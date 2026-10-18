extends RefCounted
## Finds a swing in the motion of a phone: a back swing and then a forward swing. Pin Pals throws a ball with it (REQ-BW-5, 6),
## Tennis hits the ball with it (REQ-TN-5 to 9). The game sets `lock_after` and `threshold` and reads `forward_dir` and `hit_age`.
## It reads the acceleration without gravity (m/s2, in the phone
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

## The forward swing is "down" (a serve) when it points this far below the horizon: the sine of the angle (-0.5 is 30 degrees).
const DOWN_SINE := -0.5

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
## The wait after a throw (s). Tennis uses a shorter one than bowling, so that the next ball can be hit.
var lock_after := LOCK_AFTER
## How long (s) a back swing waits for its forward swing. Tennis waits longer, because a player draws back early while the
## ball is still coming.
var window := SWING_WINDOW
## The direction of the forward swing in the phone frame (a unit vector), valid after `released`. With the world "up" of the
## sensor fusion a game finds out if it went down (a serve): `forward_dir.dot(orientation.up) < 0`.
var forward_dir := Vector3.ZERO
## Seconds from the fastest point of the forward swing to `released`: the hit was this long ago.
var hit_age := 0.0

var _above := 0.0
var _sum := Vector3.ZERO
var _axis := Vector3.ZERO
var _time := 0.0
var _peak := 0.0
var _since_peak := 0.0


func reset() -> void:
	state = State.READY
	aim_locked = false
	released = false
	weak = false
	power = 0.0
	forward_dir = Vector3.ZERO
	hit_age = 0.0
	_since_peak = 0.0
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
			if _time >= lock_after:
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
		_since_peak = 0.0
		_time = 0.0
	elif _time > window:
		weak = true
		reset()
		weak = true   # reset() clears the flag; the game shows "Swing a bit more!".


func _update_forward(delta: float, lin: Vector3) -> void:
	_time += delta
	var f := -lin.dot(_axis)
	if f >= _peak:
		_peak = f
		_since_peak = 0.0
	else:
		_since_peak += delta
	if f < _peak * RELEASE_AT or _time > FORWARD_MAX:
		var low := FWD_ACCEL * threshold
		power = clampf((_peak - low) / (FWD_FULL - low), 0.0, 1.0)
		released = true
		forward_dir = -_axis
		hit_age = _since_peak
		state = State.LOCKED
		_time = 0.0


## True when a forward swing (`forward_dir`, phone frame) goes down in the world: `up` is the world "up" in the phone frame
## (`OrientationFusion.up`). A serve goes from top to bottom (REQ-TN-9).
static func is_down(dir: Vector3, up: Vector3) -> bool:
	return dir.dot(up) < DOWN_SINE
