extends "res://scripts/game/game_host.gd"
## A host with fake players for tests/game_host.gd. It never touches `App`. It is loaded with `load()` at run time, because the
## script that it extends names the `App` autoload, which is not there while a test script is compiled.

var slots: Array[int] = [0, 2]
var phones := {}
var calls: Array = []


func players_in() -> Array[int]:
	return slots


func player(slot: int) -> PlayerInput:
	if not phones.has(slot):
		var p := PlayerInput.new(slot, {})
		p.state = PlayerInput.State.CONNECTED
		phones[slot] = p
	return phones[slot]


func set_pad(recenter_button: bool, pad_buttons: String) -> void:
	calls.append(["pad", recenter_button, pad_buttons])


func set_phase(phase: String, slots_in: Array[int]) -> void:
	calls.append(["phase", phase, slots_in.duplicate()])


func send_score(slot: int, rank: int, of: int, text: String) -> void:
	calls.append(["score", slot, rank, of, text])


func send_result(slot: int, key: String, value: int) -> void:
	calls.append(["result", slot, key, value])


func drop_player(slot: int) -> void:
	calls.append(["drop", slot])
	phones.erase(slot)
	slots.erase(slot)


func go_menu() -> void:
	calls.append(["menu"])


func go(_script: GDScript, props := {}) -> void:
	calls.append(["go", props])


func go_game_settings(id: String) -> void:
	calls.append(["settings", id])


func haptic(slot: int, ms: int) -> void:
	calls.append(["haptic", slot, ms])
