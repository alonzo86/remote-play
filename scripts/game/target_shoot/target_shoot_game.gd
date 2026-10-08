extends "res://scripts/game/minigame.gd"
## Target Shoot. Each phone is a pointer: a cursor in the player color follows `PlayerInput.pointer()`. A press on A shoots at
## the cursor. Targets are the same for all players, and the first shot that hits one takes its points (REQ-TS-1 to 16).
## The RECENTER button of the phone recenters (REQ-GM-37); GO recenters all. B does nothing.
## The rules of the targets are in target_field.gd. This script has the input, the round and the drawing.

const TargetField = preload("res://scripts/game/target_shoot/target_field.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const ROUND_TIME := 45.0
const COUNTDOWN := 3.0
const RELOAD := 0.25            # Seconds before a player can shoot again (REQ-TS-5).
const MISS_LOCK := 0.6          # Seconds without fire after a miss, the reload included (REQ-TS-6).
const MEDAL_TIERS := [200, 350, 500]   # Bronze, silver, gold for one player (REQ-TS-15). First guesses.

# The play area is the screen inside the margin, under the HUD (REQ-TS-3).
const AREA_TOP := 150.0
const AREA_MARGIN := 60.0
const TIMER_X := 560.0          # The timer pill has a fixed place, between the title and the chips.
const HINT_TIME := 4.0          # Seconds of play with the hint on the screen.

# Look (REQ-TS-12, REQ-GM-47). The board is dark so that every player color has a contrast of 3:1 or more.
const BACKGROUND := Color("1b3a8a")
const BOARD_COLOR := Color("12205a")
const STANDARD_COLOR := Color("3ddcff")   # Party Pop cyan.
const SMALL_COLOR := Color("ffd23f")      # Party Pop yellow.
const DECOY_COLOR := Color("ff3d8b")      # Party Pop pink. The decoy is also a square with an X: not known by color alone.
const OUTLINE_BIG := 6.0
const CURSOR_R := 32.0
const BADGE_R := 17.0

const BUZZ_GAP_MS := 100        # REQ-GM-43.
const POP_COUNT := 12
const POP_LIFE := 0.7

class Shooter:
	var slot := 0
	var aim := Vector2.ZERO
	var reload_left := 0.0
	var lock_left := 0.0

	func can_fire() -> bool:
		return reload_left <= 0.0 and lock_left <= 0.0

## A short effect at a shot: a ring and the points. The pool is made once (REQ-GM-51).
class Pop:
	var pos := Vector2.ZERO
	var text := ""
	var color := Color.WHITE
	var age := -1.0   # Below 0: not in use.

var _round := RoundClock.new(COUNTDOWN, ROUND_TIME)
var _field := TargetField.new()
var _board: Scoreboard
var _rng := RandomNumberGenerator.new()
var _haptics := Haptics.new()
var _shooters := {}              # slot -> Shooter
var _presses: Array[int] = []    # Slots of the A presses, in the order they arrived (REQ-TS-11).
var _pops: Array[Pop] = []
var _sb_board: StyleBoxFlat      # Made once. Drawing must not create objects every frame (REQ-GM-51).
var _sb_decoy: StyleBoxFlat


func _game_ready() -> void:
	_sb_board = UiTheme.card(BOARD_COLOR, UiTheme.OUTLINE, UiTheme.OUTLINE_W, 30, true)
	_sb_decoy = UiTheme.card(DECOY_COLOR, UiTheme.OUTLINE, int(OUTLINE_BIG), 26, true)
	if start_props.has("seed"):
		_rng.seed = int(start_props.seed)   # REQ-TS-9: a test fixes the targets. Restart keeps the seed.
	else:
		_rng.randomize()
	_board = Scoreboard.new(participants)
	for s in participants:
		var sh := Shooter.new()
		sh.slot = s
		_shooters[s] = sh
		player(s).button_pressed.connect(_on_button.bind(s))
	for i in POP_COUNT:
		_pops.append(Pop.new())


func _exit_tree() -> void:
	for s in _shooters:
		var cb := _on_button.bind(s)
		if player(s).button_pressed.is_connected(cb):
			player(s).button_pressed.disconnect(cb)


## REQ-TS-4: a press on A is a shot. It is kept until the next tick, so that shots are handled in the order they came.
func _on_button(bit: int, slot: int) -> void:
	if bit != Protocol.BTN_A or is_paused() or is_over or _round.is_counting():
		return
	_presses.append(slot)


func _on_player_left(slot: int) -> void:
	_shooters.erase(slot)
	_board.remove(slot)
	_presses = _presses.filter(func(s: int) -> bool: return s != slot)


func _area() -> Rect2:
	return Rect2(AREA_MARGIN, AREA_TOP, size.x - 2.0 * AREA_MARGIN, size.y - AREA_TOP - AREA_MARGIN)


func _game_tick(delta: float) -> void:
	if is_over:
		return
	var area := _area()
	for s in _shooters:
		var sh: Shooter = _shooters[s]
		sh.aim = TargetField.aim_to_screen(player(s).pointer(), area)
		sh.reload_left = maxf(sh.reload_left - delta, 0.0)
		sh.lock_left = maxf(sh.lock_left - delta, 0.0)
	if _round.is_counting():
		if _round.tick(delta):
			for s in _shooters:
				player(s).recenter()   # REQ-TS-2: the pose held in the countdown is the center.
				App.server.haptic(s, 60)
		return
	_round.tick(delta)
	for s in _presses:
		_fire(s, area)
	_presses.clear()
	_field.tick(delta, _rng, participants.size())
	for p in _pops:
		if p.age >= 0.0:
			p.age += delta
			if p.age > POP_LIFE:
				p.age = -1.0
	if _round.is_time_up():
		_finish()


## One shot at the cursor of `slot` (REQ-TS-4 to 6, 10).
func _fire(slot: int, area: Rect2) -> void:
	if not _shooters.has(slot):
		return
	var sh: Shooter = _shooters[slot]
	if not sh.can_fire():
		return
	sh.reload_left = RELOAD
	var t := _field.hit(sh.aim, area)
	if t == null:
		sh.lock_left = MISS_LOCK
		_haptics.pulse(slot, 15, BUZZ_GAP_MS)
		_pop(sh.aim, "", slot)
		return
	_field.take(t)
	_board.set_score(slot, maxf(_board.score(slot) + t.points, 0.0))
	_haptics.pulse(slot, 60 if t.points < 0 else 30, BUZZ_GAP_MS)
	_pop(TargetField.center_of(t, area), "%+d" % t.points, slot)


func _finish() -> void:
	for s in _board.winners():
		App.server.haptic(s, 400)
	open_results(_board, MEDAL_TIERS)


func _pop(pos: Vector2, text: String, slot: int) -> void:
	for p in _pops:
		if p.age < 0.0:
			p.pos = pos
			p.text = text
			p.color = player(slot).color
			p.age = 0.0
			return


# ---- Drawing ----

func _game_draw() -> void:
	var area := _area()
	var k := TargetField.scale_for(area)
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_style_box(_sb_board, area.grow(12.0))
	for t in _field.targets:
		_draw_target(t, area, k)
	for p in _pops:
		if p.age >= 0.0:
			_draw_pop(p)
	for s in _shooters:
		_draw_cursor(_shooters[s])
	_draw_hud()


func _draw_target(t: TargetField.Target, area: Rect2, k: float) -> void:
	var c := TargetField.center_of(t, area)
	var r := t.radius * k * t.grow(TargetField.GROW_TIME)
	if t.kind == "decoy":
		var box := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
		draw_style_box(_sb_decoy, box)
		var d := r * 0.45
		var w := maxf(r * 0.28, 3.0)
		draw_line(c + Vector2(-d, -d), c + Vector2(d, d), UiTheme.OUTLINE, w)
		draw_line(c + Vector2(-d, d), c + Vector2(d, -d), UiTheme.OUTLINE, w)
		return
	var color := SMALL_COLOR if t.kind == "small" else STANDARD_COLOR
	draw_circle(c + UiTheme.SHADOW * 0.6, r + OUTLINE_BIG, UiTheme.OUTLINE)
	draw_circle(c, r + OUTLINE_BIG, UiTheme.OUTLINE)
	draw_circle(c, r, color)
	draw_circle(c, r * 0.68, Color.WHITE)
	draw_circle(c, r * 0.36, color)


func _draw_cursor(sh: Shooter) -> void:
	var col: Color = player(sh.slot).color
	var a := 0.45 if sh.lock_left > 0.0 else 1.0   # REQ-TS-6: a locked cursor is faded and has no dot.
	var c := sh.aim
	draw_arc(c, CURSOR_R, 0.0, TAU, 48, Color(UiTheme.OUTLINE, a), 14.0)
	draw_arc(c, CURSOR_R, 0.0, TAU, 48, Color(col, a), 8.0)
	if sh.can_fire():
		draw_circle(c, 7.0, UiTheme.OUTLINE)
		draw_circle(c, 4.0, col)
	# The slot number on a badge, so that players do not depend on the color alone (REQ-GM-46).
	var b := c + Vector2(CURSOR_R, -CURSOR_R) * 0.95
	draw_circle(b, BADGE_R + 4.0, Color(UiTheme.OUTLINE, a))
	draw_circle(b, BADGE_R, Color(col, a))
	draw_string(UiTheme.title_font(), b + Vector2(-BADGE_R, 8.0), str(sh.slot + 1), HORIZONTAL_ALIGNMENT_CENTER,
			BADGE_R * 2.0, 24, Color(1, 1, 1, a))


func _draw_pop(p: Pop) -> void:
	var life := p.age / POP_LIFE
	draw_arc(p.pos, 20.0 + p.age * 160.0, 0.0, TAU, 32, p.color, maxf(7.0 * (1.0 - life), 1.0))
	if p.text != "":
		Shell.text(self, p.pos + Vector2(-60.0, -30.0 - p.age * 90.0), p.text, 44, p.color, HORIZONTAL_ALIGNMENT_CENTER, 120.0)


func _draw_hud() -> void:
	Shell.title(self, "TARGET SHOOT")
	var ordered := Shell.in_slot_order(participants.map(func(s: int) -> Object: return player(s)))
	var spots := Shell.chip_positions(size.x, ordered.size())
	for i in ordered.size():
		var p: PlayerInput = ordered[i]
		Shell.chip(self, spots[i], "%s  %d" % [p.player_name, int(_board.score(p.slot))], p.color)
	if _round.is_playing() and not is_over:
		Shell.timer(self, Vector2(TIMER_X, 36.0), _round.remaining())
	if _round.is_counting() and not participants.is_empty():
		var n := _round.count_number()
		Shell.countdown(self, size, str(n) if n > 0 else "GO", _round.count_elapsed())
	if _round.time < HINT_TIME and not is_over:   # In the countdown the time is below 0.
		Shell.hint(self, size, "Point at the TV and press A. Recenter if the cursor drifts.")
