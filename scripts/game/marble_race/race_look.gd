extends RefCounted
## The look of Car Race (REQ-MR-44 to 47): a flat pixel world seen from above, in one of three themes (candy, space,
## jungle) that the player picks in the settings view. The cars look the same in every theme; the road, the walls, the ground
## and the obstacles are the theme.
## The board (the road with its walls and the finish line) is drawn once into an image of world pixels (`render()`); the game
## draws a window of it every frame. One meter is `PX` world pixels. The outlines are filled in runs, row by row; the road and the
## walls are colored pixel by pixel in the frame of the road, so that their patterns turn with the road.

const Palette = preload("res://scripts/game/palette.gd")
const PixelArt = preload("res://scripts/game/pixel_art.gd")

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
			"mark": Color("f8b8d8"), "wall_a": Color("fcfcfc"), "wall_b": Palette.RACE_RED, "outline": Color("8c1c50"),
			"obstacles": ["lolly", "gumdrop", "cupcake"],
			"decor": ["lolly_big", "cane", "icecream", "donut", "cookie", "wrapped"]},
	"space": {"ground_a": Color("0c0c28"), "ground_b": Color("080820"), "road_a": Color("6c7488"), "road_b": Color("646c80"),
			"mark": Color("4c5468"), "wall_a": Palette.SPACE_WALL, "wall_b": Palette.RACE_BLUE, "outline": Color("101040"),
			"obstacles": ["asteroid", "satellite", "crater"],
			"decor": ["rocket", "ringed", "ufo", "planet", "star"]},
	"jungle": {"ground_a": Color("145820"), "ground_b": Color("10501c"), "road_a": Color("b88048"), "road_b": Color("b07844"),
			"mark": Color("8c5c30"), "wall_a": Color("2c8c30"), "wall_b": Color("58b848"), "outline": Color("06280c"),
			"obstacles": ["log", "boulder", "tiki"],
			"decor": ["palm", "palm", "bush", "hibiscus", "mushroom", "fern"]},
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
			"W": CAR_GLASS, "G": Color("fcfcfc"), "D": CAR_COVER, "Y": Color("f8e060"), "R": Palette.RACE_RED, "T": CAR_TIRE}
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
	return PixelArt.outlined(img.get_region(area), look(theme).outline)


static func _paint(img: Image, kind: String) -> Rect2i:
	match kind:
		"lolly":
			_disc(img, 5.5, 5.5, 5.5, 5.5, Palette.RACE_RED)
			_disc(img, 5.5, 5.5, 4.0, 4.0, Color("fcfcfc"))
			_disc(img, 5.5, 5.5, 2.5, 2.5, Palette.RACE_RED)
			_box(img, 5, 11, 2, 3, Color("fcfcfc"))
			return Rect2i(0, 0, 11, 14)
		"gumdrop":
			_disc(img, 5.5, 5.5, 5.5, 5.5, Palette.RACE_GREEN)
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
			_disc(img, 5.5, 1.5, 1.5, 1.5, Palette.RACE_RED)
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
			img.set_pixel(6, 5, Palette.RACE_RED)
			img.set_pixel(6, 1, Color("e0e8f0"))
			img.set_pixel(6, 0, Palette.RACE_RED)
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
			_box(img, 0, 0, 9, 2, Palette.RACE_RED)
			for x in [1, 4, 7]:
				_box(img, x, 0, 1, 1, Color("f8b800"))
			_box(img, 1, 4, 2, 2, Color("fcfcfc"))
			_box(img, 6, 4, 2, 2, Color("fcfcfc"))
			img.set_pixel(2, 5, Palette.RACE_RED)
			img.set_pixel(6, 5, Palette.RACE_RED)
			_box(img, 2, 8, 5, 2, Color("301808"))
			for x in [3, 5]:
				img.set_pixel(x, 8, Color("fcfcfc"))
			return Rect2i(0, 0, 9, 12)
	_disc(img, 5.5, 5.5, 5.5, 5.5, Color("fcfcfc"))   # An unknown name: a plain disc.
	return Rect2i(0, 0, 11, 11)


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
## along the road and `v` across it (both in world pixels). Candy: a chess road with pink dashes across it and candy
## cane stripes on the walls. Space: metal panels and glowing stripes. Jungle: a dirt road with specks and leafy walls.
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


# ---- Scenery beside the road ----

const DECOR_GAP_MIN := 2.0     # Meters from the outer edge of the wall to the scenery, at the least.
const DECOR_GAP_MAX := 24.0
const DECOR_STEP_MIN := 5.0    # Meters along the road between two pieces of scenery on one side.
const DECOR_STEP_MAX := 9.0


## The picture of a piece of scenery of `theme` with its outline: a lollipop, a rocket, a palm tree. `kind` is one of the `decor`
## names of the theme. They are bigger than the obstacles (16 to 28 world pixels).
static func decor_image(theme: String, kind: String) -> Image:
	var img := Image.create(36, 36, false, Image.FORMAT_RGBA8)
	var area := _paint_decor(img, kind)
	return PixelArt.outlined(img.get_region(area), look(theme).outline)


static func _paint_decor(img: Image, kind: String) -> Rect2i:
	var red := Palette.RACE_RED
	var white := Color("fcfcfc")
	match kind:
		"lolly_big":
			for ring in [[10.0, red], [8.0, white], [6.0, red], [4.0, white], [2.0, red]]:
				_disc(img, 10.0, 10.0, ring[0], ring[0], ring[1])
			_box(img, 9, 20, 3, 10, white)
			_box(img, 11, 20, 1, 10, Color("f8b8d8"))
			return Rect2i(0, 0, 21, 30)
		"cane":
			for y in 28:
				for x in 22:
					var shaft := x >= 8 and x <= 11 and y >= 8
					var hook := false
					var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(14.0, 8.0))
					if y <= 8 and d <= 7.0 and d >= 3.0:
						hook = true
					if shaft or hook:
						img.set_pixel(x, y, red if ((x + y) / 3) % 2 == 0 else white)
			return Rect2i(0, 0, 22, 28)
		"icecream":
			_poly(img, [Vector2(3, 13), Vector2(19, 13), Vector2(11, 30)], Palette.RACE_WOOD)
			for k in range(0, 14, 4):
				_box(img, 5 + k / 3, 15 + k, 12 - k * 2 / 3, 1, Color("a0702c"))
			_disc(img, 11.0, 10.0, 8.0, 7.0, Color("f8a0c8"))
			_disc(img, 8.0, 7.0, 2.0, 2.0, Color("fcd0e4"))
			_disc(img, 11.0, 2.0, 2.0, 2.0, Palette.RACE_RED)
			return Rect2i(0, 0, 22, 31)
		"donut":
			_disc(img, 10.0, 10.0, 10.0, 10.0, Palette.RACE_AMBER)
			_disc(img, 10.0, 10.0, 8.5, 8.5, Color("f8a0c8"))
			_disc(img, 10.0, 10.0, 3.0, 3.0, Color(0, 0, 0, 0))
			var sprinkles := [Palette.RACE_GREEN, Palette.NEON_CYAN, Color("f8e060"), Color("fcfcfc")]
			for p in [Vector2i(4, 6), Vector2i(8, 3), Vector2i(14, 5), Vector2i(16, 11), Vector2i(13, 15), Vector2i(6, 14),
					Vector2i(3, 10)]:
				_box(img, p.x, p.y, 2, 1, sprinkles[(p.x + p.y) % 4])
			return Rect2i(0, 0, 20, 20)
		"cookie":
			_disc(img, 9.0, 9.0, 9.0, 9.0, Color("d8a060"))
			_disc(img, 7.0, 6.0, 3.0, 2.0, Color("e8b878"))
			for p in [Vector2i(5, 8), Vector2i(10, 4), Vector2i(12, 10), Vector2i(7, 13), Vector2i(13, 14)]:
				_box(img, p.x, p.y, 2, 2, Color("5c3410"))
			return Rect2i(0, 0, 18, 18)
		"wrapped":
			_poly(img, [Vector2(7, 8), Vector2(0, 2), Vector2(0, 14)], Color("70c8f8"))
			_poly(img, [Vector2(19, 8), Vector2(26, 2), Vector2(26, 14)], Color("70c8f8"))
			_disc(img, 13.0, 8.0, 8.0, 6.0, red)
			for k in range(-6, 7, 4):
				_box(img, 13 + k, 3, 2, 10, white)
			return Rect2i(0, 0, 27, 17)
		"rocket":
			_poly(img, [Vector2(4, 22), Vector2(0, 28), Vector2(7, 24)], red)
			_poly(img, [Vector2(16, 22), Vector2(20, 28), Vector2(13, 24)], red)
			_poly(img, [Vector2(7, 26), Vector2(13, 26), Vector2(10, 33)], Color("f8a000"))
			_disc(img, 10.0, 14.0, 5.5, 12.0, Color("e0e8f0"))
			_poly(img, [Vector2(4.5, 8), Vector2(15.5, 8), Vector2(10, 0)], red)
			_disc(img, 10.0, 14.0, 2.6, 2.6, Palette.NEON_CYAN)
			_box(img, 5, 21, 10, 2, Color("8890a8"))
			return Rect2i(0, 0, 21, 33)
		"ringed":
			for y in 22:
				for x in 25:
					var q := Vector2((x + 0.5 - 12.0) / 12.0, (y + 0.5 - 11.0) / 4.0)
					var l := q.length_squared()
					if l <= 1.0 and l >= 0.55 and y < 11:
						img.set_pixel(x, y, Color("f8d880"))
			_disc(img, 12.0, 11.0, 7.0, 7.0, Color("f8a000"))
			for y in [8, 11, 13]:
				for x in range(6, 19):
					if img.get_pixel(x, y).a > 0.0 and img.get_pixel(x, y) == Color("f8a000"):
						img.set_pixel(x, y, Palette.SATURN_BAND)
			for y in 22:
				for x in 25:
					var q2 := Vector2((x + 0.5 - 12.0) / 12.0, (y + 0.5 - 11.0) / 4.0)
					var l2 := q2.length_squared()
					if l2 <= 1.0 and l2 >= 0.55 and y >= 11:
						img.set_pixel(x, y, Color("f8d880"))
			return Rect2i(0, 0, 25, 22)
		"ufo":
			_disc(img, 13.0, 11.0, 13.0, 5.0, Color("a0a8b8"))
			_disc(img, 13.0, 7.0, 5.0, 5.0, Palette.NEON_CYAN)
			_disc(img, 11.5, 5.5, 1.5, 1.5, Color("c8f4ff"))
			_box(img, 0, 9, 26, 1, Color("c0c8d8"))
			for x in [4, 9, 14, 19, 22]:
				img.set_pixel(x, 12, Color("f8e060"))
			return Rect2i(0, 0, 26, 17)
		"planet":
			_disc(img, 9.0, 9.0, 9.0, 9.0, Color("3070e0"))
			_disc(img, 6.0, 6.0, 3.5, 3.0, Palette.RACE_GREEN)
			_disc(img, 12.5, 11.5, 3.0, 4.0, Palette.RACE_GREEN)
			_disc(img, 5.0, 5.0, 1.5, 1.0, Color("a0e090"))
			return Rect2i(0, 0, 18, 18)
		"star":
			_poly(img, [Vector2(8, 0), Vector2(10, 6), Vector2(16, 8), Vector2(10, 10), Vector2(8, 16), Vector2(6, 10), Vector2(0, 8),
					Vector2(6, 6)], Color("f8e060"))
			return Rect2i(0, 0, 17, 17)
		"palm":
			var c := Vector2(14, 14)
			for k in 8:
				var a := deg_to_rad(k * 45.0 + 22.0)
				var dir := Vector2(sin(a), -cos(a))
				var side := Vector2(-dir.y, dir.x)
				_poly(img, [c, c + dir * 7.0 + side * 3.5, c + dir * 13.5, c + dir * 7.0 - side * 3.5],
						Color("2c8c30") if k % 2 == 0 else Color("58b848"))
			_disc(img, 14.0, 14.0, 3.0, 3.0, Color("7c4a1c"))
			for p in [Vector2i(12, 12), Vector2i(15, 12), Vector2i(14, 15)]:
				_box(img, p.x, p.y, 2, 2, Color("301808"))
			return Rect2i(0, 0, 28, 28)
		"bush":
			_disc(img, 6.0, 9.0, 6.0, 5.5, Color("2c8c30"))
			_disc(img, 14.0, 9.0, 7.0, 6.0, Color("2c8c30"))
			_disc(img, 10.0, 6.0, 7.0, 6.0, Color("3c9c3c"))
			for p in [Vector2i(8, 3), Vector2i(9, 3), Vector2i(4, 7), Vector2i(15, 6), Vector2i(12, 9)]:
				img.set_pixelv(p, Color("70d060"))
			_box(img, 2, 12, 16, 2, Color("145418"))
			return Rect2i(0, 0, 21, 14)
		"hibiscus":
			_disc(img, 4.0, 15.0, 4.0, 2.5, Color("2c8c30"))
			_disc(img, 16.0, 15.0, 4.0, 2.5, Color("2c8c30"))
			for k in 5:
				var a2 := deg_to_rad(k * 72.0)
				_disc(img, 10.0 + sin(a2) * 5.0, 9.0 - cos(a2) * 5.0, 4.0, 4.0, Palette.RACE_RED)
			_disc(img, 10.0, 9.0, 2.5, 2.5, Color("f8e060"))
			return Rect2i(0, 0, 20, 19)
		"mushroom":
			_box(img, 6, 9, 6, 8, Color("f8ecd0"))
			_disc(img, 9.0, 7.0, 9.0, 6.5, Palette.RACE_RED)
			_box(img, 0, 9, 18, 1, Palette.RACE_RED)
			for p in [Vector2i(5, 4), Vector2i(10, 3), Vector2i(13, 6), Vector2i(8, 7)]:
				_box(img, p.x, p.y, 2, 2, Color("fcfcfc"))
			return Rect2i(0, 0, 18, 17)
		"fern":
			var f := Vector2(10, 10)
			for k in 7:
				var a3 := deg_to_rad(k * 51.4 + 10.0)
				var d3 := Vector2(sin(a3), -cos(a3))
				var s3 := Vector2(-d3.y, d3.x)
				_poly(img, [f, f + d3 * 5.0 + s3 * 2.0, f + d3 * 9.5, f + d3 * 5.0 - s3 * 2.0],
						Color("58b848") if k % 2 == 0 else Color("3c9c3c"))
			_disc(img, 10.0, 10.0, 1.6, 1.6, Color("145418"))
			return Rect2i(0, 0, 20, 20)
	_disc(img, 8.0, 8.0, 8.0, 8.0, Color("fcfcfc"))   # An unknown name: a plain disc.
	return Rect2i(0, 0, 16, 16)


static func _poly(img: Image, pts: Array, color: Color) -> void:
	var poly := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		poly.append(p)
		lo = lo.min(p)
		hi = hi.max(p)
	for y in range(maxi(0, floori(lo.y)), mini(img.get_height(), ceili(hi.y) + 1)):
		for x in range(maxi(0, floori(lo.x)), mini(img.get_width(), ceili(hi.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				img.set_pixel(x, y, color)


## The scenery of a track: [{kind, pos}] with `pos` in meters, on both sides of the road, in the order to draw (top of the screen
## first). The same track and theme always give the same list. A piece stands clear of the wall and of the pieces drawn before it.
static func decorations(theme: String, points: Array[Vector2], half_width: float, seed_value: int) -> Array:
	var kinds: Array = look(theme).decor
	var radii := {}
	for kind in kinds:
		var pic := decor_image(theme, String(kind))
		radii[kind] = maxf(pic.get_width(), pic.get_height()) * 0.5 / PX
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var out: Array = []
	var clear_wall := half_width + float(WALL_PX + 1) / PX
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := b - a
		var dir := seg.normalized()
		var perp := Vector2(-dir.y, dir.x)
		var t := rng.randf_range(0.0, DECOR_STEP_MIN)
		while t < seg.length():
			for side in [-1.0, 1.0]:
				var kind: String = kinds[rng.randi() % kinds.size()]
				var gap := rng.randf_range(DECOR_GAP_MIN, DECOR_GAP_MAX)
				var pos: Vector2 = a + dir * (t + rng.randf_range(-1.0, 1.0)) + perp * side * (clear_wall + gap + radii[kind])
				if _scenery_fits(pos, float(radii[kind]), points, clear_wall, out, radii):
					out.append({"kind": kind, "pos": pos})
			t += rng.randf_range(DECOR_STEP_MIN, DECOR_STEP_MAX)
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p.pos.y < q.pos.y)
	return out


static func _scenery_fits(pos: Vector2, radius: float, points: Array[Vector2], clear_wall: float, placed: Array,
		radii: Dictionary) -> bool:
	for j in points.size() - 1:
		var d := pos.distance_to(Geometry2D.get_closest_point_to_segment(pos, points[j], points[j + 1]))
		if d < clear_wall + radius + 0.4:
			return false
	for q in placed:
		if pos.distance_to(q.pos) < radius + float(radii[q.kind]) + 0.3:
			return false
	return true
