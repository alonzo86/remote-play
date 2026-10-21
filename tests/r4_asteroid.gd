extends SceneTree
## Galaxy Protector, the rest of Test 22 (docs/MANUAL_TESTS.md test 22), with a simulated phone and a fixed time step: the ship
## stops at both sides of the play area, stays on the screen and stands still after it stopped (3c), and a player that plays
## alone sees "Reached wave N" where N is the last wave banner (8e). The force field buzz (5f) is in tests/auto_asteroid.gd.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/r4_asteroid.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const Lang = preload("res://scripts/core/lang.gd")
const SpaceField = preload("res://scripts/game/asteroid_blast/space_field.gd")

const DT := 1.0 / 60.0

var _fails := 0
var _checks := 0
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
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: use _check)")
	else:
		_fails += 1
		print("  FAIL (known bug) ", issue, ": ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _play() -> Control:
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	var game := SimInput.start_game(_app, _blast, {"difficulty": "medium"})
	SimInput.to_play(game, func() -> bool: return game._clock.is_counting())
	return game


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_blast = load("res://scripts/game/asteroid_blast/asteroid_blast_game.gd")
	_clients = await SimInput.connect_phones(self, _app, 4)
	_edges()
	_reached_wave()
	for c in _clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## 3c: full tilt to the right and to the left, 2 s after the ship stopped it has not moved, and it is fully on the screen.
func _edges() -> void:
	print("the sides")
	var game := _play()
	game.field.asteroids.clear()
	var p: RefCounted = _app.server.players[0]
	for side in [1.0, -1.0]:
		SimInput.set_tilt(p, Vector2(side, 0.0))
		SimInput.run(game, 4.0, DT, func(_t: float) -> void: game.field.asteroids.clear())   # 1740 px at 760 px/s: 2.3 s at most.
		var stopped: float = game.field.ships[0].x
		SimInput.run(game, 2.0, DT, func(_t: float) -> void: game.field.asteroids.clear())
		var x: float = game.field.ships[0].x
		var want: float = SpaceField.REF_AREA.x - SpaceField.EDGE if side > 0.0 else SpaceField.EDGE
		var label := "right" if side > 0.0 else "left"
		_check(absf(x - stopped) < 0.01 and absf(x - want) <= 1.0 and absf(game.field.ships[0].vx) < 5.0,
				"%s: 2 s after it stopped the ship has not moved and its middle is at %.1f of the play area (60 px from the side)"
				% [label, x])
		var fit: Dictionary = game._fit()
		var screen_x: float = fit.origin.x + x * float(fit.k)
		var from_edge := screen_x if side < 0.0 else game.size.x - screen_x
		_check(screen_x - 30.0 >= 0.0 and screen_x + 30.0 <= game.size.x,
				"%s: the ship (60 px wide) is fully on the screen: its middle is at %.0f of %.0f" % [label, screen_x, game.size.x])
		# REQ-AB-2 says "60 px from both sides" (of the play area, checked above). The step text said 2 to 4 % of the screen
		# width from the edge of the screen: the requirement wins (align.md: the middle of the ship is about 120 px from the edge).
		print("   %s: the middle of the ship is %.0f px (%.1f %%) from the edge of the screen"
				% [label, from_edge, 100.0 * from_edge / game.size.x])
	SimInput.set_tilt(p, Vector2.ZERO)


## 8e: alone, the result title says "Reached wave N", N is the number of the last wave banner.
func _reached_wave() -> void:
	print("the title of one player")
	var game := _play()
	game.participants.clear()
	game.participants.append(0)
	for s in [1, 2, 3]:
		game._on_player_left(s)
	var last_banner := {"wave": 0}
	SimInput.run(game, 80.0, DT, func(_t: float) -> void:
		game.field.asteroids.clear()
		if game.banner() == "wave_n":
			last_banner.wave = game.field.wave)
	_check(last_banner.wave >= 3, "80 s of play show the banners of waves 1 to %d" % last_banner.wave)
	game.field.ships[0].alive = false
	game._process(DT)
	SimInput.run(game, 2.2)
	var expected := Lang.f("asteroid_blast.reached_wave", [last_banner.wave]).to_lower()
	var texts: Array = game._menu_box.find_children("*", "Label", true, false).map(func(l): return String(l.text).to_lower()) \
			if game.is_over else []
	_check(game.is_over and texts.any(func(t: String) -> bool: return t.contains(expected)),
			"the result menu has the title '%s' (the last banner was wave %d): %s" % [expected, last_banner.wave, str(texts)])
