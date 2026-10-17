extends SceneTree
## The rules of Tennis without a screen: the score, the teams, the ball, the serve, the rally and the 1 player rally
## (docs/games/tennis.md, REQ-TN-1 to 20). Run: godot --headless --path . --script tests/tennis_rules.gd -- --role=controller

const Sim = preload("res://scripts/game/tennis/tennis_sim.gd")
const Rules = preload("res://scripts/game/tennis/tennis_rules.gd")
const Match = preload("res://scripts/game/tennis/tennis_match.gd")

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
	_scoring_real()
	_scoring_quick()
	_teams()
	_ball()
	_serve()
	_rally()
	_points()
	_matches()
	_solo()
	_leaving()
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
	_check(end.match and r.match_over() and r.winners() == [0], "the first player with 3 games wins the match")


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
	_check(last.match and r.winners() == [0] and r.tally[0] == 5, "the first to 5 points wins")
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
	_check(m.swing(0, 0.6, true, 0.0, 0.0) == "none", "a swing long before the top of the toss does nothing")
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
	o.swing(1, 1.0, false, -1.0, 0.0)   # The hardest swing with the widest aim, on Medium: out.
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
	_check(returns >= 5 and r.rules.points == [0, 0], "a rally goes on while the balls are returned and in (%d returns)" % returns)


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
	_check(m.phase == Match.Phase.RALLY and m.expect_team == 0 and m.hitter == 3, "the machine sends the first ball to the player")
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
