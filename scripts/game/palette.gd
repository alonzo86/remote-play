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

## World colors that are near a meaning color (issue #257), named here so that the lint can tell a decision from a mistake.
## Each has the value that the world had before, so the look did not change. To change one, pick a color that is not near a
## player color, OK or BAD.
const RACE_RED := Color("e83838")
const RACE_GREEN := Color("48c838")
const RACE_BLUE := Color("1c88b0")
const RACE_WOOD := Color("d89850")
const RACE_AMBER := Color("e8a050")
const ICE_BLUE := Color("5a90c0")
const MAZE_RED := Color("d02838")
const HOCKEY_RED := Color("d62828")
const BANANA_TAN := Color("dc9660")
const BANANA_RED := Color("e6323c")
const BANANA_PEACH := Color("e6aa6e")
const LANE_WOOD := Color("d8a058")
const TOY_RED := Color("e63946")
const TONGUE_PINK := Color("ff4060")
const GOLF_GREEN := Color("00a800")

## Issue #237 (palette B): these world colors are near a new player color. They keep their old value (a decoration, a small
## detail or a shade, not an object that has to be told from a player), named here so that the lint can tell a decision from
## a mistake.
const NEON_CYAN := Color("3ddcff")
const COCKPIT_CYAN := Color("5ad2ff")
const SATURN_BAND := Color("c87800")
const GOLF_SKY := Color("68d0fc")
const LEAF_ORANGE := Color("e0842c")
const GOLD_SHADE := Color("d69614")
const HAIR_BLOND := Color("c8861e")
## Changed in issue #237 because a car in the slot color has to be told from the wall of the track: the old Space wall was
## cyan (3ddcff, slot 1 is now 3dcef2). The Candy red (was e8286c, near the new pink slot 4) is now `RACE_RED`.
const SPACE_WALL := Color("8c9cff")
