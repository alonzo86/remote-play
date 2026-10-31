extends "res://scripts/game/minigame.gd"
## Bumper Cars. Each phone tilts a bumper car in a fun-fair rink. Gold stars lie on the floor: a car that drives over one picks it
## up. When two cars bump hard it is a bonk with a spark and a buzz; nobody loses a star, nobody is out and nobody waits
## (REQ-GM-83). The most stars after 60 seconds win (REQ-BC-1 to 20). The game needs 2 players or more and is for
## children too (REQ-GM-80 to 84). The pad is empty (REQ-GM-37a): every phone recenters at GO (REQ-BC-2), and there is
## no RECENTER, A or B. The rules of the rink are in bumper_rink.gd, the pictures in bumper_look.gd and the movement of a
## car is `TiltBody` (scripts/game/tilt_body.gd).

const TiltBody = preload("res://scripts/game/tilt_body.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")
const BumperRink = preload("res://scripts/game/bumper_cars/bumper_rink.gd")
const BumperLook = preload("res://scripts/game/bumper_cars/bumper_look.gd")

const COUNTDOWN := 3.0
const ROUND_TIME := 60.0
const GO_BUZZ_MS := 60
const HIT_BUZZ_MS := 25
const STAR_BUZZ_MS := 15
const WIN_BUZZ_MS := 400
const BUZZ_GAP_MS := 150
const HINT_TIME := 5.0
const HIT_SHOW_TIME := 0.25
const TIMER_X := Shell.TIMER_X
const TIMER_W := Shell.TIMER_W
const TITLE_X := 60.0          # The title starts at the 60 px margin.
const TITLE_FONT := 32
const TITLE_GAP := 8.0         # The title stays this far from the timer box.

## Set before the game starts (REQ-GM-93). `start_props` keeps it, and the seed, for Restart.
var difficulty := "medium"

var rink := BumperRink.new()
var _board: Scoreboard
var _round: RoundClock
var _rng := RandomNumberGenerator.new()
var _haptics := Haptics.new()
var _bodies := {}                   # slot -> TiltBody
var _facing := {}                   # slot -> BumperLook.DIR_*: the way a car looks.
var _pair_wait := {}                # "a_b" -> seconds before the pair can hit again (REQ-BC-7).
var _hits: Array[Dictionary] = []   # {pos, age}: the sparks of the hits.
var _textures := {}                 # key -> ImageTexture
var _time := 0.0                    # Seconds since the start: the sparks of the poles flicker with it.


func _game_ready() -> void:
	rink.setup(difficulty)
	_round = RoundClock.new(COUNTDOWN, ROUND_TIME)
	if start_props.has("seed"):
		_rng.seed = int(start_props.seed)   # A test fixes the stars. Restart keeps the seed.
	else:
		_rng.randomize()
	_board = Scoreboard.new(participants)
	var spots := rink.start_spots(participants.size())
	var at: Array = []
	for i in participants.size():
		var b: TiltBody = TiltBody.new()
		b.radius = BumperRink.CAR_R
		b.bounce = BumperRink.RAIL_BOUNCE
		b.pos = spots[i]
		_bodies[participants[i]] = b
		_facing[participants[i]] = BumperLook.DIR_RIGHT
		at.append(b.pos)
	rink.fill(at, _rng)


func _on_player_left(slot: int) -> void:
	_bodies.erase(slot)
	_facing.erase(slot)
	_board.remove(slot)


## REQ-BC-11: with one player left the match is over.
func _on_participants_changed() -> void:
	if not is_over and participants.size() == 1:
		_finish()


func _game_tick(delta: float) -> void:
	_time += delta
	_tick_effects(delta)
	if is_over:
		return
	if _round.is_counting():
		if _round.tick(delta):
			for s in _bodies:
				player(s).recenter()   # The pose held in the countdown is the center (REQ-BC-2).
				game_host.haptic(s, GO_BUZZ_MS)
		return
	_round.tick(delta)
	for s in _bodies:
		var b: TiltBody = _bodies[s]
		b.step(delta, player(s).tilt(), rink.car_bounds())
		_facing[s] = BumperLook.facing(b.vel, int(_facing.get(s, BumperLook.DIR_RIGHT)))
	_bump_cars()
	rink.tick(delta, _car_spots(), _rng)
	_pick_up()
	if _round.is_time_up():
		_finish()


func _tick_effects(delta: float) -> void:
	for k in _pair_wait.keys():
		_pair_wait[k] = float(_pair_wait[k]) - delta
		if float(_pair_wait[k]) <= 0.0:
			_pair_wait.erase(k)
	for h in _hits:
		h.age += delta
	_hits.assign(_hits.filter(func(h: Dictionary) -> bool: return float(h.age) < HIT_SHOW_TIME))


func _car_spots() -> Array:
	var out: Array = []
	for s in _bodies:
		out.append((_bodies[s] as TiltBody).pos)
	return out


## REQ-BC-5 to 7: cars bounce off each other. A fast bump is a hit: a spark, a bonk and a buzz; nobody loses a star (REQ-BC-7).
func _bump_cars() -> void:
	var slots: Array = _bodies.keys()
	for i in slots.size():
		for j in range(i + 1, slots.size()):
			var a: TiltBody = _bodies[slots[i]]
			var b: TiltBody = _bodies[slots[j]]
			if not BumperRink.touching(a.pos, b.pos):
				continue
			var hit := BumperRink.is_hit(a.pos, a.vel, b.pos, b.vel)   # Before the bounce changes the speeds.
			TiltBody.collide(a, b, BumperRink.RESTITUTION)
			var key := "%d_%d" % [mini(slots[i], slots[j]), maxi(slots[i], slots[j])]
			if not hit or _pair_wait.has(key):
				continue
			_pair_wait[key] = BumperRink.HIT_GAP
			_on_hit(int(slots[i]), int(slots[j]))


func _on_hit(sa: int, sb: int) -> void:
	var a: TiltBody = _bodies[sa]
	var b: TiltBody = _bodies[sb]
	_hits.append({"pos": (a.pos + b.pos) * 0.5, "age": 0.0})
	_haptics.pulse(sa, HIT_BUZZ_MS, BUZZ_GAP_MS)
	_haptics.pulse(sb, HIT_BUZZ_MS, BUZZ_GAP_MS)
	Sound.sfx("car_bump")


## REQ-BC-10: a car picks up the stars it reaches.
func _pick_up() -> void:
	var slots: Array = _bodies.keys()
	var spots := _car_spots()
	var taken: Array = []
	for p in rink.pickups(spots):
		var slot: int = slots[int(p[0])]
		_board.add(slot, 1.0)
		_haptics.pulse(slot, STAR_BUZZ_MS, BUZZ_GAP_MS)
		taken.append(int(p[1]))
	if not taken.is_empty():
		Sound.sfx("car_star")
		rink.remove_stars(taken)


## REQ-BC-12: the round is over. The most stars win.
func _finish() -> void:
	for s in _board.winners():
		game_host.haptic(s, WIN_BUZZ_MS)
	open_results(_board, "", [], _stars_text)


## "3 stars" for the result list.
func _stars_text(stars: float) -> String:
	return Lang.t("result.one_star") if int(stars) == 1 else Lang.f("result.stars", [int(stars)])


func _scoreboard() -> Scoreboard:
	return _board


# ---- Drawing ----

func _pixel_world() -> bool:
	return true


func _texture(kind: String, color := Color.WHITE, dir := 0) -> ImageTexture:
	var key := "%s|%s|%d" % [kind, color.to_html(), dir]
	if not _textures.has(key):
		var img: Image
		match kind:
			"star":
				img = BumperLook.star_image()
			"shadow":
				img = BumperLook.shadow_image(BumperLook.car_image(color, dir))
			_:
				img = BumperLook.car_image(color, dir)
		_textures[key] = ImageTexture.create_from_image(img)
	return _textures[key]


func _draw_centered(ci: CanvasItem, tex: ImageTexture, center: Vector2) -> void:
	var sz := Vector2(tex.get_size()) * Shell.WORLD_PIXEL
	ci.draw_texture_rect(tex, Rect2(Shell.snap(center - sz * 0.5), sz), false)


func _world_draw(ci: CanvasItem) -> void:
	var design := Vector2(DESIGN_SIZE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, size / design if size.x > 0.0 and size.y > 0.0 else Vector2.ONE)
	BumperLook.draw_backdrop(ci, design)
	BumperLook.draw_tent(ci, design.x)
	BumperLook.draw_rink(ci, rink.rink)
	for i in rink.stars.size():
		var s: Dictionary = rink.stars[i]
		if float(s.blink) > 0.0 and int(float(s.blink) * 10.0) % 2 == 0:
			continue   # A new star blinks.
		var bob := -Shell.WORLD_PIXEL if (int(_time * 2.0) + i) % 2 == 0 else 0.0
		_draw_centered(ci, _texture("star"), (s.pos as Vector2) + Vector2(0.0, bob))
	var slots: Array = _bodies.keys()
	slots.sort_custom(func(a: int, b: int) -> bool: return (_bodies[a] as TiltBody).pos.y < (_bodies[b] as TiltBody).pos.y)
	for s in slots:
		_draw_car(ci, int(s))
	for h in _hits:
		BumperLook.draw_hit(ci, h.pos, float(h.age))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_car(ci: CanvasItem, slot: int) -> void:
	var b: TiltBody = _bodies[slot]
	var dir: int = int(_facing.get(slot, BumperLook.DIR_RIGHT))
	var color := player(slot).color
	_draw_centered(ci, _texture("shadow", color, dir), b.pos + BumperLook.SHADOW_OFFSET * Shell.WORLD_PIXEL)
	_draw_centered(ci, _texture("car", color, dir), b.pos)
	BumperLook.draw_spark(ci, b.pos + BumperLook.pole_offset(dir) * Shell.WORLD_PIXEL, _time, slot)


## The room of the title (REQ-BC-16): up to the timer box, which stands at TIMER_X from the left edge, or from the right edge in
## Hebrew, so the room is the same in both. A longer name (the Hebrew one) goes on two lines at 32 px (`Shell.title_wrapped()`).
func title_room() -> float:
	return TIMER_X - TITLE_X - TITLE_GAP


func _game_draw() -> void:
	Shell.title_wrapped(self, "registry.bumper_cars", title_room(), Vector2(TITLE_X, 96.0), TITLE_FONT)
	draw_leader_chip(self)
	Shell.timed_hud(self, size, _round, is_over, not participants.is_empty(), "bumper_cars.hint", HINT_TIME)
