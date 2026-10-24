extends SceneTree
## Smoke test of Star Shield with three simulated phones (REQ-AB-*). Run:
##   godot --headless --path . --script tests/smoke_asteroid.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

var _fails := 0
var _checks := 0
var _seq := [0, 0, 0]


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


func _stream(clients: Array, seconds: float, accel: Array) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in clients.size():
			clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO, accel[i], 0, 0,
					Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var Blast = load("res://scripts/game/asteroid_blast/asteroid_blast_game.gd")
	var Field = load("res://scripts/game/asteroid_blast/space_field.gd")
	var GameSettings = load("res://scripts/game/game_settings.gd")
	var app: Node = root.get_node("App")
	GameSettings.clear()
	var clients: Array = []
	for i in 3:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame
	var flat := Vector3(0, 0, 9.81)
	var lean := deg_to_rad(15.0)
	var right := Vector3(-sin(lean), 0, cos(lean)) * 9.81
	var left := Vector3(sin(lean), 0, cos(lean)) * 9.81
	await _stream(clients, 0.5, [flat, flat, flat])

	# The game has the settings view with Difficulty only (REQ-AB-20).
	app.go_game_settings("asteroid_blast")
	await _frames(4)
	var sv: Control = app.current_screen()
	_check(sv.rows.size() == 1 and sv.rows[0].value == "medium" and not sv.start_button.disabled,
			"Star Shield opens the settings view with Difficulty on Medium and Start works (REQ-AB-20)")
	sv.start()
	await _frames(4)
	var med: Control = app.current_screen()
	_check(is_instance_of(med, Blast) and med.difficulty == "medium" and med.best_key() == "asteroid_blast|medium",
			"Start opens the game on Medium with its personal best key (REQ-AB-18)")

	app.go(Blast, {"difficulty": "medium"})
	await _frames(3)
	var game: Control = app.current_screen()
	var xs: Array = game.field.ships.values().map(func(s): return s.x)
	_check(game.participants.size() == 3 and game.field.ships.size() == 3 and xs[0] < xs[1] and xs[1] < xs[2],
			"3 ships start in a row along the bottom (REQ-AB-1)")
	var x0: float = game.field.ships[0].x
	await _stream(clients, 1.0, [right, left, flat])
	var moved_1: float = game.field.ships[1].x
	_check(game.field.phase_time > 0.5 and absf(game.field.ships[0].x - x0) > 20.0 and game.field.ships[2].x == xs[2],
			"there is no countdown: the wave runs and the ships steer in the first second (REQ-GM-35, REQ-AB-2)")
	_check((game.field.ships[0].x - x0 > 0.0) != (moved_1 - xs[1] > 0.0),
			"tilting right and left move the ships in opposite directions (REQ-AB-2)")
	await _stream(clients, 1.0, [flat, flat, flat])
	_check(game.field.beams.size() > 0, "the ships fire by themselves (REQ-AB-4)")

	# Banners and the hint (REQ-AB-16): one banner at a time, the hint only at the start.
	var phase_was: int = game.field.phase
	var phase_time_was: float = game.field.phase_time
	var time_was: float = game._time
	game.field.phase = Field.Phase.WAVE
	game.field.phase_time = 0.5
	var start_banner: String = game.banner()
	game.field.phase_time = 3.0
	var no_banner: String = game.banner()
	game.field.phase = Field.Phase.REST
	game.field.phase_time = 0.5
	var rest_banner: String = game.banner()
	game._end_left = 1.0
	var end_banner: String = game.banner()
	_check(start_banner == "wave_n" and no_banner == "" and rest_banner == "wave_clear" and end_banner == "all_ships_gone",
			"one banner at a time: Wave N, none, Wave clear, All ships are gone: %s %s %s %s"
			% [start_banner, no_banner, rest_banner, end_banner])
	game._end_left = -1.0
	game._time = 1.0
	var hint_early: bool = game.hint_shown()
	game._time = game.HINT_TIME + 0.1
	var hint_late: bool = game.hint_shown()
	game._time = 1.0
	game._end_left = 1.0
	var hint_end: bool = game.hint_shown()
	_check(hint_early and not hint_late and not hint_end,
			"the hint shows for the first 5 s of the game, not later and not at the end")
	game._end_left = -1.0
	game.field.phase = phase_was
	game.field.phase_time = phase_time_was
	game._time = time_was

	# Events: sounds, haptics and explosions (REQ-AB-15).
	game._booms.clear()
	game.field.events.clear()
	for e in [{"t": "kill", "x": 100.0, "y": 100.0, "size": 2, "slot": 0}, {"t": "shield_pop", "x": 1.0, "y": 1.0, "slot": 1},
			{"t": "ship_lost", "x": 5.0, "y": 5.0, "slot": 2}, {"t": "ship_back", "x": 5.0, "y": 5.0, "slot": 2}, {"t": "upgrade_taken",
					"slot": 0}, {"t": "wave_end"}, {"t": "wave_start"}]:
		game._on_event(e)
	_check(game._booms.size() == 3 and is_equal_approx(game._booms[0].scale, game.BOOM_SCALE[2])
			and is_equal_approx(game._booms[1].scale, 0.8) and is_equal_approx(game._booms[2].scale, 1.6),
			"kills, shield pops and lost ships make explosions (REQ-AB-15)")

	# The score goes to the board, the phones and the leader chip (REQ-GM-46).
	game.field.scores[0] = 120
	game.field.scores[1] = 40
	game._game_tick(0.016)
	await _frames(3)
	_check(game._board.score(0) == 120.0 and clients[0].score_rank == 1 and clients[0].score_text == "120"
			and clients[1].score_rank == 2
			and game.leader_text() == "120", "each phone gets its place and its points; the leader chip shows the best score (REQ-AB-16)")

	# A player leaves (REQ-AB-19).
	game._on_player_left(2)
	_check(not game.field.ships.has(2) and not game._board.has(2), "a player that leaves takes its ship away (REQ-AB-19)")

	# The end (REQ-AB-14): the game is over 2 s after the last ship is gone.
	game.field.ships[0].alive = false
	game._game_tick(0.016)
	_check(not game.is_over and game.field.alive_count() == 1, "while one ship flies the game goes on")
	game.field.ships[1].alive = false
	game._game_tick(0.016)
	_check(game._end_left > 0.0 and not game.is_over, "when the last ship is gone the sky goes on for 2 s")
	game._game_tick(2.1)
	await _frames(3)
	var buttons: Array = game.menu_buttons().map(func(b): return b.text)
	var labels: Array = []
	for l in game._menu_box.find_children("*", "Label", true, false):
		labels.append(l.text)
	_check(game.is_over and buttons == ["minigame.restart", "minigame.new_game", "minigame.back_to_menu"]
			and labels[0] == "SIM0 WINS!",
			"the result menu names the player with most points: %s %s" % [str(buttons), str(labels)])

	# One player: the wave in the title and no medal (REQ-AB-14, REQ-GM-73).
	app.go(Blast, {"difficulty": "easy"})
	await _frames(3)
	var solo: Control = app.current_screen()
	solo.participants.clear()
	solo.participants.append(0)
	solo._on_player_left(1)
	solo._on_player_left(2)
	solo.field.ships[0].alive = false
	solo.field.scores[0] = 1000
	solo.field.wave = 4
	solo._game_tick(0.016)
	solo._game_tick(2.1)
	await _frames(3)
	var solo_labels: Array = []
	for l in solo._menu_box.find_children("*", "Label", true, false):
		solo_labels.append(l.text)
	_check(solo.is_over and solo_labels.has("REACHED WAVE 4"), "one player sees the wave that was reached: %s" % str(solo_labels))

	# Equal points: the title says Tie (REQ-AB-14).
	app.go(Blast, {"difficulty": "medium"})
	await _frames(3)
	var tie: Control = app.current_screen()
	tie._on_player_left(2)
	tie.field.scores[0] = 80
	tie.field.scores[1] = 80
	tie.field.ships[0].alive = false
	tie.field.ships[1].alive = false
	tie._game_tick(0.016)
	tie._game_tick(2.1)
	await _frames(3)
	var tie_labels: Array = []
	for l in tie._menu_box.find_children("*", "Label", true, false):
		tie_labels.append(l.text)
	_check(tie.is_over and tie_labels.has("TIE!"), "equal points end with a Tie title: %s" % str(tie_labels))

	# The layout (REQ-AB-16): the play area is inside the margin at two sizes.
	var fits_ok := true
	for res in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = res
		await _frames(4)
		var fit: Dictionary = tie._fit()
		var area_end: Vector2 = fit.origin + Field.REF_AREA * float(fit.k)
		var unit: float = tie.size.y / 1080.0
		fits_ok = fits_ok and fit.origin.x >= 59.0 and area_end.x <= tie.size.x - 59.0 and fit.origin.y >= 149.0 * unit - 1.0 \
				and area_end.y <= tie.size.y - 59.0 * unit + 1.0
	_check(fits_ok, "the play area is inside the margin and under the HUD at 1280x720 and 1920x1080 (REQ-AB-16)")
	root.size = Vector2i(1920, 1080)
	await _frames(3)

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
