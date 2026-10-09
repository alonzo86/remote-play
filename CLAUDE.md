# Remote Play: notes for Claude

Godot 4.7 project (GDScript): a TV app and a phone controller app. Read `README.md` first.

## Rules for this repository

- Each game has a requirements file `docs/games/<id>.md`. All games also follow `docs/GAME_REQUIREMENTS.md`.
  Change the requirements file in the same commit as the behavior (REQ-GM-5). Use the `add-minigame` skill for new games.
- Run the `run-tests` skill before a commit. Do not report a pass for a check that did not run.
- Work on the branch the session gives you. Create a pull request only when the user asks for one.

## Tests and coverage

- Every module (each script file in `scripts/`) needs at least 80% line coverage. Check it with `GODOT=<path> tools/coverage.sh`
  before you create a pull request. The script fails when a module is below 80%. CI runs the same check (job `coverage`).
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

Tests the user has to run now (status on 2026-10-09 after run R1; the list is in the order to do them):

| Test | What the user does | Why |
|------|--------------------|-----|
| 8 | **Retest after R1.** TV remote: items 2 and 3 (Back must go back one step and must not quit the app, REQ-FL-55). Then items 1, 4 and 5, never run | R1 found that Back quits the app on every screen. Fixed on `games/target-shoot` on 2026-10-09 |
| 8b | **Retest after R1.** Item 2 (the game screenshots show on the Games screen) and item 7 (a TV set to Hebrew stays English and left to right). Items 1 and 3 to 6, never run | R1 found missing screenshots and a mirrored layout. Fixed on 2026-10-09. The cause of the missing screenshots is not confirmed: if they are still missing, save `adb logcat -d -s godot` and look for 'Tile image' |
| 1 | **Retest after R1.** Start and join, all 5 steps. Step 3 is new: 'Press OK to continue' and no Continue button | The Connect screen changed after the owner's feedback (FD-17). R0 failed on join by room code, which the plan does not have now |
| 10 | Target Shoot with 1 to 4 phones: the pointer (range, drift in cm), shots, miss lock, medal tiers, 4-player frame rate | New game on branch `games/target-shoot`. Needed before it is merged. The first values (range 25 degrees, tiers 200/350/500, target sizes) are guesses |
| 9 | Marble Race on a real TV, 2 to 4 phones: all 11 items. Item 11 is the check after the shared-code change | PR 12 (merged) changed the countdown, the buzz limit and the end of the race. Never run on a device |
| 6 | Tilt Maze, the rest: item 4 (2 to 4 phones) and item 5 (RECENTER recenters, A and B do nothing). Items 1 to 3 passed in R1 ('it works perfectly') | PR 12 removed the A shortcut |
| 11 | The result menus: maze (1 to 4 phones), race (4 phones, inside the screen edge, 'not finished'), Target Shoot (medal, winner, Tie) | PR 12 (merged) made the result menu generic. The 4-player list was never seen on a TV |
| 7 | Disconnect and reconnect: items 1 to 6, with item 5 (the last phone leaves) in the maze, the race and Target Shoot | The R0 run needs a retest. PR 12 changed the end with no players |
| 12 | Game tiles: compare each tile with the game. The Maze and Marble Race tiles are older than the chip style | REQ-GM-49. Claude makes the tiles again when they differ |
| 3 | Sensor directions: items 1 and 4 (the flat Accel value after the fix, Gyro z) | R0 did not check them after the fix |
| 4 | Latency and packet rate on a real TV box, and the delay with a 240 fps camera | R0 ran on a desktop and failed (RTT, Gap). Not representative |

Test 2 (QR scan) passed in R0. Run it again only when the QR plugin or the connect screen changes.
