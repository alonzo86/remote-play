extends SceneTree
## Freeze Dance with simulated phones, stepped by hand (REQ-FD-*, test 29 of docs/MANUAL_TESTS.md). Run:
##   godot --headless --path . --script tests/smoke_freeze.gd -- --role=tv

const MedalView = preload("res://scripts/ui/medal_view.gd")
const Sim = preload("res://tests/sim_b.gd")
const DanceRules = preload("res://scripts/game/freeze_dance/dance_rules.gd")
const DanceLook = preload("res://scripts/game/freeze_dance/dance_look.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")
const Registry = preload("res://scripts/game/registry.gd")

var _fails := 0
var _checks := 0
var Game
var sim
var Snd
var Haptics   # Loaded at run time: haptics.gd uses the App autoload, which a preload cannot see.
var _sfx: Array[String] = []


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
	Game = load("res://scripts/game/freeze_dance/freeze_dance_game.gd")
	sim = Sim.new(self)
	Snd = root.get_node("Sound")
	Haptics = load("res://scripts/game/haptics.gd")
	GameSettings.clear()
	Snd.sfx_played.connect(func(id: String) -> void: _sfx.append(id))
	await sim.join(2)
	sim.settle(0, Sim.FLAT)
	sim.settle(1, Sim.FLAT)
	_registry()
	await _start_and_music()
	await _freeze_and_points()
	await _move_and_bench()
	await _pause()
	await _full_round()
	await _leaving()
	await _bench_cases()
	await _small_screen()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Starts a round with the first `n` phones in it and returns the game at once: there is no countdown.
func _play(n := 2, props := {}) -> Control:
	sim.app.server.set_in(1, n > 1)   # One phone in the round: the other one chose OUT (REQ-GM-104).
	var game: Control = await sim.start(Game, props)
	for s in n:
		sim.settle(s, Sim.FLAT)
	_sfx.clear()
	return game


## Steps `seconds`; `gyro` is slot -> the turn of the phone in rad/s (a Callable(game) -> Dictionary is also allowed).
func _step(game: Control, seconds: float, gyro: Variant) -> void:
	for t in roundi(seconds / Sim.DT):
		var g: Dictionary = gyro.call(game) if gyro is Callable else gyro
		for s in game.participants:
			sim.feed(s, Sim.FLAT, Vector3(float(g.get(s, 0.0)), 0.0, 0.0))
		game._game_tick(Sim.DT)


## Steps until the freeze of the song starts.
func _to_freeze(game: Control, gyro: Variant) -> void:
	var guard := 0
	while game._rules.phase != DanceRules.Phase.FREEZE and guard < 60 * 30:
		_step(game, Sim.DT, gyro)
		guard += 1


func _registry() -> void:
	print("freeze: registry")
	var g := Registry.find("freeze_dance")
	_check(not g.is_empty() and int(g.min_players) == 1 and int(g.max_players) == 4 and g.settings.is_empty(),
			"the game is in the registry for 1 to 4 players, with Difficulty only (REQ-FD-11)")
	_check(g.pad.is_empty() and Registry.buttons_of(g) == "" and not Registry.has_control(g, "recenter"),
			"the pad has no buttons and no Recenter box: the phone is only moved (REQ-GM-37a)")
	_check(bool(g.get("swing", false)), "the safety card of the swing games shows for this game (REQ-GM-102)")
	_check(FileAccess.file_exists(String(g.doc)) and FileAccess.file_exists("res://assets/tiles/freeze_dance.png"),
			"the requirements file and the tile exist (REQ-GM-6, REQ-GM-49)")


## REQ-FD-1, 2, 3, 5, 12: no countdown, the song plays, the lights change, a wiggling dancer dances.
func _start_and_music() -> void:
	print("freeze: start and music")
	var game: Control = await _play(2, {"seed": 4})
	_check(not game._has_countdown() and game._rules.phase == DanceRules.Phase.MUSIC and game._rules.song == 1,
			"the first song starts at once, with no countdown (REQ-FD-1)")
	_check(Snd.wanted_music == "freeze_dance" and not Snd.music_held, "the song of the game plays (REQ-FD-2)")
	_check(not game._lit.is_empty(), "the floor has lit tiles during the music (REQ-FD-12)")
	var first: Dictionary = game._lit.duplicate()
	_step(game, 1.0, {0: 3.0})
	_check(game._lit != first, "the lit tiles change every half second (REQ-FD-12)")
	_check(game._rules.dancers[0].energy > 2.0 and game._rules.dancers[1].energy < 0.1,
			"the energy of a phone comes from its gyro: the wiggling phone is high, the still one is not (REQ-FD-4)")
	_check(game._rules.dancers[0].dance_time > 0.5 and game._rules.dancers[1].dance_time == 0.0,
			"only the wiggling player dances (REQ-FD-5)")
	game._request_redraw()
	await sim.frames(2)
	_check(true, "the game draws the hall, the dancers and the HUD without an error")
	var a: Dictionary = DanceLook.place(0, 2, game.size)
	var b: Dictionary = DanceLook.place(1, 2, game.size)
	_check(game._seat[0] == 0 and game._seat[1] == 1 and float(a.x) < float(b.x), "the players stand in their places (REQ-FD-13)")
	_check(game.best_key() == "" and game.difficulty == "medium",
			"no personal best, and Medium is the level at the start (REQ-FD-10)")


## REQ-FD-2, 3, 7, 14: the stop, the points after the freeze, the buzz after the freeze, the music goes on.
func _freeze_and_points() -> void:
	print("freeze: stop and points")
	var game: Control = await _play(2, {"seed": 4})
	var rec: RefCounted = _recorder()
	game._haptics = rec
	var wiggle := {0: 4.0, 1: 4.0}
	_to_freeze(game, wiggle)
	_check(game._rules.phase == DanceRules.Phase.FREEZE and Snd.music_held,
			"the music is held at once when the freeze starts (REQ-FD-2)")
	_check(game._lit.is_empty() and "freeze_stop" in _sfx, "every light goes out and the stop effect plays (REQ-FD-3, 12)")
	_check(rec.log.is_empty(), "no phone buzzes at the stop or during the freeze (REQ-FD-14)")
	_step(game, float(game._rules.level.freeze) - 0.3, {})
	_check(game._board.score(0) == 0.0, "the points come when the freeze ends, not before (REQ-FD-7)")
	_step(game, 0.6, {})
	_check(game._board.score(0) == 10.0 and game._board.score(1) == 10.0,
			"both players held still and danced: 10 points each (REQ-FD-7)")
	_check("dance_points" in _sfx, "the points play the points effect (REQ-FD-7)")
	_check(rec.ms_of(0) == [40] and rec.ms_of(1) == [40],
				"each phone buzzes once, 40 ms, for the points (Test 31 step 6c): %s" % str(rec.log))
	var pops := 0
	for p in game._pops:
		if p.age >= 0.0:
			pops += 1
	_check(pops == 2, "a +10 floats up above each scoring dancer")
	_step(game, DanceRules.REST + 0.1, {})
	_check(game._rules.song == 2 and not Snd.music_held and not game._lit.is_empty(),
			"the next song goes on from the same place and the lights are on again (REQ-FD-2, 12)")
	game._request_redraw()
	await sim.frames(2)
	_check(true, "a frame with the +10 draws without an error")


## A `Haptics` that notes every pulse (it needs the App autoload to compile, so it is loaded here).
func _recorder() -> RefCounted:
	return load("res://tests/rec_haptics.gd").new()


## REQ-FD-6, 8, 14: a move, the bench, the buzz, the sit-out song and the return.
func _move_and_bench() -> void:
	print("freeze: a move and the bench")
	var game: Control = await _play(2, {"seed": 4})
	var rec: RefCounted = _recorder()
	game._haptics = rec
	_to_freeze(game, {0: 4.0, 1: 4.0})
	game._board.add(1, 20)   # Points that stay.
	_step(game, 1.0, {0: 0.0, 1: 5.0})   # Player 1 goes on shaking; player 0 holds still.
	_check(not game._rules.dancers[1].plays() and game._rules.dancers[0].plays(),
			"the mover leaves the floor, the other player stays (REQ-FD-8)")
	_check(rec.ms_of(1) == [80] and rec.ms_of(0).is_empty() and "dance_out" in _sfx,
			"the mover buzzes once, 80 ms, and the soft effect plays (REQ-FD-8, 14): %s" % str(rec.log))
	_check(game._bench() == [1], "the mover is on the bench")
	_check(game._rules.back_in(1) > 10.0 and game._rules.back_in(1) < 25.0, "the bench says how many seconds until it dances again")
	game._request_redraw()
	await sim.frames(2)
	_check(true, "a frame with the bench draws without an error")
	# Issue #151: "back in n" stays inside the 60 px safe margin in English and in Hebrew, for 1 and 2 digits.
	var lang_script = sim.app.Lang
	var UiThemeS = load("res://scripts/ui/ui_theme.gd")
	for code in ["en", "he"]:
		lang_script.set_language(code, root)
		var chip_x: float = game._bench_feet(0).x + 60.0
		for n in [1, 9, 10, 25]:
			var shown: String = lang_script.f("freeze_dance.back_in", [n]).to_upper()
			var w: float = UiThemeS.font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, UiThemeS.SIZE_BODY).x
			var x: float = game.bench_text_x(chip_x, w, 1920.0)
			_check(x >= 60.0 and x + w <= 1920.0 - 60.0,
					"%s, %d s: the back-in text is inside the margin (%.0f to %.0f)" % [code, n, x, x + w])
	lang_script.set_language("en", root)
	_step(game, float(game._rules.level.freeze) + DanceRules.REST, {0: 0.0, 1: 5.0})
	_check(game._board.score(1) == 20.0 and game._board.score(0) == 10.0,
			"the mover keeps its points and gets none for this song (REQ-FD-8)")
	_check(game._rules.song == 2 and game._bench() == [1], "the next song starts and the mover is still on the bench")
	_to_freeze(game, {0: 4.0, 1: 5.0})
	_step(game, float(game._rules.level.freeze) + 0.2, {0: 0.0, 1: 5.0})
	_check(game._board.score(1) == 20.0 and game._board.score(0) == 20.0,
			"a sitting player scores nothing, and its phone is not checked (REQ-FD-8)")
	_step(game, DanceRules.REST + 0.1, {})
	_check(game._rules.song == 3 and game._bench().is_empty() and game._rules.dancers[1].plays(),
			"in the song after that the player dances again")


## The pause stops the round: no time, no event.
func _pause() -> void:
	print("freeze: pause")
	var game: Control = await _play(2, {"seed": 4})
	_step(game, 1.0, {0: 3.0})
	var t: float = game._rules.phase_time
	game._menu_open = true
	for i in 120:
		sim.feed(0, Sim.FLAT, Vector3(3.0, 0.0, 0.0))
		game._process(Sim.DT)
	_check(is_equal_approx(game._rules.phase_time, t), "nothing moves while the game is paused (REQ-FL-43)")
	game._menu_open = false


## REQ-FD-1, 9: the whole round, the winner, the medal rule.
func _full_round() -> void:
	print("freeze: a whole round")
	var game: Control = await _play(1, {"seed": 4})
	var dance := func(g: Control) -> Dictionary: return {0: 4.0 if g._rules.phase == DanceRules.Phase.MUSIC else 0.0}
	var t := 0.0
	while not game.is_over and t < 200.0:
		_step(game, Sim.DT, dance)
		t += Sim.DT
	_check(game.is_over and game._board.score(0) == 60.0,
			"a player who dances and holds still in 6 songs ends with 60 points (%.0f s)" % t)
	_check(t > 60.0 and t < 100.0, "a round lasts about 75 s: %.0f s (6 songs of music, freeze and rest)" % t)
	_check(MedalView.tiers_in(game._menu_box).is_empty(), "one player gets no medal (REQ-FD-9)")
	var labels: Array = []
	for l in game._menu_box.find_children("*", "Label", true, false):
		labels.append(String(l.text).to_upper())
	_check(not labels.is_empty() and labels[0] == "SIM0 WINS!", "the title of the result menu names the player: %s" % str(labels))
	_check(game.menu_buttons().size() >= 3, "the result menu has Try again, New game and Back to menu (REQ-FD-9)")
	_check(not Snd.music_held, "the song is not held when the result menu opens")
	var two: Control = await _play(2, {"seed": 4})
	two._board.add(0, 30)
	two._finish()
	_check(two.is_over and MedalView.tiers_in(two._menu_box) == ["gold", "silver"],
			"two players: the places get medals (REQ-GM-73a)")
	var easy: Control = await _play(1, {"seed": 4, "difficulty": "hard"})
	_check(easy._rules.level == DanceRules.LEVELS.hard, "the difficulty is a prop of the game (REQ-FD-11)")
	var a: Control = await _play(1, {"seed": 11})
	var lengths_a: Array = a._rules.music_lengths.duplicate()
	var b: Control = await _play(1, {"seed": 11})
	_check(lengths_a == b._rules.music_lengths, "a seed fixes the songs, as Try again keeps it (REQ-FD-1)")


## REQ-FD-9, 13: a player that leaves; the places of the others do not change.
func _leaving() -> void:
	print("freeze: leaving")
	var game: Control = await _play(2, {"seed": 4})
	var before: Dictionary = DanceLook.place(game._seat[1], game._seat_count, game.size)
	game._board.add(1, 20)
	game._on_player_left(0)
	_check(not game._rules.dancers.has(0) and not game._board.has(0),
			"a player who leaves takes the dancer and the score out (REQ-FD-9)")
	_check(DanceLook.place(game._seat[1], game._seat_count, game.size) == before, "the other dancer keeps its place (REQ-FD-13)")
	_step(game, 1.0, {1: 3.0})
	_check(not game.is_over and game._rules.dancers[1].dance_time > 0.5, "the round goes on")


## REQ-FD-8: a mover whose way back is after the last song stays on the bench; the bench fits the screen.
## REQ-GM-22: nobody left ends the round.
func _bench_cases() -> void:
	print("freeze: bench cases")
	var game: Control = await _play(4, {"seed": 4})
	var slots: Array = game.participants.duplicate()
	for s in slots:
		game._rules.dancers[s].moved = true
	game._rules.song = DanceRules.SONGS
	_check(game._bench() == slots and game._rules.back_in(slots[0]) == -1.0,
			"movers in the last song are on the bench with no BACK IN time (REQ-FD-8)")
	game.size = Vector2(1280.0, 720.0)
	var fits := true
	for row in 4:
		var feet: Vector2 = game._bench_feet(row)
		fits = fits and feet.y - 100.0 > game.BAR_H and feet.x + game.BENCH_W <= game.size.x and feet.y <= game.size.y
	_check(fits, "four players on the bench fit under the bar and inside the screen at 1280x720")
	game._request_redraw()
	await sim.frames(2)
	_check(true, "a frame with a bench without times draws without an error")
	var gone: Control = await _play(2, {"seed": 4})
	gone.participants.clear()
	gone._on_player_left(0)
	gone._on_player_left(1)
	gone.end_no_players()
	_check(gone.is_over, "when nobody is left the game ends with the menu No players connected (REQ-GM-22)")


## REQ-FD-16: the layout comes from the size of the screen.
func _small_screen() -> void:
	print("freeze: small screen")
	var game: Control = await _play(4, {"seed": 4})
	sim.app.server.set_in(1, true)
	game.size = Vector2(1280.0, 720.0)
	game._request_redraw()
	await sim.frames(2)
	var ok := true
	for i in 4:
		var p: Dictionary = DanceLook.place(i, 4, game.size)
		var h := float(DanceLook.IMG.y) * int(p.scale) * game.size.x / 480.0
		ok = ok and float(p.x) > 0.0 and float(p.x) < game.size.x and float(p.y) < game.size.y and float(p.y) - h > 0.0
	_check(ok, "at 1280x720 the dancers stand inside the screen (REQ-FD-16)")
	_check(game._pixel_viewport.size_2d_override == Vector2i(1280, 720), "the pixel view follows the size of the screen")
