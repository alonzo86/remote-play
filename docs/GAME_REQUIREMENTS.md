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
- REQ-GM-7: The registry entry also has a `description` (one line) and a `tile` (`assets/tiles/<id>.png`, 640x360, made by `tools/make_tiles.gd`). A test checks both (REQ-FL-19, 22). The Games screen shows them.
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
- REQ-GM-21: A game must stay stable when a player leaves during play (the marker or object of that player is removed, no error). The base class calls `_on_player_left(slot)` once for each participant that left for good. The game removes the objects of that slot there.
- REQ-GM-22: A game must stay stable when all players leave (a lost phone first pauses the game, REQ-GM-30). It shows a menu with "Back to menu". The base class does this (`end_no_players()`), also when the game starts with no player. It sets `is_over`, and it does nothing when the game is over already.
- REQ-GM-23: The color of a player in the game is the slot color (`PlayerInput.color`). The names are the phone names.
- REQ-GM-24: All players use the same input mapping and the same sensitivity. No player has an advantage from the slot.
- REQ-GM-25: A game that needs a fair start gives all players the same start state (same distance to the goal).

Flow

- REQ-GM-30: While a participant is lost (the phone closed its connection, or nothing came from it for 5 s, for example no Wi-Fi or a phone call), the game is paused and a card says "P2 lost connection", with a line for each lost player ("waiting to reconnect"). The base class does this. The game never goes on by itself, also not when the phone is back: the TV user chooses. The buttons are "Resume without P2" (only while at least one other participant is connected), "Resume" (only when every participant is connected again; the title is then "P2 reconnected") and "End game" (it asks "End the game?", REQ-GM-31a). The card changes by itself when a phone comes back or its slot is freed. The phones are in the phase `paused` while the card is open.
- REQ-GM-30a: The slot of a lost phone is kept 5 minutes while the game is paused for it (`Protocol.PAUSED_SLOT_GRACE_MS`, a phone call can be long), and 30 seconds in other phases. When the time is over, the slot is freed and the participant leaves (REQ-GM-21). When every participant has left, the game shows "No players connected" with "Back to menu" (REQ-GM-22). When every participant is lost, the card has no "Resume" (nobody is connected to resume with): it has only "End game" until a phone is back.
- REQ-GM-31: OK opens the pause menu: Resume, Restart, Back to menu. Back closes the menu, or leaves the game (after the question of REQ-GM-31a).
- REQ-GM-31a: Leaving a game that is in progress asks first. Back (or "Back to menu" in the pause menu) opens "End the game?" with two buttons: "Keep playing" (green, the default) and "✕  End game" (red). The game is paused while the question is open. Back on the question is "Keep playing". A game that is over (the result menu, "No players connected") leaves at once, without the question. The base class does this (`Minigame.request_leave()`). A game must not call `App.go_menu()` for a game in progress, and it overrides `_in_progress()` when a game is in progress at a time the pause menu is not allowed. By default `_in_progress()` is `_can_open_menu()`. By default `_can_open_menu()` is true while `is_over` is false and a participant is left. A game sets `is_over = true` when it opens its result menu, and it overrides `_can_open_menu()` only to add limits.
- REQ-GM-32: Restart makes a new game with the same start values (`start_props`).
- REQ-GM-33: Every menu and every screen works with the D-pad, OK and Back. No touch or mouse is needed on the TV.
- REQ-GM-34: A game with a winner or a score ends on a result screen that shows the result and offers Restart and Back to menu. A game with scores uses `open_results()` (REQ-GM-72).
- REQ-GM-35: A game that needs equal readiness starts with a visible countdown (3 s). Input does not move the players during it. `RoundClock` (`scripts/game/round_clock.gd`) keeps the countdown and the playing time.
- REQ-GM-36: A game must not open a menu that lets the player change the game setup during play.
  Setup choices (level, track, mode) are made before the game starts and on the result screen.
- REQ-GM-37: The Recenter button of the phone works in every game (`PlayerInput.recenter()`). It is the only way to recenter during play: a game does not use A or B for it, so A and B are free for the actions of the game. A game may recenter all players at the start of play.

Look and sound

- REQ-GM-40: Text and important shapes stay inside the 60 px safe margin of the 1920x1080 screen.
- REQ-GM-41: Text on the TV is 28 px or larger (all text, also hints and chips; the numbers on a player object are not text), and it has good contrast with the background (`UiTheme` colors).
- REQ-GM-42: A game uses `UiTheme` colors, the shell fonts, and mostly shapes made in code. Image, model and font files are allowed when `docs/TV_FLOW.md` (FD-9, FD-13) allows them. A game states its own asset files in its requirements file.
- REQ-GM-43: Important events give haptic feedback on the phone of the player: start, hit, goal.
  Repeated events have a cool-down of 100 ms or more. Short pulses are 15 to 60 ms. A big event can be longer. `Haptics.pulse()` (`scripts/game/haptics.gd`) keeps the cool-down for each slot.
- REQ-GM-44: The meaning of colors is the same in all games: accent = title or number, OK = good, BAD = danger.

Visual language (decision FD-14 in `docs/TV_FLOW.md`). Three tiers:

- REQ-GM-45: Tier 1, the game shell (required). A game uses the shared shell for its pause menu, countdown, result screen, HUD text and score chips. It does not draw its own versions. The shell is part of `minigame.gd` and `minigame_3d.gd`, and it uses the Party Pop style (`UiTheme`, FD-13).
- REQ-GM-46: Tier 1. Everything that belongs to a player (marble, ball, cursor, score) uses the slot color from `Protocol`. A name or score chip is a white pill with a dot in the slot color and dark text (`Shell.chip`), because white text on the light slot colors has too little contrast. A player object that is a ball or a marble shows the slot number on it (white digit, dark outline), so players do not depend on the color alone. A 2D ball is drawn with `Shell.ball()`, which does this. Chips are in slot order (P1 first). The chips are drawn by one function, `Shell.player_chips()`: a game gives only the score text of each slot. A chip is as wide as its content (at least 200 px) and nothing in it is cut: a long name makes the chip wider, and chips that do not fit in the row go to a second row. A row of 4 chips is at most 1110 px wide and ends at the 60 px margin. The meaning of accent, OK and BAD is the same in all games (REQ-GM-44).
- REQ-GM-47: Tier 2, a toy-like world (required). A "key object" is a player object, a goal or a hazard. Values are for 1920x1080 and for the first version. The marble race trial (REQ-FL-47) checks them, and a change needs a change of this file in the same commit. The sub-requirements are 47a to 47h.
  - REQ-GM-47a: Outline color. Key objects have a dark outline in `#1a0b45` (`UiTheme.OUTLINE`).
  - REQ-GM-47b: Outline width in 2D. 6 px for key objects of 40 px or more, 4 px for smaller ones. Use `draw_*` with the outline drawn first, under the fill.
  - REQ-GM-47c: Outline width in 3D. An inverted-hull mesh (a copy of the mesh, scaled out, front faces culled, unshaded, color `#1a0b45`) with a thickness of 8% of the smallest size of the object, limited to 0.03 m to 0.10 m. A game does not use a shader for it.
  - REQ-GM-47d: Color of key objects. Flat color, no gradient, no texture. HSV saturation 0.55 or more and value 0.60 or more. Player objects use the slot color from `Protocol`. A neutral object (for example a post) uses a Party Pop accent (cyan `#3ddcff`, yellow, pink) with the outline. A pale grey is not allowed: it looks unlit and out-shines the player objects.
  - REQ-GM-47e: Contrast. A key object is at least 48 px high on the screen in the normal view (the camera at its lowest height, for a 3D game). A key object and its background differ in luminance by a ratio of 3:1 or more. The ground and the background have saturation 0.35 or more and value 0.25 to 0.65, so the key objects are the brightest things on the screen. (The marble race trial found that the Party Pop purple has saturation 0.84, so the upper saturation limit was removed.)
  - REQ-GM-47f: Rounding in 2D. Key objects have a corner radius of 25% of their shorter side or more (a circle or a capsule is fine). Maze walls and other long shapes have round ends.
  - REQ-GM-47g: Rounding in 3D. Key objects are spheres, capsules, cylinders or meshes with a bevel of 15% of the shortest side or more. A sharp `BoxMesh` is allowed only for large flat world parts (floor, wall, platform).
  - REQ-GM-47h: Materials and light in 3D. `StandardMaterial3D` with `metallic` 0, `roughness` 1, no texture, no emission except for a goal (up to 0.3). One directional light, and an ambient light so that the shaded side of a key object is not darker than 60% of its lit side. The pattern of a finish line or a checker is made with geometry or vertex colors, not with a texture file.
- REQ-GM-48: Tier 3, free. Setting, background, camera, lighting mood and theme colors are the choice of the game. The background colors come from the Party Pop set (purple `#3d1a9e`, blue `#1b3a8a`, teal `#0f6a78`, plum `#7a1f4a`, green `#145a3a`, amber `#8a4a00`), or from a set that the game's requirements file lists, and they follow REQ-GM-47e.
- REQ-GM-49: Check for a new game: put a screenshot of the game next to the Games screen. They must look like the same toy box. The reviewer (the `review` skill) does this check. Hints at the bottom of the screen sit on a dark plate (`Shell.hint`), so a wall or a track behind them does not hide the text.

Scores and solo play

- REQ-GM-70: A game with a score keeps it in a `Scoreboard` (`scripts/game/scoreboard.gd`). A higher score is better, or a lower one with `lower_is_better` (a time). The ranking lists the best first. Equal scores share a rank (1, 1, 3), in slot order. A player who leaves is removed from the board.
- REQ-GM-71: A round with a fixed length uses `RoundClock` with a `duration`. The clock shows `remaining()`, and `is_time_up()` ends the round. The length does not depend on the frame rate (REQ-GM-13).
- REQ-GM-72: The result screen of a game with scores is `open_results(board, tiers)`. It sets `is_over`. It shows the ranking (rank, name, score, a dot in the slot color), Restart and Back to menu. The title names the single winner (also with one player), or says "Tie!" when two players or more share the first rank, or "Round over" when nobody has a score. A player without a score (`set_unfinished()`) is listed after the others as "not finished", the furthest first. A game may add buttons between Restart and Back to menu (`extra_entries`, for example Choose track), and give the text of a score (`score_text`, for example "4.22 s").
- REQ-GM-73: A game that works with one player lists three medal tiers `[bronze, silver, gold]` in its requirements file (`Medals`). With one player, the title of the result screen is the medal ("Gold medal!") or "No medal this time". A player who did not finish (`set_unfinished()`) gets no medal. The tiers are open tuning values until a device test. Nothing is saved: the player is not identified yet.

Audience: children too

- REQ-GM-80: Games are for children as well as adults (from about 5 years), played together on a sofa. A game is checked against REQ-GM-81 to 84 when it is made and in its device test.
- REQ-GM-81: Content is friendly. No violence against people or animals, no weapons, no blood, injury or death, no scary pictures or sounds. A game can be playful: throw snowballs, bump, race, roll. The characters are made up, kind and funny. When something is "hit", it reacts in a funny way (it is covered with snow, it spins, it floats away). Nobody cries or falls down hurt.
- REQ-GM-82: A child understands the game from one hint line and a few seconds of play. A player needs the pointer or the tilt and at most one button (A). Targets and objects are large. The pace is slow at the start. The text on the screen is short and plain.
- REQ-GM-83: Mistakes are cheap. A miss, a fall or a bump takes no points away and gives no wait. A game in which a player can be out of the round (last one standing) keeps that wait short (about 20 seconds at most) or lets the player take part in another way. This is "should" for the games that are built on being out; the game file says how it meets it.
- REQ-GM-84: Words are kind. Titles and messages are positive ("Nice throw!", "Splat!", "X wins!"). No text says "You lose", "Game over" or "Failed". A ranking shows the winner and the others without mockery.

Performance

- REQ-GM-50: A game runs at 60 frames per second on the target TV box with 4 players. (Device)
- REQ-GM-51: A game does not create nodes or large arrays in every frame.
- REQ-GM-52: A game starts in 2 seconds or less. It builds its scene in `_game_ready()` or `_world_ready()`.

Tests

- REQ-GM-60: Each game has a check in `tests/smoke_tv.gd`: start with 2 simulated phones, make one input, and check one state change.
- REQ-GM-61: Pure logic (track maths, maze generation, scoring) has unit tests in `tests/run_tests.gd`.
- REQ-GM-62: Each game has a short section in `docs/MANUAL_TESTS.md` for what only a real device can check (feel, speed, readability).
- REQ-GM-63: Every script of a game has at least 80% line coverage from the headless tests (`tools/coverage.sh`). The tests check the rules of the
  game (what wins, what blocks, what happens when a player leaves), not only that the game starts. A script that needs extremely hard work to test
  can be set aside in `tools/coverage/exclusions.txt` with a reason, and the game file lists it as a gap.

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

## Settings and difficulty

Status (2026-10-09): the shared view, the choice row and the Difficulty row are **Done** and used by the maze. Marble Race and Snowball Splat still start without the view (their requirements are written, REQ-MR-50 to 55 and REQ-SS-20 to 22), so REQ-GM-90, 91 and 95 are Done only for games with a `settings` entry in the registry. When the others are built, `docs/TV_FLOW.md` (the Games screen flow) and the game requirement files change in the same commit (REQ-GM-5).

- REQ-GM-90: Every game defines its own settings. OK on the tile of a game opens the settings view first, not the game. The view is centered on the screen, has the game name as its title, one row for each setting, a Start button, and a Back button at the bottom. Back returns to the Games screen with the tile in focus. Start begins the game (the countdown, REQ-GM-35). Everything works with the D-pad, OK and Back (REQ-GM-33). (Done: `scripts/game/game_settings.gd`, `scripts/ui/tv_game_settings.gd`, `scripts/ui/choice_row.gd`; check smoke_settings, game_helpers)
- REQ-GM-91: Every game has the setting Difficulty with the values Easy, Medium and Hard. The game decides what each value means and lists it in its requirements file (a table of Easy, Medium, Hard). Medium is the value to start with. A game without a meaning for the three values is not allowed. (Done: `scripts/game/game_settings.gd`, `scripts/ui/tv_game_settings.gd`, `scripts/ui/choice_row.gd`; check smoke_settings, game_helpers)
- REQ-GM-92: The row of a choice setting looks like `Difficulty  <  Easy  >`: the name, then the value between two arrows. When the row has focus, the Left and Right keys of the remote change the value (at the last value the row stops, it does not wrap), and the arrows show it. Up and Down move the focus between the rows, the Start button and Back. OK on a row does nothing, or goes on to Start. One shared control (`scripts/ui/`) draws all choice rows, so all games look and work the same. (Done: `scripts/game/game_settings.gd`, `scripts/ui/tv_game_settings.gd`, `scripts/ui/choice_row.gd`; check smoke_settings, game_helpers)
- REQ-GM-93: A game may have more settings than Difficulty (for example a track). Each is a row of the same kind, or a picker that is described in the game file. The settings are part of `start_props`, so Restart (REQ-GM-32) keeps them. A game must not change them during play (REQ-GM-36). (Done: `scripts/game/game_settings.gd`, `scripts/ui/tv_game_settings.gd`, `scripts/ui/choice_row.gd`; check smoke_settings, game_helpers)
- REQ-GM-94: The values the user chose are kept while the app runs, for each game, so the view opens with the last choice. Nothing is saved to the disk (see `docs/GAMES_ROADMAP.md`, decisions). (Done: `scripts/game/game_settings.gd`, `scripts/ui/tv_game_settings.gd`, `scripts/ui/choice_row.gd`; check smoke_settings, game_helpers)
- REQ-GM-95: The result menu (REQ-GM-34) has an entry "Settings" that returns to the settings view of the game. The medal tiers and scores of a solo game belong to a difficulty: a result is judged by the tiers of the difficulty that was played (REQ-GM-73). (Done: `scripts/game/game_settings.gd`, `scripts/ui/tv_game_settings.gd`, `scripts/ui/choice_row.gd`; check smoke_settings, game_helpers)
- REQ-GM-96: Difficulty must not make a game unplayable for a child (REQ-GM-80 to 84): Easy is playable by a child of about 5 years. Hard is a challenge, but it has no penalty that Easy does not have (REQ-GM-83). All players of one game have the same difficulty (REQ-GM-24). (Open)

## Status of the games

| Game | Requirements file |
|------|-------------------|
| Tilt Maze (2D) | `docs/games/maze.md` |
| Marble Race (3D) | `docs/games/marble_race.md` |
| Snowball Splat (2D) | `docs/games/snowball_splat.md` |
