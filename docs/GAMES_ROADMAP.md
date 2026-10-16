# Games roadmap: competitive 2D games

Plan for a set of 2D minigames. Most are competitive. All except Sumo Bumpers also work with one player.
This file is a plan, not a requirements file. Each game gets its own `docs/games/<id>.md` before its code
(REQ-GM-1, REQ-GM-7). General rules: `docs/GAME_REQUIREMENTS.md`.

## Decisions

- No saved scores. How users are identified is not decided, so nothing is stored. A solo game compares the score with fixed medal tiers. The tiers reset every run.
- No bots. A game that needs opponents has `min_players` 2. Only Sumo Bumpers is like this.
- Order of work: one branch for the common helpers (PR 12), then one branch for each game. The helpers are merged into `main` first. Each game branch starts from the updated `main`, so its pull request shows only that game.
- Game pull requests merge one at a time. All games touch the same few files (`registry.gd`, the status table in `GAME_REQUIREMENTS.md`, `MANUAL_TESTS.md`, `smoke_tv.gd`, the `WAIT` table in `tools/make_tiles.gd`), so a branch updates from `main` before its pull request is ready. The conflicts are small.
- Branch names: `games/<id>` (for example `games/target-shoot`). A session needs permission to create them.
- Recenter is the RECENTER button of the phone only (REQ-GM-37). It already works in every game (`{"t":"recenter"}`, `tv_server.gd`). A and B are free for game actions. The maze shortcut "A recenters" is removed.
- Pointer tuning (Snowball Splat) is checked on a real phone and TV with the `device-test` skill.
- Every game has a settings view before it starts, with the row Difficulty (Easy, Medium, Hard) and, when the game needs it, more rows (REQ-GM-90 to 97, `docs/GAME_REQUIREMENTS.md`). Its shared code is `game_settings.gd`, `tv_game_settings.gd` and `choice_row.gd`. A new game adds a `settings` entry to the registry and a difficulty table to its requirements file.

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
| `RoundClock` | `Phase`/`_clock` in the maze, negative `_time` and `GO_SHOW` in the race | Countdown (3 s), playing time, round length. `delta` only (REQ-GM-13, 35). The end flag is `is_over` in the base class. |
| `Haptics.pulse` | `haptic_cooldown` in the maze, `last_haptic_ms` in the race | A pulse with a minimum gap for each slot (REQ-GM-43). |
| Recenter cleanup | A button wiring in the maze (with `_exit_tree`), the stale "B recenters" comment in the race | Delete. The RECENTER button does the work. The maze keeps its recenter at GO. |
| `Avatar`, `Minigame.slot_label()` | The picture of a profile; the name of a player in a card | The avatar of a profile on the chips (`Shell.chip()`, REQ-GM-46b) and in the Players list. A game does not draw an avatar or a number on its objects (REQ-GM-46): the slot color alone. |
| `Minigame.best_key()`, `best_value()` | Nothing (new) | The key and the saved number of the personal best of a game (REQ-GM-98); an empty key means no best. `open_results()` sends the result to the phones (REQ-GM-99). |
| `Shell.leader_chip`, `Minigame.draw_leader_chip()` | The leader chip in the HUD | One chip: the leader and the score, or TIE (REQ-GM-46, FD-21). A game returns its `Scoreboard` from `_scoreboard()`; the phones get the place and score (REQ-FL-67). |

Not extracted: collision code (different in each game), the two damping models (the feel would change and need a device test),
and 3D-only code (camera, meshes).

### Step 0b: new helpers. Done, except `TiltBody`.

| Helper | Where | Job |
|--------|-------|-----|
| Scoreboard | `scripts/game/scoreboard.gd` | Score for each slot, ranking, ties (1, 1, 3), `lower_is_better` for times, players without a score (`set_unfinished()`), ordinals (REQ-GM-70). |
| Round length | `RoundClock` (`duration`, `remaining()`, `is_time_up()`) | A round of fixed length. The visible clock is `Shell.timer()` with `remaining()` (REQ-GM-71). |
| Ranked result | `Minigame.open_results(board, tiers, title, extra_entries, score_text)` | A result menu with the ranking (dot in the slot color), Try again, extra buttons and Back to menu. Sets `is_over` (REQ-GM-72). Used by both existing games. |
| Medal tiers | `scripts/game/medals.gd` | Solo rule: `[bronze, silver, gold]` limits for one game. The result title is the medal. Not saved (REQ-GM-73). |
| `Shell.ball` | `scripts/game/shell.gd` | The outlined 2D ball (no number since 2026-10-11), moved out of the maze draw code (REQ-GM-46, 47b). It still has the old shadow and shine and is used by no game now: every game draws `Shell.pixel_ball()` (flat colors, REQ-GM-47k) and a ball has no number. |
| `TiltBody` | Not built yet | Position, velocity, tilt acceleration, damping, bounce. It is built in the Paint Grab branch, with its first user, so that its parameters come from a real need. Maze and race may adopt it later, with a device test, because the damping models differ. |

Maze and Marble Race both use `open_results()`. Their result menus now list all players (times, and "not finished"), and the maze says "Try again" instead of "Play again".

## Branches

| # | Branch | Content | Players | Input | Competitive mode | Solo mode | Needs |
|---|--------|---------|---------|-------|------------------|-----------|-------|
| 0 | PR 12 | Common helpers (step 0a, then 0b) | | | | | none |
| 1 | `games/target-shoot` (PR 13, merged) | Snowball Splat (`snowball_splat`, first made as "Target Shoot"; the branch name stayed) | 1 to 4 | pointer, A | Throw snowballs at big, slow, friendly Puffs. Same Puffs for all. Most points in 60 s wins. No penalty for a miss. | Score attack against medal tiers | 0 |
| 2 | `games/paint-grab` (in work) | Paint Grab (`paint_grab`), builds `TiltBody` | 1 to 4 | tilt | Roll over tiles to claim them. Others can take them back. Most area at 60 s wins. | Cover 80% of the board before time ends | 0 |
| 3 | `games/dodge-storm` | Dodge Storm (`dodge_storm`) | 1 to 4 | tilt | Hazards fall. The last player standing wins. | Survive as long as possible, against medal tiers | 2 (`TiltBody`) |
| 4 | `games/tilt-snake` | Tilt Snake (`tilt_snake`) | 1 to 4 | tilt | Eat pickups to grow. A hit on any tail removes you. The last one alive wins. | High score against medal tiers | 2 (`TiltBody`) |
| 5 | `games/sumo-bumpers` (in work) | Sumo Bumpers (`sumo_bumpers`) | 2 to 4 | tilt, A (dash) | Push others off a shrinking platform. Best of 3 rounds. | None (needs 2 players) | 2 (`TiltBody`) |
| 6 | `games/wobbly-tower` (idea, 2026-10-16) | Wobbly Tower (`wobbly_tower`) | 1 to 4 | A (drop a block) | Turn-based. A block swings over the tower; A drops it. The tallest tower after 3 turns wins. A tower that falls wobbles, giggles and starts again, and the points stay (REQ-GM-83). | Stack as high as possible against medal tiers | 0 |
| 7 | `games/tennis` (idea, 2026-10-16) | Tennis (`tennis`) | 1 to 4 | swing, tilt to aim | Real-time rally. Your character runs by itself; swing the phone to hit, and timing and tilt set direction and power. 1v1, 2v2, or free-for-all rotation. First to 5 points. A miss gives the other side a point, nothing is taken away (REQ-GM-83). | Rally with a friendly ball machine; the longest rally is scored against medal tiers | 0 |
| 8 | `games/mini-golf` (idea, 2026-10-16) | Mini Golf (`mini_golf`) | 1 to 4 | swing (power), tilt (aim) | Everyone plays at once on a generated course, balls do not collide. Fewest strokes over 3 holes wins. | Fewest strokes against medal tiers | 0 |
| 9 | `games/freeze-dance` (idea, 2026-10-16) | Freeze Dance (`freeze_dance`) | 1 to 4 | shake, then hold still | Music plays and you wiggle the phone; when it stops, hold still. A mover sits out one short song (about 10 s) and keeps the points (REQ-GM-83). | Survive more stops against medal tiers | 0 (needs a stillness check on the phone) |
| 10 | `games/balloon-ride` (idea, 2026-10-16) | Balloon Ride (`balloon_ride`) | 1 to 4 | tilt, hold A | Co-op: one shared balloon. Roles split (A holds the burner, tilt steers). Collect stars over a gentle course. | Same co-op game, medal tiers by stars | 0 |

Status (2026-10-09): branch 1 is merged (PR 13). It also brought the settings view with Difficulty for the maze, Snowball Splat and
Marble Race, generated Marble Race tracks, and the lost-phone hold card. All of it still needs the tests on a device (`docs/MANUAL_TESTS.md`).
The values in the difficulty tables, the pointer range and the generated tracks are first guesses. Branch 2 (Paint Grab, with `TiltBody`) is merged (PR 14). Branch 5 (Sumo Bumpers) is in work on `games/sumo-bumpers`; branches 3 and 4 are not started.
Each of them needs a settings view and a difficulty table (REQ-GM-90, 91) before it is done.

Order and dependencies:
- Branch 0 is merged first. Branches 1 and 2 need only branch 0, so they do not wait for each other.
- Snowball Splat goes first because it has the biggest unknown: pointer drift and calibration. It reads `pointer()`, not tilt, so it does not use `TiltBody`.
- `TiltBody` is built in the Paint Grab branch, with its first user. Dodge Storm, Tilt Snake and Sumo Bumpers reuse it, so they start after Paint Grab is merged.
  (If one of them has to start earlier, `TiltBody` moves into its own small branch before all of them.)
- Tilt Snake needs extra tests for a player who leaves while the tail is on the board (REQ-GM-21).

## Games for children too

Decision (2026-10-09, after the first try of "Target Shoot"): all games are also for children (REQ-GM-80 to 84 in `docs/GAME_REQUIREMENTS.md`).
No violence against anything alive, no blood and nothing scary (REQ-GM-81): made-up friendly characters, bananas, bumpers, funny reactions. Toy beams at lifeless things (rocks) are fine (Galaxy Protector). A miss or a fall costs nothing. Large and slow at the start.
What this means for the games that are not built yet. The decision is made in the requirements file of each game:

| Game | Check against REQ-GM-80 to 84 |
|------|--------------------------------|
| Paint Grab | Fine: roll and paint. Use bright, friendly colors. |
| Dodge Storm | "The last player standing" means a player is out and waits (REQ-GM-83). A hit should be a funny bump, and the player is back in the game after a few seconds (or keeps the points and waits only until the team game ends, REQ-GM-83). The hazards are soft and funny (balloons, snowflakes, rubber ducks), not dangerous things. |
| Tilt Snake | "A hit on a tail removes you" is too harsh. A hit makes the snake short again and it goes on. The snake is a friendly made-up creature. |
| Wobbly Tower | Fine: soft, colorful blocks. A fall is funny, not a loss. It is the first turn-based game, so each player's wait is short (one drop) and the TV shows whose turn it is. |
| Sumo Bumpers | Cartoon bumpers that bounce each other off a platform. A player who falls off comes back in the next round (a round is short). No fighting words. |

## Rules that apply to every game branch

Checked against `main` on 2026-10-08.

- A game has a settings view with Difficulty and a table of what Easy, Medium and Hard mean in its requirements file (REQ-GM-90, 91). The chosen value is yellow (REQ-GM-97). The game gets it as the prop `difficulty`; Try again keeps it. A solo game has medal tiers for each difficulty (REQ-GM-95).
- Leaving a game in progress asks first (REQ-GM-31a). A game overrides `_can_open_menu()` (or `_in_progress()`) to say when it is over.
- A ball-like player object has only the slot color (no number, no avatar), the HUD has one leader chip and the name tags show in the countdown (REQ-GM-46, 46a, FD-21).
- Key objects are at least 48 px high and use no pale grey (REQ-GM-47d, 47e). All text is 28 px or larger (REQ-GM-41).
- On the phone, A is green and B is red (REQ-FL-52). A game states what A and B do, or that they do nothing. Recenter is not a game action: the RECENTER button does it (REQ-GM-37).
- Hints use `Shell.hint` (dark plate).

## Cost of each game branch

1. Requirements file `docs/games/<id>.md` (from `TEMPLATE.md`), written before the code. Medal tiers are listed as open tuning values.
2. The game, the registry entry (`doc`, `description`, `tile`, `min_players`, `max_players`, `settings`) and the tile (`tools/make_tiles.gd`, with a scene that shows action, for example 4 players).
3. A check in `tests/smoke_tv.gd` and unit tests of the rules: score, collision, what wins, a player who leaves (REQ-GM-60, 61).
4. At least 80% line coverage for each script (`GODOT=<path> tools/coverage.sh`), clean `gdlint`, passing tests.
5. A section in `docs/MANUAL_TESTS.md` (REQ-GM-62), and a row in the status table of `docs/GAME_REQUIREMENTS.md`.
6. A pull request only when the user asks. After it, the `review` skill runs and posts its findings as one comment.

## Later candidates

Air Hockey (1v1 or 2v2) and Hot Potato (tag). Both need a team rule or bots to work with few players, so they wait.

## Open questions

- Medal tier values for each game: set after a device test.
- User identification and saved scores: not decided. Solo mode shows no saved best until it is.
