# Banana Party (`snowball_splat`)

Type: 2D. Players: 1 to 4. Input: pointer (`PlayerInput.pointer()`), A (throw), Recenter.
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
The id, the folder, the best keys and the `snow_*` sound names keep the old name (Snowball Splat), so that saved personal bests stay valid.
Code: `scripts/game/snowball_splat/`. Plan: `docs/GAMES_ROADMAP.md` (branch 1). It replaces "Target Shoot" (2026-10-09): the first game
was not playable (small, fast targets) and it was a shooting game.

## Goal

Each player points a phone at the TV like a remote control. A cursor in the player color follows the phone. Hungry animals (monkeys,
lemurs, orangutans, sloths, gorillas and elephants) walk across a jungle at sunset. A press on A throws a banana at the cursor. An
animal that is hit jumps, eats the banana and cheers. Now and then a golden monkey king runs by and is worth 100 points. The player with
the most points after 60 seconds wins. With one player, the score is shown with no medal. A miss costs nothing.
Renamed from Snowball Splat on 2026-10-16 (first Banana Splat, then Banana Party the same day, because in Hebrew קרב means fight) (the owner's decision): the look is a jungle, and the rules are the same except the lanes and the bonus.

Registry entry: `description` (one line) and `tile` (`assets/tiles/snowball_splat.png`, made by `tools/make_tiles.gd`), see REQ-GM-7.
Visual language: shell, player colors, toy-like world (REQ-GM-45 to 49). Check the tile next to the Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-37 | Note | Recenter is more important here than in the other games: the pointer uses the yaw of the gyroscope, and yaw drifts (RISKS A4). The hint says so (REQ-SS-12). |
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 10). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |
| REQ-GM-80 to 84 | Note | Content: bananas at friendly animals. No violence, no scary things (REQ-SS-17). A miss costs nothing (REQ-SS-5). Text is positive. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Round

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-1 | A round has a countdown of 3 s and then 60 s of play (`RoundClock`). Cursors move during the countdown, but a throw does nothing. The visible clock shows the seconds left. At 0 the round ends and the result menu opens (REQ-SS-15). | Done | smoke_tv |
| REQ-SS-2 | At GO every phone recenters, so the pose held in the countdown is the center of the screen. The Recenter button works during the round; Banana Party is the game with the Recenter box (a pointer at a target, REQ-GM-37, issue #55). | Done | smoke_tv |

Aim and throw

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-3 | The cursor of a player is at `pointer()` mapped to the play area: -1 is the left or top edge, +1 the right or bottom edge, 0 is the center. All players use the same mapping and the same range (REQ-GM-24). The play area is the screen inside the 60 px margin, under the HUD. The cursor stays inside it. | Done | game_rules (mapping), smoke_tv |
| REQ-SS-4 | A press on A (an edge: `button_pressed`) throws one banana at the place of the cursor at that moment. Holding A does not repeat. A throw does nothing while the game is paused, in the countdown, or after the round. B does nothing. A player can throw again after 0.3 s (reload). A press inside the reload time is ignored. | Done | smoke_tv |
| REQ-SS-5 | A miss costs nothing: no points are lost, the player does not wait longer, and the cursor does not change. A banana that hits no animal makes a small poof where it lands. | Done | smoke_tv |
| REQ-SS-6 | The banana flies for 0.12 s from the bottom of the play area to the place of the cursor (a small arc, turning). It is a picture. The hit is decided when the banana lands (REQ-SS-10). Bananas land in the order they were thrown. | Done | smoke_tv |

Animals

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-7 | There are six animals and a bonus. Points and hit radius (px at 1920x1080): monkey 25 and 72, ring-tailed lemur 25 and 72, orangutan 10 and 80, sloth 10 and 76, gorilla 10 and 84, elephant 10 and 96; the golden monkey king 100 and 72 (REQ-SS-25). The speed of an animal is the speed of its lane (REQ-SS-8), 160, 90 and 80 px/s at Medium (Hard multiplies it, REQ-SS-20); the bonus runs at 320 px/s. | Done | game_rules |
| REQ-SS-8 | The play area has 3 lanes in depth, far to near (the view is from slightly above): far (y 490, walking right, 160 px/s, monkeys and lemurs), middle (y 625, left, 90 px/s, orangutans, sloths and gorillas), near (y 760, right, 80 px/s, elephants and gorillas). An animal enters at the edge of its lane, walks across with a small bob at each step (8 px, 0.6 s), and leaves at the other edge. An animal that leaves is not a loss. Two animals of one lane never overlap: all animals of a lane have the lane speed, and a new one enters only when the one before it is 380 px or more from the edge. | Done | game_rules |
| REQ-SS-9 | A new animal comes every 1.5 s while fewer than 3 + the number of players animals (not counting the bonus) are on the screen. The lane is chosen among the free lanes with the weights 30 (far), 35 (middle) and 35 (near), then a kind of that lane at random. If there is no free lane, no animal comes at that time. The first animal comes at once. The animals are the same for all players. Everything comes from one `RandomNumberGenerator`. A test can fix it with `start_props.seed`. Without a seed, a new round has new animals. Try again keeps the seed that was given (REQ-GM-32). | Done | game_rules, smoke_tv |

Hit and score

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-10 | A banana hits an animal when the place where it lands is inside the radius of the animal plus 12 px, at the time of landing. When two animals are hit, the one with the nearer center is hit. A hit takes the animal and adds its points to the thrower. A score never goes down. | Done | game_rules, smoke_tv |
| REQ-SS-11 | When two bananas land on the same animal, the one that was thrown first wins. The other one is a miss (REQ-SS-5), unless it hits another animal. Throws are handled in the order they arrived, not in slot order (REQ-GM-24). | Done | smoke_tv |

Look and feedback

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-12 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n), drawn in the 480x270 view by `banana_look.gd`: a jungle at sunset seen from slightly above. Sunset sky bands and a sun, two rows of hills, a ground of grass in three lane bands (a lane per band, near is lower and bigger) with tufts of tall grass, tree trunks that each end in a treetop of round leaves, hanging vines, the sun in the upper middle (62 % of the width), under the HUD bar (the sky, vines and treetops start under the bar, so they can be seen) and a few leaves that drift (in game time, so they stop in a pause). An animal is a pixel picture with a one-pixel black outline, bigger when nearer, drawn in whole world pixels, facing the way it walks; it has no leg animation, only the bob of REQ-SS-8. The pointer is a plain ring: a dark 4 px edge and 2 px in the player color, 40 px radius (80 px across, 20 world pixels), no badge and no number (REQ-GM-46). A banana is a yellow picture with a black outline that turns in flight. A poof of a missed banana is a ring that grows in 3 hard steps (no fade). Every key object is 48 px high or more at 1920x1080. The title "BANANA PARTY", timer (a box 208 px wide, so that 4 chips of 270 px fit in one row), the leader chip, countdown, hints and menus come from the shell. The hint says "Point at the TV and press A to throw a banana. Recenter if the cursor drifts." There is no box or pile of bananas. The tile shows exactly 4 cursor rings, one for each player, and no poof ring (issue #114). | Done | game_rules (visual rules), game_helpers, smoke_tv (the view), Screenshot |
| REQ-SS-13 | A hit animal has a hit animation of 1 s: it jumps once (72 px, 0.5 s), stands with happy closed eyes (`^`) and the banana peel falls beside it, then it walks on. Each kind has its own cheer: the gorilla shakes, the sloth wiggles slowly, the lemur turns on the spot, the elephant sprays a little water, the orangutan has three big pink hearts (10 x 8 world pixels) and no sparkles, the monkey has sparkles and the golden monkey has gold sparkles. The points show above the animal ("+10", in the color of the player, drawn by the HUD at full resolution; the gold bonus text is bigger). Nothing in a hit is violent or sad (REQ-GM-81). | Done | smoke_tv, Screenshot |
| REQ-SS-14 | Haptics (REQ-GM-43): a throw buzzes the thrower 15 ms, a hit 40 ms (the gap between two buzzes is 100 ms or more, `Haptics`). GO buzzes every phone 60 ms. The winner buzzes 400 ms at the end. There is no buzz for a miss. | Device | smoke_tv, Device (feel) (Test 10 step 12a) |
| REQ-SS-15 | The layout comes from `size` (REQ-2D-2). It works at 1280x720 and 1920x1080: the play area and the sizes of the animals scale with the screen. The cursor and the HUD keep their pixel size. | Done | game_rules (scale) |

End and players

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-16 | The result menu is `open_results()` (REQ-GM-72) with a `Scoreboard` (higher is better): ranking, "X wins!" or "Tie!", Try again, Settings, Back to menu. With one player the row has no medal (REQ-GM-73, issue #119); with more players each row has the medal of its place. A player who leaves takes the cursor and the score out, and the round goes on. A lost phone pauses the round with the card of REQ-GM-30. When the last player leaves, the menu "No players connected" opens (REQ-GM-21, 22). | Done | smoke_tv |
| REQ-SS-17 | Children (REQ-GM-80 to 84): the animals are friendly and eat bananas, the hit is funny, a miss costs nothing, no player is out of the round, the hint is one line, the animals are large and slow, and every text is positive. | Device | Review, Device (with a child, Test 10 item 9) |

### Settings and difficulty (built 2026-10-09)

REQ-GM-90 to 96 apply. The settings view has one row: Difficulty. As it grows, the animals move faster and there are fewer of them. The size of the animals, the points, the hit rule, the pointer range and the 60 s round are the same at every difficulty, and a miss costs nothing at every difficulty (REQ-SS-5, REQ-GM-96).

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SS-20 | The game has the settings view with the row Difficulty (REQ-GM-90, 91; registry `settings: []`), and `difficulty` is a prop of the game. Difficulty changes four values, see the table below: the speed of the animals (a factor on the speed of each kind), the number of animals on the screen (`MAX_BASE`, plus the number of players as before), the time between two new animals (`SPAWN_EVERY`), and the number of bushes (REQ-SS-26). | Done | game_rules, smoke_settings |
| REQ-SS-21 | The title of the result of one player is the difficulty that was played ("Hard"). There are no medal tiers (REQ-GM-73, issue #119). | Done | smoke_tv |
| REQ-SS-22 | At every difficulty the lanes never overlap (REQ-SS-8), and at least one animal is on the screen most of the time, also on Hard with 1 player. | Done | game_rules |
| REQ-SS-23 | The HUD shows the leader chip (leader and points, or TIE; REQ-GM-46) next to the title and the timer. Each phone shows its own points and place (REQ-FL-67). | Done | game_helpers (leader), run_tests (score message) |
| REQ-SS-24 | Personal best (REQ-GM-98): the key is `snowball_splat|<difficulty>`, the value is the score, higher is better. All player counts share one key. | Done | smoke_bests |
| REQ-SS-25 | The golden monkey king (the bonus, REQ-SS-7): it is worth 100 points, runs at 320 px/s, and shows a gold crown and sparkles. It comes once in a while: the first after 10 s of play, then after 14 to 22 s. Only one is on the screen at a time, it comes in a lane that has no animal at the entry, and only when it cannot catch an animal ahead of it in the lane (it keeps 200 px behind). If no lane is safe it waits 1 s and tries again, so it can come a bit later. It is the same for all players. It does not count toward the maximum number of animals. | Done | game_rules |
| REQ-SS-26 | Bushes: the ground has bushes where the animals walk. A bush stands in a lane, is 300 px wide (`BUSH_HALF_W` 150) and is drawn in front of the animals of its lane. An animal is hidden when its middle is inside the bush, less half of its radius, and a banana that lands there cannot hit it (a miss, REQ-SS-5). The animal walks on and can be hit again when it comes out. The number depends on the difficulty: Easy 3, Medium 5, Hard 8. They are spread over the lanes (middle first, then far, then near) and over the width of each lane with a random shift from the seed, 200 px or more from the edges and 420 px or more from each other in a lane. Tufts of tall grass are drawn on the ground (no effect on the game). | Done | game_rules, smoke_tv |

| Difficulty | Speed factor | animals on screen (`MAX_BASE`, + players) | New animal every | Bushes |
|------------|--------------|------------------------------------------|----------------|--------|
| Easy | 0.7 | 4 | 1.2 s | 3 |
| Medium | 1.0 | 3 | 1.5 s | 5 |
| Hard | 1.5 | 2 | 2.0 s | 8 |

The values are first guesses and are tuned on a device (Test 10). Fewer animals on Hard makes each animal worth more attention, and faster animals ask for better aim.

## Parameters

Values that change how the game feels. Tune them on a device (Test 10). First values:

| Name | File | First value |
|------|------|-------------|
| `ROUND_TIME`, `COUNTDOWN` | `snowball_splat_game.gd` | 60 s, 3 s |
| `RELOAD`, `FLIGHT_TIME` | `snowball_splat_game.gd` | 0.3 s, 0.12 s |
| `SPAWN_EVERY`, `MAX_BASE`, `ENTRY_GAP`, `HIT_SLOP` | `puff_field.gd` | 1.5 s, 3 (+ players), 380 px, 12 px |
| Kinds (points, radius), the lanes (y, direction, speed, weight), `WAVE`, `WAVE_TIME` | `puff_field.gd` | REQ-SS-7, 8, 9 |
| `BONUS_FIRST`, `BONUS_MIN`, `BONUS_MAX`, `BONUS_GAP` | `puff_field.gd` | 10 s, 14 s, 22 s, 200 px |
| `BUSH_HALF_W`, `BUSH_MARGIN`, `BUSH_MIN_GAP`, `bushes` of `LEVELS` | `puff_field.gd` | 150 px, 200 px, 420 px, 3 / 5 / 8 |
| `HIT_LIFE`, `HIT_HOP`, `HIT_HEIGHT`, `CURSOR_R` | `snowball_splat_game.gd` | 1 s, 0.5 s, 72 px, 40 px |
| `LEVELS` (speed factor, `max_base`, `spawn_every` for each difficulty) | `puff_field.gd` | REQ-SS-20 |
| `pointer_range_deg` (sensitivity) | `scripts/input/orientation.gd` | 25 (half range of the pointer in degrees) |

## Open questions

- Is a half range of 25 degrees good from the sofa? Too small is shaky, too large needs a big arm movement. This is the main thing to test.
- Does the yaw drift (gyro only) stay small enough for a round of 60 s? If not, a short smoothing or a stronger bias learning is needed in `orientation.gd`.
- Are the animals slow and big enough for a child of 5 to 6 years? Are they too slow for an adult? The speeds, sizes and the 60 s are first guesses.
- The pointer range covers the whole play area, but the animals walk only in its lower half. Is the top half wasted?
- The Hebrew texts (the name "מסיבת בננות" and the hint) were written by Claude and need a native reader (test 17).

## Sound and haptics (REQ-GM-49a to 49c, REQ-GM-43)

The song `snowball_splat` plays from "GO": Light and playful with bell tones (unchanged by the rename), 124 BPM, F major. The countdown, pause and result sounds come from the base class.

| ID | Effect | When | Sound | Status |
|----|--------|------|-------|--------|
| REQ-SS-S1 | `snow_throw` | A press on A throws a banana (haptic 15 ms). | Fwip | Device (test 18) |
| REQ-SS-S2 | `snow_hit`, `snow_points` | A banana takes an animal (haptic 40 ms). | Splat and boing, then a ping. The ping pitch rises with the slot, so a player hears their own | Device (test 18) |
| REQ-SS-S3 | `snow_miss` | A banana misses. | A very quiet puff. No negative sound (REQ-GM-81) | Device (test 18) |

Haptics on the phone of the player: Countdown end: 60 ms; Throw: 15 ms; Hit: 40 ms; Round end: 400 ms for the winners. An animal makes no sound of its own.

## Languages (REQ-GM-47o)

The texts of this game are English and Hebrew: the title, the description, the hint and the result texts have a key and a Hebrew text in `assets/lang/strings.csv`. In Hebrew the HUD is mirrored by the shell (title, leader chip, timer). The game world is not mirrored.
