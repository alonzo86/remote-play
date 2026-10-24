extends SceneTree
## The rules of the rink of Bumper Cars without a screen: the size of the rink, the stars on the floor, who is hit in a bump,
## how a dropped star rolls and who picks up a star, and the pictures (docs/games/bumper_cars.md, REQ-BC-3 to 10, 16, 20).
## Run: godot --headless --path . --script tests/bumper_rules.gd -- --role=controller

const Rink = preload("res://scripts/game/bumper_cars/bumper_rink.gd")
const Look = preload("res://scripts/game/bumper_cars/bumper_look.gd")
const Shell = preload("res://scripts/game/shell.gd")

const DT := 1.0 / 60.0

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
	_levels()
	_start_spots()
	_floor_stars()
	_bump_rule()
	_dropped_stars()
	_pickups()
	_pictures()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _rng(seed_value := 5) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## REQ-BC-20: the rink and the stars of the three difficulties.
func _levels() -> void:
	print("levels")
	var easy := Rink.new()
	easy.setup("easy")
	var medium := Rink.new()
	medium.setup("medium")
	var hard := Rink.new()
	hard.setup("hard")
	_check(easy.star_count == 12 and medium.star_count == 9 and hard.star_count == 6, "12, 9 and 6 stars on the floor (REQ-BC-20)")
	_check(easy.rink.size == Rink.LARGEST.size and easy.rink.size.x > medium.rink.size.x and medium.rink.size.x > hard.rink.size.x
			and easy.rink.size.y > medium.rink.size.y and medium.rink.size.y > hard.rink.size.y,
			"the rink gets smaller from Easy to Hard (REQ-BC-20)")
	var grid := true
	var middle := true
	for r in [easy, medium, hard]:
		grid = grid and fmod(r.rink.position.x, 4.0) == 0.0 and fmod(r.rink.position.y, 4.0) == 0.0 \
				and fmod(r.rink.size.x, 4.0) == 0.0 and fmod(r.rink.size.y, 4.0) == 0.0
		middle = middle and r.rink.get_center().distance_to(Rink.LARGEST.get_center()) <= 4.0
	_check(grid and middle, "every rink is on the grid of world pixels and in the middle of the largest one")
	var unknown := Rink.new()
	unknown.setup("nonsense")
	_check(unknown.star_count == 9 and unknown.rink == medium.rink, "an unknown difficulty gives Medium")
	_check(Rink.LARGEST.position.x >= 60.0 and Rink.LARGEST.end.x <= 1860.0 and Rink.LARGEST.end.y <= 1020.0
			and Rink.LARGEST.position.y - Look.RAIL_W >= Look.TENT_TOP + Look.TENT_BODY + Look.TENT_SCALLOP,
			"the largest rink with its rail is inside the 60 px margin and under the tent (REQ-BC-16)")


## REQ-BC-3: the cars start on a circle, the first at the top, all at the same distance from the middle.
func _start_spots() -> void:
	print("start places")
	var r := Rink.new()
	r.setup("medium")
	for n in [2, 3, 4]:
		var spots := r.start_spots(n)
		var c := r.rink.get_center()
		var same := true
		var inside := true
		for p in spots:
			same = same and absf(p.distance_to(c) - spots[0].distance_to(c)) < 0.01
			inside = inside and r.rink.grow(-Rink.CAR_R).has_point(p)
		var apart := true
		for i in n:
			for j in range(i + 1, n):
				apart = apart and spots[i].distance_to(spots[j]) > Rink.CAR_R * 2.0
		_check(spots.size() == n and same and inside and apart,
				"%d cars: the same distance from the middle, inside the rink, not touching" % n)
	var top := r.start_spots(4)[0]
	_check(is_equal_approx(top.x, r.rink.get_center().x) and top.y < r.rink.get_center().y, "the first car is at the top")


## REQ-BC-9: the full number of stars at the start, a new one every 0.6 s, away from the cars and the rail.
func _floor_stars() -> void:
	print("stars on the floor")
	var r := Rink.new()
	r.setup("medium")
	var rng := _rng()
	var cars: Array = [Vector2(600.0, 600.0), Vector2(1300.0, 700.0)]
	r.fill(cars, rng)
	_check(r.stars.size() == 9, "a round starts with all 9 stars")
	var clear := true
	for s in r.stars:
		clear = clear and r.rink.grow(-Rink.SPAWN_CLEAR + 0.5).has_point(s.pos)
		for c in cars:
			clear = clear and (c as Vector2).distance_to(s.pos) >= Rink.SPAWN_CLEAR
	_check(clear, "every star is 120 px from the rail and from every car")
	r.tick(5.0, cars, rng)
	_check(r.stars.size() == 9, "a full floor gets no new star")
	r.stars.remove_at(0)
	r.stars.remove_at(0)
	r.tick(0.5, cars, rng)
	_check(r.stars.size() == 7, "after 0.5 s there is no new star yet")
	r.tick(0.2, cars, rng)
	_check(r.stars.size() == 8 and float(r.stars[7].blink) > 0.0, "after 0.7 s there is one new star, and it blinks")
	r.tick(0.6, cars, rng)
	_check(r.stars.size() == 9, "and one more 0.6 s later: the floor is full again")
	var long := Rink.new()
	long.setup("hard")
	long.fill(cars, _rng(9))
	for i in 600:
		long.tick(DT, cars, _rng(i))
	_check(long.stars.size() == 6, "10 s later the floor still has exactly 6 stars (Hard)")


## REQ-BC-6: a hit needs 250 px/s of the two cars towards each other.
func _bump_rule() -> void:
	print("a hit")
	var o := Vector2.ZERO
	var right := Vector2(90.0, 0.0)   # b is to the right of a.
	_check(not Rink.is_hit(o, Vector2(100.0, 0.0), right, Vector2(-100.0, 0.0)),
			"two cars at 100 px/s each towards the other (200 together) make no hit (REQ-BC-6)")
	_check(Rink.is_hit(o, Vector2(125.0, 0.0), right, Vector2(-125.0, 0.0)), "125 px/s each (250 together) is a hit (REQ-BC-6)")
	_check(Rink.is_hit(o, Vector2(400.0, 0.0), right, Vector2.ZERO), "a car that rams one that stands still: a hit")
	_check(Rink.is_hit(o, Vector2.ZERO, right, Vector2(-400.0, 0.0)), "a car that stands is rammed from the other side: a hit")
	_check(not Rink.is_hit(o, Vector2(300.0, 0.0), right, Vector2(100.0, 0.0)),
			"a car that catches another one from behind at 200 px/s more makes no hit (under 250)")
	_check(Rink.is_hit(o, Vector2(600.0, 0.0), right, Vector2(100.0, 0.0)),
			"a car that catches another one from behind at 500 px/s more: a hit")
	_check(not Rink.is_hit(o, Vector2(0.0, 500.0), right, Vector2.ZERO),
			"a car that moves along the line between them, not towards the other, makes no hit")
	_check(Rink.is_hit(Vector2(10.0, 10.0), Vector2(300.0, 0.0), Vector2(10.0, 10.0), Vector2(-300.0, 0.0)),
			"two cars in the same place do not crash the rule")
	_check(Rink.touching(Vector2.ZERO, Vector2(95.0, 0.0)) and not Rink.touching(Vector2.ZERO, Vector2(96.0, 0.0)),
			"cars touch when their middles are closer than two radii")


## REQ-BC-8: a dropped star rolls 110 px in 0.35 s, away from the other car, stops at the rail and waits 0.5 s.
func _dropped_stars() -> void:
	print("dropped stars")
	var r := Rink.new()
	r.setup("medium")
	var c := r.rink.get_center()
	r.drop_star(c, c + Vector2(-80.0, 0.0))
	_check(r.stars.size() == 1 and r.stars[0].pos == c, "the star starts at the car")
	r.tick(0.2, [], _rng())
	var at: Vector2 = r.stars[0].pos
	_check(is_equal_approx(at.x, c.x + 110.0 * 0.2 / 0.35) and is_equal_approx(at.y, c.y),
			"it rolls away from the other car (to the right here)")
	r.tick(1.0, [], _rng())
	_check(is_equal_approx((r.stars[0].pos as Vector2).distance_to(c), Rink.DROP_DISTANCE), "it stops after 110 px")
	_check(r.pickups([r.stars[0].pos]).is_empty() == false, "after 1.2 s a car on the star picks it up")
	var fresh := Rink.new()
	fresh.setup("medium")
	fresh.drop_star(c, c + Vector2(0.0, 50.0))
	_check(fresh.pickups([c]).is_empty(), "a star that was just dropped cannot be picked up (REQ-BC-8)")
	fresh.tick(0.45, [], _rng())
	_check(fresh.pickups([fresh.stars[0].pos]).is_empty(), "not after 0.45 s either")
	fresh.tick(0.1, [], _rng())
	_check(fresh.pickups([fresh.stars[0].pos]).size() == 1, "after 0.55 s it can")
	var wall := Rink.new()
	wall.setup("medium")
	var edge := Vector2(wall.rink.end.x - 40.0, c.y)
	wall.drop_star(edge, edge + Vector2(-60.0, 0.0))
	wall.tick(1.0, [], _rng())
	_check(wall.rink.has_point(wall.stars[0].pos) and (wall.stars[0].pos as Vector2).x <= wall.rink.end.x - Rink.STAR_R + 0.01,
			"a star that rolls into the rail stops inside the rink")
	var same := Rink.new()
	same.setup("medium")
	same.drop_star(c, c)
	_check(same.stars.size() == 1 and (same.stars[0].vel as Vector2).length() > 0.0,
			"a star dropped from the same place as the other car still rolls")


## REQ-BC-10: a car picks up a star within 70 px; the nearer car gets it; one car can take several.
func _pickups() -> void:
	print("pick-ups")
	var r := Rink.new()
	r.setup("medium")
	r.stars.append({"pos": Vector2(500.0, 500.0), "vel": Vector2.ZERO, "move": 0.0, "lock": 0.0, "blink": 0.0})
	_check(r.pickups([Vector2(500.0 + 75.0, 500.0)]).size() == 1, "a car 75 px from a star picks it up")
	_check(r.pickups([Vector2(500.0 + 77.0, 500.0)]).is_empty(), "a car 77 px away does not")
	var two := r.pickups([Vector2(500.0 + 60.0, 500.0), Vector2(500.0 - 20.0, 500.0)])
	_check(two.size() == 1 and two[0][0] == 1, "two cars reach the star: the nearer one (index 1) gets it")
	r.stars.append({"pos": Vector2(520.0, 520.0), "vel": Vector2.ZERO, "move": 0.0, "lock": 0.0, "blink": 0.0})
	r.stars.append({"pos": Vector2(1500.0, 700.0), "vel": Vector2.ZERO, "move": 0.0, "lock": 0.0, "blink": 0.0})
	var both := r.pickups([Vector2(510.0, 510.0)])
	_check(both.size() == 2, "one car takes the two stars that it reaches, not the far one")
	r.remove_stars([0, 1])
	_check(r.stars.size() == 1 and (r.stars[0].pos as Vector2).x == 1500.0, "removing the picked stars keeps the other one")


## REQ-BC-16: the pictures.
func _pictures() -> void:
	print("pictures")
	var star := Look.star_image()
	_check(star.get_size() == Vector2i(11, 10) and star.get_pixel(5, 3) == Look.STAR_GOLD,
			"a star is 9x8 pixels plus the outline, in gold")
	var colors: Array[Color] = [Color("ff4638"), Color("4a9eff"), Color("48dc6a"), Color("ffc828")]
	var whole := true
	var outlined := true
	for c in colors:
		for d in 4:
			var img := Look.car_image(c, d)
			var want := Vector2i(28, 20) if d < 2 else Vector2i(20, 28)
			whole = whole and img.get_size() == want
			outlined = outlined and img.get_pixel(want.x / 2, 0) == Look.OUTLINE
	_check(whole, "a car is 28x20 pixels, and 20x28 when it faces up or down")
	_check(outlined, "a car has a black outline")
	var body_ok := true
	for c in colors:
		var img := Look.car_image(c, Look.DIR_RIGHT)
		var found := false
		for y in img.get_height():
			for x in img.get_width():
				found = found or img.get_pixel(x, y) == c
		body_ok = body_ok and found
	_check(body_ok, "the body of each car is in the slot color")
	var contrast := true
	for c in colors:
		contrast = contrast and Shell.contrast(c, Look.OUTLINE) >= 3.0
	_check(contrast and Shell.contrast(Look.FLOOR_A, Look.OUTLINE) >= 3.0 and Shell.contrast(Look.FLOOR_B, Look.OUTLINE) >= 3.0,
			"every slot color and the floor differ from the outline by 3:1 or more (REQ-GM-47m)")
	var left := Look.car_image(colors[0], Look.DIR_LEFT)
	var right := Look.car_image(colors[0], Look.DIR_RIGHT)
	_check(left.get_pixel(0, 10) == right.get_pixel(27, 10) and left.get_pixel(25, 10) != right.get_pixel(25, 10),
			"the car that faces left is the mirror of the one that faces right")
	var shadow := Look.shadow_image(right)
	var solid := true
	for y in right.get_height():
		for x in right.get_width():
			solid = solid and ((right.get_pixel(x, y).a > 0.0) == (shadow.get_pixel(x, y).a > 0.0))
	_check(solid and shadow.get_pixel(14, 10) == Look.SHADOW, "the shadow is the shape of the car in one dark color (REQ-BC-16)")
	_check(Look.facing(Vector2(100.0, 20.0), Look.DIR_UP) == Look.DIR_RIGHT
			and Look.facing(Vector2(-100.0, 20.0), Look.DIR_UP) == Look.DIR_LEFT
			and Look.facing(Vector2(10.0, 100.0), Look.DIR_UP) == Look.DIR_DOWN
			and Look.facing(Vector2(10.0, -100.0), Look.DIR_RIGHT) == Look.DIR_UP,
			"a car faces the way it drives")
	_check(Look.facing(Vector2(10.0, 10.0), Look.DIR_DOWN) == Look.DIR_DOWN, "a car that stands keeps the way it faced")
