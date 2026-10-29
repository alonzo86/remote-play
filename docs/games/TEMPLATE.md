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

## Sound and haptics (REQ-GM-49a to 49c, REQ-GM-43)

The events with a haptic on the phone, and the sound effect and the song of each (the TV only). No sound is scary or sad (REQ-GM-81).

## Languages and texts (REQ-GM-47o)

The rows of `assets/lang/strings.csv` that the game adds (keys), and what is mirrored in Hebrew. The Hebrew written by Claude needs a native reader; the user reviews every new row.

## Open questions
