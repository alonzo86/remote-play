extends RefCounted
## The rules of Bowling (REQ-BW-1 to 3): ten-pin bowling for 1 to 4 players. It keeps the rolls of each player, the turn order
## (frame by frame, in slot order inside a frame), the standing pins of the rack and the score sheet. Pure logic: it draws
## nothing and uses no nodes, so the rules can be tested without a screen.

const FRAMES := 10
const PINS := 10

## One player: the rolls (pins knocked down by each ball), the place in the game and the pins that stand now.
class Row:
	var slot := 0
	var rolls: Array[int] = []
	var frame := 1          # The frame of the next ball (1 to FRAMES). It is FRAMES + 1 when the player is done.
	var ball := 1           # The ball of the next roll in this frame (1 to 3).
	var standing := PINS    # Pins that stand before the next ball.
	# The rack is full and a clear of it counts as a strike (the first ball, or a new rack in the 10th frame).
	var fresh := true

	func done() -> bool:
		return frame > FRAMES


var rows: Array[Row] = []
var _turn := 0       # Index of the row on turn.
var _frame := 1      # The frame that is bowled now by all players.


## Starts a game for these slots, in slot order.
func setup(slots: Array[int]) -> void:
	rows.clear()
	for s in slots:
		var r := Row.new()
		r.slot = s
		rows.append(r)
	_turn = 0
	_frame = 1


func row_of(slot: int) -> Row:
	for r in rows:
		if r.slot == slot:
			return r
	return null


func slots() -> Array[int]:
	var out: Array[int] = []
	for r in rows:
		out.append(r.slot)
	return out


## True when every player has bowled the last ball of the last frame (REQ-BW-1). With nobody left the game is over too.
func game_over() -> bool:
	for r in rows:
		if not r.done():
			return false
	return true


## The slot that bowls now, or -1 when the game is over.
func current_slot() -> int:
	if game_over():
		return -1
	return rows[_turn].slot


func current_frame() -> int:
	return mini(_frame, FRAMES)


func current_ball() -> int:
	return -1 if game_over() else rows[_turn].ball


## The pins that stand before the next ball of the player on turn.
func pins_standing() -> int:
	return 0 if game_over() else rows[_turn].standing


## Records the pins that the ball of the player on turn knocked down and moves on. The count is limited to the standing pins.
## Returns what happened: {slot, frame, ball, pins, strike, spare, fresh_rack (the rack is set again for the next ball),
## frame_done, game_over}.
func record_roll(pins: int) -> Dictionary:
	assert(not game_over())
	var r := rows[_turn]
	var n := clampi(pins, 0, r.standing)
	var ev := {"slot": r.slot, "frame": r.frame, "ball": r.ball, "pins": n, "strike": r.fresh and n == PINS,
			"spare": not r.fresh and n == r.standing and n > 0, "fresh_rack": false, "frame_done": false, "game_over": false}
	r.rolls.append(n)
	if r.frame < FRAMES:
		if r.ball == 1 and not ev.strike:
			r.standing -= n
			r.fresh = false
			r.ball = 2
		else:
			_finish_frame(r, ev)
	else:
		_roll_last_frame(r, n, ev)
	if ev.frame_done:
		_next_turn()
	ev.game_over = game_over()
	return ev


## The 10th frame has 2 or 3 balls: after a strike or a spare there is one more, with a fresh rack when all pins fell.
func _roll_last_frame(r: Row, n: int, ev: Dictionary) -> void:
	var cleared: bool = n == r.standing
	var bonus: bool = r.rolls.size() >= 1 and frame_rolls(r.rolls, FRAMES)[0] == PINS
	if cleared:
		r.standing = PINS
		r.fresh = true
		ev.fresh_rack = true
	else:
		r.standing -= n
		r.fresh = false
	if r.ball == 1:
		r.ball = 2
	elif r.ball == 2 and (bonus or cleared):
		r.ball = 3
	else:
		_finish_frame(r, ev)


func _finish_frame(r: Row, ev: Dictionary) -> void:
	ev.frame_done = true
	ev.fresh_rack = true
	r.frame += 1
	r.ball = 1
	r.standing = PINS
	r.fresh = true


## The rolls of a frame of a row, taken from the list of all rolls.
static func frame_rolls(rolls: Array[int], frame: int) -> Array[int]:
	var i := 0
	for f in range(1, frame):
		i += 1 if i < rolls.size() and rolls[i] == PINS else 2
	var out: Array[int] = []
	var count := 3 if frame == FRAMES else (1 if i < rolls.size() and rolls[i] == PINS else 2)
	for k in count:
		if i + k < rolls.size():
			out.append(rolls[i + k])
	return out


func _next_turn() -> void:
	_pick_turn((_turn + 1) % rows.size())


## The turn goes to the first player, from `start` on, who has not bowled the frame of the game yet. When every player has,
## the next frame starts with the first player (the standard order, REQ-BW-3).
func _pick_turn(start: int) -> void:
	for step in rows.size():
		var idx := (start + step) % rows.size()
		if rows[idx].frame <= _frame and not rows[idx].done():
			_turn = idx
			return
	_frame += 1
	for idx in rows.size():
		if not rows[idx].done():
			_turn = idx
			return
	_turn = 0


## A player leaves (REQ-BW-3). The turn goes on with the next player when it was the turn of the one who left.
func remove_player(slot: int) -> void:
	var idx := -1
	for i in rows.size():
		if rows[i].slot == slot:
			idx = i
	if idx < 0:
		return
	var on_turn := idx == _turn
	rows.remove_at(idx)
	if rows.is_empty():
		_turn = 0
	elif on_turn:
		_pick_turn(idx % rows.size())
	elif idx < _turn:
		_turn -= 1


# ---- The score sheet ----

## The total score of a list of rolls so far: the frames that are done, with the bonuses that are known.
static func total_of(rolls: Array[int]) -> int:
	var cells := sheet_cells(rolls)
	var best := 0
	for c in cells:
		if c.total >= 0:
			best = c.total
	return best


## The cells of a score sheet for a list of rolls: one dictionary for each frame, {marks: Array[String], total: int}. `total` is
## the running total after the frame, or -1 when the frame has no score yet (a strike or a spare waits for its bonus balls).
static func sheet_cells(rolls: Array[int]) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	var i := 0
	var total := 0
	for f in range(1, FRAMES + 1):
		var cell := {"marks": [] as Array[String], "total": -1}
		if i >= rolls.size():
			cells.append(cell)
			continue
		if f < FRAMES:
			if rolls[i] == PINS:
				cell.marks.append("X")
				if i + 2 < rolls.size():
					total += PINS + rolls[i + 1] + rolls[i + 2]
					cell.total = total
				i += 1
			else:
				cell.marks.append(_mark(rolls[i]))
				if i + 1 < rolls.size():
					cell.marks.append("/" if rolls[i] + rolls[i + 1] == PINS else _mark(rolls[i + 1]))
					if rolls[i] + rolls[i + 1] == PINS:
						if i + 2 < rolls.size():
							total += PINS + rolls[i + 2]
							cell.total = total
					else:
						total += rolls[i] + rolls[i + 1]
						cell.total = total
				i += 2
		else:
			var last: Array[int] = []
			last.assign(rolls.slice(i))
			var sum := 0
			for v in last:
				sum += v
			cell.marks = last_frame_marks(last)
			var complete := last.size() == 3 or (last.size() == 2 and last[0] != PINS and last[0] + last[1] < PINS)
			if complete:
				total += sum
				cell.total = total
		cells.append(cell)
	return cells


## The marks of the 10th frame: a strike is "X" when the rack was full, "/" is a spare, else the pins ("-" for none).
static func last_frame_marks(last: Array[int]) -> Array[String]:
	var out: Array[String] = []
	var fresh := true
	var standing := PINS
	for v in last:
		if fresh and v == PINS:
			out.append("X")
		elif not fresh and v == standing and v > 0:
			out.append("/")
		else:
			out.append(_mark(v))
		if v == standing:
			standing = PINS
			fresh = true
		else:
			standing -= v
			fresh = false
	return out


static func _mark(n: int) -> String:
	return "-" if n == 0 else str(n)


## The score of a player so far (REQ-BW-2).
func score_of(slot: int) -> int:
	var r := row_of(slot)
	return total_of(r.rolls) if r != null else 0


# ---- Difficulty (REQ-BW-17) ----

## What Difficulty means (first guesses, test 23): `threshold` is a factor
## on the
## swing thresholds (a lower one counts a lighter swing), the ball speed is `fixed_speed` of the top speed on Easy and from
## `speed_min` to 1 of it with the swing power on the others.
const LEVELS := {
	"easy": {"threshold": 0.6, "fixed_speed": 0.8},
	"medium": {"threshold": 0.75, "speed_min": 0.7},
	"hard": {"threshold": 0.75, "speed_min": 0.5},
}


static func level(difficulty: String) -> Dictionary:
	return LEVELS.get(difficulty, LEVELS.medium)


## The speed of the ball (m/s) for a swing power of 0 to 1 (REQ-BW-6).
static func ball_speed(difficulty: String, power: float, top_speed: float) -> float:
	var lv := level(difficulty)
	if lv.has("fixed_speed"):
		return top_speed * float(lv.fixed_speed)
	return top_speed * lerpf(float(lv.speed_min), 1.0, clampf(power, 0.0, 1.0))
