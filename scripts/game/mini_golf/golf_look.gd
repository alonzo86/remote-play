extends RefCounted
## The pictures of Mini Golf (REQ-MG-16, docs/games/mini_golf.md): a small golf park seen from behind the tee, in a simple
## perspective. The ground, the walls, the sand and the water of a hole are drawn once into a 480x270 picture (the pixel view
## of the game, REQ-GM-47a) and shown scaled; the golfer, the ball, the bumpers, the windmill and the flag are drawn each frame.
## The golfer has a white hat, white trousers and white shoes and a shirt in the slot color; the ball is always white; nothing on
## the course is white (the user, 2026-10-17).
## A point of the course (x across, z along, in the units of `golf_holes.gd`) is at `Geo.at()`, in screen units.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")

const W := 480
const H := 270
const HY := 88                    # The horizon, in picture pixels.
const SK := 0.95
const CX := 240
const GROUND_END := 230           # The ground goes to the bar of the players at the bottom of the screen.
const HUD_TOP := 28
const WALL_W := 0.14              # The width of a wall, in course units.
const WALL_H := 0.16
const BALL_MIN_R := 3.0           # The ball is at least this big (picture pixels), also far away.
const GOLFER_MIN := 0.42          # The golfer is at least this share of the near size, also far away.

const SKY := [Color("3cbcfc"), Color("68d0fc"), Color("a4e4fc")]
const WHITE := Color("fcfcfc")
const HILL_FAR := Color("007800")
const HILL_NEAR := Color("00a800")
const TREE := Color("005800")
const LAWN_A := Color("98d838")
const LAWN_B := Color("8ccc30")
const FAIR_A := Color("58b800")
const FAIR_B := Color("4ca800")
const TEE_MAT := Color("009800")
const WOOD := Color("ac6418")
const WOOD_HI := Color("e4943c")
const WOOD_LO := Color("683808")
const FENCE := Color("d8ac6c")
const FENCE_LO := Color("a07038")
const SAND := Color("fcd884")
const SAND_DOT := Color("e8c068")
const WATER := Color("3cbcfc")
const WATER_DEEP := Color("0078f8")
const WATER_GLINT := Color("a4e4fc")
const STONE := Color("886840")
const STONE_LO := Color("604428")
const BUSH := Color("006800")
const BUSH_LO := Color("003800")
const BUSH_HI := Color("009800")
const RED := Color("f83800")
const GOLD := Color("f8b800")
const BRICK := Color("d48430")
const OL := Color("181818")
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


static func clear_cache() -> void:
	_hole_tex.clear()
	_base = null


static func hole_image(h: Dictionary) -> Image:
	var img := _base_image().duplicate() as Image
	_paint_ground(img, h)
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
	for e in h.sand:
		var v: Vector4 = e
		var dx := (p.x - v.x) / v.z
		var dz := (p.y - v.y) / v.w
		if dx * dx + dz * dz < 1.0:
			c = SAND if (x + y) % 7 != 0 else SAND_DOT
	for e in h.water:
		var v: Vector4 = e
		var dx := (p.x - v.x) / v.z
		var dz := (p.y - v.y) / v.w
		var d := dx * dx + dz * dz
		if d < 1.0:
			c = WATER if d > 0.35 else WATER_DEEP
			if (int(p.y * 20.0) + int(p.x * 14.0)) % 5 == 0:
				c = WATER_GLINT
		elif d < 1.35:
			c = STONE if (x + y) % 3 != 0 else STONE_LO
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


static func draw_bumper(ci: CanvasItem, geo: Geo, b: Vector3, pulse: float) -> void:
	var foot := geo.at(Vector2(b.x, b.y))
	var sc := geo.scale_at(b.y) * geo.m
	var r := b.z * sc * (1.0 + 0.18 * pulse)
	var c := foot - Vector2(0.0, r)
	ci.draw_circle(c, r + 4.0, Color("781000"))
	ci.draw_circle(c, r, RED)
	ci.draw_circle(c, r * 0.4, GOLD)


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
	var hub := foot + Vector2(0.0, -0.95 * sc)
	for i in 4:
		var a := time * 1.4 + TAU * float(i) / 4.0
		ci.draw_line(hub, hub + Vector2(cos(a), sin(a)) * 0.8 * sc, GOLD, maxf(4.0, 0.05 * sc))
	ci.draw_circle(hub, maxf(4.0, 0.06 * sc), WOOD_LO)


## The ball at `p`, always white, with a small shadow on the ground and a shine.
static func draw_ball(ci: CanvasItem, geo: Geo, p: Vector2, lift := 0.0) -> void:
	var foot := geo.at(p)
	var r := geo.ball_r(p.y)
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
			var at := geo.at(p) - Vector2(0.0, 4.0)
			var sz := maxf(8.0, 0.05 * geo.scale_at(p.y) * geo.m)
			ci.draw_rect(Rect2((at - Vector2(sz, sz) * 0.5), Vector2(sz, sz)), UiTheme.TEXT if i % 2 == 1 else GOLD)
	var end := from + dir * maxf(length, 0.6)
	var e := geo.at(end)
	var sz2 := maxf(16.0, 0.12 * geo.scale_at(end.y) * geo.m)
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

## The poses of the golfer: the hands (picture pixels from the feet, at the full size), the club angle (degrees; 0 points to the
## right, 90 up) and, for the poses at the ball, `at_ball`: the club head touches the ball.
enum Pose { ADDRESS, BACK, DOWN, HIT, FOLLOW }
const POSES := {
	Pose.ADDRESS: {"hx": 4.0, "hy": -26.0, "a": -72.0, "at_ball": true},
	Pose.BACK: {"hx": -2.0, "hy": -40.0, "a": 55.0, "at_ball": false},
	Pose.DOWN: {"hx": 8.0, "hy": -30.0, "a": -35.0, "at_ball": false},
	Pose.HIT: {"hx": 4.0, "hy": -26.0, "a": -72.0, "at_ball": true},
	Pose.FOLLOW: {"hx": -4.0, "hy": -42.0, "a": 125.0, "at_ball": false},
}
const CLUB := 34.0


## The place of the feet of the golfer for a ball at `ball`: to the left of it and a little nearer (as in the mock).
static func feet_for(ball: Vector2) -> Vector2:
	return Vector2(ball.x - 0.28, maxf(0.8, ball.y - 0.25))


## Draws the golfer, seen from behind, with the feet at `feet`. `shirt` is the slot color.
static func draw_golfer(ci: CanvasItem, geo: Geo, feet: Vector2, ball: Vector2, pose: int, shirt: Color) -> void:
	var foot := geo.at(feet)
	var k := maxf(geo.scale_at(feet.y) / 131.0 * 1.35, GOLFER_MIN) * geo.m
	var pt := func(dx: float, dy: float) -> Vector2: return foot + Vector2(dx, dy) * k
	var box := func(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
		var a: Vector2 = pt.call(x0, y0)
		var b: Vector2 = pt.call(x1, y1)
		ci.draw_rect(Rect2(a - Vector2(4.0, 4.0), b - a + Vector2(8.0, 8.0)), OL)
		ci.draw_rect(Rect2(a, b - a), c)
	ci.draw_rect(Rect2(foot - Vector2(16.0, 3.0) * k, Vector2(32.0, 7.0) * k), Color(0.0, 0.2, 0.0, 0.5))
	var d: Dictionary = POSES[pose]
	var hand: Vector2 = pt.call(float(d.hx), float(d.hy))
	for sx in [-9.0, 9.0]:
		ci.draw_line(pt.call(sx, -40.0), hand, OL, maxf(8.0, 6.0 * k))
	box.call(-8.0, -4.0, -1.0, 0.0, SHOE)
	box.call(1.0, -4.0, 8.0, 0.0, SHOE)
	box.call(-7.0, -22.0, -1.0, -4.0, WHITE)
	box.call(1.0, -22.0, 7.0, -4.0, WHITE)
	box.call(-10.0, -44.0, 10.0, -21.0, shirt)
	box.call(-4.0, -44.0, 4.0, -41.0, shirt.darkened(0.25))
	for sx in [-9.0, 9.0]:
		ci.draw_line(pt.call(sx, -40.0), hand, shirt, maxf(4.0, 4.0 * k))
	ci.draw_circle(hand, maxf(4.0, 3.0 * k), SKIN)
	var head: Vector2 = pt.call(0.0, -56.0)
	ci.draw_circle(head, 10.0 * k + 4.0, OL)
	ci.draw_circle(head, 10.0 * k, HAIR)
	var cap := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		cap.append(head + Vector2(cos(a), sin(a)) * 10.0 * k)
	ci.draw_colored_polygon(cap, WHITE)
	ci.draw_rect(Rect2(pt.call(-10.0, -56.0), Vector2(20.0, 2.0) * k), Color("c8c8c8"))
	var tip: Vector2
	if bool(d.at_ball):
		var br := geo.ball_r(ball.y)
		tip = geo.at(ball) - Vector2(br + 8.0, br)
	else:
		var a := deg_to_rad(float(d.a))
		tip = hand + Vector2(cos(a), -sin(a)) * CLUB * k
	ci.draw_line(hand, tip, OL, maxf(8.0, 5.0 * k))
	ci.draw_line(hand, tip, Color("e0e0e0"), maxf(4.0, 3.0 * k))
	ci.draw_rect(Rect2(tip - Vector2(5.0, 2.0) * k, Vector2(10.0, 4.0) * k), GOLD)
