# Games roadmap: competitive 2D games

Plan for a set of 2D minigames. Most are competitive. All except Sumo Bumpers also work with one player.
This file is a plan, not a requirements file. Each game gets its own `docs/games/<id>.md` before its code
(REQ-GM-1, REQ-GM-7). General rules: `docs/GAME_REQUIREMENTS.md`.

## Decisions

- No saved scores. How users are identified is not decided, so nothing is stored. A solo game compares the score with fixed medal tiers. The tiers reset every run.
- No bots. A game that needs opponents has `min_players` 2. Only Sumo Bumpers is like this.
- Order of work: one branch for the common helpers, then one branch for each game. Each game branch starts from the merged helpers.
- Recenter is the RECENTER button of the phone only (REQ-GM-37). It already works in every game (`{"t":"recenter"}`, `tv_server.gd`). A and B are free for game actions. The maze shortcut "A recenters" is removed.
- Pointer tuning (Target Shoot) is checked on a real phone and TV with the `device-test` skill.

## Why helpers first

`scripts/game/minigame.gd` has the shell (pause, result menu, countdown, leave question) but no score, rank or round clock.
Every game below needs them. Maze and Marble Race also repeat code that the new games would copy a third to seventh time.
Branch 0 has two steps.

### Step 0a: extract from the two existing games (no change of behavior). Done.

The existing tests are the safety net. Each helper gets its own unit tests (80% rule). The only behavior change is the removal
of the maze A shortcut, and it changes `docs/games/maze.md` (REQ-MZ-8) and `tests/smoke_tv.gd` in the same commit (REQ-GM-5).

| Helper | Replaces | Job |
|--------|----------|-----|
| No-players end | The "No players connected" menu and its guard flag, in `maze_game.gd` and `marble_race.gd` | One base-class method and one "over" flag (REQ-GM-22). |
| Player-left hook | `_balls` filter in the maze, `_racers.erase` in the race | The base class calls `_on_player_left(slot)` once for each removed slot (REQ-GM-21). |
| `RoundClock` | `Phase`/`_clock` in the maze, negative `_time` and `GO_SHOW` in the race | Countdown (3 s), playing time, ended state. `delta` only (REQ-GM-13, 35). |
| `Haptics.pulse` | `haptic_cooldown` in the maze, `last_haptic_ms` in the race | A pulse with a minimum gap for each slot (REQ-GM-43). |
| Recenter cleanup | A button wiring in the maze (with `_exit_tree`), the stale "B recenters" comment in the race | Delete. The RECENTER button does the work. The maze keeps its recenter at GO. |
| `Shell.player_chips` | Chip layout in the maze HUD | Chips in slot order for the plain case (REQ-GM-46). The race keeps its standings list. |

Not extracted: collision code (different in each game), the two damping models (the feel would change and need a device test),
and 3D-only code (camera, meshes).

### Step 0b: new helpers. Done, except `TiltBody`.

| Helper | Where | Job |
|--------|-------|-----|
| Scoreboard | `scripts/game/scoreboard.gd` | Score for each slot, ranking, ties (1, 1, 3), `lower_is_better` for times, players without a score (`set_unfinished()`), ordinals (REQ-GM-70). |
| Round length | `RoundClock` (`duration`, `remaining()`, `is_time_up()`) | A round of fixed length. The visible clock is `Shell.timer()` with `remaining()` (REQ-GM-71). |
| Ranked result | `Minigame.open_results(board, tiers, title, extra_entries, score_text)` | A result menu with the ranking (dot in the slot color), Restart, extra buttons and Back to menu. Sets `is_over` (REQ-GM-72). Used by both existing games. |
| Medal tiers | `scripts/game/medals.gd` | Solo rule: `[bronze, silver, gold]` limits for one game. The result title is the medal. Not saved (REQ-GM-73). |
| `Shell.ball` | `scripts/game/shell.gd` | The outlined 2D ball with shadow, shine and slot number, moved out of the maze draw code (REQ-GM-46, 47b). The maze uses it. |
| `TiltBody` | Not built yet | Position, velocity, tilt acceleration, damping, bounce. It is built in the Paint Grab branch, with its first user, so that its parameters come from a real need. Maze and race may adopt it later, with a device test, because the damping models differ. |

Maze and Marble Race both use `open_results()`. Their result menus now list all players (times, and "not finished"), and the maze says "Restart" instead of "Play again".

## Branches

| # | Branch content | Players | Input | Competitive mode | Solo mode |
|---|----------------|---------|-------|------------------|-----------|
| 0 | Common helpers (step 0a, then 0b) | | | | |
| 1 | Target Shoot (`target_shoot`) | 1 to 4 | pointer, A | Same targets for all. Most points in 45 s wins. Some targets give more. | Score attack against medal tiers |
| 2 | Paint Grab (`paint_grab`) | 1 to 4 | tilt | Roll over tiles to claim them. Others can take them back. Most area at 60 s wins. | Cover 80% of the board before time ends |
| 3 | Dodge Storm (`dodge_storm`) | 1 to 4 | tilt | Hazards fall. The last player standing wins. | Survive as long as possible, against medal tiers |
| 4 | Tilt Snake (`tilt_snake`) | 1 to 4 | tilt | Eat pickups to grow. A hit on any tail removes you. The last one alive wins. | High score against medal tiers |
| 5 | Sumo Bumpers (`sumo_bumpers`) | 2 to 4 | tilt, A (dash) | Push others off a shrinking platform. Best of 3 rounds. | None (needs 2 players) |

Branches 1 to 5 depend only on branch 0. The order above puts the biggest unknown first: pointer drift and calibration.
Tilt Snake needs extra tests for a player who leaves while the tail is on the board (REQ-GM-21).

## Rules that apply to every game branch

Checked against `main` on 2026-10-08.

- Leaving a game in progress asks first (REQ-GM-31a). A game overrides `_can_open_menu()` (or `_in_progress()`) to say when it is over.
- A ball-like player object shows the slot number, and chips are in slot order (REQ-GM-46).
- Key objects are at least 48 px high and use no pale grey (REQ-GM-47d, 47e). All text is 28 px or larger (REQ-GM-41).
- On the phone, A is green and B is red (REQ-FL-52). A game states what A and B do, or that they do nothing. Recenter is not a game action: the RECENTER button does it (REQ-GM-37).
- Hints use `Shell.hint` (dark plate).

## Cost of each game branch

1. Requirements file `docs/games/<id>.md` (from `TEMPLATE.md`), written before the code. Medal tiers are listed as open tuning values.
2. The game, the registry entry (`doc`, `description`, `tile`, `min_players`, `max_players`) and the tile (`tools/make_tiles.gd`).
3. A check in `tests/smoke_tv.gd` and unit tests of the rules: score, collision, what wins, a player who leaves (REQ-GM-60, 61).
4. At least 80% line coverage for each script (`GODOT=<path> tools/coverage.sh`), clean `gdlint`, passing tests.
5. A section in `docs/DEVICE_TEST.md` (REQ-GM-62), and a row in the status table of `docs/GAME_REQUIREMENTS.md`.
6. A pull request only when the user asks. After it, the `review` skill runs and posts its findings as one comment.

## Later candidates

Air Hockey (1v1 or 2v2) and Hot Potato (tag). Both need a team rule or bots to work with few players, so they wait.

## Open questions

- Medal tier values for each game: set after a device test.
- User identification and saved scores: not decided. Solo mode shows no saved best until it is.
