extends RefCounted
## The clock of a round: a countdown (REQ-GM-35), then the playing time. It uses `delta` only (REQ-GM-13).
## `time` is below 0 during the countdown (-3 to 0) and counts up from 0 when play starts.

const COUNTDOWN := 3.0

var time := 0.0


func _init(countdown := COUNTDOWN) -> void:
	time = -countdown


func is_counting() -> bool:
	return time < 0.0


func is_playing() -> bool:
	return time >= 0.0


## Adds `delta`. Returns true on the frame when the countdown ends.
func tick(delta: float) -> bool:
	var was_counting := time < 0.0
	time += delta
	return was_counting and time >= 0.0


## The number to show in the countdown: 3, 2, 1. It is 0 when the countdown is over.
func count_number() -> int:
	return ceili(-time) if time < 0.0 else 0


## Seconds since the number changed, from 0 to 1. It is the `elapsed` argument of `Shell.countdown()`.
func count_elapsed() -> float:
	return float(count_number()) + time
