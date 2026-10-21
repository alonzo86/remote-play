extends RefCounted
## Small builders for the arcade screens (docs/TV_FLOW.md). Screens are built in code. All UI text is upper case (REQ-FL-39).

const Lang = preload("res://scripts/core/lang.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const MenuItem = preload("res://scripts/ui/menu_item.gd")
const BlinkLabel = preload("res://scripts/ui/blink_label.gd")


## The text of a label or button. A key of the table stays as it is: the node translates it by itself (the table has the text
## in upper case, REQ-FL-39). Any other text (a name, a number) is set in upper case here.
static func shown(text: String) -> String:
	return text if Lang.has(text) else text.to_upper()


static func label(text: String, size := UiTheme.SIZE_BODY, color: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = shown(text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", size / 4)   # The pixel font has no leading: wrapped lines would touch.
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A title: yellow, in the arcade font.
static func title(text: String, size := UiTheme.SIZE_TITLE, color: Color = UiTheme.ACCENT) -> Label:
	return label(text, size, color)


## A prompt that blinks (PRESS OK).
static func blinking(text: String, size := UiTheme.SIZE_ITEM, color: Color = UiTheme.ACCENT) -> Label:
	var l: Label = BlinkLabel.new()
	l.text = shown(text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A menu item: text with a cursor when it has the focus. `role` is "" (a normal item), "danger" (red with the focus) or
## "quiet" (dim until it has the focus).
static func item(text: String, cb: Callable, size := UiTheme.SIZE_ITEM, role := "") -> Button:
	var b: Button = MenuItem.new()
	b.text = shown(text)
	b.add_theme_font_size_override("font_size", size)
	match role:
		"danger":
			b.theme_type_variation = "DangerButton"
		"quiet":
			b.theme_type_variation = "QuietButton"
	b.pressed.connect(cb)
	return b


## A text menu: one column of items. Each entry is `[label, callable, role]` (the role can be left out).
static func menu(entries: Array, size := UiTheme.SIZE_ITEM) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	for e in entries:
		box.add_child(item(String(e[0]), e[1], size, String(e[2]) if e.size() > 2 else ""))
	return box


## A framed text box for the phone (REQ-FL-52): a touch screen has no cursor, so the button shows its edge. The frame is
## `color`. With the focus (a keyboard on a desktop run) it is yellow; pressed, the box fills with the frame color.
## True in the phone app. It asks the autoload at run time, because a test script loads this file before the autoloads exist.
static func _on_phone() -> bool:
	var role: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Role")
	return role != null and role.is_controller()


static func box_button(text: String, cb: Callable, size := UiTheme.SIZE_ITEM, color: Color = UiTheme.TEXT) -> Button:
	var b := Button.new()
	b.text = shown(text)
	# A phone button is touched, never focused (REQ-FL-86); the TV remote needs the focus.
	b.focus_mode = Control.FOCUS_NONE if _on_phone() else Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", UiTheme.line_box(color))
	b.add_theme_stylebox_override("hover", UiTheme.line_box(color))
	b.add_theme_stylebox_override("focus", UiTheme.line_box(UiTheme.ACCENT))
	b.add_theme_stylebox_override("pressed", UiTheme.line_box(color, color))
	b.add_theme_stylebox_override("disabled", UiTheme.line_box(UiTheme.TEXT_DIM))
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color)
	b.add_theme_color_override("font_focus_color", UiTheme.ACCENT)
	b.add_theme_color_override("font_pressed_color", UiTheme.BG)
	b.add_theme_color_override("font_disabled_color", UiTheme.TEXT_DIM)
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


## A panel container with the double frame (REQ-FL-38). `padding` is the space inside the frame.
static func panel(padding := 24) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.frame(padding))
	return p


## Gives a control the focus on the next frame. It does nothing when the control is gone by then
## (the screen can change in between).
static func focus_later(c: Control) -> void:
	if c != null and is_instance_valid(c):
		c.add_child((load("res://scripts/ui/focus_later.gd") as GDScript).new())
