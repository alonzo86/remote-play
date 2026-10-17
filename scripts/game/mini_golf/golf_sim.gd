extends RefCounted
## The ball of Mini Golf on one hole (REQ-MG-5, 9, 10): a ball that rolls on the ground of a hole, slows down, bounces from the
## walls, the bumpers and the blocks, falls into water and into the cup. Pure logic: it draws nothing.
## The ball is a point with a radius that moves in small steps, one axis at a time, so that it bounces from straight walls.

const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")

const STEP := 1.0 / 120.0
const ROLL_DECEL := 0.9          # m/s2 on grass.
const WALL_KEEP := 0.7           # The speed that stays after a wall.
const BUMPER_KEEP := 1.05        # A bumper gives a little push.
const STOP_SPEED := 0.04         # Under this speed (m/s) the ball stops.
const CUP_SPEED := 1.6           # A ball slower than this falls into the cup; a faster one rolls over it.
const MAX_TIME := 14.0           # A putt ends after this time at the latest.
const SPEED_TOP := 4.5           # The speed of the strongest putt (m/s).

var hole: Dictionary = {}
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var finished := true             # True while the ball stands still.
var in_cup := false
var in_water := false
var time := 0.0
## What happened in the last `tick()`: dictionaries `{"t": "wall" | "bumper" | "water" | "cup"}`.
var events: Array[Dictionary] = []


## Puts the ball of the hole at `at` (the tee, the place of the last putt) and stops it.
func start(h: Dictionary, at: Vector2) -> void:
	hole = h
	pos = at
	vel = Vector2.ZERO
	finished = true
	in_cup = false
	in_water = false
	time = 0.0
	events.clear()


## The ball starts rolling in `heading` (radians from the +z axis towards +x) with `speed` (m/s).
func putt(heading: float, speed: float) -> void:
	vel = Vector2(sin(heading), cos(heading)) * speed
	finished = false
	in_cup = false
	in_water = false
	time = 0.0


## The speed of a putt for a swing power of 0 to 1 (REQ-MG-5): `speed_min` is the speed of the weakest putt.
static func speed_for(power: float, speed_min: float) -> float:
	return lerpf(speed_min, SPEED_TOP, clampf(power, 0.0, 1.0))


## The heading from `from` to the cup.
static func heading_to_cup(h: Dictionary, from: Vector2) -> float:
	var d: Vector2 = Vector2(h.cup) - from
	return atan2(d.x, d.y)


## True when a ball (a point) can stand at `p`: on the ground and not inside a block.
static func walkable(h: Dictionary, p: Vector2) -> bool:
	var ok := false
	for r in h.fairway:
		if (r as Rect2).grow(-Holes.BALL_R).has_point(p):
			ok = true
			break
	if not ok:
		return false
	for b in h.blocks:
		if (b as Rect2).grow(Holes.BALL_R).has_point(p):
			return false
	return true


func tick(delta: float) -> void:
	events.clear()
	if finished:
		return
	var left := delta
	while left > 0.0 and not finished:
		var dt := minf(STEP, left)
		left -= dt
		_step(dt)


func _step(dt: float) -> void:
	time += dt
	var speed := vel.length()
	speed = maxf(0.0, speed - ROLL_DECEL * dt)
	vel = vel.normalized() * speed if speed > 0.0 else Vector2.ZERO
	if speed < STOP_SPEED or time > MAX_TIME:
		vel = Vector2.ZERO
		finished = true
		return
	# One axis at a time, so that a straight wall mirrors one part of the speed.
	var nx := Vector2(pos.x + vel.x * dt, pos.y)
	if walkable(hole, nx):
		pos = nx
	else:
		vel.x = -vel.x * WALL_KEEP
		events.append({"t": "wall"})
	var nz := Vector2(pos.x, pos.y + vel.y * dt)
	if walkable(hole, nz):
		pos = nz
	else:
		vel.y = -vel.y * WALL_KEEP
		events.append({"t": "wall"})
	for b in hole.bumpers:
		var bv: Vector3 = b
		var d := pos - Vector2(bv.x, bv.y)
		var reach := bv.z + Holes.BALL_R
		if d.length() < reach:
			var n := d.normalized() if d.length() > 0.0001 else Vector2(0.0, -1.0)
			vel = (vel - 2.0 * vel.dot(n) * n) * BUMPER_KEEP
			pos = Vector2(bv.x, bv.y) + n * (reach + 0.002)
			events.append({"t": "bumper"})
	if Holes.is_water(hole, pos):
		vel = Vector2.ZERO
		finished = true
		in_water = true
		events.append({"t": "water"})
		return
	var to_cup: Vector2 = Vector2(hole.cup) - pos
	if to_cup.length() < Holes.CUP_R and vel.length() < CUP_SPEED:
		pos = hole.cup
		vel = Vector2.ZERO
		finished = true
		in_cup = true
		events.append({"t": "cup"})
