extends RefCounted
## Track for the marble race. A track is a polyline (x, z points) with one half-width.
## The drivable area is every point within half_width of the line. It has no holes and
## it has no overlap with itself, so "arc" (distance along the line) is always clear.

var points: Array[Vector2] = []
var half_width := 3.2
var length := 0.0

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


## The track used by the game. It runs toward -z (up on the screen) with three bends.
static func make_default() -> RefCounted:
	var pts: Array[Vector2] = [
		Vector2(0, 8), Vector2(0, -20), Vector2(9, -36), Vector2(9, -54),
		Vector2(-7, -70), Vector2(-7, -88), Vector2(0, -102), Vector2(0, -124),
	]
	return load("res://scripts/game/marble_race/marble_track.gd").new(pts, 3.4)
