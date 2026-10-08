extends RefCounted
## Small builders for the Party Pop screens (docs/TV_FLOW.md). Screens are built in code.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")


static func label(text: String, size := 34, color: Color = UiTheme.TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A title in the display font, yellow.
static func title(text: String, size := 76, color: Color = UiTheme.ACCENT) -> Label:
	return label(text, size, color, UiTheme.title_font())


static func button(text: String, cb: Callable, primary := false, size := 36, secondary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size)
	if primary:
		b.theme_type_variation = "PrimaryButton"
	elif secondary:
		b.theme_type_variation = "SecondaryButton"
	b.pressed.connect(cb)
	return b


static func spacer(h := 0, expand := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(m)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return m


## A card container with the Party Pop outline and shadow.
static func card_panel(fill: Color = UiTheme.CARD, margin_px := 32) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiTheme.card(fill)
	s.set_content_margin_all(margin_px)
	p.add_theme_stylebox_override("panel", s)
	return p


## Gives a control the focus on the next frame. It does nothing when the control is gone by then
## (the screen can change in between).
static func focus_later(c: Control) -> void:
	if c != null and is_instance_valid(c):
		c.add_child((load("res://scripts/ui/focus_later.gd") as GDScript).new())
