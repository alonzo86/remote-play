extends RefCounted
## The look of the picture and the pots of Paint Grab (REQ-PG-22, 23): the colors of a tile and the pictures of the pots. A tile
## that has no owner shows a faint ghost of its part of the picture;
## a painted tile keeps the shade of that part in the color of its
## owner, so the picture appears in the colors of the players as the floor fills.

const PaintPicture = preload("res://scripts/game/paint_grab/paint_picture.gd")
const PaintPots = preload("res://scripts/game/paint_grab/paint_pots.gd")
const Palette = preload("res://scripts/game/palette.gd")

const OUTLINE := Color("101018")
const GOLD := Color("ffcd28")
const GOLD_LIGHT := Color("ffe66e")
const GOLD_FRAME := Color("ffd73c")
const ROLLER_FRAME := Color("ffffff")
const POT_SIZE := 11   # World pixels, with the outline.
const GHOST_BODY := Color("9678ff")   # The tints of the hidden picture, as constants: they are used for every tile of a frame.
const GHOST_ACCENT := Color("46dcbe")


## The color of a tile that nobody has painted, for the part `kind` of the picture. `empty` is the color of an empty tile.
static func ghost(kind: int, empty: Color) -> Color:
	match kind:
		PaintPicture.BODY:
			return empty.lerp(GHOST_BODY, 0.22)
		PaintPicture.ACCENT:
			return empty.lerp(GHOST_ACCENT, 0.24)
		PaintPicture.EYE:
			return empty.lerp(Color.WHITE, 0.34)
	return empty.lerp(Color.BLACK, 0.25)


## The color of a tile painted by a player with the color `col`: the body has the color itself, the accent is darker, an eye is
## almost white and the background of the picture is very dark.
static func painted(kind: int, col: Color) -> Color:
	match kind:
		PaintPicture.BODY:
			return col
		PaintPicture.ACCENT:
			return col.lerp(Color.BLACK, 0.28)
		PaintPicture.EYE:
			return col.lerp(Color.WHITE, 0.85)
	return col.lerp(Color.BLACK, 0.72)


## The picture of a pot, 11 x 11 world pixels with a black outline.
static func pot_image(kind: String) -> Image:
	var img := Image.create(POT_SIZE - 2, POT_SIZE - 2, false, Image.FORMAT_RGBA8)
	if kind == PaintPots.ROLLER:
		var stripes := [Palette.TOY_RED, Color("fabe28"), Color("50c864"), Color("468ce6")]
		for i in stripes.size():
			img.fill_rect(Rect2i(1 + i * 2, 2, 2, 7), stripes[i])
		img.fill_rect(Rect2i(0, 0, 9, 2), Color("dcdce6"))
	else:
		img.fill_rect(Rect2i(1, 4, 7, 5), GOLD)
		img.fill_rect(Rect2i(0, 2, 9, 2), GOLD_LIGHT)
		img.set_pixel(1, 0, GOLD_LIGHT)
		img.set_pixel(7, 0, GOLD_LIGHT)
	return _outlined(img)


static func _outlined(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(1, 1))
	var painted_px := out.duplicate() as Image
	for y in h + 2:
		for x in w + 2:
			if painted_px.get_pixel(x, y).a > 0.0:
				continue
			for n in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
				if n.x >= 0 and n.y >= 0 and n.x < w + 2 and n.y < h + 2 and painted_px.get_pixelv(n).a > 0.0:
					out.set_pixel(x, y, OUTLINE)
					break
	return out
