extends RefCounted
## Finds a swing in the motion of a phone: a back swing and then a forward swing. Bowling throws a ball with it (REQ-BW-5, 6),
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
# The sharp push must go against the back swing: its part along the swing axis is at least this share of STRIKE_ACCEL.
const STRIKE_AGAINST := 0.5
const RELEASE_AT := 0.5        # The ball goes when the forward strength falls below this share of its peak.
const REVERSAL_SPAN := 0.5     # See `max_reversals`.
const LOCK_AFTER := 1.5        # After a throw the detector waits this long (s).
const REJECT_GRACE := 0.6      # After a forward swing that `fwd_ratio` rejects, the back swing waits this long (s) more.
const GATE_SPEED := 0.5        # See `speed_gate`: the value Mini Golf sets (m/s; a putt of 10 m/s2 for 0.25 s reaches about 1.6).
const FWD_RATIO := 1.3         # See `fwd_ratio`: the value Bowling sets.

enum State { READY, BACK, FORWARD, LOCKED }

## The forward swing is "down" (a serve) when it points below the horizon by this much: the sine of the angle (-0.1 is about 6
## degrees). It was -0.5 (30 degrees) until 2026-11-08: a real serve was not found on the owner's phone (issue #419).
const DOWN_SINE := -0.1

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
## The strengths (m/s2) that a game may change for itself; the defaults are the constants above, so a game that sets nothing
## keeps its feel. Mini Golf lowers them, because a putt close to the hole is a light swing (REQ-MG-5).
var back_accel := BACK_ACCEL   # A move stronger than this (times `threshold`) for BACK_TIME is the back swing.
var fwd_accel := FWD_ACCEL     # A push the other way stronger than this (times `threshold`) is the forward swing.
var fwd_full := FWD_FULL       # The forward strength of the strongest ball.
## Settings that Tennis uses (owner, 2026-11-06, from the swings that were not found); the defaults keep the feel of the other
## games. `fwd_gain`: a push also counts when the hand has gained this much speed (m/s) since its slowest point in the back swing,
## because the speed estimate of a back swing is off by a lot (the gravity of a turning phone looks like movement): 0 turns it
## off. `forward_hold`: a forward swing that starts weak waits this long (s) before it is let go, so that the real hit that
## follows a few hundredths of a second later is not locked out: 0 turns it off.
var fwd_gain := 0.0
var forward_hold := 0.0
## `strike_against`: how much of a sharp push must go against the back swing, as a share of `STRIKE_ACCEL` (Tennis sets 0: the hit
## of a real stroke often goes the same way as the first move of the back swing, owner logs 2026-11-06).
var strike_against := STRIKE_AGAINST
## `fast_full`: the forward hand speed (m/s) of the strongest ball. Tennis sets 5 (owner logs 2026-11-06: hits felt too strong; a
## sharp hit starts the speed estimate at 0, so it reached the common 3 m/s at almost every hit).
var fast_full := FWD_FAST_FULL
## `strike_without_back`: a sharp push counts as the hit also when no back swing came before it (Tennis: a forward-only swing,
## or a back swing and a forward swing, owner 2026-11-06).
var strike_without_back := false
## The wait after a throw (s). Tennis uses a shorter one than bowling, so that the next ball can be hit.
var lock_after := LOCK_AFTER
## How long (s) a back swing waits for its forward swing. Tennis waits longer, because a player draws back early while the
## ball is still coming.
var window := SWING_WINDOW
## The shortest back swing (s) that a forward swing may follow. A shake goes back and forth in about 0.1 s each way, a wind-up
## takes longer. A push before this time is not counted. 0 turns the rule off (Tennis, Mini Golf).
var min_back := 0.0
## A shake reverses the direction of the acceleration again and again. When this is above 0, a push does not count while the
## acceleration along the swing axis turned round (strongly, more than `BACK_ACCEL`) more than this many times in the last
## `REVERSAL_SPAN` seconds. A real swing turns round once, from the back swing to the forward swing. 0 turns the rule off
## (Tennis, Mini Golf). Bowling sets 1 (REQ-BW-5).
var max_reversals := 0
## A real throw is harder forward than back (the back swing is gentle, the hit is not). When this is above 0, a forward swing
## whose peak is less than this times the peak of the back swing is not a throw: a move to the side or a shake pushes as hard
## on the way back as on the way out (issue #141). The detector then goes back to the back swing and waits for the real forward
## swing, so the stop of a back swing does not throw. 0 turns the rule off (Tennis; Mini Golf, where a putt is a pendulum and
## its forward swing is as soft as its back swing). Bowling sets `FWD_RATIO`.
var fwd_ratio := 0.0
## Tennis finds the swing with the speed of the hand and a sharp strike (a gentle back swing, then a hard push in any
## direction, see `STRIKE_ACCEL`). Bowling and Mini Golf keep the plain rule: a back swing, then a push the other way.
var hand_speed := false
## Mini Golf: the hand must move forward at least this fast (m/s, along the swing axis, times `threshold`) when the forward push
## comes; 0 turns the rule off (Bowling and Tennis). A move to the side or a slow shake ends with the hand stopped: its second
## half is only the brake of the first, so the speed at the push is about zero. The brake of a real back swing is the same: the
## hand is at rest at the top, and the putt is the push after it. Unlike `hand_speed`, there is no sharp strike and no smooth wide
## swing here (a putt is gentle). `GATE_SPEED` is the value Mini Golf sets.
var speed_gate := 0.0
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
var _sign := 0                # The side of the last strong acceleration along the axis (-1 back, 1 forward).
var _reversal_times: Array[float] = []
var _back_peak := 0.0   # The strongest acceleration of the back swing along the axis (m/s2).
var _back_time := 0.0   # How long the back swing had lasted when the forward swing started.
var _speed_min := 0.0   # The lowest `_speed` of this back swing (m/s).
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
	_back_peak = 0.0
	_back_time = 0.0
	_peak_speed = 0.0
	_speed_min = 0.0
	_strike = 0.0
	_strike_sum = Vector3.ZERO
	_sign = 0
	_reversal_times.clear()


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
	if strike_without_back and _check_strike(delta, lin):
		return
	if lin.length() > back_accel * threshold:
		_above += delta
		_sum += lin * delta
		if _above >= BACK_TIME:
			_axis = _sum.normalized()
			_sign = -1
			_reversal_times.clear()
			_back_peak = _sum.length() / _above
			_speed = -_sum.length()   # The hand already moves back: it must turn round before a forward swing can count.
			_speed_min = _speed
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
	_speed_min = minf(_speed_min, _speed)
	_back_peak = maxf(_back_peak, -f)
	_count_reversals(f)
	var shaking := max_reversals > 0 and _reversal_times.size() > max_reversals
	var pushed := f > fwd_accel * threshold and _time >= min_back and not shaking
	if speed_gate > 0.0:
		pushed = pushed and _speed > speed_gate * threshold
	if hand_speed:
		var gained := fwd_gain > 0.0 and _speed - _speed_min > fwd_gain
		pushed = (pushed and (_speed > FWD_SPEED * threshold or gained)) or _speed > FWD_FAST * threshold
	if pushed:
		state = State.FORWARD
		_peak = maxf(f, 0.0)
		_peak_speed = _speed
		_since_peak = 0.0
		_back_time = _time
		_time = 0.0
	elif _time > window:
		weak = true
		reset()
		weak = true   # reset() clears the flag; the game shows "Swing a bit more!".


## Notes a strong turn round of the acceleration along the axis (a shake does it again and again).
func _count_reversals(f: float) -> void:
	var strong := back_accel * threshold
	var side := 1 if f > strong else (-1 if f < -strong else 0)
	if side != 0 and side != _sign:
		_sign = side
		_reversal_times.append(_time)
	while not _reversal_times.is_empty() and _time - _reversal_times[0] > REVERSAL_SPAN:
		_reversal_times.remove_at(0)


## A sharp strong push starts the forward swing at once, but only after a back swing (state BACK) and only against it: a real
## stroke goes back first and then forward (REQ-TN-5). A sharp move with no back swing before it, or one the same way as the
## back swing, is not the hit (it is the back swing).
func _check_strike(delta: float, lin: Vector3) -> bool:
	if not hand_speed or not (state == State.BACK or (strike_without_back and state == State.READY)) \
			or lin.length() <= STRIKE_ACCEL * threshold \
			or (strike_against > 0.0 and -lin.dot(_axis) < STRIKE_ACCEL * threshold * strike_against):
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
	if f < _peak * RELEASE_AT and _time < forward_hold and _peak < STRIKE_ACCEL * threshold:
		return   # A weak start: the real hit may still come in a few hundredths of a second.
	if f < _peak * RELEASE_AT or _time > FORWARD_MAX:
		if fwd_ratio > 0.0 and _back_time > 0.0 and _peak < _back_peak * fwd_ratio:
			# As gentle as the back swing: a move to the side, a shake or the stop of the back swing. Not a throw.
			# Back to the back swing, but only REJECT_GRACE seconds more: the real forward swing after a hard stop comes at once,
			# a player who moved to the side and swings again must not wait for the whole window.
			state = State.BACK
			_time = maxf(_back_time + _time, window - REJECT_GRACE)
			_back_time = 0.0
			return
		var low := fwd_accel * threshold
		var fast_low := FWD_FAST * threshold
		power = clampf((_peak - low) / (fwd_full - low), 0.0, 1.0)
		if hand_speed:
			power = maxf(power, clampf((_peak_speed - fast_low) / (fast_full - fast_low), 0.0, 1.0))
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
