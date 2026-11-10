extends SceneTree
## The `leave_ask` message (issue #435, REQ-FL-52c, docs/PROTOCOL.md): a phone asks the TV to end the game that runs,
## as Back on the TV remote does. The TV takes it only while a game plays, from a connected phone that takes part in the
## round, and one request each second from a phone at most; every other `leave_ask` is ignored with no answer. Real sockets
## on the local machine, like tests/net_profiles.gd.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/net_leave_ask.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const Lang = preload("res://scripts/core/lang.gd")

# Not the game port: it depends on the process, so two runs at the same time do not fail each other (as in net_limits.gd).
var PORT := 47000 + OS.get_process_id() % 900
var _checks := 0
var _fails := 0
var _server: TvServer
var _asked: Array[int] = []


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


func _wait_until(cond: Callable, max_ms := 3000) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _phone() -> ControllerClient:
	var c := ControllerClient.new()
	root.add_child(c)
	c.connect_to("127.0.0.1", PORT, _server.room_code)
	await _wait_until(func(): return c.state == ControllerClient.State.CONNECTED or c.state == ControllerClient.State.IDLE)
	return c


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _on_asked(slot: int) -> void:
	_asked.append(slot)


func _run() -> void:
	await process_frame
	Lang.set_language("en", root)
	_server = TvServer.new()
	_server.port = PORT
	root.add_child(_server)
	_server.start({})
	_server.set_phase("menu")
	_server.leave_asked.connect(_on_asked)
	_codec()
	await _wire()
	_rules()
	_server.stop()


## The message is in the table of the protocol as a phone message, and it needs no VERSION bump: nobody waits for it.
func _codec() -> void:
	print("the message")
	_check(Protocol.MESSAGES.get("leave_ask", "") == "phone", "leave_ask is a message of the phone in Protocol.MESSAGES")
	_check(Protocol.VERSION == 5 and Protocol.LEAVE_ASK_MIN_MS == 1000,
			"a compatible addition: VERSION stays 5; one request each second")
	var msg := Protocol.parse_json(Protocol.to_json({"t": "leave_ask"}))
	_check(Protocol.text(msg, "t") == "leave_ask" and msg.size() == 1, "it is the JSON object {\"t\":\"leave_ask\"} and no more")


## A real phone: the client sends it only while connected and in a running game, and the TV hears it.
func _wire() -> void:
	print("a phone over the network")
	var a := await _phone()
	var b := await _phone()
	_check(a.state == ControllerClient.State.CONNECTED and b.state == ControllerClient.State.CONNECTED, "two phones are connected")
	_asked.clear()
	_server.set_phase("menu")
	await _wait_until(func(): return a.phase == "menu")
	a.send_leave_ask()
	await _frames(20)
	_check(_asked.is_empty(), "the client does not send it in a menu phase, and the TV takes nothing")
	_server.set_phase("playing")
	await _wait_until(func(): return a.phase == "playing" and b.phase == "playing")
	a.send_leave_ask()
	await _wait_until(func(): return not _asked.is_empty())
	_check(_asked == [a.slot], "in a game the TV takes the request of the phone and says which slot asked: %s" % str(_asked))
	_server.set_phase("paused")
	await _wait_until(func(): return b.phase == "paused")
	b.send_leave_ask()
	await _frames(20)
	_check(_asked == [a.slot], "the client does not send it while the game is paused")
	# A phone with an old or hostile build that sends it anyway: the TV ignores it while paused, and does not answer.
	var raw_ws: WebSocketPeer = b._ws
	raw_ws.send_text('{"t":"leave_ask"}')
	await _frames(20)
	_check(_asked == [a.slot], "a leave_ask on the wire while the game is paused is ignored")
	_check(b.state == ControllerClient.State.CONNECTED, "the phone gets no error and stays connected")
	_server.set_phase("menu")
	await _frames(2)
	for c in [a, b]:
		c.leave()
		c.queue_free()
	await _frames(5)
	for p in _server.players:
		if p.is_present():
			_server.drop_player(p.slot)


## The rules of the TV, with the clock in the hands of the test.
func _rules() -> void:
	print("the rules of the TV")
	for slot in [0, 1]:
		_server.players[slot].state = PlayerInput.State.CONNECTED
	_asked.clear()
	_server.set_phase("menu")
	_server._handle_control(0, {"t": "leave_ask"}, 10000)
	_check(_asked.is_empty(), "no game in progress (menu): ignored")
	_server.set_phase("connect")
	_server._handle_control(0, {"t": "leave_ask"}, 10000)
	_check(_asked.is_empty(), "no game in progress (connect screen): ignored")
	_server.set_phase("playing")
	_server._handle_control(0, {"t": "leave_ask", "extra": [1, {}]}, 20000)
	_check(_asked == [0], "in a game: accepted (other fields are ignored)")
	_server._handle_control(0, {"t": "leave_ask"}, 20400)
	_check(_asked == [0], "0.4 s after the last one from the same phone: ignored")
	_server._handle_control(0, {"t": "leave_ask"}, 20999)
	_check(_asked == [0], "999 ms after the last one: ignored (a spam does not push the time)")
	_server._handle_control(1, {"t": "leave_ask"}, 20500)
	_check(_asked == [0, 1], "another phone has its own time: accepted")
	_server._handle_control(0, {"t": "leave_ask"}, 21000)
	_check(_asked == [0, 1, 0], "1 s after the last accepted one: accepted again")
	_asked.clear()
	_server._handle_control(2, {"t": "leave_ask"}, 50000)
	_check(_asked.is_empty(), "an empty slot (no phone): ignored")
	_server._handle_control(0, {"t": ["leave_ask"]}, 60000)
	_server._handle_control(0, {"t": 5}, 60000)
	_check(_asked.is_empty(), "a type that is not a text: ignored with no error")
	var round_slots_only: Array[int] = [1]
	_server.set_phase("playing", round_slots_only)
	_server._handle_control(0, {"t": "leave_ask"}, 70000)
	_check(_asked.is_empty(), "a phone that is not in the round (it waits for the next one): ignored")
	_server._handle_control(1, {"t": "leave_ask"}, 70000)
	_check(_asked == [1], "a phone that is in the round: accepted")
	_asked.clear()
	_server.set_phase("paused")
	_server._handle_control(1, {"t": "leave_ask"}, 90000)
	_check(_asked.is_empty(), "the game is paused (a question or a lost phone): ignored")
	_server.players[1].state = PlayerInput.State.LOST
	_server.set_phase("playing")
	_server._handle_control(1, {"t": "leave_ask"}, 95000)
	_check(_asked.is_empty(), "a phone that lost its link is not connected: ignored")
	_server.set_phase("menu")
