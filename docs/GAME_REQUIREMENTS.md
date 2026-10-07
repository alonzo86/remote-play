# Game requirements

These requirements apply to every minigame. Each game also has its own list in `docs/games/<id>.md`.
The system requirements (network, phone, TV, export) are in `docs/REQUIREMENTS.md`.

Style: ASD-STE100 Simplified Technical English. "Must" is mandatory. "Should" is a goal that a game may skip
if its own requirements file says why.

## How the requirements work

- REQ-GM-1: Each game has a requirements file `docs/games/<id>.md`. `<id>` is the id in `scripts/game/registry.gd`.
- REQ-GM-2: The game requirements file lists the general requirements it does not meet yet (gap) or does not need (exception), and why. All others apply.
- REQ-GM-3: Each requirement has an ID and a status. Statuses: **Done** (built), **Open** (not built), **Device** (only a test on real hardware can check it).
- REQ-GM-4: Code comments and tests use the requirement ID, for example `# REQ-MR-7`.
- REQ-GM-5: A change to the behavior of a game must change its requirements file in the same commit.
- REQ-GM-6: The registry entry of a game has a `doc` field with the path of its requirements file. A test checks that the file exists.
- REQ-GM-7: `docs/games/TEMPLATE.md` is the starting point for a new requirements file. Write it before the code.

## All games (2D and 3D)

Architecture

- REQ-GM-10: A game extends `scripts/game/minigame.gd` (2D) or `scripts/game/minigame_3d.gd` (3D) and is listed in `scripts/game/registry.gd`.
- REQ-GM-11: A game reads input only through `PlayerInput` (`tilt()`, `pointer()`, `is_down()`, `button_pressed`, raw values).
  It must not use `scripts/net/`.
- REQ-GM-12: A game uses `App.server.haptic(slot, ms)` for feedback. It must not send network messages itself.
- REQ-GM-13: Game logic uses the frame `delta`. The result must not change with the frame rate.
  Fast physics use sub-steps of 1/120 s or less.

Players

- REQ-GM-20: The registry entry gives `min_players` and `max_players`. A game works with the number of phones that are connected when it starts.
- REQ-GM-21: A game must stay stable when a player leaves during play (the marker or object of that player is removed, no error).
- REQ-GM-22: A game must stay stable when all players leave. It shows a menu with "Back to menu".
- REQ-GM-23: The color of a player in the game is the slot color (`PlayerInput.color`). The names are the phone names.
- REQ-GM-24: All players use the same input mapping and the same sensitivity. No player has an advantage from the slot.
- REQ-GM-25: A game that needs a fair start gives all players the same start state (same distance to the goal).

Flow

- REQ-GM-30: The game pauses while a participant is lost (the base class does this). OK continues without the lost players.
- REQ-GM-31: OK opens the pause menu: Resume, Restart, Back to menu. Back closes the menu, or leaves the game.
- REQ-GM-32: Restart makes a new game with the same start values (`start_props`).
- REQ-GM-33: Every menu and every screen works with the D-pad, OK and Back. No touch or mouse is needed on the TV.
- REQ-GM-34: A game with a winner or a score ends on a result screen that shows the result and offers Restart and Back to menu.
- REQ-GM-35: A game that needs equal readiness starts with a visible countdown (3 s). Input does not move the players during it.
- REQ-GM-36: A game must not open a menu that lets the player change the game setup during play.
  Setup choices (level, track, mode) are made before the game starts and on the result screen.
- REQ-GM-37: The Recenter button of the phone works in every game (`PlayerInput.recenter()`).

Look and sound

- REQ-GM-40: Text and important shapes stay inside the 60 px safe margin of the 1920x1080 screen.
- REQ-GM-41: Text on the TV is 28 px or larger, and it has good contrast with the background (`UiTheme` colors).
- REQ-GM-42: A game uses flat shapes and `UiTheme` colors. No external assets (REQ-P6).
- REQ-GM-43: Important events give haptic feedback on the phone of the player: start, hit, goal.
  Repeated events have a cool-down of 100 ms or more. Short pulses are 15 to 60 ms. A big event can be longer.
- REQ-GM-44: The meaning of colors is the same in all games: accent = title or number, OK = good, BAD = danger.

Performance

- REQ-GM-50: A game runs at 60 frames per second on the target TV box with 4 players. (Device)
- REQ-GM-51: A game does not create nodes or large arrays in every frame.
- REQ-GM-52: A game starts in 2 seconds or less. It builds its scene in `_game_ready()` or `_world_ready()`.

Tests

- REQ-GM-60: Each game has a check in `tests/smoke_tv.gd`: start with 2 simulated phones, make one input, and check one state change.
- REQ-GM-61: Pure logic (track maths, maze generation, scoring) has unit tests in `tests/run_tests.gd`.
- REQ-GM-62: Each game has a short section in `docs/DEVICE_TEST.md` for what only a real device can check (feel, speed, readability).

## 2D games

- REQ-2D-1: A 2D game extends `minigame.gd` and draws in `_game_draw()`.
- REQ-2D-2: A 2D game builds its layout from `size`, not from fixed pixels. The picture must work at 1280x720 and 1920x1080.
- REQ-2D-3: A 2D game draws with `draw_*` calls. It does not add one node for each object that moves.
- REQ-2D-4: Positions and speeds use pixels at 1920x1080. Tilt 1.0 means sin(angle), 15 degrees gives about 0.26.

## 3D games

- REQ-3D-1: A 3D game extends `minigame_3d.gd` and builds its scene in code under `world`.
- REQ-3D-2: A 3D game uses primitive meshes with flat materials (`flat_material()`, `add_mesh()`). No textures or models until the project allows them.
- REQ-3D-3: Shadows are off and MSAA is off, unless the game requirements file says why it needs them and the device test passes.
- REQ-3D-4: A 3D game should have 200 mesh instances or fewer in view at the same time. (Device)
- REQ-3D-5: The world is frozen while the game is paused (the base class does this).
- REQ-3D-6: The camera keeps all active players in view. The camera can move and zoom. It must not turn the controls:
  tilt right is always right on the screen, and tilt toward the player is always down on the screen.
- REQ-3D-7: A 3D game draws score, names and text on the HUD layer (`_hud_draw()`), not as 3D text.
- REQ-3D-8: A 3D game shows the shape of the play area clearly (floor, edges), and objects have enough contrast with the background.
- REQ-3D-9: The result of the game must not depend on the physics engine of Godot (`RigidBody3D`). Use fixed sub-steps in game code
  so that the same input gives the same result.

## Status of the games

| Game | Requirements file |
|------|-------------------|
| Tilt Maze (2D) | `docs/games/maze.md` |
| Pointer Test (2D) | `docs/games/pointer_test.md` |
| 3D Demo (3D, template) | `docs/games/demo3d.md` |
| Marble Race (3D) | `docs/games/marble_race.md` |
