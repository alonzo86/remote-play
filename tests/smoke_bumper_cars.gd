extends SceneTree
## Bumper Cars with simulated phones and a fixed time step (REQ-BC-1 to 20): the settings view, the countdown, the tilt, the
## stars that cars pick up, a hit that only bonks (no star is lost), the end and the result, a player that leaves, the layout and
## Restart. The game is stepped by hand (`SimInput`).
## Run: godot --headless --path . --script tests/smoke_bumper_cars.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const Shell = preload("res://scripts/game/shell.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")

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


## A game in play (the countdown is over), stepped by hand.
func _play(difficulty := "medium", seed_value := 7) -> Control:
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	var game := SimInput.start_game(_app, _script, {"difficulty": difficulty, "seed": seed_value})
	SimInput.to_play(game, func() -> bool: return game._round.is_counting())
	return game


func _result_labels(game: Control) -> Array:
	var out: Array = []
	for l in game._menu_box.find_children("*", "Label", true, false):
		out.append(String(l.text).to_upper())
	return out


## Puts a star that nobody can pick up yet far from the cars: it is a marker that the floor is full.
func _clear_floor(game: Control) -> void:
	game.rink.stars.clear()
	game.rink.star_count = 0


## Puts car 0 left of car 1, 80 px between the middles, car 0 driving at 500 px/s and car 1 standing: a hit.
func _stage_hit(game: Control) -> void:
	var mid: Vector2 = game.rink.rink.get_center()
	game._bodies[0].pos = mid + Vector2(-70.0, 0.0)
	game._bodies[0].vel = Vector2(500.0, 0.0)
	game._bodies[1].pos = mid + Vector2(10.0, 0.0)
	game._bodies[1].vel = Vector2.ZERO


## Moves both cars to the corners and lets `seconds` pass with nobody near a star (the floor has none).
func _wait_apart(game: Control, seconds: float) -> void:
	game._bodies[0].pos = game.rink.rink.position + Vector2(100.0, 100.0)
	game._bodies[1].pos = game.rink.rink.end - Vector2(100.0, 100.0)
	game._bodies[0].vel = Vector2.ZERO
	game._bodies[1].vel = Vector2.ZERO
	SimInput.run(game, seconds)
	game.rink.stars.clear()


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_sound = root.get_node("Sound")
	_script = load("res://scripts/game/bumper_cars/bumper_cars_game.gd")
	_sound.sfx_played.connect(func(id: String) -> void: _heard.append(id))
	load("res://scripts/game/game_settings.gd").clear()
	_clients = await SimInput.connect_phones(self, _app, 2)
	_check(_app.server.connected_slots().size() == 2, "2 simulated phones joined")
	await _settings()
	await _start()
	await _drive_and_pick_up()
	await _tilt_timing()
	await _hits()
	await _the_end()
	await _layout_and_restart()
	_clients = await SimInput.connect_phones(self, _app, 3, _clients)
	await _lost_phone()
	await _leave()
	for c in _clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The registry entry and the settings view (REQ-BC-20, REQ-GM-20, REQ-GM-90).
func _settings() -> void:
	print("the settings view")
	var Registry = load("res://scripts/game/registry.gd")
	var entry: Dictionary = Registry.find("bumper_cars")
	_check(entry.min_players == 2 and entry.max_players == 4 and entry.pad == [] and entry.settings == [],
			"2 to 4 players, no control on the pad (REQ-BC-2), and Difficulty is the only row (REQ-BC-20)")
	_check(not Registry.accepts(entry, 1) and Registry.accepts(entry, 2) and Registry.accepts(entry, 4)
			and not Registry.accepts(entry, 5) and Registry.reason(entry, 1) == "Needs 2 players",
			"the game needs 2 to 4 players (no solo mode)")
	_app.go_game_settings("bumper_cars")
	await _frames(4)
	var sv: Control = _app.current_screen()
	_check(is_instance_of(sv, load("res://scripts/ui/tv_game_settings.gd")) and sv.rows.size() == 1 and sv.rows[0].value == "medium",
			"the settings view opens with Difficulty on Medium")
	var key := InputEventAction.new()
	key.action = "ui_right"
	key.pressed = true
	sv.rows[0]._gui_input(key)
	sv.start()
	await _frames(4)
	var hard: Control = _app.current_screen()
	_check(is_instance_of(hard, _script) and hard.difficulty == "hard" and hard.rink.stars.size() == 6
			and hard.rink.rink.size.x < 1700.0 and hard._round.duration == 60.0,
			"Hard gives 6 stars, a smaller rink and 60 s (REQ-BC-20)")
	_check(hard.best_key() == "", "no personal best (REQ-GM-98)")


## The start of a round (REQ-BC-1, 2, 3, 9).
func _start() -> void:
	print("the start")
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	var game := SimInput.start_game(_app, _script, {"difficulty": "medium", "seed": 7})
	_check(game.rink.stars.size() == 9 and game._board.score(0) == 0.0 and game._board.score(1) == 0.0
			and game._round.duration == 60.0,
			"Medium has 9 stars on the floor, nobody has a star and the round is 60 s (REQ-BC-1, 9)")
	var c0: Vector2 = game._bodies[0].pos
	var c1: Vector2 = game._bodies[1].pos
	_check(c0.x == c1.x and c0.y < c1.y and game.rink.rink.has_point(c0) and game.rink.rink.has_point(c1)
			and c0.distance_to(c1) > 96.0, "the 2 cars start apart, one above the other, inside the rink (REQ-BC-3)")
	var p0: RefCounted = _app.server.players[0]
	for i in 30:
		_sim.feed(p0, Vector2(0.7, 0.0))
	SimInput.run(game, 1.5)
	_check(game._round.is_counting() and game._bodies[0].pos == c0 and game.rink.stars.size() == 9,
			"during the countdown the cars do not move (REQ-BC-1, REQ-GM-35)")
	SimInput.to_play(game, func() -> bool: return game._round.is_counting())
	_check(game._round.is_playing() and not game.is_over, "the round plays after the countdown")
	var other := SimInput.start_game(_app, _script, {"difficulty": "medium", "seed": 7})
	var same: bool = other.rink.stars.size() == game.rink.stars.size()
	for i in mini(other.rink.stars.size(), 9):
		same = same and other.rink.stars[i].pos == game.rink.stars[i].pos
	_check(same, "the same seed gives the same stars")
	var easy := SimInput.start_game(_app, _script, {"difficulty": "easy", "seed": 7})
	_check(easy.rink.stars.size() == 12 and easy.rink.rink.size == easy.rink.LARGEST.size,
			"Easy has 12 stars and the largest rink")


## The tilt drives only the car of that phone; a car that reaches a star picks it up (REQ-BC-4, 9, 10).
func _drive_and_pick_up() -> void:
	print("driving and stars")
	var game := _play()
	var rec := SimInput.record_haptics(game)
	var p0: RefCounted = _app.server.players[0]
	var start0: Vector2 = game._bodies[0].pos
	var start1: Vector2 = game._bodies[1].pos
	for i in 120:
		_sim.feed(p0, Vector2.ZERO)
	p0.recenter()
	for i in 60:
		_sim.feed(p0, Vector2(0.7, 0.0))
		game._process(DT)
	_check(game._bodies[0].pos.x > start0.x + 60.0 and game._bodies[1].pos.distance_to(start1) < 1.0,
			"tilt to the right moves the car of that phone to the right and not the other (REQ-BC-4)")
	_check(game._bodies[0].vel.length() <= game._bodies[0].max_speed + 0.01 and game._bodies[0].radius == 48.0,
			"a car is a disk of 48 px and not faster than the speed limit")
	SimInput.set_tilt(p0, Vector2.ZERO)
	_clear_floor(game)
	game.rink.star_count = 3
	game._bodies[0].pos = Vector2(900.0, 600.0)
	game._bodies[0].vel = Vector2.ZERO
	game._bodies[1].pos = Vector2(1500.0, 850.0)
	game._bodies[1].vel = Vector2.ZERO
	game.rink.stars.append({"pos": Vector2(900.0 + 50.0, 600.0), "blink": 0.0})
	game.rink.stars.append({"pos": Vector2(1300.0, 300.0), "blink": 0.0})
	game.rink.stars.append({"pos": Vector2(300.0, 900.0), "blink": 0.0})
	_quiet()
	await _real_wait(60)
	_heard.clear()
	rec.log.clear()
	game._process(DT)
	_check(game._board.score(0) == 1.0 and game._board.score(1) == 0.0 and game.rink.stars.size() == 2,
			"a car 50 px from a star picks it up: 1 star, and the star is gone (REQ-BC-10)")
	_check(rec.ms_of(0) == [15] and rec.ms_of(1).is_empty(), "the phone of the car buzzes 15 ms: %s" % str(rec.log))
	_check(_heard.has("car_star"), "the sound car_star plays: %s" % str(_heard))
	game._process(DT)
	_check(game._board.score(0) == 1.0, "one star is counted once")
	SimInput.run(game, 0.7)
	_check(game.rink.stars.size() == 3, "0.7 s later the floor has a new star again (REQ-BC-9)")
	var cars_clear := true
	for s in game.rink.stars:
		cars_clear = cars_clear and (s.pos as Vector2).distance_to(game._bodies[0].pos) >= 70.0
	_check(cars_clear, "the new star is not under a car")


## Test 32 steps 3a to 3c: a tilt of 20 degrees takes a car from the middle to the rail in 4 s or less, a flat phone stops it
## in 3 s, and the other car stays where it is (REQ-BC-4).
func _tilt_timing() -> void:
	print("the time of a tilt")
	var game := _play()
	_clear_floor(game)
	var p0: RefCounted = _app.server.players[0]
	var middle: Vector2 = game.rink.rink.get_center()
	var other_start: Vector2 = game._bodies[1].pos
	game._bodies[0].pos = middle
	game._bodies[0].vel = Vector2.ZERO
	var tilt := Vector2(sin(deg_to_rad(20.0)), 0.0)
	var rail_x: float = game.rink.rink.end.x - game._bodies[0].radius - 1.0
	var t := 0.0
	while t < 6.0 and game._bodies[0].pos.x < rail_x:
		_sim.feed(p0, tilt)
		game._process(DT)
		t += DT
	_check(game._bodies[0].pos.x >= rail_x and t <= 4.0,
				"a tilt of 20 degrees takes the car to the right rail in %.2f s (4 s or less)" % t)
	_check(game._bodies[1].pos.distance_to(other_start) < 1.0, "the other car does not move while only the first phone is tilted")
	t = 0.0
	while t < 6.0 and game._bodies[0].vel.length() >= 20.0:
		_sim.feed(p0, Vector2.ZERO)
		game._process(DT)
		t += DT
	_check(game._bodies[0].vel.length() < 20.0 and t <= 3.0,
				"the flat phone stops the car (under 20 px/s) in %.2f s (3 s or less)" % t)


## A hit: a bonk with a spark and a buzz; nobody loses a star (REQ-BC-6, 7).
func _hits() -> void:
	print("hits")
	var game := _play()
	var rec := SimInput.record_haptics(game)
	_clear_floor(game)
	game.rink.star_count = 0
	var mid: Vector2 = game.rink.rink.get_center()
	game._board.add(1, 2.0)
	game._board.add(0, 1.0)
	game._bodies[0].pos = mid + Vector2(-70.0, 0.0)
	game._bodies[0].vel = Vector2(500.0, 0.0)
	game._bodies[1].pos = mid + Vector2(10.0, 0.0)
	game._bodies[1].vel = Vector2.ZERO
	_quiet()
	await _real_wait(60)
	_heard.clear()
	rec.log.clear()
	game._process(DT)
	_check(game._board.score(0) == 1.0 and game._board.score(1) == 2.0 and game.rink.stars.is_empty(),
			"car 0 hits car 1 that stands: nobody loses a star (1 and 2 stay), and no star lies on the floor (REQ-BC-7)")
	_check(rec.ms_of(0) == [25] and rec.ms_of(1) == [25], "both phones buzz 25 ms: %s" % str(rec.log))
	_check(_heard.has("car_bump") and not _heard.has("car_drop"), "the sound car_bump plays: %s" % str(_heard))
	_check(game._hits.size() == 1, "a spark shows where they met")
	# The same pair cannot hit again for 0.6 s: no second spark and no second buzz.
	_stage_hit(game)
	rec.log.clear()
	game._process(DT)
	_check(game._hits.size() == 1 and rec.ms_of(0).is_empty() and rec.ms_of(1).is_empty(),
			"the same pair does not hit again at once (REQ-BC-7)")
	_wait_apart(game, 0.7)
	_stage_hit(game)
	rec.log.clear()
	game._process(DT)
	_check(game._hits.size() == 1 and rec.ms_of(0) == [25] and rec.ms_of(1) == [25]
			and game._board.score(0) == 1.0 and game._board.score(1) == 2.0,
			"after 0.7 s it can: a new spark and buzz, and still nobody loses a star")
	# A slow touch is no hit.
	_wait_apart(game, 0.7)
	game._bodies[0].pos = mid + Vector2(-60.0, 0.0)
	game._bodies[0].vel = Vector2(100.0, 0.0)
	game._bodies[1].pos = mid + Vector2(10.0, 0.0)
	game._bodies[1].vel = Vector2.ZERO
	var spark_count: int = game._hits.size()
	rec.log.clear()
	game._process(DT)
	_check(game._board.score(1) == 2.0 and game._hits.size() == spark_count
			and game._bodies[0].pos.distance_to(game._bodies[1].pos) >= 95.9,
			"a slow touch only bounces: no star drops, no spark, and the cars do not overlap (REQ-BC-5, 6)")
	_check(rec.ms_of(0).is_empty() and rec.ms_of(1).is_empty(), "a slow touch buzzes no phone: %s" % str(rec.log))


## The end: the most stars win (REQ-BC-12).
func _the_end() -> void:
	print("the end")
	var game := _play()
	_clear_floor(game)
	game._board.add(0, 3.0)
	game._board.add(1, 5.0)
	_quiet()
	await _real_wait(60)
	_heard.clear()
	SimInput.run(game, 0.5)
	await _frames(3)
	_check(_clients[0].score_rank == 2 and _clients[0].score_text == "3" and _clients[1].score_rank == 1
			and _clients[1].score_text == "5",
			"during the round each phone shows its own stars and its place (REQ-FL-67, REQ-BC-14): %d/%s, %d/%s"
			% [_clients[0].score_rank, _clients[0].score_text, _clients[1].score_rank, _clients[1].score_text])
	game._round.time = game._round.duration - 0.005
	game._game_tick(0.01)
	await _frames(3)
	var labels := _result_labels(game)
	var buttons: Array = game.menu_buttons().map(func(b): return b.text)
	_check(game.is_over and labels[0] == "SIM1 WINS!" and labels.has("1ST   SIM1   5 STARS") and labels.has("2ND   SIM0   3 STARS"),
			"time up: the title names the winner, and the list has the stars: %s" % str(labels))
	_check(buttons == ["minigame.restart", "common.settings", "minigame.back_to_menu"], "the buttons: %s" % str(buttons))
	_check(_heard.has("win"), "the win sound plays")
	var tie := _play()
	_clear_floor(tie)
	tie._board.add(0, 1.0)
	tie._board.add(1, 1.0)
	tie._round.time = tie._round.duration - 0.005
	tie._game_tick(0.01)
	await _frames(3)
	var tie_labels := _result_labels(tie)
	_check(tie.is_over and tie_labels[0] == "TIE!" and tie_labels.has("1ST   SIM0   1 STAR")
			and tie_labels.has("1ST   SIM1   1 STAR"),
			"the same number of stars is a tie, and 1 is '1 star': %s" % str(tie_labels))
	var clock := _play()
	_clear_floor(clock)
	SimInput.run(clock, 59.0)
	_check(not clock.is_over and absf(clock._round.remaining() - 1.0) < 0.1, "after 59 s the clock shows 1 s")
	SimInput.run(clock, 1.2)
	_check(clock.is_over, "after 60 s the round is over")


## The layout (REQ-BC-17) and Restart.
func _layout_and_restart() -> void:
	print("the layout and Restart")
	var game := _play("medium", 3)
	var r: Rect2 = game.rink.rink
	var tent_end := 112.0 + 64.0 + 24.0
	_check(r.position.x - 16.0 >= 60.0 and r.end.x + 16.0 <= 1860.0 and r.end.y + 16.0 <= 1020.0 and r.position.y - 16.0 >= tent_end,
			"the rink with its rail is inside the 60 px margin and under the tent: %s" % str(r))
	_check(game._pixel_world() and game._pixel_viewport.size == Vector2i(480, 270),
			"the world is drawn in the 480x270 pixel view (REQ-BC-16)")
	var pixel_scale: float = 1080.0 / float(game._pixel_viewport.size.y)
	_check(pixel_scale * 20.0 >= 48.0,
				"a car is 20 world pixels high, %.0f px on a 1080p screen (48 px or more, REQ-GM-47e)" % (pixel_scale * 20.0))
	for res in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = res
		await _frames(4)
		game._request_redraw()
		await _frames(2)
	_check(game.rink.rink == r and game._pixel_viewport.size == Vector2i(480, 270),
			"the world is simulated in the same units at 1280x720 and 1920x1080 (REQ-BC-17)")
	var Lang = load("res://scripts/core/lang.gd")
	var english_lines: Array = Shell.title_lines("registry.bumper_cars", game.title_room(), game.TITLE_FONT)
	Lang.set_language("he", root)
	var hebrew_lines: Array = Shell.title_lines("registry.bumper_cars", game.title_room(), game.TITLE_FONT)
	Lang.set_language("en", root)
	var room: float = game.title_room()
	var widest := 0.0
	for line in hebrew_lines:
		widest = maxf(widest, UiTheme.font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, game.TITLE_FONT).x)
	_check(english_lines.size() == 1 and hebrew_lines.size() == 2 and game.TITLE_FONT == 32 and widest <= room
			and " ".join(hebrew_lines) == Lang.table()["registry.bumper_cars"].he.to_upper(),
			"the title is 32 px: one line in English, two lines in Hebrew (one would touch the timer), all letters (REQ-BC-16): %s, %s"
			% [str(english_lines), str(hebrew_lines)])
	var stars_before: Array = game.rink.stars.duplicate(true)
	var difficulty_before: String = game.difficulty
	game.restart()
	await _frames(4)
	var again: Control = _app.current_screen()
	var same: bool = is_instance_of(again, _script) and again.difficulty == difficulty_before \
			and again.rink.stars.size() == stars_before.size()
	for i in mini(stars_before.size(), again.rink.stars.size()):
		same = same and again.rink.stars[i].pos == stars_before[i].pos
	_check(same and again._board.score(0) == 0.0,
			"Restart starts a new round with the same difficulty and the same stars (the seed is kept)")


## A player leaves (REQ-BC-11).
## REQ-BC-13: a lost phone pauses the round with the card of REQ-GM-30. Nothing runs during the pause: the cars (even with a
## tilted phone), the clock and the stars (a star that was picked up is not replaced).
func _lost_phone() -> void:
	print("a phone is lost")
	var game := _play()
	game.rink.stars.remove_at(0)   # A hole in the stars: the rink would add one on its next tick.
	game.rink._spawn_wait = 0.0
	var lost: RefCounted = _app.server.players[1]
	lost.state = PlayerInput.State.LOST
	game._process(DT)
	_check(game.is_paused() and game._hold and game.lost_participants() == [1] and game._menu_kind == "hold",
			"REQ-BC-13: a lost phone pauses the round with the card of the lost phone")
	var cars: Array = game._bodies.keys().map(func(s: int) -> Vector2: return game._bodies[s].pos)
	var clock: float = game._round.time
	var stars_before: int = game.rink.stars.size()
	var p0: RefCounted = _app.server.players[0]
	for i in 600:   # 10 s, with a tilted phone 0.
		_sim.feed(p0, Vector2(sin(deg_to_rad(20.0)), 0.0))
		game._process(DT)
	var after: Array = game._bodies.keys().map(func(s: int) -> Vector2: return game._bodies[s].pos)
	_check(after == cars and is_equal_approx(game._round.time, clock) and game.rink.stars.size() == stars_before,
			"REQ-BC-13: 10 s later the cars, the clock and the stars have not moved (clock %.2f, %d stars)"
			% [game._round.time, game.rink.stars.size()])
	lost.state = PlayerInput.State.CONNECTED
	game._process(DT)
	await _frames(2)
	var buttons: Array = game.menu_buttons().map(func(b: Button) -> String: return b.text)
	_check(game.is_paused() and buttons.has("minigame.resume"), "the phone is back: the round waits for Resume (REQ-GM-30)")
	for i in 60:
		_sim.feed(p0, Vector2.ZERO)   # Resume recenters: the pose held while the card shows is the center.
	game.menu_buttons()[0].pressed.emit()
	await _frames(2)
	for i in 60:
		_sim.feed(p0, Vector2(sin(deg_to_rad(20.0)), 0.0))
		game._process(DT)
	_check(not game.is_paused() and game._bodies[0].pos != cars[0] and game._round.time > clock,
			"REQ-BC-13: after Resume the car and the clock move again")


func _leave() -> void:
	print("a player leaves")
	var game := _play()
	game._board.add(2, 4.0)
	game._process(DT)
	_check(game._bodies.size() == 3 and game._board.score(2) == 4.0, "3 cars, and 4 stars for the player in slot 2")
	_app.server.kick(2)
	await _frames(3)
	game._process(DT)
	_check(not game._bodies.has(2) and game._bodies.size() == 2 and not game.is_over and game.participants.size() == 2,
			"the car of a player that left is gone and the round goes on")
	_app.server.kick(1)
	await _frames(3)
	game._process(DT)
	await _frames(3)
	_check(game.is_over, "with one player left the match is over at once (REQ-BC-11)")
