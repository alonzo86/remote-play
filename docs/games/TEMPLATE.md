# <Game name> (`<id>`)

Type: 2D or 3D. Players: <min> to <max>. Input: tilt, pointer, buttons, touch.
General requirements: `docs/GAME_REQUIREMENTS.md`. Exceptions to them are listed in the first section.

## Goal

One or two sentences. What the player does, and how the player wins.

Registry entry: `description` (one line) and `tile` (`assets/tiles/<id>.png`, made by `tools/make_tiles.gd`), see REQ-GM-7.
Visual language: shell, player colors, toy-like world (REQ-GM-45 to 49). Check the tile next to the Games screen.

## Gaps and exceptions

General requirements that this game does not meet. "Exception" = on purpose. "Gap" = to do.

| General ID | Kind | Note |
|------------|------|------|
| (none) | | |

## Requirements

Use the prefix REQ-<XX>-n. Status: Done, Open, or Device. "Check" says how it is tested.

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-XX-1 | | Open | smoke_tv / run_tests / device |
| REQ-XX-n | Personal best (REQ-GM-98): the key and the direction (`best_key()`, `best_value()`), or the exception ("no key", and why). | Open | smoke_bests |

## Parameters

Values that change how the game feels, with their file and the first value. Tune them on a device.

## Open questions
