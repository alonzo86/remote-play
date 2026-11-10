extends Control
## The logo screen after the Android splash (REQ-FL-2 to 4). It does not move on by itself (owner, 2026-11-10): it waits
## for OK, Back or a touch. Under the logo it shows the card "GET THE PHONE APP TO PLAY" with the QR code of the phone app
## (`About.APP_URL`), for a player whose phone has no app yet. The server already runs while it shows.
## At the first start (no saved language) it first asks for the language, "ENGLISH" or "עברית" (REQ-FL-60). OK chooses, and
## Back chooses the language that has the focus; then the screen waits for OK like every later start.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Confetti = preload("res://scripts/ui/confetti.gd")
const Lang = preload("res://scripts/core/lang.gd")
const About = preload("res://scripts/core/about.gd")
const QrView = preload("res://scripts/ui/qr_view.gd")

const LOGO_FILE := "res://assets/logo/logo.png"
const APP_QR_SIDE := 220.0   # The QR code of the app (a quiet zone of 4 modules, whole pixels).
const CARD_TITLE_W := 380.0 # The title of the card wraps in this width, in Hebrew too.
const LOGO_GRID := 4        # The file has 4 x 4 file pixels for each logo pixel (REQ-FL-50).
const DROP_FROM := -640.0   # The logo starts this far above its place.
const DROP_S := 0.5
const STEP := 16.0          # The logo moves in steps of this many pixels.

var _center: CenterContainer
var _hint: Label
var _choice: Control            # The two language items, until a language is chosen.
var _done := false
var asks_language := false      # True at the first start: the screen waits for the choice.
var language_buttons := {}      # code -> the button of that language.


func _ready() -> void:
	_center = CenterContainer.new()
	add_child(_center)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# One column: the logo (with the language choice under it at the first start), then the card of the app.
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 40)
	_center.add_child(box)
	if ResourceLoader.exists(LOGO_FILE):
		var tr := TextureRect.new()
		tr.texture = _logo_art()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = tr.texture.get_size()   # 1:1: 4 screen pixels for each logo pixel (REQ-FL-50).
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # Sharp pixels (REQ-FL-50).
		box.add_child(tr)
	else:
		var t := UiKit.title("SABABI", UiTheme.SIZE_LOGO)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(t)
		var sub := UiKit.label("logo.phone_motion_controller_games", UiTheme.SIZE_BODY, UiTheme.TEXT_DESC)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
	asks_language = App.needs_language_choice()
	if asks_language:
		_choice = _language_choice()
		box.add_child(_choice)
	var card := _app_card()
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(card)
	_hint = UiKit.blinking("logo.press_ok_start", UiTheme.SIZE_BODY, UiTheme.TEXT_DESC)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_left = 60    # Inside the 60 px safe area (REQ-GM-40).
	_hint.offset_right = -60
	_hint.offset_top = -120
	_hint.offset_bottom = -70
	_hint.visible = false

	# The logo drops in from the top in steps of 16 px (REQ-FL-42), then a confetti burst. Nothing moves on by itself.
	_drop(DROP_FROM)
	create_tween().tween_method(func(y: float): _drop(snappedf(y, STEP)), DROP_FROM, 0.0, DROP_S)
	get_tree().create_timer(0.8).timeout.connect(func(): _hint.visible = true)
	get_tree().create_timer(0.35).timeout.connect(_burst)


## The part of the logo file that has the artwork, without its empty margins (REQ-FL-50), on the grid of the logo pixels.
func _logo_art() -> Texture2D:
	var file: Texture2D = load(LOGO_FILE)
	var used := file.get_image().get_used_rect()
	var x0 := used.position.x / LOGO_GRID * LOGO_GRID
	var y0 := used.position.y / LOGO_GRID * LOGO_GRID
	var x1 := ceili(float(used.end.x) / LOGO_GRID) * LOGO_GRID
	var y1 := ceili(float(used.end.y) / LOGO_GRID) * LOGO_GRID
	var art := AtlasTexture.new()
	art.atlas = file
	art.region = Rect2(x0, y0, x1 - x0, y1 - y0)
	return art


## The card "GET THE PHONE APP TO PLAY": the title and the QR code of the phone app side by side. It has no button and no
## focus (FD-17). It follows the language of the app: in Hebrew the QR code is at the left and the title at the right.
func _app_card() -> Control:
	var card := UiKit.panel(24)
	card.name = "AppCard"
	card.layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE
	var av := HBoxContainer.new()
	av.add_theme_constant_override("separation", 24)
	card.add_child(av)
	var title := UiKit.label("connect.get_app", UiTheme.SIZE_BODY, UiTheme.TEXT_INFO)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.custom_minimum_size = Vector2(CARD_TITLE_W, 0)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av.add_child(title)
	var qr := QrView.new()
	qr.name = "AppQr"
	qr.quiet = 4
	qr.custom_minimum_size = Vector2(APP_QR_SIDE, APP_QR_SIDE)
	qr.text = About.APP_URL
	av.add_child(qr)
	return card


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


## A language is chosen at the first start: it is saved and the UI switches at once. The two items go away and the screen
## waits for OK like every later start.
func _choose(code: String) -> void:
	if _done or not asks_language:
		return
	App.set_language(code)
	asks_language = false
	language_buttons.clear()
	if _choice != null:
		_choice.queue_free()
		_choice = null


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
