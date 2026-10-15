extends RefCounted
## The look of The Amazing Race (REQ-MR-44 to 47): a flat pixel world seen from above, in one of three themes (candy, space,
## jungle) that the player picks in the settings view. The cars look the same in every theme; the road, the walls, the ground
## and the obstacles are the theme.
## The board (the road with its walls and the finish line) is drawn once into an image of world pixels (`render()`); the game
## draws a window of it every frame. One meter is `PX` world pixels. The outlines are filled in runs, row by row; the road and the
## walls are colored pixel by pixel in the frame of the road, so that their patterns turn with the road.

const PX := 8                 # World pixels in one meter (32 screen units).
const TILE := 120             # The ground tile is 120x120 world pixels: its chess squares of 12 divide it.
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

## A car: 11x16 world pixels, pointing up. `K` outline, `B` the player color with its light `L` and shade `S`, `F` the white
## stripe, `W` the windscreen with a glint `G`, `D` the rear window, `Y` headlights, `R` tail lights, `T` tires.
const CAR := [
	"....KKK....",
	"...KYBYK...",
	"..KBBLBBK..",
	"TTKBBFBBKTT",
	"TTKBLFBBKTT",
	".KWWWWWWWK.",
	".KWGWWWWWK.",
	".KBBBFBBBK.",
	".KBBBFBBBK.",
	".KBLBFBBBK.",
	".KSSSFSSSK.",
	"TTKSSSSSKTT",
	"TTKDDGDDKTT",
	"TKKDDDDDKKT",
	".KRBBBBBRK.",
	"..KKKKKKK..",
]
const CAR_GLASS := Color("bfe8ff")
const CAR_COVER := Color("303040")
const CAR_TIRE := Color("404050")


static func look(theme: String) -> Dictionary:
	return THEMES.get(theme, THEMES[DEFAULT_THEME])


## The theme that `theme` stands for: an unknown name gives the default.
static func theme_or_default(theme: String) -> String:
	return theme if THEMES.has(theme) else DEFAULT_THEME


# ---- Cars and obstacles ----

static func car_image(color: Color) -> Image:
	var colors := {"K": OUTLINE, "B": color, "L": color.lightened(0.35), "S": color.darkened(0.3), "F": Color("fcfcfc"),
			"W": CAR_GLASS, "G": Color("fcfcfc"), "D": CAR_COVER, "Y": Color("f8e060"), "R": Color("e83838"), "T": CAR_TIRE}
	var img := Image.create(CAR[0].length(), CAR.size(), false, Image.FORMAT_RGBA8)
	for y in CAR.size():
		for x in CAR[y].length():
			var c: String = CAR[y][x]
			if colors.has(c):
				img.set_pixel(x, y, colors[c])
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


# ---- The ground ----

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
	_fill_line(img, line, hw + WALL_PX + 1, c.outline)
	var base := 0.0   # The arc length at the start of a piece, so that a pattern goes on along the road.
	var bases: Array[float] = []
	for i in line.size() - 1:
		bases.append(base)
		base += line[i].distance_to(line[i + 1])
	for i in line.size() - 1:
		_shade_piece(img, line[i], line[i + 1], hw + WALL_PX, hw, bases[i], theme, hw)
	_fill_line(img, line, hw, c.outline)
	for i in line.size() - 1:
		_shade_piece(img, line[i], line[i + 1], hw - 1.0, 0.0, bases[i], theme, hw)
	_finish_line(img, finish_at * PX - Vector2(origin), finish_dir, hw - 1.0)
	return {"image": img, "origin": origin}


## Every point within `radius` of the line `pts`, in one color.
static func _fill_line(img: Image, pts: Array[Vector2], radius: float, color: Color) -> void:
	for i in pts.size() - 1:
		_fill_capsule(img, pts[i], pts[i + 1], radius, color)


static func _fill_capsule(img: Image, a: Vector2, b: Vector2, r: float, color: Color) -> void:
	var w := img.get_width()
	var y0 := maxi(0, floori(minf(a.y, b.y) - r))
	var y1 := mini(img.get_height() - 1, ceili(maxf(a.y, b.y) + r))
	for y in range(y0, y1 + 1):
		var span := row_span(a, b, r, y + 0.5)
		if span.x > span.y:
			continue
		var x0 := maxi(0, ceili(span.x - 0.5))
		var x1 := mini(w - 1, floori(span.y - 0.5))
		if x1 >= x0:
			img.fill_rect(Rect2i(x0, y, x1 - x0 + 1, 1), color)


## The points within `r_out` of the piece a-b and not within `r_in` of it (`r_in` 0: all of them), colored by the pattern of the
## theme (`pattern()`). The pattern is cut in the frame of the road: `u` along the piece and `v` across it, so that it turns
## with the road and looks the same at every angle and direction. `half_road` tells the wall (outside it) from the road.
static func _shade_piece(img: Image, a: Vector2, b: Vector2, r_out: float, r_in: float, base: float, theme: String,
		half_road: float) -> void:
	var w := img.get_width()
	var ab := b - a
	var piece_len := ab.length()
	var d := ab / piece_len if piece_len > 0.0001 else Vector2(0, -1)
	var c := look(theme)
	var y0 := maxi(0, floori(minf(a.y, b.y) - r_out))
	var y1 := mini(img.get_height() - 1, ceili(maxf(a.y, b.y) + r_out))
	for y in range(y0, y1 + 1):
		var out_span := row_span(a, b, r_out, y + 0.5)
		if out_span.x > out_span.y:
			continue
		var x0 := maxi(0, ceili(out_span.x - 0.5))
		var x1 := mini(w - 1, floori(out_span.y - 0.5))
		var runs: Array[Vector2i] = [Vector2i(x0, x1)]
		if r_in > 0.0:
			var in_span := row_span(a, b, r_in, y + 0.5)
			var i0 := ceili(in_span.x - 0.5)
			var i1 := floori(in_span.y - 0.5)
			if in_span.x <= in_span.y and i1 >= i0:
				runs = [Vector2i(x0, mini(x1, i0 - 1)), Vector2i(maxi(x0, i1 + 1), x1)]
		for run in runs:
			for x in range(run.x, run.y + 1):
				var rel := Vector2(x + 0.5, y + 0.5) - a
				var u := rel.dot(d)
				var v := rel.x * -d.y + rel.y * d.x
				var dist := absf(v) if (u >= 0.0 and u <= piece_len) else rel.distance_to(d * clampf(u, 0.0, piece_len))
				img.set_pixel(x, y, pattern(theme, c, x, y, base + u, v, dist - half_road))


## The color of the road (`wall` is the depth in the wall, 0 to WALL_PX, or below 0 on the road) at the world pixel (x, y), at `u`
## along the road and `v` across it (both in world pixels). Candy Road: a chess road with pink dashes across it and candy
## cane stripes on the walls. Space Rally: metal panels and glowing stripes. Jungle Run: a dirt road with specks and leafy walls.
static func pattern(theme: String, c: Dictionary, x: int, y: int, u: float, v: float, wall: float) -> Color:
	var ui := floori(u)
	var vi := floori(v)
	if wall >= 0.0:
		if theme == "jungle":
			var n := _hash(x, y) % 100
			return c.wall_b if n < 18 else (Color("145418") if n > 90 else c.wall_a)
		var period := 5 if theme == "candy" else 4
		return c.wall_a if floori((u + wall) / period) % 2 == 0 else c.wall_b
	var tone: Color = c.road_a if (floori(u / 10.0) + floori(v / 10.0)) % 2 == 0 else c.road_b
	match theme:
		"space":
			if posmod(ui, 6) == 0 or posmod(vi + posmod(floori(u / 6.0), 2) * 5, 10) == 0:
				return c.mark
		"jungle":
			if _hash(x, y) % 100 < 4:
				return c.mark
		_:
			if posmod(ui, 20) < 2 and posmod(floori(v / 6.0), 2) == 0:
				return c.mark
	return tone


static func _hash(x: int, y: int) -> int:
	return ((x * 73856093) ^ (y * 19349663)) & 0xffff


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
