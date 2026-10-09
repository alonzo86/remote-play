extends Button
## One tile of the track gallery (REQ-MR-53): a line sketch of the middle line of a track, without a name. The random track
## has a question mark instead of a sketch. The selected tile is green and has a check mark.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const SIZE := Vector2(130.0, 170.0)
const PAD := 16.0

var value := ""
var sketch: Array[Vector2] = []   # The points of the track (x, z). Empty for the random tile.
var selected := false:
	set(v):
		selected = v
		theme_type_variation = "PrimaryButton" if v else "LightButton"
		if _art != null:
			_art.queue_redraw()

var _art: Control


func _ready() -> void:
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	theme_type_variation = "PrimaryButton" if selected else "LightButton"
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.draw.connect(_draw_art)


## Where the sketch points go inside `area`: the track is scaled to fit and centered, and keeps its shape.
static func fit(points: Array[Vector2], area: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if points.is_empty():
		return out
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var span := (hi - lo).max(Vector2(0.001, 0.001))
	var k := minf(area.size.x / span.x, area.size.y / span.y)
	var offset := area.get_center() - (lo + hi) * 0.5 * k
	for p in points:
		out.append(p * k + offset)
	return out


func _draw_art() -> void:
	var area := Rect2(PAD, PAD, SIZE.x - PAD * 2.0, SIZE.y - PAD * 2.0)
	if sketch.is_empty():
		_art.draw_string(UiTheme.title_font(), Vector2(0.0, area.get_center().y + 34.0), "?", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 100,
				UiTheme.CARD_TEXT)
	else:
		var pts := PackedVector2Array(fit(sketch, area))
		_art.draw_polyline(pts, UiTheme.OUTLINE, 9.0, true)
		_art.draw_polyline(pts, Color.WHITE, 4.0, true)
		_art.draw_circle(pts[0], 8.0, UiTheme.OUTLINE)
		_art.draw_circle(pts[0], 5.0, UiTheme.OK)
	if selected:   # A check mark in a white disc, top right.
		var c := Vector2(SIZE.x - 22.0, 22.0)
		_art.draw_circle(c, 15.0, UiTheme.OUTLINE)
		_art.draw_circle(c, 12.0, Color.WHITE)
		_art.draw_polyline(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-1, 5), c + Vector2(7, -5)]), UiTheme.OUTLINE, 3.5, true)
