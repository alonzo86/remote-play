extends SceneTree
## Button states, the Leave button of the phone wait screen (REQ-FL-41, 41a, 52, 53), English and left to right (REQ-FL-54),
## and the Back key (REQ-FL-55).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/ui_states.gd -- --role=controller

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
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


func _button_styles() -> void:
	print("button states")
	# Three button colors with a shadow, a black focus border, a sinking pressed state, a gray disabled state
	# (REQ-FL-41, 41a, 50).
	var theme := UiTheme.make()
	var fills := {"Button": UiTheme.ACCENT, "PrimaryButton": UiTheme.OK, "DangerButton": UiTheme.DANGER,
			"RowButton": UiTheme.BUTTON, "LightButton": UiTheme.CARD}
	var btn_ok := true
	for type in fills:
		var n := theme.get_stylebox("normal", type) as StyleBoxFlat
		var f := theme.get_stylebox("focus", type) as StyleBoxFlat
		var pr := theme.get_stylebox("pressed", type) as StyleBoxFlat
		var d := theme.get_stylebox("disabled", type) as StyleBoxFlat
		btn_ok = btn_ok and n.bg_color.is_equal_approx(fills[type]) and n.shadow_offset == UiTheme.SHADOW
		btn_ok = btn_ok and f.border_color == UiTheme.FOCUS_BORDER and f.border_width_left >= 10
		btn_ok = btn_ok and f.shadow_offset.x > n.shadow_offset.x
		btn_ok = btn_ok and f.bg_color.is_equal_approx(n.bg_color)
		# Pressed: no shadow, and the box moved onto where the shadow was, with the same size.
		btn_ok = btn_ok and pr.shadow_size == 0 and pr.expand_margin_left == -UiTheme.SHADOW.x \
				and pr.expand_margin_right == UiTheme.SHADOW.x and pr.expand_margin_bottom == UiTheme.SHADOW.y
		# Disabled: opaque, gray, no shadow.
		btn_ok = btn_ok and d.bg_color.a == 1.0 and d.bg_color.s < 0.15 and d.shadow_size == 0
		btn_ok = btn_ok and UiTheme.contrast(theme.get_color("font_color", type), fills[type]) >= 4.5
		btn_ok = btn_ok and UiTheme.contrast(theme.get_color("font_disabled_color", type), UiTheme.DISABLED) >= 4.5
		if not btn_ok:
			print("    button style problem: ", type)
			break
	_check(btn_ok, "buttons: 3 colors, black focus border and lift, sunk pressed state, opaque gray disabled state")
	_check(fills.Button != fills.PrimaryButton and fills.Button != fills.DangerButton, "yellow, green and red are three colors")


## The first tap on Leave arms it (red, "Tap again to leave"), a tap after the time is over arms it again, and
## a second tap inside the time leaves (REQ-FL-52).
func _wait_screen_leave() -> void:
	print("wait screen Leave")
	var app: Node = root.get_node("App")
	var wait: Control = load("res://scripts/ui/controller_wait.gd").new()
	root.add_child(wait)
	await process_frame
	_check(wait._leave.text == "Leave" and wait._leave.theme_type_variation == "" and wait._leave_timer.is_stopped(),
			"Leave starts as a plain button")
	app.client._set_state(ControllerClient.State.CONNECTED)
	wait._leave.pressed.emit()
	_check(app.client.state == ControllerClient.State.CONNECTED and not wait._leave_timer.is_stopped()
			and wait._leave.theme_type_variation == "DangerButton" and wait._leave.text.contains("Tap again"),
			"the first tap arms Leave and does not leave")
	wait._leave_timer.timeout.emit() # The 3 s are over.
	_check(wait._leave.text == "Leave" and wait._leave.theme_type_variation == "",
			"Leave goes back to a plain button when the time is over")
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


## The screenshots of the Games screen (REQ-FL-57): rounded in the image, no clipping, and a warning when one cannot load.
func _tile_images() -> void:
	print("game tile images")
	var tile_script: GDScript = load("res://scripts/ui/game_tile.gd")
	var registry: GDScript = load("res://scripts/game/registry.gd")
	var white := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var tex: Texture2D = tile_script.rounded(ImageTexture.create_from_image(white), 20)
	var img := tex.get_image()
	_check(img.get_width() == 640 and img.get_height() == 360, "rounding keeps the size of the image")
	var corners_clear := true
	for p in [Vector2i(0, 0), Vector2i(639, 0), Vector2i(0, 359), Vector2i(639, 359)]:
		corners_clear = corners_clear and img.get_pixelv(p).a < 0.05
	_check(corners_clear, "all four corner pixels are transparent")
	_check(img.get_pixel(320, 0).a == 1.0 and img.get_pixel(0, 180).a == 1.0 and img.get_pixel(320, 180).a == 1.0,
			"the middle of the edges and the center stay opaque")
	# The radius in the pixels of the image is 20 * 640 / 420 = 30.5. The circle center is at (30.5, 30.5).
	_check(img.get_pixel(3, 3).a < 0.05 and img.get_pixel(14, 14).a > 0.95 and img.get_pixel(636, 3).a < 0.05
			and img.get_pixel(625, 14).a > 0.95,
			"the cut follows a circle: (3, 3) is outside it, (14, 14) is inside it, and the right side is the same")
	_check(tile_script.load_tile("") == null and tile_script.load_tile("res://assets/tiles/does_not_exist.png") == null,
			"no path or a missing file gives no texture, so the tile shows its placeholder")
	var all_load := true
	for g in registry.GAMES:
		var t: Texture2D = tile_script.load_tile(String(g.tile))
		if t == null or t.get_width() != 640 or t.get_height() != 360 or t.get_image().get_pixel(0, 0).a > 0.05:
			all_load = false
			print("    the tile of ", g.id, " did not load with rounded corners")
	_check(all_load, "the tile of every game in the registry loads, 640x360, with rounded corners")


## The Back key goes back one step in the app. It must not quit the app by itself (REQ-FL-55).
func _back_key() -> void:
	print("back key")
	_check(ProjectSettings.get_setting("application/config/quit_on_go_back", true) == false,
			"the engine does not quit on the Back key: the app decides (project.godot, quit_on_go_back)")
