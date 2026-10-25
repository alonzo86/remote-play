extends Button
## One item of a text menu (REQ-FL-41): a label, and a pixel cursor in front of it when it has the focus. The cursor has the
## color of the focused label (yellow, or red for a destructive item). The colors come from the theme (`UiTheme.make()`).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
		apply_margins()


## The room for the cursor is in front of the text: at the left, and at the right in a right to left layout (Hebrew).
func apply_margins() -> void:
	var room := UiTheme.CURSOR_UNIT * 4.0 + 24.0
	var rtl := is_layout_rtl()
	var s := StyleBoxEmpty.new()
	s.content_margin_left = 16.0 if rtl else room
	s.content_margin_right = room if rtl else 16.0
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		add_theme_stylebox_override(st, s)
	queue_redraw()


func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	if has_focus():   # A disabled item keeps the focus and shows its cursor dim: the marker is never lost (issue #121).
		var rtl := is_layout_rtl()
		var x := size.x - 8.0 - UiTheme.CURSOR_UNIT * 4.0 if rtl else 8.0   # In front of the text: at the right in Hebrew.
		var c := get_theme_color("font_disabled_color" if disabled else "font_focus_color")
		UiTheme.draw_cursor(self, Vector2(x, size.y * 0.5), c, UiTheme.CURSOR_UNIT, rtl)
