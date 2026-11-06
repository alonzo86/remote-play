extends SceneTree
## The numbers of the network test (docs/MANUAL_TESTS.md test 4) on the loopback, with simulated phones that send 60 packets a
## second: the round trip time, the packet rate, the longest gap and the lost packets that the TV overlay shows, with 1 phone and
## with 4 phones while the maze runs. The loopback guards the code of the TV (a stall in the main
## thread, the ping answer, the rate
## and gap arithmetic); the real radio is the manual part.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/net_rate.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const Slow = preload("res://tests/slow_run.gd")
## The instrumented copy of the coverage job runs the frame loop slower, so the packet window counts fewer packets there.
var HZ_MIN_1 := 40.0 if Slow.instrumented() else 56.0   # 56, not 58: a Mac counts 57.0 Hz (#380).
var HZ_MIN_4 := 38.0 if Slow.instrumented() else 56.0

const WINDOW_S := 5.0   # Real seconds of each run (the clocks of the code run in real time).

var _checks := 0
var _fails := 0
var _app: Node
var _seq := [0, 0, 0, 0]


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _wait_until(cond: Callable, max_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


## Sends 60 packets a second from each phone for `seconds`, on the clock and not on the frames, so the rate does not depend on
## the speed of the headless loop. `tilt` is the accel of the phones.
func _stream(phones: Array, seconds: float, tilt: Vector3) -> void:
	var t0 := Time.get_ticks_msec()
	var sent := 0
	var step_ms := 1000.0 / Protocol.SENSOR_HZ
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		var due := int((Time.get_ticks_msec() - t0) / step_ms) + 1
		while sent < due:
			for i in phones.size():
				phones[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO, tilt, 0, 0,
						Vector2.ZERO))
				_seq[i] += 1
			sent += 1
		await process_frame


func _join(count: int) -> Array:
	var phones: Array = []
	for i in count:
		var c := ControllerClient.new()
		c.player_name = "Rate%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
		phones.append(c)
	await _wait_until(func(): return _app.server.connected_slots().size() >= count, 4000)
	return phones


func _run() -> void:
	for i in 5:
		await process_frame
	_app = root.get_node("App")
	if not _app.server.listening:
		_check(false, "the TV server listens (another TV app or test holds port %d)" % Protocol.WS_PORT)
		return
	var maze: GDScript = load("res://scripts/game/maze/maze_game.gd")
	await _one_phone()
	await _four_phones(maze)
	await _frame_delay(maze)


func _one_phone() -> void:
	print("one phone at 60 Hz, no game")
	var phones := await _join(1)
	var p: PlayerInput = _app.server.players[0]
	var tilt := Vector3(0, 0, 9.81)
	await _stream(phones, 2.5, tilt)   # The first seconds warm up the clock offset and the first window.
	var worst_rtt := 0.0
	var worst_gap := 0
	var min_hz := 999.0
	var max_hz := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(WINDOW_S * 1000.0):
		await _stream(phones, 0.5, tilt)
		worst_rtt = maxf(worst_rtt, p.rtt_ms)
		worst_gap = maxi(worst_gap, p.max_gap_ms)
		min_hz = minf(min_hz, p.rx_rate)
		max_hz = maxf(max_hz, p.rx_rate)
	print("    rtt %.1f ms, rx %.1f..%.1f Hz, gap %d ms, lost %d" % [worst_rtt, min_hz, max_hz, worst_gap, p.lost_packets])
	_check(p.rtt_ms >= 0.0 and worst_rtt < Slow.limit(30.0, 8.0),
			"the round trip time is below %.0f ms (a frame of the headless loop is 17 ms) (%.1f ms)" % [Slow.limit(30.0, 8.0), worst_rtt])
	_check(min_hz >= HZ_MIN_1 and max_hz <= 62.0, "the TV counts 56 to 60 packets a second (%.1f to %.1f Hz)" % [min_hz, max_hz])
	_check(worst_gap < int(Slow.limit(60.0, 8.0)), "the longest gap between packets is below %d ms (%d ms)"
			% [int(Slow.limit(60.0, 8.0)), worst_gap])
	_check(p.lost_packets == 0, "no packet is lost (sequence gaps: %d)" % p.lost_packets)
	for c in phones:
		c.leave()
		c.queue_free()
	await _wait_until(func(): return _app.server.player_count() == 0, 2000)


func _four_phones(maze: GDScript) -> void:
	print("four phones at 60 Hz while the maze runs")
	var phones := await _join(4)
	_app.go(maze)
	await process_frame
	_check(_app.current_screen().participants.size() == 4, "the maze runs with 4 players")
	var tilt := Vector3(0, 0, 9.81)
	await _stream(phones, 6.0, tilt)   # The countdown is over after about 3 s.
	var stats := []
	for i in 4:
		stats.append({"rtt": 0.0, "gap": 0, "min": 999.0, "max": 0.0})
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(WINDOW_S * 1000.0):
		await _stream(phones, 0.5, tilt)
		for i in 4:
			var p: PlayerInput = _app.server.players[i]
			stats[i].rtt = maxf(stats[i].rtt, p.rtt_ms)
			stats[i].gap = maxi(stats[i].gap, p.max_gap_ms)
			stats[i].min = minf(stats[i].min, p.rx_rate)
			stats[i].max = maxf(stats[i].max, p.rx_rate)
	var rtt_ok := true
	var hz_ok := true
	var gap_ok := true
	var lost_ok := true
	for i in 4:
		var p: PlayerInput = _app.server.players[i]
		print("    P%d rtt %.1f ms, rx %.1f..%.1f Hz, gap %d ms, lost %d" % [i + 1, stats[i].rtt, stats[i].min, stats[i].max,
				stats[i].gap, p.lost_packets])
		rtt_ok = rtt_ok and p.rtt_ms >= 0.0 and stats[i].rtt < Slow.limit(45.0, 8.0)
		hz_ok = hz_ok and stats[i].min >= HZ_MIN_4 and stats[i].max <= 62.0
		gap_ok = gap_ok and stats[i].gap < int(Slow.limit(60.0, 8.0))
		lost_ok = lost_ok and p.lost_packets == 0
	_check(rtt_ok, "the round trip time of all 4 phones is below %.0f ms" % Slow.limit(45.0, 8.0))
	_check(hz_ok,
			"the TV counts 56 to 62 packets a second from each of the 4 phones (the window of a busy frame loop moves it by 2 or 3)")
	_check(gap_ok, "the longest gap of each phone is below %d ms" % int(Slow.limit(60.0, 8.0)))
	_check(lost_ok, "no phone lost a packet")
	for c in phones:
		c.leave()
		c.queue_free()
	await _wait_until(func(): return _app.server.player_count() == 0, 2000)
	_app.go_games()
	await process_frame


## 4.5, the part a machine can read: from a packet to the ball, the TV needs at most 2 frames (the delay of the TV code).
func _frame_delay(maze: GDScript) -> void:
	print("from a packet to the ball")
	var phones := await _join(1)
	_app.go(maze)
	await process_frame
	var game: Control = _app.current_screen()
	await _stream(phones, 4.0, Vector3(0, 0, 9.81))
	var ball = game._balls[0]
	var before: Vector2 = ball.vel
	var lean := deg_to_rad(15.0)
	var tilt := Vector3(-sin(lean), 0, cos(lean)) * 9.81   # The right side down: the ball goes right.
	# Keep the tilt, and count the frames from the first packet to the first change of the speed.
	var frames := 0
	var changed := false
	var start_pos: Vector2 = ball.pos
	var sent_at := Time.get_ticks_msec()
	while frames < 120 and not changed:
		phones[0].send_sensor(Protocol.encode_sensor(_seq[0], Time.get_ticks_msec(), Vector3.ZERO, tilt, 0, 0, Vector2.ZERO))
		_seq[0] += 1
		await process_frame
		frames += 1
		changed = ball.vel.x > before.x + 0.5
	var ms := Time.get_ticks_msec() - sent_at
	print("    %d frames, %d ms" % [frames, ms])
	_check(changed and frames <= 8,
			"the ball speeds up to the right within 8 frames (133 ms at 60 fps) of the tilt (%d frames; 5 measured)" % frames)
	_check(ball.pos.x >= start_pos.x, "and the ball moves to the right side (tilt right)")
	for c in phones:
		c.leave()
		c.queue_free()
	await _wait_until(func(): return _app.server.player_count() == 0, 2000)
	_app.go_games()
