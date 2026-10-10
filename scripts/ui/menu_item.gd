extends Button
## One item of a text menu (REQ-FL-41): a label, and a pixel cursor in front of it when it has the focus. The cursor has the
## color of the focused label (yellow, or red for a destructive item). The colors come from the theme (`UiTheme.make()`).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT


func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	if has_focus() and not disabled:
		var rtl := is_layout_rtl()
		var x := size.x - 8.0 - UiTheme.CURSOR_UNIT * 4.0 if rtl else 8.0   # In front of the text: at the right in Hebrew.
		UiTheme.draw_cursor(self, Vector2(x, size.y * 0.5), get_theme_color("font_focus_color"), UiTheme.CURSOR_UNIT, rtl)
