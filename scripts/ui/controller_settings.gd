extends Control
## Phone Settings screen (REQ-FL-66, 62): the HAPTICS switch and the language of the phone. It is reached from the waiting
## screen, so a player changes it between games. Back returns to the waiting screen.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ControllerWait = preload("res://scripts/ui/controller_wait.gd")
const Haptics = preload("res://scripts/game/haptics.gd")
const Lang = preload("res://scripts/core/lang.gd")

var _haptics: Button
var _language: Button


func _ready() -> void:
	var m := UiKit.margin(self, 40, 60, 40, 60)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 36)
	m.add_child(box)
	var title := UiKit.title("common.settings", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_haptics = UiKit.box_button("", _toggle_haptics, UiTheme.SIZE_ITEM)
	_haptics.custom_minimum_size = Vector2(0, 120)
	box.add_child(_haptics)
	var help := UiKit.label("settings.phone_vibrates_games_when", UiTheme.SIZE_BODY,
			UiTheme.TEXT_DIM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(help)
	_language = UiKit.box_button("", _toggle_language, UiTheme.SIZE_ITEM)
	_language.custom_minimum_size = Vector2(0, 120)
	_language.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # Built from a translated word and the name of a language.
	box.add_child(_language)
	box.add_child(UiKit.spacer(60))
	var back := UiKit.box_button("common.back", on_back, UiTheme.SIZE_ITEM)
	back.custom_minimum_size = Vector2(440, 96)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	_refresh()


func _refresh() -> void:
	_haptics.text = "HAPTICS: " + ("ON" if bool(App.settings.haptics) else "OFF")
	# The language name is in its own language. All caps (REQ-FL-39); Hebrew has no case.
	_language.text = (Lang.t("settings.language") + ": " + String(Lang.NAMES[Lang.current()])).to_upper()


func _toggle_haptics() -> void:
	App.settings.haptics = not bool(App.settings.haptics)
	App.save_settings()
	_refresh()
	if App.settings.haptics:
		Haptics.vibrate(40)   # The sample, so the player feels that it is on.


## Switches this phone between English and Hebrew at once and saves the choice (REQ-FL-62). The TV is not told and is not changed.
func _toggle_language() -> void:
	App.set_language(Lang.other(Lang.current()))
	_refresh()


func on_back() -> void:
	App.go(ControllerWait)
