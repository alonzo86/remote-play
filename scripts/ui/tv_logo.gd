extends Control
## The logo screen after the Android splash (REQ-FL-2 to 4). It lasts about 2.5 seconds.
## OK, Back or a touch skips it. The server and the beacon already run while it shows.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Confetti = preload("res://scripts/ui/confetti.gd")

const LOGO_FILE := "res://assets/logo/logo.png"
const SHOW_SECONDS := 2.5

var _logo: Control
var _hint: Label
var _done := false


func _ready() -> void:
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	if ResourceLoader.exists(LOGO_FILE):
		var tr := TextureRect.new()
		tr.texture = load(LOGO_FILE)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(1150, 431) # About 60% of the screen width.
		box.add_child(tr)
		_logo = tr
	else:
		var t := UiKit.title("REMOTE PLAY", 170)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("outline_size", 18)
		t.add_theme_color_override("font_outline_color", UiTheme.OUTLINE)
		box.add_child(t)
		var sub := UiKit.label("Phone motion controller games", 40, UiTheme.TEXT_DIM, UiTheme.body_bold())
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
		_logo = box
	_hint = UiKit.label("Press OK to skip", 28, UiTheme.TEXT_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -120
	_hint.offset_bottom = -70
	_hint.modulate.a = 0.0

	# Pop-in, then a confetti burst. The timer goes on to the Connect screen.
	_logo.modulate.a = 0.0
	_logo.resized.connect(func(): _logo.pivot_offset = _logo.size * 0.5)
	_logo.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel()
	tw.tween_property(_logo, "modulate:a", 1.0, 0.25)
	tw.tween_property(_logo, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hint, "modulate:a", 1.0, 0.4).set_delay(0.8)
	get_tree().create_timer(0.35).timeout.connect(_burst)
	get_tree().create_timer(SHOW_SECONDS).timeout.connect(_next)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		_next()


func _burst() -> void:
	if not _done:
		Confetti.burst(self, size * Vector2(0.5, 0.62))


func on_back() -> void:
	_next() # Back skips the logo. It does not quit (REQ-FL-3).


func _next() -> void:
	if _done:
		return
	_done = true
	App.go_connect()
