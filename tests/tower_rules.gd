extends SceneTree
## The rules of Tower Builder without a screen: where a brick lands, which bricks fall, the turn time and the pictures'
## numbers (docs/games/tower_builder.md, REQ-TB-5 to 11). Run:
##   godot --headless --path . --script tests/tower_rules.gd -- --role=controller

const Stack = preload("res://scripts/game/tower_builder/tower_stack.gd")
var Look: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).

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
	Look = load("res://scripts/game/tower_builder/tower_look.gd")
	_landing()
	_toppling()
	_widths()
	_game_numbers()
	_look()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## REQ-TB-6: a brick lands on the top brick when they overlap enough, or it misses and the tower is the same.
func _landing() -> void:
	print("landing")
	var s := Stack.new()
	_check(s.height() == 0 and s.lands(Stack.BASE_X, 200.0), "an empty tower: a brick over the base lands")
	_check(not s.lands(Stack.BASE_X + Stack.BASE_W * 0.5 + 100.0 + 50.0, 200.0), "a brick far beside the base misses it")
	var r := s.drop(Stack.BASE_X, 200.0, 0)
	_check(r.outcome == Stack.Outcome.SAFE and s.height() == 1 and r.level == 0, "the first brick stays at level 0 (SAFE)")
	var edge := Stack.BASE_X + 200.0 - Stack.MIN_OVERLAP   # The middle where two bricks of 200 overlap by exactly MIN_OVERLAP.
	_check(not s.lands(edge, 200.0) and s.lands(edge - 1.0, 200.0),
			"the overlap needed is MIN_OVERLAP: 1 px more lands, none less does not")
	var miss := s.drop(Stack.BASE_X + 350.0, 200.0, 1)
	_check(miss.outcome == Stack.Outcome.MISS and miss.fallen.is_empty() and s.height() == 1,
			"a miss changes nothing in the tower and has nothing that falls")
	_check(Stack.level_top(0) == Stack.GROUND_Y - Stack.BRICK_H and Stack.level_top(2) == Stack.GROUND_Y - 3.0 * Stack.BRICK_H,
			"level 0 sits on the base and each level is one brick higher")


## REQ-TB-7 to 9: a joint that does not hold drops everything above it, also the bricks of earlier turns.
func _toppling() -> void:
	print("toppling")
	var s := Stack.new()
	for i in 4:
		s.drop(Stack.BASE_X, 200.0, i % 2)
	_check(s.height() == 4 and s.weak_joint() == 4, "four bricks in a straight line stand")
	var r := s.drop(Stack.BASE_X + 90.0, 200.0, 2)
	_check(r.outcome == Stack.Outcome.SAFE and s.height() == 5,
			"a brick 90 px to the side with its middle over the brick below stays (the middle is over the support)")
	var t := Stack.new()
	t.drop(Stack.BASE_X, 200.0, 0)
	t.drop(Stack.BASE_X + 90.0, 200.0, 1)
	_check(t.height() == 2 and t.weak_joint() == 2, "two bricks, the second 90 px to the side, stand")
	var top := t.drop(Stack.BASE_X + 180.0, 200.0, 2)
	_check(top.outcome == Stack.Outcome.TOPPLED, "bricks that lean further and further out make the tower topple")
	_check(top.fallen.size() == 2 and t.height() == 1,
			"one brick can knock off another: the brick of the earlier turn falls together with the new one (REQ-TB-9)")
	_check(int(top.fallen[-1].slot) == 2 and int(top.fallen[0].slot) == 1 and int(top.level) == 1,
			"the new brick is the last of the fallen, and `level` is the level of the lowest brick that fell")
	_check(t.weak_joint() == t.height(), "the bricks that are left stand again")
	var u := Stack.new()
	u.drop(Stack.BASE_X, 200.0, 0)
	var big := u.drop(Stack.BASE_X + 170.0, 200.0, 1)
	_check(big.outcome == Stack.Outcome.TOPPLED and u.height() == 1,
			"a brick with its middle beyond the SLACK past the edge of the brick below falls, and the first brick stays")
	var slack := Stack.new()
	slack.drop(Stack.BASE_X, 200.0, 0)
	_check(slack.drop(Stack.BASE_X + 100.0 + Stack.SLACK - 1.0, 200.0, 1).outcome == Stack.Outcome.SAFE,
			"a brick with its middle at the edge plus the SLACK stays (REQ-TB-8)")
	# Test 30 step 4c: bricks dropped near the middle of the top brick (up to 20 px off, to one side or alternating) never topple.
	for pattern in ["right", "alternating", "left"]:
		var careful := Stack.new()
		var topples := 0
		var x := Stack.BASE_X
		for i in 10:
			var off := 20.0 if pattern == "right" else (-20.0 if pattern == "left" else (20.0 if i % 2 == 0 else -20.0))
			if careful.height() > 0:
				x = float(careful.bricks[careful.height() - 1].x) + off
			if careful.drop(x, 200.0, i % 3).outcome == Stack.Outcome.TOPPLED:
				topples += 1
		_check(topples == 0 and careful.height() == 10,
					"10 bricks dropped up to 20 px off the middle of the top brick (%s): no topple (%d)" % [pattern, topples])
	var lone := Stack.new()
	lone.drop(Stack.BASE_X, 200.0, 0)
	lone.clear()
	_check(lone.height() == 0, "clear() empties the tower")


## The widths come from nine sizes and a seed gives the same bricks every time (REQ-TB-10).
func _widths() -> void:
	print("widths")
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 7
	b.seed = 7
	var same := true
	var inside := true
	for i in 40:
		var w := Stack.next_width(a)
		same = same and w == Stack.next_width(b)
		inside = inside and w >= Stack.WIDTH_MIN and w <= Stack.WIDTH_MIN + Stack.WIDTH_STEP * Stack.WIDTH_STEPS
	_check(same and inside, "a seed gives the same widths, all between 170 and 250 px")


## REQ-TB-11, 15: 10 s, 5 s and 3 s a turn.
func _game_numbers() -> void:
	print("game numbers")
	_check(Stack.turn_time("easy") == 10.0 and Stack.turn_time("medium") == 5.0 and Stack.turn_time("hard") == 3.0
			and Stack.turn_time("nonsense") == 5.0,
			"the turn time is 10 s on Easy, 5 s on Medium and 3 s on Hard (an unknown value is Medium)")
	var lo := 1.0e9
	var hi := -1.0e9
	for i in 240:
		var x := Stack.swing_x(float(i) * Stack.SWING_PERIOD / 240.0, 0.7)
		lo = minf(lo, x)
		hi = maxf(hi, x)
	_check(lo > Stack.BASE_X - Stack.SWING_AMP - 1.0 and hi < Stack.BASE_X + Stack.SWING_AMP + 1.0
			and hi - lo > 1.9 * Stack.SWING_AMP, "the brick on the crane swings over the whole width of +-380 px around the tower")
	_check(is_equal_approx(Stack.swing_x(0.0, 0.7), Stack.swing_x(Stack.SWING_PERIOD, 0.7)), "one swing takes SWING_PERIOD seconds")


## The tower fits on the screen under the crane, and the swing stays over the tower (REQ-TB-5).
func _look() -> void:
	print("look")
	var top := Stack.level_top(Stack.TOTAL_BRICKS - 1)
	_check(top > Look.HANG_Y + Stack.BRICK_H * 0.5 + 24.0, "a tower of 12 bricks is lower than the brick on the crane")
	_check(Stack.BASE_X - Stack.SWING_AMP - 125.0 > 60.0 and Stack.BASE_X + Stack.SWING_AMP + 125.0 < Look.RULER_X - 60.0,
			"the swinging brick stays inside the screen margin and left of the ruler")
	var heights: Array[float] = []
	for x in [0.0, 400.0, 900.0, 1500.0]:
		heights.append(Look.mountain_height(x))
	var lowest: float = heights.min()
	var highest: float = heights.max()
	_check(lowest >= 220.0 and highest <= 350.0 and highest > lowest and Look.hill_height(0.0) > 0.0,
			"the mountains are 220 to 350 px high and not flat: they stay under the crane and above the grass")
