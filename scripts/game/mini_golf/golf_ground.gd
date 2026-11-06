extends RefCounted
## The pictures of the kinds of ground of Mini Golf that act on the ball (`golf_holes.gd`, `golf_sim.gd`): a sand trap, the ramp
## and the exit of a loop, the ring of a loop, the pads of a teleport, the ramp of a jump and the cannon. They are drawn by
## `golf_look.gd` with its `Geo` (the place of a point of the course on the screen; it is not typed here, so that the two files
## do not need each other).

const Palette = preload("res://scripts/game/palette.gd")

const OL := Color("181818")
const GOLD := Color("f8b800")
const RED := Palette.NES_RED
const WOOD := Color("ac6418")
const WOOD_HI := Color("d8a868")
const SAND := Color("e8d098")
const SAND_EDGE := Color("b8985c")


## A sand trap: a patch of sand with a darker edge and specks. The ball slows down fast in it (`GolfSim.SAND_DECEL`).
static func draw_sand(ci: CanvasItem, geo, r: Rect2) -> void:
	var f: Rect2 = geo.rect(r)
	ci.draw_rect(f.grow(4.0), SAND_EDGE)
	ci.draw_rect(f, SAND)
	var step: float = 28.0 * geo.u
	var gx := 0
	var x := f.position.x + step * 0.5
	while x < f.end.x - 6.0:
		var gy := 0
		var y := f.position.y + step * 0.5
		while y < f.end.y - 6.0:
			if (gx * 7 + gy * 3) % 5 < 2:
				ci.draw_rect(Rect2(geo.snap(Vector2(x + float((gx * 5 + gy * 3) % 9) - 4.0, y)), Vector2(8.0, 4.0) * float(geo.u)), SAND_EDGE)
			y += step
			gy += 1
		x += step
		gx += 1


## The wooden ramp that leads into a loop (the entry zone, with arrows that point along the course) and the landing strip where
## the ball comes out (with arrows in the heading of the loop).
static func draw_loop_ground(ci: CanvasItem, geo, l: Dictionary) -> void:
	var f: Rect2 = geo.rect((l.enter as Rect2).merge(l.base))
	ci.draw_rect(f.grow(4.0), OL)
	ci.draw_rect(f, WOOD_HI)
	for i in range(1, 6):
		var x := f.position.x + f.size.x * float(i) / 6.0
		ci.draw_line(Vector2(x, f.position.y), Vector2(x, f.end.y), WOOD, 3.0)
	var c: Vector2 = geo.at((l.enter as Rect2).get_center())
	for k in [-1.0, 0.0, 1.0]:
		_chevron(ci, c + Vector2(float(k) * 36.0 * float(geo.u) - 40.0 * float(geo.u), 0.0), Vector2.RIGHT, RED, float(geo.u))
	var e: Vector2 = geo.at(l.exit)
	var d: Vector2 = geo.dir(float(l.heading)).normalized()
	var land := Rect2(e - Vector2(34.0, 22.0) * float(geo.u), Vector2(68.0, 44.0) * float(geo.u))
	ci.draw_rect(land.grow(4.0), OL)
	ci.draw_rect(land, WOOD_HI)
	_chevron(ci, e, d, RED, float(geo.u))


static func _chevron(ci: CanvasItem, at: Vector2, d: Vector2, col: Color, u: float) -> void:
	var n := d.orthogonal()
	ci.draw_polyline(PackedVector2Array([at - d * 9.0 * u + n * 14.0 * u, at + d * 8.0 * u, at - d * 9.0 * u - n * 14.0 * u]),
			col, 6.0)


## The screen place of the ball while it goes round the ring of a loop: `t` from 0 to 1, from the foot of the ring, up its far
## side, over the top and down again.
static func loop_ball(geo, l: Dictionary, t: float) -> Vector2:
	var r: float = float(l.radius) * float(geo.s)
	var c: Vector2 = Vector2(geo.at(l.ring)) - Vector2(0.0, r)
	var a: float = TAU * clampf(t, 0.0, 1.0)
	return c + Vector2(sin(a), cos(a)) * r


## The ring of a loop, standing on its foot (the solid `base`): a steel ring in the plane of the course, seen from the front.
static func draw_loop_ring(ci: CanvasItem, geo, l: Dictionary) -> void:
	var r: float = float(l.radius) * float(geo.s)
	var foot: Vector2 = geo.at(l.ring)
	var c := foot - Vector2(0.0, r)
	var slab: Rect2 = geo.rect(l.base)
	ci.draw_rect(Rect2(slab.position.x, slab.end.y - 12.0 * float(geo.u), slab.size.x, 12.0 * float(geo.u)).grow(3.0), OL)
	ci.draw_rect(Rect2(slab.position.x, slab.end.y - 12.0 * float(geo.u), slab.size.x, 12.0 * float(geo.u)), WOOD)
	for w in [14.0, 8.0]:
		var col := OL if w > 10.0 else Color("a8b4c8")
		ci.draw_arc(c, r, 0.0, TAU, 48, col, w * float(geo.u) + (6.0 if w > 10.0 else 0.0))
	ci.draw_arc(c, r, 0.0, TAU, 24, Color("5c6880"), 3.0, false)
	for post in [-1.0, 1.0]:   # Two posts hold the ring.
		var x: float = c.x + float(post) * r * 0.6
		ci.draw_line(Vector2(x, foot.y - r * 0.2), Vector2(x, foot.y), OL, 8.0)
	ci.draw_circle(c, 6.0 * float(geo.u), Color("a8b4c8"))


## A teleport: an entrance pad (purple) and an exit pad (cyan) with a white eye. `a_k` and `b_k` (0 to 1) are how big they are
## now: the entrance shows at the start of a turn, the exit opens when the ball has gone in, and then both close (owner,
## 2026-11-05).
static func draw_portals(ci: CanvasItem, geo, t: Dictionary, a_k: float, b_k: float, time: float) -> void:
	var pads: Array = [[t.a, Palette.GOLF_PAD_A, Color("e0b0fc"), a_k], [t.b, Palette.GOLF_PAD_B, Color("b0f0fc"), b_k]]
	for p in pads:
		var k: float = float(p[3])
		if k <= 0.01:
			continue
		var c: Vector2 = geo.at(p[0])
		var r: float = float(t.r) * float(geo.s) * k
		var pulse := 1.0 + 0.06 * sin(time * 6.0)
		ci.draw_colored_polygon(_ellipse(c + Vector2(4.0, 6.0), r * 1.1, r * 0.5), Color(0.0, 0.2, 0.0, 0.4))
		ci.draw_colored_polygon(_ellipse(c, r + 4.0, (r + 4.0) * 0.55), OL)
		ci.draw_colored_polygon(_ellipse(c, r, r * 0.55), p[1])
		ci.draw_colored_polygon(_ellipse(c, r * 0.68 * pulse, r * 0.38 * pulse), p[2])
		ci.draw_colored_polygon(_ellipse(c, r * 0.3, r * 0.16), Color("fcfcfc"))


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## The ramp of a jump: a wooden wedge in front of the lake with red arrows, and a raised lip at the water side.
static func draw_jump_ramp(ci: CanvasItem, geo, j: Dictionary) -> void:
	var f: Rect2 = geo.rect(j.enter)
	var u: float = float(geo.u)
	ci.draw_rect(f.grow(4.0), OL)
	ci.draw_rect(f, WOOD_HI)
	for i in range(1, 5):
		var x := f.position.x + f.size.x * float(i) / 5.0
		ci.draw_line(Vector2(x, f.position.y), Vector2(x, f.end.y), WOOD, 3.0)
	ci.draw_rect(Rect2(f.end.x - 14.0 * u, f.position.y - 10.0 * u, 14.0 * u, f.size.y + 10.0 * u).grow(3.0), OL)
	ci.draw_rect(Rect2(f.end.x - 14.0 * u, f.position.y - 10.0 * u, 14.0 * u, f.size.y + 10.0 * u), WOOD)
	_chevron(ci, f.get_center() - Vector2(14.0 * u, 0.0), Vector2.RIGHT, RED, u)


## The screen place of the ball while it flies (a jump or a cannon): `t` from 0 to 1 along an arc from the ramp or the muzzle to
## the landing. A ball that is still inside the cannon gives `Vector2.INF` (it is not drawn).
static func flight_ball(geo, l: Dictionary, t: float) -> Vector2:
	var cannon := String(l.get("kind", "")) == "cannon"
	var from: Vector2 = geo.at((l.enter as Rect2).get_center())
	var inside := 0.3
	var s: float = float(geo.s)
	if cannon:
		if t < inside:
			return Vector2.INF
		from = cannon_muzzle(geo, l)
		t = (t - inside) / (1.0 - inside)
	var to: Vector2 = geo.at(l.exit)
	var arc: float = (0.8 if cannon else 0.45) * s
	return from.lerp(to, t) - Vector2(0.0, 4.0 * arc * t * (1.0 - t))


## The mouth of the barrel of a cannon on the screen (the base is `pos`; the barrel points at the landing).
static func cannon_muzzle(geo, c: Dictionary) -> Vector2:
	var base: Vector2 = geo.at(c.pos)
	var d: Vector2 = (Vector2(geo.at(c.exit)) - base).normalized()
	return base + d * 0.3 * float(geo.s) - Vector2(0.0, 0.26 * float(geo.s))


## The hatch of a cannon on the ground: a dark opening with a gold rim and a red arrow towards the cannon.
static func draw_cannon_hatch(ci: CanvasItem, geo, c: Dictionary) -> void:
	var f: Rect2 = geo.rect(c.enter)
	var u: float = float(geo.u) * 1.35   # A big cannon: it is the hero of its hole.
	var m := f.get_center()
	ci.draw_colored_polygon(_ellipse(m, f.size.x * 0.5 + 4.0, f.size.y * 0.5 + 4.0), OL)
	ci.draw_colored_polygon(_ellipse(m, f.size.x * 0.5, f.size.y * 0.5), GOLD)
	ci.draw_colored_polygon(_ellipse(m, f.size.x * 0.4, f.size.y * 0.38), Color("383838"))
	var d: Vector2 = (Vector2(geo.at(c.pos)) - m).normalized()
	_chevron(ci, m, d, RED, u)


## The cannon: a wooden carriage on two spoked wheels with a steel barrel that points up and across the field to the landing
## place. The barrel is a tapered tube with three bands, a round knob at the back (the breech) and a flared muzzle with a dark
## bore.
static func draw_cannon(ci: CanvasItem, geo, c: Dictionary) -> void:
	var u: float = float(geo.u)
	var base: Vector2 = geo.at(c.pos)
	var muzzle := cannon_muzzle(geo, c)
	ci.draw_colored_polygon(_ellipse(base + Vector2(8.0, 6.0) * u, 52.0 * u, 16.0 * u), Color(0.0, 0.2, 0.0, 0.4))
	var pivot := base - Vector2(0.0, 30.0 * u)
	var d := (muzzle - pivot).normalized()
	var n := d.orthogonal()
	var back := pivot - d * 26.0 * u
	# The carriage: a wooden block between the wheels, with a plank line.
	var carriage := PackedVector2Array([base + Vector2(-34.0, -6.0) * u, base + Vector2(34.0, -6.0) * u,
			base + Vector2(26.0, -34.0) * u, base + Vector2(-26.0, -34.0) * u])
	ci.draw_colored_polygon(carriage, WOOD)
	ci.draw_polyline(carriage + PackedVector2Array([carriage[0]]), OL, 4.0)
	ci.draw_line(base + Vector2(-30.0, -18.0) * u, base + Vector2(30.0, -18.0) * u, Color("683808"), 3.0)
	# The barrel: outline, steel, a light stripe along the top, and three dark bands.
	var rb := 19.0 * u
	var rm := 14.0 * u
	ci.draw_colored_polygon(PackedVector2Array([back + n * (rb + 3.0), muzzle + n * (rm + 3.0), muzzle - n * (rm + 3.0),
			back - n * (rb + 3.0)]), OL)
	ci.draw_colored_polygon(PackedVector2Array([back + n * rb, muzzle + n * rm, muzzle - n * rm, back - n * rb]), Color("5c6880"))
	ci.draw_line(back + n * rb * 0.55, muzzle + n * rm * 0.55, Color("a8b4c8"), 4.0)
	for t in [0.25, 0.5, 0.75]:
		var q := back.lerp(muzzle, t)
		var r := lerpf(rb, rm, t)
		ci.draw_line(q + n * r, q - n * r, Color("383838"), 5.0)
	# The knob at the back and the flared muzzle with its bore.
	ci.draw_circle(back - d * 8.0 * u, 11.0 * u + 3.0, OL)
	ci.draw_circle(back - d * 8.0 * u, 11.0 * u, Color("444450"))
	ci.draw_colored_polygon(_ellipse(muzzle, 10.0 * u + 3.0, 21.0 * u + 3.0), OL)
	ci.draw_colored_polygon(_ellipse(muzzle, 10.0 * u, 21.0 * u), Color("8090a8"))
	ci.draw_colored_polygon(_ellipse(muzzle + d * 2.0, 6.0 * u, 14.0 * u), Color("101010"))
	# The wheels: wood with a dark rim, a hub and spokes.
	for w in [-1.0, 1.0]:
		var wc := base + Vector2(float(w) * 30.0 * u, -2.0 * u)
		ci.draw_circle(wc, 22.0 * u + 3.0, OL)
		ci.draw_circle(wc, 22.0 * u, Color("d8a868"))
		ci.draw_circle(wc, 16.0 * u, WOOD)
		for k in 6:
			var a := TAU * float(k) / 6.0
			ci.draw_line(wc, wc + Vector2(cos(a), sin(a)) * 16.0 * u, Color("683808"), 3.0)
		ci.draw_circle(wc, 5.0 * u, OL)
