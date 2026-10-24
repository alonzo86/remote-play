extends SceneTree
## The effects and the buzzes of the events in the "Sound and haptics" table of each game file (docs/games/<id>.md,
## REQ-GM-49a to 49c, REQ-GM-43): for every event the game is put in the state where the event happens, the game's own code runs,
## and the test checks that the effect of the table was started (`Sound.sfx_played`) and that the phone of the player got the buzz
## of the table (a real client on the loopback network, so the TV message is what is counted). Events without a buzz in the table
## must send none. The games are stepped by hand where they have a clock; the events of Tennis are the events that the match
## engines (tests/tennis_rules.gd checks that the engine makes them) and are given to the game's event handler.
## That the effect plays is checked; how it sounds is not (Test 18, item 6a: the maze wall hit is in tests/audio_phones.gd and the
## blob that hits the edge, the blobs that touch and the new leader of Paint Grab are in tests/smoke_paint.gd). Run:
##   godot --headless --path . --script tests/audio_events.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const SpaceField = preload("res://scripts/game/asteroid_blast/space_field.gd")
const PuffField = preload("res://scripts/game/snowball_splat/puff_field.gd")

const ASTEROID := "res://scripts/game/asteroid_blast/asteroid_blast_game.gd"
const SUMO := "res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd"
const PAINT := "res://scripts/game/paint_grab/paint_grab_game.gd"
const SHEEP := "res://scripts/game/sheep_herding/sheep_herding_game.gd"
const BANANA := "res://scripts/game/snowball_splat/snowball_splat_game.gd"
const MAZE := "res://scripts/game/maze/maze_game.gd"
const RACE := "res://scripts/game/marble_race/marble_race.gd"
const BOWLING := "res://scripts/game/bowling/bowling_game.gd"
const GOLF := "res://scripts/game/mini_golf/mini_golf_game.gd"
const TENNIS := "res://scripts/game/tennis/tennis_game.gd"
const DT := 1.0 / 60.0

var _checks := 0
var _fails := 0
var _app: Node
var _sound: Node
var _clients: Array = []
var _heard: Array[String] = []
var _buzz: Array = [[], [], [], []]   # For each phone: the ms of the buzzes that came after the last event started.
var _haptics_script: GDScript


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_sound = root.get_node("Sound")
	_haptics_script = load("res://scripts/game/haptics.gd")
	_sound.sfx_played.connect(func(id: String) -> void: _heard.append(id))
	load("res://scripts/game/game_settings.gd").clear()
	await _phones(3)
	await _asteroid()
	await _sumo()
	await _paint()
	await _sheep()
	await _banana()
	await _maze()
	await _race()
	await _bowling()
	await _golf()
	await _tennis()
	for c in _clients:
		c.leave()
	await _frames(10)


## `count` new simulated phones; the buzzes that reach each one are noted.
func _phones(count: int) -> void:
	_clients = await SimInput.connect_phones(self, _app, count, _clients)
	for i in _clients.size():
		_clients[i].haptic_requested.connect(func(ms: int) -> void: _buzz[i].append(ms))


## A game of `path`, stepped by hand, with all phones held flat.
func _game(path: String, props := {}) -> Control:
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	return SimInput.start_game(_app, load(path), props)


## Makes one event happen and checks the effects that were heard and the buzzes of the phones. `buzzes` is slot -> ms (or a list
## of ms) that the phone must have got; `quiet` says that the table has no buzz for the event, so no phone may get one. The game
## gets a new `Haptics`, so the pause between two buzzes of an earlier event does not hide this one.
func _event(game: Control, label: String, ids: Array, buzzes: Dictionary, trigger: Callable, quiet := false,
		not_ids := []) -> void:
	await create_timer(0.2).timeout   # The GO buzz of the countdown and other earlier buzzes are still on the way.
	_heard.clear()
	for b in _buzz:
		b.clear()
	_sound._last_ms.clear()
	if game.get("_haptics") != null:
		game._haptics = _haptics_script.new()
	trigger.call()
	await create_timer(0.2).timeout   # The buzz is a message over the network.
	var missing: Array = ids.filter(func(id: String) -> bool: return not _heard.has(id))
	var forbidden: Array = not_ids.filter(func(id: String) -> bool: return _heard.has(id))
	var lacking: Array = []
	for slot in buzzes:
		var wanted: Array = buzzes[slot] if buzzes[slot] is Array else [buzzes[slot]]
		for ms in wanted:
			if not _buzz[slot].has(ms):
				lacking.append("phone %d: %d ms" % [slot, ms])
	var noisy := false
	if quiet:
		for b in _buzz:
			noisy = noisy or not b.is_empty()
	var what := "%s: plays %s%s" % [label, str(ids), " and buzzes " + str(buzzes) if not buzzes.is_empty() else ""]
	if quiet:
		what += " and buzzes nobody"
	_check(missing.is_empty() and forbidden.is_empty() and lacking.is_empty() and not noisy,
			"%s (heard %s; buzzes %s%s%s)" % [what, str(_heard), str(_buzz.slice(0, _clients.size())),
			"; missing: " + str(missing) if not missing.is_empty() else "",
			"; wrongly heard: " + str(forbidden) if not forbidden.is_empty() else ""])


# ---- Star Shield (REQ-AB-S1 to S5) ----

func _asteroid() -> void:
	print("Star Shield")
	var game := _game(ASTEROID, {"difficulty": "medium"})
	game.field.asteroids.clear()
	var ship: SpaceField.Ship = game.field.ships[0]
	await _event(game, "an asteroid is destroyed", ["blast_boom"], {}, func() -> void:
		game._on_event({"t": "kill", "x": 900.0, "y": 300.0, "size": 1}))
	await _event(game, "a ship takes an upgrade", ["blast_pickup"], {0: 30}, func() -> void:
		var up := SpaceField.Upgrade.new()
		up.kind = SpaceField.SHIELD
		up.x = ship.x
		up.y = SpaceField.SHIP_Y
		game.field.upgrades.append(up)
		game._process(DT)
		game._process(DT))
	await _event(game, "a force field takes a hit", ["blast_shield"], {0: 80}, func() -> void:
		game.field._make(1, ship.x, SpaceField.SHIP_Y - 30.0, RandomNumberGenerator.new())
		game._process(DT))
	await _event(game, "a ship is lost", ["blast_lost"], {0: 400}, func() -> void:
		game.field._make(1, ship.x, SpaceField.SHIP_Y - 30.0, RandomNumberGenerator.new())
		game._process(DT)
		game._process(DT))
	var wave := _game(ASTEROID, {"difficulty": "medium"})
	await _event(wave, "a wave ends", ["blast_wave"], {}, func() -> void:
		SimInput.run(wave, 31.0, DT, func(_t: float) -> void: wave.field.asteroids.clear()))


# ---- Sumo Bumpers (REQ-SB-S1 to S4) ----

func _sumo() -> void:
	print("Sumo Bumpers")
	var game := _game(SUMO, {"difficulty": "medium"})
	for i in 3:
		game._bodies[i].pos = game.arena.start_spots(3)[i]
		game._bodies[i].vel = Vector2.ZERO
	game._bodies[0].pos = Vector2.ZERO
	game._bodies[1].pos = Vector2(0.0, 250.0)
	SimInput.set_tilt(_app.server.players[0], Vector2(0.5, 0.0))
	await _event(game, "a bumper dashes", ["sumo_dash"], {0: 30}, func() -> void:
		game._on_button(Protocol.BTN_A, 0)
		game._process(DT))
	SimInput.set_tilt(_app.server.players[0], Vector2.ZERO)
	await _event(game, "two bumpers bump above the buzz speed", ["sumo_bump"], {0: 20, 1: 20}, func() -> void:
		game._bodies[0].pos = Vector2.ZERO
		game._bodies[1].pos = Vector2(50.0, 0.0)
		game._bodies[0].vel = Vector2(350.0, 0.0)
		game._bodies[1].vel = Vector2.ZERO
		game._bump(0, 1))
	var fall := func(slot: int) -> void:
		game._bodies[slot].vel = Vector2.ZERO
		game._bodies[slot].pos = Vector2(game.arena.radius() + 60.0, 0.0)
		game._process(DT)
	game._bodies[0].pos = Vector2(-120.0, 0.0)
	game._bodies[0].vel = Vector2.ZERO
	game._bodies[1].pos = Vector2(0.0, 250.0)
	game._bodies[1].vel = Vector2.ZERO
	game._bodies[2].pos = Vector2(120.0, 0.0)
	game._bodies[2].vel = Vector2.ZERO
	await _event(game, "a bumper falls", ["sumo_fall"], {1: 80}, func() -> void: fall.call(1), false, ["sumo_round_win"])
	await _event(game, "the last bumper but one falls: the round has a winner", ["sumo_fall", "sumo_round_win"], {2: 80, 0: 120},
			func() -> void: fall.call(2))


# ---- Paint Grab (REQ-PG-S1 to S5) ----

func _paint() -> void:
	print("Paint Grab")
	var game := _game(PAINT, {"difficulty": "medium", "seed": 3})
	SimInput.to_play(game, func() -> bool: return game._round.is_counting())
	var tile: float = game.floor_map.size().x / float(game.floor_map.cols)
	var spot := Vector2(2.5, 2.5) * tile
	await _event(game, "a blob paints a tile", ["paint_tile"], {}, func() -> void:
		game._bodies[0].pos = spot
		game._paint_under(0), true, ["paint_steal"])
	await _event(game, "a blob takes a tile of another color", ["paint_steal"], {1: 20}, func() -> void:
		game._bodies[1].pos = spot
		game._paint_under(1), false, ["paint_tile"])


# ---- Sheep Herding (REQ-SH-S1 to S3, REQ-SH-12) ----

func _sheep() -> void:
	print("Sheep Herding")
	var game := _game(SHEEP, {"difficulty": "medium", "seed": 3})
	SimInput.to_play(game, func() -> bool: return game._round.is_counting())
	await _event(game, "a sheep gets scared", ["sheep_baa"], {}, func() -> void:
		game._on_flock_event({"t": "startled", "i": 0, "slot": 0, "pos": Vector2(900.0, 500.0)}), true)
	await _event(game, "a sheep walks into the pen: the dog that scared it buzzes", ["sheep_pen"], {1: 40}, func() -> void:
		game._on_flock_event({"t": "penned", "i": 0, "slot": 1, "pos": Vector2(1600.0, 600.0)}))
	await _event(game, "two dogs touch", ["sheep_bump"], {}, func() -> void:
		game.dogs[0].pos = Vector2(300.0, 420.0)
		game.dogs[1].pos = Vector2(330.0, 420.0)
		game.dogs[0].vel = Vector2.ZERO
		game.dogs[1].vel = Vector2.ZERO
		game._process(DT), true)
	await _event(game, "every sheep is in the pen: the team wins and every phone buzzes", ["win"], {0: 400, 1: 400, 2: 400},
			func() -> void:
				for i in game.flock.sheep.size():
					game.flock.sheep[i].pos = game.pen.position + Vector2(70.0 + 60.0 * float(i % 4), 80.0 + 60.0 * float(i / 4))
					game.flock.sheep[i].penned = true
				SimInput.run(game, 2.5))


# ---- Banana Party (REQ-SS-S1 to S3) ----

func _banana() -> void:
	print("Banana Party")
	var game := _game(BANANA, {"seed": 3})
	SimInput.to_play(game, func() -> bool: return game._round.is_counting())
	var area: Rect2 = game._area()
	game._field.bushes.clear()
	game._field.puffs.clear()
	var land := func() -> void:
		for f in game._flights:
			if f.age >= 0.0:
				f.age = game.FLIGHT_TIME
		game._fly(0.0, area)
	await _event(game, "a press on A throws a banana", ["snow_throw"], {0: 15}, func() -> void:
		game._throwers[0].reload_left = 0.0
		game._throwers[0].aim = area.get_center()
		game._throw(0, area))
	await _event(game, "a banana misses", ["snow_miss"], {}, land, true, ["snow_hit"])
	game._throwers[0].reload_left = 0.0
	var puff: PuffField.Puff = game._field._add(1, "orangutan")
	puff.x = 900.0
	game._field.puffs.clear()
	game._field.puffs.append(puff)
	game._throwers[0].aim = PuffField.center_of(puff, area)
	game._throw(0, area)
	await create_timer(0.2).timeout   # The buzz of the throw has arrived before the buzz of the hit is counted.
	await _event(game, "a banana takes an animal", ["snow_hit", "snow_points"], {0: 40}, land, false, ["snow_miss"])


# ---- Treasure Maze (REQ-MZ-S1, S2) ----

func _maze() -> void:
	print("Treasure Maze")
	var game := _game(MAZE)
	SimInput.to_play(game, func() -> bool: return game._round.is_counting())
	var ball = game._balls[0]
	await _event(game, "a ball reaches the exit", ["maze_exit"], {int(ball.slot): 400}, func() -> void:
		ball.pos = game._exit_center()
		game._game_tick(DT))


# ---- Road Rally (REQ-MR-S1 to S4) ----

func _race() -> void:
	print("Road Rally")
	var game := _game(RACE, {"track_choice": "1", "difficulty": "medium"})
	SimInput.to_play(game, func() -> bool: return game._round.is_counting())
	var tr = game.track
	var r0 = game._racers[0]
	var r1 = game._racers[1]
	r1.pos = tr.point_at(30.0)
	var wall := func(speed: float) -> void:
		r0.pos = tr.point_at(10.0) + Vector2(1, 0) * (tr.half_width - game.R - 0.01)
		r0.vel = Vector2(1, 0) * speed
		r0.arc = 10.0
		game._step(1.0 / 120.0)
	await _event(game, "a car hits a wall", ["marble_wall"], {0: 20}, func() -> void: wall.call(4.0), false, ["marble_wall_hard"])
	await _event(game, "a car hits a wall hard (above twice the buzz speed)", ["marble_wall_hard"], {0: 20},
			func() -> void: wall.call(8.0))
	if game._bumpers.is_empty():
		_check(false, "the track 1 has an obstacle")
	else:
		var post: Vector2 = game._bumpers[0]
		await _event(game, "a car hits an obstacle", ["marble_bumper"], {0: 20}, func() -> void:
			r0.pos = post + Vector2(0.0, game.R + game.BUMPER_R - 0.01)
			r0.vel = Vector2(0.0, -8.0)
			game._step(1.0 / 120.0))
	await _event(game, "two cars touch", ["marble_marble"], {0: 20, 1: 20}, func() -> void:
		r0.pos = tr.point_at(8.0)
		r1.pos = r0.pos + Vector2(0.0, -(game.R * 2.0 - 0.02))
		r0.vel = Vector2(0.0, -6.0)
		r1.vel = Vector2.ZERO
		game._step(1.0 / 120.0))
	r1.pos = tr.point_at(30.0)
	r1.vel = Vector2.ZERO
	await _event(game, "a car crosses the line", ["marble_finish"], {0: 120}, func() -> void:
		r0.pos = tr.point_at(game.finish_arc + 0.5)
		r0.vel = Vector2.ZERO
		game._step(1.0 / 120.0))


# ---- Pin Pals (REQ-BW-S1 to S7) ----

func _bowling_game() -> Control:
	var game := _game(BOWLING, {"difficulty": "medium"})
	return game


func _bowling() -> void:
	print("Pin Pals")
	var game := _bowling_game()
	var on: int = game.rules.current_slot()
	await _event(game, "a turn starts", ["bowl_turn"], {on: 60}, func() -> void: game._start_turn())
	await _event(game, "the ball is let go", ["bowl_throw"], {on: 40}, func() -> void:
		game.detector.power = 0.8
		game._throw(on))
	await _event(game, "the ball hits the pins", ["bowl_pins"], {on: 40}, func() -> void:
		var guard := 0
		while game.phase == game.Phase.ROLL and guard < 1500:
			game._game_tick(DT)
			guard += 1)
	# A strike: all 10 pins are down with the first ball.
	var strike := _bowling_game()
	var s_on: int = strike.rules.current_slot()
	await _event(strike, "a strike", ["bowl_strike"], {s_on: 200}, func() -> void:
		strike._before = strike.sim.standing_mask()
		strike.sim.set_rack([false, false, false, false, false, false, false, false, false, false])
		strike._roll_done(), false, ["bowl_spare", "bowl_gutter"])
	# A spare: 7 pins with the first ball, the other 3 with the second.
	var spare := _bowling_game()
	var p_on: int = spare.rules.current_slot()
	spare._before = spare.sim.standing_mask()
	spare.sim.set_rack([true, true, true, false, false, false, false, false, false, false])
	spare._roll_done()
	spare._after_result()
	await _event(spare, "a spare", ["bowl_spare"], {p_on: 80}, func() -> void:
		spare._before = spare.sim.standing_mask()
		spare.sim.set_rack([false, false, false, false, false, false, false, false, false, false])
		spare._roll_done(), false, ["bowl_strike", "bowl_gutter"])
	# A gutter ball: it goes off the side and takes no pin. The table has no buzz for it.
	var gutter := _bowling_game()
	await _event(gutter, "the ball goes off the side", ["bowl_gutter"], {}, func() -> void:
		gutter._before = gutter.sim.standing_mask()
		gutter.sim.in_gutter = true
		gutter._roll_done(), true, ["bowl_strike", "bowl_spare"])


# ---- Mini Golf (REQ-MG-S1 to S7) ----

## A flat hole of 2 x 5 m with nothing on it (tests/golf_rules.gd has the same one).
func _flat_hole() -> Dictionary:
	return {"par": 2, "tee": Vector2(0.0, 1.0), "cup": Vector2(0.0, 5.0), "fairway": [Rect2(-1.0, 0.75, 2.0, 5.0)],
			"water": [], "bridges": [], "spinners": [], "blocks": [], "rocks": [], "movers": []}


## Rolls the ball of the game on `hole` from `from` with `speed`, tick after tick, until `effect` was heard or the ball stops.
func _roll_on(game: Control, hole: Dictionary, from: Vector2, speed: float, effect: String) -> void:
	game.sim.start(hole, from)
	game.sim.putt(0.0, speed)
	game.phase = game.Phase.ROLL
	var guard := 0
	while not game.sim.finished and not _heard.has(effect) and guard < 900:
		game._tick_roll(DT)
		guard += 1


func _golf() -> void:
	print("Mini Golf")
	var game := _game(GOLF, {"difficulty": "medium", "holes": "3"})
	await _event(game, "a turn starts", ["golf_turn"], {0: 60}, func() -> void: game._start_turn())
	await _event(game, "a hard putt (power above 0.6)", ["golf_putt"], {0: 60}, func() -> void:
		game.detector.power = 0.8
		game._putt(0))
	await _event(game, "a soft putt", ["golf_putt"], {0: 30}, func() -> void:
		game.detector.power = 0.3
		game._putt(0))
	var wall := _flat_hole()
	await _event(game, "the ball touches a wall", ["golf_wall"], {}, func() -> void:
		_roll_on(game, wall, Vector2(0.0, 5.0), 3.0, "golf_wall"), true)
	var rock := _flat_hole()
	rock.rocks = [Vector3(0.0, 3.0, 0.2)]
	await _event(game, "the ball touches a rock", ["golf_wall"], {}, func() -> void:
		_roll_on(game, rock, Vector2(0.0, 1.0), 3.0, "golf_wall"), true)
	var barrier := _flat_hole()
	barrier.movers = [{"rect": Rect2(-1.0, 3.0, 2.0, 0.2), "axis": "z", "amp": 0.0, "speed": 1.0}]
	await _event(game, "a sliding barrier touches the ball", ["golf_wall"], {}, func() -> void:
		_roll_on(game, barrier, Vector2(0.0, 3.1), 0.5, "golf_wall"), true)
	var blade := _flat_hole()
	blade.spinners = [{"c": Vector2(0.0, 3.0), "len": 0.5, "speed": 0.0}]
	await _event(game, "the ball touches a turning blade", ["golf_blade"], {}, func() -> void:
		_roll_on(game, blade, Vector2(0.0, 1.0), 3.0, "golf_blade"), true, ["golf_wall"])
	await _event(game, "the ball falls in the lake", ["golf_splash"], {}, func() -> void:
		game.sim.in_water = true
		game.sim.finished = true
		game._putt_done(), true, ["golf_hole", "golf_ace"])
	# A hole in one needs the first stroke of the player: a new game.
	var ace := _game(GOLF, {"difficulty": "medium", "holes": "3"})
	await _event(ace, "a hole in one", ["golf_ace"], {0: 200}, func() -> void:
		ace.sim.in_cup = true
		ace.sim.in_water = false
		ace._putt_done(), false, ["golf_hole"])
	# A hole in two strokes: every player misses once, then the first one holes out.
	var hole := _game(GOLF, {"difficulty": "medium", "holes": "3"})
	for i in _clients.size():   # The turns go round all the phones, so the first player is on turn again after the last one.
		hole.sim.in_cup = false
		hole.sim.in_water = false
		hole._putt_done()
		hole._after_result()
	await _event(hole, "the ball goes in the cup", ["golf_hole"], {0: 80}, func() -> void:
		hole.sim.in_cup = true
		hole.sim.in_water = false
		hole._putt_done(), false, ["golf_ace"])


# ---- Tennis (REQ-TN-S1 to S9) ----

func _tennis() -> void:
	print("Tennis")
	var game := _game(TENNIS, {"difficulty": "medium"})
	var team: Array = game.play.rules.teams[0]
	var team_buzz := {}
	for s in team:
		team_buzz[int(s)] = 80
	var events := func(list: Array) -> Callable:
		return func() -> void: game._handle_events(list)
	await _event(game, "the server tosses the ball", ["tennis_toss"], {}, events.call([{"t": "toss", "slot": 0}]), true)
	await _event(game, "a swing hits the ball", ["tennis_hit"], {0: 30}, events.call([{"t": "hit", "slot": 0, "green": false}]),
			false, ["tennis_great"])
	await _event(game, "a hit in the green part of the window", ["tennis_great"], {0: 60},
			events.call([{"t": "hit", "slot": 0, "green": true}]), false, ["tennis_hit"])
	await _event(game, "the machine hits the ball: never the great sound, no buzz", ["tennis_hit"], {},
			events.call([{"t": "hit", "slot": -1, "green": true}]), true, ["tennis_great"])
	await _event(game, "the ball bounces", ["tennis_bounce"], {}, events.call([{"t": "bounce", "pos": Vector2.ZERO}]), true)
	await _event(game, "the ball hits the net", ["tennis_net"], {}, events.call([{"t": "net"}]), true)
	await _event(game, "the ball lands out", ["tennis_out"], {}, events.call([{"t": "out", "pos": Vector2.ZERO}]), true)
	await _event(game, "a rally with the machine ends", ["tennis_out"], {}, events.call([{"t": "rally_over", "rally": 4, "best": 4,
			"reason": "out"}]), true)
	await _event(game, "a serve fault", ["tennis_fault"], {}, events.call([{"t": "fault", "reason": "net"}]), true)
	await _event(game, "a point is won", ["tennis_point"], team_buzz, events.call([{"t": "point", "team": 0, "reason": "out",
			"game": false, "match": false, "status": ""}]), false, ["tennis_game"])
	await _event(game, "a game is won", ["tennis_game"], team_buzz, events.call([{"t": "point", "team": 0, "reason": "out",
			"game": true, "match": false, "status": ""}]), false, ["tennis_point"])
	await _event(game, "the time is up", ["tennis_game"], {}, events.call([{"t": "time_up", "best": 4}]))
	await _event(game, "the match is over", ["tennis_game"], {}, events.call([{"t": "match_over", "winners": [0]}]))
