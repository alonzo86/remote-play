extends Button
## A round button with a gear drawn in code. OK opens the Settings screen (REQ-FL-16).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(84, 84)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	theme_type_variation = "RowButton"
	add_theme_stylebox_override("normal", UiTheme.button_style(UiTheme.BUTTON, "normal", 42))
	add_theme_stylebox_override("disabled", UiTheme.button_style(UiTheme.BUTTON, "disabled", 42))
	for st in ["hover", "focus"]:
		add_theme_stylebox_override(st, UiTheme.button_style(UiTheme.BUTTON, "focus", 42))
	add_theme_stylebox_override("pressed", UiTheme.button_style(UiTheme.BUTTON, "pressed", 42))


func _draw() -> void:
	var c := size * 0.5
	var col := UiTheme.ACCENT if has_focus() else UiTheme.TEXT # Yellow gear on focus: the border is black.
	for i in 8:
		var a := TAU * i / 8.0
		var dir := Vector2.from_angle(a)
		draw_line(c + dir * 20.0, c + dir * 29.0, col, 9.0)
	draw_circle(c, 22.0, col)
	draw_circle(c, 9.0, UiTheme.BUTTON)
