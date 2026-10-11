extends "res://scripts/game/minigame.gd"
## Sumo Bumpers. Each phone tilts a friendly bumper on a round platform that shrinks. Bumpers bounce off each other, A dashes.
## A bumper that rolls over the edge falls ("Whee!") and waits for the next round. The last one on the platform gets a point.
## A match has 3 rounds; the most points win (REQ-SB-1 to 20). The game is for children too (REQ-GM-80 to 84).
## RECENTER recenters (REQ-GM-37). The rules of the platform are in sumo_arena.gd, the movement is `TiltBody` (tilt_body.gd).

const SumoArena = preload("res://scripts/game/sumo_bumpers/sumo_arena.gd")
const TiltBody = preload("res://scripts/game/tilt_body.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const ROUNDS := 3
const COUNTDOWN := 3.0
const BANNER_TIME := 2.5
const DASH_BOOST_TIME := 0.35   # While a dash is fresh the speed limit is the dash speed, so the dash is not cut at once.
const FALL_TIME := 0.8          # A fallen bumper spins and shrinks in this time (REQ-SB-9).
const BUZZ_GAP_MS := 150
const HINT_TIME := 5.0
const SIM_AREA := Vector2(1800.0, 890.0)   # The simulation area: the platform fits in it at every difficulty.
const AREA_TOP := 150.0
const AREA_MARGIN := 60.0
const TIMER_X := 560.0
const TIMER_W := 160.0
const FAR := 1.0e6
const UNBOUNDED := Rect2(Vector2(-FAR, -FAR), Vector2(2.0 * FAR, 2.0 * FAR))   # No walls: the edge makes them fall.

# Look (REQ-SB-15, REQ-GM-47). The world palette is black, dark gray and blue stars, a dark purple platform (so that every player
# color has a contrast of 3:1 or more) with a light edge ring that gets red when the platform is small.
const BACKGROUND := UiTheme.BG
const STAR_COUNT := 48
const PLATFORM := Color("2a1070")
const PLATFORM_RING := Color("8c78e6")
const DANGER_COLOR := Color("ff5a4d")

enum Phase { COUNT, PLAY, BANNER }

## Set before the game starts (REQ-GM-93). `start_props` keeps it for Restart.
var difficulty := "medium"

var arena := SumoArena.new()
var round_no := 1
var phase := Phase.COUNT
var banner_text := ""

var _board: Scoreboard
var _bodies := {}               # slot -> TiltBody (all participants, also the ones that fell)
var _alive: Array[int] = []
var _falling := {}              # slot -> {pos, age}
var _dash_left := {}            # slot -> seconds until the dash is ready
var _boost_left := {}           # slot -> seconds that the dash speed limit lasts
var _normal_speed := TiltBody.new().max_speed   # The speed limit without a dash.
var _dashes: Array[int] = []    # The slots of the presses of A, kept until the next tick.
var _fell: Array[int] = []      # The slots that fell in this tick (one array for all ticks: nothing is made in each frame).
var _clock := RoundClock.new(COUNTDOWN, 0.0)
var _banner_left := 0.0
var _haptics := Haptics.new()
var _stars := PackedVector2Array()   # The star pixels of the background, on the world pixel grid.


func _game_ready() -> void:
	arena.setup(difficulty)
	_board = Scoreboard.new(participants)
	_stars = Shell.star_field(STAR_COUNT, 7)   # The same sky every time.
	for s in participants:
		var b: TiltBody = TiltBody.new()
		b.radius = SumoArena.BUMPER_R
		_bodies[s] = b
		player(s).button_pressed.connect(_on_button.bind(s))
	_start_round()


func _exit_tree() -> void:
	for s in _bodies:
		var cb := _on_button.bind(s)
		if player(s).button_pressed.is_connected(cb):
			player(s).button_pressed.disconnect(cb)


## A new round: the platform is full again and all bumpers are back at their start places (REQ-SB-2).
func _start_round() -> void:
	arena.setup(difficulty)
	phase = Phase.COUNT
	_clock = RoundClock.new(COUNTDOWN, 0.0)
	_falling.clear()
	_dashes.clear()
	_alive.clear()
	var spots := arena.start_spots(participants.size())
	for i in participants.size():
		var s: int = participants[i]
		var b: TiltBody = _bodies[s]
		b.pos = spots[i]
		b.vel = Vector2.ZERO
		_alive.append(s)
		_dash_left[s] = 0.0
		_boost_left[s] = 0.0
		b.max_speed = _normal_speed


## REQ-SB-10: a press on A is a dash. It is kept until the next tick.
func _on_button(bit: int, slot: int) -> void:
	if bit != Protocol.BTN_A or is_paused() or is_over or phase != Phase.PLAY:
		return
	_dashes.append(slot)


func _on_player_left(slot: int) -> void:
	_bodies.erase(slot)
	_alive.erase(slot)
	_falling.erase(slot)
	_dash_left.erase(slot)
	_boost_left.erase(slot)
	_board.remove(slot)
	_dashes = _dashes.filter(func(s: int) -> bool: return s != slot)


## REQ-SB-12: with one player left the match is over.
func _on_participants_changed() -> void:
	if not is_over and participants.size() == 1:
		_finish()


func _game_tick(delta: float) -> void:
	if is_over:
		return
	_tick_falls(delta)
	match phase:
		Phase.COUNT:
			if _clock.tick(delta):
				phase = Phase.PLAY
				for s in participants:
					player(s).recenter()   # The pose held in the countdown is the center.
					App.server.haptic(s, 60)
		Phase.PLAY:
			_tick_play(delta)
		Phase.BANNER:
			_banner_left -= delta
			if _banner_left <= 0.0:
				if round_no >= ROUNDS:
					_finish()
				else:
					round_no += 1
					_start_round()


func _tick_play(delta: float) -> void:
	arena.tick(delta)
	for s in _dash_left:
		_dash_left[s] = maxf(float(_dash_left[s]) - delta, 0.0)
		_boost_left[s] = maxf(float(_boost_left[s]) - delta, 0.0)
		(_bodies[s] as TiltBody).max_speed = SumoArena.DASH_SPEED if float(_boost_left[s]) > 0.0 else _normal_speed
	for s in _dashes:
		_dash(s)
	_dashes.clear()
	for s in _alive:
		(_bodies[s] as TiltBody).step(delta, player(s).tilt(), UNBOUNDED)
	for i in _alive.size():
		for j in range(i + 1, _alive.size()):
			_bump(_alive[i], _alive[j])
	_fell.clear()
	for s in _alive:
		if arena.is_off((_bodies[s] as TiltBody).pos):
			_fell.append(s)
	if not _fell.is_empty():
		arena.speed_up()   # REQ-SB-6: the wait of a fallen bumper stays short (REQ-GM-83).
	for s in _fell:
		_alive.erase(s)
		_falling[s] = {"pos": (_bodies[s] as TiltBody).pos, "age": 0.0}
		_haptics.pulse(s, 80, BUZZ_GAP_MS)   # REQ-SB-11
		Sound.sfx("sumo_fall")
	if _alive.size() <= 1:
		_end_round(_fell)


## REQ-SB-10: a dash in the direction of the tilt, when it is ready.
func _dash(slot: int) -> void:
	if not _alive.has(slot) or float(_dash_left[slot]) > 0.0:
		return
	var b: TiltBody = _bodies[slot]
	var v := SumoArena.dash_velocity(player(slot).tilt(), b.vel, b.deadzone)
	if v == Vector2.ZERO:
		return
	b.vel = v
	b.max_speed = SumoArena.DASH_SPEED
	_boost_left[slot] = DASH_BOOST_TIME
	_dash_left[slot] = arena.dash_time
	_haptics.pulse(slot, 30, BUZZ_GAP_MS)
	Sound.sfx("sumo_dash")


## REQ-SB-8: two bumpers bounce off each other. A fast hit buzzes both phones.
func _bump(a: int, b: int) -> void:
	var ba: TiltBody = _bodies[a]
	var bb: TiltBody = _bodies[b]
	var speed := (bb.vel - ba.vel).length()
	if TiltBody.collide(ba, bb, SumoArena.BUMP_RESTITUTION) and speed > SumoArena.BUMP_BUZZ_SPEED:
		_haptics.pulse(a, 20, BUZZ_GAP_MS)
		_haptics.pulse(b, 20, BUZZ_GAP_MS)
		Sound.sfx("sumo_bump")


## REQ-SB-3, 4: the round is over. The last bumper (or all that fell last) gets the point.
func _end_round(fell_last: Array) -> void:
	var winners := SumoArena.round_winners(_alive, fell_last)
	for s in winners:
		_board.add(s, 1.0)
		App.server.haptic(s, 120)
	if not winners.is_empty():
		Sound.sfx("sumo_round_win")
	if winners.size() == 1:
		banner_text = Lang.f("%s wins the round!", [player(winners[0]).player_name])
	else:
		banner_text = Lang.t("Round draw!")
	phase = Phase.BANNER
	_banner_left = BANNER_TIME


func _tick_falls(delta: float) -> void:
	for s in _falling:
		_falling[s].age += delta


func _finish() -> void:
	for s in _board.winners():
		App.server.haptic(s, 400)
	open_results(_board, [], "", [], _points_text)


## "2 points" for the result list.
func _points_text(points: float) -> String:
	return Lang.t("1 point") if int(points) == 1 else Lang.f("%d points", [int(points)])


# ---- Drawing ----

## The world is drawn in the low-resolution view (REQ-GM-47a); the HUD, the slot numbers and "Whee!" are at full resolution.
func _pixel_world() -> bool:
	return true


## The scale and the middle of the platform on the screen.
func _fit() -> Dictionary:
	var avail := Vector2(size.x - 2.0 * AREA_MARGIN, size.y - AREA_TOP - AREA_MARGIN)
	return {"k": minf(avail.x / SIM_AREA.x, avail.y / SIM_AREA.y),
			"center": Vector2(AREA_MARGIN + avail.x * 0.5, AREA_TOP + avail.y * 0.5)}


func _world_draw(ci: CanvasItem) -> void:
	var fit := _fit()
	var k: float = fit.k
	var c: Vector2 = fit.center
	ci.draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	Shell.draw_stars(ci, _stars)
	_draw_platform(ci, c, k)
	for s in _falling:
		_draw_fall(ci, s, c, k)
	for s in _alive:
		_draw_bumper(ci, s, c, k)


func _draw_platform(ci: CanvasItem, c: Vector2, k: float) -> void:
	var r := arena.radius() * k
	ci.draw_circle(c, r + Shell.WORLD_PIXEL, UiTheme.OUTLINE)
	ci.draw_circle(c, r, PLATFORM)
	for f in [0.66, 0.33]:   # Rings on the platform, one world pixel wide.
		ci.draw_arc(c, r * f, 0.0, TAU, 48, Color(PLATFORM_RING, 0.25), Shell.WORLD_PIXEL)
	# The ring gets red when the platform is small.
	var ring := danger_ring(arena.danger())
	ci.draw_arc(c, r - Shell.WORLD_PIXEL * 2.0, 0.0, TAU, 96, ring, Shell.WORLD_PIXEL * 3.0)


## The color of the platform ring for a danger level (0 full platform, 1 smallest): it turns red when the platform is small.
static func danger_ring(danger: float) -> Color:
	return PLATFORM_RING.lerp(DANGER_COLOR, clampf(danger * 1.6 - 0.3, 0.0, 1.0))


func _draw_bumper(ci: CanvasItem, slot: int, c: Vector2, k: float) -> void:
	var b: TiltBody = _bodies[slot]
	var center := c + b.pos * k
	var radius := SumoArena.BUMPER_R * k
	Shell.pixel_ball(ci, center, radius, player(slot).color)
	Shell.pixel_eyes(ci, center, radius, b.vel / b.max_speed)   # The pupils step to the side the bumper rolls.
	var left: float = _dash_left.get(slot, 0.0)   # A ring: complete when the dash is ready.
	var share := 1.0 - clampf(left / arena.dash_time, 0.0, 1.0)
	var ring_color := Color.WHITE if share >= 1.0 else Color(1, 1, 1, 0.5)
	ci.draw_arc(center, radius + Shell.WORLD_PIXEL * 4.0, -PI * 0.5, -PI * 0.5 + TAU * share, 32, ring_color, Shell.WORLD_PIXEL)


## The size of a fallen bumper after `age` seconds: it shrinks in 4 steps (REQ-SB-9). 0 when the fall is over.
static func fall_scale(age: float) -> float:
	var t := clampf(age / FALL_TIME, 0.0, 1.0)
	return 0.0 if t >= 1.0 else ceilf((1.0 - t) * 4.0) / 4.0


## A fallen bumper gets smaller in steps (REQ-SB-9). "Whee!" is drawn by the HUD.
func _draw_fall(ci: CanvasItem, slot: int, c: Vector2, k: float) -> void:
	var f: Dictionary = _falling[slot]
	var s := fall_scale(float(f.age))
	if s == 0.0 or not _bodies.has(slot):
		return
	Shell.pixel_ball(ci, c + (f.pos as Vector2) * k, SumoArena.BUMPER_R * k * s, player(slot).color)


func _game_draw() -> void:
	var fit := _fit()
	var k: float = fit.k
	var c: Vector2 = fit.center
	for s in _alive:   # The slot numbers: full resolution, on top of the pixel ball.
		var p := Shell.snap(c + (_bodies[s] as TiltBody).pos * k)
		Shell.ball_number(self, p, SumoArena.BUMPER_R * k, player(s).color, s, Shell.NUMBER_DROP, player(s).avatar)
	for s in _falling:
		var f: Dictionary = _falling[s]
		if fall_scale(float(f.age)) > 0.0 and _bodies.has(s):
			var above := Vector2(0.0, -SumoArena.BUMPER_R * k * 1.6 - clampf(float(f.age) / FALL_TIME, 0.0, 1.0) * 30.0)
			Shell.text_centered(self, c + (f.pos as Vector2) * k + above, Lang.t("Whee!"), 32, UiTheme.TEXT)
	_draw_hud()


func _scoreboard() -> Scoreboard:
	return _board


func _draw_hud() -> void:
	Shell.title(self, "SUMO BUMPERS")
	draw_leader_chip(self)
	if not is_over:
		Shell.text(self, Vector2(Shell.mx(self, TIMER_X, TIMER_W + 80.0), 84.0), Lang.f("Round %d of %d", [round_no, ROUNDS]), 32,
				UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, TIMER_W + 80.0)
	if phase == Phase.COUNT and not participants.is_empty():
		var n := _clock.count_number()
		Shell.countdown(self, size, str(n) if n > 0 else "GO", _clock.count_elapsed())
		var fit := _fit()
		var spots := {}
		for s in _bodies:
			spots[s] = Shell.snap(fit.center + (_bodies[s] as TiltBody).pos * float(fit.k))
		draw_name_tags(self, spots, SumoArena.BUMPER_R * float(fit.k))
	if phase == Phase.BANNER and not is_over:
		Shell.text(self, Vector2(0.0, size.y * 0.5 - 20.0), banner_text, 72, UiTheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if round_no == 1 and arena.time < HINT_TIME and phase != Phase.BANNER and not is_over:
		Shell.hint(self, size, "Tilt to bump the others off the platform! A dashes.")
