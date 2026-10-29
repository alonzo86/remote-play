# Games roadmap: competitive 2D games

Plan for a set of 2D minigames. Most are competitive. All except Sumo Bumpers and Bumper Cars (`min_players` 2) also work with one player.
This file is a plan, not a requirements file. Each game gets its own `docs/games/<id>.md` before its code
(REQ-GM-1, REQ-GM-7). General rules: `docs/GAME_REQUIREMENTS.md`.

## Decisions

- Personal bests are kept on the phone by profile (FD-22, REQ-GM-98 to 101; a game with `best_key()` saves one, the others have an exception row). There is no server and no login. A solo game shows the score and no medal (REQ-GM-73).
- Bots only in the games that say so (REQ-GM-105, issue #102; decision 2026-10-22). Air Hockey is the first: with one phone ROBO plays the other seat. Any other game that needs opponents has `min_players` 2 (Sumo Bumpers, Bumper Cars).
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
| `Shell.leader_chip`, `Minigame.draw_leader_chip()` | The leader chip in the HUD | One chip: the leader and the score, or TIE (REQ-GM-46, FD-21 leader chip). A game returns its `Scoreboard` from `_scoreboard()`; the phones get the place and score (REQ-FL-67). |

Not extracted: collision code (different in each game), the two damping models (the feel would change and need a device test),
and 3D-only code (camera, meshes).

### Step 0b: new helpers. Done, except `TiltBody`.

| Helper | Where | Job |
|--------|-------|-----|
| Scoreboard | `scripts/game/scoreboard.gd` | Score for each slot, ranking, ties (1, 1, 3), `lower_is_better` for times, players without a score (`set_unfinished()`), ordinals (REQ-GM-70). |
| Round length | `RoundClock` (`duration`, `remaining()`, `is_time_up()`) | A round of fixed length. The visible clock is `Shell.timer()` with `remaining()` (REQ-GM-71). |
| Ranked result | `Minigame.open_results(board, title, extra_entries, score_text)` | A result menu with the ranking (dot in the slot color), Try again, extra buttons and Back to menu. Sets `is_over` (REQ-GM-72). Used by both existing games. |
| Medals | `scripts/game/medals.gd` | The medal of a place (1st gold, 2nd silver, 3rd bronze) with more than one player. No medal for one player. Not saved (REQ-GM-73). |
| `Shell.ball` | `scripts/game/shell.gd` | The outlined 2D ball (no number since 2026-10-11), moved out of the maze draw code (REQ-GM-46, 47b). It still has the old shadow and shine and is used by no game now: every game draws `Shell.pixel_ball()` (flat colors, REQ-GM-47k) and a ball has no number. |
| `TiltBody` | Not built yet | Position, velocity, tilt acceleration, damping, bounce. It is built in the Paint Grab branch, with its first user, so that its parameters come from a real need. Maze and race may adopt it later, with a device test, because the damping models differ. |

Maze and Marble Race both use `open_results()`. Their result menus now list all players (times, and "not finished"), and the maze says "Try again" instead of "Play again".

## Branches

| # | Branch | Content | Players | Input | Competitive mode | Solo mode | Needs |
|---|--------|---------|---------|-------|------------------|-----------|-------|
| 0 | PR 12 | Common helpers (step 0a, then 0b) | | | | | none |
| 1 | `games/target-shoot` (PR 13, merged) | Snowball Splat (`snowball_splat`, first made as "Target Shoot"; the branch name stayed) | 1 to 4 | pointer, A | Throw snowballs at big, slow, friendly Puffs. Same Puffs for all. Most points in 60 s wins. No penalty for a miss. | Score attack; the score only, no medal for one player (REQ-GM-73) | 0 |
| 2 | `games/paint-grab` (merged, PR 14) | Paint Grab (`paint_grab`), builds `TiltBody` | 1 to 4 | tilt | Roll over tiles to claim them. Others can take them back. Most area at 60 s wins. | Cover 80% of the board before time ends | 0 |
| 3 | built 2026-10-16 (Manual test 22) | Star Shield (`asteroid_blast`, `docs/games/asteroid_blast.md`; first called Galaxy Protector) | 1 to 4 | tilt (ship left and right) | Team game: the ships shoot by themselves at falling asteroids and take upgrades (force field, up to 4 lasers); a ship that is hit is out for a while. The player with the most points wins. | Score attack; no medal for one player (REQ-GM-73) | 0 |
| 4 | built 2026-10-16 (Manual test 23) | Pin Pals (`bowling`, `docs/games/bowling.md`) | 1 to 4 | finger on the aim strip (aim), phone swing (throw) | Turns on one lane, the standard 10 frame score sheet. | Score attack; no medal for one player (REQ-GM-73) | 0 |
| 5 | `games/sumo-bumpers` (merged) | Sumo Bumpers (`sumo_bumpers`) | 2 to 4 | tilt, A (dash) | Push others off a shrinking platform. Best of 3 rounds. | None (needs 2 players) | 2 (`TiltBody`) |
| 6 | `claude/project-thread-d6v9j3` (idea 2026-10-16, requirements written and built 2026-10-23, Manual test 30) | Tower Builder (`tower_builder`, `docs/games/tower_builder.md`, issue #96; first called Wobbly Tower) | 1 to 4 | A (drop a brick) | Turn-based and cooperative: all players build one tower, one brick each in turn. A brick swings on a crane; A drops it, or it drops when the turn time (Easy 10 s, Medium 5 s, Hard 3 s) is over. 12 bricks in all. A brick that stays is a point; a tower that topples wobbles, giggles and goes on with the lower tower, and the points stay (REQ-GM-83). | Bricks that stayed; the score only, no medal for one player (REQ-GM-73) | 0 |
| 7 | `games/tennis` (requirements written 2026-10-16, built 2026-10-17, Manual test 25) | Tennis (`tennis`, `docs/games/tennis.md`) | 1 to 4 | swing (to a side to aim), A (serve toss) | Real tennis counting (setting Scoring: Real, first to 3 games, or Quick, first to 5 points; REQ-TN-10, 19). The character runs by itself, the player only swings. 1v1, 2v1 or 2v2 on the regular court. Server tosses with A and swings top to bottom. A miss gives the other side a point, nothing is taken away (REQ-GM-83). | Rally with a friendly ball machine; the longest rally is the score, no medal for one player (REQ-GM-73) | 0 |
| 8 | `games/mini-golf` (requirements written 2026-10-17) | Mini Golf (`mini_golf`, `docs/games/mini_golf.md`) | 1 to 4 | swing (power), phone direction (aim, locks at the backswing) | Turns: each player putts once in slot order, only the current golfer is on screen. 5 hole designs made in advance; the setting picks 1 to 5 holes (default 3). Pick up after 6 strokes, water costs nothing. Fewest strokes wins. Difficulty changes the aim and power help. | Fewest strokes against par; the score only, no medal for one player (REQ-GM-73) | 0 (uses the shared `swing_detector.gd`: aim lock and power) |
| 9 | `claude/project-thread-nlcjhu` (requirements written and built 2026-10-24, Manual test 31; issue #97) | Freeze Dance (`freeze_dance`) | 1 to 4 | shake, then hold still | Music plays and you wiggle the phone; when it stops, hold still. A mover gets no points for that song, dances again in the next one and keeps the points (REQ-GM-83). | Survive more stops; the score only, no medal for one player (REQ-GM-73) | 0 (needs a stillness check on the phone) |
| 11 | `claude/project-thread-hfg6z1` (requirements written and built 2026-10-23, Manual test 27) | Air Hockey (`air_hockey`, `docs/games/air_hockey.md`, issues #101, #102) | 1 to 4 phones, 2 play | tilt, A (enroll) | Head to head on a table, first to 3 to 10 goals (setting). The two players enroll with A at every match start. | One phone: ROBO, the first bot (`scripts/game/bot.gd`), plays the other seat; Difficulty changes ROBO only. No medal (decision 2026-10-23) | 0 |
| 12 | `claude/project-thread-xuoavw` (requirements written and built 2026-10-24, Manual test 32) | Bumper Cars (`bumper_cars`, `docs/games/bumper_cars.md`, issue #99) | 2 to 4 | tilt | Fun-fair rink with bumper cars. Drive over gold stars; a fast bump makes both cars drop a star that rolls away. 60 s, most stars win. Nobody is out (REQ-GM-83). Difficulty changes the rink size and the stars on the floor. | None (needs 2 players) | 1 (`TiltBody`) |
| 13 | merged as PR #105 (built 2026-10-23, Manual test 29, issue #98) | Sheep Herding (`sheep_herding`, `docs/games/sheep_herding.md`) | 1 to 4 | tilt | Co-op: each player is a dog that herds the sheep into one gate before the time ends. Solo shows the number of sheep, no medal (REQ-GM-73); 2 to 4 players tie for 1st and have the gold medal. | Same game, score only | 0 |
| 14 | built 2026-10-23, Manual test 28, issue #100 | Whack-a-Mole (`whack_a_mole`, `docs/games/whack_a_mole.md`) | 1 to 4 | tilt (ring), A (bonk) | Shared 9 holes: bonk the moles, 10 points, 50 for the golden mole, 60 s, most points win. | Score attack; no medal for one player | 0 |

Status (2026-10-09): branch 1 is merged (PR 13). It also brought the settings view with Difficulty for the maze, Snowball Splat and
Marble Race, generated Marble Race tracks, and the lost-phone hold card. All of it still needs the tests on a device (`docs/MANUAL_TESTS.md`).
The values in the difficulty tables, the pointer range and the generated tracks are first guesses. Branch 2 (Paint Grab, with `TiltBody`) is merged (PR 14). Branch 5 (Sumo Bumpers) is merged; Dodge Storm and Tilt Snake were dropped from the plan (issue #95; Dodge Storm stays only as a later candidate, see the end of this file).
Each of them needs a settings view and a difficulty table (REQ-GM-90, 91) before it is done.

Order and dependencies:
- Branch 0 is merged first. Branches 1 and 2 need only branch 0, so they do not wait for each other.
- Snowball Splat goes first because it has the biggest unknown: pointer drift and calibration. It reads `pointer()`, not tilt, so it does not use `TiltBody`.
- `TiltBody` is built in the Paint Grab branch, with its first user. Sumo Bumpers reuses it, so they start after Paint Grab is merged.
  (If one of them has to start earlier, `TiltBody` moves into its own small branch before all of them.)

## Games for children too

Decision (2026-10-09, after the first try of "Target Shoot"): all games are also for children (REQ-GM-80 to 84 in `docs/GAME_REQUIREMENTS.md`).
No violence against anything alive, no blood and nothing scary (REQ-GM-81): made-up friendly characters, bananas, bumpers, funny reactions. Toy beams at lifeless things (rocks) are fine (Star Shield). A miss or a fall costs nothing. Large and slow at the start.
What this means for the games that are not built yet. The decision is made in the requirements file of each game:

| Game | Check against REQ-GM-80 to 84 |
|------|--------------------------------|
| Paint Grab | Fine: roll and paint. Use bright, friendly colors. |
| Tower Builder (was Wobbly Tower) | Fine: soft, colorful bricks. A fall is funny, not a loss, and nobody loses a point. It is a turn-based game (Pin Pals and Mini Golf are turn-based too): the TV shows whose turn it is, and the wait is the turns of the others (a note in `docs/games/tower_builder.md`, REQ-GM-83).
| Sumo Bumpers | Cartoon bumpers that bounce each other off a platform. A player who falls off comes back in the next round (a round is short). No fighting words. |

## Rules that apply to every game branch

Checked against `main` on 2026-10-08.

- A game has a settings view with Difficulty and a table of what Easy, Medium and Hard mean in its requirements file (REQ-GM-90, 91). The chosen value is yellow (REQ-GM-97). The game gets it as the prop `difficulty`; Try again keeps it. The score of a solo game belongs to a difficulty and has no medal (REQ-GM-73, REQ-GM-95).
- Leaving a game in progress asks first (REQ-GM-31a). A game overrides `_can_open_menu()` (or `_in_progress()`) to say when it is over.
- A ball-like player object has only the slot color (no number, no avatar), the HUD has one leader chip, and the countdown has no name tags (removed 2026-10-21; REQ-GM-46, FD-21 leader chip).
- Key objects are at least 48 px high and use no pale grey (REQ-GM-47d, 47e). All text is 28 px or larger (REQ-GM-41).
- On the phone, A is green and B is red (REQ-FL-52). A game states what A and B do, or that it has none (the `pad` list of its registry entry, REQ-GM-37a). Recenter is not a game action: the RECENTER button does it (REQ-GM-37).
- Hints use `Shell.hint` (dark plate).

## Cost of each game branch

1. Requirements file `docs/games/<id>.md` (from `TEMPLATE.md`), written before the code. There are no medal tiers for a single player, so none are listed (REQ-GM-73).
2. The game, the registry entry (`doc`, `description`, `tile`, `min_players`, `max_players`, `settings`) and the tile (`tools/make_tiles.gd`, with a scene that shows action, for example 4 players).
3. A check in `tests/smoke_tv.gd` and unit tests of the rules: score, collision, what wins, a player who leaves (REQ-GM-60, 61).
4. At least 80% line coverage for each script (`GODOT=<path> tools/coverage.sh`), clean `gdlint`, passing tests.
5. A section in `docs/MANUAL_TESTS.md` (REQ-GM-62), and a row in the status table of `docs/GAME_REQUIREMENTS.md`.
6. A pull request only when the user asks. After it, the `review` skill runs and posts its findings as one comment.

## Later candidates

Dodge Storm (hazards fall, the last player standing wins; "maybe later", issue #95; it needs a rule that keeps nobody out, REQ-GM-83) and Hot Potato (tag). Hot Potato needs a team rule or bots to work with few players, so it waits. Air Hockey 1v1 is built (branch 11); a 2v2 version is not planned.

## Open questions

- Saved scores: decided (profiles on the phone, personal bests, FD-22). Open: a late phone with a profile that is already in the room.
