extends SceneTree
## Car Race with simulated phones, stepped by hand (REQ-MR-*, test 9 of docs/MANUAL_TESTS.md). Run:
##   godot --headless --path . --script tests/smoke_race.gd -- --role=tv

const Sim = preload("res://tests/sim_b.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")
const RaceLook = preload("res://scripts/game/marble_race/race_look.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")
const Lang = preload("res://scripts/core/lang.gd")

var _fails := 0
var _checks := 0
var Race
var sim


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


func _run() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)
	Race = load("res://scripts/game/marble_race/marble_race.gd")
	sim = Sim.new(self)
	await sim.join(4)
	GameSettings.clear()
	for s in 4:
		sim.settle(s, Sim.FLAT)
	await _grid_and_directions()
	await _motion()
	await _edge_markers()
	await _spread_pack()
	await _end_delay()
	await _restart_and_seeds()
	await _settings_view()
	_names()
	await _standings_and_leave()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _flat_all() -> void:
	for s in 4:
		sim.settle(s, Sim.FLAT, 500)
		sim.app.server.players[s].recenter()


## Test 9.2a, 9.3b, 9.13d: the cars wait on the grid in "3, 2, 1" even when all four phones are leaned 30 degrees; after GO the
## car goes where the phone tilts: top up goes down the screen, top down goes up, left turns the car to face left.
func _grid_and_directions() -> void:
	print("race: grid and directions")
	var game: Control = await sim.start(Race, {"track_choice": "1", "difficulty": "medium"})
	var lean := {}
	for s in 4:
		lean[s] = Sim.lean(30.0)
		sim.settle(s, lean[s])
	var start: Array = []
	for s in 4:
		start.append(game._racers[s].pos)
	var worst := 0.0
	while game._round.is_counting():
		sim.step(game, Sim.DT, lean)
		if game._round.is_counting():
			for s in 4:
				worst = maxf(worst, game._racers[s].pos.distance_to(start[s]))
	_check(worst < 0.01, "4 cars stay on the grid in '3, 2, 1' with all phones leaned 30 degrees: %.4f m < 0.01 (REQ-MR-3, REQ-MR-4)"
			% worst)
	_flat_all()
	sim.step(game, 0.5, {0: Sim.FLAT, 1: Sim.FLAT, 2: Sim.FLAT, 3: Sim.FLAT})
	var p0: Vector2 = game._racers[0].pos
	var p1: Vector2 = game._racers[1].pos
	sim.step(game, 1.0, {0: func(t): return Sim.ramp(t, 0.0, 20.0), 1: func(t): return Sim.ramp(t, 0.0, -20.0), 2: Sim.FLAT,
			3: Sim.FLAT})
	var d0: Vector2 = game._racers[0].pos - p0
	var d1: Vector2 = game._racers[1].pos - p1
	_check(d0.y > 1.0 and absf(d0.x) < 0.2,
			"top of the phone up: the car goes down the screen (%.2f m) and not sideways (%.3f m, REQ-3D-6)" % [d0.y, d0.x])
	_check(d1.y < -1.0 and absf(d1.x) < 0.2,
			"top of the phone down: the car goes up the screen (%.2f m) and not sideways (%.3f m)" % [d1.y, d1.x])
	_flat_all()
	game._racers[2].vel = Vector2.ZERO
	sim.step(game, 0.7, {0: Sim.FLAT, 1: Sim.FLAT, 2: func(t): return Sim.ramp(t, -20.0), 3: Sim.FLAT})
	var r2 = game._racers[2]
	var off := absf(wrapf(r2.angle + PI * 0.5, -PI, PI))
	_check(r2.vel.x < -1.0 and off <= deg_to_rad(15.0) + 0.001,
			"a car driven to the left faces left, within 15 degrees: %.0f degrees off" % rad_to_deg(off))


## REQ-MR-2 and REQ-MR-5: tilt gives acceleration (no dead zone, no speed limit), the car keeps its speed and slows by damping; a
## car that goes past the edge of the track is put back and loses part of its speed.
func _motion() -> void:
	print("race: acceleration, damping and the edge")
	var game: Control = await sim.start(Race, {"track_choice": "1", "difficulty": "medium"})
	_flat_all()
	sim.through_countdown(game)
	var r = game._racers[0]
	var tr = game.track
	var start_arc := 20.0
	var dir: Vector2 = tr.dir_at(start_arc)
	var speeds := {}
	for deg in [3.0, 6.0, 12.0]:
		r.pos = tr.point_at(start_arc)
		r.vel = Vector2.ZERO
		_flat_all()
		sim.step(game, 0.5, {0: func(t): return Sim.ramp(t, 0.0, deg)})   # The top of the phone up: the car goes down the screen.
		speeds[deg] = r.vel.length()
	_check(speeds[3.0] > 0.1, "REQ-MR-2: 3 degrees of tilt already give a speed (no dead zone): %.2f m/s" % speeds[3.0])
	_check(speeds[6.0] > 1.6 * speeds[3.0] and speeds[12.0] > 1.6 * speeds[6.0],
			"REQ-MR-2: the speed after 0.5 s grows with the tilt (3, 6, 12 degrees: %.1f, %.1f, %.1f m/s)"
			% [speeds[3.0], speeds[6.0], speeds[12.0]])
	# Damping: with a flat phone the speed falls by exp(-DAMPING * t), it does not stop at once and does not stay.
	_flat_all()
	r.pos = tr.point_at(start_arc)
	r.vel = dir * 8.0
	sim.step(game, 1.0, {0: Sim.FLAT})
	var kept: float = r.vel.length() / 8.0
	_check(kept > 0.30 and kept < 0.45,
			"REQ-MR-2: a flat phone: 1 s later the car keeps %.0f %% of its speed (exp(-1) = 37 %%)" % (kept * 100.0))
	# No speed limit: a car at 40 m/s is not held back to a top speed.
	r.pos = tr.point_at(start_arc)
	r.vel = dir * 40.0
	sim.step(game, Sim.DT, {0: Sim.FLAT})
	_check(r.vel.length() > 38.5, "REQ-MR-2: there is no speed limit (40 m/s is still %.1f m/s one tick later)" % r.vel.length())
	# REQ-MR-5: past the edge, the car is put back inside the road and bounces with a part of its speed.
	var q: Dictionary = tr.query(tr.point_at(start_arc))
	var side := Vector2(-dir.y, dir.x)
	var limit: float = tr.half_width - game.R
	r.pos = tr.point_at(start_arc) + side * (tr.half_width + 1.5)
	r.vel = side * 8.0
	sim.step(game, Sim.DT, {0: Sim.FLAT})
	var back: Dictionary = tr.query(r.pos)
	_check(q.dist < 0.01 and back.dist <= limit + 0.01,
			"REQ-MR-5: a car 1.5 m past the edge is put back on the road (%.2f m from the line, limit %.2f)" % [back.dist, limit])
	var out_speed: float = r.vel.dot(side)
	_check(out_speed < 0.0 and absf(out_speed) < 8.0 * 0.6 and absf(out_speed) > 8.0 * 0.3,
			"REQ-MR-5: it bounces back and loses part of its speed (8 m/s out, %.1f m/s in)" % out_speed)


## Test 9.7a, 9.7b: the arrow for a car that is out of view stays in the safe margin and names the distance.
func _edge_markers() -> void:
	print("race: edge markers")
	var game: Control = await sim.start(Race, {"track_choice": "1", "difficulty": "hard"})
	_flat_all()
	sim.through_countdown(game)
	var tr = game.track
	var lead_arc := minf(tr.length - 12.0, 130.0)
	var back_arc := lead_arc - 100.0
	game._racers[0].pos = tr.point_at(lead_arc)
	game._racers[0].arc = lead_arc
	game._racers[1].pos = tr.point_at(back_arc)
	game._racers[1].arc = back_arc
	game._cam_set = false
	for i in 200:
		game._game_tick(Sim.DT)
	var lead_arc_now: float = game._racers[0].arc
	var markers: Array = game.edge_markers()
	var rect := Rect2(60.0, 136.0, 1800.0, 884.0).grow(0.01)
	var m: Dictionary = markers[0] if not markers.is_empty() else {}
	var gap := roundi(game._lead().arc - game._racers[1].arc)
	_check(markers.size() >= 1 and m.slot == 1 and rect.has_point(m.pos),
			"the arrow of a car 100 m behind is inside the 60 px margin and under the bar: %s" % str(m.get("pos")))
	_check(not markers.is_empty() and is_equal_approx((m.dir as Vector2).length(), 1.0), "the arrow direction is a unit vector")
	_check(not markers.is_empty() and m.text == "%d m behind" % gap and gap >= 95,
			"the arrow says '%d m behind' (the lead minus the car, rounded)" % gap)
	_check(game.player(1).color == Protocol.PLAYER_COLORS[1], "the arrow is drawn in the color of its car (slot 1)")
	# The leader goes on for 5 s: the gap grows.
	game._racers[0].vel = Vector2.ZERO
	var before := gap
	sim.step(game, 5.0, {0: func(t): return Sim.ramp(t, 0.0, -25.0), 1: Sim.FLAT, 2: Sim.FLAT, 3: Sim.FLAT})
	var after := roundi(game._lead().arc - game._racers[1].arc)
	var m2: Array = game.edge_markers()
	_check(after > before and not m2.is_empty() and m2[0].text == "%d m behind" % after,
			"5 s later the gap grew from %d m to %d m and the text follows" % [before, after])
	game._racers[1].pos = game._racers[0].pos + Vector2(1.0, 1.0)
	game._racers[1].arc = game._racers[0].arc
	game._racers[2].pos = game._racers[0].pos + Vector2(-1.0, 1.0)
	game._racers[3].pos = game._racers[0].pos + Vector2(1.0, 2.0)
	game._racers[2].arc = game._racers[0].arc
	game._racers[3].arc = game._racers[0].arc
	game._cam_set = false
	for i in 120:
		game._game_tick(Sim.DT)
	_check(game.edge_markers().is_empty() or lead_arc_now > 0.0 and game.edge_markers().size() < 3,
			"cars that are in view get no arrow")


## Test 9.14f (REQ-MR-41, REQ-MR-42): 4 cars, one far ahead: the leader stays in view, every car that is out of view has an
## arrow in its color inside the 60 px margin and under the bar, the text names the meters within 3 m, the middle of the pack
## is in the lower half of the screen.
func _spread_pack() -> void:
	print("race: a pack that is spread out")
	var game: Control = await sim.start(Race, {"track_choice": "1", "difficulty": "hard"})
	_flat_all()
	sim.through_countdown(game)
	var tr = game.track
	var lead_arc := minf(tr.length - 12.0, 130.0)
	var behind := {0: 0.0, 1: 45.0, 2: 70.0, 3: 110.0}   # Meters behind the leader along the track.
	for s in 4:
		var arc: float = lead_arc - float(behind[s])
		game._racers[s].pos = tr.point_at(arc)
		game._racers[s].arc = arc
		game._racers[s].vel = Vector2.ZERO
	game._cam_set = false
	sim.step(game, 1.5, {0: Sim.FLAT, 1: Sim.FLAT, 2: Sim.FLAT, 3: Sim.FLAT})
	var size: Vector2 = game.size
	var window := Rect2(Vector2.ZERO, size)
	var lead_screen := _screen_of(game, game._racers[0].pos)
	_check(window.grow(-60.0).has_point(lead_screen) and lead_screen.y > 136.0,
			"the leader stays in view: %s on a %s screen, under the bar" % [str(lead_screen), str(size)])
	var markers: Array = game.edge_markers()
	var by_slot := {}
	for m in markers:
		by_slot[m.slot] = m
	var rect := Rect2(60.0, 136.0, size.x - 120.0, size.y - 136.0 - 60.0).grow(0.01)
	var out_of_view := 0
	var all_ok := true
	var texts_ok := true
	for s in [1, 2, 3]:
		var sp := _screen_of(game, game._racers[s].pos)
		if window.has_point(sp):
			continue
		out_of_view += 1
		if not by_slot.has(s):
			all_ok = false
			print("    car %d is out of view (%s) and has no arrow" % [s, str(sp)])
			continue
		var m: Dictionary = by_slot[s]
		var meters := float(String(m.text).split(" ")[0])
		var real: float = float(behind[s])
		print("    car %d: arrow at %s, text '%s', real %.0f m" % [s, str(m.pos), m.text, real])
		all_ok = all_ok and rect.has_point(m.pos)
		texts_ok = texts_ok and absf(meters - real) <= 3.0 and m.text == "%d m behind" % roundi(meters)
	_check(out_of_view >= 2 and all_ok,
			"%d cars are out of view and each has an arrow inside the 60 px margin and under the bar" % out_of_view)
	_check(texts_ok, "the text of each arrow names the meters within 3 m of the real distance")
	_check(not by_slot.has(0), "the leader has no arrow")
	var colors_ok := true
	for s in by_slot:
		colors_ok = colors_ok and game.player(s).color == Protocol.PLAYER_COLORS[s]
	_check(colors_ok and not by_slot.is_empty(), "each car that has an arrow plays in the color of its slot")
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s in 4:
		lo = lo.min(game._racers[s].pos)
		hi = hi.max(game._racers[s].pos)
	var middle := _screen_of(game, (lo + hi) * 0.5)
	_check(middle.y > size.y * 0.5,
			"the middle of the pack is in the lower half of the screen (y %.0f of %.0f)" % [middle.y, size.y])


## The screen position of a point of the track, in screen units (the camera is `_cam`, the anchor is 620 down).
func _screen_of(game: Control, p: Vector2) -> Vector2:
	return (p - game._cam) * Race.SCALE + Vector2(game.size.x * 0.5, Race.ANCHOR_Y)


## Test 9.8b: the others have 4 s after the first car finishes, then the result menu opens.
func _end_delay() -> void:
	print("race: end delay")
	var game: Control = await sim.start(Race, {"track_choice": "2", "difficulty": "easy"})
	_flat_all()
	sim.through_countdown(game)
	var tr = game.track
	game._racers[0].pos = tr.point_at(game.finish_arc - 0.1)
	game._racers[0].arc = game.finish_arc - 0.1
	game._racers[0].vel = Vector2(0.0, -3.0) * 1.0
	game._racers[0].vel = tr.dir_at(game.finish_arc) * 3.0
	var flat := {0: Sim.FLAT, 1: Sim.FLAT, 2: Sim.FLAT, 3: Sim.FLAT}
	var t_first := -1.0
	var t_open := -1.0
	for i in 600:
		sim.step(game, Sim.DT, flat)
		if t_first < 0.0 and game._first_finish_time >= 0.0:
			t_first = game._round.time
		if game.is_over and t_open < 0.0:
			t_open = game._round.time
			break
	_check(t_first > 0.0 and t_open - t_first >= 4.0 - 0.001 and t_open - t_first <= 5.0,
			"the result menu opens %.2f s after the first car finished (4.0 to 5.0, REQ-MR-12)" % (t_open - t_first))
	_check(game._winner == 0 and game._racers[0].finish_time > 0.0, "the winner is car 0 with a finish time > 0")


## Test 9.9d, 9.13c, 9.13f: Try again plays the same track, with the same obstacles and scenery, and the same theme. Two
## random tracks have different seeds.
func _restart_and_seeds() -> void:
	print("race: restart and seeds")
	var a: Control = await sim.start(Race, {"track_choice": "random", "difficulty": "medium", "race_theme": "space"})
	var b_seed := -1
	var seed_a: int = a.start_props.track_seed
	var bumpers := str(a._bumpers)
	var kinds := str(a._bumper_kinds)
	var decor := str(a._decor)
	a.restart()
	await sim.frames(2)
	var again: Control = sim.app.current_screen()
	again.set_process(false)
	_check(again != a and again.track_seed == seed_a and str(again._bumpers) == bumpers and str(again._bumper_kinds) == kinds
			and str(again._decor) == decor, "Try again: the same seed, obstacles, obstacle pictures and scenery (REQ-MR-33, REQ-MR-54)")
	_check(again.start_props.race_theme == "space" and again.race_theme == "space", "Try again keeps the theme (REQ-MR-45)")
	var b: Control = await sim.start(Race, {"track_choice": "random", "difficulty": "medium"})
	b_seed = b.start_props.track_seed
	_check(b_seed != seed_a and not MarbleTrack.FIXED_SEEDS.has(b_seed) and not MarbleTrack.FIXED_SEEDS.has(seed_a),
			"two random starts give different seeds that are not fixed tracks: %d, %d (REQ-MR-53)" % [seed_a, b_seed])


## Test 9.9a, 9.9b, 9.13a: the settings view.
func _settings_view() -> void:
	print("race: settings view")
	GameSettings.clear()
	sim.app.go_game_settings("marble_race")
	await sim.frames(4)
	var sv: Control = sim.app.current_screen()
	sim.app.go_games()
	await sim.frames(6)
	var tiles: Array = sim.app.current_screen()._tiles.filter(func(t: Button) -> bool: return String(t.game.id) == "marble_race")
	_check(tiles.size() == 1 and tiles[0].game.title == "registry.marble_race",
			"REQ-MR-30: the Games screen has one Car Race tile")
	sim.app.go_game_settings("marble_race")
	await sim.frames(4)
	sv = sim.app.current_screen()
	_check(sv.rows.size() == 3 and sv.rows[0].get_script() == sv.rows[1].get_script() and sv.rows[2].tiles.size() == 11
			and sv.start_button != null and sv.back_button != null
			and sv.back_button.global_position.x < sv.start_button.global_position.x,
			"REQ-MR-30: the settings view has Difficulty, Theme, the track list, then Back and Start")
	var theme_row: Control = sv.rows[1]
	var shown: Array = []
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	for i in 3:
		shown.append(theme_row._value.text)
		theme_row._gui_input(right)
	_check(shown == ["CANDY", "SPACE", "JUNGLE"] and theme_row.value == "jungle",
			"the Theme row shows CANDY, SPACE, JUNGLE in this order, starting with Candy: %s" % str(shown))
	var picker: Control = sv.rows[2]
	var labels := picker.find_children("*", "Label", true, false)
	_check(picker.tiles.size() == 11 and labels.is_empty(), "the track list has 11 tiles (10 sketches and ?) and no text")
	var same := true
	for d in ["easy", "medium", "hard"]:
		for i in 10:
			same = same and picker.tiles[i].sketch == MarbleTrack.make(MarbleTrack.FIXED_SEEDS[i], d).points
	_check(same and picker.tiles[10].sketch.is_empty(),
			"tile i is the line of the track of fixed seed i at every difficulty; the 11th is the random one (REQ-MR-53)")
	GameSettings.clear()


func _names() -> void:
	var expected := {"registry.marble_race": ["CAR RACE", "מירוץ מכוניות"], "registry.candy": ["CANDY", "ממתקים"],
			"registry.space": ["SPACE", "חלל"], "registry.jungle": ["JUNGLE", "ג׳ונגל"]}
	var ok := true
	for key in expected:
		Lang.set_language("en")
		ok = ok and Lang.t(key) == expected[key][0]
		Lang.set_language("he")
		ok = ok and Lang.t(key) == expected[key][1] and Lang.t(key).strip_edges() != ""
	Lang.set_language("en")
	_check(ok, "the 4 names of Car Race and its themes are the exact English and Hebrew texts")


## REQ-MR-10: the order is the finished cars by time, then the others by distance along the track. REQ-MR-11: a player who
## leaves is removed from the race, and the race goes on with the others. This runs last: it takes a phone away.
func _standings_and_leave() -> void:
	print("race: order and a player that leaves")
	var game: Control = await sim.start(Race, {"track_choice": "1", "difficulty": "easy"})
	_flat_all()
	sim.through_countdown(game)
	game._racers[0].finish_time = 25.0
	game._racers[1].arc = 80.0
	game._racers[2].finish_time = 20.0
	game._racers[3].arc = 100.0
	game._racers[2].arc = 10.0   # A finished car stays before a car that is further along but did not finish.
	game._racers[0].arc = 5.0
	var order: Array = game.standings().map(func(r) -> int: return r.slot)
	_check(order == [2, 0, 3, 1],
			"finished cars first by time (20 s, 25 s), then the others by distance (100 m, 80 m): %s (REQ-MR-10)" % str(order))
	sim.clients[1].leave()
	var waited := Time.get_ticks_msec()
	while game.player(1).is_present() and Time.get_ticks_msec() - waited < 5000:
		await sim.frames(1)
	game._prune_participants()   # What _process() does in every frame.
	sim.step(game, 0.1, {0: Sim.FLAT, 2: Sim.FLAT, 3: Sim.FLAT})
	order = game.standings().map(func(r) -> int: return r.slot)
	_check(not game.player(1).is_present() and not game._racers.has(1) and order.size() == 3
			and order.slice(0, 2) == [2, 0] and not order.has(1) and not game.is_over,
			"a player who leaves is out of the order and the race goes on with the others: %s (REQ-MR-11)" % str(order))
