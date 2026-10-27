extends "res://scripts/game/minigame.gd"
## Freeze Dance. Everybody wiggles the phone while the music plays and the dancers on the TV dance; when the music stops and the
## floor lights go out, everybody holds the phone still. A player who holds still gets 10 points. A player who moves gets no
## points for that song, rests until the next one and keeps the points (REQ-FD-1 to 16, REQ-GM-83).
## The game is for children too (REQ-GM-80 to 84).
## The rules are in dance_rules.gd, the pictures in dance_look.gd. This script has the input, the round and the drawing.

const DanceRules = preload("res://scripts/game/freeze_dance/dance_rules.gd")
const DanceLook = preload("res://scripts/game/freeze_dance/dance_look.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const BAR_H := 112.0             # The black bar on top is for the HUD.
const TIMER_X := Shell.TIMER_X   # The song counter has the place of the timer (REQ-GM-47o).
const BANNER_Y := 176.0          # The baseline of the banner WIGGLE! / FREEZE!.
const BANNER_SIZE := 64
const HINT_TIME := 4.0           # Seconds of the first song with the hint on the screen.
const BUZZ_GAP_MS := 100         # REQ-GM-43.
const MOVE_BUZZ_MS := 80
const HELD_BUZZ_MS := 40
const WIN_BUZZ_MS := 400
const POP_COUNT := 8
const POP_LIFE := 1.2
const DANCE_RATE := 5.0          # Steps of the dance in a second.
const BENCH_STEP := 104.0        # The height of one place on the bench.
const BENCH_W := 280.0
const SONG_WAIT_MAX := 8.0   # Seconds the first round waits for its song at most.

## A "+10" that floats up above a dancer. The pool is made once (REQ-GM-51).
class Pop:
	var pos := Vector2.ZERO
	var text := ""
	var color := Color.WHITE
	var age := -1.0   # Below 0: not in use.

## Set before the game starts (REQ-GM-93). `start_props` keeps it for Restart.
var difficulty := "medium"

var _rules := DanceRules.new()
var _rng := RandomNumberGenerator.new()
var _board: Scoreboard
var _haptics := Haptics.new()
var _seat := {}                  # slot -> the place of the dancer (0 to count - 1), fixed at the start (REQ-FD-13).
var _seat_count := 1
var _draw_order: Array[int] = [] # The slots, the far dancers first.
var _lit := {}                   # The lit tiles of the floor (Vector2i(row, col)).
var _light_clock := 0.0
var _light_step := -1
var _song_ready := false         # The song is made and the first round may start (issue #149).
var _song_wait := 0.0
var _scene_time := 0.0           # Game time of the dance: it stands still while the game is paused (REQ-FL-43).
var _pops: Array[Pop] = []
var _tex := {}                   # "slot|pose|dim" -> the ImageTexture of a dancer.
var _meters := {}                # slot -> DanceRules.Meter


## No countdown (REQ-GM-35): the game has no timer, and the first song starts at once.
func _has_countdown() -> bool:
	return false


func _game_ready() -> void:
	if start_props.has("seed"):
		_rng.seed = int(start_props.seed)   # REQ-FD-1: a test fixes the songs. Restart keeps the seed.
	else:
		_rng.randomize()
	_rules.setup(difficulty, participants, _rng)
	for s in participants:
		_meters[s] = DanceRules.Meter.new()
	_board = Scoreboard.new(participants)
	_seat_count = maxi(participants.size(), 1)
	for i in participants.size():
		_seat[participants[i]] = i
	_draw_order = participants.duplicate()
	_draw_order.sort_custom(func(a: int, b: int) -> bool:
		var pa := DanceLook.place(int(_seat[a]), _seat_count, size)
		var pb := DanceLook.place(int(_seat[b]), _seat_count, size)
		return float(pa.y) < float(pb.y) or (float(pa.y) == float(pb.y) and float(pa.x) < float(pb.x)))
	for i in POP_COUNT:
		_pops.append(Pop.new())
	_new_lights()


func _exit_tree() -> void:
	Sound.hold_music(false)   # The next game must not start with a held song.


func _on_player_left(slot: int) -> void:
	_rules.remove(slot)
	_meters.erase(slot)
	_board.remove(slot)


func _game_tick(delta: float) -> void:
	_scene_time += delta
	if not _song_ready:   # The first round waits until the song is made, so it has music (issue #149).
		_song_wait += delta
		_song_ready = Sound.song_ready(Registry.id_of_script(get_script())) or _song_wait >= SONG_WAIT_MAX
		return
	for p in _pops:
		if p.age >= 0.0:
			p.age += delta
			if p.age > POP_LIFE:
				p.age = -1.0
	if is_over:
		return
	var energies := {}
	for s in _meters:
		energies[s] = _meters[s].update(player(s).gyro, player(s).accel, delta)
	for e in _rules.tick(delta, energies):
		_on_event(e)
	if _rules.phase == DanceRules.Phase.MUSIC:
		_light_clock += delta
		if int(_light_clock / DanceRules.LIGHT_STEP) != _light_step:
			_new_lights()


## The lights of the floor change in steps while the music plays (REQ-FD-12).
func _new_lights() -> void:
	_light_step = int(_light_clock / DanceRules.LIGHT_STEP)
	_lit = DanceRules.lit_tiles(_light_step)


func _on_event(e: Dictionary) -> void:
	match String(e.type):
		"freeze":   # REQ-FD-2, 3: the music stops at once and every light goes out. Nothing is sent to the phones.
			Sound.hold_music(true)
			Sound.sfx("freeze_stop")
			_lit = {}
		"moved":   # REQ-FD-8
			_haptics.pulse(int(e.slot), MOVE_BUZZ_MS, BUZZ_GAP_MS)
			Sound.sfx("dance_out")
		"held":   # REQ-FD-7: the points come when the freeze ends.
			var slot := int(e.slot)
			if int(e.points) <= 0 or not _board.has(slot):
				return
			_board.add(slot, int(e.points))
			_haptics.pulse(slot, HELD_BUZZ_MS, BUZZ_GAP_MS)
			Sound.sfx("dance_points", 1.0 + 0.12 * float(slot))   # Each player has a pitch (docs/AUDIO_PLAN.md, section 9).
			_pop(slot, "+%d" % int(e.points))
		"song":   # The next song: the music goes on from where it stopped.
			Sound.hold_music(false)
			_light_clock = 0.0
			_new_lights()
		"done":
			_finish()


func _pop(slot: int, text: String) -> void:
	var at := DanceLook.place(int(_seat[slot]), _seat_count, size)
	var head := Vector2(float(at.x), float(at.y) - float(DanceLook.IMG.y * int(at.scale)) * size.x / 480.0 - 24.0)
	for p in _pops:
		if p.age < 0.0:
			p.pos = head
			p.text = text
			p.color = player(slot).color
			p.age = 0.0
			return


func _finish() -> void:
	Sound.hold_music(false)
	_light_clock = 0.0
	_new_lights()
	for s in _board.winners():
		App.server.haptic(s, WIN_BUZZ_MS)
	open_results(_board)


# ---- Drawing ----

func _pixel_world() -> bool:
	return true


## The world: the hall with the floor and the mirror ball, the dancers and the stage. All text is drawn by the HUD (REQ-GM-47n).
func _world_draw(ci: CanvasItem) -> void:
	var wp := size.x / 480.0
	DanceLook.draw_hall(ci, size, BAR_H, _lit, _scene_time)
	for s in _draw_order:
		var d: DanceRules.Dancer = _rules.dancers.get(s)
		if d == null or not d.plays():
			continue
		var at := DanceLook.place(int(_seat[s]), _seat_count, size)
		var step := floori(_scene_time * DANCE_RATE)
		var dancing := _rules.phase == DanceRules.Phase.MUSIC and d.energy >= DanceRules.WIGGLE_MIN * 0.5
		var pose := (1 + step % 2) if dancing else 0
		var hop := wp if dancing and step % 2 == 0 else 0.0   # A hop of one world pixel.
		DanceLook.draw_dancer(ci, _texture(s, pose, false), Vector2(float(at.x), float(at.y) - hop), int(at.scale), wp)
	DanceLook.draw_stage(ci, size)
	var row := 0
	for s in _bench():   # The dancers that moved, on the bench at the right (REQ-FD-8).
		var feet := _bench_feet(row)
		DanceLook.draw_dancer(ci, _texture(s, 0, true), feet, 1, wp)
		row += 1
	ci.draw_rect(Rect2(0, 0, size.x, BAR_H), UiTheme.BG)


func _texture(slot: int, pose: int, dim: bool) -> ImageTexture:
	var key := "%d|%d|%s" % [slot, pose, dim]
	if not _tex.has(key):
		_tex[key] = ImageTexture.create_from_image(DanceLook.dancer_image(player(slot).color, pose, dim))
	return _tex[key]


## The slots that moved in this song (REQ-FD-8), in slot order. A mover in the last song has no "BACK IN" time.
func _bench() -> Array[int]:
	var out: Array[int] = []
	if is_over:
		return out
	for s in participants:
		if _rules.is_out(s):
			out.append(s)
	return out


## The left edge of the "back in n" text under a chip at `chip_x`: centered under the chip, and inside the 60 px safe margin even
## when the text is wider than the bench (the Hebrew text is, issue #151).
static func bench_text_x(chip_x: float, text_w: float, area_w: float) -> float:
	return clampf(chip_x + (BENCH_W - 40.0) * 0.5 - text_w * 0.5, 60.0, area_w - 60.0 - text_w)


## The middle of the feet of the dancer on place `row` of the bench: the first place is the lowest.
func _bench_feet(row: int) -> Vector2:
	return Vector2(size.x - 60.0 - BENCH_W - 60.0, size.y - 120.0 - float(row) * BENCH_STEP + 40.0)


func _game_draw() -> void:
	for p in _pops:
		if p.age >= 0.0:
			Shell.text_centered(self, p.pos + Vector2(0.0, -p.age * 40.0), p.text, 48, p.color)
	_draw_hud()


func _scoreboard() -> Scoreboard:
	return _board


func _draw_hud() -> void:
	Shell.title(self, "registry.freeze_dance")
	draw_leader_chip(self)
	if not is_over:
		_draw_song_counter()
		_draw_banner()
		_draw_bench_plates()
		if _rules.song == 1 and _scene_time < HINT_TIME:
			Shell.hint(self, size, "freeze_dance.hint")


## "SONG n OF 6" in the place of the timer (REQ-FD-3).
func _draw_song_counter() -> void:
	var shown := Lang.f("freeze_dance.song_n", [_rules.song, DanceRules.SONGS]).to_upper()
	var w := Shell.timer_width(shown, 208.0)
	var r := Rect2(Vector2(Shell.mx(self, TIMER_X, w), 36.0), Vector2(w, 64.0))
	draw_style_box(UiTheme.line_box(UiTheme.TEXT, UiTheme.BG, Shell.CHIP_LINE), r)
	UiTheme.draw_centered(self, UiTheme.font(), shown, r, Shell.CHIP_FONT, UiTheme.TEXT)


## WIGGLE! during the music and FREEZE! from the stop to the end of the freeze (REQ-FD-3).
func _draw_banner() -> void:
	var key := ""
	var color := UiTheme.ACCENT
	match _rules.phase:
		DanceRules.Phase.MUSIC:
			key = "freeze_dance.wiggle"
		DanceRules.Phase.FREEZE:
			key = "freeze_dance.freeze"
			color = Color("a0f0ff")
	if key != "":
		Shell.label_plate(self, Vector2(size.x * 0.5, BANNER_Y), key, BANNER_SIZE, color)


## The name and the time of each player on the bench (REQ-FD-8). The dancer is drawn in the world, at the left of the chip.
func _draw_bench_plates() -> void:
	var row := 0
	for s in _bench():
		var feet := _bench_feet(row)
		var x := feet.x + 60.0
		var y := feet.y - 40.0
		var p := player(s)
		Shell.chip(self, Vector2(x, y - 20.0), slot_label(s), p.color, BENCH_W - 40.0, 64.0, p.avatar)
		var back_in := Lang.f("freeze_dance.back_in", [ceili(_rules.back_in(s))])
		var text_w := UiTheme.font().get_string_size(back_in.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BODY).x
		Shell.text(self, Vector2(bench_text_x(x, text_w, size.x), y + 76.0), back_in, UiTheme.SIZE_BODY, UiTheme.TEXT)
		row += 1
