extends Control
## Settings screen (REQ-FL-23, 24): the debug overlay and the invert tilt switch, and the language (REQ-FL-61). Back returns to
## Games.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const MenuItem = preload("res://scripts/ui/menu_item.gd")
const Lang = preload("res://scripts/core/lang.gd")

var _rows: Array[Button] = []
var scroll_box: ScrollContainer


func _ready() -> void:
	var m := UiKit.margin(self, 0, 60, 0, 60)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1440, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 22)
	m.add_child(box)
	box.add_child(UiKit.title("Settings"))
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
	_add_row(rows, "Debug overlay", "Shows the link of each phone. The Menu key or F3 does the same.", "overlay",
			func(): App.toggle_overlay())
	_add_row(rows, "Invert tilt axes", "Use this when a ball rolls the wrong way.", "invert_tilt", Callable())
	_add_level_row(rows, "Music", "Left and Right change the music volume.", "music_volume")
	_add_level_row(rows, "Effects", "Left and Right change the volume of the sound effects.", "sfx_volume")
	_add_row(rows, "Mute", "Turns off the music and the effects. The phones are not changed.", "mute", Callable())
	_add_row(rows, "Language", "English or Hebrew. The phones follow the TV.", "language",
			func(): App.set_language(Lang.other(Lang.current())))
	box.add_child(UiKit.spacer(10))
	box.add_child(UiKit.item("About", func(): App.go(App.AboutScreen, {"back_screen": App.TvSettings}), UiTheme.SIZE_ITEM, "quiet"))
	box.add_child(UiKit.item("Back", on_back, UiTheme.SIZE_ITEM, "quiet"))
	UiKit.focus_later(_rows[0])


func _add_row(parent: Control, title: String, help: String, key: String, custom: Callable) -> void:
	var b: Button = MenuItem.new()
	b.custom_minimum_size = Vector2(0, 160)
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
	var help_l := UiKit.label(help, UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	help_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(help_l)
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
		state.text = "ON" if on else "OFF"
		state.add_theme_color_override("font_color", UiTheme.OK if on else UiTheme.TEXT_DIM)
	var tint := func():
		name_l.add_theme_color_override("font_color", UiTheme.ACCENT if b.has_focus() else UiTheme.TEXT)
	b.focus_entered.connect(tint)
	b.focus_exited.connect(tint)
	b.pressed.connect(func():
		if custom.is_valid():
			custom.call()
		else:
			App.settings[key] = not bool(App.settings[key])
			App.save_settings()
			Sound.apply_settings()   # The Mute row acts at once (REQ-FL-64).
		refresh.call())
	refresh.call()
	parent.add_child(b)
	_rows.append(b)


## A volume row (REQ-FL-64): the value 0 to 10 at the right. Left and Right change it, OK adds one and goes back to 0 after 10.
func _add_level_row(parent: Control, title: String, help: String, key: String) -> void:
	var b: Button = MenuItem.new()
	b.custom_minimum_size = Vector2(0, 160)
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
	var help_l := UiKit.label(help, UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	help_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(help_l)
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


func on_back() -> void:
	App.go_games()
