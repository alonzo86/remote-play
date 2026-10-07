extends SceneTree
## Screenshots of the phone screens. Run with --role=controller and a display:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script tests/screenshots_controller.gd -- --role=controller
const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(5)
	var app: Node = root.get_node("App")
	root.size = Vector2i(540, 960)
	await _frames(5)
	root.get_texture().get_image().save_png("user://shot_ctl_connect.png")
	var server := TvServer.new()
	root.add_child(server)
	server.start({})
	server.tv_name = "Living Room TV"
	app.client.connect_to("127.0.0.1", Protocol.WS_PORT, server.room_code)
	await _frames(90)
	root.get_texture().get_image().save_png("user://shot_ctl_wait.png")
	server.set_phase("menu")
	await _frames(20)
	root.get_texture().get_image().save_png("user://shot_ctl_menu.png")
	server.set_phase("playing")
	await _frames(30)
	root.get_texture().get_image().save_png("user://shot_ctl_pad.png")
	print("client state: ", app.client.state, " rtt ", app.client.rtt_ms)
	app.client.leave()
	await _frames(10)
	quit()
