extends SceneTree
## The whole join on the loopback, with the real phone screens and the real TV server: join, the waiting text and the slot color
## on both sides, a rejoin with the saved token, a Wi-Fi that goes away without a close (a relay cuts the link), a kick, a join
## during a round, the QR scan with a fake plugin (docs/MANUAL_TESTS.md tests 1, 2, 7 and 8b). A typed code: r4_join_code.gd.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/join_flow.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const TcpRelay = preload("res://tests/tcp_relay.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Lang = preload("res://scripts/core/lang.gd")

var _checks := 0
var _fails := 0
var _app: Node
var _server: TvServer
var _relay: Node
var _port := 0
var _relay_port := 0
var _wait_script: GDScript
var _connect_script: GDScript
var _pad_script: GDScript
var _slot_list_script: GDScript
var _tv_connect_script: GDScript
var _tv_games_script: GDScript


## A known bug: it counts as a failure until the bug is fixed.
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: remove _known_bug)")
	else:
		_fails += 1
		print("  FAIL (known bug) ", issue, ": ", what)


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


func _wait_until(cond: Callable, max_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _labels(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).map(func(l): return l.text)


func _buttons(n: Node) -> Array:
	return n.find_children("*", "Button", true, false).map(func(b): return b.text)


func _button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null


## A fresh TV on its own ports (a TV app may run on the standard port beside the test), and a relay in front of it.
func _new_tv(slot_grace_ms := 8000) -> void:
	if _server != null:
		_server.stop()
		_server.queue_free()
	if _relay != null:
		_relay.stop()
		_relay.queue_free()
	_port = 48100 + randi() % 400
	_relay_port = _port + 500
	_server = TvServer.new()
	_server.port = _port
	root.add_child(_server)
	_server.start({})
	_server.peer_timeout_ms = 1500
	_server.slot_grace_ms = slot_grace_ms
	_server.set_phase("connect")
	_relay = TcpRelay.new()
	root.add_child(_relay)
	_relay.start(_relay_port, _port)
	_app.server = _server   # The TV screens and the slot list read the server from the App.


func _join(via_relay := false) -> bool:
	_app.last_error = ""
	_app.client.connect_to("127.0.0.1", _relay_port if via_relay else _port, _server.room_code)
	return await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED, 4000)


func _leave_all() -> void:
	_app.client.leave()
	for p in _server.players:
		if p.is_present():
			_server.drop_player(p.slot)
	await _frames(3)


func _run() -> void:
	await _frames(3)   # The autoloads start in the first frames.
	_app = root.get_node("App")
	_wait_script = load("res://scripts/ui/controller_wait.gd")
	_connect_script = load("res://scripts/ui/controller_connect.gd")
	_pad_script = load("res://scripts/ui/controller_pad.gd")
	_slot_list_script = load("res://scripts/ui/slot_list.gd")
	_tv_connect_script = load("res://scripts/ui/tv_connect.gd")
	_tv_games_script = load("res://scripts/ui/tv_games.gd")
	_new_tv()
	await _join_and_wait_screen()
	await _tv_ok_to_games()
	await _four_slots()
	await _rejoin_saved_token()
	await _join_in_round()
	await _kick()
	await _wifi_cut()
	await _wifi_cut_paused()
	await _qr_scan()
	_app.server = null
	_server.stop()
	_relay.stop()


## 1.3b: after the join, the phone shows the waiting text and a square in the color of slot 1, and the TV says READY for slot 1.
func _join_and_wait_screen() -> void:
	print("join: the phone and the TV agree")
	_app.go(_connect_script)
	await process_frame
	var tv_slots: Control = _slot_list_script.new()
	tv_slots.theme = _app.theme_res
	root.add_child(tv_slots)
	await _frames(2)
	_check(_labels(tv_slots).count("slot_list.ready") == 0 and _labels(tv_slots).count("slot_list.wait") == 4,
			"before the join the TV shows 4 free slots (WAIT)")
	var ok := await _join()
	_check(ok, "the phone joins the TV")
	await _frames(3)
	var wait: Control = _app.current_screen()
	_check(wait.get_script() == _wait_script, "the phone shows the waiting screen after the join")
	_check(_app.client.slot == 0 and _app.client.color == Protocol.PLAYER_COLORS[0]
			and _server.players[0].color == Protocol.PLAYER_COLORS[0],
			"the phone and the TV both have slot 1 in the color of player 1 (%s)" % _app.client.color.to_html(false))
	_check(wait._name.text == "1P", "the waiting screen shows 1P")
	_check(wait._title.text == Lang.t("wait.waiting_host").to_upper(),
			"the phone says WAITING FOR THE HOST while the TV is on Connect: '%s'" % wait._title.text)
	await _frames(3)
	var states := tv_slots.find_children("*", "Label", true, false).map(func(l): return l.text).filter(
			func(t): return t.begins_with("slot_list."))
	_check(states[0] == "slot_list.ready" and states.slice(1) == ["slot_list.wait", "slot_list.wait", "slot_list.wait"],
			"the TV says READY for slot 1 and WAIT for the others: %s" % str(states))
	tv_slots.queue_free()


## 1.3d: OK on the Connect screen of the TV opens the Games screen, and the phone says "choose a game on the TV".
func _tv_ok_to_games() -> void:
	print("OK on the TV Connect screen")
	var tv_connect: Control = _tv_connect_script.new()
	tv_connect.theme = _app.theme_res
	root.add_child(tv_connect)
	await _frames(3)
	var hint: Label = tv_connect._hint
	_check(hint.text == "connect.press_ok_continue", "after a join the TV Connect screen says PRESS OK TO CONTINUE")
	# 1.3c: the prompt blinks (hard steps), and there is no Continue button.
	var seen_on := false
	var seen_off := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1400:
		if hint.modulate.a == 0.0:
			seen_off = true
		elif hint.modulate.a == 1.0:
			seen_on = true
		await process_frame
	_check(seen_on and seen_off, "the prompt is seen on and off within 1.4 s: it blinks")
	_check(not _buttons(tv_connect).any(func(t): return String(t).to_lower().contains("continue")), "there is no Continue button")
	var ok := InputEventAction.new()
	ok.action = "ui_accept"
	ok.pressed = true
	tv_connect._unhandled_input(ok)
	_check(_app.current_screen().get_script() == _tv_games_script and _server.phase == "menu",
			"OK opens the Games screen and the TV phase is menu")
	var got := await _wait_until(func(): return _app.client.phase == "menu", 2000)
	await _frames(3)
	_check(got and _app.current_screen().get_script() == _wait_script, "the phone is back on its waiting screen")
	var wait: Control = _app.current_screen()
	_check(wait._title.text == Lang.t("wait.choose_game_tv").to_upper()
			and wait._sub.text == Lang.t("wait.use_tv_remote_phone").to_upper(),
			"the phone says CHOOSE A GAME ON THE TV: '%s'" % wait._title.text)
	tv_connect.queue_free()
	await _leave_all()


## 8b.6b: the slot color of the phone is the slot color of the TV for the four slots, on the waiting screen and on the pad.
func _four_slots() -> void:
	print("four phones: slot colors")
	var phones: Array[ControllerClient] = []
	for i in 4:
		var c := ControllerClient.new()
		root.add_child(c)
		c.connect_to("127.0.0.1", _port, _server.room_code)
		phones.append(c)
		await _wait_until(func(): return c.state == ControllerClient.State.CONNECTED, 4000)
	var same := true
	var distinct := {}
	for i in 4:
		same = same and phones[i].slot == i and phones[i].color == _server.players[i].color \
				and phones[i].color == Protocol.PLAYER_COLORS[i]
		distinct[phones[i].color.to_html()] = true
	_check(same and distinct.size() == 4, "each phone has the color of its slot on the TV, and the four colors differ")
	# The screens draw `client.color`: put each phone behind the screens and read the colors they take.
	var real_client: Node = _app.client
	var on_screens := true
	for i in 4:
		_app.client = phones[i]
		for script in [_wait_script, _pad_script]:
			var screen: Control = script.new()
			screen.theme = _app.theme_res
			root.add_child(screen)
			await process_frame
			on_screens = on_screens and _app.client.color == _server.players[i].color
			screen.queue_free()
	_app.client = real_client
	_check(on_screens, "the waiting screen and the pad of each phone take the color of its TV slot")
	# The number in the square is the slot number: the TV says 1P to 4P in the same slot order.
	var tv_slots: Control = _slot_list_script.new()
	tv_slots.theme = _app.theme_res
	root.add_child(tv_slots)
	await _frames(3)
	var numbers := _labels(tv_slots).filter(func(t): return t.ends_with("P"))
	_check(numbers == ["1P", "2P", "3P", "4P"] and _labels(tv_slots).count("slot_list.ready") == 4,
			"the TV lists 1P to 4P, all READY: %s" % str(numbers))
	tv_slots.queue_free()
	for c in phones:
		c.leave()
		c.queue_free()
	for p in _server.players:
		if p.is_present():
			_server.drop_player(p.slot)
	await _frames(3)


## 1.6d (REQ-N6): a phone that is closed without Disconnect comes back with the saved settings and the saved token, with no input.
func _rejoin_saved_token() -> void:
	print("a phone that returns with its saved token")
	var first := ControllerClient.new()
	root.add_child(first)
	first.connect_to("127.0.0.1", _port, _server.room_code)
	await _wait_until(func(): return first.state == ControllerClient.State.CONNECTED, 4000)
	var token: String = _server.players[first.slot].token
	var slot := first.slot
	var saved := first.load_last()
	_check(saved.host == "127.0.0.1" and saved.port == _port and saved.room == _server.room_code and saved.token == token
			and token != "", "the phone saved the TV address, the room and the token")
	first.queue_free()   # The app is closed: no Disconnect, no bye.
	await _frames(2)
	var second := ControllerClient.new()
	root.add_child(second)
	second.use_saved_token(String(saved.token))   # What App._start_controller does with the saved file.
	var t0 := Time.get_ticks_msec()
	second.connect_to(String(saved.host), int(saved.port), String(saved.room))
	var back := await _wait_until(func(): return second.state == ControllerClient.State.CONNECTED, 10000)
	var ms := Time.get_ticks_msec() - t0
	_check(back and ms < 10000 and second.slot == slot and _server.players[slot].token == token,
			"it is joined again in %d ms, in the same slot, with no tap" % ms)
	_check(_server.player_count() == 1, "the TV still has one phone (the old connection did not take a second slot)")
	second.leave()
	second.queue_free()
	for p in _server.players:
		if p.is_present():
			_server.drop_player(p.slot)
	await _frames(3)


## 8b.4a and 7.4c: a phone that joins during a round is told to wait for the next round.
func _join_in_round() -> void:
	print("a join during a round")
	var player := ControllerClient.new()
	root.add_child(player)
	player.connect_to("127.0.0.1", _port, _server.room_code)
	await _wait_until(func(): return player.state == ControllerClient.State.CONNECTED, 4000)
	_server.set_phase("playing", [player.slot] as Array[int])
	await _frames(5)
	_app.go(_connect_script)
	await process_frame
	var ok := await _join()
	await _frames(5)
	_check(ok and _app.client.phase == "waiting" and player.phase == "playing",
			"the late phone gets the phase waiting, the player gets playing")
	var wait: Control = _app.current_screen()
	_check(wait.get_script() == _wait_script and _app.current_screen().get_script() != _pad_script,
			"the late phone shows the waiting screen, not the pad (it has no object in the round)")
	_check(wait._title.text == Lang.t("wait.round_running").to_upper()
			and wait._sub.text == Lang.t("wait.join_next_round").to_upper(),
			"it says A ROUND IS IN PROGRESS and YOU JOIN NEXT ROUND: '%s' / '%s'" % [wait._title.text, wait._sub.text])
	_server.set_phase("menu")
	await _wait_until(func(): return _app.client.phase == "menu", 2000)
	player.leave()
	player.queue_free()
	await _leave_all()


## 8b.3b and 3c: a removed phone stays out, with the text of the host, and a scan of the pair link joins again.
func _kick() -> void:
	print("the host removes a phone")
	_app.go(_connect_script)
	await process_frame
	var ok := await _join(true)
	_check(ok, "the phone joins through the relay")
	var accepted_before: int = _relay.accepted
	_server.kick(_app.client.slot)
	var idle := await _wait_until(func(): return _app.client.state == ControllerClient.State.IDLE, 3000)
	await _frames(3)
	_check(idle and _app.last_error == Lang.t("app.host_removed_scan_code"),
			"a removed phone is idle and the message is the text of the host: '%s'" % _app.last_error)
	var screen: Control = _app.current_screen()
	_check(screen.get_script() == _connect_script, "the phone is on the Connect screen")
	_check(screen._status.text == _app.last_error.to_upper(),
			"the Connect screen shows the reason in its status line: '%s'" % screen._status.text)
	await create_timer(5.0).timeout
	_check(_app.client.state == ControllerClient.State.IDLE and _relay.accepted == accepted_before
			and _server.player_count() == 0,
			"after 5 s the removed phone has made no new connection attempt (%d connections)" % (_relay.accepted - accepted_before))
	# 3c: the pair link (what the QR code holds) brings the phone back in less than 5 s.
	var url := "ws://127.0.0.1:%d/%s" % [_port, _server.room_code]
	var pair := Protocol.parse_pair_url(url)
	var t0 := Time.get_ticks_msec()
	screen._join(pair.host, pair.port, pair.room)
	var again := await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED, 5000)
	_check(again and Time.get_ticks_msec() - t0 < 5000 and _server.player_count() == 1,
			"a join with the pair link fills the slot again in %d ms" % (Time.get_ticks_msec() - t0))
	await _leave_all()


## 7.1a, 7.1d and 7.3b: the link goes away without a close. The phone notices; when the slot is freed it joins again.
func _wifi_cut() -> void:
	print("Wi-Fi off: the phone notices, the TV frees the slot")
	_new_tv(2500)   # A freed slot after 2.5 s of silence.
	_app.go(_connect_script)
	await process_frame
	var ok := await _join(true)
	_check(ok and _server.players[0].state == PlayerInput.State.CONNECTED, "the phone joins through the relay")
	var lost_at := [-1]
	_server.player_lost.connect(func(_s): lost_at[0] = Time.get_ticks_msec())
	var t0 := Time.get_ticks_msec()
	_relay.cut()
	var phone_ms := await _phone_notices_cut(t0)
	_check(lost_at[0] > 0 and lost_at[0] - t0 < 3500, "the TV marks the slot lost within 3.5 s (%d ms)" % (lost_at[0] - t0))
	var freed := await _wait_until(func(): return _server.players[0].state == PlayerInput.State.EMPTY, 6000)
	_check(freed, "the TV frees the lost slot after the grace time")
	_relay.restore()
	# The TV does not know the token any more, and it asks for no PIN: the phone joins again by itself, as a new phone.
	var back := await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED, 20000)
	_check(back and _server.player_count() == 1, "when the link is back and the slot is gone, the phone joins again by itself")
	await _leave_all()


## The phone must notice that the TV is silent: after PEER_TIMEOUT_MS the client drops the half-open socket and retries.
## If it does not, the test does by hand what the client should do, so that the rest of the scenario is still tested.
func _phone_notices_cut(t0: int) -> int:
	var c: ControllerClient = _app.client
	var noticed := await _wait_until(func(): return c.state == ControllerClient.State.RECONNECTING, 9000)
	var ms := Time.get_ticks_msec() - t0
	_check(noticed and ms <= 3600, "the phone shows RECONNECTING within 3.6 s of the cut (REQ-GM-30: 3 s of silence) (%d ms)" % ms)
	if not noticed:
		c._close_socket()
		c._on_closed()   # What the client should do after PEER_TIMEOUT_MS.
	return ms


## 7.4b, 7.7d: while the game is paused for the phone, the slot is kept longer, and the phone returns to it.
func _wifi_cut_paused() -> void:
	print("Wi-Fi off during a pause: the slot is kept")
	_new_tv(1200)
	_server.paused_slot_grace_ms = 60000
	_app.go(_connect_script)
	await process_frame
	var ok := await _join(true)
	var token: String = _server.players[0].token if ok else ""
	var slot: int = _app.client.slot
	_server.set_phase("paused", [slot] as Array[int])
	await _wait_until(func(): return _app.client.phase == "paused", 2000)
	_relay.cut()
	await _wait_until(func(): return _server.players[slot].state == PlayerInput.State.LOST, 6000)
	await _phone_notices_cut(Time.get_ticks_msec())   # The phone gives up the dead link.
	await create_timer(1.5).timeout   # More than the normal grace time of 1.2 s.
	_check(_server.players[slot].state == PlayerInput.State.LOST and _server.players[slot].token == token,
			"a long cut during a pause: the slot is kept longer than the normal grace time (1.2 s) (the normal grace time is 1.2 s)")
	var t0 := Time.get_ticks_msec()
	_relay.restore()
	var back := await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED, 12000)
	var ms := Time.get_ticks_msec() - t0
	_check(back and ms < 10000 and _app.client.slot == slot and _server.players[slot].state == PlayerInput.State.CONNECTED
			and _server.players[slot].token == token,
			"when the link is back the phone returns to the same slot in %d ms (less than 10 s)" % ms)
	_check(_app.client.phase == "paused", "and the TV phase is still paused for it")
	_check(Protocol.PAUSED_SLOT_GRACE_MS >= 70000 and Protocol.PAUSED_SLOT_GRACE_MS > Protocol.SLOT_GRACE_MS,
			"the real hold during a pause is longer than a 70 s call (%d s)" % (Protocol.PAUSED_SLOT_GRACE_MS / 1000))
	_server.set_phase("menu")
	await _leave_all()


## A stand-in for the Android plugin "QrScanner" (android/plugin/QrScannerPlugin.java).
class FakeQrPlugin extends Object:
	signal scanned(text: String)
	signal failed(reason: String)
	var calls: Array[String] = []

	func scan() -> void:
		calls.append("scan")

	# gdlint:ignore=function-name
	func acquireWifiLocks() -> void:
		calls.append("acquireWifiLocks")


## Test 2: the scan with a fake plugin: the button, a good code, a cancel, a text that is not a code.
func _qr_scan() -> void:
	print("QR scan with a fake plugin")
	_new_tv()
	# Without the plugin the button pastes the link.
	_app.go(_connect_script)
	await process_frame
	var plain: Control = _app.current_screen()
	_check(_button(plain, "qr_scanner.paste_room_link") != null and _button(plain, "connect.scan_qr_code") == null,
			"without the plugin the button is PASTE TV LINK")
	var fake := FakeQrPlugin.new()
	Engine.register_singleton("QrScanner", fake)
	_app.go(_connect_script)
	await process_frame
	var screen: Control = _app.current_screen()
	var scan := _button(screen, "connect.scan_qr_code")
	_check(scan != null and _button(screen, "qr_scanner.paste_room_link") == null, "with the plugin the button is SCAN QR CODE")
	# A cancel: no error text, the button works again.
	scan.pressed.emit()
	fake.failed.emit("cancelled")
	await _frames(2)
	var failed_text := _labels(screen).any(func(t): return String(t).to_lower().contains("qr_failed"))
	_check(not failed_text, "a cancelled scan shows no QR SCAN FAILED text")
	_check(not scan.disabled and fake.calls == ["scan"], "after the cancel the scan button is enabled")
	scan.pressed.emit()
	_check(fake.calls == ["scan", "scan"], "and it starts a second scan (%d calls)" % fake.calls.size())
	# A real failure shows the reason.
	fake.failed.emit("camera denied")
	_check(screen._status.text == Lang.f("connect.qr_failed", ["camera denied"]).to_upper(),
			"a failed scan shows the reason: '%s'" % screen._status.text)
	# A text that is not a Sababi code.
	fake.scanned.emit("https://example.com")
	_check(screen._status.text == Lang.t("connect.not_sababi_code").to_upper()
			and screen._status.get_theme_color("font_color") == UiTheme.BAD,
			"a scan of https://example.com says THIS IS NOT A SABABI CODE: '%s'" % screen._status.text)
	_check(_app.client.state == ControllerClient.State.IDLE and _server.player_count() == 0, "and nothing is joined")
	# A good code: joined in less than 5 s.
	var url := "ws://127.0.0.1:%d/%s" % [_port, _server.room_code]
	var t0 := Time.get_ticks_msec()
	fake.scanned.emit(url)
	var joined := await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED, 5000)
	_check(joined and Time.get_ticks_msec() - t0 < 5000, "a scan of the TV code joins in %d ms" % (Time.get_ticks_msec() - t0))
	await _leave_all()
	Engine.unregister_singleton("QrScanner")
	fake.free()
	_app.go(_connect_script)
	await process_frame
