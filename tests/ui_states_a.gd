extends SceneTree
## More phone screen checks (docs/MANUAL_TESTS.md tests 7, 8, 8b and 13): the Disconnect button in English and Hebrew, the A and B
## buttons of the pad, the pressed state, the place of Disconnect, the fonts and the black background of the phone screens, the
## Back key of the phone, and every phone screen inside the safe area of an iPhone (portrait and landscape).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/ui_states_a.gd -- --role=controller

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const SafeArea = preload("res://scripts/ui/safe_area.gd")

var _checks := 0
var _fails := 0
var _app: Node
var _pad_script: GDScript


func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: use _check)")
	else:
		_fails += 1
		print("  FAIL (known bug) ", issue, ": ", what)


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _run() -> void:
	for i in 3:
		await process_frame
	_app = root.get_node("App")
	_pad_script = load("res://scripts/ui/controller_pad.gd")
	_app.client.slot = 1
	_app.client.color = Protocol.PLAYER_COLORS[1]
	_app.client.phase = "menu"
	await _disconnect_button()
	await _pad_buttons()
	await _pad_header()
	await _fonts_and_background()
	await _back_key()
	await _swing_card()
	await _pick_question()
	await _no_focus()
	await _safe_layout()
	await _safe_rtl()
	_app.client._set_state(ControllerClient.State.IDLE)


func _screen(script: GDScript, parent: Control = null) -> Control:
	var s: Control = script.new()
	s.theme = _app.theme_res
	if parent != null:
		parent.add_child(s)
	else:
		root.add_child(s)
	return s


## Issue #79, REQ-GM-102: the safety card of a swing game shows on the waiting screen until OK, not again for the same view,
## and again for the next view.
func _swing_card() -> void:
	print("swing card")
	var wait: Control = _screen(_app.ControllerWait)
	await process_frame
	_check(not is_instance_valid(wait._swing_card), "no card without the setup of a swing game")
	_app.client.swing_acked = false
	_app.client.setup_swing = true
	_app.client.setup_changed.emit()
	await process_frame
	_check(is_instance_valid(wait._swing_card) and wait._swing_card.ok_button.text == "common.ok",
			"the card shows while the setup is a swing game, with an OK button")
	var card: Control = wait._swing_card
	card.ok_button.pressed.emit()
	await process_frame
	await process_frame
	_check(_app.client.swing_acked and not is_instance_valid(wait._swing_card), "OK answers and closes the card")
	_app.client.setup_changed.emit()
	await process_frame
	_check(not is_instance_valid(wait._swing_card), "the card does not show again for the same view")
	_app.client._handle({"t": "phase", "v": "connect"}, 0)   # The view closes.
	_check(not _app.client.swing_acked and not _app.client.setup_swing,
			"the answer is forgotten when the view closes: the next view asks again (issue #148)")
	_app.client.swing_acked = true
	_app.client._handle({"t": "welcome", "slot": 1, "color": "#ff0000", "token": "t", "name": "TV2", "phase": "connect"}, 0)
	_check(not _app.client.swing_acked, "a new welcome (another TV) forgets the answer too")
	wait.queue_free()


## Issue #76, REQ-GM-104: with two or more phones the waiting screen asks "play this game?" and the chosen button is filled.
func _pick_question() -> void:
	print("IN or OUT question")
	var wait: Control = _screen(_app.ControllerWait)
	await process_frame
	_check(not wait._pick_box.visible, "no question with one phone")
	_app.client.setup_pick = true
	_app.client.setup_in = true
	_app.client.setup_changed.emit()
	await process_frame
	var in_fill: StyleBoxFlat = wait._in_button.get_theme_stylebox("normal")
	var out_fill: StyleBoxFlat = wait._out_button.get_theme_stylebox("normal")
	_check(wait._pick_box.visible and in_fill.bg_color == UiTheme.BUTTON_FACE and out_fill.bg_color == UiTheme.BUTTON_FACE
			and in_fill.border_width_left == UiTheme.MARK_W and out_fill.border_width_left == UiTheme.LINE,
			"with 2 phones the question shows, both buttons are white and IN has the thick yellow border")
	wait._out_button.pressed.emit()
	await process_frame
	in_fill = wait._in_button.get_theme_stylebox("normal")
	out_fill = wait._out_button.get_theme_stylebox("normal")
	_check(not _app.client.setup_in and in_fill.border_width_left == UiTheme.LINE
			and out_fill.border_width_left == UiTheme.MARK_W and out_fill.bg_color == UiTheme.BUTTON_FACE,
			"a tap on OUT moves the thick border to OUT, and both stay white")
	_app.client.setup_pick = false
	_app.client.setup_in = true
	wait.queue_free()


## Test 7.6b, 6d, 6e: the Disconnect button of the waiting screen and the pad.
func _disconnect_button() -> void:
	print("Disconnect button")
	var wait_script: GDScript = load("res://scripts/ui/controller_wait.gd")
	var viewport := Vector2(1080, 1920)
	for lang in ["en", "he"]:
		_app.set_language(lang, false)
		var holder := Control.new()
		holder.size = viewport
		root.add_child(holder)
		var wait := _screen(wait_script, holder)
		wait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await process_frame
		await process_frame
		var b: Button = wait._leave
		var font := b.get_theme_font("font")
		var fs := b.get_theme_font_size("font_size")
		var text_w := font.get_string_size(b.tr(b.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sb := b.get_theme_stylebox("normal")
		var room := b.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT)
		_check(b.get_minimum_size().x <= b.size.x + 0.5 and text_w <= room + 0.5,
				"[%s] the Disconnect text fits in its button (text %.0f px, room %.0f px, button %.0f px)" % [lang,
						text_w, room, b.size.x])
		var r := b.get_global_rect()
		_check(r.end.x > viewport.x * 0.8 and r.position.y < viewport.y * 0.15,
				"[%s] Disconnect is in the top right corner of the waiting screen (right %.0f, top %.0f)" % [lang, r.end.x, r.position.y])
		_check(b.size.y >= 80.0, "[%s] and it is at least 80 px high (%.0f)" % [lang, b.size.y])
		var pressed := b.get_theme_stylebox("pressed") as StyleBoxFlat
		var normal := b.get_theme_stylebox("normal") as StyleBoxFlat
		_check(pressed.bg_color != normal.bg_color and pressed.bg_color == UiTheme.BG and normal.bg_color == UiTheme.BUTTON_FACE,
				"[%s] a pressed button turns black and a normal one is white (issue #173)" % lang)
		_check(b.get_theme_color("font_pressed_color") == UiTheme.TEXT and b.get_theme_color("font_color") == UiTheme.BUTTON_TEXT,
				"[%s] the text of a pressed button turns white on the black fill, a normal one is black on white" % lang)
		holder.queue_free()
	_app.set_language("en", false)
	# The Disconnect box of the pad: the rect is the top right of the pad.
	var pad_script: GDScript = _pad_script
	var holder2 := Control.new()
	holder2.size = viewport
	root.add_child(holder2)
	var pad := _screen(pad_script, holder2)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	var leave: Rect2 = pad._rect_leave()
	_check(leave.end.x > pad.size.x * 0.8 and leave.position.y < pad.size.y * 0.15 and leave.size.y >= 80.0,
			"Disconnect is in the top right corner of the pad and at least 80 px high: %s" % str(leave))
	holder2.queue_free()


## Test 7.6c, 6d: A and B are white (issue #173); a pressed button sits lower (REQ-FL-52).
func _pad_buttons() -> void:
	print("A and B")
	var pad_script: GDScript = _pad_script
	_check(pad_script.BUTTON_LIFT - pad_script.BUTTON_LIFT_DOWN > 0.0 and pad_script.BUTTON_LIFT_DOWN < pad_script.BUTTON_LIFT,
			"a pressed arcade button sits lower than a free one (%.0f against %.0f px)"
			% [pad_script.BUTTON_LIFT_DOWN, pad_script.BUTTON_LIFT])
	var src := FileAccess.get_file_as_string("res://scripts/ui/controller_pad.gd")
	var draws_a: bool = src.contains('_draw_button(_center_a(), "A", Protocol.BTN_A)')
	var draws_b: bool = src.contains('_draw_button(_center_b(), "B", Protocol.BTN_B)')
	_check(draws_a and draws_b, "the pad draws A and B with no color of their own (a white face, issue #173)")


## Issue #238, REQ-FL-52b: a long name fits the header, and a lost link buzzes the phone once (HAPTICS ON only).
func _pad_header() -> void:
	print("pad header and lost link")
	var holder := Control.new()
	holder.size = Vector2(1080, 1920)
	root.add_child(holder)
	var pad := _screen(_pad_script, holder)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	var names := {"en": "WWWWWWWWWWWWWWWW", "he": "אבגדהוזחטיכלמנסע"}
	for lang in names:
		for avatar in [true, false]:
			var rect: Rect2 = pad._rect_name(avatar)
			var fs: int = _pad_script.name_size(names[lang], rect.size.x)
			var w := UiTheme.font().get_string_size(names[lang], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_check(w <= rect.size.x and fs >= 16 and rect.end.x <= pad._rect_leave().position.x,
					"[%s] a name of 16 letters fits the header with%s an avatar (%.0f of %.0f px at %d px type)"
					% [lang, "" if avatar else "out", w, rect.size.x, fs])
	_check(_pad_script.name_size("MAYA", pad._rect_name(true).size.x) == 48, "a short name keeps the full 48 px type")
	var Haptics: GDScript = load("res://scripts/game/haptics.gd")
	var calls: Array = []
	Haptics.vibrate_call = func(ms: int) -> void: calls.append(ms)
	var old: bool = _app.settings.get("haptics", true)
	_app.settings.haptics = true
	_app.client.state_changed.emit(ControllerClient.State.CONNECTED)
	_check(calls.is_empty(), "no buzz when the link is (back) up")
	_app.client.state_changed.emit(ControllerClient.State.RECONNECTING)
	_check(calls == [_pad_script.LOST_BUZZ_MS] and _pad_script.LOST_BUZZ_MS >= 500,
			"a lost link buzzes once, 500 ms or more (got %s)" % str(calls))
	_app.settings.haptics = false
	_app.client.state_changed.emit(ControllerClient.State.RECONNECTING)
	_check(calls.size() == 1, "with HAPTICS off the lost link does not buzz")
	_app.settings.haptics = old
	Haptics.vibrate_call = Callable()
	holder.queue_free()


## Test 8b.6a: the phone screens are black with the pixel font. Every text uses the font of the theme.
func _fonts_and_background() -> void:
	print("fonts and background")
	_check(_app.theme_res.default_font == UiTheme.font(), "the theme of the app has the pixel font as its default font")
	var backdrops := _app.get_children().filter(func(n): return n is CanvasLayer)
	var black := false
	for layer in backdrops:
		for n in layer.get_children():
			if n.get_script() != null and String(n.get_script().resource_path).ends_with("backdrop.gd"):
				black = true
	_check(black, "the app draws the backdrop behind every screen")
	_check(UiTheme.BG == Color.BLACK, "the background color is black")
	var scripts := ["controller_connect", "controller_wait", "controller_settings", "about_screen", "controller_profiles"]
	var bad: Array[String] = []
	for name in scripts:
		_app.go(load("res://scripts/ui/%s.gd" % name))
		await process_frame
		await process_frame
		var screen: Control = _app.current_screen()
		if screen.theme != _app.theme_res:
			bad.append(name + " theme")
		for n in screen.find_children("*", "Control", true, false):
			if (n is Label or n is Button) and n.has_theme_font_override("font") and n.get_theme_font("font") != UiTheme.font():
				bad.append(name + " " + n.name)
			if n is ColorRect and n.color != UiTheme.BG and n.get_parent() == screen:
				bad.append(name + " color rect")
	_check(bad.is_empty(), "no phone screen has its own font or a non-black cover (found: %s)" % str(bad))


## Test 8.6: the Back key of the phone.
func _back_key() -> void:
	print("Back key of the phone")
	var quits := [0]
	_app.quit_hook = func(): quits[0] += 1
	_app.go(load("res://scripts/ui/controller_connect.gd"))
	await process_frame
	var screen: Control = _app.current_screen()
	_app._last_back_ms = 0
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)   # What Android sends for the Back key.
	var dialogs := screen.find_children("*", "Control", true, false).filter(
			func(c: Node) -> bool: return c.get_script() != null and c.get_script().resource_path.ends_with("controller_quit_dialog.gd"))
	_check(dialogs.size() == 1 and quits[0] == 0,
			"Back on the Connect screen asks first and does not quit (%d dialogs, %d quits)" % [dialogs.size(), quits[0]])
	# The same press as a key and as a notification counts once: the question stays open.
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	_check(is_instance_valid(dialogs[0]) and not dialogs[0].is_queued_for_deletion(), "two Back requests inside 250 ms count once")
	dialogs[0].quit_button.pressed.emit()
	_check(quits[0] == 1, "QUIT in the question quits the app through the quit hook (%d)" % quits[0])
	_check(_app.client.state == ControllerClient.State.IDLE, "and the phone leaves the TV first")
	_app.quit_hook = Callable()
	_app._last_back_ms = 0
	_app.client.slot = 1
	_app.client.color = Protocol.PLAYER_COLORS[1]


## All the Controls with text of `screen` that are not inside a scroll container.
func _fixed_controls(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is ScrollContainer:
			continue
		if c is Control and c.visible and (c is Label or c is Button or c is LineEdit):
			out.append(c)
		_fixed_controls(c, out)


## The safe area is physical: a notch at the left of the phone keeps its room at the left in Hebrew too (REQ-FL-68).
func _safe_rtl() -> void:
	print("safe area in Hebrew")
	var insets := Vector4(177.0, 40.0, 0.0, 30.0)
	for lang in ["en", "he"]:
		_app.set_language(lang, false)
		_app.go(_app.ControllerWait)
		await process_frame
		await process_frame
		_app._apply_insets(insets)
		await process_frame
		var r: Rect2 = _app.current_screen().get_global_rect()
		var vp: Vector2 = root.get_visible_rect().size
		_check(absf(r.position.x - 177.0) < 0.5 and absf(vp.x - r.end.x) < 0.5,
				"[%s] a left inset of 177 px stays at the physical left (screen x %.0f to %.0f of %.0f)"
				% [lang, r.position.x, r.end.x, vp.x])
	_app.set_language("en", false)
	_app._apply_insets(Vector4.ZERO)


## REQ-FL-86 (issue #54): on the phone no button has the focus or can take it, on any phone screen. A text field keeps its focus
## mode: the keyboard needs it.
func _no_focus() -> void:
	print("no focus on the phone")
	var names := ["controller_connect", "controller_wait", "controller_settings", "about_screen", "controller_profiles",
			"controller_profile_edit", "controller_profile_share", "controller_pad", "controller_quit_dialog"]
	for name in names:
		var screen := _screen(load("res://scripts/ui/%s.gd" % name))
		await process_frame
		await process_frame
		await process_frame
		var buttons := screen.find_children("*", "Button", true, false)
		var bad: Array[String] = []
		for b in buttons:
			if b.focus_mode != Control.FOCUS_NONE or b.has_focus():
				bad.append(str(b.name))
		_check(bad.is_empty(), "%s: %d buttons, none takes or has the focus (%s)" % [name, buttons.size(), str(bad)])
		screen.queue_free()


## Test 13.6: every phone screen stays inside the safe area of an iPhone with a Dynamic Island, portrait and landscape.
func _safe_layout() -> void:
	print("safe area layout")
	var cases := {
		"portrait": {"window": Vector2(1179, 2556), "safe": Rect2(0, 177, 1179, 2280), "viewport": Vector2(1080, 1920)},
		"landscape": {"window": Vector2(2556, 1179), "safe": Rect2(177, 0, 2202, 1179), "viewport": Vector2(1920, 886)},
	}
	var names := ["controller_connect", "controller_wait", "controller_settings", "about_screen", "controller_profiles",
			"controller_pad"]
	for case_name in cases:
		var c: Dictionary = cases[case_name]
		var m: Vector4 = SafeArea.insets(c.window, c.safe, c.viewport)
		var holder := Control.new()
		holder.position = Vector2(m.x, m.y)
		holder.size = Vector2(c.viewport.x - m.x - m.z, c.viewport.y - m.y - m.w)
		root.add_child(holder)
		var outside: Array[String] = []
		var count := 0
		for name in names:
			var screen := _screen(load("res://scripts/ui/%s.gd" % name), holder)
			screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await process_frame
			await process_frame
			var list := []
			_fixed_controls(screen, list)
			var safe := holder.get_global_rect().grow(0.5)
			for ctrl in list:
				count += 1
				if not safe.encloses(ctrl.get_global_rect()):
					outside.append("%s/%s %s" % [name, ctrl.name, str(ctrl.get_global_rect())])
			if name == "controller_pad":
				for r in [screen._rect_leave(), screen._rect_recenter()]:
					count += 1
					if not holder.get_rect().grow(0.5).encloses(Rect2(holder.position + r.position, r.size)):
						outside.append("pad rect " + str(r))
				var a_r: float = screen._radius()
				for center in [screen._center_a(), screen._center_b()]:
					count += 1
					if not Rect2(Vector2.ZERO, screen.size).grow(0.5).encloses(Rect2(center - Vector2(a_r, a_r),
							Vector2(a_r, a_r) * 2.0)):
						outside.append("pad button " + str(center))
			screen.queue_free()
		var fits := outside.is_empty() and count > 20
		_check(fits,
				"[%s] %d texts, buttons and pad rects are inside the safe area (inset top %.0f, bottom %.0f, left %.0f; outside: %s)"
				% [case_name, count, m.y, m.w, m.x, str(outside)])
		holder.queue_free()
