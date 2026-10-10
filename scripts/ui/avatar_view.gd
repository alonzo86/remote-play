extends Control
## One avatar as a control (FD-22): the picture of the sheet, with a frame when it is chosen. A tap or a click sends `pressed`.
## The phone profile screens use it for the avatar picker and for the rows.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Avatar = preload("res://scripts/ui/avatar.gd")

signal pressed

var index := 0
var selected := false
var tappable := true


func _init(p_index := 0, side := 96.0) -> void:
	index = p_index
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_index(i: int) -> void:
	index = i
	queue_redraw()


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, UiTheme.BG)
	draw_style_box(UiTheme.line_box(UiTheme.ACCENT if selected else UiTheme.TEXT_DIM, UiTheme.BG, 4), r)
	Avatar.draw(self, r.grow(-8.0), index)


func _gui_input(event: InputEvent) -> void:
	if tappable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
