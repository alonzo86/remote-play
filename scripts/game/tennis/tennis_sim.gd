extends RefCounted
## The ball of Tennis (REQ-TN-2 to 7). Pure logic: no drawing. The court is in meters. `x` is across the court (positive to the
## right of the near team, who look to the far end), `y` is along it (0 is the net, the near team is at negative `y`) and `z` is
## the height. A hit sets the speed so that the ball lands on a wanted point after a wanted flight time; a ball that would not
## clear the net is lifted. The ball bounces with a loss, and a net touch ends its flight.

const G := 9.81
const HALF_L := 11.885          # Half the length of the court.
const HALF_W_DOUBLES := 5.485
const HALF_W_SINGLES := 4.115
const SERVICE := 6.4            # The service line, from the net.
const NET_H := 0.914
const NET_CLEAR := 0.3          # A ball must pass the net this much above its top.
const BOUNCE := 0.72            # The share of the vertical speed that stays after a bounce.
const SKID := 0.86              # The share of the horizontal speed that stays after a bounce.
const REST_VZ := 0.8            # A bounce slower than this (m/s) ends the bouncing.
const STEP := 1.0 / 120.0
const CONTACT_DELAY := 0.30     # The ball is hit this long (s) after its first bounce (REQ-TN-5).
const PREDICT_MAX := 4.0

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var active := false
var tossed := false             # A tossed ball ignores the net and the ground until it is hit or taken away.
var dead := false               # The ball touched the net: it falls and the point is over.
var bounces := 0                # Bounces since the last hit.
## Events of the last `tick()`: `{t: "bounce", pos: Vector3, n: int}` and `{t: "net", pos: Vector3}`.
var events: Array = []


func clone() -> Object:
	var c = get_script().new()
	c.pos = pos
	c.vel = vel
	c.active = active
	c.tossed = tossed
	c.dead = dead
	c.bounces = bounces
	return c


func clear() -> void:
	active = false
	tossed = false
	dead = false
	bounces = 0
	vel = Vector3.ZERO
	events.clear()


## The ball goes straight up from `from` (the hand of the server) with the speed `up`.
func toss(from: Vector3, up: float) -> void:
	clear()
	pos = from
	vel = Vector3(0.0, 0.0, up)
	active = true
	tossed = true


## A hit from `from` to the point `to` on the ground, with a flight of about `flight` seconds. The flight is made longer when
## the ball would not clear the net. Returns the flight time that was used.
func launch(from: Vector3, to: Vector2, flight: float) -> float:
	clear()
	var t := maxf(flight, 0.3)
	var dxy := to - Vector2(from.x, from.y)
	for i in 20:
		var vxy := dxy / t
		var vz := (G * t * t * 0.5 - from.z) / t
		var tn := t * 2.0   # The time at the net: never, when the ball starts and lands on one side.
		if from.y * to.y < 0.0:
			tn = -from.y / vxy.y
		if tn > 0.0 and tn < t and from.z + vz * tn - 0.5 * G * tn * tn < NET_H + NET_CLEAR:
			t += 0.1
			continue
		break
	var v := dxy / t
	pos = from
	vel = Vector3(v.x, v.y, (G * t * t * 0.5 - from.z) / t)
	active = true
	return t


func tick(delta: float) -> void:
	events.clear()
	if not active:
		return
	var left := delta
	while left > 0.0:
		var dt := minf(left, STEP)
		left -= dt
		var prev := pos
		vel.z -= G * dt
		pos += vel * dt
		if not tossed and not dead and (prev.y < 0.0) != (pos.y < 0.0):
			var f := prev.y / (prev.y - pos.y)
			var h := lerpf(prev.z, pos.z, f)
			if h < NET_H:
				dead = true
				pos = Vector3(lerpf(prev.x, pos.x, f), 0.0, maxf(h, 0.0))
				vel = Vector3(vel.x * 0.05, 0.0, 0.0)
				events.append({"t": "net", "pos": pos})
		if not tossed and pos.z <= 0.0 and vel.z < 0.0:
			pos.z = 0.0
			bounces += 1
			if -vel.z * BOUNCE < REST_VZ:
				vel.z = 0.0
			else:
				vel.z = -vel.z * BOUNCE
			vel.x *= SKID
			vel.y *= SKID
			events.append({"t": "bounce", "pos": pos, "n": bounces})


## Where the ball will be hit: `{bounce_t, bounce_pos, contact_t, contact_pos}` (seconds from now), or an empty Dictionary when
## the ball does not bounce (it touches the net, or it is tossed).
func predict() -> Dictionary:
	if not active or tossed or dead:
		return {}
	var c = clone()
	var t := 0.0
	var tb := -1.0
	var bpos := Vector3.ZERO
	while t < PREDICT_MAX:
		c.tick(1.0 / 60.0)
		t += 1.0 / 60.0
		for e in c.events:
			if e.t == "net":
				return {}
			if e.t == "bounce" and tb < 0.0:
				tb = t
				bpos = e.pos
		if tb >= 0.0 and t >= tb + CONTACT_DELAY:
			return {"bounce_t": tb, "bounce_pos": bpos, "contact_t": t, "contact_pos": c.pos}
	return {}
