extends SceneTree
## The join PIN (FD-25): a new phone must send the PIN that the TV shows, a phone that returns with its token needs none,
## a phone on the same device needs none, and the TV makes a new PIN after too many wrong ones. Also the PIN pad of the phone
## and the pages of the About screen. Real sockets on the local machine, like tests/net_profiles.gd.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/net_pin.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PinPad = preload("res://scripts/ui/pin_pad.gd")
const About = preload("res://scripts/core/about.gd")
const Lang = preload("res://scripts/core/lang.gd")

var _checks := 0
var _fails := 0
var _server: TvServer
var _about_script: GDScript   # The screens use the autoloads (App, Role): load them when the test runs, not at compile time.
var _pad_script: GDScript
var _connect_script: GDScript


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


func _raw_hello(fields: Dictionary) -> Dictionary:
	var ws := WebSocketPeer.new()
	ws.connect_to_url("ws://127.0.0.1:%d" % Protocol.WS_PORT)
	var msg := {"t": "hello", "v": Protocol.VERSION, "room": _server.room_code, "token": "", "name": ""}
	msg.merge(fields, true)
	var sent := false
	var reply := {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000 and reply.is_empty():
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			if not sent:
				ws.send_text(Protocol.to_json(msg))
				sent = true
			while ws.get_available_packet_count() > 0:
				var parsed := Protocol.parse_json(ws.get_packet().get_string_from_utf8())
				if reply.is_empty():
					reply = parsed
		await process_frame
	return {"ws": ws, "reply": reply}


func _free_all() -> void:
	for p in _server.players:
		if p.is_present():
			_server.drop_player(p.slot)


func _run() -> void:
	_about_script = load("res://scripts/ui/about_screen.gd")
	_pad_script = load("res://scripts/ui/controller_pad.gd")
	_connect_script = load("res://scripts/ui/controller_connect.gd")
	_check(Protocol.is_pin("0427") and not Protocol.is_pin("427") and not Protocol.is_pin("04a7") and not Protocol.is_pin("04271"),
			"a PIN is exactly 4 digits")
	var pin := Protocol.make_pin()
	_check(Protocol.is_pin(pin), "a made PIN is valid: " + pin)
	_server = TvServer.new()
	root.add_child(_server)
	_server.start({})
	_server.set_phase("menu")
	_check(Protocol.is_pin(_server.pin), "the TV makes a PIN when it starts")
	_server.pin_exempt_loopback = false   # The test phones are on this device: ask them for the PIN as a phone on the Wi-Fi.
	await _join_rules()
	await _wrong_pins()
	_server.pin_exempt_loopback = true
	var same_device := await _raw_hello({})
	_check(same_device.reply.get("t", "") == "welcome", "a phone on the same device needs no PIN")
	_free_all()
	_server.stop()
	await _pad()
	_about()
	await _about_screen()


func _join_rules() -> void:
	print("join with the PIN")
	var none := await _raw_hello({})
	_check(none.reply.get("t", "") == "reject" and none.reply.get("reason", "") == "bad_pin", "no PIN: rejected as bad_pin")
	var wrong := await _raw_hello({"pin": "0000" if _server.pin != "0000" else "1111"})
	_check(wrong.reply.get("reason", "") == "bad_pin", "a wrong PIN is rejected")
	var good := await _raw_hello({"pin": _server.pin})
	_check(good.reply.get("t", "") == "welcome", "the right PIN joins")
	var token := String(good.reply.get("token", ""))
	_check(_server.connected_slots().size() == 1, "the phone holds a slot")
	good.ws.close()
	await create_timer(0.3).timeout
	var again := await _raw_hello({"token": token})
	_check(again.reply.get("t", "") == "welcome" and int(again.reply.get("slot", -1)) == int(good.reply.get("slot", -2)),
			"a phone that returns with its token needs no PIN")
	var client := ControllerClient.new()
	root.add_child(client)
	client.connect_to("127.0.0.1", Protocol.WS_PORT, _server.room_code, _server.pin)
	var t0 := Time.get_ticks_msec()
	while client.state != ControllerClient.State.CONNECTED and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	_check(client.state == ControllerClient.State.CONNECTED and client.pin == "",
			"the phone client joins with the PIN and then forgets it")
	client.leave()
	client.queue_free()
	_free_all()


func _wrong_pins() -> void:
	print("too many wrong PINs")
	_server.pin = "1234"
	for i in Protocol.PIN_TRIES - 1:
		await _raw_hello({"pin": "0000"})
	var right := await _raw_hello({"pin": "1234"})
	_check(right.reply.get("t", "") == "welcome", "a right PIN after fewer wrong ones than the limit still joins")
	_free_all()
	for i in Protocol.PIN_TRIES:
		var wrong := await _raw_hello({"pin": "0000"})
		_check(wrong.reply.get("reason", "") == "bad_pin", "wrong PIN %d is bad_pin" % (i + 1))
	var locked := await _raw_hello({"pin": "1234"})
	_check(locked.reply.get("reason", "") == "pin_locked" and _server.pin == "1234",
			"after %d wrong PINs even the right PIN is turned away, and the PIN stays" % Protocol.PIN_TRIES)
	_server._pin_locked_until_ms = 0   # The lock time is over.
	var after := await _raw_hello({"pin": "1234"})
	_check(after.reply.get("t", "") == "welcome", "after the lock time the right PIN joins again")
	var token := String(after.reply.get("token", ""))
	for i in Protocol.PIN_TRIES:
		await _raw_hello({"pin": "0000"})
	var kept := await _raw_hello({"token": token})
	_check(kept.reply.get("t", "") == "welcome", "a phone with its token is not turned away by the lock")
	_server._pin_locked_until_ms = 0
	_free_all()
	# A hello with no PIN and a token that the TV does not know (a phone after a TV restart) is no guess: it does not lock.
	for i in Protocol.PIN_TRIES + 2:
		var stale := await _raw_hello({"token": "unknown-token"})
		_check(stale.reply.get("reason", "") == "bad_pin", "no PIN with an unknown token is bad_pin (%d)" % (i + 1))
	var fresh := await _raw_hello({"pin": "1234"})
	_check(fresh.reply.get("t", "") == "welcome",
			"after %d hellos with no PIN the right PIN still joins (no lock)" % (Protocol.PIN_TRIES + 2))
	_free_all()


func _pad() -> void:
	print("PIN pad")
	var pad: Control = PinPad.new()
	root.add_child(pad)
	await process_frame
	var got: Array = []
	var cancelled := [false]
	pad.entered.connect(func(p): got.append(p))
	pad.cancelled.connect(func(): cancelled[0] = true)
	for k in ["4", "2", "<", "1", "0"]:
		pad._key(k)
	_check(got.is_empty() and pad.digits == "410", "the digits are typed and one is deleted, and the pad waits: " + pad.digits)
	var pad2: Control = PinPad.new()
	root.add_child(pad2)
	await process_frame
	var got2: Array = []
	pad2.entered.connect(func(p): got2.append(p))
	for k in ["0", "4", "2", "7", "9"]:
		pad2._key(k)
	_check(got2 == ["0427"], "the fourth digit sends the PIN once: " + str(got2))
	pad._key("X")
	_check(cancelled[0], "the X key cancels")
	_check(pad.find_children("*", "GridContainer", true, false)[0].layout_direction == Control.LAYOUT_DIRECTION_LTR,
			"the keypad keeps its digit order in every language")
	pad.queue_free()
	pad2.queue_free()


func _about() -> void:
	print("About pages")
	var pages := About.pages(false)
	var titles := pages.map(func(p): return p.title)
	_check(titles == ["Sababi", "Godot Engine", "about.third_party_libraries"], "the About list: Sababi, Godot, 3rd Party Libraries")
	_check(not ("QR scanner" in titles) and "QR scanner" in About.pages(true).map(func(p): return p.title),
			"the scanner note is only for the Android phone")
	var by := {}
	for p in pages:
		by[p.title] = p
	_check(About.text(by["Godot Engine"]).contains("Permission is hereby granted"), "the Godot page has the MIT license text")
	var libs := About.libraries()
	var has_android := func(list: Array): return list.any(func(l): return l.title == "Android libraries")
	_check(not has_android.call(libs) and has_android.call(About.libraries(true)),
			"the Android libraries page is only in the Android apps")
	var android_page: Dictionary = About.libraries(true).filter(func(l): return l.title == "Android libraries").front()
	var android_text := About.text(android_page)
	_check(android_page.license == "Apache-2.0" and android_text.contains("Apache License") and android_text.contains("Version 2.0")
			and android_text.contains("play-services-code-scanner") and android_text.contains("Kotlin standard library"),
			"the Android libraries page has the list and the Apache 2.0 text")
	var lib := {}
	for l in libs:
		lib[l.title] = l
	_check(lib.has("Press Start 2P") and lib.has("Sababi Pixel Hebrew") and lib["Press Start 2P"].license == "OFL-1.1",
			"the libraries list has both fonts with their license type")
	var press := About.text(lib["Press Start 2P"])
	_check(press.contains("SIL OPEN FONT LICENSE") and press.contains("cody@zone38.net"),
			"the Press Start 2P page has its copyright and the OFL text")
	_check(About.text(lib["Sababi Pixel Hebrew"]).contains("SIL OPEN FONT LICENSE"), "the Sababi Pixel Hebrew page has the OFL text")
	var ft: Dictionary = libs.filter(func(l): return String(l.title).contains("FreeType")).front()
	_check(ft.license == "FTL" and About.text(ft).contains("FreeType") and About.text(ft).contains("License: FTL"),
			"a part of Godot shows its name, its license type and its copyright lines")
	_check(libs.size() > 50 and not libs.any(func(l): return l.title == "Godot Engine"),
			"the list has the parts of Godot but not Godot itself, which has its own page")
	var bullet: Dictionary = libs.filter(func(l): return String(l.title).begins_with("Bullet")).front()
	_check(bullet.license == "MIT, Zlib" and About.text(bullet).contains("== Zlib =="),
			"a part with two licenses lists both, and Expat is written as MIT: %s" % bullet.license)
	_check(libs.all(func(l): return About.text(l).strip_edges() != "" and String(l.license) != ""),
			"every library has a license type and a text")
	_check(About.license_label(["Expat", "Zlib"]) == "MIT, Zlib", "Expat is the MIT license")
	_check(About.safe("© Café") == "(c) Caf?", "characters outside ASCII are made safe for the pixel font")


func _about_screen() -> void:
	print("About screen")
	var screen: Control = _about_script.new()
	screen.theme = root.get_node("App").theme_res
	root.add_child(screen)
	await process_frame
	await process_frame
	_check(About.pages(false).size() > 0 and screen.chunks("a\nb").size() == 1, "a short text is one part")
	var long_text := "\n".join(range(100).map(func(n): return str(n)))
	_check(screen.chunks(long_text).size() == 3 and "\n".join(screen.chunks(long_text)) == long_text,
			"a long text is split in parts of 40 lines and nothing is lost")
	var buttons: Array = screen.find_children("*", "Button", true, false)
	_check(buttons.size() == About.pages(false).size() + 1 and screen.open_page == -1 and not screen.in_libraries,
			"the list has a button for each page and Back")
	screen.show_page(1)
	await process_frame
	_check(screen.open_page == 1 and not screen.find_children("*", "Label", true, false).filter(
			func(l): return String(l.text).contains("Permission is hereby granted")).is_empty(), "a page shows its text")
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	screen._unhandled_input(down)
	await process_frame
	_check(screen._scroll.scroll_vertical > 0, "Down scrolls the text of a page")
	var up := InputEventAction.new()
	up.action = "ui_up"
	up.pressed = true
	screen._unhandled_input(up)
	await process_frame
	_check(screen._scroll.scroll_vertical == 0, "Up scrolls back")
	screen.on_back()
	await process_frame
	_check(screen.open_page == -1 and not screen.in_libraries, "Back from a page returns to the list")
	screen._show_libraries()
	await process_frame
	buttons = screen.find_children("*", "Button", true, false)
	_check(screen.in_libraries and buttons.size() == About.libraries().size() + 1,
			"3rd Party Libraries has a row for each library and Back")
	_check(buttons.any(func(b): return String(b.text).contains("FREETYPE") and String(b.text).contains("(FTL)")),
			"a row has the name of the library and the type of its license")
	var long_row: Button = buttons.filter(func(b): return String(b.text).begins_with("BULLET CONTINUOUS")).front()
	_check(long_row.get_minimum_size().y > 84.0 and long_row.get_minimum_size().x < 100.0,
			"a long library name wraps to more lines, and the row does not force the screen wider")
	screen.show_page(0)
	await process_frame
	_check(screen.open_page == 0 and screen.in_libraries, "a library row opens its page")
	screen.on_back()
	await process_frame
	_check(screen.in_libraries and screen.open_page == -1, "Back from a library page returns to the list of libraries")
	screen.on_back()
	await process_frame
	_check(not screen.in_libraries and screen.open_page == -1, "Back from the list of libraries returns to the About list")
	screen.queue_free()
	await _about_extra()
	await _about_stays_open()


## Marks a check that fails because of a real problem in the game that is not fixed yet: it is printed and not counted as a
## failure.
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL (known bug) (", issue, ") ", what)


## A fresh About screen that fills the window, with the layout done.
func _open_about(props := {}) -> Control:
	var screen: Control = _about_script.new()
	for k in props:
		screen.set(k, props[k])
	screen.theme = root.get_node("App").theme_res
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	await process_frame
	return screen


## More About steps of tests 21.8 to 21.10 (REQ-FL-85): every library row, the size of the text, the fourth Back, touch scrolling,
## the scanner note and the license text in Hebrew.
func _about_extra() -> void:
	print("About rows, Back, touch and Hebrew")
	var app: Node = root.get_node("App")
	var screen: Control = await _open_about()
	screen._show_libraries()
	await process_frame
	await process_frame
	var rows: Array = screen.find_children("*", "Button", true, false)
	rows.pop_back()   # The last button is Back.
	var libs := About.libraries()
	var bad: Array = []
	var outside: Array = []
	var edge := 60.0
	var window := screen.get_global_rect()
	for i in rows.size():
		var b: Button = rows[i]
		var shown := String(b.text)
		var font := b.get_theme_font("font")
		var size := b.get_theme_font_size("font_size")
		var box := b.get_theme_stylebox("normal")
		var room := b.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
		var needed := font.get_multiline_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, room, size).y \
				+ box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM)
		var r := b.get_global_rect()
		var name_ok := shown.to_upper().contains(About.safe(String(libs[i].title)).to_upper())
		var license_ok := shown.to_upper().contains("(%s)" % String(libs[i].license).to_upper())
		if not (name_ok and license_ok and b.autowrap_mode != TextServer.AUTOWRAP_OFF and b.size.y + 0.5 >= needed):
			bad.append(String(libs[i].title))
		if not (r.position.x >= window.position.x + edge - 0.5 and r.end.x <= window.end.x - edge + 0.5):
			outside.append(String(libs[i].title))
	_check(rows.size() == libs.size() and bad.is_empty(),
			"every library row shows its name and license, wraps, and is tall enough for its lines: %s" % str(bad.slice(0, 5)))
	_check(outside.is_empty(),
			"every library row is inside the 60 px edge of a 1080 px phone screen (%d rows are not; the title is %d px wide)"
			% [outside.size(), int(screen._box.get_minimum_size().x)])
	screen.queue_free()

	# The size of the text (REQ-FL-40: TV text is 32 px or more; phone text 24 px or more).
	var script_size: int = _about_script.TEXT_SIZE
	_check(script_size >= 24, "the text of an About page is 24 px or more (the phone minimum)")
	_check(script_size >= 32,
			"the About text is 32 px or more, so it reads from the sofa on the TV (it is %d)" % script_size)

	# The fourth Back: from the About list to the screen that opened it.
	app.go(_about_script, {"back_screen": app.ControllerSettings})
	await process_frame
	await process_frame
	var about_list: Control = app.current_screen()
	about_list._show_libraries()
	about_list.on_back()
	_check(about_list.in_libraries == false and about_list.open_page == -1 and app.current_screen() == about_list,
			"Back from the libraries list stays on About (it shows the About list)")
	about_list.on_back()
	await process_frame
	await process_frame
	_check(app.current_screen().get_script() == app.ControllerSettings,
			"Back from the About list goes to the screen before (Settings)")

	# A page scrolls with a finger drag on the phone.
	var page_screen: Control = await _open_about()
	page_screen._show_libraries()   # The longest library text: many licenses, more than one screen.
	var longest := 0
	for k in page_screen._libs.size():
		if About.text(page_screen._libs[k]).length() > About.text(page_screen._libs[longest]).length():
			longest = k
	page_screen.show_page(longest)
	await process_frame
	await process_frame
	var sc: ScrollContainer = page_screen._scroll
	_check(sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			and sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
			and sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page > 1000.0,
			"a long page can scroll up and down only, and its text is much taller than the window")
	# A finger drag is the engine's own ScrollContainer touch code, and a headless run has no touch screen to feed it: the check is
	# that the page is a vertical ScrollContainer that is not disabled, and that its end can be reached.
	# The end of a long text is reachable: the last part is a label of the page and the scroll goes to its end.
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await process_frame
	var labels: Array = page_screen.find_children("*", "Label", true, false)
	var last_text := String(page_screen.chunks(About.text(page_screen._libs[longest])).back())
	_check(not labels.is_empty() and String(labels.back().text) == last_text
			and sc.scroll_vertical >= int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page) - 1,
			"the scroll goes to the end, where the last part of the text is")
	page_screen.queue_free()

	# The Android scanner note names Google and the technical data (REQ-FL-85).
	var scanner_page: Dictionary = About.pages(true).filter(func(p): return p.kind == "scanner").front()
	var note := About.text(scanner_page)
	_check(note.contains("Google") and note.contains("technical data") and note.contains("stays on your phone"),
			"the scanner page says that Google receives technical data and that the picture stays on the phone")

	# Hebrew: the lists come from the table, and the license texts are the English originals.
	var english_godot := About.text(About.pages(false)[1])
	var english_font := About.text(About.libraries()[0])
	var english_summary := About.text(About.pages(false)[0])
	app.set_language("he", false)
	var hebrew_summary := About.text(About.pages(false)[0])
	var hebrew_godot := About.text(About.pages(false)[1])
	var hebrew_font := About.text(About.libraries()[0])
	var has_hebrew := func(t: String) -> bool:
		for i in t.length():
			if t.unicode_at(i) >= 0x0590 and t.unicode_at(i) <= 0x05FF:
				return true
		return false
	_check(hebrew_godot == english_godot and hebrew_font == english_font and not has_hebrew.call(hebrew_godot)
			and not has_hebrew.call(hebrew_font), "a license text is the same bytes in Hebrew and has no Hebrew letter")
	_check(hebrew_summary != english_summary and has_hebrew.call(hebrew_summary),
			"the first page is in Hebrew when the language is Hebrew")
	var he_screen: Control = await _open_about()
	var he_texts: Array = he_screen.find_children("*", "Button", true, false).map(func(b): return String(b.text))
	_check(he_texts[0] == "SABABI" and has_hebrew.call(he_texts[2]),
			"the About list in Hebrew has the Hebrew name for 3rd Party Libraries")
	he_screen.queue_free()
	app.set_language("en", false)


## A phase message of the TV does not close the About screen of the phone (it closes Settings only to show the pad in a round).
func _about_stays_open() -> void:
	var app: Node = root.get_node("App")
	app.go(_about_script, {"back_screen": app.ControllerSettings})
	await process_frame
	app.client.state = ControllerClient.State.CONNECTED
	app.client.phase = "menu"
	app._show_phone_screen()
	await process_frame
	_check(app.current_screen().get_script() == _about_script, "a menu phase of the TV leaves the About screen open")
	app.client.phase = "playing"
	app._show_phone_screen()
	var on_pad: bool = app.current_screen().get_script() == _pad_script
	app.client.state = ControllerClient.State.IDLE   # Before the pad runs: there is no socket behind this state.
	await process_frame
	_check(on_pad, "a round still opens the pad")
	app.client.phase = "connect"
	await _missing_pin()


## A refusal for a missing PIN (the phone joined with a saved token that the TV does not know) opens the pad and shows no text.
func _missing_pin() -> void:
	var app: Node = root.get_node("App")
	app.go(_connect_script)
	await process_frame
	var screen: Control = app.current_screen()
	app.client.pin = ""
	app._on_client_rejected("bad_pin")
	_check(app.last_error == "", "a refusal for a missing PIN shows no error text")
	screen._on_rejected("bad_pin")
	_check(screen._pad != null, "a refusal for a missing PIN opens the pad")
	screen._close_pad()
	app.client.pin = "0000"
	screen._on_rejected("bad_pin")
	_check(screen._pad == null, "a refusal after a PIN was sent does not open the pad again")
	app.client.pin = ""
	app.last_error = ""
