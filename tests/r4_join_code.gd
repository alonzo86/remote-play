extends SceneTree
## Join by room code (issue #52, docs/TV_FLOW.md REQ-FL-4, REQ-FL-83, docs/MANUAL_TESTS.md tests 1 and 21), with the real
## Connect screen and a real TV server on the real port: the rules of the TV (its code follows its address, a wrong room is
## `bad_room`, no PIN), typing 4 letters does not join, JOIN joins (also in lower case and with spaces), a wrong text shows its
## error, a code that no address answers says that the room is not found, the QR link joins, and the screen has no list of
## rooms, no Refresh and no PIN pad. Also the pencil next to the player (9f).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/r4_join_code.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")
const PencilIcon = preload("res://scripts/ui/pencil_icon.gd")
const Lang = preload("res://scripts/core/lang.gd")

const PATH := "user://test_r4_join_code.cfg"
const TV_IP := "192.168.0.1"   # The last two numbers are 0 and 1: a phone at 127.0.x.x builds the address 127.0.0.1, this device.

var _checks := 0
var _fails := 0
var _app: Node
var _real_store
var _server: TvServer


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


func _clean_files() -> void:
	for f in [PATH, PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


## A TV on the real port with the address TV_IP.
func _new_tv() -> void:
	_server = TvServer.new()
	_server.address_lookup = func() -> String: return TV_IP
	root.add_child(_server)
	_server.start({})
	_server.set_phase("connect")
	_app.server = _server


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


func _connect_screen(own: Array[String]) -> Control:
	_app.go(_app.ControllerConnect)
	await _frames(3)
	var screen: Control = _app.current_screen()
	screen.local_ips_lookup = func() -> Array[String]: return own
	return screen


func _type(screen: Control, text: String) -> void:
	screen._code.text = text
	screen._code.text_changed.emit(text)
	screen.join_typed()


func _run() -> void:
	await _frames(3)
	_app = root.get_node("App")
	_real_store = _app.profiles
	_app.set_language("en", false)
	_clean_files()
	_app.profiles = ProfileStore.new(PATH)
	_app.apply_profile()
	_new_tv()
	await _tv_rules()
	await _screen_layout()
	await _typing_does_not_join()
	await _typed_code()
	await _errors()
	await _unreachable()
	await _qr_link()
	await _edit_screen()
	if _app.client.state != ControllerClient.State.IDLE:
		_app.client.leave()
	_server.stop()
	_app.server = null
	_app.profiles = _real_store
	_app.apply_profile()
	_app.set_language("en", false)
	_clean_files()


## What the TV does with a hello: its code is the code of its address, only that room joins, and no PIN is asked.
func _tv_rules() -> void:
	print("the TV")
	_check(_server.ip == TV_IP and _server.room_code == Protocol.room_code_for_ip(TV_IP),
			"the room code is the code of the TV address (%s)" % _server.room_code)
	var good := await _raw_hello({})
	_check(good.reply.get("t", "") == "welcome", "a hello with the room code of the TV joins, with no PIN")
	var token := String(good.reply.get("token", ""))
	_free_all()
	var lower := await _raw_hello({"room": _server.room_code.to_lower()})
	_check(lower.reply.get("t", "") == "welcome", "the room is compared in upper case")
	_free_all()
	var other := await _raw_hello({"room": "AAAA"})
	_check(other.reply.get("t", "") == "reject" and other.reply.get("reason", "") == "bad_room" and other.reply.size() == 2,
			"another room code is bad_room, and the answer says nothing else about the TV")
	_check(_server.player_count() == 0, "and nobody joined")
	var none := await _raw_hello({"room": ""})
	_check(none.reply.get("t", "") == "welcome", "a hello with no room joins (a run on a desktop: --join=127.0.0.1)")
	_free_all()
	var unknown := await _raw_hello({"token": token})
	_check(unknown.reply.get("t", "") == "welcome", "a token that the TV does not know joins as a new phone (no PIN to ask)")
	_free_all()
	var old := await _raw_hello({"v": 3})
	_check(old.reply.get("reason", "") == "version", "a phone of version 3 is turned away as version")
	_server.address_lookup = func() -> String: return "10.1.2.3"
	_server._address_timer = 0.0
	await _frames(3)
	_check(_server.ip == "10.1.2.3" and _server.room_code == Protocol.room_code_for_ip("10.1.2.3") and _server.room_code != "",
			"a new address of the TV gives a new room code: " + _server.room_code)
	var stale := await _raw_hello({"room": Protocol.room_code_for_ip(TV_IP)})
	_check(stale.reply.get("reason", "") == "bad_room", "the old code is turned away")
	_server.address_lookup = func() -> String: return ""
	_server._address_timer = 0.0
	await _frames(3)
	_check(_server.ip == "" and _server.room_code == "", "a TV with no address has no room code")
	_server.address_lookup = func() -> String: return TV_IP
	_server._address_timer = 0.0
	await _frames(3)
	_check(_server.room_code == Protocol.room_code_for_ip(TV_IP), "and it shows the code again when the address is back")


## The Connect screen has the code field, JOIN and the scan button, and no list, no Refresh and no PIN pad.
func _screen_layout() -> void:
	print("the Connect screen")
	var screen := await _connect_screen(["127.0.0.9"])
	var buttons: Array = screen.find_children("*", "Button", true, false).map(func(b): return b.text)
	var labels: Array = screen.find_children("*", "Label", true, false).map(func(l): return l.text)
	_check(screen._code != null and screen._code.is_visible_in_tree(), "the code field shows")
	var join: Button = screen.find_child("JoinButton", true, false)
	var icon_script: Script = load("res://scripts/ui/enter_icon.gd")
	var has_icon: bool = join != null and join.find_children("*", "Control", true, false).any(
			func(n): return n.get_script() == icon_script)
	_check(join != null and join.is_visible_in_tree() and join.text == "" and join.accessibility_name == Lang.t("connect.join")
			and join.tooltip_text == Lang.t("connect.join") and join.focus_mode == Control.FOCUS_NONE and has_icon,
			"JOIN is an icon button (the enter arrow, no text) with its name for a screen reader, no focus on a phone")
	var plain: Array = icon_script.cells(false)
	var mirror: Array = icon_script.cells(true)
	var tail_x := func(cells: Array) -> int:   # The column of the long stroke (the tail of the arrow), at its row.
		return cells.filter(func(c): return c.y == 4).map(func(c): return int(c.x)).min()
	_check(plain.size() == mirror.size() and mirror.all(func(m): return plain.any(func(p): return p.y == m.y and p.x == 11 - m.x))
			and tail_x.call(plain) == 0 and tail_x.call(mirror) == 11 - 9,
			"in Hebrew (right to left) the enter arrow is mirrored left to right (REQ-FL-83)")
	_check(not ("qr_scanner.paste_room_link" in buttons), "there is no paste button: %s" % str(buttons))
	_check("connect.type_code" in labels, "the field has its label")
	for gone in ["connect.refresh", "connect.rooms_found", "connect.searching", "connect.no_rooms_found",
			"connect.looking_for_rooms"]:
		_check(not (gone in buttons) and not (gone in labels), "no %s" % gone)
	_check(screen._status.text == "", "the status line is empty when nothing happens")
	_check(not buttons.has("connect.scan_qr_code"),
			"a phone with no scanner plugin has no scan button, the code field is its way (REQ-FL-58)")
	for k in ["pin_pad", "_pad", "_prober"]:
		_check(not (k in screen) or screen.get(k) == null, "the screen has no %s" % k)


## Typing never joins (owner, 2026-11-03; the 4th letter joined by itself until then): 4 letters of a real room wait for JOIN,
## JOIN joins, a second JOIN while the first try runs makes no second player, a text that is no code shows the error on JOIN.
func _typing_does_not_join() -> void:
	print("typing does not join")
	var screen := await _connect_screen(["127.0.9.9"])
	var shown: String = _server.room_code
	screen._code.text = shown.to_lower()
	screen._code.text_changed.emit(screen._code.text)
	await _frames(2)
	_check(screen._code.text == shown, "the field shows capitals")
	await _wait_until(func(): return _app.client.state != ControllerClient.State.IDLE, 1000)
	_check(_app.client.state == ControllerClient.State.IDLE and _server.player_count() == 0 and _app.last_error == "",
			"the 4 letters of a real room do not join by themselves")
	screen.join_typed()
	screen.join_typed()   # A second tap while the first try runs.
	_check(await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED, 4000), "JOIN joins")
	_check(_server.player_count() == 1, "and a second JOIN made no second player (%d)" % _server.player_count())
	_app.client.leave()
	await _wait_until(func(): return _server.player_count() == 0, 3000)
	await _frames(3)
	var bad := await _connect_screen(["127.0.9.9"])
	bad._code.text = "ZZZZ"
	bad._code.text_changed.emit("ZZZZ")
	_check(_app.last_error == "", "4 letters that are no code show no error while typing")
	bad.join_typed()
	_check(_app.last_error == Lang.t("connect.bad_code") and _app.client.state == ControllerClient.State.IDLE,
			"JOIN on a text that is no code says so")
	_app.last_error = ""


## A typed code joins. Lower case and spaces are fine.
func _typed_code() -> void:
	print("a typed code")
	var screen := await _connect_screen(["127.0.9.9"])
	var shown: String = _server.room_code
	screen._code.text = shown.to_lower()
	screen._code.text_changed.emit(screen._code.text)
	_check(screen._code.text == shown, "the field shows capital letters")
	_type(screen, " %s %s " % [shown.substr(0, 2).to_lower(), shown.substr(2)])
	_check(await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED, 4000),
			"a code in lower case with spaces joins")
	_check(_app.client.host == "127.0.0.1" and _app.client.room == shown and _server.player_count() == 1,
			"the phone built the address 127.0.0.1 from its own 127.0 and the code, and holds a slot")
	_check(_app.current_screen().get_script() == _app.ControllerWait, "the phone shows the waiting screen")
	_app.client.leave()
	await _wait_until(func(): return _server.player_count() == 0, 3000)
	await _frames(3)
	# Enter on the keyboard joins like the button (REQ-FL-83).
	var enter := await _connect_screen(["127.0.9.9"])
	enter._code.text = shown
	enter._code.text_submitted.emit(shown)
	_check(await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED, 4000),
			"Enter in the code field joins")
	_app.client.leave()
	await _wait_until(func(): return _server.player_count() == 0, 3000)
	await _frames(3)
	# Another TV answers bad_room at the first address: the next address of the phone is tried (the right TV is there).
	var two := await _connect_screen(["127.0.9.9"])
	two._typed_room = shown
	two._candidates = ["127.0.0.1"] as Array[String]
	_app.last_error = Lang.t("app.wrong_room_code")
	two._on_rejected("bad_room")
	_check(_app.last_error == "", "bad_room with an address left clears the error and tries again")
	_check(await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED, 4000),
			"the second address holds the right TV and the phone joins")
	_app.client.leave()
	await _wait_until(func(): return _server.player_count() == 0, 3000)
	await _frames(3)
	# bad_room at the last address stays WRONG ROOM CODE.
	var last := await _connect_screen(["127.0.9.9"])
	last._typed_room = shown
	last._candidates.clear()
	_app.last_error = Lang.t("app.wrong_room_code")
	last._on_rejected("bad_room")
	_check(_app.last_error == Lang.t("app.wrong_room_code") and last._typed_room == "",
			"bad_room at the last address shows WRONG ROOM CODE")
	_app.last_error = ""
	# The desktop argument --join= (a development run with no room code).
	_check(_app._join_arg(PackedStringArray(["--role=controller", "--join=127.0.0.1"])) == "127.0.0.1"
			and _app._join_arg(PackedStringArray(["--role=controller"])) == "", "--join= gives the TV address, none gives empty")


## A text that is not a code and a code that nobody answers show their texts.
func _errors() -> void:
	print("a wrong text")
	var screen := await _connect_screen(["127.0.9.9"])
	for bad in ["", "AB", "ABCDE", "DRE1", "ZZZZ"]:
		_type(screen, bad)
		await _frames(2)
		_check(_app.last_error == Lang.t("connect.bad_code") and screen._status.text == Lang.t("connect.bad_code").to_upper()
				and _app.client.state == ControllerClient.State.IDLE, "'%s' says that it is not a room code" % bad)
	_app.last_error = ""
	var no_wifi := await _connect_screen([] as Array[String])
	_type(no_wifi, _server.room_code)
	await _frames(2)
	_check(_app.last_error == Lang.t("connect.room_not_found") and _app.client.state == ControllerClient.State.IDLE,
			"a phone with no Wi-Fi address says that the room is not found")
	_app.last_error = ""
	_app._on_client_rejected("bad_room")
	_check(_app.last_error == Lang.t("app.wrong_room_code"), "bad_room says WRONG ROOM CODE")
	_check(Lang.t("pin.wrong") == "pin.wrong" and Lang.t("pin.locked") == "pin.locked", "the PIN texts are gone from the strings")
	_app._on_client_rejected("bad_pin")
	_check(_app.last_error == Lang.f("connect.refused", ["bad_pin"]), "bad_pin is no known reason any more")
	_app.last_error = ""


## No address answers: a fast failure, each address of the phone is tried, then the room is not found.
func _unreachable() -> void:
	print("a code that nobody answers")
	_server.stop()
	var screen := await _connect_screen(["127.0.9.9", "127.5.9.9"])
	var hosts := {}
	var t0 := Time.get_ticks_msec()
	_type(screen, Protocol.room_code_for_ip("192.168.0.1"))
	while Time.get_ticks_msec() - t0 < 9000 and _app.last_error == "":
		hosts[_app.client.host] = true
		await process_frame
	await _frames(3)
	_check(_app.last_error == Lang.t("connect.room_not_found"), "the text is '%s'" % _app.last_error)
	_check(hosts.has("127.0.0.1") and hosts.has("127.5.0.1"), "both addresses of the phone were tried: %s" % str(hosts.keys()))
	var took := Time.get_ticks_msec() - t0
	_check(took < 8000, "and it took %d ms (a short timeout, one try for each address)" % took)
	_check(_app.client.state == ControllerClient.State.IDLE and screen._status.text == Lang.t("connect.room_not_found").to_upper(),
			"the Connect screen shows the text and the phone is idle")
	_check(_app.client.give_up_after == ControllerClient.QUICK_GIVE_UP_AFTER, "a typed code gives up after one try")
	_app.last_error = ""
	_new_tv()


## The QR link: the address is in it and there is no PIN.
func _qr_link() -> void:
	print("the QR link")
	var screen := await _connect_screen(["10.0.0.5"])
	screen._on_qr_text("ws://127.0.0.1:%d/%s" % [Protocol.WS_PORT, _server.room_code])
	_check(await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED, 4000),
			"a link without a PIN joins")
	_check(_app.client.give_up_after == ControllerClient.GIVE_UP_AFTER, "a join by the link keeps the normal tries")
	_app.client.leave()
	await _wait_until(func(): return _server.player_count() == 0, 3000)
	var screen2 := await _connect_screen(["10.0.0.5"])
	screen2._on_qr_text("ws://127.0.0.1:%d/%s?pin=1234" % [Protocol.WS_PORT, _server.room_code])
	await _frames(2)
	_check(_app.client.state == ControllerClient.State.IDLE and _app.last_error == Lang.t("connect.not_sababi_code"),
			"a link with a PIN (the old version) is not a Sababi code")
	_app.last_error = ""


func _pencil(screen: Node) -> Button:
	for b in screen.find_children("*", "Button", true, false):
		if b.get_child_count() > 0 and b.get_child(0).get_script() == PencilIcon:
			return b
	return null


## 9f: the pencil next to the player opens the edit screen of the active profile: the name field and SAVE show.
func _edit_screen() -> void:
	print("the pencil")
	var maya = _app.profiles.create("Maya", 3)
	_app.apply_profile()
	var screen := await _connect_screen([] as Array[String])
	var pencil := _pencil(screen)
	_check(pencil != null, "9f: the Connect screen has the pencil next to the player")
	if pencil == null:
		return
	pencil.pressed.emit()
	await _frames(3)
	var edit: Control = _app.current_screen()
	_check(edit.get_script() == _app.ControllerProfileEdit and edit.profile_id == maya.id,
			"9f: the pencil opens the edit screen of the active profile")
	_check(edit._name.is_visible_in_tree() and edit._name.text == "Maya" and edit._save.is_visible_in_tree()
			and edit._save.text == "profile_edit.save", "9f: the name field (Maya) and SAVE show")
