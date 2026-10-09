# Tilt Maze (`maze`)

Type: 2D. Players: 1 to 4. Input: tilt. Code: `scripts/game/maze/`.
General requirements: `docs/GAME_REQUIREMENTS.md`. System requirement: REQ-T1.

## Goal

Each player tilts a phone to roll a ball through the same maze. The first ball in the exit wins.
The collision uses the wall rectangles, so a wall end is square for the physics and round on the screen (the difference is 5 px).

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
| REQ-MZ-7 | Visual language (REQ-GM-45 to 49). Dark board `#2a1070` with the outline and a hard shadow. Light rounded walls `#8c78e6` (a bar with a circle on each end). Balls: hard shadow, dark outline of 6 px, the slot color, a small shine. Balls show the slot number. Exit: a green rounded square with a dark outline and a big white ring that pulses a little. Every player color has a contrast of 3:1 or more on the floor. The title, chips (P1 first), timer (a pill at a fixed place, `Shell.timer`), countdown and menus come from the shell. The tile screenshot looks like the same toy box as the Games screen. | Done | run_tests (visual rules), Screenshot (`tools/make_tiles.gd`) |

## Parameters

`TILT_ACCEL`, `FRICTION`, `MAX_SPEED`, `RESTITUTION`, `DEADZONE` in `scripts/game/maze/maze_game.gd`.
