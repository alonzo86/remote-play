# Mini Golf (`mini_golf`)

Type: 2D with a view from behind the tee (pixel world). Players: 1 to 4. Input: swing and phone direction (the sensor of the phone), Recenter.
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
Plan: `docs/GAMES_ROADMAP.md` (branch 8). Status: built on 2026-10-17 (code, tests and tile); the feel is tested on devices in Manual test 26. The look was shown in the project thread on 2026-10-16 and 2026-10-17 (mocks in the project files, `screens/mini-golf/`, the last one is `v6-*`): the course is seen from behind the golfer, in perspective, in the 8-bit world. The look is not yet approved as final; the user said it can be revisited later.

## Goal

Players take turns on a small golf course. On a turn the player points the phone to aim, then swings the phone back and through like a real putt. The
swing speed sets the power. Each player putts once, then the next player (slot order) until every ball is in the hole. The player with the fewest strokes over
all holes wins. With 1 player the game is practice against the par of each hole.

Registry entry: `description` (one line) and `tile` (`assets/tiles/mini_golf.png`, made by `tools/make_tiles.gd`), see REQ-GM-7.
Visual language: shell, player colors, pixel world (REQ-GM-45 to 49). Check the tile next to the Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-46 | Note | The golfer is a character seen from behind, not a ball. The **shirt** has the slot color and is the only sign of who plays. Hat, trousers and shoes are always white, and the ball is always white. There is no number or avatar on the golfer. Obstacles are never white. |
| REQ-GM-82 | Note | A child must understand the game from one hint line: "Point, swing back, then swing!" (a text row, to be reviewed). The phone needs a swing and at most nothing else. |
| REQ-GM-83 | Note | A water hazard costs nothing (REQ-MG-9). A hole ends after 6 strokes (REQ-MG-8), so a wait is short. Nobody is out and nothing is taken away. |
| REQ-GM-62 | Note | Manual test 26 covers what only a device can check. |
| REQ-GM-98 | Exception | No personal best in this version (REQ-MG-15). |
| REQ-GM-50, 51, 52 | Device | Frame rate, allocation and start time are not measured on a TV box. |

## Requirements

Rules and turns

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MG-1 | The game has 1 to 4 players. A match is a number of holes chosen in the settings (REQ-MG-12), 1 to 5, default 3. | Done | run_tests |
| REQ-MG-2 | **Turns.** Only the golfer whose turn it is and the ball of that player are on the course. The other players are not drawn (REQ-MG-3). Each player putts once, in slot order, and the round repeats until every ball is in the hole or has been picked up (REQ-MG-8). A player who is already in the hole is skipped. The order is the slot order on every hole (it does not change with the score). | Done | run_tests (turn order), smoke_golf |
| REQ-MG-3 | A bar at the bottom shows every player (slot color square, name, strokes on this hole) and marks the player whose turn it is. The top shows the hole number, the number of holes and the par. A banner says whose turn it is for 1.5 s ("MAYA'S TURN", text rows to be reviewed). The phones of the others show a short wait text. | Done | smoke_golf |
| REQ-MG-4 | **Aim.** In the aim phase the phone direction (its turning left and right, not its tilt) moves an aim marker along the ground on the TV. The general direction is shown to the player (the length and the look depend on the difficulty, REQ-MG-13). When the player begins the backswing (the first clear movement back), the direction **locks** and stays locked until the ball stops. RECENTER sets the straight-ahead direction (REQ-GM-37). | Device | run_tests (lock), Device |
| REQ-MG-5 | **Power.** The swing speed sets the power (`scripts/input/swing_detector.gd`, the shared detector of Pin Pals and Tennis, REQ-BW-5, 6 and REQ-TN-5 to 9; the swing is found on the TV, no protocol change). A weak swing gives a short putt, a strong swing a long one. A swing that is only a small movement is not a putt (no stroke, the player tries again). A swing is not accepted before the direction is locked. | Device | run_tests, Device |
| REQ-MG-6 | **Strokes and holes.** Every putt that is accepted counts one stroke. The ball is in when it stops or passes slowly over the hole. A hole ends when all balls are in or picked up. Hole result words: BIRDIE (one under par), PAR, BOGEY (one over), and the plain number for the rest. A hole in one is "HOLE IN ONE!". Words are kind (REQ-GM-84). | Done | run_tests |
| REQ-MG-7 | **The winner** has the fewest strokes over all holes of the match. A tie is shown as a tie. The end is `open_results()` (REQ-GM-72) with the strokes as the score (fewer is better), the medal (REQ-MG-14) and Try again, New game, Back to menu. | Done | smoke_golf |
| REQ-MG-8 | **Pick up after 6 strokes.** When a player has played 6 strokes on a hole and the ball is not in, the ball is picked up with a soft message and the hole counts as 6 for that player. The player waits for the others. | Done | run_tests |
| REQ-MG-9 | **Water.** A ball that touches water makes a small splash, stops, and goes back to the place of the last putt (the putt counts as a stroke). Nothing more is taken away. | Done | run_tests |
| REQ-MG-10 | **Edges.** A strong putt with a bad direction can leave the green. The wall brings the ball back (a bounce); the ball never leaves the course. Sand slows the ball. The windmill and the bumpers are obstacles that bounce the ball. Nothing is taken away for a bounce. | Done | run_tests |
| REQ-MG-11 | A player who leaves: the golfer and the ball go away, the turn goes to the next player, and the strokes stay in the result. When nobody is left the "No players connected" menu opens (REQ-GM-22). A lost phone pauses the game (REQ-GM-30). A phone that comes back keeps its slot (REQ-GM-30a). | Done | smoke_golf |

Holes and settings

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MG-12 | **Holes.** The game has **5 holes**, made in advance (pre-generated and saved as data, not made at run time). The settings view (REQ-GM-90) has a row "Holes" with 1 to 5 (default 3) and the Difficulty row. A match of N holes plays holes 1 to N in order. Every hole has its own par (2 to 4). | Done | run_tests (hole data), smoke_golf |
| REQ-MG-13 | **Difficulty changes the help for aim and power only** (REQ-GM-96; all players have the same difficulty). Easy: a long aim line, a power hint at the swing, and a weak swing still reaches a nearby hole. Medium: a short aim line, no power hint. Hard: no aim line, only a small marker on the ground. The courses are the same on every difficulty. | Device | run_tests, Device |
| REQ-MG-14 | **Medals** (REQ-GM-73), for 1 player: by the total strokes against the par of the played holes. First guess: gold at par or better, silver at most 1 over par per hole, bronze at most 2 over par per hole (the exact tiers are in Parameters). For 2 to 4 players the medal is for the winner. | Done | run_tests |
| REQ-MG-15 | **No personal best in this version.** The key table of the profile (`profile_keys.gd`) has a limited size, and the saved number would be strokes (fewer is better). `best_key()` returns "". A key `mini_golf|<difficulty>|<holes>` can be added later. | Done | smoke_golf (`best_key()`) |
| REQ-MG-16 | The golfer is drawn from behind with an animation of address, backswing, downswing, hit and follow-through. The animation is played by the TV when the swing is found; it is not a live copy of the arm (the detector reports a swing a few samples after the hit). The ball starts at once, and the phone buzzes (30 ms, a strong putt 60 ms). | Device | smoke_golf, Device |

## Parameters

| Value | Easy | Medium | Hard | REQ-MG-13 |
|-------|------|--------|------|-----------|
| Aim line | long | short | none (marker only) | |
| Power hint at the swing | yes | no | no | |
| Weakest swing that moves the ball far enough for a short hole | helped | normal | normal | |
| Medal tiers, strokes over par per hole (silver, bronze) | 1, 2 | 1, 2 | 1, 2 | REQ-MG-14 |

Values in code (first guesses): aim range 1.2 rad to each side; weakest putt 1.5 / 0.5 / 0.3 m/s and strongest 4.5 m/s; swing threshold factor 0.7 on Easy; aim line 3.0 / 1.2 / 0 course units (`mini_golf_game.gd` `LEVELS`, `golf_sim.gd`). Other first guesses: stroke limit 6 (REQ-MG-8); the turn banner 1.5 s; 5 holes with par 2 to 4. All values are tuned on a device (`docs/MANUAL_TESTS.md`, to be added with the code).

## Texts for the user to review

The rows are in `assets/lang/strings.csv` (keys `registry.mini_golf`, `registry.swing_phone_putt` and `mini_golf.*`). The Hebrew texts are written by Claude and need a Hebrew reader. English: "MINI GOLF", "SWING YOUR PHONE TO PUTT THE BALL INTO THE HOLE!", "HOLES" with "1 HOLE" to "5 HOLES", "Hole 2/3  Par 3", "Maya's turn!", "MOVE THE PHONE TO AIM. SWING BACK, THEN FORWARD TO PUTT!", "SWING A BIT MORE!", "SWING FORWARD. A BIGGER SWING GOES FARTHER!" (Easy), "HOLE IN ONE!", "BIRDIE!", "PAR!", "BOGEY", "4 strokes", "Picked up after 6 strokes", "SPLASH! TRY AGAIN FROM HERE", "Hole 2 done!", "Strokes", "Total", and on the phone "MAYA IS PUTTING" (the turn message has the optional field `k` = `golf`, `docs/PROTOCOL.md`).

## Open questions

- The shared detector (`scripts/input/swing_detector.gd`, from Pin Pals, used by Tennis since 2026-10-17) gives `aim_locked` from the start of the back swing and `power` at the release. Mini Golf needs only these two. It needs `lock_after` and `threshold` set for putts (a putt swing is slower than a throw or a stroke); the first values are guesses and are tuned on a device (Manual test 25 for Tennis, a new test for Mini Golf with the code).
- The aim rule (the phone direction moves the aim mark, the first back swing locks it) is Pin Pals' (`docs/games/bowling.md`, REQ-BW-4 and REQ-BW-5). Mini Golf follows it, including the automatic recenter at the start of every turn.
- The look is a mock. The windmill, the pond and the other obstacles and the 5 hole designs still need to be drawn and agreed.
- The golfer's backswing is an animation. A live copy of the phone movement is possible later.
- Names: "Mini Golf" is a generic word; the Hebrew name and the texts are checked by a Hebrew reader. A trademark check of the name is not done.
