extends RefCounted
## The score of each player in a round, and the ranking (REQ-GM-70). Pure logic: it does not draw.
## Higher is better. For a time that must be small, make it with `lower_is_better`.
## Equal scores share a rank: 1, 1, 3 (REQ-GM-72). Players with the same rank are in slot order.
## A player who has not finished (a race that ended before the line) has no score. `set_unfinished()` gives only how far the
## player got. Such players rank after all players with a score, the furthest first.

const Lang = preload("res://scripts/core/lang.gd")

const ORDINALS := ["result.place_1", "result.place_2", "result.place_3", "result.place_4"]

var lower_is_better := false

var _scores := {}     # slot -> float, for the players with a score
var _progress := {}   # slot -> float, for the players without a score


## `slots` are the players of the round. Each starts with 0.
func _init(slots: Array = [], p_lower_is_better := false) -> void:
	lower_is_better = p_lower_is_better
	for s in slots:
		_scores[int(s)] = 0.0


func has(slot: int) -> bool:
	return _scores.has(slot) or _progress.has(slot)


func size() -> int:
	return _scores.size() + _progress.size()


## True when the player has a score (not `set_unfinished()`). Only the tests call it; it is part of the model of a race.
func is_finished(slot: int) -> bool:
	return _scores.has(slot)


func score(slot: int) -> float:
	return float(_scores.get(slot, 0.0))


func set_score(slot: int, value: float) -> void:
	_progress.erase(slot)
	_scores[slot] = value


## The player has no score. `progress` is how far the player got: a higher number is further.
func set_unfinished(slot: int, progress: float) -> void:
	_scores.erase(slot)
	_progress[slot] = progress


func add(slot: int, points: float) -> void:
	_scores[slot] = score(slot) + points


## A player that left the game does not count in the ranking any more.
func remove(slot: int) -> void:
	_scores.erase(slot)
	_progress.erase(slot)


## Entries `{slot, score, rank, finished}` from the best to the worst. An unfinished player has `finished` false and
## score 0. Its rank counts all players ahead, so 1st finished and two unfinished players give ranks 1, 2, 2.
func ranking() -> Array:
	var done: Array = _scores.keys()
	done.sort_custom(func(a: int, b: int) -> bool:
		if is_equal_approx(_scores[a], _scores[b]):
			return a < b
		return _better(_scores[a], _scores[b]))
	var out: Array = []
	for s in done:
		var rank := 1
		for other in done:
			if _better(_scores[other], _scores[s]) and not is_equal_approx(_scores[other], _scores[s]):
				rank += 1
		out.append({"slot": s, "score": _scores[s], "rank": rank, "finished": true})
	var rest: Array = _progress.keys()
	rest.sort_custom(func(a: int, b: int) -> bool:
		if is_equal_approx(_progress[a], _progress[b]):
			return a < b
		return _progress[a] > _progress[b])
	for s in rest:
		var rank := done.size() + 1
		for other in rest:
			if _progress[other] > _progress[s] and not is_equal_approx(_progress[other], _progress[s]):
				rank += 1
		out.append({"slot": s, "score": 0.0, "rank": rank, "finished": false})
	return out


## The finished slots with rank 1. More than one slot means a tie. Empty when nobody has a score.
func winners() -> Array[int]:
	var out: Array[int] = []
	for e in ranking():
		if e.rank == 1 and e.finished:
			out.append(e.slot)
	return out


## The entries of `ranking()` with rank 1. More than one means a tie. A player without a score counts, so a race shows who leads
## before anyone finishes. Empty when there is no player.
func leaders() -> Array:
	return ranking().filter(func(e: Dictionary) -> bool: return e.rank == 1)


## True when the leader chip has something to say (REQ-GM-46): a leader with a score above 0, a time, or one unfinished player
## ahead of the others. False while everybody is level at 0 (or level before a race starts) and when nobody is ranked.
func has_lead() -> bool:
	var lead := leaders()
	if lead.is_empty():
		return false
	if not lead[0].finished:
		return lead.size() == 1
	return lower_is_better or lead[0].score > 0.0


func _better(a: float, b: float) -> bool:
	return a < b if lower_is_better else a > b


## "1st", "2nd", "3rd", "4th" for a rank from 1 to 4.
static func ordinal(rank: int) -> String:
	return Lang.t(ORDINALS[clampi(rank, 1, ORDINALS.size()) - 1])


## A score for the screen: "12" for a whole number, "12.5" otherwise.
static func format(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
