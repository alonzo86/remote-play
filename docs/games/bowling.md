# Pin Pals (`bowling`)

Status: **built** (2026-10-16), not yet tried on a device (manual test 23). The mock frames are in the project files, `screens/bowling/`.
Type: 2D (pixel world). Players: 1 to 4. Input: a finger on the phone (aim strip) to aim, phone motion (a swing) to throw.
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84).
Code: `scripts/game/bowling/` (`bowling_rules.gd` the score sheet and the turn order, `lane_sim.gd` the ball and the pins,
`scripts/input/swing_detector.gd` (shared with Tennis since 2026-10-17) the throw from the sensor values, `bowling_look.gd` the pictures, `bowling_game.gd` the screen).

The name is a first idea (friendly, no trademark). Other names: "Strike Party", "Lane Bash". A trademark search was not done.

## Goal

Ten-pin bowling with the standard rules. The players bowl in turns, 10 frames each. The phone is the ball: the player **moves the phone
left or right to aim**, then **swings it back and forward to throw**. The ball rolls down the lane on the TV and hits 10 pins.
The player with the most points after the 10th frame wins. One player plays for a score and gets no medal (REQ-GM-73).

Registry entry: `description` (one line) and `tile` (`assets/tiles/bowling.png`, made by `tools/make_tiles.gd`), see REQ-GM-7. The tile shows only the lanes (the pins and the ball), without the score board, and the picture fills the whole tile with no gray area at the bottom.
Visual language: shell, player colors, pixel world (REQ-GM-45, 46, 47i to 47n, 48, 49).

## Rules (standard ten-pin bowling)

- A game has 10 **frames**. In each frame a player bowls up to 2 balls at 10 pins.
- A **strike** is all 10 pins with the first ball. The frame ends. The score is 10 plus the pins of the next 2 balls.
- A **spare** is all 10 pins with 2 balls. The score is 10 plus the pins of the next 1 ball.
- An open frame (pins left after 2 balls) scores the pins that fell.
- The 10th frame: after a strike or a spare the player bowls a 3rd ball. A strike in the 10th frame gives a fresh rack of 10 pins for the
  next ball, so the 10th frame has 2 or 3 balls (X X X, X 7 /, 9 / X, 9 / 5, 8 1 ...).
- The best score is 300 (12 strikes in a row). A game with no pin down is 0.
- No foul line rule: the lane has a foul line on the TV, but the phone cannot cross it (the ball starts at the line).
- Turn order: player 1 bowls frame 1, then player 2 bowls frame 1, and so on, then frame 2 starts (the standard way).
  A player who has a strike or spare does not bowl again out of turn.
- The winner has the highest total. Players with the same total share the rank (REQ-GM-70). With one player the score is
  shown as a score, with no medal (REQ-GM-73, issue #119).

## How the player throws

Hold the phone in one hand like a ball, arm down at the side (see `screens/bowling/5-swing.png`).

1. **Aim.** The player slides a finger on the aim strip of the phone. The ball moves along the foul line on the TV, with a dotted
   line to the pins, and stays where the finger lifted (REQ-BW-4). The ball always rolls straight. No sensor is used for the aim,
   so drift does not matter.
2. **Swing back.** The first strong move of the phone in one direction is the back swing. The aim is **locked** at that moment,
   so the shaking of the swing does not change it. The mark turns solid.
3. **Swing forward.** A strong move the other way is the forward swing. The ball is let go at its fastest point. Its speed is the
   speed of the swing (REQ-BW-6).

The detector knows the back swing from the sensor values and does not need to know how the player holds the phone: the swing axis is the
direction of the strongest move in the back swing, and forward is the opposite way (REQ-BW-5). A fast forward move with no back swing before it is read as a back swing (the first strong move gives the axis), so it does not throw. No button is needed (REQ-GM-82).
A swing that is too weak does nothing and the hint says "Swing a bit more!"; the ball stays, and there is no time limit.

## Turn flow

1. "NOA, YOUR TURN!" (a plate in the middle of the top bar for 1.5 s, the phone buzzes once, 60 ms; the game starts with this turn at once, there is no countdown). The ball of the player (slot color) is at the foul line.
2. Aim, swing back, swing forward. The ball rolls (about 2 s). The pins fall (about 1.5 s). The score sheet updates.
3. Pins left: the same player bowls ball 2 ("2 pins left. One more ball!"). Then the fallen pins are taken away at once and the next player starts.
4. Strike: "STRIKE!" banner and a burst of colored pixels. Spare: "SPARE!". Off the side: "OOPS! OFF THE SIDE" (no point is taken, no mockery, REQ-GM-84).
5. A turn has **no time limit**: it takes as long as the player needs (decision of 2026-10-16). A game of 4 players is about 10 minutes
   and the longest wait for the others is about 30 s, more than the "about 20 seconds" of REQ-GM-83 (see the gaps). The banner after a ball shows 1.8 s (REQ-BW-11). There is no short game: the game always has 10 frames.

The phones: the player on turn gets a short buzz (60 ms). The pad shows "YOUR TURN" on the phone on turn and "NOA IS BOWLING" on the others (REQ-BW-14, the optional `turn` message of `docs/PROTOCOL.md`).

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-24 | Note | All players have the same values. The turn order is standard (player 1 first in every frame), which is the rule of the sport. |
| REQ-GM-35, 71 | Exception | There is no countdown (REQ-GM-35, no visible timer) and no round clock: the first turn starts at once after Start; the game ends after the 10th frame of the last player (REQ-BW-1). |
| REQ-GM-37 | Exception | The Recenter box is the aim strip while it is the turn of the phone (REQ-BW-4), because the game needs no recenter: the aim is a finger, not a pose. Other phones have no Recenter box either (issue #55). The pad has no A and no B (issue #143): the game needs no button. |
| REQ-GM-81 | Note | The pins are plain lifeless pins with no face. Knocked pins spin and burst into colored pixels. No living thing is hit. |
| REQ-GM-83 | Gap (open) | A player waits for the other players (about 30 s with 4 players) and a turn has no time limit. The user decided this on 2026-10-16 (no Length setting). Mitigation: short animations. |
| REQ-GM-47k | Note | The disco light grid on the back wall (REQ-BW-13) uses 7 bright light colors besides the 8 colors of the world palette (`DISCO` in `bowling_look.gd`). The user allowed a few more colors when the general theme is kept (2026-10-16). It is decoration only. |
| REQ-GM-98 | Note | A personal best only with Rails off (REQ-BW-19). |
| REQ-GM-46 | Exception | No leader chip in the HUD: the score sheet at the bottom shows all scores (REQ-BW-12). The phones still show their own place and score (REQ-FL-67) unless the user says otherwise. |
| REQ-GM-62 | Note | Test 23 in `docs/MANUAL_TESTS.md`. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test: `bowling_rules` is `tests/bowling_rules.gd`, `smoke_bowling` is `tests/smoke_bowling.gd`.

Rules and score

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-BW-1 | A game is 10 frames for each player . It ends when the last player has bowled the last ball of the last frame. The result menu opens 2 s after the banner of the last ball (the banner lasts 1.8 s), so 3.8 s after the last ball stops (`open_results()`, REQ-GM-72) with the totals, "X wins!" or "Tie!", Try again, New game, Back to menu. | Done | bowling_rules, smoke_bowling |
| REQ-BW-2 | The score follows the standard rules above: strike (10 + next 2 balls), spare (10 + next ball), open frame, the 10th frame with 2 or 3 balls and a fresh rack after a strike. The rules module is pure code (no nodes). Known games are tests: 12 strikes = 300, 21 balls of 5 pins (all spares of 5) = 150, all gutters = 0, ten frames of 9 / and a last 9 = 190, the 10th frame cases X X X, X 7 / and 9 / 5.| Done | bowling_rules |
| REQ-BW-3 | The turn order is frame by frame: slot order inside each frame. A player who leaves is skipped (REQ-GM-21) and the score sheet row is removed from the ranking. When one player is left the game goes on for that player. When nobody is left, "No players connected" opens (REQ-GM-22). | Done | bowling_rules, smoke_bowling |

Aim and throw

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-BW-4 | While it is the turn of a phone, its Recenter box becomes the **aim strip** (same place, a lane row with a ball mark). A finger that slides on the strip moves the ball along the foul line; the phone sends the place on the strip (0 left to 1 right) as the touch x of the sensor packet. The TV maps it to the aim −1 to 1 (`aim_from_touch()`), that is plus and minus 0.60 m from the middle of the lane (`AIM_X`, into the gutter). The aim stays where the finger lifted (the mark on the phone and the ball on the TV stay), starts in the middle for a new player (the same player keeps it for ball 2 and the mark on the phone stays), and is locked by the back swing (REQ-BW-5). The ball always rolls straight. Only a finger on the strip is read: A, B and the rest of the screen do not move the aim. Difficulty does not change the aim. | Device | bowling_rules (`aim_from_touch`, the aim strip limits), bowling_replay (finger, lift, keep), smoke_bowling, ui_states (the pad), Device |
| REQ-BW-5 | The throw is detected from `PlayerInput.linear_accel()` (the acceleration without gravity). State machine (`swing_detector.gd`): Ready, Back swing (the acceleration is more than `BACK_ACCEL` for at least 60 ms; it gives the axis `d`; the aim is locked), Forward (the acceleration along `-d` is more than `FWD_ACCEL` within 1.5 s of the back swing), Release (when the forward strength falls to half its peak, or after 1 s), then Locked for 1.5 s. A back swing with no forward swing within 1.5 s goes back to Ready, unlocks the aim and shows the "Swing a bit more!" hint. A forward push counts only when the back swing lasted at least 0.1 s after the start of the move (`MIN_BACK`, `min_back` of the detector; with the 0.06 s that finds the move, about 0.16 s in all): a shake goes back and forth faster and throws nothing (2026-10-20). A push also does not count when the acceleration along the axis turned round strongly (more than `BACK_ACCEL`) more than once in the last 0.5 s (`max_reversals` = 1 of the detector, `REVERSAL_SPAN`): a hard shake of 6 to 12 Hz throws nothing, a real swing turns round once. While a finger is on the aim strip the detector is reset, so a move of the phone does not throw (REQ-BW-4); a swing that would have thrown shows the hint "Lift your finger, then swing!" for 3 s (`bowling.hint_lift`). Only the player on turn is read. Other players cannot throw. | Device | swing_detector (made-up traces), bowling_rules (shake, MIN_BACK), bowling_replay (three grips, walking, shakes, finger on the strip, weak swing), swing_replay, smoke_bowling, Device |
| REQ-BW-6 | The ball speed comes from the peak forward acceleration, mapped from 0 at `FWD_ACCEL` to 1 at `FWD_FULL` (30 m/s2), then to the speed table of the difficulty (top speed 9 m/s). A swing below `FWD_ACCEL` does nothing; after a back swing with no forward swing the hint "Swing a bit more!" shows for 3 s. On Easy the speed is always 0.8 of the top speed (REQ-BW-17). | Device | swing_detector, lane_sim, bowling_replay (soft and hard swing) |
| REQ-BW-7 | The throw buzzes the phone 40 ms at the release. The haptic never carries information alone (REQ-GM-43): the TV shows the ball. | Device | smoke_bowling, Device |
| REQ-BW-8 | A sensor trace tool: the debug overlay shows the swing state, the aim and the peak values for the player on turn, so that the thresholds are set from real swings ("swing lab"). Not built: the thresholds are first guesses. | Open | Device |

Lane and pins

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-BW-9 | The lane is a fixed 2D simulation (top view numbers, drawn in perspective): the lane is 1.05 m wide, the ball radius 0.11 m, a pin radius 0.09 m (a pin is bigger than a real one so that it is easy to see), in the standard triangle of 10 pins (numbered 1 to 10, 0.305 m apart). Sub-steps of 1/120 s (REQ-GM-13). Pins and ball are circles. A ball that hits a pin passes on momentum with a fixed restitution; a pin hit above a speed limit falls and goes on as a sliding circle with friction, so it can knock others (pin action). The same aim and speed always give the same result (REQ-3D-9 spirit): no random number in the physics. | Device | lane_sim |
| REQ-BW-10 | A ball that leaves the lane (the line of the gutter) is in the gutter: it rolls to the end with no pin hit and the player sees "OOPS! OFF THE SIDE". The result of the ball is 0 pins. With the setting **Rails** on, the gutters are covered by rails (bumpers): a ball that touches a rail rolls back into the lane, so there is no gutter ball (REQ-BW-16). | Done | lane_sim |
| REQ-BW-11 | After a ball, the fallen pins are taken away at once (no animation) and the standing pins stay for ball 2. After the last ball of a frame, a fresh rack is set at once.  The banner of the ball shows 1.8 s and nothing skips it (issue #143: there is no A button). | Done | smoke_bowling |

Feedback and screen

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-BW-12 | HUD: the title and "FRAME 4/10  BALL 1" (at the right). There is **no leader chip** and no player stats in the bar (decision of 2026-10-16): the game draws no leader chip (the phones still get their own score and place from the board). The **score sheet** (the headboard) of all players is at the bottom (one row each, 10 cells, the marks X, / and digits, the running total, the active cell has the accent frame), 28 px text, inside the 60 px margin (REQ-GM-40, 41). The layout comes from `size` (REQ-2D-2). | Device | smoke_bowling, game_helpers |
| REQ-BW-13 | Look (REQ-GM-47i to 47n): a pixel bowling hall. The own lane is **narrow and long** (112 world pixels wide at the foul line, 52 at the pins; the strong narrowing makes it look long) and shown in perspective (long wood planks that run along the lane, with no cross lines or grid, dark gray gutters, arrows, a red foul line). **Three more lanes on each side**, darker, with their own racks of pins (some pins down, they do not move or play), so the sides are never empty. The **floor** around and between the lanes is **gray** (`#5a5a64`). At the **far end of all lanes** there is one wall across the whole width: its top two thirds are a **disco light grid** (rows of small colored light tiles, 7 bright colors) and its bottom third is **plain black**, so the white pins stand in front of black and the strike burst is easy to see. The HUD row above (y under 112) is black and has no grid. Three more lanes each side are drawn on the gray floor. In a later version the tiles may blink (in steps, with game time, REQ-GM-47l; never faster than 3 times a second). A ball in the slot color with a white shine, detailed pins: a 7 x 14 pixel picture with a round head, a thin neck with a red stripe, a shaded right side and a red band on the belly (the first mock had flat pins). World palette (8 colors): `#1b3a8a` wall, `#0f6a78` floor, `#d8a058` and `#cc944c` planks, `#3c3c3c` gutter, `#fcfcfc` pins, `#e63946` bands. One-pixel black outline on pins and ball. A pin is 12 pixels high or more at the far end. The ball gets smaller with distance in steps of a quarter. Banners sit on a black plate. | Device | game_rules (pictures), Device |
| REQ-BW-14 | The phone: a short "YOUR TURN" with a buzz, and "NAME IS BOWLING" while another player bowls, plus the own score and place (REQ-FL-67). The TV sends the optional `turn` message (`s` 0, 1 or 2, and `who`) once for each change; the phone draws it under its score row. `VERSION` stays 3. | Device | smoke_bowling |
| REQ-BW-15 | Texts are positive: "Strike!", "Spare!", "Nice roll!", "Oops! Off the side", "Nice try!" (REQ-GM-84). The hint is one line at a time (REQ-GM-82): "Move the phone to aim. Swing back, then forward!". | Done | smoke_lang |

Settings and difficulty (REQ-GM-90 to 97)

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-BW-16 | Settings rows: **Difficulty** (Easy, Medium, Hard) and **Rails** (the values read "WITHOUT" and "WITH"; default Without; issue #140) only (no Length row: every turn takes as long as it takes, and the game is always 10 frames). The rails are a setting of their own, not part of the difficulty. The mock is `screens/bowling/v2-5-settings.png`. The Rails row is a registry settings row (`key: rails`, values `off` and `on`). Both rows are part of `start_props` (REQ-GM-93). | Done | smoke_settings |
| REQ-BW-17 | The table below shows what Difficulty means. Easy plus Rails must be playable by a child of about 5 years (REQ-GM-96): the child can only swing and score. | Device | lane_sim, game_rules |
| REQ-BW-18 | One player gets no medal and the result shows the points (REQ-GM-73). The medal tiers were removed (issue #119). | Done | game_rules |
| REQ-BW-19 | Personal best (REQ-GM-98): the key is `bowling|<difficulty>` with Rails Off only, higher is better (`best_key()`; new keys at the end of `ProfileKeys`, 3 keys, numbers 40 to 42; the code format was not changed, see `docs/PROFILES_PLAN.md`). A game with rails has no best (exception, the scores are not comparable). | Done | smoke_bests, profile_code |
| REQ-BW-21 | The plate "NAME, YOUR TURN!" shows 1.5 s at the start of each turn, then it goes away (it is not drawn for the rest of the turn). | Done | r4_bowling |
| REQ-BW-20 | A player who leaves takes the row out of the ranking. A lost phone pauses the game (REQ-GM-30). Nothing runs in the pause, and the swing state of the player on turn is reset when the pause closes. | Done | smoke_bowling |
| REQ-BW-22 | Safety (REQ-GM-102, issue #79): Pin Pals is a swing game (`swing` in the registry). The settings view shows the line "HOLD YOUR PHONE TIGHT AND KEEP SPACE AROUND YOU.", each phone shows the card "HOLD ON TIGHT!" once for each run of the app, and Start waits for the OK of every phone. | Done | swing_setup, ui_states_a |

| Difficulty | Ball speed | Aim | Swing threshold |
|------------|------------|-----------|-----------------|
| Easy | always the middle value | whole strip | low (`FWD_ACCEL` x 0.7) |
| Medium | 0.7 to 1.0 of the top speed | whole strip | normal |
| Hard | 0.5 to 1.0 (a slow ball leaves pins) | whole strip | normal |

A game with rails has no personal best (REQ-BW-19).

All numbers are first guesses.

## Parameters

Values that change the feel. Tune them with the swing lab and a device test (REQ-BW-8). First values:

| Name | Value (file) |
|------|--------------|
| End of the aim strip | 0.60 m from the middle of the lane, in the gutter (`AIM_X`, `bowling_game.gd`) |
| `BACK_ACCEL`, `FWD_ACCEL`, `FWD_FULL`, `SWING_WINDOW`, `LOCK_AFTER` | 4, 8, 30 m/s2, 1.5 s, 1.5 s (`swing_detector.gd`); Easy counts 0.7 of the thresholds |
| Ball top speed; speed range | 9 m/s; Easy 0.8, Medium 0.7 to 1.0, Hard 0.5 to 1.0 of it |
| Lane, ball, pin, pin distance | 1.05 m, 0.109 m, 0.09 m, 0.305 m (`lane_sim.gd`) |
| Masses, restitution, pin fall speed, friction | ball 6 and pin 1; 0.9 and 0.95; 0.2 m/s; 1.6 m/s2 |
| Banner of a ball; wait after the last ball | 1.8 s; 2 s |

## Open questions

- **Aim by finger (decided 2026-10-20).** Aiming by the turn of the phone (yaw) drifted and was hard to hold, so the aim is now a finger on the phone (REQ-BW-4). The old question, kept for the record: "Moving the phone left or right" cannot be measured as a slide (a phone cannot know a distance). The plan turns the phone
  (yaw, like the Banana Party pointer) and sets the center at each turn, so drift does not matter. The other way is to tilt the phone
  left or right (roll, no drift, like Star Shield). Which one feels like bowling?
- **Does the swing work with any grip?** The detector finds the swing axis from the back swing. This is never tried with a real phone (Test 23; the sensor directions test, Test 3, is still open).
- **Spin (hook).** A twist of the wrist at the release could curve the ball and make splits (7-10) possible. It is not in the first version (straight balls only).
- **The code of the profile.** Pin Pals added keys 40 to 42. A code with a Pin Pals best is format version 2; any other code stays version 1, so an old app reads it and refuses only a version 2 code (`docs/PROFILES_PLAN.md`).
- **Name.** "Pin Pals" or something else? The Hebrew name is "באולינג חברים" (first guess).
- The sizes of the lane and the pins are guesses.

## Sound and haptics (REQ-GM-49a to 49c, REQ-GM-43)

The song `bowling`: a light, bouncy loop (about 110 BPM, C major) that starts with the first turn (no countdown). The effects are short. No sound is scary or sad.

| ID | Effect | When | Sound | Haptic |
|----|--------|------|-------|--------|
| REQ-BW-S1 | `bowl_turn` | A turn starts. | Two soft bell notes | 60 ms for the player |
| REQ-BW-S2 | `bowl_throw` | The ball is let go. | Soft whoosh | 40 ms |
| REQ-BW-S4 | `bowl_pins` | The ball hits the pins. | Rattle of wood, stronger with more pins | 40 ms |
| REQ-BW-S5 | `bowl_strike` | A strike. | Bright rising fanfare | 200 ms |
| REQ-BW-S6 | `bowl_spare` | A spare. | Rising three notes | 80 ms |
| REQ-BW-S7 | `bowl_gutter` | The ball goes off the side. | Funny falling "bwoop", soft | none |

## Languages and texts (REQ-GM-47o)

The rows are in `assets/lang/strings.csv` and need a review by the user. The Hebrew is a first guess by Claude and needs a native reader. The full texts and the `where` of each row are in that file; the keys are `registry.pin_pals`, `registry.desc_bowling`, `bowling.rails`, `bowling.on`, `bowling.off`, `bowling.turn`, `bowling.frame`, `bowling.hint_slide`, `bowling.hint_weak`, `bowling.strike`, `bowling.spare`, `bowling.gutter`, `bowling.nice_roll`, `bowling.nice_try`, `bowling.pins_left`, `bowling.pin_left`. The phone lines are `bowling.phone_turn` and `bowling.phone_wait`. The aim strip help line on the phone is `pad.slide_to_aim`.

In Hebrew the HUD is mirrored by the shell. The lane and the score sheet are the same in both languages (the game world is not mirrored, and a score sheet reads left to right as the frames go left to right).
