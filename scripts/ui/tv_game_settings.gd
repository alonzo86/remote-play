extends Control
## The settings view of a game (REQ-GM-90 to 95), shown after the tile and before the game: a centered column with the
## name of the game, one row for each setting (Difficulty first), Start, and Back at the bottom. The rows come from
## `GameSettings`; a choice is drawn by `ChoiceRow`. Start gives the chosen values to the game as props (REQ-GM-93).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Registry = preload("res://scripts/game/registry.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")
const ChoiceRow = preload("res://scripts/ui/choice_row.gd")
const TrackPicker = preload("res://scripts/ui/track_picker.gd")

## Set by `App.go_game_settings()` before the screen enters the tree.
var game_id := ""

var game := {}
var rows: Array[Control] = []   # The row controls: a choice row or a track list.
var start_button: Button
var back_button: Button


func _ready() -> void:
	game = Registry.find(game_id)
	var m := UiKit.margin(self, 0, 60, 0, 60)
	var center := CenterContainer.new()
	m.add_child(center)
	var box := VBoxContainer.new()
	# No fixed width: the column is as wide as its widest row. The rows and the Back and Start line have that width (REQ-GM-90).
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	var title := UiKit.title(String(game.get("title", "")), 84)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UiKit.spacer(12))
	for r in GameSettings.rows_for(game):
		var row: Control = TrackPicker.new() if r.get("type", "") == "tracks" else ChoiceRow.new()
		row.row = r
		row.size_flags_horizontal = Control.SIZE_FILL
		row.value = GameSettings.value(game, r)
		row.changed.connect(func(v: String): GameSettings.set_value(game, r, v))
		box.add_child(row)
		rows.append(row)
	box.add_child(UiKit.spacer(10))
	# Back and Start are on one line at the bottom, spaced to the two edges of the view: Back on the left, Start on the right
	# (REQ-GM-90). Start is wide and green, Back is smaller and plain.
	var line := HBoxContainer.new()
	box.add_child(line)
	back_button = UiKit.button("Back", on_back, false, 32, true)
	back_button.custom_minimum_size = Vector2(200, 88)
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(back_button)
	line.add_child(UiKit.spacer(0, true))
	start_button = UiKit.button("Start", start, true, 44)
	start_button.custom_minimum_size = Vector2(300, 100)
	line.add_child(start_button)
	# Down from the last row goes to Start, not to Back, and Up from both goes to that row.
	var last: Control = rows[-1]
	last.focus_neighbor_bottom = last.get_path_to(start_button)
	start_button.focus_neighbor_top = start_button.get_path_to(last)
	back_button.focus_neighbor_top = back_button.get_path_to(last)
	UiKit.focus_later(rows[0])


func start() -> void:
	var script := Registry.load_script(game_id)
	if script != null:
		App.go(script, GameSettings.props_for(game))


func on_back() -> void:
	App.go_games()
