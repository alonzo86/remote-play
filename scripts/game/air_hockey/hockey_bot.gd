extends "res://scripts/game/bot.gd"
## The brain of ROBO, the computer player of Air Hockey (REQ-AH-13 to 17). It defends its goal, and when the puck is slow and on
## its own half it goes behind the puck and hits it at the other goal. Difficulty (REQ-AH-17) changes only its skill:
## the reaction time, how far it may tilt (its top speed), how wrong its aim is, how often it attacks and how long it lets a
## slow puck lie on its half.

const Sim = preload("res://scripts/game/air_hockey/air_hockey_sim.gd")

## What Easy, Medium and Hard mean for the bot (REQ-AH-17). First guesses, tuned on a device (Manual test 27).
const LEVELS := {
	"easy": {"reaction": 0.5, "max_tilt": 0.35, "aim_error": 250.0,
			"defend_error": 260.0, "attack": 0.3,
			"attack_speed": 260.0, "idle": 2.0},
	"medium": {"reaction": 0.3, "max_tilt": 0.5, "aim_error": 200.0,
			"defend_error": 60.0, "attack": 0.5,
			"attack_speed": 520.0, "idle": 1.2},
	"hard": {"reaction": 0.07, "max_tilt": 1.0, "aim_error": 60.0,
			"defend_error": 25.0, "attack": 0.95,
			"attack_speed": 900.0, "idle": 0.5},
}
const DEFEND_GAP := 100.0       # The paddle waits this far from its goal line, beyond its radius.
const GOAL_REACH := 170.0       # The paddle keeps this close to the middle of its goal (up and down).
const KP := 6.0                 # Position error (px) to wanted speed (px/s).
const SPEED_LIMIT := 1000.0
const APPROACH_SPEED := 60.0    # The puck comes to our goal when it moves toward it faster than this (px/s).
const DANGER_DEPTH := 190.0     # A puck closer than this to our goal line, in front of the opening, is swept sideways.
const DANGER_BAND := 30.0       # The band of the opening grows by this much on both sides.

var seat := 1
var _committed := false         # The bot decided to attack the puck that is on its half now.
var _was_home := false
var _slow_time := 0.0           # How long the puck has been slow on our half.
var _aim_noise := 0.0
var _defend_noise := 0.0


## The skill of a difficulty ("medium" when the name is unknown).
static func skill_for(difficulty: String) -> Dictionary:
	return LEVELS.get(difficulty, LEVELS.medium)


func _init(p_difficulty := "medium", p_seat := 1, p_seed := 1) -> void:
	super(skill_for(p_difficulty), p_seed)
	seat = p_seat


## +1 when "into the rink" is to the right (the left seat), -1 for the right seat.
func away() -> float:
	return 1.0 if seat == 0 else -1.0


func _brain(seen: Dictionary, now: Dictionary, delta: float) -> Vector2:
	var puck: Vector2 = seen.puck_pos
	var vel: Vector2 = seen.puck_vel
	var pad: Vector2 = now.pad_pos
	var depth := (puck.x - Sim.goal_x(seat)) * away()   # How far the puck is from our goal line.
	var home := depth < Sim.RINK.size.x * 0.5
	if home and not _was_home:
		_committed = rng.randf() < float(skill.attack)   # A new puck on our half: attack it, or only defend.
		_aim_noise = rng.randf_range(-1.0, 1.0) * float(skill.aim_error)
	if not home:
		_defend_noise = rng.randf_range(-1.0, 1.0) * float(skill.defend_error)
	_was_home = home
	# A puck that stays slow on our half must be played: nobody else can reach it. After `idle` seconds the bot attacks.
	_slow_time = _slow_time + delta if home and vel.length() < float(skill.attack_speed) else 0.0
	if _slow_time > float(skill.idle):
		_committed = true
	var target := _defend_target(puck, vel)
	# A puck that comes to our goal is defended, however slow it is: going behind it would leave the goal open (issue #147).
	if home and _committed and vel.length() < float(skill.attack_speed) and vel.x * away() > -APPROACH_SPEED:
		target = _attack_target(puck, pad)
	var want := ((target - pad).limit_length(SPEED_LIMIT / KP)) * KP
	var pv: Vector2 = now.pad_vel
	return (want * Sim.PADDLE_DAMPING + (want - pv) * 10.0) / Sim.PADDLE_ACCEL


## Waits in front of the goal, in line with where the puck will cross.
func _defend_target(puck: Vector2, vel: Vector2) -> Vector2:
	var c := Sim.RINK.get_center()
	var x := Sim.goal_x(seat) + away() * (Sim.PADDLE_R + DEFEND_GAP)
	var y := lerpf(c.y, puck.y, 0.5)
	if vel.x * away() < -APPROACH_SPEED:   # The puck comes to our goal: stand where it will cross.
		y = _fold(puck.y + vel.y * (x - puck.x) / vel.x) + _defend_noise
	return Vector2(x, clampf(y, c.y - GOAL_REACH, c.y + GOAL_REACH))


## The y of a line that bounces off the top and the bottom rail.
static func _fold(y: float) -> float:
	var top := Sim.RINK.position.y + Sim.PUCK_R
	var span := Sim.RINK.size.y - 2.0 * Sim.PUCK_R
	var m := fposmod(y - top, 2.0 * span)
	return top + (m if m <= span else 2.0 * span - m)


## Goes behind the puck (as seen from the other goal), then through it. A puck in front of our own goal opening cannot be hit
## toward the other goal: there is no room behind it, and a hit from the side of the field pushes it into our goal (issue #146).
## It is swept along the goal line, away from the opening, from the side of the middle line.
func _attack_target(puck: Vector2, pad: Vector2) -> Vector2:
	var c := Sim.RINK.get_center()
	var depth := (puck.x - Sim.goal_x(seat)) * away()
	var dir: Vector2
	if depth < DANGER_DEPTH and absf(puck.y - c.y) < Sim.GOAL_H * 0.5 + Sim.PUCK_R + DANGER_BAND:
		dir = Vector2(0.0, 1.0 if puck.y >= c.y else -1.0)
	else:
		dir = (Vector2(Sim.goal_x(1 - seat), c.y + _aim_noise) - puck).normalized()
	var behind := puck - dir * (Sim.PUCK_R + Sim.PADDLE_R + 70.0)
	var lined_up := (pad - behind).length() < 60.0 or (pad - puck).dot(dir) < 0.0 and absf((pad - puck).cross(dir)) < 50.0
	if lined_up:
		return puck + dir * 40.0
	# The straight way to the point behind the puck must not brush the puck: a touch from the wrong side sends it the wrong way.
	var keep_off := Sim.PUCK_R + Sim.PADDLE_R + 30.0
	var way := behind - pad
	var t := clampf((puck - pad).dot(way) / maxf(way.length_squared(), 1.0), 0.0, 1.0)
	if (pad + way * t).distance_to(puck) < keep_off:
		var side := dir.orthogonal()
		if (pad - puck).dot(side) < 0.0:
			side = -side
		return puck + side * (keep_off + 40.0) - dir * 40.0
	return behind
