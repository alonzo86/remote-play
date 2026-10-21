extends "res://scripts/game/minigame.gd"
## Mini Golf: a golf park for 1 to 4 phones (REQ-MG-1 to 16). The players putt in turns, one putt each, on 1 to 5 holes. Turning
## the phone moves the aim, the first back swing locks it, and the swing speed sets the power. The rules are in golf_rules.gd, the
## ball in golf_sim.gd, the courses in golf_holes.gd, the swing in swing_detector.gd and the pictures in golf_look.gd. The game
## is for children too (REQ-GM-80 to 84): a turn has no time limit, water costs nothing and a hole ends after 6 strokes.

const GolfRules = preload("res://scripts/game/mini_golf/golf_rules.gd")
const GolfSim = preload("res://scripts/game/mini_golf/golf_sim.gd")
const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")
const GolfLook = preload("res://scripts/game/mini_golf/golf_look.gd")
const SwingDetector = preload("res://scripts/input/swing_detector.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const TURN_BANNER := 1.5        # REQ-MG-3: how long the name of the player on turn shows.
const RESULT_TIME := 1.8        # How long the banner of a putt shows. A press on A of any phone ends it at once.
const QUIET_TIME := 0.5         # After a putt with nothing to say.
const HOLE_TIME := 4.0          # The card at the end of a hole.
const END_DELAY := 1.2
const HINT_TIME := 12.0
const WEAK_HINT_TIME := 3.0
const BUZZ_GAP_MS := 150
const MAX_HEADING := 1.2        # The aim can turn this far to each side (radians).
const PAUSE_GAP_MS := 400
const BAR_H := 56.0
const BAR_MARGIN := 24.0

enum Phase { AIM, ROLL, RESULT, HOLE, END }

## What Difficulty means (REQ-MG-13): `line` is the length of the aim line in course units (0 for the marker only), `speed_min`
## is the speed of the weakest putt (m/s), `threshold` is a factor on the swing thresholds, `power_hint` shows the hint about the
## swing.
const LEVELS := {
	"easy": {"line": 3.0, "speed_min": 1.5, "threshold": 0.7, "power_hint": true},
	"medium": {"line": 1.2, "speed_min": 0.5, "threshold": 1.0, "power_hint": false},
	"hard": {"line": 0.0, "speed_min": 0.3, "threshold": 1.0, "power_hint": false},
}

## Set before the game starts (REQ-GM-93). `start_props` keeps them for Try again.
var difficulty := "medium"
var holes := "3"

var rules := GolfRules.new()
var sim := GolfSim.new()
var detector := SwingDetector.new()
var phase := Phase.AIM

var _board: Scoreboard
var _scored := false
var _haptics := Haptics.new()
var _hole: Dictionary = {}
var _time := 0.0
var _phase_time := 0.0
var _end_left := 0.0
var _heading := 0.0
var _spot := Vector2.ZERO       # Where the last putt started: the ball goes back here from the water.
var _feet := Vector2.ZERO
var _swing_age := 99.0
var _lock_age := 0.0            # How long the direction is locked.
var _banner := ""
var _banner_color := UiTheme.ACCENT
var _weak_left := 0.0
var _last_tick_ms := 0
var _a_pressed := false
var _a_down := {}
var _splash_at := Vector2.ZERO
var _splash_age := 99.0
var _spark_age := 99.0
var _last_event := {}
var _putter := -1               # The slot of the golfer who is drawn.
var _balls := {}                # slot -> where the ball of that player lies on this hole.


static func level(d: String) -> Dictionary:
	return LEVELS.get(d, LEVELS.medium)


func _has_countdown() -> bool:
	return false   # No visible timer, so no countdown (REQ-GM-35): the first turn starts at once.


func _game_ready() -> void:
	var slots: Array[int] = []
	slots.assign(participants)
	rules.setup(slots, int(holes))
	_board = Scoreboard.new(participants, true)
	for s in participants:
		_board.set_unfinished(s, 0.0)
	detector.threshold = float(level(difficulty).threshold)
	_load_hole()
	if not participants.is_empty():
		_start_turn()


func _load_hole() -> void:
	_hole = Holes.hole(rules.hole_number())
	_spot = _hole.tee
	sim.start(_hole, _spot)
	_putter = -1


func _on_player_left(slot: int) -> void:
	var was_turn := rules.current_slot() == slot
	rules.remove_player(slot)
	_board.remove(slot)
	_a_down.erase(slot)
	_balls.erase(slot)
	if is_over:
		return
	if rules.rows.is_empty():
		return
	if rules.hole_done() and phase != Phase.HOLE and phase != Phase.END:
		_begin_hole_done()
	elif was_turn and (phase == Phase.AIM or phase == Phase.ROLL):
		_start_turn()


# ---- The turns ----

func _start_turn() -> void:
	var slot := rules.current_slot()
	if slot < 0:
		_begin_hole_done()
		return
	phase = Phase.AIM
	_phase_time = 0.0
	_banner = ""
	_weak_left = 0.0
	_swing_age = 99.0
	_heading = 0.0
	_putter = slot
	sim.start(_hole, _ball_of(slot))
	_spot = sim.pos
	_feet = GolfLook.feet_for(sim.pos)
	detector.reset()
	detector.threshold = float(level(difficulty).threshold)
	player(slot).recenter()   # The pose at the start of the turn is straight ahead (REQ-MG-4).
	Sound.sfx("golf_turn")
	_haptics.pulse(slot, 60, BUZZ_GAP_MS)


func _game_tick(delta: float) -> void:
	_time += delta
	_splash_age += delta
	_spark_age += delta
	_swing_age += delta
	_lock_age = _lock_age + delta if detector.aim_locked else 0.0
	if is_over:
		return
	_publish_turn()
	_phase_time += delta
	_weak_left = maxf(0.0, _weak_left - delta)
	_poll_buttons()
	match phase:
		Phase.AIM:
			_tick_aim(delta)
		Phase.ROLL:
			_tick_roll(delta)
		Phase.RESULT:
			var wait := RESULT_TIME if _banner != "" else QUIET_TIME
			if _phase_time >= wait or (_banner != "" and _a_pressed):
				_after_result()
		Phase.HOLE:
			if _phase_time >= HOLE_TIME or _a_pressed:
				_after_hole()
		Phase.END:
			_end_left -= delta
			if _end_left <= 0.0:
				_finish()
	_last_tick_ms = Time.get_ticks_msec()


## Tells each phone whose turn it is (REQ-MG-3). The server sends a changed message only.
func _publish_turn() -> void:
	var on := rules.current_slot() if phase == Phase.AIM or phase == Phase.ROLL else -1
	for s in participants:
		if on < 0:
			App.server.send_turn(s, 0, "", "golf")
		elif s == on:
			App.server.send_turn(s, 1, "", "golf")
		else:
			App.server.send_turn(s, 2, player(on).player_name, "golf")


## Polls A on every tick, in every phase, so a button held since an earlier phase is not read as a new press (the putt banner
## is not skipped by a held A). `_a_pressed` is true when a press on A starts on any phone this tick.
func _poll_buttons() -> void:
	var pressed := false
	for s in participants:
		var down := player(s).is_down(Protocol.BTN_A)
		if down and not _a_down.get(s, false):
			pressed = true
		_a_down[s] = down
	_a_pressed = pressed


func _tick_aim(delta: float) -> void:
	var slot := rules.current_slot()
	if slot < 0:
		_begin_hole_done()
		return
	var p := player(slot)
	if _last_tick_ms > 0 and Time.get_ticks_msec() - _last_tick_ms > PAUSE_GAP_MS:
		detector.reset()   # The game was paused: a swing that was under way starts again.
	if not detector.aim_locked:
		_heading = clampf(-p.yaw_offset(), -MAX_HEADING, MAX_HEADING)
	detector.update(delta, p.linear_accel())
	if detector.weak:
		_weak_left = WEAK_HINT_TIME
	if detector.released:
		_putt(slot)


func _putt(slot: int) -> void:
	var speed := GolfSim.speed_for(detector.power, float(level(difficulty).speed_min))
	_spot = sim.pos
	_feet = GolfLook.feet_for(sim.pos)
	sim.putt(_heading, speed)
	phase = Phase.ROLL
	_phase_time = 0.0
	_swing_age = 0.0
	Sound.sfx("golf_putt")
	_haptics.pulse(slot, 60 if detector.power > 0.6 else 30, BUZZ_GAP_MS)


func _tick_roll(delta: float) -> void:
	sim.clock = _time - delta
	sim.tick(delta)
	for e in sim.events:
		match String(e.t):
			"wall", "rock", "mover":
				Sound.sfx("golf_wall")
			"blade":
				Sound.sfx("golf_blade")
	if sim.finished:
		_putt_done()


func _putt_done() -> void:
	var slot := rules.current_slot()
	var in_water := sim.in_water
	_splash_at = sim.pos
	var ev := rules.putt_done(sim.in_cup)
	if not in_water:
		_balls[slot] = sim.pos
	_last_event = ev
	if _board.has(slot):
		_board.set_score(slot, float(rules.total(slot)))
		_scored = true
	_banner_color = UiTheme.ACCENT
	_banner = ""
	if in_water:
		_banner = Lang.t("mini_golf.splash")
		_banner_color = UiTheme.TEXT
		_splash_age = 0.0
		Sound.sfx("golf_splash")
		_balls[slot] = _spot   # REQ-MG-9: the ball goes back to the place of the last putt.
	elif ev.get("in", false):
		_spark_age = 0.0
		var key := String(ev.label)
		_banner = Lang.t(key) if key != "" else Lang.f("mini_golf.strokes", [int(ev.strokes)])
		Sound.sfx("golf_hole" if key != "mini_golf.hole_in_one" else "golf_ace")
		App.server.haptic(slot, 200 if key == "mini_golf.hole_in_one" else 80)
	elif ev.get("picked", false):
		_banner = Lang.f("mini_golf.picked", [GolfRules.MAX_STROKES])
		_banner_color = UiTheme.TEXT
	phase = Phase.RESULT
	_phase_time = 0.0


func _after_result() -> void:
	if rules.hole_done():
		_begin_hole_done()
	else:
		_start_turn()


## The place of the ball of a player. Every ball stays where its last putt stopped, until the player is on turn again.
func _ball_of(slot: int) -> Vector2:
	return _balls.get(slot, Vector2(_hole.tee))


func _begin_hole_done() -> void:
	phase = Phase.HOLE
	_phase_time = 0.0
	_banner = ""


func _after_hole() -> void:
	if rules.next_hole():
		_balls.clear()
		_load_hole()
		_start_turn()
	else:
		phase = Phase.END
		_end_left = END_DELAY


## The match is over: one player gets a medal for the strokes, more players the winner (REQ-MG-7, 14).
func _finish() -> void:
	for s in _board.winners():
		App.server.haptic(s, 400)
	open_results(_board, GolfRules.tiers(rules.holes))


func _scoreboard() -> Scoreboard:
	return _board if _scored else null


## REQ-MG-15: no personal best in this version. The key table of the profile has a limited size (`profile_keys.gd`).
func best_key() -> String:
	return ""


# ---- Drawing ----

func _pixel_world() -> bool:
	return true


func _geo() -> GolfLook.Geo:
	return GolfLook.Geo.new(size)


func _line_length() -> float:
	return float(level(difficulty).line)


## The pose of the golfer: at the ball, the back swing once the direction is locked, then the swing through (REQ-MG-16).
func _pose() -> Dictionary:
	if phase == Phase.AIM:
		return GolfLook.aim_pose(detector.aim_locked, _lock_age)
	return GolfLook.swing_pose(_swing_age)


func _world_draw(ci: CanvasItem) -> void:
	var geo := _geo()
	GolfLook.draw_ground(ci, size, rules.hole_number())
	var blocks: Array = _hole.blocks
	var windmill: bool = _hole.get("windmill", false)
	var things: Array = []
	for i in blocks.size():
		var block: Rect2 = blocks[i]
		if windmill and i == 0:
			things.append([block.end.y, func() -> void: GolfLook.draw_windmill(ci, geo, block, _time)])
		else:
			things.append([block.end.y, func() -> void: GolfLook.draw_box(ci, geo, block, true)])
	for r in _hole.rocks:
		things.append([float(Vector3(r).y), func() -> void: GolfLook.draw_rock(ci, geo, r)])
	for m in _hole.movers:
		things.append([Holes.mover_rect(m, _time).end.y, func() -> void: GolfLook.draw_box(ci, geo, Holes.mover_rect(m, _time), false)])
	for sp in _hole.spinners:
		things.append([Vector2(sp.c).y + float(sp.len), func() -> void: GolfLook.draw_spinner(ci, geo, sp, _time)])
	things.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for th in things:
		th[1].call()
	GolfLook.draw_flag(ci, geo, _hole, _time)
	if phase == Phase.HOLE or phase == Phase.END or _putter < 0 or not participants.has(_putter):
		return
	GolfLook.draw_golfer(ci, geo, _feet, sim.pos, _pose(), player(_putter).color)
	if phase == Phase.AIM:
		GolfLook.draw_aim(ci, geo, sim.pos, _heading, _line_length(), detector.aim_locked)
	if not sim.in_cup and not sim.in_water:
		GolfLook.draw_ball(ci, geo, sim.pos)
	if _splash_age < 1.0:
		GolfLook.draw_splash(ci, geo, _splash_at, _splash_age)
	if _spark_age < 1.0:
		GolfLook.draw_sparks(ci, geo, Vector2(_hole.cup), _spark_age)


func _game_draw() -> void:
	Shell.title(self, "registry.mini_golf")
	_draw_hole_text()
	_draw_bar()
	if is_over:
		return
	var mid := size.x * 0.5
	var slot := rules.current_slot()
	if phase == Phase.HOLE:
		_draw_hole_card()
	elif phase == Phase.RESULT and _banner != "":
		Shell.label_plate(self, Vector2(mid, size.y * 0.3), _banner, 72, _banner_color)
	elif phase == Phase.AIM and slot >= 0 and participants.has(slot):
		var p := player(slot)
		if _phase_time < TURN_BANNER:
			Shell.label_plate(self, Vector2(mid, size.y * 0.3), Lang.f("mini_golf.turn", [p.player_name]), 64,
					p.color if Shell.contrast(p.color, UiTheme.BG) >= 4.5 else UiTheme.TEXT)
		elif _weak_left > 0.0:
			Shell.label_plate(self, Vector2(mid, size.y * 0.3), Lang.t("mini_golf.hint_weak"), 48, UiTheme.ACCENT)
		elif _phase_time < HINT_TIME and not detector.aim_locked:
			Shell.label_plate(self, Vector2(mid, size.y * 0.3), Lang.t("mini_golf.hint_aim"), 32, UiTheme.TEXT)
		elif detector.aim_locked and bool(level(difficulty).power_hint):
			Shell.label_plate(self, Vector2(mid, size.y * 0.3), Lang.t("mini_golf.hint_power"), 32, UiTheme.TEXT)


## The hint line of a turn after the name banner (REQ-MG-13): the key of a text row, or "" for none. "Swing a bit more" after a
## swing that was too weak, the aim hint before the back swing, the power hint on Easy once the aim is locked.
func aim_hint_key() -> String:
	if _weak_left > 0.0:
		return "mini_golf.hint_weak"
	if _phase_time < HINT_TIME and not detector.aim_locked:
		return "mini_golf.hint_aim"
	if detector.aim_locked and bool(level(difficulty).power_hint):
		return "mini_golf.hint_power"
	return ""


## The hole number, the holes of the match and the par, top right (REQ-MG-3).
func hole_text() -> String:
	return Lang.f("mini_golf.hole", [rules.hole_number(), rules.holes, rules.par()]).to_upper()


## The text of the chip of a player in the bar at the bottom: the name and the strokes on this hole (REQ-MG-3).
func chip_text(slot: int) -> String:
	return Lang.f("mini_golf.chip", [player(slot).player_name, rules.strokes_on_hole(slot)])


func _draw_hole_text() -> void:
	var text := hole_text()
	var w := UiTheme.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var at := Vector2(Shell.mx(self, size.x - 60.0 - w, w), 96.0)
	draw_string(UiTheme.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiTheme.TEXT)


## The bar at the bottom (REQ-MG-3): a chip for every player with the strokes on this hole; the player on turn has a frame.
func _draw_bar() -> void:
	var n := rules.rows.size()
	if n == 0:
		return
	var gap := 16.0
	var w := minf(440.0, (size.x - 120.0 - gap * float(n - 1)) / float(n))
	var total_w := w * float(n) + gap * float(n - 1)
	var x := (size.x - total_w) * 0.5
	var y := size.y - BAR_MARGIN - BAR_H
	var on := rules.current_slot() if phase != Phase.HOLE else -1
	for r in rules.rows:
		if not participants.has(r.slot):
			continue
		var p := player(r.slot)
		var text := Lang.f("mini_golf.chip", [p.player_name, r.strokes])
		var rect := Shell.chip(self, Vector2(x, y), text, p.color, w, BAR_H, p.avatar)
		if r.slot == on and not is_over:
			draw_rect(rect.grow(4.0), UiTheme.ACCENT, false, 4.0)
		x += w + gap


## The card at the end of a hole: the strokes of each player on the hole and in all (REQ-MG-6).
func _draw_hole_card() -> void:
	var n := rules.rows.size()
	var row_h := 76.0
	var w := 1000.0
	var h := 200.0 + row_h * float(n)
	var rect := Rect2((size.x - w) * 0.5, size.y * 0.5 - h * 0.5 - 40.0, w, h)
	draw_style_box(UiTheme.line_box(UiTheme.ACCENT, UiTheme.BG, 6), rect)
	Shell.label_plate(self, Vector2(size.x * 0.5, rect.position.y + 60.0), Lang.f("mini_golf.hole_done", [rules.hole_number()]), 56,
			UiTheme.ACCENT)
	var f := UiTheme.font()
	var x_strokes := Shell.mx(self, rect.position.x + 600.0, 160.0)
	var x_total := Shell.mx(self, rect.position.x + 800.0, 160.0)
	var y := rect.position.y + 130.0
	var head_strokes := Lang.t("mini_golf.col_strokes").to_upper()
	var head_total := Lang.t("mini_golf.col_total").to_upper()
	draw_string(f, Vector2(x_strokes, y), head_strokes, HORIZONTAL_ALIGNMENT_LEFT, 180.0, 28, UiTheme.TEXT_DIM)
	draw_string(f, Vector2(x_total, y), head_total, HORIZONTAL_ALIGNMENT_LEFT, 180.0, 28, UiTheme.TEXT_DIM)
	y += 24.0
	for r in rules.rows:
		if not participants.has(r.slot):
			continue
		var p := player(r.slot)
		var chip_at := Vector2(Shell.mx(self, rect.position.x + 40.0, 520.0), y)
		Shell.chip(self, chip_at, p.player_name, p.color, 520.0, row_h - 12.0, p.avatar)
		draw_string(f, Vector2(x_strokes, y + 40.0), str(r.strokes), HORIZONTAL_ALIGNMENT_LEFT, 180.0, 36, UiTheme.TEXT)
		draw_string(f, Vector2(x_total, y + 40.0), str(rules.total(r.slot)), HORIZONTAL_ALIGNMENT_LEFT, 180.0, 36, UiTheme.ACCENT)
		y += row_h
