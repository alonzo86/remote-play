extends SceneTree
## Smoke test of the whole TV app with two simulated phones. Run:
##   godot --headless --path . --script tests/smoke_tv.gd -- --role=tv
## It runs the TV flow, the maze and the marble race, and checks that tilt moves a ball.

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
var MazeGame
var MarbleRace
var Registry
var MarbleTrack
var TvLogo
var TvConnect
var TvGames
var TvSettings

var _fails := 0
var _seq := [0, 0]


func _initialize() -> void:
	_run()


## Texts in the tree of `n` with a font size below 28 px (REQ-FL-40). A label without an override uses 34.
func _small_text(n: Node) -> Array:
	var out := []
	if n is Label or n is Button:
		var fs: int = n.get_theme_font_size("font_size")
		var txt: String = n.text
		if txt != "" and fs < 28:
			out.append("%s:%d" % [txt.left(20), fs])
	for c in n.get_children():
		out.append_array(_small_text(c))
	return out


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _stream(c: Node, idx: int, seconds: float, accel: Vector3, gyro := Vector3.ZERO, buttons := 0) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		c.send_sensor(Protocol.encode_sensor(_seq[idx], Time.get_ticks_msec(), gyro, accel, buttons, 0, Vector2.ZERO))
		_seq[idx] += 1
		await _frames(1)


func _stream_both(c: Array[Node], seconds: float, a0: Vector3, a1: Vector3) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in 2:
			c[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO,
					a0 if i == 0 else a1, 0, 0, Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


func _run() -> void:
	await _frames(5)
	# Load now, not at parse time: the App autoload must exist first.
	MazeGame = load("res://scripts/game/maze/maze_game.gd")
	MarbleTrack = load("res://scripts/game/marble_race/marble_track.gd")
	Registry = load("res://scripts/game/registry.gd")
	MarbleRace = load("res://scripts/game/marble_race/marble_race.gd")
	TvLogo = load("res://scripts/ui/tv_logo.gd")
	TvConnect = load("res://scripts/ui/tv_connect.gd")
	TvGames = load("res://scripts/ui/tv_games.gd")
	TvSettings = load("res://scripts/ui/tv_settings.gd")
	var app: Node = root.get_node("App")
	_check(is_instance_of(app.current_screen(), TvLogo), "TV starts on the logo screen (REQ-FL-2)")
	_check(app.server.listening, "server is listening while the logo shows (REQ-FL-4)")
	_check(app.server.phase == "connect", "phase is connect on the logo screen")
	# The logo goes on by itself after about 2.5 seconds (REQ-FL-2).
	var logo_start := Time.get_ticks_msec()
	while is_instance_of(app.current_screen(), TvLogo) and Time.get_ticks_msec() - logo_start < 5000:
		await process_frame
	var logo_ms := Time.get_ticks_msec() - logo_start
	_check(is_instance_of(app.current_screen(), TvConnect) and logo_ms >= 2000 and logo_ms <= 3500,
			"the logo goes on to Connect by itself after about 2.5 s (took %d ms)" % logo_ms)
	app.go_logo()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), TvLogo), "the logo can be shown again")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	Input.parse_input_event(accept)
	await _frames(3)
	_check(is_instance_of(app.current_screen(), TvConnect), "the OK key skips the logo screen (REQ-FL-3)")
	app.go_logo()
	await _frames(3)
	app.current_screen().on_back() # Back skips the logo. It does not quit (REQ-FL-3).
	await _frames(3)
	var connect: Control = app.current_screen()
	_check(is_instance_of(connect, TvConnect), "Back skips the logo screen and goes to Connect")
	_check(connect._continue.disabled, "Continue is disabled with no phone (REQ-FL-6)")
	connect.on_back()
	await _frames(2)
	_check(connect._modal != null, "Back on Connect opens the quit confirmation (REQ-FL-10)")
	connect.on_back()
	await _frames(2)
	_check(connect._modal == null, "Back closes the quit confirmation")

	var clients: Array[Node] = []
	for i in 2:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
	var t0 := Time.get_ticks_msec()
	while app.server.connected_slots().size() < 2 and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	_check(app.server.connected_slots().size() == 2, "two simulated phones joined")
	var flat := Vector3(0, 0, 9.81)
	await _stream(clients[0], 0, 0.3, flat)
	await _stream(clients[1], 1, 0.3, flat)
	await _frames(3)
	_check(not connect._continue.disabled and connect._continue.has_focus(),
			"Continue is enabled and focused after a phone joins (REQ-FL-7)")
	_check(clients[0].phase == "connect", "the phone sees the connect phase")
	connect._continue.pressed.emit()
	await _frames(3)
	var games: Control = app.current_screen()
	_check(is_instance_of(games, TvGames) and app.server.phase == "menu", "Continue opens the Games screen")
	_check(games._tiles.size() == Registry.all().size(), "one tile for each game (REQ-FL-11)")
	# The tile_focus tile is wide and shows the description. The others keep the screenshot width (REQ-FL-12, 13).
	await create_timer(0.4).timeout
	var tile_focus: Button = null
	for t in games._tiles:
		if t.has_focus():
			tile_focus = t
	_check(tile_focus != null and is_equal_approx(tile_focus.size.x, tile_focus.wide_width()) and tile_focus._desc.modulate.a > 0.99,
			"the focused tile grows wide and shows the description (REQ-FL-12)")
	_check(tile_focus._desc.size.x <= tile_focus.INFO_W and tile_focus._desc.get_line_count() >= 2,
			"the description wraps inside the panel of the wide tile")
	var others_small := true
	for t in games._tiles:
		if t != tile_focus:
			others_small = others_small and is_equal_approx(t.size.x, t.SHOT.x) and t._desc.modulate.a < 0.01
	_check(others_small and games._tiles.size() >= 2, "the other tiles keep the screenshot width")
	var next_tile: Button = games._tiles[(games._tiles.find(tile_focus) + 1) % games._tiles.size()]
	next_tile.grab_focus()
	await create_timer(0.4).timeout
	_check(is_equal_approx(next_tile.size.x, next_tile.wide_width()) and is_equal_approx(tile_focus.size.x, tile_focus.SHOT.x),
			"the focus moves: the new tile grows and the old tile shrinks")
	tile_focus.grab_focus()
	await create_timer(0.4).timeout
	_check(_small_text(games).is_empty(), "Games screen: no text below 28 px (REQ-FL-40) " + str(_small_text(games)))
	_check(games._badge.text == "2 players", "the badge shows the number of players (REQ-FL-15)")
	var nobody: bool = true
	for t in games._tiles:
		nobody = nobody and t.fits
	_check(nobody, "all games accept 2 players (REQ-FL-14)")
	_check(not Registry.accepts({"min_players": 3, "max_players": 4}, 2), "a game for 3 or more players does not accept 2")
	# The content column keeps its width and stays centered on a wide screen (21:9).
	root.size = Vector2i(2560, 1080)
	await _frames(4)
	var col: Control = games._root
	_check(is_equal_approx(col.size.x, float(games.CONTENT_W))
			and absf(col.global_position.x + col.size.x * 0.5 - games.size.x * 0.5) < 2.0,
			"the Games column keeps its width and stays centered on a wide screen")
	root.size = Vector2i(1920, 1080)
	await _frames(4)
	games.on_back()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), TvConnect) and app.server.connected_slots().size() == 2,
			"Back on Games returns to Connect and the players stay (REQ-FL-9, 18)")
	app.go_games()
	await _frames(3)
	games = app.current_screen()
	# The Back key of the remote and F3 (REQ-T3, REQ-T4).
	var back_key := InputEventKey.new()
	back_key.keycode = KEY_BACK
	back_key.pressed = true
	app._last_back_ms = 0
	app._input(back_key)
	await _frames(3)
	_check(is_instance_of(app.current_screen(), TvConnect), "the Back key of the remote goes back one screen")
	var f3 := InputEventKey.new()
	f3.keycode = KEY_F3
	f3.pressed = true
	var overlay_before: bool = app.overlay.visible
	app._input(f3)
	_check(app.overlay.visible != overlay_before, "F3 toggles the debug overlay")
	app._input(f3)
	_check(app.overlay.visible == overlay_before, "F3 toggles it back")
	app.go_games()
	await _frames(3)
	games = app.current_screen()
	games._gear.pressed.emit()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), TvSettings), "the gear opens Settings")
	var small: Array = _small_text(app.current_screen())
	_check(small.is_empty(), "Settings screen: no text below 28 px (REQ-FL-40) " + str(small))
	app.current_screen().on_back()
	await _frames(3)
	games = app.current_screen()
	_check(is_instance_of(games, TvGames) and games._gear.has_focus(), "Back from Settings returns to the gear (REQ-FL-24)")
	games._open_players()
	await _frames(3)
	_check(games._modal != null, "the badge opens the Players modal")
	app.server.kick(1)
	await _frames(3)
	_check(games._badge.text == "1 player", "Remove updates the badge at once (REQ-FL-36)")
	_check(not app.server.players[1].is_present(), "Remove frees the slot (REQ-FL-33)")
	games.on_back()
	await _frames(2)
	_check(games._modal == null, "Back closes the Players modal")
	await _frames(40)
	_check(clients[1].state == ControllerClient.State.IDLE and not app.server.players[1].is_present(),
			"the removed phone stays out until it connects again")
	clients[1].connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
	var t2 := Time.get_ticks_msec()
	while app.server.connected_slots().size() < 2 and Time.get_ticks_msec() - t2 < 4000:
		await process_frame
	_check(app.server.connected_slots().size() == 2, "a removed player can join again")
	await _stream(clients[0], 0, 0.2, flat)
	await _stream(clients[1], 1, 0.2, flat)

	if app.overlay.visible:
		app.toggle_overlay() # The setting is saved between runs. Start from "off".
	app.toggle_overlay()
	await _frames(3)
	_check(app.overlay.visible, "debug overlay toggles on")

	# Maze: start it, wait for the countdown, then tilt phone 0 right-down.
	app.go(MazeGame)
	await _frames(3)
	var game: Control = app.current_screen()
	_check(is_instance_of(game, MazeGame) and game.participants.size() == 2, "maze starts with 2 participants")
	# A phone that joins during the round waits for the next round (REQ-FL-25).
	var late := ControllerClient.new()
	late.player_name = "Late"
	root.add_child(late)
	late.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
	var t3 := Time.get_ticks_msec()
	while app.server.connected_slots().size() < 3 and Time.get_ticks_msec() - t3 < 4000:
		await process_frame
	await _frames(5)
	_check(app.server.connected_slots().size() == 3 and game.participants.size() == 2,
			"a late phone joins but does not take part in the round")
	_check(app.server.phase_for(late.slot) == "waiting" and late.phase == "waiting",
			"the late phone gets the waiting phase")
	late.leave()
	await _frames(5)
	await _stream(clients[0], 0, 3.3, flat)
	var a := deg_to_rad(15.0)
	_check(game._balls[0].pos.distance_to(game._balls[1].pos) > 2.0 * game.BALL_R + 2.0,
			"two balls do not touch at the start (REQ-MZ-2)")
	var start_x: float = game._balls[0].pos.x
	var start_x1: float = game._balls[1].pos.x
	var tilt := Vector3(-sin(a), 0, cos(a)) * 9.81  # Right side down.
	await _stream_both(clients, 1.0, tilt, flat)
	var moved: float = game._balls[0].pos.x - start_x
	_check(moved > 15.0, "ball 0 rolls right when the phone tilts right (moved %.0f px)" % moved)
	_check(absf(game._balls[1].pos.x - start_x1) < 5.0, "ball 1 stays (flat phone)")

	# Pause on lost player: kill phone 1's socket and look at the game state.
	clients[1]._ws.close()
	await _frames(30)
	_check(game.is_paused() or game.lost_participants().size() == 1 or clients[1].state == ControllerClient.State.CONNECTED,
			"game pauses (or phone already back) when a phone drops")
	var t1 := Time.get_ticks_msec()
	while not game.lost_participants().is_empty() and Time.get_ticks_msec() - t1 < 5000:
		await process_frame
	_check(game.lost_participants().is_empty(), "game resumes after the phone reconnects")

	# Pause menu with OK, then restart.
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(3)
	_check(game.is_paused(), "OK opens the pause menu")
	game.restart()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), MazeGame) and app.current_screen() != game, "restart makes a new maze screen")

	# Maze physics, the end of a round, and the buttons (REQ-MZ-4 to 6).
	var mz: Control = app.current_screen()
	var haptics: Array = []
	clients[0].haptic_requested.connect(func(ms): haptics.append(ms))
	var b0 = mz._balls[0]
	var ball_r: float = mz.BALL_R
	var horizontal: Rect2 = mz._walls.filter(func(r): return r.size.x > r.size.y)[0]
	var vertical: Rect2 = mz._walls.filter(func(r): return r.size.y > r.size.x)[0]
	var cases := [
		["up", Vector2(horizontal.get_center().x, horizontal.position.y + 1.0), horizontal],
		["down", Vector2(horizontal.get_center().x, horizontal.end.y - 1.0), horizontal],
		["left", Vector2(vertical.position.x + 1.0, vertical.get_center().y), vertical],
		["right", Vector2(vertical.end.x - 1.0, vertical.get_center().y), vertical],
	]
	var pushed_out := true
	for c in cases:
		var wall: Rect2 = c[2]
		b0.pos = c[1]
		b0.vel = Vector2.ZERO
		mz._collide(b0)
		var nearest := Vector2(clampf(b0.pos.x, wall.position.x, wall.end.x), clampf(b0.pos.y, wall.position.y, wall.end.y))
		var side_ok: bool = (c[0] == "up" and b0.pos.y < wall.position.y) or (c[0] == "down" and b0.pos.y > wall.end.y) \
				or (c[0] == "left" and b0.pos.x < wall.position.x) or (c[0] == "right" and b0.pos.x > wall.end.x)
		if not (side_ok and b0.pos.distance_to(nearest) >= ball_r - 0.5):
			pushed_out = false
			print("    a ball in a wall was not pushed out of the ", c[0], " side")
	_check(pushed_out, "a ball that is inside a wall is pushed out the short way, on all four sides")
	# A hard hit bounces the ball back with a quarter of its speed and buzzes the phone. A soft hit does not buzz.
	b0.pos = Vector2(horizontal.get_center().x, horizontal.position.y - ball_r + 3.0)
	b0.vel = Vector2(0, 400)
	b0.haptic_cooldown = 0.0
	mz._collide(b0)
	_check(is_equal_approx(b0.vel.y, -400.0 * mz.RESTITUTION) and b0.haptic_cooldown > 0.0,
			"a hard hit bounces the ball back (%.0f px/s) and starts the buzz cool-down" % b0.vel.y)
	await _frames(10)
	_check(haptics == [20], "the phone of the ball buzzes 20 ms after a hard hit: %s" % str(haptics))
	b0.pos = Vector2(horizontal.get_center().x, horizontal.position.y - ball_r + 3.0)
	b0.vel = Vector2(0, 100)
	b0.haptic_cooldown = 0.0
	mz._collide(b0)
	_check(b0.haptic_cooldown == 0.0 and b0.vel.y < 0.0, "a soft hit bounces without a buzz")
	b0.pos = Vector2(mz.CELL * 0.5, mz.CELL * 0.5)
	b0.vel = Vector2(5000.0, 0.0)
	mz._step_ball(b0, 0.016)
	_check(b0.vel.length() <= mz.MAX_SPEED + 0.5, "the speed of a ball is limited (%.0f px/s)" % b0.vel.length())

	# The buttons: A recenters (REQ-MZ), B does nothing in the maze.
	var lean := deg_to_rad(15.0)
	var tilted := Vector3(-sin(lean), 0.0, cos(lean)) * 9.81
	var feed := func():
		for i in 90:
			app.server.players[0].on_sensor(Protocol.decode_sensor(
					Protocol.encode_sensor(i, i * 16, Vector3.ZERO, tilted, 0, 0, Vector2.ZERO)), Time.get_ticks_msec())
	feed.call()
	app.server.players[0].button_pressed.emit(Protocol.BTN_B)
	_check(app.server.players[0].tilt().length() > 0.2, "B does not recenter in the maze")
	app.server.players[0].button_pressed.emit(Protocol.BTN_A)
	_check(app.server.players[0].tilt().length() < 0.02, "A recenters during the maze")
	await _stream(clients[0], 0, 0.5, flat) # Back to a flat reference for the next games.
	app.server.players[0].recenter()

	# A ball in the exit ends the round: one winner, a result menu, a long buzz, no pause menu.
	mz._clock = 0.0
	mz._game_tick(0.01)
	_check(mz._phase == mz.Phase.PLAYING, "the countdown ends and the race starts")
	haptics.clear()
	mz._balls[0].pos = mz._exit_center()
	mz._game_tick(0.016)
	_check(mz._phase == mz.Phase.DONE and mz._winner == mz._balls[0].slot, "a ball in the exit wins")
	var labels: Array = mz.menu_buttons().map(func(b): return b.text)
	_check(labels == ["Play again", "Back to menu"] and mz.is_paused(), "the result menu opens: %s" % str(labels))
	_check(not mz._can_open_menu(), "the pause menu cannot open over the result menu")
	mz._balls[1].pos = mz._exit_center()
	mz._game_tick(0.016)
	_check(mz._winner == mz._balls[0].slot, "a second ball in the exit does not change the winner")
	await _frames(10)
	_check(haptics.has(400), "the phone of the winner buzzes 400 ms: %s" % str(haptics))
	mz.menu_buttons()[0].pressed.emit()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), MazeGame) and app.current_screen() != mz and app.current_screen()._phase == 0,
			"Play again starts a new maze with a countdown")

	# A player who leaves takes the ball out of the game (REQ-GM-21).
	var third := ControllerClient.new()
	third.player_name = "Third"
	root.add_child(third)
	third.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
	var t4 := Time.get_ticks_msec()
	while app.server.connected_slots().size() < 3 and Time.get_ticks_msec() - t4 < 4000:
		await process_frame
	app.go(MazeGame)
	await _frames(3)
	var mz3: Control = app.current_screen()
	_check(mz3.participants.size() == 3 and mz3._balls.size() == 3, "a maze with 3 phones has 3 balls")
	app.server.drop_player(third.slot)
	await _frames(3)
	_check(mz3.participants.size() == 2 and mz3._balls.size() == 2 and not mz3.is_paused(),
			"a player who leaves takes the ball out and the game goes on")
	third.leave()
	await _frames(3)

	# Marble race menu: one entry, then a track list, then the race.
	app.go_menu()
	await _frames(3)
	var menu: Control = app.current_screen()
	menu._on_tile(Registry.find("marble_race"))
	await _frames(2)
	var variant_buttons := 0
	for ch in menu._variant_view.get_children():
		if ch is Button:
			variant_buttons += 1
	_check(is_instance_of(app.current_screen(), TvGames) and menu._variants_of == "marble_race"
			and variant_buttons == MarbleTrack.IDS.size() + 1, "Marble Race opens the track list before the race (REQ-FL-17)")
	menu.on_back()
	await _frames(3)
	var focused = menu.get_viewport().gui_get_focus_owner()
	_check(menu._variants_of == "" and focused != null and "game" in focused and focused.game.id == "marble_race",
			"Back from the track list returns to the grid with the same tile in focus")
	menu._on_tile(Registry.find("marble_race"))
	await _frames(2)
	menu._launch("marble_race", {})   # A variant with empty props must start the game, not reopen the list.
	await _frames(3)
	_check(is_instance_of(app.current_screen(), MarbleRace), "a variant with empty props starts the game")
	# Leaving a game in progress asks first (REQ-GM-31a).
	var lg: Control = app.current_screen()
	lg.on_back()
	await _frames(2)
	var leave_labels: Array = []
	for b in lg.menu_buttons():
		leave_labels.append(b.text)
	_check(app.current_screen() == lg and lg.is_paused() and leave_labels == ["Keep playing", "\u2715  End game"],
			"Back in a game in progress asks 'End the game?' and pauses: %s" % str(leave_labels))
	_check(lg.menu_buttons()[1].theme_type_variation == "DangerButton", "End game is the red destructive button")
	lg.on_back()
	await _frames(2)
	_check(app.current_screen() == lg and not lg.is_paused() and lg.menu_buttons().is_empty(), "Back on the question keeps playing")
	var ok_event := InputEventAction.new()
	ok_event.action = "ui_accept"
	ok_event.pressed = true
	lg._unhandled_input(ok_event) # OK opens the pause menu. Its "Back to menu" asks the same question.
	await _frames(2)
	lg.menu_buttons()[2].pressed.emit()
	await _frames(2)
	_check(app.current_screen() == lg and lg.menu_buttons().size() == 2 and lg.menu_buttons()[0].text == "Keep playing",
			"Back to menu in the pause menu asks 'End the game?'")
	lg.menu_buttons()[1].pressed.emit()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), TvGames), "End game leaves for the Games screen")
	app.go(MazeGame)
	await _frames(3)
	var over: Control = app.current_screen()
	over._phase = over.Phase.DONE
	over.request_leave()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), TvGames), "a game that is over leaves at once, without the question")
	app.go_menu()
	await _frames(3)
	menu = app.current_screen()

	# Marble race: grid wait, tilt moves a marble, finish line ends the race.
	root.size = Vector2i(1920, 1080)   # The headless window can have another shape. The TV is 16:9.
	await _frames(3)
	app.go(MarbleRace, Registry.find("marble_race").variants[2].props)
	await _frames(3)
	var mr: Control = app.current_screen()
	_check(is_instance_of(mr, MarbleRace) and mr.participants.size() == 2, "marble race starts with 2 participants")
	_check(mr.track.id == "zigzag", "registry props choose the track")
	_check(mr.camera != null, "the 3D game has a camera")
	mr.open_menu("Paused", [["Resume", mr.close_menu]])
	await _frames(2)
	_check(mr.world.process_mode == Node.PROCESS_MODE_DISABLED, "the 3D world freezes while paused")
	mr.close_menu()
	await _frames(2)
	var post_color: Color = MarbleRace.get_script_constant_map()["POST_COLOR"]
	var clash := false
	for c in Protocol.PLAYER_COLORS:
		if c.is_equal_approx(post_color):
			clash = true
	_check(not clash and not post_color.is_equal_approx(Color("e63946")), "post color is not a player color (REQ-MR-43)")
	_check(is_equal_approx(mr._racers[0].arc, mr._racers[1].arc) and absf(mr._racers[0].pos.distance_to(mr._racers[1].pos)) >= 1.0,
			"marbles start on one line and do not touch (REQ-MR-4)")
	var mx0: float = mr._racers[0].pos.x
	await _stream(clients[0], 0, 1.0, tilt)
	_check(absf(mr._racers[0].pos.x - mx0) < 0.01, "marbles wait on the grid during the countdown")
	await _stream(clients[0], 0, 2.6, tilt)
	_check(mr._racers[0].pos.x > mx0 + 0.3, "marble 0 rolls right when the phone tilts right")
	_check(mr.standings().size() == 2, "standings list both players")
	clients[0].send_recenter()
	await _stream(clients[0], 0, 0.5, tilt)
	_check(mr.player(0).tilt().length() < 0.05, "the Recenter button zeroes the tilt in the race (REQ-GM-37)")

	# Camera: all marbles in view at a small spread. Beyond the camera limit (about 55 m), edge markers point to them (REQ-MR-42).
	mr._racers[0].pos = mr.track.point_at(60.0)
	mr._racers[1].pos = mr.track.point_at(30.0)
	await _stream(clients[0], 0, 1.5, flat)
	_check(mr.edge_markers().is_empty(), "no edge marker when the marbles are close")
	mr._racers[0].pos = mr.track.point_at(150.0)
	mr._racers[1].pos = mr.track.point_at(10.0)
	await _stream(clients[0], 0, 1.5, flat)
	var markers: Array = mr.edge_markers()
	_check(not markers.is_empty() and markers[0].slot == 1, "an edge marker points to the marble that is out of view")
	for s in [0, 1]:
		mr._racers[s].pos = mr.track.point_at(mr.finish_arc + 0.5)
	await _frames(5)
	_check(mr._racers[0].finish_time >= 0.0 and mr._racers[1].finish_time >= 0.0, "marbles past the line finish")
	_check(mr._ended and mr.is_paused(), "race ends and the results menu opens")
	var results_items: int = mr.menu_buttons().size()
	mr._open_picker()
	await _frames(2)
	_check(mr._picking and mr.menu_buttons().size() == MarbleTrack.IDS.size() + 1,
			"track picker lists every track and Cancel")
	mr.on_back()
	await _frames(2)
	_check(not mr._picking and mr._ended and mr.menu_buttons().size() == results_items,
			"Back from the picker returns to the results")
	mr._open_picker()
	mr._switch_track("sprint")
	await _frames(3)
	var sp: Control = app.current_screen()
	_check(sp != mr and sp.track.id == "sprint" and sp.start_props.track_id == "sprint",
			"picking a track starts that track")
	sp.restart()
	await _frames(3)
	_check(app.current_screen().track.id == "sprint", "restart keeps the chosen track")

	# A player leaves during the race, then the last player leaves (REQ-GM-21, REQ-GM-22).
	var lr: Control = app.current_screen()
	app.server.drop_player(1)
	await _frames(3)
	_check(lr.participants == [0] and lr._racers.size() == 1 and not lr._ended, "the race goes on when one player leaves")
	app.server.drop_player(0)
	await _frames(3)
	_check(lr._ended and lr.is_paused() and lr._menu_box != null, "a menu opens when all players leave")

	# The only player is lost: no pause message and no waiting for the hold, the game ends at once (REQ-GM-30a).
	var solo := ControllerClient.new()   # No name: the TV shows "Player N".
	root.add_child(solo)
	solo.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
	var t5 := Time.get_ticks_msec()
	while app.server.connected_slots().size() < 1 and Time.get_ticks_msec() - t5 < 4000:
		await process_frame
	_check(app.server.players[solo.slot].player_name == "Player %d" % (solo.slot + 1), "a phone without a name is Player N")
	app.go(MazeGame)
	await _frames(3)
	var solo_game: Control = app.current_screen()
	_check(solo_game.participants == [solo.slot], "the maze has the single player")
	# The only player is lost: the game ends at once, with a menu and without the pause message (REQ-GM-30a).
	solo._ws.close()
	t5 = Time.get_ticks_msec()
	while not solo_game.participants.is_empty() and Time.get_ticks_msec() - t5 < 3000:
		await process_frame
	_check(solo_game.participants.is_empty() and not solo_game._paused_lost and solo_game._menu_box != null,
			"the last player is lost: the game ends at once with a menu, without the pause message")
	solo.leave()
	await _frames(3)

	# The same in the marble race, which has its own branch for "no players" (REQ-MR-14).
	var solo2 := ControllerClient.new()
	root.add_child(solo2)
	solo2.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
	t5 = Time.get_ticks_msec()
	while app.server.connected_slots().size() < 1 and Time.get_ticks_msec() - t5 < 4000:
		await process_frame
	app.go(MarbleRace, Registry.find("marble_race").variants[0].props)
	await _frames(3)
	var solo_race: Control = app.current_screen()
	solo2._ws.close()
	t5 = Time.get_ticks_msec()
	while not solo_race.participants.is_empty() and Time.get_ticks_msec() - t5 < 3000:
		await process_frame
	_check(solo_race._ended and not solo_race._paused_lost and solo_race._menu_box != null,
			"marble race: the last player is lost, the race ends at once with a menu")
	solo2.leave()

	app.go_menu()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), TvGames), "back to the Games screen")
	print("smoke test done, %d failed" % _fails)
	for c in clients:
		c.leave()
	await _frames(30)
	quit(1 if _fails > 0 else 0)
