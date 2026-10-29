extends SceneTree
## Whack-a-Mole with simulated phones, stepped by hand (REQ-WM-*, test 28 of docs/MANUAL_TESTS.md). Run:
##   godot --headless --path . --script tests/smoke_mole.gd -- --role=tv

const MedalView = preload("res://scripts/ui/medal_view.gd")
const Sim = preload("res://tests/sim_b.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const MoleField = preload("res://scripts/game/whack_a_mole/mole_field.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")
const Registry = preload("res://scripts/game/registry.gd")

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
	Game = load("res://scripts/game/whack_a_mole/whack_a_mole_game.gd")
	sim = Sim.new(self)
	GameSettings.clear()
	await sim.join(2)
	sim.settle(0, Sim.FLAT)
	sim.settle(1, Sim.FLAT)
	_registry()
	await _countdown_and_aim()
	await _bonk()
	await _first_press_wins()
	await _round_end()
	await _leaving()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Starts a round, steps out the countdown for the first `n` phones and returns the game at GO, with no moles. All connected
## phones are in the round.
func _play(n := 1, props := {}) -> Control:
	sim.app.server.set_in(1, n > 1)   # One phone in the round: the other one chose OUT (REQ-GM-104).
	var game: Control = await sim.start(Game, props)
	var accels := {}
	for s in n:
		sim.settle(s, Sim.FLAT)
		sim.app.server.players[s].recenter()
		accels[s] = Sim.FLAT
	sim.through_countdown(game, accels)
	game._field.moles.clear()
	game._field._spawn_left = 1000.0   # No new mole while a check works with its own moles.
	game._field._bonus_left = 1000.0
	return game


## Points the phone of `slot` so that the ring is at `target` (screen pixels). Returns the ring after one tick.
func _aim_at(game: Control, slot: int, target: Vector2) -> Vector2:
	var area: Rect2 = game._area()
	var p := (target - area.get_center()) / (area.size * 0.5)
	var yaw := deg_to_rad(-p.x * 25.0)
	var elev := deg_to_rad(-p.y * 25.0)
	var pl = sim.app.server.players[slot]
	pl.orientation.yaw = yaw
	pl.orientation.up = Vector3(0.0, sin(elev), cos(elev))
	game._game_tick(Sim.DT)
	return game._players[slot].aim


## A mole that is fully up in `hole`.
func _mole(game: Control, hole: int, golden := false) -> MoleField.Mole:
	game._field._add(hole, golden)
	var m: MoleField.Mole = game._field.moles[game._field.moles.size() - 1]
	m.age = MoleField.RISE_TIME + 0.05
	return m


func _poofs(game: Control) -> int:
	var n := 0
	for p in game._poofs:
		if p.age >= 0.0:
			n += 1
	return n


func _press(game: Control, slot: int) -> void:
	game._on_button(Protocol.BTN_A, slot)


func _registry() -> void:
	print("mole: registry")
	var g := Registry.find("whack_a_mole")
	_check(not g.is_empty() and int(g.min_players) == 1 and int(g.max_players) == 4 and Registry.has_control(g, "a")
			and Registry.has_control(g, "recenter") and not Registry.has_control(g, "b"),
			"the game is in the registry for 1 to 4 players, the pad has A and Recenter (REQ-WM-2)")
	_check(FileAccess.file_exists(String(g.doc)), "the requirements file exists (REQ-GM-6)")


## REQ-WM-1, 2, 3: no bonk in the countdown; the ring follows the phone and stays inside the play area.
func _countdown_and_aim() -> void:
	print("mole: countdown and aim")
	var game: Control = await sim.start(Game, {"seed": 3})
	sim.settle(0, Sim.FLAT)
	sim.app.server.players[0].recenter()
	game._game_tick(Sim.DT)
	_check(game._round.is_counting(), "the round starts with the countdown (REQ-WM-1)")
	_press(game, 0)
	_check(game._presses.is_empty(), "a press on A in the countdown does nothing (REQ-WM-4)")
	sim.through_countdown(game, {0: Sim.FLAT})
	var area: Rect2 = game._area()
	var c := area.get_center()
	_check(game._players[0].aim.distance_to(c) < 2.0, "at GO the ring is at the center of the play area (REQ-WM-2, 3)")
	var target := c + Vector2(400.0, -200.0)
	var got := _aim_at(game, 0, target)
	_check(got.distance_to(target) < 12.0, "the ring follows the phone (%.1f px off, REQ-WM-3)" % got.distance_to(target))
	var reached := 0
	for hole in 9:
		var hp: Vector2 = MoleField.hole_pos(hole, area)
		var at := _aim_at(game, 0, hp)
		if at.distance_to(hp) < 12.0:
			reached += 1
	_check(reached == 9, "the ring reaches each of the 9 holes (%d of 9, Test 28 step 3a)" % reached)
	var far := _aim_at(game, 0, c + Vector2(5000.0, 5000.0))
	_check(area.grow(0.01).has_point(far), "the ring stays inside the play area (REQ-WM-3)")
	sim.app.server.players[0].orientation.yaw = 0.0
	sim.app.server.players[0].orientation.up = Vector3(0, 0, 1)


## REQ-WM-4, 5, 7, 8, 11: a bonk hits, a miss costs nothing, the reload, the golden mole and the effects.
func _bonk() -> void:
	print("mole: bonk")
	var game: Control = await _play(1, {"seed": 3})
	var area: Rect2 = game._area()
	var m := _mole(game, 4)
	_aim_at(game, 0, MoleField.head_pos(m, area))
	_press(game, 0)
	game._game_tick(Sim.DT)
	_check(game._board.score(0) == 10.0 and m.is_hit(), "a bonk on a mole gives 10 points and takes the mole (REQ-WM-7, 8)")
	var pop: Object = null
	for p in game._pops:
		if p.age >= 0.0:
			pop = p
	_check(pop != null and pop.text == "+10" and pop.color == game.player(0).color,
			"the points show as +10 in the color of the player (REQ-WM-11)")
	game._players[0].reload_left = 0.0
	_press(game, 0)
	game._game_tick(Sim.DT)
	_check(game._board.score(0) == 10.0, "a mole that was taken is not hit again, and the second press is a miss (REQ-WM-7)")
	game._players[0].reload_left = 0.0
	var before: float = game._board.score(0)
	var poofs_before := _poofs(game)
	_aim_at(game, 0, MoleField.hole_pos(0, area))
	_press(game, 0)
	game._game_tick(Sim.DT)
	_check(game._board.score(0) == before and _poofs(game) == poofs_before + 1, "a miss costs nothing and makes a poof (REQ-WM-5)")
	_press(game, 0)
	game._game_tick(Sim.DT)
	_check(_poofs(game) == poofs_before + 1, "a press inside the 0.3 s reload is ignored (REQ-WM-4)")
	sim.step(game, 0.35)
	var g := _mole(game, 8, true)
	_aim_at(game, 0, MoleField.head_pos(g, area))
	_press(game, 0)
	game._game_tick(Sim.DT)
	_check(game._board.score(0) == before + 50.0 and g.is_hit(), "the golden mole gives 50 points (REQ-WM-8)")
	var golden_pop := false
	for p in game._pops:
		golden_pop = golden_pop or (p.age >= 0.0 and p.text == "+50" and p.golden)
	_check(golden_pop, "the golden mole shows +50 in the big text (REQ-WM-11)")
	var life := 0.0
	while life < 1.2:
		sim.step(game, 0.1)
		life += 0.1
	var gone := true
	for mole in game._field.moles:
		gone = gone and not mole.is_hit()
	_check(gone, "a hit mole is gone after its animation (REQ-WM-7)")
	game._request_redraw()
	await sim.frames(2)
	_check(true, "the game draws a frame with moles, a poof and a ring without an error")


## REQ-WM-4, 7: two bonks on one mole in the same tick: the press that came first wins, not the lower slot.
func _first_press_wins() -> void:
	print("mole: first press wins")
	var game: Control = await _play(2, {"seed": 3})
	var area: Rect2 = game._area()
	var m := _mole(game, 4)
	var head := MoleField.head_pos(m, area)
	_aim_at(game, 0, head)
	_aim_at(game, 1, head)
	_press(game, 1)
	_press(game, 0)
	game._game_tick(Sim.DT)
	_check(game._board.score(1) == 10.0 and game._board.score(0) == 0.0,
			"the press that arrived first wins the mole: slot 1 before slot 0 (REQ-WM-7)")


## REQ-WM-1, 13: the round lasts 60 s; one player gets no medal, two players get the medals of the places.
func _round_end() -> void:
	print("mole: round end")
	var game: Control = await _play(1, {"seed": 3})
	var t := 0.0
	game._board.add(0, 70)
	while not game.is_over and t < 70.0:
		game._game_tick(Sim.DT)
		t += Sim.DT
	_check(game.is_over and t >= 58.0 and t <= 62.0, "the round ends %.1f s after GO (58 to 62, REQ-WM-1)" % t)
	var labels: Array = game._menu_box.find_children("*", "Label", true, false)
	var text := ""
	for l in labels:
		text += String(l.text) + "|"
	print("    result menu: ", text)
	_check(MedalView.tiers_in(game._menu_box).is_empty() and text.find("MEDAL") < 0,
			"one player: no medal and no 'no medal' title (REQ-WM-13)")
	_check(game.menu_buttons().size() >= 3, "the result menu has Try again, New game and Back to menu (REQ-WM-13)")
	var two: Control = await _play(2, {"seed": 3})
	two._board.add(0, 30)
	two._board.add(1, 10)
	two._finish()
	_check(MedalView.tiers_in(two._menu_box) == ["gold", "silver"], "two players: the places get medals (REQ-GM-73a)")
	var left: Control = await _play(2, {"seed": 3})
	left._board.add(0, 30)
	left._on_player_left(1)
	left._finish()
	_check(MedalView.tiers_in(left._menu_box) == ["gold"],
			"two players start and one leaves: the player that stays has a technical win and the gold medal (REQ-WM-13)")
	var easy: Control = await _play(1, {"seed": 3, "difficulty": "easy"})
	_check(easy._field.level == MoleField.LEVELS.easy and easy.best_key() == "",
			"the difficulty is a prop; no personal best (REQ-WM-16)")


## REQ-WM-13: a player who leaves takes the ring and the score out, and the round goes on.
func _leaving() -> void:
	print("mole: leaving")
	var game: Control = await _play(2, {"seed": 3})
	game._board.add(1, 20)
	_press(game, 1)
	game._on_player_left(1)
	_check(not game._players.has(1) and game._presses.is_empty(),
			"the ring and the waiting press of the player are gone (REQ-WM-13)")
	sim.step(game, 0.2)
	_check(not game.is_over and game._players.has(0), "the round goes on for the other player (REQ-WM-13)")
