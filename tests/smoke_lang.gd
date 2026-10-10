extends SceneTree
## Smoke test of the languages and the right to left layout (REQ-FL-54, 60 to 63, REQ-GM-47o). Run:
##   godot --headless --path . --script tests/smoke_lang.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Strings = preload("res://scripts/core/strings.gd")

## Texts that stay as they are in Hebrew: brand names and the room code are not words of a language.
const KEEP := ["WOBBLE", "1P", "2P", "3P", "4P", "A", "B", "OK", "%S %D/%D"]

var _fails := 0
var _checks := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The Hebrew text of `msg` exists (a plain text in upper case, a format string as it is written).
func _has_he(msg: String) -> bool:
	return Strings.HE.has(msg) or Strings.HE.has(msg.to_upper())


## Every literal text that the code gives to the UI has a Hebrew text (REQ-FL-63). A text that code builds from parts is covered
## by its format string, which `Lang.f()` looks up.
func _untranslated_literals() -> Array:
	var missing: Array = []
	var re := RegEx.new()
	re.compile("(?:Lang\\.[tf]|UiKit\\.(?:label|title|blinking|item|box_button)|open_menu|entries\\.append\\("
			+ "|Shell\\.(?:hint|title)\\([^,\"]+,"
			+ "(?: size,)?)\\(?\\[?\\[?\"([^\"]+)\"")
	for path in _script_files("res://scripts"):
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			var t := m.get_string(1)
			if t == "" or _has_he(t) or t.to_upper() in KEEP or t.to_upper() == t.to_lower():
				continue   # Empty, translated, a brand, or without letters.
			missing.append("%s: %s" % [path.get_file(), t])
	return missing


func _script_files(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_script_files(dir + "/" + d))
	return out


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var Registry = load("res://scripts/game/registry.gd")
	var GameSettings = load("res://scripts/game/game_settings.gd")
	var Shell = load("res://scripts/game/shell.gd")
	var Medals = load("res://scripts/game/medals.gd")
	var TvLogo = load("res://scripts/ui/tv_logo.gd")
	var TvConnect = load("res://scripts/ui/tv_connect.gd")
	var TvSettings = load("res://scripts/ui/tv_settings.gd")
	var app: Node = root.get_node("App")
	var saved_settings := FileAccess.get_file_as_string(app.SETTINGS_FILE) if FileAccess.file_exists(app.SETTINGS_FILE) else ""

	# The table: nothing is empty, and every text that the UI can show is in it (REQ-FL-63).
	var empty: Array = []
	for k in Strings.HE:
		if String(Strings.HE[k]).strip_edges() == "":
			empty.append(k)
	_check(empty.is_empty(), "no Hebrew text is empty " + str(empty))
	var missing := _untranslated_literals()
	_check(missing.is_empty(), "every literal text in the code has a Hebrew text " + str(missing))
	var games_ok := true
	for g in Registry.all():
		games_ok = games_ok and _has_he(String(g.title)) and _has_he(String(g.description))
		for r in GameSettings.rows_for(g):
			games_ok = games_ok and _has_he(String(r.label))
			for t in r.titles:
				games_ok = games_ok and (_has_he(String(t)) or String(t).begins_with("Track "))
	_check(games_ok, "every game title, description, setting row and value has a Hebrew text")
	var medals_ok := true
	for m in ["bronze", "silver", "gold", ""]:
		medals_ok = medals_ok and _has_he(Medals.label(m))
	_check(medals_ok, "every medal text has a Hebrew text")

	# The helper.
	Lang.set_language("en", root)
	_check(Lang.t("Room code") == "Room code" and Lang.f("Up to %d players", [4]) == "Up to 4 players" and not Lang.is_rtl(),
			"English text is left as it is, and the layout is left to right")
	Lang.set_language("he", root)
	_check(Lang.t("Room code") == "קוד חדר" and Lang.f("Up to %d players", [4]) == "עד 4 שחקנים" and Lang.is_rtl(),
			"Hebrew text is found for a plain text and for a format string")
	_check(Lang.t("Some new text") == "Some new text" and Lang.t("Alon") == "Alon",
			"a text without a translation (a name) stays as it is")
	_check(root.get_layout_direction() == Window.LAYOUT_DIRECTION_RTL,
			"Hebrew sets the layout direction of the window to right to left")
	Lang.set_language("fr", root)
	_check(Lang.current() == "he", "a language that the app does not have is ignored")
	Lang.set_language("en", root)
	_check(root.get_layout_direction() == Window.LAYOUT_DIRECTION_LTR and Lang.other("en") == "he" and Lang.other("he") == "en",
			"English sets the layout back to left to right")
	var bidi := TextServerManager.get_primary_interface()
	var line := TextLine.new()
	line.add_string("אב CD", ThemeDB.fallback_font, 32)
	var glyphs: Array[Dictionary] = bidi.shaped_text_get_glyphs(line.get_rid())
	_check(bidi.has_feature(TextServer.FEATURE_BIDI_LAYOUT) and not glyphs.is_empty() and int(glyphs[0].start) == 3,
			"a Hebrew line with Latin letters is put in the right order (the Latin letters come first from the left)")

	# The first start (REQ-FL-60): the logo waits for the language.
	app.settings.language = ""
	app.go_logo()
	await _frames(3)
	var logo: Control = app.current_screen()
	_check(is_instance_of(logo, TvLogo) and logo.asks_language and logo.language_buttons.size() == 2,
			"the first start shows the logo with the choice 'ENGLISH' and 'עברית'")
	_check(logo.language_buttons.en.text == "ENGLISH" and logo.language_buttons.he.text == "עברית",
			"each language is written in its own language")
	var pictures := logo.find_children("*", "TextureRect", true, false)
	var picture: TextureRect = pictures[0] if pictures.size() > 0 else null
	_check(picture != null and picture.texture.get_size() == Vector2(1600, 600) and picture.custom_minimum_size == Vector2(1200, 450)
			and picture.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"the logo screen shows the logo file at 6 screen pixels per logo pixel, with sharp pixels (REQ-FL-50)")
	var splash := str(ProjectSettings.get_setting("application/boot_splash/image"))
	_check(splash == "res://assets/logo/splash.png" and ResourceLoader.exists(splash)
			and not ProjectSettings.get_setting("application/boot_splash/use_filter"),
			"the Android splash shows the square logo without a filter (REQ-FL-51)")
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 3300:
		await process_frame
	_check(app.current_screen() == logo, "the logo does not go on by itself at the first start")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	logo._unhandled_input(accept)
	await _frames(2)
	_check(app.current_screen() == logo, "OK without a choice does not skip the logo at the first start")
	logo.language_buttons.he.pressed.emit()
	await _frames(4)
	_check(is_instance_of(app.current_screen(), TvConnect) and Lang.current() == "he" and app.settings.language == "he"
			and app.server.language == "he", "choosing Hebrew saves it, switches the UI and opens the Connect screen")
	var cfg := ConfigFile.new()
	cfg.load(app.SETTINGS_FILE)
	_check(cfg.get_value("settings", "language", "") == "he" and not app.needs_language_choice(),
			"the choice is saved in the settings file")

	# The Connect screen is mirrored (REQ-FL-54): the QR card is at the right, the slots at the left.
	var connect: Control = app.current_screen()
	await _frames(3)
	var qr_x := _first(connect, "QrView").get_global_rect().get_center().x
	var slots_x := _first(connect, "SlotList").get_global_rect().get_center().x
	_check(qr_x > slots_x, "in Hebrew the QR card is at the right of the slots (%d > %d)" % [qr_x, slots_x])
	_check(connect._hint.get_theme_font_size("font_size") == 40, "the Hebrew screen keeps the text sizes")
	var texts := _texts(connect)
	_check(texts.has("קוד חדר") and texts.has("בחירת שחקנים"), "Connect shows Hebrew text: " + str(texts.slice(0, 4)))

	# Back at the first start takes the language that has the focus.
	app.settings.language = ""
	app.go_logo()
	await _frames(4)
	logo = app.current_screen()
	logo.language_buttons.en.grab_focus()
	logo.on_back()
	await _frames(3)
	_check(Lang.current() == "en" and is_instance_of(app.current_screen(), TvConnect),
			"Back at the first start chooses the focused language")
	await _frames(2)
	var qr_en := _first(app.current_screen(), "QrView").get_global_rect().get_center().x
	var slots_en := _first(app.current_screen(), "SlotList").get_global_rect().get_center().x
	_check(qr_en < slots_en, "in English the QR card is at the left of the slots (%d < %d)" % [qr_en, slots_en])

	# A phone follows the TV (REQ-FL-62).
	var c := ControllerClient.new()
	c.player_name = "Ready"   # A name that is also a word of the UI: it must stay as it is.
	root.add_child(c)
	var heard: Array = []
	c.language_changed.connect(func(code: String): heard.append(code))
	c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
	var joined := Time.get_ticks_msec()
	while app.server.connected_slots().is_empty() and Time.get_ticks_msec() - joined < 4000:
		await process_frame
	await _frames(10)
	_check(heard == ["en"], "the welcome tells the phone the language of the TV: %s" % str(heard))
	app.go_settings()
	await _frames(4)
	var settings: Control = app.current_screen()
	_check(is_instance_of(settings, TvSettings) and settings._rows.size() == 6, "Settings has the row Language")
	settings._rows[5].pressed.emit()
	await _frames(10)
	_check(Lang.current() == "he" and app.settings.language == "he" and app.server.language == "he" and heard == ["en", "he"],
			"the Language row switches the UI at once and every phone follows: %s" % str(heard))
	_check(_texts(settings).has("שפה") and _texts(settings).has("עברית"), "the Settings screen is in Hebrew at once")
	settings._rows[5].pressed.emit()
	await _frames(10)
	_check(Lang.current() == "en" and heard == ["en", "he", "en"], "the row switches back to English")
	# Every screen in Hebrew shows no English word (REQ-FL-63): the player name, the room code and the brand are the only Latin text.
	Lang.set_language("he", root)
	var shown_missing: Array = []
	var views: Array[Callable] = [app.go_connect, app.go_games, app.go_settings]
	for g in Registry.all():
		views.append(app.go_game_settings.bind(String(g.id)))
	for v in views:
		v.call()
		await _frames(4)
		var screen: Control = app.current_screen()
		if screen.has_method("_open_players"):
			screen._open_players()
			await _frames(3)
		var stays := ["SIM", app.server.room_code, "WOBBLE", "OK", "WI-FI", "QR", "F3", "A", "B", "1P", "2P", "3P", "4P"]
		for t in _latin_texts(screen, stays):
			shown_missing.append("%s: %s" % [screen.get_script().resource_path.get_file(), t])
	app.go_connect()
	await _frames(4)
	var names := _texts(_first(app.current_screen(), "SlotList"))
	_check(names.has("READY") and names.has("מוכן"),
		"a player named Ready stays Ready while the state word is translated: " + str(names))
	app.go_settings()
	await _frames(3)
	var item: Button = _first_item(app.current_screen())
	Lang.set_language("he", root)
	await _frames(2)
	var rtl_margins := _margins(item)
	Lang.set_language("en", root)
	await _frames(2)
	var ltr_margins := _margins(item)
	_check(item != null and rtl_margins.y > rtl_margins.x and ltr_margins.x > ltr_margins.y,
		"a menu item keeps the room for its cursor at the side of the cursor, in both layouts")
	Lang.set_language("he", root)
	_check(shown_missing.is_empty(), "no screen shows an untranslated English text in Hebrew " + str(shown_missing))
	Lang.set_language("en", root)
	c.leave()
	await _frames(5)

	# The HUD is mirrored in Hebrew (REQ-GM-47o); the English HUD is as before.
	var widths := [300.0, 300.0]
	var ltr: Array[Vector2] = Shell.chip_row_positions(1920.0, widths)
	Lang.set_language("he", root)
	var rtl: Array[Vector2] = Shell.chip_row_positions(1920.0, widths)
	_check(ltr[0].x < ltr[1].x and is_equal_approx(ltr[1].x + 300.0, 1860.0),
			"English chips: 1P first, the row ends at the right margin")
	_check(is_equal_approx(rtl[0].x, 370.0) and is_equal_approx(rtl[1].x, 60.0),
			"Hebrew chips: 1P is the rightmost and the row starts at the left margin")
	var probe := Control.new()
	probe.size = Vector2(1920, 1080)
	root.add_child(probe)
	_check(is_equal_approx(Shell.mx(probe, 60.0, 240.0), 1620.0), "Hebrew mirrors a box of 240 px at x 60 to x 1620")
	Lang.set_language("en", root)
	_check(is_equal_approx(Shell.mx(probe, 60.0, 240.0), 60.0), "English leaves the box where it is")
	probe.queue_free()

	# The test must not change the settings of the person who runs it.
	if saved_settings == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(app.SETTINGS_FILE))
	else:
		FileAccess.open(app.SETTINGS_FILE, FileAccess.WRITE).store_string(saved_settings)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The first node of a script class inside `node`.
func _first(node: Node, class_file: String) -> Control:
	var file: String = {"QrView": "qr_view.gd", "SlotList": "slot_list.gd"}[class_file]
	for n in node.find_children("*", "Control", true, false):
		if n.get_script() != null and String(n.get_script().resource_path).ends_with(file):
			return n
	return null


## The texts of all labels and buttons inside `node` (as they are shown).
func _texts(node: Node) -> Array:
	var out: Array = []
	for n in node.find_children("*", "", true, false):
		if n is Label or n is Button:
			out.append(n.tr(n.text) if n.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else n.text)
	return out


## The texts inside `node` that show Latin letters in Hebrew although they are not allowed: a label or button whose English text
## has no Hebrew text. `allowed` are words that stay (a name, the room code, a brand).
func _latin_texts(node: Node, allowed: Array) -> Array:
	var out: Array = []
	for n in node.find_children("*", "", true, false):
		if not (n is Label or n is Button) or n.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED:
			continue
		var t := String(n.text)
		if t.to_upper() == t.to_lower() or n.tr(t) != t:
			continue
		var words := t.to_upper().split(" ", false)
		var foreign := false
		for w in words:
			var clean := w.strip_edges().trim_suffix("S").trim_suffix(".")
			if w.to_upper() != w.to_lower() and not (w in allowed) and not (clean in allowed) and not w.is_valid_int():
				foreign = true
		if foreign and not _has_he(t):
			out.append(t)
	return out


## The first menu item (a button with the cursor) inside `node`.
func _first_item(node: Node) -> Button:
	for n in node.find_children("*", "Button", true, false):
		if n.has_method("apply_margins"):
			return n
	return null


## The left and right content margins of a menu item.
func _margins(item: Button) -> Vector2:
	if item == null:
		return Vector2.ZERO
	var sb := item.get_theme_stylebox("normal")
	return Vector2(sb.content_margin_left, sb.content_margin_right)
