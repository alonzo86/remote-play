extends SceneTree
## What Tennis adds to the swing detector (docs/games/tennis.md, REQ-TN-5 to 9): the wait after a swing, the direction
## and the age of the hit, and the swing of a phone slot on the TV. The back and forward swing itself is tested in
## tests/bowling_rules.gd.
## Run: godot --headless --path . --script tests/swing_detector.gd -- --role=controller

const SwingDetector = preload("res://scripts/input/swing_detector.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const OrientationFusion = preload("res://scripts/input/orientation.gd")

const DT := 1.0 / 60.0
const G := 9.81
const UP := Vector3(0, 0, 1)

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
	_detector_additions()
	_player_slot()
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
	_check(not SwingDetector.is_down(Vector3(1, 0, 0), UP) and not SwingDetector.is_down(Vector3(0, 0, 1), UP)
			and not SwingDetector.is_down(Vector3(0.9, 0, -0.3), UP),
			"a sideways, an upward and a flat swing (less than 30 degrees down) are not down")

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

	# The hit is a sharp strong push in any direction, after a small first move and a gentle slow pull back (found 2026-10-18).
	var strike := SwingDetector.new()
	strike.hand_speed = true
	for i in 12:
		strike.update(DT, Vector3(-8, 0, 0))   # A small first move to the left.
	for i in 30:
		strike.update(DT, Vector3(4, 0, 0))   # A slow gentle pull back to the right.
	_check(not strike.released and strike.state != SwingDetector.State.FORWARD, "a gentle move is not the hit")
	for f in [-30.0, -50.0, -35.0, -20.0, -8.0]:
		strike.update(DT, Vector3(f, 0, 0))   # The sharp push to the left: the hit.
	_check(strike.state == SwingDetector.State.LOCKED and strike.forward_dir.is_equal_approx(Vector3(-1, 0, 0))
			and strike.power > 0.5,
			"a sharp strong push is the hit, in the direction it pushed (power %.2f)" % strike.power)
	var fresh := SwingDetector.new()
	fresh.hand_speed = true
	for f in [30.0, 50.0, 35.0, 20.0, 8.0]:
		fresh.update(DT, Vector3(0, f, 0))
	_check(fresh.state == SwingDetector.State.LOCKED and fresh.forward_dir.is_equal_approx(Vector3(0, 1, 0)),
			"a sharp push alone is the hit too")

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
	t = _send(p, t, UP, 500)
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
