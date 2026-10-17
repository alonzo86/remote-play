extends RefCounted
## The five holes of Mini Golf (REQ-MG-12), made in advance. A hole is data: the ground the ball may roll on (`fairway`, a list
## of rectangles that overlap at the turns), the place of the tee and of the cup, and the things on the course: lakes (`water`,
## a rectangle from wall to wall), the `bridges` over them, bumpers and blocks. All in the same units as the picture
## (`golf_look.gd`): x across (the middle of the view is 0) and z along, away from the camera, about a meter each. `Rect2(x, z,
## width, depth)` is a rectangle with its near left corner at (x, z). A bumper is `Vector3(x, z, radius)`. The par of a hole is
## the strokes of a good player (REQ-MG-6). The first values are guesses (Manual test 26).

const COUNT := 5
const BALL_R := 0.045
const CUP_R := 0.1

const HOLES: Array[Dictionary] = [
	# 1: a straight, easy hole.
	{"par": 2, "tee": Vector2(0.0, 1.1), "cup": Vector2(0.0, 5.1),
			"fairway": [Rect2(-0.8, 0.75, 1.6, 5.0)], "water": [], "bridges": [], "bumpers": [], "blocks": []},
	# 2: a lake from wall to wall with a bridge on the right, then a windmill and two bumpers before the cup.
	{"par": 3, "tee": Vector2(-0.42, 1.2), "cup": Vector2(0.25, 5.3),
			"fairway": [Rect2(-1.25, 0.75, 2.5, 5.45)], "water": [Rect2(-1.25, 2.5, 2.5, 0.9)],
			"bridges": [Rect2(0.05, 2.5, 0.7, 0.9)],
			"bumpers": [Vector3(0.55, 4.4, 0.2), Vector3(-0.15, 4.4, 0.2)],
			"blocks": [Rect2(-0.8, 3.75, 0.4, 0.3)]},
	# 3: a turn to the right with a bumper at the corner.
	{"par": 3, "tee": Vector2(0.0, 1.1), "cup": Vector2(2.4, 3.6),
			"fairway": [Rect2(-0.7, 0.75, 1.4, 2.7), Rect2(-0.7, 2.9, 3.6, 1.4)], "water": [], "bridges": [],
			"bumpers": [Vector3(1.4, 3.6, 0.2)], "blocks": []},
	# 4: a lake from wall to wall with a narrow bridge in the middle.
	{"par": 3, "tee": Vector2(-0.6, 1.1), "cup": Vector2(0.0, 5.0),
			"fairway": [Rect2(-1.25, 0.75, 2.5, 5.0)], "water": [Rect2(-1.25, 2.7, 2.5, 1.0)],
			"bridges": [Rect2(-0.3, 2.7, 0.6, 1.0)], "bumpers": [], "blocks": []},
	# 5: an S with a bumper before the cup and a windmill block at the first turn.
	{"par": 4, "tee": Vector2(-0.7, 1.1), "cup": Vector2(1.2, 5.4),
			"fairway": [Rect2(-1.2, 0.75, 1.4, 2.3), Rect2(-1.2, 2.7, 3.0, 1.2), Rect2(0.6, 3.6, 1.2, 2.4)],
			"water": [], "bridges": [], "bumpers": [Vector3(1.2, 4.4, 0.18)], "blocks": [Rect2(-0.2, 3.2, 0.35, 0.25)]},
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
