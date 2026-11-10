extends "res://scripts/game/haptics.gd"
## The `Haptics` of a game with a clock that the test sets (`now`, in ms), so the cool-down between two buzzes can be tested
## with no real waiting. It notes the buzzes that the cool-down lets through instead of sending them (`log` is
## [slot, ms, now]). It needs the App autoload to compile, so tests load it with `load()`.

var now := 0
var log: Array = []


func pulse(slot: int, ms: int, cooldown_ms: int) -> bool:
	if not allow(slot, cooldown_ms, now):
		return false
	log.append([slot, ms, now])
	return true
