extends "res://scripts/game/minigame_3d.gd"
## A tiny 3D game for tests/smoke_3d.gd: one outlined box under the camera. It counts its ticks and its HUD draws.

var ticks := 0
var hud_draws := 0
var box: MeshInstance3D


func _world_ready() -> void:
	box = add_outlined_mesh(world, BoxMesh.new(), Color("e63946"))


func _world_tick(_delta: float) -> void:
	ticks += 1


func _hud_draw(canvas: Control) -> void:
	hud_draws += 1
	canvas.draw_rect(Rect2(0, 0, 10, 10), Color.WHITE)
