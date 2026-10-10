extends Button
## The players badge of the Games screen (REQ-FL-15): four small squares in the slot colors (dark gray when the slot is
## empty) and the number of players, like "2P". OK opens the Players modal. It does not show the room code.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const SQUARE := 24.0
const GAP := 8.0
const SQUARES_W := 4.0 * SQUARE + 3.0 * GAP


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	add_theme_font_size_override("font_size", UiTheme.SIZE_ITEM)
	custom_minimum_size = Vector2(SQUARES_W + 170.0, 84)
	for st in ["normal", "pressed", "disabled"]:
		add_theme_stylebox_override(st, _style(UiTheme.TEXT_DIM))
	for st in ["hover", "focus"]:
		add_theme_stylebox_override(st, _style(UiTheme.ACCENT))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		add_theme_color_override(c, UiTheme.TEXT)
	add_theme_color_override("font_focus_color", UiTheme.ACCENT)
	alignment = HORIZONTAL_ALIGNMENT_LEFT


func _style(color: Color) -> StyleBoxFlat:
	var s := UiTheme.line_box(color)
	s.content_margin_left = UiTheme.LINE + 20.0 + SQUARES_W + 20.0
	return s


func _process(_delta: float) -> void:
	var t := "%dP" % App.server.connected_slots().size()
	if text != t:
		text = t
		queue_redraw()


func _draw() -> void:
	for p in App.server.players:
		var x: float = UiTheme.LINE + 20.0 + p.slot * (SQUARE + GAP)
		draw_rect(Rect2(Vector2(x, (size.y - SQUARE) * 0.5), Vector2(SQUARE, SQUARE)),
				p.color if p.is_present() else UiTheme.SLOT_EMPTY)
