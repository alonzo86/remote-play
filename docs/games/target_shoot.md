# Target Shoot (`target_shoot`)

Type: 2D. Players: 1 to 4. Input: pointer (`PlayerInput.pointer()`), A (fire), Recenter.
General requirements: `docs/GAME_REQUIREMENTS.md`. Exceptions to them are listed in the first section.
Code: `scripts/game/target_shoot/`. Plan: `docs/GAMES_ROADMAP.md` (branch 1).

## Goal

Each player points a phone at the TV like a remote control. A cursor in the player color follows the phone. Targets appear on the
screen, the same for all players. A press on A shoots at the cursor. The first shot that hits a target takes it and its points.
The player with the most points after 45 seconds wins. With one player, the score is compared with medal tiers.

Registry entry: `description` (one line) and `tile` (`assets/tiles/target_shoot.png`, made by `tools/make_tiles.gd`), see REQ-GM-7.
Visual language: shell, player colors, toy-like world (REQ-GM-45 to 49). Check the tile next to the Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-37 | Note | Recenter is more important here than in the other games: the pointer uses the yaw of the gyroscope, and yaw drifts (RISKS A4). The hint says so (REQ-TS-12). |
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a section for this game (Test 10). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Round

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TS-1 | A round has a countdown of 3 s and then 45 s of play (`RoundClock`). Cursors move during the countdown, but a shot does nothing. The visible clock shows the seconds left. At 0 the round ends and the result menu opens (REQ-TS-15). | Done | smoke_tv |
| REQ-TS-2 | At GO every phone recenters, so the pose held in the countdown is the center of the screen. The Recenter button works during the round. | Done | smoke_tv |

Aim and fire

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TS-3 | The cursor of a player is at `pointer()` mapped to the play area: -1 is the left or top edge, +1 the right or bottom edge, 0 is the center. All players use the same mapping and the same range (REQ-GM-24). The play area is the screen inside the 60 px margin, under the HUD. The cursor stays inside it. | Done | game_rules (mapping), smoke_tv |
| REQ-TS-4 | A press on A (an edge: `button_pressed`) fires one shot at the cursor of that player. Holding A does not repeat. A shot does nothing while the game is paused, in the countdown, or after the round. B does nothing. | Done | smoke_tv |
| REQ-TS-5 | A shot needs 0.25 s to reload. A press inside the reload time is ignored. | Done | smoke_tv |
| REQ-TS-6 | A shot that hits no target is a miss. A miss locks the fire of that player for 0.6 s in total (it includes the reload). While the fire is locked, the cursor is faded and has no center dot, and a press does nothing. A hit does not lock. | Done | smoke_tv |

Targets

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TS-7 | There are three kinds. Standard: 10 points, radius 56 px, lives 3.2 s. Small: 25 points, radius 36 px, lives 2.2 s. Decoy: -15 points, radius 48 px, lives 3.0 s. A target that lives out its time is removed without points. | Done | game_rules |
| REQ-TS-8 | A new target appears every 0.7 s while fewer than 4 + the number of players targets are on the screen. The kind is chosen with the weights 60 (standard), 25 (small), 15 (decoy). A new target is inside the play area, and its center is at least 160 px from the center of every other target. If no place is found in 12 tries, no target appears at that time. | Done | game_rules |
| REQ-TS-9 | The targets are the same for all players. Positions and kinds come from one `RandomNumberGenerator`. A test can fix it with `start_props.seed`. Without a seed, a new round has new targets. Restart keeps the seed that was given (REQ-GM-32). | Done | game_rules, smoke_tv |

Hit and score

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TS-10 | A shot hits a target when the cursor center is inside the radius of the target plus 8 px. When two targets are hit, the one with the nearer center is hit. A hit removes the target and adds its points to the player. A score never goes below 0. | Done | game_rules, smoke_tv |
| REQ-TS-11 | When two players shoot the same target, the shot that was pressed first wins. The second shot is a miss for the second player, unless it hits another target. Presses are handled in the order they arrived, not in slot order (REQ-GM-24). | Done | smoke_tv |

Look and feedback

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TS-12 | Visual language (REQ-GM-45 to 49). Background blue `#1b3a8a`. A standard target is a cyan `#3ddcff` bullseye with the dark outline. A small target is a yellow bullseye. A decoy is a pink rounded square with a dark X, so it is not known by color alone. A cursor is a ring in the slot color with the slot number, 64 px wide, with the dark outline. Every key object is 48 px high or more at 1920x1080 (the small target is 72 px). Targets grow in from small in 0.15 s. The title, timer, chips (name and score, in slot order), countdown, hints and menus come from the shell. The hint says "Point at the TV and press A. Recenter if the cursor drifts." | Done | game_rules (visual rules), Screenshot (`tools/make_tiles.gd`) |
| REQ-TS-13 | Haptics (REQ-GM-43): a hit buzzes the shooter 30 ms, a decoy 60 ms, a miss 15 ms (all with a gap of 100 ms or more, `Haptics`). GO buzzes every phone 60 ms. The winner buzzes 400 ms at the end. | Done | smoke_tv, Device (feel) |
| REQ-TS-14 | The layout comes from `size` (REQ-2D-2). It works at 1280x720 and 1920x1080: the play area and the radii of the targets scale with the screen. The cursor and the HUD (title, timer, chips) keep their pixel size. | Done | game_rules (scale) |

End and players

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TS-15 | The result menu is `open_results()` (REQ-GM-72) with a `Scoreboard` (higher is better): ranking, "X wins!" or "Tie!", Restart, Back to menu. With one player it shows the medal for the tiers [200, 350, 500] (bronze, silver, gold, REQ-GM-73). The tiers are open tuning values. | Done | smoke_tv |
| REQ-TS-16 | A player who leaves takes the cursor and the score out, and the round goes on. When the last player leaves, the menu "No players connected" opens (REQ-GM-21, 22). | Done | smoke_tv |

## Parameters

Values that change how the game feels. Tune them on a device (Test 10). First values:

| Name | File | First value |
|------|------|-------------|
| `ROUND_TIME`, `COUNTDOWN` | `target_shoot_game.gd` | 45 s, 3 s |
| `RELOAD`, `MISS_LOCK` | `target_shoot_game.gd` | 0.25 s, 0.6 s |
| `HIT_SLOP` | `target_field.gd` | 8 px |
| `SPAWN_EVERY`, `MAX_BASE`, `MIN_SPACING` | `target_field.gd` | 0.7 s, 4 (+ players), 160 px |
| Kinds (points, radius, life, weight) | `target_field.gd` | REQ-TS-7, REQ-TS-8 |
| `MEDAL_TIERS` | `target_shoot_game.gd` | [200, 350, 500] |
| `pointer_range_deg` (sensitivity) | `scripts/input/orientation.gd` | 25 (half range of the pointer in degrees) |

## Open questions

- Is a half range of 25 degrees good from the sofa? Too small is shaky, too large needs a big arm movement. This is the main thing to test.
- Does the yaw drift (gyro only) stay small enough for a round of 45 s? If not, a short smoothing or a stronger bias learning is needed in `orientation.gd`.
- Medal tiers, the decoy penalty and the sizes of the targets are first guesses.
