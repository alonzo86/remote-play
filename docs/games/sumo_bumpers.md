# Sumo Bumpers (`sumo_bumpers`)

Type: 2D. Players: 2 to 4. Input: tilt (`PlayerInput.tilt()`), A (dash), Recenter.
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
Code: `scripts/game/sumo_bumpers/`, with the shared helper `scripts/game/tilt_body.gd`. Plan: `docs/GAMES_ROADMAP.md` (branch 5).

## Goal

Each player tilts a phone to roll a round, friendly **bumper** (a made-up cartoon creature with big eyes, in the player color) on a
round platform that floats in the sky. The bumpers bounce off each other. The platform shrinks all the time, so the bumpers come
closer to the edge. A bumper that rolls over the edge falls with a funny spin ("Whee!") and waits for the next round. The last bumper on
the platform wins the round and gets a point. A match has 3 rounds. The player with the most points after 3 rounds wins. Nobody is hurt:
a bumper that falls is back in the next round. The game needs 2 players or more.

Registry entry: `description` (one line) and `tile` (`assets/tiles/sumo_bumpers.png`, made by `tools/make_tiles.gd`), see REQ-GM-7.
Visual language: shell, player colors, toy-like world (REQ-GM-45 to 49). Check the tile next to the Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-73 | Exception | The game needs 2 players (registry `min_players` 2), so it has no solo mode and no medal tiers. |
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 15). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |
| REQ-GM-80 to 84 | Note | Content: friendly bumpers that bounce, no fighting words. A bumper that falls spins and shrinks ("Whee!"), is back in the next round, and waits only until the round is over, which is short (REQ-SB-9). Text is positive. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Match and rounds

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SB-1 | A match has 3 rounds. Each round starts with a countdown of 3 s (`RoundClock`) and the title "Round 1", "Round 2", "Round 3". The bumpers cannot move during the countdown (REQ-GM-35). | Open | smoke_sumo |
| REQ-SB-2 | The bumpers start on a circle around the middle of the platform, spread evenly, at the same distance from the middle (REQ-GM-25). Every round starts again like this, and all bumpers are back, also the ones that fell. | Open | run_tests, smoke_sumo |
| REQ-SB-3 | A round ends when one bumper is left, or when none is left in the same moment. The last bumper gets 1 point. When the last bumpers fall in the same frame, all of them get the point. | Open | run_tests, smoke_sumo |
| REQ-SB-4 | After a round, a banner names the player that won it (or says "Round draw!"), for 2.5 s. Then the next round starts, or the match ends. | Open | smoke_sumo |
| REQ-SB-5 | After round 3 the result menu is `open_results()` (REQ-GM-72) with the points: ranking, "X wins!" or "Tie!", Restart, Settings, Back to menu. The score text is "N points". | Open | smoke_sumo |

Platform and movement

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SB-6 | The platform is a disk in the middle of the play area. Its radius falls in a straight line from its start radius to the least radius in the shrink time (REQ-SB-20). It does not stop before the round is over: at the least radius two bumpers do not fit, so every round ends. | Open | run_tests |
| REQ-SB-7 | Tilt moves a bumper (`TiltBody`: acceleration, dead zone, damping, speed limit). All players have the same values (REQ-GM-24). A bumper is a disk. It falls when the middle of the disk is outside the platform. | Open | run_tests, smoke_sumo |
| REQ-SB-8 | Bumpers bounce off each other (`TiltBody.collide` with a high restitution) so that a hit pushes the other one away. There is no damage. A hit that is fast enough (more than 300 px/s between the two) buzzes both phones (20 ms, at most every 150 ms for one slot). | Open | run_tests, smoke_sumo |
| REQ-SB-9 | Children (REQ-GM-80 to 84): the bumpers are friendly made-up creatures; a fall is funny (the bumper spins and shrinks in 0.8 s, "Whee!"); there is no loss of points for a fall; a bumper that fell is back in the next round; the wait for the next round is at most the rest of the shrink time (REQ-SB-20), and the hint is one line ("Tilt to bump the others off the platform! A dashes."); all texts are positive. | Open | review |
| REQ-SB-10 | A press on A is a dash: the bumper gets a speed of 700 px/s in the direction of the tilt (when there is no tilt: in the direction it moves; when it does not move, nothing happens). The dash is ready again after the dash time of the difficulty (REQ-SB-20). A ring around the bumper shows when it is ready. B does nothing. | Open | run_tests, smoke_sumo |
| REQ-SB-11 | A dash buzzes the phone (30 ms). A fall buzzes the phone that fell (80 ms). The winner of a round gets 120 ms, and the winner of the match 400 ms. GO buzzes every phone (60 ms). | Open | Device |

Players and feedback

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SB-12 | A player who leaves takes the bumper out and keeps no points in the ranking (REQ-GM-21). When one player is left, the match ends at once with the result menu. When nobody is left the "No players connected" menu opens (REQ-GM-22). | Open | smoke_sumo |
| REQ-SB-13 | A lost phone pauses the match with the card of REQ-GM-30. Nothing runs during the pause (the shrink, the countdown). | Open | smoke_tv (shared base class) |
| REQ-SB-14 | The chips (`Shell.player_chips`, in slot order) show the points of each player. A bumper has its slot number on it (`Shell.ball`, REQ-GM-46). The RECENTER button recenters (REQ-GM-37). | Open | smoke_sumo |

Look

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SB-15 | Visual language (REQ-GM-45 to 49). The platform is a round, light disk with a dark outline and a hard shadow, its edge ring gets red when it is small (a warning without text). The background is from the Party Pop set. All text is 28 px or larger and inside the 60 px margin. | Open | review, Device |
| REQ-SB-16 | The layout comes from `size` (REQ-2D-2). It works at 1280x720 and 1920x1080: the simulation runs in 1920x1080 units and only the drawing is scaled. | Open | smoke_sumo |

Settings (REQ-GM-90 to 97)

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SB-20 | The settings view has the row Difficulty (registry `settings: []`), and `difficulty` is a prop of the game. The values are in the table below. | Open | smoke_sumo |

| Difficulty | Start radius of the platform | Shrink time of a round | Dash ready again after |
|------------|------------------------------|------------------------|------------------------|
| Easy | 430 px | 30 s | 1.5 s |
| Medium | 380 px | 24 s | 2.0 s |
| Hard | 330 px | 18 s | 2.5 s |

The least radius is 30 px at every difficulty. A bumper has a radius of 34 px.

## Parameters

Values that change how the game feels. Tune them on a device (Test 15). First values:

| Name | File | First value |
|------|------|-------------|
| `ACCEL`, `DAMPING`, `MAX_SPEED`, `DEADZONE` | `tilt_body.gd` | 2200 px/s2, 1.4 1/s, 560 px/s, 0.03 (the same as Paint Grab) |
| `BUMP_RESTITUTION` | `sumo_arena.gd` | 0.95 |
| `DASH_SPEED` | `sumo_arena.gd` | 700 px/s |
| `ROUNDS`, `COUNTDOWN`, `BANNER_TIME` | `sumo_bumpers_game.gd` | 3, 3 s, 2.5 s |
| Levels | `sumo_arena.gd` | table above |

## Open questions

- Is the shrink time right: is a round too long to wait for a bumper that fell first, and too short to play with 4 players?
- Is a dash of 700 px/s too strong, so that a bumper can dash through the others?
- Should a bumper that falls watch the round with a small ghost, or is the wait fine as it is?
