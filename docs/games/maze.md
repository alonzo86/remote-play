# Tilt Maze (`maze`)

Type: 2D. Players: 1 to 4. Input: tilt. Code: `scripts/game/maze/`.
General requirements: `docs/GAME_REQUIREMENTS.md`. System requirement: REQ-T1.

## Goal

Each player tilts a phone to roll a ball through the same maze. The first ball in the exit wins.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-34 | Exception | The result menu shows the winner and time in its title. It has "Play again" and "Back to menu". |
| REQ-GM-62 | Gap | Test 6 in `docs/DEVICE_TEST.md` covers the feel. The other device checks are not written. |

## Requirements

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MZ-1 | The maze is made new at each start (17 x 9 cells). Every maze can be solved. | Done | run_tests |
| REQ-MZ-2 | All players have the same maze, and all balls start in the start cell. | Done | Review |
| REQ-MZ-3 | A countdown of 3 s holds the balls still. | Done | smoke_tv |
| REQ-MZ-4 | Tilt gives acceleration with a dead zone of 0.03 and a speed limit. Walls bounce the ball a little. | Done | smoke_tv |
| REQ-MZ-5 | The first ball in the exit wins. The winner's phone buzzes 400 ms. | Done | Device |
| REQ-MZ-6 | A ball that hits a wall hard buzzes the phone (20 ms, at most every 0.12 s). | Done | Device |

## Parameters

`TILT_ACCEL`, `FRICTION`, `MAX_SPEED`, `RESTITUTION`, `DEADZONE` in `scripts/game/maze/maze_game.gd`.
