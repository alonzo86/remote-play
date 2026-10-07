extends Button
## A round button with a gear drawn in code. OK opens the Settings screen (REQ-FL-16).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(84, 84)
	for st in ["normal", "disabled"]:
		add_theme_stylebox_override(st, UiTheme.card(UiTheme.CARD, UiTheme.OUTLINE, UiTheme.OUTLINE_W, 42))
	for st in ["hover", "focus", "pressed"]:
		add_theme_stylebox_override(st, UiTheme.card(UiTheme.CARD, UiTheme.ACCENT, 10, 42))


func _draw() -> void:
	var c := size * 0.5
	var col := UiTheme.CARD_TEXT
	for i in 8:
		var a := TAU * i / 8.0
		var dir := Vector2.from_angle(a)
		draw_line(c + dir * 20.0, c + dir * 29.0, col, 9.0)
	draw_circle(c, 22.0, col)
	draw_circle(c, 9.0, UiTheme.CARD)
