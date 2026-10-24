extends RefCounted
## The look of Freeze Dance (REQ-FD-12): a dark hall seen from the edge of a stage, a mirror ball, a floor in perspective with
## white light tiles, and simple dancers. The world is drawn on the pixel layer in screen units; `size.x / 480` is one world
## pixel. The pictures of the dancers are made from shapes when the game starts (`dancer_image()`), one pixel of a picture is
## `scale` world pixels.

const Shell = preload("res://scripts/game/shell.gd")
const DanceRules = preload("res://scripts/game/freeze_dance/dance_rules.gd")

const OUTLINE := Color("0c0814")
const SKIN := Color("ffd6aa")
const HALL := Color("0a061a")
const WALL := Color("0e0824")
const TILE_DARK := [Color("121022"), Color("181630")]
const TILE_LINE := Color("08061a")
const TILE_LIT := Color("f5f5eb")
const TILE_LIT_EDGE := Color("ffffff")
const STAGE := Color("1e1410")
const STAGE_LIP := Color("966e3c")
const SPEAKER := Color("121216")
const SPEAKER_CONE := Color("282830")
const BALL := Color("d2d2e1")
const BALL_LINE := Color("828296")
const BALL_GLINT := Color.WHITE
const IMG := Vector2i(14, 20)   # The picture of a dancer, in pixels of the picture.
## The design is a 320x180 picture (one unit is 1.5 world pixels): the rows of the floor (the top of each row), and the number
## of units per column at a height. Rows run from the horizon to under the bottom of the screen.
const DESIGN := Vector2(320.0, 180.0)
const ROW_TOPS := [50.0, 58.0, 68.0, 80.0, 95.0, 114.0, 138.0, 168.0, 200.0]
const HORIZON_Y := 28.0
const COL_WIDTH := 0.30
const BALL_POS := Vector2(160.0, 34.0)   # Units of the design.
const BALL_R := 9.0

## Where the dancers stand, for 1 to 4 players: the middle of the feet in units of the design, and the size of a pixel of the
## picture in world pixels (far ones 2, near ones 3). The first place is for the first player in the slot order.
const PLACES := [
	[],
	[Vector3(160.0, 132.0, 3.0)],
	[Vector3(104.0, 130.0, 3.0), Vector3(216.0, 130.0, 3.0)],
	[Vector3(72.0, 108.0, 2.0), Vector3(160.0, 134.0, 3.0), Vector3(248.0, 108.0, 2.0)],
	[Vector3(70.0, 105.0, 2.0), Vector3(125.0, 132.0, 3.0), Vector3(195.0, 105.0, 2.0), Vector3(250.0, 132.0, 3.0)],
]


## The place of dancer `index` of `count`, in screen units for a screen of `area`: `x`, `y` (the feet) and `scale`.
static func place(index: int, count: int, area: Vector2) -> Dictionary:
	var p: Vector3 = PLACES[clampi(count, 1, 4)][clampi(index, 0, clampi(count, 1, 4) - 1)]
	return {"x": p.x / DESIGN.x * area.x, "y": p.y / DESIGN.y * area.y, "scale": int(p.z)}


## The picture of a dancer: a head with a cap in `color`, two dots for the eyes and a mouth, a body in `color`, two arms and two
## legs, a black outline. `pose` is 0 (arms down), 1 (left arm up) or 2 (right arm up). `dim` is the dancer on the bench.
static func dancer_image(color: Color, pose: int, dim := false) -> Image:
	var img := Image.create(IMG.x, IMG.y, false, Image.FORMAT_RGBA8)
	var c := color
	var skin := SKIN
	if dim:
		c = Color(color.r / 3.0, color.g / 3.0, color.b / 3.0)
		skin = Color(0.35, 0.3, 0.26)
	_rect(img, 4, 9, 6, 9, OUTLINE)
	_rect(img, 5, 10, 4, 7, c)
	_rect(img, 4, 18, 2, 2, OUTLINE)
	_rect(img, 8, 18, 2, 2, OUTLINE)
	_rect(img, 3, 0, 8, 9, OUTLINE)
	_rect(img, 4, 1, 6, 7, skin)
	_rect(img, 5, 3, 1, 2, OUTLINE)
	_rect(img, 8, 3, 1, 2, OUTLINE)
	_rect(img, 6, 6, 2, 1, OUTLINE)
	var left_y := 5 if pose == 1 else 10
	var right_y := 5 if pose == 2 else 10
	_rect(img, 2, left_y, 2, 4, c)
	_rect(img, 10, right_y, 2, 4, c)
	_rect(img, 3, 0, 8, 2, c)   # The cap.
	return img


static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), color)


## Draws a dancer: `tex` is its picture, `feet` the middle of its feet, `s` pixels of the world for one pixel of the picture.
static func draw_dancer(ci: CanvasItem, tex: Texture2D, feet: Vector2, s: int, wp: float) -> Rect2:
	var dest := Rect2(Vector2(feet.x - float(IMG.x) * 0.5 * s * wp, feet.y - float(IMG.y) * s * wp),
			Vector2(float(IMG.x) * s * wp, float(IMG.y) * s * wp))
	dest.position = Shell.snap(dest.position)
	ci.draw_texture_rect(tex, dest, false)
	return dest


# ---- The hall ----

## The corners of tile (`row`, `col`) of the floor in screen units: top left, top right, bottom right, bottom left.
## `col` runs from -8 to 7 (column 0 and -1 touch the middle line of the screen).
static func tile_corners(row: int, col: int, area: Vector2) -> PackedVector2Array:
	var y0: float = ROW_TOPS[row]
	var y1: float = ROW_TOPS[row + 1]
	var w0 := (y0 - HORIZON_Y) * COL_WIDTH
	var w1 := (y1 - HORIZON_Y) * COL_WIDTH
	var k := Vector2(area.x / DESIGN.x, area.y / DESIGN.y)
	var cx := DESIGN.x * 0.5
	return PackedVector2Array([Vector2((cx + float(col) * w0) * k.x, y0 * k.y),
			Vector2((cx + float(col + 1) * w0) * k.x, y0 * k.y), Vector2((cx + float(col + 1) * w1) * k.x, y1 * k.y),
			Vector2((cx + float(col) * w1) * k.x, y1 * k.y)])


## The hall: the dark wall, the mirror ball and the floor with the lit tiles `lit` (see `DanceRules.lit_tiles()`).
## `bar` is the height of the HUD bar that covers the top of the screen.
static func draw_hall(ci: CanvasItem, area: Vector2, bar: float, lit: Dictionary, t: float) -> void:
	var k := Vector2(area.x / DESIGN.x, area.y / DESIGN.y)
	ci.draw_rect(Rect2(Vector2.ZERO, area), HALL)
	ci.draw_rect(Rect2(0.0, bar, area.x, float(ROW_TOPS[0]) * k.y - bar), WALL)
	for row in DanceRules.ROWS:
		for col in range(-8, 8):
			var cell := Vector2i(row, col + 8)
			var corners := tile_corners(row, col, area)
			var color: Color = TILE_DARK[(row + col) & 1]
			if lit.has(cell):
				color = TILE_LIT
			ci.draw_colored_polygon(corners, color)
			ci.draw_line(corners[0], corners[3], TILE_LINE, 2.0)
		ci.draw_line(Vector2(0.0, float(ROW_TOPS[row]) * k.y), Vector2(area.x, float(ROW_TOPS[row]) * k.y), TILE_LINE, 2.0)
	_draw_ball(ci, area, t)


static func _draw_ball(ci: CanvasItem, area: Vector2, t: float) -> void:
	var k := area.x / DESIGN.x
	var c := Shell.snap(Vector2(BALL_POS.x * k, BALL_POS.y * area.y / DESIGN.y))
	var r := BALL_R * k
	ci.draw_rect(Rect2(c.x - 2.0, 0.0, 4.0, c.y - r), BALL_LINE)
	ci.draw_circle(c, r + Shell.WORLD_PIXEL, OUTLINE)
	ci.draw_circle(c, r, BALL)
	for i in range(-2, 3):   # The squares of the ball.
		ci.draw_line(c + Vector2(float(i) * r * 0.4, -r), c + Vector2(float(i) * r * 0.4, r), BALL_LINE, 2.0)
		ci.draw_line(c + Vector2(-r, float(i) * r * 0.4), c + Vector2(r, float(i) * r * 0.4), BALL_LINE, 2.0)
	var glint := floori(t * 2.0) % 3   # A glint that moves in 3 steps.
	ci.draw_rect(Rect2(c + Vector2(-r * 0.5 + float(glint) * r * 0.35, -r * 0.5), Vector2.ONE * Shell.WORLD_PIXEL * 2.0), BALL_GLINT)


## The lip of the stage at the bottom of the screen and a speaker on each side.
static func draw_stage(ci: CanvasItem, area: Vector2) -> void:
	var k := Vector2(area.x / DESIGN.x, area.y / DESIGN.y)
	ci.draw_rect(Rect2(0.0, 166.0 * k.y, area.x, 14.0 * k.y), STAGE)
	ci.draw_rect(Rect2(0.0, 164.0 * k.y, area.x, 2.0 * k.y), STAGE_LIP)
	for x in [4.0, 296.0]:
		ci.draw_rect(Rect2(x * k.x, 150.0 * k.y, 22.0 * k.x, 30.0 * k.y), SPEAKER)
		ci.draw_rect(Rect2((x + 4.0) * k.x, 156.0 * k.y, 14.0 * k.x, 14.0 * k.y), SPEAKER_CONE)
