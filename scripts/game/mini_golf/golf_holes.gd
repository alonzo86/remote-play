extends RefCounted
## The five holes of Mini Golf (REQ-MG-12), made in advance. A hole is data: the ground the ball may roll on (`fairway`, a
## list of rectangles that overlap at the turns), the place of the tee and of the cup, and the things on the course. All in
## the same units as the picture (`golf_look.gd`): x across (the middle of the view is 0) and z along, away from the camera,
## about a meter each. `Rect2(x, z, width, depth)` is a rectangle with its near left corner at (x, z). An ellipse is
## `Vector4(x, z, radius x, radius z)`, a bumper `Vector3(x, z, radius)`.
## The par of a hole is the strokes of a good player (REQ-MG-6). The first values are guesses (Manual test 26).

const COUNT := 5
const BALL_R := 0.045
const CUP_R := 0.1

const HOLES: Array[Dictionary] = [
	# 1: a straight, easy hole.
	{"par": 2, "tee": Vector2(0.0, 1.1), "cup": Vector2(0.0, 5.1),
			"fairway": [Rect2(-0.8, 0.75, 1.6, 5.0)], "sand": [], "water": [], "bumpers": [], "blocks": []},
	# 2: sand on the left, a pond on the right, a windmill and two bumpers before the cup.
	{"par": 3, "tee": Vector2(-0.42, 1.2), "cup": Vector2(0.25, 5.3),
			"fairway": [Rect2(-1.25, 0.75, 2.5, 5.45)], "sand": [Vector4(-0.5, 2.2, 0.45, 0.5)],
			"water": [Vector4(0.45, 3.0, 0.8, 0.75)],
			"bumpers": [Vector3(0.55, 4.4, 0.2), Vector3(-0.15, 4.4, 0.2)],
			"blocks": [Rect2(-0.8, 3.45, 0.4, 0.3)]},
	# 3: a turn to the right with a bumper and a little sand at the corner.
	{"par": 3, "tee": Vector2(0.0, 1.1), "cup": Vector2(2.4, 3.6),
			"fairway": [Rect2(-0.7, 0.75, 1.4, 2.7), Rect2(-0.7, 2.9, 3.6, 1.4)], "sand": [Vector4(0.4, 3.9, 0.35, 0.25)],
			"water": [], "bumpers": [Vector3(1.4, 3.6, 0.2)], "blocks": []},
	# 4: a bridge: water on both sides in the middle, a narrow way between.
	{"par": 3, "tee": Vector2(-0.6, 1.1), "cup": Vector2(0.0, 5.0),
			"fairway": [Rect2(-1.25, 0.75, 2.5, 5.0)], "sand": [],
			"water": [Vector4(-1.15, 3.0, 0.9, 0.55), Vector4(1.15, 3.0, 0.9, 0.55)], "bumpers": [], "blocks": []},
	# 5: an S, with sand at the start, a puddle in the middle and a bumper before the cup.
	{"par": 4, "tee": Vector2(-0.7, 1.1), "cup": Vector2(1.2, 5.4),
			"fairway": [Rect2(-1.2, 0.75, 1.4, 2.3), Rect2(-1.2, 2.7, 3.0, 1.2), Rect2(0.6, 3.6, 1.2, 2.4)],
			"sand": [Vector4(-0.5, 2.0, 0.4, 0.4)], "water": [Vector4(0.1, 3.3, 0.35, 0.3)],
			"bumpers": [Vector3(1.2, 4.4, 0.18)], "blocks": []},
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


## True when `p` is inside an ellipse of `list` (`Vector4`, see above).
static func in_ellipse(list: Array, p: Vector2) -> bool:
	for e in list:
		var v: Vector4 = e
		var dx := (p.x - v.x) / v.z
		var dz := (p.y - v.y) / v.w
		if dx * dx + dz * dz < 1.0:
			return true
	return false
