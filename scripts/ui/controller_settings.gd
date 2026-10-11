extends Control
## Phone Settings screen (REQ-FL-66): the HAPTICS switch. It is reached from the waiting screen, so a player changes it
## between games. Back returns to the waiting screen.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ControllerWait = preload("res://scripts/ui/controller_wait.gd")

var _haptics: Button


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
	var about := UiKit.box_button("common.about", func():
		App.go(App.AboutScreen, {"back_screen": App.ControllerSettings, "scanner_note": OS.get_name() == "Android"}),
			UiTheme.SIZE_ITEM)
	about.custom_minimum_size = Vector2(0, 110)
	box.add_child(about)
	box.add_child(UiKit.spacer(60))
	var back := UiKit.box_button("common.back", on_back, UiTheme.SIZE_ITEM)
	back.custom_minimum_size = Vector2(440, 96)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	_refresh()


func _refresh() -> void:
	_haptics.text = "HAPTICS: " + ("ON" if bool(App.settings.haptics) else "OFF")


func _toggle_haptics() -> void:
	App.settings.haptics = not bool(App.settings.haptics)
	App.save_settings()
	_refresh()
	if App.settings.haptics:
		Input.vibrate_handheld(40)   # The sample, so the player feels that it is on.


func on_back() -> void:
	App.go(ControllerWait)
