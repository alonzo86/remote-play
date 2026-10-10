extends "res://scripts/game/minigame_3d.gd"
## 3D marble race. Each phone tilts its own marble along a winding track. First to the
## finish line wins. Marbles bounce off walls, bumpers and each other.
## Tilt comes from PlayerInput.tilt(). The RECENTER button of the phone recenters (REQ-GM-37). The marbles
## are simulated here in 2D (x, z) with simple physics, so the race is the same on every run.

const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const R := 0.5                 # Marble radius.
const ACCEL := 36.0            # m/s^2 for tilt 1.0. 15 degrees gives about 9.
const DAMPING := 1.0           # 1/s. With 15 degrees, top speed is about 9 m/s.
const WALL_BOUNCE := 0.45
const BUMPER_BOUNCE := 0.9
const MARBLE_BOUNCE := 0.85
const SUBSTEP := 1.0 / 120.0
const GO_SHOW := 0.8           # Seconds to show "GO!".
const END_DELAY := 4.0         # Seconds the others have to finish after the first marble.
const FINISH_BEFORE_END := 6.0 # Finish line distance from the end of the track.
const CAM_MIN_H := 9.0         # Lowest camera height. Lower means bigger marbles on screen.
const EDGE_MARGIN := 60.0      # Out-of-view markers stay inside the TV safe margin.
const HAPTIC_MIN_SPEED := 3.0
const HAPTIC_COOLDOWN_MS := 150

const BUMPER_SIDE := 0.44   # Side 1.0 in the track data, as a fraction of the half-width.
const START_ARC := 2.0         # All marbles start on one line across the track.
const BUMPER_R := 0.9
const POST_COLOR := Color("3ddcff")   # Cyan: not a slot color, not red (REQ-MR-43). A test checks it.
const FLOOR_COLOR := Color("472aa3")  # Purple. Darker than the marbles (REQ-GM-47e).
const RIM_COLOR := UiTheme.OUTLINE    # The black edge of the track. It is the outline color.
const BACKGROUND := Color("1b3a8a")   # Blue from the arcade set (REQ-GM-48).
const NUMBER_MIN_R := 16.0            # A marble is drawn with its slot number from this radius on the HUD (REQ-MR-44).

class Racer:
	var slot := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var arc := 0.0
	var finish_time := -1.0
	var node: MeshInstance3D

## Set before the game starts (REQ-GM-93, REQ-MR-50 to 54). `track_choice` is a choice of the track list ("1" to "10" or
## "random"). The seed it gives is kept in `start_props`, so Restart plays the same track also after "random".
var track_choice := "1"
var difficulty := "medium"
var track_seed := 0
var track
var finish_arc := 0.0

var _racers := {}          # slot -> Racer
var _bumpers: Array[Vector2] = []
var _round := RoundClock.new()   # Race clock. Below 0 the marbles wait on the grid.
var _haptics := Haptics.new()
var _first_finish_time := -1.0
var _winner := -1
var _cam_pos := Vector3.ZERO


func _world_ready() -> void:
	if not start_props.has("track_seed"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		start_props["track_seed"] = MarbleTrack.seed_for(track_choice, rng)
	track_seed = int(start_props.track_seed)
	track = MarbleTrack.make(track_seed, difficulty)
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
		r.node = add_outlined_mesh(world, sphere, player(s).color, Vector3(r.pos.x, R, r.pos.y))
		_racers[s] = r
	_cam_pos = _camera_target()
	_place_camera(1.0)


## REQ-MR-14: when the last player leaves, the base class opens "No players connected".
func _on_player_left(slot: int) -> void:
	if _racers.has(slot):
		_racers[slot].node.queue_free()
		_racers.erase(slot)


func _world_tick(delta: float) -> void:
	if _round.tick(delta):
		for s in participants:
			App.server.haptic(s, 60)
	if _round.is_playing():
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
			r.finish_time = _round.time
			App.server.haptic(r.slot, 120)
			Sound.sfx("marble_finish")
			if _first_finish_time < 0.0:
				_first_finish_time = _round.time
				_winner = r.slot
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
		_buzz(r, vn, "marble_wall_hard" if vn > 2.0 * HAPTIC_MIN_SPEED else "marble_wall")


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
			_buzz(r, -vn, "marble_bumper")


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
		_buzz(a, -rel, "marble_marble")
		_buzz(b, -rel)


func _buzz(r: Racer, speed: float, sound := "") -> void:
	if speed >= HAPTIC_MIN_SPEED:
		_haptics.pulse(r.slot, 20, HAPTIC_COOLDOWN_MS)
		if sound != "":
			Sound.sfx(sound)


func _check_end() -> void:
	if is_over or _winner < 0:
		return
	var all_done := true
	for s in participants:
		if _racers[s].finish_time < 0.0:
			all_done = false
	if all_done or _round.time - _first_finish_time >= END_DELAY:
		_open_results()


# ---- Results menu ----

func _open_results() -> void:
	if participants.is_empty():   # Everyone left after the finish: nobody is left to read a list.
		open_menu("No players connected", [["Back to menu", App.go_menu]])
		return
	# Finished marbles have their time. The others are ranked by how far they got.
	var board := Scoreboard.new([], true)
	for s in participants:
		var r: Racer = _racers[s]
		if r.finish_time >= 0.0:
			board.set_score(s, r.finish_time)
		else:
			board.set_unfinished(s, r.arc)
	open_results(board, [], "", [], func(t: float) -> String: return "%.2f s" % t)


## The results menu leaves the game with Back (REQ-MR-34).
func on_back() -> void:
	if is_over:
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
	return Vector3(mid.x, clampf(CAM_MIN_H + spread * 0.9, CAM_MIN_H, 48.0), mid.y)


func _place_camera(weight: float) -> void:
	_cam_pos = _cam_pos.lerp(_camera_target(), weight)
	camera.position = _cam_pos + Vector3(0, 0, _cam_pos.y * 0.28)
	camera.look_at(Vector3(_cam_pos.x, 0, _cam_pos.z))


# ---- Scene ----

func _perp(dir: Vector2) -> Vector2:
	return Vector2(-dir.y, dir.x)   # For dir (0, -1) this is (1, 0).


func _background_color() -> Color:
	return BACKGROUND


func _build_track() -> void:
	var rim := Node3D.new()
	var floor_n := Node3D.new()
	world.add_child(rim)
	world.add_child(floor_n)
	_strip(rim, track.half_width + 0.35, 0.3, RIM_COLOR, -0.35)
	_strip(floor_n, track.half_width, 0.4, FLOOR_COLOR, -0.2)
	# Finish line: a checkered band across the track, made of boxes (no texture, REQ-GM-47h).
	var dir: Vector2 = track.dir_at(finish_arc)
	var c: Vector2 = track.point_at(finish_arc)
	var line := Node3D.new()
	line.position = Vector3(c.x, 0.03, c.y)
	line.rotation.y = atan2(-dir.x, -dir.y)
	world.add_child(line)
	var frame := BoxMesh.new()
	frame.size = Vector3(track.half_width * 2.0, 0.04, 1.5)
	add_mesh(line, frame, RIM_COLOR, Vector3(0, -0.005, 0))
	var cols := int(roundf(track.half_width * 2.0 / 0.75))
	var cell_w: float = track.half_width * 2.0 / float(cols)
	var cell := BoxMesh.new()
	cell.size = Vector3(cell_w, 0.05, 0.6)
	for row in 2:
		for col in cols:
			var white := (row + col) % 2 == 0
			add_mesh(line, cell, Color.WHITE if white else RIM_COLOR,
					Vector3((col + 0.5) * cell_w - track.half_width, 0.0, (row - 0.5) * 0.6))


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
		add_outlined_mesh(world, post, POST_COLOR, Vector3(pos.x, 0.6, pos.y))


# ---- HUD ----

## Markers for marbles that are out of view (REQ-MR-42): [{slot, pos, dir, text}] in HUD pixels.
func edge_markers() -> Array:
	var out: Array = []
	if camera == null or participants.is_empty():
		return out
	var rect := Rect2(Vector2.ONE * EDGE_MARGIN, hud.size - Vector2.ONE * EDGE_MARGIN * 2.0)
	var center := hud.size * 0.5
	var lead: Racer = standings()[0]
	for s in participants:
		var r: Racer = _racers[s]
		var p3 := Vector3(r.pos.x, R, r.pos.y)
		var sp := world_to_hud(p3)
		if camera.is_position_behind(p3):
			sp = Vector2(center.x, hud.size.y * 2.0)
		if rect.has_point(sp):
			continue
		var dir := (sp - center).normalized()
		var t := minf(rect.size.x * 0.5 / maxf(absf(dir.x), 0.001), rect.size.y * 0.5 / maxf(absf(dir.y), 0.001))
		out.append({"slot": s, "pos": center + dir * t, "dir": dir,
				"text": Lang.f("%d m", [roundi(r.arc - lead.arc)])})
	return out


func _draw_edge_markers(canvas: Control) -> void:
	for m in edge_markers():
		var col: Color = player(m.slot).color
		var d: Vector2 = m.dir
		var side := Vector2(-d.y, d.x)
		var tip: Vector2 = m.pos
		canvas.draw_colored_polygon(PackedVector2Array([tip + d * 34.0, tip - d * 18.0 + side * 26.0,
				tip - d * 18.0 - side * 26.0]), UiTheme.OUTLINE) # A dark outline: readable on any ground.
		canvas.draw_colored_polygon(PackedVector2Array([tip + d * 24.0, tip - d * 12.0 + side * 18.0,
				tip - d * 12.0 - side * 18.0]), col)
		var label_pos: Vector2 = tip - d * 40.0 - Vector2(70, -10)
		Shell.text(canvas, label_pos, m.text, 32, col.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, 140.0)


## The slot numbers of the marbles, at full resolution on top of the pixel view (REQ-GM-47n). A marble that is too small
## on the screen has no number (the camera is high): its color and the edge arrow tell it.
func _draw_marble_numbers(canvas: Control) -> void:
	for s in _racers:
		var p3 := Vector3(_racers[s].pos.x, R, _racers[s].pos.y)
		if camera.is_position_behind(p3):
			continue
		var radius := radius_on_hud(p3, R)
		var sp := world_to_hud(p3)
		if radius >= NUMBER_MIN_R and Rect2(Vector2.ZERO, canvas.size).has_point(sp):
			Shell.ball_number(canvas, sp, radius, player(s).color, s)


func _hud_draw(canvas: Control) -> void:
	_draw_marble_numbers(canvas)
	var y := 36.0
	var place := 0
	for r in standings():
		var p = player(r.slot)
		var t := ""
		if r.finish_time >= 0.0:
			t = "  " + Lang.f("%.2f s", [r.finish_time])
		var msg := "%s  %s%s" % [Scoreboard.ordinal(place + 1), p.player_name, t]
		var chip_w := Shell.score_chip_width(msg, "", 54.0, 400.0)
		Shell.chip(canvas, Vector2(Shell.mx(canvas, 60.0, chip_w), y), msg, p.color, chip_w, 54.0)
		y += 68.0
		place += 1
	if _round.is_counting():
		Shell.countdown(canvas, canvas.size, str(_round.count_number()), _round.count_elapsed())
	elif _round.time < GO_SHOW:
		Shell.countdown(canvas, canvas.size, "GO!", _round.time / GO_SHOW, UiTheme.OK)
	elif not is_over:
		var lead: Racer = standings()[0]
		var to_go := maxf(finish_arc - lead.arc, 0.0)
		Shell.text(canvas, Vector2(0, 90), Lang.f("Finish in %d m", [roundi(to_go)]), 40, UiTheme.ACCENT,
				HORIZONTAL_ALIGNMENT_CENTER, canvas.size.x)
		Shell.text(canvas, Vector2(Shell.mx(canvas, canvas.size.x - 360.0, 300.0), 90), Lang.f("%.1f s", [_round.time]), 40,
				UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT if Lang.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT, 300.0)
	_draw_edge_markers(canvas)
	Shell.text(canvas, Vector2(Shell.mx(canvas, canvas.size.x - 360.0, 300.0), canvas.size.y - 70), track.title, 32,
			UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT if Lang.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT, 300.0)
