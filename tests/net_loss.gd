extends SceneTree
## A phone that goes silent (REQ-GM-30, PROTOCOL.md "Slots, loss and reconnect"): the TV marks it lost, gives the slot back when
## the phone returns, and keeps the slot longer while the game is paused for it.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/net_loss.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")

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


func _join(server: TvServer) -> ControllerClient:
	var c := ControllerClient.new()
	root.add_child(c)
	c.connect_to("127.0.0.1", Protocol.WS_PORT, server.room_code)
	await _wait_until(func(): return c.state == ControllerClient.State.CONNECTED, 4000)
	return c


func _run() -> void:
	var server := TvServer.new()
	root.add_child(server)
	server.start({})
	server.peer_timeout_ms = 1500   # More than a heartbeat (1 s) of a phone that is well.
	server.slot_grace_ms = 8000   # Long: the phone comes back in time. The stage of the freed slot makes it short.
	server.paused_slot_grace_ms = 3500
	var events := []
	server.player_lost.connect(func(s): events.append("lost%d" % s))
	server.player_resumed.connect(func(s): events.append("resume%d" % s))
	server.player_removed.connect(func(s): events.append("removed%d" % s))

	print("a phone that stays well")
	var c := await _join(server)
	var token: String = server.players[0].token
	await create_timer(2.5).timeout
	_check(server.players[0].state == PlayerInput.State.CONNECTED and events.is_empty(),
			"a phone that only sends its heartbeat is not lost")

	print("a silent phone")
	c.set_process(false)   # The connection stays open but nothing comes: a phone that lost its Wi-Fi.
	var t0 := Time.get_ticks_msec()
	var lost := await _wait_until(func(): return server.players[0].state == PlayerInput.State.LOST, 6000)
	var after := Time.get_ticks_msec() - t0
	_check(lost and after < 3500, "the TV marks a silent phone lost (%d ms), also when the connection does not close" % after)
	_check(events == ["lost0"], "one lost event: %s" % str(events))
	c.set_process(true)
	var back := await _wait_until(func(): return server.players[0].state == PlayerInput.State.CONNECTED, 6000)
	_check(back and server.players[0].token == token and c.slot == 0 and events.has("resume0"),
			"the phone comes back with its token and gets the same slot (back %s, same token %s, slot %d, events %s)"
			% [str(back), str(server.players[0].token == token), c.slot, str(events)])

	print("the slot of a lost phone")
	events.clear()
	server.slot_grace_ms = 800
	server.set_phase("playing", [0] as Array[int])
	c.set_process(false)
	await _wait_until(func(): return server.players[0].state == PlayerInput.State.LOST, 6000)
	var freed := await _wait_until(func(): return server.players[0].state == PlayerInput.State.EMPTY, 3000)
	_check(freed and events.has("removed0"), "in a running game the lost slot is freed after the normal grace time")
	c.set_process(true)
	await create_timer(1.0).timeout
	c.leave()
	await create_timer(0.5).timeout

	var c2 := await _join(server)
	events.clear()
	server.set_phase("paused", [server.players[0].slot] as Array[int])
	c2.set_process(false)
	await _wait_until(func(): return server.players[0].state == PlayerInput.State.LOST, 6000)
	await create_timer(1.8).timeout   # More than the normal grace time of 0.8 s.
	_check(server.players[0].state == PlayerInput.State.LOST and not events.has("removed0"),
			"while the game is paused for it, the lost slot is kept longer than the normal grace time")
	var freed2 := await _wait_until(func(): return server.players[0].state == PlayerInput.State.EMPTY, 4000)
	_check(freed2 and events.has("removed0"), "and it is freed when the longer time is over")
	c2.set_process(true)
	c2.leave()
	await create_timer(0.5).timeout
	_check(Protocol.PEER_TIMEOUT_MS == 3000 and Protocol.SLOT_GRACE_MS <= 5000,
			"a phone that sends nothing for 3 s is lost, and a lost slot is freed in 5 s or less (issues #56, #44)")
	_check(Protocol.PAUSED_SLOT_GRACE_MS > Protocol.SLOT_GRACE_MS and Protocol.PEER_TIMEOUT_MS >= 2000,
			"the real times: the paused hold is longer than the normal one, and the silence limit is above 2 s")
