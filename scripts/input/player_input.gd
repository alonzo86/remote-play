extends RefCounted
## State of one player slot on the TV. The network code writes to it.
## Games only read from it. Games must not use any networking script.

const Protocol = preload("res://scripts/core/protocol.gd")
const Lang = preload("res://scripts/core/lang.gd")
const OrientationFusion = preload("res://scripts/input/orientation.gd")
const SwingDetector = preload("res://scripts/input/swing_detector.gd")
const SensorRecorder = preload("res://scripts/input/sensor_recorder.gd")

const SWING_THRESHOLD := 0.75   # Tennis counts a lighter swing than Pin Pals (the factor on the thresholds of the detector).
const SWING_WINDOW_S := 3.0     # A player draws back early: a back swing waits this long (s) for the forward swing.
# A swing 70 degrees (rad) to the side of the TV aims all the way to the side (REQ-TN-7; it was 45 degrees until 2026-11-05:
# almost every shot went to the sideline).
const SWING_SIDE_FULL := 1.2217
const HEADING_PRIOR := 1.0       # The weight of the guess "the TV is where the phone pointed at GO" (azimuth 0).
const HEADING_KEEP := 0.9        # The share of the old swings that stays when a new swing comes (the last ~10 count).
const SWING_HOLD_S := 0.5       # A back swing does not correct gravity from the accelerometer for this long (s).
const SWING_LOCK_S := 0.6   # After a swing the next one can be found after this time (a bowling throw waits 1.5 s).

enum State { EMPTY, CONNECTED, LOST }

signal button_pressed(bit: int)
signal swung(info: Dictionary)   # A swing was thrown (see `_feed_swing()`): the power, the direction and how old the hit is.

## The sensor recorder of the debug overlay (REQ-T7), or null. One for all phones; it records only while it is `recording`.
static var recorder: SensorRecorder = null

var slot := 0
var state: State = State.EMPTY
var player_name := ""   # The name that the TV shows: the profile name, or "Player N"; a second equal name gets a number.
var raw_name := ""      # The name that the phone sent (empty for a guest that sent none).
var profile_id := ""    # The profile ID of the phone, or empty for a guest (FD-22).
var avatar := -1        # The avatar index, or -1 for none: the slot number is shown then.
var color := Color.WHITE
var token := ""
var lost_since_ms := 0

var orientation: OrientationFusion
var swing := SwingDetector.new()   # Fed here for every phone, so that the debug overlay can show swings. Tennis reads `swung`.
var last_swing: Dictionary = {}    # The last `swung` info, empty before the first.
var last_swing_ms := 0             # TV time of the last swing, for the debug overlay.
var swing_count := 0


# Latest raw values
var gyro := Vector3.ZERO
var accel := Vector3.ZERO
var buttons := 0
var touching := false
var touch := Vector2.ZERO

# Link statistics
var rtt_ms := -1.0            # Reported by the phone.
var clock_offset_ms := 0.0    # TV clock minus phone clock. Reported by the phone.
var has_clock := false
var sensor_age_ms := -1.0     # TV receive time minus phone send time (with offset).
var rx_total := 0
var rx_rate := 0.0            # Packets per second, last full second.
var lost_packets := 0
var max_gap_ms := 0           # Longest gap between packets in the last second.
var last_packet_ms := 0

var _last_seq := -1
var _window_start_ms := 0
var _window_count := 0
var _window_max_gap := 0
var _prev_buttons := 0
var _swing_ts := -1
## The azimuth of a swing at the TV (rad, in the world frame of the sensor fusion), and if the player calibrated it.
var heading := 0.0
var _head_x := 0.0               # The weighted mean direction of the swings so far, as a vector (sin, cos).
var _head_y := HEADING_PRIOR
var _hold_s := 0.0
var _fwd_world := Vector3.ZERO   # The forward swing as it happened in the world (x right of the TV, y to the TV, z up).


func _init(p_slot: int, settings: Dictionary) -> void:
	slot = p_slot
	_new_swing_detector()
	color = Protocol.PLAYER_COLORS[p_slot % Protocol.PLAYER_COLORS.size()]
	orientation = OrientationFusion.new(settings)


func is_connected_now() -> bool:
	return state == State.CONNECTED


func is_present() -> bool:
	return state != State.EMPTY


func reset() -> void:
	state = State.EMPTY
	player_name = ""
	raw_name = ""
	profile_id = ""
	avatar = -1
	token = ""
	gyro = Vector3.ZERO
	accel = Vector3.ZERO
	buttons = 0
	_prev_buttons = 0
	touching = false
	rtt_ms = -1.0
	has_clock = false
	sensor_age_ms = -1.0
	rx_total = 0
	rx_rate = 0.0
	lost_packets = 0
	max_gap_ms = 0
	_last_seq = -1
	_window_count = 0
	orientation = OrientationFusion.new(orientation.settings)
	_new_swing_detector()


## The name of a phone that has no profile name: "Player N" in the language of the TV (players.default_name). It is never
## saved, only made when the TV needs it, so it follows the language of the TV.
static func default_name(p_slot: int) -> String:
	return Lang.f("players.default_name", [p_slot + 1])


## Called when a phone (re)joins this slot.
func on_join(p_name: String, p_token: String) -> void:
	raw_name = p_name
	player_name = p_name if p_name != "" else default_name(slot)
	token = p_token
	state = State.CONNECTED
	_last_seq = -1 # Do not count the reconnect gap as packet loss.
	_window_start_ms = Time.get_ticks_msec()
	_window_count = 0


## Sets the profile of this slot. An empty `pid` is a guest: it has no avatar and no profile name.
func set_profile(pid: String, av: int, p_name: String) -> void:
	profile_id = pid
	avatar = av if pid != "" else -1
	raw_name = p_name


## True when this player has a profile (the TV shows the avatar and the name, FD-22).
func has_profile() -> bool:
	return profile_id != ""


func on_lost() -> void:
	if state == State.CONNECTED:
		state = State.LOST
		lost_since_ms = Time.get_ticks_msec()
		buttons = 0
		_prev_buttons = 0
		touching = false


func on_sensor(pkt: Dictionary, now_ms: int) -> void:
	gyro = pkt.gyro
	accel = pkt.accel
	touching = pkt.touching
	touch = pkt.touch
	buttons = pkt.buttons
	var pressed_bits: int = buttons & ~_prev_buttons
	_prev_buttons = buttons
	rx_total += 1
	_window_count += 1
	if _last_seq >= 0:
		var expected := (_last_seq + 1) & 0xFFFF
		var missed: int = (pkt.seq - expected) & 0xFFFF
		if missed > 0 and missed < 1000:
			lost_packets += missed
	_last_seq = pkt.seq
	if last_packet_ms > 0:
		_window_max_gap = maxi(_window_max_gap, now_ms - last_packet_ms)
	last_packet_ms = now_ms
	if has_clock:
		sensor_age_ms = now_ms - (pkt.ts + clock_offset_ms)
	orientation.update(pkt.ts, pkt.gyro, pkt.accel)
	if recorder != null and recorder.recording:
		recorder.add(slot, pkt.ts, orientation.linear_accel(pkt.accel), pkt.gyro)
	_feed_swing(pkt, now_ms)
	for bit in [Protocol.BTN_A, Protocol.BTN_B]:
		if pressed_bits & bit:
			button_pressed.emit(bit)


func on_stat(p_rtt: float, p_offset: float) -> void:
	rtt_ms = p_rtt
	clock_offset_ms = p_offset
	has_clock = true


## Call about once per frame. Updates the packet-rate window.
func tick(now_ms: int) -> void:
	if now_ms - _window_start_ms >= 1000:
		rx_rate = _window_count * 1000.0 / (now_ms - _window_start_ms)
		max_gap_ms = _window_max_gap
		_window_count = 0
		_window_max_gap = 0
		_window_start_ms = now_ms
	if state == State.CONNECTED and rx_rate > 0.0 and now_ms - last_packet_ms > 1500:
		rx_rate = 0.0


func recenter(snap_flat := true) -> void:
	orientation.recenter(snap_flat)
	heading = 0.0
	_head_x = 0.0
	_head_y = HEADING_PRIOR


## "Straight at the TV" without a setup step: the mean direction of the player's own swings (a player hits around the middle of
## the court), started from the guess that the TV is where the phone pointed at GO. The swing that is being reported is measured
## against the mean from before it.
func _follow_heading(az: float) -> void:
	if is_nan(az):
		return
	_head_x = _head_x * HEADING_KEEP + sin(az)
	_head_y = _head_y * HEADING_KEEP + cos(az)
	heading = atan2(_head_x, _head_y)



# ---- API for games ----

func tilt() -> Vector2:
	return orientation.tilt()


func pointer() -> Vector2:
	return orientation.pointer()


## The turn of the phone since the last recenter in radians, positive to the left (REQ-BW-4).
func yaw_offset() -> float:
	return orientation.yaw_offset()


## The acceleration of the phone without gravity, in the phone frame (REQ-BW-5).
func linear_accel() -> Vector3:
	return orientation.linear_accel(accel)


func is_down(bit: int) -> bool:
	return (buttons & bit) != 0


# ---- swing (for the games that hit a ball with a swing) ----

func _new_swing_detector() -> void:
	swing = SwingDetector.new()
	swing.lock_after = SWING_LOCK_S
	swing.threshold = SWING_THRESHOLD
	swing.window = SWING_WINDOW_S
	swing.hand_speed = true
	last_swing = {}
	swing_count = 0
	_swing_ts = -1


## Feeds the swing detector with one sensor packet. When a swing is thrown, `swung` is emitted with: `power` (0 to 1),
## `down` (a swing from top to bottom, like a serve), `forward_dir` (the direction in the phone frame), `hit_age_ms`
## (the hit was this long ago), `side` (-1 left to 1 right of the TV, from the direction of the swing) and `world_dir`.
func _feed_swing(pkt: Dictionary, now_ms: int) -> void:
	var dt := 0.0
	if _swing_ts >= 0:
		dt = clampf(((pkt.ts - _swing_ts) & 0xFFFFFFFF) / 1000.0, 0.0, 0.1)
	_swing_ts = pkt.ts
	var lin := orientation.linear_accel(pkt.accel)
	var was_forward := swing.state == SwingDetector.State.FORWARD
	swing.update(dt, lin)
	# The accelerometer is not trusted for gravity while a swing starts and runs, but only briefly: a wrong gravity direction
	# looks like movement, which starts a new back swing at once and would never end.
	if swing.state == SwingDetector.State.BACK:
		_hold_s += dt
	elif swing.state != SwingDetector.State.FORWARD:
		_hold_s = 0.0
	orientation.hold_accel = swing.state == SwingDetector.State.FORWARD or (
			swing.state == SwingDetector.State.BACK and _hold_s < SWING_HOLD_S)
	if swing.state == SwingDetector.State.FORWARD or (was_forward and swing.released):
		# The phone turns in the swing: sum the push in the world frame, not in the phone frame.
		_fwd_world += orientation.to_world(lin) * maxf(dt, 0.001)
	elif swing.state == SwingDetector.State.READY or swing.state == SwingDetector.State.BACK:
		_fwd_world = Vector3.ZERO
	if not swing.released:
		return
	var world := _fwd_world
	last_swing = {
		"power": swing.power,
		"down": SwingDetector.is_down(swing.forward_dir, orientation.up),
		"forward_dir": swing.forward_dir,
		"hit_age_ms": swing.hit_age * 1000.0,
		"side": OrientationFusion.swing_side(world, SWING_SIDE_FULL, heading),
		"azimuth": OrientationFusion.azimuth(world),
		"world_dir": world.normalized(),
	}
	_follow_heading(last_swing.azimuth)
	last_swing_ms = now_ms
	swing_count += 1
	swung.emit(last_swing)
