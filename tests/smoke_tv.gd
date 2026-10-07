extends SceneTree
## Smoke test of the whole TV app with two simulated phones. Run:
##   godot --headless --path . --script tests/smoke_tv.gd -- --role=tv
## It opens the menu, the maze and the pointer test, and checks that tilt moves a ball.

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
var MazeGame
var PointerTest
var Demo3D
var MarbleRace
var Registry
var MarbleTrack
var TvMenu

var _fails := 0
var _seq := [0, 0]


func _initialize() -> void:
	_run()


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
	PointerTest = load("res://scripts/game/pointer_test/pointer_test.gd")
	Demo3D = load("res://scripts/game/demo3d/demo3d_game.gd")
	MarbleTrack = load("res://scripts/game/marble_race/marble_track.gd")
	Registry = load("res://scripts/game/registry.gd")
	MarbleRace = load("res://scripts/game/marble_race/marble_race.gd")
	TvMenu = load("res://scripts/ui/tv_menu.gd")
	var app: Node = root.get_node("App")
	_check(is_instance_of(app.current_screen(), TvMenu), "TV starts on the menu")
	_check(app.server.listening, "server is listening")

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
	await _stream(clients[0], 0, 3.3, flat)
	var a := deg_to_rad(15.0)
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

	# Pointer test
	app.go(PointerTest)
	await _frames(3)
	var pt: Control = app.current_screen()
	await _stream(clients[0], 0, 0.5, flat)
	clients[0].send_recenter()
	await _stream(clients[0], 0, 0.5, flat)
	var before: Vector2 = pt._cursor(0)
	await _stream(clients[0], 0, 0.5, flat, Vector3(0, 0, 1.0))
	var after: Vector2 = pt._cursor(0)
	_check(after.x < before.x - 50.0, "cursor moves left when the phone turns left (%.0f -> %.0f)" % [before.x, after.x])
	await _stream(clients[0], 0, 0.1, flat, Vector3.ZERO, Protocol.BTN_A)
	await _stream(clients[0], 0, 0.1, flat, Vector3.ZERO, 0)
	await _frames(3)

	# 3D game: a tilted phone moves its sphere on the floor.
	app.go(Demo3D)
	await _frames(3)
	var g3: Control = app.current_screen()
	_check(is_instance_of(g3, Demo3D) and g3.camera != null and g3.participants.size() == 2, "3D demo starts with a camera")
	var x0: float = g3._balls[0].position.x
	await _stream(clients[0], 0, 1.5, tilt)
	_check(g3._balls[0].position.x > x0 + 0.3, "3D ball 0 rolls right when the phone tilts right")
	g3.open_menu("Paused", [["Resume", g3.close_menu]])
	await _frames(2)
	_check(g3.world.process_mode == Node.PROCESS_MODE_DISABLED, "3D world freezes while paused")
	g3.close_menu()
	await _frames(2)

	# Marble race menu: one entry, then a track list, then the race.
	app.go_menu()
	await _frames(3)
	var menu: Control = app.current_screen()
	menu._start_game("marble_race")
	await _frames(2)
	_check(is_instance_of(app.current_screen(), TvMenu) and menu._variants_of == "marble_race"
			and menu._buttons.size() == MarbleTrack.IDS.size() + 1, "Marble Race opens the track list before the race")
	menu.on_back()
	await _frames(2)
	_check(menu._variants_of == "", "Back from the track list returns to the main menu")

	# Marble race: grid wait, tilt moves a marble, finish line ends the race.
	app.go(MarbleRace, Registry.find("marble_race").variants[2].props)
	await _frames(3)
	var mr: Control = app.current_screen()
	_check(is_instance_of(mr, MarbleRace) and mr.participants.size() == 2, "marble race starts with 2 participants")
	_check(mr.track.id == "zigzag", "registry props choose the track")
	_check(is_equal_approx(mr._racers[0].arc, mr._racers[1].arc) and absf(mr._racers[0].pos.distance_to(mr._racers[1].pos)) >= 1.0,
			"marbles start on one line and do not touch (REQ-MR-4)")
	var mx0: float = mr._racers[0].pos.x
	await _stream(clients[0], 0, 1.0, tilt)
	_check(absf(mr._racers[0].pos.x - mx0) < 0.01, "marbles wait on the grid during the countdown")
	await _stream(clients[0], 0, 2.6, tilt)
	_check(mr._racers[0].pos.x > mx0 + 0.3, "marble 0 rolls right when the phone tilts right")
	_check(mr.standings().size() == 2, "standings list both players")
	for s in [0, 1]:
		mr._racers[s].pos = mr.track.point_at(mr.finish_arc + 0.5)
	await _frames(5)
	_check(mr._racers[0].finish_time >= 0.0 and mr._racers[1].finish_time >= 0.0, "marbles past the line finish")
	_check(mr._ended and mr.is_paused(), "race ends and the results menu opens")
	var results_items: int = mr._menu_box.get_child_count()
	mr._open_picker()
	await _frames(2)
	_check(mr._picking and mr._menu_box.get_child_count() == MarbleTrack.IDS.size() + 2,
			"track picker lists every track and Cancel")
	mr.on_back()
	await _frames(2)
	_check(not mr._picking and mr._ended and mr._menu_box.get_child_count() == results_items,
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

	app.go_menu()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), TvMenu), "back to the menu")
	print("smoke test done, %d failed" % _fails)
	for c in clients:
		c.leave()
	await _frames(30)
	quit(1 if _fails > 0 else 0)
