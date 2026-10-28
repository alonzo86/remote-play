extends SceneTree
## Treasure Maze with simulated phones, stepped by hand (REQ-MZ-1 to 14, test 6 of docs/MANUAL_TESTS.md). Run:
##   godot --headless --path . --script tests/smoke_maze.gd -- --role=tv
## The tilt of a phone is written into the player (a fake clock), so a test of many game seconds takes a fraction of a second.

const Sim = preload("res://tests/sim_b.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const MazeBoard = preload("res://scripts/game/maze/maze_board.gd")
const MazeGenerator = preload("res://scripts/game/maze/maze_generator.gd")
const Shell = preload("res://scripts/game/shell.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Lang = preload("res://scripts/core/lang.gd")

var _fails := 0
var _checks := 0
var MazeGame
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
	MazeGame = load("res://scripts/game/maze/maze_game.gd")
	sim = Sim.new(self)
	await sim.join(4)
	_check(sim.app.server.connected_slots().size() == 4, "four simulated phones joined")
	for s in 4:
		sim.settle(s, Sim.FLAT)
	await _countdown_and_recenter()
	await _flat_phone_stays()
	await _phone_to_ball()
	await _balls_never_in_walls()
	_levels()
	await _size_margin_corridor()
	await _look()
	await _window_sizes()
	await _wall_edges()
	await _torch_flames()
	await _titles()
	_check_colors()
	_check_strings()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Test 6.1 and 6.5c: the balls do not move in "3, 2, 1" even when the phone is leaned, and after GO the pose that was held is
## the center, so a phone that is still leaned does not move the ball (REQ-MZ-3, REQ-GM-35).
func _countdown_and_recenter() -> void:
	print("maze: countdown and GO")
	var game: Control = await sim.start(MazeGame, {"difficulty": "medium"})
	var lean := {}
	for s in 4:
		lean[s] = Sim.lean(15.0)
		sim.settle(s, lean[s])
	var start: Array = game._balls.map(func(b): return b.pos)
	var at3 := -1.0
	var at1 := -1.0
	var moved_in_count := 0.0
	while game._round.is_counting():
		sim.step(game, Sim.DT, lean)
		if game._round.is_counting():
			for i in 4:
				moved_in_count = maxf(moved_in_count, game._balls[i].pos.distance_to(start[i]))
			if game._round.count_number() == 3 and at3 < 0.0:
				at3 = moved_in_count
			if game._round.count_number() == 1:
				at1 = moved_in_count
	_check(at3 == 0.0 and at1 == 0.0 and moved_in_count == 0.0,
			"a 15 degree lean in '3, 2, 1' moves no ball (0.0 px, REQ-MZ-3): %.2f" % moved_in_count)
	var tilt_at_go := 0.0
	for s in 4:
		tilt_at_go = maxf(tilt_at_go, sim.app.server.players[s].tilt().length())
	_check(tilt_at_go < 0.05, "at GO every phone is recentered: tilt %.3f < 0.05 (REQ-GM-37)" % tilt_at_go)
	var at_go: Array = game._balls.map(func(b): return b.pos)
	sim.step(game, 3.0, lean)
	var drift := 0.0
	for i in 4:
		drift = maxf(drift, game._balls[i].pos.distance_to(at_go[i]))
	_check(drift < 36.0, "3 s after GO with the phone still leaned the ball moved %.1f px < 36 px (REQ-MZ-3)" % drift)

	# Test 6.5a (machine half): RECENTER while the phone is held leaned, the ball stays (REQ-GM-37).
	game._balls[0].vel = Vector2.ZERO
	sim.step(game, 0.6, {0: Sim.lean(15.0)})
	sim.clients[0].send_recenter()
	var waited := Time.get_ticks_msec()
	while Time.get_ticks_msec() - waited < 1500 and sim.app.server.players[0].tilt().length() > 0.05:
		sim.feed(0, Sim.lean(15.0))
		await process_frame
	game.set_process(false)
	_check(sim.app.server.players[0].tilt().length() < 0.05, "the RECENTER button of a phone reached the player (tilt < 0.05)")
	game._balls[0].vel = Vector2.ZERO
	var p0: Vector2 = game._balls[0].pos
	sim.step(game, 5.0, {0: func(t): return Sim.lean(15.0) + Vector3(0.0, sin(t * 0.7) * 0.15, 0.0)})
	var d5: float = game._balls[0].pos.distance_to(p0)
	_check(d5 < 36.0, "after RECENTER the ball moved %.1f px < 36 px in 5 s with the phone still leaned (REQ-GM-37)" % d5)

	# Test 6.5b: A and B do not recenter.
	sim.settle(1, Sim.FLAT)
	sim.app.server.players[1].recenter()
	sim.settle(1, Sim.lean(-15.0))
	sim.app.server.players[1].button_pressed.emit(Protocol.BTN_A)
	sim.app.server.players[1].button_pressed.emit(Protocol.BTN_B)
	_check(sim.app.server.players[1].tilt().length() > 0.2, "A and B do not recenter in the maze (REQ-MZ-8)")
	var b1: Object = game._balls[1]
	b1.vel = Vector2.ZERO
	var before: Vector2 = b1.pos
	sim.step(game, 0.2, {1: Sim.lean(-15.0)})   # Short: the ball has room to the left and meets no wall.
	_check(b1.pos.x < before.x - 5.0, "the ball still follows the tilt after 5 presses of A and B: %.1f px to the left" %
			(before.x - b1.pos.x))


## Test 6.2a: a phone that lies flat on a table with sensor noise does not move the ball (dead zone, REQ-MZ-4).
func _flat_phone_stays() -> void:
	print("maze: a flat phone")
	var game: Control = await sim.start(MazeGame, {"difficulty": "medium"})
	for s in 4:
		sim.settle(s, Sim.FLAT)
	sim.through_countdown(game)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var start: Vector2 = game._balls[0].pos
	var worst_speed := 0.0
	for t in 600:   # 10 game seconds
		var noise := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0.0) * 0.02 * 9.81
		sim.feed(0, Sim.FLAT + noise)
		game._game_tick(Sim.DT)
		worst_speed = maxf(worst_speed, game._balls[0].vel.length())
	var moved: float = game._balls[0].pos.distance_to(start)
	_check(moved < 2.0 and worst_speed < 1.0, "a flat phone with noise: the ball moved %.2f px, top speed %.2f px/s" % [moved,
			worst_speed])


## Test 6.4b: each phone moves its own ball and no other (REQ-GM-24).
func _phone_to_ball() -> void:
	print("maze: phone to ball")
	var game: Control = await sim.start(MazeGame, {"difficulty": "medium"})
	for s in 4:
		sim.settle(s, Sim.FLAT)
		sim.app.server.players[s].recenter()
	sim.through_countdown(game)
	var ok := true
	for i in 4:
		for b in game._balls:
			b.vel = Vector2.ZERO
		var before: Array = game._balls.map(func(b): return b.pos)
		var toward := -signf(before[i].x - game.cell * 0.5)   # Toward the middle of the start cell: there is room.
		var accels := {}
		for s in 4:
			accels[s] = Sim.lean(15.0 * toward) if s == i else Sim.FLAT
		sim.step(game, 1.0, accels)
		var own: float = game._balls[i].pos.distance_to(before[i])
		var others := 0.0
		for j in 4:
			if j != i:
				others = maxf(others, game._balls[j].pos.distance_to(before[j]))
		var good: bool = own > 20.0 and others < 1.0
		ok = ok and good
		print("    phone %d: its ball %.1f px, the others at most %.2f px" % [i, own, others])
		for s in 4:
			sim.settle(s, Sim.FLAT)
			sim.app.server.players[s].recenter()
	_check(ok, "tilting one phone moves its own ball more than 20 px in 1 s and every other ball less than 1 px (REQ-GM-24)")


## Test 6.2b: a ball is never inside or on a wall, on every difficulty, with a phone that is tilted hard in changing directions.
func _balls_never_in_walls() -> void:
	print("maze: the ball never enters a wall")
	var worst := INF
	var rng := RandomNumberGenerator.new()
	for d in ["easy", "medium", "hard"]:
		var game: Control = await sim.start(MazeGame, {"difficulty": d})
		var lv: Dictionary = MazeGame.LEVELS[d]
		sim.settle(0, Sim.FLAT)
		sim.through_countdown(game)
		for seed_value in 8:
			rng.seed = 1000 + seed_value
			game._maze.generate(game.cols, game.rows, rng, float(lv.openings))
			game._walls = game._maze.wall_rects(game.cell, MazeGame.WALL)
			var b = game._balls[0]
			b.pos = Vector2(game.cell, game.cell) * 0.5
			b.vel = Vector2.ZERO
			var angle := rng.randf() * TAU
			for t in 900:   # 15 game seconds
				if t % 30 == 0:
					angle = rng.randf() * TAU   # Full tilt in a new direction every half second.
				sim.feed(0, Sim.lean(30.0 * cos(angle), 30.0 * sin(angle)))
				game._step_ball(b, Sim.DT)
				for r in game._walls:
					if not r.grow(MazeGame.BALL_R + 1.0).has_point(b.pos):
						continue
					var nearest := Vector2(clampf(b.pos.x, r.position.x, r.end.x), clampf(b.pos.y, r.position.y, r.end.y))
					worst = minf(worst, b.pos.distance_to(nearest))
	_check(worst >= MazeGame.BALL_R - 0.5, ("3 difficulties x 8 mazes x 15 s of hard tilt: closest the ball center got to a wall "
			+ "is %.2f px (>= %.1f, REQ-MZ-4)") % [worst, MazeGame.BALL_R - 0.5])


## Test 6.6c: the size of each difficulty (REQ-MZ-9).
func _levels() -> void:
	print("maze: levels")
	var levels: Dictionary = MazeGame.LEVELS
	_check(levels.easy.cols == 13 and levels.easy.rows == 6 and levels.medium.cols == 16 and levels.medium.rows == 8
			and levels.hard.cols == 18 and levels.hard.rows == 9, "Easy is 13 x 6, Medium 16 x 8, Hard 18 x 9 cells (REQ-MZ-9)")


func _fit_of(game: Control) -> Dictionary:
	var o: Vector2 = game._origin()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for r in game._walls:
		lo = lo.min(r.position)
		hi = hi.max(r.end)
	return {"left": o.x + lo.x, "right": 1920.0 - (o.x + hi.x), "bottom": 1080.0 - (o.y + hi.y), "top": o.y + lo.y - 112.0}


## Test 6.6c, 6.6d, 6.6e: the started maze has the size, every cell can be reached, the walls are inside the margin, and a ball
## crosses the longest straight corridor with a 15 degree lean without stopping.
func _size_margin_corridor() -> void:
	print("maze: size, margin, corridor")
	for d in ["easy", "medium", "hard"]:
		var game: Control = await sim.start(MazeGame, {"difficulty": d})
		var lv: Dictionary = MazeGame.LEVELS[d]
		var m: MazeGenerator = game._maze
		var seen := {Vector2i.ZERO: true}
		var queue: Array[Vector2i] = [Vector2i.ZERO]
		while not queue.is_empty():
			var c: Vector2i = queue.pop_front()
			for step in [[Vector2i(1, 0), c.x + 1 < m.cols and not m.v[c.y][c.x + 1]],
					[Vector2i(-1, 0), c.x > 0 and not m.v[c.y][c.x]],
					[Vector2i(0, 1), c.y + 1 < m.rows and not m.h[c.y + 1][c.x]],
					[Vector2i(0, -1), c.y > 0 and not m.h[c.y][c.x]]]:
				if step[1] and not seen.has(c + step[0]):
					seen[c + step[0]] = true
					queue.append(c + step[0])
		_check(game.cols == int(lv.cols) and game.rows == int(lv.rows) and seen.size() == game.cols * game.rows,
				"%s: started as %d x %d and all %d cells are reachable (found %d)" % [d, game.cols, game.rows,
				game.cols * game.rows, seen.size()])
		var fit := _fit_of(game)
		var top_min := 52.0 if d == "easy" else 16.0
		_check(fit.left >= 60.0 and fit.right >= 60.0 and fit.bottom >= 60.0 and fit.top >= top_min - 0.01,
				"%s: walls %.0f px from the left, %.0f from the right, %.0f from the bottom (>= 60), %.0f under the bar (>= %.0f)"
				% [d, fit.left, fit.right, fit.bottom, fit.top, top_min])
		var best := {"len": 0, "row": 0, "col": 0}
		for y in m.rows:
			var run := 0
			for x in m.cols:
				if x > 0 and m.v[y][x]:
					run = 0
				run += 1
				if run > best.len:
					best = {"len": run, "row": y, "col": x - run + 1}
		sim.settle(0, Sim.FLAT)
		sim.through_countdown(game)
		var b = game._balls[0]
		b.pos = (Vector2(best.col, best.row) + Vector2(0.5, 0.5)) * game.cell
		b.vel = Vector2.ZERO
		var target_x: float = (best.col + best.len - 0.5) * game.cell
		var slowest := INF
		var t := 0
		sim.settle(0, Sim.lean(15.0))
		while b.pos.x < target_x - 2.0 and t < 60 * 30:
			sim.feed(0, Sim.lean(15.0))
			game._step_ball(b, Sim.DT)
			t += 1
			if t > 30:
				slowest = minf(slowest, b.vel.length())
		print("    %s: the longest straight corridor is %d cells, crossed in %.2f s" % [d, best.len, t * Sim.DT])
		_check(b.pos.x >= target_x - 2.0 and (best.len < 3 or slowest > 50.0),
				"%s: a ball crosses the straight corridor of %d cells; its slowest speed is %.0f px/s (> 50)" % [d, best.len,
						slowest])


## Test 6.7a, d: the picture of the board has only palette colors, the pixel layer has the right size and filter.
func _look() -> void:
	print("maze: pixel look")
	for theme in MazeBoard.THEMES:
		var game: Control = await sim.start(MazeGame, {"difficulty": "medium", "maze_theme": theme})
		var o: Vector2 = game._origin()
		var rects: Array[Rect2] = []
		for r in game._walls:
			rects.append(Rect2(o + r.position, r.size))
		var start := Rect2(o + Vector2(28, 28) * 0.5, Vector2(game.cell, game.cell) - Vector2(28, 28))
		var img: Image = MazeBoard.render(theme, rects, start, Vector2i(480, 270))
		var c: Dictionary = MazeBoard.THEMES[theme]
		var palette := {}
		for key in ["ground_a", "ground_b", "tuft", "flower", "outline", "face", "light", "front", "start"]:
			palette[(c[key] as Color).to_html(false)] = true
		for extra in [Color.WHITE, Color.BLACK, Color("f8b800")]:
			palette[extra.to_html(false)] = true
		for name in c.deco:
			for col in MazeBoard.SPRITES[name].colors.values():
				if col is Color:
					palette[(col as Color).to_html(false)] = true
		var stray := {}
		var alpha_ok := true
		for y in img.get_height():
			for x in img.get_width():
				var px := img.get_pixel(x, y)
				alpha_ok = alpha_ok and px.a == 1.0
				if not palette.has(px.to_html(false)):
					stray[px.to_html(false)] = true
		_check(stray.is_empty() and alpha_ok, "%s: every pixel of the board is a color of the palette, none blended (%s)"
				% [theme, str(stray.keys().slice(0, 3))])
		var vp: SubViewport = game._pixel_viewport
		_check(vp.size == Vector2i(480, 270) and vp.size_2d_override == Vector2i(1920, 1080)
				and vp.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
				and 1920 / vp.size.x == 4, "%s: the world is drawn in 480 x 270 with the nearest filter, scale 4 (REQ-GM-47a)" % theme)
	var src := FileAccess.get_file_as_string("res://scripts/game/maze/maze_game.gd")
	_check(src.contains("func _draw_ball(ci: CanvasItem, pos: Vector2, color: Color, vel: Vector2)")
			and src.contains("func _draw_chest(ci: CanvasItem, c: Vector2)") and src.count("MazeBoard.render(maze_theme") == 1,
			"the theme only goes to the board picture: ball and chest drawing have no theme argument (REQ-MZ-7)")
	var game: Control = await sim.start(MazeGame, {"difficulty": "medium"})
	_check(game._winner == -1, "a round starts with the chest closed (no winner)")
	sim.settle(0, Sim.FLAT)
	sim.through_countdown(game)
	game._balls[0].pos = game._exit_center()
	game._game_tick(Sim.DT)
	_check(game._winner == 0 and game.is_over, "a ball in the exit sets the winner at once, so the chest draws open (REQ-MZ-7)")


## Issue #45: on a window that is not 1920 x 1080 (a maximized window on a Mac) the picture of the walls is where the collision
## walls are: the middle of a wall is not ground in the picture, the middle of a corridor cell is.
func _window_sizes() -> void:
	print("maze: the picture follows the window")
	for theme in MazeBoard.THEMES:
		var game: Control = await sim.start(MazeGame, {"difficulty": "medium", "maze_theme": theme})
		var c: Dictionary = MazeBoard.THEMES[theme]
		var ground := {}
		for key in ["ground_a", "ground_b", "tuft", "flower", "start"]:
			ground[(c[key] as Color).to_html(false)] = true
		for win in [Vector2(1920, 1080), Vector2(2450, 1230), Vector2(1920, 1350)]:   # The window never gets smaller than 1920 x 1080.
			game.size = win
			var img: Image = game.board_image()
			var o: Vector2 = game._origin()
			var unit: Vector2 = game._unit()
			var on_wall := 0
			var checked := 0
			for r in game._walls:
				if minf(r.size.x, r.size.y) < 20.0:
					continue
				checked += 1
				var p: Vector2 = (o + r.get_center()) / unit
				if not ground.has(img.get_pixelv(Vector2i(p)).to_html(false)):
					on_wall += 1
			_check(checked > 20 and on_wall == checked,
					"%s, window %dx%d: %d of %d wall middles are wall in the picture" % [theme, win.x, win.y, on_wall, checked])
			var cell_mid: Vector2 = (o + Vector2(game.cell, game.cell) * 0.5) / unit
			_check(ground.has(img.get_pixelv(Vector2i(cell_mid)).to_html(false)),
					"%s, window %dx%d: the middle of the start cell is ground in the picture" % [theme, win.x, win.y])
		game.size = Vector2(1920, 1080)


## The edges of the walls in the mask of the picture are within half a world pixel of the collision rectangle: along the middle of
## every wall, a pixel is wall exactly when its center is between the two edges (the corridors are at least 15 pixels wide).
func _wall_edges() -> void:
	print("maze: the edges of the walls")
	var game: Control = await sim.start(MazeGame, {"difficulty": "medium", "maze_theme": "garden"})
	for win in [Vector2(1920, 1080), Vector2(2450, 1230), Vector2(1920, 1350)]:
		game.size = win
		var rects: Array[Rect2] = game.board_rects()
		var mask: PackedByteArray = MazeBoard._mask(rects, Vector2i(480, 270))
		var wrong := 0
		var checked := 0
		for r in rects:
			var l := r.position / 4.0
			var e := r.end / 4.0
			var horizontal := r.size.x > r.size.y
			var lo := l.y if horizontal else l.x
			var hi := e.y if horizontal else e.x
			var along := int((l.x + e.x) * 0.5) if horizontal else int((l.y + e.y) * 0.5)
			for i in range(maxi(int(floor(lo)) - 2, 0), int(ceil(hi)) + 2):
				var center := float(i) + 0.5
				var xi := along if horizontal else i
				var yi := i if horizontal else along
				if absf(center - lo) < 0.01 or absf(center - hi) < 0.01 or xi >= 480 or yi >= 270:
					continue
				checked += 1
				if (mask[yi * 480 + xi] != 0) != (center > lo and center < hi):
					wrong += 1
		_check(checked > 500 and wrong == 0,
				"window %dx%d: %d edge pixels of the walls checked, %d on the wrong side" % [win.x, win.y, checked, wrong])
		var scaled_ok := true
		var unit: Vector2 = game._unit()
		for i in game._walls.size():
			var truth := Rect2(game._origin() + game._walls[i].position, game._walls[i].size)
			var back := Rect2(rects[i].position * unit / 4.0, rects[i].size * unit / 4.0)
			scaled_ok = scaled_ok and back.position.distance_to(truth.position) < 0.01 and back.size.distance_to(truth.size) < 0.01
		_check(scaled_ok, "window %dx%d: the picture rectangles are the collision walls in the window pixels" % [win.x, win.y])
	game.size = Vector2(1920, 1080)


func _torch_flames() -> void:
	print("maze: torch flames")
	var rows: Array = MazeBoard.SPRITES.torch.rows
	var clear := true
	for y in 5:
		clear = clear and String(rows[y]).replace(".", "") == ""
	_check(clear, "the top 5 rows of the torch picture are empty: the flame is not in the board picture (REQ-MZ-14)")
	var frames: Array = MazeBoard.FLAME_FRAMES
	var distinct := true
	for i in frames.size():
		for j in range(i + 1, frames.size()):
			distinct = distinct and str(frames[i]) != str(frames[j])
	_check(frames.size() >= 3 and distinct, "the flame has %d frames and they all differ (REQ-MZ-14)" % frames.size())
	var f0: Array = MazeBoard.flame_squares(Vector2i(10, 20), 0, Vector2(4, 4))
	var f1: Array = MazeBoard.flame_squares(Vector2i(10, 20), 1, Vector2(4, 4))
	var wide: Array = MazeBoard.flame_squares(Vector2i(10, 20), 0, Vector2(5, 4.5))
	var first: Rect2 = wide[0][0]
	_check(first.size == Vector2(5, 4.5) and is_equal_approx(first.position.x / 5.0, roundf(first.position.x / 5.0)),
			"a flame follows the size of a world pixel of the window (5 x 4.5 units)")
	_check(not f0.is_empty() and str(f0) != str(f1) and (f0[0][0] as Rect2).size == Vector2(4, 4),
			"two frames draw different squares of one world pixel (4 x 4 units)")
	var inside := true
	for sq in f0:
		var r: Rect2 = sq[0]
		inside = inside and r.position.x >= 40.0 and r.end.x <= 40.0 + 8 * 4.0 and r.position.y >= 80.0 and r.end.y <= 80.0 + 5 * 4.0
	_check(inside, "a flame stays inside its 8 x 5 world pixel box above the torch")
	var seq: Array = []
	for i in 12:
		seq.append(MazeBoard.flame_frame(i * MazeBoard.FLAME_S + 0.01))
	var changes := 0
	for i in range(1, seq.size()):
		changes += 1 if seq[i] != seq[i - 1] else 0
	_check(changes == 11 and seq.slice(0, 4) == [0, 1, 2, 0] and MazeBoard.flame_frame(0.19) == 0
			and MazeBoard.flame_frame(0.21) == 1, "the frame changes every %.1f s and goes round: %s" % [MazeBoard.FLAME_S,
					str(seq)])
	var garden: Control = await sim.start(MazeGame, {"difficulty": "medium", "maze_theme": "garden"})
	garden._make_board_texture()
	var garden_torches: int = garden._torches.size()
	var castle: Control = await sim.start(MazeGame, {"difficulty": "medium", "maze_theme": "castle"})
	castle._make_board_texture()
	_check(castle._torches.size() == 2 and garden_torches == 0, "the castle has 2 flames, the garden has none")
	# Game time: a pause stops the flames (REQ-FL-43).
	castle.set_process(true)
	await sim.frames(10)
	var t0: float = castle._ring_time
	_check(t0 > 0.0, "the game time of the flames runs while the game plays")
	castle.open_menu("minigame.paused", [["minigame.resume", castle.close_menu]])
	await sim.frames(2)
	var t1: float = castle._ring_time
	await sim.frames(20)
	_check(castle._ring_time == t1, "the flames stand still while the pause menu is open")
	castle.close_menu()
	await sim.frames(10)
	_check(castle._ring_time > t1, "the flames burn again after Resume")
	castle.set_process(false)
	# The chest sparkle: two spots in turn, 0.55 s each (step 6.7c).
	_check(is_equal_approx(UiTheme.BLINK_S, 0.55) and UiTheme.blink_on(0.0) and UiTheme.blink_on(0.54)
			and not UiTheme.blink_on(0.56) and not UiTheme.blink_on(1.09) and UiTheme.blink_on(1.11),
			"the chest sparkle changes place every 0.55 s")


## Test 6.7c: the title ends before the timer box, in English and in Hebrew.
func _titles() -> void:
	print("maze: title and timer")
	var game: Control = await sim.start(MazeGame, {"difficulty": "medium"})
	for code in ["en", "he"]:
		Lang.set_language(code)
		var shown := Lang.t("registry.treasure_maze").to_upper()
		var w := UiTheme.font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		var t_left := Shell.mx(game, 60.0, w)
		var timer_w := Shell.timer_width(Lang.f("shell.seconds", [99.9]).to_upper(), MazeGame.TIMER_W)
		var m_left := Shell.mx(game, MazeGame.TIMER_X, timer_w)
		var gap := (m_left - (t_left + w)) if not Lang.is_rtl() else (t_left - (m_left + timer_w))
		_check(gap >= 1.0, "%s: the title (%.0f px wide) ends %.0f px before the timer box" % [code, w, gap])
	Lang.set_language("en")


## The color difference of two colors in CIE Lab (CIE76), D65 white.
func _delta_e(a: Color, b: Color) -> float:
	var la := _lab(a)
	var lb := _lab(b)
	return la.distance_to(lb)


func _lab(c: Color) -> Vector3:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var bl: float = lin.call(c.b)
	var x := (0.4124 * r + 0.3576 * g + 0.1805 * bl) / 0.95047
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * bl
	var z := (0.0193 * r + 0.1192 * g + 0.9505 * bl) / 1.08883
	var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	return Vector3(116.0 * f.call(y) - 16.0, 500.0 * (f.call(x) - f.call(y)), 200.0 * (f.call(y) - f.call(z)))


func _check_colors() -> void:
	print("maze: player colors")
	var pc: Array = Protocol.PLAYER_COLORS
	var from_phone := true
	var from_game := true
	for s in 4:
		from_phone = from_phone and sim.clients[s].color == pc[s]
		from_game = from_game and sim.app.server.players[s].color == pc[s]
	_check(from_phone and from_game, "the color a phone shows is the color of its ball (Protocol.PLAYER_COLORS by slot)")
	var apart := true
	var ground_ok := true
	for i in 4:
		for j in range(i + 1, 4):
			apart = apart and _delta_e(pc[i], pc[j]) >= 25.0
		for theme in MazeBoard.THEMES:
			for g in [MazeBoard.THEMES[theme].ground_a, MazeBoard.THEMES[theme].ground_b]:
				ground_ok = ground_ok and maxf(UiTheme.contrast(Color.WHITE, g), UiTheme.contrast(pc[i], g)) >= 3.0
	_check(apart, "the four player colors are at least 25 apart in CIE Lab (REQ-GM-24)")
	_check(ground_ok, "the white ring or the color of every ball stands out (3:1) from both grounds of all themes (REQ-MZ-7)")


func _check_strings() -> void:
	print("maze: names")
	Lang.set_language("en")
	var en := Lang.t("registry.treasure_maze")
	Lang.set_language("he")
	var he := Lang.t("registry.treasure_maze")
	Lang.set_language("en")
	_check(en == "TREASURE MAZE" and he == "מבוך האוצר" and he.strip_edges() != "", "the name is TREASURE MAZE and מבוך האוצר")
