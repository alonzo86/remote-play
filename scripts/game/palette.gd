extends RefCounted
## The shared colors of the game worlds (issue #232, REQ-GM-48). A world picks its own colors, but three groups of colors
## carry a meaning on every screen, and a world must not use them with another meaning by chance:
##   - the player colors (`Protocol.PLAYER_COLORS`): a thing in this color belongs to a player (REQ-GM-46),
##   - OK green (`UiTheme.OK`): good, ready,
##   - BAD red (`UiTheme.BAD`): lost, an error, danger.
## A world that needs one of these colors on purpose (fire is red, party lights are the player colors) uses a constant of this
## file, never a new `Color("...")` that is equal or near. `tests/palette_lint.gd` fails on a new literal like that outside
## this file (the old ones are in `tests/palette_baseline.txt`; moving them is issue #257).

const Protocol = preload("res://scripts/core/protocol.gd")

## The red of fire, flags and balloons in a world: the NES red. It has the value of `UiTheme.BAD` by choice; a world color,
## not a message.
const NES_RED := Color("f83800")

## The four player colors, for party lights and confetti in a world (they follow the player palette).
const SLOTS: Array[Color] = Protocol.PLAYER_COLORS
