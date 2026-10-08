extends SceneTree
## Saves screenshots of the TV screens (needs a display, for example xvfb-run). Run:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --role=tv
## Output: user://shot_*.png

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
var _seq := [0, 0]


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	root.get_texture().get_image().save_png("user://shot_%s.png" % name)


func _stream(c: Array, seconds: float, a0: Vector3, g0 := Vector3.ZERO) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in c.size():
			c[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), g0 if i == 0 else Vector3.ZERO,
					a0, 0, 0, Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


func _run() -> void:
	await _frames(5)
	var app: Node = root.get_node("App")
	var MazeGame = load("res://scripts/game/maze/maze_game.gd")
	var MarbleRace = load("res://scripts/game/marble_race/marble_race.gd")
	var clients := []
	for i in 2:
		var c := ControllerClient.new()
		c.player_name = "Phone %d" % (i + 1)
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
	await _stream(clients, 0.6, Vector3(0, 0, 9.81))
	if app.overlay.visible:
		app.toggle_overlay() # The UI shots show the screens without the overlay.
	app.discovery.ip = "192.168.1.20" # A sandbox has no Wi-Fi address. The QR code needs one.
	app.go_logo()
	await _frames(40)
	await _shot("logo")
	app.go_connect()
	await _frames(20)
	await _shot("connect")
	app.go_games()
	await _frames(20)
	await _shot("games")
	app.current_screen()._open_players()
	await _frames(20)
	await _shot("players")
	app.current_screen().on_back()
	app.go_settings()
	await _frames(10)
	await _shot("settings")
	app.go_connect()
	await _frames(5)
	app.current_screen().on_back()
	await _frames(20)
	await _shot("quit")
	app.go_games()
	app.go(MazeGame)
	await _stream(clients, 1.5, Vector3(0, 0, 9.81))
	await _shot("maze_countdown")
	await _stream(clients, 2.5, Vector3(0, 0, 9.81))
	await _stream(clients, 1.2, Vector3(-0.3, 0.2, 9.8))
	await _shot("maze_play")
	app.go(MarbleRace, {"track_id": "classic"})
	await _stream(clients, 4.5, Vector3(0, 0, 9.81))
	await _stream(clients, 1.5, Vector3(-0.3, 0.2, 9.8))
	await _shot("marble_play")
	for c in clients:
		c.leave()
	await _frames(20)
	quit()
