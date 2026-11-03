extends Control
## A pixel "enter" arrow (the return arrow of a keyboard), for the JOIN button of the phone Connect screen. The button shows the
## icon and not the word JOIN. The cells are white, as the text of every enabled button (REQ-FL-38a). Rows run from the top.
## In a right to left layout (Hebrew) the arrow is mirrored: it points to the right and its tail is at the left.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const ROWS := [
	"........ww..",
	"........ww..",
	"..w.....ww..",
	".ww.....ww..",
	"wwwwwwwwww..",
	"wwwwwwwwww..",
	".ww.........",
	"..w.........",
]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
		queue_redraw()


## The cells of the arrow as {x, y, color}, mirrored left to right when `mirrored`. A test reads it, and `_draw()` paints it.
static func cells(mirrored := false) -> Array:
	var out: Array = []
	for y in ROWS.size():
		var cols := String(ROWS[y]).length()
		for x in cols:
			if String(ROWS[y])[x] == "w":
				out.append({"x": cols - 1 - x if mirrored else x, "y": y, "color": UiTheme.BUTTON_TEXT})
	return out


func _draw() -> void:
	var cols := String(ROWS[0]).length()
	var cell := floorf(minf(size.x / float(cols), size.y / float(ROWS.size())))
	var origin := (size - Vector2(cols, ROWS.size()) * cell) / 2.0
	for c in cells(is_layout_rtl()):
		draw_rect(Rect2(origin + Vector2(c.x, c.y) * cell, Vector2(cell, cell)), c.color)
