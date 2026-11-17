extends SceneTree
## The swing detector with the debug overlay line (A-24-1 to A-24-11; Test 24 of docs/MANUAL_TESTS.md has no manual step
## since 2026-11-17) with made-up sensor traces (tests/sensor_replay.gd): a hand that is
## still, walking, trembling; strokes of three strengths in three grips; serves; shakes and taps; two loopback phones.
## Run: godot --headless --path . --script tests/swing_replay.gd -- --role=tv

const R = preload("res://tests/sensor_replay.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var DebugOverlay = null   # Loaded when the tests run: the overlay script uses the App autoload.

var _checks := 0
var _fails := 0


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A phone slot with a started sensor fusion.
func _rig(up := R.UP_FLAT, invert := false) -> R.Feeder:
	var f := R.Feeder.new(PlayerInput.new(0, {"invert_tilt": invert}), up)
	f.invert = invert
	f.settle(0.5)
	return f


## `n` times: the trace `make.call(i)`, then `gap` seconds of rest. Returns the swings that were found.
func _repeat(f: R.Feeder, n: int, make: Callable, gap := 2.0) -> Array:
	for i in n:
		f.feed(make.call(i))
		f.feed(R.still(gap))
	return f.swings


func _run() -> void:
	await process_frame
	DebugOverlay = load("res://scripts/ui/debug_overlay.gd")
	root.size = Vector2i(1920, 1080)
	_overlay()
	_quiet_hand()
	_strokes()
	_serve_and_direction()
	_wait_and_lock()
	_shake_and_tap()
	_side()
	_ios()
	await _two_phones()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


# ---- Item 1, 3b: the line of the debug overlay ----

func _overlay() -> void:
	print("overlay line")
	var canvas = DebugOverlay._Canvas.new()
	var p := PlayerInput.new(0, {})
	var plain := " ".join(String(canvas._swing_text(p)).split(" ", false))
	_check(plain == "P1 swing: none yet", "before any swing the line says 'P1 swing: none yet' (%s)" % plain)
	var f := R.Feeder.new(p, R.UP_UPRIGHT)
	f.settle()
	f.feed(R.serve(R.UP_UPRIGHT))
	f.feed(R.still(0.5))
	var text: String = canvas._swing_text(p)
	_check(text.begins_with("P1") and text.contains("swing 1:") and text.contains("DOWN") and not text.contains("not down")
			and text.contains("ms ago"), "a serve gives 'swing 1' with DOWN and the age of the hit: %s" % text)
	# REQ-BW-8: the line holds the number, the power, DOWN, the side, the direction in the world, the age of the hit and the time
	# since the swing; it holds no detector state, aim or peaks.
	var fields := RegEx.create_from_string("^P1 +swing 1: power (\\d\\.\\d\\d) +DOWN +side (-?\\d\\.\\d\\d) "
			+ "\\(x -?\\d\\.\\d\\d, to TV -?\\d\\.\\d\\d, up -?\\d\\.\\d\\d\\) +hit \\d+ ms ago +-?\\d+\\.\\d s ago$")
	var m := fields.search(text)
	_check(m != null and float(m.get_string(1)) == snappedf(float(p.last_swing.power), 0.01)
			and float(m.get_string(2)) == snappedf(float(p.last_swing.side), 0.01),
			"REQ-BW-8: the line has the number, power, DOWN, side, direction, hit age and swing age of the last swing: %s" % text)
	_check(not text.to_lower().contains("aim") and not text.to_lower().contains("peak") and not text.to_lower().contains("state"),
			"REQ-BW-8: and no detector state, aim or peaks")
	var other := PlayerInput.new(1, {})
	_check(String(canvas._swing_text(other)).begins_with("P2"), "REQ-BW-8: every player has a line of its own (P2)")
	var g := R.grip(R.UP_UPRIGHT)
	f.feed(R.still(1.0))
	f.feed(R.stroke(g.dir(0.0), 10.0, 25.0))
	f.feed(R.still(0.5))
	text = canvas._swing_text(p)
	_check(text.contains("swing 2:") and text.contains("not down"), "a forehand says 'not down': %s" % text)
	var t := p.last_swing_ms
	_check(canvas._swing_color(p, t + 1000) == p.color and canvas._swing_color(p, t + 1499) == p.color,
			"the line has the color of the player for 1.5 s after a swing")
	_check(canvas._swing_color(p, t + 1500) == UiTheme.TEXT_DIM and canvas._swing_color(p, t + 4000) == UiTheme.TEXT_DIM,
			"then it is dim")
	canvas.free()


# ---- Items 2, 4b, 7: nothing that is not a swing ----

func _quiet_hand() -> void:
	print("a hand that is not swinging")
	for up in [R.UP_FLAT, R.UP_UPRIGHT]:
		var f := _rig(up)
		f.feed(R.still(30.0, 0.15, 3))
		_check(f.swings.is_empty(), "a hand that is still for 30 s (noise 0.15 m/s2) gives no swing (grip %s)" % str(up))
		f = _rig(up)
		f.feed(R.tremor(10.0, 0.3, 10.0))
		_check(f.swings.is_empty(), "a trembling hand (0.3 m/s2 at 10 Hz) gives no swing (grip %s)" % str(up))
		f = _rig(up)
		f.feed(R.walk(30.0, up))
		f.feed(R.walk(10.0, R.grip(up).north, 2.0, [1.0, 2.0, 1.5]))
		_check(f.swings.is_empty(),
				"walking (steps at 2 Hz, 2 to 6 m/s2 up and down, sway) for 40 s gives no swing (grip %s)" % str(up))
	var f2 := _rig()
	_repeat(f2, 10, func(i): return R.slow_move(10.0, 0.5, 2.0), 0.0)
	_check(f2.swings.is_empty(), "a gentle move of 10 cm at 0.5 Hz (1 m/s2), 10 times, is not a swing")
	var f3 := _rig()
	_repeat(f3, 10, func(i): return R.stroke(R.grip(R.UP_FLAT).dir(0.0), 10.0, 5.0))
	_check(f3.swings.is_empty(), "a very soft stroke (forward 5 m/s2, under the threshold of 6) is not a swing")


# ---- Items 3, 4, 8: strokes ----

func _strokes() -> void:
	print("strokes")
	for up in [R.UP_FLAT, R.UP_UPRIGHT, R.UP_SIDE, R.UP_SIDE_LEFT, R.UP_TILT45]:
		var g := R.grip(up)
		var f := _rig(up)
		_repeat(f, 10, func(i): return R.noisy(R.stroke(g.dir(0.0), 10.0, 25.0, 0.25, 0.25), 0.3, i + 1))
		_check(f.swings.size() >= 9 and f.swings.size() <= 10,
				"10 forehands (back 10, forward 25 m/s2, 0.25 s) in the grip %s: %d found" % [str(up), f.swings.size()])
	var g := R.grip(R.UP_FLAT)
	var mean := []
	for fwd in [10.0, 20.0, 32.0]:
		var f := _rig()
		_repeat(f, 5, func(i): return R.stroke(g.dir(0.0), 10.0, fwd))
		var sum := 0.0
		for s in f.swings:
			sum += float(s.power)
		mean.append(sum / maxf(1.0, float(f.swings.size())))
		_check(f.swings.size() == 5, "5 strokes of %.0f m/s2 are all found" % fwd)
	_check(mean[1] - mean[0] >= 0.1 and mean[2] - mean[1] >= 0.1 and mean[2] <= 1.0,
			"the power grows from soft to medium to hard by 0.1 or more: %s" % str(mean))
	var fwd_dir: Vector3 = g.dir(0.0)
	var pushes := _repeat(_rig(), 10, func(i): return R.back_swing(fwd_dir, 8.0, 0.2).append(
			R.push(fwd_dir, 20.0 + 2.0 * float(i % 6), 0.04)))
	_check(pushes.size() >= 9, "10 back swings, each followed by a sharp push of 20 to 30 m/s2 for 0.04 s, are the hit (%d found)"
			% pushes.size())
	# Item 8: how long ago was the hit. The stroke is a half sine; the hit is its peak and the report comes when it fades to half.
	var f := _rig()
	_repeat(f, 10, func(i): return R.stroke(g.dir(0.0), 10.0, 25.0))
	var ok := f.swings.size() == 10
	for s in f.swings:
		ok = ok and float(s.hit_age_ms) > 0.0 and float(s.hit_age_ms) < 550.0 and absf(float(s.hit_age_ms) - 66.7) < 20.0
	_check(ok, "the age of the hit is 0 to 550 ms, and 67 ms for this stroke (peak at 0.1 s, half at 0.167 s)")
	var lat := _rig()
	lat.player.on_stat(20.0, float(lat.base_ms))   # The TV clock is the phone clock + base_ms.
	lat.base_ms += 45   # The packets arrive 45 ms after they were sent.
	_repeat(lat, 3, func(i): return R.stroke(g.dir(0.0), 10.0, 25.0))
	_check(lat.swings.size() == 3 and absf(lat.player.sensor_age_ms - 45.0) < 20.0
			and absf(float(lat.swings[0].hit_age_ms) - 66.7) < 20.0,
			"a link delay of 45 ms shows in Age ms (%.0f) and does not change the age of the hit" % lat.player.sensor_age_ms)


# ---- Item 5: the serve is DOWN ----

func _serve_and_direction() -> void:
	print("serve")
	for up in [R.UP_TILT45, R.UP_UPRIGHT, R.UP_SIDE_TILT45]:
		var f := _rig(up)
		_repeat(f, 10, func(i): return R.noisy(R.serve(up), 0.3, i + 1))
		var down := f.swings.filter(func(s): return s.down).size()
		_check(down >= 9, "10 serves from top to bottom (grip %s): %d of %d say DOWN" % [str(up), down, f.swings.size()])
		var g := R.grip(up)
		var h := _rig(up)
		_repeat(h, 10, func(i): return R.noisy(R.stroke(g.dir(40.0), 10.0, 25.0), 0.3, i + 1))
		var wrong := h.swings.filter(func(s): return s.down).size()
		_check(h.swings.size() >= 9 and wrong <= 1,
				"10 forehands left to right (grip %s): %d of %d say DOWN" % [str(up), wrong, h.swings.size()])


# ---- Item 6: the wait ----

func _wait_and_lock() -> void:
	print("the wait after a swing")
	var g := R.grip(R.UP_FLAT)
	var fw := g.dir(0.0)
	var f := _rig()
	_repeat(f, 5, func(i): return R.stroke(fw, 10.0, 25.0).append(R.follow_through(fw, 15.0)).append(R.stroke(-fw, 10.0, 25.0)), 3.0)
	_check(f.swings.size() == 5, "a swing and at once the stroke back is one swing: %d for 5 tries" % f.swings.size())
	for gap in [0.5, 1.0]:
		var h := _rig()
		for i in 5:
			h.feed(R.stroke(fw, 10.0, 25.0))
			h.feed(R.still(gap))
			h.feed(R.stroke(fw, 10.0, 25.0))
			h.feed(R.still(3.0))
		_check(h.swings.size() == 10, "two strokes %.1f s apart, 5 times: both are found (%d of 10)" % [gap, h.swings.size()])


# ---- Item 7 ----

func _shake_and_tap() -> void:
	print("shake and tap")
	var f := _rig()
	_repeat(f, 10, func(i): return R.shake(1.0, 5.0, 8.0))
	_check(f.swings.is_empty(), "10 shakes of 5 m/s2 at 8 Hz are not a swing")
	var t := _rig()
	_repeat(t, 10, func(i): return R.tap(100.0))
	_check(t.swings.is_empty(), "10 taps (100 m/s2 in one packet, 8 ms) are not a swing")
	var two := _rig()
	_repeat(two, 5, func(i): return R.back_swing(Vector3(0, 1, 0), 8.0, 0.2).append(R.push(Vector3(0, 1, 0), 100.0, 0.05)))
	_check(two.swings.size() == 5, "but a push that lasts 3 packets (0.05 s) is the hit: the rule needs 0.03 s, not only a spike")


# ---- Item 11: left and right ----

func _side() -> void:
	print("left and right")
	var g := R.grip(R.UP_FLAT)
	var f := _rig()
	var order := []
	for c in 10:
		order.append_array([0.0, 30.0, 0.0, -30.0])
	for i in order.size():
		f.feed(R.noisy(R.stroke(g.dir(order[i]), 10.0, 25.0), 0.3, i + 1))
		f.feed(R.still(1.0))
	var right_ok := 0
	var left_ok := 0
	var mid_ok := 0
	if f.swings.size() == order.size():
		for i in order.size():
			var side := float(f.swings[i].side)
			if order[i] > 0.0 and side >= 0.3:
				right_ok += 1
			elif order[i] < 0.0 and side <= -0.3:
				left_ok += 1
			elif order[i] == 0.0 and absf(side) < 0.3:
				mid_ok += 1
	_check(f.swings.size() == order.size() and right_ok >= 8 and left_ok >= 8 and mid_ok >= 18,
			"swings at the TV, 30 degrees right and 30 degrees left (noise): right %d/10, left %d/10, middle %d/20"
			% [right_ok, left_ok, mid_ok])
	var s := _rig()
	_repeat(s, 10, func(i): return R.noisy(R.stroke(g.dir(0.0), 10.0, 25.0), 0.3, i + 1), 1.0)
	var worst := 0.0
	for x in s.swings:
		worst = maxf(worst, absf(float(x.side)))
	_check(s.swings.size() == 10 and worst < 0.1, "10 swings at the TV give a side of 0 (largest %.2f)" % worst)
	var rep := _rig()
	_repeat(rep, 10, func(i): return R.stroke(g.dir(30.0), 10.0, 25.0), 1.0)
	_check(rep.swings.size() == 10 and float(rep.swings[0].side) > 0.3 and absf(float(rep.swings[9].side)) < 0.3,
			"REQ-TN-7: by default 'straight' is the mean of the last swings, so ten equal swings 30 degrees right drift to the "
			+ "middle (%.2f -> %.2f)"
			% [float(rep.swings[0].side), float(rep.swings[9].side)])
	# Tennis (owner, 2026-11-06): the heading does not follow the swings, so the same swing gives the same side every time.
	var fixed := _rig()
	fixed.player.follow_heading = false
	_repeat(fixed, 10, func(i): return R.stroke(g.dir(30.0), 10.0, 25.0), 1.0)
	var lowest := 9.0
	for x in fixed.swings:
		lowest = minf(lowest, float(x.side))
	_check(fixed.swings.size() == 10 and lowest > 0.3,
			"REQ-TN-7: in Tennis ten equal swings 30 degrees right all aim right (lowest side %.2f)" % lowest)


# ---- Item 10: the other sign of the accelerometer ----

func _ios() -> void:
	print("the other sign")
	var g := R.grip(R.UP_UPRIGHT)
	var f := _rig(R.UP_UPRIGHT, true)
	_repeat(f, 10, func(i): return R.noisy(R.stroke(g.dir(0.0), 10.0, 25.0), 0.3, i + 1))
	_check(f.swings.size() >= 9 and f.swings.filter(func(s): return s.down).is_empty(),
			"with the other sign (and invert_tilt) 10 forehands are found and not DOWN: %d" % f.swings.size())
	var h := _rig(R.UP_UPRIGHT, true)
	_repeat(h, 10, func(i): return R.noisy(R.serve(R.UP_UPRIGHT), 0.3, i + 1))
	_check(h.swings.filter(func(s): return s.down).size() >= 9, "with the other sign 10 serves say DOWN")
	var w := _rig(R.UP_UPRIGHT, true)
	w.feed(R.walk(20.0, R.UP_UPRIGHT))
	_check(w.swings.is_empty(), "with the other sign walking is not a swing")


# ---- Item 9: two phones on loopback ----

func _two_phones() -> void:
	print("two phones")
	var app: Node = root.get_node("App")
	var clients: Array = []
	for i in 2:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame
	var states := [{}, {}]
	var ups := [R.UP_UPRIGHT, R.UP_FLAT]
	var gu := R.grip(R.UP_UPRIGHT)
	var gf := R.grip(R.UP_FLAT)
	var still := R.still(0.6)
	await R.stream_many(self, clients, [still, still], ups, states)
	var p0: PlayerInput = app.server.players[0]
	var p1: PlayerInput = app.server.players[1]
	p0.swing_count = 0
	p1.swing_count = 0
	var one := R.still(0.2)
	for i in 5:
		one.append(R.stroke(gu.dir(0.0), 10.0, 25.0)).append(R.still(0.8))
	await R.stream_many(self, clients, [one, R.still(one.seconds())], ups, states)
	_check(p0.swing_count == 5 and p1.swing_count == 0,
			"5 strokes on phone 1: P1 counts %d, P2 counts %d" % [p0.swing_count, p1.swing_count])
	var two := R.still(0.2)
	for i in 5:
		two.append(R.stroke(gf.dir(0.0), 10.0, 25.0)).append(R.still(0.8))
	await R.stream_many(self, clients, [R.still(two.seconds()), two], ups, states)
	_check(p0.swing_count == 5 and p1.swing_count == 5,
			"5 strokes on phone 2: P1 stays at %d, P2 counts %d" % [p0.swing_count, p1.swing_count])
	await R.stream_many(self, clients, [one, two], ups, states)
	_check(p0.swing_count == 10 and p1.swing_count == 10,
			"both phones at the same time: each gets its 5 more (%d, %d)" % [p0.swing_count, p1.swing_count])
	var lines := ["P1", "P2"]
	var canvas = DebugOverlay._Canvas.new()
	_check(String(canvas._swing_text(p0)).begins_with(lines[0]) and String(canvas._swing_text(p1)).begins_with(lines[1])
			and p0.last_swing.down == false and p1.last_swing.down == false, "each phone has its own line and its own last swing")
	canvas.free()
