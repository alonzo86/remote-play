extends RefCounted
## The look of Whack-a-Mole (REQ-WM-10): a sunny meadow with a fence, nine holes and friendly moles. The world is drawn in screen
## units on the pixel layer; one pixel of a picture is one world pixel (`Shell.WORLD_PIXEL` units). The pictures of the moles are
## made from shapes when the game starts (`mole_image()`), with a black outline of one pixel.

const Shell = preload("res://scripts/game/shell.gd")
const Palette = preload("res://scripts/game/palette.gd")

const OUTLINE := Color("101018")
const SKY_TOP := Color("58b4f0")
const SKY_BOTTOM := Color("a8dcff")
const SKY_BANDS := 5
const SUN := Color("fff096")
const CLOUD := Color("ffffff")
const FENCE := Color("b07840")
const FENCE_DARK := Color("7a4e28")
const GRASS := [Color("58b050"), Color("66bf58")]   # Two tones in stripes, like a mowed lawn.
const GRASS_LINE := Color("2e7a34")
const FLECK := Color("96d26e")
const FLOWER := [Color("ff6e8c"), Color("ffe040"), Color("ffffff")]
const DIRT := Color("8a5a30")
const DIRT_LIGHT := Color("a8723c")
const HOLE := Color("28180e")
const FUR := Color("8c5630")
const FUR_DARK := Color("60381c")
const GOLD := Color("ffc832")
const GOLD_DARK := Palette.GOLD_SHADE
const CROWN := Color("fff078")
const NOSE := Color("ff96aa")
const CHEEK := Color("ff8aa0")
const HORIZON := 0.27          # The grass starts at this share of the screen height.
const HOLE_RX := 70.0          # The half width and the half height of a hole (px).
const HOLE_RY := 22.0
const STRIPE := 10             # Width of a stripe of the lawn, in world pixels.
const IMG := Vector2i(32, 40)  # The picture of a mole before the outline: 4 rows of crown, the mole under it.


# ---- Scene ----

## The meadow: the sky with the sun and two clouds, a fence along the horizon and a lawn in stripes with flecks and flowers.
## `bar` is the height of the HUD bar that covers the top of the screen.
static func draw_scene(ci: CanvasItem, area: Vector2, t: float, bar := 0.0) -> void:
	var px := Shell.WORLD_PIXEL
	var ground_y := snappedf(area.y * HORIZON, px)
	var sky_h := ground_y - bar
	var band := ceilf(sky_h / float(SKY_BANDS))
	for i in SKY_BANDS:
		ci.draw_rect(Rect2(0.0, bar + band * i, area.x, band + 1.0), SKY_TOP.lerp(SKY_BOTTOM, float(i) / float(SKY_BANDS - 1)))
	ci.draw_circle(Vector2(snappedf(area.x * 0.1, px), snappedf(bar + sky_h * 0.45, px)), 50.0, SUN)
	for i in 2:   # Two clouds that drift slowly to the right (game time: they stand still in a pause).
		var cx := fposmod(area.x * (0.35 + 0.4 * i) + t * 8.0, area.x + 400.0) - 200.0
		var cy := snappedf(bar + sky_h * (0.35 + 0.2 * i), px)
		for blob in [Vector2(-40.0, 8.0), Vector2(0.0, -8.0), Vector2(40.0, 8.0), Vector2(0.0, 12.0)]:
			ci.draw_rect(Rect2(Shell.snap(Vector2(cx, cy) + blob - Vector2(36.0, 16.0)), Vector2(72.0, 32.0)), CLOUD)
	# The lawn, in stripes.
	var stripe_w := STRIPE * px
	for k in int(area.x / stripe_w) + 1:
		ci.draw_rect(Rect2(k * stripe_w, ground_y, stripe_w, area.y - ground_y), GRASS[k % 2])
	ci.draw_rect(Rect2(0.0, ground_y, area.x, px), GRASS_LINE)
	var n := 0
	for ky in int((area.y - ground_y) / (11.0 * px)) + 1:   # Flecks of grass and a few flowers, always in the same places.
		for kx in int(area.x / (13.0 * px)) + 1:
			var fx := snappedf(kx * 13.0 * px + ((ky * 5 + kx * 3) % 11) * px, px)
			var fy := snappedf(ground_y + px * 4.0 + ky * 11.0 * px + ((kx * 7 + ky) % 5) * px, px)
			if fy < area.y - px:
				ci.draw_rect(Rect2(fx, fy, px, 2.0 * px), FLECK)
				if n % 17 == 0:
					ci.draw_rect(Rect2(fx + 3.0 * px, fy, 2.0 * px, 2.0 * px), FLOWER[(n / 17) % FLOWER.size()])
			n += 1
	# The fence: posts and two rails, on the horizon.
	var rail_y := ground_y - 7.0 * px
	for rail in 2:
		var y := rail_y + rail * 4.0 * px
		ci.draw_rect(Rect2(0.0, y - px, area.x, 3.0 * px), OUTLINE)
		ci.draw_rect(Rect2(0.0, y, area.x, px), FENCE)
	for k in int(area.x / (12.0 * px)) + 1:
		var x := k * 12.0 * px
		ci.draw_rect(Rect2(x - px, rail_y - 4.0 * px, 5.0 * px, 13.0 * px), OUTLINE)
		ci.draw_rect(Rect2(x, rail_y - 3.0 * px, 3.0 * px, 11.0 * px), FENCE)
		ci.draw_rect(Rect2(x + 2.0 * px, rail_y - 3.0 * px, px, 11.0 * px), FENCE_DARK)


## A filled ellipse made of rows of one world pixel, centered at `c`. `lower` draws only the half under the middle.
static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color, lower := false) -> void:
	var px := Shell.WORLD_PIXEL
	var rows := int(ry / px)
	for r in range(0 if lower else -rows, rows + 1):
		var y := float(r) * px
		var half := rx * sqrt(maxf(0.0, 1.0 - (y * y) / (ry * ry)))
		var w := snappedf(half * 2.0, 2.0 * px)
		ci.draw_rect(Rect2(Shell.snap(Vector2(c.x - w * 0.5, c.y + y)), Vector2(w, px)), color)


## The back of a hole: a mound of dirt with a dark opening. A mole is drawn after this, and `draw_hole_front()` after the mole.
static func draw_hole_back(ci: CanvasItem, c: Vector2, k: float) -> void:
	ellipse(ci, c + Vector2(0.0, 6.0 * k), (HOLE_RX + 14.0) * k, (HOLE_RY + 10.0) * k, OUTLINE)
	ellipse(ci, c + Vector2(0.0, 4.0 * k), (HOLE_RX + 10.0) * k, (HOLE_RY + 6.0) * k, DIRT)
	ellipse(ci, c, HOLE_RX * k, HOLE_RY * k, HOLE)


## The front lip of a hole: the lower half of the opening is dirt again, so that a mole comes out from behind it.
static func draw_hole_front(ci: CanvasItem, c: Vector2, k: float) -> void:
	ellipse(ci, c, HOLE_RX * k, HOLE_RY * k, DIRT_LIGHT, true)
	ellipse(ci, c + Vector2(0.0, Shell.WORLD_PIXEL * 2.0), HOLE_RX * k * 0.9, HOLE_RY * k * 0.7, DIRT, true)


# ---- Pictures ----

static func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, color)


static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, color)


## The picture of a mole: `golden` has a crown and gold fur, `happy` has closed, smiling eyes and pink cheeks (the hit).
## The picture is 34 x 42 pixels with the outline; its top is the top of the crown or the head.
static func mole_image(golden: bool, happy: bool) -> Image:
	var img := Image.create(IMG.x, IMG.y, false, Image.FORMAT_RGBA8)
	var fur := GOLD if golden else FUR
	var dark := GOLD_DARK if golden else FUR_DARK
	_fill_ellipse(img, 16.0, 20.0, 12.0, 15.0, fur)           # The head and the back.
	_rect(img, 4, 20, 24, IMG.y - 20, fur)                    # The body goes down to the hole.
	_rect(img, 4, 20, 2, IMG.y - 20, dark)                    # A darker side on each edge.
	_rect(img, 26, 20, 2, IMG.y - 20, dark)
	_rect(img, 6, 36, 5, 4, dark)                             # Two small paws.
	_rect(img, 21, 36, 5, 4, dark)
	_rect(img, 13, 20, 6, 4, NOSE)                            # The nose.
	_rect(img, 14, 24, 2, 3, Color.WHITE)                     # Two little teeth.
	_rect(img, 16, 24, 2, 3, Color.WHITE)
	if happy:
		for ex in [8, 20]:   # An eye that smiles: a little roof ^.
			_rect(img, ex + 1, 12, 2, 1, OUTLINE)
			_rect(img, ex, 13, 1, 1, OUTLINE)
			_rect(img, ex + 3, 13, 1, 1, OUTLINE)
		_rect(img, 5, 19, 3, 2, CHEEK)
		_rect(img, 24, 19, 3, 2, CHEEK)
	else:
		for ex in [9, 21]:
			_rect(img, ex, 11, 3, 4, OUTLINE)
			_rect(img, ex, 11, 1, 1, Color.WHITE)
	if golden:
		for i in 3:   # A crown: three points on the head.
			_rect(img, 9 + i * 6, 1, 3, 3, CROWN)
			_rect(img, 9 + i * 6, 3, 3, 1, GOLD_DARK)
		_rect(img, 9, 4, 15, 3, CROWN)
		_rect(img, 9, 6, 15, 1, GOLD_DARK)
	return _outlined(img)


## The picture with a black outline of one pixel around its colored pixels.
static func _outlined(img: Image) -> Image:
	var out := Image.create(img.get_width() + 2, img.get_height() + 2, false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					out.set_pixel(x + 1 + d.x, y + 1 + d.y, OUTLINE)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				out.set_pixel(x + 1, y + 1, c)
	return out
