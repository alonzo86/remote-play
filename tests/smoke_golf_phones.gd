extends SceneTree
## Mini Golf with simulated phones, the automated half of Manual test 26: sensor traces (a turn of the phone, a back swing, a
## swing through, a slow move) go into the phone slots of the TV and the game reacts as it would to a real phone: the aim, the
## lock, the power, the buzz, the pause. Also the texts of the bar, the hole card, the hints and the medals. Run:
##   godot --headless --path . --script tests/smoke_golf_phones.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Trace = preload("res://tests/golf_tennis_trace.gd")
const R = preload("res://tests/sensor_replay.gd")
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
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_run()


func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: use _check)")
	else:
		_fails += 1
		print("  FAIL (known bug) ", issue, ": ", what)


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


## The first turn starts at once (REQ-GM-35); it starts again here, now that the phones have settled, so that the pose of
## each phone is the straight line, and one tick publishes it.
func _to_turn(game: Control) -> void:
	game._start_turn()
	game._game_tick(0.016)


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

	# ---- The start, the bar and the hole text ----
	app.go(_Golf, {"difficulty": "medium", "holes": "3"})
	await _frames(3)
	var game: Control = app.current_screen()
	_check(not game.has_method("_countdown_spots") and game.player(0).player_name != game.player(1).player_name,
			"the game has no name tags (removed 2026-10-21) and the 2 phones have different names (2a)")
	_check(game.hole_text() == "HOLE 1/3  PAR 2"
			and game.chip_text(0) == game.player(0).player_name + "  0" and game.chip_text(1) == game.player(1).player_name + "  0",
			"the top right says '%s' and the bar has one chip per player: '%s', '%s' (2c)"
			% [game.hole_text(), game.chip_text(0), game.chip_text(1)])
	# The ball is 32 units (3 % of 1080; an exception to REQ-GM-47m, owner 2026-11-03: 48 was too big) on every hole, and the cup is
	# bigger than the ball (the view has one scale for a hole, so it is the same at the tee and at the cup).
	var smallest := 9999.0
	var cup_ok := true
	for n in [1, 2, 3, 4, 5]:
		var geo := GolfLook.Geo.new(Vector2(1920, 1080), Holes.hole(n))
		smallest = minf(smallest, geo.ball_d())
		cup_ok = cup_ok and geo.cup_r() * 2.0 > geo.ball_d()
	print("   the ball is %.0f units wide on a 1080p screen (%.1f%% of the height)" % [smallest, smallest / 10.8])
	_check(smallest == 32.0 and cup_ok,
			"the golf ball is 32 units at 1080p on every hole, and the cup is wider (%.0f)" % smallest)
	_to_turn(game)
	var on_course: Array = game.ball_list()
	_check(game._putter == game.rules.current_slot() and game._putter == 0 and game.golfer_shown(),
			"only the golfer of the player on turn is drawn (3a)")
	_check(on_course.size() == 1 and on_course[0].turn and on_course[0].slot == 0,
			"only the ball of the player on turn is on the course (REQ-MG-2, owner 2026-11-03)")
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
	_turn(game, 0, 150.0, 1.0)   # Nearly backwards: the aim is not limited to the front (owner, 2026-11-04).
	_check(game._heading < -2.4 and game._heading > -2.8,
			"150 degrees to the left aims %.2f rad: the putt can go back" % game._heading)
	_check(game.golfer_flipped(), "when the aim points back the golfer turns the other way")
	_turn(game, 0, -150.0, 1.0)
	_check(absf(game._heading) < 0.06 and not game.golfer_flipped(),
			"and back at the start the aim is straight again (%.2f rad) and the golfer faces the cup" % game._heading)
	_feed(game, 0, Trace.stroke(Vector3(1, 0, 0), 8.0, 0.0, 0.25, 0.01).slice(0, 15))
	_check(game.detector.aim_locked, "the back swing locks the aim")
	var locked_at: float = game._heading
	_turn(game, 0, 20.0, 0.5)
	_check(game.detector.aim_locked
				and game._heading == locked_at, "a turn of 20 degrees while the aim is locked changes nothing (4c)")

	# ---- 4e: near the cup the aim snaps to it; A locks the aim and a second press unlocks it (REQ-MG-4) ----
	var gsn := await _start(app)
	var to_cup: float = GolfSim.heading_to_cup(gsn._hole, gsn.sim.pos)
	_turn(gsn, 0, -rad_to_deg(to_cup + 0.06), 0.5)   # 0.06 rad (3.4 degrees) from the cup: inside the snap
	_check(gsn._snapped and gsn._heading == to_cup,
			"3 degrees from the cup the aim snaps to the cup (heading %.3f, cup %.3f)" % [gsn._heading, to_cup])
	_turn(gsn, 0, -rad_to_deg(0.19), 0.5)
	_check(not gsn._snapped and absf(gsn._heading - to_cup) > 0.15,
			"14 degrees from the cup the aim does not snap (%.2f rad away)" % absf(gsn._heading - to_cup))
	_sample(gsn, 0, Vector3.ZERO, Vector3.ZERO, Protocol.BTN_A)   # A goes down: the aim is locked.
	_sample(gsn, 0, Vector3.ZERO)
	var held_at: float = gsn._heading
	_turn(gsn, 0, 25.0, 0.5)
	_check(gsn._aim_held and not gsn.detector.aim_locked and gsn._heading == held_at,
			"A locks the aim: a turn of 25 degrees changes nothing, and the swing has not started")
	_check(gsn.aim_hint_key() == "", "while the aim is locked by A no instruction shows on the screen (owner, 2026-11-04)")
	_sample(gsn, 0, Vector3.ZERO, Vector3.ZERO, Protocol.BTN_A)
	_sample(gsn, 0, Vector3.ZERO)
	_turn(gsn, 0, -10.0, 0.5)
	_check(not gsn._aim_held and gsn._heading != held_at, "a second press on A unlocks it: the aim follows the phone again")
	# An A that is held while the turn starts is not a press, and a press during the back swing changes nothing.
	var gk := await _start(app)
	gk.player(0).buttons = Protocol.BTN_A
	_rest(gk, 0, 0.3)
	_check(not gk._aim_held, "an A that is held from before is not a press")
	gk.player(0).buttons = 0
	_feed(gk, 0, Trace.stroke(Vector3(1, 0, 0), 8.0, 0.0, 0.25, 0.01).slice(0, 15))
	_sample(gk, 0, Vector3.ZERO, Vector3.ZERO, Protocol.BTN_A)
	_check(gk.detector.aim_locked and not gk._aim_held, "a press on A during the back swing does nothing")

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
		for peak in [8.0, 12.0, 18.0]:   # Full power is reached at 18 m/s2 (FULL_FWD).
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

	# ---- Issue #209: a move of the phone that is not a putt ----
	var x := Vector3(1, 0, 0)
	var moves := {}
	for cm_s in [[20.0, 0.3], [30.0, 0.4], [50.0, 0.5], [15.0, 0.25]]:
		var peak: float = TAU * cm_s[0] / 100.0 / (cm_s[1] * cm_s[1])
		var carry := R.Trace.new()
		var n := int(round(cm_s[1] / DT))
		for i in n:
			carry.add(x * peak * sin(TAU * float(i) / float(n)))
		moves["a move of %d cm to the side in %.2f s (%.0f m/s2)" % [cm_s[0], cm_s[1], peak]] = carry
	for hz in [2.0, 3.0, 4.0, 5.0]:
		moves["a slow shake of %d Hz at 8 m/s2" % hz] = R.shake(1.0, 8.0, hz)
	var putted := []
	for d in ["easy", "medium", "hard"]:
		for name in moves:
			var gm := await _start(app, {"difficulty": d})
			_feed(gm, 0, Array(moves[name].lin))
			_rest(gm, 0, 1.5)
			if gm.phase != gm.Phase.AIM or gm.rules.strokes_on_hole(0) > 0:
				putted.append("%s: %s" % [d, name])
	_check(putted.is_empty(), "%d moves to the side and slow shakes give no putt on 3 levels (issue #209). Putted: %s"
			% [moves.size(), "; ".join(putted)])
	var gwalk := await _start(app, {"difficulty": "easy"})
	_feed(gwalk, 0, Array(R.walk(15.0, Vector3(0, 0, 1), 2.0, [2.0, 4.0, 6.0, 3.0, 5.0]).lin))
	_check(gwalk.phase == gwalk.Phase.AIM and gwalk.rules.strokes_on_hole(0) == 0,
			"15 s of walking give no putt on Easy (#209)")
	# A real putt: the hand brakes the back swing (9 m/s2: as hard as the push that the old rule took for the forward swing),
	# then swings forward. The stop of the back swing is not the putt.
	var real_putts := 0
	var early := 0
	for d in ["easy", "medium", "hard"]:
		for fwd in [10.0, 14.0, 20.0]:
			var gr := await _start(app, {"difficulty": d})
			var tr := R.pendulum(x, 9.0, fwd, 0.25)
			var stopped_at := int(round(0.5 / DT))
			var first := -1
			for i in tr.size():
				_sample(gr, 0, tr.lin[i])
				if first < 0 and gr.phase != gr.Phase.AIM:
					first = i
			_rest(gr, 0, 0.5)
			real_putts += 1 if gr.phase != gr.Phase.AIM and first >= 0 else 0
			early += 1 if first >= 0 and first < stopped_at else 0
	_check(real_putts == 9 and early == 0,
			"9 real putts (back 9 and brake, forward 10 to 20) all roll, none at the stop of the back swing: %d rolled, %d early"
			% [real_putts, early])

	# ---- 9: the help of the three levels ----
	var lines: Array = [_Golf.level("easy").line, _Golf.level("medium").line, _Golf.level("hard").line]
	_check(lines[0] >= 2.0 * lines[1] and lines[1] > 0.0 and lines[2] == 0.0,
			"the aim line is %s course units on Easy, Medium, Hard: Easy at least twice Medium, Hard has none (9a)" % str(lines))
	var hint_ok := true
	for d in ["easy", "medium", "hard"]:
		var gh := await _start(app, {"difficulty": d})
		var unlocked: String = gh.aim_hint_key()
		_feed(gh, 0, Trace.stroke(Vector3(1, 0, 0), 8.0, 0.0, 0.25, 0.01).slice(0, 15))
		hint_ok = hint_ok and unlocked == "" and gh.aim_hint_key() == ""
	_check(hint_ok, "no instruction shows before or after the lock on any level (9b, owner 2026-11-04)")
	var dist := {"easy": 0.0, "medium": 0.0}
	for d in ["easy", "medium"]:
		for k in 5:
			var gw := await _start(app, {"difficulty": d})
			var flat := {"par": 2, "tee": Vector2(0.0, 1.1), "cup": Vector2(0.0, 5.1), "fairway": [Rect2(-0.8, 0.75, 1.6, 5.0)],
					"water": [], "bridges": [], "spinners": [], "blocks": [], "rocks": []}   # No hill: the weakest putts roll free.
			gw._hole = flat
			gw._spot = flat.tee
			gw.sim.start(flat, flat.tee)
			# The weakest putt is a pendulum swing as a hand moves it (it brakes the back swing, issue #209).
			var weak_fwd: float = (6.0 if d == "easy" else 8.6) + rng.randf_range(0.0, 0.3)
			_feed(gw, 0, Array(R.pendulum(Vector3(1, 0, 0), 5.0 if d == "easy" else 8.0, weak_fwd, 0.25).lin))
			for i in 180:
				if gw.phase != gw.Phase.AIM:
					break
				_sample(gw, 0, Vector3.ZERO)
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
	_check(g6.phase == g6.Phase.HOLE, "the card stays for 1 s (it goes on by itself, no button: owner, 2026-11-03)")
	for i in int((g6.HOLE_TIME + 0.5) / DT):
		_sample(g6, 0, Vector3.ZERO)
	_check(g6.phase == g6.Phase.AIM and g6.rules.hole_number() == 2,
			"the card goes on to the next hole by itself after %.1f s (8e)" % g6.HOLE_TIME)
	_check(g6.rules.total(0) == 1 and g6.rules.total(1) == 2, "the totals go on to hole 2: 1 and 2 strokes")

	# A button held on the phone does nothing: the game has no button (REQ-GM-37a).
	var g7 := await _start(app, {"holes": "3"})
	g7.player(0).buttons = Protocol.BTN_A
	g7.sim.in_cup = true   # A putt that holes out has a banner.
	g7._putt_done()
	g7._game_tick(DT)
	g7.player(0).buttons = 0
	g7.player(0).buttons = Protocol.BTN_A
	g7._game_tick(DT)
	_check(g7.phase == g7.Phase.RESULT and g7._banner != "", "a press on A does not skip the putt banner: the game has no button")

	# ---- 10b: the score of 3 holes alone is the number of strokes (no medal tiers, REQ-GM-73, REQ-MG-14) ----
	var strokes_ok := true
	var table := [[3, 3, 2], [3, 3, 3], [4, 4, 3], [4, 4, 4], [5, 5, 4], [5, 5, 5]]
	for row in table:
		var gm := await _start(app, {"holes": "3"})
		gm._on_player_left(1)
		for per_hole in row:
			for st in per_hole:
				gm.sim.in_cup = st == per_hole
				gm.sim.in_water = false
				gm._putt_done()
				gm._after_result()
			gm._after_hole()
		var total := int(gm._board.score(0))
		if total != int(row[0]) + int(row[1]) + int(row[2]):
			strokes_ok = false
			print("    strokes %s total %d" % [str(row), total])
	_check(strokes_ok, "8, 9, 11, 12, 14 and 15 strokes over 3 holes are the score of the player (10b)")

	# ---- 11c: a pause after the back swing, then a full swing putts ----
	var gp := await _start(app)
	_feed(gp, 0, Trace.stroke(Vector3(1, 0, 0), 8.0, 0.0, 0.25, 0.01).slice(0, 15))
	var locked_before: bool = gp.detector.aim_locked
	gp.open_menu("minigame.end_game_ask", gp.pause_entries())
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
