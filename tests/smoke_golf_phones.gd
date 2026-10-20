extends SceneTree
## Mini Golf with simulated phones, the automated half of Manual test 26: sensor traces (a turn of the phone, a back swing, a
## swing through, a slow move) go into the phone slots of the TV and the game reacts as it would to a real phone: the aim, the
## lock, the power, the buzz, the pause. Also the texts of the bar, the hole card, the hints and the medals. Run:
##   godot --headless --path . --script tests/smoke_golf_phones.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Medals = preload("res://scripts/game/medals.gd")
const Trace = preload("res://tests/golf_tennis_trace.gd")
const GolfRules = preload("res://scripts/game/mini_golf/golf_rules.gd")
const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")
const GolfSim = preload("res://scripts/game/mini_golf/golf_sim.gd")
const GolfLook = preload("res://scripts/game/mini_golf/golf_look.gd")

const DT := 1.0 / 60.0

var _fails := 0
var _checks := 0
var _ticks := {}
var _buzzes := {}
var _Golf: GDScript


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


func _join_to(app: Node, clients: Array, n: int) -> void:
	while clients.size() < n:
		var i := clients.size()
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
		_buzzes[i] = 0
		c.haptic_requested.connect(func(_ms: int) -> void: _buzzes[i] += 1)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame


## Skips the countdown so that a test goes straight to the first turn.
func _to_turn(game: Control) -> void:
	game._clock.time = -0.001
	game._game_tick(0.016)   # GO: the first turn starts


## Feeds one sample to the phone of `slot` and ticks the game.
func _sample(game: Control, slot: int, lin: Vector3, gyro := Vector3.ZERO, buttons := 0) -> void:
	var tk: int = _ticks.get(slot, 0)
	var pkt := Trace.packet(lin, tk, gyro)
	pkt.buttons = buttons
	game.player(slot).on_sensor(pkt, int(round(float(tk) * Trace.DT * 1000.0)))
	_ticks[slot] = tk + 1
	game._game_tick(DT)


func _feed(game: Control, slot: int, samples: Array) -> void:
	for s in samples:
		_sample(game, slot, s)


func _rest(game: Control, slot: int, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_sample(game, slot, Vector3.ZERO)


## The phone turns by `deg` degrees (positive: to the left) in `seconds` and then rests.
func _turn(game: Control, slot: int, deg: float, seconds: float) -> void:
	var w := deg_to_rad(deg) / seconds
	for i in int(round(seconds / DT)):
		_sample(game, slot, Vector3.ZERO, Vector3(0, 0, w))
	_rest(game, slot, 0.3)


## A full putt swing of strength `peak` (m/s2): back, then forward. Returns when the ball rolls or after 3 s.
func _swing(game: Control, slot: int, peak: float, back := 8.0) -> void:
	_feed(game, slot, Trace.stroke(Vector3(1, 0, 0), back, peak))
	for i in 180:
		if game.phase != game.Phase.AIM:
			break
		_sample(game, slot, Vector3.ZERO)


func _roll_out(game: Control) -> void:
	var guard := 0
	while game.phase == game.Phase.ROLL and guard < 3000:
		game._game_tick(DT)
		guard += 1


func _new_game(app: Node, props := {}) -> Control:
	var p := {"difficulty": "medium", "holes": "3"}
	p.merge(props, true)
	app.go(_Golf, p)
	return null


func _start(app: Node, props := {}) -> Control:
	var p := {"difficulty": "medium", "holes": "3"}
	p.merge(props, true)
	app.go(_Golf, p)
	await _frames(3)
	var g: Control = app.current_screen()
	_to_turn(g)
	for s in g.participants:
		var pl = g.player(s)
		_ticks[s] = _ticks.get(s, 0)
		_rest(g, s, 0.2)
	return g


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_Golf = load("res://scripts/game/mini_golf/mini_golf_game.gd")
	var GameSettings = load("res://scripts/game/game_settings.gd")
	var app: Node = root.get_node("App")
	app.set_language("en", false)
	GameSettings.clear()
	var clients: Array = []
	await _join_to(app, clients, 2)
	await _frames(2)

	# ---- The countdown, the bar and the hole text ----
	app.go(_Golf, {"difficulty": "medium", "holes": "3"})
	await _frames(3)
	var game: Control = app.current_screen()
	var spots: Dictionary = game._countdown_spots(game._geo())
	var inside := true
	for s in spots:
		inside = inside and Rect2(Vector2.ZERO, game.size).has_point(spots[s])
	_check(spots.size() == 2 and inside and spots[0] != spots[1] and game.player(0).player_name != game.player(1).player_name
			and game.player(0).player_name != "", "the countdown has a name tag for each of the 2 phones, on the screen (2a)")
	_check(game.hole_text() == "HOLE 1/3  PAR 2"
			and game.chip_text(0) == game.player(0).player_name + "  0" and game.chip_text(1) == game.player(1).player_name + "  0",
			"the top right says '%s' and the bar has one chip per player: '%s', '%s' (2c)"
			% [game.hole_text(), game.chip_text(0), game.chip_text(1)])
	var balls: Array = [GolfLook.Geo.new(Vector2(1920, 1080)).ball_r(Holes.hole(1).tee.y) * 2.0]
	print("   the ball is %.0f px wide at the tee on a 1080p screen (%.1f%% of the height)" % [balls[0], balls[0] / 10.8])
	_to_turn(game)
	_check(game._putter == game.rules.current_slot() and game._putter == 0, "only the golfer of the player on turn is drawn (3a)")
	_check(game.TURN_BANNER >= 1.0 and game.TURN_BANNER <= 2.0,
			"the name of the player on turn shows for %.1f s, between 1 and 2 (3c)"
			% game.TURN_BANNER)

	# ---- 4a, 4c: the aim follows the turn of the phone, the back swing locks it ----
	for s in 2:
		_rest(game, s, 0.3)
	_turn(game, 0, -20.0, 0.5)   # to the right
	var right: float = game._heading
	_turn(game, 0, 40.0, 0.7)    # 20 degrees to the left of the start
	var left: float = game._heading
	_check(right > 0.28 and right < 0.42 and left < -0.28 and left > -0.42,
			"20 degrees to the right aims +%.2f rad, 20 degrees to the left aims %.2f rad (4a)" % [right, left])
	_turn(game, 0, -20.0, 0.5)
	_check(absf(game._heading) < 0.06, "back at the start the aim is straight again (%.2f rad)" % game._heading)
	_feed(game, 0, Trace.stroke(Vector3(1, 0, 0), 8.0, 0.0, 0.25, 0.01).slice(0, 15))
	_check(game.detector.aim_locked, "the back swing locks the aim")
	var locked_at: float = game._heading
	_turn(game, 0, 20.0, 0.5)
	_check(game.detector.aim_locked
				and game._heading == locked_at, "a turn of 20 degrees while the aim is locked changes nothing (4c)")

	# ---- 4b: RECENTER straightens the aim within a second ----
	var g2 := await _start(app)
	_turn(g2, 0, 30.0, 0.5)
	var before: float = g2._heading
	g2.player(0).recenter()
	_rest(g2, 0, 0.5)
	_check(absf(before) > 0.4 and absf(g2._heading) < 0.03,
			"RECENTER: the aim of %.2f rad is straight again after 0.5 s (4b)" % before)

	# ---- 4d: a phone that is turned before its turn starts straight ----
	var g3 := await _start(app)
	_turn(g3, 1, 30.0, 0.5)   # the second phone is turned 30 degrees to the left while the first one is on turn
	var off: float = g3.player(1).yaw_offset()
	g3.rules.putt_done(false)
	g3._start_turn()
	_rest(g3, 1, 0.2)
	_check(g3.rules.current_slot() == 1 and off > 0.45 and absf(g3._heading) < 0.03,
			"a phone turned %.2f rad before its turn aims straight when the turn starts (4d)" % off)

	# ---- 5a: soft, medium and hard swings: the speed and the way the ball rolls ----
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var ordered_speed := 0
	var ordered_dist := 0
	for k in 5:
		var speeds: Array = []
		var dists: Array = []
		for peak in [12.0, 20.0, 30.0]:
			var g := await _start(app)
			_swing(g, 0, peak + rng.randf_range(-1.0, 1.0))
			speeds.append(g.sim.vel.length())
			var from: Vector2 = g.sim.pos
			_roll_out(g)
			dists.append(g.sim.pos.distance_to(from))
		ordered_speed += 1 if speeds[0] < speeds[1] and speeds[1] < speeds[2] else 0
		ordered_dist += 1 if dists[0] < dists[1] and dists[1] > 1.5 else 0
	_check(ordered_speed >= 4 and ordered_dist >= 4,
			"soft < medium < hard in %d of 5 groups by speed; soft rolls less than medium in %d of 5 (hard reaches the end wall) (5a)"
			% [ordered_speed, ordered_dist])

	# ---- 5c: one buzz for each putt ----
	var buzz_total := 0
	for k in 5:
		var g := await _start(app)
		await _frames(4)
		_buzzes[0] = 0
		g._haptics._last.clear()   # The cool-down of the buzz runs in real time, and the test is faster than a real turn.
		_swing(g, 0, 20.0)
		await _frames(4)
		buzz_total += int(_buzzes[0])
	_check(buzz_total == 5, "5 putts buzz the phone 5 times (%d) (5c)" % buzz_total)

	# ---- 5d: a slow small move is not a putt ----
	var g4 := await _start(app)
	for k in 10:
		_feed(g4, 0, Trace.stroke(Vector3(1, 0, 0), 1.5, 1.5, 0.5, 0.5))
		_rest(g4, 0, 0.3)
	_check(g4.rules.strokes_on_hole(0) == 0 and g4.phase == g4.Phase.AIM and not g4.detector.aim_locked,
			"10 slow moves (1.5 m/s2) give no stroke and no lock (5d)")

	# ---- 9: the help of the three levels ----
	var lines: Array = [_Golf.level("easy").line, _Golf.level("medium").line, _Golf.level("hard").line]
	_check(lines[0] >= 2.0 * lines[1] and lines[1] > 0.0 and lines[2] == 0.0,
			"the aim line is %s course units on Easy, Medium, Hard: Easy at least twice Medium, Hard has none (9a)" % str(lines))
	var hint_ok := true
	for d in ["easy", "medium", "hard"]:
		var gh := await _start(app, {"difficulty": d})
		var unlocked: String = gh.aim_hint_key()
		_feed(gh, 0, Trace.stroke(Vector3(1, 0, 0), 8.0, 0.0, 0.25, 0.01).slice(0, 15))
		var locked: String = gh.aim_hint_key()
		if d == "easy":
			hint_ok = hint_ok and unlocked == "mini_golf.hint_aim" and locked == "mini_golf.hint_power" \
					and Lang.t(locked) == "SWING FORWARD. A BIGGER SWING GOES FARTHER!"
		else:
			hint_ok = hint_ok and unlocked == "mini_golf.hint_aim" and locked == ""
	_check(hint_ok, "'SWING FORWARD...' shows after the lock on Easy only (9b)")
	var dist := {"easy": 0.0, "medium": 0.0}
	for d in ["easy", "medium"]:
		for k in 5:
			var gw := await _start(app, {"difficulty": d})
			_swing(gw, 0, (6.0 if d == "easy" else 8.6) + rng.randf_range(0.0, 0.3), 5.0 if d == "easy" else 8.0)
			var moved: bool = gw.phase == gw.Phase.ROLL
			var from: Vector2 = gw.sim.pos
			_roll_out(gw)
			dist[d] += gw.sim.pos.distance_to(from) if moved else 0.0
	_check(dist.medium > 0.0 and dist.easy >= 2.0 * dist.medium,
			"the weakest swing rolls %.2f m on Easy and %.2f m on Medium (5 swings each): Easy at least twice (9c)"
			% [dist.easy / 5.0, dist.medium / 5.0])
	var same := true
	for d in ["easy", "medium", "hard"]:
		var gs := await _start(app, {"difficulty": d})
		same = same and str(gs._hole) == str(Holes.hole(1))
	_check(same, "hole 1 is the same on every level (9d)")

	# ---- 8: the holes, the card and the next hole ----
	var g5 := await _start(app, {"holes": "5"})
	var texts: Array = []
	for n in 5:
		texts.append(g5.hole_text())
		if n < 4:
			g5.rules.next_hole()
	_check(texts == ["HOLE 1/5  PAR 2", "HOLE 2/5  PAR 3", "HOLE 3/5  PAR 3", "HOLE 4/5  PAR 3", "HOLE 5/5  PAR 4"],
			"the top right text of the 5 holes: %s (8a)" % str(texts))
	var g6 := await _start(app, {"holes": "2"})
	g6.sim.in_cup = true
	g6._putt_done()
	g6._after_result()   # phone 1: in, 1 stroke
	g6.sim.in_cup = false
	g6._putt_done()
	g6._after_result()
	g6.sim.in_cup = true
	g6._putt_done()
	g6._after_result()   # phone 2: in at its 2nd stroke
	_check(g6.phase == g6.Phase.HOLE and Lang.f("mini_golf.hole_done", [g6.rules.hole_number()]) == "Hole 1 done!"
			and g6.rules.strokes_on_hole(0) == 1 and g6.rules.strokes_on_hole(1) == 2 and g6.rules.total(0) == 1,
			"the card says 'Hole 1 done!' with 1 and 2 strokes and the totals 1 and 2 (8d)")
	for i in 60:
		_sample(g6, 0, Vector3.ZERO)
	_check(g6.phase == g6.Phase.HOLE, "the card stays while nobody presses A (1 s)")
	_sample(g6, 0, Vector3.ZERO, Vector3.ZERO, Protocol.BTN_A)
	_sample(g6, 0, Vector3.ZERO)
	_check(g6.phase == g6.Phase.AIM and g6.rules.hole_number() == 2 and g6._phase_time < 0.2,
			"A on a phone starts the next hole at once (8e)")
	_check(g6.rules.total(0) == 1 and g6.rules.total(1) == 2, "the totals go on to hole 2: 1 and 2 strokes")

	# ---- 10b: the medal of 3 holes alone ----
	var medals_ok := true
	var table := [[[3, 3, 2], Medals.GOLD], [[3, 3, 3], Medals.SILVER], [[4, 4, 3], Medals.SILVER], [[4, 4, 4], Medals.BRONZE],
			[[5, 5, 4], Medals.BRONZE], [[5, 5, 5], Medals.NONE]]
	for row in table:
		var gm := await _start(app, {"holes": "3"})
		gm._on_player_left(1)
		for per_hole in row[0]:
			for st in per_hole:
				gm.sim.in_cup = st == per_hole
				gm.sim.in_water = false
				gm._putt_done()
				gm._after_result()
			gm._after_hole()
		var total := int(gm._board.score(0))
		var got: String = Medals.medal(float(total), GolfRules.tiers(3), true)
		if got != row[1] or total != int(row[0][0]) + int(row[0][1]) + int(row[0][2]):
			medals_ok = false
			print("    strokes %s total %d: %s, wanted %s" % [str(row[0]), total, got, row[1]])
	_check(medals_ok, "8, 9, 11, 12, 14 and 15 strokes over 3 holes: gold, silver, silver, bronze, bronze, none (10b)")

	# ---- 11c: a pause after the back swing, then a full swing putts ----
	var gp := await _start(app)
	_feed(gp, 0, Trace.stroke(Vector3(1, 0, 0), 8.0, 0.0, 0.25, 0.01).slice(0, 15))
	var locked_before: bool = gp.detector.aim_locked
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	gp._unhandled_input(ev)
	await _frames(2)
	var paused: bool = gp.is_paused()
	await create_timer(0.6).timeout
	gp.close_menu()
	await _frames(2)
	var t_resume: float = gp._time
	_rest(gp, 0, 0.3)
	_swing(gp, 0, 22.0)
	_check(locked_before and paused and gp.phase == gp.Phase.ROLL and gp._time - t_resume < 10.0,
			"after a pause and Resume a full swing putts within 10 s (11c)")

	# ---- The text of the splash ----
	var gw2 := await _start(app)
	gw2.sim.in_water = true
	gw2.sim.finished = true
	gw2._putt_done()
	_check(gw2._banner == "SPLASH! TRY AGAIN FROM HERE", "the banner of the water is '%s' (7e)" % gw2._banner)

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
