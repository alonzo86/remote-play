extends Control
## The purple background with a few confetti dots (REQ-FL-45). Drawn in code.
## App keeps one of these on a layer behind every screen.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

## Dots: position as a fraction of the screen, radius in pixels, color index.
const DOTS := [
	[0.06, 0.18, 22.0, 0], [0.92, 0.10, 30.0, 1], [0.84, 0.88, 20.0, 2], [0.03, 0.82, 16.0, 1],
	[0.50, 0.04, 14.0, 2], [0.97, 0.55, 18.0, 0], [0.30, 0.95, 24.0, 1], [0.70, 0.07, 12.0, 0],
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	var scale_f := minf(size.x, size.y) / 1080.0
	for d in DOTS:
		draw_circle(Vector2(size.x * d[0], size.y * d[1]), d[2] * scale_f, Color(UiTheme.CONFETTI[d[3]], 0.85))
