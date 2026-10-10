extends SceneTree
## Smoke test of Sumo Bumpers with three simulated phones (REQ-SB-*). Run:
##   godot --headless --path . --script tests/smoke_sumo.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

var _fails := 0
var _checks := 0
var _seq := [0, 0, 0]


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


func _stream(clients: Array, seconds: float, accel: Array) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in clients.size():
			clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO, accel[i], 0, 0, Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


## A new `Haptics` without a past: a test reads what it has noted (`_last`). It is loaded here because it needs the App autoload.
func _new_haptics() -> RefCounted:
	return load("res://scripts/game/haptics.gd").new()


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var Sumo = load("res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd")
	var TvGameSettings = load("res://scripts/ui/tv_game_settings.gd")
	var GameSettings = load("res://scripts/game/game_settings.gd")
	var app: Node = root.get_node("App")
	GameSettings.clear()
	var clients: Array = []
	for i in 3:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame
	var flat := Vector3(0, 0, 9.81)
	var lean := deg_to_rad(15.0)
	var right := Vector3(-sin(lean), 0, cos(lean)) * 9.81
	await _stream(clients, 0.5, [flat, flat, flat])

	# The settings view and the difficulty (REQ-SB-20).
	app.go_game_settings("sumo_bumpers")
	await _frames(4)
	var sv: Control = app.current_screen()
	_check(is_instance_of(sv, TvGameSettings) and sv.rows.size() == 1 and sv.rows[0].value == "medium"
			and not sv.start_button.disabled, "Sumo Bumpers opens the settings view with Difficulty on Medium and Start works")
	var key := InputEventAction.new()
	key.action = "ui_right"
	key.pressed = true
	sv.rows[0]._gui_input(key)
	sv.start()
	await _frames(4)
	var hard: Control = app.current_screen()
	_check(is_instance_of(hard, Sumo) and hard.difficulty == "hard" and hard.arena.start_radius == 330.0,
			"Hard gives a platform of 330 px (REQ-SB-20)")
	GameSettings.clear()

	# A match on Medium.
	app.go(Sumo, {"difficulty": "medium"})
	await _frames(3)
	var game: Control = app.current_screen()
	_check(game.participants.size() == 3 and game.round_no == 1 and game.phase == game.Phase.COUNT and game._alive.size() == 3,
			"a match starts with 3 bumpers in round 1 and the countdown (REQ-SB-1)")
	var spots: Array = game.arena.start_spots(3)
	_check(game._bodies[0].pos.is_equal_approx(spots[0]) and game._bodies[2].pos.is_equal_approx(spots[2]),
			"the bumpers start at the places around the middle (REQ-SB-2)")
	await _stream(clients, 1.5, [right, right, right])
	_check(game.phase == game.Phase.COUNT and game._bodies[0].pos.is_equal_approx(spots[0]),
			"during the countdown the bumpers do not move (REQ-SB-1)")
	await _stream(clients, 2.2, [flat, flat, flat])
	_check(game.phase == game.Phase.PLAY, "the round plays after the countdown")

	# A dash (REQ-SB-10).
	await _stream(clients, 1.5, [right, flat, flat])
	game._bodies[0].vel = Vector2.ZERO
	var tilt: Vector2 = game.player(0).tilt()
	game._haptics = _new_haptics()
	game._on_button(Protocol.BTN_A, 0)
	game._game_tick(0.016)
	_check(tilt.length() > 0.05 and game._bodies[0].vel.length() > 650.0 and game._dash_left[0] > 1.9,
			"A dashes in the way of the tilt, and the dash needs time to be ready again")
	_check(game._haptics._last.has(0) and not game._haptics._last.has(1), "a dash buzzes the phone that dashed (REQ-SB-11)")
	var after: Vector2 = game._bodies[0].vel
	game._bodies[0].vel = Vector2.ZERO
	game._on_button(Protocol.BTN_A, 0)
	game._game_tick(0.016)
	_check(game._bodies[0].vel.length() < 100.0, "a dash that is not ready does nothing")
	_check(after.length() > 0.0, "the first dash gave speed")

	# A bump buzzes both phones when it is fast, and none when it is slow (REQ-SB-8).
	game._haptics = _new_haptics()
	game._bodies[0].pos = Vector2(0.0, 0.0)
	game._bodies[1].pos = Vector2(50.0, 0.0)
	game._bodies[0].vel = Vector2(400.0, 0.0)
	game._bodies[1].vel = Vector2.ZERO
	game._bump(0, 1)
	var fast_buzz: bool = game._haptics._last.has(0) and game._haptics._last.has(1)
	game._haptics = _new_haptics()
	game._bodies[0].pos = Vector2(0.0, 0.0)
	game._bodies[1].pos = Vector2(50.0, 0.0)
	game._bodies[0].vel = Vector2(150.0, 0.0)
	game._bodies[1].vel = Vector2.ZERO
	game._bump(0, 1)
	_check(fast_buzz and game._haptics._last.is_empty(), "a fast bump buzzes both phones and a slow bump buzzes none (REQ-SB-8)")

	# Falls and the end of a round (REQ-SB-3, 4).
	for s in [0, 1, 2]:
		game._bodies[s].pos = spots[s]
		game._bodies[s].vel = Vector2.ZERO
	var edge: float = game.arena.radius() + 60.0
	_check(game.arena.speedup == 1.0, "before the first fall the platform shrinks at the normal rate")
	game._bodies[1].pos = Vector2(edge, 0.0)
	game._game_tick(0.016)
	_check(not game._alive.has(1) and game._falling.has(1) and game.phase == game.Phase.PLAY,
			"a bumper outside the platform falls and the round goes on with two")
	var shrunk: float = game.arena.time
	game._game_tick(0.1)
	_check(game.arena.speedup == 2.0 and is_equal_approx(game.arena.time - shrunk, 0.2),
			"after the first fall the platform shrinks twice as fast (REQ-SB-6)")
	game._bodies[2].pos = Vector2(0.0, edge)
	game._game_tick(0.016)
	_check(game.phase == game.Phase.BANNER and game._board.score(0) == 1.0 and game.banner_text.ends_with("wins the round!"),
			"the last bumper gets the point and a banner names it: %s" % game.banner_text)
	game._banner_left = 0.01
	game._game_tick(0.02)
	_check(game.round_no == 2 and game.phase == game.Phase.COUNT and game._alive.size() == 3 and game.arena.time == 0.0
			and game._bodies[1].pos.is_equal_approx(spots[1]) and game.arena.radius() == 380.0 and game.arena.speedup == 1.0,
			"round 2 starts with all bumpers back, also the ones that fell, on a full platform (REQ-SB-2)")
	game._game_tick(3.5)
	for s in [0, 1, 2]:
		game._bodies[s].pos = Vector2.from_angle(2.1 * s) * edge   # Apart, so that the bumps do not push one back in.
	game._game_tick(0.016)
	_check(game.phase == game.Phase.BANNER and game.banner_text == "Round draw!" and game._board.score(0) == 2.0
			and game._board.score(1) == 1.0 and game._board.score(2) == 1.0,
			"bumpers that fall in the same moment all get the point (REQ-SB-3)")
	game._banner_left = 0.01
	game._game_tick(0.02)
	game._game_tick(3.5)
	game._bodies[1].pos = Vector2(edge, 0.0)
	game._bodies[2].pos = Vector2(-edge, 0.0)
	game._game_tick(0.016)
	_check(game._board.score(0) == 3.0 and game.round_no == 3, "round 3 gives the third point to bumper 0")
	game._banner_left = 0.01
	game._game_tick(0.02)
	await _frames(3)
	var buttons: Array = game.menu_buttons().map(func(b): return b.text)
	var labels: Array = []
	for l in game._menu_box.find_children("*", "Label", true, false):
		labels.append(l.text)
	_check(game.is_over and buttons == ["RESTART", "SETTINGS", "BACK TO MENU"] and labels[0] == "SIM0 WINS!"
			and labels[1].ends_with("3 POINTS") and labels[2].ends_with("1 POINT"),
			"after round 3 the result menu names the winner and lists the points: %s %s" % [str(buttons), str(labels)])

	# The layout (REQ-SB-16): the platform is inside the margin at two sizes, at every difficulty.
	var fits_ok := true
	for res in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = res
		await _frames(4)
		var fit: Dictionary = game._fit()
		for r in [430.0, 380.0, 330.0]:
			var d: float = (r + 12.0) * fit.k
			fits_ok = fits_ok and fit.center.x - d >= 59.0 and fit.center.x + d <= game.size.x - 59.0 \
					and fit.center.y - d >= 149.0 and fit.center.y + d <= game.size.y - 59.0
	_check(fits_ok, "the platform is inside the margin and under the HUD at 1280x720 and 1920x1080 (REQ-SB-16)")
	root.size = Vector2i(1920, 1080)
	await _frames(3)
	# The world is drawn in a 480x270 view that stands for the whole screen, behind the HUD (REQ-GM-47i).
	var view: SubViewport = game._pixel_viewport
	_check(game._pixel_world() and view != null and view.size == Vector2i(480, 270) and view.size_2d_override_stretch
			and view.size_2d_override == Vector2i(game.size) and game._pixel_layer.size == game.size,
			"the world is drawn in a 480x270 view that follows the size of the game (REQ-GM-47i)")
	root.size = Vector2i(1280, 720)
	await _frames(3)
	_check(view.size == Vector2i(480, 270) and view.size_2d_override == Vector2i(game.size),
			"the view still stands for the whole screen at 1280x720, and stays 480x270")
	root.size = Vector2i(1920, 1080)
	await _frames(3)

	# Players leave (REQ-SB-12).
	game.restart()
	await _frames(4)
	game = app.current_screen()
	_check(is_instance_of(game, Sumo) and game.round_no == 1 and game._board.score(0) == 0.0,
			"Restart starts a new match with 0 points")
	# A lost phone pauses the match and nothing runs during the pause (REQ-SB-13): a phone that goes silent, like one without Wi-Fi.
	await _stream(clients, 3.4, [flat, flat, flat])
	_check(game.phase == game.Phase.PLAY and game.arena.time > 0.0, "the new match plays")
	app.server.peer_timeout_ms = 2500
	clients[2].set_process(false)
	var waited := Time.get_ticks_msec()
	while not game.is_paused() and Time.get_ticks_msec() - waited < 8000:
		await _stream([clients[0], clients[1]], 0.2, [flat, flat])
	_check(game.is_paused() and not game.is_over, "a silent phone pauses the match")
	var shrink_time: float = game.arena.time
	await _stream([clients[0], clients[1]], 1.0, [flat, flat])
	_check(is_equal_approx(game.arena.time, shrink_time), "the platform does not shrink while a phone is lost (REQ-SB-13)")
	app.server.peer_timeout_ms = Protocol.PEER_TIMEOUT_MS
	app.server.kick(2)
	await _frames(5)
	_check(game._bodies.size() == 2 and not game._bodies.has(2) and not game.is_over and game.participants.size() == 2,
			"a player who leaves takes the bumper out and the match goes on with two")
	app.server.kick(1)
	await _frames(5)
	_check(game.is_over and game.menu_buttons().map(func(b): return b.text).has("BACK TO MENU"),
			"with one player left the match is over at once")

	# The game needs 2 players (REQ-GM-20): with one phone Start is dimmed and says why.
	app.go_game_settings("sumo_bumpers")
	await _frames(5)
	sv = app.current_screen()
	_check(sv.start_button.disabled and sv.reason_label.text == "NEEDS 2 PLAYERS",
			"with one phone Start is disabled and the line says 'Needs 2 players': %s" % sv.reason_label.text)
	for c in clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
