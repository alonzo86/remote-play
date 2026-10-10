extends StyleBox
## The double frame of an arcade panel (docs/TV_FLOW.md, REQ-FL-38): a `line` px outer line, `line` px of black, and a
## `line` px inner line. The inside is filled with `fill`. The edges are square. The content margins include the frame.

var outer_color := Color("fcfcfc")
var inner_color := Color("0058f8")
var fill := Color.BLACK
var line := 6


## `padding` is the space between the frame and the content, in pixels.
func setup(line_px: int, padding: int, fill_color: Color, outer: Color, inner: Color) -> StyleBox:
	line = line_px
	fill = fill_color
	outer_color = outer
	inner_color = inner
	set_content_margin_all(float(line * 3 + padding))
	return self


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var gap := Color.BLACK
	var layers: Array = [[0, outer_color], [1, gap], [2, inner_color], [3, fill]]
	for l in layers:
		var r := rect.grow(-float(line * int(l[0])))
		if r.size.x > 0.0 and r.size.y > 0.0:
			RenderingServer.canvas_item_add_rect(to_canvas_item, r, l[1])


## The widths of the rings from the outside in (a test checks them): the outer line, the black gap, the inner line.
func rings() -> Array[int]:
	return [line, line, line]
