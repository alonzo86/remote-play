extends "res://scripts/game/minigame.gd"
## Mini Golf: a golf park for 1 to 4 phones (REQ-MG-1 to 16). The players putt in turns, one putt each, on 1 to 5 holes. Turning
## the phone moves the aim, the first back swing locks it, and the swing speed sets the power. The rules are in golf_rules.gd, the
## ball in golf_sim.gd, the courses in golf_holes.gd, the swing in swing_detector.gd and the whole TV view
## in golf_look.gd. The game is for children too (REQ-GM-80 to 84): a turn has no time limit, water costs nothing and a hole ends
## after 6 strokes.

const GolfRules = preload("res://scripts/game/mini_golf/golf_rules.gd")
const GolfSim = preload("res://scripts/game/mini_golf/golf_sim.gd")
const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")
const GolfLook = preload("res://scripts/game/mini_golf/golf_look.gd")
const SwingDetector = preload("res://scripts/input/swing_detector.gd")

const STATUS_X := 560.0         # The status text of the bar (the hole and the par) stands where the timer is in the other games.
const TEXT_SIZE := 32   # The hole text and the column heads of the hole card (REQ-FL-40: 32 px or more).
const Haptics = preload("res://scripts/game/haptics.gd")

const TURN_BANNER := 1.5        # REQ-MG-3: how long the name of the player on turn shows.
const RESULT_TIME := 1.8        # How long the banner of a putt shows.
const QUIET_TIME := 0.5         # After a putt with nothing to say.
const HOLE_TIME := 4.0          # The card at the end of a hole.
const END_DELAY := 1.2
const SNAP := 0.1               # The aim snaps to the cup when it is this close to it (radians, about 6 degrees; REQ-MG-4).
const WEAK_HINT_TIME := 3.0
# The swing strengths of a putt (m/s2), lower than the common ones of `SwingDetector` (REQ-MG-5). The gate is the common one.
const LIGHT_BACK_ACCEL := 3.0
const LIGHT_FWD_ACCEL := 5.0
const FULL_FWD := 18.0           # A hard swing reaches the full power at this strength (m/s2); the common value is 30.
const BUZZ_GAP_MS := 150
const PAUSE_GAP_MS := 400
const BAR_H := 56.0
const BAR_MARGIN := 64.0   # Chips and the 4 px frame of the player on turn end inside the 60 px margin (REQ-GM-40, #223).

enum Phase { AIM, ROLL, RESULT, HOLE, END }

## What Difficulty means (REQ-MG-13): `line` is the length of the aim line in course units (0 for the marker only), `speed_min`
## is the speed of the weakest putt (m/s), `threshold` is a factor on the swing thresholds.
const LEVELS := {
	"easy": {"line": 3.0, "speed_min": 1.5, "threshold": 1.0},
	"medium": {"line": 1.2, "speed_min": 0.5, "threshold": 1.0},
	"hard": {"line": 0.0, "speed_min": 0.3, "threshold": 1.0},
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
var _swing_age := 99.0
var _lock_age := 0.0            # How long the direction is locked.
var _a_down := {}               # Which phone holds A (a press is the change from up to down).
var _aim_held := false          # The player locked the aim with A (REQ-MG-4); a second press on A unlocks it.
var _snapped := false           # The aim is on the cup now.
var _banner := ""
var _banner_color := UiTheme.ACCENT
var _weak_left := 0.0
var _last_tick_ms := 0
var _splash_at := Vector2.ZERO
var _splash_age := 99.0
var _spark_age := 99.0
var _last_event := {}
var _putter := -1               # The slot of the golfer who is drawn (the player on turn).
var _bar_rows := -1             # Rows of chips in the bar at the bottom (-1: not counted).
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
	# A move to the side, a slow shake or the brake of the back swing is not a putt (issue #209, REQ-MG-5).
	_set_swing_feel()
	_load_hole()
	if not participants.is_empty():
		_start_turn()


## A putt close to the hole is a light swing, so Mini Golf asks less of the detector than the other games (owner, 2026-11-03: a
## light swing was not found, and a back swing with no found putt ended with "swing not found"). The common code and its
## defaults stay as they are for the other games. A move to the side, a slow shake and the brake of the back swing are still
## stopped by the speed gate.
func _set_swing_feel() -> void:
	detector.back_accel = LIGHT_BACK_ACCEL
	detector.fwd_accel = LIGHT_FWD_ACCEL
	detector.fwd_full = FULL_FWD
	detector.speed_gate = SwingDetector.GATE_SPEED


func _load_hole() -> void:
	_hole = Holes.hole(rules.hole_number())
	_spot = _hole.tee
	sim.start(_hole, _spot)
	_putter = -1
	_bar_rows = -1


func _on_player_left(slot: int) -> void:
	var was_turn := rules.current_slot() == slot
	rules.remove_player(slot)
	_board.remove(slot)
	_balls.erase(slot)
	_a_down.erase(slot)
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
	_aim_held = false
	_snapped = false
	_putter = slot
	sim.start(_hole, _ball_of(slot))
	_spot = sim.pos
	_heading = GolfSim.heading_to_cup(_hole, sim.pos)   # Straight ahead of the phone is the cup (REQ-MG-4).
	detector.reset()
	detector.threshold = float(level(difficulty).threshold)
	player(slot).recenter()   # The pose at the start of the turn is straight ahead (REQ-MG-4).
	Sound.sfx("golf_turn")
	_haptics.pulse(slot, 60, BUZZ_GAP_MS)


## TEMP-DEBUG (owner, 2026-11-05; remove before release, with `golf_rules.gd` `debug_jump_to_hole()`): the keys 1 to 5 on the TV
## jump to that hole, to test it.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode < KEY_1 or key.keycode > KEY_5 or is_over:
		return
	rules.debug_jump_to_hole(key.keycode - KEY_1 + 1)
	_balls.clear()
	_load_hole()
	_start_turn()


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
	match phase:
		Phase.AIM:
			_tick_aim(delta)
		Phase.ROLL:
			_tick_roll(delta)
		Phase.RESULT:
			var wait := RESULT_TIME if _banner != "" else QUIET_TIME
			if _phase_time >= wait:
				_after_result()
		Phase.HOLE:
			if _phase_time >= HOLE_TIME:
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
			game_host.send_turn(s, 0, "", "golf")
		elif s == on:
			game_host.send_turn(s, 1, "", "golf")
		else:
			game_host.send_turn(s, 2, player(on).player_name, "golf")


## True when a press on A starts on the phone `slot` in this tick. The button is read in every tick, so an A that was held from an
## earlier phase is not a press.
func _a_pressed(slot: int) -> bool:
	var down := player(slot).is_down(Protocol.BTN_A)
	var pressed: bool = down and not _a_down.get(slot, false)
	_a_down[slot] = down
	return pressed


func _tick_aim(delta: float) -> void:
	var slot := rules.current_slot()
	if slot < 0:
		_begin_hole_done()
		return
	var p := player(slot)
	if _last_tick_ms > 0 and Time.get_ticks_msec() - _last_tick_ms > PAUSE_GAP_MS:
		detector.reset()   # The game was paused: a swing that was under way starts again.
	var pressed := _a_pressed(slot)
	if pressed and not detector.aim_locked:
		_aim_held = not _aim_held   # A locks the aim, and a second press unlocks it (REQ-MG-4).
	if not detector.aim_locked and not _aim_held:
		# The phone as it is at the start of the turn points at the cup (the game recenters by itself); turning it to the right or
		# to the left aims clockwise or anticlockwise from the cup. The player never has to turn round to hit the ball, and a
		# hit at the cup is the same pose on every turn (owner, 2026-11-05).
		var to_cup := GolfSim.heading_to_cup(_hole, sim.pos)
		var turn := -p.yaw_offset()
		_snapped = absf(turn) <= SNAP
		_heading = to_cup if _snapped else wrapf(to_cup + turn, -PI, PI)
	detector.update(delta, p.linear_accel())
	if detector.weak:
		_weak_left = WEAK_HINT_TIME
	if detector.released:
		_putt(slot)


func _putt(slot: int) -> void:
	var speed := GolfSim.speed_for(detector.power, float(level(difficulty).speed_min))
	_spot = sim.pos
	sim.putt(_heading, speed)
	phase = Phase.ROLL
	_phase_time = 0.0
	_swing_age = 0.0
	Sound.sfx("golf_putt")
	_haptics.pulse(slot, 60 if detector.power > 0.6 else 30, BUZZ_GAP_MS)


func _tick_roll(delta: float) -> void:
	sim.tick(delta)
	for e in sim.events:
		match String(e.t):
			"wall", "rock":
				Sound.sfx("golf_wall")
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
		game_host.haptic(slot, 200 if key == "mini_golf.hole_in_one" else 80)
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


## The match is over: one player sees the strokes and no medal, more players the winner (REQ-MG-7, 14, REQ-GM-73).
func _finish() -> void:
	for s in _board.winners():
		game_host.haptic(s, 400)
	open_results(_board)


func _scoreboard() -> Scoreboard:
	return _board if _scored else null


## REQ-MG-15: no personal best in this version. The key table of the profile has a limited size (`profile_keys.gd`).
func best_key() -> String:
	return ""


# ---- Drawing ----

func _pixel_world() -> bool:
	return true


## The scale of the course on the screen: one for the whole hole (see `golf_look.gd`).
func _geo() -> GolfLook.Geo:
	if _bar_rows < 0 and size.x > 0.0:
		_bar_rows = _bar_row_count()
	return GolfLook.Geo.new(size, _hole, maxi(_bar_rows, 1))


## The rows of chips that the bar at the bottom needs on this screen (REQ-MG-3). The course ends above them.
func _bar_row_count() -> int:
	var widths: Array = []
	for r in rules.rows:
		if participants.has(r.slot):
			var text := Lang.f("mini_golf.chip", [player(r.slot).player_name, GolfRules.MAX_STROKES])
			widths.append(Shell.chip_width(text, 200.0, player(r.slot).avatar))
	if widths.is_empty():
		return 1
	return bar_lines(widths, size.x - 120.0, 16.0).size()


func _line_length() -> float:
	return float(level(difficulty).line)


## The pose of the golfer: at the ball, the back swing once the direction is locked, then the swing through (REQ-MG-16).
func _pose() -> Dictionary:
	if phase == Phase.AIM:
		return GolfLook.aim_pose(detector.aim_locked, _lock_age)
	return GolfLook.swing_pose(_swing_age)


## The balls that are on the course now, the ball of the player on turn first: `{slot, pos, turn}` with `pos` the place on the
## course. A ball that is in the cup or picked up is not on the course. At the end of a hole there are none.
func ball_list() -> Array:
	var out: Array = []
	if phase == Phase.HOLE or phase == Phase.END or is_over:
		return out
	if _putter >= 0 and participants.has(_putter):
		var row := rules.row_of(_putter)
		if row != null and not row.finished() and not sim.in_cup:
			out.append({"slot": _putter, "pos": _spot if sim.in_water else sim.pos, "turn": true})
	return out   # Only the ball of the player on turn is drawn (owner, 2026-11-03).


## The golfer is drawn by the ball of the player on turn, from the start of the turn until the next one.
func golfer_shown() -> bool:
	return phase != Phase.HOLE and phase != Phase.END and _putter >= 0 and participants.has(_putter)


## True when the aim points back (to the left of the screen): the golfer stands on the other side and faces the other way.
func golfer_flipped() -> bool:
	return cos(_heading) < 0.0


## The screen place of a point of the course with the height of the ground (a hill lifts the ball).
func _lifted(geo: GolfLook.Geo, p: Vector2) -> Vector2:
	return geo.at(p) - Vector2(0.0, geo.up(Holes.hill_height(_hole, p)))


func _world_draw(ci: CanvasItem) -> void:
	var geo := _geo()
	GolfLook.draw_lawn(ci, geo)
	GolfLook.draw_scenery(ci, geo, _hole, rules.hole_number(), _time)
	GolfLook.draw_course(ci, geo, _hole)
	# The obstacles, the ball and the golfer are drawn from far to near (the camera is tilted, so a tall obstacle hides what is
	# behind it); the flag and the aim line stay on top.
	var items: Array = []
	var blocks: Array = _hole.blocks
	var windmill: bool = _hole.get("windmill", false)
	if windmill and not blocks.is_empty():
		var tower: Rect2 = blocks[0]
		items.append([geo.at(tower.end).y, func() -> void:
			GolfLook.draw_windmill(ci, geo, tower, _time, float(_hole.get("door", 0.3)))])
	for r in _hole.rocks:
		var rock: Vector3 = r
		items.append([geo.at(Vector2(rock.x, rock.y)).y, func() -> void: GolfLook.draw_rock(ci, geo, rock)])
	var list := ball_list()
	if golfer_shown():
		var spot := geo.at(_spot) - Vector2(0.0, geo.up(Holes.hill_height(_hole, _spot)))
		items.append([spot.y, func() -> void:
			GolfLook.draw_golfer(ci, geo, spot, _pose(), player(_putter).color, golfer_flipped())])
	if not list.is_empty():
		var ball: Dictionary = list[0]
		# The ball is on top of everything (a tall obstacle never hides it), except inside the tunnel of the windmill, where it
		# disappears behind the door and comes out on the other side.
		var in_tunnel: bool = windmill and blocks.size() > 0 and (blocks[0] as Rect2).has_point(ball.pos)
		var ball_key: float = geo.at((blocks[0] as Rect2).end).y - 1.0 if in_tunnel else INF
		items.append([ball_key, func() -> void: GolfLook.draw_ball(ci, geo, _lifted(geo, ball.pos), ball.slot)])
	items.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	for it in items:
		it[1].call()
	GolfLook.draw_flag(ci, geo, _hole, _time)   # On top of the obstacles: the tower never hides it.
	if golfer_shown() and phase == Phase.AIM:
		GolfLook.draw_aim(ci, geo, _hole, sim.pos, _heading, _line_length(), detector.aim_locked or _aim_held, _snapped)
	if _splash_age < 1.0:
		GolfLook.draw_splash(ci, geo, geo.at(_splash_at), _splash_age)
	if _spark_age < 1.0:
		GolfLook.draw_sparks(ci, geo, _hole, _spark_age)


## The place of a banner plate: where it covers the cup, the balls, the golfer and the aim line the least (REQ-MG-3).
func _plate_pos(msg: String, font_size: int) -> Vector2:
	var geo := _geo()
	var avoid: Array = [GolfLook.cup_zone(geo, _hole)]
	for b in ball_list():
		avoid.append(Rect2(geo.at(b.pos) - Vector2(36.0, 36.0) * geo.u, Vector2(72.0, 72.0) * geo.u))
	if golfer_shown():
		avoid.append(GolfLook.golfer_zone(geo, geo.at(_spot)))
		if phase == Phase.AIM:
			var to := GolfLook.aim_end(geo, _hole, sim.pos, _heading, _line_length())
			avoid.append(Rect2(geo.at(sim.pos), Vector2.ZERO).expand(to).grow(30.0 * geo.u))
	return GolfLook.plate_at(geo, msg, font_size, avoid, GolfLook.obstacle_zones(geo, _hole))


## A banner plate (the turn, the putt, the hints) on the course, away from what the players look at.
func _banner_plate(msg: String, font_size: int, color: Color) -> void:
	Shell.label_plate(self, _plate_pos(msg, font_size), msg, font_size, color)


func _game_draw() -> void:
	Shell.title(self, "registry.mini_golf")
	_draw_hole_text()
	draw_leader_chip(self)   # The leader (the fewest strokes) in the black bar, as in every other game (owner, 2026-11-05).
	_draw_bar()
	if is_over:
		return
	var slot := rules.current_slot()
	if phase == Phase.HOLE:
		_draw_hole_card()
	elif phase == Phase.RESULT and _banner != "":
		_banner_plate(_banner, 72, _banner_color)
	elif phase == Phase.AIM and slot >= 0 and participants.has(slot):
		var p := player(slot)
		if _phase_time < TURN_BANNER:
			_banner_plate(Lang.f("mini_golf.turn", [p.player_name]), 64,
					p.color if Shell.contrast(p.color, UiTheme.BG) >= 4.5 else UiTheme.TEXT)
		elif _weak_left > 0.0:
			_banner_plate(Lang.t("mini_golf.hint_weak"), 48, UiTheme.ACCENT)


## The hint line of a turn after the name banner: the key of a text row, or "" for none. Only "Swing a bit more" after a swing
## that was too weak; there are no instructions on the screen during the game (owner, 2026-11-04).
func aim_hint_key() -> String:
	return "mini_golf.hint_weak" if _weak_left > 0.0 else ""


## The hole number, the holes of the match and the par, top right (REQ-MG-3).
func hole_text() -> String:
	return Lang.f("mini_golf.hole", [rules.hole_number(), rules.holes, rules.par()]).to_upper()


## The text of the chip of a player in the bar at the bottom: the name and the strokes on this hole (REQ-MG-3).
func chip_text(slot: int) -> String:
	return Lang.f("mini_golf.chip", [player(slot).player_name, rules.strokes_on_hole(slot)])


func _draw_hole_text() -> void:
	var text := hole_text()
	var w := UiTheme.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Shell.STATUS_FONT).x
	Shell.status(self, STATUS_X, w, text)


## The bar at the bottom (REQ-MG-3): a chip for every player with the strokes on this hole; the player on turn has a frame.
func _draw_bar() -> void:
	var items: Array = []   # [row, text, width]
	for r in rules.rows:
		if participants.has(r.slot):
			var text := Lang.f("mini_golf.chip", [player(r.slot).player_name, r.strokes])
			items.append([r, text, Shell.chip_width(text, 200.0, player(r.slot).avatar)])
	if items.is_empty():
		return
	var gap := 16.0
	var widths: Array = items.map(func(it): return it[2])
	var lines := bar_lines(widths, size.x - 120.0, gap)   # Index lists: a long name does not fit one row, so the bar gets a second.
	var on := rules.current_slot() if phase != Phase.HOLE else -1
	for li in lines.size():
		var line_w := gap * float(lines[li].size() - 1)
		for k in lines[li]:
			line_w += float(widths[k])
		var x := (size.x - line_w) * 0.5
		var y := size.y - BAR_MARGIN - BAR_H - float(lines.size() - 1 - li) * (BAR_H + gap)
		for k in lines[li]:
			var p := player(items[k][0].slot)
			var rect := Shell.chip(self, Vector2(x, y), items[k][1], p.color, widths[k], BAR_H, p.avatar)
			if items[k][0].slot == on and not is_over:
				draw_rect(rect.grow(4.0), UiTheme.ACCENT, false, 4.0)
			x += float(widths[k]) + gap


## The chips of the bar in rows: the indexes of `widths` that stand in each row, in order. A chip is as wide as its text needs
## (nothing is cut, issue #246), so when they do not fit one row of `avail` px the bar gets one more row.
static func bar_lines(widths: Array, avail: float, gap: float) -> Array:
	var lines: Array = [[]]
	var used := 0.0
	for k in widths.size():
		var need: float = float(widths[k]) + (gap if not lines[-1].is_empty() else 0.0)
		if not lines[-1].is_empty() and used + need > avail:
			lines.append([])
			need = float(widths[k])
			used = 0.0
		lines[-1].append(k)
		used += need
	return lines


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
	var x_strokes := Shell.mx(self, rect.position.x + 540.0, 240.0)
	var x_total := Shell.mx(self, rect.position.x + 790.0, 180.0)
	var y := rect.position.y + 130.0
	var head_strokes := Lang.t("mini_golf.col_strokes").to_upper()
	var head_total := Lang.t("mini_golf.col_total").to_upper()
	draw_string(f, Vector2(x_strokes, y), head_strokes, HORIZONTAL_ALIGNMENT_LEFT, 240.0, TEXT_SIZE, UiTheme.TEXT_INFO)
	draw_string(f, Vector2(x_total, y), head_total, HORIZONTAL_ALIGNMENT_LEFT, 180.0, TEXT_SIZE, UiTheme.TEXT_INFO)
	y += 24.0
	for r in rules.rows:
		if not participants.has(r.slot):
			continue
		var p := player(r.slot)
		var chip_at := Vector2(Shell.mx(self, rect.position.x + 40.0, 480.0), y)
		Shell.chip(self, chip_at, p.player_name, p.color, 480.0, row_h - 12.0, p.avatar)
		draw_string(f, Vector2(x_strokes, y + 52.0), str(r.strokes), HORIZONTAL_ALIGNMENT_LEFT, 180.0, 40, UiTheme.TEXT)
		draw_string(f, Vector2(x_total, y + 52.0), str(rules.total(r.slot)), HORIZONTAL_ALIGNMENT_LEFT, 180.0, 40, UiTheme.ACCENT)
		y += row_h
