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
| REQ-MZ-1 | The maze is made new at each start (17 x 9 cells). Every maze can be solved. | Done | run_tests |
| REQ-MZ-2 | All players have the same maze, and all balls start in the start cell. Slot 0 and slot 1 start on the two diagonal corners of it, so two balls do not touch. | Done | Review |
| REQ-MZ-3 | A countdown of 3 s holds the balls still. | Done | smoke_tv |
| REQ-MZ-4 | Tilt gives acceleration with a dead zone of 0.03 and a speed limit. Walls bounce the ball a little (a quarter of the speed). A ball never stays inside a wall. | Done | smoke_tv |
| REQ-MZ-5 | The first ball in the exit wins, once. The result menu (`open_results()`, REQ-GM-72) names the winner and lists the ranking: the winner with the time, the other balls as "not finished", ordered by the distance to the exit. It has "Try again" and "Back to menu", and the pause menu cannot open over it. The winner's phone buzzes 400 ms. | Done | smoke_tv, Device |
| REQ-MZ-6 | A ball that hits a wall hard buzzes the phone (20 ms, at most every 0.12 s). A soft hit does not buzz. | Done | smoke_tv, Device |
| REQ-MZ-8 | The RECENTER button of the phone recenters during the race (REQ-GM-37). A and B do nothing. A player who leaves takes the ball out and the game goes on. When the last player leaves, the menu "No players connected" opens with "Back to menu". | Done | smoke_tv |
| REQ-MZ-7 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n), drawn in the 480x270 view, in the style of a dungeon: a black sky with 48 star pixels; a dark board with a one-pixel black outline and a checkered floor (cells in the two tones `#2a1070` and `#230e60`); a start cell with a lighter edge; walls of stone bricks (`#b8a890`, a lit top and left edge `#e0d4b8`, a shade `#6c5a48` on the bottom and right, a mortar mark every 32 px). The walls are square-ended bars 12 px (3 world pixels) thick on the pixel grid; the cell sizes are multiples of 4 for that. Four torches stand beside the board (two on each side); the flame changes shape in a hard step every 0.55 s of game time. Balls: a one-pixel black outline, the slot color and two small square eyes whose pupils step to the side the ball rolls; a ball has no number and no avatar (REQ-GM-46). Exit: a treasure chest with a lock and a sparkle that moves between two places in a hard step every 0.55 s of game time (it stands still while the game is paused, REQ-FL-43). When a ball reaches the chest, the lid opens and the gold shows. Every player color has a contrast of 3:1 or more on both floor tones. The title, chips (P1 first, in a row that ends before the timer, a second row when they do not fit), timer (a box at a fixed place, `Shell.timer`), countdown and menus come from the shell. The tile screenshot shows this look. | Done | run_tests (visual rules), game_rules (the sizes), Screenshot (`tools/make_tiles.gd`) |
| REQ-MZ-9 | Settings (REQ-GM-90 to 96): Difficulty changes the size and the complexity of the maze, see the table below. The ball, the wall thickness (12 px) and the tilt feel stay the same, so a bigger maze is a longer and more winding way, not a different game. The board always fits inside the safe margin (REQ-GM-40). The values in the table are the first guess and are tuned on a device (Test 6). | Device | game_rules (sizes, solvable, more walls), smoke_settings |
| REQ-MZ-10 | The maze has no score during play, so the HUD has no leader chip (REQ-GM-46) and the phones show no place (REQ-FL-67). In the countdown each ball has a name tag (REQ-GM-46a). The result menu names the winner and ranks the others (REQ-GM-72). | Done | game_helpers (tags) |
| REQ-MZ-11 | Personal best (REQ-GM-98): exception, decided by the owner on 2026-10-10. The maze is random in every round, so a time is mostly the luck of the maze. The game has no key and sends no result. | Done | smoke_bests |

### Difficulty (REQ-MZ-9)

| Difficulty | Cells (columns x rows) | Cell size | Extra openings | What the player feels |
|------------|------------------------|-----------|----------------|-----------------------|
| Easy | 11 x 6 | 120 px | 20% | Small, wide corridors, many loops and short ways to the exit, few dead ends. |
| Medium | 17 x 9 | 96 px | 8% | The maze of today. |
| Hard | 21 x 11 | 76 px | 2% | Large, narrow corridors, almost one long way with many dead ends. |

"Extra openings" is the share of inner walls that is removed after the maze is made (`extra_openings` in `maze_generator.gd`). Fewer openings
mean fewer loops and a more complex maze. Every maze can be solved at every difficulty. The ball is 48 px wide and the gap in Hard is 68 px.

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
