extends Control
## A pixel pencil, 8 x 8 cells, for the Edit button of the player on the Connect screen. The phone shows an icon and not the word
## EDIT, so the word needs no Hebrew text and the button is small. Rows run from the top; a cell is a color or empty.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const GRID := 8
## The icon sits on a black button (issue #173, 2026-11-02): the body is white, the tip gray and the eraser red.
const ROWS := [
	".....ee#",
	"....bbbe",
	"...bbbb.",
	"..bbbb..",
	".bbbb...",
	".tbb....",
	"tt......",
	"tt......",
]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The cells of the pencil as {x, y, color}. A test reads it, and `_draw()` paints it.
static func cells() -> Array:
	var out: Array = []
	for y in ROWS.size():
		for x in String(ROWS[y]).length():
			var palette := {"b": UiTheme.BUTTON_TEXT, "t": UiTheme.BUTTON_EDGE, "e": UiTheme.BAD, "#": UiTheme.TEXT_DIM}
			var color = palette.get(String(ROWS[y])[x])
			if color != null:
				out.append({"x": x, "y": y, "color": color})
	return out


func _draw() -> void:
	var cell := floorf(minf(size.x, size.y) / float(GRID))
	var origin := (size - Vector2(cell, cell) * GRID) / 2.0
	for c in cells():
		draw_rect(Rect2(origin + Vector2(c.x, c.y) * cell, Vector2(cell, cell)), c.color)
