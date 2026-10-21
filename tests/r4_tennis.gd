extends SceneTree
## Tennis, the rest of Test 25 (docs/MANUAL_TESTS.md test 25), with simulated phones and a fixed time step: no leader chip before
## the first point (2c), the toss goes up at once and falls when nobody swings (3b, 3d), the character runs by itself into the
## ring (4c), GREAT! for a green swing and not for an early or a late one (5a, 5b), wide and long shots keep the characters on
## the screen and the swings return the ball (6b), the place of a phone is the place of its team (9e), the rally count, the best
## rally and the new rally after a miss (10b). The round of 90 s (10c) is in tests/smoke_tennis_phones.gd.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/r4_tennis.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const Shell = preload("res://scripts/game/shell.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Match = preload("res://scripts/game/tennis/tennis_match.gd")
const Look = preload("res://scripts/game/tennis/tennis_look.gd")

const DT := 1.0 / 60.0

var _checks := 0
var _fails := 0
var _app: Node
var _tennis: GDScript
var _clients: Array = []
var _log: Array = []   # What the game drew: {kind, msg}.
var _game: Control


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A check of something that is wrong today: it counts as a failure until the bug is fixed.
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: use _check)")
	else:
		_fails += 1
		print("  FAIL (known bug) ", issue, ": ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_app.set_language("en", false)
	_tennis = load("res://scripts/game/tennis/tennis_game.gd")
	load("res://scripts/game/game_settings.gd").clear()
	_clients = await SimInput.connect_phones(self, _app, 2)
	await _leader_chip()
	await _toss()
	await _runs_and_great()
	_wide_and_long()
	await _places()
	_rally_count()
	Shell.recorder = Callable()
	for c in _clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _on_note(kind: String, ci: CanvasItem, _rect: Rect2, info: Dictionary) -> void:
	if ci == _game and (kind == "plate" or kind == "leader"):
		_log.append({"kind": kind, "msg": String(info.get("msg", ""))})


## A game for the connected phones, after the countdown.
func _new_game(props := {"difficulty": "medium", "scoring": "real"}) -> Control:
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	_game = SimInput.start_game(_app, _tennis, props)
	await _frames(3)
	SimInput.to_play(_game, func() -> bool: return _game._clock.is_counting())
	Shell.recorder = _on_note
	return _game


func _draw_once(game: Control) -> void:
	_log.clear()
	game.queue_redraw()
	await process_frame
	await process_frame


func _drawn(kind: String, msg := "") -> bool:
	return _log.any(func(e: Dictionary) -> bool: return e.kind == kind and (msg == "" or e.msg == msg))


## Runs the game until its match clock reaches `t`.
func _until(game: Control, t: float) -> void:
	var guard := 0
	while game.play.time < t and guard < 3000:
		game._process(DT)
		guard += 1


func _swing(game: Control, slot: int, power: float, down: bool, side := 0.0) -> void:
	game._on_swing({"power": power, "down": down, "side": side, "hit_age_ms": 0.0}, slot)


## The server tosses (A) and swings from top to bottom `offset` seconds from the top of the toss.
func _serve(game: Control, offset := 0.0, power := 0.5) -> int:
	var server: int = game.play.server_slot()
	game._on_button(Protocol.BTN_A, server)
	_until(game, game.play._toss_apex + offset)
	_swing(game, server, power, true)
	return server


# ---- 2c: no leader chip before the first point ----

func _leader_chip() -> void:
	print("the leader chip")
	var game := await _new_game()
	await _draw_once(game)
	_check(not _drawn("leader"), "2c: before the first point the top bar draws no leader chip")
	for i in 4:   # With Real scoring the chip says something after the first game.
		game.play.rules.score_point(0)
	game._sync_board()
	game._process(DT)
	await _draw_once(game)
	_check(_drawn("leader"), "2c: after the first game the leader chip is drawn")


# ---- 3b, 3d: the toss ----

func _toss() -> void:
	print("the toss")
	var game := await _new_game()
	var server: int = game.play.server_slot()
	game._on_button(Protocol.BTN_A, server)
	_check(game.play.phase == Match.Phase.TOSS and game.play.sim.active, "3b: A starts the toss at once")
	var top := 0.0
	var t := 0.0
	while t < 0.5:
		game._process(DT)
		t += DT
		top = maxf(top, game.play.sim.pos.z)
	_check(top - Match.TOSS_FROM >= 0.5, "3b: within 0.5 s the ball went up %.2f m" % (top - Match.TOSS_FROM))
	# 3d: no swing. The ball is taken away when it is back near the hand (it fell) and the server tosses again.
	var fell := SimInput.run_until(game, func() -> bool: return game.play.phase == Match.Phase.SERVE, 3.0)
	var total := t + fell
	_check(game.play.phase == Match.Phase.SERVE and total >= 0.5 and total <= 1.5,
			"3d: with no swing the ball is down %.2f s after the toss (0.5 to 1.5 s) and the server can toss again" % total)
	game._on_button(Protocol.BTN_A, server)
	_check(game.play.phase == Match.Phase.TOSS, "3d: A tosses again (no fault, no point lost)")
	_check(game.play.rules.tally[0] == 0 and game.play.rules.tally[1] == 0 and game.play.faults == 0, "3d: and no point was scored")


# ---- 4c, 5a, 5b: the runs and GREAT! ----

func _runs_and_great() -> void:
	print("the runs and the green part")
	var game := await _new_game()
	var green: float = game.play.level.green
	# A green serve, then 5 green returns, one after the other. The character runs by itself and stands in the ring.
	_serve(game)
	_check(game.play.phase == Match.Phase.RALLY and game.play.serve_ball, "5a: a serve at the top of the toss is hit")
	var greats := 0
	var great_drawn := 0
	var in_ring := 0
	var moved := 0
	for k in 5:
		if game.play.phase != Match.Phase.RALLY or game.play.hitter < 0:
			break
		var hitter: int = game.play.hitter
		var c_pos: Vector2 = game.play.chars[hitter].pos
		var contact: Vector3 = game.play.contact.pos
		_until(game, float(game.play.contact.t) - 0.01)
		var now: Vector2 = game.play.chars[hitter].pos
		if now.distance_to(c_pos) > 0.5 or c_pos.distance_to(Vector2(contact.x, contact.y)) < 0.8:
			moved += 1
		var ring := Vector2(contact.x, contact.y).distance_to(now)
		in_ring += 1 if ring <= 0.8 else 0
		_swing(game, hitter, 0.6, false)
		game._process(DT)   # The events of the hit are handled in the next step.
		await _draw_once(game)
		greats += 1 if game._great.has(hitter) else 0
		great_drawn += 1 if _drawn("plate", "tennis.great") else 0
	_check(moved == 5, "4c: the character of the other team ran by itself before each of 5 hits (%d of 5)" % moved)
	_check(in_ring == 5, "4c: at the hit it stood inside the ring (0.8 m) in %d of 5" % in_ring)
	_check(greats == 5 and great_drawn == 5, "5a: 5 of 5 green swings show GREAT! (%d, drawn %d)" % [greats, great_drawn])
	_known_bug("issue-needed: REQ-TN-6 and step 5a want sparks on a green hit; no code draws sparks (only the GREAT! plate)",
			FileAccess.get_file_as_string("res://scripts/game/tennis/tennis_game.gd").to_lower().contains("spark")
			or FileAccess.get_file_as_string("res://scripts/game/tennis/tennis_look.gd").to_lower().contains("spark"),
			"5a: a green hit shows sparks")
	# 5b: the second player swings early and late, the first player returns green. The ball stays in play.
	var game2 := await _new_game()
	_serve(game2)
	var trials := ["early", "late", "early", "late", "early", "late", "early", "late", "early", "late"]
	var done := 0
	var stayed := 0
	var no_great := 0
	var bad_banner := false
	var offset := green + 0.04
	while done < trials.size() and game2.play.phase == Match.Phase.RALLY and game2.play.hitter >= 0:
		var hitter2: int = game2.play.hitter
		var t_c := float(game2.play.contact.t)
		if hitter2 == 1:
			var off := -offset if trials[done] == "early" else offset
			_until(game2, t_c + off)
			_swing(game2, hitter2, 0.6, false)
			game2._process(DT)
			no_great += 0 if game2._great.has(hitter2) else 1
			done += 1
			# The ball goes on to the other side: wait for the next contact and see that the rally is still on.
			if game2.play.phase == Match.Phase.RALLY and game2.play.hitter == 0 and not game2.play.contact.is_empty():
				_until(game2, float(game2.play.contact.t) - 0.05)
				var banner: String = game2._banner if game2._banner_left > 0.0 else ""
				bad_banner = bad_banner or banner == "tennis.out" or banner == "tennis.net"
				if game2.play.phase == Match.Phase.RALLY and game2.play.hitter == 0:
					stayed += 1
		else:
			_until(game2, t_c)
			_swing(game2, hitter2, 0.6, false)
	_check(done == 10 and no_great == 10, "5b: 10 of 10 swings (5 early, 5 late) did not show GREAT! (%d)" % no_great)
	_check(stayed == 10 and not bad_banner,
			"5b: and the ball stayed in play 10 of 10 times (%d), with no OUT or NET banner" % stayed)


# ---- 6b: wide and long ----

## The rectangle of a character on the screen (the body and the hands, 0.35 m to each side, 2 m high).
func _char_rect(p: Look.Proj, pos: Vector2) -> Rect2:
	var s := p.scale(pos.y)
	var foot := p.at(pos.x, pos.y)
	return Rect2(foot.x - 0.35 * s, foot.y - 2.0 * s, 0.7 * s, 2.0 * s)


func _wide_and_long() -> void:
	print("wide and long")
	for n in [2, 4]:
		var slots: Array = []
		for s in n:
			slots.append(s)
		var m := Match.new()
		m.setup(slots, false, "medium", 11 + n)
		var server: int = m.server_slot()
		m.press_a(server)
		var guard := 0
		while m.time < m._toss_apex and guard < 600:
			m.tick(DT)
			guard += 1
		var served := m.swing(server, 0.5, true, 0.0, 0.0) == "serve"
		var attempts := 0
		var returns := 0
		var inside := true
		var worst := ""
		var rects := [Look.Proj.new(Vector2(1920, 1080)), Look.Proj.new(Vector2(1280, 720))]
		var screens := [Rect2(0, 0, 1920, 1080), Rect2(0, 0, 1280, 720)]
		var side := 1.0
		while served and attempts < 5 and m.phase == Match.Phase.RALLY and m.hitter >= 0:
			var hitter: int = m.hitter
			var guard2 := 0
			while m.time < float(m.contact.t) and guard2 < 600:
				m.tick(DT)
				guard2 += 1
				for s in m.chars:
					for i in 2:
						if not screens[i].encloses(_char_rect(rects[i], m.chars[s].pos)):
							inside = false
							worst = "slot %d at %s" % [s, str(m.chars[s].pos)]
			attempts += 1
			if m.swing(hitter, 1.0, false, 0.85 * side, 0.0) == "hit":
				returns += 1
			side = -side
			m.take_events()
		_check(served and attempts == 5 and returns >= 4,
				"6b: %d phones: %d of %d wide and long swings returned the ball" % [n, returns, attempts])
		_check(inside, "6b: %d phones: no character left the screen at 1920x1080 and 1280x720 %s" % [n, worst])


# ---- 9e: the place of a phone ----

func _places() -> void:
	print("the places")
	for n in [3, 4]:
		_clients = await SimInput.connect_phones(self, _app, n, _clients)
		var game := await _new_game()
		for i in 4:
			game.play.rules.score_point(0)
		game._sync_board()
		game._process(DT)
		await _frames(6)
		var front: Array = game.play.rules.teams[0]
		var other: Array = game.play.rules.teams[1]
		var front_ok := true
		var other_places := []
		for s in front:
			front_ok = front_ok and _clients[s].score_rank == 1
		for s in other:
			other_places.append(_clients[s].score_rank)
		_check(front.size() >= 1 and front_ok, "9e: %d phones: the phones of the team in front show place 1" % n)
		_known_bug("issue-needed: REQ-TN-13 says each phone shows its own team's place (2 for the other team); the board ranks "
				+ "players, so equal scores share a place and the other team shows 3: %s" % str(other_places),
				other_places.all(func(r: int) -> bool: return r == 2),
				"9e: %d phones: the phones of the other team show place 2" % n)


# ---- 10b: the rally count ----

func _rally_count() -> void:
	print("the rally")
	var m := Match.new()
	m.setup([0], false, "medium", 5)
	var seq: Array[int] = []
	var shown_best := 0
	var t_over := -1.0
	var t_next := -1.0
	var last := 0
	var guard := 0
	while guard < 20000 and t_next < 0.0:
		guard += 1
		var swung := false
		if t_over < 0.0 and m.phase == Match.Phase.RALLY and m.hitter == 0 and not m.contact.is_empty() \
				and m.time >= float(m.contact.t) and m.rally < 5:
			swung = m.swing(0, 0.6, false, 0.0, 0.0) == "hit"
		if not swung:
			m.tick(DT)
		if m.rally != last:
			last = m.rally
			if last > 0:
				seq.append(last)
				shown_best = maxi(m.best_rally, m.rally)
		for e in m.take_events():
			if e.t == "rally_over" and t_over < 0.0:
				t_over = m.time
				_check(int(e.rally) == 5 and int(e.best) == 5, "10b: the rally that ended counted %d, the best is %d" % [e.rally, e.best])
			elif e.t == "hit" and int(e.slot) == -1 and t_over >= 0.0 and t_next < 0.0:
				t_next = m.time
	_check(seq == [1, 2, 3, 4, 5], "10b: the count goes 1, 2, 3, 4, 5: %s" % str(seq))
	_check(shown_best == 5 and Lang.f("tennis.best", [shown_best]).to_upper().ends_with("5"),
			"10b: BEST is 5, the highest count: '%s'" % Lang.f("tennis.best", [shown_best]).to_upper())
	var gap := t_next - t_over
	_check(t_over > 0.0 and t_next > t_over, "10b: after the miss a new rally starts (%.2f s later)" % gap)
	_known_bug("step 10b and REQ-TN-15 say a new rally starts about 2 s (1.5 to 2.5 s) after a miss; the banner (1.8 s) and the "
			+ "wait of the machine (1.6 s) make %.1f s" % gap, gap >= 1.5 and gap <= 2.5, "10b: the new rally starts 1.5 to 2.5 s later")
