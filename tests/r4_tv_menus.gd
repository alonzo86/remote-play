extends SceneTree
## Test 21 on the TV (docs/MANUAL_TESTS.md test 21): the Connect screen shows the room code and no PIN (1a);
## the Players modal shows the room code, and a late phone joins with it (7); Settings, About and OK (keys of the
## remote) open the list with "Godot Engine" and "3rd Party Libraries" (8a2); the Godot page has the MIT text, a library page
## opens, and so does a library with two licenses (8b).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/r4_tv_menus.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const About = preload("res://scripts/core/about.gd")
const Lang = preload("res://scripts/core/lang.gd")

var _checks := 0
var _fails := 0
var _app: Node


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


func _wait_until(cond: Callable, max_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


## A key of the remote as an input action. A button acts when the key is let go.
func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(3)


func _labels(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(l): return String(l.text))


func _buttons(node: Node) -> Array:
	return node.find_children("*", "Button", true, false)


## OK on the button: the focus goes to it, then the key of the remote.
func _ok_on(b: Button) -> void:
	b.grab_focus()
	await _frames(1)
	await _press("ui_accept")


func _run() -> void:
	await _frames(5)
	_app = root.get_node("App")
	root.size = Vector2i(1920, 1080)
	await _frames(3)
	if not _app.server.listening:
		_check(false, "the TV server listens (another TV app or test holds port %d)" % Protocol.WS_PORT)
		return
	_app.settings.language = "en"
	_app.set_language("en")
	var lookup: Callable = _app.server.address_lookup
	_app.server.address_lookup = func() -> String: return "192.168.0.1"   # A sandbox may have no Wi-Fi address, so no room code.
	_app.server.ip = "192.168.0.1"
	await _connect_screen()
	await _players_modal()
	await _settings_about()
	_app.server.address_lookup = lookup
	_app.go_connect()


## 1a: the room code of the TV address, and no PIN.
func _connect_screen() -> void:
	print("the Connect screen of the TV")
	_app.go_connect()
	await _frames(4)
	var screen: Control = _app.current_screen()
	var texts := _labels(screen)
	_check(texts.has(_app.server.room_code) and _app.server.room_code == Protocol.room_code_for_ip("192.168.0.1"),
			"1a: the Connect screen shows the room code %s of the TV address" % _app.server.room_code)
	_check(not texts.has("pin.name") and not texts.any(func(t): return String(t).begins_with("PIN")), "1a: and no PIN")


## 7: the Players modal holds the room code, and a late phone joins with exactly this.
func _players_modal() -> void:
	print("the Players modal")
	_app.go_games()
	await _frames(6)
	var games: Control = _app.current_screen()
	games._open_players()
	await _frames(4)
	var modal: Control = games._modal
	_check(modal != null, "7: the Players badge opens the Players modal")
	if modal == null:
		return
	var texts := _labels(modal)
	_check(texts.has(_app.server.room_code), "7: the modal shows the room code %s" % _app.server.room_code)
	_check(not texts.any(func(t): return String(t).begins_with("PIN") or String(t).begins_with("pin.")), "7: and no PIN")
	var room := ""
	for t in texts:
		if String(t) == _app.server.room_code:
			room = String(t)
	var late := ControllerClient.new()
	root.add_child(late)
	var reasons: Array[String] = []
	late.rejected.connect(func(reason: String): reasons.append(reason))
	late.connect_to("127.0.0.1", Protocol.WS_PORT, "AAAA")
	var refused := await _wait_until(func(): return not reasons.is_empty(), 3000)
	await _frames(2)
	_check(refused and reasons[0] == "bad_room" and _app.server.player_count() == 0,
			"7: a phone with another room code is not let in (the code matters)")
	late.connect_to("127.0.0.1", Protocol.WS_PORT, room)
	var joined := await _wait_until(func(): return late.state == ControllerClient.State.CONNECTED, 4000)
	_check(joined and _app.server.player_count() == 1, "7: a late phone joins with the room code of the modal")
	late.leave()
	late.queue_free()
	await _wait_until(func(): return _app.server.player_count() == 0, 3000)
	modal.on_back()
	await _frames(3)


## 8a2 and 8b: Settings, About and OK with the remote, the pages by the same keys.
func _settings_about() -> void:
	print("Settings, About and the pages")
	_app.go_settings()
	await _frames(5)
	var settings: Control = _app.current_screen()
	_check(settings.get_script() == _app.TvSettings, "8a2: the Settings screen is open")
	# Issue #122: an on/off row changes with Left and Right, and OK does nothing.
	var invert_row: Button = settings._rows[2]   # Rows: approve new players, debug overlay, invert tilt axes (issue #393).
	var invert_before: bool = _app.settings.invert_tilt
	invert_row.grab_focus()
	await _frames(1)
	await _press("ui_accept")
	_check(_app.settings.invert_tilt == invert_before, "8a2: OK on 'Invert tilt axes' changes nothing")
	await _press("ui_right")
	_check(_app.settings.invert_tilt, "8a2: Right sets 'Invert tilt axes' to ON")
	await _press("ui_right")
	_check(_app.settings.invert_tilt, "8a2: Right again keeps it ON")
	await _press("ui_left")
	_check(not _app.settings.invert_tilt, "8a2: Left sets it to OFF")
	_app.settings.invert_tilt = invert_before
	_app.save_settings()
	var about_item: Button = null
	for b in _buttons(settings):
		if b.text == "common.about":
			about_item = b
	_check(about_item != null, "8a2: Settings has the item About")
	if about_item == null:
		return
	await _ok_on(about_item)
	await _frames(4)
	var screen: Control = _app.current_screen()
	_check(screen.get_script() == _app.AboutScreen, "8a2: OK on About opens the About screen")
	if screen.get_script() != _app.AboutScreen:
		return
	var rows: Array = _buttons(screen)
	var texts: Array = rows.map(func(b): return String(b.text))
	_check(texts.has("GODOT ENGINE") and texts.has(Lang.t("about.third_party_libraries").to_upper()),
			"8a2: the list shows Godot Engine and 3rd Party Libraries: %s" % str(texts))

	# 8b: the Godot page.
	var godot: Button = rows[texts.find("GODOT ENGINE")]
	await _ok_on(godot)
	await _frames(4)
	var page_text := " ".join(_labels(screen))
	_check(screen.open_page >= 0 and not screen.in_libraries and page_text.contains("Permission is hereby granted"),
			"8b: the Godot page shows the MIT text")
	screen.on_back()
	await _frames(4)
	_check(screen.open_page == -1, "8b: Back returns to the list")

	# The list of libraries, a library (FreeType) and a library with two licenses.
	rows = _buttons(screen)
	texts = rows.map(func(b): return String(b.text))
	await _ok_on(rows[texts.find(Lang.t("about.third_party_libraries").to_upper())])
	await _frames(4)
	_check(screen.in_libraries and screen.open_page == -1, "8b: OK on 3rd Party Libraries opens the list of libraries")
	var libs: Array = About.libraries(OS.get_name() == "Android")
	var free_i := -1
	var two_i := -1
	for i in libs.size():
		if free_i < 0 and String(libs[i].title).to_lower().contains("freetype"):
			free_i = i
		if two_i < 0 and String(libs[i].license).contains(","):
			two_i = i
	_check(free_i >= 0 and two_i >= 0, "8b: the libraries include FreeType and one with two licenses")
	for pick in [free_i, two_i]:
		if pick < 0:
			continue
		var lib_rows: Array = screen._scroll.find_children("*", "Button", true, false)
		await _ok_on(lib_rows[pick])
		await _frames(4)
		var text := " ".join(_labels(screen._scroll))
		_check(screen.open_page == pick and text.strip_edges().length() > 100,
				"8b: the page of '%s' (%s) opens with its text" % [libs[pick].title, libs[pick].license])
		screen.on_back()
		await _frames(4)
		_check(screen.in_libraries and screen.open_page == -1, "8b: Back returns to the list of libraries")
	screen.on_back()
	await _frames(3)
	_app.go_connect()
