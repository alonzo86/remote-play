extends RefCounted
## The rules and the physics of Air Hockey (REQ-AH-4 to 12), with no nodes: a rink, a puck and two paddles. A seat is 0 (left,
## defends the left goal) or 1 (right). The paddle is a `TiltBody` that a tilt moves inside its own half. The game and the tests
## call `step()`. Units: px of the 1920x1080 design screen and seconds.

const TiltBody = preload("res://scripts/game/tilt_body.gd")

const RINK := Rect2(120.0, 152.0, 1680.0, 728.0)   # The playing surface inside the rails.
const GOAL_H := 280.0           # The height of a goal opening in the middle of each short side.
const PUCK_R := 34.0
const PADDLE_R := 60.0
const PADDLE_ACCEL := 5200.0    # The paddle body (a `TiltBody`): the same values for both seats (REQ-GM-24).
const PADDLE_DAMPING := 5.0
const PADDLE_MAX := 1100.0
const PUCK_DAMPING := 0.35      # 1/s: the puck slows down by itself, slowly.
const PUCK_MAX := 1800.0        # px/s
const WALL_KEEP := 0.92         # The part of the speed that is kept after a bounce at a rail.
const HIT_KEEP := 0.9           # Restitution of a paddle hit.
const MIN_HIT := 420.0          # A hit sends the puck away at this speed at least: it never sticks to a paddle.
const SERVE_WAIT := 1.0         # The puck waits this long on its spot after a goal.
const MAX_STEP := 1.0 / 120.0   # A longer frame is split: the puck cannot jump over a paddle.
const SERVE_DX := 260.0         # The serve spot is this far from the middle line, on the side of the seat that conceded.
const START_DX := 300.0         # The start place of a paddle is this far from its goal line.

var puck_pos := Vector2.ZERO
var puck_vel := Vector2.ZERO
var paddles: Array[TiltBody] = []
var wait := 0.0                 # While above 0 the puck stands still on its spot.


func _init() -> void:
	for i in 2:
		var b := TiltBody.new()
		b.radius = PADDLE_R
		b.accel = PADDLE_ACCEL
		b.damping = PADDLE_DAMPING
		b.max_speed = PADDLE_MAX
		paddles.append(b)
	reset(-1)


## A new rally: the paddles go to their start places. The puck waits on the serve spot of `serve_seat` (the seat that conceded
## the last goal), or in the middle at the start of a match (-1).
func reset(serve_seat: int) -> void:
	var c := RINK.get_center()
	paddles[0].pos = Vector2(RINK.position.x + START_DX, c.y)
	paddles[1].pos = Vector2(RINK.end.x - START_DX, c.y)
	for p in paddles:
		p.vel = Vector2.ZERO
	puck_vel = Vector2.ZERO
	puck_pos = c if serve_seat < 0 else c + Vector2(-SERVE_DX if serve_seat == 0 else SERVE_DX, 0.0)
	wait = SERVE_WAIT


## The area a seat's paddle may move in: its own half of the rink.
static func half(seat: int) -> Rect2:
	var w := RINK.size.x * 0.5
	return Rect2(RINK.position + Vector2(0.0 if seat == 0 else w, 0.0), Vector2(w, RINK.size.y))


static func goal_x(seat: int) -> float:
	return RINK.position.x if seat == 0 else RINK.end.x


## Moves the paddles by `tilts` (one tilt for each seat) and the puck. Returns what happened: `goal` is the seat that scored
## (-1 for none), `hit` the seat of the paddle that hit the puck (-1 for none), `hit_speed` the speed after the hit, and `wall`
## the speed of the hardest bounce at a rail (0 for none).
func step(dt: float, tilts: Array) -> Dictionary:
	var ev := {"goal": -1, "hit": -1, "hit_speed": 0.0, "wall": 0.0}
	var left := dt
	while left > 0.0:
		var h := minf(left, MAX_STEP)
		left -= h
		_step_once(h, tilts, ev)
		if ev.goal >= 0:
			break
	return ev


func _step_once(dt: float, tilts: Array, ev: Dictionary) -> void:
	for i in 2:
		paddles[i].step(dt, tilts[i], half(i))
	if wait > 0.0:
		wait -= dt
		_keep_out(puck_pos)
		return
	puck_vel *= exp(-PUCK_DAMPING * dt)
	puck_pos += puck_vel * dt
	for i in 2:
		if _hit_paddle(paddles[i]):
			ev.hit = i
			ev.hit_speed = puck_vel.length()
	var wall := _rails()
	ev.wall = maxf(ev.wall, wall)
	var c := RINK.get_center()
	if absf(puck_pos.y - c.y) < GOAL_H * 0.5:
		if puck_pos.x < RINK.position.x - PUCK_R:
			ev.goal = 1
		elif puck_pos.x > RINK.end.x + PUCK_R:
			ev.goal = 0


## While the puck waits on its spot it is solid for the paddles: a paddle that reaches it stops at its edge. Without this a
## paddle that stands in the puck when the wait ends hits it away from the wrong side (an own goal, issue #146).
func _keep_out(spot: Vector2) -> void:
	for p in paddles:
		var d: Vector2 = p.pos - spot
		var reach := PUCK_R + PADDLE_R
		if d.length() >= reach:
			continue
		var n := d / d.length() if d.length() > 0.001 else Vector2.RIGHT
		p.pos = spot + n * reach
		p.vel -= minf(p.vel.dot(n), 0.0) * n


## The puck leaves a paddle it overlaps: it takes the speed of the paddle into account (a moving paddle hits harder).
func _hit_paddle(p: TiltBody) -> bool:
	var d := puck_pos - p.pos
	var dist := d.length()
	var reach := PUCK_R + PADDLE_R
	if dist >= reach:
		return false
	var n := d / dist if dist > 0.001 else Vector2.RIGHT
	puck_pos = p.pos + n * reach
	var rel := puck_vel - p.vel
	var closing := rel.dot(n)
	if closing < 0.0:
		rel -= (1.0 + HIT_KEEP) * closing * n
	puck_vel = rel + p.vel
	if puck_vel.dot(n) < MIN_HIT:
		puck_vel += n * (MIN_HIT - puck_vel.dot(n))
	puck_vel = puck_vel.limit_length(PUCK_MAX)
	return true


## Bounces the puck off the rails. The goal openings are open. Returns the speed of the hardest bounce (0 for none).
func _rails() -> float:
	var hit := 0.0
	var c := RINK.get_center()
	if puck_pos.y < RINK.position.y + PUCK_R:
		puck_pos.y = RINK.position.y + PUCK_R
		hit = maxf(hit, absf(puck_vel.y))
		puck_vel.y = absf(puck_vel.y) * WALL_KEEP
	elif puck_pos.y > RINK.end.y - PUCK_R:
		puck_pos.y = RINK.end.y - PUCK_R
		hit = maxf(hit, absf(puck_vel.y))
		puck_vel.y = -absf(puck_vel.y) * WALL_KEEP
	if absf(puck_pos.y - c.y) >= GOAL_H * 0.5:
		if puck_pos.x < RINK.position.x + PUCK_R:
			puck_pos.x = RINK.position.x + PUCK_R
			hit = maxf(hit, absf(puck_vel.x))
			puck_vel.x = absf(puck_vel.x) * WALL_KEEP
		elif puck_pos.x > RINK.end.x - PUCK_R:
			puck_pos.x = RINK.end.x - PUCK_R
			hit = maxf(hit, absf(puck_vel.x))
			puck_vel.x = -absf(puck_vel.x) * WALL_KEEP
	return hit
