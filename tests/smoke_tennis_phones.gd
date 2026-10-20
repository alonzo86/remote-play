extends SceneTree
## Tennis with simulated phones, the automated half of Manual test 25: sensor traces go into the phone slots of the TV and the
## game reacts as it would to a real swing (the serve, the hit, the buzz), the ring on the court, the hint, the banners, the
## 4 phone scoreboard and places, and the 1 player round. Run:
##   godot --headless --path . --script tests/smoke_tennis_phones.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Trace = preload("res://tests/golf_tennis_trace.gd")

const DT := 1.0 / 60.0

var _fails := 0
var _checks := 0
var _ticks := {}      # slot -> the sensor tick of that phone
var _buzzes := {}     # slot -> the buzzes that the phone got
var _player_hits := 0 # The balls that a player hit in the last `_play()` (the last hitter changed from the machine to a player).


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _join_to(app: Node, clients: Array, n: int) -> void:
	while clients.size() < n:
		var i := clients.size()
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
		_buzzes[i] = 0
		c.haptic_requested.connect(func(_ms: int) -> void: _buzzes[i] += 1)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame


## Skips the countdown and keeps the tick gap short, so that swings count.
func _go(game: Control) -> void:
	game._clock.time = -0.01
	game._game_tick(0.02)
	game._game_tick(0.016)


func _tick_n(game: Control, seconds: float, step := 0.05) -> void:
	for i in int(round(seconds / step)):
		game._game_tick(step)


## Plays a trace on the phone of `slot` while the game runs. The first sample goes in at the game time `peak - lead`. Returns
## true when the phone found a swing.
func _play(game: Control, slot: int, samples: Array, peak: float, lead := 0.375) -> bool:
	var pl = game.player(slot)
	var found := [false]
	var cb := func(_i: Dictionary) -> void: found[0] = true
	pl.swung.connect(cb)
	var start := peak - lead
	var idx := 0
	var guard := 0
	while idx < samples.size() and guard < 2000:
		guard += 1
		var before: int = game.play.hit_team
		if game.play.time >= start:
			var tk: int = _ticks.get(slot, 0)
			pl.on_sensor(Trace.packet(samples[idx], tk), int(round(float(tk) * Trace.DT * 1000.0)))
			_ticks[slot] = tk + 1
			idx += 1
		game._game_tick(DT)
		if before == 1 and game.play.hit_team == 0:
			_player_hits += 1
	for i in 90:   # A quiet 1.5 s: the detector is ready again.
		var before2: int = game.play.hit_team
		var tk2: int = _ticks.get(slot, 0)
		pl.on_sensor(Trace.packet(Vector3.ZERO, tk2), int(round(float(tk2) * Trace.DT * 1000.0)))
		_ticks[slot] = tk2 + 1
		game._game_tick(DT)
		if before2 == 1 and game.play.hit_team == 0:
			_player_hits += 1
	pl.swung.disconnect(cb)
	return found[0]


## Lets the phone settle: a first packet gives the orientation its gravity.
func _settle(game: Control) -> void:
	for s in game.participants:
		var pl = game.player(s)
		var tk: int = _ticks.get(s, 0)
		for i in 30:
			pl.on_sensor(Trace.packet(Vector3.ZERO, tk), int(round(float(tk) * Trace.DT * 1000.0)))
			tk += 1
		_ticks[s] = tk


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var Tennis = load("res://scripts/game/tennis/tennis_game.gd")
	var GameSettings = load("res://scripts/game/game_settings.gd")
	var app: Node = root.get_node("App")
	app.set_language("en", false)
	GameSettings.clear()
	var clients: Array = []
	await _join_to(app, clients, 2)
	await _frames(2)

	# ---- The countdown and the first screen (2 phones) ----
	app.go(Tennis, {"difficulty": "medium", "scoring": "real"})
	await _frames(3)
	var game: Control = app.current_screen()
	var spots: Dictionary = game.countdown_spots(game.Look.Proj.new(game.size))
	var inside := true
	for s in spots:
		inside = inside and Rect2(Vector2.ZERO, game.size).has_point(spots[s])
	_check(spots.size() == 2 and spots.has(0) and spots.has(1) and inside and spots[0] != spots[1]
			and game.player(0).player_name != game.player(1).player_name and game.player(0).player_name != "",
			"the countdown has a name tag for each of the 2 phones, on the screen, with the phone names (2a)")
	_check(not game._board.has_lead() and game.play.rules.tally[0] == 0 and game.play.rules.tally[1] == 0,
			"before the first point nobody leads, so the leader chip is not drawn (2c)")
	_check(game.difficulty == "medium", "the difficulty is Medium by default (1a)")
	_go(game)
	_settle(game)
	_check(game._hint() == "tennis.hint_serve" and Lang.t("tennis.hint_serve").begins_with("PRESS A TO TOSS"),
			"at GO the hint line is the serve hint: %s (3a)" % Lang.t("tennis.hint_serve"))
	_tick_n(game, 14.0)
	_check(game._hint() == "tennis.hint_serve", "the hint is still there after 14 s")
	_tick_n(game, 4.0)
	_check(game._hint() == "", "the hint is gone after 18 s (3a)")
	await _frames(1)

	# ---- 3c: the serve with a trace, the buzz ----
	var served := 0
	var buzz_ok := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for k in 10:
		app.go(Tennis, {"difficulty": "medium", "scoring": "real"})
		await _frames(3)
		var g: Control = app.current_screen()
		_go(g)
		_settle(g)
		await _frames(3)
		var server: int = g.play.server_slot()
		_buzzes[server] = 0
		g._on_button(Protocol.BTN_A, server)
		var peak: float = g.play._toss_apex + rng.randf_range(-0.1, 0.1)
		_play(g, server, Trace.stroke(Vector3(0, 0, -1), 10.0, 25.0), peak)
		await _frames(3)
		if g.play.serve_ball or g.play.phase == g.Match.Phase.RALLY or g.play.phase == g.Match.Phase.POINT:
			served += 1
			buzz_ok += 1 if _buzzes[server] == 1 else 0
	_check(served >= 8, "a swing from top to bottom around the top of the toss serves: %d of 10 (3c)" % served)
	_check(buzz_ok == served, "each serve buzzes the phone once: %d of %d (3c)" % [buzz_ok, served])

	# ---- The ring, the glow, the green part (4a, 4b, 5c, 5d) ----
	for d in ["easy", "medium", "hard"]:
		app.go(Tennis, {"difficulty": d, "scoring": "real"})
		await _frames(3)
		var g2: Control = app.current_screen()
		_go(g2)
		_settle(g2)
		var server2: int = g2.play.server_slot()
		g2._on_button(Protocol.BTN_A, server2)
		_tick_n(g2, 4.6 / 9.81, 0.016)
		g2._on_swing({"power": 0.5, "down": true, "side": 0.0, "hit_age_ms": 0.0}, server2)
		var first_green := 99.0
		var frames_green := 0
		var yellow_before := false
		var shown := 0
		var glow_all := true
		for i in 240:
			g2._game_tick(DT)
			if g2.play.phase != g2.Match.Phase.RALLY:
				break
			var ring: Dictionary = g2.ring_state()
			if ring.show:
				shown += 1
				glow_all = glow_all and g2._hits_pending()
				if ring.green:
					frames_green += 1
					if first_green > 90.0:
						first_green = float(ring.left)
				elif frames_green == 0:
					yellow_before = true
		var want: float = 2.0 * float(g2.play.level.green)
		_check(absf(float(frames_green) * DT - want) <= 0.05, "%s: the ring is green for %.2f s (wanted %.2f s) (5c, 5d)"
				% [d, float(frames_green) * DT, want])
		_check(yellow_before and absf(first_green - float(g2.play.level.green)) <= 0.03,
				"%s: the ring is yellow, and turns green %.2f s before the contact (4b)" % [d, first_green])
		_check(shown > 60 and glow_all, "%s: the ball glows for the whole time the ring shows (4a)" % d)

	# ---- The banners of 8 outcomes (7d) ----
	app.go(Tennis, {"difficulty": "medium", "scoring": "real"})
	await _frames(3)
	var b: Control = app.current_screen()
	_go(b)
	var cases := [
		[{"t": "out"}, "OUT", ""], [{"t": "net"}, "NET", ""], [{"t": "fault"}, "FAULT", ""],
		[{"t": "point", "team": 0, "game": false, "status": ""}, "POINT: " + b.player(0).player_name, ""],
		[{"t": "point", "team": 1, "game": false, "status": "deuce"}, "POINT: " + b.player(1).player_name, "DEUCE"],
		[{"t": "point", "team": 0, "game": true, "status": ""}, "GAME: " + b.player(0).player_name, ""],
		[{"t": "rally_over", "rally": 7}, "RALLY 7", ""],
	]
	for c in cases:
		b._banner = ""
		b._banner_sub = ""
		b._handle_events([c[0]])
		_check(Lang.t(b._banner) == c[1] and b._banner_sub == c[2], "the event %s shows the banner '%s'" % [c[0].t, c[1]])
	b.play.rules.points = [4, 3]
	b._banner_sub = ""
	b._handle_events([{"t": "point", "team": 0, "game": false, "status": "advantage"}])
	_check(b._banner_sub == "ADVANTAGE: " + b.player(0).player_name, "an advantage names the team: %s" % b._banner_sub)

	# ---- 4 phones: the scoreboard and the places (9d, 9e) ----
	await _join_to(app, clients, 4)
	app.go(Tennis, {"difficulty": "medium", "scoring": "real"})
	await _frames(3)
	var f: Control = app.current_screen()
	var ok_colors := true
	for s in 4:
		ok_colors = ok_colors and f.player(s).color == Protocol.PLAYER_COLORS[s] and f.player(s).player_name != ""
	_check(f.participants.size() == 4 and ok_colors and f._team_names(0) == f.player(0).player_name + " + " + f.player(1).player_name
			and f._team_names(1) == f.player(2).player_name + " + " + f.player(3).player_name,
			"4 phones: the scoreboard rows have the names and colors of the phones, team by team (9d)")
	var distinct := true
	for i in 4:
		for j in range(i + 1, 4):
			distinct = distinct and f.player(i).color != f.player(j).color
	_check(distinct, "the 4 player colors are different")
	_go(f)
	for i in 4:
		f.play.rules.score_point(0)
	f._sync_board()
	f._game_tick(0.016)
	await _frames(4)
	_check(clients[0].score_rank == 1 and clients[1].score_rank == 1 and clients[2].score_rank == 3 and clients[3].score_rank == 3,
			"the team in front has place 1 on both of its phones, the other team shares place 3 "
			+ "(REQ-GM-72: equal scores share a place) (9e): %s"
			% [[clients[0].score_rank, clients[1].score_rank, clients[2].score_rank, clients[3].score_rank]])
	_check(f.leader_text() == "1" and f._board.leaders().size() == 2, "the leader chip shows the 1 game of the team in front")

	# ---- 1 phone: the machine, the buzz of every hit (4d, 10a, 10c) ----
	for i in [3, 2, 1]:
		clients[i].leave()
	var left_at := Time.get_ticks_msec()
	while app.server.connected_slots().size() > 1 and Time.get_ticks_msec() - left_at < 4000:
		await process_frame
	app.go(Tennis, {"difficulty": "medium"})
	await _frames(3)
	var solo: Control = app.current_screen()
	_go(solo)
	_settle(solo)
	var t_first := -1.0
	for i in 400:
		solo._game_tick(0.016)
		if solo.play.sim.active:
			t_first = solo._playing
			break
	_check(t_first > 0.0 and t_first <= 5.0, "alone, the machine sends the first ball %.1f s after GO (10a)" % t_first)
	_player_hits = 0
	await _frames(5)   # The buzz of GO has arrived.
	var buzzes_before := int(_buzzes[0])
	for k in 5:
		solo._haptics._last.clear()
		var guard := 0
		while (solo.play.hitter != 0 or solo.play.contact.is_empty() or float(solo.play.contact.t) - solo.play.time < 0.8) \
				and guard < 3000:
			solo._game_tick(DT)
			guard += 1
		var hit_t: float = float(solo.play.contact.t)
		var found := _play(solo, 0, Trace.stroke(Vector3(1, 0, 0), 10.0, 25.0), hit_t)
		_check(found, "the phone found the swing %d" % (k + 1))
		await _frames(3)
	var buzz_count := int(_buzzes[0]) - buzzes_before
	_check(_player_hits >= 4 and buzz_count == _player_hits,
			"5 swings at the contact time of the machine ball: %d returned, the phone buzzed %d times, once for each (4d)"
			% [_player_hits, buzz_count])

	# 10c: the round is 90 s, the result menu opens 2.2 s later.
	app.go(Tennis, {"difficulty": "easy"})
	await _frames(3)
	var round: Control = app.current_screen()
	_go(round)
	var t_over := -1.0
	var t_menu := -1.0
	for i in int(100.0 / 0.05):
		round._game_tick(0.05)
		if t_over < 0.0 and round.play.is_over():
			t_over = round._playing
		if round.is_over:
			t_menu = round._playing
			break
	_check(absf(t_over - 90.0) <= 0.5 and t_menu > t_over and t_menu - t_over <= 2.5,
			"alone, the round ends after %.1f s and the result menu opens %.1f s later (10c)" % [t_over, t_menu - t_over])

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
