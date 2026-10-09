extends RefCounted
## The Puffs of Snowball Splat: the kinds, the lanes, spawning, flying and the hit test (REQ-SS-7 to 10). Pure logic: it draws
## nothing and uses no nodes, so the rules can be tested without a screen.
## Positions are in pixels of the play area at 1920x1080 (`REF_AREA`). `center_of()` turns them into screen pixels.

## The kinds. `speed` is in px/s. `weight` is the chance of a kind when a Puff comes (REQ-SS-9).
const KINDS := {
	"puff": {"points": 10, "radius": 100.0, "speed": 100.0, "weight": 70},
	"little": {"points": 25, "radius": 72.0, "speed": 160.0, "weight": 30},
}
const KIND_ORDER := ["puff", "little"]
## One lane has one kind and one direction, so two Puffs of a lane never overlap (REQ-SS-8). `y` is the middle of the lane.
const LANES := [
	{"y": 150.0, "dir": 1, "kind": "little"},
	{"y": 365.0, "dir": -1, "kind": "puff"},
	{"y": 580.0, "dir": 1, "kind": "puff"},
]
const COLOR_COUNT := 3   # A Puff has one of 3 colors. The game knows them.
const REF_AREA := Vector2(1800.0, 870.0)   # The play area at 1920x1080: the screen inside the 60 px margin, under the HUD.
const SPAWN_EVERY := 1.5
const MAX_BASE := 3          # Puffs on the screen at the same time: this plus the number of players.
const ENTRY_GAP := 380.0     # A new Puff comes only when the one before it in the lane is this far from the edge.
const WAVE := 28.0           # The up and down wave of a flying Puff (px) and the time of one wave (s).
const WAVE_TIME := 2.4
const HIT_SLOP := 12.0

class Puff:
	var kind := ""
	var lane := 0
	var dir := 1
	var x := 0.0           # Middle of the Puff in px of the play area (1920x1080). It starts outside the edge.
	var lane_y := 0.0
	var radius := 0.0
	var speed := 0.0
	var points := 0
	var color_index := 0
	var age := 0.0

	## The height in px of the play area: the lane and the wave.
	func y() -> float:
		return lane_y + WAVE * sin(age * TAU / WAVE_TIME)

	func is_gone() -> bool:
		return x > REF_AREA.x + radius + 2.0 if dir > 0 else x < -radius - 2.0

var puffs: Array[Puff] = []

var _spawn_timer := SPAWN_EVERY   # The first Puff comes at once.


## Where the cursor is on the screen: `pointer` (-1 to 1 on both axes) mapped to the play area `area` (REQ-SS-3).
static func aim_to_screen(pointer: Vector2, area: Rect2) -> Vector2:
	var p := pointer.clamp(Vector2(-1, -1), Vector2(1, 1))
	return area.get_center() + p * area.size * 0.5


## The scale from reference pixels to the pixels of a real play area (for the sizes).
static func scale_for(area: Rect2) -> float:
	return minf(area.size.x / REF_AREA.x, area.size.y / REF_AREA.y)


static func max_puffs(players: int) -> int:
	return MAX_BASE + players


## The center of a Puff on the screen.
static func center_of(p: Puff, area: Rect2) -> Vector2:
	return area.position + Vector2(p.x, p.y()) * (area.size / REF_AREA)


## Moves the Puffs, removes the ones that flew out of the other edge (no points, no loss), and brings a new one every
## SPAWN_EVERY. Returns the number of Puffs that flew away.
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
	while _spawn_timer >= SPAWN_EVERY:
		_spawn_timer -= SPAWN_EVERY
		spawn(rng, players)
	return away


## Adds one Puff, or none when the screen is full or the lanes of the chosen kind are not free.
func spawn(rng: RandomNumberGenerator, players: int) -> Puff:
	if puffs.size() >= max_puffs(players):
		return null
	var kind := _pick_kind(rng)
	var free: Array[int] = []
	for i in LANES.size():
		if LANES[i].kind == kind and _lane_is_free(i):
			free.append(i)
	if free.is_empty():
		return null
	var lane: int = free[rng.randi_range(0, free.size() - 1)]
	var info: Dictionary = KINDS[kind]
	var p := Puff.new()
	p.kind = kind
	p.lane = lane
	p.dir = LANES[lane].dir
	p.lane_y = LANES[lane].y
	p.radius = info.radius
	p.speed = info.speed
	p.points = info.points
	p.color_index = rng.randi_range(0, COLOR_COUNT - 1)
	p.x = -p.radius if p.dir > 0 else REF_AREA.x + p.radius
	puffs.append(p)
	return p


## The Puff hit by a snowball that lands at `point` (screen pixels), or null (REQ-SS-10). The point must be inside the radius
## plus HIT_SLOP. When it is inside two, the nearer center is hit.
func hit(point: Vector2, area: Rect2) -> Puff:
	var k := scale_for(area)
	var best: Puff = null
	var best_d := INF
	for p in puffs:
		var d := point.distance_to(center_of(p, area))
		if d <= (p.radius + HIT_SLOP) * k and d < best_d:
			best = p
			best_d = d
	return best


func take(p: Puff) -> void:
	puffs.erase(p)


func _lane_is_free(lane: int) -> bool:
	var radius: float = KINDS[LANES[lane].kind].radius
	var entry_x := -radius if LANES[lane].dir > 0 else REF_AREA.x + radius
	for p in puffs:
		if p.lane == lane and absf(p.x - entry_x) < ENTRY_GAP:
			return false
	return true


func _pick_kind(rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in KIND_ORDER:
		total += int(KINDS[k].weight)
	var roll := rng.randi_range(0, total - 1)
	for k in KIND_ORDER:
		roll -= int(KINDS[k].weight)
		if roll < 0:
			return k
	return KIND_ORDER[0]
