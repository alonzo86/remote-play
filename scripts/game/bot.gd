extends RefCounted
## Base class of a computer player (REQ-GM-105, issue #102). A game that uses bots has one brain that extends this script. The
## bot gives what a phone gives, a tilt (`PlayerInput.tilt()`), so it moves with the same body and the same physics as a person
## (REQ-GM-24); only its skill changes with Difficulty (REQ-GM-91). The base class keeps what a person lacks: a reaction time (the
## bot sees the world as it was `reaction` seconds ago) and a seeded random generator, so a test plays the same game every time.
## A brain overrides `_brain(seen, now, delta)` and answers with the tilt it wants. `skill` is a dictionary: the base class reads
## `reaction` (s) and `max_tilt` (0 to 1); the brain reads its own keys.

var skill := {"reaction": 0.2, "max_tilt": 1.0}
var rng := RandomNumberGenerator.new()

var _seen: Array[Dictionary] = []   # {t, view} snapshots, oldest first.
var _clock := 0.0


func _init(p_skill: Dictionary = {}, p_seed := 1) -> void:
	skill = skill.merged(p_skill, true)
	rng.seed = p_seed


## The tilt of this frame (a vector of length 0 to `max_tilt`, like `PlayerInput.tilt()`). `view` is a dictionary that the game
## fills with what a person would see on the screen; the brain gets it `reaction` seconds late.
func tilt(delta: float, view: Dictionary) -> Vector2:
	_clock += delta
	_seen.append({"t": _clock, "view": view})
	var due := _clock - float(skill.reaction)
	var shown: Dictionary = _seen[0].view
	while _seen.size() > 1 and float(_seen[1].t) <= due:
		_seen.pop_front()
		shown = _seen[0].view
	return _brain(shown, view, delta).limit_length(float(skill.max_tilt))


## Override in the brain: `seen` is the late view, `now` is the view of this frame (the bot knows its own body at once).
func _brain(_seen_view: Dictionary, _now: Dictionary, _delta: float) -> Vector2:
	return Vector2.ZERO


## Forget what the bot saw (a new rally).
func reset() -> void:
	_seen.clear()
