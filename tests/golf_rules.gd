extends SceneTree
## The rules of Mini Golf without a screen: the holes, the ball, the turns, the strokes, the pick-up and the medals
## (docs/games/mini_golf.md, REQ-MG-1 to 14). Run: godot --headless --path . --script tests/golf_rules.gd -- --role=controller

const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")
const Sim = preload("res://scripts/game/mini_golf/golf_sim.gd")
const Rules = preload("res://scripts/game/mini_golf/golf_rules.gd")

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
			"water": [], "bridges": [], "bumpers": [], "blocks": []}


## REQ-MG-12: five holes with a par of 2 to 4, and a tee and a cup on the ground, away from the things on the course.
func _holes() -> void:
	print("holes")
	_check(Holes.COUNT == 5, "the game has 5 holes")
	for n in range(1, Holes.COUNT + 1):
		var h := Holes.hole(n)
		_check(int(h.par) >= 2 and int(h.par) <= 4, "hole %d has a par of 2 to 4" % n)
		_check(Sim.walkable(h, h.tee) and Sim.walkable(h, h.cup), "hole %d: the tee and the cup are on the ground" % n)
		var clear := not Holes.is_water(h, h.tee) and not Holes.is_water(h, h.cup)
		for b in h.bumpers:
			var bv: Vector3 = b
			clear = clear and (Vector2(bv.x, bv.y) - Vector2(h.tee)).length() > bv.z + 0.3 \
					and (Vector2(bv.x, bv.y) - Vector2(h.cup)).length() > bv.z + 0.3
		_check(clear, "hole %d: no water or bumper on the tee or the cup" % n)
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


## REQ-MG-9, 10: water sends the ball back, a bridge lets it over, a bumper and a block bounce it.
func _obstacles() -> void:
	print("water, bridges, bumpers")
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
	h.bumpers = [Vector3(0.0, 3.0, 0.2)]
	var bump := Sim.new()
	bump.start(h, Vector2(0.0, 1.0))
	var hit := false
	var back := false
	bump.putt(0.0, 3.0)
	while not bump.finished:
		bump.tick(DT)
		hit = hit or not bump.events.filter(func(e: Dictionary) -> bool: return e.t == "bumper").is_empty()
		back = back or bump.vel.y < -0.1
	_check(hit and back, "a bumper bounces the ball back (REQ-MG-10)")
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
## the cup) finds the cup in at most par + 1 strokes.
func _solvable() -> void:
	print("every hole can be played")
	for n in range(1, Holes.COUNT + 1):
		var h := Holes.hole(n)
		var best := _search(h, Vector2(h.tee), 0, int(h.par) + 1)
		_check(best > 0 and best <= int(h.par) + 1, "hole %d: the cup is reachable in %d strokes (par %d)" % [n, best, h.par])


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
	_check(r.total(0) == 1 and r.done_total(2) == 2, "the strokes of the first hole stay in the total")
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
	_check(Rules.tiers(3) == [14, 11, 8] and Rules.tiers(1) == [4, 3, 2] and Rules.tiers(5) == [25, 20, 15],
			"the medal tiers come from the par: gold at par, silver 1 over a hole, bronze 2 over a hole")
	for n in range(1, Holes.COUNT + 1):
		_check(_medals_valid(Rules.tiers(n)), "the tiers of %d holes are valid (each one is harder)" % n)


func _medals_valid(t: Array) -> bool:
	return t.size() == 3 and float(t[2]) < float(t[1]) and float(t[1]) < float(t[0])
