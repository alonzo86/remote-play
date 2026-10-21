extends RefCounted
## Haptic pulses with a minimum gap for each slot. A repeated event (a hit on a wall) has a cool-down of
## 100 ms or more (REQ-GM-43). A game keeps one instance. It sends the pulse with `App.server.haptic()` (REQ-GM-12).

## The phone side: the call that makes the motor run. A test replaces it (a Callable that takes `ms`) and records the calls.
static var vibrate_call := Callable()

var _last := {}   # slot -> tick of the last pulse in ms


## The phone makes its motor run for `ms` (this is the only place that calls the motor).
static func vibrate(ms: int) -> void:
	if vibrate_call.is_valid():
		vibrate_call.call(ms)
	else:
		Input.vibrate_handheld(ms)


## The phone got a haptic message from the TV: it vibrates when the HAPTICS switch of the phone is on (REQ-FL-66).
static func on_message(ms: int) -> void:
	if bool(App.settings.get("haptics", true)):
		vibrate(ms)


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
