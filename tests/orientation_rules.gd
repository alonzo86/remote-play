extends SceneTree
## The sensor fusion of the TV (scripts/input/orientation.gd): the tilt of a phone that is tilted too far (Paint Grab, REQ-PG-7)
## and the calm phone that a hand-over of Mini Golf waits for (REQ-MG-4). The basic tilt and yaw checks are in tests/run_tests.gd.
## Run: godot --headless --path . --script tests/orientation_rules.gd -- --role=controller

const OrientationFusion = preload("res://scripts/input/orientation.gd")

const G := 9.81
const FLAT := Vector3(0, 0, G)

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
	_tilt_past_90_degrees()
	_calm()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Feeds `seconds` of one reading at 60 Hz and returns the last timestamp (ms).
func _feed(o: OrientationFusion, seconds: float, gyro: Vector3, accel: Vector3, start_ts := 0) -> int:
	var ts := start_ts
	for i in int(seconds * 60.0):
		ts += 17
		o.update(ts, gyro, accel)
	return ts


## The right side of the phone goes down by `deg` degrees.
func _right_down(deg: float) -> Vector3:
	var r := deg_to_rad(deg)
	return Vector3(-sin(r), 0, cos(r)) * G


## The sine of the angle falls again past 90 degrees. A phone that was tilted too far then pushed a ball back the other way and
## the ball came back to the middle only after the phone had come back (owner feedback, 2026-11-06).
func _tilt_past_90_degrees() -> void:
	print("tilt past 90 degrees")
	var o := OrientationFusion.new({})
	var ts := _feed(o, 1.0, Vector3.ZERO, FLAT)
	var prev := 0.0
	var steps := []
	var never_falls := true
	for deg in [30.0, 60.0, 85.0, 100.0, 120.0, 150.0]:
		ts = _feed(o, 2.0, Vector3.ZERO, _right_down(deg), ts)
		var tx: float = o.tilt().x
		steps.append("%.2f" % tx)
		never_falls = never_falls and tx >= prev - 0.02
		prev = tx
	_check(never_falls, "the tilt only grows from 30 to 150 degrees: %s" % str(steps))
	_check(o.tilt().x > 0.95, "150 degrees to the right is the full tilt to the right (%.2f)" % o.tilt().x)
	ts = _feed(o, 3.0, Vector3.ZERO, FLAT, ts)
	_check(o.tilt().length() < 0.05, "back flat, the tilt is gone (%.3f)" % o.tilt().length())
	# The same on the other axis (the top of the phone up) and in a diagonal: the direction stays, the size is full.
	var r := deg_to_rad(120.0)
	ts = _feed(o, 2.0, Vector3.ZERO, Vector3(0, sin(r), cos(r)) * G, ts)
	_check(o.tilt().y > 0.95 and absf(o.tilt().x) < 0.1,
			"120 degrees top up is the full tilt forward (%.2f, %.2f)" % [o.tilt().x, o.tilt().y])
	ts = _feed(o, 3.0, Vector3.ZERO, FLAT, ts)
	var d := Vector3(-sin(r), sin(r), 2.0 * cos(r)).normalized() * G
	_feed(o, 2.0, Vector3.ZERO, d, ts)
	_check(o.tilt().x > 0.5 and o.tilt().y > 0.5 and o.tilt().length() > 0.9,
			"a diagonal tilt of 120 degrees keeps its direction (%.2f, %.2f)" % [o.tilt().x, o.tilt().y])


## `calm_s` counts how long the phone has been held steady. A phone that is turned or pushed is not calm.
func _calm() -> void:
	print("calm phone")
	var o := OrientationFusion.new({})
	var ts := _feed(o, 1.0, Vector3.ZERO, FLAT)
	_check(o.calm_s > 0.8, "a steady phone is calm (%.2f s)" % o.calm_s)
	ts = _feed(o, 0.2, Vector3(0, 0, 1.5), FLAT, ts)
	_check(o.calm_s == 0.0, "a phone that turns at 1.5 rad/s is not calm")
	ts = _feed(o, 0.5, Vector3.ZERO, FLAT, ts)
	_check(o.calm_s > 0.4 and o.calm_s < 0.6, "it is calm again 0.5 s after it stops (%.2f s)" % o.calm_s)
	ts = _feed(o, 0.2, Vector3.ZERO, FLAT + Vector3(0, 6.0, 0), ts)
	_check(o.calm_s == 0.0, "a push of 6 m/s2 is not calm")
	ts = _feed(o, 1.0, Vector3(0.1, -0.1, 0.1), FLAT + Vector3(0.3, 0.2, 0.0), ts)
	_check(o.calm_s > 0.8, "the shake of a hand that holds the phone still is calm (%.2f s)" % o.calm_s)
