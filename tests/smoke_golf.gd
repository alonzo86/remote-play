extends SceneTree
## Smoke test of Mini Golf with two simulated phones (REQ-MG-*). Run:
##   godot --headless --path . --script tests/smoke_golf.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

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


## Skips the countdown so that a test goes straight to the first turn.
func _to_turn(game: Control) -> void:
	game._clock.time = 0.0
	game._game_tick(0.016)
	game._game_tick(3.1)


## Ends the putt of the player on turn with the ball in the cup, and goes on.
func _hole_out(game: Control) -> void:
	game.sim.in_cup = true
	game.sim.in_water = false
	game._putt_done()
	game._after_result()


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var Golf = load("res://scripts/game/mini_golf/mini_golf_game.gd")
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

	# The settings view has Difficulty and Holes, 3 holes by default (REQ-MG-12).
	app.go_game_settings("mini_golf")
	await _frames(4)
	var sv: Control = app.current_screen()
	_check(sv.rows.size() == 2 and sv.rows[0].value == "medium" and sv.rows[1].value == "3" and not sv.start_button.disabled,
			"Mini Golf opens the settings view with Medium and 3 holes (REQ-MG-12)")
	sv.start()
	await _frames(4)
	var game: Control = app.current_screen()
	_check(is_instance_of(game, Golf) and game.rules.holes == 3 and game.best_key() == "",
			"Start opens the game with 3 holes and no personal best (REQ-MG-1, 15)")
	_check(game.participants.size() == 2 and game._clock.is_counting() and game.rules.current_slot() == 0,
			"the game starts with a countdown and the first phone is on turn (REQ-MG-2)")
	await _frames(3)   # The pixel layer draws the course, and the countdown draws the name tags.
	await _stream(clients, 3.4, [flat, flat])
	_check(not game._clock.is_counting() and game.phase == game.Phase.AIM and game.sim.pos == Vector2(game._hole.tee),
			"after the countdown the first phone aims from the tee (REQ-MG-4)")

	# The phones know whose turn it is, with the words of Mini Golf (REQ-MG-3).
	_check(clients[0].turn_state == 1 and clients[1].turn_state == 2 and clients[1].turn_who == game.player(0).player_name
			and clients[1].turn_kind == "golf", "the other phone gets the name of the player on turn, with the golf words (REQ-MG-3)")

	# A swing of the phone that is not on turn does nothing; a swing of the phone on turn putts (REQ-MG-4, 5).
	await _stream(clients, 0.4, [flat, flat + Vector3(0, 9, 0)])
	await _stream(clients, 0.4, [flat, flat + Vector3(0, -15, 0)])
	await _stream(clients, 0.8, [flat, flat])
	_check(game.phase == game.Phase.AIM and game.rules.current_slot() == 0, "a swing of the phone that is not on turn does nothing")
	await _stream(clients, 0.3, [flat + Vector3(0, 9, 0), flat])
	_check(game.detector.aim_locked, "the back swing locks the aim (REQ-MG-4)")
	await _stream(clients, 0.35, [flat + Vector3(0, -18, 0), flat])
	await _stream(clients, 0.3, [flat, flat])
	_check(game.phase == game.Phase.ROLL or game.phase == game.Phase.RESULT, "the forward swing putts the ball (REQ-MG-5)")
	var guard := 0
	while game.phase == game.Phase.ROLL and guard < 600:
		await _stream(clients, 0.05, [flat, flat])
		guard += 1
	_check(game.phase == game.Phase.RESULT and game.rules.strokes_on_hole(0) == 1 and game.rules.strokes_on_hole(1) == 0,
			"the putt ends with one stroke for phone 1 only (REQ-MG-6)")
	var ball0: Vector2 = game._balls[0]
	_check(ball0.y > Vector2(game._hole.tee).y, "the ball of phone 1 lies further along the hole")
	game._after_result()
	_check(game.rules.current_slot() == 1 and game.sim.pos == Vector2(game._hole.tee),
			"the next phone putts from the tee: every player has a ball of their own (REQ-MG-2)")
	_check(game._ball_of(0) == ball0, "the ball of phone 1 waits where it stopped")

	# Water: one stroke, the ball goes back to the place of the last putt (REQ-MG-9).
	game.sim.in_water = true
	game.sim.finished = true
	game._putt_done()
	_check(game.rules.strokes_on_hole(1) == 1 and game._balls[1] == Vector2(game._hole.tee) and game._banner != "",
			"a ball in the water counts the stroke, goes back to the last spot and shows a splash (REQ-MG-9)")
	game._after_result()
	_check(game.rules.current_slot() == 0 and game.sim.pos == ball0, "after the water the turn goes to the next phone")

	# Both balls in: the card of the hole, then hole 2 (REQ-MG-6, 12).
	_hole_out(game)
	_hole_out(game)
	_check(game.phase == game.Phase.HOLE and game.rules.hole_done(), "when every ball is in the hole the card of the hole shows")
	await _frames(3)
	game._after_hole()
	_check(game.rules.hole_number() == 2 and game.phase == game.Phase.AIM and game.sim.pos == Vector2(game._hole.tee)
			and game._balls.is_empty(), "the next hole starts from its tee with new balls (REQ-MG-12)")
	await _frames(3)   # The second hole has a windmill, a blade and water.

	# A player that leaves is taken out of the rules and the board (REQ-MG-11).
	game._on_player_left(0)
	_check(not game._board.has(0) and not game.rules.slots().has(0) and game.rules.current_slot() == 1,
			"a player that leaves is taken out and the turn goes on (REQ-MG-11)")

	# The end: one hole, one phone, a hole in one. The result menu has the medal (REQ-MG-7, 14).
	app.go(Golf, {"difficulty": "easy", "holes": "1"})
	await _frames(3)
	var solo: Control = app.current_screen()
	solo._on_player_left(1)
	_to_turn(solo)
	_hole_out(solo)
	_check(solo.phase == solo.Phase.HOLE and solo.rules.total(0) == 1, "a hole in one counts one stroke")
	solo._after_hole()
	_check(solo.phase == solo.Phase.END and solo.rules.match_over(), "after the last hole the match is over (REQ-MG-7)")
	solo._game_tick(1.3)
	await _frames(3)
	var labels := _labels(solo)
	_check(solo.is_over and not labels.is_empty(), "the result menu opens: %s" % str(labels))

	# Two players with the same strokes: Tie (REQ-MG-7).
	app.go(Golf, {"difficulty": "medium", "holes": "1"})
	await _frames(3)
	var tie: Control = app.current_screen()
	_to_turn(tie)
	_hole_out(tie)
	_hole_out(tie)
	tie._after_hole()
	tie._game_tick(1.3)
	await _frames(3)
	_check(tie.is_over and _labels(tie).has("TIE!"), "equal strokes end with a Tie title: %s" % str(_labels(tie)))

	app.go_menu()
	await _stream(clients, 0.3, [flat, flat])
	_check(clients[0].turn_state == 0 and clients[1].turn_state == 0 and clients[1].turn_kind == "",
			"the menu clears the turn line on the phones (REQ-MG-3)")

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
