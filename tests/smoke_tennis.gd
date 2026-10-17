extends SceneTree
## Smoke test of Tennis with simulated phones (REQ-TN-*). Run:
##   godot --headless --path . --script tests/smoke_tennis.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

var _fails := 0
var _checks := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _labels(game: Control) -> Array:
	var labels: Array = []
	for l in game._menu_box.find_children("*", "Label", true, false):
		labels.append(l.text)
	return labels


func _join(app: Node, n: int) -> Array:
	var clients: Array = []
	for i in n:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame
	return clients


## Skips the countdown and keeps the tick gap short, so that swings count.
func _go(game: Control) -> void:
	game._clock.time = -0.01
	game._game_tick(0.02)
	game._game_tick(0.016)


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var Tennis = load("res://scripts/game/tennis/tennis_game.gd")
	var GameSettings = load("res://scripts/game/game_settings.gd")
	var app: Node = root.get_node("App")
	GameSettings.clear()
	var clients: Array = await _join(app, 2)

	# The settings view has Difficulty and Scoring, Real by default (REQ-TN-12).
	app.go_game_settings("tennis")
	await _frames(4)
	var sv: Control = app.current_screen()
	_check(sv.rows.size() == 2 and sv.rows[1].value == "real" and not sv.start_button.disabled,
			"Tennis opens the settings view with Scoring on Real (REQ-TN-12)")
	sv.start()
	await _frames(4)
	var game: Control = app.current_screen()
	_check(is_instance_of(game, Tennis) and game.scoring == "real" and game.difficulty == "medium" and game.best_key() == "",
			"Start opens the game with Real scoring")
	_check(game._clock.is_counting() and not game.play.rules.quick and game.play.chars.size() == 2,
			"the game starts with a countdown and 2 players on the court")
	await _frames(3)   # The pixel layer draws the court and the people without an error.

	# A press on A of the server tosses the ball, a swing down serves (REQ-TN-9).
	_go(game)
	var server: int = game.play.server_slot()
	game._on_button(Protocol.BTN_A, 1 - server)
	_check(game.play.phase == game.Match.Phase.SERVE, "A of the other phone does not toss")
	game._on_button(Protocol.BTN_A, server)
	_check(game.play.phase == game.Match.Phase.TOSS, "A of the server tosses the ball")
	var apex := 4.6 / 9.81
	for i in int(apex / 0.016):
		game._game_tick(0.016)
	game._tick_ms = 0   # The game was paused a moment ago: a swing now is ignored.
	game._on_swing({"power": 0.8, "down": true, "forward_dir": Vector3.ZERO, "hit_age_ms": 0.0, "tilt": Vector2.ZERO}, server)
	_check(game.play.phase == game.Match.Phase.TOSS, "a swing right after a pause does nothing")
	game._tick_ms = Time.get_ticks_msec()
	game._on_swing({"power": 0.8, "down": true, "forward_dir": Vector3.ZERO, "hit_age_ms": 0.0, "tilt": Vector2.ZERO}, server)
	_check(game.play.phase == game.Match.Phase.RALLY and game.play.serve_ball, "a swing down at the top of the toss serves")

	# The ball in play shows the target ring and the people draw (REQ-TN-5).
	for i in 20:
		game._game_tick(0.016)
	await _frames(2)
	_check(game.play.sim.active and game.play.hitter >= 0, "the other team has a hitter for the ball")

	# A point goes to the board and shows a banner (REQ-TN-10).
	game.play._award(0, "test")
	game._handle_events(game.play.take_events())
	game._sync_board()
	_check(game._banner_left > 0.0 and game._banner.begins_with("POINT"), "a point shows a banner: %s" % game._banner)
	_check(game._wired == [0, 1], "the game remembers the slots it connected")
	await _frames(2)

	# The match ends: the winners are named (REQ-TN-17).
	var rules = game.play.rules
	for i in 12:
		if rules.match_over():
			break
		rules.score_point(0)
	game.play._end_match()
	game._handle_events(game.play.take_events())
	game._sync_board()
	game._game_tick(0.016)
	game._game_tick(2.3)
	await _frames(3)
	_check(game.is_over and not _labels(game).is_empty() and _labels(game).any(func(l: String) -> bool: return l.contains("WINS")),
			"the result menu names the winner: %s" % str(_labels(game)))

	# A player that leaves during the match (REQ-TN-20).
	app.go(Tennis, {"difficulty": "medium", "scoring": "quick"})
	await _frames(3)
	var quick: Control = app.current_screen()
	_check(quick.play.rules.quick, "Quick scoring is passed to the rules")
	_go(quick)
	quick.play._award(0, "test")
	quick._handle_events(quick.play.take_events())
	_check(quick._banner.begins_with("POINT") and quick.play._wait == quick.Match.POINT_PAUSE,
			"with Quick scoring a point shows POINT and the short pause, not GAME")
	quick._on_player_left(1)
	_check(not quick._board.has(1) and not quick.play.chars.has(1), "a player that leaves is taken out of the match")
	quick._game_tick(0.016)
	await _frames(2)

	# 1 player: the machine sends balls, the score is the longest rally (REQ-TN-15).
	clients[1].leave()
	var left_at := Time.get_ticks_msec()
	while app.server.connected_slots().size() > 1 and Time.get_ticks_msec() - left_at < 4000:
		await process_frame
	app.go(Tennis, {"difficulty": "easy"})
	await _frames(3)
	var solo: Control = app.current_screen()
	_go(solo)
	_check(solo.play.solo and solo._board.has(0), "with 1 player the game is a rally against the machine")
	for i in 200:
		solo._game_tick(0.016)
	await _frames(2)
	_check(solo.play.sim.active or solo.play.phase == solo.Match.Phase.SERVE, "the machine feeds the ball")
	solo.play.solo_left = 0.0
	solo._game_tick(0.016)
	solo._game_tick(2.3)
	await _frames(3)
	_check(solo.is_over and not _labels(solo).is_empty(), "the round ends with the result menu: %s" % str(_labels(solo)))

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
