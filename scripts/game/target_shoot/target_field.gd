extends RefCounted
## The targets of Target Shoot: the kinds, spawning, lifetimes and the hit test (REQ-TS-7 to 10). Pure logic: it draws
## nothing and uses no nodes, so the rules can be tested without a screen.
## A target position is in play-area units (0 to 1 on both axes), so the layout follows the screen (REQ-2D-2).
## Radii and distances are in pixels of the 1920x1080 screen. `k` turns them into pixels of the real play area.

const KINDS := {
	"standard": {"points": 10, "radius": 56.0, "life": 3.2, "weight": 60},
	"small": {"points": 25, "radius": 36.0, "life": 2.2, "weight": 25},
	"decoy": {"points": -15, "radius": 48.0, "life": 3.0, "weight": 15},
}
const KIND_ORDER := ["standard", "small", "decoy"]
const REF_AREA := Vector2(1800.0, 870.0)   # The play area at 1920x1080: the screen inside the 60 px margin, under the HUD.
const SPAWN_EVERY := 0.7
const MAX_BASE := 4          # Targets on the screen at the same time: this plus the number of players.
const MIN_SPACING := 160.0   # Minimum distance between two target centers.
const SPAWN_TRIES := 12
const GROW_TIME := 0.15
const HIT_SLOP := 8.0

class Target:
	var kind := ""
	var uv := Vector2.ZERO
	var radius := 0.0
	var points := 0
	var age := 0.0
	var life_left := 0.0

	## 0 to 1: how far the target has grown in (REQ-TS-12).
	func grow(grow_time: float) -> float:
		return clampf(age / grow_time, 0.0, 1.0)

var targets: Array[Target] = []

var _spawn_timer := SPAWN_EVERY   # The first target appears at once.


## Where the cursor is on the screen: `pointer` (-1 to 1 on both axes) mapped to the play area `area` (REQ-TS-3).
static func aim_to_screen(pointer: Vector2, area: Rect2) -> Vector2:
	var p := pointer.clamp(Vector2(-1, -1), Vector2(1, 1))
	return area.get_center() + p * area.size * 0.5


## The scale from reference pixels to the pixels of a real play area.
static func scale_for(area: Rect2) -> float:
	return minf(area.size.x / REF_AREA.x, area.size.y / REF_AREA.y)


static func max_targets(players: int) -> int:
	return MAX_BASE + players


## The center of a target on the screen.
static func center_of(t: Target, area: Rect2) -> Vector2:
	return area.position + t.uv * area.size


## Ages the targets, removes the ones that lived out their time (no points), and spawns new ones every SPAWN_EVERY.
## Returns the number of targets that expired.
func tick(dt: float, rng: RandomNumberGenerator, players: int) -> int:
	var expired := 0
	for i in range(targets.size() - 1, -1, -1):
		var t := targets[i]
		t.age += dt
		t.life_left -= dt
		if t.life_left <= 0.0:
			targets.remove_at(i)
			expired += 1
	_spawn_timer += dt
	while _spawn_timer >= SPAWN_EVERY:
		_spawn_timer -= SPAWN_EVERY
		spawn(rng, players)
	return expired


## Adds one target, or none when the screen is full or no free place is found in SPAWN_TRIES tries.
func spawn(rng: RandomNumberGenerator, players: int) -> Target:
	if targets.size() >= max_targets(players):
		return null
	var kind := _pick_kind(rng)
	var info: Dictionary = KINDS[kind]
	var r: float = info.radius
	for i in SPAWN_TRIES:
		var uv := Vector2(rng.randf_range(r / REF_AREA.x, 1.0 - r / REF_AREA.x),
				rng.randf_range(r / REF_AREA.y, 1.0 - r / REF_AREA.y))
		if _is_free(uv):
			var t := Target.new()
			t.kind = kind
			t.uv = uv
			t.radius = r
			t.points = info.points
			t.life_left = info.life
			targets.append(t)
			return t
	return null


## The target hit by a shot at `cursor` (screen pixels), or null (REQ-TS-10). The cursor must be inside the radius plus
## HIT_SLOP. When it is inside two targets, the nearer center is hit.
func hit(cursor: Vector2, area: Rect2) -> Target:
	var k := scale_for(area)
	var best: Target = null
	var best_d := INF
	for t in targets:
		var d := cursor.distance_to(center_of(t, area))
		if d <= (t.radius + HIT_SLOP) * k and d < best_d:
			best = t
			best_d = d
	return best


func take(t: Target) -> void:
	targets.erase(t)


func _is_free(uv: Vector2) -> bool:
	for t in targets:
		if ((t.uv - uv) * REF_AREA).length() < MIN_SPACING:
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
