extends SceneTree
## What Tennis adds to the swing detector (docs/games/tennis.md, REQ-TN-5 to 9): the wait after a swing, the direction
## and the age of the hit, and the swing of a phone slot on the TV. The back and forward swing itself is tested in
## tests/bowling_rules.gd.
## Run: godot --headless --path . --script tests/swing_detector.gd -- --role=controller

const SwingDetector = preload("res://scripts/input/swing_detector.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")

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
	_check(s.down and s.power > 0.5 and s.power <= 1.0 and s.hit_age_ms > 0.0 and s.has("tilt"),
			"it is a down swing with power (%.2f), the age of the hit (%.0f ms) and the tilt" % [s.power, s.hit_age_ms])
	t = _send(p, t, Vector3(1, 0, 0), 100)
	_check(got.size() == 2 and not got[1].down, "a second swing after the wait is found, and a sideways swing is not down")
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
