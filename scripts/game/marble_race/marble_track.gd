extends RefCounted
## Track for the marble race. A track is a polyline (x, z points) with one half-width.
## The drivable area is every point within half_width of the line. It has no holes and
## it has no overlap with itself, so "arc" (distance along the line) is always clear.

var id := ""
var title := ""
var points: Array[Vector2] = []
var half_width := 3.2
var length := 0.0
## Round posts to steer around: [arc along the track, side] pairs. A side of 1.0 puts the post
## at 0.44 of the half-width from the center line, to the right of the driving direction.
var bumpers: Array = []

var _cum := PackedFloat32Array()   # Arc length at each point.


func _init(p_points: Array[Vector2], p_half_width: float) -> void:
	points = p_points
	half_width = p_half_width
	_cum.append(0.0)
	for i in range(1, points.size()):
		length += points[i].distance_to(points[i - 1])
		_cum.append(length)


## Nearest point on the line. Returns {dist, arc, closest}.
func query(p: Vector2) -> Dictionary:
	var best := {"dist": INF, "arc": 0.0, "closest": points[0]}
	for i in points.size() - 1:
		var a := points[i]
		var ab := points[i + 1] - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var c := a + ab * t
		var d := p.distance_to(c)
		if d < best.dist:
			best = {"dist": d, "arc": _cum[i] + t * ab.length(), "closest": c}
	return best


func point_at(arc: float) -> Vector2:
	var i := _segment_at(arc)
	var seg_len := _cum[i + 1] - _cum[i]
	return points[i].lerp(points[i + 1], clampf((arc - _cum[i]) / seg_len, 0.0, 1.0))


## Unit vector along the track at `arc`.
func dir_at(arc: float) -> Vector2:
	var i := _segment_at(arc)
	return (points[i + 1] - points[i]).normalized()


func _segment_at(arc: float) -> int:
	for i in points.size() - 1:
		if arc <= _cum[i + 1]:
			return i
	return points.size() - 2


## The 10 fixed tracks of the settings view are made from these seeds (REQ-MR-51, 53). A seed always gives the same track.
const FIXED_SEEDS: Array[int] = [11, 23, 37, 42, 58, 64, 71, 85, 93, 107]
## Posts for each 100 m of track, for each difficulty (REQ-MR-50).
const POSTS_PER_100M := {"easy": 2.0, "medium": 6.0, "hard": 10.0}
const POST_SIDES := [-1.2, -0.8, 0.0, 0.8, 1.2]
const START_STRAIGHT := 20.0     # The first straight, toward -z (up on the screen). It must be 8 m or more.
const POSTS_FROM := 14.0         # Posts start this far from the start and end 8 m before the end of the track.
const POSTS_BEFORE_END := 8.0
const LENGTH_MIN := 100.0        # The length of a generated track (REQ-MR-52). All are inside 90 to 170 m.
const LENGTH_MAX := 165.0
const HALF_WIDTH_MIN := 2.95     # Width 5.9 to 9.2 m.
const HALF_WIDTH_MAX := 4.6
const TURN_MIN := 15.0           # Degrees. A bend is never sharper than TURN_MAX, so a marble does not get stuck in a corner.
const TURN_MAX := 55.0
const HEADING_LIMIT := 65.0      # The track never turns more than this from "up", so it cannot curl back on itself.
const CLEARANCE := 1.0           # Extra room between two far parts of the track, besides the two half-widths.


## The track of a fixed seed (index 0 to 9) or a seed that is not fixed (the "Random track").
static func title_for(seed_value: int) -> String:
	var i := FIXED_SEEDS.find(seed_value)
	return "Track %d" % (i + 1) if i >= 0 else "Random track"


## The seed of a choice of the track list: "1" to "10" is a fixed seed, "random" is a new seed that is not one of the fixed ones.
static func seed_for(choice: String, rng: RandomNumberGenerator) -> int:
	if choice.is_valid_int() and int(choice) >= 1 and int(choice) <= FIXED_SEEDS.size():
		return FIXED_SEEDS[int(choice) - 1]
	var v := rng.randi_range(1000, 999999)
	while FIXED_SEEDS.has(v):
		v = rng.randi_range(1000, 999999)
	return v


## A track with its posts for a difficulty (REQ-MR-50, 51). The line depends on the seed only, so every difficulty has the same
## track. Every track starts with a straight, 8 m or longer, toward -z (up on the screen), so the start grid works.
static func make(seed_value: int, difficulty := "medium") -> RefCounted:
	var t = generate(seed_value)
	t.id = "seed_%d" % seed_value
	t.title = title_for(seed_value)
	t.bumpers = posts(t.length, seed_value, difficulty)
	return t


## The line of a track from a seed. A walk of straight pieces with smooth bends. A walk that touches itself is dropped and the
## next one is tried, so the result is always clear (REQ-MR-23). The same seed gives the same track.
static func generate(seed_value: int) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var limit := deg_to_rad(HEADING_LIMIT)
	for attempt in 80:
		var hw := rng.randf_range(HALF_WIDTH_MIN, HALF_WIDTH_MAX)
		var target := rng.randf_range(LENGTH_MIN, LENGTH_MAX)
		var pts: Array[Vector2] = [Vector2(0, 8), Vector2(0, 8.0 - START_STRAIGHT)]
		var dev := 0.0    # The heading, in radians from "up" (-z). Plus turns to the right.
		var total := START_STRAIGHT
		while total < target - 0.01:
			var remaining := target - total
			var seg := minf(rng.randf_range(14.0, 26.0), remaining)
			if remaining - seg < 10.0:
				seg = remaining
			var turn := deg_to_rad(rng.randf_range(TURN_MIN, TURN_MAX)) * (1.0 if rng.randf() < 0.5 else -1.0)
			if absf(dev + turn) > limit:
				turn = -turn
			dev += turn
			pts.append(pts[-1] + Vector2(sin(dev), -cos(dev)) * seg)
			total += seg
		if _is_clear(pts, hw):
			return _build(pts, hw)
	var straight: Array[Vector2] = [Vector2(0, 8), Vector2(0, -130)]   # Not reached with the fixed seeds (a test checks).
	return _build(straight, 3.6)


## The posts of a track: [arc, side] pairs, `POSTS_PER_100M` of the difficulty for each 100 m, spread evenly between
## POSTS_FROM and POSTS_BEFORE_END before the end. The sides change from post to post. They are made from the seed, apart from
## the line, so that a difficulty never changes the line.
static func posts(track_length: float, seed_value: int, difficulty: String) -> Array:
	var out := []
	var span := track_length - POSTS_BEFORE_END - POSTS_FROM
	var count := roundi(float(POSTS_PER_100M.get(difficulty, POSTS_PER_100M.medium)) * span / 100.0)
	if count <= 0 or span <= 0.0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var step := span / count
	var prev := 99.0
	for i in count:
		var side: float = POST_SIDES[rng.randi_range(0, POST_SIDES.size() - 1)]
		while side == prev:
			side = POST_SIDES[rng.randi_range(0, POST_SIDES.size() - 1)]
		prev = side
		out.append([POSTS_FROM + (i + 0.5) * step, side])
	return out


## True when no two parts of the line that are not neighbours are closer than two half-widths plus CLEARANCE.
static func _is_clear(pts: Array[Vector2], hw: float) -> bool:
	var need := hw * 2.0 + CLEARANCE
	for i in pts.size() - 1:
		for j in range(i + 2, pts.size() - 1):
			if Geometry2D.segment_intersects_segment(pts[i], pts[i + 1], pts[j], pts[j + 1]) != null:
				return false
			var d := minf(minf(_point_seg(pts[i], pts[j], pts[j + 1]), _point_seg(pts[i + 1], pts[j], pts[j + 1])),
					minf(_point_seg(pts[j], pts[i], pts[i + 1]), _point_seg(pts[j + 1], pts[i], pts[i + 1])))
			if d < need:
				return false
	return true


## A track of this class (a static function cannot call `new()` on its own class here).
static func _build(pts: Array[Vector2], hw: float) -> RefCounted:
	return load("res://scripts/game/marble_race/marble_track.gd").new(pts, hw)


static func _point_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
