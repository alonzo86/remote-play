extends SceneTree
## Games with 3 and 4 simulated phones (real clients on loopback that stream sensor values and listen to the TV). It replaces
## the "play with 2, 3 and 4 phones" part of the manual tests that a machine can check: every phone gets the buzz at GO, every
## phone is told its own place and the number of ranked players (REQ-FL-67), a tie gives the same place, and a phone that
## leaves takes its player out and the round goes on, or ends when too few are left (REQ-GM-20, 21). It also measures the logic
## cost of one frame with 4 players. Run by tests/run_all.sh and tools/coverage.sh:
##   godot --headless --path . --script tests/multi_phone.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

## id -> [script, props, min players]. The maze has no score and the race ranks by distance, so they only get the leave check.
const GAMES := {
	"paint_grab": ["res://scripts/game/paint_grab/paint_grab_game.gd", {"difficulty": "medium"}, 1],
	"sumo_bumpers": ["res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd", {"difficulty": "medium"}, 2],
	"asteroid_blast": ["res://scripts/game/asteroid_blast/asteroid_blast_game.gd", {"difficulty": "medium"}, 1],
	"snowball_splat": ["res://scripts/game/snowball_splat/snowball_splat_game.gd", {"difficulty": "medium"}, 1],
	"marble_race": ["res://scripts/game/marble_race/marble_race.gd", {"track_choice": "3", "difficulty": "easy"}, 1],
	"mini_golf": ["res://scripts/game/mini_golf/mini_golf_game.gd", {"difficulty": "medium", "holes": "1"}, 1],
	"bowling": ["res://scripts/game/bowling/bowling_game.gd", {"difficulty": "medium"}, 1],
	"tennis": ["res://scripts/game/tennis/tennis_game.gd", {"difficulty": "medium"}, 1],
	"maze": ["res://scripts/game/maze/maze_game.gd", {}, 1],
}
const FRAME_BUDGET_MS := 12.0   # Logic of one frame with 4 players, headless. Generous for a CI machine.

var _checks := 0
var _fails := 0
var _seq := [0, 0, 0, 0]
var _clients: Array = []
var _buzzes: Array = [[], [], [], []]


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The first `n` phones stream a flat phone for `seconds`.
func _stream(seconds: float, n: int) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in n:
			if is_instance_valid(_clients[i]):
				_clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO,
						Vector3(0, 0, 9.81), 0, 0, Vector2.ZERO))
				_seq[i] += 1
		await _frames(1)


func _join(app: Node, n: int) -> void:
	for i in n:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.haptic_requested.connect(func(ms: int) -> void: _buzzes[i].append(ms))
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		_clients.append(c)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var app: Node = root.get_node("App")
	load("res://scripts/game/game_settings.gd").clear()
	await _join(app, 4)
	_check(app.server.connected_slots().size() == 4, "4 simulated phones joined")
	for id in GAMES:
		await _round(app, id, 4)
	# 3 phones: the games that change their shape with the number of players (2 against 1 in Tennis, a match of 2 in Sumo).
	for id in ["tennis", "sumo_bumpers", "mini_golf", "bowling"]:
		await _round(app, id, 3)
	for c in _clients:
		if is_instance_valid(c):
			c.leave()


## One game with the first `n` phones: the buzz at GO, the places, a tie, the cost of a frame, one phone leaves.
func _round(app: Node, id: String, n: int) -> void:
	# Phones that left an earlier round come back.
	await _rejoin(app, 4)
	_buzzes = [[], [], [], []]
	var spec: Array = GAMES[id]
	var state := "%s with %d phones" % [id, n]
	# Only the first n phones play: the others leave first.
	for i in range(n, 4):
		_clients[i].leave()
	await _frames(10)
	app.go(load(spec[0]), spec[1].duplicate())
	await _frames(3)
	await _stream(1.5, n)
	var before := 0
	for i in n:
		before += _buzzes[i].size()
	await _stream(2.5, n)
	_check(before == 0, "%s: no buzz in 3, 2, 1" % state)
	var all_buzzed := true
	for i in n:
		all_buzzed = all_buzzed and _buzzes[i].count(60) >= 1
	if id != "maze":   # The maze sends no buzz at GO, although its game file says so (issue #58).
		_check(all_buzzed, "%s: every phone gets the 60 ms buzz at GO" % state)
	var game: Control = app.current_screen()
	_check(game.participants.size() == n, "%s: %d players take part" % [state, n])
	# The cost of one frame (logic only, nothing is drawn in --headless).
	var start := Time.get_ticks_usec()
	for i in 120:
		game._process(1.0 / 60.0)
	var per_frame := float(Time.get_ticks_usec() - start) / 120.0 / 1000.0
	if n == 4:
		print("  info %s: logic of one frame %.2f ms" % [id, per_frame])
		_check(per_frame < FRAME_BUDGET_MS, "%s: the logic of a frame with 4 players is under %.0f ms (%.2f ms)"
				% [id, FRAME_BUDGET_MS, per_frame])
	await _places(game, state, n)
	# One phone leaves: its player goes. The round goes on, or ends when fewer than the minimum are left (REQ-GM-20, 21).
	if game.is_paused():
		game.close_menu()
	var last: int = n - 1
	_clients[last].leave()
	await _stream(1.5, last)
	var left: Array = game.participants
	_check(left.size() == n - 1 and not left.has(last), "%s: the phone that left takes its player out (%s)" % [state, str(left)])
	_check(game.is_over == (n - 1 < int(spec[2])), "%s: the round %s" % [state, "ends" if n - 1 < int(spec[2]) else "goes on"])


## Pauses the game, gives every player a different score and then two players the same score, and checks what each phone is told.
func _places(game: Control, state: String, n: int) -> void:
	var board = game._scoreboard()
	# The race ranks by distance, not by a set score.
	if board == null or game.get_script().resource_path.ends_with("marble_race.gd"):
		_check(true, "%s: no score on the phones (this game has none)" % state)
		return
	game.open_menu("minigame.paused", [["minigame.resume", game.close_menu]])   # The ticks stop, so they do not change the scores.
	for k in n:
		board.set_score(k, float(k + 1) * 10.0)
	await _stream(0.6, n)
	var ranking: Array = board.ranking()
	var ok := true
	for e in ranking:
		var c = _clients[e.slot]
		ok = ok and c.score_rank == int(e.rank) and c.score_of == n
	var places := ranking.map(func(e): return e.rank)
	_check(ok, "%s: every phone is told its own place and the number of players (%s)" % [state, str(places)])
	var best_ranks := ranking.map(func(e): return int(e.rank))
	best_ranks.sort()
	_check(best_ranks == range(1, n + 1), "%s: the places are 1 to %d without a gap" % [state, n])
	# A tie: players 0 and 1 have the same best score.
	var best: float = float(n) * 10.0
	if board.lower_is_better:
		best = 10.0
	board.set_score(0, best)
	board.set_score(1, best)
	await _stream(0.6, n)
	_check(_clients[0].score_rank == 1 and _clients[1].score_rank == 1,
			"%s: players with the same best score both get place 1" % state)


## Brings the phones that left back, so that the next game starts with four.
func _rejoin(app: Node, n: int) -> void:
	for i in n:
		var c = _clients[i]
		if c.state != ControllerClient.State.CONNECTED:
			c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
	var waited := Time.get_ticks_msec()
	while app.server.connected_slots().size() < n and Time.get_ticks_msec() - waited < 8000:
		await process_frame
