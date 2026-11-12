extends SceneTree
## What Tennis adds to the swing detector (docs/games/tennis.md, REQ-TN-5 to 9): the wait after a swing, the direction
## and the age of the hit, and the swing of a phone slot on the TV. The back and forward swing itself is tested in
## tests/bowling_rules.gd.
## Run: godot --headless --path . --script tests/swing_detector.gd -- --role=controller

const SwingDetector = preload("res://scripts/input/swing_detector.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const OrientationFusion = preload("res://scripts/input/orientation.gd")
const R = preload("res://tests/sensor_replay.gd")
const BowlingRules = preload("res://scripts/game/bowling/bowling_rules.gd")
const SensorRecorder = preload("res://scripts/input/sensor_recorder.gd")

const DT := 1.0 / 60.0
const G := 9.81
const UP := Vector3(0, 0, 1)

var BowlingGame: GDScript   # Loaded in _initialize(): the game script needs the autoloads.
var _checks := 0
var _fails := 0


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
	BowlingGame = load("res://scripts/game/bowling/bowling_game.gd")
	_detector_additions()
	_player_slot()
	_not_a_throw()
	_real_shakes_432()
	_real_swings()
	_golf_gate()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## A made-up swing along `axis`: a back swing, a forward swing that peaks and fades, then rest.
func _run(d: SwingDetector, axis: Vector3, rest_s: float = 0.0) -> void:
	for i in 6:
		d.update(DT, axis * 6.0)
	for f in [10.0, 30.0, 30.0, 10.0]:
		d.update(DT, -axis * f)
	for i in int(rest_s / DT):
		d.update(DT, Vector3.ZERO)


func _detector_additions() -> void:
	print("detector: direction, age of the hit, wait")
	var d := SwingDetector.new()
	_run(d, Vector3(0, 0, 1))
	_check(d.released and d.forward_dir.is_equal_approx(Vector3(0, 0, -1)),
			"the forward direction is the opposite of the back swing")
	_check(is_equal_approx(d.hit_age, DT), "the hit was one tick before the release (the peak was the tick before the fade)")
	_check(not d.released or d.power > 0.5, "a swing of 30 m/s2 has power (%.2f)" % d.power)
	d.reset()
	_check(d.forward_dir == Vector3.ZERO and d.hit_age == 0.0, "reset() clears the direction and the age")

	_check(SwingDetector.is_down(Vector3(0, 0, -1), UP) and SwingDetector.is_down(Vector3(0.6, 0, -0.8), UP),
			"a swing that points 30 degrees or more below the horizon is down")
	_check(SwingDetector.is_down(Vector3(0.9, 0, -0.3), UP) and SwingDetector.is_down(Vector3(0.95, 0, -0.15), UP),
			"a swing that points a little below the horizon (about 9 and 17 degrees) is down too (issue #419)")
	_check(not SwingDetector.is_down(Vector3(1, 0, 0), UP) and not SwingDetector.is_down(Vector3(0, 0, 1), UP)
			and not SwingDetector.is_down(Vector3(0.99, 0, -0.05), UP),
			"a sideways, an upward and a flat swing (less than about 6 degrees down) are not down")

	# A shake turns the acceleration round again and again; with `max_reversals` it throws nothing, a real swing still does.
	for hz in [6.0, 8.0, 12.0]:
		var shaken := SwingDetector.new()
		shaken.min_back = 0.1
		shaken.max_reversals = 1
		for i in int(1.0 / DT):
			shaken.update(DT, Vector3(25.0 * sin(TAU * hz * float(i) * DT), 0, 0))
			if shaken.released:
				break
		_check(not shaken.released, "a shake of %d Hz at 25 m/s2 throws nothing with max_reversals" % int(hz))
	var real := SwingDetector.new()
	real.min_back = 0.1
	real.max_reversals = 1
	for i in 12:
		real.update(DT, Vector3(8, 0, 0))
	for f in [10.0, 30.0, 30.0, 10.0]:
		real.update(DT, Vector3(-f, 0, 0))
	_check(real.released, "a real swing (one turn round) still throws with max_reversals")

	var quick := SwingDetector.new()
	quick.lock_after = 0.4
	_run(quick, Vector3(1, 0, 0), 0.45)
	var slow := SwingDetector.new()
	_run(slow, Vector3(1, 0, 0), 0.45)
	_check(quick.state == SwingDetector.State.READY and slow.state == SwingDetector.State.LOCKED,
			"`lock_after` sets the wait after a swing (0.4 s for Tennis, 1.5 s is the bowling default)")

	# Stopping the back swing pushes the other way, but the hand is only slowing down: it is not a forward swing.
	var stop := SwingDetector.new()
	stop.hand_speed = true
	for i in 6:
		stop.update(DT, Vector3(6, 0, 0))
	for i in 3:
		stop.update(DT, Vector3(-12, 0, 0))   # A hard stop: -12 m/s2 is over the forward threshold, but the speed never turns.
	_check(stop.state == SwingDetector.State.BACK and not stop.released, "the stop of the back swing is not a forward swing")
	for f in [10.0, 30.0, 30.0, 30.0, 10.0]:
		stop.update(DT, Vector3(-f, 0, 0))
	_check(stop.released, "the real forward swing after the stop is found")

	# The hit is a sharp strong push against the back swing, after a small first move (the back swing) and a gentle slow pull
	# (found 2026-10-18; the back swing is needed since 2026-11-03: a real stroke goes back, then forward).
	var strike := SwingDetector.new()
	strike.hand_speed = true
	for i in 12:
		strike.update(DT, Vector3(8, 0, 0))   # A small first move to the right: the back swing.
	for i in 30:
		strike.update(DT, Vector3(4, 0, 0))   # A slow gentle pull back to the right.
	_check(not strike.released and strike.state != SwingDetector.State.FORWARD, "a gentle move is not the hit")
	for f in [-30.0, -50.0, -35.0, -20.0, -8.0]:
		strike.update(DT, Vector3(f, 0, 0))   # The sharp push to the left: the hit.
	_check(strike.state == SwingDetector.State.LOCKED and strike.forward_dir.is_equal_approx(Vector3(-1, 0, 0))
			and strike.power > 0.5,
			"a sharp strong push is the hit, in the direction it pushed (power %.2f)" % strike.power)
	# Two phases (REQ-TN-5): the hit is on the forward move after a back swing, never on the back move or on a push alone.
	var fresh := SwingDetector.new()
	fresh.hand_speed = true
	for f in [30.0, 50.0, 35.0, 20.0, 8.0]:
		fresh.update(DT, Vector3(0, f, 0))
	_check(not fresh.released and fresh.state != SwingDetector.State.LOCKED and fresh.state != SwingDetector.State.FORWARD,
			"a sharp push with no back swing before it is not the hit (forward only: no hit)")
	var back_only := SwingDetector.new()
	back_only.hand_speed = true
	for i in 30:
		back_only.update(DT, Vector3(40, 0, 0))   # A hard, long move one way: the back swing, however strong.
	for i in 30:
		back_only.update(DT, Vector3.ZERO)
	_check(not back_only.released and back_only.state == SwingDetector.State.BACK,
			"a back swing alone (even a hard one) is not the hit")
	var same_way := SwingDetector.new()
	same_way.hand_speed = true
	for i in 6:
		same_way.update(DT, Vector3(6, 0, 0))
	for f in [30.0, 50.0, 35.0, 20.0, 8.0]:
		same_way.update(DT, Vector3(f, 0, 0))   # A sharp push the same way as the back swing is more back swing.
	_check(not same_way.released, "a sharp push the same way as the back swing is not the hit")
	var two_phase := SwingDetector.new()
	two_phase.hand_speed = true
	for i in 6:
		two_phase.update(DT, Vector3(6, 0, 0))
	for f in [-30.0, -50.0, -35.0, -20.0, -8.0]:
		two_phase.update(DT, Vector3(f, 0, 0))
	_check(two_phase.state == SwingDetector.State.LOCKED and two_phase.forward_dir.is_equal_approx(Vector3(-1, 0, 0)),
			"a back swing and then a sharp push against it is the hit, on the forward move")

	var smooth_back := SwingDetector.new()   # A back swing is gentle: 10 m/s2 is not the hit.
	for i in 12:
		smooth_back.update(DT, Vector3(10, 0, 0))
	_check(not smooth_back.released and smooth_back.state == SwingDetector.State.BACK, "a firm back swing is not the hit")

	var held := SwingDetector.new()   # A slow back swing that is held while the ball comes is not a hit.
	for i in 12:
		held.update(DT, Vector3(6, 0, 0))
	for i in int(1.0 / DT):
		held.update(DT, Vector3.ZERO)
	_check(not held.released and held.state == SwingDetector.State.BACK, "a slow back swing that waits is not the hit")

	# A smooth, wide swing never has a sharp push (5 m/s2 is under the forward threshold) but the hand gets fast.
	var smooth := SwingDetector.new()
	smooth.hand_speed = true
	for i in 6:
		smooth.update(DT, Vector3(6, 0, 0))
	for i in int(0.6 / DT):
		smooth.update(DT, Vector3(-5, 0, 0))
	smooth.update(DT, Vector3.ZERO)
	_check(smooth.released and smooth.forward_dir.is_equal_approx(Vector3(-1, 0, 0)) and smooth.power > 0.0,
			"a smooth fast forward move without a sharp push is a swing (power %.2f)" % smooth.power)

	# A player who draws back early still gets the hit when the forward swing comes 2 s later (Tennis waits 3 s).
	var early := SwingDetector.new()
	early.window = 3.0
	early.hand_speed = true
	var plain := SwingDetector.new()
	plain.hand_speed = true
	for d2 in [early, plain]:
		for i in 6:
			d2.update(DT, Vector3(1, 0, 0) * 6.0)
		for i in 120:
			d2.update(DT, Vector3.ZERO)
		for f in [10.0, 12.0, 12.0, 3.0]:   # A forward swing under the strike push (20).
			d2.update(DT, Vector3(-1, 0, 0) * f)
	_check(early.released and not plain.released,
			"`window` sets how long a back swing waits for the forward swing (1.5 s is the default)")


## A packet at `ts` with the extra acceleration `extra` (m/s2, phone frame) on top of gravity.
func _packet(ts: int, extra: Vector3) -> Dictionary:
	return {"ts": ts, "seq": 0, "gyro": Vector3.ZERO, "accel": UP * G + extra, "buttons": 0,
			"touching": false, "touch": Vector2.ZERO}


## Sends a made-up swing along `axis` to a slot, starting at the timestamp `t0`. Returns the timestamp after it.
func _send(p: PlayerInput, t0: int, axis: Vector3, rest_ms: int) -> int:
	var t := t0
	var seq: Array = []
	for i in 6:
		seq.append(axis * 6.0)
	for f in [10.0, 30.0, 30.0, 10.0]:
		seq.append(-axis * f)
	for i in int(rest_ms / 17.0):
		seq.append(Vector3.ZERO)
	for extra in seq:
		p.on_sensor(_packet(t & 0xFFFFFFFF, extra), 100000 + t)
		t += 17
	return t


func _player_slot() -> void:
	print("PlayerInput")
	var p := PlayerInput.new(0, {})
	var got: Array = []
	p.swung.connect(func(info): got.append(info))
	var t := 0
	for i in 20:   # The phone lies still: the sensor fusion starts and nothing is found.
		p.on_sensor(_packet(t, Vector3.ZERO), 100000 + t)
		t += 17
	_check(got.is_empty() and p.swing_count == 0 and p.last_swing.is_empty(), "a phone that lies still gives no swing")
	t = _send(p, t, UP, 700)   # The wait after a swing is 0.6 s: the back swing of the next one needs the time after it.
	_check(got.size() == 1 and p.swing_count == 1 and p.last_swing_ms > 0, "a swing along the up axis is reported once")
	var s: Dictionary = got[0]
	_check(s.down and s.power > 0.5 and s.power <= 1.0 and s.hit_age_ms > 0.0 and s.has("side"),
			"it is a down swing with power (%.2f), the age of the hit (%.0f ms) and the side" % [s.power, s.hit_age_ms])
	t = _send(p, t, Vector3(1, 0, 0), 100)   # A sideways swing also shakes the tilt of the sensor fusion.
	_check(got.size() == 2 and not got[1].down, "a second swing after the wait is found, and a sideways swing is not down")
	_check(absf(float(got[0].side)) < 0.01 and float(got[1].side) < -0.9,
			"the side of a swing follows its direction: straight down gives 0, a forward swing to the left gives -1 (REQ-TN-7)")
	var o := OrientationFusion.new({})
	o.update(0, Vector3.ZERO, Vector3(0, 0, 9.81))   # Flat on a table, the top of the phone points at the TV.
	var full := 0.7854
	_check(o.to_world(Vector3(1, 2, 3)).is_equal_approx(Vector3(1, 2, 3)), "flat, the phone x is right of the TV, y at the TV, z up")
	_check(is_equal_approx(OrientationFusion.swing_side(Vector3(0, 1, 0), full), 0.0), "a swing at the TV aims to the middle")
	_check(OrientationFusion.swing_side(Vector3(1, 1, 0), full) > 0.99, "a swing 45 degrees to the right aims all the way right")
	_check(OrientationFusion.swing_side(Vector3(-0.5, 1, 0), full) < -0.5, "a swing to the left of the TV aims left")
	_check(OrientationFusion.swing_side(Vector3(0.2, 0.1, -1), full) == 0.0, "a swing that is nearly vertical has no side")
	var cal_side := OrientationFusion.swing_side(Vector3(1, 1, 0), full, PI / 4.0)
	_check(absf(cal_side) < 0.01 and OrientationFusion.swing_side(Vector3(0, 1, 0), full, PI / 4.0) < -0.99,
			"a swing is measured from the calibrated heading: the calibrated one is straight, the old straight is now left")
	var auto := PlayerInput.new(4, {})
	for i in 12:   # A player whose swings all go 20 degrees (0.35 rad) to the side: that becomes "straight".
		auto.last_swing = {"azimuth": 0.35}
		auto._follow_heading(0.35)
	_check(absf(auto.heading - 0.35) < 0.05, "the heading follows the swings of the player by itself")
	var first := PlayerInput.new(5, {})
	first._follow_heading(0.35)
	_check(first.heading > 0.05 and first.heading < 0.3, "the first swing moves the heading only part of the way")
	auto.recenter()
	_check(auto.heading == 0.0, "a recenter clears the heading")
	var u := OrientationFusion.new({})   # Held upright like a racket grip, the screen to the player: the TV is away from the screen.
	u.update(0, Vector3.ZERO, Vector3(0, 9.81, 0))
	_check(u.to_world(Vector3(0, 0, -1)).is_equal_approx(Vector3(0, 1, 0)) and u.to_world(Vector3(1, 0, 0)).x > 0.99,
			"upright, away from the screen is toward the TV and the phone x is still right")
	t = _send(p, t, UP, 100)
	_check(got.size() == 2, "a swing inside the wait of 0.4 s after the last one is ignored")
	# The timestamp runs over the u32 wrap: the time step must stay 17 ms, not a huge number.
	var w := PlayerInput.new(1, {})
	var wrapped: Array = []
	w.swung.connect(func(info): wrapped.append(info))
	var tw := 0xFFFFFFFF - 300
	for i in 20:
		w.on_sensor(_packet(tw & 0xFFFFFFFF, Vector3.ZERO), 100000 + i * 17)
		tw += 17
	_send(w, tw, UP, 100)
	_check(wrapped.size() == 1, "a swing over the u32 wrap of the timestamp is found")
	p.reset()
	_check(p.swing_count == 0 and p.last_swing.is_empty(), "a slot that is reset starts again without swings")


# ---- Issues #141 and #142: made-up sensor series for Bowling (2026-10-29) ----

## The detector as Bowling sets it (bowling_game.gd `_game_ready()`) for `level`.
func _pins(level := "medium") -> SwingDetector:
	var d := SwingDetector.new()
	d.threshold = float(BowlingRules.level(level).threshold)
	d.min_back = BowlingGame.MIN_BACK
	d.min_forward = BowlingGame.MIN_FORWARD
	d.max_reversals = 1
	d.fwd_ratio = SwingDetector.FWD_RATIO
	return d


## The phone moves `cm` to the side in `seconds` and stops (one sine of acceleration: out, then back): a hand that carries it.
func _sideways(cm: float, seconds: float, axis := Vector3(1, 0, 0)) -> R.Trace:
	var peak := TAU * cm / 100.0 / (seconds * seconds)
	var t := R.Trace.new()
	var n := int(round(seconds / R.DT))
	for i in n:
		t.add(axis.normalized() * peak * sin(TAU * float(i) / float(n)))
	return t


func _throws(d: SwingDetector, trace: R.Trace) -> int:
	return R.run_detector(d, R.still(0.3).append(trace).append(R.still(2.0))).releases.size()


func _not_a_throw() -> void:
	print("issue #141: moves that are not a swing")
	var cases := {}
	for cm_s in [[20.0, 0.3], [30.0, 0.4], [50.0, 0.5], [40.0, 0.3], [15.0, 0.25]]:
		var peak: float = TAU * cm_s[0] / 100.0 / (cm_s[1] * cm_s[1])
		cases["a move of %d cm to the side in %.2f s (%.0f m/s2)" % [cm_s[0], cm_s[1], peak]] = _sideways(cm_s[0], cm_s[1])
	var x := Vector3(-1, 0, 0)
	cases["a sideways move with a harder stop (the push 1.2 times the start)"] = R.stroke(x, 12.0, 14.0, 0.2, 0.2)
	for hz in [2.0, 3.0, 4.0, 5.0]:
		for amp in [8.0, 15.0]:
			cases["a shake of %d Hz at %d m/s2" % [hz, amp]] = R.shake(1.0, amp, hz)
			cases["three waves of %d Hz at %d m/s2" % [hz, amp]] = R.shake(3.0 / hz, amp, hz)
	cases["20 s of brisk walking"] = R.walk(20.0, Vector3(0, 0, 1), 2.0, [2.0, 4.0, 6.0, 3.0, 5.0])
	cases["a tap (100 m/s2 for one step)"] = R.tap(100.0)
	cases["the stop of a back swing (back 8, a push of 10 the other way)"] = R.stroke(Vector3(0, 1, 0), 8.0, 0.0, 0.2, 0.2, 10.0)
	var bad := []
	for name in cases:
		for who in ["Bowling Medium", "Bowling Easy", "Bowling Hard"]:
			var d := _pins(who.get_slice(" ", 2).to_lower())
			if _throws(d, cases[name]) > 0:
				bad.append("%s: %s" % [who, name])
	_check(bad.is_empty(), "%d moves (sideways, shakes, walking, a tap, a stop) throw nothing in 3 levels. Thrown: %s" %
			[cases.size(), "; ".join(bad)])
	# A move to the side and then a real swing: the swing still throws, once.
	var d2 := _pins()
	var both := _sideways(30.0, 0.4).append(R.still(1.0)).append(R.stroke(Vector3(0, 1, 0), 8.0, 20.0))
	_check(_throws(d2, both) == 1, "a move to the side and then, a second later, a real swing throw once")
	# The stop of the back swing is not the throw: the real forward swing after it is, with its own power.
	var d3 := _pins()
	var stop_then := R.stroke(Vector3(0, 1, 0), 8.0, 25.0, 0.2, 0.2, 10.0)
	var res := R.run_detector(d3, R.still(0.3).append(stop_then).append(R.still(2.0)))
	var pw := float(res.releases[0].power) if res.releases.size() == 1 else -1.0
	_check(pw > 0.5, "a back swing, its stop and the forward swing throw once with the power of the forward swing (%.2f)" % pw)
	_check(SwingDetector.new().fwd_ratio == 0.0, "the rule is off by default (Tennis keeps its own rule)")


## Issue #432 (Test 23 step 4g): two recordings of a real fast shake from the owner's phone (tests/fixtures/shake_432, recorded
## with the sensor recorder of the TV, label hard_shake, 2026-11-12). A shake that starts from rest has a weak first half cycle
## and a hard second one, about 0.1 s each, so with `min_back` 0.1 and the ratio rule alone it threw a ball at its start. Bowling
## now has `min_back` 0.12 and `min_forward` 0.1: a shake throws nothing, in the three levels. The price: a wind-up shorter than
## 0.12 s and a push barely above the threshold (peak 7 m/s2, over in 0.07 s) no longer throw.
func _real_shakes_432() -> void:
	print("issue #432: real shakes")
	_check(is_equal_approx(BowlingGame.MIN_BACK, 0.12) and is_equal_approx(BowlingGame.MIN_FORWARD, 0.1),
			"Bowling sets min_back 0.12 s and min_forward 0.1 s")
	for n in [1, 2]:
		var parsed := SensorRecorder.parse(FileAccess.get_file_as_string("res://tests/fixtures/shake_432/hard_shake_%d.csv" % n))
		var grid := SensorRecorder.resample(parsed)
		var trace := R.Trace.new()
		for i in grid.lin.size():
			trace.add(grid.lin[i], grid.gyro[i])
		_check(parsed.ok and trace.size() > 240, "the recording %d is read (%d steps)" % [n, trace.size()])
		var old := SwingDetector.new()   # Bowling before the fix: min_back 0.1, no min_forward.
		old.threshold = float(BowlingRules.level("medium").threshold)
		old.min_back = 0.1
		old.max_reversals = 1
		old.fwd_ratio = SwingDetector.FWD_RATIO
		_check(R.run_detector(old, trace).releases.size() == 1, "recording %d: the old rules throw a ball (the bug)" % n)
		for level in ["easy", "medium", "hard"]:
			_check(R.run_detector(_pins(level), trace).releases.is_empty(),
					"recording %d: a fast shake throws nothing in Bowling %s" % [n, level])
	var y := Vector3(0, 1, 0)
	var gone := {"a wind-up of 0.1 s": R.stroke(y, 10.0, 25.0, 0.1, 0.15),
			"a push of 7 m/s2 (barely above the threshold)": R.stroke(y, 4.5, 7.0)}
	for name in gone:
		_check(_throws(_pins(), gone[name]) == 0, "since #432 not a throw: %s" % name)
	# min_forward on its own: a push that is over in 0.08 s is not a throw, one of 0.2 s is.
	var short := SwingDetector.new()
	short.min_forward = 0.1
	short.fwd_ratio = SwingDetector.FWD_RATIO
	var fw := Vector3(0, 1, 0)
	var short_push := R.still(0.3).append(R.stroke(fw, 8.0, 30.0, 0.25, 0.08)).append(R.still(2.0))
	_check(R.run_detector(short, short_push).releases.is_empty(),
			"min_forward: a hard push that is over in 0.08 s is not a throw")
	var long_push := SwingDetector.new()
	long_push.min_forward = 0.1
	long_push.fwd_ratio = SwingDetector.FWD_RATIO
	var long_trace := R.still(0.3).append(R.stroke(fw, 8.0, 30.0, 0.25, 0.2)).append(R.still(2.0))
	_check(R.run_detector(long_push, long_trace).releases.size() == 1,
			"min_forward: a push of 0.2 s throws once")
	_check(SwingDetector.new().min_forward == 0.0, "the rule is off by default (Tennis and Mini Golf keep their own rules)")


func _real_swings() -> void:
	print("issue #142: real swings that must throw")
	var y := Vector3(0, 1, 0)
	var cases := {
		"soft (back 5, forward 10 m/s2)": R.stroke(y, 5.0, 10.0),
		"soft and slow (back 4.5, forward 9, 0.3 s each)": R.stroke(y, 4.5, 9.0, 0.3, 0.3),
		"a gentle back swing (back 3.5, forward 10)": R.stroke(y, 3.5, 10.0),
		"a gentle back swing (back 4.2, forward 12)": R.stroke(y, 4.2, 12.0),
		"medium (back 8, forward 18)": R.stroke(y, 8.0, 18.0),
		"hard (back 10, forward 32)": R.stroke(y, 10.0, 32.0),
		"a long back swing (0.5 s)": R.stroke(y, 6.0, 20.0, 0.5, 0.2),
		"a wide slow swing (0.4 s each way)": R.stroke(y, 6.0, 14.0, 0.4, 0.4),
		"a pause of 0.4 s between the back and the forward swing":
				R.back_swing(y, 8.0, 0.25).append(R.still(0.4)).append(R.forward_swing(y, 20.0, 0.2)),
		"a forward swing 45 degrees off the back axis":
				R.back_swing(y, 8.0, 0.25).append(R.forward_swing(Vector3(0.7071, 0.7071, 0), 20.0, 0.2)),
		"a soft swing with sensor noise (1 m/s2)": R.noisy(R.stroke(y, 5.0, 10.0), 1.0, 3),
		"a medium swing with sensor noise (1.5 m/s2)": R.noisy(R.stroke(y, 8.0, 18.0), 1.5, 4),
	}
	var missed := []
	for name in cases:
		for who in ["Bowling Easy", "Bowling Medium", "Bowling Hard"]:
			var d := _pins(who.get_slice(" ", 2).to_lower())
			if _throws(d, cases[name]) != 1:
				missed.append("%s: %s" % [who, name])
	_check(missed.is_empty(), "%d real swings, soft to hard, throw exactly once in 3 levels. Missed: %s" %
			[cases.size(), "; ".join(missed)])
	var easy := _pins("easy")
	_check(_throws(easy, R.stroke(y, 4.5, 6.0, 0.25, 0.25)) == 1, "Bowling Easy counts an even lighter swing (back 4.5, forward 6)")
	var powers := []
	for fwd in [9.0, 18.0, 32.0]:
		powers.append(float(R.run_detector(_pins(), R.still(0.3).append(R.stroke(y, 5.0, fwd)).append(R.still(2.0))).releases[0].power))
	_check(powers[0] < powers[1] and powers[1] < powers[2], "the power still grows with the swing: %s" % str(powers))


# ---- Issue #209: the speed gate of Mini Golf (2026-11-01) ----

## The detector as Mini Golf sets it: the strengths are the constants of the game (read here, so that the test follows them).
func _golf(level_threshold := 1.0) -> SwingDetector:
	var c: Dictionary = load("res://scripts/game/mini_golf/mini_golf_game.gd").get_script_constant_map()
	var d := SwingDetector.new()
	d.threshold = level_threshold
	d.back_accel = c.LIGHT_BACK_ACCEL
	d.fwd_accel = c.LIGHT_FWD_ACCEL
	d.fwd_full = c.FULL_FWD
	d.speed_gate = SwingDetector.GATE_SPEED
	d.max_reversals = c.MAX_REVERSALS
	return d


func _golf_gate() -> void:
	print("issue #209: the hand speed gate (Mini Golf)")
	var x := Vector3(1, 0, 0)
	var moves := {
		"a move of 20 cm in 0.3 s": _sideways(20.0, 0.3), "a move of 30 cm in 0.4 s": _sideways(30.0, 0.4),
		"a move of 50 cm in 0.5 s": _sideways(50.0, 0.5), "a move of 15 cm in 0.25 s": _sideways(15.0, 0.25),
		"a 3 Hz shake of 8 m/s2": R.shake(1.0, 8.0, 3.0), "a 5 Hz shake of 8 m/s2": R.shake(1.0, 8.0, 5.0),
		"15 s of walking": R.walk(15.0, Vector3(0, 0, 1), 2.0, [2.0, 4.0, 6.0, 3.0, 5.0]),
	}
	var bad := []
	for name in moves:
		for th in [1.0]:   # Every level of Mini Golf has the factor 1.0 since 2026-11-03.
			if _throws(_golf(th), moves[name]) > 0:
				bad.append("%s (threshold %.1f)" % [name, th])
	_check(bad.is_empty(), "moves to the side, slow shakes and walking do not putt. Putted: %s" % "; ".join(bad))
	var missed := []
	for fwd in [10.0, 14.0, 20.0, 30.0]:
		for th in [1.0]:
			var res := R.run_detector(_golf(th), R.still(0.3).append(R.pendulum(x, 9.0, fwd, 0.25)).append(R.still(2.0)))
			# The back swing and its brake are 0.5 s long (from step 18): the putt is the forward swing after them.
			if res.releases.size() != 1 or int(res.releases[0].step) < 18 + 30:
				missed.append("forward %.0f, threshold %.1f: %s" % [fwd, th, str(res.releases)])
	_check(missed.is_empty(), "a pendulum putt (back 9 and brake, forward 10 to 30) putts once, after the forward swing. Wrong: %s"
			% "; ".join(missed))
	# A light putt (owner, 2026-11-03): a gentle back swing and a gentle forward swing, as for a putt close to the hole. Mini
	# Golf finds it and gives the weakest power; a detector with the common values (Bowling, Tennis) does not change.
	var light := R.still(0.3).append(R.pendulum(x, 3.5, 5.5, 0.25)).append(R.still(2.0))
	var light_golf := _golf(1.0)
	var res_light := R.run_detector(light_golf, light)
	_check(res_light.releases.size() == 1 and light_golf.power < 0.2,
			"a light putt (back 3.5, forward 5.5 m/s2) is found once by Mini Golf, with a small power (%s)" % str(res_light.releases))
	_check(_throws(SwingDetector.new(), light) == 0, "the common detector does not find that light swing: its values are unchanged")
	var defaults := SwingDetector.new()
	_check(defaults.back_accel == SwingDetector.BACK_ACCEL and defaults.fwd_accel == SwingDetector.FWD_ACCEL
			and defaults.fwd_full == SwingDetector.FWD_FULL, "the strengths of a new detector are the common constants")
	# Issue #209 item 1 (2026-11-06): a very hard shake (25 m/s2 or more, 2 to 3 Hz) passed the speed gate, because the hand
	# does move at the push. A shake turns the acceleration round again and again, a putt only once (the brake of the back swing).
	# MADE-UP series (SensorReplay), not recordings: the limit is a first guess (Test 26 step 16h).
	var hard := {}
	for amp in [25.0, 30.0, 40.0]:
		for hz in [2.0, 3.0, 5.0]:
			if amp == 40.0 and hz == 2.0:
				continue   # Still putts (one swing of 0.25 s each way is a hard pendulum): the known limit, Test 26 step 16h.
			hard["a %.0f Hz shake of %.0f m/s2" % [hz, amp]] = R.shake(1.0, amp, hz)
	var shook := []
	for name in hard:
		if _throws(_golf(), hard[name]) > 0:
			shook.append(name)
	_check(shook.is_empty(), "a hard shake (made-up, 25 to 40 m/s2, 2 to 5 Hz, but not 40 at 2 Hz) does not putt. Putted: %s"
			% "; ".join(shook))
	var lost := []
	for back in [6.0, 9.0, 14.0]:
		for fwd in [10.0, 20.0, 30.0]:
			for s in [0.2, 0.3, 0.45]:
				if _throws(_golf(), R.pendulum(x, back, fwd, s)) != 1:
					lost.append("back %.0f forward %.0f, %.2f s" % [back, fwd, s])
	_check(lost.is_empty(), "made-up pendulum putts (back 6 to 14, forward 10 to 30, 0.2 to 0.45 s) still putt with the shake rule."
			+ " Lost: %s" % "; ".join(lost))
	_check(_golf().max_reversals == 1 and SwingDetector.new().max_reversals == 0,
			"Mini Golf allows one turn round (the brake), the default is off")
	var plain := SwingDetector.new()
	_check(_throws(plain, R.pendulum(x, 9.0, 14.0, 0.25)) == 1 and plain.speed_gate == 0.0,
			"the gate is off by default (Bowling and Tennis keep their rules)")
	var tennis := PlayerInput.new(0, {}).swing
	_check(tennis.speed_gate == 0.0 and tennis.fwd_ratio == 0.0 and tennis.max_reversals == 0 and tennis.hand_speed,
			"Tennis keeps its detector: no speed gate, no ratio, the hand speed and strike rules (issue #209 item 4)")
