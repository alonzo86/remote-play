extends "res://scripts/game/minigame.gd"
## Pin Pals: ten-pin bowling for 1 to 4 phones (REQ-BW-1 to 20). The players bowl in turns, 10 frames each. A finger on the
## phone slides the ball along the foul line to aim, swinging the phone back and then forward throws the ball. The rules are in
## bowling_rules.gd, the ball and the pins in lane_sim.gd, the swing in swing_detector.gd and the pictures in bowling_look.gd.
## The game is for children too (REQ-GM-80 to 84): a turn has no time limit,
## the pins are plain pins, and a ball in the gutter takes no points away.

const BowlingRules = preload("res://scripts/game/bowling/bowling_rules.gd")
const LaneSim = preload("res://scripts/game/bowling/lane_sim.gd")
const SwingDetector = preload("res://scripts/input/swing_detector.gd")
const BowlingLook = preload("res://scripts/game/bowling/bowling_look.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const COUNTDOWN := 3.0
const RESULT_TIME := 1.8        # How long the banner of a ball shows. A press on A of any phone ends it at once.
const END_DELAY := 2.0          # After the last ball the lane stays this long, then the result menu opens (REQ-BW-1).
const HINT_TIME := 12.0         # The hint shows this long at the start of a turn, then again after a weak swing.
const WEAK_HINT_TIME := 3.0
const PLATE_TIME := 1.5         # The plate "NAME, YOUR TURN!" shows this long at the start of a turn (REQ-BW-21).
const LIFT_HINT_TIME := 3.0     # The hint "lift your finger" shows this long after a swing with a finger on the strip.
const MIN_BACK := 0.1          # A back swing shorter than this (s) is a shake, not a wind-up (REQ-BW-5).
const BUZZ_GAP_MS := 150
# The aim at its end is this far from the middle of the lane (m): past the lane edge, in the gutter.
const AIM_X := 0.60
const ROW_H := 72.0             # A row of the score sheet.
const NAME_W := 420.0
const SHEET_MARGIN := 60.0
const PAUSE_GAP_MS := 400       # A gap between two ticks longer than this means the game was paused: the swing starts again.

const FULL_RACK := [true, true, true, true, true, true, true, true, true, true]

enum Phase { AIM, ROLL, RESULT, END }

## Set before the game starts (REQ-GM-93). `start_props` keeps them for Try again.
var difficulty := "medium"
var rails := "off"

var rules := BowlingRules.new()
var sim := LaneSim.new()
var detector := SwingDetector.new()
var phase := Phase.AIM

var _board: Scoreboard
var _clock := RoundClock.new(COUNTDOWN, 0.0)
var _haptics := Haptics.new()
var _rows_at_start := 1
var _time := 0.0
var _phase_time := 0.0
var _end_left := 0.0
var _aim := 0.0                 # -1 to 1: the aim of the player on turn.
var _before: Array = []         # The pins that stood before the ball.
var _banner := ""               # The text of the banner after a ball, "" for none.
var _banner_color := UiTheme.ACCENT
var _pins_left_line := ""
var _weak_left := 0.0
var _lift_left := 0.0
var _plate_left := 0.0
var _aim_slot := -1             # The player whose aim is in `_aim`: the same player keeps it for ball 2 (REQ-BW-4).
var _probe := SwingDetector.new()   # Sees a swing made with a finger on the strip, to show the hint.
var _last_tick_ms := 0
var _a_pressed := false
var _a_down := {}               # slot -> A was down at the last tick.
var _last_event := {}


func _game_ready() -> void:
	var slots: Array[int] = []
	slots.assign(participants)
	rules.setup(slots)
	_rows_at_start = maxi(1, participants.size())
	_board = Scoreboard.new(participants)
	detector.threshold = float(BowlingRules.level(difficulty).threshold)
	detector.min_back = MIN_BACK
	detector.max_reversals = 1   # A shake turns the acceleration round again and again: it throws nothing (REQ-BW-5).


func _on_player_left(slot: int) -> void:
	var was_turn := rules.current_slot() == slot
	rules.remove_player(slot)
	_board.remove(slot)
	_a_down.erase(slot)
	if is_over or _clock.is_counting():
		return
	if rules.game_over():
		_begin_end()
	elif was_turn and (phase == Phase.AIM or phase == Phase.ROLL):
		sim.set_rack(FULL_RACK)   # The next player starts a frame with a full rack.
		_start_turn()


# ---- The turns ----

func _start_turn() -> void:
	var slot := rules.current_slot()
	if slot < 0:
		_begin_end()
		return
	phase = Phase.AIM
	_phase_time = 0.0
	_banner = ""
	_pins_left_line = ""
	_weak_left = 0.0
	_lift_left = 0.0
	_plate_left = PLATE_TIME
	if slot != _aim_slot:
		_aim = 0.0   # A new player starts in the middle. The same player keeps the aim (the phone keeps its mark).
		_aim_slot = slot
	_probe.reset()
	detector.reset()
	detector.threshold = float(BowlingRules.level(difficulty).threshold)
	Sound.sfx("bowl_turn")
	_haptics.pulse(slot, 60, BUZZ_GAP_MS)


func _begin_end() -> void:
	phase = Phase.END
	_end_left = END_DELAY
	_banner = ""
	_pins_left_line = ""


func _game_tick(delta: float) -> void:
	_time += delta
	if is_over:
		return
	if _clock.is_counting():
		if _clock.tick(delta):
			var first := rules.current_slot()
			for s in participants:
				if s != first:   # The first player gets the buzz of the turn only: one buzz (bowling.md Turn flow 1).
					App.server.haptic(s, 60)
			_start_turn()
		return
	_publish_turn()
	_phase_time += delta
	_plate_left = maxf(0.0, _plate_left - delta)
	_poll_buttons()
	_weak_left = maxf(0.0, _weak_left - delta)
	_lift_left = maxf(0.0, _lift_left - delta)
	match phase:
		Phase.AIM:
			_tick_aim(delta)
		Phase.ROLL:
			_tick_roll(delta)
		Phase.RESULT:
			if _phase_time >= RESULT_TIME or _a_pressed:
				_after_result()
		Phase.END:
			_end_left -= delta
			if _end_left <= 0.0:
				_finish()
	_last_tick_ms = Time.get_ticks_msec()


## Tells each phone whose turn it is (REQ-BW-14). The server sends a changed message only.
func _publish_turn() -> void:
	var on := rules.current_slot() if phase != Phase.END else -1
	for s in participants:
		if on < 0:
			App.server.send_turn(s, 0, "")
		elif s == on:
			App.server.send_turn(s, 1, "")
		else:
			App.server.send_turn(s, 2, player(on).player_name)


## Polls A on every tick, in every phase, so a button held since an earlier phase is not read as a new press. Sets
## `_a_pressed`: true when a press on A starts on any phone this tick: it skips the banner (REQ-BW-11).
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
		_begin_end()
		return
	var p := player(slot)
	if _last_tick_ms > 0 and Time.get_ticks_msec() - _last_tick_ms > PAUSE_GAP_MS:
		detector.reset()   # The game was paused: a swing that was under way starts again (REQ-BW-20).
	if not detector.aim_locked and p.touching:
		_aim = aim_from_touch(p.touch.x)   # The aim stays when the finger lifts (REQ-BW-4).
	if p.touching:
		# A finger on the aim strip means the player is aiming: moves of the phone do not throw (REQ-BW-5). A swing that
		# would have thrown shows the hint to lift the finger.
		detector.reset()
		_probe.threshold = detector.threshold
		_probe.min_back = detector.min_back
		_probe.max_reversals = detector.max_reversals
		_probe.update(delta, p.linear_accel())
		if _probe.released:
			_lift_left = LIFT_HINT_TIME
	else:
		_probe.reset()
		detector.update(delta, p.linear_accel())
	if detector.weak:
		_weak_left = WEAK_HINT_TIME
	if detector.released:
		_throw(slot)


## The aim (-1 left, 1 right) from the place of the finger on the aim strip (0 to 1). The ball rolls straight.
static func aim_from_touch(x: float) -> float:
	return clampf(x * 2.0 - 1.0, -1.0, 1.0)


func _throw(slot: int) -> void:
	_before = sim.standing_mask()
	var speed := BowlingRules.ball_speed(difficulty, detector.power, LaneSim.SPEED_TOP)
	sim.throw(_aim * AIM_X, speed, rails == "on")
	phase = Phase.ROLL
	_phase_time = 0.0
	Sound.sfx("bowl_throw")
	_haptics.pulse(slot, 40, BUZZ_GAP_MS)


func _tick_roll(delta: float) -> void:
	sim.tick(delta)
	for e in sim.events:
		if e.t == "hit":
			Sound.sfx("bowl_pins")
			var slot := rules.current_slot()
			if slot >= 0:
				_haptics.pulse(slot, 40, BUZZ_GAP_MS)
	if sim.finished:
		_roll_done()


## The ball is done: the fallen pins are counted, the rule engine moves on and the banner shows what happened (REQ-BW-15).
func _roll_done() -> void:
	var slot := rules.current_slot()
	var knocked := sim.knocked_since(_before)
	var ev := rules.record_roll(knocked)
	_last_event = ev
	if _board.has(slot):
		_board.set_score(slot, float(rules.score_of(slot)))
	_banner_color = UiTheme.ACCENT
	_pins_left_line = ""
	if ev.strike:
		_banner = Lang.t("bowling.strike")
		Sound.sfx("bowl_strike")
		App.server.haptic(slot, 200)
	elif ev.spare:
		_banner = Lang.t("bowling.spare")
		Sound.sfx("bowl_spare")
		App.server.haptic(slot, 80)
	elif sim.in_gutter or knocked == 0:
		_banner = Lang.t("bowling.gutter")
		_banner_color = UiTheme.TEXT
		Sound.sfx("bowl_gutter")
	elif knocked >= 7:
		_banner = Lang.t("bowling.nice_roll")
	else:
		_banner = Lang.t("bowling.nice_try")
		_banner_color = UiTheme.TEXT
	var left := sim.standing_count()
	if not ev.frame_done and not ev.fresh_rack and left > 0:
		_pins_left_line = Lang.t("bowling.pin_left") if left == 1 else Lang.f("bowling.pins_left", [left])
	phase = Phase.RESULT
	_phase_time = 0.0


func _after_result() -> void:
	if rules.game_over():
		_begin_end()
		return
	if bool(_last_event.get("fresh_rack", false)):
		sim.set_rack(FULL_RACK)
	else:
		sim.sweep()
	_start_turn()


## REQ-BW-1: the game is over. One player gets a medal for the score, more players the winner.
func _finish() -> void:
	for s in _board.winners():
		App.server.haptic(s, 400)
	open_results(_board, BowlingRules.level(difficulty).tiers)


func _scoreboard() -> Scoreboard:
	return _board


## The personal best (REQ-GM-98): the score, for each difficulty. A game with rails has none (REQ-BW-19).
func best_key() -> String:
	return "bowling|%s" % difficulty if rails == "off" else ""


# ---- Drawing ----

func _pixel_world() -> bool:
	return true


func _sheet_top() -> float:
	return size.y - SHEET_MARGIN - float(_rows_at_start) * ROW_H


func _geo() -> BowlingLook.Geo:
	return BowlingLook.Geo.new(size, _sheet_top())


func _world_draw(ci: CanvasItem) -> void:
	var geo := _geo()
	BowlingLook.draw_hall(ci, size, geo, rails == "on")
	var colors: Array = []
	for s in participants:
		colors.append(player(s).color)
	if colors.is_empty():
		colors.append(UiTheme.TEXT)
	var ball_first := false
	if _clock.is_counting():
		BowlingLook.draw_pins(ci, geo, sim, colors)
		for i in participants.size():
			BowlingLook.draw_ball(ci, geo, Vector2(_wait_x(i), 0.0), player(participants[i]).color)
		return
	var slot := rules.current_slot()
	if phase == Phase.ROLL and sim.ball_active and sim.ball_pos.y > LaneSim.HEAD_Y + 0.15:
		ball_first = true
	if ball_first and slot >= 0:
		BowlingLook.draw_ball(ci, geo, sim.ball_pos, player(slot).color)
	BowlingLook.draw_pins(ci, geo, sim, colors)
	if slot < 0 or not participants.has(slot):
		return
	var color := player(slot).color
	if phase == Phase.AIM:
		BowlingLook.draw_aim(ci, geo, _aim * AIM_X, color)
		BowlingLook.draw_ball(ci, geo, Vector2(_aim * AIM_X, 0.0), color)
	elif phase == Phase.ROLL and sim.ball_active and not ball_first:
		BowlingLook.draw_ball(ci, geo, sim.ball_pos, color)


## The place across the lane (m) of the ball of the i-th player in the countdown.
func _wait_x(i: int) -> float:
	return (float(i + 1) / float(participants.size() + 1) * 2.0 - 1.0) * 0.4


func _game_draw() -> void:
	Shell.title(self, "registry.pin_pals")
	var geo := _geo()
	if _clock.is_counting():
		var n := _clock.count_number()
		var label := str(n)
		draw_set_transform(Vector2(8.0, 8.0), 0.0, Vector2.ONE)
		Shell.countdown(self, size, label, _clock.count_elapsed(), UiTheme.BG)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Shell.countdown(self, size, label, _clock.count_elapsed())
		_draw_sheet()
		return
	_draw_frame_text()
	_draw_sheet()
	if is_over:
		return
	var slot := rules.current_slot()
	if slot >= 0 and participants.has(slot) and phase != Phase.END and _plate_left > 0.0:
		Shell.label_plate(self, Vector2(size.x * 0.5, 92.0), Lang.f("bowling.turn", [player(slot).player_name]), 32,
				player(slot).color if _readable(player(slot).color) else UiTheme.TEXT)
	if phase == Phase.RESULT and _banner != "":
		Shell.label_plate(self, Vector2(size.x * 0.5, size.y * 0.36), _banner, 72, _banner_color)
		if _pins_left_line != "":
			Shell.label_plate(self, Vector2(size.x * 0.5, size.y * 0.36 + 110.0), _pins_left_line, 32, UiTheme.TEXT)
	elif phase == Phase.AIM:
		if _lift_left > 0.0:
			Shell.label_plate(self, Vector2(size.x * 0.5, size.y * 0.36), Lang.t("bowling.hint_lift"), 48, UiTheme.ACCENT)
		elif _weak_left > 0.0:
			Shell.label_plate(self, Vector2(size.x * 0.5, size.y * 0.36), Lang.t("bowling.hint_weak"), 48, UiTheme.ACCENT)
		elif _phase_time < HINT_TIME and not detector.aim_locked:
			Shell.label_plate(self, Vector2(size.x * 0.5, size.y * 0.36), Lang.t("bowling.hint_slide"), 32, UiTheme.TEXT)


## The title of the turn is in the slot color when that color reads on black (REQ-GM-46 is about chips; text stays white
## otherwise).
func _readable(c: Color) -> bool:
	return Shell.contrast(c, UiTheme.BG) >= 4.5


func _draw_frame_text() -> void:
	var text := Lang.f("bowling.frame", [rules.current_frame(), BowlingRules.FRAMES, maxi(1, rules.current_ball())]).to_upper()
	var w := UiTheme.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var at := Vector2(Shell.mx(self, size.x - 60.0 - w, w), 96.0)
	draw_string(UiTheme.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiTheme.TEXT)


## The score sheet at the bottom (the headboard, REQ-BW-12): a row for each player with the marks and the running total of each
## frame.
## It is laid out left to right in both languages.
func _draw_sheet() -> void:
	var x0 := SHEET_MARGIN
	var cell_w := (size.x - 2.0 * SHEET_MARGIN - NAME_W) / (float(BowlingRules.FRAMES) + 0.5)
	var on_turn := rules.current_slot()
	var current_frame := rules.current_frame()
	var y := _sheet_top()
	var f := UiTheme.font()
	for r in rules.rows:
		if not participants.has(r.slot):
			continue
		var active: bool = r.slot == on_turn and not is_over and not _clock.is_counting()
		var p := player(r.slot)
		var name_rect := Shell.chip(self, Vector2(x0, y), p.player_name, p.color, NAME_W - 6.0, ROW_H - 6.0, p.avatar)
		if active:
			draw_rect(name_rect, UiTheme.ACCENT, false, 4.0)
		var cells := BowlingRules.sheet_cells(r.rolls)
		for i in BowlingRules.FRAMES:
			var w := cell_w * (1.5 if i == BowlingRules.FRAMES - 1 else 1.0)
			var x := x0 + NAME_W + cell_w * i
			var rect := Rect2(x, y, w - 6.0, ROW_H - 6.0)
			var here := active and i + 1 == current_frame
			draw_style_box(UiTheme.line_box(UiTheme.ACCENT if here else UiTheme.FRAME, UiTheme.BG, 4), rect)
			var marks := " ".join(cells[i].marks)
			draw_string(f, Vector2(x + 10.0, y + 30.0), marks, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiTheme.TEXT)
			if int(cells[i].total) >= 0:
				draw_string(f, Vector2(x + 10.0, y + 60.0), str(int(cells[i].total)), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiTheme.ACCENT)
		y += ROW_H
