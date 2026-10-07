extends "res://scripts/game/minigame_3d.gd"
## 3D template game. Each phone tilts a sphere on a square floor. There is no goal.
## Copy this folder to start a new 3D game. It shows how to use Minigame3D and PlayerInput.

const FLOOR_HALF := 8.0
const BALL_R := 0.6
const SPEED := 9.0

var _balls := {}   # slot -> MeshInstance3D


func _world_ready() -> void:
	camera.position = Vector3(0, 14, 11)
	camera.look_at(Vector3.ZERO)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(FLOOR_HALF * 2.0, 0.4, FLOOR_HALF * 2.0)
	add_mesh(world, floor_mesh, UiTheme.PANEL_LIGHT, Vector3(0, -0.2, 0))
	var sphere := SphereMesh.new()
	sphere.radius = BALL_R
	sphere.height = BALL_R * 2.0
	var i := 0
	for s in participants:
		var x := (float(i) - (participants.size() - 1) * 0.5) * 3.0
		_balls[s] = add_mesh(world, sphere, player(s).color, Vector3(x, BALL_R, 0))
		i += 1
	if participants.is_empty():
		open_menu("No players connected", [["Back to menu", App.go_menu]])


func _can_open_menu() -> bool:
	return not participants.is_empty()


func _world_tick(delta: float) -> void:
	for s in _balls:
		var t: Vector2 = player(s).tilt()
		var ball: MeshInstance3D = _balls[s]
		var p := ball.position + Vector3(t.x, 0, t.y) * SPEED * delta
		p.x = clampf(p.x, -FLOOR_HALF + BALL_R, FLOOR_HALF - BALL_R)
		p.z = clampf(p.z, -FLOOR_HALF + BALL_R, FLOOR_HALF - BALL_R)
		ball.position = p


func _hud_draw(canvas: Control) -> void:
	Shell.title(canvas, "3D DEMO")
	Shell.text(canvas, Vector2(60, 146), "Tilt your phone to roll your ball.", 30, UiTheme.TEXT_DIM)
