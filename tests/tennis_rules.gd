extends SceneTree
## The rules of Tennis without a screen: the score, the teams, the ball, the serve, the rally and the 1 player rally
## (docs/games/tennis.md, REQ-TN-1 to 20). Run: godot --headless --path . --script tests/tennis_rules.gd -- --role=controller

const Sim = preload("res://scripts/game/tennis/tennis_sim.gd")
const Rules = preload("res://scripts/game/tennis/tennis_rules.gd")
const Match = preload("res://scripts/game/tennis/tennis_match.gd")
const Trace = preload("res://tests/golf_tennis_trace.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")

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
	_scoring_real()
	_scoring_quick()
	_teams()
	_ball()
	_serve()
	_rally()
	_points()
	_on_screen()
	_matches()
	_solo()
	_leaving()
	_leaving_teams()
	_quick_three()
	_green_window()
	_power_and_distance()
	_easy_stays_in()
	_court_width()
	_solo_clock()
	_medal_tiers()
	_swing_chain()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _win_game(r: Rules, team: int) -> Dictionary:
	var last := {}
	for i in 4:
		last = r.score_point(team)
	return last


## The scoring Real (REQ-TN-10).
func _scoring_real() -> void:
	print("scoring Real")
	var r := Rules.new()
	r.setup([0, 1], false)
	_check(r.point_text(0) == "0" and r.point_text(1) == "0" and r.status() == "", "a game starts at 0 to 0")
	r.score_point(0)
	r.score_point(0)
	r.score_point(1)
	_check(r.point_text(0) == "30" and r.point_text(1) == "15", "the points count 15, 30, 40")
	r.score_point(0)
	var g := r.score_point(0)
	_check(g.game and r.tally[0] == 1 and r.tally[1] == 0 and r.points == [0, 0],
			"4 points with a lead of 2 win the game and the points restart")
	for i in 3:
		r.score_point(0)
		r.score_point(1)
	_check(r.status() == "deuce" and r.point_text(0) == "40" and r.point_text(1) == "40", "40 to 40 is deuce")
	r.score_point(1)
	_check(r.status() == "advantage" and r.advantage_team() == 1 and r.point_text(1) == "AD" and r.point_text(0) == "40",
			"the next point is an advantage")
	r.score_point(0)
	_check(r.status() == "deuce" and r.advantage_team() == -1, "the other team wins the next point: deuce again")
	r.score_point(0)
	var win := r.score_point(0)
	_check(win.game and r.tally[0] == 2, "an advantage and one more point win the game")
	_win_game(r, 1)
	_check(not r.match_over() and r.winners().is_empty(), "no match winner before 3 games")
	var end := _win_game(r, 0)
	_check(end.match and r.match_over() and r.winners() == [0], "the first player with 3 games wins the match (REQ-TN-19)")


## The scoring Quick (REQ-TN-10).
func _scoring_quick() -> void:
	print("scoring Quick")
	var r := Rules.new()
	r.setup([0, 1], true)
	r.score_point(0)
	r.score_point(1)
	_check(r.point_text(0) == "1" and r.point_text(1) == "1" and r.status() == "", "Quick counts the points as numbers")
	for i in 3:
		r.score_point(0)
	_check(not r.match_over(), "4 points are not enough")
	var last := r.score_point(0)
	_check(last.match and r.winners() == [0] and r.tally[0] == 5, "the first to 5 points wins (REQ-TN-19)")
	var fresh := Rules.new()
	fresh.setup([0, 1], true)
	_check(not fresh.score_point(0).game, "Quick has no games: a point never ends a game")


## The teams and the servers (REQ-TN-1, 11).
func _teams() -> void:
	print("teams and servers")
	var two := Rules.new()
	two.setup([4, 7], false)
	_check(two.teams == [[4], [7]] and two.team_of(7) == 1 and two.server_slot() == 4, "2 players: 1 against 1, slot order")
	_win_game(two, 0)
	_check(two.server_slot() == 7, "the server changes after a game")
	_win_game(two, 1)
	_check(two.server_slot() == 4, "and back")
	var four := Rules.new()
	four.setup([0, 1, 2, 3], false)
	_check(four.teams == [[0, 1], [2, 3]], "4 players: 2 against 2")
	var servers: Array = []
	for i in 4:
		servers.append(four.server_slot())
		_win_game(four, 0)
	_check(servers == [0, 2, 1, 3], "the servers go team to team and inside the team: %s" % [servers])
	var three := Rules.new()
	three.setup([0, 1, 2], false)
	_check(three.teams == [[1, 2], [0]] or three.teams == [[0], [1, 2]], "3 players: 2 against 1")
	_check(three.teams[0].has(0), "team 0 holds the first player (the camera side)")
	var singles: Array = []
	for i in 3:
		for t in three.teams:
			if t.size() == 1:
				singles.append(t[0])
		_win_game(three, 0)
	singles.sort()
	_check(singles == [0, 1, 2], "with 3 players the single player changes after every game: %s" % [singles])
	var q3 := Rules.new()
	q3.setup([0, 1, 2], true)
	var before := q3.teams.duplicate(true)
	q3.score_point(0)
	_check(q3.teams == before, "in Quick the teams stay for the first point")
	q3.score_point(1)
	_check(q3.teams != before, "and change after 2 points")
	_check(two.serve_side() == 0 and (func() -> int:
			two.score_point(0)
			return two.serve_side()).call() == 1, "the serving side changes with every point")


## The ball (REQ-TN-3, 4, 7).
func _ball() -> void:
	print("the ball")
	var s := Sim.new()
	var flight := s.launch(Vector3(1.0, -11.0, 1.0), Vector2(-2.0, 8.0), 0.9)
	_check(flight >= 0.9 and s.active, "a hit starts the ball")
	var landed := Vector3.ZERO
	var t := 0.0
	while t < 4.0 and landed == Vector3.ZERO:
		s.tick(DT)
		t += DT
		for e in s.events:
			if e.t == "bounce":
				landed = e.pos
	_check(absf(landed.x + 2.0) < 0.15 and absf(landed.y - 8.0) < 0.2, "the ball lands on the wanted point %s" % [landed])
	_check(s.bounces >= 1 and absf(t - flight) < 0.05, "after the flight time that was asked (%.2f s)" % t)
	var low := Sim.new()
	var f2 := low.launch(Vector3(0.0, -2.0, 0.6), Vector2(0.0, 1.5), 0.3)
	_check(f2 > 0.3, "a ball that would not clear the net gets a longer flight (%.2f s)" % f2)
	var net := Sim.new()
	net.active = true
	net.pos = Vector3(0.0, -1.0, 0.3)
	net.vel = Vector3(0.0, 10.0, 0.0)
	var saw := false
	for i in 60:
		net.tick(DT)
		for e in net.events:
			saw = saw or e.t == "net"
	_check(saw and net.dead, "a ball below the top of the net touches it and is dead (REQ-TN-12)")
	var tossed := Sim.new()
	tossed.toss(Vector3(0.0, -12.0, 1.0), 4.6)
	var top := 0.0
	for i in 120:
		tossed.tick(DT)
		top = maxf(top, tossed.pos.z)
	_check(top > 1.9 and top < 2.2 and tossed.predict().is_empty(), "a toss goes up about 1 m and has no prediction")
	var p := Sim.new()
	p.launch(Vector3(0.0, -11.0, 1.0), Vector2(1.0, 7.0), 1.0)
	var pred := p.predict()
	_check(not pred.is_empty() and absf(float(pred.bounce_t) - 1.0) < 0.05
			and absf(float(pred.contact_t) - float(pred.bounce_t) - Sim.CONTACT_DELAY) < 0.03,
			"the prediction gives the bounce and the contact time 0.3 s after it")
	_check(pred.contact_pos.y > 7.0 and pred.contact_pos.z > 0.0, "the contact point is past the bounce and above the ground")
	var l := Rules.level("easy")
	_check(l.green > Rules.level("medium").green and Rules.level("medium").green > Rules.level("hard").green
			and l.inside and not Rules.level("hard").inside, "Easy has the widest green part and keeps the ball inside the lines")


## A match with `slots` that is ready to serve.
func _match(slots: Array, quick := false, difficulty := "medium") -> Match:
	var m := Match.new()
	m.setup(slots, quick, difficulty, 5)
	return m


func _run(m: Match, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		m.tick(DT)
		t += DT


func _until_toss_top(m: Match) -> void:
	for i in 300:
		if m.time >= m._toss_apex:
			return
		m.tick(DT)


func _until_contact(m: Match) -> void:
	for i in 600:
		if m.phase != Match.Phase.RALLY or m.time >= float(m.contact.get("t", INF)):
			return
		m.tick(DT)


## The server tosses and swings: power 0.6, no aim.
func _serve_now(m: Match, power := 0.6, tilt := 0.0, down := true) -> String:
	m.press_a(m.server_slot())
	_until_toss_top(m)
	return m.swing(m.server_slot(), power, down, tilt, 0.0)


func _has(events: Array, t: String) -> bool:
	for e in events:
		if e.t == t:
			return true
	return false


## The serve (REQ-TN-9).
func _serve() -> void:
	print("the serve")
	var m := _match([0, 1])
	_check(m.phase == Match.Phase.SERVE and m.server_slot() == 0, "the match starts with a serve of the first player")
	m.swing(0, 0.6, true, 0.0, 0.0)
	_check(m.phase == Match.Phase.SERVE, "a swing before the toss does nothing")
	m.press_a(1)
	_check(m.phase == Match.Phase.SERVE, "A of the player who does not serve does nothing")
	m.press_a(0)
	_check(m.phase == Match.Phase.TOSS and m.sim.tossed, "A tosses the ball")
	_check(m.swing(0, 0.6, false, 0.0, 0.0) == "none" and m.phase == Match.Phase.TOSS,
			"a swing that is not from top to bottom does nothing")
	# (Until 2026-11-08 a swing right after the toss did nothing; the window is now the whole toss, issue #419.)
	_until_toss_top(m)
	_check(m.swing(1, 0.6, true, 0.0, 0.0) == "none", "the other player cannot serve")
	_check(m.swing(0, 0.6, true, 0.0, 0.0) == "serve" and m.phase == Match.Phase.RALLY and m.serve_ball,
			"a swing from top to bottom at the top of the toss is the serve")
	_check(m.expect_team == 1 and m.hitter == 1 and m.chars[1].target.y > 0.0, "the other team returns it, and its player runs")
	var lost := _match([0, 1])
	lost.press_a(0)
	_run(lost, 2.0)
	_check(lost.phase == Match.Phase.SERVE and _has(lost.take_events(), "toss_lost"),
			"a toss that is not hit falls and the server tosses again, with no fault")
	# A serve that lands in the box, and its return.
	var ok := _match([0, 1])
	_serve_now(ok, 0.5, 0.0)
	var ev: Array = []
	_run(ok, 1.5)
	ev = ok.take_events()
	_check(_has(ev, "bounce") and not _has(ev, "fault") and not ok.serve_ball and ok.faults == 0,
			"a serve in the service box is good")
	# Faults (REQ-TN-9): out, then a double fault gives the point.
	var f := _match([0, 1])
	_serve_now(f, 1.0, 1.0)   # Hard serve with an extreme aim: long or wide.
	_run(f, 1.5)
	var fe := f.take_events()
	_check(_has(fe, "fault") and f.phase == Match.Phase.POINT and f.faults == 1, "a serve that lands out is a fault")
	_run(f, Match.FAULT_PAUSE + 0.2)
	_check(f.phase == Match.Phase.SERVE and f.server_slot() == 0 and f.rules.points == [0, 0],
			"after a fault the same player serves again and nothing is scored")
	_serve_now(f, 1.0, 1.0)
	_run(f, 1.5)
	var fe2 := f.take_events()
	_check(f.rules.points == [0, 1] and _has(fe2, "point") and f.last_point.reason == "double_fault",
			"a second fault is a point for the other team")
	var easy := _match([0, 1], false, "easy")
	_serve_now(easy, 1.0, 1.0)
	_run(easy, 1.5)
	_check(not _has(easy.take_events(), "fault") and easy.faults == 0, "on Easy the serve is kept inside the box")


## The rally: who hits, the hit window and the quality (REQ-TN-5, 6).
func _rally() -> void:
	print("the rally")
	var m := _match([0, 1])
	_serve_now(m, 0.5)
	_until_contact(m)
	_check(m.hitter == 1, "the returner is the hitter")
	_check(m.swing(0, 0.5, false, 0.0, 0.0) == "none", "a player of the team that does not have to hit cannot hit")
	var c: Dictionary = m.contact
	_check(m.swing(1, 0.5, false, 0.0, 1.0) == "none", "a swing whose hit was 1 s before the contact does nothing")
	_check(m.swing(1, 0.5, false, 0.0, -1.0) == "none", "and one whose hit is 1 s after it does nothing")
	m.chars[1].anim = 5.0
	var miss := m.swing(1, 0.5, false, 0.0, 1.0)
	_check(miss == "none" and m.chars[1].anim == 0.0 and m.contact == c and m.hitter == 1,
			"a missed swing still plays the swing of the character, and the ball and the turn stay as they were")
	var back := m.swing(1, 0.7, false, 0.0, 0.0)
	_check(back == "hit" and m.hit_team == 1 and m.expect_team == 0 and m.hitter == 0,
			"a swing at the contact time returns the ball")
	_check(absf(m.chars[1].pos.y - (c.pos.y + Match.BEHIND)) < 0.01 or m.chars[1].pos.y > 5.0,
			"the player hits from behind the ball")
	var ev := m.take_events()
	_check(_has(ev, "hit") and ev.filter(func(e): return e.t == "hit")[-1].green, "a swing at the contact time is green")
	# A late swing inside the window is a high lob, and Easy makes the green part wider (REQ-TN-6).
	var late := _match([0, 1])
	_serve_now(late, 0.5)
	_until_contact(late)
	late.swing(1, 0.7, false, 0.0, -0.4)   # 0.4 s after the contact: outside the green half width of 0.21 s.
	var hits := late.take_events().filter(func(e): return e.t == "hit")
	_check(not hits[-1].green and late.sim.vel.z > 6.0, "a swing 0.4 s late on Medium is a lob (not green)")
	var easy := _match([0, 1], false, "easy")
	_serve_now(easy, 0.5)
	_until_contact(easy)
	easy.swing(1, 0.7, false, 0.0, -0.25)
	var eh := easy.take_events().filter(func(e): return e.t == "hit")
	_check(eh[-1].green, "the same 0.25 s is still green on Easy (the half width is 0.30 s)")
	# Aim: tilt moves the target, and a far team mirrors it.
	var left := _match([0, 1])
	_serve_now(left, 0.5)
	_until_contact(left)
	left.swing(1, 0.6, false, 1.0, 0.0)
	var right_x: float = left.sim.vel.x
	var mid := _match([0, 1])
	_serve_now(mid, 0.5)
	_until_contact(mid)
	mid.swing(1, 0.6, false, -1.0, 0.0)
	_check(right_x < mid.sim.vel.x, "the far team has its right hand at negative x: the aim is mirrored")
	# The side of the swing (-1 left to 1 right) decides where along the court the ball goes (REQ-TN-7).
	var aim := _match([0, 1])
	_serve_now(aim, 0.5)
	_until_contact(aim)
	_check(aim.hitter >= 0, "a player has to hit")
	_check(aim.aim_x(1, 1.0, false) < aim.aim_x(1, -1.0, false), "far team: a swing to the right is a smaller x (mirrored)")
	_check(absf(aim.aim_x(0, 1.0, false, 0.0)) <= aim.half_width() * 1.12 + 0.001,
			"the aim of a full side stays within the aim range")
	var ez := _match([0, 1], false, "easy")
	_check(absf(ez.aim_x(0, 1.0, false)) <= ez.half_width() - 0.4 + 0.001, "on Easy the aim stays inside the lines")
	var sv := _match([0, 1])
	var sx: float = sv.chars[sv.server_slot()].pos.x
	_check(sv.aim_x(sv.server_slot(), 0.0, true) * sx < 0.0, "the serve aim with no side is in the box across the net")


## A character never runs out of the picture (REQ-TN-4).
func _on_screen() -> void:
	print("characters stay on the screen")
	var m := _match([0, 1])
	var v: Vector2 = Match._on_screen(Vector2(9.0, -20.0))
	_check(is_equal_approx(v.x, Match.RUN_MAX_X) and is_equal_approx(v.y, -(Sim.HALF_L + Match.RUN_MAX_BEHIND)),
			"a place far out and far behind is moved back")
	_check(Match._on_screen(Vector2(1.0, -5.0)) == Vector2(1.0, -5.0), "a place on the court stays")
	_serve_now(m, 0.9, 1.0)
	for i in 6:
		_until_contact(m)
		if m.phase != Match.Phase.RALLY or m.hitter < 0:
			break
		var tg: Vector2 = m.chars[m.hitter].target
		_check(absf(tg.x) <= Match.RUN_MAX_X + 0.001 and tg.y >= -(Sim.HALF_L + Match.RUN_MAX_BEHIND) - 0.001,
				"the hitter runs to a place that the screen shows")
		m.swing(m.hitter, 1.0, false, 1.0 if i % 2 == 0 else -1.0, 0.0)


## How a point is won (REQ-TN-12).
func _points() -> void:
	print("points")
	# The returner does not hit: the ball bounces twice, the serving team wins the point.
	var m := _match([0, 1])
	_serve_now(m, 0.5)
	_run(m, 3.0)
	var ev := m.take_events()
	_check(m.rules.points == [1, 0] and m.last_point.reason == "double_bounce" and _has(ev, "point"),
			"a ball that is not returned is a point for the team that hit it")
	_run(m, Match.POINT_PAUSE + 0.1)
	_check(m.phase == Match.Phase.SERVE and m.rules.serve_side() == 1, "then the next serve from the other half")
	# The returner hits out.
	var o := _match([0, 1])
	_serve_now(o, 0.5)
	_until_contact(o)
	# The widest aim ends on the sideline, which is in (2026-11-06). A swing that is not green (0.3 s late) adds a random
	# sideways miss to it (the match has a fixed seed), and this one is out.
	o.swing(1, 1.0, false, -1.0, -0.3)
	_run(o, 2.0)
	_check(o.rules.points == [1, 0] and o.last_point.reason == "out", "a ball that lands out is a point for the other team")
	# A ball that stays in is returned back and forth.
	var r := _match([0, 1])
	_serve_now(r, 0.5)
	var returns := 0
	for i in 6:
		_until_contact(r)
		if r.phase != Match.Phase.RALLY:
			break
		if r.swing(r.hitter, 0.5, false, 0.0, 0.0) == "hit":
			returns += 1
	_check(returns >= 5 and r.rules.points == [0, 0],
			"a rally goes on while the balls are returned and in (%d returns)" % returns)


## Games, the match and the result (REQ-TN-10, 14).
func _matches() -> void:
	print("games and the match")
	var m := _match([0, 1])
	for g in 3:
		for p in 4:
			_serve_now(m, 0.5)
			_run(m, 3.0)   # Not returned: the server wins the point.
			if m.rules.match_over():
				break
			_run(m, Match.GAME_PAUSE + 0.1)
			if m.phase != Match.Phase.SERVE:
				break
			# The other player serves after a game: this loop gives the points to whoever serves, so alternate by hand.
			if p == 3:
				break
	_check(m.rules.tally[0] + m.rules.tally[1] >= 1, "games are counted in the tally")
	var q := _match([0, 1], true)
	var over := false
	for i in 12:
		if q.rules.match_over():
			over = true
			break
		_serve_now(q, 0.5)
		_run(q, 3.0)
		_run(q, Match.GAME_PAUSE + 0.1)
	_check(q.is_over() and _has(q.take_events(), "match_over") and q.winners().size() == 1,
			"a Quick match ends with phase END, `match_over` and the winners")
	_check(q.rules.tally[q.winners()[0]] >= 5, "the winner has 5 points")


## 1 player: the machine (REQ-TN-15, 16).
func _solo() -> void:
	print("1 player and the machine")
	var m := _match([3])
	_check(m.solo and m.half_width() == Sim.HALF_W_SINGLES, "1 player: a rally on the singles court")
	_run(m, Match.FEED_DELAY + 0.5)
	_check(m.phase == Match.Phase.RALLY and m.expect_team == 0 and m.hitter == 3,
			"the machine sends the first ball to the player")
	for i in 5:
		_until_contact(m)
		if m.swing(3, 0.5, false, 0.0, 0.0) != "hit":
			break
		_until_contact(m)   # The machine returns every ball it can reach.
	_run(m, 0.5)
	_check(m.rally >= 3 and m.hit_team in [0, 1], "the machine returns the balls (rally %d)" % m.rally)
	var before := m.rally
	_run(m, 5.0)
	var ev := m.take_events()
	_check(_has(ev, "rally_over") and m.best_rally >= before and m.rally == 0,
			"a ball that is not returned ends the rally and the best one stays")
	_check(m.rules.tally[3] == 0 and m.rules.points == [0, 0], "no points are scored with 1 player")
	var best := m.best_rally
	m.solo_left = 0.5
	_run(m, 1.0)
	_check(m.is_over() and _has(m.take_events(), "time_up") and m.best_rally >= best, "after 90 s the round is over")
	var skip := _match([3])
	skip.press_a(3)
	_run(skip, 1.0)
	_check(skip.phase == Match.Phase.RALLY, "A of the player skips the wait of the machine")


## Players that leave (REQ-TN-20).
func _leaving() -> void:
	print("players that leave")
	var m := _match([0, 1])
	m.remove_player(1)
	_check(m.is_over() and m.winners() == [0] and _has(m.take_events(), "match_over"),
			"when a team has no player left the other team wins at once")
	var four := _match([0, 1, 2, 3])
	four.remove_player(3)
	_check(not four.is_over() and four.rules.slots == [0, 1, 2] and four.rules.teams.size() == 2,
			"with 4 players, one player less: the teams are made again for 3 players")
	_check(four.phase == Match.Phase.SERVE and four.rules.slots.has(four.server_slot()),
			"and the serve goes on with a player that is left")
	var rally := _match([0, 1, 2, 3])
	_serve_now(rally, 0.5)
	_until_contact(rally)
	var hitter := rally.hitter
	rally.remove_player(hitter)
	_check(rally.hitter != hitter and not rally.is_over(), "a hitter that leaves is replaced")
	var solo := _match([2])
	solo.remove_player(2)
	_check(solo.is_over(), "with 1 player that leaves the game ends")


## REQ-TN-20: the teams of 2 against 2 stay when a player leaves; a team without players loses at once.
func _leaving_teams() -> void:
	print("players that leave, 2 against 2")
	var r := Rules.new()
	r.setup([0, 1, 2, 3], false)
	r.remove_player(2)
	_check(r.teams == [[0, 1], [3]], "2 against 2, player 2 leaves: the teams stay [0, 1] and [3] (%s)" % str(r.teams))
	_check(r.team_of(0) == 0 and r.team_of(1) == 0 and r.team_of(3) == 1 and not r.forfeit, "and nobody changes the team")
	var servers := {}
	for i in 6:
		servers[r.server_slot()] = true
		r.chunks += 1
	_check(servers.has(0) and servers.has(1) and servers.has(3) and not servers.has(2), "and only players that are left serve")
	var both := Rules.new()
	both.setup([0, 1, 2, 3], false)
	both.remove_player(2)
	var over := both.remove_player(3)
	_check(over and both.forfeit and both.match_over() and both.winners() == [0, 1],
			"2 against 2: both players of a team leave, the 2 players of the other team win at once (%s)" % str(both.winners()))
	var m := _match([0, 1, 2, 3])
	m.remove_player(2)
	_check(m.team_of(0) == 0 and m.team_of(1) == 0 and m.team_of(3) == 1,
			"the match keeps the team of every character after a leave")
	var three := _match([0, 1, 2])
	for i in 4:
		three.rules.score_point(0)   # Slot 0 (alone) wins the game: the single is slot 1 now.
	three.remove_player(2)
	for s in three.chars:
		_check(three.team_of(s) == three.rules.team_of(s),
				"3 players, one leaves: the character of slot %d follows the new team" % s)


## Quick with 3 players: the teams change every 2 points, so the score shown for a team is the tally of its players.
func _quick_three() -> void:
	print("Quick with 3 players")
	var r := Rules.new()
	r.setup([0, 1, 2], true)
	r.score_point(0)
	r.score_point(0)   # The team of slot 0 has 2 points; the teams change now.
	for team in 2:
		for s in r.teams[team]:
			_check(int(r.point_text(team)) >= int(r.tally[s]),
					"Quick, 3 players: the score of team %d is not below slot %d (%d)" % [team, s, r.tally[s]])
	_check(r.point_text(r.team_of(0)) == "2",
			"Quick, 3 players: the team of slot 0 that won both points shows 2 (%s)" % r.point_text(r.team_of(0)))


# ---- Added for the automated half of Manual test 25 ----

## One phone for the chain tests: a `PlayerInput` that gets a trace, and the swings that it found.
class Rig:
	var pi: PlayerInput
	var tick := 0
	var infos: Array = []

	func _init(slot: int) -> void:
		pi = PlayerInput.new(slot, {})
		pi.on_join("Rig%d" % slot, "t")
		pi.swung.connect(func(i: Dictionary) -> void: infos.append(i))
		tick = Trace.feed(pi, Trace.rest(0.5), 0)


## Plays `samples` (a trace) on `rig` while the match runs: the first sample goes in at the match time `peak - lead`, where
## `lead` is the time from the start of the trace to the peak of its forward swing. A swing that is found is given to the
## match at once, as the game does. Returns the result of the swing ("none" when no swing was found).
func _play(m: Match, rig: Rig, samples: Array, peak: float, lead := 0.375) -> String:
	var start := peak - lead
	var idx := 0
	var result := "none"
	rig.infos.clear()
	var guard := 0
	while (idx < samples.size() or rig.infos.is_empty()) and guard < 1200:
		guard += 1
		if m.time >= start and idx < samples.size():
			rig.pi.on_sensor(Trace.packet(samples[idx], rig.tick), int(round(float(rig.tick) * Trace.DT * 1000.0)))
			rig.tick += 1
			idx += 1
		elif idx >= samples.size():
			rig.pi.on_sensor(Trace.packet(Vector3.ZERO, rig.tick), int(round(float(rig.tick) * Trace.DT * 1000.0)))
			rig.tick += 1
		m.tick(DT)
		if not rig.infos.is_empty():
			var i: Dictionary = rig.infos[0]
			result = m.swing(rig.pi.slot, float(i.power), bool(i.down), float(i.side), float(i.hit_age_ms) / 1000.0)
			break
	# The rest of the trace and a quiet second, so that the detector is ready for the next swing.
	for k in range(idx, samples.size()):
		rig.pi.on_sensor(Trace.packet(samples[k], rig.tick), int(round(float(rig.tick) * Trace.DT * 1000.0)))
		rig.tick += 1
	rig.tick = Trace.feed(rig.pi, Trace.rest(1.0), rig.tick)
	return result


## A 2 player match in which slot 1 has to hit (after the serve of slot 0), seed `seed_value`.
func _ready_to_return(difficulty := "medium", seed_value := 5, wait := true) -> Match:
	var m := Match.new()
	m.setup([0, 1], false, difficulty, seed_value)
	_serve_now(m, 0.5)
	if wait:
		_until_contact(m)
	return m


## REQ-TN-6, 18: the width of the green part of the hit window is twice the half width of the level.
func _green_window() -> void:
	print("the green part of the hit window")
	for d in ["easy", "medium", "hard"]:
		var greens := 0
		var any := 0
		for i in range(-30, 31):
			var m := _ready_to_return(d)
			var age := float(i) * 0.02   # The hit was `age` s before the contact (negative: after it).
			var r := m.swing(1, 0.5, false, 0.0, age)
			if r == "hit":
				any += 1
				if m.take_events().filter(func(e: Dictionary) -> bool: return e.t == "hit")[-1].green:
					greens += 1
		var w := float(greens) * 0.02
		var want: float = 2.0 * float(Rules.level(d).green)
		_check(absf(w - want) <= 0.05, "%s: the green part is %.2f s wide (wanted %.2f s)" % [d, w, want])
		_check(absf(float(any) * 0.02 - 2.0 * Match.HIT_W) <= 0.05,
				"%s: the whole hit window is %.2f s wide" % [d, float(any) * 0.02])
	var wm: float = 2.0 * float(Rules.level("medium").green)
	var we: float = 2.0 * float(Rules.level("easy").green)
	var wh: float = 2.0 * float(Rules.level("hard").green)
	_check(absf(wm - 0.42) < 0.001 and absf(we - 0.60) < 0.001 and absf(wh - 0.30) < 0.001,
			"the widths of the green part are 0.60 s (Easy), 0.42 s (Medium) and 0.30 s (Hard) (REQ-TN-18)")


## The first bounce of the ball in play: `{pos, t}` (seconds after now), or an empty Dictionary.
func _first_bounce(m: Match) -> Dictionary:
	var t0 := m.time
	m.take_events()   # The events of the serve and of the hit itself do not count.
	for i in 400:
		m.tick(DT)
		for e in m.take_events():
			if e.t == "bounce" or e.t == "out":
				return {"pos": e.pos, "t": m.time - t0, "out": e.t == "out"}
			if e.t == "net":
				return {}
	return {}


## REQ-TN-7: a stronger swing is a longer and faster ball.
func _power_and_distance() -> void:
	print("power: distance and flight time")
	var longer := 0
	var faster := 0
	for seed_value in range(1, 6):
		var soft := _ready_to_return("medium", seed_value)
		soft.swing(1, 0.2 + 0.05 * float(seed_value), false, 0.0, 0.0)
		var sb := _first_bounce(soft)
		var hard := _ready_to_return("medium", seed_value)
		hard.swing(1, 0.7 + 0.06 * float(seed_value), false, 0.0, 0.0)
		var hb := _first_bounce(hard)
		if not sb.is_empty() and not hb.is_empty():
			longer += 1 if absf(float(hb.pos.y)) > absf(float(sb.pos.y)) + 2.0 else 0
			faster += 1 if float(hb.t) < float(sb.t) - 0.1 else 0
	_check(longer == 5, "a hard swing (0.76 to 1.0) lands deeper than a soft one (0.25 to 0.45) in 5 of 5 pairs (%d)" % longer)
	_check(faster == 5, "and the ball is in the air a shorter time in 5 of 5 pairs (%d)" % faster)


## REQ-TN-4, 18: on Easy the ball stays inside the lines, also with the hardest swing and any side.
func _easy_stays_in() -> void:
	print("Easy: 10 hardest swings stay in")
	var outs := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 10:
		var m := _ready_to_return("easy", 20 + k)
		m.swing(1, 1.0, false, rng.randf_range(-1.0, 1.0), 0.0)
		var b := _first_bounce(m)
		outs += 1 if b.is_empty() or bool(b.out) else 0
	_check(outs == 0, "no out event in 10 hits with power 1.0 and a random side (%d out)" % outs)


## REQ-TN-1: 3 and 4 players play on the same doubles court; 2 players and the rally use the singles lines.
func _court_width() -> void:
	print("the court is the same for 3 and 4 players")
	var w3 := _match([0, 1, 2]).half_width()
	var w4 := _match([0, 1, 2, 3]).half_width()
	_check(w3 == w4 and is_equal_approx(w3, Sim.HALF_W_DOUBLES), "3 and 4 players: the doubles court, the same sidelines")
	_check(is_equal_approx(_match([0, 1]).half_width(), Sim.HALF_W_SINGLES), "2 players: the singles lines")


## REQ-TN-15: with 1 player the first ball comes soon, and the round lasts 90 s.
func _solo_clock() -> void:
	print("1 player: the first ball and the 90 s")
	var m := _match([0])
	var t_first := -1.0
	var t_end := -1.0
	for i in int(95.0 / DT):
		m.tick(DT)
		if t_first < 0.0 and m.sim.active:
			t_first = m.time
		if m.is_over():
			t_end = m.time
			break
	_check(t_first > 0.0 and t_first <= 5.0, "the machine sends the first ball after %.1f s (at most 5 s)" % t_first)
	_check(absf(t_end - 90.0) <= 0.1, "the round is over after %.1f s (90 s, REQ-TN-15)" % t_end)


## REQ-GM-73: no difficulty has medal tiers.
func _medal_tiers() -> void:
	print("no medal tiers")
	var none := true
	for d in ["easy", "medium", "hard"]:
		none = none and not Rules.level(d).has("tiers")
	_check(none, "no difficulty has medal tiers (REQ-TN-16)")


## The chain from a trace of the phone to the ball: the swing detector of a slot, the match, the landing place (REQ-TN-5 to 9).
func _swing_chain() -> void:
	print("traces: serve, hit, aim")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# 3c: the serve swing around the top of the toss, with a jitter of +/- 0.1 s.
	var served := 0
	for k in 10:
		var m := _match([0, 1])
		var rig := Rig.new(0)
		m.press_a(0)
		var peak: float = m._toss_apex + rng.randf_range(-0.1, 0.1)
		var res := _play(m, rig, Trace.stroke(Vector3(0, 0, -1), 10.0, 25.0), peak)
		served += 1 if res == "serve" else 0
	_check(served >= 8, "a swing from top to bottom around the top of the toss serves: %d of 10 (3c)" % served)
	# 3e: forehands (not down) around the top of the toss do nothing.
	var wrong := 0
	for k in 5:
		var m2 := _match([0, 1])
		var rig2 := Rig.new(0)
		m2.press_a(0)
		wrong += 1 if _play(m2, rig2, Trace.stroke(Vector3(1, 0, 0), 10.0, 25.0), m2._toss_apex) != "none" else 0
	_check(wrong == 0, "a forehand at the top of the toss never serves (0 of 5)")
	# Issue #419: the window is 0.6 s each side of the top of the toss, from the toss until the ball is back at the hand.
	var m_late := _match([0, 1])
	m_late.press_a(0)
	while m_late.time < m_late._toss_apex + 0.5 and m_late.phase == Match.Phase.TOSS:
		m_late.tick(DT)
	_check(m_late.phase == Match.Phase.TOSS and m_late.swing(0, 0.6, true, 0.0, 0.0) == "serve",
			"a swing 0.5 s after the top of the toss serves (too late with 0.45 s) (issue #419)")
	var m_early := _match([0, 1])
	m_early.press_a(0)
	_check(m_early.swing(0, 0.6, true, 0.0, 0.0) == "serve",
			"a swing at the moment of the toss (0.47 s before the top) serves (#419)")
	var m_back := _match([0, 1])
	m_back.press_a(0)
	_check(m_back.swing(0, 0.6, true, 0.0, 0.1) == "serve",
			"a swing that is reported at the toss and was hit 0.1 s before the press still serves (REQ-TN-9, #419)")
	var m_flat := _match([0, 1])
	m_flat.press_a(0)
	while m_flat.time < m_flat._toss_apex + 0.5 and m_flat.phase == Match.Phase.TOSS:
		m_flat.tick(DT)
	_check(m_flat.swing(0, 0.6, false, 0.0, 0.0) == "none", "a swing that is not down at the end of the toss does nothing (#419)")
	# 4d: swings with the hit inside the green part come back, green.
	var returned := 0
	var green := 0
	for k in 10:
		var m3 := _ready_to_return("medium", 30 + k, false)
		var rig3 := Rig.new(1)
		var at: float = float(m3.contact.t) + rng.randf_range(-0.15, 0.15)
		var res3 := _play(m3, rig3, Trace.stroke(Vector3(1, 0, 0), 10.0, 25.0), at)
		if res3 == "hit":
			returned += 1
			green += 1 if m3.take_events().filter(func(e: Dictionary) -> bool: return e.t == "hit")[-1].green else 0
	_check(returned >= 8 and green >= 7,
			"swings with the hit inside the green part return the ball: %d of 10, %d green (4d)" % [returned, green])
	# 4f: a back swing and a sharp push, and a slow wide swing, are both found (the hand moves differently).
	var push := 0
	var wide := 0
	for k in 5:
		var m4 := _ready_to_return("medium", 50 + k, false)
		var back := Trace.stroke(Vector3(1, 0, 0), 8.0, 0.0, 0.3, 0.1)
		var strike: Array = [Vector3(30, 0, 0), Vector3(30, 0, 0), Vector3(30, 0, 0), Vector3(15, 0, 0)]
		var res4 := _play(m4, Rig.new(1), back + strike, float(m4.contact.t), 0.3)
		push += 1 if res4 == "hit" else 0
		var m5 := _ready_to_return("medium", 60 + k, false)
		var res5 := _play(m5, Rig.new(1), Trace.stroke(Vector3(1, 0, 0), 4.0, 8.0, 0.5, 0.5), float(m5.contact.t), 0.75)
		wide += 1 if res5 == "hit" else 0
	_check(push >= 4, "a back swing and a sharp push return the ball: %d of 5 (4f)" % push)
	_check(wide >= 4, "a slow, wide swing returns the ball: %d of 5 (4f)" % wide)
	# 6c, 6d, 6e: the side of the swing decides where the ball lands. The mean direction of the player's own swings is
	# "straight" (REQ-TN-7), so right and left swings alternate, as in a game.
	var dirs := {"right": Vector3(0.5, 0.866, 0), "left": Vector3(-0.5, 0.866, 0), "straight": Vector3(0, 1, 0)}
	var counts := {"right": 0, "left": 0, "straight": 0}
	var rig6 := Rig.new(0)   # One phone swings both ways, so its heading stays about straight.
	for k in 10:
		for name in ["right", "left"]:
			var m6 := _ready_to_return("medium", 70 + k, false)
			_until_contact(m6)
			m6.swing(1, 0.5, false, 0.0, 0.0)
			if m6.hitter != 0:
				continue
			_play(m6, rig6, Trace.stroke(dirs[name], 10.0, 25.0), float(m6.contact.t))
			var b := _first_bounce(m6)
			if b.is_empty():
				continue
			if name == "right" and float(b.pos.x) > 0.0:
				counts.right += 1
			if name == "left" and float(b.pos.x) < 0.0:
				counts.left += 1
	_check(counts.right >= 8, "a swing 30 degrees to the right lands in the right half: %d of 10 (6c)" % counts.right)
	_check(counts.left >= 8, "a swing 30 degrees to the left lands in the left half: %d of 10 (6d)" % counts.left)
	var mid := 0
	var rig_s := Rig.new(0)
	for k in 10:
		var m7 := _ready_to_return("medium", 90 + k)
		m7.swing(1, 0.5, false, 0.0, 0.0)
		if m7.hitter != 0:
			continue
		_play(m7, rig_s, Trace.stroke(dirs.straight if k % 2 == 0 else Vector3(0, 0, 1), 10.0, 25.0), float(m7.contact.t))
		var b2 := _first_bounce(m7)
		if not b2.is_empty() and absf(float(b2.pos.x)) < m7.half_width() / 3.0:
			mid += 1
	_check(mid >= 8, "a straight swing and a nearly vertical swing land in the middle third: %d of 10 (6e)" % mid)
