# Wobble: notes for Claude

Godot 4.7 project (GDScript): a TV app and a phone controller app. Read `README.md` first.

## Rules for this repository

- Each game has a requirements file `docs/games/<id>.md`. All games also follow `docs/GAME_REQUIREMENTS.md`.
  Change the requirements file in the same commit as the behavior (REQ-GM-5). Use the `add-minigame` skill for new games.
- Do not run the whole test suite after every change. Run the `run-tests` skill only before you submit a pull request, or when the user asks. Run a single test or check while you work only when it is needed. Do not report a pass for a check that did not run.
- Do not decide on your own what the user sees (for example cutting or shortening text, hiding information). Ask the user first.
- Work on the branch the session gives you. Create a pull request only when the user asks for one.

## Tests and coverage

- Every module (each script file in `scripts/`) needs at least 80% line coverage. Check it with `GODOT=<path> tools/coverage.sh`
  before you create a pull request. The script fails when a module is below 80%. CI runs the same check in two jobs: `test` runs the suites of `tests/suites.txt` on the instrumented copy, and `coverage` reads their hits and checks the 80%. A new test suite is added to `tests/suites.txt` only.
  New or changed code comes with its tests in the same change. Say the total and the lowest modules in the pull request.
- Write tests that matter. A test checks a behavior: an input and the result, an error case, a state change, a rule from a
  requirements file. It must fail when that behavior breaks. Do not write a test only to run lines or to raise the number
  (a call without an assertion, a copy of the code in the test). If code has no behavior worth a test, say so and do not test it.
- A module that needs extremely hard work to test today (it needs a real device or an external service) may be set aside:
  add `path | reason` to `tools/coverage/exclusions.txt`, with what is missing. Tell the user in the pull request. Take the line
  away when the module has tests. Do not lower the 80%, and do not set a module aside only because tests are some work.
- Change code so it can be tested when that is a small, honest change (for example `Role.pick()`). Do not add code only for tests.

## Pull requests

- Before you create a pull request: the tests pass, `gdlint` is clean, and `tools/coverage.sh` reports every module at 80% or more
  (see "Tests and coverage"). Do not create the pull request when it does not.
- After you create a pull request, always run the `review` skill on it, and post the findings as one comment on the pull request.
  End the comment with the Claude Code footer. If there are no findings, post a short comment that says so, and list what you checked.
- Do not fix the findings of that review unless the user asks. Tell the user what you found.
- The review comment is also required for later pull requests, not only for the first one.

## Manual tests (for the user)

- The tests that need real devices (phones, a TV or a TV box, a remote, a camera) are in `docs/MANUAL_TESTS.md`: the steps, a result for
  every step, the run log, and the evidence (photos, videos, logs in `docs/evidence/`). Claude cannot run them.
- Claude never marks a manual test as passed. When the user reports a result, Claude writes it in `docs/MANUAL_TESTS.md` (the result of the
  step, the run ID, the evidence path, the measured values), then updates the Summary table there and the list below. Use the `device-test` skill.
- A requirement with the status `Device` is not done until its test is Pass. Do not say that a feature is verified on a device before that.
- A change that needs a device check adds or changes its test in the same commit (REQ-GM-62) and adds it to the list below.
  Every pull request lists the manual tests that are still open for its change.

Tests the user has to run now (status on 2026-10-10 after run R1; the list is in the order to do them):

| Test | What the user does | Why |
|------|--------------------|-----|
| 21 | **New game.** Asteroid Blast with 1 to 4 phones: the ship speed and RECENTER, the rate of fire, the three asteroid sizes and the splitting, the upgrades (force field, weapon up to 4 lasers), a hit with and without a force field, the waves of 30 s with 5 s of rest (how hard from which wave, for Easy, Medium and Hard), the winner and the medal, the leaving of a player, a child of 5 to 8 years, the pixel look from the sofa | Asteroid Blast was added on 2026-10-16 (`docs/games/asteroid_blast.md`). Needed before it is merged. All values (speeds, waves, upgrade times, medal tiers), the pictures, the song, the effects and the Hebrew text are first guesses |
| 20 | **New (player profiles, phases A to C; items 16 and 17 added 2026-10-11).** Items 16 and 17: the dropdown and + on the Connect screen, the one-line avatar carousel, Back and Save at the bottom, no PLAYER button when joined, the avatar on the HUD chips and no number or avatar on any game object. Phase C: personal bests (NEW BEST! on the phone, a worse round, the bests after a restart, no best in the maze and Sumo). Phase B: share a player by QR to a second phone (distance, time, brightness), a rename merge, an iPhone with COPY CODE and PASTE A CODE, a broken code. Phase A: 2 to 4 phones, one profile each with a name and an avatar, a guest, a parent phone with 3 profiles, the same profile on 2 phones, `Sam` and `sam`, the pause card with names, all 32 avatars from the sofa and the scrolling picker, a child of 5 to 8 years, Hebrew names | Profiles were added on 2026-10-10 (FD-22, `docs/PROFILES_PLAN.md`, REQ-FL-69 to 75). Needed before it is merged. The avatar drawings and the texts of the profile screens (also in Hebrew) are first guesses |
| 19 | **New (leader chip, phone score, name tags).** Snowball Splat, Paint Grab and Sumo Bumpers with 4 phones, two with names of 10 letters: one leader chip on one row, TIE, the place and score on each phone, The Amazing Race and Treasure Maze, the name tags in every countdown, a child of 5 to 8 years, Hebrew | The row of 4 player chips wrapped and covered the play area (issue #25). Replaced on 2026-10-10 (FD-21, REQ-FL-67, REQ-GM-46, 46a). Needed before it is merged. The sizes and the place of the tags are first guesses |
| 18 | **New (sound and haptics).** The menu song, the effects of the menus and of the 5 games, the Music, Effects and Mute rows, the phone Settings screen with the HAPTICS switch, the sound of the pause and result menus, a child of 5 to 8 years | Audio was added on 2026-10-10 (FD-20, `docs/AUDIO_PLAN.md`). Needed before it is merged. All songs, effects and levels are first guesses; the render time of a song on a TV box is not measured |
| 16 | **New (arcade look, phase 1).** The TV menus, the phone screens and the game shell (HUD, countdown, menus) in the 8-bit style: read every screen from the sofa, sharp pixels, the cursor, the blinking prompts, A and B on the phone, the HUD of each game with 4 long names, a child of 5 to 8 years | Phase 1 of `docs/ARCADE_STYLE_PLAN.md` was built on 2026-10-10. Needed before it is merged. The games still draw their old worlds (phases 2 to 4). All sizes and values come from the plan |
| 17 | **New (Hebrew and right to left, phase 5).** The first start (the language choice on the logo screen), every TV screen in Hebrew mirrored and readable, the Left and Right keys in a choice row, 2 phones that follow the TV language, the Language row in Settings, each game's HUD in Hebrew, the phone pad; then English again. A person who reads Hebrew | Phase 5 of `docs/ARCADE_STYLE_PLAN.md` was built on 2026-10-10. Needed before it is merged. The Hebrew text was written by Claude: a native reader must check it (wording, kid-friendly words, text that does not fit) |
| 7 | **Retest after R1.** Disconnect and reconnect: items 1 to 6 and the new item 7 (a phone call). Item 1: a phone without Wi-Fi must pause the game with the card '2P LOST CONNECTION'. Item 5: with one phone, the card has only End game, then Resume after the return | R1 found that a phone without Wi-Fi did not pause the game, and that a phone call ended the game with no way to resume. Fixed and changed on 2026-10-09 (REQ-GM-30, 30a) |
| 8 | **Retest after R1.** TV remote: items 2 and 3 (Back must go back one step and must not quit the app, REQ-FL-55). Then items 1, 4 and 5, never run | R1 found that Back quits the app on every screen. Fixed on `games/target-shoot` on 2026-10-09 |
| 8b | **Retest after R1.** New items 8 and 9 (OPTIONS reachable, the Players modal holds the focus, Hebrew tile cursor, white messages on a wide card). Item 2 (the game screenshots show on the Games screen) and items 1 and 3 to 6, never run (item 7 moved to test 17: FD-19 replaced the rule "a TV set to Hebrew stays English") | R1 found missing screenshots and a mirrored layout. Fixed on 2026-10-09. The cause of the missing screenshots is not confirmed: if they are still missing, save `adb logcat -d -s godot` and look for 'Tile image' |
| 1 | **Retest after R1.** Start and join, all 6 steps (step 6 is new: the phone starts in portrait with one splash, and the Disconnect button). Step 3 is new: 'PRESS OK TO CONTINUE' and no Continue button. Steps 1 and 2 are changed: the new name Wobble, the mascot on the splash and the logo picture (uninstall the old Remote Play apps first) | The Connect screen changed after the owner's feedback (FD-17). The app was renamed Wobble and got its logo and splash on 2026-10-10 (FD-21). R0 failed on join by room code, which the plan does not have now |
| 10 | **Retest after R1 (new game); renamed Banana Party 2026-10-16 (jungle, animals, golden monkey).** Banana Party with 1 to 4 phones: the pointer (range, drift in cm), throws, the speed of the Puffs, medal tiers [150, 300, 450], 4-player frame rate, and item 9: a child of 5 to 8 years plays. R2 found that the last digit of a score above 3 digits was cut: fixed, check scores of 4 and 5 digits and a long phone name. New item 10: the settings view and Easy, Medium, Hard (REQ-SS-20 to 22). New item 11: the pixel look of the sky from the sofa | The owner found Target Shoot not playable (R1). It was redesigned on 2026-10-09 as Snowball Splat on branch `games/target-shoot`. Needed before it is merged. The first values (range 25 degrees, speeds, sizes, tiers) are guesses. On 2026-10-10 the world became a pixel world (phase 4 of the arcade style) |
| 9 | **Changed 2026-10-15.** The Amazing Race (was the 3D Marble Race) on a real TV, 2 to 4 phones: all 13 items. Item 13 is new: the Theme row (Candy Road, Space Rally, Jungle Run) and the matching obstacles, the cars that turn, the Hebrew texts. Item 12: the pixel look from the sofa and the frame rate. Item 9: the settings view with Theme, the 11 track tiles, Easy, Medium, Hard | The race became a flat pixel world with cars and three themes (REQ-MR-44 to 48). The tracks, the physics and the sounds are the same. Never run on a device. The cars (64 px), the obstacles (about 52 px), the colors and the Hebrew texts are first guesses |
| 6 | Treasure Maze (was Tilt Maze, new dungeon look 2026-10-15), the rest: item 4 (2 to 4 phones), item 5 (RECENTER recenters, A and B do nothing) and the new item 6 (the settings view and Easy, Medium, Hard) and the new item 7 (the pixel look of the maze from the sofa, thicker walls). Items 1 to 3 passed in R1 ('it works perfectly') | PR 12 removed the A shortcut. The settings view and the maze difficulty were added on 2026-10-09 (REQ-GM-90 to 95, REQ-MZ-9) |
| 14 | **New game.** Paint Grab with 1 to 4 phones: the blob feel (too slow, fast or nervous), painting and taking tiles, Easy, Medium, Hard (floor size, speed, medal tiers in percent), the result menu, a child of 5 to 8 years. New item 10: the pixel look of the floor from the sofa. New item 11 (2026-10-16): the hidden picture under the floor and the bonus pots | Paint Grab and `TiltBody` were added on 2026-10-09 on branch `games/paint-grab`. On 2026-10-10 the floor became a pixel world (phase 4 of the arcade style). All values are first guesses |
| 15 | **New game.** Sumo Bumpers with 2 to 4 phones: the bump and the dash (too strong or weak), the fall and the banner, the length of a round and the wait after a fall, Easy, Medium, Hard, a child of 5 to 8 years. New item 11: the pixel world from the sofa (sharp pixels, readable numbers) | Sumo Bumpers was added on 2026-10-09 on branch `games/sumo-bumpers`. On 2026-10-10 its world became the first pixel world (phase 2 of the arcade style, REQ-GM-47i to 47n). All values are first guesses |
| 11 | The result menus: maze (1 to 4 phones), race (4 phones, inside the screen edge, 'not finished'), Snowball Splat (medal, winner, Tie) | PR 12 (merged) made the result menu generic. The 4-player list was never seen on a TV |
| 12 | Game tiles: compare each tile with the game. All three tiles were remade on 2026-10-09 (4 players, action in the picture) | REQ-GM-49. Claude makes the tiles again when they differ |
| 3 | Sensor directions: items 1 and 4 (the flat Accel value after the fix, Gyro z) | R0 did not check them after the fix |
| 4 | Latency and packet rate on a real TV box, and the delay with a 240 fps camera | R0 ran on a desktop and failed (RTT, Gap). Not representative |
| 13 | Controller on an iPhone: deploy with `IOS_TEAM_ID=<id> tools/deploy-ios.sh`, join with Paste TV link, sensor directions, lock and unlock | New on 2026-10-09. Written on a Mac without Xcode, so never run |

Test 2 (QR scan) passed in R0. Run it again only when the QR plugin or the connect screen changes.
