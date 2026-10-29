extends RefCounted
## The rules of the rink of Bumper Cars (REQ-BC-3 to 10, 20): the size of the rink, the stars on the floor and how they come
## and go, whether a bump is a hit and who picks up a star. Pure logic: it draws nothing and it knows no players, only positions.
## Units are px of the 1920x1080 simulation (the drawing scales them).

const CAR_R := 48.0
const STAR_R := 28.0
const PICKUP_R := CAR_R + STAR_R         # A car picks up a star when its middle is this close (REQ-BC-10).
const RAIL_BOUNCE := 0.6                 # The part of the speed that a car keeps after a bounce at the rail (REQ-BC-4).
const RESTITUTION := 0.9                 # Close to 1: a hit pushes the other car away (REQ-BC-5).
const HIT_SPEED := 250.0                 # The speed of two cars towards each other that makes a hit (REQ-BC-6).
const HIT_GAP := 0.6                     # The least time between two hits of the same pair (REQ-BC-7).
const SPAWN_EVERY := 0.6                 # A new star comes this often while the floor has too few (REQ-BC-9).
const SPAWN_CLEAR := 120.0               # A new star is this far from every car and from the rail.
const SPAWN_BLINK := 0.4
const STAR_GAP := 90.0                   # A new star is this far from the other stars when there is room.
const START_SHARE := 0.28                # The cars start at this part of the half height from the middle.
## The largest rink: the screen inside the margin, under the HUD and the tent (REQ-BC-16, 20).
const LARGEST := Rect2(72.0, 224.0, 1776.0, 784.0)
const PIXEL := 4.0
## Difficulty (REQ-BC-20): the size of the rink (a share of the largest) and the stars on the floor. First guesses (Test 32).
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


## One tick of `dt` seconds: a new star comes when the floor has too few (REQ-BC-9).
## `cars` is the list of the positions of the cars.
func tick(dt: float, cars: Array, rng: RandomNumberGenerator) -> void:
	for s in stars:
		s.blink = maxf(float(s.blink) - dt, 0.0)
	if stars.size() >= star_count:
		_spawn_wait = 0.0
		return
	_spawn_wait += dt
	if _spawn_wait >= SPAWN_EVERY:
		_spawn_wait = 0.0
		_add_random(cars, rng, SPAWN_BLINK)


## A star at a random place at least SPAWN_CLEAR from the rail and from every car, and STAR_GAP from the other stars when that
## fits.
func _add_random(cars: Array, rng: RandomNumberGenerator, blink: float) -> void:
	var area := rink.grow(-SPAWN_CLEAR)
	var p := area.get_center()
	for attempt in 30:
		p = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if _is_clear(p, cars, STAR_GAP if attempt < 20 else 0.0):
			break
	stars.append({"pos": p, "blink": blink})


func _is_clear(p: Vector2, cars: Array, star_gap: float) -> bool:
	for c in cars:
		if (c as Vector2).distance_to(p) < SPAWN_CLEAR:
			return false
	for s in stars:
		if (s.pos as Vector2).distance_to(p) < star_gap:
			return false
	return true


## The stars that cars pick up now (REQ-BC-10): a list of `[car_index, star_index]`. A star that two cars reach is picked up
## by the nearer one, and a car picks up all the stars that it reaches.
func pickups(cars: Array) -> Array:
	var out: Array = []
	for i in stars.size():
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


## True when a bump of two cars is a hit (REQ-BC-6): the speeds of the two cars towards each other, from their positions and
## velocities before the bounce, add up to HIT_SPEED or more. A hit is a bonk with a spark and a buzz; nobody loses a star
## (REQ-BC-7).
static func is_hit(pos_a: Vector2, vel_a: Vector2, pos_b: Vector2, vel_b: Vector2) -> bool:
	var d := pos_b - pos_a
	var n := d.normalized() if d.length() > 0.001 else Vector2.RIGHT
	var towards_b := vel_a.dot(n)      # How fast a goes towards b.
	var towards_a := -vel_b.dot(n)     # How fast b goes towards a.
	return towards_b + towards_a >= HIT_SPEED
