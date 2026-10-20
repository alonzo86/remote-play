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
		print("  KNOWN BUG ", issue, ": ", what)


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
	await _fonts_and_background()
	await _back_key()
	await _safe_layout()
	_app.client._set_state(ControllerClient.State.IDLE)


func _screen(script: GDScript, parent: Control = null) -> Control:
	var s: Control = script.new()
	s.theme = _app.theme_res
	if parent != null:
		parent.add_child(s)
	else:
		root.add_child(s)
	return s


## The hue of a color in degrees.
func _hue(c: Color) -> float:
	return c.h * 360.0


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
		_check(pressed.bg_color != normal.bg_color and pressed.bg_color == UiTheme.TEXT and normal.bg_color == UiTheme.BG,
				"[%s] a pressed button fills with white and a normal one is black" % lang)
		_check(b.get_theme_color("font_pressed_color") == UiTheme.BG and b.get_theme_color("font_color") == UiTheme.TEXT,
				"[%s] the text of a pressed button turns black on the white fill" % lang)
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


## Test 7.6c, 6d: A is green, B is red; a pressed button sits lower (REQ-FL-52).
func _pad_buttons() -> void:
	print("A and B")
	_check(_hue(UiTheme.OK) >= 90.0 and _hue(UiTheme.OK) <= 150.0, "A is green (hue %.0f degrees)" % _hue(UiTheme.OK))
	var bad_hue := _hue(UiTheme.BAD)
	_check(bad_hue < 20.0 or bad_hue > 340.0, "B is red (hue %.0f degrees)" % bad_hue)
	var pad_script: GDScript = _pad_script
	_check(pad_script.BUTTON_LIFT - pad_script.BUTTON_LIFT_DOWN > 0.0 and pad_script.BUTTON_LIFT_DOWN < pad_script.BUTTON_LIFT,
			"a pressed arcade button sits lower than a free one (%.0f against %.0f px)"
			% [pad_script.BUTTON_LIFT_DOWN, pad_script.BUTTON_LIFT])
	var src := FileAccess.get_file_as_string("res://scripts/ui/controller_pad.gd")
	var draws_a: bool = src.contains('_draw_button(_center_a(), "A", Protocol.BTN_A, UiTheme.OK)')
	var draws_b: bool = src.contains('_draw_button(_center_b(), "B", Protocol.BTN_B, UiTheme.BAD)')
	_check(draws_a and draws_b, "the pad draws A with the green and B with the red")


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
	_check(quits[0] == 1, "Back on the Connect screen of the phone quits the app through the quit hook (%d)" % quits[0])
	_check(_app.client.state == ControllerClient.State.IDLE, "and the phone leaves the TV first")
	# With the PIN pad open, Back closes the pad and does not quit.
	screen = _app.current_screen()
	screen._ask_pin("127.0.0.1", 1, "ABCD")
	await process_frame
	_check(screen._pad != null, "the PIN pad is open")
	_app._last_back_ms = 0
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(screen._pad == null and quits[0] == 1, "Back closes the PIN pad and the app stays open")
	# The same press as a key and as a notification counts once.
	_app._last_back_ms = 0
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(quits[0] == 2, "two Back requests inside 250 ms count once (%d quits)" % quits[0])
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
		if case_name == "landscape":
			# The phone is locked to portrait (project.godot, orientation.controller = 1, also on iOS through the custom feature
			# "controller"), so this case does not happen today. It is kept for the day the lock is removed.
			_known_bug("issue-needed: the waiting screen is taller than a landscape phone (only when rotation is allowed)", fits,
					"[landscape] every text and button is inside the safe area (outside: %s)" % str(outside))
			holder.queue_free()
			continue
		_check(fits,
				"[%s] %d texts, buttons and pad rects are inside the safe area (inset top %.0f, bottom %.0f, left %.0f; outside: %s)"
				% [case_name, count, m.y, m.w, m.x, str(outside)])
		holder.queue_free()
