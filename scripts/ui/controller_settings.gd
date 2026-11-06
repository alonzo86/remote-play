extends Control
## Phone Settings screen (REQ-FL-66, 62): the HAPTICS switch and the language of the phone, as touch controls. It is reached from
## the waiting screen, so a player changes it between games. Back returns to the waiting screen.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ControllerWait = preload("res://scripts/ui/controller_wait.gd")
const Haptics = preload("res://scripts/game/haptics.gd")
const Lang = preload("res://scripts/core/lang.gd")
const ChoiceRow = preload("res://scripts/ui/choice_row.gd")
const SwitchIcon = preload("res://scripts/ui/switch_icon.gd")

const ROW_H := 120   # A touch target: a finger hits the whole row.

var _haptics: Button
var _haptics_state: Label
var _haptics_switch: Control
var _language: Control


func _ready() -> void:
	var m := UiKit.margin(self, 40, 60, 40, 60)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 36)
	m.add_child(box)
	var title := UiKit.title("common.settings", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	# Touch controls (REQ-FL-66): HAPTICS is a switch (a tap anywhere on the row turns it on or off) and LANGUAGE is a
	# `< ENGLISH >` row whose enabled arrow a tap steps.
	_build_haptics(box)
	_build_language(box)
	var help := UiKit.label("settings.phone_vibrates_games_when", UiTheme.SIZE_BODY,
			UiTheme.TEXT_DESC)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(help)
	box.add_child(UiKit.spacer(60))
	var back := UiKit.box_button("common.back", on_back, UiTheme.SIZE_ITEM)
	back.custom_minimum_size = Vector2(440, 96)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)


## The switch row: the name at the start, then the ON or OFF word and the pixel switch at the end. A tap anywhere on the row turns
## it on or off.
func _build_haptics(box: Control) -> void:
	_haptics = UiKit.box_button("", _on_haptics)
	_haptics.custom_minimum_size = Vector2(0, ROW_H)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 24)
	_haptics.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 32)
	var name_l := UiKit.label("settings.haptics_row", UiTheme.SIZE_ITEM)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(name_l)
	_haptics_state = UiKit.label("", UiTheme.SIZE_ITEM)
	_haptics_state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_haptics_state)
	_haptics_switch = SwitchIcon.new()
	_haptics_switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_haptics_switch)
	box.add_child(_haptics)
	_show_haptics()


func _show_haptics() -> void:
	var on := bool(App.settings.haptics)
	_haptics_state.text = "common.on" if on else "common.off"
	_haptics_state.add_theme_color_override("font_color", UiTheme.OK if on else UiTheme.TEXT_INFO)
	_haptics_switch.on = on


## The language choice: a row like the game settings of the TV, `LANGUAGE  < ENGLISH >`. A tap on an enabled arrow (or the key)
## steps to the other language at once (REQ-FL-62).
func _build_language(box: Control) -> void:
	var names: Array = Lang.CODES.map(func(c): return String(Lang.NAMES[c]))   # Each name is in its own language.
	_language = ChoiceRow.new()
	_language.row = {"label": "settings.language", "values": Lang.CODES.duplicate(), "titles": names}
	_language.value = Lang.current()
	_language.focus_mode = Control.FOCUS_NONE   # A phone has a touch screen: no button takes the focus (REQ-FL-86).
	_language.changed.connect(_on_language)
	box.add_child(_language)


func _on_haptics() -> void:
	App.settings.haptics = not bool(App.settings.haptics)
	App.save_settings()
	_show_haptics()
	if App.settings.haptics:
		Haptics.vibrate(40)   # The sample, so the player feels that it is on.


## Switches this phone between English and Hebrew at once and saves the choice (REQ-FL-62). The TV is not told and is not changed.
func _on_language(code: String) -> void:
	App.set_language(code)
	_language.set_value(code)   # Written again in the new language.


func on_back() -> void:
	App.go(ControllerWait)
