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
| REQ-MZ-2 | All players have the same maze, and all balls start in the start cell. Slot 0 and slot 1 start on the two diagonal corners of it, so two balls do not touch. Slots 2 and 3 start on the other two corners; on Hard the start cell is too small (inner width 68 px for two balls of 36 px), so those balls overlap at the start and part again at once. | Done | Review |
| REQ-MZ-3 | A countdown of 3 s holds the balls still. | Done | smoke_tv |
| REQ-MZ-4 | Tilt gives acceleration with a dead zone of 0.03 and a speed limit. Walls bounce the ball a little (a quarter of the speed). A ball never stays inside a wall. | Done | smoke_tv |
| REQ-MZ-5 | The first ball in the exit wins, once. The result menu (`open_results()`, REQ-GM-72) names the winner and lists the ranking: the winner with the time, the other balls as "not finished", ordered by the distance to the exit. It has "Try again" and "Back to menu", and the pause menu cannot open over it. The winner's phone buzzes 400 ms. Each phone shows its own row of the list in the middle of the screen as three lines (the game name, the place, the time or "not finished"; the maze has no medal for a player that does not finish) with only the HOLD TO DISCONNECT box (REQ-FL-67a, issue #455). | Device | smoke_tv, Device |
| REQ-MZ-6 | A ball that hits a wall hard buzzes the phone (20 ms, at most every 0.12 s). A soft hit does not buzz. | Device | smoke_tv, Device (Test 6 step 8a) |
| REQ-MZ-8 | The pad has no RECENTER box in the maze (REQ-GM-37, issue #55); every ball is recentered at GO. The pad shows no A and no B (REQ-GM-37a, issue #80). A player who leaves takes the ball out and the game goes on. When the last player leaves, the menu "No players connected" opens with "Back to menu". | Done | smoke_tv |
| REQ-MZ-7 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n), drawn in the 480x270 view. The ground fills the whole screen under a black HUD bar of 112 px (the title and the timer): a chess board of tiles of 48 px in two tones with small marks (`MazeBoard`, one picture made once when the round starts). The walls are square-ended bars 28 px (7 world pixels) thick on the pixel grid, drawn as thick blocks that stand on the ground: a dark outline, a lit top edge of 8 px, a face with marks and a front band of 16 px under the wall (the band is only drawn, it is not part of the collision). The board is made as big as the safe margin allows: the outer edge of the walls is at least 60 px from the left, right and bottom of the screen and at least 16 px under the HUD bar (52 px on Easy; REQ-GM-40). The start cell has a lighter frame. The colors and the look of the walls come from the theme (REQ-MZ-12). **Balls (the same in every theme):** a one-pixel white ring, a one-pixel black outline, the slot color and two small square eyes whose pupils step to the side the ball rolls; no number and no avatar (REQ-GM-46). The white ring keeps every player color easy to see on the bright garden lawn, so the rule of REQ-GM-47e (3:1 against the floor) is checked for the ring, not for the slot color. **Exit (the same in every theme):** a treasure chest with a lock and a sparkle that moves between two places in a hard step every 0.55 s of game time (it stands still while the game is paused, REQ-FL-43). When a ball reaches the chest, the lid opens and the gold shows. The title, chips (P1 first, in a row that ends before the timer, a second row when they do not fit), timer (a box at a fixed place, `Shell.timer`), countdown and menus come from the shell. The tile screenshot shows this look (in the default theme). | Done | run_tests (visual rules), game_rules (the sizes, the themes, the board picture), Screenshot (`tools/make_tiles.gd`) |
| REQ-MZ-12 | Theme (the settings view has the row **Theme** after Difficulty; values in this order: Garden, Castle, Ice; the default is Garden, the first). The theme is the prop `maze_theme` (the name `theme` is taken by every Control) of the game, and Restart keeps it (REQ-GM-93). It changes only the look of the ground and the walls (`MazeBoard.THEMES`). It does not change the rules, the sizes or the collision, and the balls and the chest are the same. **Garden:** a bright green lawn with grass and small daisies, hedge walls with a rough leafy edge. **Castle:** a dark purple stone floor, walls of stone bricks. **Ice:** a dark blue frozen floor with snow flecks, walls of ice with snow marks. For every theme the white ring of a ball and the wall (by its face or its outline) have a contrast of 3:1 or more against both tones of the ground. An unknown value gives Garden. | Done | smoke_settings (the row, Start, Restart), game_rules (the list, the default, the picture), run_tests (contrast) |
| REQ-MZ-13 | Margin pictures: in the free space at the left and at the right of the maze there are two small pictures on each side, drawn into the board picture (`MazeBoard.SPRITES`, 1 world pixel for each character of the picture, so 4 screen pixels). The first picture is at a quarter of the height of the maze on the left and at 72% on the right, the second one the other way round. **Garden:** a tree and a rose bush. **Castle:** a torch and a shield. **Ice:** a penguin and an iceberg. They are still pictures, they are not part of the collision, and they sit outside the walls. A picture that does not fit in the margin is cut off at the edge of the screen. | Done | game_rules (the pictures, both sides of every theme) |
| REQ-MZ-14 | Torch flames (decided by the owner on 2026-10-20, test 6 step 7c): in the Castle theme the two torches of the margins have a burning flame. The flame is the top 5 rows of the torch picture; it is not in the board picture but is drawn on top of it in the world layer (`MazeBoard.draw_flame`) as one of 3 frames (`MazeBoard.FLAME_FRAMES`, 8x5 world pixels, hard steps, no fade) that change every 0.2 s of game time, so the flames stand still while the game is paused (REQ-FL-43). The Garden and Ice themes have no torch and no flame. No text. | Done | smoke_maze (the frames differ and change with time, the places of the flames, a still flame during a pause) |
| REQ-MZ-9 | Settings (REQ-GM-90 to 96): Difficulty changes the size and the complexity of the maze, see the table below. The ball, the wall thickness (28 px) and the tilt feel stay the same, so a bigger maze is a longer and more winding way, not a different game. The board always fits inside the safe margin (REQ-GM-40). The values in the table are the first guess and are tuned on a device (Test 6). | Device | game_rules (sizes, solvable, more walls), smoke_settings |
| REQ-MZ-10 | The maze has no score during play, so the HUD has no leader chip (REQ-GM-46) and the phones show no place (REQ-FL-67). The result menu names the winner and ranks the others (REQ-GM-72). | Done | hud_layout |
| REQ-MZ-11 | Personal best (REQ-GM-98): exception, decided by the owner on 2026-10-10. The maze is random in every round, so a time is mostly the luck of the maze. The game has no key and sends no result. | Done | smoke_bests |
| REQ-MZ-15 | The picture of the board follows the window. The pixel view is 480 x 270 and stands for the whole screen (REQ-GM-47i), so on a window that is not 1920 x 1080 (a maximized window on a computer; the window is never smaller than 1920 x 1080 and keeps the 60 px margin of REQ-MZ-7) a world pixel is larger than 4 units. The walls, the start cell and the flames of the picture are placed in the units of the window (`MazeGame.board_image()`, `_unit()`), so the walls that are drawn are the walls the ball collides with, on any window size, to half a world pixel (an edge is rounded to the nearest world pixel; the thickness is the distance of the two edges; issue #45, reopened 2026-10-28). In Hebrew the world stays where it is: the pixel layer is left to right, so a right to left window does not push the maze to the right (found on a maximized Mac window in Hebrew, 2026-10-29). | Device | smoke_maze (`_window_sizes`, `_wall_edges`), Device (Test 6 step 7i, on a Mac) |

### Difficulty (REQ-MZ-9)

| Difficulty | Cells (columns x rows) | Cell size | Extra openings | What the player feels |
|------------|------------------------|-----------|----------------|-----------------------|
| Easy | 13 x 6 | 132 px | 20% | Small, wide corridors, many loops and short ways to the exit, few dead ends. |
| Medium | 16 x 8 | 108 px | 8% | A mid-size maze with wide hedges. |
| Hard | 18 x 9 | 96 px | 2% | Large, narrow corridors, almost one long way with many dead ends. |

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

The texts of this game are English and Hebrew: the title, the description, the hint and the result texts have a key and a Hebrew text in `assets/lang/strings.csv`. In Hebrew the HUD is mirrored by the shell (title, timer). The game world is not mirrored.
