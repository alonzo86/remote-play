extends SceneTree
## Smoke test of Paint Grab with two simulated phones (REQ-PG-*). Run:
##   godot --headless --path . --script tests/smoke_paint.gd -- --role=tv

const MedalView = preload("res://scripts/ui/medal_view.gd")
const PaintPicture = preload("res://scripts/game/paint_grab/paint_picture.gd")
const PaintPots = preload("res://scripts/game/paint_grab/paint_pots.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

var _fails := 0
var _checks := 0
var _seq := [0, 0]


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


## Both phones send `accel` (a lean of the phone) for `seconds`.
func _stream(clients: Array, seconds: float, accel: Array) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in clients.size():
			clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO, accel[i], 0, 0, Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var PaintGame = load("res://scripts/game/paint_grab/paint_grab_game.gd")
	var TvGameSettings = load("res://scripts/ui/tv_game_settings.gd")
	var GameSettings = load("res://scripts/game/game_settings.gd")
	var app: Node = root.get_node("App")
	GameSettings.clear()
	var clients: Array = []
	for i in 2:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
	var joined := Time.get_ticks_msec()
	while app.server.connected_slots().size() < 2 and Time.get_ticks_msec() - joined < 4000:
		await process_frame
	var flat := Vector3(0, 0, 9.81)
	var lean := deg_to_rad(15.0)
	var right := Vector3(-sin(lean), 0, cos(lean)) * 9.81
	await _stream(clients, 0.5, [flat, flat])

	# The settings view and the difficulty (REQ-PG-20).
	app.go_game_settings("paint_grab")
	await _frames(4)
	var sv: Control = app.current_screen()
	_check(is_instance_of(sv, TvGameSettings) and sv.rows.size() == 1 and sv.rows[0].value == "medium",
			"Paint Grab opens the settings view with Difficulty on Medium")
	var key := InputEventAction.new()
	key.action = "ui_right"
	key.pressed = true
	sv.rows[0]._gui_input(key)
	sv.start()
	await _frames(4)
	var hard: Control = app.current_screen()
	_check(is_instance_of(hard, PaintGame) and hard.difficulty == "hard" and hard.floor_map.cols == 20 and hard.floor_map.rows == 11
			and hard._bodies[0].max_speed > 560.0, "Hard gives a floor of 20 x 11 tiles and faster blobs (REQ-PG-20)")
	GameSettings.clear()

	# A round on Medium.
	app.go(PaintGame, {"difficulty": "medium"})
	await _frames(3)
	var game: Control = app.current_screen()
	_check(game.participants.size() == 2 and game.floor_map.cols == 16 and game.floor_map.rows == 9
			and game.floor_map.count(0) == 0, "Medium starts with 2 blobs on an empty floor of 16 x 9 tiles (REQ-PG-2)")
	var start0: Vector2 = game._bodies[0].pos
	var start1: Vector2 = game._bodies[1].pos
	var middle: Vector2 = game.floor_map.size() * 0.5
	_check(is_equal_approx(start0.distance_to(middle), start1.distance_to(middle)) and start0.distance_to(start1) > 200.0,
			"the blobs start apart and at the same distance from the middle (REQ-PG-3)")
	await _stream(clients, 1.5, [right, right])
	_check(game._round.is_counting() and game._bodies[0].pos == start0 and game.floor_map.count(0) == 0,
			"during the countdown the blobs do not move and nothing is painted (REQ-PG-1)")
	await _stream(clients, 2.2, [flat, flat])
	_check(game._round.is_playing(), "the round plays after the countdown")
	await _stream(clients, 2.5, [right, flat])
	_check(game._bodies[0].pos.x > start0.x + 20.0 and game._bodies[1].pos.distance_to(start1) < 40.0,
			"tilt moves only the blob of that phone")
	_check(game.floor_map.count(0) >= 3 and game._board.score(0) == game.floor_map.count(0),
			"the blob painted tiles on its way and the score is the number of tiles (REQ-PG-4, 5): %d" % game.floor_map.count(0))
	# A blob of the other player takes a tile (REQ-PG-4).
	var some := Vector2i(-1, -1)
	for r in game.floor_map.rows:
		for c in game.floor_map.cols:
			var cell := Vector2i(c, r)
			if some.x < 0 and game.floor_map.owner_of(cell) == 0 and cell != game.floor_map.cell_at(game._bodies[0].pos):
				some = Vector2i(c, r)
	game._bodies[1].pos = (Vector2(some) + Vector2(0.5, 0.5)) * 100.0
	game._bodies[1].vel = Vector2.ZERO
	var before0: int = game.floor_map.count(0)
	game._game_tick(0.016)
	_check(game.floor_map.owner_of(some) == 1 and game.floor_map.count(0) == before0 - 1
			and game._board.score(0) == before0 - 1 and game._board.score(1) == game.floor_map.count(1),
			"a blob that rolls over a tile of another player takes it, and both scores follow (REQ-PG-4)")
	await _frames(3)
	var s0: int = game._board.score(0)
	var s1: int = game._board.score(1)
	_check(clients[0].score_text == str(s0) and clients[1].score_text == str(s1)
			and clients[0].score_rank == (2 if s1 > s0 else 1) and clients[1].score_rank == (2 if s0 > s1 else 1),
			"each phone gets its tiles and its place (REQ-FL-67): %d/%d" % [s0, s1])
	# The buzz of a take (REQ-PG-12): a free tile gives none, a take gives one, and a second take within 150 ms gives no second.
	game._haptics = load("res://scripts/game/haptics.gd").new()   # Loaded here: it needs the App autoload.
	var free := Vector2i(-1, -1)
	var other := Vector2i(-1, -1)
	for r in game.floor_map.rows:
		for c in game.floor_map.cols:
			var cell := Vector2i(c, r)
			if free.x < 0 and game.floor_map.owner_of(cell) == -1:
				free = cell
			elif other.x < 0 and game.floor_map.owner_of(cell) == 0 and cell != game.floor_map.cell_at(game._bodies[0].pos):
				other = cell
	game._bodies[1].pos = (Vector2(free) + Vector2(0.5, 0.5)) * 100.0
	game._paint_under(1)
	var after_free: bool = game._haptics._last.has(1)
	game._bodies[1].pos = (Vector2(other) + Vector2(0.5, 0.5)) * 100.0
	game._paint_under(1)
	var first_buzz: int = game._haptics._last.get(1, -1)
	var again := Vector2i(-1, -1)
	for r in game.floor_map.rows:
		for c in game.floor_map.cols:
			var cell2 := Vector2i(c, r)
			if again.x < 0 and game.floor_map.owner_of(cell2) == 0 and cell2 != game.floor_map.cell_at(game._bodies[0].pos):
				again = cell2
	game._bodies[1].pos = (Vector2(again) + Vector2(0.5, 0.5)) * 100.0
	game._paint_under(1)
	_check(not after_free and first_buzz >= 0 and game._haptics._last[1] == first_buzz,
			"a free tile does not buzz, a take buzzes, and a second take within 150 ms does not buzz again (REQ-PG-12)")
	await _frames(3)
	_check(game._pops[some.y * game.floor_map.cols + some.x] > 0.0, "a painted tile pops (REQ-PG-16)")
	# A pot: the first blob on its tile paints the patch for its player (REQ-PG-23).
	_check(game._picture.size() == game.floor_map.cols * game.floor_map.rows and game._picture.size() - game._picture.count(0) > 10,
			"the floor hides a picture that fits it (REQ-PG-22)")
	game._pots.pots.clear()
	var pot = PaintPots.Pot.new()
	pot.kind = PaintPots.GOLD
	pot.cell = Vector2i(8, 4)
	game._pots.pots.append(pot)
	game._bodies[0].pos = Vector2(100.0, 100.0)
	game._bodies[1].pos = (Vector2(pot.cell) + Vector2(0.5, 0.5)) * 100.0
	game._bodies[1].vel = Vector2.ZERO
	game._tick_pots(0.016)
	var patch_ok := true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			patch_ok = patch_ok and game.floor_map.owner_of(Vector2i(8 + dx, 4 + dy)) == 1
	_check(patch_ok and game._pots.pots.is_empty() and game._board.score(1) == game.floor_map.count(1)
			and game._board.score(0) == game.floor_map.count(0),
			"a blob on the gold pot paints the 3 x 3 patch, takes tiles of the other player, and the scores follow (REQ-PG-23)")
	# A player leaves while a pot lies on the floor: the pot stays for the others (REQ-GM-21, REQ-PG-23).
	var left_body = game._bodies[0]
	game._bodies.erase(0)
	var lone = PaintPots.Pot.new()
	lone.kind = PaintPots.ROLLER
	lone.cell = Vector2i(2, 2)
	game._pots.pots.append(lone)
	game._bodies[1].pos = Vector2(1500.0, 800.0)
	game._tick_pots(0.016)
	_check(game._pots.pots.size() == 1 and game._pots.pots[0] == lone and game.floor_map.owner_of(Vector2i(2, 2)) != 1,
			"a pot stays on the floor when a player leaves and nobody stands on it (REQ-PG-23)")
	game._pots.pots.clear()
	game._bodies[0] = left_body
	# The sounds of the blobs (docs/AUDIO_PLAN.md, section 4.3).
	var sound: Node = root.get_node("Sound")
	var heard: Array[String] = []
	var listen := func(id: String): heard.append(id)
	sound.sfx_played.connect(listen)
	await create_timer(0.1).timeout   # The same effect twice in 40 ms is one sound.
	game._bodies[0].pos = Vector2(-5.0, 300.0)
	game._bodies[0].vel = Vector2(-800.0, 0.0)
	game._game_tick(0.016)
	_check(heard.has("paint_edge"), "a fast hit at the edge makes a sound: %s" % str(heard))
	heard.clear()
	game._bodies[0].pos = Vector2(600.0, 400.0)
	game._bodies[1].pos = Vector2(620.0, 400.0)
	game._bodies[0].vel = Vector2.ZERO
	game._bodies[1].vel = Vector2.ZERO
	game._game_tick(0.016)
	_check(heard.count("paint_bounce") == 1, "two blobs that touch make one bounce sound: %s" % str(heard))
	# The lead alert: only in the last 10 s, and only when the lead changes hands.
	var saved_time: float = game._round.time
	game._leader = -1
	game._board.set_score(0, 10.0)
	game._board.set_score(1, 5.0)
	game._lead_sound()
	heard.clear()
	game._board.set_score(1, 20.0)
	game._lead_sound()
	_check(not heard.has("paint_lead"), "no lead alert before the last 10 s: %s" % str(heard))
	game._round.time = game._round.duration - 5.0
	game._leader = 0
	game._lead_sound()
	_check(heard.has("paint_lead") and game._leader == 1, "the lead changes hands in the last 10 s: an alert")
	heard.clear()
	game._lead_sound()
	_check(heard.is_empty(), "the same leader again: no second alert")
	game._round.time = saved_time
	game._leader = -1
	sound.sfx_played.disconnect(listen)
	game._board.set_score(0, game.floor_map.count(0))
	game._board.set_score(1, game.floor_map.count(1))

	# A lost phone pauses the round and the clock does not run (REQ-PG-11): a phone that goes silent, like one without Wi-Fi.
	app.server.peer_timeout_ms = 2500
	clients[1].set_process(false)
	var waited := Time.get_ticks_msec()
	while not game.is_paused() and Time.get_ticks_msec() - waited < 8000:
		await _stream([clients[0]], 0.2, [flat])
	_check(game.is_paused() and not game.is_over, "a silent phone pauses the round")
	var clock: float = game._round.time
	await _stream([clients[0]], 1.0, [flat])
	_check(is_equal_approx(game._round.time, clock), "the clock does not run while a phone is lost (REQ-PG-11)")
	app.server.peer_timeout_ms = Protocol.PEER_TIMEOUT_MS

	# A player leaves (REQ-PG-10).
	var tiles1: int = game.floor_map.count(1)
	app.server.kick(1)
	await _frames(5)
	_check(not game._bodies.has(1) and not game.is_over and game.floor_map.count(1) == tiles1,
			"a player who leaves takes the blob out, the tiles stay and the round goes on")

	# Time is up with one player left: a technical win (gold medal), the difficulty is the title (REQ-PG-5, 6, 21).
	game._round.time = game.ROUND_TIME - 0.005
	game._game_tick(0.01)
	await _frames(3)
	var buttons: Array = game.menu_buttons().map(func(b): return b.text)
	var labels: Array = []
	for l in game._menu_box.find_children("*", "Label", true, false):
		labels.append(l.text)
	_check(game.is_over and buttons == ["minigame.restart", "minigame.new_game", "minigame.back_to_menu"],
			"time up opens the result menu: %s" % str(buttons))
	_check(labels[0] == "MEDIUM" and MedalView.tiers_in(game._menu_box) == ["gold"]
			and labels[1].contains(" TILES (") and labels[1].ends_with("%)"),
			"one player left gets the difficulty as the title, the gold medal and a list row with the tiles and the percent: %s" % str(labels))
	# The layout comes from the size of the screen (REQ-PG-17): the floor stays inside the margin at 1280x720 and at 1920x1080.
	var fits_ok := true
	for res in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = res
		await _frames(4)
		var fit: Dictionary = game._fit()
		var rect := Rect2(fit.origin, game.floor_map.size() * fit.k)
		var pitch: float = fit.k * game.REF_TILE
		fits_ok = fits_ok and fmod(pitch, 4.0) == 0.0 and fmod(fit.origin.x, 4.0) == 0.0 and fmod(fit.origin.y, 4.0) == 0.0 \
				and rect.position.x >= 59.0 and rect.end.x <= game.size.x - 59.0 and rect.position.y >= 149.0 \
				and rect.end.y <= game.size.y - 59.0
	_check(fits_ok, "the floor is inside the margin and under the HUD at 1280x720 and 1920x1080, and a tile is a whole number of "
			+ "world pixels (REQ-PG-17, REQ-PG-15)")
	_check(game._pixel_world() and game._pixel_viewport.size == Vector2i(480, 270),
			"the floor is drawn in the 480x270 pixel view (REQ-PG-15)")
	game.restart()
	await _frames(4)
	_check(is_instance_of(app.current_screen(), PaintGame) and app.current_screen().difficulty == "medium"
			and app.current_screen().floor_map.count(0) == 0, "Restart starts a new empty floor with the same difficulty")
	# The round ends when the last tile of the picture is painted, before the time is up (REQ-PG-5).
	var g2 = app.current_screen()
	g2._game_tick(4.0)   # The countdown is over.
	var open_tile := Vector2i(-1, -1)
	for i in g2._picture.size():
		if g2._picture[i] != PaintPicture.EMPTY:
			if open_tile.x < 0:
				open_tile = Vector2i(i % g2.floor_map.cols, i / g2.floor_map.cols)
			else:
				g2.floor_map.paint(Vector2i(i % g2.floor_map.cols, i / g2.floor_map.cols), 0)
	g2._game_tick(0.01)
	_check(not g2.is_over, "one picture tile without a color: the round goes on")
	g2.floor_map.paint(open_tile, 1)
	g2._game_tick(0.01)
	_check(g2.is_over and g2._round.remaining() > 30.0,
			"the last picture tile painted (another color): the round ends before the time")
	# Only the tiles of the picture can be painted and count (REQ-PG-24, issue #130).
	app.go(g2.get_script(), {"difficulty": "medium", "seed": 7})
	await _frames(3)
	var g3 = app.current_screen()
	g3._game_tick(4.0)
	var cols: int = g3.floor_map.cols
	var inside := Vector2i(-1, -1)
	var outside := Vector2i(-1, -1)
	var edge := Vector2i(-1, -1)   # A picture tile with a tile outside the picture in its 3 x 3 patch.
	for i in g3._picture.size():
		var c := Vector2i(i % cols, i / cols)
		if g3._picture[i] == PaintPicture.EMPTY:
			outside = c
		elif inside.x < 0:
			inside = c
		if g3._picture[i] != PaintPicture.EMPTY and edge.x < 0 and c.x > 0 and c.y > 0 and c.x < cols - 1 \
				and c.y < g3.floor_map.rows - 1:
			for d in [Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1)]:
				if g3._picture[(c.y + d.y) * cols + c.x + d.x] == PaintPicture.EMPTY:
					edge = c
	g3._bodies[0].pos = (Vector2(outside) + Vector2(0.5, 0.5)) * g3.floor_map.tile
	g3._paint_under(0)
	_check(g3.floor_map.owner_of(outside) == -1 and g3.floor_map.count(0) == 0 and not g3.is_paintable(outside),
			"a blob over a tile outside the picture paints nothing and nothing counts")
	g3._bodies[0].pos = (Vector2(inside) + Vector2(0.5, 0.5)) * g3.floor_map.tile
	g3._paint_under(0)
	_check(g3.floor_map.owner_of(inside) == 0 and g3.floor_map.count(0) == 1 and g3.is_paintable(inside),
			"a blob over a tile of the picture paints it")
	_check(g3.percent_of(g3._picture_total) == 100 and g3.percent_of(g3._picture_total / 2) == 50 and g3.best_value(1.0) >= 1
			and g3._picture_total < g3.floor_map.total(),
			"the percent and the personal best are counted on the picture tiles, not on the whole floor (REQ-PG-21, 31)")
	var gold := PaintPots.Pot.new()
	gold.kind = PaintPots.GOLD
	gold.cell = edge
	g3._apply_pot(1, gold)
	var painted := 0
	var stray := 0
	for i in g3._picture.size():
		if g3.floor_map.owners[i] == 1:
			painted += 1
			stray += 1 if g3._picture[i] == PaintPicture.EMPTY else 0
	_check(edge.x >= 0 and painted >= 1 and painted < 9 and stray == 0,
			"a gold pot paints only the picture tiles of its patch (%d of 9)" % painted)

	for c in clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
