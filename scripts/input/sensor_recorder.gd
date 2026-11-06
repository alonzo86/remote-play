extends RefCounted
## Records the sensor packets of the phones on the TV, to get real traces for tuning the swing detector (Test 24 step
## 12d, REQ-T7). The debug overlay starts and stops it (`debug_overlay.gd`); `PlayerInput.on_sensor()` calls `add()` for
## every packet.
## A recording is one CSV file per phone (`user://sensor_traces/<label>_<time>_p<slot>.csv`):
##
##   # sababi sensor trace 1
##   # label=sweep
##   # slot=1
##   t_ms,lin_x,lin_y,lin_z,gyro_x,gyro_y,gyro_z
##   0,0.1234,-0.0123,0.5000,0.0100,0.0000,-0.0200
##
## `t_ms` is the time of the phone clock since the first packet, `lin_*` is `PlayerInput.linear_accel()` (m/s2, phone frame, no
## gravity), `gyro_*` is rad/s. `parse()` reads such a file back and `resample()` puts it on the 60 Hz grid of
## tests/sensor_replay.gd.

const DIR := "user://sensor_traces"
const MAGIC := "# sababi sensor trace 1"
const HEADER := "t_ms,lin_x,lin_y,lin_z,gyro_x,gyro_y,gyro_z"
## The kinds of movement that Test 24 step 12d asks for, in the order the overlay cycles through them.
const LABELS: Array[String] = ["sweep", "hard_shake", "slow_shake", "swing_soft", "swing_medium", "swing_hard"]

## Rows kept for one phone: 10 minutes at 60 Hz. A recording that runs longer stops growing (issue #387).
const MAX_ROWS := 36000

var label := LABELS[0]
var recording := false
var started_ms := 0
## Per slot: {"t0": first timestamp, "rows": Array of [t_ms, lin, gyro]}.
var _rows := {}


func next_label(step := 1) -> void:
	label = LABELS[posmod(LABELS.find(label) + step, LABELS.size())]


func start(p_label := "", now_ms := 0) -> void:
	if p_label != "":
		label = p_label
	recording = true
	started_ms = now_ms
	_rows = {}


func seconds(now_ms: int) -> float:
	return (now_ms - started_ms) / 1000.0 if recording else 0.0


## One packet of the phone in `slot`: `ts` is the timestamp the phone put in it (ms, 32 bits).
func add(slot: int, ts: int, lin: Vector3, gyro: Vector3) -> void:
	if not recording:
		return
	if not _rows.has(slot):
		_rows[slot] = {"t0": ts, "rows": []}
	var r: Dictionary = _rows[slot]
	if r.rows.size() >= MAX_ROWS:
		return
	r.rows.append([(ts - r.t0) & 0xFFFFFFFF, lin, gyro])


## Number of packets recorded for `slot`.
func count(slot: int) -> int:
	return _rows[slot].rows.size() if _rows.has(slot) else 0


## Ends the recording and returns {slot: csv text} for the phones that sent at least one packet.
func stop() -> Dictionary:
	recording = false
	var out := {}
	for slot in _rows:
		if not _rows[slot].rows.is_empty():
			out[slot] = to_csv(label, slot, _rows[slot].rows)
	_rows = {}
	return out


## Ends the recording and writes one file per phone into `dir`. Returns the paths that were written (global paths).
func save(dir := DIR, stamp := "") -> PackedStringArray:
	var files := stop()
	var paths := PackedStringArray()
	if files.is_empty():
		return paths
	if stamp == "":
		# The milliseconds keep two quick recordings of the same label in the same second apart.
		stamp = Time.get_datetime_string_from_system().replace(":", "").replace("-", "") + "%03d" % (Time.get_ticks_msec() % 1000)
	DirAccess.make_dir_recursive_absolute(dir)
	for slot in files:
		var path := "%s/%s_%s_p%d.csv" % [dir, label, stamp, slot + 1]
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			push_warning("sensor recorder: cannot write %s (%d)" % [path, FileAccess.get_open_error()])
			continue
		f.store_string(files[slot])
		f.close()
		paths.append(ProjectSettings.globalize_path(path))
	return paths


static func to_csv(p_label: String, slot: int, rows: Array) -> String:
	var lines := PackedStringArray([MAGIC, "# label=" + p_label, "# slot=%d" % (slot + 1), HEADER])
	for r in rows:
		var l: Vector3 = r[1]
		var g: Vector3 = r[2]
		lines.append("%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f" % [r[0], l.x, l.y, l.z, g.x, g.y, g.z])
	return "\n".join(lines) + "\n"


## Reads a file made by `save()`: {"ok": bool, "label": String, "slot": int (1 based), "t_ms": PackedInt64Array,
## "lin": PackedVector3Array, "gyro": PackedVector3Array}. A file with a wrong first line or a bad row is `ok == false`.
static func parse(text: String) -> Dictionary:
	var out := {"ok": false, "label": "", "slot": 0, "t_ms": PackedInt64Array(), "lin": PackedVector3Array(),
			"gyro": PackedVector3Array()}
	var lines := text.strip_edges().split("\n")
	if lines.is_empty() or lines[0].strip_edges() != MAGIC:
		return out
	for raw in lines.slice(1):
		var line := raw.strip_edges()
		if line.begins_with("# label="):
			out.label = line.trim_prefix("# label=")
		elif line.begins_with("# slot="):
			out.slot = int(line.trim_prefix("# slot="))
		elif line == HEADER or line == "" or line.begins_with("#"):
			continue
		else:
			var c := line.split(",")
			if c.size() != 7 or not c[0].is_valid_int():
				return out
			for i in range(1, 7):
				if not c[i].is_valid_float():
					return out
			out.t_ms.append(int(c[0]))
			out.lin.append(Vector3(float(c[1]), float(c[2]), float(c[3])))
			out.gyro.append(Vector3(float(c[4]), float(c[5]), float(c[6])))
	out.ok = not out.t_ms.is_empty()
	return out


## The parsed file on a grid of `dt` seconds: every step takes the last packet that is not newer (a gap of lost packets
## repeats the last value). Returns {"lin": PackedVector3Array, "gyro": PackedVector3Array}.
static func resample(parsed: Dictionary, dt := 1.0 / 60.0) -> Dictionary:
	var lin := PackedVector3Array()
	var gyro := PackedVector3Array()
	var t: PackedInt64Array = parsed.t_ms
	if t.is_empty():
		return {"lin": lin, "gyro": gyro}
	var steps := int(floor(t[t.size() - 1] / 1000.0 / dt)) + 1
	var j := 0
	for i in steps:
		var now_ms := i * dt * 1000.0
		while j + 1 < t.size() and t[j + 1] <= now_ms + 0.5:
			j += 1
		lin.append(parsed.lin[j])
		gyro.append(parsed.gyro[j])
	return {"lin": lin, "gyro": gyro}
