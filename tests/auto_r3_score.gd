extends SceneTree
## The place and the score on the phones (REQ-FL-67), with real clients on the loopback network in Banana Party: every phone is
## told its place and score and the line it draws changes within 1 s of a score change (19.3a), one phone alone gets the score
## without a place (19.3b), and the pause menu leaves the score on the phone until the game goes back to the menu (19.3f).
## What the phone draws is `ControllerPad.score_line(rank, of, text)` with the three values that the client got. Run:
##   godot --headless --path . --script tests/auto_r3_score.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

const BANANA := "res://scripts/game/snowball_splat/snowball_splat_game.gd"
const PAD := "res://scripts/ui/controller_pad.gd"

var _checks := 0
var _fails := 0
var _seq := [0, 0, 0, 0]
var _clients: Array = []
var _app: Node
var _pad: GDScript


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


## One frame in which the first `n` phones send a flat sensor packet (so that the TV keeps them).
func _tick(n: int) -> void:
	for i in n:
		if is_instance_valid(_clients[i]) and _clients[i].state == ControllerClient.State.CONNECTED:
			_clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO, Vector3(0, 0, 9.81), 0, 0,
					Vector2.ZERO))
			_seq[i] += 1
	await process_frame


func _stream(seconds: float, n: int) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await _tick(n)


## The line that the phone `i` draws now under its header row.
func _line(i: int) -> String:
	var c = _clients[i]
	return _pad.score_line(c.score_rank, c.score_of, c.score_text)


## Streams frames until `done.call()` is true or 1.5 s are over. Returns the milliseconds it took, or -1.
func _until(n: int, done: Callable) -> int:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		await _tick(n)
		if done.call():
			return Time.get_ticks_msec() - t0
	return -1


func _join(n: int) -> void:
	for i in n:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
		_clients.append(c)
		var joined := Time.get_ticks_msec()
		while _app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame


func _start_banana(n: int) -> Control:
	_app.go(load(BANANA), {"difficulty": "medium"})
	await process_frame
	var game: Control = _app.current_screen()
	await _stream(4.2, n)   # Through 3, 2, 1: the round plays.
	return game


func _run() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_pad = load(PAD)
	load("res://scripts/game/game_settings.gd").clear()
	await _join(4)
	_check(_app.server.connected_slots().size() == 4, "4 simulated phones joined")
	await _four_phones()
	await _one_phone()
	for c in _clients:
		if is_instance_valid(c):
			c.leave()


## 19.3a and 19.3f: with 4 phones each phone gets its place and its score, and the line follows a change within 1 s; the pause
## menu keeps the score on the phone, the menu of games clears it.
func _four_phones() -> void:
	print("4 phones")
	var game := await _start_banana(4)
	var board = game._scoreboard()
	var slots: Array = game.participants
	_check(slots.size() == 4 and game._round.is_playing(), "Banana Party plays with 4 players")
	var scores := [120.0, 90.0, 60.0, 30.0]
	for k in 4:
		board.set_score(slots[k], scores[k])
	var wanted := ["1ST  120", "2ND  90", "3RD  60", "4TH  30"]
	var took := await _until(4, func() -> bool:
		return [_line(slots[0]), _line(slots[1]), _line(slots[2]), _line(slots[3])] == wanted)
	_check(took >= 0 and took <= 1000, "each phone draws its own line %s within 1 s (took %d ms)" % [str(wanted), took])
	# A change of one score changes the lines of the others at once.
	board.set_score(slots[3], 200.0)
	var wanted2 := ["2ND  120", "3RD  90", "4TH  60", "1ST  200"]
	var took2 := await _until(4, func() -> bool:
		return [_line(slots[0]), _line(slots[1]), _line(slots[2]), _line(slots[3])] == wanted2)
	_check(took2 >= 0 and took2 <= 1000, "after a new score the lines are %s within 1 s (took %d ms)" % [str(wanted2), took2])

	# 19.3f: the pause menu (OK on the remote) keeps the score on every phone.
	var before: Array = []
	for i in 4:
		before.append([_clients[slots[i]].score_rank, _clients[slots[i]].score_of, _clients[slots[i]].score_text])
	game.open_menu("minigame.paused", game.pause_entries())
	_check(game.is_paused(), "the pause menu is open")
	await _stream(1.5, 4)
	var after: Array = []
	for i in 4:
		after.append([_clients[slots[i]].score_rank, _clients[slots[i]].score_of, _clients[slots[i]].score_text])
	_check(after == before and before[0][2] == "120", "in the pause menu every phone keeps its place and score: %s" % str(after))
	game.close_menu()
	# Back to the menu of games: the score is gone from every phone.
	_app.go_menu()
	var cleared := await _until(4, func() -> bool:
		var all := true
		for i in 4:
			var c = _clients[slots[i]]
			all = all and c.score_rank == 0 and c.score_of == 0 and c.score_text == "" and _line(slots[i]) == ""
		return all)
	_check(cleared >= 0, "back at the Games screen the score and the place are gone from every phone (%d ms)" % cleared)


## 19.3b: with one phone the line shows the score only, no place.
func _one_phone() -> void:
	print("1 phone")
	for i in range(1, 4):
		_clients[i].leave()
	var gone := Time.get_ticks_msec()
	while _app.server.connected_slots().size() > 1 and Time.get_ticks_msec() - gone < 4000:
		await _tick(1)
	var game := await _start_banana(1)
	var board = game._scoreboard()
	_check(game.participants.size() == 1, "Banana Party plays with 1 player")
	board.set_score(game.participants[0], 7.0)
	var took := await _until(1, func() -> bool: return _clients[0].score_text == "7")
	_check(took >= 0 and took <= 1000, "the phone gets the score 7 within 1 s (took %d ms)" % took)
	var line := _line(0)
	_check(line == "7" and not line.contains("ST") and not line.contains("ND"),
			"the line of the only phone is '%s': the score and no place word" % line)
	_app.go_menu()
	await _stream(0.5, 1)
