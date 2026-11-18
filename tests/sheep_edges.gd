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
	_picture_rect()
	_markers_inside()
	_free_space()
	_barn_picture()
	_penned_stay()
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


## A picture that is turned around is drawn on the same box as the one that is not (REQ-SH-22). Godot flips a picture when the
## width of the rectangle is negative and keeps `position` as the left side, so the flipped picture fills `position` to
## `position + abs(width)`. Found on a real render: a sheep that walked left was drawn one picture too far right, over the
## barn or off the grass, while its collision stayed where it was.
func _picture_rect() -> void:
	print("a turned picture fills the same box as a normal one (REQ-SH-22)")
	var top_left := Vector2(100.0, 200.0)
	var sz := Vector2(72.0, 56.0)
	for face in [1, -1]:
		var r: Rect2 = Game.picture_rect(top_left, sz, face)
		var filled := Rect2(r.position, r.size.abs())   # Where Godot draws it.
		_check(filled == Rect2(top_left, sz), "face %d: the drawn box is the box of the picture: %s" % [face, str(filled)])
		_check((r.size.x < 0.0) == (face < 0), "face %d: the picture is flipped only when it looks left" % face)


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
## The heart, the "z" and the speed dashes of a sheep are on the grass at every place a sheep can stand (the edges too), the
## corners and every edge (REQ-SH-15, issue #485); in the middle they are where they always were.
func _markers_inside() -> void:
	var heart := Vector2(7.0, 6.0) * 4.0
	var snooze := Vector2(4.0, 5.0) * 4.0
	var bad_marker := ""
	var bad_dash := ""
	var n := 0
	var x := _field.position.x + SHEEP_PICTURE.x
	while x <= _field.end.x - SHEEP_PICTURE.x:
		var y := _field.position.y + SHEEP_PICTURE.y
		while y <= _field.end.y - SHEEP_PICTURE.y:
			var c := Vector2(x, y)
			for sz in [heart, snooze]:
				var r: Rect2 = Game.marker_rect(c + Vector2(0.0, -52.0), sz, _field)
				if not _field.encloses(r) and bad_marker == "":
					bad_marker = "%s at %s" % [str(r), str(c)]
				n += 1
			for a in 16:
				var back := Vector2.from_angle(TAU * float(a) / 16.0)
				for r in Game.dash_rects(c, back, _field):
					if not _field.encloses(r) and bad_dash == "":
						bad_dash = "%s at %s, back %s" % [str(r), str(c), str(back)]
				n += 1
			y += 20.0
		x += 20.0
	_check(bad_marker == "", "heart and z inside the grass at %d places (%s)" % [n, bad_marker])
	_check(bad_dash == "", "speed dashes inside the grass at every place and 16 directions (%s)" % bad_dash)
	var mid := _field.get_center()
	var r0: Rect2 = Game.marker_rect(mid + Vector2(0.0, -52.0), heart, _field)
	var want := mid + Vector2(0.0, -52.0)
	_check(r0.size == heart and r0.get_center().distance_to(want) <= 4.0, "in the middle the heart stays over the sheep")
	var top: Rect2 = Game.marker_rect(Vector2(mid.x, _field.position.y + 28.0 - 52.0), heart, _field)
	_check(is_equal_approx(top.position.y, _field.position.y), "at the top edge the heart is moved down to the grass, not cut")
	var d: Array[Rect2] = Game.dash_rects(mid, Vector2.LEFT, _field)
	var near := absf(d[0].position.x - (mid.x - 46.0)) <= 2.0 and absf(d[2].position.x - (mid.x - 78.0)) <= 2.0
	_check(d.size() == 3 and near, "in the middle the dashes are 46 to 78 px behind")


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


# ---- The barn (REQ-SH-24) ----

## The parts of the picture of the barn, in screen pixels, written from the drawing (`SheepLook.draw_barn`) and not from the
## collision: the roof and the walls, the tip of the weather vane, the silo with its cap. Nothing may stand on them.
func _picture_parts() -> Array[Rect2]:
	var w := 4.0
	var o := _origin
	return [Rect2(o + Vector2(-3.0, -5.0) * w, Vector2(62.0, 51.0) * w),    # the roof (a gambrel) and the walls
			Rect2(o + Vector2(24.0, -14.0) * w, Vector2(11.0, 9.0) * w),    # the weather vane
			Rect2(o + Vector2(-14.0, 2.0) * w, Vector2(14.0, 44.0) * w)]    # the silo and its cap


## How far a circle is inside the picture of the barn (0 when it is clear of it).
func _in_picture(p: Vector2, r: float) -> float:
	var worst := 0.0
	for part in _picture_parts():
		worst = maxf(worst, SheepFlock.push_out_of_rect(p, r, part).length())
	return worst


## The reason why a dog or a sheep is on the barn or not on the grass, or "".
func _barn_problem(f: SheepFlock, dogs: Dictionary) -> String:
	var why := _first_problem(f, dogs)
	if why != "":
		return why
	for s in f.sheep:
		if _in_picture(s.pos, SheepFlock.RADIUS) > SLACK:
			return "sheep on the barn at %s" % str(s.pos)
	for slot in dogs:
		if _in_picture(dogs[slot].pos, dogs[slot].radius) > SLACK:
			return "dog on the barn at %s" % str(dogs[slot].pos)
	return ""


## Where a dog or a sheep is aimed at: the places of the picture that were open before (the roof, the vane, the top of the silo,
## the right end of the roof at the edge of the grass) and the middle of the walls.
func _barn_targets() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for q in [Vector2(28.0, 6.0), Vector2(28.0, -10.0), Vector2(-7.0, 2.0), Vector2(56.0, 5.0), Vector2(58.0, 14.0),
			Vector2(30.0, 40.0), Vector2(0.0, 0.0), Vector2(57.0, -4.0)]:
		out.append(_origin + q * 4.0)
	return out


func _on_field(p: Vector2) -> Vector2:
	return p.clamp(_field.position + Vector2(60.0, 60.0), _field.end - Vector2(60.0, 60.0))


func _barn_picture() -> void:
	print("nothing is on the barn: not the roof, the vane, the silo or the edge beside it (REQ-SH-24)")
	var f := _flock("hard")
	var cols := int(_field.size.x / CELL)
	var rows := int(_field.size.y / CELL)
	var on_barn := 0
	var dog_on := 0
	var dogs := _dogs(1)
	for cx in cols:
		for cy in rows:
			var p := _field.position + Vector2(float(cx) + 0.5, float(cy) + 0.5) * CELL
			if _is_free(f, p) and _in_picture(p, SheepFlock.RADIUS) > SLACK:
				on_barn += 1
			if cx % 4 == 0 and cy % 4 == 0:
				dogs[0].pos = p
				dogs[0].vel = Vector2.ZERO
				_move_dogs(dogs, {0: Vector2.ZERO}, f)
				if _in_picture(dogs[0].pos, Game.DOG_R) > SLACK:
					dog_on += 1
	_check(on_barn == 0, "no place where a sheep can stand is on the picture of the barn: %d cells" % on_barn)
	_check(dog_on == 0, "a dog put anywhere on the grass is put out of the barn: %d cells" % dog_on)
	# A dog is driven at every target of the barn from 16 sides.
	var bad := ""
	var cases := 0
	for target in _barn_targets():
		for k in 16:
			cases += 1
			var flock := _flock("hard")
			var d := _dogs(1)
			d[0].pos = _on_field(target + Vector2.from_angle(float(k) * TAU / 16.0) * 260.0)
			for t in 150:
				_move_dogs(d, {0: (target - d[0].pos).limit_length(100.0) / 100.0}, flock)
				var why := _barn_problem(flock, d)
				if why != "":
					bad = bad if bad != "" else "target %s, side %d, tick %d: %s" % [str(target), k, t, why]
					break
	_check(bad == "",
			"%d dogs driven at the roof, the vane, the silo and the edge stay off the barn (first problem: %s)" % [cases, bad])
	# A sheep is pushed at every target by a dog that follows it, from 16 sides.
	bad = ""
	cases = 0
	for target in _barn_targets():
		for k in 16:
			var r := _rng(4000 + cases)
			var flock := _flock("hard")
			var sh := SheepFlock.Sheep.new()
			sh.pos = _on_field(target + Vector2.from_angle(float(k) * TAU / 16.0) * 200.0)
			if not _is_free(flock, sh.pos):
				continue
			cases += 1
			flock.sheep.append(sh)
			var d := _dogs(1)
			d[0].pos = _on_field(sh.pos - (target - sh.pos).normalized() * 110.0)
			for t in 240:
				var behind := sh.pos - (target - sh.pos).normalized() * 90.0
				_move_dogs(d, {0: (behind - d[0].pos).limit_length(150.0) / 150.0}, flock)
				flock.tick(DT, _dog_spots(d), r)
				var why := _barn_problem(flock, d)
				if why != "":
					bad = bad if bad != "" else "target %s, side %d, tick %d: %s" % [str(target), k, t, why]
					break
	_check(cases >= 40, "many legal starts for the pushed sheep: %d" % cases)
	_check(bad == "",
			"%d sheep pushed at the roof, the vane, the silo and the edge stay off the barn (first problem: %s)" % [cases, bad])
	# A sheep put on the roof is inside a wall of the game, so it is pushed out.
	var roof := _origin + Vector2(30.0, 4.0) * 4.0
	_check(_depth(f, roof, SheepFlock.RADIUS) > 40.0, "the roof is a wall of the game: a sheep put on it is pushed out")


# ---- The pen holds its sheep (REQ-SH-24) ----

## A penned sheep stays inside the pen box (the inside of the fence, less the radius of the sheep) at every tick.
func _penned_problem(f: SheepFlock) -> String:
	var box := f.interior().grow(-SheepFlock.RADIUS).grow(0.01)
	for s in f.sheep:
		if s.penned and not box.has_point(s.pos):
			return "a penned sheep is outside the pen box at %s" % str(s.pos)
	return ""


func _penned_stay() -> void:
	print("a sheep in the pen stays in the pen (REQ-SH-24)")
	var bad := ""
	var cases := 0
	for k in 12:
		cases += 1
		var r := _rng(600 + k)
		var f := _flock("medium")
		var gate := f.gate_center()
		var count := 0
		# Penned sheep at the gate and along the fence, and free sheep crowding the gate from outside.
		for q in [Vector2(40.0, 0.0), Vector2(60.0, 70.0), Vector2(60.0, -70.0), Vector2(100.0, 0.0), Vector2(60.0, 130.0)]:
			var s := SheepFlock.Sheep.new()
			s.pos = gate + q
			s.penned = true
			f.sheep.append(s)
			count += 1
		for q in [Vector2(-60.0, 0.0), Vector2(-70.0, 55.0), Vector2(-70.0, -55.0), Vector2(-130.0, 20.0)]:
			var s := SheepFlock.Sheep.new()
			s.pos = gate + q
			f.sheep.append(s)
		var dogs := _dogs(1 + k % 4)
		for slot in dogs:
			dogs[slot].pos = _on_field(gate + Vector2.from_angle(float(k + slot * 3) * TAU / 12.0) * 300.0)
		var why := ""
		for t in 360:
			var tilts := {}
			for slot in dogs:
				# Every dog goes to the gate, from a different side, and then stays there and pushes.
				var side := Vector2.from_angle(float(k + slot * 3) * TAU / 12.0)
				var aim := gate + side * (60.0 if t > 120 else 200.0)
				tilts[slot] = (aim - dogs[slot].pos).limit_length(150.0) / 150.0
			_move_dogs(dogs, tilts, f)
			f.tick(DT, _dog_spots(dogs), r)
			why = _penned_problem(f)
			if why == "" and f.penned_count() < count:
				why = "a penned sheep got out of the count: %d of %d" % [f.penned_count(), count]
			if why == "":
				why = _first_problem(f, dogs)
			if why != "":
				why = "case %d tick %d: %s" % [k, t, why]
				break
		if why != "":
			bad = bad if bad != "" else why
	_check(bad == "",
			"%d cases: penned sheep at the gate with dogs on every side never leave the pen (first: %s)" % [cases, bad])
	# A penned sheep that is in the gate (it has just come in) is inside the pen box after one tick.
	var f2 := _flock("hard")
	var inn := SheepFlock.Sheep.new()
	inn.pos = f2.gate_center() + Vector2(-20.0, 10.0)
	inn.penned = true
	f2.sheep.append(inn)
	f2.tick(DT, {}, _rng(1))
	_check(_penned_problem(f2) == "" and inn.penned, "a penned sheep in the gate is put in the pen box at once: %s" % str(inn.pos))
	# A herded flock: a sheep is counted once, and once it is in the pen it is in the pen until the end.
	var in_total := 0
	var counted := 0
	bad = ""
	for n in 12:
		var r := _rng(8100 + n)
		var level: String = ["easy", "medium", "hard"][n % 3]
		var f := _flock(level)
		f.spawn(int(Game.LEVELS[level].sheep), Rect2(_field.position + Vector2(380.0, 160.0), Vector2(560.0, _field.size.y - 320.0)), r)
		var herd := _dogs(2)
		var gate3 := f.gate_center()
		var seen := {}
		var was_in := {}
		for t in 1500:
			var tilts := {}
			_herd(f, herd, gate3, tilts)
			_move_dogs(herd, tilts, f)
			f.tick(DT, _dog_spots(herd), r)
			for e in f.events:
				if String(e.t) == "penned":
					counted += 1
					seen[int(e.i)] = int(seen.get(int(e.i), 0)) + 1
			for i in f.sheep.size():
				if was_in.has(i) and not f.sheep[i].penned:
					bad = bad if bad != "" else "seed %d: sheep %d left the pen" % [n, i]
				if f.sheep[i].penned:
					was_in[i] = true
			if bad == "" and _penned_problem(f) != "":
				bad = "seed %d tick %d: %s" % [n, t, _penned_problem(f)]
			if bad != "":
				break
		for i in seen:
			if int(seen[i]) != 1:
				bad = bad if bad != "" else "seed %d: sheep %d was counted %d times" % [n, i, seen[i]]
		in_total += f.penned_count()
	_check(bad == "",
			"a herded flock: a sheep that is in stays in, inside the box, and is counted once (first problem: %s)" % bad)
	_check(counted == in_total and in_total > 0, "every penned sheep is counted once: %d events, %d sheep" % [counted, in_total])


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
	_check(_first_problem(f2, two) == "",
			"two dogs pushed into the top left corner stay on the grass: %s" % _first_problem(f2, two))
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
