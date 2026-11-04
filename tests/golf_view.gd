extends SceneTree
## The view of Mini Golf without a screen (docs/MINI_GOLF_REDESIGN.md option A, REQ-MG-2, 3, 4, 18, 19): the whole hole is drawn
## with one scale, so it always fits the room between the black bar and the chips, the ball and the cup keep one size, the aim
## line is as long on the screen as the putt on the course, the ball is white and only the one on turn is drawn, the banner
## plate keeps away from the cup, and the scenery stands outside the course.
## Run: godot --headless --path . --script tests/golf_view.gd -- --role=controller

const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")
const Look = preload("res://scripts/game/mini_golf/golf_look.gd")
const Shell = preload("res://scripts/game/shell.gd")

const SCREEN := Vector2(1920.0, 1080.0)
const CHIPS_TOP := 956.0        # The top of the frame of the first row of chips of the bar (y 960 and a frame of 4).
const CHIP_ROW := 72.0          # A second row of chips stands this much higher.

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
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_fits()
	_one_scale()
	_aim()
	await _ball()
	_plate()
	_scenery()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _course_rect(geo: Look.Geo) -> Rect2:
	var tl := geo.at(geo.bounds.position)
	return Rect2(tl, Vector2(geo.bounds.size.y * geo.s, geo.bounds.size.x * geo.s * geo.k + geo.wall_h))


## The whole hole, walls included (and the front face of the wall slab), is inside the 60 unit margin and between the black
## bar (112) and the chips, with one row of chips and with two (the HUD never lies on the course). One of its two sides fills the
## room: the scale is as big as it can be.
func _fits() -> void:
	print("the hole fits the room")
	for n in range(1, Holes.COUNT + 1):
		var hole: Dictionary = Holes.hole(n)
		for rows in [1, 2]:
			var geo := Look.Geo.new(SCREEN, hole, rows)
			var c := _course_rect(geo)
			var chips := CHIPS_TOP - CHIP_ROW * float(rows - 1)
			_check(c.position.x >= 60.0 - 0.01 and c.end.x <= 1860.0 + 0.01 and c.position.y >= 112.0 and c.end.y <= chips - 8.0,
					"hole %d, %d row(s) of chips: the course %s is inside x 60 to 1860 and y 112 to %.0f (the chips)"
					% [n, rows, str(c), chips - 8.0])
			var fill := maxf(c.size.x / geo.area.size.x, c.size.y / geo.area.size.y)
			_check(fill > 0.99, "hole %d, %d row(s): one side of the course fills the room (%.3f)" % [n, rows, fill])
		var one := Look.Geo.new(SCREEN, hole, 1)
		_check(one.s >= 200.0, "hole %d: the course is at least 200 units for each course unit (%.0f), so it can be read" % [n, one.s])


## One scale: a course unit along the course is as long on the screen at the tee as at the cup, and across it is squashed by the
## tilt of the camera (owner, 2026-11-04). The ball, the cup and the golfer have one size on every hole (the ball is 32 units
## wide with its outline, owner 2026-11-03).
func _one_scale() -> void:
	print("one scale")
	for n in range(1, Holes.COUNT + 1):
		var hole: Dictionary = Holes.hole(n)
		var geo := Look.Geo.new(SCREEN, hole, 1)
		var near := geo.at(Vector2(0.0, 1.0)).distance_to(geo.at(Vector2(0.0, 2.0)))
		var far := geo.at(Vector2(0.0, 4.0)).distance_to(geo.at(Vector2(0.0, 5.0)))
		var side := geo.at(Vector2(0.0, 3.0)).distance_to(geo.at(Vector2(1.0, 3.0)))
		_check(is_equal_approx(near, geo.s) and is_equal_approx(far, geo.s) and is_equal_approx(side, geo.s * geo.k),
				"hole %d: a course unit is %.1f units long along the course (near the tee %.1f, far %.1f) and %.1f across (tilt %.2f)"
				% [n, geo.s, near, far, side, geo.k])
		_check(geo.ball_d() == 32.0 and geo.cup_r() * 2.0 >= geo.ball_d() + 8.0,
				"hole %d: the ball is %.0f units wide and the cup %.0f, the ball fits in it" % [n, geo.ball_d(), geo.cup_r() * 2.0])
	var small := Look.Geo.new(Vector2(960.0, 540.0), Holes.hole(2), 1)
	_check(is_equal_approx(small.ball_d(), 16.0),
			"on a screen of half the size everything is half as big (the ball is %.0f)" % small.ball_d())
	var a := Look.Geo.new(SCREEN, Holes.hole(3), 1)
	var p := Vector2(1.3, 3.7)
	_check(a.point_at(a.at(p)).is_equal_approx(p), "a point of the course is found again from its place on the screen")


## The aim line is as long on the screen as the putt is on the course (Easy 3.0, Medium 1.2 course units, Hard only a marker of
## 0.6), at the tee and far from it, and it stops at the wall.
func _aim() -> void:
	print("the aim line")
	var hole: Dictionary = Holes.hole(1)
	var geo := Look.Geo.new(SCREEN, hole, 1)
	var from := Vector2(0.0, 1.1)
	for want in [3.0, 1.2]:
		var got := (Look.aim_end(geo, hole, from, 0.0, want) - geo.at(from)).length() / geo.s
		_check(absf(got - want) <= 0.03, "the aim line of %.1f course units is %.2f long at the tee" % [want, got])
	var far_from := Vector2(0.0, 4.5)
	var got_far := (Look.aim_end(geo, hole, far_from, 0.0, 1.2) - geo.at(far_from)).length() / geo.s
	_check(absf(got_far - 1.2) <= 0.03, "and %.2f course units long near the cup: it does not shrink with the distance" % got_far)
	var marker := (Look.aim_end(geo, hole, from, 0.0, 0.0) - geo.at(from)).length() / geo.s
	_check(absf(marker - Look.AIM_MARK) <= 0.03, "Hard has the marker only, %.2f course units from the ball" % marker)
	var wall_end := Look.aim_end(geo, hole, from, 1.2, 3.0)
	var wall_len := (wall_end - geo.at(from)).length() / geo.s
	_check(Look.on_ground(hole, geo.point_at(wall_end)) and wall_len < 1.0,
			"an aim line at 1.2 rad stops at the wall of the hole (%.2f course units, not 3.0)" % wall_len)
	# A turn of the phone to the right aims clockwise: down the screen (the course runs to the right).
	_check(geo.dir(0.0).is_equal_approx(Vector2(1.0, 0.0)) and geo.dir(0.5).y > 0.0 and geo.dir(-0.5).y < 0.0,
			"aim 0 points to the cup side, a positive heading (to the right of the player) points down the screen")


## The ball is white with no ring and no flashing halo (owner, 2026-11-03); one ball is as wide as `Geo.ball_d()`.
func _ball() -> void:
	print("the ball")
	var ci := Node2D.new()
	var hole: Dictionary = Holes.hole(1)
	var geo := Look.Geo.new(SCREEN, hole, 1)
	var seen: Array = []
	Shell.recorder = func(kind: String, _ci: CanvasItem, rect: Rect2, info: Dictionary) -> void:
		if kind == "ball":
			seen.append({"rect": rect, "info": info})
	ci.draw.connect(func() -> void: Look.draw_ball(ci, geo, geo.at(hole.tee), 1))
	root.add_child(ci)
	await process_frame
	Shell.recorder = Callable()
	ci.queue_free()
	_check(seen.size() == 1 and seen[0].info.color == Look.WHITE and not seen[0].info.has("ring") and not seen[0].info.has("turn")
			and is_equal_approx(seen[0].rect.size.x, geo.ball_d()),
			"the ball is white, has no ring of a slot color and no halo, and is one ball wide")


## The banner plate keeps away from the cup with its flag, from the balls and from the golfer on every hole (the ball at the
## tee), whatever the text.
func _plate() -> void:
	print("the banner plate")
	for n in range(1, Holes.COUNT + 1):
		var hole: Dictionary = Holes.hole(n)
		var geo := Look.Geo.new(SCREEN, hole, 1)
		var avoid: Array = [Look.cup_zone(geo, hole), Look.golfer_zone(geo, geo.at(hole.tee))]
		var ball := geo.snap(geo.at(hole.tee))
		avoid.append(Rect2(ball - Vector2(36.0, 36.0), Vector2(72.0, 72.0)))
		var covers := []
		for msg in ["MAYA'S TURN!", "HOLE IN ONE!", "SPLASH! TRY AGAIN FROM HERE"]:
			var at := Look.plate_at(geo, msg, 64, avoid, Look.obstacle_zones(geo, hole))
			var rect := Shell.label_plate_rect(at, msg, 64)
			for a in avoid:
				if rect.intersects(a):
					covers.append("%s %s" % [msg, str(a)])
			_check(rect.position.x >= 60.0 and rect.end.x <= 1860.0, "hole %d: the plate '%s' stays inside the 60 unit margin" % [n, msg])
		_check(covers.is_empty(), "hole %d: the plate covers neither the cup nor the ball nor the golfer (%s)" % [n, str(covers)])
	# The cup is covered only when there is no other place.
	var hole2: Dictionary = Holes.hole(2)
	var geo2 := Look.Geo.new(SCREEN, hole2, 1)
	var everywhere: Array = [Rect2(Vector2.ZERO, SCREEN)]
	var at2 := Look.plate_at(geo2, "A", 64, everywhere)
	_check(at2.x > 0.0 and at2.y > 0.0, "when every place is taken the plate still has a place (%s)" % str(at2))


## The scenery stands outside the course and its walls, outside the bar and the chips, and a hole with room has the clubhouse and
## the balloon too (a border round the course, smaller than before).
func _scenery() -> void:
	print("the scenery")
	for n in range(1, Holes.COUNT + 1):
		var hole: Dictionary = Holes.hole(n)
		var geo := Look.Geo.new(SCREEN, hole, 1)
		var items := Look.scenery(geo, hole, n)
		var on_course := 0
		var in_hud := 0
		var kinds := {}
		for it in items:
			kinds[it[0]] = true
			for r in hole.fairway:
				if geo.rect((r as Rect2).grow(Look.WALL_W)).has_point(it[1]):
					on_course += 1
			if it[1].y < 112.0 + 24.0 or (it[1].y > 930.0 and it[1].y < 1030.0):
				in_hud += 1
		_check(items.size() >= 8 and on_course == 0 and in_hud == 0,
				"hole %d: %d things of the park, none on the course (%d) or in the bar or the chips (%d)"
				% [n, items.size(), on_course, in_hud])
		if n == 3 or n == 5:
			_check(kinds.has("clubhouse") and kinds.has("balloon"), "hole %d has room for the clubhouse and the balloon" % n)
