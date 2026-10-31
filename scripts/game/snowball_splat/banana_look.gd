extends RefCounted
## The look of Banana Party (REQ-SS-12): a jungle at sunset and the animals that walk in it. The world is drawn in screen units
## on the pixel layer; one pixel of a picture is one world pixel (`Shell.WORLD_PIXEL` units). The pictures of the animals are
## made from shapes when the game starts (`animal_image()`): they face right, and have a black outline of one pixel.

const Shell = preload("res://scripts/game/shell.gd")
const Palette = preload("res://scripts/game/palette.gd")
const PixelArt = preload("res://scripts/game/pixel_art.gd")

const OUTLINE := Color("101018")
const SKY_TOP := Palette.BANANA_TAN
const SKY_BOTTOM := Color("fad8a8")
const SKY_BANDS := 6
const SUN := Color("fff096")
const HILL_FAR := Color("3c8264")
const HILL_NEAR := Color("246450")
const TRUNK := Color("503824")
const VINE := Color("287838")
const LEAF := Color("226e3c")
const GROUND := [Color("46963e"), Color("58a846"), Color("6eba50")]   # The three lanes, far to near.
const GROUND_LINE := Color("286432")
const GRASS_FLECK := Color("96d26e")
const BANANA := Color("ffe040")
const BANANA_STEM := Color("6e501e")
const GROUND_TOP := 0.555       # The ground starts at this share of the screen height.
const LANE_EDGES := [0.555, 0.667, 0.787]   # Where the lanes of the ground start, as shares of the screen height.
const TRUNKS := [0.0, 0.055, 0.117, 0.78, 0.953]   # Shares of the width, there is one trunk at each.
const BUSH := [Color("2e8a3e"), Color("3fa84a"), Color("63c45a")]   # Dark, middle and light leaves of a bush.
const BUSH_FLOWER := Color("ff6e8c")
const TUFT := Color("2c7a34")
const TUFTS := 9                 # Tufts of tall grass in each lane band.
const LEAVES := [8, 5, 3]       # The number of drifting leaves in each layer.

const FUR := {
	"monkey": Color("96603a"), "monkey_dark": Color("6e4426"), "monkey_face": Color("f0c896"), "monkey_belly": Color("deb078"),
}


# ---- Scene ----

## The jungle: the sky with the sun, two rows of hills, trunks with vines, leaves in the corners, the ground in three lanes, and
## a few leaves that drift down. `t` is the game time (the leaves
## stand still while the game is paused). `bar` is the height of the
## HUD bar that covers the top of the screen: the sky, the vines and the treetops are drawn under it, so they can be seen.
static func draw_scene(ci: CanvasItem, area: Vector2, t: float, bar := 0.0) -> void:
	var px := Shell.WORLD_PIXEL
	var ground_y := snappedf(area.y * GROUND_TOP, px)
	var sky_h := ground_y - bar
	var band := ceilf(sky_h / float(SKY_BANDS))
	for i in SKY_BANDS:
		ci.draw_rect(Rect2(0.0, bar + band * i, area.x, band + 1.0), SKY_TOP.lerp(SKY_BOTTOM, float(i) / float(SKY_BANDS - 1)))
	var sun := Vector2(snappedf(area.x * 0.62, px), snappedf(bar + sky_h * 0.3, px))
	ci.draw_circle(sun, 60.0, SUN)
	for layer in 2:   # The far hills are lighter and higher, the near hills are darker and 8 world pixels lower.
		var color: Color = HILL_FAR if layer == 0 else HILL_NEAR
		for col in int(area.x / (5.0 * px)) + 1:
			var x := col * 5.0 * px
			var h := 72.0 + 32.0 * sin(col / 17.0 + layer) + 24.0 * sin(col / 6.0 + layer * 2.0)
			var y0 := ground_y - snappedf(h, px) - 10.0 * px + layer * 8.0 * px
			ci.draw_rect(Rect2(x, y0, 5.0 * px, ground_y - y0), color)
	for i in LANE_EDGES.size():
		var top := snappedf(area.y * float(LANE_EDGES[i]), px)
		var bottom := area.y if i == LANE_EDGES.size() - 1 else snappedf(area.y * float(LANE_EDGES[i + 1]), px)
		ci.draw_rect(Rect2(0.0, top, area.x, bottom - top), GROUND[i])
		ci.draw_rect(Rect2(0.0, top, area.x, px), GROUND_LINE)
		var step := 13.0 * px
		var k := 0
		while k * step < area.x:   # Flecks of grass, always in the same places.
			var fx := snappedf(k * step + (i * 5 % 13) * px, px)
			var fy := snappedf(top + px * (4.0 + float((k * 7 + i * 3) % 19)), px)
			if fy < bottom - px:
				ci.draw_rect(Rect2(fx, fy, px, px), GRASS_FLECK)
			k += 1
	for share in TRUNKS:
		var tx := snappedf(area.x * float(share), px)
		ci.draw_rect(Rect2(tx - px, bar, 5.0 * px, ground_y + 2.0 * px - bar), OUTLINE)
		ci.draw_rect(Rect2(tx, bar, 3.0 * px, ground_y + 2.0 * px - bar), TRUNK)
	for share in [0.12, 0.28, 0.45, 0.62, 0.84]:
		var vx := snappedf(area.x * float(share), px)
		ci.draw_rect(Rect2(vx, bar, 2.0 * px, 38.0 * px + 10.0 * px * fmod(share * 13.0, 3.0)), VINE)
	# The treetops (every one sits on a trunk): a cluster of round leaf blobs
	# on every trunk, with a black outline, so the whole tree can be seen. Each is
	# [share of the width, blob radius in world pixels, height under the bar in world pixels].
	for tree in [[0.0, 22.0, 6.0], [0.055, 18.0, 10.0], [0.117, 20.0, 5.0], [0.78, 24.0, 7.0], [0.953, 22.0, 6.0]]:
		var c := Vector2(snappedf(area.x * float(tree[0]) + px, px), bar + float(tree[2]) * px)
		var r: float = float(tree[1]) * px
		for blob in [Vector2(-0.7, 0.35), Vector2(0.7, 0.35), Vector2(0.0, -0.1)]:
			ci.draw_circle(c + blob * r, r * 0.8 + px, OUTLINE)
		for blob in [Vector2(-0.7, 0.35), Vector2(0.7, 0.35), Vector2(0.0, -0.1)]:
			ci.draw_circle(c + blob * r, r * 0.8, LEAF)
	var n := 0
	for layer in LEAVES.size():   # Drifting leaves: small squares that fall slowly, in three speeds.
		for i in int(LEAVES[layer]):
			var lx := fposmod(n * 211.3 + sin(n * 1.7) * 50.0 + t * 6.0, area.x)
			var ly := fposmod(t * (22.0 + layer * 10.0) + n * 97.7, area.y)
			ci.draw_rect(Rect2(Shell.snap(Vector2(lx, ly)), Vector2.ONE * px * (1.0 + (layer % 2))), LEAF if n % 2 == 0
					else Palette.LEAF_ORANGE)
			n += 1


# ---- Pictures ----

## The picture of the animal `kind` (a key of `PuffField.KINDS`): `happy` has closed, smiling eyes (the hit), `facing` is 1 to
## the right or -1 to the left.
static func animal_image(kind: String, happy: bool, facing: int) -> Image:
	var img: Image
	match kind:
		"lemur":
			img = _lemur(happy)
		"orangutan":
			img = _orangutan(happy)
		"sloth":
			img = _sloth(happy)
		"gorilla":
			img = _gorilla(happy)
		"elephant":
			img = _elephant(happy)
		"golden":
			img = _monkey(Color("ffc832"), Palette.GOLD_SHADE, Color("ffecaa"), Color("ffe06e"), true, happy)
		_:
			img = _monkey(FUR.monkey, FUR.monkey_dark, FUR.monkey_face, FUR.monkey_belly, false, happy)
	var out := PixelArt.outlined(img, OUTLINE)
	if facing < 0:
		out.flip_x()
	return out


## The banana that flies, turned by 90 degrees `turn` times (0 to 3).
static func banana_image(turn: int) -> Image:
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	_line(img, [Vector2(8, 1), Vector2(8, 3), Vector2(6, 6), Vector2(2, 8)], BANANA, 2)
	img.set_pixel(8, 1, BANANA_STEM)
	img.set_pixel(1, 8, BANANA_STEM)
	var out := PixelArt.outlined(img, OUTLINE)
	for i in posmod(turn, 4):
		out.rotate_90(CLOCKWISE)
	return out


## The banana peel that stays where an animal was hit.
static func peel_image() -> Image:
	var img := Image.create(9, 4, false, Image.FORMAT_RGBA8)
	_ell(img, 0, 1, 8, 3, BANANA)
	_ell(img, 2, 0, 5, 1, BANANA.lightened(0.3))
	return PixelArt.outlined(img, OUTLINE)


## A bush (REQ-SS-26): `BUSH_HALF_W * 2` px wide, round, in three greens with a few flowers, a one pixel black outline.
static func bush_image() -> Image:
	var img := _canvas(75, 34)
	_ell(img, 0, 12, 74, 33, BUSH[0])
	for lobe in [[2, 4, 26, 28], [20, 0, 54, 26], [46, 5, 72, 29]]:
		_ell(img, lobe[0], lobe[1], lobe[2], lobe[3], BUSH[1])
	for lobe in [[8, 6, 20, 16], [28, 2, 44, 12], [52, 8, 64, 18]]:
		_ell(img, lobe[0], lobe[1], lobe[2], lobe[3], BUSH[2])
	for f in [Vector2(14, 20), Vector2(36, 16), Vector2(58, 22), Vector2(26, 26)]:
		_rect(img, int(f.x), int(f.y), int(f.x) + 1, int(f.y) + 1, BUSH_FLOWER)
	return PixelArt.outlined(img, OUTLINE)


# ---- Animals ----

static func _canvas(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func _eye(img: Image, x: int, y: int, happy: bool, big := false) -> void:
	if happy:   # A smiling arc: closed eyes.
		img.set_pixel(x, y + 1, OUTLINE)
		img.set_pixel(x + 1, y, OUTLINE)
		img.set_pixel(x + 2, y + 1, OUTLINE)
		return
	_rect(img, x, y, x + 1, y + (2 if big else 1), Color("14101a"))
	img.set_pixel(x, y, Color.WHITE)


static func _monkey(body: Color, dark: Color, face: Color, belly: Color, crown: bool, happy: bool) -> Image:
	var img := _canvas(28, 26)
	_line(img, [Vector2(2, 22), Vector2(1, 16), Vector2(2, 10), Vector2(5, 8)], dark, 2)
	_ell(img, 4, 10, 18, 22, body)
	_ell(img, 7, 12, 16, 21, belly)
	_rect(img, 6, 20, 9, 24, dark)
	_rect(img, 13, 20, 17, 24, dark)
	_rect(img, 5, 24, 10, 25, dark)
	_rect(img, 12, 24, 18, 25, dark)
	_rect(img, 16, 12, 19, 20, body)
	_rect(img, 17, 18, 20, 21, dark)
	_ell(img, 14, 2, 26, 14, body)
	_ell(img, 12, 6, 17, 11, body)
	_ell(img, 13, 7, 16, 10, Color("eb968c"))
	_ell(img, 17, 5, 26, 13, face)
	if happy:
		_rect(img, 19, 5, 27, 10, face)
	_eye(img, 20, 7, happy)
	_eye(img, 23, 7, happy)
	_rect(img, 23, 10, 25, 11, Color("3c281e"))
	_line(img, [Vector2(20, 11), Vector2(21, 12), Vector2(24, 12)], Color("783c32"), 1)
	if crown:
		_rect(img, 17, 1, 25, 3, Color("ffd628"))
		for x in [17, 20, 23]:
			_rect(img, x, 0, x + 1, 1, Color("ffd628"))
		img.set_pixel(20, 2, Palette.BANANA_RED)
		img.set_pixel(23, 2, Color("3cb4e6"))
	return img


static func _lemur(happy: bool) -> Image:
	var img := _canvas(30, 24)
	for i in 12:   # The ringed tail curls up.
		var y := 12 - int(8.0 * sin(float(i) / 11.0 * PI * 0.8))
		_rect(img, 1 + i, y, 3 + i, y + 2, Color("fafaff") if i % 2 == 0 else Color("282832"))
	_ell(img, 10, 9, 24, 20, Color("9ea2b0"))
	_ell(img, 13, 12, 22, 19, Color("ecf0f6"))
	_rect(img, 12, 18, 15, 23, Color("787c8c"))
	_rect(img, 20, 18, 23, 23, Color("787c8c"))
	_ell(img, 18, 3, 29, 14, Color("aaaebc"))
	_ell(img, 20, 6, 29, 14, Color("fafaff"))
	_ell(img, 18, 2, 21, 6, Color("9ea2b0"))
	_ell(img, 24, 1, 27, 5, Color("9ea2b0"))
	if happy:
		_eye(img, 21, 6, true)
	else:
		_ell(img, 21, 6, 25, 10, Color("1e1e28"))
		img.set_pixel(22, 7, Color.WHITE)
	_ell(img, 26, 6, 29, 9, Color("1e1e28"))
	_ell(img, 28, 10, 30, 12, Color("1e1e28"))
	return img


static func _orangutan(happy: bool) -> Image:
	var img := _canvas(32, 32)
	_ell(img, 5, 12, 25, 28, Color("d66428"))
	_ell(img, 8, 14, 22, 26, Color("ec823c"))
	_rect(img, 7, 26, 12, 31, Color("b4501e"))
	_rect(img, 18, 26, 24, 31, Color("b4501e"))
	_rect(img, 0, 14, 6, 28, Color("c85c24"))
	_rect(img, 1, 26, 6, 30, Color("964222"))
	_rect(img, 24, 14, 29, 28, Color("c85c24"))
	_rect(img, 24, 26, 30, 30, Color("964222"))
	_ell(img, 10, 2, 28, 18, Color("d66428"))
	_ell(img, 8, 4, 14, 12, Color("d66428"))
	_ell(img, 14, 6, 27, 17, Color("f4c48c"))
	_ell(img, 12, 8, 17, 15, Palette.BANANA_PEACH)
	_eye(img, 18, 9, happy)
	_eye(img, 22, 9, happy)
	_ell(img, 19, 12, 23, 15, Color("d2966a"))
	_line(img, [Vector2(19, 15), Vector2(22, 15)], Color("783c32"), 1)
	return img


static func _sloth(happy: bool) -> Image:
	var img := _canvas(32, 24)
	_ell(img, 2, 6, 24, 20, Color("bca076"))
	_ell(img, 5, 8, 20, 19, Color("ceb68c"))
	_rect(img, 4, 18, 8, 23, Color("967c56"))
	_rect(img, 17, 18, 21, 23, Color("967c56"))
	for x in [4, 6, 17, 19]:
		img.set_pixel(x, 23, Color("f0ecdc"))
	_ell(img, 18, 3, 31, 16, Color("d6be96"))
	_ell(img, 19, 6, 30, 13, Color("6e543c"))
	if happy:
		_eye(img, 21, 7, true)
		_eye(img, 26, 7, true)
		img.set_pixel(21, 7, Color("6e543c"))
	else:
		_ell(img, 21, 7, 24, 11, Color("6e543c"))
		img.set_pixel(22, 8, Color.WHITE)
		_ell(img, 26, 7, 29, 11, Color("6e543c"))
		img.set_pixel(27, 8, Color.WHITE)
	_ell(img, 24, 11, 28, 14, Color("3c2c22"))
	_line(img, [Vector2(22, 14), Vector2(26, 15), Vector2(29, 14)], Color("5a3c2c"), 1)
	return img


static func _gorilla(happy: bool) -> Image:
	var img := _canvas(34, 34)
	_ell(img, 4, 10, 30, 32, Color("464856"))
	_ell(img, 11, 15, 25, 29, Color("6e7080"))
	_rect(img, 2, 14, 9, 30, Color("3c3e4c"))
	_rect(img, 2, 28, 10, 33, Color("282a36"))
	_rect(img, 25, 14, 32, 30, Color("3c3e4c"))
	_rect(img, 24, 28, 32, 33, Color("282a36"))
	_ell(img, 10, 1, 26, 17, Color("464856"))
	_ell(img, 9, 0, 27, 6, Color("363844"))
	_ell(img, 12, 6, 24, 16, Color("82869a"))
	_rect(img, 12, 6, 24, 7, Color("282a36"))
	_eye(img, 14, 8, happy)
	_eye(img, 20, 8, happy)
	_ell(img, 15, 11, 21, 15, Color("606274"))
	img.set_pixel(16, 12, Color("1e1e28"))
	img.set_pixel(19, 12, Color("1e1e28"))
	_line(img, [Vector2(15, 15), Vector2(20, 15)], Color("282a36"), 1)
	return img


static func _elephant(happy: bool) -> Image:
	var col := Color("969cac")
	var light := Color("bec4d2")
	var tusk := Color("f6f4ec")
	var img := _canvas(46, 36)
	_line(img, [Vector2(2, 12), Vector2(1, 20)], col, 2)
	_rect(img, 0, 19, 2, 22, light)
	_ell(img, 3, 8, 32, 28, col)
	_ell(img, 7, 10, 28, 18, light)
	for x in [6, 12, 22, 28]:
		_rect(img, x, 24, x + 4, 34, col)
		_rect(img, x, 33, x + 4, 34, tusk)
	_ell(img, 24, 3, 42, 24, col)
	_ell(img, 20, 5, 32, 24, Color("e6aab4"))
	_ell(img, 22, 7, 31, 22, Color("f4c8d2"))
	_ell(img, 32, 9, 43, 22, col)
	_rect(img, 38, 18, 43, 26, col)
	_rect(img, 39, 25, 45, 30, col)
	_rect(img, 42, 29, 45, 31, col)
	_rect(img, 36, 24, 38, 28, tusk)
	_eye(img, 38, 12, happy, true)
	_ell(img, 31, 6, 36, 10, Color("8288a0"))
	return img


# ---- Drawing helpers on an image ----

static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	img.fill_rect(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1), color)


## An ellipse that fills the box (x0, y0) to (x1, y1), both included.
static func _ell(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	var cx := (x0 + x1 + 1) * 0.5
	var cy := (y0 + y1 + 1) * 0.5
	var rx := (x1 - x0 + 1) * 0.5
	var ry := (y1 - y0 + 1) * 0.5
	for y in range(maxi(y0, 0), mini(y1 + 1, img.get_height())):
		for x in range(maxi(x0, 0), mini(x1 + 1, img.get_width())):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, color)


## A line through `points` with a brush of `width` pixels.
static func _line(img: Image, points: Array, color: Color, width: int) -> void:
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
		for s in steps + 1:
			var p := a.lerp(b, float(s) / float(steps))
			_rect(img, int(p.x), int(p.y), int(p.x) + width - 1, int(p.y) + width - 1, color)
