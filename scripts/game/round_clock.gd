extends RefCounted
## The clock of a round: a countdown (REQ-GM-35), then the playing time. It uses `delta` only (REQ-GM-13).
## `time` is below 0 during the countdown (-3 to 0) and counts up from 0 when play starts.
## A round can have a length (`duration`, REQ-GM-71). With 0 it has no limit.

const COUNTDOWN := 3.0
const TIME_LOW_SECONDS := 5   # The last seconds of a timed round tick.

var time := 0.0
var duration := 0.0


func _init(countdown := COUNTDOWN, p_duration := 0.0) -> void:
	time = -countdown
	duration = p_duration


func is_counting() -> bool:
	return time < 0.0


func is_playing() -> bool:
	return time >= 0.0


## Adds `delta`. Returns true on the frame when the countdown ends.
func tick(delta: float) -> bool:
	var was_counting := time < 0.0
	var before := count_number()
	var left_before := ceili(duration - time)
	time += delta
	if was_counting and time >= 0.0:
		_sound("go")
		return true
	if was_counting and count_number() != before:
		_sound("count")
	elif duration > 0.0 and not was_counting:
		var left := ceili(duration - time)
		if left != left_before and left >= 1 and left <= TIME_LOW_SECONDS:
			_sound("time_low")   # A soft tick in each of the last seconds of a timed round.
	return false


## Plays an effect of the countdown (REQ-FL-65a). The clock is pure logic and tests load it without the autoloads, so the
## `Sound` autoload is looked up here, and a missing one is ignored.
static func _sound(id: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.has_node("Sound"):
		var sound: Node = tree.root.get_node("Sound")
		sound.sfx(id)
		if id == "go":
			sound.start_queued_music()


## The number to show in the countdown: 3, 2, 1. It is 0 when the countdown is over.
func count_number() -> int:
	return ceili(-time) if time < 0.0 else 0


## Seconds since the number changed, from 0 to 1. It is the `elapsed` argument of `Shell.countdown()`.
func count_elapsed() -> float:
	return float(count_number()) + time


## True when the round has a length and the playing time has used it.
func is_time_up() -> bool:
	return duration > 0.0 and time >= duration


## Seconds left in the round, for the visible clock. It is the whole length during the countdown.
## It is 0 when time is up, and also when the round has no length.
func remaining() -> float:
	return clampf(duration - maxf(time, 0.0), 0.0, duration)
