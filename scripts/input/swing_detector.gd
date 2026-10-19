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
const FWD_SPEED := 0.15        # The hand must move forward this fast (m/s) too: the stop of the back swing is a push, not a move.
const SPEED_LEAK := 0.4        # The speed estimate fades by this rate per second (errors add up in a long back swing).
const FWD_FAST := 1.5          # A forward move this fast (m/s) counts even without a sharp push: a smooth, wide swing.
const FWD_FAST_FULL := 3.0     # The forward speed of the strongest ball.
const STRIKE_ACCEL := 20.0     # A sharp push stronger than this (m/s2) for STRIKE_TIME is the forward swing, in any direction:
const STRIKE_TIME := 0.03      # the back swing is gentle (6 to 10), the hit is 25 to 50.
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
## Tennis finds the swing with the speed of the hand and a sharp strike (a gentle back swing, then a hard push in any
## direction, see `STRIKE_ACCEL`). Pin Pals and Mini Golf keep the plain rule: a back swing, then a push the other way.
var hand_speed := false
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
var _peak_speed := 0.0
var _strike := 0.0
var _strike_sum := Vector3.ZERO
var _speed := 0.0   # The speed of the hand along the swing axis (m/s), forward positive, from the start of the back swing.


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
	_speed = 0.0
	_peak_speed = 0.0
	_strike = 0.0
	_strike_sum = Vector3.ZERO


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
	if _check_strike(delta, lin):
		return
	if lin.length() > BACK_ACCEL * threshold:
		_above += delta
		_sum += lin * delta
		if _above >= BACK_TIME:
			_axis = _sum.normalized()
			_speed = -_sum.length()   # The hand already moves back: it must turn round before a forward swing can count.
			state = State.BACK
			aim_locked = true
			_time = 0.0
	else:
		_above = 0.0
		_sum = Vector3.ZERO


func _update_back(delta: float, lin: Vector3) -> void:
	if _check_strike(delta, lin):
		return
	_time += delta
	var f := -lin.dot(_axis)
	_speed += f * delta - _speed * SPEED_LEAK * delta
	var pushed := f > FWD_ACCEL * threshold
	if hand_speed:
		pushed = (pushed and _speed > FWD_SPEED * threshold) or _speed > FWD_FAST * threshold
	if pushed:
		state = State.FORWARD
		_peak = maxf(f, 0.0)
		_peak_speed = _speed
		_since_peak = 0.0
		_time = 0.0
	elif _time > window:
		weak = true
		reset()
		weak = true   # reset() clears the flag; the game shows "Swing a bit more!".


## A sharp strong push starts the forward swing at once, whatever came before it (a gentle back swing, a small move, nothing).
func _check_strike(delta: float, lin: Vector3) -> bool:
	if not hand_speed or lin.length() <= STRIKE_ACCEL * threshold:
		_strike = 0.0
		_strike_sum = Vector3.ZERO
		return false
	_strike += delta
	_strike_sum += lin * delta
	if _strike < STRIKE_TIME:
		return false
	_axis = -_strike_sum.normalized()
	state = State.FORWARD
	aim_locked = true
	_peak = lin.length()
	_peak_speed = 0.0
	_speed = 0.0
	_since_peak = 0.0
	_time = 0.0
	return true


func _update_forward(delta: float, lin: Vector3) -> void:
	_time += delta
	var f := -lin.dot(_axis)
	_speed += f * delta
	_peak_speed = maxf(_peak_speed, _speed)
	if f >= _peak:
		_peak = f
		_since_peak = 0.0
	else:
		_since_peak += delta
	if f < _peak * RELEASE_AT or _time > FORWARD_MAX:
		var low := FWD_ACCEL * threshold
		var fast_low := FWD_FAST * threshold
		power = clampf((_peak - low) / (FWD_FULL - low), 0.0, 1.0)
		if hand_speed:
			power = maxf(power, clampf((_peak_speed - fast_low) / (FWD_FAST_FULL - fast_low), 0.0, 1.0))
		released = true
		forward_dir = -_axis
		hit_age = _since_peak
		state = State.LOCKED
		_time = 0.0


## True when a forward swing (`forward_dir`, phone frame) goes down in the world: `up` is the world "up" in the phone frame
## (`OrientationFusion.up`). A serve goes from top to bottom (REQ-TN-9).
static func is_down(dir: Vector3, up: Vector3) -> bool:
	return dir.dot(up) < DOWN_SINE


## The axis of the first move (a unit vector) while the detector is in the back swing, else zero.
func axis() -> Vector3:
	return _axis if state == State.BACK else Vector3.ZERO
