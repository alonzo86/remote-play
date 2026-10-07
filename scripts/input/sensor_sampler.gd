extends Node
## Phone side. Reads the sensors and sends a packet about 60 times each second.
## On desktop (no sensors) the mouse simulates tilt and yaw, for testing.

const Protocol = preload("res://scripts/core/protocol.gd")

var client: Node            # ControllerClient
var buttons := 0
var touching := false
var touch := Vector2.ZERO   # 0..1 over the whole screen.

var last_gyro := Vector3.ZERO
var last_accel := Vector3.ZERO

var _seq := 0
var _next_send_us := 0
var _mouse_rel_x := 0.0
var _simulate := false


func _ready() -> void:
	_simulate = not OS.has_feature("mobile")


func _input(event: InputEvent) -> void:
	if _simulate and event is InputEventMouseMotion:
		_mouse_rel_x += event.relative.x


func _process(_delta: float) -> void:
	var now_us := Time.get_ticks_usec()
	var period_us := int(1000000.0 / Protocol.SENSOR_HZ)
	# Send when the frame is within half a period of the next slot.
	# This keeps 60 Hz on displays that run at 60 FPS with timing jitter.
	if now_us + period_us / 2 < _next_send_us:
		return
	if _next_send_us == 0 or now_us - _next_send_us > period_us:
		_next_send_us = now_us # First packet, or a stall. Do not burst.
	_next_send_us += period_us
	_read_sensors()
	var flags := Protocol.FLAG_TOUCH if touching else 0
	var pkt := Protocol.encode_sensor(_seq, Time.get_ticks_msec(), last_gyro, last_accel,
			buttons, flags, touch)
	_seq = (_seq + 1) & 0xFFFF
	if client != null:
		client.send_sensor(pkt)


func _read_sensors() -> void:
	if _simulate:
		var vp := get_viewport()
		var size := vp.get_visible_rect().size
		var m := vp.get_mouse_position() / size
		last_accel = Vector3(-(m.x - 0.5), (m.y - 0.5), 1.0).normalized() * 9.81
		last_gyro = Vector3(0, 0, -_mouse_rel_x * 0.05 * Protocol.SENSOR_HZ / 60.0)
		_mouse_rel_x = 0.0
	else:
		last_gyro = Input.get_gyroscope()
		# Measured on a real phone: Godot on Android reports every accelerometer axis inverted
		# (flat, screen up: z = -9.8). The protocol uses +9.8 on z, so flip it here.
		last_accel = -Input.get_accelerometer()
