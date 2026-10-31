extends SceneTree
## Player profiles over the network (FD-22, docs/PROFILES_PLAN.md section 4): the TV checks what a phone sends, a phone with a
## profile is the same player in every room, a second phone with the same profile replaces the first one in a menu and not in a
## round, and equal names get a number. Real sockets on the local machine, like tests/net_loss.gd.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/net_profiles.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const Lang = preload("res://scripts/core/lang.gd")

const ID_A := "9f2c4e7a1b3d5f60718293a4b5c6d7e8"
const ID_B := "00112233445566778899aabbccddeeff"

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


func _wait_until(cond: Callable, max_ms := 3000) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


## A phone as a client object. `pid` empty is a guest.
func _phone(pid := "", p_name := "", av := -1) -> ControllerClient:
	var c := ControllerClient.new()
	root.add_child(c)
	c.set_profile(pid, p_name, av)
	c.connect_to("127.0.0.1", Protocol.WS_PORT, _server.room_code)
	await _wait_until(func(): return c.state == ControllerClient.State.CONNECTED or c.state == ControllerClient.State.IDLE)
	return c


## Sends one raw `hello` (so the test can send what a real phone never would) and returns the first answer.
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
	_server.set_phase("menu")
	await process_frame


func _leave(c: ControllerClient) -> void:
	if c.state != ControllerClient.State.IDLE:
		c.leave()
	c.queue_free()
	await process_frame


func _run() -> void:
	_server = TvServer.new()
	root.add_child(_server)
	_server.start({})
	_server.set_phase("menu")
	await _join_and_validate()
	await _switch_profile()
	await _same_profile()
	await _equal_names()
	await _round_rules()
	_server.stop()


func _join_and_validate() -> void:
	print("join with a profile")
	var a := await _phone(ID_A, "Maya", 3)
	var p := _server.players[0]
	_check(p.profile_id == ID_A and p.avatar == 3 and p.player_name == "Maya" and p.has_profile(),
			"the TV takes the ID, the avatar and the name of the hello")
	_check(a.tv_pid == ID_A and a.tv_avatar == 3 and a.tv_player_name == "Maya", "the welcome tells the phone what the TV took")
	await _leave(a)
	await _free_all()

	print("a phone with no profile")
	var g := await _phone()
	_check(not _server.players[0].has_profile() and _server.players[0].player_name == "Player 1" and _server.players[0].avatar == -1
			and g.tv_pid == "", "a guest is called Player N and has no avatar")
	# Issue #307: the default name is a string row, made in the language of the TV, never saved as text.
	Lang.set_language("he")   # In this order, as App.set_language does.
	_server.set_language("he")
	_check(_server.players[0].player_name == "שחקן 1" and _server.players[0].raw_name == "",
			"a guest is 'שחקן 1' when the TV is in Hebrew, and no name is stored")
	Lang.set_language("en")
	_server.set_language("en")
	_check(_server.players[0].player_name == "Player 1", "the guest name follows the TV back to English")
	await _leave(g)
	await _free_all()
	var old := await _raw_hello({"name": "Longname123456"})
	_check(_server.players[0].player_name == "Longname12" and not _server.players[0].has_profile()
			and old.reply.get("pid", "x") == "" and old.reply.get("pname", "x") == "",
			"an old phone that sends only a name is a guest with that name, cut to 10 characters")
	old.ws.close()
	await _free_all()

	print("what the TV does not believe")
	var bad := await _raw_hello({"pid": ID_A.to_upper(), "av": 300, "name": "Ma\nya!"})
	_check(_server.players[0].profile_id == ID_A and _server.players[0].avatar == -1 and _server.players[0].player_name == "Maya"
			and bad.reply.get("av", 0) == -1 and bad.reply.get("pid", "") == ID_A,
			"an ID in capitals is made small, an avatar of 300 is none, a name with a newline and a sign is cleaned")
	bad.ws.close()
	await _free_all()
	var notid := await _raw_hello({"pid": "not-an-id", "av": 2, "name": "Noam"})
	_check(not _server.players[0].has_profile() and _server.players[0].player_name == "Noam" and _server.players[0].avatar == -1,
			"a text that is not an ID makes a guest")
	notid.ws.close()
	await _free_all()
	var numeric := await _raw_hello({"pid": ID_A, "av": "x", "name": "Avi"})
	_check(_server.players[0].avatar == -1 and _server.players[0].profile_id == ID_A, "an avatar that is not a number is none")
	numeric.ws.close()
	await _free_all()


func _switch_profile() -> void:
	print("a change of profile")
	_server.set_phase("menu")
	var c := await _phone()
	var answers := []
	c.profile_answered.connect(func(): answers.append(c.tv_pid))
	c.set_profile(ID_A, "Noam", 7)
	await _wait_until(func(): return not answers.is_empty())
	var p := _server.players[0]
	_check(p.profile_id == ID_A and p.player_name == "Noam" and p.avatar == 7 and answers == [ID_A] and c.tv_avatar == 7,
			"in a menu the TV takes the new profile and answers with it")
	var twin := await _phone(ID_B, "Noam", 3)
	_check(_server.players[1].player_name == "Noam 2" and twin.tv_player_name == "Noam 2",
			"the phone is told the name that the TV shows, with the number")
	twin.player_name = "Noam"
	twin.avatar = 3
	_check(not twin._tv_differs(), "a number added by the TV is not a different name")
	twin.player_name = "Noama"
	_check(twin._tv_differs(), "another name is sent again")
	twin.player_name = "Noam"
	twin.avatar = 4
	_check(twin._tv_differs(), "another avatar is sent again")
	await _leave(twin)
	c.set_profile("", "", -1)
	await _wait_until(func(): return answers.size() == 2)
	_check(not p.has_profile() and p.player_name == "Player 1" and answers[1] == "", "the guest is a profile change too")

	_server.set_phase("playing", [0] as Array[int])
	answers.clear()
	c.phase = "playing"   # The phone follows the TV phase.
	c._handle({"t": "phase", "v": "playing"}, 0)
	c.set_profile(ID_B, "Dana", 1)
	_check(not c.can_change_profile(), "the phone does not send a change while a round runs")
	c._send_json({"t": "profile", "pid": ID_B, "name": "Dana", "av": 1})   # A phone that is not careful.
	await _wait_until(func(): return not answers.is_empty())
	_check(not p.has_profile() and answers == [""], "in a round the TV ignores a profile change and answers with the stored one")

	_server.set_phase("menu")   # The phone sends its profile again when the TV is in a menu (the TV may have ignored it).
	await _wait_until(func(): return p.profile_id == ID_B)
	_check(p.profile_id == ID_B and p.player_name == "Dana" and c.tv_pid == ID_B,
			"the phone sends its profile again in the next menu")
	await _leave(c)
	await _free_all()


func _same_profile() -> void:
	print("the same profile on two phones")
	_server.set_phase("menu")
	var a := await _phone(ID_A, "Maya", 1)
	var token_a := _server.players[0].token
	var rejected := []
	a.rejected.connect(func(reason): rejected.append(reason))
	var b := await _phone(ID_A, "Maya", 1)
	await _wait_until(func(): return not rejected.is_empty())
	_check(rejected == ["replaced"] and a.state == ControllerClient.State.IDLE,
			"in a menu the newer phone wins; the older one is told")
	_check(_server.player_count() == 1 and _server.players[0].profile_id == ID_A and _server.players[0].token != token_a,
			"only one player is left, with the new token")
	var stale := await _raw_hello({"token": token_a, "pid": ID_A})
	_check(stale.reply.get("t", "") == "kicked" and stale.reply.get("reason", "") == "replaced" and _server.player_count() == 1,
			"a phone that comes back with the old token is sent away and does not replace the new one")
	stale.ws.close()
	await _leave(a)
	await _leave(b)
	await _free_all()

	print("a full TV")
	var guests: Array[ControllerClient] = []
	var first := await _phone(ID_A, "Maya", 1)
	for i in 3:
		guests.append(await _phone())
	_check(_server.player_count() == Protocol.MAX_PLAYERS, "the TV is full")
	var again := await _phone(ID_A, "Maya", 2)
	_check(again.state == ControllerClient.State.CONNECTED and _server.player_count() == Protocol.MAX_PLAYERS
			and _server.players[0].avatar == 2, "a full TV still takes the phone that replaces its own profile")
	var fifth := await _raw_hello({"pid": ID_B})
	_check(fifth.reply.get("t", "") == "reject" and fifth.reply.get("reason", "") == "full", "another phone is still turned away")
	fifth.ws.close()
	for c in guests:
		await _leave(c)
	await _leave(first)
	await _leave(again)
	await _free_all()


func _equal_names() -> void:
	print("equal names")
	_server.set_phase("menu")
	var a := await _phone(ID_A, "Sam", 1)
	var b := await _phone(ID_B, "sam", 2)
	var g := await _phone()
	_check(_server.players[0].player_name == "Sam" and _server.players[1].player_name == "sam 2",
			"a second name that is the same, in other case, gets a number")
	var named := await _raw_hello({"name": "Player 3"})
	_check(_server.players[2].player_name == "Player 3" and _server.players[3].player_name == "Player 3 2",
			"a guest name is part of the check")
	named.ws.close()
	await _leave(a)
	await process_frame
	_check(_server.players[1].player_name == "sam", "when the other player leaves in a menu, the number goes")
	await _leave(b)
	await _leave(g)
	await _free_all()


func _round_rules() -> void:
	print("a round")
	_server.set_phase("menu")
	var a := await _phone(ID_A, "Sam", 1)
	var b := await _phone(ID_B, "Lea", 2)
	_server.set_phase("playing", [0, 1] as Array[int])
	var late := await _phone(ID_B, "Lea", 4)
	_check(late.state == ControllerClient.State.CONNECTED and _server.player_count() == 3
			and b.state == ControllerClient.State.CONNECTED
			and _server.players[1].profile_id == ID_B and late.tv_pid == "",
			"in a round a second phone with a profile does not replace anybody; it joins as a guest")
	_check(_server.players[2].player_name == "Player 3", "the guest has no profile name")
	var same := await _raw_hello({"name": "Sam"})
	_check(_server.players[3].player_name == "Sam 2" and _server.players[0].player_name == "Sam",
			"a name that joins in a round gets a number and nobody else changes name")
	await _leave(a)   # The first Sam leaves in the round: the other Sam keeps its number until the menu.
	await process_frame
	_check(_server.players[3].player_name == "Sam 2", "in a round no name changes, also when the other player left")
	var again := await _raw_hello({"name": "Sam", "token": String(same.reply.get("token", ""))})
	_check(again.reply.get("slot", -1) == 3 and _server.players[3].player_name == "Sam 2"
			and String(again.reply.get("pname", "")) == "" and _server.players[0].is_present() == false,
			"a phone that returns in a round keeps the name it had, also when the first Sam is gone")
	same.ws.close()
	again.ws.close()
	# A phone that comes back in a round keeps the profile that the TV has.
	b.set_process(false)
	await _wait_until(func(): return _server.players[1].state == PlayerInput.State.LOST, 8000)
	b.set_process(true)
	b.set_profile(ID_A, "Other", 5)
	var back := await _wait_until(func(): return _server.players[1].state == PlayerInput.State.CONNECTED, 8000)
	_check(back and _server.players[1].profile_id == ID_B and _server.players[1].player_name == "Lea",
			"a phone that returns in a round keeps its profile, whatever it sends")
	_server.set_phase("menu")
	_check(_server.players[3].player_name == "Sam", "in the menu the names are made again, so the number goes")
	for c in [b, late]:
		await _leave(c)
	await _free_all()
