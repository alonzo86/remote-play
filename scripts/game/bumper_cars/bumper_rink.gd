extends RefCounted
## The rules of the rink of Bumper Cars (REQ-BC-3 to 10, 20): the size of the rink, the stars on the floor and how they come
## and go, who is hit in a bump and who picks up a star. Pure logic: it draws nothing and it knows no players, only positions.
## Units are px of the 1920x1080 simulation (the drawing scales them).

const CAR_R := 48.0
const STAR_R := 28.0
const PICKUP_R := CAR_R + STAR_R         # A car picks up a star when its middle is this close (REQ-BC-10).
const RAIL_BOUNCE := 0.6                 # The part of the speed that a car keeps after a bounce at the rail (REQ-BC-4).
const RESTITUTION := 0.9                 # Close to 1: a hit pushes the other car away (REQ-BC-5).
const HIT_SPEED := 250.0                 # The speed of two cars towards each other that makes a hit (REQ-BC-6).
const HIT_TIE := 40.0                    # Two speeds this close make a tie: both cars are hit (REQ-BC-7).
const HIT_GAP := 0.6                     # The least time between two hits of the same pair (REQ-BC-7).
const DROP_DISTANCE := 110.0             # A dropped star rolls this far, in DROP_TIME (REQ-BC-8).
const DROP_TIME := 0.35
const DROP_LOCK := 0.5                   # A dropped star cannot be picked up in this time (REQ-BC-8).
const SPAWN_EVERY := 0.6                 # A new star comes this often while the floor has too few (REQ-BC-9).
const SPAWN_CLEAR := 120.0               # A new star is this far from every car and from the rail.
const SPAWN_BLINK := 0.4
const STAR_GAP := 90.0                   # A new star is this far from the other stars when there is room.
const START_SHARE := 0.28                # The cars start at this part of the half height from the middle.
## The largest rink: the screen inside the margin, under the HUD and the tent (REQ-BC-16, 20).
const LARGEST := Rect2(72.0, 224.0, 1776.0, 784.0)
const PIXEL := 4.0
## Difficulty (REQ-BC-20): the size of the rink (a share of the largest) and the stars on the floor. First guesses (Test 30).
const LEVELS := {
	"easy": {"size": 1.0, "stars": 12},
	"medium": {"size": 0.9, "stars": 9},
	"hard": {"size": 0.8, "stars": 6},
}

var rink := LARGEST
var star_count := 9
## {pos, vel, move, lock, blink}: `move` is the time the star still rolls, `lock` how long it waits.
var stars: Array[Dictionary] = []
var _spawn_wait := 0.0


## Sets the difficulty (a key of `LEVELS`; an unknown one gives Medium) and clears the floor.
func setup(difficulty: String) -> void:
	var level: Dictionary = LEVELS.get(difficulty, LEVELS.medium)
	star_count = int(level.stars)
	var size := LARGEST.size * float(level.size)
	size = (size / PIXEL).floor() * PIXEL   # The rink is on the grid of world pixels.
	rink = Rect2(((LARGEST.get_center() - size * 0.5) / PIXEL).round() * PIXEL, size)
	stars.clear()
	_spawn_wait = 0.0


## The start places of `count` cars on a circle around the middle, the first at the top (REQ-BC-3).
func start_spots(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var r := rink.size.y * 0.5 * (1.0 - START_SHARE)
	for i in count:
		var a := -PI * 0.5 + TAU * float(i) / float(maxi(count, 1))
		out.append(rink.get_center() + Vector2(cos(a), sin(a)) * r)
	return out


## The part of the rink where a car can be: its whole disk inside the rail.
func car_bounds() -> Rect2:
	return rink


## A start: the floor gets all its stars at once, away from the cars (REQ-BC-9).
func fill(cars: Array, rng: RandomNumberGenerator) -> void:
	stars.clear()
	while stars.size() < star_count:
		_add_random(cars, rng, 0.0)


## One tick of `dt` seconds: the dropped stars roll and wait, and a new star comes when the floor has too few (REQ-BC-8, 9).
## `cars` is the list of the positions of the cars.
func tick(dt: float, cars: Array, rng: RandomNumberGenerator) -> void:
	var inner := rink.grow(-STAR_R)
	for s in stars:
		s.lock = maxf(float(s.lock) - dt, 0.0)
		s.blink = maxf(float(s.blink) - dt, 0.0)
		if float(s.move) > 0.0:
			var step := minf(dt, float(s.move))
			s.pos = _clamp_to(inner, (s.pos as Vector2) + (s.vel as Vector2) * step)
			s.move = float(s.move) - step
	if stars.size() >= star_count:
		_spawn_wait = 0.0
		return
	_spawn_wait += dt
	if _spawn_wait >= SPAWN_EVERY:
		_spawn_wait = 0.0
		_add_random(cars, rng, SPAWN_BLINK)


static func _clamp_to(area: Rect2, p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, area.position.x, area.end.x), clampf(p.y, area.position.y, area.end.y))


## A star at a random place at least SPAWN_CLEAR from the rail and from every car, and STAR_GAP from the other stars when that
## fits.
func _add_random(cars: Array, rng: RandomNumberGenerator, blink: float) -> void:
	var area := rink.grow(-SPAWN_CLEAR)
	var p := area.get_center()
	for attempt in 30:
		p = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if _is_clear(p, cars, STAR_GAP if attempt < 20 else 0.0):
			break
	stars.append({"pos": p, "vel": Vector2.ZERO, "move": 0.0, "lock": 0.0, "blink": blink})


func _is_clear(p: Vector2, cars: Array, star_gap: float) -> bool:
	for c in cars:
		if (c as Vector2).distance_to(p) < SPAWN_CLEAR:
			return false
	for s in stars:
		if (s.pos as Vector2).distance_to(p) < star_gap:
			return false
	return true


## A car at `from` was hit by a car at `other`: a star leaves it in the direction away from the other car (REQ-BC-8).
func drop_star(from: Vector2, other: Vector2) -> void:
	var away := (from - other).normalized() if from.distance_to(other) > 0.001 else Vector2.RIGHT
	stars.append({"pos": from, "vel": away * DROP_DISTANCE / DROP_TIME, "move": DROP_TIME, "lock": DROP_LOCK, "blink": 0.0})


## The stars that cars pick up now (REQ-BC-10): a list of `[car_index, star_index]`. A star that two cars reach is picked up
## by the nearer one, and a car picks up all the stars that it reaches. A star that is locked (just dropped) is not picked up.
func pickups(cars: Array) -> Array:
	var out: Array = []
	for i in stars.size():
		if float(stars[i].lock) > 0.0:
			continue
		var best := -1
		var best_d := PICKUP_R
		for j in cars.size():
			var d := (cars[j] as Vector2).distance_to(stars[i].pos)
			if d < best_d:
				best_d = d
				best = j
		if best >= 0:
			out.append([best, i])
	return out


## Removes the stars with these indexes (a list from `pickups()`).
func remove_stars(indexes: Array) -> void:
	var sorted := indexes.duplicate()
	sorted.sort()
	sorted.reverse()
	for i in sorted:
		stars.remove_at(int(i))


## True when the two cars touch.
static func touching(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < CAR_R * 2.0


## A bump of two cars, with their positions and velocities before the bounce (REQ-BC-6, 7). Returns `{hit, a, b}`: `hit` is true
## when the two speeds towards each other add up to HIT_SPEED or more; `a` and `b` say which cars were hit: the one that moves
## towards the other more slowly, or both when the two speeds are within HIT_TIE.
static func bump(pos_a: Vector2, vel_a: Vector2, pos_b: Vector2, vel_b: Vector2) -> Dictionary:
	var d := pos_b - pos_a
	var n := d.normalized() if d.length() > 0.001 else Vector2.RIGHT
	var sa := vel_a.dot(n)      # How fast a goes towards b.
	var sb := -vel_b.dot(n)     # How fast b goes towards a.
	if sa + sb < HIT_SPEED:
		return {"hit": false, "a": false, "b": false}
	if absf(sa - sb) < HIT_TIE:
		return {"hit": true, "a": true, "b": true}
	return {"hit": true, "a": sa < sb, "b": sb < sa}
