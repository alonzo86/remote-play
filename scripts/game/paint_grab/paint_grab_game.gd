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
const PaintPicture = preload("res://scripts/game/paint_grab/paint_picture.gd")
const PaintPots = preload("res://scripts/game/paint_grab/paint_pots.gd")
const PaintLook = preload("res://scripts/game/paint_grab/paint_look.gd")

const ROUND_TIME := 60.0
const COUNTDOWN := 3.0
const REF_TILE := 100.0         # The simulation runs on a floor of 100 px tiles; the drawing is scaled to the screen (REQ-GM-13).
const BLOB_R := 34.0
const BUZZ_GAP_MS := 150        # REQ-PG-12.
const EDGE_SOUND_SPEED := 250.0   # px/s. A slower hit at the edge makes no sound.
const LEAD_SOUND_TIME := 10.0     # s. The lead alert is in the last seconds.
const POT_POP_TIME := 0.4      # The tiles that a pot paints pop for a longer time (REQ-PG-23).
const POT_BUZZ_MS := 40
const POT_BUZZ_GAP_MS := 150
const POP_TIME := 0.15          # A painted tile grows and goes back in this time (REQ-PG-16).
const HINT_TIME := 4.0
const BOARD_TOP := 150.0        # The floor is the screen inside the margin, under the HUD.
const BOARD_MARGIN := 60.0
const TIMER_X := Shell.TIMER_X  # The timer box has the same place in every game (REQ-GM-47o).
const TIMER_W := Shell.TIMER_W
## Difficulty (REQ-PG-20): the floor, and the speed of the blobs (a factor on the Medium values)
## (first guesses, Test 13). A tile is `REF_TILE` in the simulation; on the screen it is as big as the floor fits.
const LEVELS := {
	"easy": {"cols": 12, "rows": 7, "speed": 0.8},
	"medium": {"cols": 16, "rows": 9, "speed": 1.0},
	"hard": {"cols": 20, "rows": 11, "speed": 1.25},
}
## Where the blobs start: the corners of a rectangle around the middle of the floor, so that all have the same distance to it.
const START_SPOTS := [Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1)]
const START_SHARE := 0.3

# Look (REQ-PG-15, REQ-GM-47i to 47n). The floor is dark so that every player color has a contrast of 3:1 or more.
const STAR_COUNT := 48
const FLOOR_COLOR := Color("2a1070")
const EMPTY_TILE := Color("2a3a8c")
const OUTSIDE_TILE := Color("1d0b4d")   # A tile outside the picture: a dark block, nobody can paint it (REQ-PG-24).
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
var _rng := RandomNumberGenerator.new()
var _pots := PaintPots.new()
var _picture_total := 0              # Tiles that belong to the picture, the only ones that can be painted (REQ-PG-24).
var _picture := PackedInt32Array()   # The part of the picture on each tile (PaintPicture), row after row (REQ-PG-22).
var _pot_textures := {}


func _game_ready() -> void:
	_level = LEVELS.get(difficulty, LEVELS.medium)
	floor_map = PaintFloor.new(int(_level.cols), int(_level.rows), REF_TILE)
	_pops.resize(floor_map.cols * floor_map.rows)
	_pops.fill(0.0)
	_stars = Shell.star_field(STAR_COUNT, 13)
	if start_props.has("seed"):
		_rng.seed = int(start_props.seed)   # A test fixes the picture and the pots. Restart keeps the seed.
	else:
		_rng.randomize()
	_picture = PaintPicture.kinds_for(PaintPicture.pick(_rng), floor_map.cols, floor_map.rows, _rng.randf() < 0.5,
			_rng.randf() < 0.5)
	_picture_total = 0
	for k in _picture:
		if k != PaintPicture.EMPTY:
			_picture_total += 1
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
				game_host.haptic(s, 60)
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
	_tick_pots(delta)
	_lead_sound()
	for i in _pops.size():
		if _pops[i] > 0.0:
			_pops[i] = maxf(_pops[i] - delta, 0.0)
	if _round.is_time_up() or PaintPicture.is_painted(_picture, floor_map.owners, PaintFloor.NONE):
		_finish()   # REQ-PG-5: the time is up, or the last tile of the picture got a color.


## The pots (REQ-PG-23): one lands now and then, and the first blob that rolls over it paints its patch.
func _tick_pots(delta: float) -> void:
	var cells := []
	for s in _bodies:
		cells.append(floor_map.cell_at(_bodies[s].pos))
	_pots.tick(delta, _rng, floor_map.cols, floor_map.rows, cells, is_paintable)
	for s in _bodies:
		var c: Vector2i = floor_map.cell_at(_bodies[s].pos)
		var pot := _pots.take_at(c) if c.x >= 0 else null
		if pot != null:
			_apply_pot(s, pot)


func _apply_pot(slot: int, pot: PaintPots.Pot) -> void:
	for c in PaintPots.patch(pot.kind, pot.cell, floor_map.cols, floor_map.rows):
		if not is_paintable(c):
			continue   # A pot paints the picture tiles of its patch only (REQ-PG-24).
		if floor_map.paint(c, slot) != PaintFloor.Result.SAME:
			_pops[c.y * floor_map.cols + c.x] = POT_POP_TIME
	for s in _bodies:
		_board.set_score(s, floor_map.count(s))
	Sound.sfx("paint_tile")   # Not "paint_lead": that one says that someone took the lead.
	_haptics.pulse(slot, POT_BUZZ_MS, POT_BUZZ_GAP_MS)   # REQ-GM-43


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


## True for a tile that belongs to the picture: only those tiles can be painted and count (REQ-PG-24).
func is_paintable(c: Vector2i) -> bool:
	return c.x >= 0 and _picture[c.y * floor_map.cols + c.x] != PaintPicture.EMPTY


## REQ-PG-4: the blob paints the tile under its middle.
func _paint_under(slot: int) -> void:
	var c := floor_map.cell_at(_bodies[slot].pos)
	if c.x < 0:
		return
	if not is_paintable(c):
		return   # REQ-PG-24: a tile outside the picture stays as it is.
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
		game_host.haptic(s, 400)
	var heading := ""
	if _board.ranking().size() == 1:   # One player: the difficulty that was played is the title (REQ-PG-21).
		heading = Lang.t("game_settings." + difficulty)
	open_results(_board, heading, [], _score_text)


## "34 tiles (23%)" for the result list.
func _score_text(tiles: float) -> String:
	return Lang.f("paint_grab.tiles", [int(tiles),
			percent_of(int(tiles))])   # The percent is rounded down (REQ-PG-21).


## The share of the picture that `tiles` tiles are, in percent, rounded down (REQ-PG-21).
func percent_of(tiles: int) -> int:
	return tiles * 100 / maxi(_picture_total, 1)


# ---- Drawing ----

## The scale and the corner of the floor on the screen: it is as big as it fits inside the margin and under the HUD. A tile is a
## whole number of world pixels wide (a multiple of 4 units), so that all gaps between the tiles are equal (REQ-GM-47l).
func _fit() -> Dictionary:
	var avail := Vector2(size.x - 2.0 * BOARD_MARGIN, size.y - BOARD_TOP - BOARD_MARGIN)
	var fl := floor_map.size()
	var fit_k := minf(avail.x / fl.x, avail.y / fl.y)
	var pitch := maxf(floorf(REF_TILE * fit_k / Shell.WORLD_PIXEL) * Shell.WORLD_PIXEL, Shell.WORLD_PIXEL)
	var k := pitch / REF_TILE
	var origin := Vector2(BOARD_MARGIN + (avail.x - fl.x * k) * 0.5, BOARD_TOP + (avail.y - fl.y * k) * 0.5)
	return {"k": k, "origin": Shell.snap(origin)}


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
	for pot in _pots.pots:
		_draw_pot(ci, pot, origin, k)
	for s in _bodies:
		_draw_blob(ci, s, origin, k)


func _game_draw() -> void:
	var fit := _fit()
	var k: float = fit.k
	var origin: Vector2 = fit.origin
	_draw_hud()


## The rectangle of the tile `c` on the screen: one world pixel less than the pitch, so the gap between two tiles is one world
## pixel. A tile that pops is one world pixel wider on each side (REQ-PG-16, a hard step).
func _tile_rect(c: Vector2i, origin: Vector2, k: float, pop: bool) -> Rect2:
	var side := REF_TILE * k - TILE_GAP + (Shell.WORLD_PIXEL * 2.0 if pop else 0.0)
	return Rect2(origin + Vector2(c) * REF_TILE * k - Vector2.ONE * (Shell.WORLD_PIXEL if pop else 0.0), Vector2(side, side))


## A tile: flat, one world pixel apart from the next. A painted tile pops for a moment (REQ-PG-16).
func _draw_tile(ci: CanvasItem, c: Vector2i, origin: Vector2, k: float) -> void:
	var owner_slot := floor_map.owner_of(c)
	var rect := _tile_rect(c, origin, k, _pops[c.y * floor_map.cols + c.x] > 0.0)
	var part: int = _picture[c.y * floor_map.cols + c.x]
	if part == PaintPicture.EMPTY:
		ci.draw_rect(rect, OUTSIDE_TILE)
		return
	ci.draw_rect(rect, PaintLook.ghost(part, EMPTY_TILE) if owner_slot == PaintFloor.NONE
			else PaintLook.painted(part, player(owner_slot).color))


## A pot with a frame around the tiles it will paint: a patch of 3 x 3 for
## the gold pot, the row for the roller. A pot that is about to go away blinks (REQ-PG-23).
func _draw_pot(ci: CanvasItem, pot: PaintPots.Pot, origin: Vector2, k: float) -> void:
	if pot.is_blinking() and int(pot.age * 4.0) % 2 == 0:
		return
	var cells := PaintPots.bounds(pot.kind, pot.cell, floor_map.cols, floor_map.rows)
	var frame := Rect2(origin + Vector2(cells.position) * REF_TILE * k, Vector2(cells.size) * REF_TILE * k
			- Vector2.ONE * TILE_GAP)
	var color := PaintLook.GOLD_FRAME if pot.kind == PaintPots.GOLD else PaintLook.ROLLER_FRAME
	ci.draw_rect(frame, color, false, Shell.WORLD_PIXEL)
	if not _pot_textures.has(pot.kind):
		_pot_textures[pot.kind] = ImageTexture.create_from_image(PaintLook.pot_image(pot.kind))
	var tex: ImageTexture = _pot_textures[pot.kind]
	var sz := Vector2(tex.get_size()) * Shell.WORLD_PIXEL
	var center := origin + (Vector2(pot.cell) + Vector2(0.5, 0.5)) * REF_TILE * k
	ci.draw_texture_rect(tex, Rect2(Shell.snap(center - sz * 0.5), sz), false)


func _draw_blob(ci: CanvasItem, slot: int, origin: Vector2, k: float) -> void:
	var b: TiltBody = _bodies[slot]
	var center := origin + b.pos * k
	var radius := BLOB_R * k
	Shell.pixel_ball(ci, center, radius, player(slot).color)
	Shell.pixel_eyes(ci, center, radius, b.vel / b.max_speed)   # The pupils step to the side the blob rolls (REQ-PG-16).


func _scoreboard() -> Scoreboard:
	return _board


func _draw_hud() -> void:
	Shell.title(self, "registry.paint_grab")
	draw_leader_chip(self)
	Shell.timed_hud(self, size, _round, is_over, not participants.is_empty(), "paint_grab.tilt_phone_roll_paint", HINT_TIME)


func best_key() -> String:
	return "paint_grab|%s" % difficulty


## The personal best is the percent of the picture, so that a small and a big picture are fair (REQ-PG-31).
func best_value(score: float) -> int:
	return percent_of(int(score))
