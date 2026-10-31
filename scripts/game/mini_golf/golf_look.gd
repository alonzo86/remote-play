extends RefCounted
## The pictures of Mini Golf (REQ-MG-16, docs/games/mini_golf.md): a small golf park seen from behind the tee, in a simple
## perspective. The ground, the walls, the lake with its bridge and the scenery of a hole are drawn once into a 480x270 picture
## (the pixel view of the game, REQ-GM-47a) and shown scaled; the golfer, the ball, the rocks, the barriers, the blades,
## the windmill and the flag are
## drawn each frame. The golfer has a white hat, white trousers and white shoes and a shirt in the slot color; the ball is
## always white; nothing on the course is white (the user, 2026-10-17). A point of the course (x across, z along, in the units
## of `golf_holes.gd`) is at `Geo.at()`, in screen units.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")
const Shell = preload("res://scripts/game/shell.gd")
const Palette = preload("res://scripts/game/palette.gd")

const W := 480
const H := 270
const HY := 88                    # The horizon, in picture pixels.
const SK := 0.95
const CX := 240
const GROUND_END := 230           # The ground goes to the bar of the players at the bottom of the screen.
const HUD_TOP := 28
const WALL_W := 0.14              # The width of a wall, in course units.
const WALL_H := 0.16
const BALL_MIN_R := 6.0           # The ball is at least this big (picture pixels), also far away (48 px across at 1080p).
const GOLFER_MIN := 0.42          # The golfer is at least this share of the near size, also far away.

const SKY := [Color("3cbcfc"), Palette.GOLF_SKY, Color("a4e4fc")]
const WHITE := Color("fcfcfc")
const HILL_FAR := Color("007800")
const HILL_NEAR := Palette.GOLF_GREEN
const TREE := Color("005800")
const LAWN_A := Color("98d838")
const LAWN_B := Color("8ccc30")
const FAIR_A := Color("58b800")
const FAIR_B := Color("4ca800")
const TEE_MAT := Color("009800")
const WOOD := Color("ac6418")
const WOOD_HI := Color("d8a868")
const WOOD_LO := Color("683808")
const FENCE := Color("d8ac6c")
const FENCE_LO := Color("a07038")
const WATER := Color("3cbcfc")
const WATER_DEEP := Color("0078f8")
const WATER_GLINT := Color("a4e4fc")
const STONE := Color("886840")
const STONE_LO := Color("604428")
const BUSH := Color("006800")
const BUSH_LO := Color("003800")
const BUSH_HI := Color("009800")
const RED := Palette.NES_RED
const GOLD := Color("f8b800")
const BRICK := Color("b4503c")
const OL := Color("181818")
const ROCK := Color("887868")
const ROCK_HI := Color("b8a898")
const ROCK_LO := Color("504438")
const STEEL := Color("a8b4c8")
const STEEL_LO := Color("5c6880")
const GRIP := Color("383838")
const SKIN := Color("fcbc94")
const HAIR := Color("784818")
const SHOE := Color("fcfcfc")

static var _base: Image
static var _hole_tex := {}        # hole number -> ImageTexture


## Where a point of the course is on the screen. `scale` is how many screen units a course unit is long there.
class Geo:
	var m := 4.0                  # Screen units for one picture pixel.

	func _init(size: Vector2) -> void:
		m = size.x / float(W)

	func py(z: float) -> float:
		return float(HY) + 100.0 / maxf(z, 0.05)

	func scale_at(z: float) -> float:
		return (py(z) - float(HY)) / SK

	## The screen place of the foot of a thing at (x, z).
	func at(p: Vector2) -> Vector2:
		return Vector2(float(CX) + p.x * scale_at(p.y), py(p.y)) * m

	## The ball radius in screen units.
	func ball_r(z: float) -> float:
		return maxf(BALL_MIN_R, Holes.BALL_R * scale_at(z)) * m


# ---- The picture of a hole ----

## The texture of a hole, made the first time it is asked for (REQ-MG-12).
static func hole_texture(n: int) -> ImageTexture:
	if not _hole_tex.has(n):
		_hole_tex[n] = ImageTexture.create_from_image(hole_image(Holes.hole(n)))
	return _hole_tex[n]


static func hole_image(h: Dictionary) -> Image:
	var img := _base_image().duplicate() as Image
	_paint_ground(img, h)
	_paint_scenery(img, h)
	_paint_bushes(img, h)
	return img


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < W and y >= 0 and y < H:
		img.set_pixel(x, y, c)


static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, H - 1) + 1):
		for x in range(maxi(x0, 0), mini(x1, W - 1) + 1):
			img.set_pixel(x, y, c)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (float(x) - cx) / maxf(rx, 0.5)
			var dy := (float(y) - cy) / maxf(ry, 0.5)
			if dx * dx + dy * dy <= 1.0:
				_px(img, x, y, c)


## The sky, the hills, the trees, the clubhouse and the fence: the same for every hole.
static func _base_image() -> Image:
	if _base != null:
		return _base
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(UiTheme.BG)
	for y in range(HUD_TOP, HY):
		img.fill_rect(Rect2i(0, y, W, 1), SKY[0] if y < 52 else SKY[1] if y < 70 else SKY[2])
	for c in [Vector3(60, 50, 28), Vector3(190, 58, 36), Vector3(330, 52, 30), Vector3(430, 46, 26)]:
		_rect(img, int(c.x - c.z / 2.0), int(c.y), int(c.x + c.z / 2.0), int(c.y) + 5, WHITE)
		_rect(img, int(c.x - c.z / 3.0), int(c.y) - 4, int(c.x + c.z / 4.0), int(c.y), WHITE)
	for x in W:
		var far := int(10.0 + 7.0 * sin(float(x) / 37.0) + 4.0 * sin(float(x) / 11.0))
		img.fill_rect(Rect2i(x, HY - far - 4, 1, far + 4), HILL_FAR)
		var near := int(5.0 + 3.0 * sin(float(x) / 19.0 + 1.0))
		img.fill_rect(Rect2i(x, HY - near, 1, near), HILL_NEAR)
	for tx in range(6, W, 26):
		var ty := HY - 6 - (tx * 7) % 5
		_rect(img, tx, ty - 8, tx + 8, ty, TREE)
		_rect(img, tx + 2, ty - 11, tx + 6, ty - 8, TREE)
		_rect(img, tx + 3, ty, tx + 5, ty + 3, WOOD_LO)
	for y in range(HY, GROUND_END + 30):
		for x in W:
			img.set_pixel(x, y, LAWN_A if (x / 4 + y / 4) % 2 == 0 else LAWN_B)
	_rect(img, 380, HY - 26, 430, HY - 6, BRICK)
	for i in 31:
		_rect(img, 374 + i * 2, HY - 27 - mini(i, 30 - i), 375 + i * 2, HY - 26, RED)
	_rect(img, 398, HY - 18, 410, HY - 6, WOOD_LO)
	_rect(img, 384, HY - 22, 392, HY - 14, WATER)
	_rect(img, 418, HY - 22, 426, HY - 14, WATER)
	for fx in range(0, W, 5):
		_rect(img, fx, HY - 4, fx + 2, HY + 1, FENCE)
	_rect(img, 0, HY - 2, W - 1, HY - 2, FENCE)
	_rect(img, 0, HY, W - 1, HY, FENCE_LO)
	# The sky: a hot air balloon and birds. The park: a Ferris wheel behind the hills and a string of flags on the fence.
	_ellipse(img, 285.0, 42.0, 11.0, 13.0, BALLOON[0])
	_ellipse(img, 285.0, 42.0, 4.0, 13.0, BALLOON[1])
	_ellipse(img, 285.0, 42.0, 11.0, 3.0, BALLOON[2])
	_line(img, 280.0, 54.0, 282.0, 61.0, OL)
	_line(img, 290.0, 54.0, 288.0, 61.0, OL)
	_rect(img, 281, 61, 289, 65, WOOD)
	for b in [Vector2(120, 40), Vector2(135, 36), Vector2(150, 42)]:
		_px(img, int(b.x) - 2, int(b.y), OL)
		_px(img, int(b.x) - 1, int(b.y) + 1, OL)
		_px(img, int(b.x), int(b.y), OL)
		_px(img, int(b.x) + 1, int(b.y) + 1, OL)
		_px(img, int(b.x) + 2, int(b.y), OL)
	var wheel := Vector2(88.0, 52.0)
	for i in 16:
		var a := TAU * float(i) / 16.0
		_line(img, wheel.x, wheel.y, wheel.x + cos(a) * 22.0, wheel.y + sin(a) * 22.0, FENCE_LO)
		_px(img, int(wheel.x + cos(a) * 22.0), int(wheel.y + sin(a) * 22.0), FENCE)
		var cab := Color.from_hsv(float(i % 4) / 4.0, 0.8, 0.95)
		_rect(img, int(wheel.x + cos(a) * 22.0) - 2, int(wheel.y + sin(a) * 22.0), int(wheel.x + cos(a) * 22.0) + 2,
				int(wheel.y + sin(a) * 22.0) + 3, cab)
	_line(img, wheel.x, wheel.y, wheel.x - 10.0, HY - 6.0, FENCE_LO)
	_line(img, wheel.x, wheel.y, wheel.x + 10.0, HY - 6.0, FENCE_LO)
	for fx in range(4, W, 8):
		var sag := int(2.0 * sin(float(fx) / 8.0 * PI))
		var flag := [RED, GOLD, FL_PINK, BALLOON[2]][(fx / 8) % 4] as Color
		_rect(img, fx, HY - 8 + sag, fx + 4, HY - 8 + sag, OL)
		_rect(img, fx + 1, HY - 7 + sag, fx + 3, HY - 6 + sag, flag)
		_rect(img, fx + 2, HY - 5 + sag, fx + 2, HY - 5 + sag, flag)
	_base = img
	return img


static func _in_union(list: Array, p: Vector2, grow: float) -> bool:
	for r in list:
		if (r as Rect2).grow(grow).has_point(p):
			return true
	return false


## The ground of a hole: for every picture row below the horizon the depth `z` is known, so every pixel is a point of the course.
static func _paint_ground(img: Image, h: Dictionary) -> void:
	var rects: Array = h.fairway
	var tee: Vector2 = h.tee
	for y in range(HY + 1, GROUND_END + 30):
		var z := 100.0 / float(y - HY)
		var s := float(y - HY) / SK
		for x in W:
			var wx := (float(x) - float(CX)) / s
			var p := Vector2(wx, z)
			if _in_union(rects, p, 0.0):
				img.set_pixel(x, y, _fairway_pixel(h, p, x, y, tee))
			elif _in_union(rects, p, WALL_W):
				img.set_pixel(x, y, WOOD_HI if _in_union(rects, p, 0.05) else WOOD)
	# The walls at the far edges of the ground stand up a little.
	for r in rects:
		var rr: Rect2 = r
		var far := rr.position.y + rr.size.y
		for i in 9:
			var wx := rr.position.x + rr.size.x * float(i) / 8.0
			if _in_union(rects, Vector2(wx, far + 0.05), 0.0):
				continue
			var a := Vector2(float(CX) + wx * (100.0 / far / SK), HY + 100.0 / far)
			var hgt := WALL_H * (100.0 / far / SK)
			_rect(img, int(a.x) - 3, int(a.y - hgt), int(a.x) + 3, int(a.y), WOOD)
			_rect(img, int(a.x) - 3, int(a.y - hgt), int(a.x) + 3, int(a.y - hgt), WOOD_HI)
	var cup: Vector2 = h.cup
	var cy := HY + 100.0 / cup.y
	var cs := (cy - HY) / SK
	_ellipse(img, float(CX) + cup.x * cs, cy, maxf(1.5, Holes.CUP_R * cs * 1.3), maxf(1.0, Holes.CUP_R * cs * 0.55), OL)


static func _fairway_pixel(h: Dictionary, p: Vector2, x: int, y: int, tee: Vector2) -> Color:
	var c := FAIR_A if int(p.y / 0.45) % 2 == 1 else FAIR_B
	if absf(p.x - tee.x) < 0.3 and absf(p.y - tee.y) < 0.18:
		c = TEE_MAT
	for r in h.water:
		var rr: Rect2 = r
		if not rr.has_point(p):
			continue
		var d := minf(p.y - rr.position.y, rr.end.y - p.y)
		c = WATER if d > 0.2 else WATER_DEEP
		if (int(p.y * 20.0) + int(p.x * 14.0)) % 5 == 0:
			c = WATER_GLINT
		if d < 0.07:
			c = STONE if (x + y) % 3 != 0 else STONE_LO
	for r in h.bridges:
		var br: Rect2 = r
		if not br.has_point(p):
			continue
		c = WOOD_HI if int(p.y / 0.07) % 2 == 0 else WOOD
		if minf(p.x - br.position.x, br.end.x - p.x) < 0.05:
			c = WOOD_LO
	return c


## Round bushes outside the walls, along both sides of the ground of the hole.
static func _paint_bushes(img: Image, h: Dictionary) -> void:
	var min_x := 99.0
	var max_x := -99.0
	var max_z := 0.0
	for r in h.fairway:
		var rr: Rect2 = r
		min_x = minf(min_x, rr.position.x)
		max_x = maxf(max_x, rr.end.x)
		max_z = maxf(max_z, rr.end.y)
	for zv in [1.0, 1.5, 2.1, 2.8, 3.6, 4.5, 5.5]:
		var z: float = zv
		if z > max_z:
			continue
		var y: float = HY + 100.0 / z
		var s: float = (y - HY) / SK
		for side in [-1.0, 1.0]:
			var x: float = float(CX) + (min_x - 0.45 if side < 0.0 else max_x + 0.45) * s
			_ellipse(img, x, y - 0.13 * s, 0.30 * s, 0.14 * s, BUSH_LO)
			_ellipse(img, x, y - 0.14 * s, 0.28 * s, 0.12 * s, BUSH)
			_ellipse(img, x - 0.06 * s, y - 0.18 * s, 0.14 * s, 0.05 * s, BUSH_HI)


# ---- The scenery ----

const FL_PINK := Color("f878f8")
const FL_PURPLE := Color("6844fc")
const LAMP := Color("383838")
const BALLOON := [Palette.NES_RED, Color("f8b800"), Color("0078f8")]


static func _line(img: Image, x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	var n := int(maxf(absf(x1 - x0), absf(y1 - y0))) + 1
	for i in n + 1:
		var f := float(i) / float(n)
		_px(img, int(lerpf(x0, x1, f)), int(lerpf(y0, y1, f)), c)


## A round tree with a trunk: `s` is the picture pixels of one course unit at its foot.
static func _tree(img: Image, x: float, y: float, s: float, fruit: Color) -> void:
	_rect(img, int(x - 0.07 * s), int(y - 0.55 * s), int(x + 0.07 * s), int(y), WOOD)
	_rect(img, int(x + 0.02 * s), int(y - 0.55 * s), int(x + 0.07 * s), int(y), WOOD_LO)
	_ellipse(img, x, y - 0.85 * s, 0.5 * s, 0.42 * s, BUSH_LO)
	_ellipse(img, x - 0.02 * s, y - 0.88 * s, 0.46 * s, 0.38 * s, BUSH)
	_ellipse(img, x - 0.14 * s, y - 1.0 * s, 0.2 * s, 0.14 * s, BUSH_HI)
	for i in 4:
		var fx := int(x + (float(i) - 1.5) * 0.2 * s)
		var fy := int(y - 0.8 * s - float(i % 2) * 0.15 * s)
		_rect(img, fx, fy, fx + 1, fy + 1, fruit)


static func _flowerbed(img: Image, x: float, y: float, s: float, seed_i: int) -> void:
	_ellipse(img, x, y - 0.06 * s, 0.42 * s, 0.1 * s, WOOD_LO)
	var cols := [RED, GOLD, FL_PINK, FL_PURPLE]
	for i in 7:
		var fx := x + (float(i) - 3.0) * 0.11 * s
		var fy := y - 0.09 * s - float((i * 3 + seed_i) % 3) * 0.04 * s
		_rect(img, int(fx), int(fy), int(fx), int(fy + 0.07 * s), BUSH)
		_rect(img, int(fx) - 1, int(fy) - 1, int(fx) + 1, int(fy) + 1, cols[(i + seed_i) % 4])


static func _bench(img: Image, x: float, y: float, s: float) -> void:
	_rect(img, int(x - 0.3 * s), int(y - 0.2 * s), int(x - 0.27 * s), int(y), LAMP)
	_rect(img, int(x + 0.27 * s), int(y - 0.2 * s), int(x + 0.3 * s), int(y), LAMP)
	_rect(img, int(x - 0.33 * s), int(y - 0.26 * s), int(x + 0.33 * s), int(y - 0.2 * s), WOOD_HI)
	_rect(img, int(x - 0.33 * s), int(y - 0.46 * s), int(x + 0.33 * s), int(y - 0.38 * s), WOOD)


static func _lamp(img: Image, x: float, y: float, s: float) -> void:
	_rect(img, int(x) - 1, int(y - 0.7 * s), int(x) + 1, int(y), LAMP)
	_ellipse(img, x, y - 0.76 * s, 0.08 * s, 0.08 * s, GOLD)


## Trees, flower beds, benches and lamps on the lawn on both sides of the course, far ones first. The course (and
## its bushes) are in the middle, so everything stands outside the widest part of the ground of the hole.
static func _paint_scenery(img: Image, h: Dictionary) -> void:
	var min_x := 99.0
	var max_x := -99.0
	for r in h.fairway:
		var rr: Rect2 = r
		min_x = minf(min_x, rr.position.x)
		max_x = maxf(max_x, rr.end.x)
	var zs := [7.5, 6.2, 5.0, 4.0, 3.2, 2.5, 2.0, 1.6, 1.25]
	for i in zs.size():
		var z: float = zs[i]
		var y: float = HY + 100.0 / z
		var s: float = (y - HY) / SK
		for side in [-1.0, 1.0]:
			var kind := (i * 2 + (0 if side < 0.0 else 1)) % 4
			var edge: float = (min_x - 0.9) if side < 0.0 else (max_x + 0.9)
			var x: float = float(CX) + (edge + side * 0.25 * float(i % 3)) * s
			match kind:
				0:
					_tree(img, x, y, s, RED if i % 2 == 0 else GOLD)
				1:
					_flowerbed(img, x, y, s, i)
				2:
					_bench(img, x, y, s)
				_:
					_lamp(img, x, y, s)


## Draws the picture of the hole over the whole view.
static func draw_ground(ci: CanvasItem, size: Vector2, n: int) -> void:
	ci.draw_texture_rect(hole_texture(n), Rect2(Vector2.ZERO, size), false)


# ---- Things on the course ----

static func draw_flag(ci: CanvasItem, geo: Geo, h: Dictionary, time: float) -> void:
	var foot := geo.at(h.cup)
	var sc := geo.scale_at(float(Vector2(h.cup).y)) * geo.m
	var top := foot - Vector2(0.0, 1.0 * sc)
	ci.draw_line(foot, top, GOLD, maxf(4.0, 0.03 * sc))
	var wave := sin(time * 5.0) * 0.04 * sc
	ci.draw_colored_polygon(PackedVector2Array([top, top + Vector2(0.5 * sc, 0.16 * sc + wave), top + Vector2(0.0, 0.34 * sc)]), RED)


## A boulder with a green patch of moss: the ball bounces off it.
static func draw_rock(ci: CanvasItem, geo: Geo, r: Vector3) -> void:
	var foot := geo.at(Vector2(r.x, r.y))
	var sc := geo.scale_at(r.y) * geo.m
	var rad := maxf(r.z * sc, 12.0)
	ci.draw_circle(foot, rad * 0.9, Color(0.0, 0.2, 0.0, 0.45))
	var c := foot - Vector2(0.0, rad * 0.65)
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		var wob := 1.0 + 0.08 * sin(float(i) * 2.3)
		pts.append(c + Vector2(cos(a) * rad * 1.05 * wob, sin(a) * rad * 0.8 * wob))
	ci.draw_colored_polygon(pts, ROCK)
	pts.append(pts[0])
	ci.draw_polyline(pts, OL, 4.0)
	ci.draw_circle(c + Vector2(rad * 0.3, rad * 0.2), rad * 0.4, ROCK_LO)
	ci.draw_circle(c + Vector2(-rad * 0.25, -rad * 0.2), rad * 0.45, ROCK_HI)
	ci.draw_circle(c + Vector2(-rad * 0.3, -rad * 0.55), rad * 0.2, BUSH_HI)
	ci.draw_circle(c + Vector2(-rad * 0.1, -rad * 0.6), rad * 0.15, BUSH)


## A box on the ground: a sliding barrier (red and gold stripes on wood) or, with `wall`, a brick wall. `rect` is its
## place now. The
## top, the front and the side that faces the middle of the view are drawn.
static func draw_box(ci: CanvasItem, geo: Geo, rect: Rect2, wall: bool) -> void:
	var h := 0.32
	var nl := Shell.snap(geo.at(Vector2(rect.position.x, rect.position.y)))
	var nr := Shell.snap(geo.at(Vector2(rect.end.x, rect.position.y)))
	var fl := Shell.snap(geo.at(Vector2(rect.position.x, rect.end.y)))
	var fr := Shell.snap(geo.at(Vector2(rect.end.x, rect.end.y)))
	var hn := Vector2(0.0, h * geo.scale_at(rect.position.y) * geo.m)
	var hf := Vector2(0.0, h * geo.scale_at(rect.end.y) * geo.m)
	ci.draw_colored_polygon(PackedVector2Array([nl, nr, fr, fl]), Color(0.0, 0.2, 0.0, 0.45))
	var left_side := rect.position.x + rect.size.x * 0.5 > 0.0
	var side := PackedVector2Array([nl, fl, fl - hf, nl - hn]) if left_side else PackedVector2Array([nr, fr, fr - hf, nr - hn])
	ci.draw_colored_polygon(side, ROCK_LO if wall else WOOD_LO)
	ci.draw_polyline(side + PackedVector2Array([side[0]]), OL, 4.0)
	var front := PackedVector2Array([nl, nr, nr - hn, nl - hn])
	ci.draw_colored_polygon(front, BRICK if wall else RED)
	if wall:
		for row in 3:
			var f := float(row + 1) / 4.0
			ci.draw_line(nl - hn * f, nr - hn * f, ROCK_LO, 3.0)
	else:
		var stripes := maxi(2, int(rect.size.x * 6.0))
		for i in stripes:
			if i % 2 == 0:
				var a := float(i) / float(stripes)
				var b := float(i + 1) / float(stripes)
				ci.draw_colored_polygon(PackedVector2Array([nl.lerp(nr, a), nl.lerp(nr, b), nl.lerp(nr, b) - hn,
						nl.lerp(nr, a) - hn]), GOLD)
	ci.draw_polyline(front + PackedVector2Array([front[0]]), OL, 4.0)
	var top := PackedVector2Array([nl - hn, nr - hn, fr - hf, fl - hf])
	ci.draw_colored_polygon(top, ROCK_HI if wall else WOOD_HI)
	ci.draw_polyline(top + PackedVector2Array([top[0]]), OL, 4.0)


## A turning blade: a bar on a post that turns, with red and gold halves (REQ-MG-10).
static func draw_spinner(ci: CanvasItem, geo: Geo, sp: Dictionary, time: float) -> void:
	var ends := Holes.spinner_ends(sp, time)
	var c: Vector2 = sp.c
	var sc := geo.scale_at(c.y) * geo.m
	var lift := Vector2(0.0, -0.22 * sc)
	var foot := Shell.snap(geo.at(c))
	ci.draw_line(foot, foot + lift, OL, maxf(10.0, 0.1 * sc))
	ci.draw_line(foot, foot + lift, WOOD, maxf(6.0, 0.06 * sc))
	var a := Shell.snap(geo.at(ends[0]) + lift * (geo.scale_at(float(Vector2(ends[0]).y)) / geo.scale_at(c.y)))
	var b := Shell.snap(geo.at(ends[1]) + lift * (geo.scale_at(float(Vector2(ends[1]).y)) / geo.scale_at(c.y)))
	var mid := foot + lift
	ci.draw_line(a, b, OL, maxf(14.0, 0.14 * sc))
	ci.draw_line(a, mid, RED, maxf(8.0, 0.09 * sc))
	ci.draw_line(mid, b, GOLD, maxf(8.0, 0.09 * sc))
	ci.draw_circle(mid, maxf(8.0, 0.08 * sc), WOOD_LO)


## The windmill stands on the first block of a hole that has one: a brown tower, a red roof and four gold blades that turn.
static func draw_windmill(ci: CanvasItem, geo: Geo, block: Rect2, time: float) -> void:
	var mid := Vector2(block.position.x + block.size.x * 0.5, block.position.y + block.size.y * 0.5)
	var foot := geo.at(mid)
	var sc := geo.scale_at(mid.y) * geo.m
	var hw := block.size.x * 0.5 * sc
	ci.draw_colored_polygon(PackedVector2Array([foot + Vector2(-hw, 0.0), foot + Vector2(hw, 0.0),
			foot + Vector2(hw * 0.6, -1.0 * sc), foot + Vector2(-hw * 0.6, -1.0 * sc)]), BRICK)
	ci.draw_colored_polygon(PackedVector2Array([foot + Vector2(-hw * 0.8, -1.0 * sc), foot + Vector2(hw * 0.8, -1.0 * sc),
			foot + Vector2(0.0, -1.3 * sc)]), RED)
	var hub := Shell.snap(foot + Vector2(0.0, -0.95 * sc))
	for i in 4:
		var a := time * 1.4 + TAU * float(i) / 4.0
		ci.draw_line(hub, hub + Vector2(cos(a), sin(a)) * 0.8 * sc, GOLD, maxf(4.0, 0.05 * sc))
	ci.draw_circle(hub, maxf(4.0, 0.06 * sc), WOOD_LO)


## The ball at `p`, always white, with a small shadow on the ground and a shine.
static func draw_ball(ci: CanvasItem, geo: Geo, p: Vector2, lift := 0.0) -> void:
	var foot := Shell.snap(geo.at(p))
	var r := geo.ball_r(p.y)
	Shell.record("ball", ci, Rect2(foot - Vector2(r, 2.0 * r), Vector2(2.0 * r, 2.0 * r)), {"color": WHITE})
	ci.draw_circle(foot, r * 0.9, Color(0.0, 0.2, 0.0, 0.5))
	var c := foot - Vector2(0.0, r + lift)
	ci.draw_circle(c, r + 4.0, OL)
	ci.draw_circle(c, r, WHITE)
	ci.draw_rect(Rect2(c + Vector2(r * 0.1, r * 0.15), Vector2(4.0, 4.0)), Color("bcbcbc"))


## The aim: a line of dots on the ground from the ball in `heading` that is `length` course units long (0 for no line), and a
## small mark at its end (REQ-MG-4, 13).
static func draw_aim(ci: CanvasItem, geo: Geo, from: Vector2, heading: float, length: float, locked: bool) -> void:
	var dir := Vector2(sin(heading), cos(heading))
	if length > 0.0:
		var steps := 9
		for i in range(1, steps + 1):
			var p := from + dir * length * float(i) / float(steps)
			if p.y < 0.8:
				continue
			var at := Shell.snap(geo.at(p) - Vector2(0.0, 4.0))
			var sz := maxf(8.0, 0.05 * geo.scale_at(p.y) * geo.m)
			ci.draw_rect(Rect2((at - Vector2(sz, sz) * 0.5), Vector2(sz, sz)), UiTheme.TEXT if i % 2 == 1 else GOLD)
	var end := from + dir * maxf(length, 0.6)
	var e := Shell.snap(geo.at(end))
	var sz2 := maxf(16.0, 0.12 * geo.scale_at(end.y) * geo.m)
	Shell.record("aim", ci, Rect2(e - Vector2(sz2 * 0.5, sz2 * 1.4), Vector2(sz2, sz2)),
			{"locked": locked, "color": GOLD if locked else UiTheme.TEXT})
	ci.draw_colored_polygon(PackedVector2Array([e + Vector2(0.0, -sz2 * 0.4), e + Vector2(-sz2 * 0.5, -sz2 * 1.4),
			e + Vector2(sz2 * 0.5, -sz2 * 1.4)]), GOLD if locked else UiTheme.TEXT)
	ci.draw_polyline(PackedVector2Array([e + Vector2(0.0, -sz2 * 0.4), e + Vector2(-sz2 * 0.5, -sz2 * 1.4),
			e + Vector2(sz2 * 0.5, -sz2 * 1.4), e + Vector2(0.0, -sz2 * 0.4)]), OL, 4.0)


## A splash of water drops at `p` (age in seconds): REQ-MG-9.
static func draw_splash(ci: CanvasItem, geo: Geo, p: Vector2, age: float) -> void:
	var foot := geo.at(p)
	var sc := geo.scale_at(p.y) * geo.m
	for i in 7:
		var a := TAU * float(i) / 7.0
		var d := Vector2(cos(a) * 0.18, -absf(sin(a)) * 0.25 - age * 0.3) * sc * (0.6 + age)
		ci.draw_rect(Rect2(foot + d - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), WATER_GLINT if i % 2 == 0 else WATER)


## Gold sparks around the cup: the ball is in (age in seconds).
static func draw_sparks(ci: CanvasItem, geo: Geo, p: Vector2, age: float) -> void:
	var foot := geo.at(p)
	var sc := geo.scale_at(p.y) * geo.m
	for i in 8:
		var a := TAU * float(i) / 8.0
		var d := Vector2(cos(a), sin(a) * 0.6 - 0.4) * (0.15 + age * 0.35) * sc
		ci.draw_rect(Rect2(foot + d - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), GOLD)


# ---- The golfer ----

## The poses of the golfer, the key pictures of a swing: the hands (picture pixels from the feet, at the full size), the club
## angle (degrees; 0 points to the right, 90 up), `ab` (1: the club head touches the ball, 0: the club is in the air) and `lean`
## (the upper body moves this far to the right).
enum Pose { ADDRESS, BACK, DOWN, HIT, FOLLOW, FINISH }
const POSES := {
	Pose.ADDRESS: {"hx": 4.0, "hy": -27.0, "a": -72.0, "ab": 1.0, "lean": 0.0},
	Pose.BACK: {"hx": 8.0, "hy": -40.0, "a": 42.0, "ab": 0.0, "lean": -3.0},
	Pose.DOWN: {"hx": 6.0, "hy": -33.0, "a": 5.0, "ab": 0.0, "lean": 0.0},
	Pose.HIT: {"hx": 4.0, "hy": -27.0, "a": -72.0, "ab": 1.0, "lean": 2.0},
	Pose.FOLLOW: {"hx": -5.0, "hy": -46.0, "a": 140.0, "ab": 0.0, "lean": 3.0},
	Pose.FINISH: {"hx": -8.0, "hy": -48.0, "a": 165.0, "ab": 0.0, "lean": 4.0},
}
const CLUB := 34.0
## How long the parts of the swing take, in seconds after the putt: down to the ball, through, up, and back to the address.
const SWING_DOWN := 0.12
const SWING_THROUGH := 0.38
const SWING_UP := 0.7
const SWING_TOTAL := 1.0


static func _mix(a: Dictionary, b: Dictionary, f: float) -> Dictionary:
	var out := {}
	for k in a:
		out[k] = lerpf(float(a[k]), float(b[k]), f)
	return out


## The pose of the golfer at the address, and at the back swing that starts when the direction locks (`lock_age` seconds ago).
static func aim_pose(locked: bool, lock_age: float) -> Dictionary:
	if not locked:
		return POSES[Pose.ADDRESS]
	return _mix(POSES[Pose.ADDRESS], POSES[Pose.BACK], smoothstep(0.0, 0.3, lock_age))


## The pose `age` seconds after the putt: from the top of the swing down to the ball, through it, up to the finish and slowly back
## to the address.
static func swing_pose(age: float) -> Dictionary:
	if age < SWING_DOWN:
		return _mix(POSES[Pose.BACK], POSES[Pose.HIT], smoothstep(0.0, SWING_DOWN, age))
	if age < SWING_THROUGH:
		var f := (age - SWING_DOWN) / (SWING_THROUGH - SWING_DOWN)
		return _mix(POSES[Pose.HIT], POSES[Pose.FINISH], smoothstep(0.0, 1.0, f))
	if age < SWING_UP:
		return POSES[Pose.FINISH]
	return _mix(POSES[Pose.FINISH], POSES[Pose.ADDRESS], smoothstep(SWING_UP, SWING_TOTAL, age))


## The place of the feet of the golfer for a ball at `ball`: to the left of it, level with it, so that the club reaches
## down to the ball.
static func feet_for(ball: Vector2) -> Vector2:
	return Vector2(ball.x - 0.3, maxf(0.8, ball.y - 0.04))


## Draws the golfer, seen from behind and a little from the side (the cap, the cheek and one eye look to the ball), with the
## feet at `feet`. `shirt` is the slot color. `pose` is one of `POSES` or a mix.
static func draw_golfer(ci: CanvasItem, geo: Geo, feet: Vector2, ball: Vector2, pose: Dictionary, shirt: Color) -> void:
	var foot := geo.at(feet)
	var k := maxf(geo.scale_at(feet.y) / 131.0 * 1.35, GOLFER_MIN) * geo.m
	Shell.record("golfer", ci, Rect2(foot - Vector2(30.0, 70.0) * k, Vector2(60.0, 70.0) * k),
			{"shirt": shirt, "pose": pose})
	var lean := float(pose.lean)
	var pt := func(dx: float, dy: float) -> Vector2: return foot + Vector2(dx, dy) * k
	var up := func(dx: float, dy: float) -> Vector2: return foot + Vector2(dx + lean * clampf(-dy / 60.0, 0.0, 1.0), dy) * k
	var poly := func(points: Array, c: Color) -> void:
		var pts := PackedVector2Array(points)
		ci.draw_colored_polygon(pts, c)
		pts.append(pts[0])
		ci.draw_polyline(pts, OL, 4.0)
	ci.draw_rect(Rect2(foot - Vector2(16.0, 3.0) * k, Vector2(34.0, 7.0) * k), Color(0.0, 0.2, 0.0, 0.5))
	var hand: Vector2 = up.call(float(pose.hx), float(pose.hy))
	# Legs and shoes: white, the shoes point to the ball, with a grey sole.
	for sx in [-5.0, 3.0]:
		poly.call([pt.call(sx - 3.5, -24.0), pt.call(sx + 3.5, -24.0), pt.call(sx + 3.5, -5.0), pt.call(sx - 3.5, -5.0)], WHITE)
		ci.draw_line(pt.call(sx, -23.0), pt.call(sx, -7.0), Color("d8d8d8"), 3.0)
		poly.call([pt.call(sx - 4.0, -5.0), pt.call(sx + 3.0, -6.0), pt.call(sx + 9.0, -2.0), pt.call(sx + 9.0, 0.0),
				pt.call(sx - 4.0, 0.0)], WHITE)
		ci.draw_line(pt.call(sx - 4.0, -0.5), pt.call(sx + 9.0, -0.5), Color("a8a8a8"), 4.0)
	poly.call([up.call(-9.0, -27.0), up.call(9.0, -27.0), up.call(9.0, -23.0), up.call(-9.0, -23.0)], WOOD_LO)
	# The shirt, in the slot color: the back with a darker side and a collar.
	poly.call([up.call(-9.0, -26.0), up.call(9.0, -26.0), up.call(12.0, -46.0), up.call(-11.0, -46.0)], shirt)
	ci.draw_line(up.call(3.0, -27.0), up.call(6.0, -45.0), shirt.darkened(0.2), maxf(4.0, 6.0 * k))
	poly.call([up.call(-5.0, -49.0), up.call(5.0, -49.0), up.call(7.0, -45.0), up.call(-7.0, -45.0)], shirt.darkened(0.3))
	# Both arms reach the hands on the club: a short sleeve, then the skin.
	for sx in [-1.0, 1.0]:
		var shoulder: Vector2 = up.call(sx * 11.0, -43.0)
		var skin := SKIN if sx > 0.0 else SKIN.darkened(0.15)
		var elbow := shoulder.lerp(hand, 0.55) + Vector2(sx * 5.0, 2.0) * k
		for seg in [[shoulder, elbow], [elbow, hand]]:
			ci.draw_line(seg[0], seg[1], OL, maxf(8.0, 7.0 * k))
		for seg in [[shoulder, elbow], [elbow, hand]]:
			ci.draw_line(seg[0], seg[1], skin, maxf(4.0, 4.0 * k))
		ci.draw_line(shoulder, shoulder.lerp(elbow, 0.5), shirt, maxf(8.0, 7.0 * k))
	ci.draw_circle(hand, maxf(5.0, 4.0 * k) + 3.0, OL)
	ci.draw_circle(hand, maxf(5.0, 4.0 * k), SKIN)
	# The head: neck, hair, a face that looks to the ball and a white cap with a visor.
	ci.draw_rect(Rect2(up.call(-3.0, -52.0), Vector2(6.0, 5.0) * k), SKIN)
	var head: Vector2 = up.call(0.0, -62.0)
	ci.draw_circle(head, 11.0 * k + 4.0, OL)
	ci.draw_circle(head, 11.0 * k, HAIR)
	ci.draw_circle(head + Vector2(3.0, 1.0) * k, 8.5 * k, SKIN)
	ci.draw_circle(head + Vector2(-3.0, 1.0) * k, 3.0 * k + 3.0, OL)
	ci.draw_circle(head + Vector2(-3.0, 1.0) * k, 3.0 * k, SKIN)
	ci.draw_circle(head + Vector2(6.0, 4.0) * k, 2.5 * k, Color("f89898"))
	ci.draw_rect(Rect2(head + Vector2(6.5, -3.0) * k, Vector2(2.0, 4.0) * k), OL)
	ci.draw_line(head + Vector2(4.0, 7.0) * k, head + Vector2(8.0, 6.5) * k, OL, 3.0)
	# The white baseball cap: a round crown with a button and seams, a band round the head and a curved visor to the front.
	var cap := PackedVector2Array()
	for i in 21:
		var a := PI + PI * float(i) / 20.0
		cap.append(head + Vector2(1.0 + cos(a) * 13.5, -4.0 + sin(a) * 13.0) * k)
	ci.draw_colored_polygon(cap, WHITE)
	ci.draw_polyline(cap, OL, 4.0)
	for sx in [-5.0, 5.0]:
		var seam := PackedVector2Array()
		for i in 7:
			var f := float(i) / 6.0
			seam.append(head + Vector2(1.0 + sx * (0.2 + 0.8 * f), -17.0 + 12.0 * f) * k)
		ci.draw_polyline(seam, Color("c8c8c8"), 3.0)
	ci.draw_circle(head + Vector2(1.0, -17.2) * k, 2.2 * k + 2.0, OL)
	ci.draw_circle(head + Vector2(1.0, -17.2) * k, 2.2 * k, Color("c8c8c8"))
	poly.call([head + Vector2(-12.5, -5.5) * k, head + Vector2(14.5, -5.5) * k, head + Vector2(14.5, -3.0) * k,
			head + Vector2(-12.5, -3.0) * k], Color("e8e8e8"))
	var visor := PackedVector2Array([head + Vector2(8.0, -5.5) * k, head + Vector2(16.0, -7.0) * k, head + Vector2(24.0, -4.5) * k,
			head + Vector2(25.0, -1.0) * k, head + Vector2(17.0, -2.5) * k, head + Vector2(8.0, -3.0) * k])
	ci.draw_colored_polygon(visor, WHITE)
	ci.draw_polyline(visor + PackedVector2Array([visor[0]]), OL, 4.0)
	ci.draw_line(head + Vector2(10.0, -3.2) * k, head + Vector2(24.0, -1.8) * k, Color("a8a8a8"), 3.0)
	# The putter, drawn like a real one: a long thin steel shaft, a black grip with a rounded top, and a small blade head
	# that lies on
	# the ground. At the ball the shaft goes down to the ball at an angle and the head stands behind the ball.
	var ang := deg_to_rad(float(pose.a))
	var br := geo.ball_r(ball.y)
	var head_at: Vector2 = hand + Vector2(cos(ang), -sin(ang)) * CLUB * k
	var at_ball: Vector2 = geo.at(ball) - Vector2(br + 14.0, br * 0.5)
	head_at = head_at.lerp(at_ball, float(pose.ab))
	var shaft := head_at - hand
	var dir := shaft.normalized()
	var side := dir.orthogonal()
	var grip_end := hand + shaft * 0.32
	var heel := head_at - dir * 3.0 * k
	ci.draw_line(hand - dir * 5.0 * k, heel, OL, maxf(7.0, 3.6 * k))
	ci.draw_line(hand - dir * 5.0 * k, heel, STEEL, maxf(3.0, 1.8 * k))
	ci.draw_line(hand + dir * 3.0 * k + side * 1.0, heel + side * 1.0, ROCK_HI, 2.0)
	ci.draw_line(hand - dir * 5.0 * k, grip_end, OL, maxf(11.0, 5.5 * k))
	ci.draw_line(hand - dir * 5.0 * k, grip_end, GRIP, maxf(7.0, 3.5 * k))
	ci.draw_circle(hand - dir * 5.0 * k, maxf(5.0, 2.8 * k), GRIP)
	var blade := PackedVector2Array([head_at + Vector2(-9.0, -5.0) * k, head_at + Vector2(6.0, -5.0) * k,
			head_at + Vector2(7.0, 1.0) * k, head_at + Vector2(-9.0, 1.0) * k])
	ci.draw_colored_polygon(blade, STEEL)
	ci.draw_polyline(blade + PackedVector2Array([blade[0]]), OL, 4.0)
	ci.draw_rect(Rect2(head_at + Vector2(-9.0, -5.0) * k, Vector2(15.0, 1.6) * k), GOLD)
	ci.draw_rect(Rect2(head_at + Vector2(-9.0, -0.6) * k, Vector2(16.0, 1.6) * k), STEEL_LO)
