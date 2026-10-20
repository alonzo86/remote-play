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
3. Update the **Summary** table at the top, and the list in `CLAUDE.md` (section *Manual tests*).
4. If a step fails, save the log: `adb logcat -s godot > docs/evidence/<test>/<run>-log.txt`. Then tell Claude the step and the result.

Rules

- Claude does not run these tests and never marks a step `Pass`. Claude writes down what you report, in your words, with the evidence you give.
- A requirement with the status **Device** is not done until the test for it is `Pass`.
- Evidence files go in `docs/evidence/<test>/`, named `<run>-<what>.<ext>`, for example `R1-t10-04-miss-fade.mp4`. Photos up to 1920 px wide, videos up to 30 s and 20 MB.
  Bigger files: put them in your own storage and link them. Do not commit private data: crop or blur the name of your Wi-Fi and addresses on your home network.
- Do not turn a number into a pass without a measurement. Write the value in the Notes.
- Every step has a clear pass or fail criterion (a number with a limit, an exact text, an object that is visible or not). A step that asks for a feeling or an opinion is not a test: do not write it. A step checks one thing, or two linked things; split it when it checks more.

## What you need

- 1 Android TV or streaming box, with the `tv` APK installed, and its remote control.
- 1 to 4 Android phones with the `controller` APK. The phones need Google Play services (for the QR scanner).
- 1 Wi-Fi network for all devices. Best: 5 GHz. Turn off VPN on the phones. A TV app on a desktop is **not** a TV box: say so in the Run log.
- A phone camera (240 fps slow motion for Test 4).
- Before every run: the current APKs are installed, **Invert axes** is off, and the TV and the phones are on the same Wi-Fi.

## Run log

One row for each session with the devices. The *Run* ID is used in the result tables.

| Run | Date | Tester | Commit or build | TV device | Phones | Network | Notes |
|-----|------|--------|-----------------|-----------|--------|---------|-------|
| R0 | before 2026-10-08 | (not written down) | prototype, before `main` a599ca3 | TV app on a desktop (not a TV box) | 1 phone | same Wi-Fi | The first run. The date and the build were not written down. |
| R1 | 2026-10-09 | the project owner | branch `games/target-shoot`, HEAD `091cacf` (the app code is the same as `5603ac1`), debug APK installed with `tools/deploy.sh` over `adb connect` | Android TV, Android 10, Ethernet. Language Hebrew, region Israel (IL). Model not written down | not written down (the maze was played) | TV on Ethernet. Same home network | Reported in chat. No photos, videos or logs yet. Found 4 problems (Tests 1, 8, 8b), all fixed in code on `games/target-shoot` and waiting for a retest. Run R2 is the retest. |
| R2 | 2026-10-09 | the project owner | build with Snowball Splat. The commit was not written down | not written down | not written down | not written down | Reported in chat. Only the problem with the score chip was reported. Everything else of the new game is not reported yet. |
| R3 | | | | | | | |

## Summary

Update this table after every run. *Latest* is the newest result of the whole test (the worst result of its steps).

| Test | Title | Needs | Covers | Latest | Run | Evidence |
|------|-------|-------|--------|--------|-----|----------|
| [1](#test-1) | Start and join | 1 phone, 1 TV | REQ-A3, REQ-A4, REQ-FL-5 to 10, REQ-FL-80, 83, 84 | Retest (design change) | R1 | |
| [2](#test-2) | QR scan (plugin, unverified) | 1 phone, 1 TV | RISKS C5 | Pass | R0 | |
| [3](#test-3) | Sensor directions | 1 phone, 1 TV | RISKS A2 | Retest | R0 | |
| [4](#test-4) | Latency and packet rate | 1 to 4 phones, 1 TV, a phone camera (240 fps) | RISKS A3, B1, B2, B3, B5, B6 | Fail | R0 | |
| [6](#test-6) | Treasure Maze feel | 1 to 4 phones, 1 TV | REQ-MZ-4, 6, 7, 8, 9, 12, 13, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-90 to 95 | Partial (items 1 to 3 Pass, 4 to 7 not run) | R1 | |
| [7](#test-7) | Disconnect and reconnect | 2 phones, 1 TV | REQ-GM-30, REQ-GM-30a, REQ-T5, REQ-N5, REQ-N6, REQ-FL-25, REQ-FL-52, REQ-MR-14, REQ-MZ-8 | Fail (item 1, fixed, retest) | R1 | |
| [8](#test-8) | TV remote | 1 phone, 1 TV with its remote | REQ-GM-31, REQ-GM-31a, REQ-GM-33, REQ-FL-41, REQ-FL-55 | Fail (items 2 and 3, fixed, retest) | R1 | |
| [8b](#test-8b) | The TV flow and the style | 1 to 2 phones, 1 TV (item 7 moved to Test 17) | REQ-FL-1 to 46, REQ-FL-56, 57, REQ-FL-81, FD-1 to 17, FD-23 | Fail (items 2 and 7, fixed, retest) | R1 | |
| [9](#test-9) | Road Rally | 1 to 4 phones (2 to 4 for items 5, 7 and 11), 1 TV | REQ-MR-*, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50 | Not run |  | |
| [10](#test-10) | Banana Party (pointer) | 1 to 4 phones, 1 TV, a child for item 9 | REQ-SS-*, REQ-GM-47i to 47n, REQ-GM-80 to 84, 90 to 95, RISKS A4, REQ-GM-37, REQ-GM-50 | Fail (first version, redesigned), score chip fixed, retest | R2 | |
| [11](#test-11) | Result menus (REQ-GM-72) | 1 to 4 phones, 1 TV | REQ-GM-34, REQ-GM-40, REQ-GM-41, REQ-GM-72, REQ-GM-73, REQ-MZ-5, REQ-MR-31 | Not run |  | |
| [12](#test-12) | Game tiles and the toy box look (REQ-GM-49) | 1 TV (phones for the game photos) | REQ-GM-49, REQ-FL-20, REQ-FL-40, REQ-GM-41 | Not run |  | |
| [13](#test-13) | Controller on an iPhone | 1 iPhone, 1 Mac with Xcode, 1 TV | `tools/deploy-ios.sh`, RISKS A2, REQ-FL-58, 59, 68, 83, 84 | Not run |  | |
| [14](#test-14) | Paint Grab (tilt) | 1 to 4 phones, 1 TV, a child for item 7 | REQ-PG-*, REQ-GM-80 to 84, 90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50 | Not run |  | |
| [15](#test-15) | Sumo Bumpers (tilt and A) | 2 to 4 phones, 1 TV, a child for item 8 | REQ-SB-*, REQ-GM-80 to 84, 90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50 | Not run |  | |
| [16](#test-16) | The arcade look (phase 1) | 1 to 4 phones, 1 TV on 1080p (and a 4K TV if you have one), a child for item 8 | REQ-FL-37 to 46, REQ-FL-41a, 52, 53, REQ-GM-45, 46, FD-18 | Not run |  | |
| [17](#test-17) | Hebrew and right to left (phase 5) | 2 phones (one set to Hebrew), 1 TV (once set to Hebrew, once to English) | REQ-FL-54, 60 to 63, REQ-GM-47o, FD-19 | Not run |  | |
| [18](#test-18) | Sound and haptics | 1 to 4 phones, 1 TV | REQ-FL-64 to 66, REQ-GM-49a to 49c, REQ-GM-43 | Not run | | |
| [19](#test-19) | Leader chip, phone score and name tags | 2 to 4 phones (names of 10 letters), 1 TV, a child for item 8 | REQ-FL-67, REQ-FL-68, REQ-GM-46, 46a, FD-21 | Not run | | |
| [20](#test-20) | Player profiles (names, avatars, personal bests, copy by QR) | 2 to 4 phones, 1 TV, a child for item 7 | REQ-FL-69 to 79, REQ-GM-98 to 101, REQ-N8, REQ-C7 to C11, FD-22 | Not run | | |
| [21](#test-21) | Join PIN and About screens | 2 phones (one Android, one iPhone if possible), 1 TV | REQ-FL-84, REQ-FL-85, REQ-N9, FD-25 | Not run | | |
| [22](#test-22) | Galaxy Protector (tilt, waves, upgrades) | 1 to 4 phones, 1 TV, a child for item 9 | REQ-AB-*, REQ-GM-80 to 84, 90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50 | Not run | | |
| [23](#test-23) | Pin Pals (bowling: aim with a turn, swing to throw) | 1 to 4 phones, 1 TV, a child for item 11 | REQ-BW-*, REQ-GM-80 to 84, 90 to 98, REQ-GM-37, REQ-GM-47i to 47n | Not run | | |
| [24](#test-24) | Swing detector for Tennis (debug overlay) | 1 to 2 phones, 1 TV with its remote | REQ-TN-5 to 9 (`docs/games/tennis.md`), REQ-T4 | Not run | | |
| [25](#test-25) | Tennis (swing, toss, serve, rally, scoring) | 1 to 4 phones, 1 TV, a child for item 12 | REQ-TN-* (`docs/games/tennis.md`), REQ-GM-80 to 84, 90 to 97, REQ-GM-37, REQ-GM-47i to 47n | Not run | | |
| [26](#test-26) | Mini Golf (aim, putt power, turns, 5 holes) | 1 to 4 phones, 1 TV, a child for item 12 | REQ-MG-* (`docs/games/mini_golf.md`), REQ-GM-80 to 84, 90 to 97, REQ-GM-37, REQ-GM-47i to 47n | Not run | | |

Test 5 (pointer drift) was removed on 2026-10-07 with the old pointer test. The pointer is checked again in Test 10.

## Test 1

### Start and join

Needs: 1 phone, 1 TV, a stopwatch. Covers: REQ-A3, REQ-A4, REQ-FL-5 to 10, REQ-FL-80, 83, 84.

Uninstall the old apps first. The package names changed (FD-26 and FD-27; the list is in `README.md`). Use a stopwatch for every time limit.

**Steps**

1a. Look at the home row of the Android TV (the launcher). Check: the app tile shows the name **Sababi: TV Games**, and the banner shows the pixel mascot (a yellow face with sunglasses) and the word SABABI. (Sizes and colors of the icon, the adaptive layers and the banner are in the automated tests, A-1-1.)
1b. Start the TV app. Check: the Android splash shows the pixel mascot (a yellow face with sunglasses) on a black background.
1c. At the very first start only: the logo screen waits for the language choice. Choose ENGLISH with OK (Test 17 checks the language). Check: the logo screen does not go on until you press OK.
1d. Close the TV app and start it again. Check: the logo screen shows the mascot and the word SABABI, and it stays between 2.0 and 3.0 seconds (stopwatch from the first frame of the logo screen), then the **PLAYERS** screen shows. (The hard pixel edges of the logo are in the automated tests, A-1-1.)
1e. Look at the **PLAYERS** screen. Check: it shows a QR code, the words ROOM CODE with a room code of 4 letters, a join PIN of 4 digits, and 4 slots. (Changes with issue #52: the PIN goes away.)
1f. Only if the TV has no Wi-Fi or Ethernet address: Check: the QR code is empty and the screen says that the TV has no network address.
2a. Start the controller app on one phone. Check: the app is named **Sababi: Remote**.
2b. Look at the phone screen. Check: the screen is in **portrait** and shows the title SABABI.
3a. Tap the TV in the list **ROOMS FOUND**. Check: the phone shows the PIN pad with the text "TYPE THE PIN THAT IS SHOWN ON THE TV". (Changes with issue #52: no list and no PIN pad.)
4a. Tap **Disconnect** (top right on the phone). Check: the list **ROOMS FOUND** shows the TV as a white button with the text "<code> x/y", for example "KQZM 0/4" (a room with no player). (Changes with issue #52: no list.)
4b. Tap that button and type the PIN. Check: the phone joins (it shows "WAITING FOR THE HOST"). (Changes with issue #52.)
4c. Tap **Disconnect**, then tap **Refresh** (white). Check: the list shows "SEARCHING..." at once, and the TV is in the list again within 2 seconds of the tap. (Changes with issue #52: no Refresh.)
4d. REQ-FL-83. Use the TV app on a Mac, where the list stays empty. Wait 30 seconds without a tap. Check: the list stays empty (the scan never starts by itself). Tap Refresh. Check: the TV shows in the list within 15 seconds. If the Mac asks for the Local Network permission, answer for the app that runs the TV; the scan works without it. (Changes with issue #52.)
5. (Removed. There is no join by IP address, REQ-A4. The join by QR code is Test 2, the PIN rules are Test 21.)
6a. Tap **Disconnect** on the phone. Check: within 5 seconds the TV slot of the phone shows no "READY". (Today the slot shows "LOST" for up to 30 seconds and then is empty. Changes with issue #44: the slot is empty within 5 seconds and never shows "LOST".)
6b. Close the controller app and start it again, and film the start. Check: the Android splash (the mascot on black) is already in portrait and the phone does not turn at any frame of the video, and it is the only splash: the Connect screen follows at once, with no logo screen.
6c. Look at the Connect screen. Check: the heading "ROOMS FOUND" and the button **Refresh** are white (not another color). (Changes with issue #52.)

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the TV home row with the app name and the banner | Not run | | | |
| 1b | Photo of the TV splash | Not run | | | |
| 1c | Photo of the logo screen with the language choice (first start only) | Not run | | | |
| 1d | Video of the TV start with the stopwatch (time of the logo screen) | Not run | | | |
| 1e | Photo of the PLAYERS screen | Not run | | | |
| 1f | Photo of the PLAYERS screen with no network (or N/A) | Not run | | | |
| 2a | Photo of the phone launcher with the app name | Not run | | | |
| 2b | Photo of the phone in portrait | Not run | | | |
| 3a | Photo of the phone with the PIN pad | Retest | R1 | Chat report 2026-10-09 (no file) | R1: the owner found the Continue button redundant (it was the only focus target) and the count of players repeated the slot list. Changed on 2026-10-09 (FD-17, REQ-FL-6, 7): the button and the count are gone, and 'PRESS OK TO CONTINUE' shows once a phone has joined. The old check cannot pass any more. Retest the new screen. |
| 4a | Photo of the phone list with the button '<code> x/y' | Not run | | | |
| 4b | Photo of the phone after the join | Not run | | | |
| 4c | Video of the tap on Refresh with the stopwatch (seconds until the TV shows) | Not run | | | |
| 4d | Video on the Mac: list empty for 30 s, then the TV after Refresh, with the seconds | Not run | | | |
| 5 | (Removed with the join by IP address) | Not run | | | |
| 6a | Photo of the TV slots 5 s after the tap, and the seconds until the slot is empty | Not run | | | |
| 6b | Video of the app start in portrait: splash, then the Connect screen | Not run | | | |
| 6c | Photo of the Connect screen | Not run | | | |

Items 3b, 3c, 3d and 6d moved to the automated tests (docs/AUTOMATED_TESTS.md, A-1-3, A-1-6). Steps 8.5a and 8.5b of Test 8 (the Android TV home row) are now part of step 1a. The numbers of the other items do not change.

Measurements (not steps): write the time of the logo screen (1d), the time of Refresh (4c) and the time of the scan (4d) in the Notes of the step.

History:

- R1: **Retest** (step 3). Design change after the first run on a real Android TV. See the row of step 3a.
- R0: **Fail**. Join by room code failed with 'Room YCNW not found, is the tv on the same wi-fi?'. The list and the IP worked. TV app on a desktop, phone on the same Wi-Fi. The plan has no join by room code now, so every step needs a retest.

## Test 2

### QR scan (plugin, unverified)

Needs: 1 phone, 1 TV, a stopwatch, a second QR code that is not from Sababi (for example a code with the text `https://example.com`). Covers: RISKS C5.


**Steps**

1. Tap **Disconnect**. Look at the Connect screen. Check: the button says **SCAN QR CODE**. If it says **PASTE ROOM LINK**, the plugin is not in the build (that button is only for a phone with no scanner). Run `tools/patch_android_manifest.sh controller` and export the controller again.
2a. Tap the button and scan the QR code on the TV. Check: the phone shows "WAITING FOR THE HOST" less than 5 seconds after the scanner closes (stopwatch).
2b. Check: the PIN pad did not open at any time (the QR code holds the PIN). (Changes with issue #52: the QR code holds no PIN.)
3a. Tap the scan button, then press Back in the scanner. Check: the Connect screen shows no message that starts with "QR SCAN FAILED".
3b. Check: the app did not close, and a tap on the scan button opens the scanner again.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Phone screenshot of the connect screen: the button text | Not run | | | |
| 2a | Screen recording of the scan, with the seconds to join | Not run | | | |
| 2b | Screen recording of the scan: the PIN pad does not show | Not run | | | |
| 3a | Phone screenshot after Back in the scanner | Not run | | | |
| 3b | Note: the app is open; `adb logcat -d -s godot > docs/evidence/2/<run>-log.txt` if it crashes | Not run | | | |

Item 4 (a QR code that is not from Sababi) moved to the automated tests (docs/AUTOMATED_TESTS.md, A-2-4). Items 1, 2a, 3a and 3b stay: they need the real scanner. Item 2b changes with issue #52 and stays until then. The numbers of the other items do not change.

History:

- R0: **Pass**.

## Test 3

### Sensor directions

Needs: 1 phone, 1 TV, a protractor or a phone angle app (for the tilt angle). Covers: RISKS A2.

Before the test: **Invert axes** is off (Settings screen of the TV). Open the debug overlay on the TV (Menu key or F3, or OPTIONS, SETTINGS, DEBUG OVERLAY). Hold the phone in portrait with the screen toward you. Start a Treasure Maze round for items 2b and 3b. Read the row of the phone in the overlay (column `Accel m/s2` and column `Gyro rad/s`).

| Item | Action | Check |
|------|--------|-------|
| 1 | Phone flat, screen up, still for 3 seconds | `Accel` x and y are between -0.5 and +0.5, and z is between +9.3 and +10.3 |
| 2a | Tilt the right side down to about 45 degrees | `Accel` x is below -4.0 |
| 2b | Same tilt, in the maze | The ball rolls toward the right edge of the TV screen |
| 3a | Tilt the top of the phone up to about 45 degrees | `Accel` y is above +4.0 |
| 3b | Same tilt, in the maze | The ball rolls toward you (toward the bottom edge of the TV screen) |
| 4 | Turn the phone to the left on a table (counterclockwise seen from above) at about 90 degrees in 1 second | `Gyro` z is above +1.0 rad/s at its peak (a turn to the right gives a negative peak). No game uses the yaw now. |

If a check fails, do not use **Invert axes**: write the axis and the values in the Notes and tell Claude (RISKS A2: the fix is in `sensor_sampler.gd`).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Overlay screenshot: Accel x, y, z (flat, still) | Retest | R0 | | Before the fix the phone reported z = -9.83. The fix is in `sensor_sampler.gd`. The value after the fix was not written down. |
| 2a | Overlay screenshot with Accel x (write the value) | Pass | R0 | | R0: after the fix the tilt directions in the maze are right. |
| 2b | Video of the ball rolling right | Pass | R0 | | R0: after the fix the tilt directions in the maze are right. |
| 3a | Overlay screenshot with Accel y (write the value) | Pass | R0 | | R0: after the fix the tilt directions in the maze are right. |
| 3b | Video of the ball rolling toward you | Pass | R0 | | R0: after the fix the tilt directions in the maze are right. |
| 4 | Overlay screenshot at the peak of the turn: Gyro z (write the value) | Retest | R0 | | R0: the gyro rows were not checked again after the fix. |

History:

- R0: **Pass**. The phone reported every accelerometer axis inverted (flat, screen up: z = -9.83). Fixed in `sensor_sampler.gd`. No invert switch is needed. After the fix: the tilt directions in the maze are right. The gyro rows were not checked again, so Test 3 needs a retest of items 1 and 4.

## Test 4

### Latency and packet rate

Needs: 1 to 4 phones, 1 TV, a phone camera (240 fps), a stopwatch. Covers: RISKS A3, B1, B2, B3, B5, B6.

Setup (not a step): write in the Run log if the TV is on Ethernet or Wi-Fi, and if the game mode of the TV is on or off (RISKS B6: turn it on). Open the overlay (Menu key or F3).

Reading rule: for each phone, read the overlay row at 10 s, 20 s and 30 s of a 30 second window. The worst value of the three readings counts.

| Value | Good | Acceptable | Problem | Pass if |
|-------|------|------------|---------|---------|
| RTT ms | below 20 | below 40 | above 60 | below 40 |
| Rx Hz | 58 to 60 | 50 to 58 | below 50 | 50 or more |
| Gap ms (longest gap in 1 s) | below 40 | below 80 | above 100 | below 80 |
| Lost | 0 | 0 | any (gaps in the sequence number) | 0 |

**Steps**

1a. 1 phone on the Games screen. Keep the phone still for 30 seconds, then move it for 30 seconds. Check: RTT ms is below 40 in both windows.
1b. Play a Treasure Maze round with 4 phones for 60 seconds. Check: RTT ms is below 40 in all 4 rows.
2a. Same as 1a. Check: Rx Hz is 50 or more in both windows.
2b. Same as 1b. Check: Rx Hz is 50 or more in all 4 rows.
3a. Same as 1a. Check: Gap ms is below 80 in both windows.
3b. Same as 1b. Check: Gap ms is below 80 in all 4 rows.
4a. Same as 1a. Check: Lost is 0 in both windows.
4b. Same as 1b. Check: Lost is 0 in all 4 rows.
5. Total delay. Put the phone camera (240 fps, slow motion) so that it films the phone and the TV in one picture. Move the phone quickly in the maze. Count the video frames between the first movement of the phone and the first movement of the ball (1 frame = 4.2 ms). Do this 5 times. Check: the median is 150 ms or less (36 frames). 100 ms or less (24 frames) is good.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a (RTT ms: good below 20, acceptable below 40, problem above 60) | Overlay screenshots at 10, 20 and 30 s, still and moving (write the 6 values) | Fail | R0 | | R0: above 60 ms (exact value not written down). TV app on a desktop, not a TV box. |
| 1b (RTT ms, 4 phones) | Overlay screenshots at 10, 20 and 30 s (write the 4 worst values) | Fail | R0 | | Same result as step 1a (the step was split). |
| 2a (Rx Hz: good 58 to 60, acceptable 50 to 58, problem below 50) | Same screenshots as 1a | Retest | R0 | | R0: 'above 55' (exact value not written down). Desktop TV. |
| 2b (Rx Hz, 4 phones) | Same screenshots as 1b | Retest | R0 | | Same result as step 2a (the step was split). |
| 3a (Gap ms: longest gap in 1 s; good below 40, acceptable below 80, problem above 100) | Same screenshots as 1a | Fail | R0 | | R0: 150 to 380 ms. Desktop TV. |
| 3b (Gap ms, 4 phones) | Same screenshots as 1b | Fail | R0 | | Same result as step 3a (the step was split). |
| 4a (Lost: good 0) | Same screenshots as 1a | Pass | R0 | | R0: 0. |
| 4b (Lost, 4 phones) | Same screenshots as 1b | Pass | R0 | | Same result as step 4a (the step was split). |
| 5 (Total delay with a camera: 100 ms or less good, 150 ms or less pass) | Slow motion video (240 fps), table of the 5 frame counts and the median | Not run |  | | Not tested in R0. |

The same four values are read on the loopback by the automated tests (docs/AUTOMATED_TESTS.md, A-4-1), with looser limits because a headless frame is 17 ms. That does not answer this test: the numbers of the real radio, a real TV box and the camera stay here.

Measurements (not steps): the values read in R0 are in the Notes. Write the exact values of each reading in the Notes of the step.

History:

- R0: **Fail**. RTT above 60 ms, Rx Hz above 55, Gap 150 to 380 ms, Lost 0. TV app on a desktop (not a TV box), phone on the same Wi-Fi: not yet representative of a real TV. The total delay (camera) was not tested.

## Test 6

### Treasure Maze

Needs: 1 to 4 phones, 1 TV, a protractor app, a child of about 5 to 8 years for step 7g. Covers: REQ-MZ-3 to 9, REQ-MZ-12, REQ-MZ-13, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-90 to 95.


**Steps**

4a. Play the maze with 2 phones, then with 4 phones. Open the debug overlay. Check on every row, during the race: Rx Hz is 50 or more, Gap ms is below 80, and Lost is 0 (the "acceptable" limits of Test 4).
5a. On one real phone, tilt the phone 15 degrees (use a protractor app) to the right and hold it still for at least 3 seconds. Tap **RECENTER**. Keep holding the phone at the same angle for 5 seconds. Check: the ball moves less than one ball width (36 px) in the 5 seconds after the tap. (Changes with issue #55.)
7e. In each theme, stand 3 m from the TV. Check: a person reads aloud the names of the two pictures at each side of the maze from this list, with 0 errors in 6 pictures: Garden tree and rose bush, Castle torch and shield, Ice penguin and iceberg (REQ-MZ-13).
7f. Bring a ball to the chest. Check: the lid of the chest opens and the gold shows.
7g. Check with a child of 5 to 8 years. Say only: "Where do you need to go?" Check: the child points to the chest within 10 seconds of "GO", without help.

Items 1, 2a, 2b, 2c, 4b, 5b, 5c, 6a to 6h, 7a to 7d and 7h moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-6-1 to A-6-7). Item 3 was removed earlier. Items 5a and 7f keep only what a machine cannot show (a real phone; the drawn lid). The numbers of the other items do not change. The result menu has New game and returns to the view with the last choice (A-11-5), the rows of the result menu (A-11-1, A-11-2).

Measurements (no pass or fail; tune the constants if the owner asks): with the phone tilted 15 degrees the ball speeds up by about 670 px/s2 (`TILT_ACCEL` 2600, `FRICTION` 1.6, `MAX_SPEED` 760). The crossing time of the longest corridor of Easy, Medium and Hard is printed by `tests/smoke_maze.gd`.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 4a | Overlay screenshot of every row during the race (2 phones and 4 phones) | Not run | | | |
| 5a | Video of the ball: tilt, RECENTER, 5 s | Not run | | | |
| 7e | Note: the 6 names read aloud | Not run | | | Same result as old item 7. |
| 7f | Photo of the open chest | Not run | | | Same result as old item 7. |
| 7g | Note: time in seconds until the child points to the chest | Not run | | | Same result as old item 7. |

History:

- 2026-10-20 (not run): the steps were made measurable and split (items 2, 4 to 7 got letters; item 3 is removed; 2b, 6h limits and 7e to 7h are checks with numbers). Feel notes moved to Measurements.
- 2026-10-20 (automated): 20 steps moved to the automated tests. Items 1, 2a and 2c had a Pass in R1 (the owner's chat report); the machine now checks the same rules, and the results stay in the result database. The torch flames of the Castle theme are built (REQ-MZ-14) and tested. Hebrew wording of the title (old 7h) is a string review in the pull request.
- 2026-10-10 (not run): item 7 is new: the maze world is a pixel world (phase 4 of the arcade style), walls 12 px, Hard cells 76 px.
- 2026-10-09 (not run): item 6 is new (REQ-MZ-9, REQ-GM-90 to 97): the settings view, the three difficulties, the yellow chosen value, Back and Start on one line, and Start dimmed when no phone fits.
- R1: items 1 to 3 **Pass** (the owner: 'it works perfectly'). Items 4 and 5 are not run: 2 to 4 phones, and RECENTER with A and B.
- R0: **Retest**. First run: drift and inverted controls (caused by 'Invert axes' being on). After the fix the maze looks good on the desk. The feel and the constants were not judged. Item 5 is new (RECENTER, and A and B do nothing).

## Test 7

### Disconnect and reconnect

Needs: 2 phones, 1 TV, a stopwatch, a third phone to call (for item 7). Covers: REQ-GM-30, REQ-GM-30a, REQ-T5, REQ-N5, REQ-N6, REQ-FL-25, REQ-FL-52, REQ-MR-14, REQ-MZ-8.

Time limit used below: the TV pauses when a phone is silent for 5 seconds (`Protocol.PEER_TIMEOUT_MS`), so "at once" means 8 seconds at most, measured from the moment you switch the Wi-Fi off. (Changes with issue #56: 3 seconds, so 6 seconds at most.)

**Steps**

1a. With two phones joined, during the maze, switch the Wi-Fi of one phone (2P) off for 15 seconds. Check: the phone shows "RECONNECTING..." within 8 seconds, and the TV pauses (the maze stops) and shows the card "2P LOST CONNECTION" with the line "WAITING TO RECONNECT" within 8 seconds (stopwatch from the moment the Wi-Fi goes off).
1d. Switch the Wi-Fi on. Check: within 10 seconds the card title changes to "2P reconnected" and the card shows the button **Resume**. Wait 10 seconds without a press. Check: the maze stays paused (the ball of 1P does not move).
2. On the Games screen, lock the phone screen for 10 seconds, then unlock. Check: within 10 seconds the phone shows its waiting screen again with the same slot number, and the TV slot was "READY" all the time or came back to "READY". (Android can stop the app in the background.)
3a. On the Games screen (not in a game), switch the phone Wi-Fi off for 45 seconds. Check: after 45 seconds the TV shows the slot of the phone as empty. (Changes with issue #44: the slot is empty within 5 seconds.)
3b. Switch the Wi-Fi on. Check: within 10 seconds the phone shows the PIN pad (the TV does not know it any more). (Changes with issue #52: no PIN pad.)
3c. Type the PIN. Check: the phone joins again and shows "CHOOSE A GAME ON THE TV" (maybe in a different slot).
4a. Start the maze with two phones. Switch one phone Wi-Fi off and wait for the card. Choose **Resume without 2P** (for a player with a profile the card says its name, Test 20 item 6). Check: the game continues without that player: the ball of that player is gone and the other ball moves within 3 seconds.
4b. Switch the Wi-Fi on. Check: within 10 seconds the phone shows the PIN pad. (Changes with issue #52.)
5a. With only one phone joined, switch its Wi-Fi off during the maze. Check: within 8 seconds the game pauses with the card "1P LOST CONNECTION" that has only **End game** (no Resume, because nobody is connected).
5b. Switch the Wi-Fi on. Check: the card says "1P reconnected" and offers **Resume**.
5c. Do steps 5a and 5b in Road Rally. Check: the same card and the same buttons both times.
5d. Do steps 5a and 5b in Banana Party. Check: the same card and the same buttons both times.
6a. On the phone pad, tap **Disconnect** once. Check: the phone shows the Connect screen less than 1 second after the tap (no second tap).
7a. With one phone in a game, call that phone from another phone and answer. Check: within 8 seconds of the answer the game pauses with the card "1P LOST CONNECTION".
7b. End the call and go back to the controller app. Check: the phone says "RECONNECTING..." and then joins again in 10 seconds or less (stopwatch from the return to the app).
7c. Check: the card says "1P reconnected" with **Resume**, and **Resume** goes on with the game.
7d. Do a call that lasts 70 seconds (the slot is kept 5 minutes while the game is paused). Check: after the call the phone joins again in the same slot, with no PIN.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Video of the phone and the TV with the stopwatch: 'RECONNECTING...', the card and the seconds | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the phone disconnected from the Wi-Fi and showed 'Reconnecting...', but on the TV the game kept going (no pause, no card). The off time was not written down (it must be more than 5 s). Cause (found on 2026-10-09): the TV waited for a close handshake that a phone with no Wi-Fi cannot answer, so it never marked the phone lost. The same failure was seen in R0. Fixed on 2026-10-09 (a silent phone is lost at once, PROTOCOL.md) and the pause changed (REQ-GM-30). A test now reproduces it. Retest. |
| 1d | Video: Wi-Fi on, the card title 'reconnected', 10 s wait | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as step 1a (the step was split). |
| 2 | Note: the seconds the phone needs to show its waiting screen, the slot number before and after | Not run | | | |
| 3a | Photo of the Games screen after 45 s (slot empty) | Not run | | | |
| 3b | Photo of the phone PIN pad, with the seconds | Not run | | | |
| 3c | Photo of the phone after the PIN | Not run | | | |
| 4a | Video: Resume without 2P with a lost phone | Not run | | | |
| 4b | Photo of the phone PIN pad | Not run | | | |
| 5a | Photo of the card of the only player lost (End game only), in the maze | Retest | R1 | Chat report 2026-10-09 (no file) | R1: a phone call stopped the game ('as expected') and the TV showed 'No players connected'. After the call there was no way to resume. The owner asked for a message that says which player disconnected, with Resume only when a player is still connected or the disconnected player is back. Changed on 2026-10-09 (REQ-GM-30, 30a): the game waits with a card, there is no Resume while nobody is connected, and Resume shows when the phone is back. The slot is kept 5 minutes while paused. The old check ('No players connected' at once) is gone. Retest. |
| 5b | Photo of the card after the return (Resume), in the maze | Retest | R1 | Chat report 2026-10-09 (no file) | Same result as step 5a (the step was split). |
| 5c | Photos of the card (End game only) and after the return (Resume), in Road Rally | Retest | R1 | Chat report 2026-10-09 (no file) | Same result as step 5a (the step was split). |
| 5d | Photos of the card (End game only) and after the return (Resume), in Banana Party | Retest | R1 | Chat report 2026-10-09 (no file) | Same result as step 5a (the step was split). |
| 6a | Video of the tap and the Connect screen (the seconds) | Not run | | | |
| 7a | Video of a phone call: the card, with the seconds | Not run | | | |
| 7b | Video of the return: 'RECONNECTING...', the join, the seconds | Not run | | | |
| 7c | Video: the card 'reconnected', Resume, the game goes on | Not run | | | |
| 7d | Video of the 70 s call and the return, same slot | Not run | | | |

Items 1b (merged into 1a), 1c, 1e, 4c, 5e and 6b to 6e moved to the automated tests (docs/AUTOMATED_TESTS.md, A-7-1, A-7-4, A-7-5, A-7-6). The numbers of the other items do not change.

Measurements (not steps): write the reconnect time after the call (7b) in the Notes of step 7b.

History:

- R1: **Fail** (item 1) and **Retest** (item 5). A phone without Wi-Fi did not pause the game, and a phone call ended it with no way to resume. Both changed on 2026-10-09 and wait for the retest. Items 2, 3, 4 and 6 are not run.
- R0: **Retest**. Wi-Fi off on the phone: the phone shows 'Reconnecting...'. The game kept running and the TV never showed 'Waiting for P1 to reconnect'. Wi-Fi on: the phone reconnected and the game went on. The off time was not measured (the TV pauses only after 5 s of silence). Item 6 (Leave twice, A green and B red) is new.

## Test 8

### TV remote

Needs: 1 phone, 1 TV with its remote, a stopwatch. Covers: REQ-GM-31, REQ-GM-31a, REQ-GM-33, REQ-FL-41, REQ-FL-55.


**Steps**

1a. Use only the remote. On each of these 7 screens press Up, Down, Left and Right once each: Connect, Games, Players modal, OPTIONS (Settings), the settings view of a game, the pause menu and the result menu. Check: on each screen the focus moves at least once, and OK selects the focused item (REQ-GM-33).
1d. Stand 3 m from the TV. A second person presses keys on the 7 screens of step 1a without saying where the focus is. Check: you name the focused item on 7 of 7 screens, also in Settings.
2c. In a game press Back on the real remote. Check: the question "END THE GAME?" opens and the timer on the TV shows the same value 5 seconds later (REQ-FL-55). (Changes with issue #53.)
2f. Play a game to its result menu. Press Back. Check: the Games screen shows at once, with no question.
3a. On the Games screen press Back on the real remote. Check: the Connect screen shows, the app is still open 5 seconds later, and the player slots are still filled (same number of players).
3b. Press Back on the Connect screen. Check: the quit question opens with **Stay** in focus.
4. Press the Menu key. If the remote has no Menu key, open **Settings** (the OPTIONS button on the Games screen) and use **Debug overlay**. Check: the overlay shows the header line that starts with "DEBUG" and the FPS number.
6a. On the phone, press the Android Back key on the waiting screen (joined, the TV on the Games screen). Check: the question "QUIT SABABI?" opens with **Stay** in focus and the app is still open 5 seconds later. (Changes with issue #54: no phone button has the focus.)
6b. Press the Android Back key in the middle of a game (the pad screen). Check: the same question opens and the app is still open 5 seconds later. Tap **A** 5 times while the question shows. Check: the TV shows no action of A.
6d. Press Back, then choose **Quit**. Check: the app closes (REQ-FL-55).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Video of the 4 keys on each of the 7 screens | Not run | | | |
| 1d | Note: 7 answers of the second person | Not run | | | Same result as old item 1. |
| 2c | Video of Back during play, with the timer | Fail | R1 | Chat report 2026-10-09 (no file) | R1: pressing Back on the remote in the middle of a game quits the app completely. The 'End the game?' question was not seen. Cause: the engine setting `quit_on_go_back` was on, so the engine quit after the app had handled Back. Fixed on 2026-10-09 (REQ-FL-55). Retest. The OK key and the pause menu were not reported. Items 2a, 2b, 2d, 2e of this result moved to the automated tests. |
| 2f | Video of Back on the result menu | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as old item 2. |
| 3a | Video of Back on the Games screen, with the slots visible | Fail | R1 | Chat report 2026-10-09 (no file) | R1: Back quits the app on every screen. The owner saw the app go back to the previous view for a moment before it closed. Same cause and fix as item 2. Retest. |
| 3b | Photo of the quit question | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as old item 3. |
| 4 | Photo of the overlay after the Menu key, or of the Settings switch | Not run | | | |
| 6a | Video of Back on the phone waiting screen, with the stopwatch | Not run | | | The question and its answers are tested without a phone (`ui_states`); only the real Back key is open. |
| 6b | Video of Back on the pad screen and 5 taps on A | Not run | | | Same result as old item 6. |
| 6d | Video of Quit | Not run | | | Same result as old item 6. |

Items 1b, 1c, 2a, 2b, 2d, 2e, 5a, 5b and 6c moved to the automated tests (docs/AUTOMATED_TESTS.md, A-8-1 to A-8-6). Items 5a and 5b (the home row of the TV) are now part of step 1a of Test 1. What stays here needs the real remote or the real Android Back key. The numbers of the other items do not change.

History:

- 2026-10-20 (not run): the steps were split and the criteria made measurable (focus on 7 screens, timer values, 5 s). Items 2b to 2e change with issue #53, item 6a with issue #54.
- R1: **Fail** (items 2 and 3). Back quits the app on every screen. Fixed on 2026-10-09 (REQ-FL-55). Items 1, 4 and 5 are not run.
- Item 2 changed before the first run (the 'End the game?' question).

## Test 8b

### The TV flow and the style

Needs: 1 to 2 phones, 1 TV, a stopwatch. Covers: REQ-FL-1 to 46, REQ-FL-56, 57, REQ-FL-81, FD-1 to 17, FD-23. Item 7 (a TV set to Hebrew) moved to Test 17 on 2026-10-10: FD-19 replaced REQ-FL-54, so the TV now offers Hebrew and no longer stays English.


**Steps**

1a. Start the TV app from cold (not the first start: at the first start the logo waits for the language choice). Start the stopwatch when the logo shows. Check: the Connect screen shows after 2 to 3 seconds (REQ-FL-2).
1c. Start the app again. Press Back on the logo screen. Check: the app is still open 3 seconds later (it shows the logo or the Connect screen).
2a. On the Games screen, with one phone joined, look at all tiles. Check: every tile shows its screenshot (no color placeholder), the number of tiles equals the number of games in the registry (9 on 2026-10-20), and each tile shows its title and its player range (REQ-FL-13, 56, 57). (Changes with issue #57: a tile shows only the world of the game.)
2b. Stand 3 m from the TV. Check: you read aloud the title and the player range of 3 tiles, with 0 errors (REQ-FL-40).
3a. Open the **players badge** (OK). Check: the modal shows 4 slots, a QR code, the room code and the PIN. (Changes with issue #52: the PIN goes.)
3b. Press **Remove** on a player. Check: the phone shows "THE HOST REMOVED YOU. SCAN THE CODE TO JOIN AGAIN." and it is still on its Connect screen 30 seconds later (it does not reconnect by itself).
4b. Check: the new phone has no object in the running game.
4c. Finish the round and start the next round. Check: the new phone has its object in the next round.
5a. Check the motion on the TV box with the overlay on: the logo (with its confetti), the blinking prompts and the screen changes. Check: the overlay FPS is 55 or more at all times (REQ-FL-44).
5b. Look at a test screen: a black background, a focused menu item, a modal frame and a tile frame. Check: you name the colors black, yellow, blue and white for them, 4 of 4 correct.
7. (Moved to Test 17.) The old step was: set the TV to Hebrew, region Israel, and check that the app stays English and left to right. FD-19 replaced that rule on 2026-10-10: the app now has Hebrew, and the result of R1 (the mirrored English UI) is not a defect any more.
9a. In English, open three cards: "NO PLAYERS CONNECTED" (in a game with one phone, tap **Disconnect** on the phone; it frees the slot at once), "PAUSED" (OK in a game) and "END THE GAME?" (Back in a game). Check: the title of each card is white and the items below are yellow only with the focus (REQ-FL-81). (Switching the phone Wi-Fi off does not open this card. It opens the card "LOST CONNECTION", REQ-GM-30.)
9b. In Hebrew, open the same three cards. Check: each title is on one line (אין שחקנים מחוברים, מושהה, לסיים את המשחק?).
10c. Play a game in Hebrew with a leader (and Road Rally too). Check: the timer box and the leader chip are at opposite sides of the screen and do not overlap (0 px of overlap in the photo).
10d. Open the result menu in Hebrew. Check: the time says ש׳ and each row has the avatar next to the color.
10e. On the phone, look at the waiting screen and the pad. Check: the avatar is beside the color square on both screens.
10f. Play a round with 4 phones to the result menu. Check: row 1 shows the gold medal, row 2 silver, row 3 bronze, and row 4 has none (tie and solo rules: A-11-7).
10g. Games screen: scroll down to the second row of games, move up to the first row, on to the players badge, then to OPTIONS, in English and in Hebrew. Check: OPTIONS is reached in both languages.

Items 1b, 3c, 4a, 6a, 6b, 8a, 8b, 8c, 10a and 10b moved to the automated tests (docs/AUTOMATED_TESTS.md, A-8b-1 to A-8b-10). The numbers of the other items do not change.

Covered by machines (not repeated here): the buttons TRY AGAIN, NEW GAME and BACK TO MENU of the result menu (A-11-1) and the medals of a tie or a solo round (A-11-7).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Video from cold start with the stopwatch: logo, then Connect | Not run | | | |
| 1c | Video of Back on the logo, 3 s | Not run | | | Same result as old item 1. |
| 2a | Photo of the Games screen with all tiles | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the screenshots of the games are missing on the Games screen of the Android 10 TV. What the tiles showed instead (dark boxes, colors) was not written down. The same tiles show on a desktop with the OpenGL renderer. The cause is not confirmed. Changed on 2026-10-09 (REQ-FL-56, 57): the image is rounded in the file and not clipped, a placeholder shows when a tile does not load, and a warning goes to the log. Retest. If they are still missing, save `adb logcat -d -s godot` and look for 'Tile image'. |
| 2b | Note: the 3 tiles read aloud with the errors counted | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as old item 2 (split 2026-10-20). |
| 3a | Photo of the Players modal | Not run | | | |
| 3b | Photo of the phone after Remove, and 30 s later | Not run | | | Same result as old item 3. |
| 4b | Photo of the running game with the new phone in the room | Not run | | | Same result as old item 4. |
| 4c | Photo of the next round with the new object | Not run | | | Same result as old item 4. |
| 5a | Overlay FPS screenshot during the logo, tile growth and screen changes | Not run | | | |
| 5b | Photo of the test screen; note: the 4 color names | Not run | | | Same result as old item 5. |
| 7 | (Moved to Test 17.) Photos of the Connect and Games screens on a TV set to Hebrew; of the phone set to Hebrew | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the TV is set to the IL region and Hebrew. The text was English, but the layout was mirrored (right to left). Fixed on 2026-10-09 (REQ-FL-54): the app sets the locale to English and the layout to left to right. Retest on the TV. The phone was not tried. |
| 9a | Photos of the three cards in English | Not run | | | |
| 9b | Photos of the three cards in Hebrew | Not run | | | Same result as old item 9. |
| 10c | Photo of the HUD of a game and of Road Rally in Hebrew | Not run | | | Same result as old item 10. |
| 10d | Photo of the result menu in Hebrew | Not run | | | Same result as old item 10. |
| 10e | Photos of the phone header on both screens | Not run | | | Same result as old item 10. |
| 10f | Photo of the 4-player result menu | Not run | | | Same result as old item 10. |
| 10g | Video of the focus path to OPTIONS in both languages | Not run | | | Same result as old item 10. |

History:

- 2026-10-20 (not run): the steps were split and the criteria made measurable (times, key counts, color names, 55 FPS). Item 3a and 4a change with issue #52, 2a with issue #57.
- R1: **Fail** (items 2 and 7). The tile screenshots are missing, and the layout is mirrored on a TV set to Hebrew. Both changed on 2026-10-09 and wait for the retest. The other items are not run.

## Test 9

### Road Rally

Needs: 1 to 4 phones (2 to 4 for step 11a), 1 TV, a phone camera, a child of about 5 to 8 years for step 13h. Covers: REQ-MR-*, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Needs 1 to 4 phones (one phone is a time trial). Requirements: `docs/games/marble_race.md`. Start "Road Rally" and pick a track.


**Steps**

1c. Stand 3 m from the TV. Check: you read aloud the title, the timer and the distance text ("Finish in N m") with 0 errors.
6. Play a race with 4 phones on a Hard track in each of the 3 themes. Check: the frame rate in the debug overlay is 55 or more, 5 readings in a row in each theme, and the road shows in the first frame after Start (no black road for more than 1 second). (REQ-GM-50)
11a. After a change to the shared game code (the countdown clock, the buzz cool-down, the end with no players), run this test again with 2 real phones on each track. Check: no phone buzzes in "3, 2, 1" and each phone buzzes once at "GO" (A-multi_phone covers the simulated phones only).
13b. Play one race in each theme. Check: the three obstacles match the theme: candy lollipops, gumdrops and cupcakes; space asteroids, satellites and craters; jungle logs, boulders and tiki masks. You name all 3 kinds in each theme with 0 errors from a photo. (The lists of obstacles are checked by A-9-13b.)
13e. Check: the scenery beside the road matches the theme (REQ-MR-57: candy lollipops, canes, ice creams, donuts, cookies; space rockets, planets, UFOs, stars; jungle palms, bushes, flowers, mushrooms) and 0 pieces cover the road or a car in the photo.
13h. Check with a child of 5 to 8 years. Ask: "Show me your car." Check: the child points to its own car within 10 seconds of "GO", without help. Ask: "Show me one thing you can hit." Check: the child points to an obstacle within 10 seconds.

Items 1a, 1b, 1d, 2a, 2b, 3a, 3b, 5a, 5b, 7a, 7b, 8a, 8b, 9a to 9e, 11b, 11c, 12a to 12d, 13a, 13c, 13d, 13f and 13g moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-9-1 to A-9-13). Item 1c keeps the reading from 3 m, item 6 keeps the frame rate on the TV box (it also holds the frame rate of old item 12d), item 13b keeps the naming of the pictures. Item 13e stays manual until the owner has decided which list of scenery is right (see the notes of this change). Items 4 and 10 were removed earlier (10 is A-9-10). The numbers of the other items do not change. The result menu with Try again, New game and Back to menu is covered by A-11-1 and A-11-5.

Measurements (no pass or fail): note how the car feels at `ACCEL` and `DAMPING` and tell the owner if a constant needs a change. The winning times of the 69 races of `tests/race_bot.gd` are printed by that test.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1c | Photo of the screen edges; note: the 3 texts read aloud | Not run | | | Same result as old item 1. |
| 6 | Overlay screenshot (FPS), 5 readings in each of the 3 themes, 4 phones on a Hard track | Not run | | | Now holds old item 12d (frame rate in each theme). |
| 11a | Video of the countdown and GO with 2 phones on each track | Not run | | | |
| 13b | Photo of each theme with the obstacles | Not run | | | Same result as old item 13. |
| 13e | Photo of the scenery of each theme | Not run | | | Same result as old item 13. |
| 13h | Note: the two times in seconds | Not run | | | Same result as old item 13. |

History:

- 2026-10-20 (not run): the steps were made measurable and split. Item 4 (feel) is removed. Items 8b and 9e are new checks (REQ-MR-8, REQ-MR-52). Item 11b changes with issue #55.
- 2026-10-20 (automated): 29 steps moved to the automated tests (see the note above the Results table). The limit of old item 11b is 20 px (decided by the owner; measured 7.6 px in the test). The Hebrew wording check of old item 13g is a string review in the pull request.
- 2026-10-09 (not run): the four hand-made tracks were replaced by generated tracks, and item 9 is new: the settings view with Difficulty and the track carousel (10 sketches and a '?', the middle one is chosen, yellow border), difficulty by the number of obstacles (Easy 2, Medium 6, Hard 10 for each 100 m). The results menu has Settings, not Choose track.
- 2026-10-10 (not run): item 12 is new: the 3D world is drawn in a 480x270 pixel view (phase 3 of the arcade style), and the cars have their slot number on them.
- -: **Not run**. Not run on a device yet. Item 11 is new: run it again after a change of the shared game code (PR 12 changed the countdown, the buzz limit and the end with no players).

## Test 10

### Banana Party (pointer)

Needs: 1 to 4 phones, 1 TV, a second phone with an angle app (or a paper protractor), and a child of about 5 to 8 years for steps 9a and 9b. Covers: REQ-SS-*, REQ-GM-47i to 47n, REQ-GM-80 to 84, 90 to 95, RISKS A4, REQ-GM-37, REQ-GM-50.

Hold each phone like a remote control, pointing at the TV, from the sofa (about 3 m). This is the first game that uses the
gyroscope pointer, so this test also checks the pointer itself (the old Test 5 for drift was removed).
The game was "Target Shoot" until 2026-10-09: it was changed after the first try (see History).
Record every video at 30 frames per second or more. "Screen width" means the width of the TV picture. "Center" means the middle of the play area.

**Steps**

3a. On one real phone, hold the phone still toward the TV after "GO" for 40 seconds (stopwatch). Check: the cursor moves less than 5% of the screen width from its first place. (RISKS A4, REQ-GM-37. The drift of a simulated gyro with an offset is checked by A-10-3a.)
3b. Move the phone away from the TV and back, then tap **RECENTER**. Check: the cursor goes to the center, less than 5% of the screen width from it. (REQ-GM-37)
4c. Hit one animal of each kind. Check: after each hit the animal shows closed happy eyes (^) and a banana peel falls beside it, and each kind has its own cheer: gorilla shakes, sloth wiggles slowly, lemur turns on the spot, elephant sprays water, orangutan has hearts, monkey has sparkles. (REQ-SS-7, 13. The points, the text and the effect of each kind are checked by A-10-4b.)
5a. Play 60 seconds. Check: a second person with the list monkey, lemur, orangutan, sloth, gorilla, elephant names each animal that the tester points to on the TV, from 3 m. All six names are correct. Check: the golden monkey king, when it comes, shows a gold crown. (REQ-SS-7, 12, 25)
7c. Play a full round with 4 phones. Check: the debug overlay shows 55 frames per second or more during the whole round (60 expected). (REQ-GM-50)
9a. Let a child of about 5 to 8 years play 1 round, with a grown-up next to them. The grown-up reads the hint line once and says nothing more. Check: the child hits at least 1 animal within the 60 seconds, and nobody touches the phone for the child. Write down the age. (REQ-GM-80 to 84, REQ-SS-17)
9b. The child plays a second round. Check: the child plays both rounds to the end without asking to stop or crying, and answers "yes" when asked "again?" (yes or no). Write down the words of the child. (REQ-GM-80 to 84, REQ-SS-17)
10c. Play one round alone on each of Easy, Medium and Hard. Count the animals on the screen in the video (the golden monkey does not count). Check: with 1 player, never more than 5 on Easy, 4 on Medium and 3 on Hard; the most you count is equal to that number at least once. (REQ-SS-20: 4, 3, 2 plus 1 player)
11b. From the sofa (about 3 m), play a round. Check: the tester reads aloud the "+10" or "+25" over a hit animal and the score of the round end, without error. (REQ-SS-13, REQ-FL-40)

Items 1a, 1b, 1c, 2a, 2b, 4a, 4b, 4d, 4e, 5b to 5e, 6a to 6c, 7a, 7b, 8a, 8b, 10a, 10b, 10d, 10e, 11a, 11c, 11d, 11e and 11f moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-10-1 to A-10-11). The numbers of the other items do not change. Step 4c holds the drawn part of old item 4b. Step 5a holds the gold crown of old item 5d. Step 10c stays manual because the test counts the animals for 2 players, not for 1 player (see the notes of this change). Whether a real phone buzzes (old item 4d) is Test 18; a real Wi-Fi loss (old item 8a) is Test 7 item 1.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 3a | Photo at the start and at 40 s; the drift in % of the screen width | Not run | | | Now one real phone. The simulated gyro is in A-10-3a. |
| 3b | Video of RECENTER, the cursor in the middle | Not run | | | |
| 4c | Video of each of the six cheers, with the happy eyes and the peel | Not run | | | Now holds the drawn part of old item 4b. |
| 5a | Photo of the animals; the six names that were given; the crown | Not run | | | Now holds the crown of old item 5d. |
| 7c | Overlay screenshot (FPS) with 4 phones | Not run | | | |
| 9a | The age of the child; short video (only with the permission of the parent) | Not run | | | |
| 9b | The words of the child; yes or no for "again?" | Not run | | | |
| 10c | The most animals counted in each round | Not run | | | Added 2026-10-09 (REQ-SS-20 to 22). |
| 11b | Note: the texts that were read aloud | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-16 (jungle, REQ-SS-12). |

Measurements (not a test; no pass or fail). Write these values in the Notes column of the steps above. They decide the first tuning values of the game.

| Value | Step | Result | Run | Notes |
|-------|------|--------|-----|-------|
| Drift after 40 s still (% of the screen width) | 3a | | | |
| Frame rate with 4 phones (aim 60) | 7c | | | |

History:

- 2026-10-20: the steps were rewritten with a measurable Check and split with letters (1a to 11f). Each new step keeps the result of the old step with the same number. Step 8a follows the 5 s rule of REQ-GM-30 (the owner asked for 2 to 3 seconds, planned 3 s in issue #56).
- 2026-10-20 (automated): 29 steps moved to the automated tests. Items 6a, 6b and 6c had the result Retest (R2, the last digit of a score above 3 digits was cut): the machine now checks a score of 1 to 6 digits and a name of 10 letters in the chip (`game_helpers`, `hud_layout`), and the results stay in the result database. The first golden monkey comes 10 to 18 s after GO (the owner's decision; it waits for a free lane). The measurement rows of the removed steps (animal times, medal tiers, pointer range, Wi-Fi wait) are removed.
- 2026-10-10 (not run): item 11 is new: the sky is a pixel world (phase 4 of the arcade style).
- 2026-10-16 (not run): Snowball Splat became **Banana Party** (first Banana Splat; "קרב" means fight in Hebrew, so the owner chose Party): bushes that hide animals (REQ-SS-26, 3, 5 or 8 by difficulty), a jungle at sunset, six animals that eat bananas in three depth lanes, a hit animation for each, plain ring pointers and the golden monkey king (100 points). Items 4, 5 and 11 changed (REQ-SS-7 to 13, 25). All values are first guesses.
- 2026-10-09 (not run): item 10 is new: the settings view and Easy, Medium and Hard for Snowball Splat (faster and fewer Puffs as it grows, medal tiers for each level, the title names the difficulty).
- R2: the owner played the new game and reported one problem: the last digit of a score above 3 digits was not visible in the chip at the top. Fixed on 2026-10-09. Nothing else was reported, so the other items stay not run.
- R1: **Fail**, then redesigned. The owner tried the first version ("Target Shoot", small fast targets, a lock after a miss, decoys) and said: "I don't think it's playable in its current definition." They asked for something like Duck Hunt with larger and slowly moving targets, no penalty for a miss, and a game that is also for kids, so not shooting but for example throwing snowballs at a made-up character. Changed on 2026-10-09: the game is now Snowball Splat (REQ-SS-*), and REQ-GM-80 to 84 are new for all games. Which steps failed was not reported. The whole test needs a run with the new game.

## Test 11

### Result menus (REQ-GM-72)

Needs: 1 to 4 phones, 1 TV, a camera for photos. Covers: REQ-GM-34, REQ-GM-40, REQ-GM-41, REQ-GM-72, REQ-GM-73, REQ-GM-73a, REQ-MZ-5, REQ-MR-31.

1 to 4 phones. Tests the ranked result menu (REQ-GM-72) that every game with scores uses. Here: the maze and the race. New. Added with the shared game code (PR 12).
"Screen edge" means the edge of the TV picture. The margin must be 60 px at 1080p, that is 3.1% of the screen width (REQ-GM-41). Measure it on the photo. Read from the sofa (about 3 m).

**Steps**

1a. Maze with 1 phone: finish the maze. Check: the tester reads aloud the title and the first row (name and score text) of the result menu from 3 m, without error. (The rows, the title and the buttons are checked by `docs/AUTOMATED_TESTS.md`, A-11-1.)
1b. Look at the same result menu. Check: the tester points to the avatar picture and to the square in the slot color next to the name (2 of 2 found). (REQ-GM-72. The color of the square and the medal of one player are checked by A-11-1b.)
2b. Maze with 2 to 4 phones: let one ball reach the exit first and leave the others behind. Look at the result menu from 3 m. Check: the tester reads aloud the winner row and the row "NOT FINISHED" without error. (The gold medal of the winner, REQ-GM-73a, and the buttons are checked by A-11-2b.)
3a. Road Rally with 4 phones on any track: let all cars finish. Take a photo of the whole TV. Check: the card with the list and the 3 buttons (Try again, New game, Back to menu) is 3.1% of the screen width or more from every screen edge. (The rows, the order and the 60 px edge of the layout are checked by A-11-3. The photo shows the real TV, which may cut the picture.)
3b. Look at the same card from 3 m. Check: the tester reads aloud the 3 button names and the names of the 4 players without error. (A-11-3.)

Items 2a and 3c moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-11-2a, A-11-3c). Items 4, 5, 6, 7 moved earlier (A-11-4 to A-11-7). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the result menu (1 phone) from the sofa; the text that was read | Not run | | | |
| 1b | Photo of the first row: avatar, square | Not run | | | |
| 2b | Photo of the result menu with 'not finished' rows; the text that was read | Not run | | | |
| 3a | Photo of the whole TV with the race results (4 rows); the margin in % of the screen width | Not run | | | |
| 3b | Photo of the race results from the sofa; the text that was read | Not run | | | |

History:

- 2026-10-20: the steps were rewritten with a measurable Check and split with letters (1a to 3c).
- 2026-10-20 (automated): item 2a (the same edge check as 3a, on the maze; the layout is tested for both) and item 3c (the colors and the order of the medals) moved to the automated tests. In 1b and 2b only what a person must see is left. REQ-GM-73a (the medal of the place with more than one player) is checked by `results_medals`.
- -: **Not run**. New.

## Test 12

### Game tiles and the toy box look (REQ-GM-49)

Needs: 1 TV (phones for the game photos), a camera for photos. Covers: REQ-GM-49, REQ-FL-20, REQ-FL-40, REQ-GM-41.

Phones are needed only for the photos of the running games. Needs the TV and the Games screen. New. This is the visual check that the `review` skill asks for with a screenshot of the game next to the Games screen.
A tile has a 16:9 picture. The colors and the objects of each tile file (the ground, the 4 player colors, the main objects) are checked by the test `tiles` (A-12-3 to A-12-10); the steps below keep only what the test does not see. Today the tile shows the world of the game with its HUD (score, title). (Changes with issue #57: the tile shows only the world of the game, with no HUD, title bar, leader chip, name tag, score, time, hint or menu text. Then a tile with any of these texts fails. The test `pixel_render` already looks for the black bar and lists it as a known bug.)

**Steps**

1c. Open the Games screen on the TV (the Android build, not the computer). Look at every tile. Check: each of the 9 tiles shows its screenshot, a title and a player range (for example "1-4 PLAYERS"): 9 of 9. (REQ-FL-13. The tile files, their import, the export presets and the player range are checked by A-12-1c.)
1e. From the sofa (about 3 m), look at the Games screen. Check: the tester reads aloud the title and the player range of 3 tiles and the description of the focused game, without error. (REQ-FL-40)
2. For each game, compare its tile with a photo of the game running. Check: the tile has the same background color and the same main objects as the photo (the objects are listed in A-12-3 to A-12-10 and in the steps below). (Changes with issue #57.)
3b. Check the tile of **Road Rally**. Check: the road in the tile turns in a bend (as in Track 1, Hard), with a post beside it. (The 4 cars, the candy ground, the road and the outline of the posts are checked by A-12-3b. Changes with issue #57.)
4. Check the tile of **Banana Party**. Check: an animal was just hit (the text "+10" over it) and a banana is in the air. (The jungle, the four cursor rings, the banana and the black outline of an animal are checked by A-12-4. Changes with issue #57: no score and no "+10" text.)
5. Check the tile of **Paint Grab**. Check: the hidden picture shows in the floor. (The floor, the bonus pot and the four blobs are checked by A-12-5. Changes with issue #57.)
8. Check the tile of **Pin Pals**. Check: the 10 pins stand in a triangle and the ball is between the foul line and the pins. (The lane and the white shapes are checked by A-12-8; the test counts 138 white blobs and does not count the 10 pins. Changes with issue #57.)
9. Check the tile of **Tennis**. Check: the ball is high over the near half of the court. (The grass, the court, the ball and the players are checked by A-12-9. Changes with issue #57.)
10. Check the tile of **Mini Golf**. Check: a ball is between the tee and the hole. (The fairway, the lake, the windmill and the players are checked by A-12-10. Changes with issue #57.)

Items 1a, 1b, 1d, 3a, 6 and 7 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-12-1a, A-12-1b, A-12-1d, A-12-3a, A-12-6, A-12-7). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1c | Photo of the Games screen on the TV; the number of tiles with all 3 parts | Not run | | | Now on the TV only. |
| 1e | Photo from the sofa; the texts that were read | Not run | | | |
| 2 | Photos: tile next to the game, for each game | Not run | | | |
| 3b | Photo of the Road Rally tile and of the running game | Not run | | | Same result as old item 3. Road Rally and Maze tiles remade 2026-10-09 (4 cars on a bend with posts; 4 balls on the way to the exit). |
| 4 | Photo of the tile and of the running game | Not run | | | Banana Party tile remade 2026-10-16 (a jungle, 4 players, a hit, a banana in the air). |
| 5 | Photo of the tile and of the running game | Not run | | | Paint Grab tile remade 2026-10-16. |
| 8 | Photo of the Pin Pals tile next to a photo of the game | Not run | | | |
| 9 | Photo of the Tennis tile next to a photo of the game | Not run | | | |
| 10 | Photo of the Mini Golf tile next to a photo of the game | Not run | | | |

History:

- 2026-10-20: the steps were rewritten with a measurable Check (list of objects in the tile, text read aloud from 3 m) and step 1 and step 3 were split with letters. The sentence "the Games screen and the games look like one toy box" was removed: it has no measure. The owner's run R1 is kept in the result database (step 1 passed, steps 2 to 10 failed because the tiles show the wrapper; planned: issue #57, REQ-GM-49).
- 2026-10-20 (automated): steps 1a, 1b, 1d, 3a, 6 and 7 moved to the automated tests. In steps 3b, 4, 5, 8, 9 and 10 only the composition that the test does not see is left. Open: a title that is wider than its tile (`focus_walk`, known bug) and the missing screenshots on the TV (step 1c on the device).
- -: **Not run**. New.

## Test 13

### Controller on an iPhone

Needs: 1 iPhone, 1 Mac with Xcode, 1 TV, a stopwatch. Covers: `tools/deploy-ios.sh`, RISKS A2, REQ-FL-58, 59, 68, 83, 84. New. Nothing in the iOS path has run yet.
Write the model of the iPhone (for example "iPhone 15 Pro, with Dynamic Island") in the Run log.

**Steps**

1a. Follow `docs/EXPORT.md`, section *Controller on an iPhone*, and run `IOS_TEAM_ID=<team id> tools/deploy-ios.sh`. Check: the export, the build, the install and the launch end, and `echo $?` after the script prints 0. If it fails, save the last 50 lines of the log.
1b. Look at the iPhone. Check: the app opens in portrait, and the home screen icon is named **Sababi: Remote**.
2a. Open the connect screen. Check: there is no scan button and no paste button. The screen shows only **ROOMS FOUND**, **Refresh** and the ABOUT button at the top. (REQ-FL-58. Changes with issue #52.)
2b. Start the app for the first time after the install. Check: the iPhone asks for the Local Network permission once. Close the app and start it again: no second question. (Changes with issue #52.)
2c. Tap **Refresh** (or wait on the screen), with the stopwatch. Check: the TV shows in the list **ROOMS FOUND** within 15 seconds. (REQ-FL-83. Changes with issue #52.)
2d. Tap the TV in the list and type the 4-digit PIN from the TV. Check: the phone shows the waiting screen with the square of slot 1, and the TV shows the player in slot 1. (Changes with issue #52.)
2e. Turn Local Network off for the app in the iPhone Settings. Open the connect screen with an empty list. Check: the second line under "NO ROOMS FOUND" reads exactly "NO ROOMS FOUND? IN PHONE SETTINGS, ALLOW LOCAL NETWORK FOR THIS APP, AND CONNECT TO THE SAME WI-FI AS THE TV." (REQ-FL-59. Changes with issue #52.)
3a. Open the debug overlay on the TV. Put the iPhone flat, screen up, still. Check: Accel z is between +9.3 and +10.3, and Accel x and y are between -0.5 and +0.5. If z is negative, tell Claude: remove "iOS" from `ACCEL_INVERTED_ON` in `scripts/input/sensor_sampler.gd`.
3b. Put the right side down at about 30 degrees, then the left side down. Check: Accel x is -2 or lower for the right side down, and +2 or higher for the left side down. (Like Test 3, item 2.)
3c. Put the top up at about 30 degrees, then the top down. Check: Accel y is +2 or higher for the top up, and -2 or lower for the top down. (Like Test 3, item 3.)
3d. Turn the phone to the left on a table (like turning a plate). Check: Gyro z is positive during the turn. (Like Test 3, item 4.)
4a. Play Treasure Maze for 2 minutes (stopwatch) with the screen on and no touch on the screen. Check: no "lost connection" card on the TV and the iPhone screen does not lock.
4b. In the same game, tilt the phone left, right, top up and top down. Check: the ball rolls to the side that is lowered, in all 4 directions.
5a. In a game, lock the iPhone. Check: the TV shows the lost-phone card ("1P LOST CONNECTION" for slot 1) within 10 seconds. (Like Test 7, item 1.)
5b. Unlock the phone after 10 seconds. Check: the phone returns without the PIN pad, the card on the TV changes to a card with the button "Resume", and "Resume" restarts the game. (Like Test 7, items 1 and 5. Changes with issue #52 for the PIN.)
5c. Outside a game (on the Games screen), lock the iPhone for 40 seconds and unlock it. Check: the PIN pad opens. (Like Test 7, item 3. Changes with issue #52.)
6a. On an iPhone with a Dynamic Island or a notch, open upright: Connect (with the player dropdown), the PIN pad, About, and in a game the waiting screen and the pad. Take a photo of each. Check: in each photo the complete outline of every text and button is visible (also the colored square, the player number, DISCONNECT, A and B), and none is under the island, the notch, the status bar or the home bar. (REQ-FL-68)
6b. Open the player list, the player edit screen with the keyboard open, and Settings, upright. Take a photo of each. Check: the same as 6a. (REQ-FL-68)
6d. Turn the phone to the side and open the screens of 6a and 6b again. Check: the same as 6a for every screen. (REQ-FL-68)

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Terminal log of the deploy with the exit code | Not run | | | |
| 1b | Photo of the app and of the home screen icon | Not run | | | |
| 2a | Photo of the Connect screen | Not run | | | |
| 2b | Photo of the permission question; note on the second start | Not run | | | |
| 2c | Time in seconds until the TV shows in the list | Not run | | | |
| 2d | Photo of the TV with the player joined | Not run | | | |
| 2e | Photo of the Connect screen with the second line | Not run | | | |
| 3a | Photo of the overlay values flat | Not run | | | |
| 3b | Photo of the overlay values for each tilt | Not run | | | |
| 3c | Photo of the overlay values for each tilt | Not run | | | |
| 3d | Photo of the overlay Gyro z during the turn | Not run | | | |
| 4a | Short video; the time | Not run | | | |
| 4b | Short video of the ball in 4 directions | Not run | | | |
| 5a | Photo of the TV card; the time in seconds | Not run | | | |
| 5b | Photo of the TV card and of the phone after unlock | Not run | | | |
| 5c | Photo of the phone after 40 seconds | Not run | | | |
| 6a | Photos of the five screens under the island, upright | Not run | | | |
| 6b | Photos of the three screens, upright | Not run | | | |
| 6d | Photos of the screens turned to the side | Not run | | | |

Step 6c is now part of step 6a. The parts of steps 1b, 2b, 4a and 6a that a machine reads (the preset, the usage texts, the screen-on setting, the layout in the safe area of an iPhone) are in the automated tests (docs/AUTOMATED_TESTS.md, A-13-1 to A-13-6). The numbers of the other items do not change.

History:

- 2026-10-20: the steps were rewritten with a measurable Check and split with letters (1a to 6d). Steps 2a to 2e, 5b and 5c change with issue #52 (no PIN, no list, no Refresh).
- -: **Not run**. New.

## Test 14

### Paint Grab (tilt)

Needs: 1 to 4 phones, 1 TV, a stopwatch, and a child of about 5 to 8 years for step 7. Covers: REQ-PG-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Hold each phone flat like a tray. New game (2026-10-09). The blob feel (`TiltBody`: acceleration, damping, speed limit, bounce) and the
difficulty values are first guesses. "Full tilt" means the phone is tilted about 45 degrees. Record videos at 30 frames per second or more.

**Steps**

4a. Roll over 5 free tiles. Check: each of the 5 tiles takes the color of your blob, and the tile count on your phone goes up by 5. (REQ-PG-4, 13)
4c. With 2 phones, roll over a tile of the other player. Check: the phone of the player that takes the tile buzzes once (felt by the tester: yes or no) and the phone of the other player does not buzz. (REQ-PG-12)
7a. Let a child of about 5 to 8 years play 1 round, with a grown-up next to them. The grown-up reads the hint line once and says nothing more. Check: the child paints at least 10 tiles in the first 30 seconds, and nobody touches the phone for the child. Write down the age. (REQ-PG-9, REQ-GM-80 to 84)
7b. The child plays a second round. Check: the child plays both rounds to the end without asking to stop or crying, also when a tile is painted over, and answers "yes" when asked "again?" (yes or no). (REQ-PG-9, REQ-GM-80 to 84)
8. Play a full round with 4 phones on Hard. Check: the debug overlay shows 55 frames per second or more during the whole round (60 expected). (REQ-GM-50)
10d. Look at the floor with 4 blobs from the sofa (about 3 m). Check: a second person names the color of each blob correctly (4 of 4), and each blob has a black outline and no number. (REQ-PG-8, 15, REQ-GM-46)
11a. **Pictures (2026-10-16, REQ-PG-22).** Play 5 rounds in a row. After 10 seconds of each round (the floor is still mostly empty), take a photo. Check: a second person who has the list of the 30 names (`SHAPES` in `paint_picture.gd`) names the picture correctly in at least 4 of the 5 rounds, and the 5 pictures are not all the same.
11b. At the end of the same rounds (the floor is full), take a photo. Check: the same second person names the same picture in at least 4 of the 5 rounds. (REQ-PG-22)
11g. Let the child of step 7 play 2 rounds with pots, without a hint about pots. Check: the child rolls over at least 1 pot within 10 seconds after it landed, and no picture makes the child upset (the child does not cover the eyes, cry or ask to stop). (REQ-PG-9, 22, 23)

Items 1, 2, 9 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-14-1, A-14-2, A-14-9). Items 3a to 3c, 5a to 5c, 6a to 6c, 10a, 10c and 11c to 11f moved there too (A-14-3, A-14-5, A-14-6, A-14-10, A-14-11). Items 4b and 10b were split: the machine checks the rule (A-14-4, A-14-10), and the part that needs a person is now 4c and 10d. The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 4a | Video: painting 5 free tiles; the tile count on the phone before and after | Not run | | | |
| 4c | Note: buzz of both phones, taker and other, yes or no | Not run | | | |
| 7a | The age of the child; the number of tiles painted in 30 s | Not run | | | |
| 7b | The words of the child; yes or no for "again?" | Not run | | | |
| 8 | Overlay screenshot (FPS) with 4 phones on Hard | Not run | | | |
| 10d | Photo of 4 blobs; the colors that were named | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-15 (Treasure Maze). |
| 11a | Photos at 10 s of 5 rounds; the names that were given | Not run | | | Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |
| 11b | Photos at the end of 5 rounds; the names that were given | Not run | | | Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |
| 11g | Note: the child, the time to the first pot, what happened | Not run | | | Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |

Measurements (not a test; no pass or fail). Write these values in the Notes column of the steps above. They decide the first tuning values of the game.

| Value | Step | Result | Run | Notes |
|-------|------|--------|-----|-------|
| Which pictures were not recognized, and if one picture came twice in a row | 11a | | | |
| Frame rate with 4 phones on Hard (aim 60) | 8 | | | |

History:

- 2026-10-20: the steps that a machine can check moved to the automated tests (A-14-3 to A-14-11). 4b and 10b were split into the automated part and 4c and 10d (each keeps the result of the old step). The measurement of the percent of the floor (old step 5c) was removed with the step.
- 2026-10-20: the steps were rewritten with a measurable Check and split with letters. The words "the blob and its number" of step 10 were removed: a blob has no number (REQ-GM-46). Each new step keeps the result of the old step with the same number.
- 2026-10-16 (not run): item 11 is new: a hidden picture under the floor (30 shapes, a new one each round) and bonus pots (gold 3 x 3, rainbow roller), REQ-PG-22 and 23.
- 2026-10-10 (not run): item 10 is new: the floor is a pixel world (phase 4 of the arcade style).
- -: **Not run**. New.

## Test 15

### Sumo Bumpers (tilt and A)

Needs: 2 to 4 phones, 1 TV, and a child of about 5 to 8 years for step 8. Covers: REQ-SB-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Hold each phone flat like a tray. New game (2026-10-09). The movement (`TiltBody`), the bounce, the dash and the difficulty values are first guesses. "Full tilt" means the phone is tilted about 45 degrees. Record videos at 30 frames per second or more.

**Steps**

4b. Roll a bumper into another one at a speed of about 100 px per second (a slow touch), then at full tilt (a fast hit). Check: both phones buzz at the fast hit and neither phone buzzes at the slow touch (felt by the testers: yes or no). (REQ-SB-8: more than 300 px/s)
6b. Check the phone that fell. Check: the phone buzzes at the fall (yes or no). (REQ-SB-11)
8a. Let a child of about 5 to 8 years play 1 match, with a grown-up next to them. The grown-up reads the hint line once and says nothing more. Check: the child makes the bumper move in the first 10 seconds, and nobody touches the phone for the child. Write down the age. (REQ-SB-9, REQ-GM-80 to 84)
8b. Check the child during the match. Check: the child plays all 3 rounds to the end without asking to stop or crying, also after a fall, and answers "yes" when asked "again?" (yes or no). (REQ-SB-9, REQ-GM-80 to 84)
10. Play a full round with 4 phones on Hard. Check: the debug overlay shows 55 frames per second or more during the whole round (60 expected). (REQ-GM-50)
11c. Take two photos 10 seconds apart. Check: a cloud moved to the right by 4% to 6.5% of the screen width. (REQ-SB-15: 2 to 3 world pixels per second)
11e. Zoom a photo of the TV to 300%. Check: the island, the sky and the clouds have square steps with no soft edge. (REQ-GM-47i to 47n, REQ-SB-15)
11f. From the sofa (about 3 m), look at 4 penguins. Check: a second person names the body color of each penguin correctly (4 of 4). (REQ-SB-15)
11g. From 3 m, read the word "WHEE!", the round banner and the countdown digits. Check: the tester reads all three aloud without error. (REQ-SB-15, REQ-FL-40)

Items 2, 9 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-15-2, A-15-9). Items 1a, 1b, 3a to 3c, 4a, 5a, 5b, 6a, 6c and 7a to 7e moved there too (A-15-1, A-15-3, A-15-4, A-15-5, A-15-6, A-15-7). Items 11a, 11b and 11d were split: the machine checks the sizes, the colors, the fonts and the pixels (A-15-11), and the part that needs a person is now 11e, 11f and 11g. The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 4b | Note: buzz of both phones, slow touch and fast hit | Not run | | | |
| 6b | Note: buzz felt, yes or no | Not run | | | |
| 8a | The age of the child; what the child did in 10 s | Not run | | | |
| 8b | The words of the child; yes or no for "again?" | Not run | | | |
| 10 | Overlay screenshot (FPS) with 4 phones on Hard | Not run | | | |
| 11c | Two photos 10 s apart; the cloud move in % | Not run | | | |
| 11e | Zoomed photo of the screen | Not run | | | |
| 11f | Photo of the screen from the sofa; the colors that were named | Not run | | | |
| 11g | Note: the texts that were read; the TV (1080p or 4K) | Not run | | | |

Measurements (not a test; no pass or fail). Write these values in the Notes column of the steps above. They decide the first tuning values of the game.

| Value | Step | Result | Run | Notes |
|-------|------|--------|-----|-------|
| The TV (1080p or 4K) | 11g | | | |

History:

- 2026-10-20: the steps that a machine can check moved to the automated tests (A-15-1 to A-15-11). 11a, 11b and 11d were split into the automated part and 11e, 11f and 11g (each keeps the result of the old step). The three measurements of the old steps 5a, 7b and 7c were removed with the steps: the values are tested now (round length, wait after a fall, dash speed and time).
- 2026-10-20: the steps were rewritten with a measurable Check and split with letters. Each new step keeps the result of the old step with the same number.
- -: **Not run**. New. Item 11 was added on 2026-10-10 (phase 2 of the arcade style) and changed on 2026-10-15 for the Sky Island and the penguins.

## Test 16

### The arcade look (REQ-FL-37 to 46, FD-18)

Needs: 1 to 4 phones, 1 TV on 1080p (and a 4K TV if you have one), a child of 5 to 8 years for items 8a and 8b, a tape measure or a marked distance of 3 m, a stopwatch, a phone camera. Covers: REQ-FL-37 to 46, 41a, 52, 53, REQ-GM-45, 46. New, written on 2026-10-10 for phase 1 of `docs/ARCADE_STYLE_PLAN.md`. The games are in the pixel style too (phases 2 to 4 are built); this test checks the menus, the phone and the game shell (HUD, countdown, menus, hints). The headless suites `tests/screens_sweep.gd`, `tests/hud_layout.gd` and `tests/games_focus.gd` and the render suite `tests/pixel_render.gd` check the sizes, colors, rows, cursors and pixels; this test keeps what needs a real TV, a real phone or a person.

**Steps**

1b. On the Connect screen, the Games screen, a pause menu and a result menu, read aloud the smallest text of each screen (the hint, a slot row or a description) from 3 m. Check: you read each one without a mistake (0 mistakes). The smallest text is 32 px (REQ-FL-40).
2c. On a 1080p TV, photograph the Logo screen and the Games screen from the sofa, with the phone camera at 1:1 crop. Check: a single-pixel black and white edge of a letter stays a single pixel in the photo, with no gray halo wider than 1 pixel of the photo (the TV's own scaler does not soften the picture).
2d. Do step 2c on a 4K TV, if you have one. Check: the same result. (Skip this step if you have no 4K TV and write "no 4K TV" in the notes.)
3e. With 1 phone, focus a game that needs more phones (for example Sumo Bumpers). Check: the reason shows in yellow text, and OK on the tile plays the sound of a dim item and does not start the game.
4d. On the real TV remote, in each menu of the Games screen, a game settings view and the quit question, press OK, Back and the D-pad once each. Check: OK does the action of the focused item, Back closes the menu or goes up one step, and the D-pad moves the focus (the same result as in Test 8).
5a. Record a 10 s video of a screen with the blinking prompt PRESS OK TO CONTINUE (or PRESS OK TO SKIP). Check: the prompt is on 9 or 10 times in the 10 s (0.55 s on, 0.55 s off, REQ-FL-42).
5b. Record a video of the logo screen. Check: the logo drops from the top and stops (frame by frame, it moves in jumps with no blur), and the confetti pieces are squares.
5c. Record a video of a countdown. Check: the number shows in steps of size (the video shows 4 different sizes, from the largest to the smallest, and each size stays for more than 1 frame).
5d. Open the overlay (FPS) and record the logo, a blinking prompt and a countdown. Check: the FPS value is 55 or more in the whole video (REQ-FL-44: 60 fps).
6a. On a phone, go through the Connect, the waiting and the pad screens. Hold the phone at 50 cm and read aloud every text of each screen. Check: you read each text without a mistake.
6b. On the pad, take a photo of A with a finger on it and a photo without. Check: A is green and B is red, both are round with a ring, and the face of the button is lower in the photo with the finger.
6c. Tap RECENTER. Check: RECENTER is a yellow framed box, and it fills with yellow for a moment when tapped (video).
6d. Tap DISCONNECT once. Check: the phone leaves the TV with this one tap (no question). (The position at the top right is checked by `tests/run_tests.gd`.)
6e. Join a TV. Check: the slot color square with the slot number is at the top of the pad.
8a. A child of 5 to 8 years sits at the TV with the Games screen open. Ask: "Which game is chosen now?". Check: the child points to the focused tile (the one with the cursor) within 10 s and without help.
8b. Show the child the screen with PRESS OK TO CONTINUE. Ask the child to continue. Check: the child presses OK within 10 s and without help.

Items 1a, 2a, 2b (split into 2c and 2d), 3a, 3b, 3c, 3d, 4a, 4b, 4c, 7a, 7b moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-16-1 to A-16-7). The numbers of the other items do not change.

Measurements: write down the lowest FPS value of step 5d and the text sizes you saw in step 1b. Do not turn them into a pass or fail.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b | List of the screens and the smallest text read without a mistake (yes or no) | Not run | | | |
| 2c | Close photo of the Logo screen and the Games screen on 1080p, 1:1 crop | Not run | | | |
| 2d | Close photo of the Logo screen and the Games screen on 4K (or "no 4K TV") | Not run | | | |
| 3e | Photo of the yellow reason text; note on the sound | Not run | | | |
| 4d | Note: OK, Back and D-pad on each menu | Not run | | | |
| 5a | 10 s video of a blinking prompt; the count of on phases | Not run | | | |
| 5b | Video of the logo and the confetti | Not run | | | |
| 5c | Video of a countdown | Not run | | | |
| 5d | Video with the overlay FPS; the lowest FPS value | Not run | | | |
| 6a | Photos of the phone screens; the note "read without a mistake" | Not run | | | |
| 6b | Photos of the pad with and without a finger on A | Not run | | | |
| 6c | Video of the tap on RECENTER | Not run | | | |
| 6d | Note: one tap leaves | Not run | | | |
| 6e | Photo of the top of the pad | Not run | | | |
| 8a | Note: the child, the age, the seconds | Not run | | | |
| 8b | Note: the child, the age, the seconds | Not run | | | |

History:

- -: **Not run**. New.

## Test 17

### Hebrew and right to left (REQ-FL-54, 60 to 63, REQ-GM-47o, FD-19)

Needs: 2 phones (one with the system language Hebrew, one English), 1 TV (run it with the TV set to Hebrew, region Israel, and again set to English), a person who reads Hebrew, a stopwatch. Covers: REQ-FL-54, 60 to 63, REQ-GM-47o. New, written on 2026-10-10 for phase 5 of `docs/ARCADE_STYLE_PLAN.md`. The headless tests `tests/smoke_lang.gd`, `tests/smoke_settings.gd`, `tests/screens_sweep.gd`, `tests/hud_layout.gd` and `tests/run_tests.gd` check the table, the layout positions, the fit of every text, the language choice and the protocol; they cannot check how the text looks on a TV or whether it reads right.

**Steps**

2a. In Hebrew, go through the Connect, Games and Settings screens. Check: the cursor is at the right of the focused item and points left. (The title at the right and the fit of every text are checked by `tests/screens_sweep.gd`.)
2b. On the Connect screen in Hebrew, check: the slot squares are at the right of each slot row. (The QR card at the right of the slots is checked by `tests/smoke_lang.gd`.)
2e. The person who reads Hebrew reads each TV screen aloud (Connect, Games, Settings, About, the quit question). Check: the punctuation (`. , ! ? -`) is at the correct end of every sentence. Write down every text that is wrong. (That a Hebrew text ends with the same punctuation as its English text is checked by `tests/smoke_lang.gd`.)
4a. Join 2 phones: one with the system language Hebrew, one English, with a profile with a Latin name on one and a profile with a Hebrew name on the other (Test 20). Before the join, check: the Hebrew phone shows its Connect screen in Hebrew and the English phone in English.
4c. On the TV, look at the Connect screen with the two names. The person who reads Hebrew reads the Latin name and the Hebrew name aloud. Check: each one equals what was typed (the letters are in the same order, the mixed-direction text is not shuffled). (That the names stay as typed and that the pixel font has every glyph is checked by `tests/smoke_lang.gd`.)
6b. In Hebrew, start every game with 2 phones. Check: the title is at the top right, the leader chip is at the left margin (Pin Pals has no leader chip), and the timer box is at the right (Road Rally: the timer box is at the left margin). (REQ-GM-47o)
6c. In the same games, check: the hint and the countdown word "קדימה" show complete.
6e. Open the pause menu and the result menu in Hebrew. Check: the ranking list, the medal text and "תיקו!" show complete, and the Hebrew reader says that the text reads right.
7a. Phone in Hebrew, on the pad screen. Check: the words RECENTER, DISCONNECT and the hint are in Hebrew and none is cut.

Items 1a to 1d, 2c, 2d, 3a to 3c, 4b, 6a, 6d, 8a and 8b moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-17-1 to A-17-8). Item 5 moved earlier (A-17-5). Item 7b moved too (A-17-7b). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 2a | Photos of each TV screen in Hebrew | Not run | | | |
| 2b | Photo of the Connect screen in Hebrew | Not run | | | |
| 2e | A list of the sentences with wrong punctuation | Not run | | | |
| 4a | Photos of both phones before the join | Not run | | | |
| 4c | Photo of the Connect screen with the names; note from the Hebrew reader | Not run | | | |
| 6b | Same photos | Not run | | | |
| 6c | Same photos and the countdown | Not run | | | |
| 6e | Photos of the pause and result menus | Not run | | | |
| 7a | Photo of the Hebrew phone pad | Not run | | | |

History:

- -: **Not run**. New.

## Test 18

### Sound and haptics

Needs: 1 to 4 phones, 1 TV, a grown-up, a child of about 5 to 8 years for item 9, a phone with a sound level meter app (dB(A)), a camera at 60 fps or more for items 6b and 11a, a stopwatch for item 11b. Covers: REQ-FL-64 to 66, REQ-GM-49a to 49c, REQ-GM-43.

New (2026-10-10). The songs, the effects and the levels are first guesses (`scripts/audio/songs.gd`). The headless tests check the data (the notes, the levels in dB, the order of the sounds, the ducking, the haptics calls), not how it sounds in the room. Items 1a to 1c, 2a to 2e, 3b, 3c, 3e, 4a, 4b, 5a to 5e, 6c, 7a to 7c, 8a to 8d, 10b, 10d and 10e moved to the automated tests (docs/AUTOMATED_TESTS.md, A-18-1 to A-18-10). The numbers of the other items do not change. Put the phone with the meter app at the sofa seat and keep the TV volume the same for the whole test. A meter reading is the highest value in 5 s.

**Steps**

3a. Open Settings. Check: the rows Music and Effects show as rows 3 and 4, and a Mute row shows as row 5 (this changes with issue #49, which removes the Mute row).
3d. Set Effects to 0. Check: you hear no effect in the menu. Set Effects to 6: the effects come back.
6a. In each game, make each event of the *Sound and haptics* table of its game file (`docs/games/<id>.md`). Check: for each event, the effect plays (yes or no). The maze wall hit is also checked by the automated tests (A-18-6a), but play it here too.
6b. Film the phone of the player and the TV with sound at 60 fps or more for 3 events. Check: the phone starts to buzz within 100 ms of the start of the sound (6 frames or fewer at 60 fps). The automated tests check this on the network only (A-18-6b), not the phone motor or the TV audio path.
9a. A child of about 5 to 8 years plays a game with sound for 3 rounds. Read the meter at the highest effect. Check: the reading is 85 dB(A) or lower, and the child does not cover its ears and does not ask for less sound.
10a. On a phone, open **Settings** on the waiting screen. Check: the HAPTICS switch shows and its default is ON.
10c. Play a game with Haptics ON on one real phone. Check: the phone vibrates at GO and at each event of step 6a that has a haptic (yes or no for each).
10f. Take a photo of the waiting screen. Check: the Settings button does not touch the DISCONNECT button.
11a. Film a picture event and its sound on the TV box with a camera at 60 fps or more. Count the frames from the picture to the sound for 3 events. Check: the delay is 100 ms or less (6 frames at 60 fps) for each event.
11b. Start the app with the stopwatch. Check: the first song starts within 5 s (the same limit as the automated check A-18-1a, on the TV box).

Measurements: write down the meter reading of step 9a and the delay of steps 6b and 11a. The levels of the songs are tuned from these values.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 3a | Photo of the Settings rows | Not run | | | |
| 3d | Note: silent with Effects at 0 | Not run | | | |
| 6a | Note for each event: the effect plays, yes or no | Not run | | | |
| 6b | Video; the frames between the buzz and the sound | Not run | | | |
| 9a | Note: the child, the age, the highest meter reading, what happened | Not run | | | |
| 10a | Photo of the phone Settings | Not run | | | |
| 10c | Note: the vibration at the events | Not run | | | |
| 10f | Photo of the waiting screen | Not run | | | |
| 11a | Video; the frames for 3 events; the delay in ms | Not run | | | |
| 11b | Value: seconds until the first song | Not run | | | |

History:

- -: **Not run**. New.

## Test 19

### Leader chip, phone score and name tags (REQ-FL-67, REQ-GM-46, 46a, FD-21)

Needs: 2 to 4 phones (give two of them names of 10 letters, the most since FD-22), 1 TV on 1080p, a grown-up, a child of about 5 to 8 years for item 8, a person who reads Hebrew for item 9. Covers: REQ-FL-67, REQ-FL-68, REQ-GM-46, 46a, FD-21, issue #25.

New (2026-10-10). The HUD shows one chip, the leader, and not a chip for each player. Each phone shows its own place and score. The size of the header text on the phone and the place of the name tags are first values. The headless test `tests/hud_layout.gd` checks the rectangles of the chip, the title, the timer and the tags in all games with 4 phones, in English and Hebrew; what stays here is the phone screen, the real TV and the people.

**Steps**

3a. Look at each phone during a game of Banana Party with 4 phones. Check: the line under the header row (not next to Disconnect) shows the place (1ST to 4TH) and the score (`2ND  120`), and it changes within 1 s of a score change.
3b. Play with one phone only. Check: only the score shows (no place).
3c. Hold a phone at 50 cm. Check: you read aloud the place and the score of the line without a mistake.
3d. On an iPhone with a Dynamic Island (and on an Android phone with a camera cut-out), take a photo of the pad. Check: the colored square, the player number and DISCONNECT are fully visible, and A and B are fully on the screen (REQ-FL-68).
3e. Turn the same phone to landscape and back. Check: nothing is hidden at the top, at the bottom (the home bar) or at the side.
3f. Open the pause menu. Check: the phone keeps its score. Go back to the menu: the score is gone.
7a. In the countdown of Treasure Maze, Road Rally and Banana Party, take a photo. Check: each player's name stands next to its own ball, car or cursor, in its color, and no other object is nearer to it. (That there is one tag for each player with the right name and color, near its object, is checked by `tests/hud_layout.gd`.)
8a. A child of 5 to 8 years plays a game. In the countdown, ask the child to point to its own object. Check: the child points to the right object within 10 s and without help.
8b. After one minute of play, ask the child to read aloud the number on its phone. Check: the child says the number that the phone shows.
9a. Set the TV to Hebrew and play one game with 2 phones. Check: the title is at the top right, the leader chip is at the left margin, and the timer box is at the right (Road Rally: the timer box is at the left margin in English and at the right in Hebrew). (REQ-GM-47o)
9c. The person who reads Hebrew reads the header of a phone. Check: the place and the score are read without a mistake.

Items 1a to 1c, 2a to 2d, 4a to 4c, 5a to 5c, 6, 7b, 7c and 9b moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-19-1 to A-19-9). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 3a | Photo of a phone header with place and score | Not run | | | |
| 3b | Photo of a phone with one player | Not run | | | |
| 3c | Note: read without a mistake, yes or no | Not run | | | |
| 3d | Photos of the pad on an iPhone and an Android phone with a cut-out | Not run | | | |
| 3e | Photos of the phone in landscape | Not run | | | |
| 3f | Photos of the phone in pause and after the menu | Not run | | | |
| 7a | Photo of the countdown of the three games | Not run | | | |
| 8a | Note: the child, the age, the seconds | Not run | | | |
| 8b | Note: the child, the age, the number | Not run | | | |
| 9a | Photo of the Hebrew HUD | Not run | | | |
| 9c | Photo of the Hebrew phone header; note from the Hebrew reader | Not run | | | |

History:

- -: **Not run**. New.

## Test 20

### Player profiles (REQ-FL-69 to 75, REQ-N8, REQ-C7 to C9, FD-22)

Needs: 2 to 4 phones (one an iPhone if possible), 1 TV on 1080p, a grown-up, a child of about 5 to 8 years for items 7b and 17d, a person who reads Hebrew for item 6e, a stopwatch. Covers: REQ-FL-69 to 79, REQ-GM-98 to 101, REQ-N8, REQ-C7 to C11, FD-22. Items 1 to 8 are phase A (names and avatars), items 9 to 11 are phase C (personal bests), items 12 to 15 are phase B (copy by QR), items 16 and 17 are the Connect screen and the HUD changes of 2026-10-11 (`docs/PROFILES_PLAN.md`, section 11.2).

New (2026-10-10). The headless tests check the rules and the drawing. They do not show how an avatar looks from the sofa, or how the profile screens work in a hand.

**Steps**

1b. Start a game. Check: the name and the avatar show in the countdown tag and on the leader chip (make this phone the leader).
2a. Change the avatar and the name with the pencil button on the Connect screen, then join. Check: the TV shows the new name and avatar within 3 s of the join.
2b. Check: the phone shows the same name that the TV shows (REQ-FL-75).
3a. A parent phone with 3 profiles: after a round tap DISCONNECT, pick another profile on the Connect screen and join again. Check: the TV shows the new name and avatar.
4a. Two phones with the names `Sam` and `sam`. Check: the TV shows `SAM` and `SAM 2` (upper case, REQ-FL-39).
4b. Use a name of 10 letters and a Hebrew name of 10 letters. Check: both show complete (the first and the last letter) on the cards and in the lists.
6a2. Pause card: switch the Wi-Fi of a phone that has a profile off and start the stopwatch. Check: a pause card shows on the TV within 5 s. (Changes with issue #56: within 3 s. The card title with the name, the buttons and the long names are automated; the Wi-Fi coming back is in Test 7.)
6e. Show the card with a Hebrew name in the English sentence, and with an English name in the Hebrew sentence. The Hebrew reader reads both cards aloud. Check: for each of the 2 cards the reader says that the letters of the name are in the typed order and that the sentence is in the right order (2 of 2 yes).
7a. Show all 32 avatars on the four slot colors, at the smallest size they have (the HUD chip and the result row). Take a photo of each size. Check: you count 32 different pictures (no two are the same picture).
7b. A child of 5 to 8 years joins with a phone, and 3 other players join. Ask the child to point to its own avatar on the TV. Check: the child points to it within 10 s and without help.
8a. The same profile on a second phone joins the same TV while the TV is in a menu. Check: the older phone shows `THIS PLAYER IS ALREADY IN THE ROOM.` and goes to the Connect screen.
9a. Play Banana Party, Paint Grab, Galaxy Protector, Pin Pals (Rails Off; with Rails On there is no NEW BEST) and Road Rally (a fixed track) with a profile on 2 phones. When the round is over, check: the phone of a player who scores shows NEW BEST! on the waiting screen.
9b. Play a worse round in the same game. Check: the best does not change (the next round shows "BEFORE:" with the first score).
9c. Play a second round. Check: the phone shows "BEFORE: x" and x equals the old best (a race time in seconds).
9d. Check: the phone of a guest shows nothing about a best.
10. Close the app and open it again, then join another TV. Play the same game as in step 9. Check: "BEFORE" shows the old best from before the restart.
12a. Share a profile to a second phone by QR: give the profile some personal bests first. On the first phone open the list and tap SHARE on a row; on the second phone tap SCAN A PROFILE. Check: the second phone shows PLAYER ADDED. with the same name and avatar.
12b. Open the profile on the second phone. Check: the personal bests equal the ones on the first phone (compare 3 values).
12c2. Share a profile from 30 cm with the screen at full brightness. Check: the code shows within 2 s of the tap on SHARE, and PLAYER ADDED. shows 10 s or less after the start of the scan. (The size of the largest code and the time to make it are automated.)
12d. Repeat from 60 cm, and with the screen at low brightness (4 combinations). Check: PLAYER ADDED. shows within 20 s in each combination.
13a. Share a player that the second phone already has, after a rename on the first phone (the name is newer there). Check: the second phone shows PLAYER UPDATED. and has the newer name and avatar.
13b. Rename on the second phone and scan the old copy again. Check: the newer name stays.
13c. Give each phone a better best for one game and scan again. Check: both phones keep the better value for each game.
14a. An iPhone: tap COPY CODE on one phone. Check: the phone says CODE COPIED.
14b. On the iPhone tap PASTE A CODE. Check: the iPhone shows no scan button, and it shows PLAYER ADDED. with the same name, avatar and bests as in step 12.
15a. Change one letter of a copied code, then paste. Check: the phone says THIS CODE DOES NOT WORK.
15b. Scan the QR code of the TV on the list. Check: the phone says THIS IS A ROOM LINK.
15c. Scan a player code on the Connect screen. Check: the player is added and the list opens.
16b. Tap **+**. Tap the name field. Check: the keyboard opens and stays open. Tap outside the field: the keyboard closes.
16c2. On the new player screen drag the avatar line with one finger by about 3 cm. Check: the line follows the finger, and the first avatar in view changes by 1 or more. (The 32 avatars in one line, the arrows with 3 avatars for each tap and the picked avatar in view at open are automated.)
16g. Tap the pencil button next to the dropdown. Change the name and the avatar, tap SAVE, and join. Check: the TV shows the new name and avatar.
16h. Tap the pencil button and then Back. Check: you are on the Connect screen.
17a. New (REQ-FL-71, REQ-GM-46b, 70). Join a TV. Check: the waiting screen has only DISCONNECT (top right), the text, SETTINGS and ABOUT, and no PLAYER button. To change the player, tap DISCONNECT and choose on the Connect screen.
17b. On the TV, in every game, check: the leader chip and the name tags in the countdown show the color square, then the avatar, then the name, also in Hebrew (left to right inside the chip).
17c. In every game, check: no ball, marble, blob, bumper or cursor shows a number or an avatar, only its color.
17d. A child of 5 to 8 years plays a game. Check: in the countdown the child points to its own object within 10 s, with the name tags and without help.

Items 5, 11 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-20-5 and A-20-11). Items 1a, 1c, 3b, 6b, 6c, 8b, 16a, 16d, 16e, 16f moved to the automated tests, and items 6a, 6d, 12c, 16c lost the part that a machine checks (`docs/AUTOMATED_TESTS.md`, A-20-1 to A-20-16). The remaining part of 6a is 6a2, of 6d is 6e, of 12c is 12c2, of 16c is 16c2. The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b | Photos of the countdown tag and the leader chip | Not run | | | |
| 2a | Video of the join; the seconds until the new name | Not run | | | |
| 2b | Photo of the phone and of the TV | Not run | | | |
| 3a | Video of a switch between rounds | Not run | | | |
| 4a | Photo of `SAM` and `SAM 2` | Not run | | | |
| 4b | Photo of the 10-letter names | Not run | | | |
| 6a2 | Photo of the pause card in English; the seconds | Not run | | | |
| 6e | Photo of the card in English and in Hebrew; note from the Hebrew reader | Not run | | | |
| 7a | Photos of the 32 avatars at both sizes | Not run | | | |
| 7b | Note: the child, the age, the seconds | Not run | | | |
| 8a | Photo of the message on the older phone | Not run | | | |
| 9a | Photo of NEW BEST! on a phone | Not run | | | |
| 9b | Photo of the next BEFORE text | Not run | | | |
| 9c | Photo of BEFORE on a phone | Not run | | | |
| 9d | Photo of the guest phone | Not run | | | |
| 10 | Note: the bests after a restart of the app | Not run | | | |
| 12a | Video: the scan | Not run | | | |
| 12b | Photos of the bests on both phones | Not run | | | |
| 12c2 | Value: seconds to show and to scan | Not run | | | |
| 12d | Values: seconds for the 4 combinations | Not run | | | |
| 13a | Photos of both phones | Not run | | | |
| 13b | Note: the names on both phones | Not run | | | |
| 13c | Photos of the bests on both phones | Not run | | | |
| 14a | Note: the iPhone model; the message | Not run | | | |
| 14b | Photo of the iPhone screen | Not run | | | |
| 15a | Photo of the message | Not run | | | |
| 15b | Photo of the message | Not run | | | |
| 15c | Photo of the message and the list | Not run | | | |
| 16b | Video of the keyboard | Not run | | | |
| 16c2 | Video of the drag on the avatar line | Not run | | | |
| 16g | Photos of the phone and the TV | Not run | | | |
| 16h | Video of Back from the pencil | Not run | | | |
| 17a | Photo of the waiting screen | Not run | | | |
| 17b | Photos of the chip and tags in English and Hebrew | Not run | | | |
| 17c | Photos of the objects in each game | Not run | | | |
| 17d | Note: the child, the age, the seconds | Not run | | | |

History:

- -: **Not run**. New.

## Test 21

### Join PIN and About screens (REQ-FL-84, 85, REQ-N9, FD-25)

Needs: 2 phones (an Android phone and, if possible, an iPhone), 1 TV on 1080p, a grown-up, a person who reads Hebrew for step 10a, a stopwatch. Covers: REQ-FL-84, REQ-FL-85, REQ-N9, FD-25.

New (2026-10-11). The headless tests check the rules and the pages. They do not show how the PIN pad works in a hand, or how long the Godot pages take to open on a TV box. Issue #52 removes the join PIN, the list of found TVs, Refresh and the beacon. Steps 1 to 7 change with it; the About steps (8 to 10) stay.

**Steps**

1a. Open the Sababi: TV Games app. Check: the Connect screen shows the room code and, under it, a PIN of 4 digits. (Changes with issue #52.)
1b. Sit 3 m from the TV. Check: you read aloud the room code and the PIN without a mistake. (Changes with issue #52.)
2. Scan the QR code of the TV with an Android phone. Check: the phone joins within 5 s and shows no PIN pad. (Changes with issue #52.)
3a. On a second phone, leave and tap the TV in the list of found TVs. Check: the PIN pad opens. (Changes with issue #52.)
3b. Type a wrong PIN. Check: the phone shows the text WRONG PIN. CHECK THE PIN THAT IS SHOWN ON THE TV., and the text stays for 3 s or more (or until the next key). (Changes with issue #52.)
3c. Tap the TV again and type the right PIN. Check: the phone joins. (Changes with issue #52.)
3d. Start the stopwatch when the grown-up taps the TV, and stop it when the phone is joined (the grown-up reads the PIN from the TV). Check: the time is 15 s or less. (Changes with issue #52.)
3e. Open the pad and press Back. Check: the pad closes. (Changes with issue #52.)
4a. Type 5 wrong PINs in a row on the second phone. Check: each wrong PIN shows WRONG PIN. CHECK THE PIN THAT IS SHOWN ON THE TV. (Changes with issue #52.)
4b. Make the sixth try, with the right PIN. Check: the phone says TOO MANY WRONG PINS. WAIT 30 SECONDS BEFORE RETRYING. and does not join. (Changes with issue #52.)
4c. Wait 30 s with the stopwatch and try the right PIN. Check: the phone joins within 35 s of the fifth wrong PIN. (Changes with issue #52.)
4d. Check: the PIN on the TV did not change, and the first phone stays in its slot. (Changes with issue #52.)
5a. Close the phone app and open it again while the TV stays on. Check: the phone comes back to its slot without a PIN. (Changes with issue #52.)
5b. Restart the TV app and open the phone app. Check: the PIN pad opens by itself and no error text shows. (Changes with issue #52.)
6a. An iPhone: join from the list with the PIN (the iPhone has no scan button). Check: the iPhone joins. (Changes with issue #52.)
6b. Type the PIN with one hand. Check: you reach all digit keys and the delete key with the thumb of the hand that holds the phone, without the other hand. (Changes with issue #52.)
7. Open the Players modal on the TV (from the Games screen). Check: it shows the room code and the PIN, and a late phone joins with them. (Changes with issue #52.)
8a2. On the TV: Settings, select About and press OK. Check: the list opens and shows "Godot Engine" and "3rd Party Libraries". (The list and the pages are automated.)
8b. Open "Godot Engine". Check: the page shows the MIT text. Go back and open "3rd Party Libraries", then one library (for example FreeType) and one with two licenses. Check: each page opens.
8d2. Read the first line of a page aloud from 3 m. Check: you read it without a mistake. (Down and Up scroll the text: automated.)
8f. On the TV box, use the stopwatch from OK on "3rd Party Libraries" to the list on the screen, and from OK on a library to its page. Check: the list opens within 3 s and the page within 2 s.
9b2. On a phone open a long page (for example a library with two licenses) and drag it with one finger. Check: the text moves with the finger and the last line of the page can be reached by touch.
9d. Open the page "Android libraries" and scroll to the end with the stopwatch. Check: it opens within 3 s and you reach the end of the text.
9f. Tap the pencil button next to the player. Check: the edit screen of the active profile opens (the name field and SAVE show).
10a. Set the TV to Hebrew. Check: the About list and the pages "Sababi" show in Hebrew, and the Hebrew reader says that the wording is correct. (The planned Settings changes of issue #49 are in Test 18.)
10c. Open the PIN pad on a phone in Hebrew (before issue #52). Check: the digit keys are in the same places as in English, and the PIN line shows the digits in the order that you typed them.

Items 8c, 8e, 9a, 9c, 9e, 10b moved to the automated tests, and items 8a, 8d, 9b lost the part that a machine checks (`docs/AUTOMATED_TESTS.md`, A-21-8 to A-21-10). The remaining part of 8a is 8a2, of 8d is 8d2, of 9b is 9b2. The PIN steps (1 to 7, 10c) are rewritten with issue #52 and stay as they are. The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the Connect screen with the PIN | Pass | R1 | | |
| 1b | Note: read aloud from 3 m without a mistake | Pass | R1 | | |
| 2 | Value: seconds until joined; photo of the phone | Pass | R1 | | |
| 3a | Photo of the PIN pad | Fail | R1 | | R1 (before the split): step 3 failed. The failure is in step 3b. |
| 3b | Photo of the error text; value: seconds it stays | Fail | R1 | | R1: "either an error is displayed briefly and disappears or not displayed at all" |
| 3c | Note: the phone joined | Fail | R1 | | R1 (before the split): step 3 failed. The failure is in step 3b. |
| 3d | Value: seconds from the tap to the join | Not run | | | New limit (15 s) after R1. |
| 3e | Note: Back closes the pad | Fail | R1 | | R1 (before the split): step 3 failed. The failure is in step 3b. |
| 4a | Note: the text after each wrong PIN | Fail | R1 | | R1 (before the split): step 4 failed. The failure is in step 4b. |
| 4b | Photo of the lock text | Fail | R1 | | R1: "the correct pin doesn't connect but there's also no error displayed" |
| 4c | Value: seconds until the right PIN joins | Fail | R1 | | R1 (before the split): step 4 failed. The failure is in step 4b. |
| 4d | Note: the PIN before and after; the first phone | Fail | R1 | | R1 (before the split): step 4 failed. The failure is in step 4b. |
| 5a | Note: the phone came back without a PIN | Pass | R1 | | |
| 5b | Note: the pad opens, no error text | Pass | R1 | | |
| 6a | Note: the iPhone model | Pass | R1 | | |
| 6b | Note: the iPhone model; keys reached with one hand | Pass | R1 | | |
| 7 | Photo of the Players modal | Pass | R1 | | |
| 8a2 | Photo of the About list | Pass | R1 | | |
| 8b | Photo of the Godot page and a library page | Pass | R1 | | |
| 8d2 | Note: read aloud from 3 m | Pass | R1 | | |
| 8f | Values: seconds for the list and for a page | Not run | | | New limits (3 s and 2 s) after R1. |
| 9b2 | Note: scroll by touch | Pass | R1 | | |
| 9d | Value: seconds to open the page | Not run | | | New limit (3 s) after R1. |
| 9f | Photo of the edit screen | Not run | | | R1 judged whether the pencil is easy to tell as Edit. The check changed. |
| 10a | Photo of the Hebrew About screen; note from the Hebrew reader | Fail | R1 | | R1: "1. language should be modified by left and right keys. should be a selection of languages. 2. no explanation strings needed for the settings 3. drop Mute. it should be covered by music=0 and/or effects=0" (This note is about the Settings screen: issue #49. See Test 18 step 3.) |
| 10c | Photo of the Hebrew PIN pad | Fail | R1 | | R1 (before the split): step 10 failed. The failure is in step 10a. |

History:

- R1: **Fail** (steps 3, 4 and 10; the steps 1, 2, 5 to 9 pass). Reported in chat 2026-10-19. The failures of steps 3 and 4 are about the error texts WRONG PIN and TOO MANY WRONG PINS (no text, or a text that goes away). The note of step 10 asks for changes of the Settings screen (issue #49).
- -: **Not run**. New.

## Test 22

### Galaxy Protector (tilt, waves, upgrades)

Needs: 1 to 4 phones, 1 TV, a stopwatch, and a child of about 5 to 8 years for items 9a to 9c. Covers: REQ-AB-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Hold each phone upright or flat as you do for the other tilt games. New game (2026-10-16). Every number (ship speed, the rate of fire, the asteroid speeds, the waves, the upgrade times, the medal tiers) is a first guess, but each step below has a fixed limit. "From 3 m" means: sit or stand 3 m from the TV. Play on Medium unless the step says another difficulty.

**Steps**

1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the night sky with stars, the purple planet, a gray asteroid and a ship. (Changes with issue #57.)
2e. Read the hint line "Tilt to steer. Your ship shoots by itself. Grab the upgrades!" aloud from 3 m during "3, 2, 1". Check: no error.
3c. Tilt to the right and keep the tilt for 2 s after the ship stops. Do the same to the left. Check: the ship stops at both sides, stays fully on the screen, does not move more, and its middle is 2 % to 4 % of the screen width (60 px of 1920) from the edge.
5f. Take a shield upgrade. Check: the phone buzzes once (felt by the tester: yes or no).
8e. Play alone. Check: the result title is "Reached wave N", where N is the number of the last wave banner that you saw. The medal is the one of the table (Medium: bronze from 600 points, silver from 1800, gold from 4000, no medal below 600).
9a. Let a child of about 5 to 8 years play, with a grown-up next to them who does not help. Check: in "3, 2, 1" the child points at its own ship within 10 s.
9b. Same child. Check: the child moves the ship from the middle to the left side of the screen within 30 s after "GO!", with no help.
9c. Same child. Lose the ship of the child on purpose. Check: the child is still at the game 30 s later (does not stop and does not give the phone back). Ask: "Play again?". Check: the child says yes.
11. Play with 4 phones on Hard until wave 8 or later and open the debug overlay. Check: the FPS value is 55 or more for 30 s. (REQ-GM-50)
12b. From 3 m, look for the objects. Check: you can point at all of these: stars, the planet with the ring, an asteroid with craters, a ship, a beam, an upgrade and an explosion.
12f. Take a close photo of the TV (30 cm). Check: the edges of the ship and of an asteroid are steps of square pixels, with no blurred edge and no gradient inside a color area.
12g. Play with 4 phones. From 3 m, each tester names the color of the ship of a phone you point at. Check: 4 of 4 answers are right for every tester.
12h. From 3 m, read aloud the banners "Wave 2", "Wave 2 clear!" and "Next wave in 4", and the points in the bar. Check: no error.
(The music and the effects are checked in Test 18.)

Items 1a, 2a, 2b, 2d, 3a, 3b, 3d, 3e, 4a to 4d, 5a, 5b, 5d, 5e, 6a to 6d, 7a to 7e, 8a to 8d, 8f, 10a, 10b and 12d moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-22-1 to A-22-12). Items 2c, 5c, 12a, 12c and 12e were split: the machine checks the numbers (A-22-2, A-22-5, A-22-12), and the part that needs a person is now 2e, 5f, 12f, 12g and 12h. The numbers of the other items do not change.

Measurements (write down, no pass or fail): the real delay from a tilt to the ship moving; the wave from which you lose in less than 60 s on Easy, Medium and Hard; how long a player who is out waits for the end of the round with 4 phones; if the rate of fire of 1 shot every 0.4 s feels too slow at the start. Use them to tune `SHIP_SPEED`, `SHIP_SMOOTH`, `FIRE_EVERY` and the wave values.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b | Photo of the tile next to a photo of the game | Not run | | | |
| 2e | Note: errors made when reading the hint | Not run | | | |
| 3c | Photo of the ship at each stop; note: distance to the edge in % | Not run | | | |
| 5f | Note: buzz (yes or no) | Not run | | | |
| 8e | Photo of the result menu with the medal; note: points and N | Not run | | | |
| 9a | Note: the child, the age, seconds until it points | Not run | | | |
| 9b | Note: seconds until the ship is at the left side | Not run | | | |
| 9c | Note: the child is still at the game after 30 s (yes or no); the answer | Not run | | | |
| 11 | Overlay screenshot (FPS) with 4 phones on Hard, wave 8 or later | Not run | | | |
| 12b | Note: the seven objects, each yes or no | Not run | | | |
| 12f | Close photo of the TV (30 cm) | Not run | | | |
| 12g | Note: the answers of each tester (n of 4) | Not run | | | |
| 12h | Note: errors made when reading the texts | Not run | | | |

History:

- 2026-10-20: the steps that a machine can check moved to the automated tests (A-22-1 to A-22-12). 2c, 5c, 12a, 12c and 12e were split into the automated part and 2e, 5f, 12f, 12g and 12h (each keeps the result of the old step). Step 8e (the title and the medal of one player) stays manual: the automated test `auto_asteroid` finds that the medal does not follow the score (REQ-AB-14), so the step fails until that is fixed.
- -: **Not run**. New (2026-10-16).

## Test 23

### Pin Pals (bowling: aim with a turn, swing to throw)

Needs: 1 to 4 phones, 1 TV, a stopwatch, a phone camera (60 fps or more), and a child of about 5 to 8 years for items 11a to 11c. Covers: REQ-BW-*, REQ-GM-80 to 84, REQ-GM-90 to 98, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-16). It was only tested with made-up sensor values. Every number (the swing thresholds 4, 8 and 30 m/s2, the aim ranges, the ball speeds, the lane, the pins, the medal tiers) is a first guess, but each step below has a fixed limit. Hold the phone in one hand like a ball, arm down at the side. "From 3 m" means: sit or stand 3 m from the TV. Play on Medium unless the step says another difficulty.

**Steps**

1a. Open the tile of **Pin Pals** with 1 phone. Check: the settings view has the row Difficulty with Medium and the row Rails with Off. Start.
1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the lane with pins, the ball, the gray floor and the disco wall. (Changes with issue #57.)
4e. Throw 5 balls with each grip: screen up, screen to the side, and the other hand. Check: at least 4 of 5 swings throw a ball for each grip. (REQ-BW-5)
4f. Walk 10 steps with the phone in your hand. Check: no ball is thrown.
6a. Play a whole game (10 frames) with 1 phone. Write down the pins of every ball. Check: the total on the score sheet after frame 10 is equal to the total that you count by hand with the standard rules. (The rules are tested by `bowling_rules`.)
6c. Throw the last ball of frame 10. Start the stopwatch. Check: the top bar shows "Frame 10/10", and the result menu opens 1 to 3 s after the last ball. (REQ-BW-1)
7a. Set Rails to On. Aim to the end of the path and throw 5 balls. Check: in the video, each ball touches a rail and rolls back into the lane, and 0 balls are in the gutter. (REQ-BW-10)
7b. Finish a game with Rails On. Check: the result menu has no personal best, and the phone shows no "NEW BEST!". (REQ-BW-19)
8a. Play with 2, 3 and 4 phones for 2 frames. Check: the name on the plate "NAME, YOUR TURN!" goes in slot order in each frame (1, 2, 3, 4, then 1 again). The plate shows for 1 to 2 s.
8c. Look at each phone after a throw. Check: the score and the place on the phone are equal to the total and the order on the score sheet.
8d. Finish a game with 2 phones. Check: the result menu names the player with the most points as "X wins!", and the list is in the order of the totals.
9a. Look at the phone on turn. Check: it shows "YOUR TURN" and buzzes once when the turn starts. (REQ-BW-14)
9b. Look at the phones that wait. Check: each shows "<NAME> IS BOWLING" with the name of the player on turn.
9c. Open the result menu. Check: the line "YOUR TURN" or "<NAME> IS BOWLING" is gone on every phone.
10a. Play with 2 phones. Leave the game on the phone that is on turn. Check: the plate shows the name of the next player within 5 s, and the game goes on.
10b. With 1 phone left, leave the game. Check: the "No players connected" menu opens. (The pause of a lost phone is checked by A-23-10.)
11a. Let a child of about 5 to 8 years play on Easy with Rails On, with a grown-up next to them who does not help. Check: in "3, 2, 1" the child points at its own ball (the name tag) within 10 s.
11b. Same child. Check: the child throws a ball (a ball leaves the foul line) within 60 s after the first plate "YOUR TURN", with no help.
11c. After the game, ask: "Play again?". Check: the child says yes.
12. Play with 4 phones and open the debug overlay. Check: the FPS value is 55 or more for 30 s. (REQ-GM-50)
13a. **Pixel world (REQ-GM-47i to 47n).** Take a photo of the far end of the lane. Check: a pin is at least 4.4 % of the screen height (12 world pixels, 48 px of 1080).
13b. From 3 m, a tester points at the ball each time you say "mark" at a random time during a roll. Check: the finger points at the ball (not at a pin or the lane) in 5 of 5 tries.
13c. From 3 m, read aloud the totals of all rows of the score sheet and one banner. Check: no error.
13d. Look at the disco wall for 30 s. Check: the top two thirds are light tiles, the bottom third is plain black, and no tile changes more than 3 times in 1 s.
(The music and the effects are checked in Test 18.)

Items 2a to 2e, 3a to 3d, 4a to 4d, 5a, 5b, 6b, 6d, 8b, 8e, 10c and 14 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-23-2 to A-23-14). Items 4e, 4f and 13a keep only the part that needs a real phone or a photo (the rest is in A-23-4 and A-23-13). The numbers of the other items do not change.

Measurements (write down, no pass or fail): the turn angle that you find best for each difficulty and if turn or tilt is better for bowling; every swing that did not throw and every throw that you did not mean (with the grip); the peak power of a soft and a hard swing. Use them to tune `AIM_RANGE_DEG`, `BACK_ACCEL`, `FWD_ACCEL` and `FWD_FULL`.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the settings view | Not run | | | |
| 1b | Photo of the tile next to a photo of the game | Not run | | | |
| 4e | Note: throws of 5 for each grip | Not run | | | |
| 4f | Note: balls thrown while walking | Not run | | | |
| 6a | Photo of the score sheet after the game; list of the pins | Not run | | | |
| 6c | Note: stopwatch seconds from the last ball to the menu | Not run | | | |
| 7a | Video of 5 balls with rails | Not run | | | |
| 7b | Photo of the result menu and of the phone | Not run | | | |
| 8a | Note: the order of the names in 2 frames | Not run | | | |
| 8c | Photo of a phone and the score sheet at the same moment | Not run | | | |
| 8d | Photo of the result menu with 2 phones | Not run | | | |
| 9a | Photo of the phone on turn | Not run | | | |
| 9b | Photo of the phones that wait | Not run | | | |
| 9c | Photo of the phones with the result menu | Not run | | | |
| 10a | Note: seconds until the next name shows | Not run | | | |
| 10b | Photo of the "No players connected" menu | Not run | | | |
| 11a | Note: the child, the age, seconds until it points | Not run | | | |
| 11b | Note: seconds until the first ball | Not run | | | |
| 11c | Note: the answer of the child | Not run | | | |
| 12 | Overlay screenshot (FPS) with 4 phones | Not run | | | |
| 13a | Photo of the far end of the lane; note: pin height in % | Not run | | | |
| 13b | Note: pointed right, of 5 tries | Not run | | | |
| 13c | Note: errors made when reading | Not run | | | |
| 13d | Video of 30 s of the wall | Not run | | | |

History:

- -: **Not run**. New (2026-10-16).

## Test 24

### Swing detector for Tennis (debug overlay)

Needs: 1 phone on the same Wi-Fi as the TV (an iPhone for 10a and 10b, if you have one), 1 TV with its remote. Covers: REQ-TN-5 to 9 (`docs/games/tennis.md`), REQ-T4. New (2026-10-17). Tennis was built after this test (Test 25). This test checks only the
swing detector (`scripts/input/swing_detector.gd`) as Tennis uses it (`PlayerInput`) with the line that the debug overlay shows for each player. A swing is a swing back and then a swing
forward, or a sharp push in any direction with no back swing. The thresholds (`BACK_ACCEL` 4, `FWD_ACCEL` 8, `FWD_FULL` 30 m/s2, all times 0.75 for Tennis; the back swing waits 3 s; a sharp push of 20 m/s2 times 0.75 for 0.03 s; the lock after a swing is 0.6 s) are first guesses. Each step below has a fixed limit. The swing counter in the line ("swing N") is the number of swings found since the start.

**Steps**

Items 1 to 7b and 9a, 9b moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-24-1 to A-24-9). Item 8 is now 8b (the hit age is in A-24-8a; only the Age ms of the real phone is left). The numbers of the other items do not change.

8b. Join with 1 phone on Wi-Fi, open the debug overlay and read "Age ms" in the table for 10 s. Check: "Age ms" stays below 150 for the 10 s. (The hit age of 0 to 550 ms is checked by A-24-8a.)
10a. (iPhone, if you have one) Make 10 forehands from left to right, 2 s apart. Check: the counter rises by 9 or 10.
10b. (iPhone) Make 10 serves and then 10 forehands from left to right, 2 s apart. Check: at least 9 of 10 serves say `DOWN`, and at most 1 of 10 forehands says `DOWN`. (Sensor sign: Test 13 item 3.)
11a. Press RECENTER while you point at the TV. Swing a forehand to the right, 10 times, 2 s apart. Check: the `side` value is +0.3 or more in at least 8 of 10 swings. (REQ-TN-7)
11b. Swing a forehand to the left, 10 times. Check: the `side` value is -0.3 or less in at least 8 of 10 swings.
11c. Swing straight at the TV, 10 times. Check: the `side` value is between -0.2 and +0.2 in at least 8 of 10 swings.
11d. Swing nearly vertical (up and down), 10 times. Check: the `side` value is between -0.2 and +0.2 in at least 8 of 10 swings.

Measurements (write down, no pass or fail): the power of a soft, medium and hard stroke; the `side` values of each direction; the values of "hit N ms ago" and "Age ms" (the delay of the phone, Test 4). Use them to tune the thresholds of `swing_detector.gd` and `SWING_LOCK_S`.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 8b | Note: the lowest and the highest Age ms in 10 s | Not run | | | |
| 10a | Note: the iPhone counter | Not run | | | |
| 10b | Note: the iPhone serves and forehands with `DOWN` | Not run | | | |
| 11a | Note: 10 `side` values to the right | Not run | | | |
| 11b | Note: 10 `side` values to the left | Not run | | | |
| 11c | Note: 10 `side` values straight | Not run | | | |
| 11d | Note: 10 `side` values nearly vertical | Not run | | | |

History:

- -: **Not run**. New (2026-10-17).

## Test 25

### Tennis (swing, toss, serve, rally, scoring)

Needs: 1 to 4 phones, 1 TV, a stopwatch, a phone camera (60 fps or more for items 3b and 3d, 240 fps for item 4g), and a child of about 5 to 8 years for items 12a to 12d. Covers: REQ-TN-* (`docs/games/tennis.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-17). It was only tested with made-up sensor values. Every number (the swing thresholds of Test 24, the hit window of 0.55 s, the green half width of 0.30, 0.21 and 0.15 s, the ball speeds, the medal tiers) is a first guess, but each step below has a fixed limit. Do Test 24 first: Tennis uses the same swing detector. Hold the phone like a racket handle, with the screen toward you. The direction of the swing sends the ball: swing toward the right of the TV and the ball goes right, toward the left and it goes left (changed 2026-10-18: the tilt did not work). The first run (2026-10-18) found swings that were not detected and shots that mostly went left for a right-handed player: check both again (items 6c to 6e; the swing detection of items 3c, 4d and 4f is checked by the automated tests). "From 3 m" means: sit or stand 3 m from the TV. Play on Medium unless the step says another difficulty.

**Steps**

1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the court, the net, a character and the ball. (Changes with issue #57.)
2b. In "3, 2, 1" look at the court. Check: you can point at all of these: the doubles sidelines, the singles sidelines, the baselines, the service lines, the net, the umpire on the chair, the ball kid at the left net post, the stands and the blank ad boards.
2c. Look at the top bar before the first point. Check: there is no leader chip.
3b. The server presses A. Check: the ball goes up within 0.5 s (video, 60 fps or more).
3d. Toss and do not swing. Check: the ball falls to the ground 0.5 to 1.5 s after the toss (video, 60 fps or more).
4c. Look at the character of your team. Check: the character runs by itself (you do not move it), and at the hit it stands inside the ring.
4g. Record the phone and the TV with the camera (240 fps) for 5 hits. Count the frames from the fastest point of the swing to the contact of the racket and the ball. Check: the median delay is 150 ms or less (36 frames at 240 fps).
5a. Swing in the green part, 5 times. Check: in 5 of 5 tries the text "GREAT!" and sparks show.
5b. Swing too early, 5 times, and too late, 5 times. Check: in 10 of 10 tries the text "GREAT!" does not show, and the ball stays in play (no "OUT", no "NET" banner).
6b. **Far out and far behind (REQ-TN-4).** Aim wide and long with a hard swing so the other player has to run to the side line and behind the baseline (also with 4 phones). Check: in the video, 0 frames show a character cut by the edge of the screen, and the swing of that player still returns the ball in 4 of 5 tries.
6c. Swing 30 degrees to the right of the TV, 10 times. Check: at least 8 of 10 balls land in the right half of the court (from the view of the swinging player).
6d. Swing 30 degrees to the left of the TV, 10 times. Check: at least 8 of 10 balls land in the left half of the court.
6e. Swing straight at the TV, 5 times, and nearly straight up, 5 times. Check: at least 8 of 10 balls land in the middle third of the court width.
6h. Give the phone to a person who has not played. Show only the hint line. Check: the person sends one ball to the left half and one ball to the right half of the court within 5 swings each.
9e. Look at the phones with 3 and 4 phones. Check: the place on each phone is 1 for the team in front and 2 for the other team.
10b. Return 5 balls in a row. Check: the text "RALLY N" counts 1, 2, 3, 4, 5, and "BEST N" is equal to the highest count. After a missed ball a new rally starts 1.5 to 2.5 s later.
10c. Start the stopwatch at "GO!". Check: the result menu opens 88 to 92 s later.
12a. Let a child of about 5 to 8 years play on Easy, with a grown-up next to them who does not help. Check: in "3, 2, 1" the child points at its own character within 10 s.
12b. Same child. Check: the child serves a ball in play (over the net, inside the box) within 5 tries.
12c. Same child. Check: the child returns a ball at least once in the first 3 min of a rally.
12d. After the match, ask: "Play again?". Check: the child says yes.
13. Play with 4 phones and open the debug overlay. Check: the FPS value is 55 or more for 30 s. (REQ-GM-50)
14a. **Pixel world (REQ-GM-47i to 47n).** From 3 m, a tester calls "in" or "out" at the moment of the bounce for 10 balls. Check: at least 8 of 10 calls agree with the banner ("OUT" or no banner). The ball and its shadow are visible.
14b. With 4 phones, from 3 m, each tester names the shirt color of the two far characters. Check: 2 of 2 answers are right for every tester.
14c. From 3 m, read aloud the scoreboard and one banner. Check: no error.

Items 1a, 2a, 3a, 3c, 3e, 3f, 4a, 4b, 4d, 4e, 4f, 5c, 5d, 6a, 6f, 6g, 7a to 7d, 8a, 8b, 9a to 9d, 10a, 10d, 11a, 11b moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-25-1a to A-25-11b). Items 3b and 3d keep only the part that needs a person (the timing of the toss). The numbers of the other items do not change.

Measurements (write down, no pass or fail): the time of a whole match with 2 phones (the plan says about 8 minutes with 4 phones); the delay from the swing to the hit; if the green part feels too short or too long on each difficulty; every swing that went to the wrong side. Use them to tune the green half widths, the hit window and `SWING_SIDE_FULL`.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b | Photo of the tile next to a photo of the game | Not run | | | |
| 2b | Photo of the court; note: the nine objects, each yes or no | Not run | | | |
| 2c | Photo of the top bar | Not run | | | |
| 3b | Note: seconds from A to the toss | Not run | | | |
| 3d | Video of a toss with no swing; note: seconds until the ball falls | Not run | | | |
| 4c | Video of the character at the hit | Not run | | | |
| 4g | Video (240 fps); note: frames and ms for 5 hits | Not run | | | |
| 5a | Video; note: "GREAT!" and sparks of 5 | Not run | | | |
| 5b | Video; note: lobs in play of 10, any "GREAT!" | Not run | | | |
| 6b | Video of a player far out and far behind the baseline | Not run | | | |
| 6c | Note: balls in the right half of 10 | Not run | | | |
| 6d | Note: balls in the left half of 10 | Not run | | | |
| 6e | Note: balls in the middle third of 10 | Not run | | | |
| 6h | Note: swings until left and right, for the person | Not run | | | |
| 9e | Photo of the phones with the places | Not run | | | |
| 10b | Photo of the solo screen; note: the counts | Not run | | | |
| 10c | Note: stopwatch seconds until the result menu | Not run | | | |
| 12a | Note: the child, the age, seconds until it points | Not run | | | |
| 12b | Note: tries until a served ball | Not run | | | |
| 12c | Note: returns in 3 min | Not run | | | |
| 12d | Note: the answer of the child | Not run | | | |
| 13 | Overlay screenshot (FPS) with 4 phones | Not run | | | |
| 14a | Note: calls that agree, of 10 | Not run | | | |
| 14b | Note: answers of each tester | Not run | | | |
| 14c | Note: errors made when reading | Not run | | | |

History:

- -: **Not run**. New (2026-10-17).

## Test 26

### Mini Golf (aim, putt power, turns, 5 holes)

Needs: 1 to 4 phones, 1 TV, a stopwatch, a phone camera (240 fps for item 5e), and a child of about 5 to 8 years for items 12a to 12d. Covers: REQ-MG-* (`docs/games/mini_golf.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-17). It was only tested with made-up sensor values. Every number (the swing thresholds of Test 24, the putt speeds, the friction of the grass, the 5 course designs, the aim line lengths, the medal tiers) is a first guess, but each step below has a fixed limit. Do Test 24 first: Mini Golf uses the same swing detector. Hold the phone like a putter, with the screen toward you: turn it left and right to aim, swing it back and then forward to putt. "From 3 m" means: sit or stand 3 m from the TV. Play on Medium unless the step says another difficulty. The pars of the 5 holes are 2, 3, 3, 3 and 4.

**Steps**

1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the lawn, the fence, a golfer and the ball. (Changes with issue #57.)
2b. Look at the course. Check: you can point at all of these: the lawn, the fence, the clubhouse, the bushes and the walls of the hole.
3a. Look at the course at the start of a turn. Check: it shows 1 golfer and 1 white ball (the player on turn), and no other golfer.
3b. Look at the golfer. Check: the shirt has the color of the phone of the player on turn, and the cap, the trousers and the shoes are white.
3c. Start the stopwatch when the plate "<NAME>'S TURN!" shows. Check: it shows for 1.0 to 2.0 s.
3d. Look at the phones. Check: the phone on turn shows "YOUR TURN", and the other phone shows "<NAME> IS PUTTING" with the name of the player on turn.
4c. Swing back and hold the back swing. Check: the aim mark turns gold (yellow) at the back swing.
5b. Look at the golfer when you putt. Check: the golfer swings back and through, and the ball starts to move at the hit.
5e. Record the phone and the TV (240 fps) for 5 putts. Count the frames from the fastest point of the swing to the first move of the ball. Check: the median delay is 150 ms or less (36 frames at 240 fps).
7d. **Sliding barriers (holes 3 and 5).** Look at a barrier for 30 s (video). Check: at every moment there is a gap in the course. Check: the ball passes a barrier at least once in 5 putts.
8c. On one hole, putt away from the hole on purpose. Check: after the 6th stroke the banner "Picked up after 6 strokes" shows.
8f. Count the strokes of one player by hand for a hole. Check: the number in the bar is the same after every putt.
10a. Finish a match with 2 phones. Check: the result menu names the player with the fewest strokes as "<NAME> wins!" (or "Tie!" when the strokes are equal), and the list is in the order of the strokes.
10c. Choose Try again. Check: hole 1 starts again, with 0 strokes for every player.
10d. Choose New game, then Back to menu (on the next result menu). Check: New game opens the settings view, and Back to menu opens the Games screen.
12a. Let a child of about 5 to 8 years play on Easy, with a grown-up next to them who does not help. Check: in "3, 2, 1" the child points at its own name tag within 10 s.
12b. Same child. Check: the child turns the phone and the aim mark moves to the left side within 30 s after the first plate "<NAME>'S TURN!", with no help.
12c. Same child. Check: the child putts the ball (one stroke counted) within 60 s after the first plate, with no help.
12d. After the match, ask: "Play again?". Check: the child says yes.
13. Play with 4 phones and open the debug overlay. Check: the FPS value is 55 or more for 30 s. (REQ-GM-50)
14a. **Pixel world (REQ-GM-47i to 47n).** From 3 m, a tester points at the ball each time you say "mark" while it rolls on the farthest hole. Check: the finger points at the ball in 5 of 5 tries.
14b. From 3 m, ask a tester to point at the golfer and then at the windmill. Check: both answers are right for every tester.
14c. From 3 m, read aloud the names and strokes in the bar and one banner. Check: no error.

Items 1a, 2a, 2c, 4a, 4b, 4d, 5a, 5c, 5d, 6a to 6c, 7a to 7c, 7e, 7f, 8a, 8b, 8d, 8e, 9a to 9d, 10b, 11a to 11c moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-26-1a to A-26-11c). Items 4c and 8c keep only the part that needs a person (the color of the aim mark, the text of the banner). The numbers of the other items do not change.

Measurements (write down, no pass or fail): the turn angle that moves the aim mark from the middle to the side end; the delay from the swing to the ball moving; if a normal putt goes too far or too short; any hole that you find too hard or too easy; the time of a 3 hole match. Use them to tune the aim range, the putt speeds and the hole designs.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1b | Photo of the tile next to a photo of the game | Not run | | | |
| 2b | Photo of the course; note: the five objects, each yes or no | Not run | | | |
| 3a | Photo of the TV at the start of a turn | Not run | | | |
| 3b | Photo of the golfer next to the phone color | Not run | | | |
| 3c | Note: stopwatch seconds of the plate | Not run | | | |
| 3d | Photo of both phones | Not run | | | |
| 4c | Photo of the gold mark | Not run | | | |
| 5b | Video of a putt | Not run | | | |
| 5e | Video (240 fps); note: frames and ms for 5 putts | Not run | | | |
| 7d | Video of 30 s of a barrier; note: ball passed (yes or no) | Not run | | | |
| 8c | Photo of the banner "Picked up after 6 strokes" | Not run | | | |
| 8f | Note: strokes counted by hand and in the bar | Not run | | | |
| 10a | Photo of the result menu with 2 phones | Not run | | | |
| 10c | Note: hole and strokes after Try again | Not run | | | |
| 10d | Note: the screen after New game and after Back to menu | Not run | | | |
| 12a | Note: the child, the age, seconds until it points | Not run | | | |
| 12b | Note: seconds until the mark moves | Not run | | | |
| 12c | Note: seconds until the first stroke | Not run | | | |
| 12d | Note: the answer of the child | Not run | | | |
| 13 | Overlay screenshot (FPS) with 4 phones | Not run | | | |
| 14a | Note: right answers of 5 | Not run | | | |
| 14b | Note: answers of each tester | Not run | | | |
| 14c | Note: errors made when reading | Not run | | | |

History:

- -: **Not run**. New (2026-10-17).

