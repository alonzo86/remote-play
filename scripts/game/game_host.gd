extends RefCounted
## What a minigame asks from the TV app (issue #300): the players, the phase and the pad of the phones, the score and the
## result messages, and the way out of the game. The base class `Minigame` holds one (`game_host`) and uses only this class, so
## a game can run without the whole app when a test gives it a stub that extends this class and records the calls. This class
## is the one that knows the `App` autoload. REQ-GM-12: a game reaches the phones only through the server API, and this is
## that API for a game.
##
## Issue #300: `Minigame`, `Haptics` and the games use it; nothing under `scripts/game/` names `App` except this class and
## the phone side of `Haptics` (`on_message`, the HAPTICS switch).

const PlayerInput = preload("res://scripts/input/player_input.gd")


## The slots that play this round (the phones that chose OUT in the settings view are not in it, REQ-GM-104).
func players_in() -> Array[int]:
	return App.server.players_in()


func player(slot: int) -> PlayerInput:
	return App.server.players[slot]


## The buttons of the pad of the phones for this game (REQ-GM-37, 37a): the Recenter button and the letters of A and B.
func set_pad(recenter_button: bool, pad_buttons: String) -> void:
	App.server.recenter_button = recenter_button
	App.server.pad_buttons = pad_buttons


func set_phase(phase: String, slots: Array[int]) -> void:
	App.server.set_phase(phase, slots)


## The turn state of a phone (0 waiting, 1 your turn, 2 the turn of `who`), for the games that play in turns.
func send_turn(slot: int, state: int, who: String, kind := "") -> void:
	App.server.send_turn(slot, state, who, kind)


func send_score(slot: int, rank: int, of: int, text: String, spec: Array = []) -> void:
	App.server.send_score(slot, rank, of, text, spec)


## The line of the result of this phone (REQ-FL-67a): the text of its row in the result menu.
func send_final(slot: int, text: String, parts := {}) -> void:
	App.server.send_final(slot, text, parts)


func send_result(slot: int, key: String, value: int) -> void:
	App.server.send_result(slot, key, value)


func drop_player(slot: int) -> void:
	App.server.drop_player(slot)


## A buzz of `ms` on the phone of `slot` (REQ-GM-12, 43).
func haptic(slot: int, ms: int) -> void:
	App.server.haptic(slot, ms)


# ---- The way out of the game ----

func go_menu() -> void:
	App.go_menu()


func go(script: GDScript, props := {}) -> void:
	App.go(script, props)


func go_game_settings(id: String) -> void:
	App.go_game_settings(id)
