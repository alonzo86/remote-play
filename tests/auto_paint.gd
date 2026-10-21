extends SceneTree
## Paint Grab with simulated phones and a fixed time step: what used to be checked by hand in Test 14 and a machine can check
## (the direction of the tilt, the damping, the edge of the floor, the speed of the three levels, the medals, two blobs that
## touch,
## the leader chip, the tile grid, the pop). The game is stepped by hand (`SimInput`), so the result does not depend on the speed
## of the machine. Run:
##   godot --headless --path . --script tests/auto_paint.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const MedalView = preload("res://scripts/ui/medal_view.gd")
const PaintPots = preload("res://scripts/game/paint_grab/paint_pots.gd")

const DT := 1.0 / 60.0

var _fails := 0
var _checks := 0
var _sim := SimInput.new()
var _app: Node
var _game_script: GDScript
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A game of Paint Grab in play (the countdown is over), stepped by hand. All phones are held flat.
func _play(difficulty := "medium", seed_value := 7) -> Control:
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	var game := SimInput.start_game(_app, _game_script, {"difficulty": difficulty, "seed": seed_value})
	SimInput.to_play(game, func() -> bool: return game._round.is_counting())
	return game


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_game_script = load("res://scripts/game/paint_grab/paint_grab_game.gd")
	_clients = await SimInput.connect_phones(self, _app, 3)
	_check(_app.server.connected_slots().size() == 3, "3 simulated phones joined")
	_colors()
	await _axes()
	await _damping()
	await _edges()
	await _level_speed()
	await _level_medals()
	await _blobs_touch()
	await _leader_and_winner()
	await _pop_and_grid()
	await _takes_and_pots()
	await _leave_and_end()
	for c in _clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## 14.10b: the 4 player colors are told apart by their distance in the Lab color space, and every one stands out from an empty
## tile (REQ-GM-47m). A person naming the colors from 3 m stays a manual step.
func _colors() -> void:
	print("the colors")
	var cols: Array = Protocol.PLAYER_COLORS
	var worst := SimInput.min_delta_e(cols)
	_check(worst >= 25.0, "the 4 slot colors differ pairwise by a delta E of 25 or more: %.1f" % worst)
	var on_floor := 1.0e9
	for c in cols:
		on_floor = minf(on_floor, SimInput.delta_e(c, _game_script.EMPTY_TILE))
	_check(on_floor >= 40.0, "every slot color differs from an empty tile by a delta E of 40 or more: %.1f" % on_floor)


## 14.3a: a tilt to the right, left, up or down rolls the blob that way, through the sensor fusion (REQ-PG-7). The real
## direction of a phone is Test 3.
func _axes() -> void:
	print("the direction of the tilt")
	var game := _play()
	game._bodies.erase(1)
	game._bodies.erase(2)
	var p: RefCounted = _app.server.players[0]
	var body = game._bodies[0]
	var middle: Vector2 = game.floor_map.size() * 0.5
	var results := {}
	for dir in {"right": Vector2(0.7, 0.0), "left": Vector2(-0.7, 0.0), "up": Vector2(0.0, 0.7), "down": Vector2(0.0,
			-0.7)}.keys():
		var t: Vector2 = {"right": Vector2(0.7, 0.0), "left": Vector2(-0.7, 0.0), "up": Vector2(0.0, 0.7),
				"down": Vector2(0.0, -0.7)}[dir]
		for i in 120:
			_sim.feed(p, Vector2.ZERO)   # Held flat: the filter settles.
		p.recenter()
		body.pos = middle
		body.vel = Vector2.ZERO
		for i in 30:   # 0.5 s of tilt.
			_sim.feed(p, t)
			game._process(DT)
		results[dir] = body.vel
	var v: Dictionary = results
	_check(v.right.x > 60.0 and absf(v.right.y) < 0.1 * v.right.x, "a tilt to the right rolls the blob to the right (x > 0): %s"
			% str(v.right))
	_check(v.left.x < -60.0 and absf(v.left.y) < 0.1 * -v.left.x, "a tilt to the left rolls the blob to the left (x < 0): %s"
			% str(v.left))
	# `tilt().y` > 0 is the top of the phone up; the blob rolls down the screen then (toward the player).
	_check(v.up.y > 60.0 and absf(v.up.x) < 0.1 * v.up.y, "the top of the phone up rolls the blob down the screen (y > 0): %s"
			% str(v.up))
	_check(v.down.y < -60.0 and absf(v.down.x) < 0.1 * -v.down.y,
			"the top of the phone down rolls the blob up the screen (y < 0): %s" % str(v.down))


## 14.3b: the blob slows down by itself (REQ-PG-7, damping 1.4 per second).
func _damping() -> void:
	print("the damping")
	var game := _play()
	game._bodies.erase(1)
	game._bodies.erase(2)
	var p: RefCounted = _app.server.players[0]
	var body = game._bodies[0]
	body.pos = Vector2(60.0, game.floor_map.size().y * 0.5)
	body.vel = Vector2.ZERO
	SimInput.set_tilt(p, Vector2(0.7, 0.0))
	SimInput.run(game, 1.5)
	var top: float = body.vel.length()
	_check(top > 500.0, "full tilt for 1.5 s gives a high speed: %.0f px/s" % top)
	SimInput.set_tilt(p, Vector2.ZERO)
	var speeds := {}
	SimInput.run(game, 4.0, DT, func(t: float) -> void:
		for mark in [0.5, 2.0, 3.5, 4.0]:
			if absf(t - mark) < DT * 0.5:
				speeds[mark] = body.vel.length())
	_check(speeds[0.5] > 20.0 and speeds[2.0] > 20.0, "the blob still rolls 0.5 s and 2 s after the tilt stops: %.0f, %.0f px/s"
			% [speeds[0.5], speeds[2.0]])
	_check(speeds[3.5] < 20.0 and speeds[4.0] < 20.0 and speeds[4.0] < speeds[3.5],
			"it slows down by itself and is below 20 px/s after 3.5 s (REQ-PG-7): %.1f, %.1f px/s" % [speeds[3.5], speeds[4.0]])
	_check(body.pos.x < game.floor_map.size().x - 100.0, "it did not hit the edge on the way, so the damping alone slowed it")


## 14.3c: full tilt into each of the 4 edges: the blob stays inside the floor and bounces (REQ-PG-7).
func _edges() -> void:
	print("the edge of the floor")
	var game := _play()
	game._bodies.erase(1)
	game._bodies.erase(2)
	var p: RefCounted = _app.server.players[0]
	var body = game._bodies[0]
	var floor_size: Vector2 = game.floor_map.size()
	var r: float = body.radius
	var state := {"inside": true, "prev": Vector2.ZERO}   # A closure keeps a copy of a plain variable: a Dictionary is shared.
	var bounced := {}
	var middle := floor_size * 0.5
	var ways := {"right": Vector2(1.0, 0.0), "left": Vector2(-1.0, 0.0), "down": Vector2(0.0, 1.0), "up": Vector2(0.0, -1.0)}
	var total := 0.0
	for way in ways:
		body.pos = middle
		body.vel = Vector2.ZERO
		state.prev = Vector2.ZERO
		SimInput.set_tilt(p, ways[way] * 0.7)
		SimInput.run(game, 2.5, DT, func(_t: float) -> void:
			state.inside = state.inside and body.pos.x >= r - 0.01 and body.pos.x <= floor_size.x - r + 0.01 \
					and body.pos.y >= r - 0.01 and body.pos.y <= floor_size.y - r + 0.01
			var axis: Vector2 = ways[way]
			if state.prev.dot(axis) > 100.0 and body.vel.dot(axis) < 0.0:
				bounced[way] = true
			state.prev = body.vel)
		total += 2.5
	_check(state.inside and total == 10.0, "in 10 s of full tilt at all 4 edges the whole blob stayed inside the floor")
	_check(bounced.has("right") and bounced.has("left") and bounced.has("up") and bounced.has("down"),
			"at each edge the velocity turned back (a soft bounce): %s" % str(bounced.keys()))


## Seconds that a blob needs from rest to roll `distance` px to the right at tilt 0.7 on `difficulty`.
func _roll_time(difficulty: String, distance: float) -> float:
	var game := _play(difficulty)
	game._bodies.erase(1)
	game._bodies.erase(2)
	var body = game._bodies[0]
	body.pos = Vector2(60.0, game.floor_map.size().y * 0.5)
	body.vel = Vector2.ZERO
	var start_x: float = body.pos.x
	SimInput.set_tilt(_app.server.players[0], Vector2(0.7, 0.0))
	return SimInput.run_until(game, func() -> bool: return body.pos.x - start_x >= distance, 20.0)


## 14.5a, 5b: the floor and the speed of the blob depend on the difficulty (REQ-PG-20).
func _level_speed() -> void:
	print("the three levels")
	var floors := {}
	for d in ["easy", "medium", "hard"]:
		var g := _play(d)
		floors[d] = Vector2i(g.floor_map.cols, g.floor_map.rows)
	_check(floors.easy == Vector2i(12, 7) and floors.medium == Vector2i(16, 9) and floors.hard == Vector2i(20, 11),
			"the floor is 12 x 7, 16 x 9 and 20 x 11 tiles on Easy, Medium and Hard: %s" % str(floors))
	var te := _roll_time("easy", 600.0)
	var tm := _roll_time("medium", 600.0)
	var th := _roll_time("hard", 600.0)
	_check(te > tm and tm > th and th > 0.0,
			"a blob crosses 600 px faster on Hard than on Medium than on Easy: %.2f, %.2f, %.2f s"
			% [te, tm, th])
	# The speed is 0.8, 1.0 and 1.25 of Medium, so the cruise time differs by 1.25 and 1.56 (the first 0.4 s of acceleration is
	# the same for all, so the ratios are a little smaller).
	_check(te / tm > 1.1 and te / tm < 1.3 and tm / th > 1.1 and tm / th < 1.3 and te / th > 1.35 and te / th < 1.7,
			"the times are about 1.25 : 1 and 1.25 : 1 apart (speed 0.8, 1.0, 1.25): %.2f, %.2f" % [te / tm, tm / th])


## 14.5c: the medal and the title for the share of the floor, at the limits of each difficulty (REQ-PG-21).
func _level_medals() -> void:
	print("the medal for the share of the floor")
	var lv: Dictionary = _game_script.LEVELS
	var all_ok := true
	var shown := []
	for d in ["easy", "medium", "hard"]:
		var tiers: Array = lv[d].tiers
		var total: int = int(lv[d].cols) * int(lv[d].rows)
		var cases := []   # [tiles, medal]: the fewest tiles for each limit, and one tile less.
		for i in 3:
			var n := 0
			while n * 100 / total < int(tiers[i]):
				n += 1
			cases.append([n - 1, ["", "bronze", "silver"][i]])
			cases.append([n, ["bronze", "silver", "gold"][i]])
		for c in cases:
			var game := _play(d)
			game.participants.clear()
			game.participants.append(0)
			game._on_player_left(1)
			game._on_player_left(2)
			for i in int(c[0]):
				game.floor_map.paint(Vector2i(i % game.floor_map.cols, i / game.floor_map.cols), 0)
			game._board.set_score(0, game.floor_map.count(0))
			var percent: int = game.floor_map.percent(0)
			game._round.time = game.ROUND_TIME - 0.001
			game._process(0.01)
			var labels: Array = []
			for l in game._menu_box.find_children("*", "Label", true, false):
				labels.append(l.text)
			var tiers_shown: Array = MedalView.tiers_in(game._menu_box)
			var title_ok: bool = labels[0] == d.to_upper() if c[1] != "" else (String(labels[0]).begins_with("NO MEDAL")
					and String(labels[0]).ends_with("(%s)" % d.to_upper()))
			var ok: bool = game.is_over and title_ok and tiers_shown == ([c[1]] if c[1] != "" else [])
			all_ok = all_ok and ok
			shown.append("%s %d tiles=%d%%=%s" % [d, c[0], percent, c[1] if c[1] != "" else "none"])
			if not ok:
				print("    bad case: ", d, " ", c, " got percent ", percent, " labels ", labels, " medals ", tiers_shown)
	_check(all_ok, "every limit gives its medal, the tile below gives the one before, and the title names the level: %s"
			% str(shown))


## 14.6a: two blobs that run into each other bounce and never overlap (REQ-PG-8).
func _blobs_touch() -> void:
	print("two blobs")
	var game := _play()
	game._bodies.erase(2)
	var a = game._bodies[0]
	var b = game._bodies[1]
	a.pos = Vector2(400.0, 450.0)
	b.pos = Vector2(1200.0, 450.0)
	a.vel = Vector2.ZERO
	b.vel = Vector2.ZERO
	SimInput.set_tilt(_app.server.players[0], Vector2(0.7, 0.0))
	SimInput.set_tilt(_app.server.players[1], Vector2(-0.7, 0.0))
	var reach: float = a.radius + b.radius
	var st := {"closest": 1.0e9, "was_closing": false, "turned": false}
	SimInput.run(game, 2.0, DT, func(_t: float) -> void:
		var d: Vector2 = b.pos - a.pos
		st.closest = minf(st.closest, d.length())
		var closing: float = (a.vel - b.vel).dot(d.normalized())   # > 0: coming together.
		if st.was_closing and closing < 0.0:
			st.turned = true
		st.was_closing = closing > 50.0)
	var closest: float = st.closest
	var turned: bool = st.turned
	_check(closest >= reach - 0.01, "2 blobs that run at each other never overlap (closest %.1f, two radii %.1f)" % [closest,
			reach])
	_check(turned, "after the touch the blobs move apart, the closing speed turned into a separating speed")


## 14.6b: the leader chip names the player with the most tiles, and the result names the same player (REQ-PG-13).
func _leader_and_winner() -> void:
	print("the leader and the winner")
	var game := _play()
	# Each blob paints its own row, one tile at a time, by sitting on the tile for one frame.
	var rows := {0: 1, 1: 4, 2: 7}
	var paint := func(slot: int, from_col: int, count: int, row: int) -> void:
		for i in count:
			game._bodies[slot].pos = (Vector2(from_col + i, row) + Vector2(0.5, 0.5)) * 100.0
			game._bodies[slot].vel = Vector2.ZERO
			game._process(DT)
	var leader_slot := func() -> int:
		return int(game._board.leaders()[0].slot)
	paint.call(0, 0, 5, rows[0])
	_check(leader_slot.call() == 0 and game.leader_text() == str(game.floor_map.count(0)) and game.floor_map.count(0) >= 5,
			"after 5 tiles the leader chip shows player 0 with its tiles: %s"
			% game.leader_text())
	paint.call(1, 0, 8, rows[1])
	paint.call(2, 0, 3, rows[2])
	_check(leader_slot.call() == 1 and game.leader_text() == str(game.floor_map.count(1)) and game.floor_map.count(1) >= 8,
			"after player 1 painted 8 the chip shows player 1 with its tiles: %s" % game.leader_text())
	# Player 0 rolls over 6 tiles of player 1 (parked out of the way first): 5 + 6 = 11 against 8 - 6 + 1.
	game._bodies[1].pos = (Vector2(15, 8) + Vector2(0.5, 0.5)) * 100.0
	game._process(DT)
	paint.call(0, 0, 6, rows[1])
	var counts := [game.floor_map.count(0), game.floor_map.count(1), game.floor_map.count(2)]
	var best: int = counts.max()
	var best_slot: int = counts.find(best)
	_check(counts.count(best) == 1 and leader_slot.call() == best_slot and game.leader_text() == str(best) and best_slot == 0,
			"after taking tiles the chip follows the floor: player 0 leads with %d (%s)" % [best, str(counts)])
	game._round.time = game.ROUND_TIME - 0.001
	game._process(0.01)
	var labels: Array = []
	for l in game._menu_box.find_children("*", "Label", true, false):
		labels.append(l.text)
	var winner_name: String = String(_app.server.players[best_slot].player_name).to_upper()
	_check(labels[0] == "%s WINS!" % winner_name, "the result names the same player as the chip: %s" % str(labels[0]))


## 14.10a, 10c: every tile is a whole number of world pixels with equal gaps, and a painted tile pops for several frames.
func _pop_and_grid() -> void:
	print("the tile grid and the pop")
	var all_ok := true
	var bad := ""
	for d in ["easy", "medium", "hard"]:
		for res in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
			root.size = res
			await _frames(2)
			var game := SimInput.start_game(_app, _game_script, {"difficulty": d, "seed": 3})
			await _frames(2)
			var fit: Dictionary = game._fit()
			var k: float = fit.k
			var pitch: float = game.REF_TILE * k
			var first: Rect2 = game._tile_rect(Vector2i(0, 0), fit.origin, k, false)
			var ok: bool = fmod(pitch, 4.0) == 0.0 and fmod(first.position.x, 4.0) == 0.0 and fmod(first.position.y, 4.0) == 0.0
			for r in game.floor_map.rows:
				for c in game.floor_map.cols:
					var t: Rect2 = game._tile_rect(Vector2i(c, r), fit.origin, k, false)
					ok = ok and t.size == first.size and fmod(t.position.x, 4.0) == 0.0 and fmod(t.position.y, 4.0) == 0.0
					if c + 1 < game.floor_map.cols:
						ok = ok and is_equal_approx(game._tile_rect(Vector2i(c + 1, r), fit.origin, k,
								false).position.x - t.end.x, 4.0)
					if r + 1 < game.floor_map.rows:
						ok = ok and is_equal_approx(game._tile_rect(Vector2i(c, r + 1), fit.origin, k,
								false).position.y - t.end.y, 4.0)
			if not ok:
				bad = "%s %s" % [d, str(res)]
			all_ok = all_ok and ok
	root.size = Vector2i(1920, 1080)
	await _frames(3)
	_check(all_ok,
			"on all levels and at 720p, 1080p and 1440p every tile is a whole number of world pixels with a gap of 4 units "
			+ "(1 world pixel) to every neighbor %s" % bad)
	var game := _play()
	game._bodies.erase(1)
	game._bodies.erase(2)
	var fit: Dictionary = game._fit()
	var c := Vector2i(3, 3)
	var plain: Rect2 = game._tile_rect(c, fit.origin, fit.k, false)
	var popped: Rect2 = game._tile_rect(c, fit.origin, fit.k, true)
	_check(game.size == Vector2(1920, 1080) and is_equal_approx(popped.position.x, plain.position.x - 4.0)
			and is_equal_approx(popped.end.x, plain.end.x + 4.0) and is_equal_approx(popped.position.y, plain.position.y - 4.0)
			and is_equal_approx(popped.end.y,
					plain.end.y + 4.0), "at 1080p a popping tile is 4 px (1 world pixel) wider on each side")
	var idx: int = c.y * game.floor_map.cols + c.x
	game._bodies[0].pos = (Vector2(c) + Vector2(0.5, 0.5)) * 100.0
	game._bodies[0].vel = Vector2.ZERO
	var frames := 0
	var painted_frame := -1
	for f in 12:
		game._process(0.033)   # 30 frames per second.
		if game._pops[idx] > 0.0:
			frames += 1
			if painted_frame < 0:
				painted_frame = f
	_check(painted_frame == 0 and frames >= 3 and frames <= 5 and game._pops[idx] == 0.0,
			"at 30 frames per second a painted tile pops for %d frames (3 to 5) and then stops (REQ-PG-16)" % frames)


## 14.4b, 11e: the buzz of a take, the gold pot and the rainbow roller (REQ-PG-12, REQ-PG-23).
func _takes_and_pots() -> void:
	print("takes and pots")
	var game := _play()
	game._bodies.erase(2)
	var rec := SimInput.record_haptics(game)
	game._bodies[0].pos = Vector2(150.0, 150.0)
	game._process(DT)   # Player 0 paints (1, 1): a free tile.
	game._bodies[1].pos = Vector2(1450.0, 750.0)
	game._process(DT)
	_check(rec.log.is_empty(), "painting a free tile buzzes nobody")
	game._bodies[1].pos = Vector2(150.0, 150.0) + Vector2(0.0, 0.0)
	game._bodies[0].pos = Vector2(1450.0, 150.0)
	game._process(DT)   # Player 1 sits on the tile of player 0 and takes it.
	_check(rec.log == [[1, 20]], "taking the tile of another player buzzes the player that took it for 20 ms: %s" % str(rec.log))
	# The rainbow roller paints the whole row, also the tiles of the other player, and buzzes 40 ms.
	game._bodies[0].pos = Vector2(250.0, 250.0)
	game._process(DT)
	var before0: int = game.floor_map.count(0)
	game._pots.pots.clear()
	var roller := PaintPots.Pot.new()
	roller.kind = PaintPots.ROLLER
	roller.cell = Vector2i(5, 7)
	game._pots.pots.append(roller)
	game._bodies[1].pos = (Vector2(roller.cell) + Vector2(0.5, 0.5)) * 100.0
	game._bodies[1].vel = Vector2.ZERO
	rec.log.clear()
	game._process(DT)
	var row_ok := true
	for x in game.floor_map.cols:
		row_ok = row_ok and game.floor_map.owner_of(Vector2i(x, 7)) == 1
	_check(row_ok and game._pots.pots.is_empty() and game._board.score(1) == game.floor_map.count(1)
			and game._board.score(0) == game.floor_map.count(0) and game.floor_map.count(0) == before0 and rec.ms_of(1).has(40)
			and rec.ms_of(0).is_empty(),
			"the rainbow roller paints the whole row of 16 tiles for player 1, the scores follow, and only player 1 buzzes (40 ms)")
	# A tile that the roller takes from the other player moves the score of both.
	game._bodies[0].pos = Vector2(250.0, 750.0)   # Player 0 paints the tile (2, 7) back.
	game._process(DT)
	var lone := PaintPots.Pot.new()
	lone.kind = PaintPots.ROLLER
	lone.cell = Vector2i(9, 7)
	game._pots.pots.append(lone)
	game._bodies[1].pos = (Vector2(9, 7) + Vector2(0.5, 0.5)) * 100.0
	game._process(DT)
	_check(game._pots.pots.is_empty() and game.floor_map.owner_of(Vector2i(2, 7)) == 1
			and game._board.score(0) == game.floor_map.count(0),
			"the roller takes a tile of the other player back, and the score of that player falls")


## 14.6c: a player leaves, the blob goes, the tiles stay and the round still ends after 60 s (REQ-PG-10).
func _leave_and_end() -> void:
	print("a player leaves")
	var game := _play()
	game._bodies[2].pos = Vector2(150.0, 150.0)
	game._process(DT)
	var tiles2: int = game.floor_map.count(2)
	var started: float = game._round.time
	_app.server.kick(2)
	await _frames(3)
	game._process(DT)   # The game prunes the player that left.
	_check(not game._bodies.has(2) and game.floor_map.count(2) == tiles2 and tiles2 >= 1 and not game.is_over
			and game.participants.size() == 2, "the blob of a player that left is gone, its tile stays, and the round goes on")
	var ran := SimInput.run_until(game, func() -> bool: return game.is_over, 80.0)
	_check(game.is_over and absf(game._round.time - game.ROUND_TIME) < 0.1 and absf(ran - (game.ROUND_TIME - started)) < 0.2,
			"the round ends at 60 s of play: %.2f s" % game._round.time)
