extends SceneTree
## The pure rules of the minigames, without a screen: the Puffs of Snowball Splat (REQ-SS-3, 7 to 10, 12).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/game_rules.gd -- --role=controller

const Shell = preload("res://scripts/game/shell.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const MazeGenerator = preload("res://scripts/game/maze/maze_generator.gd")
const MazeBoard = preload("res://scripts/game/maze/maze_board.gd")
const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")
const Medals = preload("res://scripts/game/medals.gd")
const SumoArena = preload("res://scripts/game/sumo_bumpers/sumo_arena.gd")
const TiltBody = preload("res://scripts/game/tilt_body.gd")
const PaintFloor = preload("res://scripts/game/paint_grab/paint_floor.gd")
const PuffField = preload("res://scripts/game/snowball_splat/puff_field.gd")

const AREA := Rect2(60.0, 150.0, 1800.0, 870.0)   # The play area at 1920x1080.

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
	_aim()
	_kinds_and_lanes()
	_flying()
	_spawning()
	_hit_test()
	_visual_rules()
	_maze_levels()
	_difficulty()
	_test_marble_track()
	_tilt_body()
	_paint_floor()
	_paint_levels()
	_sumo_arena()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## A Puff in lane `lane` (0 top: Little Puffs to the right, 1 middle: Puffs to the left, 2 bottom: Puffs to the right) at `x`
## (px of the play area), at the start of its wave.
func _puff(lane: int, x: float) -> PuffField.Puff:
	var p := PuffField.Puff.new()
	p.lane = lane
	p.kind = PuffField.LANES[lane].kind
	p.dir = PuffField.LANES[lane].dir
	p.lane_y = PuffField.LANES[lane].y
	p.radius = PuffField.KINDS[p.kind].radius
	p.speed = PuffField.KINDS[p.kind].speed
	p.points = PuffField.KINDS[p.kind].points
	p.x = x
	return p


func _aim() -> void:
	print("snowball splat: aim")
	var c := AREA.get_center()
	_check(PuffField.aim_to_screen(Vector2.ZERO, AREA) == c, "pointer 0 is the center of the play area (REQ-SS-3)")
	_check(PuffField.aim_to_screen(Vector2(-1, -1), AREA) == AREA.position
			and PuffField.aim_to_screen(Vector2(1, 1), AREA) == AREA.end, "pointer -1 and +1 are the corners of the play area")
	_check(PuffField.aim_to_screen(Vector2(0.5, -0.5), AREA) == c + Vector2(AREA.size.x * 0.25, -AREA.size.y * 0.25),
			"pointer 0.5 is a quarter of the area from the center")
	_check(PuffField.aim_to_screen(Vector2(7, -9), AREA) == Vector2(AREA.end.x, AREA.position.y),
			"the cursor stays inside the play area")
	var small := Rect2(60.0, 150.0, 1160.0, 510.0)   # A 1280x720 screen.
	_check(is_equal_approx(PuffField.scale_for(AREA), 1.0) and PuffField.scale_for(small) < 0.6,
			"the scale is 1 at 1920x1080 and smaller on a small screen (REQ-SS-15)")


func _kinds_and_lanes() -> void:
	print("snowball splat: kinds and lanes")
	var kinds: Dictionary = PuffField.KINDS
	_check(kinds.puff.points == 10 and kinds.puff.radius == 100.0 and kinds.puff.speed == 100.0
			and kinds.little.points == 25 and kinds.little.radius == 72.0 and kinds.little.speed == 160.0,
			"Puff: 10 points, radius 100, 100 px/s. Little Puff: 25 points, radius 72, 160 px/s (REQ-SS-7)")
	var slow := true
	var big := true
	for k in kinds:
		slow = slow and float(kinds[k].speed) <= 200.0
		big = big and float(kinds[k].radius) >= 72.0
	_check(slow and big, "no Puff is faster than 200 px/s, and every Puff is at least 144 px wide (REQ-SS-7, REQ-GM-82)")
	var inside := true
	var kinds_ok := true
	for lane in PuffField.LANES:
		var r: float = kinds[lane.kind].radius
		inside = inside and lane.y - r - PuffField.WAVE >= 0.0 and lane.y + r + PuffField.WAVE <= PuffField.REF_AREA.y - 70.0
		kinds_ok = kinds_ok and kinds.has(lane.kind) and (lane.dir == 1 or lane.dir == -1)
	_check(inside and kinds_ok, "every lane, with its wave, is inside the play area and above the snow (REQ-SS-8)")
	_check(PuffField.LANES.size() == 3, "there are 3 lanes")
	var p := _puff(1, 500.0)
	p.age = PuffField.WAVE_TIME * 0.25
	var top := p.y()
	p.age = PuffField.WAVE_TIME * 0.75
	_check(is_equal_approx(top, p.lane_y + PuffField.WAVE) and is_equal_approx(p.y(), p.lane_y - PuffField.WAVE),
			"a Puff goes up and down 28 px around its lane")


func _flying() -> void:
	print("snowball splat: flying")
	var f := PuffField.new()
	var p := _puff(1, 500.0)   # The middle lane flies to the left.
	f.puffs.append(p)
	f.tick(1.0, _rng(1), 99)
	_check(p.dir == -1 and is_equal_approx(p.x, 400.0), "a Puff of the middle lane flies left at 100 px/s: x = %.1f" % p.x)
	var q := _puff(0, 0.0)   # The top lane flies to the right.
	var g := PuffField.new()
	g.puffs.append(q)
	g.tick(0.5, _rng(1), 99)
	_check(q.dir == 1 and is_equal_approx(q.x, 80.0), "a Little Puff of the top lane flies right at 160 px/s: x = %.1f" % q.x)
	var once := _puff(1, 1200.0)
	var split := _puff(1, 1200.0)
	var fa := PuffField.new()
	var fb := PuffField.new()
	fa.puffs.append(once)
	fb.puffs.append(split)
	fa.tick(2.0, _rng(2), 0)
	for i in 200:
		fb.tick(0.01, _rng(2), 0)
	_check(absf(once.x - split.x) < 0.01 and absf(once.age - split.age) < 0.0001,
			"the flight does not depend on the frame time (REQ-GM-13): %.3f and %.3f" % [once.x, split.x])
	var leaving := _puff(1, 150.0)
	var h := PuffField.new()
	h.puffs.append(leaving)
	var away := h.tick(2.0, _rng(3), 0)   # 150 - 200 = -50: still inside the edge zone (radius 100).
	away += h.tick(1.0, _rng(3), 0)       # -150 is beyond -radius - 2.
	_check(away == 1 and not h.puffs.has(leaving), "a Puff that flew out of the other edge is gone and nothing else happens")


func _spawning() -> void:
	print("snowball splat: coming in")
	var rng := _rng(11)
	var f := PuffField.new()
	f.tick(0.01, rng, 2)
	_check(f.puffs.size() == 1, "the first Puff comes at once (REQ-SS-9)")
	var first := f.puffs[0]
	var right_edge: float = PuffField.REF_AREA.x + first.radius
	var edge_ok := (first.dir > 0 and first.x <= -first.radius + 0.5) or (first.dir < 0 and first.x >= right_edge - 0.5)
	_check(edge_ok and first.kind == PuffField.LANES[first.lane].kind,
			"a Puff comes in at the edge of its lane, with the kind of the lane")
	f.tick(1.0, rng, 2)
	_check(f.puffs.size() == 1, "the next Puff waits for the 1.5 s")
	f.tick(0.6, rng, 2)
	_check(f.puffs.size() == 2, "a new Puff every 1.5 s")
	var overlaps := false
	var too_many := false
	var colors_ok := true
	var run := PuffField.new()
	var rng2 := _rng(5)
	for i in 3600:   # 2 minutes at 30 frames per second, 3 players.
		run.tick(1.0 / 30.0, rng2, 3)
		too_many = too_many or run.puffs.size() > PuffField.max_puffs(3)
		for a in run.puffs:
			colors_ok = colors_ok and a.color_index >= 0 and a.color_index < PuffField.COLOR_COUNT
			for b in run.puffs:
				if a != b and a.lane == b.lane and absf(a.x - b.x) < a.radius + b.radius:
					overlaps = true
	_check(not overlaps, "in 2 minutes two Puffs of one lane never overlap (REQ-SS-8)")
	_check(not too_many and PuffField.max_puffs(3) == 6, "never more than 3 + the number of players Puffs on the screen (REQ-SS-9)")
	_check(colors_ok, "every Puff has one of the colors")
	var counts := {"puff": 0, "little": 0}
	var rng3 := _rng(21)
	for i in 3000:
		var one := PuffField.new()
		var p := one.spawn(rng3, 99)
		counts[p.kind] += 1
	_check(absf(counts.puff / 3000.0 - 0.70) < 0.04 and absf(counts.little / 3000.0 - 0.30) < 0.04,
			"Puffs and Little Puffs come in the ratio 70 : 30: %s" % str(counts))
	var full := PuffField.new()
	for i in 12:
		full.spawn(rng3, 0)
	_check(full.puffs.size() <= PuffField.max_puffs(0) and full.puffs.size() <= 3, "a full screen (or full lanes) adds no Puff")
	var a1 := PuffField.new()
	var a2 := PuffField.new()
	var s1 := _rng(8)
	var s2 := _rng(8)
	var same := true
	for i in 40:
		a1.tick(0.5, s1, 2)
		a2.tick(0.5, s2, 2)
		same = same and a1.puffs.size() == a2.puffs.size()
		for j in a1.puffs.size():
			same = same and a1.puffs[j].lane == a2.puffs[j].lane and a1.puffs[j].color_index == a2.puffs[j].color_index \
					and is_equal_approx(a1.puffs[j].x, a2.puffs[j].x)
	_check(same, "the same seed gives the same Puffs (REQ-SS-9)")


func _hit_test() -> void:
	print("snowball splat: hit test")
	var f := PuffField.new()
	var a := _puff(2, 900.0)
	f.puffs.append(a)
	var c := PuffField.center_of(a, AREA)
	_check(f.hit(c, AREA) == a, "a snowball in the middle hits")
	_check(f.hit(c + Vector2(100.0, 0.0), AREA) == a, "a snowball at the edge of the radius hits")
	_check(f.hit(c + Vector2(100.0 + PuffField.HIT_SLOP, 0.0), AREA) == a, "a snowball inside the 12 px slop hits (REQ-SS-10)")
	_check(f.hit(c + Vector2(100.0 + PuffField.HIT_SLOP + 1.0, 0.0), AREA) == null, "a snowball just outside the slop misses")
	var b := _puff(0, 940.0)   # A Little Puff that is moved down, so that it touches the first Puff in this test.
	b.lane_y = a.lane_y + 60.0
	f.puffs.append(b)
	var between := PuffField.center_of(b, AREA) + Vector2(-20.0, 0.0)
	_check(f.hit(between, AREA) == b, "inside two Puffs, the nearer center is hit")
	f.take(b)
	_check(f.hit(between, AREA) == a and f.puffs.size() == 1, "a taken Puff is gone")
	f.tick(2.0, _rng(4), 0)   # The Puff moves 200 px to the left.
	_check(f.hit(c, AREA) == null and f.hit(PuffField.center_of(a, AREA), AREA) == a,
			"the hit follows the Puff where it is when the snowball lands")
	var small := Rect2(60.0, 150.0, 1160.0, 510.0)
	var k := PuffField.scale_for(small)
	var sc := PuffField.center_of(a, small)
	_check(f.hit(sc + Vector2(100.0 * k, 0.0), small) == a and f.hit(sc + Vector2(120.0, 0.0), small) == null,
			"the radius scales with the screen")


func _visual_rules() -> void:
	print("snowball splat: visual rules")
	var consts: Dictionary = load("res://scripts/game/snowball_splat/snowball_splat_game.gd").get_script_constant_map()
	var board: Color = consts["BOARD_COLOR"]
	var bg: Color = consts["BACKGROUND"]
	var slots_ok := true
	for c in Protocol.PLAYER_COLORS:
		if Shell.contrast(c, board) < 3.0:
			slots_ok = false
			print("    slot color too close to the board: ", c)
	_check(slots_ok, "every player color has a contrast of 3:1 on the board (REQ-GM-47e)")
	var puff_colors: Array = consts["PUFF_COLORS"] + [consts["LITTLE_COLOR"]]
	var colors_ok := puff_colors.size() == PuffField.COLOR_COUNT + 1
	for c in puff_colors:
		if Shell.contrast(c, board) < 3.0 or c.s < 0.55 or c.v < 0.60:
			colors_ok = false
			print("    Puff color not bright enough or not saturated: ", c)
	_check(colors_ok, "Puff colors have a contrast of 3:1 on the board, saturation 0.55+ and value 0.60+ (REQ-GM-47d, 47e)")
	_check(board.s >= 0.35 and board.v >= 0.25 and board.v <= 0.65 and bg.s >= 0.35 and bg.v >= 0.25 and bg.v <= 0.65,
			"the board and the background are dark and saturated (REQ-GM-47e)")
	var smallest := 1e9
	for kind in PuffField.KINDS:
		smallest = minf(smallest, float(PuffField.KINDS[kind].radius) * 2.0)
	_check(smallest >= 48.0 and float(consts["CURSOR_R"]) * 2.0 >= 48.0,
			"every key object is 48 px high or more at 1080p (REQ-GM-47e)")
	var clash := false
	for c in Protocol.PLAYER_COLORS:
		for t in puff_colors:
			if c.is_equal_approx(t):
				clash = true
	_check(not clash, "no Puff color is a player color")
	_check(float(consts["RELOAD"]) <= 0.5 and float(consts["ROUND_TIME"]) >= 45.0,
			"a quick reload (0.5 s or less) and a round of at least 45 s: a child is not stopped after a miss (REQ-GM-83)")


## The maze difficulty (REQ-MZ-9).
func _maze_levels() -> void:
	print("maze difficulty")
	var rng := _rng(7)
	var Maze = load("res://scripts/game/maze/maze_game.gd")
	var levels: Dictionary = Maze.LEVELS
	var walls := {}
	var solvable := true
	var fits := true
	for d in ["easy", "medium", "hard"]:
		var lv: Dictionary = levels[d]
		var total := 0
		for i in 30:
			var m := MazeGenerator.new()
			m.generate(int(lv.cols), int(lv.rows), rng, float(lv.openings))
			solvable = solvable and m.is_solvable()
			total += m.wall_rects(float(lv.cell), 12.0).size()
		walls[d] = total / 30.0
		fits = fits and int(lv.cols) * float(lv.cell) + Maze.WALL <= 1800.0 and int(lv.rows) * float(lv.cell) + Maze.WALL <= 892.0
	_check(solvable, "mazes of every difficulty are solvable")
	_check(fits, "the board of every difficulty fits the screen under the HUD")
	_check(levels.easy.cols < levels.medium.cols and levels.medium.cols < levels.hard.cols
			and levels.easy.rows < levels.medium.rows and levels.medium.rows < levels.hard.rows,
			"the maze grows with the difficulty")
	_check(levels.easy.openings > levels.medium.openings and levels.medium.openings > levels.hard.openings,
			"fewer openings (more complex) with the difficulty")
	_check(walls.easy < walls.medium and walls.medium < walls.hard, "more walls with the difficulty: %s" % str(walls))
	_check(levels.medium.cols == 16 and levels.medium.rows == 8 and levels.medium.cell == 108.0, "Medium is 16 x 8 cells of 108 px")
	# The styles (REQ-MZ-12): the registry row lists exactly the styles the board draws, and an unknown one gives the default.
	var style_row: Dictionary = {}
	for g in load("res://scripts/game/registry.gd").GAMES:
		if g.id == "maze":
			style_row = g.settings[0]
	var style_keys: Array = MazeBoard.STYLES.keys()
	var row_keys: Array = style_row.get("values", []).duplicate()
	style_keys.sort()
	row_keys.sort()
	_check(style_row.get("key", "") == "style" and style_keys == row_keys and MazeBoard.STYLES.has(MazeBoard.DEFAULT_STYLE),
			"the Style row of the maze lists the styles of the board and the default is one of them")
	_check(MazeBoard.look("nothing") == MazeBoard.STYLES[MazeBoard.DEFAULT_STYLE], "an unknown style gives the default look")
	_check(MazeBoard.scatter(3, 4, 1) == MazeBoard.scatter(3, 4, 1) and MazeBoard.scatter(3, 4, 1) != MazeBoard.scatter(4, 3, 1),
			"the marks of the ground come from the place, so they stay in place")
	_test_maze_board()
	var on_grid := fmod(Maze.WALL, Shell.WORLD_PIXEL) == 0.0
	for d in levels:
		on_grid = on_grid and fmod(float(levels[d].cell), Shell.WORLD_PIXEL) == 0.0
	_check(on_grid and Maze.WALL == 28.0, "the walls and the cells are on the pixel grid (REQ-MZ-7)")
	# A corridor is wide enough for the ball in every difficulty .
	var corridors_ok := true
	for d in levels:
		corridors_ok = corridors_ok and float(levels[d].cell) - Maze.WALL >= Maze.BALL_R * 2.0 + 16.0
	_check(corridors_ok, "a corridor of every difficulty is at least 16 px wider than the ball")
	# The balls start apart and clear of the walls in every difficulty (REQ-MZ-2).
	var starts_ok := true
	var start_node = Maze.new()
	for d in levels:
		start_node.cell = float(levels[d].cell)
		var o: float = start_node._start_offset()
		starts_ok = starts_ok and o * 2.0 * sqrt(2.0) > Maze.BALL_R * 2.0 + 2.0 and (start_node.cell - Maze.WALL) * 0.5 - o >= Maze.BALL_R
	start_node.free()
	_check(starts_ok, "the balls of slot 0 and 1 start apart and clear of the walls in every difficulty")


## The picture of the board (REQ-MZ-7, REQ-MZ-12): a wall pixel, an outline, a front band and the ground are where they should be,
## and the same input gives the same picture.
func _test_maze_board() -> void:
	var wall := [Rect2(100.0, 100.0, 120.0, 28.0)]   # Screen units: 30 x 7 world pixels at (25, 25).
	var typed: Array[Rect2] = []
	typed.append_array(wall)
	var view := Vector2i(80, 60)
	for key in MazeBoard.STYLES:
		var st: Dictionary = MazeBoard.STYLES[key]
		var img: Image = MazeBoard.render(key, typed, Rect2(8.0, 8.0, 40.0, 40.0), view)
		_check(img.get_width() == 80 and img.get_height() == 60, "the %s board picture has the size of the view" % key)
		_check(img.get_pixel(40, 25) == st.light, "the top of a %s wall is the lit edge" % key)
		var outlines := 0
		var fronts := 0
		for x in range(30, 50):   # A hedge has a rough edge, so most of the pixels of a row count.
			outlines += int(img.get_pixel(x, 24) == st.outline)
			fronts += int(img.get_pixel(x, 32) == st.front)
		_check(outlines >= 10, "the %s wall has an outline above it" % key)
		_check(fronts >= 10, "the %s wall has a front band under it" % key)
		var ground := img.get_pixel(70, 50)
		_check(ground == st.ground_a or ground == st.ground_b or ground == st.tuft or ground == st.flower
				or ground == Color("f8b800"), "a pixel far from the walls is ground in the %s style" % key)
	var a: Image = MazeBoard.render("garden", typed, Rect2(8.0, 8.0, 40.0, 40.0), view)
	var b: Image = MazeBoard.render("garden", typed, Rect2(8.0, 8.0, 40.0, 40.0), view)
	_check(a.get_data() == b.get_data(), "the same board is drawn the same way every time")


## Snowball Splat difficulty (REQ-SS-20 to 22): faster Puffs and fewer of them as it grows.
func _difficulty() -> void:
	print("snowball difficulty")
	var lv: Dictionary = PuffField.LEVELS
	_check(lv.easy.speed < lv.medium.speed and lv.medium.speed < lv.hard.speed, "the Puffs are faster with the difficulty")
	_check(lv.easy.max_base > lv.medium.max_base and lv.medium.max_base > lv.hard.max_base,
			"there are fewer Puffs with the difficulty")
	_check(lv.easy.spawn_every < lv.medium.spawn_every and lv.medium.spawn_every < lv.hard.spawn_every,
			"new Puffs come less often with the difficulty")
	_check(lv.medium.speed == 1.0 and lv.medium.max_base == PuffField.MAX_BASE and lv.medium.spawn_every == PuffField.SPAWN_EVERY
			and lv.medium.tiers == [150, 300, 450], "Medium is the game from before")
	_check(Medals.is_valid(lv.easy.tiers) and Medals.is_valid(lv.medium.tiers) and Medals.is_valid(lv.hard.tiers)
			and lv.easy.tiers[2] > lv.medium.tiers[2] and lv.medium.tiers[2] > lv.hard.tiers[2],
			"every difficulty has valid medal tiers (REQ-GM-73), harder levels have lower limits")
	# The speed and the count of a real field.
	for d in ["easy", "medium", "hard"]:
		var f := PuffField.new()
		f.setup(d)
		var most := 0
		var puff_speed := 0.0
		var seen_little := 0.0
		var rng := _rng(5)
		for i in 1200:
			f.tick(0.05, rng, 2)
			most = maxi(most, f.puffs.size())
			for p in f.puffs:
				if p.kind == "puff":
					puff_speed = p.speed
				else:
					seen_little = p.speed
		_check(most <= PuffField.max_puffs(2, lv[d].max_base) and most >= lv[d].max_base,
				"%s: at most %d Puffs on the screen at once (most seen: %d)" % [d, PuffField.max_puffs(2, lv[d].max_base), most])
		_check(is_equal_approx(puff_speed, 100.0 * lv[d].speed) and is_equal_approx(seen_little, 160.0 * lv[d].speed),
				"%s: the speed of both kinds is the factor %.1f" % [d, lv[d].speed])
	_check(PuffField.new().puffs.is_empty(), "a field without setup is a Medium field")
	# On Hard with one player there is a Puff on the screen nearly all the time (REQ-SS-22).
	var hard := PuffField.new()
	hard.setup("hard")
	var rng2 := _rng(11)
	var empty_time := 0.0
	for i in 2400:
		hard.tick(0.025, rng2, 1)
		if i > 80 and hard.puffs.is_empty():
			empty_time += 0.025
	_check(empty_time < 3.0, "Hard with 1 player: the screen is empty for %.1f s of 60 s (less than 3 s)" % empty_time)
	var odd := PuffField.new()
	odd.setup("nonsense")
	_check(odd.spawn(_rng(1), 1) != null and odd.puffs[0].speed in [100.0, 160.0], "an unknown difficulty is Medium")


func _test_marble_track() -> void:
	print("marble track")
	var seeds: Array = MarbleTrack.FIXED_SEEDS.duplicate()
	for i in 150:
		seeds.append(1000 + i * 37)
	var all_clear := true
	var all_long := true
	var all_start := true
	var all_posts := true
	var apart_all := true
	var smooth := true
	var fallback := false
	for sd in seeds:
		var t = MarbleTrack.make(sd, "hard")
		all_long = all_long and t.length >= 90.0 and t.length <= 170.0 and t.half_width >= 2.9 and t.half_width <= 4.6
		fallback = fallback or t.points.size() == 2 and t.half_width == 3.6
		all_start = all_start and t.dir_at(5.0).is_equal_approx(Vector2(0, -1)) and t.point_at(8.0).x == 0.0 \
				and t.points[1].distance_to(t.points[0]) >= 8.0
		# Parts of the track far apart in arc must be far apart in space, or arc is not clear (REQ-MR-23).
		var samples: Array[Vector2] = []
		var a := 0.0
		while a <= t.length:
			samples.append(t.point_at(a))
			a += 1.0
		var gap := ceili(t.half_width * 4.0)
		for i in samples.size():
			for j in range(i + gap, samples.size()):
				if samples[i].distance_to(samples[j]) < t.half_width * 1.8:
					apart_all = false
		# A bend is never sharp (REQ-MR-52).
		for i in range(1, t.points.size() - 1):
			var d1: Vector2 = (t.points[i] - t.points[i - 1]).normalized()
			var d2: Vector2 = (t.points[i + 1] - t.points[i]).normalized()
			if rad_to_deg(d1.angle_to(d2)) > MarbleTrack.TURN_MAX + 0.5 or rad_to_deg(d1.angle_to(d2)) < -MarbleTrack.TURN_MAX - 0.5:
				smooth = false
		for b in t.bumpers:
			var off: float = absf(b[1]) * t.half_width * 0.44
			if b[0] > t.length - 8.0 or b[0] < 14.0 or t.half_width + off - 0.9 < 2.0:
				all_posts = false
		all_clear = all_clear and t.query(t.point_at(t.length * 0.5)).dist < 0.01
	_check(not fallback, "no seed falls back to the plain track (%d seeds)" % seeds.size())
	_check(all_long, "every track is 90 to 170 m long and 5.8 to 9.2 m wide (REQ-MR-52)")
	_check(all_start, "every track starts with a straight of 8 m or more toward -z (REQ-MR-22)")
	_check(apart_all, "no track touches itself (REQ-MR-23)")
	_check(smooth, "no bend is sharper than %d degrees (REQ-MR-52)" % int(MarbleTrack.TURN_MAX))
	_check(all_posts, "posts leave a marble-wide gap and stay between 14 m and 8 m before the end (REQ-MR-6, 24)")
	_check(all_clear, "point_at and query agree")
	# The same seed gives the same track, other seeds other tracks (REQ-MR-51).
	var a1 = MarbleTrack.make(42, "medium")
	var a2 = MarbleTrack.make(42, "medium")
	var b1 = MarbleTrack.make(43, "medium")
	_check(a1.points == a2.points and a1.bumpers == a2.bumpers and a1.half_width == a2.half_width,
			"the same seed gives the same track")
	_check(a1.points != b1.points, "another seed gives another track")
	# Difficulty changes the posts only (REQ-MR-50).
	var counts := {}
	for d in ["easy", "medium", "hard"]:
		var td = MarbleTrack.make(42, d)
		counts[d] = td.bumpers.size()
		_check(td.points == a1.points, "%s: the line of the track is the same at every difficulty" % d)
		var per100: float = float(td.bumpers.size()) / ((td.length - 22.0) / 100.0)
		_check(absf(per100 - MarbleTrack.POSTS_PER_100M[d]) < 0.8 * 100.0 / (td.length - 22.0) + 0.01,
				"%s: about %d posts for each 100 m (%.1f)" % [d, int(MarbleTrack.POSTS_PER_100M[d]), per100])
	_check(counts.easy < counts.medium and counts.medium < counts.hard, "more posts with the difficulty: %s" % str(counts))
	var neighbours_differ := true
	for i in range(1, a1.bumpers.size()):
		neighbours_differ = neighbours_differ and a1.bumpers[i][1] != a1.bumpers[i - 1][1]
	_check(neighbours_differ, "a post is never on the same side as the one before it")
	_check(MarbleTrack.make(42, "nope").bumpers.size() == counts.medium, "an unknown difficulty is Medium")
	# The list: 10 fixed seeds, a random seed is never one of them (REQ-MR-53).
	var distinct := {}
	for sd in MarbleTrack.FIXED_SEEDS:
		distinct[sd] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var random_ok := true
	for i in 300:
		random_ok = random_ok and not MarbleTrack.FIXED_SEEDS.has(MarbleTrack.seed_for("random", rng))
	_check(MarbleTrack.FIXED_SEEDS.size() == 10 and distinct.size() == 10, "there are 10 different fixed seeds")
	_check(random_ok, "the random track never has a fixed seed")
	_check(MarbleTrack.seed_for("3", rng) == MarbleTrack.FIXED_SEEDS[2]
			and MarbleTrack.seed_for("10", rng) == MarbleTrack.FIXED_SEEDS[9],
			"a choice of 1 to 10 gives the fixed seed")
	_check(MarbleTrack.title_for(MarbleTrack.FIXED_SEEDS[4]) == "Track 5" and MarbleTrack.title_for(5) == "Random track",
			"the names are Track 1 to 10 and Random track")
	var t0 = MarbleTrack.make(MarbleTrack.FIXED_SEEDS[0])
	var side: Vector2 = t0.point_at(30.0) + Vector2(t0.half_width + 1.0, 0)
	_check(t0.query(side).dist > t0.half_width * 0.5, "a point beside the track is not on the line")


## TiltBody (REQ-PG-7, 8, 30).
func _tilt_body() -> void:
	print("tilt body")
	var field := Rect2(0, 0, 1000, 600)
	var b := TiltBody.new()
	b.pos = Vector2(500, 300)
	b.step(0.1, Vector2(0.01, 0.0), field)
	_check(b.vel == Vector2.ZERO, "a tilt inside the dead zone gives no speed")
	b.step(0.1, Vector2(0.5, 0.0), field)
	_check(b.vel.x > 0.0 and b.vel.y == 0.0 and b.pos.x > 500.0, "a tilt to the right rolls the body to the right")
	var fast := TiltBody.new()
	fast.pos = Vector2(500, 300)
	for i in 200:
		fast.step(0.02, Vector2(1.0, 1.0), field)
		fast.pos = Vector2(500, 300)   # Keep it inside, so that only the speed limit is tested.
	_check(fast.vel.length() <= fast.max_speed + 0.01 and fast.vel.length() > fast.max_speed * 0.9,
			"a long tilt reaches the speed limit and does not pass it")
	var slow := TiltBody.new()
	slow.pos = Vector2(500, 300)
	slow.vel = Vector2(400, 0)
	slow.step(1.0, Vector2.ZERO, field)
	_check(slow.vel.x < 400.0 * 0.3 and slow.vel.x > 0.0, "the body slows down by itself (damping)")
	# The same result at 30 and 120 steps for each second (REQ-GM-13).
	var a30 := TiltBody.new()
	var a120 := TiltBody.new()
	a30.pos = Vector2(100, 300)
	a120.pos = Vector2(100, 300)
	for i in 30:
		a30.step(1.0 / 30.0, Vector2(0.3, 0.0), field)
	for i in 120:
		a120.step(1.0 / 120.0, Vector2(0.3, 0.0), field)
	_check(absf(a30.vel.x - a120.vel.x) < 25.0 and absf(a30.pos.x - a120.pos.x) < 25.0,
			"the speed hardly depends on the frame rate (%.0f, %.0f)" % [a30.vel.x, a120.vel.x])
	# The edge.
	var e := TiltBody.new()
	e.pos = Vector2(40, 300)
	e.vel = Vector2(-500, 0)
	var hit := e.step(0.05, Vector2.ZERO, field)
	_check(e.pos.x == e.radius and e.vel.x > 0.0 and e.vel.x < 500.0 * e.bounce + 1.0 and hit > 100.0,
			"at the edge the body stays inside, bounces softly and reports the hit")
	var corner := TiltBody.new()
	corner.pos = Vector2(990, 590)
	corner.vel = Vector2(300, 300)
	corner.step(0.1, Vector2.ZERO, field)
	_check(corner.pos.x <= 1000.0 - corner.radius and corner.pos.y <= 600.0 - corner.radius and corner.vel.x < 0.0
			and corner.vel.y < 0.0, "in a corner the whole circle stays on the floor")
	# Two bodies.
	var p := TiltBody.new()
	var q := TiltBody.new()
	p.pos = Vector2(300, 300)
	q.pos = Vector2(350, 300)
	p.vel = Vector2(200, 0)
	_check(TiltBody.collide(p, q), "two overlapping bodies touch")
	_check(p.pos.distance_to(q.pos) >= p.radius + q.radius - 0.01 and q.vel.x > 0.0 and p.vel.x < 200.0,
			"they are pushed apart and the moving body gives speed to the other")
	var far := TiltBody.new()
	far.pos = Vector2(900, 100)
	_check(not TiltBody.collide(p, far), "two bodies that are apart do not touch")
	var same_a := TiltBody.new()
	var same_b := TiltBody.new()
	same_a.pos = Vector2(100, 100)
	same_b.pos = Vector2(100, 100)
	TiltBody.collide(same_a, same_b)
	_check(same_a.pos.distance_to(same_b.pos) >= same_a.radius * 2.0 - 0.01, "two bodies in the same place are pushed apart")


## The floor (REQ-PG-2, 4, 5, 21).
func _paint_floor() -> void:
	print("paint floor")
	var f := PaintFloor.new(4, 3, 100.0)
	_check(f.total() == 12 and f.size() == Vector2(400, 300) and f.count(0) == 0, "an empty floor of 4 x 3 tiles")
	_check(f.cell_at(Vector2(0, 0)) == Vector2i(0, 0) and f.cell_at(Vector2(399, 299)) == Vector2i(3, 2)
			and f.cell_at(Vector2(150, 250)) == Vector2i(1, 2), "a point gives its tile")
	_check(f.cell_at(Vector2(-1, 10)) == Vector2i(-1, -1) and f.cell_at(Vector2(400, 10)) == Vector2i(-1, -1),
			"a point outside the floor gives no tile")
	_check(f.paint(Vector2i(1, 1), 0) == PaintFloor.Result.NEW and f.owner_of(Vector2i(1, 1)) == 0 and f.count(0) == 1,
			"a free tile is painted")
	_check(f.paint(Vector2i(1, 1), 0) == PaintFloor.Result.SAME and f.count(0) == 1,
			"the same player painting again changes nothing")
	_check(f.paint(Vector2i(1, 1), 2) == PaintFloor.Result.TAKEN and f.owner_of(Vector2i(1, 1)) == 2
			and f.count(0) == 0 and f.count(2) == 1, "the tile of another player is taken, and the counts follow (REQ-PG-4)")
	f.paint(Vector2i(0, 0), 0)
	f.paint(Vector2i(2, 0), 0)
	f.paint(Vector2i(3, 0), 0)
	_check(f.percent(0) == 25 and f.percent(2) == 8 and f.percent(3) == 0,
			"the share of the floor in percent, rounded down (REQ-PG-21)")


## The difficulty of Paint Grab (REQ-PG-20, 21).
func _paint_levels() -> void:
	print("paint grab difficulty")
	var lv: Dictionary = load("res://scripts/game/paint_grab/paint_grab_game.gd").LEVELS
	_check(lv.easy.cols < lv.medium.cols and lv.medium.cols < lv.hard.cols and lv.easy.rows < lv.medium.rows
			and lv.medium.rows < lv.hard.rows, "the floor grows with the difficulty")
	_check(lv.easy.speed < lv.medium.speed and lv.medium.speed < lv.hard.speed and lv.medium.speed == 1.0,
			"the blobs are faster with the difficulty, Medium is the base")
	_check(Medals.is_valid(lv.easy.tiers) and Medals.is_valid(lv.medium.tiers) and Medals.is_valid(lv.hard.tiers)
			and lv.easy.tiers[2] > lv.medium.tiers[2] and lv.medium.tiers[2] > lv.hard.tiers[2],
			"every difficulty has valid medal tiers, harder levels have lower limits")
	_check(lv.hard.tiers[2] <= 100 and lv.easy.tiers[2] <= 100, "no medal needs more than the whole floor")


## The platform and the rules of Sumo Bumpers (REQ-SB-2, 3, 6, 7, 10, 20).
func _sumo_arena() -> void:
	print("sumo arena")
	var lv: Dictionary = SumoArena.LEVELS
	_check(lv.easy.radius > lv.medium.radius and lv.medium.radius > lv.hard.radius
			and lv.easy.shrink > lv.medium.shrink and lv.medium.shrink > lv.hard.shrink
			and lv.easy.dash < lv.medium.dash and lv.medium.dash < lv.hard.dash,
			"the platform is smaller, shrinks faster and the dash comes back later with the difficulty")
	var a := SumoArena.new()
	a.setup("medium")
	_check(a.radius() == 380.0 and a.danger() == 0.0 and a.speedup == 1.0,
			"a round starts with the full platform at the normal rate")
	a.tick(12.0)
	_check(is_equal_approx(a.radius(), (380.0 + SumoArena.MIN_RADIUS) * 0.5) and is_equal_approx(a.danger(), 0.5),
			"the radius falls in a straight line: half way after half the time")
	a.tick(100.0)
	_check(a.radius() == SumoArena.MIN_RADIUS and a.danger() == 1.0, "the platform stops at the least radius (REQ-SB-6)")
	_check(SumoArena.MIN_RADIUS * 2.0 < SumoArena.BUMPER_R * 2.0,
			"at the least radius two bumpers do not fit, so every round ends")
	_check(a.is_off(Vector2(SumoArena.MIN_RADIUS + 1.0, 0.0)) and not a.is_off(Vector2(0.0, SumoArena.MIN_RADIUS - 1.0)),
			"a bumper has fallen when its middle is outside the platform (REQ-SB-7)")
	# The wait of a bumper that fell is short (REQ-GM-83, REQ-SB-9): the platform shrinks faster after the first fall.
	var wait_ok := true
	for d in ["easy", "medium", "hard"]:
		var w := SumoArena.new()
		w.setup(d)
		w.speed_up()   # The worst case: the first fall is at the very start.
		var seconds := 0.0
		while w.radius() > SumoArena.MIN_RADIUS and seconds < 100.0:
			w.tick(0.1)
			seconds += 0.1
		wait_ok = wait_ok and seconds <= SumoArena.MAX_WAIT and absf(seconds - w.longest_wait()) < 0.2
		wait_ok = wait_ok and w.longest_wait() <= SumoArena.MAX_WAIT
	_check(wait_ok, "after the first fall every round is over in 20 s or less, at every difficulty (REQ-GM-83)")
	var fast := SumoArena.new()
	fast.setup("easy")
	fast.tick(1.0)
	fast.speed_up()
	fast.speed_up()
	fast.tick(1.0)
	_check(is_equal_approx(fast.time, 1.0 + SumoArena.FALL_SPEEDUP),
			"the time of the shrinking runs faster after the first fall, once")
	fast.setup("easy")
	_check(fast.speedup == 1.0 and fast.time == 0.0, "a new round starts at the normal rate again")
	a.setup("nonsense")
	_check(a.radius() == 380.0, "an unknown difficulty is Medium")
	var spread_ok := true
	var inside_ok := true
	for d in ["easy", "medium", "hard"]:
		a.setup(d)
		for n in [2, 3, 4]:
			var spots := a.start_spots(n)
			for i in n:
				spread_ok = spread_ok and is_equal_approx(spots[i].length(), spots[0].length())
				if n > 2:   # Evenly spread: the angle between two neighbours is the same.
					spread_ok = spread_ok and is_equal_approx(absf(spots[i].angle_to(spots[(i + 1) % n])), TAU / n)
				inside_ok = inside_ok and spots[i].length() + SumoArena.BUMPER_R < a.radius()
			if n > 1:
				inside_ok = inside_ok and spots[0].distance_to(spots[1]) > SumoArena.BUMPER_R * 2.0
	_check(spread_ok and inside_ok,
			"2 to 4 bumpers start on a circle, at the same distance, apart and inside the platform (REQ-SB-2)")
	_check(a.start_spots(4)[0].is_equal_approx(Vector2(0.0, -a.start_radius * SumoArena.START_SHARE)),
			"the first bumper starts at the top")
	_check(SumoArena.dash_velocity(Vector2(0.0, 0.5), Vector2(100, 0)).is_equal_approx(Vector2(0.0, SumoArena.DASH_SPEED)),
			"a dash goes the way of the tilt, at the dash speed (REQ-SB-10)")
	_check(SumoArena.dash_velocity(Vector2(0.01, 0.0), Vector2(0, -50)).is_equal_approx(Vector2(0.0, -SumoArena.DASH_SPEED)),
			"a tilt in the dead zone does not steer: the dash goes the way the bumper moves")
	_check(SumoArena.dash_velocity(Vector2.ZERO, Vector2.ZERO) == Vector2.ZERO, "no tilt and no movement: no dash")
	_check(SumoArena.round_winners([2], [0, 1]) == [2] and SumoArena.round_winners([], [0, 3]) == [0, 3]
			and SumoArena.round_winners([1, 2], []) == [], "the last bumper wins; when none is left all that fell last win (REQ-SB-3)")
