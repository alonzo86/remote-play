extends "res://scripts/game/minigame_3d.gd"
## 3D marble race. Each phone tilts its own marble along a winding track. First to the
## finish line wins. Marbles bounce off walls, bumpers and each other.
## Tilt comes from PlayerInput.tilt(). Press B on the phone to recenter. The marbles
## are simulated here in 2D (x, z) with simple physics, so the race is the same on every run.

const Protocol = preload("res://scripts/core/protocol.gd")
const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")

const R := 0.5                 # Marble radius.
const ACCEL := 36.0            # m/s^2 for tilt 1.0. 15 degrees gives about 9.
const DAMPING := 1.0           # 1/s. With 15 degrees, top speed is about 9 m/s.
const WALL_BOUNCE := 0.45
const BUMPER_BOUNCE := 0.9
const MARBLE_BOUNCE := 0.85
const SUBSTEP := 1.0 / 120.0
const COUNTDOWN := 3.0
const GO_SHOW := 0.8           # Seconds to show "GO!".
const END_DELAY := 4.0         # Seconds the others have to finish after the first marble.
const FINISH_BEFORE_END := 6.0 # Finish line distance from the end of the track.
const HAPTIC_MIN_SPEED := 3.0
const HAPTIC_COOLDOWN_MS := 150
const ORDINALS := ["1st", "2nd", "3rd", "4th"]

const BUMPER_SIDE := 0.44   # Side 1.0 in the track data, as a fraction of the half-width.
const START_ARC := 2.0         # All marbles start on one line across the track.
const BUMPER_R := 0.9

class Racer:
	var slot := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var arc := 0.0
	var finish_time := -1.0
	var node: MeshInstance3D
	var last_haptic_ms := 0

## Set before the game starts (App.go props). See marble_track.gd for the ids.
var track_id := "classic"
var track
var finish_arc := 0.0

var _racers := {}          # slot -> Racer
var _bumpers: Array[Vector2] = []
var _time := -COUNTDOWN    # Race clock. Below 0 the marbles wait on the grid.
var _first_finish_time := -1.0
var _winner := -1
var _winner_name := ""
var _picking := false   # True while the track picker is open on the results menu.
var _ended := false
var _cam_pos := Vector3.ZERO


func _world_ready() -> void:
	track = MarbleTrack.make(track_id)
	finish_arc = track.length - FINISH_BEFORE_END
	_build_track()
	_build_bumpers()
	var sphere := SphereMesh.new()
	sphere.radius = R
	sphere.height = R * 2.0
	var n := participants.size()
	for i in n:
		var s: int = participants[i]
		var r := Racer.new()
		r.slot = s
		var side := (float(i) - (n - 1) * 0.5) * 1.3
		r.pos = track.point_at(START_ARC) + _perp(track.dir_at(START_ARC)) * side   # REQ-MR-4
		r.arc = START_ARC
		r.node = add_mesh(world, sphere, player(s).color, Vector3(r.pos.x, R, r.pos.y))
		_racers[s] = r
	_cam_pos = _camera_target()
	_place_camera(1.0)
	if participants.is_empty():
		open_menu("No players connected", [["Back to menu", App.go_menu]])


func _can_open_menu() -> bool:
	return not participants.is_empty() and not _ended


func _on_participants_changed() -> void:
	for s in _racers.keys():
		if not participants.has(s):
			_racers[s].node.queue_free()
			_racers.erase(s)


func _world_tick(delta: float) -> void:
	var was_waiting := _time < 0.0
	_time += delta
	if was_waiting and _time >= 0.0:
		for s in participants:
			App.server.haptic(s, 60)
	if _time >= 0.0:
		var steps := maxi(1, ceili(delta / SUBSTEP))
		for i in steps:
			_step(delta / steps)
	for s in _racers:
		var r: Racer = _racers[s]
		r.node.position = Vector3(r.pos.x, R, r.pos.y)
	_place_camera(clampf(delta * 4.0, 0.0, 1.0))
	_check_end()


func _step(dt: float) -> void:
	var live: Array = []
	for s in participants:
		var r: Racer = _racers[s]
		if r.finish_time < 0.0:
			live.append(r)
			var t: Vector2 = player(s).tilt()
			if t.length() > 1.0:
				t = t.normalized()
			r.vel += t * ACCEL * dt
		r.vel *= exp(-(DAMPING if r.finish_time < 0.0 else 4.0) * dt)
		r.pos += r.vel * dt
		_hit_wall(r)
		_hit_bumpers(r)
		var q: Dictionary = track.query(r.pos)
		r.arc = q.arc
		if r.finish_time < 0.0 and r.arc >= finish_arc:
			r.finish_time = _time
			App.server.haptic(r.slot, 120)
			if _first_finish_time < 0.0:
				_first_finish_time = _time
				_winner = r.slot
				_winner_name = player(r.slot).player_name
	for i in live.size():
		for j in range(i + 1, live.size()):
			_hit_marbles(live[i], live[j])


func _hit_wall(r: Racer) -> void:
	var q: Dictionary = track.query(r.pos)
	var limit: float = track.half_width - R
	if q.dist <= limit:
		return
	var n: Vector2 = (r.pos - q.closest) / q.dist
	r.pos = q.closest + n * limit
	var vn := r.vel.dot(n)
	if vn > 0.0:
		r.vel -= n * vn * (1.0 + WALL_BOUNCE)
		_buzz(r, vn)


func _hit_bumpers(r: Racer) -> void:
	for b in _bumpers:
		var d := r.pos - b
		var dist := d.length()
		var min_d := R + BUMPER_R
		if dist >= min_d:
			continue
		var n := d / dist if dist > 0.0001 else Vector2.RIGHT
		r.pos = b + n * min_d
		var vn := r.vel.dot(n)
		if vn < 0.0:
			r.vel -= n * vn * (1.0 + BUMPER_BOUNCE)
			_buzz(r, -vn)


func _hit_marbles(a: Racer, b: Racer) -> void:
	var d := b.pos - a.pos
	var dist := d.length()
	if dist >= R * 2.0:
		return
	var n := d / dist if dist > 0.0001 else Vector2.RIGHT
	var push := (R * 2.0 - dist) * 0.5
	a.pos -= n * push
	b.pos += n * push
	var rel := (b.vel - a.vel).dot(n)
	if rel < 0.0:
		var j := -(1.0 + MARBLE_BOUNCE) * rel * 0.5   # Equal mass.
		a.vel -= n * j
		b.vel += n * j
		_buzz(a, -rel)
		_buzz(b, -rel)


func _buzz(r: Racer, speed: float) -> void:
	var now := Time.get_ticks_msec()
	if speed >= HAPTIC_MIN_SPEED and now - r.last_haptic_ms >= HAPTIC_COOLDOWN_MS:
		r.last_haptic_ms = now
		App.server.haptic(r.slot, 20)


func _check_end() -> void:
	if _ended or _winner < 0:
		return
	var all_done := true
	for s in participants:
		if _racers[s].finish_time < 0.0:
			all_done = false
	if all_done or _time - _first_finish_time >= END_DELAY:
		_ended = true
		_open_results()


# ---- Results menu ----

func _open_results() -> void:
	_picking = false
	open_menu("%s wins!" % _winner_name,
			[["Restart", restart], ["Choose track", _open_picker], ["Back to menu", App.go_menu]])


func _open_picker() -> void:
	_picking = true
	var entries: Array = []
	for id in MarbleTrack.IDS:
		var title: String = MarbleTrack.make(id).title
		entries.append([title + ("  (now)" if id == track_id else ""), _switch_track.bind(id)])
	entries.append(["Cancel", _open_results])
	open_menu("Choose a track", entries)


func _switch_track(id: String) -> void:
	var props := start_props.duplicate()
	props["track_id"] = id
	App.go(get_script(), props)


## Back from the track picker returns to the results. Back from the results leaves the game.
func on_back() -> void:
	if _ended and _picking:
		_open_results()
	elif _ended:
		App.go_menu()
	else:
		super()


# ---- Standings ----

## Racers from first to last. Finished marbles come first (by time), then by distance.
func standings() -> Array:
	var list: Array = []
	for s in participants:
		list.append(_racers[s])
	list.sort_custom(func(a: Racer, b: Racer) -> bool:
		if (a.finish_time >= 0.0) != (b.finish_time >= 0.0):
			return a.finish_time >= 0.0
		if a.finish_time >= 0.0:
			return a.finish_time < b.finish_time
		return a.arc > b.arc)
	return list


# ---- Camera ----

func _camera_target() -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s in participants:
		var p: Vector2 = _racers[s].pos
		lo = lo.min(p)
		hi = hi.max(p)
	if lo.x == INF:
		return Vector3.ZERO
	var mid := (lo + hi) * 0.5
	var spread := maxf(hi.x - lo.x, hi.y - lo.y)
	return Vector3(mid.x, clampf(16.0 + spread * 0.9, 16.0, 48.0), mid.y)


func _place_camera(weight: float) -> void:
	_cam_pos = _cam_pos.lerp(_camera_target(), weight)
	camera.position = _cam_pos + Vector3(0, 0, _cam_pos.y * 0.28)
	camera.look_at(Vector3(_cam_pos.x, 0, _cam_pos.z))


# ---- Scene ----

func _perp(dir: Vector2) -> Vector2:
	return Vector2(-dir.y, dir.x)   # For dir (0, -1) this is (1, 0).


func _build_track() -> void:
	var rim := Node3D.new()
	var floor_n := Node3D.new()
	world.add_child(rim)
	world.add_child(floor_n)
	_strip(rim, track.half_width + 0.35, 0.3, UiTheme.ACCENT, -0.35)
	_strip(floor_n, track.half_width, 0.4, UiTheme.PANEL_LIGHT, -0.2)
	# Finish line: a white band across the track.
	var dir: Vector2 = track.dir_at(finish_arc)
	var c: Vector2 = track.point_at(finish_arc)
	var band := BoxMesh.new()
	band.size = Vector3(track.half_width * 2.0, 0.05, 1.2)
	var mi := add_mesh(world, band, Color.WHITE, Vector3(c.x, 0.03, c.y))
	mi.rotation.y = atan2(-dir.x, -dir.y)


## Boxes along each segment and discs at the joints. Together they match the drivable area.
func _strip(parent: Node3D, half_w: float, thickness: float, color: Color, y_center: float) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = half_w
	disc.bottom_radius = half_w
	disc.height = thickness
	for i in track.points.size():
		var p: Vector2 = track.points[i]
		add_mesh(parent, disc, color, Vector3(p.x, y_center, p.y))
		if i == track.points.size() - 1:
			break
		var q: Vector2 = track.points[i + 1]
		var seg := BoxMesh.new()
		seg.size = Vector3(half_w * 2.0, thickness, p.distance_to(q))
		var m := add_mesh(parent, seg, color, Vector3((p.x + q.x) * 0.5, y_center, (p.y + q.y) * 0.5))
		m.rotation.y = atan2(p.x - q.x, p.y - q.y)


func _build_bumpers() -> void:
	var post := CylinderMesh.new()
	post.top_radius = BUMPER_R
	post.bottom_radius = BUMPER_R
	post.height = 1.2
	for b in track.bumpers:
		var arc: float = b[0]
		var pos: Vector2 = track.point_at(arc) + _perp(track.dir_at(arc)) * float(b[1]) * track.half_width * BUMPER_SIDE
		_bumpers.append(pos)
		add_mesh(world, post, UiTheme.BAD, Vector3(pos.x, 0.6, pos.y))


# ---- HUD ----

func _hud_draw(canvas: Control) -> void:
	var font := ThemeDB.fallback_font
	var y := 100.0
	var place := 0
	for r in standings():
		var p = player(r.slot)
		canvas.draw_rect(Rect2(60, y - 30, 16, 36), p.color)
		var t := ""
		if r.finish_time >= 0.0:
			t = "   %.2f s" % r.finish_time
		canvas.draw_string(font, Vector2(90, y), "%s  %s%s" % [ORDINALS[place], p.player_name, t],
				HORIZONTAL_ALIGNMENT_LEFT, 600, 32, UiTheme.TEXT)
		y += 48.0
		place += 1
	if _time < 0.0:
		canvas.draw_string(font, Vector2(0, canvas.size.y * 0.42), str(ceili(-_time)),
				HORIZONTAL_ALIGNMENT_CENTER, canvas.size.x, 160, UiTheme.ACCENT)
	elif _time < GO_SHOW:
		canvas.draw_string(font, Vector2(0, canvas.size.y * 0.42), "GO!",
				HORIZONTAL_ALIGNMENT_CENTER, canvas.size.x, 160, UiTheme.OK)
	elif not _ended:
		canvas.draw_string(font, Vector2(canvas.size.x - 360, 100), "%.1f s" % _time,
				HORIZONTAL_ALIGNMENT_RIGHT, 300, 40, UiTheme.TEXT_DIM)
	canvas.draw_string(font, Vector2(canvas.size.x - 360, canvas.size.y - 70), track.title,
			HORIZONTAL_ALIGNMENT_RIGHT, 300, 30, UiTheme.TEXT_DIM)
