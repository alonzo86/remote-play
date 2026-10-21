extends RefCounted
## The look of Sumo Bumpers (REQ-SB-15): Sky Island. A round grass island floats in a pixel sky with drifting clouds. Its edge is
## a ring that turns red as the island shrinks, and a brown cliff hangs below it. The bumpers are penguins in the player colors.
## Everything is drawn in screen units on the pixel layer (one world pixel is `Shell.WORLD_PIXEL` units).

const Shell = preload("res://scripts/game/shell.gd")

const PX := Shell.WORLD_PIXEL   # One world pixel in screen units.
const CELL := 24.0            # A square of the grass chess pattern: 6 world pixels.
const OUTLINE := Color("101018")
const SKY_TOP := Color("5eb8f0")
const SKY_BOTTOM := Color("b4e4f8")
const SKY_BANDS := 8
const CLOUD := Color("fcfcfc")
const CLOUD_SHADE := Color("d4eafa")
const GRASS_A := Color("58b838")
const GRASS_B := Color("4eaa30")
const GRASS_LINE := Color("3c8c28")   # The two rings on the grass.
const RIM := Color("b0804e")           # The edge of the island. It turns `DANGER` as the island shrinks.
const DANGER := Color("ff5a4d")
const CLIFF := Color("96694a")
const CLIFF_SHADE := Color("785238")
const CLIFF_DEPTH := 0.17             # The cliff hangs this share of the radius below the island.
const BELLY := Color("fcfcfc")
const BEAK := Color("ffa01e")
## The clouds: x and y in the 480x270 view, the width in world pixels, and the drift speed in world pixels per second.
const CLOUDS := [[30.0, 40.0, 16, 2.0], [130.0, 34.0, 16, 3.0], [240.0, 60.0, 14, 2.5], [330.0, 36.0, 18, 2.0],
		[400.0, 120.0, 16, 2.0], [20.0, 170.0, 14, 3.0], [350.0, 200.0, 16, 2.5], [90.0, 230.0, 12, 2.0]]
const VIEW_W := 480.0
const GRASS_FLECKS := [Vector2(-0.45, -0.3), Vector2(0.3, -0.15), Vector2(-0.2, 0.5), Vector2(0.5, 0.4), Vector2(-0.6, 0.15)]

## A penguin: 8x8 sprite pixels, each drawn 2x2 world pixels, so 16x16 before the outline. `k` is the body (player color),
## `w` the belly, `o` beak and feet, `e` an eye (white, with a pupil that looks to one side).
const PENGUIN := [
	"..kkkk..",
	".kkkkkk.",
	".kekekk.",
	".kkookk.",
	"kkwwwwkk",
	"kkwwwwkk",
	".kwwwwk.",
	"..o..o..",
]
const SCALE := 2


## The sky: bands of blue from the top to the bottom of `area`.
static func draw_sky(ci: CanvasItem, area: Vector2) -> void:
	var h := ceilf(area.y / float(SKY_BANDS))
	for i in SKY_BANDS:
		ci.draw_rect(Rect2(0.0, h * i, area.x, h + 1.0), SKY_TOP.lerp(SKY_BOTTOM, float(i) / float(SKY_BANDS - 1)))


## Where the cloud `i` is after `t` seconds, in world pixels: it drifts to the right and comes back on the left.
static func cloud_x(i: int, t: float) -> float:
	var c: Array = CLOUDS[i]
	var span := VIEW_W + float(c[2]) * 2.0
	return fposmod(float(c[0]) + t * float(c[3]), span) - float(c[2])


static func draw_clouds(ci: CanvasItem, t: float) -> void:
	for i in CLOUDS.size():
		var c: Array = CLOUDS[i]
		var x := roundf(cloud_x(i, t)) * PX
		var y := float(c[1]) * PX
		var w := float(c[2]) * PX
		ci.draw_rect(Rect2(x, y + 2.0 * PX, w, 3.0 * PX), CLOUD)
		ci.draw_rect(Rect2(x + 3.0 * PX, y, w - 6.0 * PX, 2.0 * PX), CLOUD)
		ci.draw_rect(Rect2(x, y + 5.0 * PX, w, PX), CLOUD_SHADE)


## The color of the island edge for a danger level (0 full island, 1 smallest): it turns red when the island is small.
static func rim_color(danger: float) -> Color:
	return RIM.lerp(DANGER, clampf(danger * 1.6 - 0.3, 0.0, 1.0))


## The island with its cliff: the middle `c`, the radius `r` of the grass edge, and how far it has shrunk (`danger`).
static func draw_island(ci: CanvasItem, c: Vector2, r: float, danger: float) -> void:
	var drop := Vector2(0.0, snappedf(r * CLIFF_DEPTH, PX))
	ci.draw_circle(c + drop, r + PX, OUTLINE)
	ci.draw_circle(c + drop, r, CLIFF)
	ci.draw_circle(c + drop * 0.55, r, CLIFF_SHADE)
	ci.draw_circle(c, r + PX, OUTLINE)
	ci.draw_circle(c, r, rim_color(danger))
	var g := r - 3.0 * PX   # The grass is inside the edge ring.
	if g <= 0.0:
		return
	ci.draw_circle(c, g, GRASS_A)
	# The chess pattern is on the grid of the screen, so the squares do not move while the island shrinks: the edge eats them.
	var from := Vector2(floorf((c.x - g) / CELL), floorf((c.y - g) / CELL))
	var n := int(ceilf(2.0 * g / CELL)) + 1
	for iy in n:
		for ix in n:
			var gx := int(from.x) + ix
			var gy := int(from.y) + iy
			if (gx + gy) % 2 != 0:
				continue
			var cell := Rect2(float(gx) * CELL, float(gy) * CELL, CELL, CELL)
			if _inside(cell, c, g - PX):
				ci.draw_rect(cell, GRASS_B)
	for f in [0.66, 0.33]:
		ci.draw_arc(c, g * f, 0.0, TAU, 48, GRASS_LINE, PX)
	for fl in GRASS_FLECKS:
		var p: Vector2 = Shell.snap(c + fl * g)
		if p.distance_to(c) < g - 2.0 * PX:
			ci.draw_rect(Rect2(p, Vector2.ONE * PX), Color("f8e878") if fl.x < 0.0 else Color("f8b8d8"))


## True when the whole of `cell` is inside the circle (`c`, `r`).
static func _inside(cell: Rect2, c: Vector2, r: float) -> bool:
	for corner in [cell.position, cell.position + Vector2(cell.size.x, 0.0), cell.position + Vector2(0.0, cell.size.y), cell.end]:
		if corner.distance_to(c) > r:
			return false
	return true


## The picture of a penguin in `color`. `step` is -1, 0 or 1: the side the pupils look to (0: outward). With a one-pixel outline.
static func penguin_image(color: Color, step: int) -> Image:
	var w := PENGUIN[0].length() * SCALE
	var h := PENGUIN.size() * SCALE
	var src := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var colors := {"k": color, "w": BELLY, "o": BEAK, "e": Color.WHITE}
	var eye_no := 0
	for y in PENGUIN.size():
		for x in PENGUIN[y].length():
			var ch: String = PENGUIN[y][x]
			if not colors.has(ch):
				continue
			src.fill_rect(Rect2i(x * SCALE, y * SCALE, SCALE, SCALE), colors[ch])
			if ch == "e":
				var px := 0 if (step < 0 or (step == 0 and eye_no == 0)) else SCALE - 1
				src.set_pixel(x * SCALE + px, y * SCALE + SCALE - 1, OUTLINE)
				eye_no += 1
	return _outlined(src)


static func _outlined(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(1, 1))
	var painted := out.duplicate() as Image
	for y in h + 2:
		for x in w + 2:
			if painted.get_pixel(x, y).a > 0.0:
				continue
			for n in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
				if n.x >= 0 and n.y >= 0 and n.x < w + 2 and n.y < h + 2 and painted.get_pixelv(n).a > 0.0:
					out.set_pixel(x, y, OUTLINE)
					break
	return out
