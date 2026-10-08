# Games roadmap: competitive 2D games

Plan for a set of 2D minigames. Most are competitive. All except Sumo Bumpers also work with one player.
This file is a plan, not a requirements file. Each game gets its own `docs/games/<id>.md` before its code
(REQ-GM-1, REQ-GM-7). General rules: `docs/GAME_REQUIREMENTS.md`.

## Decisions

- No saved scores. How users are identified is not decided, so nothing is stored. A solo game compares the score with fixed medal tiers. The tiers reset every run.
- No bots. A game that needs opponents has `min_players` 2. Only Sumo Bumpers is like this.
- Order of work: one branch for the common helpers, then one branch for each game. Each game branch starts from the merged helpers.
- Pointer tuning (Target Shoot) is checked on a real phone and TV with the `device-test` skill.

## Why helpers first

`scripts/game/minigame.gd` has the shell (pause, result menu, countdown, leave question) but no score, rank or round clock.
Every game below needs them. They are written once, with tests, in branch 0.

| Helper | Job |
|--------|-----|
| Scoreboard | Score for each slot, ranking, ties, slot order (REQ-GM-46). Pure logic with unit tests (REQ-GM-61). |
| Round timer | A round of fixed length, driven by `delta` only (REQ-GM-13), with a visible clock. |
| Ranked result | A result menu with the ranking, slot-color chips, Restart and Back to menu (REQ-GM-34). |
| Medal tiers | Solo rule: bronze, silver and gold score limits for one game. Shown on the result menu. Not saved. |

## Branches

| # | Branch content | Players | Input | Competitive mode | Solo mode |
|---|----------------|---------|-------|------------------|-----------|
| 0 | Common helpers | | | | |
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
- On the phone, A is green and B is red (REQ-FL-52). A game states what B does, or that it does nothing.
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
