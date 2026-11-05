extends SceneTree
## The rules of Mini Golf without a screen: the holes, the ball, the turns, the strokes, the pick-up and the medals
## (docs/games/mini_golf.md, REQ-MG-1 to 14). Run: godot --headless --path . --script tests/golf_rules.gd -- --role=controller

const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")
const Sim = preload("res://scripts/game/mini_golf/golf_sim.gd")
const Rules = preload("res://scripts/game/mini_golf/golf_rules.gd")
const Look = preload("res://scripts/game/mini_golf/golf_look.gd")
const Shell = preload("res://scripts/game/shell.gd")
const Protocol = preload("res://scripts/core/protocol.gd")

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
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_holes()
	_ball()
	_obstacles()
	_cup()
	_solvable()
	_turns()
	_pick_up()
	_holes_and_totals()
	_leaving()
	_words_and_medals()
	_things_bounce()
	_windmill_door()
	_rocks_do_not_trap()
	_debug_jump()
	_hills()
	_pars()
	await _grid()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Rolls a putt until the ball stops.
func _roll(sim: Sim, heading: float, speed: float) -> void:
	sim.putt(heading, speed)
	var guard := 0
	while not sim.finished and guard < 2000:
		sim.tick(DT)
		guard += 1


func _flat_hole() -> Dictionary:
	return {"par": 2, "tee": Vector2(0.0, 1.0), "cup": Vector2(0.0, 5.0), "fairway": [Rect2(-1.0, 0.75, 2.0, 5.0)],
			"water": [], "bridges": [], "blocks": [], "rocks": []}


## REQ-MG-12: five holes with a par of 2 to 4, and a tee and a cup on the ground, away from the things on the course.
func _holes() -> void:
	print("holes")
	_check(Holes.COUNT == 5, "the game has 5 holes")
	for n in range(1, Holes.COUNT + 1):
		var h := Holes.hole(n)
		_check(int(h.par) >= 2 and int(h.par) <= 4, "hole %d has a par of 2 to 4" % n)
		_check(Sim.walkable(h, h.tee) and Sim.walkable(h, h.cup), "hole %d: the tee and the cup are on the ground" % n)
		var clear := not Holes.is_water(h, h.tee) and not Holes.is_water(h, h.cup)
		for b in h.get("bumpers", []):
			var bv: Vector3 = b
			clear = clear and (Vector2(bv.x, bv.y) - Vector2(h.tee)).length() > bv.z + 0.3 \
					and (Vector2(bv.x, bv.y) - Vector2(h.cup)).length() > bv.z + 0.3
		for rk in h.get("rocks", []):
			var rv: Vector3 = rk
			clear = clear and (Vector2(rv.x, rv.y) - Vector2(h.tee)).length() > rv.z + 0.3 \
					and (Vector2(rv.x, rv.y) - Vector2(h.cup)).length() > rv.z + 0.3
		_check(clear, "hole %d: no water, rock or hill on the tee or the cup" % n)
	_check(Holes.hole(0) == Holes.hole(1) and Holes.hole(9) == Holes.hole(5), "a hole number outside 1 to 5 gives the nearest hole")
	_check(Holes.par_total(3) == 8 and Holes.par_total(5) == 15 and Holes.par_total(0) == 0, "the par of the first holes together")


## REQ-MG-5, 10: the power sets how far the ball rolls, the ball slows down and stops, a wall brings it back.
func _ball() -> void:
	print("ball")
	var sim := Sim.new()
	sim.start(_flat_hole(), Vector2(0.0, 1.0))
	_check(sim.finished and sim.pos == Vector2(0.0, 1.0), "a new ball stands still at its place")
	_roll(sim, 0.0, Sim.speed_for(0.0, 0.8))
	var short := sim.pos.y - 1.0
	_check(sim.finished and short > 0.2 and short < 1.0, "the weakest putt rolls a short way and the ball stops (%.2f m)" % short)
	sim.start(_flat_hole(), Vector2(0.0, 1.0))
	_roll(sim, 0.0, Sim.speed_for(0.5, 0.8))
	var mid := sim.pos.y - 1.0
	_check(mid > short, "a stronger putt rolls further (%.2f m against %.2f m)" % [mid, short])
	_check(is_equal_approx(Sim.speed_for(1.0, 0.8), Sim.SPEED_TOP) and is_equal_approx(Sim.speed_for(0.0, 0.8), 0.8)
			and is_equal_approx(Sim.speed_for(9.0, 0.8), Sim.SPEED_TOP), "the putt speed goes from the weakest to the top speed")
	sim.start(_flat_hole(), Vector2(0.0, 5.2))
	_roll(sim, 0.0, 3.0)
	_check(sim.pos.y < 5.75 and sim.pos.y > 4.0 and sim.events.size() >= 0, "a wall stops the ball from leaving the ground")
	var bounced := false
	sim.start(_flat_hole(), Vector2(0.0, 5.0))
	sim.putt(0.0, 3.0)
	while not sim.finished:
		sim.tick(DT)
		for e in sim.events:
			bounced = bounced or e.t == "wall"
	_check(bounced and sim.vel == Vector2.ZERO, "a wall is an event and the ball comes back (REQ-MG-10)")
	sim.start(_flat_hole(), Vector2(0.0, 1.0))
	_roll(sim, deg_to_rad(90.0), 4.0)
	_check(absf(sim.pos.x) <= 1.0 and sim.finished, "a sideways putt stays between the side walls")
	_check(is_equal_approx(Sim.heading_to_cup(_flat_hole(), Vector2(0.0, 1.0)), 0.0)
			and Sim.heading_to_cup(_flat_hole(), Vector2(-1.0, 5.0)) > 1.4, "the heading to the cup")


## REQ-MG-9, 10: water sends the ball back, a bridge lets it over, a block bounces it.
func _obstacles() -> void:
	print("water, bridges, blocks")
	var h := _flat_hole()
	h.water = [Rect2(-1.0, 2.8, 2.0, 0.6)]
	var wet := Sim.new()
	wet.start(h, Vector2(0.0, 1.0))
	var splash := false
	wet.putt(0.0, 3.0)
	while not wet.finished:
		wet.tick(DT)
		for e in wet.events:
			splash = splash or e.t == "water"
	_check(wet.in_water and splash and not wet.in_cup, "a ball that touches the lake stops with a splash (REQ-MG-9)")
	h.bridges = [Rect2(-0.3, 2.8, 0.6, 0.6)]
	_check(not Holes.is_water(h, Vector2(0.0, 3.0)) and Holes.is_water(h, Vector2(0.6, 3.0)),
			"a bridge is not water, the lake next to it is")
	var dry := Sim.new()
	dry.start(h, Vector2(0.0, 1.0))
	_roll(dry, 0.0, 3.0)
	_check(not dry.in_water and dry.pos.y > 3.5, "a ball that rolls over the bridge crosses the lake (REQ-MG-9)")
	h = _flat_hole()
	h.rocks = [Vector3(0.0, 3.0, 0.2)]
	var rock := Sim.new()
	rock.start(h, Vector2(0.0, 1.0))
	var bounced := false
	rock.putt(0.0, 3.0)
	while not rock.finished:
		rock.tick(DT)
		for e in rock.events:
			bounced = bounced or e.t == "rock"
	_check(bounced and rock.pos.y < 3.0, "a ball that hits a rock bounces back (REQ-MG-10)")
	h = _flat_hole()
	h.blocks = [Rect2(-0.3, 3.0, 0.6, 0.3)]
	var blocked := Sim.new()
	blocked.start(h, Vector2(0.0, 1.0))
	_roll(blocked, 0.0, 3.0)
	_check(blocked.pos.y < 3.0, "a block stops the ball (it never rolls through it)")
	_check(not Sim.walkable(h, Vector2(0.0, 3.1)) and Sim.walkable(h, Vector2(0.9, 3.1)) and not Sim.walkable(h, Vector2(5.0, 3.0)),
			"the ground is the fairway without the blocks")


## REQ-MG-6: a slow ball falls into the cup, a fast ball rolls over it.
func _cup() -> void:
	print("cup")
	var sim := Sim.new()
	sim.start(_flat_hole(), Vector2(0.0, 4.4))
	_roll(sim, 0.0, 1.0)
	_check(sim.in_cup and sim.pos == Vector2(0.0, 5.0), "a slow ball that reaches the cup falls in")
	sim.start(_flat_hole(), Vector2(0.0, 4.4))
	var in_event := false
	sim.putt(0.0, 1.0)
	while not sim.finished:
		sim.tick(DT)
		for e in sim.events:
			in_event = in_event or e.t == "cup"
	_check(in_event, "falling into the cup is an event")
	sim.start(_flat_hole(), Vector2(0.0, 4.0))
	_roll(sim, 0.0, 4.0)
	_check(not sim.in_cup, "a fast ball rolls over the cup and does not fall in")
	sim.start(_flat_hole(), Vector2(0.5, 4.4))
	_roll(sim, 0.0, 1.0)
	_check(not sim.in_cup, "a ball that misses the cup does not fall in")


## Every hole can be played in a few strokes: a simple search of putts (each one starts from the stopped ball that is nearest to
## the cup) finds the cup in at most par + 1 strokes. Hole 2 has a wall with the door of the windmill in it: there the
## search goes through the door first.
func _solvable() -> void:
	print("every hole can be played")
	for n in range(1, Holes.COUNT + 1):
		var h := Holes.hole(n)
		var best := _solve_through_the_door(h) if h.get("windmill", false) else _search(h, Vector2(h.tee), 0, int(h.par) + 1)
		_check(best > 0 and best <= int(h.par) + 1, "hole %d: the cup is reachable in %d strokes (par %d)" % [n, best, h.par])


## A hole with the door of the windmill in a wall: a putt that stops in front of the door (on the side of the tee), a putt through
## the door, then the search finds the cup. Returns the number of strokes, or 0.
func _solve_through_the_door(h: Dictionary) -> int:
	var tower: Rect2 = h.blocks[0]
	var zc := tower.get_center().y
	var cx := tower.get_center().x
	var side := 1.0 if Vector2(h.tee).x > cx else -1.0
	var aim := Vector2(cx + side * 0.7, zc)
	var sim := Sim.new()
	var tee: Vector2 = h.tee
	for speed in range(14, 34, 1):
		for deg in [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]:
			sim.start(h, tee)
			_roll(sim, Sim.heading_to_cup({"cup": aim}, tee) + deg_to_rad(deg), float(speed) * 0.1)
			if sim.in_water or absf(sim.pos.y - zc) > 0.08 or (sim.pos.x - cx) * side < 0.25:
				continue
			var from: Vector2 = sim.pos
			for sp2 in [2.6, 3.4, 1.8]:
				for i in range(-2, 3):
					sim.start(h, from)
					_roll(sim, Sim.heading_to_cup({"cup": Vector2(cx, zc)}, from) + deg_to_rad(float(i) * 3.0), sp2)
					if (sim.pos.x - cx) * side < -0.3 and not sim.in_water:
						var rest := _search(h, sim.pos, 2, int(h.par) + 1)
						if rest > 0:
							return rest
	return 0


## Returns the number of strokes of the shortest way found, or 0.
func _search(h: Dictionary, from: Vector2, used: int, limit: int) -> int:
	if used >= limit:
		return 0
	var ends: Array = []
	var sim := Sim.new()
	var base := Sim.heading_to_cup(h, from)
	for i in range(-12, 13):
		for p in [0.15, 0.3, 0.5, 0.7, 0.9]:
			sim.start(h, from)
			_roll(sim, base + deg_to_rad(float(i) * 5.0), Sim.speed_for(p, 0.8))
			if sim.in_cup:
				return used + 1
			if not sim.in_water:
				ends.append([(Vector2(h.cup) - sim.pos).length(), sim.pos])
	if used + 1 >= limit:
		return 0
	ends.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in mini(3, ends.size()):
		var r := _search(h, ends[k][1], used + 1, limit)
		if r > 0:
			return r
	return 0


func _two_players(holes: int) -> Rules:
	var r := Rules.new()
	r.setup([0, 2], holes)
	return r


## REQ-MG-2: each player putts once, in slot order, and the round repeats; a player whose ball is in is skipped.
func _turns() -> void:
	print("turns")
	var r := Rules.new()
	r.setup([0, 1, 3], 3)
	_check(r.current_slot() == 0 and r.hole_number() == 1 and r.holes == 3, "the first player putts first on the first hole")
	var order: Array[int] = []
	for i in 6:
		order.append(r.current_slot())
		r.putt_done(false)
	_check(order == [0, 1, 3, 0, 1, 3], "the turns go round in slot order")
	r = Rules.new()
	r.setup([0, 1, 3], 3)
	r.putt_done(true)
	_check(r.current_slot() == 1 and r.row_of(0).state == Rules.State.IN, "a ball that is in leaves the round")
	r.putt_done(false)
	r.putt_done(false)
	_check(r.current_slot() == 1, "the player who is in is skipped: 1, 3, 1 ...")
	var ev := r.putt_done(true)
	ev = r.putt_done(true)
	_check(ev.hole_done and r.current_slot() == -1 and r.hole_done(), "the hole is done when every ball is in")
	_check(Rules.new().current_slot() == -1 and Rules.new().putt_done(true).is_empty(), "with nobody there is no turn")
	_check(r.strokes_on_hole(0) == 1 and r.strokes_on_hole(1) == 2 and r.strokes_on_hole(3) == 2 and r.strokes_on_hole(7) == 0,
			"every putt that was played is a stroke (REQ-MG-6)")


## REQ-MG-8: after 6 strokes the ball is picked up and the hole counts 6.
func _pick_up() -> void:
	print("pick up after 6 strokes")
	var r := _two_players(1)
	var last := {}
	for i in 5:
		r.putt_done(false)   # slot 0
		last = r.putt_done(true) if i == 4 else r.putt_done(false)   # slot 2: in at its 5th stroke
	_check(last.in and last.strokes == 5 and r.current_slot() == 0, "a player who is in leaves the round, the other plays on")
	last = r.putt_done(false)
	_check(last.picked and last.strokes == Rules.MAX_STROKES and last.hole_done and not last.in,
			"the 6th stroke without a hole picks the ball up and ends the hole")
	_check(r.total(0) == 6 and r.total(2) == 5, "the picked up ball counts 6 strokes")
	_check(last.label == "", "no words for a picked up ball")


## REQ-MG-1, 7, 12: the match has 1 to 5 holes, the strokes are added up and the last hole ends the match.
func _holes_and_totals() -> void:
	print("holes and totals")
	_check(_two_players(0).holes == 1 and _two_players(9).holes == 5 and _two_players(4).holes == 4,
			"the number of holes is 1 to 5")
	var r := _two_players(2)
	r.putt_done(true)   # slot 0: 1 stroke
	r.putt_done(false)
	r.putt_done(true)   # slot 2: 2 strokes
	_check(r.hole_done() and not r.match_over() and r.total(0) == 1 and r.total(2) == 2, "a hole is done but the match is not")
	_check(r.next_hole() and r.hole_number() == 2 and r.current_slot() == 0 and r.strokes_on_hole(0) == 0,
			"the next hole starts with the first player and no strokes")
	_check(r.total(0) == 1 and r.total(2) == 2, "the strokes of the first hole stay in the total")
	r.putt_done(false)
	r.putt_done(true)   # slot 2: 1
	r.putt_done(true)   # slot 0: 2
	_check(r.hole_done() and r.match_over(), "the last hole ends the match")
	_check(not r.next_hole() and r.total(0) == 3 and r.total(2) == 3, "there is no hole after the last, and nothing changes")
	_check(r.par() == int(Holes.hole(2).par), "the par is the par of the hole that is played")
	var one := Rules.new()
	one.setup([4], 1)
	one.putt_done(true)
	_check(one.match_over() and one.total(4) == 1, "one player on one hole")


## REQ-MG-11: a player who leaves takes the strokes away and the turn goes on.
func _leaving() -> void:
	print("leaving")
	var r := Rules.new()
	r.setup([0, 1, 2], 3)
	r.putt_done(false)
	r.remove_player(1)   # it was the turn of slot 1
	_check(r.current_slot() == 2 and r.slots() == [0, 2], "when the player on turn leaves the next one putts")
	r.remove_player(0)
	_check(r.current_slot() == 2, "a player before the turn leaves: the turn stays")
	r = Rules.new()
	r.setup([0, 1, 2], 3)
	r.putt_done(true)
	r.remove_player(2)
	_check(r.current_slot() == 1, "a player after the turn leaves: the turn stays")
	r.remove_player(1)
	_check(r.hole_done() and r.current_slot() == -1, "the hole is done when the last player of it leaves")
	r.remove_player(0)
	_check(r.rows.is_empty() and r.match_over() and r.current_slot() == -1, "nobody left: the match is over")
	r.remove_player(7)
	_check(r.rows.is_empty(), "a slot that is not in the game changes nothing")
	r = Rules.new()
	r.setup([0, 1], 3)
	r.putt_done(true)
	r.remove_player(1)
	_check(r.hole_done(), "the player who is left is already in: the hole is done")


## REQ-MG-6, 14: the words of a hole and the medal tiers of one player.
func _words_and_medals() -> void:
	print("words and medals")
	_check(Rules.label_for(1, 3) == "mini_golf.hole_in_one" and Rules.label_for(1, 2) == "mini_golf.hole_in_one",
			"one stroke is a hole in one")
	_check(Rules.label_for(2, 3) == "mini_golf.birdie" and Rules.label_for(3, 4) == "mini_golf.birdie", "one under par is a birdie")
	_check(Rules.label_for(3, 3) == "mini_golf.par" and Rules.label_for(4, 3) == "mini_golf.bogey", "par and bogey")
	_check(Rules.label_for(5, 3) == "" and Rules.label_for(6, 3) == "", "two over par or more has no words, only the number")
	var r := Rules.new()
	r.setup([0], 2)
	var ev := r.putt_done(true)
	_check(ev.label == "mini_golf.hole_in_one", "a hole in one is said")


# ---- Added for the automated half of Manual test 26 ----

## Rolls a ball from `from` at `speed` towards `target` for at most `seconds`. Returns
## `{events, off}`: the types of the events in order, and whether the ball was ever off the ground (outside the fairway or in
## a block).
func _shoot(h: Dictionary, from: Vector2, target: Vector2, speed: float, seconds := 4.0) -> Dictionary:
	var sim := Sim.new()
	sim.start(h, from)
	var d := target - from
	sim.putt(atan2(d.x, d.y), speed)
	var types: Array = []
	var off := false
	var t := 0.0
	while not sim.finished and t < seconds:
		sim.tick(DT)
		t += DT
		for e in sim.events:
			types.append(e.t)
		off = off or not Sim.walkable(h, sim.pos)
	return {"events": types, "off": off}


## Four starting places around `centre`, `dist` away on each side.
func _around(centre: Vector2, dist: float) -> Array:
	return [centre + Vector2(0, -dist), centre + Vector2(0, dist), centre + Vector2(-dist, 0), centre + Vector2(dist, 0)]


## REQ-MG-10: a rock and the windmill tower bounce the ball and it stays on the ground, on each hole.
func _things_bounce() -> void:
	print("rocks and the windmill on every hole")
	var rock_holes: Array = []
	var windmill_holes: Array = []
	for n in range(1, Holes.COUNT + 1):
		var h := Holes.hole(n)
		var all_off := false
		for rk in h.rocks:
			var rv: Vector3 = rk
			var bounced := false
			for from in _around(Vector2(rv.x, rv.y), rv.z + 0.45):
				if not Sim.walkable(h, from):
					continue
				var r := _shoot(h, from, Vector2(rv.x, rv.y), 2.5)
				all_off = all_off or r.off
				bounced = bounced or (r.events.size() > 0 and r.events[0] == "rock")
			_check(bounced, "hole %d: a ball shot at the rock at (%.2f, %.2f) bounces from it" % [n, rv.x, rv.y])
			rock_holes.append(n)
		var solid := Holes.solid_blocks(h)
		if h.get("windmill", false):   # The tower is two pillars with a door between them.
			var bounced2 := false
			var windmill_pieces: Array[Rect2] = [solid[0], solid[1]]
			for blk in windmill_pieces:
				var centre := blk.get_center()
				for from in _around(centre, maxf(blk.size.x, blk.size.y) * 0.5 + 0.4):
					if not Sim.walkable(h, from):
						continue
					var r2 := _shoot(h, from, centre, 2.5)
					all_off = all_off or r2.off
					bounced2 = bounced2 or (r2.events.size() > 0 and r2.events[0] == "wall")
			_check(bounced2, "hole %d: a ball shot at a pillar of the windmill bounces from it" % n)
			windmill_holes.append(n)
		_check(not all_off, "hole %d: the ball never leaves the ground or enters a block" % n)
	_check(windmill_holes == [2], "the windmill is on hole 2 only (there are no brick walls, sliding barriers or blades any more)")
	_check(rock_holes.size() == 6, "the holes have 6 rocks in all (%d)" % rock_holes.size())


## TEMP-DEBUG (remove with `Rules.debug_jump_to_hole()`): the jump to a hole for testing.
func _debug_jump() -> void:
	print("temporary: jump to a hole")
	var r := _two_players(3)
	r.debug_jump_to_hole(4)
	_check(r.hole_number() == 4 and r.holes == Holes.COUNT and r.strokes_on_hole(0) == 0 and r.total(0) == 0
			and r.current_slot() == 0, "TEMP-DEBUG: a jump to hole 4 starts hole 4 of 5 with no strokes")
	r.debug_jump_to_hole(99)
	_check(r.hole_number() == Holes.COUNT, "TEMP-DEBUG: a jump past the last hole goes to the last hole")


## REQ-MG-10 (owner, 2026-11-05: a rock was hit wrong and the ball could get stuck near it): a rock never leaves a pinch against a
## wall that a ball can wedge in (the free lane is 0.15 m or more on each side), and a ball shot at a rock from any side, hard or
## soft, straight or off the middle, ends on the ground and outside the rock.
func _rocks_do_not_trap() -> void:
	print("rocks do not trap the ball")
	for n in range(1, Holes.COUNT + 1):
		var h := Holes.hole(n)
		for rk in h.rocks:
			var rv: Vector3 = rk
			var c := Vector2(rv.x, rv.y)
			var reach := rv.z + Holes.BALL_R
			var narrowest := 99.0
			for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var d := reach
				while d < 3.0 and Sim.walkable(h, c + dir * d):
					d += 0.005
				narrowest = minf(narrowest, d - reach if d < 3.0 else 99.0)
			_check(narrowest >= 0.15, "hole %d: the rock at (%.2f, %.2f) leaves a lane of %.2f m beside it, at least 0.15 m"
					% [n, rv.x, rv.y, narrowest])
			var bad := 0
			var shots := 0
			for k in 24:
				var a := TAU * float(k) / 24.0
				var from := c + Vector2(cos(a), sin(a)) * (reach + 0.3)
				if not Sim.walkable(h, from):
					continue
				for off in [-0.08, 0.0, 0.08]:
					for speed in [0.8, 2.5]:
						var sim := Sim.new()
						sim.start(h, from)
						var aim: Vector2 = c + Vector2(-sin(a), cos(a)) * off - from
						_roll(sim, atan2(aim.x, aim.y), speed)
						shots += 1
						if not sim.finished or not Sim.walkable(h, sim.pos) or (sim.pos - c).length() < reach - 0.001:
							bad += 1
			_check(shots > 0 and bad == 0, "hole %d: %d shots at the rock end on the ground and outside it (%d did not)" % [n, shots, bad])


## REQ-MG-10, 12: the tower of a windmill has a door that the ball goes through; the tower is two pillars on both sides of it, and
## on hole 2 the door is the only way into the far row (owner, 2026-11-04).
func _windmill_door() -> void:
	print("the door of the windmill")
	for n in [2]:
		var h := Holes.hole(n)
		var tower: Rect2 = h.blocks[0]
		var door: float = h.get("door", 0.3)
		var solid := Holes.solid_blocks(h)
		_check(h.get("windmill", false) and solid.size() == h.blocks.size() + 1
				and is_equal_approx(solid[0].size.y + solid[1].size.y + door, tower.size.y)
				and is_equal_approx(solid[0].end.y + door, solid[1].position.y),
				"hole %d: the tower is two pillars with a door of %.2f m in the middle" % [n, door])
		var zc := tower.get_center().y
		_check(not Sim.walkable(h, Vector2(tower.get_center().x, tower.position.y + 0.02))
				and Sim.walkable(h, Vector2(tower.get_center().x, zc)),
				"hole %d: the ball can stand in the door, not in a pillar" % n)
	# Hole 2: a ball shot up the screen (heading -90 degrees) through the door gets into the far row; beside it, it does not.
	var h2 := Holes.hole(2)
	var zd: float = Rect2(h2.blocks[0]).get_center().y
	var through := Sim.new()
	through.start(h2, Vector2(0.6, zd))
	through.putt(-PI * 0.5, 3.0)
	var crossed := false
	while not through.finished:
		through.tick(DT)
		crossed = crossed or through.pos.x < -0.3
	_check(crossed and not through.in_water, "hole 2: a ball shot straight at the door goes through it into the far row")
	var beside := Sim.new()
	beside.start(h2, Vector2(0.6, zd - 0.6))
	beside.putt(-PI * 0.5, 3.0)
	var got_in := false
	while not beside.finished:
		beside.tick(DT)
		got_in = got_in or beside.pos.x < 0.0
	_check(not got_in, "hole 2: a ball shot up beside the door stays in the near row (the wall stops it)")
	_check(Sim.walkable(h2, h2.cup) and Vector2(h2.cup).x < -0.13 and Vector2(h2.tee).x > 0.13,
			"hole 2: the tee is in the near row and the cup in the far row")


## REQ-MG-10: a hill is a bump across the whole width: a soft putt does not get over it and rolls back, a strong one does and
## speeds up again on the way down (owner, 2026-11-04).
func _hills() -> void:
	print("hills")
	var h := _flat_hole()
	h.hills = [{"rect": Rect2(-1.0, 2.0, 2.0, 1.0), "height": 0.12}]
	_check(is_zero_approx(Holes.hill_height(h, Vector2(0.0, 1.9))) and absf(Holes.hill_height(h, Vector2(0.0, 2.5)) - 0.12) < 0.001
			and is_zero_approx(Holes.hill_height(h, Vector2(0.0, 3.1))),
			"the hill is 0.12 m high in the middle and flat outside")
	_check(Holes.hill_slope(h, Vector2(0.0, 2.25)) > 0.2 and Holes.hill_slope(h, Vector2(0.0, 2.75)) < -0.2
			and absf(Holes.hill_slope(h, Vector2(0.0, 2.5))) < 0.001, "it rises, is level at the top and falls")
	var soft := Sim.new()
	soft.start(h, Vector2(0.0, 1.2))
	_roll(soft, 0.0, 1.2)
	_check(soft.finished and soft.pos.y < 2.5, "a soft putt (1.2 m/s) does not get over the hill (stops at z %.2f)" % soft.pos.y)
	var rolled_back := Sim.new()
	rolled_back.start(h, Vector2(0.0, 1.2))
	rolled_back.putt(0.0, 1.5)
	var top := 0.0
	var back := false
	while not rolled_back.finished:
		rolled_back.tick(DT)
		top = maxf(top, rolled_back.pos.y)
		back = back or (top > 2.0 and rolled_back.vel.y < -0.05)
	_check(back and rolled_back.pos.y < top - 0.05,
			"a putt that does not make it rolls back down the hill (the top %.2f, the end %.2f)" % [top, rolled_back.pos.y])
	var strong := Sim.new()
	strong.start(h, Vector2(0.0, 1.2))
	_roll(strong, 0.0, 3.5)
	_check(strong.pos.y > 3.1, "a strong putt (3.5 m/s) gets over the hill (stops at z %.2f)" % strong.pos.y)
	var speeds: Array = []
	for hole_data in [h, _flat_hole()]:
		var run := Sim.new()
		run.start(hole_data, Vector2(0.0, 1.2))
		run.putt(0.0, 3.5)
		var at := -1.0
		while not run.finished and at < 0.0:
			run.tick(DT)
			if run.pos.y > 2.5:
				at = run.vel.length()
		speeds.append(at)
	_check(speeds[0] > 0.0 and speeds[0] < speeds[1] - 0.3,
			"a putt is slower on the top of the hill (%.2f m/s at z 2.5, against %.2f m/s on flat ground)" % [speeds[0], speeds[1]])
	# A ramp up to a platform and a slide down (hole 4).
	var hs := _flat_hole()
	hs.hills = [{"rect": Rect2(-1.0, 2.0, 2.0, 1.0), "height": 0.14, "kind": "slide"}]
	_check(is_zero_approx(Holes.hill_height(hs, Vector2(0.0, 2.0))) and absf(Holes.hill_height(hs, Vector2(0.0, 2.5)) - 0.14) < 0.001
			and Holes.hill_height(hs, Vector2(0.0, 2.999)) < 0.01,
			"the slide is 0.14 m high on the platform and 0 at both ends")
	_check(Holes.hill_slope(hs, Vector2(0.0, 2.2)) > 0.2 and is_zero_approx(Holes.hill_slope(hs, Vector2(0.0, 2.5)))
			and Holes.hill_slope(hs, Vector2(0.0, 2.8)) < -0.2, "it rises on the ramp, is level on the platform and falls on the slide")
	var weak_slide := Sim.new()
	weak_slide.start(hs, Vector2(0.0, 1.2))
	_roll(weak_slide, 0.0, 1.5)
	_check(weak_slide.pos.y < 2.5, "a soft putt (1.5 m/s) does not get up the ramp (stops at z %.2f)" % weak_slide.pos.y)
	var strong_slide := Sim.new()
	strong_slide.start(hs, Vector2(0.0, 1.2))
	_roll(strong_slide, 0.0, 3.5)
	_check(strong_slide.pos.y > 3.0, "a strong putt (3.5 m/s) goes up the ramp, over the platform and down the slide (z %.2f)"
			% strong_slide.pos.y)
	for n in range(1, Holes.COUNT + 1):
		var hh := Holes.hole(n)
		_check(is_zero_approx(Holes.hill_height(hh, hh.tee)) and is_zero_approx(Holes.hill_height(hh, hh.cup)),
				"hole %d: the tee and the cup are not on a hill" % n)


## REQ-MG-12, 6: the par of each hole, and the words of the holes that are not covered above.
func _pars() -> void:
	print("pars and words")
	var pars: Array = []
	for n in range(1, Holes.COUNT + 1):
		pars.append(int(Holes.hole(n).par))
	_check(pars == [2, 3, 3, 3, 4], "the five holes have the pars 2, 3, 3, 3 and 4 (8a)")
	_check(Rules.label_for(2, 2) == "mini_golf.par" and Rules.label_for(3, 2) == "mini_golf.bogey" and Rules.label_for(4, 2) == ""
			and Rules.label_for(2, 4) == "mini_golf.birdie" and Rules.label_for(4, 4) == "mini_golf.par"
			and Rules.label_for(5, 4) == "mini_golf.bogey" and Rules.label_for(6, 4) == "",
			"the words fit the par of the hole: par 2, par 4")


## REQ-GM-47l (issue #346): the ball and the aim mark are drawn on the grid of world pixels (4 units), so that they do not
## shimmer between two pixels while they move.
func _grid() -> void:
	print("pixel grid")
	var ci := Node2D.new()
	var hole: Dictionary = Holes.hole(1)
	var geo := Look.Geo.new(Vector2(1920.0, 1080.0), hole)
	var centers: Array[Vector2] = []
	Shell.recorder = func(kind: String, _ci: CanvasItem, rect: Rect2, _info: Dictionary) -> void:
		# The middle of the ball and of the tip of the aim mark, from the box each one records.
		if kind == "ball" or kind == "aim":
			centers.append(rect.get_center())
	ci.draw.connect(func() -> void:
		for i in 12:
			var p := Vector2(-0.5 + 0.037 * float(i), 2.0 + 0.0113 * float(i))
			Look.draw_ball(ci, geo, geo.at(p), 0)
			Look.draw_aim(ci, geo, hole, p, 0.3, 1.0, false))
	root.add_child(ci)
	await process_frame
	Shell.recorder = Callable()
	var off := 0
	for f in centers:
		if absf(f.x - snappedf(f.x, 4.0)) > 0.001 or absf(f.y - snappedf(f.y, 4.0)) > 0.001:
			off += 1
	ci.queue_free()
	_check(centers.size() == 24 and off == 0,
			"the ball and the aim mark stand on the 4-unit grid (%d of %d off)" % [off, centers.size()])
