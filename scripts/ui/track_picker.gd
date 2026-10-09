extends ScrollContainer
## The track gallery of the marble race (REQ-MR-53): one line of tiles that scrolls sideways, like an image gallery. A tile is
## the line sketch of a fixed track, the last one is a question mark (the random track). There are no names. The D-pad moves
## over the tiles and the line follows the focus, OK selects one. Like a `ChoiceRow` it has a `row` (the row of the registry),
## a `value` and a signal.

const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")
const TrackTile = preload("res://scripts/ui/track_tile.gd")

signal changed(value: String)

## The visible width: 5 tiles and a part of the next one, so that the line is seen to go on.
const VIEW_W := 760.0
const GAP := 12
const EDGE := 16   # Room around the tiles for the shadow and the focus border.

var row := {}
var value := ""
var tiles: Array[Button] = []


func _ready() -> void:
	custom_minimum_size = Vector2(VIEW_W, TrackTile.SIZE.y + EDGE * 2.0)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, EDGE)
	add_child(pad)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", GAP)
	pad.add_child(line)
	for i in row.values.size():
		var t: Button = TrackTile.new()
		t.value = String(row.values[i])
		if i < MarbleTrack.FIXED_SEEDS.size():
			t.sketch = MarbleTrack.generate(MarbleTrack.FIXED_SEEDS[i]).points
		t.selected = t.value == value
		t.pressed.connect(set_value.bind(t.value, true))
		line.add_child(t)
		tiles.append(t)
	_show_selected.call_deferred()


## Selects a tile. `notify` is true when the user did it.
func set_value(v: String, notify := false) -> void:
	value = v
	for t in tiles:
		t.selected = t.value == v
	if notify:
		changed.emit(v)


## Scrolls the line so that the selected tile is seen (when the view opens with an earlier choice).
func _show_selected() -> void:
	for t in tiles:
		if t.selected:
			ensure_control_visible(t)
