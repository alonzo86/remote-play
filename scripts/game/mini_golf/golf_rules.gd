extends RefCounted
## The rules of Mini Golf (REQ-MG-1 to 8, 14): the players putt in turns, one putt each, in slot order, until every ball is in
## the cup or picked up. It keeps the strokes of each player on each hole and the turn order. Pure logic: it draws nothing and
## uses no nodes, so the rules can be tested without a screen.

const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")

const MAX_STROKES := 6   # REQ-MG-8: after this many strokes the ball is picked up and the hole counts this many.
const MIN_HOLES := 1
const DEFAULT_HOLES := 3

enum State { PLAY, IN, PICKED }

## One player: the strokes on the holes that are done, the strokes on this hole and what happens to the ball.
class Row:
	var slot := 0
	var done: Array[int] = []
	var strokes := 0
	var state := State.PLAY

	func finished() -> bool:
		return state != State.PLAY

var rows: Array[Row] = []
var holes := DEFAULT_HOLES   # How many holes the match has.
var _hole := 1               # The hole that is played now (1 to holes).
var _turn := 0               # Index of the row on turn.


## Starts a match for these slots, in slot order, with `p_holes` holes (1 to Holes.COUNT).
func setup(slots: Array[int], p_holes: int) -> void:
	holes = clampi(p_holes, MIN_HOLES, Holes.COUNT)
	rows.clear()
	for s in slots:
		var r := Row.new()
		r.slot = s
		rows.append(r)
	_hole = 1
	_turn = 0


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


## The hole that is played now, 1 to `holes`.
func hole_number() -> int:
	return _hole


func par() -> int:
	return int(Holes.hole(_hole).par)


## The slot on turn, or -1 when nobody putts: every ball is in or picked up (the hole is done), or nobody is left.
func current_slot() -> int:
	if _hole_over():
		return -1
	return rows[_turn].slot


func _hole_over() -> bool:
	for r in rows:
		if not r.finished():
			return false
	return true


func hole_done() -> bool:
	return _hole_over()


func strokes_on_hole(slot: int) -> int:
	var r := row_of(slot)
	return r.strokes if r != null else 0


## The strokes of a player over the holes that are done and the one that is played (REQ-MG-6).
func total(slot: int) -> int:
	var r := row_of(slot)
	if r == null:
		return 0
	var sum := r.strokes
	for s in r.done:
		sum += s
	return sum


## The strokes of the holes that are done only.
func done_total(slot: int) -> int:
	var r := row_of(slot)
	var sum := 0
	if r != null:
		for s in r.done:
			sum += s
	return sum


## One putt of the player on turn is over (REQ-MG-2, 6, 8): `in_cup` says whether the ball is in the cup. The result:
## `slot`, `strokes` (on this hole), `in` (the ball is in), `picked` (the ball was picked up after MAX_STROKES), `hole_done`
## (nobody putts any more on this hole) and `label` (a text key, see `label_for()`, or "" for a plain number).
func putt_done(in_cup: bool) -> Dictionary:
	var slot := current_slot()
	if slot < 0:
		return {}
	var r := rows[_turn]
	r.strokes += 1
	var picked := false
	if in_cup:
		r.state = State.IN
	elif r.strokes >= MAX_STROKES:
		r.state = State.PICKED
		picked = true
	var ev := {"slot": slot, "strokes": r.strokes, "in": in_cup, "picked": picked, "hole_done": _hole_over(),
			"label": label_for(r.strokes, par()) if in_cup else ""}
	_advance()
	return ev


func _advance() -> void:
	for i in range(1, rows.size() + 1):
		var j := (_turn + i) % rows.size()
		if not rows[j].finished():
			_turn = j
			return


## The words for a hole of `strokes` on a hole of `par` (REQ-MG-6): a text key, or "" for the plain number.
static func label_for(strokes: int, hole_par: int) -> String:
	if strokes == 1:
		return "mini_golf.hole_in_one"
	if strokes < hole_par:
		return "mini_golf.birdie"
	if strokes == hole_par:
		return "mini_golf.par"
	if strokes == hole_par + 1:
		return "mini_golf.bogey"
	return ""


## Moves to the next hole. The strokes of the hole that ended are kept. Returns false, and changes nothing, when this was the
## last hole (the match is over, `match_over()`).
func next_hole() -> bool:
	if _hole >= holes:
		return false
	for r in rows:
		r.done.append(r.strokes)
		r.strokes = 0
		r.state = State.PLAY
	_hole += 1
	_turn = 0
	return true


## A player that left: the strokes go away with the row (REQ-MG-11). The turn passes to the next player when it was the turn of
## the one who left.
func remove_player(slot: int) -> void:
	for i in rows.size():
		if rows[i].slot == slot:
			rows.remove_at(i)
			if rows.is_empty():
				_turn = 0
			elif i < _turn:
				_turn -= 1
			elif i == _turn:
				_turn = _turn % rows.size()
				if not _hole_over() and rows[_turn].finished():
					_advance()
			return


## True when the match is over: the last hole is done (REQ-MG-7) or nobody is left.
func match_over() -> bool:
	return rows.is_empty() or (_hole >= holes and _hole_over())
