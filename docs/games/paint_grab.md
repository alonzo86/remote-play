# Paint Grab (`paint_grab`)

Type: 2D. Players: 1 to 4. Input: tilt (`PlayerInput.tilt()`), Recenter.
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
Code: `scripts/game/paint_grab/` and the shared helper `scripts/game/tilt_body.gd`. Plan: `docs/GAMES_ROADMAP.md` (branch 2).

## Goal

Each player tilts a phone to roll a round, friendly **paint blob** (a made-up creature with big eyes, in the player color) over a
floor of square tiles. A tile that a blob rolls over turns into the color of that blob, also when it had the color of another
player. After 60 seconds the player with the most tiles wins. With one player, the score (the share of the floor that is painted)
is compared with medal tiers. A tile that is painted over costs nothing but the tile: nobody is out and nobody waits.

Registry entry: `description` (one line) and `tile` (`assets/tiles/paint_grab.png`, made by `tools/make_tiles.gd`), see REQ-GM-7.
Visual language: shell, player colors, toy-like world (REQ-GM-45 to 49). Check the tile next to the Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 14). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |
| REQ-GM-80 to 84 | Note | Content: friendly paint blobs and colorful tiles, no fighting. A painted-over tile costs only that tile (REQ-PG-9). Text is positive. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Round

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-PG-1 | A round has a countdown of 3 s and then 60 s of play (`RoundClock`). The blobs cannot move during the countdown (REQ-GM-35). The clock is visible (`Shell.timer`). | Done | smoke_paint |
| REQ-PG-2 | The floor is a grid of square tiles (the size depends on the difficulty, REQ-PG-20). The floor is empty (no color) at the start. All players have the same floor. | Done | smoke_paint, run_tests |
| REQ-PG-3 | The blobs start in different places of the floor, apart from each other, at the same distance from the middle (REQ-GM-25). | Done | smoke_paint |
| REQ-PG-4 | A blob paints the tile under its middle at every frame. A tile has one color at a time: the one of the blob that was on it last. A tile that is painted again by the same player stays as it is. | Done | run_tests, smoke_paint |
| REQ-PG-5 | The round ends when the time is up. The score of a player is the number of tiles in the color of that player at that moment (`Scoreboard`, higher is better). Players with the same score share the rank (a tie). | Done | run_tests, smoke_paint |
| REQ-PG-6 | The result menu is `open_results()` (REQ-GM-72): ranking, "X wins!" or "Tie!", Restart, Settings, Back to menu. The score text is the number of tiles. With one player it shows a medal (REQ-PG-21). | Done | smoke_paint |

Movement

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-PG-7 | Tilt gives the acceleration of the blob (`TiltBody`): a dead zone, a damping so that the blob slows down by itself, a speed limit, and a soft bounce at the edge of the floor. All players have the same values (REQ-GM-24). The blob never leaves the floor. | Device | run_tests (rules), Device (feel) |
| REQ-PG-8 | Blobs bounce off each other softly (no one is pushed through a wall). A blob is at least 48 px high on the screen (REQ-GM-47e) and shows its slot number. | Done | run_tests |
| REQ-PG-9 | Children (REQ-GM-80 to 84): the blobs are friendly made-up creatures, the paint is colorful and funny, a painted-over tile costs only that tile, no player is out or waits, the hint is one line ("Tilt your phone to roll and paint the tiles!"), the blobs are large and slow at the start, and all texts are positive. | Done | review |

Players and feedback

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-PG-10 | A player who leaves takes the blob out. The tiles of that player stay on the floor and count for nobody. The round goes on with the others (REQ-GM-21). When nobody is left the "No players connected" menu opens (REQ-GM-22). | Done | smoke_paint |
| REQ-PG-11 | A lost phone pauses the round with the card of REQ-GM-30. The clock does not run during the pause. | Done | smoke_tv (shared base class) |
| REQ-PG-12 | Haptics (REQ-GM-43): GO buzzes every phone (60 ms). Painting a tile that had the color of another player buzzes the player that painted (20 ms, at most every 150 ms for one slot, `Haptics`). The end buzzes the winner (400 ms). | Device | Device (the buzz) |
| REQ-PG-13 | The chips (`Shell.player_chips`, in slot order) show the number of tiles of each player and are updated at every change. | Done | smoke_paint (scores) |
| REQ-PG-14 | The RECENTER button recenters the tilt of that player (REQ-GM-37). A and B do nothing, and the hint says so only if a player asks (it is not on the screen). | Device | Device (RECENTER) |

Look

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-PG-15 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n), drawn in the 480x270 view: a black sky with 48 star pixels, a dark floor board `#2a1070` with a one-pixel black outline, empty tiles `#3a1c97`, painted tiles in the flat slot color (no lighter edge). A tile is a whole number of world pixels wide, so all gaps are one world pixel (the floor is as big as fits, in steps of 4 px per tile). A blob has a one-pixel black outline, square eyes, and its slot number drawn by the HUD at full resolution on it (`Shell.ball_number`). All text is 32 px or larger. Everything stays inside the 60 px margin. | Device | review, smoke_paint (the view, the grid), Device |
| REQ-PG-16 | A tile that is painted pops (it is one world pixel wider on each side for 0.15 s, a hard step), so the painting can be seen. A blob has square eyes with pupils that step to the side it rolls. | Device | smoke_paint (pop), Device |
| REQ-PG-17 | The layout comes from `size` (REQ-2D-2). It works at 1280x720 and 1920x1080. | Done | smoke_paint |

Settings (REQ-GM-90 to 97)

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-PG-20 | The settings view has the row Difficulty (registry `settings: []`), and `difficulty` is a prop of the game. The values are in the table below. | Done | smoke_paint |
| REQ-PG-21 | One player: the score is the share of the floor that is painted at the end, in percent, rounded down. The medal tiers `[bronze, silver, gold]` belong to the difficulty (REQ-GM-73, 95); the title of the medal names the difficulty. | Done | smoke_paint, run_tests |

| Difficulty | Floor (columns x rows) | Tile size | Blob speed limit | Medal tiers (percent, first guess) |
|------------|------------------------|-----------|------------------|------------------------------------|
| Easy | 12 x 7 | about 124 px | 0.8 of Medium | [35, 55, 75] |
| Medium | 16 x 9 | about 96 px | 1.0 | [30, 50, 70] |
| Hard | 20 x 11 | about 79 px | 1.25 | [25, 40, 55] |

The tile size is what fits inside the margin and under the HUD at 1920x1080. The brush is the blob itself: a bigger floor with smaller tiles and a faster blob is harder to cover, and every level has the same 60 s.

Shared code

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-PG-30 | `scripts/game/tilt_body.gd` (`TiltBody`) is a helper without nodes: position, velocity, tilt acceleration, dead zone, damping, speed limit, bounce at a rectangle, and the bounce between two bodies. The Dodge Storm, Tilt Snake and Sumo Bumpers branches use it too. The maze and the race keep their own models for now (a device test is needed to change them). | Done | run_tests |

## Parameters

Values that change how the game feels. Tune them on a device (Test 14). First values:

| Name | File | First value |
|------|------|-------------|
| `ROUND_TIME`, `COUNTDOWN` | `paint_grab_game.gd` | 60 s, 3 s |
| `ACCEL`, `DAMPING`, `MAX_SPEED`, `DEADZONE`, `BOUNCE` | `tilt_body.gd` / game | 2200 px/s2 for tilt 1.0, 1.4 1/s, 560 px/s, 0.03, 0.35 |
| Blob radius | `paint_grab_game.gd` | 34 px (68 px wide) |
| Levels | `paint_grab_game.gd` | table above |

## Open questions

- Is a round of 60 s right for 4 players on a floor of 144 tiles? Is it too hard to cover 70% alone on Medium?
- Does the blob feel good, or does it need a stronger damping so it is easy to steer for a child?
- Should the blobs also paint a ring around them (a bigger brush) on Easy, so a child fills the floor faster?
