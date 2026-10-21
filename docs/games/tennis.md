# Tennis (`tennis`)

Type: 2D with a view from behind a baseline (pixel world). Players: 1 to 4. Input: swing and tilt (the sensor of the phone), A (serve toss), Recenter.
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
Plan: `docs/GAMES_ROADMAP.md` (branch 7). Status: built on 2026-10-17 (code in `scripts/game/tennis/`), not yet tested on a device (Manual test 25). The look was agreed on 2026-10-16 (mock in the project thread).

## Goal

Two teams play on a tennis court that is seen from behind one baseline. The character of each player **runs by itself** to the ball; the
player only swings the phone. A swing at the right time sends the ball back, and the swing and the tilt decide where it goes and how fast.
A point is won when the other team does not return the ball. With 1 player the game is a rally with a friendly ball machine and the score
is the longest rally.

Registry entry: `description` (one line) and `tile` (`assets/tiles/tennis.png`, made by `tools/make_tiles.gd`), see REQ-GM-7.
Visual language: shell, player colors, pixel world (REQ-GM-45 to 49). Check the tile next to the Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-46 | Note | Players are detailed characters (hair, shirt, shorts, racket), not balls. The shirt has the slot color. There is no number or avatar on a character (REQ-GM-46). |
| REQ-GM-82 | Note | A child must understand the game from one hint line. The phone needs a swing and at most A (REQ-TN-8, 9). The character runs by itself, so a child only times the swing. |
| REQ-GM-83 | Note | A missed ball gives a point to the other team and takes nothing away. Nobody is out. All players play every point. |
| REQ-GM-47k | Note | The world palette is the arcade colors plus the court and the stands: court blue and light blue, grass green, white lines, dark net, and the seats and shirts of the crowd (about 12 more colors, `tennis_look.gd`). They are decoration and flat colors, so the arcade theme stays. |
| REQ-GM-98 | Gap | No personal best for now (REQ-TN-17). |
| REQ-GM-62 | Note | Manual test 25 is added with the code. |
| REQ-GM-50, 51, 52 | Device | Frame rate, allocation and start time are not measured on a TV box. |

## Requirements

Teams and court

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TN-1 | 1 player: the player plays a rally with the ball machine (a friendly pink box at the far end). Only this solo rally shows a timer (the time left), so only it starts with the 3 s countdown; a match of 2 to 4 players has no timer and starts at once (REQ-GM-35). 2 players: 1 against 1. 3 players: 2 against 1 on the **regular court**, with the same court as 4 players (no smaller court for the single player). 4 players: 2 against 2. With 3 players the single player changes after every game, so that each player is alone in turn. Slots are put in teams by their order. | Done | tennis_rules, smoke_tennis |
| REQ-TN-2 | The court is a doubles court seen from behind the near baseline, in perspective, with the real lines: outer doubles sidelines, inner singles sidelines, baselines, service lines, the center service line and center marks. The net, a referee tower with an umpire at the net, one ball kid at the net post and stands with seats behind the far end (blank ad boards). | Device | smoke_tennis, Test 25 |
| REQ-TN-3 | The near team is drawn large and seen from behind, the far team is small and faces the camera. The ball has a thin black border and a shadow on the court so that its landing place can be seen. | Device | Test 25 |
| REQ-TN-4 | A character runs by itself to the place where the ball will land. The player does not move it (REQ-GM-82). A character never leaves the picture: the court is seen from far enough behind the baseline that a player who hits from 2.2 m behind it or 5.6 m out is fully visible, and the run target is limited to that area (the swing still counts, the hit window is by time). A ball is **in** when it lands inside the lines of the court that apply (singles lines for 1 against 1 and for the rally, doubles lines for 2 players on a side). | Done | tennis_rules |

Hits and serve

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TN-5 | The ball glows when it is the turn of a team to hit. The player of that team who is nearest to the ball is the hitter. A swing counts (the shared swing detector: a back swing, then a forward swing; the back swing is gentle and the hit is a sharp strong push (20 m/s2 or more, 0.03 s) in any direction, so a small first move or a slow back swing before it does not matter; a smooth wide swing counts when the hand gets fast; found 2026-10-18) when the hit, `hit_age` before the report, falls while the ball is near that character (the hit window). A swing while the ball is not near does nothing to the ball and costs nothing, but the character still plays its swing (2026-10-18). | Device | tennis_rules, Test 24, 25 |
| REQ-TN-6 | The hit zone has 3 parts by time: early, green and late. A swing in the green part is a fast shot with sparks (8 square pixel sparks of 1 to 2 world pixels fly out from the racket in 4 steps, 0.4 s, white and yellow). An early or a late swing is a slow, high lob that stays in play (REQ-GM-83). The width of the green part comes from the difficulty (REQ-TN-18). | Device | tennis_rules, smoke_tennis_phones, Test 25 |
| REQ-TN-7 | Swing speed sets the power. The **direction of the forward swing** sets left or right: the angle of its horizontal part from the direction of the TV (the heading of the last recenter, followed with the gyroscope), full to the side at 45 degrees; "straight" is the mean direction of the player's own last swings (no setup step), started from the pose at the start (GO of the solo countdown, or the start of the match); a swing that is nearly vertical aims to the middle. **Heading:** after RECENTER the heading is the direction of the TV; it then follows the mean of the player's last swings, so a player who always swings to one side ends with that side as straight (ten equal swings to the right drift to the middle). A test that wants a side must alternate the swings. **Court halves:** the middle third of the court is the third of the court width around the center line; a ball is in the right (left) half when its first bounce is right (left) of the center line (`tennis_rules` asserts this). The tilt of the phone is not used any more, because the wrist turn of the swing pushed most shots to the left (found on 2026-10-18; the tilt from before the swing was tried first and was worse). A weak swing gives a short slow ball, a strong swing a long fast ball. A ball can be too long (out): a strong swing with a bad tilt may land out, a weak one never does on Easy. | Device | tennis_rules, Test 25 |
| REQ-TN-9 | Serve: the server presses A to toss the ball up and then swings the phone **from top to bottom**, like a real serve. The swing counts when the ball is high (the serve window). The serve window is the time around the top of the toss (0.45 s each side). When the server does not swing in it, the ball falls (about 1 s after the toss) and the server tosses again (no fault, no point lost). A serve must land in the service box across the net. A serve that lands out is repeated once, then the point goes to the other team. | Device | tennis_rules, smoke_tennis, Test 25 |
| REQ-TN-8 | Phone: the swing is the only action to hit. A stroke that starts less than 0.3 s after a swing is not a second swing; one that starts 0.6 s or more after the hit is (`swing_replay` asserts both). A tosses the ball (serve only). B does nothing. RECENTER recenters the tilt (REQ-GM-37). A hit buzzes the phone (30 ms, a fast shot 60 ms). The hint is one line at the bottom for the first 16 s: `tennis.hint_serve` while a serve is due (press A to toss, swing down to serve, swing to a side to aim), `tennis.hint_hit` in a rally (swing when the ball arrives, swing to a side to aim; REQ-TN-7, REQ-TN-21 is removed), `tennis.hint_solo` with 1 player (rows of `strings.csv`, to be reviewed by the user). | Device | smoke_tennis, Test 25 |

Aim

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TN-21 | **Removed 2026-10-18.** The aim line on the TV followed the tilt of the phone. The swing direction now decides the shot (REQ-TN-7), so the line would be wrong, and it is not built. The hint texts were rewritten. | Removed | - |

Scoring

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TN-10 | The game has the setting **Scoring** with the values `Real` (default) and `Quick`. `Real`: the points count 0, 15, 30, 40, game; at 40 to 40 it is deuce and a team needs 2 points more than the other team to win the game (advantage). A match is the first team to win 3 games (the number is a tuning value, REQ-TN-19). `Quick`: the first team to 5 points wins the match, and there are no games. | Done | tennis_rules |
| REQ-TN-11 | The server changes after every game (`Real`) or every 2 points (`Quick`), in turns inside the team, and the teams take turns to serve. The near team is always the team of slot 1 (the camera does not turn), and the server serves into the service box across the net. | Done | tennis_rules |
| REQ-TN-12 | A point is lost when: the ball lands out, the ball is not returned, or the ball bounces twice on a side. A net touch in play is "let", the ball goes on. Nothing takes points away (REQ-GM-83). | Done | tennis_rules |
| REQ-TN-13 | The leader chip (`draw_leader_chip()`, REQ-GM-46) shows the team in front and its games (`Real`) or points (`Quick`), or TIE. A scoreboard at the top left shows both teams (slot colors, names, the games and the points of the game; the server has a ball). With 1 player it shows the running rally, the best rally and a timer. Each phone shows its own team's place (REQ-FL-67). With two teams the places are 1 and 2 (1 and 1 on a tie): a place belongs to the team, not to its players (this replaces the shared ranks 1, 1, 3 of REQ-GM-70 for team games). The leader chip shows the team in front and its games, and TIE only when the teams are level, also in 2 against 2. The timer box of the solo panel is at the place of every game (REQ-GM-47o). | Done | smoke_tennis, smoke_tennis_phones, r4_tennis |
| REQ-TN-14 | The end: `open_results()` (REQ-GM-72) with the teams, "X wins!" and Try again, New game, Back to menu. In 1 player mode the title is the medal (REQ-TN-16). The result menu opens 2.2 s after the time is up, at most 3 s. | Done | smoke_tennis |

Solo, players and feedback

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TN-15 | 1 player: the ball machine returns every ball it can reach (never misses on purpose). The rally counts the hits in a row. A missed ball ends the rally, the count is kept as the best of the round, and a new rally starts 2 s after the miss (the banner shows 1.8 s, the machine sends the ball 0.2 s later). The round lasts 90 s. The score is the longest rally. | Done | tennis_rules, smoke_tennis |
| REQ-TN-16 | Medal tiers for 1 player (REQ-GM-73), by the longest rally: `[5, 10, 20]` on Medium (the tiers for Easy and Hard are in REQ-TN-18). First guesses. | Done | tennis_rules |
| REQ-TN-17 | Personal best (REQ-GM-98): **not built yet.** `best_key()` is empty, because a new key needs a number in `ProfileKeys` and in the profile code (a change of the profile format). Planned: in 1 player mode the key is `tennis|<difficulty>` and the longest rally counts (more is better). The games with 2 to 4 players have no key, because a match has no score that compares between matches (no best). The user decides when to add it. | Open | smoke_tennis |
| REQ-TN-20 | A player who leaves: the character goes away and its team plays on with the rest (REQ-GM-21); in 2 against 2 the teams stay as they were (no new teams for 3 players), and the characters keep their side of the court. When a team has no player left, the other team wins at once with the result menu. With 3 players the change of the single player (REQ-TN-1) skips the one who left. When nobody is left the "No players connected" menu opens (REQ-GM-22). A lost phone pauses the match (REQ-GM-30). | Done | tennis_rules, smoke_tennis |

## Parameters

| Value | Easy | Medium | Hard | REQ-TN-18 |
|-------|------|--------|------|-----------|
| Half width of the green part (s, around the contact time; the hit window is 0.55 s) | 0.30 | 0.21 | 0.15 | |
| Flight time factor (a bigger factor is a slower ball) | 1.2 | 1.0 | 0.9 | |
| The ball stays inside the lines | yes | no | no | |
| Ball machine error (m, solo) | 0.8 | 1.4 | 2.2 | |
| Medal tiers (longest rally) | [4, 8, 14] | [5, 10, 20] | [6, 14, 28] | |

REQ-TN-19: games to win a match on `Real`: 3 (about 8 minutes with 4 players, a first guess); points on `Quick`: 5. All values are first guesses and are
tuned on a device (`docs/MANUAL_TESTS.md`, Test 25). The values are in `Rules.level()` and the constants of `tennis_match.gd`.

## Sound and haptics (REQ-GM-49a to 49c, REQ-GM-43)

The song `tennis` starts with the play in a match of 2 to 4 players, and at "GO" in the solo rally (it has the 3 s countdown, REQ-GM-35): a light, springy loop (118 BPM, G major). The pause and result sounds come from the base class; `count` and `go` are heard in the solo rally only. All values are first guesses (Test 25, Test 18).

| ID | Effect | When | Sound | Haptic |
|----|--------|------|-------|--------|
| REQ-TN-S1 | `tennis_toss` | The server tosses the ball. | Short rising blip | none |
| REQ-TN-S2 | `tennis_hit` | A swing hits the ball (also the machine). | Soft "pok" | 30 ms for the player, 80 ms gap |
| REQ-TN-S3 | `tennis_great` | A hit inside the green part of the window (never for the machine). | Brighter "pok" with a ring | 60 ms for the player |
| REQ-TN-S4 | `tennis_bounce` | The ball bounces. | Quiet low tok | none |
| REQ-TN-S5 | `tennis_net` | The ball hits the net. | Soft thud | none |
| REQ-TN-S6 | `tennis_out` | The ball lands out, or a rally with the machine ends. | Short falling "bwoop" | none |
| REQ-TN-S7 | `tennis_fault` | A serve fault. | Longer falling "bwoop", soft | none |
| REQ-TN-S8 | `tennis_point` | A point is won. | Rising three notes | 80 ms for the players of the team |
| REQ-TN-S9 | `tennis_game` | A game is won, the time is up, or the match is over. | Rising five notes | 80 ms for the players of the team that won the game; 400 ms for the winners at the end |

Haptics on the phone of the player: Countdown end: 60 ms (solo rally only; a match of 2 to 4 players has no countdown and no start buzz). No sound is scary or sad (REQ-GM-81): a miss, a fault and an out are funny and soft.

## Open questions

- The swing is found on the TV, in the sensor stream, with the shared `scripts/input/swing_detector.gd` (the Pin Pals detector, moved there on 2026-10-17: a back swing and then a forward swing, no protocol change). Tennis adds `lock_after` (0.6 s), `forward_dir` (a serve is a forward swing that goes down) and `hit_age`, and every slot finds its swings in `PlayerInput` (the `swung` signal). Tennis counts a lighter swing than Pin Pals (the thresholds are 0.75 of the default) and a back swing waits 3 s for its forward swing, because a player draws back while the ball is still coming (2026-10-18, after a device test where swings were not always found). The thresholds are first guesses and are tuned on a device (Manual test 24). A hit needs a back swing first. If the delay is too large, the detection moves to the phone, which needs a new message (`change-protocol` skill).
- The hit window and the green part depend on the real delay of the phone (Test 4, never run on a TV box). Tune on a device.
- Sounds and music for Tennis (the ball, the net, the crowd) and the Hebrew texts are written with the code, and the user reviews them (CLAUDE.md rules for strings).
- Names: "Tennis" is a generic word; the Hebrew name and the texts are checked by a Hebrew reader.
