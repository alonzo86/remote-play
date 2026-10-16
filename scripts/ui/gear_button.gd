extends Button
## The OPTIONS button of the Games screen: a framed text box (the frame is yellow with the focus). OK opens the Settings
## screen (REQ-FL-16). The file keeps its old name, from the time it drew a gear.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	text = "gear_button.options"
	add_theme_font_size_override("font_size", UiTheme.SIZE_ITEM)
	custom_minimum_size = Vector2(0, 84)
	for st in ["normal", "pressed", "disabled"]:
		add_theme_stylebox_override(st, UiTheme.line_box(UiTheme.TEXT_DIM))
	for st in ["hover", "focus"]:
		add_theme_stylebox_override(st, UiTheme.line_box(UiTheme.ACCENT))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		add_theme_color_override(c, UiTheme.TEXT)
	add_theme_color_override("font_focus_color", UiTheme.ACCENT)
