extends SceneTree
## Smoke test of the whole TV app with two simulated phones. Run:
##   godot --headless --path . --script tests/smoke_tv.gd -- --role=tv
## It runs the TV flow, the maze and the marble race, and checks that tilt moves a ball.

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
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
	_check(connect._hint.text != "Press OK to continue" and not connect.can_continue(),
			"no phone: no 'Press OK' line, and OK does nothing (REQ-FL-6, 7)")
	var ok_key := InputEventAction.new()
	ok_key.action = "ui_accept"
	ok_key.pressed = true
	connect._unhandled_input(ok_key)
	await _frames(2)
	_check(app.current_screen() == connect, "OK with no phone stays on the Connect screen")
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
	_check(connect._hint.text == "Press OK to continue" and connect.can_continue(),
			"after a phone joins the screen says 'Press OK to continue' (REQ-FL-6)")
	_check(connect.find_children("*", "Button", true, false).is_empty(), "the Connect screen has no button (REQ-FL-6)")
	_check(not ("players connected" in connect._hint.text), "the screen does not count the players")
	_check(clients[0].phase == "connect", "the phone sees the connect phase")
	connect.on_back()   # The quit question is open: OK is for its buttons, not for Continue.
	await _frames(2)
	_check(not connect.can_continue(), "with the quit question open, OK does not continue")
	connect.on_back()
	await _frames(2)
	connect._unhandled_input(ok_key)
	await _frames(3)
	var games: Control = app.current_screen()
	_check(is_instance_of(games, TvGames) and app.server.phase == "menu", "OK opens the Games screen (REQ-FL-7)")
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

	# A phone goes silent (like a phone that lost its Wi-Fi: its connection stays open but nothing arrives).
	# The game pauses with a card. It goes on only when the TV user chooses (REQ-GM-30, 30a).
	app.server.peer_timeout_ms = 2500   # More than two heartbeats (1 s) of the phone.
	clients[1].set_process(false)
	var t1 := Time.get_ticks_msec()
	while not game._hold and Time.get_ticks_msec() - t1 < 8000:
		await process_frame
	await _frames(3)
	_check(game._hold and game.is_paused() and game.lost_participants() == [1],
			"a silent phone makes the TV pause the game, also when its connection does not close")
	var card_title: String = game._menu_box.find_children("*", "Label", true, false)[0].text
	var card_buttons: Array = game.menu_buttons().map(func(b): return b.text)
	_check(card_title == "P2 lost connection" and card_buttons == ["Resume without P2", "\u2715  End game"],
			"the card names the phone and offers Resume without it while a phone is connected: %s %s" % [card_title, str(card_buttons)])
	_check(app.server.phase == "paused" and clients[0].phase == "paused", "the phones are told that the game is paused")
	clients[1].set_process(true)   # The phone is back (the call is over).
	t1 = Time.get_ticks_msec()
	while not game.lost_participants().is_empty() and Time.get_ticks_msec() - t1 < 6000:
		await process_frame
	await _frames(5)
	card_title = game._menu_box.find_children("*", "Label", true, false)[0].text
	card_buttons = game.menu_buttons().map(func(b): return b.text)
	_check(game.is_paused() and card_title == "P2 reconnected" and card_buttons == ["Resume", "\u2715  End game"],
			"when the phone is back the game stays paused and the card offers Resume: %s %s" % [card_title, str(card_buttons)])
	game.menu_buttons()[0].pressed.emit()
	await _frames(3)
	_check(not game.is_paused() and not game._hold and app.server.phase == "playing" and game.participants == [0, 1],
			"Resume goes on with both players, and the phones are told")
	app.server.peer_timeout_ms = Protocol.PEER_TIMEOUT_MS
	# Back on the card asks to end the game, and Keep playing brings the card back.
	clients[1].set_process(false)
	app.server.peer_timeout_ms = 2500   # More than two heartbeats (1 s) of the phone.
	t1 = Time.get_ticks_msec()
	while not game._hold and Time.get_ticks_msec() - t1 < 8000:
		await process_frame
	await _frames(3)
	game.on_back()
	await _frames(3)
	var ask: Array = game.menu_buttons().map(func(b): return b.text)
	_check(ask == ["Keep playing", "\u2715  End game"], "Back on the card asks 'End the game?' (REQ-GM-31a): %s" % str(ask))
	game.menu_buttons()[0].pressed.emit()
	await _frames(4)
	_check(game._hold and game.is_paused() and game._menu_kind == "hold", "Keep playing brings the card of the lost phone back")
	# Resume without the lost phone: its slot is freed and the game goes on with the other player.
	game.menu_buttons()[0].pressed.emit()
	await _frames(4)
	_check(not game.is_paused() and game.participants == [0] and app.server.players[1].state == PlayerInput.State.EMPTY,
			"Resume without P2 goes on with one player and frees the slot of P2")
	clients[1].set_process(true)
	app.server.peer_timeout_ms = Protocol.PEER_TIMEOUT_MS
	t1 = Time.get_ticks_msec()
	while app.server.connected_slots().size() < 2 and Time.get_ticks_msec() - t1 < 6000:
		await process_frame
	await _frames(3)

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
	mz._collide(b0)
	_check(is_equal_approx(b0.vel.y, -400.0 * mz.RESTITUTION), "a hard hit bounces the ball back (%.0f px/s)" % b0.vel.y)
	b0.pos = Vector2(horizontal.get_center().x, horizontal.position.y - ball_r + 3.0)
	b0.vel = Vector2(0, 400)
	mz._collide(b0)   # A second hard hit right after the first: inside the cool-down.
	await _frames(10)
	_check(haptics == [20], "a hard hit buzzes 20 ms, and a second one inside the cool-down does not: %s" % str(haptics))
	b0.pos = Vector2(horizontal.get_center().x, horizontal.position.y - ball_r + 3.0)
	b0.vel = Vector2(0, 100)
	mz._haptics = mz.Haptics.new()   # The cool-down is over.
	mz._collide(b0)
	await _frames(10)
	_check(haptics == [20] and b0.vel.y < 0.0, "a soft hit bounces without a buzz: %s" % str(haptics))
	b0.pos = Vector2(mz.CELL * 0.5, mz.CELL * 0.5)
	b0.vel = Vector2(5000.0, 0.0)
	mz._step_ball(b0, 0.016)
	_check(b0.vel.length() <= mz.MAX_SPEED + 0.5, "the speed of a ball is limited (%.0f px/s)" % b0.vel.length())

	# The RECENTER button recenters. A and B do not (REQ-MZ-8, REQ-GM-37).
	var lean := deg_to_rad(15.0)
	var tilted := Vector3(-sin(lean), 0.0, cos(lean)) * 9.81
	var feed := func():
		for i in 90:
			app.server.players[0].on_sensor(Protocol.decode_sensor(
					Protocol.encode_sensor(i, i * 16, Vector3.ZERO, tilted, 0, 0, Vector2.ZERO)), Time.get_ticks_msec())
	feed.call()
	app.server.players[0].button_pressed.emit(Protocol.BTN_B)
	app.server.players[0].button_pressed.emit(Protocol.BTN_A)
	_check(app.server.players[0].tilt().length() > 0.2, "A and B do not recenter in the maze")
	clients[0].send_recenter()
	await _frames(10)
	_check(app.server.players[0].tilt().length() < 0.02, "the RECENTER button recenters during the maze")
	await _stream(clients[0], 0, 0.5, flat) # Back to a flat reference for the next games.
	app.server.players[0].recenter()

	# A ball in the exit ends the round: one winner, a result menu, a long buzz, no pause menu.
	mz._round.time = -0.005
	mz._game_tick(0.01)
	_check(mz._round.is_playing() and not mz.is_over, "the countdown ends and the race starts")
	haptics.clear()
	mz._balls[0].pos = mz._exit_center()
	mz._game_tick(0.016)
	_check(mz.is_over and mz._winner == mz._balls[0].slot, "a ball in the exit wins")
	var labels: Array = mz.menu_buttons().map(func(b): return b.text)
	_check(labels == ["Restart", "Back to menu"] and mz.is_paused(), "the result menu opens: %s" % str(labels))
	var maze_rows: Array = []
	for l in mz._menu_box.find_children("*", "Label", true, false):
		maze_rows.append(l.text)
	_check(maze_rows.size() == 3 and maze_rows[0].ends_with("wins!") and maze_rows[1].begins_with("1st")
			and maze_rows[1].ends_with(" s") and maze_rows[2].begins_with("2nd") and maze_rows[2].ends_with("not finished"),
			"the maze result lists the winner with the time and the other ball as not finished: %s" % str(maze_rows))
	_check(not mz._can_open_menu(), "the pause menu cannot open over the result menu")
	mz._balls[1].pos = mz._exit_center()
	mz._game_tick(0.016)
	_check(mz._winner == mz._balls[0].slot, "a second ball in the exit does not change the winner")
	await _frames(10)
	_check(haptics.has(400), "the phone of the winner buzzes 400 ms: %s" % str(haptics))
	mz.menu_buttons()[0].pressed.emit()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), MazeGame) and app.current_screen() != mz
			and app.current_screen()._round.is_counting(), "Restart starts a new maze with a countdown")

	# The result menu of a round with scores (REQ-GM-34, 72, 73) on the race screen, with its two players gone.
	# (The fresh maze of "Restart" has both phones.)
	var Scoreboard = load("res://scripts/game/scoreboard.gd")
	var rg: Control = app.current_screen()
	var board = Scoreboard.new(rg.participants)
	board.set_score(rg.participants[0], 3)
	board.set_score(rg.participants[1], 9)
	rg.open_results(board)
	await _frames(2)
	var row_labels: Array = []
	for l in rg._menu_box.find_children("*", "Label", true, false):
		row_labels.append(l.text)
	var result_buttons: Array = rg.menu_buttons().map(func(b): return b.text)
	_check(rg.is_over and result_buttons == ["Restart", "Back to menu"] and not rg._can_open_menu(),
			"the result menu has Restart and Back to menu, and the game is over: %s" % str(result_buttons))
	_check(row_labels.size() == 3 and row_labels[1].begins_with("1st") and row_labels[1].ends_with("9")
			and row_labels[2].begins_with("2nd") and row_labels[0].ends_with("wins!"),
			"the ranking lists the best first and the title names the winner: %s" % str(row_labels))
	var dots: Array = rg._menu_box.find_children("*", "Panel", true, false)
	var dot_colors: Array = dots.map(func(d): return d.get_theme_stylebox("panel").bg_color)
	_check(dot_colors == [rg.player(rg.participants[1]).color, rg.player(rg.participants[0]).color],
			"each row has a dot in the slot color of its player, best first")
	board.set_score(rg.participants[0], 9)
	rg.open_results(board)
	await _frames(2)
	_check(rg._menu_box.find_children("*", "Label", true, false)[0].text == "Tie!", "equal scores give the title Tie!")
	var one = Scoreboard.new([rg.participants[0]])
	one.set_score(rg.participants[0], 25)
	rg.open_results(one, [10, 20, 30])
	await _frames(2)
	_check(rg._menu_box.find_children("*", "Label", true, false)[0].text == "Silver medal!",
			"one player and tiers: the title is the medal")
	# A time that must be small: 25 s earns silver, and a player who did not finish earns nothing (REQ-GM-73).
	var fast_tiers := [40.0, 30.0, 20.0]
	var timed = Scoreboard.new([], true)
	timed.set_score(rg.participants[0], 25.0)
	rg.open_results(timed, fast_tiers)
	await _frames(2)
	_check(rg._menu_box.find_children("*", "Label", true, false)[0].text == "Silver medal!", "a time of 25 s earns silver")
	var lost = Scoreboard.new([], true)
	lost.set_unfinished(rg.participants[0], 3.0)
	rg.open_results(lost, fast_tiers)
	await _frames(2)
	_check(rg._menu_box.find_children("*", "Label", true, false)[0].text == "No medal this time",
			"a solo player who did not finish gets no medal, although the score 0 is below every limit")

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

	# Target Shoot (REQ-TS-1 to 16): aim, shots, points, the end. Each step sets up its own state, because the real game also
	# ticks in the frames that are awaited. A step without an await is one tick of the game.
	var ts_script: GDScript = Registry.load_script("target_shoot")
	app.go(ts_script, {"seed": 7})
	await _frames(3)
	var ts: Control = app.current_screen()
	var p0 = app.server.players[0]
	var p1 = app.server.players[1]
	var area: Rect2 = ts._area()
	_check(is_instance_of(ts, ts_script) and ts.participants.size() == 2 and ts._shooters.size() == 2,
			"target shoot starts with 2 players")
	_check(ts._round.is_counting() and ts._field.targets.is_empty(), "the round starts with the countdown and no target (REQ-TS-1)")
	p0.button_pressed.emit(Protocol.BTN_A)
	_check(ts._presses.is_empty(), "a shot in the countdown does nothing (REQ-TS-1)")
	var aim_x: float = ts._shooters[0].aim.x
	p0.orientation.yaw += deg_to_rad(-12.5)   # Half of the 25 degree range, to the right.
	await _frames(3)
	_check(absf(ts._shooters[0].aim.x - aim_x - area.size.x * 0.25) < 1.0,
			"the cursor follows the pointer during the countdown: 12.5 degrees is a quarter of the width (REQ-TS-3)")
	haptics.clear()
	ts._round.time = -0.005
	ts._game_tick(0.01)   # The countdown ends: every phone recenters and buzzes.
	ts._game_tick(0.01)
	_check(ts._round.is_playing() and ts._shooters[0].aim.distance_to(area.get_center()) < 1.0,
			"at GO the pose of the phone is the center of the screen (REQ-TS-2)")
	_check(ts._field.targets.size() == 1, "the first target appears at once (REQ-TS-8)")
	var first_uv: Vector2 = ts._field.targets[0].uv
	await _frames(8)
	_check(haptics.has(60), "GO buzzes the phone 60 ms: %s" % str(haptics))

	var put := func(kind: String, uv: Vector2) -> void:
		ts._field.targets.clear()
		var t = ts.TargetField.Target.new()
		t.kind = kind
		t.uv = uv
		t.radius = ts.TargetField.KINDS[kind].radius
		t.points = ts.TargetField.KINDS[kind].points
		t.life_left = 99.0
		ts._field.targets.append(t)
	var ready_all := func() -> void:
		for sh in ts._shooters.values():
			sh.reload_left = 0.0
			sh.lock_left = 0.0
		ts._haptics = ts.Haptics.new()
	var center := Vector2(0.5, 0.5)
	ts._board.set_score(0, 0.0)
	ts._board.set_score(1, 0.0)
	haptics.clear()
	ready_all.call()
	put.call("standard", center)
	p0.button_pressed.emit(Protocol.BTN_A)
	ts._game_tick(0.01)
	_check(ts._board.score(0) == 10.0 and ts._field.targets.is_empty(),
			"a shot at a standard target takes it and gives 10 points (REQ-TS-10)")
	await _frames(8)
	_check(haptics == [30], "a hit buzzes the shooter 30 ms: %s" % str(haptics))

	# Reload, miss and lock (REQ-TS-5, 6).
	ready_all.call()
	put.call("standard", center)
	p0.button_pressed.emit(Protocol.BTN_A)
	ts._game_tick(0.01)
	put.call("standard", center)
	p0.button_pressed.emit(Protocol.BTN_A)
	ts._game_tick(0.01)
	_check(ts._board.score(0) == 20.0 and ts._field.targets.size() == 1, "a press inside the 0.25 s reload does nothing (REQ-TS-5)")
	p0.button_pressed.emit(Protocol.BTN_A)
	ts._game_tick(0.3)
	_check(ts._board.score(0) == 30.0, "after the reload the next shot works")
	ts._game_tick(0.3)
	haptics.clear()
	ready_all.call()
	put.call("standard", Vector2(0.1, 0.1))
	p0.button_pressed.emit(Protocol.BTN_A)
	ts._game_tick(0.01)
	var sh0: Object = ts._shooters[0]
	_check(ts._board.score(0) == 30.0 and is_equal_approx(sh0.lock_left, ts.MISS_LOCK) and not sh0.can_fire(),
			"a miss gives no points and locks the fire for 0.6 s (REQ-TS-6)")
	put.call("standard", center)
	p0.button_pressed.emit(Protocol.BTN_A)
	ts._game_tick(0.3)
	_check(ts._board.score(0) == 30.0 and ts._field.targets.size() == 1, "a press in the lock does nothing")
	ts._game_tick(0.31)
	p0.button_pressed.emit(Protocol.BTN_A)
	ts._game_tick(0.01)
	_check(ts._board.score(0) == 40.0, "after the lock the next shot works")
	await _frames(8)
	_check(haptics.has(15), "a miss buzzes the shooter 15 ms: %s" % str(haptics))

	# Two players, one target: the first press wins (REQ-TS-11).
	ready_all.call()
	put.call("small", center)
	p1.button_pressed.emit(Protocol.BTN_A)
	p0.button_pressed.emit(Protocol.BTN_A)
	ts._game_tick(0.01)
	_check(ts._board.score(1) == 25.0 and ts._board.score(0) == 40.0 and ts._shooters[0].lock_left > 0.5,
			"two shots at one target: the first press gets 25 points, the second is a miss (REQ-TS-11)")

	# A decoy takes 15 points, and a score never goes below 0 (REQ-TS-7, 10).
	await _frames(8)   # The buzz of the shot before arrives first.
	ready_all.call()
	ts._board.set_score(0, 10.0)
	haptics.clear()
	put.call("decoy", center)
	p0.button_pressed.emit(Protocol.BTN_A)
	ts._game_tick(0.01)
	_check(ts._board.score(0) == 0.0, "a decoy takes 15 points but the score stops at 0 (REQ-TS-10)")
	await _frames(8)
	_check(haptics == [60], "a decoy buzzes the shooter 60 ms: %s" % str(haptics))

	# B does nothing. Nothing is shot while the game is paused (REQ-TS-4).
	ready_all.call()
	p0.button_pressed.emit(Protocol.BTN_B)
	_check(ts._presses.is_empty(), "B does nothing")
	ts.open_menu("Paused", [["Resume", ts.close_menu]])
	p0.button_pressed.emit(Protocol.BTN_A)
	_check(ts._presses.is_empty(), "a press in the pause menu does nothing")
	ts.close_menu()

	# The end of the round: ranking, winner, long buzz (REQ-TS-1, 15).
	ts._board.set_score(0, 30.0)
	ts._board.set_score(1, 10.0)
	haptics.clear()
	ts._round.time = ts.ROUND_TIME - 0.005
	ts._game_tick(0.01)
	await _frames(8)
	var ts_rows: Array = []
	for l in ts._menu_box.find_children("*", "Label", true, false):
		ts_rows.append(l.text)
	var ts_buttons: Array = ts.menu_buttons().map(func(b): return b.text)
	_check(ts.is_over and ts_buttons == ["Restart", "Back to menu"] and ts_rows.size() == 3
			and ts_rows[0] == p0.player_name + " wins!" and ts_rows[1].begins_with("1st") and ts_rows[1].ends_with("30")
			and ts_rows[2].begins_with("2nd") and ts_rows[2].ends_with("10"),
			"time up opens the ranking with the winner: %s" % str(ts_rows))
	_check(haptics == [400], "the winner buzzes 400 ms: %s" % str(haptics))
	ts.restart()
	await _frames(3)
	var ts2: Control = app.current_screen()
	_check(ts2 != ts and ts2.start_props.get("seed") == 7 and ts2._round.is_counting(),
			"Restart starts a new round with the same seed (REQ-GM-32)")
	ts2._round.time = -0.005
	ts2._game_tick(0.01)
	ts2._game_tick(0.01)
	_check(ts2._field.targets.size() == 1 and ts2._field.targets[0].uv == first_uv,
			"the same seed gives the same first target (REQ-TS-9)")
	# One player: the score is compared with the medal tiers (REQ-TS-15).
	ts2._board.remove(1)
	ts2._board.set_score(0, 400.0)
	ts2._round.time = ts2.ROUND_TIME - 0.005
	ts2._game_tick(0.01)
	await _frames(3)
	_check(ts2._menu_box.find_children("*", "Label", true, false)[0].text == "Silver medal!",
			"400 points alone earn silver (REQ-TS-15)")

	# A player who leaves takes the cursor and the score out (REQ-TS-16).
	var fourth := ControllerClient.new()
	fourth.player_name = "Fourth"
	root.add_child(fourth)
	fourth.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
	var t6 := Time.get_ticks_msec()
	while app.server.connected_slots().size() < 3 and Time.get_ticks_msec() - t6 < 4000:
		await process_frame
	app.go(ts_script)
	await _frames(3)
	var ts3: Control = app.current_screen()
	_check(ts3.participants.size() == 3 and ts3._shooters.size() == 3 and ts3._board.size() == 3, "target shoot with 3 phones")
	app.server.drop_player(fourth.slot)
	await _frames(3)
	_check(ts3.participants.size() == 2 and ts3._shooters.size() == 2 and ts3._board.size() == 2 and not ts3.is_paused(),
			"a player who leaves takes the cursor and the score out and the round goes on (REQ-TS-16)")
	fourth.leave()
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
	_check(lg._in_progress() == lg._can_open_menu() and lg._in_progress(), "a race in progress is in progress (REQ-GM-31a)")
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
	over.is_over = true
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
	_check(mr.is_over and mr.is_paused(), "race ends and the results menu opens")
	var results_items: int = mr.menu_buttons().size()
	_check(mr._menu_box.find_children("*", "Label", true, false)[0].text == "Tie!", "two marbles with the same time are a tie")
	mr._racers[1].finish_time = mr._racers[0].finish_time + 1.0
	mr._open_results()
	await _frames(2)
	var race_labels: Array = mr.menu_buttons().map(func(b): return b.text)
	var race_rows: Array = []
	for l in mr._menu_box.find_children("*", "Label", true, false):
		race_rows.append(l.text)
	_check(race_labels == ["Restart", "Choose track", "Back to menu"] and race_rows.size() == 3 and race_rows[0].ends_with("wins!")
			and race_rows[1].begins_with("1st") and race_rows[2].begins_with("2nd") and race_rows[2].ends_with(" s"),
			"the race results list both marbles with their times, and keep Choose track: %s %s" % [str(race_labels), str(race_rows)])
	mr._racers[1].finish_time = -1.0   # The second marble did not reach the line.
	mr._open_results()
	await _frames(2)
	var late_rows: Array = []
	for l in mr._menu_box.find_children("*", "Label", true, false):
		late_rows.append(l.text)
	_check(late_rows.size() == 3 and late_rows[2].begins_with("2nd") and late_rows[2].ends_with("not finished"),
			"a marble that did not finish is listed as not finished, after the finishers: %s" % str(late_rows))
	mr._racers[1].finish_time = mr._racers[0].finish_time + 1.0
	mr._open_results()
	await _frames(2)
	var kept_players: Array[int] = mr.participants.duplicate()
	mr.participants.clear()   # Everyone left after the finish. Choose track and Cancel must not show an empty list.
	mr._open_results()
	await _frames(2)
	var left_buttons: Array = mr.menu_buttons().map(func(b): return b.text)
	var left_title: String = mr._menu_box.find_children("*", "Label", true, false)[0].text
	_check(left_buttons == ["Back to menu"] and left_title == "No players connected",
			"results with nobody left say 'No players connected' and only offer Back to menu: %s" % str(left_buttons))
	mr.participants.append_array(kept_players)
	mr._open_results()
	await _frames(2)
	mr._open_picker()
	await _frames(2)
	_check(mr._picking and mr.menu_buttons().size() == MarbleTrack.IDS.size() + 1,
			"track picker lists every track and Cancel")
	mr.on_back()
	await _frames(2)
	_check(not mr._picking and mr.is_over and mr.menu_buttons().size() == results_items,
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
	_check(lr.participants == [0] and lr._racers.size() == 1 and not lr.is_over, "the race goes on when one player leaves")
	app.server.drop_player(0)
	await _frames(3)
	_check(lr.is_over and lr.is_paused() and lr._menu_box != null, "a menu opens when all players leave")
	var empty_menu: Control = lr._menu_box
	lr.end_no_players()
	_check(lr._menu_box == empty_menu and not lr._can_open_menu() and lr.menu_buttons().size() == 1
			and lr.menu_buttons()[0].text == "Back to menu", "the end with no players happens once, and the pause menu cannot open")

	# The only player is lost: no pause message and no waiting for the hold, the game ends at once (REQ-GM-30a).
	var solo := ControllerClient.new()   # No name: the TV shows "Player N".
	root.add_child(solo)
	solo.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
	var t5 := Time.get_ticks_msec()
	while solo.state != ControllerClient.State.CONNECTED and Time.get_ticks_msec() - t5 < 4000:
		await process_frame # Wait for the welcome: only then `solo.slot` is the slot of this phone.
	_check(app.server.players[solo.slot].player_name == "Player %d" % (solo.slot + 1), "a phone without a name is Player N")
	app.go(MazeGame)
	await _frames(3)
	var solo_game: Control = app.current_screen()
	_check(solo_game.participants == [solo.slot], "the maze has the single player")
	# The only player is lost (a phone call): the game pauses and waits. There is nobody to resume with, so the card has no
	# Resume (REQ-GM-30a). When the phone is back, the card offers Resume.
	app.server.peer_timeout_ms = 2500   # More than two heartbeats (1 s) of the phone.
	solo.set_process(false)
	t5 = Time.get_ticks_msec()
	while not solo_game._hold and Time.get_ticks_msec() - t5 < 8000:
		await process_frame
	await _frames(3)
	var solo_buttons: Array = solo_game.menu_buttons().map(func(b): return b.text)
	_check(solo_game._hold and solo_game.is_paused() and not solo_game.is_over and solo_game.participants == [solo.slot],
			"the only player is lost: the game waits, it does not end")
	_check(solo_buttons == ["\u2715  End game"], "with nobody connected the card has no Resume: %s" % str(solo_buttons))
	solo.set_process(true)
	t5 = Time.get_ticks_msec()
	while not solo_game.lost_participants().is_empty() and Time.get_ticks_msec() - t5 < 6000:
		await process_frame
	await _frames(5)
	solo_buttons = solo_game.menu_buttons().map(func(b): return b.text)
	_check(solo_buttons == ["Resume", "\u2715  End game"] and solo_game.is_paused(),
			"the phone is back (the call is over): the card offers Resume and the game still waits: %s" % str(solo_buttons))
	solo_game.menu_buttons()[0].pressed.emit()
	await _frames(3)
	_check(not solo_game.is_paused() and solo_game.participants == [solo.slot], "Resume goes on with the returned player")
	# A phone that does not come back: the slot is kept while the game is paused, then it is freed and the game ends.
	app.server.paused_slot_grace_ms = 1200
	solo.set_process(false)
	t5 = Time.get_ticks_msec()
	while not solo_game._hold and Time.get_ticks_msec() - t5 < 8000:
		await process_frame
	await _frames(5)
	_check(solo_game._hold and not solo_game.is_over and app.server.players[solo.slot].state == PlayerInput.State.LOST,
			"the slot of the lost phone is kept for a while (the long wait of a paused game)")
	t5 = Time.get_ticks_msec()
	while not solo_game.is_over and Time.get_ticks_msec() - t5 < 8000:
		await process_frame
	await _frames(3)
	_check(solo_game.is_over and solo_game.participants.is_empty()
			and solo_game.menu_buttons().map(func(b): return b.text) == ["Back to menu"],
			"the lost phone does not come back in time: the game ends with 'No players connected' (REQ-GM-22)")
	app.server.paused_slot_grace_ms = Protocol.PAUSED_SLOT_GRACE_MS
	app.server.peer_timeout_ms = Protocol.PEER_TIMEOUT_MS
	solo.set_process(true)
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
	app.server.peer_timeout_ms = 2500   # More than two heartbeats (1 s) of the phone.
	app.server.paused_slot_grace_ms = 1200
	solo2.set_process(false)
	t5 = Time.get_ticks_msec()
	while not solo_race._hold and Time.get_ticks_msec() - t5 < 8000:
		await process_frame
	await _frames(3)
	_check(solo_race._hold and solo_race.is_paused() and not solo_race.is_over
			and solo_race.menu_buttons().map(func(b): return b.text) == ["\u2715  End game"],
			"marble race: the last player is lost, the race waits with a card that has no Resume")
	t5 = Time.get_ticks_msec()
	while not solo_race.is_over and Time.get_ticks_msec() - t5 < 8000:
		await process_frame
	await _frames(3)
	_check(solo_race.is_over and solo_race.menu_buttons().map(func(b): return b.text) == ["Back to menu"],
			"marble race: when the phone does not come back, 'No players connected' opens (REQ-MR-14)")
	app.server.paused_slot_grace_ms = Protocol.PAUSED_SLOT_GRACE_MS
	app.server.peer_timeout_ms = Protocol.PEER_TIMEOUT_MS
	solo2.set_process(true)
	solo2.leave()

	app.go_menu()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), TvGames), "back to the Games screen")
	print("smoke test done, %d failed" % _fails)
	for c in clients:
		c.leave()
	await _frames(30)
	quit(1 if _fails > 0 else 0)
