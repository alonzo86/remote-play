extends "res://scripts/game/minigame.gd"
## The Amazing Race. Each phone tilts its own car along a winding road. First to the finish line wins. Cars bounce off the
## walls, the obstacles and each other. The game is a flat pixel world seen from above (REQ-MR-40 to 47) in a theme that the
## player picks (candy, space, jungle).
## Tilt comes from PlayerInput.tilt(). The RECENTER button of the phone recenters (REQ-GM-37). The cars are simulated here in 2D
## (x, y in meters) with simple physics, so the race is the same on every run.

const MarbleTrack = preload("res://scripts/game/marble_race/marble_track.gd")
const RaceLook = preload("res://scripts/game/marble_race/race_look.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const R := 0.5                 # Car radius for the physics.
const ACCEL := 36.0            # m/s^2 for tilt 1.0. 15 degrees gives about 9.
const DAMPING := 1.0           # 1/s. With 15 degrees, top speed is about 9 m/s.
const WALL_BOUNCE := 0.45
const BUMPER_BOUNCE := 0.9
const CAR_BOUNCE := 0.85
const SUBSTEP := 1.0 / 120.0
const GO_SHOW := 0.8           # Seconds to show "GO!".
const END_DELAY := 4.0         # Seconds the others have to finish after the first car.
const FINISH_BEFORE_END := 6.0 # Finish line distance from the end of the track.
const SCALE := 32.0            # Screen units for one meter: 8 world pixels.
const ANCHOR_Y := 620.0        # Where the middle of the pack is on the screen: under the black bar, the road ahead is above.
const BAR_H := 112.0           # The black bar for the title and the timer.
const TIMER_X := 640.0
const EDGE_MARGIN := 60.0      # Out-of-view markers stay inside the TV safe margin.
const HAPTIC_MIN_SPEED := 3.0
const HAPTIC_COOLDOWN_MS := 150
const TURN_STEP := 15.0        # A car turns in steps of 15 degrees, like a pixel picture does.
const TURN_MIN_SPEED := 0.8    # A slower car keeps its direction.
const CAR_TAG_RADIUS := 40.0

const BUMPER_SIDE := 0.44   # Side 1.0 in the track data, as a fraction of the half-width.
const START_ARC := 2.0         # All cars start on one line across the track.
const BUMPER_R := 0.9

class Racer:
	var slot := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var arc := 0.0
	var finish_time := -1.0
	var angle := 0.0     # The direction of the car in radians; 0 is up.

## Set before the game starts (REQ-GM-93, REQ-MR-50 to 54). `track_choice` is a choice of the track list ("1" to "10" or
## "random"). The seed it gives is kept in `start_props`, so Restart plays the same track also after "random".
## `race_theme` is a key of `RaceLook.THEMES` (REQ-MR-45); an unknown one gives the default.
var track_choice := "1"
var difficulty := "medium"
var race_theme := RaceLook.DEFAULT_THEME
var track_seed := 0
var track
var finish_arc := 0.0

var _racers := {}          # slot -> Racer
var _bumpers: Array[Vector2] = []
var _bumper_kinds: Array[String] = []   # The obstacle picture of each bumper, from the theme.
var _round := RoundClock.new()   # Race clock. Below 0 the cars wait on the grid.
var _haptics := Haptics.new()
var _first_finish_time := -1.0
var _winner := -1
var _cam := Vector2.ZERO   # The middle of the view, in meters.
var _cam_set := false
var _board: Dictionary = {}                 # {image, origin} of `RaceLook.render()`, made at the first frame.
var _board_tex: ImageTexture
var _ground_tex: ImageTexture
var _obstacle_tex := {}    # kind -> ImageTexture
var _car_tex := {}         # slot -> ImageTexture


func _game_ready() -> void:
	race_theme = RaceLook.theme_or_default(race_theme)
	if not start_props.has("track_seed"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		start_props["track_seed"] = MarbleTrack.seed_for(track_choice, rng)
	track_seed = int(start_props.track_seed)
	track = MarbleTrack.make(track_seed, difficulty)
	finish_arc = track.length - FINISH_BEFORE_END
	_build_bumpers()
	var n := participants.size()
	for i in n:
		var s: int = participants[i]
		var r := Racer.new()
		r.slot = s
		var side := (float(i) - (n - 1) * 0.5) * 1.3
		r.pos = track.point_at(START_ARC) + _perp(track.dir_at(START_ARC)) * side   # REQ-MR-4
		r.arc = START_ARC
		_racers[s] = r


## REQ-MR-14: when the last player leaves, the base class opens "No players connected".
func _on_player_left(slot: int) -> void:
	_racers.erase(slot)


func _game_tick(delta: float) -> void:
	if _round.tick(delta):
		for s in participants:
			App.server.haptic(s, 60)
	if _round.is_playing():
		var steps := maxi(1, ceili(delta / SUBSTEP))
		for i in steps:
			_step(delta / steps)
	for s in _racers:
		_turn(_racers[s])
	_cam = _cam.lerp(_camera_target(), clampf(delta * 4.0, 0.0, 1.0) if _cam_set else 1.0)
	_cam_set = size.x > 0.0   # The first frame with a screen size puts the camera on the pack, with no slide.
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
			_hit_cars(live[i], live[j])


## A car faces the way it moves, in steps of `TURN_STEP` degrees. A car that is almost still keeps its direction.
func _turn(r: Racer) -> void:
	if r.vel.length() >= TURN_MIN_SPEED:
		r.angle = snappedf(atan2(r.vel.x, -r.vel.y), deg_to_rad(TURN_STEP))


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


func _hit_cars(a: Racer, b: Racer) -> void:
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
		var j := -(1.0 + CAR_BOUNCE) * rel * 0.5   # Equal mass.
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
	# Finished cars have their time. The others are ranked by how far they got.
	open_results(_scoreboard(), [], "", [], func(t: float) -> String: return Lang.f("%.2f s", [t]))


## The results menu leaves the game with Back (REQ-MR-34).
func on_back() -> void:
	if is_over:
		App.go_menu()
	else:
		super()


# ---- Standings ----

## Racers from first to last. Finished cars come first (by time), then by distance.
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

## The middle of the pack. When the pack is too spread out for the screen, the leader stays in view (the others get an arrow).
func _camera_target() -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s in participants:
		var p: Vector2 = _racers[s].pos
		lo = lo.min(p)
		hi = hi.max(p)
	if lo.x == INF:
		return Vector2.ZERO
	var mid := (lo + hi) * 0.5
	var lead: Vector2 = standings()[0].pos
	var ahead := (ANCHOR_Y - BAR_H - 160.0) / SCALE
	var behind := (size.y - ANCHOR_Y - 160.0) / SCALE
	var across := (size.x * 0.5 - 220.0) / SCALE
	var d := (lead - mid).clamp(Vector2(-across, -ahead), Vector2(across, behind))
	return lead - d


## The top-left world pixel of the view: the camera is on the world pixel grid.
func _view_origin() -> Vector2i:
	var cam_px := Vector2i((_cam * float(RaceLook.PX)).round())
	return cam_px - Vector2i(roundi(size.x / 8.0), roundi(ANCHOR_Y / Shell.WORLD_PIXEL))


## The screen position of a point of the track (meters), on the world pixel grid.
func _screen(p: Vector2) -> Vector2:
	var wp := Vector2i((p * float(RaceLook.PX)).round()) - _view_origin()
	return Vector2(wp) * Shell.WORLD_PIXEL


func _perp(dir: Vector2) -> Vector2:
	return Vector2(-dir.y, dir.x)   # For dir (0, -1) this is (1, 0).


func _build_bumpers() -> void:
	var kinds: Array = RaceLook.look(race_theme).obstacles
	for i in track.bumpers.size():
		var b: Array = track.bumpers[i]
		var arc: float = b[0]
		_bumpers.append(track.point_at(arc) + _perp(track.dir_at(arc)) * float(b[1]) * track.half_width * BUMPER_SIDE)
		_bumper_kinds.append(String(kinds[(i + track_seed) % kinds.size()]))


# ---- The world ----

func _pixel_world() -> bool:
	return true


func _make_board() -> void:
	var line: Array[Vector2] = track.points
	_board = RaceLook.render(race_theme, line, track.half_width, track.point_at(finish_arc), track.dir_at(finish_arc))
	_board_tex = ImageTexture.create_from_image(_board.image)
	_ground_tex = ImageTexture.create_from_image(RaceLook.ground_tile(race_theme))


func _obstacle_texture(kind: String) -> ImageTexture:
	if not _obstacle_tex.has(kind):
		_obstacle_tex[kind] = ImageTexture.create_from_image(RaceLook.obstacle_image(race_theme, kind))
	return _obstacle_tex[kind]


func _car_texture(slot: int) -> ImageTexture:
	if not _car_tex.has(slot):
		_car_tex[slot] = ImageTexture.create_from_image(RaceLook.car_image(player(slot).color))
	return _car_tex[slot]


## The world (REQ-GM-47i): the ground, the board with the road and the finish line, the obstacles, the cars and the black bar.
func _world_draw(ci: CanvasItem) -> void:
	if _board.is_empty():
		_make_board()   # At the first frame, when the size of the screen is known.
	var px := Shell.WORLD_PIXEL
	var origin := _view_origin()
	var view := Vector2i(roundi(size.x / px), roundi(size.y / px))
	var tile := RaceLook.TILE
	for ty in range(floori(float(origin.y) / tile), floori(float(origin.y + view.y) / tile) + 1):
		for tx in range(floori(float(origin.x) / tile), floori(float(origin.x + view.x) / tile) + 1):
			ci.draw_texture_rect(_ground_tex, Rect2((Vector2(tx, ty) * tile - Vector2(origin)) * px, Vector2.ONE * tile * px), false)
	var board_origin: Vector2i = _board.origin
	var image: Image = _board.image
	var whole := Rect2(0, 0, image.get_width(), image.get_height())
	var shown := Rect2(Vector2(origin - board_origin), Vector2(view)).intersection(whole)
	if shown.has_area():
		ci.draw_texture_rect_region(_board_tex, Rect2((shown.position + Vector2(board_origin) - Vector2(origin)) * px, shown.size * px),
				shown)
	for i in _bumpers.size():
		var tex := _obstacle_texture(_bumper_kinds[i])
		var sz := Vector2(tex.get_size()) * px
		ci.draw_texture_rect(tex, Rect2(Shell.snap(_screen(_bumpers[i]) - sz * 0.5), sz), false)
	for s in participants:
		if _racers.has(s):
			_draw_car(ci, _racers[s])
	ci.draw_rect(Rect2(0, 0, size.x, BAR_H), UiTheme.BG)


func _draw_car(ci: CanvasItem, r: Racer) -> void:
	var tex := _car_texture(r.slot)
	var sz := Vector2(tex.get_size()) * Shell.WORLD_PIXEL
	ci.draw_set_transform(_screen(r.pos), r.angle, Vector2.ONE)
	ci.draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---- HUD ----

## Markers for cars that are out of view (REQ-MR-42): [{slot, pos, dir, text}] in screen units.
func edge_markers() -> Array:
	var out: Array = []
	if participants.is_empty() or _racers.is_empty():
		return out
	var rect := Rect2(Vector2(EDGE_MARGIN, BAR_H + 24.0), Vector2(size.x - EDGE_MARGIN * 2.0, size.y - BAR_H - 24.0 - EDGE_MARGIN))
	var center := rect.get_center()
	var lead: Racer = standings()[0]
	for s in participants:
		var r: Racer = _racers[s]
		var sp := (r.pos - _cam) * SCALE + Vector2(size.x * 0.5, ANCHOR_Y)
		if rect.has_point(sp):
			continue
		var dir := (sp - center).normalized()
		var t := minf(rect.size.x * 0.5 / maxf(absf(dir.x), 0.001), rect.size.y * 0.5 / maxf(absf(dir.y), 0.001))
		out.append({"slot": s, "pos": center + dir * t, "dir": dir, "text": Lang.f("%d m", [roundi(r.arc - lead.arc)])})
	return out


func _draw_edge_markers() -> void:
	for m in edge_markers():
		var col: Color = player(m.slot).color
		var d: Vector2 = m.dir
		var side := Vector2(-d.y, d.x)
		var tip: Vector2 = m.pos
		draw_colored_polygon(PackedVector2Array([tip + d * 34.0, tip - d * 18.0 + side * 26.0,
				tip - d * 18.0 - side * 26.0]), UiTheme.OUTLINE) # A dark outline: readable on any ground.
		draw_colored_polygon(PackedVector2Array([tip + d * 24.0, tip - d * 12.0 + side * 18.0,
				tip - d * 12.0 - side * 18.0]), col)
		var label_pos: Vector2 = tip - d * 40.0 - Vector2(70, -10)
		Shell.text(self, label_pos, m.text, 32, col.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, 140.0)


## The screen position of each car (the name tags of the countdown, REQ-GM-46a).
func _car_spots() -> Dictionary:
	var spots := {}
	for s in _racers:
		spots[s] = _screen(_racers[s].pos)
	return spots


## The place of each car: the finish times first, then how far the others got (REQ-FL-67).
func _scoreboard() -> Scoreboard:
	var board := Scoreboard.new([], true)
	for s in participants:
		var r: Racer = _racers[s]
		if r.finish_time >= 0.0:
			board.set_score(s, r.finish_time)
		else:
			board.set_unfinished(s, r.arc)
	return board


func _score_label(entry: Dictionary) -> String:
	return Lang.f("%.2f s", [entry.score]) if entry.finished else ""


func _game_draw() -> void:
	Shell.title(self, "THE AMAZING RACE")
	draw_leader_chip(self)
	if _round.is_counting():
		Shell.countdown(self, size, str(_round.count_number()), _round.count_elapsed())
		draw_name_tags(self, _car_spots(), CAR_TAG_RADIUS)
	elif _round.time < GO_SHOW:
		Shell.countdown(self, size, "GO!", _round.time / GO_SHOW, UiTheme.OK)
	elif not is_over:
		var lead: Racer = standings()[0]
		var to_go := maxf(finish_arc - lead.arc, 0.0)
		Shell.text(self, Vector2(Shell.mx(self, 960.0, 480.0), 80.0), Lang.f("Finish in %d m", [roundi(to_go)]), 32,
				UiTheme.ACCENT, HORIZONTAL_ALIGNMENT_LEFT if not Lang.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT, 480.0)
		Shell.timer(self, Vector2(TIMER_X, 36.0), _round.time, 240.0)
	_draw_edge_markers()
	Shell.text(self, Vector2(Shell.mx(self, size.x - 360.0, 300.0), size.y - 70), track.title, 32,
			UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT if Lang.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT, 300.0)


## Only the 10 fixed tracks have a personal best; a random track has none (REQ-MR-56).
func best_key() -> String:
	var i := MarbleTrack.FIXED_SEEDS.find(track_seed)
	return "marble_race|%s|%d" % [difficulty, i + 1] if i >= 0 else ""


## The time of a finish in milliseconds.
func best_value(score: float) -> int:
	return roundi(score * 1000.0)
