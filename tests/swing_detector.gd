extends SceneTree
## The swing detector, without a phone: a swing is made from a gyroscope and accelerometer stream at 60 Hz
## (docs/games/tennis.md, REQ-TN-5 to 9). Run: godot --headless --path . --script tests/swing_detector.gd -- --role=controller

const SwingDetector = preload("res://scripts/input/swing_detector.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")

const STEP_MS := 17
const UP := Vector3(0, 0, 1)

var _checks := 0
var _fails := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_still_and_weak()
	_strong_swing()
	_direction()
	_cooldown()
	_stream_edges()
	_player_input()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## One swing as samples: the turning speed is a bell `peak * sin(pi * x)` over `dur_ms`, and the vertical acceleration
## is `vert_acc * sin(2 pi x)` (a positive `vert_acc` pushes up first, then down). Returns the swings that were found
## and the time of the true peak. `t0` is the first timestamp (it may be near the u32 wrap).
func _swing(d: SwingDetector, t0: int, peak: float, dur_ms: int, vert_acc: float, tail_ms: int = 300) -> Dictionary:
	var found: Array = []
	var t := 0
	while t <= dur_ms + tail_ms:
		var x := float(t) / dur_ms
		var inside := t <= dur_ms
		var gyro := Vector3(0, 0, peak * sin(PI * x)) if inside else Vector3.ZERO
		var acc := vert_acc * sin(2.0 * PI * x) if inside else 0.0
		var r := d.feed((t0 + t) & 0xFFFFFFFF, gyro, UP * (SwingDetector.G + acc), UP)
		if not r.is_empty():
			found.append(r)
		t += STEP_MS
	return {"found": found, "peak_ts": (t0 + dur_ms / 2) & 0xFFFFFFFF, "end": t0 + dur_ms + tail_ms}


func _still_and_weak() -> void:
	print("rest and weak movements")
	var d := SwingDetector.new()
	var found := 0
	for i in 120:
		if not d.feed(i * STEP_MS, Vector3(0.05, 0, 0.1), UP * SwingDetector.G, UP).is_empty():
			found += 1
	_check(found == 0 and d.count == 0 and d.last.is_empty(), "a phone at rest gives no swing")
	var weak := _swing(SwingDetector.new(), 0, 5.0, 300, 0.0)
	_check(weak.found.is_empty(), "a movement with a low peak (5 rad/s) is not a swing")
	var knock := _swing(SwingDetector.new(), 0, 15.0, 30, 0.0)
	_check(knock.found.is_empty(), "a very short knock (30 ms) is not a swing")


func _strong_swing() -> void:
	print("a strong swing")
	var d := SwingDetector.new()
	var r := _swing(d, 1000, 14.0, 240, 0.0)
	_check(r.found.size() == 1 and d.count == 1, "one swing is found")
	var s: Dictionary = r.found[0]
	_check(absi(int(s.ts) - int(r.peak_ts)) <= STEP_MS,
			"the hit time is the time of the highest speed (%d vs %d)" % [s.ts, r.peak_ts])
	_check(is_equal_approx(float(s.peak), 14.0) or absf(float(s.peak) - 14.0) < 0.2, "the peak speed is kept")
	_check(absf(float(s.power) - (14.0 - SwingDetector.MIN_PEAK) / (SwingDetector.MAX_PEAK - SwingDetector.MIN_PEAK)) < 0.03,
			"the power follows the peak (14 rad/s gives about 0.54)")
	_check(int(s.latency_ms) > 0 and int(s.latency_ms) < 150, "the report comes a little after the hit (%d ms)" % s.latency_ms)
	_check(s.up_dir == UP and d.last == s, "the report holds the tilt at the hit and is kept as `last`")
	var soft := _swing(SwingDetector.new(), 0, 8.0, 240, 0.0)
	var hard := _swing(SwingDetector.new(), 0, 30.0, 240, 0.0)
	_check(soft.found.size() == 1 and hard.found.size() == 1
			and soft.found[0].power < 0.2 and hard.found[0].power == 1.0, "a soft swing has little power, a hard one is capped at 1")


func _direction() -> void:
	print("direction: a serve goes from top to bottom")
	# Pushing down first (negative vertical acceleration), then up: the vertical speed at the peak is below zero.
	var down := _swing(SwingDetector.new(), 0, 14.0, 240, -25.0)
	var up := _swing(SwingDetector.new(), 0, 14.0, 240, 25.0)
	var flat := _swing(SwingDetector.new(), 0, 14.0, 240, 0.0)
	_check(down.found.size() == 1 and down.found[0].down and down.found[0].vertical < -SwingDetector.VERTICAL_MIN,
			"a downward swing is `down` (vertical %.2f m/s)" % down.found[0].vertical)
	_check(up.found.size() == 1 and not up.found[0].down and up.found[0].vertical > 0.0, "an upward swing is not `down`")
	_check(flat.found.size() == 1 and not flat.found[0].down and absf(flat.found[0].vertical) < SwingDetector.VERTICAL_MIN,
			"a sideways swing is not `down`")


func _cooldown() -> void:
	print("one swing, one report")
	var d := SwingDetector.new()
	var first := _swing(d, 0, 14.0, 240, 0.0, 100)
	# The next swing starts 100 ms after the first one ended: the arm coming back, inside the cooldown of 400 ms.
	var back := _swing(d, int(first.end), 14.0, 240, 0.0, 100)
	_check(first.found.size() == 1 and back.found.is_empty(), "a second movement inside 400 ms of the hit is ignored")
	var later := _swing(d, int(back.end) + 600, 14.0, 240, 0.0)
	_check(later.found.size() == 1 and d.count == 2, "a swing after the cooldown is found")
	# A slow long turn that never falls below 80% of its peak is closed after 600 ms.
	var e := SwingDetector.new()
	var found := 0
	for i in 60:
		if not e.feed(i * STEP_MS, Vector3(0, 0, 9.0), UP * SwingDetector.G, UP).is_empty():
			found += 1
	_check(found == 1 and e.last.peak == 9.0, "a swing that does not end is closed after 600 ms")


func _stream_edges() -> void:
	print("timestamps and gaps")
	# The timestamp is a u32: the swing runs over the wrap at 2^32.
	var wrap := _swing(SwingDetector.new(), 0xFFFFFFFF - 100, 14.0, 240, 0.0)
	_check(wrap.found.size() == 1 and int(wrap.found[0].latency_ms) < 150, "a swing over the u32 wrap of the timestamp is found")
	# A gap of 2 s inside a swing (a lost phone) drops the swing.
	var d := SwingDetector.new()
	var found := 0
	for t in [0, 17, 34, 51]:
		found += 0 if d.feed(t, Vector3(0, 0, 12.0), UP * SwingDetector.G, UP).is_empty() else 1
	found += 0 if d.feed(2051, Vector3.ZERO, UP * SwingDetector.G, UP).is_empty() else 1
	_check(found == 0 and d.count == 0, "a swing that is cut by a 2 s gap is dropped")


func _player_input() -> void:
	print("PlayerInput")
	var p := PlayerInput.new(0, {})
	var got: Array = []
	p.swung.connect(func(info): got.append(info))
	var t := 0
	while t <= 700:
		var x := float(t) / 240.0
		var gyro := Vector3(0, 0, 14.0 * sin(PI * x)) if t <= 240 else Vector3.ZERO
		p.on_sensor({"ts": t, "seq": t / STEP_MS, "gyro": gyro, "accel": UP * SwingDetector.G,
				"buttons": 0, "touching": false, "touch": Vector2.ZERO}, 5000 + t)
		t += STEP_MS
	_check(got.size() == 1 and p.swing.count == 1 and p.last_swing_ms > 5000,
			"the slot reports a swing with `swung` and keeps its time")
	p.reset()
	_check(p.swing.count == 0 and p.swing.last.is_empty(), "a slot that is reset starts again without swings")
