extends RefCounted
## Flat geometric theme. No external assets.

const BG := Color("14161c")
const PANEL := Color("1f232d")
const PANEL_LIGHT := Color("2b3140")
const TEXT := Color("f2f2f2")
const TEXT_DIM := Color("9aa3b5")
const ACCENT := Color("ffd166")
const OK := Color("57cc99")
const BAD := Color("e63946")


static func box(fill: Color, border: Color = Color.TRANSPARENT, border_w := 0, radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_border_width_all(border_w)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 34
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", BG)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_stylebox("normal", "Button", box(PANEL_LIGHT))
	t.set_stylebox("hover", "Button", box(PANEL_LIGHT, ACCENT, 3))
	t.set_stylebox("pressed", "Button", box(ACCENT))
	t.set_stylebox("focus", "Button", box(ACCENT))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("normal", "LineEdit", box(PANEL_LIGHT))
	t.set_stylebox("focus", "LineEdit", box(PANEL_LIGHT, ACCENT, 3))
	return t
