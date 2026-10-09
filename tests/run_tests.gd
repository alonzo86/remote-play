extends SceneTree
## Headless tests. Run (see README):
##   godot --headless --path . --script tests/run_tests.gd -- --role=controller
## "--role=controller" keeps the TV autoload from taking port 47801.

const Shell = preload("res://scripts/game/shell.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const OrientationFusion = preload("res://scripts/input/orientation.gd")
const MazeGenerator = preload("res://scripts/game/maze/maze_generator.gd")
const Registry = preload("res://scripts/game/registry.gd")
const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")
const QrEncoder = preload("res://scripts/core/qr_encoder.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const SensorSampler = preload("res://scripts/input/sensor_sampler.gd")

var _fails := 0
var _checks := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_until(cond: Callable, max_ms := 4000) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


## Loads a script at run time. Scripts that use the App autoload cannot be preloaded here:
## the autoload is not known when this file is parsed.
func _script(path: String) -> GDScript:
	return load(path)


func _touch(index: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	return e


## A stand-in for the Android plugin "QrScanner" (android/plugin/QrScannerPlugin.java).
class FakeQrPlugin extends Object:
	signal scanned(text: String)
	signal failed(reason: String)
	var calls: Array[String] = []

	func scan() -> void:
		calls.append("scan")

	# gdlint:ignore=function-name
	func acquireWifiLocks() -> void:
		calls.append("acquireWifiLocks")


## Collects the packets that a sensor sampler sends.
class FakeClient extends Node:
	var packets: Array = []

	func send_sensor(packet: PackedByteArray) -> void:
		packets.append(packet)


## A screen with a Back handler, to see how App sends Back.
class BackProbe extends Control:
	var calls := 0

	func on_back() -> void:
		calls += 1


func _run() -> void:
	_test_protocol()
	_test_orientation()
	_test_maze()
	_test_qr()
	_test_registry()
	await _test_network()
	await _test_phone_screens()
	_test_visual_rules()
	_test_role()
	await _test_sensor_sampler()
	await _test_discovery()
	await _test_qr_scanner()
	await _test_connect_screen()
	await _test_app_input()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _test_protocol() -> void:
	print("protocol")
	var pkt := Protocol.encode_sensor(65535, 4000000000, Vector3(1, -2, 3), Vector3(0.5, 9.81, -1),
			Protocol.BTN_A | Protocol.BTN_B, Protocol.FLAG_TOUCH, Vector2(1.0, 0.0))
	_check(pkt.size() == Protocol.SENSOR_PACKET_SIZE, "packet is 36 bytes")
	_check(Protocol.parse_json('{"t":"ping","id":7}') == {"t": "ping", "id": 7.0}, "a JSON object is parsed")
	_check(Protocol.parse_json("not json").is_empty() and Protocol.parse_json("[1, 2]").is_empty()
			and Protocol.parse_json("42").is_empty() and Protocol.parse_json("").is_empty(),
			"text that is not a JSON object gives an empty Dictionary")
	var d := Protocol.decode_sensor(pkt)
	_check(d.seq == 65535 and d.ts == 4000000000, "seq and timestamp round trip")
	_check(d.gyro.is_equal_approx(Vector3(1, -2, 3)) and d.accel.is_equal_approx(Vector3(0.5, 9.81, -1)), "sensor floats round trip")
	_check(d.buttons == 3 and d.touching and absf(d.touch.x - 1.0) < 0.01 and d.touch.y == 0.0, "buttons and touch round trip")
	_check(Protocol.decode_sensor(PackedByteArray([1, 2, 3])).is_empty(), "short packet is rejected")
	_check(Protocol.make_room_code().length() == 4, "room code has 4 letters")
	_check(Protocol.is_ipv4("192.168.1.20") and not Protocol.is_ipv4("KQZM"), "ipv4 check")
	_check(Protocol.subnet_broadcast("192.168.1.20") == "192.168.1.255", "subnet broadcast")
	var pair := Protocol.parse_pair_url(Protocol.pair_url("192.168.1.20", "kqzm"))
	_check(pair == {"host": "192.168.1.20", "port": 47801, "room": "KQZM"}, "QR text parses: %s" % str(pair))
	_check(Protocol.parse_pair_url("ws://10.0.0.5:47801").room == "", "QR text without room is accepted")
	var bad := ["", "http://192.168.1.20:47801/KQZM", "ws://?:47801/KQZM", "ws://192.168.1.20/KQZM",
			"ws://192.168.1.20:99999/KQZM", "ws://192.168.1.20:47801/KQ", "ws://192.168.1.20:47801/KQZI",
			"ws://999.1.1.1:47801/KQZM"]
	var all_bad := true
	for b in bad:
		if not Protocol.parse_pair_url(b).is_empty():
			all_bad = false
			print("    accepted: ", b)
	_check(all_bad, "invalid QR texts are rejected")


func _feed(o: OrientationFusion, seconds: float, gyro: Vector3, accel: Vector3, start_ts := 0) -> int:
	var ts := start_ts
	for i in int(seconds * 60.0):
		ts += 17
		o.update(ts, gyro, accel)
	return ts


func _test_orientation() -> void:
	print("orientation")
	var s := {}
	var o := OrientationFusion.new(s)
	var flat := Vector3(0, 0, 9.81)
	var ts := _feed(o, 1.0, Vector3.ZERO, flat)
	_check(o.tilt().length() < 0.01, "flat phone: no tilt")
	# Right side down by 20 degrees: up vector gets a negative x component.
	var a := deg_to_rad(20.0)
	_feed(o, 3.0, Vector3.ZERO, Vector3(-sin(a), 0, cos(a)) * 9.81, ts)
	_check(o.tilt().x > 0.25 and o.tilt().x < 0.4, "right side down: tilt.x about sin(20 deg), got %.3f" % o.tilt().x)
	o.recenter()
	_check(o.tilt().length() < 0.01, "recenter zeroes the tilt")
	# Top of phone up by 20 degrees: up gets a positive y component.
	_feed(o, 3.0, Vector3.ZERO, Vector3(0, sin(a), cos(a)) * 9.81, ts + 100000)
	_check(o.tilt().y > 0.1, "top up: tilt.y positive (got %.3f)" % o.tilt().y)

	# Yaw: turn left at 1 rad/s for 0.5 s. The cursor must go left (x < 0).
	var o2 := OrientationFusion.new({})
	var ts2 := _feed(o2, 0.5, Vector3.ZERO, flat)
	o2.recenter()
	_feed(o2, 0.5, Vector3(0, 0, 1.0), flat, ts2)
	_check(o2.pointer().x < -0.5, "turn left: pointer.x negative (got %.2f)" % o2.pointer().x)
	_check(absf(rad_to_deg(o2.yaw) - 28.6) < 3.0, "yaw integrates to about 28.6 deg (got %.1f)" % rad_to_deg(o2.yaw))
	# Gyro bias: a constant offset on a still phone must not move the pointer.
	var o3 := OrientationFusion.new({})
	var bias := Vector3(0.01, -0.02, 0.03)
	var ts3 := _feed(o3, 6.0, bias, flat)
	var yaw_before := o3.yaw
	_feed(o3, 5.0, bias, flat, ts3)
	_check(absf(o3.yaw - yaw_before) < 0.01, "still phone: yaw frozen despite gyro bias")
	_check(o3.gyro_bias.distance_to(bias) < 0.015, "gyro bias is learned (%s)" % str(o3.gyro_bias))
	# Setting invert_yaw flips the sign.
	var o4 := OrientationFusion.new({"invert_yaw": true})
	var ts4 := _feed(o4, 0.5, Vector3.ZERO, flat)
	o4.recenter()
	_feed(o4, 0.5, Vector3(0, 0, 1.0), flat, ts4)
	_check(o4.pointer().x > 0.5, "invert_yaw flips the pointer")
	# Timestamp wrap
	var o5 := OrientationFusion.new({})
	o5.update(0xFFFFFFF0, Vector3.ZERO, flat)
	o5.update(0xFFFFFFF8, Vector3(0, 0, 1), flat)
	o5.update(0x00000005, Vector3(0, 0, 1), flat)
	_check(absf(o5.yaw) < 0.1, "u32 timestamp wrap does not jump")


func _test_registry() -> void:
	print("registry")
	var ids := {}
	var all_ok := true
	for g in Registry.all():
		ids[g.id] = true
		var sc := Registry.load_script(String(g.id))
		var base := "res://scripts/game/minigame_3d.gd" if g.dim == "3d" else "res://scripts/game/minigame.gd"
		var s := sc
		var inherits_base := false
		while s != null:
			if s.resource_path == base:
				inherits_base = true
			s = s.get_base_script()
		if sc == null or not inherits_base:
			all_ok = false
	_check(ids.size() == Registry.all().size(), "registry ids are unique")
	var docs_ok := true
	for g in Registry.all():
		if not FileAccess.file_exists(String(g.get("doc", ""))):
			docs_ok = false
			print("    missing requirements file for ", g.id)
	_check(docs_ok, "every game has a requirements file (REQ-GM-6)")
	_check(all_ok, "every registry game loads and extends the right base class")
	_check(Registry.reason({"min_players": 3, "max_players": 4}, 2) == "Needs 3 players",
			"a game that needs more players says why (REQ-FL-14)")
	var shown_ok := true
	for g in Registry.all():
		var id := String(g.id)
		if String(g.get("description", "")) == "":
			shown_ok = false
			print("    no description for ", id)
		var tile := String(g.get("tile", ""))
		if tile == "" or not FileAccess.file_exists(tile):
			shown_ok = false
			print("    no tile file for ", id)
		else:
			var img := Image.load_from_file(ProjectSettings.globalize_path(tile))
			if img == null or img.get_width() != 640 or img.get_height() != 360:
				shown_ok = false
				print("    tile of ", id, " is not 640x360")
	_check(shown_ok, "every game has a description and a 640x360 tile file (REQ-FL-19, 20, 22)")
	_check(Registry.find("nope").is_empty() and Registry.load_script("nope") == null, "unknown game id gives nothing")
	var race_rows: Array = Registry.find("marble_race").get("settings", [])
	_check(race_rows.size() == 1 and race_rows[0].type == "tracks"
			and race_rows[0].values.size() == MarbleTrack.FIXED_SEEDS.size() + 1
			and race_rows[0].titles.size() == race_rows[0].values.size() and race_rows[0].values[-1] == "random",
			"the marble race track list has the 10 fixed tracks and the random one (REQ-MR-53)")
	_check(Registry.accepts(Registry.find("maze"), 4) and not Registry.accepts(Registry.find("maze"), 5), "player range check")


func _test_maze() -> void:
	print("maze")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var all_ok := true
	for i in 50:
		var m := MazeGenerator.new()
		m.generate(17, 9, rng)
		if not m.is_solvable():
			all_ok = false
	_check(all_ok, "50 generated mazes are solvable")
	var m2 := MazeGenerator.new()
	m2.generate(17, 9, rng)
	_check(m2.wall_rects(96.0, 10.0).size() > 100, "maze has wall rectangles")


func _test_qr() -> void:
	print("qr")
	var m := QrEncoder.encode("ws://192.168.100.100:47801/KQZM")
	_check(m.size() == 25, "31 byte URL gives version 2 (25 modules), got %d" % m.size())
	_check(m[0][0] and m[0][6] and m[6][0] and not m[1][1] and m[2][2], "finder pattern top-left")
	_check(QrEncoder.encode("x".repeat(200)).is_empty(), "too long text returns empty")
	# Save for an external decoder check.
	var n := m.size()
	var img := Image.create(n * 8 + 64, n * 8 + 64, false, Image.FORMAT_L8)
	img.fill(Color.WHITE)
	for y in n:
		for x in n:
			if m[y][x]:
				img.fill_rect(Rect2i(32 + x * 8, 32 + y * 8, 8, 8), Color.BLACK)
	img.save_png("user://qr_test.png")
	# Larger texts use other versions.
	for len in [10, 40, 70, 100, 130]:
		var q := QrEncoder.encode("a".repeat(len))
		_check(not q.is_empty(), "encodes %d bytes (%d modules)" % [len, q.size()])
		var img2 := Image.create(q.size() * 8 + 64, q.size() * 8 + 64, false, Image.FORMAT_L8)
		img2.fill(Color.WHITE)
		for y in q.size():
			for x in q.size():
				if q[y][x]:
					img2.fill_rect(Rect2i(32 + x * 8, 32 + y * 8, 8, 8), Color.BLACK)
		img2.save_png("user://qr_test_%d.png" % len)


## The phone shows the pad for `playing` and `paused`, and the waiting screen for the other phases
## (REQ-FL-28). It goes back to the connect screen when it leaves.
## The maze colors follow REQ-GM-47d and 47e (REQ-MZ-7). The player colors are checked for every game.
func _test_visual_rules() -> void:
	print("visual rules")
	var Maze = load("res://scripts/game/maze/maze_game.gd")
	var consts: Dictionary = Maze.get_script_constant_map()
	var floor_c: Color = consts["FLOOR_COLOR"]
	var wall_c: Color = consts["WALL_COLOR"]
	var players_ok := true
	var floor_ok := true
	for c in Protocol.PLAYER_COLORS:
		if c.s < 0.55 or c.v < 0.60:
			players_ok = false
			print("    player color not saturated or bright enough: ", c)
		if Shell.contrast(c, floor_c) < 3.0:
			floor_ok = false
			print("    player color too close to the maze floor: ", c)
	_check(players_ok, "player colors have saturation 0.55+ and value 0.60+ (REQ-GM-47d)")
	_check(floor_ok, "every player color has a contrast of 3:1 on the maze floor (REQ-GM-47e)")
	_check(floor_c.s >= 0.35 and floor_c.v >= 0.25 and floor_c.v <= 0.65, "the maze floor is dark and saturated (REQ-GM-47e)")
	_check(Shell.contrast(wall_c, floor_c) >= 3.0, "the maze walls can be seen on the floor")
	_check(UiTheme.OUTLINE.v < 0.4, "the outline color is dark")

	_check(UiTheme.SHADOW_COLOR.a < 1.0, "the shadow is see-through, so it is lighter than the outline")

	# A name for a phone without one, and a digit centered in its circle.
	var p := PlayerInput.new(2, {})
	p.on_join("", "tok")
	_check(p.player_name == "Player 3", "a phone without a name is Player N: %s" % p.player_name)
	p.on_join("Ana", "tok")
	_check(p.player_name == "Ana", "a given name is kept")
	var f := UiTheme.title_font()
	var base := UiTheme.centered_baseline(f, Rect2(0, 10, 54, 54), 30)
	var mid := base - (f.get_ascent(30) - f.get_descent(30)) * 0.5
	_check(absf(mid - 37.0) < 0.01 and base > 37.0, "the text middle is at the rect middle, the baseline below it (%.2f)" % base)


func _test_phone_screens() -> void:
	print("phone screens")
	var app: Node = root.get_node("App")
	var wait_script: GDScript = _script("res://scripts/ui/controller_wait.gd")
	var pad_script: GDScript = _script("res://scripts/ui/controller_pad.gd")
	_check(wait_script.texts_for("connect")[0] == "Waiting for the host"
			and wait_script.texts_for("menu")[0] == "Choose a game on the TV"
			and wait_script.texts_for("waiting")[0] == "A round is running", "the waiting screen has a text for each phase")
	var server := TvServer.new()
	root.add_child(server)
	server.start({})
	app.client.connect_to("127.0.0.1", Protocol.WS_PORT, server.room_code)
	await _wait_until(func(): return app.client.state == ControllerClient.State.CONNECTED)
	await process_frame
	_check(is_instance_of(app.current_screen(), wait_script), "connect phase: the phone shows the waiting screen")
	server.set_phase("menu")
	await _wait_until(func(): return app.client.phase == "menu")
	await process_frame
	_check(is_instance_of(app.current_screen(), wait_script), "menu phase: the phone stays on the waiting screen")
	server.set_phase("playing")
	await _wait_until(func(): return app.client.phase == "playing")
	await process_frame
	_check(is_instance_of(app.current_screen(), pad_script), "playing phase: the phone shows the pad")
	server.set_phase("paused")
	await _wait_until(func(): return app.client.phase == "paused")
	await process_frame
	_check(is_instance_of(app.current_screen(), pad_script), "paused phase: the phone keeps the pad")
	await _test_pad(app, server)
	var others: Array[int] = [app.client.slot + 1]
	server.set_phase("playing", others)
	await _wait_until(func(): return app.client.phase == "waiting")
	await process_frame
	_check(is_instance_of(app.current_screen(), wait_script), "a phone that is not in the round goes to the waiting screen")
	server.set_phase("playing")
	await _wait_until(func(): return app.client.phase == "playing")
	await process_frame
	var leave_pad = app.current_screen()
	leave_pad._input(_touch(5, true, leave_pad._rect_leave().get_center()))
	leave_pad._input(_touch(5, false, leave_pad._rect_leave().get_center()))
	await process_frame
	_check(app.client.state == ControllerClient.State.CONNECTED and leave_pad._leave_armed > 0.0,
			"the first tap on Leave only arms it (REQ-FL-52)")
	leave_pad._leave_armed = 0.0 # The 3 s are over: a new tap arms again and does not leave.
	leave_pad._input(_touch(5, true, leave_pad._rect_leave().get_center()))
	leave_pad._input(_touch(5, false, leave_pad._rect_leave().get_center()))
	await process_frame
	_check(app.client.state == ControllerClient.State.CONNECTED, "a tap on Leave after the time is over arms it again")
	leave_pad._input(_touch(6, true, leave_pad._rect_leave().get_center()))
	await process_frame
	await process_frame
	_check(app.client.state == ControllerClient.State.IDLE, "the second tap on Leave leaves the TV (REQ-FL-52)")
	_check(app.current_screen().get_script().resource_path == "res://scripts/ui/controller_connect.gd",
			"leaving returns to the connect screen")
	server.stop()
	server.queue_free()


## The sensor packets: about 60 a second, no burst after a stall, sequence numbers that wrap,
## buttons and touch inside the packet, and the mouse that simulates yaw on desktop (REQ-N1, REQ-N2, REQ-C2).
func _test_sensor_sampler() -> void:
	print("sensor sampler")
	var client := FakeClient.new()
	root.add_child(client)
	var sampler = SensorSampler.new()
	sampler.client = client
	root.add_child(sampler)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1000:
		await process_frame
	var rate: int = client.packets.size()
	_check(rate >= 52 and rate <= 62, "about 60 packets in one second (%d)" % rate)
	var seqs: Array = client.packets.map(func(p): return Protocol.decode_sensor(p).seq)
	var in_order := true
	for i in range(1, seqs.size()):
		in_order = in_order and seqs[i] == (seqs[i - 1] + 1) & 0xFFFF
	_check(in_order and not seqs.is_empty(), "the sequence numbers go up by one")
	var flat: Dictionary = Protocol.decode_sensor(client.packets[-1])
	_check(absf(flat.accel.length() - 9.81) < 0.05, "the simulated accelerometer has a length of 9.81 (%.2f)" % flat.accel.length())

	# The sign fix: flat on Android, Godot reports z = -9.8 and the protocol needs +9.8. A desktop value is not changed.
	var flat_raw := Vector3(0.1, -0.2, -9.8)
	var flat_fixed := Vector3(-0.1, 0.2, 9.8)
	_check(SensorSampler.accel_to_protocol(flat_raw, "Android") == flat_fixed, "Android: all accelerometer axes are flipped")
	_check(SensorSampler.accel_to_protocol(flat_raw, "iOS") == flat_fixed, "iOS: flipped like Android until a device test says so")
	_check(SensorSampler.accel_to_protocol(flat_raw, "macOS") == flat_raw, "other platforms: the value is not changed")

	# A stall (the app was paused) must not make a burst of old packets.
	sampler.set_process(false)
	await create_timer(0.5).timeout
	var before: int = client.packets.size()
	sampler.set_process(true)
	for i in 3:
		await process_frame
	_check(client.packets.size() - before <= 2, "no burst of packets after a stall (%d)" % (client.packets.size() - before))

	# Mouse motion simulates a turn of the phone, once. Buttons and touch are inside the packet.
	sampler.set_process(false)
	client.packets.clear()
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(20, 0)
	sampler._input(motion)
	sampler.buttons = Protocol.BTN_A | Protocol.BTN_B
	sampler.touching = true
	sampler.touch = Vector2(0.25, 0.75)
	sampler._next_send_us = 0
	sampler._process(0.0)
	sampler._next_send_us = 0
	sampler._process(0.0)
	var first: Dictionary = Protocol.decode_sensor(client.packets[0])
	var second: Dictionary = Protocol.decode_sensor(client.packets[1])
	_check(first.gyro.z < -0.5 and second.gyro.z == 0.0,
			"a mouse move turns the simulated phone once (%.2f, %.2f)" % [first.gyro.z, second.gyro.z])
	_check(first.buttons == (Protocol.BTN_A | Protocol.BTN_B) and first.touching
			and absf(first.touch.x - 0.25) < 0.01 and absf(first.touch.y - 0.75) < 0.01, "buttons and touch are in the packet")
	sampler.touching = false
	sampler._next_send_us = 0
	sampler._seq = 65535
	sampler._process(0.0)
	sampler._next_send_us = 0
	sampler._process(0.0)
	var wrap_a: Dictionary = Protocol.decode_sensor(client.packets[2])
	var wrap_b: Dictionary = Protocol.decode_sensor(client.packets[3])
	_check(wrap_a.seq == 65535 and wrap_b.seq == 0 and not wrap_a.touching, "the sequence number wraps from 65535 to 0")
	sampler.queue_free()
	client.queue_free()


## The phone pad: layout on common phone shapes, multi-touch, Recenter, Leave, haptic, latency color.
func _test_pad(app: Node, server: Node) -> void:
	print("controller pad")
	var pad_script: GDScript = _script("res://scripts/ui/controller_pad.gd")
	for dim in [Vector2(1080, 1920), Vector2(1080, 2160), Vector2(1080, 2400)]:
		var lay: Control = pad_script.new()
		lay.size = dim
		var screen := Rect2(Vector2.ZERO, dim)
		var leave: Rect2 = lay._rect_leave()
		var rec: Rect2 = lay._rect_recenter()
		var ra: float = lay._radius()
		var ca: Vector2 = lay._center_a()
		var cb: Vector2 = lay._center_b()
		var box_a := Rect2(ca - Vector2(ra, ra), Vector2(ra, ra) * 2.0)
		var box_b := Rect2(cb - Vector2(ra, ra), Vector2(ra, ra) * 2.0)
		var inside := screen.encloses(leave) and screen.encloses(rec) and screen.encloses(box_a) and screen.encloses(box_b)
		var apart := not leave.intersects(rec) and not rec.intersects(box_a) and not rec.intersects(box_b) \
				and not box_a.intersects(box_b)
		_check(inside and apart, "pad %dx%d: the controls are on the screen and do not overlap" % [dim.x, dim.y])
		var hits: Array = [lay._zone_at(rec.get_center()), lay._zone_at(ca), lay._zone_at(cb),
				lay._zone_at(leave.get_center()), lay._zone_at(Vector2(dim.x * 0.5, dim.y - 20.0))]
		_check(hits == ["recenter", "a", "b", "leave", "pad"],
				"pad %dx%d: a touch gives the right zone: %s" % [dim.x, dim.y, str(hits)])
		lay.free()
	var lat: Control = pad_script.new()
	lat.size = Vector2(1080, 2160)
	_check(is_equal_approx(lat._rect_leave().get_center().y, lat.HEADER_Y), "Leave is centered on the pad header row")
	_check(lat._lat_color(-1.0) == UiTheme.TEXT_DIM and lat._lat_color(10.0) == UiTheme.OK
			and lat._lat_color(24.9) == UiTheme.OK and lat._lat_color(25.0) == UiTheme.ACCENT
			and lat._lat_color(59.0) == UiTheme.ACCENT and lat._lat_color(60.0) == UiTheme.BAD_TEXT,
			"the latency color is dim, green, yellow and red at 25 ms and 60 ms")
	lat.free()
	var pad = app.current_screen()
	var sampler = pad._sampler
	sampler.set_process(false) # No zero samples must overwrite what the test gives the TV player.
	var ca2: Vector2 = pad._center_a()
	var cb2: Vector2 = pad._center_b()
	pad._input(_touch(0, true, ca2))
	_check((sampler.buttons & Protocol.BTN_A) != 0 and (sampler.buttons & Protocol.BTN_B) == 0, "a finger on A presses A")
	_check(sampler.touching and absf(sampler.touch.x - ca2.x / pad.size.x) < 0.01, "the first finger is the touch point")
	pad._input(_touch(1, true, cb2))
	_check((sampler.buttons & (Protocol.BTN_A | Protocol.BTN_B)) == (Protocol.BTN_A | Protocol.BTN_B),
			"A and B can be held at the same time (multi-touch)")
	pad._input(_touch(0, false, ca2))
	_check((sampler.buttons & Protocol.BTN_A) == 0 and (sampler.buttons & Protocol.BTN_B) != 0,
			"lifting the finger from A keeps B pressed")
	pad._input(_touch(1, false, cb2))
	_check(sampler.buttons == 0 and not sampler.touching, "lifting all fingers releases everything")

	# The Recenter button reaches the TV: the tilt of this player is zero after the tap.
	var tv_player = server.players[app.client.slot]
	var lean := deg_to_rad(15.0)
	var tilted := Vector3(-sin(lean), 0.0, cos(lean)) * 9.81
	for i in 90:
		tv_player.on_sensor(Protocol.decode_sensor(Protocol.encode_sensor(i, i * 16, Vector3.ZERO, tilted, 0, 0, Vector2.ZERO)),
				Time.get_ticks_msec())
	var before: float = tv_player.tilt().length()
	pad._input(_touch(3, true, pad._rect_recenter().get_center()))
	pad._input(_touch(3, false, pad._rect_recenter().get_center()))
	_check(pad._flash.recenter > 0.9, "the Recenter button flashes")
	await _wait_until(func(): return tv_player.tilt().length() < 0.02)
	_check(before > 0.2 and tv_player.tilt().length() < 0.02,
			"Recenter on the phone zeroes the tilt on the TV (%.2f -> %.2f)" % [before, tv_player.tilt().length()])

	var got: Array = []
	app.client.haptic_requested.connect(func(ms): got.append(ms))
	server.haptic(app.client.slot, 33)
	await _wait_until(func(): return not got.is_empty())
	_check(got == [33], "a haptic message from the TV reaches the pad: %s" % str(got))
	sampler.set_process(true)


## Which role runs: the command line first, then the feature tags, then the platform (REQ-P3, REQ-P4).
func _test_role() -> void:
	print("role")
	var role_script: GDScript = _script("res://scripts/core/role.gd")
	var tags := func(list: Array) -> Callable: return func(tag: String) -> bool: return tag in list
	var tv: int = role_script.Kind.TV
	var ctl: int = role_script.Kind.CONTROLLER
	_check(role_script.pick(["--role=tv"], tags.call(["controller"])) == tv, "the command line beats the feature tag (tv)")
	_check(role_script.pick(["x", "--role=controller"], tags.call(["tv"])) == ctl,
			"the command line beats the feature tag (controller)")
	_check(role_script.pick([], tags.call(["controller"])) == ctl and role_script.pick([], tags.call(["tv"])) == tv,
			"the feature tag decides")
	_check(role_script.pick([], tags.call(["tv", "controller"])) == ctl, "controller wins when both tags are set")
	_check(role_script.pick([], tags.call(["mobile"])) == ctl, "a phone without a tag is the controller")
	_check(role_script.pick([], tags.call([])) == tv, "a desktop without a tag is the TV")
	_check(role_script.pick(["--role=other"], tags.call([])) == tv, "an unknown role argument is ignored")
	var here = role_script.new()
	_check(here.is_controller() and not here.is_tv(), "this test run has --role=controller")
	here.free()


## The phone finds TVs by their UDP beacon (REQ-A2, REQ-A4).
func _test_discovery() -> void:
	print("controller discovery")
	var app: Node = root.get_node("App")
	var disc: Node = app.controller_discovery
	_check(disc.listening, "the phone listens on the beacon port")
	disc.tvs.clear()
	var changes := [0]
	disc.list_changed.connect(func(): changes[0] += 1)
	var udp := PacketPeerUDP.new()
	udp.set_dest_address("127.0.0.1", Protocol.UDP_PORT)
	var send := func(text: String): udp.put_packet(text.to_utf8_buffer())
	var beacon := func(room: String, extra := {}) -> String:
		var d := {"t": "beacon", "v": Protocol.VERSION, "room": room, "port": 47801, "name": "Den TV", "players": 1, "max": 4}
		d.merge(extra, true)
		return JSON.stringify(d)
	send.call("not json at all")
	send.call(JSON.stringify({"t": "hello", "v": Protocol.VERSION, "room": "HELO"}))
	send.call(beacon.call("OLDV", {"v": Protocol.VERSION + 1}))
	send.call(beacon.call(""))
	send.call(beacon.call("BBBB", {"players": 2}))
	send.call(beacon.call("AAAA", {"name": "Hall TV", "port": 5555}))
	await _wait_until(func(): return disc.tvs.has("AAAA") and disc.tvs.has("BBBB"))
	_check(disc.tvs.size() == 2,
			"garbage, other message types, other versions and empty rooms are ignored (%d TVs)" % disc.tvs.size())
	var a: Dictionary = disc.tvs.get("AAAA", {})
	_check(a.get("ip", "") == "127.0.0.1" and a.get("port", 0) == 5555 and a.get("name", "") == "Hall TV",
			"a TV entry has the sender address, the port and the name of the beacon")
	_check(int(disc.tvs.get("BBBB", {}).get("players", -1)) == 2, "a TV entry has the player count")
	_check(disc.sorted_list().map(func(t): return t.room) == ["AAAA", "BBBB"], "the list is sorted by room code")
	_check(changes[0] >= 1, "a new TV changes the list")
	send.call(beacon.call("AAAA", {"players": 3}))
	await _wait_until(func(): return int(disc.tvs["AAAA"].players) == 3)
	_check(int(disc.tvs["AAAA"].players) == 3, "a new beacon updates the player count")
	var seen_before: int = changes[0]
	disc.tvs["BBBB"].seen_ms = Time.get_ticks_msec() - disc.EXPIRE_MS - 100
	await _wait_until(func(): return not disc.tvs.has("BBBB"))
	_check(not disc.tvs.has("BBBB") and disc.tvs.has("AAAA"), "a TV that is silent for 4 s leaves the list")
	_check(changes[0] > seen_before, "the list changes when a TV leaves")
	disc.tvs.clear()


## The Android plugin glue: the fallback on desktop, and the calls with a plugin (here a stand-in).
func _test_qr_scanner() -> void:
	print("qr scanner")
	var qr_script: GDScript = _script("res://scripts/net/qr_scanner.gd")
	var app: Node = root.get_node("App")
	var plain = qr_script.new()
	root.add_child(plain)
	var reasons: Array = []
	plain.failed.connect(func(r): reasons.append(r))
	_check(not plain.is_available(), "there is no scanner plugin on desktop")
	plain.scan()
	_check(reasons == ["unavailable"], "scan without the plugin says unavailable: %s" % str(reasons))
	plain.acquire_wifi_locks() # Must do nothing, not fail.
	plain.queue_free()

	# The scanner exists before the plugin: the first call finds the plugin later.
	var late = qr_script.new()
	root.add_child(late)
	var fake := FakeQrPlugin.new()
	Engine.register_singleton("QrScanner", fake)
	var texts: Array = []
	var fails: Array = []
	late.scanned.connect(func(t): texts.append(t))
	late.failed.connect(func(r): fails.append(r))
	_check(late.is_available(), "the scanner sees a plugin that is registered later")
	late.scan()
	_check(fake.calls == ["scan"], "scan() calls the plugin: %s" % str(fake.calls))
	fake.scanned.emit("ws://192.168.1.20:47801/KQZM")
	fake.failed.emit("cancelled")
	_check(texts == ["ws://192.168.1.20:47801/KQZM"] and fails == ["cancelled"], "results of the plugin come out as signals")
	late.acquire_wifi_locks()
	_check(fake.calls == ["scan", "acquireWifiLocks"], "acquire_wifi_locks() calls the plugin: %s" % str(fake.calls))

	# The connect screen offers the scan button when the plugin exists, and the button starts a scan.
	var screen: Control = _script("res://scripts/ui/controller_connect.gd").new()
	screen.theme = app.theme_res
	root.add_child(screen)
	var scan_button: Button = null
	for b in screen.find_children("*", "Button", true, false):
		if b.text == "Scan QR code":
			scan_button = b
	_check(scan_button != null, "the connect screen says Scan QR code when the plugin exists")
	fake.calls.clear()
	if scan_button != null:
		scan_button.pressed.emit()
	_check(fake.calls == ["scan"], "the scan button starts a scan: %s" % str(fake.calls))
	screen.queue_free()
	late.queue_free()
	Engine.unregister_singleton("QrScanner")
	fake.free()
	await process_frame


## What the phone user sees while joining: codes, errors and the target of the join.
func _test_connect_screen() -> void:
	print("connect screen")
	var app: Node = root.get_node("App")
	var screen = _script("res://scripts/ui/controller_connect.gd").new()
	screen.theme = app.theme_res
	root.add_child(screen)
	await process_frame
	var has_paste := false
	for b in screen.find_children("*", "Button", true, false):
		has_paste = has_paste or b.text == "Paste TV link"
	_check(has_paste, "without the plugin the connect screen offers Paste TV link")
	var connect_script: GDScript = _script("res://scripts/ui/controller_connect.gd")
	_check(not connect_script.shows_scan_button("iOS"),
			"on an iPhone or iPad the connect screen has no scan or paste button")
	_check(connect_script.shows_scan_button("Android") and connect_script.shows_scan_button("macOS"),
			"on Android and desktop (also a Mac) the connect screen keeps the scan or paste button")
	app.last_error = ""
	screen._on_state(ControllerClient.State.IDLE)
	_check(screen._status.text == "Looking for a TV...", "idle: the screen says it looks for a TV")
	screen._on_state(ControllerClient.State.CONNECTING)
	_check(screen._status.text == "Connecting...", "connecting: the screen says so")
	screen._on_state(ControllerClient.State.RECONNECTING)
	_check(screen._status.text == "Reconnecting...", "reconnecting: the screen says so")

	screen._on_qr_text("hello")
	_check(app.last_error == "This is not a Remote Play code." and screen._status.text == app.last_error,
			"a QR code of something else is refused with a message")
	app.last_error = ""
	screen._on_qr_failed("cancelled")
	_check(app.last_error == "", "cancelling the scan is not an error")
	screen._on_qr_failed("no camera")
	_check(app.last_error == "QR scan failed: no camera" and screen._status.text == app.last_error, "a failed scan shows the reason")

	screen._on_qr_text("ws://127.0.0.1:47801/kqzm")
	_check(app.client.host == "127.0.0.1" and app.client.port == 47801 and app.client.room == "KQZM"
			and app.client.state != ControllerClient.State.IDLE, "a TV code joins that TV and room")
	app.client.leave()
	app.last_error = ""
	# Only two ways to join: the QR code and the list of detected TVs (no typed room code or IP).
	_check(screen.find_children("*", "LineEdit", true, false).is_empty(), "the connect screen has no text input")
	app.controller_discovery.forget_all()
	screen._rebuild_list()
	_check(_list_texts(screen) == ["No TVs found"], "an empty list says no TVs were found: %s" % str(_list_texts(screen)))
	app.controller_discovery.tvs["QQQQ"] = {"room": "QQQQ", "ip": "127.0.0.9", "port": 47801, "name": "Den", "players": 1,
			"max": 4, "seen_ms": Time.get_ticks_msec()}
	screen._rebuild_list()
	await process_frame
	var tv_button: Button = null
	for btn in screen._list.find_children("*", "Button", true, false):
		tv_button = btn
	_check(tv_button != null and tv_button.text == "QQQQ 1/4", "a detected TV is only '<code> x/y': %s" % tv_button.text)
	var refresh_btn: Array = screen.find_children("*", "Button", true, false).filter(func(x): return x.text == "Refresh")
	_check(refresh_btn.size() == 1 and tv_button.theme_type_variation != refresh_btn[0].theme_type_variation,
			"the Refresh button is not the same color as the detected TVs")
	tv_button.pressed.emit()
	_check(app.client.host == "127.0.0.9" and app.client.room == "QQQQ", "tapping a detected TV joins it")
	app.client.leave()
	# Refresh forgets the TVs and says it searches; a TV that beacons again comes back.
	screen.refresh_list()
	await process_frame
	_check(app.controller_discovery.tvs.is_empty() and _list_texts(screen) == ["Searching..."],
			"Refresh clears the list and shows Searching: %s" % str(_list_texts(screen)))
	app.controller_discovery.tvs["QQQQ"] = {"room": "QQQQ", "ip": "127.0.0.9", "port": 47801, "name": "Den", "players": 1,
			"max": 4, "seen_ms": Time.get_ticks_msec()}
	screen._rebuild_list()
	await process_frame
	_check(not screen._list.find_children("*", "Button", true, false).is_empty(), "a TV that beacons after Refresh is listed again")
	app.controller_discovery.tvs.erase("QQQQ")
	screen.queue_free()
	app.last_error = ""
	await process_frame


func _list_texts(screen: Control) -> Array:
	var r: Array = []
	for c in screen._list.get_children():
		r.append(c.text if "text" in c else "")
	return r


## Back, the keys and the messages of App (REQ-T3, REQ-GM-33), and the join of a phone by itself (--auto-join).
func _test_app_input() -> void:
	print("app input")
	var app: Node = root.get_node("App")
	app.go(BackProbe)
	var probe: BackProbe = app.current_screen()
	app._last_back_ms = 0
	app._back()
	app._back()
	_check(probe.calls == 1, "two Back signals within 250 ms count once (key and notification of one press)")
	await create_timer(0.3).timeout
	app._back()
	_check(probe.calls == 2, "a later Back is sent to the screen")

	# A click leaves no focus on the button. The debug overlay is never saved, so it starts off.
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_ALL
	probe.add_child(btn)
	btn.grab_focus()
	_check(btn.has_focus(), "the test button has the focus")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	app._input(up)
	await process_frame
	await process_frame
	_check(not btn.has_focus(), "a mouse click or a tap leaves no focus on the button")
	btn.queue_free()
	var was: bool = app.settings.overlay
	app.settings.overlay = true
	app.save_settings()
	var cfg := ConfigFile.new()
	cfg.load(app.SETTINGS_FILE)
	_check(not cfg.has_section_key("settings", "overlay") and cfg.has_section_key("settings", "invert_tilt"),
			"the debug overlay is not saved, the other settings are")
	app.settings.overlay = was
	await create_timer(0.3).timeout
	var key := InputEventKey.new()
	key.keycode = KEY_BACK
	key.pressed = true
	app._input(key)
	_check(probe.calls == 3, "the Back key of the remote is sent to the screen")
	await create_timer(0.3).timeout
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	app._input(cancel)
	_check(probe.calls == 4, "Escape is sent to the screen")
	var other := InputEventKey.new()
	other.keycode = KEY_A
	other.pressed = true
	app._input(other)
	_check(probe.calls == 4, "another key is not a Back")

	var texts := {}
	for reason in ["full", "bad_room", "version", "unreachable", "tv_closed", "kicked"]:
		app._on_client_rejected(reason)
		texts[reason] = app.last_error
	_check(texts.values().all(func(t): return t != "" and not t.begins_with("Connection refused")),
			"every known rejection has its own message")
	_check(texts.values().size() == 6 and texts["full"] != texts["bad_room"] and texts["version"] != texts["unreachable"],
			"the messages are different")
	_check(String(texts["full"]).contains("4"), "the full message says how many players fit")
	app._on_client_rejected("weird")
	_check(app.last_error == "Connection refused: weird", "an unknown rejection shows its reason")

	var disc: Node = app.controller_discovery
	disc.tvs.clear()
	app._auto_join()
	_check(app.client.state == ControllerClient.State.IDLE, "auto-join does nothing when no TV is found")
	disc.tvs["AUTO"] = {"room": "AUTO", "ip": "127.0.0.1", "port": 47801, "name": "Den", "players": 0, "max": 4,
			"seen_ms": Time.get_ticks_msec()}
	app._auto_join()
	_check(app.client.host == "127.0.0.1" and app.client.room == "AUTO" and app.client.state != ControllerClient.State.IDLE,
			"auto-join joins the first TV that is found")
	app.client.leave()
	disc.tvs.clear()

	var shown = app.current_screen()
	app._show_phone_screen() # The client is idle: the screen must not change.
	_check(app.current_screen() == shown, "an idle phone keeps its screen when the phase changes")
	app.go(_script("res://scripts/ui/controller_connect.gd"))
	app.last_error = ""
	await process_frame


func _test_network() -> void:
	print("network")
	var settings := {}
	var server := TvServer.new()
	root.add_child(server)
	var err := server.start(settings)
	_check(err == OK, "server listens on %d" % Protocol.WS_PORT)
	var events := []
	server.player_joined.connect(func(s): events.append("join%d" % s))
	server.player_lost.connect(func(s): events.append("lost%d" % s))
	server.player_resumed.connect(func(s): events.append("resume%d" % s))
	server.player_removed.connect(func(s): events.append("removed%d" % s))

	var c1 := ControllerClient.new()
	c1.player_name = "  One  "
	root.add_child(c1)
	c1.connect_to("127.0.0.1", Protocol.WS_PORT, server.room_code)
	var ok := await _wait_until(func(): return c1.state == ControllerClient.State.CONNECTED)
	_check(ok, "client 1 connects")
	_check(c1.slot == 0 and server.players[0].player_name == "One", "client 1 gets slot 0 with a trimmed name")

	# Send sensor packets at 60 Hz for 1.5 s with a fake sampler.
	var seq := 0
	var t_end := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < t_end:
		c1.send_sensor(Protocol.encode_sensor(seq, Time.get_ticks_msec(), Vector3(0, 0, 0.1),
				Vector3(0, 0, 9.81), Protocol.BTN_A if seq == 30 else 0, 0, Vector2.ZERO))
		seq += 1
		await _frames(1)
	var p0 := server.players[0]
	_check(p0.rx_total > 30, "server received sensor packets (%d)" % p0.rx_total)
	_check(p0.lost_packets == 0, "no sequence gaps")
	_check(c1.rtt_ms >= 0.0 and c1.rtt_ms < 200.0, "client measured RTT (%.1f ms)" % c1.rtt_ms)
	_check(p0.rtt_ms >= 0.0, "TV received the RTT from the phone (%.1f ms)" % p0.rtt_ms)
	_check(p0.has_clock and absf(p0.sensor_age_ms) < 100.0, "sensor age is small on loopback (%.1f ms)" % p0.sensor_age_ms)

	# Second client, then the room fills up.
	var clients := [c1]
	for i in range(1, 4):
		var c := ControllerClient.new()
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, server.room_code)
		clients.append(c)
		await _wait_until(func(): return c.state == ControllerClient.State.CONNECTED)
	_check(server.connected_slots().size() == 4, "4 phones connected")
	var c5 := ControllerClient.new()
	root.add_child(c5)
	var rejected := []
	c5.rejected.connect(func(r): rejected.append(r))
	c5.connect_to("127.0.0.1", Protocol.WS_PORT, server.room_code)
	await _wait_until(func(): return not rejected.is_empty())
	_check(rejected == ["full"], "5th phone is rejected: %s" % str(rejected))
	var cbad := ControllerClient.new()
	root.add_child(cbad)
	var rej2 := []
	cbad.rejected.connect(func(r): rej2.append(r))
	cbad.connect_to("127.0.0.1", Protocol.WS_PORT, "ZZZZ")
	await _wait_until(func(): return not rej2.is_empty())
	_check(rej2 == ["bad_room"] or rej2 == ["full"], "wrong room code is rejected: %s" % str(rej2))

	# Reconnect: break the socket of client 2. It must come back to the same slot.
	var c2: Node = clients[1]
	var slot2: int = c2.slot
	c2._ws.close()
	await _wait_until(func(): return server.players[slot2].state == PlayerInput.State.LOST)
	_check(server.players[slot2].state == PlayerInput.State.LOST, "server marks the slot as lost")
	ok = await _wait_until(func():
			return c2.state == ControllerClient.State.CONNECTED and server.players[slot2].is_connected_now(),
			6000)
	_check(ok and c2.slot == slot2, "client 2 reconnects to the same slot")
	_check(events.has("lost%d" % slot2) and events.has("resume%d" % slot2), "lost and resume events fired: %s" % str(events))

	# Clean leave frees the slot.
	c2.leave()
	await _wait_until(func(): return not server.players[slot2].is_present())
	_check(not server.players[slot2].is_present(), "leave frees the slot")

	# Remove (REQ-FL-33): the slot is free at once, the phone is told, and it does not reconnect by itself.
	var c3: Node = clients[2]
	var slot3: int = c3.slot
	var kicked := []
	c3.rejected.connect(func(r): kicked.append(r))
	server.kick(slot3)
	await _wait_until(func(): return not kicked.is_empty())
	_check(kicked == ["kicked"], "a removed phone is told: %s" % str(kicked))
	_check(not server.players[slot3].is_present(), "remove frees the slot at once")
	_check(c3.state == ControllerClient.State.IDLE and c3.slot == -1, "the removed phone goes back to idle")
	await _wait_until(func(): return false, 1500)
	_check(not server.players[slot3].is_present() and c3.state == ControllerClient.State.IDLE,
			"the removed phone does not reconnect by itself")

	# Phase and haptic messages reach the phone.
	var phases := []
	clients[0].phase_changed.connect(func(p): phases.append(p))
	server.set_phase("playing")
	await _wait_until(func(): return not phases.is_empty())
	_check(phases == ["playing"], "phase message reaches the phone")

	# A phone that joined late gets "waiting" during a round (REQ-FL-25).
	var late_phases := []
	clients[3].phase_changed.connect(func(p): late_phases.append(p))
	phases.clear()
	var in_round: Array[int] = [clients[0].slot]
	server.set_phase("paused", in_round)
	await _wait_until(func(): return not phases.is_empty() and not late_phases.is_empty())
	_check(phases == ["paused"] and late_phases == ["waiting"], "late phone gets waiting: %s %s" % [str(phases), str(late_phases)])
	server.set_phase("menu")
	phases.clear()
	late_phases.clear()
	await _wait_until(func(): return not late_phases.is_empty())
	_check(late_phases == ["menu"], "the next phase reaches the late phone")

	# A slot that is freed during a round leaves the round. A new phone in it must wait (REQ-FL-25).
	var slot4: int = clients[3].slot
	var round_two: Array[int] = [clients[0].slot, slot4]
	server.set_phase("playing", round_two)
	_check(server.phase_for(slot4) == "playing", "a slot in the round sees playing")
	server.drop_player(slot4)
	_check(server.phase_for(slot4) == "waiting" and server.round_slots == [clients[0].slot],
			"a slot freed during the round is not in the round any more")
	server.set_phase("menu")
	_check(not server.round_limited and server.phase_for(slot4) == "menu", "the menu phase ends the round list")

	# Server stop makes clients go to reconnect, not crash.
	for c in clients:
		c.leave()
	server.stop()


