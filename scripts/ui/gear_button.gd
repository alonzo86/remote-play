extends Button
## The OPTIONS button of the Games screen: a white text box (the border is thick and yellow with the focus). OK opens the Settings
## screen (REQ-FL-16). The file keeps its old name, from the time it drew a gear.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	text = "gear_button.options"
	add_theme_font_size_override("font_size", UiTheme.SIZE_ITEM)
	custom_minimum_size = Vector2(0, 84)
	UiTheme.style_button(self)   # White like every enabled button (issue #173); the focus is a thick yellow border.
