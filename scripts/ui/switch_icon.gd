extends Control
## A pixel on/off switch for the phone Settings (the HAPTICS row): a track and a square knob. ON has a green track and the knob at
## the end of the track, OFF has a gray track and the knob at the start; in a right to left layout (Hebrew) the sides swap. The
## row that holds it takes the tap. The word ON or OFF is next to it, so the state is not only a color.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const TRACK := Vector2(120, 56)

var on := false:
	set(v):
		on = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = TRACK


func _notification(what: int) -> void:
	if what == NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
		queue_redraw()


## The knob is at the right when `on` in a left to right layout; the rect is in the coordinates of the control.
func knob_rect() -> Rect2:
	var at_right := on != is_layout_rtl()
	var side := TRACK.y - 16.0
	var x := TRACK.x - 8.0 - side if at_right else 8.0
	return Rect2(x, 8.0, side, side)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, TRACK), UiTheme.OK if on else UiTheme.TEXT_DIM)
	draw_rect(knob_rect(), UiTheme.BUTTON_TEXT)
