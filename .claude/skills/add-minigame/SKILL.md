---
name: add-minigame
description: Add a new minigame to the Remote Play TV app. Use when asked to create a game, mode or level type.
---

0. Write the requirements first. Copy `docs/games/TEMPLATE.md` to `docs/games/<id>.md` and fill it in. Read `docs/GAME_REQUIREMENTS.md`:
   the general requirements (all games, plus 2D or 3D) apply, and the game file lists its gaps and its own `REQ-<XX>-n` requirements.
   Show the file to the user before you write code if a requirement is a design choice.
1. Create `scripts/game/<name>/<name>_game.gd` that `extends "res://scripts/game/minigame.gd"`. Look at `maze/maze_game.gd` and
   `marble_race/marble_race.gd` (3D) for the style.
2. Override `_game_ready()`, `_game_tick(delta)` and `_game_draw()`. Read input only through `player(slot)`:
   `tilt()`, `pointer()`, `is_down()`, `button_pressed`, and the raw values. Never import anything from `scripts/net/`.
   Use `participants` for the players, `is_paused()` to freeze logic, and `App.server.haptic(slot, ms)` for feedback (`Haptics.pulse()` in `scripts/game/haptics.gd` adds a cool-down for each slot).
   Use `RoundClock` (`scripts/game/round_clock.gd`) for the 3 s countdown and the playing time. Do not bind A or B to recenter: the RECENTER button does it (REQ-GM-37).
3. Add one entry for it in `scripts/game/registry.gd`, with the `doc`, `description` and `tile` fields. The Games screen is built from the registry. For a 3D game, extend `minigame_3d.gd`.
4. Follow the visual language (REQ-GM-45 to 49): use the shell (`scripts/game/shell.gd`, `open_menu`) for titles, chips (in slot order), the timer pill, hints (on a dark plate), countdown and menus,
   the slot color for everything of a player (and the slot number on a ball or marble, so color is never the only cue), and the toy-like world rules (rounded shapes, flat saturated colors, dark outline on key objects;
   in 3D use `add_outlined_mesh`). Keep text inside the 60 px TV safe margin, and all text at 28 px or more. A key object is at least 48 px high on screen (REQ-GM-47e). The base class handles the players that leave: remove the objects of a slot in `_on_player_left(slot)` (REQ-GM-21), and it shows the "No players connected" menu when nobody is left (REQ-GM-22, 30a). Set `is_over = true` when you open the result menu. Draw the chips with `Shell.player_chips()` and a 2D ball with `Shell.ball()`. For a score, keep a `Scoreboard` and end the round with `open_results(board, tiers)` (REQ-GM-70 to 73): a timed round uses `RoundClock.new(3.0, duration)`, and a game for one player lists its medal tiers in its requirements file. Pick the background from the Party Pop set.
   Make the tile screenshot with `tools/make_tiles.gd` and check it next to the Games screen (REQ-GM-49).
5. Add a check to `tests/smoke_tv.gd` (start the game with simulated phones, check one state change), and unit tests for pure logic.
   Put the requirement ID in the check text. Add a section to `docs/DEVICE_TEST.md`.
   Every script of the game needs 80% line coverage (`tools/coverage.sh`, REQ-GM-63). Test the rules of the game (win, collision, leaving
   players, buttons), not only that it starts.
6. Run the `run-tests` skill and the `review` skill, then update the README project structure if needed.
   Set the status of each requirement (Done, Open, Device) so that the file matches the code.
