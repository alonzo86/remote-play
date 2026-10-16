extends SceneTree
## Smoke test of the base class of 3D games (`minigame_3d.gd`) with a tiny game and one simulated phone. Run:
##   godot --headless --path . --script tests/smoke_3d.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _fails := 0
var _checks := 0


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


func _run() -> void:
	await _frames(5)
	var Game3d = load("res://scripts/game/minigame_3d.gd")   # Loaded here: the games need the App autoload.
	var SampleGame = load("res://tests/sample_3d_game.gd")
	root.size = Vector2i(1920, 1080)
	var app: Node = root.get_node("App")
	var phone := ControllerClient.new()
	phone.player_name = "Sim"
	root.add_child(phone)
	phone.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
	var joined := Time.get_ticks_msec()
	while app.server.connected_slots().size() < 1 and Time.get_ticks_msec() - joined < 4000:
		await process_frame

	# The size of the pixel view keeps square pixels in every window shape (REQ-GM-47i).
	_check(Game3d.view_size_for(Vector2(1920, 1080)) == Vector2i(480, 270)
			and Game3d.view_size_for(Vector2(1280, 720)) == Vector2i(480, 270)
			and Game3d.view_size_for(Vector2(1000, 1000)) == Vector2i(270, 270)
			and Game3d.view_size_for(Vector2.ZERO) == Vector2i(480, 270),
			"the 3D view is 480x270 on a 16:9 screen and keeps square pixels in another window shape")

	app.go(SampleGame, {})
	await _frames(4)
	var game: Control = app.current_screen()
	_check(is_instance_of(game, SampleGame) and game._viewport.size == Vector2i(480, 270) and game.participants.size() == 1,
			"the game starts with a 480x270 view")
	_check(game.ticks > 0 and game.hud_draws > 0, "the game logic ticks and the HUD is drawn above the world")
	_check(game.world_to_hud(Vector3.ZERO).distance_to(game.hud.size * 0.5) < 2.0,
			"the point the camera looks at is in the middle of the HUD (REQ-GM-47n)")
	var radius: float = game.radius_on_hud(Vector3.ZERO, 1.0)
	_check(radius > 8.0, "a sphere of 1 m has a clear size on the HUD: %.1f px" % radius)

	# Pause: the world stops (REQ-FL-43), then it runs again.
	game.open_menu("minigame.paused", [["minigame.resume", game.close_menu]])
	await _frames(2)
	var ticks_paused: int = game.ticks
	await _frames(3)
	_check(game.world.process_mode == Node.PROCESS_MODE_DISABLED and game.ticks == ticks_paused,
			"the 3D world and the logic freeze while paused")
	game.close_menu()
	await _frames(3)
	_check(game.world.process_mode == Node.PROCESS_MODE_INHERIT and game.ticks > ticks_paused,
			"the world runs again after the pause")

	# The outline of a key object (REQ-GM-47c): a hull a little bigger
	# than the mesh, culled on the front, 8 % thick, between 3 and 10 cm.
	var hull: MeshInstance3D = game.box.get_child(0)
	var mat: StandardMaterial3D = hull.material_override
	_check(mat.cull_mode == BaseMaterial3D.CULL_FRONT and mat.albedo_color == UiTheme.OUTLINE
			and absf(hull.scale.x - 1.16) < 0.001,
			"a key object has a black outline of 8 % of its size")
	var small_mesh := BoxMesh.new()
	small_mesh.size = Vector3.ONE * 0.1
	var big_mesh := BoxMesh.new()
	big_mesh.size = Vector3.ONE * 10.0
	var small_hull: MeshInstance3D = Game3d.add_outlined_mesh(game.world, small_mesh, Color.RED).get_child(0)
	var big_hull: MeshInstance3D = Game3d.add_outlined_mesh(game.world, big_mesh, Color.RED).get_child(0)
	_check(is_equal_approx(small_hull.scale.x, 1.0 + 2.0 * 0.03 / 0.1)
			and is_equal_approx(big_hull.scale.x, 1.0 + 2.0 * 0.10 / 10.0),
			"the outline is never thinner than 3 cm and never thicker than 10 cm")
	_check(Game3d.flat_material(Color("50c864")).albedo_color == Color("50c864") and game._background_color() == UiTheme.BG,
			"a flat material has the color it is given and the default background is the arcade black")

	phone.leave()
	await _frames(3)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
