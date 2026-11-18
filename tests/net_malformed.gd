extends SceneTree
## Frames with fields of the wrong type (issue #308). Any device on the Wi-Fi can send text to the TV port, and the TV can be
## another build: a field that is an Array, a Dictionary, a number where a text is expected (or the other way) must not raise
## a script error, and must not change the state of the player. Real sockets on the local machine, like tests/net_profiles.gd.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/net_malformed.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Lang = preload("res://scripts/core/lang.gd")

# Not the game port: it depends on the process, so two runs at the same time do not fail each other (as in net_limits.gd).
var PORT := 47000 + OS.get_process_id() % 900
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
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Polls `ws` for up to `ms` and returns the frames that came.
func _pump(ws: WebSocketPeer, ms := 400) -> Array:
	var got := []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		ws.poll()
		while ws.get_ready_state() == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count() > 0:
			got.append(Protocol.parse_json(ws.get_packet().get_string_from_utf8()))
		await process_frame
	return got


func _open(fields: Dictionary) -> WebSocketPeer:
	var ws := WebSocketPeer.new()
	ws.connect_to_url("ws://127.0.0.1:%d" % PORT)
	var t0 := Time.get_ticks_msec()
	while ws.get_ready_state() != WebSocketPeer.STATE_OPEN and Time.get_ticks_msec() - t0 < 3000:
		ws.poll()
		await process_frame
	var msg := {"t": "hello", "v": Protocol.VERSION, "room": _server.room_code, "token": "", "name": ""}
	msg.merge(fields, true)
	ws.send_text(Protocol.to_json(msg))
	return ws


func _welcome(frames: Array) -> Dictionary:
	for f in frames:
		if f.get("t", "") == "welcome":
			return f
	return {}


func _run() -> void:
	await process_frame   # The App autoload applies the saved language in its _ready; set ours after it.
	Lang.set_language("en", root)   # The texts are checked in English, whatever language this machine saved.
	_server = TvServer.new()
	_server.port = PORT
	root.add_child(_server)
	_server.start({})
	_server.set_phase("menu")
	_helpers()
	await _hello_fields()
	await _control_fields()
	await _client_fields()
	_server.stop()


func _helpers() -> void:
	print("Protocol readers")
	var m := {"a": 3, "b": 2.5, "c": "x", "d": true, "e": [1], "f": {}, "g": INF}
	_check(Protocol.num(m, "a") == 3.0 and Protocol.num(m, "b") == 2.5, "num reads an integer and a float")
	_check(Protocol.num(m, "c", 7.0) == 7.0 and Protocol.num(m, "d", 7.0) == 7.0 and Protocol.num(m, "e", 7.0) == 7.0
			and Protocol.num(m, "f", 7.0) == 7.0 and Protocol.num(m, "g", 7.0) == 7.0 and Protocol.num(m, "zz", 7.0) == 7.0,
			"num gives the default for text, a boolean, an Array, a Dictionary, INF and a missing key")
	_check(Protocol.whole(m, "b") == 2 and Protocol.whole(m, "e", 9) == 9 and Protocol.whole(m, "c", 9) == 9, "whole")
	_check(Protocol.text(m, "c") == "x" and Protocol.text(m, "a", "d") == "d" and Protocol.text(m, "e", "d") == "d", "text")
	_check(Protocol.flag(m, "d") and not Protocol.flag(m, "a") and Protocol.flag(m, "e", true), "flag")


func _hello_fields() -> void:
	print("a hello with fields of the wrong type")
	var ws := await _open({"room": ["A"], "token": {"x": 1}, "name": 5, "pid": [1], "av": {}})
	var frames := await _pump(ws)
	var w := _welcome(frames)
	_check(not w.is_empty(), "the phone is welcomed (an unusable room, token and name count as empty)")
	_check(_server.players[0].is_present() and _server.players[0].player_name == "Player 1" and not _server.players[0].has_profile(),
			"the player is a guest with the default name")
	ws.close()
	await _pump(ws, 200)
	_server.drop_player(0)
	var ws2 := await _open({"v": [5]})
	var frames2 := await _pump(ws2)
	_check(_welcome(frames2).is_empty(), "a version that is not a number is a wrong version")
	ws2.close()
	await process_frame


func _control_fields() -> void:
	print("control frames with fields of the wrong type")
	var ws := await _open({})
	await _pump(ws)
	var p := _server.players[0]
	p.on_stat(12.0, 3.0)
	ws.send_text('{"t":"stat","rtt":{},"off":[1]}')
	await _pump(ws, 200)
	_check(p.rtt_ms == -1.0 and p.clock_offset_ms == 0.0, "a stat with an object and an Array takes the defaults")
	ws.send_text('{"t":"stat","rtt":20.5,"off":-4}')
	await _pump(ws, 200)
	_check(p.rtt_ms == 20.5 and p.clock_offset_ms == -4.0, "a good stat after it is taken")
	ws.send_text('{"t":"ping","id":[1],"t0":{"a":1}}')
	var pong := {}
	for f in await _pump(ws, 300):
		if f.get("t", "") == "pong":
			pong = f
	_check(pong.get("id", "x") == 0 and pong.get("t0", "x") == 0, "a pong echoes only numbers (Array and object become 0)")
	ws.send_text('{"t":["stat"]}')
	ws.send_text('{"t":"profile","pid":7,"name":[],"av":"x"}')
	var prof := {}
	for f in await _pump(ws, 300):
		if f.get("t", "") == "profile":
			prof = f
	_check(prof.get("pid", "x") == "" and prof.get("name", "x") == "", "a profile with wrong types is a guest and gets the answer")
	_check(ws.get_ready_state() == WebSocketPeer.STATE_OPEN and p.is_present(), "the link is still open")
	ws.close()
	await _pump(ws, 200)
	_server.drop_player(0)


func _client_fields() -> void:
	print("a phone gets frames with fields of the wrong type")
	var c := ControllerClient.new()
	root.add_child(c)
	var now := Time.get_ticks_msec()
	c._handle({"t": "welcome", "slot": [0], "color": {}, "token": 5, "name": [], "phase": 3, "rc": "yes", "ab": {}, "pid": 1,
			"av": [], "pname": 2}, now)
	_check(c.slot == -1 and c.tv_name == "TV" and c.phase == "connect" and c.recenter_button and c.pad_buttons == "ab"
			and c.tv_pid == "" and c.tv_player_name == "", "a welcome with the wrong types gives the defaults")
	c._handle({"t": "pong", "t0": "x", "t1": [1]}, now + 10)
	_check(is_finite(c.rtt_ms) and is_finite(c.clock_offset_ms), "a pong with the wrong types keeps the clock numbers finite")
	c._handle({"t": "score", "rank": {}, "of": "2", "v": 5}, now)
	_check(c.score_rank == 0 and c.score_of == 0 and c.score_text == "", "a score with the wrong types is empty")
	for bad in [{}, [1], null, "x".repeat(100000), "A\nB\tC\u0007D"]:   # `final` (REQ-FL-67a): no error, an empty or a clean line.
		c._handle({"t": "final", "v": bad}, now)
		_check(c.final_text.length() <= 60 and not c.final_text.contains("\n") and not c.final_text.contains("\u0007")
				and (c.final_text == "" or bad is String), "a final line with a bad value is empty or clean: %s" % str(c.final_text.left(12)))
	for part in ["g", "p", "s", "m"]:   # The pieces of the result: the same bad values, no error, empty or clean.
		for bad in [{}, [1], null, "x".repeat(100000), "A\nB\tC\u0007D"]:
			c._handle({"t": "final", "v": "1ST   A   1", part: bad}, now)
			var got: String = {"g": c.final_game, "p": c.final_place, "s": c.final_score, "m": c.final_medal}[part]
			_check(got.length() <= 60 and not got.contains("\n") and not got.contains("\u0007") and (got == "" or bad is String)
					and (part != "m" or got == ""), "final piece %s with a bad value is empty or clean: %s" % [part, str(got.left(12))])
	for part in ["n", "k", "x"]:   # The place and the score as data (issue #470): a bad value is no error and `p` and `s` stay.
		for bad in [{}, [1], null, "x".repeat(100000), "A\nB", 1.0e300, -5, [[]], [null, null], ["a", {}]]:
			c._handle({"t": "final", "v": "1ST   A   1", "p": "1ST", "s": "1", part: bad}, now)
			_check(c.final_place.length() <= 60 and c.final_score.length() <= 60 and not c.final_place.contains("\n")
					and not c.final_score.contains("\n") and c.final_place != "" and c.final_score != "",
					"final data %s with a bad value gives a clean place and score: %s / %s"
					% [part, c.final_place.left(12), c.final_score.left(12)])
	c._handle({"t": "final", "v": "x", "p": "1ST", "s": "1", "n": 2, "k": "result.points", "x": [1.0e300, 5, 6, 7, 8]}, now)
	_check(c.final_score.length() <= 60 and c.final_place == "2ND", "a huge number or too many numbers: a clean score, no error")
	c._handle({"t": "final"}, now)
	_check(c.final_text == "", "a final without a value is an empty line")
	c._handle({"t": "final", "v": "A\nB"}, now)
	_check(c.final_text == "A B", "line breaks in a final line become spaces")
	c._handle({"t": "turn", "s": [2], "who": 3, "k": []}, now)
	_check(c.turn_state == 0 and c.turn_who == "" and c.turn_kind == "", "a turn with the wrong types is no turn")
	c._handle({"t": ["x"]}, now)
	c.queue_free()
	await process_frame
