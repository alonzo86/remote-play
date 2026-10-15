extends "res://scripts/game/minigame.gd"
## Tilt maze. Each phone tilts its own ball. The first ball in the exit wins.
## Tilt comes from PlayerInput.tilt(). The RECENTER button of the phone recenters (REQ-GM-37); GO recenters all.
## Look (REQ-GM-47i to 47n, REQ-MZ-7, REQ-MZ-12): a pixel world in one of three styles (garden, castle, ice) that the player picks in the
## settings view. The balls with eyes and the treasure chest of the exit look the same in every style.

const MazeGenerator = preload("res://scripts/game/maze/maze_generator.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

## Difficulty (REQ-MZ-9): the size of the maze, the cell size (so that it fits the screen) and the share of inner walls that is
## removed after the maze is made (fewer openings: fewer loops, more dead ends). Medium is the maze from before.
const LEVELS := {
	"easy": {"cols": 11, "rows": 6, "cell": 120.0, "openings": 0.20},
	"medium": {"cols": 17, "rows": 9, "cell": 96.0, "openings": 0.08},
	"hard": {"cols": 21, "rows": 11, "cell": 76.0, "openings": 0.02},
}
const WALL := 12.0           # Three world pixels (REQ-GM-47l). Cells are multiples of 4, so every wall is on the pixel grid.
const BALL_R := 24.0
const TILT_ACCEL := 2600.0   # px/s^2 for tilt 1.0 (sin of angle). 15 degrees gives about 670.
const DEADZONE := 0.03
const FRICTION := 1.6        # 1/s
const MAX_SPEED := 760.0
const RESTITUTION := 0.25
const SUBSTEPS := 2
const HIT_BUZZ_MS := 120    # Minimum gap between two wall buzzes of one ball.
const HIT_BUZZ_SPEED := 320.0
const TIMER_X := 500.0       # The timer box has a fixed place, between the title and the leader chip.
const TIMER_W := 240.0
const STAR_COUNT := 48

# The styles (REQ-MZ-12). `floor_a` and `floor_b` are the two tones of the checkered floor: they are dark so that every player color
# has a contrast of 3:1 or more on them (REQ-GM-47e). `wall` is the face of a wall, `light` its lit top and left edge, `shade` its
# bottom and right edge. `detail` is the mark on the walls and the floor, `deco` the four objects beside the board.
const STYLES := {
	"garden": {"floor_a": Color("0a3010"), "floor_b": Color("08280e"), "start": Color("0a3010"), "start_edge": Color("2a8a30"),
			"wall": Color("58b830"), "light": Color("a0e060"), "shade": Color("2c7a20"), "detail": "leaf", "deco": "tree",
			"mark": Color("14501c"), "flower": Color("fcfcfc")},
	"castle": {"floor_a": Color("2a1070"), "floor_b": Color("230e60"), "start": Color("2e1478"), "start_edge": Color("5a3cc0"),
			"wall": Color("b8a890"), "light": Color("e0d4b8"), "shade": Color("6c5a48"), "detail": "mortar", "deco": "torch",
			"mark": Color("2a1070"), "flower": Color("2a1070")},
	"ice": {"floor_a": Color("0e2458"), "floor_b": Color("0a1c4a"), "start": Color("0e2458"), "start_edge": Color("3a68c0"),
			"wall": Color("a8d8f0"), "light": Color("e8f8ff"), "shade": Color("5a90c0"), "detail": "frost", "deco": "crystal",
			"mark": Color("1c3c7c"), "flower": Color("fcfcfc")},
}
const DEFAULT_STYLE := "garden"
const BOARD_PAD := 12.0
const BRICK := 32.0           # The distance between two marks on a wall (a multiple of the world pixel).
const CHEST_WOOD := Color("a0521c")
const CHEST_DARK := Color("6c3410")
const CHEST_GOLD := Color("f8b800")
const TORCH_POST := Color("7c4a1c")
const FLAME_OUTER := Color("f83800")
const FLAME_INNER := Color("f8b800")

class Ball:
	var slot := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO

## Set before the game starts (REQ-GM-93). `start_props` keeps it for Restart.
var difficulty := "medium"
var style := DEFAULT_STYLE   # A key of `STYLES` (REQ-MZ-12). An unknown one gives the default.
var cols := 17
var rows := 9
var cell := 96.0

var _maze := MazeGenerator.new()
var _walls: Array[Rect2] = []
var _balls: Array[Ball] = []
var _round := RoundClock.new()
var _haptics := Haptics.new()
var _winner := -1
var _stars := PackedVector2Array()
var _ring_time := 0.0   # Game time for the exit ring: it stands still while the game is paused (REQ-FL-43).


func _game_ready() -> void:
	_stars = Shell.star_field(STAR_COUNT, 11)
	var level: Dictionary = LEVELS.get(difficulty, LEVELS.medium)
	cols = int(level.cols)
	rows = int(level.rows)
	cell = float(level.cell)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_maze.generate(cols, rows, rng, float(level.openings))
	_walls = _maze.wall_rects(cell, WALL)
	# Slot 1 starts on the diagonal from slot 0, so that two balls never touch at the start.
	var offsets := [Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1)]
	for s in participants:
		var b := Ball.new()
		b.slot = s
		b.pos = Vector2(cell, cell) * 0.5 + offsets[s % 4] * cell * 0.22
		_balls.append(b)


func _on_player_left(slot: int) -> void:
	for i in _balls.size():
		if _balls[i].slot == slot:
			_balls.remove_at(i)
			return


func _game_tick(delta: float) -> void:
	_ring_time += delta
	if is_over:
		return
	if _round.is_counting():
		if _round.tick(delta):
			for b in _balls:
				player(b.slot).recenter() # Use the pose held during the countdown.
		return
	_round.tick(delta)
	for b in _balls:
		_step_ball(b, delta)
		if b.pos.distance_to(_exit_center()) < cell * 0.3:
			_finish(b.slot)
			return


func _finish(slot: int) -> void:
	_winner = slot
	App.server.haptic(slot, 400)
	Sound.sfx("maze_exit")
	# Times: the winner has one. The balls still in the maze are ranked by their distance to the exit.
	var board := Scoreboard.new([], true)
	board.set_score(slot, _round.time)
	for b in _balls:
		if b.slot != slot:
			board.set_unfinished(b.slot, -b.pos.distance_to(_exit_center()))
	open_results(board, [], "", [], func(t: float) -> String: return Lang.f("%.1f s", [t]))


func _exit_center() -> Vector2:
	return Vector2((cols - 0.5) * cell, (rows - 0.5) * cell)


func _step_ball(b: Ball, dt: float) -> void:
	var p := player(b.slot)
	var t := p.tilt()
	if t.length() < DEADZONE:
		t = Vector2.ZERO
	b.vel += t * TILT_ACCEL * dt
	b.vel *= maxf(0.0, 1.0 - FRICTION * dt)
	if b.vel.length() > MAX_SPEED:
		b.vel = b.vel.normalized() * MAX_SPEED
	for i in SUBSTEPS:
		b.pos += b.vel * dt / SUBSTEPS
		_collide(b)


func _collide(b: Ball) -> void:
	for r in _walls:
		if b.pos.x + BALL_R < r.position.x or b.pos.x - BALL_R > r.end.x \
				or b.pos.y + BALL_R < r.position.y or b.pos.y - BALL_R > r.end.y:
			continue
		var closest := Vector2(clampf(b.pos.x, r.position.x, r.end.x), clampf(b.pos.y, r.position.y, r.end.y))
		var delta := b.pos - closest
		var d := delta.length()
		if d >= BALL_R:
			continue
		var n: Vector2
		var push: float
		if d > 0.0001:
			n = delta / d
			push = BALL_R - d
		else:
			# The center is inside the wall. Leave by the shortest way.
			var to_left := b.pos.x - r.position.x
			var to_right := r.end.x - b.pos.x
			var to_top := b.pos.y - r.position.y
			var to_bottom := r.end.y - b.pos.y
			var m := minf(minf(to_left, to_right), minf(to_top, to_bottom))
			if m == to_left:
				n = Vector2.LEFT
			elif m == to_right:
				n = Vector2.RIGHT
			elif m == to_top:
				n = Vector2.UP
			else:
				n = Vector2.DOWN
			push = m + BALL_R
		b.pos += n * push
		var vn := b.vel.dot(n)
		if vn < 0.0:
			if -vn > HIT_BUZZ_SPEED:
				if _haptics.pulse(b.slot, 20, HIT_BUZZ_MS):
					Sound.sfx("maze_bump")
			b.vel -= (1.0 + RESTITUTION) * vn * n


## The colors of the style of this round.
func _look() -> Dictionary:
	return STYLES.get(style, STYLES[DEFAULT_STYLE])


## A number from the place (`a`, `b`) and a `salt`, the same every time: it places the marks of a style in the same spots.
static func scatter(a: int, b: int, salt: int) -> int:
	return ((a * 73856093) ^ (b * 19349663) ^ (salt * 83492791)) & 0xffff


## All walls on the pixel grid (REQ-MZ-7, REQ-MZ-12): the shade of every bar first, then the face, then the lit top and left edge,
## then a mark every `BRICK` px (mortar, a leaf or frost). The collision uses the same rectangles. One pass for each color, so that
## two bars that meet look like one piece of wall.
func _draw_walls(ci: CanvasItem, o: Vector2) -> void:
	var px := Shell.WORLD_PIXEL
	var look := _look()
	var rects: Array[Rect2] = []
	for r in _walls:
		rects.append(Rect2(Shell.snap(o + r.position), r.size))
	for r in rects:
		ci.draw_rect(r, look.shade)
	for r in rects:
		ci.draw_rect(Rect2(r.position, r.size - Vector2(px, px)), look.wall)
	for r in rects:
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, px)), look.light)
		ci.draw_rect(Rect2(r.position, Vector2(px, r.size.y)), look.light)
	for r in rects:
		_draw_wall_marks(ci, r, look)


## The marks of a bar in its middle band, at fixed places of the screen. Mortar is a dark square, a leaf a light one on the odd marks
## and a dark one on the even marks, frost a white square on every other mark.
func _draw_wall_marks(ci: CanvasItem, r: Rect2, look: Dictionary) -> void:
	var px := Shell.WORLD_PIXEL
	var horizontal := r.size.x >= r.size.y
	var from := (r.position.x if horizontal else r.position.y) + px
	var to := (r.end.x if horizontal else r.end.y) - px * 2.0
	var t := ceilf(from / BRICK) * BRICK
	while t < to:
		var n := int(t / BRICK)
		var color: Color = look.shade
		var skip := false
		match String(look.detail):
			"leaf":
				color = look.light if n % 2 == 0 else look.shade
			"frost":
				color = Color.WHITE
				skip = n % 2 == 1
		if not skip:
			var at := Vector2(t, r.position.y + px) if horizontal else Vector2(r.position.x + px, t)
			ci.draw_rect(Rect2(at, Vector2(px, px)), color)
		t += BRICK


## The floor: cells in two tones like a chess board, the start cell with a lighter edge, and small marks on the cells (grass and
## daisies, snow flecks) at places that come from the cell, so that they do not change.
func _draw_floor(ci: CanvasItem, o: Vector2) -> void:
	var px := Shell.WORLD_PIXEL
	var look := _look()
	var steps := int(cell / px)
	for cy in rows:
		for cx in cols:
			var at := o + Vector2(cx, cy) * cell
			if (cx + cy) % 2 == 1:
				ci.draw_rect(Rect2(at, Vector2(cell, cell)), look.floor_b)
			match String(look.detail):
				"leaf":
					var h := scatter(cx, cy, 1)
					ci.draw_rect(Rect2(at + Vector2(h % steps, (h >> 4) % steps) * px, Vector2(px * 2.0, px)), look.mark)
					if h % 5 == 0:
						var d := at + Vector2((h >> 2) % steps, (h >> 6) % steps) * px
						ci.draw_rect(Rect2(d - Vector2(px, 0), Vector2(px * 3.0, px)), look.flower)
						ci.draw_rect(Rect2(d - Vector2(0, px), Vector2(px, px * 3.0)), look.flower)
						ci.draw_rect(Rect2(d, Vector2(px, px)), CHEST_GOLD)
				"frost":
					var h := scatter(cx, cy, 2)
					ci.draw_rect(Rect2(at + Vector2(h % steps, (h >> 4) % steps) * px, Vector2(px, px)), look.mark)
					if h % 4 == 0:
						ci.draw_rect(Rect2(at + Vector2((h >> 3) % steps, (h >> 7) % steps) * px, Vector2(px, px)), look.flower)
	var start := Rect2(o + Vector2(WALL, WALL) * 0.5, Vector2(cell, cell) - Vector2(WALL, WALL))
	ci.draw_rect(start, look.start_edge)
	ci.draw_rect(start.grow(-px), look.start)


## Two small square eyes on a ball (the ball is too small for `Shell.pixel_eyes`): a white square of 8 px with a pupil of 4 px that
## steps to the side the ball rolls.
func _draw_eyes(ci: CanvasItem, c: Vector2, look: Vector2) -> void:
	var step := (look * 2.0).limit_length(1.0).round() * Shell.WORLD_PIXEL * 0.5
	for sx in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(sx * 8.0 - 4.0, -8.0)
		ci.draw_rect(Rect2(e, Vector2(8, 8)), Color.WHITE)
		ci.draw_rect(Rect2(e + Vector2(2, 2) + step, Vector2(4, 4)), UiTheme.OUTLINE)


## One of the four objects beside the board: a torch (castle), a tree (garden) or an ice crystal (ice).
func _draw_deco(ci: CanvasItem, base: Vector2) -> void:
	var look := _look()
	var blink := UiTheme.blink_on(_ring_time)
	match String(look.deco):
		"tree":
			ci.draw_rect(Rect2(base + Vector2(-12, 20), Vector2(24, 52)), UiTheme.OUTLINE)
			ci.draw_rect(Rect2(base + Vector2(-8, 20), Vector2(16, 48)), TORCH_POST)
			ci.draw_rect(Rect2(base + Vector2(-40, -48), Vector2(80, 80)), UiTheme.OUTLINE)
			ci.draw_rect(Rect2(base + Vector2(-36, -44), Vector2(72, 72)), look.wall)
			ci.draw_rect(Rect2(base + Vector2(-36, -44), Vector2(72, 12)), look.light)
			ci.draw_rect(Rect2(base + Vector2(-36, 16), Vector2(72, 12)), look.shade)
			var spot := Vector2(-12, -8) if blink else Vector2(12, -8)
			ci.draw_rect(Rect2(base + spot, Vector2(8, 8)), Color("f83800"))
		"crystal":
			var rows_w := [16.0, 40.0, 64.0, 40.0, 16.0]
			var y := -40.0
			for i in rows_w.size():
				var w: float = rows_w[i]
				ci.draw_rect(Rect2(base + Vector2(-w * 0.5 - 4.0, y - 4.0), Vector2(w + 8.0, 28.0)), UiTheme.OUTLINE)
				y += 20.0
			y = -40.0
			for i in rows_w.size():
				var w: float = rows_w[i]
				ci.draw_rect(Rect2(base + Vector2(-w * 0.5, y), Vector2(w, 20.0)), look.wall)
				y += 20.0
			ci.draw_rect(Rect2(base + Vector2(-8, -32), Vector2(16, 12)), look.light)
			ci.draw_rect(Rect2(base + Vector2(-4 if blink else 4, -8), Vector2(8, 8)), Color.WHITE)
		_:
			_draw_torch(ci, base, blink)


## A torch on a post. The flame has two shapes that change in a hard step every 0.55 s of game time.
func _draw_torch(ci: CanvasItem, base: Vector2, tall: bool) -> void:
	ci.draw_rect(Rect2(base + Vector2(-16, -4), Vector2(32, 76)), UiTheme.OUTLINE)
	ci.draw_rect(Rect2(base + Vector2(-12, 0), Vector2(24, 68)), TORCH_POST)
	var h := 48.0 if tall else 36.0
	ci.draw_rect(Rect2(base + Vector2(-24, -h - 4.0), Vector2(48, h + 8.0)), UiTheme.OUTLINE)
	ci.draw_rect(Rect2(base + Vector2(-20, -h), Vector2(40, h + 4.0)), FLAME_OUTER)
	ci.draw_rect(Rect2(base + Vector2(-8, -h * 0.6), Vector2(16, h * 0.6 + 4.0)), FLAME_INNER)


## The treasure chest of the exit (REQ-MZ-7): a closed chest with a lock and two sparkles that blink; the lid is open and the gold
## shows once a ball has reached it.
func _draw_chest(ci: CanvasItem, c: Vector2) -> void:
	var px := Shell.WORLD_PIXEL
	var w := Shell.snap(Vector2.ONE * cell * 0.7).x
	var body := Rect2(Shell.snap(c) - Vector2(w * 0.5, 0.0) + Vector2(0, px), Vector2(w, w * 0.4))
	var lid_h := Shell.snap(Vector2.ONE * w * 0.3).x
	ci.draw_rect(body.grow(px), UiTheme.OUTLINE)
	ci.draw_rect(body, CHEST_WOOD)
	ci.draw_rect(Rect2(body.position + Vector2(px, 0), Vector2(px, body.size.y)), CHEST_DARK)
	ci.draw_rect(Rect2(body.end - Vector2(px * 2.0, body.size.y), Vector2(px, body.size.y)), CHEST_DARK)
	if _winner >= 0:
		var top := Rect2(body.position + Vector2(px, -px * 2.0), Vector2(body.size.x - px * 2.0, px * 3.0))
		ci.draw_rect(top.grow(px), UiTheme.OUTLINE)
		ci.draw_rect(top, CHEST_GOLD)
		var lid := Rect2(body.position + Vector2(0, -lid_h - px * 3.0), Vector2(w, lid_h * 0.6))
		ci.draw_rect(lid.grow(px), UiTheme.OUTLINE)
		ci.draw_rect(lid, CHEST_WOOD)
	else:
		var lid := Rect2(body.position + Vector2(0, -lid_h), Vector2(w, lid_h))
		ci.draw_rect(lid.grow(px), UiTheme.OUTLINE)
		ci.draw_rect(lid, CHEST_WOOD)
		ci.draw_rect(Rect2(lid.position + Vector2(px, px), Vector2(w - px * 2.0, px)), CHEST_GOLD)
		var lock := Rect2(Vector2(Shell.snap(c).x - px * 1.5, body.position.y - px * 2.0), Vector2(px * 3.0, px * 4.0))
		ci.draw_rect(lock.grow(px), UiTheme.OUTLINE)
		ci.draw_rect(lock, CHEST_GOLD)
	# Two sparkles, one pixel plus shapes, that take turns (REQ-FL-42, a hard step).
	var spots := [Vector2(-w * 0.6, -lid_h - px), Vector2(w * 0.38, -lid_h - px * 4.0)]
	var which := 0 if UiTheme.blink_on(_ring_time) else 1
	var sp := Shell.snap(c + spots[which])
	ci.draw_rect(Rect2(sp - Vector2(px * 1.5, px * 0.5), Vector2(px * 3.0, px)), Color.WHITE)
	ci.draw_rect(Rect2(sp - Vector2(px * 0.5, px * 1.5), Vector2(px, px * 3.0)), Color.WHITE)


func _origin() -> Vector2:
	return Vector2((size.x - cols * cell) * 0.5, (size.y - rows * cell) * 0.5 + 46.0)


func _pixel_world() -> bool:
	return true


## The world (REQ-GM-47i): the sky, the board with its floor, the four objects beside it, the chest, the walls and the balls.
func _world_draw(ci: CanvasItem) -> void:
	var o := Shell.snap(_origin())
	ci.draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	Shell.draw_stars(ci, _stars)
	var board := Rect2(o, Vector2(cols * cell, rows * cell)).grow(BOARD_PAD)
	ci.draw_rect(board.grow(Shell.WORLD_PIXEL), UiTheme.OUTLINE)
	ci.draw_rect(board, _look().floor_a)
	_draw_floor(ci, o)
	for x in [board.position.x - 44.0, board.end.x + 44.0]:
		for y in [board.position.y + board.size.y * 0.22, board.position.y + board.size.y * 0.72]:
			_draw_deco(ci, Shell.snap(Vector2(x, y)))
	_draw_chest(ci, o + _exit_center())
	_draw_walls(ci, o)
	for b in _balls:   # The slot numbers are drawn by the HUD (REQ-GM-47n).
		Shell.pixel_ball(ci, o + b.pos, BALL_R, player(b.slot).color)
		_draw_eyes(ci, Shell.snap(o + b.pos), b.vel / MAX_SPEED)


func _game_draw() -> void:
	var o := Shell.snap(_origin())
	Shell.title(self, "TREASURE MAZE")
	if _round.is_playing() and not is_over:
		Shell.timer(self, Vector2(TIMER_X, 36.0), _round.time)
	if _round.is_counting() and not participants.is_empty():
		var n := _round.count_number()
		Shell.countdown(self, size, str(n) if n > 0 else "GO", _round.count_elapsed())
		var spots := {}
		for b in _balls:
			spots[b.slot] = Shell.snap(o + b.pos)
		draw_name_tags(self, spots, BALL_R)
		Shell.hint(self, size, "Hold the phone level. It recenters at GO.")
	if participants.is_empty():
		Shell.hint(self, size, "Join with the controller app, then start again.")
