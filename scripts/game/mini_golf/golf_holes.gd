extends RefCounted
## The five holes of Mini Golf (REQ-MG-12), made in advance. A hole is data: the ground the ball may roll on (`fairway`, a list
## of rectangles that overlap at the turns), the place of the tee and of the cup, and the things on the course: lakes (`water`,
## a rectangle from wall to wall) with `bridges`, rocks (`Vector3(x, z, radius)`), brick walls and the tower of a windmill
## (`blocks`, `Rect2`), sliding barriers (`movers`) and turning blades (`spinners`). All in the same units as the picture
## (`golf_look.gd`): x across (the middle of the view is 0) and z along, away from the camera, about a meter each. `Rect2(x, z,
## width, depth)` has its near left corner at (x, z). The par of a hole is the strokes of a good player (REQ-MG-6). The first
## values are guesses (Manual test 26).

const COUNT := 5
const BALL_R := 0.045
const CUP_R := 0.1

const HOLES: Array[Dictionary] = [
	# 1: a straight hole with a rock and a brick wall to steer around.
	{"par": 2, "tee": Vector2(0.0, 1.1), "cup": Vector2(0.0, 5.1),
			"fairway": [Rect2(-0.8, 0.75, 1.6, 5.0)], "water": [], "bridges": [], "spinners": [],
			"blocks": [Rect2(0.25, 3.6, 0.5, 0.25)], "rocks": [Vector3(-0.3, 3.0, 0.17)], "movers": []},
	# 2: a lake from wall to wall with a bridge on the right, then a windmill whose blades turn before the cup.
	{"par": 3, "tee": Vector2(-0.42, 1.2), "cup": Vector2(0.25, 5.3), "windmill": true,
			"fairway": [Rect2(-1.25, 0.75, 2.5, 5.45)], "water": [Rect2(-1.25, 2.5, 2.5, 0.9)],
			"bridges": [Rect2(0.05, 2.5, 0.7, 0.9)],
			"spinners": [{"c": Vector2(0.15, 4.5), "len": 0.5, "speed": 1.8}],
			"blocks": [Rect2(-0.8, 3.75, 0.4, 0.3)], "rocks": [Vector3(-0.55, 1.9, 0.15)], "movers": []},
	# 3: a turn to the right with a brick wall at the corner and a sliding barrier before the cup.
	{"par": 3, "tee": Vector2(0.0, 1.1), "cup": Vector2(2.4, 3.6),
			"fairway": [Rect2(-0.7, 0.75, 1.4, 2.7), Rect2(-0.7, 2.9, 3.6, 1.4)], "water": [], "bridges": [], "spinners": [],
			"blocks": [Rect2(0.0, 3.8, 0.45, 0.4)], "rocks": [Vector3(0.9, 3.3, 0.15)],
			"movers": [{"rect": Rect2(1.7, 2.9, 0.2, 0.65), "axis": "z", "amp": 0.75, "speed": 1.6}]},
	# 4: a lake from wall to wall with a narrow bridge in the middle, rocks before it and turning blades after it.
	{"par": 3, "tee": Vector2(-0.6, 1.1), "cup": Vector2(0.0, 5.0),
			"fairway": [Rect2(-1.25, 0.75, 2.5, 5.0)], "water": [Rect2(-1.25, 2.7, 2.5, 1.0)],
			"bridges": [Rect2(-0.3, 2.7, 0.6, 1.0)], "spinners": [{"c": Vector2(0.0, 4.4), "len": 0.55, "speed": 2.0}],
			"blocks": [], "rocks": [Vector3(-0.7, 1.9, 0.16), Vector3(0.45, 2.1, 0.16)], "movers": []},
	# 5: an S with a windmill block at the first turn, a rock, turning blades and a sliding barrier before the cup.
	{"par": 4, "tee": Vector2(-0.7, 1.1), "cup": Vector2(1.2, 5.4), "windmill": true,
			"fairway": [Rect2(-1.2, 0.75, 1.4, 2.3), Rect2(-1.2, 2.7, 3.0, 1.2), Rect2(0.6, 3.6, 1.2, 2.4)],
			"water": [], "bridges": [], "spinners": [{"c": Vector2(1.2, 4.2), "len": 0.42, "speed": -1.5}],
			"blocks": [Rect2(-0.2, 3.2, 0.35, 0.25)], "rocks": [Vector3(-0.6, 2.2, 0.17)],
			"movers": [{"rect": Rect2(0.6, 5.0, 0.55, 0.15), "axis": "x", "amp": 0.65, "speed": 1.4}]},
]


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


## The place of a sliding barrier at time `t` (s): it slides along its `axis` between its rectangle and `amp` further, back and
## forth. The same function is used by the ball and by the picture.
static func mover_rect(m: Dictionary, t: float) -> Rect2:
	var r: Rect2 = m.rect
	var off := float(m.amp) * (0.5 + 0.5 * sin(t * float(m.speed)))
	if String(m.axis) == "x":
		r.position.x += off
	else:
		r.position.y += off
	return r


## Where the arm of a turning blade of `s` ends at time `t`: the two ends of its bar, as `[a, b]`.
static func spinner_ends(s: Dictionary, t: float) -> Array:
	var c: Vector2 = s.c
	var dir := Vector2(cos(t * float(s.speed)), sin(t * float(s.speed))) * float(s.len)
	return [c - dir, c + dir]


## The point of a bar `a` to `b` that is nearest to `p`.
static func nearest_on_bar(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab := b - a
	var f := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return a + ab * f
