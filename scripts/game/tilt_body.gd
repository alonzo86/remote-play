extends RefCounted
## A round body that a phone tilts around a rectangle (REQ-PG-7, REQ-PG-30). It has no nodes: position, velocity, the
## acceleration of the tilt, a dead zone, damping, a speed limit and a soft bounce at the edge. `step()` moves it and `collide()`
## bounces two bodies off each other. The values are the same for all players (REQ-GM-24). Units: px and seconds.

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var radius := 34.0
var accel := 2200.0       # px/s2 for tilt 1.0 (the sine of the angle).
var damping := 1.4        # 1/s: the speed falls by itself.
var max_speed := 560.0
var deadzone := 0.03      # A tilt smaller than this is no tilt.
var bounce := 0.35        # The part of the speed that is kept after a bounce at the edge.


## One step of `dt` seconds. `tilt` is `PlayerInput.tilt()`. The body stays inside `bounds` with its whole circle.
## Returns the speed (px/s) of the hit when it bounced at the edge, or 0.0.
func step(dt: float, tilt: Vector2, bounds: Rect2) -> float:
	var t := tilt if tilt.length() >= deadzone else Vector2.ZERO
	vel += t * accel * dt
	vel *= exp(-damping * dt)   # The same result at every frame rate (REQ-GM-13).
	if vel.length() > max_speed:
		vel = vel.normalized() * max_speed
	pos += vel * dt
	return _keep_inside(bounds)


## Bounces two bodies of the same weight off each other when they overlap: they are pushed apart and lose a part of the
## speed along the line between them. Returns true when they touched.
static func collide(a: RefCounted, b: RefCounted, restitution := 0.6) -> bool:
	var d: Vector2 = b.pos - a.pos
	var dist := d.length()
	var reach: float = a.radius + b.radius
	if dist >= reach:
		return false
	var n := d / dist if dist > 0.001 else Vector2.RIGHT   # Two bodies in the same place: any direction.
	var overlap := reach - dist
	a.pos -= n * overlap * 0.5
	b.pos += n * overlap * 0.5
	var closing: float = (b.vel - a.vel).dot(n)
	if closing < 0.0:
		var j := -(1.0 + restitution) * closing * 0.5
		a.vel -= n * j
		b.vel += n * j
	return true


func _keep_inside(bounds: Rect2) -> float:
	var lo := bounds.position + Vector2.ONE * radius
	var hi := bounds.end - Vector2.ONE * radius
	var hit := 0.0
	if pos.x < lo.x:
		hit = maxf(hit, absf(vel.x))
		pos.x = lo.x
		vel.x = absf(vel.x) * bounce
	elif pos.x > hi.x:
		hit = maxf(hit, absf(vel.x))
		pos.x = hi.x
		vel.x = -absf(vel.x) * bounce
	if pos.y < lo.y:
		hit = maxf(hit, absf(vel.y))
		pos.y = lo.y
		vel.y = absf(vel.y) * bounce
	elif pos.y > hi.y:
		hit = maxf(hit, absf(vel.y))
		pos.y = hi.y
		vel.y = -absf(vel.y) * bounce
	return hit
