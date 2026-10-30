extends RefCounted
## The picture of the maze board (REQ-MZ-7, REQ-MZ-12): the ground, the walls and the start cell of one theme, drawn once into an
## image of world pixels (480x270). The game draws this image every frame and puts the balls and the chest on top of it.
## The walls are given as rectangles in screen units (1 world pixel = 4 units). Everything is flat color on the pixel grid:
## a wall has a dark outline, a lit top edge, a face with marks, and a front band below it (the wall stands up from the ground).

const Palette = preload("res://scripts/game/palette.gd")

const FRONT := 4      # The front band under a wall, in world pixels.
const TILE := 12      # The ground is a chess board of tiles this many world pixels wide.
const HUD_ROWS := 28  # The black bar for the title and the timer: 112 screen units.

## The colors of the themes. `kind` says how the wall is drawn: a hedge (leafy edge and leaf marks), stone (a pattern of bricks)
## or ice (snow marks and a shine). `outline`, `face`, `light` and `front` are the colors of the wall. `ground_a` and `ground_b`
## are the two tones of the ground, `tuft` and `flower` the marks on it.
const THEMES := {
	"garden": {"kind": "hedge", "ground_a": Color("4c9e3c"), "ground_b": Color("46943a"), "tuft": Color("2e7a2c"),
			"flower": Color("fcfcfc"), "outline": Color("083010"), "face": Color("247024"), "light": Color("70c448"),
			"front": Color("145418"), "start": Color("8ad06a"), "deco": ["tree", "bush"]},
	"castle": {"kind": "stone", "ground_a": Color("2a1070"), "ground_b": Color("230e60"), "tuft": Color("34188a"),
			"flower": Color("5a3cc0"), "outline": Color("140840"), "face": Color("b8a890"), "light": Color("e0d4b8"),
			"front": Color("6c5a48"), "start": Color("5a3cc0"), "deco": ["torch", "shield"]},
	"ice": {"kind": "ice", "ground_a": Color("0e2458"), "ground_b": Color("0a1c4a"), "tuft": Color("1c3c7c"),
			"flower": Color("fcfcfc"), "outline": Color("061030"), "face": Color("a8d8f0"), "light": Color("e8f8ff"),
			"front": Palette.ICE_BLUE, "start": Color("3a68c0"), "deco": ["penguin", "iceberg"]},
}
const DEFAULT_THEME := "garden"

## The flame of a torch (REQ-MZ-14): the top 5 rows of the torch picture are not in the board picture. The game draws one of these
## frames there, and the frame changes every FLAME_S seconds of game time. One character is one world pixel, as in SPRITES.
const FLAME_COLORS := {"Y": Color("f8b800"), "O": Palette.NES_RED}
const FLAME_FRAMES := [
	["...YY...", "..YOOY..", "..YOOY..", ".YOYYOY.", ".YOYYOY."],
	["........", "...YY...", "..YOOY..", ".YOYYOY.", ".YOYYOY."],
	["..Y.....", "..YY.Y..", "..YOYY..", ".YOOYOY.", ".YOYYOY."],
]
const FLAME_S := 0.2

## Small pictures for the side margins (REQ-MZ-13). One character is one world pixel; `.` is empty. The letters name a color:
## the theme colors `outline`, `face`, `light` and `front` come from the theme, the others are written here.
const SPRITES := {
	"tree": {"rows": ["....KKKK....",
				"..KKGGGGKK..",
				".KGGLGGGGGK.",
				".KGLLGGGGGK.",
				"KGGLGGGGGGGK",
				"KGGGGGGGGGDK",
				"KGGGGGGGGDDK",
				".KGGGGGGDDK.",
				".KKGGGDDDKK.",
				"...KKKKKK...",
				".....KTK....",
				".....KTK....",
				".....KTK....",
				"....KKTKK...",
				"....KKKKK..."],
			"colors": {"K": "outline", "G": "face", "L": "light", "D": "front", "T": Color("7c4a1c")}},
	"bush": {"rows": ["...KKKKKK...",
				".KKGGGGGGKK.",
				"KGGRGGGGRGGK",
				"KGGGGPGGGGGK",
				"KGRGGGGGRGGK",
				"KGGGGRGGGGDK",
				".KDDDDDDDDK.",
				"..KKKKKKKK.."],
			"colors": {"K": "outline", "G": "face", "D": "front", "R": Palette.NES_RED, "P": Color("f8a0b8")}},
	"torch": {"rows": ["........",
				"........",
				"........",
				"........",
				"........",
				"..OOOO..",
				"...KK...",
				"..KTTK..",
				"..KTTK..",
				"...TT...",
				"...TT...",
				"...TT...",
				"...TT...",
				"...TT...",
				"..KKKK.."],
			"colors": {"K": "outline", "O": Palette.NES_RED, "T": Color("7c4a1c")}},
	"shield": {"rows": ["KKKKKKKKKK",
				"KRRRRRRRRK",
				"KRRRYYRRRK",
				"KRRRYYRRRK",
				"KYYYYYYYYK",
				"KYYYYYYYYK",
				"KRRRYYRRRK",
				"KRRRYYRRRK",
				".KRRYYRRK.",
				"..KRYYRK..",
				"...KRRK...",
				"....KK...."],
			"colors": {"K": Color("140840"), "R": Palette.MAZE_RED, "Y": Color("f8b800")}},
	"penguin": {"rows": ["..HHHHH..",
				".HNNNNNH.",
				".HNWNWNH.",
				".HNNONNH.",
				"HNWWWWWNH",
				"HNWWWWWNH",
				"HNWWWWWNH",
				"HNWWWWWNH",
				".HNWWWNH.",
				"..HHHHH..",
				"..OO.OO..",
				".OOO.OOO."],
			"colors": {"H": Color("e8f8ff"), "N": Color("303860"), "W": Color("fcfcfc"), "O": Color("f8a000")}},
	"iceberg": {"rows": [".....H......",
				"....HLH.....",
				"...HLLLH....",
				"..HLLWLLH...",
				"..HLWLLLLH..",
				".HLLLLLLLLH.",
				"HLLLLLLLDDLH",
				"HLLLLLDDDDLH",
				".HDDDDDDDDH.",
				"..HHHHHHHH.."],
			"colors": {"H": Color("e8f8ff"), "L": Color("a8d8f0"), "W": Color.WHITE, "D": Palette.ICE_BLUE}},
}


## A number from the place (`a`, `b`) and a `salt`, the same every time: it places the marks of a theme in the same spots.
static func scatter(a: int, b: int, salt: int) -> int:
	return ((a * 73856093) ^ (b * 19349663) ^ (salt * 83492791)) & 0xffff


static func look(theme: String) -> Dictionary:
	return THEMES.get(theme, THEMES[DEFAULT_THEME])


## The picture of the board. `walls` are rectangles in screen units, `start` is the start cell as a rectangle in screen units,
## `view` is the size of the picture in world pixels.
static func render(theme: String, walls: Array[Rect2], start: Rect2, view: Vector2i) -> Image:
	var c := look(theme)
	var img := Image.create(view.x, view.y, false, Image.FORMAT_RGBA8)
	_ground(img, c)
	_hud_bar(img)
	_start(img, c, start)
	var mask := _mask(walls, view)
	_walls(img, c, mask, view, String(c.kind))
	_decorations(img, c, walls)
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


## The black bar under the title and the timer (the same in every theme), drawn after the ground.
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


## Two small pictures in the margin on each side of the maze (REQ-MZ-13): the first picture of the theme on top at the left and
## at the bottom at the right, the second one the other way round. They are centered in the free space beside the walls, at a
## quarter and at three quarters of the height of the maze. A picture that does not fit in the margin is not drawn.
static func _decorations(img: Image, c: Dictionary, walls: Array[Rect2]) -> void:
	for place in deco_places(c, walls, img.get_width()):
		_sprite(img, c, place.name, place.center)


## Where the pictures of the margins stand: [{name, center}] with the middle in world pixels. `width` is the width of the board
## picture in world pixels.
static func deco_places(c: Dictionary, walls: Array[Rect2], width: int) -> Array:
	var out := []
	if walls.is_empty():
		return out
	var box := walls[0]
	for r in walls:
		box = box.merge(r)
	var left_edge := int(box.position.x / 4.0)
	var right_edge := int(box.end.x / 4.0)
	var names: Array = c.deco
	var tops := [int((box.position.y + box.size.y * 0.25) / 4.0), int((box.position.y + box.size.y * 0.72) / 4.0)]
	for i in 2:
		out.append({"name": names[i], "center": Vector2i(left_edge / 2, tops[i])})
		out.append({"name": names[1 - i], "center": Vector2i((right_edge + width) / 2, tops[i])})
	return out


## The top left corner (world pixels) of the flame of each torch of a theme, for the same walls as `render`.
static func torch_places(theme: String, walls: Array[Rect2], width: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rows: Array = SPRITES.torch.rows
	for place in deco_places(look(theme), walls, width):
		if place.name == "torch":
			out.append(place.center - Vector2i(String(rows[0]).length() / 2, rows.size() / 2))
	return out


## The frame of the flame at game time `t` seconds.
static func flame_frame(t: float) -> int:
	return int(maxf(t, 0.0) / FLAME_S) % FLAME_FRAMES.size()


## The squares of one frame of the flame with its top left corner at `spot` (world pixels): [[Rect2 in screen units, Color]].
## `unit` is the size of a world pixel in screen units (4 x 4 on 1920 x 1080).
static func flame_squares(spot: Vector2i, frame: int, unit: Vector2) -> Array:
	var out := []
	var rows: Array = FLAME_FRAMES[frame % FLAME_FRAMES.size()]
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			if row[x] != ".":
				out.append([Rect2(Vector2(spot + Vector2i(x, y)) * unit, unit), FLAME_COLORS[row[x]]])
	return out


## Draws one frame of the flame on `ci`, which draws in screen units.
static func draw_flame(ci: CanvasItem, spot: Vector2i, frame: int, unit: Vector2) -> void:
	for sq in flame_squares(spot, frame, unit):
		ci.draw_rect(sq[0], sq[1])


## One small picture with its middle at `center` (world pixels). Pixels outside the image are left out.
static func _sprite(img: Image, c: Dictionary, name: String, center: Vector2i) -> void:
	var sprite: Dictionary = SPRITES[name]
	var rows: Array = sprite.rows
	var colors: Dictionary = sprite.colors
	var origin := center - Vector2i(String(rows[0]).length() / 2, rows.size() / 2)
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var spot := origin + Vector2i(x, y)
			if spot.x < 0 or spot.y < 0 or spot.x >= img.get_width() or spot.y >= img.get_height():
				continue
			var color = colors.get(ch)
			if color is String:
				color = c[color]   # A color of the theme: outline, face, light or front.
			img.set_pixel(spot.x, spot.y, color)


## The walls as a grid of 0 and 1 (one byte for each world pixel), with a rough edge on a hedge.
static func _mask(walls: Array[Rect2], view: Vector2i) -> PackedByteArray:
	var m := Image.create(view.x, view.y, false, Image.FORMAT_L8)
	for r in walls:
		# The edges are rounded, not the position and the size: a wall is as thick as its edges are far apart, to half a world pixel.
		var from := (r.position / 4.0).round()
		m.fill_rect(Rect2i(from, ((r.end / 4.0).round() - from)), Color.WHITE)
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


## The color of one wall pixel: the lit top edge (two rows), then the face with the marks of the theme.
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
