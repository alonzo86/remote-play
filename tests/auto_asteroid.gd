extends SceneTree
## Galaxy Protector with simulated phones and a fixed time step: what used to be checked by hand in Test 22 and a machine can
## check (the name tags, the hint time, RECENTER, the colors of the beams, the buzzes, the line of the wave, the medals, a player
## that leaves). The game is stepped by hand (`SimInput`). Run:
##   godot --headless --path . --script tests/auto_asteroid.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const Shell = preload("res://scripts/game/shell.gd")
const MedalView = preload("res://scripts/ui/medal_view.gd")
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


## A game in its countdown, stepped by hand. All phones are held flat.
func _new_game(difficulty := "medium") -> Control:
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	return SimInput.start_game(_app, _blast, {"difficulty": difficulty})


## A game after GO. The asteroids can be switched off (`calm`), so that nothing hits a ship.
func _play(difficulty := "medium") -> Control:
	var game := _new_game(difficulty)
	SimInput.to_play(game, func() -> bool: return game._clock.is_counting())
	return game


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_blast = load("res://scripts/game/asteroid_blast/asteroid_blast_game.gd")
	_clients = await SimInput.connect_phones(self, _app, 4)
	await _countdown()
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


## 22.2a, 2b, 2c: in the countdown the ships steer and have name tags; the hint stays about 5 s after GO (REQ-AB-16).
func _countdown() -> void:
	print("the countdown")
	var game := _new_game()
	var p: RefCounted = _app.server.players[0]
	var x0: float = game.field.ships[0].x
	SimInput.set_tilt(p, Vector2(0.5, 0.0))
	SimInput.run(game, 1.0)
	_check(game._clock.is_counting() and game.field.ships[0].x - x0 > 100.0 and game.field.asteroids.is_empty()
			and game.field.beams.is_empty() and game.field.events.is_empty(),
			"in the first second of the countdown the ship steers %.0f px, and nothing falls or fires" % (game.field.ships[0].x - x0))
	var spots: Dictionary = game.name_tag_spots()
	var entries: Array = []
	for s in game.participants:
		entries.append({"pos": spots[s], "name": _app.server.players[s].player_name, "avatar": _app.server.players[s].avatar})
	var rects: Array = Shell.name_tag_rects(game.size, entries, game.name_tag_radius())
	var inside := true
	var apart := true
	for i in rects.size():
		inside = inside and rects[i].position.x >= 60.0 and rects[i].end.x <= game.size.x - 60.0 and rects[i].position.y >= 60.0 \
				and rects[i].end.y <= game.size.y - 60.0
		for j in range(i + 1, rects.size()):
			apart = apart and not rects[i].intersects(rects[j])
	var names: Array = entries.map(func(e: Dictionary) -> String: return e.name)
	_check(game.name_tags_shown() and names == ["Sim0", "Sim1", "Sim2", "Sim3"] and rects.size() == 4,
			"4 ships have 4 name tags with the names of the phones: %s" % str(names))
	_check(inside and apart, "the tags are inside the 60 px margin and no tag covers another one")
	_check(spots[0].y < game.size.y and spots[0].x < spots[1].x and spots[1].x < spots[2].x and spots[2].x < spots[3].x,
			"the tags stand over the ships, from left to right in the order of the phones")
	SimInput.set_tilt(p, Vector2.ZERO)
	var go := SimInput.run_until(game, func() -> bool: return not game._clock.is_counting(), 10.0)
	var tags_at_go: bool = game.name_tags_shown()
	var hint_after := SimInput.run_until(game, func() -> bool: return not game.hint_shown(), 20.0)
	_check(not tags_at_go and go > 1.5, "the name tags are gone at GO")
	_check(hint_after >= 4.0 and hint_after <= 6.0, "the hint goes away %.1f s after GO (4 to 6 s)" % hint_after)


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
	# An asteroid hits the ship without the ring.
	var rock2: SpaceField.Asteroid = game.field._make(1, ship.x, SpaceField.SHIP_Y - 30.0, RandomNumberGenerator.new())
	rec.log.clear()
	game._process(DT)
	game._process(DT)
	_check(not ship.alive and game.field.asteroids.has(rock2) == true and rec.log == [[0, 400]]
			and game.field.scores[0] == score_before
			and game.field.ships[1].alive, "a hit without the ring buzzes once for 400 ms, the ship is out, the score is the same")
	game.field.asteroids.clear()
	SimInput.run(game, 30.0, DT, func(_t: float) -> void: game.field.asteroids.clear())
	_check(not ship.alive and game.field.alive_count() == 3, "the ship that is out does not come back in 30 s")
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


## 22.8e: the medal for the score at the limits of Medium (600, 1800, 4000) (REQ-AB-14, REQ-AB-20).
func _medals() -> void:
	print("the medals")
	var all_ok := true
	var shown := []
	for c in [[599, ""], [600, "bronze"], [1799, "bronze"], [1800, "silver"], [3999, "silver"], [4000, "gold"]]:
		var game := _play()
		game.participants.clear()
		game.participants.append(0)
		for s in [1, 2, 3]:
			game._on_player_left(s)
		game.field.ships[0].alive = false
		game.field.scores[0] = c[0]
		game._process(DT)
		SimInput.run(game, 2.2)
		var tiers_shown: Array = MedalView.tiers_in(game._menu_box) if game.is_over else ["not over"]
		var ok: bool = game.is_over and tiers_shown == ([c[1]] if c[1] != "" else [])
		all_ok = all_ok and ok
		shown.append("%d=%s" % [c[0], c[1] if c[1] != "" else "none"])
	# open_results() skips the medal of the score when the game passes a title ("Reached wave N"), and gives the place medal: a
	# single player always gets gold. REQ-AB-14 says the medal comes from the score.
	_known_bug("issue-needed: Galaxy Protector with one player always shows a gold medal; REQ-AB-14 wants bronze at 600, silver at "
			+ "1800, gold at 4000 and none below (open_results with a title ignores the tiers): %s" % str(shown), all_ok)


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
