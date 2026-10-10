extends RefCounted
## The best score keys of the personal bests (FD-22, docs/PROFILES_PLAN.md 5 and 6.1). A key is the text a game gives
## (`Minigame.best_key()`); its number is what a profile code stores (one byte). A number is never changed or reused: a new
## game or a changed track set adds numbers at the end. The direction (a lower time or a higher score is better) belongs to
## the key and is never sent: a code or a message cannot change it.
##
## Numbers: 1 to 3 Snowball Splat (easy, medium, hard), 4 to 6 Paint Grab, 7 to 36 Marble Race: 7 + 10 * difficulty + (track - 1).
## Tilt Maze, Sumo Bumpers and a random Marble Race track have no key (the owner, 2026-10-10).

const DIFFICULTIES: Array[String] = ["easy", "medium", "hard"]
const TRACKS := 10
const MAX_KEYS := 39   # What a code can hold (plan 6.1). The table has 36.

static var _keys: Array[String] = []


## All keys, in the order of their numbers (the key of number n is at index n - 1).
static func all_keys() -> Array[String]:
	if _keys.is_empty():
		for g in ["snowball_splat", "paint_grab"]:
			for d in DIFFICULTIES:
				_keys.append("%s|%s" % [g, d])
		for d in DIFFICULTIES:
			for t in range(1, TRACKS + 1):
				_keys.append("marble_race|%s|%d" % [d, t])
	return _keys


## The number of a key, or 0 when the key is not in the table.
static func number_of(key: String) -> int:
	return all_keys().find(key) + 1


## The key of a number, or "" when the app does not know the number (a later app added it).
static func key_of(number: int) -> String:
	var k := all_keys()
	return k[number - 1] if number >= 1 and number <= k.size() else ""


## True when a lower value is the better one (a race time). The other keys count a higher value.
static func lower_is_better(key: String) -> bool:
	return key.begins_with("marble_race|")


## True when `a` is a better value than `b` for `key`. A value of 0 is "no value": it is never better.
static func is_better(key: String, a: int, b: int) -> bool:
	if a <= 0:
		return false
	if b <= 0:
		return true
	return a < b if lower_is_better(key) else a > b
