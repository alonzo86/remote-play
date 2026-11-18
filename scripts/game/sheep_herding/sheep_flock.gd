extends RefCounted
## The sheep of Sheep Herding and the fence around them (REQ-SH-4 to 12). Pure logic, no nodes and no drawing. Units: px and
## seconds, on the 1920 x 1080 screen (REQ-GM-13: `dt` only). A sheep keeps away from a dog that comes close, stays with its
## friends a little, grazes when no dog is near, and cannot walk through the barn, the fence of the pen or the edge of the field.
## The things around the field (a pond, a rock, a tree, a hay stack) are only scenery: nothing walks into them, but they are
## where the sheep and dogs do not start (REQ-SH-4). A scared sheep is helped toward the gate by the difficulty (REQ-SH-21).
## A sheep that walks in through the gate is in the pen for good (REQ-SH-6); nothing hurts it.

const RADIUS := 28.0              # A sheep is about 72 x 56 px on the screen (REQ-GM-47e).
const HALF := Vector2(36.0, 28.0) # Half of the picture of a sheep: all of it stays on the grass (REQ-SH-22).
const FLEE_ACCEL := 2600.0        # px/s2 for a dog right next to the sheep. It falls to 0 at the flee radius.
const DAMPING := 2.5              # 1/s.
const GRAZE_SPEED := 45.0         # The speed limit of a sheep that nobody scares.
const GRAZE_ACCEL := 90.0
const COHESION_R := 340.0         # A sheep walks slowly toward the middle of the friends this close.
const COHESION_ACCEL := 40.0
const SCARED_TIME := 0.7          # A sheep stays "scared" (runs, shows dashes) for this long after a dog was close.
const SCARED_AT := 0.25           # The share of the flee radius at which a sheep gets scared.
const WALL := 12.0                # The thickness of the fence.
const WALL_BOUNCE := 0.3
const HOP_TIME := 0.4             # A sheep that enters the pen hops once.
const WANDER_MIN := 1.0
const WANDER_MAX := 3.0

class Sheep:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var penned := false
	var scared := 0.0            # The time left of the fright. It is above 0 while the sheep runs.
	var last_dog := -1           # The slot of the dog that was closest when the sheep was last scared.
	var hop := 0.0               # The time left of the hop of a sheep that has just entered the pen.
	var heading := 0.0           # The way the sheep grazes, in radians, and how long that lasts.
	var heading_left := 0.0
	var grazing := false

var field := Rect2()
var pen := Rect2()               # The outside of the pen, the fence included.
var gate := 180.0                # The height of the gap in the left fence.
var walls: Array[Rect2] = []     # The fence, and the barn.
var blockers: Array[Dictionary] = []   # {pos: Vector2, r: float}: the scenery. Sheep do not start on it; it never blocks.
var sheep: Array[Sheep] = []
var flee_radius := 260.0
var run_speed := 270.0
var assist := 0.0                # 0 to 1: how much of the flee force of a scared sheep turns toward the gate (REQ-SH-21).
var events: Array[Dictionary] = []   # What happened in the last `tick()`: {t: "startled" | "penned", i, slot, pos}.


## `params`: gate (px), flee (px), speed (px/s), assist (0 to 1, optional). The fence is built from `pen_rect` and `gate`.
func setup(field_rect: Rect2, pen_rect: Rect2, params: Dictionary, p_blockers: Array[Dictionary],
		extra_walls: Array[Rect2]) -> void:
	field = field_rect
	pen = pen_rect
	gate = float(params.gate)
	flee_radius = float(params.flee)
	run_speed = float(params.speed)
	assist = clampf(float(params.get("assist", 0.0)), 0.0, 1.0)
	blockers = p_blockers
	walls = _fence()
	walls.append_array(extra_walls)


## The fence: top, bottom and right, and the left side in two pieces with the gate between them.
func _fence() -> Array[Rect2]:
	var gate_top := pen.position.y + (pen.size.y - gate) * 0.5
	var gate_bottom := gate_top + gate
	var f: Array[Rect2] = []
	f.append(Rect2(pen.position, Vector2(pen.size.x, WALL)))
	f.append(Rect2(Vector2(pen.position.x, pen.end.y - WALL), Vector2(pen.size.x, WALL)))
	f.append(Rect2(Vector2(pen.end.x - WALL, pen.position.y), Vector2(WALL, pen.size.y)))
	f.append(Rect2(pen.position, Vector2(WALL, gate_top - pen.position.y)))
	f.append(Rect2(Vector2(pen.position.x, gate_bottom), Vector2(WALL, pen.end.y - gate_bottom)))
	return f


## The inside of the pen: where a sheep stands when it is in.
func interior() -> Rect2:
	return pen.grow(-WALL)


## The gate of the pen: the middle of the opening.
func gate_center() -> Vector2:
	return Vector2(pen.position.x, pen.position.y + pen.size.y * 0.5)


## Puts `count` sheep inside `area`, apart from each other and from the blockers. They graze at first.
func spawn(count: int, area: Rect2, rng: RandomNumberGenerator) -> void:
	sheep.clear()
	var tries := 0
	while sheep.size() < count and tries < 4000:
		tries += 1
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var gap := 2.0 * RADIUS + 24.0
		if tries > 1500:
			gap = 2.0 * RADIUS   # A crowded area: the sheep may be closer.
		if _free(p, gap):
			var s := Sheep.new()
			s.pos = p
			s.heading = rng.randf() * TAU
			sheep.append(s)


func _free(p: Vector2, gap: float) -> bool:
	for s in sheep:
		if s.pos.distance_to(p) < gap:
			return false
	for b in blockers:
		if p.distance_to(b.pos) < float(b.r) + RADIUS + 8.0:
			return false
	for w in walls:
		if w.grow(RADIUS + 8.0).has_point(p):
			return false
	return field.grow(-RADIUS).has_point(p)


func penned_count() -> int:
	var n := 0
	for s in sheep:
		if s.penned:
			n += 1
	return n


func all_penned() -> bool:
	return not sheep.is_empty() and penned_count() == sheep.size()


## One step of `dt` seconds. `dogs` maps a slot to the position of its dog.
func tick(dt: float, dogs: Dictionary, rng: RandomNumberGenerator) -> void:
	events.clear()
	for i in sheep.size():
		var s: Sheep = sheep[i]
		if s.hop > 0.0:
			s.hop = maxf(s.hop - dt, 0.0)
		if s.penned:
			_tick_penned(s, dt, rng)
		else:
			_tick_free(i, s, dt, dogs, rng)
	_separate()   # It puts both sheep of a pair back on the grass and out of the walls (REQ-SH-22).


func _tick_free(i: int, s: Sheep, dt: float, dogs: Dictionary, rng: RandomNumberGenerator) -> void:
	var force := Vector2.ZERO
	var nearest := INF
	var nearest_slot := -1
	for slot in dogs:
		var d: Vector2 = s.pos - dogs[slot]
		var dist := d.length()
		if dist >= flee_radius:
			continue
		var away := d / dist if dist > 0.001 else Vector2.RIGHT
		var push := FLEE_ACCEL * (1.0 - dist / flee_radius)   # The closer the dog, the harder the sheep runs.
		force += away * push + _assist_dir(s.pos, away) * push * assist
		if dist < nearest:
			nearest = dist
			nearest_slot = int(slot)
	if nearest < flee_radius * (1.0 - SCARED_AT) or (nearest < flee_radius and s.scared > 0.0):
		if s.scared <= 0.0:
			events.append({"t": "startled", "i": i, "slot": nearest_slot, "pos": s.pos})
		s.scared = SCARED_TIME
		s.last_dog = nearest_slot
	else:
		s.scared = maxf(s.scared - dt, 0.0)
	if s.scared <= 0.0:
		force += _graze_force(s, dt, rng)
	force += _cohesion(s)
	s.vel += force * dt
	s.vel *= exp(-DAMPING * dt)   # The same result at every frame rate (REQ-GM-13).
	var limit := run_speed if s.scared > 0.0 else GRAZE_SPEED
	if s.vel.length() > limit:
		s.vel = s.vel.normalized() * limit
	s.pos += s.vel * dt
	var fixed := resolve(s.pos, s.vel, RADIUS, HALF)
	s.pos = fixed[0]
	s.vel = fixed[1]
	if _in_pen(s.pos):
		s.penned = true
		s.hop = HOP_TIME
		s.scared = 0.0
		events.append({"t": "penned", "i": i, "slot": s.last_dog, "pos": s.pos})


## The way a scared sheep is helped (REQ-SH-21): toward the gate, but never toward the dog. The part of the way to the gate that
## points at the dog is dropped, so a dog in front makes the sheep slide to the side and not run into the dog.
func _assist_dir(pos: Vector2, away: Vector2) -> Vector2:
	if assist <= 0.0:
		return Vector2.ZERO
	var to_gate := (gate_center() - pos).normalized()
	var toward_dog := to_gate.dot(away)
	return to_gate - away * toward_dog if toward_dog < 0.0 else to_gate


## A sheep that nobody scares walks a little in one direction and then stands still, and picks a new way.
func _graze_force(s: Sheep, dt: float, rng: RandomNumberGenerator) -> Vector2:
	s.heading_left -= dt
	if s.heading_left <= 0.0:
		s.heading_left = rng.randf_range(WANDER_MIN, WANDER_MAX)
		s.heading = rng.randf() * TAU
		s.grazing = rng.randf() < 0.5
	return Vector2.from_angle(s.heading) * GRAZE_ACCEL if s.grazing else Vector2.ZERO


## A weak pull toward the middle of the free sheep that are near, so that a flock stays a flock.
func _cohesion(s: Sheep) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for o in sheep:
		if o != s and not o.penned and o.pos.distance_to(s.pos) < COHESION_R:
			sum += o.pos
			n += 1
	if n == 0:
		return Vector2.ZERO
	var to_middle := sum / float(n) - s.pos
	return to_middle.normalized() * COHESION_ACCEL if to_middle.length() > 3.0 * RADIUS else Vector2.ZERO


## A sheep in the pen walks around inside it (it never runs and does not mind the dogs).
func _tick_penned(s: Sheep, dt: float, rng: RandomNumberGenerator) -> void:
	s.vel += _graze_force(s, dt, rng) * dt
	s.vel *= exp(-DAMPING * dt)
	s.vel = s.vel.limit_length(GRAZE_SPEED)
	s.pos += s.vel * dt
	var inner := interior().grow(-RADIUS)
	# It slides in from the gate instead of jumping.
	var target := s.pos.clamp(inner.position, inner.end)
	s.pos = s.pos.move_toward(target, 240.0 * dt) if s.pos != target else s.pos
	if not inner.has_point(s.pos):
		s.vel = Vector2.ZERO


## True when the middle of a sheep has passed the fence line through the gate.
func _in_pen(p: Vector2) -> bool:
	var inner := interior()
	return p.x >= inner.position.x + RADIUS * 0.5 and p.x <= inner.end.x and p.y >= inner.position.y and p.y <= inner.end.y


## Free sheep do not overlap: each pair is pushed apart by half the overlap each.
func _separate() -> void:
	for a in sheep.size():
		for b in range(a + 1, sheep.size()):
			var sa: Sheep = sheep[a]
			var sb: Sheep = sheep[b]
			var d: Vector2 = sb.pos - sa.pos
			var dist := d.length()
			var reach := 2.0 * RADIUS * 0.9
			if dist >= reach:
				continue
			var n := d / dist if dist > 0.001 else Vector2.RIGHT.rotated(float(a))
			var push := n * (reach - dist) * 0.5
			sa.pos -= push
			sb.pos += push
			sa.pos = resolve(sa.pos, sa.vel, RADIUS, HALF)[0]
			sb.pos = resolve(sb.pos, sb.vel, RADIUS, HALF)[0]


## Moves a circle out of the fence, the barn and the edge of the field (not the scenery, REQ-SH-4). Returns `[pos, vel]`:
## the speed that goes into a wall is turned back a little. It is used for the sheep and for the dogs. `half` is half of the
## picture (the width and the height): the picture stays on the grass, so the middle keeps at least `half` from the edge, and at
## least `r` (REQ-SH-22).
func resolve(pos: Vector2, vel: Vector2, r: float, half := Vector2.ZERO) -> Array:
	for w in walls:
		var push := push_out_of_rect(pos, r, w)
		if push != Vector2.ZERO:
			pos += push
			vel = _bounce(vel, push.normalized())
	var inner := field.grow_individual(-maxf(r, half.x), -maxf(r, half.y), -maxf(r, half.x), -maxf(r, half.y))
	var kept := pos.clamp(inner.position, inner.end)
	if kept != pos:
		vel = _bounce(vel, (kept - pos).normalized())
		pos = kept
	return [pos, vel]


func _bounce(vel: Vector2, n: Vector2) -> Vector2:
	var into := vel.dot(n)
	return vel - n * into * (1.0 + WALL_BOUNCE) if into < 0.0 else vel


## The vector that moves a circle at `pos` with radius `r` out of `rect`, or ZERO when they do not touch.
static func push_out_of_rect(pos: Vector2, r: float, rect: Rect2) -> Vector2:
	var closest := pos.clamp(rect.position, rect.end)
	var d := pos - closest
	if d != Vector2.ZERO:
		var dist := d.length()
		return d / dist * (r - dist) if dist < r else Vector2.ZERO
	# The middle is inside the rectangle: leave by the nearest side.
	var left := pos.x - rect.position.x
	var right := rect.end.x - pos.x
	var up := pos.y - rect.position.y
	var down := rect.end.y - pos.y
	var m := minf(minf(left, right), minf(up, down))
	if m == left:
		return Vector2(-(left + r), 0.0)
	if m == right:
		return Vector2(right + r, 0.0)
	if m == up:
		return Vector2(0.0, -(up + r))
	return Vector2(0.0, down + r)
