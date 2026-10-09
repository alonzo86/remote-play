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
const POP_TIME := 0.15          # A painted tile grows and goes back in this time (REQ-PG-16).
const HINT_TIME := 4.0
const BOARD_TOP := 150.0        # The floor is the screen inside the margin, under the HUD.
const BOARD_MARGIN := 60.0
const TIMER_X := 560.0
const TIMER_W := 160.0
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

# Look (REQ-PG-15, REQ-GM-47). The floor is dark so that every player color has a contrast of 3:1 or more.
const BACKGROUND := Color("0f6a78")
const FLOOR_COLOR := Color("2a1070")
const EMPTY_TILE := Color("3a1c97")
const TILE_GAP := 4.0

## Set before the game starts (REQ-GM-93). `start_props` keeps it for Restart.
var difficulty := "medium"

var floor_map: PaintFloor
var _round := RoundClock.new(COUNTDOWN, ROUND_TIME)
var _board: Scoreboard
var _bodies := {}                 # slot -> TiltBody
var _haptics := Haptics.new()
var _pops := PackedFloat32Array()  # The time left of the pop of each tile.
var _level := {}
var _sb_board: StyleBoxFlat


func _game_ready() -> void:
	_level = LEVELS.get(difficulty, LEVELS.medium)
	floor_map = PaintFloor.new(int(_level.cols), int(_level.rows), REF_TILE)
	_pops.resize(floor_map.cols * floor_map.rows)
	_pops.fill(0.0)
	_sb_board = UiTheme.card(FLOOR_COLOR, UiTheme.OUTLINE, UiTheme.OUTLINE_W, 30, true)
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
		b.step(delta, player(s).tilt(), bounds)
	var list: Array = _bodies.values()
	for i in list.size():
		for j in range(i + 1, list.size()):
			TiltBody.collide(list[i], list[j])
	for s in _bodies:
		_paint_under(s)
	for i in _pops.size():
		if _pops[i] > 0.0:
			_pops[i] = maxf(_pops[i] - delta, 0.0)
	if _round.is_time_up():
		_finish()


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
		heading = "%s (%s)" % [Medals.label(medal), difficulty.capitalize()]
	open_results(_board, [], heading, [], _score_text)


## "34 tiles (23%)" for the result list.
func _score_text(tiles: float) -> String:
	return "%d tiles (%d%%)" % [int(tiles), int(tiles) * 100 / floor_map.total()]


# ---- Drawing ----

## The scale and the corner of the floor on the screen: it is as big as it fits inside the margin and under the HUD.
func _fit() -> Dictionary:
	var avail := Vector2(size.x - 2.0 * BOARD_MARGIN, size.y - BOARD_TOP - BOARD_MARGIN)
	var fl := floor_map.size()
	var k := minf(avail.x / fl.x, avail.y / fl.y)
	return {"k": k, "origin": Vector2(BOARD_MARGIN + (avail.x - fl.x * k) * 0.5, BOARD_TOP + (avail.y - fl.y * k) * 0.5)}


func _game_draw() -> void:
	var fit := _fit()
	var k: float = fit.k
	var origin: Vector2 = fit.origin
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_style_box(_sb_board, Rect2(origin, floor_map.size() * k).grow(12.0))
	for r in floor_map.rows:
		for c in floor_map.cols:
			_draw_tile(Vector2i(c, r), origin, k)
	for s in _bodies:
		_draw_blob(s, origin, k)
	_draw_hud()


func _draw_tile(c: Vector2i, origin: Vector2, k: float) -> void:
	var owner_slot := floor_map.owner_of(c)
	var pop := _pops[c.y * floor_map.cols + c.x] / POP_TIME
	var grow := 1.0 + 0.15 * pop
	var side := (REF_TILE - TILE_GAP) * k * grow
	var middle := origin + (Vector2(c) + Vector2(0.5, 0.5)) * REF_TILE * k
	var rect := Rect2(middle - Vector2(side, side) * 0.5, Vector2(side, side))
	if owner_slot == PaintFloor.NONE:
		draw_rect(rect, EMPTY_TILE)
		return
	var col: Color = player(owner_slot).color
	draw_rect(rect, col)
	draw_rect(Rect2(rect.position, Vector2(side, side * 0.22)), col.lightened(0.3))   # A lighter top edge.


func _draw_blob(slot: int, origin: Vector2, k: float) -> void:
	var b: TiltBody = _bodies[slot]
	var center := origin + b.pos * k
	var radius := BLOB_R * k
	Shell.ball(self, center, radius, player(slot).color, slot)
	# Two eyes that look the way the blob rolls (REQ-PG-16).
	var look := b.vel.limit_length(b.max_speed) / b.max_speed
	for sign_x in [-1.0, 1.0]:
		var e := center + Vector2(sign_x * radius * 0.42, -radius * 0.52)
		draw_circle(e, radius * 0.24, UiTheme.OUTLINE)
		draw_circle(e, radius * 0.19, Color.WHITE)
		draw_circle(e + look * radius * 0.08, radius * 0.09, UiTheme.OUTLINE)


func _draw_hud() -> void:
	Shell.title(self, "PAINT GRAB")
	var scores := {}
	for slot in participants:
		scores[slot] = str(floor_map.count(slot))
	Shell.player_chips(self, size.x, participants.map(func(s: int) -> Object: return player(s)), scores,
			size.x - 60.0 - (TIMER_X + TIMER_W + 20.0))
	if _round.is_playing() and not is_over:
		Shell.timer(self, Vector2(TIMER_X, 36.0), _round.remaining(), TIMER_W)
	if _round.is_counting() and not participants.is_empty():
		var n := _round.count_number()
		Shell.countdown(self, size, str(n) if n > 0 else "GO", _round.count_elapsed())
	if _round.time < HINT_TIME and not is_over:
		Shell.hint(self, size, "Tilt your phone to roll and paint the tiles!")
