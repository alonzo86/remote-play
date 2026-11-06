extends RefCounted
## The ball of Mini Golf on one hole (REQ-MG-5, 9, 10): a ball that rolls on the ground of a hole, slows down, bounces from the
## walls, the blocks, the rocks and the hills, falls into water and into the cup. Pure
## logic: it draws nothing.
## The ball is a point with a radius that moves in small steps, one axis at a time, so that it bounces from straight walls.

const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")

const STEP := 1.0 / 120.0
const ROLL_DECEL := 0.9          # m/s2 on grass.
const WALL_KEEP := 0.7           # The speed that stays after a wall.
const ROCK_KEEP := 0.65          # A rock takes some speed.
const STOP_SPEED := 0.04         # Under this speed (m/s) the ball stops.
const CUP_SPEED := 1.6           # A ball slower than this falls into the cup; a faster one rolls over it.
const MAX_TIME := 14.0           # A putt ends after this time at the latest.
const TELEPORT_SPEED := 1.5      # A ball slower than this falls into a teleport pad; a faster one rolls over it.
const LOOP_KEEP := 0.9           # The share of its speed that a ball keeps when it comes out of a loop.
const SAND_DECEL := 3.0          # m/s2 in a sand trap, against ROLL_DECEL on grass.
const HILL_G := 9.8              # m/s2: a hill slows a ball that climbs it and speeds up one that rolls down.
const SPEED_TOP := 4.5           # The speed of the strongest putt (m/s).

var hole: Dictionary = {}
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var finished := true             # True while the ball stands still.
var in_cup := false
var in_water := false
## While the ball goes round a loop: how far it is (0 to 1) and the loop; -1 when it is not in a loop.
var loop_t := -1.0
var loop_info: Dictionary = {}
var _loop_speed := 0.0
var _on_pad := false         # True while the ball stands on a teleport pad: it does not fall in again until it has left it.
var time := 0.0
## What happened in the last `tick()`: dictionaries `{"t": "wall" | "rock" | "water" | "cup"}`.
var events: Array[Dictionary] = []


## Puts the ball of the hole at `at` (the tee, the place of the last putt) and stops it.
func start(h: Dictionary, at: Vector2) -> void:
	hole = h
	pos = at
	vel = Vector2.ZERO
	finished = true
	in_cup = false
	in_water = false
	loop_t = -1.0
	_on_pad = Holes.on_pad(h, at)
	time = 0.0
	events.clear()


## The ball starts rolling in `heading` (radians from the +z axis towards +x) with `speed` (m/s).
func putt(heading: float, speed: float) -> void:
	vel = Vector2(sin(heading), cos(heading)) * speed
	finished = false
	in_cup = false
	in_water = false
	loop_t = -1.0
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
	for b in Holes.solid_blocks(h):
		if b.grow(Holes.BALL_R).has_point(p):
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
	var before := pos
	if loop_t >= 0.0:   # The ball goes round a ring: it comes out at the exit when the time is up.
		_step_loop(dt)
		return
	var slope := Holes.hill_slope(hole, pos)
	vel.y -= HILL_G * slope * dt
	var decel := SAND_DECEL if Holes.in_sand(hole, pos) else ROLL_DECEL
	var speed := vel.length()
	speed = maxf(0.0, speed - decel * dt)
	vel = vel.normalized() * speed if speed > 0.0 else Vector2.ZERO
	if (speed < STOP_SPEED and absf(HILL_G * slope) <= decel) or time > MAX_TIME:
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
	for rk in hole.rocks:
		var rv: Vector3 = rk
		var rc := Vector2(rv.x, rv.y)
		var rd := pos - rc
		var rreach := rv.z + Holes.BALL_R
		if rd.length() < rreach:
			var rn := rd.normalized() if rd.length() > 0.0001 else (before - rc).normalized()
			if vel.dot(rn) < 0.0:   # Only a ball that moves into the rock bounces: one that moves away is not turned back.
				vel = (vel - 2.0 * vel.dot(rn) * rn) * ROCK_KEEP
			var out := rc + rn * (rreach + 0.002)
			# A ball pushed out of a rock must stay on the ground: beside a wall it goes back to where it was before the step.
			pos = out if walkable(hole, out) else before
			events.append({"t": "rock"})
	var loop := Holes.loop_at(hole, pos)
	if not loop.is_empty():   # The entry of a loop, a jump or a cannon.
		var kind := String(loop.get("kind", "loop"))
		var dir := Vector2(sin(float(loop.get("dir", 0.0))), cos(float(loop.get("dir", 0.0))))
		if kind == "cannon" or (vel.length() >= float(loop.min_speed) and vel.dot(dir) > 0.0):
			match kind:
				"cannon":
					_loop_speed = float(loop.speed)
				"jump":   # A ball that has flown over a lake lands and slows down.
					_loop_speed = maxf(vel.length() * 0.6, 0.8)
				_:
					_loop_speed = maxf(vel.length() * LOOP_KEEP, 1.5)
			loop_info = loop
			loop_t = 0.0
			vel = Vector2.ZERO
			pos = (loop.enter as Rect2).get_center()
			events.append({"t": "cannon" if kind == "cannon" else "loop"})
		else:   # A ball that is too slow for the loop or the ramp is turned back.
			vel = -vel * WALL_KEEP
			pos = before
			events.append({"t": "wall"})
		return
	if not _on_pad:   # A slow ball that falls into the entrance pad of a teleport comes out of the exit pad and stops there.
		for t in hole.get("teleports", []):
			if pos.distance_to(t.a) < float(t.r) and vel.length() < TELEPORT_SPEED:
				pos = t.b
				vel = Vector2.ZERO
				finished = true
				_on_pad = true
				events.append({"t": "teleport"})
				return
	elif not Holes.on_pad(hole, pos):
		_on_pad = false
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


## The ball goes round the ring of a loop for `loop_info.time` seconds, then comes out at the exit with its speed (`LOOP_KEEP` of
## the speed it came with) in the heading of the loop.
func _step_loop(dt: float) -> void:
	loop_t += dt / float(loop_info.time)
	if loop_t < 1.0:
		return
	loop_t = -1.0
	pos = loop_info.exit
	var h := float(loop_info.heading)
	vel = Vector2(sin(h), cos(h)) * _loop_speed
