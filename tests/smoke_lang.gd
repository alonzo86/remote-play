extends SceneTree
## Smoke test of the languages and the right to left layout (REQ-FL-54, 60 to 63, REQ-GM-47o). Run:
##   godot --headless --path . --script tests/smoke_lang.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Lang = preload("res://scripts/core/lang.gd")

## Texts that stay as they are in Hebrew: brand names and the room code are not words of a language.
## Keys that code builds from a prefix and a word, so that no script has them as a whole.
const DYNAMIC_KEYS := ["game_settings.easy", "game_settings.medium", "game_settings.hard"]

const KEEP := ["PIN", "SABABI", "1P", "2P", "3P", "4P", "A", "B", "OK", "%S %D/%D"]

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


## `key` is a key of the table, and the table has a Hebrew text for it.
func _has_he(key: String) -> bool:
	return Lang.has(key) and String(Lang.table()[key].he).strip_edges() != ""


## Every literal text that the code gives to the UI is a key of the table (REQ-FL-63), so it has a Hebrew text. A text that code
## builds from parts is covered by its format key, which `Lang.f()` looks up.
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
			if t == "" or _has_he(t) or t.to_upper() in KEEP or t.to_upper() == t.to_lower() or t.ends_with("."):
				continue   # Empty, translated, a brand, or without letters.
			missing.append("%s: %s" % [path.get_file(), t])
	return missing


## The keys of the table that no script uses. A key that code builds from a prefix ("game_settings." + difficulty) is used by
## its prefix.
func _unused_keys(table: Dictionary) -> Array:
	var src := ""
	for path in _script_files("res://scripts"):
		src += FileAccess.get_file_as_string(path)
	var out: Array = []
	for k in table:
		if not src.contains('"' + k + '"') and not (k in DYNAMIC_KEYS):
			out.append(k)
	return out


## The CSV reader: quotes, commas, line breaks inside a cell, a byte order mark, a missing Hebrew text, a file without the header.
func _csv_checks() -> void:
	var csv := "\ufeffkey,en,he,notes\r\n"
	csv += 'a.b,"One, two","Say ""hi""",x\r\n'
	csv += 'c.d,"Line\nbreak",,\n\n'
	var t: Dictionary = Lang.parse_table(csv)
	_check(t.size() == 2 and t["a.b"].en == "One, two" and t["a.b"].he == 'Say "hi"',
			"the CSV reader handles commas, quotes and a byte order mark")
	_check(t["c.d"].en == "Line\nbreak" and t["c.d"].he == "Line\nbreak",
			"a line break stays in a cell, and a missing Hebrew text falls back to English")
	var file_rows: Array = Lang.parse_csv(FileAccess.get_file_as_string(Lang.TABLE_FILE))
	var no_where: Array = []
	for i in range(1, file_rows.size()):
		var row: Array = file_rows[i]
		if row.size() > 0 and row[0] != "" and (row.size() < 4 or String(row[3]).strip_edges() == ""):
			no_where.append(row[0])
	_check(file_rows[0].slice(0, 4) == ["key", "en", "he", "where"] and no_where.is_empty(),
			"the file has the column 'where' and every row says where its text is used " + str(no_where))
	_check(FileAccess.get_file_as_bytes(Lang.TABLE_FILE).slice(0, 3) == PackedByteArray([0xEF, 0xBB, 0xBF]),
			"the file starts with a byte order mark, so that Excel shows the Hebrew correctly")
	var rx := RegEx.create_from_string("%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[a-zA-Z%]")
	var mismatched: Array = []
	for i in range(1, file_rows.size()):
		var row: Array = file_rows[i]
		if row.size() < 3 or row[0] == "":
			continue
		if _placeholders(rx, row[1]) != _placeholders(rx, row[2]):
			mismatched.append(row[0])
	_check(mismatched.is_empty(), "English and Hebrew use the same placeholders in every row " + str(mismatched))
	_check(_placeholders(rx, "%d of %s, 50%%") == ["%%", "%d", "%s"] and
			_placeholders(rx, "%d") != _placeholders(rx, "%s"),
			"the placeholder check sorts the placeholders and tells %d from %s")
	_check(Lang.parse_table("a,b,c\nx,y,z").is_empty() and Lang.parse_table("").is_empty(),
			"a text without the header 'key,en,he' gives an empty table")


func _placeholders(rx: RegEx, text: String) -> Array:
	var found: Array = []
	for m in rx.search_all(text):
		found.append(m.get_string())
	found.sort()
	return found


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

	# The table (assets/lang/strings.csv): every row is complete, and every text that the UI can show is in it (REQ-FL-63).
	var table: Dictionary = Lang.table()
	var bad_rows: Array = []
	var keyre := RegEx.create_from_string("^[a-z0-9_]+\\.[a-z0-9_]+$")
	var fmtre := RegEx.create_from_string("%[-+0-9.]*[sdf]")
	for k in table:
		var en := String(table[k].en)
		var he := String(table[k].he)
		if keyre.search(k) == null or en.strip_edges() == "" or he.strip_edges() == "":
			bad_rows.append(k)
		elif fmtre.search_all(en).size() != fmtre.search_all(he).size():
			bad_rows.append(k + " (the values differ)")   # A format key must take the same values in both languages.
	_check(table.size() > 150 and bad_rows.is_empty(),
			"every row has a key like 'area.name', an English and a Hebrew text " + str(bad_rows))
	var same: Array = []
	for k in table:
		var en2 := String(table[k].en)
		if table[k].he == en2 and en2.to_upper() != en2.to_lower() and not (en2.to_upper() in KEEP):
			same.append(k)
	_check(same.is_empty(), "no Hebrew text is the English text, except the brands " + str(same))
	var missing := _untranslated_literals()
	_check(missing.is_empty(), "every literal text in the code is a key of the table " + str(missing))
	var unused := _unused_keys(table)
	_check(unused.is_empty(), "every key of the table is used in the code " + str(unused))
	var games_ok := true
	for g in Registry.all():
		games_ok = games_ok and _has_he(String(g.title)) and _has_he(String(g.description))
		for r in GameSettings.rows_for(g):
			games_ok = games_ok and _has_he(String(r.label))
			for t in r.titles:
				games_ok = games_ok and _has_he(String(t))
	_check(games_ok, "every game title, description, setting row and value is a key with a Hebrew text")
	var medals_ok := true
	for m in ["bronze", "silver", "gold", ""]:
		Lang.set_language("en", root)
		var en_label: String = Medals.label(m)
		Lang.set_language("he", root)
		medals_ok = medals_ok and Medals.label(m) != en_label
	_check(medals_ok, "every medal text is different in Hebrew")
	_csv_checks()

	# The helper.
	Lang.set_language("en", root)
	_check(Lang.t("connect.room_code") == "ROOM CODE" and Lang.f("games.up_to_players", [4]) == "Up to 4 players"
			and not Lang.is_rtl(),
			"English text comes from the table, and the layout is left to right")
	Lang.set_language("he", root)
	_check(Lang.t("connect.room_code") == "קוד חדר" and Lang.f("games.up_to_players", [4]) == "עד 4 שחקנים" and Lang.is_rtl(),
			"Hebrew text is found for a plain text and for a format key")
	_check(Lang.t("Some new text") == "Some new text" and Lang.t("Alon") == "Alon" and not Lang.has("Alon"),
			"a text that is not a key (a name) stays as it is")
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
			"the logo screen shows the logo file at 3 screen pixels per logo pixel, with sharp pixels (REQ-FL-50)")
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
	_check(texts.has("קוד חדר") and texts.has("שחקנים"), "Connect shows Hebrew text: " + str(texts.slice(0, 4)))

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
		var stays := ["SIM", app.server.room_code, "SABABI", "OK", "WI-FI", "QR", "PIN", "F3", "A", "B", "1P", "2P", "3P", "4P"]
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
	var ltr_x: float = Shell.leader_chip_x(1920.0, 300.0)
	Lang.set_language("he", root)
	var rtl_x: float = Shell.leader_chip_x(1920.0, 300.0)
	_check(is_equal_approx(ltr_x + 300.0, 1860.0), "English leader chip: it ends at the right margin")
	_check(is_equal_approx(rtl_x, 60.0), "Hebrew leader chip: it starts at the left margin")
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
