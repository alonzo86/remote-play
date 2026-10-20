extends SceneTree
## Test 21 on the TV (docs/MANUAL_TESTS.md test 21): the Connect screen shows the room code and, under it, a PIN of 4 digits (1a);
## the Players modal shows the room code and the PIN, and a late phone joins with them (7); Settings, About and OK (keys of the
## remote) open the list with "Godot Engine" and "3rd Party Libraries" (8a2); the Godot page has the MIT text, a library page
## opens, and so does a library with two licenses (8b).
## The steps of the PIN change with issue #52: this suite changes with them.
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
	_app.server.pin_exempt_loopback = false   # The test phone is on this device: ask it for the PIN like a phone on the Wi-Fi.
	await _connect_screen()
	await _players_modal()
	await _settings_about()
	_app.server.pin_exempt_loopback = true
	_app.go_connect()


## 1a: the room code, then the PIN of 4 digits under it.
func _connect_screen() -> void:
	print("the Connect screen of the TV")
	_app.go_connect()
	await _frames(4)
	var screen: Control = _app.current_screen()
	var room_label: Label = null
	var pin_label: Label = null
	var name_label: Label = null
	for l in screen.find_children("*", "Label", true, false):
		if l.text == _app.server.room_code:
			room_label = l
		elif l.text == _app.server.pin:
			pin_label = l
		elif l.text == "pin.name":
			name_label = l
	_check(room_label != null, "1a: the Connect screen shows the room code %s" % _app.server.room_code)
	_check(Protocol.is_pin(_app.server.pin) and pin_label != null and name_label != null,
			"1a: and a PIN of 4 digits (%s) with the word PIN above it" % _app.server.pin)
	_check(room_label != null and pin_label != null and room_label.global_position.y < name_label.global_position.y
			and name_label.global_position.y < pin_label.global_position.y,
			"1a: the PIN is under the room code")


## 7: the Players modal holds the room code and the PIN, and a late phone joins with exactly these.
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
	var pin_text := Lang.f("pin.shown", [_app.server.pin]).to_upper()
	_check(texts.has(_app.server.room_code), "7: the modal shows the room code %s" % _app.server.room_code)
	_check(texts.has(pin_text), "7: the modal shows the PIN: '%s'" % pin_text)
	var room := ""
	var pin := ""
	for t in texts:
		if String(t) == _app.server.room_code:
			room = String(t)
		elif String(t).begins_with("PIN ") and String(t).length() == 8:
			pin = String(t).substr(4)
	var late := ControllerClient.new()
	root.add_child(late)
	var reasons: Array[String] = []
	late.rejected.connect(func(reason: String): reasons.append(reason))
	late.connect_to("127.0.0.1", Protocol.WS_PORT, room, "1111" if pin != "1111" else "2222")
	var refused := await _wait_until(func(): return not reasons.is_empty(), 3000)
	await _frames(2)
	_check(refused and reasons[0] == "bad_pin" and _app.server.player_count() == 0,
			"7: a phone with another PIN is not let in (the PIN matters)")
	late.connect_to("127.0.0.1", Protocol.WS_PORT, room, pin)
	var joined := await _wait_until(func(): return late.state == ControllerClient.State.CONNECTED, 4000)
	_check(joined and _app.server.player_count() == 1, "7: a late phone joins with the room code and the PIN of the modal")
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
