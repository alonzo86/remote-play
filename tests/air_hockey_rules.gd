extends SceneTree
## The rules of Air Hockey and the bot without a screen: the rink, the puck, the paddles, the goals and ROBO
## (docs/games/air_hockey.md, REQ-AH-4 to 17). Run:
##   godot --headless --path . --script tests/air_hockey_rules.gd -- --role=controller

const Sim = preload("res://scripts/game/air_hockey/air_hockey_sim.gd")
const Bot = preload("res://scripts/game/air_hockey/hockey_bot.gd")
const BaseBot = preload("res://scripts/game/bot.gd")

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
	_paddles()
	_puck()
	_goals()
	_hits()
	_serve()
	_bot_base()
	_bot_brain()
	_levels()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## A sim with the puck out of the way, for the tests of a paddle.
func _quiet() -> Sim:
	var sim := Sim.new()
	sim.wait = 0.0
	sim.puck_pos = Sim.RINK.get_center() + Vector2(0.0, 300.0)
	sim.puck_vel = Vector2.ZERO
	return sim


## REQ-AH-4, 5: a tilt moves a paddle, and a paddle never leaves its own half or the rink.
func _paddles() -> void:
	print("paddles")
	var sim := _quiet()
	var start := sim.paddles[0].pos
	for i in 30:
		sim.step(DT, [Vector2(0.4, 0.0), Vector2.ZERO])
	_check(sim.paddles[0].pos.x > start.x + 50.0 and is_equal_approx(sim.paddles[0].pos.y, start.y),
			"a tilt to the right slides the left paddle to the right and no other way (REQ-AH-4)")
	_check(sim.paddles[1].pos.is_equal_approx(Vector2(Sim.RINK.end.x - Sim.START_DX, Sim.RINK.get_center().y)),
			"a paddle that is not tilted stays where it is")
	var mid := Sim.RINK.get_center().x
	for i in 240:
		sim.step(DT, [Vector2(1.0, 0.0), Vector2(-1.0, 0.0)])
		sim.puck_pos = Sim.RINK.get_center() + Vector2(0.0, 300.0)   # Keep the puck away: the paddles must stop by the line.
		sim.puck_vel = Vector2.ZERO
	_check(sim.paddles[0].pos.x <= mid - Sim.PADDLE_R + 0.01 and sim.paddles[1].pos.x >= mid + Sim.PADDLE_R - 0.01,
			"the paddles stop at the middle line: each stays in its own half (REQ-AH-5)")
	for i in 240:
		sim.step(DT, [Vector2(-1.0, -1.0), Vector2(1.0, 1.0)])
		sim.puck_pos = Sim.RINK.get_center() + Vector2(0.0, 300.0)
		sim.puck_vel = Vector2.ZERO
	var r := Sim.RINK
	_check(sim.paddles[0].pos.x >= r.position.x + Sim.PADDLE_R - 0.01 and sim.paddles[0].pos.y >= r.position.y + Sim.PADDLE_R - 0.01
			and sim.paddles[1].pos.x <= r.end.x - Sim.PADDLE_R + 0.01 and sim.paddles[1].pos.y <= r.end.y - Sim.PADDLE_R + 0.01,
			"the paddles stay inside the rails (REQ-AH-5)")
	var fast := _quiet()
	for i in 120:
		fast.step(DT, [Vector2(1.0, 0.0), Vector2.ZERO])
		fast.puck_pos = Sim.RINK.get_center() + Vector2(0.0, 300.0)
	_check(fast.paddles[0].vel.length() <= Sim.PADDLE_MAX + 0.01, "a paddle has a speed limit (REQ-AH-4)")
	var a := _quiet()
	var b := _quiet()
	for i in 60:
		a.step(DT, [Vector2(0.3, 0.2), Vector2(-0.3, 0.1)])
		b.step(DT * 0.5, [Vector2(0.3, 0.2), Vector2(-0.3, 0.1)])
		b.step(DT * 0.5, [Vector2(0.3, 0.2), Vector2(-0.3, 0.1)])
	_check(a.paddles[0].pos.distance_to(b.paddles[0].pos) < 8.0,
			"the same tilt gives about the same way at 60 and 120 frames per s (REQ-GM-13)")


## REQ-AH-6, 7: the puck slows down by itself, and bounces off the rails.
func _puck() -> void:
	print("puck")
	var sim := _quiet()
	sim.puck_pos = Sim.RINK.get_center()
	sim.puck_vel = Vector2(0.0, -800.0)
	var ev := {}
	for i in 60:
		ev = sim.step(DT, [Vector2.ZERO, Vector2.ZERO])
		if sim.puck_vel.y > 0.0:
			break
	_check(sim.puck_vel.y > 0.0 and sim.puck_pos.y >= Sim.RINK.position.y + Sim.PUCK_R - 0.01,
			"a puck that hits the top rail bounces back and stays inside the rink (REQ-AH-7)")
	_check(sim.puck_vel.y < 800.0 * Sim.WALL_KEEP and sim.puck_vel.y > 800.0 * Sim.WALL_KEEP * 0.8,
			"a bounce keeps most of the speed: %.0f" % sim.puck_vel.y)
	var slow := _quiet()
	slow.puck_pos = Sim.RINK.get_center() + Vector2(0.0, -250.0)   # Beside the paddles, which stand in the middle height.
	slow.puck_vel = Vector2(700.0, 0.0)
	for i in 60:
		slow.step(DT, [Vector2.ZERO, Vector2.ZERO])
	var s1 := slow.puck_vel.length()
	_check(absf(s1 - 700.0 * exp(-Sim.PUCK_DAMPING)) < 15.0,
			"the puck loses speed slowly, about a third in a second: %.0f px/s" % s1)
	var wall := _quiet()
	wall.puck_pos = Vector2(Sim.RINK.position.x + 80.0, Sim.RINK.position.y + 100.0)   # Far from the goal opening.
	wall.puck_vel = Vector2(-900.0, 0.0)
	var got := {}
	for i in 30:
		got = wall.step(DT, [Vector2.ZERO, Vector2.ZERO])
		if float(got.wall) > 0.0:
			break
	_check(wall.puck_vel.x > 0.0 and int(got.goal) == -1 and float(got.wall) > 500.0,
			"a puck at a short rail outside the goal bounces and is no goal; the bounce reports its speed (REQ-AH-7)")
	var c := _quiet()
	c.puck_vel = Vector2(Sim.PUCK_MAX * 3.0, 0.0)
	c.puck_pos = Sim.RINK.get_center()
	c.step(DT, [Vector2.ZERO, Vector2.ZERO])
	_check(c.puck_vel.length() <= Sim.PUCK_MAX * 3.0, "the puck does not speed up by itself")


## REQ-AH-8: a goal is the whole puck over the goal line, inside the opening, for the other seat.
func _goals() -> void:
	print("goals")
	var cy := Sim.RINK.get_center().y
	var left := _quiet()
	left.puck_pos = Vector2(Sim.RINK.position.x + 200.0, cy)
	left.puck_vel = Vector2(-900.0, 0.0)
	var ev := {"goal": -1}
	for i in 60:
		ev = left.step(DT, [Vector2.ZERO, Vector2.ZERO])
		if int(ev.goal) >= 0:
			break
	_check(int(ev.goal) == 1, "a puck in the left goal is a goal for seat 1, the right player (REQ-AH-8)")
	var right := _quiet()
	right.puck_pos = Vector2(Sim.RINK.end.x - 200.0, cy + Sim.GOAL_H * 0.4)
	right.puck_vel = Vector2(900.0, 0.0)
	for i in 60:
		ev = right.step(DT, [Vector2.ZERO, Vector2.ZERO])
		if int(ev.goal) >= 0:
			break
	_check(int(ev.goal) == 0, "a puck in the right goal, near the post, is a goal for seat 0 (REQ-AH-8)")
	var post := _quiet()
	post.puck_pos = Vector2(Sim.RINK.position.x + 200.0, cy + Sim.GOAL_H * 0.5 + 30.0)
	post.puck_vel = Vector2(-900.0, 0.0)
	var any := false
	for i in 60:
		ev = post.step(DT, [Vector2.ZERO, Vector2.ZERO])
		any = any or int(ev.goal) >= 0
	_check(not any and post.puck_vel.x > 0.0, "a puck beside the opening hits the rail: no goal")
	var fast := _quiet()
	fast.puck_pos = Vector2(Sim.RINK.position.x + 300.0, cy)
	fast.puck_vel = Vector2(-Sim.PUCK_MAX, 0.0)
	ev = fast.step(0.5, [Vector2.ZERO, Vector2.ZERO])   # One long frame: the puck is not lost between two steps.
	_check(int(ev.goal) == 1, "a fast puck in a long frame is still a goal")


## REQ-AH-6: a paddle hits the puck away, harder when it moves, and nothing sticks or tunnels.
func _hits() -> void:
	print("hits")
	var sim := _quiet()
	sim.paddles[0].pos = Vector2(600.0, 500.0)
	sim.puck_pos = Vector2(600.0 + Sim.PADDLE_R + Sim.PUCK_R + 20.0, 500.0)
	sim.puck_vel = Vector2.ZERO
	var ev := {}
	for i in 12:
		ev = sim.step(DT, [Vector2(0.5, 0.0), Vector2.ZERO])
		if int(ev.hit) >= 0:
			break
	_check(int(ev.hit) == 0 and sim.puck_vel.x >= Sim.MIN_HIT - 1.0,
			"a moving paddle hits a still puck away, at the minimum speed or more (REQ-AH-6)")
	_check(sim.puck_pos.distance_to(sim.paddles[0].pos) >= Sim.PADDLE_R + Sim.PUCK_R - 0.01,
			"the puck is never inside a paddle after a hit")
	var slow_hit := sim.puck_vel.x
	var quick := _quiet()
	quick.paddles[0].pos = Vector2(600.0, 500.0)
	quick.paddles[0].vel = Vector2(1000.0, 0.0)
	quick.puck_pos = Vector2(600.0 + Sim.PADDLE_R + Sim.PUCK_R - 5.0, 500.0)
	quick.puck_vel = Vector2.ZERO
	quick.step(DT, [Vector2(0.6, 0.0), Vector2.ZERO])
	_check(quick.puck_vel.x > slow_hit + 300.0,
			"a faster paddle sends the puck faster (%.0f against %.0f)" % [quick.puck_vel.x, slow_hit])
	var still := _quiet()
	still.paddles[1].pos = Vector2(1300.0, 500.0)
	still.puck_pos = Vector2(1300.0 - 150.0, 500.0)
	still.puck_vel = Vector2(1200.0, 0.0)
	var hit_seat := -1
	for i in 30:
		ev = still.step(DT, [Vector2.ZERO, Vector2.ZERO])
		if int(ev.hit) >= 0:
			hit_seat = int(ev.hit)
			break
	_check(hit_seat == 1 and still.puck_vel.x < 0.0, "a fast puck on a still paddle bounces back")
	var tunnel := _quiet()
	tunnel.paddles[1].pos = Vector2(1300.0, 500.0)
	tunnel.puck_pos = Vector2(1300.0 - 400.0, 500.0)
	tunnel.puck_vel = Vector2(Sim.PUCK_MAX, 0.0)
	ev = tunnel.step(0.4, [Vector2.ZERO, Vector2.ZERO])   # A long frame: the puck would go through the paddle in one step.
	_check(int(ev.hit) == 1 and tunnel.puck_vel.x < 0.0, "a long frame does not let the puck go through a paddle")


## REQ-AH-9: after a goal the paddles go to their places and the puck waits on the side of the seat that conceded.
func _serve() -> void:
	print("serve")
	var sim := Sim.new()
	var c := Sim.RINK.get_center()
	_check(sim.puck_pos.is_equal_approx(c) and sim.wait > 0.0, "a new match starts with the puck in the middle, waiting")
	sim.paddles[0].pos = Vector2(300.0, 300.0)
	sim.reset(0)
	_check(sim.puck_pos.x < c.x and is_equal_approx(sim.puck_pos.y, c.y) and sim.paddles[0].pos.y == c.y
			and sim.paddles[0].vel == Vector2.ZERO,
			"after a goal for the right player the puck is served on the left side, the paddles go back")
	sim.reset(1)
	_check(sim.puck_pos.x > c.x, "after a goal for the left player the puck is served on the right side")
	sim.puck_vel = Vector2(500.0, 0.0)
	var before := sim.puck_pos
	for i in 30:
		sim.step(DT, [Vector2.ZERO, Vector2.ZERO])
	_check(sim.puck_pos == before, "the puck waits for the serve wait before it moves (%.1f s)" % Sim.SERVE_WAIT)
	for i in 60:
		sim.step(DT, [Vector2.ZERO, Vector2.ZERO])
	_check(sim.puck_pos.x > before.x, "then the puck moves")


class TiltBot extends "res://scripts/game/bot.gd":
	func _brain(seen: Dictionary, _now: Dictionary, _delta: float) -> Vector2:
		return seen.want


## The base class of a bot (REQ-GM-105): the reaction time, the tilt limit and the seed.
func _bot_base() -> void:
	print("bot base class")
	var bot := TiltBot.new({"reaction": 0.3, "max_tilt": 0.5}, 7)
	var out := Vector2.ZERO
	for i in 6:   # 0.1 s: the first view is all the bot has seen.
		out = bot.tilt(DT, {"want": Vector2(1.0, 0.0)})
	_check(out.is_equal_approx(Vector2(0.5, 0.0)), "the tilt is cut to the max tilt of the skill")
	var early := Vector2.ZERO
	for i in 12:   # The view changes: for 0.2 s the bot still acts on the old one.
		early = bot.tilt(DT, {"want": Vector2(0.0, 0.4)})
	_check(early.is_equal_approx(Vector2(0.5, 0.0)), "the bot acts on what it saw 0.3 s ago: still the old view after 0.2 s")
	var late := Vector2.ZERO
	for i in 12:
		late = bot.tilt(DT, {"want": Vector2(0.0, 0.4)})
	_check(late.is_equal_approx(Vector2(0.0, 0.4)), "after 0.4 s it acts on the new view")
	bot.reset()
	_check(bot.tilt(DT, {"want": Vector2(0.0, -0.1)}).is_equal_approx(Vector2(0.0, -0.1)), "reset forgets the old views")
	var a := Bot.new("medium", 1, 42)
	var b := Bot.new("medium", 1, 42)
	var same := true
	for i in 200:
		var puck := Vector2(900.0 + i * 2.0, 400.0)
		var view := {"puck_pos": puck, "puck_vel": Vector2(-300.0, 20.0), "pad_pos": Vector2(1500.0, 500.0), "pad_vel": Vector2.ZERO}
		same = same and a.tilt(DT, view).is_equal_approx(b.tilt(DT, view))
	_check(same, "the same seed gives the same bot (a test plays the same match every time)")
	_check(is_instance_of(a, BaseBot), "the hockey bot is a bot")


func _view(puck: Vector2, vel: Vector2, pad: Vector2) -> Dictionary:
	return {"puck_pos": puck, "puck_vel": vel, "pad_pos": pad, "pad_vel": Vector2.ZERO}


## REQ-AH-13 to 15: ROBO defends its goal and attacks a slow puck on its half.
func _bot_brain() -> void:
	print("bot brain")
	var c := Sim.RINK.get_center()
	var pad := Vector2(Sim.RINK.end.x - Sim.START_DX, c.y)
	var bot := Bot.new("hard", 1, 3)
	var out := Vector2.ZERO
	for i in 30:   # A fast puck that comes at the top of the goal: the bot goes up.
		out = bot.tilt(DT, _view(Vector2(900.0, c.y - 150.0), Vector2(900.0, 0.0), pad))
	_check(out.y < -0.05, "a puck that comes at the upper part of the goal: ROBO moves up (tilt y %.2f)" % out.y)
	bot = Bot.new("hard", 1, 3)
	for i in 30:
		out = bot.tilt(DT, _view(Vector2(900.0, c.y + 150.0), Vector2(900.0, 0.0), pad))
	_check(out.y > 0.05, "a puck that comes at the lower part: ROBO moves down (tilt y %.2f)" % out.y)
	bot = Bot.new("hard", 1, 3)
	var far := Vector2(Sim.RINK.end.x - 400.0, c.y)
	for i in 30:
		out = bot.tilt(DT, _view(Vector2(500.0, c.y), Vector2.ZERO, far))
	_check(out.x > 0.05, "the puck is far away on the other half: ROBO goes back to its goal (tilt x %.2f)" % out.x)
	bot = Bot.new("hard", 1, 3)
	for i in 120:   # A slow puck on its own half: it attacks. The tilt then points at the puck, from behind.
		out = bot.tilt(DT, _view(Vector2(1300.0, c.y), Vector2.ZERO, pad))
	_check(out.length() > 0.05 and out.x < 0.0, "a slow puck on its half: ROBO goes to the puck, the other way from its goal")
	var seat0 := Bot.new("hard", 0, 3)
	var pad0 := Vector2(Sim.RINK.position.x + Sim.START_DX, c.y)
	for i in 30:
		out = seat0.tilt(DT, _view(Vector2(700.0, c.y - 150.0), Vector2(-900.0, 0.0), pad0))
	_check(out.y < -0.05 and seat0.away() == 1.0, "a bot in the left seat does the same, mirrored")
	var wall := Bot.new("hard", 1, 3)
	for i in 30:   # A puck that comes in at an angle and bounces off the rail: the bot folds the line.
		out = wall.tilt(DT, _view(Vector2(900.0, Sim.RINK.position.y + 60.0), Vector2(600.0, -900.0), pad))
	_check(out.y > 0.0 or out.y < 0.0, "a puck that will bounce gives a tilt too")
	_check(is_equal_approx(Bot._fold(Sim.RINK.position.y + Sim.PUCK_R - 100.0), Sim.RINK.position.y + Sim.PUCK_R + 100.0)
			and is_equal_approx(Bot._fold(Sim.RINK.end.y - Sim.PUCK_R + 100.0), Sim.RINK.end.y - Sim.PUCK_R - 100.0),
			"a line that goes past a rail comes back inside the rink")


## A player who does not aim and does not know the game: chases the puck on its half with a soft tilt (REQ-GM-96).
func _novice(sim: Sim, seat: int) -> Vector2:
	var p := sim.paddles[seat]
	var away := 1.0 if seat == 0 else -1.0
	var target := sim.puck_pos - Vector2(away * 60.0, 0.0)
	if (sim.puck_pos.x - Sim.goal_x(seat)) * away > Sim.RINK.size.x * 0.5:
		target = Vector2(Sim.goal_x(seat) + away * 200.0, Sim.RINK.get_center().y)
	return ((target - p.pos) / 400.0).limit_length(0.4)


## Plays `seconds` of the novice (left) against ROBO (right) and returns the goals [novice, bot].
func _play(difficulty: String, seed_value: int, seconds: float) -> Array:
	var sim := Sim.new()
	var bot := Bot.new(difficulty, 1, seed_value)
	var goals := [0, 0]
	var t := 0.0
	while t < seconds:
		t += DT
		var view := _view(sim.puck_pos, sim.puck_vel, sim.paddles[1].pos)
		view.pad_vel = sim.paddles[1].vel
		var ev := sim.step(DT, [_novice(sim, 0), bot.tilt(DT, view)])
		if int(ev.goal) >= 0:
			goals[int(ev.goal)] += 1
			sim.reset(1 - int(ev.goal))
			bot.reset()
	return goals


## REQ-AH-17, REQ-GM-96: Difficulty changes the bot only. Easy loses to a player who just chases the puck (a child of 5 can do
## that), Hard beats that player.
func _levels() -> void:
	print("levels")
	var easy: Dictionary = Bot.skill_for("easy")
	var medium: Dictionary = Bot.skill_for("medium")
	var hard: Dictionary = Bot.skill_for("hard")
	_check(easy.reaction > medium.reaction and medium.reaction > hard.reaction
			and easy.max_tilt < medium.max_tilt and medium.max_tilt < hard.max_tilt and easy.aim_error > hard.aim_error,
			"Easy reacts slower, tilts less and aims worse than Medium, and Medium than Hard (REQ-AH-17)")
	_check(Bot.skill_for("nonsense") == Bot.skill_for("medium"), "an unknown difficulty is Medium")
	var total := {}
	for d in ["easy", "medium", "hard"]:
		var novice := 0
		var robo := 0
		for s in 4:
			var g := _play(d, s + 1, 180.0)
			novice += int(g[0])
			robo += int(g[1])
		total[d] = [novice, robo]
		print("    %s: the novice scored %d, ROBO scored %d" % [d, novice, robo])
	_check(total.easy[0] + total.easy[1] >= 10, "matches have goals: nobody waits for ever (the bot plays a slow puck on its half)")
	_check(total.easy[0] >= 3 * total.easy[1] and total.easy[0] >= 20,
			"Easy: a player that only chases the puck scores most of the goals (REQ-GM-96)")
	_check(total.hard[1] > 3 * total.hard[0], "Hard: ROBO beats that player clearly")
	_check(total.medium[1] > total.easy[1] and total.hard[1] > total.medium[1], "ROBO scores more on each higher level")
