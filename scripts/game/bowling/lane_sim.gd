extends RefCounted
## The lane of Bowling (REQ-BW-9, 10): a ball that rolls down the lane and ten pins. A fixed 2D simulation in metres (x across
## the
## lane, 0 in the middle and positive to the right; y along the lane, 0 at the foul line). Circles only. It uses sub-steps of
## 1/120 s (REQ-GM-13) and no random number, so the same throw always gives the same result. Pure logic: it draws nothing.

const LANE_HALF := 0.525          # Half of the lane width (1.05 m). A ball whose middle is further out is in the gutter.
const GUTTER_X := 0.62            # Where a ball in the gutter rolls.
# With rails the middle of the ball stays this far from the middle (the lane edge less the ball radius).
const RAIL_LIMIT := 0.416
const RAIL_NUDGE := 0.012         # With rails, a ball on a rail drifts back into the lane by this share of its speed.
const BALL_R := 0.109
const PIN_R := 0.09
const HEAD_Y := 18.29             # The head pin (1) is 60 feet from the foul line.
const ROW_DY := 0.264
const PIN_DX := 0.1525            # Half the distance between two pins of a row.
const PIT_Y := 19.6               # A pin or a ball that is past this line is in the pit.
const END_Y := 20.2
const STEP := 1.0 / 120.0
const MAX_TIME := 7.0             # A throw that has not settled after this time is stopped.
const BALL_MASS := 6.0
const PIN_MASS := 1.0
const E_BALL_PIN := 0.9           # Bounciness of the ball against a pin, and of a pin against a pin.
const E_PIN_PIN := 0.95
const FALL_SPEED := 0.2          # A pin that a hit sends faster than this (m/s) falls. A slower hit only makes it wobble.
const FRICTION := 1.6             # A fallen pin slows by this (m/s2).
const REST_SPEED := 0.05
const SPEED_TOP := 9.0            # The ball speed (m/s) of the strongest swing (REQ-BW-6).
const PIN_COUNT := 10

enum State { STAND, FALLEN, GONE }

## The place of each pin of the rack (pin n is at index n - 1): 1 is the head pin, 7 is at the left and 10 at the right
## at the back, as the bowler sees them.
const RACK := [
	Vector2(0.0, 0.0),
	Vector2(-1.0, 1.0), Vector2(1.0, 1.0),
	Vector2(-2.0, 2.0), Vector2(0.0, 2.0), Vector2(2.0, 2.0),
	Vector2(-3.0, 3.0), Vector2(-1.0, 3.0), Vector2(1.0, 3.0), Vector2(3.0, 3.0),
]


class Pin:
	var n := 1                 # The number of the pin, 1 to 10.
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var state := State.STAND
	var fell_at := -1.0        # The time of the throw when it fell (for the picture).


var pins: Array[Pin] = []
var ball_pos := Vector2.ZERO
var ball_vel := Vector2.ZERO
var ball_active := false       # True from the throw until the ball is in the pit or in the gutter's end.
var in_gutter := false
var rails := false
var time := 0.0                # Seconds since the throw.
var finished := true           # True when there is no throw in progress.
var events: Array[Dictionary] = []   # {t: "hit", count} and {t: "fall", n}: what happened in the last `tick()`.
var first_hit := false
var _acc := 0.0


func _init() -> void:
	for i in PIN_COUNT:
		var p := Pin.new()
		p.n = i + 1
		pins.append(p)
	set_rack([true, true, true, true, true, true, true, true, true, true])


## The pin position of pin number n (1 to 10) in a standing rack.
static func rack_pos(n: int) -> Vector2:
	var r: Vector2 = RACK[n - 1]
	return Vector2(r.x * PIN_DX, HEAD_Y + r.y * ROW_DY)


## Puts a rack on the lane: pin n stands when `mask[n - 1]` is true; the others are gone. The ball is back at the foul line.
func set_rack(mask: Array) -> void:
	for p in pins:
		p.pos = rack_pos(p.n)
		p.vel = Vector2.ZERO
		p.state = State.STAND if mask[p.n - 1] else State.GONE
		p.fell_at = -1.0
	ball_active = false
	in_gutter = false
	finished = true
	first_hit = false
	events.clear()
	time = 0.0
	_acc = 0.0


## The pins that stand now, as a mask (index n - 1).
func standing_mask() -> Array:
	var m := []
	for p in pins:
		m.append(p.state == State.STAND)
	return m


func standing_count() -> int:
	var c := 0
	for p in pins:
		if p.state == State.STAND:
			c += 1
	return c


## The pins that were standing in `before` and are not now.
func knocked_since(before: Array) -> int:
	var c := 0
	for p in pins:
		if before[p.n - 1] and p.state != State.STAND:
			c += 1
	return c


## Takes the fallen pins away (the sweep). The standing pins stay where they are.
func sweep() -> void:
	for p in pins:
		if p.state != State.STAND:
			p.state = State.GONE
	ball_active = false
	events.clear()


## Throws the ball from the foul line. `x` is the place across the lane in metres, `speed` in m/s, straight down the lane.
## With rails the place is limited to the rails and the ball is pushed back a little (REQ-BW-10).
func throw(x: float, speed: float, with_rails: bool) -> void:
	rails = with_rails
	ball_pos = Vector2(x, 0.0)
	ball_vel = Vector2(0.0, speed)
	in_gutter = false
	if rails:
		if absf(ball_pos.x) >= RAIL_LIMIT:
			ball_vel.x = -signf(ball_pos.x) * RAIL_NUDGE * speed
		ball_pos.x = clampf(ball_pos.x, -RAIL_LIMIT, RAIL_LIMIT)
	elif absf(ball_pos.x) > LANE_HALF:
		_to_gutter()
	ball_active = true
	finished = false
	first_hit = false
	time = 0.0
	_acc = 0.0
	events.clear()


func _to_gutter() -> void:
	in_gutter = true
	ball_pos.x = signf(ball_pos.x) * GUTTER_X
	ball_vel.x = 0.0


## Moves the simulation by `delta` seconds in whole sub-steps of 1/120 s: a rest of time waits for the next call, so the result
## does
## not depend on the frame rate (REQ-GM-13). `events` holds what happened.
func tick(delta: float) -> void:
	events.clear()
	if finished:
		return
	_acc += delta
	while _acc >= STEP and not finished:
		_step(STEP)
		_acc -= STEP


func _step(dt: float) -> void:
	time += dt
	if ball_active:
		ball_pos += ball_vel * dt
		if rails and absf(ball_pos.x) > RAIL_LIMIT:
			ball_pos.x = signf(ball_pos.x) * RAIL_LIMIT
			ball_vel.x = -signf(ball_pos.x) * RAIL_NUDGE * ball_vel.y
		elif not rails and not in_gutter and absf(ball_pos.x) > LANE_HALF:
			_to_gutter()
		if not in_gutter:
			_ball_hits_pins()
		if ball_pos.y > END_Y:
			ball_active = false
	_move_pins(dt)
	_pins_hit_pins()
	var moving := false
	for p in pins:
		if p.state == State.FALLEN and p.vel.length() > REST_SPEED:
			moving = true
	if (not ball_active and not moving) or time > MAX_TIME:
		for p in pins:
			p.vel = Vector2.ZERO
		ball_active = false
		finished = true


func _ball_hits_pins() -> void:
	for p in pins:
		if p.state == State.GONE:
			continue
		var d := p.pos - ball_pos
		var dist := d.length()
		if dist >= BALL_R + PIN_R or dist < 0.0001:
			continue
		var n := d / dist
		var vn := (ball_vel - p.vel).dot(n)
		if vn > 0.0:
			var j := (1.0 + E_BALL_PIN) * vn / (1.0 / BALL_MASS + 1.0 / PIN_MASS)
			ball_vel -= n * (j / BALL_MASS)
			p.vel += n * (j / PIN_MASS)
			if not first_hit:
				first_hit = true
				events.append({"t": "hit"})
			_after_hit(p)
		if p.state == State.FALLEN:
			p.pos = ball_pos + n * (BALL_R + PIN_R)


## A pin that is hit hard falls and goes on as a sliding body; a soft hit only makes it wobble (it stays where it is).
func _after_hit(p: Pin) -> void:
	if p.state == State.STAND:
		if p.vel.length() >= FALL_SPEED:
			p.state = State.FALLEN
			p.fell_at = time
			events.append({"t": "fall", "n": p.n})
		else:
			p.vel = Vector2.ZERO


func _move_pins(dt: float) -> void:
	for p in pins:
		if p.state != State.FALLEN:
			continue
		var speed := p.vel.length()
		if speed > 0.0:
			var slowed := maxf(0.0, speed - FRICTION * dt)
			p.vel = p.vel * (slowed / speed)
			p.pos += p.vel * dt
		if p.pos.y > PIT_Y or absf(p.pos.x) > GUTTER_X:
			p.state = State.GONE
			p.vel = Vector2.ZERO


func _pins_hit_pins() -> void:
	for i in pins.size():
		var a := pins[i]
		if a.state != State.FALLEN or a.vel.length() <= REST_SPEED:
			continue
		for j in pins.size():
			if i == j or pins[j].state == State.GONE:
				continue
			var b := pins[j]
			var d := b.pos - a.pos
			var dist := d.length()
			if dist >= 2.0 * PIN_R or dist < 0.0001:
				continue
			var n := d / dist
			var vn := (a.vel - b.vel).dot(n)
			if vn > 0.0:
				var j_imp := (1.0 + E_PIN_PIN) * vn / 2.0
				a.vel -= n * j_imp
				b.vel += n * j_imp
				_after_hit(b)
			if b.state == State.FALLEN:
				b.pos = a.pos + n * (2.0 * PIN_R)   # A standing pin does not move.
