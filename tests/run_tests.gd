extends SceneTree
## Headless tests. Run (see README):
##   godot --headless --path . --script tests/run_tests.gd -- --role=controller
## "--role=controller" keeps the TV autoload from taking port 47801.

const Protocol = preload("res://scripts/core/protocol.gd")
const OrientationFusion = preload("res://scripts/input/orientation.gd")
const MazeGenerator = preload("res://scripts/game/maze/maze_generator.gd")
const Registry = preload("res://scripts/game/registry.gd")
const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")
const QrEncoder = preload("res://scripts/core/qr_encoder.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")

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


func _run() -> void:
	_test_protocol()
	_test_orientation()
	_test_maze()
	_test_qr()
	_test_registry()
	_test_marble_track()
	await _test_network()
	await _test_room_code_join()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _test_protocol() -> void:
	print("protocol")
	var pkt := Protocol.encode_sensor(65535, 4000000000, Vector3(1, -2, 3), Vector3(0.5, 9.81, -1),
			Protocol.BTN_A | Protocol.BTN_B, Protocol.FLAG_TOUCH, Vector2(1.0, 0.0))
	_check(pkt.size() == Protocol.SENSOR_PACKET_SIZE, "packet is 36 bytes")
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
	var tracks_ok := true
	for g in Registry.all():
		if g.id == "marble_race":
			var track_ids: Array = []
			for v in g.variants:
				track_ids.append(v.props.track_id)
			tracks_ok = track_ids == MarbleTrack.IDS
	_check(tracks_ok, "marble race menu variants match the track list")
	_check(Registry.accepts(Registry.find("maze"), 4) and not Registry.accepts(Registry.find("maze"), 5), "player range check")


func _test_marble_track() -> void:
	print("marble track")
	for tid in MarbleTrack.IDS:
		var t = MarbleTrack.make(tid)
		_check(t.id == tid and t.length > 60.0, "%s: loads and is long enough (%.0f m)" % [tid, t.length])
		var prev := -1.0
		var mono := true
		var on_line := true
		var a := 0.0
		var samples: Array[Vector2] = []
		while a <= t.length:
			var q: Dictionary = t.query(t.point_at(a))
			if q.dist > 0.01 or absf(q.arc - a) > 0.05:
				on_line = false
			if q.arc < prev:
				mono = false
			prev = q.arc
			samples.append(t.point_at(a))
			a += 1.0
		_check(on_line and mono, "%s: point_at and query agree, arc grows" % tid)
		# Parts of the track far apart in arc must be far apart in space, or arc is not clear.
		var apart := true
		var gap := ceili(t.half_width * 4.0)
		for i in samples.size():
			for j in range(i + gap, samples.size()):
				if samples[i].distance_to(samples[j]) < t.half_width * 1.8:
					apart = false
		_check(apart, "%s: track does not touch itself" % tid)
		_check(t.dir_at(5.0).is_equal_approx(Vector2(0, -1)) and t.point_at(8.0).x == 0.0, "%s: starts with a straight toward -z" % tid)
		var bumpers_ok := true
		for b in t.bumpers:
			var off: float = absf(b[1]) * t.half_width * 0.44
			if b[0] > t.length - 8.0 or t.half_width + off - 0.9 < 2.0:
				bumpers_ok = false
		_check(bumpers_ok, "%s: bumpers leave a marble-wide gap and stay before the finish" % tid)
	var t0 = MarbleTrack.make("classic")
	var side: Vector2 = t0.point_at(30.0) + Vector2(t0.half_width + 1.0, 0)
	_check(t0.query(side).dist > t0.half_width, "a point beside the track is outside it")
	_check(MarbleTrack.make("nope").id == "classic", "unknown track id gives the classic track")


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


func _test_room_code_join() -> void:
	print("room code join")
	var app: Node = root.get_node("App")
	# Load now, not at parse time: the App autoload must exist first.
	var ControllerConnect: GDScript = load("res://scripts/ui/controller_connect.gd")
	var screen = ControllerConnect.new()
	screen.theme = app.theme_res
	root.add_child(screen)
	screen._input.text = "ZZZZ"
	screen._join_typed() # Waits for a beacon that never comes.
	_check(screen._joining, "typed room code starts one wait")
	screen._join_typed()
	_check(screen._joining, "second tap during the wait is ignored")
	# A beacon that arrives after the screen is gone must not start a connection.
	screen.queue_free()
	app.controller_discovery.tvs["ZZZZ"] = {"ip": "127.0.0.1", "port": 1, "room": "ZZZZ", "name": "Test TV",
			"players": 0, "max": 4, "seen_ms": Time.get_ticks_msec()}
	await create_timer(0.5).timeout
	_check(app.client.state == ControllerClient.State.IDLE, "no join after the screen is closed")
	app.controller_discovery.tvs.erase("ZZZZ")


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
	c1.player_name = "One"
	root.add_child(c1)
	c1.connect_to("127.0.0.1", Protocol.WS_PORT, server.room_code)
	var ok := await _wait_until(func(): return c1.state == ControllerClient.State.CONNECTED)
	_check(ok, "client 1 connects")
	_check(c1.slot == 0 and server.players[0].player_name == "One", "client 1 gets slot 0")

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
