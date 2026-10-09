extends RefCounted
## The rules of the platform of Sumo Bumpers (REQ-SB-2, 3, 6, 7, 10): the platform that shrinks, who has fallen, where the
## bumpers start, the dash, and who wins a round. Pure logic: it draws nothing.
## Positions are in px with the middle of the platform at (0, 0).

const BUMPER_R := 34.0
const MIN_RADIUS := 30.0         # At this radius two bumpers do not fit, so every round ends (REQ-SB-6).
const START_SHARE := 0.55        # The bumpers start at this part of the start radius from the middle.
const DASH_SPEED := 700.0        # px/s (REQ-SB-10).
const BUMP_RESTITUTION := 0.95   # Close to 1: a hit pushes the other bumper away (REQ-SB-8).
const BUMP_BUZZ_SPEED := 300.0   # The speed between two bumpers that buzzes the phones (REQ-SB-8).
## After the first fall of a round the platform shrinks this many times faster, so a bumper that fell waits at most
## `shrink_time / FALL_SPEEDUP` seconds (REQ-SB-6, REQ-SB-9). REQ-GM-83 asks for about 20 s at most (MAX_WAIT).
const FALL_SPEEDUP := 2.0
const MAX_WAIT := 20.0
## Difficulty (REQ-SB-20): the start radius of the platform, the time it needs to shrink to MIN_RADIUS, and the time before the
## dash is ready again. First guesses (Test 15).
const LEVELS := {
	"easy": {"radius": 430.0, "shrink": 30.0, "dash": 1.5},
	"medium": {"radius": 380.0, "shrink": 24.0, "dash": 2.0},
	"hard": {"radius": 330.0, "shrink": 18.0, "dash": 2.5},
}

var start_radius := 380.0
var shrink_time := 24.0
var dash_time := 2.0
var time := 0.0   # The time of the shrinking in this round: seconds since GO, but faster after the first fall.
var speedup := 1.0


## Sets the difficulty (a key of `LEVELS`). An unknown one gives Medium.
func setup(difficulty: String) -> void:
	var level: Dictionary = LEVELS.get(difficulty, LEVELS.medium)
	start_radius = float(level.radius)
	shrink_time = float(level.shrink)
	dash_time = float(level.dash)
	time = 0.0
	speedup = 1.0


func tick(dt: float) -> void:
	time += dt * speedup


## The first bumper of the round has fallen: from now on the platform shrinks faster (REQ-SB-6). It does it only once.
func speed_up() -> void:
	speedup = FALL_SPEEDUP


## The longest time a bumper that fell has to wait for the end of the round (REQ-SB-9): the whole shrinking at the fast rate.
func longest_wait() -> float:
	return shrink_time / FALL_SPEEDUP


## The radius of the platform now: a straight line from the start radius to MIN_RADIUS.
func radius() -> float:
	return lerpf(start_radius, MIN_RADIUS, clampf(time / shrink_time, 0.0, 1.0))


## How far the platform has shrunk, 0 (full) to 1 (least). The edge ring gets red with it.
func danger() -> float:
	return clampf(time / shrink_time, 0.0, 1.0)


## A bumper has fallen when the middle of its disk is outside the platform (REQ-SB-7).
func is_off(pos: Vector2) -> bool:
	return pos.length() > radius()


## The start places of `count` bumpers, spread evenly on a circle around the middle (REQ-SB-2). The first is at the top.
func start_spots(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in count:
		var a := -PI * 0.5 + TAU * float(i) / float(maxi(count, 1))
		out.append(Vector2(cos(a), sin(a)) * start_radius * START_SHARE)
	return out


## The speed of a dash (REQ-SB-10): in the direction of the tilt; without tilt, in the direction the bumper moves;
## without both, zero.
static func dash_velocity(tilt: Vector2, vel: Vector2, deadzone := 0.03) -> Vector2:
	if tilt.length() >= deadzone:
		return tilt.normalized() * DASH_SPEED
	if vel.length() > 1.0:
		return vel.normalized() * DASH_SPEED
	return Vector2.ZERO


## Who gets the point of a round (REQ-SB-3): the one that is left; when none is left, all that fell in the last moment.
static func round_winners(alive: Array, fell_last: Array) -> Array:
	if alive.size() == 1:
		return alive.duplicate()
	if alive.is_empty():
		return fell_last.duplicate()
	return []
