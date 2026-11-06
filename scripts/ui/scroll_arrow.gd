extends Control
## A pixel arrow that tells a scrolling list has more rows above or below (REQ-FL-12a). It blinks like a prompt (REQ-FL-42), keeps
## its place when it is off, and is drawn as a stack of rects, so it is sharp at any size.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const CELL := 4   # One pixel of the arrow.
const SLACK := 20.0   # See more_below().
const ROWS := 6   # The arrow is 11 pixels wide at its base and ROWS pixels high.

## True when the arrow points up.
var up := false
## True when there is more to scroll in the direction of the arrow.
var active := false
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2((2 * ROWS - 1) * CELL, ROWS * CELL)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Whether the arrow shows now: there is more to scroll and the blink is on.
func is_lit() -> bool:
	return active and UiTheme.blink_on(_time)


## Whether a scroll box with the scroll position `value`, a visible height `page` and a content height `total` has more below.
## `SLACK` px of the end count as the end: the last row is fully visible while the 16 px padding of the grid is not.
static func more_below(value: float, page: float, total: float) -> bool:
	return value + page < total - SLACK


## Whether the same box has more above.
static func more_above(value: float) -> bool:
	return value > SLACK


## The rectangles of the arrow, one for each pixel row, inside a box that is `width` px wide. The tip (the narrowest row) is at
## the top of an up arrow and at the bottom of a down arrow.
static func rects(is_up: bool, width: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in ROWS:
		var w := (2 * r + 1) * CELL
		var y := (r if is_up else ROWS - 1 - r) * CELL
		out.append(Rect2((width - w) / 2.0, y, w, CELL))
	return out


func _draw() -> void:
	if not is_lit():
		return
	for rect in rects(up, size.x):
		draw_rect(rect, UiTheme.ACCENT)
