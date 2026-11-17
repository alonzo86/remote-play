extends CanvasLayer
## TV debug overlay. Per player: latency, sensor age, packet rate, gaps, loss,
## raw sensor values and fused orientation. Toggle: Menu key or F3.

const PlayerInput = preload("res://scripts/input/player_input.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const SensorRecorder = preload("res://scripts/input/sensor_recorder.gd")

const SWING_LIT_MS := 1500

var _canvas: Control
## The sensor recorder (REQ-T7). F5 starts and stops it, F6 and F7 change the label, while the overlay is on.
var recorder := SensorRecorder.new()
var last_saved := PackedStringArray()


func _ready() -> void:
	layer = 100
	_canvas = _Canvas.new()
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PlayerInput.recorder = recorder
	visibility_changed.connect(_on_visibility_changed)


## Hiding the overlay while it records ends the recording and writes the files (no recording that nobody sees).
func _on_visibility_changed() -> void:
	if not visible and recorder.recording:
		last_saved = recorder.save()


func _exit_tree() -> void:
	if PlayerInput.recorder == recorder:
		PlayerInput.recorder = null


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F5:
			toggle_recording()
		KEY_F6:
			if not recorder.recording:
				recorder.next_label(1)
		KEY_F7:
			if not recorder.recording:
				recorder.next_label(-1)


## Starts a recording, or stops it and writes the files (one for each phone).
func toggle_recording() -> void:
	if recorder.recording:
		last_saved = recorder.save()
	else:
		recorder.start("", Time.get_ticks_msec())


## The first line of the overlay: the room, the address and the frame rate.
static func header_text(room: String, ip: String, fps: float) -> String:
	return _Canvas.header_text(room, ip, fps)


class _Canvas extends Control:
	const COLS := [0, 70, 170, 270, 370, 470, 570, 690, 940, 1190]
	const HEAD := ["Slot", "State", "RTT ms", "Age ms", "Rx Hz", "Gap ms", "Lost", "Gyro rad/s", "Accel m/s2", "Tilt / Pointer"]

	static func header_text(room: String, ip: String, fps: float) -> String:
		return "DEBUG   room %s   %s:%d   %d FPS" % [room, ip, 47801, fps]

	func _process(_d: float) -> void:
		if visible and get_parent().visible:
			queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var fs := 22
		var line := 30.0
		var w := 1500.0
		var rows: Array = App.server.players.filter(func(p): return p.is_present())
		var h: float = 56.0 + line * (5 + maxi(rows.size(), 1) * 2)
		var o := Vector2(40, 40)
		draw_rect(Rect2(o, Vector2(w, h)), Color(0, 0, 0, 0.78))
		var ip: String = App.server.ip if App.server.ip != "" else "?"
		draw_string(font, o + Vector2(16, 30), header_text(App.server.room_code, ip, Engine.get_frames_per_second()),
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.ACCENT)
		var y := o.y + 30 + line
		for c in COLS.size():
			draw_string(font, Vector2(o.x + 16 + COLS[c], y), HEAD[c], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)
		if rows.is_empty():
			draw_string(font, Vector2(o.x + 16, y + line), "No players connected", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)
		for p in rows:
			y += line
			var col: Color = p.color if p.state != PlayerInput.State.EMPTY else UiTheme.TEXT_DIM
			var cells: Array[String] = [
				"P%d" % (p.slot + 1),
				["empty", "ok", "LOST"][p.state],
				"--" if p.rtt_ms < 0 else "%.1f" % p.rtt_ms,
				"--" if not p.has_clock else "%.1f" % p.sensor_age_ms,
				"%.0f" % p.rx_rate,
				str(p.max_gap_ms),
				str(p.lost_packets),
				"%+.2f %+.2f %+.2f" % [p.gyro.x, p.gyro.y, p.gyro.z],
				"%+.2f %+.2f %+.2f" % [p.accel.x, p.accel.y, p.accel.z],
				"%+.2f %+.2f / %+.2f %+.2f" % [p.tilt().x, p.tilt().y, p.pointer().x, p.pointer().y],
			]
			for c in cells.size():
				draw_string(font, Vector2(o.x + 16 + COLS[c], y), cells[c], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		y += line
		for p in rows:
			y += line
			draw_string(font, Vector2(o.x + 16, y), _swing_text(p), HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
					_swing_color(p, Time.get_ticks_msec()))
		y += line * 2
		var rec: SensorRecorder = get_parent().recorder
		draw_string(font, Vector2(o.x + 16, y), record_text(rec, rows, Time.get_ticks_msec()), HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				UiTheme.ACCENT if rec.recording else UiTheme.TEXT_DIM)
		y += line
		var saved: PackedStringArray = get_parent().last_saved
		if not saved.is_empty():
			draw_string(font, Vector2(o.x + 16, y), "saved %d file(s): %s" % [saved.size(), saved[0].get_base_dir()],
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)

	## The recorder line (REQ-T7): the label, the keys, and while recording the time and the packets of every phone.
	static func record_text(rec: SensorRecorder, rows: Array, now_ms: int) -> String:
		if not rec.recording:
			return "RECORD  label: %s   F5 start   F6 / F7 label" % rec.label
		var parts: Array[String] = []
		for p in rows:
			parts.append("P%d %d" % [p.slot + 1, rec.count(p.slot)])
		return "RECORDING %s  %.1f s  packets: %s   F5 stop and save" % [rec.label, rec.seconds(now_ms), "  ".join(parts)]

	## The line of a swing is in the color of the player for `SWING_LIT_MS` after the swing, then dim (`swing_replay`, A-24-3).
	func _swing_color(p: PlayerInput, now_ms: int) -> Color:
		return p.color if now_ms - p.last_swing_ms < SWING_LIT_MS else UiTheme.TEXT_DIM

	func _swing_text(p: PlayerInput) -> String:
		if p.swing_count == 0:
			return "P%d  swing: none yet" % (p.slot + 1)
		var s: Dictionary = p.last_swing
		var w: Vector3 = s.world_dir
		return "P%d  swing %d: power %.2f  %s  side %.2f (x %.2f, to TV %.2f, up %.2f)  hit %d ms ago  %.1f s ago" % [
				p.slot + 1, p.swing_count, s.power, "DOWN" if s.down else "not down", s.side, w.x, w.y, w.z, s.hit_age_ms,
				(Time.get_ticks_msec() - p.last_swing_ms) / 1000.0]
