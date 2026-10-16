extends "res://scripts/game/minigame.gd"
## Banana Party (the id and the folder are still `snowball_splat`: they were the first name of the game). Each phone is a
## pointer: a circle in the player color follows `PlayerInput.pointer()`. A press on A throws a banana at the circle. Hungry
## animals walk across a jungle. The first banana that lands on an animal takes its points. A miss costs nothing
## (REQ-SS-1 to 17, 23). The game is for children too (REQ-GM-80 to 84).
## The RECENTER button of the phone recenters (REQ-GM-37); GO recenters all. B does nothing.
## The rules of the animals are in puff_field.gd, the pictures in banana_look.gd. This script has the input, the round and the
## drawing.

const PuffField = preload("res://scripts/game/snowball_splat/puff_field.gd")
const BananaLook = preload("res://scripts/game/snowball_splat/banana_look.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const ROUND_TIME := 60.0
const COUNTDOWN := 3.0
const RELOAD := 0.3             # Seconds before a player can throw again (REQ-SS-4).
const FLIGHT_TIME := 0.12       # Seconds that a banana flies (REQ-SS-6).

# The play area is the screen inside the margin, under the HUD (REQ-SS-3).
const AREA_TOP := 150.0
const AREA_MARGIN := 60.0
const TIMER_X := 520.0          # The timer box has a fixed place, between the title and the leader chip.
const TIMER_W := 208.0          # "60.0 S" in the 32 px font is 192 px wide.
const HINT_TIME := 4.0          # Seconds of play with the hint on the screen.

# Look (REQ-SS-12, REQ-GM-47i to 47n): the jungle and the animals are in banana_look.gd. The black bar on top is for the HUD.
const BAR_H := 112.0
const BUSH_DROP := 16.0         # A bush stands this much lower than the middle of its lane (px).
const CURSOR_R := 40.0
const POOF_STEPS := 3           # The poof of a banana that missed grows in 3 hard steps.
const POOF_COLOR := Color("ffe040")

const BUZZ_GAP_MS := 100        # REQ-GM-43.
const FLIGHT_COUNT := 12
const EFFECT_COUNT := 16
const HIT_LIFE := 1.0           # Seconds of the hit animation of an animal (REQ-SS-13).
const HIT_HOP := 0.5            # The jump at the start of it.
const HIT_HEIGHT := 72.0        # How high the animal jumps (px).
const POOF_LIFE := 0.35
const CHEER_GOLD := Color("ffd23f")   # The colors of the cheer effects, as constants (no parsing in a frame).
const CHEER_YELLOW := Color("ffe878")
const CHEER_WATER := Color("78c8ff")
const CHEER_HEART := Color("ff6ea0")

class Thrower:
	var slot := 0
	var aim := Vector2.ZERO
	var reload_left := 0.0

	func can_throw() -> bool:
		return reload_left <= 0.0

## A banana in the air. The pool is made once (REQ-GM-51).
class Flight:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var slot := 0
	var seq := 0       # The order of the throws.
	var age := -1.0    # Below 0: not in use.

## What stays after a banana landed: a hit animal that cheers with its points, or a small poof.
class Effect:
	var kind := "poof"
	var pos := Vector2.ZERO
	var text := ""
	var color := Color.WHITE      # The color of the player.
	var species := ""             # The animal that was hit (a key of `PuffField.KINDS`).
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
var _scene_time := 0.0           # Game time of the drifting leaves: they stand still while the game is paused (REQ-FL-43).
var _tex := {}                   # "kind|happy|facing" -> the ImageTexture of an animal.
var _banana_tex: Array[ImageTexture] = []
var _peel_tex: ImageTexture


func _game_ready() -> void:
	if start_props.has("seed"):
		_rng.seed = int(start_props.seed)   # REQ-SS-9: a test fixes the animals. Restart keeps the seed.
	else:
		_rng.randomize()
	_field.setup(difficulty)
	_field.place_bushes(_rng)
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
			f.age = -1.0   # The banana of a player who left is gone.


func _area() -> Rect2:
	return Rect2(AREA_MARGIN, AREA_TOP, size.x - 2.0 * AREA_MARGIN, size.y - AREA_TOP - AREA_MARGIN)


func _game_tick(delta: float) -> void:
	_scene_time += delta
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


## One throw of `slot` (REQ-SS-4): the banana starts to fly to the place of the cursor.
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
			Sound.sfx("snow_throw")   # The sound names are the first ones of the game.
			return


## The bananas fly. The ones that land are handled in the order they were thrown (REQ-SS-6, 11).
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


## A banana lands at `f.to` (REQ-SS-5, 10): it takes the animal there, or it makes a poof. A miss costs nothing.
func _land(f: Flight, area: Rect2) -> void:
	if not _throwers.has(f.slot):
		return
	var puff := _field.hit(f.to, area)
	if puff == null:
		_effect("poof", f.to, "", f.slot, "", 0.0, 1)
		Sound.sfx("snow_miss")
		return
	_field.take(puff)
	_board.add(f.slot, puff.points)
	_haptics.pulse(f.slot, 40, BUZZ_GAP_MS)
	Sound.sfx("snow_hit")
	Sound.sfx("snow_points", 1.0 + 0.12 * float(f.slot))   # Each player has a pitch (docs/AUDIO_PLAN.md, section 9).
	var k := PuffField.scale_for(area)
	_effect("hit", PuffField.center_of(puff, area), "+%d" % puff.points, f.slot, puff.kind, puff.radius * k, puff.dir)


func _effect(kind: String, pos: Vector2, text: String, slot: int, species: String, radius: float, dir: int) -> void:
	for e in _effects:
		if e.age < 0.0:
			e.kind = kind
			e.pos = pos
			e.text = text
			e.color = player(slot).color
			e.species = species
			e.radius = radius
			e.dir = dir
			e.age = 0.0
			return


func _finish() -> void:
	for s in _board.winners():
		App.server.haptic(s, 400)
	var tiers: Array = PuffField.LEVELS.get(difficulty, PuffField.LEVELS.medium).tiers
	var heading := ""
	var medal: Variant = null
	if _board.ranking().size() == 1:   # The medal picture has the difficulty that was played under it (REQ-SS-21).
		medal = Medals.medal(_board.ranking()[0].score, tiers)
		heading = Lang.t("game_settings." + difficulty)
	open_results(_board, tiers, heading, [], Callable(), medal)


# ---- Drawing ----

func _pixel_world() -> bool:
	return true


## The world: the jungle, the animals, the bananas, the effects and the cursors. All text is drawn by the HUD (REQ-GM-47n).
func _world_draw(ci: CanvasItem) -> void:
	var area := _area()
	BananaLook.draw_scene(ci, size, _scene_time, BAR_H)
	for lane in PuffField.LANES.size():   # Far to near, so that a bush covers the animal that walks behind it.
		for p in _field.puffs:
			if p.lane == lane:
				_draw_animal(ci, PuffField.center_of(p, area), p.kind, false, p.dir, 1.0)
		for b in _field.bushes:
			if b.lane == lane:
				_draw_bush(ci, b, area)
	for e in _effects:
		if e.age >= 0.0 and e.kind == "hit":
			_draw_peel(ci, e)
	for e in _effects:
		if e.age >= 0.0:
			_draw_effect(ci, e)
	for f in _flights:
		if f.age >= 0.0:
			_draw_banana(ci, f)
	for s in _throwers:
		_draw_cursor(ci, _throwers[s])
	ci.draw_rect(Rect2(0, 0, size.x, BAR_H), UiTheme.BG)


func _game_draw() -> void:
	for e in _effects:   # The points of a hit animal float up with it.
		if e.age >= 0.0 and e.kind == "hit":
			var state := _hit_state(e)
			var big := e.species == PuffField.BONUS_KIND
			Shell.text_centered(self, state.center + Vector2(0.0, -state.radius - 20.0 - e.age * 30.0), e.text, 64 if big else 48,
					UiTheme.ACCENT if big else e.color)
	_draw_hud()


## The texture of an animal, made when it is needed (REQ-GM-51: nothing is made in each frame).
func _animal_texture(kind: String, happy: bool, facing: int) -> ImageTexture:
	var key := "%s|%s|%d" % [kind, happy, facing]
	if not _tex.has(key):
		_tex[key] = ImageTexture.create_from_image(BananaLook.animal_image(kind, happy, facing))
	return _tex[key]


## An animal at the screen position `c`: `scale` 1 is one picture pixel for one world pixel.
func _draw_animal(ci: CanvasItem, c: Vector2, kind: String, happy: bool, dir: int, scale: float) -> void:
	var tex := _animal_texture(kind, happy, dir)
	var sz := Vector2(tex.get_size()) * Shell.WORLD_PIXEL * scale
	ci.draw_texture_rect(tex, Rect2(Shell.snap(c - sz * 0.5), sz), false)


## A bush: its middle is at the middle of the lane, a little lower, so that the animals of the lane are covered (REQ-SS-26).
func _draw_bush(ci: CanvasItem, b: PuffField.Bush, area: Rect2) -> void:
	if not _tex.has("bush"):
		_tex["bush"] = ImageTexture.create_from_image(BananaLook.bush_image())
	var tex: ImageTexture = _tex["bush"]
	var k := area.size / PuffField.REF_AREA
	var c := area.position + Vector2(b.x, float(PuffField.LANES[b.lane].y) + BUSH_DROP) * k
	var sz := Vector2(tex.get_size()) * Shell.WORLD_PIXEL
	ci.draw_texture_rect(tex, Rect2(Shell.snap(c - sz * 0.5), sz), false)


## The size of a hit animal at the end of its animation: it shrinks in 4 steps in the last fifth, and then it is gone.
static func leave_scale(t: float) -> float:
	var u := clampf((t - 0.8) / 0.2, 0.0, 1.0)
	return 1.0 if u <= 0.0 else ceilf((1.0 - u) * 4.0) / 4.0


## The center and the radius of a hit animal (REQ-SS-13): it jumps once and then stands and cheers.
func _hit_state(e: Effect) -> Dictionary:
	var hop := sin(clampf(e.age / HIT_HOP, 0.0, 1.0) * PI) * HIT_HEIGHT
	return {"center": e.pos + Vector2(0.0, -hop), "radius": e.radius}


## The banana peel that an animal leaves where it was hit.
func _draw_peel(ci: CanvasItem, e: Effect) -> void:
	if e.age < HIT_HOP:
		return
	if _peel_tex == null:
		_peel_tex = ImageTexture.create_from_image(BananaLook.peel_image())
	var sz := Vector2(_peel_tex.get_size()) * Shell.WORLD_PIXEL
	var feet := e.pos + Vector2(-e.dir * e.radius * 0.3, e.radius * 0.7)
	ci.draw_texture_rect(_peel_tex, Rect2(Shell.snap(feet - sz * 0.5), sz), false)


## The size step (0 to 2) of the poof of a missed banana after `age` seconds.
static func poof_step(age: float) -> int:
	return clampi(floori(age / POOF_LIFE * POOF_STEPS), 0, POOF_STEPS - 1)


func _banana_texture(turn: int) -> ImageTexture:
	if _banana_tex.is_empty():
		for i in 4:
			_banana_tex.append(ImageTexture.create_from_image(BananaLook.banana_image(i)))
	return _banana_tex[posmod(turn, 4)]


## A banana in the air: it turns a quarter every 15 ms of flight and flies in a small arc.
func _draw_banana(ci: CanvasItem, f: Flight) -> void:
	var t := clampf(f.age / FLIGHT_TIME, 0.0, 1.0)
	var pos := f.from.lerp(f.to, t) + Vector2(0.0, -sin(t * PI) * 60.0)
	var tex := _banana_texture(int(f.age / 0.03))
	var sz := Vector2(tex.get_size()) * Shell.WORLD_PIXEL * lerpf(1.4, 1.0, t)
	ci.draw_texture_rect(tex, Rect2(Shell.snap(pos - sz * 0.5), sz), false)


func _draw_effect(ci: CanvasItem, e: Effect) -> void:
	if e.kind == "poof":
		var step := poof_step(e.age)   # A ring in 3 hard steps, no fade.
		ci.draw_arc(Shell.snap(e.pos), 20.0 + step * 20.0, 0.0, TAU, 24, UiTheme.OUTLINE, Shell.WORLD_PIXEL * 3.0)
		ci.draw_arc(Shell.snap(e.pos), 20.0 + step * 20.0, 0.0, TAU, 24, POOF_COLOR, Shell.WORLD_PIXEL)
		return
	var state := _hit_state(e)
	var t := e.age / HIT_LIFE
	var center: Vector2 = state.center
	var dir := e.dir
	match e.species:   # Each animal cheers in its own way (REQ-SS-13).
		"gorilla":   # It beats its chest: a shake.
			if t > 0.4 and t < 0.8:
				center.x += 8.0 * signf(sin(e.age * 40.0))
		"sloth":   # A slow wiggle.
			center.x += 10.0 * sin(e.age * 9.0)
		"lemur":   # It spins around: it turns to the other side every 0.1 s.
			if t > 0.4:
				dir = e.dir if int(e.age * 10.0) % 2 == 0 else -e.dir
	var scale := leave_scale(t)
	if scale > 0.0:
		_draw_animal(ci, center, e.species, true, dir, scale)
	_draw_cheer(ci, e, center, t)


## The sparkles around a hit animal, and the extras of some animals: water from the elephant, hearts from the orangutan, gold
## from the golden monkey. Squares of one or two world pixels that move with the age; nothing is made in the frame.
func _draw_cheer(ci: CanvasItem, e: Effect, center: Vector2, t: float) -> void:
	var px := Shell.WORLD_PIXEL
	var gold := e.species == PuffField.BONUS_KIND
	var reach := e.radius * 1.15
	for i in 4 + (6 if gold else 0):   # Sparkles in a ring that turns in 4 steps.
		var a := float(i) / float(4 + (6 if gold else 0)) * TAU + floorf(t * 8.0) * 0.4
		var pos := Shell.snap(center + Vector2(cos(a), sin(a) * 0.8) * reach * (1.0 + 0.12 * float(i % 3)))
		var color := Color.WHITE if i % 2 == 0 else (CHEER_GOLD if gold else CHEER_YELLOW)
		ci.draw_rect(Rect2(pos - Vector2(px, 0.0), Vector2(3.0 * px, px)), color)
		ci.draw_rect(Rect2(pos - Vector2(0.0, px), Vector2(px, 3.0 * px)), color)
	match e.species:
		"elephant":   # Water from the trunk: drops in arcs.
			if e.age < 0.7:
				var origin := center + Vector2(e.dir * e.radius * 0.95, -e.radius * 0.1)
				for i in 6:
					var v := Vector2(e.dir * (60.0 + 40.0 * float(i % 3)), -260.0 + 30.0 * float(i))
					var p := Shell.snap(origin + v * e.age + Vector2(0.0, 520.0) * e.age * e.age)
					ci.draw_rect(Rect2(p, Vector2.ONE * 2.0 * px), CHEER_WATER)
		"orangutan":   # Hearts that float up.
			for i in 3:
				var h := Shell.snap(center + Vector2((float(i) - 1.0) * e.radius * 0.7, -e.radius * 0.9 - e.age * 70.0 - float(i) * 12.0))
				if e.age > 0.2:
					ci.draw_rect(Rect2(h, Vector2(px, px)), CHEER_HEART)
					ci.draw_rect(Rect2(h + Vector2(2.0 * px, 0.0), Vector2(px, px)), CHEER_HEART)
					ci.draw_rect(Rect2(h + Vector2(0.0, px), Vector2(3.0 * px, px)), CHEER_HEART)
					ci.draw_rect(Rect2(h + Vector2(px, 2.0 * px), Vector2(px, px)), CHEER_HEART)


func _draw_cursor(ci: CanvasItem, t: Thrower) -> void:
	var c := Shell.snap(t.aim)   # A plain circle in the color of the player, with a dark edge so it shows on the green.
	ci.draw_arc(c, CURSOR_R, 0.0, TAU, 48, UiTheme.OUTLINE, Shell.WORLD_PIXEL * 4.0)
	ci.draw_arc(c, CURSOR_R, 0.0, TAU, 48, player(t.slot).color, Shell.WORLD_PIXEL * 2.0)


func _scoreboard() -> Scoreboard:
	return _board


func _draw_hud() -> void:
	Shell.title(self, "registry.snowball_splat")
	draw_leader_chip(self)
	if _round.is_playing() and not is_over:
		Shell.timer(self, Vector2(TIMER_X, 36.0), _round.remaining(), TIMER_W)
	if _round.is_counting() and not participants.is_empty():
		var n := _round.count_number()
		Shell.countdown(self, size, str(n) if n > 0 else "shell.go", _round.count_elapsed())
		var spots := {}
		for s in _throwers:
			spots[s] = Shell.snap((_throwers[s] as Thrower).aim)
		draw_name_tags(self, spots, CURSOR_R)
	if _round.time < HINT_TIME and not is_over:   # In the countdown the time is below 0.
		Shell.hint(self, size, "snowball_splat.point_at_tv_press")


func best_key() -> String:
	return "snowball_splat|%s" % difficulty
