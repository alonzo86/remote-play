extends SceneTree
## Smoke test of Pin Pals with two simulated phones (REQ-BW-*). Run:
##   godot --headless --path . --script tests/smoke_bowling.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Lang = preload("res://scripts/core/lang.gd")

var _fails := 0
var _checks := 0
var _seq := [0, 0]


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


## Streams one acceleration per phone for `seconds`. A phone that lies flat reads 9.81 on z; a push adds to it.
func _stream(clients: Array, seconds: float, accel: Array) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in clients.size():
			clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO, accel[i], 0, 0,
					Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


func _labels(game: Control) -> Array:
	var labels: Array = []
	for l in game._menu_box.find_children("*", "Label", true, false):
		labels.append(l.text)
	return labels


## Skips the banner so that a test goes straight to the next turn (there is no countdown, REQ-GM-35).
func _to_turn(game: Control) -> void:
	game._game_tick(0.016)
	game._game_tick(3.1)


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var Bowling = load("res://scripts/game/bowling/bowling_game.gd")
	var GameSettings = load("res://scripts/game/game_settings.gd")
	var app: Node = root.get_node("App")
	GameSettings.clear()
	var clients: Array = []
	for i in 2:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame
	var flat := Vector3(0, 0, 9.81)
	await _stream(clients, 0.5, [flat, flat])

	# The settings view has Difficulty and Rails (REQ-BW-16, 17).
	app.go_game_settings("bowling")
	await _frames(4)
	var sv: Control = app.current_screen()
	_check(sv.rows.size() == 2 and sv.rows[0].value == "medium" and sv.rows[1].value == "off" and not sv.start_button.disabled,
			"Pin Pals opens the settings view with Difficulty on Medium and Rails off (REQ-BW-16, 17)")
	sv.start()
	await _frames(4)
	var med: Control = app.current_screen()
	_check(is_instance_of(med, Bowling) and med.difficulty == "medium" and med.rails == "off" and med.best_key() == "bowling|medium",
			"Start opens the game with its personal best key (REQ-BW-19)")
	app.go(Bowling, {"difficulty": "easy", "rails": "on"})
	await _frames(3)
	var rail_game: Control = app.current_screen()
	_check(rail_game.best_key() == "", "with rails there is no personal best (REQ-BW-19)")

	# No countdown (REQ-GM-35): the first player's turn starts at once (REQ-BW-3).
	app.go(Bowling, {"difficulty": "medium"})
	await _frames(3)
	var game: Control = app.current_screen()
	_check(game.participants.size() == 2 and not game._has_countdown() and game.rules.current_slot() == 0
			and game.phase == game.Phase.AIM and game.sim.standing_count() == 10,
			"the game starts at once with no countdown: the first phone aims at 10 pins (REQ-GM-35, REQ-BW-3, REQ-BW-4)")
	await _stream(clients, 0.5, [flat, flat])

	# The phones know whose turn it is (REQ-BW-14).
	_check(clients[0].turn_state == 1 and clients[1].turn_state == 2 and clients[1].turn_who == game.player(0).player_name,
			"the phone on turn gets YOUR TURN and the other phone gets the name of the player on turn (REQ-BW-14)")

	# The same turn message is not sent again (REQ-BW-14).
	var turn_events := []
	clients[1].score_changed.connect(func(): turn_events.append(clients[1].turn_state))
	app.server.send_turn(1, 2, game.player(0).player_name)
	app.server.send_turn(1, 2, game.player(0).player_name)
	await _stream(clients, 0.2, [flat, flat])
	_check(turn_events.is_empty() and clients[1].turn_state == 2, "a turn message that was sent already is not sent again")

	# Turning the phone does not move the aim of the phone that is not on turn; a swing of the wrong phone does nothing.
	await _stream(clients, 0.4, [flat, flat + Vector3(0, 9, 0)])
	await _stream(clients, 0.4, [flat, flat + Vector3(0, -15, 0)])
	await _stream(clients, 0.8, [flat, flat])
	_check(game.phase == game.Phase.AIM and game.rules.current_slot() == 0,
			"a swing of the phone that is not on turn does nothing (REQ-BW-3)")

	# A finger on the aim strip moves the ball and the aim stays when the finger lifts (REQ-BW-4).
	var p0 = game.player(0)
	for i in 3:
		clients[0].send_sensor(Protocol.encode_sensor(_seq[0], Time.get_ticks_msec(), Vector3.ZERO, flat, 0, Protocol.FLAG_TOUCH,
				Vector2(1.0, 0.5)))
		_seq[0] += 1
		await _frames(2)
	_check(p0.touching and is_equal_approx(game._aim, 1.0), "a finger at the right end of the strip aims to the right (REQ-BW-4)")
	await _stream(clients, 0.2, [flat, flat])
	_check(not p0.touching and is_equal_approx(game._aim, 1.0), "the aim stays where the finger lifted (REQ-BW-4)")

	# A swing with a finger on the strip throws nothing and shows the hint to lift the finger (REQ-BW-5).
	var swing_back := flat + Vector3(0, 9, 0)
	var swing_fwd := flat + Vector3(0, -18, 0)
	var seq := [[swing_back, 0.3], [swing_fwd, 0.35], [flat, 0.3]]
	for step in seq:
		var end := Time.get_ticks_msec() + int(step[1] * 1000.0)
		while Time.get_ticks_msec() < end:
			clients[0].send_sensor(Protocol.encode_sensor(_seq[0], Time.get_ticks_msec(), Vector3.ZERO, step[0], 0,
					Protocol.FLAG_TOUCH, Vector2(1.0, 0.5)))
			_seq[0] += 1
			clients[1].send_sensor(Protocol.encode_sensor(_seq[1], Time.get_ticks_msec(), Vector3.ZERO, flat, 0, 0, Vector2.ZERO))
			_seq[1] += 1
			await _frames(1)
	_check(game.phase == game.Phase.AIM and not game.detector.aim_locked and game._lift_left > 0.0,
			"a swing with a finger on the strip does not throw and shows the hint (REQ-BW-5)")
	await _stream(clients, 0.2, [flat, flat])

	# A swing of the phone on turn throws the ball (REQ-BW-5).
	await _stream(clients, 0.3, [flat + Vector3(0, 9, 0), flat])
	_check(game.detector.aim_locked, "the back swing locks the aim (REQ-BW-5)")
	await _stream(clients, 0.35, [flat + Vector3(0, -18, 0), flat])
	await _stream(clients, 0.3, [flat, flat])
	_check(game.phase == game.Phase.ROLL or game.phase == game.Phase.RESULT, "the forward swing throws the ball (REQ-BW-5)")

	# The ball rolls, the pins are counted and the turn goes on (REQ-BW-9, 11).
	var guard := 0
	while game.phase == game.Phase.ROLL and guard < 600:
		await _stream(clients, 0.05, [flat, flat])
		guard += 1
	_check(game.phase == game.Phase.RESULT and game.rules.row_of(0).rolls.size() == 1,
			"the roll ends with a result and one ball in the sheet of phone 1")
	var first_pins: int = game.rules.row_of(0).rolls[0]
	_check(game._banner != "" and game._board.score(0) == float(game.rules.score_of(0)),
			"the banner shows and the score goes to the board (REQ-BW-15)")
	game._after_result()
	await _stream(clients, 0.2, [flat, flat])
	var expect_next: int = 0 if first_pins < 10 and game.rules.current_ball() == 2 else 1
	_check(game.rules.current_slot() == expect_next and game.phase == game.Phase.AIM,
			"after the ball the same phone bowls again, or the next phone after a strike (REQ-BW-1)")

	_check(clients[0].turn_state == (1 if game.rules.current_slot() == 0 else 2), "the turn line follows the turn (REQ-BW-14)")

	# The same player keeps the aim for ball 2; a new player starts in the middle (REQ-BW-4).
	if game.rules.current_slot() == 0:
		_check(is_equal_approx(game._aim, 1.0), "the same player keeps the aim for ball 2 (REQ-BW-4)")
	else:
		_check(is_equal_approx(game._aim, 0.0), "the next player starts in the middle (REQ-BW-4)")

	# A whole game, phone 2 leaves in frame 1 (REQ-GM-21).
	game._on_player_left(1)
	_check(not game._board.has(1) and not game.rules.slots().has(1),
			"a player that leaves is taken out of the rules and the board (REQ-GM-21)")

	# One pin left: the line under the banner has no number to format (the error of 2026-10-20).
	app.go(Bowling, {"difficulty": "medium"})
	await _frames(3)
	var one: Control = app.current_screen()
	_to_turn(one)
	one.sim.set_rack([true, false, false, false, false, false, false, false, false, false])
	one._before = one.sim.standing_mask()
	one._roll_done()
	_check(one._pins_left_line == Lang.t("bowling.pin_left"), "one pin left gives the one pin line: %s" % one._pins_left_line)

	# The end: 12 strikes of one player give 300 and the result menu says so (REQ-BW-1, REQ-GM-73).
	app.go(Bowling, {"difficulty": "easy"})
	await _frames(3)
	var solo: Control = app.current_screen()
	solo._on_player_left(1)
	_to_turn(solo)
	for i in 12:
		solo.sim.set_rack(solo.FULL_RACK)
		solo._before = solo.sim.standing_mask()
		for p in solo.sim.pins:
			p.state = 2
		solo._roll_done()
		solo._after_result()
	_check(solo.rules.game_over() and solo.rules.score_of(0) == 300 and solo.phase == solo.Phase.END,
			"12 strikes end the game with 300 and the lane waits before the menu (REQ-BW-1)")
	solo._game_tick(2.1)
	await _frames(3)
	var labels := _labels(solo)
	_check(solo.is_over and not labels.is_empty(), "the result menu opens after the last ball: %s" % str(labels))

	# Two players with equal scores: Tie (REQ-GM-72).
	app.go(Bowling, {"difficulty": "medium"})
	await _frames(3)
	var tie: Control = app.current_screen()
	_to_turn(tie)
	for i in 24:
		if tie.rules.game_over():
			break
		tie.sim.set_rack(tie.FULL_RACK)
		tie._before = tie.sim.standing_mask()
		for p in tie.sim.pins:
			p.state = 2
		tie._roll_done()
		tie._after_result()
	_check(tie.rules.game_over() and tie.rules.score_of(0) == tie.rules.score_of(1),
			"two players with the same rolls end with the same score")
	tie._game_tick(2.1)
	await _frames(3)
	_check(tie.is_over and _labels(tie).has("TIE!"), "equal scores end with a Tie title: %s" % str(_labels(tie)))

	# The layout is the same at two sizes: the sheet is inside the margin (REQ-BW-12).
	var fits_ok := true
	for res in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = res
		await _frames(4)
		var top: float = tie._sheet_top()
		fits_ok = fits_ok and top > 112.0 and top < 1080.0
	_check(fits_ok, "the score sheet sits under the lane at 1280x720 and 1920x1080 (REQ-BW-12)")
	root.size = Vector2i(1920, 1080)
	await _frames(3)
	app.go_menu()
	await _stream(clients, 0.3, [flat, flat])
	_check(clients[0].turn_state == 0 and clients[1].turn_state == 0 and clients[1].turn_who == "",
			"the menu clears the turn line on the phones (REQ-BW-14)")

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
