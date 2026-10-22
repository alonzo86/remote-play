extends Control
## The settings view of a game (REQ-GM-90 to 95), shown after the tile and before the game: a centered column with the
## name of the game, one row for each setting (Difficulty first), Start, and Back at the bottom. The rows come from
## `GameSettings`; a choice is drawn by `ChoiceRow`. Start gives the chosen values to the game as props (REQ-GM-93).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Registry = preload("res://scripts/game/registry.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")
const SlotList = preload("res://scripts/ui/slot_list.gd")
const ChoiceRow = preload("res://scripts/ui/choice_row.gd")
const TrackPicker = preload("res://scripts/ui/track_picker.gd")

## Set by `App.go_game_settings()` before the screen enters the tree.
var game_id := ""

var game := {}
var rows: Array[Control] = []   # The row controls: a choice row or a track list.
var start_button: Button
var back_button: Button
var slot_list: VBoxContainer   # Who plays this game, IN or OUT (issue #76, REQ-GM-104); hidden with one phone.
var how_to_label: Label   # How to play (REQ-GM-103).
var reason_label: Label   # Why Start does not work now (REQ-GM-20): not enough phones. Empty when it works.


func _ready() -> void:
	game = Registry.find(game_id)
	var m := UiKit.margin(self, 0, 60, 0, 60)
	var center := CenterContainer.new()
	m.add_child(center)
	var box := VBoxContainer.new()
	# No fixed width: the column is as wide as its widest row. The rows and the Back and Start line have that width (REQ-GM-90).
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	var title := UiKit.title(String(game.get("title", "")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	# How to play: the text of the game under the name, for the whole room (issue #77, REQ-GM-103).
	how_to_label = UiKit.label(String(game.get("how_to", "")), UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	how_to_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how_to_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(how_to_label)
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
	# (REQ-GM-90). Back is a quiet item.
	var line := HBoxContainer.new()
	box.add_child(line)
	back_button = UiKit.item("common.back", on_back, UiTheme.SIZE_ITEM, "quiet")
	line.add_child(back_button)
	line.add_child(UiKit.spacer(0, true))
	start_button = UiKit.item("game_settings.start", start)
	line.add_child(start_button)
	# Down from the last row goes to Start, not to Back, and Up from both goes to that row.
	var last: Control = rows[-1]
	last.focus_neighbor_bottom = last.get_path_to(start_button)
	start_button.focus_neighbor_top = start_button.get_path_to(last)
	back_button.focus_neighbor_top = back_button.get_path_to(last)
	if bool(game.get("swing", false)):
		# The safety line of a swing game, always shown (issue #79, REQ-GM-102): the whole room reads it.
		var safety := UiKit.label("swing.tv_line", UiTheme.SIZE_BODY, UiTheme.TEXT)
		safety.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		safety.autowrap_mode = TextServer.AUTOWRAP_WORD
		safety.custom_minimum_size = Vector2(900, 0)
		box.add_child(safety)
	slot_list = SlotList.new()
	slot_list.choices = true
	slot_list.row_height = 48
	box.add_child(slot_list)
	reason_label = UiKit.label("", UiTheme.SIZE_BODY, UiTheme.ACCENT)
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(reason_label)
	_update_fit()
	UiKit.focus_later(rows[0])


func _process(_delta: float) -> void:
	_update_fit()


## Start works only when the connected phones fit the game (REQ-GM-20): a phone can leave while the view is open.
func _update_fit() -> void:
	# Only the players that are IN count (issue #76); the list shows who is IN or OUT when two or more phones are here.
	var n: int = App.server.players_in().size()
	slot_list.visible = App.server.connected_slots().size() >= 2
	var fits := Registry.accepts(game, n)
	# A swing game waits until every phone has tapped OK on the safety card (issue #79).
	var waiting: bool = fits and not App.server.swing_pending().is_empty()
	start_button.disabled = not fits or waiting
	reason_label.text = Lang.t("game_settings.waiting_phones").to_upper() if waiting else (
			"" if fits else Registry.reason(game, n).to_upper())


func start() -> void:
	if not Registry.accepts(game, App.server.players_in().size()) or not App.server.swing_pending().is_empty():
		return
	var script := Registry.load_script(game_id)
	if script != null:
		App.go(script, GameSettings.props_for(game))


func on_back() -> void:
	App.go_games()
