extends RefCounted
## The five holes of Mini Golf (REQ-MG-12), made in advance. A hole is data: the ground the ball may roll on (`fairway`, a list
## of rectangles that overlap at the turns), the place of the tee and of the cup, and the things on the course: lakes (`water`,
## a rectangle from wall to wall) with `bridges`, rocks (`Vector3(x, z, radius)`) and the tower of a windmill
## (`blocks`, `Rect2`; the first block of a hole with `windmill` is the tower, with a door of width `door` along z in the middle
## that the ball goes through along x, `solid_blocks()`) and hills (`hills`: a bump, or a ramp up to a platform and a slide down).
## All in the same units as the picture (`golf_look.gd`): x across (the middle of the view is 0) and z along, away from the
## camera, about a meter each. `Rect2(x, z, width, depth)` has its near left corner at (x, z). The par of a hole is the strokes
## of a good player (REQ-MG-6). The first values are guesses (Manual test 26).

const COUNT := 5
const BALL_R := 0.045
const CUP_R := 0.1

const HOLES: Array[Dictionary] = [
	# 1: a straight hole with a hill to climb (a soft putt rolls back) and a rock to steer around.
	{"par": 2, "tee": Vector2(0.0, 1.1), "cup": Vector2(0.0, 5.1),
			"fairway": [Rect2(-0.8, 0.75, 1.6, 5.0)], "water": [], "bridges": [],
			"hills": [{"rect": Rect2(-0.8, 1.7, 1.6, 0.9), "height": 0.12}],
			"blocks": [], "rocks": [Vector3(-0.3, 3.4, 0.17)]},
	# 2: two rows with a wall between them. The ball crosses a lake by the bridge in the near row, then goes up through the
	# door of the windmill (the only way into the far row) to the cup. The rows are wide (1.1 m) and the rock leaves a free lane
	# (owner, 2026-11-04: it was too narrow).
	{"par": 3, "tee": Vector2(0.7, 1.2), "cup": Vector2(-0.68, 5.4), "windmill": true, "door": 0.30,
			"fairway": [Rect2(0.13, 0.75, 1.1, 3.95), Rect2(-1.23, 3.2, 1.1, 3.0), Rect2(-0.3, 3.65, 0.6, 0.5)],
			"water": [Rect2(0.13, 1.9, 1.1, 0.7)], "bridges": [Rect2(0.4, 1.9, 0.6, 0.7)],
			"blocks": [Rect2(-0.13, 3.65, 0.26, 0.5)], "rocks": [Vector3(0.68, 3.1, 0.12)]},
	# 3: a hill, then a turn to the right with a rock at the corner before the cup.
	{"par": 3, "tee": Vector2(0.0, 1.1), "cup": Vector2(2.4, 3.6),
			"fairway": [Rect2(-0.7, 0.75, 1.4, 2.7), Rect2(-0.7, 2.9, 3.6, 1.4)], "water": [], "bridges": [],
			"hills": [{"rect": Rect2(-0.7, 1.6, 1.4, 0.8), "height": 0.1}],
			"blocks": [], "rocks": [Vector3(0.9, 3.3, 0.15)]},
	# 4: a lake from wall to wall with a narrow bridge in the middle and rocks before it, then a ramp up to a platform and a slide
	# down, and the cup just after the slide.
	{"par": 3, "tee": Vector2(-0.6, 1.1), "cup": Vector2(0.0, 5.45),
			"fairway": [Rect2(-1.25, 0.75, 2.5, 5.0)], "water": [Rect2(-1.25, 2.7, 2.5, 1.0)],
			"bridges": [Rect2(-0.3, 2.7, 0.6, 1.0)],
			"hills": [{"rect": Rect2(-1.25, 3.95, 2.5, 1.15), "height": 0.14, "kind": "slide"}],
			"blocks": [], "rocks": [Vector3(-0.7, 1.9, 0.16), Vector3(0.45, 2.1, 0.16)]},
	# 5: an S. A hill and a rock in the first leg, then the turn down, and a hill before the cup in the last leg (owner,
	# 2026-11-05: the windmill of this hole faced the wrong way to play, so it is gone).
	{"par": 4, "tee": Vector2(-0.7, 1.1), "cup": Vector2(1.2, 5.45),
			"fairway": [Rect2(-1.2, 0.75, 1.4, 2.3), Rect2(-1.2, 2.7, 3.0, 1.2), Rect2(0.6, 3.6, 1.2, 2.4)],
			"water": [], "bridges": [],
			"hills": [{"rect": Rect2(-1.2, 1.6, 1.4, 0.8), "height": 0.1}, {"rect": Rect2(0.6, 4.3, 1.2, 0.8), "height": 0.1}],
			"blocks": [], "rocks": [Vector3(-0.55, 2.85, 0.14)]},
]


## What the ball cannot enter: the blocks, but the tower of a windmill is two pillars with the door (`door`, along z, in the
## middle of the tower) between them. The ball goes through the door along x.
static func solid_blocks(h: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in h.blocks.size():
		var b: Rect2 = h.blocks[i]
		if i == 0 and h.get("windmill", false):
			var side := (b.size.y - float(h.get("door", 0.3))) * 0.5
			out.append(Rect2(b.position.x, b.position.y, b.size.x, side))
			out.append(Rect2(b.position.x, b.end.y - side, b.size.x, side))
		else:
			out.append(b)
	return out


## The shape of a hill (`hills`, `{"rect": Rect2, "height": m, "kind": "bump" | "slide"}`) along z, for `t` from 0 to 1 over its
## rectangle: `Vector2(height as a share of `height`, its change per unit of t)`. A bump is smooth (sin squared); a slide is a
## ramp up over the first 45%, a flat platform over the next 15% and a slide down over the last 40%.
static func hill_profile(hl: Dictionary, t: float) -> Vector2:
	if String(hl.get("kind", "bump")) == "slide":
		if t < 0.45:
			return Vector2(t / 0.45, 1.0 / 0.45)
		if t < 0.6:
			return Vector2(1.0, 0.0)
		return Vector2(1.0 - (t - 0.6) / 0.4, -1.0 / 0.4)
	return Vector2(pow(sin(PI * t), 2.0), PI * sin(2.0 * PI * t))


## The height of the ground of a hole at `p` (m): a hill is across the whole width of its rectangle, `height` at the top and 0
## at both ends.
static func hill_height(h: Dictionary, p: Vector2) -> float:
	for hl in h.get("hills", []):
		var r: Rect2 = hl.rect
		if r.has_point(p):
			return float(hl.height) * hill_profile(hl, (p.y - r.position.y) / r.size.y).x
	return 0.0


## The slope of the ground at `p` along z (dh/dz, positive going up in the direction of the course axis).
static func hill_slope(h: Dictionary, p: Vector2) -> float:
	for hl in h.get("hills", []):
		var r: Rect2 = hl.rect
		if r.has_point(p):
			return float(hl.height) * hill_profile(hl, (p.y - r.position.y) / r.size.y).y / r.size.y
	return 0.0


## The hole `n` (1 to COUNT). A number outside the range gives the nearest hole.
static func hole(n: int) -> Dictionary:
	return HOLES[clampi(n, 1, COUNT) - 1]


## The par of the first `holes` holes together.
static func par_total(holes: int) -> int:
	var total := 0
	for i in clampi(holes, 0, COUNT):
		total += int(HOLES[i].par)
	return total


## True when a ball at `p` is in the water of a hole: inside a lake (`water`, `Rect2`) and not on a bridge (`bridges`, `Rect2`).
static func is_water(h: Dictionary, p: Vector2) -> bool:
	for r in h.bridges:
		if (r as Rect2).has_point(p):
			return false
	for r in h.water:
		if (r as Rect2).has_point(p):
			return true
	return false
