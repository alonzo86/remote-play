extends SceneTree
## Sheep Herding with simulated phones and a fixed time step (REQ-SH-1 to 20): the countdown, the dogs
## and the tilt, the sheep that
## run from a dog, the pen, the shared score on the TV and on the phones, the sounds and the buzzes, the end (all sheep in, or the
## time is up), the medal of one player, a player that leaves, the layout and Restart. The game is stepped by hand (`SimInput`).
## Run: godot --headless --path . --script tests/smoke_sheep.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const MedalView = preload("res://scripts/ui/medal_view.gd")

const DT := 1.0 / 60.0

var _fails := 0
var _checks := 0
var _sim := SimInput.new()
var _app: Node
var _sound: Node
var _script: GDScript
var _clients: Array = []
var _heard: Array[String] = []


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


## Stops the sounds that still play: a stepped game starts its sounds much faster than they end, and a full pool drops a new one.
func _quiet() -> void:
	for p in _sound._pool:
		p.stop()


## Waits `ms` of real time, in frames (a stepped game runs much faster than the clock).
func _real_wait(ms: int) -> void:
	var end := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < end:
		await process_frame


## A game in play (the countdown is over), stepped by hand, with the buzzes noted.
func _play(difficulty := "medium", seed_value := 7) -> Control:
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	var game := SimInput.start_game(_app, _script, {"difficulty": difficulty, "seed": seed_value})
	SimInput.to_play(game, func() -> bool: return game._round.is_counting())
	return game


## Every sheep of the game goes into the pen (their places), as if the dogs had herded them.
func _pen_all(game: Control, count := -1) -> void:
	var n: int = game.flock.sheep.size() if count < 0 else count
	for i in n:
		var s = game.flock.sheep[i]
		s.pos = game.pen.position + Vector2(70.0 + 60.0 * float(i % 4), 80.0 + 60.0 * float(i / 4))
		s.penned = true


## A place on the field that is far from every blocker and from the pen, where a dog can run.
func _open_spot(game: Control) -> Vector2:
	for x in range(1000, 1300, 20):
		for y in range(300, 1000, 20):
			var p := Vector2(x, y)
			var clear := true
			for b in game.scenery.blockers:
				clear = clear and p.distance_to(b.pos) > float(b.r) + 150.0
			if clear:
				return p
	return Vector2(1000.0, 300.0)


func _result_labels(game: Control) -> Array:
	var out: Array = []
	for l in game._menu_box.find_children("*", "Label", true, false):
		out.append(String(l.text).to_upper())
	return out


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_sound = root.get_node("Sound")
	_script = load("res://scripts/game/sheep_herding/sheep_herding_game.gd")
	_sound.sfx_played.connect(func(id: String) -> void: _heard.append(id))
	load("res://scripts/game/game_settings.gd").clear()
	_clients = await SimInput.connect_phones(self, _app, 2)
	_check(_app.server.connected_slots().size() == 2, "2 simulated phones joined")
	await _settings()
	await _start()
	await _tilt_and_flock()
	await _tilt_timing()
	await _pen_and_score()
	await _team_chip()
	await _the_end()
	await _layout_and_restart()
	_clients = await SimInput.connect_phones(self, _app, 1, _clients)
	await _one_player()
	_clients = await SimInput.connect_phones(self, _app, 3, _clients)
	await _leave()
	for c in _clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The registry entry and the settings view (REQ-SH-17, REQ-SH-20, REQ-GM-90).
func _settings() -> void:
	print("the settings view")
	var Registry = load("res://scripts/game/registry.gd")
	var entry: Dictionary = Registry.find("sheep_herding")
	_check(entry.min_players == 1 and entry.max_players == 4 and entry.pad == [] and entry.settings == [],
			"1 to 4 players, no A or B or RECENTER on the pad, and Difficulty is the only row (REQ-SH-14, 17)")
	var sv: Control = null
	_app.go_game_settings("sheep_herding")
	await _frames(4)
	sv = _app.current_screen()
	_check(is_instance_of(sv, load("res://scripts/ui/tv_game_settings.gd")) and sv.rows.size() == 1 and sv.rows[0].value == "medium",
			"the settings view opens with Difficulty on Medium")
	var key := InputEventAction.new()
	key.action = "ui_right"
	key.pressed = true
	sv.rows[0]._gui_input(key)
	sv.start()
	await _frames(4)
	var hard: Control = _app.current_screen()
	_check(is_instance_of(hard, _script) and hard.difficulty == "hard" and hard.flock.sheep.size() == 14
			and hard.flock.gate == 150.0 and hard._round.duration == 60.0, "Hard gives 14 sheep, a gate of 150 px and 60 s (REQ-SH-17)")
	_check(hard.best_key() == "", "no personal best (REQ-SH-20)")


## The start of a round (REQ-SH-1, 2, 3).
func _start() -> void:
	print("the start")
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	var game := SimInput.start_game(_app, _script, {"difficulty": "medium", "seed": 7})
	_check(game.flock.sheep.size() == 11 and game.flock.penned_count() == 0 and game._round.duration == 75.0
			and game.flock.gate == 180.0, "Medium has 11 sheep, none in the pen, a gate of 180 px and 75 s")
	var d0: Vector2 = game.dogs[0].pos
	var d1: Vector2 = game.dogs[1].pos
	_check(is_equal_approx(d0.x, d1.x) and d0.x < 300.0 and d0.y < d1.y and absf(d1.y - d0.y) > 300.0
			and game.field.has_point(d0) and game.field.has_point(d1),
			"the 2 dogs start at the left edge, apart, one above the other (REQ-SH-2): %s %s" % [str(d0), str(d1)])
	var near_flock := true
	for s in game.flock.sheep:
		near_flock = near_flock and s.pos.x > 400.0 and s.pos.x < 1000.0
	_check(near_flock, "the flock starts in the left middle of the field")
	var before := {}
	for i in game.flock.sheep.size():
		before[i] = game.flock.sheep[i].pos
	SimInput.run(game, 1.5)
	var still := true
	for i in game.flock.sheep.size():
		still = still and game.flock.sheep[i].pos == before[i]
	_check(game._round.is_counting() and game.dogs[0].pos == d0 and still,
			"during the countdown the dogs and the sheep do not move (REQ-SH-1, REQ-GM-35)")
	SimInput.to_play(game, func() -> bool: return game._round.is_counting())
	_check(game._round.is_playing() and not game.is_over, "the round plays after the countdown")
	var other := SimInput.start_game(_app, _script, {"difficulty": "medium", "seed": 7})
	var same: bool = other.scenery.items.size() == game.scenery.items.size()
	for i in mini(other.scenery.items.size(), game.scenery.items.size()):
		same = same and other.scenery.items[i].pos == game.scenery.items[i].pos
	for i in other.flock.sheep.size():
		same = same and other.flock.sheep[i].pos == before[i]
	_check(same, "the same seed gives the same field and the same flock (REQ-SH-3)")
	var easy := SimInput.start_game(_app, _script, {"difficulty": "easy", "seed": 7})
	_check(easy.flock.sheep.size() == 8 and easy._round.duration == 90.0 and easy.flock.gate == 220.0,
			"Easy has 8 sheep, a gate of 220 px and 90 s")


## Test 29 steps 2b, 3a, 3b: a tilt of 20 degrees takes the dog from the left edge to the fence of the pen in 5 s or less, a flat
## phone stops it within 1.5 s, and a dog is 48 px or more high at 1080p (REQ-SH-7).
func _tilt_timing() -> void:
	print("the time of a tilt")
	var game := _play("easy", 5)
	var p0: RefCounted = _app.server.players[0]
	game.scenery.items.clear()   # Trees and the pond are in the way of a straight run; the time is for a free field.
	var dog = game.dogs[0]
	dog.pos = Vector2(game.field.position.x + dog.radius + 4.0, game.field.get_center().y)
	dog.vel = Vector2.ZERO
	var fence_x: float = game.pen.position.x - dog.radius
	var tilt := Vector2(sin(deg_to_rad(20.0)), 0.0)
	var t := 0.0
	while t < 8.0 and dog.pos.x < fence_x:
		_sim.feed(p0, tilt)
		game._process(DT)
		t += DT
	_check(dog.pos.x >= fence_x and t <= 5.0,
				"a tilt of 20 degrees takes the dog from the left edge to the fence of the pen in %.2f s (5 s or less)" % t)
	t = 0.0
	while t < 4.0 and dog.vel.length() >= 20.0:
		_sim.feed(p0, Vector2.ZERO)
		game._process(DT)
		t += DT
	_check(dog.vel.length() < 20.0 and t <= 1.5, "the flat phone stops the dog in %.2f s (1.5 s or less)" % t)
	var pixel_scale: float = 1080.0 / float(game._pixel_viewport.size.y)
	_check(pixel_scale * 14.0 >= 48.0,
				"a dog is 14 world pixels high, %.0f px on a 1080p screen (48 px or more, REQ-GM-47e)" % (pixel_scale * 14.0))
	# Step 5b: the dogs stand still for 10 s (nobody tilts): no sheep leaves the field and no sheep is scared (no speed dashes).
	var calm := _play("easy", 5)
	var worst_scared := 0.0
	var all_in := true
	SimInput.run(calm, 10.0, DT, func(_t: float) -> void:
		for sh in calm.flock.sheep:
			worst_scared = maxf(worst_scared, float(sh.scared))
			all_in = all_in and calm.field.has_point(sh.pos))
	_check(all_in and worst_scared < 0.001,
				"10 s with the dogs still: every sheep stays on the field and none is scared (%.2f)" % worst_scared)


## The tilt moves only the dog of that phone, and a sheep runs from it (REQ-SH-7, REQ-SH-11).
func _tilt_and_flock() -> void:
	print("the dogs and the sheep")
	var game := _play()
	var p0: RefCounted = _app.server.players[0]
	var start0: Vector2 = game.dogs[0].pos
	var start1: Vector2 = game.dogs[1].pos
	for i in 120:
		_sim.feed(p0, Vector2.ZERO)
	p0.recenter()
	for i in 90:
		_sim.feed(p0, Vector2(0.7, 0.0))
		game._process(DT)
	_check(game.dogs[0].pos.x > start0.x + 60.0 and game.dogs[1].pos.distance_to(start1) < 1.0,
			"tilt to the right moves the dog of that phone to the right and not the other (REQ-SH-11)")
	_check(game.dogs[0].vel.length() <= game.DOG_SPEED + 0.01 and game.dogs[0].radius == 30.0,
			"a dog is not faster than 440 px/s")
	# A dog next to a sheep scares it: the sheep runs away and has the name of the dog.
	var sheep = game.flock.sheep[0]
	sheep.vel = Vector2.ZERO
	sheep.scared = 0.0
	game._baa_wait = 0.0
	var at: Vector2 = sheep.pos
	game.dogs[1].pos = at + Vector2(-80.0, 0.0)
	game.dogs[1].vel = Vector2.ZERO
	_heard.clear()
	_quiet()
	# The sound manager drops the same effect inside 40 ms of real time, and a stepped game runs faster than that.
	await _real_wait(60)
	SimInput.run(game, 0.5)
	_check(sheep.pos.x > at.x + 20.0 and sheep.last_dog == 1, "a sheep runs from a dog that comes close: %s" % str(sheep.pos - at))
	_check(_heard.has("sheep_baa") and _heard.count("sheep_baa") <= 1,
			"a scared sheep says baa, once for a moment: %s" % str(_heard))
	# A dog is blocked by the pond and the trees, and bounces off another dog.
	var blocker: Dictionary = game.scenery.blockers[0]
	game.dogs[0].pos = blocker.pos
	game.dogs[0].vel = Vector2.ZERO
	game._process(DT)
	_check(game.dogs[0].pos.distance_to(blocker.pos) >= float(blocker.r) + game.DOG_R - 1.0,
			"a dog is pushed out of a blocker (REQ-SH-4)")
	_quiet()
	await _real_wait(60)   # The same effect twice in 40 ms of real time is one sound.
	_heard.clear()
	game.dogs[0].pos = Vector2(700.0, 900.0)
	game.dogs[1].pos = Vector2(730.0, 900.0)
	game.dogs[0].vel = Vector2.ZERO
	game.dogs[1].vel = Vector2.ZERO
	game._process(DT)
	game._process(DT)
	_check(_heard.count("sheep_bump") == 1, "two dogs that touch make one bump sound (REQ-SH-11): %s" % str(_heard))
	var face_before: int = game._faces[0]
	game.dogs[0].vel = Vector2(-200.0, 0.0)
	game.dogs[0].pos = _open_spot(game)
	game.dogs[1].pos = Vector2(300.0, 300.0)
	game._process(DT)
	_check(face_before == 1 and game._faces[0] == -1, "a dog looks the way it runs (REQ-SH-15)")


## A sheep that comes in: the score of everybody, the chip, the phones, the buzz, the sound (REQ-SH-10, 12, 13).
func _pen_and_score() -> void:
	print("a sheep in the pen")
	var game := _play()
	var rec := SimInput.record_haptics(game)
	game.dogs[1].pos = Vector2(300.0, 300.0)
	game.dogs[0].pos = Vector2(300.0, 900.0)
	var sheep = game.flock.sheep[0]
	sheep.pos = game.flock.gate_center() + Vector2(-30.0, 0.0)
	sheep.vel = Vector2(300.0, 0.0)
	sheep.scared = 0.6
	sheep.last_dog = 1
	_heard.clear()
	SimInput.run_until(game, func() -> bool: return sheep.penned, 2.0)
	_check(sheep.penned and game.flock.penned_count() == 1, "a sheep that runs through the gate is in the pen")
	_check(game._board.score(0) == 1.0 and game._board.score(1) == 1.0, "the score is one for every player (REQ-SH-5)")
	_check(rec.ms_of(1) == [40] and rec.ms_of(0).is_empty(),
			"only the dog that scared it feels a 40 ms buzz (REQ-SH-12): %s" % str(rec.log))
	_check(_heard.has("sheep_pen") and game._glow > 0.0 and game._stars.size() == 1, "the pen sound, the yellow fence and the star")
	await _frames(3)
	game._process(DT)
	await _frames(3)
	_check(_clients[0].score_text == "1 / 11" and _clients[1].score_text == "1 / 11"
			and _clients[0].score_rank == 0 and _clients[1].score_rank == 0, "every phone shows 1 / 11 and no place (REQ-SH-13): %s %s"
			% [_clients[0].score_text, _clients[1].score_text])
	SimInput.run(game, 1.0)
	_check(game._glow == 0.0 and game._stars.is_empty(), "the glow and the star go away")
	# The shout has a gap: a second fright inside 0.6 s makes no second baa (the real wait is longer than
	# the 40 ms of the sound manager).
	game._baa_wait = 0.0
	_heard.clear()
	game._on_flock_event({"t": "startled", "i": 1, "slot": 0, "pos": Vector2.ZERO})
	_check(_heard.count("sheep_baa") == 1 and is_equal_approx(game._baa_wait, game.BAA_GAP),
			"a fright makes a baa and starts the gap")
	await _real_wait(100)
	game._on_flock_event({"t": "startled", "i": 2, "slot": 0, "pos": Vector2.ZERO})
	_check(_heard.count("sheep_baa") == 1, "a second fright inside the gap makes no second baa (REQ-SH-12)")
	game._game_tick(game.BAA_GAP + 0.1)
	_check(game._baa_wait == 0.0, "the gap ends")


## The team chip (REQ-SH-13): "N / M" at the right margin, and at the left margin in Hebrew.
func _team_chip() -> void:
	print("the team chip")
	var Shell = load("res://scripts/game/shell.gd")
	var Lang = load("res://scripts/core/lang.gd")
	var game := _play()
	var seen: Array = []
	Shell.recorder = func(kind: String, _ci: CanvasItem, rect: Rect2, info: Dictionary) -> void:
		if kind in ["team", "leader"]:
			seen.append([kind, rect, info])
	game._request_redraw()
	await _frames(3)

	_check(not seen.is_empty() and seen[-1][0] == "team" and seen[-1][2].text == "0 / 11"
			and is_equal_approx(seen[-1][1].end.x, 1860.0),
			"the team chip shows 0 / 11 and ends at the right margin: %s" % str(seen.slice(-1)))
	_check(not seen.any(func(e: Array) -> bool: return e[0] == "leader"), "there is no leader chip: the score is shared")
	_pen_all(game, 4)
	game._process(DT)
	seen.clear()
	game._request_redraw()
	await _frames(3)
	_check(not seen.is_empty() and seen[-1][2].text == "4 / 11", "the chip follows the sheep in the pen: 4 / 11")
	Lang.set_language("he", root)
	seen.clear()
	game._request_redraw()
	await _frames(3)
	_check(not seen.is_empty() and is_equal_approx(seen[-1][1].position.x, 60.0), "in Hebrew the chip starts at the left margin")
	Lang.set_language("en", root)
	Shell.recorder = Callable()


## The two ways to end: every sheep is in, or the time is up (REQ-SH-5, 6, 18).
func _the_end() -> void:
	print("the end")
	var game := _play()
	_pen_all(game)
	_heard.clear()
	game._process(DT)
	_check(game.flock.all_penned() and not game.is_over and game._confetti.size() == game.CONFETTI_COUNT
			and game._end_left > 1.5, "every sheep is in: confetti first, the result is not open yet")
	SimInput.run(game, 1.0)
	_check(not game.is_over and game._confetti[0].pos.y != game.pen.position.y, "the confetti moves for a moment")
	SimInput.run_until(game, func() -> bool: return game.is_over, 3.0)
	await _frames(3)
	var labels := _result_labels(game)
	var buttons: Array = game.menu_buttons().map(func(b): return b.text)
	_check(game.is_over and labels[0] == "ALL SHEEP ARE SAFE!" and labels.has("1ST   SIM0   11 / 11 SHEEP")
			and labels.has("1ST   SIM1   11 / 11 SHEEP"),
			"with 2 players the title says that all sheep are safe, and the list has the same score for both: %s" % str(labels))
	_check(MedalView.tiers_in(game._menu_box) == ["gold", "gold"],
			"with 2 players the shared score is a tie for 1st, so both rows have the gold medal (REQ-GM-73a)")
	_check(buttons == ["minigame.restart", "minigame.new_game", "minigame.back_to_menu"], "the buttons: %s" % str(buttons))
	_check(_heard.has("win") and not _heard.has("tie"), "the team wins: the win sound")
	# Time is up with 3 sheep in the pen.
	var game2 := _play()
	_pen_all(game2, 3)
	_heard.clear()
	game2._round.time = game2._round.duration - 0.005
	game2._game_tick(0.01)
	await _frames(3)
	var labels2 := _result_labels(game2)
	_check(game2.is_over and labels2[0] == "3 OF 11 SHEEP ARE SAFE!",
			"time up with 3 sheep in: the title is positive and has the numbers: %s"
			% str(labels2))
	_check(_heard.has("tie") and not _heard.has("win"), "not all sheep in: the soft sound, not the win")
	_check(game2._board.score(0) == 3.0 and game2._board.score(1) == 3.0, "both players have 3 sheep")
	# The result opens at once when the time is up, without the confetti.
	_check(game2._confetti.is_empty(), "no confetti when the time is up")


## One player: no medal, the title is the difficulty and the list shows the sheep (REQ-SH-18, REQ-GM-73).
func _one_player() -> void:
	print("one player")
	var cases := {"easy": [3, 4, 6, 8], "medium": [5, 6, 9, 11], "hard": [7, 8, 11, 14]}
	var all_ok := true
	for d in cases:
		for n in cases[d]:
			var game := _play(d)
			_pen_all(game, int(n))
			game._round.time = game._round.duration - 0.005
			SimInput.run_until(game, func() -> bool: return game.is_over, 4.0)
			await _frames(2)
			var labels := _result_labels(game)
			var medals: Array = MedalView.tiers_in(game._menu_box)
			var ok: bool = game.is_over and labels[0] == d.to_upper() and medals.is_empty()
			ok = ok and labels.has("1ST   SIM0   %d / %d SHEEP" % [int(n), game.flock.sheep.size()])
			if not ok:
				print("    bad case: ", d, " ", n, " ", labels, " ", medals)
			all_ok = all_ok and ok
	_check(all_ok, "one player gets no medal at any number of sheep, and the title is the difficulty (REQ-SH-18)")
	var game2 := _play()
	_pen_all(game2)
	_heard.clear()
	_quiet()
	await _real_wait(60)
	SimInput.run_until(game2, func() -> bool: return game2.is_over, 4.0)
	_check(game2.is_over and MedalView.tiers_in(game2._menu_box).is_empty() and _heard.has("win"),
			"one player with every sheep in has no medal, and hears the win sound: %s" % str(_heard))


## A player leaves: the dog goes, the round goes on, nobody is out (REQ-SH-9).
func _leave() -> void:
	print("a player leaves")
	var game := _play()
	_pen_all(game, 2)
	game._process(DT)
	_check(game.dogs.size() == 3 and game._board.score(2) == 2.0, "3 dogs, and the score is 2 for the player in slot 2")
	_app.server.kick(2)
	await _frames(3)
	game._process(DT)
	_check(not game.dogs.has(2) and game.dogs.size() == 2 and not game.is_over and game.participants.size() == 2,
			"the dog of a player that left is gone and the round goes on")
	_check(game.flock.penned_count() == 2, "the sheep in the pen stay in the pen")
	_pen_all(game)
	SimInput.run_until(game, func() -> bool: return game.is_over, 4.0)
	await _frames(3)
	var labels := _result_labels(game)
	_check(game.is_over and labels[0] == "ALL SHEEP ARE SAFE!" and labels.size() >= 3,
			"the 2 players that are left win together: %s" % str(labels))


## The layout (REQ-SH-19) and Restart.
func _layout_and_restart() -> void:
	print("the layout and Restart")
	var game := _play("hard", 3)
	var f: Rect2 = game.field
	var inside := f.position.x >= 60.0 and f.position.y >= 152.0 and f.end.x <= 1860.0 and f.end.y <= 1020.0 \
			and fmod(f.position.x, 4.0) == 0.0 and fmod(f.size.x, 4.0) == 0.0 and fmod(f.size.y, 4.0) == 0.0
	_check(inside, "the field is inside the margin and under the HUD, on the grid of world pixels: %s" % str(f))
	_check(f.grow(1.0).encloses(game.pen) and game.pen.end.x <= f.end.x - 40.0, "the pen is inside the field")
	var things_in := true
	for it in game.scenery.items:
		things_in = things_in and f.has_point(it.pos)
	for s in game.flock.sheep:
		things_in = things_in and f.has_point(s.pos)
	_check(things_in, "every thing and every sheep stands on the field")
	var barn: Rect2 = game._barn_box()
	_check(f.has_point(barn.position) and f.has_point(barn.end) and barn.end.y < game.pen.position.y + 1.0,
			"the barn, the silo and the vane are on the field, above the pen: %s" % str(barn))
	var vane_top: float = game.barn_origin.y - 14.0 * 4.0
	_check(vane_top >= f.position.y, "the weather vane is on the field")
	_check(game._pixel_world() and game._pixel_viewport.size == Vector2i(480, 270),
			"the world is drawn in the 480x270 pixel view (REQ-SH-15)")
	for res in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = res
		await _frames(4)
		game._request_redraw()
		await _frames(2)
	_check(game.field == f and game._pixel_viewport.size == Vector2i(480, 270),
			"the world is simulated in the same units at 1280x720 and 1920x1080 (REQ-SH-19)")
	var items_before: Array = game.scenery.items.duplicate()
	var difficulty_before: String = game.difficulty
	game.restart()
	await _frames(4)
	var again: Control = _app.current_screen()
	var same: bool = is_instance_of(again, _script) and again.difficulty == difficulty_before and again.flock.penned_count() == 0 \
			and again.scenery.items.size() == items_before.size()
	for i in mini(items_before.size(), again.scenery.items.size()):
		same = same and again.scenery.items[i].pos == items_before[i].pos
	_check(same, "Restart starts a new round with the same difficulty and the same field (the seed is kept)")
