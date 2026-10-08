extends RefCounted
## Haptic pulses with a minimum gap for each slot. A repeated event (a hit on a wall) has a cool-down of
## 100 ms or more (REQ-GM-43). A game keeps one instance. It sends the pulse with `App.server.haptic()` (REQ-GM-12).

var _last := {}   # slot -> tick of the last pulse in ms


## True when `slot` may get a pulse now, and then the time is noted. False while the cool-down runs.
func allow(slot: int, cooldown_ms: int, now_ms := Time.get_ticks_msec()) -> bool:
	if _last.has(slot) and now_ms - int(_last[slot]) < cooldown_ms:
		return false
	_last[slot] = now_ms
	return true


## Sends a pulse of `ms` to `slot` unless its cool-down runs. Returns true when the pulse was sent.
func pulse(slot: int, ms: int, cooldown_ms: int) -> bool:
	if not allow(slot, cooldown_ms):
		return false
	App.server.haptic(slot, ms)
	return true
