extends SceneTree
## Makes the tile screenshots of the Games screen (REQ-FL-20): assets/tiles/<id>.png, 640x360.
## Every game in the registry runs with two simulated phones. The picture is taken after a
## short time per game. It needs a display and the TV role. Run:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##       --script tools/make_tiles.gd -- --role=tv
## Run it again after a visible change to a game. Commit the new files.

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

const OUT_DIR := "res://assets/tiles/"
const TILE_SIZE := Vector2i(640, 360)
## Seconds to wait before the picture. The default is for games that need no countdown.
const WAIT := {"maze": 4.6, "marble_race": 5.4}

var _seq := [0, 0]


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _stream(c: Array, seconds: float, accel: Array) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in c.size():
			c[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO,
					accel[i], 0, 0, Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


func _run() -> void:
	await _frames(5)
	var app: Node = root.get_node("App")
	var Registry = load("res://scripts/game/registry.gd")
	if app.overlay.visible:
		app.toggle_overlay()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var clients := []
	for i in 2:
		var c := ControllerClient.new()
		c.player_name = "Phone %d" % (i + 1)
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
	var flat := Vector3(0, 0, 9.81)
	await _stream(clients, 0.6, [flat, flat])
	var lean_a := deg_to_rad(10.0)
	var right := Vector3(-sin(lean_a), 0, cos(lean_a)) * 9.81
	var left := Vector3(sin(lean_a), 0.0, cos(lean_a)) * 9.81
	for g in Registry.all():
		var props: Dictionary = g.get("props", {})
		if g.has("variants"):
			props = g.variants[0].props
		app.go(Registry.load_script(String(g.id)), props)
		await _stream(clients, 3.2, [flat, flat]) # The countdown.
		var wait: float = float(WAIT.get(String(g.id), 3.0)) - 3.2
		if wait > 0.0:
			await _stream(clients, wait, [right, left])
		await _frames(3)
		var img := root.get_texture().get_image()
		img.resize(TILE_SIZE.x, TILE_SIZE.y, Image.INTERPOLATE_LANCZOS)
		var path := OUT_DIR + String(g.id) + ".png"
		var err := img.save_png(ProjectSettings.globalize_path(path))
		print("%s: %s (%d)" % [g.id, path, err])
	app.go_menu()
	for c in clients:
		c.leave()
	await _frames(20)
	quit()
