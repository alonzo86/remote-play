extends "res://scripts/game/minigame.gd"
## Snowball Splat. Each phone is a pointer: a cursor in the player color follows `PlayerInput.pointer()`. A press on A throws a
## snowball at the cursor. Big, friendly Puffs float slowly across the sky. The first snowball that lands on a Puff takes its
## points. A miss costs nothing (REQ-SS-1 to 17). The game is for children too (REQ-GM-80 to 84).
## The RECENTER button of the phone recenters (REQ-GM-37); GO recenters all. B does nothing.
## The rules of the Puffs are in puff_field.gd. This script has the input, the round and the drawing.

const PuffField = preload("res://scripts/game/snowball_splat/puff_field.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const ROUND_TIME := 60.0
const COUNTDOWN := 3.0
const RELOAD := 0.3             # Seconds before a player can throw again (REQ-SS-4).
const FLIGHT_TIME := 0.12       # Seconds that a snowball flies (REQ-SS-6).

# The play area is the screen inside the margin, under the HUD (REQ-SS-3).
const AREA_TOP := 150.0
const AREA_MARGIN := 60.0
const TIMER_X := 560.0          # The timer pill has a fixed place, between the title and the chips.
const TIMER_W := 160.0          # The chips of 4 players are at most 1110 px wide, so they start right of the timer.
const HINT_TIME := 4.0          # Seconds of play with the hint on the screen.

# Look (REQ-SS-12, REQ-GM-47). The board is dark so that every player color has a contrast of 3:1 or more.
const BACKGROUND := Color("1b3a8a")
const BOARD_COLOR := Color("12205a")
const PUFF_COLORS := [Color("3ddcff"), Color("ff3d8b"), Color("57cc99")]   # Party Pop cyan, pink and OK green.
const LITTLE_COLOR := Color("ffd23f")                                      # Party Pop yellow.
const OUTLINE_BIG := 6.0
const CURSOR_R := 40.0
const BADGE_R := 17.0
const GROUND_H := 64.0          # The strip of snow at the bottom of the board.
const FLAKES := 28

const BUZZ_GAP_MS := 100        # REQ-GM-43.
const FLIGHT_COUNT := 12
const EFFECT_COUNT := 16
const HIT_LIFE := 0.8           # Seconds that a hit Puff floats away (REQ-SS-13).
const POOF_LIFE := 0.35

class Thrower:
	var slot := 0
	var aim := Vector2.ZERO
	var reload_left := 0.0

	func can_throw() -> bool:
		return reload_left <= 0.0

## A snowball in the air. The pool is made once (REQ-GM-51).
class Flight:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var slot := 0
	var seq := 0       # The order of the throws.
	var age := -1.0    # Below 0: not in use.

## What stays after a snowball landed: a hit Puff that floats away with its points, or a small poof of snow.
class Effect:
	var kind := "poof"
	var pos := Vector2.ZERO
	var text := ""
	var color := Color.WHITE      # The color of the player.
	var body := Color.WHITE       # The color of the Puff.
	var radius := 0.0
	var dir := 1
	var age := -1.0   # Below 0: not in use.

## Set before the game starts (REQ-GM-93). `start_props` keeps it for Restart.
var difficulty := "medium"

var _round := RoundClock.new(COUNTDOWN, ROUND_TIME)
var _field := PuffField.new()
var _board: Scoreboard
var _rng := RandomNumberGenerator.new()
var _haptics := Haptics.new()
var _throwers := {}              # slot -> Thrower
var _presses: Array[int] = []    # Slots of the A presses, in the order they arrived (REQ-SS-11).
var _flights: Array[Flight] = []
var _effects: Array[Effect] = []
var _seq := 0
var _sb_board: StyleBoxFlat      # Made once. Drawing must not create objects every frame (REQ-GM-51).
var _sb_snow: StyleBoxFlat


func _game_ready() -> void:
	_sb_board = UiTheme.card(BOARD_COLOR, UiTheme.OUTLINE, UiTheme.OUTLINE_W, 30, true)
	_sb_snow = UiTheme.card(Color.WHITE, UiTheme.OUTLINE, int(OUTLINE_BIG) - 1, 28, false)
	if start_props.has("seed"):
		_rng.seed = int(start_props.seed)   # REQ-SS-9: a test fixes the Puffs. Restart keeps the seed.
	else:
		_rng.randomize()
	_field.setup(difficulty)
	_board = Scoreboard.new(participants)
	for s in participants:
		var t := Thrower.new()
		t.slot = s
		_throwers[s] = t
		player(s).button_pressed.connect(_on_button.bind(s))
	for i in FLIGHT_COUNT:
		_flights.append(Flight.new())
	for i in EFFECT_COUNT:
		_effects.append(Effect.new())


func _exit_tree() -> void:
	for s in _throwers:
		var cb := _on_button.bind(s)
		if player(s).button_pressed.is_connected(cb):
			player(s).button_pressed.disconnect(cb)


## REQ-SS-4: a press on A is a throw. It is kept until the next tick, so that throws are handled in the order they came.
func _on_button(bit: int, slot: int) -> void:
	if bit != Protocol.BTN_A or is_paused() or is_over or _round.is_counting():
		return
	_presses.append(slot)


func _on_player_left(slot: int) -> void:
	_throwers.erase(slot)
	_board.remove(slot)
	_presses = _presses.filter(func(s: int) -> bool: return s != slot)
	for f in _flights:
		if f.slot == slot:
			f.age = -1.0   # The snowball of a player who left is gone.


func _area() -> Rect2:
	return Rect2(AREA_MARGIN, AREA_TOP, size.x - 2.0 * AREA_MARGIN, size.y - AREA_TOP - AREA_MARGIN)


func _game_tick(delta: float) -> void:
	if is_over:
		return
	var area := _area()
	for s in _throwers:
		var t: Thrower = _throwers[s]
		t.aim = PuffField.aim_to_screen(player(s).pointer(), area)
		t.reload_left = maxf(t.reload_left - delta, 0.0)
	if _round.is_counting():
		if _round.tick(delta):
			for s in _throwers:
				player(s).recenter()   # REQ-SS-2: the pose held in the countdown is the center.
				App.server.haptic(s, 60)
		return
	_round.tick(delta)
	for s in _presses:
		_throw(s, area)
	_presses.clear()
	_fly(delta, area)
	_field.tick(delta, _rng, participants.size())
	for e in _effects:
		if e.age >= 0.0:
			e.age += delta
			if e.age > (HIT_LIFE if e.kind == "hit" else POOF_LIFE):
				e.age = -1.0
	if _round.is_time_up():
		_finish()


## One throw of `slot` (REQ-SS-4): the snowball starts to fly to the place of the cursor.
func _throw(slot: int, area: Rect2) -> void:
	if not _throwers.has(slot):
		return
	var t: Thrower = _throwers[slot]
	if not t.can_throw():
		return
	for f in _flights:
		if f.age < 0.0:
			t.reload_left = RELOAD
			f.from = Vector2(t.aim.x, area.end.y)
			f.to = t.aim
			f.slot = slot
			f.seq = _seq
			_seq += 1
			f.age = 0.0
			_haptics.pulse(slot, 15, BUZZ_GAP_MS)
			Sound.sfx("snow_throw")
			return


## The snowballs fly. The ones that land are handled in the order they were thrown (REQ-SS-6, 11).
func _fly(delta: float, area: Rect2) -> void:
	for f in _flights:
		if f.age >= 0.0:
			f.age += delta
	while true:
		var next: Flight = null
		for f in _flights:
			if f.age >= FLIGHT_TIME and (next == null or f.seq < next.seq):
				next = f
		if next == null:
			return
		next.age = -1.0
		_land(next, area)


## A snowball lands at `f.to` (REQ-SS-5, 10): it takes the Puff there, or it makes a poof. A miss costs nothing.
func _land(f: Flight, area: Rect2) -> void:
	if not _throwers.has(f.slot):
		return
	var puff := _field.hit(f.to, area)
	if puff == null:
		_effect("poof", f.to, "", f.slot, Color.WHITE, 0.0, 1)
		Sound.sfx("snow_miss")
		return
	_field.take(puff)
	_board.add(f.slot, puff.points)
	_haptics.pulse(f.slot, 40, BUZZ_GAP_MS)
	Sound.sfx("snow_hit")
	Sound.sfx("snow_points", 1.0 + 0.12 * float(f.slot))   # Each player has a pitch (docs/AUDIO_PLAN.md, section 9).
	var k := PuffField.scale_for(area)
	_effect("hit", PuffField.center_of(puff, area), "+%d" % puff.points, f.slot, _body_color(puff.kind, puff.color_index),
			puff.radius * k, puff.dir)


func _body_color(kind: String, color_index: int) -> Color:
	return LITTLE_COLOR if kind == "little" else PUFF_COLORS[color_index]


func _effect(kind: String, pos: Vector2, text: String, slot: int, body: Color, radius: float, dir: int) -> void:
	for e in _effects:
		if e.age < 0.0:
			e.kind = kind
			e.pos = pos
			e.text = text
			e.color = player(slot).color
			e.body = body
			e.radius = radius
			e.dir = dir
			e.age = 0.0
			return


func _finish() -> void:
	for s in _board.winners():
		App.server.haptic(s, 400)
	var tiers: Array = PuffField.LEVELS.get(difficulty, PuffField.LEVELS.medium).tiers
	var heading := ""
	if _board.ranking().size() == 1:   # The medal text says which difficulty was played (REQ-SS-21).
		var medal := Medals.medal(_board.ranking()[0].score, tiers)
		heading = "%s (%s)" % [Medals.label(medal), difficulty.capitalize()]
	open_results(_board, tiers, heading)


# ---- Drawing ----

func _game_draw() -> void:
	var area := _area()
	var k := PuffField.scale_for(area)
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_style_box(_sb_board, area.grow(12.0))
	_draw_snowfall(area)
	draw_style_box(_sb_snow, Rect2(area.position.x + 6.0, area.end.y - GROUND_H - 4.0, area.size.x - 12.0, GROUND_H))
	for p in _field.puffs:
		_draw_puff(PuffField.center_of(p, area), p.radius * k, _body_color(p.kind, p.color_index), p.dir, p.age, false, 0.0)
	for f in _flights:
		if f.age >= 0.0:
			_draw_snowball(f)
	for e in _effects:
		if e.age >= 0.0:
			_draw_effect(e)
	for s in _throwers:
		_draw_cursor(_throwers[s])
	_draw_hud()


## A slow snowfall for the mood. It only depends on the clock, and it makes no objects.
func _draw_snowfall(area: Rect2) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in FLAKES:
		var x := area.position.x + fposmod(i * 211.3 + sin(i * 1.7) * 40.0, area.size.x)
		var y := area.position.y + fposmod(t * (28.0 + (i % 5) * 9.0) + i * 97.7, area.size.y - GROUND_H)
		draw_circle(Vector2(x, y), 3.0 + (i % 3) * 1.5, Color(1, 1, 1, 0.8))


## A Puff: a round fuzzy body with tufts and small wings, big eyes that look the way it flies, and a smile (REQ-SS-12).
## `happy` closes the eyes with a smile. `snow` from 0 to 1 covers the top with snow (REQ-SS-13).
func _draw_puff(c: Vector2, r: float, body: Color, dir: int, age: float, happy: bool, snow: float) -> void:
	var ow := maxf(OUTLINE_BIG * (r / 100.0), 3.0)
	var flap := sin(age * 9.0) * r * 0.14
	var wing_l := c + Vector2(-r * 0.98, -r * 0.05 + flap)
	var wing_r := c + Vector2(r * 0.98, -r * 0.05 - flap)
	var wing := body.lightened(0.25)
	draw_circle(wing_l, r * 0.3 + ow, UiTheme.OUTLINE)
	draw_circle(wing_r, r * 0.3 + ow, UiTheme.OUTLINE)
	for i in 8:
		var a := i * TAU / 8.0
		draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.82, r * 0.34 + ow, UiTheme.OUTLINE)
	draw_circle(c, r + ow * 0.4, UiTheme.OUTLINE)
	draw_circle(wing_l, r * 0.3, wing)
	draw_circle(wing_r, r * 0.3, wing)
	for i in 8:
		var a2 := i * TAU / 8.0
		draw_circle(c + Vector2(cos(a2), sin(a2)) * r * 0.82, r * 0.34, body)
	draw_circle(c, r * 0.96, body)
	if snow > 0.0:
		for cap in [[Vector2(0, -0.78), 0.4], [Vector2(-0.4, -0.6), 0.27], [Vector2(0.4, -0.62), 0.25]]:
			var cc: Vector2 = c + cap[0] * r
			draw_circle(cc, r * cap[1] + ow * 0.5, UiTheme.OUTLINE)
			draw_circle(cc, r * cap[1], Color.WHITE)
	var eye_l := c + Vector2(-r * 0.3, -r * 0.1)
	var eye_r := c + Vector2(r * 0.3, -r * 0.1)
	if happy:
		draw_arc(eye_l, r * 0.16, PI, TAU, 12, UiTheme.OUTLINE, ow)
		draw_arc(eye_r, r * 0.16, PI, TAU, 12, UiTheme.OUTLINE, ow)
	else:
		for eye in [eye_l, eye_r]:
			draw_circle(eye, r * 0.23 + ow * 0.5, UiTheme.OUTLINE)
			draw_circle(eye, r * 0.23, Color.WHITE)
			draw_circle(eye + Vector2(dir * r * 0.08, r * 0.02), r * 0.11, UiTheme.OUTLINE)
	draw_arc(c + Vector2(0, r * 0.1), r * 0.3, PI * 0.2, PI * 0.8, 16, UiTheme.OUTLINE, ow)


func _draw_snowball(f: Flight) -> void:
	var t := clampf(f.age / FLIGHT_TIME, 0.0, 1.0)
	var pos := f.from.lerp(f.to, t) + Vector2(0.0, -sin(t * PI) * 60.0)
	var r := lerpf(18.0, 11.0, t)
	draw_circle(pos, r + 4.0, UiTheme.OUTLINE)
	draw_circle(pos, r, Color.WHITE)


func _draw_effect(e: Effect) -> void:
	if e.kind == "poof":
		var life := e.age / POOF_LIFE
		var a := 1.0 - life
		draw_circle(e.pos, 14.0 + life * 30.0, Color(1, 1, 1, a * 0.8))
		draw_arc(e.pos, 20.0 + life * 44.0, 0.0, TAU, 24, Color(UiTheme.OUTLINE, a * 0.6), 4.0)
		return
	var t := e.age / HIT_LIFE
	var c := e.pos + Vector2(0.0, -t * 150.0)
	_draw_puff(c, e.radius * (1.0 - 0.45 * t), e.body, e.dir, e.age, true, 1.0)
	var top := c + Vector2(-70.0, -e.radius * (1.0 - 0.45 * t) - 20.0)
	Shell.text(self, top, e.text, 48, e.color, HORIZONTAL_ALIGNMENT_CENTER, 140.0)


func _draw_cursor(t: Thrower) -> void:
	var col: Color = player(t.slot).color
	var c := t.aim
	draw_arc(c, CURSOR_R, 0.0, TAU, 48, UiTheme.OUTLINE, 14.0)
	draw_arc(c, CURSOR_R, 0.0, TAU, 48, col, 8.0)
	if t.can_throw():   # A snowball in the middle: ready to throw.
		draw_circle(c, 12.0, UiTheme.OUTLINE)
		draw_circle(c, 9.0, Color.WHITE)
	# The slot number on a badge, so that players do not depend on the color alone (REQ-GM-46).
	var b := c + Vector2(CURSOR_R, -CURSOR_R) * 0.95
	draw_circle(b, BADGE_R + 4.0, UiTheme.OUTLINE)
	draw_circle(b, BADGE_R, col)
	draw_string(UiTheme.title_font(), b + Vector2(-BADGE_R, 8.0), str(t.slot + 1), HORIZONTAL_ALIGNMENT_CENTER,
			BADGE_R * 2.0, 24, Color.WHITE)


func _draw_hud() -> void:
	Shell.title(self, "SNOWBALL SPLAT")
	var scores := {}
	for slot in participants:
		scores[slot] = str(int(_board.score(slot)))
	Shell.player_chips(self, size.x, participants.map(func(s: int) -> Object: return player(s)), scores,
			size.x - 60.0 - (TIMER_X + TIMER_W + 20.0))
	if _round.is_playing() and not is_over:
		Shell.timer(self, Vector2(TIMER_X, 36.0), _round.remaining(), TIMER_W)
	if _round.is_counting() and not participants.is_empty():
		var n := _round.count_number()
		Shell.countdown(self, size, str(n) if n > 0 else "GO", _round.count_elapsed())
	if _round.time < HINT_TIME and not is_over:   # In the countdown the time is below 0.
		Shell.hint(self, size, "Point at the TV and press A to throw a snowball. Recenter if the cursor drifts.")
