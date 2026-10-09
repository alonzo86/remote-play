extends RefCounted
## The floor of Paint Grab (REQ-PG-2, 4, 5, 21): a grid of square tiles. A tile has no color or the slot of the player that
## painted it last. Pure logic: it draws nothing. Positions are in px of the floor (the top left corner is 0, 0).

const NONE := -1

## What `paint()` did: nothing changed, a free tile was painted, or the tile of another player was taken.
enum Result { SAME, NEW, TAKEN }

var cols := 0
var rows := 0
var tile := 100.0
var owners := PackedInt32Array()   # The slot that painted the tile, or NONE. One value for each tile, row after row.

var _counts := {}                  # slot -> number of its tiles, kept up to date by paint().


func _init(p_cols := 16, p_rows := 9, p_tile := 100.0) -> void:
	cols = p_cols
	rows = p_rows
	tile = p_tile
	owners.resize(cols * rows)
	owners.fill(NONE)


func size() -> Vector2:
	return Vector2(cols * tile, rows * tile)


## The cell under a point of the floor, or (-1, -1) when the point is outside.
func cell_at(p: Vector2) -> Vector2i:
	var c := Vector2i(floori(p.x / tile), floori(p.y / tile))
	return c if c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows else Vector2i(-1, -1)


func owner_of(c: Vector2i) -> int:
	return owners[c.y * cols + c.x]


## `slot` paints the tile `c`. The tile has one color at a time (REQ-PG-4).
func paint(c: Vector2i, slot: int) -> Result:
	var i := c.y * cols + c.x
	var before := owners[i]
	if before == slot:
		return Result.SAME
	owners[i] = slot
	_counts[slot] = int(_counts.get(slot, 0)) + 1
	if before != NONE:
		_counts[before] = int(_counts[before]) - 1
	return Result.NEW if before == NONE else Result.TAKEN


## The number of tiles of a slot.
func count(slot: int) -> int:
	return int(_counts.get(slot, 0))


func total() -> int:
	return cols * rows


## The share of the floor that has the color of a slot, in percent, rounded down (REQ-PG-21).
func percent(slot: int) -> int:
	return count(slot) * 100 / total()
