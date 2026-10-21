extends RefCounted
## Made-up sensor traces and ways to replay them, for every test that needs a moving phone (Pin Pals, Tennis, Mini Golf, the
## swing detector). It is a helper, not a suite: `const SensorReplay = preload("res://tests/sensor_replay.gd")`.
##
## A `Trace` is a list of 60 Hz steps (`DT`): the acceleration of the hand without gravity (`lin`, m/s2, phone frame) and the
## gyroscope (`gyro`, rad/s). Build one with the static builders and join them with `append()`:
##
##   var t := SensorReplay.still(1.0).append(SensorReplay.stroke(Vector3(1, 0, 0), 10.0, 25.0)).append(SensorReplay.still(2.0))
##
## The builders (all deterministic: a `seed` fixes the noise):
##   still(s, noise, seed)            a phone in a hand that does not move (noise: +/- m/s2 on every axis)
##   tremor(s, amp, hz)               a hand that trembles
##   walk(s, axis, hz, peaks)         steps at `hz` along `axis`, the peaks cycle through `peaks` (m/s2)
##   stroke(fwd_dir, back, fwd, ...)  a swing: the hand goes back (peak `back`), then forward (peak `fwd`) along `fwd_dir`
##   back_swing(fwd_dir, peak, s) / forward_swing(fwd_dir, peak, s)  the two halves of a stroke, to cut a swing in the middle
##   follow_through(fwd_dir, peak, s) the hand slows down after a forward swing (a push against `fwd_dir`)
##   noisy(trace, amp, seed)          the same trace with +/- `amp` m/s2 of sensor noise on every axis, step by step
##   push(fwd_dir, peak, s)           a sharp push of `peak` m/s2 for `s` seconds (at least one step)
##   tap(peak)                        one step of `peak` m/s2 (a knock on the phone, 8 ms long in real life)
##   shake(s, amp, hz, axis)          a hand that shakes
##   slow_move(cm, hz, s, axis)       a gentle sine move (an aim, a carry): the peak acceleration is cm * (2 pi hz)^2
##   serve(up, ...)                   a stroke from top to bottom (the forward direction is `-up`)
##   turn(deg, s, up)                 the phone turns by `deg` (positive = left) around the vertical in `s` seconds
##   gyro_drift(s, noise, bias, seed) a phone that lies still with a noisy gyroscope that has an offset (rad/s)
##
## A grip says how the phone is held: `grip(UP_*)` gives its `up` (gravity in the phone frame), the direction of the TV
## (`north`, the recenter rule of orientation.gd) and `right`. `Grip.dir(az_deg, elev_deg)` is a direction of the world in the
## phone frame (0 = at the TV, positive azimuth = to the right), so `stroke(g.dir(30.0), ...)` swings 30 degrees to the right.
##
## Replay:
##   run_detector(detector, trace)  feeds a `SwingDetector` directly (fake clock = the steps), returns {releases, weak}
##   Feeder.new(player_input, up)   feeds a `PlayerInput` with packets (gravity added, timestamps from the steps); collects
##                                  the `swung` infos in `.swings`. `feed(trace, after_step)` calls `after_step` after each
##                                  packet (a game ticks its own clock there), `settle()` lets the sensor fusion start.
##   stream(tree, client, trace, up, state)  a coroutine that sends the trace as real packets from a `ControllerClient` on
##                                  loopback at 60 Hz in real time (`await` it); `state` is a Dictionary that keeps `seq`.

const Protocol = preload("res://scripts/core/protocol.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const SwingDetector = preload("res://scripts/input/swing_detector.gd")

const DT := 1.0 / 60.0
const G := 9.81
const UP_FLAT := Vector3(0, 0, 1)         # Lying flat, screen up (the top of the phone points at the TV).
const UP_UPRIGHT := Vector3(0, 1, 0)      # Held like a racket grip, screen to the player.
const UP_SIDE := Vector3(1, 0, 0)         # Held on its side (the right edge is up), like a ball in the hand.
const UP_SIDE_LEFT := Vector3(-1, 0, 0)   # The other hand: mirrored.
const UP_TILT45 := Vector3(0, 0.7071068, 0.7071068)   # Tilted 45 degrees.
const UP_SIDE_TILT45 := Vector3(0.7071068, 0, 0.7071068)


## One trace: parallel lists of the hand acceleration and the gyroscope.
class Trace:
	var lin := PackedVector3Array()
	var gyro := PackedVector3Array()

	func add(l: Vector3, g := Vector3.ZERO) -> Trace:
		lin.append(l)
		gyro.append(g)
		return self

	func append(other: Trace) -> Trace:
		lin.append_array(other.lin)
		gyro.append_array(other.gyro)
		return self

	func size() -> int:
		return lin.size()

	func seconds() -> float:
		return float(lin.size()) * DT

	func copy() -> Trace:
		return Trace.new().append(self)


## The frame of a held phone: `up` (gravity direction in the phone frame), `north` (toward the TV) and `right`.
class Grip:
	var up := Vector3(0, 0, 1)
	var north := Vector3(0, 1, 0)
	var right := Vector3(1, 0, 0)

	## The direction `az_deg` to the right of the TV and `elev_deg` above the horizon, in the phone frame.
	func dir(az_deg: float, elev_deg := 0.0) -> Vector3:
		var az := deg_to_rad(az_deg)
		var el := deg_to_rad(elev_deg)
		return (right * sin(az) + north * cos(az)) * cos(el) + up * sin(el)


## The grip of a phone whose gravity reads `up_vec`. The TV is where the top points when the phone lies flat, else away from the
## screen (the recenter rule of orientation.gd).
static func grip(up_vec: Vector3) -> Grip:
	var g := Grip.new()
	g.up = up_vec.normalized()
	var n := Vector3(0, 1, 0) if absf(g.up.z) > 0.8 else Vector3(0, 0, -1)
	g.north = n.slide(g.up).normalized()
	g.right = g.north.cross(g.up)
	return g


# ---- Builders ----

static func still(seconds: float, noise := 0.0, seed_value := 1) -> Trace:
	var t := Trace.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in int(round(seconds / DT)):
		t.add(Vector3(rng.randf_range(-noise, noise), rng.randf_range(-noise, noise), rng.randf_range(-noise, noise)))
	return t


static func tremor(seconds: float, amp := 0.3, hz := 10.0) -> Trace:
	var t := Trace.new()
	for i in int(round(seconds / DT)):
		var ph := TAU * hz * float(i) * DT
		t.add(Vector3(sin(ph), sin(ph * 1.3 + 1.0), sin(ph * 0.7 + 2.0)) * amp)
	return t


static func walk(seconds: float, axis := Vector3(0, 0, 1), hz := 2.0, peaks := [2.0, 4.0, 6.0, 3.0, 5.0]) -> Trace:
	var t := Trace.new()
	for i in int(round(seconds / DT)):
		var ph := TAU * hz * float(i) * DT
		var step := int(floor(hz * float(i) * DT))
		t.add(axis.normalized() * float(peaks[step % peaks.size()]) * sin(ph))
	return t


## A swing along `fwd_dir`: the hand speeds up backward (half sine, `back` m/s2 peak, `back_s` long), optionally stops (a push
## the other way of `stop` m/s2 for half the time), then speeds up forward (`fwd` peak, `fwd_s` long).
static func stroke(fwd_dir: Vector3, back: float, fwd: float, back_s := 0.2, fwd_s := 0.2, stop := 0.0) -> Trace:
	var d := fwd_dir.normalized()
	var t := Trace.new()
	_bump(t, -d * back, back_s)
	if stop > 0.0:
		_bump(t, d * stop, back_s * 0.5)
	_bump(t, d * fwd, fwd_s)
	return t


static func _bump(t: Trace, peak: Vector3, seconds: float) -> void:
	var n := maxi(1, int(round(seconds / DT)))
	for i in n:
		t.add(peak * sin(PI * (float(i) + 0.5) / float(n)))


static func back_swing(fwd_dir: Vector3, peak: float, seconds := 0.2) -> Trace:
	var t := Trace.new()
	_bump(t, -fwd_dir.normalized() * peak, seconds)
	return t


static func forward_swing(fwd_dir: Vector3, peak: float, seconds := 0.2) -> Trace:
	var t := Trace.new()
	_bump(t, fwd_dir.normalized() * peak, seconds)
	return t


static func follow_through(fwd_dir: Vector3, peak: float, seconds := 0.2) -> Trace:
	var t := Trace.new()
	_bump(t, -fwd_dir.normalized() * peak, seconds)
	return t


static func noisy(trace: Trace, amp: float, seed_value := 1) -> Trace:
	var t := Trace.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in trace.size():
		t.add(trace.lin[i] + Vector3(rng.randf_range(-amp, amp), rng.randf_range(-amp, amp), rng.randf_range(-amp, amp)),
				trace.gyro[i])
	return t


static func push(fwd_dir: Vector3, peak: float, seconds: float) -> Trace:
	var t := Trace.new()
	for i in maxi(1, int(round(seconds / DT))):
		t.add(fwd_dir.normalized() * peak)
	return t


static func tap(peak := 100.0, axis := Vector3(0, 0, 1)) -> Trace:
	return Trace.new().add(axis.normalized() * peak)


static func shake(seconds: float, amp := 5.0, hz := 8.0, axis := Vector3(1, 0.4, 0.2)) -> Trace:
	var t := Trace.new()
	for i in int(round(seconds / DT)):
		t.add(axis.normalized() * amp * sin(TAU * hz * float(i) * DT))
	return t


static func slow_move(cm: float, hz: float, seconds: float, axis := Vector3(1, 0, 0)) -> Trace:
	var t := Trace.new()
	var peak := cm / 100.0 * pow(TAU * hz, 2.0)
	for i in int(round(seconds / DT)):
		t.add(axis.normalized() * peak * sin(TAU * hz * float(i) * DT))
	return t


## A serve: from top to bottom. `up` is the gravity of the grip (phone frame); the forward swing goes down, `-up`.
static func serve(up_vec: Vector3, back := 8.0, fwd := 28.0, back_s := 0.2, fwd_s := 0.2, stop := 0.0) -> Trace:
	return stroke(-up_vec, back, fwd, back_s, fwd_s, stop)


## The phone turns by `deg` degrees (positive = to the left) around the vertical of the grip in `seconds`.
static func turn(deg: float, seconds: float, up_vec := UP_FLAT) -> Trace:
	var t := Trace.new()
	var n := maxi(1, int(round(seconds / DT)))
	var rate := deg_to_rad(deg) / (float(n) * DT)
	for i in n:
		t.add(Vector3.ZERO, up_vec.normalized() * rate)
	return t


## A phone that lies still, with gyro noise (+/- rad/s) and a constant offset `bias` (rad/s) around the vertical.
static func gyro_drift(seconds: float, noise := 0.0, bias := 0.0, seed_value := 1, up_vec := UP_FLAT) -> Trace:
	var t := Trace.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in int(round(seconds / DT)):
		var g := Vector3(rng.randf_range(-noise, noise), rng.randf_range(-noise, noise), rng.randf_range(-noise, noise))
		t.add(Vector3.ZERO, g + up_vec.normalized() * bias)
	return t


# ---- Replay ----

## Feeds `det` with the steps of `trace`. Returns {releases: [{step, power, dir, age}], weak: the count of dropped back swings}.
static func run_detector(det: SwingDetector, trace: Trace) -> Dictionary:
	var out := {"releases": [], "weak": 0}
	for i in trace.size():
		det.update(DT, trace.lin[i])
		if det.weak:
			out.weak += 1
		if det.released:
			out.releases.append({"step": i, "power": det.power, "dir": det.forward_dir, "age": det.hit_age})
	return out


## Feeds a `PlayerInput` with sensor packets as the phone would send them. The accelerometer reads the hand plus gravity.
class Feeder:
	var player: PlayerInput
	var up := Vector3(0, 0, 1)
	var swings: Array = []
	var step := 0
	var seq := 0
	var base_ms := 100000   # The TV clock at step 0.
	## True for a phone that reports the acceleration with the other sign (the iPhone convention): the TV then needs the
	## `invert_tilt` setting, as the controller sends it (orientation.gd).
	var invert := false
	## A finger on the touch screen: `touching` and the place `touch` (0 to 1 on both axes) go in every packet.
	var touching := false
	var touch := Vector2.ZERO

	func _init(p: PlayerInput, up_vec := Vector3(0, 0, 1)) -> void:
		player = p
		up = up_vec.normalized()
		p.swung.connect(func(info: Dictionary) -> void: swings.append(info))

	## The phone clock (ms) of the next packet.
	func ts() -> int:
		return int(round(float(step) * DT * 1000.0))

	func packet(lin: Vector3, gyro: Vector3) -> Dictionary:
		var accel := (lin + up * G) * (-1.0 if invert else 1.0)
		return {"ts": ts() & 0xFFFFFFFF, "seq": seq & 0xFFFF, "gyro": gyro, "accel": accel, "buttons": 0,
				"touching": touching, "touch": touch if touching else Vector2.ZERO}

	func feed(trace: Trace, after_step := Callable()) -> void:
		for i in trace.size():
			player.on_sensor(packet(trace.lin[i], trace.gyro[i]), base_ms + ts())
			step += 1
			seq += 1
			if after_step.is_valid():
				after_step.call()

	## The phone lies still for `seconds`: the sensor fusion starts and the first pose is the center of the aim.
	func settle(seconds := 0.5, after_step := Callable()) -> void:
		var t := Trace.new()
		for i in int(round(seconds / DT)):
			t.add(Vector3.ZERO)
		feed(t, after_step)

	## The TV clock now (ms), for the code that compares it with `last_swing_ms`.
	func now_ms() -> int:
		return base_ms + ts()


## Sends `trace` as real packets from `client` (a ControllerClient joined to the TV) at 60 Hz, in real time. Use it with
## `await SensorReplay.stream(self, client, trace, up, state)`. `state` keeps the packet number and the clock between calls.
static func stream(tree: SceneTree, client: Node, trace: Trace, up_vec: Vector3, state: Dictionary) -> void:
	await stream_many(tree, [client], [trace], [up_vec], [state])


## Like `stream()` for several phones at once: the traces run side by side (a shorter one ends, the others go on).
static func stream_many(tree: SceneTree, clients: Array, traces: Array, ups: Array, states: Array) -> void:
	var start := Time.get_ticks_msec()
	var index: Array = []
	var longest := 0
	for k in clients.size():
		index.append(0)
		longest = maxi(longest, traces[k].size())
		if not states[k].has("t0"):
			states[k]["t0"] = Time.get_ticks_msec()
			states[k]["step"] = 0
			states[k]["seq"] = 0
	var done := 0
	while done < longest:
		done = int(float(Time.get_ticks_msec() - start) / (DT * 1000.0)) + 1
		for k in clients.size():
			var tr: Trace = traces[k]
			while index[k] < mini(tr.size(), done):
				var st: Dictionary = states[k]
				var ts := int(st.t0) + int(round(float(st.step) * DT * 1000.0))
				clients[k].send_sensor(Protocol.encode_sensor(int(st.seq), ts, tr.gyro[index[k]],
						tr.lin[index[k]] + ups[k].normalized() * G, 0, 0, Vector2.ZERO))
				st.seq = int(st.seq) + 1
				st.step = int(st.step) + 1
				index[k] += 1
		await tree.process_frame
