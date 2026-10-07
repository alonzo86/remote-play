extends Control
## Phone screen while connected. Draws everything itself and tracks touches by finger,
## so Recenter, A and B can be used at the same time (multi-touch).

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const SensorSampler = preload("res://scripts/input/sensor_sampler.gd")

var _sampler: Node
var _fingers: Dictionary = {}   # finger index -> zone name
var _touch_finger := -1
var _flash := {"recenter": 0.0}


func _ready() -> void:
	_sampler = SensorSampler.new()
	_sampler.client = App.client
	add_child(_sampler)
	# Connect methods, not lambdas: App.client outlives this screen.
	App.client.haptic_requested.connect(_on_haptic)
	App.client.phase_changed.connect(_on_phase)


func _on_haptic(ms: int) -> void:
	Input.vibrate_handheld(ms)


func _on_phase(_phase: String) -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_flash.recenter = maxf(_flash.recenter - delta * 3.0, 0.0)
	queue_redraw()


# ---- Layout (all in viewport coordinates) ----

func _rect_leave() -> Rect2:
	return Rect2(size.x - 260, 30, 230, 90)


func _rect_recenter() -> Rect2:
	var top := 360.0
	var h := minf(size.y * 0.30, 620.0)
	return Rect2(60, top, size.x - 120, h)


func _center_a() -> Vector2:
	return Vector2(size.x * 0.28, size.y - 330)


func _center_b() -> Vector2:
	return Vector2(size.x * 0.72, size.y - 330)


func _radius() -> float:
	return minf(size.x * 0.19, 200.0)


func _zone_at(pos: Vector2) -> String:
	if _rect_leave().has_point(pos):
		return "leave"
	if _rect_recenter().has_point(pos):
		return "recenter"
	if pos.distance_to(_center_a()) <= _radius() * 1.25:
		return "a"
	if pos.distance_to(_center_b()) <= _radius() * 1.25:
		return "b"
	return "pad"


# ---- Input ----

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos: Vector2 = get_global_transform().affine_inverse() * event.position
		if event.pressed:
			var zone := _zone_at(pos)
			_fingers[event.index] = zone
			_on_zone_down(zone, event.index, pos)
		else:
			var zone2: String = _fingers.get(event.index, "")
			_fingers.erase(event.index)
			_on_zone_up(zone2, event.index)
	elif event is InputEventScreenDrag:
		if event.index == _touch_finger:
			_update_touch(get_global_transform().affine_inverse() * event.position)


func _on_zone_down(zone: String, index: int, pos: Vector2) -> void:
	match zone:
		"leave":
			App.client.leave()
		"recenter":
			App.client.send_recenter()
			_flash.recenter = 1.0
		"a":
			_sampler.buttons |= Protocol.BTN_A
		"b":
			_sampler.buttons |= Protocol.BTN_B
	if _touch_finger < 0:
		_touch_finger = index
		_sampler.touching = true
		_update_touch(pos)


func _on_zone_up(zone: String, index: int) -> void:
	match zone:
		"a":
			_sampler.buttons &= ~Protocol.BTN_A
		"b":
			_sampler.buttons &= ~Protocol.BTN_B
	if index == _touch_finger:
		_touch_finger = -1
		_sampler.touching = false


func _update_touch(pos: Vector2) -> void:
	_sampler.touch = Vector2(clampf(pos.x / size.x, 0.0, 1.0), clampf(pos.y / size.y, 0.0, 1.0))


# ---- Drawing ----

func _draw() -> void:
	var tf := UiTheme.title_font()
	var bf := UiTheme.body_bold()
	var c: Node = App.client
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)

	# Player dot, name and TV. The dot is the player color. It is red when the link is lost.
	var online: bool = c.state == ControllerClient.State.CONNECTED
	var dot := Vector2(110, 110)
	draw_circle(dot + UiTheme.SHADOW * 0.5, 54.0, UiTheme.OUTLINE)
	draw_circle(dot, 54.0, UiTheme.OUTLINE)
	draw_circle(dot, 46.0, c.color if online else UiTheme.BAD)
	draw_string(tf, dot + Vector2(-46, 20), str(c.slot + 1), HORIZONTAL_ALIGNMENT_CENTER, 92, 56, Color.WHITE)
	var status := "Player %d" % (c.slot + 1) if online else "Reconnecting..."
	draw_string(tf, Vector2(190, 108), status, HORIZONTAL_ALIGNMENT_LEFT, size.x - 460, 56,
			UiTheme.ACCENT if online else UiTheme.BAD)
	draw_string(bf, Vector2(190, 156), c.tv_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 460, 32, UiTheme.TEXT_DIM)

	var lat := "RTT -- ms" if c.rtt_ms < 0 else "RTT %d ms" % roundi(c.rtt_ms)
	draw_string(tf, Vector2(60, 262), lat, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, _lat_color(c.rtt_ms))
	draw_string(bf, Vector2(60, 316), "%d Hz  -  TV: %s" % [roundi(c.tx_rate), c.phase],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 32, UiTheme.TEXT_DIM)

	# Leave
	_draw_box(_rect_leave(), UiTheme.CARD, "Leave", bf, 36, UiTheme.CARD_TEXT)

	# Recenter
	var rr := _rect_recenter()
	var fill := UiTheme.ACCENT.lerp(Color.WHITE, _flash.recenter * 0.6)
	_draw_box(rr, fill, "RECENTER", tf, 92, UiTheme.CARD_TEXT)
	draw_string(bf, rr.position + Vector2(0, rr.size.y - 40), "Point at the TV, then tap",
			HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 34, UiTheme.CARD_TEXT)

	# A and B
	_draw_button(_center_a(), "A", Protocol.BTN_A, c.color)
	_draw_button(_center_b(), "B", Protocol.BTN_B, UiTheme.CARD)


func _draw_box(r: Rect2, fill: Color, text: String, font: Font, fs: int, col: Color) -> void:
	draw_style_box(UiTheme.card(fill, UiTheme.OUTLINE, UiTheme.OUTLINE_W, 40, true), r)
	var ty := r.position.y + r.size.y * 0.5 + fs * 0.35
	draw_string(font, Vector2(r.position.x, ty), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)


func _draw_button(center: Vector2, label: String, bit: int, col: Color) -> void:
	var down: bool = (_sampler.buttons & bit) != 0
	var r := _radius()
	var off := Vector2.ZERO if down else UiTheme.SHADOW
	draw_circle(center + off, r + 8.0, UiTheme.OUTLINE)
	draw_circle(center + (UiTheme.SHADOW if down else Vector2.ZERO) * 0.0, r + 8.0, UiTheme.OUTLINE)
	draw_circle(center, r, col.lightened(0.25) if down else col)
	draw_string(UiTheme.title_font(), center + Vector2(-r, 38), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 112,
			Color.WHITE if col != UiTheme.CARD else UiTheme.CARD_TEXT)


func _lat_color(rtt: float) -> Color:
	if rtt < 0:
		return UiTheme.TEXT_DIM
	if rtt < 25:
		return UiTheme.OK
	if rtt < 60:
		return UiTheme.ACCENT
	return UiTheme.BAD
