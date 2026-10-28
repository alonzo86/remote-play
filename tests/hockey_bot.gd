extends SceneTree
## ROBO in simulated play (issues #146 and #147, REQ-AH-16, REQ-AH-17), with the real physics of `air_hockey_sim.gd`. Matches: a
## seeded bot plays seat 0 against ROBO on seat 1. Shots: a puck comes straight to the goal of ROBO. Run:
##   godot --headless --path . --script tests/hockey_bot.gd -- --role=tv

const Sim = preload("res://scripts/game/air_hockey/air_hockey_sim.gd")
const HockeyBot = preload("res://scripts/game/air_hockey/hockey_bot.gd")

const DT := 1.0 / 60.0
const RALLY_MAX := 40.0   # Seconds of a rally at most (a rally that does not end is cut).

var _fails := 0
var _checks := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


static func _view(sim: RefCounted, seat: int) -> Dictionary:
	var pad = sim.paddles[seat]
	return {"puck_pos": sim.puck_pos, "puck_vel": sim.puck_vel, "pad_pos": pad.pos, "pad_vel": pad.vel}


## `rallies` rallies: seat 0 plays `foe_level`, seat 1 (ROBO) plays `level`. A rally starts with the puck on the side of the seat
## that conceded. Counts the goals of ROBO (`scored`), the goals against it (`conceded`) and, of those, the own goals: the last
## hit was by ROBO, its mallet drove at the puck (150 px/s or more), the puck did not go to its goal before the hit and the hit
## sent it there. A mallet that stands still and only blocks a puck that comes by is not an own goal.
static func play(level: String, foe_level: String, rallies: int, seed_value: int) -> Dictionary:
	var sim := Sim.new()
	var robo := HockeyBot.new(level, 1, seed_value)
	var foe := HockeyBot.new(foe_level, 0, seed_value + 1000)
	var out := {"own": 0, "scored": 0, "conceded": 0}
	var serve := 1
	for r in rallies:
		sim.reset(serve)
		robo.reset()
		foe.reset()
		var last_hit := -1
		var self_made := false
		var t := 0.0
		while t < RALLY_MAX:
			t += DT
			var before := sim.puck_vel
			var ev := sim.step(DT, [foe.tilt(DT, _view(sim, 0)), robo.tilt(DT, _view(sim, 1))])
			if ev.hit >= 0:
				last_hit = ev.hit
				# The mallet drove at the puck (150 px/s or more toward it); a stand-still mallet only blocks a puck that comes by.
				var toward: float = sim.paddles[1].vel.dot((sim.puck_pos - sim.paddles[1].pos).normalized())
				self_made = ev.hit == 1 and before.x < 150.0 and sim.puck_vel.x > 100.0 and toward > 150.0
			if ev.goal >= 0:
				out.scored += 1 if ev.goal == 1 else 0
				out.conceded += 1 if ev.goal == 0 else 0
				out.own += 1 if ev.goal == 0 and last_hit == 1 and self_made else 0
				serve = 1 - ev.goal
				break
	return out


## A puck from the foe half, straight to the goal of ROBO at `y_off` from the middle line. Returns how far the mallet of ROBO is
## from the line of the puck when the puck arrives at it.
static func miss(level: String, y_off: float, speed: float, seed_value: int) -> float:
	var sim := Sim.new()
	var robo := HockeyBot.new(level, 1, seed_value)
	var c := Sim.RINK.get_center()
	sim.reset(0)
	sim.wait = 0.0
	sim.puck_pos = Vector2(c.x - 200.0, c.y + y_off)
	sim.puck_vel = Vector2(speed, 0.0)
	var arrive: float = sim.paddles[1].pos.x - Sim.PUCK_R - Sim.PADDLE_R - 40.0
	var t := 0.0
	while t < 6.0:
		t += DT
		sim.step(DT, [Vector2.ZERO, robo.tilt(DT, _view(sim, 1))])
		if sim.puck_pos.x >= arrive:
			return absf(sim.paddles[1].pos.y - sim.puck_pos.y)
	return 0.0


func _run() -> void:
	_shots()
	_matches()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Issue #147: a puck that comes straight to the goal, slow or fast. Medium and Hard stand in its line when it arrives (inside the
## reach of mallet and puck) and do not go behind it. Easy may miss (REQ-AH-17).
func _shots() -> void:
	var reach := Sim.PADDLE_R + Sim.PUCK_R
	var worst := {}
	for level in ["easy", "medium", "hard"]:
		worst[level] = 0.0
		var n := 0
		for speed in [float(HockeyBot.skill_for(level).attack_speed) + 80.0, 300.0]:
			for y_off in [-120.0, -60.0, 0.0, 60.0, 120.0]:
				for k in 4:
					n += 1
					worst[level] = maxf(worst[level], miss(level, y_off, speed, 5 + n))
	_check(worst.medium <= reach and worst.hard <= reach,
			"Medium and Hard are in the line of a puck that comes to their goal: the worst miss is %.0f px and %.0f px (reach %.0f px)"
			% [worst.medium, worst.hard, reach])
	_check(worst.easy > reach, "Easy still misses sometimes: the worst miss is %.0f px" % worst.easy)


## Issue #146: ROBO against a Medium player over 180 rallies. Before the fix ROBO scored against itself 115 times on Easy, 19 on
## Medium and 1 on Hard (it ran into the puck while it waited for the serve, and it hit a puck near its goal from the wrong side).
func _matches() -> void:
	var limits := {"easy": 8, "medium": 4, "hard": 3}
	for level in ["easy", "medium", "hard"]:
		var total := {"own": 0, "scored": 0, "conceded": 0}
		for s in 6:
			var r := play(level, "medium", 30, 11 + s * 7)
			for k in total:
				total[k] += int(r[k])
		_check(total.own <= int(limits[level]), "%s: %d own goals in 180 rallies (limit %d)" % [level, total.own, limits[level]])
		if level == "easy":
			_check(total.scored < total.conceded - total.own,
					"Easy stays beatable: ROBO scored %d, the player %d" % [total.scored, total.conceded - total.own])
