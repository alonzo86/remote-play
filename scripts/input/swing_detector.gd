extends RefCounted
## Finds a swing in the sensor stream of one phone, on the TV (no new message: docs/games/tennis.md, REQ-TN-5 to 9).
## A swing starts when the turning speed of the phone (gyroscope, rad/s) rises above START_SPEED. The hit is the
## moment of the highest turning speed. The swing is finished (and reported) when the speed falls to FALL_RATIO of
## the peak, so the report comes a few samples after the hit: `latency_ms` says how many ms later.
## Power comes from the peak speed. The direction comes from the vertical speed of the phone up to the peak,
## found from the accelerometer along the world "up" of the sensor fusion (`OrientationFusion.up`).
## The detector does not know any game. A game decides what a swing means (a hit, a serve, a putt).

const G := 9.81
const START_SPEED := 4.0     # rad/s. A swing starts above this.
const MIN_PEAK := 7.0        # rad/s. A swing with a lower peak is a movement, not a swing.
const MAX_PEAK := 20.0       # rad/s. The peak that gives power 1.0.
const FALL_RATIO := 0.8      # The swing is over when the speed is below this share of the peak.
const MIN_SWING_MS := 40     # A shorter movement is a knock on the phone, not a swing.
const MAX_SWING_MS := 600    # A swing that does not end is closed after this time.
const COOLDOWN_MS := 400     # After a hit the backswing and the arm coming back are not swings.
const VERTICAL_MIN := 0.5    # m/s. A smaller vertical speed at the peak is neither down nor up.

var count := 0               # Swings found.
var last := {}               # The last swing (empty before the first).

var _clock := 0              # ms since the first sample, with the u32 wrap of the timestamp removed.
var _last_ts := -1
var _swinging := false
var _start_clock := 0
var _peak := 0.0
var _peak_clock := 0
var _peak_ts := 0
var _peak_up := Vector3.UP
var _vertical := 0.0         # m/s, integral of the vertical acceleration since the start. Positive is up.
var _vertical_at_peak := 0.0
var _cool_until := 0


## One sample: the phone timestamp (ms), gyroscope (rad/s), accelerometer (m/s2, +G along `up` at rest) and the world
## "up" in the phone frame. Returns the swing that finished with this sample, or an empty Dictionary.
## The swing: `ts` (phone time of the hit), `peak` (rad/s), `power` (0 to 1), `vertical` (m/s, negative is down),
## `down` (true for a clear downward swing, like a serve), `up_dir` (the "up" at the hit: the tilt of the phone) and
## `latency_ms` (how long ago the hit was).
func feed(ts_ms: int, gyro: Vector3, accel: Vector3, up: Vector3) -> Dictionary:
	var dt_ms := 0
	if _last_ts >= 0:
		dt_ms = (ts_ms - _last_ts) & 0xFFFFFFFF   # The u32 wrap.
		if dt_ms > 1000:
			dt_ms = 0   # A pause in the stream (a lost phone): the swing before it is not continued.
			_swinging = false
	_last_ts = ts_ms
	_clock += dt_ms
	var speed := gyro.length()
	if not _swinging:
		if speed > START_SPEED and _clock >= _cool_until:
			_begin(speed, ts_ms, up)
		return {}
	_vertical += (accel.dot(up) - G) * dt_ms / 1000.0
	if speed >= _peak:
		_peak = speed
		_peak_clock = _clock
		_peak_ts = ts_ms
		_peak_up = up
		_vertical_at_peak = _vertical
	if speed < _peak * FALL_RATIO or _clock - _start_clock > MAX_SWING_MS:
		return _finish()
	return {}


func _begin(speed: float, ts_ms: int, up: Vector3) -> void:
	_swinging = true
	_start_clock = _clock
	_peak = speed
	_peak_clock = _clock
	_peak_ts = ts_ms
	_peak_up = up
	_vertical = 0.0
	_vertical_at_peak = 0.0


func _finish() -> Dictionary:
	_swinging = false
	if _peak < MIN_PEAK or _peak_clock - _start_clock < MIN_SWING_MS:
		return {}
	_cool_until = _peak_clock + COOLDOWN_MS
	count += 1
	last = {
		"ts": _peak_ts,
		"peak": _peak,
		"power": clampf((_peak - MIN_PEAK) / (MAX_PEAK - MIN_PEAK), 0.0, 1.0),
		"vertical": _vertical_at_peak,
		"down": _vertical_at_peak < -VERTICAL_MIN,
		"up_dir": _peak_up,
		"latency_ms": _clock - _peak_clock,
	}
	return last
