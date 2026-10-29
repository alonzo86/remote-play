extends RefCounted
## The pictures of Air Hockey (REQ-AH-20): a white table with dark gray rails on a black floor, red and blue lines, mallets in
## the slot colors and a black puck (the look of the approved mock, 2026-10-23). Everything is drawn in the pixel view with shapes
## in 1920x1080 units; one world pixel is `Shell.WORLD_PIXEL` (4) units.

const Sim = preload("res://scripts/game/air_hockey/air_hockey_sim.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const FLOOR := UiTheme.BG          # Black around the table, like the other games (owner, 2026-10-29).
const SURFACE := Color("f6f8fc")
const RAIL := Color("000000")      # Outlines of the mallets and the puck.
const RAIL_GRAY := Color("4a4e5e")  # The rails of the table: dark gray, so they show on the black floor (owner, 2026-10-29).
const SILVER := Color("b0b6c4")
const LINE_RED := Color("d62828")
const LINE_BLUE := Color("1e46c8")
const SHADOW_SURFACE := Color("bec2ce")   # A shadow on the white surface.
const BOT_COLOR := Color("a678e6")  # ROBO: a color that no phone slot has (REQ-AH-15).
const RAIL_W := 24.0
const CORNER := 64.0
const LINE_W := 4.0                 # One world pixel.
const MID_DASH := 24.0

const MARK_FACE_DX := 240.0         # The face-off circles: this far from the goal line and from the middle (up and down).
const MARK_FACE_DY := 240.0
const MARK_FACE_R := 48.0
const BLUE_LINE_DX := 420.0         # The blue lines are this far from the goal lines.
const CREASE_R := 136.0
const CENTER_R := 104.0


## The floor, the table and its lines.
static func draw_table(ci: CanvasItem, area: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, area), FLOOR)
	var rink := Sim.RINK
	var c := rink.get_center()
	ci.draw_style_box(_box(RAIL_GRAY, CORNER + RAIL_W), rink.grow(RAIL_W))
	ci.draw_style_box(_box(SURFACE, CORNER), rink)
	for seat in 2:
		var gx := Sim.goal_x(seat)
		var s := 1.0 if seat == 0 else -1.0
		ci.draw_line(Vector2(gx + s * BLUE_LINE_DX, rink.position.y + 8.0), Vector2(gx + s * BLUE_LINE_DX, rink.end.y - 8.0),
				LINE_BLUE, LINE_W * 2.0)
		var from := -PI * 0.5 if seat == 0 else PI * 0.5
		ci.draw_arc(Vector2(gx, c.y), CREASE_R, from, from + PI, 40, LINE_BLUE, LINE_W * 2.0)
		for dy in [-MARK_FACE_DY, MARK_FACE_DY]:
			var m := Vector2(gx + s * MARK_FACE_DX, c.y + dy)
			ci.draw_arc(m, MARK_FACE_R, 0.0, TAU, 32, LINE_RED, LINE_W)
			ci.draw_rect(Rect2(m - Vector2(LINE_W, LINE_W), Vector2(LINE_W * 2.0, LINE_W * 2.0)), LINE_RED)
		var opening := Rect2(gx - (RAIL_W if seat == 0 else 0.0), c.y - Sim.GOAL_H * 0.5, RAIL_W, Sim.GOAL_H)
		ci.draw_rect(opening, FLOOR)   # The goal opening in the rail.
		ci.draw_rect(Rect2(Vector2(c.x - s * MARK_FACE_DX - LINE_W, c.y - LINE_W), Vector2(LINE_W * 2.0, LINE_W * 2.0)), LINE_RED)
	var y := rink.position.y + 16.0
	while y < rink.end.y - 16.0:   # The dashed red middle line.
		ci.draw_rect(Rect2(c.x - LINE_W, y, LINE_W * 2.0, MID_DASH), LINE_RED)
		y += MID_DASH * 2.0
	ci.draw_arc(c, CENTER_R, 0.0, TAU, 48, LINE_BLUE, LINE_W * 2.0)
	ci.draw_rect(Rect2(c - Vector2(LINE_W, LINE_W) * 1.5, Vector2(LINE_W, LINE_W) * 3.0), LINE_RED)
	for corner in [rink.position, Vector2(rink.end.x, rink.position.y), Vector2(rink.position.x, rink.end.y), rink.end]:
		_cap(ci, rink, corner)


## A silver cap on a corner of the rail.
static func _cap(ci: CanvasItem, rink: Rect2, corner: Vector2) -> void:
	var cx := corner.x + (CORNER if corner.x <= rink.position.x else -CORNER)
	var cy := corner.y + (CORNER if corner.y <= rink.position.y else -CORNER)
	var from := 0.0
	if corner.x <= rink.position.x:
		from = PI if corner.y <= rink.position.y else PI * 0.5
	else:
		from = PI * 1.5 if corner.y <= rink.position.y else 0.0
	ci.draw_arc(Vector2(cx, cy), CORNER + RAIL_W * 0.5, from, from + PI * 0.5, 12, SILVER, 12.0)


static func _box(color: Color, radius: float) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(int(radius))
	return b


## A mallet seen from above: a black outline, a base in the slot color with a darker lower edge, a groove, a raised knob with a
## shine and a soft shadow (the mock of 2026-10-23). `pos` is the middle; the outline is `Sim.PADDLE_R` wide.
static func draw_paddle(ci: CanvasItem, pos: Vector2, color: Color) -> void:
	var r := Sim.PADDLE_R
	var dark := color.darkened(0.38)
	var light := color.lightened(0.4)
	ci.draw_circle(pos + Vector2(10.0, 28.0), r, SHADOW_SURFACE)
	ci.draw_circle(pos, r, RAIL)
	ci.draw_circle(pos, r * 0.9, dark)
	ci.draw_circle(pos - Vector2(4.0, 4.0), r * 0.88, color)
	ci.draw_circle(pos, r * 0.62, RAIL)
	ci.draw_circle(pos, r * 0.56, dark)
	ci.draw_circle(pos, r * 0.52, RAIL)
	ci.draw_circle(pos, r * 0.46, color)
	ci.draw_circle(pos - Vector2(4.0, 4.0), r * 0.40, light)
	ci.draw_rect(Rect2(pos + Vector2(-r * 0.26, -r * 0.26), Vector2(8.0, 8.0)), Color.WHITE)
	ci.draw_rect(Rect2(pos + Vector2(-r * 0.12, -r * 0.36), Vector2(8.0, 4.0)), Color.WHITE)


## The puck: black, with a dark bevel ring, a darker top face, a small shine and a soft shadow.
static func draw_puck(ci: CanvasItem, pos: Vector2) -> void:
	var r := Sim.PUCK_R
	ci.draw_circle(pos + Vector2(4.0, 14.0), r, SHADOW_SURFACE)
	ci.draw_circle(pos, r, RAIL)
	ci.draw_circle(pos, r * 0.78, Color("34364a"))
	ci.draw_circle(pos, r * 0.56, Color("0e0e14"))
	ci.draw_rect(Rect2(pos + Vector2(-r * 0.5, -r * 0.4), Vector2(8.0, 8.0)), Color("c8cddc"))
	ci.draw_rect(Rect2(pos + Vector2(-r * 0.25, -r * 0.62), Vector2(12.0, 4.0)), Color("c8cddc"))
