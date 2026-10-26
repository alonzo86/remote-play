extends "res://scripts/game/minigame.gd"
## Whack-a-Mole. Each phone is a pointer: a ring in the player color follows `PlayerInput.pointer()`. Friendly moles pop out of
## nine holes. A press on A bonks the mole under the ring; the first bonk that lands on a mole takes its points. A miss costs
## nothing (REQ-WM-1 to 16). The game is for children too (REQ-GM-80 to 84).
## The RECENTER button of the phone recenters (REQ-GM-37); GO recenters all. B does nothing.
## The rules of the moles are in mole_field.gd, the pictures in mole_look.gd. This script has the input, the round and the
## drawing.

const MoleField = preload("res://scripts/game/whack_a_mole/mole_field.gd")
const MoleLook = preload("res://scripts/game/whack_a_mole/mole_look.gd")
const PointerMap = preload("res://scripts/game/pointer_map.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const ROUND_TIME := 60.0
const COUNTDOWN := 3.0
const RELOAD := 0.3             # Seconds before a player can bonk again (REQ-WM-4).
const HINT_TIME := 4.0          # Seconds of play with the hint on the screen.

# The play area is the screen inside the margin, under the HUD (REQ-WM-3).
const AREA_TOP := 150.0
const AREA_MARGIN := 60.0
const TIMER_X := Shell.TIMER_X  # The timer box has the same place in every game (REQ-GM-47o).
const TIMER_W := 208.0
const BAR_H := 112.0            # The black bar on top is for the HUD.
const CURSOR_R := 40.0
const POOF_COLOR := Color("ffe040")
const POOF_STEPS := 3           # The poof of a bonk that missed grows in 3 hard steps.
const POOF_LIFE := 0.35
const BUZZ_GAP_MS := 100        # REQ-GM-43.
const EFFECT_COUNT := 16
const SPARKLE_WHITE := Color.WHITE

class Player:
	var slot := 0
	var aim := Vector2.ZERO
	var reload_left := 0.0

	func can_bonk() -> bool:
		return reload_left <= 0.0

## A poof of a missed bonk. The pool is made once (REQ-GM-51).
class Poof:
	var pos := Vector2.ZERO
	var age := -1.0   # Below 0: not in use.

## The points that float up from a hit mole.
class Pop:
	var pos := Vector2.ZERO
	var text := ""
	var color := Color.WHITE
	var golden := false
	var age := -1.0   # Below 0: not in use.

## Set before the game starts (REQ-GM-93). `start_props` keeps it for Restart.
var difficulty := "medium"

var _round := RoundClock.new(COUNTDOWN, ROUND_TIME)
var _field := MoleField.new()
var _board: Scoreboard
var _rng := RandomNumberGenerator.new()
var _haptics := Haptics.new()
var _players := {}               # slot -> Player
var _presses: Array[int] = []    # Slots of the A presses, in the order they arrived (REQ-WM-4).
var _poofs: Array[Poof] = []
var _pops: Array[Pop] = []
var _scene_time := 0.0           # Game time of the clouds: they stand still while the game is paused (REQ-FL-43).
var _tex := {}                   # "golden|happy" -> the ImageTexture of a mole.


func _game_ready() -> void:
	if start_props.has("seed"):
		_rng.seed = int(start_props.seed)   # REQ-WM-9: a test fixes the moles. Restart keeps the seed.
	else:
		_rng.randomize()
	_field.setup(difficulty)
	_board = Scoreboard.new(participants)
	for s in participants:
		var t := Player.new()
		t.slot = s
		_players[s] = t
		player(s).button_pressed.connect(_on_button.bind(s))
	for i in EFFECT_COUNT:
		_poofs.append(Poof.new())
		_pops.append(Pop.new())


func _exit_tree() -> void:
	for s in _players:
		var cb := _on_button.bind(s)
		if player(s).button_pressed.is_connected(cb):
			player(s).button_pressed.disconnect(cb)


## REQ-WM-4: a press on A is a bonk. It is kept until the next tick, so that bonks are handled in the order they came.
func _on_button(bit: int, slot: int) -> void:
	if bit != Protocol.BTN_A or is_paused() or is_over or _round.is_counting():
		return
	_presses.append(slot)


func _on_player_left(slot: int) -> void:
	_players.erase(slot)
	_board.remove(slot)
	_presses = _presses.filter(func(s: int) -> bool: return s != slot)


func _area() -> Rect2:
	return Rect2(AREA_MARGIN, AREA_TOP, size.x - 2.0 * AREA_MARGIN, size.y - AREA_TOP - AREA_MARGIN)


func _game_tick(delta: float) -> void:
	_scene_time += delta
	if is_over:
		return
	var area := _area()
	for s in _players:
		var t: Player = _players[s]
		t.aim = PointerMap.aim_to_screen(player(s).pointer(), area)   # The same mapping as Banana Party (REQ-WM-3).
		t.reload_left = maxf(t.reload_left - delta, 0.0)
	if _round.is_counting():
		if _round.tick(delta):
			for s in _players:
				player(s).recenter()   # REQ-WM-2: the pose held in the countdown is the center.
				App.server.haptic(s, 60)
		return
	_round.tick(delta)
	_field.tick(delta, _rng, participants.size())
	for s in _presses:
		_bonk(s, area)
	_presses.clear()
	for p in _poofs:
		if p.age >= 0.0:
			p.age += delta
			if p.age > POOF_LIFE:
				p.age = -1.0
	for p in _pops:
		if p.age >= 0.0:
			p.age += delta
			if p.age > MoleField.HIT_LIFE:
				p.age = -1.0
	if _round.is_time_up():
		_finish()


## One bonk of `slot` at the place of its ring (REQ-WM-4, 5, 7): it takes the mole there, or makes a poof. A miss costs nothing.
func _bonk(slot: int, area: Rect2) -> void:
	if not _players.has(slot):
		return
	var t: Player = _players[slot]
	if not t.can_bonk():
		return
	t.reload_left = RELOAD
	var mole := _field.hit(t.aim, area)
	if mole == null:
		_poof(t.aim)
		_haptics.pulse(slot, 15, BUZZ_GAP_MS)
		Sound.sfx("mole_miss")
		return
	_field.take(mole)
	_board.add(slot, mole.points())
	_haptics.pulse(slot, 40, BUZZ_GAP_MS)
	Sound.sfx("mole_hit")
	Sound.sfx("mole_points", 1.0 + 0.12 * float(slot))   # Each player has a pitch (docs/AUDIO_PLAN.md, section 9).
	for p in _pops:
		if p.age < 0.0:
			p.pos = MoleField.head_pos(mole, area)
			p.text = "+%d" % mole.points()
			p.color = player(slot).color
			p.golden = mole.golden
			p.age = 0.0
			break


func _poof(pos: Vector2) -> void:
	for p in _poofs:
		if p.age < 0.0:
			p.pos = pos
			p.age = 0.0
			return


func _finish() -> void:
	for s in _board.winners():
		App.server.haptic(s, 400)
	open_results(_board)


# ---- Drawing ----

func _pixel_world() -> bool:
	return true


## The world: the meadow, the holes with the moles, the poofs and the rings. All text is drawn by the HUD (REQ-GM-47n).
func _world_draw(ci: CanvasItem) -> void:
	var area := _area()
	var k := MoleField.scale_for(area)
	MoleLook.draw_scene(ci, size, _scene_time, BAR_H)
	for hole in 9:   # Back to front, so that the mole of a hole in front covers the one behind it.
		var c := MoleField.hole_pos(hole, area)
		MoleLook.draw_hole_back(ci, c, k)
		for m in _field.moles:
			if m.hole == hole:
				_draw_mole(ci, m, c, k)
		MoleLook.draw_hole_front(ci, c, k)
	for m in _field.moles:
		if m.is_hit():
			_draw_sparkles(ci, m, MoleField.head_pos(m, area))
	for p in _poofs:
		if p.age >= 0.0:
			var step := clampi(floori(p.age / POOF_LIFE * POOF_STEPS), 0, POOF_STEPS - 1)   # A ring in 3 hard steps, no fade.
			ci.draw_arc(Shell.snap(p.pos), 20.0 + step * 20.0, 0.0, TAU, 24, UiTheme.OUTLINE, Shell.WORLD_PIXEL * 3.0)
			ci.draw_arc(Shell.snap(p.pos), 20.0 + step * 20.0, 0.0, TAU, 24, POOF_COLOR, Shell.WORLD_PIXEL)
	for s in _players:
		_draw_cursor(ci, _players[s])
	ci.draw_rect(Rect2(0, 0, size.x, BAR_H), UiTheme.BG)


func _game_draw() -> void:
	for p in _pops:   # The points of a hit mole float up with it.
		if p.age >= 0.0:
			Shell.text_centered(self, p.pos + Vector2(0.0, -110.0 - p.age * 40.0), p.text, 64 if p.golden else 48,
					UiTheme.ACCENT if p.golden else p.color)
	_draw_hud()


func _mole_texture(golden: bool, happy: bool) -> ImageTexture:
	var key := "%s|%s" % [golden, happy]
	if not _tex.has(key):
		_tex[key] = ImageTexture.create_from_image(MoleLook.mole_image(golden, happy))
	return _tex[key]


## A mole in its hole at `c`: the top of the picture rises out of the hole, and the part that is still inside is not drawn
## (REQ-WM-6, 10). A hit mole has happy eyes.
func _draw_mole(ci: CanvasItem, m: MoleField.Mole, c: Vector2, k: float) -> void:
	var tex := _mole_texture(m.golden, m.is_hit())
	var rows := roundi(m.out() * float(tex.get_height()))
	if rows <= 0:
		return
	var px := Shell.WORLD_PIXEL * k
	var w := float(tex.get_width()) * px
	var dest := Rect2(Shell.snap(Vector2(c.x - w * 0.5, c.y - float(rows) * px)), Vector2(w, float(rows) * px))
	ci.draw_texture_rect_region(tex, dest, Rect2(0, 0, tex.get_width(), rows), Color.WHITE)


## The sparkles around a hit mole (REQ-WM-11): squares of one or two world pixels in a ring that turns in 4 steps.
func _draw_sparkles(ci: CanvasItem, m: MoleField.Mole, center: Vector2) -> void:
	var px := Shell.WORLD_PIXEL
	var t := clampf(m.hit_age / MoleField.HIT_LIFE, 0.0, 1.0)
	var count := 10 if m.golden else 6
	for i in count:
		var a := float(i) / float(count) * TAU + floorf(t * 8.0) * 0.4
		var pos := Shell.snap(center + Vector2(cos(a), sin(a) * 0.8) * (100.0 + 14.0 * float(i % 3)))
		var color := SPARKLE_WHITE if i % 2 == 0 else (UiTheme.ACCENT if m.golden else POOF_COLOR)
		ci.draw_rect(Rect2(pos - Vector2(px, 0.0), Vector2(3.0 * px, px)), color)
		ci.draw_rect(Rect2(pos - Vector2(0.0, px), Vector2(px, 3.0 * px)), color)


func _draw_cursor(ci: CanvasItem, t: Player) -> void:
	var c := Shell.snap(t.aim)   # A plain ring in the color of the player, with a dark edge so it shows on the green.
	ci.draw_arc(c, CURSOR_R, 0.0, TAU, 48, UiTheme.OUTLINE, Shell.WORLD_PIXEL * 4.0)
	ci.draw_arc(c, CURSOR_R, 0.0, TAU, 48, player(t.slot).color, Shell.WORLD_PIXEL * 2.0)


func _scoreboard() -> Scoreboard:
	return _board


func _draw_hud() -> void:
	Shell.title(self, "registry.whack_a_mole")
	draw_leader_chip(self)
	if _round.is_playing() and not is_over:
		Shell.timer(self, Vector2(TIMER_X, 36.0), _round.remaining(), TIMER_W)
	if _round.is_counting() and not participants.is_empty():
		Shell.countdown(self, size, str(_round.count_number()), _round.count_elapsed())
	if _round.time < HINT_TIME and not is_over:   # In the countdown the time is below 0.
		Shell.hint(self, size, "whack_a_mole.point_at_tv_press")
