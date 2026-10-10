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
	var title := UiKit.title("Settings", 84)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_haptics = UiKit.button("", _toggle_haptics, true, 44)
	_haptics.custom_minimum_size = Vector2(0, 120)
	box.add_child(_haptics)
	var help := UiKit.label("The phone vibrates in games: when you score, bump or start. The TV is not changed.", 36,
			UiTheme.TEXT_DIM, UiTheme.body_font())
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(help)
	box.add_child(UiKit.spacer(60))
	var back := UiKit.button("Back", on_back, false, 40)
	back.custom_minimum_size = Vector2(440, 96)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	_refresh()


func _refresh() -> void:
	_haptics.text = "Haptics: " + ("ON" if bool(App.settings.haptics) else "OFF")


func _toggle_haptics() -> void:
	App.settings.haptics = not bool(App.settings.haptics)
	App.save_settings()
	_refresh()
	if App.settings.haptics:
		Input.vibrate_handheld(40)   # The sample, so the player feels that it is on.


func on_back() -> void:
	App.go(ControllerWait)
