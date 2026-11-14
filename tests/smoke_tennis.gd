extends SceneTree
## Smoke test of Tennis with simulated phones (REQ-TN-*). Run:
##   godot --headless --path . --script tests/smoke_tennis.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const MedalView = preload("res://scripts/ui/medal_view.gd")

var _fails := 0
var _checks := 0


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
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


## Skips the countdown (only the solo match has one, REQ-GM-35) and keeps the tick gap short, so that swings count.
func _go(game: Control) -> void:
	if game._clock.is_counting():
		game._clock.time = -0.01
	game._game_tick(0.02)
	game._game_tick(0.016)


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var Tennis = load("res://scripts/game/tennis/tennis_game.gd")
	var GameSettings = load("res://scripts/game/game_settings.gd")
	var app: Node = root.get_node("App")
	app.set_language("en", false)   # The texts are checked in English, whatever language this machine saved.
	GameSettings.clear()
	var clients: Array = await _join(app, 2)

	# The settings view has Difficulty and Scoring, Real by default (REQ-TN-12).
	app.go_game_settings("tennis")
	await _frames(4)
	for c in clients:   # The safety card of a swing game: every phone taps OK before Start works (REQ-GM-102).
		c.send_swing_ok()
	await _frames(6)
	var sv: Control = app.current_screen()
	_check(sv.rows.size() == 2 and sv.rows[1].value == "real" and not sv.start_button.disabled,
			"Tennis opens the settings view with Scoring on Real (REQ-TN-12)")
	sv.start()
	await _frames(4)
	var game: Control = app.current_screen()
	_check(is_instance_of(game, Tennis) and game.scoring == "real" and game.difficulty == "medium" and game.best_key() == "",
			"Start opens the game with Real scoring")
	_check(not game._has_countdown() and not game._clock.is_counting() and not game.play.rules.quick and game.play.chars.size() == 2,
			"a match of 2 players has no countdown (no timer, REQ-GM-35) and 2 players are on the court")
	await _frames(3)   # The pixel layer draws the court and the people without an error.
	# Issue #246: the team panel grows with the names, no name is cut.
	var panel_before: float = game.panel_width()
	_check(panel_before == game.PANEL_W, "short names: the team panel has its least width (%.0f px)" % panel_before)
	var old_names: Array[String] = [game.player(0).player_name, game.player(1).player_name]
	game.player(0).player_name = "WWWWWWWWWW"
	game.player(1).player_name = "MMMMMMMMMM"
	var teams_two: bool = game.play.rules.teams[0].size() + game.play.rules.teams[1].size() == 2
	var wide: float = game.panel_width()
	var one_team_needs: float = 250.0 + 14.0 + 30.0 + 4.0 + 10.0 * 32.0
	_check(teams_two and wide >= one_team_needs,
			"names of 10 letters: the team panel is %.0f px, at least %.0f px (nothing is cut)" % [wide, one_team_needs])
	game.player(0).player_name = old_names[0]
	game.player(1).player_name = old_names[1]

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
	game._on_swing({"power": 0.8, "down": true, "forward_dir": Vector3.ZERO, "hit_age_ms": 0.0}, server)
	_check(game.play.phase == game.Match.Phase.TOSS, "a swing right after a pause does nothing")
	game._tick_ms = Time.get_ticks_msec()
	# A swing that misses the serve (not from top to bottom) still shows the serve pose: the racket goes high, not a plain hit
	# (owner, 2026-11-14, issue #419).
	game._on_swing({"power": 0.8, "down": false, "forward_dir": Vector3.ZERO, "hit_age_ms": 0.0}, server)
	_check(game.play.phase == game.Match.Phase.TOSS and game._look_of(server, game.play.chars[server]).pose == "serve",
			"a missed swing during the toss shows the serve pose")
	game._on_swing({"power": 0.8, "down": true, "forward_dir": Vector3.ZERO, "hit_age_ms": 0.0}, server)
	_check(game.play.phase == game.Match.Phase.RALLY and game.play.serve_ball, "a swing down at the top of the toss serves")
	_check(game._look_of(server, game.play.chars[server]).pose == "serve", "the serve shows the serve pose")

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
	_check(MedalView.tiers_in(solo._menu_box).is_empty(), "the machine rally of one player has no medal (REQ-GM-73)")

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
