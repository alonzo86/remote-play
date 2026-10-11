extends Control
## One medal of the sheet as a control (REQ-GM-73), for the rows of the result menu. `tier` is "gold", "silver" or "bronze".

const Medal = preload("res://scripts/ui/medal.gd")

var tier := "gold"


func _init(p_tier := "gold", side := 48.0) -> void:
	tier = p_tier
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	Medal.draw(self, Rect2(Vector2.ZERO, size), tier)
