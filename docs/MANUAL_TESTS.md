# Manual tests

The tests that only a person with real devices can do: phones, a TV or a TV box, a remote control, a camera.
This file holds **all** of them: the steps, the result of every step, and the evidence. The headless tests (`tests/`, listed in `docs/AUTOMATED_TESTS.md`) do not replace them; a step that a headless test covers fully was moved there.
Style: ASD-STE100 Simplified Technical English. It replaces `docs/MANUAL_TESTS.md` (that file now points here). Test numbers do not change. A step that checks several things is split into steps with letters (3a, 3b); the result of the old step is copied to the new steps unless what is checked changed.

## How to use this file

1. Build and install the APKs (`docs/EXPORT.md`, the `build-deploy` skill). Add a row to the **Run log** (below): the date, the commit, the devices.
2. Do the steps of a test, in order. Each step has a **Check**. For each step, fill the row in the **Results** table of that test:
   - **Result**: `Pass`, `Fail`, `Retest`, `N/A` (cannot be done on this setup) or `Not run`.
   - **Run**: the run ID from the Run log. A retest is a new row or a new line, not an overwrite: keep the first result.
   - **Evidence**: a link to a file in `docs/evidence/<test>/` or to an outside place. The column *Evidence to capture* says what to record.
   - **Notes**: measured values (ms, Hz, cm, seconds), what felt wrong, the constants you changed.
3. Update the **Summary** table at the top, and the table **Tests to run, in order** below it.
4. If a step fails, save the log: `adb logcat -s godot > docs/evidence/<test>/<run>-log.txt`. Then tell Claude the step and the result.

Rules

- Claude does not run these tests and never marks a step `Pass`. Claude writes down what you report, in your words, with the evidence you give.
- A requirement with the status **Device** is not done until the test for it is `Pass`.
- **Join approval (issue #393, phase 4).** The TV setting "APPROVE NEW PLAYERS" (Settings, first row) is ON by default. In **every** test in which a phone joins a TV that you start or restart, the phone waits for the host: press OK on ALLOW on the TV card each time a phone joins (the focus is on ALLOW), or turn the setting OFF first (Settings, first row, press Left; the setting is saved and stays OFF until you turn it ON). A test that tests the approval (Test 34) needs it ON. Tests 1, 2, 7, 8b, 13, 17, 20, 21 and 33 repeat this rule at their start; the other tests do not.
- Evidence files go in `docs/evidence/<test>/`, named `<run>-<what>.<ext>`, for example `R1-t10-04-miss-fade.mp4`. Photos up to 1920 px wide, videos up to 30 s and 20 MB.
  Bigger files: put them in your own storage and link them. Do not commit private data: crop or blur the name of your Wi-Fi and addresses on your home network.
- Do not turn a number into a pass without a measurement. Write the value in the Notes.
- A manual step never needs more than 2 phones (owner decision, 2026-11-17, issue #457).
- Every step has a clear pass or fail criterion (a number with a limit, an exact text, an object that is visible or not). A step that asks for a feeling or an opinion is not a test: do not write it. A step checks one thing, or two linked things; split it when it checks more.

## What you need

- 1 Android TV or streaming box, with the `tv` APK installed, and its remote control.
- 1 to 2 Android phones with the `controller` APK. The phones need Google Play services (for the QR scanner).
- 1 Wi-Fi network for all devices. Best: 5 GHz. Turn off VPN on the phones. A TV app on a desktop is **not** a TV box: say so in the Run log.
- Before every run: the current APKs are installed, **Invert axes** is off, and the TV and the phones are on the same Wi-Fi.

## Run log

One row for each session with the devices. The *Run* ID is used in the result tables.

| Run | Date | Tester | Commit or build | TV device | Phones | Network | Notes |
|-----|------|--------|-----------------|-----------|--------|---------|-------|
| R0 | before 2026-10-08 | (not written down) | prototype, before `main` a599ca3 | TV app on a desktop (not a TV box) | 1 phone | same Wi-Fi | The first run. The date and the build were not written down. |
| R1 | 2026-10-09 | the project owner | branch `games/target-shoot`, HEAD `091cacf` (the app code is the same as `5603ac1`), debug APK installed with `tools/deploy.sh` over `adb connect` | Android TV, Android 10, Ethernet. Language Hebrew, region Israel (IL). Model not written down | not written down (the maze was played) | TV on Ethernet. Same home network | Reported in chat. No photos, videos or logs yet. Found 4 problems (Tests 1, 8, 8b), all fixed in code on `games/target-shoot` and waiting for a retest. Run R2 is the retest. |
| R2 | 2026-10-09 | the project owner | build with Snowball Splat. The commit was not written down | not written down | not written down | not written down | Reported in chat. Only the problem with the score chip was reported. Everything else of the new game is not reported yet. |
| R3 | 2026-10-19 to 2026-10-20 | the project owner | not written down | Android TV | 1 phone | same Wi-Fi | Results typed in the test tracker (first session). Recorded in this file on 2026-10-25. |
| R4 | 2026-10-24 to 2026-10-25 | the project owner | not written down | Android TV | 1 phone | same Wi-Fi | Retests typed in the test tracker (second session), with notes. Recorded on 2026-10-25. |
| R5 | 2026-10-25 | the project owner | not written down | Android phone | 1 phone | same Wi-Fi | Retest of Test 2 steps 3a and 3b and Test 8 step 6a after the fixes of issues #109 and #110 (rebuilt phone app, patch script run first). The owner reported "all these steps now pass, no additional notes". |
| R6 | 2026-10-27 | the project owner | not written down | Android TV | 1 phone (2 phones or more were not available) | same Wi-Fi | Results typed in the test tracker. Recorded in this file on 2026-11-10. Tests 14, 22, 23, 27, 28 and 31. Steps that need 4 phones, 3 phones or 2 phones were marked N/A with the request to remove or automate them. |
| R7 | 2026-11-10 | the project owner | not written down | Android TV | 1 phone (no 2, 3 or 4 phones) | same Wi-Fi | Results typed in the test tracker (the tracker was synced with this file on 2026-11-10). Tests 1, 3, 4, 6, 7, 9, 10, 11, 12, 15, 16, 17 and 23. Steps that need more than 1 phone were marked N/A with the request to remove or automate them: removed from this file (see the History of each test). Recorded on 2026-11-10. |
| R8 | 2026-11-16 | the project owner | not written down | not written down | not written down | same Wi-Fi | Results typed in the test tracker. Tests 14, 19 and 20. Recorded in this file on 2026-11-17. |
| R9 | 2026-11-17 | the project owner | not written down | not written down | not written down | same Wi-Fi | Results typed in the test tracker. Tests 20, 21, 22, 23, 25, 26, 27, 28, 30, 32 and 34 (the join approval, Test 34, was run for the first time). Recorded on 2026-11-17. Steps for 3 or 4 phones and for the debug overlay were marked N/A with the request to remove or automate them (issues #457 and #458). |

## Summary

Update this table after every run. *Latest* is the newest result of the whole test (the worst result of its steps). `Partial (see the result table)` means that some steps are Pass and the other steps are Not run: no step is Fail or Retest. When a step is Fail or Retest, the row names that result and the steps, as in Test 12.

| Test | Title | Needs | Covers | Latest | Run | Evidence |
|------|-------|-------|--------|--------|-----|----------|
| [1](#test-1) | Start and join | 1 phone, 1 TV | REQ-A3, REQ-A4, REQ-FL-5 to 10, REQ-FL-80, 83, 84 | Pass | R7 | |
| [2](#test-2) | QR scan (plugin, unverified) | 1 phone, 1 TV | RISKS C5 | Pass | R5 | |
| [3](#test-3) | Sensor directions | 1 phone, 1 TV | RISKS A2 | Pass | R7 | |
| [4](#test-4) | Latency and packet rate (no manual step since 2026-11-17) | no device | RISKS A3, B1, B2, B3, B5, B6 | Not run (no manual step: see the History; the R7 results of 1a to 4a were removed with the steps) | | |
| [6](#test-6) | Treasure Maze feel | 1 to 2 phones, 1 TV (item 7i: a Mac) | REQ-MZ-4, 6, 7, 8, 9, 12, 13, 15, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-90 to 95 | Pass | R7 | |
| [7](#test-7) | Disconnect and reconnect | 2 phones, 1 TV | REQ-GM-30, REQ-GM-30a, REQ-T5, REQ-N5, REQ-N6, REQ-FL-25, REQ-FL-52, REQ-FL-52a, REQ-FL-52b, REQ-FL-52c, REQ-FL-55, REQ-GM-31a, REQ-MR-14, REQ-MZ-8 | Partial (see the result table) | R7 | |
| [8](#test-8) | TV remote | 1 phone, 1 TV with its remote | REQ-GM-31, REQ-GM-31a, REQ-GM-33, REQ-FL-41, REQ-FL-52c, REQ-FL-55 | Partial (see the result table) | R5 | |
| [8b](#test-8b) | The TV flow and the style | 1 to 2 phones, 1 TV (item 7 moved to Test 17) | REQ-FL-1 to 46, REQ-FL-56, 57, REQ-FL-81, FD-1 to 17, FD-23 | Pass | R3 | |
| [9](#test-9) | Car Race | 1 to 2 phones (2 for items 11a and 14c), 1 TV | REQ-MR-*, REQ-GM-37, REQ-GM-47i to 47n | Pass | R7 | |
| [10](#test-10) | Banana Party (pointer) | 1 to 2 phones, 1 TV, a child for item 9 | REQ-SS-*, REQ-GM-47i to 47n, REQ-GM-80 to 84, 90 to 95, RISKS A4, REQ-GM-37 | Pass | R7 | |
| [11](#test-11) | Result menus (REQ-GM-72) | 1 to 2 phones, 1 TV | REQ-GM-34, REQ-GM-40, REQ-GM-41, REQ-GM-72, REQ-GM-73, REQ-MZ-5, REQ-MR-31 | Pass | R7 | |
| [12](#test-12) | Game tiles and the toy box look (REQ-GM-49) | 1 TV (phones for the game photos) | REQ-GM-49, REQ-FL-20, REQ-FL-40, REQ-GM-41 | Retest (steps 1c, 11) | R7 | |
| [13](#test-13) | Controller on an iPhone | 1 iPhone, 1 Mac with Xcode, 1 TV | `tools/deploy-ios.sh`, RISKS A2, REQ-FL-58, 68, 83, 84 | Not run |  | |
| [14](#test-14) | Paint Grab (tilt) | 1 phone, 1 TV, a child for item 7 | REQ-PG-*, REQ-GM-80 to 84, 90 to 97, REQ-GM-37, REQ-GM-47i to 47n | Pass | R8 | |
| [15](#test-15) | Sumo Bumpers (tilt and A) | 2 phones, 1 TV, a child for item 8 | REQ-SB-*, REQ-GM-80 to 84, 90 to 97, REQ-GM-37, REQ-GM-47i to 47n | Pass | R7 | |
| [16](#test-16) | The arcade look (phase 1) | 1 to 2 phones, 1 TV on 1080p (and a 4K TV if you have one), a child for item 8 | REQ-FL-37 to 46, REQ-FL-38a, 41a, 52, 53, REQ-GM-45, 46, FD-18 | Partial (see the result table) | R7 | |
| [17](#test-17) | Hebrew and right to left (phase 5) | 2 phones (one set to Hebrew), 1 TV (once set to Hebrew, once to English) | REQ-FL-54, 60 to 63, REQ-GM-47o, FD-19 | Pass | R7 | |
| [18](#test-18) | Sound and haptics | 1 to 2 phones, 1 TV | REQ-FL-64 to 66, REQ-GM-49a to 49c, REQ-GM-43 | Not run | | |
| [19](#test-19) | Leader chip and phone score | 2 phones (names of 10 letters), 1 TV, a child for item 8 | REQ-FL-67, REQ-FL-68, REQ-GM-46, FD-21 | Fail (steps 3c; built for issue #455, run again) | R8 | |
| [20](#test-20) | Player profiles (names, avatars, personal bests, copy by QR) | 2 to 4 phones, 1 TV, a child for item 7 | REQ-FL-69 to 79, REQ-GM-98 to 101, REQ-N8, REQ-C7 to C11, FD-22 | Partial (see the result table) | R9 | |
| [21](#test-21) | Join by room code and About screens | 2 phones (one Android, one iPhone if possible), 1 TV | REQ-FL-83, REQ-FL-84, REQ-FL-85, FD-25, FD-28 | Pass | R9 | |
| [22](#test-22) | Star Shield (tilt, waves, upgrades) | 1 to 2 phones, 1 TV, a child for item 9 | REQ-AB-*, REQ-GM-80 to 84, 90 to 97, REQ-GM-37, REQ-GM-47i to 47n | Partial (see the result table) | R9 | |
| [23](#test-23) | Bowling (aim with a finger, swing to throw) | 1 to 2 phones, 1 TV, a child for item 11 | REQ-BW-*, REQ-GM-80 to 84, 90 to 98, REQ-GM-37, REQ-GM-47i to 47n | Partial (see the result table) | R9 | |
| [24](#test-24) | Swing detector for Tennis (no manual step since 2026-11-17) | no device | REQ-TN-5 to 9 (`docs/games/tennis.md`), REQ-T4, REQ-T7 | Not run (no manual step: see the History; issue #209 has no manual test) | | |
| [25](#test-25) | Tennis (swing, toss, serve, rally, scoring) | 1 to 2 phones, 1 TV, a child for item 12 | REQ-TN-* (`docs/games/tennis.md`), REQ-GM-80 to 84, 90 to 97, REQ-GM-37, REQ-GM-47i to 47n | Fail (steps 1b) | R9 | |
| [26](#test-26) | Mini Golf (aim, putt power, turns, 5 holes) | 1 to 2 phones, 1 TV, a child for item 12 | REQ-MG-* (`docs/games/mini_golf.md`), REQ-GM-80 to 84, 90 to 97, REQ-GM-37, REQ-GM-47i to 47n | Pass | R9 | |
| [27](#test-27) | Air Hockey (tilt, enroll with A, ROBO the bot) | 1 to 2 phones, 1 TV with its remote, a stopwatch, a phone camera (240 fps for item 3b), a child for item 9 | REQ-AH-* (`docs/games/air_hockey.md`), REQ-GM-80 to 84, 90 to 97, REQ-GM-105, 106, REQ-GM-47i to 47n | Partial (see the result table) | R9 | |
| [28](#test-28) | Mole Bonk (pointer, bonk, moles, difficulty) | 1 to 2 phones, 1 TV, a 240 fps camera, a child for item 10 | REQ-WM-* (`docs/games/whack_a_mole.md`), REQ-GM-80 to 84, 90 to 97, REQ-GM-37, REQ-GM-47i to 47n | Pass | R9 | |
| [29](#test-29) | Sheep Herding (tilt, a team herds the sheep into the pen) | 1 to 2 phones, 1 TV, a child for items 8a to 8d | REQ-SH-* (`docs/games/sheep_herding.md`), REQ-GM-80 to 84, 90 to 97, REQ-GM-37, REQ-GM-47i to 47n | Not run | | |
| [30](#test-30) | Tower Builder (turns, swing, drop, wobble, 12 bricks) | 1 to 2 phones, 1 TV, a stopwatch, a child for item 9 | REQ-TB-* (`docs/games/tower_builder.md`), REQ-GM-80 to 84, 90 to 97, REQ-GM-47i to 47n | Pass | R9 | |
| [31](#test-31) | Freeze Dance (wiggle, freeze, difficulty) | 1 to 2 phones, 1 TV, a stopwatch, a 240 fps camera (item 4a), a child for item 10 | REQ-FD-* (`docs/games/freeze_dance.md`), REQ-GM-80 to 84, 90 to 97, REQ-GM-102, REQ-GM-47i to 47n | Partial (see the result table) | R6 | |
| [32](#test-32) | Bumper Cars (tilt, drive over stars and bump the others) | 2 phones, 1 TV, a stopwatch, a child of about 5 to 8 years | REQ-BC-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-47i to 47n | Pass | R9 | |
| [33](#test-33) | iPhone QR scanner (camera view, permission, cancel, privacy) | 1 iPhone, 1 Mac with Xcode, 1 TV, a second phone, a child for item 9b, a Hebrew reader for item 8a | REQ-FL-58, 88 to 92 (`docs/TV_FLOW.md`), issue #299 | Not run |  | |
| [34](#test-34) | Join approval with the TV remote (built, not run) | 2 phones, 1 TV with its real remote, a stopwatch, a native reader of Hebrew for item 7a | REQ-FL-93 to REQ-FL-104, FD-30 (`docs/TV_FLOW.md`), issue #393 | Partial (see the result table) | R9 | |

Test 5 (pointer drift) was removed on 2026-10-07 with the old pointer test. The pointer is checked again in Test 10.

## Tests to run, in order

Moved from `CLAUDE.md` on 2026-10-31 (issue #312). Brought in line with the Results tables on 2026-11-01. The Sababi Test Tracker holds the live results; the Results tables of each test are the source for this table.

Tests the user has to run now (status on 2026-11-17 after run R9; the list is in the order to do them. Open failures: step 3c of Test 19 (issue #455) and step 1b of Test 25 (issue #456); steps 6b of Test 27 and 4g of Test 23 passed in R9 after their fixes (issues #431 and #432 are closed)). Tests 4 and 24 have no manual step since 2026-11-17 (the owner's decision of issue #458: no manual step reads the debug overlay; their History says which automated tests cover them), so they are not in the table; issue #437 (RTT of Test 4), issue #386 (a run on a TV box) and issue #209 (the swing detector on a device) have no manual test now. Tests 1, 2, 3, 6, 8, 8b, 9, 10, 11, 14, 15, 17, 21, 26, 28, 30 and 32 have no open step (all steps Pass), so they are not in the table; run them again only when their area changes. Tests 13 and 33 (iPhone) are for the next release (iOS, issue #415): they are at the end of the table and are not run for the first (Android) release:

| Test | What the user does | Why |
|------|--------------------|-----|
| 34 | **Open: items 4c** (after run R9 of 2026-11-17; 22 of 23 steps are Pass or N/A in the Results table). | The owner decided on 2026-11-07 (issue #385) that the host approves each new phone with the remote; the details are FD-30 and REQ-FL-93 to REQ-FL-104. All texts, the card, the 60 s and the 1 s guard are first guesses; the Hebrew is written by Claude |
| 31 | **Open: items 10c, 12b, 13** (after run R7 of 2026-11-10; step 11 was removed on 2026-11-10; 11 of 14 steps are Pass or N/A in the Results table). | Freeze Dance was added on 2026-10-24 (`docs/games/freeze_dance.md`). Needed before it is merged. Every value (the wiggle level, the limit for "still", the grace time, the music and freeze lengths), the pictures, the song and the Hebrew texts are first guesses |
| 29 | **New game.** Sheep Herding with 1 to 4 phones: the tile against the game, a tester points at the gate, an adult herds all the sheep in the time (4 and 6a), a child of 5 to 8 years, the how-to line, the Hebrew texts. The tilt times, how the sheep run, the buzz and the dog size are automated (A-29-*) | Sheep Herding was added on 2026-10-23 (`docs/games/sheep_herding.md`, issue #98). Needed before it is merged. All values (dog speed, the scare distance, the sheep speed, the gate, the time of a round), the pictures, the song and the Hebrew texts are first guesses; a Hebrew reader checks the 7 new texts |
| 27 | **Open: items 1a, 11b** (after run R9 of 2026-11-17; 12 of 14 steps are Pass or N/A in the Results table). | Air Hockey and ROBO were added on 2026-10-23 (`docs/games/air_hockey.md`, REQ-GM-105, 106). Needed before they are merged. All values (the mallet and puck physics, the goal size, the levels of ROBO), the pictures, the song, the effects and the Hebrew texts are first guesses |
| 25 | **Open: items 1b** (after run R9 of 2026-11-17; 20 of 21 steps are Pass or N/A in the Results table). Step 1b failed (issue #456). | Tennis was added on 2026-10-17 (`docs/games/tennis.md`). Needed before it is merged. It uses the swing detector that machines check (A-24-*; Test 24 has no manual step). All values (the hit window, the green zone, the ball speeds), the pictures, the song and the Hebrew texts are first guesses |
| 23 | **Open: items 14c** (after run R9 of 2026-11-17; 20 of 21 steps are Pass or N/A in the Results table). | Bowling was added on 2026-10-16 (`docs/games/bowling.md`). Needed before it is merged. It was only tested with made-up sensor values (the thresholds and the forward ratio `FWD_RATIO` were tuned on 2026-10-29 with made-up series only): the swing thresholds, the strip size, the ball speeds, the pictures, the song, the effects and the Hebrew text are first guesses |
| 22 | **Open: items 12b** (after run R9 of 2026-11-17; 14 of 15 steps are Pass or N/A in the Results table). | Star Shield was added on 2026-10-16 (`docs/games/asteroid_blast.md`). Needed before it is merged. All values (speeds, waves, upgrade times), the pictures, the song, the effects and the Hebrew text are first guesses |
| 20 | **Open: items 1b3, 14a, 14b** (after run R9 of 2026-11-17; 12 of 14 steps are Pass or N/A in the Results table). | Profiles were added on 2026-10-10 (FD-22, `docs/PROFILES_PLAN.md`, REQ-FL-69 to 75). Needed before it is merged. The avatar drawings and the texts of the profile screens (also in Hebrew) are first guesses |
| 19 | **Open: items 3c, 3d** (after run R9 of 2026-11-17; 5 of 7 steps are Pass or N/A in the Results table). Step 3c failed (issue #455); the phone result line is built (PR of issue #455) and step 3c is the open device check with the new wording. | The row of 4 player chips wrapped and covered the play area (issue #25). Replaced on 2026-10-10 (FD-21, REQ-FL-67, REQ-GM-46; the name tags of the countdown were removed on 2026-10-21 by decision of the owner). Needed before it is merged. The sizes are first guesses |
| 18 | **New (sound and haptics).** The menu song, the effects of the menus and of all games, the Music and Effects rows, the phone Settings screen with the HAPTICS row, the sound of the pause and result menus, a child of 5 to 8 years | Audio was added on 2026-10-10 (FD-20, `docs/AUDIO_PLAN.md`). Needed before it is merged. All songs, effects and levels are first guesses; the render time of a song on a TV box is not measured |
| 16 | **Open: items 6b2** (after run R7 of 2026-11-10; 11 of 12 steps are Pass or N/A in the Results table). | Phase 1 of `docs/ARCADE_STYLE_PLAN.md` was built on 2026-10-10. Needed before it is merged. The games are in the pixel style too (phases 2 to 4 are built). All sizes and values come from the plan |
| 7 | **Open: items 6a, 6b, 6f, 6g, 6h, 6i, 9a and 9b** (after run R7 of 2026-11-10; 9a and 9b changed on 2026-11-10 with the softer lost-link look, issue #433, and are Not run again; 6b changed with the text HOLD TO DISCONNECT and 6f to 6i are new, issue #435, REQ-FL-52c). | R1 found that a phone without Wi-Fi did not pause the game, and that a phone call ended the game with no way to resume. Fixed and changed on 2026-10-09 (REQ-GM-30, 30a) |
| 8 | **Open: item 6b** (changed 2026-11-10, issue #435: Back on the phone in a game asks the TV "End the game?"; the other steps are Pass in R3 to R5). | Back on the pad in a game no longer opens QUIT SABABI APP? on the phone (REQ-FL-52c, REQ-FL-55). Needs a phone and the real Android Back key |
| 12 | **Open: items 1c, 10, 11** (after run R7 of 2026-11-10; 10 of 13 steps are Pass or N/A in the Results table). | REQ-GM-49. Claude makes the tiles again when they differ |
| 13 | **Next release (iOS, issue #415).** **Open: items 1a, 1b, 2b, 2c, 2d, 4a, 4b, 5a, 5b, 5c, 6b, 6d, 7** (after run R9 of 2026-11-17; 0 of 13 steps are Pass or N/A in the Results table). | New on 2026-10-09. Written on a Mac without Xcode, so never run |
| 33 | **Next release (iOS, issue #415).** **New (iPhone QR scanner).** An iPhone with a Mac and Xcode: build the plugin and deploy (1a), the scan button, the camera question on the first scan and the view (2a, 2b, 3a, 3b), a TV code, a profile code and a web page code (4a to 4d), CANCEL, swipe down and the home button (5a to 5c), the camera off in Settings and on again (6a, 6b), no photo saved and only Camera and Local Network listed (7a, 7b), Hebrew from a Hebrew reader (8a), a dark room and a child of 5 to 8 years (9a, 9b). Run test 13 steps 1a to 2d first. Nothing here can be done headless | The iPhone scanner was planned on 2026-11-01 (`docs/IOS_SCANNER_PLAN.md`, issue #299, REQ-FL-58, 88 to 92). The plugin source is written on Linux and was never built or run: every value, the plugin and the texts (also the Hebrew camera question) are unverified. Needed before it is merged and before the privacy notice text about the iPhone camera is final |

Test 2 (QR scan) passed in R0. Run it again only when the QR plugin or the connect screen changes. It changed on 2026-10-21 (Back in the scanner is a cancel, issue #43); item 3a passed again in R5.

## Test 1

### Start and join

Needs: 1 phone, 1 TV, a stopwatch. Covers: REQ-A3, REQ-A4, REQ-FL-5 to 10, REQ-FL-80, 83, 83a, 84, FD-28.

Join approval (issue #393, phase 4): the TV setting "APPROVE NEW PLAYERS" is ON by default, so each phone that joins in this test waits for the host. Before the first join either turn the setting OFF (Settings, first row, press Left) or press OK on ALLOW on the TV card each time a phone joins (the focus is on ALLOW; REQ-FL-93, 94).

Uninstall the old apps first. The package names changed (FD-26 and FD-27; the list is in `README.md`). Use a stopwatch for every time limit.

**Steps**

1a. Look at the home row of the Android TV (the launcher). Check: the app tile shows the name **Sababi: TV Games**, and the banner shows the pixel mascot (a yellow face with sunglasses) and the word SABABI. (Sizes and colors of the icon, the adaptive layers and the banner are in the automated tests, A-1-1.)
1b. Start the TV app. Check: the Android splash shows the pixel mascot (a yellow face with sunglasses) on a black background.
2a. Start the controller app on one phone. Check: the app is named **Sababi: Remote**.
2b. Look at the phone screen. Check: the screen is in **portrait** and shows the title SABABI.
4c. Tap **Disconnect**. Type the room code of the TV in lower case with a space after the second letter, and tap **JOIN**. Check: the phone shows the waiting screen with the square of slot 1 less than 5 seconds after the tap (stopwatch), and the TV shows the player in slot 1. (REQ-FL-83. The phone builds the TV address from its own Wi-Fi address.)
4d. Tap **Disconnect**. Type the room code with its last letter changed to another letter of the code alphabet, and tap **JOIN**. Check: less than 5 seconds after the tap the status line of the phone shows "CAN'T FIND THIS ROOM. CHECK THE CODE, OR SCAN THE QR CODE." or "WRONG ROOM CODE.", and the TV shows no new player.
4e. **Issue #241.** Tap **Disconnect** and look at the Connect screen on an Android phone. Check: the SCAN QR CODE button is as high as the JOIN icon button (the white enter arrow on black), with no yellow frame, under the code field and JOIN (yes or no; changed 2026-11-02, it was above the field, 260 px high and had a yellow frame). Tap it and scan the TV code: the phone shows the waiting screen in less than 5 seconds (stopwatch).
4f. Tap **Disconnect**. Type the 4 letters of the room code. Check: the phone does not join by itself (still on the Connect screen 3 s after the 4th letter, 3 of 3 tries) and the letters show as capitals while you type; then tap JOIN: the phone shows the waiting screen less than 5 seconds later. A child of 5 to 8 years reads the 4 letters from the TV and types them: note the seconds and the wrong letters.
4g. **New 2026-11-06 (owner); changed 2026-11-10 (owner: the app QR code moved from the Connect screen to the logo screen).** Start the TV app and look at the logo screen from the sofa. Check: the logo is at the top and the card with the words GET THE PHONE APP TO PLAY and its QR code under it, both centered, the screen is still there after 10 s (it does not go on by itself), and OK goes on to the Connect screen, which has only the room QR code with the words SCAN TO JOIN (4 of 4 yes). With the TV set to Hebrew, the Hebrew title of the card is read by a native reader: it wraps to two or more lines inside the card and reads right (yes or no). Scan the code on the logo screen with a phone camera: it opens the page https://alonzo86.github.io/remote-play/get/ (it works once the repository is public and Pages is on, issue #37; the store button says "Coming soon" until the app has its store page).
4h. **New 2026-11-06 (owner); changed 2026-11-10 (owner: the two codes are no longer on one screen).** On the Connect screen, hold a phone with the Sababi app 2 m from the TV and tap SCAN QR CODE 5 times (re-aiming each time). Check: the phone joins in 5 of 5 scans (there is only the room code in view).
4i. **New 2026-11-12 (owner).** On an Android phone with the system buttons hidden (full screen), open the Sababi app and look at the Connect screen. Check: a QUIT icon button (a power sign) is in the corner at the end of the top row, after ABOUT and SETTINGS (at the right in English, at the left in Hebrew); a tap opens the question QUIT SABABI APP? with STAY and QUIT; STAY closes it and QUIT leaves the app.
4j. **New 2026-11-12 (owner).** On the TV, open the Games screen. Check: the header has the players badge, then the ABOUT icon button, then the OPTIONS icon button (no word on them); OK on ABOUT opens the About screen and Back returns to ABOUT; OK on OPTIONS opens Settings, which has no About row.
6a. Tap **Disconnect** on the phone. Check: within 6 seconds the TV slot of the phone is empty (the slot may show "LOST" for 5 seconds at most, REQ-FL-8, issue #44).
6b. Close the controller app and start it again, and film the start. Check: the Android splash (the mascot on black) is already in portrait and the phone does not turn at any frame of the video, and it is the only splash: the Connect screen follows at once, with no logo screen.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the TV home row with the app name and the banner | Pass | R3 |  |  |
| 1b | Photo of the TV splash | Pass | R3 |  |  |
| 2a | Photo of the phone launcher with the app name | Pass | R3 |  |  |
| 2b | Photo of the phone in portrait | Pass | R3 |  |  |
| 4c | Video of the typed code and the tap on JOIN with the stopwatch (seconds until the waiting screen) | Pass | R4 |  | R3: Pass - 1. instead of "Discovered TVs" now shows "ROOMS" - this is the correct behavior; R4: Pass |
| 4d | Photo of the status line after the wrong code, with the seconds | Pass | R4 |  | R3: Pass - 1. instead of "Discovered TVs" now shows "ROOMS" - this is the correct behavior; R4: Pass |
| 4e | Photo of the Connect screen; note: the seconds to the waiting screen | Pass | R7 |  | R7: Pass Added 2026-10-30 (issue #241). |
| 4f | Video of typing 4 letters; note: seconds, and for the child the wrong letters | Pass | R7 |  | R7: Pass Added 2026-10-30 (issue #241). |
| 4g | Photo of the logo screen and of the Connect screen | Pass | R7 |  | R7: Pass Added 2026-11-06; changed 2026-11-10. |
| 4h | Note: scans of 5 that joined | Pass | R7 |  | R7: Pass Added 2026-11-06; changed 2026-11-10. |
| 6a | Photo of the TV slots 5 s after the tap, and the seconds until the slot is empty | Pass | R4 |  | R3: Pass - when disconnected, the tv still shows the previously connected player with status "LOST" which disappears after some time. i think the "LOST" state is no needed here, if a player disconnected they need to be removed from the list or maybe give some grace but no more then 3-5 seconds; R4: Pass |
| 6b | Video of the app start in portrait: splash, then the Connect screen | Pass | R3 |  | R3: Pass - when disconnected, the tv still shows the previously connected player with status "LOST" which disappears after some time. i think the "LOST" state is no needed here, if a player disconnected they need to be removed from the list or maybe give some grace but no more then 3-5 seconds |

Items 1c to 1f, 3a, 3b, 3c, 3d, 4a, 4b, 6c and 6d moved to the automated tests (docs/AUTOMATED_TESTS.md, A-1-2, A-1-3, A-1-4, A-1-6). Steps 8.5a and 8.5b of Test 8 (the Android TV home row) are now part of step 1a. The numbers of the other items do not change.

Measurements (not steps): write the seconds from JOIN to the waiting screen (4c) and to the error text (4d) in the Notes of the step.

History:

- 2026-11-10 (recorded; R7 in the tracker): Pass: steps 4e, 4f, 4g, 4h.
- 2026-10-21 (issue #52, FD-28): steps 4c and 4d are about the typed room code now (they were about Refresh and the scan of the network, which are gone). Their old results were "Not run", so nothing is lost.
- 2026-10-21 (automated): steps 1c to 1f, 3a, 4a, 4b and 6c moved to the automated tests (`r1_tv_screens`, `join_flow`). The R1 result of step 3a (Retest) is kept in the History line below and in the result database.
- R1: **Retest** (step 3). Design change after the first run on a real Android TV: the owner found the Continue button redundant and the count of players repeated the slot list. Changed on 2026-10-09 (FD-17, REQ-FL-6, 7): the button and the count are gone, and 'PRESS OK TO CONTINUE' shows once a phone has joined. Step 3a is automated now (A-1-3).
- R0: **Fail**. Join by room code failed with 'Room YCNW not found, is the tv on the same wi-fi?'. The list and the IP worked. TV app on a desktop, phone on the same Wi-Fi. The plan has no join by room code now, so every step needs a retest.

## Test 2

### QR scan (plugin, unverified)

Needs: 1 phone, 1 TV, a stopwatch, a second QR code that is not from Sababi (for example a code with the text `https://example.com`). Covers: RISKS C5.

Join approval (issue #393, phase 4): the TV setting "APPROVE NEW PLAYERS" is ON by default, so each phone that joins in this test waits for the host. Before the first join either turn the setting OFF (Settings, first row, press Left) or press OK on ALLOW on the TV card each time a phone joins (the focus is on ALLOW; REQ-FL-93, 94).


**Steps**

1. Tap **Disconnect**. Look at the Connect screen. Check: the button says **SCAN QR CODE**. (If there is no scan button, the plugin is not in the build: run `tools/patch_android_manifest.sh controller` and export the controller again.)
2a. Tap the button and scan the QR code on the TV. Check: the phone shows "WAITING FOR THE HOST" less than 5 seconds after the scanner closes (stopwatch).
2b. (Removed with the join PIN, issue #52. The QR code holds no PIN and the phone asks for nothing after the scan.)
3a. Tap the scan button, then press Back in the scanner. Check: the Connect screen shows no message that starts with "QR SCAN FAILED". (R1 failed: the Google scanner reports Back as a failure, "Failed to scan code". Fixed on 2026-10-21 in `QrScannerPlugin.java`, which now sends "cancelled" for `MlKitException.CODE_SCANNER_CANCELLED`, issue #43: run it again on a build with the new plugin.)
3b. Check: the app did not close, and a tap on the scan button opens the scanner again.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Phone screenshot of the connect screen: the button text | Pass | R4 |  | R4: Pass - "TV link" feature was removed (FD-28, issue #52) - this step is no longer relevant; R4: Pass |
| 2a | Screen recording of the scan, with the seconds to join | Pass | R3 |  |  |
| 2b | (Removed with the join PIN) | N/A | R3 |  |  |
| 3a | Phone screenshot after Back in the scanner | Pass | R5 |  | R5: Pass, no notes (issue #109). Before: R3: Fail - an error is shown: "QR SCAN FAILED: FAILED TO SCAN CODE"; R4: Fail - an error is shown: "QR SCAN FAILED: FAILED TO SCAN CODE" Issue #109. |
| 3b | Note: the app is open; `adb logcat -d -s godot > docs/evidence/2/<run>-log.txt` if it crashes | Pass | R5 |  | |

Item 4 (a QR code that is not from Sababi) moved to the automated tests (docs/AUTOMATED_TESTS.md, A-2-4). Items 1, 2a, 3a and 3b stay: they need the real scanner. Item 2b was removed with the join PIN (issue #52). The numbers of the other items do not change.

History:

- 2026-10-25 (R5): steps 3a and 3b pass after the fix of issue #109 (a phone app rebuilt with the patch script). The owner gave no notes.
- 2026-10-25 (R4 notes): step 1 lost the sentence about the missing plugin as a defect (the PASTE ROOM LINK button stays for a phone without the scanner; the tester noted that the TV link feature was removed: question to the owner). Steps 3a and 3b failed again after the fix of #43: issue #109.
- R0: **Pass**.

## Test 3

### Sensor directions

Needs: 1 phone, 1 TV, a protractor or a phone angle app (for the tilt angle). Covers: RISKS A2.

Before the test: **Invert axes** is off (Settings screen of the TV). Hold the phone in portrait with the screen toward you. Start a Treasure Maze round for items 2b and 3b.

| Item | Action | Check |
|------|--------|-------|
| 2b | Tilt the right side down to about 45 degrees | The ball rolls toward the right edge of the TV screen |
| 3b | Tilt the top of the phone up to about 45 degrees | The ball rolls toward you (toward the bottom edge of the TV screen) |

Items 1, 2a, 3a and 4 (the values of `Accel` and `Gyro` in the debug overlay: flat, right side down, top up, a turn to the left) were removed on 2026-11-17 (owner decision: no manual step reads the debug overlay, issue #458). What is checked by a machine instead: the sign fix of the accelerometer (A-3-1, `run_tests`) and the way a tilt moves the ball, the car, the cursor, the blob and the ship (A-3-2). The real values of a real phone are not read by anything now (see the History). If a direction fails, do not use **Invert axes**: write the axis in the Notes and tell Claude (RISKS A2: the fix is in `sensor_sampler.gd`).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 2b | Video of the ball rolling right | Pass | R7 |  | R7: Pass Before (R0): Pass - R0: after the fix the tilt directions in the maze are right. |
| 3b | Video of the ball rolling toward you | Pass | R7 |  | R7: Pass Before (R0): Pass - R0: after the fix the tilt directions in the maze are right. |

History:

- 2026-11-17 (steps removed): Owner decision of 2026-11-17 (issue #458: "remove every manual step that needs the debug overlay"). Steps 1, 2a, 3a and 4 (the values of `Accel` x, y, z and `Gyro` z in the overlay) are removed; steps 2b and 3b (the direction of the ball in the maze) stay. Covered by machines: the sign fix of the accelerometer is A-3-1 (`run_tests`: Android and iOS flipped, other platforms not) and the direction of the tilt in the games is A-3-2 (`smoke_maze`, `smoke_tv`, `auto_paint`). What is not verified by anything now: the real values of the accelerometer and the gyroscope of a real phone (flat: z between +9.3 and +10.3; a tilt of 45 degrees: x below -4.0 and y above +4.0) and the sign of the real gyro z (a turn to the left is positive). The steps had the result Pass in R7; those results are removed with them.
- 2026-11-10 (recorded; R7 in the tracker): Pass: steps 1, 2a, 2b, 3a, 3b, 4.
- R0: **Pass**. The phone reported every accelerometer axis inverted (flat, screen up: z = -9.83). Fixed in `sensor_sampler.gd`. No invert switch is needed. After the fix: the tilt directions in the maze are right. The gyro rows were not checked again, so Test 3 needs a retest of items 1 and 4.

## Test 4

### Latency and packet rate

Needs: no device. Covers: RISKS A3, B1, B2, B3, B5, B6 (no manual step).

**This test has no manual step since 2026-11-17.** Every step read the debug overlay (RTT ms, Rx Hz, Gap ms, Lost), and the owner decided on 2026-11-17 (issue #458) that no manual test uses the debug overlay. The test stays in this file with its number. What a machine checks: the same four values on the loopback with 1 phone and with 4 phones in the maze (A-4-1: `net_rate`) and the response in frames (A-4-5: `net_rate`). What is not verified by anything now: the round trip time, the packet rate, the longest gap and the lost packets of a real phone on a real Wi-Fi and a real TV box (RISKS A3, B1, B6), and the delay of the real phone and TV (REQ-GM-12, 150 ms, stays Device).

**Results**

No step. The results of the old steps (steps 1a to 4a: Fail, Pass, Pass, Pass in R7) are in the History.

History:

- 2026-11-17 (steps removed): Owner decision of 2026-11-17 (issue #458: "remove every manual step that needs the debug overlay"). Steps 1a (RTT ms), 2a (Rx Hz), 3a (Gap ms) and 4a (Lost) are removed: each one read the overlay row of the phone. Test 4 has no step now. Covered by machines: A-4-1 (`net_rate`: round trip, packets a second, longest gap and lost packets, 1 phone and 4 phones, on the loopback, with looser limits than the steps because a headless frame is 17 ms) and A-4-5 (`net_rate`: the ball speeds up within 8 frames). What is not verified by anything now: the numbers of the real radio and a real TV box (RTT below 40 ms, Rx Hz 50 or more, Gap below 80 ms, Lost 0). The open failure of step 1a (issue #437, RTT at or above 40 ms in R7) and the wish to run on a real TV box (issue #386) have no manual test now: the Summary row says so.
- 2026-11-10 (R7): step 1a **Fail**; steps 2a, 3a and 4a Pass (1 phone). The owner first ticked Pass for 1a with the note "mostly below 40"; on 2026-11-10 (issue #437) the owner confirmed that some reading was at or above 40 ms (the values were not written down; the highest reading is unknown), so 1a is Fail (rule: the worst of the three readings counts). The TV of R7 was a desktop or an emulator, not a real TV box (like R0, issue #386): the Pass of 2a, 3a and 4a stays as reported but was measured on a desktop. Test 4 is still open: it needs a run on a real TV box (RISKS B6: game mode on, Ethernet or Wi-Fi written in the Run log), and issue #386 stays open. Steps 1b, 2b, 3b, 4b (4 phones) and 5 (the camera at 240 fps) were marked N/A by the owner ("remove step, i don't have 4 phones. try automating with load testing"; "either remove this step or automate, this is impossible to manually test") and are removed from this file. The 4 phone load is in A-4-1 (`net_rate`); the delay in frames is A-4-5 (`net_rate`). The delay of the real phone and TV with a camera is not measured by anything now: REQ-GM-12 (150 ms) stays Device.
- R0: **Fail**. RTT above 60 ms, Rx Hz above 55, Gap 150 to 380 ms, Lost 0. TV app on a desktop (not a TV box), phone on the same Wi-Fi: not yet representative of a real TV. The total delay (camera) was not tested.

## Test 6

### Treasure Maze

Needs: 1 to 2 phones, 1 TV, a protractor app, a child of about 5 to 8 years for step 7g. Covers: REQ-MZ-3 to 9, REQ-MZ-12, REQ-MZ-13, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-90 to 95.


**Steps**

5a. On one real phone, hold the phone tilted 15 degrees (use a protractor app) to the right during the countdown and keep it at the same angle for 5 seconds after GO. Check: the ball moves less than one ball width (36 px) in the 5 seconds after GO. The pad shows no **RECENTER** box (REQ-GM-37, issue #55).
7e. In each theme, stand 3 m from the TV. Check: a person reads aloud the names of the two pictures at each side of the maze from this list, with 0 errors in 6 pictures: Garden tree and rose bush, Castle torch and shield, Ice penguin and iceberg (REQ-MZ-13).
7f. Bring a ball to the chest. Check: the lid of the chest opens and the gold shows.
7g. Check with a child of 5 to 8 years. Say only: "Where do you need to go?" Check: the child points to the chest within 10 seconds of "GO", without help.
7i. On a Mac, in English and then in Hebrew, start the maze in a small window, then maximize the window (green button) and play to the chest. Check: the walls of the picture and the walls the ball bumps into are the same lines (the ball never goes into a wall, 0 times in 1 round), and the whole maze is inside the window with an equal margin at the left and the right (a photo of the screen). (REQ-MZ-15, issue #45)
8a. Roll the ball into a wall hard (a fast flick), 5 times, with the phone in your hand. Then roll it into a wall slowly, 5 times. Check: the phone buzzes shortly for each hard hit (5 of 5) and does not buzz for any slow touch (0 of 5). (REQ-MZ-6)

Items 1, 2a, 2b, 2c, 4b, 5b, 5c, 6a to 6h, 7a to 7d and 7h moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-6-1 to A-6-7). Item 3 was removed earlier. Items 5a and 7f keep only what a machine cannot show (a real phone; the drawn lid). The numbers of the other items do not change. The result menu has New game and returns to the view with the last choice (A-11-5), the rows of the result menu (A-11-1, A-11-2).

Measurements (no pass or fail; tune the constants if the owner asks): with the phone tilted 15 degrees the ball speeds up by about 670 px/s2 (`TILT_ACCEL` 2600, `FRICTION` 1.6, `MAX_SPEED` 760). The crossing time of the longest corridor of Easy, Medium and Hard is printed by `tests/smoke_maze.gd`.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 5a | Video of the ball: tilt held from the countdown, 5 s; photo of the pad | Pass | R4 |  | R3: Fail - 1. after recenter ball still drifts; 2. A and B does nothing. R4: Pass |
| 7e | Note: the 6 names read aloud | Pass | R3 |  | R3: Pass - THEME should start from Garden which should be first in the options Same result as old item 7. |
| 7f | Photo of the open chest | Pass | R3 |  | R3: Pass - THEME should start from Garden which should be first in the options Same result as old item 7. |
| 7g | Note: time in seconds until the child points to the chest | Pass | R3 |  | R3: Pass - THEME should start from Garden which should be first in the options Same result as old item 7. |
| 7i | Photo of the maximized window; the number of times the ball went into a wall | Pass | R7 |  | R7: Pass |
| 8a | Note: buzzes in 5 hard hits; buzzes in 5 slow touches | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |

History:

- 2026-11-10 (recorded; R7 in the tracker): Pass: steps 7i, 8a.
- 2026-10-25 (N/A): step 4a (2 and 4 phones on a real Wi-Fi) was removed: the tester has one phone. The one-phone-moves-only-its-own-ball part is automated (A-6-4b); Rx Hz, Gap and Lost with 4 phones on a real network stay in Test 4.
- 2026-10-20 (not run): the steps were made measurable and split (items 2, 4 to 7 got letters; item 3 is removed; 2b, 6h limits and 7e to 7h are checks with numbers). Feel notes moved to Measurements.
- 2026-10-20 (automated): 20 steps moved to the automated tests. Items 1, 2a and 2c had a Pass in R1 (the owner's chat report); the machine now checks the same rules, and the results stay in the result database. The torch flames of the Castle theme are built (REQ-MZ-14) and tested. Hebrew wording of the title (old 7h) is a string review in the pull request.
- 2026-10-10 (not run): item 7 is new: the maze world is a pixel world (phase 4 of the arcade style), walls 12 px, Hard cells 76 px.
- 2026-10-09 (not run): item 6 is new (REQ-MZ-9, REQ-GM-90 to 97): the settings view, the three difficulties, the yellow chosen value, Back and Start on one line, and Start dimmed when no phone fits.
- R1: items 1 to 3 **Pass** (the owner: 'it works perfectly'). Items 4 and 5 are not run: 2 to 4 phones, and RECENTER with A and B.
- R0: **Retest**. First run: drift and inverted controls (caused by 'Invert axes' being on). After the fix the maze looks good on the desk. The feel and the constants were not judged. Item 5 is new (RECENTER, and A and B do nothing).

## Test 7

### Disconnect and reconnect

Needs: 2 phones, 1 TV, a stopwatch, a third phone to call (for item 7). Covers: REQ-GM-30, REQ-GM-30a, REQ-T5, REQ-N5, REQ-N6, REQ-FL-25, REQ-FL-52, REQ-FL-52a, REQ-FL-52c, REQ-FL-55, REQ-GM-31a, REQ-MR-14, REQ-MZ-8.

Join approval (issue #393, phase 4): the TV setting "APPROVE NEW PLAYERS" is ON by default, so each phone that joins in this test waits for the host. Before the first join either turn the setting OFF (Settings, first row, press Left) or press OK on ALLOW on the TV card each time a phone joins (the focus is on ALLOW; REQ-FL-93, 94).

Time limit used below: the TV pauses when a phone is silent for 3 seconds (`Protocol.PEER_TIMEOUT_MS`, issue #56), so "at once" means 3.6 seconds at most (REQ-GM-30), measured from the moment you switch the Wi-Fi off. With one phone, the card then says "NO PLAYERS CONNECTED" and offers only **End game** (REQ-GM-30a, issue #46); when the phone is back, the card says "1P RECONNECTED" with **Resume**.

**Steps**

2. On the Games screen, lock the phone screen for 10 seconds, then unlock. Check: within 10 seconds the phone shows its waiting screen again with the same slot number, and the TV slot was "READY" all the time or came back to "READY". (Android can stop the app in the background.)
3a. On the Games screen (not in a game), switch the phone Wi-Fi off for 45 seconds. Check: after 45 seconds the TV shows the slot of the phone as empty (it is empty 5 seconds after the phone was lost, REQ-FL-8).
3b. Switch the Wi-Fi on. Check: within 10 seconds the phone joins again by itself (the TV does not know it any more, so it takes a new slot, maybe a different one) and shows "CHOOSE A GAME ON THE TV". No question is asked. (Issue #52: the PIN pad is gone.)
3c. (Removed with the join PIN, issue #52. The phone joins again by itself in 3b.)
6a. On the phone pad (in a game), tap **HOLD TO DISCONNECT** (the box at the bottom edge) quickly 5 times. Check: the phone is still on the pad (no leave). (REQ-FL-52a, issue #239)
6b. On the phone pad, press **HOLD TO DISCONNECT** and keep the finger on it. Check: the box is at the bottom edge, with a gap of at least 48 px at the left and right and 32 px at the bottom, none of its four corners is cut by the round corner of the phone (yes or no), and it shows the whole text HOLD TO DISCONNECT (also in Hebrew; changed 2026-11-03; the English text changed on 2026-11-10, issue #435: it was HOLD TO LEAVE); the box fills from left to right and the phone shows the Connect screen 0.8 to 1.2 seconds after the press. A Hebrew reader checks the text (`pad.disconnect_hold`). The tester also says what the box does: it disconnects the phone from the TV (yes or no). (REQ-FL-52a, issue #239)
6c. Swing the phone in Tennis or Bowling for 20 swings with the thumb near the bottom edge (changed 2026-11-02: HOLD TO DISCONNECT is at the bottom; it was at the top right). Check: the phone does not leave the TV (yes or no). (issue #239)
7a. With one phone in a game, call that phone from another phone and answer. Check: within 4 seconds of the answer (3 s of silence plus 1 s) the game pauses with the card "NO PLAYERS CONNECTED" (one phone, issue #46).
7b. End the call and go back to the controller app. Check: the phone says "RECONNECTING..." and then joins again in 10 seconds or less (stopwatch from the return to the app).
7c. Check: the card says "1P reconnected" with **Resume**, and **Resume** goes on with the game.
7d. Do a call that lasts 70 seconds (the slot is kept 5 minutes while the game is paused). Check: after the call the phone joins again in the same slot.
8a. **The TV closes (2026-10-29, issue #169).** With one phone joined and on the Games screen, press Back on the TV remote until the TV app quits. Check: within 3 seconds the phone leaves the waiting screen and shows the Connect screen or "RECONNECTING..." (yes or no). (REQ-GM-30)
8b. Join again, then kill the TV app (swipe it away in the recent apps, or unplug the box). Check: within 5 seconds the phone shows "RECONNECTING..." and not the waiting screen with the game name (yes or no). (REQ-GM-30)
6f. **Pause button (2026-11-10, issue #435).** Start a game with one phone and look at the top right of the pad. Check: a square button with a white frame and two white bars (a pause symbol) is at the right end of the header row, about 1 cm from the right edge, and no letter of the player name is covered by it (yes or no for each of the two). Repeat with a profile whose name is 10 letters of the widest kind (for example WWWWWWWWWW) and an avatar: the name goes on a second line and none of its letters is under the button (yes or no).
6g. In the game, tap the pause button once. Check: within 1 second the TV pauses the game and shows the question "END THE GAME?" with RESUME first and in focus (yes or no), and the phone still shows the pad. Press OK on the TV: the game goes on.
6h. In the game, press the Android Back key on the phone once (a swipe from the edge on a phone with gestures). Check: the TV shows the same question "END THE GAME?" as in 6g, and the phone does not show "QUIT SABABI APP?" (yes or no for each of the two). Press Back on the phone twice more, with a pause of 2 seconds: the question stays and no "QUIT SABABI APP?" shows.
6i. While the question "END THE GAME?" shows on the TV, tap the pause button 5 times. Check: the question stays as it is and the game stays paused (yes or no). Then, on the menu of the TV (Games screen), look at the pad: the pause button shows only while a game plays (yes or no: no button on the waiting screen).
9a. **Lost link on the pad (2026-10-30, issue #238).** Start a game with one phone, then switch the phone Wi-Fi off. Check: within 4 seconds the phone vibrates once for about 0.7 s and the pad shows a thin yellow frame around the whole screen, the A and B buttons dimmed and RECONNECTING... in yellow in the middle (changed 2026-11-10, owner, issue #433: it was a frame of red and white dashes; yes or no for each of the four). (REQ-FL-52b)
9b. Look at the phone for the yellow frame with a color-blindness filter on (or in gray scale). Check: the frame, the dimmed buttons and the words RECONNECTING... are still visible (yes or no for each of the three; changed 2026-11-10, owner, issue #433: it was the ring of dashes).
9c. With the HAPTICS switch OFF repeat 9a. Check: the phone does not vibrate; the frame still shows.
9d. Join with a profile whose name is 10 letters of the widest kind (for example WWWWWWWWWW) and an avatar. Check: all letters of the name show in the header and none is cut at the right edge of the screen (yes or no; changed 2026-11-02: the leave box is at the bottom).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 2 | Note: the seconds the phone needs to show its waiting screen, the slot number before and after | Pass | R4 |  |  |
| 3a | Photo of the Games screen after 45 s (slot empty) | Pass | R4 |  |  |
| 3b | Photo of the phone after the join, with the seconds | Pass | R4 |  |  |
| 3c | (Removed with the join PIN) | N/A | | | Owner decision 2026-11-01: the step was removed with the join PIN (issue #52); the join by itself is step 3b. |
| 6a | Video of 5 quick taps on the pad | Not run | | | Changed 2026-10-30 (issue #239). R4 passed the old one-tap step. |
| 6b | Video of the hold: the fill and the seconds to the Connect screen | Not run | | | R7: Pass was for the text HOLD TO LEAVE; the text changed to HOLD TO DISCONNECT on 2026-11-10 (issue #435, owner), so the step is not run again yet. R7 note: question: should "hold to leave" leave the game or disconnect from the TV? Added 2026-10-30 (issue #239). |
| 6c | Video of 20 swings | Pass | R7 |  | R7: Pass Added 2026-10-30 (issue #239). |
| 6f | Photo of the pad with the pause button, also with a 10 letter name | Not run | | | New 2026-11-10 (issue #435). |
| 6g | Video of a tap on the pause button and the question on the TV | Not run | | | New 2026-11-10 (issue #435). |
| 6h | Video of Back on the phone in a game | Not run | | | New 2026-11-10 (issue #435). |
| 6i | Video of 5 taps while the question shows | Not run | | | New 2026-11-10 (issue #435). |
| 7a | Video of a phone call: the card, with the seconds | Pass | R4 |  |  |
| 7b | Video of the return: 'RECONNECTING...', the join, the seconds | Pass | R4 |  |  |
| 7c | Video: the card 'reconnected', Resume, the game goes on | Pass | R4 |  |  |
| 7d | Video of the 70 s call and the return, same slot | Pass | R4 |  |  |
| 8a | Video of the phone when the TV app quits | Pass | R7 |  | R7: Pass Added 2026-10-29 (issue #169). |
| 8b | Video of the phone when the TV app is killed | Pass | R7 |  | R7: Pass Added 2026-10-29 (issue #169). |
| 9a | Video of the Wi-Fi cut: the buzz (sound or feel), the frame, the dimmed buttons, the time | Not run | | | R7: Pass was for the old frame of red and white dashes; the look changed on 2026-11-10 (issue #433), so the step is not run again yet. Added 2026-10-30 (issue #238). |
| 9b | Photo in gray scale | Not run | | | R7: Pass was for the old dashed frame (the owner said: very alarming and not friendly, issue #433); the frame is now thin and yellow with dimmed buttons (owner, 2026-11-10), so the step is not run again yet. Added 2026-10-30 (issue #238). |
| 9c | Video with HAPTICS OFF | Pass | R7 |  | R7: Pass Added 2026-10-30 (issue #238). |
| 9d | Photo of the header | Pass | R7 |  | R7: Pass Added 2026-10-30 (issue #238). |

Items 1b (merged into 1a), 1c, 1e, 4c, 5e and 6b to 6e moved to the automated tests (docs/AUTOMATED_TESTS.md, A-7-1, A-7-4, A-7-5, A-7-6). Items 1d, 4a and 5a to 5d moved too (A-7-7), and item 1a moved too: the TV half is A-7-7 and the phone half (it shows RECONNECTING when the TV is silent) is A-7-8, a check of `join_flow` that fails until issue #61 is fixed (Alon decided on 2026-10-21 to keep this automatic). The numbers of the other items do not change.

Measurements (not steps): write the reconnect time after the call (7b) in the Notes of step 7b.

History:

- 2026-11-10 (issue #435, owner decision): the text of the box is HOLD TO DISCONNECT (it was HOLD TO LEAVE; Hebrew unchanged), the pad has a pause button at the top right and Back on the phone in a game asks the TV "End the game?" (REQ-FL-52c). Step 6b is Not run again (the R7 Pass was for the old text); new steps 6f to 6i are Not run. The step 6b of Test 8 changed too.
- 2026-11-10 (recorded; R7 in the tracker): Pass: steps 6b, 6c, 8a, 8b, 9a, 9b, 9c, 9d. Step 6b: the owner asked "should HOLD TO LEAVE leave the game or disconnect from the TV?" (answer: it disconnects from the TV, REQ-FL-52a). Step 9b: the owner asked why the dashed frame is needed and called it alarming and not friendly: issue #433. Decided by the owner on 2026-11-10: a thin yellow frame (8 px), the A and B buttons dimmed, the header word and RECONNECTING... in yellow, the slot square keeps its color (no red); steps 9a and 9b changed and are Not run again (the R7 Pass was for the old look).
- 2026-11-01 (N/A): step 3c was removed with the join PIN (issue #52); the owner decided to mark it N/A. It was "Not run". The join by itself is step 3b.
- 2026-10-25 (N/A): step 4b was removed (the PIN question it mentions is gone since issue #52; the join by itself is step 3b).
- 2026-10-21 (automated): items 1d, 4a and 5a to 5d moved to the automated tests (`r1_reconnect`: a phone that goes silent, with the real timeouts). Item 1a was split: the card on the TV is automated (A-7-7), and the phone half is automated too (A-7-8, `join_flow`, failing until issue #61 is fixed); step 1a2 was removed. The R1 result of 1a2 (Retest: the phone showed 'Reconnecting...' but the seconds were not written down) stays in the result database. The R1 results of 1a, 1d (Fail) and 5a to 5d (Retest) were about the TV; they stay in the result database.
- 2026-10-21 (aligned with the requirements, not run): step 7a says 6 seconds (REQ-GM-30: 5 s of silence plus 1 s). No recorded result changed.
- R1: **Fail** (item 1) and **Retest** (item 5). A phone without Wi-Fi did not pause the game, and a phone call ended it with no way to resume. Both changed on 2026-10-09 and wait for the retest. Items 2, 3, 4 and 6 are not run.
- R0: **Retest**. Wi-Fi off on the phone: the phone shows 'Reconnecting...'. The game kept running and the TV never showed 'Waiting for P1 to reconnect'. Wi-Fi on: the phone reconnected and the game went on. The off time was not measured (the TV pauses only after 5 s of silence at that time, 3 s since issue #56). Item 6 (Leave twice, A green and B red) is new.

## Test 8

### TV remote

Needs: 1 phone, 1 TV with its remote, a stopwatch. Covers: REQ-GM-31, REQ-GM-31a, REQ-GM-33, REQ-FL-41, REQ-FL-52c, REQ-FL-55.


**Steps**

1a. Use only the remote. On each of these 7 screens press Up, Down, Left and Right once each: Connect, Games, Players modal, OPTIONS (Settings), the settings view of a game, the question "End the game?" (Back in a game) and the result menu. Check: on each screen the focus moves at least once, and OK selects the focused item (REQ-GM-33).
1d. Stand 3 m from the TV. A second person presses keys on the 7 screens of step 1a without saying where the focus is. Check: you name the focused item on 7 of 7 screens, also in Settings.
3a. On the Games screen press Back on the real remote. Check: the Connect screen shows, the app is still open 5 seconds later, and the player slots are still filled (same number of players).
3b. Press Back on the Connect screen. Check: the quit question opens with **Stay** in focus.
6a. On the phone, press the Android Back key on the Connect screen (before joining), then join and press it again on the waiting screen (the TV on the Games screen). Check: the question "QUIT SABABI APP?" opens, with no button in focus (no yellow frame), and the app is still open 5 seconds later (REQ-FL-86).
6b. Press the Android Back key on the phone in the middle of a game (the pad screen). Check: the question "QUIT SABABI APP?" does not open on the phone; the TV pauses the game and shows "END THE GAME?" (changed 2026-11-10, issue #435, REQ-FL-52c: it opened QUIT SABABI APP? on the phone). Press Back on the phone again after 2 seconds: the question stays on the TV. Then pause the game with a lost phone card (switch the phone Wi-Fi off and on, wait for the pad) and press Back on the pad: "QUIT SABABI APP?" opens, the app is still open 5 seconds later, and tapping **A** 5 times while it shows does nothing on the TV.
6d. Press Back, then choose **Quit**. Check: the app closes (REQ-FL-55).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Video of the 4 keys on each of the 7 screens | Pass | R3 |  |  |
| 1d | Note: 7 answers of the second person | Pass | R3 |  | Same result as old item 1. |
| 3a | Video of Back on the Games screen, with the slots visible | Pass | R3 | Chat report 2026-10-09 (no file) | R1: Back quits the app on every screen. The owner saw the app go back to the previous view for a moment before it closed. Same cause and fix as item 2. Retest. |
| 3b | Photo of the quit question | Pass | R3 | Chat report 2026-10-09 (no file) | Same result as old item 3. |
| 6a | Video of Back on the phone Connect screen and waiting screen, with the stopwatch | Pass | R5 |  | R5: Pass, no notes (issue #110: the Connect screen had no question; fixed). Before: R3: Pass - buttons should never be in focus in the mobile app, this needs to be fixed; R4: Fail - "QUIT SABABI APP?" question isn't shown The question and its answers are tested without a phone (`ui_states`); only the real Back key is open. Issue #110. |
| 6b | Video of Back on the pad in a game (the TV question) and of Back on the pad of a paused game (QUIT SABABI APP?), with 5 taps on A | Not run | | | R3: Pass was for the old step (Back opened QUIT SABABI APP? on the pad in a game); the behavior changed on 2026-11-10 (issue #435, REQ-FL-52c), so the step is not run again yet. R3: buttons should never be in focus in the mobile app, this needs to be fixed Same result as old item 6. |
| 6d | Video of Quit | Pass | R3 |  | R3: Pass - buttons should never be in focus in the mobile app, this needs to be fixed Same result as old item 6. |

Items 1b, 1c, 2a to 2f, 5a, 5b and 6c moved to the automated tests (docs/AUTOMATED_TESTS.md, A-8-1 to A-8-6; items 2c and 2f are A-8-2c). Items 5a and 5b (the home row of the TV) are now part of step 1a of Test 1. What stays here needs the real remote or the real Android Back key. Item 4 (the Menu key shows the debug overlay with the FPS) was removed on 2026-11-17 (see the History; the machine half is A-8-4). The numbers of the other items do not change.

History:

- 2026-11-17 (step removed): Owner decision of 2026-11-17 (issue #458: "remove every manual step that needs the debug overlay"). Step 4 (press the Menu key, or use the Debug overlay row of Settings, and read the header line "DEBUG" and the FPS) is removed; it had the result Pass in R3, which is removed with it. Covered by a machine: A-8-4 (`focus_walk`: the Menu key shows and hides the overlay, F3 shows it, the first line has DEBUG and a number before FPS). What is not verified by anything now: that the real Menu key of a real TV remote shows the overlay (RISKS D2: the Menu key does not exist on all remotes).
- 2026-10-25 (R5): step 6a passes on the Connect and waiting screens after the fix of issue #110. The owner gave no notes.
- 2026-10-25 (R4): step 6a failed: the Android Back key does not open the quit question (issue #110).
- 2026-10-21 (automated): items 2c and 2f moved to the automated tests (`r1_tv_screens`: Back in a game asks, the timer stays, End game leaves, Back on the result menu goes to the Games screen; `quit_on_go_back` is false). The R1 result of 2c and 2f (Fail) stays in the result database. Item 1a is partly automated (A-8-1a) and stays.
- 2026-10-20 (not run): the steps were split and the criteria made measurable (focus on 7 screens, timer values, 5 s). Items 2b to 2e change with issue #53 (done 2026-10-21: the pause menu has End game, which leaves at once), item 6a with issue #54 (done 2026-10-21: no focus on the phone; the screens are checked by A-8-7).
- R1: **Fail** (items 2 and 3). Back quits the app on every screen. Fixed on 2026-10-09 (REQ-FL-55). Items 1, 4 and 5 are not run.
- Item 2 changed before the first run (the 'End the game?' question).

## Test 8b

### The TV flow and the style

Needs: 1 to 2 phones, 1 TV, a stopwatch. Covers: REQ-FL-1 to 46, REQ-FL-56, 57, REQ-FL-81, FD-1 to 17, FD-23. Item 7 (a TV set to Hebrew) moved to Test 17 on 2026-10-10: FD-19 replaced REQ-FL-54, so the TV now offers Hebrew and no longer stays English.

Join approval (issue #393, phase 4): the TV setting "APPROVE NEW PLAYERS" is ON by default, so each phone that joins in this test waits for the host. Before the first join either turn the setting OFF (Settings, first row, press Left) or press OK on ALLOW on the TV card each time a phone joins (the focus is on ALLOW; REQ-FL-93, 94).


**Steps**

2b. Stand 3 m from the TV. Check: you read aloud the title and the player range of 3 tiles, with 0 errors (REQ-FL-40).
3b. Press **Remove** on a player. Check: the phone shows "THE HOST REMOVED YOU. SCAN THE CODE TO JOIN AGAIN." and it is still on its Connect screen 30 seconds later (it does not reconnect by itself).
5b. Look at a test screen: a black background, a focused menu item, a modal frame and a tile frame. Check: you name the colors black, yellow, white with blue inside, and gray, 4 of 4 correct.
10e. On the phone, look at the waiting screen and the pad. Check: the avatar is beside the color square on both screens.

Items 1a, 1b, 1c, 2a, 3a, 3c, 4a, 4b, 4c, 6a, 6b, 8a, 8b, 8c, 9a, 9b, 10a, 10b, 10c, 10d, 10f and 10g moved to the automated tests (docs/AUTOMATED_TESTS.md, A-8b-1 to A-8b-10; the tiles of item 2a on a real TV are step 1c of Test 12). Item 5a (the overlay FPS of 55 or more on the TV box) was removed on 2026-11-17 (see the History). The numbers of the other items do not change.

Covered by machines (not repeated here): the buttons TRY AGAIN, NEW GAME and BACK TO MENU of the result menu (A-11-1) and the medals of a tie or a solo round (A-11-7).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 2b | Note: the 3 tiles read aloud with the errors counted | Pass | R3 | Chat report 2026-10-09 (no file) | Same result as old item 2 (split 2026-10-20). |
| 3b | Photo of the phone after Remove, and 30 s later | Pass | R3 |  | Same result as old item 3. |
| 5b | Photo of the test screen; note: the 4 color names | Pass | R3 |  | Same result as old item 5. |
| 10e | Photos of the phone header on both screens | Pass | R3 |  | Same result as old item 10. |

History:

- 2026-11-17 (step removed): Owner decision of 2026-11-17 (issue #458: "remove every manual step that needs the debug overlay"). Step 5a (the overlay FPS of 55 or more during the logo, the blinking prompts and the screen changes on the TV box, REQ-FL-44) is removed; it had the result Pass in R3, which is removed with it. Covered by machines: A-8b-5a (`design_tokens`: the style uses no shader, REQ-FL-44, new on 2026-11-17; `frame_cost`: the logic of one frame with 4 phones on Hard is under 8 ms, the logo and the menus are not in it). What is not verified by anything now: the frame rate of the logo, the prompts and the screen changes on a real TV box (REQ-FL-44 on a real device, like REQ-GM-50 since 2026-11-10).
- 2026-10-25 (N/A): steps 11a, 11b and 11c were removed (the tester has one phone). The logic of IN and OUT with 3 and 4 simulated phones is automated (A-8b-11); the look of the view with 2 real phones is no longer checked on a device.
- 2026-10-21 (automated): items 1a, 1c, 2a, 3a, 4b, 4c, 9a, 9b, 10c, 10d, 10f and 10g moved to the automated tests (`r1_tv_screens`, `hud_layout`, `results_medals`, `games_focus`). The R1 result of 2a (Fail: no screenshots on the Android 10 TV) stays in the result database; the check on the real TV is Test 12 step 1c. Item 5b stays: its text and the code differ (tile frame color).
- 2026-10-21 (aligned with the requirements, not run): step 5b names gray for the tile frame (REQ-FL-13, 38). No recorded result changed.
- 2026-10-20 (not run): the steps were split and the criteria made measurable (times, key counts, color names, 55 FPS). Item 3a and 4a change with issue #52, 2a with issue #57.
- R1: **Fail** (items 2 and 7). The tile screenshots are missing, and the layout is mirrored on a TV set to Hebrew. Both changed on 2026-10-09 and wait for the retest. The other items are not run.

## Test 9

### Car Race

Needs: 1 to 2 phones (2 for steps 11a and 14c), 1 TV, a phone camera, a child of about 5 to 8 years for step 13h. Covers: REQ-MR-*, REQ-GM-37, REQ-GM-47i to 47n.

Needs 1 to 2 phones for the manual steps (one phone is a time trial; the game takes up to 4 players). Requirements: `docs/games/marble_race.md`. Start "Car Race" and pick a track.


**Steps**

1c. Stand 3 m from the TV. Check: you read aloud the title and the timer with 0 errors.
11a. After a change to the shared game code (the countdown clock, the buzz cool-down, the end with no players), run this test again with 2 real phones on each track. Check: no phone buzzes in "3, 2, 1" and each phone buzzes once at "GO" (A-multi_phone covers the simulated phones only).
13b. Play one race in each theme. Check: the three obstacles match the theme: candy lollipops, gumdrops and cupcakes; space asteroids, satellites and craters; jungle logs, boulders and tiki masks. You name all 3 kinds in each theme with 0 errors from a photo. (The lists of obstacles are checked by A-9-13b.) (REQ-MR-46)
13e. Check: the scenery beside the road matches the theme (REQ-MR-57: candy lollipops, canes, ice creams, donuts, cookies; space rockets, planets, UFOs, stars; jungle palms, bushes, flowers, mushrooms) and 0 pieces cover the road or a car in the photo.
13h. Check with a child of 5 to 8 years. Ask: "Show me your car." Check: the child points to its own car within 10 seconds of "GO", without help. Ask: "Show me one thing you can hit." Check: the child points to an obstacle within 10 seconds.
14a. Drive two cars into each other, 5 times. Check: the cars bounce away from each other in 5 of 5 hits. Let one car finish and wait at the finish. Drive another car through the place of the car that finished, 3 times. Check: it drives through it without a bounce (3 of 3). (REQ-MR-7)
14c. Race with 2 phones in your hands. Check: both phones buzz at GO (2 of 2); a hit at full speed buzzes the phones of both cars (5 of 5 hits); a soft touch slower than 3 m/s buzzes none (0 of 5); crossing the finish line buzzes the phone of that car (2 of 2 cars). With your eyes closed, name the longer buzz of a pair of one hit and one finish. Check: you name the finish buzz (120 ms against 20 ms) right in 2 of 2 pairs. (REQ-MR-13)
14d. Race on Track 1, Track 5 and Track 10. Check: the name of the track shows on the screen during the race and equals the name in the settings view (3 of 3 tracks), and the tester reads it from 3 m without error. (REQ-MR-35)
14e. Take a screenshot of the TV during a race (the Android TV screenshot or a photo straight at the screen) on 3 tracks. Check: the black bar at the top is 112 px high (108 px to 116 px) and holds the title, the timer and the leader chip (3 of 3 items); the left edge of the timer box is at x 520 in English and its right edge at x 1400 in Hebrew (each within 8 px); at the start the first straight of the track runs up from the cars (3 of 3 tracks), and after a bend of the road the view has not turned: the wall pieces of the first straight stay upright in the photo (3 of 3 tracks). (REQ-MR-40)
14g. In each of the 3 themes, from 3 m, a tester points at the 4 cars and at the 3 kinds of obstacle on the road. Check: 7 of 7 right for each of 3 testers in each theme. (REQ-MR-43)
14h. Zoom a photo of the TV to 300% on the edge of the road, on a wall and on the finish line. Check: all 3 places are made of square steps with no blended pixel (3 of 3). Count the rows of the finish line. Check: 2 rows of black and white cells, each cell 16 px wide at 1080p (14 px to 18 px). Look at the ground. Check: a chess board that repeats. (REQ-MR-44)
14i. In each theme, from 3 m, a tester names the ground, the road and the walls. Check: Candy: pink chess ground with sprinkles, cream road with pink dashes, candy cane walls; Space: starry sky, metal road of panels, glowing cyan walls; Jungle: dark green ground with grass, dirt road with specks, leafy hedges (9 of 9 named right by each of 3 testers). An obstacle is 48 px or more high (12 world pixels) in a photo with a ruler (3 of 3 kinds). Start the same track twice. Check: the obstacles stand in the same places both times (3 of 3 tracks). (REQ-MR-46)

Items 1a, 1b, 1d, 2a, 2b, 3a, 3b, 5a, 5b, 7a, 7b, 8a, 8b, 9a to 9e, 11b, 11c, 12a to 12d, 13a, 13c, 13d, 13f and 13g moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-9-1 to A-9-13). Item 1c keeps the reading from 3 m, item 6 was removed (2026-10-25), item 13b keeps the naming of the pictures. Item 13e stays manual until the owner has decided which list of scenery is right (see the notes of this change); the geometry of the scenery (no piece on the road, no two pieces overlap) is checked by A-9-13e. Items 4 and 10 were removed earlier (10 is A-9-10). The numbers of the other items do not change. The result menu with Try again, New game and Back to menu is covered by A-11-1 and A-11-5.

Measurements (no pass or fail): note how the car feels at `ACCEL` and `DAMPING` and tell the owner if a constant needs a change. The winning times of the 69 races of `tests/race_bot.gd` are printed by that test.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1c | Photo of the screen edges; note: the 3 texts read aloud | Pass | R3 |  | Same result as old item 1. |
| 11a | Video of the countdown and GO with 2 phones on each track | Pass | R3 |  | R3: Pass - important note: RECENTER option should be available only for games in which the phone is used as a target pointer like "banana party". it shouldn't be available when playing other games. |
| 13b | Photo of each theme with the obstacles | Pass | R3 |  | Same result as old item 13. |
| 13e | Photo of the scenery of each theme | Pass | R3 |  | Same result as old item 13. |
| 13h | Note: the two times in seconds | Pass | R3 |  | Same result as old item 13. |
| 14a | Video; note: bounces (of 5); drive-throughs (of 3) | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |
| 14c | Note: the buzzes of each kind | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |
| 14d | Photos of 3 screens; note: reading errors | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |
| 14e | Screenshots; note: the bar height, the timer box edges, the 3 tracks | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |
| 14g | Note: the answers per theme; the numbers | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |
| 14h | Photos zoomed to 300%; note: the 3 places, the rows, the cell width | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |
| 14i | Note: the answers; photo with the ruler; the 3 tracks | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |

History:
- 2026-11-10 (REQ-GM-50 dropped): Owner decision of 2026-11-10 (issue #440, the owner answered: remove the FPS steps on the TV box; the owner has 1 Android phone and no TV box). This test has no FPS step now (Test 9 step 6 and Test 10 step 7c were removed on 2026-10-25); REQ-GM-50 is dropped from the Covers line, and the old frame-rate notes in the text and in the Measurements table are removed. The cost of a frame with 4 phones stays automated (`frame_cost`, issue #132); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device).

- 2026-11-10 (recorded; R7 in the tracker): Pass: steps 14a, 14c, 14d, 14e, 14g, 14h, 14i. Steps 14b and 14f (4 phones) were marked N/A by the owner ("remove step, i don't have 4 phones. try automating.") and are removed. 14b: the one leader chip in the bar and the 4 result rows are A-9-14b (`layout_menus`) and A-11-3, A-11-3a, A-11-3b; 14f: the leader in view, the arrows with the meters and the middle of the pack are the new A-9-14f (REQ-MR-41, 42).
- 2026-10-25 (N/A): step 6 (4 phones, Hard track, 3 themes) was removed (the tester has one phone). The frame rate with 4 phones is still a step in other tests; the track and theme looks stay in the other steps.
- 2026-10-20 (not run): the steps were made measurable and split. Item 4 (feel) is removed. Items 8b and 9e are new checks (REQ-MR-8, REQ-MR-52). Item 11b changes with issue #55.
- 2026-10-20 (automated): 29 steps moved to the automated tests (see the note above the Results table). The limit of old item 11b is 20 px (decided by the owner; measured 7.6 px in the test). The Hebrew wording check of old item 13g is a string review in the pull request.
- 2026-10-09 (not run): the four hand-made tracks were replaced by generated tracks, and item 9 is new: the settings view with Difficulty and the track carousel (10 sketches and a '?', the middle one is chosen, yellow border), difficulty by the number of obstacles (Easy 2, Medium 6, Hard 10 for each 100 m). The results menu has Settings, not Choose track.
- 2026-10-10 (not run): item 12 is new: the 3D world is drawn in a 480x270 pixel view (phase 3 of the arcade style), and the cars have their slot number on them.
- -: **Not run**. Not run on a device yet. Item 11 is new: run it again after a change of the shared game code (PR 12 changed the countdown, the buzz limit and the end with no players).

## Test 10

### Banana Party (pointer)

Needs: 1 to 2 phones, 1 TV, a second phone with an angle app (or a paper protractor), and a child of about 5 to 8 years for steps 9a and 9b. Covers: REQ-SS-*, REQ-GM-47i to 47n, REQ-GM-80 to 84, 90 to 95, RISKS A4, REQ-GM-37.

Hold each phone like a remote control, pointing at the TV, from the sofa (about 3 m). This is the first game that uses the
gyroscope pointer, so this test also checks the pointer itself (the old Test 5 for drift was removed).
The game was "Target Shoot" until 2026-10-09: it was changed after the first try (see History).
Record every video at 30 frames per second or more. "Screen width" means the width of the TV picture. "Center" means the middle of the play area.

**Steps**

3a. On one real phone, hold the phone still toward the TV after "GO" for 40 seconds (stopwatch). Check: the cursor moves less than 5% of the screen width from its first place. (RISKS A4, REQ-GM-37. The drift of a simulated gyro with an offset is checked by A-10-3a.)
3b. Move the phone away from the TV and back, then tap **RECENTER**. Check: the cursor goes to the center, less than 5% of the screen width from it. (REQ-GM-37)
4c2. Hit one elephant, one orangutan and one monkey. Check: after each hit the elephant sprays water, the orangutan has hearts and the monkey has sparkles (3 of 3). (REQ-SS-7, 13. The closed happy eyes, the banana peel and the cheers of the gorilla, the sloth and the lemur are checked by A-10-4c. The points, the text and the effect of each kind are checked by A-10-4b.)
5a2. A second person, who did not play, stands 3 m from the TV while a round runs (60 seconds). You point at one animal at a time and ask "What animal is this?". Do this for all six animals: monkey, lemur, orangutan, sloth, gorilla, elephant (keep this list to yourself). Check: the second person says the right name for each of the 6 animals (6 of 6). Write down every wrong name. (This checks that the six animals can be told apart by looks only. REQ-SS-7, 12. The gold crown of the golden monkey king is checked by A-10-5a.)
9a. Let a child of about 5 to 8 years play 1 round, with a grown-up next to them. The grown-up reads the hint line once and says nothing more. Check: the child hits at least 1 animal within the 60 seconds, and nobody touches the phone for the child. Write down the age. (REQ-GM-80 to 84, REQ-SS-17)
9b. The child plays a second round. Check: the child plays both rounds to the end without asking to stop or crying, and answers "yes" when asked "again?" (yes or no). Write down the words of the child. (REQ-GM-80 to 84, REQ-SS-17)
11b. From the sofa (about 3 m), play a round. Check: the tester reads aloud the "+10" or "+25" over a hit animal and the score of the round end, without error. (REQ-SS-13, REQ-FL-40)
12a. Play a round with 2 phones, with the phone of A in your hand. Throw 5 times at an animal (a hit) and 5 times at the empty sky (a miss), and count the buzzes after each throw. Check: each throw gives a short buzz (10 of 10), each hit gives a second, longer buzz after it (5 of 5), and a miss gives no second buzz (0 of 5). All phones buzz at GO (2 of 2). At the end the phone of the winner buzzes about 400 ms, and the other phone does not (2 of 2). (REQ-SS-14)

Items 1a, 1b, 1c, 2a, 2b, 4a, 4b, 4d, 4e, 5b to 5e, 6a to 6c, 7a, 7b, 8a, 8b, 10a, 10b, 10c, 10d, 10e, 11a, 11c, 11d, 11e and 11f moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-10-1 to A-10-11). The numbers of the other items do not change. Step 4c2 holds the water, hearts and sparkles of old item 4b (the rest of 4c is A-10-4c). Step 5a2 holds the six names (the crown is A-10-5a). Whether a real phone buzzes (old item 4d) is Test 18; a real Wi-Fi loss (old item 8a) is A-7-8.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 3a | Photo at the start and at 40 s; the drift in % of the screen width | Pass | R3 |  | Now one real phone. The simulated gyro is in A-10-3a. |
| 3b | Video of RECENTER, the cursor in the middle | Pass | R3 |  |  |
| 4c2 | Video of the cheers of the elephant, the orangutan and the monkey | Pass | R7 |  | R7: Pass - the owner confirmed on 2026-11-10 (issue #436) that the orangutan showed hearts (REQ-SS-13); the words "the orangutan has sparkles" in the earlier note were copied from R4. The result (Pass, ticked by the owner) does not change. Before (R4): Retest - R4: Fail - elephant sprays water, the orangutan has sparkles and the monkey has sparkles Now holds the water, the hearts and the sparkles of old item 4b. Issue #111. |
| 5a2 | Photo of the animals; the six names that were given | Pass | R7 |  | R7: Pass. Before (R4): N/A - R4: N/A - don't understand what needs to be tested and verified (the step was written again in plainer words on 2026-11-10). The crown of old item 5d is A-10-5a. |
| 9a | The age of the child; short video (only with the permission of the parent) | Pass | R3 |  |  |
| 9b | The words of the child; yes or no for "again?" | Pass | R3 |  |  |
| 11b | Note: the texts that were read aloud | Pass | R3 |  | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-16 (jungle, REQ-SS-12). |
| 12a | Note: throw buzzes (of 10); hit buzzes (of 5); miss buzzes (of 5); GO and end buzzes | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |

Measurements (not a test; no pass or fail). Write these values in the Notes column of the steps above. They decide the first tuning values of the game.

| Value | Step | Result | Run | Notes |
|-------|------|--------|-----|-------|
| Drift after 40 s still (% of the screen width) | 3a | | | |

History:
- 2026-11-10 (REQ-GM-50 dropped): Owner decision of 2026-11-10 (issue #440, the owner answered: remove the FPS steps on the TV box; the owner has 1 Android phone and no TV box). This test has no FPS step now (Test 9 step 6 and Test 10 step 7c were removed on 2026-10-25); REQ-GM-50 is dropped from the Covers line, and the old frame-rate notes in the text and in the Measurements table are removed. The cost of a frame with 4 phones stays automated (`frame_cost`, issue #132); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device).

- 2026-11-10 (recorded; R7 in the tracker): Pass: steps 4c2, 5a2, 12a. Step 4c2: the tester ticked Pass but the note said "the orangutan has sparkles" (REQ-SS-13 says hearts and no sparkles). The owner answered on 2026-11-10 (issue #436): the orangutan showed hearts, and the note was a leftover of R4. The note is corrected; the result Pass does not change. Step 5a2: the tester wrote "don't understand what needs to be tested and verified": the step was written again in plainer words (same check, 6 of 6).
- 2026-10-25 (R4 notes): step 7c (4 phones) was removed (one phone only). Step 5a2 was written again in simpler words (a second person names the six animals; same check, 6 of 6). Step 4c2 failed: issue #111.
- 2026-10-21 (automated): item 10c moved to the automated tests (`auto_banana_b`: the most animals with 1 phone, 5, 4 and 3). Item 4c was split (the closed eyes and three cheers are automated, 4c2 keeps the water, hearts and sparkles) and item 5a was split (the crown is automated, 5a2 keeps the six names).
- 2026-10-20: the steps were rewritten with a measurable Check and split with letters (1a to 11f). Each new step keeps the result of the old step with the same number. Step 8a follows the 3 s rule of REQ-GM-30 (the owner asked for 2 to 3 seconds, built as 3 s in issue #56).
- 2026-10-20 (automated): 29 steps moved to the automated tests. Items 6a, 6b and 6c had the result Retest (R2, the last digit of a score above 3 digits was cut): the machine now checks a score of 1 to 6 digits and a name of 10 letters in the chip (`game_helpers`, `hud_layout`), and the results stay in the result database. The first golden monkey comes 10 to 18 s after GO (the owner's decision; it waits for a free lane). The measurement rows of the removed steps (animal times, medal tiers, pointer range, Wi-Fi wait) are removed.
- 2026-10-10 (not run): item 11 is new: the sky is a pixel world (phase 4 of the arcade style).
- 2026-10-16 (not run): Snowball Splat became **Banana Party** (first Banana Splat; "קרב" means fight in Hebrew, so the owner chose Party): bushes that hide animals (REQ-SS-26, 3, 5 or 8 by difficulty), a jungle at sunset, six animals that eat bananas in three depth lanes, a hit animation for each, plain ring pointers and the golden monkey king (100 points). Items 4, 5 and 11 changed (REQ-SS-7 to 13, 25). All values are first guesses.
- 2026-10-09 (not run): item 10 is new: the settings view and Easy, Medium and Hard for Snowball Splat (faster and fewer Puffs as it grows, medal tiers for each level, the title names the difficulty).
- R2: the owner played the new game and reported one problem: the last digit of a score above 3 digits was not visible in the chip at the top. Fixed on 2026-10-09. Nothing else was reported, so the other items stay not run.
- R1: **Fail**, then redesigned. The owner tried the first version ("Target Shoot", small fast targets, a lock after a miss, decoys) and said: "I don't think it's playable in its current definition." They asked for something like Duck Hunt with larger and slowly moving targets, no penalty for a miss, and a game that is also for kids, so not shooting but for example throwing snowballs at a made-up character. Changed on 2026-10-09: the game is now Snowball Splat (REQ-SS-*), and REQ-GM-80 to 84 are new for all games. Which steps failed was not reported. The whole test needs a run with the new game.

## Test 11

### Result menus (REQ-GM-72)

Needs: 1 to 2 phones, 1 TV, a camera for photos. Covers: REQ-GM-34, REQ-GM-40, REQ-GM-41, REQ-GM-72, REQ-GM-73, REQ-GM-73a, REQ-MZ-5, REQ-MR-31.

1 to 2 phones. Tests the ranked result menu (REQ-GM-72) that every game with scores uses. Here: the maze and the race. New. Added with the shared game code (PR 12).
"Screen edge" means the edge of the TV picture. The margin must be 60 px at 1080p, that is 3.1% of the screen width (REQ-GM-41). Measure it on the photo. Read from the sofa (about 3 m).

**Steps**

1a. Maze with 1 phone: finish the maze. Check: the tester reads aloud the title and the first row (name and score text) of the result menu from 3 m, without error. (The rows, the title and the buttons are checked by `docs/AUTOMATED_TESTS.md`, A-11-1.)
1b. Look at the same result menu. Check: the tester points to the avatar picture and to the square in the slot color next to the name (2 of 2 found). (REQ-GM-72. The color of the square and the medal of one player are checked by A-11-1b.)
2b. Maze with 2 phones: let one ball reach the exit first and leave the other behind. Look at the result menu from 3 m. Check: the tester reads aloud the winner row and the row "NOT FINISHED" without error. (The gold medal of the winner, REQ-GM-73a, and the buttons are checked by A-11-2b.)

Items 2a and 3c moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-11-2a, A-11-3c). Items 4, 5, 6, 7 moved earlier (A-11-4 to A-11-7). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the result menu (1 phone) from the sofa; the text that was read | Pass | R7 |  | R7: Pass |
| 1b | Photo of the first row: avatar, square | Pass | R7 |  | R7: Pass |
| 2b | Photo of the result menu with 'not finished' rows; the text that was read | Pass | R7 |  | R7: Pass |

History:

- 2026-11-17 (reworded; owner decision of 2026-11-17, issue #457: no step needs more than 2 phones): step 2b said "2 to 4 phones" and "the others"; it says 2 phones and "the other" now. What is checked does not change (the winner row and the row NOT FINISHED, read from 3 m), so the R7 Pass stays. The step needed 2 phones at most, so it stays. The Needs line says 1 to 2 phones.
- 2026-11-10 (recorded; R7 in the tracker): Pass: steps 1a, 1b, 2b. Steps 3a and 3b (4 phones) were marked N/A by the owner ("remove step, i don't have 4 phones. try automating.") and are removed: the race results with 4 rows, the 3 buttons and the 60 px edge are A-11-3, A-11-3a and A-11-3b (`layout_menus`).
- 2026-10-20: the steps were rewritten with a measurable Check and split with letters (1a to 3c).
- 2026-10-20 (automated): item 2a (the same edge check as 3a, on the maze; the layout is tested for both) and item 3c (the colors and the order of the medals) moved to the automated tests. In 1b and 2b only what a person must see is left. REQ-GM-73a (the medal of the place with more than one player) is checked by `results_medals`.
- -: **Not run**. New.

## Test 12

### Game tiles and the toy box look (REQ-GM-49)

Needs: 1 TV (phones for the game photos), a camera for photos. Covers: REQ-GM-49, REQ-FL-20, REQ-FL-40, REQ-GM-41.

Phones are needed only for the photos of the running games. Needs the TV and the Games screen. New. This is the visual check that the `review` skill asks for with a screenshot of the game next to the Games screen.
A tile has a 16:9 picture. The colors and the objects of each tile file (the ground, the 4 player colors, the main objects) are checked by the test `tiles` (A-12-3 to A-12-10); the steps below keep only what the test does not see. The tile shows only the world of the game, with no HUD, title bar, leader chip, score, time, hint or menu text (issue #57 fixed: `tools/make_tiles.gd` draws without the HUD; the test `pixel_render` checks the top rows).

**Steps**

1c. Open the Games screen on the TV (the Android build, not the computer). Look at every tile. Check: each of the 15 tiles shows its screenshot, a title and a player range (for example "1-4 PLAYERS"): 15 of 15. (REQ-FL-13. The tile files, their import, the export presets and the player range are checked by A-12-1c.)
1e. From the sofa (about 3 m), look at the Games screen. Check: the tester reads aloud the title and the player range of 3 tiles and the description of the focused game, without error. (REQ-FL-40)
1f. From the sofa (about 3 m), open the Games screen with the first row in view. Check: a yellow arrow that points down blinks under the grid, and no arrow points up (issue #220, REQ-FL-12a). Then press Down until the last row is in view. Check: the arrow that points up blinks and the one that points down is gone.
1g. From the sofa (about 3 m), in English and in Hebrew, find the focused tile. Check: the tester points at the focused tile within 2 seconds, and says which of the title and the player range is bigger (the title: 40 px against 32 px, a 12 px yellow frame; issue #225, REQ-FL-13).
2. For each game, compare its tile with a photo of the game running. Check: the tile has the same background color and the same main objects as the photo (the objects are listed in A-12-3 to A-12-10 and in the steps below).
3b. Check the tile of **Car Race**. Check: the road in the tile turns in a bend (as in Track 1, Hard), with a post beside it. (The 4 cars, the candy ground, the road and the outline of the posts are checked by A-12-3b.)
4. Check the tile of **Banana Party**. Check: an animal was just hit (its peel shows) and a banana is in the air. (The jungle, the four cursor rings, the banana and the black outline of an animal are checked by A-12-4. The tile has no score and no "+10" text.)
4b. Check the tiles of **Air Hockey** and **Paint Grab** (remade 2026-10-29, issue #123). Check: Air Hockey has a black floor and dark gray rails around the white table; Paint Grab shows no stars under a black bar. (REQ-GM-49)
5. Check the tile of **Paint Grab**. Check: the hidden picture shows in the floor. (The floor, the bonus pot and the four blobs are checked by A-12-5.)
8. Check the tile of **Bowling**. Check: the 10 pins stand in a triangle and the ball is between the foul line and the pins. (The lane and the white shapes are checked by A-12-8; the test counts 138 white blobs and does not count the 10 pins.)
9. Check the tile of **Tennis**. Check: the ball is high over the near half of the court. (The grass, the court, the ball and the players are checked by A-12-9.)
10. Check the tile of **Mini Golf**. Check: the course is seen from above, three balls wait on the tee and a ball is between the tee and the hole (remade 2026-11-03). (The fairway, the lake, the windmill and the players are checked by A-12-10.)
11. Open the settings view of each of the 15 games. From the sofa (about 3 m), read the how-to-play text aloud. Check: the tester reads the text of each game without error and without a cut or hidden line (15 of 15), and Back and Start are fully on the screen (15 of 15). (REQ-GM-103, issue #77)

Items 1a, 1b, 1d, 3a, 6 and 7 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-12-1a, A-12-1b, A-12-1d, A-12-3a, A-12-6, A-12-7). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1c | Photo of the Games screen on the TV; the number of tiles with all 3 parts | Retest | R3 |  | R3: Pass, counted 13 tiles (13 games then). Reset to Retest on 2026-11-01: the step counts 15 games. Count 15 at the next run. Now on the TV only. |
| 1e | Photo from the sofa; the texts that were read | Pass | R3 |  |  |
| 1f | Photo of the Games screen with the first row and with the last row in view; the arrows seen | Pass | R7 |  | R7: Pass Row added 2026-10-31 (issue #303); step added for issue #220. |
| 1g | Photos from the sofa in English and in Hebrew; the seconds until the tester points at the tile | Pass | R7 |  | R7: Pass Row added 2026-10-31 (issue #303); step added for issue #225. |
| 2 | Photos: tile next to the game, for each game | Pass | R4 |  |  |
| 3b | Photo of the Car Race tile and of the running game | Pass | R4 |  | Same result as old item 3. Car Race and Maze tiles remade 2026-10-09 (4 cars on a bend with posts; 4 balls on the way to the exit). |
| 4 | Photo of the tile and of the running game | Pass | R7 |  | R7: Pass Before (R3): Retest - R3: Fail - the tile shows 5 cursor rings instead of 4 Banana Party tile remade 2026-10-16 (a jungle, 4 players, a hit, a banana in the air). Issue #114. |
| 4b | Photo of the two tiles and of the running games | Pass | R7 |  | R7: Pass Added 2026-10-29 (issue #123). |
| 5 | Photo of the tile and of the running game | Pass | R4 |  | Paint Grab tile remade 2026-10-16. |
| 8 | Photo of the Bowling tile next to a photo of the game | Pass | R7 |  | R7: Pass Before (R4): Retest - R4: Fail - in the tile show the bawling tracks without the score board but fill the tile. currently there's a gray area in the bottom which doesn't look good Issue #112. |
| 9 | Photo of the Tennis tile next to a photo of the game | Pass | R4 |  |  |
| 10 | Photo of the Mini Golf tile next to a photo of the game | Not run |  |  | The tile was remade on 2026-11-03 (view from above, a golfer and one white ball). The R4 Pass was for the old tile and no longer counts: retest. |
| 11 | Photos of the 15 settings views from the sofa; the number read without error | Retest | R4 |  | R4: Pass, counted 13 settings views (13 games then). Reset to Retest on 2026-11-01: the step counts 15 games. Count 15 at the next run. |

History:

- 2026-11-10 (recorded; R7 in the tracker): Pass: steps 1f, 1g, 4, 4b, 8.
- 2026-11-01: steps 1c and 11 count 15 games (they said 13; the registry has 15). The old Pass results of 1c (R3) and 11 (R4) counted 13 games; the owner decided to reset both to Retest (2026-11-01). The old results and run IDs stay in their Notes.
- 2026-10-25 (R4): step 8 failed: the Bowling tile has a gray area at the bottom and shows the score board; the owner wants lanes only, filling the tile (issue #112, docs/games/bowling.md marked Planned).
- 2026-10-20: the steps were rewritten with a measurable Check (list of objects in the tile, text read aloud from 3 m) and step 1 and step 3 were split with letters. The sentence "the Games screen and the games look like one toy box" was removed: it has no measure. The owner's run R1 is kept in the result database (step 1 passed, steps 2 to 10 failed because the tiles show the wrapper; planned: issue #57, REQ-GM-49).
- 2026-10-20 (automated): steps 1a, 1b, 1d, 3a, 6 and 7 moved to the automated tests. In steps 3b, 4, 5, 8, 9 and 10 only the composition that the test does not see is left. Open: a title that is wider than its tile (`focus_walk`, known bug) and the missing screenshots on the TV (step 1c on the device).
- -: **Not run**. New.

## Test 13

### Controller on an iPhone

Needs: 1 iPhone, 1 Mac with Xcode, 1 TV, a stopwatch. Covers: `tools/deploy-ios.sh`, RISKS A2, REQ-FL-58, 59, 68, 83, 84. New. Nothing in the iOS path has run yet.

Join approval (issue #393, phase 4): the TV setting "APPROVE NEW PLAYERS" is ON by default, so each phone that joins in this test waits for the host. Before the first join either turn the setting OFF (Settings, first row, press Left) or press OK on ALLOW on the TV card each time a phone joins (the focus is on ALLOW; REQ-FL-93, 94).
Write the model of the iPhone (for example "iPhone 15 Pro, with Dynamic Island") in the Run log.

**Steps**

1a. Follow `docs/EXPORT.md`, section *Controller on an iPhone*, and run `IOS_TEAM_ID=<team id> tools/deploy-ios.sh`. Check: the export, the build, the install and the launch end, and `echo $?` after the script prints 0. If it fails, save the last 50 lines of the log.
1b. Look at the iPhone. Check: the app opens in portrait, and the home screen icon is named **Sababi: Remote**.
2b. Start the app for the first time after the install, type the room code of the TV and tap **JOIN**. Check: the iPhone asks for the Local Network permission once; allow it, and the phone joins within 10 seconds. Close the app, start it again and join again by the code: no second question. (The app connects to the TV address, so iOS asks.)
2c. Look at the Connect screen. Check: it has the field for the room code and the JOIN button, and no paste button, no list of rooms and no Refresh button. It has a scan button only when the build has the scanner plugin (Test 33); a build without the plugin has none. (REQ-FL-58, changed 2026-11-01)
2d. Type the room code of the TV in lower case with a space after the second letter, and tap **JOIN**, with the stopwatch. Check: the phone shows the waiting screen with the square of slot 1 less than 5 seconds after the tap, and the TV shows the player in slot 1. (REQ-FL-83)
4a. Play Treasure Maze for 2 minutes (stopwatch) with the screen on and no touch on the screen. Check: no "lost connection" card on the TV and the iPhone screen does not lock.
4b. In the same game, tilt the phone left, right, top up and top down. Check: the ball rolls to the side that is lowered, in all 4 directions.
5a. In a game, lock the iPhone. Check: the TV shows the lost-phone card ("NO PLAYERS CONNECTED" for the only phone) within 10 seconds. (Like A-7-7.)
5b. Unlock the phone after 10 seconds. Check: the phone returns by itself, the card on the TV changes to a card with the button "Resume", and "Resume" restarts the game. (Like A-7-7 and A-7-8.)
5c. Outside a game (on the Games screen), lock the iPhone for 40 seconds and unlock it. Check: within 10 seconds the phone joins again by itself and shows "CHOOSE A GAME ON THE TV". (Like Test 7, item 3b.)
6b. Open the player edit screen with the keyboard open, and Settings, upright. Take a photo of each. Check: the same as 6a. (REQ-FL-68)
6d. Turn the phone to the side and open the screens of 6a and 6b again. Check: the same as 6a for every screen. (REQ-FL-68)
7. **Dynamic Island (moved from Test 19 step 3d on 2026-11-17, owner decision).** On an iPhone with a Dynamic Island, take a photo of the pad in a game. Check: the colored square, the player number and the HOLD TO DISCONNECT box at the bottom are fully visible, and A and B are fully on the screen (REQ-FL-68; the Android half is Test 19 step 3d).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Terminal log of the deploy with the exit code | Not run | | | |
| 1b | Photo of the app and of the home screen icon | Not run | | | |
| 2b | Photo of the permission question; note on the second start; seconds until the join | Not run | | | |
| 2c | Photo of the Connect screen of the iPhone | Not run | | | |
| 2d | Photo of the TV with the player joined; seconds from the tap | Not run | | | |
| 4a | Short video; the time | Not run | | | |
| 4b | Short video of the ball in 4 directions | Not run | | | |
| 5a | Photo of the TV card; the time in seconds | Not run | | | |
| 5b | Photo of the TV card and of the phone after unlock | Not run | | | |
| 5c | Photo of the phone after the unlock, with the seconds | Not run | | | |
| 6b | Photos of the three screens, upright | Not run | | | |
| 6d | Photos of the screens turned to the side | Not run | | | |
| 7 | Photo of the pad on an iPhone with a Dynamic Island | Not run | | | Moved from Test 19 step 3d on 2026-11-17 (owner). The Android camera cut-out stays in Test 19. |

Step 6c was part of step 6a. Steps 2a, 2e and 6a moved to the automated tests (docs/AUTOMATED_TESTS.md, A-13-2, A-13-6a). The parts of steps 1b, 2b and 4a that a machine reads (the preset, the usage texts, the screen-on setting) are in the automated tests (A-13-1 to A-13-6). Items 3a to 3d (the debug overlay: the values of `Accel` and `Gyro` of the iPhone) were removed on 2026-11-17 (see the History); the real sign of the iPhone sensor is checked by step 4b (the ball rolls to the side that is lowered), and `run_tests` checks that the code flips the iPhone sensor like Android (A-3-1). Step 7 is new (moved from Test 19). The numbers of the other items do not change.

History:

- 2026-11-17 (steps removed and one added; owner decisions of 2026-11-17, issues #458 and the answer on Test 19 step 3d): steps 3a (Accel z flat), 3b (Accel x for the right and left side down), 3c (Accel y for the top up and down) and 3d (Gyro z in a turn) are removed: each one read the debug overlay. None had a result (Not run). Step 4b (the ball rolls to the side that is lowered, in 4 directions) stays and checks the iPhone sensor signs through the game. Covered by machines: A-3-1 (`run_tests`: the iPhone accelerometer is flipped like Android) and A-3-2 (the direction of a tilt in the games). What is not verified by anything now: the real values of the iPhone accelerometer and gyroscope (flat z between +9.3 and +10.3; the code comment in `sensor_sampler.gd` and `docs/EXPORT.md` still say that Manual test 13 item 3 measures the sign: step 4b does it through the ball now). New step 7: the iPhone half of Test 19 step 3d (the pad under a Dynamic Island). Test 13 is for the next release (issue #415). Test 21 step 6a (an iPhone joins by the typed room code) is the same as step 2d here and was removed from Test 21.
- 2026-10-21 (automated): steps 2a, 2e and 6a moved to the automated tests (`run_tests`, `ui_states_a`). Step 3a stays (the real iPhone sensor sign). Steps 6b and 6d stay.
- 2026-10-20: the steps were rewritten with a measurable Check and split with letters (1a to 6d). Steps 2b to 2d, 5b and 5c were changed on 2026-10-21 by issue #52 (a typed room code instead of the list and the PIN; no Refresh).
- -: **Not run**. New.

## Test 14

### Paint Grab (tilt)

Needs: 1 phone, 1 TV, a stopwatch, and a child of about 5 to 8 years for step 7. Covers: REQ-PG-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

Hold each phone flat like a tray. New game (2026-10-09). The blob feel (`TiltBody`: acceleration, damping, speed limit, bounce) and the
difficulty values are first guesses. "Full tilt" means the phone is tilted about 45 degrees. Record videos at 30 frames per second or more.

**Steps**

7a. Let a child of about 5 to 8 years play 1 round, with a grown-up next to them. The grown-up reads the hint line once and says nothing more. Check: the child paints at least 10 tiles in the first 30 seconds, and nobody touches the phone for the child. Write down the age. (REQ-PG-9, REQ-GM-80 to 84)
7b. The child plays a second round. Check: the child plays both rounds to the end without asking to stop or crying, also when a tile is painted over, and answers "yes" when asked "again?" (yes or no). (REQ-PG-9, REQ-GM-80 to 84)
11a. **Pictures (2026-10-16, REQ-PG-22).** Play 5 rounds in a row. After 10 seconds of each round (the floor is still mostly empty), take a photo. Check: a second person who has the list of the 30 names (`SHAPES` in `paint_picture.gd`) names the picture correctly in at least 4 of the 5 rounds, and the 5 pictures are not all the same.
11b. At the end of the same rounds (the time is up, or the picture is painted), take a photo. Check: the same second person names the same picture in at least 4 of the 5 rounds. (REQ-PG-22)
11g. Let the child of step 7 play 2 rounds with pots, without a hint about pots. Check: the child rolls over at least 1 pot within 10 seconds after it landed, and no picture makes the child upset (the child does not cover the eyes, cry or ask to stop). (REQ-PG-9, 22, 23)
11h. **Paintable tiles (2026-10-27, REQ-PG-24, issue #130).** At the start of 5 rounds (nothing painted), from 3 m, ask a tester: "Where can you paint?". Check: the tester points at the lighter tiles (the picture) and not at the dark blocks in 5 of 5 rounds, and the ghost of the picture is faded (the lighter tiles are not brighter than the player colors).
12. **The black bar (2026-10-29, issue #123, REQ-GM-45a).** Start a round and look at the top of the screen from 3 m. Check: the bar is black from the left edge to the right edge of the TV (yes or no), and no star of the picture or bonus pot shows inside the bar (yes or no). (REQ-GM-45a)
13a. Tilt the phone 15 degrees to one side and hold it for 5 s; record the TV with the phone camera (60 fps or more). Then lay the phone flat and still. Check: the blob stops within 2 s after the phone is flat (3 of 3 tries), with the phone flat and still for 10 s the blob moves less than one blob width, and the blob stays on the floor at each of the 4 edges (4 of 4 edges). (REQ-PG-7)
13a2. (Added 2026-11-06, owner feedback.) Tilt the phone 120 degrees to one side (past upright) and hold it for 3 s, then lay it flat and still. Check: during the 3 s the blob keeps rolling to the side of the tilt (it never turns back, 3 of 3 tries), and within 2 s after the phone is flat the blob stops and stays within one blob width for 10 s (3 of 3 tries). (REQ-PG-7)
13e. Paint 10 tiles while a second person watches the TV from 3 m. Check: the second person sees each tile pop (a short step wider, about 0.15 s) when it is painted, 10 of 10. Tilt the phone to the left and then to the right, 5 times each. Check: the pupils of the blob step to the side it rolls in 10 of 10 moves. (REQ-PG-16)
13f. Start a round and use a stopwatch. Check: the first pot lands 7 s to 9 s after the start; the next pots land 9 s to 15 s after the one before (3 of 3 gaps in the limit); there is never more than one pot on the floor (checked at 5 moments); a pot that nobody takes goes away 8 s to 10 s after it landed and blinks in its last 2 s (2 of 2 pots). (REQ-PG-23)
13g. Roll a blob over a gold pot and over a rainbow roller (play more rounds until you have seen both). Check: before it is taken, a frame shows the tiles that it will paint; when it is taken the whole patch (3 x 3 tiles for the gold pot, the whole row for the roller) turns to the color of the blob, also tiles of other players (2 of 2 pots); the tiles pop for about 0.4 s; the phone of the blob buzzes (40 ms) and the sound plays (2 of 2 pots). (REQ-PG-23)

Items 1, 2, 9 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-14-1, A-14-2, A-14-9). Items 3a to 3c, 4a, 4c, 5a to 5c, 6a to 6c, 10a, 10c and 11c to 11f moved there too (A-14-3, A-14-4, A-14-5, A-14-6, A-14-10, A-14-11). Item 10b was split: the machine checks the rule (A-14-10), and the part that needs a person is now 10d. Item 4b was split earlier into the rule (A-14-4) and 4c; both are automated now. The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 7a | The age of the child; the number of tiles painted in 30 s | Pass | R6 |  | R6: Pass |
| 7b | The words of the child; yes or no for "again?" | Pass | R6 |  | R6: Pass |
| 11a | Photos at 10 s of 5 rounds; the names that were given | Pass | R6 |  | R6: Pass Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |
| 11b | Photos at the end of 5 rounds; the names that were given | Pass | R6 |  | R6: Pass - (Run on the text of 2026-10-27 ("the floor is full"); the step now says "the time is up, or the picture is painted".) Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |
| 11g | Note: the child, the time to the first pot, what happened | Pass | R6 |  | R6: Pass Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |
| 11h | Note: the answers of the tester in 5 rounds | Pass | R8 |  | R8: Pass Added 2026-10-27 (issue #130). The faded values (0.22 to 0.34) are first guesses. |
| 12 | Photo of the top of the screen | Pass | R8 |  | R8: Pass Added 2026-10-29 (issue #123). The shell draws the bar over the floor. |
| 13a | Video; note: stop times (3), movement in 10 s, edges (of 4) | Pass | R8 |  | R8: Pass Added 2026-10-31 (issue #306). |
| 13a2 | Video; note: tries where the blob turned back (of 3), stop times (3) | Pass | R8 |  | R8: Pass Added 2026-11-06 (owner feedback: tilting too much messed up the movement later). |
| 13e | Video; note: pops seen (of 10), pupils right (of 10) | Pass | R8 |  | R8: Pass Added 2026-10-31 (issue #306). |
| 13f | Note: the times in seconds; the pots on the floor at 5 moments | Pass | R8 |  | R8: Pass Added 2026-10-31 (issue #306). |
| 13g | Photos before and after; note: the patch size, the buzz, the sound | Pass | R8 |  | R8: Pass Added 2026-10-31 (issue #306). |

Measurements (not a test; no pass or fail). Write these values in the Notes column of the steps above. They decide the first tuning values of the game.

| Value | Step | Result | Run | Notes |
|-------|------|--------|-----|-------|
| Which pictures were not recognized, and if one picture came twice in a row | 11a | | | |

History:

- 2026-11-17 (step removed): Owner decision of 2026-11-17 (issue #457: remove the steps that say that more than 2 phones are needed). Step 10d (the floor with 4 blobs from the sofa: a second person names the color of each blob, 4 of 4, and each blob has a black outline and no number) is removed; it had the result Pass in R6, which is removed with it. Covered by machines: A-14-10 (`auto_paint`: the 4 slot colors differ pairwise by a delta E of 25 or more; every slot color differs from an empty tile by 40 or more) and `palette_lint` (A-237-1: the 4 colors stay apart for the 3 kinds of color blindness); REQ-PG-8 (a blob shows no number) is named by `run_tests` and `auto_paint`. What is not verified by anything now: a person who names the 4 blob colors from 3 m and sees the black outline of a blob (REQ-PG-8, 15, REQ-GM-46 on a real TV). The Needs line says 1 phone.
- 2026-11-17 (recorded; R8 in the tracker): Pass: steps 11h, 12, 13a, 13a2, 13e, 13f, 13g.
- 2026-11-10 (steps removed): Owner request of 2026-11-10 (tracker and chat: "Tests 14, 23, 27, 28 and 31 still have steps that either need to be removed or automated"; the owner has 1 Android phone and no TV box). The FPS step on the TV box is removed: nobody can do it now. The cost of a frame with 4 phones on Hard stays automated (`frame_cost`, A-14-8); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device). Step 13b (4 phones) is the new A-14-13b (the GO buzz of every phone is `multi_phone`; 20 ms for a take on the phone of the taker only and at most 4 buzzes for 5 takes in 0.4 s are `auto_paint`; 400 ms for the winner only is `audio_events`). Step 13c (the pad of 3 phones has no RECENTER, A or B is A-14-9, `device_mocks`; a phone held tilted 15 degrees in the countdown moves the blob 0 px in 5 s, limit one blob width, is `auto_paint`) is A-14-13c. Step 13d (the gap between two tiles on a 1080p TV is 4 px: `auto_paint`; the purple blob against an empty tile: a delta E of 40 or more, `auto_paint`) is A-14-13d. What is not verified by anything now: a person who points at the star, the floor, a tile or a blob from 3 m (the look, REQ-PG-15), and the felt buzz of the 4 real phones (the motor is Test 18).
- 2026-11-10 (recorded; R6 in the tracker): Pass: steps 7a, 7b, 10d, 11a, 11b, 11g. R6: the N/A of step 8 (4 phones) is not recorded: the step is 1 phone on the TV box now, and the frame cost with 4 phones on Hard is A-14-8 (issue #132).
- 2026-10-21 (automated): items 4a and 4c moved to the automated tests (`auto_paint_b`: 5 free tiles are painted and counted on the phone; taking the tile of another player buzzes only the taker). The step 4c asked for a felt buzz; the machine counts the buzz message of the TV. The motor of a real phone is Test 18.
- 2026-10-20: the steps that a machine can check moved to the automated tests (A-14-3 to A-14-11). 4b and 10b were split into the automated part and 4c and 10d (each keeps the result of the old step). The measurement of the percent of the floor (old step 5c) was removed with the step.
- 2026-10-20: the steps were rewritten with a measurable Check and split with letters. The words "the blob and its number" of step 10 were removed: a blob has no number (REQ-GM-46). Each new step keeps the result of the old step with the same number.
- 2026-10-16 (not run): item 11 is new: a hidden picture under the floor (30 shapes, a new one each round) and bonus pots (gold 3 x 3, rainbow roller), REQ-PG-22 and 23.
- 2026-10-10 (not run): item 10 is new: the floor is a pixel world (phase 4 of the arcade style).
- -: **Not run**. New.

## Test 15

### Sumo Bumpers (tilt and A)

Needs: 2 phones, 1 TV, and a child of about 5 to 8 years for step 8. Covers: REQ-SB-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

Hold each phone flat like a tray. New game (2026-10-09). The movement (`TiltBody`), the bounce, the dash and the difficulty values are first guesses. "Full tilt" means the phone is tilted about 45 degrees. Record videos at 30 frames per second or more.

**Steps**

6b. Check the phone that fell. Check: the phone buzzes at the fall (yes or no). (REQ-SB-11)
8a. Let a child of about 5 to 8 years play 1 match, with a grown-up next to them. The grown-up reads the hint line once and says nothing more. Check: the child makes the bumper move in the first 10 seconds, and nobody touches the phone for the child. Write down the age. (REQ-SB-9, REQ-GM-80 to 84)
8b. Check the child during the match. Check: the child plays all 3 rounds to the end without asking to stop or crying, also after a fall, and answers "yes" when asked "again?" (yes or no). (REQ-SB-9, REQ-GM-80 to 84)
11e2. Zoom a photo of the TV to 300% on the edge of the island and on the edge of a cloud. Check: both edges are made of square steps, with no soft (blended) pixel at either edge (2 of 2). (REQ-GM-47i to 47n, REQ-SB-15. The view of 480 x 270 pixels, the whole scale and the nearest filter are checked by A-15-11e.)
11g. From 3 m, read the word "WHEE!" and the round banner. Check: the tester reads both aloud without error. (REQ-SB-15, REQ-FL-40)
12a. Look at the pad of a phone while the match runs. Check: the pad shows the green button A alone, in the middle of the row, and no button B and no RECENTER box (3 of 3). (REQ-GM-37a, issue #80)
13a. Play a match with 2 phones and hold both. Bump the two bumpers into each other at full speed, 5 times, and slowly (below 300 px/s: they need more than 6 s to cross the screen), 5 times. Check: every fast bump buzzes both phones (5 of 5), a slow touch buzzes none (0 of 5), the bumper that is hit moves away from the other (5 of 5) and nobody loses points for it (0 of 5 losses). (REQ-SB-8)

Items 2, 9 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-15-2, A-15-9). Items 1a, 1b, 3a to 3c, 4a, 4b, 5a, 5b, 6a, 6c and 7a to 7e moved there too (A-15-1, A-15-3, A-15-4, A-15-5, A-15-6, A-15-7). Items 11a, 11b and 11d were split: the machine checks the sizes, the colors, the fonts and the pixels (A-15-11); items 11c and 11f are automated too (A-15-11c, A-15-11f), and the part that needs a person is now 11e2 and 11g. The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 6b | Note: buzz felt, yes or no | Pass | R7 |  | R7: Pass |
| 8a | The age of the child; what the child did in 10 s | Pass | R7 |  | R7: Pass |
| 8b | The words of the child; yes or no for "again?" | Pass | R7 |  | R7: Pass |
| 11e2 | Zoomed photo of the island edge and of a cloud edge | Pass | R7 |  | R7: Pass |
| 11g | Note: the texts that were read; the TV (1080p or 4K) | Pass | R7 |  | R7: Pass |
| 12a | Photo of the pad during the match | Pass | R7 |  | R7: Pass |
| 13a | Video; note: fast bumps with 2 buzzes (of 5), slow touches with a buzz (of 5) | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |

Measurements (not a test; no pass or fail). Write these values in the Notes column of the steps above. They decide the first tuning values of the game.

| Value | Step | Result | Run | Notes |
|-------|------|--------|-----|-------|
| The TV (1080p or 4K) | 11g | | | |

History:
- 2026-11-10 (step removed): Owner decision of 2026-11-10 (issue #440, the owner answered: remove them; the owner has 1 Android phone and no TV box). The FPS step on the TV box (step 10) is removed: nobody can do it now. The step had the result Pass in R7 (the screenshot of the FPS with 2 phones on the TV box); that result is removed with the step. The cost of a frame with 4 phones on Hard stays automated (`frame_cost`, A-15-10, issue #132); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device). REQ-GM-50 is dropped from the Covers line of this test.

- 2026-11-10 (recorded; R7 in the tracker): Pass: steps 6b, 8a, 8b, 10 (step 10, the FPS on the TV box, was removed the same day, issue #440), 11e2, 11g, 12a, 13a. Step 13b (3 phones) was marked N/A by the owner ("remove step, i don't have 3 phones. try automating.") and is removed: the leader chip, TIE, the score of each phone and the pad with A only are the new A-15-13b (REQ-SB-14).
- 2026-11-01: step 10 says 2 phones (it said 1 phone, but the game needs 2 to 4 phones, `min_players` 2).
- 2026-10-21 (decision of the owner, REQ-GM-35): Sumo Bumpers has no timer, so it has no countdown. A round starts at once; step 11g lost the countdown digits (no result recorded, it was not run). No recorded result changed.
- 2026-10-21 (automated): items 4b, 11c and 11f moved to the automated tests (`auto_sumo_b`). Item 11e was split: the view size, the scale and the filter are automated, 11e2 keeps the photo of the edges. The suite fails on step 11c today: the slowest cloud moves under 4 % of the view in 10 s (REQ-SB-15 says 2 to 3 world pixels per second).
- 2026-10-20: the steps that a machine can check moved to the automated tests (A-15-1 to A-15-11). 11a, 11b and 11d were split into the automated part and 11e, 11f and 11g (each keeps the result of the old step). The three measurements of the old steps 5a, 7b and 7c were removed with the steps: the values are tested now (round length, wait after a fall, dash speed and time).
- 2026-10-20: the steps were rewritten with a measurable Check and split with letters. Each new step keeps the result of the old step with the same number.
- -: **Not run**. New. Item 11 was added on 2026-10-10 (phase 2 of the arcade style) and changed on 2026-10-15 for the Sky Island and the penguins.

## Test 16

### The arcade look (REQ-FL-37 to 46, FD-18)

Needs: 1 to 2 phones, 1 TV on 1080p (and a 4K TV if you have one), a child of 5 to 8 years for items 8a and 8b, a tape measure or a marked distance of 3 m, a stopwatch, a phone camera. Covers: REQ-FL-37 to 46, 41a, 52, 53, REQ-GM-45, 46. New, written on 2026-10-10 for phase 1 of `docs/ARCADE_STYLE_PLAN.md`. The games are in the pixel style too (phases 2 to 4 are built); this test checks the menus, the phone and the game shell (HUD, countdown, menus, hints). The headless suites `tests/screens_sweep.gd`, `tests/hud_layout.gd` and `tests/games_focus.gd` and the render suite `tests/pixel_render.gd` check the sizes, colors, rows, cursors and pixels; this test keeps what needs a real TV, a real phone or a person.

**Steps**

1b. On the Connect screen, the Games screen, a pause menu and a result menu, read aloud the smallest text of each screen (the hint, a slot row or a description) from 3 m. Check: you read each one without a mistake (0 mistakes). The smallest text is 32 px (REQ-FL-40).
1b2. New (issue #221; the info text is white since 2026-11-02, check it is still readable and still different from the dim disabled text). On the Connect screen and the Games screen, in a dim room, read aloud from 3 m the info lines ('1-4 PLAYERS' under three tiles, the hint lines, 'WAIT' and the empty slots), and look at the disabled things (a game that needs more phones). Check: you read all of them without a mistake (0 mistakes), and the info lines (light gray, #b0b0b0) are clearly lighter than a dimmed tile or a disabled item (dark gray, #7c7c7c): you name the 2 gray levels correctly in 3 of 3 tries. (REQ-FL-37, REQ-FL-40)
2c. On a 1080p TV, photograph the Logo screen and the Games screen from the sofa, with the phone camera at 1:1 crop. Check: a single-pixel black and white edge of a letter stays a single pixel in the photo, with no gray halo wider than 1 pixel of the photo (the TV's own scaler does not soften the picture).
2d. Do step 2c on a 4K TV, if you have one. Check: the same result. (Skip this step if you have no 4K TV and write "no 4K TV" in the notes.)
4d. On the real TV remote, in each menu of the Games screen, a game settings view and the quit question, press OK, Back and the D-pad once each. Check: OK does the action of the focused item, Back closes the menu or goes up one step, and the D-pad moves the focus (the same result as in Test 8).
6a. On a phone, go through the Connect, the waiting and the pad screens. Hold the phone at 50 cm and read aloud every text of each screen. Check: you read each text without a mistake.
6b2. Look at the phone pad from 50 cm. Check: A is green and B is red, each with a black letter and a white ring (2 of 2; changed 2026-11-03 by the owner: black with a white letter since 2026-11-02, white before, green and red before 2026-10-29), RECENTER is a small box (not full width) centered right above HOLD TO DISCONNECT, and the NEW BEST! text, when shown, is centered and larger than the slot number (yes or no), and the tester reads the slot number in the slot square at the top of the pad aloud, without a mistake. (The lift of the buttons, the independent press and the place of the square are checked by A-16-6b.)
6b3. Look at the Connect or waiting screen of a phone from 50 cm. Check: the icon buttons (JOIN, ABOUT, SETTINGS; DISCONNECT on the waiting screen) have a black face, white icon and a white border (all of them), and the tester says what each icon is without a mistake (changed 2026-11-06, owner: ABOUT, SETTINGS and DISCONNECT are icons with no word). (New 2026-10-29, issue #173; the colors changed 2026-11-02.)
6b4. Look at the TV Games screen from the sofa (3 m), with the focus on the OPTIONS icon button, then on the ABOUT icon button. Check: each has a black face with a white icon and a thick yellow border (changed 2026-11-02: no yellow fill; changed 2026-11-12: icon buttons), and the tester names the icon within 5 s. Do the same in Hebrew. (New 2026-10-29, issue #173.)
6b5. **A and B reach (2026-10-30, issue #240).** Use one phone with a screen of 6.7 inches or more (the one that is held in the right hand), in a game that uses both A and B (for example Star Shield). Hold it in one hand, the way you hold it to play, and without moving the hand, reach A and then B with the thumb, 10 times each. Measure the height of the middle of A above the bottom edge of the screen with a ruler (the code puts it 330 px above the bottom, about 2.6 cm on a 6.7-inch phone). Check: the thumb reaches A and B without moving the hand in 10 of 10 tries each (yes or no), and write the height in cm and the phone model. Repeat with the left hand: 10 of 10 tries each (yes or no).
8a. A child of 5 to 8 years sits at the TV with the Games screen open. Ask: "Which game is chosen now?". Check: the child points to the focused tile (the one with the cursor) within 10 s and without help.
8b. Show the child the screen with PRESS OK TO CONTINUE. Ask the child to continue. Check: the child presses OK within 10 s and without help.

Items 1a, 2a, 2b (split into 2c and 2d), 3a, 3b, 3c, 3d, 3e, 4a, 4b, 4c, 5a, 5b, 5c, 6c, 6d, 6e, 7a, 7b moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-16-1 to A-16-7). Item 6b was split: the geometry is automated and 6b2 keeps the colors, the ring and the number in the square (6e is part of 6b2). The numbers of the other items do not change.

Measurements: write down the lowest FPS value of step 5d and the text sizes you saw in step 1b. Do not turn them into a pass or fail.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b | List of the screens and the smallest text read without a mistake (yes or no) | Pass | R4 |  |  |
| 1b2 | Note: the info lines read without a mistake (yes or no); the 2 gray levels named in 3 of 3 tries | Pass | R7 |  | R7: Pass Before: Open - New 2026-10-30, issue #221 |
| 2c | Close photo of the Logo screen and the Games screen on 1080p, 1:1 crop | Pass | R4 |  |  |
| 2d | Close photo of the Logo screen and the Games screen on 4K (or "no 4K TV") | Pass | R4 |  |  |
| 4d | Note: OK, Back and D-pad on each menu | Pass | R4 |  |  |
| 6a | Photos of the phone screens; the note "read without a mistake" | Pass | R4 |  |  |
| 6b2 | Photo of the pad; note: the slot number that was read | Open | R4 (Pass before the change of 2026-10-29, issue #173: A is green and B is red with a black letter since 2026-11-03; black with a white ring 2026-11-02, white before) |  |  |
| 6b3 | Photo of the phone screen; note: the two words that were read | Pass | R7 |  | R7: Pass Before: Open |
| 6b4 | Photo of the Games screen in English and in Hebrew; note: the seconds | Pass | R7 |  | R7: Pass Before: Open |
| 6b5 | Photo of the hand on the phone; note: the phone model, the height in cm, tries of 10 for A and B with the right and the left hand | Pass | R7 |  | R7: Pass Before: Open - Added 2026-10-30 (issue #240). |
| 8a | Note: the child, the age, the seconds | Pass | R4 |  |  |
| 8b | Note: the child, the age, the seconds | Pass | R4 |  |  |

History:

- 2026-11-10 (recorded; R7 in the tracker): Pass: steps 1b2, 6b3, 6b4, 6b5.
- 2026-10-25 (N/A): step 5d (the FPS overlay) was removed: the owner decided that the debug overlay is not tested.
- 2026-10-21 (automated): items 3e, 5a, 5b, 5c, 6c, 6d and 6e moved to the automated tests (`auto_r3_tv`, `auto_r3_phone`, `run_tests`). Item 6b was split into the geometry (automated) and 6b2 (the pixels: colors, ring, number). The pixel test of the pad (`a render check of the pad (not written yet)`) is not written.
- -: **Not run**. New.

## Test 17

### Hebrew and right to left (REQ-FL-54, 60 to 63, REQ-GM-47o, FD-19)

Needs: 2 phones (one with the system language Hebrew, one English), 1 TV (run it with the TV set to Hebrew, region Israel, and again set to English), a person who reads Hebrew, a stopwatch. Covers: REQ-FL-54, 60 to 63, REQ-GM-47o. Items 9b and 9c (issue #171, the phones keep their own language) are new on 2026-10-29. New, written on 2026-10-10 for phase 5 of `docs/ARCADE_STYLE_PLAN.md`. The headless tests `tests/smoke_lang.gd`, `tests/smoke_settings.gd`, `tests/screens_sweep.gd`, `tests/hud_layout.gd` and `tests/run_tests.gd` check the table, the layout positions, the fit of every text, the language choice and the protocol; they cannot check how the text looks on a TV or whether it reads right.

Join approval (issue #393, phase 4): the TV setting "APPROVE NEW PLAYERS" is ON by default, so each phone that joins in this test waits for the host. Before the first join either turn the setting OFF (Settings, first row, press Left) or press OK on ALLOW on the TV card each time a phone joins (the focus is on ALLOW; REQ-FL-93, 94).

**Steps**

2e. The person who reads Hebrew reads each TV screen aloud (Connect, Games, Settings, About, the quit question). Check: the punctuation (`. , ! ? -`) is at the correct end of every sentence. Write down every text that is wrong. (That a Hebrew text ends with the same punctuation as its English text is checked by `tests/smoke_lang.gd`.)
4c. On the TV, look at the Connect screen with the two names. The person who reads Hebrew reads the Latin name and the Hebrew name aloud. Check: each one equals what was typed (the letters are in the same order, the mixed-direction text is not shuffled). (That the names stay as typed and that the pixel font has every glyph is checked by `tests/smoke_lang.gd`.)
6c. In Car Race in Hebrew, check: the word after the 1 is complete (inside the screen): "צא" with one player, "צאו" with two or more players (owner decision on issue #113). In every game in Hebrew, check: the hint line shows complete.
6e2. Open the pause menu and the result menu in Hebrew. The Hebrew reader reads the ranking list, the medal text and the tie text aloud. Check: the reader says that each of the 3 reads right (3 of 3 yes).

9b. Set the TV to English and the system language of phone A to Hebrew. Join phone A, open the waiting screen, the Settings screen and start Car Race. Check: every text on phone A (waiting screen, Settings, pad, hint line, result card) is in Hebrew and the screen is mirrored (title at the right), while the TV stays in English and left to right; no text on the phone is cut off or outside the screen edge (6 of 6 screens). Then set the TV to Hebrew and the system language of phone B to English and repeat. Check: phone B stays in English and left to right.
9c. On phone A (Hebrew) open Settings and tap the arrow that is not dim in the LANGUAGE row once, then leave the app and start it again. Check: the row shows ENGLISH (the language switched to English at the tap), the phone is in English after the restart, and the TV language did not change.

9d. The person who reads Hebrew reads the buttons and the prompts changed by issue #230 (the rows in the pull request: JOIN, SCAN QR CODE, TRY AGAIN on the buttons; CHOOSE A GAME ON THE TV, SELECT GAME and HOLD ON TIGHT! on the prompts). Check: the reader says that each of the 6 reads right and natural for a child (6 of 6 yes).
9e. The person who reads Hebrew reads the 5 Hebrew texts whose end mark changed by issue #234 (the how-to texts of Mini Golf and Sheep Herding now end with a full stop; the hints of Tennis (serve, hit) and Sumo Bumpers now end with an exclamation mark). Check: the reader says that each of the 5 reads right (5 of 5 yes).

9f. On a phone set to Hebrew open Settings (waiting screen). The person who reads Hebrew reads the HAPTICS switch in both states (a tap on the row turns it) (issue #290: the name says "רטט" and the value "פועל" with the switch on and "כבוי" with it off). Check: the reader says that each of the 2 reads right (2 of 2 yes) and the name and the value fit inside the row.

9g. On an Android phone set to Hebrew open About. The person who reads Hebrew reads the entry "סורק QR", then (3rd Party Libraries) the entry and the heading of the page "ספריות אנדרואיד" (issue #292). Check: the reader says that each of the 3 reads right (3 of 3 yes), the heading shows Hebrew letters and no "?" mark, and each text fits inside its button.

9h. Join 2 phones without a profile (guests) to a TV set to Hebrew. The person who reads Hebrew reads the names in the Players list and on the HUD chips of a game (issue #307: "שחקן 1" and "שחקן 2"). Then set the TV to English in the menu. Check: the reader says that the 2 Hebrew names read right (2 of 2 yes), they fit their chips, and after the switch the names read "Player 1" and "Player 2".

Items 1a to 1d, 2a, 2b, 2c, 2d, 3a to 3c, 4a, 4b, 6a, 6d, 7a, 8a and 8b moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-17-1 to A-17-8). Item 5 moved earlier (A-17-5). Item 7b moved too (A-17-7b). Item 6e was split: that the text shows complete is automated, 6e2 keeps the reading. The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 2e | A list of the sentences with wrong punctuation | Pass | R4 |  |  |
| 4c | Photo of the Connect screen with the names; note from the Hebrew reader | Pass | R4 |  |  |
| 6c | Same photos and the countdown | Pass | R7 |  | R7: Pass Before (R4): Retest - R4: Fail - change the string to צא instead of קדימה Issue #113. Owner decision (issue #113, 2026-11-07): one player shows "צא", two or more show "צאו"; R7 ran it on the TV. |
| 6e2 | Photos of the pause and result menus; note from the Hebrew reader | Pass | R4 |  |  |
| 9b | Photos of phone and TV side by side, in both combinations | Pass | R7 |  | R7: Pass New 2026-10-29 (issue #171) |
| 9c | Photo of the Settings screen before and after the tap; photo after the restart | Pass | R7 |  | R7: Pass New 2026-10-29 (issue #171) |
| 9d | Note from the Hebrew reader | Pass | R7 |  | R7: Pass New 2026-10-30 (issue #230) |
| 9e | Note from the Hebrew reader | Pass | R7 |  | R7: Pass New 2026-10-30 (issue #234) |
| 9f | Note from the Hebrew reader | Pass | R7 |  | R7: Pass New 2026-10-31 (issue #290); Hebrew by Claude |
| 9g | Note from the Hebrew reader | Pass | R7 |  | R7: Pass New 2026-10-31 (issue #292); Hebrew by Claude |
| 9h | Note from the Hebrew reader | Pass | R7 |  | R7: Pass New 2026-10-31 (issue #307); Hebrew by Claude |

History:

- 2026-11-10 (recorded; R7 in the tracker): Pass: steps 6c, 9b, 9c, 9d, 9e, 9f, 9g, 9h.
- 2026-10-31 (issue #290): the haptics button of the phone Settings is the string row settings.haptics (it was English text in the code). New step 9f, not run. The automated half is the Hebrew check in `audio` (_phone_haptics).
- 2026-10-31 (issue #292): the About titles "QR scanner" and "Android libraries" are string rows (about.qr_scanner, about.android_libraries). New step 9g, not run. The automated half is `about_pages` (About titles in Hebrew).
- 2026-10-31 (issue #307): the name of a phone without a profile is the string row players.default_name (it was "Player N" in the code) and follows the TV language. New step 9h, not run. The automated half is `net_profiles`.
- 2026-10-29 (issue #171): the phones no longer follow the TV language (REQ-FL-62). New steps 9b and 9c, not run. The automated half is A-17-9.
- 2026-10-25 (R4): step 6c failed: the Hebrew of GO in Car Race should be "צא" (issue #113, a string change that waits for the owner's review). Step 6b (the HUD boxes in Hebrew with 2 phones) was removed: the tester has one phone; the box places are automated (`hud_layout`, REQ-GM-47o).
- 2026-10-21 (aligned with the requirements, not run): step 6b names the Car Race timer box at the left (English) and right (Hebrew) margin, and step 6c splits the countdown word (Car Race) from the hint line (every game). No recorded result changed.
- 2026-10-21 (automated): items 2a, 2b, 4a and 7a moved to the automated tests (`screens_sweep`, `auto_r3_tv`, `auto_r3_phone`). Item 6e was split (6e2 keeps the reading by the Hebrew reader). Steps 6b and 6c stay until Alon decides (the Car Race timer side in Hebrew; the Hebrew GO word that most games do not draw).
- -: **Not run**. New.

## Test 18

### Sound and haptics

Needs: 1 to 2 phones, 1 TV, a grown-up, a child of about 5 to 8 years for item 9, a phone with a sound level meter app (dB(A)), a camera at 60 fps or more for items 6b and 11a, a stopwatch for item 11b. Covers: REQ-FL-64 to 66, REQ-GM-49a to 49c, REQ-GM-43.

New (2026-10-10). The songs, the effects and the levels are first guesses (`scripts/audio/songs.gd`). The headless tests check the data (the notes, the levels in dB, the order of the sounds, the ducking, the haptics calls, the effect and the buzz of every event of the game tables), not how it sounds in the room. Items 1a to 1c, 2a to 2e, 3a to 3e, 4a, 4b, 5a to 5e, 6a, 6c, 7a to 7c, 8a to 8d, 10a, 10b, 10d, 10e and 10f moved to the automated tests (docs/AUTOMATED_TESTS.md, A-18-1 to A-18-10). Item 10c was split: the TV side is automated, 10c2 keeps the motor of a real phone. The numbers of the other items do not change. Put the phone with the meter app at the sofa seat and keep the TV volume the same for the whole test. A meter reading is the highest value in 5 s.

**Steps**

6b. Film the phone of the player and the TV with sound at 60 fps or more for 3 events. Check: the phone starts to buzz within 100 ms of the start of the sound (6 frames or fewer at 60 fps). The automated tests check this on the network only (A-18-6b), not the phone motor or the TV audio path.
9a. A child of about 5 to 8 years plays a game with sound for 3 rounds. Read the meter at the highest effect. Check: the reading is 85 dB(A) or lower, and the child does not cover its ears and does not ask for less sound.
10c2. Play Paint Grab (it has a countdown; Star Shield, Sumo Bumpers, Bowling, Mini Golf and Tennis with 2 to 4 players have none, REQ-GM-35) with Haptics ON on one real phone. Check: the phone vibrates at GO and at 2 events of the haptic table of that game (yes or no for each of the 3).
11a. Film a picture event and its sound on the TV box with a camera at 60 fps or more. Count the frames from the picture to the sound for 3 events. Check: the delay is 100 ms or less (6 frames at 60 fps) for each event.
11b. Start the app with the stopwatch. Check: the first song starts within 5 s (the same limit as the automated check A-18-1a, on the TV box).

Measurements: write down the meter reading of step 9a and the delay of steps 6b and 11a. The levels of the songs are tuned from these values.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 6b | Video; the frames between the buzz and the sound | Not run | | | |
| 9a | Note: the child, the age, the highest meter reading, what happened | Not run | | | |
| 10c2 | Note: the vibration at GO and at 2 events (yes or no each) | Not run |  |  |  |
| 11a | Video; the frames for 3 events; the delay in ms | Not run | | | |
| 11b | Value: seconds until the first song | Not run | | | |

History:

- 2026-10-21 (automated): items 3a, 3d, 6a, 10a and 10f moved to the automated tests (`audio`, `auto_r3_tv`, `audio_events`, `auto_r3_phone`). Item 10c was split (10c2 keeps the motor of a real phone). The Mute row was dropped on 2026-10-21 (issue #49); `audio` checks that it is gone and that the Language row changes with Left and Right.
- -: **Not run**. New.

## Test 19

### Leader chip and phone score (REQ-FL-67, REQ-GM-46, FD-21)

Needs: 2 phones (give them names of 10 letters, the most since FD-22), 1 TV on 1080p, a grown-up, a child of about 5 to 8 years for item 8, a person who reads Hebrew for item 9. Covers: REQ-FL-67, REQ-FL-68, REQ-GM-46, FD-21, issue #25.

New (2026-10-10). The HUD shows one chip, the leader, and not a chip for each player. Each phone shows its own place and score. The size of the header text on the phone is a first value. The headless test `tests/hud_layout.gd` checks the rectangles of the chip, the title and the timer, and that the countdown draws no name, in all games with 4 phones, in English and Hebrew; what stays here is the phone screen, the real TV and the people.

**Steps**

3c. (Reworded 2026-11-17, issue #455: it was "read the place and the score of the line"; run R8 failed it.) Play a game to its end with 2 phones, and in a second game with Treasure Maze or Car Race. When the result menu opens on the TV, hold each phone at 50 cm. Check, on each phone: (1) you read aloud the line of that player in the TV list (place, name and score or time) without a mistake, and it is the same text as that player's row on the TV, with no color square and no avatar next to it; (2) the line is in the middle of the screen (the middle of the line is within 1 cm of the middle of the height of the screen); (3) no button is visible (no A, no B, no RECENTER, no pause button, no HOLD TO DISCONNECT); (4) when the next game starts, the buttons are back at once. (A-455-1 checks the text, the middle and the buttons with a machine; this step is the check on a real phone.)
3d. On an Android phone with a camera cut-out, take a photo of the pad. Check: the colored square, the player number and the HOLD TO DISCONNECT box at the bottom are fully visible, and A and B are fully on the screen (REQ-FL-68; HOLD TO DISCONNECT (then HOLD TO LEAVE) moved from the top right on 2026-11-02).
3e. Turn the same phone to landscape and back. Check: nothing is hidden at the top, at the bottom (the home bar) or at the side.
8a. A child of 5 to 8 years plays a game. In the countdown, ask the child to point to its own object (the one in the color of its phone). Check: the child points to the right object within 10 s and without help.
8b. After one minute of play, ask the child to read aloud the number on its phone. Check: the child says the number that the phone shows.
8d. New (2026-10-30, issue #237; changed 2026-11-17: it was "the same as 8c", and 8c needed 4 phones and was removed). Car Race and Treasure Maze with 1 phone, the TV seen from 3 m. A tester who has red-green color blindness, when one is available (write "none available" otherwise), points in the countdown to the object in the color of the own phone. Check: the tester points to the right object within 5 s in both games.
9c. The person who reads Hebrew reads the header of a phone. Check: the place and the score are read without a mistake.

Items 1a to 1c, 2a to 2d, 3a, 3b, 3f, 4a to 4c, 5a to 5c, 6, 7a, 7b, 7c, 9a and 9b moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-19-1 to A-19-9). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 3c | Note: read without a mistake, yes or no | Fail | R8 |  | R8 (on the old wording of the step, before the fix of issue #455; not run on the new wording): Fail - the summary needs to be consistant across games on the phone. the phone should show, for each user, the same line that is shown in the summary on the tv just without the color and avatar. it should be shown in the center of the screen while all buttons shouldn't be visible anymore until game time. Issue #455. |
| 3d | Photo of the pad on an Android phone with a cut-out | Not run | | | The iPhone half (Dynamic Island) moved to Test 13 step 7 on 2026-11-17. |
| 3e | Photos of the phone in landscape | Pass | R8 |  | R8: Pass |
| 8a | Note: the child, the age, the seconds | Pass | R8 |  | R8: Pass |
| 8b | Note: the child, the age, the number | Pass | R8 |  | R8: Pass |
| 8d | Note: the tester, the type of color blindness, the seconds | Pass | R8 |  | R8: Pass, run on the old text ("same as 8c", which needed 4 phones); the step was reworded on 2026-11-17 to need 1 phone and the owner has not run the new text. Added 2026-10-30 (issue #237). |
| 9c | Photo of the Hebrew phone header; note from the Hebrew reader | Pass | R8 |  | R8: Pass |

History:

- 2026-11-17 (step removed, one reworded, one moved; owner decisions of 2026-11-17, issue #457 and the answer on step 3d): step 8c (4 phones, 4 testers, Car Race and Treasure Maze: each tester points to the object in the color of the own phone within 5 s; the result was Pass in R8, which is removed with it) is removed. Covered by machines: A-237-1 (`palette_lint`: the 4 slot colors stay apart for normal vision, protanopia, deuteranopia and tritanopia, REQ-GM-46c), A-6-7 (`smoke_maze`: the ball colors of the maze) and A-14-10 and A-22-12g (the 4 slot colors in the games). What is not verified by anything now: that 4 people find their own object by its color from 3 m on a real TV. Step 8d no longer refers to 8c and says 1 phone. Step 3d is Android only (the camera cut-out); its iPhone half (the Dynamic Island) is Test 13 step 7. The Needs line says 2 phones.
- 2026-11-17 (recorded; R8 in the tracker): Pass: steps 3e, 8a, 8b, 8c, 8d, 9c. Fail: step 3c. Step 3c Fail: issue #455 (the phone result line). Step 3d (N/A): the iPhone half moves to Test 13, the Android camera cut-out half stays.
- 2026-10-21 (automated): items 3a, 3b, 3f, 7a and 9a moved to the automated tests (`auto_r3_score`, `hud_layout`).
- 2026-10-21: the name tags of the countdown (REQ-GM-46a) were removed by decision of the owner (Alon). Item 7a (the object nearest to a tag) and the tag parts of items 7b and 7c are gone; the title of the test lost "name tags". No recorded result changed.
- -: **Not run**. New.

## Test 20

### Player profiles (REQ-FL-69 to 75, REQ-N8, REQ-C7 to C9, FD-22)

Needs: 2 to 4 phones (one an iPhone if possible), 1 TV on 1080p, a grown-up, a child of about 5 to 8 years for item 17d, a person who reads Hebrew for item 6e, a stopwatch. Covers: REQ-FL-69 to 79, REQ-GM-98 to 101, REQ-N8, REQ-C7 to C11, FD-22. Items 1 to 8 are phase A (names and avatars), items 9 to 11 are phase C (personal bests), items 12 to 15 are phase B (copy by QR), items 16 and 17 are the Connect screen and the HUD changes of 2026-10-11 (`docs/PROFILES_PLAN.md`, section 11.2).

Join approval (issue #393, phase 4): the TV setting "APPROVE NEW PLAYERS" is ON by default, so each phone that joins in this test waits for the host. Before the first join either turn the setting OFF (Settings, first row, press Left) or press OK on ALLOW on the TV card each time a phone joins (the focus is on ALLOW; REQ-FL-93, 94).

New (2026-10-10). The headless tests check the rules and the drawing. They do not show how an avatar looks from the sofa, or how the profile screens work in a hand.

**Steps**

1b2. Start a game. Start a game and make this phone the leader. From 3 m look at the leader chip. Check: the tester finds the avatar of the phone in the chip (1 of 1 found). (That the chip holds the square, the avatar and the name in this order is checked by A-20-1b.)
1b3. **New 2026-11-11 (owner).** Join one phone without a profile (a guest) and one phone with a profile to a TV, and start a game. Check: the guest has a grey silhouette with a question mark, the same everywhere: in the Players list beside its color square, on its chip in the game and in the result rows, and on its own phone in the header of the pad and on the waiting screen beside the number square; the other player has the avatar of its profile; the guest picture is not in the avatar picker of the edit screen (4 of 4 yes). (The test `profiles` checks that a guest is shown with the picture and a profile with its avatar; the look and the places are manual.)
6e. Show the card with a Hebrew name in the English sentence, and with an English name in the Hebrew sentence. The Hebrew reader reads both cards aloud. Check: for each of the 2 cards the reader says that the letters of the name are in the typed order and that the sentence is in the right order (2 of 2 yes).
9a. Play Banana Party, Paint Grab, Star Shield, Bowling (Rails Without; with Rails With there is no NEW BEST) and Car Race (a fixed track) with a profile on 2 phones. When the round is over, check: the phone of a player who scores shows NEW BEST! on the pad, centered, in yellow, with the name of the game above it, while the result is open, and does not show it on the waiting screen or after the TV is back at the menu.
12a. Share a profile to a second phone by QR: give the profile some personal bests first. On the first phone tap the pencil on the Connect screen and tap SHARE on the edit screen; on the second phone tap + and then IMPORT on the new player screen (changed 2026-11-02, owner: the list screen is gone). Check: the second phone goes to the Connect screen by itself, with the new player selected in the dropdown (same name and avatar), and the status line says PLAYER ADDED. (changed 2026-11-06, owner: the new player screen used to stay open).
12c2. Share a profile from 30 cm with the screen at full brightness. Check: the code shows within 2 s of the tap on SHARE, and PLAYER ADDED. shows 10 s or less after the start of the scan. (The size of the largest code and the time to make it are automated.)
12d. Repeat from 60 cm, and with the screen at low brightness (4 combinations). Check: PLAYER ADDED. shows within 20 s in each combination.
12e. New 2026-11-02 (owner). On the Connect screen open the dropdown, then tap + and then the pencil. Check: the dropdown has no PLAYERS button; the new player screen has IMPORT and no SHARE; the edit screen has SHARE and no IMPORT (3 of 3 yes).
14a. Removed on 2026-11-09 (owner): COPY CODE is gone from the Share screen (it is checked by `tests/ui_share.gd`).
14b. Removed on 2026-11-02 (owner): PASTE A CODE is gone. On the iPhone use IMPORT on the new player screen (step 12a). Check: the iPhone shows PLAYER ADDED. with the same name, avatar and bests as in step 12.
16b. Tap **+**. Tap the name field. Check: the keyboard opens and stays open. Tap outside the field: the keyboard closes.
16c2. On the new player screen drag the avatar line with one finger by about 3 cm. Check: the line follows the finger, and the first avatar in view changes by 1 or more. (The 32 avatars in one line, the arrows with 3 avatars for each tap and the picked avatar in view at open are automated.)
17c. In every game, check: no ball, marble, blob, bumper or cursor shows a number or an avatar, only its color.
17d. A child of 5 to 8 years plays a game. Check: in the countdown the child points to its own object (the one in the color of its phone) within 10 s and without help.

Items 5, 11 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-20-5 and A-20-11). Items 1a, 1c, 3b, 6b, 6c, 8b, 16a, 16d, 16e, 16f moved to the automated tests, and items 6a, 6d, 12c, 16c lost the part that a machine checks (`docs/AUTOMATED_TESTS.md`, A-20-1 to A-20-16). The remaining part of 6a is 6a2, of 6d is 6e, of 12c is 12c2, of 16c is 16c2. On 2026-10-21 items 2a, 2b, 3a, 4a, 4b, 6a2, 7a, 8a, 9b, 9c, 9d, 10, 12b, 13a to 13c, 15a to 15c, 16g, 16h, 17a and 17b moved too (A-20-1b to A-20-16g), and the machine half of 1b is A-20-1b (the rest is 1b2). Item 7b was removed on 2026-11-17 (see the History; the machine part is A-20-7b). Step 9a stays until Alon decides (the NEW BEST! line shows on the waiting screen and on the pad). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b2 | Photo of the leader chip; note: found, yes or no | Pass | R8 |  | R8: Pass |
| 1b3 | Photos of the Players list, a game chip and the pad of the guest | Not run |  |  | New 2026-11-11 (owner: a picture for guests). |
| 6e | Photo of the card in English and in Hebrew; note from the Hebrew reader | Pass | R8 |  | R8: Pass |
| 9a | Photo of NEW BEST! on a phone | Pass | R8 |  | R8: Pass |
| 12a | Video: the scan | Pass | R8 |  | R8: Pass |
| 12c2 | Value: seconds to show and to scan | Pass | R8 |  | R8: Pass |
| 12d | Values: seconds for the 4 combinations | Pass | R8 |  | R8: Pass |
| 12e | Note: the answers (3 of 3) | Pass | R8 |  | R8: Pass New 2026-11-02. |
| 14a | Removed 2026-11-09 | Removed | | | The COPY CODE button was removed (owner). |
| 14b | Photo of the iPhone screen | Not run | | | |
| 16b | Video of the keyboard | Pass | R8 |  | R8: Pass |
| 16c2 | Video of the drag on the avatar line | Pass | R8 |  | R8: Pass |
| 17c | Photos of the objects in each game | Pass | R8 |  | R8: Pass |
| 17d | Note: the child, the age, the seconds | Pass | R9 |  | R9: Pass |

History:

- 2026-11-17 (owner, issue #457): step 7b (a child of 5 to 8 years points to its own avatar among 4 on the TV) was removed: it needed 4 phones, and a manual step never needs more than 2 phones. Its recorded result stays: Pass in R8 (2026-11-16). What a machine can check is A-20-7b (`r4_tv_profiles`): with 4 simulated phones that each sent a name and an avatar, every slot row of the Players list and of the Connect screen shows the avatar of its phone, the 4 pictures differ in their sheet cells, each row control is 64 px (16 px x 4), in English and in Hebrew. Nothing verifies any more that a child of 5 to 8 years finds its own avatar among 4 on a real TV within 10 s and without help.
- 2026-11-17 (recorded; R8 and R9 in the tracker): Pass: steps 1b2, 6e, 7b, 9a, 12a, 12c2, 12d, 12e, 16b, 16c2, 17c, 17d. Step 17d was run on 2026-11-17 (R9), the others on 2026-11-16 (R8).
- 2026-10-21: the name tags of the countdown were removed (decision of the owner, Alon). Step 1b2 now checks the leader chip only, and 17d says the child finds its object by the color. No recorded result changed.
- 2026-10-21 (automated): 24 steps moved to the automated tests (`r4_phone_profiles`, `r4_tv_profiles`, `r4_bests`). Step 1b was split (1b2 keeps the look of the avatar). The suite `r4_phone_profiles` fails on step 8a today: the Connect screen shows no reason after the phone was replaced (known bug).
- 2026-11-11 (owner): guests have a picture of their own, a grey silhouette with a question mark (REQ-FL-70). New step 1b3, Not run. No recorded result changed.
- -: **Not run**. New.

## Test 21

### Join by room code and About screens (REQ-FL-83, 84, 85, FD-25, FD-28)

Needs: 2 phones (an Android phone and, if possible, an iPhone), 1 TV on 1080p, a grown-up, a person who reads Hebrew for steps 1e and 10a, a stopwatch. Covers: REQ-FL-83, REQ-FL-84, REQ-FL-85, FD-25, FD-28.

Join approval (issue #393, phase 4): the TV setting "APPROVE NEW PLAYERS" is ON by default, so each phone that joins in this test waits for the host. Before the first join either turn the setting OFF (Settings, first row, press Left) or press OK on ALLOW on the TV card each time a phone joins (the focus is on ALLOW; REQ-FL-93, 94).

New (2026-10-11). The headless tests check the rules and the pages. They do not show how the typed room code works in a hand, or how long the Godot pages take to open on a TV box. Issue #52 (2026-10-21) removed the join PIN, the PIN pad, the list of found TVs, Refresh and the beacon. The steps that stay are about the real phone, the iPhone, a stopwatch and a reader. The old results of the steps about the PIN are kept in the History.

**Steps**

1b. Sit 3 m from the TV. Check: you read aloud the room code without a mistake.
1c. New (2026-11-01, issue #172). Open the Games screen with 0 players joined (TV in English) and sit 3 m from the TV. Check: the header shows the label "ROOM CODE" with the 4-letter code under it, and you read the 4 letters aloud without a mistake. (REQ-FL-15a)
1e. Set the TV to Hebrew and open the Games screen with 0 players, then with 2 players. The person who reads Hebrew reads the header. Check: the Hebrew label and the code show inside the screen margin in mirrored order (right to left) with 0 and with 2 players (2 of 2), and the reader reads the label and the code without a mistake. (REQ-FL-15a)
2. Scan the QR code of the TV with an Android phone. Check: the phone joins within 5 s and asks for nothing after the scan.
3d. Start the stopwatch when the grown-up taps the TV, and stop it when the phone is joined (the grown-up reads the room code from the TV and types it). Check: the time is 15 s or less.
6b. Type the room code and tap **JOIN** with one hand. Check: you reach all letter keys of the keyboard, the delete key and JOIN with the thumb of the hand that holds the phone, without the other hand.
8d2. Read the first line of a page aloud from 3 m. Check: you read it without a mistake. (Down and Up scroll the text: automated.)
8f. On the TV box, use the stopwatch from OK on "3rd Party Libraries" to the list on the screen, and from OK on a library to its page. Check: the list opens within 3 s and the page within 2 s.
9b2. On a phone open a long page (for example a library with two licenses) and drag it with one finger. Check: the text moves with the finger and the last line of the page can be reached by touch.
9h. **New 2026-11-12 (owner).** On an Android phone (an exported app, not the editor) open About, then "Privacy policy". Check: the page shows the text "Sababi Privacy Notice" with the sections 1 to 9, and you reach the last line of section 9 by dragging the page. Set the phone to Hebrew: the page shows the Hebrew notice right to left, and the person who reads Hebrew confirms that it reads right to left without a broken line. On the TV box open About, Privacy policy and scroll to the end with Down. (That the text is the file of the website is automated: `about_pages`.)
9d. Open the page "Android libraries" and scroll to the end with the stopwatch. Check: it opens within 3 s and you reach the end of the text.
10a. Set the TV to Hebrew. Check: the About list and the pages "Sababi" show in Hebrew, and the Hebrew reader says that the wording is correct. (The Settings changes of issue #49 are built and checked by `audio`.)

Items 8c, 8e, 9a, 9c, 9e, 10b moved to the automated tests, and items 8a, 8d, 9b lost the part that a machine checks (`docs/AUTOMATED_TESTS.md`, A-21-8 to A-21-10). The remaining part of 8a is 8a2, of 8d is 8d2, of 9b is 9b2. On 2026-10-21 items 1a, 3a, 3b, 3c, 3e, 4a to 4d, 5a, 5b, 7, 8a2, 8b, 9f and 10c moved too (A-21-1a to A-21-10c). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b | Note: read aloud from 3 m without a mistake | Pass | R4 |  | R3: Pass; R4: Pass R1 passed with the room code and the PIN; the PIN is gone, so it runs again. |
| 1c | Photo of the Games screen with 0 players; the 4 letters read | Pass | R9 |  | R9: Pass New step 2026-11-01 (issue #172). The image `docs/evidence/games_room_code_en.png` is not a device result. |
| 1e | Photos of the Hebrew Games screen with 0 and with 2 players; note from the Hebrew reader | Pass | R9 |  | R9: Pass New step 2026-11-01 (issue #172). The image `docs/evidence/games_room_code_he.png` is not a device result. |
| 2 | Value: seconds until joined; photo of the phone | Pass | R4 |  | R3: Pass; R4: Pass |
| 3d | Value: seconds from the tap to the join | Pass | R4 |  | New limit (15 s) after R1. The grown-up types the room code now. |
| 6b | Note: the iPhone model; keys reached with one hand | Pass | R4 |  | R3: Pass; R4: Pass R1 passed with the PIN pad; the keyboard and JOIN are checked now. |
| 8d2 | Note: read aloud from 3 m | Pass | R3 |  |  |
| 8f | Values: seconds for the list and for a page | Pass | R4 |  | New limits (3 s and 2 s) after R1. |
| 9b2 | Note: scroll by touch | Pass | R3 |  |  |
| 9d | Value: seconds to open the page | Pass | R4 |  | New limit (3 s) after R1. |
| 10a | Photo of the Hebrew About screen; note from the Hebrew reader | Pass | R4 |  | R1: "1. language should be modified by left and right keys. should be a selection of languages. 2. no explanation strings needed for the settings 3. drop Mute. it should be covered by music=0 and/or effects=0" (This note is about the Settings screen: issue #49, done 2026-10-21 and checked by `audio`.) |

History:

- 2026-11-17 (the A button was removed, owner decision in chat; REQ-TN-8, REQ-TN-9): the Tennis pad has no button. Step 16f now checks that the pad shows no A, no B and no RECENTER; its recorded result is kept (the A button was optional and the old check was about B and RECENTER). Steps 16c, 16d and 16g do not mention A as an action. Machines check it (A-25-16h). No recorded result changed.
- 2026-11-17 (steps removed, where each is covered; owner decisions of 2026-11-17, issue #457 and the answer on step 6a): step 1d (4 phones on the Games screen: the label ROOM CODE and the same 4 letters, and the code covers no tile and not the yellow frame of the cursor; it was Not run) is covered by A-21-1d (`games_focus`: with 4 players, in English and in Hebrew, the room code is visible, equal to the TV code, inside the 60 px margin, not over a tile (the cursor frame is the frame of a tile) and not a focus target). Step 6a (an iPhone joins with the typed room code within 5 s; the result was Pass in R3, which is removed with it) is the same as Test 13 step 2d (with the stopwatch and the TV in slot 1); the code half is A-21-1a, 7 and `r4_join_code`. What is not verified by anything now: a real iPhone that types the code, until Test 13 (next release, issue #415) runs.
- 2026-11-17 (recorded; R9 in the tracker): Pass: steps 1c, 1e. Step 1d (4 phones) and step 6a (iPhone; it is Test 13 step 2d) were marked N/A by the owner and are removed (issue #457).
- 2026-11-01: steps 1c to 1e added for the room code in the header of the Games screen (issue #172, REQ-FL-15a). Step 1b keeps its result: it was written and passed before the code was always in the header of the Games screen.
- 2026-10-21 (issue #52, FD-28): the join PIN, the PIN pad and the list of TVs are gone. Steps 1b, 3d, 6a and 6b are about the room code now; 1b, 6a and 6b go back to "Not run" (R1 passed them with the PIN). The tests of the PIN (`r4_pin`, `net_pin`, `probe`) became `r4_join_code`, `about_pages` and `room_code`. The R1 failures of steps 3b and 4b (the texts of a wrong PIN and of the lock) are gone with the PIN.
- 2026-10-21 (automated): 16 steps moved to the automated tests (`r4_pin`, `r4_tv_menus`, `join_flow`, `ui_states_a`). The R1 results of 1a, 3a to 3e, 4a to 4d, 5a, 5b, 7, 9f and 10c stay in the result database.
- R1: **Fail** (steps 3, 4 and 10; the steps 1, 2, 5 to 9 pass). Reported in chat 2026-10-19. The failures of steps 3 and 4 are about the error texts WRONG PIN and TOO MANY WRONG PINS (no text, or a text that goes away). The note of step 10 asks for changes of the Settings screen (issue #49).
- -: **Not run**. New.

## Test 22

### Star Shield (tilt, waves, upgrades)

Needs: 1 to 2 phones, 1 TV, a stopwatch, and a child of about 5 to 8 years for items 9a to 9c. Covers: REQ-AB-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

Hold each phone upright or flat as you do for the other tilt games. New game (2026-10-16). Every number (ship speed, the rate of fire, the asteroid speeds, the waves, the upgrade times) is a first guess, but each step below has a fixed limit. "From 3 m" means: sit or stand 3 m from the TV. Play on Medium unless the step says another difficulty.

**Steps**

1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the night sky with stars, the purple planet, a gray asteroid and a ship.
2e. Read the hint line "Tilt to steer. Your ship shoots by itself. Grab the upgrades!" aloud from 3 m while it shows, in the first 5 s after Start (there is no countdown). Check: no error. (This is the hint line of the game; the description on the Games screen is another text.)
3c. Tilt to the right and keep the tilt for 2 s after the ship stops. Do the same to the left. Check: the ship stops at both sides, stays fully on the screen, does not move more, and its middle is 5.5 % to 7 % of the screen width (about 120 px of 1920: the 60 px margin plus the 60 px of REQ-AB-2) from the edge of the screen.
9a. Let a child of about 5 to 8 years play, with a grown-up next to them who does not help. Check: the child points at its own ship within 10 s after Start (there is no countdown).
9b. Same child. Check: the child moves the ship from the middle to the left side of the screen within 30 s after Start, with no help.
9c. Same child. Lose the ship of the child on purpose while another ship flies. Check: the child is still at the game 30 s later (does not stop and does not give the phone back). Ask: "Play again?". Check: the child says yes (1 of 1 children asked).
12b. From 3 m, look for the objects. Check: you can point at all of these: stars, the far dark world, an asteroid with craters, a ship, a beam, an upgrade and an explosion.
12f. Take a close photo of the TV (30 cm). Check: the edges of the ship and of an asteroid are steps of square pixels, with no blurred edge and no gradient inside a color area.
13a. Look at the pad of a phone while the game runs. Check: the pad shows no button A, no button B and no RECENTER box (3 of 3). (REQ-GM-37a, issue #80)
12h. From 3 m, read aloud the banners "Wave 2", "Wave 2 clear!" and "Next wave in 4", and the points in the bar. Check: no error.
12i. Watch the rest between two waves, in 3 waves. Check: 1.5 s after the banner "Wave n clear!" shows there is no asteroid on the screen, in 3 of 3 waves. (REQ-AB-8, issue #136)
12j. Let an asteroid hit a ship that has a force field, 3 times. Check: the ship blinks for 2.5 s to 3.5 s (stopwatch) and shoots meanwhile, and an asteroid that touches it in this time does not blow it up, in 3 of 3 tries. (REQ-AB-12, issue #137)
12k. From 3 m, play 30 s and ask each of 2 testers what the dark round thing in the top right is ("background" or "target"). Check: both say "background" and nobody shoots at it in 30 s. (REQ-AB-17, issue #138)
14a. Look at the pad of a phone while the game runs. Hold the phone tilted 15 degrees to the right during the countdown (Start) and keep it so for 5 s. Check: the pad shows no RECENTER box, no A and no B (3 of 3 absent on 1 phone), and the ship does not move to the side for more than its own width in 5 s (2 of 2 tries). (REQ-AB-3)
14b. Play a round with 2 phones, one in each hand of two testers, and take 5 pickups, let a ship with a force field be hit 3 times and lose 1 ship. Check: a pickup buzzes the phone shortly (5 of 5), a force field hit buzzes it longer than a pickup (3 of 3 pairs felt right), a lost ship gives the longest buzz (1 of 1), the winner buzzes at the end (1 of 1). Listen to the round. Check: you hear a sound for each of these 7 events: an asteroid breaks, a pickup is taken, a force field takes a hit, a ship is lost, a ship comes back, a wave ends, a wave begins (7 of 7). (REQ-AB-15)
(The music and the effects are checked in Test 18.)

Items 1a, 2a, 2b, 2d, 3a, 3b, 3d, 3e, 4a to 4d, 5a, 5b, 5d, 5e, 5f, 6a to 6d, 7a to 7e, 8a to 8d, 8e, 8f, 10a, 10b and 12d moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-22-1 to A-22-12). Items 2c, 5c, 12a, 12c and 12e were split: the machine checks the numbers (A-22-2, A-22-5, A-22-12), and the part that needs a person is now 2e, 12f, 12g and 12h. Step 3c stays until Alon decides (the step says 2 % to 4 %, the ship is 6.25 % from the screen edge). The numbers of the other items do not change.

Measurements (write down, no pass or fail): the real delay from a tilt to the ship moving; the wave from which you lose in less than 60 s on Easy, Medium and Hard; how long a player who is out waits until the ship is back (wanted: 10 s) with 4 phones; if the rate of fire of 1 shot every 0.4 s feels too slow at the start. Use them to tune `SHIP_SPEED`, `SHIP_SMOOTH`, `FIRE_EVERY` and the wave values.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b | Photo of the tile next to a photo of the game | Pass | R6 |  | R6: Pass |
| 2e | Note: errors made when reading the hint | Pass | R6 |  | R6: Pass - the hint is the game's description which is correct and test needs to be updated (The hint line is the game's own hint; the description on the Games screen is another text. The step text was made clear on 2026-10-30.) |
| 3c | Photo of the ship at each stop; note: distance to the edge in % | Pass | R6 |  | R6: Pass |
| 9a | Note: the child, the age, seconds until it points | Pass | R6 |  | R6: Pass |
| 9b | Note: seconds until the ship is at the left side | Pass | R6 |  | R6: Pass |
| 9c | Note: the child is still at the game after 30 s (yes or no); the answer | Pass | R6 |  | R6: Pass |
| 12b | Note: the seven objects, each yes or no | Not run | | | |
| 12f | Close photo of the TV (30 cm) | Pass | R6 |  | R6: Pass |
| 13a | Photo of the pad while the game runs | Pass | R6 |  | R6: Pass |
| 12h | Note: errors made when reading the texts | Pass | R6 |  | R6: Pass |
| 12i | Note: asteroids seen 1.5 s into the rest (per wave) | Pass | R9 |  | R9: Pass Added 2026-10-27 (issue #136). |
| 12j | Note: the seconds of blinking in 3 tries (stopwatch); whether a touch in this time blew up the ship | Pass | R9 |  | R9: Pass Added 2026-10-27 (issue #137). The 3 s is the owner's value. |
| 12k | Note: the answers of 2 testers; shots at it in 30 s | Pass | R9 |  | R9: Pass Added 2026-10-27 (issue #138). The look is the owner's choice A. |
| 14a | Photo of the pad; video of the ship | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 14b | Note: buzzes per event; the sounds heard (of 7) | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |

History:
- 2026-11-10 (step removed): Owner decision of 2026-11-10 (issue #440, the owner answered: remove them; the owner has 1 Android phone and no TV box). The FPS step on the TV box (step 11) is removed: nobody can do it now. The cost of a frame with 4 phones on Hard stays automated (`frame_cost`, A-22-11, issue #132); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device). REQ-GM-50 is dropped from the Covers line of this test.

- 2026-11-10 (recorded; R6 in the tracker): Pass: steps 1b, 2e, 3c, 9a, 9b, 9c, 12f, 13a, 12h. R6: step 11 passed on the old text (4 phones on Hard until wave 8) and step 12b on the old list of objects (the planet with the ring); both stay Not run because the steps changed (11 is 1 phone on the TV box now, A-22-11). Step 2e: the owner noted that the hint is the description of the game and that the test needed to change: the step says now which text it is. Step 12g: see below. Step 12g (4 phones) was marked N/A by the owner ("don't have 4 phones, remove this step or automate if possible") and is removed: the 4 ship colors are told apart by A-22-12g (REQ-AB-*, REQ-GM-46).
- 2026-10-21 (decision of the owner, REQ-GM-35): Star Shield has no timer, so it has no countdown: wave 1 starts at once after Start. Steps 2e, 9a and 9b say "after Start" instead of "3, 2, 1" and "GO" (they were not run). No recorded result changed.
- 2026-10-21 (aligned with the requirements, not run): step 3c now says 5.5 % to 7 % (about 120 px of 1920), the 60 px margin plus the 60 px of REQ-AB-2. No recorded result changed.
- 2026-10-21 (automated): items 5f and 8e moved to the automated tests (`auto_asteroid`, `r4_asteroid`). Step 3c is also checked by `r4_asteroid`, which fails on the 2 % to 4 % limit today (the ship is 120 px, 6.25 %, from the screen edge).
- 2026-10-20: the steps that a machine can check moved to the automated tests (A-22-1 to A-22-12). 2c, 5c, 12a, 12c and 12e were split into the automated part and 2e, 5f, 12f, 12g and 12h (each keeps the result of the old step). Step 8e (the title and the medal of one player) is automated now (`r4_asteroid`); it finds that the medal does not follow the score (REQ-AB-14), so that suite is red until that is fixed.
- -: **Not run**. New (2026-10-16).

History:

- 2026-11-17 (recorded; R9 in the tracker): Pass: steps 12j, 12i, 12k, 14a, 14b.

## Test 23

### Bowling (aim with a finger, swing to throw)

Needs: 1 to 2 phones, 1 TV, a stopwatch, a phone camera (60 fps or more), and a child of about 5 to 8 years for items 11a to 11c. Covers: REQ-BW-*, REQ-GM-80 to 84, REQ-GM-90 to 98, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-16). It was only tested with made-up sensor values. Every number (the swing thresholds 4, 8 and 30 m/s2, the aim ranges, the ball speeds, the lane, the pins) is a first guess, but each step below has a fixed limit. Hold the phone in one hand like a ball, arm down at the side. "From 3 m" means: sit or stand 3 m from the TV. Play on Medium unless the step says another difficulty.

**Steps**

1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the lane with pins, the ball, the gray floor and the disco wall.
3e. **Aim strip.** On the phone on turn, slide a finger from the left end of the strip to the right end in about 1 s, then back. Check: the ball on the TV is in the left gutter at the left end of the strip and in the right gutter at the right end, and it moves in the same direction as the finger. (The mapping is in A-23-3.) (REQ-BW-4)
3f. Film the phone and the TV together at 60 fps or more and slide a finger on the strip. Check: the ball starts to move within 12 frames (0.2 s) after the finger starts to move, in 5 of 5 tries.
3g. Touch the rest of the screen outside the strip with a finger, 5 times. Check: the ball does not move, and the pad shows no A and no B button (REQ-GM-37a, issues #80 and #143). A phone that is not on turn has no Recenter box either (REQ-GM-37, issue #55).
3h. **Knob, trail and tick (2026-10-30, issue #236).** On the phone on turn, slide a finger slowly from the left end to the right end of the strip, with the HAPTICS switch ON. Check: the knob is still visible next to the finger (yes or no), a fading trail follows it (yes or no), and the phone ticks once as the knob passes the middle mark (once in 5 of 5 slides). (REQ-BW-4a)
4e. Throw 5 balls with each grip: screen up, screen to the side, and the other hand. Check: at least 4 of 5 swings throw a ball for each grip. (REQ-BW-5)
4f. Walk 10 steps with the phone in your hand. Check: no ball is thrown.
4g. Shake the phone fast, back and forth, with no wind-up, 5 times 2 s apart, once with the finger off the strip and once with a finger on the strip. Check: no ball is thrown in the 10 shakes. Then swing normally 5 times. Check: at least 4 of 5 swings throw a ball. (REQ-BW-5, MIN_BACK, MIN_FORWARD; changed 2026-11-12, issue #432: retest with the new rules, the same check)
4h. Swing normally with a thumb still on the aim strip, 5 times. Check: no ball is thrown and the hint "Lift your finger, then swing!" shows in 5 of 5 swings.
11a. Let a child of about 5 to 8 years play on Easy with Rails With, with a grown-up next to them who does not help. Check: the child points at its own ball (the one in the color of its phone) within 10 s after Start (there is no countdown).
11b. Same child. Check: the child throws a ball (a ball leaves the foul line) within 60 s after the first plate "YOUR TURN", with no help.
11c. After the game, ask: "Play again?". Check: the child says yes (1 of 1 children asked).
13b. From 3 m, a tester points at the ball each time you say "mark" at a random time during a roll. Check: the finger points at the ball (not at a pin or the lane) in 5 of 5 tries.
13c. From 3 m, read aloud the totals of all rows of the score sheet and one banner. Check: no error.
14a. On the phone on turn, slide a finger to about three quarters of the strip to the right and lift it. Wait 5 s. Check: the mark on the phone and the ball on the TV stay where the finger lifted (each moves less than the width of the ball in 5 s, 5 of 5 tries). Start the turn of a new player and look before touching the strip. Check: the ball is in the middle of the lane (3 of 3 new players). Throw ball 1 and look at the start of ball 2 of the same player. Check: the ball and the mark are where they were at the throw (3 of 3 players). Start the back swing and slide the finger on the strip meanwhile. Check: the ball does not move (5 of 5). (REQ-BW-4)
14b. Take a screenshot of the phone while a finger holds the knob on the strip and measure the knob in the screenshot. Check: the radius of the knob is 88 px (80 px to 96 px). Slide a finger slowly from the left end to the right end. Check: the trail has 2 to 8 fading circles at any moment (5 of 5 slides), and it starts new when the finger goes down again (5 of 5). (REQ-BW-4a)
14c. Throw 5 soft swings and 5 hard swings on Medium and film the TV at 60 fps or more. Count the frames from the foul line to the first pin. Check: the median time of the hard swings is shorter than the median time of the soft swings. Then swing so weakly that nothing is thrown, 3 times, and use a stopwatch. Check: no ball is thrown and the hint "Swing a bit more!" shows for 2.5 s to 3.5 s (3 of 3 tries). On Easy throw 5 soft and 5 hard swings. Check: the medians of the two times differ by less than 10 %. (REQ-BW-6)
14d. Hold the phone of the player on turn and throw 5 balls. Check: the phone buzzes shortly at the release of the ball in 5 of 5 throws. At the start of 5 turns of this phone, look and feel. Check: the plate "YOUR TURN" shows with a buzz that is longer than the buzz at the release (5 of 5 turns), the phone of another player does not buzz at it (0 of 5), and while another player bowls the phone shows "<NAME> IS BOWLING" and its own score and place (3 of 3 turns). (REQ-BW-7, REQ-BW-14)
14e. Throw 10 balls on Medium. Check: in at least 1 of the 10 throws a pin that the ball did not touch falls (pin action), and a ball that hits the front pin in the middle knocks down 5 pins or more in at least 3 of the 10 throws. In a screenshot of the lane measure a pin and the ball. Check: the ball is wider than a pin (ball radius 0.11 m, pin radius 0.09 m; 1 of 1). (REQ-BW-9)
14g. From 3 m, a tester points at: the own lane, a gutter, the red foul line, a lane at the side with its pins, the gray floor, the disco wall at the far end and the black part of the wall. Check: 7 of 7 right for each of 3 testers (3 of 3 testers). Count the pins in the rack of the own lane. Check: 10. Make a strike. Check: the tester says "strike" at the burst, in 3 of 3 strikes. (REQ-BW-13)
14h. Let the child of step 11a play 3 frames (6 balls) on Easy with Rails WITH. Check: the child knocks down at least 1 pin with at least 4 of the 6 balls, and no ball goes to the gutter (0 of 6). (REQ-BW-17)
(The music and the effects are checked in Test 18.)

Items 1a, 2a to 2e, 3a to 3d, 4a to 4d, 5a, 5b, 6a to 6d, 7a, 7b, 8a to 8e, 9a to 9c, 10a to 10c, 13a, 13d, 14 and 14a to 14c moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-23-1a to A-23-14c). Items 4e and 4f keep only the part that needs a real phone (the rest is in A-23-4). Items 3e to 3g, 4g and 4h are new (2026-10-21, the aim is a finger since 2026-10-20): they need a real touch screen and real hands. The numbers of the other items do not change.

Measurements (write down, no pass or fail): if the strip is too small or too large and if it is hard to slide with the thumb while the other fingers hold the phone; every swing that did not throw and every throw that you did not mean (with the grip); the peak power of a soft and a hard swing. Use them to tune `AIM_X`, `BACK_ACCEL`, `FWD_ACCEL`, `FWD_FULL` and `MIN_BACK`.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b | Photo of the tile next to a photo of the game | Pass | R6 |  | R6: Pass |
| 3e | Note: where the ball is at the two ends of the strip | Pass | R6 |  | R6: Pass |
| 3f | Video of the phone and the TV; note: frames of delay | Pass | R6 |  | R6: Pass |
| 3g | Note: balls that moved when the screen was touched; a photo of the pad | Pass | R7 |  | R7: Pass |
| 3h | Video of the finger and the knob; note: ticks counted in 5 slides | Pass | R7 |  | R7: Pass Added 2026-10-30 (issue #236). |
| 4e | Note: throws of 5 for each grip | Pass | R6 |  | R6: Pass |
| 4f | Note: balls thrown while walking | Pass | R6 |  | R6: Pass |
| 4g | Note: balls thrown by 10 shakes; throws of 5 normal swings | Pass | R9 |  | R9: Pass Before (R7): Fail - R7: Fail - this is still failing! when shaking with a finger on the strip the ball isn't thrown. shaking without the finger on the strip throws the ball. (2 tries, the last one counts) Issue #432. (2 tries, the last one counts) |
| 4h | Note: balls thrown and hints shown in 5 swings with a thumb on the strip | Pass | R6 |  | R6: Pass |
| 11a | Note: the child, the age, seconds until it points | Pass | R6 |  | R6: Pass - (Run on the text "Rails On" (the step says Rails With since then).) |
| 11b | Note: seconds until the first ball | Pass | R6 |  | R6: Pass |
| 11c | Note: the answer of the child | Pass | R6 |  | R6: Pass |
| 13b | Note: pointed right, of 5 tries | Pass | R6 |  | R6: Pass |
| 13c | Note: errors made when reading | Pass | R6 |  | R6: Pass |
| 14a | Video of the strip and the TV; note: each count of 5, 3 and 3 | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 14b | Screenshot with the measure; note: the trail counts | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 14c | Video; note: the 2 medians on Medium; the hint times; the 2 medians on Easy | Not run | | | Added 2026-10-31 (issue #306). |
| 14d | Note: buzzes at the release (of 5), at the turn start (of 5), other phone (of 5), the line (of 3) | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |
| 14e | Video of 10 throws; screenshot with the sizes; note: the counts | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |
| 14g | Note: the answers of each tester; the pins counted; strikes seen (of 3) | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |
| 14h | Note: the child, the age; balls with a pin down (of 6); balls in the gutter (of 6) | Pass | R7 |  | R7: Pass Added 2026-10-31 (issue #306). |

History:

- 2026-11-17 (recorded; R9 in the tracker): Pass: steps 4g, 14a, 14b. Step 4g passed on the second try (the fix of issue #432, run after the change of the detector).
- 2026-11-10 (step removed): Owner request of 2026-11-10 (tracker and chat: "Tests 14, 23, 27, 28 and 31 still have steps that either need to be removed or automated"; the owner has 1 Android phone and no TV box). The FPS step on the TV box is removed: nobody can do it now. The cost of a frame with 4 phones on Hard stays automated (`frame_cost`, A-23-12); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device).
- 2026-11-10 (recorded; R7 and R6 in the tracker): Pass: steps 1b, 3e, 3f, 3g, 3h, 4e, 4f, 4h, 11a, 11b, 11c, 13b, 13c, 14d, 14e, 14g, 14h. Fail: step 4g. Step 14f (4 phones) was marked N/A by the owner ("don't have 4 phones, remove this step or automate if possible") and is removed: the top bar, the 4 rows of the score sheet and the whole names are the new A-23-14f (REQ-BW-12). Step 4g failed twice (issue #432). The R6 N/A of the old steps 12, 14a and 14b is not recorded: those steps changed after R6 (12 is 1 phone now; the safety card is checked by A-23-14a, A-23-14b and A-25-15a).
- 2026-10-21 (decision of the owner, REQ-GM-35): Bowling has no timer, so it has no countdown: the first turn starts at once after Start, with the plate and the turn buzz. Step 11a says "after Start" (not run). No recorded result changed.
- 2026-10-21 (automated): 15 steps moved to the automated tests (`smoke_bowling`, `r4_bowling`). `r4_bowling` is red today on three known bugs: the result menu opens after 3.8 s (step 6c said 1 to 3 s), the plate with the name shows the whole turn (step 8a said 1 to 2 s), and the first turn gives two buzzes (step 9a).
- 2026-10-21 (merge with main, PR 59): the aim is a finger on the aim strip, not the turn of the phone. The yaw steps stay removed; new steps 3e to 3g (strip, delay, A and B), 4g (shakes) and 4h (thumb on the strip). No recorded result changed.
- -: **Not run**. New (2026-10-16).

## Test 24

### Swing detector for Tennis (no manual step since 2026-11-17)

Needs: no device. Covers: REQ-TN-5 to 9 (`docs/games/tennis.md`), REQ-T4, REQ-T7. New (2026-10-17). Tennis was built after this test (Test 25).

**This test has no manual step since 2026-11-17.** Every step read the debug overlay (the swing counter, `power`, `side`, `DOWN`, `Age ms`, the recorder line), and the owner decided on 2026-11-17 (issue #458) that no manual test uses the debug overlay. The test stays in this file with its number. The swing detector (`scripts/input/swing_detector.gd`, as Tennis uses it through `PlayerInput`) is checked by machines: `swing_replay` (A-24-1 to A-24-11: still hand and walking, strokes of 5 grips, power, serve DOWN, one stroke is one swing, the lock of 0.6 s, shake and tap, the hit age, 2 phones, flipped sensor signs, the `side` value), `sensor_recorder` (A-24-12: the recorder, REQ-T7) and `swing_detector` (real recordings of a fast shake, A-23-4j). The tests use made-up traces (`tests/sensor_replay.gd`) and two real recordings: no test uses the sensors of a real phone in a hand.

**Results**

No step. The old steps had no result (all Not run).

History:

- 2026-11-17 (steps removed): Owner decision of 2026-11-17 (issue #458: "remove every manual step that needs the debug overlay"). All 10 remaining steps are removed: 8b ("Age ms" of the real phone below 150 for 10 s), 10a and 10b (the counter and `DOWN` on an iPhone), 11a, 11c and 11d (the `side` value to the right, to the left, straight and nearly vertical), 12a (10 sweeps give a counter of 0), 12b (5 hard shakes give 0), 12c (10 real forehands give 9 or 10) and 12d (the recorder of raw samples: 60 files, 6 labels, 50 rows a second). None had a result. Covered by machines: A-24-1 to A-24-11 and A-24-12 (`swing_replay`, `sensor_recorder`). What is not verified by anything now: the swing detector with the sensor of a real phone in a hand (the counter for real forehands, sweeps and hard shakes, the `side` value of a real swing, the `DOWN` of a real serve, the `Age ms` of the real Wi-Fi, an iPhone), and the real traces that step 12d was to collect for tuning the rule that tells a sweep or a shake from a swing (the 2 recordings of `tests/fixtures/shake_432` are the only real ones). **Issue #209 (retest of the swing detector on a device) had this test as its device test: it has no manual test now.** Test 25 steps 16c, 16f and 16h and Test 26 steps 16h and 16i still swing a real phone in a real game; they are the device check of the detector now.
- 2026-11-01 (not run): steps 12a to 12d added (issue #209): sweeps, hard shakes, real swings and the missing recorder. No recorded result changed.
- 2026-11-01 (not run): step 12d rewritten for the sensor recorder of the debug overlay (REQ-T7). It was a note about a missing tool. No recorded result changed.
- 2026-10-21 (aligned with the requirements, not run): step 11a now swings to both sides in one run and 11b is merged into it (REQ-TN-7: straight is the mean of the player's own swings); 11c starts with RECENTER. No recorded result changed.
- -: **Not run**. New (2026-10-17).

## Test 25

### Tennis (swing, toss, serve, rally, scoring)

Needs: 1 to 2 phones, 1 TV, a stopwatch, a phone camera (240 fps for item 4g), and a child of about 5 to 8 years for items 12a to 12d. Covers: REQ-TN-* (`docs/games/tennis.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-17). It was only tested with made-up sensor values. Every number (the swing thresholds of Test 24, the hit window of 0.55 s, the green half width of 0.30, 0.21 and 0.15 s, the ball speeds) is a first guess, but each step below has a fixed limit. Tennis uses the shared swing detector, which machines check (A-24-*; Test 24 has no manual step since 2026-11-17). Hold the phone like a racket handle, with the screen toward you. The direction of the swing sends the ball: swing toward the right of the TV and the ball goes right, toward the left and it goes left (changed 2026-10-18: the tilt did not work). The first run (2026-10-18) found swings that were not detected and shots that mostly went left for a right-handed player: check both again (items 6c to 6e; the swing detection of items 3c, 4d and 4f is checked by the automated tests). "From 3 m" means: sit or stand 3 m from the TV. Play on Medium unless the step says another difficulty.

**Steps**

1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the court, the net, a character and the ball.
2b. Right after Start (a match of 2 to 4 players has no countdown) look at the court. Check: you can point at all of these: the doubles sidelines, the singles sidelines, the baselines, the service lines, the net, the umpire on the chair, the stands and the blank ad boards. (REQ-TN-2)
4g. Record the phone and the TV with the camera (240 fps) for 5 hits. Count the frames from the fastest point of the swing to the contact of the racket and the ball. Check: the median delay is 150 ms or less (36 frames at 240 fps).
6c. Alternate swings 30 degrees to the right and 30 degrees to the left of your usual straight swing, 5 each, 2 s apart. Check: at least 4 of the 5 balls to the right land in the right half of the court (from the view of the swinging player), and at least 4 of the 5 balls to the left land in the left half.
6e. Swing the way you swing when you do not aim, 5 times, then nearly straight up, 5 times, 2 s apart. Check: at least 8 of 10 balls land in the middle third of the court width.
6h. Give the phone to a person who has not played. Show only the hint line. Check: the person sends one ball to the left half and one ball to the right half of the court within 5 swings each.
12a. Let a child of about 5 to 8 years play on Easy, with a grown-up next to them who does not help. Check: the child points at its own character within 10 s after Start (there is no countdown).
12b. Same child. Check: the child serves a ball in play (over the net, inside the box) within 5 tries.
12c. Same child. Check: the child returns a ball at least once in the first 3 min of a rally.
12d. After the match, ask: "Play again?". Check: the child says yes (1 of 1 children asked).
14a. **Pixel world (REQ-GM-47i to 47n).** From 3 m, a tester calls "in" or "out" at the moment of the bounce for 10 balls. Check: at least 8 of 10 calls agree with the banner ("OUT" or no banner). The ball and its shadow are visible.
14c. From 3 m, read aloud the scoreboard and one banner. Check: no error.
15a. With 2 phones connected, open the settings view of Tennis (OK on its tile). Check: the TV shows the line "HOLD YOUR PHONE TIGHT AND KEEP SPACE AROUND YOU." in a large box at the top, under the title, both phones show the card "HOLD ON TIGHT!" with the line "GRIP FIRMLY. KEEP SPACE AROUND YOU." and an OK button, and Start is off with the line "WAITING FOR PHONES" (4 of 4). (REQ-GM-102, issue #79)
15c. **The card with children (2026-10-30, issue #235).** Show the card (open the Tennis settings view) on a phone to 3 children of 5 to 8 years, 5 seconds each, and ask: "What do you do before you play?". Check: at least 2 of 3 answer with holding the phone tight or making space around them. A Hebrew reader checks the Hebrew line "אחזו חזק. שמרו מרחק מסביב." (`swing.card_text`).
16a. From 3 m, a tester points at: a near character, a far character, the ball and the shadow of the ball. Check: 4 of 4 right for each of 3 testers (3 of 3 testers). Measure the height of a near character and of a far character in a photo of the 1080p TV. Check: the near one is at least 1.5 times as high as the far one, the near one is seen from behind and the far one faces the camera (2 of 2), and the ball has a thin black border in a photo zoomed to 300% (yes or no). (REQ-TN-3)
16b. Serve 5 times with a swing in the green part of the ring, 5 times too early and 5 times too late. Check: a swing in the green part gives a fast shot with sparks in at least 4 of 5 swings; an early or a late swing gives a slower high lob that lands in the court in at least 4 of 5 swings each, with no sparks (0 of 10); the median flight time of the 10 lobs is longer than the median flight time of the 5 fast shots (video at 60 fps). (REQ-TN-6)
16c. Wait for the ball to be tossed by itself (about 1.5 s after "X SERVES") and swing the phone as a serve when the ball is at its top (up and a little back, then forward and down, in one move), 5 times with the phone in one hand (changed 2026-11-14, issue #419; the step does not use the A button, 2026-11-17). Check: the serve is counted in 5 of 5 tries. Swing 0.3 s after the top: counted in 5 of 5 tries. Swing about 0.3 s after the toss, before the top (added 2026-11-08, issue #419): counted in 5 of 5 tries. Swing 0.8 s after the top (the ball is low): not counted in 5 of 5 tries (0 counted). Swing and miss on purpose (a swing that does not go down): the character shows the serve pose, with the racket high, and not a plain hit (5 of 5). (REQ-TN-9)
16d. Toss and do not swing, 3 times, with a stopwatch from the toss. Check: the ball falls 1.2 s to 1.6 s after the toss and the server's ball is tossed again by itself about 1.5 s later, with no fault and no point lost (3 of 3). A hard serve straight ahead lands in the box, and a ball that touches a line is in (added 2026-11-14, issue #419). Make a serve land out (clearly wide, not on a line). Check: it is served again (1 of 1). Make the second serve land out too. Check: the point goes to the other team (1 of 1). (REQ-TN-9)
16f. Look at the pad of a phone in a match. Check: the pad shows no button at all: no A, no B and no RECENTER box (2 of 2 phones; changed 2026-11-17: the A button was removed, owner decision). Hit 5 normal shots and 5 fast shots with the phone in your hand. Check: every hit buzzes (10 of 10) and, with your eyes closed, you name the fast shot (60 ms) of a pair right in 4 of 5 pairs against the normal shot (30 ms). (REQ-TN-8)
16g. Start a match with 2 phones and a stopwatch. Check: before the first serve the hint line shows one line at the bottom that tells to wait for the toss, swing down to serve and swing to a side to aim (changed 2026-11-14: it said to press A); in a rally it tells to swing when the ball arrives and to swing to a side to aim; a match with 1 player shows the line for 1 player (3 of 3 variants as written); the line goes away 15 s to 17 s after it began (3 of 3 matches). (REQ-TN-8)
16h. Start a solo rally. When the ball glows, move the phone back (a wind-up, about 0.3 s) and then forward through the ball, 10 times. Then 10 times move the phone only back, hard and fast, and stop. Then 10 times move the phone only forward, fast, from rest. Check: the hit is counted on the forward move in 9 of 10 back-then-forward strokes, in 0 of 10 back-only moves, and in 0 of 10 forward-only moves (REQ-TN-5, two-phase swing, 2026-11-03; changed 2026-11-17: the half that read the overlay `swing_count` is removed).

Items 1a, 2a, 2c, 3a, 3b, 3c, 3d, 3e, 3f, 4a, 4b, 4c, 4d, 4e, 4f, 5a, 5b, 5c, 5d, 6a, 6b, 6f, 6g, 7a to 7d, 8a, 8b, 9a to 9e, 10a, 10b, 10c, 10d, 11a, 11b moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-25-1a to A-25-11b). The numbers of the other items do not change.

Measurements (write down, no pass or fail): the time of a whole match with 2 phones (the plan says about 8 minutes with 4 phones); the delay from the swing to the hit; if the green part feels too short or too long on each difficulty; every swing that went to the wrong side. Use them to tune the green half widths, the hit window and `SWING_SIDE_FULL`.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b | Photo of the tile next to a photo of the game | Fail | R9 |  | R9: Fail - need to retake the game tile screenshot since there were some changes Issue #456. |
| 2b | Photo of the court; note: the nine objects, each yes or no | Pass | R9 |  | R9: Pass |
| 4g | Video (240 fps); note: frames and ms for 5 hits | Pass | R9 |  | R9: Pass |
| 6c | Note: balls in the right half of 5, and in the left half of 5 | Pass | R9 |  | R9: Pass |
| 6e | Note: balls in the middle third of 10 | Pass | R9 |  | R9: Pass |
| 6h | Note: swings until left and right, for the person | Pass | R9 |  | R9: Pass |
| 12a | Note: the child, the age, seconds until it points | Pass | R9 |  | R9: Pass |
| 12b | Note: tries until a served ball | Pass | R9 |  | R9: Pass |
| 12c | Note: returns in 3 min | Pass | R9 |  | R9: Pass |
| 12d | Note: the answer of the child | Pass | R9 |  | R9: Pass |
| 14a | Note: calls that agree, of 10 | Pass | R9 |  | R9: Pass |
| 14c | Note: errors made when reading | Pass | R9 |  | R9: Pass |
| 15a | Photo of the TV and of both phones | Pass | R9 |  | R9: Pass |
| 15c | Note: the ages and the answers of 3 children; a photo of the card | Pass | R9 |  | R9: Pass Added 2026-10-30 (issue #235). |
| 16a | Photo with the heights; note: the answers of each tester | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 16b | Video; note: sparks (of 5), lobs in play (of 5 and of 5), the 2 medians | Pass | R9 |  | R9: Pass - the owner verified it on the TV and asked to set it to Pass after the step text was changed (the toss is automatic; the step does not use the A button). The N/A note of the tracker: the steps needed to change. Added 2026-10-31 (issue #306). |
| 16c | Video at 60 fps; note: counted serves in each group of 5 | Pass | R9 |  | R9: Pass - the owner verified it on the TV and asked to set it to Pass after the step text was changed (the toss is automatic; the step does not use the A button). The N/A note of the tracker: the steps needed to change. Added 2026-10-31 (issue #306). |
| 16d | Note: the 3 fall times; the two outs | Pass | R9 |  | R9: Pass - the owner verified it on the TV and asked to set it to Pass after the step text was changed (the toss is automatic; the step does not use the A button). The N/A note of the tracker: the steps needed to change. Added 2026-10-31 (issue #306). |
| 16f | Photo of the pad; note: the buzzes (of 10), the pairs right (of 5) | Pass | R9 |  | R9: Pass - the owner verified it on the TV and asked to set it to Pass after the step text was changed (the toss is automatic; the step does not use the A button). The N/A note of the tracker: the steps needed to change. Added 2026-10-31 (issue #306). 2026-11-17: the A button was removed (owner); the step text now checks that the pad has no button. |
| 16g | Photos of the 3 hint lines; note: the 3 times | Pass | R9 |  | R9: Pass - the owner verified it on the TV and asked to set it to Pass after the step text was changed (the toss is automatic; the step does not use the A button). The N/A note of the tracker: the steps needed to change. Added 2026-10-31 (issue #306). |
| 16h | Note: hits on the forward move (of 10), on back-only (of 10), on forward-only (of 10) | Pass | R9 |  | R9: Pass, run on the text with the overlay counter; the overlay half was removed on 2026-11-17 (issue #458), the rest of the step stays as run. Added 2026-11-03 (two-phase swing). |

History:
- 2026-11-10 (step removed): Owner decision of 2026-11-10 (issue #440, the owner answered: remove them; the owner has 1 Android phone and no TV box). The FPS step on the TV box (step 13) is removed: nobody can do it now. The cost of a frame with 4 phones on Hard stays automated (`frame_cost`, A-25-13, issue #132); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device). REQ-GM-50 is dropped from the Covers line of this test.

- 2026-10-21 (decision of the owner, REQ-GM-35): a Tennis match of 2 to 4 players has no timer, so it has no countdown and starts at once after Start; only the solo machine rally keeps the 3 s countdown. Steps 2b and 12a say "after Start" (not run). No recorded result changed.
- 2026-10-21 (automated): 10 steps moved to the automated tests (`r4_tennis`, `smoke_tennis_phones`). `r4_tennis` is red today on three known bugs: no sparks in the code (5a), the other team shows place 3 and not 2 (9e), and a new rally starts about 3.4 s after a miss (10b said 1.5 to 2.5 s).
- 2026-10-21 (aligned with the requirements, not run): steps 6c and 6d are merged into 6c (alternate right and left, REQ-TN-7); 6e says 'the way you swing when you do not aim'. No recorded result changed.
- -: **Not run**. New (2026-10-17).

History:

- 2026-11-17 (steps removed, where each is covered; owner decisions of 2026-11-17, issues #457 and #458): step 14b (4 phones: each tester names the shirt color of the two far characters, 2 of 2 for each of 3 testers; it was Not run) is covered by A-25-14b (`smoke_tennis_phones`, new: with 4 phones each of the 4 characters, near and far, wears the color of its phone, and the 4 colors differ; the palette is A-237-1). Step 16e (the overlay counts 1 swing for a swing and the stroke back at once and 2 for strokes 0.7 s apart; it was Not run) is covered by A-25-16e (`swing_replay`, A-24-6: a stroke and the stroke back at once is one swing; two strokes 0.5 s and 1.0 s apart are both found). Step 16h lost its overlay half (the counter `swing_count`); the hit on the forward move, in 9 of 10 strokes, 0 of 10 back-only and 0 of 10 forward-only, stays (it passed in R9 with both halves; the result stays). Stray rows 14d and 14e of Test 26 in the Results table of this test are removed. What is not verified by anything now: that 3 testers name the shirt colors from 3 m (REQ-TN-3), and the swing counter of the real phone in a Tennis game (the hit counted on the forward move is still checked by a person in 16h). The Needs line says 1 to 2 phones.
- 2026-11-17 (recorded; R9 in the tracker): Pass: steps 2b, 4g, 6c, 6e, 6h, 12a, 12b, 12c, 12d, 14a, 14c, 15a, 15c, 16a, 16h. Fail: step 1b. Step 1b Fail: issue #456 (retake the tile). Steps 16b, 16c, 16d, 16f and 16g: the toss is automatic since 2026-11-14, the owner verified them and asked to set them to Pass after the step text changed (16c and 16f were changed today to not use the A button). Step 14b (4 phones) and step 16e (debug overlay) were marked N/A and are removed (issues #457, #458).

## Test 26

### Mini Golf (aim, putt power, turns, 5 holes)

Needs: 1 to 2 phones, 1 TV, a stopwatch, a phone camera (240 fps for item 5e), and a child of about 5 to 8 years for items 12a to 12d. Covers: REQ-MG-* (`docs/games/mini_golf.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-17). It was only tested with made-up sensor values. Every number (the swing thresholds of Test 24, the putt speeds, the friction of the grass, the 5 course designs, the aim line lengths) is a first guess, but each step below has a fixed limit. Mini Golf uses the shared swing detector, which machines check (A-24-*; Test 24 has no manual step since 2026-11-17). Hold the phone like a putter, with the screen toward you: turn it left and right to aim, swing it back and then forward to putt. "From 3 m" means: sit or stand 3 m from the TV. Play on Medium unless the step says another difficulty. The pars of the 5 holes are 2, 3, 3, 3 and 4.

**Steps**

1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the lawn, the brown wall of the course seen from above, a golfer and a white ball.
3b2. Look at the golfer. Check: the cap, the trousers and the shoes are white (3 of 3 white). (The shirt has the color of the phone of the player on turn: A-26-3b.)
5e. Record the phone and the TV (240 fps) for 5 putts. Count the frames from the fastest point of the swing to the first move of the ball. Check: the median delay is 150 ms or less (36 frames at 240 fps).
12a. Let a child of about 5 to 8 years play on Easy, with a grown-up next to them who does not help. Check: the child points at its own character (the one in the color of its phone) within 10 s after Start (there is no countdown).
12b. Same child. Check: the child turns the phone and the aim mark moves to the left side within 30 s after the first plate "<NAME>'S TURN!", with no help.
12c. Same child. Check: the child putts the ball (one stroke counted) within 60 s after the first plate, with no help.
12d. After the match, ask: "Play again?". Check: the child says yes (1 of 1 children asked).
14a. **Pixel world (REQ-GM-47i to 47n).** From 3 m, a tester points at the ball each time you say "mark" while it rolls on hole 5. Check: the finger points at the ball in 5 of 5 tries. Check: the ball is 32 px high on the screen at 1080p (photo; 32 px is an exception to the 48 px of REQ-GM-47e for this game, owner 2026-11-03). (REQ-GM-47e)
14b. From 3 m, ask a tester to point at the golfer and then at the windmill. Check: both answers are right for each of 3 testers (3 of 3 testers).
14c. From 3 m, read aloud the names and strokes in the bar and one banner. Check: no error.
15a. With 2 phones connected, open the settings view of Mini Golf (OK on its tile). Check: the TV shows the line "HOLD YOUR PHONE TIGHT AND KEEP SPACE AROUND YOU." in a large box at the top, under the title, both phones show the card "HOLD ON TIGHT!" with the line "GRIP FIRMLY. KEEP SPACE AROUND YOU." and an OK button, and Start is off with the line "WAITING FOR PHONES" (4 of 4). (REQ-GM-102, issue #79)
16a. Hold the phone like a putter in the aim phase. Turn it 20 degrees to the left, then 20 degrees to the right (a protractor app), 5 times each way. Then tilt it forward and back by 20 degrees without turning, 5 times. Check: the aim mark moves to the left for each left turn and to the right for each right turn (10 of 10), and a tilt without a turn moves the mark sideways by less than the width of the ball (5 of 5). (REQ-MG-4)
16b. Aim to the left, begin the backswing (the first clear movement back) and turn the phone to the right while the club goes back and forward. Wait until the ball stops, then turn the phone to the right again. Check: during the swing the aim mark stays where it was at the start of the backswing (it moves less than the width of the ball) in 5 of 5 putts, and after the ball has stopped the mark follows the turn of the phone again (5 of 5). (REQ-MG-4)
16b2. (Added 2026-11-03.) Hold the phone like a putter in the aim phase. Turn it until the dotted line is about 20 degrees from the cup, press A, then turn the phone 30 degrees and swing back and forward, 5 times. Check: the dotted line does not move after A (gold dots, 5 of 5 putts). Press A again. Check: the dotted line follows the phone again (5 of 5). Then turn the phone until the line is within about 5 degrees of the cup, 5 times. Check: the line goes to the cup and turns green (5 of 5), and 15 degrees away it stays white (5 of 5). (REQ-MG-4)
16b3. (Added 2026-11-06, owner feedback.) Play with 2 phones. Player 1 putts. While the turn banner of player 2 shows, player 1 hands the phone to player 2, who turns it any way while taking it and then holds it still toward the TV. Check: after 1 s of holding still, the dotted line points at the cup (the first line is within 6 degrees of the cup, 5 of 5 hand-overs), and a turn of 20 degrees to the right then moves it about 20 degrees clockwise (5 of 5). (REQ-MG-4)
16b4. (Added 2026-11-06, owner feedback.) A person who has never played reads the phone when it is their turn and swings. Check: the phone shows the line "YOUR TURN: AIM, THEN SWING BACK AND FORWARD LIKE A PUTTER!" (shown at 3 of 3 turns on 1 phone), and the person putts within 30 s of the banner without help (3 of 3 people). (REQ-MG-20)
16c. On hole 1 putt 5 soft, 5 medium and 5 hard swings. Measure how far each ball rolls (a photo of the end place, or the number of lawn tiles). Check: the median distance of the soft putts is smaller than the median of the medium putts, and that is smaller than the median of the hard putts (2 of 2 comparisons). (REQ-MG-5)
16d. Move only the hand a little (about 5 cm) in the swing place, 5 times, with no real backswing. Then make one real swing. Check: no stroke is counted in the 5 small moves (0 of 5), the ball does not move, and the real swing is counted (1 of 1). (REQ-MG-5)
16e. Play one hole on Easy, one on Medium and one on Hard and look at the aim phase. Check: Easy shows a long aim line; Medium shows a short aim line; no text instruction shows on any of them; Hard shows no aim line, only a small marker on the ground (3 of 3 difficulties as written). Then on Easy and on Medium make the weakest swing that still counts as a putt, 5 times each. Check: the median distance of the 5 Easy putts is larger than the median of the 5 Medium putts. (REQ-MG-13)
16f. Record the golfer with the phone camera (240 fps) for 3 putts. Check: in each of 3 putts you see these phases in this order: address, backswing, downswing, hit, follow-through (3 of 3), and the putter has a dark grip, a steel shaft and a steel head with a gold top line (3 of 3 parts seen). (REQ-MG-16)
16g. Hold a phone and putt 5 soft and 5 strong putts. A second person watches. Then you putt 5 pairs (one soft and one strong, in a random order) with your eyes closed, and say which buzz of the pair was longer. Check: the phone buzzes at the hit in 10 of 10 putts, and you name the longer buzz (the strong putt, 60 ms against 30 ms) right in 4 of 5 pairs. (REQ-MG-16)
16h. (Added 2026-11-01, issue #209.) Medium. Move the phone 40 cm to the side in about 0.4 s, 10 times, then shake it slowly (2 to 5 Hz) for 2 s, 5 times, then shake it as hard as you can (about 3 Hz) for 2 s, 5 times, then walk 20 steps with the phone in your hand. Check: the stroke count stays 0 (0 of 10 moves, 0 of 5 slow shakes, 0 of 5 hard shakes and 0 of the walk make a putt; the hard shake was added on 2026-11-06, the shake rule `MAX_REVERSALS` is a first guess). Do it again on Easy.
16i. (Added 2026-11-01, issue #209.) Medium. Putt 10 soft putts, a real slow pendulum swing as for a short putt. Check: at least 9 of 10 roll the ball, and none rolls at the stop of the back swing. Write down the misses and how you held the phone. The speed rule (`GATE_SPEED` 0.5 m/s) is a first guess and a soft putt can be dropped by it: if more than 1 of 10 is dropped, report it (issue #142).

16j. (Added 2026-11-03.) Medium. Put the ball close to the cup (about 5 ball widths away) and putt it with the lightest swing you can make that is still a swing (a back swing of about 5 cm and a forward swing of about 5 cm), 10 times. Check: at least 9 of 10 light swings roll the ball (the plate "SWING A BIT MORE!" does not show and each swing of the golfer is followed by a rolling ball), and the ball stops less than a fifth of the screen width from where it started in at least 8 of 10 (the putt is a light one). Then repeat 16h's 10 moves to the side: 0 of 10 make a putt. (REQ-MG-5)
16k. (Added 2026-11-05.) Medium, hole 3 (press 3 on the TV keyboard: temporary). Stand so that you can see the TV and hold the phone as you like, still, at the start of your turn, 5 turns in a row, one after the other. Check: at the start of each turn the dotted line points at the cup (5 of 5 turns) with no turn of the phone. Hit the ball and, on your next turn, hold the phone as you hold it after the hit, without moving it. Check: the dotted line points at the cup again and the putt goes toward the cup (5 of 5 turns); you never turn round or move your feet to hit in the direction of the cup (5 of 5). Turn the phone 30 degrees to the right. Check: the dotted line turns clockwise by about the same angle (within 10 degrees, 5 of 5). (REQ-MG-4)

Items 1a, 2a, 2c, 3a, 3c, 3d, 4a, 4b, 4c, 4d, 5a, 5b, 5c, 5d, 6a to 6c, 7a to 7c, 7d, 7e, 7f, 8a, 8b, 8c, 8d, 8e, 8f, 9a to 9d, 10a to 10d, 11a to 11c moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-26-1a to A-26-11c). Item 3b was split: the shirt color is automated and 3b2 keeps the white cap, trousers and shoes. The numbers of the other items do not change.

Measurements (write down, no pass or fail): the turn angle that moves the aim mark from the middle to the side end; the delay from the swing to the ball moving; if a normal putt goes too far or too short; any hole that you find too hard or too easy; the time of a 3 hole match. Use them to tune the aim range, the putt speeds and the hole designs.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b | Photo of the tile next to a photo of the game | Pass | R9 |  | R9: Pass |
| 3b2 | Photo of the golfer | Pass | R9 |  | R9: Pass |
| 5e | Video (240 fps); note: frames and ms for 5 putts | Pass | R9 |  | R9: Pass |
| 12a | Note: the child, the age, seconds until it points | Pass | R9 |  | R9: Pass |
| 12b | Note: seconds until the mark moves | Pass | R9 |  | R9: Pass |
| 12c | Note: seconds until the first stroke | Pass | R9 |  | R9: Pass |
| 12d | Note: the answer of the child | Pass | R9 |  | R9: Pass |
| 14a | Note: right answers of 5; photo of the ball with its height in px | Pass | R9 |  | R9: Pass |
| 14b | Note: answers of each tester | Pass | R9 |  | R9: Pass |
| 14c | Note: errors made when reading | Pass | R9 |  | R9: Pass |
| 15a | Photo of the TV and of both phones | Pass | R9 |  | R9: Pass |
| 16a | Video of the aim mark; note: turns that moved it the right way (of 10), tilts (of 5) | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 16b | Video of 5 putts; note: putts with a locked mark (of 5), marks that moved again after the stop (of 5) | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 16b2 | Video; note: lines that stayed after A (of 5), followed again (of 5), snapped and green (of 5), white at 15 degrees (of 5) | Pass | R9 |  | R9: Pass Added 2026-11-03 (A locks the aim, snap to the cup). |
| 16b3 | Video; note: hand-overs where the line points at the cup (of 5), turns of 20 degrees that moved it about 20 degrees (of 5) | Pass | R9 |  | R9: Pass Added 2026-11-06 (owner feedback: the direction is lost when the phone changes hands). |
| 16b4 | Photo of the phone; note: people who putted within 30 s (of 3) | Pass | R9 |  | R9: Pass Added 2026-11-06 (owner feedback: testers did not know what to do with the phone). |
| 16c | Note: the 15 distances and the 3 medians | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 16d | Note: strokes counted in 5 small moves; the stroke of the real swing | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 16e | Photos of the aim phase on the 3 difficulties; note: the 10 distances | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 16f | Video (240 fps) of 3 putts; note: phases seen per putt | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). 2026-11-17: the A button was removed (owner); the step text now checks that the pad has no button. |
| 16g | Note: putts with a buzz (of 10); pairs answered right (of 5) | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 16h | Note: strokes after the moves, the shakes and the walk, on Medium and on Easy | Pass | R9 |  | R9: Pass Added 2026-11-01 (issue #209). |
| 16i | Note: soft putts that rolled (of 10) and the misses | Pass | R9 |  | R9: Pass Added 2026-11-01 (issue #209). |
| 16j | Note: light putts that rolled (of 10), distances, and the 10 moves to the side | Pass | R9 |  | R9: Pass Added 2026-11-03 (light swings). |
| 16k | Note: lines at the cup at the start of the turn (of 5), the putts toward the cup after a hit (of 5), moves of the feet needed (0), the angle for 30 degrees | Pass | R9 |  | R9: Pass Added 2026-11-05 (the straight ahead of the phone is the cup). |

History:
- 2026-11-10 (step removed): Owner decision of 2026-11-10 (issue #440, the owner answered: remove them; the owner has 1 Android phone and no TV box). The FPS step on the TV box (step 13) is removed: nobody can do it now. The cost of a frame with 4 phones on Hard stays automated (`frame_cost`, A-26-13, issue #132); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device). REQ-GM-50 is dropped from the Covers line of this test.

- 2026-10-21 (decision of the owner, REQ-GM-35): Mini Golf has no timer, so it has no countdown: the first turn starts at once after Start, with the turn banner and the turn buzz. Step 12a says "after Start" (not run). No recorded result changed.
- 2026-10-21 (automated): 11 steps moved to the automated tests (`r4_golf`). Step 3b was split (3b2). `r4_golf` is red today on one known bug: the ball starts to move at swing age 0, while the club reaches it at 0.12 s (step 5b).
- -: **Not run**. New (2026-10-17).
- 2026-10-21 (aligned with the requirements, not run): step 14a also checks the ball height of 48 px or more (REQ-GM-47e). No recorded result changed.
- 2026-11-03 (the redesign of the view, owner decision, `docs/MINI_GOLF_REDESIGN.md` option A; nothing in this test had a recorded result): the course is seen from above with one scale per hole and only the ball on turn is drawn, white (changed again later the same day: it was first all balls in rings of the slot colors). Steps 1b and 2b describe the new look, 14a asks for hole 5 (the ball has one size on every hole now) and steps 14d and 14e are new (Not run). The steps of the aim, the power and the rules did not change.

History:

- 2026-11-17 (steps removed, where each is covered; owner decision of 2026-11-17, issue #457): step 2b (hole 3 with 4 phones: the walls, the tee mat, the cup with its flag, the clubhouse, the hot air balloon and the trees, and one ball for each of the 4 phones; it was Not run, and the one ball for each phone is old text: only the ball on turn is drawn since 2026-11-03) is covered by A-26-2b (`golf_view`: every hole has room for the clubhouse, the balloon and scenery that is on neither the course nor the HUD; REQ-MG-18, 19). Step 14d (4 phones: a tester points at the white ball at the start of each turn on holes 1, 3 and 5 and names the player on turn by the golfer's shirt, no flashing border; it was Not run) is covered by A-26-14d (`golf_view`: only the white ball of the player on turn is drawn, with no ring and no halo; `r4_golf`: the shirt of the golfer has the color of the phone on turn, A-26-3b). Step 14e (4 phones, 5 holes: the tee, the cup and the whole course on the screen under the bar and over the chips, the ball 32 px, no banner plate on the cup; it was Not run) is covered by A-26-14e (`golf_view`: the course of each of the 5 holes is inside x 60 to 1860 and y 112 to the chips, with 1 and 2 rows of chips; the ball is 32 px and the cup wider; the plate covers neither the cup nor the ball nor the golfer). What is not verified by anything now: that a tester finds the white ball and names the golfer's shirt from 3 m on a real TV with 4 phones, and the photo of a real screen. Step 16b4 (a person who never played reads the phone when it is their turn: 3 of 3 phones on turn, 3 of 3 people) needs 1 phone (3 people in turn) and stays. The Needs line says 1 to 2 phones.
- 2026-11-17 (recorded; R9 in the tracker): Pass: steps 1b, 3b2, 5e, 12a, 12b, 12c, 12d, 14a, 14b, 14c, 15a, 16a, 16b, 16b2, 16b3, 16b4, 16c, 16d, 16e, 16f, 16g, 16h, 16i, 16j, 16k. Steps 2b, 14d and 14e (4 phones) were marked N/A by the owner and are removed (issue #457).

## Test 27

### Air Hockey (tilt, enroll with A, ROBO the bot)

Needs: 1 to 2 phones, 1 TV with its remote, a stopwatch, a phone camera (240 fps for item 3b), and a child of about 5 to 8 years for item 9. Covers: REQ-AH-* (`docs/games/air_hockey.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-105, REQ-GM-106, REQ-GM-47i to 47n.

New game (2026-10-23), and the first game with a computer player. It was tested only with made-up sensor values. Every number (the mallet speed, the puck friction and hit speed, the goal size, the three levels of ROBO) is a first guess; write what you measure in the Notes. Hold each phone flat like a tray. "Full tilt" means the phone is tilted about 45 degrees.

**Steps**

1a. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the white table, the dark gray rails, the mallets and the black puck.
3a. From the sofa (about 3 m), look at the puck while it is in front of the right goal and the left goal (hit it there, or wait). Check: the tester points at the puck within 1 second in 5 of 5 tries (issue #227, REQ-AH-20; the light ring and its contrast are checked by A-27-puck).
3b. Record a phone and the TV (240 fps) for 5 quick tilts. Count the frames from the start of the tilt to the first move of the mallet. Check: the median delay is 150 ms or less (36 frames at 240 fps). (REQ-GM-12)
6b. Set Difficulty to Easy and goals to 5. A grown-up plays 5 matches. Check: the grown-up wins 5 of 5. Write down the goals ROBO scored in each match. (REQ-AH-17, REQ-GM-96)
6c. Set Difficulty to Hard and goals to 5. A grown-up plays 3 matches. Check: ROBO scores 2 goals or more in each of the 3 matches. Write down who won each match. (REQ-AH-17)
9a. Let a child of about 5 to 8 years play on Easy, with a grown-up next to them who does not help. The grown-up reads the hint line once and says nothing more. Check: the child points at its own mallet (the one in the color of its phone) within 10 s after the match starts. Write down the age. (REQ-GM-80 to 84)
9b. Same child. Check: the child hits the puck with its mallet at least once within 60 s, with no help. (REQ-AH-17)
9c. Same child. Check: the child scores at least 1 goal in a match of 3 goals (yes or no), and the child plays to the end without asking to stop or crying (yes or no). (REQ-AH-17, REQ-GM-96)
9d. After the match, ask: "Play again?". Check: the child says yes (1 of 1 children asked).
11a. **Pixel world (REQ-GM-47i to 47n).** From 3 m, a tester points at the puck each time you say "mark" while it moves. Check: the finger points at the puck in 5 of 5 tries. Check: the puck is 48 px or more high on the screen at 1080p (photo with a ruler on a 1080p TV: 68 px expected). (REQ-GM-47e, REQ-AH-20)
11b. From 3 m, ask a tester to tell the puck from the red and blue lines of the table and from the dark gray rails and the black floor: the tester points at the puck and then at the red middle line. Check: both answers are right for each of 3 testers (3 of 3 testers). (REQ-AH-20)
11c. From 3 m, read aloud the two chips, "FIRST TO N" and one goal banner. Check: no error when reading. (REQ-AH-21, REQ-FL-40)
11d. **Black floor (2026-10-29, issue #123, REQ-AH-20).** From 3 m, a tester points at the left goal opening, the top rail and the floor outside the table. Check: the tester points at all 3 right (3 of 3), and the black puck is seen at every moment it is over a rail (yes or no). (REQ-AH-20)
12. Set the TV language to Hebrew and start a match. Check: the left player's goal is still on the left (the table is not mirrored), the title and "FIRST TO N" are mirrored to the right side, and no text is cut (3 of 3). A person who reads Hebrew also checks the words: "הוקי אוויר", "רובו", "שער של ...!". (REQ-AH-21, REQ-GM-47o)

Items 2a, 2b, 2c, 3a, 3c, 4a, 4b, 4c, 4d, 5a, 6a, 6d, 7a, 7b, 8a, 8b and 13 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-27-*). The numbers of the other items do not change.

Measurements (write down, no pass or fail): the time for a mallet to cross its half at full tilt; the speed of a hard hit (how long the puck needs from one end to the other); the goals ROBO scores on Easy, Medium and Hard against a grown-up; if Medium feels too easy or too hard for a grown-up and for a child; the goal size (too wide or too narrow); the time the puck waits after a goal.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the tile next to a photo of the game | Not run | | | |
| 3a | Note: the tries in which the tester pointed at the puck within 1 s (of 5); photo of the screen | Pass | R9 |  | R9: Pass Row added 2026-10-31 (issue #303); step added for issue #227. |
| 3b | Video (240 fps); note: frames and ms for 5 tilts | Pass | R6 |  | R6: Pass |
| 6b | Note: the winner and the goals of ROBO in each of 5 matches | Pass | R9 |  | R9: Pass R6 (2026-10-27) was Fail, before the fix of issues #146 and #147 (commit b2b9ca5, 2026-10-27): "1. the player scored 1 goal and then robo scored 4 own goals 2. robo sometimes moves away from the puck allowing the player to score a goal". Not run again on the current build. Issue #431 was filed from this row by mistake and closed as a duplicate on 2026-11-12. Machine half: A-27-6b. |
| 6c | Note: the goals of ROBO and the winner in each of 3 matches | Pass | R6 |  | R6: Pass |
| 9a | Note: the child, the age, seconds until it points | Pass | R6 |  | R6: Pass |
| 9b | Note: seconds until the first hit | Pass | R6 |  | R6: Pass |
| 9c | Note: goals of the child; yes or no for crying or stopping | Pass | R6 |  | R6: Pass |
| 9d | Note: the answer of the child | Pass | R6 |  | R6: Pass |
| 11a | Note: right answers of 5; photo of the puck with its height in px | Pass | R6 |  | R6: Pass |
| 11b | Note: answers of each tester | Not run | | | |
| 11c | Note: errors made when reading | Pass | R6 |  | R6: Pass |
| 11d | Note: the answers of the tester; photo of the table from 3 m | Pass | R9 |  | R9: Pass Added 2026-10-29 (issue #123). The rails are dark gray `#4a4e5e` (a first guess) on the black floor. |
| 12 | Photo of the TV in Hebrew; note: words that a reader changed | Pass | R6 |  | R6: Pass |

History:

- 2026-11-17 (recorded; R9 in the tracker): Pass: steps 3a, 6b, 11d.
- 2026-11-10 (steps removed): Owner request of 2026-11-10 (tracker and chat: "Tests 14, 23, 27, 28 and 31 still have steps that either need to be removed or automated"; the owner has 1 Android phone and no TV box). The FPS step on the TV box is removed: nobody can do it now. The cost of a frame with 4 phones on Hard stays automated (`frame_cost`, A-27-10); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device). Step 11e (2 phones, after the screen scaling of issue #348) is the new A-27-11e: `smoke_air_hockey` checks at 1280x720, 1920x1080 and 1600x1200 that the left chip starts at the left goal and the right chip ends at the right goal, both on the screen, and the top rail is under the bar (REQ-AH-23). What is not verified by anything now: the photo of the real TV box against the photo of step 11a (each edge within 10 px).
- 2026-11-10 (recorded; R6 in the tracker): Pass: steps 3b, 6c, 9a, 9b, 9c, 9d, 11a, 11c, 12. Step 6b: Fail before the fix of #146 and #147 (see the row; it is Not run for the current build). The N/A of step 10 (4 phones) is not recorded: the step is 1 phone on the TV box now (A-27-10). Steps 1a and 11b passed on the old text (black rails); they stay Not run because the step says dark gray rails now.
- 2026-10-24 (automated): steps 2a, 2b, 2c, 3a, 3c, 4a, 4b, 4c, 4d, 5a, 6a, 6d, 7a, 7b, 8a, 8b, 13 moved to the automated tests (smoke_air_hockey, air_hockey_rules). Nothing was run on a device, so no result moved.
- -: **Not run**. New (2026-10-23). The headless checks of the rules, the bot and the screens are in `air_hockey_rules` and `smoke_air_hockey` (`docs/AUTOMATED_TESTS.md`); this test holds what needs a person, a phone or a TV.

## Test 28

### Mole Bonk (pointer, bonk, moles, difficulty)

Needs: 1 to 2 phones, 1 TV, a 240 fps phone camera (item 4b), and a child of about 5 to 8 years for items 10a to 10d. Covers: REQ-WM-* (`docs/games/whack_a_mole.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-23). It was only tested with made-up sensor values. Every number (the stay of a mole, the time between moles, the size of the hit circle, the 9 places of the holes, the points) is a first guess, but each step below has a fixed limit. Hold the phone like a remote control and point it at the TV. "From 3 m" means: sit or stand 3 m from the TV. Play on Medium unless the step says another difficulty.

**Steps**

1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the meadow, the fence, a hole and a mole.
2b. Look at the game screen. Check: you can point at all of these: the sky, the fence, the lawn, the 9 holes (9 of 9) and a mole.
4b. Record the phone (the A button) and the TV (240 fps) for 5 bonks on a mole. Count the frames from the press on A to the first change of the mole (closed eyes). Check: the median delay is 150 ms or less (36 frames at 240 fps).
8a. Open the settings view of the game (OK on its tile). Check: the TV shows the line "POINT YOUR PHONE AT THE SCREEN AND PRESS A TO BONK THE FRIENDLY MOLES. MOST POINTS IN 60 S WINS." and the rows Difficulty and Start. The phone pad shows A and RECENTER only (3 of 3). (REQ-GM-37a)
10a. Let a child of about 5 to 8 years play on Easy, with a grown-up next to them who does not help. Check: the child puts the ring on a mole within 20 s after GO, with no help.
10b. Same child. Check: the child bonks a mole (the score grows) within 30 s after GO.
10c. Same child. Check: the child has 5 or more bonks on moles in the 60 s round.
10d. After the round, ask: "Play again?". Check: the child says yes (1 of 1 children asked).
12a. **Pixel world (REQ-GM-47i to 47n).** From 3 m, a tester points at the golden mole when you say "mark". Check: the tester finds it in 5 of 5 tries. Check: a mole is 48 px or more high on the screen at 1080p (photo). (REQ-GM-47e)
12b. From 3 m, ask a tester to read aloud the points that float up from a hit mole and the timer. Check: no error.
13b. Let a child of 5 to 8 years play a round on Easy. Measure the ring of a mole in a photo of the 1080p TV with a ruler. Check: the mole circle is 168 px (160 px to 176 px). Check: the child plays to the end of the round without asking to stop (yes or no), the score does not go down after 5 misses (0 of 5 drops), and none of the texts on the screen (hint, banner, result) has the words LOSE, WRONG, FAIL or BAD (0 of 3 texts). (REQ-WM-14)

Items 3a, 4a, 5a, 6a, 6b, 6c, 7a, 7b, 9a and 9b moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-28-*). The numbers of the other items do not change.

Measurements (write down, no pass or fail): the turn angle that moves the ring from the middle to the edge; how often a bonk misses a mole that you aim at; if a mole is out too long or too short on each difficulty; the number of bonks of a good player in a round. Use them to tune the stay, the spawn time and the hit circle.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b | Photo of the tile next to a photo of the game | Pass | R6 |  | R6: Pass |
| 2b | Note: right answers of 9 holes and 4 other objects | Pass | R6 |  | R6: Pass |
| 4b | Video (240 fps); note: frames and ms for 5 bonks | Pass | R6 |  | R6: Pass |
| 8a | Photo of the settings view | Pass | R6 |  | R6: Pass |
| 10a | Note: the child, the age, seconds until the ring is on a mole | Pass | R6 |  | R6: Pass |
| 10b | Note: seconds until the first bonk | Pass | R6 |  | R6: Pass |
| 10c | Note: bonks on moles in the round | Pass | R6 |  | R6: Pass |
| 10d | Note: the answer of the child | Pass | R6 |  | R6: Pass |
| 12a | Note: right answers of 5; photo of a mole with its height in px | Pass | R6 |  | R6: Pass |
| 12b | Note: errors made when reading | Pass | R6 |  | R6: Pass |
| 13b | Note: the child, the age; the ring in px; the 3 checks | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |

History:

- 2026-11-17 (recorded; R9 in the tracker): Pass: steps 13b.
- 2026-11-10 (steps removed): Owner request of 2026-11-10 (tracker and chat: "Tests 14, 23, 27, 28 and 31 still have steps that either need to be removed or automated"; the owner has 1 Android phone and no TV box). The FPS step on the TV box is removed: nobody can do it now. The cost of a frame with 4 phones on Hard stays automated (`frame_cost`, A-28-11); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device). Step 13a (2 phones) is the new A-28-13a: `audio_events` (Mole Bonk) checks that a hit buzzes 40 ms and a miss 15 ms on the phone of the player only, that a winner alone buzzes 400 ms, and that the sounds `mole_hit`, `mole_points` (a pitch for each player) and `mole_miss` play; GO buzzes both phones in `multi_phone`; the song starts in A-18-5. What is not verified by anything now: that a person feels 40 ms as longer than 15 ms with the eyes closed (REQ-WM-12, felt buzz) and that the sounds are heard on a real TV.
- 2026-11-10 (recorded; R6 in the tracker): Pass: steps 1b, 2b, 4b, 8a, 10a, 10b, 10c, 10d, 12a, 12b. R6: the N/A of step 11 (4 phones) is not recorded: the step is 1 phone on the TV box now (A-28-11).
- 2026-10-24 (automated): steps 3a, 4a, 5a, 6a, 6b, 6c, 7a, 7b, 9a, 9b moved to the automated tests (smoke_mole, mole_rules). Nothing was run on a device, so no result moved.


## Test 29

### Sheep Herding (tilt, a team herds the sheep into the pen)

Needs: 1 to 2 phones, 1 TV, a stopwatch, and a child of about 5 to 8 years for items 8a to 8d. Covers: REQ-SH-* (`docs/games/sheep_herding.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-23). It was only tested with made-up sensor values. Every number (the speed of the dogs, how far a dog scares a sheep, how fast a sheep runs, the gate, the time of the round, the pictures, the song and the Hebrew texts) is a first guess, but each step below has a fixed limit. "From 3 m" means: sit or stand 3 m from the TV. The sheep and the dogs run by themselves, so do not count on the same round twice.

**Steps**

1. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the sheep, a dog, the pen with its fence, and the barn.
2a. From 3 m, a tester points at the gate of the pen. Check: the finger points at the gap in the left fence (5 of 5 testers).
4. Play alone on Easy, an adult. Check: the adult herds all 8 sheep into the pen in 90 s or less, in 2 of 3 rounds.
6a. Play with 2 phones on Medium, 2 adults, who talk to each other. Check: the 2 adults herd all 11 sheep into the pen in 75 s or less, in 2 of 3 rounds.
8a. Let a child of about 5 to 8 years play on Easy, with a grown-up next to them who does not help. Check: the child points at its own dog (the one in the color of its phone) within 10 s after GO.
8b. Same child. Check: the child moves its dog next to a sheep and the sheep runs away, within 30 s after GO, with no help.
8c. Same child. Check: at least 1 sheep is in the pen at the end of the round, with no help.
8d. After the round, ask: "Play again?". Check: the child says yes (1 of 1 children asked).
9a. Open the settings view and read the how-to line under the name, then play 1 round. Check: a tester can tell what to do (tilt the phone, bring all the sheep into the pen) without more help (3 of 3 testers).
9b. A native reader of Hebrew reads the 7 new texts of the game (the 7 rows of `assets/lang/strings.csv` that start with `sheep_herding.`, `registry.sheep_herding`, `registry.desc_sheep_herding` and `how_to.sheep_herding`) on the TV set to Hebrew. Check: the reader marks 0 texts as wrong and 0 texts as cut.
10a. Tilt the phone 15 degrees to one side and hold it for 5 s; record the TV with the phone camera (60 fps or more). Check: the dog crosses the full width of the screen (1920 px) in 4.3 s or more in each of 3 tries (the speed limit is 440 px/s), and with the phone laid flat and still for 10 s the dog moves less than one dog length (80 px). (REQ-SH-11)
10b. Tilt the phone flat after a hold of 3 s, and tilt the dog into each of the 4 edges for 3 s. Check: the dog stops within 2 s after the phone is flat (3 of 3 tries), and the dog stays fully inside the field at each edge and comes back softly (4 of 4 edges). (REQ-SH-11)
10c. With 2 phones, drive the two dogs into each other 5 times. Check: each touch plays one sound only (5 of 5 touches, no double sound) and the dogs move apart without a jump (5 of 5). (REQ-SH-11)
10d. Play a round with 2 phones and hold both phones. Check: both phones buzz at GO, and a tester with a phone in the hand says that the GO buzz is shorter than the buzz at the end of a round in which all sheep are in (2 of 2 phones, 60 ms against 400 ms). (REQ-SH-12)
10e. Herd 5 sheep into the pen one after another with dog A (the phone of A in your hand, the phone of B on the table). Check: the phone of A buzzes shortly for each sheep that walks in (5 of 5 sheep) and the phone of B does not buzz for them (0 of 5). (REQ-SH-12)
10f. Play a round with 2 phones. Turn the Wi-Fi of one phone off and note the time on the TV. Check: the card of a lost phone shows within 5 s, the time of the round changes by 1 s or less in the next 10 s, and after the Wi-Fi is on again and Resume is chosen the round goes on (3 of 3). Look at the pad of both phones: no RECENTER box and no A or B (2 of 2 phones). (REQ-SH-14, REQ-GM-30)
10g. Hold the phone tilted 15 degrees to the right during the countdown and keep that angle for 5 s after GO. Check: the dog moves less than one dog length (80 px) in the 5 s after GO (2 of 2 tries). (REQ-SH-14)
10h. From 3 m, a tester points at: a dog, a sheep, the pen, the gate posts and the path of sand dots to the gate. Check: 5 of 5 right for each of 3 testers (3 of 3 testers). Then you make one sheep calm and one run. Check: the tester says which sheep is running (the one with three speed dashes) in 5 of 5 tries. Read aloud the timer and the title: no error. (REQ-SH-15)

Items 2b, 3a, 3b, 5a, 5b and 6b moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-29-*). The numbers of the other items do not change.

Measurements (write down, no pass or fail): the time that a dog needs from the left edge to the gate with a steady tilt; the speed of the sheep that you see (too slow, too fast); if a sheep gets stuck in a corner, behind a tree, at the pond or at the fence; the time that a round of 1 child takes on Easy; how many sheep an adult herds alone on Hard in 60 s. Use them to tune the speed of the dogs, how far they scare a sheep, the gate and the time of a round.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the tile next to a photo of the game | Not run | | | |
| 2a | Note: right answers of 5 | Not run | | | |
| 4 | Note: sheep and seconds in each of 3 rounds | Not run | | | |
| 6a | Note: sheep and seconds in each of 3 rounds | Not run | | | |
| 8a | Note: the child, the age, seconds until it points | Not run | | | |
| 8b | Note: seconds until the sheep runs | Not run | | | |
| 8c | Note: sheep in the pen | Not run | | | |
| 8d | Note: the answer of the child | Not run | | | |
| 9a | Note: answers of each tester | Not run | | | |
| 9b | Note: the texts that the reader marks, with the reason | Not run | | | |
| 10a | Video; note: the 3 crossing times; the movement in 10 s | Not run | | | Added 2026-10-31 (issue #306). |
| 10b | Video; note: stop times (3), edges (of 4) | Not run | | | Added 2026-10-31 (issue #306). |
| 10c | Note: touches with one sound (of 5) | Not run | | | Added 2026-10-31 (issue #306). |
| 10d | Note: phones that buzzed at GO (of 2); phones that felt a longer final buzz (of 2) | Not run | | | Added 2026-10-31 (issue #306). |
| 10e | Note: buzzes of phone A (of 5), buzzes of phone B (of 5) | Not run | | | Added 2026-10-31 (issue #306). |
| 10f | Photo of the card; note: the time before and 10 s after; photo of the pad | Not run | | | Added 2026-10-31 (issue #306). |
| 10g | Video; note: the movement in px | Not run | | | Added 2026-10-31 (issue #306). |
| 10h | Note: answers of each tester; errors in reading | Not run | | | Added 2026-10-31 (issue #306). |

History:
- 2026-11-10 (step removed): Owner decision of 2026-11-10 (issue #440, the owner answered: remove them; the owner has 1 Android phone and no TV box). The FPS step on the TV box (step 7) is removed: nobody can do it now. The cost of a frame with 4 phones on Hard stays automated (`frame_cost`, A-29-7, issue #132); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device). REQ-GM-50 is dropped from the Covers line of this test.

- 2026-10-24 (automated): steps 2b, 3a, 3b, 5a, 5b, 6b moved to the automated tests (smoke_sheep, sheep_rules). Nothing was run on a device, so no result moved.
- -: **Not run**. New (2026-10-23).

## Test 30

### Tower Builder (turns, swing, drop, wobble, 12 bricks)

Needs: 1 to 2 phones, 1 TV with its remote, a stopwatch, and a child of about 5 to 8 years for item 9. Covers: REQ-TB-* (`docs/games/tower_builder.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-47i to 47n.

New game (2026-10-23). It was tested only with made-up button presses. Every number (the swing, the 12 bricks, the widths of the bricks, the 24 px of overlap, the 8 px of slack, the turn times) is a first guess; write what you measure in the Notes.

**Steps**

1a. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the sky with the sun, the mountains, the tower of colored bricks and the crane.
8a. In a game with 2 phones, turn off Wi-Fi on one phone. Check: within 6 s the TV pauses with the card "<NAME> LOST CONNECTION"; the brick stops swinging and the timer box does not change. Turn Wi-Fi on again and press Resume. Check: the game goes on (3 of 3). (REQ-TB-12, REQ-GM-30)
9a. Let a child of about 5 to 8 years play on Easy, with a grown-up next to them who does not help. The grown-up reads the hint line once and says nothing more. Check: the child presses A of its own phone, when it is its turn, within 20 s of the plate with its name. Write down the age. (REQ-GM-80 to 84)
9b. Same child. Check: the child drops at least 2 bricks that stay in a game of 12 bricks (yes or no). (REQ-TB-11, REQ-GM-96)
9c. Same child. Check: the child plays to the end without asking to stop or crying (yes or no), also after a topple (yes or no). (REQ-GM-83)
9d. After the game, ask: "Play again?". Check: the child says yes (1 of 1 children asked).
11a. **Pixel world (REQ-GM-47i to 47n).** From 3 m, a tester reads the plate "<NAME>'S TURN", "BRICK n OF 12" and one banner aloud. Check: no error when reading. (REQ-TB-19, REQ-FL-40)
11b. From 3 m, a tester points at the brick that hangs on the crane and at the top brick of the tower. Check: both answers are right for each of 3 testers (3 of 3 testers), and the brick is 48 px or more high on the screen at 1080p (photo with a ruler on a 1080p TV: 48 px expected). (REQ-GM-47e, REQ-TB-18)
12. Set the TV language to Hebrew and start a game. Check: the title and the plates are mirrored to the right side, the tower and the crane are not mirrored, and no text is cut (3 of 3). A person who reads Hebrew also checks the words: "בונים מגדל", "התור של ...", "קראש! חיחי!". (REQ-GM-47o, REQ-TB-19)
13a. Record 10 drops with the camera at 60 fps or more. In the frame after each landing measure, in a photo of the 1080p TV, how far the middle of the new brick is beyond the edge of the brick below. Check: no brick that stays is more than 8 world pixels (32 px at 1080p) beyond the edge, no brick that is further out stays (0 of 10), and at least 1 brick that stays is between 1 and 8 world pixels beyond the edge. (REQ-TB-8)
13b. Play a round with 2 phones. Check: the phone whose turn starts buzzes (5 of 5 turns) and the other phone does not (0 of 5). A drop buzzes the phone shortly (5 of 5), a brick that stays buzzes it longer than the drop (4 of 5 pairs named right with the eyes closed: 60 ms against 30 ms), a miss buzzes it (3 of 3), and a topple buzzes both phones (2 of 2). (REQ-TB-13)
13c. Use a stopwatch on Easy, Medium and Hard and let a turn run to the end without a drop. Check: the timer box starts at 10 s on Easy, 5 s on Medium and 3 s on Hard, and the crane drops by itself at that time plus or minus 1 s (3 of 3 difficulties). On Easy time the crane for 5 swings from one end and back. Check: one swing takes 2.4 s (2.2 s to 2.6 s) in each of 3 measures. A child of the steps 9a to 9d plays a round on Easy. Check: the answers to those steps are written (REQ-TB-16, REQ-GM-80 to 84).
13d. **Re-look after the screen scaling (2026-11-01, issue #348, REQ-TB-22).** The layout now comes from the window size; at 1920x1080 nothing moved. On the TV box, start a game with 2 phones. Check: both chips are fully visible under the base (2 of 2) and the plates "<NAME>'S TURN" and "BRICK n OF 12" are at the left of the tower; the crane arm is visible under the black bar (yes or no). Check: the sky, the tower, the chips and the plates are at the same places as in the photo of step 1a (compare the photos: each edge within 10 px at 1080p). (REQ-TB-22, REQ-2D-2)

Items 2a, 2b, 3a, 3b, 3c, 3d, 4a, 4b, 4c, 5a, 5b, 6a, 6b, 7a, 8b and 13 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-30-*). The numbers of the other items do not change.

Measurements (write down, no pass or fail): the time for one drop that people really need; how many bricks 4 players stack on Easy, Medium and Hard; if the topple feels fair (a tower that leans too far falls, a tower that is nearly straight stays); if 12 bricks are too short or too long; how long the wait with 4 players feels.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the tile next to a photo of the game | Pass | R9 |  | R9: Pass |
| 8a | Note: seconds until the card shows; photo of the card | Pass | R9 |  | R9: Pass |
| 9a | Note: the child, the age, seconds until it presses A | Pass | R9 |  | R9: Pass |
| 9b | Note: bricks that stayed | Pass | R9 |  | R9: Pass |
| 9c | Note: yes or no for crying or stopping, also after a topple | Pass | R9 |  | R9: Pass |
| 9d | Note: the answer of the child | Pass | R9 |  | R9: Pass |
| 11a | Note: errors made when reading | Pass | R9 |  | R9: Pass |
| 11b | Note: answers of each tester; photo of the brick with its height in px | Pass | R9 |  | R9: Pass |
| 12 | Photo of the TV in Hebrew; note: words that a reader changed | Pass | R9 |  | R9: Pass |
| 13a | Frames with the measure; note: each of the 10 offsets and the result (stays or not) | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 13b | Note: the buzzes of each kind | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 13c | Note: the 3 times; the 3 swing times; the child's steps | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 13d | Photo of the screen next to the photo of 1a; note: yes or no for each check | Pass | R9 |  | R9: Pass Added 2026-11-01 (issue #348). |

History:
- 2026-11-10 (step removed): Owner decision of 2026-11-10 (issue #440, the owner answered: remove them; the owner has 1 Android phone and no TV box). The FPS step on the TV box (step 10) is removed: nobody can do it now. The cost of a frame with 4 phones on Hard stays automated (`frame_cost`, A-30-10, issue #132); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device). REQ-GM-50 is dropped from the Covers line of this test.

- 2026-10-24 (automated): steps 2a, 2b, 3a, 3b, 3c, 3d, 4a, 4b, 4c, 5a, 5b, 6a, 6b, 7a, 8b, 13 moved to the automated tests (smoke_tower, tower_rules). Nothing was run on a device, so no result moved.
- -: **Not run**. New (2026-10-23). The headless checks of the rules and the screens are in `tower_rules` and `smoke_tower` (`docs/AUTOMATED_TESTS.md`); this test holds what needs a person, a phone or a TV.

History:

- 2026-11-17 (recorded; R9 in the tracker): Pass: steps 1a, 8a, 9a, 9b, 9c, 9d, 11a, 11b, 12, 13a, 13b, 13c, 13d.

## Test 31

### Freeze Dance (wiggle, freeze, difficulty)

Needs: 1 to 2 phones, 1 TV, a stopwatch, a phone camera (240 fps for item 4a), and a child of about 5 to 8 years for item 10. Covers: REQ-FD-* (`docs/games/freeze_dance.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-102, REQ-GM-47i to 47n.

New game (2026-10-24). It was tested only with made-up sensor values. Every number (the wiggle level, the limit for "still", the grace time, the length of the music and of the freeze) is a first guess; write what you measure in the Notes. Hold each phone like a remote control. Play on Medium unless the step says another difficulty. The checks of the rules (the points, the sit-out, the order of the songs, the light tiles) are automated (`dance_rules`, `smoke_freeze`, `docs/AUTOMATED_TESTS.md`).

**Steps**

1a. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the dark floor with white tiles, the mirror ball, the dancers and the stage edge.
2a. Open the settings view of Freeze Dance (OK on its tile) with 2 phones connected. Check: the TV shows the line "WIGGLE YOUR PHONE WHILE THE MUSIC PLAYS. WHEN IT STOPS, HOLD STILL TO GET POINTS.", the safety line, and the rows Difficulty and Start. Each phone shows the card "HOLD ON TIGHT!" and Start stays off until both phones tapped OK (3 of 3 tries). (REQ-GM-102, REQ-GM-103)
3c. Wiggle gently, like a child of 5 would, for 5 s. Check: the dancer dances (arms up and down) in 5 of 5 tries. Write down in the Notes if the wiggle that you made was too weak. (REQ-FD-5)
4b. Hold a phone and watch it during 5 stops. Check: the screen of the phone does not change and the phone does not buzz at the stop (5 of 5). (REQ-FD-3, REQ-FD-14)
5a. Wiggle in the music and hold the phone as still as you can in 10 stops on Medium (a relaxed arm, no support). Check: the dancer is not moved off the floor in 9 of 10 stops. Write down the stops where it moved. (REQ-FD-6)
5c. Hold the phone loosely with two fingers like a small child (the arm hanging) and hold still in 10 stops on Medium. Check: the dancer is not moved off the floor in 8 of 10 stops. (REQ-FD-4, REQ-FD-6)
5d. Hold the phone still in 3 different poses: flat on the palm, upright like a camera, and upside down, 3 stops each. Check: the dancer is not moved off the floor in 8 of 9 stops. (REQ-FD-4)
10a. Let a child of about 5 to 8 years play on Easy, with a grown-up next to them who does not help. The grown-up reads the hint line once. Check: the child wiggles so that its dancer dances within 15 s after Start, with no help. (REQ-FD-15)
10b. Same child. Check: the child holds still in at least 1 stop out of 3 (the score grows at least once), with no help. (REQ-FD-15)
10c. Same child. After a move at FREEZE, check: the child plays on in the next song and does not ask to stop or cry (yes or no). (REQ-FD-8, REQ-GM-83)
10d. After the round, ask: "Play again?". Check: the child says yes (1 of 1 children asked).
12a. **Pixel world (REQ-GM-47i to 47n).** From 3 m, a tester points at the dancer in a given color when you say "mark". Check: the tester finds it in 5 of 5 tries, also when the floor is lit. Check: a dancer is 48 px or more high on the screen at 1080p (photo). (REQ-GM-47e, REQ-FD-12)
12b. From 3 m, ask a tester to read aloud the banner and the "SONG n OF 6" box. Check: no error. (REQ-FL-40)
13. Set the TV language to Hebrew and play 1 song. Check: the title and the song box are mirrored (they are on the other side of the screen), and the floor and the dancers are not mirrored (the stage is at the bottom, the near dancers on the right stay near). No text is cut. (REQ-GM-47o)

Items 2b, 3a, 3b, 3d, 4a, 5b, 6a, 6b, 6c, 7a, 7b, 8a, 8b, 8c, 9a and 9b moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-31-*). The numbers of the other items do not change.

Measurements (write down, no pass or fail): in how many stops a still hand was marked as moved on Easy, Medium and Hard; how much wiggle a child needs to make the dancer dance; how long a child needs to stop after the music; the length of a whole round. Use them to tune `WIGGLE_MIN`, the limits for "still", the grace time and the length of the freeze.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the tile next to a photo of the game | Pass | R6 |  | R6: Pass |
| 2a | Photo of the TV and of a phone | Pass | R6 |  | R6: Pass |
| 3c | Note: tries of 5 | Pass | R6 |  | R6: Pass |
| 4b | Note: yes or no for each of 5 stops | Pass | R6 |  | R6: Pass |
| 5a | Note: stops that were marked as moved, of 10 | Pass | R6 |  | R6: Pass |
| 5c | Note: stops that were marked as moved, of 10 | Pass | R6 |  | R6: Pass |
| 5d | Note: stops marked as moved, per pose | Pass | R6 |  | R6: Pass |
| 10a | Note: the child, the age, seconds | Pass | R6 |  | R6: Pass |
| 10b | Note: scores | Pass | R6 |  | R6: Pass |
| 10c | Note: yes or no | Not run | | | |
| 10d | Note: the answer of the child | Pass | R6 |  | R6: Pass |
| 12a | Note: right answers of 5; photo with the height in px | Pass | R6 |  | R6: Pass |
| 12b | Note: errors made when reading | Not run | | | |
| 13 | Photo of the TV in Hebrew; note: words that a reader changed | Not run | | | |

History:

- 2026-11-10 (step removed): Owner request of 2026-11-10 (tracker and chat: "Tests 14, 23, 27, 28 and 31 still have steps that either need to be removed or automated"; the owner has 1 Android phone and no TV box). The FPS step on the TV box is removed: nobody can do it now. The cost of a frame with 4 phones on Hard stays automated (`frame_cost`, A-31-11); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device).
- 2026-11-10 (recorded; R6 in the tracker): Pass: steps 1a, 2a, 3c, 4b, 5a, 5c, 5d, 10a, 10b, 10d, 12a. R6: the N/A of step 11 (4 phones) is not recorded: the step is 1 phone on the TV box now (A-31-11). Steps 10c, 12b and 13 passed on an older text (the bench plate; the move in one of 3 songs); they stay Not run because the steps changed.
- 2026-10-24 (automated): steps 2b, 3a, 3b, 3d, 4a, 5b, 6a, 6b, 6c, 7a, 7b, 8a, 8b, 8c, 9a, 9b moved to the automated tests (smoke_freeze, dance_rules). Nothing was run on a device, so no result moved.
- -: **Not run**. New (2026-10-24). The headless checks of the rules and the screens are in `dance_rules` and `smoke_freeze` (`docs/AUTOMATED_TESTS.md`); this test holds what needs a person, a phone or a TV.

## Test 32

### Bumper Cars (tilt, drive over stars and bump the others)

Needs: 2 phones, 1 TV, a stopwatch, and a child of about 5 to 8 years for items 9a to 9d. Covers: REQ-BC-* (`docs/games/bumper_cars.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-24). It was only tested with made-up sensor values. Every number (the speed of the cars, the size of the rink, the number of stars on the floor, the size of a bump, the 60 s of the round), the pictures, the song, the sounds and the Hebrew texts are first guesses. Changed 2026-10-29 (owner): a hit takes no star (it took 1 star from each car from 2026-10-24); a bump is only a bonk, a spark and a buzz (REQ-BC-7).

**Steps**

1. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the red and white tent, the rink with its black rail, gold stars on the floor, and the cars.
2a. From 3 m, a tester points at one star and at one car. Check: both answers are right for each of 5 testers (5 of 5 testers).
9a. Let a child of about 5 to 8 years play with 2 phones on Easy, with a grown-up next to them who does not help. Check: the child points at its own car (the one in the color of its phone) within 10 s after GO.
9b. Same child. Check: the child drives over at least 1 star within 30 s after GO, with no help.
9c. Same child. Check: the child has at least 3 stars at the end of the round.
9d. After the round, ask: "Play again?". Check: the child says yes (1 of 1 children asked).
11a. Open the settings view and read the how-to line under the name, then play 1 round. Check: a tester can tell what to do (tilt to drive, pick up stars, bump the others) without more help (3 of 3 testers).
11b. A native reader of Hebrew reads the 6 new texts of the game (the 6 rows of `assets/lang/strings.csv` with the keys `registry.bumper_cars`, `registry.desc_bumper_cars`, `how_to.bumper_cars`, `bumper_cars.hint`, `result.one_star` and `result.stars`) on the TV set to Hebrew. Check: the reader marks 0 texts as wrong and 0 texts as not fitting on the screen.
12a. Drive two cars slowly into each other (the speed towards each other below 250 px/s: the cars need more than 8 s to cross the rink on their own), 5 times. Then drive them into each other at full tilt from 1/3 of the rink apart, 5 times. Check: the slow touches give no spark, no sound and no buzz (0 of 5), and the fast hits give a spark, the sound of a bump and a buzz on both phones (5 of 5). (REQ-BC-6)
12b. From 3 m, a tester points at: the tent roof, the ring in the middle of the rink, the rail with the white reflectors, a star and a car. Check: 5 of 5 right for each of 3 testers (3 of 3 testers). Drive a car to the left, to the right, up and down on the screen and stop it each time. Check: the tester says the way the car faces after it stopped, right in 4 of 4. Read aloud the title and the timer: no error. (REQ-BC-16)

Items 2b, 3a, 3b, 3c, 4a, 4b, 5a, 5b, 5c, 5d, 6a, 6b, 8a, 8b and 10 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-32-2b to A-32-10). The numbers of the other items do not change.

Measurements (write down, no pass or fail): the time that a car needs from the middle to the rail with a steady tilt; how many stars a player picks up in a round of 2 and of 4; how often a hit happens in a round; if a car gets stuck in a corner or at the rail; the time that a round of 1 child takes to become fun (when the child first laughs).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the tile next to a photo of the game | Pass | R9 |  | R9: Pass |
| 2a | Note: right answers of 5 | Pass | R9 |  | R9: Pass |
| 9a | Note: the child, the age, seconds until it points | Pass | R9 |  | R9: Pass |
| 9b | Note: seconds until the first star | Pass | R9 |  | R9: Pass |
| 9c | Note: stars at the end | Pass | R9 |  | R9: Pass |
| 9d | Note: the answer of the child | Pass | R9 |  | R9: Pass |
| 11a | Note: answers of each tester | Pass | R9 |  | R9: Pass |
| 11b | Note: the texts that the reader marks, with the reason | Pass | R9 |  | R9: Pass |
| 12a | Video; note: slow touches with any effect (of 5); fast hits with spark, sound and 2 buzzes (of 5) | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |
| 12b | Note: answers of each tester; directions right (of 4); reading errors | Pass | R9 |  | R9: Pass Added 2026-10-31 (issue #306). |

History:
- 2026-11-10 (step removed): Owner decision of 2026-11-10 (issue #440, the owner answered: remove them; the owner has 1 Android phone and no TV box). The FPS step on the TV box (step 7) is removed: nobody can do it now. The cost of a frame with 4 phones on Hard stays automated (`frame_cost`, A-32-7, issue #132); what is not verified by anything now is the frame rate of the real TV box (REQ-GM-50 on a real device). REQ-GM-50 is dropped from the Covers line of this test.

- 2026-11-01: step 7 says 2 phones (it said 1 phone, but the game needs 2 to 4 phones, `min_players` 2).
- 2026-10-24 (automated): steps 2b, 3a to 3c, 4a, 4b, 5a to 5d, 6a, 6b, 8a, 8b and 10 moved to the automated tests (`smoke_bumper_cars`, `bumper_rules`). Nothing was run on a device, so no result moved.
- -: **Not run**. New (2026-10-24).

History:

- 2026-11-17 (recorded; R9 in the tracker): Pass: steps 1, 2a, 7, 9a, 9b, 9c, 9d, 11a, 11b, 12a, 12b.

## Test 33

### iPhone QR scanner (camera view, permission, cancel, privacy)

Needs: 1 iPhone, 1 Mac with Xcode, 1 TV with the Sababi TV app, a second phone with a player profile (for item 4b), a stopwatch, a child of about 5 to 8 years for item 9b, and a native reader of Hebrew for item 8a. Covers: REQ-FL-58, REQ-FL-88, REQ-FL-89, REQ-FL-90, REQ-FL-91, REQ-FL-92 (`docs/TV_FLOW.md`), `docs/IOS_SCANNER_PLAN.md`, issue #299.

Join approval (issue #393, phase 4): the TV setting "APPROVE NEW PLAYERS" is ON by default, so each phone that joins in this test waits for the host. Before the first join either turn the setting OFF (Settings, first row, press Left) or press OK on ALLOW on the TV card each time a phone joins (the focus is on ALLOW; REQ-FL-93, 94).

New (2026-11-01). The plugin (`ios/plugin/qr_scanner/`) was written without Xcode and without an iPhone: it was never built and never run. Run Test 13 steps 1a to 2d first, so that a scanner problem can be told from a join problem. In Test 13, step 2c ("no scan button") stays true until the code of the scanner is built; after that, the scan button is expected on an iPhone that has the plugin, and Claude changes step 2c then.
Write the model of the iPhone and the iOS version in the Run log.

**Steps**

1a. Run `IOS_TEAM_ID=<id> tools/deploy-ios.sh` (it builds the plugin first, `docs/EXPORT.md`). Check: the plugin builds, the app installs and starts, and `echo $?` after the script prints 0. If it fails, save the last 50 lines of the log.
2a. Open the Connect screen. Check: the SCAN QR CODE button is under the code field and the JOIN icon button and is as high as it (130 px) (changed 2026-11-02, it was above the field). (REQ-FL-58, REQ-FL-83a)
2b. Only if you have an iPhone older than the A12 chip (iPhone 8 or X, iOS 16): open the Connect screen there. Check: there is no SCAN QR CODE button, and the typed room code joins. Write "no old phone" in the result if you have none. (REQ-FL-58, changed 2026-11-02: the scanner uses VisionKit)
3a. Tap SCAN QR CODE for the first time. Check: iOS shows the camera question once, and the text of the question is "Sababi uses the camera only to read the QR code on your TV, to join the game. The picture is not saved or sent." (REQ-FL-91)
3b. Tap Allow. Check: the camera view opens within 2 seconds, in portrait, with a live picture, the hint line and a CANCEL button at least 96 points high (about 1.5 cm, measure on the screen) at the bottom. The texts use the iOS system font, not the pixel font: this is a known limit, write in the Notes if the look should change. (REQ-FL-88)
4a. Point the phone at the QR code on the TV from 30 cm to 1 m. Check: the view closes and the phone is on the waiting screen within 3 seconds of the code being in the picture, in 5 tries out of 5. Note the distance range that reads. (REQ-FL-89)
4b. Scan the QR code of a shared player profile (a second phone, Share) with SCAN QR CODE on the Connect screen. Check: the Connect screen shows the new player selected in the dropdown and its status line says PLAYER ADDED. (changed 2026-11-02: the player list is gone; 2026-11-06: the new player is selected). (REQ-FL-89)
4c. Scan a QR code of a web page. Check: the Connect screen shows "THIS IS NOT A SABABI APP CODE." and the camera is closed (no green dot in the status bar). (REQ-FL-89)
4d. Scan a good TV code with HAPTICS on. Check: the phone buzzes once when the view closes (yes or no). Then switch HAPTICS off in the Settings of the phone and scan again: no buzz (yes or no). (REQ-FL-89)
5a. Open the scan view and tap CANCEL. Check: the view closes, the Connect screen shows no message, and the typed room code still joins. (REQ-FL-90)
5b. Open the scan view and swipe down. Check: same result as 5a. (REQ-FL-90)
5c. Open the scan view, press the home button and return. Check: the camera view is closed, the Connect screen shows no message, and the green camera dot in the status bar is off. (REQ-FL-88, REQ-FL-90)
6a. Switch the camera off for Sababi (Settings > Sababi > Camera) and tap SCAN QR CODE. Check: no camera view opens, the Connect screen shows the exact text of `connect.camera_denied` ("THE CAMERA IS OFF FOR SABABI APP. TURN IT ON IN SETTINGS, OR TYPE THE ROOM CODE."), and the typed room code joins. (REQ-FL-91)
6b. Switch the camera on again and tap SCAN QR CODE. Check: the scan works without a restart of the app. (REQ-FL-91)
7a. After a scan and after a CANCEL, open the Photos app. Check: no new picture. (REQ-FL-92)
7b. Open Settings > Sababi. Check: the only permissions listed are Camera and Local Network (no Photos, no Microphone). (REQ-FL-92)
7c. Set the iPhone to Hebrew, delete the app, install it again and tap SCAN QR CODE. Check: the camera question is in Hebrew (the text in the preset, `privacy/camera_usage_description_localized`). If it is in English, the Hebrew text did not reach the build: tell Claude. (REQ-FL-92)
8a. Set the app to Hebrew. Check: the hint line and CANCEL show the Hebrew text, read right to left, and are inside the screen edge. A native reader of Hebrew confirms the words of the 4 new rows (`connect.scan_hint`, `connect.scan_cancel`, `connect.camera_denied`, `connect.no_camera`) and of the camera question (7c). (REQ-FL-88, REQ-FL-91)
9a. In a dark room with only the TV on, scan the code. Check: it reads within 5 seconds (yes or no; write the phone model). (REQ-FL-89)
9b. A child of about 5 to 8 years scans the code on the TV with the phone, with no help. Check: the child joins within 30 seconds (stopwatch). (REQ-FL-58, REQ-FL-89)

Nothing in this test can be done headless (it needs a real camera): the GDScript side (the call with the two texts, the reasons, the button) is covered by headless tests (`docs/AUTOMATED_TESTS.md`, A-33-1 and A-33-2).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Terminal log of the deploy with the exit code | Not run | | | |
| 2a | Photo of the Connect screen | Not run | | | |
| 3a | Photo of the camera question | Not run | | | |
| 3b | Photo of the camera view | Not run | | | |
| 4a | Note: seconds for each of 5 tries; the distance range | Not run | | | |
| 4b | Photo of the Connect screen after the scan (PLAYER ADDED.) | Not run | | | |
| 4c | Photo of the message | Not run | | | |
| 4d | Note: buzz with HAPTICS on (yes/no), buzz with HAPTICS off (yes/no) | Not run | | | |
| 5a | Photo of the Connect screen after CANCEL | Not run | | | |
| 5b | Note: result | Not run | | | |
| 5c | Photo of the status bar | Not run | | | |
| 6a | Photo of the message | Not run | | | |
| 6b | Note: result | Not run | | | |
| 7a | Photo of the Photos app | Not run | | | |
| 7b | Photo of Settings > Sababi | Not run | | | |
| 7c | Photo of the camera question in Hebrew | Not run | | | |
| 8a | Photo of the view in Hebrew; note: the words the reader marks, with the reason | Not run | | | |
| 9a | Note: yes or no; the phone model | Not run | | | |
| 9b | Note: the child, the age, seconds | Not run | | | |

History:

- -: **Not run**. New (2026-11-01, issue #299).

## Test 34

### Join approval with the TV remote (issue #393)

Needs: 1 TV with the Sababi TV app and its real remote (not a keyboard), 2 phones with the Sababi controller (phone A, phone B; two different Wi-Fi addresses), a stopwatch, a child of about 5 to 8 years for step 8a, a native reader of Hebrew for step 7a. Covers: REQ-FL-93, REQ-FL-94, REQ-FL-95, REQ-FL-96, REQ-FL-97, REQ-FL-98, REQ-FL-99, REQ-FL-100, REQ-FL-101, REQ-FL-102, REQ-FL-103, REQ-FL-104, REQ-FL-74, FD-30 (`docs/TV_FLOW.md`), issue #393.

New (2026-11-07). **Built (phases 1 to 4, 2026-11-07): every step is Not run.** Claude does not mark any step Pass. The texts of the steps are the proposed strings of `docs/TV_FLOW.md` ("Proposed strings"); when the owner or the reviewer changes a text, change the step in the same commit. Use English first. Write the build in the Run log. Phones A and B have different player profiles (or none) for steps 2 to 6.

**Steps**

1a. Install a new TV app (no `settings.cfg`) and open Settings (OPTIONS on the Games screen). Check: the first row is APPROVE NEW PLAYERS with the value ON in green, above Debug overlay. (REQ-FL-93)
1b. On that row press Left, then close the app with the TV remote and open it again. Check: the row shows OFF after the restart; OK on the row changes nothing. (REQ-FL-93)
1c. With OFF, join phone A with the typed room code. Check: A is on its waiting screen within 3 seconds (stopwatch) and no card shows on the TV. Then set the row to ON again. (REQ-FL-94)
2a. Set ON, phone A leaves (DISCONNECT) and the TV is on the Connect screen. Join with phone B. Check: B shows the waiting text; the TV shows a card with the title NEW PLAYER and the name of B, the avatar when B has a profile, the line WANTS TO JOIN, the two buttons ALLOW and REFUSE with the focus on ALLOW, and no OK box, no BACK box, no time bar and no seconds, inside the screen edge; the slot list is empty (0 players joined). (REQ-FL-94, REQ-FL-97)
2b. A card shows for B. Within 0.5 seconds after it shows press OK, then BACK, then Right (a helper counts; video). Check: the card is still there, the focus is still on ALLOW, B is not in a slot and no refusal sound plays (the card ignores OK, the arrows and BACK for 1 second). Then, 3 seconds after the card shows, press Up, Down, BACK and Menu: the card is still there with the focus on ALLOW (Up, Down and BACK do nothing; Menu is not handled by the card and does what it does today on the Connect screen). (REQ-FL-97)
2c. Press OK 2 seconds or more after the card shows (the focus is on ALLOW). Check: the card closes, B is in slot 1P with its name on the Connect screen, B shows the waiting screen of the TV phase, within 2 seconds, and the `join` sound plays (yes or no). The refusal counter of B is 0 (an allow resets it). (REQ-FL-95, REQ-FL-97, REQ-FL-104)
2d. Phone B leaves (DISCONNECT). Join with phone B again, and after 2 seconds press Right (the focus moves to REFUSE) and then OK. Check: the card closes, no slot is used, and the TV plays the denied sound (yes or no). Counter of B: 1. Tap JOIN on B: a new card shows with the focus on ALLOW; press Right, then Left: the focus is back on ALLOW. Leave this card open. (REQ-FL-97, REQ-FL-104)
2e. On the card that is open from step 2d (2 seconds or more after it showed) press BACK on the remote 3 times. Check: the card is still there with the focus on ALLOW, no slot is used, no sound plays and B shows no answer yet (BACK does nothing on the card). Then press Right and OK (REFUSE). Check: the card closes, no slot is used, and the TV plays the denied sound (yes or no). Counter of B: 2. (REQ-FL-97, REQ-FL-104)
3a. Tap JOIN on B (the counter stays 2: no refusal yet); a card shows, do not press anything on the TV. Read the phone. Check: the text WAITING FOR THE HOST TO GET YOU IN., the line ASK THE HOST TO ALLOW YOU ON THE TV. and a CANCEL button at least 96 px high, all inside the safe area; no JOIN button. (REQ-FL-100)
3b. Tap CANCEL on B. Check: the card closes on the TV within 2 seconds, the phone shows the Connect screen with no message, and no slot is used. A CANCEL does not change the counter (it stays 2). (REQ-FL-99, REQ-FL-100, REQ-FL-104)
4a. Close the TV app and open it again (the counter of every address is 0). Join with B (a card shows) and, 2 seconds after it showed, press Right and OK (REFUSE). Counter of B: 1. Check: B shows THE HOST DID NOT LET YOU IN. in red on the Connect screen within 2 seconds. Tap JOIN again at once: a new card shows (one refusal does not block). Leave the card open for step 4b. (REQ-FL-101, REQ-FL-104)
4b. On the card of step 4a press nothing. Check: the card is open at 55 seconds and closed at 65 seconds (stopwatch from the card), with no time bar and no seconds at any time, and B shows NO ANSWER FROM THE TV. TRY AGAIN. Tap JOIN again at once: a new card shows (a timeout does not block and does not change the counter, which stays 1). (REQ-FL-98, REQ-FL-101, REQ-FL-104)
4c. Moved to the headless test A-34-4c (planned, `docs/TV_FLOW.md`, REQ-FL-99): the `busy` text needs 4 waiting requests from 4 addresses, and a manual test has at most 3 phones and one waiting request for each address. The number 4c stays free.
4d. Close the TV app and open it again (the counter is 0). B joins, and 2 seconds after each card the host presses Right and OK (REFUSE) 3 times in a row (join, REFUSE, tap JOIN, REFUSE, tap JOIN, REFUSE). Check: after the 3rd REFUSE (the counter is 3), tap JOIN at once: B shows THE HOST DID NOT LET YOU IN. and the TV shows no card; tap JOIN at 50 seconds (stopwatch from the 3rd REFUSE): still no card; tap JOIN at 65 seconds: a card shows (the block ended and the counter is 0). Leave the card open for step 4e. (REQ-FL-104)
4e. On the card of step 4d press Right and OK (REFUSE) 2 seconds after it showed (counter 1). B taps JOIN and the host presses OK on ALLOW (B is allowed and is in a slot; counter 0); B leaves (DISCONNECT); B joins, REFUSE (1); B taps JOIN, REFUSE (2); B taps JOIN. Check: a card shows at once (the allow reset the counter, so only 2 refusals in a row count). Leave the card open. (REQ-FL-104)
5a. Close the TV app and open it again (this clears the open card and the counters). Phone A joins and is allowed (slot 1P). A turns off its Wi-Fi for 3 seconds and turns it on again. Check: A gets its slot 1P back with no card on the TV, within 10 seconds. (REQ-FL-94)
5b. Phone B types the room code and taps JOIN, so that a card is open on the TV and B waits. Close the TV app with Back and Quit. Check: B leaves the waiting screen within 5 seconds and shows THE TV APP CLOSED THE CONNECTION.; it does not join by itself after the TV opens again. (REQ-FL-103)
5c. Start: close and open the TV app again (step 5b left it closed), let phone A join and press OK on ALLOW so that A is in slot 1P, and wait 10 seconds. A turns off its Wi-Fi for 10 seconds (stopwatch) and turns it on again. Check: A is in its own slot 1P again within 10 seconds after the Wi-Fi is on, and the TV shows no card (a known token is accepted after the 5 seconds of the grace; wide rule, D11 decided by the owner on 2026-11-07). (REQ-FL-94, D11)
5d. Not used: D11 decided as the wide rule (owner, 2026-11-07). The number 5d stays free.
6a. Close the TV app and open it again, join phone A and allow it (OK, 2 seconds after the card), and start a game with phone A. Join with phone B during the round. Check: the TV shows no card during the round (watch the whole round, at least 60 seconds), B shows the waiting text, and the card shows within 2 seconds after the TV goes back to the Games screen. Press OK 2 seconds after the card shows: B joins. (REQ-FL-96, REQ-FL-95)
6b. Phone B leaves (DISCONNECT). In a menu, join with the same profile as phone A, on phone B (REQ-FL-74). Check: B shows THIS PLAYER IS ALREADY IN THE ROOM. at once and the TV shows no card. (REQ-FL-94, REQ-FL-74)
7a. Set the app (both phones and the TV) to Hebrew. Check: the texts of steps 2a, 3a, 4a and 4b are in Hebrew, read right to left and inside the screen edge; the native reader writes the words that are wrong, with the reason. (REQ-FL-63a, REQ-FL-97, REQ-FL-100, REQ-FL-101)
8a. A child of about 5 to 8 years holds phone B, and an adult holds the remote. The child joins with the room code or the QR code and says what the phone says. Check: the child says in own words that the phone waits for the TV (yes or no) and the child joins within 60 seconds after the adult presses OK (stopwatch). (REQ-FL-100)

The rules of this test that need no device (queue order, the limits, the 60 seconds, the setting saved, a held profile, OFF, the `busy` answer when 4 requests wait: A-34-4c) are planned as headless tests (`tests/join_approval.gd`).

**Order and counters.** The steps run in sequence. The refusal counter of REQ-FL-104 is kept for each address and carries over from step to step: 3 refusals by the host in a row from phone B block it for 60 seconds, and only an allow, or a restart of the TV app, resets it. The steps say where the counter is and where to restart the TV app. Press a key on a card only 2 seconds after the card shows (the card ignores OK, the arrows and BACK for 1 second, and BACK stays ignored after it, REQ-FL-97), except in step 2b.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the Settings screen, first row | Pass | R9 |  | R9: Pass |
| 1b | Photo of the row after the restart | Pass | R9 |  | R9: Pass |
| 1c | Note: seconds to the waiting screen; photo of the TV (no card) | Pass | R9 |  | R9: Pass |
| 2a | Photo of the card; note: the things read | Pass | R9 |  | R9: Pass |
| 2b | Video of the keys at 0.5 s | Pass | R9 |  | R9: Pass |
| 2c | Video; note: seconds, the sound (yes/no) | Pass | R9 |  | R9: Pass |
| 2d | Video; note: the sound (yes/no) | Pass | R9 |  | R9: Pass |
| 2e | Video; note: the sound (yes/no) | Pass | R9 |  | R9: Pass |
| 3a | Photo of the phone | Pass | R9 |  | R9: Pass |
| 3b | Video; note: seconds | Pass | R9 |  | R9: Pass |
| 4a | Video with the stopwatch; photo of the status line | Pass | R9 |  | R9: Pass |
| 4b | Video with the stopwatch; photo of the status line | Pass | R9 |  | R9: Pass |
| 4c | Moved to A-34-4c (headless, planned); no manual step | Moved | | | |
| 4d | Video with the stopwatch; photo of the status line | Pass | R9 |  | R9: Pass |
| 4e | Video; note: card yes/no on the last try | Pass | R9 |  | R9: Pass |
| 5a | Video; note: seconds | Pass | R9 |  | R9: Pass |
| 5b | Video of the phone; note: seconds | Pass | R9 |  | R9: Pass |
| 5c | Video; note: seconds, card yes/no | Pass | R9 |  | R9: Pass |
| 5d | Not used: D11 decided as the wide rule | Pass | R9 |  | R9: Pass Before: N/A - Owner decision 2026-11-07. |
| 6a | Video of a whole round; note: seconds to the card | Pass | R9 |  | R9: Pass |
| 6b | Photo of the phone and the TV | Pass | R9 |  | R9: Pass |
| 7a | Photos in Hebrew; note: the words the reader marks, with the reason | Pass | R9 |  | R9: Pass |
| 8a | Note: the child, the age, what the child said, seconds | Pass | R9 |  | R9: Pass |

History:

- 2026-11-17 (recorded; R9 in the tracker): Pass: steps 1a, 1b, 1c, 2a, 2b, 2c, 2d, 2e, 3a, 3b, 4a, 4b, 4d, 4e, 5a, 5b, 5c, 5d, 6a, 6b, 7a, 8a.
- -: **Not run**. New (2026-11-07, issue #393).
