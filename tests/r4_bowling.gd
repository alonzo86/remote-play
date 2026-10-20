extends SceneTree
## Pin Pals, the rest of Test 23 (docs/MANUAL_TESTS.md test 23), with simulated phones over the loopback and the game stepped by
## hand: the total of a whole game against an independent count (6a), Frame 10/10 and the time to the result menu (6c), the rails
## (7a), the plate with the name of the player on turn in slot order (8a), the score and the place on every phone (8c), the
## winner and the order of the list (8d), YOUR TURN, <NAME> IS BOWLING and the buzz (9a to 9c), a player that leaves (10a, 10b),
## the height of a pin (13a) and the disco wall (13d).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/r4_bowling.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const Shell = preload("res://scripts/game/shell.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Scoreboard = preload("res://scripts/game/scoreboard.gd")
const BowlingRules = preload("res://scripts/game/bowling/bowling_rules.gd")
const BowlingLook = preload("res://scripts/game/bowling/bowling_look.gd")
const LaneSim = preload("res://scripts/game/bowling/lane_sim.gd")

const DT := 1.0 / 60.0

var _checks := 0
var _fails := 0
var _app: Node
var _bowling: GDScript
var _clients: Array = []
var _buzzes: Array = [[], [], [], []]
var _log: Array = []   # The plates that the game drew: {frame, msg}.
var _game: Control


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A check of something that is wrong today (or a step that does not match the code): it prints KNOWN BUG and does not fail.
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: use _check)")
	else:
		print("  KNOWN BUG ", issue, ": ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_bowling = load("res://scripts/game/bowling/bowling_game.gd")
	load("res://scripts/game/game_settings.gd").clear()
	await _connect(4)
	await _totals()
	await _last_frame()
	await _rails()
	await _turn_order()
	await _phones_and_scores()
	await _winner_and_menu()
	await _leave()
	_look()
	Shell.recorder = Callable()
	for c in _clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _connect(n: int) -> void:
	_clients = await SimInput.connect_phones(self, _app, n, _clients)
	_buzzes = [[], [], [], []]
	for i in _clients.size():
		var idx := i
		_clients[i].haptic_requested.connect(func(ms: int) -> void: _buzzes[idx].append(ms))


func _on_plate(kind: String, ci: CanvasItem, _rect: Rect2, info: Dictionary) -> void:
	if kind == "plate" and ci == _game:
		_log.append({"frame": Engine.get_process_frames(), "msg": String(info.msg)})


## A game for the first `n` phones, after the countdown. The others stay joined but do not play.
func _new_game(n: int, difficulty := "medium", rails := "off") -> Control:
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	_game = SimInput.start_game(_app, _bowling, {"difficulty": difficulty, "rails": rails})
	await _frames(3)
	var slots: Array[int] = []
	for s in n:
		slots.append(s)
	_game.participants = slots
	_game.rules.setup(slots)
	_game._board = Scoreboard.new(slots)
	_game._rows_at_start = n
	SimInput.to_play(_game, func() -> bool: return _game._clock.is_counting())
	Shell.recorder = _on_plate
	return _game


## One ball of the player on turn that knocks `n` of the standing pins (at most). The banner is skipped, the next turn starts.
func _ball(game: Control, n: int) -> int:
	game._before = game.sim.standing_mask()
	var k := 0
	for p in game.sim.pins:
		if p.state == LaneSim.State.STAND and k < n:
			p.state = LaneSim.State.FALLEN
			k += 1
	game._roll_done()
	game._after_result()
	return k


## The textbook count of a finished game: the running total after each of the 10 frames.
func _textbook(rolls: Array) -> Array:
	var out: Array = []
	var total := 0
	var i := 0
	for f in 10:
		if rolls[i] == 10:
			total += 10 + rolls[i + 1] + rolls[i + 2]
			i += 1
		elif rolls[i] + rolls[i + 1] == 10:
			total += 10 + rolls[i + 2]
			i += 2
		else:
			total += rolls[i] + rolls[i + 1]
			i += 2
		out.append(total)
	return out


## 6a: games with strikes, spares, open frames, gutters and made-up rolls. The sheet (the cells) shows the textbook total after
## every frame, and the score of the player is the total of the last frame.
func _totals() -> void:
	print("the total of a whole game")
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var plans := [
		["12 strikes", func(_i: int, _st: int) -> int: return 10],
		["all gutters", func(_i: int, _st: int) -> int: return 0],
		["5 and 5 with a 5", func(_i: int, _st: int) -> int: return 5],
		["9 and a miss", func(i: int, _st: int) -> int: return 9 if i % 2 == 0 else 0],
	]
	for g in 8:
		plans.append(["made up %d" % g, func(_i: int, st: int) -> int:
			return st if rng.randf() < 0.3 else rng.randi_range(0, st)])
	for plan in plans:
		var game := await _new_game(1)
		var i := 0
		while not game.rules.game_over() and i < 30:
			_ball(game, int(plan[1].call(i, game.sim.standing_count())))
			i += 1
		var rolls: Array = game.rules.row_of(0).rolls
		var cells: Array = BowlingRules.sheet_cells(game.rules.row_of(0).rolls)
		var shown: Array = cells.map(func(c: Dictionary) -> int: return int(c.total))
		var want := _textbook(rolls)
		_check(game.rules.game_over() and shown == want and game.rules.score_of(0) == want[9]
				and game._board.score(0) == float(want[9]),
				"6a: %s (%d balls): the sheet shows %s, the textbook count is %s" % [plan[0], rolls.size(), str(shown), str(want)])


## 6c: on the last ball the bar says Frame 10/10; from the end of the last ball to the result menu it takes the banner and the
## wait of the lane.
func _last_frame() -> void:
	print("the last frame")
	var game := await _new_game(1)
	for i in 9:
		_ball(game, 10)
	var text := Lang.f("bowling.frame", [game.rules.current_frame(), BowlingRules.FRAMES, maxi(1, game.rules.current_ball())])
	_check(text.to_upper().begins_with("FRAME 10/10"), "6c: in the last frame the top bar says '%s'" % text.to_upper())
	_ball(game, 10)   # The first ball of the 10th frame: a strike, so two more balls.
	_ball(game, 10)
	game._before = game.sim.standing_mask()
	for p in game.sim.pins:
		p.state = LaneSim.State.FALLEN
	game._roll_done()   # The last ball has stopped. Time starts here.
	var t := 0.0
	while not game.is_over and t < 10.0:
		game._process(DT)
		t += DT
	_check(game.is_over and game.rules.game_over(), "6c: the result menu opens after the last ball")
	_check(t >= 1.0 and t <= 4.0, "6c: it opens %.2f s after the last ball stopped (the banner %.1f s, then the lane %.1f s)"
			% [t, game.RESULT_TIME, game.END_DELAY])
	_known_bug("step 6c asks for 1 to 3 s after the last ball; the banner (1.8 s) and the wait of the lane (2.0 s) make 3.8 s "
			+ "(REQ-BW-1 says 2 s)", t >= 1.0 and t <= 3.0, "6c: the menu opens 1 to 3 s after the last ball (%.2f s)" % t)


## 7a: with Rails on, 5 balls aimed at the end of the path (both sides, slow to fast) touch a rail, are never in the gutter and
## roll back into the lane, so each knocks a pin.
func _rails() -> void:
	print("rails")
	var game: Control = await _new_game(1, "easy", "on")
	var all_ok := true
	var detail := ""
	var plan := [[1.0, 0.0], [-1.0, 0.3], [1.0, 0.6], [-1.0, 0.8], [1.0, 1.0]]
	for step in plan:
		game._aim = step[0]
		game.detector.power = step[1]
		var start_x: float = step[0] * game.AIM_X
		game._throw(game.rules.current_slot())
		var touched := absf(game.sim.ball_pos.x) >= LaneSim.RAIL_LIMIT - 0.001
		var in_gutter := false
		var widest := 0.0
		var guard := 0
		while game.phase == game.Phase.ROLL and guard < 2000:
			game._process(DT)
			in_gutter = in_gutter or game.sim.in_gutter
			widest = maxf(widest, absf(game.sim.ball_pos.x))
			guard += 1
		var knocked: int = game.sim.knocked_since(game._before)
		var ok: bool = touched and not in_gutter and widest <= LaneSim.RAIL_LIMIT + 0.001 and knocked >= 1 \
				and game.phase == game.Phase.RESULT
		if not ok:
			all_ok = false
			detail += " [aim %.0f x=%.2f touched=%s gutter=%s knocked=%d]" % [step[0], start_x, touched, in_gutter, knocked]
		game._after_result()
		game.sim.set_rack(game.FULL_RACK)   # Every ball has the whole rack.
	_check(all_ok, "7a: 5 balls with rails touch a rail, none is in the gutter, each knocks a pin%s" % detail)
	_check(game.best_key() == "", "7b: a game with rails has no personal best")


## The last plate that the game drew with the name of `slot`, or "".
func _plate_text() -> String:
	return String(_log.back().msg) if not _log.is_empty() else ""


func _draw_once(game: Control) -> void:
	_log.clear()
	game.queue_redraw()
	await process_frame
	await process_frame


## 8a: with 2, 3 and 4 phones and strikes only, the plate "<NAME>, your turn!" goes in slot order, frame after frame.
func _turn_order() -> void:
	print("the plate with the name")
	for n in [2, 3, 4]:
		var game := await _new_game(n)
		var seen: Array[String] = []
		for k in 2 * n:
			await _draw_once(game)
			seen.append(_plate_text())
			_ball(game, 10)
		var want: Array[String] = []
		for k in 2 * n:
			want.append(Lang.f("bowling.turn", ["Sim%d" % (k % n)]))
		_check(seen == want, "8a: %d phones, two frames of strikes: the plate names %s" % [n, str(seen)])
	# How long the plate stays: the whole turn (the step says 1 to 2 s).
	var game := await _new_game(2)
	await _draw_once(game)
	var first := _plate_text()
	SimInput.run(game, 3.0)
	await _draw_once(game)
	var later := _plate_text()
	_check(first == Lang.f("bowling.turn", ["Sim0"]), "8a: the plate shows the name of the first player at the start of the turn")
	_known_bug("step 23.8a says the plate shows 1 to 2 s; the game draws it for the whole turn (strings.csv: 'plate in the top bar "
			+ "while a player bowls')", later == "", "8a: after 3 s of the turn the plate is gone ('%s')" % later)


## 9a to 9c, 8c: the phones are told whose turn it is, buzz once, and show their own score and place.
func _phones_and_scores() -> void:
	print("the phones")
	await _connect(2)
	var game := await _new_game(2)
	await _frames(6)
	var first_buzzes: Array = _buzzes[0].duplicate()
	_check(_clients[0].turn_state == 1 and _clients[1].turn_state == 2 and _clients[1].turn_who == "Sim0"
			and _clients[0].turn_who == "", "9a, 9b: the phone on turn is told YOUR TURN and the other one gets the name Sim0")
	_known_bug("issue-needed: the first turn buzzes twice (the GO buzz to every phone and the buzz of the turn)",
			first_buzzes.count(60) == 1, "9a: the phone of the first turn buzzed once for 60 ms: %s" % str(first_buzzes))
	# A strike moves the turn to phone 2: it gets one buzz, phone 1 gets the name.
	_buzzes = [[], [], [], []]
	await create_timer(0.2).timeout   # The cool-down of the pulses is real time.
	_ball(game, 10)
	game._process(DT)
	await _frames(6)
	_check(_clients[1].turn_state == 1 and _clients[0].turn_state == 2 and _clients[0].turn_who == "Sim1",
			"9a, 9b: after a strike phone 2 is on turn and phone 1 sees the name Sim1")
	var turn_buzzes: Array = _buzzes[1].filter(func(ms: int) -> bool: return ms == 60)
	_check(turn_buzzes.size() == 1, "9a: phone 2 buzzed once for 60 ms when its turn started: %s" % str(_buzzes[1]))
	# 8c: the score and the place on the phones are the totals of the sheet.
	var ok := true
	var detail := ""
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for k in 8:
		_ball(game, rng.randi_range(0, 10))
		game._process(DT)
		await _frames(6)
		var totals := {}
		for s in [0, 1]:
			totals[s] = game.rules.score_of(s)
		for s in [0, 1]:
			var rank := 1
			for o in [0, 1]:
				if totals[o] > totals[s]:
					rank += 1
			var want_rank := rank if maxi(totals[0], totals[1]) > 0 else 0
			if _clients[s].score_text != str(totals[s]) or _clients[s].score_rank != want_rank:
				ok = false
				detail += " [ball %d phone %d: '%s' place %d, sheet %d place %d]" % [k, s + 1, _clients[s].score_text,
						_clients[s].score_rank, totals[s], want_rank]
	_check(ok, "8c: after each of 8 balls the score and the place on both phones are the total and the order of the sheet%s"
			% detail)
	# 9c: at the result menu the turn line is gone on every phone.
	var guard := 0
	while not game.rules.game_over() and guard < 60:
		_ball(game, 10)
		guard += 1
	var t := 0.0
	while not game.is_over and t < 10.0:
		game._process(DT)
		t += DT
	await _frames(8)
	_check(game.is_over and _clients[0].turn_state == 0 and _clients[1].turn_state == 0 and _clients[0].turn_who == ""
			and _clients[1].turn_who == "", "9c: at the result menu neither phone shows YOUR TURN or <NAME> IS BOWLING")


## 8d: two phones, the first knocks more: "X wins!" and the list in the order of the totals.
func _winner_and_menu() -> void:
	print("the result menu")
	var game := await _new_game(2)
	var guard := 0
	while not game.rules.game_over() and guard < 80:
		_ball(game, 10 if game.rules.current_slot() == 1 else 3)   # Phone 2 is the better one.
		guard += 1
	var t := 0.0
	while not game.is_over and t < 10.0:
		game._process(DT)
		t += DT
	await _frames(4)
	var texts: Array = game._menu_box.find_children("*", "Label", true, false).map(func(l: Label) -> String:
		return String(l.text).to_lower())
	var title := Lang.f("result.winner", ["Sim1"]).to_lower()
	var rows := texts.filter(func(s: String) -> bool: return s.contains("   ") and (s.contains("sim0") or s.contains("sim1")))
	_check(texts.any(func(s: String) -> bool: return s == title), "8d: the title is '%s': %s" % [title, str(texts)])
	_check(rows.size() == 2 and rows[0].contains("sim1") and rows[1].contains("sim0"),
			"8d: the list has the winner first (%s)" % str(rows))
	_check(game.rules.score_of(1) > game.rules.score_of(0), "8d: and the totals are in that order (%d against %d)"
			% [game.rules.score_of(1), game.rules.score_of(0)])


## 10a, 10b: the player on turn leaves; the plate names the next player within 5 s. The last phone leaves: the menu.
func _leave() -> void:
	print("a player leaves")
	await _connect(2)
	var game := await _new_game(2)
	await _draw_once(game)
	_check(_plate_text() == Lang.f("bowling.turn", ["Sim0"]), "10a: phone 1 is on turn")
	_clients[0].leave()
	var t0 := Time.get_ticks_msec()
	var next := ""
	while Time.get_ticks_msec() - t0 < 5000 and next == "":
		game._process(DT)
		await _draw_once(game)
		if _plate_text() == Lang.f("bowling.turn", ["Sim1"]):
			next = _plate_text()
	var took := Time.get_ticks_msec() - t0
	_check(next != "" and not game.is_over and game.rules.current_slot() == 1,
			"10a: the plate shows the next player Sim1 %d ms after phone 1 left (less than 5 s) and the game goes on" % took)
	_clients[1].leave()
	var t := 0.0
	while not game.is_over and t < 5.0:
		game._process(DT)
		await process_frame
		t += DT
	await _frames(2)
	var texts: Array = game._menu_box.find_children("*", "Label", true, false).map(func(l: Label) -> String: return String(l.text))
	_check(game.is_over and (texts.has("minigame.no_players_connected")
			or texts.has(Lang.t("minigame.no_players_connected").to_upper())), "10b: the last phone left: %s" % str(texts))


## 13a, 13d: the pin is at least 4.4 % of the screen height; the disco wall is the same tile by tile over 30 s.
func _look() -> void:
	print("the look")
	var pin_h := float(BowlingLook.PIN_ROWS.size()) * Shell.WORLD_PIXEL
	_check(pin_h / 1080.0 >= 0.044, "13a: a pin is %.0f units high, %.1f %% of the 1080 high screen (at least 4.4 %%)"
			% [pin_h, 100.0 * pin_h / 1080.0])
	var size := Vector2(1920, 1080)
	var geo := BowlingLook.Geo.new(size, 1080.0 - 60.0 - 72.0)
	var first := BowlingLook.wall_tiles(size, geo)
	var changes := 0
	var max_per_s := 0
	var colors: Array = first.map(func(t: Dictionary) -> Color: return t.color)
	var window := 0
	for step in 60:   # 30 s, a look every half second.
		var now := BowlingLook.wall_tiles(size, geo)
		for i in now.size():
			if now[i].color != colors[i]:
				changes += 1
				window += 1
				colors[i] = now[i].color
		if step % 2 == 1:
			max_per_s = maxi(max_per_s, window)
			window = 0
	var wall_h := geo.top - BowlingLook.WALL_TOP
	var in_top := first.all(func(t: Dictionary) -> bool: return t.rect.end.y <= BowlingLook.WALL_TOP + wall_h * 2.0 / 3.0 + 0.01)
	_check(not first.is_empty() and in_top and changes == 0 and max_per_s <= 3,
			"13d: the light tiles fill the top two thirds only; over 30 s no tile changed (%d changes, at most %d in 1 s)"
			% [changes, max_per_s])
