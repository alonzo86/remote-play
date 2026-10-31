extends RefCounted
## Helpers for the sprites that the look files of the games build in code (issue #294).


## The picture with a one pixel line of `color` around its colored pixels. The result is 2 pixels wider and higher than `src`.
## A pixel gets the line when it is empty (alpha 0) and one of its 4 neighbors (left, right, up, down) is colored in `src`;
## the line pixels themselves do not count as colored, so the line is one pixel wide. It reads the alpha bytes of the
## picture once and makes no object for a pixel: the textures of a game are built when the game starts, on a TV box.
static func outlined(src: Image, color: Color) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(1, 1))
	var ow := w + 2
	var oh := h + 2
	var alpha := PackedByteArray()
	alpha.resize(ow * oh)
	var data := out.get_data()
	for i in ow * oh:
		alpha[i] = data[i * 4 + 3]
	for y in oh:
		for x in ow:
			var i := y * ow + x
			if alpha[i] > 0:
				continue
			if (x > 0 and alpha[i - 1] > 0) or (x < ow - 1 and alpha[i + 1] > 0) \
					or (y > 0 and alpha[i - ow] > 0) or (y < oh - 1 and alpha[i + ow] > 0):
				out.set_pixel(x, y, color)
	return out
