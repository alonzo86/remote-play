extends GridContainer
## The track list of the marble race (REQ-MR-53): 10 fixed tracks and "Random track", as tiles with a line sketch. The D-pad
## moves over the tiles, OK selects one. Like a `ChoiceRow` it has a `row` (the row of the registry), a `value` and a signal.

const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")
const TrackTile = preload("res://scripts/ui/track_tile.gd")

signal changed(value: String)

const COLUMNS_PER_ROW := 6

var row := {}
var value := ""
var tiles: Array[Button] = []


func _ready() -> void:
	columns = COLUMNS_PER_ROW
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 12)
	for i in row.values.size():
		var t: Button = TrackTile.new()
		t.value = String(row.values[i])
		t.title = String(row.titles[i])
		if i < MarbleTrack.FIXED_SEEDS.size():
			t.sketch = MarbleTrack.generate(MarbleTrack.FIXED_SEEDS[i]).points
		t.selected = t.value == value
		t.pressed.connect(set_value.bind(t.value, true))
		add_child(t)
		tiles.append(t)


## Selects a tile. `notify` is true when the user did it.
func set_value(v: String, notify := false) -> void:
	value = v
	for t in tiles:
		t.selected = t.value == v
	if notify:
		changed.emit(v)
