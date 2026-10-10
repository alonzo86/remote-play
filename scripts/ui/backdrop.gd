extends Control
## The plain black background (REQ-FL-45). Drawn in code.
## App keeps one of these on a layer behind every screen.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
