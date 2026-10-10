extends SceneTree
## Menu item states and the pixel cursor, the double frame, blinking prompts (REQ-FL-38, 41, 42, 53), the Leave box of the phone
## wait screen (REQ-FL-52), English and left to right (REQ-FL-54), the game tile images and the Back key (REQ-FL-55).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/ui_states.gd -- --role=controller

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Shell = preload("res://scripts/game/shell.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

var _checks := 0
var _fails := 0


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
	_button_styles()
	await _wait_screen_leave()
	_english_ltr()
	_back_key()
	_tile_images()
	_safe_area()


func _button_styles() -> void:
	print("menu items")
	# A menu item is text: no box. The focused item is yellow, a destructive one is red, a quiet one is dim. A disabled
	# one is dim. The text of every state has a contrast of 4.5:1 or more on the black screen (REQ-FL-41, 53).
	var theme := UiTheme.make()
	var focus_colors := {"Button": UiTheme.ACCENT, "DangerButton": UiTheme.BAD, "QuietButton": UiTheme.ACCENT}
	var item_ok := true
	for type in focus_colors:
		item_ok = item_ok and theme.get_color("font_focus_color", type) == focus_colors[type]
		for c in ["font_color", "font_focus_color", "font_disabled_color", "font_pressed_color"]:
			item_ok = item_ok and UiTheme.contrast(theme.get_color(c, type), UiTheme.BG) >= 4.5
		for st in ["normal", "focus", "pressed", "disabled"]:
			item_ok = item_ok and theme.get_stylebox(st, type) is StyleBoxEmpty   # No box, no shadow, no outline.
	_check(item_ok, "menu items: no box, yellow with the focus, red for a destructive item, 4.5:1 or more in every state")
	_check(theme.get_color("font_color", "QuietButton") == UiTheme.TEXT_DIM and theme.get_color("font_disabled_color", "Button")
			== UiTheme.DISABLED, "a quiet item and a disabled item are dim")
	# The cursor is made of pixels: 4 columns of 7, 5, 3 and 1 pixels, tall in the middle (REQ-FL-41).
	var rects := UiTheme.cursor_rects(Vector2(0, 100), 5.0)
	_check(rects.size() == 4 and rects[0].size == Vector2(5, 35) and rects[1].size == Vector2(5, 25)
			and rects[3].size == Vector2(5, 5) and rects[0].position.y == 100.0 - 17.5 and rects[3].position.x == 15.0,
			"the cursor is a stepped triangle that points right")
	var flipped := UiTheme.cursor_rects(Vector2(0, 100), 5.0, true)
	_check(flipped[0].position.x == 15.0 and flipped[3].position.x == 0.0, "a flipped cursor points left (right to left layouts)")
	var item: Button = UiKit.item("Quit", func(): pass, 40, "danger")
	root.add_child(item)
	_check(item.text == "QUIT" and item.theme_type_variation == "DangerButton" and item.focus_mode == Control.FOCUS_ALL,
			"a menu item shows upper case text and keeps its role")
	item.queue_free()
	# The double frame: a 6 px line, 6 px of black, a 6 px line, and the content margin covers all three.
	var fr := UiTheme.frame(24)
	_check(fr.rings() == [6, 6, 6] and fr.get_margin(SIDE_LEFT) == 42.0 and fr.outer_color == UiTheme.TEXT
			and fr.inner_color == UiTheme.FRAME,
			"a panel has a double frame: white line, black gap, blue line")
	var box := UiTheme.card(UiTheme.BG, UiTheme.TEXT, 6, 30, true)
	_check(box.corner_radius_top_left == 0 and box.shadow_size == 0,
			"boxes have square corners and no shadow, whatever the game asks for")
	# A prompt blinks with a hard step: 0.55 s on, 0.55 s off.
	_check(UiTheme.blink_on(0.0) and UiTheme.blink_on(0.54) and not UiTheme.blink_on(0.56) and not UiTheme.blink_on(1.09)
			and UiTheme.blink_on(1.11), "a prompt is on for 0.55 s and off for 0.55 s")
	var blink: Label = UiKit.blinking("Press OK")
	root.add_child(blink)
	blink._process(0.6)
	_check(blink.text == "PRESS OK" and blink.modulate.a == 0.0, "the blinking label is hidden in the off half")
	blink._process(0.55)
	_check(blink.modulate.a == 1.0, "and shows again in the next on half")
	blink.queue_free()
	_check(Shell.countdown_size(0.0) == 352 and Shell.countdown_size(0.1) == 320 and Shell.countdown_size(0.2) == 288
			and Shell.countdown_size(1.0) == 256, "the countdown number settles in 4 steps of the font grid")
	var fonts_ok := true
	for path in [UiTheme.FONT_FILE, UiTheme.FONT_HEBREW]:
		var imp := FileAccess.get_file_as_string(path + ".import")
		fonts_ok = fonts_ok and imp.contains("antialiasing=0") and imp.contains("hinting=0") and imp.contains("subpixel_positioning=0")
	_check(fonts_ok, "both pixel fonts are imported with no smoothing and no hinting, so the pixels stay sharp (REQ-FL-39)")
	_check(UiTheme.font().fallbacks.size() == 1 and UiTheme.font().has_char("A".unicode_at(0)),
			"the Hebrew pixel font is the fallback of the arcade font")


## The first tap on Leave arms it (red, "Tap again to leave"), a tap after the time is over arms it again, and
## a second tap inside the time leaves (REQ-FL-52).
func _wait_screen_leave() -> void:
	print("wait screen Leave")
	var app: Node = root.get_node("App")
	var wait: Control = load("res://scripts/ui/controller_wait.gd").new()
	root.add_child(wait)
	await process_frame
	_check(wait._leave.text == "LEAVE" and wait._leave_timer.is_stopped(), "Leave starts as a white box")
	app.client._set_state(ControllerClient.State.CONNECTED)
	wait._leave.pressed.emit()
	_check(app.client.state == ControllerClient.State.CONNECTED and not wait._leave_timer.is_stopped()
			and wait._leave.get_theme_color("font_color") == UiTheme.BAD and wait._leave.text.contains("TAP AGAIN"),
			"the first tap arms Leave (red) and does not leave")
	wait._leave_timer.timeout.emit() # The 3 s are over.
	_check(wait._leave.text == "LEAVE" and wait._leave.get_theme_color("font_color") == UiTheme.TEXT,
			"Leave goes back to a white box when the time is over")
	wait._leave.pressed.emit()
	wait._leave.pressed.emit()
	_check(app.client.state == ControllerClient.State.IDLE, "the second tap inside the time leaves the TV")
	wait.queue_free()


## A device in Hebrew (locale he_IL) must not mirror the UI. The app is English only and always left to right (REQ-FL-54).
func _english_ltr() -> void:
	print("english and left to right")
	var app: Node = root.get_node("App")
	TranslationServer.set_locale("he_IL")
	root.set_layout_direction(Window.LAYOUT_DIRECTION_APPLICATION_LOCALE)   # What the engine does without the setting.
	var probe := Control.new()
	root.add_child(probe)
	_check(probe.is_layout_rtl(), "on a Hebrew device the layout is right to left when nothing is done")
	app._force_english_ltr()
	_check(not probe.is_layout_rtl(), "after the app sets its own layout direction, it is left to right")
	_check(TranslationServer.get_locale().begins_with("en"), "the locale is English: %s" % TranslationServer.get_locale())
	TranslationServer.set_locale("ar_SA")
	_check(not probe.is_layout_rtl(), "an Arabic device is also left to right: the direction does not follow the locale")
	probe.queue_free()


## The screenshots of the Games screen: loaded as they are (square corners, REQ-FL-57), and a warning when one cannot load.
func _tile_images() -> void:
	print("game tile images")
	var tile_script: GDScript = load("res://scripts/ui/game_tile.gd")
	var registry: GDScript = load("res://scripts/game/registry.gd")
	_check(tile_script.load_tile("") == null and tile_script.load_tile("res://assets/tiles/does_not_exist.png") == null,
			"no path or a missing file gives no texture, so the tile shows its placeholder")
	var all_load := true
	for g in registry.GAMES:
		var t: Texture2D = tile_script.load_tile(String(g.tile))
		if t == null or t.get_width() != 640 or t.get_height() != 360:
			all_load = false
			print("    the tile of ", g.id, " did not load")
	_check(all_load, "the tile of every game in the registry loads, 640x360")


## The Back key goes back one step in the app. It must not quit the app by itself (REQ-FL-55).
func _back_key() -> void:
	print("back key")
	_check(ProjectSettings.get_setting("application/config/quit_on_go_back", true) == false,
			"the engine does not quit on the Back key: the app decides (project.godot, quit_on_go_back)")


## The safe area of a phone (REQ-FL-68): the margins that a notch, a Dynamic Island and the home bar need.
func _safe_area() -> void:
	print("safe area")
	var safe_area := load("res://scripts/ui/safe_area.gd")
	# An iPhone with a Dynamic Island: 1179x2556 px, a safe area from y 177 to y 2457, drawn in a viewport 1920 wide.
	var m: Vector4 = safe_area.insets(Vector2(1179, 2556), Rect2(0, 177, 1179, 2280), Vector2(1920, 4162))
	_check(is_equal_approx(m.x, 0.0) and is_equal_approx(m.z, 0.0) and is_equal_approx(m.y, 177.0 * 1920.0 / 1179.0)
			and is_equal_approx(m.w, 99.0 * 1920.0 / 1179.0), "the top and the bottom margins are in viewport units: %s" % str(m))
	_check(safe_area.insets(Vector2(1080, 1920), Rect2(0, 0, 1080, 1920), Vector2(1080, 1920)) == Vector4.ZERO,
			"a screen with no cut-out has no margin")
	_check(safe_area.insets(Vector2(1080, 1920), Rect2(), Vector2(1080, 1920)) == Vector4.ZERO
			and safe_area.insets(Vector2.ZERO, Rect2(0, 0, 10, 10), Vector2(1080, 1920)) == Vector4.ZERO,
			"an unknown safe area or window gives no margin")
	_check(safe_area.insets(Vector2(1080, 1920), Rect2(-20, -20, 1400, 2400), Vector2(1080, 1920)) == Vector4.ZERO,
			"a safe area larger than the window gives no negative margin")
	var landscape: Vector4 = safe_area.insets(Vector2(2556, 1179), Rect2(177, 0, 2202, 1179), Vector2(1920, 886))
	_check(landscape.x > 0.0 and landscape.z > 0.0 and landscape.y == 0.0, "a turned phone has the cut-out at the side")
	_check(safe_area.current(Vector2(1920, 1080)) == Vector4.ZERO, "a desktop window has no margin")
