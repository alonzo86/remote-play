---
name: add-minigame
description: Add a new minigame to the Remote Play TV app. Use when asked to create a game, mode or level type.
---

1. Create `scripts/game/<name>/<name>_game.gd` that `extends "res://scripts/game/minigame.gd"`. Look at `maze/maze_game.gd` and
   `pointer_test/pointer_test.gd` for the style.
2. Override `_game_ready()`, `_game_tick(delta)` and `_game_draw()`. Read input only through `player(slot)`:
   `tilt()`, `pointer()`, `is_down()`, `button_pressed`, and the raw values. Never import anything from `scripts/net/`.
   Use `participants` for the players, `is_paused()` to freeze logic, and `App.server.haptic(slot, ms)` for feedback.
3. Add one button for it in `scripts/ui/tv_menu.gd`, next to the maze and pointer test.
4. Draw with flat shapes and `UiTheme` colors. No external assets. Keep text inside the 60 px TV safe margin.
5. Add a check to `tests/smoke_tv.gd` (start the game with simulated phones, check one state change).
6. Run the `run-tests` skill and the `review` skill, then update the README project structure if needed.
