extends SceneTree
## Phone screens: what used to be looked at by hand in manual tests 16, 17 and 18 and a machine can check (docs/MANUAL_TESTS.md):
## the pad buttons A and B that sit lower while pressed (16.6b), the Recenter box that fills with yellow for 0.34 s after a tap
## (16.6c), the slot square at the top of the pad (16.6e), the Connect screen of a Hebrew phone and of an English phone (17.4a),
## the Hebrew texts of the pad that fit their boxes (17.7a), the HAPTICS switch that is on at the first start (18.10a) and the
## waiting screen where Settings does not touch Disconnect on 4 phone shapes (18.10f). Run:
##   godot --headless --path . --script tests/auto_r3_phone.gd -- --role=controller
## The colors and the round shape of the buttons, and the number in the square, are pixels: they need a render check of the pad
## (tests/pixel_pad.gd was planned and is not written; Test 16 step 6b2 stays manual).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const Lang = preload("res://scripts/core/lang.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

const MIN_GAP := 24.0   # The least room between the Settings button and Disconnect on the waiting screen, in px.

var _checks := 0
var _fails := 0
var _app: Node
var _pad_script: GDScript
var _wait_script: GDScript


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: use _check)")
	else:
		_fails += 1
		print("  FAIL (known bug) (", issue, ") ", what)


func _initialize() -> void:
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _touch(index: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	return e


func _run() -> void:
	await _frames(3)
	_app = root.get_node("App")
	_pad_script = load("res://scripts/ui/controller_pad.gd")
	_wait_script = load("res://scripts/ui/controller_wait.gd")
	_app.client.slot = 1
	_app.client.color = Protocol.PLAYER_COLORS[1]
	_app.client.phase = "menu"
	var old_settings: Dictionary = _app.settings.duplicate()
	await _pad_checks()
	await _hebrew_pad()
	await _connect_language()
	await _haptics_default()
	await _phone_language()
	await _wait_layout()
	_app.settings.merge(old_settings, true)
	_app.set_language("en", false)
	_app.client.state = ControllerClient.State.IDLE


## A pad of 1080 x 1920 in a holder, with the sensor sampler stopped so that nothing overwrites the buttons of the test.
func _make_pad(viewport := Vector2(1080, 1920)) -> Dictionary:
	var holder := Control.new()
	holder.size = viewport
	root.add_child(holder)
	var pad: Control = _pad_script.new()
	pad.theme = _app.theme_res
	holder.add_child(pad)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(2)
	pad._sampler.set_process(false)
	return {"holder": holder, "pad": pad}


## 16.6b, 16.6c, 16.6e: the arcade buttons, the Recenter box and the slot square of the pad.
func _pad_checks() -> void:
	print("the pad")
	var made := await _make_pad()
	var pad: Control = made.pad
	# 16.6b: a finger on A lowers the face of A by 8 px, B stays; lifting the finger puts it back; the same for B.
	var a: Vector2 = pad._center_a()
	var b: Vector2 = pad._center_b()
	var lift: float = pad.BUTTON_LIFT
	var drop: float = pad.BUTTON_LIFT - pad.BUTTON_LIFT_DOWN
	var free_a: Vector2 = pad._button_face(a, Protocol.BTN_A)
	_check(is_equal_approx(a.y - free_a.y, lift) and a.x == free_a.x,
			"a free button A has its face %.0f px above its lower edge" % lift)
	pad._input(_touch(0, true, a))
	var down_a: Vector2 = pad._button_face(a, Protocol.BTN_A)
	var still_b: Vector2 = pad._button_face(b, Protocol.BTN_B)
	_check(is_equal_approx(down_a.y - free_a.y, drop) and is_equal_approx(still_b.y, b.y - lift),
			"a finger on A lowers the face of A by %.0f px and B stays (A %.0f, B %.0f)" % [drop, down_a.y - free_a.y, still_b.y - b.y])
	pad._input(_touch(0, false, a))
	_check(pad._button_face(a, Protocol.BTN_A) == free_a, "lifting the finger puts the face of A back")
	pad._input(_touch(1, true, b))
	var down_b: Vector2 = pad._button_face(b, Protocol.BTN_B)
	_check(is_equal_approx(b.y - down_b.y, lift - drop) and pad._button_face(a, Protocol.BTN_A) == free_a,
			"a finger on B lowers the face of B by %.0f px and A stays" % drop)
	pad._input(_touch(1, false, b))
	_check(pad._sampler.buttons == 0, "and nothing stays pressed")

	# 16.6c: RECENTER is black; a tap fills it with yellow; it is black again after 0.34 s (the flash falls by 3 each second).
	_check(pad._recenter_fill() == UiTheme.BG, "the Recenter box is black while nobody taps it")
	var middle: Vector2 = pad._rect_recenter().get_center()
	pad._input(_touch(2, true, middle))
	_check(pad._recenter_fill() == UiTheme.ACCENT, "a tap on RECENTER fills the box with yellow at once")
	pad._input(_touch(2, false, middle))
	pad._process(0.2)
	_check(pad._recenter_fill() == UiTheme.ACCENT, "0.2 s later it is still yellow")
	pad._process(0.15)
	_check(pad._recenter_fill() == UiTheme.BG, "0.35 s after the tap it is black again")

	# 16.6e: the color square with the slot number is at the top left of the pad, on the row of Disconnect.
	var sq: Rect2 = pad._rect_slot_square()
	var leave: Rect2 = pad._rect_leave()
	_check(sq.position.x <= 60.0 and sq.end.y < pad.size.y * 0.15 and is_equal_approx(sq.get_center().y, leave.get_center().y)
			and not sq.intersects(leave), "the slot square is in the top 15 percent of the pad, on the row of Disconnect: %s" % str(sq))
	_app.client.state = ControllerClient.State.CONNECTED
	_check(pad._slot_square_color() == Protocol.PLAYER_COLORS[1], "joined: the square has the color of the slot")
	_app.client.state = ControllerClient.State.IDLE
	_check(pad._slot_square_color() == UiTheme.BAD, "without the link to the TV the square is red")
	made.holder.queue_free()


## 17.7a: in Hebrew the words RECENTER and DISCONNECT and the hint are Hebrew, and each fits inside its box (the frame is
## 6 px at each side).
func _hebrew_pad() -> void:
	print("the pad in Hebrew")
	var made := await _make_pad()
	var pad: Control = made.pad
	var texts := {}   # language -> [recenter, disconnect, hint]
	for code in ["en", "he"]:
		_app.set_language(code, false)
		texts[code] = [Lang.t("pad.recenter").to_upper(), Lang.t("pad.disconnect").to_upper(),
				Lang.t("pad.point_at_tv_then").to_upper()]
	_check(texts.he[0] != texts.en[0] and texts.he[1] != texts.en[1] and texts.he[2] != texts.en[2],
			"the three texts of the pad are different in Hebrew and in English")
	_app.set_language("he", false)
	var font := UiTheme.font()
	var room := {"recenter": pad._rect_recenter().size.x, "disconnect": pad._rect_leave().size.x,
			"hint": pad._rect_recenter().size.x}
	var sizes := {"recenter": 72, "disconnect": 24, "hint": pad.hint_size(font, pad._rect_recenter())}
	var names := ["recenter", "disconnect", "hint"]
	for i in 3:
		var w := font.get_string_size(texts.he[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(sizes[names[i]])).x
		var ok: bool = w > 0.0 and w <= float(room[names[i]]) - 2.0 * UiTheme.LINE
		var what := "Hebrew %s: %.0f px of text in a box of %.0f px (the frame takes %d px)" % [names[i], w, room[names[i]],
				2 * UiTheme.LINE]
		_check(ok, what)
	_app.set_language("en", false)
	made.holder.queue_free()


## The texts of the labels and buttons under `node` that are keys of the table: node -> the text that shows.
func _shown_keys(node: Node) -> Dictionary:
	var out := {}
	for n in node.find_children("*", "", true, false):
		if (n is Label or n is Button) and Lang.has(String(n.text)) and n.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
			out[String(n.text)] = n.tr(n.text)
	return out


## 17.4a: a phone whose system language is Hebrew shows its Connect screen in Hebrew before it has joined; a phone whose system
## language is English (or another one) shows English (REQ-FL-62: the phone never follows the TV).
func _connect_language() -> void:
	print("the Connect screen follows the language of the phone")
	var connect_script: GDScript = load("res://scripts/ui/controller_connect.gd")
	var table := Lang.table()
	for pair in [["he", "he"], ["iw", "he"], ["en", "en"], ["fr", "en"]]:
		Lang.device_locale = pair[0]
		_app.settings.language = ""   # No saved choice: the phone uses the language of the device.
		_app.set_language(_app.language_to_use(), false)
		_app.go(connect_script)
		await _frames(3)
		var shown := _shown_keys(_app.current_screen())
		var right := true
		var different := 0
		for key in shown:
			right = right and shown[key] == table[key][pair[1]]
			if table[key].en != table.get(key, {}).he:
				different += 1
		_check(Lang.current() == pair[1] and shown.size() >= 4 and right,
				"device language %s: %d texts of the Connect screen are in %s" % [pair[0], shown.size(),
				"Hebrew" if pair[1] == "he" else "English"])
		if pair[1] == "he":
			_check(different >= 4, "device language %s: at least 4 of them differ from the English text (%d)" % [pair[0], different])
	Lang.device_locale = ""
	_app.set_language("en", false)


## 18.10a: the first time the phone is used the HAPTICS switch on the Settings screen is ON. The default comes from a fresh App
## object (the one in the tree may have read a saved file), then the screen is opened with the Settings button of the waiting
## screen.
func _haptics_default() -> void:
	print("the HAPTICS switch")
	var fresh: Node = load("res://scripts/app.gd").new()
	var default_on: bool = bool(fresh.settings.haptics)
	fresh.free()
	_check(default_on, "the default of the HAPTICS setting is on")
	var saved: bool = bool(_app.settings.haptics)
	_app.settings.haptics = default_on
	_app.go(_wait_script)
	await _frames(3)
	var wait: Control = _app.current_screen()
	var settings_button: Button = null
	for b in wait.find_children("*", "Button", true, false):
		if b.text == "common.settings":
			settings_button = b
	_check(settings_button != null, "the waiting screen has a Settings button")
	if settings_button != null:
		settings_button.pressed.emit()
		await _frames(3)
		var screen: Control = _app.current_screen()
		_check(screen.get_script().resource_path.ends_with("controller_settings.gd") and screen._haptics.text == "HAPTICS: ON",
				"Settings opens, with the row '%s'" % (screen._haptics.text if "_haptics" in screen else "-"))
	_app.settings.haptics = saved


## 17.2b (issue #171): the phone Settings screen has a language button. A tap switches the phone at once (text and layout
## direction) and saves the choice; the choice wins over the language of the device at the next start; the TV language message
## (`welcome.lang`, `lang`) changes nothing on the phone, also when the connection state changes.
func _phone_language() -> void:
	print("the language of the phone")
	var saved_lang: String = _app.settings.language
	Lang.device_locale = "en"
	_app.settings.language = ""
	_app.set_language(_app.language_to_use(), false)
	_app.go(_wait_script)
	await _frames(3)
	for b in _app.current_screen().find_children("*", "Button", true, false):
		if b.text == "common.settings":
			b.pressed.emit()
	await _frames(3)
	var screen: Control = _app.current_screen()
	_check(screen.get_script().resource_path.ends_with("controller_settings.gd") and screen._language.text == "LANGUAGE: ENGLISH",
			"the Settings screen shows the language button in English: '%s'" % screen._language.text)
	screen._language.pressed.emit()
	await _frames(3)
	_check(Lang.current() == "he" and _app.settings.language == "he" and Lang.is_rtl() and screen._language.text == "שפה: עברית"
			and root.get_layout_direction() == Window.LAYOUT_DIRECTION_RTL,
			"a tap switches the phone to Hebrew, right to left, and saves it: '%s'" % screen._language.text)
	# The TV says English and the connection comes and goes: the phone keeps its own choice.
	_app.client._handle({"t": "lang", "v": "en"}, Time.get_ticks_msec())
	_check(Lang.current() == "he", "a lang message of the TV changes nothing")
	_app.client._handle({"t": "welcome", "slot": 1, "token": "t", "color": "#e63946", "phase": "menu", "name": "TV", "lang": "en"},
			Time.get_ticks_msec())
	await _frames(3)
	_check(Lang.current() == "he" and _app.settings.language == "he", "a welcome with lang en changes nothing")
	_app._on_client_state(ControllerClient.State.IDLE)
	await _frames(3)
	_check(Lang.current() == "he", "the language of the TV and a lost connection do not change the language of the phone")
	# The next start: the saved choice wins over the language of the device.
	Lang.device_locale = "en"
	var settings_now: String = _app.settings.language
	_app.settings.language = ""
	_app._load_settings()
	_check(settings_now == "he" and _app.language_to_use() == "he",
			"the next start uses the saved choice (Hebrew), not the device (English)")
	_app.go(_app.ControllerSettings)   # The lost connection took the phone to the Connect screen.
	await _frames(3)
	screen = _app.current_screen()
	screen._language.pressed.emit()
	await _frames(3)
	_check(Lang.current() == "en" and _app.settings.language == "en" and screen._language.text == "LANGUAGE: ENGLISH",
			"a second tap switches back to English")
	Lang.device_locale = ""
	_app.settings.language = saved_lang
	_app.save_settings()
	_app.set_language("en", false)


## 18.10f: on the waiting screen the Settings button and Disconnect do not touch (at least 24 px apart) and both are inside the
## screen, in English and in Hebrew, on four phone shapes.
func _wait_layout() -> void:
	print("the waiting screen")
	var shapes := [Vector2(1080, 1920), Vector2(1080, 2340), Vector2(1170, 2532), Vector2(1080, 2400)]
	for code in ["en", "he"]:
		_app.set_language(code, false)
		for viewport in shapes:
			var holder := Control.new()
			holder.size = viewport
			root.add_child(holder)
			var wait: Control = _wait_script.new()
			wait.theme = _app.theme_res
			holder.add_child(wait)
			wait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await _frames(3)
			var leave: Rect2 = wait._leave.get_global_rect()
			var settings_rect := Rect2()
			for b in wait.find_children("*", "Button", true, false):
				if b.text == "common.settings":
					settings_rect = b.get_global_rect()
			var screen_rect := Rect2(Vector2.ZERO, viewport)
			var gap := settings_rect.position.y - leave.end.y
			_check(settings_rect.size != Vector2.ZERO and not settings_rect.intersects(leave) and gap >= MIN_GAP
					and screen_rect.encloses(settings_rect) and screen_rect.encloses(leave),
					"[%s] %dx%d: Settings is %.0f px under Disconnect (24 or more) and both are on the screen" % [code,
					viewport.x, viewport.y, gap])
			holder.queue_free()
	_app.set_language("en", false)
