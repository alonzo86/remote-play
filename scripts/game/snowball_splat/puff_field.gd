extends RefCounted
## The animals of Banana Party (the class is still called `Puff`): the kinds, the lanes, spawning, walking and the hit test
## (REQ-SS-7 to 10). Pure logic: it draws nothing and uses no nodes, so the rules can be tested without a screen.
## Positions are in pixels of the play area at 1920x1080 (`REF_AREA`). `center_of()` turns them into screen pixels.

## The kinds, one for each animal. `radius` is the hit circle. The speed of an animal is the speed of its lane, so a fast animal
## never catches a slow one (REQ-SS-8). The golden monkey is the bonus: it has its own speed (REQ-SS-23).
const KINDS := {
	"monkey": {"points": 25, "radius": 72.0},
	"lemur": {"points": 25, "radius": 72.0},
	"orangutan": {"points": 10, "radius": 80.0},
	"sloth": {"points": 10, "radius": 76.0},
	"gorilla": {"points": 10, "radius": 84.0},
	"elephant": {"points": 10, "radius": 96.0},
	"golden": {"points": 100, "radius": 72.0, "speed": 320.0},
}
const BONUS_KIND := "golden"
## The three lanes, far to near: small fast animals, medium animals, big animals. A lane has one direction and the animals
## that walk in it, so two animals of one lane never overlap (REQ-SS-8). `y` is the middle of the lane, `speed` is in px/s.
## `weight` is the
## chance of the lane when an animal comes (REQ-SS-9).
const LANES := [
	{"y": 490.0, "dir": 1, "speed": 160.0, "kinds": ["monkey", "lemur"], "weight": 30},
	{"y": 625.0, "dir": -1, "speed": 90.0, "kinds": ["orangutan", "sloth", "gorilla"], "weight": 35},
	{"y": 760.0, "dir": 1, "speed": 80.0, "kinds": ["elephant", "gorilla"], "weight": 35},
]
const REF_AREA := Vector2(1800.0, 870.0)   # The play area at 1920x1080: the screen inside the 60 px margin, under the HUD.
const SPAWN_EVERY := 1.5
const MAX_BASE := 3          # Animals on the screen at the same time: this plus the number of players (the bonus is extra).
const ENTRY_GAP := 380.0     # A new animal comes only when the one before it in the lane is this far from the edge.
const WAVE := 8.0            # The up and down bob of a walking animal (px) and the time of one step (s).
const WAVE_TIME := 0.6
const HIT_SLOP := 12.0
const BONUS_FIRST := 10.0    # The first bonus comes after this many seconds of play, then after BONUS_MIN to BONUS_MAX.
const BONUS_MIN := 14.0
const BONUS_MAX := 22.0
const BONUS_GAP := 200.0     # The bonus keeps this far behind an animal of its lane (px).
const BUSH_HALF_W := 150.0   # A bush hides the animals that walk behind it (REQ-SS-26). Half of its width (px).
const BUSH_MARGIN := 200.0   # The middle of a bush is at least this far from the edges of the play area ...
const BUSH_MIN_GAP := 420.0  # ... and the middles of two bushes of one lane are at least this far from each other.
## Difficulty (REQ-SS-20, 21): faster animals and fewer of them as it grows. `speed` is a factor on the speed of each kind,
## `max_base` is MAX_BASE, `spawn_every` is SPAWN_EVERY, `bushes` is the number of
## bushes (REQ-SS-26) and `tiers` are the medal tiers [bronze, silver, gold]. Medium is the
## game as it was. First guesses (Test 10).
const LEVELS := {
	"easy": {"speed": 0.7, "max_base": 4, "spawn_every": 1.2, "bushes": 3, "tiers": [170, 340, 510]},
	"medium": {"speed": 1.0, "max_base": MAX_BASE, "spawn_every": SPAWN_EVERY, "bushes": 5, "tiers": [150, 300, 450]},
	"hard": {"speed": 1.5, "max_base": 2, "spawn_every": 2.0, "bushes": 8, "tiers": [120, 240, 360]},
}

class Puff:
	var kind := ""
	var lane := 0
	var dir := 1
	var x := 0.0           # Middle of the animal in px of the play area (1920x1080). It starts outside the edge.
	var lane_y := 0.0
	var radius := 0.0
	var speed := 0.0
	var points := 0
	var age := 0.0

	## The height in px of the play area: the lane and the bob of the steps.
	func y() -> float:
		return lane_y - WAVE * absf(sin(age * PI / WAVE_TIME))

	func is_gone() -> bool:
		return x > REF_AREA.x + radius + 2.0 if dir > 0 else x < -radius - 2.0

## A bush stands in a lane. An animal that walks behind it is hidden and a banana cannot reach it (REQ-SS-26).
class Bush:
	var lane := 0
	var x := 0.0   # The middle of the bush in px of the play area.

var puffs: Array[Puff] = []
var bushes: Array[Bush] = []
var _bush_count := 5

var _speed := 1.0
var _max_base := MAX_BASE
var _spawn_every := SPAWN_EVERY
var _spawn_timer := SPAWN_EVERY   # The first animal comes at once.
var _bonus_timer := BONUS_FIRST   # Seconds until the next bonus.


## Sets the difficulty (a value of `LEVELS`). An unknown id gives Medium.
func setup(difficulty: String) -> void:
	var level: Dictionary = LEVELS.get(difficulty, LEVELS.medium)
	_speed = float(level.speed)
	_max_base = int(level.max_base)
	_spawn_every = float(level.spawn_every)
	_bush_count = int(level.bushes)
	_spawn_timer = _spawn_every
	_bonus_timer = BONUS_FIRST


## Places the bushes of a round: the number of the difficulty, spread over the lanes (the middle lane first, then far, then near),
## and over the width of each lane with a little random shift, never closer than BUSH_MIN_GAP in one lane (REQ-SS-26).
func place_bushes(rng: RandomNumberGenerator) -> void:
	bushes.clear()
	var order := [1, 0, 2]
	var per_lane := [0, 0, 0]
	for i in _bush_count:
		per_lane[order[i % 3]] += 1
	for lane in 3:
		var n: int = per_lane[lane]
		var span := REF_AREA.x - 2.0 * BUSH_MARGIN
		for k in n:
			var step := span / float(n)
			var slot := step * (float(k) + 0.5)
			var shift := rng.randf_range(-0.2, 0.2) * maxf(step - BUSH_MIN_GAP, 0.0)   # Never closer than BUSH_MIN_GAP.
			var b := Bush.new()
			b.lane = lane
			b.x = BUSH_MARGIN + slot + (shift if n > 1 else rng.randf_range(-0.25, 0.25) * span)
			bushes.append(b)


## True when the animal walks behind a bush of its lane: its middle is inside the bush, less half of its own radius.
func is_hidden(p: Puff) -> bool:
	for b in bushes:
		if b.lane == p.lane and absf(p.x - b.x) <= BUSH_HALF_W - p.radius * 0.5:
			return true
	return false


## Where the cursor is on the screen: `pointer` (-1 to 1 on both axes) mapped to the play area `area` (REQ-SS-3).
static func aim_to_screen(pointer: Vector2, area: Rect2) -> Vector2:
	var p := pointer.clamp(Vector2(-1, -1), Vector2(1, 1))
	return area.get_center() + p * area.size * 0.5


## The scale from reference pixels to the pixels of a real play area (for the sizes).
static func scale_for(area: Rect2) -> float:
	return minf(area.size.x / REF_AREA.x, area.size.y / REF_AREA.y)


static func max_puffs(players: int, base := MAX_BASE) -> int:
	return base + players


## The center of a Puff on the screen.
static func center_of(p: Puff, area: Rect2) -> Vector2:
	return area.position + Vector2(p.x, p.y()) * (area.size / REF_AREA)


## Moves the animals, removes the ones that walked out of the other edge (no points, no loss), and brings a new one every
## `spawn_every` of the difficulty (SPAWN_EVERY at Medium). The bonus comes by itself, first after BONUS_FIRST seconds and then
## after BONUS_MIN to BONUS_MAX (REQ-SS-23). Returns the number of animals that walked away.
func tick(dt: float, rng: RandomNumberGenerator, players: int) -> int:
	var away := 0
	for i in range(puffs.size() - 1, -1, -1):
		var p := puffs[i]
		p.age += dt
		p.x += p.dir * p.speed * dt
		if p.is_gone():
			puffs.remove_at(i)
			away += 1
	_spawn_timer += dt
	while _spawn_timer >= _spawn_every:
		_spawn_timer -= _spawn_every
		spawn(rng, players)
	_bonus_timer -= dt
	if _bonus_timer <= 0.0:
		if spawn_bonus(rng) != null:
			_bonus_timer = rng.randf_range(BONUS_MIN, BONUS_MAX)
		else:
			_bonus_timer = 1.0   # No lane is free or the bonus is still on the screen: try again soon.
	return away


## Adds one animal, or none when the screen is full or the lanes are not free. The lane is chosen with the lane weights among
## the free lanes, then the animal of the lane (REQ-SS-9).
func spawn(rng: RandomNumberGenerator, players: int) -> Puff:
	if _regular_count() >= max_puffs(players, _max_base):
		return null
	var free: Array[int] = []
	var total := 0
	for i in LANES.size():
		if _lane_is_free(i):
			free.append(i)
			total += int(LANES[i].weight)
	if free.is_empty():
		return null
	var roll := rng.randi_range(0, total - 1)
	var lane: int = free[free.size() - 1]
	for i in free:
		roll -= int(LANES[i].weight)
		if roll < 0:
			lane = i
			break
	var kinds: Array = LANES[lane].kinds
	return _add(lane, kinds[rng.randi_range(0, kinds.size() - 1)])


## Adds the golden monkey in a lane where it cannot run into an animal, or none when one is on the screen already or no lane
## is safe (REQ-SS-23). The bonus is faster than the others, so a lane is safe when every animal in it will be out of the screen
## before the bonus can reach it.
func spawn_bonus(rng: RandomNumberGenerator) -> Puff:
	for p in puffs:
		if p.kind == BONUS_KIND:
			return null
	var safe: Array[int] = []
	for i in LANES.size():
		if _lane_is_free(i) and _bonus_is_safe(i):
			safe.append(i)
	if safe.is_empty():
		return null
	return _add(safe[rng.randi_range(0, safe.size() - 1)], BONUS_KIND)


## True when the bonus that comes in at the edge of `lane` does not catch any animal of the lane before it walks out. An animal
## that has walked `walked` px of the length `span` with the speed `v` leaves after `(span - walked) / v` s. The bonus reaches
## it (up to BONUS_GAP px behind) after `(walked - BONUS_GAP) / (bonus speed - v)` s. It is safe when that is later.
func _bonus_is_safe(lane: int) -> bool:
	var bonus_speed: float = float(KINDS[BONUS_KIND].speed) * _speed
	for p in puffs:
		if p.lane != lane:
			continue
		var span := REF_AREA.x + 2.0 * p.radius
		var walked := p.x + p.radius if p.dir > 0 else REF_AREA.x + p.radius - p.x
		var catch_in := (walked - BONUS_GAP) / maxf(bonus_speed - p.speed, 1.0)
		if catch_in <= (span - walked) / p.speed:
			return false
	return true


func _add(lane: int, kind: String) -> Puff:
	var info: Dictionary = KINDS[kind]
	var p := Puff.new()
	p.kind = kind
	p.lane = lane
	p.dir = LANES[lane].dir
	p.lane_y = LANES[lane].y
	p.radius = info.radius
	p.speed = float(info.get("speed", LANES[lane].speed)) * _speed
	p.points = info.points
	p.x = -p.radius if p.dir > 0 else REF_AREA.x + p.radius
	puffs.append(p)
	return p


## The number of animals without the bonus.
func _regular_count() -> int:
	var n := 0
	for p in puffs:
		if p.kind != BONUS_KIND:
			n += 1
	return n


## The animal hit by a banana that lands at `point` (screen pixels), or null (REQ-SS-10). The point must be inside the radius
## plus HIT_SLOP. An animal behind a bush is not hit. When it is inside two, the nearer center is hit.
func hit(point: Vector2, area: Rect2) -> Puff:
	var k := scale_for(area)
	var best: Puff = null
	var best_d := INF
	for p in puffs:
		if is_hidden(p):
			continue
		var d := point.distance_to(center_of(p, area))
		if d <= (p.radius + HIT_SLOP) * k and d < best_d:
			best = p
			best_d = d
	return best


func take(p: Puff) -> void:
	puffs.erase(p)


## A lane is free when no animal of it is near its entry edge. The entry of the biggest animal of the lane counts, so that
## any animal of the lane can come in.
func _lane_is_free(lane: int) -> bool:
	var radius := 0.0
	for k in LANES[lane].kinds:
		radius = maxf(radius, float(KINDS[k].radius))
	radius = maxf(radius, float(KINDS[BONUS_KIND].radius))
	var entry_x := -radius if LANES[lane].dir > 0 else REF_AREA.x + radius
	for p in puffs:
		if p.lane == lane and absf(p.x - entry_x) < ENTRY_GAP:
			return false
	return true
