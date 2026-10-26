extends RefCounted
## The rules of the tower of Tower Builder (REQ-TB-5 to 9), without a screen: where a brick lands, and which bricks fall.
## Everything is in the units of the 1920x1080 screen. A brick is {x, w, slot}: the middle, the width and the player that
## dropped it. Level 0 is the first brick on the base. The rule is simple and the same for everybody (REQ-GM-24):
##  - a brick lands on the top brick when the two overlap by at least MIN_OVERLAP, or it misses and falls beside the tower;
##  - a joint holds when the middle of the weight above it is over the brick below (plus SLACK). At the lowest joint that does
##    not hold, everything above it falls: one brick can knock off the bricks under it too.

const BRICK_H := 48.0            # A key object is 48 px high or more (REQ-GM-47e).
const BASE_X := 900.0            # The middle of the base, and of the tower.
const BASE_W := 560.0
const GROUND_Y := 840.0          # The top of the base.
const MIN_OVERLAP := 24.0        # A brick that overlaps the top brick by less misses it.
const SLACK := 8.0               # A joint holds a little beyond the edge of the brick below (REQ-TB-8).
const WIDTH_MIN := 170.0
const WIDTH_STEP := 10.0
const WIDTH_STEPS := 8           # The widths are WIDTH_MIN + k * WIDTH_STEP for k = 0 to WIDTH_STEPS.

const TOTAL_BRICKS := 12         # Bricks dropped in a game, shared by the players in turns (REQ-TB-3).
const TURN_TIMES := {"easy": 10.0, "medium": 5.0, "hard": 3.0}   # Seconds for one drop (REQ-TB-11).
const SWING_AMP := 380.0         # The brick on the crane swings this far to each side of the middle of the tower.
const SWING_PERIOD := 2.4        # Seconds for a full swing there and back.

enum Outcome { MISS, SAFE, TOPPLED }

var bricks: Array[Dictionary] = []


## The number of bricks that stand on the base.
func height() -> int:
	return bricks.size()


func clear() -> void:
	bricks.clear()


## The width of a new brick: one of nine, from `rng` (a seeded generator, so that a test makes the same bricks every time).
static func next_width(rng: RandomNumberGenerator) -> float:
	return WIDTH_MIN + WIDTH_STEP * float(rng.randi_range(0, WIDTH_STEPS))


## The top edge of the brick at `level` (0 = on the base).
static func level_top(level: int) -> float:
	return GROUND_Y - BRICK_H * float(level + 1)


## True when a brick of width `w` with its middle at `x` touches the top of the tower enough to land on it.
func lands(x: float, w: float) -> bool:
	var top_x := BASE_X if bricks.is_empty() else float(bricks[-1].x)
	var top_w := BASE_W if bricks.is_empty() else float(bricks[-1].w)
	return absf(x - top_x) < (w + top_w) * 0.5 - MIN_OVERLAP


## The lowest joint that does not hold: -1 is the base, 0 the first brick. Returns `bricks.size()` when the tower stands.
## The bricks above the joint are the ones that fall.
func weak_joint() -> int:
	for j in range(-1, bricks.size() - 1):
		var wsum := 0.0
		var xsum := 0.0
		for k in range(j + 1, bricks.size()):
			wsum += float(bricks[k].w)
			xsum += float(bricks[k].x) * float(bricks[k].w)
		var mid := xsum / wsum
		var bx := BASE_X if j < 0 else float(bricks[j].x)
		var bw := BASE_W if j < 0 else float(bricks[j].w)
		if absf(mid - bx) > bw * 0.5 + SLACK:
			return j
	return bricks.size()


## Drops a brick. Returns {outcome, level, fallen}: MISS (the brick falls beside the tower, `fallen` is empty), SAFE (it stays)
## or TOPPLED (the bricks above the weak joint, the new one included, are removed and listed in `fallen`; `level` is the level
## of the lowest of them). The dropped brick is never kept when the tower falls (REQ-TB-9).
func drop(x: float, w: float, slot: int) -> Dictionary:
	if not lands(x, w):
		return {"outcome": Outcome.MISS, "level": bricks.size(), "fallen": []}
	bricks.append({"x": x, "w": w, "slot": slot})
	var joint := weak_joint()
	if joint >= bricks.size():
		return {"outcome": Outcome.SAFE, "level": bricks.size() - 1, "fallen": []}
	var fallen: Array = bricks.slice(joint + 1)
	bricks.resize(joint + 1)
	return {"outcome": Outcome.TOPPLED, "level": joint + 1, "fallen": fallen}


## The seconds a player has for one drop at `difficulty` (an unknown value is Medium).
static func turn_time(difficulty: String) -> float:
	return float(TURN_TIMES.get(difficulty, TURN_TIMES.medium))


## The middle of the brick on the crane `t` seconds into the turn (REQ-TB-5): a smooth swing over the tower.
static func swing_x(t: float, phase: float) -> float:
	return BASE_X + SWING_AMP * sin(TAU * t / SWING_PERIOD + phase)
