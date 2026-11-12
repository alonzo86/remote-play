extends SceneTree
## ROBO on Easy and its own goals (REQ-AH-17; Test 27 step 6b; issue #431, closed as a duplicate of #146 and #147). The step plays
## 5 matches to 5 goals on Easy against ROBO; the R6 note "the player scored 1 goal and then ROBO scored 4 own goals" was made
## before the fix of #146 and #147. An own goal is ROBO's mallet hitting the puck toward its own goal at 150 px/s or more and
## the puck going in. Against a player who stands still ROBO scores no own goal. Against a player that chases the puck (the
## proxy of REQ-AH-17) it scores some by deflection: the limit is 10% of the goals of the 5 matches (2 of 39 today). A stronger
## chaser (Medium) is printed only: a hard shot against a defending ROBO is a lost defense, not a mistake of the bot.
## Run: godot --headless --path . --script tests/hockey_robo_own_goals.gd -- --role=tv

const Sim = preload("res://scripts/game/air_hockey/air_hockey_sim.gd")
const HockeyBot = preload("res://scripts/game/air_hockey/hockey_bot.gd")
const Bot = preload("res://tests/hockey_bot.gd")

const DT := 1.0 / 60.0
const GOALS := 5
const MATCHES := 5
const RALLY_MAX := 40.0

var _fails := 0
var _checks := 0


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## One match to GOALS goals, ROBO (seat 1, `level`) against `foe` ("still", or a bot level that only chases the puck). Returns
## {own, scored, conceded} like `hockey_bot.gd`.
static func match_to_goals(level: String, foe: String, seed_value: int) -> Dictionary:
	var sim := Sim.new()
	var robo := HockeyBot.new(level, 1, seed_value)
	var chaser: HockeyBot = null if foe == "still" else HockeyBot.new(foe, 0, seed_value + 1000)
	var out := {"own": 0, "scored": 0, "conceded": 0}
	var serve := 0
	while out.scored < GOALS and out.conceded < GOALS:
		sim.reset(serve)
		robo.reset()
		if chaser != null:
			chaser.reset()
		var last_hit := -1
		var self_made := false
		var t := 0.0
		var ended := false
		while t < RALLY_MAX and not ended:
			t += DT
			var before := sim.puck_vel
			var foe_tilt := Vector2.ZERO if chaser == null else chaser.tilt(DT, Bot._view(sim, 0))
			var ev := sim.step(DT, [foe_tilt, robo.tilt(DT, Bot._view(sim, 1))])
			if ev.hit >= 0:
				last_hit = ev.hit
				var toward: float = sim.paddles[1].vel.dot((sim.puck_pos - sim.paddles[1].pos).normalized())
				self_made = ev.hit == 1 and before.x < 150.0 and sim.puck_vel.x > 100.0 and toward > 150.0
			if ev.goal >= 0:
				out.scored += 1 if ev.goal == 1 else 0
				out.conceded += 1 if ev.goal == 0 else 0
				out.own += 1 if ev.goal == 0 and last_hit == 1 and self_made else 0
				serve = 1 - ev.goal
				ended = true
		if not ended:
			serve = 1 - serve   # A rally that does not end is cut; the next one is served from the other side.
			if out.scored + out.conceded > 60:
				break
	return out


func _run() -> void:
	for foe in ["still", "easy", "medium"]:
		var own := 0
		var scored := 0
		var conceded := 0
		for m in MATCHES:
			var r := match_to_goals("easy", foe, 100 + m * 13)
			own += int(r.own)
			scored += int(r.scored)
			conceded += int(r.conceded)
		print("    foe %s: ROBO scored %d, the player %d, own goals of ROBO %d" % [foe, scored, conceded, own])
		if foe == "still":
			_check(own == 0, "Easy ROBO scores no own goal in 5 matches to 5 goals against a player who stands still (%d)" % own)
		elif foe == "easy":
			var goals := scored + conceded
			_check(own * 10 <= goals, "Easy ROBO scores at most 10%% own goals against a chasing player (%d of %d goals)" % [own, goals])
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
