extends SceneTree
## Screenshots of the phone screens. Run with --role=controller and a display:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script tests/screenshots_controller.gd -- --role=controller
const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")


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
	await _approval_shots(app)
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
	server.set_phase("menu") # Back to the waiting screen. The freed pad must not receive signals.
	await _frames(10)
	server.set_phase("playing")
	await _frames(10)
	print("client state: ", app.client.state, " rtt ", app.client.rtt_ms)
	app.client.leave()
	await _frames(10)
	quit()


## The screens of the join approval (issue #393) in English and Hebrew: the waiting screen from a real TV that asks its host,
## and the status line of the three answers on the Connect screen.
func _approval_shots(app: Node) -> void:
	var store_path := "user://shot_ctl_profiles.cfg"
	var real_store = app.profiles
	app.profiles = ProfileStore.new(store_path)
	app.profiles.create("Maya", 5)
	app.apply_profile()
	var tv := TvServer.new()
	tv.approve_new = true
	root.add_child(tv)
	tv.start({})
	tv.set_phase("menu")
	for code in ["en", "he"]:
		app.set_language(code, false)
		app.last_error = ""
		app.go(app.ControllerConnect)
		await _frames(5)
		app.client.connect_to("127.0.0.1", Protocol.WS_PORT, tv.room_code)
		await _frames(60)
		root.get_texture().get_image().save_png("user://shot_ctl_waiting_%s.png" % code)
		app.client.cancel_wait()
		await _frames(5)
		for reason in ["refused", "timeout", "busy"]:
			app.client.rejected.emit(reason)
			await _frames(5)
			root.get_texture().get_image().save_png("user://shot_ctl_%s_%s.png" % [reason, code])
	app.set_language("en", false)
	app.last_error = ""
	tv.stop()
	tv.free()
	app.profiles = real_store
	app.apply_profile()
	for f in [store_path, store_path + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	await _frames(5)
