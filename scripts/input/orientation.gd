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

var _initialized := false
var _last_ts := -1
var _still_time := 0.0
var _ref_up := Vector3(0, 0, 1)
var _ref_yaw := 0.0
var _ref_elev := 0.0


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
	if alen > 0.1 and absf(alen - G) < ACCEL_TRUST_BAND:
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
	_ref_up = up
	_ref_yaw = yaw
	_ref_elev = _elevation()


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
