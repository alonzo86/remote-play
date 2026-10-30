extends RefCounted
## The pictures of Pin Pals (REQ-BW-13): a pixel bowling hall seen from behind the ball. The own lane is narrow and long; more
## lanes
## stand at its sides; at the far end of all lanes a wall has a disco light grid in its top two thirds and black in its bottom
## third.
## The lane is drawn in a simple perspective: depth `t` goes from 0 (the foul line) to 1 (the far end), across the lane `u` goes
## from -1 to 1 (the lane edges). Everything is drawn in 1920x1080 units on the pixel layer, so it comes out as sharp pixels.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Palette = preload("res://scripts/game/palette.gd")
const Minigame = preload("res://scripts/game/minigame.gd")
const Shell = preload("res://scripts/game/shell.gd")
const LaneSim = preload("res://scripts/game/bowling/lane_sim.gd")

const WALL_TOP := Minigame.HUD_BAR_H
const WALL_END := 232.0           # The far end of the lanes; the wall is above it.
const NEAR_HALF := 224.0          # Half the lane width at the foul line, in units at 1920 px wide ...
const FAR_HALF := 104.0           # ... and at the far end.
const PITCH := 2.8                # The distance between the middles of two lanes, in lane half-widths.
const GUTTER_U := 1.24
const RAIL_FROM := 1.04
const RAIL_TO := 1.2
const SIDE_LANES := 3             # Lanes on each side of the own lane.
const SIDE_ORDER := [-3, 3, -2, 2, -1, 1]   # The side lanes, far ones first (they are drawn back to front).
const DEPTH_END := 21.0           # The lane length (m) that depth 1 stands for.
const FLOOR := Color("5a5a64")
const GUTTER := Color("2c2c34")
const GUTTER_DIM := Color("22222a")
const PLANK := [Palette.LANE_WOOD, Color("d0985a"), Color("dca65e")]
const PLANK_DIM := [Color("9a7044"), Color("946a40"), Color("9e7448")]
const SEAM := Color("b87c3c")
const ARROW := Color("6a3a10")
const FOUL := Color("fc3030")
const DISCO := Palette.SLOTS + [ Color("f8b800"), Color("b05cd8"),
		Color("3ddcff")]

## The picture of a pin: 7 x 14 world pixels. K black, W white, G shade, R red.
const PIN_ROWS := ["..KKK..", ".KWWGK.", ".KWWGK.", "..KWK..", "..KRK..", "..KWK..", ".KWWGK.", "KWWWWGK", "KWRRRGK",
		"KWWWWGK", "KWWWWGK", "KWWWWGK", ".KWWGK.", "..KKK.."]
const PIN_COLORS := {"K": Color("000000"), "W": Color("fcfcfc"), "G": Color("b0b8d0"), "R": Palette.TOY_RED}
const BURST_TIME := 0.45
const LIE_TIME := 0.55            # A fallen pin lies this long (s), then it bursts into colored pixels.

static var _pin_tex: ImageTexture
static var _lying_tex: ImageTexture


## The geometry of the lanes on a screen of `size` with `rows` rows of the score sheet.
class Geo:
	var k := 1.0          # The screen width as a share of 1920.
	var cx := 960.0
	var top := WALL_END
	var bot := 718.0

	func _init(size: Vector2, sheet_top: float) -> void:
		k = size.x / 1920.0
		cx = size.x * 0.5
		top = WALL_END * size.y / 1080.0
		bot = sheet_top - 2.0

	func half(t: float) -> float:
		return lerpf(NEAR_HALF, FAR_HALF, t) * k

	func px(t: float, u: float, c := 0.0) -> float:
		return cx + (u + c) * half(t)

	func py(t: float) -> float:
		return bot - (bot - top) * t

	## The screen place of a point of the lane (x across and y along, in m), at the foot of the object.
	func at(p: Vector2) -> Vector2:
		var t := clampf(p.y / DEPTH_END, 0.0, 1.0)
		return Vector2(px(t, p.x / LaneSim.LANE_HALF), py(t))

	## The radius of the ball picture at depth `t`: the real size, but never under 24 units (48 px across).
	func ball_radius(t: float) -> float:
		return maxf(24.0, LaneSim.BALL_R / LaneSim.LANE_HALF * half(t))


## Draws the whole hall: the floor, the wall, the side lanes and the own lane (without pins and ball).
static func draw_hall(ci: CanvasItem, size: Vector2, geo: Geo, rails: bool) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), FLOOR)
	_draw_wall(ci, size, geo)
	for n in SIDE_ORDER:
		_draw_lane(ci, geo, float(n) * PITCH, true, false)
		_draw_rack(ci, geo, float(n) * PITCH, _neighbor_mask(n))
	_draw_lane(ci, geo, 0.0, false, rails)


## The wall at the far end: the top two thirds are a grid of light tiles (7 bright colors), the bottom third is black.
static func _draw_wall(ci: CanvasItem, size: Vector2, geo: Geo) -> void:
	var y0 := WALL_TOP * size.y / 1080.0
	var y1 := geo.top
	var wall_h := y1 - y0
	ci.draw_rect(Rect2(0.0, y0, size.x, wall_h), UiTheme.BG)
	for t in wall_tiles(size, geo):
		ci.draw_rect(t.rect, t.color)


## The light tiles of the wall: {rect, color} for each. They fill the top two thirds of the wall; the bottom third has none
## (it is plain black).
static func wall_tiles(size: Vector2, geo: Geo) -> Array:
	var y0 := WALL_TOP * size.y / 1080.0
	var wall_h := geo.top - y0
	var grid_h := wall_h * 2.0 / 3.0
	var tile := Vector2(48.0 * geo.k, 28.0 * size.y / 1080.0)
	var rows := int(grid_h / tile.y)
	var cols := int(ceil(size.x / tile.x))
	var out := []
	for gy in rows:
		for gx in cols:
			var c: Color = DISCO[_hash(gx, gy, 0) % DISCO.size()]
			out.append({"rect": Rect2(Shell.snap(Vector2(gx * tile.x, y0 + gy * tile.y)), tile - Vector2(8.0, 4.0)), "color": c})
	return out


static func _hash(a: int, b: int, c: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) >> 3


## A lane with its middle `c` lane half-widths from the own lane. A dim lane belongs to the neighbors.
static func _draw_lane(ci: CanvasItem, geo: Geo, c: float, dim: bool, rails: bool) -> void:
	var planks: Array = PLANK_DIM if dim else PLANK
	for i in 10:
		var u0 := -1.0 + 0.2 * i
		var u1 := u0 + 0.2
		ci.draw_colored_polygon(PackedVector2Array([Vector2(geo.px(0.0, u0, c), geo.py(0.0)), Vector2(geo.px(0.0, u1, c), geo.py(0.0)),
				Vector2(geo.px(1.0, u1, c), geo.py(1.0)), Vector2(geo.px(1.0, u0, c), geo.py(1.0))]), planks[i % 3])
	for s in [-1.0, 1.0]:
		var quad := PackedVector2Array([Vector2(geo.px(0.0, s, c), geo.py(0.0)), Vector2(geo.px(0.0, s * GUTTER_U, c), geo.py(0.0)),
				Vector2(geo.px(1.0, s * GUTTER_U, c), geo.py(1.0)), Vector2(geo.px(1.0, s, c), geo.py(1.0))])
		ci.draw_colored_polygon(quad, GUTTER_DIM if dim else GUTTER)
		if rails:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(geo.px(0.0, s * RAIL_FROM, c), geo.py(0.0)),
					Vector2(geo.px(0.0, s * RAIL_TO, c), geo.py(0.0)), Vector2(geo.px(1.0, s * RAIL_TO, c), geo.py(1.0)),
					Vector2(geo.px(1.0, s * RAIL_FROM, c), geo.py(1.0))]), UiTheme.ACCENT)
		for e in [1.0, GUTTER_U]:
			ci.draw_line(Vector2(geo.px(0.0, s * e, c), geo.py(0.0)), Vector2(geo.px(1.0, s * e, c), geo.py(1.0)), UiTheme.OUTLINE, 4.0)
	for u in [-0.6, -0.3, 0.0, 0.3, 0.6]:
		var t := 0.3 + 0.1 * (1.0 - absf(u) * 1.4)
		var p := Vector2(geo.px(t, u, c), geo.py(t))
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, -16.0), p + Vector2(-8.0, 4.0), p + Vector2(8.0, 4.0)]), ARROW)
	var fl := 0.02
	var foul := FOUL if not dim else FOUL.darkened(0.4)
	ci.draw_line(Vector2(geo.px(fl, -1.0, c), geo.py(fl)), Vector2(geo.px(fl, 1.0, c), geo.py(fl)), foul, 8.0)


## The pins of a neighbor lane: a rack with a few pins down, decided by the lane (they never move).
static func _neighbor_mask(n: int) -> Array:
	var m := []
	for i in 10:
		m.append(_hash(n + 7, i, 3) % 5 != 0)
	return m


static func _draw_rack(ci: CanvasItem, geo: Geo, c: float, mask: Array) -> void:
	for i in range(9, -1, -1):
		if not mask[i]:
			continue
		var p := LaneSim.rack_pos(i + 1)
		var t := clampf(p.y / DEPTH_END, 0.0, 1.0)
		draw_pin(ci, Vector2(geo.px(t, p.x / LaneSim.LANE_HALF, c), geo.py(t)))


## The picture of a pin (7 x 14) or of a lying pin (14 x 7, its head on the left).
static func pin_image(lying: bool) -> Image:
	var w := PIN_ROWS[0].length()
	var h := PIN_ROWS.size()
	var img := Image.create(h if lying else w, w if lying else h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var ch: String = PIN_ROWS[y][x]
			if ch == ".":
				continue
			if lying:
				img.set_pixel(y, x, PIN_COLORS[ch])
			else:
				img.set_pixel(x, y, PIN_COLORS[ch])
	return img


## A standing pin with its foot at `foot`. 28 x 56 units: 7 x 14 world pixels.
static func draw_pin(ci: CanvasItem, foot: Vector2) -> void:
	if _pin_tex == null:
		_pin_tex = ImageTexture.create_from_image(pin_image(false))
	var sz := Vector2(_pin_tex.get_size()) * Shell.WORLD_PIXEL
	ci.draw_texture_rect(_pin_tex, Rect2(Shell.snap(foot - Vector2(sz.x * 0.5, sz.y)), sz), false)


## A pin that lies on the lane, its head to the left or right.
static func draw_lying_pin(ci: CanvasItem, middle: Vector2, head_left: bool) -> void:
	if _lying_tex == null:
		_lying_tex = ImageTexture.create_from_image(pin_image(true))
	var sz := Vector2(_lying_tex.get_size()) * Shell.WORLD_PIXEL
	var rect := Rect2(Shell.snap(middle - sz * 0.5), sz)
	if head_left:
		ci.draw_texture_rect(_lying_tex, rect, false)
	else:
		ci.draw_set_transform(rect.position + Vector2(sz.x, 0.0), 0.0, Vector2(-1.0, 1.0))
		ci.draw_texture_rect(_lying_tex, Rect2(Vector2.ZERO, sz), false)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A burst of colored pixels where a pin was, in 3 steps (REQ-GM-81: nothing is hurt, it only bursts into colored pixels).
static func draw_burst(ci: CanvasItem, at: Vector2, age: float, colors: Array) -> void:
	var step := clampi(floori(age / BURST_TIME * 3.0), 0, 2)
	var r := 16.0 + 16.0 * step
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.5
		var c: Color = colors[i % colors.size()]
		ci.draw_rect(Rect2(Shell.snap(at + Vector2(cos(a), sin(a)) * r - Vector2(4.0, 4.0)), Vector2(8.0, 8.0)), c)


## The pins of the own lane: standing pins at their place, fallen pins lying for a moment, then a burst. Back to front.
static func draw_pins(ci: CanvasItem, geo: Geo, sim: LaneSim, burst_colors: Array) -> void:
	var order: Array[LaneSim.Pin] = []
	order.assign(sim.pins)
	order.sort_custom(func(a: LaneSim.Pin, b: LaneSim.Pin) -> bool: return a.pos.y > b.pos.y)
	for p in order:
		if p.state == LaneSim.State.STAND:
			draw_pin(ci, geo.at(p.pos))
		elif p.state == LaneSim.State.FALLEN:
			var age := sim.time - p.fell_at
			if age < LIE_TIME:
				draw_lying_pin(ci, geo.at(p.pos) + Vector2(0.0, -14.0), p.vel.x <= 0.0)
			elif age < LIE_TIME + BURST_TIME:
				draw_burst(ci, geo.at(p.pos) + Vector2(0.0, -14.0), age - LIE_TIME, burst_colors)


## The ball at `pos` (x across, y along, in m), with a white shine.
static func draw_ball(ci: CanvasItem, geo: Geo, pos: Vector2, color: Color) -> void:
	var t := clampf(pos.y / DEPTH_END, 0.0, 1.0)
	var r := geo.ball_radius(t)
	var foot := geo.at(pos)
	var c := foot - Vector2(0.0, r)
	Shell.pixel_ball(ci, c, r, color)
	ci.draw_rect(Rect2(Shell.snap(c + Vector2(-r * 0.5, -r * 0.55)), Vector2(8.0, 8.0)), UiTheme.TEXT)


## The dotted aim line from the ball to the pins, in the colors of the player and white.
static func draw_aim(ci: CanvasItem, geo: Geo, x: float, color: Color) -> void:
	for i in range(1, 9):
		var y := LaneSim.HEAD_Y * float(i) / 9.0
		var p := geo.at(Vector2(x, y)) - Vector2(0.0, 4.0)
		ci.draw_rect(Rect2(Shell.snap(p - Vector2(8.0, 8.0)), Vector2(16.0, 16.0)), UiTheme.TEXT if i % 2 == 1 else color)
