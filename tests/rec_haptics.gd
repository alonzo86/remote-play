extends "res://scripts/game/haptics.gd"
## Notes the pulses of a game instead of sending them (the `Haptics` of a game is replaced with it). It needs the App autoload
## to compile, so tests load it with `load()` (see `SimInput.record_haptics()`).

var log: Array = []   # [slot, ms] for every pulse, in order.


func pulse(slot: int, ms: int, _cooldown_ms: int) -> bool:
	log.append([slot, ms])
	return true


## The durations (ms) of the pulses of `slot`.
func ms_of(slot: int) -> Array:
	var out: Array = []
	for e in log:
		if int(e[0]) == slot:
			out.append(int(e[1]))
	return out
