extends SceneTree
## The join PIN (FD-23): a new phone must send the PIN that the TV shows, a phone that returns with its token needs none,
## a phone on the same device needs none, and the TV makes a new PIN after too many wrong ones. Also the PIN pad of the phone
## and the pages of the About screen. Real sockets on the local machine, like tests/net_profiles.gd.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/net_pin.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PinPad = preload("res://scripts/ui/pin_pad.gd")
const About = preload("res://scripts/core/about.gd")

var _checks := 0
var _fails := 0
var _server: TvServer


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
	for i in Protocol.PIN_TRIES:
		var guess := "0000" if _server.pin != "0000" else "1111"
		await _raw_hello({"pin": guess})
	_check(_server._bad_pins == 0 and Protocol.is_pin(_server.pin),
			"after %d wrong PINs the TV counts again with a valid PIN" % Protocol.PIN_TRIES)
	_server.pin = "1234"
	for i in Protocol.PIN_TRIES - 1:
		await _raw_hello({"pin": "0000"})
	var right := await _raw_hello({"pin": "1234"})
	_check(right.reply.get("t", "") == "welcome", "a right PIN after fewer wrong ones than the limit still joins")
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
	pad2._key("X")
	pad.cancelled.emit()
	_check(cancelled[0], "cancel is announced")
	pad.queue_free()
	pad2.queue_free()


func _about() -> void:
	print("About pages")
	var pages := About.pages(false)
	var titles := pages.map(func(p): return p.title)
	_check("Wobble" in titles and "Godot Engine" in titles and "Press Start 2P" in titles and "Wobble Pixel Hebrew" in titles,
			"the About list names Wobble, Godot and both fonts")
	_check(not ("QR scanner" in titles) and "QR scanner" in About.pages(true).map(func(p): return p.title),
			"the scanner note is only for the Android phone")
	var by := {}
	for p in pages:
		by[p.title] = p
	_check(About.text(by["Godot Engine"]).contains("Permission is hereby granted"), "the Godot page has the MIT license text")
	var press := About.text(by["Press Start 2P"])
	_check(press.contains("SIL OPEN FONT LICENSE") and press.contains("cody@zone38.net"),
			"the Press Start 2P page has its copyright and the OFL text")
	_check(About.text(by["Wobble Pixel Hebrew"]).contains("SIL OPEN FONT LICENSE"), "the Wobble Pixel Hebrew page has the OFL text")
	_check(About.text(by["Godot parts"]).contains("FreeType"), "the Godot parts page lists FreeType")
	var license_pages := pages.filter(func(p): return p.kind == "license")
	_check(license_pages.size() >= 5 and license_pages.all(func(p): return About.text(p) != ""),
			"every Godot license page has a text")
	_check(About.safe("© Café") == "(c) Caf?", "characters outside ASCII are made safe for the pixel font")


func _about_screen() -> void:
	print("About screen")
	var screen: Control = load("res://scripts/ui/about_screen.gd").new()
	screen.theme = root.get_node("App").theme_res
	root.add_child(screen)
	await process_frame
	await process_frame
	var buttons: Array = screen.find_children("*", "Button", true, false)
	_check(buttons.size() == About.pages(false).size() + 1 and screen.open_page == -1,
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
	_check(screen.open_page == -1, "Back from a page returns to the list")
	screen.queue_free()
