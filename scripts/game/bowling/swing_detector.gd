extends RefCounted
## Finds a bowling swing in the motion of a phone (REQ-BW-5, 6). It reads the acceleration without gravity (m/s2, in the phone
## frame) and does not need to know how the phone is held: the first strong move is the back swing and it gives the swing axis;
## the strong move the other way along that axis is the forward swing, and the ball is let go at its fastest point. The speed of
## the ball comes from the strength of the forward swing. Pure logic: the game gives it the numbers, so it can be tested with
## recorded or made-up traces.

const BACK_ACCEL := 4.0        # A move stronger than this (m/s2) for BACK_TIME is the back swing.
const BACK_TIME := 0.06
const FWD_ACCEL := 8.0         # A move the other way stronger than this is the forward swing.
const FWD_FULL := 30.0         # The forward strength of the strongest ball.
const SWING_WINDOW := 1.5      # A back swing with no forward swing after this time (s) is dropped: the aim is free again.
const FORWARD_MAX := 1.0       # A forward swing is over after this time.
const RELEASE_AT := 0.5        # The ball goes when the forward strength falls below this share of its peak.
const LOCK_AFTER := 1.5        # After a throw the detector waits this long (s).

enum State { READY, BACK, FORWARD, LOCKED }

var state := State.READY
## True from the start of the back swing until the throw is done or dropped: the aim must not change (REQ-BW-5).
var aim_locked := false
## One-shot flags that are true after the `update()` in which they happened.
var released := false
var weak := false
## The strength of the throw from 0 to 1, valid after `released`.
var power := 0.0
## The factor on the thresholds (Easy counts a lighter swing, REQ-BW-17).
var threshold := 1.0

var _above := 0.0
var _sum := Vector3.ZERO
var _axis := Vector3.ZERO
var _time := 0.0
var _peak := 0.0


func reset() -> void:
	state = State.READY
	aim_locked = false
	released = false
	weak = false
	power = 0.0
	_above = 0.0
	_sum = Vector3.ZERO
	_time = 0.0
	_peak = 0.0


## Feeds the acceleration without gravity for `delta` seconds.
func update(delta: float, lin: Vector3) -> void:
	released = false
	weak = false
	match state:
		State.READY:
			_update_ready(delta, lin)
		State.BACK:
			_update_back(delta, lin)
		State.FORWARD:
			_update_forward(delta, lin)
		State.LOCKED:
			_time += delta
			if _time >= LOCK_AFTER:
				reset()


func _update_ready(delta: float, lin: Vector3) -> void:
	if lin.length() > BACK_ACCEL * threshold:
		_above += delta
		_sum += lin * delta
		if _above >= BACK_TIME:
			_axis = _sum.normalized()
			state = State.BACK
			aim_locked = true
			_time = 0.0
	else:
		_above = 0.0
		_sum = Vector3.ZERO


func _update_back(delta: float, lin: Vector3) -> void:
	_time += delta
	var f := -lin.dot(_axis)
	if f > FWD_ACCEL * threshold:
		state = State.FORWARD
		_peak = f
		_time = 0.0
	elif _time > SWING_WINDOW:
		weak = true
		reset()
		weak = true   # reset() clears the flag; the game shows "Swing a bit more!".


func _update_forward(delta: float, lin: Vector3) -> void:
	_time += delta
	var f := -lin.dot(_axis)
	_peak = maxf(_peak, f)
	if f < _peak * RELEASE_AT or _time > FORWARD_MAX:
		var low := FWD_ACCEL * threshold
		power = clampf((_peak - low) / (FWD_FULL - low), 0.0, 1.0)
		released = true
		state = State.LOCKED
		_time = 0.0
