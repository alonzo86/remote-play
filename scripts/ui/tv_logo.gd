extends Control
## The logo screen after the Android splash (REQ-FL-2 to 4). It lasts about 2.5 seconds.
## OK, Back or a touch skips it. The server and the beacon already run while it shows.
## At the first start (no saved language) it does not move on by itself: it asks for the language, "ENGLISH" or "עברית"
## (REQ-FL-60). OK chooses, and Back chooses the language that has the focus.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Confetti = preload("res://scripts/ui/confetti.gd")
const Lang = preload("res://scripts/core/lang.gd")

const LOGO_FILE := "res://assets/logo/logo.png"
const SHOW_SECONDS := 2.5
const DROP_FROM := -640.0   # The logo starts this far above its place.
const DROP_S := 0.5
const STEP := 16.0          # The logo moves in steps of this many pixels.

var _center: CenterContainer
var _hint: Label
var _done := false
var asks_language := false      # True at the first start: the screen waits for the choice.
var language_buttons := {}      # code -> the button of that language.


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
		tr.custom_minimum_size = Vector2(1200, 450) # 62.5% of the screen width: 3 screen pixels per logo pixel.
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # Sharp pixels (REQ-FL-50).
		box.add_child(tr)
	else:
		var t := UiKit.title("SABABI", UiTheme.SIZE_LOGO)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(t)
		var sub := UiKit.label("logo.phone_motion_controller_games", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
	asks_language = App.needs_language_choice()
	if asks_language:
		box.add_child(UiKit.spacer(24))
		box.add_child(_language_choice())
	_hint = UiKit.blinking("logo.press_ok_start" if asks_language else "logo.press_ok_skip", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -120
	_hint.offset_bottom = -70
	_hint.visible = false

	# The logo drops in from the top in steps of 16 px (REQ-FL-42), then a confetti burst. The timer goes on to
	# the Connect screen.
	_drop(DROP_FROM)
	create_tween().tween_method(func(y: float): _drop(snappedf(y, STEP)), DROP_FROM, 0.0, DROP_S)
	get_tree().create_timer(0.8).timeout.connect(func(): _hint.visible = true)
	get_tree().create_timer(0.35).timeout.connect(_burst)
	if not asks_language:
		get_tree().create_timer(SHOW_SECONDS).timeout.connect(_next)


## The two languages side by side, English on the left in both layouts. Each name is in its own language, so it is not translated.
func _language_choice() -> Control:
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 120)
	for code in Lang.CODES:
		var b := UiKit.item(String(Lang.NAMES[code]), _choose.bind(code))
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.add_child(b)
		language_buttons[code] = b
	UiKit.focus_later(language_buttons[Lang.system_language()])
	return row


## The language that has the focus: the language of the device until the player moves.
func focused_language() -> String:
	for code in language_buttons:
		if language_buttons[code].has_focus():
			return code
	return Lang.system_language()


func _choose(code: String) -> void:
	if _done:
		return
	App.set_language(code)
	_next()


func _unhandled_input(event: InputEvent) -> void:
	if asks_language:
		return   # A touch or OK on a language button chooses; nothing else moves on.
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
	if asks_language:
		_choose(focused_language())   # Back takes the language that has the focus.
		return
	_next() # Back skips the logo. It does not quit (REQ-FL-3).


func _next() -> void:
	if _done:
		return
	_done = true
	App.go_connect()
