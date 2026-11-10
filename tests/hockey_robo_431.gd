extends SceneTree
## Issue #431 (REQ-AH-17, REQ-GM-96; Test 27 step 6b): the step plays 5 matches to 5 goals on Easy against ROBO. ROBO must not
## score in its own goal ("the player scored 1 goal and then ROBO scored 4 own goals"). The foes are players of the step: one
## that stands still, and bots that chase the puck. It FAILS today (own goals against the chasing players), so it is NOT in
## tests/suites.txt until the bot is fixed.
## Run: godot --headless --path . --script tests/hockey_robo_431.gd -- --role=tv

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
		_check(own == 0, "Easy ROBO scores no own goal in 5 matches to 5 goals against a '%s' player (%d own goals)" % [foe, own])
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
