extends Button
## The players badge of the Games screen (REQ-FL-15): four dots in the slot colors and the number of
## players. OK opens the Players modal. It does not show the room code.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const DOTS_W := 150.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	theme_type_variation = "RowButton"
	add_theme_font_size_override("font_size", 34)
	custom_minimum_size = Vector2(DOTS_W + 250, 84)
	add_theme_stylebox_override("normal", _style("normal"))
	add_theme_stylebox_override("disabled", _style("disabled"))
	for st in ["hover", "focus"]:
		add_theme_stylebox_override(st, _style("focus"))
	add_theme_stylebox_override("pressed", _style("pressed"))
	alignment = HORIZONTAL_ALIGNMENT_LEFT


func _style(state: String) -> StyleBoxFlat:
	var s := UiTheme.button_style(UiTheme.BUTTON, state, 42)
	s.content_margin_left = DOTS_W
	s.content_margin_right = 28
	return s


func _process(_delta: float) -> void:
	var n: int = App.server.connected_slots().size()
	var t := "%d player%s" % [n, "" if n == 1 else "s"]
	if text != t:
		text = t
		queue_redraw()


func _draw() -> void:
	for p in App.server.players:
		var c := Vector2(44.0 + p.slot * 24.0, size.y * 0.5)
		draw_circle(c, 15.0, UiTheme.OUTLINE)
		draw_circle(c, 11.0, p.color if p.is_present() else UiTheme.BADGE_EMPTY)
