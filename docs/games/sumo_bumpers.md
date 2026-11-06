# Sumo Bumpers (`sumo_bumpers`)

Type: 2D. Players: 2 to 4. Input: tilt (`PlayerInput.tilt()`), A (dash).
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
Code: `scripts/game/sumo_bumpers/`, with the shared helper `scripts/game/tilt_body.gd`. Plan: `docs/GAMES_ROADMAP.md` (branch 5).

## Goal

Each player tilts a phone to roll a round, friendly **bumper** (a penguin in the player color) on a
round grass island that floats in the sky. The bumpers bounce off each other. The platform shrinks all the time, so the bumpers come
closer to the edge. A bumper that rolls over the edge falls with a funny spin ("Whee!") and waits for the next round. The last bumper on
the platform wins the round and gets a point. A match has 3 rounds. The player with the most points after 3 rounds wins. Nobody is hurt:
a bumper that falls is back in the next round. The game needs 2 players or more.

Registry entry: `description` (one line) and `tile` (`assets/tiles/sumo_bumpers.png`, made by `tools/make_tiles.gd`), see REQ-GM-7.
Visual language: shell, player colors, pixel world (REQ-GM-45, 46, 47i to 47n, 48, 49). Check the tile next to the Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 15). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |
| REQ-GM-80 to 84 | Note | Content: friendly bumpers that bounce, no fighting words. A bumper that falls spins and shrinks ("Whee!"), is back in the next round, and waits only until the round is over, which is short (REQ-SB-9). Text is positive. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Match and rounds

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SB-1 | A match has 3 rounds. Each round starts at once, with no countdown (REQ-GM-35: the game shows no timer), with the title "Round 1", "Round 2", "Round 3" in the bar. The bumpers are on their start places and the pose of each phone is the center at the start of a round. | Done | smoke_sumo |
| REQ-SB-2 | The bumpers start on a circle around the middle of the platform, spread evenly, at the same distance from the middle (REQ-GM-25). Every round starts again like this, and all bumpers are back, also the ones that fell. | Done | run_tests, smoke_sumo |
| REQ-SB-3 | A round ends when one bumper is left, or when none is left in the same moment. The last bumper gets 1 point. When the last bumpers fall in the same frame, all of them get the point. | Done | run_tests, smoke_sumo |
| REQ-SB-4 | After a round, a banner names the player that won it (or says "Round draw!"), for 2.5 s. Then the next round starts, or the match ends. | Done | smoke_sumo |
| REQ-SB-5 | After round 3 the result menu is `open_results()` (REQ-GM-72) with the points: ranking, "X wins!" or "Tie!", Try again, New game, Back to menu. The score text is "N points". | Done | smoke_sumo |

Platform and movement

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SB-6 | The platform is a disk in the middle of the play area. Its radius falls in a straight line from its start radius to the least radius in the shrink time (REQ-SB-20). It does not stop before the round is over: at the least radius two bumpers do not fit, so every round ends. After the first fall of a round the platform shrinks 2.5 times as fast (`FALL_SPEEDUP`), so that a bumper that fell waits at most 40 percent of the shrink time: 20 s on Easy, 16 s on Medium, 12 s on Hard (REQ-GM-83, about 20 s at most). | Done | run_tests, auto_sumo |
| REQ-SB-7 | Tilt moves a bumper (`TiltBody`: acceleration, dead zone, damping, speed limit). All players have the same values (REQ-GM-24); this game moves a quarter slower than the shared body (`MOVE_ACCEL`, `MOVE_MAX`, decision of the owner, 2026-11-06). A bumper is a disk. It falls when the middle of the disk is outside the platform. | Done | run_tests, smoke_sumo, auto_sumo |
| REQ-SB-8 | Bumpers bounce off each other (`TiltBody.collide` with a high restitution) so that a hit pushes the other one away. There is no damage. A hit that is fast enough (more than 300 px/s between the two) buzzes both phones (20 ms, at most every 150 ms for one slot). | Device | run_tests (the bounce), Device (the feel and the buzz), auto_sumo (Test 15 step 13a) |
| REQ-SB-9 | Children (REQ-GM-80 to 84): the bumpers are friendly made-up creatures; a fall is funny (the bumper spins and shrinks in 0.8 s, "Whee!"); there is no loss of points for a fall; a bumper that fell is back in the next round; the wait for the next round is at most 40 percent of the shrink time, 20 s at most (REQ-SB-6, REQ-SB-20), and the hint is one line ("Tilt to bump the others off the platform! A dashes."); all texts are positive. | Done | review, auto_sumo |
| REQ-SB-10 | A press on A is a dash: the bumper gets a speed of 700 px/s in the direction of the tilt (when there is no tilt: in the direction it moves; when it does not move, nothing happens). The dash is ready again after the dash time of the difficulty (REQ-SB-20). For 0.35 s after a dash the speed limit is the dash speed, so that the dash is not cut at once. A ring around the bumper shows when it is ready. B does nothing. | Done | run_tests, smoke_sumo, auto_sumo |
| REQ-SB-11 | A dash buzzes the phone (30 ms). A fall buzzes the phone that fell (80 ms). The winner of a round gets 120 ms, and the winner of the match 400 ms. There is no start buzz. | Device | Device (the buzzes), auto_sumo |

Players and feedback

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SB-12 | A player who leaves takes the bumper out and keeps no points in the ranking (REQ-GM-21). When one player is left, the match ends at once with the result menu: a technical win with the gold medal (REQ-GM-73). When nobody is left the "No players connected" menu opens (REQ-GM-22). | Done | smoke_sumo |
| REQ-SB-13 | A lost phone pauses the match with the card of REQ-GM-30. Nothing runs during the pause (the shrink). | Done | smoke_tv (shared base class) |
| REQ-SB-14 | The leader chip (`draw_leader_chip()`, REQ-GM-46) shows the leader and the points of the leader, or TIE. Each phone shows its own points and place (REQ-FL-67). A bumper has no number on it (REQ-GM-46). The pad has A only, no Recenter box (REQ-GM-37a). | Device | smoke_sumo (points, phones), game_helpers (leader), Device (RECENTER) (Test 15 step 13b) |

Look

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SB-15 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n): it is drawn in the 480x270 view, in `sumo_look.gd`, as the **Sky Island**: a sky of 8 bands of blue (`#5eb8f0` to `#b4e4f8`) with 8 white pixel clouds that drift to the right (2 to 3 world pixels per second) under the black bar of the HUD (112 px). The platform is a round grass island with a chess pattern of two greens (`#58b838`, `#4eaa30`, squares of 6 world pixels on the grid of the screen, so the edge eats them as the island shrinks), two rings, a few flowers, an edge ring that is brown (`#b0804e`) and turns to red (`#ff5a4d`) as the island shrinks, and a brown cliff that hangs below it. Island, cliff and bumpers have a one-pixel black outline (`#101018`). A bumper is a **penguin**: 16x16 world pixels plus the outline, body in the slot color, a white belly, an orange beak and feet, eyes with pupils that step to the side it rolls (no number on it, REQ-GM-46); a ring around it shows the dash. The outline of a penguin differs from both greens and from the sky by 3:1 or more, and every slot color differs from the outline by 3:1 or more (REQ-GM-47m). A fallen penguin shrinks in 4 steps in 0.8 s, and "WHEE!" is drawn at full resolution above it on a black plate. The round banner and "WHEE!" sit on a black plate, and the countdown digits have a black shadow, because the sky is light. All text is 32 px or larger and inside the 60 px margin. The round banner is always 72 px: a long name makes it go on a second line and the plate grows (issue #288), the text is never made smaller. | Device | review, game_helpers (colors, penguin, clouds), smoke_sumo (the view), Device, auto_sumo, layout_menus |
| REQ-SB-16 | The layout comes from `size` (REQ-2D-2). It works at 1280x720 and 1920x1080: the simulation runs in 1920x1080 units and only the drawing is scaled. | Done | smoke_sumo |

Settings (REQ-GM-90 to 97)

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SB-20 | The settings view has the row Difficulty (registry `settings: []`), and `difficulty` is a prop of the game. The values are in the table below. | Done | smoke_sumo, run_tests |
| REQ-SB-21 | Personal best (REQ-GM-98): exception. The result is a win, not a number, so the game has no key and sends no result. | Done | smoke_bests |

| Difficulty | Start radius of the platform | Shrink time of a round | Dash ready again after |
|------------|------------------------------|------------------------|------------------------|
| Easy | 440 px | 50 s | 1.5 s |
| Medium | 400 px | 40 s | 2.0 s |
| Hard | 360 px | 30 s | 2.5 s |

The least radius is 30 px at every difficulty. A bumper has a radius of 34 px.

## Parameters

Values that change how the game feels. Tune them on a device (Test 15). First values:

| Name | File | First value |
|------|------|-------------|
| `ACCEL`, `DAMPING`, `MAX_SPEED`, `DEADZONE` | `tilt_body.gd` | 2200 px/s2, 1.4 1/s, 560 px/s, 0.03 (the same as Paint Grab; Sumo Bumpers overrides the acceleration and the speed limit with `MOVE_ACCEL` and `MOVE_MAX`) |
| `MOVE_ACCEL`, `MOVE_MAX` | `sumo_bumpers_game.gd` | 1650 px/s2, 420 px/s (a quarter slower than the shared body, for small children; the dash stays 700 px/s) |
| `BUMP_RESTITUTION` | `sumo_arena.gd` | 0.95 |
| `DASH_SPEED` | `sumo_arena.gd` | 700 px/s |
| `FALL_SPEEDUP` | `sumo_arena.gd` | 2.5 (the shrinking is 2.5 times as fast after the first fall) |
| `ROUNDS`, `BANNER_TIME` | `sumo_bumpers_game.gd` | 3, 2.5 s |
| Levels | `sumo_arena.gd` | table above |

## Open questions

- Is the shrink time right: is a round too long to wait for a bumper that fell first, and too short to play with 4 players?
- Is a dash of 700 px/s too strong, so that a bumper can dash through the others?
- Should a bumper that falls watch the round with a small ghost, or is the wait fine as it is?

## Sound and haptics (REQ-GM-49a to 49c, REQ-GM-43)

The song `sumo_bumpers` starts with the first round (no countdown): Heavy and comic, a march at 132 BPM, D minor. The pause and result sounds come from the base class; there is no `count` or `go` sound.

| ID | Effect | When | Sound | Status |
|----|--------|------|-------|--------|
| REQ-SB-S1 | `sumo_bump` | Two bumpers bump above the buzz speed. | Bonk | Device (test 18) |
| REQ-SB-S2 | `sumo_dash` | A bumper dashes. | Whoosh | Device (test 18) |
| REQ-SB-S3 | `sumo_fall` | A bumper falls (haptic 80 ms). | A falling slide, funny, not sad | Device (test 18) |
| REQ-SB-S4 | `sumo_round_win` | A round has a winner (haptic 120 ms). | Rising run | Device (test 18) |

Haptics on the phone of the player: no start buzz (no countdown); Bump: 20 ms; dash: 30 ms; fall: 80 ms; Round win: 120 ms; match end: 400 ms. The shrinking drone is not built.

## Languages (REQ-GM-47o)

The texts of this game are English and Hebrew: the title, the description, the hint and the result texts have a key and a Hebrew text in `assets/lang/strings.csv`. In Hebrew the HUD is mirrored by the shell (title, leader chip, timer); the "Round x of y" text uses `Shell.mx()`. The game world is not mirrored.
