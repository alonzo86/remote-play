extends SceneTree
## Rules of docs/TV_FLOW.md that need a TV with real phones on the loopback (issue #306): the tiles of the Games screen follow the
## number of phones (REQ-FL-27), the TV sends the phase of the Connect and Games screens (REQ-FL-29), the Players modal shows
## the 4 slots with color and state, the QR code and Close (REQ-FL-32) and follows the phones while it is open, with the focus on
## Close and Back closing it (REQ-FL-34).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/tv_flow_reqs.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Registry = preload("res://scripts/game/registry.gd")
const QrView = preload("res://scripts/ui/qr_view.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _checks := 0
var _fails := 0
var _app: Node
var _clients: Array = []


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


## A phone joins with the room code of the TV. Returns the client.
func _join(player_name: String) -> ControllerClient:
	var c := ControllerClient.new()
	c.player_name = player_name
	root.add_child(c)
	c.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
	var n: int = _app.server.connected_slots().size()
	await _wait_until(func(): return _app.server.connected_slots().size() > n, 4000)
	_clients.append(c)
	return c


func _leave(c: ControllerClient) -> void:
	var n: int = _app.server.connected_slots().size()
	c.leave()
	await _wait_until(func(): return _app.server.connected_slots().size() < n, 4000)
	_clients.erase(c)
	c.queue_free()


func _tile(games: Control, id: String) -> Button:
	for t in games._tiles:
		if String(t.game.id) == id:
			return t
	return null


func _texts(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(l): return String(l.text))


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
	_app.server.address_lookup = func() -> String: return "192.168.1.20"   # A sandbox may have no Wi-Fi address, so no room code.
	_app.server.ip = "192.168.1.20"
	await _phase()
	await _tiles_follow_phones()
	await _players_modal()
	_app.server.address_lookup = lookup
	_app.go_connect()


## REQ-FL-29: the Connect and Games screens have their own value of the `phase` message, and a joined phone receives it.
func _phase() -> void:
	print("the phase of the Connect and Games screens")
	_app.go_connect()
	await _frames(3)
	_check(_app.server.phase == "connect", "REQ-FL-29: the Connect screen sets the phase `connect` (%s)" % _app.server.phase)
	var phone := await _join("Maya")
	_app.go_games()
	var got := await _wait_until(func(): return phone.phase == "menu", 3000)
	_check(_app.server.phase == "menu" and got,
			"REQ-FL-29: the Games screen sets `menu` and the phone receives it (%s)" % phone.phase)
	_app.go_settings()
	await _frames(3)
	_check(_app.server.phase == "menu" and phone.phase == "menu", "REQ-FL-29: the Settings screen keeps `menu`")
	_app.go_connect()
	got = await _wait_until(func(): return phone.phase == "connect", 3000)
	_check(got, "REQ-FL-29: back on the Connect screen the phone receives `connect` again (%s)" % phone.phase)
	await _leave(phone)


## REQ-FL-27: on the Games screen the tiles dim and open at once when a phone joins or leaves, without leaving the screen.
func _tiles_follow_phones() -> void:
	print("the tiles follow the number of phones")
	_app.go_games()
	await _frames(8)
	var games: Control = _app.current_screen()
	var paint := _tile(games, "paint_grab")   # 1 to 4 phones.
	var sumo := _tile(games, "sumo_bumpers")  # 2 to 4 phones.
	_check(paint != null and sumo != null, "the Games screen has the tiles of Paint Grab and Sumo Bumpers")
	if paint == null or sumo == null:
		return
	_check(not paint.fits and not sumo.fits and paint.modulate.a < 1.0 and sumo.modulate.a < 1.0,
			"REQ-FL-27: with no phone every tile is dim")
	var a := await _join("Maya")
	await _frames(3)
	_check(games == _app.current_screen() and paint.fits and paint.modulate.a == 1.0 and not sumo.fits and sumo.modulate.a < 1.0,
			"REQ-FL-27: one phone joins: Paint Grab opens, Sumo Bumpers stays dim")
	sumo.grab_focus()
	await _frames(3)
	_check(games._reason.text == Registry.reason(sumo.game, 1).to_upper(),
			"and the info bar shows why Sumo Bumpers cannot start: '%s'" % games._reason.text)
	var b := await _join("Noam")
	await _frames(3)
	_check(sumo.fits and sumo.modulate.a == 1.0 and sumo._meta.text == sumo.players_text().to_upper() and games._reason.text == "",
			"REQ-FL-27: a second phone joins: Sumo Bumpers opens, shows its player range ('%s') and the reason goes away"
			% sumo._meta.text)
	await _leave(b)
	await _frames(3)
	_check(not sumo.fits and sumo.modulate.a < 1.0 and paint.fits, "REQ-FL-27: the second phone leaves: Sumo Bumpers is dim again")
	await _leave(a)
	await _frames(3)
	_check(not paint.fits and paint.modulate.a < 1.0, "REQ-FL-27: the last phone leaves: Paint Grab is dim again")


## REQ-FL-32 and REQ-FL-34.
func _players_modal() -> void:
	print("the Players modal")
	_app.go_games()
	await _frames(6)
	var games: Control = _app.current_screen()
	var a := await _join("Maya")
	games._open_players()
	await _frames(6)
	var modal: Control = games._modal
	_check(modal != null, "the badge opens the Players modal")
	if modal == null:
		return
	var rows := _slot_rows(modal)
	_check(rows.size() == Protocol.MAX_PLAYERS, "REQ-FL-32: the modal shows %d slots (%d)" % [Protocol.MAX_PLAYERS, rows.size()])
	if rows.size() == Protocol.MAX_PLAYERS:
		_check(rows[0].square.color == Protocol.PLAYER_COLORS[a.slot] and rows[0].state == "slot_list.ready",
				"REQ-FL-32: the joined slot has the color of its player and the state READY")
		_check(rows[1].square.color == UiTheme.SLOT_EMPTY and rows[1].state == "slot_list.wait"
				and rows[2].state == "slot_list.wait" and rows[3].state == "slot_list.wait",
				"REQ-FL-32: an empty slot is gray and waits")
	var qrs := modal.find_children("*", "Control", true, false).filter(func(n): return n is QrView)
	_check(qrs.size() == 1 and qrs[0].text == Protocol.pair_url("192.168.1.20", _app.server.room_code),
			"REQ-FL-32: the modal has the QR code of the join link with the room code")
	var close: Button = modal._close_button
	_check(close != null and close.text == "players_modal.close" and modal.is_ancestor_of(close),
			"REQ-FL-32: the modal has a Close button")
	_check(root.gui_get_focus_owner() == close, "REQ-FL-34: the focus starts on Close")
	# A phone joins and one leaves while the modal is open: the rows follow without a reopen.
	var b := await _join("Noam")
	await _frames(4)
	rows = _slot_rows(modal)
	_check(modal == games._modal and rows.size() == 4 and rows[1].state == "slot_list.ready"
			and rows[1].square.color == Protocol.PLAYER_COLORS[b.slot] and _texts(modal).has("NOAM"),
			"REQ-FL-34: a phone joins: its row shows READY, its color and its name at once")
	await _leave(a)
	await _frames(4)
	rows = _slot_rows(modal)
	_check(rows[0].state == "slot_list.wait" and rows[0].square.color == UiTheme.SLOT_EMPTY and not _texts(modal).has("MAYA")
			and rows[1].state == "slot_list.ready",
			"REQ-FL-34: a phone leaves: its row is empty again and the other row stays")
	games.on_back()
	await _frames(3)
	_check(games._modal == null, "REQ-FL-34: Back closes the modal")
	await _leave(b)


## The rows of the slot list in a modal: [{square, state}] in the order of the slots.
func _slot_rows(modal: Node) -> Array:
	var out: Array = []
	for list in modal.find_children("*", "VBoxContainer", true, false):
		if list.get_script() == null or not String(list.get_script().resource_path).ends_with("slot_list.gd"):
			continue
		for row in list.get_children():
			var sq: ColorRect = row.get_node_or_null("Square")
			var state := ""
			for l in row.find_children("*", "Label", false, false):
				if String(l.text).begins_with("slot_list."):
					state = String(l.text)
			out.append({"square": sq, "state": state})
	return out
