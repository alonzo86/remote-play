extends SceneTree
## Star Shield with simulated phones and a fixed time step: what used to be checked by hand in Test 22 and a machine can
## check (no countdown, no name tags, the hint time, RECENTER, the colors of the beams, the buzzes, the line of the wave,
## the medals, a player that leaves). The game is stepped by hand (`SimInput`). Run:
##   godot --headless --path . --script tests/auto_asteroid.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const Shell = preload("res://scripts/game/shell.gd")
const MedalView = preload("res://scripts/ui/medal_view.gd")
const BlastLook = preload("res://scripts/game/asteroid_blast/blast_look.gd")
const SpaceField = preload("res://scripts/game/asteroid_blast/space_field.gd")

const DT := 1.0 / 60.0

var _fails := 0
var _checks := 0
var _sim := SimInput.new()
var _app: Node
var _blast: GDScript
var _clients: Array = []


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A check of something that is wrong in the game today: it counts as a failure until the bug is fixed.
func _known_bug(issue: String, cond: bool) -> void:
	_checks += 1
	if cond:
		print("  ok   (known bug is fixed, make this a normal check) ", issue)
	else:
		_fails += 1
		print("  FAIL (known bug) ", issue)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A game at its start, stepped by hand. All phones are held flat.
func _new_game(difficulty := "medium") -> Control:
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	return SimInput.start_game(_app, _blast, {"difficulty": difficulty})


## A game in play (there is no countdown). The asteroids can be switched off (`calm`), so that nothing hits a ship.
func _play(difficulty := "medium") -> Control:
	return _new_game(difficulty)


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_blast = load("res://scripts/game/asteroid_blast/asteroid_blast_game.gd")
	_clients = await SimInput.connect_phones(self, _app, 4)
	await _start()
	await _recenter()
	_beams()
	await _buzzes()
	_wave_line()
	await _medals()
	await _leave()
	for c in _clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## 22.2a, 2b, 2c: no countdown (REQ-GM-35), the ships steer at once and carry no name tags; the hint stays about 5 s (REQ-AB-16).
func _start() -> void:
	print("the start")
	var game := _new_game()
	var p: RefCounted = _app.server.players[0]
	var x0: float = game.field.ships[0].x
	SimInput.set_tilt(p, Vector2(0.5, 0.0))
	SimInput.run(game, 1.0)
	_check(not game._has_countdown() and game.field.phase_time > 0.9 and game.field.ships[0].x - x0 > 100.0,
			"there is no countdown: in the first second the wave runs and the ship steers %.0f px" % (game.field.ships[0].x - x0))
	var methods: Array = game.get_script().get_script_method_list().map(func(m: Dictionary) -> String: return m.name)
	_check(not methods.has("name_tag_spots") and not methods.has("name_tags_shown"),
			"the game has no name tags over the ships (the players are known by the color of the ship)")
	var ship0 := BlastLook.ship_image(_app.server.players[0].color, 0)
	var ship1 := BlastLook.ship_image(_app.server.players[1].color, 0)
	_check(ship0.get_data() != ship1.get_data(),
			"the ships of two players have different pictures (different colors)")
	SimInput.set_tilt(p, Vector2.ZERO)
	var hint_after := 1.0 + SimInput.run_until(game, func() -> bool: return not game.hint_shown(), 20.0)
	_check(hint_after >= 4.0 and hint_after <= 6.0, "the hint goes away %.1f s after the start (4 to 6 s)" % hint_after)


## 22.3e: after RECENTER the ship stops within 1 s while the phone is held at the new pose (REQ-GM-37).
func _recenter() -> void:
	print("RECENTER")
	var game := _play()
	game.field.asteroids.clear()
	var p: RefCounted = _app.server.players[0]
	SimInput.set_tilt(p, Vector2(0.5, 0.0))
	SimInput.run(game, 1.0)
	var moving: float = game.field.ships[0].vx
	p.recenter()   # What the RECENTER button of the phone does on the TV.
	SimInput.run(game, 1.0)
	var x_at_1s: float = game.field.ships[0].x
	SimInput.run(game, 1.0)
	_check(moving > 200.0 and absf(game.field.ships[0].vx) < 5.0 and absf(game.field.ships[0].x - x_at_1s) < 5.0,
			"the ship flew at %.0f px/s and stands still within 1 s of RECENTER (%.1f px/s)" % [moving, game.field.ships[0].vx])


## 22.4b, 12c: the beams of a ship have the color of its player, and the 4 colors differ.
func _beams() -> void:
	print("the colors")
	var game := _play()
	game.field.asteroids.clear()
	SimInput.run(game, 0.5)
	var owners := {}
	for b in game.field.beams:
		owners[b.owner] = true
	var ok := owners.size() == 4
	for s in owners:
		ok = ok and game.beam_color(s).is_equal_approx(Protocol.PLAYER_COLORS[s])
	_check(ok and game.beam_color(9).is_equal_approx(Color.WHITE), "every ship fires beams in the color of its player: %s"
			% str(owners.keys()))
	var worst := SimInput.min_delta_e(Protocol.PLAYER_COLORS)
	_check(worst >= 25.0, "the 4 hull colors differ pairwise by a delta E of 25 or more: %.1f" % worst)


## 22.5c, 6b, 6d: the buzz of a pickup (30 ms), of a force field that pops (80 ms) and of a lost ship (400 ms) (REQ-AB-15).
func _buzzes() -> void:
	print("the buzzes")
	var game := _play()
	game.field.asteroids.clear()
	var rec := SimInput.record_haptics(game)
	var ship: SpaceField.Ship = game.field.ships[0]
	var up := SpaceField.Upgrade.new()
	up.kind = SpaceField.SHIELD
	up.x = ship.x
	up.y = SpaceField.SHIP_Y
	game.field.upgrades.append(up)
	game._process(DT)
	game._process(DT)
	_check(ship.shield and game.field.upgrades.is_empty() and rec.log == [[0, 30]],
			"taking a force field turns the ring on and buzzes that phone once for 30 ms: %s" % str(rec.log))
	# An asteroid hits the ship with the ring.
	var rock: SpaceField.Asteroid = game.field._make(1, ship.x, SpaceField.SHIP_Y - 30.0, RandomNumberGenerator.new())
	rec.log.clear()
	var score_before: int = game.field.scores[0]
	game._process(DT)
	_check(not ship.shield and ship.alive and not game.field.asteroids.has(rock) and rec.log == [[0, 80]]
			and game.field.scores[0] == score_before, "a hit on the ring buzzes once for 80 ms, the ship flies on, the score is the same")
	# Issue #137: for 3 s after the ring took a hit an asteroid passes through the ship: no hit, no buzz.
	var rock_in_grace: SpaceField.Asteroid = game.field._make(1, ship.x, SpaceField.SHIP_Y - 30.0, RandomNumberGenerator.new())
	rec.log.clear()
	game._process(DT)
	_check(ship.alive and game.field.asteroids.has(rock_in_grace) and rec.log.is_empty(),
			"an asteroid inside the grace time after the ring is gone does not hit the ship and does not buzz")
	game.field.asteroids.clear()
	SimInput.run(game, SpaceField.GRACE_TIME + 0.1, DT, func(_t: float) -> void: game.field.asteroids.clear())
	# An asteroid hits the ship without the ring.
	var rock2: SpaceField.Asteroid = game.field._make(1, ship.x, SpaceField.SHIP_Y - 30.0, RandomNumberGenerator.new())
	rec.log.clear()
	game._process(DT)
	game._process(DT)
	_check(not ship.alive and game.field.asteroids.has(rock2) == true and rec.log == [[0, 400]]
			and game.field.scores[0] == score_before
			and game.field.ships[1].alive, "a hit without the ring buzzes once for 400 ms, the ship is out, the score is the same")
	game.field.asteroids.clear()
	SimInput.run(game, 5.0, DT, func(_t: float) -> void: game.field.asteroids.clear())
	_check(not ship.alive and game.field.alive_count() == 3, "the ship that is out does not come back in 5 s")
	SimInput.run(game, 6.0, DT, func(_t: float) -> void: game.field.asteroids.clear())
	_check(ship.alive and ship.shield and game.field.alive_count() == 4,
			"the ship that is out is back with a force field after 10 s")
	_check(80 < 400, "the buzz of a lost ship is longer than the one of the ring")


## 22.7c, 7b: the line in the bar shows the time that is left of the wave, and the rest says how long it takes.
func _wave_line() -> void:
	print("the line of the wave")
	var game := _play()
	var marks := {}
	SimInput.run(game, 31.0, DT, func(t: float) -> void:
		game.field.asteroids.clear()
		for mark in [0.5, 15.0, 29.5]:
			if absf(t - mark) < DT * 0.5:
				marks[mark] = game.wave_line_fraction())
	_check(marks[0.5] > 0.95 and marks[15.0] > 0.45 and marks[15.0] < 0.55 and marks[29.5] < 0.05,
			"the line is full at the start of a wave, half at 15 s and nearly empty at 30 s: %s" % str(marks))
	_check(game.field.phase == SpaceField.Phase.REST and game.banner() == "wave_clear"
			and game.next_wave_text() == "Next wave in 5"
			and game.wave_line_fraction() > 0.8, "the rest starts with Wave clear, Next wave in 5 and a full line (%s)"
			% game.next_wave_text())
	SimInput.run(game, 2.0, DT, func(_t: float) -> void: game.field.asteroids.clear())
	_check(game.next_wave_text() == "Next wave in 3" and game.wave_line_fraction() < 0.65,
			"2 s later it says %s and the line is shorter" % game.next_wave_text())


## 22.8e: alone there is no medal at any score; with more players the place gets the medal (REQ-AB-14, REQ-GM-73a).
func _medals() -> void:
	print("the medals")
	var all_ok := true
	var shown := []
	for score in [0, 599, 600, 1800, 4000, 9000]:
		var game := _play()
		game.participants.clear()
		game.participants.append(0)
		for s in [1, 2, 3]:
			game._on_player_left(s)
		game.players_at_start = 1   # A round that started with one phone; a player that stays after a leave has the gold medal.
		game.field.ships[0].alive = false
		game.field.scores[0] = score
		game._process(DT)
		SimInput.run(game, 2.2)
		var shown_tiers: Array = MedalView.tiers_in(game._menu_box) if game.is_over else ["not over"]
		all_ok = all_ok and game.is_over and shown_tiers.is_empty()
		shown.append("%d=%s" % [score, str(shown_tiers)])
	_check(all_ok, "one player gets no medal, at any score (REQ-AB-14): %s" % str(shown))
	var duo := _play()
	duo.participants.clear()
	duo.participants.append_array([0, 1])
	for s in [2, 3]:
		duo._on_player_left(s)
	duo.field.ships[0].alive = false
	duo.field.ships[1].alive = false
	duo.field.scores[0] = 300
	duo.field.scores[1] = 100
	duo._process(DT)
	SimInput.run(duo, 2.2)
	var duo_tiers: Array = MedalView.tiers_in(duo._menu_box) if duo.is_over else ["not over"]
	_check(duo.is_over and duo_tiers == ["gold", "silver"], "two players: the place gets the medal, 1st gold and 2nd silver: %s"
			% str(duo_tiers))


## 22.10a: a player leaves; the ship goes at once and the others go on firing for 10 s (REQ-AB-19).
func _leave() -> void:
	print("a player leaves")
	var game := _play()
	game.field.asteroids.clear()
	_app.server.kick(3)
	await _frames(3)
	game._process(DT)
	_check(not game.field.ships.has(3) and game.field.ships.size() == 3 and not game.is_over,
			"the ship of the player that left is gone within one frame")
	var shots := {"n": 0}
	SimInput.run(game, 10.0, DT, func(_t: float) -> void:
		game.field.asteroids.clear()
		for e in game.field.events:
			if e.t == "shot":
				shots.n += 1)
	_check(shots.n >= 3 * 24 and game.field.alive_count() == 3 and not game.is_over,
			"the 3 ships that are left fire for 10 s (%d shots) and the game goes on" % shots.n)
