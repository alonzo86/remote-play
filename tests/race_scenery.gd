extends SceneTree
## The scenery beside the road of Car Race (REQ-MR-57, test 9 item 13e): no pixel of any piece of scenery is on the road, and no
## two pieces cover each other. The cars stay on the road, so a piece that is off the road covers no car. It looks at the opaque
## pixels of every piece of the 10 fixed tracks on Hard in the 3 themes, not at the middle of the piece. Run:
##   godot --headless --path . --script tests/race_scenery.gd -- --role=controller

const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")
const RaceLook = preload("res://scripts/game/marble_race/race_look.gd")

const ROAD_MARGIN := 0.25   # Meters: no pixel of scenery is nearer to the middle line than the half width plus this.
const STRIDE := 2           # Every second pixel of a piece is looked at.

var _checks := 0
var _fails := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_scenery()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The distance in meters from the middle line of `track` to the nearest opaque pixel of the piece `pic` that stands at `pos`
## (the picture is centered on `pos`, one meter is `RaceLook.PX` pixels). It gives up early when the piece is far away.
func _nearest_pixel(track: RefCounted, pic: Image, pos: Vector2) -> float:
	var size := Vector2(pic.get_size())
	var reach := size.length() * 0.5 / float(RaceLook.PX)   # The corner of the picture.
	var middle: float = track.query(pos).dist
	if middle - reach >= track.half_width + ROAD_MARGIN + 1.0:
		return middle - reach   # Every pixel is at least this far: no need to look at them.
	var best := INF
	for y in range(0, pic.get_height(), STRIDE):
		for x in range(0, pic.get_width(), STRIDE):
			if pic.get_pixel(x, y).a > 0.0:
				var world := pos + (Vector2(x + 0.5, y + 0.5) - size * 0.5) / float(RaceLook.PX)
				best = minf(best, track.query(world).dist)
	return best


func _scenery() -> void:
	print("the scenery of Car Race")
	for theme in RaceLook.THEMES:
		var pieces := 0
		var tracks_ok := true
		var closest := INF
		var worst_pair := INF
		var overlap_ok := true
		var pics := {}
		for kind in RaceLook.look(theme).decor:
			pics[kind] = RaceLook.decor_image(theme, String(kind))
		for seed_value in MarbleTrack.FIXED_SEEDS:
			var track = MarbleTrack.make(seed_value, "hard")
			var decor: Array = RaceLook.decorations(theme, track.points, track.half_width, seed_value)
			tracks_ok = tracks_ok and decor.size() > 10
			pieces += decor.size()
			for i in decor.size():
				var near := _nearest_pixel(track, pics[decor[i].kind], decor[i].pos)
				closest = minf(closest, near - track.half_width)
			for i in decor.size():
				var pa: Image = pics[decor[i].kind]
				var ra := maxf(pa.get_width(), pa.get_height()) * 0.5 / float(RaceLook.PX)
				for j in range(i + 1, decor.size()):
					var d: float = decor[i].pos.distance_to(decor[j].pos)
					if d > 12.0:
						continue   # Two pieces that are 12 m apart cannot touch (a piece is 4.5 m wide at most).
					var pb: Image = pics[decor[j].kind]
					var rb := maxf(pb.get_width(), pb.get_height()) * 0.5 / float(RaceLook.PX)
					worst_pair = minf(worst_pair, d - ra - rb)
					overlap_ok = overlap_ok and d >= ra + rb
		_check(tracks_ok and pieces > 100, "%s: the 10 fixed tracks have scenery (%d pieces, more than 10 for each track)"
				% [theme, pieces])
		_check(closest >= ROAD_MARGIN, ("%s: no pixel of any of the %d pieces is on the road: the nearest is %.2f m outside the " +
				"road (at least %.2f m)") % [theme, pieces, closest, ROAD_MARGIN])
		_check(overlap_ok, "%s: no two pieces of scenery cover each other (the closest pair has %.2f m between their circles)"
				% [theme, worst_pair])
