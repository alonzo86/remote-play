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
const TIMER_X := 520.0          # The timer box has a fixed place, between the title and the chips.
const TIMER_W := 208.0          # "60.0 S" in the 32 px font is 192 px wide. With 4 chips of 270 px the row still fits (a test).
const HINT_TIME := 4.0          # Seconds of play with the hint on the screen.

# Look (REQ-SS-12, REQ-GM-47i to 47n). The board is dark so that every player color has a contrast of 3:1 or more.
const BACKGROUND := Color("1b3a8a")
const BOARD_COLOR := Color("12205a")
const PUFF_COLORS := [Color("3ddcff"), Color("ff3d8b"), Color("57cc99")]   # Cyan, pink and green.
const LITTLE_COLOR := Color("ffd23f")                                      # Yellow.
const CURSOR_R := 40.0
const BADGE_R := 24.0           # 12 world pixels across: the slot number on it is drawn by the HUD (REQ-GM-47n).
const GROUND_H := 64.0          # The strip of snow at the bottom of the board.
const FLAKES := 28
const STAR_COUNT := 48
const POOF_STEPS := 3           # The poof of a snowball that missed grows in 3 hard steps.

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
var _stars := PackedVector2Array()
var _snow_time := 0.0            # Game time of the snowfall: it stands still while the game is paused (REQ-FL-43).


func _game_ready() -> void:
	_stars = Shell.star_field(STAR_COUNT, 17)
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
	_snow_time += delta
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
		return
	_field.take(puff)
	_board.add(f.slot, puff.points)
	_haptics.pulse(f.slot, 40, BUZZ_GAP_MS)
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

func _pixel_world() -> bool:
	return true


## The world: the sky, the board, the snowfall, the ground, the Puffs, the snowballs, the effects and the cursors. All text
## and the slot numbers are drawn by the HUD (REQ-GM-47n).
func _world_draw(ci: CanvasItem) -> void:
	var area := _area()
	var k := PuffField.scale_for(area)
	ci.draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	Shell.draw_stars(ci, _stars)
	ci.draw_rect(area.grow(12.0 + Shell.WORLD_PIXEL), UiTheme.OUTLINE)
	ci.draw_rect(area.grow(12.0), BOARD_COLOR)
	_draw_snowfall(ci, area)
	var ground := Rect2(Shell.snap(Vector2(area.position.x + 8.0, area.end.y - GROUND_H - 4.0)),
			Vector2(area.size.x - 16.0, GROUND_H))
	ci.draw_rect(ground.grow(Shell.WORLD_PIXEL), UiTheme.OUTLINE)
	ci.draw_rect(ground, Color.WHITE)
	for p in _field.puffs:
		_draw_puff(ci, PuffField.center_of(p, area), p.radius * k, _body_color(p.kind, p.color_index), p.dir, p.age, false, 0.0)
	for f in _flights:
		if f.age >= 0.0:
			_draw_snowball(ci, f)
	for e in _effects:
		if e.age >= 0.0:
			_draw_effect(ci, e)
	for s in _throwers:
		_draw_cursor(ci, _throwers[s])


func _game_draw() -> void:
	var area := _area()
	for s in _throwers:   # The slot number on the badge of each cursor.
		var t: Thrower = _throwers[s]
		Shell.ball_number(self, _badge_pos(t), BADGE_R, player(s).color, s)
	var k := PuffField.scale_for(area)
	for e in _effects:   # The points of a hit Puff float up with it.
		if e.age >= 0.0 and e.kind == "hit":
			var state := _hit_state(e)
			Shell.text_centered(self, state.center + Vector2(0.0, -state.radius - 20.0), e.text, 48, e.color)
	_draw_hud()


## A slow snowfall for the mood: square flakes of one or two world pixels. It depends on the game time only and makes no objects.
func _draw_snowfall(ci: CanvasItem, area: Rect2) -> void:
	for i in FLAKES:
		var x := area.position.x + fposmod(i * 211.3 + sin(i * 1.7) * 40.0, area.size.x)
		var y := area.position.y + fposmod(_snow_time * (28.0 + (i % 5) * 9.0) + i * 97.7, area.size.y - GROUND_H)
		ci.draw_rect(Rect2(Shell.snap(Vector2(x, y)), Vector2.ONE * Shell.WORLD_PIXEL * (1.0 + (i % 2))), Color.WHITE)


## A Puff: a round fuzzy body with tufts and small wings, big eyes that look the way it flies, and a smile (REQ-SS-12). One
## world pixel of outline, flat colors. `happy` closes the eyes with a smile. `snow` (0 to 1) puts snow on top (REQ-SS-13).
func _draw_puff(ci: CanvasItem, c: Vector2, r: float, body: Color, dir: int, age: float, happy: bool, snow: float) -> void:
	var ow := Shell.WORLD_PIXEL
	c = Shell.snap(c)
	var flap := snappedf(sin(age * 9.0) * r * 0.14, ow)
	var wing_l := c + Vector2(-r * 0.98, -r * 0.05 + flap)
	var wing_r := c + Vector2(r * 0.98, -r * 0.05 - flap)
	ci.draw_circle(wing_l, r * 0.3 + ow, UiTheme.OUTLINE)
	ci.draw_circle(wing_r, r * 0.3 + ow, UiTheme.OUTLINE)
	for i in 8:
		var a := i * TAU / 8.0
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.82, r * 0.34 + ow, UiTheme.OUTLINE)
	ci.draw_circle(c, r + ow, UiTheme.OUTLINE)
	ci.draw_circle(wing_l, r * 0.3, body)
	ci.draw_circle(wing_r, r * 0.3, body)
	for i in 8:
		var a2 := i * TAU / 8.0
		ci.draw_circle(c + Vector2(cos(a2), sin(a2)) * r * 0.82, r * 0.34, body)
	ci.draw_circle(c, r, body)
	if snow > 0.0:
		for cap in [[Vector2(0, -0.78), 0.4], [Vector2(-0.4, -0.6), 0.27], [Vector2(0.4, -0.62), 0.25]]:
			var cc: Vector2 = c + cap[0] * r
			ci.draw_circle(cc, r * cap[1] + ow, UiTheme.OUTLINE)
			ci.draw_circle(cc, r * cap[1], Color.WHITE)
	var eye_l := c + Vector2(-r * 0.3, -r * 0.1)
	var eye_r := c + Vector2(r * 0.3, -r * 0.1)
	if happy:
		ci.draw_arc(eye_l, r * 0.16, PI, TAU, 12, UiTheme.OUTLINE, ow)
		ci.draw_arc(eye_r, r * 0.16, PI, TAU, 12, UiTheme.OUTLINE, ow)
	else:
		for eye in [eye_l, eye_r]:
			ci.draw_circle(eye, r * 0.23 + ow, UiTheme.OUTLINE)
			ci.draw_circle(eye, r * 0.23, Color.WHITE)
			ci.draw_circle(eye + Vector2(dir * r * 0.08, r * 0.02), r * 0.11, UiTheme.OUTLINE)
	ci.draw_arc(c + Vector2(0, r * 0.1), r * 0.3, PI * 0.2, PI * 0.8, 16, UiTheme.OUTLINE, ow)


func _draw_snowball(ci: CanvasItem, f: Flight) -> void:
	var t := clampf(f.age / FLIGHT_TIME, 0.0, 1.0)
	var pos := Shell.snap(f.from.lerp(f.to, t) + Vector2(0.0, -sin(t * PI) * 60.0))
	var r := lerpf(20.0, 12.0, t)
	ci.draw_circle(pos, r + Shell.WORLD_PIXEL, UiTheme.OUTLINE)
	ci.draw_circle(pos, r, Color.WHITE)


## The center and the radius of a hit Puff that floats away (REQ-SS-13).
func _hit_state(e: Effect) -> Dictionary:
	var t := e.age / HIT_LIFE
	return {"center": e.pos + Vector2(0.0, -t * 150.0), "radius": e.radius * (1.0 - 0.45 * t)}


## The size step (0 to 2) of the poof of a missed snowball after `age` seconds.
static func poof_step(age: float) -> int:
	return clampi(floori(age / POOF_LIFE * POOF_STEPS), 0, POOF_STEPS - 1)


func _draw_effect(ci: CanvasItem, e: Effect) -> void:
	if e.kind == "poof":
		var step := poof_step(e.age)   # A white ring of snow in 3 hard steps, no fade.
		ci.draw_arc(Shell.snap(e.pos), 20.0 + step * 20.0, 0.0, TAU, 24, UiTheme.OUTLINE, Shell.WORLD_PIXEL * 3.0)
		ci.draw_arc(Shell.snap(e.pos), 20.0 + step * 20.0, 0.0, TAU, 24, Color.WHITE, Shell.WORLD_PIXEL)
		return
	var state := _hit_state(e)
	_draw_puff(ci, state.center, state.radius, e.body, e.dir, e.age, true, 1.0)


func _badge_pos(t: Thrower) -> Vector2:
	return Shell.snap(t.aim + Vector2(CURSOR_R, -CURSOR_R) * 0.95)


func _draw_cursor(ci: CanvasItem, t: Thrower) -> void:
	var col: Color = player(t.slot).color
	var c := Shell.snap(t.aim)
	ci.draw_arc(c, CURSOR_R, 0.0, TAU, 48, UiTheme.OUTLINE, Shell.WORLD_PIXEL * 4.0)
	ci.draw_arc(c, CURSOR_R, 0.0, TAU, 48, col, Shell.WORLD_PIXEL * 2.0)
	if t.can_throw():   # A snowball in the middle: ready to throw.
		ci.draw_circle(c, 12.0 + Shell.WORLD_PIXEL, UiTheme.OUTLINE)
		ci.draw_circle(c, 12.0, Color.WHITE)
	Shell.pixel_ball(ci, _badge_pos(t), BADGE_R, col)   # The slot number is on it, drawn by the HUD (REQ-GM-46).


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
