extends CanvasLayer
## TV debug overlay. Per player: latency, sensor age, packet rate, gaps, loss,
## raw sensor values and fused orientation. Toggle: Menu key or F3.

const PlayerInput = preload("res://scripts/input/player_input.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _canvas: Control


func _ready() -> void:
	layer = 100
	_canvas = _Canvas.new()
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE


class _Canvas extends Control:
	const COLS := [0, 70, 170, 270, 370, 470, 570, 690, 940, 1190]
	const HEAD := ["Slot", "State", "RTT ms", "Age ms", "Rx Hz", "Gap ms", "Lost", "Gyro rad/s", "Accel m/s2", "Tilt / Pointer"]

	func _process(_d: float) -> void:
		if visible and get_parent().visible:
			queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var fs := 22
		var line := 30.0
		var w := 1500.0
		var rows: Array = App.server.players.filter(func(p): return p.is_present())
		var h: float = 56.0 + line * (2 + maxi(rows.size(), 1))
		var o := Vector2(40, 40)
		draw_rect(Rect2(o, Vector2(w, h)), Color(0, 0, 0, 0.78))
		var ip: String = App.discovery.ip if App.discovery != null else "?"
		draw_string(font, o + Vector2(16, 30), "DEBUG   room %s   %s:%d   %d FPS" % [
				App.server.room_code, ip, 47801, Engine.get_frames_per_second()],
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
