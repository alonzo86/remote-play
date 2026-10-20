extends RefCounted
## Helpers for the tests that run a game with simulated phones and a fixed time step (tests/auto_paint.gd, auto_sumo.gd,
## auto_asteroid.gd). A test that waits for real frames depends on the speed of the machine; these helpers do not:
##   - `SimInput.step(game, dt)` runs one frame of a game by hand (the game must have `set_process(false)`),
##   - `SimInput.feed()` sends a sensor packet straight to a `PlayerInput` (the sensor fusion runs, the network does not),
##   - `SimInput.set_tilt()` sets the tilt of a phone to an exact value,
##   - `SimInput.RecHaptics` notes every pulse (slot, ms) that a game would send to a phone,
##   - `SimInput.delta_e()` is the distance of two colors in the CIE Lab space.
## They need the autoloads (role `tv`).

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

var _ts := 0.0      # The sensor time of the simulated phones in ms (one clock for all).
var _seq := {}      # slot -> the next sequence number


## Lets the phones in `old` leave and connects `count` new simulated phones named "Sim0", "Sim1" ... to the TV. Returns them.
## It waits for real frames, so call it with `await`.
static func connect_phones(tree: SceneTree, app: Node, count: int, old: Array = []) -> Array:
	for c in old:
		c.leave()
	var waited := Time.get_ticks_msec()
	while not app.server.connected_slots().is_empty() and Time.get_ticks_msec() - waited < 4000:
		await tree.process_frame
	var out: Array = []
	for i in count:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		tree.root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		out.append(c)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await tree.process_frame
	return out


## Starts a game from the App with its process switched off, so a test steps it by hand. All phones are flat.
static func start_game(app: Node, script: GDScript, props := {}) -> Control:
	app.go(script, props)
	var game: Control = app.current_screen()
	game.set_process(false)
	return game


## Runs the countdown of a game until `counting.call()` is false. Returns false when it still counts after 10 s.
static func to_play(game: Control, counting: Callable, dt := 1.0 / 60.0) -> bool:
	var t := 0.0
	while counting.call() and t < 10.0:
		game._process(dt)
		t += dt
	return not counting.call()


## Gives a game a recording `Haptics` and returns it.
static func record_haptics(game: Object) -> RefCounted:
	var rec: RefCounted = load("res://tests/rec_haptics.gd").new()   # Loaded here: it needs the App autoload to compile.
	game._haptics = rec
	return rec


## Runs `seconds` of a game in steps of `dt` (the game does not process by itself). `each` (optional) is called after every step
## with the time since the start.
static func run(game: Control, seconds: float, dt := 1.0 / 60.0, each := Callable()) -> void:
	var t := 0.0
	while t < seconds - 1.0e-6:
		game._process(dt)
		t += dt
		if each.is_valid():
			each.call(t)


## Runs a game until `done.call()` is true or `limit` seconds passed. Returns the seconds it ran.
static func run_until(game: Control, done: Callable, limit: float, dt := 1.0 / 60.0) -> float:
	var t := 0.0
	while t < limit and not done.call():
		game._process(dt)
		t += dt
	return t


## Sets the tilt of a player to `t` (x: right side down, y: top of the phone up, both -1 to 1) as if the phone were held so,
## relative to the pose of the last recenter at a flat pose. Use it only before the first sensor packet of a phone.
static func set_tilt(p: RefCounted, t: Vector2) -> void:
	var tt := t.limit_length(1.0)
	p.orientation.up = Vector3(-tt.x, tt.y, sqrt(maxf(0.0, 1.0 - tt.length_squared())))


## The accelerometer reading of a phone that is tilted by `t` (a unit gravity vector, 9.81 m/s2).
static func accel_for(t: Vector2) -> Vector3:
	var tt := t.limit_length(1.0)
	return Vector3(-tt.x, tt.y, sqrt(maxf(0.0, 1.0 - tt.length_squared()))) * 9.81


## Sends one sensor packet of a phone held at tilt `t`, `dt` seconds after the last one of any phone of this clock.
func feed(p: RefCounted, t: Vector2, dt := 1.0 / 60.0, gyro := Vector3.ZERO) -> void:
	_ts += dt * 1000.0
	var n: int = int(_seq.get(p.slot, 0))
	_seq[p.slot] = n + 1
	p.on_sensor({"seq": n & 0xFFFF, "ts": int(_ts), "gyro": gyro, "accel": accel_for(t), "buttons": 0, "touching": false,
			"touch": Vector2.ZERO}, int(_ts))


## Converts an sRGB color to CIE Lab (D65).
static func lab(c: Color) -> Vector3:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var b: float = lin.call(c.b)
	var x := (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * b
	var z := (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	var f := func(v: float) -> float: return pow(v, 1.0 / 3.0) if v > 0.008856 else 7.787 * v + 16.0 / 116.0
	var fx: float = f.call(x)
	var fy: float = f.call(y)
	var fz: float = f.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


## The distance of two colors (CIE76 delta E). About 2.3 is the smallest difference that an eye sees; 20 or more are two colors.
static func delta_e(a: Color, b: Color) -> float:
	return lab(a).distance_to(lab(b))


## The smallest delta E between two colors of `colors`.
static func min_delta_e(colors: Array) -> float:
	var worst := 1.0e9
	for i in colors.size():
		for j in range(i + 1, colors.size()):
			worst = minf(worst, delta_e(colors[i], colors[j]))
	return worst
