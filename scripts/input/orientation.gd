extends RefCounted
## Sensor fusion on the TV. Input: raw gyroscope (rad/s) and accelerometer (m/s^2)
## in the phone frame (x right, y top of phone, z out of the screen).
## Output: tilt (for tray-style games) and pointer (for aiming games).
## Gravity direction is tracked with a complementary filter.
## Yaw comes from the gyroscope only, so it drifts. Recenter removes the offset.

const G := 9.81
const ACCEL_TRUST_BAND := 2.5   # Trust the accelerometer only near 1 g.
const BLEND := 0.03             # Accelerometer weight for each sample.
const STILL_GYRO := 0.08        # rad/s. Below this the phone counts as still.
const STILL_TIME_FOR_BIAS := 0.5
const BIAS_RATE := 0.02

var settings: Dictionary

var up := Vector3(0, 0, 1)      # World "up" in the phone frame.
var yaw := 0.0                  # Radians. Positive = phone turns left.
var gyro_bias := Vector3.ZERO
var still := false
## True while a swing runs: the accelerometer then holds the push of the hand, not gravity, so `up` follows the gyroscope only.
var hold_accel := false

var _initialized := false
var _last_ts := -1
var _still_time := 0.0
var _ref_up := Vector3(0, 0, 1)
var _ref_yaw := 0.0
var _ref_elev := 0.0
var _north := Vector3(0, 1, 0)  # The horizontal direction at the TV (the heading at the last recenter), in the phone frame.


func _init(p_settings: Dictionary = {}) -> void:
	settings = p_settings


func update(ts_ms: int, gyro: Vector3, accel: Vector3) -> void:
	var dt := 0.0
	if _last_ts >= 0:
		var d := ts_ms - _last_ts
		if d < 0:
			d += 0x100000000 # u32 wrap
		dt = clampf(d / 1000.0, 0.0, 0.1)
	_last_ts = ts_ms

	var sign_a := -1.0 if settings.get("invert_tilt", false) else 1.0
	var a := accel * sign_a
	var alen := a.length()
	if not _initialized:
		if alen > 0.1:
			up = a / alen
			_initialized = true
			recenter()
		return

	var w := gyro - gyro_bias
	# A fixed world vector rotates by -w in the phone frame.
	up = (up - w.cross(up) * dt).normalized()
	_north = _flatten(_north - w.cross(_north) * dt)
	if alen > 0.1 and absf(alen - G) < ACCEL_TRUST_BAND and not hold_accel:
		up = up.lerp(a / alen, BLEND).normalized()

	# Stationary detection: freeze yaw and learn the gyro bias.
	var moving := (gyro - gyro_bias).length() > STILL_GYRO or absf(alen - G) > 0.6
	if moving:
		_still_time = 0.0
		still = false
	else:
		_still_time += dt
		still = true
		if _still_time > STILL_TIME_FOR_BIAS:
			gyro_bias = gyro_bias.lerp(gyro, BIAS_RATE)

	if not still:
		var sign_y := -1.0 if settings.get("invert_yaw", false) else 1.0
		yaw += w.dot(up) * dt * sign_y


func recenter() -> void:
	# The TV is where the phone points: its top when it lies flat, else away from the screen (a racket grip, screen to the player).
	_north = _flatten(Vector3(0, 1, 0) if absf(up.z) > 0.8 else Vector3(0, 0, -1))
	_ref_up = up
	_ref_yaw = yaw
	_ref_elev = _elevation()


## The part of `v` that is horizontal (no `up` part), as a unit vector. A zero vector when `v` is vertical.
func _flatten(v: Vector3) -> Vector3:
	var h := v.slide(up)
	return h.normalized() if h.length() > 0.001 else Vector3.ZERO


func _elevation() -> float:
	return asin(clampf(up.y, -1.0, 1.0))


## Tray tilt. x: positive = right side down. y: positive = top of phone up
## (ball rolls toward the player). Range about -1..1 (sin of the angle).
func tilt() -> Vector2:
	var d := up - _ref_up
	return Vector2(clampf(-d.x, -1.0, 1.0), clampf(d.y, -1.0, 1.0))


## Pointer in -1..1 on both axes. The phone y axis points at the TV.
func pointer() -> Vector2:
	var range_rad := deg_to_rad(float(settings.get("pointer_range_deg", 25.0)))
	var yaw_rel := wrapf(yaw - _ref_yaw, -PI, PI)
	var elev_rel := _elevation() - _ref_elev
	return Vector2(
		clampf(-yaw_rel / range_rad, -1.0, 1.0),
		clampf(-elev_rel / range_rad, -1.0, 1.0))


## The turn of the phone since the last recenter, in radians. Positive = the phone turned left (the same yaw as `pointer()`,
## before
## its range is applied). Bowling uses it with its own range (REQ-BW-4).
func yaw_offset() -> float:
	return wrapf(yaw - _ref_yaw, -PI, PI)


## The acceleration of the phone without gravity (m/s2, phone frame) for a raw accelerometer reading: the reading minus gravity
## along
## `up`. A phone that lies still gives about zero. Bowling finds its swing in it (REQ-BW-5).
func linear_accel(raw: Vector3) -> Vector3:
	var sign_a := -1.0 if settings.get("invert_tilt", false) else 1.0
	return raw * sign_a - up * G


## A vector of the phone frame in the world frame: x = to the right of the TV, y = toward the TV, z = up. It follows the
## heading of the last recenter. A phone with no heading gives zero for x and y.
func to_world(v: Vector3) -> Vector3:
	if _north == Vector3.ZERO:
		return Vector3(0.0, 0.0, v.dot(up))
	return Vector3(v.dot(_north.cross(up)), v.dot(_north), v.dot(up))


## The direction of a world vector (see `to_world()`) around the vertical: 0 is the heading of the last recenter, positive to the
## right (rad). Zero when the vector is nearly vertical.
static func azimuth(world: Vector3) -> float:
	if Vector2(world.x, world.y).length() < 0.25 * world.length():
		return NAN
	return atan2(world.x, world.y)


## Left or right of a swing, from -1 (to the left of the TV) to 1 (to the right), for a world vector `world`: its `azimuth()`
## minus `heading` (the azimuth that the player calibrated as "straight at the TV"), full at `full_rad`. A swing that goes
## straight up or down has no side and gives 0. The wrist turn and the tilt of the phone do not matter (REQ-TN-7).
static func swing_side(world: Vector3, full_rad: float, heading := 0.0) -> float:
	var az := azimuth(world)
	if is_nan(az):
		return 0.0
	return clampf(wrapf(az - heading, -PI, PI) / full_rad, -1.0, 1.0)
