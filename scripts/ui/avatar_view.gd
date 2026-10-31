extends Control
## One avatar as a control (FD-22): the picture of the sheet, with a frame when it is chosen. A tap or a click sends `pressed`.
## The phone profile screens use it for the avatar picker and for the rows.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Avatar = preload("res://scripts/ui/avatar.gd")

signal pressed

const TAP_SLOP := 24.0   # A finger that moved farther than this scrolled the list; it did not tap.

var index := 0
var selected := false
var tappable := true
var framed := true   # False draws the picture alone: no frame and no background (the Connect screen dropdown).
var _press_at := Vector2.INF   # Where the finger went down; a tap is a release near it (the picker scrolls by dragging).


func _init(p_index := 0, side := 96.0) -> void:
	index = p_index
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_PASS   # A drag goes on to the scroll box that holds the picker.


## Shows another avatar (only the tests call it; the picker makes a new view for each choice).
func set_index(i: int) -> void:
	index = i
	queue_redraw()


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if not framed:
		Avatar.draw(self, r, index)
		return
	draw_rect(r, UiTheme.BG)
	draw_style_box(UiTheme.line_box(UiTheme.ACCENT if selected else UiTheme.TEXT_DIM, UiTheme.BG, 4), r)
	Avatar.draw(self, r.grow(-8.0), index)


func _gui_input(event: InputEvent) -> void:
	if not tappable or not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_press_at = event.position
	elif _press_at != Vector2.INF and _press_at.distance_to(event.position) <= TAP_SLOP:
		_press_at = Vector2.INF
		pressed.emit()
