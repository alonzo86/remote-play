extends SceneTree
## Sheep Herding: nothing leaves the grass and no sheep can get stuck (REQ-SH-22, REQ-SH-23). A simulation without a screen on the
## real layout of the game: hundreds of rounds with random dogs, with dogs that hug every edge and every corner, with sheep that
## start next to the pen and in every corner, and a herding dog; after every tick every dog and every sheep (the whole picture) is
## on the grass and out of the fence and the barn. A static check of the free space finds the pockets, and a flock that is
## herded and then left alone ends in the pen or in the open.
## Run: godot --headless --path . --script tests/sheep_edges.gd -- --role=tv

const SheepFlock = preload("res://scripts/game/sheep_herding/sheep_flock.gd")
const SheepLook = preload("res://scripts/game/sheep_herding/sheep_look.gd")
const TiltBody = preload("res://scripts/game/tilt_body.gd")

var Game: GDScript

const DT := 1.0 / 30.0
const RANDOM_ROUNDS := 300           # Rounds with random dogs.
const ROUND_TICKS := 240             # 8 s of a round.
const HERD_SEEDS := 24
const SLACK := 1.0                   # A circle may touch a wall; more than 1 px inside it is "in the wall".
const CELL := 8.0
const SHEEP_PICTURE := Vector2(36.0, 28.0)   # How far the middle of a sheep stays from the edge (half of 72 x 56 px).
const DOG_PICTURE := Vector2(40.0, 30.0)   # The same for a dog (REQ-SH-22): 40 px sideways, 30 px up and down.

var _checks := 0
var _fails := 0
var _field := Rect2()
var _pen := Rect2()
var _origin := Vector2.ZERO


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
	Game = load("res://scripts/game/sheep_herding/sheep_herding_game.gd")   # At run time: it needs the autoloads.
	var l := _layout()
	_field = l.field
	_pen = l.pen
	_origin = l.barn_origin
	_layout_rules()
	_free_space()
	_random_rounds()
	_hugging_dogs()
	_pushed_sheep()
	_herded_flock()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The seams: the layout of the game and one step of the dogs.
func _layout() -> Dictionary:
	return Game.layout()


func _move_dogs(bodies: Dictionary, tilts: Dictionary, f: SheepFlock) -> void:
	Game.move_dogs(bodies, tilts, DT, f)


func _flock(level: String) -> SheepFlock:
	var f := SheepFlock.new()
	var blockers: Array[Dictionary] = []
	f.setup(_field, _pen, Game.LEVELS[level], blockers, SheepLook.barn_blocks(_origin))
	return f


func _rng(n: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = n
	return r


## How far a circle at `p` is inside a wall (0 when it does not touch).
func _depth(f: SheepFlock, p: Vector2, r: float) -> float:
	var worst := 0.0
	for w in f.walls:
		var push := SheepFlock.push_out_of_rect(p, r, w)
		worst = maxf(worst, push.length())
	return worst


## The reason why a dog or a sheep is not where it should be, or "" when it is. `half` is half of the picture.
func _problem(f: SheepFlock, p: Vector2, r: float, half: Vector2) -> String:
	if not _field.encloses(Rect2(p - half, half * 2.0)):
		return "outside the grass at %s" % str(p)
	var d := _depth(f, p, r)
	if d > SLACK:
		return "%.1f px inside a wall at %s" % [d, str(p)]
	return ""


## The first problem of the dogs and the sheep of a flock, or "".
func _first_problem(f: SheepFlock, dogs: Dictionary) -> String:
	for s in f.sheep:
		var why := _problem(f, s.pos, SheepFlock.RADIUS, SHEEP_PICTURE)
		if why != "":
			return "sheep %s" % why
	for slot in dogs:
		var why := _problem(f, dogs[slot].pos, dogs[slot].radius, DOG_PICTURE)
		if why != "":
			return "dog %s" % why
	return ""


func _dogs(count: int) -> Dictionary:
	var d := {}
	for i in count:
		var b := TiltBody.new()
		b.radius = Game.DOG_R
		b.max_speed = Game.DOG_SPEED
		b.pos = _field.position + Vector2(120.0, _field.size.y * (0.15 + 0.23 * float(i)))
		d[i] = b
	return d


func _dog_spots(dogs: Dictionary) -> Dictionary:
	var spots := {}
	for s in dogs:
		spots[s] = dogs[s].pos
	return spots


## The places for the start of a sheep next to every corner of the grass, the pen and the barn: only places where a sheep may
## stand (on the grass, in no wall); a sheep never starts inside a wall (`SheepFlock.spawn`).
func _edge_starts() -> Array[Vector2]:
	var f := _flock("hard")
	var legal: Array[Vector2] = []
	for p in _raw_starts():
		if _is_free(f, p):
			legal.append(p)
	return legal


func _raw_starts() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var f := _field.grow(-40.0)
	for c in [f.position, Vector2(f.end.x, f.position.y), Vector2(f.position.x, f.end.y), f.end]:
		for dx in [0.0, 50.0]:
			out.append(c + Vector2(-dx if c.x > f.get_center().x else dx, 0.0))
	for k in 6:
		out.append(Vector2(_pen.position.x - 36.0, _pen.position.y + 40.0 + 56.0 * float(k)))   # at the left fence and the gate
		out.append(Vector2(_pen.position.x + 40.0 + 50.0 * float(k), _pen.position.y - 40.0))   # on top of the pen
		out.append(Vector2(_pen.end.x + 10.0 + 0.0 * k, _pen.position.y - 40.0 - 56.0 * float(k)))
		out.append(Vector2(_pen.end.x - 30.0, _pen.position.y - 40.0 - 56.0 * float(k)))        # at the barn and the right edge
	return out


# ---- The layout ----

func _layout_rules() -> void:
	print("the layout of the pen (REQ-SH-23)")
	_check(is_equal_approx(_pen.end.x, _field.end.x) and is_equal_approx(_pen.end.y, _field.end.y),
			"the pen is in the bottom right corner of the grass, flush with both edges: %s in %s" % [str(_pen), str(_field)])
	var f := _flock("hard")
	var gate := f.gate_center()
	_check(_field.grow(-SheepFlock.RADIUS).has_point(gate) and gate.x < _pen.end.x - 200.0 and gate.y > _field.position.y + 400.0,
			"the gate faces the open field, far from the black margin and from the HUD: %s" % str(gate))
	var barn := SheepLook.barn_blocks(_origin)
	_check(is_equal_approx(barn[0].end.x, _field.end.x) and is_equal_approx(barn[0].end.y, _pen.position.y),
			"the barn stands on the pen and is flush with the right edge: %s" % str(barn[0]))
	_check(barn[1].end.y == barn[0].end.y and is_equal_approx(barn[1].position.x, _pen.position.x),
			"the silo stands on the pen too, at its left end, so no gap or ledge is left")
	_check(_field.encloses(Rect2(_origin + Vector2(-14.0, -14.0) * 4.0, Vector2(73.0, 60.0) * 4.0)),
			"the whole picture of the barn (the roof and the vane) is on the grass")


## The distance between two rectangles (0 when they touch or overlap).
func _rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dy := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(dx, dy).length()


## True when a third thing touches both, so that the space between the two is closed (the silo between the pen and the barn).
func _bridged(things: Array[Rect2], i: int, j: int) -> bool:
	for k in things.size():
		if k != i and k != j and _rect_gap(things[k], things[i]) <= 0.5 and _rect_gap(things[k], things[j]) <= 0.5:
			return true
	return false


## A gap between two things (a piece of the fence, the barn, the silo, an edge of the grass) that is wider than 0 and narrower
## than
## a sheep (56 px) is a place where a sheep wedges: the walls push it out and the edge pushes it back. There must be none.
func _narrow_gaps() -> Array[String]:
	var f := _flock("hard")
	var things: Array[Rect2] = f.walls.duplicate()
	var edge := 200.0
	things.append(Rect2(_field.position - Vector2(edge, edge), Vector2(edge, _field.size.y + 2.0 * edge)))
	things.append(Rect2(Vector2(_field.end.x, _field.position.y - edge), Vector2(edge, _field.size.y + 2.0 * edge)))
	things.append(Rect2(_field.position - Vector2(edge, edge), Vector2(_field.size.x + 2.0 * edge, edge)))
	things.append(Rect2(Vector2(_field.position.x - edge, _field.end.y), Vector2(_field.size.x + 2.0 * edge, edge)))
	var bad: Array[String] = []
	for i in things.size():
		for j in range(i + 1, things.size()):
			var g := _rect_gap(things[i], things[j])
			if g > 0.5 and g < 2.0 * SheepFlock.RADIUS and not _bridged(things, i, j):
				bad.append("%s and %s: %.0f px" % [str(things[i]), str(things[j]), g])
	return bad


## A cell of the grid where the middle of a sheep can stand (the picture on the grass, no wall touched).
func _is_free(f: SheepFlock, p: Vector2) -> bool:
	return _field.encloses(Rect2(p - SHEEP_PICTURE, SHEEP_PICTURE * 2.0)) and _depth(f, p, SheepFlock.RADIUS) <= SLACK


## Static pockets: the free space for a sheep is one region (reached from the gate), and a sheep that is made to stand on a
## place that is not free (the old gap behind the pen) is not left there by `resolve`.
func _free_space() -> void:
	print("the free space of a sheep has no pocket (REQ-SH-23)")
	var f := _flock("hard")
	var cols := int(_field.size.x / CELL)
	var rows := int(_field.size.y / CELL)
	var free := {}
	for cx in cols:
		for cy in rows:
			var p := _field.position + Vector2(float(cx) + 0.5, float(cy) + 0.5) * CELL
			if _is_free(f, p):
				free[Vector2i(cx, cy)] = true
	var from := f.gate_center() - _field.position - Vector2(60.0, 0.0)
	var start := Vector2i(int(from.x / CELL), int(from.y / CELL))
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if free.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	var gaps := _narrow_gaps()
	_check(gaps.is_empty(), "no gap between walls, or a wall and an edge, is narrower than a sheep and not closed: %s" % str(gaps))
	_check(free.has(start), "the cell in front of the gate is free")
	_check(seen.size() == free.size(), "every free cell is reached from the gate (no pocket): %d of %d" % [seen.size(), free.size()])
	_check(_edge_starts().size() >= 10, "there are many legal edge starts for the simulations: %d" % _edge_starts().size())


# ---- Simulations ----

func _random_rounds() -> void:
	print("%d rounds with random dogs: nothing leaves the grass or goes into a wall" % RANDOM_ROUNDS)
	var bad := ""
	var rounds_bad := 0
	var walls_n := 0
	var outside_n := 0
	for n in RANDOM_ROUNDS:
		var r := _rng(1000 + n)
		var f := _flock(["easy", "medium", "hard"][n % 3])
		var area := Rect2(_field.position + Vector2(380.0, 160.0), Vector2(900.0, 560.0))
		f.spawn(int(Game.LEVELS[["easy", "medium", "hard"][n % 3]].sheep), area, r)
		var starts := _edge_starts()
		for i in mini(f.sheep.size() / 2, starts.size()):
			f.sheep[i].pos = starts[(i * 7 + n) % starts.size()]   # a half of the flock starts at an edge, a corner or the pen
		var dogs := _dogs(1 + n % 4)
		var tilts := {}
		var why := ""
		for t in ROUND_TICKS:
			if t % 12 == 0:
				for s in dogs:
					tilts[s] = Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.4, 1.0)
			_move_dogs(dogs, tilts, f)
			f.tick(DT, _dog_spots(dogs), r)
			why = _first_problem(f, dogs)
			if why != "":
				why = "round %d tick %d: %s" % [n, t, why]
				break
		if why != "":
			rounds_bad += 1
			walls_n += 1 if "wall" in why else 0
			outside_n += 1 if "outside" in why else 0
			bad = bad if bad != "" else why
	_check(rounds_bad == 0, "%d of %d rounds: outside (%d) or in a wall (%d); first: %s" % [rounds_bad, RANDOM_ROUNDS,
			outside_n, walls_n, bad])


## Dogs that push at every edge and every corner (8 directions, 1 to 4 dogs, side by side so that they bounce off each other).
func _hugging_dogs() -> void:
	print("dogs that hug every edge and corner")
	var bad := ""
	var cases := 0
	for dir_n in 8:
		for count in [1, 2, 4]:
			cases += 1
			var r := _rng(50 + dir_n * 10 + count)
			var f := _flock("medium")
			f.spawn(11, Rect2(_field.position + Vector2(380.0, 160.0), Vector2(900.0, 560.0)), r)
			var dogs := _dogs(count)
			var dir := Vector2.from_angle(float(dir_n) * TAU / 8.0)
			var tilts := {}
			var why := ""
			for t in 360:
				for s in dogs:
					# All dogs push the same way, some from a place that sends them to the pen and the barn.
					tilts[s] = dir.rotated(0.05 * float(s)) if t < 300 else Vector2(1.0, 1.0).normalized()
				_move_dogs(dogs, tilts, f)
				f.tick(DT, _dog_spots(dogs), r)
				why = _first_problem(f, dogs)
				if why != "":
					why = "direction %d, %d dogs, tick %d: %s" % [dir_n, count, t, why]
					break
			if why != "":
				bad = bad if bad != "" else why
	_check(bad == "", "%d cases, no dog or sheep outside or in a wall (first problem: %s)" % [cases, bad])
	# Two dogs squeezed into a corner and into the pen corner bounce off each other without leaving.
	var f2 := _flock("hard")
	var two := _dogs(2)
	two[0].pos = _field.position + Vector2(60.0, 60.0)
	two[1].pos = _field.position + Vector2(62.0, 61.0)
	for t in 120:
		_move_dogs(two, {0: Vector2(-1.0, -1.0), 1: Vector2(-1.0, -1.0)}, f2)
	_check(_first_problem(f2, two) == "", "two dogs pushed into the top left corner stay on the grass: %s" % _first_problem(f2, two))
	two[0].pos = _pen.position + Vector2(-50.0, -50.0)
	two[1].pos = _pen.position + Vector2(-48.0, -49.0)
	for t in 120:
		_move_dogs(two, {0: Vector2(1.0, 1.0), 1: Vector2(1.0, 1.0)}, f2)
	_check(_first_problem(f2, two) == "", "two dogs pushed at the pen corner stay out of the fence: %s" % _first_problem(f2, two))


## One dog chases one sheep that starts at every legal edge place, from 8 sides, for 8 s: the sheep is pushed into every corner,
## along every wall and into the narrow places. It is never in a wall or off the grass, and it is never wedged: when the dog
## has left, the sheep is free to move (it is not in a wall) after 6 s.
func _pushed_sheep() -> void:
	print("a dog pushes one sheep along every edge, the fence and the barn")
	var bad := ""
	var cases := 0
	for start in _edge_starts():
		for k in 8:
			cases += 1
			var r := _rng(9000 + cases)
			var f := _flock("hard")
			var s := SheepFlock.Sheep.new()
			s.pos = start
			f.sheep.append(s)
			var dogs := _dogs(1)
			dogs[0].pos = start + Vector2.from_angle(float(k) * TAU / 8.0) * 140.0
			dogs[0].pos = dogs[0].pos.clamp(_field.position + Vector2(60.0, 60.0), _field.end - Vector2(60.0, 60.0))
			var why := ""
			for t in 360:
				var tilts := {0: (s.pos - dogs[0].pos).limit_length(200.0) / 200.0} if t < 240 else {}
				_move_dogs(dogs, tilts, f)
				f.tick(DT, _dog_spots(dogs) if t < 240 else {}, r)
				why = _first_problem(f, dogs)
				if why != "":
					why = "start %s, dog from side %d, tick %d: %s" % [str(start), k, t, why]
					break
			if why != "":
				bad = bad if bad != "" else why
	_check(bad == "", "%d cases, no dog or sheep outside or in a wall (first problem: %s)" % [cases, bad])


## A dog that herds the flock to the gate for 40 s; then it leaves and the sheep graze for 20 s. At the end every sheep is in
## the pen or free in the open: none is in a wall or in a pocket (REQ-SH-23).
func _herded_flock() -> void:
	print("a herded flock ends in the pen or in the open (%d seeds)" % HERD_SEEDS)
	var bad := ""
	var in_pen := 0
	var total := 0
	for n in HERD_SEEDS:
		var r := _rng(7000 + n)
		var level: String = ["easy", "medium", "hard"][n % 3]
		var f := _flock(level)
		f.spawn(int(Game.LEVELS[level].sheep), Rect2(_field.position + Vector2(380.0, 160.0), Vector2(560.0, _field.size.y - 320.0)), r)
		var starts := _edge_starts()
		for i in 3:
			f.sheep[i].pos = starts[(n * 5 + i * 11) % starts.size()]   # some sheep start at an edge, a corner or the pen
		var dogs := _dogs(2)
		var gate := f.gate_center()
		var why := ""
		for t in 1800:
			var tilts := {}
			if t < 1200:
				_herd(f, dogs, gate, tilts)
			_move_dogs(dogs, tilts, f)
			f.tick(DT, _dog_spots(dogs) if t < 1200 else {}, r)
			why = _first_problem(f, dogs)
			if why != "":
				why = "seed %d tick %d: %s" % [n, t, why]
				break
		total += f.sheep.size()
		in_pen += f.penned_count()
		if why == "":
			for s in f.sheep:
				if not s.penned and not _is_free(f, s.pos):
					why = "seed %d: a sheep is left in a pocket at %s" % [n, str(s.pos)]
					break
		if why != "":
			bad = bad if bad != "" else why
	_check(bad == "", "no sheep is in a wall or a pocket at any tick or at the end (first problem: %s)" % bad)
	_check(in_pen * 2 >= total, "the herding dog brought at least half of the sheep into the pen: %d of %d" % [in_pen, total])


## The tilt of two dogs that go behind the free sheep that is the farthest from the gate and push it toward the gate.
func _herd(f: SheepFlock, dogs: Dictionary, gate: Vector2, tilts: Dictionary) -> void:
	var free: Array = f.sheep.filter(func(s: SheepFlock.Sheep) -> bool: return not s.penned)
	if free.is_empty():
		return
	free.sort_custom(func(a: SheepFlock.Sheep, b: SheepFlock.Sheep) -> bool:
			return a.pos.distance_to(gate) > b.pos.distance_to(gate))
	for i in dogs.size():
		var target: SheepFlock.Sheep = free[mini(i, free.size() - 1)]
		var behind: Vector2 = target.pos + (target.pos - gate).normalized() * 150.0
		behind = behind.clamp(_field.position + Vector2(80.0, 60.0), _field.end - Vector2(80.0, 60.0))
		tilts[i] = (behind - dogs[i].pos).limit_length(300.0) / 300.0
