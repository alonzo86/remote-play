extends Control
## Settings screen (REQ-FL-23, 24): the debug overlay and the invert tilt switch, and the language (REQ-FL-61). Back returns to
## Games.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const MenuItem = preload("res://scripts/ui/menu_item.gd")
const Lang = preload("res://scripts/core/lang.gd")

const ROW_H := 120   # A row is its name and its value on one line (REQ-FL-23).

var _rows: Array[Button] = []
var scroll_box: ScrollContainer


func _ready() -> void:
	var m := UiKit.margin(self, 0, 60, 0, 60)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1440, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 22)
	m.add_child(box)
	box.add_child(UiKit.title("common.settings"))
	# The rows scroll with the focus (REQ-FL-23); the title above and Back below stay in view.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	scroll_box = scroll
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 22)
	scroll.add_child(rows)
	_add_row(rows, "settings.debug_overlay", "overlay", Callable())
	_add_row(rows, "settings.invert_tilt_axes", "invert_tilt", Callable())
	_add_level_row(rows, "settings.music", "music_volume")
	_add_level_row(rows, "settings.effects", "sfx_volume")
	_add_row(rows, "settings.language", "language", func(): _step_language(1))
	box.add_child(UiKit.spacer(10))
	box.add_child(UiKit.item("common.about", func(): App.go(App.AboutScreen, {"back_screen": App.TvSettings}),
			UiTheme.SIZE_ITEM, "quiet"))
	box.add_child(UiKit.item("common.back", on_back, UiTheme.SIZE_ITEM, "quiet"))
	UiKit.focus_later(_rows[0])


func _add_row(parent: Control, title: String, key: String, custom: Callable) -> void:
	var b: Button = MenuItem.new()
	b.custom_minimum_size = Vector2(0, ROW_H)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = UiTheme.CURSOR_UNIT * 4.0 + 24.0
	h.offset_right = -(UiTheme.CURSOR_UNIT * 4.0 + 24.0)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var name_l := UiKit.label(title, UiTheme.SIZE_ITEM)
	col.add_child(name_l)
	var state := UiKit.label("", UiTheme.SIZE_ITEM)   # ON in green, OFF in gray: the word says it, not the color alone.
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(state)
	var refresh := func():
		if key == "language":
			state.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # The name of a language is written in that language.
			state.text = String(Lang.NAMES[Lang.current()]).to_upper()
			state.add_theme_color_override("font_color", UiTheme.SELECTED)
			return
		var on := bool(App.settings[key])
		state.text = "common.on" if on else "common.off"
		state.add_theme_color_override("font_color", UiTheme.OK if on else UiTheme.TEXT_INFO)
	var tint := func():
		name_l.add_theme_color_override("font_color", UiTheme.ACCENT if b.has_focus() else UiTheme.TEXT)
	b.focus_entered.connect(tint)
	b.focus_exited.connect(tint)
	if custom.is_valid():
		b.pressed.connect(func():
			custom.call()
			refresh.call())
	else:
		# An on/off row changes with Left and Right like a choice row (issue #122): Left is OFF, Right is ON, mirrored in
		# Hebrew. OK does nothing.
		b.gui_input.connect(func(e: InputEvent):
			var forward := -1 if b.is_layout_rtl() else 1
			for action in ["ui_left", "ui_right"]:
				if e.is_action_pressed(action):
					var on: bool = (forward if action == "ui_right" else -forward) > 0
					if key == "overlay":
						App.set_overlay(on)
					else:
						App.settings[key] = on
						App.save_settings()
					refresh.call()
					b.accept_event())
	if key == "language":   # Left and Right choose the language from the list (REQ-FL-61).
		b.gui_input.connect(func(e: InputEvent):
			for action in ["ui_left", "ui_right"]:
				if e.is_action_pressed(action):
					_step_language(-1 if action == "ui_left" else 1)
					refresh.call()
					b.accept_event())
	refresh.call()
	parent.add_child(b)
	_rows.append(b)


## A volume row (REQ-FL-64): the value 0 to 10 at the right. Left and Right change it, OK adds one and goes back to 0 after 10.
func _add_level_row(parent: Control, title: String, key: String) -> void:
	var b: Button = MenuItem.new()
	b.custom_minimum_size = Vector2(0, ROW_H)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = UiTheme.CURSOR_UNIT * 4.0 + 24.0
	h.offset_right = -(UiTheme.CURSOR_UNIT * 4.0 + 24.0)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var name_l := UiKit.label(title, UiTheme.SIZE_ITEM)
	col.add_child(name_l)
	var value := UiKit.label("", UiTheme.SIZE_ITEM, UiTheme.SELECTED)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(value)
	var tint := func():
		name_l.add_theme_color_override("font_color", UiTheme.ACCENT if b.has_focus() else UiTheme.TEXT)
	b.focus_entered.connect(tint)
	b.focus_exited.connect(tint)
	var set_level := func(v: int):
		App.settings[key] = v
		App.save_settings()
		Sound.apply_settings()
		value.text = "%d / 10" % v
		Sound.sfx("select")   # The sample, so the new level is heard.
	value.text = "%d / 10" % int(App.settings[key])
	b.pressed.connect(func(): set_level.call((int(App.settings[key]) + 1) % 11))
	b.gui_input.connect(func(e: InputEvent):
		if e.is_action_pressed("ui_left"):
			set_level.call(maxi(int(App.settings[key]) - 1, 0))
			b.accept_event()
		elif e.is_action_pressed("ui_right"):
			set_level.call(mini(int(App.settings[key]) + 1, 10))
			b.accept_event())
	parent.add_child(b)
	_rows.append(b)


## Moves to the next (1) or the previous (-1) language of the list. After the last comes the first, so OK goes
## through all of them.
func _step_language(dir: int) -> void:
	var codes := Lang.CODES
	var i := codes.find(Lang.current())
	App.set_language(codes[posmod(i + dir, codes.size())])


func on_back() -> void:
	App.go_games()
