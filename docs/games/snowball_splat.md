# Snowball Splat (`snowball_splat`)

Type: 2D. Players: 1 to 4. Input: pointer (`PlayerInput.pointer()`), A (throw), Recenter.
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
Code: `scripts/game/snowball_splat/`. Plan: `docs/GAMES_ROADMAP.md` (branch 1). It replaces "Target Shoot" (2026-10-09): the first game
was not playable (small, fast targets) and it was a shooting game.

## Goal

Each player points a phone at the TV like a remote control. A cursor in the player color follows the phone. Big, friendly **Puffs**
(round, fuzzy, made-up creatures with big eyes) float slowly across a snowy night sky. A press on A throws a snowball at the
cursor. A Puff that is hit is covered with snow, giggles and floats away. The player with the most points after 60 seconds wins.
With one player, the score is compared with medal tiers. A miss costs nothing.

Registry entry: `description` (one line) and `tile` (`assets/tiles/snowball_splat.png`, made by `tools/make_tiles.gd`), see REQ-GM-7.
Visual language: shell, player colors, toy-like world (REQ-GM-45 to 49). Check the tile next to the Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-37 | Note | Recenter is more important here than in the other games: the pointer uses the yaw of the gyroscope, and yaw drifts (RISKS A4). The hint says so (REQ-SS-12). |
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 10). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |
| REQ-GM-80 to 84 | Note | Content: snowballs at made-up friendly creatures. No violence, no scary things (REQ-SS-17). A miss costs nothing (REQ-SS-5). Text is positive. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Round

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-1 | A round has a countdown of 3 s and then 60 s of play (`RoundClock`). Cursors move during the countdown, but a throw does nothing. The visible clock shows the seconds left. At 0 the round ends and the result menu opens (REQ-SS-15). | Done | smoke_tv |
| REQ-SS-2 | At GO every phone recenters, so the pose held in the countdown is the center of the screen. The Recenter button works during the round. | Done | smoke_tv |

Aim and throw

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-3 | The cursor of a player is at `pointer()` mapped to the play area: -1 is the left or top edge, +1 the right or bottom edge, 0 is the center. All players use the same mapping and the same range (REQ-GM-24). The play area is the screen inside the 60 px margin, under the HUD. The cursor stays inside it. | Done | game_rules (mapping), smoke_tv |
| REQ-SS-4 | A press on A (an edge: `button_pressed`) throws one snowball at the place of the cursor at that moment. Holding A does not repeat. A throw does nothing while the game is paused, in the countdown, or after the round. B does nothing. A player can throw again after 0.3 s (reload). A press inside the reload time is ignored. | Done | smoke_tv |
| REQ-SS-5 | A miss costs nothing: no points are lost, the player does not wait longer, and the cursor does not change. A snowball that hits no Puff makes a small white poof in the snow. | Done | smoke_tv |
| REQ-SS-6 | The snowball flies for 0.12 s from the snow at the bottom of the play area to the place of the cursor (a small arc). It is a picture. The hit is decided when the snowball lands (REQ-SS-10). Snowballs land in the order they were thrown. | Done | smoke_tv |

Puffs

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-7 | There are two kinds. Puff: 10 points, radius 100 px, speed 100 px/s. Little Puff: 25 points, radius 72 px, speed 160 px/s. No Puff is faster than 200 px/s at Medium (Hard multiplies the speed, REQ-SS-20). Sizes and speeds are for 1920x1080. | Done | game_rules |
| REQ-SS-8 | The play area has 3 lanes (top, middle, bottom). A lane has one direction and one kind: the top lane has Little Puffs flying right, the middle lane has Puffs flying left, the bottom lane has Puffs flying right. A Puff enters at the edge of its lane, flies across in a straight line with a gentle up and down wave (28 px, 2.4 s for one wave), and leaves at the other edge. A Puff that leaves is not a loss. Two Puffs of one lane never overlap (a new one enters only when the one before it is 380 px or more from the edge). | Done | game_rules |
| REQ-SS-9 | A new Puff comes every 1.5 s while fewer than 3 + the number of players Puffs are on the screen. The kind is chosen with the weights 70 (Puff) and 30 (Little Puff), and then a free lane of that kind. If there is no free lane, no Puff comes at that time. The first Puff comes at once. The color of a Puff (cyan, pink or green) is chosen at random. The Puffs are the same for all players. Everything comes from one `RandomNumberGenerator`. A test can fix it with `start_props.seed`. Without a seed, a new round has new Puffs. Restart keeps the seed that was given (REQ-GM-32). | Done | game_rules, smoke_tv |

Hit and score

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-10 | A snowball hits a Puff when the place where it lands is inside the radius of the Puff plus 12 px, at the time of landing. When two Puffs are hit, the one with the nearer center is hit. A hit takes the Puff and adds its points to the thrower. A score never goes down. | Done | game_rules, smoke_tv |
| REQ-SS-11 | When two snowballs land on the same Puff, the one that was thrown first wins. The other one is a miss (REQ-SS-5), unless it hits another Puff. Throws are handled in the order they arrived, not in slot order (REQ-GM-24). | Done | smoke_tv |

Look and feedback

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-12 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n), drawn in the 480x270 view: a blue `#1b3a8a` sky with 48 star pixels, a dark board `#12205a` with a one-pixel black outline and square flakes of one or two world pixels that fall slowly (in game time, so they stop in a pause), and a strip of white snow at the bottom. A Puff is a round fuzzy body with tufts and small wings that flap in whole world pixels, a one-pixel black outline, big white eyes with dark pupils that look the way it flies, and a smile; the wings have the color of the body. Puffs are cyan `#3ddcff`, pink `#ff3d8b` or green `#57cc99`. A Little Puff is yellow `#ffd23f`. A cursor is a ring in the slot color with a black outline, and a badge of 48 px (12 world pixels) in the slot color with a one-pixel black outline; the slot number on the badge is drawn by the HUD at full resolution (`Shell.ball_number`, REQ-GM-46). A white snowball is in the middle of the ring when the player can throw. A snowball in flight is white with a black outline. A poof of a missed snowball is a white ring that grows in 3 hard steps (no fade). Every key object is 48 px high or more at 1920x1080 (the smallest Puff is 144 px). The title, timer (a box 208 px wide, so that 4 chips of 270 px fit in one row), chips (name and score, in slot order, the score is never cut, REQ-GM-46), countdown, hints and menus come from the shell. The hint says "Point at the TV and press A to throw a snowball. Recenter if the cursor drifts." | Done | game_rules (visual rules), smoke_tv (the view), Screenshot |
| REQ-SS-13 | A hit Puff is covered with snow on top, its eyes close happily, and it floats up and away in 0.8 s. The points show above it ("+10", in the color of the player, drawn by the HUD at full resolution). Nothing in a hit is violent or sad (REQ-GM-81). | Done | smoke_tv, Screenshot |
| REQ-SS-14 | Haptics (REQ-GM-43): a throw buzzes the thrower 15 ms, a hit 40 ms (the gap between two buzzes is 100 ms or more, `Haptics`). GO buzzes every phone 60 ms. The winner buzzes 400 ms at the end. There is no buzz for a miss. | Done | smoke_tv, Device (feel) |
| REQ-SS-15 | The layout comes from `size` (REQ-2D-2). It works at 1280x720 and 1920x1080: the play area and the sizes of the Puffs scale with the screen. The cursor and the HUD keep their pixel size. | Done | game_rules (scale) |

End and players

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-16 | The result menu is `open_results()` (REQ-GM-72) with a `Scoreboard` (higher is better): ranking, "X wins!" or "Tie!", Restart, Back to menu. With one player it shows the medal for the tiers [150, 300, 450] (bronze, silver, gold, REQ-GM-73). The tiers are open tuning values. A player who leaves takes the cursor and the score out, and the round goes on. A lost phone pauses the round with the card of REQ-GM-30. When the last player leaves, the menu "No players connected" opens (REQ-GM-21, 22). | Done | smoke_tv |
| REQ-SS-17 | Children (REQ-GM-80 to 84): the creatures are made up and friendly, the hit is funny, a miss costs nothing, no player is out of the round, the hint is one line, the Puffs are large and slow, and every text is positive. | Done | Review, Device (with a child, Test 10 item 9) |

### Settings and difficulty (built 2026-10-09)

REQ-GM-90 to 96 apply. The settings view has one row: Difficulty. As it grows, the Puffs move faster and there are fewer of them. The size of the Puffs, the points, the hit rule, the pointer range and the 60 s round are the same at every difficulty, and a miss costs nothing at every difficulty (REQ-SS-5, REQ-GM-96).

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-20 | The game has the settings view with the row Difficulty (REQ-GM-90, 91; registry `settings: []`), and `difficulty` is a prop of the game. Difficulty changes three values, see the table below: the speed of the Puffs (a factor on the speed of each kind), the number of Puffs on the screen (`MAX_BASE`, plus the number of players as before), and the time between two new Puffs (`SPAWN_EVERY`). | Done | game_rules, smoke_settings |
| REQ-SS-21 | The medal tiers (REQ-GM-73) belong to the difficulty. A result is judged by the tiers of the difficulty that was played, and the medal title of one player names it: "Silver medal! (Hard)". | Done | game_rules (tiers), smoke_tv |
| REQ-SS-22 | At every difficulty the lanes never overlap (REQ-SS-8), and at least one Puff is on the screen most of the time, also on Hard with 1 player. | Done | game_rules |

| Difficulty | Speed factor | Puffs on screen (`MAX_BASE`, + players) | New Puff every | Medal tiers (first guess) |
|------------|--------------|------------------------------------------|----------------|---------------------------|
| Easy | 0.7 | 4 | 1.2 s | [170, 340, 510] |
| Medium | 1.0 | 3 | 1.5 s | [150, 300, 450] |
| Hard | 1.5 | 2 | 2.0 s | [120, 240, 360] |

The values, and especially the tiers, are first guesses and are tuned on a device (Test 10). Fewer Puffs on Hard makes each Puff worth more attention, and faster Puffs ask for better aim.

## Parameters

Values that change how the game feels. Tune them on a device (Test 10). First values:

| Name | File | First value |
|------|------|-------------|
| `ROUND_TIME`, `COUNTDOWN` | `snowball_splat_game.gd` | 60 s, 3 s |
| `RELOAD`, `FLIGHT_TIME` | `snowball_splat_game.gd` | 0.3 s, 0.12 s |
| `SPAWN_EVERY`, `MAX_BASE`, `ENTRY_GAP`, `HIT_SLOP` | `puff_field.gd` | 1.5 s, 3 (+ players), 380 px, 12 px |
| Kinds (points, radius, speed, weight) and the lanes | `puff_field.gd` | REQ-SS-7, 8, 9 |
| `LEVELS` (speed factor, `max_base`, `spawn_every`, medal tiers for each difficulty) | `puff_field.gd` | REQ-SS-20 |
| `pointer_range_deg` (sensitivity) | `scripts/input/orientation.gd` | 25 (half range of the pointer in degrees) |

## Open questions

- Is a half range of 25 degrees good from the sofa? Too small is shaky, too large needs a big arm movement. This is the main thing to test.
- Does the yaw drift (gyro only) stay small enough for a round of 60 s? If not, a short smoothing or a stronger bias learning is needed in `orientation.gd`.
- Are the Puffs slow and big enough for a child of 5 to 6 years? Are they too slow for an adult? The speeds, sizes, medal tiers and the 60 s are first guesses.
- The name of the game and of the creatures (Puff) is a first idea.
