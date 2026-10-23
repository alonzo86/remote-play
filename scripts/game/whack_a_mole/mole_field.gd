extends RefCounted
## The moles of Whack-a-Mole: the holes, spawning, popping up and down, and the hit test (REQ-WM-6 to 9). Pure logic: it draws
## nothing and uses no nodes, so the rules can be tested without a screen.
## Positions are in pixels of the play area at 1920x1080 (`REF_AREA`). `hole_pos()` and `head_pos()` turn them into screen pixels.

const REF_AREA := Vector2(1800.0, 870.0)   # The play area at 1920x1080: the screen inside the 60 px margin, under the HUD.
const COLS := [1.0 / 6.0, 0.5, 5.0 / 6.0]  # Shares of the width, the middle of each column.
const ROWS := [0.30, 0.62, 0.94]           # Shares of the height, the middle of the hole of each row.
const RISE_TIME := 0.25
const DOWN_TIME := 0.25
const HIT_LIFE := 0.8
const PICTURE_H := 168.0     # The height of the picture of a mole (px at 1920x1080): 42 world pixels of 4 px.
const HEAD_FROM_TOP := 84.0  # The middle of the head is this far under the top of the picture.
const HIT_SLOP := 12.0
const POINTS := 10
const GOLDEN_POINTS := 50
const GOLDEN_STAY := 0.7     # The golden mole stays up for this share of `stay`.
const BONUS_FIRST := 10.0    # The first golden mole comes after this many seconds of play, then after BONUS_MIN to BONUS_MAX.
const BONUS_MIN := 14.0
const BONUS_MAX := 22.0
const MAX_OUT := 6           # Never more moles out than this.
## Difficulty (REQ-WM, settings): `stay` is how long a mole stays up, `spawn_every` the time between two new moles, `max_base` the
## moles out at the same time (plus the number of players), `radius` the hit circle (px at 1920x1080). Medium is the base.
## First guesses (Test 28).
const LEVELS := {
	"easy": {"stay": 2.6, "spawn_every": 1.4, "max_base": 2, "radius": 100.0},
	"medium": {"stay": 1.8, "spawn_every": 1.0, "max_base": 2, "radius": 84.0},
	"hard": {"stay": 1.1, "spawn_every": 0.7, "max_base": 3, "radius": 72.0},
}

class Mole:
	var hole := 0
	var golden := false
	var stay := 1.8
	var age := 0.0            # Seconds since the mole came up.
	var hit_age := -1.0       # Seconds since it was hit, or -1.

	func is_hit() -> bool:
		return hit_age >= 0.0

	func points() -> int:
		return GOLDEN_POINTS if golden else POINTS

	## How far out of its hole the mole is: 0 (hidden) to 1 (fully up).
	func out() -> float:
		if is_hit():
			return 1.0
		if age < RISE_TIME:
			return age / RISE_TIME
		if age < RISE_TIME + stay:
			return 1.0
		return clampf(1.0 - (age - RISE_TIME - stay) / DOWN_TIME, 0.0, 1.0)

	func is_done() -> bool:
		return hit_age >= HIT_LIFE if is_hit() else age >= RISE_TIME + stay + DOWN_TIME

var level := LEVELS.medium
var moles: Array[Mole] = []
var _spawn_left := 0.0       # Seconds until the next mole. The first one comes at once.
var _bonus_left := BONUS_FIRST
var _time := 0.0


func setup(difficulty: String) -> void:
	level = LEVELS.get(difficulty, LEVELS.medium)
	moles.clear()
	_spawn_left = 0.0
	_bonus_left = BONUS_FIRST
	_time = 0.0


## The most moles (not counting the golden one) that are out at the same time (REQ-WM-9).
func max_out(players: int) -> int:
	return mini(int(level.max_base) + players, MAX_OUT)


func tick(delta: float, rng: RandomNumberGenerator, players: int) -> void:
	_time += delta
	for m in moles:
		if m.is_hit():
			m.hit_age += delta
		else:
			m.age += delta
	moles = moles.filter(func(m: Mole) -> bool: return not m.is_done())
	_bonus_left -= delta
	if _bonus_left <= 0.0:
		var gold_hole := _free_hole(rng)
		if gold_hole >= 0:
			_add(gold_hole, true)
			_bonus_left = rng.randf_range(BONUS_MIN, BONUS_MAX)
	_spawn_left -= delta
	if _spawn_left <= 0.0 and normal_count() < max_out(players):
		var hole := _free_hole(rng)
		if hole >= 0:
			_add(hole, false)
			_spawn_left = float(level.spawn_every)


func normal_count() -> int:
	var n := 0
	for m in moles:
		if not m.golden:
			n += 1
	return n


func _add(hole: int, golden: bool) -> void:
	var m := Mole.new()
	m.hole = hole
	m.golden = golden
	m.stay = float(level.stay) * (GOLDEN_STAY if golden else 1.0)
	moles.append(m)


## A random hole with no mole, or -1.
func _free_hole(rng: RandomNumberGenerator) -> int:
	var free: Array[int] = []
	for h in COLS.size() * ROWS.size():
		var taken := false
		for m in moles:
			if m.hole == h:
				taken = true
		if not taken:
			free.append(h)
	return free[rng.randi() % free.size()] if not free.is_empty() else -1


# ---- Places ----

## The scale from reference pixels to the pixels of a real play area (for the sizes).
static func scale_for(area: Rect2) -> float:
	return minf(area.size.x / REF_AREA.x, area.size.y / REF_AREA.y)


## The middle of hole `hole` (0 to 8, row by row) in screen pixels.
static func hole_pos(hole: int, area: Rect2) -> Vector2:
	return area.position + Vector2(float(COLS[hole % 3]) * area.size.x, float(ROWS[floori(hole / 3.0)]) * area.size.y)


## The middle of the head of `m` in screen pixels: the top of the picture rises out of the hole with the mole.
static func head_pos(m: Mole, area: Rect2) -> Vector2:
	return hole_pos(m.hole, area) - Vector2(0.0, (PICTURE_H * m.out() - HEAD_FROM_TOP) * scale_for(area))


# ---- Hits ----

## A mole can be hit when it is more than half out of its hole and was not hit yet (REQ-WM-7).
static func is_hittable(m: Mole) -> bool:
	return not m.is_hit() and m.out() > 0.5


## The mole that a bonk at `point` hits, or null (REQ-WM-7): the hittable mole with the nearest head whose circle holds the point.
func hit(point: Vector2, area: Rect2) -> Mole:
	var k := scale_for(area)
	var best: Mole = null
	var best_d := INF
	for m in moles:
		if not is_hittable(m):
			continue
		var d := point.distance_to(head_pos(m, area))
		if d <= (float(level.radius) + HIT_SLOP) * k and d < best_d:
			best = m
			best_d = d
	return best


## The mole is taken: it starts its happy animation and cannot be hit again.
func take(m: Mole) -> void:
	m.hit_age = 0.0
