extends RefCounted
## State of one player slot on the TV. The network code writes to it.
## Games only read from it. Games must not use any networking script.

const Protocol = preload("res://scripts/core/protocol.gd")
const OrientationFusion = preload("res://scripts/input/orientation.gd")

enum State { EMPTY, CONNECTED, LOST }

signal button_pressed(bit: int)

var slot := 0
var state: State = State.EMPTY
var player_name := ""
var color := Color.WHITE
var token := ""
var lost_since_ms := 0

var orientation: OrientationFusion

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


func _init(p_slot: int, settings: Dictionary) -> void:
	slot = p_slot
	color = Protocol.PLAYER_COLORS[p_slot % Protocol.PLAYER_COLORS.size()]
	orientation = OrientationFusion.new(settings)


func is_connected_now() -> bool:
	return state == State.CONNECTED


func is_present() -> bool:
	return state != State.EMPTY


func reset() -> void:
	state = State.EMPTY
	player_name = ""
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


## Called when a phone (re)joins this slot.
func on_join(p_name: String, p_token: String) -> void:
	player_name = p_name
	token = p_token
	state = State.CONNECTED
	_last_seq = -1 # Do not count the reconnect gap as packet loss.
	_window_start_ms = Time.get_ticks_msec()
	_window_count = 0


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


func recenter() -> void:
	orientation.recenter()


# ---- API for games ----

func tilt() -> Vector2:
	return orientation.tilt()


func pointer() -> Vector2:
	return orientation.pointer()


func is_down(bit: int) -> bool:
	return (buttons & bit) != 0
