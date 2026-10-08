extends "res://scripts/game/minigame.gd"
## Tilt maze. Each phone tilts its own ball. The first ball in the exit wins.
## Tilt comes from PlayerInput.tilt(). Press A on the phone to recenter fast.
## Look (REQ-GM-47): a dark board, light rounded walls, outlined balls and an outlined exit.

const MazeGenerator = preload("res://scripts/game/maze/maze_generator.gd")

const COLS := 17
const ROWS := 9
const CELL := 96.0
const WALL := 10.0
const BALL_R := 24.0
const TILT_ACCEL := 2600.0   # px/s^2 for tilt 1.0 (sin of angle). 15 degrees gives about 670.
const DEADZONE := 0.03
const FRICTION := 1.6        # 1/s
const MAX_SPEED := 760.0
const RESTITUTION := 0.25
const SUBSTEPS := 2
const COUNTDOWN := 3.0
const TIMER_X := 400.0       # The timer pill has a fixed place, between the title and the chips.

# Colors (REQ-MZ-7). The floor is dark so that every player color has a contrast of 3:1 or more (REQ-GM-47e).
const FLOOR_COLOR := Color("2a1070")
const START_COLOR := Color("3a1c97")
const WALL_COLOR := Color("8c78e6")
const BOARD_PAD := 12.0
const OUTLINE_BIG := 6.0     # Outline of a key object of 40 px or more (REQ-GM-47b).

enum Phase { COUNTDOWN, PLAYING, DONE }

class Ball:
	var slot := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var haptic_cooldown := 0.0

var _maze := MazeGenerator.new()
var _walls: Array[Rect2] = []
var _balls: Array[Ball] = []
var _phase: Phase = Phase.COUNTDOWN
var _clock := COUNTDOWN
var _race_time := 0.0
var _winner := -1
var _sb_board: StyleBoxFlat   # Made once. Drawing must not create objects every frame (REQ-GM-51).
var _sb_start: StyleBoxFlat
var _sb_exit: StyleBoxFlat


func _game_ready() -> void:
	_sb_board = UiTheme.card(FLOOR_COLOR, UiTheme.OUTLINE, UiTheme.OUTLINE_W, 30, true)
	_sb_start = UiTheme.card(START_COLOR, START_COLOR, 0, 22, false)
	_sb_exit = UiTheme.card(UiTheme.OK, UiTheme.OUTLINE, int(OUTLINE_BIG), 24, true)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_maze.generate(COLS, ROWS, rng)
	_walls = _maze.wall_rects(CELL, WALL)
	# Slot 1 starts on the diagonal from slot 0, so that two balls never touch at the start.
	var offsets := [Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1)]
	for s in participants:
		var b := Ball.new()
		b.slot = s
		b.pos = Vector2(CELL, CELL) * 0.5 + offsets[s % 4] * CELL * 0.22
		_balls.append(b)
		player(s).button_pressed.connect(_on_button.bind(s))
	if participants.is_empty():
		open_menu("No players connected", [["Back to menu", App.go_menu]])


func _exit_tree() -> void:
	for s in participants:
		var cb := _on_button.bind(s)
		if player(s).button_pressed.is_connected(cb):
			player(s).button_pressed.disconnect(cb)


func _on_button(bit: int, slot: int) -> void:
	if bit == Protocol.BTN_A:
		player(slot).recenter() # Quick recenter during play.


func _on_participants_changed() -> void:
	var keep: Array[Ball] = []
	for b in _balls:
		if participants.has(b.slot):
			keep.append(b)
	_balls = keep
	if participants.is_empty() and _phase != Phase.DONE:
		_phase = Phase.DONE
		open_menu("No players connected", [["Back to menu", App.go_menu]])


func _can_open_menu() -> bool:
	return _phase != Phase.DONE and not participants.is_empty()


func _game_tick(delta: float) -> void:
	match _phase:
		Phase.COUNTDOWN:
			_clock -= delta
			if _clock <= 0.0:
				for b in _balls:
					player(b.slot).recenter() # Use the pose held during the countdown.
				_phase = Phase.PLAYING
				_race_time = 0.0
		Phase.PLAYING:
			_race_time += delta
			for b in _balls:
				_step_ball(b, delta)
				if b.pos.distance_to(_exit_center()) < CELL * 0.3:
					_finish(b.slot)
					return
		Phase.DONE:
			pass


func _finish(slot: int) -> void:
	_phase = Phase.DONE
	_winner = slot
	App.server.haptic(slot, 400)
	open_menu("Player %d wins!   %.1f s" % [slot + 1, _race_time],
			[["Play again", restart], ["Back to menu", App.go_menu]])


func _exit_center() -> Vector2:
	return Vector2((COLS - 0.5) * CELL, (ROWS - 0.5) * CELL)


func _step_ball(b: Ball, dt: float) -> void:
	var p := player(b.slot)
	var t := p.tilt()
	if t.length() < DEADZONE:
		t = Vector2.ZERO
	b.vel += t * TILT_ACCEL * dt
	b.vel *= maxf(0.0, 1.0 - FRICTION * dt)
	if b.vel.length() > MAX_SPEED:
		b.vel = b.vel.normalized() * MAX_SPEED
	b.haptic_cooldown = maxf(0.0, b.haptic_cooldown - dt)
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
			if -vn > 320.0 and b.haptic_cooldown <= 0.0:
				App.server.haptic(b.slot, 20)
				b.haptic_cooldown = 0.12
			b.vel -= (1.0 + RESTITUTION) * vn * n


## A wall rectangle with round ends: a bar and a circle on each end.
func _draw_wall(o: Vector2, r: Rect2) -> void:
	var t := minf(r.size.x, r.size.y)
	var half := t * 0.5
	if r.size.x >= r.size.y:
		draw_rect(Rect2(o + r.position + Vector2(half, 0), Vector2(maxf(r.size.x - t, 0.0), t)), WALL_COLOR)
		draw_circle(o + r.position + Vector2(half, half), half, WALL_COLOR)
		draw_circle(o + r.position + Vector2(r.size.x - half, half), half, WALL_COLOR)
	else:
		draw_rect(Rect2(o + r.position + Vector2(0, half), Vector2(t, maxf(r.size.y - t, 0.0))), WALL_COLOR)
		draw_circle(o + r.position + Vector2(half, half), half, WALL_COLOR)
		draw_circle(o + r.position + Vector2(half, r.size.y - half), half, WALL_COLOR)


func _origin() -> Vector2:
	return Vector2((size.x - COLS * CELL) * 0.5, (size.y - ROWS * CELL) * 0.5 + 46.0)


func _game_draw() -> void:
	var o := _origin()
	# Board, start cell and exit (the goal has a dark outline and a hard shadow).
	draw_style_box(_sb_board, Rect2(o, Vector2(COLS * CELL, ROWS * CELL)).grow(BOARD_PAD))
	draw_style_box(_sb_start, Rect2(o + Vector2(WALL, WALL) * 0.5, Vector2(CELL, CELL) - Vector2(WALL, WALL)))
	var exit_cell := Rect2(o + Vector2((COLS - 1) * CELL, (ROWS - 1) * CELL), Vector2(CELL, CELL)).grow(-WALL * 0.5 - 4.0)
	draw_style_box(_sb_exit, exit_cell)
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.006) # The exit pulses a little (easy to find).
	draw_arc(o + _exit_center(), CELL * 0.30 * pulse, 0, TAU, 48, UiTheme.OUTLINE, 14.0)
	draw_arc(o + _exit_center(), CELL * 0.30 * pulse, 0, TAU, 48, Color.WHITE, 8.0)
	# Walls: rounded ends (REQ-GM-47f). The collision still uses the rectangles.
	for r in _walls:
		_draw_wall(o, r)
	# Balls: a hard shadow, a dark outline, the player color and a small shine (REQ-GM-47a, 47b).
	for b in _balls:
		var col: Color = player(b.slot).color
		var c := o + b.pos
		draw_circle(c + UiTheme.SHADOW * 0.6, BALL_R + OUTLINE_BIG, UiTheme.OUTLINE)
		draw_circle(c, BALL_R + OUTLINE_BIG, UiTheme.OUTLINE)
		draw_circle(c, BALL_R, col)
		draw_circle(c + Vector2(-8, -9), 6.0, Color(1, 1, 1, 0.55))
		# The slot number on the ball: players do not depend on the color alone (REQ-GM-46).
		var f := UiTheme.title_font()
		draw_string_outline(f, c + Vector2(-BALL_R, 9.0), str(b.slot + 1), HORIZONTAL_ALIGNMENT_CENTER, BALL_R * 2.0, 26, 8,
				UiTheme.OUTLINE)
		draw_string(f, c + Vector2(-BALL_R, 9.0), str(b.slot + 1), HORIZONTAL_ALIGNMENT_CENTER, BALL_R * 2.0, 26, Color.WHITE)
	# HUD
	Shell.title(self, "TILT MAZE")
	var order := participants.duplicate()
	order.sort() # P1 first, left to right.
	var x := size.x - 60.0 - 270.0 * order.size() + 20.0
	for s in order:
		Shell.chip(self, Vector2(x, 36), player(s).player_name, player(s).color, 250.0)
		x += 270.0
	if _phase == Phase.PLAYING:
		Shell.timer(self, Vector2(TIMER_X, 36.0), _race_time) # Next to the title: 4 chips use the right side.
	if _phase == Phase.COUNTDOWN and not participants.is_empty():
		var n := ceili(_clock)
		Shell.countdown(self, size, str(n) if n > 0 else "GO", float(n) - _clock)
		Shell.hint(self, size, "Hold the phone level. It recenters at GO.")
	if participants.is_empty():
		Shell.hint(self, size, "Join with the controller app, then start again.")
