extends RefCounted
## The picture of the maze board (REQ-MZ-7, REQ-MZ-12): the ground, the walls and the start cell of one style, drawn once into an
## image of world pixels (480x270). The game draws this image every frame and puts the balls and the chest on top of it.
## The walls are given as rectangles in screen units (1 world pixel = 4 units). Everything is flat color on the pixel grid:
## a wall has a dark outline, a lit top edge, a face with marks, and a front band below it (the wall stands up from the ground).

const FRONT := 4      # The front band under a wall, in world pixels.
const TILE := 12      # The ground is a chess board of tiles this many world pixels wide.
const HUD_ROWS := 28  # The black bar for the title and the timer: 112 screen units.

## The colors of the styles. `kind` says how the wall is drawn: a hedge (leafy edge and leaf marks), stone (a pattern of bricks)
## or ice (snow marks and a shine). `outline`, `face`, `light` and `front` are the colors of the wall. `ground_a` and `ground_b`
## are the two tones of the ground, `tuft` and `flower` the marks on it.
const STYLES := {
	"garden": {"kind": "hedge", "ground_a": Color("4c9e3c"), "ground_b": Color("46943a"), "tuft": Color("2e7a2c"),
			"flower": Color("fcfcfc"), "outline": Color("083010"), "face": Color("247024"), "light": Color("70c448"),
			"front": Color("145418"), "start": Color("8ad06a")},
	"castle": {"kind": "stone", "ground_a": Color("2a1070"), "ground_b": Color("230e60"), "tuft": Color("34188a"),
			"flower": Color("5a3cc0"), "outline": Color("140840"), "face": Color("b8a890"), "light": Color("e0d4b8"),
			"front": Color("6c5a48"), "start": Color("5a3cc0")},
	"ice": {"kind": "ice", "ground_a": Color("0e2458"), "ground_b": Color("0a1c4a"), "tuft": Color("1c3c7c"),
			"flower": Color("fcfcfc"), "outline": Color("061030"), "face": Color("a8d8f0"), "light": Color("e8f8ff"),
			"front": Color("5a90c0"), "start": Color("3a68c0")},
}
const DEFAULT_STYLE := "garden"


## A number from the place (`a`, `b`) and a `salt`, the same every time: it places the marks of a style in the same spots.
static func scatter(a: int, b: int, salt: int) -> int:
	return ((a * 73856093) ^ (b * 19349663) ^ (salt * 83492791)) & 0xffff


static func look(style: String) -> Dictionary:
	return STYLES.get(style, STYLES[DEFAULT_STYLE])


## The picture of the board. `walls` are rectangles in screen units, `start` is the start cell as a rectangle in screen units,
## `view` is the size of the picture in world pixels.
static func render(style: String, walls: Array[Rect2], start: Rect2, view: Vector2i) -> Image:
	var c := look(style)
	var img := Image.create(view.x, view.y, false, Image.FORMAT_RGBA8)
	_ground(img, c)
	_hud_bar(img)
	_start(img, c, start)
	var mask := _mask(walls, view)
	_walls(img, c, mask, view, String(c.kind))
	return img


static func _ground(img: Image, c: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for ty in ceili(float(h) / TILE):
		for tx in ceili(float(w) / TILE):
			img.fill_rect(Rect2i(tx * TILE, ty * TILE, TILE, TILE), c.ground_a if (tx + ty) % 2 == 0 else c.ground_b)
	for y in range(HUD_ROWS, h):
		for x in w:
			var s := scatter(x, y, 3) % 4000
			if s < 40:
				img.set_pixel(x, y, c.tuft)
				if x + 1 < w:
					img.set_pixel(x + 1, y, c.tuft)
			elif s < 43 and x > 1 and y > 1 and x < w - 2 and y < h - 2:
				# A flower: a plus of five pixels with a yellow middle.
				for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					img.set_pixel(x + d.x, y + d.y, c.flower)
				img.set_pixel(x, y, Color("f8b800"))


## The black bar under the title and the timer (the same in every style), drawn after the ground.
static func _hud_bar(img: Image) -> void:
	img.fill_rect(Rect2i(0, 0, img.get_width(), HUD_ROWS), Color.BLACK)


## The start cell: a lighter frame of one world pixel inside the cell.
static func _start(img: Image, c: Dictionary, start: Rect2) -> void:
	var r := Rect2i((start.position / 4.0).round(), (start.size / 4.0).round())
	var edge: Color = c.start
	img.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 1)), edge)
	img.fill_rect(Rect2i(r.position + Vector2i(0, r.size.y - 1), Vector2i(r.size.x, 1)), edge)
	img.fill_rect(Rect2i(r.position, Vector2i(1, r.size.y)), edge)
	img.fill_rect(Rect2i(r.position + Vector2i(r.size.x - 1, 0), Vector2i(1, r.size.y)), edge)


## The walls as a grid of 0 and 1 (one byte for each world pixel), with a rough edge on a hedge.
static func _mask(walls: Array[Rect2], view: Vector2i) -> PackedByteArray:
	var m := Image.create(view.x, view.y, false, Image.FORMAT_L8)
	for r in walls:
		m.fill_rect(Rect2i((r.position / 4.0).round(), (r.size / 4.0).round()), Color.WHITE)
	return m.get_data()


static func _walls(img: Image, c: Dictionary, mask: PackedByteArray, view: Vector2i, kind: String) -> void:
	var w := view.x
	var h := view.y
	var m := mask.duplicate()
	if kind == "hedge":
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var i := y * w + x
				if mask[i] == 0 and (mask[i - 1] != 0 or mask[i + 1] != 0 or mask[i - w] != 0 or mask[i + w] != 0) \
						and scatter(x, y, 4) % 100 < 22:
					m[i] = 255
	var body := m.duplicate()
	# The front band: the pixels under a wall.
	for y in range(h - 1, 0, -1):
		for x in w:
			if m[(y - 1) * w + x] != 0 and m[y * w + x] == 0:
				for k in FRONT:
					if y + k < h and m[(y + k) * w + x] == 0:
						body[(y + k) * w + x] = 128
	for y in h:
		for x in w:
			var i := y * w + x
			if m[i] != 0:
				img.set_pixel(x, y, _wall_pixel(c, m, w, x, y, kind))
			elif body[i] == 128:
				img.set_pixel(x, y, c.front)
	# The outline: a pixel next to the wall or its front band.
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			if body[i] == 0 and (body[i - 1] != 0 or body[i + 1] != 0 or body[i - w] != 0 or body[i + w] != 0):
				img.set_pixel(x, y, c.outline)


## The color of one wall pixel: the lit top edge (two rows), then the face with the marks of the style.
static func _wall_pixel(c: Dictionary, m: PackedByteArray, w: int, x: int, y: int, kind: String) -> Color:
	var lit := m[(y - 1) * w + x] == 0 or (y > 1 and m[(y - 2) * w + x] == 0)
	if lit:
		return c.light
	var s := scatter(x, y, 5) % 100
	match kind:
		"stone":
			# Bricks: a joint every 4 rows, and across the row every 8 pixels, moved by half a brick on every other row.
			if y % 4 == 0 or (x + (y / 4 % 2) * 4) % 8 == 0:
				return c.front
		"ice":
			if s < 4:
				return Color.WHITE
			if s < 8:
				return c.front
		_:
			if s < 4:
				return c.light
			if s < 9:
				return c.front
	return c.face
