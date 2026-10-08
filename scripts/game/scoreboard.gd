extends RefCounted
## The score of each player in a round, and the ranking (REQ-GM-70). Pure logic: it does not draw.
## Higher is better. For a time that must be small, make it with `lower_is_better`.
## Equal scores share a rank: 1, 1, 3 (REQ-GM-72). Players with the same rank are in slot order.

const ORDINALS := ["1st", "2nd", "3rd", "4th"]

var lower_is_better := false

var _scores := {}   # slot -> float


## `slots` are the players of the round. Each starts with 0.
func _init(slots: Array = [], p_lower_is_better := false) -> void:
	lower_is_better = p_lower_is_better
	for s in slots:
		_scores[int(s)] = 0.0


func has(slot: int) -> bool:
	return _scores.has(slot)


func size() -> int:
	return _scores.size()


func score(slot: int) -> float:
	return float(_scores.get(slot, 0.0))


func set_score(slot: int, value: float) -> void:
	_scores[slot] = value


func add(slot: int, points: float) -> void:
	_scores[slot] = score(slot) + points


## A player that left the game does not count in the ranking any more.
func remove(slot: int) -> void:
	_scores.erase(slot)


## Entries `{slot, score, rank}` from the best to the worst.
func ranking() -> Array:
	var slots: Array = _scores.keys()
	slots.sort_custom(func(a: int, b: int) -> bool:
		if is_equal_approx(_scores[a], _scores[b]):
			return a < b
		return _better(_scores[a], _scores[b]))
	var out: Array = []
	for i in slots.size():
		var s: int = slots[i]
		var rank := 1
		for other in slots:
			if _better(_scores[other], _scores[s]) and not is_equal_approx(_scores[other], _scores[s]):
				rank += 1
		out.append({"slot": s, "score": _scores[s], "rank": rank})
	return out


## The slots with rank 1. More than one slot means a tie. Empty when there is no player.
func winners() -> Array[int]:
	var out: Array[int] = []
	for e in ranking():
		if e.rank == 1:
			out.append(e.slot)
	return out


func _better(a: float, b: float) -> bool:
	return a < b if lower_is_better else a > b


## "1st", "2nd", "3rd", "4th" for a rank from 1 to 4.
static func ordinal(rank: int) -> String:
	return ORDINALS[clampi(rank, 1, ORDINALS.size()) - 1]


## A score for the screen: "12" for a whole number, "12.5" otherwise.
static func format(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
