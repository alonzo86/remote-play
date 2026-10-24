extends SceneTree
## The rules of Sheep Herding, without a screen: the fence and the blockers, how a sheep runs from a
## dog, grazes and stays with its
## friends, the pen, the things around the field, the pictures and the difficulty (REQ-SH-2 to 4, 7, 8, 10, 15 to 18).
## Run: godot --headless --path . --script tests/sheep_rules.gd -- --role=controller

const Medals = preload("res://scripts/game/medals.gd")
const SheepFlock = preload("res://scripts/game/sheep_herding/sheep_flock.gd")
const SheepScenery = preload("res://scripts/game/sheep_herding/sheep_scenery.gd")
const SheepLook = preload("res://scripts/game/sheep_herding/sheep_look.gd")

const DT := 1.0 / 60.0
const FIELD := Rect2(60, 152, 1800, 868)
const PEN := Rect2(1488, 452, 320, 360)

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
	_rect_push()
	_fence_and_blockers()
	_spawn()
	_running_away()
	_grazing_and_flock()
	_the_pen()
	_scenery()
	_pictures()
	_levels()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## A flock on the field of the game, with the pen and no blockers, unless `blockers` is given.
func _flock(params := {"gate": 180.0, "flee": 260.0, "speed": 270.0}, blockers: Array[Dictionary] = []) -> SheepFlock:
	var f := SheepFlock.new()
	f.setup(FIELD, PEN, params, blockers, [])
	return f


func _sheep_at(f: SheepFlock, p: Vector2) -> SheepFlock.Sheep:
	var s := SheepFlock.Sheep.new()
	s.pos = p
	f.sheep.append(s)
	return s


## The vector that moves a circle out of a rectangle (REQ-SH-4).
func _rect_push() -> void:
	print("push out of a rectangle")
	var r := Rect2(100, 100, 200, 50)
	_check(SheepFlock.push_out_of_rect(Vector2(200, 60), 28.0, r) == Vector2.ZERO, "a circle that does not touch is not pushed")
	var up := SheepFlock.push_out_of_rect(Vector2(200, 90), 28.0, r)
	_check(is_equal_approx(up.y, -18.0) and up.x == 0.0, "a circle above the rectangle is pushed up by the overlap: %s" % str(up))
	var side := SheepFlock.push_out_of_rect(Vector2(320, 125), 28.0, r)
	_check(is_equal_approx(side.x, 8.0) and side.y == 0.0, "a circle at the right is pushed to the right: %s" % str(side))
	var inside_left := SheepFlock.push_out_of_rect(Vector2(110, 125), 28.0, r)
	_check(inside_left.x < 0.0 and is_equal_approx(inside_left.x, -(10.0 + 28.0)),
			"a middle inside the rectangle leaves by the nearest side")
	var inside_down := SheepFlock.push_out_of_rect(Vector2(200, 145), 28.0, r)
	_check(inside_down.y > 0.0 and is_equal_approx(inside_down.y, 5.0 + 28.0), "a middle near the bottom leaves downward")
	var inside_up := SheepFlock.push_out_of_rect(Vector2(200, 105), 28.0, r)
	_check(inside_up.y < 0.0, "a middle near the top leaves upward")
	var inside_right := SheepFlock.push_out_of_rect(Vector2(295, 125), 28.0, r)
	_check(inside_right.x > 0.0, "a middle near the right edge leaves to the right")
	var corner := SheepFlock.push_out_of_rect(Vector2(95, 95), 28.0, r)
	_check(corner.x < 0.0 and corner.y < 0.0 and is_equal_approx(corner.length(), 28.0 - Vector2(5, 5).length()),
			"at a corner the push is along the line from the corner")


## The fence has a gate, a sheep cannot walk through a blocker, the fence or the edge, and keeps part of its speed (REQ-SH-4).
func _fence_and_blockers() -> void:
	print("the fence and the blockers")
	var f := _flock()
	_check(f.walls.size() == 5, "the fence is 5 pieces: top, bottom, right and the left side in two (the gate between)")
	var gate := f.gate_center()
	_check(gate == Vector2(1488, 632), "the gate is in the middle of the left side: %s" % str(gate))
	var through := f.resolve(gate + Vector2(10, 0), Vector2.ZERO, SheepFlock.RADIUS)
	_check(through[0] == gate + Vector2(10, 0), "a sheep fits through the gate of 180 px")
	var narrow := _flock({"gate": 40.0, "flee": 260.0, "speed": 270.0})
	var stuck: Array = narrow.resolve(gate + Vector2(14, 0), Vector2.ZERO, SheepFlock.RADIUS)
	_check(stuck[0] != gate + Vector2(14, 0), "a gate narrower than a sheep (40 px) holds the sheep back")
	var wall_hit := f.resolve(Vector2(1500, 470), Vector2(0, -300), SheepFlock.RADIUS)
	_check(wall_hit[0].y >= PEN.position.y + SheepFlock.WALL - 1.0 or wall_hit[0].y <= PEN.position.y - SheepFlock.RADIUS + 1.0,
			"a sheep on the fence is pushed out of it: %s" % str(wall_hit[0]))
	var blockers: Array[Dictionary] = [{"pos": Vector2(500, 500), "r": 40.0}]
	var g := _flock({"gate": 180.0, "flee": 260.0, "speed": 270.0}, blockers)
	var hit := g.resolve(Vector2(520, 500), Vector2(-200, 0), SheepFlock.RADIUS)
	_check(hit[0].distance_to(Vector2(500, 500)) >= 40.0 + SheepFlock.RADIUS - 0.01 and hit[1].x > -200.0,
			"a sheep in a blocker is pushed out, and the speed into it is turned back a little: %s" % str(hit))
	var tight := g.resolve(Vector2(500, 500), Vector2.ZERO, SheepFlock.RADIUS)
	_check(tight[0].distance_to(Vector2(500, 500)) >= 40.0 + SheepFlock.RADIUS - 0.01,
			"a sheep exactly in the middle of a blocker leaves it")
	var edge := g.resolve(Vector2(10, 10), Vector2(-100, -100), 30.0)
	_check(edge[0] == FIELD.position + Vector2(30, 30), "the edge of the field keeps a circle inside: %s" % str(edge[0]))
	var free := g.resolve(Vector2(800, 400), Vector2(50, 20), 30.0)
	_check(free[0] == Vector2(800, 400) and free[1] == Vector2(50, 20), "a circle in free space is not changed")
	var away := g.resolve(Vector2(520, 500), Vector2(200, 0), SheepFlock.RADIUS)
	_check(away[1] == Vector2(200, 0), "a speed that goes away from the blocker is kept")


## The flock starts apart from each other and from the blockers, the same for the same seed (REQ-SH-2).
func _spawn() -> void:
	print("the start of the flock")
	var blockers: Array[Dictionary] = [{"pos": Vector2(700, 600), "r": 80.0}]
	var f := _flock({"gate": 180.0, "flee": 260.0, "speed": 270.0}, blockers)
	var area := Rect2(440, 312, 560, 548)
	f.spawn(11, area, _rng(4))
	_check(f.sheep.size() == 11, "11 sheep were placed")
	var apart := true
	var inside := true
	for i in f.sheep.size():
		inside = inside and area.has_point(f.sheep[i].pos) and f.sheep[i].pos.distance_to(Vector2(700, 600)) >= 80.0 + SheepFlock.RADIUS
		for j in range(i + 1, f.sheep.size()):
			apart = apart and f.sheep[i].pos.distance_to(f.sheep[j].pos) >= 2.0 * SheepFlock.RADIUS
	_check(apart and inside, "the sheep do not overlap and stand outside the blocker")
	var h := _flock({"gate": 180.0, "flee": 260.0, "speed": 270.0}, blockers)
	h.spawn(11, area, _rng(4))
	var same := true
	for i in f.sheep.size():
		same = same and f.sheep[i].pos == h.sheep[i].pos
	_check(same, "the same seed gives the same flock (REQ-SH-3)")
	var crowded := _flock()
	crowded.spawn(40, Rect2(440, 312, 200, 200), _rng(1))
	_check(crowded.sheep.size() < 40, "a crowded start places fewer sheep and does not hang: %d" % crowded.sheep.size())
	_check(not _flock().all_penned(), "a field without sheep is not full")


## A sheep runs from a dog (REQ-SH-7).
func _running_away() -> void:
	print("running away")
	var f := _flock()
	var s := _sheep_at(f, Vector2(600, 500))
	var far := {0: Vector2(100, 500)}   # 500 px away: out of range (260)
	var rng := _rng(2)
	for i in 120:
		f.tick(DT, far, rng)
	_check(s.scared == 0.0 and s.vel.length() <= SheepFlock.GRAZE_SPEED + 0.01, "a sheep far from a dog does not run")
	var near := {1: Vector2(500, 500)}   # 100 px to its left
	var start := s.pos
	var startled := 0
	var speed_max := 0.0
	for i in 60:
		f.tick(DT, near, rng)
		for e in f.events:
			if e.t == "startled":
				startled += 1
				_check(int(e.slot) == 1, "the event names the dog that scared the sheep")
		speed_max = maxf(speed_max, s.vel.length())
	_check(s.pos.x > start.x + 30.0 and s.last_dog == 1, "a sheep runs away from a dog that is close: %s" % str(s.pos - start))
	_check(startled == 1, "one fright is one event, not one for every frame (%d)" % startled)
	_check(speed_max <= 270.0 + 0.01 and speed_max > SheepFlock.GRAZE_SPEED,
			"a scared sheep runs, not faster than the run speed: %.0f" % speed_max)
	var close_f := _flock()
	var close_s := _sheep_at(close_f, Vector2(600, 500))
	var far_f := _flock()
	var far_s := _sheep_at(far_f, Vector2(600, 500))
	close_f.tick(DT, {0: Vector2(560, 500)}, _rng(3))
	far_f.tick(DT, {0: Vector2(420, 500)}, _rng(3))
	_check(close_s.vel.x > far_s.vel.x, "a closer dog scares harder than a dog at the edge of the range")
	var two := _flock()
	var squeezed := _sheep_at(two, Vector2(600, 500))
	two.tick(DT, {0: Vector2(500, 450), 1: Vector2(500, 550)}, _rng(3))
	_check(squeezed.vel.x > 0.0 and absf(squeezed.vel.y) < absf(squeezed.vel.x) * 0.5,
			"two dogs add up: a sheep between a dog above and a dog below runs sideways")
	var hard_f := _flock({"gate": 150.0, "flee": 300.0, "speed": 320.0})
	var hard_s := _sheep_at(hard_f, Vector2(700, 500))
	for i in 80:
		hard_f.tick(DT, {0: hard_s.pos - Vector2(80, 0)}, _rng(5))
	_check(hard_s.vel.length() > 270.0 and hard_s.vel.length() <= 320.01,
			"on Hard a sheep runs faster than on Medium: %.0f" % hard_s.vel.length())
	var cornered := _flock()
	var c := _sheep_at(cornered, FIELD.position + Vector2(40, 40))
	for i in 120:
		cornered.tick(DT, {0: c.pos + Vector2(70, 70)}, _rng(6))
	_check(FIELD.grow(-SheepFlock.RADIUS + 0.5).has_point(c.pos), "a sheep that is cornered stays on the field")
	var calm := _flock()
	var d := _sheep_at(calm, Vector2(600, 500))
	calm.tick(DT, {0: Vector2(600 - 150, 500)}, _rng(1))
	var after_calm := d.scared
	for i in 90:
		calm.tick(DT, {}, _rng(1))   # The dog went away.
	_check(after_calm > 0.0 and d.scared == 0.0, "the fright ends a moment after the dog is gone (%.2f s)" % SheepFlock.SCARED_TIME)


## A sheep that nobody scares grazes slowly, the flock stays together, and sheep do not overlap (REQ-SH-8).
func _grazing_and_flock() -> void:
	print("grazing and the flock")
	var f := _flock()
	var s := _sheep_at(f, Vector2(600, 500))
	var rng := _rng(8)
	var peak := 0.0
	var moved := false
	for i in 600:
		f.tick(DT, {}, rng)
		peak = maxf(peak, s.vel.length())
		moved = moved or s.pos.distance_to(Vector2(600, 500)) > 10.0
	_check(peak <= SheepFlock.GRAZE_SPEED + 0.01 and moved, "a grazing sheep walks, never faster than 45 px/s: %.1f" % peak)
	var pair := _flock()
	var a := _sheep_at(pair, Vector2(700, 500))
	var b := _sheep_at(pair, Vector2(1000, 500))
	for i in 360:
		pair.tick(DT, {}, _rng(9))
	_check(a.pos.distance_to(b.pos) < 300.0 - 0.01 + 0.5 and a.pos.distance_to(b.pos) >= 2.0 * SheepFlock.RADIUS * 0.9 - 0.5,
			"two sheep 300 px apart come together and do not overlap: %.0f px" % a.pos.distance_to(b.pos))
	var lonely := _flock()
	var l1 := _sheep_at(lonely, Vector2(500, 400))
	var l2 := _sheep_at(lonely, Vector2(1300, 400))
	lonely.tick(DT, {}, _rng(9))
	_check(lonely._cohesion(l1) == Vector2.ZERO and lonely._cohesion(l2) == Vector2.ZERO,
			"sheep that are more than 340 px apart do not pull each other")
	var crowd := _flock()
	for i in 6:
		_sheep_at(crowd, Vector2(800, 500) + Vector2(float(i % 3), float(i / 3)) * 4.0)
	for i in 60:
		crowd.tick(DT, {}, _rng(10))
	var min_gap := 1000.0
	for i in 6:
		for j in range(i + 1, 6):
			min_gap = minf(min_gap, crowd.sheep[i].pos.distance_to(crowd.sheep[j].pos))
	_check(min_gap >= 2.0 * SheepFlock.RADIUS * 0.9 - 1.0,
			"six sheep that start on top of each other are pushed apart: %.0f px" % min_gap)
	var many := _flock()
	var rng2 := _rng(11)
	many.spawn(11, Rect2(440, 312, 560, 548), rng2)
	var dogs := {0: Vector2(300, 400), 1: Vector2(300, 700)}
	for i in 600:
		many.tick(DT, dogs, rng2)
	var ok := true
	for q in many.sheep:
		ok = ok and FIELD.grow(1.0).has_point(q.pos)
	_check(ok, "after 10 s with two dogs every sheep is still on the field")


## A sheep that goes through the gate is in the pen for good (REQ-SH-10).
func _the_pen() -> void:
	print("the pen")
	var f := _flock()
	var s := _sheep_at(f, f.gate_center() + Vector2(-60, 0))
	s.last_dog = 2
	s.scared = 0.5
	var penned_event := {}
	for i in 90:
		s.vel = Vector2(200, 0)
		f.tick(DT, {}, _rng(1))
		for e in f.events:
			if e.t == "penned":
				penned_event = e
		if s.penned:
			break
	_check(s.penned and f.penned_count() == 1 and f.all_penned(), "a sheep that runs through the gate is in the pen")
	_check(not penned_event.is_empty() and int(penned_event.slot) == 2 and penned_event.i == 0,
			"the event names the dog that scared it last (REQ-SH-12): %s" % str(penned_event))
	_check(s.hop > 0.0 and s.scared == 0.0, "it hops once and is not scared any more")
	var inner := f.interior()
	for i in 600:
		f.tick(DT, {0: s.pos + Vector2(-90, 0), 1: s.pos + Vector2(0, 90)}, _rng(3))   # Dogs next to it do not scare it.
	_check(s.penned and s.scared == 0.0 and inner.grow(1.0).has_point(s.pos) and s.vel.length() <= SheepFlock.GRAZE_SPEED + 0.01,
			"a sheep in the pen stays inside, does not run, and dogs do not scare it")
	var wall := _flock()
	var out_of_gate := _sheep_at(wall, Vector2(1490, 480))
	out_of_gate.vel = Vector2(150, 0)
	wall.tick(DT, {}, _rng(1))
	_check(not out_of_gate.penned, "a sheep at the fence outside the gate (above the opening) is not in the pen")
	var dropped := _flock()
	var inside := _sheep_at(dropped, Vector2(1600, 640))
	dropped.tick(DT, {}, _rng(1))
	_check(inside.penned, "a sheep whose middle is inside the pen is counted")
	var full := _flock()
	var rng := _rng(12)
	for i in 14:
		var q := _sheep_at(full, full.gate_center() + Vector2(40, -150 + 22.0 * float(i)))
		q.vel = Vector2(80, 0)
	for i in 600:
		full.tick(DT, {}, rng)
	var all_inside := true
	for q in full.sheep:
		all_inside = all_inside and q.penned and full.interior().grow(1.0).has_point(q.pos)
	_check(all_inside and full.all_penned() and full.penned_count() == 14, "the pen holds all 14 sheep of Hard")


## The things around the field (REQ-SH-3, 16).
func _scenery() -> void:
	print("the scenery")
	var free: Array[Rect2] = [Rect2(60, 152, 280, 868), Rect2(440, 312, 560, 548), Rect2(440, 482, 1048, 300), PEN.grow(120)]
	var clear: Array[Rect2] = [PEN.grow(40), Rect2(1424, 220, 304, 248)]
	var a := SheepScenery.new()
	a.generate(FIELD, free, clear, _rng(5))
	var counts := {}
	for it in a.items:
		counts[it.kind] = int(counts.get(it.kind, 0)) + 1
	_check(int(counts.get("pond", 0)) == 1 and int(counts.get("tree", 0)) >= 5 and int(counts.get("pine", 0)) >= 3
			and int(counts.get("hay", 0)) >= 2 and int(counts.get("bales", 0)) >= 1 and int(counts.get("rock", 0)) >= 2
			and int(counts.get("bush", 0)) >= 4, "there is a pond, trees, pines, hay stacks, bales, rocks and bushes: %s" % str(counts))
	var blocker_ok := true
	for b in a.blockers:
		for r in free:
			if r.grow(float(b.r)).has_point(b.pos):
				blocker_ok = false
	_check(blocker_ok, "no blocker stands in the start strip, the start of the sheep, the way to the gate or near the pen")
	var clear_ok := true
	for it in a.items:
		for r in clear:
			clear_ok = clear_ok and not r.has_point(it.pos)
		clear_ok = clear_ok and FIELD.has_point(it.pos)
	for fl in a.flowers:
		for r in clear:
			clear_ok = clear_ok and not r.has_point(fl.pos)
	_check(clear_ok, "nothing is drawn in the pen or on the barn, and everything stands on the field")
	var spread := false
	for it in a.items:
		if it.pos.x > 700.0 and it.pos.x < 1300.0 and it.kind != "pond":
			spread = true
	_check(spread, "the things are scattered, also in the middle of the field and not only at the edges (REQ-SH-16)")
	_check(a.flowers.size() >= 20, "there are flowers: %d" % a.flowers.size())
	var b := SheepScenery.new()
	b.generate(FIELD, free, clear, _rng(5))
	var same := a.items.size() == b.items.size()
	for i in mini(a.items.size(), b.items.size()):
		same = same and a.items[i].pos == b.items[i].pos and a.items[i].kind == b.items[i].kind
	_check(same, "the same seed gives the same field (Restart keeps it)")
	var c := SheepScenery.new()
	c.generate(FIELD, free, clear, _rng(6))
	var differs := false
	for i in mini(a.items.size(), c.items.size()):
		differs = differs or a.items[i].pos != c.items[i].pos
	_check(differs, "another seed gives another field")
	var pond_blockers := 0
	for blk in a.blockers:
		if is_equal_approx(float(blk.r), 58.0):
			pond_blockers += 1
	_check(pond_blockers == 3, "the pond blocks with three circles along its length")
	var wanted := 0
	for kind in SheepScenery.KINDS:
		wanted += int(SheepScenery.KINDS[kind].count)
	var short := []
	for seed_n in range(1, 61):   # The game picks a new seed for every round.
		var field_n := SheepScenery.new()
		field_n.generate(FIELD, free, clear, _rng(seed_n))
		if field_n.items.size() != wanted:
			short.append("%d:%d" % [seed_n, field_n.items.size()])
	_check(short.is_empty(), "every thing finds room on the field for 60 seeds (%d wanted); short seeds: %s" % [wanted, str(short)])
	var tiny := SheepScenery.new()
	tiny.generate(Rect2(0, 0, 200, 200), [], [], _rng(1))
	_check(tiny.items.size() < 26, "things that find no room are left out and nothing hangs: %d" % tiny.items.size())
	var open := SheepScenery.new()
	open.generate(FIELD, [], [], _rng(2))
	_check(open.blockers.size() >= a.blockers.size() - 6, "without keep-free places the same things are placed")


## The pictures (REQ-SH-15).
func _pictures() -> void:
	print("the pictures")
	var dog := SheepLook.image("dog", Color("e63946"))
	_check(dog.get_width() == 20 and dog.get_height() == 14, "a dog is 20 x 14 world pixels (80 x 56 px)")
	var body_px := 0
	var cream := 0
	for y in dog.get_height():
		for x in dog.get_width():
			var c := dog.get_pixel(x, y)
			body_px += 1 if c.is_equal_approx(Color("e63946")) else 0
			cream += 1 if c.is_equal_approx(Color("fcf0dc")) else 0
	_check(body_px > 60 and cream > 10,
			"the body of the dog has the color of the player, with a cream muzzle and belly (%d, %d)" % [body_px, cream])
	var other := SheepLook.image("dog", Color("457b9d"))
	_check(other.get_pixel(8, 7) != dog.get_pixel(8, 7) and other.get_pixel(8, 7).is_equal_approx(Color("457b9d")),
			"another player gets a dog in another color")
	var sheep := SheepLook.image("sheep")
	_check(sheep.get_width() == 18 and sheep.get_height() == 14, "a sheep is 18 x 14 world pixels (72 x 56 px)")
	var tall := true
	for kind in ["dog", "sheep", "heart", "snooze", "star", "bush", "tree", "pine", "hay", "bales", "rock"]:
		var img := SheepLook.image(kind, Color.WHITE)
		var seen := false
		for y in img.get_height():
			for x in img.get_width():
				seen = seen or img.get_pixel(x, y).a > 0.0
		tall = tall and seen and img.get_width() > 2
	_check(tall, "every picture has pixels")
	_check(SheepLook.image("nothing").get_width() == 1, "an unknown picture is one empty pixel")
	var tree := SheepLook.image("tree")
	_check(tree.get_pixel(0, 0).a == 0.0 and tree.get_pixel(12, tree.get_height() - 3).is_equal_approx(Color("6b4420"))
			and tree.get_pixel(12, tree.get_height() - 2) == SheepLook.OUTLINE, "a tree stands on its trunk, with a black line around it")
	var blocks := SheepLook.barn_blocks(Vector2(1000, 200))
	_check(blocks.size() == 2 and blocks[0].size == Vector2(224, 128) and blocks[1].size.y == 152.0,
			"the barn blocks its walls and the silo")


## The difficulty (REQ-SH-17, 18).
func _levels() -> void:
	print("the difficulty")
	var lv: Dictionary = load("res://scripts/game/sheep_herding/sheep_herding_game.gd").LEVELS
	_check(lv.easy.sheep == 8 and lv.medium.sheep == 11 and lv.hard.sheep == 14,
			"8, 11 and 14 sheep on Easy, Medium and Hard (REQ-SH-17)")
	_check(lv.easy.flee < lv.medium.flee and lv.medium.flee < lv.hard.flee and lv.easy.speed < lv.medium.speed
			and lv.medium.speed < lv.hard.speed, "harder levels have a longer scare and faster sheep")
	_check(lv.easy.gate > lv.medium.gate and lv.medium.gate > lv.hard.gate and lv.hard.gate >= 150.0,
			"harder levels have a narrower gate")
	_check(lv.easy.time > lv.medium.time and lv.medium.time > lv.hard.time, "harder levels have less time")
	_check(lv.easy.tiers == [4, 6, 8] and lv.medium.tiers == [6, 9, 11] and lv.hard.tiers == [8, 11, 14],
			"the medal tiers are [4, 6, 8], [6, 9, 11] and [8, 11, 14] sheep (REQ-SH-18)")
	var tiers_ok := true
	for d in ["easy", "medium", "hard"]:
		var t: Array = lv[d].tiers
		tiers_ok = tiers_ok and Medals.is_valid(t) and t[2] == lv[d].sheep and Medals.medal(t[0] - 1, t) == "" \
				and Medals.medal(t[0], t) == "bronze" and Medals.medal(t[1], t) == "silver" and Medals.medal(t[2], t) == "gold"
		tiers_ok = tiers_ok and lv[d].gate > 2.0 * SheepFlock.RADIUS * 2.0
	_check(tiers_ok, "gold is every sheep, each limit gives its medal, and the gate is wider than two sheep (REQ-SH-18)")
