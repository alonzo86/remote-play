extends SceneTree
## More rules of Banana Party and Car Race without a screen (test 10 and 9 of docs/MANUAL_TESTS.md): how long an animal needs to
## cross the screen, when the golden monkey comes, and the pictures of the animals, cars, obstacles and boards are flat pixels.
## Run: godot --headless --path . --script tests/game_rules_b.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const Slow = preload("res://tests/slow_run.gd")
const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")
const RaceLook = preload("res://scripts/game/marble_race/race_look.gd")
const BananaLook = preload("res://scripts/game/snowball_splat/banana_look.gd")
const PuffField = preload("res://scripts/game/snowball_splat/puff_field.gd")

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
	_banana_times_and_pictures()
	_race_pictures()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## Test 10.5c, 10.5d, 10.10b, 10.11a: how long an animal takes to cross the screen, when the golden monkey comes, and the
## pictures of the animals are flat pixels with a black outline.
func _banana_times_and_pictures() -> void:
	print("banana party: times and pictures")
	var rng := _rng(3)
	var cross := func(difficulty: String, lane: int, kind: String) -> float:
		var f := PuffField.new()
		f.setup(difficulty)
		var p: PuffField.Puff = f._add(lane, kind)
		var t := 0.0
		while p.x < PuffField.REF_AREA.x and t < 60.0:
			p.x += p.dir * p.speed / 60.0
			t += 1.0 / 60.0
		return t
	var monkey_m: float = cross.call("medium", 0, "monkey")
	var elephant_m: float = cross.call("medium", 2, "elephant")
	var easy: float = cross.call("easy", 0, "monkey")
	var hard: float = cross.call("hard", 0, "monkey")
	_check(monkey_m >= 10.0 and monkey_m <= 14.0, "Medium: a far lane monkey crosses 1800 px in %.1f s (10 to 14, REQ-SS-8)"
			% monkey_m)
	_check(elephant_m >= 19.0 and elephant_m <= 29.0, "Medium: a near lane elephant crosses in %.1f s (19 to 29)" % elephant_m)
	_check(easy >= 14.0 and easy <= 20.0, "Easy: a far lane monkey crosses in %.1f s (14 to 20, REQ-SS-20)" % easy)
	_check(hard >= 6.5 and hard <= 9.5, "Hard: a far lane monkey crosses in %.1f s (6.5 to 9.5, REQ-SS-20)" % hard)
	# The golden monkey: 200 seeds. The first comes after BONUS_FIRST s, but waits for a free lane (up to 8 s more).
	var firsts: Array[float] = []
	var first_min := INF
	var first_max := 0.0
	var gap_min := INF
	var gap_max := 0.0
	var gaps := 0
	for seed_value in 200:
		var r := _rng(seed_value + 1)
		var f := PuffField.new()
		f.setup("medium")
		var seen_gold := false
		var last_spawn := 0.0
		var spawns := 0
		for i in 1800:   # 60 s at 30 ticks a second
			var t := (i + 1) / 30.0
			f.tick(1.0 / 30.0, r, 2)
			var has := false
			for p in f.puffs:
				has = has or p.kind == PuffField.BONUS_KIND
			if has and not seen_gold:
				spawns += 1
				if spawns == 1:
					firsts.append(t)
					first_min = minf(first_min, t)
					first_max = maxf(first_max, t)
				elif spawns == 2:
					gap_min = minf(gap_min, t - last_spawn)
					gap_max = maxf(gap_max, t - last_spawn)
					gaps += 1
				last_spawn = t
			seen_gold = has
	var within := firsts.filter(func(v: float) -> bool: return v <= 18.0).size()
	_check(firsts.size() == 200 and first_min >= 10.0 - 0.04 and within >= 190,
			"the first golden monkey never comes before 10 s and in %d of 200 rounds by 18 s (latest %.1f s, 2 players)"
			% [within, first_max])
	_check(gaps > 100 and gap_min >= 14.0 - 0.04,
			"the next one comes at least 14 s later (%.1f to %.1f s; it waits for a free lane)" % [gap_min, gap_max])
	# The pictures: only 0 or 1 alpha, and every pixel next to nothing is the black outline.
	var flat := true
	var outlined := true
	var count := 0
	for kind in PuffField.KINDS:
		for happy in [false, true]:
			for facing in [-1, 1]:
				var img: Image = BananaLook.animal_image(kind, happy, facing)
				count += 1
				var w := img.get_width()
				var h := img.get_height()
				for y in h:
					for x in w:
						var px := img.get_pixel(x, y)
						if px.a != 0.0 and px.a != 1.0:
							flat = false
						if px.a == 0.0:
							continue
						var edge := false
						for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							var q: Vector2i = Vector2i(x, y) + d
							if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or img.get_pixel(q.x, q.y).a == 0.0:
								edge = true
						if edge and px != BananaLook.OUTLINE:
							outlined = false
	_check(count == 28 and flat, "all %d animal pictures have only opaque or empty pixels (REQ-GM-47a)" % count)
	_check(outlined, "every pixel of an animal that touches the outside is the black outline (REQ-GM-47m)")


## Test 9.12a, 9.12b, 9.12c, 9.12d, 9.13b, 9.13e: the pictures of Car Race are flat pixels in the colors of their theme.
func _race_pictures() -> void:
	print("race look: pictures")
	var track = MarbleTrack.make(42, "medium")
	var obstacle_names := {"candy": ["lolly", "gumdrop", "cupcake"], "space": ["asteroid", "satellite", "crater"],
			"jungle": ["log", "boulder", "tiki"]}
	var decor_names := {"candy": ["lolly_big", "cane", "icecream", "donut", "cookie", "wrapped"],
			"space": ["rocket", "ringed", "ufo", "planet", "star"], "jungle": ["palm", "palm", "bush", "hibiscus", "mushroom",
					"fern"]}
	var cars := {}
	for key in RaceLook.THEMES:
		var c: Dictionary = RaceLook.THEMES[key]
		_check(c.obstacles == obstacle_names[key], "%s: the obstacles are %s (REQ-MR-46)" % [key, str(obstacle_names[key])])
		_check(c.decor == decor_names[key], "%s: the scenery is %s (REQ-MR-57)" % [key, str(decor_names[key])])
		var t0 := Time.get_ticks_msec()
		var board: Dictionary = RaceLook.render(key, track.points, track.half_width, track.point_at(track.length - 6.0),
				track.dir_at(track.length - 6.0))
		var ms := Time.get_ticks_msec() - t0
		var board_limit := int(Slow.limit(600.0, 4.0))   # The instrumented copy of the coverage run is slower.
		_check(ms < board_limit, "%s: the board of a track is made in %d ms (< %d ms here; about 100 ms measured)"
				% [key, ms, board_limit])
		var palette := {}
		for k in ["road_a", "road_b", "mark", "wall_a", "wall_b", "outline"]:
			palette[(c[k] as Color).to_html()] = true
		for extra in [Color(0, 0, 0, 0), Color("fcfcfc"), RaceLook.OUTLINE, Color("145418")]:
			palette[(extra as Color).to_html()] = true
		var img: Image = board.image
		var stray := 0
		for y in img.get_height():
			for x in img.get_width():
				if not palette.has(img.get_pixel(x, y).to_html()):
					stray += 1
		_check(stray == 0, "%s: every pixel of the board is a color of the theme, none blended (%d stray)" % [key, stray])
		var flat := true
		for kind in c.obstacles:
			var pic: Image = RaceLook.obstacle_image(key, String(kind))
			for y in pic.get_height():
				for x in pic.get_width():
					flat = flat and (pic.get_pixel(x, y).a == 0.0 or pic.get_pixel(x, y).a == 1.0)
		for kind in c.decor:
			var pic: Image = RaceLook.decor_image(key, String(kind))
			for y in pic.get_height():
				for x in pic.get_width():
					flat = flat and (pic.get_pixel(x, y).a == 0.0 or pic.get_pixel(x, y).a == 1.0)
		_check(flat, "%s: obstacles and scenery have only opaque or empty pixels" % key)
		# The finish line is two rows of cells (REQ-MR-44): the black and white band is 2 x FINISH_CELL world pixels high.
		var line: Array[Vector2] = [Vector2(0, 8), Vector2(0, -30)]
		var b2: Dictionary = RaceLook.render(key, line, 3.0, Vector2(0, -20), Vector2(0, -1))
		var rows_with_white := 0
		var cx: int = -b2.origin.x
		for dy in range(-12, 12):
			var yy: int = -20 * RaceLook.PX - b2.origin.y + dy
			var has_white := false
			var has_dark := false
			for dx in range(-8, 8):
				var px: Color = b2.image.get_pixel(cx + dx, yy)
				has_white = has_white or px == Color("fcfcfc")
				has_dark = has_dark or px == RaceLook.OUTLINE
			rows_with_white += 1 if (has_white and has_dark) else 0
		_check(rows_with_white == RaceLook.FINISH_CELL * 2,
				"%s: the finish line band is 2 rows of cells, %d world pixels (found %d)"
				% [key, RaceLook.FINISH_CELL * 2, rows_with_white])
		for slot in 4:
			var car: Image = RaceLook.car_image(Protocol.PLAYER_COLORS[slot])
			if not cars.has(slot):
				cars[slot] = car.get_data()
			_check(car.get_data() == cars[slot], "%s: the car of slot %d is the same picture in every theme (REQ-MR-45)" % [key,
					slot])
	var ring_ok := true
	var body_ok := true
	var bodies := {}
	for slot in 4:
		var car: Image = RaceLook.car_image(Protocol.PLAYER_COLORS[slot])
		bodies[car.get_pixel(3, 7).to_html()] = true
		body_ok = body_ok and car.get_pixel(3, 7) == Protocol.PLAYER_COLORS[slot]
		for y in car.get_height():
			for x in car.get_width():
				var px := car.get_pixel(x, y)
				ring_ok = ring_ok and (px.a == 0.0 or px.a == 1.0)
				if px.a == 1.0:
					var edge := x == 0 or y == 0 or x == car.get_width() - 1 or y == car.get_height() - 1
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var q: Vector2i = Vector2i(x, y) + d
						if q.x >= 0 and q.y >= 0 and q.x < car.get_width() and q.y < car.get_height() and car.get_pixel(q.x,
								q.y).a == 0.0:
							edge = true
					if edge and px != RaceLook.OUTLINE and px != RaceLook.CAR_TIRE:
						ring_ok = false
	_check(ring_ok, "a car has only opaque or empty pixels and its outer ring is the black outline or a tire (REQ-MR-48)")
	_check(body_ok and bodies.size() == 4, "the 4 cars have 4 different body colors, the 4 player colors")
