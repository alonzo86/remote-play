extends "res://scripts/game/minigame.gd"
## Sheep Herding. A team game for 1 to 4 phones: each phone tilts a friendly sheepdog, and together the dogs herd the sheep
## into the pen through its gate (REQ-SH-1 to 20). The sheep keep away from a dog that comes close; nobody is hurt, a sheep in
## the pen stays there. The round ends when every sheep is in or when the time is up; the score is the number of sheep in the
## pen and it belongs to the whole team. Nobody is out and nobody waits (REQ-SH-9, REQ-GM-83). The RECENTER button recenters
## (REQ-GM-37); A and B do nothing. The rules of the sheep are in sheep_flock.gd, the things around the field in sheep_scenery.gd,
## the pictures in sheep_look.gd and the movement of a dog is `TiltBody` (scripts/game/tilt_body.gd).

const TiltBody = preload("res://scripts/game/tilt_body.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")
const SheepFlock = preload("res://scripts/game/sheep_herding/sheep_flock.gd")
const SheepScenery = preload("res://scripts/game/sheep_herding/sheep_scenery.gd")
const SheepLook = preload("res://scripts/game/sheep_herding/sheep_look.gd")

const COUNTDOWN := 3.0
const DOG_R := 30.0
const DOG_SPEED := 440.0          # px/s, a little below the blob of Paint Grab, so that a child can steer it.
const GO_BUZZ_MS := 60
const PEN_BUZZ_MS := 40           # The dog that last scared a sheep feels it when the sheep walks in (REQ-SH-12).
const BUZZ_GAP_MS := 150
const BAA_GAP := 0.6              # The least time between two "baa" sounds, so a scared flock does not shout.
const GLOW_TIME := 0.5            # The fence is yellow for this long after a sheep came in.
const STAR_TIME := 0.4
const END_DELAY := 1.6            # The confetti of a full pen, before the result menu.
const HINT_TIME := 4.0
const FIELD_TOP := 152.0          # The grass is the screen inside the margin, under the HUD.
const FIELD_MARGIN := 60.0
const TIMER_X := Shell.TIMER_X
const TIMER_W := 208.0
const CHIP_W := 280.0
const CONFETTI_COUNT := 70
## Difficulty (REQ-SH-17): the number of sheep, how far a dog scares a sheep, how fast a scared sheep
## runs, the gate, the time of the
## round. First guesses (Test 26). The number of dogs changes nothing.
const LEVELS := {
	"easy": {"sheep": 8, "flee": 220.0, "speed": 230.0, "gate": 220.0, "time": 90.0},
	"medium": {"sheep": 11, "flee": 260.0, "speed": 270.0, "gate": 180.0, "time": 75.0},
	"hard": {"sheep": 14, "flee": 300.0, "speed": 320.0, "gate": 150.0, "time": 60.0},
}
## Where the dogs start (the share of the height of the field, on the left edge), for 1 to 4 dogs.
const START_Y := [[0.5], [0.3, 0.7], [0.2, 0.5, 0.8], [0.15, 0.38, 0.62, 0.85]]
const START_X := 120.0

## Set before the game starts (REQ-GM-93). `start_props` keeps it, and the seed, for Restart.
var difficulty := "medium"

var field := Rect2()
var pen := Rect2()
var barn_origin := Vector2.ZERO
var flock: SheepFlock
var scenery: SheepScenery
var dogs := {}                      # slot -> TiltBody
var _board: Scoreboard
var _round: RoundClock
var _level := {}
var _rng := RandomNumberGenerator.new()
var _haptics := Haptics.new()
var _touching := {}                 # Pairs of dogs that touch now (one sound for one touch).
var _baa_wait := 0.0
var _glow := 0.0
var _stars: Array[Dictionary] = []  # {pos, age}: the stars where a sheep came in.
var _end_left := -1.0               # The time left of the confetti, or -1 while the round runs.
var _confetti: Array[Dictionary] = []   # {pos, vel, color}
var _faces := {}                    # slot -> -1 or 1: the way a dog looks (the last way it moved sideways).
var _tufts: Array[Vector2] = []
var _textures := {}
var _scenery_order: Array[Dictionary] = []   # The things of the scenery from the back to the front.


func _game_ready() -> void:
	_level = LEVELS.get(difficulty, LEVELS.medium)
	_round = RoundClock.new(COUNTDOWN, float(_level.time))
	if start_props.has("seed"):
		_rng.seed = int(start_props.seed)   # A test fixes the field and the flock. Restart keeps the seed.
	else:
		_rng.randomize()
	_layout()
	flock = SheepFlock.new()
	scenery = SheepScenery.new()
	var spawn := Rect2(field.position + Vector2(380.0, 160.0), Vector2(560.0, field.size.y - 320.0))
	var gate_y := pen.position.y + pen.size.y * 0.5
	var corridor := Rect2(spawn.position.x, gate_y - 150.0, pen.position.x - spawn.position.x, 300.0)
	var start_strip := Rect2(field.position, Vector2(280.0, field.size.y))
	var free: Array[Rect2] = [start_strip, spawn, corridor, pen.grow(120.0)]
	var clear: Array[Rect2] = [pen.grow(40.0), _barn_box()]
	scenery.generate(field, free, clear, _rng)
	flock.setup(field, pen, _level, scenery.blockers, SheepLook.barn_blocks(barn_origin))
	flock.spawn(int(_level.sheep), spawn, _rng)
	for i in 160:
		_tufts.append(Shell.snap(Vector2(_rng.randf_range(field.position.x, field.end.x - 8.0),
				_rng.randf_range(field.position.y, field.end.y - 4.0))))
	_scenery_order.assign(scenery.items)
	_scenery_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y)
	_board = Scoreboard.new(participants)
	var rows: Array = START_Y[clampi(participants.size(), 1, START_Y.size()) - 1]
	for i in participants.size():
		var b: TiltBody = TiltBody.new()
		b.radius = DOG_R
		b.max_speed = DOG_SPEED
		b.pos = Vector2(field.position.x + START_X, field.position.y + field.size.y * float(rows[i % rows.size()]))
		dogs[participants[i]] = b
		_faces[participants[i]] = 1


## The grass fits inside the margin and under the HUD, on the grid of world pixels. The pen is at the right, the barn above it.
func _layout() -> void:
	var design := Vector2(DESIGN_SIZE)   # The world is simulated in these units, and scaled to `size` when it is drawn.
	field = Rect2(Vector2(FIELD_MARGIN, FIELD_TOP), Vector2(design.x - 2.0 * FIELD_MARGIN, design.y - FIELD_TOP - FIELD_MARGIN))
	field.size = (field.size / Shell.WORLD_PIXEL).floor() * Shell.WORLD_PIXEL
	pen = Rect2(Vector2(field.end.x - 372.0, field.position.y + 300.0), Vector2(320.0, 360.0))
	barn_origin = Vector2(pen.position.x + 48.0, pen.position.y - 32.0 - SheepLook.BARN_SIZE.y * Shell.WORLD_PIXEL)


## The box around the barn, the silo and the vane, where nothing else stands.
func _barn_box() -> Rect2:
	var w := Shell.WORLD_PIXEL
	return Rect2(barn_origin + Vector2(-16.0, -14.0) * w, Vector2(76.0, 62.0) * w)


func _on_player_left(slot: int) -> void:
	dogs.erase(slot)
	_board.remove(slot)


func _game_tick(delta: float) -> void:
	_tick_effects(delta)
	if is_over:
		return
	if _round.is_counting():
		if _round.tick(delta):
			for s in dogs:
				player(s).recenter()   # The pose held in the countdown is the center.
				App.server.haptic(s, GO_BUZZ_MS)
		return
	if _end_left < 0.0:
		_round.tick(delta)
	_tick_dogs(delta)
	flock.tick(delta, _dog_spots(), _rng)
	for e in flock.events:
		_on_flock_event(e)
	var n := flock.penned_count()
	for s in dogs:
		_board.set_score(s, n)
	if _end_left >= 0.0:
		_end_left -= delta
		if _end_left <= 0.0:
			_finish()
	elif flock.all_penned():
		_end_left = END_DELAY   # The sheep are all in: a moment of confetti, then the result.
		_start_confetti()
	elif _round.is_time_up():
		_finish()


func _tick_dogs(delta: float) -> void:
	for s in dogs:
		var b: TiltBody = dogs[s]
		b.step(delta, player(s).tilt(), field)
		var fixed := flock.resolve(b.pos, b.vel, b.radius)   # A dog walks around the pond, the trees and the fence.
		b.pos = fixed[0]
		b.vel = fixed[1]
		if absf(b.vel.x) > 20.0:
			_faces[s] = 1 if b.vel.x > 0.0 else -1
	var slots: Array = dogs.keys()
	for i in slots.size():
		for j in range(i + 1, slots.size()):
			var pair: int = int(slots[i]) * 4 + int(slots[j])
			if TiltBody.collide(dogs[slots[i]], dogs[slots[j]]):
				if not _touching.has(pair):
					_touching[pair] = true
					Sound.sfx("sheep_bump")   # One soft sound for one touch.
			else:
				_touching.erase(pair)


func _dog_spots() -> Dictionary:
	var spots := {}
	for s in dogs:
		spots[s] = dogs[s].pos
	return spots


## The sounds and the buzzes of what the sheep did (REQ-SH-12).
func _on_flock_event(e: Dictionary) -> void:
	if String(e.t) == "startled":
		if _baa_wait <= 0.0:
			Sound.sfx("sheep_baa")
			_baa_wait = BAA_GAP
	elif String(e.t) == "penned":
		_glow = GLOW_TIME
		_stars.append({"pos": e.pos, "age": 0.0})
		Sound.sfx("sheep_pen")
		if dogs.has(int(e.slot)):
			_haptics.pulse(int(e.slot), PEN_BUZZ_MS, BUZZ_GAP_MS)   # REQ-GM-43


func _tick_effects(delta: float) -> void:
	_baa_wait = maxf(_baa_wait - delta, 0.0)
	_glow = maxf(_glow - delta, 0.0)
	for st in _stars:
		st.age += delta
	_stars = _stars.filter(func(st: Dictionary) -> bool: return float(st.age) < STAR_TIME)
	for c in _confetti:
		c.vel.y += 900.0 * delta
		c.pos += c.vel * delta


func _start_confetti() -> void:
	_confetti.clear()
	for i in CONFETTI_COUNT:
		var p := Vector2(_rng.randf_range(pen.position.x, pen.end.x), _rng.randf_range(pen.position.y, pen.end.y))
		_confetti.append({"pos": p, "vel": Vector2(_rng.randf_range(-160.0, 160.0), _rng.randf_range(-520.0, -200.0)),
				"color": SheepLook.CONFETTI[i % SheepLook.CONFETTI.size()]})
	Sound.sfx("sheep_pen")


## The round is over: all the sheep are in (a win for the team, REQ-SH-5) or the time is up. One player gets the medal of the
## number of sheep (REQ-SH-18); more players get a sentence for the whole team and no medals (the score is shared).
func _finish() -> void:
	var n := flock.penned_count()
	var total := flock.sheep.size()
	var all := n >= total
	if all:
		for s in dogs:
			App.server.haptic(s, 400)
	team_won = all
	var heading := ""
	if _board.ranking().size() == 1:
		heading = Lang.t("game_settings." + difficulty)
	else:
		no_medals = true
		heading = Lang.t("sheep_herding.all_safe") if all else Lang.f("sheep_herding.some_safe", [n, total])
	open_results(_board, heading, [], _score_text)


## "6 / 9 sheep" for the result list.
func _score_text(count: float) -> String:
	return Lang.f("sheep_herding.count", [int(count), flock.sheep.size()])


func _scoreboard() -> Scoreboard:
	return _board


## One shared score: every phone shows the number of sheep in the pen and no place (REQ-SH-13, REQ-FL-67).
func _publish_scores() -> void:
	if _board == null:
		return
	var text := "%d / %d" % [flock.penned_count(), flock.sheep.size()]
	for s in dogs:
		App.server.send_score(s, 0, 0, text)


# ---- Drawing ----

func _pixel_world() -> bool:
	return true


func _texture(kind: String, color := Color.WHITE) -> ImageTexture:
	var key := "%s|%s" % [kind, color.to_html()]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(SheepLook.image(kind, color))
	return _textures[key]


## A picture with its foot (the middle of the bottom edge) at `foot`.
func _draw_standing(ci: CanvasItem, kind: String, foot: Vector2) -> void:
	var tex := _texture(kind)
	var sz := Vector2(tex.get_size()) * Shell.WORLD_PIXEL
	ci.draw_texture_rect(tex, Rect2(Shell.snap(foot - Vector2(sz.x * 0.5, sz.y)), sz), false)


## A picture with its middle at `center`, turned around when `face` is -1.
func _draw_centered(ci: CanvasItem, tex: ImageTexture, center: Vector2, face: int) -> void:
	var sz := Vector2(tex.get_size()) * Shell.WORLD_PIXEL
	var top_left := Shell.snap(center - sz * 0.5)
	if face < 0:
		ci.draw_texture_rect(tex, Rect2(top_left + Vector2(sz.x, 0.0), Vector2(-sz.x, sz.y)), false)
	else:
		ci.draw_texture_rect(tex, Rect2(top_left, sz), false)


func _world_draw(ci: CanvasItem) -> void:
	var design := Vector2(DESIGN_SIZE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, size / design if size.x > 0.0 and size.y > 0.0 else Vector2.ONE)
	ci.draw_rect(Rect2(Vector2.ZERO, design), UiTheme.BG)
	SheepLook.draw_grass(ci, field, _tufts)
	SheepLook.draw_path(ci, field.position.x + 480.0, pen.position.x - 16.0, pen.position.y + pen.size.y * 0.5)
	for f in scenery.flowers:
		SheepLook.draw_flower(ci, Shell.snap(f.pos), int(f.color))
	SheepLook.draw_barn(ci, barn_origin)
	SheepLook.draw_pen(ci, pen, flock.gate, SheepFlock.WALL, _glow > 0.0)
	for it in _scenery_order:
		if String(it.kind) == SheepScenery.POND:
			SheepLook.draw_pond(ci, it.pos, SheepScenery.POND_SIZE)
	for it in _scenery_order:
		if String(it.kind) != SheepScenery.POND:
			_draw_standing(ci, String(it.kind), it.pos)
	var order: Array = []
	for s in flock.sheep:
		order.append([s.pos.y, s, -1])
	for slot in dogs:
		order.append([dogs[slot].pos.y, dogs[slot], slot])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for o in order:
		if int(o[2]) >= 0:
			_draw_dog(ci, int(o[2]), o[1])
		else:
			_draw_sheep(ci, o[1])
	for st in _stars:
		var tex := _texture("star")
		_draw_centered(ci, tex, st.pos + Vector2(0.0, -40.0 - 40.0 * float(st.age) / STAR_TIME), 1)
	for c in _confetti:
		ci.draw_rect(Rect2(Shell.snap(c.pos), Vector2.ONE * Shell.WORLD_PIXEL * 2.0), c.color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_dog(ci: CanvasItem, slot: int, b: TiltBody) -> void:
	_draw_centered(ci, _texture("dog", player(slot).color), b.pos, int(_faces.get(slot, 1)))


## A sheep, and over it a heart or a sleepy "z" when it is calm, or speed dashes behind it when it runs (REQ-SH-16).
func _draw_sheep(ci: CanvasItem, s: SheepFlock.Sheep) -> void:
	var hop := 0.0
	if s.hop > 0.0:
		hop = -Shell.WORLD_PIXEL * 2.0 * (1.0 - absf(s.hop / SheepFlock.HOP_TIME * 2.0 - 1.0)) * 2.0   # Up and down in hard steps.
	var face := 1 if s.vel.x >= -2.0 else -1
	var center := s.pos + Vector2(0.0, hop)
	_draw_centered(ci, _texture("sheep"), center, face)
	var idx := flock.sheep.find(s)
	if s.scared > 0.0 and not s.penned:
		var back := -s.vel.normalized() if s.vel.length() > 1.0 else Vector2.LEFT
		for k in 3:
			var at := Shell.snap(center + back * (46.0 + 16.0 * float(k)) + Vector2(0.0, -8.0 + 8.0 * float(k)))
			ci.draw_rect(Rect2(at, Vector2(Shell.WORLD_PIXEL * 2.0, Shell.WORLD_PIXEL)), Color.WHITE)
	else:
		_draw_centered(ci, _texture("snooze" if idx % 2 == 1 else "heart"), center + Vector2(0.0, -52.0), 1)


func _game_draw() -> void:
	Shell.title(self, "registry.sheep_herding")
	draw_leader_chip(self)
	if _round.is_playing() and not is_over:
		Shell.timer(self, Vector2(TIMER_X, 36.0), maxf(_round.remaining(), 0.0), TIMER_W)
	if _round.is_counting() and not participants.is_empty():
		Shell.countdown(self, size, str(_round.count_number()), _round.count_elapsed())
	if _round.time < HINT_TIME and not is_over:
		Shell.hint(self, size, "sheep_herding.hint")


## The one chip of the team: the number of sheep in the pen out of all (REQ-SH-13). It has no leader: the score is shared.
func draw_leader_chip(ci: CanvasItem) -> void:
	if flock == null:
		return
	var label := "%d / %d" % [flock.penned_count(), flock.sheep.size()]
	var r := Shell.chip(ci, Vector2(Shell.leader_chip_x(Shell.area_width(ci), CHIP_W), 36.0), label, UiTheme.TEXT_DIM, CHIP_W)
	Shell.record("team", ci, r, {"text": label})
