extends SceneTree
## Test 24 step 12d (REQ-T7): the sensor recorder of the debug overlay. A recording of a made-up swing is written as CSV, read
## back, put on the 60 Hz grid of tests/sensor_replay.gd and replayed in the swing detector: the detector finds the same swing
## as in the original trace. Also: the packets of a phone reach the recorder, the labels, bad files.
## Run: godot --headless --path . --script tests/sensor_recorder.gd -- --role=tv

const R = preload("res://tests/sensor_replay.gd")
const SensorRecorder = preload("res://scripts/input/sensor_recorder.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const SwingDetector = preload("res://scripts/input/swing_detector.gd")

var DebugOverlay = null   # Loaded when the tests run: the overlay script uses the App autoload.
var _checks := 0
var _fails := 0


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _detect(trace: R.Trace) -> Dictionary:
	var det := SwingDetector.new()
	return R.run_detector(det, trace)


## A trace as a `Feeder` sends it to a phone slot while the recorder runs. Returns the recorder text of the slot.
func _record(rec: SensorRecorder, trace: R.Trace, slot := 0) -> void:
	var p := PlayerInput.new(slot, {})
	var f := R.Feeder.new(p, R.UP_UPRIGHT)
	f.settle(0.5)
	rec.start("swing_hard", 0)
	f.feed(trace)


func _run() -> void:
	await process_frame
	DebugOverlay = load("res://scripts/ui/debug_overlay.gd")
	_round_trip()
	_packets_reach_the_recorder()
	_row_cap()
	_labels()
	_files()
	_bad_files()
	_overlay_line()
	_overlay_hidden_while_recording()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _round_trip() -> void:
	print("csv round trip into the detector")
	var trace := R.still(0.5).append(R.pendulum(Vector3(1, 0, 0), 10.0, 25.0, 0.6)).append(R.still(1.0))
	var rows: Array = []
	for i in trace.size():
		rows.append([roundi(i * R.DT * 1000.0), trace.lin[i], trace.gyro[i]])
	var text := SensorRecorder.to_csv("swing_hard", 0, rows)
	var head := SensorRecorder.MAGIC + "\n# label=swing_hard\n# slot=1\n" + SensorRecorder.HEADER + "\n"
	_check(text.begins_with(head), "the file starts with the format line, the label, the slot and the column names")
	var parsed := SensorRecorder.parse(text)
	_check(parsed.ok and parsed.label == "swing_hard" and parsed.slot == 1, "the file is read back with its label and slot")
	_check(parsed.t_ms.size() == trace.size(), "every row is read back (%d of %d)" % [parsed.t_ms.size(), trace.size()])
	var grid := SensorRecorder.resample(parsed)
	var back := R.Trace.new()
	for i in grid.lin.size():
		back.add(grid.lin[i], grid.gyro[i])
	_check(absi(back.size() - trace.size()) <= 1, "60 Hz rows come back as the same number of steps (%d, %d)"
			% [back.size(), trace.size()])
	var worst := 0.0
	for i in mini(back.size(), trace.size()):
		worst = maxf(worst, back.lin[i].distance_to(trace.lin[i]))
	_check(worst < 0.001, "the acceleration is kept to 4 decimals (worst error %.5f m/s2)" % worst)
	var before := _detect(trace)
	var after := _detect(back)
	_check(before.releases.size() == 1, "the made-up swing is a swing (%d)" % before.releases.size())
	_check(after.releases.size() == before.releases.size()
			and absf(after.releases[0].power - before.releases[0].power) < 0.01,
			"the recorded swing is found like the original, with the same power (%.3f, %.3f)"
			% [before.releases[0].power, after.releases[0].power])
	var two := [[0, Vector3.ZERO, Vector3.ZERO], [1000, Vector3.ZERO, Vector3.ZERO]]
	var still_back := SensorRecorder.resample(SensorRecorder.parse(SensorRecorder.to_csv("sweep", 1, two)))
	_check(still_back.lin.size() == 61, "1 s of packets is 61 steps of 1/60 s (%d)" % still_back.lin.size())
	# A lost stretch of packets repeats the last value.
	var gap := SensorRecorder.resample(SensorRecorder.parse(SensorRecorder.to_csv("sweep", 0,
			[[0, Vector3(1, 0, 0), Vector3.ZERO], [500, Vector3(2, 0, 0), Vector3.ZERO]])))
	_check(gap.lin[10].x == 1.0 and gap.lin[gap.lin.size() - 1].x == 2.0, "a gap of lost packets keeps the last value")


func _row_cap() -> void:
	print("a long recording")
	var rec := SensorRecorder.new()
	rec.start("sweep", 0)
	for i in SensorRecorder.MAX_ROWS + 500:
		rec.add(0, i, Vector3.ZERO, Vector3.ZERO)
	_check(rec.count(0) == SensorRecorder.MAX_ROWS,
			"the rows of one phone stop at %d (%d)" % [SensorRecorder.MAX_ROWS, rec.count(0)])
	rec.add(1, 0, Vector3.ZERO, Vector3.ZERO)
	_check(rec.count(1) == 1, "another phone still records")


func _packets_reach_the_recorder() -> void:
	print("packets of a phone")
	var rec := SensorRecorder.new()
	PlayerInput.recorder = rec
	var trace := R.push(Vector3(1, 0, 0), 20.0, 0.05).append(R.still(0.5))
	_record(rec, trace, 2)
	_check(rec.count(2) == trace.size(), "every packet of phone P3 is recorded (%d of %d)" % [rec.count(2), trace.size()])
	_check(rec.count(0) == 0, "a phone that sent nothing has no rows")
	var files := rec.stop()
	_check(files.keys() == [2] and not rec.recording, "stop() gives one file for the phone that sent packets and ends the recording")
	var parsed := SensorRecorder.parse(files[2])
	_check(parsed.slot == 3 and parsed.lin[0].length() > 5.0, "the first row is the push (slot 3, %.1f m/s2)"
			% parsed.lin[0].length())
	# Packets outside a recording are dropped.
	var p := PlayerInput.new(0, {})
	var f := R.Feeder.new(p, R.UP_UPRIGHT)
	f.feed(R.still(0.2))
	_check(rec.count(0) == 0, "nothing is recorded while the recorder is off")
	PlayerInput.recorder = null


func _labels() -> void:
	print("labels")
	var rec := SensorRecorder.new()
	_check(rec.label == "sweep", "the first label is sweep")
	for i in SensorRecorder.LABELS.size():
		rec.next_label(1)
	_check(rec.label == "sweep", "6 steps forward come back to the first of the 6 labels")
	rec.next_label(-1)
	_check(rec.label == "swing_hard", "one step back from the first label is the last (swing_hard)")


func _files() -> void:
	print("files")
	var dir := "user://sensor_traces_test"
	var rec := SensorRecorder.new()
	rec.start("hard_shake", 0)
	rec.add(0, 1000, Vector3(1, 2, 3), Vector3(0.1, 0.2, 0.3))
	rec.add(0, 1016, Vector3(2, 2, 3), Vector3.ZERO)
	rec.add(1, 5000, Vector3(0, 0, 9), Vector3.ZERO)
	var paths := rec.save(dir, "20261101T120000")
	_check(paths.size() == 2, "one file for each of the 2 phones (%d)" % paths.size())
	var p1: String = dir + "/hard_shake_20261101T120000_p1.csv"
	_check(FileAccess.file_exists(p1) and FileAccess.file_exists(dir + "/hard_shake_20261101T120000_p2.csv"),
			"the files are named label, time, phone")
	var parsed := SensorRecorder.parse(FileAccess.get_file_as_string(p1))
	_check(parsed.ok and parsed.t_ms == PackedInt64Array([0, 16]) and parsed.lin[0] == Vector3(1, 2, 3),
			"the file on disk has the times from the first packet and the values")
	_check(rec.save(dir).is_empty(), "saving again with no packets writes nothing")
	# Two quick recordings of one label, saved in the same second, do not overwrite each other.
	var names := {}
	for i in 2:
		rec.start("sweep", 0)
		rec.add(0, 0, Vector3.ZERO, Vector3.ZERO)
		for path in rec.save(dir):
			names[path] = true
		OS.delay_msec(5)
	_check(names.size() == 2, "two recordings of one label one after the other are two files (%d)" % names.size())
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	DirAccess.remove_absolute(dir)


func _bad_files() -> void:
	print("bad files")
	_check(not SensorRecorder.parse("").ok, "an empty file is not a trace")
	_check(not SensorRecorder.parse("t_ms,lin_x\n0,1").ok, "a file with no format line is not a trace")
	var head := SensorRecorder.MAGIC + "\n" + SensorRecorder.HEADER + "\n"
	_check(not SensorRecorder.parse(head + "0,1,2").ok, "a row with too few cells is not a trace")
	_check(not SensorRecorder.parse(head + "0,a,2,3,4,5,6").ok, "a row with a word instead of a number is not a trace")
	_check(not SensorRecorder.parse(head).ok, "a file with no rows is not a trace")


func _overlay_hidden_while_recording() -> void:
	print("overlay hidden while recording")
	var overlay = DebugOverlay.new()
	root.add_child(overlay)
	overlay.recorder.start("sweep", 0)
	overlay.recorder.add(0, 0, Vector3.ZERO, Vector3.ZERO)
	overlay.visible = false
	_check(not overlay.recorder.recording and overlay.last_saved.size() == 1,
			"hiding the overlay ends the recording and writes the file")
	for path in overlay.last_saved:
		DirAccess.remove_absolute(path)
	root.remove_child(overlay)
	overlay.free()
	_check(PlayerInput.recorder == null, "a removed overlay does not leave its recorder in PlayerInput")


func _overlay_line() -> void:
	print("overlay line")
	var rec := SensorRecorder.new()
	var p := PlayerInput.new(1, {})
	var idle: String = DebugOverlay._Canvas.record_text(rec, [p], 0)
	_check(idle.contains("label: sweep") and idle.contains("F5") and not idle.contains("RECORDING"),
			"idle: the line names the label and the keys (%s)" % idle)
	rec.start("", 1000)
	rec.add(1, 0, Vector3.ZERO, Vector3.ZERO)
	rec.add(1, 16, Vector3.ZERO, Vector3.ZERO)
	var on: String = DebugOverlay._Canvas.record_text(rec, [p], 3500)
	_check(on.contains("RECORDING sweep") and on.contains("2.5 s") and on.contains("P2 2"),
			"recording: the line names the label, the time and the packets of P2 (%s)" % on)
