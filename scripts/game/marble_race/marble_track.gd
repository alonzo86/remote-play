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


const IDS: Array[String] = ["classic", "sprint", "zigzag", "gauntlet"]


## Builds one of the tracks in IDS. Every track starts with a straight, 8 m or longer, toward -z
## (up on the screen), so the start grid works. Other bends are free but must not touch themselves.
static func make(track_id: String) -> RefCounted:
	var pts: Array[Vector2] = []
	var hw := 3.4
	var title := "Classic"
	var bumpers := []
	match track_id:
		"sprint":
			title = "Sprint"
			hw = 4.0
			pts = [Vector2(0, 8), Vector2(0, -10), Vector2(6, -20), Vector2(-6, -34),
					Vector2(-6, -46), Vector2(0, -58), Vector2(0, -76)]
			bumpers = [[14.0, -1.0], [30.0, 1.0], [46.0, -1.0], [62.0, 0.8]]
		"zigzag":
			title = "Zigzag"
			hw = 2.9
			pts = [Vector2(0, 8), Vector2(0, -14), Vector2(12, -26), Vector2(-12, -40),
					Vector2(12, -54), Vector2(-12, -68), Vector2(12, -82), Vector2(0, -94),
					Vector2(0, -116)]
		"gauntlet":
			title = "Gauntlet"
			hw = 4.6
			pts = [Vector2(0, 8), Vector2(0, -40), Vector2(5, -60), Vector2(5, -110),
					Vector2(0, -130), Vector2(0, -150)]
			for i in 15:
				bumpers.append([14.0 + i * 8.5, [-1.4, 1.4, 0.0, 1.0, -1.0][i % 5]])
		_:
			track_id = "classic"
			pts = [Vector2(0, 8), Vector2(0, -20), Vector2(9, -36), Vector2(9, -54),
					Vector2(-7, -70), Vector2(-7, -88), Vector2(0, -102), Vector2(0, -124)]
			bumpers = [[14.0, -1.0], [26.0, 0.8], [40.0, -0.7], [52.0, 1.0], [66.0, 0.0],
					[78.0, -1.0], [90.0, 0.8], [102.0, 0.0], [112.0, -0.8]]
	var t = load("res://scripts/game/marble_race/marble_track.gd").new(pts, hw)
	t.id = track_id
	t.title = title
	t.bumpers = bumpers
	return t
