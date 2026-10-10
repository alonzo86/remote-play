extends Control
## The logo screen after the Android splash (REQ-FL-2 to 4). It lasts about 2.5 seconds.
## OK, Back or a touch skips it. The server and the beacon already run while it shows.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Confetti = preload("res://scripts/ui/confetti.gd")

const LOGO_FILE := "res://assets/logo/logo.png"
const SHOW_SECONDS := 2.5
const DROP_FROM := -640.0   # The logo starts this far above its place.
const DROP_S := 0.5
const STEP := 16.0          # The logo moves in steps of this many pixels.

var _center: CenterContainer
var _hint: Label
var _done := false


func _ready() -> void:
	_center = CenterContainer.new()
	add_child(_center)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_center.add_child(box)
	if ResourceLoader.exists(LOGO_FILE):
		var tr := TextureRect.new()
		tr.texture = load(LOGO_FILE)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(1150, 431) # About 60% of the screen width.
		box.add_child(tr)
	else:
		var t := UiKit.title("REMOTE PLAY", UiTheme.SIZE_LOGO)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(t)
		var sub := UiKit.label("Phone motion controller games", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
	_hint = UiKit.blinking("Press OK to skip", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -120
	_hint.offset_bottom = -70
	_hint.visible = false

	# The logo drops in from the top in steps of the 8 px grid (REQ-FL-42), then a confetti burst. The timer goes on to
	# the Connect screen.
	_drop(DROP_FROM)
	create_tween().tween_method(func(y: float): _drop(snappedf(y, STEP)), DROP_FROM, 0.0, DROP_S)
	get_tree().create_timer(0.8).timeout.connect(func(): _hint.visible = true)
	get_tree().create_timer(0.35).timeout.connect(_burst)
	get_tree().create_timer(SHOW_SECONDS).timeout.connect(_next)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		_next()


## Puts the logo `y` pixels from its place (up when negative).
func _drop(y: float) -> void:
	_center.offset_top = y
	_center.offset_bottom = y


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
