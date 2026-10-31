extends SceneTree
## Smoke test of Tower Builder with simulated phones (REQ-TB-*). Run:
##   godot --headless --path . --script tests/smoke_tower.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Lang = preload("res://scripts/core/lang.gd")
const MedalView = preload("res://scripts/ui/medal_view.gd")

const DT := 1.0 / 60.0

var _fails := 0
var _checks := 0
var _seq := [0, 0, 0, 0]


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


func _stream(clients: Array, seconds: float, accel: Array) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in clients.size():
			clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO, accel[i], 0, 0, Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


func _labels(game: Control) -> Array:
	var r := []
	if game._menu_box != null:
		for l in game._menu_box.find_children("*", "Label", true, false):
			r.append(l.text)
	return r


func _connect(app: Node, n: int) -> Array:
	var clients := []
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


## Steps the game `seconds` of game time, as the base class does every frame.
func _tick(game: Control, seconds: float) -> void:
	var n := int(ceilf(seconds / DT))
	for i in n:
		game._game_tick(DT)


## Ticks until the game is in `phase` (at most `limit` seconds).
func _until(game: Control, phase: int, limit := 10.0) -> bool:
	var t := 0.0
	while game.phase != phase and t < limit:
		game._game_tick(DT)
		t += DT
	return game.phase == phase


## A new turn in which the brick hangs at `dx` px from the middle of the tower.
func _aim(game: Control, dx: float) -> void:
	game._swing_t = 0.0
	game._swing_phase = asin(clampf(dx / game.Stack.SWING_AMP, -1.0, 1.0))


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var Tower = load("res://scripts/game/tower_builder/tower_builder_game.gd")
	var TvGameSettings = load("res://scripts/ui/tv_game_settings.gd")
	var GameSettings = load("res://scripts/game/game_settings.gd")
	var app: Node = root.get_node("App")
	GameSettings.clear()
	var clients: Array = await _connect(app, 3)
	var flat := Vector3(0, 0, 9.81)
	await _stream(clients, 0.5, [flat, flat, flat])

	# The settings view: Difficulty only (REQ-TB-11), and IN and OUT for the players (REQ-GM-104).
	app.go_game_settings("tower_builder")
	await _frames(4)
	var sv: Control = app.current_screen()
	await _stream(clients, 0.4, [flat, flat, flat])
	_check(is_instance_of(sv, TvGameSettings) and sv.rows.size() == 1 and sv.rows[0].value == "medium"
			and not sv.start_button.disabled,
			"Tower Builder opens the settings view with Difficulty on Medium only; Start works with 3 phones (REQ-TB-11)")
	_check(GameSettings.props_for(app.Registry.find("tower_builder")) == {"difficulty": "medium"},
			"the game gets the prop difficulty (REQ-GM-93)")
	var entry: Dictionary = app.Registry.find("tower_builder")
	_check(entry.pad == ["a"] and not app.Registry.has_control(entry, "recenter") and app.Registry.buttons_of(entry) == "a",
			"the pad has button A alone, no B and no RECENTER (Test 30 step 13, REQ-GM-37a, REQ-TB-17)")
	GameSettings.clear()

	# Turns: 3 phones, Medium (5 s).
	app.go(Tower, {"difficulty": "medium", "seed_value": 3})
	await _frames(3)
	var game: Control = app.current_screen()
	game.set_process(false)   # The test steps the game itself, so that the times are exact.
	_check(game.participants == [0, 1, 2] and game.phase == game.Phase.TURN and game.current_slot() == 0
			and game._turn_left > 4.8 and game._turn_left <= 5.0 and game.dropped == 0 and game.stack.height() == 0,
			"3 phones: the first turn is slot 0 with 5 s, and the tower is empty (REQ-TB-4, 11)")
	_check(not game._has_countdown() and clients[0].phase == "playing",
			"no countdown: the first turn starts at once (REQ-GM-35, REQ-TB-2)")
	_check(Lang.f("tower_builder.turn_of", [game.player(0).player_name]).to_upper() == "SIM0'S TURN"
			and Lang.f("tower_builder.brick_n_of", [1, 12]).to_upper() == "BRICK 1 OF 12",
			"the plates say the name of the turn and the brick number (Test 30 step 2b)")
	var rec: RefCounted = load("res://tests/rec_haptics.gd").new()
	game._haptics = rec
	game._on_button(Protocol.BTN_A, 1)
	_tick(game, 0.1)
	_check(game.phase == game.Phase.TURN, "A of a phone that is not the player of the turn does nothing (REQ-TB-5)")
	game._on_button(Protocol.BTN_B, 0)
	_tick(game, 0.1)
	_check(game.phase == game.Phase.TURN, "B does nothing")
	_aim(game, 0.0)
	game._on_button(Protocol.BTN_A, 0)
	_tick(game, DT)
	_check(game.phase == game.Phase.FALL, "A of the player of the turn drops the brick (REQ-TB-5)")
	_check(_until(game, game.Phase.AFTER) and game.stack.height() == 1 and game._board.score(0) == 1.0 and game.dropped == 1,
			"the brick lands on the base, stays, and its player gets a point (REQ-TB-6, 14)")
	_check(absf(float(game.stack.bricks[0].x) - game.Stack.BASE_X) < 40.0,
			"it landed where it was dropped (the swing moved a few frames)")
	_tick(game, game.AFTER_SAFE + 0.1)
	_check(game.phase == game.Phase.TURN and game.current_slot() == 1 and game._turn_left > 4.7 and game._turn_left < 5.0,
			"the next turn is the next phone, with the full turn time (REQ-TB-4)")
	_check(rec.ms_of(1).has(100), "the phone of the next turn buzzes 100 ms (REQ-TB-13): %s" % str(rec.log))
	game._publish_scores()
	await _frames(3)
	_check(clients[0].score_rank == 1 and clients[0].score_text == "1" and game.leader_text() == "1",
			"each phone gets its place and bricks; the leader chip shows the leader (REQ-GM-46)")

	# The time runs out: the brick drops by itself (REQ-TB-11).
	_tick(game, 4.6)
	_check(game.phase == game.Phase.TURN and game._turn_left < 0.4 and game._turn_left > 0.0,
			"after 4.6 s of 5 the turn is still on")
	_tick(game, 0.5)
	_check(game.phase != game.Phase.TURN and game.dropped == 1, "after 5 s the brick drops by itself")
	_until(game, game.Phase.AFTER)
	_tick(game, 2.0)
	_check(game.dropped == 2 and game.current_slot() == 2, "then the turn passes on (REQ-TB-4)")

	# A miss: far from the top brick, the brick falls beside the tower and nobody loses anything (REQ-TB-6, REQ-GM-83).
	var before_h: int = game.stack.height()
	var scores_before := [game._board.score(0), game._board.score(1), game._board.score(2)]
	_aim(game, game.Stack.SWING_AMP)
	game._on_button(Protocol.BTN_A, 2)
	_tick(game, DT)
	_check(_until(game, game.Phase.AFTER) and game.stack.height() == before_h and game.banner_text == "WHOOPS! IT MISSED!"
			and not game._rubble.is_empty(),
			"a brick that misses the tower falls beside it and a banner says so: %s" % game.banner_text)
	_tick(game, 3.0)
	var missed: Dictionary = game._rubble[-1]
	_check(bool(missed.rest) and is_equal_approx(float(missed.y) + game.Stack.BRICK_H, game.Look.RUBBLE_Y),
			"the missed brick lies on the grass")
	_check(absf(float(missed.x) - game.Stack.BASE_X) >= (game.Stack.BASE_W + float(missed.w)) * 0.5 - 8.0,
			"the missed brick slid off the base and does not lie on it (REQ-TB-9)")
	_check([game._board.score(0), game._board.score(1), game._board.score(2)] == scores_before,
			"a miss takes no point away and gives none (REQ-GM-83)")
	_check(game.banner_text == "" and game.phase == game.Phase.TURN and game.current_slot() == 0,
			"the banner goes away with the next turn")

	# A topple: a leaning tower falls and everything above the weak joint with it, nobody loses a point (REQ-TB-9).
	game.stack.clear()
	game.stack.bricks.append({"x": game.Stack.BASE_X, "w": 200.0, "slot": 1})
	game.stack.bricks.append({"x": game.Stack.BASE_X + 90.0, "w": 200.0, "slot": 2})
	game._brick_w = 200.0
	_aim(game, 180.0)
	var points: float = game._board.score(0)
	game._on_button(Protocol.BTN_A, 0)
	_tick(game, DT)
	_check(_until(game, game.Phase.WOBBLE) and game.banner_text == "CRASH! GIGGLE!" and game._pending.size() == 2
			and game.stack.height() == 1,
			"the brick lands too far out: the tower wobbles first, and the bricks above the weak joint wait to fall (REQ-TB-9)")
	game._wobble_t = 0.03
	_check(game.wobble_offset(0, 3) == 0.0 and game.wobble_offset(2, 3) != 0.0,
			"while the tower wobbles the higher bricks lean, and the lowest one does not move")
	_tick(game, game.WOBBLE_TIME + 0.05)
	_check(game.phase == game.Phase.AFTER and game._pending.is_empty() and game.stack.height() == 1 and game._rubble.size() >= 2,
			"after the wobble the bricks fall and lie on the grass; the tower is the lower tower that stands")
	_check(game._board.score(0) == points, "the player of the toppling brick gets no point, and nobody loses one (REQ-GM-83)")
	_tick(game, 3.0)
	var off_base := true
	for r in game._rubble:
		off_base = off_base and absf(float(r.x) - game.Stack.BASE_X) >= (game.Stack.BASE_W + float(r.w)) * 0.5 - 8.0
	_check(off_base, "the toppled bricks slid off the base (REQ-TB-9)")
	var rested := true
	for r in game._rubble:
		rested = rested and bool(r.rest) and is_equal_approx(float(r.y) + game.Stack.BRICK_H, game.Look.RUBBLE_Y)
	_check(rested, "the fallen bricks come to rest on the grass")
	await _frames(3)

	# A player that leaves: the next player gets a new brick at once, and nobody is skipped (REQ-TB-12).
	_check(game.phase == game.Phase.TURN, "a new turn runs")
	var owner: int = game.current_slot()
	game._on_player_left(owner)
	_check(game.phase == game.Phase.TURN and game.current_slot() != owner and is_equal_approx(game._turn_left, 5.0)
			and not game._board.has(owner),
			"the player of the turn leaves: the next player gets a full turn and the leaver is off the board")
	var second: int = game.current_slot()
	_aim(game, 0.0)
	game._on_button(Protocol.BTN_A, second)
	_tick(game, DT)
	var other: int = game._order[(game._cursor + 1) % game._order.size()]
	game._on_player_left(second)   # Leaves while its brick falls.
	_until(game, game.Phase.AFTER)
	_tick(game, 2.0)
	_check(game.phase == game.Phase.TURN and game.current_slot() == other,
			"a player that leaves while the brick falls: the turn goes to the next player, not past it")

	# The end: 12 bricks (REQ-TB-3), the result menu ranks the bricks that stayed (REQ-GM-72, 73).
	game.dropped = game.Stack.TOTAL_BRICKS - 1
	game.stack.clear()
	_aim(game, 0.0)
	game._on_button(Protocol.BTN_A, game.current_slot())
	_tick(game, DT)
	_until(game, game.Phase.AFTER)
	_check(game.dropped == 12 and not game.is_over, "the 12th brick has landed; the game waits for the banner")
	_tick(game, 1.0)
	await _frames(3)
	var menu: Array = game.menu_buttons().map(func(b): return b.text)
	var labels := _labels(game)
	_check(game.is_over and menu == ["minigame.restart", "common.settings", "minigame.back_to_menu"] and labels.size() >= 2,
			"after 12 bricks the result menu opens: %s %s" % [str(menu), str(labels)])
	_check(game.bricks_text(1.0) == "1 BRICK" and game.bricks_text(3.0) == "3 BRICKS", "the score text is a number of bricks")

	# The chips of the players stay inside the 60 px margins with long names, in English and in Hebrew (REQ-TB-19).
	var names := ["Abcdefghij", "Klmnopqrstuvwxyz", "Twinsssssss", "Twinsssssss"]
	var saved: Array = []
	for i in game.participants.size():
		saved.append(game.player(game.participants[i]).player_name)
		game.player(game.participants[i]).player_name = names[i + (4 - game.participants.size())]
	for lang in ["en", "he"]:
		Lang.set_language(lang, root)
		var rects: Array[Rect2] = game.chip_rects()
		var inside := true
		var apart := true
		for i in rects.size():
			inside = inside and Rect2(60, 60, 1800, 960).encloses(rects[i])
			for j in range(i + 1, rects.size()):
				apart = apart and not rects[i].intersects(rects[j])
		_check(rects.size() == game.participants.size() and inside and apart,
				"%s: every chip is inside the margins and no chips overlap: %s" % [lang, str(rects)])
	Lang.set_language("en", root)
	# Four chips with 12-letter names need 1960 px: two rows of two (the 4th chip repeats a phone, only its width matters).
	var real: Array[int] = game.participants.duplicate()
	for s in real:
		game.player(s).player_name = "Twinsssssss"
	var four: Array[int] = [real[0], real[1], real[2], real[0]]
	game.participants = four
	var wide: Array[Rect2] = game.chip_rects()
	game.participants = real
	var in_margins := true
	for r in wide:
		in_margins = in_margins and Rect2(60, 60, 1800, 960).encloses(r)
	_check(wide.size() == 4 and wide[0].position.y == wide[1].position.y and wide[2].position.y == wide[3].position.y
			and wide[0].position.y < wide[2].position.y and in_margins,
			"four long names: two chips in each of two rows, inside the margins: %s" % str(wide))
	for i in game.participants.size():
		game.player(game.participants[i]).player_name = saved[i]

	# The first brick can miss the base: it falls beside the base, the tower stays empty and the game goes on (REQ-TB-6).
	app.go(Tower, {"difficulty": "easy", "seed_value": 3})
	await _frames(3)
	game = app.current_screen()
	game.set_process(false)
	_aim(game, game.Stack.SWING_AMP)
	game._on_button(Protocol.BTN_A, game.current_slot())
	_tick(game, DT)
	_check(_until(game, game.Phase.AFTER) and game.stack.height() == 0 and game.dropped == 1 and not game._rubble.is_empty()
			and game.banner_text == "WHOOPS! IT MISSED!" and not game.is_over,
			"the first brick that misses the base falls beside it, the tower stays empty and the game goes on")

	# Test 30 step 6b: on Easy nobody presses A, and each of 5 turns takes 12 s or less from one plate to the next (REQ-GM-83).
	app.go(Tower, {"difficulty": "easy", "seed_value": 3})
	await _frames(3)
	game = app.current_screen()
	game.set_process(false)
	var longest := 0.0
	var turns := 0
	for n in 5:
		var dropped_before: int = game.dropped
		var who: int = game.current_slot()
		var took := 0.0
		while took < 30.0 and not (game.phase == game.Phase.TURN and (game.dropped != dropped_before or game.current_slot() != who)):
			game._game_tick(DT)
			took += DT
		if took < 30.0:   # A turn that never ends in 30 s is not counted, so the check below fails with the real time.
			turns += 1
		longest = maxf(longest, took)
	_check(turns == 5 and longest <= 12.0,
				"5 turns on Easy with nobody pressing (%d ended): the longest turn takes %.1f s (12 s or less)" % [turns, longest])

	# Solo: one phone plays all 12 bricks and gets no medal (REQ-TB-15, REQ-GM-73).
	clients[2].leave()
	clients[1].leave()
	var left := Time.get_ticks_msec()
	while app.server.connected_slots().size() > 1 and Time.get_ticks_msec() - left < 8000:
		await _stream([clients[0]], 0.1, [flat])
	clients.resize(1)
	app.go(Tower, {"difficulty": "easy", "seed_value": 5})
	await _frames(3)
	game = app.current_screen()
	game.set_process(false)
	_check(game.participants == [0] and game._turn_left > 9.8, "one phone plays alone, with 10 s on Easy (REQ-TB-11)")
	for i in 12:
		game.stack.clear()   # Every brick lands on the empty base: all safe.
		_aim(game, 0.0)
		game._on_button(Protocol.BTN_A, 0)
		_tick(game, DT)
		_until(game, game.Phase.AFTER)
		_tick(game, 1.0)
		if i == 5:
			_check(game._board.score(0) == 6.0, "after 6 safe bricks a solo player has 6 points")
	await _frames(3)
	_check(game.is_over and MedalView.tiers_in(game._menu_box).is_empty(),
			"12 safe bricks of one player: the result menu has no medal (REQ-TB-15, REQ-GM-73)")
	_check(_labels(game)[0] != "" and game.bricks_text(12.0) == "12 BRICKS", "the result list says 12 bricks")

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
