extends "res://scripts/game/minigame.gd"
## Tilt maze. Each phone tilts its own ball. The first ball in the exit wins.
## Tilt comes from PlayerInput.tilt(). The RECENTER button of the phone recenters (REQ-GM-37); GO recenters all.
## Look (REQ-GM-47i to 47n, REQ-MZ-7, REQ-MZ-12): a pixel world in one of three themes (garden, castle, ice) that the player picks in the
## settings view. The balls with eyes and the treasure chest of the exit look the same in every theme.

const MazeGenerator = preload("res://scripts/game/maze/maze_generator.gd")
const MazeBoard = preload("res://scripts/game/maze/maze_board.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

## Difficulty (REQ-MZ-9): the size of the maze, the cell size (so that it fits the screen) and the share of inner walls that is
## removed after the maze is made (fewer openings: fewer loops, more dead ends). Medium is the maze from before.
const LEVELS := {
	"easy": {"cols": 13, "rows": 6, "cell": 132.0, "openings": 0.20},
	"medium": {"cols": 16, "rows": 8, "cell": 108.0, "openings": 0.08},
	"hard": {"cols": 18, "rows": 9, "cell": 96.0, "openings": 0.02},
}
const WALL := 28.0           # Seven world pixels (REQ-GM-47l). Cells are multiples of 4, so every wall is on the pixel grid.
const BALL_R := 18.0
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

const DEFAULT_THEME := "garden"
const RING_W := 4.0           # The white ring around a ball: one world pixel outside the black outline (REQ-MZ-7).
const CHEST_WOOD := Color("a0521c")
const CHEST_DARK := Color("6c3410")
const CHEST_GOLD := Color("f8b800")

class Ball:
	var slot := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO

## Set before the game starts (REQ-GM-93). `start_props` keeps it for Restart.
var difficulty := "medium"
var maze_theme := DEFAULT_THEME   # A key of `MazeBoard.THEMES` (REQ-MZ-12). An unknown one gives the default.
var cols := 17
var rows := 9
var cell := 96.0

var _maze := MazeGenerator.new()
var _walls: Array[Rect2] = []
var _balls: Array[Ball] = []
var _round := RoundClock.new()
var _haptics := Haptics.new()
var _winner := -1
var _board_tex: ImageTexture   # The picture of the ground and the walls, made once (`MazeBoard`).
var _ring_time := 0.0   # Game time for the exit ring: it stands still while the game is paused (REQ-FL-43).


func _game_ready() -> void:
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
		b.pos = Vector2(cell, cell) * 0.5 + offsets[s % 4] * _start_offset()
		_balls.append(b)


## How far a ball starts from the middle of the start cell, on each axis: 0.22 of a cell, but not so far that the ball touches a wall.
func _start_offset() -> float:
	return minf(cell * 0.22, (cell - WALL) * 0.5 - BALL_R - 2.0)


## The ground and the walls of the theme of this round as one texture (REQ-MZ-12). The walls are the collision rectangles.
func _make_board_texture() -> ImageTexture:
	var o := Shell.snap(_origin())
	var rects: Array[Rect2] = []
	for r in _walls:
		rects.append(Rect2(o + r.position, r.size))
	var start := Rect2(o + Vector2(WALL, WALL) * 0.5, Vector2(cell, cell) - Vector2(WALL, WALL))
	return ImageTexture.create_from_image(MazeBoard.render(maze_theme, rects, start, PIXEL_VIEW))


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


## Two small square eyes on a ball (the ball is too small for `Shell.pixel_eyes`): a white square of 8 px with a pupil of 4 px that
## steps to the side the ball rolls.
func _draw_eyes(ci: CanvasItem, c: Vector2, look: Vector2) -> void:
	var step := (look * 2.0).limit_length(1.0).round() * Shell.WORLD_PIXEL * 0.5
	for sx in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(sx * 8.0 - 4.0, -8.0)
		ci.draw_rect(Rect2(e, Vector2(8, 8)), Color.WHITE)
		ci.draw_rect(Rect2(e + Vector2(2, 2) + step, Vector2(4, 4)), UiTheme.OUTLINE)


## A ball: a white ring, a black outline and the slot color, with two eyes. The ring keeps every player color easy to see
## on a bright ground (REQ-MZ-7).
func _draw_ball(ci: CanvasItem, pos: Vector2, color: Color, vel: Vector2) -> void:
	var c := Shell.snap(pos)
	ci.draw_circle(c, BALL_R + Shell.WORLD_PIXEL + RING_W, Color.WHITE)
	ci.draw_circle(c, BALL_R + Shell.WORLD_PIXEL, UiTheme.OUTLINE)
	ci.draw_circle(c, BALL_R, color)
	_draw_eyes(ci, c, vel / MAX_SPEED)


## The treasure chest of the exit (REQ-MZ-7): a closed chest with a lock and two sparkles that blink; the lid is open and the gold
## shows once a ball has reached it.
func _draw_chest(ci: CanvasItem, c: Vector2) -> void:
	var px := Shell.WORLD_PIXEL
	var w := Shell.snap(Vector2.ONE * cell * 0.5).x
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
	# The middle of the space under the HUD (y 128 to 1020 at 1080p): the outer edge of the walls is 14 px outside the cells.
	return Vector2((size.x - cols * cell) * 0.5, size.y * 0.5 + 34.0 - rows * cell * 0.5)


func _pixel_world() -> bool:
	return true


## The world (REQ-GM-47i): the picture of the board (ground, walls, start cell), the chest and the balls.
func _world_draw(ci: CanvasItem) -> void:
	if _board_tex == null:
		_board_tex = _make_board_texture()   # At the first frame, when the size of the screen is known.
	ci.draw_texture_rect(_board_tex, Rect2(Vector2.ZERO, size), false)
	var o := Shell.snap(_origin())
	_draw_chest(ci, o + _exit_center())
	for b in _balls:   # The slot numbers are drawn by the HUD (REQ-GM-47n).
		_draw_ball(ci, o + b.pos, player(b.slot).color, b.vel)


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
