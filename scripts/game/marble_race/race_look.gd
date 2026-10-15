extends RefCounted
## The look of The Amazing Race (REQ-MR-44 to 47): a flat pixel world seen from above, in one of three themes (candy, space,
## jungle) that the player picks in the settings view. The cars look the same in every theme; the road, the walls, the ground
## and the obstacles are the theme.
## The board (the road with its walls and the finish line) is drawn once into an image of world pixels (`render()`); the game
## draws a window of it every frame. One meter is `PX` world pixels. The road is filled with pattern tiles in runs, row by row,
## so that no pixel is tested one by one (a long track is about 1400x1300 world pixels).

const PX := 8                 # World pixels in one meter (32 screen units).
const TILE := 120             # The pattern tiles are 120x120 world pixels: 10, 12 and 24 all divide it.
const WALL_PX := 7            # The thickness of a wall: seven world pixels (REQ-GM-47l).
const MARGIN_M := 3.0         # Space around the track in the board image, in meters.
const FINISH_CELL := 4        # A cell of the finish line, in world pixels.
const DEFAULT_THEME := "candy"
const OUTLINE := Color("101018")   # The outline of a car.

## The colors of a theme. The ground is a chess board of two tones (12 world pixel squares), the road has two tones and marks,
## the wall has two colors (stripes or leaves), `outline` is the dark edge of the road and of the obstacles.
const THEMES := {
	"candy": {"ground_a": Color("f8a8d0"), "ground_b": Color("f090c0"), "road_a": Color("fff0d8"), "road_b": Color("f8e4c8"),
			"mark": Color("f8b8d8"), "wall_a": Color("fcfcfc"), "wall_b": Color("e8286c"), "outline": Color("8c1c50"),
			"obstacles": ["lolly", "gumdrop", "cupcake"]},
	"space": {"ground_a": Color("0c0c28"), "ground_b": Color("080820"), "road_a": Color("6c7488"), "road_b": Color("646c80"),
			"mark": Color("4c5468"), "wall_a": Color("3ddcff"), "wall_b": Color("1c88b0"), "outline": Color("101040"),
			"obstacles": ["asteroid", "satellite", "crater"]},
	"jungle": {"ground_a": Color("145820"), "ground_b": Color("10501c"), "road_a": Color("b88048"), "road_b": Color("b07844"),
			"mark": Color("8c5c30"), "wall_a": Color("2c8c30"), "wall_b": Color("58b848"), "outline": Color("06280c"),
			"obstacles": ["log", "boulder", "tiki"]},
}

## A car: 7x12 world pixels, pointing up. `K` outline, `B` the player color, `W` the windscreen, `D` the engine cover.
const CAR := [
	"..KKK..",
	".KBBBK.",
	"KKBBBKK",
	"KWWWWWK",
	"KWWWWWK",
	"KBBBBBK",
	"KBBBBBK",
	"KBBBBBK",
	"KKBBBKK",
	"KKDDDKK",
	".KDDDK.",
	"..KKK..",
]
const CAR_GLASS := Color("bfe8ff")
const CAR_COVER := Color("303040")


static func look(theme: String) -> Dictionary:
	return THEMES.get(theme, THEMES[DEFAULT_THEME])


## The theme that `theme` stands for: an unknown name gives the default.
static func theme_or_default(theme: String) -> String:
	return theme if THEMES.has(theme) else DEFAULT_THEME


# ---- Cars and obstacles ----

static func car_image(color: Color) -> Image:
	var img := Image.create(CAR[0].length(), CAR.size(), false, Image.FORMAT_RGBA8)
	for y in CAR.size():
		for x in CAR[y].length():
			var c: String = CAR[y][x]
			match c:
				"K":
					img.set_pixel(x, y, OUTLINE)
				"B":
					img.set_pixel(x, y, color)
				"W":
					img.set_pixel(x, y, CAR_GLASS)
				"D":
					img.set_pixel(x, y, CAR_COVER)
	return img


## The picture of an obstacle of `theme` (one of its `obstacles`). It is about 13x13 world pixels (the obstacle is 1.8 m wide)
## with a dark outline of the theme.
static func obstacle_image(theme: String, kind: String) -> Image:
	var img := Image.create(15, 16, false, Image.FORMAT_RGBA8)
	var area := _paint(img, kind)
	return _outlined(img.get_region(area), look(theme).outline)


static func _paint(img: Image, kind: String) -> Rect2i:
	match kind:
		"lolly":
			_disc(img, 5.5, 5.5, 5.5, 5.5, Color("e8286c"))
			_disc(img, 5.5, 5.5, 4.0, 4.0, Color("fcfcfc"))
			_disc(img, 5.5, 5.5, 2.5, 2.5, Color("e8286c"))
			_box(img, 5, 11, 2, 3, Color("fcfcfc"))
			return Rect2i(0, 0, 11, 14)
		"gumdrop":
			_disc(img, 5.5, 5.5, 5.5, 5.5, Color("48c838"))
			_box(img, 0, 8, 11, 2, Color("2c8c20"))
			for p in [Vector2i(3, 2), Vector2i(4, 1), Vector2i(3, 3), Vector2i(7, 4), Vector2i(6, 6), Vector2i(2, 5)]:
				img.set_pixelv(p, Color("b0f090"))
			return Rect2i(0, 0, 11, 10)
		"cupcake":
			for y in range(6, 12):
				var inset := (y - 6) / 3
				_box(img, inset, y, 11 - inset * 2, 1, Color("c88040") if (y % 2 == 0) else Color("a0602c"))
			_disc(img, 5.5, 4.5, 5.5, 4.0, Color("f8a0c8"))
			for p in [Vector2i(3, 3), Vector2i(7, 4), Vector2i(5, 6), Vector2i(2, 5), Vector2i(8, 2)]:
				img.set_pixelv(p, Color("fcfcfc"))
			_disc(img, 5.5, 1.5, 1.5, 1.5, Color("e83838"))
			return Rect2i(0, 0, 11, 12)
		"asteroid":
			_disc(img, 5.5, 5.5, 5.5, 5.5, Color("8c8478"))
			_disc(img, 3.5, 4.0, 1.6, 1.6, Color("5c5448"))
			_disc(img, 7.5, 7.0, 1.6, 1.6, Color("5c5448"))
			_disc(img, 7.0, 3.0, 1.1, 1.1, Color("5c5448"))
			for p in [Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(4, 0)]:
				img.set_pixelv(p, Color("b8b0a0"))
			return Rect2i(0, 0, 11, 11)
		"satellite":
			_box(img, 0, 1, 4, 8, Color("3070e0"))
			_box(img, 9, 1, 4, 8, Color("3070e0"))
			for x in [1, 3, 10, 12]:
				_box(img, x, 1, 1, 8, Color("70a0f8"))
			_box(img, 4, 2, 5, 6, Color("e0e8f0"))
			img.set_pixel(6, 5, Color("e83838"))
			img.set_pixel(6, 1, Color("e0e8f0"))
			img.set_pixel(6, 0, Color("e83838"))
			return Rect2i(0, 0, 13, 10)
		"crater":
			_disc(img, 5.5, 5.5, 5.5, 5.5, Color("8890a8"))
			_disc(img, 5.5, 5.5, 4.0, 4.0, Color("4c5468"))
			_disc(img, 6.5, 6.5, 2.6, 2.6, Color("2c3248"))
			for p in [Vector2i(1, 4), Vector2i(2, 2), Vector2i(4, 1)]:
				img.set_pixelv(p, Color("c0c8dc"))
			return Rect2i(0, 0, 11, 11)
		"log":
			_box(img, 2, 0, 11, 10, Color("7c4a1c"))
			_box(img, 2, 3, 11, 1, Color("5c3410"))
			_box(img, 2, 7, 11, 1, Color("5c3410"))
			_disc(img, 2.5, 5.0, 2.5, 5.0, Color("c89050"))
			_disc(img, 2.5, 5.0, 1.2, 2.6, Color("a0702c"))
			return Rect2i(0, 0, 13, 10)
		"boulder":
			_disc(img, 5.5, 5.0, 5.5, 5.0, Color("8c9490"))
			for y in range(7, 10):
				for x in 11:
					if img.get_pixel(x, y).a > 0.0:
						img.set_pixel(x, y, Color("5c6460"))
			for p in [Vector2i(2, 2), Vector2i(3, 1), Vector2i(2, 3), Vector2i(4, 1), Vector2i(1, 4)]:
				img.set_pixelv(p, Color("c0c8c4"))
			return Rect2i(0, 0, 11, 10)
		"tiki":
			_box(img, 0, 1, 9, 11, Color("a86c2c"))
			_box(img, 0, 0, 9, 2, Color("e83838"))
			for x in [1, 4, 7]:
				_box(img, x, 0, 1, 1, Color("f8b800"))
			_box(img, 1, 4, 2, 2, Color("fcfcfc"))
			_box(img, 6, 4, 2, 2, Color("fcfcfc"))
			img.set_pixel(2, 5, Color("e83838"))
			img.set_pixel(6, 5, Color("e83838"))
			_box(img, 2, 8, 5, 2, Color("301808"))
			for x in [3, 5]:
				img.set_pixel(x, 8, Color("fcfcfc"))
			return Rect2i(0, 0, 9, 12)
	_disc(img, 5.5, 5.5, 5.5, 5.5, Color("fcfcfc"))   # An unknown name: a plain disc.
	return Rect2i(0, 0, 11, 11)


## `src` with a one pixel outline around it: every empty pixel that touches a painted one (up, down, left or right) gets `color`.
static func _outlined(src: Image, color: Color) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(1, 1))
	for y in h + 2:
		for x in w + 2:
			if out.get_pixel(x, y).a > 0.0:
				continue
			for n in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
				if n.x >= 1 and n.y >= 1 and n.x <= w and n.y <= h and out.get_pixelv(n).a > 0.0:
					out.set_pixel(x, y, color)
					break
	return out


static func _disc(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, color)


static func _box(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), color)


# ---- Pattern tiles ----

## The ground of the theme: a chess board of 12 world pixel squares. Space has stars on it.
static func ground_tile(theme: String) -> Image:
	var c := look(theme)
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			img.set_pixel(x, y, c.ground_a if ((x / 12) + (y / 12)) % 2 == 0 else c.ground_b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	if theme == "space":
		for i in 190:
			img.set_pixel(rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), Color("fcfcfc") if i % 3 != 0 else Color("7c7c7c"))
	elif theme == "jungle":
		for i in 90:
			var x := rng.randi_range(1, TILE - 2)
			var y := rng.randi_range(1, TILE - 2)
			img.set_pixel(x, y, Color("0c4818"))
			img.set_pixel(x, y - 1, Color("2c8c30"))
	else:
		for i in 40:
			img.set_pixel(rng.randi_range(1, TILE - 2), rng.randi_range(1, TILE - 2), Color("fcfcfc"))
	return img


## The road: two tones in 10 pixel squares, and the marks of the theme (pink dashes, metal panels, dirt specks).
static func road_tile(theme: String) -> Image:
	var c := look(theme)
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for y in TILE:
		for x in TILE:
			img.set_pixel(x, y, c.road_a if ((x / 10) + (y / 10)) % 2 == 0 else c.road_b)
	match theme:
		"space":
			for y in TILE:
				for x in TILE:
					if y % 6 == 0 or (x + ((y / 6) % 2) * 5) % 10 == 0:
						img.set_pixel(x, y, c.mark)
		"jungle":
			for i in 260:
				img.set_pixel(rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), c.mark)
		_:
			for y in range(0, TILE, 20):
				for x in TILE:
					if (x / 6) % 2 == 0:
						img.set_pixel(x, y, c.mark)
						img.set_pixel(x, y + 1, c.mark)
	return img


## The wall: diagonal stripes of two colors (candy and space), leaves and dark gaps (jungle).
static func wall_tile(theme: String) -> Image:
	var c := look(theme)
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for y in TILE:
		for x in TILE:
			if theme == "jungle":
				var n := rng.randf()
				img.set_pixel(x, y, c.wall_b if n < 0.18 else (Color("145418") if n > 0.9 else c.wall_a))
			else:
				var period := 5 if theme == "candy" else 4
				img.set_pixel(x, y, c.wall_a if ((x + y) / period) % 2 == 0 else c.wall_b)
	return img


# ---- The board ----

## The board of a track as {image, origin}: `image` has the outline, the walls, the road and the finish line on a transparent
## ground, `origin` is the world pixel of its top-left corner (a world pixel is 1/PX of a meter). `points` and `half_width`
## are the line and the half-width of the track in meters, and the finish line stands at `finish_at`, across `finish_dir`.
static func render(theme: String, points: Array[Vector2], half_width: float, finish_at: Vector2,
		finish_dir: Vector2) -> Dictionary:
	var c := look(theme)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	var reach := half_width + float(WALL_PX + 1) / PX + MARGIN_M
	var origin := Vector2i(floori((lo.x - reach) * PX), floori((lo.y - reach) * PX))
	var far := Vector2i(ceili((hi.x + reach) * PX), ceili((hi.y + reach) * PX))
	var img := Image.create(far.x - origin.x, far.y - origin.y, false, Image.FORMAT_RGBA8)
	var line: Array[Vector2] = []
	for p in points:
		line.append(p * PX - Vector2(origin))
	var hw := half_width * PX
	_fill_line(img, line, hw + WALL_PX + 1, null, c.outline)
	_fill_line(img, line, hw + WALL_PX, wall_tile(theme), Color.BLACK)
	_fill_line(img, line, hw, null, c.outline)
	_fill_line(img, line, hw - 1.0, road_tile(theme), Color.BLACK)
	_finish_line(img, finish_at * PX - Vector2(origin), finish_dir, hw - 1.0)
	return {"image": img, "origin": origin}


## Every point within `radius` of the line `pts`, in a color or from a pattern tile.
static func _fill_line(img: Image, pts: Array[Vector2], radius: float, tile: Image, color: Color) -> void:
	for i in pts.size() - 1:
		_fill_capsule(img, pts[i], pts[i + 1], radius, tile, color)


static func _fill_capsule(img: Image, a: Vector2, b: Vector2, r: float, tile: Image, color: Color) -> void:
	var w := img.get_width()
	var y0 := maxi(0, floori(minf(a.y, b.y) - r))
	var y1 := mini(img.get_height() - 1, ceili(maxf(a.y, b.y) + r))
	for y in range(y0, y1 + 1):
		var span := row_span(a, b, r, y + 0.5)
		if span.x > span.y:
			continue
		var x0 := maxi(0, ceili(span.x - 0.5))
		var x1 := mini(w - 1, floori(span.y - 0.5))
		if x1 < x0:
			continue
		if tile == null:
			img.fill_rect(Rect2i(x0, y, x1 - x0 + 1, 1), color)
			continue
		var x := x0
		while x <= x1:
			var tx := x % TILE
			var n := mini(TILE - tx, x1 - x + 1)
			img.blit_rect(tile, Rect2i(tx, y % TILE, n, 1), Vector2i(x, y))
			x += n


## The x range (x = start, y = end; start > end when it is empty) of the row at height `py` that is within `r` of the segment
## a-b. A capsule cuts a row in one piece, so the piece is the hull of the cut of the two end circles and the cut of the slab.
static func row_span(a: Vector2, b: Vector2, r: float, py: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for c in [a, b]:
		var dy: float = py - c.y
		if absf(dy) <= r:
			var h := sqrt(r * r - dy * dy)
			lo = minf(lo, c.x - h)
			hi = maxf(hi, c.x + h)
	var ab := b - a
	var seg_len := ab.length()
	if seg_len > 0.0001:
		var d := ab / seg_len
		var ky := py - a.y
		# With t = x - a.x: 0 <= d.x * t + d.y * ky <= seg_len, and -r <= -d.y * t + d.x * ky <= r.
		var t_lo := -INF
		var t_hi := INF
		var ok := true
		for k in [[d.x, -d.y * ky, seg_len - d.y * ky], [-d.y, -r - d.x * ky, r - d.x * ky]]:
			var coef: float = k[0]
			if absf(coef) < 0.000001:
				if k[1] > 0.0 or k[2] < 0.0:
					ok = false
				continue
			var t0: float = k[1] / coef
			var t1: float = k[2] / coef
			t_lo = maxf(t_lo, minf(t0, t1))
			t_hi = minf(t_hi, maxf(t0, t1))
		if ok and t_lo <= t_hi:
			lo = minf(lo, a.x + t_lo)
			hi = maxf(hi, a.x + t_hi)
	return Vector2(lo, hi)


## A band of black and white cells across the road, `FINISH_CELL` pixels each, two rows of them, at `at` (world pixels).
static func _finish_line(img: Image, at: Vector2, dir: Vector2, half_road: float) -> void:
	var d := dir.normalized()
	var perp := Vector2(-d.y, d.x)
	var reach := int(half_road + FINISH_CELL * 2.0) + 2
	for y in range(maxi(0, int(at.y) - reach), mini(img.get_height(), int(at.y) + reach + 1)):
		for x in range(maxi(0, int(at.x) - reach), mini(img.get_width(), int(at.x) + reach + 1)):
			var rel := Vector2(x + 0.5, y + 0.5) - at
			var u := rel.dot(d)
			var v := rel.dot(perp)
			if absf(u) >= FINISH_CELL or absf(v) >= half_road:
				continue
			var cell := floori((u + FINISH_CELL) / FINISH_CELL) + floori((v + half_road) / FINISH_CELL)
			img.set_pixel(x, y, Color("fcfcfc") if cell % 2 == 0 else OUTLINE)
