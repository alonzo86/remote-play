extends "res://scripts/game/minigame.gd"
## Paint Grab. Each phone tilts a friendly paint blob over a floor of square tiles. The tile under a blob takes the color of
## that blob, also when it had the color of another player. After 60 s the most tiles win (REQ-PG-1 to 17). The game is for
## children too (REQ-GM-80 to 84): a painted-over tile costs only that tile. The RECENTER button recenters (REQ-GM-37).
## A and B do nothing.
## The rules of the floor are in paint_floor.gd and the movement is in `TiltBody` (scripts/game/tilt_body.gd).

const PaintFloor = preload("res://scripts/game/paint_grab/paint_floor.gd")
const TiltBody = preload("res://scripts/game/tilt_body.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const ROUND_TIME := 60.0
const COUNTDOWN := 3.0
const REF_TILE := 100.0         # The simulation runs on a floor of 100 px tiles; the drawing is scaled to the screen (REQ-GM-13).
const BLOB_R := 34.0
const BUZZ_GAP_MS := 150        # REQ-PG-12.
const EDGE_SOUND_SPEED := 250.0   # px/s. A slower hit at the edge makes no sound.
const LEAD_SOUND_TIME := 10.0     # s. The lead alert is in the last seconds.
const POP_TIME := 0.15          # A painted tile grows and goes back in this time (REQ-PG-16).
const HINT_TIME := 4.0
const BOARD_TOP := 150.0        # The floor is the screen inside the margin, under the HUD.
const BOARD_MARGIN := 60.0
const TIMER_X := 520.0
const TIMER_W := 208.0          # "60.0 S" in the 32 px font is 192 px wide.
## Difficulty (REQ-PG-20): the floor, the speed of the blobs (a factor on the Medium values) and the medal tiers in percent of the
## floor (first guesses, Test 13). A tile is `REF_TILE` in the simulation; on the screen it is as big as the floor fits.
const LEVELS := {
	"easy": {"cols": 12, "rows": 7, "speed": 0.8, "tiers": [35, 55, 75]},
	"medium": {"cols": 16, "rows": 9, "speed": 1.0, "tiers": [30, 50, 70]},
	"hard": {"cols": 20, "rows": 11, "speed": 1.25, "tiers": [25, 40, 55]},
}
## Where the blobs start: the corners of a rectangle around the middle of the floor, so that all have the same distance to it.
const START_SPOTS := [Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1)]
const START_SHARE := 0.3

# Look (REQ-PG-15, REQ-GM-47i to 47n). The floor is dark so that every player color has a contrast of 3:1 or more.
const STAR_COUNT := 48
const FLOOR_COLOR := Color("2a1070")
const EMPTY_TILE := Color("3a1c97")
const TILE_GAP := Shell.WORLD_PIXEL   # One world pixel between two tiles.

## Set before the game starts (REQ-GM-93). `start_props` keeps it for Restart.
var difficulty := "medium"

var floor_map: PaintFloor
var _round := RoundClock.new(COUNTDOWN, ROUND_TIME)
var _touching := {}     # Pairs of blobs that touch now (one sound for one touch).
var _leader := -1       # The blob that has the most tiles in the last seconds.
var _board: Scoreboard
var _bodies := {}                 # slot -> TiltBody
var _haptics := Haptics.new()
var _pops := PackedFloat32Array()  # The time left of the pop of each tile.
var _level := {}
var _stars := PackedVector2Array()


func _game_ready() -> void:
	_level = LEVELS.get(difficulty, LEVELS.medium)
	floor_map = PaintFloor.new(int(_level.cols), int(_level.rows), REF_TILE)
	_pops.resize(floor_map.cols * floor_map.rows)
	_pops.fill(0.0)
	_stars = Shell.star_field(STAR_COUNT, 13)
	_board = Scoreboard.new(participants)
	var middle := floor_map.size() * 0.5
	for i in participants.size():
		var b: TiltBody = TiltBody.new()
		b.radius = BLOB_R
		b.max_speed *= float(_level.speed)
		b.accel *= float(_level.speed)
		var spot: Vector2 = START_SPOTS[i % START_SPOTS.size()]
		b.pos = middle + spot * floor_map.size() * START_SHARE
		_bodies[participants[i]] = b


func _on_player_left(slot: int) -> void:
	_bodies.erase(slot)
	_board.remove(slot)   # The tiles of the player stay on the floor and count for nobody (REQ-PG-10).


func _game_tick(delta: float) -> void:
	if is_over:
		return
	if _round.is_counting():
		if _round.tick(delta):
			for s in _bodies:
				player(s).recenter()   # The pose held in the countdown is the center.
				App.server.haptic(s, 60)
		return
	_round.tick(delta)
	var bounds := Rect2(Vector2.ZERO, floor_map.size())
	for s in _bodies:
		var b: TiltBody = _bodies[s]
		if b.step(delta, player(s).tilt(), bounds) > EDGE_SOUND_SPEED:
			Sound.sfx("paint_edge")
	var slots: Array = _bodies.keys()
	for i in slots.size():
		for j in range(i + 1, slots.size()):
			var pair: int = int(slots[i]) * 4 + int(slots[j])
			if TiltBody.collide(_bodies[slots[i]], _bodies[slots[j]]):
				if not _touching.has(pair):
					_touching[pair] = true
					Sound.sfx("paint_bounce")   # One sound for one touch, not one for every frame.
			else:
				_touching.erase(pair)
	for s in _bodies:
		_paint_under(s)
	_lead_sound()
	for i in _pops.size():
		if _pops[i] > 0.0:
			_pops[i] = maxf(_pops[i] - delta, 0.0)
	if _round.is_time_up():
		_finish()


## In the last seconds of the round, a short alert when another blob takes the lead (docs/AUDIO_PLAN.md, section 4.3).
func _lead_sound() -> void:
	if _round.remaining() > LEAD_SOUND_TIME:
		return
	var w := _board.winners()
	if w.size() != 1:
		return
	if _leader >= 0 and w[0] != _leader:
		Sound.sfx("paint_lead")
	_leader = w[0]


## REQ-PG-4: the blob paints the tile under its middle.
func _paint_under(slot: int) -> void:
	var c := floor_map.cell_at(_bodies[slot].pos)
	if c.x < 0:
		return
	var before := floor_map.owner_of(c)
	var result := floor_map.paint(c, slot)
	if result == PaintFloor.Result.SAME:
		return
	_pops[c.y * floor_map.cols + c.x] = POP_TIME
	Sound.sfx("paint_tile" if result != PaintFloor.Result.TAKEN else "paint_steal")
	_board.set_score(slot, floor_map.count(slot))
	if result == PaintFloor.Result.TAKEN:
		if _bodies.has(before):
			_board.set_score(before, floor_map.count(before))
		_haptics.pulse(slot, 20, BUZZ_GAP_MS)   # REQ-PG-12


func _finish() -> void:
	for s in _board.winners():
		App.server.haptic(s, 400)
	var tiers: Array = _level.tiers
	var heading := ""
	if _board.ranking().size() == 1:   # One player: the share of the floor gives the medal (REQ-PG-21).
		var slot: int = _board.ranking()[0].slot
		var medal := Medals.medal(floor_map.percent(slot), tiers)
		heading = "%s (%s)" % [Medals.label(medal), Lang.t(difficulty.capitalize())]
	open_results(_board, [], heading, [], _score_text)


## "34 tiles (23%)" for the result list.
func _score_text(tiles: float) -> String:
	return Lang.f("%d tiles (%d%%)", [int(tiles), int(tiles) * 100 / floor_map.total()])   # The percent is rounded down (REQ-PG-21).


# ---- Drawing ----

## The scale and the corner of the floor on the screen: it is as big as it fits inside the margin and under the HUD. A tile is a
## whole number of world pixels wide (a multiple of 4 units), so that all gaps between the tiles are equal (REQ-GM-47l).
func _fit() -> Dictionary:
	var avail := Vector2(size.x - 2.0 * BOARD_MARGIN, size.y - BOARD_TOP - BOARD_MARGIN)
	var fl := floor_map.size()
	var fit_k := minf(avail.x / fl.x, avail.y / fl.y)
	var pitch := maxf(floorf(REF_TILE * fit_k / Shell.WORLD_PIXEL) * Shell.WORLD_PIXEL, Shell.WORLD_PIXEL)
	var k := pitch / REF_TILE
	return {"k": k, "origin": Shell.snap(Vector2(BOARD_MARGIN + (avail.x - fl.x * k) * 0.5, BOARD_TOP + (avail.y - fl.y * k) * 0.5))}


func _pixel_world() -> bool:
	return true


func _world_draw(ci: CanvasItem) -> void:
	var fit := _fit()
	var k: float = fit.k
	var origin: Vector2 = fit.origin
	ci.draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	Shell.draw_stars(ci, _stars)
	var board := Rect2(origin, floor_map.size() * k).grow(12.0)
	ci.draw_rect(board.grow(Shell.WORLD_PIXEL), UiTheme.OUTLINE)
	ci.draw_rect(board, FLOOR_COLOR)
	for r in floor_map.rows:
		for c in floor_map.cols:
			_draw_tile(ci, Vector2i(c, r), origin, k)
	for s in _bodies:
		_draw_blob(ci, s, origin, k)


func _game_draw() -> void:
	var fit := _fit()
	var k: float = fit.k
	var origin: Vector2 = fit.origin
	for s in _bodies:   # The slot numbers: full resolution, on top of the pixel blob (REQ-GM-47n).
		Shell.ball_number(self, Shell.snap(origin + (_bodies[s] as TiltBody).pos * k), BLOB_R * k, player(s).color, s,
				Shell.NUMBER_DROP, player(s).avatar)
	_draw_hud()


## A tile: flat, one world pixel apart from the next. A painted tile pops for a moment: it is one world pixel wider on each side
## (REQ-PG-16, a hard step).
func _draw_tile(ci: CanvasItem, c: Vector2i, origin: Vector2, k: float) -> void:
	var owner_slot := floor_map.owner_of(c)
	var pop := _pops[c.y * floor_map.cols + c.x] > 0.0
	var side := REF_TILE * k - TILE_GAP + (Shell.WORLD_PIXEL * 2.0 if pop else 0.0)
	var rect := Rect2(origin + Vector2(c) * REF_TILE * k - Vector2.ONE * (Shell.WORLD_PIXEL if pop else 0.0), Vector2(side, side))
	ci.draw_rect(rect, EMPTY_TILE if owner_slot == PaintFloor.NONE else player(owner_slot).color)


func _draw_blob(ci: CanvasItem, slot: int, origin: Vector2, k: float) -> void:
	var b: TiltBody = _bodies[slot]
	var center := origin + b.pos * k
	var radius := BLOB_R * k
	Shell.pixel_ball(ci, center, radius, player(slot).color)
	Shell.pixel_eyes(ci, center, radius, b.vel / b.max_speed)   # The pupils step to the side the blob rolls (REQ-PG-16).


func _scoreboard() -> Scoreboard:
	return _board


func _draw_hud() -> void:
	Shell.title(self, "PAINT GRAB")
	draw_leader_chip(self)
	if _round.is_playing() and not is_over:
		Shell.timer(self, Vector2(TIMER_X, 36.0), _round.remaining(), TIMER_W)
	if _round.is_counting() and not participants.is_empty():
		var n := _round.count_number()
		Shell.countdown(self, size, str(n) if n > 0 else "GO", _round.count_elapsed())
		var fit := _fit()
		var spots := {}
		for s in _bodies:
			spots[s] = Shell.snap(fit.origin + (_bodies[s] as TiltBody).pos * float(fit.k))
		draw_name_tags(self, spots, BLOB_R * float(fit.k))
	if _round.time < HINT_TIME and not is_over:
		Shell.hint(self, size, "Tilt your phone to roll and paint the tiles!")
