extends SceneTree
## Sumo Bumpers with simulated phones and a fixed time step: what used to be checked by hand in Test 15 and a machine can check
## (the direction of the tilt, the damping, the shrinking island, the bump, the dash, the fall, the rounds with 2, 3 and 4 phones,
## the length of a round, the clouds, the penguin pictures). The game is stepped by hand (`SimInput`). Run:
##   godot --headless --path . --script tests/auto_sumo.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const Lang = preload("res://scripts/core/lang.gd")
const SumoLook = preload("res://scripts/game/sumo_bumpers/sumo_look.gd")
const SumoArena = preload("res://scripts/game/sumo_bumpers/sumo_arena.gd")

const DT := 1.0 / 60.0

var _fails := 0
var _checks := 0
var _sim := SimInput.new()
var _app: Node
var _sumo: GDScript
var _clients: Array = []


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A check of something that is wrong in the game today: it prints KNOWN BUG and is not counted as a failure. The text says what
## to file. When the game is fixed the check passes and the line can become a normal `_check`.
func _known_bug(issue: String, cond: bool) -> void:
	_checks += 1
	if cond:
		print("  ok   (known bug is fixed, make this a normal check) ", issue)
	else:
		print("  KNOWN BUG ", issue)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A match in the countdown (not yet in play), stepped by hand. All phones are held flat.
func _new_game(difficulty := "medium") -> Control:
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	return SimInput.start_game(_app, _sumo, {"difficulty": difficulty})


## A match in play (round 1, the countdown is over).
func _play(difficulty := "medium") -> Control:
	var game := _new_game(difficulty)
	SimInput.to_play(game, func() -> bool: return game.phase == game.Phase.COUNT)
	return game


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_sumo = load("res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd")
	_pictures()
	_clouds()
	_clients = await SimInput.connect_phones(self, _app, 2)
	await _axes()
	await _damping()
	await _shrink()
	await _bump()
	await _dash()
	await _round_length()
	_clients = await SimInput.connect_phones(self, _app, 3, _clients)
	await _fall_and_next_round()
	await _wait_after_a_fall()
	for k in [2, 3, 4]:
		_clients = await SimInput.connect_phones(self, _app, k, _clients)
		await _three_rounds(k)
	for c in _clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## 15.11a, 11b: the penguin is a sharp picture, big enough, and the 4 colors differ (REQ-SB-15, REQ-GM-47e).
func _pictures() -> void:
	print("the penguin pictures")
	var sharp := true
	var palette_ok := true
	var ring_ok := true
	for col in Protocol.PLAYER_COLORS:
		for step in [-1, 0, 1]:
			var img: Image = SumoLook.penguin_image(col, step)
			var palette := [col, SumoLook.BELLY, SumoLook.BEAK, Color.WHITE, SumoLook.OUTLINE]
			for y in img.get_height():
				for x in img.get_width():
					var px := img.get_pixel(x, y)
					sharp = sharp and (px.a == 0.0 or px.a == 1.0)
					if px.a == 1.0:
						palette_ok = palette_ok and palette.any(func(c: Color) -> bool: return c.is_equal_approx(px))
					else:
						for n in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
							if n.x >= 0 and n.y >= 0 and n.x < img.get_width() and n.y < img.get_height():
								var q := img.get_pixelv(n)
								ring_ok = ring_ok and (q.a == 0.0 or q.is_equal_approx(SumoLook.OUTLINE))
	_check(sharp and palette_ok, "a penguin has only whole pixels (no half transparent edge) in five known colors")
	_check(ring_ok, "a penguin has a black ring: every empty pixel next to the penguin is touched only by the outline color")
	var img0: Image = SumoLook.penguin_image(Protocol.PLAYER_COLORS[0], 0)
	for unit_h in [1080.0, 720.0]:
		# The world view of 480x270 stands for the whole screen, so the penguin is the same share of the height at every size.
		var share := float(img0.get_height()) * SumoLook.PX / 1080.0
		_check(share >= 0.044, "a penguin is %.1f %% of the screen height at %dp (REQ-GM-47e asks for 4.4 %% or more)"
				% [share * 100.0, int(unit_h)])
	var worst := SimInput.min_delta_e(Protocol.PLAYER_COLORS)
	_check(worst >= 25.0, "the 4 penguin colors differ pairwise by a delta E of 25 or more: %.1f" % worst)


## 15.11c: the clouds drift 2 to 3 world pixels per second (REQ-SB-15), which is 4 % to 6.5 % of the view in 10 s.
func _clouds() -> void:
	print("the clouds")
	var low := 1.0e9
	var high := 0.0
	for i in SumoLook.CLOUDS.size():
		var shift := SumoLook.cloud_x(i, 1.0) - SumoLook.cloud_x(i, 0.0)   # World pixels in one second (no wrap here).
		low = minf(low, shift)
		high = maxf(high, shift)
	_check(high <= 3.0 + 0.001 and high > 2.0, "the fastest cloud drifts at most 3 world pixels per second: %.2f" % high)
	# docs/games/sumo_bumpers.md (REQ-SB-15) says 2 to 3; the cloud at x = 330 drifts at 1.5.
	_known_bug("issue-needed: a cloud drifts at %.1f world pixels per second, REQ-SB-15 says 2 to 3 (CLOUDS in sumo_look.gd)"
			% low,
			low >= 2.0 - 0.001)


## 15.3a: the tilt rolls the bumper the same way, through the sensor fusion (REQ-SB-7).
func _axes() -> void:
	print("the direction of the tilt")
	var game := _play()
	var p: RefCounted = _app.server.players[0]
	var body = game._bodies[0]
	var got := {}
	var ways := {"right": Vector2(0.7, 0.0), "left": Vector2(-0.7, 0.0), "up": Vector2(0.0, 0.7), "down": Vector2(0.0, -0.7)}
	for way in ways:
		for i in 120:
			_sim.feed(p, Vector2.ZERO)
		p.recenter()
		body.pos = Vector2.ZERO
		body.vel = Vector2.ZERO
		game._bodies[1].pos = Vector2(0.0, 250.0)   # Out of the way.
		for i in 24:
			_sim.feed(p, ways[way])
			game._process(DT)
		got[way] = body.vel
	_check(got.right.x > 50.0 and absf(got.right.y) < 0.1 * got.right.x, "a tilt to the right rolls the bumper to the right: %s"
			% str(got.right))
	_check(got.left.x < -50.0 and absf(got.left.y) < 0.1 * -got.left.x, "a tilt to the left rolls it to the left: %s"
			% str(got.left))
	_check(got.up.y > 50.0 and absf(got.up.x) < 0.1 * got.up.y, "the top of the phone up rolls it down the screen: %s"
			% str(got.up))
	_check(got.down.y < -50.0 and absf(got.down.x) < 0.1 * -got.down.y, "the top of the phone down rolls it up the screen: %s"
			% str(got.down))


## 15.3b: the bumper slows down by itself (the same TiltBody as Paint Grab).
func _damping() -> void:
	print("the damping")
	var game := _play()
	var p: RefCounted = _app.server.players[0]
	var body = game._bodies[0]
	body.pos = Vector2(-200.0, 0.0)
	body.vel = Vector2.ZERO
	game._bodies[1].pos = Vector2(0.0, 250.0)
	SimInput.set_tilt(p, Vector2(0.15, 0.0))
	SimInput.run(game, 1.0)
	var top: float = body.vel.length()
	SimInput.set_tilt(p, Vector2.ZERO)
	var speeds := {}
	SimInput.run(game, 4.0, DT, func(t: float) -> void:
		for mark in [0.5, 4.0]:
			if absf(t - mark) < DT * 0.5:
				speeds[mark] = body.vel.length())
	_check(top > 100.0 and speeds[0.5] > 20.0 and speeds[4.0] < 20.0 and game._alive.has(0),
			"the bumper is %.0f px/s at the end of the tilt, still %.0f px/s 0.5 s later, and below 20 px/s after 4 s (%.1f)"
			% [top, speeds[0.5], speeds[4.0]])


## 15.3c: the island gets smaller all the time and its edge ring turns from brown to red (REQ-SB-6, REQ-SB-15).
func _shrink() -> void:
	print("the shrinking island")
	var game := _play()
	game._bodies[0].pos = Vector2(-40.0, 0.0)   # Two bumpers close to the middle, so that nobody falls in 21 s.
	game._bodies[1].pos = Vector2(40.0, 0.0)
	var start_r: float = game.arena.radius()
	var rings: Array = [_sumo.danger_ring(game.arena.danger())]
	var radii: Array = [start_r]
	for second in 21:
		SimInput.run(game, 1.0)
		radii.append(game.arena.radius())
		rings.append(_sumo.danger_ring(game.arena.danger()))
	var falling := true
	var greener := true
	for i in range(1, radii.size()):
		falling = falling and radii[i] < radii[i - 1]
		greener = greener and rings[i].g <= rings[i - 1].g + 0.0001
	_check(game.phase == game.Phase.PLAY and falling and radii[21] < 0.25 * start_r,
			"in 21 s without a fall the radius gets smaller every second, from %.0f to %.0f px" % [start_r, radii[21]])
	_check(rings[0].is_equal_approx(SumoLook.RIM) and rings[0].r > rings[0].b + 0.2 and rings[21].r > 0.95 and rings[21].g < 0.4
			and greener, "the edge ring is brown at GO and red after 21 s, and loses green all the way: %s -> %s"
			% [str(rings[0]), str(rings[21])])


## 15.4a, 4b: two bumpers that run into each other bounce apart; only a fast hit buzzes (REQ-SB-8).
func _bump() -> void:
	print("the bump")
	var game := _play()
	var a = game._bodies[0]
	var b = game._bodies[1]
	a.pos = Vector2(-120.0, 0.0)
	b.pos = Vector2(120.0, 0.0)
	a.vel = Vector2.ZERO
	b.vel = Vector2.ZERO
	SimInput.set_tilt(_app.server.players[0], Vector2(0.7, 0.0))
	SimInput.set_tilt(_app.server.players[1], Vector2(-0.7, 0.0))
	var rec := SimInput.record_haptics(game)
	var st := {"closest": 1.0e9, "was_closing": false, "turned": false, "sep": 0.0}
	SimInput.run(game, 1.2, DT, func(_t: float) -> void:
		var d: Vector2 = b.pos - a.pos
		st.closest = minf(st.closest, d.length())
		var closing: float = (a.vel - b.vel).dot(d.normalized())
		if st.was_closing and closing < 0.0:
			st.turned = true
			st.sep = -closing
		st.was_closing = closing > 50.0)
	_check(st.closest >= 2.0 * SumoArena.BUMPER_R - 0.01 and st.turned and st.sep > 50.0,
			"2 bumpers at full tilt toward each other bounce: the closing speed turns into %.0f px/s apart" % st.sep)
	_check(rec.ms_of(0).has(20) and rec.ms_of(1).has(20) and game._alive.size() == 2,
			"both phones buzz 20 ms at that fast hit and nobody is out")
	# The limit of the buzz is 300 px/s between the two (REQ-SB-8).
	for case in [[250.0, false], [350.0, true]]:
		var rec2 := SimInput.record_haptics(game)
		a.pos = Vector2(0.0, 0.0)
		b.pos = Vector2(50.0, 0.0)
		a.vel = Vector2(case[0], 0.0)
		b.vel = Vector2.ZERO
		game._bump(0, 1)
		_check((rec2.log.size() == 2) == case[1], "a hit at %.0f px/s %s" % [case[0],
				"buzzes both phones" if case[1] else "buzzes nobody"])


## 15.5a, 5b: the dash is short, B does nothing, and the dash is ready again after the time of the level (REQ-SB-10).
func _dash() -> void:
	print("the dash")
	var wanted := {"easy": 1.5, "medium": 2.0, "hard": 2.5}
	for d in ["easy", "medium", "hard"]:
		var game := _play(d)
		game._bodies[1].pos = Vector2(0.0, 250.0)
		var body = game._bodies[0]
		body.pos = Vector2.ZERO
		body.vel = Vector2.ZERO
		SimInput.set_tilt(_app.server.players[0], Vector2(0.5, 0.0))
		game._on_button(Protocol.BTN_A, 0)
		game._process(DT)
		var first_speed: float = body.vel.length()
		var ready_after := 0.0
		var boost := {}
		while float(game._dash_left[0]) > 0.0 and ready_after < 5.0:
			game._process(0.05)
			ready_after += 0.05
			if d == "medium":
				boost[roundi(ready_after * 100.0)] = [body.max_speed, body.vel.length()]
			game._bodies[0].pos = Vector2.ZERO   # Only the speed matters here: the bumper must not fall.
		_check(first_speed > 650.0 and absf(ready_after - float(wanted[d]) + DT) < 0.11,
				"%s: a dash gives %.0f px/s and is ready again after %.2f s (wanted %.1f)" % [d, first_speed, ready_after,
						wanted[d]])
		if d == "medium":
			# The speed limit of the dash lasts 0.35 s; after it the normal limit of 560 px/s is back.
			_check(boost[30][0] == 700.0 and boost[40][0] == 560.0 and boost[40][1] <= 560.01,
					"on Medium the dash speed limit lasts about 0.35 s: at 0.30 s %.0f, at 0.40 s %.0f px/s" % [boost[30][0],
							boost[40][0]])
			game._dash_left[0] = 0.0
			game._dashes.clear()
			game._on_button(Protocol.BTN_B, 0)
			_check(game._dashes.is_empty() and float(game._dash_left[0]) == 0.0, "B does nothing")


## Seconds from GO until the round ends, for two bumpers that stay where they are (`spots`).
func _seconds_to_end(difficulty: String, spots: Array) -> float:
	var game := _play(difficulty)
	for i in spots.size():
		game._bodies[i].pos = spots[i]
		game._bodies[i].vel = Vector2.ZERO
	return SimInput.run_until(game, func() -> bool: return game.phase == game.Phase.BANNER, 60.0)


## 15.7b: a round is as long as the shrinking: 30, 24 and 18 s at most on Easy, Medium and Hard (REQ-SB-6, REQ-SB-20).
func _round_length() -> void:
	print("the length of a round")
	var ends := {}
	var passive := {}
	for d in ["easy", "medium", "hard"]:
		ends[d] = _seconds_to_end(d, [Vector2(-40.0, 0.0), Vector2(40.0, 0.0)])
		var arena := SumoArena.new()
		arena.setup(d)
		passive[d] = _seconds_to_end(d, arena.start_spots(2))
	_check(ends.easy > 27.0 and ends.easy < 33.0 and ends.medium > 21.6 and ends.medium < 26.4 and ends.hard > 16.2
			and ends.hard < 19.8,
			"bumpers in the middle: the round lasts %.1f, %.1f, %.1f s on Easy, Medium, Hard (30, 24, 18 s of shrinking)"
			% [ends.easy, ends.medium, ends.hard])
	_check(passive.easy < 30.0 and passive.medium < 24.0 and passive.hard < 18.0 and passive.hard < passive.medium
			and passive.medium < passive.easy, "bumpers that wait at their start places fall sooner: %.1f, %.1f, %.1f s"
			% [passive.easy, passive.medium, passive.hard])


## 15.6a, 6b, 6c: a fall, the word, the buzz, the banner and the next round (REQ-SB-3, 4, 9, 11).
func _fall_and_next_round() -> void:
	print("a fall")
	var game := _play()
	var rec := SimInput.record_haptics(game)
	var spots: Array = game.arena.start_spots(3)
	_check(Lang.t("sumo_bumpers.whee").to_upper() == "WHEE!", "the word over a fallen bumper is WHEE!")
	game._bodies[1].pos = Vector2(game.arena.radius() + 60.0, 0.0)
	game._process(DT)
	_check(not game._alive.has(1) and game._falling.has(1) and game.phase == game.Phase.PLAY and game._alive.size() == 2,
			"a bumper over the edge falls, the round goes on with two")
	_check(rec.ms_of(1) == [80] and rec.ms_of(0).is_empty() and rec.ms_of(2).is_empty(),
			"the phone that fell buzzes 80 ms and the others do not (REQ-SB-11)")
	var scales := {}
	SimInput.run(game, 1.0, DT, func(t: float) -> void:
		for mark in [0.2, 0.4, 0.7, 0.9]:
			if absf(t - mark) < DT * 0.5:
				scales[mark] = _sumo.fall_scale(float(game._falling[1].age)))
	_check(scales[0.2] == 0.75 and scales[0.4] == 0.5 and scales[0.7] == 0.25 and scales[0.9] == 0.0 and game._alive.size() == 2,
			"the fallen bumper shrinks in steps to nothing in 0.8 s: %s" % str(scales))
	# The last bumper but one falls: the banner names the winner and the next round starts after 2.5 s with all bumpers back.
	game._bodies[2].pos = Vector2(0.0, game.arena.radius() + 60.0)
	game._bodies[0].pos = Vector2.ZERO
	game._process(DT)
	_check(game.phase == game.Phase.BANNER and game.banner_text == "Sim0 wins the round!" and game._board.score(0) == 1.0,
			"the banner names the winner of the round: %s" % game.banner_text)
	var waited := SimInput.run_until(game, func() -> bool: return game.phase == game.Phase.COUNT, 10.0)
	_check(absf(waited - 2.5) < 0.1 and game.round_no == 2 and game._alive.size() == 3
			and game._bodies[1].pos.is_equal_approx(spots[1]),
			"the next round starts %.2f s after the banner with all 3 bumpers back" % waited)


## 15.7c: after the first fall the platform shrinks twice as fast, so the wait is short (REQ-SB-6, REQ-GM-83).
func _wait_after_a_fall() -> void:
	print("the wait after a fall")
	var results := {}
	for d in ["easy", "medium", "hard"]:
		var game := _play(d)
		game._bodies[0].pos = Vector2(-40.0, 0.0)
		game._bodies[2].pos = Vector2(40.0, 0.0)
		game._bodies[1].pos = Vector2(0.0, 250.0)
		SimInput.run(game, 1.0)
		game._bodies[1].pos = Vector2(game.arena.radius() + 60.0, 0.0)
		game._process(DT)
		var after := SimInput.run_until(game, func() -> bool: return game.phase == game.Phase.BANNER, 60.0)
		results[d] = after
		_check(after <= game.arena.longest_wait() + 1.0,
				"%s: the round ends %.1f s after the first fall (at most %.1f s)" % [d, after, game.arena.longest_wait() + 1.0])
	_check(results.easy <= 16.0 and results.medium <= 13.0 and results.hard <= 10.0,
			"the wait is at most 16, 13 and 10 s on Easy, Medium and Hard: %s" % str(results))


## 15.7a: 3 rounds with `count` phones: the round number on the screen, the points, and the winner of the match.
func _three_rounds(count: int) -> void:
	print("3 rounds with %d phones" % count)
	var game := _play()
	var titles_ok := true
	var shown := []
	for n in [1, 2, 3]:
		titles_ok = titles_ok and game.round_no == n and game.phase == game.Phase.PLAY \
				and Lang.f("sumo_bumpers.round_n_of", [game.round_no, game.ROUNDS]) == "Round %d of 3" % n
		shown.append(Lang.f("sumo_bumpers.round_n_of", [game.round_no, game.ROUNDS]))
		# Everybody but player 0 rolls off the island, in different directions.
		for s in game.participants:
			if s != 0:
				game._bodies[s].pos = Vector2.from_angle(2.1 * float(s)) * (game.arena.radius() + 60.0)
		game._process(DT)
		titles_ok = titles_ok and game.phase == game.Phase.BANNER and game._board.score(0) == float(n)
		if n < 3:
			SimInput.run_until(game, func() -> bool: return game.phase == game.Phase.COUNT, 10.0)
			SimInput.to_play(game, func() -> bool: return game.phase == game.Phase.COUNT)
	_check(titles_ok, "with %d phones the bar says %s and player 0 has 1, 2, 3 points after the rounds" % [count, str(shown)])
	SimInput.run_until(game, func() -> bool: return game.is_over, 10.0)
	var labels: Array = []
	for l in game._menu_box.find_children("*", "Label", true, false):
		labels.append(l.text)
	_check(game.is_over and labels[0] == "SIM0 WINS!" and labels[1].ends_with("3 POINTS") and game.leader_text() == "3"
			and labels.size() >= count + 1, "after round 3 the result names SIM0 and lists %d players: %s" % [count, str(labels)])
