extends RefCounted
## The pictures of Sheep Herding (REQ-SH-15, 16): the sheepdog in the color of a player, the sheep, the things around the field,
## the barn, the pond and the pen. The small pictures are text (`.` nothing, a letter a color) turned into images, one pixel of
## the text is one world pixel (4 units, REQ-GM-47a). Nothing is an image file. The drawing helpers draw on the pixel layer.

const Shell = preload("res://scripts/game/shell.gd")
const Palette = preload("res://scripts/game/palette.gd")

const WORLD_PIXEL := 4.0
const OUTLINE := Color("000000")
const GRASS := Color("2f8f3a")
const GRASS_LIGHT := Color("38a044")
const PEN_GROUND := Color("c9b27a")
const PEN_DOT := Color("b09a62")
const FENCE := Color("8b5a2b")
const POST := Color("5a3a1a")
const GATE_POST := Color("f8b800")
const GLOW := Color("f8d800")
const POND := Color("2c78d8")
const POND_LIGHT := Color("5aa4f0")
const FLOWER_COLORS := [Color("f8d800"), Color("ff9ac8"), Color("fcfcfc")]
const PATH := Color("b8a06a")
const BARN := Color("b52a26")
const BARN_DARK := Color("8a1d1a")
const BARN_PLANK := Color("9a1f1c")
const ROOF := Color("5a4a42")
const ROOF_LINE := Color("46382f")
const TRIM := Color("fcfcfc")
const STONE := Color("8a8a8a")
const SILO := Color("b8bcc8")
const SILO_LIGHT := Color("dfe3ee")
const HAY_COLOR := Color("e8c24a")
const HAY_DARK := Color("c49a28")
const CONFETTI := Palette.SLOTS + [ Color("f8d800"), Color("fcfcfc")]

## Where the barn parts are, from the top-left corner of the barn picture (world pixels).
const BARN_SIZE := Vector2(56.0, 46.0)         # The walls and the roof, without the silo and the vane.
const BARN_WALL_TOP := 14.0
const SILO_W := 13.0

## The sheepdog, 20 x 14, looking to the right. `b` the body (the color of the player), `d` its dark ear, `w` the cream
## muzzle, belly and paws, `c` the white collar, `t` the tongue.
const DOG := [
	"....................",
	"..o..........oo.....",
	"..oo........odo.....",
	"...oo..oooooodddo...",
	"...obooobbbbbodddo..",
	"...obbbbbbbbbboooooo",
	"...obbbbbbbbbcbbbbbo",
	"...obbbbbbbbbcbebbwo",
	"....obbbbbbbbcbbwwwn",
	"....obbbbbbbbbbbwwwo",
	"....obwwwwbbbbbboooo",
	"....obwoobwoobwoo...",
	"....obwo.obwo.obwo..",
	"....oooo.oooo.oooo..",
]
## The sheep, 18 x 14. `f` the wool, `g` its shadow, `k` the dark face and legs.
const SHEEP := [
	"....oooooooo......",
	"..ooffffffffoo....",
	".offfffffffffffo..",
	"offfffffffffffffo.",
	"offfffffffffffoooo",
	"offfffffffffffokko",
	"offfffffffffffokeo",
	".offfffffffffgfokk",
	".offffffffffggfoo.",
	"..offgggggggggoo..",
	"...oooooooooooo...",
	"....okko...okko...",
	"....okko...okko...",
	"....oooo...oooo...",
]
const HEART := [".rr.rr.", "rrrrrrr", "rrrrrrr", ".rrrrr.", "..rrr..", "...r..."]
const SNOOZE := ["zzzz", "...z", "..z.", ".z..", "zzzz"]
const STAR := ["...y...", "...y...", "..yyy..", "yyyyyyy", "..yyy..", "...y...", "...y..."]
const BUSH := [".....gggg.....", "...gggggggg...", ".ggggpgggggg..", "gggggggggpggg.", "gggggggggggggg"]

const KEY := {
	"o": Color("000000"), "b": Palette.TOY_RED, "d": Color("7a1c24"), "w": Color("fcf0dc"), "c": Color("fcfcfc"),
	"t": Color("ff7a9a"), "e": Color("000000"), "n": Color("000000"),
	"f": Color("fcfcfc"), "g": Color("cfd8e8"), "k": Color("3a3a3a"),
	"r": Palette.TONGUE_PINK, "z": Color("9ad0ff"), "y": Color("f8d800"), "p": Color("ff9ac8"),
}
const BUSH_KEY := {"g": Color("237a30"), "p": Color("ff9ac8")}


## The picture of a thing: "dog" (with the color of the player), "sheep", "heart", "snooze", "star",
## "bush", "tree", "pine", "hay",
## "bales", "rock". It is cached by the caller.
static func image(kind: String, color := Color.WHITE) -> Image:
	match kind:
		"dog":
			return _from_rows(DOG, _dog_key(color))
		"sheep":
			return _from_rows(SHEEP, KEY)
		"heart":
			return _from_rows(HEART, KEY)
		"snooze":
			return _from_rows(SNOOZE, KEY)
		"star":
			return _from_rows(STAR, KEY)
		"bush":
			return _from_rows(BUSH, BUSH_KEY, true)
		"tree":
			return _tree()
		"pine":
			return _pine()
		"hay":
			return _hay()
		"bales":
			return _bales()
		"rock":
			return _rock()
	return Image.create(1, 1, false, Image.FORMAT_RGBA8)


static func _dog_key(color: Color) -> Dictionary:
	var k := KEY.duplicate()
	k["b"] = color
	k["d"] = color.darkened(0.4)
	return k


static func _from_rows(rows: Array, key: Dictionary, outline := false) -> Image:
	var w: int = String(rows[0]).length()
	var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if key.has(ch):
				img.set_pixel(x, y, key[ch])
	return _outlined(img) if outline else img


## The same picture with a one pixel black line around it (the lines of the text pictures are already in the text).
static func _outlined(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(1, 1))
	var base := out.duplicate() as Image
	for y in h + 2:
		for x in w + 2:
			if base.get_pixel(x, y).a > 0.0:
				continue
			for n in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
				if n.x >= 0 and n.y >= 0 and n.x < w + 2 and n.y < h + 2 and base.get_pixelv(n).a > 0.0:
					out.set_pixel(x, y, OUTLINE)
					break
	return out


static func _disc(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() \
					and (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r + r:
				img.set_pixel(x, y, color)


## A round tree: a crown with light spots and a few red apples, on a trunk. 24 x 28 with the outline.
static func _tree() -> Image:
	var img := Image.create(22, 26, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(9, 17, 4, 8), Color("6b4420"))
	_disc(img, 11, 10, 9, Color("1f7a2e"))
	_disc(img, 8, 7, 4, Color("2f9a40"))
	img.set_pixel(14, 6, Color("ff4040"))
	img.set_pixel(9, 13, Color("ff4040"))
	img.set_pixel(15, 12, Color("ff4040"))
	return _outlined(img)


## A pine: three steps of green on a trunk. 22 x 27 with the outline.
static func _pine() -> Image:
	var img := Image.create(20, 25, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(9, 20, 2, 5), Color("6b4420"))
	for step in 3:
		var top := step * 6
		var half := 4 + step * 2
		for row in 8:
			var w := mini(half, 1 + row * (half - 1) / 7)
			img.fill_rect(Rect2i(10 - w, top + row, w * 2, 1), Color("17692a"))
	return _outlined(img)


## A hay stack: a heap with a few darker stripes. 24 x 20 with the outline.
static func _hay() -> Image:
	var img := Image.create(22, 18, false, Image.FORMAT_RGBA8)
	for row in 18:
		var half := 4 + row * 7 / 17
		img.fill_rect(Rect2i(11 - half, row, half * 2, 1), HAY_COLOR)
	for x in [5, 9, 13, 17]:
		for y in range(6, 17):
			if img.get_pixel(x, y).a > 0.0 and (x + y) % 3 == 0:
				img.set_pixel(x, y, HAY_DARK)
	return _outlined(img)


## Four square bales, two below and two above. 32 x 24 with the outline.
static func _bales() -> Image:
	var img := Image.create(30, 22, false, Image.FORMAT_RGBA8)
	for spot in [Vector2i(0, 11), Vector2i(15, 11), Vector2i(7, 0)]:
		img.fill_rect(Rect2i(spot.x, spot.y, 14, 10), HAY_COLOR)
		img.fill_rect(Rect2i(spot.x, spot.y + 4, 14, 1), HAY_DARK)
		img.fill_rect(Rect2i(spot.x + 4, spot.y, 1, 10), HAY_DARK)
		img.fill_rect(Rect2i(spot.x + 9, spot.y, 1, 10), HAY_DARK)
	return _outlined(img)


static func _rock() -> Image:
	var img := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 1, 12, 7), Color("8a8a8a"))
	img.fill_rect(Rect2i(1, 0, 10, 1), Color("8a8a8a"))
	img.fill_rect(Rect2i(2, 2, 4, 2), Color("c4c4c4"))
	return _outlined(img)


# ---- Drawing helpers (the pixel layer, units of the 1920 x 1080 screen) ----

## One flower: two pixels of color on the grass.
static func draw_flower(ci: CanvasItem, pos: Vector2, color_index: int) -> void:
	ci.draw_rect(Rect2(pos, Vector2(WORLD_PIXEL * 2.0, WORLD_PIXEL)), FLOWER_COLORS[color_index % FLOWER_COLORS.size()])


## The grass of the field with a one pixel black line around it.
static func draw_grass(ci: CanvasItem, field: Rect2, tufts: Array[Vector2]) -> void:
	ci.draw_rect(field.grow(WORLD_PIXEL), OUTLINE)
	ci.draw_rect(field, GRASS)
	for t in tufts:
		ci.draw_rect(Rect2(t, Vector2(WORLD_PIXEL * 2.0, WORLD_PIXEL)), GRASS_LIGHT)


## The pond: an ellipse of blue with a lighter shine.
static func draw_pond(ci: CanvasItem, center: Vector2, size: Vector2) -> void:
	var half := size * 0.5
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(Shell.snap(center + Vector2(cos(a) * half.x, sin(a) * half.y)))
	ci.draw_colored_polygon(_grow_polygon(pts, center, WORLD_PIXEL), OUTLINE)
	ci.draw_colored_polygon(pts, POND)
	ci.draw_rect(Rect2(Shell.snap(center + Vector2(-half.x * 0.55, -half.y * 0.5)), Vector2(WORLD_PIXEL * 7.0, WORLD_PIXEL * 2.0)),
			POND_LIGHT)


static func _grow_polygon(pts: PackedVector2Array, center: Vector2, by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (p - center).normalized() * by)
	return out


## The path of dots from the middle of the field to the gate, so that a child sees where the sheep go.
static func draw_path(ci: CanvasItem, from_x: float, to_x: float, y: float) -> void:
	var x := from_x
	while x < to_x:
		ci.draw_rect(Rect2(Vector2(x, y), Vector2(WORLD_PIXEL * 2.0, WORLD_PIXEL)), PATH)
		x += WORLD_PIXEL * 6.0


## The pen: sand, the fence with the gate in the left side, and the gate posts. `glow` makes the fence yellow (a sheep came in).
static func draw_pen(ci: CanvasItem, pen: Rect2, gate: float, wall: float, glow: bool) -> void:
	ci.draw_rect(pen.grow(WORLD_PIXEL), OUTLINE)
	ci.draw_rect(pen, PEN_GROUND)
	var x := pen.position.x + wall + WORLD_PIXEL * 3.0
	while x < pen.end.x - wall:
		var y := pen.position.y + wall + WORLD_PIXEL * 4.0
		while y < pen.end.y - wall:
			ci.draw_rect(Rect2(Vector2(x, y), Vector2.ONE * WORLD_PIXEL), PEN_DOT)
			y += WORLD_PIXEL * 9.0
		x += WORLD_PIXEL * 7.0
	var rail := GLOW if glow else FENCE
	var gate_top := pen.position.y + (pen.size.y - gate) * 0.5
	for r in [Rect2(pen.position, Vector2(pen.size.x, wall)),
			Rect2(Vector2(pen.position.x, pen.end.y - wall), Vector2(pen.size.x, wall)),
			Rect2(Vector2(pen.end.x - wall, pen.position.y), Vector2(wall, pen.size.y)),
			Rect2(pen.position, Vector2(wall, gate_top - pen.position.y)),
			Rect2(Vector2(pen.position.x, gate_top + gate), Vector2(wall, pen.end.y - gate_top - gate))]:
		ci.draw_rect(r, rail)
	var post_x := pen.position.x
	while post_x <= pen.end.x - wall:
		for y in [pen.position.y - WORLD_PIXEL, pen.end.y - wall - WORLD_PIXEL]:
			ci.draw_rect(Rect2(Vector2(post_x, y), Vector2(WORLD_PIXEL * 2.0, wall + WORLD_PIXEL * 2.0)), POST)
		post_x += WORLD_PIXEL * 8.0
	for y in [gate_top - WORLD_PIXEL * 3.0, gate_top + gate - WORLD_PIXEL * 2.0]:
		ci.draw_rect(Rect2(Vector2(pen.position.x - WORLD_PIXEL, y), Vector2(wall + WORLD_PIXEL * 2.0, WORLD_PIXEL * 5.0)), GATE_POST)


## The barn with a silo, the weather vane and the hayloft: `origin` is the top-left corner of the walls and the roof (the vane
## and the silo stand outside this box). It is 56 x 46 world pixels.
static func draw_barn(ci: CanvasItem, origin: Vector2) -> void:
	var w := WORLD_PIXEL
	var o := origin
	# The silo, left of the barn.
	ci.draw_rect(Rect2(o + Vector2(-SILO_W - 1.0, 6.0) * w, Vector2(SILO_W, 38.0) * w).grow(w), OUTLINE)
	ci.draw_rect(Rect2(o + Vector2(-SILO_W - 1.0, 6.0) * w, Vector2(SILO_W, 38.0) * w), SILO)
	ci.draw_rect(Rect2(o + Vector2(-SILO_W + 1.0, 8.0) * w, Vector2(3.0, 34.0) * w), SILO_LIGHT)
	ci.draw_rect(Rect2(o + Vector2(-SILO_W - 1.0, 2.0) * w, Vector2(SILO_W, 4.0) * w), ROOF)
	# The walls with their planks, and the stone base.
	ci.draw_rect(Rect2(o + Vector2(0.0, BARN_WALL_TOP) * w, Vector2(56.0, 32.0) * w).grow(w), OUTLINE)
	ci.draw_rect(Rect2(o + Vector2(0.0, BARN_WALL_TOP) * w, Vector2(56.0, 32.0) * w), BARN)
	for px in range(4, 56, 5):
		ci.draw_rect(Rect2(o + Vector2(float(px), BARN_WALL_TOP + 2.0) * w, Vector2(1.0, 26.0) * w), BARN_PLANK)
	ci.draw_rect(Rect2(o + Vector2(0.0, 42.0) * w, Vector2(56.0, 4.0) * w), STONE)
	# The roof: a gambrel, wide at the bottom, with the white trim under it.
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-3.0, 15.0) * w, o + Vector2(6.0, 3.0) * w, o + Vector2(14.0, -5.0) * w,
			o + Vector2(42.0, -5.0) * w, o + Vector2(50.0, 3.0) * w, o + Vector2(59.0, 15.0) * w]), ROOF)
	for ry in [5.0, 12.0]:
		ci.draw_rect(Rect2(o + Vector2(2.0, ry) * w, Vector2(52.0, 1.0) * w), ROOF_LINE)
	ci.draw_rect(Rect2(o + Vector2(-3.0, 14.0) * w, Vector2(62.0, 2.0) * w), TRIM)
	# The hayloft window with hay in it.
	ci.draw_rect(Rect2(o + Vector2(22.0, 2.0) * w, Vector2(13.0, 10.0) * w), HAY_COLOR)
	ci.draw_rect(Rect2(o + Vector2(22.0, 7.0) * w, Vector2(13.0, 1.0) * w), HAY_DARK)
	ci.draw_rect(Rect2(o + Vector2(28.0, 2.0) * w, Vector2(1.0, 10.0) * w), TRIM)
	# The double doors with white crosses.
	ci.draw_rect(Rect2(o + Vector2(14.0, 22.0) * w, Vector2(29.0, 22.0) * w), BARN_DARK)
	ci.draw_rect(Rect2(o + Vector2(14.0, 22.0) * w, Vector2(29.0, 22.0) * w), TRIM, false, w)
	ci.draw_rect(Rect2(o + Vector2(28.0, 22.0) * w, Vector2(1.0, 22.0) * w), TRIM)
	for half in [14.0, 29.0]:
		for k in 22:
			var fx := float(k) * 13.0 / 22.0
			ci.draw_rect(Rect2(o + Vector2(half + fx, 22.0 + k) * w, Vector2(1.0, 1.0) * w), TRIM)
			ci.draw_rect(Rect2(o + Vector2(half + 13.0 - fx, 22.0 + k) * w, Vector2(1.0, 1.0) * w), TRIM)
	# The weather vane.
	ci.draw_rect(Rect2(o + Vector2(28.0, -12.0) * w, Vector2(1.0, 7.0) * w), OUTLINE)
	ci.draw_rect(Rect2(o + Vector2(24.0, -13.0) * w, Vector2(9.0, 1.0) * w), GATE_POST)
	ci.draw_rect(Rect2(o + Vector2(32.0, -14.0) * w, Vector2(3.0, 3.0) * w), GATE_POST)


## What the barn blocks, in the same units as the picture: the walls (not the roof) and the silo.
static func barn_blocks(origin: Vector2) -> Array[Rect2]:
	return [Rect2(origin + Vector2(0.0, BARN_WALL_TOP) * WORLD_PIXEL, Vector2(56.0, 32.0) * WORLD_PIXEL),
			Rect2(origin + Vector2(-SILO_W - 1.0, 6.0) * WORLD_PIXEL, Vector2(SILO_W, 38.0) * WORLD_PIXEL)]

