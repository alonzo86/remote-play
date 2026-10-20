extends SceneTree
## Banana Party with simulated phones, stepped by hand (REQ-SS-*, test 10 of docs/MANUAL_TESTS.md). Run:
##   godot --headless --path . --script tests/smoke_banana.gd -- --role=tv

const Sim = preload("res://tests/sim_b.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const PuffField = preload("res://scripts/game/snowball_splat/puff_field.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")
const Medals = preload("res://scripts/game/medals.gd")

var _fails := 0
var _checks := 0
var Game
var sim


func _initialize() -> void:
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
	Game = load("res://scripts/game/snowball_splat/snowball_splat_game.gd")
	sim = Sim.new(self)
	GameSettings.clear()
	await sim.join(1)
	sim.settle(0, Sim.FLAT)
	await _aim()
	await _drift()
	await _golden_and_species()
	await _round_and_medals()
	await sim.join(3)
	_cursor_colors()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Starts a round, steps out the countdown with the phone flat and returns the game at GO.
func _play(props := {}) -> Control:
	var game: Control = await sim.start(Game, props)
	var p = sim.app.server.players[0]
	sim.settle(0, Sim.FLAT)
	p.recenter()
	sim.through_countdown(game, {0: Sim.FLAT})
	return game


## Points the phone `yaw` radians to the left and `elev` radians up from the pose of GO (fusion state set directly).
func _point(yaw_deg: float, elev_deg: float) -> void:
	var p = sim.app.server.players[0]
	p.orientation.yaw = deg_to_rad(yaw_deg)
	p.orientation.up = Vector3(0.0, sin(deg_to_rad(elev_deg)), cos(deg_to_rad(elev_deg)))


## Test 10.2a, 10.2b: the cursor follows the phone in four directions, 25 degrees reaches the edge, 40 degrees stays inside.
func _aim() -> void:
	print("banana: aim")
	var game: Control = await _play({"seed": 3})
	var area: Rect2 = game._area()
	var c := area.get_center()
	var at := func(yaw: float, elev: float) -> Vector2:
		_point(yaw, elev)
		game._game_tick(Sim.DT)
		return game._throwers[0].aim
	var right: Vector2 = at.call(-10.0, 0.0)
	var left: Vector2 = at.call(10.0, 0.0)
	var up: Vector2 = at.call(0.0, 10.0)
	var down: Vector2 = at.call(0.0, -10.0)
	_check(right.x > c.x + 100.0 and left.x < c.x - 100.0 and absf(right.y - c.y) < 1.0 and absf(left.y - c.y) < 1.0,
			"turning the phone 10 degrees right / left moves the cursor right / left of the center (REQ-SS-3)")
	_check(up.y < c.y - 100.0 and down.y > c.y + 100.0 and absf(up.x - c.x) < 1.0 and absf(down.x - c.x) < 1.0,
			"raising / lowering the phone 10 degrees moves the cursor up / down (REQ-SS-3)")
	var edge := absf(( at.call(-25.0, 0.0) as Vector2).x - area.end.x) < area.size.x * 0.1 \
			and absf((at.call(25.0, 0.0) as Vector2).x - area.position.x) < area.size.x * 0.1 \
			and absf((at.call(0.0, 25.0) as Vector2).y - area.position.y) < area.size.y * 0.1 \
			and absf((at.call(0.0, -25.0) as Vector2).y - area.end.y) < area.size.y * 0.1
	_check(edge, "25 degrees puts the cursor at the edge of the play area, in all four directions (REQ-SS-3)")
	var inside := true
	for pair in [[-40.0, 0.0], [40.0, 0.0], [0.0, 40.0], [0.0, -40.0], [-40.0, 40.0], [40.0, -40.0]]:
		inside = inside and area.grow(0.01).has_point(at.call(pair[0], pair[1]))
	_check(inside, "40 degrees keeps the cursor inside the play area and its 60 px margin")
	_point(0.0, 0.0)


## Test 10.3a: a phone that lies still with a gyro bias and noise drifts less than 5 % of the width in 40 s (REQ-SS-3).
func _drift() -> void:
	print("banana: drift")
	var game: Control = await _play({"seed": 3})
	var p = sim.app.server.players[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var worst := 0.0
	for bias in [Vector3(0.03, 0.03, 0.03), Vector3(-0.03, 0.03, -0.03), Vector3(0.03, -0.03, 0.03), Vector3(-0.03, -0.03, -0.03)]:
		sim.settle(0, Sim.FLAT)
		p.recenter()
		game._game_tick(Sim.DT)
		var start: Vector2 = game._throwers[0].aim
		for i in 2400:   # 40 s
			var noise := Vector3(rng.randfn(0.0, 0.005), rng.randfn(0.0, 0.005), rng.randfn(0.0, 0.005))
			sim.feed(0, Sim.FLAT, bias + noise)
			if i % 6 == 0:
				game._game_tick(Sim.DT * 6.0 / 6.0)
		worst = maxf(worst, game._throwers[0].aim.distance_to(start))
	_check(worst < 96.0, "a still phone with a gyro bias of 0.03 rad/s and noise: the cursor drifted %.0f px in 40 s (< 96 px = 5 %% of 1920)" % worst)


## Test 10.4c (data part), 10.5e: every animal that is hit leaves its own effect, the golden monkey gives +100.
func _golden_and_species() -> void:
	print("banana: golden and species")
	var game: Control = await _play({"seed": 3})
	var area: Rect2 = game._area()
	game._field.bushes.clear()
	var seen := {}
	for kind in PuffField.KINDS:
		game._field.puffs.clear()
		game._throwers[0].reload_left = 0.0
		var lane := 0
		for i in PuffField.LANES.size():
			if PuffField.LANES[i].kinds.has(kind):
				lane = i
		var puff: PuffField.Puff = game._field._add(lane, kind)
		puff.x = 900.0
		game._field.puffs.clear()
		game._field.puffs.append(puff)
		var score_before: float = game._board.score(0)
		game._throwers[0].aim = PuffField.center_of(puff, area)
		game._throw(0, area)
		for f in game._flights:
			if f.age >= 0.0:
				f.age = Game.FLIGHT_TIME
		game._fly(0.0, area)
		var gain: float = game._board.score(0) - score_before
		var effect = null
		for e in game._effects:
			if e.age >= 0.0 and e.kind == "hit" and e.species == kind:
				effect = e
		seen[kind] = effect != null
		_check(effect != null and gain == float(PuffField.KINDS[kind].points) and effect.text == "+%d" % PuffField.KINDS[kind].points,
				"a hit on a %s gives +%d points and an effect of its own species (REQ-SS-7, 13, 25)" % [kind, PuffField.KINDS[kind].points])
		for e in game._effects:
			e.age = -1.0


## Test 10.6a, 10.6b, 10.10e: the round lasts 60 s of play; the medal and the title for each difficulty.
func _round_and_medals() -> void:
	print("banana: round and medals")
	var game: Control = await _play({"seed": 3})
	var start: float = game._round.time
	var t := 0.0
	var remaining_first: float = game._round.remaining()
	while not game.is_over and t < 70.0:
		game._game_tick(Sim.DT)
		t += Sim.DT
	_check(game.is_over and t >= 58.0 and t <= 62.0 and absf(start) < 0.05 and remaining_first > 59.9,
			"the round ends %.1f s after GO (58 to 62, REQ-SS-14)" % t)
	var cases := {"easy": [[169, Medals.NONE], [170, "bronze"], [339, "bronze"], [340, "silver"], [509, "silver"], [510, "gold"]],
			"medium": [[149, Medals.NONE], [150, "bronze"], [299, "bronze"], [300, "silver"], [449, "silver"], [450, "gold"]],
			"hard": [[119, Medals.NONE], [120, "bronze"], [239, "bronze"], [240, "silver"], [359, "silver"], [360, "gold"]]}
	for d in cases:
		var ok := true
		var titles_ok := true
		for case in cases[d]:
			var g: Control = await _play({"seed": 3, "difficulty": d})
			g._board.add(0, case[0])
			g._finish()
			var tier := Medals.medal(case[0], PuffField.LEVELS[d].tiers)
			ok = ok and tier == case[1]
			var labels: Array = g._menu_box.find_children("*", "Label", true, false)
			var title: String = labels[0].text
			var want: String = "NO MEDAL THIS TIME (%s)" % d.to_upper() if case[1] == Medals.NONE else d.to_upper()
			titles_ok = titles_ok and title == want
			if title != want:
				print("    ", d, " ", case[0], ": '", title, "' instead of '", want, "'")
		_check(ok, "%s: scores around the tiers %s give none, bronze, bronze, silver, silver, gold" % [d, str(PuffField.LEVELS[d].tiers)])
		_check(titles_ok, "%s: the result title is the difficulty, or NO MEDAL THIS TIME (%s) under the first tier" % [d, d.to_upper()])


## Test 10.7a: the cursor of each of 4 phones has the color of the square on that phone.
func _cursor_colors() -> void:
	print("banana: colors")
	var pc: Array = Protocol.PLAYER_COLORS
	var ok: bool = sim.clients.size() == 4
	var distinct := {}
	for s in 4:
		ok = ok and sim.clients[s].color == pc[s] and sim.app.server.players[s].color == pc[s]
		distinct[pc[s].to_html()] = true
	_check(ok and distinct.size() == 4, "4 phones: the color of each phone is the color of its cursor, all four different (REQ-GM-24)")
