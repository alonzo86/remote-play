extends Control
## Settings screen (REQ-FL-23, 24): the debug overlay and the invert switches. Back returns to Games.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

var _rows: Array[Button] = []


func _ready() -> void:
	var m := UiKit.margin(self, 0, 80, 0, 70)
	var center := CenterContainer.new()
	m.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1100, 0)
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)
	box.add_child(UiKit.title("Settings", 88))
	box.add_child(UiKit.spacer(10))
	_add_row(box, "Debug overlay", "Shows the link of each phone. The Menu key or F3 does the same.", "overlay",
			func(): App.toggle_overlay())
	_add_row(box, "Invert tilt axes", "Use this when a ball rolls the wrong way.", "invert_tilt", Callable())
	_add_row(box, "Invert pointer yaw", "Use this when the pointer moves left and right the wrong way.", "invert_yaw", Callable())
	box.add_child(UiKit.spacer(10))
	box.add_child(UiKit.button("Back", on_back, true, 40))
	UiKit.focus_later(_rows[0])


func _add_row(parent: Control, title: String, help: String, key: String, custom: Callable) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 118)
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
	col.add_child(UiKit.label(title, 38, UiTheme.CARD_TEXT, UiTheme.body_bold()))
	col.add_child(UiKit.label(help, 24, UiTheme.CARD_DIM, UiTheme.body_font()))
	var state := UiKit.title("", 44, UiTheme.CARD_TEXT)
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(state)
	var refresh := func():
		var on := bool(App.settings[key])
		state.text = "ON" if on else "OFF"
		state.add_theme_color_override("font_color", Color("1f9d6b") if on else UiTheme.CARD_DIM)
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


func on_back() -> void:
	App.go_games()
