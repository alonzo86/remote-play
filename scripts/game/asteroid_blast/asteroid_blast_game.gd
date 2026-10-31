extends "res://scripts/game/minigame.gd"
## Star Shield. Each phone tilts a little spaceship along the bottom of the screen. The ships shoot by themselves at the
## asteroids that fall from above. A pickup gives a force field or one more laser. A ship that is hit without a force field
## blows up. The waves last 30 s with 5 s of rest between them and get harder. It is a team game with a winner: the most points
## win. It is endless and ends when every ship is gone (REQ-AB-1 to 20). The game is for children too (REQ-GM-80 to 84).
## RECENTER recenters (REQ-GM-37). The rules are in space_field.gd, the pictures in blast_look.gd.

const SpaceField = preload("res://scripts/game/asteroid_blast/space_field.gd")
const BlastLook = preload("res://scripts/game/asteroid_blast/blast_look.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

## After the last ship is gone the sky goes on for this long, then the result menu opens (REQ-AB-14).
const END_DELAY := 2.0
const BANNER_TIME := 2.0        # How long "Wave 3" shows at the start of a wave.
const HINT_TIME := 5.0
const BUZZ_GAP_MS := 150
const AREA_TOP := 150.0
const AREA_MARGIN := 60.0
const BAR_H := HUD_BAR_H            # The black bar on top (the shell draws it, REQ-GM-45a).
const TIMER_X := 560.0
const TIMER_W := 160.0
const BANNER_FONT := 72         # The banners in the middle of the screen.
const SUB_FONT := 48            # "Next wave in 3" under the banner.
const BAR_LINE_Y := 100.0       # The line in the bar that shows how much of the wave is left.
const BAR_LINE_H := 8.0
const BOOM_SCALE := [0.6, 1.0, 1.5]   # The size of the explosion of a small, medium and large asteroid.
const SHIELD_LINE := Color("4cb4ff")  # The color of the line of a rest.

## Set before the game starts (REQ-GM-93). `start_props` keeps it for Restart.
var difficulty := "medium"

var field := SpaceField.new()

var _board: Scoreboard
var _rng := RandomNumberGenerator.new()
var _haptics := Haptics.new()
var _end_left := -1.0           # Below 0 until every ship is gone.
var _time := 0.0                # Seconds since the start: the stars drift with it.
var _booms: Array[Dictionary] = []   # {x, y, age, scale}: explosions on the screen, in field units.
var _tex := {}                  # Cached pictures.


func _has_countdown() -> bool:
	return false   # No visible timer, so no countdown (REQ-GM-35): wave 1 starts at once.


func _game_ready() -> void:
	_rng.randomize()
	field.setup(difficulty)
	_board = Scoreboard.new(participants)
	for i in participants.size():
		field.add_ship(participants[i], SpaceField.REF_AREA.x * float(i + 1) / float(participants.size() + 1))
		player(participants[i]).recenter()   # The pose held at the start is the center.


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
		"ship_back":
			Sound.sfx("blast_shield")
		"wave_end", "wave_start":
			Sound.sfx("blast_wave")


## REQ-AB-14: every ship is gone, the game is over. One player sees the wave that was reached and no medal, more players the
## winner and the medal of the place.
func _finish() -> void:
	for s in _board.winners():
		game_host.haptic(s, 400)
	var title := Lang.f("asteroid_blast.reached_wave", [field.wave]) if participants.size() == 1 else ""
	open_results(_board, title)


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
	BlastLook.draw_planet(ci, Vector2(size.x - 260.0, 300.0), 50.0)
	for a in field.asteroids:
		var tex := _picture("rock%d_%d_%d" % [a.size, a.look, roundi(k * 100.0)],
				BlastLook.asteroid_image.bind(a.size, a.look, a.radius * k))
		_draw_picture(ci, tex, o + Vector2(a.x, a.y) * k)
	for u in field.upgrades:
		_draw_picture(ci, _picture("up_" + u.kind, BlastLook.pickup_image.bind(u.kind)), o + Vector2(u.x, u.y) * k)
	for b in field.beams:
		BlastLook.draw_beam(ci, o + Vector2(b.x, b.y) * k, beam_color(b.owner))
	for s in field.ships.values():
		if s.alive:
			_draw_ship(ci, s, o, k)
	for b in _booms:
		BlastLook.draw_explosion(ci, o + Vector2(b.x, b.y) * k, b.age, b.scale)


func _has_player(slot: int) -> bool:
	return participants.has(slot)


## The color of the beams of the ship of `slot`: the color of its player (white when the player has left).
func beam_color(slot: int) -> Color:
	return player(slot).color if _has_player(slot) else Color.WHITE


## "Next wave in 3" for the rest between two waves.
func next_wave_text() -> String:
	return Lang.f("asteroid_blast.next_wave_in", [ceili(field.phase_left())])


## How much of the wave (or of the rest) is left, 1 to 0: the length of the line in the bar.
func wave_line_fraction() -> float:
	var total := SpaceField.WAVE_TIME if field.phase == SpaceField.Phase.WAVE else SpaceField.REST_TIME
	return clampf(field.phase_left() / total, 0.0, 1.0)


func _draw_ship(ci: CanvasItem, s: SpaceField.Ship, o: Vector2, k: float) -> void:
	var p := o + Vector2(s.x, SpaceField.SHIP_Y) * k
	var frame := int(_time * 10.0) % 2
	var tex := _picture("ship_%d_%d" % [s.slot, frame], BlastLook.ship_image.bind(player(s.slot).color, frame))
	# The hull is the top 14 of the picture; the middle of the hull is the place of the ship.
	var blink_off: bool = s.grace > 0.0 and int(_time * 6.0) % 2 == 0   # A ship in its grace time blinks (issue #137).
	if not blink_off:
		_draw_picture(ci, tex, p + Vector2(0.0, (float(tex.get_height()) * 0.5 - 8.0) * Shell.WORLD_PIXEL))
	if s.shield:
		BlastLook.draw_shield(ci, p, (SpaceField.SHIP_R + 10.0) * k, _time)


func _game_draw() -> void:
	Shell.title(self, "registry.star_shield")
	draw_leader_chip(self)
	if is_over:
		return
	Shell.status(self, TIMER_X, TIMER_W + 80.0, Lang.f("asteroid_blast.wave_n", [field.wave]))
	_draw_wave_line()
	match banner():
		"wave_clear":
			Shell.label_plate(self, banner_at(), Lang.f("asteroid_blast.wave_clear", [field.wave]), BANNER_FONT, UiTheme.ACCENT)
			Shell.label_plate(self, banner_at() + Vector2(0.0, 110.0),
					next_wave_text(), SUB_FONT, UiTheme.TEXT)
		"wave_n":
			Shell.label_plate(self, banner_at(), Lang.f("asteroid_blast.wave_n", [field.wave]), BANNER_FONT, UiTheme.ACCENT)
		"all_ships_gone":
			Shell.label_plate(self, banner_at(), Lang.t("asteroid_blast.all_ships_gone"), BANNER_FONT, UiTheme.ACCENT)
	if hint_shown():
		Shell.hint(self, size, "asteroid_blast.tilt_steer_ship_shoots")


## Where the big banners are drawn (the baseline, in the middle of the plate).
func banner_at() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.36)


## The big banner in the middle (REQ-AB-16): "all_ships_gone" once the last ship is out, "wave_clear" in the rest, "wave_n" for
## BANNER_TIME at the start of a wave, else "". Only one at a time, so two plates never share a spot.
func banner() -> String:
	if _end_left >= 0.0:
		return "all_ships_gone"
	if field.phase == SpaceField.Phase.REST:
		return "wave_clear"
	if field.phase_time < BANNER_TIME:
		return "wave_n"
	return ""


## True while the hint line shows: for HINT_TIME after the start, never after the last ship is out (REQ-AB-16).
func hint_shown() -> bool:
	return _end_left < 0.0 and _time < HINT_TIME


## The line at the bottom of the bar: how much of the wave (or of the rest) is left.
func _draw_wave_line() -> void:
	var w := (size.x - 2.0 * AREA_MARGIN) * wave_line_fraction()
	var color := UiTheme.ACCENT if field.phase == SpaceField.Phase.WAVE else SHIELD_LINE
	draw_rect(Rect2(Shell.mx(self, AREA_MARGIN, w), BAR_LINE_Y, w, BAR_LINE_H), color)
