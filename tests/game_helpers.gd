extends SceneTree
## Helpers shared by the minigames: RoundClock (REQ-GM-35, 71), Haptics (REQ-GM-43), the chip order (REQ-GM-46),
## Scoreboard (REQ-GM-70, 72) and Medals (REQ-GM-73).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/game_helpers.gd -- --role=controller

const Shell = preload("res://scripts/game/shell.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")

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
	_round_clock()
	_haptics()
	_shell_order()
	_shell_layout()
	_round_length()
	_scoreboard()
	_medals()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## A plain array copy, so that a typed Array[int] can be compared with a literal.
func _ints(a: Array) -> Array:
	return a.map(func(x): return x)


func _round_clock() -> void:
	print("round clock")
	var c = RoundClock.new()
	_check(c.is_counting() and not c.is_playing() and c.count_number() == 3, "a new clock counts down from 3 (REQ-GM-35)")
	_check(not c.tick(0.5) and c.count_number() == 3 and is_equal_approx(c.count_elapsed(), 0.5),
			"after 0.5 s the number is still 3 and half a second old")
	c.tick(0.6)
	_check(c.count_number() == 2 and is_equal_approx(c.count_elapsed(), 0.1), "after 1.1 s the number is 2")
	_check(not c.tick(1.0) and c.count_number() == 1, "after 2.1 s the number is 1")
	var started: bool = c.tick(1.0)
	_check(started and c.is_playing() and c.count_number() == 0 and is_equal_approx(c.time, 0.1),
			"the tick that ends the countdown says so, and keeps the overshoot (%.2f)" % c.time)
	_check(not c.tick(1.0) and is_equal_approx(c.time, 1.1), "later ticks add time and do not say it again")
	var short = RoundClock.new(1.0)
	_check(short.tick(1.0) and short.is_playing() and short.time == 0.0, "a countdown of 1 s ends after 1 s")
	var frames = RoundClock.new()
	var ends := 0
	for i in 400:
		if frames.tick(1.0 / 60.0):
			ends += 1
	_check(ends == 1 and frames.is_playing(), "the countdown ends once at 60 fps")


func _haptics() -> void:
	print("haptics cool-down")
	var h = load("res://scripts/game/haptics.gd").new()
	_check(h.allow(0, 150, 1000), "the first pulse of a slot is allowed")
	_check(not h.allow(0, 150, 1100), "a second pulse 100 ms later waits for the 150 ms cool-down")
	_check(h.allow(0, 150, 1150), "a pulse 150 ms after the first is allowed")
	_check(h.allow(1, 150, 1160), "the cool-down of one slot does not block another slot")
	_check(not h.allow(0, 150, 1200), "a refused pulse is not noted: 50 ms after the pulse at 1150 is too early")
	_check(h.allow(0, 150, 1300), "and 150 ms after the pulse at 1150 is allowed")


func _shell_order() -> void:
	print("chips in slot order")
	var players: Array = []
	for slot in [2, 0, 3, 1]:
		players.append(PlayerInput.new(slot, {}))
	var slots: Array = Shell.in_slot_order(players).map(func(p): return p.slot)
	_check(slots == [0, 1, 2, 3], "the chips are in slot order, P1 first (REQ-GM-46): %s" % str(slots))
	_check(players[0].slot == 2, "the order is a copy: the list of the caller stays as it was")
	_check(Shell.in_slot_order([]).is_empty(), "no players, no chips")


func _shell_layout() -> void:
	print("chip and ball layout")
	var edge_ok := true
	var inside_ok := true
	for w in [1920.0, 1280.0]:
		for n in [1, 2, 3, 4]:
			var spots: Array = Shell.chip_positions(w, n)
			if not is_equal_approx(spots[n - 1].x + 250.0, w - 60.0):
				edge_ok = false
			if spots[0].x < 60.0:
				inside_ok = false
	_check(edge_ok, "the last chip ends at the 60 px safe margin on 1920 and 1280 wide screens (REQ-GM-40)")
	_check(inside_ok, "4 chips fit inside the left margin too")
	var four: Array = Shell.chip_positions(1920.0, 4)
	_check(four.size() == 4 and is_equal_approx(four[1].x - four[0].x, 270.0) and four[0].y == 36.0 and four[3].x > four[0].x,
			"chips go left to right, 270 px apart, in one row")
	_check(Shell.chip_positions(1920.0, 0).is_empty(), "no players, no chip")
	_check(Shell.ball_metrics(24.0).outline == 6.0 and Shell.ball_metrics(20.0).outline == 6.0
			and Shell.ball_metrics(19.0).outline == 4.0, "a ball of 40 px or more has a 6 px outline, a smaller one 4 px (REQ-GM-47b)")
	var m: Dictionary = Shell.ball_metrics(24.0)
	_check(m.font_size == 26 and is_equal_approx(m.baseline, 9.0) and is_equal_approx(m.shine_radius, 6.0)
			and m.shine_offset.x < 0.0 and m.shine_offset.y < 0.0,
			"the slot number is 26 px at radius 24, and the shine is at the top left")


func _round_length() -> void:
	print("round length")
	var c = RoundClock.new(3.0, 45.0)
	_check(is_equal_approx(c.remaining(), 45.0) and not c.is_time_up(), "during the countdown the whole length is left")
	c.tick(3.0)
	c.tick(10.0)
	_check(is_equal_approx(c.remaining(), 35.0) and not c.is_time_up(), "10 s of play leave 35 s")
	c.tick(34.9)
	_check(not c.is_time_up() and c.remaining() > 0.0, "just before the end the time is not up")
	c.tick(0.2)
	_check(c.is_time_up() and c.remaining() == 0.0, "the time is up after 45 s and nothing is left")
	var open_clock = RoundClock.new()
	open_clock.tick(100.0)
	_check(not open_clock.is_time_up() and open_clock.remaining() == 0.0, "a round without a length never ends by time")


func _scoreboard() -> void:
	print("scoreboard")
	var board_script: GDScript = load("res://scripts/game/scoreboard.gd")
	var b = board_script.new([2, 0, 1])
	_check(b.size() == 3 and b.score(1) == 0.0 and b.winners().size() == 3, "all players start at 0 and tie for first place")
	b.add(0, 5)
	b.add(0, 2.5)
	b.set_score(2, 7.5)
	b.add(1, 3)
	var r: Array = b.ranking()
	_check(r.map(func(e): return e.slot) == [0, 2, 1] and r.map(func(e): return e.rank) == [1, 1, 3],
			"7.5 and 7.5 share the first place and the next player is third: %s" % str(r))
	_check(_ints(b.winners()) == [0, 2], "a tie has two winners, in slot order")
	b.remove(0)
	_check(_ints(b.winners()) == [2] and b.size() == 2 and not b.has(0), "a player who leaves is not ranked any more")
	_check(b.score(0) == 0.0, "the score of an unknown slot is 0")
	var times = board_script.new([0, 1, 2], true)
	times.set_score(0, 31.2)
	times.set_score(1, 28.9)
	times.set_score(2, 40.0)
	_check(times.ranking().map(func(e): return e.slot) == [1, 0, 2] and _ints(times.winners()) == [1],
			"with lower_is_better the smallest time wins")
	var race = board_script.new([0, 1, 2, 3], true)
	race.set_score(2, 61.5)
	race.set_unfinished(0, 120.0)
	race.set_unfinished(1, 250.0)
	race.set_unfinished(3, 120.0)
	var rr: Array = race.ranking()
	_check(rr.map(func(e): return e.slot) == [2, 1, 0, 3] and rr.map(func(e): return e.rank) == [1, 2, 3, 3]
			and rr.map(func(e): return e.finished) == [true, false, false, false],
			"unfinished players rank after the finished one, the furthest first, equal progress shares a rank: %s" % str(rr))
	_check(_ints(race.winners()) == [2] and race.is_finished(2) and not race.is_finished(1) and race.size() == 4,
			"only a player with a score can win")
	race.set_score(1, 70.0)
	race.remove(0)
	_check(race.is_finished(1) and not race.has(0) and race.size() == 3, "set_score finishes a player, remove deletes either kind")
	var nobody = board_script.new([0, 1])
	nobody.set_unfinished(0, 1.0)
	nobody.set_unfinished(1, 2.0)
	_check(nobody.winners().is_empty() and nobody.ranking()[0].slot == 1 and nobody.ranking()[0].rank == 1,
			"nobody has a score: no winner, but the furthest player is listed first")
	var empty = board_script.new()
	_check(empty.ranking().is_empty() and empty.winners().is_empty(), "no player, no ranking")
	_check([1, 2, 3, 4].map(func(n): return board_script.ordinal(n)) == ["1st", "2nd", "3rd", "4th"], "ordinals")
	_check(board_script.ordinal(0) == "1st" and board_script.ordinal(9) == "4th", "an ordinal outside 1 to 4 stays in range")
	_check(board_script.format(12.0) == "12" and board_script.format(12.5) == "12.5", "a whole score has no decimals")


func _medals() -> void:
	print("medals")
	var medals: GDScript = load("res://scripts/game/medals.gd")
	var tiers := [10, 20, 30]
	_check(medals.medal(9, tiers) == "" and medals.medal(10, tiers) == "bronze" and medals.medal(25, tiers) == "silver"
			and medals.medal(30, tiers) == "gold" and medals.medal(99, tiers) == "gold",
			"a score at the limit or better earns the medal of that tier")
	var fast := [40.0, 30.0, 20.0]
	_check(medals.medal(45.0, fast, true) == "" and medals.medal(40.0, fast, true) == "bronze"
			and medals.medal(19.9, fast, true) == "gold", "with lower_is_better a smaller time earns more")
	_check(medals.is_valid(tiers) and medals.is_valid(fast, true), "tiers that get harder are valid")
	_check(not medals.is_valid([10, 10, 30]) and not medals.is_valid([30, 20, 10]) and not medals.is_valid([10, 20]),
			"equal, backward or missing tiers are not valid")
	_check(not medals.is_valid(tiers, true), "tiers that get easier are not valid for a time")
	_check(medals.label("gold") == "Gold medal!" and medals.label("") == "No medal this time", "the text of a medal")
