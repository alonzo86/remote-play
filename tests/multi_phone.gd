extends SceneTree
## Games with 3 and 4 simulated phones (real clients on loopback that stream sensor values and listen to the TV). It replaces
## the "play with 2, 3 and 4 phones" part of the manual tests that a machine can check: every phone gets the buzz at GO, every
## phone is told its own place and the number of ranked players (REQ-FL-67), a tie gives the same place, and a phone that
## leaves takes its player out and the round goes on, or ends when too few are left (REQ-GM-20, 21). It also measures the logic
## cost of one frame with 4 players. Run by tests/run_all.sh and tools/coverage.sh:
##   godot --headless --path . --script tests/multi_phone.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Slow = preload("res://tests/slow_run.gd")

## id -> [script, props, min players]. The maze has no score and the race ranks by distance, so they only get the leave check.
const GAMES := {
	"paint_grab": ["res://scripts/game/paint_grab/paint_grab_game.gd", {"difficulty": "medium"}, 1],
	"sumo_bumpers": ["res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd", {"difficulty": "medium"}, 2],
	"asteroid_blast": ["res://scripts/game/asteroid_blast/asteroid_blast_game.gd", {"difficulty": "medium"}, 1],
	"snowball_splat": ["res://scripts/game/snowball_splat/snowball_splat_game.gd", {"difficulty": "medium"}, 1],
	"whack_a_mole": ["res://scripts/game/whack_a_mole/whack_a_mole_game.gd", {"difficulty": "medium"}, 1],
	"marble_race": ["res://scripts/game/marble_race/marble_race.gd", {"track_choice": "3", "difficulty": "easy"}, 1],
	"mini_golf": ["res://scripts/game/mini_golf/mini_golf_game.gd", {"difficulty": "medium", "holes": "1"}, 1],
	"bowling": ["res://scripts/game/bowling/bowling_game.gd", {"difficulty": "medium"}, 1],
	"tennis": ["res://scripts/game/tennis/tennis_game.gd", {"difficulty": "medium"}, 1],
	"sheep_herding": ["res://scripts/game/sheep_herding/sheep_herding_game.gd", {"difficulty": "medium"}, 1],
	"maze": ["res://scripts/game/maze/maze_game.gd", {}, 1],
}
const FRAME_BUDGET_MS := 12.0   # Logic of one frame with 4 players, headless. Generous for a CI machine.

var _checks := 0
var _fails := 0
var _seq := [0, 0, 0, 0]
var _clients: Array = []
var _buzzes: Array = [[], [], [], []]
var _buzz_at: Array = [[], [], [], []]   # [ms, tick] of each buzz
var _sounds: Array = []                  # [id, tick] of each effect that started on the TV
var _watch_song := ""                    # The song id that _stream() waits for
var _song_ms := -1                       # Tick when that song was first playing
## Games with a round time: the last 5 seconds tick (REQ-FL-65).
const TIMED := ["paint_grab", "snowball_splat", "whack_a_mole", "sheep_herding"]
## Games with a visible timer start with the 3 s countdown; the others start at once (REQ-GM-35, decision of 2026-10-21).
## Tennis has a timer only alone against the machine (`_solo_tennis`), so it has none here.
const COUNTDOWN_GAMES := ["paint_grab", "snowball_splat", "whack_a_mole", "marble_race", "maze", "sheep_herding"]
## The games without a countdown that buzz the first player at the start of the first turn (the turn buzz, 60 ms).
const TURN_BUZZ_GAMES := ["bowling", "mini_golf"]


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


## The first `n` phones stream a flat phone for `seconds`.
func _stream(seconds: float, n: int) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in n:
			if is_instance_valid(_clients[i]):
				_clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO,
						Vector3(0, 0, 9.81), 0, 0, Vector2.ZERO))
				_seq[i] += 1
		if _watch_song != "" and _song_ms < 0:
			var sound: Node = root.get_node("Sound")
			if sound._music.playing and String(sound._music.get_meta("id", "")) == _watch_song:
				_song_ms = Time.get_ticks_msec()
		await _frames(1)


func _join(app: Node, n: int) -> void:
	for i in n:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.haptic_requested.connect(func(ms: int) -> void:
			_buzzes[i].append(ms)
			_buzz_at[i].append([ms, Time.get_ticks_msec()]))
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
	var sound: Node = root.get_node("Sound")
	sound.skip_without_output = false   # The headless run has no audio device; the songs are made anyway (18.5b).
	sound.sfx_played.connect(func(id: String) -> void: _sounds.append([id, Time.get_ticks_msec()]))
	await _join(app, 4)
	_check(app.server.connected_slots().size() == 4, "4 simulated phones joined")
	for id in GAMES:
		await _round(app, id, 4)
	# 3 phones: the games that change their shape with the number of players (2 against 1 in Tennis, a match of 2 in Sumo).
	for id in ["tennis", "sumo_bumpers", "mini_golf", "bowling"]:
		await _round(app, id, 3)
	await _solo_tennis(app)
	for c in _clients:
		if is_instance_valid(c):
			c.leave()


## One game with the first `n` phones: the countdown (timed games only) and the buzz at GO, the places, a tie, the cost of
## a frame, one phone leaves.
func _round(app: Node, id: String, n: int) -> void:
	# Phones that left an earlier round come back.
	await _rejoin(app, 4)
	_buzzes = [[], [], [], []]
	_buzz_at = [[], [], [], []]
	_sounds.clear()
	_song_ms = -1
	_watch_song = id
	root.get_node("Sound")._streams.erase(id)   # A cold start: the song is made behind the countdown (REQ-FL-65a).
	var spec: Array = GAMES[id]
	var state := "%s with %d phones" % [id, n]
	# Only the first n phones play: the others leave first.
	for i in range(n, 4):
		_clients[i].leave()
	await _frames(10)
	var started_ms := Time.get_ticks_msec()
	app.go(load(spec[0]), spec[1].duplicate())
	await _frames(3)
	await _stream(1.5, n)
	var before := 0
	for i in n:
		before += _buzzes[i].size()
	await _stream(3.2, n)
	# The song is made in steps of 3 ms a frame. The instrumented copy is slow and makes it later: wait for it (REQ-FL-65a).
	var waited := Time.get_ticks_msec()
	while _song_ms < 0 and Time.get_ticks_msec() - waited < (20000 if Slow.instrumented() else 0):
		await _stream(0.2, n)
	_watch_song = ""
	var all_buzzed := true
	var buzzed_60 := 0
	for i in n:
		all_buzzed = all_buzzed and _buzzes[i].count(60) >= 1
		buzzed_60 += 1 if _buzzes[i].count(60) >= 1 else 0
	if id in COUNTDOWN_GAMES:
		_check(before == 0, "%s: no buzz in 3, 2, 1" % state)
		_check(all_buzzed, "%s: every phone gets the 60 ms buzz at GO" % state)
		_countdown_sounds(id, state, n)
	else:
		_no_countdown(id, state, buzzed_60, started_ms)
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
	if n == 4 and id in TIMED:
		await _time_ticks(game, state)
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
	# Sheep Herding is a team game: every phone is told the same number of sheep and no place (REQ-SH-13).
	if game.get_script().resource_path.ends_with("sheep_herding_game.gd"):
		game.open_menu("minigame.end_game_ask", [["minigame.resume", game.close_menu]])
		await _stream(0.6, n)
		var same_text := true
		for k in n:
			same_text = same_text and _clients[k].score_text == "0 / 11" and _clients[k].score_rank == 0
		_check(same_text, "%s: every phone shows 0 / 11 and no place (a team game)" % state)
		return
	# Tennis ranks teams, not players (REQ-TN-13): r4_tennis.gd and smoke_tennis_phones.gd check it.
	if n > 2 and game.has_method("places"):
		_check(true, "%s: the places are per team (checked in the tennis suites)" % state)
		return
	# The ticks stop, so they do not change the scores.
	game.open_menu("minigame.end_game_ask", [["minigame.resume", game.close_menu]])
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


## 18.5a, 5b, 6b: the countdown sounds, the start of the song and the buzz that goes with the GO sound.
func _countdown_sounds(id: String, state: String, n: int) -> void:
	var sound: Node = root.get_node("Sound")
	var beeps: Array = _sounds.filter(func(x): return x[0] == "count" or x[0] == "go").map(func(x): return x[0])
	_check(beeps == ["count", "count", "go"], "%s: the countdown sounds are 2 count beeps, then GO (got %s)" % [state, str(beeps)])
	var go_ms := -1
	for x in _sounds:
		if x[0] == "go":
			go_ms = x[1]
	var song_limit := int(Slow.limit(1000.0, 15.0))
	_check(_song_ms >= 0 and go_ms > 0 and _song_ms - go_ms <= song_limit and sound.wanted_music == id and id != "menu",
			"%s: the song of the game starts %d ms after GO (%d or less)" % [state, _song_ms - go_ms, song_limit])
	var worst := 0
	for i in n:
		for b in _buzz_at[i]:
			if b[0] == 60:
				worst = maxi(worst, absi(int(b[1]) - go_ms))
	_check(go_ms > 0 and worst <= 100, "%s: the GO buzz comes within 100 ms of the GO sound (%d ms on loopback)" % [state, worst])


## REQ-GM-35: a game without a timer has no countdown: no count or go sound, no start buzz on every phone (the games with
## turns buzz the player on turn only), and the song of the game starts with the play, not after 3 s.
func _no_countdown(id: String, state: String, buzzed_60: int, started_ms: int) -> void:
	var sound: Node = root.get_node("Sound")
	var beeps: Array = _sounds.filter(func(x): return x[0] == "count" or x[0] == "go").map(func(x): return x[0])
	_check(beeps.is_empty(), "%s: no timer, so no countdown sounds (got %s)" % [state, str(beeps)])
	var allowed := 1 if id in TURN_BUZZ_GAMES else 0
	_check(buzzed_60 <= allowed,
			"%s: no start buzz on every phone: %d phone(s) buzzed 60 ms (%d at most)" % [state, buzzed_60, allowed])
	_check(_song_ms >= 0 and sound.wanted_music == id and id != "menu",
			"%s: the song of the game starts with the play (%d ms after the start)" % [state, _song_ms - started_ms])


## Tennis alone against the machine shows the solo clock, so it has the 3 s countdown and the GO buzz (REQ-GM-35).
func _solo_tennis(app: Node) -> void:
	await _rejoin(app, 4)
	_buzzes = [[], [], [], []]
	_sounds.clear()
	for i in range(1, 4):
		_clients[i].leave()
	await _frames(10)
	app.go(load(GAMES.tennis[0]), GAMES.tennis[1].duplicate())
	await _frames(3)
	await _stream(1.5, 1)
	var before: int = _buzzes[0].size()
	await _stream(3.2, 1)
	var beeps: Array = _sounds.filter(func(x): return x[0] == "count" or x[0] == "go").map(func(x): return x[0])
	_check(before == 0, "tennis with 1 phone: no buzz in 3, 2, 1")
	_check(beeps == ["count", "count", "go"],
			"tennis with 1 phone: the solo clock gives the countdown 2 count beeps, then GO (got %s)" % str(beeps))
	_check(_buzzes[0].count(60) >= 1, "tennis with 1 phone: the phone gets the 60 ms buzz at GO")


## 18.5e: a timed round ticks once in each of the last 5 seconds. The clock is moved to 6.5 s before the end and runs 6 seconds.
func _time_ticks(game: Control, state: String) -> void:
	var clock = game.get("_round")
	if game.is_paused():
		game.close_menu()
	_sounds.clear()
	clock.time = clock.duration - 6.5
	var was_processing: bool = game.is_processing()
	game.set_process(false)   # Only the steps below move the clock: a slow frame must not end the round.
	for k in 6:
		game._process(1.0)
		await create_timer(0.06).timeout   # The same effect twice in 40 ms is one sound.
	game.set_process(was_processing)
	clock.time = 1.0   # Back near the start, so that the round does not end in the checks that follow.
	var ticks: int = _sounds.filter(func(x): return x[0] == "time_low").size()
	_check(ticks == 5 and not game.is_over, "%s: the last 5 s tick 5 times, once each second (got %d)" % [state, ticks])
