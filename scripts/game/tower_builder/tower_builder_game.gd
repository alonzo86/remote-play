extends "res://scripts/game/minigame.gd"
## Tower Builder. All players build one tower together, one brick at a time, in turns (REQ-TB-1 to 4). A brick swings over the
## tower on a crane; the player whose turn it is presses A to drop it, or it drops by itself when the turn time of the
## difficulty is over (10 s Easy, 5 s Medium, 3 s Hard, REQ-TB-11). A brick that lands safely is a point for its player; a
## tower that topples ("wobble, crash, giggle") loses its upper bricks but nobody loses a point (REQ-TB-9, REQ-GM-83).
## 12 bricks are dropped in all (REQ-TB-3). The rules of the tower are in `tower_stack.gd`, the pictures in `tower_look.gd`.

const Stack = preload("res://scripts/game/tower_builder/tower_stack.gd")
const Look = preload("res://scripts/game/tower_builder/tower_look.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const FALL_SPEED := 1400.0            # A dropped brick falls this fast (px/s).
const GRAVITY := 2600.0
const SLIDE_SPEED := 320.0            # A fallen brick slides this fast (px/s) over the base, so that it leaves it (REQ-TB-9).
const WOBBLE_TIME := 0.7
const AFTER_SAFE := 0.6
const AFTER_MISS := 1.0
const AFTER_TOPPLED := 1.8
const HINT_TIME := 6.0
const BUZZ_GAP_MS := 150
const CHIP_Y := 940.0
const CHIP_GAP := 24.0
const CHIP_MARGIN := 60.0
const CHIP_Y_TWO_ROWS := 884.0         # Two rows of chips: the first row starts under the base, the second ends at the margin.
const CHIP_ROW_STEP := 72.0
const BANNER_FONT := 72
const INFO_FONT := 32
const INFO_X := 340.0                 # The middle of the plates at the left (turn, brick number).
const TIMER_X := Shell.TIMER_X
const TIMER_W := 240.0

enum Phase { TURN, FALL, WOBBLE, AFTER }

## Set before the game starts (REQ-GM-93). `start_props` keeps it for Restart.
var difficulty := "medium"
## A test sets a seed to get the same bricks every time; a negative seed is a random one.
var seed_value := -1

var stack := Stack.new()
var phase := Phase.TURN
var dropped := 0                  # Bricks dropped so far, also the ones that missed.
var banner_text := ""

var _board: Scoreboard
var _rng := RandomNumberGenerator.new()
var _order: Array[int] = []       # The slots in turn order.
var _cursor := 0                  # Index in `_order` of the player whose turn it is.
var _colors := {}                 # slot -> Color, kept after a player leaves (the bricks of the player stay).
var _brick_w := 200.0             # The width of the brick on the crane.
var _swing_t := 0.0
var _swing_phase := 0.0
var _turn_left := 0.0
var _advance := true              # False when the player of a finished turn left: the cursor is on the next player already.
var _release := false             # A was pressed by the player of the turn; it drops in the next tick.
var _falling := {}                # The brick that falls: {x, y, w, slot, target}.
var _pending: Array = []          # The bricks that fall off the tower after the wobble: {x, w, slot, level}.
var _rubble: Array[Dictionary] = []   # Bricks that lie or fall on the grass: {x, y, w, color, vx, vy, rest}.
var _phase_left := 0.0
var _last_outcome := -1           # Stack.Outcome of the last brick, for the wobble of a brick that stayed.
var _wobble_t := 0.0
var _time := 0.0
var _haptics := Haptics.new()


func _has_countdown() -> bool:
	return false   # The turn time is a limit of one drop, not a round clock (REQ-TB-11), so there is no 3 s countdown.


func _game_ready() -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_board = Scoreboard.new(participants)
	for s in participants:
		_order.append(s)
		_colors[s] = player(s).color
		player(s).button_pressed.connect(_on_button.bind(s))
	_begin_turn()


func _exit_tree() -> void:
	for s in participants:
		var cb := _on_button.bind(s)
		if player(s).button_pressed.is_connected(cb):
			player(s).button_pressed.disconnect(cb)


## The seconds a player has for one drop at this difficulty (REQ-TB-11).
func turn_time() -> float:
	return Stack.turn_time(difficulty)


## The slot of the player whose turn it is, or -1 when nobody is left.
func current_slot() -> int:
	return -1 if _order.is_empty() else _order[_cursor % _order.size()]


## The middle of the brick on the crane (REQ-TB-5): a smooth swing across the tower.
func swing_x() -> float:
	return Stack.swing_x(_swing_t, _swing_phase)


func _begin_turn() -> void:
	if dropped >= Stack.TOTAL_BRICKS or _order.is_empty():
		return
	phase = Phase.TURN
	_brick_w = Stack.next_width(_rng)
	_swing_t = 0.0
	_swing_phase = _rng.randf() * TAU
	_turn_left = turn_time()
	_release = false
	banner_text = ""
	var s := current_slot()
	_haptics.pulse(s, 100, BUZZ_GAP_MS)   # REQ-TB-13: the phone of the turn buzzes.
	player(s).recenter()


## REQ-TB-5: a press on A of the player of the turn drops the brick. A of anybody else does nothing.
func _on_button(bit: int, slot: int) -> void:
	if bit != Protocol.BTN_A or is_paused() or is_over or phase != Phase.TURN or slot != current_slot():
		return
	_release = true


func _on_player_left(slot: int) -> void:
	var i := _order.find(slot)
	var was_turn := i >= 0 and i == _cursor % _order.size()
	if i >= 0:
		_order.remove_at(i)
		if i < _cursor:
			_cursor -= 1
		if not _order.is_empty():
			_cursor %= _order.size()
		if was_turn and phase != Phase.TURN:
			_advance = false   # The cursor already points at the next player (REQ-TB-12).
	_board.remove(slot)
	if was_turn and phase == Phase.TURN and not _order.is_empty():
		_begin_turn()   # The player of the turn left: the next player gets a new brick at once (REQ-TB-12).


func _game_tick(delta: float) -> void:
	_time += delta
	_wobble_t += delta
	_tick_rubble(delta)
	if is_over:
		return
	match phase:
		Phase.TURN:
			_swing_t += delta
			_turn_left = maxf(_turn_left - delta, 0.0)
			if _release or _turn_left <= 0.0:
				_drop()
		Phase.FALL:
			_tick_fall(delta)
		Phase.WOBBLE:
			_phase_left -= delta
			if _phase_left <= 0.0:
				_topple()
		Phase.AFTER:
			_phase_left -= delta
			if _phase_left <= 0.0:
				if _order.is_empty():
					return
				if dropped >= Stack.TOTAL_BRICKS:
					_finish()
				else:
					if _advance:
						_cursor = (_cursor + 1) % _order.size()
					_advance = true
					_begin_turn()


## REQ-TB-5, 6: the brick leaves the crane. Where it lands is known now (the rules are pure), the result applies on landing.
func _drop() -> void:
	var s := current_slot()
	var x := swing_x()
	var lands := stack.lands(x, _brick_w)
	var target := Stack.level_top(stack.height())   # A brick that misses falls to the top of the tower, then tumbles off.
	_falling = {"x": x, "y": Look.HANG_Y - Stack.BRICK_H * 0.5, "w": _brick_w, "slot": s, "target": target}
	phase = Phase.FALL
	_release = false
	_haptics.pulse(s, 30, BUZZ_GAP_MS)
	Sound.sfx("tower_drop")


func _tick_fall(delta: float) -> void:
	_falling.y += FALL_SPEED * delta
	if float(_falling.y) < float(_falling.target):
		return
	_falling.y = _falling.target
	_land()


## REQ-TB-6 to 9: the brick has landed. It stays (a point), it misses, or the tower topples.
func _land() -> void:
	var s: int = _falling.slot
	var res := stack.drop(float(_falling.x), float(_falling.w), s)
	dropped += 1
	_last_outcome = int(res.outcome)
	match _last_outcome:
		Stack.Outcome.SAFE:
			_board.add(s, 1.0)
			_phase_left = AFTER_SAFE
			_wobble_t = 0.0
			phase = Phase.AFTER
			_haptics.pulse(s, 60, BUZZ_GAP_MS)
			Sound.sfx("tower_land")
		Stack.Outcome.MISS:
			var top_x := Stack.BASE_X if stack.bricks.is_empty() else float(stack.bricks[-1].x)   # The first brick can miss the base too.
			var dir := 1.0 if float(_falling.x) >= top_x else -1.0
			_add_rubble(float(_falling.x), float(_falling.y), float(_falling.w), s, dir * SLIDE_SPEED, 0.0, false)
			banner_text = Lang.t("tower_builder.missed")
			_phase_left = AFTER_MISS
			phase = Phase.AFTER
			_haptics.pulse(s, 40, BUZZ_GAP_MS)
			Sound.sfx("tower_miss")
		_:
			_pending = []
			for i in (res.fallen as Array).size():
				var b: Dictionary = res.fallen[i]
				_pending.append({"x": b.x, "w": b.w, "slot": b.slot, "level": int(res.level) + i})
			banner_text = Lang.t("tower_builder.crash")
			_wobble_t = 0.0
			_phase_left = WOBBLE_TIME
			phase = Phase.WOBBLE
			Sound.sfx("tower_wobble")
	_falling = {}


## REQ-TB-9: the wobble is over, the bricks above the weak joint fall off the tower and lie on the grass.
func _topple() -> void:
	var dir := 1.0
	for i in _pending.size():
		var b: Dictionary = _pending[i]
		dir = 1.0 if float(b.x) >= Stack.BASE_X else -1.0
		_add_rubble(float(b.x), Stack.level_top(int(b.level)), float(b.w), int(b.slot), dir * (SLIDE_SPEED + 60.0 * float(i % 3)),
				-260.0, false)
	_pending = []
	for s in participants:
		_haptics.pulse(s, 80, BUZZ_GAP_MS)
	Sound.sfx("tower_crash")
	_phase_left = AFTER_TOPPLED
	phase = Phase.AFTER


func _add_rubble(x: float, top: float, w: float, slot: int, vx: float, vy: float, rest: bool) -> void:
	_rubble.append({"x": x, "y": top, "w": w, "color": _colors.get(slot, UiTheme.TEXT), "vx": vx, "vy": vy, "rest": rest})
	if _rubble.size() > 24:
		_rubble.remove_at(0)


func _tick_rubble(delta: float) -> void:
	for r in _rubble:
		if bool(r.rest):
			continue
		r.vy = float(r.vy) + GRAVITY * delta
		r.x = float(r.x) + float(r.vx) * delta
		r.y = float(r.y) + float(r.vy) * delta
		# Over the base a brick lands on it and slides on to the edge; beside the base it lands on the grass (REQ-TB-9).
		var over_base := absf(float(r.x) - Stack.BASE_X) < (Stack.BASE_W + float(r.w)) * 0.5 - 8.0
		var floor_y := Stack.GROUND_Y if over_base else Look.RUBBLE_Y
		if float(r.y) + Stack.BRICK_H >= floor_y:
			r.y = floor_y - Stack.BRICK_H
			r.vy = 0.0
			r.rest = not over_base


func _finish() -> void:
	for s in _board.winners():
		App.server.haptic(s, 400)
	open_results(_board, "", [], bricks_text)


## "3 bricks" for the result list.
func bricks_text(score: float) -> String:
	return Lang.t("tower_builder.one_brick") if int(score) == 1 else Lang.f("tower_builder.n_bricks", [int(score)])


func _scoreboard() -> Scoreboard:
	return _board


# ---- Drawing ----

func _pixel_world() -> bool:
	return true


## How far the brick at `level` leans to the side while the tower wobbles (REQ-TB-9): the higher the brick, the more.
func wobble_offset(level: int, height: int) -> float:
	var strength := 0.0
	if phase == Phase.WOBBLE:
		strength = 14.0
	elif phase == Phase.AFTER and _last_outcome == Stack.Outcome.SAFE and _wobble_t < AFTER_SAFE and stack.height() > 2:
		strength = 5.0 * (1.0 - _wobble_t / AFTER_SAFE)
	if height <= 1:
		return 0.0
	return roundf(sin(_wobble_t * 28.0) * strength * float(level) / float(height - 1) / Shell.WORLD_PIXEL) * Shell.WORLD_PIXEL


func _world_draw(ci: CanvasItem) -> void:
	Look.draw_scene(ci, size, _time)
	Look.draw_base(ci)
	var h := stack.height()
	for i in h:
		var b: Dictionary = stack.bricks[i]
		var rect := Look.brick_rect(i, float(b.x) + wobble_offset(i, h), float(b.w))
		Look.draw_brick(ci, rect, _colors.get(int(b.slot), UiTheme.TEXT))
	if phase == Phase.WOBBLE:
		var total := h + _pending.size()
		for b in _pending:
			var rect := Look.brick_rect(int(b.level), float(b.x) + wobble_offset(int(b.level), total), float(b.w))
			Look.draw_brick(ci, rect, _colors.get(int(b.slot), UiTheme.TEXT))
	for r in _rubble:
		Look.draw_brick(ci, Rect2(Shell.snap(Vector2(float(r.x) - float(r.w) * 0.5, float(r.y))), Vector2(float(r.w), Stack.BRICK_H)),
				r.color)
	var slot := current_slot()
	if phase == Phase.TURN and slot >= 0:
		var x := swing_x()
		var top := Look.HANG_Y - Stack.BRICK_H * 0.5
		Look.draw_crane(ci, x, top)
		var rect := Rect2(Shell.snap(Vector2(x - _brick_w * 0.5, top)), Vector2(_brick_w, Stack.BRICK_H))
		Look.draw_brick(ci, rect, _colors.get(slot, UiTheme.TEXT))
	elif phase == Phase.FALL:
		Look.draw_crane(ci, Stack.BASE_X, Look.HANG_Y - Stack.BRICK_H * 0.5)
		Look.draw_brick(ci, Rect2(Shell.snap(Vector2(float(_falling.x) - float(_falling.w) * 0.5, float(_falling.y))),
				Vector2(float(_falling.w), Stack.BRICK_H)), _colors.get(int(_falling.slot), UiTheme.TEXT))
	else:
		Look.draw_crane(ci, Stack.BASE_X, Look.HANG_Y - Stack.BRICK_H * 0.5)
	Look.draw_ruler(ci, h, Stack.TOTAL_BRICKS)


func _game_draw() -> void:
	Shell.title(self, "registry.tower_builder")
	draw_leader_chip(self)
	if not is_over:
		Shell.timer(self, Vector2(TIMER_X, 36.0), _turn_left if phase == Phase.TURN else turn_time(), TIMER_W)
		var slot := current_slot()
		if slot >= 0:
			Shell.label_plate(self, Vector2(Shell.mx(self, INFO_X, 0.0), 300.0),
					Lang.f("tower_builder.turn_of", [player(slot).player_name]), INFO_FONT, _colors.get(slot, UiTheme.TEXT))
		Shell.label_plate(self, Vector2(Shell.mx(self, INFO_X, 0.0), 380.0),
				Lang.f("tower_builder.brick_n_of", [mini(dropped + 1, Stack.TOTAL_BRICKS), Stack.TOTAL_BRICKS]), INFO_FONT, UiTheme.TEXT)
		if banner_text != "" and phase != Phase.TURN:
			Shell.label_plate(self, Vector2(size.x * 0.5, size.y * 0.5 + 24.0), banner_text, BANNER_FONT, UiTheme.ACCENT)
		if dropped == 0 and phase == Phase.TURN and _time < HINT_TIME:
			var top := CHIP_Y
			for r in chip_rects():
				top = minf(top, r.position.y)
			Shell.hint(self, size, "tower_builder.hint", top - 16.0)   # Above the chips, not over them (issue #223).
	_draw_chips()


## The rectangle of the chip of each player, in the order of `participants` (REQ-TB-19): one row along the bottom, centered;
## when the names are so long that the row does not fit inside the 60 px margins, two chips in each row and two rows.
func chip_rects() -> Array[Rect2]:
	var widths: Array[float] = []
	var total := 0.0
	for s in participants:
		var p := player(s)
		var w := Shell.score_chip_width(p.player_name, str(int(_board.score(s))), 64.0, 250.0, Shell.CHIP_FONT, p.avatar)
		widths.append(w)
		total += w + CHIP_GAP
	var avail := size.x - 2.0 * CHIP_MARGIN
	var per_row := widths.size() if total - CHIP_GAP <= avail else 2
	var rows := ceili(float(widths.size()) / float(per_row))
	var out: Array[Rect2] = []
	for row in rows:
		var first := row * per_row
		var last := mini(first + per_row, widths.size())
		var row_w := -CHIP_GAP
		for i in range(first, last):
			row_w += widths[i] + CHIP_GAP
		var x := (size.x - row_w) * 0.5
		var y := CHIP_Y if rows == 1 else CHIP_Y_TWO_ROWS + float(row) * CHIP_ROW_STEP
		for i in range(first, last):
			out.append(Rect2(Shell.mx(self, x, widths[i]), y, widths[i], 64.0))
			x += widths[i] + CHIP_GAP
	return out


## One chip for each player with the bricks that stayed; the player of the turn has a white frame.
func _draw_chips() -> void:
	var rects := chip_rects()
	for i in participants.size():
		var s: int = participants[i]
		var p := player(s)
		var r := Shell.score_chip(self, rects[i].position, p.player_name, str(int(_board.score(s))), p.color, rects[i].size.x, 64.0,
				p.avatar)
		if s == current_slot() and not is_over:
			draw_rect(r.grow(8.0), UiTheme.TEXT, false, 4.0)
