extends SceneTree
## The close handshake of let-go sockets (`ClosingSockets`, shared by the TV and the phone) and the contract of
## `TvServer.start` (issue #310). Real sockets on the local machine, on port 47811 (not the port of the TV, 47801).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/net_cleanup.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ClosingSockets = preload("res://scripts/net/closing_sockets.gd")

const TEST_PORT := 47811

var _checks := 0
var _fails := 0


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
	await _closing()
	await _start_twice()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## A connected pair of sockets: [client, server side].
func _pair(tcp: TCPServer) -> Array:
	var client := WebSocketPeer.new()
	client.connect_to_url("ws://127.0.0.1:%d" % TEST_PORT)
	var server_side: WebSocketPeer = null
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		if tcp.is_connection_available() and server_side == null:
			server_side = WebSocketPeer.new()
			server_side.accept_stream(tcp.take_connection())
		client.poll()
		if server_side != null:
			server_side.poll()
			if client.get_ready_state() == WebSocketPeer.STATE_OPEN and server_side.get_ready_state() == WebSocketPeer.STATE_OPEN:
				return [client, server_side]
		await process_frame
	return [client, server_side]


func _closing() -> void:
	print("the close of a let-go socket")
	var tcp := TCPServer.new()
	tcp.listen(TEST_PORT)
	var pair := await _pair(tcp)
	var ws: WebSocketPeer = pair[0]
	_check(ws.get_ready_state() == WebSocketPeer.STATE_OPEN, "the test pair is connected")
	var c := ClosingSockets.new()
	_check(c.is_empty(), "a new list is empty")
	c.add(ws, 1000)
	_check(c.size() == 1 and not c.is_empty(), "a socket that is added is kept")
	c.service(1000 + ClosingSockets.CLOSE_DELAY_MS - 1)
	_check(ws.get_ready_state() == WebSocketPeer.STATE_OPEN, "the close frame is not sent before the delay (a bye must go first)")
	c.service(1000 + ClosingSockets.CLOSE_DELAY_MS)
	_check(ws.get_ready_state() != WebSocketPeer.STATE_OPEN, "at the delay the close handshake starts")
	var t0 := Time.get_ticks_msec()
	var peer: WebSocketPeer = pair[1]
	while not c.is_empty() and Time.get_ticks_msec() - t0 < 3000:
		peer.poll()
		c.service(1000 + ClosingSockets.CLOSE_DELAY_MS + 1)   # The time stays below the give-up time: only a closed socket leaves.
		await process_frame
	_check(c.is_empty() and ws.get_ready_state() == WebSocketPeer.STATE_CLOSED, "a socket that has closed leaves the list")

	var pair2 := await _pair(tcp)
	var stuck: WebSocketPeer = pair2[0]
	c.add(stuck, 5000)
	c.service(5000 + ClosingSockets.CLOSE_GIVE_UP_MS)
	_check(c.size() == 1, "at the give-up time the socket is still kept")
	c.service(5000 + ClosingSockets.CLOSE_GIVE_UP_MS + 1)
	_check(c.is_empty(), "after the give-up time a socket that did not end is dropped")
	tcp.stop()


func _start_twice() -> void:
	print("TvServer.start twice")
	var server := TvServer.new()
	server.port = TEST_PORT
	root.add_child(server)
	_check(server.start({}) == OK and server.players.size() == Protocol.MAX_PLAYERS, "the first start makes 4 slots")
	server.stop()
	server.start({})
	_check(server.players.size() == Protocol.MAX_PLAYERS and server._sockets.size() == Protocol.MAX_PLAYERS
			and server._last_rx_ms.size() == Protocol.MAX_PLAYERS, "a second start does not add slots")
	_check(server.players[3].slot == 3 and server.player_count() == 0, "the slots are numbered 0 to 3 and empty")
	server.stop()
	server.queue_free()
	await process_frame
