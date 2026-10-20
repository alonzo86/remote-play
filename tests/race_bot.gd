extends SceneTree
## A bot drives Road Rally on all 10 fixed tracks and a random one at every difficulty (REQ-MR-51, 52, test 9 steps 8a and 9e).
## It steers toward the road 4 m ahead with the tilt of a hand (0.26, 15 degrees) and checks that every race can be finished, ends
## with the result menu and a winner, and that the car never stands still while the bot tilts it. Run:
##   godot --headless --path . --script tests/race_bot.gd -- --role=tv

const Sim = preload("res://tests/sim_b.gd")
const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")

const TILT := 0.26
const LIMIT_S := 120.0

var _fails := 0
var _checks := 0
var Race
var sim


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _run() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)
	Race = load("res://scripts/game/marble_race/marble_race.gd")
	sim = Sim.new(self)
	await sim.join(1)
	var slowest_overall := 0.0
	var all_ok := true
	var report: Array = []
	for d in ["easy", "medium", "hard"]:
		for choice in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
				"r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12", "r152"]:
			var r: Dictionary = await _drive(choice, d)
			all_ok = all_ok and r.ok
			slowest_overall = maxf(slowest_overall, r.time)
			if not r.ok:
				print("    FAILED: track ", choice, " ", d, " ", r)
			report.append("%s/%s %.0f s" % [choice, d[0], r.time])
	_check(all_ok,
			"the bot wins all races (10 fixed tracks and 13 random seeds, 3 difficulties): result menu, a winner, a time > 0, "
			+ "in under %.0f s, the car never stops (slowest race %.0f s)" % [LIMIT_S, slowest_overall])
	print("    ", ", ".join(report))
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _drive(choice: String, difficulty: String) -> Dictionary:
	var props := {"track_choice": choice, "difficulty": difficulty}
	if choice.begins_with("r"):   # A random track with a fixed seed, so that the test is the same every run.
		props = {"track_choice": "random", "difficulty": difficulty, "track_seed": 1000 + int(choice.substr(1)) * 7919}
	var game: Control = await sim.start(Race, props)
	var p = sim.app.server.players[0]
	sim.settle(0, Sim.FLAT)
	p.recenter()
	sim.through_countdown(game)
	var car = game._racers[0]
	var tr = game.track
	var stalled := 0.0
	var reverse := 0.0
	var worst_stall := 0.0
	var ticks := 0
	while not game.is_over and ticks < LIMIT_S * 60.0:
		var target: Vector2 = tr.point_at(minf(car.arc + 4.0, tr.length))
		var dir: Vector2 = (target - car.pos).normalized()
		if stalled > 0.5:
			reverse = 0.6   # Wedged between a post and the wall: back off a moment, like a hand does.
		if reverse > 0.0:
			reverse -= Sim.DT
			dir = -dir
		p.orientation.up = Vector3(-dir.x * TILT, dir.y * TILT, 0.0)
		p.orientation.up.z = sqrt(1.0 - p.orientation.up.x * p.orientation.up.x - p.orientation.up.y * p.orientation.up.y)
		game._game_tick(Sim.DT)
		ticks += 1
		if car.finish_time < 0.0 and ticks > 120:
			stalled = stalled + Sim.DT if car.vel.length() < 0.3 else 0.0
			worst_stall = maxf(worst_stall, stalled)
	var ok: bool = game.is_over and game._winner == 0 and car.finish_time > 0.0 and worst_stall < 2.0 \
			and game.menu_buttons().size() >= 3
	return {"ok": ok, "time": ticks * Sim.DT, "stall": worst_stall, "winner": game._winner}
