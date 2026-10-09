extends Control
## The settings view of a game (REQ-GM-90 to 95), shown after the tile and before the game: a centered column with the
## name of the game, one row for each setting (Difficulty first), Start, and Back at the bottom. The rows come from
## `GameSettings`; a choice is drawn by `ChoiceRow`. Start gives the chosen values to the game as props (REQ-GM-93).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Registry = preload("res://scripts/game/registry.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")
const ChoiceRow = preload("res://scripts/ui/choice_row.gd")

## Set by `App.go_game_settings()` before the screen enters the tree.
var game_id := ""

var game := {}
var rows: Array[Button] = []
var start_button: Button
var back_button: Button


func _ready() -> void:
	game = Registry.find(game_id)
	var m := UiKit.margin(self, 0, 60, 0, 60)
	var center := CenterContainer.new()
	m.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1000, 0)
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	var title := UiKit.title(String(game.get("title", "")), 84)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UiKit.spacer(12))
	for r in GameSettings.rows_for(game):
		var row: Button = ChoiceRow.new()
		row.row = r
		row.value = GameSettings.value(game, r)
		row.changed.connect(func(v: String): GameSettings.set_value(game, r, v))
		box.add_child(row)
		rows.append(row)
	box.add_child(UiKit.spacer(10))
	start_button = UiKit.button("Start", start, true, 44)
	start_button.custom_minimum_size = Vector2(0, 100)
	box.add_child(start_button)
	box.add_child(UiKit.spacer(24)) # Back is apart from the options and at the bottom (REQ-GM-90).
	back_button = UiKit.button("Back", on_back, false, 32, true)
	back_button.custom_minimum_size = Vector2(240, 72)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back_button)
	UiKit.focus_later(rows[0])


func start() -> void:
	var script := Registry.load_script(game_id)
	if script != null:
		App.go(script, GameSettings.props_for(game))


func on_back() -> void:
	App.go_games()
