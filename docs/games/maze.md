# Tilt Maze (`maze`)

Type: 2D. Players: 1 to 4. Input: tilt. Code: `scripts/game/maze/`.
General requirements: `docs/GAME_REQUIREMENTS.md`. System requirement: REQ-T1.

## Goal

Each player tilts a phone to roll a ball through the same maze. The first ball in the exit wins.
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
| REQ-MZ-5 | The first ball in the exit wins, once. The result menu (`open_results()`, REQ-GM-72) names the winner and lists the ranking: the winner with the time, the other balls as "not finished", ordered by the distance to the exit. It has "Restart" and "Back to menu", and the pause menu cannot open over it. The winner's phone buzzes 400 ms. | Done | smoke_tv, Device |
| REQ-MZ-6 | A ball that hits a wall hard buzzes the phone (20 ms, at most every 0.12 s). A soft hit does not buzz. | Done | smoke_tv, Device |
| REQ-MZ-8 | The RECENTER button of the phone recenters during the race (REQ-GM-37). A and B do nothing. A player who leaves takes the ball out and the game goes on. When the last player leaves, the menu "No players connected" opens with "Back to menu". | Done | smoke_tv |
| REQ-MZ-7 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n), drawn in the 480x270 view: a black sky with 48 star pixels, a dark board `#2a1070` with a one-pixel black outline, and flat light walls `#8c78e6`. The walls are square-ended bars 12 px (3 world pixels) thick on the pixel grid; the cell sizes are multiples of 4 for that. Balls: a one-pixel black outline and the slot color; the slot number is drawn by the HUD at full resolution on the ball (`Shell.ball_number`). Exit: a green square with a black outline and a white square ring that grows by one world pixel and shrinks again in a hard step every 0.55 s of game time (it stands still while the game is paused, REQ-FL-43). Every player color has a contrast of 3:1 or more on the floor. The title, chips (P1 first, in a row that ends before the timer, a second row when they do not fit), timer (a box at a fixed place, `Shell.timer`), countdown and menus come from the shell. The tile screenshot shows this look. | Done | run_tests (visual rules), game_rules (the sizes), Screenshot (`tools/make_tiles.gd`) |
| REQ-MZ-9 | Settings (REQ-GM-90 to 96): Difficulty changes the size and the complexity of the maze, see the table below. The ball, the wall thickness (12 px) and the tilt feel stay the same, so a bigger maze is a longer and more winding way, not a different game. The board always fits inside the safe margin (REQ-GM-40). The values in the table are the first guess and are tuned on a device (Test 6). | Device | game_rules (sizes, solvable, more walls), smoke_settings |

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

## Languages (REQ-GM-47o)

The texts of this game are English and Hebrew: the title, the description, the hint and the result texts have a Hebrew text in `scripts/core/strings.gd`. In Hebrew the HUD is mirrored by the shell (title, chips, timer). The game world is not mirrored.
