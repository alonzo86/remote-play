extends SceneTree
## Join approval, the PHONE screens (issue #393, docs/JOIN_APPROVAL_PLAN.md phase 2, docs/TV_FLOW.md REQ-FL-100 to 103): the real
## Connect screen and the real ControllerClient against a real TV server (waiting, CANCEL, Back, a refusal, a timeout, an allow,
## a TV
## that quits, a silent TV) and against a fake TV (the reasons `refused`, `timeout`, `busy` and `bye`, in English and Hebrew, with
## no retry). Also the strings of the phone (both languages, a `where`) and the layout at the phone width.
## Run by tests/run_all.sh: godot --headless --path . --script tests/join_approval_phone.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Lang = preload("res://scripts/core/lang.gd")

const PATH := "user://test_join_approval_phone.cfg"
const TV_IP := "192.168.0.1"   # A phone at 127.0.x.x builds the address 127.0.0.1 from this code (as tests/r4_join_code.gd).
const KEYS := ["connect.waiting_approval", "connect.waiting_approval_hint", "connect.approval_cancel", "connect.approval_refused",
		"connect.approval_timeout", "connect.approval_busy"]
const TEXTS := {
	"connect.waiting_approval": ["WAITING FOR THE HOST TO GET YOU IN.", "ממתינים שהמארח יאשר אתכם."],
	"connect.waiting_approval_hint": ["ASK THE HOST TO ALLOW YOU ON THE TV.", "בקשו מהמארח לאשר אתכם בטלוויזיה."],
	"connect.approval_cancel": ["CANCEL", "ביטול"],
	"connect.approval_refused": ["THE HOST DID NOT LET YOU IN.", "המארח לא הכניס אתכם."],
	"connect.approval_timeout": ["NO ANSWER FROM THE TV. TRY AGAIN.", "אין תשובה מהטלוויזיה. נסו שוב."],
	"connect.approval_busy": ["TOO MANY PLAYERS ARE WAITING. TRY AGAIN IN A MINUTE.", "יותר מדי שחקנים ממתינים. נסו שוב בעוד דקה."],
}

# One port for each process (as tests/net_limits.gd): two runs at the same time, or one after the other, do not meet on 47801.
var PORT := 47000 + OS.get_process_id() % 900
var FAKE_PORT := 48000 + OS.get_process_id() % 900   # The ranges do not meet.
var _checks := 0
var _fails := 0
var _app: Node
var _real_store
var _server: TvServer
var _fake: FakeTv


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A TV that speaks the protocol by script: after the `hello` it sends the frames of `script` and then nothing.
class FakeTv extends RefCounted:
	var tcp := TCPServer.new()
	var peers: Array[WebSocketPeer] = []
	var hellos := 0
	var frames: Array = []

	var listening := false

	func _init(port: int, bind := "127.0.0.1") -> void:
		listening = tcp.listen(port, bind) == OK

	func poll() -> void:
		while tcp.is_connection_available():
			var ws := WebSocketPeer.new()
			ws.accept_stream(tcp.take_connection())
			peers.append(ws)
		for ws in peers:
			ws.poll()
			while ws.get_ready_state() == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count() > 0:
				var msg: Dictionary = Protocol.parse_json(ws.get_packet().get_string_from_utf8())
				if msg.get("t", "") == "hello":
					hellos += 1
					for m in frames:
						ws.send_text(Protocol.to_json(m))

	func stop() -> void:
		for ws in peers:
			ws.close()
		tcp.stop()


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


func _until(cond: Callable, max_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if _fake != null:
			_fake.poll()
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _spin(ms: int) -> void:
	await _until(func() -> bool: return false, ms)


func _clean_files() -> void:
	for f in [PATH, PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


func _new_tv() -> void:
	_server = TvServer.new()
	_server.address_lookup = func() -> String: return TV_IP
	_server.approve_new = true
	_server.approval_gap_ms = 50
	root.add_child(_server)
	_server.port = PORT
	var err := _server.start({})
	if err != OK:
		_check(false, "the TV listens on port %d (error %d)" % [PORT, err])
		print("%d checks, %d failed (stopped: the port is taken)" % [_checks, _fails])
		quit(1)   # One clear line, not a list of failures that follow from it.
		await _frames(1000000)
	_server.set_phase("menu")
	_app.server = _server


func _stop_tv() -> void:
	if _app.client.state != ControllerClient.State.IDLE:
		_app.client.leave()
	_server.stop()
	_server.free()
	_app.server = null
	await _frames(8)


func _connect_screen() -> Control:
	_app.last_error = ""
	_app.go(_app.ControllerConnect)
	await _frames(3)
	var screen: Control = _app.current_screen()
	screen.local_ips_lookup = func() -> Array[String]: return ["127.0.0.9"] as Array[String]
	screen.port = PORT
	return screen


## Types the code of the real TV and taps JOIN.
func _join(screen: Control) -> void:
	screen._code.text = _server.room_code
	screen.join_typed()


func _waiting() -> bool:
	return await _until(func() -> bool: return _app.client.state == ControllerClient.State.WAITING, 3000)


func _status_is(screen: Control, key: String) -> bool:
	return screen._status.text == Lang.t(key).to_upper() \
			and screen._status.get_theme_color("font_color") == UiTheme.BAD


func _run() -> void:
	await _frames(3)
	_app = root.get_node("App")
	_real_store = _app.profiles
	_app.set_language("en", false)
	_clean_files()
	_app.profiles = ProfileStore.new(PATH)
	_app.profiles.create("Maya", 5)
	_app.apply_profile()
	_strings()
	await _waiting_screen()
	await _real_tv_flows()
	await _fake_tv_flows()
	await _wait_lost_no_other_address()
	await _layout()
	if _app.client.state != ControllerClient.State.IDLE:
		_app.client.leave()
	_app.profiles = _real_store
	_app.apply_profile()
	_app.set_language("en", false)
	_app.last_error = ""
	_clean_files()


## Every new key exists with both languages and a `where`; the texts are those of docs/TV_FLOW.md (REQ-FL-100, REQ-FL-101).
func _strings() -> void:
	print("the strings")
	var rows := Lang.parse_csv(FileAccess.get_file_as_string(Lang.TABLE_FILE))
	for key in KEYS:
		var row: Array = []
		for r in rows:
			if r.size() > 0 and r[0] == key:
				row = r
		_check(row.size() >= 4 and String(row[1]) == TEXTS[key][0] and String(row[2]) == TEXTS[key][1]
				and String(row[3]).strip_edges() != "",
				"%s has English, Hebrew and a where, with the text of the table" % key)
		_check(Lang.has(key), "%s is a key of the app" % key)


func _waiting_screen() -> void:
	print("the waiting screen (REQ-FL-100)")
	_new_tv()
	var screen := await _connect_screen()
	_join(screen)
	_check(await _waiting(), "the TV answers `pending`: the client is WAITING")
	await _frames(2)
	_check(_app.current_screen() == screen, "the phone stays on the Connect screen (no new screen)")
	_check(screen._wait_view.visible and not screen._main.visible, "the waiting view shows and the normal Connect view is hidden")
	_check(not screen._code.is_visible_in_tree() and not screen.find_child("JoinButton", true, false).is_visible_in_tree(),
			"no code field and no JOIN while it waits")
	_check(screen._typed_room == "" and screen._candidates.is_empty(), "a typed code does not try another address any more")
	_check(screen.find_child("WaitTitle", true, false).text == "connect.waiting_approval"
			and screen.find_child("WaitHint", true, false).text == "connect.waiting_approval_hint",
			"the title and the hint line are the keys of the table")
	var cancel: Button = screen.find_child("CancelButton", true, false)
	_check(cancel.is_visible_in_tree() and cancel.text == "connect.approval_cancel" and cancel.size.y >= 96
			and cancel.focus_mode == Control.FOCUS_NONE, "CANCEL is a box button of 96 px or more, with no focus")
	_check(screen._wait_name.text == "MAYA" and screen._wait_avatar.index == 5, "the chip shows the player: name and avatar")
	_check(_server.request_count() == 1 and _server.players_in().size() == 0, "the TV has 1 request and the phone has no slot")
	var accepts: int = _server._accepts.get("127.0.0.1", []).size()
	await _spin(2500)
	_check(_app.client.state == ControllerClient.State.WAITING and _server._accepts.get("127.0.0.1", []).size() == accepts,
			"it stays in WAITING through the keepalives and sends no second hello")
	# CANCEL.
	var got: Array[String] = []
	var on_rej := func(r: String) -> void: got.append(r)
	_app.client.rejected.connect(on_rej)
	cancel.pressed.emit()
	await _until(func() -> bool: return _server.request_count() == 0, 3000)
	await _frames(2)
	_check(_app.client.state == ControllerClient.State.IDLE and _server.request_count() == 0,
			"CANCEL: IDLE, and the TV dropped the request")
	_check(got.is_empty() and screen._status.text == "" and _app.last_error == "", "CANCEL shows no message")
	_check(screen._main.visible and not screen._wait_view.visible and _app.current_screen() == screen,
			"the Connect screen shows again")
	await _spin(1500)
	_check(_app.client.state == ControllerClient.State.IDLE and _server.request_count() == 0, "no retry after CANCEL")
	# Back.
	_join(screen)
	_check(await _waiting(), "joins again with a tap on JOIN")
	_app.current_screen().on_back()
	await _until(func() -> bool: return _server.request_count() == 0, 3000)
	_check(_app.client.state == ControllerClient.State.IDLE and not is_instance_valid(screen._quit_dialog) and got.is_empty()
			and screen._status.text == "", "Back does what CANCEL does: no quit dialog, no message")
	screen.on_back()
	_check(is_instance_valid(screen._quit_dialog), "Back outside the wait still asks to quit")
	screen.on_back()
	_app.client.rejected.disconnect(on_rej)
	await _stop_tv()


func _real_tv_flows() -> void:
	print("the answers of a real TV")
	# The host refuses.
	_new_tv()
	var screen := await _connect_screen()
	_join(screen)
	await _waiting()
	await _until(func() -> bool: return not _server.shown_request().is_empty(), 3000)
	_server.refuse_request(int(_server.shown_request().id))
	await _until(func() -> bool: return _app.client.state == ControllerClient.State.IDLE, 3000)
	await _frames(2)
	_check(_status_is(screen, "connect.approval_refused") and screen._main.visible, "refused: the status line, in BAD")
	await _spin(1500)
	_check(_app.client.state == ControllerClient.State.IDLE and _server.request_count() == 0,
			"refused: no retry, it stays on Connect")
	# No answer.
	_server.approval_timeout_ms = 400
	_join(screen)
	await _until(func() -> bool: return _app.last_error == Lang.t("connect.approval_timeout"), 4000)
	await _frames(2)
	_check(_status_is(screen, "connect.approval_timeout"), "timeout: the status line, in BAD")
	# Allowed.
	_server.approval_timeout_ms = 60000
	_join(screen)
	await _waiting()
	await _until(func() -> bool: return not _server.shown_request().is_empty(), 3000)
	_server.allow_request(int(_server.shown_request().id))
	await _until(func() -> bool: return _app.client.state == ControllerClient.State.CONNECTED, 3000)
	_check(_app.client.state == ControllerClient.State.CONNECTED and _server.players_in().size() == 1,
			"allowed: the phone joins with a slot")
	_app.client.leave()
	await _frames(3)
	await _stop_tv()
	# The TV app quits while the phone waits: `bye`.
	_new_tv()
	screen = await _connect_screen()
	_join(screen)
	await _waiting()
	_server.stop()
	await _until(func() -> bool: return _app.client.state == ControllerClient.State.IDLE, 3000)
	await _frames(2)
	_check(_status_is(screen, "app.tv_closed_connection"), "the TV quits: the text for a TV that closes the connection (REQ-FL-103)")
	_server.free()
	_app.server = null
	await _frames(5)
	# The TV goes silent: no frame for 5 s.
	_new_tv()
	screen = await _connect_screen()
	_join(screen)
	await _waiting()
	var accepts: int = _server._accepts.get("127.0.0.1", []).size()
	_server.set_process(false)
	var t0 := Time.get_ticks_msec()
	await _until(func() -> bool: return _app.client.state == ControllerClient.State.IDLE, 8000)
	var dt := Time.get_ticks_msec() - t0
	await _frames(2)
	_check(_status_is(screen, "connect.room_not_found") and dt >= 2500, "a lost link: ROOM NOT FOUND after %d ms (REQ-FL-103)" % dt)
	await _spin(1500)
	_server.set_process(true)
	_check(_server._accepts.get("127.0.0.1", []).size() == accepts and _app.client.state == ControllerClient.State.IDLE,
			"a lost link: no retry, no other address")
	await _stop_tv()


func _fake_tv_flows() -> void:
	print("a fake TV: the reasons, in both languages")
	_fake = FakeTv.new(FAKE_PORT)
	_check(_fake.listening, "the fake TV listens on port %d" % FAKE_PORT)
	if not _fake.listening:
		quit(1)
		await _frames(1000000)
	var cases := [["refused", "connect.approval_refused"], ["timeout", "connect.approval_timeout"],
			["busy", "connect.approval_busy"]]
	for code in ["en", "he"]:
		_app.set_language(code, false)
		for c in cases:
			var screen := await _connect_screen()
			_fake.frames = [{"t": "pending"}, {"t": "kicked", "reason": c[0]}]
			var hellos := _fake.hellos
			_app.client.connect_to("127.0.0.1", FAKE_PORT, "ABCD")
			await _until(func() -> bool: return _app.last_error != "", 3000)
			await _frames(2)
			_check(_status_is(screen, c[1]) and _app.last_error == Lang.t(c[1]), "[%s] %s: the text of its key, in BAD" % [code, c[0]])
			_check(_app.current_screen() == screen and screen._main.visible and not screen._wait_view.visible
					and _app.client.state == ControllerClient.State.IDLE, "[%s] %s: back on the Connect screen" % [code, c[0]])
			await _spin(1500)
			_check(_fake.hellos == hellos + 1 and _app.client.state == ControllerClient.State.IDLE,
					"[%s] %s: no retry (1 hello)" % [code, c[0]])
			_check(_app.client.load_last().get("token", "") == "", "[%s] %s: no token is kept" % [code, c[0]])
	_app.set_language("en", false)
	# A TV that quits sends bye.
	var screen := await _connect_screen()
	_fake.frames = [{"t": "pending"}, {"t": "bye"}]
	_app.client.connect_to("127.0.0.1", FAKE_PORT, "ABCD")
	await _until(func() -> bool: return _app.last_error != "", 3000)
	await _frames(2)
	_check(_status_is(screen, "app.tv_closed_connection"), "bye: the text of a TV that closes the connection")
	# `pending`, then the player leaves with CANCEL: the TV gets `bye` (the phone says it).
	_fake.frames = [{"t": "pending"}]
	_app.last_error = ""
	_app.client.connect_to("127.0.0.1", FAKE_PORT, "ABCD")
	await _until(func() -> bool: return _app.client.state == ControllerClient.State.WAITING, 3000)
	_check(screen._wait_view.visible, "a TV with a script: the waiting view shows")
	screen.cancel_wait()
	await _frames(3)
	_check(_app.client.state == ControllerClient.State.IDLE and screen._status.text == "" and screen._main.visible,
			"CANCEL: back to Connect with an empty status line")
	_fake.stop()
	_fake = null


## A typed code with two addresses of the phone: the first answers `pending`, then the link is lost (a closed socket, and the
## silence of 5 s): the phone does not try the second address (FD-30.13, REQ-FL-103); it shows ROOM NOT FOUND and stops.
func _wait_lost_no_other_address() -> void:
	print("a lost link while waiting tries no other address (REQ-FL-103)")
	for how in ["closed", "silent"]:
		_fake = FakeTv.new(FAKE_PORT)
		var second := FakeTv.new(FAKE_PORT, "127.1.0.1")
		_check(_fake.listening and second.listening, "[%s] two fake TVs listen, on 127.0.0.1 and 127.1.0.1" % how)
		_fake.frames = [{"t": "pending"}]
		var screen := await _connect_screen()
		screen.local_ips_lookup = func() -> Array[String]: return ["127.0.0.9", "127.1.0.9"] as Array[String]
		screen.port = FAKE_PORT
		screen._code.text = Protocol.room_code_for_ip(TV_IP)
		var t0 := Time.get_ticks_msec()
		screen.join_typed()
		_check(screen._candidates.size() == 1, "[%s] the join has a second address to try" % how)
		await _until(func() -> bool: return _app.client.state == ControllerClient.State.WAITING, 3000)
		_check(_app.client.state == ControllerClient.State.WAITING and screen._candidates.is_empty(),
				"[%s] `pending` from the first address: WAITING and no address left to try" % how)
		if how == "closed":
			for ws in _fake.peers:
				ws.close()
		else:
			pass   # The fake TV sends no keepalive after `pending`: 5 s of silence.
		await _until(func() -> bool: return _app.client.state == ControllerClient.State.IDLE, 9000)
		var dt := Time.get_ticks_msec() - t0
		await _frames(2)
		_check(_status_is(screen, "connect.room_not_found"), "[%s] the link is lost: ROOM NOT FOUND after %d ms" % [how, dt])
		await _spin(1500)
		_check(second.peers.is_empty() and not second.tcp.is_connection_available() and _fake.peers.size() == 1
				and _app.client.state == ControllerClient.State.IDLE,
				"[%s] the second address got no connection, the first got one, no retry" % how)
		second.stop()
		_fake.stop()
		_fake = null
		await _frames(3)


## The waiting view and the new status lines fit the phone width at the smallest text size, in both languages (REQ-FL-40).
func _layout() -> void:
	print("the layout")
	var shapes := [Vector2(1080, 1920), Vector2(1080, 2340), Vector2(1170, 2532), Vector2(1080, 2400)]
	for code in ["en", "he"]:
		_app.set_language(code, false)
		for viewport in shapes:
			var holder := Control.new()
			holder.size = viewport
			root.add_child(holder)
			var screen: Control = _app.ControllerConnect.new()
			screen.theme = _app.theme_res
			holder.add_child(screen)
			screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await _frames(3)
			var tag := "[%s] %dx%d" % [code, viewport.x, viewport.y]
			screen._show_waiting(true)
			await _frames(3)
			var area := Rect2(screen.get_global_rect().position, viewport)
			var ok := true
			var small := []
			for l: Label in screen._wait_view.find_children("*", "Label", true, false):
				if l.text == "":
					continue
				var size := l.get_theme_font_size("font_size")
				if size < 24:
					small.append(l.text)
				ok = ok and area.encloses(l.get_global_rect()) and _words_fit(l, size)
			_check(ok and small.is_empty(),
					"%s: the waiting texts are 24 px or more, inside the screen, no word cut %s" % [tag, str(small)])
			var cancel: Button = screen._wait_cancel
			_check(area.encloses(cancel.get_global_rect()) and cancel.size.y >= 96 and area.encloses(screen._wait_chip.get_global_rect()),
					"%s: CANCEL (96 px or more) and the chip are inside the screen" % tag)
			var mid_end: float = screen.find_child("WaitHint", true, false).get_global_rect().end.y
			_check(mid_end <= screen._wait_chip.get_global_rect().position.y, "%s: the texts do not touch the chip" % tag)
			screen._show_waiting(false)
			for key in ["connect.approval_refused", "connect.approval_timeout", "connect.approval_busy"]:
				screen._status.text = Lang.t(key).to_upper()
				await _frames(2)
				var st: Label = screen._status
				_check(area.encloses(st.get_global_rect()) and _words_fit(st, st.get_theme_font_size("font_size"))
						and st.get_theme_font_size("font_size") >= 24, "%s: %s fits the width at the status size" % [tag, key])
			holder.queue_free()
	_app.set_language("en", false)


## True when the longest word of the label is not wider than the label (an autowrap label cuts or overflows a longer word).
func _words_fit(l: Label, size: int) -> bool:
	var font: Font = l.get_theme_font("font")
	for w in l.tr(l.text).split(" ", false):
		if font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > l.size.x + 0.5:
			return false
	return true
