extends "res://scripts/game/minigame.gd"
## A game with a `Haptics` helper, for tests/game_host.gd.

const Haptics = preload("res://scripts/game/haptics.gd")

var _haptics := Haptics.new()
