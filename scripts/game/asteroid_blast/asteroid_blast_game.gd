extends "res://scripts/game/minigame.gd"
## Asteroid Blast. Each phone tilts a little spaceship along the bottom of the screen. The ships shoot by themselves at the
## asteroids that fall from above. A pickup gives a force field or one more laser. A ship that is hit without a force field
## blows up. The waves last 30 s with 5 s of rest between them and get harder. It is a team game with a winner: the most points
## win. It is endless and ends when every ship is gone (REQ-AB-1 to 20). The game is for children too (REQ-GM-80 to 84).
## RECENTER recenters (REQ-GM-37). The rules are in space_field.gd, the pictures in blast_look.gd.

const SpaceField = preload("res://scripts/game/asteroid_blast/space_field.gd")
const BlastLook = preload("res://scripts/game/asteroid_blast/blast_look.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const COUNTDOWN := 3.0
## After the last ship is gone the sky goes on for this long, then the result menu opens (REQ-AB-14).
const END_DELAY := 2.0
const BANNER_TIME := 2.0        # How long "Wave 3" shows at the start of a wave.
const HINT_TIME := 5.0
const BUZZ_GAP_MS := 150
const AREA_TOP := 150.0
const AREA_MARGIN := 60.0
const BAR_H := 112.0            # The black bar on top is for the title and the wave.
const TIMER_X := 560.0
const TIMER_W := 160.0
const BAR_LINE_Y := 100.0       # The line in the bar that shows how much of the wave is left.
const BAR_LINE_H := 8.0
const BOOM_SCALE := [0.6, 1.0, 1.5]   # The size of the explosion of a small, medium and large asteroid.
const SHIELD_LINE := Color("4cb4ff")  # The color of the line of a rest.

## Set before the game starts (REQ-GM-93). `start_props` keeps it for Restart.
var difficulty := "medium"

var field := SpaceField.new()

var _board: Scoreboard
var _clock := RoundClock.new(COUNTDOWN, 0.0)
var _rng := RandomNumberGenerator.new()
var _haptics := Haptics.new()
var _end_left := -1.0           # Below 0 until every ship is gone.
var _time := 0.0                # Seconds since the start: the stars drift with it.
var _booms: Array[Dictionary] = []   # {x, y, age, scale}: explosions on the screen, in field units.
var _tex := {}                  # Cached pictures.


func _game_ready() -> void:
	_rng.randomize()
	field.setup(difficulty)
	_board = Scoreboard.new(participants)
	for i in participants.size():
		field.add_ship(participants[i], SpaceField.REF_AREA.x * float(i + 1) / float(participants.size() + 1))


func _on_player_left(slot: int) -> void:
	field.remove_ship(slot)
	_board.remove(slot)


func _game_tick(delta: float) -> void:
	_time += delta
	if is_over:
		return
	var tilts := {}
	for s in participants:
		tilts[s] = player(s).tilt().x
	if _clock.is_counting():
		field.tick(delta, _rng, tilts, false)   # The ships steer in the countdown; nothing falls yet.
		if _clock.tick(delta):
			for s in participants:
				player(s).recenter()   # The pose held in the countdown is the center.
				App.server.haptic(s, 60)
		return
	field.tick(delta, _rng, tilts, true)
	for e in field.events:
		_on_event(e)
	for s in field.scores:
		_board.set_score(s, float(field.scores[s]))
	for b in _booms:
		b.age += delta
	_booms = _booms.filter(func(b: Dictionary) -> bool: return float(b.age) < BlastLook.EXPLODE_TIME)
	if _end_left < 0.0 and field.all_lost():
		_end_left = END_DELAY
	elif _end_left >= 0.0:
		_end_left -= delta
		if _end_left <= 0.0:
			_finish()


## Sounds, buzzes and explosions for what happened in this tick (REQ-AB-15).
func _on_event(e: Dictionary) -> void:
	match String(e.t):
		"kill":
			_booms.append({"x": e.x, "y": e.y, "age": 0.0, "scale": BOOM_SCALE[int(e.size)]})
			Sound.sfx("blast_boom")
		"upgrade_taken":
			Sound.sfx("blast_pickup")
			_haptics.pulse(int(e.slot), 30, BUZZ_GAP_MS)
		"shield_pop":
			_booms.append({"x": e.x, "y": e.y, "age": 0.0, "scale": 0.8})
			Sound.sfx("blast_shield")
			_haptics.pulse(int(e.slot), 80, BUZZ_GAP_MS)
		"ship_lost":
			_booms.append({"x": e.x, "y": e.y, "age": 0.0, "scale": 1.6})
			Sound.sfx("blast_lost")
			_haptics.pulse(int(e.slot), 400, BUZZ_GAP_MS)
		"wave_end", "wave_start":
			Sound.sfx("blast_wave")


## REQ-AB-14: every ship is gone, the game is over. One player gets a medal for the score, more players the winner.
func _finish() -> void:
	for s in _board.winners():
		App.server.haptic(s, 400)
	var title := Lang.f("Reached wave %d", [field.wave]) if participants.size() == 1 else ""
	open_results(_board, SpaceField.LEVELS.get(difficulty, SpaceField.LEVELS.medium).tiers, title)


func _scoreboard() -> Scoreboard:
	return _board


## The personal best (REQ-GM-98): the score, for each difficulty.
func best_key() -> String:
	return "asteroid_blast|%s" % difficulty


# ---- Drawing ----

func _pixel_world() -> bool:
	return true


## The scale and the top-left corner of the play area on the screen.
func _fit() -> Dictionary:
	var avail := Vector2(size.x - 2.0 * AREA_MARGIN, size.y - AREA_TOP - AREA_MARGIN)
	var k := minf(avail.x / SpaceField.REF_AREA.x, avail.y / SpaceField.REF_AREA.y)
	var center := Vector2(AREA_MARGIN + avail.x * 0.5, AREA_TOP + avail.y * 0.5)
	return {"k": k, "origin": center - SpaceField.REF_AREA * k * 0.5}


func _picture(key: String, make: Callable) -> ImageTexture:
	if not _tex.has(key):
		_tex[key] = ImageTexture.create_from_image(make.call())
	return _tex[key]


func _draw_picture(ci: CanvasItem, tex: ImageTexture, center: Vector2, scale := 1.0) -> void:
	var sz := Vector2(tex.get_size()) * Shell.WORLD_PIXEL * scale
	ci.draw_texture_rect(tex, Rect2(Shell.snap(center - sz * 0.5), sz), false)


func _world_draw(ci: CanvasItem) -> void:
	var fit := _fit()
	var k: float = fit.k
	var o: Vector2 = fit.origin
	BlastLook.draw_sky(ci, size)
	BlastLook.draw_stars(ci, _time)
	BlastLook.draw_planet(ci, Vector2(size.x - 260.0, 300.0), 90.0)
	for a in field.asteroids:
		var tex := _picture("rock%d_%d" % [a.size, a.look], BlastLook.asteroid_image.bind(a.size, a.look, a.radius * k))
		_draw_picture(ci, tex, o + Vector2(a.x, a.y) * k)
	for u in field.upgrades:
		_draw_picture(ci, _picture("up_" + u.kind, BlastLook.pickup_image.bind(u.kind)), o + Vector2(u.x, u.y) * k)
	for b in field.beams:
		BlastLook.draw_beam(ci, o + Vector2(b.x, b.y) * k, player(b.owner).color if _has_player(b.owner) else Color.WHITE)
	for s in field.ships.values():
		if s.alive:
			_draw_ship(ci, s, o, k)
	for b in _booms:
		BlastLook.draw_explosion(ci, o + Vector2(b.x, b.y) * k, b.age, b.scale)
	ci.draw_rect(Rect2(0, 0, size.x, BAR_H), UiTheme.BG)


func _has_player(slot: int) -> bool:
	return participants.has(slot)


func _draw_ship(ci: CanvasItem, s: SpaceField.Ship, o: Vector2, k: float) -> void:
	var p := o + Vector2(s.x, SpaceField.SHIP_Y) * k
	var frame := int(_time * 10.0) % 2
	var tex := _picture("ship_%d_%d" % [s.slot, frame], BlastLook.ship_image.bind(player(s.slot).color, frame))
	# The hull is the top 14 of the picture; the middle of the hull is the place of the ship.
	_draw_picture(ci, tex, p + Vector2(0.0, (float(tex.get_height()) * 0.5 - 8.0) * Shell.WORLD_PIXEL))
	if s.shield:
		BlastLook.draw_shield(ci, p, (SpaceField.SHIP_R + 10.0) * k, _time)


func _game_draw() -> void:
	Shell.title(self, "ASTEROID BLAST")
	draw_leader_chip(self)
	var fit := _fit()
	if _clock.is_counting():
		var n := _clock.count_number()
		var label := str(n) if n > 0 else "GO"
		draw_set_transform(Vector2(8.0, 8.0), 0.0, Vector2.ONE)   # A black shadow: the stars must not hide the digits.
		Shell.countdown(self, size, label, _clock.count_elapsed(), UiTheme.BG)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Shell.countdown(self, size, label, _clock.count_elapsed())
		var spots := {}
		for s in field.ships:
			spots[s] = Shell.snap(fit.origin + Vector2(field.ships[s].x, SpaceField.SHIP_Y) * float(fit.k))
		draw_name_tags(self, spots, SpaceField.SHIP_R * float(fit.k) + 24.0)
		Shell.hint(self, size, "Tilt to steer. Your ship shoots by itself. Grab the upgrades!")
		return
	if is_over:
		return
	Shell.text(self, Vector2(Shell.mx(self, TIMER_X, TIMER_W + 80.0), 84.0), Lang.f("Wave %d", [field.wave]), 32, UiTheme.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER, TIMER_W + 80.0)
	_draw_wave_line()
	if field.phase == SpaceField.Phase.REST:
		_label(Vector2(size.x * 0.5, size.y * 0.36), Lang.f("Wave %d clear!", [field.wave]), 72, UiTheme.ACCENT)
		_label(Vector2(size.x * 0.5, size.y * 0.36 + 110.0), Lang.f("Next wave in %d", [ceili(field.phase_left())]), 48,
				UiTheme.TEXT)
	elif field.phase_time < BANNER_TIME and _end_left < 0.0:
		_label(Vector2(size.x * 0.5, size.y * 0.36), Lang.f("Wave %d", [field.wave]), 72, UiTheme.ACCENT)
	if _end_left >= 0.0:
		_label(Vector2(size.x * 0.5, size.y * 0.36), Lang.t("All ships are gone!"), 72, UiTheme.ACCENT)
	elif _time < COUNTDOWN + HINT_TIME:
		Shell.hint(self, size, "Tilt to steer. Your ship shoots by itself. Grab the upgrades!")


## The line at the bottom of the bar: how much of the wave (or of the rest) is left.
func _draw_wave_line() -> void:
	var full := size.x - 2.0 * AREA_MARGIN
	var total := SpaceField.WAVE_TIME if field.phase == SpaceField.Phase.WAVE else SpaceField.REST_TIME
	var w := full * clampf(field.phase_left() / total, 0.0, 1.0)
	var color := UiTheme.ACCENT if field.phase == SpaceField.Phase.WAVE else SHIELD_LINE
	draw_rect(Rect2(Shell.mx(self, AREA_MARGIN, w), BAR_LINE_Y, w, BAR_LINE_H), color)



## A text on a black plate with a frame, centered at `at` (`at.y` is the baseline), so the stars behind it never hide it.
func _label(at: Vector2, msg: String, font_size: int, color: Color) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(msg.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var plate := Rect2(at.x - w * 0.5 - 24.0, at.y - f.get_ascent(font_size) - 20.0, w + 48.0, f.get_height(font_size) + 40.0)
	draw_style_box(UiTheme.line_box(UiTheme.TEXT, UiTheme.BG, Shell.CHIP_LINE), plate)
	Shell.text_centered(self, at, msg, font_size, color)
