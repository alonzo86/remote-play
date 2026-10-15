# Treasure Maze (`maze`)

Type: 2D. Players: 1 to 4. Input: tilt. Code: `scripts/game/maze/`.
General requirements: `docs/GAME_REQUIREMENTS.md`. System requirement: REQ-T1.

## Goal

Each player tilts a phone to roll a ball through the same maze. The first ball in the exit (a treasure chest) wins.
The collision uses the wall rectangles, and the walls are drawn as the same square-ended bars (REQ-MZ-7).

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-62 | Gap | Test 6 in `docs/MANUAL_TESTS.md` covers the feel. The other device checks are not written. |

## Requirements

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MZ-1 | The maze is made new at each start (the size of the difficulty, REQ-MZ-9). Every maze can be solved. | Done | run_tests |
| REQ-MZ-2 | All players have the same maze, and all balls start in the start cell. Slot 0 and slot 1 start on the two diagonal corners of it, so two balls do not touch. | Done | Review |
| REQ-MZ-3 | A countdown of 3 s holds the balls still. | Done | smoke_tv |
| REQ-MZ-4 | Tilt gives acceleration with a dead zone of 0.03 and a speed limit. Walls bounce the ball a little (a quarter of the speed). A ball never stays inside a wall. | Done | smoke_tv |
| REQ-MZ-5 | The first ball in the exit wins, once. The result menu (`open_results()`, REQ-GM-72) names the winner and lists the ranking: the winner with the time, the other balls as "not finished", ordered by the distance to the exit. It has "Try again" and "Back to menu", and the pause menu cannot open over it. The winner's phone buzzes 400 ms. | Done | smoke_tv, Device |
| REQ-MZ-6 | A ball that hits a wall hard buzzes the phone (20 ms, at most every 0.12 s). A soft hit does not buzz. | Done | smoke_tv, Device |
| REQ-MZ-8 | The RECENTER button of the phone recenters during the race (REQ-GM-37). A and B do nothing. A player who leaves takes the ball out and the game goes on. When the last player leaves, the menu "No players connected" opens with "Back to menu". | Done | smoke_tv |
| REQ-MZ-7 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n), drawn in the 480x270 view: a black sky with 48 star pixels, a board with a one-pixel black outline and a checkered floor (two tones, a start cell with a lighter edge), and walls with a face, a lit top and left edge and a shade on the bottom and right edge. The walls are square-ended bars 28 px (7 world pixels) thick, with a lit edge of 4 px on the top and left and a shade of 8 px on the bottom and right on the pixel grid; the cell sizes are multiples of 4 for that. Four objects stand beside the board (two on each side) and change shape in a hard step every 0.55 s of game time (it stands still while the game is paused, REQ-FL-43). The colors and objects come from the style (REQ-MZ-12). **Balls (the same in every style):** a one-pixel black outline, the slot color and two small square eyes whose pupils step to the side the ball rolls; no number and no avatar (REQ-GM-46). **Exit (the same in every style):** a treasure chest with a lock and a sparkle that moves between two places in a hard step every 0.55 s. When a ball reaches the chest, the lid opens and the gold shows. Every player color has a contrast of 3:1 or more on both floor tones and on the start cell of every style. The title, chips (P1 first, in a row that ends before the timer, a second row when they do not fit), timer (a box at a fixed place, `Shell.timer`), countdown and menus come from the shell. The tile screenshot shows this look (in the default style). | Done | run_tests (visual rules), game_rules (the sizes, the styles), Screenshot (`tools/make_tiles.gd`) |
| REQ-MZ-12 | Style (the settings view has the row **Style** after Difficulty; values Garden, Castle, Ice; the default is Garden). The style is the prop `style` of the game, and Restart keeps it (REQ-GM-93). It changes only the look of the board: the floor tones, the walls, the marks on them and the four objects beside the board. It does not change the rules, the sizes or the collision. **Garden:** a dark green lawn with grass marks and small daisies, hedge walls with leaves, four trees. **Castle:** a dark purple stone floor, stone walls with mortar marks, four torches. **Ice:** a dark blue frozen floor with snow flecks, walls of ice with frost marks, four ice crystals. The floor of every style is dark so that the player colors keep their contrast (REQ-GM-47e); the garden lawn is darker than a daylight lawn for this reason. An unknown value gives Garden. | Done | smoke_settings (the row, Start, Restart), game_rules (the list, the default), run_tests (contrast) |
| REQ-MZ-9 | Settings (REQ-GM-90 to 96): Difficulty changes the size and the complexity of the maze, see the table below. The ball, the wall thickness (28 px) and the tilt feel stay the same, so a bigger maze is a longer and more winding way, not a different game. The board always fits inside the safe margin (REQ-GM-40). The values in the table are the first guess and are tuned on a device (Test 6). | Device | game_rules (sizes, solvable, more walls), smoke_settings |
| REQ-MZ-10 | The maze has no score during play, so the HUD has no leader chip (REQ-GM-46) and the phones show no place (REQ-FL-67). In the countdown each ball has a name tag (REQ-GM-46a). The result menu names the winner and ranks the others (REQ-GM-72). | Done | game_helpers (tags) |
| REQ-MZ-11 | Personal best (REQ-GM-98): exception, decided by the owner on 2026-10-10. The maze is random in every round, so a time is mostly the luck of the maze. The game has no key and sends no result. | Done | smoke_bests |

### Difficulty (REQ-MZ-9)

| Difficulty | Cells (columns x rows) | Cell size | Extra openings | What the player feels |
|------------|------------------------|-----------|----------------|-----------------------|
| Easy | 11 x 6 | 120 px | 20% | Small, wide corridors, many loops and short ways to the exit, few dead ends. |
| Medium | 15 x 8 | 108 px | 8% | A mid-size maze with wide hedges. |
| Hard | 17 x 9 | 96 px | 2% | Large, narrow corridors, almost one long way with many dead ends. |

"Extra openings" is the share of inner walls that is removed after the maze is made (`extra_openings` in `maze_generator.gd`). Fewer openings
mean fewer loops and a more complex maze. Every maze can be solved at every difficulty. The ball is 36 px wide and the gap (cell minus wall) in Hard is 68 px.

## Parameters

`TILT_ACCEL`, `FRICTION`, `MAX_SPEED`, `RESTITUTION`, `DEADZONE` in `scripts/game/maze/maze_game.gd`.

## Sound and haptics (REQ-GM-49a to 49c, REQ-GM-43)

The song `maze` plays from "GO": Calm and curious, 120 BPM, A minor. The countdown, pause and result sounds come from the base class.

| ID | Effect | When | Sound | Status |
|----|--------|------|-------|--------|
| REQ-MZ-S1 | `maze_bump` | A ball touches a wall faster than the buzz limit (same gate as the haptic). | Short low tick | Device (test 18) |
| REQ-MZ-S2 | `maze_exit` | A ball reaches the exit (haptic 400 ms). | Rising run | Device (test 18) |

Haptics on the phone of the player: Countdown end: 60 ms (all phones); Wall hit: 20 ms with `HIT_BUZZ_MS` gap; Exit: 400 ms for the winner. Later balls make no sound of their own: only the first ball in the exit ends the round.

## Languages (REQ-GM-47o)

The texts of this game are English and Hebrew: the title, the description, the hint and the result texts have a Hebrew text in `scripts/core/strings.gd`. In Hebrew the HUD is mirrored by the shell (title, timer). The game world is not mirrored.
