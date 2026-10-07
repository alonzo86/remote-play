extends "res://scripts/game/minigame.gd"
## Pointer calibration test. A cursor follows the phone orientation (yaw and pitch).
## Aim at the ring and press A on the phone. The error in pixels is recorded.
## Use it to judge drift, range and latency of gyro pointing.

const Protocol = preload("res://scripts/core/protocol.gd")

const TARGET_R := 46.0
const HIT_R := 90.0

# Target positions as fractions of the safe area (-1..1).
const TARGETS := [
	Vector2(0, 0), Vector2(-0.8, -0.7), Vector2(0.8, -0.7), Vector2(0.8, 0.7),
	Vector2(-0.8, 0.7), Vector2(0, -0.7), Vector2(0.8, 0), Vector2(0, 0.7), Vector2(-0.8, 0),
]

class Stats:
	var index := 0
	var hits := 0
	var error_sum := 0.0
	var last_error := -1.0
	var trail: Array[Vector2] = []

var _stats := {}   # slot -> Stats


func _game_ready() -> void:
	for s in participants:
		_stats[s] = Stats.new()
		player(s).button_pressed.connect(_on_button.bind(s))
	if participants.is_empty():
		open_menu("No players connected", [["Back to menu", App.go_menu]])


func _exit_tree() -> void:
	for s in _stats:
		var cb := _on_button.bind(s)
		if player(s).button_pressed.is_connected(cb):
			player(s).button_pressed.disconnect(cb)


func _can_open_menu() -> bool:
	return not participants.is_empty()


func _area() -> Vector2:
	return Vector2(size.x * 0.5 - 140.0, size.y * 0.5 - 140.0)


func _center() -> Vector2:
	return size * 0.5 + Vector2(0, 30)


func _cursor(slot: int) -> Vector2:
	return _center() + player(slot).pointer() * _area()


func _on_button(bit: int, slot: int) -> void:
	if is_paused() or not _stats.has(slot):
		return
	if bit == Protocol.BTN_B:
		player(slot).recenter()
		return
	if bit != Protocol.BTN_A:
		return
	var st: Stats = _stats[slot]
	var target: Vector2 = _center() + TARGETS[st.index % TARGETS.size()] * _area()
	var err := _cursor(slot).distance_to(target)
	st.last_error = err
	if err <= HIT_R:
		st.hits += 1
		st.error_sum += err
		st.index += 1
		App.server.haptic(slot, 40)
	else:
		App.server.haptic(slot, 15)


func _game_tick(_delta: float) -> void:
	for s in participants:
		var st: Stats = _stats[s]
		st.trail.append(_cursor(s))
		if st.trail.size() > 24:
			st.trail.remove_at(0)


func _game_draw() -> void:
	var font := ThemeDB.fallback_font
	var c := _center()
	var a := _area()
	# Reference grid
	draw_rect(Rect2(c - a, a * 2.0), UiTheme.PANEL, false, 3.0)
	draw_line(c - Vector2(a.x, 0), c + Vector2(a.x, 0), UiTheme.PANEL_LIGHT, 2.0)
	draw_line(c - Vector2(0, a.y), c + Vector2(0, a.y), UiTheme.PANEL_LIGHT, 2.0)
	for ring in [0.33, 0.66, 1.0]:
		draw_arc(c, a.y * ring, 0, TAU, 64, UiTheme.PANEL_LIGHT, 2.0)
	# Targets of every player
	for s in participants:
		var st: Stats = _stats[s]
		var tp: Vector2 = c + TARGETS[st.index % TARGETS.size()] * a
		var col: Color = player(s).color
		draw_arc(tp, TARGET_R + 6.0 * s, 0, TAU, 40, col, 6.0)
		draw_circle(tp, 8, col)
	# Cursors
	for s in participants:
		var st: Stats = _stats[s]
		var col: Color = player(s).color
		for i in st.trail.size():
			draw_circle(st.trail[i], 4.0 + i * 0.25, Color(col, 0.04 * i))
		var cp := _cursor(s)
		draw_circle(cp, 18.0, col)
		draw_arc(cp, 18.0, 0, TAU, 24, Color.WHITE, 3.0)
		draw_line(cp - Vector2(34, 0), cp + Vector2(34, 0), Color.WHITE, 2.0)
		draw_line(cp - Vector2(0, 34), cp + Vector2(0, 34), Color.WHITE, 2.0)
	# HUD
	draw_string(font, Vector2(60, 70), "POINTER TEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, UiTheme.ACCENT)
	draw_string(font, Vector2(60, 112), "Point at the TV and tap Recenter. Aim at your ring. Press A. B recenters.",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 120, 28, UiTheme.TEXT_DIM)
	var y := size.y - 36.0 - 40.0 * (participants.size() - 1)
	for s in participants:
		var st: Stats = _stats[s]
		var o = player(s).orientation
		var avg := "--" if st.hits == 0 else "%.0f px" % (st.error_sum / st.hits)
		var last := "--" if st.last_error < 0 else "%.0f px" % st.last_error
		var txt := "P%d   hits %d   avg error %s   last %s   yaw %+.1f deg   %s" % [
				s + 1, st.hits, avg, last, rad_to_deg(o.yaw), "still" if o.still else "moving"]
		draw_string(font, Vector2(60, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, player(s).color)
		y += 40.0
