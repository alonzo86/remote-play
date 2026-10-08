extends Control
## Settings screen (REQ-FL-23, 24): the debug overlay and the invert tilt switch. Back returns to Games.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

var _rows: Array[Button] = []


func _ready() -> void:
	var m := UiKit.margin(self, 0, 60, 0, 60)
	var center := CenterContainer.new()
	m.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1240, 0)
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)
	box.add_child(UiKit.title("Settings", 88))
	box.add_child(UiKit.spacer(10))
	_add_row(box, "Debug overlay", "Shows the link of each phone. The Menu key or F3 does the same.", "overlay",
			func(): App.toggle_overlay())
	_add_row(box, "Invert tilt axes", "Use this when a ball rolls the wrong way.", "invert_tilt", Callable())
	box.add_child(UiKit.spacer(10))
	var back := UiKit.button("Back", on_back, true, 40)
	back.custom_minimum_size = Vector2(360, 0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	UiKit.focus_later(_rows[0])


func _add_row(parent: Control, title: String, help: String, key: String, custom: Callable) -> void:
	var b := Button.new()
	b.theme_type_variation = "RowButton"
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 128)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 32
	h.offset_right = -32
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	col.add_child(UiKit.label(title, 38, UiTheme.TEXT, UiTheme.body_bold()))
	col.add_child(UiKit.label(help, 28, UiTheme.TEXT_DIM, UiTheme.body_font()))
	var state := Control.new() # The switch: a pill with a knob, green and "ON", or grey and "OFF".
	state.custom_minimum_size = Vector2(190, 78)
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.draw.connect(func(): _draw_switch(state))
	h.add_child(state)
	var refresh := func():
		state.set_meta("on", bool(App.settings[key]))
		state.queue_redraw()
	b.pressed.connect(func():
		if custom.is_valid():
			custom.call()
		else:
			App.settings[key] = not bool(App.settings[key])
			App.save_settings()
		refresh.call())
	refresh.call()
	parent.add_child(b)
	_rows.append(b)


func _draw_switch(c: Control) -> void:
	var on: bool = c.get_meta("on", false)
	c.draw_style_box(UiTheme.card(UiTheme.OK if on else Color("d8d1ec"), UiTheme.OUTLINE, 5, 39, false),
			Rect2(Vector2.ZERO, c.size))
	var r := c.size.y * 0.5 - 12.0
	var kx := c.size.x - c.size.y * 0.5 if on else c.size.y * 0.5
	c.draw_circle(Vector2(kx, c.size.y * 0.5), r + 4.0, UiTheme.OUTLINE)
	c.draw_circle(Vector2(kx, c.size.y * 0.5), r, Color.WHITE)
	var tx := 22.0 if on else c.size.y + 8.0
	c.draw_string(UiTheme.title_font(), Vector2(tx, c.size.y * 0.5 + 14.0), "ON" if on else "OFF",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UiTheme.CARD_TEXT if on else UiTheme.CARD_MUTED)


func on_back() -> void:
	App.go_games()
