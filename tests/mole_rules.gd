extends SceneTree
## The rules of Whack-a-Mole, without a screen: the holes, popping up and down, spawning, the hit test and the pictures
## (REQ-WM-6 to 10, 15). Run: godot --headless --path . --script tests/mole_rules.gd -- --role=controller

const MoleField = preload("res://scripts/game/whack_a_mole/mole_field.gd")
const MoleLook = preload("res://scripts/game/whack_a_mole/mole_look.gd")
const PointerMap = preload("res://scripts/game/pointer_map.gd")

var _checks := 0
var _fails := 0
var _area := Rect2(60.0, 150.0, 1800.0, 870.0)


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_holes()
	_cycle()
	_spawning()
	_spawn_timer()
	_hit_motion()
	_hits()
	_levels()
	_pictures()
	_pointer_map()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _field(difficulty := "medium") -> MoleField:
	var f := MoleField.new()
	f.setup(difficulty)
	return f


## A mole in `hole` that is fully up (after the rise).
func _up(f: MoleField, hole: int, golden := false) -> MoleField.Mole:
	f._add(hole, golden)
	var m: MoleField.Mole = f.moles[f.moles.size() - 1]
	m.age = MoleField.RISE_TIME + 0.01
	return m


## REQ-WM-6: nine holes in a grid, inside the play area, in a grid of 3 columns and 3 rows.
func _holes() -> void:
	print("holes")
	var xs := {}
	var ys := {}
	var inside := true
	for h in 9:
		var p := MoleField.hole_pos(h, _area)
		xs[snappedf(p.x, 0.1)] = true
		ys[snappedf(p.y, 0.1)] = true
		inside = inside and _area.has_point(p)
	_check(xs.size() == 3 and ys.size() == 3 and inside, "nine holes: 3 columns, 3 rows, all inside the play area (REQ-WM-6)")
	var small := Rect2(60.0, 150.0, 1160.0, 510.0)
	_check(small.has_point(MoleField.hole_pos(8, small)) and MoleField.scale_for(small) < 0.7,
			"the holes and the sizes follow the play area at 1280x720 (REQ-WM-15)")


## REQ-WM-6: a mole rises in 0.25 s, stays, goes down in 0.25 s and is gone; a hit mole stays 0.8 s.
func _cycle() -> void:
	print("rise and fall")
	var f := _field()
	f._add(4, false)
	var m: MoleField.Mole = f.moles[0]
	_check(m.out() == 0.0, "a new mole is hidden")
	m.age = MoleField.RISE_TIME * 0.5
	_check(is_equal_approx(m.out(), 0.5) and not MoleField.is_hittable(m), "half way up: 50 % out, not hittable yet")
	m.age = MoleField.RISE_TIME + 0.2
	_check(m.out() == 1.0 and MoleField.is_hittable(m), "up: fully out and hittable")
	m.age = MoleField.RISE_TIME + float(f.level.stay) + MoleField.DOWN_TIME * 0.25
	_check(is_equal_approx(m.out(), 0.75) and MoleField.is_hittable(m), "going down, still more than half out: hittable")
	m.age = MoleField.RISE_TIME + float(f.level.stay) + MoleField.DOWN_TIME * 0.75
	_check(not MoleField.is_hittable(m) and not m.is_done(), "going down, less than half out: not hittable")
	m.age = MoleField.RISE_TIME + float(f.level.stay) + MoleField.DOWN_TIME + 0.01
	_check(m.is_done(), "after the stay and the fall the mole is done")
	f.tick(0.0, _rng(1), 1)
	_check(f.moles.filter(func(x: MoleField.Mole) -> bool: return x == m).is_empty(), "a mole that is done is removed (no loss)")
	var g := _field()
	g._add(0, false)
	var hit: MoleField.Mole = g.moles[0]
	g.take(hit)
	g.tick(0.7, _rng(1), 1)
	_check(hit in g.moles and hit.out() == 1.0, "a hit mole stays fully out during its happy animation (REQ-WM-7)")
	g.tick(0.15, _rng(1), 1)
	_check(not (hit in g.moles), "a hit mole is gone after 0.8 s")


## REQ-WM-8, 9: the first mole comes at once, the limit is the base plus the players (at most 6), a hole holds one mole,
## and the golden mole comes after 10 s.
func _spawning() -> void:
	print("spawning")
	var f := _field()
	var rng := _rng(5)
	f.tick(0.01, rng, 1)
	_check(f.moles.size() == 1, "the first mole comes at once (REQ-WM-9)")
	for i in 600:
		f.tick(0.05, rng, 1)
		var seen := {}
		var unique := true
		for m in f.moles:
			unique = unique and not seen.has(m.hole)
			seen[m.hole] = true
		if not unique or f.normal_count() > f.max_out(1):
			break
	_check(f.normal_count() <= f.max_out(1), "never more moles out than 2 + 1 player at Medium (%d)" % f.normal_count())
	_check(f.max_out(1) == 3 and f.max_out(4) == 6 and _field("hard").max_out(4) == 6 and _field("easy").max_out(2) == 4,
			"the limit is max_base + the number of players, at most 6")
	var seen_hole := {}
	var one_each := true
	for m in f.moles:
		one_each = one_each and not seen_hole.has(m.hole)
		seen_hole[m.hole] = true
	_check(one_each, "a hole has at most one mole")
	var g := _field()
	var gold_rng := _rng(7)
	var first_gold := -1.0
	var t := 0.0
	while t < 40.0 and first_gold < 0.0:
		g.tick(0.05, gold_rng, 2)
		t += 0.05
		for m in g.moles:
			if m.golden:
				first_gold = t
	_check(first_gold >= 10.0 and first_gold < 11.0,
			"the first golden mole comes after 10 s of play (%.2f s, REQ-WM-8)" % first_gold)
	var a := _field()
	var b := _field()
	var ra := _rng(99)
	var rb := _rng(99)
	var same := true
	for i in 400:
		a.tick(0.05, ra, 3)
		b.tick(0.05, rb, 3)
		same = same and a.moles.size() == b.moles.size()
		for j in a.moles.size():
			same = same and a.moles[j].hole == b.moles[j].hole and a.moles[j].golden == b.moles[j].golden
	_check(same, "the same seed gives the same moles (REQ-WM-9)")


## REQ-WM-7, 8: the hit test, the nearest head wins, the points.
func _hits() -> void:
	print("hits")
	var f := _field()
	var m := _up(f, 4)
	var head := MoleField.head_pos(m, _area)
	_check(f.hit(head, _area) == m, "a bonk on the middle of the head hits")
	_check(f.hit(head + Vector2(84.0 + 11.0, 0.0), _area) == m, "a bonk 95 px from the middle hits (radius 84 + 12, Medium)")
	_check(f.hit(head + Vector2(84.0 + 14.0, 0.0), _area) == null, "a bonk 98 px from the middle misses")
	var hard := _field("hard")
	var hm := _up(hard, 4)
	_check(hard.hit(MoleField.head_pos(hm, _area) + Vector2(86.0, 0.0), _area) == null
			and f.hit(head + Vector2(86.0, 0.0), _area) == m, "the hit circle is smaller at Hard (72) than at Medium (84)")
	var rising := _field()
	rising._add(0, false)
	rising.moles[0].age = MoleField.RISE_TIME * 0.3
	_check(rising.hit(MoleField.head_pos(rising.moles[0], _area), _area) == null, "a mole that is less than half out is not hit")
	f.take(m)
	_check(f.hit(head, _area) == null, "a mole that was taken cannot be hit again (REQ-WM-7)")
	var two := _field()
	var left := _up(two, 3)
	var right := _up(two, 4)
	var between := (MoleField.head_pos(left, _area) + MoleField.head_pos(right, _area)) * 0.5
	_check(two.hit(between, _area) == null, "two holes are far enough apart that the space between them is a miss")
	var near := _up(two, 0)
	var other := _up(two, 1)
	near.age = MoleField.RISE_TIME + 0.01
	_check(two.hit(MoleField.head_pos(near, _area) + Vector2(5.0, 5.0), _area) == near and other != near,
			"the mole with the nearest head is hit")
	var gold := _up(_field(), 2, true)
	var norm := _up(_field(), 2, false)
	_check(gold.points() == 50 and norm.points() == 10, "a normal mole is worth 10, the golden one 50 (REQ-WM-8)")
	var g2 := _field()
	g2._add(2, true)
	_check(is_equal_approx(g2.moles[0].stay, 1.8 * 0.7), "the golden mole stays up for 70 % of the stay (REQ-WM-8)")


## REQ-WM-9: the time between two moles also runs while the field is full, so a free hole is not filled at once.
func _spawn_timer() -> void:
	print("spawn timer")
	var f := _field()
	var rng := _rng(4)
	for hole in 3:
		_up(f, hole).stay = 100.0
	for i in 99:
		f.tick(0.05, rng, 1)
	_check(f.normal_count() == 3 and f._spawn_left >= 0.0 and f._spawn_left <= float(f.level.spawn_every),
			"3 moles are out (the cap) for 4.95 s: the spawn timer stays between 0 and %.1f s (%.2f s)" % [
					float(f.level.spawn_every), f._spawn_left])
	f.moles.remove_at(0)
	if f._spawn_left > 0.05:
		f.tick(0.01, rng, 1)
		_check(f.normal_count() == 2, "a mole that goes away is not replaced at once: the next one waits for the timer")
	for i in 40:
		f.tick(0.05, rng, 1)
	_check(f.normal_count() == 3, "the next mole comes within 2 s (REQ-WM-9)")


## A mole that is hit while it rises or sinks keeps its place and then comes fully out (REQ-WM-7).
func _hit_motion() -> void:
	print("hit motion")
	var f := _field()
	f._add(4, false)
	var m: MoleField.Mole = f.moles[0]
	m.age = MoleField.RISE_TIME + float(f.level.stay) + MoleField.DOWN_TIME * 0.45   # 55 % out, going down
	f.take(m)
	_check(is_equal_approx(m.out(), 0.55), "a mole that is hit at 55 % out is still at 55 % in that moment (no jump)")
	f.tick(MoleField.HIT_RISE * 0.5, _rng(1), 1)
	_check(m.out() > 0.55 and m.out() < 1.0, "it comes out in between")
	f.tick(MoleField.HIT_RISE, _rng(1), 1)
	_check(m.out() == 1.0, "and it is fully out after %.2f s" % MoleField.HIT_RISE)


## The pointer mapping that Banana Party and Whack-a-Mole share (REQ-WM-3).
func _pointer_map() -> void:
	print("pointer map")
	var area := Rect2(60.0, 150.0, 1800.0, 870.0)
	var c := area.get_center()
	_check(PointerMap.aim_to_screen(Vector2.ZERO, area) == c, "pointer 0 is the center of the play area")
	_check(PointerMap.aim_to_screen(Vector2(-1, -1), area) == area.position
			and PointerMap.aim_to_screen(Vector2(1, 1), area) == area.end, "-1 is the top left edge, +1 the bottom right edge")
	_check(PointerMap.aim_to_screen(Vector2(9, -9), area) == Vector2(area.end.x, area.position.y), "values outside stay at the edge")
	_check(is_equal_approx(PointerMap.scale_for(Rect2(0, 0, 900, 435), Vector2(1800, 870)), 0.5)
			and is_equal_approx(PointerMap.scale_for(Rect2(0, 0, 900, 870), Vector2(1800, 870)), 0.5),
			"the scale is the smaller of the two ratios")


## The difficulty table: faster and more precise as it grows; unknown names fall back to Medium.
func _levels() -> void:
	print("levels")
	var e: Dictionary = MoleField.LEVELS.easy
	var m: Dictionary = MoleField.LEVELS.medium
	var h: Dictionary = MoleField.LEVELS.hard
	_check(float(e.stay) > float(m.stay) and float(m.stay) > float(h.stay), "a mole stays shorter as the difficulty grows")
	_check(float(e.spawn_every) > float(m.spawn_every) and float(m.spawn_every) > float(h.spawn_every),
			"moles come faster as the difficulty grows")
	_check(float(e.radius) > float(m.radius) and float(m.radius) > float(h.radius),
			"the hit circle is smaller as the difficulty grows")
	_check(_field("nonsense").level == MoleField.LEVELS.medium, "an unknown difficulty is Medium")
	_check(float(e.radius) >= 100.0, "Easy: the hit circle is 200 px across or more, for a child of 5")


## REQ-WM-10: the pictures have the outline and the crown; a happy mole has other eyes.
func _pictures() -> void:
	print("pictures")
	var plain := MoleLook.mole_image(false, false)
	var happy := MoleLook.mole_image(false, true)
	var gold := MoleLook.mole_image(true, false)
	_check(plain.get_size() == Vector2i(34, 42) and float(plain.get_height()) * 4.0 == MoleField.PICTURE_H,
			"a mole picture is 34 x 42 pixels, 168 px tall (the field uses this height)")
	_check(plain.get_pixel(0, 0).a == 0.0 and plain.get_pixel(17, 20).a == 1.0,
			"the corner is empty, the middle of the head is filled")
	var outline_ok := false
	for y in plain.get_height():
		for x in plain.get_width():
			if plain.get_pixel(x, y) == MoleLook.OUTLINE:
				outline_ok = true
	_check(outline_ok, "the picture has a black outline")
	_check(plain.get_data() != happy.get_data(), "a happy mole looks different (closed eyes)")
	_check(gold.get_pixel(17, 3) == MoleLook.CROWN and plain.get_pixel(17, 3).a == 0.0,
			"the golden mole has a crown, the plain one has not")
