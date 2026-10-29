extends RefCounted
## The look of Bumper Cars (REQ-BC-16): the Fun Fair. A steel rink with black rubber rails under a red and white tent, gold stars
## on the floor, and cars with a black tyre bumper, a glossy body, a seat, a steering wheel and a pole with a blue spark.
## Everything is drawn in screen units on the pixel layer (one world pixel is `Shell.WORLD_PIXEL` units).

const Shell = preload("res://scripts/game/shell.gd")
const Minigame = preload("res://scripts/game/minigame.gd")

const PX := Shell.WORLD_PIXEL
const CELL := 24.0                 # A square of the floor: 6 world pixels.
const OUTLINE := Color("101018")
const BACKDROP := Color("181028")
const FLOOR_A := Color("a6acba")
const FLOOR_B := Color("b0b6c4")
const FLOOR_SPECK := Color("c4cad8")
const RING_RED := Color("ff463c")
const RING_WHITE := Color("fcfcfc")
const RAIL := Color("1e1e28")
const REFLECTOR := Color("fcfcfc")
const TENT_RED := Color("ff463c")
const TENT_WHITE := Color("fcfcfc")
const STAR_GOLD := Color("ffd640")
const STAR_SHINE := Color("fff4b0")
const SHADOW := Color("646a7a")
const TYRE := Color("343440")
const TYRE_SHINE := Color("606070")
const TYRE_TREAD := Color("222230")
const SEAT := Color("242434")
const SEAT_EDGE := Color("3c3c54")
const CHROME := Color("d2d6e4")
const LIGHT := Color("fffabe")
const SPARK := Color("96dcff")
const TENT_TOP := Minigame.HUD_BAR_H  # The tent starts under the black bar of the HUD.
const TENT_STRIPE := 40.0           # The width of a stripe: 10 world pixels.
const TENT_BODY := 64.0             # The height of the straight part of the roof, then the scallops.
const TENT_SCALLOP := 24.0
const RAIL_W := 16.0                # The rubber rail outside the rink: 4 world pixels.
const REFLECTOR_STEP := 64.0
const SHADOW_OFFSET := Vector2(2.0, 2.0)   # In world pixels: down and to the right.
const CAR_SIZE := Vector2i(28, 20)
## A star, 9x8 pixels: `y` is gold and `s` the shine.
const STAR := [
	"....y....",
	"....y....",
	"...yys...",
	"yyyyyyyyy",
	".yyyyyyy.",
	"..yyyyy..",
	"..yy.yy..",
	".y.....y.",
]
## The sparks that flicker at the top of the pole: offsets in world pixels, three groups.
const SPARKS := [
	[Vector2(0, -2), Vector2(-1, -4), Vector2(1, -5)],
	[Vector2(1, -2), Vector2(-2, -3), Vector2(0, -6)],
	[Vector2(-1, -3), Vector2(2, -4), Vector2(0, -2)],
]
const DIR_RIGHT := 0
const DIR_LEFT := 1
const DIR_DOWN := 2
const DIR_UP := 3


static func draw_backdrop(ci: CanvasItem, area: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, area), BACKDROP)


## The tent roof: stripes of red and white and a row of scallops, from the bar of the HUD down towards the rink.
static func draw_tent(ci: CanvasItem, width: float) -> void:
	var n := int(ceilf(width / TENT_STRIPE))
	for i in n:
		var x := float(i) * TENT_STRIPE
		var color := TENT_RED if i % 2 == 0 else TENT_WHITE
		ci.draw_rect(Rect2(x, TENT_TOP, TENT_STRIPE, TENT_BODY), color)
		# The scallop under the stripe: three steps that get narrower.
		for step in 3:
			var inset := float(step) * PX
			var y := TENT_TOP + TENT_BODY + float(step) * (TENT_SCALLOP / 3.0)
			ci.draw_rect(Rect2(x + inset, y, TENT_STRIPE - 2.0 * inset, TENT_SCALLOP / 3.0), color)
	ci.draw_rect(Rect2(0.0, TENT_TOP - PX, width, PX), OUTLINE)


## The rail and the floor of a rink. The squares are on the grid of the rink, so the edge cuts the last ones.
static func draw_rink(ci: CanvasItem, rink: Rect2) -> void:
	var outer := rink.grow(RAIL_W)
	ci.draw_rect(outer.grow(PX), OUTLINE)
	ci.draw_rect(outer, RAIL)
	var x := outer.position.x + REFLECTOR_STEP * 0.5
	while x < outer.end.x - REFLECTOR_STEP * 0.5:
		ci.draw_rect(Rect2(x, outer.position.y + PX, 2.0 * REFLECTOR_STEP * 0.25, 2.0 * PX), REFLECTOR)
		ci.draw_rect(Rect2(x, outer.end.y - 3.0 * PX, 2.0 * REFLECTOR_STEP * 0.25, 2.0 * PX), REFLECTOR)
		x += REFLECTOR_STEP
	var y := outer.position.y + REFLECTOR_STEP * 0.5
	while y < outer.end.y - REFLECTOR_STEP * 0.5:
		ci.draw_rect(Rect2(outer.position.x + PX, y, 2.0 * PX, 2.0 * REFLECTOR_STEP * 0.25), REFLECTOR)
		ci.draw_rect(Rect2(outer.end.x - 3.0 * PX, y, 2.0 * PX, 2.0 * REFLECTOR_STEP * 0.25), REFLECTOR)
		y += REFLECTOR_STEP
	ci.draw_rect(rink, FLOOR_A)
	var cols := int(ceilf(rink.size.x / CELL))
	var rows := int(ceilf(rink.size.y / CELL))
	for iy in rows:
		for ix in cols:
			var cell := Rect2(rink.position + Vector2(float(ix), float(iy)) * CELL, Vector2(CELL, CELL)).intersection(rink)
			if (ix + iy) % 2 == 1:
				ci.draw_rect(cell, FLOOR_B)
			if (ix + iy) % 5 == 0 and cell.size.x >= CELL and cell.size.y >= CELL:
				ci.draw_rect(Rect2(cell.position + Vector2(2.0, 2.0) * PX, Vector2(PX, PX)), FLOOR_SPECK)
	var c := rink.get_center()
	var r := minf(rink.size.x, rink.size.y) * 0.22
	ci.draw_arc(c, r, 0.0, TAU, 64, RING_RED, PX)
	ci.draw_arc(c, r - 2.0 * PX, 0.0, TAU, 64, RING_WHITE, PX)


# ---- Stars ----

static func star_image() -> Image:
	var w: int = STAR[0].length()
	var h: int = STAR.size()
	var src := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var ch: String = STAR[y][x]
			if ch == "y":
				src.set_pixel(x, y, STAR_GOLD)
			elif ch == "s":
				src.set_pixel(x, y, STAR_SHINE)
	return _outlined(src)


# ---- Cars ----

## The picture of a car in `color` that faces `dir` (DIR_RIGHT, DIR_LEFT, DIR_DOWN or DIR_UP).
static func car_image(color: Color, dir: int) -> Image:
	var img := _car_right(color)
	match dir:
		DIR_LEFT:
			img.flip_x()
		DIR_DOWN:
			img.rotate_90(CLOCKWISE)
		DIR_UP:
			img.rotate_90(COUNTERCLOCKWISE)
	return img


## The shadow of a car: the same shape in one dark color (REQ-BC-16).
static func shadow_image(car: Image) -> Image:
	var out := Image.create(car.get_width(), car.get_height(), false, Image.FORMAT_RGBA8)
	for y in car.get_height():
		for x in car.get_width():
			if car.get_pixel(x, y).a > 0.0:
				out.set_pixel(x, y, SHADOW)
	return out


## The way a car faces for a velocity: the larger axis wins. A car that stands keeps the way it faced (`current`).
static func facing(vel: Vector2, current: int) -> int:
	if vel.length() < 40.0:
		return current
	if absf(vel.x) >= absf(vel.y):
		return DIR_RIGHT if vel.x > 0.0 else DIR_LEFT
	return DIR_DOWN if vel.y > 0.0 else DIR_UP


## Where the pole of a car stands, in world pixels from the middle of the car, for a facing: at the back.
static func pole_offset(dir: int) -> Vector2:
	match dir:
		DIR_LEFT:
			return Vector2(8, -1)
		DIR_DOWN:
			return Vector2(0, -8)
		DIR_UP:
			return Vector2(0, 8)
	return Vector2(-8, -1)


## The blue spark at the top of the pole: three pixels that change 12 times a second. `t` is seconds, `seed_value` a number
## of the car.
static func draw_spark(ci: CanvasItem, at: Vector2, t: float, seed_value: int) -> void:
	var group: Array = SPARKS[(int(t * 12.0) + seed_value) % SPARKS.size()]
	for o in group:
		ci.draw_rect(Rect2(Shell.snap(at + (o as Vector2) * PX), Vector2(PX, PX)), SPARK)


## The spark of a hit: eight white dots that fly out of `at` in 0.25 s. `age` is the seconds since the hit.
static func draw_hit(ci: CanvasItem, at: Vector2, age: float) -> void:
	var t := clampf(age / 0.25, 0.0, 1.0)
	var r := (2.0 + 6.0 * t) * PX
	for i in 8:
		var a := TAU * float(i) / 8.0
		ci.draw_rect(Rect2(Shell.snap(at + Vector2(cos(a), sin(a)) * r), Vector2(PX, PX)), Color.WHITE if t < 0.7 else STAR_SHINE)


static func _car_right(color: Color) -> Image:
	var img := Image.create(CAR_SIZE.x, CAR_SIZE.y, false, Image.FORMAT_RGBA8)
	var hi := color.lerp(Color.WHITE, 0.55)
	var mid := color.lerp(Color.WHITE, 0.2)
	var lo := color.lerp(Color.BLACK, 0.35)
	_rrect(img, Rect2i(0, 0, 28, 20), 8, OUTLINE)            # The outline and the tyre bumper.
	_rrect(img, Rect2i(1, 1, 26, 18), 7, TYRE)
	for x in range(3, 26, 3):                                 # The tread marks.
		img.set_pixel(x, 1, TYRE_SHINE)
		img.set_pixel(x, 18, TYRE_TREAD)
	for y in range(4, 17, 3):
		img.set_pixel(1, y, TYRE_SHINE)
		img.set_pixel(26, y, TYRE_TREAD)
	img.fill_rect(Rect2i(4, 2, 19, 1), TYRE_SHINE)
	_rrect(img, Rect2i(4, 4, 20, 12), 5, color)               # The body.
	img.fill_rect(Rect2i(7, 5, 14, 2), hi)                    # The gloss.
	img.fill_rect(Rect2i(6, 13, 16, 2), lo)                   # The shade.
	img.fill_rect(Rect2i(4, 9, 20, 2), mid)                   # The racing stripe.
	img.fill_rect(Rect2i(5, 9, 18, 1), Color.WHITE)
	_rrect(img, Rect2i(7, 6, 7, 8), 2, SEAT)                  # The seat, with its back.
	img.fill_rect(Rect2i(7, 6, 2, 8), SEAT_EDGE)
	img.fill_rect(Rect2i(14, 8, 2, 4), CHROME)                # The steering wheel.
	img.set_pixel(14, 8, SEAT_EDGE)
	img.fill_rect(Rect2i(24, 6, 1, 2), LIGHT)                 # The two headlights.
	img.fill_rect(Rect2i(24, 12, 1, 2), LIGHT)
	img.fill_rect(Rect2i(25, 8, 2, 4), CHROME)                # The chrome nose.
	img.fill_rect(Rect2i(5, 9, 1, 2), CHROME)                 # The foot of the pole.
	return img


## A filled rectangle with round corners of radius `r`.
static func _rrect(img: Image, rect: Rect2i, r: int, color: Color) -> void:
	for y in rect.size.y:
		for x in rect.size.x:
			var dx := maxi(maxi(r - x, x - (rect.size.x - 1 - r)), 0)
			var dy := maxi(maxi(r - y, y - (rect.size.y - 1 - r)), 0)
			if dx * dx + dy * dy <= r * r + r / 2:
				img.set_pixel(rect.position.x + x, rect.position.y + y, color)


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
