extends RefCounted
## The pictures of Mini Golf (REQ-MG-16, docs/games/mini_golf.md): a small golf park seen from above, in the 8-bit world. The
## whole hole is drawn from its data (`golf_holes.gd`) with ONE scale per hole, so that the course always fits the screen between
## the black bar and the chips, and the ball, the cup and the golfer keep the same size on every putt (docs/MINI_GOLF_REDESIGN.md,
## option A, decision of the owner, 2026-11-03). The tee is at the left and the cup at the right: the course axis z runs to the
## right and the across axis x runs down, so a turn of the phone to the right aims clockwise (down). Every player has a ball in a
## ring of the slot color; the ball of the player on turn has a flashing ring round it. A small golfer stands by that ball with
## a shirt in the slot color. A point of the course (x across, z along, in the units of `golf_holes.gd`) is at `Geo.at()`, in
## screen units. This file is the whole view; the rules, the ball and the holes do not know it (a camera change touches this file
## only).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")
const Shell = preload("res://scripts/game/shell.gd")
const Palette = preload("res://scripts/game/palette.gd")

const WALL_W := 0.14              # The width of a wall, in course units.
## Design units (1920x1080): the room for the course. The black bar ends at y 112, the chips of the bar stand at y 960 or higher
## (a second row of chips 72 units higher), so the course stays 12 units clear of them (REQ-MG-3).
const AREA_L := 60.0
const AREA_R := 1860.0
const AREA_T := 124.0
const AREA_B := 944.0
const ROW_H := 72.0
## The ball is drawn at one size on every hole: 32 screen pixels with its outline (8 world pixels; owner, 2026-11-03: it was 48,
## REQ-GM-47m, and too big; the cup stays 64 and the aim arrow shows where it goes).
const BALL_OUT := 16.0            # Radius with the outline.
const CUP_MIN_R := 32.0           # The cup is never smaller than this (the ball must fit it).
const GOLFER_K := 2.0             # Screen units for one unit of the golfer picture (the golfer is about 160 units tall).
const FLAG_H := 88.0

const WHITE := Color("fcfcfc")
const LAWN_A := Color("98d838")
const LAWN_B := Color("8ccc30")
const FAIR_A := Color("58b800")
const FAIR_B := Color("4ca800")
const TEE_MAT := Color("009800")
const WOOD := Color("ac6418")
const WOOD_HI := Color("d8a868")
const WOOD_LO := Color("683808")
const WATER := Color("3cbcfc")
const WATER_DEEP := Color("0078f8")
const WATER_GLINT := Color("a4e4fc")
const STONE := Color("886840")
const STONE_LO := Color("604428")
const BUSH := Color("006800")
const BUSH_LO := Color("003800")
const BUSH_HI := Color("009800")
const RED := Palette.NES_RED
const GOLD := Color("f8b800")
const BRICK := Color("c0442c")
const MORTAR := Color("e8dcc8")
const OL := Color("181818")
const ROCK := Color("887868")
const ROCK_HI := Color("b8a898")
const ROCK_LO := Color("504438")
const STEEL := Color("a8b4c8")
const STEEL_LO := Color("5c6880")
const GRIP := Color("383838")
const SKIN := Color("fcbc94")
const HAIR := Color("784818")
const FL_PINK := Color("f878f8")
const FL_PURPLE := Color("6844fc")
const BALLOON := [Palette.NES_RED, Color("f8b800"), Color("0078f8")]
const SHADOW := Color(0.0, 0.2, 0.0, 0.45)

static var _scenery_cache := {}   # hole, screen and room -> the list of `scenery()`: the park does not change during a hole.


## Where a point of the course is on the screen. One scale `s` (screen units for one course unit) for the whole hole, so that
## nothing changes size while the players putt. The course is centered in the room between the bar and the chips.
class Geo:
	var size := Vector2(1920.0, 1080.0)
	var u := 1.0                  # Screen units for one design unit.
	var off := Vector2.ZERO       # Where the design screen starts (a window that is not 16:9 centers it).
	var s := 200.0                # Screen units for one course unit.
	var bounds := Rect2()         # The ground with its walls: Rect2(x, z, across, along).
	var origin := Vector2.ZERO    # The screen place of the near-left corner of `bounds` (x min, z min).
	var area := Rect2()           # The room for the course, in screen units.
	var grid := 4.0               # One world pixel of the pixel view, in screen units.

	## `rows` is the number of rows of chips in the bar at the bottom (1 or 2): the course ends above the first of them.
	func _init(p_size: Vector2, hole: Dictionary, rows := 1) -> void:
		size = p_size
		u = minf(size.x / 1920.0, size.y / 1080.0)
		off = Vector2(size.x - 1920.0 * u, size.y - 1080.0 * u) * 0.5
		grid = size.x / 480.0
		area = Rect2(off + Vector2(AREA_L, AREA_T) * u,
				Vector2(AREA_R - AREA_L, AREA_B - AREA_T - float(maxi(rows, 1) - 1) * ROW_H) * u)
		bounds = Geo.ground_bounds(hole)
		s = minf(area.size.x / maxf(bounds.size.y, 0.01), area.size.y / maxf(bounds.size.x, 0.01))
		var used := Vector2(bounds.size.y, bounds.size.x) * s
		origin = ((area.position + (area.size - used) * 0.5) / grid).round() * grid

	## The ground of a hole and its walls: the union of the fairway rectangles, grown by the wall.
	static func ground_bounds(hole: Dictionary) -> Rect2:
		var out := Rect2()
		var first := true
		for r in hole.fairway:
			var rr := (r as Rect2).grow(WALL_W)
			out = rr if first else out.merge(rr)
			first = false
		return out

	func snap(v: Vector2) -> Vector2:
		return (v / grid).round() * grid

	## The screen place of a point (x, z) of the course: z runs to the right, x runs down.
	func at(p: Vector2) -> Vector2:
		return origin + Vector2(p.y - bounds.position.y, p.x - bounds.position.x) * s

	## The screen rectangle of a rectangle of the course (`Rect2(x, z, across, along)`), on the pixel grid.
	func rect(r: Rect2) -> Rect2:
		var a := snap(at(r.position))
		var b := snap(at(r.end))
		return Rect2(a, b - a)

	## A length of the course in screen units.
	func len(m: float) -> float:
		return m * s

	## The point (x, z) of the course that is at the screen place `c` (the opposite of `at()`).
	func point_at(c: Vector2) -> Vector2:
		var d := (c - origin) / s
		return Vector2(d.y + bounds.position.x, d.x + bounds.position.y)

	## The direction on the screen of an aim `heading` (radians from the +z axis towards +x).
	func dir(heading: float) -> Vector2:
		return Vector2(cos(heading), sin(heading))

	## The ball with its outline is this wide (32 at 1080p, an exception to REQ-GM-47m for this game, owner 2026-11-03).
	func ball_d() -> float:
		return 2.0 * BALL_OUT * u

	## The cup as it is drawn: the real cup, and never smaller than the ball needs.
	func cup_r() -> float:
		return maxf(Holes.CUP_R * s, CUP_MIN_R * u)

	## A length in design units.
	func d(v: float) -> float:
		return v * u


# ---- The ground ----

## The lawn of the whole screen, in mowed stripes.
static func draw_lawn(ci: CanvasItem, geo: Geo) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, geo.size), LAWN_A)
	var w := 96.0 * geo.u
	var n := int(ceil(geo.size.x / w))
	for i in range(0, n, 2):
		ci.draw_rect(Rect2(float(i) * w, 0.0, w, geo.size.y), LAWN_B)


static func _in_union(list: Array, p: Vector2, grow: float) -> bool:
	for r in list:
		if (r as Rect2).grow(grow).has_point(p):
			return true
	return false


## True when the point `p` (x, z) is on the ground of the hole (inside a fairway rectangle).
static func on_ground(hole: Dictionary, p: Vector2) -> bool:
	return _in_union(hole.fairway, p, 0.0)


## The walls, the mown ground with the tee mat, the lake with its bridge and the cup. The ball, the obstacles and the flag are
## drawn on top of this by the game.
static func draw_course(ci: CanvasItem, geo: Geo, hole: Dictionary) -> void:
	var rects: Array = hole.fairway
	for r in rects:
		ci.draw_rect(geo.rect((r as Rect2).grow(WALL_W)).grow(4.0), OL)
	for r in rects:
		ci.draw_rect(geo.rect((r as Rect2).grow(WALL_W)), WOOD)
	for r in rects:
		ci.draw_rect(geo.rect((r as Rect2).grow(0.045)), WOOD_HI)
	for r in rects:
		_draw_fairway(ci, geo, r)
	var tee: Vector2 = hole.tee
	ci.draw_rect(geo.rect(Rect2(tee.x - 0.3, tee.y - 0.18, 0.6, 0.36)), TEE_MAT)
	for r in hole.water:
		_draw_water(ci, geo, r)
	for r in hole.bridges:
		_draw_bridge(ci, geo, r)
	draw_cup(ci, geo, hole)


static func _draw_fairway(ci: CanvasItem, geo: Geo, r: Rect2) -> void:
	var band := 0.45
	var b0 := int(floor(r.position.y / band))
	var b1 := int(floor((r.end.y - 0.0001) / band))
	for b in range(b0, b1 + 1):
		var z0 := maxf(r.position.y, float(b) * band)
		var z1 := minf(r.end.y, float(b + 1) * band)
		ci.draw_rect(geo.rect(Rect2(r.position.x, z0, r.size.x, z1 - z0)), FAIR_A if b % 2 == 1 else FAIR_B)


static func _draw_water(ci: CanvasItem, geo: Geo, r: Rect2) -> void:
	var edge := 0.07
	var deep := 0.2
	ci.draw_rect(geo.rect(r), STONE)
	ci.draw_rect(geo.rect(Rect2(r.position.x, r.position.y + edge, r.size.x, r.size.y - 2.0 * edge)), WATER_DEEP)
	var mid := Rect2(r.position.x, r.position.y + deep, r.size.x, r.size.y - 2.0 * deep)
	if mid.size.y > 0.0:
		ci.draw_rect(geo.rect(mid), WATER)
	var sr := geo.rect(r)
	var step := 56.0 * geo.u
	var gx := 0
	var x := sr.position.x + step * 0.5
	while x < sr.end.x - step * 0.5:
		var gy := 0
		var y := sr.position.y + step * 0.5
		while y < sr.end.y - step * 0.5:
			if (gx * 3 + gy * 5) % 4 == 0:
				ci.draw_rect(Rect2(geo.snap(Vector2(x, y)), Vector2(16.0, 4.0) * geo.u), WATER_GLINT)
			y += step
			gy += 1
		x += step
		gx += 1
	# The stones along the two shores.
	for z0 in [r.position.y, r.end.y - edge]:
		var sh := geo.rect(Rect2(r.position.x, z0, r.size.x, edge))
		ci.draw_rect(sh, STONE_LO)
		ci.draw_rect(Rect2(sh.position, Vector2(sh.size.x, sh.size.y * 0.5)), STONE)


static func _draw_bridge(ci: CanvasItem, geo: Geo, r: Rect2) -> void:
	ci.draw_rect(geo.rect(r).grow(4.0), OL)
	ci.draw_rect(geo.rect(r), WOOD)
	var plank := 0.07
	var n := int(r.size.y / plank)
	for i in n:
		if i % 2 == 0:
			ci.draw_rect(geo.rect(Rect2(r.position.x, r.position.y + float(i) * plank, r.size.x, plank)), WOOD_HI)
	var rail := 0.05
	ci.draw_rect(geo.rect(Rect2(r.position.x, r.position.y, rail, r.size.y)), WOOD_LO)
	ci.draw_rect(geo.rect(Rect2(r.end.x - rail, r.position.y, rail, r.size.y)), WOOD_LO)


## The cup: a black hole in a gold rim. It is never smaller than the ball needs (`Geo.cup_r()`).
static func draw_cup(ci: CanvasItem, geo: Geo, hole: Dictionary) -> void:
	var c := geo.snap(geo.at(hole.cup))
	var r := geo.cup_r()
	ci.draw_circle(c, r + 4.0, OL)
	ci.draw_circle(c, r, GOLD)
	ci.draw_circle(c, r - 4.0, OL)


## The flag stands at the top rim of the cup, so that it never covers the hole: a pole up the screen and a red pennant.
static func flag_base(geo: Geo, hole: Dictionary) -> Vector2:
	return geo.snap(geo.at(hole.cup)) + Vector2(0.0, -geo.cup_r() * 0.7)


static func draw_flag(ci: CanvasItem, geo: Geo, hole: Dictionary, time: float) -> void:
	var foot := flag_base(geo, hole)
	var top := foot - Vector2(0.0, FLAG_H * geo.u)
	ci.draw_line(foot, top, OL, 8.0)
	ci.draw_line(foot, top, GOLD, 4.0)
	var wave := float(int(sin(time * 5.0) * 2.0)) * 4.0
	var tip := top + Vector2(44.0 * geo.u, 16.0 * geo.u + wave)
	var pennant := PackedVector2Array([top, tip, top + Vector2(0.0, 32.0 * geo.u)])
	ci.draw_colored_polygon(pennant, RED)
	ci.draw_polyline(PackedVector2Array([top, tip, top + Vector2(0.0, 32.0 * geo.u), top]), OL, 4.0)


## The place that the flag and the cup take on the screen (the plate of the banner keeps out of it).
static func cup_zone(geo: Geo, hole: Dictionary) -> Rect2:
	var c := geo.snap(geo.at(hole.cup))
	var r := geo.cup_r() + 8.0
	var top := flag_base(geo, hole).y - FLAG_H * geo.u - 8.0
	return Rect2(c.x - r, top, 2.0 * r + 56.0 * geo.u, c.y + r - top)


# ---- Things on the course ----

## A boulder seen from above: a grey rock with sharp edges, a light side up-left and a dark side down-right, and a crack. The ball
## bounces off it. Its size is the size of the rock in the data.
static func draw_rock(ci: CanvasItem, geo: Geo, r: Vector3) -> void:
	var c := geo.snap(geo.at(Vector2(r.x, r.y)))
	var rad := maxf(geo.len(r.z), 16.0 * geo.u)
	ci.draw_circle(c + Vector2(6.0, 10.0) * geo.u, rad, SHADOW)
	var pts := PackedVector2Array()
	var n := 7
	for i in n:
		var a := TAU * (float(i) + 0.3 * sin(float(i) * 2.1)) / float(n) - 0.4
		pts.append(c + Vector2(cos(a), sin(a)) * rad * (1.0 if i % 2 == 0 else 0.82))
	ci.draw_colored_polygon(pts, ROCK)
	ci.draw_colored_polygon(PackedVector2Array([c, pts[3], pts[4], pts[5], pts[6]]), ROCK_LO)
	ci.draw_colored_polygon(PackedVector2Array([c, pts[0], pts[1], pts[2], pts[3]]), ROCK_HI)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-rad * 0.1, -rad * 0.5), c, c + Vector2(rad * 0.35, rad * 0.2)]), OL, 3.0)
	pts.append(pts[0])
	ci.draw_polyline(pts, OL, 5.0)


## A box on the ground: a sliding barrier (red and gold stripes on wood) or, with `wall`, a brick wall. `rect` is its place now.
## It is drawn flat, as the camera sees it from straight above: only the top, with a shadow and a dark outline (owner, 2026-11-03:
## the low front face did not look right from this angle).
static func draw_box(ci: CanvasItem, geo: Geo, rect: Rect2, wall: bool) -> void:
	var r := geo.rect(rect)
	ci.draw_rect(Rect2(r.position + Vector2(8.0, 8.0) * geo.u, r.size), SHADOW)
	ci.draw_rect(r.grow(4.0), OL)
	if wall:
		_draw_bricks(ci, geo, r)
		return
	ci.draw_rect(r, WOOD_LO)
	var along_x := r.size.x >= r.size.y
	var long := r.size.x if along_x else r.size.y
	var stripes := maxi(2, int(long / (24.0 * geo.u)))
	for i in stripes:
		var a := long * float(i) / float(stripes)
		var b := long * float(i + 1) / float(stripes)
		var col := GOLD if i % 2 == 0 else RED
		if along_x:
			ci.draw_rect(Rect2(r.position.x + a, r.position.y, b - a, r.size.y), col)
		else:
			ci.draw_rect(Rect2(r.position.x, r.position.y + a, r.size.x, b - a), col)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 4.0 * geo.u)), WOOD_HI)


## The top of a brick wall: red bricks with light mortar between them, every other row shifted (big enough to read from the sofa).
static func _draw_bricks(ci: CanvasItem, geo: Geo, r: Rect2) -> void:
	ci.draw_rect(r, MORTAR)
	var brick_h := maxf(r.size.y / maxf(1.0, roundf(r.size.y / (36.0 * geo.u))), 16.0 * geo.u)
	var brick_w := 64.0 * geo.u
	var row := 0
	var y := r.position.y
	while y < r.end.y - 1.0:
		var h := minf(brick_h, r.end.y - y) - 4.0
		var x := r.position.x - (brick_w * 0.5 if row % 2 == 1 else 0.0)
		while x < r.end.x:
			var x0 := maxf(x + 2.0, r.position.x)
			var x1 := minf(x + brick_w - 2.0, r.end.x)
			if x1 > x0:
				ci.draw_rect(Rect2(x0, y + 2.0, x1 - x0, h), BRICK)
			x += brick_w
		y += brick_h
		row += 1


## A turning blade: a bar that turns round its middle, with a red and a gold half (REQ-MG-10). The bar is as wide as the
## ball needs to hit it (`GolfSim.BLADE_R`).
static func draw_spinner(ci: CanvasItem, geo: Geo, sp: Dictionary, time: float) -> void:
	var ends := Holes.spinner_ends(sp, time)
	var a := geo.snap(geo.at(ends[0]))
	var b := geo.snap(geo.at(ends[1]))
	var mid := geo.snap(geo.at(sp.c))
	var w := maxf(2.0 * 0.05 * geo.s, 16.0 * geo.u)
	ci.draw_line(a + Vector2(6.0, 8.0) * geo.u, b + Vector2(6.0, 8.0) * geo.u, SHADOW, w)
	ci.draw_line(a, b, OL, w + 8.0)
	ci.draw_line(a, mid, RED, w)
	ci.draw_line(mid, b, GOLD, w)
	ci.draw_circle(mid, w * 0.75 + 4.0, OL)
	ci.draw_circle(mid, w * 0.75, WOOD_LO)


## The windmill stands on the first block of a hole that has one: the roof of a brown tower seen from above, with four gold
## blades that turn over it. The blades stay inside the block, so the picture shows what the ball hits.
static func draw_windmill(ci: CanvasItem, geo: Geo, block: Rect2, time: float) -> void:
	var r := geo.rect(block)
	ci.draw_rect(Rect2(r.position + Vector2(8.0, 8.0) * geo.u, r.size), SHADOW)
	ci.draw_rect(r.grow(4.0), OL)
	ci.draw_rect(r, RED)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 4.0 * geo.u)), BRICK)
	ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.5 - 2.0, r.size.x, 4.0), BRICK)
	var hub := geo.snap(r.get_center())
	var blade := 0.5 * minf(r.size.x, r.size.y) - 6.0 * geo.u
	for i in 4:
		var a := time * 1.4 + TAU * float(i) / 4.0
		var tip := hub + Vector2(cos(a), sin(a)) * blade
		ci.draw_line(hub, tip, OL, 14.0 * geo.u)
		ci.draw_line(hub, tip, GOLD, 8.0 * geo.u)
	ci.draw_circle(hub, 10.0 * geo.u + 4.0, OL)
	ci.draw_circle(hub, 10.0 * geo.u, WOOD_LO)


## The places of the obstacles on the screen, for a banner plate to keep out of: the blocks, the rocks, the whole way of each
## sliding barrier and the circle of each turning blade.
static func obstacle_zones(geo: Geo, hole: Dictionary) -> Array:
	var out: Array = []
	for b in hole.blocks:
		out.append(geo.rect(b))
	for r in hole.rocks:
		var c := geo.at(Vector2(r.x, r.y))
		out.append(Rect2(c - Vector2(geo.len(r.z), geo.len(r.z)), Vector2(2.0, 2.0) * geo.len(r.z)))
	for m in hole.movers:
		var a := geo.rect(m.rect)
		var far: Rect2 = m.rect
		if String(m.axis) == "x":
			far.position.x += float(m.amp)
		else:
			far.position.y += float(m.amp)
		out.append(a.merge(geo.rect(far)))
	for sp in hole.spinners:
		var c2 := geo.at(sp.c)
		var l := geo.len(float(sp.len))
		out.append(Rect2(c2 - Vector2(l, l), Vector2(2.0, 2.0) * l))
	return out


# ---- The balls ----

## The ball at the screen place `c`: white with a dark outline, in no color and with no ring (owner, 2026-11-03). Only the ball of
## the player on turn is drawn; the golfer's shirt has the slot color (REQ-MG-2). It is `Geo.ball_d()` wide.
static func draw_ball(ci: CanvasItem, geo: Geo, c: Vector2, slot := -1) -> void:
	var p := geo.snap(c)
	var u := geo.u
	Shell.record("ball", ci, Rect2(p - Vector2(BALL_OUT, BALL_OUT) * u, Vector2(2.0, 2.0) * BALL_OUT * u),
			{"color": WHITE, "slot": slot})
	ci.draw_circle(p + Vector2(3.0, 6.0) * u, BALL_OUT * u * 0.9, SHADOW)
	ci.draw_circle(p, BALL_OUT * u, OL)
	ci.draw_circle(p, (BALL_OUT - 3.0) * u, WHITE)
	ci.draw_rect(Rect2(p + Vector2(2.0, 2.0) * u, Vector2(4.0, 4.0) * u), Color("bcbcbc"))


## The aim: a line of dots on the ground from the ball in `heading`, `length` course units long (Hard: a short marker line of
## `AIM_MARK`) but never beyond the walls (REQ-MG-4, 13). There is no arrow (owner, 2026-11-03). The line is as long on the screen
## as the putt is on the course, on every hole and at every distance. The dots are white, gold when the aim is locked and green
## when it is snapped to the cup (`snapped`).
static func draw_aim(ci: CanvasItem, geo: Geo, hole: Dictionary, from: Vector2, heading: float, length: float,
		locked: bool, snapped := false) -> void:
	var e := aim_end(geo, hole, from, heading, length)
	var c := geo.at(from)
	var dir := geo.dir(heading)
	var u := geo.u
	var run := (e - c).length()
	var gap := 36.0 * u
	var start := BALL_OUT * u + 20.0 * u
	var col := GOLD if locked else (UiTheme.OK if snapped else UiTheme.TEXT)
	var side := dir.orthogonal()
	if length > 0.0 and run > start:
		# A light lane under the dots, so the direction reads from the sofa on any grass.
		var lane_a := c + dir * start
		var w := side * 12.0 * u
		var lane := PackedVector2Array([lane_a + w, e + w, e - w, lane_a - w])
		ci.draw_colored_polygon(lane, Color(1.0, 1.0, 1.0, 0.2))
	var d := start
	while d <= run:
		var p := geo.snap(c + dir * d)
		ci.draw_rect(Rect2(p - Vector2(8.0, 8.0) * u, Vector2(16.0, 16.0) * u), OL)
		ci.draw_rect(Rect2(p - Vector2(5.0, 5.0) * u, Vector2(10.0, 10.0) * u), col)
		d += gap
	Shell.record("aim", ci, Rect2(geo.snap(e) - Vector2(24.0, 24.0) * u, Vector2(48.0, 48.0) * u),
			{"locked": locked, "snapped": snapped, "color": col, "length": run / geo.s, "heading": heading})


const AIM_MARK := 0.6


## The end of the aim line on the screen: `length` course units from `from` (at least `AIM_MARK` for the marker of the Hard
## level), stopped at the wall where the line leaves the ground.
static func aim_end(geo: Geo, hole: Dictionary, from: Vector2, heading: float, length: float) -> Vector2:
	var want := maxf(length, AIM_MARK)
	var dir := Vector2(sin(heading), cos(heading))
	var reach := 0.0
	var step := 0.02
	while reach + step <= want:
		if not on_ground(hole, from + dir * (reach + step)):
			break
		reach += step
	return geo.at(from + dir * maxf(reach, 0.1))


## A splash of water drops at the screen place `c` (age in seconds): REQ-MG-9.
static func draw_splash(ci: CanvasItem, geo: Geo, c: Vector2, age: float) -> void:
	var foot := geo.snap(c)
	for i in 7:
		var a := TAU * float(i) / 7.0
		var d := Vector2(cos(a) * 30.0, sin(a) * 30.0 - 10.0) * (0.5 + age * 1.5) * geo.u
		ci.draw_rect(Rect2(foot + d - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), WATER_GLINT if i % 2 == 0 else WATER)


## Gold sparks round the cup: the ball is in (age in seconds).
static func draw_sparks(ci: CanvasItem, geo: Geo, hole: Dictionary, age: float) -> void:
	var foot := geo.snap(geo.at(hole.cup))
	for i in 8:
		var a := TAU * float(i) / 8.0
		var d := Vector2(cos(a), sin(a)) * (geo.cup_r() + 10.0 + age * 90.0) * geo.u
		ci.draw_rect(Rect2(foot + d - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), GOLD)


# ---- The plate of the banner ----

## The baseline place for a banner plate (`Shell.label_plate`) of `msg`: one of a few places on the course area that covers the
## least of `avoid` (the cup with its flag, the balls, the golfer, the aim line). The first free place wins, so the plate stays
## in one place while nothing moves under it. The plate always stays inside the 60 unit margin. `soft` are places that it should
## keep out of if it can (the obstacles): they count a quarter of `avoid`.
static func plate_at(geo: Geo, msg: String, font_size: int, avoid: Array, soft := [], max_w := -1.0) -> Vector2:
	var probe := Shell.label_plate_rect(Vector2.ZERO, msg, font_size, max_w)
	var half := probe.size.x * 0.5
	var mid := geo.size.x * 0.5
	var xs := [mid, mid - 0.25 * geo.area.size.x, mid + 0.25 * geo.area.size.x]
	var ys := [geo.area.position.y + geo.area.size.y * 0.16, geo.area.end.y - geo.area.size.y * 0.16 - probe.size.y * 0.5,
			geo.area.position.y + geo.area.size.y * 0.5]
	var best := Vector2(mid, ys[0])
	var best_score := INF
	for y in ys:
		for x in xs:
			var cx := clampf(float(x), geo.off.x + 60.0 * geo.u + half, geo.off.x + 1860.0 * geo.u - half)
			var at := Vector2(cx, float(y) + probe.size.y * 0.5)
			var rect := Shell.label_plate_rect(at, msg, font_size, max_w)
			var score := 0.0
			for a in avoid:
				var inter := rect.intersection(a as Rect2)
				score += inter.size.x * inter.size.y
			for a in soft:
				var inter2 := rect.intersection(a as Rect2)
				score += 0.25 * inter2.size.x * inter2.size.y
			if score < best_score:
				best_score = score
				best = at
				if score == 0.0:
					return best
	return best


# ---- The park round the course ----

## The things that stand on the lawn round the course, small, in the free places only: [kind, screen place]. The clubhouse and
## the hot air balloon take the first free corner, the trees, beds and benches the free places along the edges of the screen.
static func scenery(geo: Geo, hole: Dictionary, n: int) -> Array:
	var keep: Array = []
	for r in hole.fairway:
		keep.append(geo.rect((r as Rect2).grow(WALL_W)).grow(44.0 * geo.u))
	var out: Array = []
	var used: Array = []
	var u := geo.u
	var corners := [Vector2(1740.0, 250.0), Vector2(190.0, 250.0), Vector2(1740.0, 800.0), Vector2(190.0, 800.0)]
	var big := [["clubhouse", Vector2(150.0, 110.0)], ["balloon", Vector2(110.0, 150.0)]]
	for k in big.size():
		for j in corners.size():
			var c: Vector2 = corners[(j + n + k * 2) % corners.size()]
			var box := Rect2(geo.off + c * u - big[k][1] * u * 0.5, big[k][1] * u)
			if _free(box, keep, used):
				out.append([big[k][0], box.get_center()])
				used.append(box.grow(12.0 * u))
				break
	var kinds := ["tree", "flowers", "bush", "tree", "bench"]
	var i := 0
	var spots: Array = []
	for y in range(168, 940, 104):
		spots.append(Vector2(42.0, y))
		spots.append(Vector2(1878.0, y))
	for x in range(130, 1800, 120):
		spots.append(Vector2(x, 154.0))
		spots.append(Vector2(x, 1046.0))
	for y in range(236, 900, 150):
		for x in range(150, 1800, 150):
			if (x * 7 + y * 13 + n * 5) % 3 == 0:
				spots.append(Vector2(x, y))
	for sp in spots:
		var c: Vector2 = geo.off + (sp as Vector2) * u
		var box := Rect2(c - Vector2(36.0, 36.0) * u, Vector2(72.0, 72.0) * u)
		if _free(box, keep, used) and not (sp.y > 930.0 and sp.y < 1030.0):
			out.append([kinds[i % kinds.size()], c])
			used.append(box)
			i += 1
	return out


static func _free(box: Rect2, keep: Array, used: Array) -> bool:
	for k in keep:
		if box.intersects(k as Rect2):
			return false
	for k in used:
		if box.intersects(k as Rect2):
			return false
	return true


static func draw_scenery(ci: CanvasItem, geo: Geo, hole: Dictionary, n: int, time: float) -> void:
	var key := "%d|%s|%s" % [n, str(geo.size), str(geo.area.size)]
	if not _scenery_cache.has(key):
		_scenery_cache[key] = scenery(geo, hole, n)
	for it in _scenery_cache[key]:
		var c: Vector2 = geo.snap(it[1])
		match String(it[0]):
			"clubhouse":
				_clubhouse(ci, geo, c)
			"balloon":
				_balloon(ci, geo, c, time)
			"tree":
				_tree(ci, geo, c, 28.0)
			"bush":
				_tree(ci, geo, c, 20.0)
			"flowers":
				_flowerbed(ci, geo, c)
			_:
				_bench(ci, geo, c)


static func _ellipse_pts(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## A round tree seen from above: the crown with a light spot and some fruit.
static func _tree(ci: CanvasItem, geo: Geo, c: Vector2, r: float) -> void:
	var u := geo.u
	ci.draw_circle(c + Vector2(6.0, 10.0) * u, r * u, SHADOW)
	ci.draw_circle(c, r * u + 4.0, OL)
	ci.draw_circle(c, r * u, BUSH_LO)
	ci.draw_circle(c + Vector2(-2.0, -3.0) * u, r * u - 5.0, BUSH)
	ci.draw_circle(c + Vector2(-0.3, -0.3) * r * u, r * u * 0.35, BUSH_HI)
	if r > 24.0:
		for i in 4:
			var p := c + Vector2(float(i - 1) * 0.5 - 0.2, float(i % 2) * 0.6 - 0.2) * r * u
			ci.draw_rect(Rect2(geo.snap(p), Vector2(8.0, 8.0)), RED if i % 2 == 0 else GOLD)


static func _flowerbed(ci: CanvasItem, geo: Geo, c: Vector2) -> void:
	var u := geo.u
	var box := Rect2(c - Vector2(36.0, 22.0) * u, Vector2(72.0, 44.0) * u)
	ci.draw_rect(box.grow(4.0), OL)
	ci.draw_rect(box, WOOD_LO)
	ci.draw_rect(box.grow(-6.0 * u), BUSH)
	var cols := [RED, GOLD, FL_PINK, FL_PURPLE]
	for i in 6:
		var p := box.position + Vector2(14.0 + float(i % 3) * 22.0, 12.0 + float(i / 3) * 18.0) * u
		ci.draw_rect(Rect2(geo.snap(p), Vector2(8.0, 8.0)), cols[i % 4])


static func _bench(ci: CanvasItem, geo: Geo, c: Vector2) -> void:
	var u := geo.u
	var box := Rect2(c - Vector2(36.0, 12.0) * u, Vector2(72.0, 24.0) * u)
	ci.draw_rect(Rect2(box.position + Vector2(6.0, 8.0) * u, box.size), SHADOW)
	ci.draw_rect(box.grow(4.0), OL)
	ci.draw_rect(box, WOOD_HI)
	ci.draw_rect(Rect2(box.position.x, box.position.y + 8.0 * u, box.size.x, 4.0 * u), WOOD)
	ci.draw_rect(Rect2(box.position.x, box.end.y - 8.0 * u, box.size.x, 8.0 * u), WOOD_LO)


## The clubhouse seen from above: a red roof over a brick wall, with a door and two windows.
static func _clubhouse(ci: CanvasItem, geo: Geo, c: Vector2) -> void:
	var u := geo.u
	var body := Rect2(c - Vector2(66.0, 40.0) * u, Vector2(132.0, 96.0) * u)
	ci.draw_rect(Rect2(body.position + Vector2(8.0, 10.0) * u, body.size), SHADOW)
	ci.draw_rect(body.grow(4.0), OL)
	ci.draw_rect(body, BRICK)
	var roof := Rect2(body.position + Vector2(-4.0, -4.0) * u, Vector2(body.size.x + 8.0 * u, 56.0 * u))
	ci.draw_rect(roof.grow(4.0), OL)
	ci.draw_rect(roof, RED)
	ci.draw_rect(Rect2(roof.position.x, roof.position.y + roof.size.y * 0.5 - 2.0, roof.size.x, 4.0), BRICK)
	ci.draw_rect(Rect2(c + Vector2(-8.0, 22.0) * u, Vector2(16.0, 34.0) * u), WOOD_LO)
	for sx in [-44.0, 28.0]:
		ci.draw_rect(Rect2(c + Vector2(sx, 26.0) * u, Vector2(16.0, 16.0) * u), WATER)


## A hot air balloon over the lawn, with its shadow on the grass.
static func _balloon(ci: CanvasItem, geo: Geo, c: Vector2, time: float) -> void:
	var u := geo.u
	var bob := float(int(sin(time * 1.2) * 2.0)) * 4.0 * u
	var top := c + Vector2(0.0, -22.0 * u + bob)
	ci.draw_colored_polygon(_ellipse_pts(c + Vector2(30.0, 54.0) * u, 24.0 * u, 11.0 * u), SHADOW)
	var env := _ellipse_pts(top, 34.0 * u + 4.0, 42.0 * u + 4.0)
	ci.draw_colored_polygon(env, OL)
	ci.draw_colored_polygon(_ellipse_pts(top, 34.0 * u, 42.0 * u), BALLOON[0])
	ci.draw_colored_polygon(_ellipse_pts(top, 13.0 * u, 42.0 * u), BALLOON[1])
	ci.draw_rect(Rect2(top + Vector2(-34.0, -5.0) * u, Vector2(68.0, 10.0) * u), BALLOON[2])
	ci.draw_line(top + Vector2(-12.0, 40.0) * u, top + Vector2(-6.0, 62.0) * u, OL, 4.0)
	ci.draw_line(top + Vector2(12.0, 40.0) * u, top + Vector2(6.0, 62.0) * u, OL, 4.0)
	var basket := Rect2(top + Vector2(-10.0, 62.0) * u, Vector2(20.0, 14.0) * u)
	ci.draw_rect(basket.grow(4.0), OL)
	ci.draw_rect(basket, WOOD)


# ---- The golfer ----

## The poses of the golfer, the key pictures of a swing: the hands (picture pixels from the feet, at the full size), the club
## angle (degrees; 0 points to the right, 90 up), `ab` (1: the club head touches the ball, 0: the club is in the air) and `lean`
## (the upper body moves this far to the right).
enum Pose { ADDRESS, BACK, DOWN, HIT, FOLLOW, FINISH }
const POSES := {
	Pose.ADDRESS: {"hx": 4.0, "hy": -27.0, "a": -72.0, "ab": 1.0, "lean": 0.0},
	Pose.BACK: {"hx": 8.0, "hy": -40.0, "a": 42.0, "ab": 0.0, "lean": -3.0},
	Pose.DOWN: {"hx": 6.0, "hy": -33.0, "a": 5.0, "ab": 0.0, "lean": 0.0},
	Pose.HIT: {"hx": 4.0, "hy": -27.0, "a": -72.0, "ab": 1.0, "lean": 2.0},
	Pose.FOLLOW: {"hx": -5.0, "hy": -46.0, "a": 140.0, "ab": 0.0, "lean": 3.0},
	Pose.FINISH: {"hx": -8.0, "hy": -48.0, "a": 165.0, "ab": 0.0, "lean": 4.0},
}
const CLUB := 34.0
## How long the parts of the swing take, in seconds after the putt: down to the ball, through, up, and back to the address.
const SWING_DOWN := 0.12
const SWING_THROUGH := 0.38
const SWING_UP := 0.7
const SWING_TOTAL := 1.0


static func _mix(a: Dictionary, b: Dictionary, f: float) -> Dictionary:
	var out := {}
	for k in a:
		out[k] = lerpf(float(a[k]), float(b[k]), f)
	return out


## The pose of the golfer at the address, and at the back swing that starts when the direction locks (`lock_age` seconds ago).
static func aim_pose(locked: bool, lock_age: float) -> Dictionary:
	if not locked:
		return POSES[Pose.ADDRESS]
	return _mix(POSES[Pose.ADDRESS], POSES[Pose.BACK], smoothstep(0.0, 0.3, lock_age))


## The pose `age` seconds after the putt: from the top of the swing down to the ball, through it, up to the finish and slowly back
## to the address.
static func swing_pose(age: float) -> Dictionary:
	if age < SWING_DOWN:
		return _mix(POSES[Pose.BACK], POSES[Pose.HIT], smoothstep(0.0, SWING_DOWN, age))
	if age < SWING_THROUGH:
		var f := (age - SWING_DOWN) / (SWING_THROUGH - SWING_DOWN)
		return _mix(POSES[Pose.HIT], POSES[Pose.FINISH], smoothstep(0.0, 1.0, f))
	if age < SWING_UP:
		return POSES[Pose.FINISH]
	return _mix(POSES[Pose.FINISH], POSES[Pose.ADDRESS], smoothstep(SWING_UP, SWING_TOTAL, age))


## The golfer is drawn at one size (`GOLFER_K`), seen from the side and a little from above, facing the cup (to the right). The
## head of the club touches the ball from the left (the side of the tee), and the feet stand `CLUB_REACH` units further left.
const CLUB_REACH := Vector2(16.0, -3.0)

## Where the head of the putter rests at the address for the ball at the screen place `ball_c`: left of the ball, level with it.
static func club_head_at(geo: Geo, ball_c: Vector2) -> Vector2:
	var k := GOLFER_K * geo.u
	return ball_c + Vector2(-(BALL_OUT * geo.u + 6.0 * k + 2.0), 2.0 * k)


## The place of the feet of the golfer for the ball at the screen place `ball_c`.
static func feet_at(geo: Geo, ball_c: Vector2) -> Vector2:
	return club_head_at(geo, ball_c) - CLUB_REACH * GOLFER_K * geo.u


## The screen rectangle that the golfer takes (the banner keeps out of it).
static func golfer_zone(geo: Geo, ball_c: Vector2) -> Rect2:
	var k := GOLFER_K * geo.u
	var foot := feet_at(geo, ball_c)
	return Rect2(foot - Vector2(40.0, 92.0) * k, Vector2(110.0, 100.0) * k)


## Draws the golfer for the ball at the screen place `ball_c` (the cap, the cheek and one eye look to the ball). `shirt` is the
## slot color. `pose` is one of `POSES` or a mix.
## With `flip` (the aim points back, to the left of the screen) the golfer stands on the other side of the ball and faces the
## other way (owner, 2026-11-04).
static func draw_golfer(ci: CanvasItem, geo: Geo, ball_c: Vector2, pose: Dictionary, shirt: Color, flip := false) -> void:
	if flip:
		ci.draw_set_transform(Vector2(2.0 * ball_c.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	_draw_golfer(ci, geo, ball_c, pose, shirt)
	if flip:
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_golfer(ci: CanvasItem, geo: Geo, ball_c: Vector2, pose: Dictionary, shirt: Color) -> void:
	var foot := geo.snap(feet_at(geo, ball_c))
	var k := GOLFER_K * geo.u
	Shell.record("golfer", ci, Rect2(foot - Vector2(30.0, 80.0) * k, Vector2(60.0, 80.0) * k),
			{"shirt": shirt, "pose": pose})
	var lean := float(pose.lean)
	var pt := func(dx: float, dy: float) -> Vector2: return foot + Vector2(dx, dy) * k
	var up := func(dx: float, dy: float) -> Vector2: return foot + Vector2(dx + lean * clampf(-dy / 60.0, 0.0, 1.0), dy) * k
	var poly := func(points: Array, c: Color) -> void:
		var pts := PackedVector2Array(points)
		ci.draw_colored_polygon(pts, c)
		pts.append(pts[0])
		ci.draw_polyline(pts, OL, 4.0)
	ci.draw_rect(Rect2(foot - Vector2(16.0, 3.0) * k, Vector2(34.0, 7.0) * k), Color(0.0, 0.2, 0.0, 0.5))
	var hand: Vector2 = up.call(float(pose.hx), float(pose.hy))
	# Legs and shoes: white, the shoes point to the ball, with a grey sole.
	for sx in [-5.0, 3.0]:
		poly.call([pt.call(sx - 3.5, -24.0), pt.call(sx + 3.5, -24.0), pt.call(sx + 3.5, -5.0), pt.call(sx - 3.5, -5.0)], WHITE)
		ci.draw_line(pt.call(sx, -23.0), pt.call(sx, -7.0), Color("d8d8d8"), 3.0)
		poly.call([pt.call(sx - 4.0, -5.0), pt.call(sx + 3.0, -6.0), pt.call(sx + 9.0, -2.0), pt.call(sx + 9.0, 0.0),
				pt.call(sx - 4.0, 0.0)], WHITE)
		ci.draw_line(pt.call(sx - 4.0, -0.5), pt.call(sx + 9.0, -0.5), Color("a8a8a8"), 4.0)
	poly.call([up.call(-9.0, -27.0), up.call(9.0, -27.0), up.call(9.0, -23.0), up.call(-9.0, -23.0)], WOOD_LO)
	# The shirt, in the slot color: the back with a darker side and a collar.
	poly.call([up.call(-9.0, -26.0), up.call(9.0, -26.0), up.call(12.0, -46.0), up.call(-11.0, -46.0)], shirt)
	ci.draw_line(up.call(3.0, -27.0), up.call(6.0, -45.0), shirt.darkened(0.2), maxf(4.0, 6.0 * k))
	poly.call([up.call(-5.0, -49.0), up.call(5.0, -49.0), up.call(7.0, -45.0), up.call(-7.0, -45.0)], shirt.darkened(0.3))
	# Both arms reach the hands on the club: a short sleeve, then the skin.
	for sx in [-1.0, 1.0]:
		var shoulder: Vector2 = up.call(sx * 11.0, -43.0)
		var skin := SKIN if sx > 0.0 else SKIN.darkened(0.15)
		var elbow := shoulder.lerp(hand, 0.55) + Vector2(sx * 5.0, 2.0) * k
		for seg in [[shoulder, elbow], [elbow, hand]]:
			ci.draw_line(seg[0], seg[1], OL, maxf(8.0, 7.0 * k))
		for seg in [[shoulder, elbow], [elbow, hand]]:
			ci.draw_line(seg[0], seg[1], skin, maxf(4.0, 4.0 * k))
		ci.draw_line(shoulder, shoulder.lerp(elbow, 0.5), shirt, maxf(8.0, 7.0 * k))
	ci.draw_circle(hand, maxf(5.0, 4.0 * k) + 3.0, OL)
	ci.draw_circle(hand, maxf(5.0, 4.0 * k), SKIN)
	# The head: neck, hair, a face that looks to the ball and a white cap with a visor.
	ci.draw_rect(Rect2(up.call(-3.0, -52.0), Vector2(6.0, 5.0) * k), SKIN)
	var head: Vector2 = up.call(0.0, -62.0)
	ci.draw_circle(head, 11.0 * k + 4.0, OL)
	ci.draw_circle(head, 11.0 * k, HAIR)
	ci.draw_circle(head + Vector2(3.0, 1.0) * k, 8.5 * k, SKIN)
	ci.draw_circle(head + Vector2(-3.0, 1.0) * k, 3.0 * k + 3.0, OL)
	ci.draw_circle(head + Vector2(-3.0, 1.0) * k, 3.0 * k, SKIN)
	ci.draw_circle(head + Vector2(6.0, 4.0) * k, 2.5 * k, Color("f89898"))
	ci.draw_rect(Rect2(head + Vector2(6.5, -3.0) * k, Vector2(2.0, 4.0) * k), OL)
	ci.draw_line(head + Vector2(4.0, 7.0) * k, head + Vector2(8.0, 6.5) * k, OL, 3.0)
	# The white baseball cap: a round crown with a button and seams, a band round the head and a curved visor to the front.
	var cap := PackedVector2Array()
	for i in 21:
		var a := PI + PI * float(i) / 20.0
		cap.append(head + Vector2(1.0 + cos(a) * 13.5, -4.0 + sin(a) * 13.0) * k)
	ci.draw_colored_polygon(cap, WHITE)
	ci.draw_polyline(cap, OL, 4.0)
	for sx in [-5.0, 5.0]:
		var seam := PackedVector2Array()
		for i in 7:
			var f := float(i) / 6.0
			seam.append(head + Vector2(1.0 + sx * (0.2 + 0.8 * f), -17.0 + 12.0 * f) * k)
		ci.draw_polyline(seam, Color("c8c8c8"), 3.0)
	ci.draw_circle(head + Vector2(1.0, -17.2) * k, 2.2 * k + 2.0, OL)
	ci.draw_circle(head + Vector2(1.0, -17.2) * k, 2.2 * k, Color("c8c8c8"))
	poly.call([head + Vector2(-12.5, -5.5) * k, head + Vector2(14.5, -5.5) * k, head + Vector2(14.5, -3.0) * k,
			head + Vector2(-12.5, -3.0) * k], Color("e8e8e8"))
	var visor := PackedVector2Array([head + Vector2(8.0, -5.5) * k, head + Vector2(16.0, -7.0) * k, head + Vector2(24.0, -4.5) * k,
			head + Vector2(25.0, -1.0) * k, head + Vector2(17.0, -2.5) * k, head + Vector2(8.0, -3.0) * k])
	ci.draw_colored_polygon(visor, WHITE)
	ci.draw_polyline(visor + PackedVector2Array([visor[0]]), OL, 4.0)
	ci.draw_line(head + Vector2(10.0, -3.2) * k, head + Vector2(24.0, -1.8) * k, Color("a8a8a8"), 3.0)
	# The putter, drawn like a real one: a long thin steel shaft, a black grip with a rounded top, and a small blade head
	# that lies on
	# the ground. At the ball the shaft goes down to the ball at an angle and the head stands behind the ball.
	var ang := deg_to_rad(float(pose.a))
	var head_at: Vector2 = hand + Vector2(cos(ang), -sin(ang)) * CLUB * k
	var at_ball: Vector2 = club_head_at(geo, ball_c)
	head_at = head_at.lerp(at_ball, float(pose.ab))
	var shaft := head_at - hand
	var dir := shaft.normalized()
	var side := dir.orthogonal()
	var grip_end := hand + shaft * 0.32
	var heel := head_at - dir * 3.0 * k
	ci.draw_line(hand - dir * 5.0 * k, heel, OL, maxf(7.0, 3.6 * k))
	ci.draw_line(hand - dir * 5.0 * k, heel, STEEL, maxf(3.0, 1.8 * k))
	ci.draw_line(hand + dir * 3.0 * k + side * 1.0, heel + side * 1.0, ROCK_HI, 2.0)
	ci.draw_line(hand - dir * 5.0 * k, grip_end, OL, maxf(11.0, 5.5 * k))
	ci.draw_line(hand - dir * 5.0 * k, grip_end, GRIP, maxf(7.0, 3.5 * k))
	ci.draw_circle(hand - dir * 5.0 * k, maxf(5.0, 2.8 * k), GRIP)
	var blade := PackedVector2Array([head_at + Vector2(-9.0, -5.0) * k, head_at + Vector2(6.0, -5.0) * k,
			head_at + Vector2(7.0, 1.0) * k, head_at + Vector2(-9.0, 1.0) * k])
	ci.draw_colored_polygon(blade, STEEL)
	ci.draw_polyline(blade + PackedVector2Array([blade[0]]), OL, 4.0)
	ci.draw_rect(Rect2(head_at + Vector2(-9.0, -5.0) * k, Vector2(15.0, 1.6) * k), GOLD)
	ci.draw_rect(Rect2(head_at + Vector2(-9.0, -0.6) * k, Vector2(16.0, 1.6) * k), STEEL_LO)
