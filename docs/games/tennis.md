# Tennis (`tennis`)

Type: 2D with a view from behind a baseline (pixel world). Players: 1 to 4. Input: swing and tilt (the sensor of the phone), A (serve toss), Recenter.
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
Plan: `docs/GAMES_ROADMAP.md` (branch 7). Status: requirements only, no code yet. The look was agreed on 2026-10-16 (mock in the project thread).

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
| REQ-GM-62 | Gap | A manual test is added with the code. |
| REQ-GM-50, 51, 52 | Device | Frame rate, allocation and start time are not measured on a TV box. |

## Requirements

Teams and court

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TN-1 | 1 player: the player plays a rally with the ball machine (a friendly pink box at the far end). 2 players: 1 against 1. 3 players: 2 against 1 on the **regular court**, with the same court as 4 players (no smaller court for the single player). 4 players: 2 against 2. With 3 players the single player changes after every game, so that each player is alone in turn. Slots are put in teams by their order. | Open | run_tests (teams), smoke_tennis |
| REQ-TN-2 | The court is a doubles court seen from behind the near baseline, in perspective, with the real lines: outer doubles sidelines, inner singles sidelines, baselines, service lines, the center service line and center marks. The net, a referee tower with an umpire at the net, one ball kid at the net post and stands with seats behind the far end (blank ad boards). | Open | smoke_tennis, review |
| REQ-TN-3 | The near team is drawn large and seen from behind, the far team is small and faces the camera. The ball has a thin black border and a shadow on the court so that its landing place can be seen. | Open | review |
| REQ-TN-4 | A character runs by itself to the place where the ball will land. The player does not move it (REQ-GM-82). A ball is **in** when it lands inside the lines of the court that apply (singles lines for 1 against 1 and for the rally, doubles lines for 2 players on a side). | Open | run_tests |

Hits and serve

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TN-5 | The ball glows when it is the turn of a team to hit. The player of that team who is nearest to the ball is the hitter. A swing counts when it happens while the ball is near that character (the hit window). A swing while the ball is not near does nothing and costs nothing. | Open | run_tests |
| REQ-TN-6 | The hit zone has 3 parts by time: early, green and late. A swing in the green part is a fast shot with sparks. An early or a late swing is a slow, high lob that stays in play (REQ-GM-83). The width of the green part comes from the difficulty (REQ-TN-18). | Open | run_tests |
| REQ-TN-7 | Swing speed sets the power. The tilt of the phone at the moment of the hit sets left or right. A weak swing gives a short slow ball, a strong swing a long fast ball. A ball can be too long (out): a strong swing with a bad tilt may land out, a weak one never does on Easy. | Open | run_tests, Device |
| REQ-TN-9 | Serve: the server presses A to toss the ball up and then swings the phone **from top to bottom**, like a real serve. The swing counts when the ball is high (the serve window). When the server does not swing within 5 s after the toss, the ball falls and the toss is made again (no fault, no point lost). A serve must land in the service box across the net. A serve that lands out is repeated once, then the point goes to the other team. | Open | run_tests, Device |
| REQ-TN-8 | Phone: the swing is the only action to hit. A tosses the ball (serve only). B does nothing. RECENTER recenters the tilt (REQ-GM-37). A hit buzzes the phone (30 ms, a fast shot 60 ms). The hint is one line: "Swing to hit the ball!" (the text is a row of `strings.csv`, to be reviewed by the user). | Open | run_tests, Device |

Scoring

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TN-10 | The game has the setting **Scoring** with the values `Real` (default) and `Quick`. `Real`: the points count 0, 15, 30, 40, game; at 40 to 40 it is deuce and a team needs 2 points more than the other team to win the game (advantage). A match is the first team to win 3 games (the number is a tuning value, REQ-TN-19). `Quick`: the first team to 5 points wins the match, and there are no games. | Open | run_tests |
| REQ-TN-11 | The server changes after every game (`Real`) or every 2 points (`Quick`), in turns inside the team, and the teams take turns to serve. The near team is always the team of slot 1 (the camera does not turn), and the server serves into the service box across the net. | Open | run_tests |
| REQ-TN-12 | A point is lost when: the ball lands out, the ball is not returned, or the ball bounces twice on a side. A net touch in play is "let", the ball goes on. Nothing takes points away (REQ-GM-83). | Open | run_tests |
| REQ-TN-13 | The leader chip (`draw_leader_chip()`, REQ-GM-46) shows the team in front and its games (`Real`) or points (`Quick`), or TIE. A scoreboard at the top shows both teams (slot colors) and the points of the game. Each phone shows its own team's place (REQ-FL-67). In the countdown every character has a name tag (REQ-GM-46a). | Open | smoke_tennis, game_helpers |
| REQ-TN-14 | The end: `open_results()` (REQ-GM-72) with the teams, "X wins!" and Try again, New game, Back to menu. In 1 player mode the title is the medal (REQ-TN-16). | Open | smoke_tennis |

Solo, players and feedback

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TN-15 | 1 player: the ball machine returns every ball it can reach (never misses on purpose). The rally counts the hits in a row. A missed ball ends the rally, the count is kept as the best of the round, and a new rally starts after 2 s. The round lasts 90 s. The score is the longest rally. | Open | run_tests |
| REQ-TN-16 | Medal tiers for 1 player (REQ-GM-73), by the longest rally: `[5, 10, 20]` on Medium (the tiers for Easy and Hard are in REQ-TN-18). First guesses. | Open | run_tests |
| REQ-TN-17 | Personal best (REQ-GM-98): in 1 player mode the key is `tennis|<difficulty>` and the longest rally counts (more is better). The games with 2 to 4 players have no key, because a match has no score that compares between matches (no best). | Open | smoke_bests |
| REQ-TN-20 | A player who leaves: the character goes away and its team plays on with the rest (REQ-GM-21). When a team has no player left, the other team wins at once with the result menu. With 3 players the change of the single player (REQ-TN-1) skips the one who left. When nobody is left the "No players connected" menu opens (REQ-GM-22). A lost phone pauses the match (REQ-GM-30). | Open | smoke_tennis |

## Parameters

| Value | Easy | Medium | Hard | REQ-TN-18 |
|-------|------|--------|------|-----------|
| Width of the green part (of the hit window) | 50% | 35% | 25% | |
| Ball speed (medium shot, px/s) | 260 | 340 | 420 | |
| Ball machine speed (solo) | slow | medium | fast | |
| Medal tiers (longest rally) | [4, 8, 14] | [5, 10, 20] | [6, 14, 28] | |

REQ-TN-19: games to win a match on `Real`: 3 (about 8 minutes with 4 players, a first guess); points on `Quick`: 5. All values are first guesses and are
tuned on a device (`docs/MANUAL_TESTS.md`, to be added with the code).

## Open questions

- How the swing is found: in the sensor stream on the TV or on the phone, and whether the protocol needs a new message (`change-protocol` skill, protocol version). Decide before the code.
- The hit window and the green part depend on the real delay of the phone (Test 4, never run on a TV box). Tune on a device.
- Sounds and music for Tennis (the ball, the net, the crowd) and the Hebrew texts are written with the code, and the user reviews them (CLAUDE.md rules for strings).
- Names: "Tennis" is a generic word; the Hebrew name and the texts are checked by a Hebrew reader.
