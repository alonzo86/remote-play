extends SceneTree
## Join approval, the TV card (issue #393, docs/JOIN_APPROVAL_PLAN.md phase 3, 7.1 and 7.2, docs/TV_FLOW.md REQ-FL-97, 99, 34):
## the card of `JoinRequests` over the real TV screens, with fake phones on the real TV server (`approve_new` on in the test):
## what it shows (title, avatar, name, WANTS TO JOIN, +N WAITING), the focus (ALLOW first, Left and Right, mirrored in Hebrew), OK
## on each button, the 1 s guard, BACK that does nothing in any form, the card over the Players modal and the quit question, a
## screen change under the card, the end of a request (phone left, time limit, setting OFF, replaced), no card in a round, the 3
## refusals, the layout and the strings.
## Run by tests/run_all.sh: godot --headless --path . --script tests/join_approval_tv.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const Lang = preload("res://scripts/core/lang.gd")
const AvatarView = preload("res://scripts/ui/avatar_view.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const EDGE := Rect2(60, 60, 1800, 960)
const PID := "9f2c4e7a1b3d5f60718293a4b5c6d7e8"
const KEYS := {
	"approval.title": ["NEW PLAYER", "שחקן חדש"],
	"approval.wants": ["WANTS TO JOIN", "רוצה להצטרף"],
	"approval.allow": ["ALLOW", "לאשר"],
	"approval.refuse": ["REFUSE", "לסרב"],
	"approval.others_waiting": ["+%d WAITING", "עוד %d ממתינים"],
}

var _checks := 0
var _fails := 0
var _app: Node
var _fakes: Array = []
var _host_n := 0
var _quits := 0


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


func _until(cond: Callable, ms := 4000) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		for f in _fakes:
			f.poll()
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _spin(ms: int) -> void:
	await _until(func() -> bool: return false, ms)


## A phone at a made-up address (the TV reads the address of the pending entry, as tests/join_approval.gd does).
func _fake(host := "", fields := {}) -> Fake:
	if host == "":
		_host_n += 1
		host = "10.9.%d.%d" % [_host_n / 200, _host_n % 200 + 1]
	var f := Fake.new()
	_fakes.append(f)
	f.ws.connect_to_url("ws://127.0.0.1:%d" % Protocol.WS_PORT)
	var tagged := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		f.poll()
		if not tagged:
			for e in _app.server._pending:
				if not e.has("test"):
					e["test"] = true
					e.host = host
					tagged = true
					break
		if tagged and f.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			var msg := {"t": "hello", "v": Protocol.VERSION, "room": _app.server.room_code, "token": "", "name": ""}
			msg.merge(fields, true)
			f.ws.send_text(Protocol.to_json(msg))
			break
		await process_frame
	return f


func _press_key(keycode: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = pressed
	Input.parse_input_event(e)


## A real key: down, two frames, up (a button acts when the key is let go).
func _key(keycode: Key) -> void:
	if keycode == KEY_BACK or keycode == KEY_ESCAPE:
		_app._last_back_ms = 0   # Two Back presses inside 250 ms count once.
	_press_key(keycode, true)
	await _frames(2)
	_press_key(keycode, false)
	await _frames(2)


## The current screen is the script `<file>.gd` (a test script cannot preload a screen: it refers to the App autoload).
func _is_screen(file: String) -> bool:
	return _app.current_screen().get_script().resource_path.ends_with(file + ".gd")


func _jr() -> CanvasLayer:
	return _app.join_requests


func _open() -> bool:
	return _jr().is_open()


func _card() -> Control:
	return _jr().card if _open() else null


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _shown(n: Control) -> String:
	return n.text if n.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else n.tr(n.text)


## The shown texts of the visible labels and buttons of `box`.
func _texts(box: Node) -> Array:
	var out := []
	for c in box.find_children("*", "Control", true, false):
		if (c is Label or c is Button) and c.is_visible_in_tree() and String(c.text) != "":
			out.append(_shown(c))
	return out


func _button(card: Control, key: String) -> Button:
	for b in card.find_children("*", "Button", true, false):
		if b.text == key:
			return b
	return null


## The audio autoload (a test script is compiled before the autoloads exist).
func _sound() -> Node:
	return root.get_node("Sound")


func _played(id: String) -> bool:
	return _sound()._last_ms.has(id)


func _no_sound() -> void:
	_sound()._last_ms.clear()


## Waits for a card and for its first second to pass.
func _card_ready() -> bool:
	var ok := await _until(_open)
	if ok:
		await _until(func() -> bool: return not _card().guarded(), 3000)
		await _frames(3)
	return ok


func _reset() -> void:
	for f in _fakes:
		f.ws.close()
	_fakes.clear()
	_app.server.set_approve_new(false)
	for s in _app.server.connected_slots():
		_app.server.kick(s)
	_app.server.approval_timeout_ms = 60000
	_jr().guard_ms = 1000
	await _until(func() -> bool: return not _open() and _app.server.request_count() == 0, 3000)
	await _frames(10)
	_app.set_language("en", false)
	_app.server.set_approve_new(true)
	_app.go_games()
	await _frames(8)
	await _spin(1100)   # The gap after the last card.


func _run() -> void:
	await _frames(5)
	_app = root.get_node("App")
	root.size = Vector2i(1920, 1080)
	await _frames(3)
	if not _app.server.listening:
		_check(false, "the TV server listens (another TV app or test holds port %d)" % Protocol.WS_PORT)
		return
	_app.settings.language = "en"
	_app.set_language("en", false)
	var lookup: Callable = _app.server.address_lookup
	_app.server.address_lookup = func() -> String: return "192.168.1.20"   # A sandbox may have no Wi-Fi address, so no room code.
	_app.server.ip = "192.168.1.20"
	_app.server.max_accepts_per_ip = 100000
	_app.server.max_pending_per_ip = 100
	_app.quit_hook = func() -> void: _quits += 1
	_strings()
	_nothing_built()
	await _reset()
	await _card_and_flow()
	await _reset()
	await _back_never()
	await _reset()
	await _over_modals()
	await _reset()
	await _screen_change()
	await _reset()
	await _ends()
	await _reset()
	await _round()
	await _reset()
	await _refusals()
	await _reset()
	await _hebrew_and_layout()
	await _reset()
	_app.server.set_approve_new(false)
	_app.set_language("en", false)
	_app.server.address_lookup = lookup
	_app.quit_hook = Callable()
	_app.go_connect()


## The 5 strings: both languages, a `where`, the text of the table of docs/TV_FLOW.md.
func _strings() -> void:
	print("the strings")
	var rows := Lang.parse_csv(FileAccess.get_file_as_string(Lang.TABLE_FILE))
	for key in KEYS:
		var row: Array = []
		for r in rows:
			if r.size() > 0 and r[0] == key:
				row = r
		_check(row.size() >= 4 and String(row[1]) == KEYS[key][0] and String(row[2]) == KEYS[key][1]
				and String(row[3]).strip_edges() != "", "%s has English, Hebrew and a where, with the text of the table" % key)
	_check(not Lang.has("approval.hint_ok") and not Lang.has("approval.hint_back") and not Lang.has("approval.time_left"),
			"the card has no key hint and no time text: those keys do not exist")


## No card node exists until a request is shown (a hidden node would change the buttons and the focus walks of other suites).
func _nothing_built() -> void:
	print("nothing is built before a request")
	_check(_jr() != null and not _open() and _jr().card == null and _jr().get_child_count() == 0,
			"no request: the layer has no child and no card")
	_check(_app.get_child(_app.get_child_count() - 1) == _jr(), "the layer is the last child of the App (its keys come first)")
	_check(_jr().layer > 0 and _jr().layer < _app.overlay.layer, "the layer is above the screens and below the debug overlay")


func _card_and_flow() -> void:
	print("the card: content, focus, the 1 s guard, ALLOW, REFUSE, the next card")
	_app.go_connect()
	# A phone that is already in: the Connect screen would go on to Games with OK.
	_app.server.set_approve_new(false)
	var joined := await _fake("", {"name": "Joe"})
	await _until(func() -> bool: return joined.has("welcome"))
	_app.server.set_approve_new(true)
	var a := await _fake("", {"pid": PID, "name": "Maya", "av": 3})
	await _until(_open)
	var b := await _fake("", {"name": "Bo"})
	var c := await _fake("", {"name": "Cy"})
	await _until(func() -> bool: return _app.server.request_count() == 3)
	_jr().guard_ms = 1500
	await _until(_open)
	var t_open := Time.get_ticks_msec()
	_check(_open() and _card().get_parent() == _jr(), "a request is shown: the card is in the layer of the App")
	await _frames(4)
	var card := _card()
	var texts := _texts(card)
	_check(texts.has("NEW PLAYER") and texts.has("MAYA") and texts.has("WANTS TO JOIN") and texts.has("+2 WAITING")
			and texts.has("ALLOW") and texts.has("REFUSE"),
			"REQ-FL-97: title, name, WANTS TO JOIN, +2 WAITING, ALLOW, REFUSE (%s)" % str(texts))
	var views := card.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return n is AvatarView)
	_check(views.size() == 1 and views[0].index == 3 and not views[0].framed, "the avatar of the phone (3) shows with no frame")
	_check(not texts.any(func(t: String) -> bool: return t.contains("OK") or t.contains("BACK") or t.contains(":")),
			"the card has no key hint, no key name and no time")
	var allow := _button(card, "approval.allow")
	var refuse := _button(card, "approval.refuse")
	_check(allow != null and refuse != null and allow.get_global_rect().position.x < refuse.get_global_rect().position.x,
			"two buttons, ALLOW at the left of REFUSE in English")
	_check(_focus() == allow, "REQ-FL-97: the focus is on ALLOW when the card shows")
	_check(allow.get_theme_color("font_focus_color") == UiTheme.OK and refuse.get_theme_color("font_color") == UiTheme.BAD,
			"ALLOW is in OK green and REFUSE in BAD red (the mock)")

	# The first second: nothing does anything.
	var screen: Control = _app.current_screen()
	var id: int = _app.server.shown_request().id
	_no_sound()
	for k in [KEY_ENTER, KEY_RIGHT, KEY_LEFT, KEY_DOWN, KEY_UP, KEY_ESCAPE, KEY_BACK]:
		await _key(k)
	var early := Time.get_ticks_msec() - t_open < 1450
	_check(early, "the guard test ran inside the guard (%d ms)" % (Time.get_ticks_msec() - t_open))
	_check(_open() and _app.server.shown_request().get("id", -1) == id and _app.server.connected_slots().size() == 1
			and not a.has("welcome") and not a.has("kicked"),
			"REQ-FL-97: OK, BACK and the arrows in the first second answer nothing")
	_check(_focus() == allow and _app.current_screen() == screen and _quits == 0,
			"the focus is still on ALLOW, the Connect screen did not go on to Games, nothing quit")
	_check(not _played("move") and not _played("select") and not _played("back") and not _played("denied"),
			"no sound for a key in the first second")

	await _until(func() -> bool: return not card.guarded(), 3000)
	# The arrows move the focus; the edge does nothing; Up and Down do nothing.
	_no_sound()
	await _key(KEY_RIGHT)
	_check(_focus() == refuse and _played("move"), "Right moves the focus to REFUSE and plays `move`")
	_no_sound()
	await _key(KEY_RIGHT)
	_check(_focus() == refuse and not _played("move"), "Right at the edge: nothing, no sound")
	await _key(KEY_DOWN)
	await _key(KEY_UP)
	_check(_focus() == refuse and _open(), "Up and Down do nothing")
	await _key(KEY_LEFT)
	_check(_focus() == allow, "Left moves the focus back to ALLOW")
	await _key(KEY_ESCAPE)
	await _key(KEY_BACK)
	_check(_open() and _focus() == allow and _app.current_screen() == screen, "BACK after the guard does nothing either")

	# OK on ALLOW.
	_no_sound()
	await _key(KEY_ENTER)
	var ok := await _until(func() -> bool: return a.has("welcome"))
	_check(ok and _app.server.connected_slots().size() == 2, "OK on ALLOW: the phone gets `welcome` and a slot")
	await _frames(3)
	_check(not _open() and _jr().card == null, "the card closed after the answer")
	_check(_played("join") and not _played("select"), "ALLOW plays `join` (the server signal) and no `select`")
	_check(_app.current_screen() == screen, "the screen under the card did not change")
	var t_answer := Time.get_ticks_msec()
	await _spin(600)
	_check(not _open(), "the next card does not show 600 ms after an answer")
	await _until(_open, 2500)
	var gap := Time.get_ticks_msec() - t_answer
	_check(_open() and gap >= 900 and gap < 2200, "the next card shows 1 s after the answer (%d ms)" % gap)
	await _frames(3)
	var card2 := _card()
	var card2_id: int = card2.request_id()
	_check(card2 != card and _focus() == _button(card2, "approval.allow") and _texts(card2).has("BO")
			and _texts(card2).has("+1 WAITING"),
			"the next card is a new card for the next phone, focus on ALLOW, +1 WAITING")
	await _key(KEY_ENTER)
	_check(_open() and not b.has("welcome"), "OK at once on the next card does nothing (the guard of the new card)")
	await _until(func() -> bool: return is_instance_valid(card2) and not card2.guarded(), 3000)
	await _key(KEY_RIGHT)
	_no_sound()
	var slots_before: int = _app.server.connected_slots().size()
	await _key(KEY_ENTER)
	var refused := await _until(func() -> bool: return b.reason() == "refused")
	_check(refused and _app.server.connected_slots().size() <= slots_before,
			"OK on REFUSE: the phone gets kicked/refused and no slot")
	_check(_played("denied") and not _played("join"), "REFUSE plays `denied`")
	await _until(func() -> bool: return _open() and _card().request_id() != card2_id, 3000)
	_check(_open() and _texts(_card()).has("CY")
			and not _texts(_card()).any(func(t: String) -> bool: return t.contains("WAITING")),
			"the third card shows with no +N WAITING badge (nobody else waits)")
	_check(not _card().find_children("*", "Control", true, false).any(func(n: Node) -> bool: return n is AvatarView),
			"a phone with no profile shows no avatar")
	c.ws.close()


func _back_never() -> void:
	print("BACK does nothing while a card shows (D12)")
	var a := await _fake("", {"name": "Maya"})
	await _until(_open)
	var screen: Control = _app.current_screen()
	var id: int = _app.server.shown_request().id
	var phases := ["at 0.3 s", "after the guard"]
	for p in 2:
		if p == 1:
			await _card_ready()
		var allow := _button(_card(), "approval.allow")
		_no_sound()
		await _key(KEY_ESCAPE)
		await _key(KEY_BACK)
		_app._last_back_ms = 0
		_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		var e := InputEventKey.new()
		e.keycode = KEY_BACK
		e.pressed = true
		Input.parse_input_event(e)
		await _frames(2)   # The key and, within 250 ms, the notification of the same press.
		_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		_press_key(KEY_BACK, false)
		await _frames(2)
		_check(_open() and _app.server.shown_request().get("id", -1) == id and _app.server.request_count() == 1
				and not a.has("kicked") and not a.has("welcome"),
				"BACK %s (key, KEY_BACK, notification, both): the card stays, no answer" % phases[p])
		_check(_app.current_screen() == screen and _quits == 0 and _focus() == allow and not _played("back"),
				"BACK %s: same screen object, no quit, the focus stays, no sound" % phases[p])
	# After the card closed BACK works as today; the notification of a press consumed before the close is dropped.
	var back := InputEventKey.new()
	back.keycode = KEY_BACK
	back.pressed = true
	_jr()._input(back)
	_app.server.allow_request(id)
	await _frames(1)
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not _open() and _app.current_screen() == screen,
			"the notification of a BACK key consumed just before the close is dropped (250 ms)")
	await _spin(400)
	_app._last_back_ms = 0
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(5)
	_check(_is_screen("tv_connect"), "with no card BACK goes back as today: the Games screen goes to Connect")


func _over_modals() -> void:
	print("the card over the Players modal and over the quit question")
	_app.go_games()
	await _frames(5)
	var games: Control = _app.current_screen()
	games._open_players()
	await _frames(5)
	var modal: Control = games._modal
	var close_button: Control = _focus()
	_check(modal != null and close_button != null and modal.is_ancestor_of(close_button),
			"the Players modal is open with the focus inside")
	var a := await _fake("", {"name": "Maya"})
	_check(await _card_ready(), "the card shows over the Players modal")
	var card := _card()
	var allow := _button(card, "approval.allow")
	_check(_focus() == allow, "the focus moved to ALLOW of the card")
	await _key(KEY_RIGHT)
	_check(_focus() == _button(card, "approval.refuse"), "Right moves the focus of the card (the lower modal does not eat it)")
	await _key(KEY_LEFT)
	_check(_focus() == allow, "Left moves it back")
	await _key(KEY_ESCAPE)
	_check(_open() and games._modal == modal and is_instance_valid(modal) and not modal.is_queued_for_deletion(),
			"BACK does not close the Players modal under the card")
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	await _until(func() -> bool: return a.reason() == "refused")
	await _until(func() -> bool: return not _open(), 2000)
	await _frames(6)
	_check(_focus() != null and modal.is_ancestor_of(_focus()), "the card closed: the focus is back inside the Players modal")
	games.on_back()
	await _frames(3)
	_check(games._modal == null, "BACK closes the Players modal when no card shows (REQ-FL-34)")
	# The quit question of the Connect screen.
	_app.set_language("en", false)
	await _spin(1100)
	_app.go_connect()
	await _frames(5)
	var connect: Control = _app.current_screen()
	connect.on_back()
	await _frames(5)
	var dialog: Control = connect._modal
	_check(dialog != null, "the quit question is open")
	var b := await _fake("", {"name": "Bo"})
	await _card_ready()
	await _key(KEY_ESCAPE)
	await _key(KEY_BACK)
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	_check(_open() and connect._modal == dialog and _quits == 0 and _app.current_screen() == connect,
			"BACK over the quit question: no quit, the question stays, the card stays")
	await _key(KEY_ENTER)
	await _until(func() -> bool: return b.has("welcome"))
	_check(b.has("welcome") and _quits == 0, "OK on ALLOW over the quit question allows the phone and does not press Quit")
	await _until(func() -> bool: return not _open(), 2000)
	dialog.close()


func _screen_change() -> void:
	print("a screen change under an open card")
	_app.go_connect()
	await _frames(4)
	var a := await _fake("", {"name": "Maya"})
	await _card_ready()
	var card := _card()
	_app.go_games()
	await _frames(6)
	var screen: Control = _app.current_screen()
	_check(_app.get_child(_app.get_child_count() - 1) == _jr() and _open() and _card() == card,
			"after go() the layer is still the last child and the card is open")
	var loose := screen.find_children("*", "Control", true, false).filter(
			func(n: Node) -> bool: return n.focus_mode != Control.FOCUS_NONE and not card.is_ancestor_of(n))
	_check(loose.is_empty(), "the controls of the new screen cannot take the focus (%d can)" % loose.size())
	_check(_focus() != null and card.is_ancestor_of(_focus()), "the focus stays inside the card")
	await _key(KEY_ENTER)
	await _until(func() -> bool: return a.has("welcome"))
	_check(a.has("welcome") and _app.current_screen() == screen,
			"OK allows the phone and does not start a tile of the new screen")
	await _until(func() -> bool: return not _open(), 2000)
	await _frames(6)
	_check(_focus() != null and screen.is_ancestor_of(_focus()), "the card closed: the focus is on a control of the new screen")


func _ends() -> void:
	print("the card ends with its request")
	var a := await _fake("", {"name": "Maya"})
	await _until(_open)
	a.ws.close()
	_check(await _until(func() -> bool: return not _open(), 3000), "the phone left: the card closes")
	await _spin(1100)
	var b := await _fake("", {"name": "Bo"})
	await _until(_open)
	_app.server.set_approve_new(false)
	_check(await _until(func() -> bool: return not _open(), 3000) and b.reason() == "refused",
			"the setting went OFF: the card closes and the phone is refused")
	_app.server.set_approve_new(true)
	await _spin(1100)
	_app.server.approval_timeout_ms = 1500
	var c := await _fake("", {"name": "Cy"})
	await _until(_open)
	var screen: Control = _app.current_screen()
	_check(await _until(func() -> bool: return not _open(), 4000) and c.reason() == "timeout",
			"no answer: the card closes by the internal limit and the phone gets kicked/timeout")
	await _spin(300)
	_app._last_back_ms = 0
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(5)
	_check(_app.current_screen() != screen and _is_screen("tv_connect"),
			"BACK works again on the screen after the time limit")
	_app.go_games()
	_app.server.approval_timeout_ms = 60000
	await _spin(1100)
	# A replaced request: the same address asks again; the card shows again after the gap with a new id.
	var host := "10.8.0.1"
	var d := await _fake(host, {"name": "Old"})
	await _until(_open)
	var old := _card()
	var old_id: int = old.request_id()
	var d2 := await _fake(host, {"name": "New"})
	await _until(func() -> bool: return not _open() or _card().request_id() != old_id, 3000)
	_check(not _open() or _card().request_id() != old_id, "a replaced request: the old card is gone")
	await _until(_open, 3000)
	await _frames(4)
	_check(_open() and _card().request_id() != old_id and _texts(_card()).has("NEW"),
			"the replacement shows as a new card with the new name and a new id")
	_app.server.allow_request(old_id)
	await _spin(200)
	_check(_open() and not d.has("welcome") and not d2.has("welcome"), "an allow of the old id does nothing")
	# 5 seconds with no event: the texts do not change (no countdown).
	var before := _texts(_card())
	await _spin(2500)
	_check(_open() and _texts(_card()) == before, "the card shows no time: its texts do not change while it waits")


func _round() -> void:
	print("no card in a round")
	_app.server.set_phase("playing")
	var a := await _fake("", {"name": "Maya"})
	await _until(func() -> bool: return _app.server.request_count() == 1)
	await _spin(1800)
	_check(not _open() and _app.server.request_count() == 1, "in a round the request waits and no card shows")
	_app.server.set_phase("menu")
	_check(await _until(_open, 3000), "the card shows when the phase goes back to a menu phase")
	_app.server.set_phase("paused")
	await _frames(4)
	_check(not _open(), "the phase goes to a round again: the card closes (the request stays)")
	_check(_app.server.request_count() == 1 and not a.has("kicked"), "the request is not answered")
	_app.server.set_phase("menu")
	await _until(_open, 3000)


func _refusals() -> void:
	print("3 refusals in a row block the address; BACK between them changes nothing")
	var host := "10.8.1.1"
	for i in 3:
		var f := await _fake(host, {"name": "Maya"})
		await _card_ready()
		await _key(KEY_BACK)
		_check(_open() and not f.has("kicked"), "refusal %d: BACK does not refuse" % (i + 1))
		await _key(KEY_RIGHT)
		await _key(KEY_ENTER)
		await _until(func() -> bool: return f.reason() == "refused")
		await _until(func() -> bool: return not _open(), 2000)
		await _spin(1100)
	var fourth := await _fake(host, {"name": "Maya"})
	await _until(func() -> bool: return fourth.reason() == "refused", 3000)
	await _spin(1300)
	_check(fourth.reason() == "refused" and not _open() and _app.server.request_count() == 0,
			"the 4th request of the address is refused at once and shows no card")


## English and Hebrew: the texts, the mirror, the layout inside the 60 px margin, text 32 px or more.
func _hebrew_and_layout() -> void:
	print("English and Hebrew: texts, mirror, layout")
	await _fake("", {"pid": PID, "name": "Maya", "av": 3})
	var b := await _fake("", {"name": "אבגדהוזחטי"})
	var c := await _fake("", {"name": "Cy"})
	await _card_ready()
	_layout(_card(), "English")
	_app.set_language("he", false)
	await _frames(3)
	_app.server.refuse_request(_card().request_id())
	await _until(func() -> bool: return _open() and _card().request.name == "אבגדהוזחטי", 4000)
	await _card_ready()
	var card := _card()
	var texts := _texts(card)
	_check(texts.has("שחקן חדש") and texts.has("רוצה להצטרף") and texts.has("לאשר") and texts.has("לסרב")
			and texts.has("עוד 1 ממתינים"),
			"Hebrew: title, line, buttons and badge (%s)" % str(texts))
	var allow := _button(card, "approval.allow")
	var refuse := _button(card, "approval.refuse")
	_check(allow.get_global_rect().position.x > refuse.get_global_rect().position.x,
			"Hebrew mirrors: ALLOW at the right of REFUSE")
	_check(_focus() == allow, "Hebrew: the focus starts on ALLOW")
	await _key(KEY_RIGHT)
	_check(_focus() == allow, "Hebrew: Right at the right edge does nothing")
	await _key(KEY_LEFT)
	_check(_focus() == refuse, "Hebrew: Left moves the focus to REFUSE (the button at the left)")
	await _key(KEY_RIGHT)
	_check(_focus() == allow, "Hebrew: Right moves it back to ALLOW")
	_layout(card, "Hebrew")
	b.ws.close()
	c.ws.close()


func _layout(card: Control, what: String) -> void:
	var bad := []
	var buttons := []
	for n in card.find_children("*", "Control", true, false):
		if (n is Label or n is Button) and n.is_visible_in_tree() and String(n.text) != "":
			if not EDGE.encloses(n.get_global_rect()):
				bad.append("outside %s" % _shown(n).left(20))
			if n.get_theme_font_size("font_size") < 32:
				bad.append("small %s" % _shown(n).left(20))
			if n is Button:
				buttons.append(n)
	if buttons.size() == 2 and buttons[0].get_global_rect().intersects(buttons[1].get_global_rect()):
		bad.append("buttons overlap")
	_check(bad.is_empty() and EDGE.encloses(card.card.get_global_rect()) and is_equal_approx(card.card.size.x, 1200.0),
			"%s: the card is 1200 px wide, inside the 60 px margin, no text under 32 px (%s)" % [what, str(bad)])
