extends Control
## The track carousel of The Amazing Race (REQ-MR-53): the tracks in one line like an image carousel. The track in the middle,
## in focus and bigger, is the selected one and has a yellow border; the others get smaller and fainter toward the sides.
## A tile is the line sketch of a fixed track, the last one is a question mark (the random track). There are no names.
## With the focus, Left and Right on the remote move the line by one track (it stops at the ends, REQ-GM-92). Like a
## `ChoiceRow` it has a `row` (the row of the registry), a `value` and a signal. It draws everything itself, so the tiles
## are not buttons.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")

signal changed(value: String)

const VIEW := Vector2(640.0, 230.0)
const TILE := Vector2(150.0, 170.0)    # The tile in the middle.
const SPACING := 140.0                 # The distance between the middle of two tiles (the first neighbours, before the scale).
const SHRINK := 0.28                   # The size lost by a tile one place away from the middle. Two places: twice that.
const SLIDE_S := 0.16
const FOCUS_W := 6

var row := {}
var value := ""
var index := 0          # The selected track: its place in `row.values`.
var tiles: Array[Dictionary] = []   # {value, sketch (points of the track, empty for the random track)}

var _pos := 0.0         # Where the line is while it slides (the index, between two numbers when it moves).
var _tween: Tween
var _sb_tile: StyleBoxFlat
var _sb_selected: StyleBoxFlat
var _sb_focus: StyleBoxFlat
var _veils := {}        # The veil style for each fade step (made once, not in every draw).


func _ready() -> void:
	custom_minimum_size = VIEW
	focus_mode = Control.FOCUS_ALL
	_sb_tile = UiTheme.card(Color.WHITE, UiTheme.TEXT_DIM, 6)
	_sb_selected = UiTheme.card(Color.WHITE, UiTheme.SELECTED, 6)   # REQ-GM-97: the choice has a yellow border.
	_sb_focus = UiTheme.card(Color(1, 1, 1, 0), UiTheme.TEXT, FOCUS_W)   # The focus: a white frame around the yellow one.
	for i in row.values.size():
		var sketch: Array = []
		if i < MarbleTrack.FIXED_SEEDS.size():
			sketch = MarbleTrack.generate(MarbleTrack.FIXED_SEEDS[i]).points
		tiles.append({"value": String(row.values[i]), "sketch": sketch})
	index = maxi(row.values.find(value), 0)
	_pos = float(index)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Selects the track `v` (the view opens with the last choice). `notify` is true when the user did it.
func set_value(v: String, notify := false) -> void:
	var i: int = row.values.find(v)
	if i < 0:
		return
	_go_to(i, notify)


## Moves the line by `delta` tracks. It stops at the first and the last.
func move(delta: int) -> void:
	_go_to(clampi(index + delta, 0, tiles.size() - 1), true)


func _go_to(i: int, notify: bool) -> void:
	var changed_now := i != index
	index = i
	value = String(tiles[i].value)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_slide, _pos, float(i), SLIDE_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if changed_now and notify:
		changed.emit(value)


func _slide(p: float) -> void:
	_pos = p
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		move(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		move(1)
		accept_event()


## Where the sketch points go inside `area`: the track is scaled to fit and centered, and keeps its shape.
static func fit(points: Array, area: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if points.is_empty():
		return out
	var lo: Vector2 = points[0]
	var hi: Vector2 = points[0]
	for p: Vector2 in points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var span := (hi - lo).max(Vector2(0.001, 0.001))
	var k := minf(area.size.x / span.x, area.size.y / span.y)
	var offset := area.get_center() - (lo + hi) * 0.5 * k
	for p: Vector2 in points:
		out.append(p * k + offset)
	return out


## The size factor of a tile `d` places from the middle of the line (d can be between two numbers while it slides).
static func scale_at(d: float) -> float:
	return maxf(1.0 - SHRINK * absf(d), 0.3)


## The x of the middle of a tile `d` places from the middle of the line, relative to the middle of the view.
static func x_at(d: float) -> float:
	var sign_d := signf(d)
	var a := absf(d)
	# The first place is SPACING away. Further tiles come closer together, because they are smaller.
	return sign_d * (minf(a, 1.0) * SPACING + maxf(a - 1.0, 0.0) * SPACING * 0.78)


func _draw() -> void:
	if tiles.is_empty():
		return
	var mid := Vector2(size.x * 0.5, VIEW.y * 0.5)   # The carousel can be wider than VIEW: the middle is the middle of the control.
	# Far tiles first, so that the middle one is on top.
	var order: Array[int] = []
	for i in tiles.size():
		if absf(float(i) - _pos) < 3.0:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return absf(float(a) - _pos) > absf(float(b) - _pos))
	for i in order:
		_draw_tile(i, float(i) - _pos, mid)
	if has_focus():
		var sc := scale_at(0.0)
		draw_style_box(_sb_focus, Rect2(mid - Vector2(0.0, 14.0) - TILE * sc * 0.5, TILE * sc).grow(FOCUS_W))
	# The dots under the line: one for each track, the selected one is big.
	var dot_gap := 22.0
	var x0 := mid.x - dot_gap * (tiles.size() - 1) * 0.5
	for i in tiles.size():
		var near := i == index
		var dot_color := UiTheme.SELECTED if near else UiTheme.TEXT_DIM
		var half := 8.0 if near else 5.0
		draw_rect(Rect2(Vector2(x0 + dot_gap * i, VIEW.y - 14.0) - Vector2(half, half), Vector2(half, half) * 2.0), dot_color)


func _draw_tile(i: int, d: float, mid: Vector2) -> void:
	var sc := scale_at(d)
	var size := TILE * sc
	var center := Vector2(mid.x + x_at(d), mid.y - 14.0)
	var rect := Rect2(center - size * 0.5, size)
	var fade := clampf(1.0 - (absf(d) - 1.0) * 0.45, 0.25, 1.0) if absf(d) > 1.0 else lerpf(1.0, 0.75, absf(d))
	var near_mid := absf(d) < 0.5
	var box := _sb_selected if near_mid else _sb_tile
	draw_style_box(box, rect)
	var sketch: Array = tiles[i].sketch
	var line_color := Color(UiTheme.OUTLINE, fade)
	if sketch.is_empty():
		draw_string(UiTheme.font(), Vector2(rect.position.x, center.y + 36.0 * sc), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x,
				int(96.0 * sc / 8.0) * 8, line_color)
	else:
		var pts := PackedVector2Array(fit(sketch, rect.grow(-16.0 * sc)))
		draw_polyline(pts, line_color, 9.0 * sc, false)
		draw_polyline(pts, Color(Color.WHITE, fade), 4.0 * sc, false)
		draw_rect(Rect2(pts[0] - Vector2(8.0, 8.0) * sc, Vector2(16.0, 16.0) * sc), line_color)
		draw_rect(Rect2(pts[0] - Vector2(5.0, 5.0) * sc, Vector2(10.0, 10.0) * sc), Color(UiTheme.OK, fade))
	if fade < 1.0:   # A veil of the background color: the tiles at the sides are fainter.
		draw_style_box(_veil(1.0 - fade), rect)


func _veil(a: float) -> StyleBoxFlat:
	var step := roundi(a * 20.0)
	if not _veils.has(step):
		_veils[step] = UiTheme.card(Color(UiTheme.BG, step / 20.0), Color(0, 0, 0, 0), 0)
	return _veils[step]
