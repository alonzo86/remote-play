extends RefCounted
## Made-up sensor traces for the swing tests of Tennis and Mini Golf (tests/tennis_rules.gd, smoke_tennis.gd, smoke_golf.gd).
## A trace is a list of linear accelerations (m/s2, phone frame, gravity not included), one per 1/60 s. `packet()` adds gravity
## and builds the sensor packet that `PlayerInput.on_sensor()` reads, so a trace can go through the same code as a real phone.
## Phone flat (screen up) has `up` = (0, 0, 1) in the phone frame, so a push along phone x is a push to the right of the TV.

const DT := 1.0 / 60.0
const G := 9.81
const FLAT := Vector3(0.0, 0.0, 1.0)


## One stroke: the hand moves back along -`dir` (half sine of `back` m/s2 for `bt` s), then forward along `dir` (`fwd` m/s2 for
## `ft` s). `dir` is the direction of the forward swing. The peak of the forward swing is `bt + ft / 2` after the start.
static func stroke(dir: Vector3, back: float, fwd: float, bt := 0.25, ft := 0.25) -> Array:
	var out: Array = []
	var d := dir.normalized()
	var nb := int(round(bt / DT))
	var nf := int(round(ft / DT))
	for i in nb:
		out.append(-d * back * sin(PI * (float(i) + 0.5) / float(nb)))
	for i in nf:
		out.append(d * fwd * sin(PI * (float(i) + 0.5) / float(nf)))
	return out


## `seconds` of rest with a little noise (m/s2) of `noise` on each axis.
static func rest(seconds: float, noise := 0.0, rng: RandomNumberGenerator = null) -> Array:
	var out: Array = []
	for i in int(round(seconds / DT)):
		var v := Vector3.ZERO
		if noise > 0.0 and rng != null:
			v = Vector3(rng.randf_range(-noise, noise), rng.randf_range(-noise, noise), rng.randf_range(-noise, noise))
		out.append(v)
	return out


## A walk: a vertical bounce of `peak` m/s2 at 2 Hz plus a small sway.
static func walk(seconds: float, peak := 3.0) -> Array:
	var out: Array = []
	for i in int(round(seconds / DT)):
		var t := float(i) * DT
		out.append(Vector3(0.4 * sin(TAU * 1.0 * t), 0.3 * sin(TAU * 2.0 * t), peak * sin(TAU * 2.0 * t)))
	return out


## The sensor packet for a linear acceleration `lin`, a gyroscope `gyro` (rad/s) and the world up `up` in the phone frame.
static func packet(lin: Vector3, tick: int, gyro := Vector3.ZERO, up := FLAT) -> Dictionary:
	return {"ts": int(round(float(tick) * DT * 1000.0)), "seq": tick & 0xFFFF, "gyro": gyro, "accel": lin + up * G,
			"touching": false, "touch": Vector2.ZERO, "buttons": 0}


## Feeds `samples` into `pi` (a PlayerInput) from tick `start`. Returns the tick after the last sample. `each` (a Callable
## taking the tick number) runs after every sample: the games call their tick there.
static func feed(pi: RefCounted, samples: Array, start: int, up := FLAT, each := Callable()) -> int:
	var tick := start
	for lin in samples:
		pi.on_sensor(packet(lin, tick, Vector3.ZERO, up), int(round(float(tick) * DT * 1000.0)))
		if each.is_valid():
			each.call(tick)
		tick += 1
	return tick
