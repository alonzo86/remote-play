extends SceneTree
## The Settings row "approve new players" (issue #393, docs/JOIN_APPROVAL_PLAN.md phase 4, 7.3; docs/TV_FLOW.md REQ-FL-93, 102):
## the row is the first of 6 and has the focus when Settings opens; Left and Right set it ON and OFF (mirrored in Hebrew), OK does
## nothing; the choice is saved in settings.cfg and given to the TV server (`set_approve_new`); OFF refuses the phones that wait
## and lets nobody in; the texts in both languages; the 6 rows stay inside the 60 px margin when the focus walks (REQ-FL-23).
## The default, the saved file and the wrong types are in tests/config_files.gd.
## The App of this run has the approval OFF in memory (tests/import_guard.gd); the suite turns it ON where it tests it, and it
## puts the settings file of the machine back.
## Run by tests/run_all.sh: godot --headless --path . --script tests/approve_setting.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const Lang = preload("res://scripts/core/lang.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const EDGE := Rect2(60, 60, 1800, 960)

var _checks := 0
var _fails := 0
var _app: Node


## A phone by script: it keeps every frame that the TV sent.
class Fake extends RefCounted:
	var ws := WebSocketPeer.new()
	var frames: Array = []

	func poll() -> void:
		ws.poll()
		while ws.get_ready_state() == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count() > 0:
			frames.append(Protocol.parse_json(ws.get_packet().get_string_from_utf8()))

	func has(t: String) -> bool:
		return frames.any(func(f: Dictionary) -> bool: return f.get("t", "") == t)

	func reason() -> String:
		for i in range(frames.size() - 1, -1, -1):
			if frames[i].get("t", "") in ["kicked", "reject"]:
				return str(frames[i].get("reason", ""))
		return ""


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	e = InputEventAction.new()
	e.action = action
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(2)


func _saved() -> Variant:
	var cfg := ConfigFile.new()
	cfg.load(_app.SETTINGS_FILE)
	return cfg.get_value("settings", "approve_players", null)


func _texts(row: Node) -> Array:
	return row.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _run() -> void:
	await _frames(5)
	_app = root.get_node("App")
	root.size = Vector2i(1920, 1080)
	if not _app.server.listening:
		_check(false, "the TV server listens (another TV app or test holds port %d)" % Protocol.WS_PORT)
		return
	# The real boot path: `_start_tv` gave the server the saved setting (the default is ON; the machine's own settings file may say
	# OFF, so the check compares with the setting, not with the literal). tests/import_guard.gd kept the value before it turned the
	# approval off for the suite.
	_check(_app.has_meta("approve_at_boot") and bool(_app.get_meta("approve_at_boot")) == bool(_app.settings.approve_players),
			"at boot the server got the saved setting: %s" % str(_app.get_meta("approve_at_boot", "not kept")))
	var had := FileAccess.file_exists(_app.SETTINGS_FILE)
	var old_text := FileAccess.get_file_as_string(_app.SETTINGS_FILE) if had else ""
	var old_settings: Dictionary = _app.settings.duplicate()
	_app.settings.language = "en"
	_app.set_language("en", false)
	await _rows_and_focus()
	await _toggle()
	await _refuses_waiting()
	await _layout()
	_texts_of_both()
	_app.set_approve_players(false)
	_app.settings.merge(old_settings, true)
	_app.set_language("en", false)
	if had:
		var f := FileAccess.open(_app.SETTINGS_FILE, FileAccess.WRITE)
		f.store_string(old_text)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_app.SETTINGS_FILE))
	_app.go_connect()


func _rows_and_focus() -> void:
	print("the row is first and has the focus")
	_app.set_approve_players(true)
	_app.go_settings()
	await _frames(8)
	var screen: Control = _app.current_screen()
	var rows: Array = screen._rows
	_check(rows.size() == 6, "Settings has 6 rows (approve, debug, invert, music, effects, language)")
	var names := rows.map(func(r: Control) -> String: return String(_texts(r)[0]))
	_check(names[0] == "settings.approve_players" or names[0] == Lang.t("settings.approve_players"),
			"the first row is 'approve new players' (%s)" % str(names))
	_check(names[1] == "settings.debug_overlay" or names[1] == Lang.t("settings.debug_overlay"),
			"Debug overlay is the second row, after it")
	_check(root.gui_get_focus_owner() == rows[0], "the focus is on the approve row when Settings opens")
	_check(_texts(rows[0])[1] in ["common.on", Lang.t("common.on")], "the row says ON when the setting is ON")
	var state: Label = rows[0].find_children("*", "Label", true, false)[1]
	_check(state.get_theme_color("font_color") == UiTheme.OK, "ON is green (UiTheme.OK)")


func _toggle() -> void:
	print("Left, Right and OK")
	var rows: Array = _app.current_screen()._rows
	rows[0].grab_focus()
	await _frames(2)
	await _key("ui_accept")
	_check(_app.settings.approve_players == true and _app.server.approve_new, "OK on the row does nothing (it stays ON)")
	await _key("ui_left")
	_check(_app.settings.approve_players == false and not _app.server.approve_new,
			"Left sets it OFF in the settings and in the TV server")
	_check(_saved() == false, "OFF is saved in settings.cfg")
	_check(_texts(rows[0])[1] in ["common.off", Lang.t("common.off")], "the row says OFF")
	var state: Label = rows[0].find_children("*", "Label", true, false)[1]
	_check(state.get_theme_color("font_color") == UiTheme.TEXT_INFO, "OFF is gray (UiTheme.TEXT_INFO)")
	await _key("ui_right")
	_check(_app.settings.approve_players == true and _app.server.approve_new, "Right sets it ON again in both")
	_check(_saved() == true, "ON is saved in settings.cfg")
	await _key("ui_left")
	await _key("ui_left")
	_check(_app.settings.approve_players == false, "a second Left keeps it OFF")
	_check(_app.settings.overlay == false, "the choice does not touch the debug overlay")
	_app.set_language("he", false)
	_app.go_settings()
	await _frames(8)
	rows = _app.current_screen()._rows
	rows[0].grab_focus()
	await _frames(2)
	await _key("ui_left")
	_check(_app.settings.approve_players == true, "in Hebrew the layout is mirrored: Left sets it ON")
	await _key("ui_right")
	_check(_app.settings.approve_players == false and not _app.server.approve_new, "in Hebrew Right sets it OFF")
	_app.set_language("en", false)


func _refuses_waiting() -> void:
	print("OFF refuses the phones that wait (REQ-FL-102)")
	_app.set_approve_players(true)
	_app.server.address_lookup = func() -> String: return "192.168.1.20"   # A sandbox may have no Wi-Fi address, so no room code.
	_app.server.ip = "192.168.1.20"
	var f := Fake.new()
	f.ws.connect_to_url("ws://127.0.0.1:%d" % Protocol.WS_PORT)
	var t0 := Time.get_ticks_msec()
	var sent := false
	while Time.get_ticks_msec() - t0 < 5000 and not f.has("pending"):
		f.poll()
		if not sent and f.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			f.ws.send_text(Protocol.to_json({"t": "hello", "v": Protocol.VERSION, "room": _app.server.room_code,
					"token": "", "name": "Sam"}))
			sent = true
		await process_frame
	_check(f.has("pending") and not f.has("welcome") and _app.server.request_count() == 1,
			"with the setting ON a new phone waits and takes no slot")
	_app.set_approve_players(false)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000 and f.reason() == "":
		f.poll()
		await process_frame
	_check(f.reason() == "refused" and not f.has("welcome"), "turning it OFF refuses the waiting phone (kicked/refused, no welcome)")
	_check(_app.server.request_count() == 0 and _app.server.connected_slots().is_empty(), "nobody joined by the change")
	f.ws.close()


func _layout() -> void:
	print("6 rows inside the 60 px margin (REQ-FL-23)")
	for lang in ["en", "he"]:
		_app.set_language(lang, false)
		_app.go_settings()
		await _frames(8)
		var rows: Array = _app.current_screen()._rows
		var inside := true
		for r: Button in rows:
			r.grab_focus()
			await _frames(4)
			inside = inside and EDGE.encloses(r.get_global_rect())
		_check(inside, "%s: every row is inside the 60 px margin when it has the focus (%s)" % [lang, str(EDGE)])
		_check(rows.all(func(r: Button) -> bool: return r.custom_minimum_size.y == 120.0), "%s: every row is 120 px high" % lang)
		rows[0].grab_focus()
		await _frames(4)
		var labels: Array = rows[0].find_children("*", "Label", true, false)
		_check(not labels[0].get_global_rect().intersects(labels[1].get_global_rect()),
				"%s: the name and the value of the first row do not touch" % lang)
	_app.set_language("en", false)


func _texts_of_both() -> void:
	print("the texts")
	_check(Lang.t("settings.approve_players") != "settings.approve_players", "the key has a text")
	Lang.set_language("en", root)
	_check(Lang.t("settings.approve_players") == "APPROVE NEW PLAYERS", "English: APPROVE NEW PLAYERS")
	Lang.set_language("he", root)
	_check(Lang.t("settings.approve_players") == "אישור שחקנים חדשים", "Hebrew: אישור שחקנים חדשים")
	Lang.set_language("en", root)
