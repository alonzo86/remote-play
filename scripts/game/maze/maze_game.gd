extends "res://scripts/game/minigame.gd"
## Tilt maze. Each phone tilts its own ball. The first ball in the exit wins.
## Tilt comes from PlayerInput.tilt(). The RECENTER button of the phone recenters (REQ-GM-37); GO recenters all.
## Look (REQ-GM-47i to 47n, REQ-MZ-7): a pixel world with a dark board, light square walls, outlined balls and an outlined exit.

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
const TIMER_X := 400.0       # The timer box has a fixed place, between the title and the chips.
const TIMER_W := 240.0
const STAR_COUNT := 48

# Colors (REQ-MZ-7). The floor is dark so that every player color has a contrast of 3:1 or more (REQ-GM-47e).
const FLOOR_COLOR := Color("2a1070")
const START_COLOR := Color("3a1c97")
const WALL_COLOR := Color("8c78e6")
const BOARD_PAD := 12.0

class Ball:
	var slot := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO

## Set before the game starts (REQ-GM-93). `start_props` keeps it for Restart.
var difficulty := "medium"
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
	# Times: the winner has one. The balls still in the maze are ranked by their distance to the exit.
	var board := Scoreboard.new([], true)
	board.set_score(slot, _round.time)
	for b in _balls:
		if b.slot != slot:
			board.set_unfinished(b.slot, -b.pos.distance_to(_exit_center()))
	open_results(board, [], "", [], func(t: float) -> String: return "%.1f s" % t)


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
				_haptics.pulse(b.slot, 20, HIT_BUZZ_MS)
			b.vel -= (1.0 + RESTITUTION) * vn * n


## A wall: a flat square-ended bar on the pixel grid. The collision uses the same rectangle.
func _draw_wall(ci: CanvasItem, o: Vector2, r: Rect2) -> void:
	ci.draw_rect(Rect2(Shell.snap(o + r.position), r.size), WALL_COLOR)


func _origin() -> Vector2:
	return Vector2((size.x - cols * cell) * 0.5, (size.y - rows * cell) * 0.5 + 46.0)


func _pixel_world() -> bool:
	return true


## The world (REQ-GM-47i): the sky, the board, the start cell, the exit with its square ring, the walls and the balls.
func _world_draw(ci: CanvasItem) -> void:
	var o := Shell.snap(_origin())
	ci.draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	Shell.draw_stars(ci, _stars)
	var board := Rect2(o, Vector2(cols * cell, rows * cell)).grow(BOARD_PAD)
	ci.draw_rect(board.grow(Shell.WORLD_PIXEL), UiTheme.OUTLINE)
	ci.draw_rect(board, FLOOR_COLOR)
	ci.draw_rect(Rect2(o + Vector2(WALL, WALL) * 0.5, Vector2(cell, cell) - Vector2(WALL, WALL)), START_COLOR)
	var exit_cell := Rect2(o + Vector2((cols - 1) * cell, (rows - 1) * cell), Vector2(cell, cell))
	exit_cell = exit_cell.grow(-WALL * 0.5 - Shell.WORLD_PIXEL)
	ci.draw_rect(exit_cell.grow(Shell.WORLD_PIXEL), UiTheme.OUTLINE)
	ci.draw_rect(exit_cell, UiTheme.OK)
	_draw_exit_ring(ci, o + _exit_center())
	for r in _walls:
		_draw_wall(ci, o, r)
	for b in _balls:   # The slot numbers are drawn by the HUD (REQ-GM-47n).
		Shell.pixel_ball(ci, o + b.pos, BALL_R, player(b.slot).color)


## The white square ring of the exit. It grows by one world pixel and shrinks again, in a hard step every 0.55 s (REQ-FL-42).
func _draw_exit_ring(ci: CanvasItem, c: Vector2) -> void:
	var half := Shell.snap(Vector2.ONE * cell * 0.30).x
	if UiTheme.blink_on(_ring_time):
		half += Shell.WORLD_PIXEL
	var edge := Shell.WORLD_PIXEL * 2.0
	var outer := Rect2(Shell.snap(c) - Vector2.ONE * half, Vector2.ONE * half * 2.0)
	ci.draw_rect(outer.grow(Shell.WORLD_PIXEL), UiTheme.OUTLINE)
	ci.draw_rect(outer, Color.WHITE)
	ci.draw_rect(outer.grow(-edge), UiTheme.OK)


func _game_draw() -> void:
	var o := Shell.snap(_origin())
	for b in _balls:
		Shell.ball_number(self, Shell.snap(o + b.pos), BALL_R, player(b.slot).color, b.slot)
	Shell.title(self, "TILT MAZE")
	Shell.player_chips(self, size.x, participants.map(func(s: int) -> Object: return player(s)), {},
			size.x - 60.0 - (TIMER_X + TIMER_W + 20.0))
	if _round.is_playing() and not is_over:
		Shell.timer(self, Vector2(TIMER_X, 36.0), _round.time) # Next to the title: 4 chips use the right side.
	if _round.is_counting() and not participants.is_empty():
		var n := _round.count_number()
		Shell.countdown(self, size, str(n) if n > 0 else "GO", _round.count_elapsed())
		Shell.hint(self, size, "Hold the phone level. It recenters at GO.")
	if participants.is_empty():
		Shell.hint(self, size, "Join with the controller app, then start again.")
