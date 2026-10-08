extends SceneTree
## Helpers shared by the minigames: RoundClock (REQ-GM-35), Haptics (REQ-GM-43) and the chip order (REQ-GM-46).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/game_helpers.gd -- --role=controller

const Shell = preload("res://scripts/game/shell.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")

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
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _round_clock() -> void:
	print("round clock")
	var clock_script: GDScript = load("res://scripts/game/round_clock.gd")
	var c = clock_script.new()
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
	var short = clock_script.new(1.0)
	_check(short.tick(1.0) and short.is_playing() and short.time == 0.0, "a countdown of 1 s ends after 1 s")
	var frames = clock_script.new()
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
