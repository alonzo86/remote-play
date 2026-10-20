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

1a. Look at the launcher of the Android TV. Check: the TV app is named **Sababi: TV Games**.
1b. Start the TV app. Check: the Android splash shows the pixel mascot (a yellow face with sunglasses) on a black background.
1c. At the very first start only: the logo screen waits for the language choice. Choose ENGLISH with OK (Test 17 checks the language). Check: the logo screen does not go on until you press OK.
1d. Close the TV app and start it again. Check: the logo screen shows the mascot and the word SABABI, and it stays between 2.0 and 3.0 seconds (stopwatch from the first frame of the logo screen), then the **PLAYERS** screen shows. In a photo of the logo, zoomed to 400%, the edges of the pixels are hard squares (no smooth blend between two colors).
1e. Look at the **PLAYERS** screen. Check: it shows a QR code, the words ROOM CODE with a room code of 4 letters, a join PIN of 4 digits, and 4 slots. (Changes with issue #52: the PIN goes away.)
1f. Only if the TV has no Wi-Fi or Ethernet address: Check: the QR code is empty and the screen says that the TV has no network address.
2a. Start the controller app on one phone. Check: the app is named **Sababi: Remote**.
2b. Look at the phone screen. Check: the screen is in **portrait** and shows the title SABABI.
3a. Tap the TV in the list **ROOMS FOUND**. Check: the phone shows the PIN pad with the text "TYPE THE PIN THAT IS SHOWN ON THE TV". (Changes with issue #52: no list and no PIN pad.)
3b. Type the 4 digits of the PIN. Check: the phone shows "WAITING FOR THE HOST" with a colored square with the number 1, and the TV shows the phone in slot 1 with the word "READY".
3c. Look at the bottom of the TV screen. Check: the line **PRESS OK TO CONTINUE** shows and blinks. The screen has no Continue button and no count of players.
3d. Press OK on the remote. Check: the TV shows the Games screen, and the phone says "CHOOSE A GAME ON THE TV".
4a. Tap **Disconnect** (top right on the phone). Check: the list **ROOMS FOUND** shows the TV as a white button with the text "<code> x/y", for example "KQZM 0/4" (a room with no player). (Changes with issue #52: no list.)
4b. Tap that button and type the PIN. Check: the phone joins (it shows "WAITING FOR THE HOST"). (Changes with issue #52.)
4c. Tap **Disconnect**, then tap **Refresh** (white). Check: the list shows "SEARCHING..." at once, and the TV is in the list again within 2 seconds of the tap. (Changes with issue #52: no Refresh.)
4d. REQ-FL-83. Use the TV app on a Mac, where the list stays empty. Wait 30 seconds without a tap. Check: the list stays empty (the scan never starts by itself). Tap Refresh. Check: the TV shows in the list within 15 seconds. If the Mac asks for the Local Network permission, answer for the app that runs the TV; the scan works without it. (Changes with issue #52.)
5. (Removed. There is no join by IP address, REQ-A4. The join by QR code is Test 2, the PIN rules are Test 21.)
6a. Tap **Disconnect** on the phone. Check: within 5 seconds the TV slot of the phone shows no "READY". (Today the slot shows "LOST" for up to 30 seconds and then is empty. Changes with issue #44: the slot is empty within 5 seconds and never shows "LOST".)
6b. Close the controller app and start it again. Check: the Android splash (the mascot on black) is already in portrait (the phone does not turn), and it is the only splash: the Connect screen follows at once, with no logo screen.
6c. Look at the Connect screen. Check: the heading "ROOMS FOUND" and the button **Refresh** are white (not another color). (Changes with issue #52.)
6d. Join the TV, close the app without **Disconnect** and start it again. Check: the phone joins the same TV again by itself within 10 seconds of the start, with no tap (REQ-N6).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the launcher with the name of the TV app | Not run | | | |
| 1b | Photo of the TV splash | Not run | | | |
| 1c | Photo of the logo screen with the language choice (first start only) | Not run | | | |
| 1d | Video of the TV start with the stopwatch (time of the logo screen); zoomed photo of the logo | Not run | | | |
| 1e | Photo of the PLAYERS screen | Not run | | | |
| 1f | Photo of the PLAYERS screen with no network (or N/A) | Not run | | | |
| 2a | Photo of the phone launcher with the app name | Not run | | | |
| 2b | Photo of the phone in portrait | Not run | | | |
| 3a | Photo of the phone with the PIN pad | Retest | R1 | Chat report 2026-10-09 (no file) | R1: the owner found the Continue button redundant (it was the only focus target) and the count of players repeated the slot list. Changed on 2026-10-09 (FD-17, REQ-FL-6, 7): the button and the count are gone, and 'PRESS OK TO CONTINUE' shows once a phone has joined. The old check cannot pass any more. Retest the new screen. |
| 3b | Photo of TV and phone together: slot 1 'READY' and 'WAITING FOR THE HOST' | Retest | R1 | Chat report 2026-10-09 (no file) | Same result as step 3a (the step was split). |
| 3c | Photo of the TV bottom line 'PRESS OK TO CONTINUE' | Retest | R1 | Chat report 2026-10-09 (no file) | Same result as step 3a (the step was split). |
| 3d | Photo of the Games screen and of the phone text | Retest | R1 | Chat report 2026-10-09 (no file) | Same result as step 3a (the step was split). |
| 4a | Photo of the phone list with the button '<code> x/y' | Not run | | | |
| 4b | Photo of the phone after the join | Not run | | | |
| 4c | Video of the tap on Refresh with the stopwatch (seconds until the TV shows) | Not run | | | |
| 4d | Video on the Mac: list empty for 30 s, then the TV after Refresh, with the seconds | Not run | | | |
| 5 | (Removed with the join by IP address) | Not run | | | |
| 6a | Photo of the TV slots 5 s after the tap, and the seconds until the slot is empty | Not run | | | |
| 6b | Video of the app start in portrait: splash, then the Connect screen | Not run | | | |
| 6c | Photo of the Connect screen | Not run | | | |
| 6d | Video: close the app, start it, the phone joins again; the seconds | Not run | | | |

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
4. Put a QR code that is not from Sababi in front of the scanner. Check: the phone shows the message "THIS IS NOT A SABABI CODE."

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Phone screenshot of the connect screen: the button text | Not run | | | |
| 2a | Screen recording of the scan, with the seconds to join | Not run | | | |
| 2b | Screen recording of the scan: the PIN pad does not show | Not run | | | |
| 3a | Phone screenshot after Back in the scanner | Not run | | | |
| 3b | Note: the app is open; `adb logcat -d -s godot > docs/evidence/2/<run>-log.txt` if it crashes | Not run | | | |
| 4 | Phone screenshot of the message | Not run | | | |

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

Measurements (not steps): the values read in R0 are in the Notes. Write the exact values of each reading in the Notes of the step.

History:

- R0: **Fail**. RTT above 60 ms, Rx Hz above 55, Gap 150 to 380 ms, Lost 0. TV app on a desktop (not a TV box), phone on the same Wi-Fi: not yet representative of a real TV. The total delay (camera) was not tested.

## Test 6

### Treasure Maze

Needs: 1 to 4 phones, 1 TV, a stopwatch, a phone camera. Covers: REQ-MZ-3 to 9, REQ-MZ-12, REQ-MZ-13, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-90 to 95.


**Steps**

1. Start **Treasure Maze** with 1 phone. Put the phone flat on a table in the countdown. Take a photo of the ball at "3" and a photo at "1". Check: the ball is at the same place in both photos (REQ-MZ-3).
2a. Keep the phone flat on the table. Count 10 seconds from "GO" with the stopwatch. Check: the ball stays inside the start cell (the cell with the lighter frame) for the 10 seconds (REQ-MZ-4, dead zone 0.03).
2b. Hold the phone and play the maze to the chest. Record a video of the TV. Check: the ball never crosses a wall and never sits on top of a wall (0 times in the video, REQ-MZ-4).
2c. Bring the ball to the chest. Check: the result menu opens within 2 seconds, names the winner and shows the time (REQ-MZ-5).
3. (Removed. Tuning of `TILT_ACCEL`, `FRICTION` and `DEADZONE` is not a test. The limits are in step 2a and in the Measurements note.)
4a. Repeat with 2 phones, then with 4 phones. Open the debug overlay. Check on every row, during the race: Rx Hz is 50 or more, Gap ms is below 80, and Lost is 0 (the "acceptable" limits of Test 4).
4b. With 4 phones, tilt each phone in turn for 2 seconds. Check: the ball of that phone, and only that ball, moves within 1 second.
5a. Tilt the phone 15 degrees (use a protractor app) to the right and hold it still. Tap **RECENTER**. Keep holding the phone at the same angle for 5 seconds. Check: the ball moves less than one ball width (36 px) in the 5 seconds after the tap. (Changes with issue #55.)
5b. Tilt the phone 15 degrees to the right and hold it still. Tap **A** 5 times and **B** 5 times. Check: the ball keeps moving to the right (A and B do not recenter, REQ-MZ-8).
5c. Hold the phone tilted 15 degrees to the right in the countdown. Check: in the 3 seconds after "GO" the ball moves less than one ball width (36 px) (the phone recenters at GO).
6a. Open the tile of **Treasure Maze**. Check: the settings view opens with Difficulty on MEDIUM, and **Back** (left) and **Start** (right) are on one line at the bottom.
6b. With the remote, select the Difficulty row. Press Right 4 times, then Left 4 times. Check: after the 4 presses to the right the value is HARD, and after the 4 presses to the left it is EASY (it stops at the ends, it does not wrap).
6c. Play one round on each of Easy, Medium and Hard. Count the cells in a photo of the board. Check: Easy is 13 x 6, Medium is 16 x 8 and Hard is 18 x 9 cells.
6d. On each of the three boards, measure in the photo the distance from the outer edge of the walls to the edge of the screen. Check: it is at least 60 px at 1920 x 1080 (3.1 percent of the screen width at the left and right, 5.6 percent of the screen height at the bottom), and no part of the board is cut off (REQ-MZ-7, REQ-GM-40).
6e. On Hard, tilt the ball 15 degrees along the longest straight corridor. Check: the ball goes along the whole corridor with no stop before its end (0 stops in the video).
6f. Open the settings view. Check: the Theme row shows GARDEN first. Press Right: CASTLE, then ICE, then Right again: ICE stays (REQ-MZ-12, REQ-GM-93).
6g. In the settings view, press Back on the remote. Check: the Games screen shows with the tile of Treasure Maze in focus, and the app stays open.
6h. With the only phone connected, open the settings view. Switch the Wi-Fi of the phone off and start the stopwatch. Check: within 7 seconds Start is dimmed and a yellow line says "NO PLAYERS CONNECTED". Switch the Wi-Fi on. Check: within 5 seconds Start works again. (The time to lose a phone is 5 seconds today. It changes with issue #56.)
7a. **Pixel world (phase 4, REQ-MZ-7).** Take a photo of the TV on Medium and zoom to a wall corner, a ball and the chest. Check: no pixel at the edge of these shapes shows a mix of the two colors beside it (the edge is a hard step).
7b. Play with 4 phones. From 3 m, a person who does not see the phone screens matches each ball to the color square on its phone. Check: 4 of 4 balls are matched correctly, on the Garden lawn too (the white ring of the ball, REQ-MZ-7).
7c. From 3 m, look at the maze on Medium and Hard. Check: the title and the timer do not touch (at least 1 px of black bar between them in the photo), and the torch flames (Castle) and the sparkle of the chest change position in a hard step (2 positions, about every 0.55 s of the sparkle).
7d. Play one round in each theme: Garden, Castle and Ice. Check: the balls and the chest are the same in the three themes, and the Theme row works with the remote (Left and Right).
7e. In each theme, stand 3 m from the TV. Check: a person reads aloud the names of the two pictures at each side of the maze from this list, with 0 errors in 6 pictures: Garden tree and rose bush, Castle torch and shield, Ice penguin and iceberg (REQ-MZ-13).
7f. Bring a ball to the chest. Check: the lid of the chest opens and the gold shows.
7g. Check with a child of 5 to 8 years. Say only: "Where do you need to go?" Check: the child points to the chest within 10 seconds of "GO", without help.
7h. Check: the title on the TV reads TREASURE MAZE in English and מבוך האוצר in Hebrew (the owner confirms the Hebrew text).

Covered by machines (not repeated here): the result menu has New game and returns to the view with the last choice (A-11-5), the rows of the result menu (A-11-1, A-11-2).

Measurements (no pass or fail; tune the constants if the owner asks): with the phone tilted 15 degrees the ball speeds up by about 670 px/s2 (`TILT_ACCEL` 2600, `FRICTION` 1.6, `MAX_SPEED` 760). Note the time the ball needs to cross the longest corridor of Easy, Medium and Hard.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Two photos of the ball at "3" and at "1" | Pass | R1 | Chat report 2026-10-09 (no file) | R1: the owner played the maze and reported 'it works perfectly'. The steps of the countdown were not reported one by one. |
| 2a | Video of the ball for 10 s with the stopwatch visible | Pass | R1 | Chat report 2026-10-09 (no file) | R1: 'i tested the maze game and it works perfectly'. Same result as old item 2 (split 2026-10-20). The number of phones was not written down (step 4 is still open). |
| 2b | Video of the TV during the whole round | Not run | | | Added 2026-10-20 (REQ-MZ-4: a ball never stays inside a wall). |
| 2c | Photo of the result menu with the stopwatch time | Pass | R1 | Chat report 2026-10-09 (no file) | Same result as old item 2 (split 2026-10-20). |
| 3 | (Removed.) | N/A | R1 | Chat report 2026-10-09 (no file) | R1: no tuning is needed, because the owner reported no problem. The constants are unchanged. Removed 2026-10-20: tuning is not a test. |
| 4a | Overlay screenshot of every row during the race (2 phones and 4 phones) | Not run | | | |
| 4b | Video of 4 phones tilted one after the other | Not run | | | |
| 5a | Video of the ball: tilt, RECENTER, 5 s | Not run | | | |
| 5b | Video of the ball: tilt, then 10 taps on A and B | Not run | | | |
| 5c | Video of the ball in the countdown and 3 s after GO | Not run | | | |
| 6a | Photo of the settings view | Not run | | | Added 2026-10-09 (REQ-MZ-9). The sizes in `LEVELS` are first guesses. |
| 6b | Video of the Difficulty row with the key presses | Not run | | | Same result as old item 6. |
| 6c | Photo of the board on Easy, Medium and Hard with the cells counted | Not run | | | Same result as old item 6. |
| 6d | Photo of each board with the margin measured | Not run | | | Same result as old item 6. |
| 6e | Video of the ball in the longest corridor of Hard | Not run | | | Same result as old item 6. |
| 6f | Photos of the Theme row with GARDEN, CASTLE and ICE | Not run | | | Same result as old item 6. |
| 6g | Video of Back on the remote | Not run | | | Same result as old item 6. |
| 6h | Video with the stopwatch: Wi-Fi off, Start dimmed, Wi-Fi on | Not run | | | Same result as old item 6. |
| 7a | Zoomed photo of a wall corner, a ball and the chest | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-15 (Treasure Maze). |
| 7b | Photo of 4 balls next to the 4 phones; the 4 matches | Not run | | | Same result as old item 7. |
| 7c | Photos of the title and timer; of the sparkle in 2 positions | Not run | | | Same result as old item 7. |
| 7d | Photo of each theme | Not run | | | Same result as old item 7. |
| 7e | Note: the 6 names read aloud | Not run | | | Same result as old item 7. |
| 7f | Photo of the open chest | Not run | | | Same result as old item 7. |
| 7g | Note: time in seconds until the child points to the chest | Not run | | | Same result as old item 7. |
| 7h | Photo of the title in English and in Hebrew | Not run | | | Same result as old item 7. |

History:

- 2026-10-20 (not run): the steps were made measurable and split (items 2, 4 to 7 got letters; item 3 is removed; 2b, 6h limits and 7e to 7h are checks with numbers). Feel notes moved to Measurements.
- 2026-10-10 (not run): item 7 is new: the maze world is a pixel world (phase 4 of the arcade style), walls 12 px, Hard cells 76 px.
- 2026-10-09 (not run): item 6 is new (REQ-MZ-9, REQ-GM-90 to 97): the settings view, the three difficulties, the yellow chosen value, Back and Start on one line, and Start dimmed when no phone fits.
- R1: items 1 to 3 **Pass** (the owner: 'it works perfectly'). Items 4 and 5 are not run: 2 to 4 phones, and RECENTER with A and B.
- R0: **Retest**. First run: drift and inverted controls (caused by 'Invert axes' being on). After the fix the maze looks good on the desk. The feel and the constants were not judged. Item 5 is new (RECENTER, and A and B do nothing).

## Test 7

### Disconnect and reconnect

Needs: 2 phones, 1 TV, a stopwatch, a third phone to call (for item 7). Covers: REQ-GM-30, REQ-GM-30a, REQ-T5, REQ-N5, REQ-N6, REQ-FL-25, REQ-FL-52, REQ-MR-14, REQ-MZ-8.

Time limit used below: the TV pauses when a phone is silent for 5 seconds (`Protocol.PEER_TIMEOUT_MS`), so "at once" means 8 seconds at most, measured from the moment you switch the Wi-Fi off. (Changes with issue #56: 3 seconds, so 6 seconds at most.)

**Steps**

1a. With two phones joined, during the maze, switch the Wi-Fi of one phone (2P) off for 15 seconds. Check: the phone shows "RECONNECTING..." within 8 seconds.
1b. Check: the TV pauses (the maze stops) and shows the card "2P LOST CONNECTION" with the line "WAITING TO RECONNECT", within 8 seconds.
1c. Check: the card has the buttons **Resume without 2P** and **End game**, and it has no **Resume** button.
1d. Switch the Wi-Fi on. Check: within 10 seconds the card title changes to "2P reconnected" and the card shows the button **Resume**. Wait 10 seconds without a press. Check: the maze stays paused (the ball of 1P does not move).
1e. Press **Resume**. Check: the maze goes on (the ball of 1P moves with the phone within 3 seconds).
2. On the Games screen, lock the phone screen for 10 seconds, then unlock. Check: within 10 seconds the phone shows its waiting screen again with the same slot number, and the TV slot was "READY" all the time or came back to "READY". (Android can stop the app in the background.)
3a. On the Games screen (not in a game), switch the phone Wi-Fi off for 45 seconds. Check: after 45 seconds the TV shows the slot of the phone as empty. (Changes with issue #44: the slot is empty within 5 seconds.)
3b. Switch the Wi-Fi on. Check: within 10 seconds the phone shows the PIN pad (the TV does not know it any more). (Changes with issue #52: no PIN pad.)
3c. Type the PIN. Check: the phone joins again and shows "CHOOSE A GAME ON THE TV" (maybe in a different slot).
4a. Start the maze with two phones. Switch one phone Wi-Fi off and wait for the card. Choose **Resume without 2P** (for a player with a profile the card says its name, Test 20 item 6). Check: the game continues without that player: the ball of that player is gone and the other ball moves within 3 seconds.
4b. Switch the Wi-Fi on. Check: within 10 seconds the phone shows the PIN pad. (Changes with issue #52.)
4c. Type the PIN. Check: the phone joins as a new player and shows "YOU JOIN NEXT ROUND.".
5a. With only one phone joined, switch its Wi-Fi off during the maze. Check: within 8 seconds the game pauses with the card "1P LOST CONNECTION" that has only **End game** (no Resume, because nobody is connected).
5b. Switch the Wi-Fi on. Check: the card says "1P reconnected" and offers **Resume**.
5c. Do steps 5a and 5b in Road Rally. Check: the same card and the same buttons both times.
5d. Do steps 5a and 5b in Banana Party. Check: the same card and the same buttons both times.
5e. Press Back on the card. Check: the TV asks "END THE GAME?".
6a. On the phone pad, tap **Disconnect** once. Check: the phone shows the Connect screen less than 1 second after the tap (no second tap).
6b. Look at the **Disconnect** button. Check: all letters of the word are inside the frame of the button (none is cut).
6c. Check the pad buttons: the face of A is green and the face of B is red.
6d. Press A, then B, and look at the side of the phone. Check: while the finger is down, the face of the button is lower than when it is released (the lower edge shows less).
6e. Look at the waiting screen and at the pad. Check: **Disconnect** is at the top right on both.
7a. With one phone in a game, call that phone from another phone and answer. Check: within 8 seconds of the answer the game pauses with the card "1P LOST CONNECTION".
7b. End the call and go back to the controller app. Check: the phone says "RECONNECTING..." and then joins again in 10 seconds or less (stopwatch from the return to the app).
7c. Check: the card says "1P reconnected" with **Resume**, and **Resume** goes on with the game.
7d. Do a call that lasts 70 seconds (the slot is kept 5 minutes while the game is paused). Check: after the call the phone joins again in the same slot, with no PIN.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Video of the phone with the stopwatch: 'RECONNECTING...' and the seconds | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the phone disconnected from the Wi-Fi and showed 'Reconnecting...', but on the TV the game kept going (no pause, no card). The off time was not written down (it must be more than 5 s). Cause (found on 2026-10-09): the TV waited for a close handshake that a phone with no Wi-Fi cannot answer, so it never marked the phone lost. The same failure was seen in R0. Fixed on 2026-10-09 (a silent phone is lost at once, PROTOCOL.md) and the pause changed (REQ-GM-30). A test now reproduces it. Retest. |
| 1b | Video of TV and phone with the stopwatch: the card, the seconds | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as step 1a (the step was split). |
| 1c | Photo of the card with its buttons | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as step 1a (the step was split). |
| 1d | Video: Wi-Fi on, the card title 'reconnected', 10 s wait | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as step 1a (the step was split). |
| 1e | Video: Resume, the ball moves | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as step 1a (the step was split). |
| 2 | Note: the seconds the phone needs to show its waiting screen, the slot number before and after | Not run | | | |
| 3a | Photo of the Games screen after 45 s (slot empty) | Not run | | | |
| 3b | Photo of the phone PIN pad, with the seconds | Not run | | | |
| 3c | Photo of the phone after the PIN | Not run | | | |
| 4a | Video: Resume without 2P with a lost phone | Not run | | | |
| 4b | Photo of the phone PIN pad | Not run | | | |
| 4c | Photo of the phone with 'YOU JOIN NEXT ROUND.' | Not run | | | |
| 5a | Photo of the card of the only player lost (End game only), in the maze | Retest | R1 | Chat report 2026-10-09 (no file) | R1: a phone call stopped the game ('as expected') and the TV showed 'No players connected'. After the call there was no way to resume. The owner asked for a message that says which player disconnected, with Resume only when a player is still connected or the disconnected player is back. Changed on 2026-10-09 (REQ-GM-30, 30a): the game waits with a card, there is no Resume while nobody is connected, and Resume shows when the phone is back. The slot is kept 5 minutes while paused. The old check ('No players connected' at once) is gone. Retest. |
| 5b | Photo of the card after the return (Resume), in the maze | Retest | R1 | Chat report 2026-10-09 (no file) | Same result as step 5a (the step was split). |
| 5c | Photos of the card (End game only) and after the return (Resume), in Road Rally | Retest | R1 | Chat report 2026-10-09 (no file) | Same result as step 5a (the step was split). |
| 5d | Photos of the card (End game only) and after the return (Resume), in Banana Party | Retest | R1 | Chat report 2026-10-09 (no file) | Same result as step 5a (the step was split). |
| 5e | Photo of the question 'END THE GAME?' | Retest | R1 | Chat report 2026-10-09 (no file) | Same result as step 5a (the step was split). |
| 6a | Video of the tap and the Connect screen (the seconds) | Not run | | | |
| 6b | Photo of the Disconnect button on the pad | Not run | | | |
| 6c | Photo of the pad buttons A and B | Not run | | | |
| 6d | Two photos of a button: pressed and released | Not run | | | |
| 6e | Photos of the waiting screen and the pad (top right) | Not run | | | |
| 7a | Video of a phone call: the card, with the seconds | Not run | | | |
| 7b | Video of the return: 'RECONNECTING...', the join, the seconds | Not run | | | |
| 7c | Video: the card 'reconnected', Resume, the game goes on | Not run | | | |
| 7d | Video of the 70 s call and the return, same slot | Not run | | | |

Measurements (not steps): write the reconnect time after the call (7b) in the Notes of step 7b.

History:

- R1: **Fail** (item 1) and **Retest** (item 5). A phone without Wi-Fi did not pause the game, and a phone call ended it with no way to resume. Both changed on 2026-10-09 and wait for the retest. Items 2, 3, 4 and 6 are not run.
- R0: **Retest**. Wi-Fi off on the phone: the phone shows 'Reconnecting...'. The game kept running and the TV never showed 'Waiting for P1 to reconnect'. Wi-Fi on: the phone reconnected and the game went on. The off time was not measured (the TV pauses only after 5 s of silence). Item 6 (Leave twice, A green and B red) is new.

## Test 8

### TV remote

Needs: 1 phone, 1 TV with its remote, a stopwatch. Covers: REQ-GM-31, REQ-GM-31a, REQ-GM-33, REQ-FL-41, REQ-FL-55.


**Steps**

1a. Use only the remote. On each of these 7 screens press Up, Down, Left and Right once each: Connect, Games, Players modal, OPTIONS (Settings), the settings view of a game, the pause menu and the result menu. Check: on each screen the focus moves at least once, and OK selects the focused item (REQ-GM-33).
1b. Look at the menus. Check: a focused menu item is yellow with a pixel cursor in front of it, and the focused END GAME, QUIT and REMOVE are red (REQ-FL-41).
1c. On the Games screen, move the focus over 3 tiles. Check: the focused tile has a yellow frame and the bar under the grid shows the description of that game (REQ-FL-12, 13).
1d. Stand 3 m from the TV. A second person presses keys on the 7 screens of step 1a without saying where the focus is. Check: you name the focused item on 7 of 7 screens, also in Settings.
2a. In a game, press OK. Check: the pause menu opens with exactly three items: Resume, Try again and Back to menu. The timer on the TV stops (it shows the same value 5 seconds later).
2b. Choose **Back to menu**. Check: the question "END THE GAME?" opens with **Resume play** in focus (yellow) and **End game** below it (red when it has the focus). (Changes with issue #53.)
2c. Close the question, then press Back during play. Check: the same question opens and the timer stays stopped.
2d. On the question press Back. Check: the game plays on (the timer runs again).
2e. Choose **End game**. Check: the Games screen shows.
2f. Play a game to its result menu. Press Back. Check: the Games screen shows at once, with no question.
3a. In a game press Back and choose **End game**. Check: the Games screen shows. Press Back on the Games screen. Check: the Connect screen shows and the player slots are still filled (same number of players).
3b. Press Back on the Connect screen. Check: the quit question opens with **Stay** in focus.
4. Press the Menu key. If the remote has no Menu key, open **Settings** (the OPTIONS button on the Games screen) and use **Debug overlay**. Check: the overlay shows the header line that starts with "DEBUG" and the FPS number.
5a. Check: the Android TV home row shows the app with the name "Sababi: TV Games".
5b. Check: the icon shows the Sababi mascot (a yellow face with sunglasses) on black, and the banner shows the mascot and the word SABABI.
6a. On the phone, press the Android Back key on the waiting screen (joined, the TV on the Games screen). Check: the question "QUIT SABABI?" opens with **Stay** in focus and the app is still open 5 seconds later. (Changes with issue #54: no phone button has the focus.)
6b. Press the Android Back key in the middle of a game (the pad screen). Check: the same question opens and the app is still open 5 seconds later. Tap **A** 5 times while the question shows. Check: the TV shows no action of A.
6c. Press Back again on the question. Check: the question closes (Stay).
6d. Press Back, then choose **Quit**. Check: the app closes (REQ-FL-55).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Video of the 4 keys on each of the 7 screens | Not run | | | |
| 1b | Photos of a focused item in yellow, and of END GAME in red | Not run | | | Same result as old item 1. |
| 1c | Photo of a focused tile and the description bar | Not run | | | Same result as old item 1. |
| 1d | Note: 7 answers of the second person | Not run | | | Same result as old item 1. |
| 2a | Video of OK in a game, with the timer | Fail | R1 | Chat report 2026-10-09 (no file) | R1: pressing Back on the remote in the middle of a game quits the app completely. The 'End the game?' question was not seen. Cause: the engine setting `quit_on_go_back` was on, so the engine quit after the app had handled Back. Fixed on 2026-10-09 (REQ-FL-55). Retest. The OK key and the pause menu were not reported. |
| 2b | Photo of the question after Back to menu | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as old item 2 (split 2026-10-20). |
| 2c | Video of Back during play | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as old item 2. |
| 2d | Video of Back on the question | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as old item 2. |
| 2e | Video of End game | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as old item 2. |
| 2f | Video of Back on the result menu | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as old item 2. |
| 3a | Video of Back on the Games screen, with the slots visible | Fail | R1 | Chat report 2026-10-09 (no file) | R1: Back quits the app on every screen. The owner saw the app go back to the previous view for a moment before it closed. Same cause and fix as item 2. Retest. |
| 3b | Photo of the quit question | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as old item 3. |
| 4 | Photo of the overlay after the Menu key, or of the Settings switch | Not run | | | |
| 5a | Photo of the TV home row with the app name | Not run | | | |
| 5b | Photo of the icon and of the banner | Not run | | | Same result as old item 5. |
| 6a | Video of Back on the phone waiting screen, with the stopwatch | Not run | | | The question and its answers are tested without a phone (`ui_states`); only the real Back key is open. |
| 6b | Video of Back on the pad screen and 5 taps on A | Not run | | | Same result as old item 6. |
| 6c | Video of Back on the question | Not run | | | Same result as old item 6. |
| 6d | Video of Quit | Not run | | | Same result as old item 6. |

History:

- 2026-10-20 (not run): the steps were split and the criteria made measurable (focus on 7 screens, timer values, 5 s). Items 2b to 2e change with issue #53, item 6a with issue #54.
- R1: **Fail** (items 2 and 3). Back quits the app on every screen. Fixed on 2026-10-09 (REQ-FL-55). Items 1, 4 and 5 are not run.
- Item 2 changed before the first run (the 'End the game?' question).

## Test 8b

### The TV flow and the style

Needs: 1 to 2 phones, 1 TV, a stopwatch. Covers: REQ-FL-1 to 46, REQ-FL-56, 57, REQ-FL-81, FD-1 to 17, FD-23. Item 7 (a TV set to Hebrew) moved to Test 17 on 2026-10-10: FD-19 replaced REQ-FL-54, so the TV now offers Hebrew and no longer stays English.


**Steps**

1a. Start the TV app from cold (not the first start: at the first start the logo waits for the language choice). Start the stopwatch when the logo shows. Check: the Connect screen shows after 2 to 3 seconds (REQ-FL-2).
1b. Start the app again. Press OK on the logo screen. Check: the Connect screen shows within 1 second (REQ-FL-3).
1c. Start the app again. Press Back on the logo screen. Check: the app is still open 3 seconds later (it shows the logo or the Connect screen).
2a. On the Games screen, with one phone joined, look at all tiles. Check: every tile shows its screenshot (no color placeholder), the number of tiles equals the number of games in the registry (9 on 2026-10-20), and each tile shows its title and its player range (REQ-FL-13, 56, 57). (Changes with issue #57: a tile shows only the world of the game.)
2b. Stand 3 m from the TV. Check: you read aloud the title and the player range of 3 tiles, with 0 errors (REQ-FL-40).
3a. Open the **players badge** (OK). Check: the modal shows 4 slots, a QR code, the room code and the PIN. (Changes with issue #52: the PIN goes.)
3b. Press **Remove** on a player. Check: the phone shows "THE HOST REMOVED YOU. SCAN THE CODE TO JOIN AGAIN." and it is still on its Connect screen 30 seconds later (it does not reconnect by itself).
3c. Join again with the QR code. Check: the slot fills within 5 seconds.
4a. Join a phone while a game runs. Check: the phone says "A ROUND IS IN PROGRESS" and "YOU JOIN NEXT ROUND." (it needs the PIN from the list, or it scans the QR code; changes with issue #52).
4b. Check: the new phone has no object in the running game.
4c. Finish the round and start the next round. Check: the new phone has its object in the next round.
5a. Check the motion on the TV box with the overlay on: the logo (with its confetti), the blinking prompts and the screen changes. Check: the overlay FPS is 55 or more at all times (REQ-FL-44).
5b. Look at a test screen: a black background, a focused menu item, a modal frame and a tile frame. Check: you name the colors black, yellow, blue and white for them, 4 of 4 correct.
6a. Phone: open the connect, waiting and pad screens. Check: on each screen the background is black and the text is in the pixel font of the TV.
6b. Check: on the waiting screen and on the pad screen the square of the player has the same color as the slot of the player on the TV.
7. (Moved to Test 17.) The old step was: set the TV to Hebrew, region Israel, and check that the app stays English and left to right. FD-19 replaced that rule on 2026-10-10: the app now has Hebrew, and the result of R1 (the mirrored English UI) is not a defect any more.
8a. On the Games screen with the remote, press Up from a tile in the first row, from a tile in the last row, and from a tile after the grid has scrolled. Check: Up goes to the players badge and Right goes on to **OPTIONS**, so OPTIONS is reached in 2 key presses or less from each tile (REQ-FL-16).
8b. Open the players badge. Press each of the four arrow keys 5 times. Check: the focus stays on the buttons of the modal and no game tile shows a yellow frame (REQ-FL-34).
8c. In Hebrew, focus a tile. Check: in a photo, a gap of black background shows between the yellow cursor and the title of the tile.
9a. In English, open three cards: "NO PLAYERS CONNECTED" (in a game with one phone, tap **Disconnect** on the phone; it frees the slot at once), "PAUSED" (OK in a game) and "END THE GAME?" (Back in a game). Check: the title of each card is white and the items below are yellow only with the focus (REQ-FL-81). (Switching the phone Wi-Fi off does not open this card. It opens the card "LOST CONNECTION", REQ-GM-30.)
9b. In Hebrew, open the same three cards. Check: each title is on one line (אין שחקנים מחוברים, מושהה, לסיים את המשחק?).
10a. Settings: press Down through all rows with the remote. Check: the focused row is fully on the screen at each press, and **Back** stays visible at the bottom.
10b. Games screen: focus 3 tiles in turn, in English and in Hebrew. Check: only the focused tile has its title moved in, and the cursor does not touch the text of its title.
10c. Play a game in Hebrew with a leader (and Road Rally too). Check: the timer box and the leader chip are at opposite sides of the screen and do not overlap (0 px of overlap in the photo).
10d. Open the result menu in Hebrew. Check: the time says ש׳ and each row has the avatar next to the color.
10e. On the phone, look at the waiting screen and the pad. Check: the avatar is beside the color square on both screens.
10f. Play a round with 4 phones to the result menu. Check: row 1 shows the gold medal, row 2 silver, row 3 bronze, and row 4 has none (tie and solo rules: A-11-7).
10g. Games screen: scroll down to the second row of games, move up to the first row, on to the players badge, then to OPTIONS, in English and in Hebrew. Check: OPTIONS is reached in both languages.

Covered by machines (not repeated here): the buttons TRY AGAIN, NEW GAME and BACK TO MENU of the result menu (A-11-1) and the medals of a tie or a solo round (A-11-7).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Video from cold start with the stopwatch: logo, then Connect | Not run | | | |
| 1b | Video of OK on the logo with the stopwatch | Not run | | | Same result as old item 1. |
| 1c | Video of Back on the logo, 3 s | Not run | | | Same result as old item 1. |
| 2a | Photo of the Games screen with all tiles | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the screenshots of the games are missing on the Games screen of the Android 10 TV. What the tiles showed instead (dark boxes, colors) was not written down. The same tiles show on a desktop with the OpenGL renderer. The cause is not confirmed. Changed on 2026-10-09 (REQ-FL-56, 57): the image is rounded in the file and not clipped, a placeholder shows when a tile does not load, and a warning goes to the log. Retest. If they are still missing, save `adb logcat -d -s godot` and look for 'Tile image'. |
| 2b | Note: the 3 tiles read aloud with the errors counted | Fail | R1 | Chat report 2026-10-09 (no file) | Same result as old item 2 (split 2026-10-20). |
| 3a | Photo of the Players modal | Not run | | | |
| 3b | Photo of the phone after Remove, and 30 s later | Not run | | | Same result as old item 3. |
| 3c | Photo of the slot after the join again, with the time | Not run | | | Same result as old item 3. |
| 4a | Photo of the phone 'A round is running' | Not run | | | |
| 4b | Photo of the running game with the new phone in the room | Not run | | | Same result as old item 4. |
| 4c | Photo of the next round with the new object | Not run | | | Same result as old item 4. |
| 5a | Overlay FPS screenshot during the logo, tile growth and screen changes | Not run | | | |
| 5b | Photo of the test screen; note: the 4 color names | Not run | | | Same result as old item 5. |
| 6a | Photos of the phone connect, waiting and pad screens next to the TV | Not run | | | |
| 6b | Photos of the phone square next to the TV slot | Not run | | | Same result as old item 6. |
| 7 | (Moved to Test 17.) Photos of the Connect and Games screens on a TV set to Hebrew; of the phone set to Hebrew | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the TV is set to the IL region and Hebrew. The text was English, but the layout was mirrored (right to left). Fixed on 2026-10-09 (REQ-FL-54): the app sets the locale to English and the layout to left to right. Retest on the TV. The phone was not tried. |
| 8a | Video of the key presses from 3 tiles to OPTIONS | Not run | | | |
| 8b | Video of 20 arrow presses in the Players modal | Not run | | | Same result as old item 8. |
| 8c | Photo of a focused tile in Hebrew | Not run | | | Same result as old item 8. |
| 9a | Photos of the three cards in English | Not run | | | |
| 9b | Photos of the three cards in Hebrew | Not run | | | Same result as old item 9. |
| 10a | Photos of Settings scrolled, first and last row | Not run | | | |
| 10b | Photos of three focused tiles in English and in Hebrew | Not run | | | Same result as old item 10. |
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

Needs: 1 to 4 phones (2 to 4 for items 5, 7 and 11), 1 TV, a stopwatch, a phone camera. Covers: REQ-MR-*, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Needs 1 to 4 phones (one phone is a time trial). Requirements: `docs/games/marble_race.md`. Start "Road Rally" and pick a track.


**Steps**

1a. Check: the TV shows the track from above and a black bar at the top with the title, the timer, "Finish in N m" and the leader chip (REQ-MR-9, REQ-MR-10, REQ-MR-40).
1b. Check: the track name shows at the bottom right (REQ-MR-35).
1c. Take a photo of the screen. Check: no text is closer than 60 px to the screen edge at 1920 x 1080 (REQ-GM-40). Stand 3 m from the TV. Check: you read aloud the title, the timer and the distance text with 0 errors.
1d. Play with 4 phones. Check: the top bar shows one leader chip (the first car, or TIE), not the order of all cars. The places 1st to 4th show in the result menu (A-11-3).
2a. Tilt every phone 30 degrees in the countdown "3, 2, 1". Take a photo at "3" and one at "1". Check: all cars are at the same places in both photos (REQ-MR-3).
2b. Check: at "GO!" every phone buzzes once (4 of 4 phones with 4 phones).
3a. Tilt right. Check: the car goes right on the screen (REQ-MR-40).
3b. Tilt the top of the phone up. Check: the car goes down on the screen (REQ-MR-40, REQ-3D-6).
4. (Removed. A feel check is not a test. The speed values `ACCEL` and `DAMPING` are in the Measurements note; the finish times are in item 8.)
5a. With 2 phones, drive at full tilt for 1 second into a wall, into an obstacle and into another car. Check: the phone buzzes at each of the 3 hits (REQ-MR-13).
5b. Push the car against a wall for 5 seconds with the phone on a table. Record a video with sound. Check: in every 1 second of the video you hear 7 buzzes or less (at least 150 ms between two buzzes, REQ-MR-13).
6. Check: the frame rate in the debug overlay is 55 or more, 5 readings in a row with 4 phones on Hard. (REQ-GM-50)
7a. Let one car run far ahead on a long track (Hard). Check: when the last car leaves the view, an arrow in the color of that car shows at the screen edge, inside the 60 px margin and under the top bar. (REQ-MR-42)
7b. Check: next to the arrow the text "N m behind" shows (N is a whole number). You read it aloud from 3 m with 0 errors. The number grows when the car falls further behind (two readings 5 seconds apart).
8a. Finish a race on 3 different tracks of the list and on the random track. Check: each of the 4 races ends with the result menu, which shows a winner and a winning time above 0 s (REQ-MR-51).
8b. In one race let one car stay at the start after the first car finishes. Start the stopwatch at the first finish. Check: the result menu opens within 4 to 5 seconds (REQ-MR-8: the other players have 4 s).
9a. Open the tile of **Road Rally**. Check: the settings view shows Difficulty (Left and Right), the Theme row and, under them, a carousel of 11 tiles (10 line sketches and a "?"), with no names, wider than the Difficulty row. The selected track is in the middle, and it is Track 1 the first time. (REQ-MR-53)
9b. Move the carousel with Left and Right. Check: it stops at both ends (after 11 presses the same tile stays). Choose track 2, then Start. Check: the road of the race has the same turns, in the same order from the start (left or right), as the sketch. (REQ-MR-54)
9c. Play Easy, Medium and Hard on one track. Read "Finish in N m" at the start and count the obstacles. Check: the line is the same, the counts rise from Easy to Hard, and each count is within 3 of 2, 6 and 10 for each 100 m of N (REQ-MR-50).
9d. Choose the "?" tile twice. Check: the two races have different roads. Then use Try again. Check: the road is the same as the race just before (REQ-MR-33).
9e. In the races of item 8, watch every bend. Check: no car stops for 2 seconds or more at a bend while its phone is tilted 15 degrees or more toward the road (0 stops, REQ-MR-52).
10. (Moved to the automated tests, A-9-10.)
11a. After a change to the shared game code (the countdown clock, the buzz cool-down, the end with no players), run this test again with 2 phones on each track. Check: no phone buzzes in "3, 2, 1" and each phone buzzes once at "GO" (A-multi_phone covers the simulated phones only).
11b. Tilt a phone 15 degrees to the right until the car moves, then tap **RECENTER** during a race. Check: 5 seconds after the tap, the car moved less than 10 px in the last 2 seconds. (Changes with issue #55: RECENTER may go away from games that do not point.)
11c. With 1 phone, start a race. Check: Start works (no "Needs 2 players") and the race is a time trial. Finish it. Check: the result menu shows the time and a medal picture.
12a. **Pixel world (REQ-MR-44, REQ-GM-47i to 47n).** In each theme, take a photo of the race and zoom to a car, a wall and an obstacle. Check: no pixel at the edge of these shapes shows a mix of the two colors beside it.
12b. Stand 3 m from the TV with 4 cars on the screen. Check: you count 4 cars, with a black outline on each, in each of the 3 themes (REQ-MR-43).
12c. Check: the finish line is a band of two rows of black and white cells.
12d. Check the frame rate in each theme: the overlay shows 55 FPS or more. Check: the road shows in the first frame after Start (no black road for more than 1 second).
13a. **Themes (REQ-MR-45, 46, 47, 48).** In the settings view, check: the row **Theme** shows CANDY ROAD, SPACE RALLY and JUNGLE RUN, in this order, and CANDY ROAD is the first value.
13b. Play one race in each theme. Check: the three obstacles match the theme: candy lollipops, gumdrops and cupcakes; space asteroids, satellites and craters; jungle logs, boulders and tiki masks. You name all 3 kinds in each theme with 0 errors from a photo.
13c. Press Try again. Check: the obstacles are at the same places as before.
13d. Check: the cars look the same in the three themes. Drive a car left. Check: its nose points left within 15 degrees (REQ-MR-48).
13e. Check: the scenery beside the road matches the theme (REQ-MR-57: candy lollipops, canes, ice creams, donuts, cookies; space rockets, planets, UFOs, stars; jungle palms, bushes, flowers, mushrooms) and 0 pieces cover the road or a car in the photo.
13f. Press Try again and then New game. Check: the theme you chose is still chosen.
13g. Switch the TV to Hebrew. Check: the title reads ראלי כבישים, and the theme names read כביש הממתקים, ראלי בחלל and ריצה בג׳ונגל. A Hebrew reader confirms the wording.
13h. Check with a child of 5 to 8 years. Ask: "Show me your car." Check: the child points to its own car within 10 seconds of "GO", without help. Ask: "Show me one thing you can hit." Check: the child points to an obstacle within 10 seconds.

Measurements (no pass or fail): note how the car feels at `ACCEL` and `DAMPING` and tell the owner if a constant needs a change. Fill the winning times of item 8a in the table below.

Item 10 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-9-10). The numbers of the other items do not change. The result menu with Try again, New game and Back to menu is covered by A-11-1 and A-11-5.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the race screen (top bar, track from above) | Not run | | | |
| 1b | Photo of the track name at the bottom right | Not run | | | Same result as old item 1. |
| 1c | Photo of the screen edges; note: the 3 texts read aloud | Not run | | | Same result as old item 1. |
| 1d | Photo of the top bar with 4 cars | Not run | | | Same result as old item 1. |
| 2a | Two photos: cars at "3" and at "1" | Not run | | | |
| 2b | Note: which phones buzzed at GO | Not run | | | Same result as old item 2. |
| 3a | Video: tilt right | Not run | | | |
| 3b | Video: tilt up | Not run | | | Same result as old item 3. |
| 4 | (Removed.) | N/A | | | Removed 2026-10-20: a feel check is not a test. |
| 5a | Note: buzz yes or no for the wall, the obstacle and the car | Not run | | | |
| 5b | Video with sound of the phone at the wall, buzzes counted for each second | Not run | | | Same result as old item 5. |
| 6 | Overlay screenshot (FPS), 5 readings, 4 phones on a Hard track | Not run | | | |
| 7a | Photo of an edge arrow | Not run | | | |
| 7b | Photos of the distance text, 5 s apart | Not run | | | Same result as old item 7. |
| 8a | Photo of each result menu; the winning time in the table | Not run | | | |
| 8b | Video with the stopwatch from the first finish to the result menu | Not run | | | Added 2026-10-20 (REQ-MR-8). |
| 9a | Photo of the settings view | Not run | | | Changed 2026-10-09: the four hand-made tracks were replaced by generated tracks. |
| 9b | Video of the carousel and the race; photo of sketch and road | Not run | | | Same result as old item 9. |
| 9c | Photos of Easy, Medium and Hard with the obstacle counts and N | Not run | | | Same result as old item 9. |
| 9d | Photos of the two "?" races and of Try again | Not run | | | Same result as old item 9. |
| 9e | Note: the number of stops at bends in the races of item 8 | Not run | | | Added 2026-10-20 (REQ-MR-52). Was a note on bad bends in item 9. |
| 11a | Video of the countdown and GO with 2 phones on each track | Not run | | | |
| 11b | Video: tilt, RECENTER, 5 s | Not run | | | Same result as old item 11. |
| 11c | Photo of the result menu of a 1-phone race | Not run | | | Same result as old item 11. |
| 12a | Zoomed photo in each theme | Not run | | | Added 2026-10-10 (phase 3 of the arcade style). |
| 12b | Photo of the race with 4 cars in each theme | Not run | | | Same result as old item 12. |
| 12c | Photo of the finish line | Not run | | | Same result as old item 12. |
| 12d | Overlay screenshot in each theme; video of the start | Not run | | | Same result as old item 12. |
| 13a | Photo of the settings view with the Theme row | Not run | | | Added 2026-10-15: the race became Road Rally (flat pixel world, 3 themes). |
| 13b | Photo of each theme with the obstacles | Not run | | | Same result as old item 13. |
| 13c | Two photos: before and after Try again | Not run | | | Same result as old item 13. |
| 13d | Photo of the cars in three themes; photo of a car going left | Not run | | | Same result as old item 13. |
| 13e | Photo of the scenery of each theme | Not run | | | Same result as old item 13. |
| 13f | Photo of the Theme row after Try again and New game | Not run | | | Same result as old item 13. |
| 13g | Photo of the title and theme names in Hebrew | Not run | | | Same result as old item 13. |
| 13h | Note: the two times in seconds | Not run | | | Same result as old item 13. |

Winning times (item 8a):

| Track | Difficulty | Winning time (s) | Run | Evidence |
|-------|------------|------------------|-----|----------|
| Track | | | | |
| Track | | | | |
| Track | | | | |
| Random track | | | | |

History:

- 2026-10-20 (not run): the steps were made measurable and split. Item 4 (feel) is removed. Items 8b and 9e are new checks (REQ-MR-8, REQ-MR-52). Item 11b changes with issue #55.
- 2026-10-09 (not run): the four hand-made tracks were replaced by generated tracks, and item 9 is new: the settings view with Difficulty and the track carousel (10 sketches and a '?', the middle one is chosen, yellow border), difficulty by the number of obstacles (Easy 2, Medium 6, Hard 10 for each 100 m). The results menu has Settings, not Choose track.
- 2026-10-10 (not run): item 12 is new: the 3D world is drawn in a 480x270 pixel view (phase 3 of the arcade style), and the cars have their slot number on them.
- -: **Not run**. Not run on a device yet. Item 11 is new: run it again after a change of the shared game code (PR 12 changed the countdown, the buzz limit and the end with no players).

## Test 10

### Banana Party (pointer)

Needs: 1 to 4 phones, 1 TV, a stopwatch, a second phone with an angle app (or a paper protractor), and a child of about 5 to 8 years for steps 9a and 9b. Covers: REQ-SS-*, REQ-GM-47i to 47n, REQ-GM-80 to 84, 90 to 95, RISKS A4, REQ-GM-37, REQ-GM-50.

Hold each phone like a remote control, pointing at the TV, from the sofa (about 3 m). This is the first game that uses the
gyroscope pointer, so this test also checks the pointer itself (the old Test 5 for drift was removed).
The game was "Target Shoot" until 2026-10-09: it was changed after the first try (see History).
Record every video at 30 frames per second or more. "Screen width" means the width of the TV picture. "Center" means the middle of the play area.

**Steps**

1a. Start **Banana Party** with 1 phone. Hold the phone toward the TV during "3, 2, 1" and press nothing. Check: a cursor ring in the player color (the color of the square on the phone) shows on the TV and follows the phone. (REQ-SS-1, 3)
1b. In "3, 2, 1", press **A** three times. Check: no banana appears and the score stays at 0. (REQ-SS-1, 4)
1c. Hold the phone still toward the TV in "3, 2, 1". Look at the first frame of the video after "GO". Check: the center of the ring is less than 5% of the screen width from the center of the play area. (REQ-SS-2)
2a. Turn the phone to the left, to the right, up and down. Check: the cursor moves to the left, to the right, up and down, the same way as the phone, in all 4 directions. (REQ-SS-3)
2b. Start from the pose of "GO". Turn the phone 25 degrees to the left (measure the angle with the second phone). Do the same to the right, up and down. Check: for each direction the cursor is at the edge of the play area, or less than 10% of the play-area width (or height) from it. Then turn 40 degrees. Check: the cursor stays inside the play area (inside the 60 px margin) in all 4 directions. (`pointer_range_deg` 25 in `orientation.gd`, REQ-SS-3)
3a. After "GO", hold the phone still for 40 seconds (stopwatch). Check: the cursor moves less than 5% of the screen width from its first place. (RISKS A4, REQ-GM-37)
3b. Move the phone away from the TV and back, then tap **RECENTER**. Check: the cursor goes to the center, less than 5% of the screen width from it. (REQ-GM-37)
4a. Press **A** with the cursor on empty ground. Check: a banana flies to the cursor and a ring (a poof) shows where it lands, the score does not change, and a second press after 1 second throws a second banana. (REQ-SS-4 to 6)
4b. Press **A** with the cursor on an animal. Check: the animal jumps once, shows closed happy eyes (^), a banana peel falls beside it, and the text "+10" or "+25" shows above it in your color. The score goes up by the same number: 25 for a monkey or a lemur, 10 for the other four animals. (REQ-SS-7, 10, 13)
4c. Hit one animal of each kind. Check: each kind has its own cheer: gorilla shakes, sloth wiggles slowly, lemur turns on the spot, elephant sprays water, orangutan has hearts, monkey has sparkles. (REQ-SS-13)
4d. Hit an animal with a phone in the hand. Check: the phone buzzes at the throw or at the hit (the tester feels a buzz: yes or no). Haptics are on in the phone Settings. (REQ-SS-14, REQ-GM-43)
4e. Press **B** five times. Check: nothing happens on the TV and on the phone. (REQ-SS-4)
5a. Play 60 seconds. Check: a second person with the list monkey, lemur, orangutan, sloth, gorilla, elephant names each animal that the tester points to on the TV, from 3 m. All six names are correct. (REQ-SS-7, 12)
5b. Take a photo of the TV during play. Check: every animal is at least 4.4% of the screen height (48 px at 1080p) high, and the ring of the cursor is visible on the green ground and has the color of your phone square. (REQ-SS-12)
5c. With a stopwatch, time a monkey in the far lane from the left edge to the right edge of the screen (Medium). Do the same for an elephant in the near lane (it walks from the other edge). Check: the monkey needs 10 to 14 seconds, the elephant needs 19 to 29 seconds. (REQ-SS-8: 160 and 80 px/s, plus or minus 20%)
5d. Play two rounds. Check: the golden monkey king comes in each round, the first one after 10 s of play (plus or minus 2 s), and the next one after 14 to 22 seconds. It shows a gold crown. (REQ-SS-25)
5e. Throw at the golden monkey king in the same two rounds. Check: you hit it at least once, and the text shows "+100" and the score goes up by 100. (REQ-SS-7, 25)
6a. Play a full round alone on Medium. Start the stopwatch at "GO". Check: the result menu opens 60 seconds (plus or minus 2 s) after GO. The clock on the TV counts down the seconds. (REQ-SS-1)
6b. Look at the result menu. Check: the medal picture next to your name matches the score: no medal under 150, bronze from 150, silver from 300, gold from 450. With no medal the title says "NO MEDAL THIS TIME (MEDIUM)". (REQ-SS-16, 21, REQ-GM-73)
6c. Use a phone name of 10 letters. Play until the score is 100 or more. Check: the chip at the top shows the full name and every digit of the score, and no letter or digit is cut. (REQ-GM-46, R2)
7a. Play with 2 to 4 phones. Check: each phone has its own ring on the TV, the ring colors are different, and each ring color equals the square color on its phone. (REQ-GM-24, 46)
7b. Two players put the cursor on the same animal and press **A** on a count of "3, 2, 1, now". Do this 5 times. Check: in every try only one of the two scores goes up and the other score does not change. (REQ-SS-11)
7c. Play a full round with 4 phones. Check: the debug overlay shows 55 frames per second or more during the whole round (60 expected). (REQ-GM-50)
8a. Play with 2 phones. Switch the Wi-Fi of one phone off during a round. Start the stopwatch at that moment. Check: the game pauses and the card says "2P LOST CONNECTION" within 6 seconds. (REQ-GM-30. Changes with issue #56: within 4 seconds.)
8b. On the card, choose "Resume without 2P". Check: the cursor and the score of that phone are gone from the TV, and the round goes on. (REQ-GM-30, REQ-SS-16)
9a. Let a child of about 5 to 8 years play 1 round, with a grown-up next to them. The grown-up reads the hint line once and says nothing more. Check: the child hits at least 1 animal within the 60 seconds, and nobody touches the phone for the child. Write down the age. (REQ-GM-80 to 84, REQ-SS-17)
9b. The child plays a second round. Check: the child plays both rounds to the end without asking to stop or crying, and answers "yes" when asked "again?" (yes or no). Write down the words of the child. (REQ-GM-80 to 84, REQ-SS-17)
10a. Open the tile of **Banana Party** with OK. Check: the settings view opens with a row Difficulty set to Medium. (REQ-GM-91, REQ-SS-20)
10b. Play one round alone on each of Easy, Medium and Hard. Time a monkey in the far lane across the screen. Check: Easy needs 14 to 20 seconds, Medium 10 to 14 seconds, Hard 6.5 to 9.5 seconds. (REQ-SS-20: factors 0.7, 1.0, 1.5 of 160 px/s, plus or minus 20%)
10c. In the same three rounds, count the animals on the screen in the video (the golden monkey does not count). Check: with 1 player, never more than 5 on Easy, 4 on Medium and 3 on Hard; the most you count is equal to that number at least once. (REQ-SS-20: 4, 3, 2 plus 1 player)
10d. In the video of the Hard round, look at the screen every 5 seconds (12 looks). Check: at least one animal is on the screen in 11 of the 12 looks. (REQ-SS-22)
10e. Look at each result menu. Check: the title is the difficulty you played in capital letters ("EASY", "MEDIUM", "HARD") and the medal picture is next to your name. A round with no medal says "NO MEDAL THIS TIME (HARD)" (with the difficulty you played). (REQ-SS-21)
11a. **Jungle look (2026-10-16, REQ-SS-12).** Zoom a photo of the TV to 300%. Check: the outline of an animal and of a ring is made of square steps with no soft edge, and the outline of an animal is black.
11b. From the sofa (about 3 m), play a round. Check: the tester reads aloud the "+10" or "+25" over a hit animal and the score of the round end, without error. (REQ-SS-13, REQ-FL-40)
11c. Take 5 photos of animals during play (some in each lane). Check: in each photo no leaf or vine covers any part of an animal, and the sky, the vines and the treetops start under the HUD bar. (REQ-SS-12)
11d. Look at an animal during its walk. Check: the animal moves up and down a little at each step (a bob) and has no moving legs. (REQ-SS-8, 12)
11e. **Bushes (REQ-SS-26).** Watch an animal that walks behind a bush. Check: while the middle of the animal is behind the bush, the animal is covered, and a banana thrown at it gives no points (a poof shows). The animal can be hit again when it comes out.
11f. Count the bushes on the ground at the start of a round. Check: Easy has 3, Medium has 5 and Hard has 8. (REQ-SS-26)

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the TV in the countdown with the ring | Not run | | | |
| 1b | Video of the countdown with 3 presses of A | Not run | | | |
| 1c | Video: the first frame after GO, with the ring in the middle | Not run | | | |
| 2a | Video of the cursor in the four directions | Not run | | | |
| 2b | Photos of the cursor at the edge for the four turns of 25 degrees, with the angle app in the photo | Not run | | | |
| 3a | Photo at the start and at 40 s; the drift in % of the screen width | Not run | | | |
| 3b | Video of RECENTER, the cursor in the middle | Not run | | | |
| 4a | Video: a miss with the poof, the score, the second banana | Not run | | | |
| 4b | Video of a hit and the score before and after | Not run | | | |
| 4c | Video of each of the six cheers | Not run | | | |
| 4d | Note: buzz felt, yes or no | Not run | | | |
| 4e | Video: B does nothing | Not run | | | |
| 5a | Photo of the animals; the six names that were given | Not run | | | |
| 5b | Photo of the TV during play with the animal height measured in % of the screen height | Not run | | | |
| 5c | Times in seconds of the monkey and of the elephant | Not run | | | |
| 5d | Times of the golden monkey in two rounds | Not run | | | |
| 5e | Video of a hit on the golden monkey with "+100" | Not run | | | |
| 6a | Time in seconds from GO to the result menu | Retest | R2 | Chat report 2026-10-09 (no file) | Split from item 6. The R2 note of item 6 is in 6c. |
| 6b | Photo of the result menu with the medal; the score | Retest | R2 | Chat report 2026-10-09 (no file) | Split from item 6. The R2 note of item 6 is in 6c. |
| 6c | Photo of the chip with a name of 10 letters and a score of 3 digits or more | Retest | R2 | Chat report 2026-10-09 (no file) | R2: while playing, 'when in the game and the score is above 3 digits, the last digit isn't visible'. The name-and-score chip at the top was a fixed 250 px wide and cut the text. Fixed on 2026-10-09 (REQ-GM-46): the chip is as wide as its content, and a long name is not cut (the chip gets wider, or goes to a second row). The rest of the round (feel, medal, tiers) was not reported. Retest, and check scores of 4 and 5 digits and a long phone name. |
| 7a | Photo of two to four rings and the phone squares | Not run | | | |
| 7b | Note: the result of each of the 5 tries | Not run | | | |
| 7c | Overlay screenshot (FPS) with 4 phones | Not run | | | |
| 8a | Video: Wi-Fi off, the stopwatch, then the card; the time in seconds | Not run | | | |
| 8b | Video: "Resume without 2P" and the TV after it | Not run | | | |
| 9a | The age of the child; short video (only with the permission of the parent) | Not run | | | |
| 9b | The words of the child; yes or no for "again?" | Not run | | | |
| 10a | Photo of the settings view | Not run | | | Added 2026-10-09 (REQ-SS-20 to 22). |
| 10b | Times in seconds of the monkey on Easy, Medium and Hard | Not run | | | Added 2026-10-09 (REQ-SS-20 to 22). |
| 10c | The most animals counted in each round | Not run | | | Added 2026-10-09 (REQ-SS-20 to 22). |
| 10d | The 12 looks of the Hard round: how many had an animal | Not run | | | Added 2026-10-09 (REQ-SS-20 to 22). |
| 10e | Photos of the three result menus | Not run | | | Added 2026-10-09 (REQ-SS-20 to 22). |
| 11a | Zoomed photo of an animal and a ring | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-16 (jungle, REQ-SS-12). |
| 11b | Note: the texts that were read aloud | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-16 (jungle, REQ-SS-12). |
| 11c | 5 photos of animals in the three lanes | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-16 (jungle, REQ-SS-12). |
| 11d | Video of a walking animal | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-16 (jungle, REQ-SS-12). |
| 11e | Video: a banana at a hidden animal, then at the same animal outside the bush | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-16 (jungle, REQ-SS-12). |
| 11f | Photos of the ground on Easy, Medium and Hard with the bush count | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-16 (jungle, REQ-SS-12). |

Measurements (not a test; no pass or fail). Write these values in the Notes column of the steps above. They decide the first tuning values of the game.

| Value | Step | Result | Run | Notes |
|-------|------|--------|-----|-------|
| Drift after 40 s still (% of the screen width) | 3a | | | |
| Times of the animals across the screen (now 160, 90 and 80 px/s at Medium) | 5c, 10b | | | |
| Score of a full round alone on Easy, Medium and Hard, and the medal (tiers [170, 340, 510], [150, 300, 450], [120, 240, 360]) | 6b, 10e | | | |
| Frame rate with 4 phones (aim 60) | 7c | | | |
| Pointer range: the half range in degrees at which the cursor reaches the edge (now 25, `pointer_range_deg`) | 2b | | | |
| The wait from the Wi-Fi off to the card in seconds (now 5, planned 3) | 8a | | | |

History:

- 2026-10-20: the steps were rewritten with a measurable Check and split with letters (1a to 11f). Each new step keeps the result of the old step with the same number. Step 8a follows the 5 s rule of REQ-GM-30 (the owner asked for 2 to 3 seconds, planned 3 s in issue #56).
- 2026-10-10 (not run): item 11 is new: the sky is a pixel world (phase 4 of the arcade style).
- 2026-10-16 (not run): Snowball Splat became **Banana Party** (first Banana Splat; "קרב" means fight in Hebrew, so the owner chose Party): bushes that hide animals (REQ-SS-26, 3, 5 or 8 by difficulty), a jungle at sunset, six animals that eat bananas in three depth lanes, a hit animation for each, plain ring pointers and the golden monkey king (100 points). Items 4, 5 and 11 changed (REQ-SS-7 to 13, 25). All values are first guesses.
- 2026-10-09 (not run): item 10 is new: the settings view and Easy, Medium and Hard for Snowball Splat (faster and fewer Puffs as it grows, medal tiers for each level, the title names the difficulty).
- R2: the owner played the new game and reported one problem: the last digit of a score above 3 digits was not visible in the chip at the top. Fixed on 2026-10-09. Nothing else was reported, so the other items stay not run.
- R1: **Fail**, then redesigned. The owner tried the first version ("Target Shoot", small fast targets, a lock after a miss, decoys) and said: "I don't think it's playable in its current definition." They asked for something like Duck Hunt with larger and slowly moving targets, no penalty for a miss, and a game that is also for kids, so not shooting but for example throwing snowballs at a made-up character. Changed on 2026-10-09: the game is now Snowball Splat (REQ-SS-*), and REQ-GM-80 to 84 are new for all games. Which steps failed was not reported. The whole test needs a run with the new game.

## Test 11

### Result menus (REQ-GM-72)

Needs: 1 to 4 phones, 1 TV, a camera for photos. Covers: REQ-GM-34, REQ-GM-40, REQ-GM-41, REQ-GM-72, REQ-GM-73, REQ-MZ-5, REQ-MR-31.

1 to 4 phones. Tests the ranked result menu (REQ-GM-72) that every game with scores uses. Here: the maze and the race. New. Added with the shared game code (PR 12).
"Screen edge" means the edge of the TV picture. The margin must be 60 px at 1080p, that is 3.1% of the screen width (REQ-GM-41). Measure it on the photo. Read from the sofa (about 3 m).

**Steps**

1a. Maze with 1 phone: finish the maze. Check: the tester reads aloud the title and the first row (name and score text) of the result menu from 3 m, without error. (The rows, the title and the buttons are checked by `docs/AUTOMATED_TESTS.md`, A-11-1.)
1b. Look at the same result menu. Check: the tester points to the avatar picture and to the square in the slot color next to the name. If a medal picture shows, the tester names its color (gold, silver or bronze) and it fits the score. (REQ-GM-72, 73. A-11-1 covers the rows.)
2a. Maze with 2 to 4 phones: let one ball reach the exit first. Take a photo of the whole TV. Check: the distance from the card, the list and the buttons to every screen edge is 3.1% of the screen width or more. (The rows and the 60 px edge are checked by A-11-2.)
2b. Look at the same result menu from 3 m. Check: the tester reads aloud the winner row and the row "NOT FINISHED" without error, and the buttons Try again and Back to menu are all visible. (A-11-2.)
3a. Road Rally with 4 phones on any track: let all cars finish. Take a photo of the whole TV. Check: the card with the list and the 3 buttons (Try again, New game, Back to menu) is 3.1% of the screen width or more from every screen edge. (The rows, the order and the 60 px edge are checked by A-11-3.)
3b. Look at the same card from 3 m. Check: the tester reads aloud the 3 button names and the names of the 4 players without error. (A-11-3.)
3c. Look at the medals of 1st, 2nd and 3rd place. Check: the tester names the colors in order gold, silver, bronze without error. (REQ-GM-73. A-11-3 covers the order.)

Items 4, 5, 6, 7 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-11-4 to A-11-7). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the result menu (1 phone) from the sofa; the text that was read | Not run | | | |
| 1b | Photo of the first row: avatar, square, medal | Not run | | | |
| 2a | Photo of the whole TV with the result menu; the margin in % of the screen width | Not run | | | |
| 2b | Photo of the result menu with 'not finished' rows; the text that was read | Not run | | | |
| 3a | Photo of the whole TV with the race results (4 rows); the margin in % of the screen width | Not run | | | |
| 3b | Photo of the race results from the sofa; the text that was read | Not run | | | |
| 3c | Photo of the 3 medals; the colors that were named | Not run | | | |

History:

- 2026-10-20: the steps were rewritten with a measurable Check and split with letters (1a to 3c).
- -: **Not run**. New.

## Test 12

### Game tiles and the toy box look (REQ-GM-49)

Needs: 1 TV (phones for the game photos), a camera for photos. Covers: REQ-GM-49, REQ-FL-20, REQ-FL-40, REQ-GM-41.

Phones are needed only for the photos of the running games. Needs the TV and the Games screen. New. This is the visual check that the `review` skill asks for with a screenshot of the game next to the Games screen.
A tile has a 16:9 picture. In steps 4 to 10, an object "is in the tile" when a tester at 3 m points to it. Today the tile shows the world of the game with its HUD (score, title). (Changes with issue #57: the tile shows only the world of the game, with no HUD, title bar, leader chip, name tag, score, time, hint or menu text. Then a tile with any of these texts fails.)

**Steps**

1a. Open the Games screen. Check: the 9 games are in 3 rows of 3. (REQ-FL-12)
1b. With the remote, move the focus down to the last row. Check: the grid scrolls and every tile of the last row shows fully. (REQ-FL-12)
1c. Look at every tile. Check: each of the 9 tiles has a screenshot, a title and a player range (for example "1-4 PLAYERS"). (REQ-FL-13)
1d. Move the focus over 3 tiles. Check: the bar under the grid shows the description of the focused game, and the text changes when the focus moves. (REQ-FL-13)
1e. From the sofa (about 3 m), look at the Games screen. Check: the tester reads aloud the title and the player range of 3 tiles and the description of the focused game, without error. (REQ-FL-40)
2. For each game, compare its tile with a photo of the game running. Check: the tile has the same background color and the same main objects as the photo (the objects are listed in steps 3a to 10). (Changes with issue #57.)
3a. Check the tile of **Treasure Maze** (made again on 2026-10-09): 4 balls on the way to the exit in the pixel Garden look. Check: the tile has 4 balls, the exit and the garden floor. (Changes with issue #57.)
3b. Check the tile of **Road Rally** (made again on 2026-10-09): 4 cars on a bend before a post (Track 1, Hard). Check: the tile has 4 cars, the bend and the post. (Changes with issue #57.)
4. Check the tile of **Banana Party** (made again on 2026-10-16). Check: the tile has the jungle, the animals, four cursor rings, an animal that was just hit ("+10") and a banana in the air. (Changes with issue #57: no score and no "+10" text.)
5. Check the tile of **Paint Grab** (made again on 2026-10-16). Check: the tile has the floor with the hidden picture, a bonus pot and four blobs. (Changes with issue #57.)
6. Check the tile of **Sumo Bumpers**. Check: the tile has the island, its edge and the penguins. (Changes with issue #57.)
7. Check the tile of **Galaxy Protector** (new on 2026-10-16). Check: the tile has the night sky, the ships, asteroids of three sizes and a beam. (Changes with issue #57.)
8. Check the tile of **Pin Pals** (new on 2026-10-16). Check: the tile has the lane, the pins and the ball about to hit them. (Changes with issue #57.)
9. Check the tile of **Tennis** (new on 2026-10-17). Check: the tile has the court, the players and the ball high over the near half. (Changes with issue #57.)
10. Check the tile of **Mini Golf** (new on 2026-10-17). Check: the tile has a hole with the windmill and the lake, and a ball on its way. (Changes with issue #57.)

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the Games screen with 9 tiles | Not run | | | |
| 1b | Photo of the Games screen after the scroll | Not run | | | |
| 1c | Photo of the Games screen; the number of tiles with all 3 parts | Not run | | | |
| 1d | Two photos with different focus and the bar text | Not run | | | |
| 1e | Photo from the sofa; the texts that were read | Not run | | | |
| 2 | Photos: tile next to the game, for each game | Not run | | | |
| 3a | Photo of the Treasure Maze tile and of the running game | Not run | | | Road Rally and Maze tiles remade 2026-10-09 (4 cars on a bend with posts; 4 balls on the way to the exit). |
| 3b | Photo of the Road Rally tile and of the running game | Not run | | | Road Rally and Maze tiles remade 2026-10-09 (4 cars on a bend with posts; 4 balls on the way to the exit). |
| 4 | Photo of the tile and of the running game | Not run | | | Banana Party tile remade 2026-10-16 (a jungle, 4 players, a hit, a banana in the air). |
| 5 | Photo of the tile and of the running game | Not run | | | Paint Grab tile remade 2026-10-16. |
| 6 | Photo of the tile and of the running game | Not run | | | Sumo Bumpers tile. |
| 7 | Photo of the tile and of the running game | Not run | | | Galaxy Protector tile, new 2026-10-16. |
| 8 | Photo of the Pin Pals tile next to a photo of the game | Not run | | | |
| 9 | Photo of the Tennis tile next to a photo of the game | Not run | | | |
| 10 | Photo of the Mini Golf tile next to a photo of the game | Not run | | | |

History:

- 2026-10-20: the steps were rewritten with a measurable Check (list of objects in the tile, text read aloud from 3 m) and step 1 and step 3 were split with letters. The sentence "the Games screen and the games look like one toy box" was removed: it has no measure. The owner's run R1 is kept in the result database (step 1 passed, steps 2 to 10 failed because the tiles show the wrapper; planned: issue #57, REQ-GM-49).
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
6a. On an iPhone with a Dynamic Island or a notch, open Connect (with the player dropdown), the PIN pad and About, upright. Take a photo of each. Check: in each photo the complete outline of every text and button is visible, and none is under the island, the notch, the status bar or the home bar. (REQ-FL-68)
6b. Open the player list, the player edit screen with the keyboard open, and Settings, upright. Take a photo of each. Check: the same as 6a. (REQ-FL-68)
6c. Open the waiting screen and the pad in a game, upright. Check: the colored square, the player number, DISCONNECT, and the A and B buttons are fully visible in the photo. (REQ-FL-68)
6d. Turn the phone to the side and open the screens of 6a to 6c again. Check: the same as 6a for every screen. (REQ-FL-68)

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
| 6a | Photos of the three screens under the island, upright | Not run | | | |
| 6b | Photos of the three screens, upright | Not run | | | |
| 6c | Photos of the waiting screen and the pad, upright | Not run | | | |
| 6d | Photos of the screens turned to the side | Not run | | | |

History:

- 2026-10-20: the steps were rewritten with a measurable Check and split with letters (1a to 6d). Steps 2a to 2e, 5b and 5c change with issue #52 (no PIN, no list, no Refresh).
- -: **Not run**. New.

## Test 14

### Paint Grab (tilt)

Needs: 1 to 4 phones, 1 TV, a stopwatch, and a child of about 5 to 8 years for step 7. Covers: REQ-PG-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Hold each phone flat like a tray. New game (2026-10-09). The blob feel (`TiltBody`: acceleration, damping, speed limit, bounce) and the
difficulty values are first guesses. "Full tilt" means the phone is tilted about 45 degrees. Record videos at 30 frames per second or more.

**Steps**

3a. Tilt the phone to the left, to the right, up and down (the top of the phone up, then down). Check: the blob rolls to the lowered side in all 4 directions. (REQ-PG-7)
3b. Tilt the phone to full tilt for 2 seconds, then hold it flat. Start the stopwatch when the phone is flat. Check: the blob stops (it moves less than 20 px per second) within 4 seconds. (REQ-PG-7: damping 1.4 1/s)
3c. Roll the blob at full tilt against each of the 4 edges of the floor, 10 seconds in total. Check: the blob turns back from each edge, and the middle of the blob never goes outside the floor. (REQ-PG-7)
4a. Roll over 5 free tiles. Check: each of the 5 tiles takes the color of your blob, and the tile count on your phone goes up by 5. (REQ-PG-4, 13)
4b. With 2 phones, roll over a tile of the other player. Check: the tile changes to your color, the count of the other player goes down by 1, and your phone buzzes (yes or no). (REQ-PG-4, 12)
5a. Play a full round of 60 seconds alone on Easy, then on Medium, then on Hard. Count the tiles of the floor on the TV. Check: the floor is 12 x 7 tiles on Easy, 16 x 9 on Medium and 20 x 11 on Hard. (REQ-PG-20)
5b. On each difficulty, roll the blob from the left edge to the right edge of the floor at full tilt. Film it and count the frames. Do this 3 times and take the middle value. Check: the time on Easy is longer than the time on Medium, and the time on Medium is longer than the time on Hard. (REQ-PG-20: speed 0.8, 1.0, 1.25)
5c. Look at each result menu. Check: the title is the difficulty ("EASY", "MEDIUM", "HARD") and the medal picture is next to your name. The medal matches the percent of the floor you painted (rounded down) with the tiers [Easy 35, 55, 75; Medium 30, 50, 70; Hard 25, 40, 55]. With no medal the title is "NO MEDAL THIS TIME (HARD)" (with the difficulty you played). (REQ-PG-21, REQ-GM-73)
6a. Play with 2 to 4 phones. Roll two blobs into each other. Check: both blobs turn away from each other and do not go through each other. (REQ-PG-8)
6b. Play a full round with 2 to 4 phones. Check: the leader chip names the player with the most tiles, and at the end the title names the same player ("X wins!"). (REQ-PG-13, 5. The title "Tie!" is checked by A-11-7.)
6c. Leave the game on one phone during a round (Disconnect). Check: its blob goes, its tiles stay on the floor, and the round goes on until 60 seconds. (REQ-PG-10)
7a. Let a child of about 5 to 8 years play 1 round, with a grown-up next to them. The grown-up reads the hint line once and says nothing more. Check: the child paints at least 10 tiles in the first 30 seconds, and nobody touches the phone for the child. Write down the age. (REQ-PG-9, REQ-GM-80 to 84)
7b. The child plays a second round. Check: the child plays both rounds to the end without asking to stop or crying, also when a tile is painted over, and answers "yes" when asked "again?" (yes or no). (REQ-PG-9, REQ-GM-80 to 84)
8. Play a full round with 4 phones on Hard. Check: the debug overlay shows 55 frames per second or more during the whole round (60 expected). (REQ-GM-50)
10a. **Pixel world (phase 4, REQ-PG-15).** Zoom a photo of the floor on Easy, Medium and Hard to 300%. Check: the tiles are squares with sharp edges, and in each photo the gap between two tiles has the same width everywhere (compare 5 gaps; the difference is 1 photo pixel or less).
10b. Look at the floor with 4 blobs from the sofa (about 3 m). Check: a second person names the color of each blob correctly (4 of 4), and each blob has a black outline and no number. (REQ-PG-8, 15, REQ-GM-46)
10c. Film a tile that is just painted at 30 frames per second. Check: at least 3 frames show the tile wider than its neighbours by one world pixel (4 px at 1080p) on each side. (REQ-PG-16)
11a. **Pictures (2026-10-16, REQ-PG-22).** Play 5 rounds in a row. After 10 seconds of each round (the floor is still mostly empty), take a photo. Check: a second person who has the list of the 30 names (`SHAPES` in `paint_picture.gd`) names the picture correctly in at least 4 of the 5 rounds, and the 5 pictures are not all the same.
11b. At the end of the same rounds (the floor is full), take a photo. Check: the same second person names the same picture in at least 4 of the 5 rounds. (REQ-PG-22)
11c. **Pots (REQ-PG-23).** Play 2 rounds and note the time of each pot from the video. Check: the first pot lands at 8 seconds (plus or minus 1 s) of play and the next ones 9 to 15 seconds after the one before. One pot at a time is on the floor.
11d. Look at a pot on the floor. Check: a frame shows the tiles it will paint: a 3 x 3 patch for the gold pot, or the whole row for the rainbow roller. (REQ-PG-23)
11e. Roll over a pot with your blob. Check: the whole patch (or row) takes your color, also the tiles of other players, and the phone buzzes (yes or no). (REQ-PG-23)
11f. Do not take a pot. Check: the pot blinks in its last 2 seconds and is gone 9 seconds (plus or minus 1 s) after it landed. (REQ-PG-23)
11g. Let the child of step 7 play 2 rounds with pots, without a hint about pots. Check: the child rolls over at least 1 pot within 10 seconds after it landed, and no picture makes the child upset (the child does not cover the eyes, cry or ask to stop). (REQ-PG-9, 22, 23)

Items 1, 2, 9 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-14-1, A-14-2, A-14-9). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 3a | Short video of the blob in 4 directions | Not run | | | |
| 3b | Video of the stop; the time in seconds | Not run | | | |
| 3c | Video of the blob at the 4 edges | Not run | | | |
| 4a | Video: painting 5 free tiles; the tile count on the phone before and after | Not run | | | |
| 4b | Video: taking a tile; the counts of both players | Not run | | | |
| 5a | Photos of the floor on each difficulty; the tile counts | Not run | | | |
| 5b | The frame counts of 3 crossings for each difficulty | Not run | | | |
| 5c | Photos of the three result menus; the percent and the medal | Not run | | | |
| 6a | Video or photo of 2 blobs that bounce | Not run | | | |
| 6b | Photo of the leader chip and of the result title with 2 to 4 phones | Not run | | | |
| 6c | Video: a phone leaves, the tiles stay | Not run | | | |
| 7a | The age of the child; the number of tiles painted in 30 s | Not run | | | |
| 7b | The words of the child; yes or no for "again?" | Not run | | | |
| 8 | Overlay screenshot (FPS) with 4 phones on Hard | Not run | | | |
| 10a | Zoomed photos of the floor on three difficulties | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-15 (Treasure Maze). |
| 10b | Photo of 4 blobs; the colors that were named | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-15 (Treasure Maze). |
| 10c | Video of a painted tile, frame by frame | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-15 (Treasure Maze). |
| 11a | Photos at 10 s of 5 rounds; the names that were given | Not run | | | Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |
| 11b | Photos at the end of 5 rounds; the names that were given | Not run | | | Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |
| 11c | The times of the pots in 2 rounds | Not run | | | Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |
| 11d | Photo of a gold pot and of a rainbow roller with the frame | Not run | | | Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |
| 11e | Video of a pot taken | Not run | | | Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |
| 11f | Video of a pot that blinks and goes away; the time | Not run | | | Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |
| 11g | Note: the child, the time to the first pot, what happened | Not run | | | Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |

Measurements (not a test; no pass or fail). Write these values in the Notes column of the steps above. They decide the first tuning values of the game.

| Value | Step | Result | Run | Notes |
|-------|------|--------|-----|-------|
| Percent of the floor painted in a full round alone on Easy, Medium and Hard, and the medal | 5c | | | |
| Which pictures were not recognized, and if one picture came twice in a row | 11a | | | |
| Frame rate with 4 phones on Hard (aim 60) | 8 | | | |

History:

- 2026-10-20: the steps were rewritten with a measurable Check and split with letters. The words "the blob and its number" of step 10 were removed: a blob has no number (REQ-GM-46). Each new step keeps the result of the old step with the same number.
- 2026-10-16 (not run): item 11 is new: a hidden picture under the floor (30 shapes, a new one each round) and bonus pots (gold 3 x 3, rainbow roller), REQ-PG-22 and 23.
- 2026-10-10 (not run): item 10 is new: the floor is a pixel world (phase 4 of the arcade style).
- -: **Not run**. New.

## Test 15

### Sumo Bumpers (tilt and A)

Needs: 2 to 4 phones, 1 TV, a stopwatch, and a child of about 5 to 8 years for step 8. Covers: REQ-SB-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Hold each phone flat like a tray. New game (2026-10-09). The movement (`TiltBody`), the bounce, the dash and the difficulty values are first guesses. "Full tilt" means the phone is tilted about 45 degrees. Record videos at 30 frames per second or more.

**Steps**

1a. With 1 phone, open the tile of **Sumo Bumpers**. Check: the tile is dimmed and says "Needs 2 players", and OK on it opens no settings view. (REQ-FL-14)
1b. With 2 phones, press OK on the tile. Check: the settings view opens with Difficulty on Medium. Start the game. (REQ-FL-17, REQ-GM-91)
3a. Tilt the phone to the left, to the right, up and down. Check: the bumper rolls to the lowered side in all 4 directions. (REQ-SB-7)
3b. Tilt to full tilt for 2 seconds, then hold the phone flat. Start the stopwatch when the phone is flat. Check: the bumper stops (it moves less than 20 px per second) within 4 seconds. (REQ-SB-7: damping 1.4 1/s)
3c. Take a photo at GO and a photo 21 seconds after GO (Medium), with nobody falling. Check: the platform is smaller in the second photo, and the edge ring is brown at GO and red at 21 seconds. (REQ-SB-6, 15)
4a. Roll a bumper into another one at full tilt. Check: both bumpers bounce away from each other, and no bumper or text shows damage. (REQ-SB-8)
4b. Roll a bumper into another one at a speed of about 100 px per second (a slow touch), then at full tilt (a fast hit). Check: both phones buzz at the fast hit and neither phone buzzes at the slow touch (felt by the testers: yes or no). (REQ-SB-8: more than 300 px/s)
5a. Press **A** with a tilt. Check: the bumper moves fast in the tilt direction for about 0.35 seconds, and **B** does nothing. (REQ-SB-10)
5b. Press **A** and start the stopwatch. Check: the ring around the bumper shows that the dash is ready again after 2.0 seconds (plus or minus 0.5 s) on Medium (1.5 s on Easy, 2.5 s on Hard). (REQ-SB-10, 20)
6a. Roll over the edge. Check: the bumper spins and gets small in about 1 second and the word "WHEE!" shows above it, and the round goes on. (REQ-SB-15)
6b. Check the phone that fell. Check: the phone buzzes at the fall (yes or no). (REQ-SB-11)
6c. When one bumper is left, start the stopwatch. Check: a banner names the winner of the round, and the next round starts 2.5 seconds (plus or minus 0.5 s) later with all bumpers back (the number of bumpers equals the number of phones). If two bumpers fall in the same moment, the banner says "ROUND DRAW!". (REQ-SB-3, 4)
7a. Play all 3 rounds with 2 phones, then with 3 phones, then with 4 phones. Check: the title says Round 1, Round 2 and Round 3, and the bar says Round x of 3 with the same x. (REQ-SB-1)
7b. Play one round on each difficulty with 2 phones. Both players stay in the middle and nobody dashes. Start the stopwatch at GO. Check: the round ends at 30 seconds on Easy (27 to 33), 24 seconds on Medium (21.6 to 26.4) and 18 seconds on Hard (16.2 to 19.8). (REQ-SB-6, 20)
7c. In a round on each difficulty, make one bumper fall in the first 3 seconds. Start the stopwatch at the fall. Check: the banner shows at most 16 seconds (Easy), 13 seconds (Medium) or 10 seconds (Hard) after the fall. (REQ-SB-6, 9: 15, 12 and 9 s, plus 1 s)
7d. After each round, look at the leader chip and at each phone. Check: the round winner has 1 more point on the chip and on its phone, and each phone shows its own place. (REQ-SB-14)
7e. After round 3, look at the result menu. Check: the title names the player with the most points ("X wins!"), and each row shows "N points" with the right number. (REQ-SB-5. The title "Tie!" is checked by A-11-7.)
8a. Let a child of about 5 to 8 years play 1 match, with a grown-up next to them. The grown-up reads the hint line once and says nothing more. Check: the child makes the bumper move in the first 10 seconds, and nobody touches the phone for the child. Write down the age. (REQ-SB-9, REQ-GM-80 to 84)
8b. Check the child during the match. Check: the child plays all 3 rounds to the end without asking to stop or crying, also after a fall, and answers "yes" when asked "again?" (yes or no). (REQ-SB-9, REQ-GM-80 to 84)
10. Play a full round with 4 phones on Hard. Check: the debug overlay shows 55 frames per second or more during the whole round (60 expected). (REQ-GM-50)
11a. **Pixel world and Sky Island (REQ-GM-47i to 47n, REQ-SB-15).** Zoom a photo of the TV to 300%. Check: the island, the clouds and the penguins have square steps with no soft edge, and each penguin has a black outline.
11b. From the sofa (about 3 m), look at 4 penguins. Check: a second person names the body color of each penguin correctly (4 of 4), and every penguin is at least 4.4% of the screen height high (48 px at 1080p) in the photo. (REQ-SB-15, REQ-GM-47e)
11c. Take two photos 10 seconds apart. Check: a cloud moved to the right by 4% to 6.5% of the screen width. (REQ-SB-15: 2 to 3 world pixels per second)
11d. From 3 m, read the word "WHEE!", the round banner and the countdown digits. Check: the tester reads all three aloud without error. (REQ-SB-15, REQ-FL-40)

Items 2, 9 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-15-2, A-15-9). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the dimmed tile with the text | Not run | | | |
| 1b | Photo of the settings view | Not run | | | |
| 3a | Short video of the bumper in 4 directions | Not run | | | |
| 3b | Video of the stop; the time in seconds | Not run | | | |
| 3c | Two photos (GO and 21 s) with the red ring | Not run | | | |
| 4a | Video of a bump | Not run | | | |
| 4b | Note: buzz of both phones, slow touch and fast hit | Not run | | | |
| 5a | Video of a dash | Not run | | | |
| 5b | The time in seconds from the dash to the ready ring | Not run | | | |
| 6a | Video of a fall | Not run | | | |
| 6b | Note: buzz felt, yes or no | Not run | | | |
| 6c | Video of the banner and the next round; the time in seconds | Not run | | | |
| 7a | Photos of the title and the bar of each round | Not run | | | |
| 7b | Length of a round for each difficulty in seconds | Not run | | | |
| 7c | The wait after a fall for each difficulty in seconds | Not run | | | |
| 7d | Photos of the chip and the phones after each round | Not run | | | |
| 7e | Photo of the result menu | Not run | | | |
| 8a | The age of the child; what the child did in 10 s | Not run | | | |
| 8b | The words of the child; yes or no for "again?" | Not run | | | |
| 10 | Overlay screenshot (FPS) with 4 phones on Hard | Not run | | | |
| 11a | Zoomed photo of the screen | Not run | | | |
| 11b | Photo of the screen from the sofa; the colors that were named; the penguin height in % | Not run | | | |
| 11c | Two photos 10 s apart; the cloud move in % | Not run | | | |
| 11d | Note: the texts that were read; the TV (1080p or 4K) | Not run | | | |

Measurements (not a test; no pass or fail). Write these values in the Notes column of the steps above. They decide the first tuning values of the game.

| Value | Step | Result | Run | Notes |
|-------|------|--------|-----|-------|
| Length of a round on Easy, Medium and Hard (now 30, 24, 18 s) | 7b | | | |
| Wait after a fall (at most 15, 12, 9 s) | 7c | | | |
| Dash speed (now `DASH_SPEED` 700 px/s) and dash time | 5a | | | |
| The TV (1080p or 4K) | 11d | | | |

History:

- 2026-10-20: the steps were rewritten with a measurable Check and split with letters. Each new step keeps the result of the old step with the same number.
- -: **Not run**. New. Item 11 was added on 2026-10-10 (phase 2 of the arcade style) and changed on 2026-10-15 for the Sky Island and the penguins.
## Test 16

### The arcade look (REQ-FL-37 to 46, FD-18)

Needs: 1 to 4 phones, 1 TV on 1080p (and a 4K TV if you have one), a child of 5 to 8 years for items 8a and 8b, a tape measure or a marked distance of 3 m, a stopwatch, a phone camera. Covers: REQ-FL-37 to 46, 41a, 52, 53, REQ-GM-45, 46. New, written on 2026-10-10 for phase 1 of `docs/ARCADE_STYLE_PLAN.md`. The games are in the pixel style too (phases 2 to 4 are built); this test checks the menus, the phone and the game shell (HUD, countdown, menus, hints).

**Steps**

1a. Sit 3 m from the TV. Go through the logo, Connect, Games, Settings, About, a game settings view, the Players modal, the quit question, a pause menu and a result menu. Check: on every screen all letters are upper case, and every text is white, gray or yellow on a black background (red or green only for a destructive item with the focus, and for OK or BAD words).
1b. On the same screens, read aloud the smallest text of the screen (the hint, a slot row or a description) from 3 m. Check: you read each one without a mistake. The smallest text is 32 px (REQ-FL-40).
2a. On a 1080p TV, take a close photo from 1 m of the word SABABI and of one menu item. Zoom the photo to 400%. Check: the edges of the letters are square steps. There is no soft gray edge between a letter and the black background.
2b. Do step 2a on a 4K TV, if you have one. Check: the same result. (Skip this step if you have no 4K TV and write "no 4K TV" in the notes.)
3a. Open the Games screen with 1 phone, then with 2 and with 4 phones. Check: each row has 3 tiles, with every number of phones.
3b. Move the focus to 3 different tiles. Check: the focused tile has a yellow frame and the cursor, and no other tile has them. The bar under the grid shows the description of the focused game and changes with the focus.
3c. Focus the tile "GALAXY PROTECTOR" (the longest title). Check: the full title shows under its tile, with the cursor, and no letter is cut or outside the screen edge.
3d. With the 9 tiles (3 rows), press Down and Right until the focus is on the last tile, then go back to the first. Check: after each press the whole focused tile is inside the screen.
3e. With 1 phone, focus a game that needs more phones (for example Sumo Bumpers). Check: the reason shows in yellow text, and OK on the tile plays the sound of a dim item and does not start the game.
4a. In each menu of step 1a that has items, check the cursor. Check: the cursor is in front of the focused item only, and it moves by one item for each press of Up or Down.
4b. Focus END GAME, QUIT and REMOVE (where they exist). Check: the text is red when the item has the focus and white when it has not.
4c. Focus BACK. Check: BACK is gray when it has no focus and yellow with the cursor when it has the focus.
4d. In each menu, press OK, Back and the D-pad once each. Check: OK does the action of the focused item, Back closes the menu or goes up one step, and the D-pad moves the focus (the same result as in Test 8).
5a. Record a 10 s video of a screen with the blinking prompt PRESS OK TO CONTINUE (or PRESS OK TO SKIP). Check: the prompt is on 9 or 10 times in the 10 s (0.55 s on, 0.55 s off, REQ-FL-42).
5b. Record a video of the logo screen. Check: the logo drops from the top and stops (frame by frame, it moves in jumps with no blur), and the confetti pieces are squares.
5c. Record a video of a countdown. Check: the number shows in steps of size (the video shows 4 different sizes, from the largest to the smallest, and each size stays for more than 1 frame).
5d. Open the overlay (FPS) and record the logo, a blinking prompt and a countdown. Check: the FPS value is 55 or more in the whole video (REQ-FL-44: 60 fps).
6a. On a phone, go through the Connect, the waiting and the pad screens. Hold the phone at 50 cm and read aloud every text of each screen. Check: you read each text without a mistake.
6b. On the pad, take a photo of A with a finger on it and a photo without. Check: A is green and B is red, both are round with a ring, and the face of the button is lower in the photo with the finger.
6c. Tap RECENTER. Check: RECENTER is a yellow framed box, and it fills with yellow for a moment when tapped (video).
6d. Tap DISCONNECT once. Check: it is at the top right and the phone leaves the TV with this one tap (no question).
6e. Join a TV. Check: the slot color square with the slot number is at the top of the pad.
7a. Play every game of the Games screen with 4 phones that have names of 10 letters (the most a name can have; give two phones the same name to get 12 characters on the TV). Take a photo of the HUD of each game during play. Check: in every game the leader chip (name and score), the timer and the title are on one row.
7b. In the same photos, check: no HUD text covers another HUD text or the play area, and the whole name and the whole score in the chip show. Write down the game and the place of each problem. Test 19 covers the leader chip and the phone score in detail.
8a. A child of 5 to 8 years sits at the TV with the Games screen open. Ask: "Which game is chosen now?". Check: the child points to the focused tile (the one with the cursor) within 10 s and without help.
8b. Show the child the screen with PRESS OK TO CONTINUE. Ask the child to continue. Check: the child presses OK within 10 s and without help.

Measurements: write down the lowest FPS value of step 5d and the text sizes you saw in step 1b. Do not turn them into a pass or fail.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of each TV screen of the list | Not run | | | |
| 1b | List of the screens and the smallest text read without a mistake (yes or no) | Not run | | | |
| 2a | Close photo of SABABI and a menu item on 1080p, zoomed to 400% | Not run | | | |
| 2b | Close photo of SABABI and a menu item on 4K (or "no 4K TV") | Not run | | | |
| 3a | Photo of the Games screen with 1, 2 and 4 phones | Not run | | | |
| 3b | Photo of the Games screen with 3 focus positions | Not run | | | |
| 3c | Photo of the GALAXY PROTECTOR tile with the focus | Not run | | | |
| 3d | Photo of the first and the last tile with the focus | Not run | | | |
| 3e | Photo of the yellow reason text; note on the sound | Not run | | | |
| 4a | Photos of a menu with the cursor | Not run | | | |
| 4b | Photos of a red item with the focus and without | Not run | | | |
| 4c | Photos of BACK with and without the focus | Not run | | | |
| 4d | Note: OK, Back and D-pad on each menu | Not run | | | |
| 5a | 10 s video of a blinking prompt; the count of on phases | Not run | | | |
| 5b | Video of the logo and the confetti | Not run | | | |
| 5c | Video of a countdown | Not run | | | |
| 5d | Video with the overlay FPS; the lowest FPS value | Not run | | | |
| 6a | Photos of the phone screens; the note "read without a mistake" | Not run | | | |
| 6b | Photos of the pad with and without a finger on A | Not run | | | |
| 6c | Video of the tap on RECENTER | Not run | | | |
| 6d | Photo of the top right of the pad; note: one tap leaves | Not run | | | |
| 6e | Photo of the top of the pad | Not run | | | |
| 7a | Photos of the HUD of each game with 4 long names (one row) | Not run | | | |
| 7b | Same photos; list of games with a problem | Not run | | | |
| 8a | Note: the child, the age, the seconds | Not run | | | |
| 8b | Note: the child, the age, the seconds | Not run | | | |

History:

- -: **Not run**. New.

## Test 17

### Hebrew and right to left (REQ-FL-54, 60 to 63, REQ-GM-47o, FD-19)

Needs: 2 phones (one with the system language Hebrew, one English), 1 TV (run it with the TV set to Hebrew, region Israel, and again set to English), a person who reads Hebrew, a stopwatch. Covers: REQ-FL-54, 60 to 63, REQ-GM-47o. New, written on 2026-10-10 for phase 5 of `docs/ARCADE_STYLE_PLAN.md`. The headless test `tests/smoke_lang.gd` checks the table, the layout positions and the protocol; it cannot check how the text looks on a TV.

**Steps**

1a. Delete the app data of the TV app (or install fresh) and start it with the TV set to Hebrew. Check: the logo screen shows "ENGLISH" and "עברית" side by side, ENGLISH at the left, the focus is on "עברית", and after 30 s the screen has not moved on by itself.
1b. Press OK. Check: the app is in Hebrew and the Connect screen opens.
1c. Close the app and start it again. Check: no language choice shows, the logo goes on to the Connect screen by itself within 5 s, and the language is still Hebrew.
1d. Delete the app data again and start the app with the TV set to English. Check: the focus starts on "ENGLISH".
2a. In Hebrew, go through the logo, Connect, Games, Settings, About, a settings view, the Players modal, the quit question, the Connect screen with the PIN. Check: on every screen the title is at the right, and the cursor is at the right and points left.
2b. On the Connect screen in Hebrew, check: the QR card is at the right of the slots, and the slot squares are at the right of each slot row.
2c. On the same screens, check: no text is cut (the first and the last letter of every line show, and no text goes over the screen edge).
2d. On the same screens, check: no English word is left, except SABABI, WI-FI, QR, OK, PIN, the room code and the player names.
2e. The person who reads Hebrew reads each screen aloud. Check: the punctuation (`. , ! ? -`) is at the correct end of every sentence. Write down every text that is wrong.
3a. In Hebrew, open Settings and focus the Difficulty row (a choice row). Press Right once. Check: the value goes to the previous value (the arrow at the right).
3b. Press Left once. Check: the value goes to the next value.
3c. Press Up and Down on the remote. Check: the focus moves between rows by position, one row for each press (the same as in English).
4a. Join 2 phones: one with the system language Hebrew, one English, with a profile with a Latin name on one and a profile with a Hebrew name on the other (Test 20). Before the join, check: the Hebrew phone shows its Connect screen in Hebrew and the English phone in English.
4b. After the join, check: both phones show their screens in Hebrew (the language of the TV).
4c. On the TV, check: each player name shows as typed. A reader reads the Latin name and the Hebrew name aloud, and each one equals what was typed (the letters are in the same order).
6a. Start every game in Hebrew with 2 phones. Check: the title is at the top right.
6b. In the same games, check: the leader chip is at the left margin (Pin Pals has no leader chip), and the timer is at the left of the title.
6c. In the same games, check: the hint and the countdown word "קדימה" show complete.
6d. In the same games, check: the world is not mirrored (the maze start is at the top left, the track runs as in English).
6e. Open the pause menu and the result menu. Check: the ranking list, the medal text and "תיקו!" show complete, and the Hebrew reader says that the text reads right.
7a. Phone in Hebrew, on the pad screen. Check: the words RECENTER, DISCONNECT and the hint are in Hebrew.
7b. On the same phone, check: A and B are in the same places as on the English phone (take a photo of both pads side by side).
8a. Set the TV to English and start the app again with the same phones. Check: the QR card is at the left of the Connect screen, the cursor is at the left of the item and the Settings row Language shows "ENGLISH".
8b. Check: the 2 phones show their screens in English after they join, and the HUD of one game is the same as in Test 16 step 7a.

Item 5 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-17-5). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the choice; note: the seconds with no change | Not run | | | |
| 1b | Photo of the Connect screen in Hebrew | Not run | | | |
| 1c | Video of the second start; the seconds | Not run | | | |
| 1d | Photo of the choice with the English TV | Not run | | | |
| 2a | Photos of each TV screen in Hebrew | Not run | | | |
| 2b | Photo of the Connect screen in Hebrew | Not run | | | |
| 2c | Photos of each TV screen; a list of cut text | Not run | | | |
| 2d | A list of English words left | Not run | | | |
| 2e | A list of the sentences with wrong punctuation | Not run | | | |
| 3a | Video of a choice row with Right | Not run | | | |
| 3b | Video of a choice row with Left | Not run | | | |
| 3c | Video of Up and Down | Not run | | | |
| 4a | Photos of both phones before the join | Not run | | | |
| 4b | Photos of both phones after the join | Not run | | | |
| 4c | Photo of the Connect screen with the names; note from the Hebrew reader | Not run | | | |
| 6a | Photos of the HUD of each game in Hebrew | Not run | | | |
| 6b | Same photos | Not run | | | |
| 6c | Same photos and the countdown | Not run | | | |
| 6d | Photos of the maze and of a track | Not run | | | |
| 6e | Photos of the pause and result menus | Not run | | | |
| 7a | Photo of the Hebrew phone pad | Not run | | | |
| 7b | Photo of the two pads side by side | Not run | | | |
| 8a | Photos of the English TV | Not run | | | |
| 8b | Photos of the phones and of the HUD | Not run | | | |

History:

- -: **Not run**. New.

## Test 18

### Sound and haptics

Needs: 1 to 4 phones, 1 TV, a grown-up, a child of about 5 to 8 years for item 9, a stopwatch, a phone with a sound level meter app (dB(A)), a camera at 60 fps or more for item 11. Covers: REQ-FL-64 to 66, REQ-GM-49a to 49c, REQ-GM-43.

New (2026-10-10). The songs, the effects and the levels are first guesses (`scripts/audio/songs.gd`). The headless tests check the data, not how it sounds. Put the phone with the meter app at the sofa seat and keep the TV volume the same for the whole test. A meter reading is the highest value in 5 s.

**Steps**

1a. Start the TV app and start the stopwatch when the logo shows. Check: the menu song starts within 5 s, without a click from you.
1b. Check: you hear no click or pop when the song starts.
1c. Go from the logo to Connect, Games and Settings. Check: the song does not start again from its first note on any screen change.
2a. Move the cursor with the remote 5 times. Check: you hear 5 short blips, one for each press.
2b. Press OK on an item. Check: you hear a two-note rising sound.
2c. Press Back. Check: you hear a two-note falling sound.
2d. Join a phone and then leave with it. Check: a rising run of 3 notes on the join, a falling run of 3 notes on the leave.
2e. Press OK on a dimmed tile (Sumo Bumpers with 1 phone). Check: you hear one low short sound, and the game does not start.
3a. Open Settings. Check: the rows Music, Effects and Mute show. (Changes with issue #49: the Mute row goes away, Music or Effects at 0 covers it.)
3b. Focus Music. Press Left until the value is 0, then press Right 10 times. Check: the value goes up by 1 for each press, from 0 to 10; at 0 you hear no music; the meter reading at 2 is lower than at 5, and the reading at 5 is lower than at 10.
3c. Focus Effects and change the value by one with Left and Right. Check: a sample plays at each change.
3d. Set Mute to ON (before issue #49). Check: you hear no music and no effect. Set it to OFF: both come back.
3e. Set Music to 4 and Effects to 6. Leave the app and start it again. Check: Settings shows Music 4 and Effects 6.
4a. Change the volume of the TV. Check: the TV sound changes, and the phone is silent.
4b. Set the media volume of the phone to the maximum, with silent mode off, and play one game for 1 minute. Check: the phone makes no sound at all.
5a. Start each of the 9 games of the Games screen. Check: in each game you hear 2 beeps at 2 and 1, and one higher and longer beep at GO (3 beeps).
5b. In each game, start the stopwatch at GO. Check: the game song starts within 1 s. Write down the seconds.
5c. Let the song of one game play through 2 loops. Check: you hear no click at the loop point.
5d. Play each game once. Check: no two games have the same song, and no game plays the menu song.
5e. In a timed game, listen to the last 5 seconds. Check: you hear 5 soft ticks, one in each second.
6a. In each game, make each event of the *Sound and haptics* table of its game file (`docs/games/<id>.md`). Check: for each event, the effect plays (yes or no).
6b. Film the phone of the player and the TV with sound at 60 fps or more for 3 events. Check: the phone starts to buzz within 100 ms of the start of the sound (count the frames).
6c. With the meter app, read the music and 3 effects at the default levels. Check: each effect reading is 3 to 9 dB above the music reading (the plan: about 6 dB).
7a. Open the pause menu, read the meter before and after. Check: the music reading drops by 8 to 13 dB (the music goes to 30%) and the music does not stop.
7b. Choose Resume. Check: the music comes back to the first reading, within 2 dB, within 1 s, and you hear no jump or click.
7c. Turn off Wi-Fi on one phone. Check: the "phone lost" card shows, and the music drops by 8 to 13 dB in the same way. (The time to show the card changes with issue #56.)
8a. Finish a game with a winner. Finish a one-player game with a medal. Check: both play the winner fanfare (a short rising jingle, 2 s or shorter).
8b. Finish a game with a tie, a round over with no score, and a one-player game with no medal. Check: all three play the tie sound, and it is not the fanfare of step 8a.
8c. Stay on the result menu for 10 s. Check: after the jingle you hear no music and no sound.
8d. Choose Back to menu. Check: the menu song comes back within 5 s.
9a. A child of about 5 to 8 years plays a game with sound for 3 rounds. Read the meter at the highest effect. Check: the reading is 85 dB(A) or lower, and the child does not cover its ears and does not ask for less sound.
10a. On a phone, open **Settings** on the waiting screen. Check: the HAPTICS switch shows and its default is ON.
10b. Turn Haptics ON. Check: the phone vibrates once (about 40 ms).
10c. Play a game with Haptics ON. Check: the phone vibrates at the start and at each event of step 6a that has a haptic.
10d. Set Haptics to OFF and play the same game for 1 minute. Check: the phone does not vibrate, and the game, the sound and the score work as before.
10e. Close the phone app and start it again. Check: Haptics is still OFF. (Set it ON again after the test.)
10f. Take a photo of the waiting screen. Check: the Settings button does not touch the DISCONNECT button.
11a. Film a picture event and its sound on the TV box with a camera at 60 fps or more. Count the frames from the picture to the sound for 3 events. Check: the delay is 100 ms or less (6 frames at 60 fps) for each event.
11b. Start the app with the stopwatch. Check: the first song starts within 5 s (the same limit as step 1a, on the TV box).

Measurements: write down the seconds of step 5b, the meter readings of steps 6c, 7a and 9a, and the delay of step 11a. The levels of the songs are tuned from these values.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Value: seconds until the song starts | Not run | | | |
| 1b | Note: click or pop, yes or no | Not run | | | |
| 1c | Note: the song restarts, yes or no | Not run | | | |
| 2a | Note: count of blips for 5 presses | Not run | | | |
| 2b | Note: rising or falling | Not run | | | |
| 2c | Note: rising or falling | Not run | | | |
| 2d | Note: the join and the leave sounds | Not run | | | |
| 2e | Note: the sound; the game did not start | Not run | | | |
| 3a | Photo of the Settings rows | Not run | | | |
| 3b | Photo of the value at 0 and 10; the three meter readings | Not run | | | |
| 3c | Note: a sample at each change | Not run | | | |
| 3d | Note: silent with Mute ON | Not run | | | |
| 3e | Photo of Settings after the restart | Not run | | | |
| 4a | Note: TV and phone | Not run | | | |
| 4b | Note: the phone is silent | Not run | | | |
| 5a | Note for each game: the count of beeps | Not run | | | |
| 5b | Value for each game: seconds after GO | Not run | | | |
| 5c | Note: a click at the loop point, yes or no | Not run | | | |
| 5d | Note: the songs that sound the same | Not run | | | |
| 5e | Note: the count of ticks | Not run | | | |
| 6a | Note for each event: the effect plays, yes or no | Not run | | | |
| 6b | Video; the frames between the buzz and the sound | Not run | | | |
| 6c | The four meter readings in dB(A) | Not run | | | |
| 7a | Meter readings before and after the pause | Not run | | | |
| 7b | Meter reading after Resume; note: jump or click | Not run | | | |
| 7c | Photo of the card; meter readings | Not run | | | |
| 8a | Note on the winner and the medal sounds | Not run | | | |
| 8b | Note on the tie sounds | Not run | | | |
| 8c | Note: silence after the jingle | Not run | | | |
| 8d | Value: seconds until the menu song | Not run | | | |
| 9a | Note: the child, the age, the highest meter reading, what happened | Not run | | | |
| 10a | Photo of the phone Settings | Not run | | | |
| 10b | Note: one vibration | Not run | | | |
| 10c | Note: the vibration at the events | Not run | | | |
| 10d | Note: no vibration; the game works | Not run | | | |
| 10e | Photo of Settings after the restart | Not run | | | |
| 10f | Photo of the waiting screen | Not run | | | |
| 11a | Video; the frames for 3 events; the delay in ms | Not run | | | |
| 11b | Value: seconds until the first song | Not run | | | |

History:

- -: **Not run**. New.

## Test 19

### Leader chip, phone score and name tags (REQ-FL-67, REQ-GM-46, 46a, FD-21)

Needs: 2 to 4 phones (give two of them names of 10 letters, the most since FD-22), 1 TV on 1080p, a grown-up, a child of about 5 to 8 years for item 8, a person who reads Hebrew for item 9. Covers: REQ-FL-67, REQ-FL-68, REQ-GM-46, 46a, FD-21, issue #25.

New (2026-10-10). The HUD shows one chip, the leader, and not a chip for each player. Each phone shows its own place and score. The size of the header text on the phone and the place of the name tags are first values. The headless tests check the layout rules, not how it looks from the sofa.

**Steps**

1a. Start Banana Party with 4 phones (two names of 10 letters, the most a name can have since FD-22). Take a photo of the TV during play. Check: the title, the timer and one chip with the leader's name and score are all on one row.
1b. In the same photo, check: nothing covers the play area, and the chip ends at the right margin of the screen.
1c. In the same photo, check: the name shows with its first and last letter, and the score shows with all its digits.
2a. In the same game, before anybody scores, check: no chip shows on the TV, and each phone shows only `2P` (or the profile name) and 0.
2b. Score with different phones. Check: the chip shows the new leader within 1 s of the score change.
2c. Make two phones have the same top score. Check: the chip says TIE with a gray square and the score.
2d. Reach a score of 4 digits and of 5 digits (use a test score if the game has one). Check: all the digits show in the chip.
3a. Look at each phone during the game. Check: the line under the header row (not next to Disconnect) shows the place (1ST to 4TH) and the score (`2ND  120`), and it changes within 1 s of a score change.
3b. Play with one phone only. Check: only the score shows (no place).
3c. Hold a phone at 50 cm. Check: you read aloud the place and the score of the line without a mistake.
3d. On an iPhone with a Dynamic Island (and on an Android phone with a camera cut-out), take a photo of the pad. Check: the colored square, the player number and DISCONNECT are fully visible, and A and B are fully on the screen (REQ-FL-68).
3e. Turn the same phone to landscape and back. Check: nothing is hidden at the top, at the bottom (the home bar) or at the side.
3f. Open the pause menu. Check: the phone keeps its score. Go back to the menu: the score is gone.
4a. Play Paint Grab with 2 to 4 phones. Check: the same as steps 1a, 1b, 2a, 2b and 3a.
4b. Play Sumo Bumpers with 2 to 4 phones. Check: the same as steps 1a, 1b, 2a, 2b and 3a. The name tags show again in the countdown of every round.
4c. Play Galaxy Protector (4 ships) and Tennis. Check: the same as steps 1a, 1b, 2a, 2b and 3a.
5a. Play Road Rally with 3 or 4 phones. Check: the leader chip names the first car, and it shows its time after the finish.
5b. In the same race, check: each phone shows its place, and a car that has not finished shows no time.
5c. Check: the old list of names at the left of the screen is gone.
6. Play Treasure Maze with 2 to 4 phones. Check: there is no chip during play (the maze has no score) and each phone shows only `2P`.
7a. In the countdown of every game, take a photo. Check: each player's name stands next to its own ball, car, cursor, bumper, blob, ship or character, in its color.
7b. In the countdown of the maze and of Sumo Bumpers with 4 phones, check: no tag covers another tag, and every name is complete.
7c. Check: all the tags are gone when GO shows. No tag covers the object of another player. Write down the game and the place of each problem.
8a. A child of 5 to 8 years plays a game. In the countdown, ask the child to point to its own object. Check: the child points to the right object within 10 s and without help.
8b. After one minute of play, ask the child to read aloud the number on its phone. Check: the child says the number that the phone shows.
9a. Set the TV to Hebrew and play one game with 2 phones. Check: the leader chip is at the left margin and the timer is at the left of the title.
9b. Make a tie. Check: the chip says "תיקו".
9c. The person who reads Hebrew reads the header of a phone. Check: the place and the score are read without a mistake.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the TV with 4 long names | Not run | | | |
| 1b | Same photo | Not run | | | |
| 1c | Same photo | Not run | | | |
| 2a | Photo of the TV and of a phone before a score | Not run | | | |
| 2b | Video: the score change and the new chip; the seconds | Not run | | | |
| 2c | Photo of TIE | Not run | | | |
| 2d | Photo of a 4-digit and a 5-digit score | Not run | | | |
| 3a | Photo of a phone header with place and score | Not run | | | |
| 3b | Photo of a phone with one player | Not run | | | |
| 3c | Note: read without a mistake, yes or no | Not run | | | |
| 3d | Photos of the pad on an iPhone and an Android phone with a cut-out | Not run | | | |
| 3e | Photos of the phone in landscape | Not run | | | |
| 3f | Photos of the phone in pause and after the menu | Not run | | | |
| 4a | Note and photo for Paint Grab | Not run | | | |
| 4b | Note and photo for Sumo Bumpers | Not run | | | |
| 4c | Note and photo for Galaxy Protector and Tennis | Not run | | | |
| 5a | Photo of the Road Rally HUD | Not run | | | |
| 5b | Photo of the phones | Not run | | | |
| 5c | Photo of the HUD | Not run | | | |
| 6 | Note: no chip in the maze | Not run | | | |
| 7a | Photo of the countdown of each game | Not run | | | |
| 7b | Photos of the maze and Sumo Bumpers countdowns | Not run | | | |
| 7c | Photos before and after GO; list of problems | Not run | | | |
| 8a | Note: the child, the age, the seconds | Not run | | | |
| 8b | Note: the child, the age, the number | Not run | | | |
| 9a | Photo of the Hebrew HUD | Not run | | | |
| 9b | Photo of the Hebrew TIE | Not run | | | |
| 9c | Photo of the Hebrew phone header; note from the Hebrew reader | Not run | | | |

History:

- -: **Not run**. New.

## Test 20

### Player profiles (REQ-FL-69 to 75, REQ-N8, REQ-C7 to C9, FD-22)

Needs: 2 to 4 phones (one an iPhone if possible), 1 TV on 1080p, a grown-up, a child of about 5 to 8 years for items 7b and 17d, a person who reads Hebrew for item 6d, a stopwatch. Covers: REQ-FL-69 to 79, REQ-GM-98 to 101, REQ-N8, REQ-C7 to C11, FD-22. Items 1 to 8 are phase A (names and avatars), items 9 to 11 are phase C (personal bests), items 12 to 15 are phase B (copy by QR), items 16 and 17 are the Connect screen and the HUD changes of 2026-10-11 (`docs/PROFILES_PLAN.md`, section 11.2).

New (2026-10-10). The headless tests check the rules and the drawing. They do not show how an avatar looks from the sofa, or how the profile screens work in a hand.

**Steps**

1a. Make a profile on a phone (name, avatar) and join a TV. Check: the TV shows the name and the avatar in the Players list.
1b. Start a game. Check: the name and the avatar show in the countdown tag and on the leader chip (make this phone the leader).
1c. Finish the round. Check: the name and the avatar show in the result list, and no text "Player N" shows for that phone anywhere on the TV.
2a. Change the avatar and the name with the pencil button on the Connect screen, then join. Check: the TV shows the new name and avatar within 3 s of the join.
2b. Check: the phone shows the same name that the TV shows (REQ-FL-75).
3a. A parent phone with 3 profiles: after a round tap DISCONNECT, pick another profile on the Connect screen and join again. Check: the TV shows the new name and avatar.
3b. While the phone is joined, look at the waiting screen, the pad and Settings. Check: no button changes the player (REQ-FL-71).
4a. Two phones with the names `Sam` and `sam`. Check: the TV shows `SAM` and `SAM 2` (upper case, REQ-FL-39).
4b. Use a name of 10 letters and a Hebrew name of 10 letters. Check: both show complete (the first and the last letter) on the cards and in the lists.
6a. Pause card with profile names: switch the Wi-Fi of a phone off. Stop the time from the switch to the card. Check: the card `MAYA LOST CONNECTION` shows within 5 s. (Changes with issue #56: within 3 s.)
6b. On the card, check: the button `Resume without Maya` shows. Switch the Wi-Fi on. Check: the title changes to `Maya reconnected` and the button `Resume` shows.
6c. Use two names of 10 letters. Check: both names show complete on the card.
6d. Show the card with a Hebrew name in the English sentence, and with an English name in the Hebrew sentence. The Hebrew reader reads both aloud. Check: each name has its letters in the same order as typed, and the sentence has no broken order.
7a. Show all 32 avatars on the four slot colors, at the smallest size they have (the HUD chip and the result row). Take a photo of each size. Check: you count 32 different pictures (no two are the same picture).
7b. A child of 5 to 8 years joins with a phone, and 3 other players join. Ask the child to point to its own avatar on the TV. Check: the child points to it within 10 s and without help.
8a. The same profile on a second phone joins the same TV while the TV is in a menu. Check: the older phone shows `THIS PLAYER IS ALREADY IN THE ROOM.` and goes to the Connect screen.
8b. Repeat during a round. Check: the second phone waits as a guest, the first phone stays in the game, and the count of players on the TV does not go down.
9a. Play Banana Party, Paint Grab, Galaxy Protector, Pin Pals (Rails Off; with Rails On there is no NEW BEST) and Road Rally (a fixed track) with a profile on 2 phones. When the round is over, check: the phone of a player who scores shows NEW BEST! on the waiting screen.
9b. Play a worse round in the same game. Check: the best does not change (the next round shows "BEFORE:" with the first score).
9c. Play a second round. Check: the phone shows "BEFORE: x" and x equals the old best (a race time in seconds).
9d. Check: the phone of a guest shows nothing about a best.
10. Close the app and open it again, then join another TV. Play the same game as in step 9. Check: "BEFORE" shows the old best from before the restart.
12a. Share a profile to a second phone by QR: give the profile some personal bests first. On the first phone open the list and tap SHARE on a row; on the second phone tap SCAN A PROFILE. Check: the second phone shows PLAYER ADDED. with the same name and avatar.
12b. Open the profile on the second phone. Check: the personal bests equal the ones on the first phone (compare 3 values).
12c. Time the code (tap SHARE to the picture) and the scan (start of the scan to PLAYER ADDED.) from 30 cm, with the screen at full brightness. Check: the code shows within 2 s and the scan takes 10 s or less.
12d. Repeat from 60 cm, and with the screen at low brightness (4 combinations). Check: PLAYER ADDED. shows within 20 s in each combination.
13a. Share a player that the second phone already has, after a rename on the first phone (the name is newer there). Check: the second phone shows PLAYER UPDATED. and has the newer name and avatar.
13b. Rename on the second phone and scan the old copy again. Check: the newer name stays.
13c. Give each phone a better best for one game and scan again. Check: both phones keep the better value for each game.
14a. An iPhone: tap COPY CODE on one phone. Check: the phone says CODE COPIED.
14b. On the iPhone tap PASTE A CODE. Check: the iPhone shows no scan button, and it shows PLAYER ADDED. with the same name, avatar and bests as in step 12.
15a. Change one letter of a copied code, then paste. Check: the phone says THIS CODE DOES NOT WORK.
15b. Scan the QR code of the TV on the list. Check: the phone says THIS IS A ROOM LINK.
15c. Scan a player code on the Connect screen. Check: the player is added and the list opens.
16a. New (REQ-FL-71, 72). On the Connect screen open the dropdown. Check: it shows the avatar and the name together; pick another player, and the dropdown shows that player; pick GUEST, and the dropdown shows GUEST.
16b. Tap **+**. Tap the name field. Check: the keyboard opens and stays open. Tap outside the field: the keyboard closes.
16c. On the new player screen, check: the 32 avatars are in one line, the line scrolls by a drag and by the arrows (three avatars for each tap), and the picked avatar is in view when the screen opens.
16d. Go to the first and to the last avatar. Check: the arrow of that side is dim and does nothing.
16e. In Hebrew, check: the arrows still move the line in the direction that they point.
16f. Tap **Back** from the new player screen. Check: you are on the Connect screen, not on the list. Tap **PLAYERS** in the dropdown: the list opens. SAVE and BACK are at the bottom of the screen.
16g. Tap the pencil button next to the dropdown. Change the name and the avatar, tap SAVE, and join. Check: the TV shows the new name and avatar.
16h. Tap the pencil button and then Back. Check: you are on the Connect screen.
17a. New (REQ-FL-71, REQ-GM-46b, 70). Join a TV. Check: the waiting screen has only DISCONNECT (top right), the text, SETTINGS and ABOUT, and no PLAYER button. To change the player, tap DISCONNECT and choose on the Connect screen.
17b. On the TV, in every game, check: the leader chip and the name tags in the countdown show the color square, then the avatar, then the name, also in Hebrew (left to right inside the chip).
17c. In every game, check: no ball, marble, blob, bumper or cursor shows a number or an avatar, only its color.
17d. A child of 5 to 8 years plays a game. Check: in the countdown the child points to its own object within 10 s, with the name tags and without help.

Items 5, 11 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-20-5 and A-20-11). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the Players list with the profile | Not run | | | |
| 1b | Photos of the countdown tag and the leader chip | Not run | | | |
| 1c | Photo of the result list | Not run | | | |
| 2a | Video of the join; the seconds until the new name | Not run | | | |
| 2b | Photo of the phone and of the TV | Not run | | | |
| 3a | Video of a switch between rounds | Not run | | | |
| 3b | Photos of the three phone screens | Not run | | | |
| 4a | Photo of `SAM` and `SAM 2` | Not run | | | |
| 4b | Photo of the 10-letter names | Not run | | | |
| 6a | Photo of the pause card in English; the seconds | Not run | | | |
| 6b | Photos of both cards | Not run | | | |
| 6c | Photo of the card with two long names | Not run | | | |
| 6d | Photo of the card in English and in Hebrew; note from the Hebrew reader | Not run | | | |
| 7a | Photos of the 32 avatars at both sizes | Not run | | | |
| 7b | Note: the child, the age, the seconds | Not run | | | |
| 8a | Photo of the message on the older phone | Not run | | | |
| 8b | Photo of the TV and the two phones | Not run | | | |
| 9a | Photo of NEW BEST! on a phone | Not run | | | |
| 9b | Photo of the next BEFORE text | Not run | | | |
| 9c | Photo of BEFORE on a phone | Not run | | | |
| 9d | Photo of the guest phone | Not run | | | |
| 10 | Note: the bests after a restart of the app | Not run | | | |
| 12a | Video: the scan | Not run | | | |
| 12b | Photos of the bests on both phones | Not run | | | |
| 12c | Value: seconds to show and to scan | Not run | | | |
| 12d | Values: seconds for the 4 combinations | Not run | | | |
| 13a | Photos of both phones | Not run | | | |
| 13b | Note: the names on both phones | Not run | | | |
| 13c | Photos of the bests on both phones | Not run | | | |
| 14a | Note: the iPhone model; the message | Not run | | | |
| 14b | Photo of the iPhone screen | Not run | | | |
| 15a | Photo of the message | Not run | | | |
| 15b | Photo of the message | Not run | | | |
| 15c | Photo of the message and the list | Not run | | | |
| 16a | Video of the dropdown | Not run | | | |
| 16b | Video of the keyboard | Not run | | | |
| 16c | Video of the avatar line | Not run | | | |
| 16d | Photos of the dim arrows | Not run | | | |
| 16e | Photo of the Hebrew arrows | Not run | | | |
| 16f | Video of Back and PLAYERS; photo of SAVE and BACK | Not run | | | |
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
8a. On the TV: Settings, About. Check: the list opens and has "Godot Engine" and "3rd Party Libraries".
8b. Open "Godot Engine". Check: the page shows the MIT text. Go back and open "3rd Party Libraries", then one library (for example FreeType) and one with two licenses. Check: each page opens.
8c. In the "3rd Party Libraries" list, check: every row shows the name and the license type, and a long name wraps to more lines and is not cut.
8d. Read the first line of a page aloud from 3 m. Check: you read it without a mistake. Press Down and Up. Check: the text scrolls.
8e. Press Back three times from a library page. Check: each press goes up one step (page, list of libraries, About list), and the next press goes to Settings.
8f. On the TV box, use the stopwatch from OK on "3rd Party Libraries" to the list on the screen, and from OK on a library to its page. Check: the list opens within 3 s and the page within 2 s.
9a. On a phone: open About on the waiting screen (the button after Settings), and About in the top corner of the Connect screen (right in English, left in Hebrew). Check: both open the About list.
9b. Check: the pages scroll by touch.
9c. On an Android phone, check: the list has the page "QR scanner", and the page says that Google receives technical data. In 3rd Party Libraries (also on the Android TV), check: the page "Android libraries" has the Apache 2.0 text.
9d. Open the page "Android libraries" and scroll to the end with the stopwatch. Check: it opens within 3 s and you reach the end of the text.
9e. Take a photo of the Connect screen. Check: the About button, the dropdown, the pencil and the + button do not touch each other, and all are inside the screen.
9f. Tap the pencil button next to the player. Check: the edit screen of the active profile opens (the name field and SAVE show).
10a. Set the TV to Hebrew. Check: the About list and the pages "Sababi" show in Hebrew, and the Hebrew reader says that the wording is correct. (The planned Settings changes of issue #49 are in Test 18.)
10b. Check: the license pages stay in English.
10c. Open the PIN pad on a phone in Hebrew (before issue #52). Check: the digit keys are in the same places as in English, and the PIN line shows the digits in the order that you typed them.

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
| 8a | Photo of the About list | Pass | R1 | | |
| 8b | Photo of the Godot page and a library page | Pass | R1 | | |
| 8c | Photo of the 3rd Party Libraries list | Pass | R1 | | |
| 8d | Note: read aloud from 3 m; scroll | Pass | R1 | | |
| 8e | Note: the steps of Back | Pass | R1 | | |
| 8f | Values: seconds for the list and for a page | Not run | | | New limits (3 s and 2 s) after R1. |
| 9a | Photo of the phone About list and the Connect screen | Pass | R1 | | |
| 9b | Note: scroll by touch | Pass | R1 | | |
| 9c | Photos of the pages "QR scanner" and "Android libraries" | Pass | R1 | | |
| 9d | Value: seconds to open the page | Not run | | | New limit (3 s) after R1. |
| 9e | Photo of the Connect screen | Pass | R1 | | |
| 9f | Photo of the edit screen | Not run | | | R1 judged whether the pencil is easy to tell as Edit. The check changed. |
| 10a | Photo of the Hebrew About screen; note from the Hebrew reader | Fail | R1 | | R1: "1. language should be modified by left and right keys. should be a selection of languages. 2. no explanation strings needed for the settings 3. drop Mute. it should be covered by music=0 and/or effects=0" (This note is about the Settings screen: issue #49. See Test 18 step 3.) |
| 10b | Photo of a license page | Fail | R1 | | R1 (before the split): step 10 failed. The failure is in step 10a. |
| 10c | Photo of the Hebrew PIN pad | Fail | R1 | | R1 (before the split): step 10 failed. The failure is in step 10a. |

History:

- R1: **Fail** (steps 3, 4 and 10; the steps 1, 2, 5 to 9 pass). Reported in chat 2026-10-19. The failures of steps 3 and 4 are about the error texts WRONG PIN and TOO MANY WRONG PINS (no text, or a text that goes away). The note of step 10 asks for changes of the Settings screen (issue #49).
- -: **Not run**. New.

## Test 22

### Galaxy Protector (tilt, waves, upgrades)

Needs: 1 to 4 phones, 1 TV, a stopwatch, a phone with a level (angle) app, and a child of about 5 to 8 years for items 9a to 9c. Covers: REQ-AB-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Hold each phone upright or flat as you do for the other tilt games. New game (2026-10-16). Every number (ship speed, the rate of fire, the asteroid speeds, the waves, the upgrade times, the medal tiers) is a first guess, but each step below has a fixed limit. "From 3 m" means: sit or stand 3 m from the TV. Play on Medium unless the step says another difficulty.

**Steps**

1a. Open the tile of **Galaxy Protector** with 1 phone. Check: the settings view opens, and the Difficulty row shows Medium. Start.
1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the night sky with stars, the purple planet, a gray asteroid and a ship. (Changes with issue #57.)
2a. Tilt the phone to the right in "3, 2, 1". Check: the ship moves to the right within 1 s. Check: no asteroid falls and no beam fires until "GO!".
2b. Look at the TV in "3, 2, 1" with 4 phones. Check: each ship has a name tag over it, the text of the tag is the name of its phone, and the tags are gone 1 s after "GO!".
2c. Start the stopwatch at "GO!". Check: the hint line "Tilt to steer. Your ship shoots by itself. Grab the upgrades!" shows in the countdown, and it is gone 5 s after "GO!" (limit: 4 to 6 s). Read it aloud from 3 m without an error.
2d. Hold the phone in your hand. Check: the phone does not buzz in "3, 2, 1" and buzzes once at "GO!".
3a. Tilt the phone 45 degrees to the right (check the angle with the level app), then 45 degrees to the left. Check: the ship moves to the right, then to the left, in the same direction as the tilt.
3b. Tilt 45 degrees to the right and start the stopwatch when the ship leaves the left stop. Check: the ship needs 2.5 to 4.2 s to reach the right stop (full tilt is 760 px/s, 45 degrees is 0.71 of it, the way is 1800 px). (REQ-AB-2)
3c. Tilt to the right and keep the tilt for 2 s after the ship stops. Do the same to the left. Check: the ship stops at both sides, stays fully on the screen, does not move more, and its middle is 2 % to 4 % of the screen width (60 px of 1920) from the edge.
3d. Hold the phone still for 10 s. Check: the ship does not move.
3e. Tilt the phone 45 degrees to the right and hold it. Press **RECENTER**. Check: the ship stops within 1 s and stays still for 5 s while you hold the phone in the new pose. (REQ-AB-3)
4a. Count the shots of one ship for 10 s with the stopwatch (video). Check: the ship fires by itself, with no button, 22 to 28 times (one shot every 0.4 s is 25).
4b. Look at the beams of 2 ships of different colors. Check: the beam of each ship has the color of its hull.
4c. Wait until the three sizes are on the screen at the same time. Take a photo. Check: the large asteroid is more than 2 times as wide as the small one, and the medium one is wider than the small one and narrower than the large one.
4d. Shoot at one asteroid of each size with 1 laser and count the hits (video). Check: a large one breaks after 4 hits into two medium ones, a medium one after 2 hits into two small ones, and a small one after 1 hit into nothing.
5a. Start the stopwatch at "GO!" and write down the time of each upgrade that falls in the first 60 s. Check: the first upgrade enters at the top 9 to 11 s after "GO!", and the next ones come 12 to 20 s after the one before. (REQ-AB-10)
5b. Look at 3 upgrades of different kinds. Check: the shield is a blue disc with a white shield, the weapon is an orange disc with a white arrow, and no upgrade has another color.
5c. Take a shield upgrade. Check: a light blue ring shows around the ship, and the phone buzzes once.
5d. Take 3 weapon upgrades, one after the other, and count the beams of one shot after each one. Check: the number of beams is 2, then 3, then 4, side by side.
5e. Take a weapon upgrade when the ship has 4 lasers, and a shield upgrade when the ship has a ring already. Check: each gives exactly 50 points, the ship keeps 4 lasers, and it keeps one ring. (REQ-AB-11)
6a. Let an asteroid hit the ship with the ring. Check: the ring goes away, the asteroid breaks into dust (no pieces), and the ship flies on.
6b. Let an asteroid hit a ship with a ring. Check: the phone buzzes once, and the buzz is felt as short (80 ms), shorter than the buzz of step 6d.
6c. Let an asteroid hit the ship with no ring. Check: the ship bursts into colored pixels, and it does not come back in the next 30 s.
6d. Let an asteroid hit the ship with no ring (second time, new round). Check: the phone buzzes once, a long buzz (400 ms) that you can tell from the buzz of step 6b, and the points of the player do not change at the hit.
7a. Start the stopwatch at the banner "Wave 1". Check: the rest starts 30 s later (limit: 29 to 31 s) with the banner "Wave 1 clear!".
7b. Start the stopwatch at "Wave 1 clear!". Check: the line "Next wave in N" counts down, and the banner "Wave 2" shows 5 s later (limit: 4 to 6 s).
7c. Take photos of the line in the bar at 0 s, 15 s and 30 s of a wave. Check: the line is full at 0 s, half full at 15 s (35 % to 65 %) and empty at 30 s.
7d. Start the stopwatch when a medium asteroid enters at the top and stop it when it leaves at the bottom. Do it in wave 1 and in wave 6. Check: the time in wave 6 is at most 75 % of the time in wave 1 (the speed grows 10 % for each wave: the expected ratio is 0.67).
7e. Count the asteroids that enter the screen in 10 s in wave 1 and in wave 6 (1 phone). Check: wave 6 has at least 1.5 times as many as wave 1 (the expected ratio is 2).
8a. Play with 2 phones. Check: the leader chip shows the name and the points of the player with the most points, and each phone shows its own points, which are equal to the points of that player on the TV at the same moment (photo).
8b. Play with 3 and with 4 phones. Check: the phone of each player shows its place, and the places agree with the order of the points on the TV (photo of the TV and the phones at the same moment).
8c. Let one ship be lost when 2 or more ships are still flying. Check: the other ships fly on and fire for 10 more s, and the lost ship does not come back.
8d. Let the last ship be lost. Start the stopwatch. Check: the banner "ALL SHIPS ARE GONE!" shows, and the result menu opens 1 to 3 s later.
8e. Play alone. Check: the result title is "Reached wave N", where N is the number of the last wave banner that you saw. The medal is the one of the table (Medium: bronze from 600 points, silver from 1800, gold from 4000, no medal below 600).
8f. Finish a round with 2 phones. Check: the result menu names the player with the most points as "X wins!", and the list is in the order of the points. (The places, a tie, a leave and the buzz at GO with 3 and 4 phones are checked by `multi_phone`.)
9a. Let a child of about 5 to 8 years play, with a grown-up next to them who does not help. Check: in "3, 2, 1" the child points at its own ship within 10 s.
9b. Same child. Check: the child moves the ship from the middle to the left side of the screen within 30 s after "GO!", with no help.
9c. Same child. Lose the ship of the child on purpose. Check: the child is still at the game 30 s later (does not stop and does not give the phone back). Ask: "Play again?". Check: the child says yes.
10a. Play with 2 phones. Leave the game on one phone during a wave. Check: its ship is gone within 2 s, and the other ship flies and fires for 10 more s.
10b. With 1 phone left, leave the game. Check: the "No players connected" menu opens.
11. Play with 4 phones on Hard until wave 8 or later and open the debug overlay. Check: the FPS value is 55 or more for 30 s. (REQ-GM-50)
12a. **Pixel world (REQ-GM-47i to 47n, REQ-AB-17).** Take a close photo of the TV (30 cm). Check: the edges of the ship and of an asteroid are steps of square pixels, with no blurred edge and no gradient inside a color area.
12b. From 3 m, look for the objects. Check: you can point at all of these: stars, the planet with the ring, an asteroid with craters, a ship, a beam, an upgrade and an explosion.
12c. Play with 4 phones. From 3 m, each tester names the color of the ship of a phone you point at. Check: 4 of 4 answers are right for every tester.
12d. Take a photo of the TV screen with a ship. Check: the ship is at least 4.4 % of the screen height (48 px of 1080).
12e. From 3 m, read aloud the banners "Wave 2", "Wave 2 clear!" and "Next wave in 4", and the points in the bar. Check: no error.
(The music and the effects are checked in Test 18.)

Measurements (write down, no pass or fail): the real delay from a tilt to the ship moving; the wave from which you lose in less than 60 s on Easy, Medium and Hard; how long a player who is out waits for the end of the round with 4 phones; if the rate of fire of 1 shot every 0.4 s feels too slow at the start. Use them to tune `SHIP_SPEED`, `SHIP_SMOOTH`, `FIRE_EVERY` and the wave values.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the settings view (Difficulty row) | Not run | | | |
| 1b | Photo of the tile next to a photo of the game | Not run | | | |
| 2a | Video of the countdown and GO | Not run | | | |
| 2b | Photo of the countdown with 4 name tags | Not run | | | |
| 2c | Video with the stopwatch: seconds from GO to the end of the hint | Not run | | | |
| 2d | Note: buzz in 3, 2, 1 (yes or no); buzz at GO (yes or no) | Not run | | | |
| 3a | Video of the tilt to both sides | Not run | | | |
| 3b | Note: stopwatch seconds for the way from stop to stop | Not run | | | |
| 3c | Photo of the ship at each stop; note: distance to the edge in % | Not run | | | |
| 3d | Note: ship moved (yes or no) in 10 s | Not run | | | |
| 3e | Video of RECENTER; note: seconds until the ship stops | Not run | | | |
| 4a | Video of 10 s; note: number of shots | Not run | | | |
| 4b | Photo of 2 ships with their beams | Not run | | | |
| 4c | Photo with the three sizes; note: width of large / width of small | Not run | | | |
| 4d | Video of the shooting; note: hits for each size | Not run | | | |
| 5a | Note: times of the upgrades in s after GO | Not run | | | |
| 5b | Photo of a shield and a weapon upgrade | Not run | | | |
| 5c | Photo of the ring; note: buzz (yes or no) | Not run | | | |
| 5d | Video of the beam count 2, 3, 4 | Not run | | | |
| 5e | Note: points before and after, lasers, rings | Not run | | | |
| 6a | Video of a hit with a ring | Not run | | | |
| 6b | Note: buzz and its length compared with 6d | Not run | | | |
| 6c | Video of a ship that bursts | Not run | | | |
| 6d | Note: buzz length; points before and after the hit | Not run | | | |
| 7a | Note: stopwatch seconds of wave 1 | Not run | | | |
| 7b | Note: stopwatch seconds of the rest; text of the banners | Not run | | | |
| 7c | 3 photos of the line | Not run | | | |
| 7d | Note: seconds of a medium asteroid in wave 1 and wave 6 | Not run | | | |
| 7e | Note: asteroids in 10 s in wave 1 and wave 6 | Not run | | | |
| 8a | Photo of the TV and 2 phones at the same moment | Not run | | | |
| 8b | Photo of the TV and the phones with 3 and 4 phones | Not run | | | |
| 8c | Video of a ship lost and the others for 10 s | Not run | | | |
| 8d | Video with the stopwatch: seconds from the banner to the menu | Not run | | | |
| 8e | Photo of the result menu with the medal; note: points and N | Not run | | | |
| 8f | Photo of the result menu with 2 phones | Not run | | | |
| 9a | Note: the child, the age, seconds until it points | Not run | | | |
| 9b | Note: seconds until the ship is at the left side | Not run | | | |
| 9c | Note: the child is still at the game after 30 s (yes or no); the answer | Not run | | | |
| 10a | Note: seconds until the ship is gone; the other ship after 10 s | Not run | | | |
| 10b | Photo of the "No players connected" menu | Not run | | | |
| 11 | Overlay screenshot (FPS) with 4 phones on Hard, wave 8 or later | Not run | | | |
| 12a | Close photo of the TV (30 cm) | Not run | | | |
| 12b | Note: the seven objects, each yes or no | Not run | | | |
| 12c | Note: the answers of each tester (n of 4) | Not run | | | |
| 12d | Photo of a ship; note: ship height in % of the screen height | Not run | | | |
| 12e | Note: errors made when reading the texts | Not run | | | |

History:

- -: **Not run**. New (2026-10-16).

## Test 23

### Pin Pals (bowling: aim with a turn, swing to throw)

Needs: 1 to 4 phones, 1 TV, a stopwatch, a phone with a level (angle) app, a phone camera (60 fps or more), and a child of about 5 to 8 years for items 11a to 11c. Covers: REQ-BW-*, REQ-GM-80 to 84, REQ-GM-90 to 98, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-16). It was only tested with made-up sensor values. Every number (the swing thresholds 4, 8 and 30 m/s2, the aim ranges, the ball speeds, the lane, the pins, the medal tiers) is a first guess, but each step below has a fixed limit. Hold the phone in one hand like a ball, arm down at the side. "From 3 m" means: sit or stand 3 m from the TV. Play on Medium unless the step says another difficulty.

**Steps**

1a. Open the tile of **Pin Pals** with 1 phone. Check: the settings view has the row Difficulty with Medium and the row Rails with Off. Start.
1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the lane with pins, the ball, the gray floor and the disco wall. (Changes with issue #57.)
2a. In "3, 2, 1" look at the lane. Check: the name tag with the name of the phone is at the ball.
2b. Count the lanes in "3, 2, 1". Check: there is 1 own lane, 3 darker lanes on the left and 3 darker lanes on the right, each with a rack of pins.
2c. Look at the far wall. Check: the top two thirds are colored light tiles (the disco wall), and the bottom third is plain black.
2d. Look at the bottom and the top of the screen. Check: the score sheet shows a row with 10 cells for each player. Check: the top bar shows the title and "Frame 1/10  Ball 1", and shows no leader chip.
2e. Point the phone 30 degrees to the left of the TV before the first turn starts, and hold it still. Check: when the turn starts, the aim mark is inside the middle fifth of the lane width. (REQ-BW-4)
3a. Turn the phone 7 degrees to the right, then 7 degrees to the left (check the angle with the level app). Check: the aim mark moves to the right, then to the left, in the direction of the turn, with no jump.
3b. Medium: turn the phone 14 degrees (the end of the range) and then 7 degrees. Check: at 14 degrees the mark is at the end of its path (in the gutter), and at 7 degrees it is 35 % to 65 % of the way from the middle to the end. (REQ-BW-4)
3c. Easy: turn the phone 18 degrees. Hard: turn the phone 11 degrees. Check: on both difficulties the mark is at the end of its path.
3d. Hold the phone still for 30 s. Check: the aim mark moves less than 10 % of the lane width.
4a. Swing back. Check: the mark stops and turns solid within 0.5 s of the back swing, and it does not move when you turn the phone 20 degrees while you hold the back swing. (REQ-BW-5)
4b. Swing back, then forward. Check: the ball leaves the foul line within 1 s of the end of the forward swing.
4c. Throw 5 balls. Check: the phone buzzes once at each throw.
4d. Throw 5 soft balls (just over the limit) and 5 hard balls (as hard as you can). Time the ball from the foul line to the first pin with the camera. Check: the soft ball needs at least 1.25 times as long as the hard ball (the expected ratio is 1.43). (REQ-BW-6)
4e. Throw 10 balls with each grip: screen up, screen to the side, and the other hand. Check: at least 8 of 10 swings throw a ball for each grip. (REQ-BW-5)
4f. Move the phone to aim 10 times without a swing back and forward. Walk 10 steps with the phone in your hand. Check: no ball is thrown.
5a. Swing back as usual, but swing forward only a very little. Check: no ball is thrown, the text "SWING A BIT MORE!" shows, and the text is gone after 2 to 4 s. The aim mark is free again 1 to 2 s after the back swing.
5b. Wait 60 s on your turn with no swing. Check: it is still your turn (the plate shows your name), and a normal swing then throws a ball.
6a. Play a whole game (10 frames) with 1 phone. Write down the pins of every ball. Check: the total on the score sheet after frame 10 is equal to the total that you count by hand with the standard rules. (The rules are tested by `bowling_rules`.)
6b. Look at the banner after each ball. Check: 10 pins with ball 1: "STRIKE!". 10 pins with 2 balls: "SPARE!". 7 to 9 pins with ball 1 (no strike, no spare): "NICE ROLL!". 1 to 6 pins: "NICE TRY!". 0 pins or a gutter: "OOPS! OFF THE SIDE". The banner matches the pins for at least 18 of 20 balls.
6c. Throw the last ball of frame 10. Start the stopwatch. Check: the top bar shows "Frame 10/10", and the result menu opens 1 to 3 s after the last ball. (REQ-BW-1)
6d. Look at the result menu. Check: the medal is the one of the table for the played difficulty (Medium: bronze from 60 points, silver from 100, gold from 150, no medal below 60).
7a. Set Rails to On. Aim to the end of the path and throw 5 balls. Check: in the video, each ball touches a rail and rolls back into the lane, and 0 balls are in the gutter. (REQ-BW-10)
7b. Finish a game with Rails On. Check: the result menu has no personal best, and the phone shows no "NEW BEST!". (REQ-BW-19)
8a. Play with 2, 3 and 4 phones for 2 frames. Check: the name on the plate "NAME, YOUR TURN!" goes in slot order in each frame (1, 2, 3, 4, then 1 again). The plate shows for 1 to 2 s.
8b. Swing a phone that is not on turn 5 times. Check: no ball is thrown, and nothing changes on the TV.
8c. Look at each phone after a throw. Check: the score and the place on the phone are equal to the total and the order on the score sheet.
8d. Finish a game with 2 phones. Check: the result menu names the player with the most points as "X wins!", and the list is in the order of the totals.
8e. Play a game with 4 phones. With a stopwatch, measure for each player the time from its own throw (the last ball of its frame) to its next turn. Check: the longest time is 35 s or less (the plan says about 30 s). (The places, a tie, a phone that leaves and the buzz at GO with 3 and 4 phones are checked by `multi_phone`.)
9a. Look at the phone on turn. Check: it shows "YOUR TURN" and buzzes once when the turn starts. (REQ-BW-14)
9b. Look at the phones that wait. Check: each shows "<NAME> IS BOWLING" with the name of the player on turn.
9c. Open the result menu. Check: the line "YOUR TURN" or "<NAME> IS BOWLING" is gone on every phone.
10a. Play with 2 phones. Leave the game on the phone that is on turn. Check: the plate shows the name of the next player within 5 s, and the game goes on.
10b. With 1 phone left, leave the game. Check: the "No players connected" menu opens. (The pause of a lost phone is checked by A-23-10.)
10c. Pause the game from the TV (OK) on your turn, then choose Resume. Check: a full swing back and forward within 10 s after Resume throws a ball. (REQ-BW-20)
11a. Let a child of about 5 to 8 years play on Easy with Rails On, with a grown-up next to them who does not help. Check: in "3, 2, 1" the child points at its own ball (the name tag) within 10 s.
11b. Same child. Check: the child throws a ball (a ball leaves the foul line) within 60 s after the first plate "YOUR TURN", with no help.
11c. After the game, ask: "Play again?". Check: the child says yes.
12. Play with 4 phones and open the debug overlay. Check: the FPS value is 55 or more for 30 s. (REQ-GM-50)
13a. **Pixel world (REQ-GM-47i to 47n).** Take a photo of the far end of the lane. Check: a pin is at least 4.4 % of the screen height (12 world pixels, 48 px of 1080), and the white pins stand in front of black.
13b. From 3 m, a tester points at the ball each time you say "mark" at a random time during a roll. Check: the finger points at the ball (not at a pin or the lane) in 5 of 5 tries.
13c. From 3 m, read aloud the totals of all rows of the score sheet and one banner. Check: no error.
13d. Look at the disco wall for 30 s. Check: the top two thirds are light tiles, the bottom third is plain black, and no tile changes more than 3 times in 1 s.
(The music and the effects are checked in Test 18.)

Item 14 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-23-14). The numbers of the other items do not change.

Measurements (write down, no pass or fail): the turn angle that you find best for each difficulty and if turn or tilt is better for bowling; every swing that did not throw and every throw that you did not mean (with the grip); the peak power of a soft and a hard swing. Use them to tune `AIM_RANGE_DEG`, `BACK_ACCEL`, `FWD_ACCEL` and `FWD_FULL`.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the settings view | Not run | | | |
| 1b | Photo of the tile next to a photo of the game | Not run | | | |
| 2a | Photo of the countdown with the name tag | Not run | | | |
| 2b | Photo of the countdown; note: lanes on each side | Not run | | | |
| 2c | Photo of the far wall | Not run | | | |
| 2d | Photo of the score sheet and the top bar | Not run | | | |
| 2e | Photo of the aim mark at the start of the turn | Not run | | | |
| 3a | Video of the turn to both sides | Not run | | | |
| 3b | 2 photos of the mark (14 and 7 degrees) with the level app | Not run | | | |
| 3c | 2 photos of the mark (Easy 18, Hard 11 degrees) | Not run | | | |
| 3d | 2 photos of the mark at 0 s and 30 s | Not run | | | |
| 4a | Video of the back swing with the mark | Not run | | | |
| 4b | Video; note: seconds from the swing to the ball | Not run | | | |
| 4c | Note: buzzes in 5 throws (yes or no for each) | Not run | | | |
| 4d | Video; note: seconds to the first pin, soft and hard | Not run | | | |
| 4e | Note: throws of 10 for each grip | Not run | | | |
| 4f | Note: balls thrown without a swing | Not run | | | |
| 5a | Video; note: seconds the text shows | Not run | | | |
| 5b | Note: the plate and the throw after 60 s | Not run | | | |
| 6a | Photo of the score sheet after the game; list of the pins | Not run | | | |
| 6b | Note: balls with a matching banner of 20 | Not run | | | |
| 6c | Note: stopwatch seconds from the last ball to the menu | Not run | | | |
| 6d | Photo of the result menu with the medal; note: points | Not run | | | |
| 7a | Video of 5 balls with rails | Not run | | | |
| 7b | Photo of the result menu and of the phone | Not run | | | |
| 8a | Note: the order of the names in 2 frames | Not run | | | |
| 8b | Note: balls thrown by the phone not on turn | Not run | | | |
| 8c | Photo of a phone and the score sheet at the same moment | Not run | | | |
| 8d | Photo of the result menu with 2 phones | Not run | | | |
| 8e | Note: the longest wait in s for each player | Not run | | | |
| 9a | Photo of the phone on turn | Not run | | | |
| 9b | Photo of the phones that wait | Not run | | | |
| 9c | Photo of the phones with the result menu | Not run | | | |
| 10a | Note: seconds until the next name shows | Not run | | | |
| 10b | Photo of the "No players connected" menu | Not run | | | |
| 10c | Note: the throw after Resume (yes or no) | Not run | | | |
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

Needs: 1 to 2 phones, 1 TV with its remote, a stopwatch, a metronome app, a phone camera. Covers: REQ-TN-5 to 9 (`docs/games/tennis.md`), REQ-T4. New (2026-10-17). Tennis was built after this test (Test 25). This test checks only the
swing detector (`scripts/input/swing_detector.gd`) as Tennis uses it (`PlayerInput`) with the line that the debug overlay shows for each player. A swing is a swing back and then a swing
forward, or a sharp push in any direction with no back swing. The thresholds (`BACK_ACCEL` 4, `FWD_ACCEL` 8, `FWD_FULL` 30 m/s2, all times 0.75 for Tennis; the back swing waits 3 s; a sharp push of 20 m/s2 times 0.75 for 0.03 s; the lock after a swing is 0.6 s) are first guesses. Each step below has a fixed limit. The swing counter in the line ("swing N") is the number of swings found since the start.

**Steps**

1. Join with 1 phone. Open the debug overlay (Menu key or F3, or Settings, Debug overlay). Check: under the table there is a line with the text "P1 swing: none yet".
2a. Hold the phone in your hand like a racket handle, still, for 30 s. Check: the line still says "none yet" (0 swings).
2b. Walk around the room with the phone in your hand for 30 s. Check: the swing counter does not change (0 swings).
3a. Make a forehand: swing back, then forward, about as hard as a tennis stroke. Do 10 strokes, 2 s apart. Check: the counter rises by 9 or 10 (not more: one stroke is one swing).
3b. Make one stroke. Start the stopwatch when the line shows `swing N`. Check: the line is in the color of the player for 1 to 2 s, then it is dim.
3c. Make 10 sharp pushes of the phone with no back swing, 2 s apart. Check: the counter rises by 9 or 10.
4a. Make 5 soft, 5 medium and 5 hard strokes (2 s apart) and write down the power of each. Check: the mean power of the soft strokes is lower than the mean of the medium strokes, and the mean of the medium strokes is lower than the mean of the hard strokes, each by 0.1 or more.
4b. Move the phone slowly 10 cm to the front and back, 10 times. Check: the counter does not change.
5a. Make a **serve**: toss, swing the phone back (up) and then forward from top to bottom. Do 10 serves, 2 s apart. Check: at least 9 of 10 lines say `DOWN`.
5b. Make a forehand from left to right. Do 10 strokes, 2 s apart. Check: at most 1 of 10 lines says `DOWN`.
6a. Swing back and forward, then at once back again (the return move only). Check: the counter rises by exactly 1.
6b. Set the metronome to 120 beats a minute (0.5 s). Make a stroke on beat 1 and a stroke on beat 2. Do it 5 times, 3 s apart. Check: the counter rises by 5 or 6 (the second stroke is inside the lock of 0.6 s).
6c. Set the metronome to 60 beats a minute (1 s). Make a stroke on beat 1 and a stroke on beat 2. Do it 5 times, 3 s apart. Check: the counter rises by 10 (both strokes are found).
7a. Shake the phone a little in your hand, 10 times. Check: the counter does not change.
7b. Tap the table with the phone, 10 times. Check: the counter does not change.
8. Make 10 strokes, 2 s apart, and write down "hit N ms ago" in the line of each. Check: every value is between 0 and 550 ms (the hit window of Tennis is 0.55 s). Write down "Age ms" of the table too.
9a. Join with 2 phones. Make 10 strokes with phone 1 only. Check: the counter of P1 rises by 9 or 10, and the counter of P2 does not change. Do the same with phone 2 only.
9b. Make 10 strokes with both phones at the same time. Check: each counter rises by 9 or 10.
10a. (iPhone, if you have one) Repeat item 3a. Check: the counter rises by 9 or 10.
10b. (iPhone) Repeat items 5a and 5b. Check: at least 9 of 10 serves say `DOWN`, and at most 1 of 10 forehands says `DOWN`. (Sensor sign: Test 13 item 3.)
11a. Press RECENTER while you point at the TV. Swing a forehand to the right, 10 times, 2 s apart. Check: the `side` value is +0.3 or more in at least 8 of 10 swings. (REQ-TN-7)
11b. Swing a forehand to the left, 10 times. Check: the `side` value is -0.3 or less in at least 8 of 10 swings.
11c. Swing straight at the TV, 10 times. Check: the `side` value is between -0.2 and +0.2 in at least 8 of 10 swings.
11d. Swing nearly vertical (up and down), 10 times. Check: the `side` value is between -0.2 and +0.2 in at least 8 of 10 swings.

Measurements (write down, no pass or fail): the power of a soft, medium and hard stroke; the `side` values of each direction; the values of "hit N ms ago" and "Age ms" (the delay of the phone, Test 4). Use them to tune the thresholds of `swing_detector.gd` and `SWING_LOCK_S`.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the overlay with the text "P1 swing: none yet" | Not run | | | |
| 2a | Photo of the overlay after 30 s | Not run | | | |
| 2b | Photo of the overlay after the walk | Not run | | | |
| 3a | Note: counter before and after 10 strokes | Not run | | | |
| 3b | Note: stopwatch seconds that the line is lit | Not run | | | |
| 3c | Note: counter before and after 10 pushes | Not run | | | |
| 4a | Note: the 15 power values | Not run | | | |
| 4b | Note: counter before and after | Not run | | | |
| 5a | Note: serves with `DOWN` of 10 | Not run | | | |
| 5b | Note: forehands with `DOWN` of 10 | Not run | | | |
| 6a | Note: counter before and after | Not run | | | |
| 6b | Note: counter before and after 5 pairs at 0.5 s | Not run | | | |
| 6c | Note: counter before and after 5 pairs at 1 s | Not run | | | |
| 7a | Note: counter before and after the shakes | Not run | | | |
| 7b | Note: counter before and after the taps | Not run | | | |
| 8 | Note: the 10 values in ms and the Age ms | Not run | | | |
| 9a | Photo of the overlay with 2 phones; counters | Not run | | | |
| 9b | Note: counters of both phones | Not run | | | |
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

Needs: 1 to 4 phones, 1 TV, a stopwatch, a phone camera (240 fps for item 4g), and a child of about 5 to 8 years for items 12a to 12d. Covers: REQ-TN-* (`docs/games/tennis.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-17). It was only tested with made-up sensor values. Every number (the swing thresholds of Test 24, the hit window of 0.55 s, the green half width of 0.30, 0.21 and 0.15 s, the ball speeds, the medal tiers) is a first guess, but each step below has a fixed limit. Do Test 24 first: Tennis uses the same swing detector. Hold the phone like a racket handle, with the screen toward you. The direction of the swing sends the ball: swing toward the right of the TV and the ball goes right, toward the left and it goes left (changed 2026-10-18: the tilt did not work). The first run (2026-10-18) found swings that were not detected and shots that mostly went left for a right-handed player: check both again (items 3c, 4d, 4f and 6c to 6e). "From 3 m" means: sit or stand 3 m from the TV. Play on Medium unless the step says another difficulty.

**Steps**

1a. Open the tile of **Tennis** with 2 phones. Check: the settings view has the row Difficulty with Medium and the row Scoring with Real. Start.
1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the court, the net, a character and the ball. (Changes with issue #57.)
2a. In "3, 2, 1" look at the characters. Check: each character has a name tag above it, and the text of the tag is the name of its phone.
2b. In "3, 2, 1" look at the court. Check: you can point at all of these: the doubles sidelines, the singles sidelines, the baselines, the service lines, the net, the umpire on the chair, the ball kid at the left net post, the stands and the blank ad boards.
2c. Look at the top bar before the first point. Check: there is no leader chip.
3a. Look at the bottom of the screen at the start of the first serve. Check: the hint line reads "PRESS A TO TOSS. SWING DOWN TO SERVE! SWING TO A SIDE TO AIM.", and it is gone 16 s after "GO!" (limit: 14 to 18 s).
3b. The server presses A. Check: the ball goes up within 0.5 s. Press A on the phone of a player who does not serve. Check: nothing happens.
3c. Toss, then swing from top to bottom at the top of the toss. Do it 10 times. Check: in at least 8 of 10 tries the ball is served (it flies toward the net), and the phone buzzes once at each served ball.
3d. Toss and do not swing. Check: the ball falls 0.5 to 1.5 s after the toss, the server can toss again, no banner "FAULT" shows, and the score does not change.
3e. Toss, then swing from left to right at the top of the toss. Do it 5 times. Check: in 5 of 5 tries the ball is not served.
3f. Swing from top to bottom before you press A. Do it 5 times. Check: nothing happens in 5 of 5 tries.
4a. Look at the ball. Check: it glows when it is the turn of your team, and it does not glow when it is the turn of the other team.
4b. Look at the ring on the court as the ball comes. Check: the ring is yellow first, and it turns green. Check: it is green for the last 0.2 s before the hit (video, 60 fps or more).
4c. Look at the character of your team. Check: the character runs by itself (you do not move it), and at the hit it stands inside the ring.
4d. Swing in the green part, 10 times. Check: the ball is returned in at least 8 of 10 tries, and the phone buzzes once at each return.
4e. Swing when the ball is not near, 5 times. Check: in 5 of 5 tries the ball does not change its path, and the character swings its racket.
4f. Make a gentle back swing, then a sharp push, 5 times. Then make a slow wide swing, 5 times. Check: at least 4 of 5 hit the ball in each way.
4g. Record the phone and the TV with the camera (240 fps) for 5 hits. Count the frames from the fastest point of the swing to the contact of the racket and the ball. Check: the median delay is 150 ms or less (36 frames at 240 fps).
5a. Swing in the green part, 5 times. Check: in 5 of 5 tries the text "GREAT!" and sparks show.
5b. Swing too early, 5 times, and too late, 5 times. Check: in 10 of 10 tries the text "GREAT!" does not show, and the ball stays in play (no "OUT", no "NET" banner).
5c. Medium: count the video frames in which the ring is green for one ball. Check: the ring is green for 0.32 to 0.52 s (the green part is 0.42 s: 2 times 0.21 s).
5d. Set Difficulty to Easy, then to Hard, and do item 5c. Check: Easy is green for 0.50 to 0.70 s (0.60 s), Hard for 0.20 to 0.40 s (0.30 s).
6a. Hit 5 pairs of balls: first a soft swing, then a hard swing. Check: in at least 4 of 5 pairs the hard ball lands farther from the net than the soft ball, and its flight time is shorter (video).
6b. **Far out and far behind (REQ-TN-4).** Aim wide and long with a hard swing so the other player has to run to the side line and behind the baseline (also with 4 phones). Check: in the video, 0 frames show a character cut by the edge of the screen, and the swing of that player still returns the ball in 4 of 5 tries.
6c. Swing 30 degrees to the right of the TV, 10 times. Check: at least 8 of 10 balls land in the right half of the court (from the view of the swinging player).
6d. Swing 30 degrees to the left of the TV, 10 times. Check: at least 8 of 10 balls land in the left half of the court.
6e. Swing straight at the TV, 5 times, and nearly straight up, 5 times. Check: at least 8 of 10 balls land in the middle third of the court width.
6f. A player of the far team swings to the right of the TV, 5 times. Check: at least 4 of 5 balls land on the right side of that player (the left half of the picture).
6g. Easy: swing as hard as you can, 10 times. Check: 0 balls are out (no "OUT" banner).
6h. Give the phone to a person who has not played. Show only the hint line. Check: the person sends one ball to the left half and one ball to the right half of the court within 5 swings each.
7a. **Real scoring.** Play a whole match with 2 phones. Check: the first 4 points of a game show 0, 15, 30 and 40 on the scoreboard in this order. At 40 to 40 the line "DEUCE" shows, and after the next point "ADVANTAGE: NAME" with the right name.
7b. Check: the match ends when one team has 3 games, and the result menu shows "NAME wins!" with the name of that team.
7c. Check: the plate "NAME SERVES" shows a different server after every game.
7d. Look at the banners of 10 points. Check: "POINT: NAME", "FAULT", "OUT" and "NET" match what happened in at least 9 of 10 points.
8a. **Quick scoring.** Set Scoring to Quick and play. Check: the match ends when one team has 5 points, and the result menu shows its name.
8b. Check: the plate "NAME SERVES" shows a different server after every 2 points.
9a. Play with 3 phones (2 against 1). Take a photo of the court. Play with 4 phones and take a photo. Check: the outer sidelines are in the same place in both photos (difference 2 % of the screen width or less).
9b. Play 3 games with 3 phones. Write down the single player of each game. Check: the single player is a different player in each of the 3 games.
9c. Play with 4 phones (2 against 2). Check: the servers take turns between the teams, and inside a team the other player serves in the next service game of that team.
9d. Look at the scoreboard with 4 phones. Check: each name is equal to the name of its phone, and each color square is equal to the color of the phone (4 of 4).
9e. Look at the phones with 3 and 4 phones. Check: the place on each phone is 1 for the team in front and 2 for the other team.
10a. Play with 1 phone (the pink ball machine). Check: the machine sends the first ball within 5 s after "GO!".
10b. Return 5 balls in a row. Check: the text "RALLY N" counts 1, 2, 3, 4, 5, and "BEST N" is equal to the highest count. After a missed ball a new rally starts 1.5 to 2.5 s later.
10c. Start the stopwatch at "GO!". Check: the result menu opens 88 to 92 s later.
10d. Look at the medal. Check: it is the one of the table for the played difficulty (Easy 4, 8 and 14 hits in a row, Medium 5, 10 and 20, Hard 6, 14 and 28, no medal below the first number).
11a. Leave on one phone during a match with 4 phones. Check: the character is gone within 2 s and the match goes on with 3 players.
11b. Leave on one phone during a match with 2 phones. Check: the result menu opens within 5 s and names the other player as the winner. (The pause with the card and the ignored swing after it are checked by A-25-11.)
12a. Let a child of about 5 to 8 years play on Easy, with a grown-up next to them who does not help. Check: in "3, 2, 1" the child points at its own character within 10 s.
12b. Same child. Check: the child serves a ball in play (over the net, inside the box) within 5 tries.
12c. Same child. Check: the child returns a ball at least once in the first 3 min of a rally.
12d. After the match, ask: "Play again?". Check: the child says yes.
13. Play with 4 phones and open the debug overlay. Check: the FPS value is 55 or more for 30 s. (REQ-GM-50)
14a. **Pixel world (REQ-GM-47i to 47n).** From 3 m, a tester calls "in" or "out" at the moment of the bounce for 10 balls. Check: at least 8 of 10 calls agree with the banner ("OUT" or no banner). The ball and its shadow are visible.
14b. With 4 phones, from 3 m, each tester names the shirt color of the two far characters. Check: 2 of 2 answers are right for every tester.
14c. From 3 m, read aloud the scoreboard and one banner. Check: no error.

Measurements (write down, no pass or fail): the time of a whole match with 2 phones (the plan says about 8 minutes with 4 phones); the delay from the swing to the hit; if the green part feels too short or too long on each difficulty; every swing that went to the wrong side. Use them to tune the green half widths, the hit window and `SWING_SIDE_FULL`.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the settings view | Not run | | | |
| 1b | Photo of the tile next to a photo of the game | Not run | | | |
| 2a | Photo of the countdown with the name tags | Not run | | | |
| 2b | Photo of the court; note: the nine objects, each yes or no | Not run | | | |
| 2c | Photo of the top bar | Not run | | | |
| 3a | Video; note: seconds until the hint is gone | Not run | | | |
| 3b | Note: seconds from A to the toss; the other phone | Not run | | | |
| 3c | Video of 10 serves; note: served of 10, buzzes | Not run | | | |
| 3d | Video of a toss with no swing; note: seconds, banner, score | Not run | | | |
| 3e | Note: balls served of 5 | Not run | | | |
| 3f | Note: reactions of 5 | Not run | | | |
| 4a | Photo of a glowing ball | Not run | | | |
| 4b | Video (60 fps or more) of the ring; note: seconds green | Not run | | | |
| 4c | Video of the character at the hit | Not run | | | |
| 4d | Note: balls returned of 10; buzzes | Not run | | | |
| 4e | Video; note: balls that changed their path of 5 | Not run | | | |
| 4f | Note: hits of 5 for each way | Not run | | | |
| 4g | Video (240 fps); note: frames and ms for 5 hits | Not run | | | |
| 5a | Video; note: "GREAT!" and sparks of 5 | Not run | | | |
| 5b | Video; note: lobs in play of 10, any "GREAT!" | Not run | | | |
| 5c | Video; note: frames and seconds of the green ring | Not run | | | |
| 5d | Video; note: seconds of the green ring on Easy and Hard | Not run | | | |
| 6a | Video; note: pairs of 5 with a farther and faster hard ball | Not run | | | |
| 6b | Video of a player far out and far behind the baseline | Not run | | | |
| 6c | Note: balls in the right half of 10 | Not run | | | |
| 6d | Note: balls in the left half of 10 | Not run | | | |
| 6e | Note: balls in the middle third of 10 | Not run | | | |
| 6f | Note: balls on the right side of the far player of 5 | Not run | | | |
| 6g | Note: balls out of 10 on Easy | Not run | | | |
| 6h | Note: swings until left and right, for the person | Not run | | | |
| 7a | Photo of the scoreboard at 15, 30, 40 and deuce | Not run | | | |
| 7b | Photo of the result menu and the scoreboard | Not run | | | |
| 7c | Note: the server of each game | Not run | | | |
| 7d | Note: banners that matched of 10 | Not run | | | |
| 8a | Photo of the result menu after a Quick match | Not run | | | |
| 8b | Note: the server of each 2 points | Not run | | | |
| 9a | 2 photos of the court; note: difference in % | Not run | | | |
| 9b | Note: the single player of each of 3 games | Not run | | | |
| 9c | Note: the order of the servers | Not run | | | |
| 9d | Photo of the scoreboard with 4 phones | Not run | | | |
| 9e | Photo of the phones with the places | Not run | | | |
| 10a | Note: seconds until the first ball | Not run | | | |
| 10b | Photo of the solo screen; note: the counts | Not run | | | |
| 10c | Note: stopwatch seconds until the result menu | Not run | | | |
| 10d | Photo of the result menu with the medal; note: the longest rally | Not run | | | |
| 11a | Note: seconds until the character is gone; players left | Not run | | | |
| 11b | Photo of the result menu after the leave | Not run | | | |
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

1a. Open the tile of **Mini Golf** with 2 phones. Check: the settings view has the row Difficulty with Medium and the row Holes with "3 HOLES". Start.
1b. Put the tile next to the game screen (REQ-GM-49). Check: the tile and the game show the same four things: the lawn, the fence, a golfer and the ball. (Changes with issue #57.)
2a. In "3, 2, 1" look at the course. Check: each player has a name tag, and the text of the tag is the name of its phone.
2b. Look at the course. Check: you can point at all of these: the lawn, the fence, the clubhouse, the bushes and the walls of the hole.
2c. Look at the bar at the bottom and at the top right. Check: the bar shows one entry for each player (color square, name, number of strokes), and the top right shows "HOLE 1/3  PAR 2".
3a. Look at the course at the start of a turn. Check: it shows 1 golfer and 1 white ball (the player on turn), and no other golfer.
3b. Look at the golfer. Check: the shirt has the color of the phone of the player on turn, and the cap, the trousers and the shoes are white.
3c. Start the stopwatch when the plate "<NAME>'S TURN!" shows. Check: it shows for 1.0 to 2.0 s.
3d. Look at the phones. Check: the phone on turn shows "YOUR TURN", and the other phone shows "<NAME> IS PUTTING" with the name of the player on turn.
4a. Turn the phone 20 degrees to the right, then 20 degrees to the left (check the angle with the level app). Check: the aim mark moves to the right, then to the left, in the direction of the turn.
4b. Turn the phone 30 degrees to the left and press **RECENTER**. Check: the aim mark points straight ahead within 1 s. (REQ-MG-4, REQ-GM-37)
4c. Swing back and turn the phone 20 degrees while you hold the back swing. Check: the aim mark turns gold at the back swing and does not move more, until the ball stops.
4d. Point the phone 30 degrees to the left of the TV and hold it still until the next turn starts. Check: when the turn starts, the aim mark points straight ahead.
5a. Putt 5 times with a soft, 5 with a medium and 5 with a hard swing, and mark where the ball stops. Check: in at least 4 of 5 groups of (soft, medium, hard) the ball goes farther with each step.
5b. Look at the golfer when you putt. Check: the golfer swings back and through, and the ball starts to move at the hit.
5c. Putt 5 times. Check: the phone buzzes once at each putt.
5d. Move the phone slowly 5 cm to the front and back, 10 times. Check: no stroke is counted (the number in the bar does not change).
5e. Record the phone and the TV (240 fps) for 5 putts. Count the frames from the fastest point of the swing to the first move of the ball. Check: the median delay is 150 ms or less (36 frames at 240 fps).
6a. Play one hole with 2 phones. Check: the plate "<NAME>'S TURN!" shows the names in slot order (1, 2, 1, 2 ...) for 4 turns.
6b. Play one hole with 4 phones. Check: the plates show the names in slot order (1, 2, 3, 4, then 1 again), and at its next turn each ball starts where it stopped at its last turn.
6c. Let one player put the ball in the hole while the others play on. Check: the plates do not show the name of that player again on that hole.
7a. **Walls and rocks.** Putt at a wall and at a rock on every hole. Check: the ball changes its direction at the contact, stays on the course, and no stroke is added besides the putt.
7b. **Brick walls (holes 1, 2, 3 and 5) and the windmill block (holes 2 and 5).** Putt at each one. Check: the ball bounces at each one, and no stroke is added besides the putt.
7c. **Turning blades (holes 2, 4 and 5).** Putt at a blade, 3 times. Check: in 3 of 3 tries the ball changes its path at the blade.
7d. **Sliding barriers (holes 3 and 5).** Look at a barrier for 30 s (video). Check: at every moment there is a gap in the course. Check: the ball passes a barrier at least once in 5 putts.
7e. **Lake (holes 2 and 4).** Putt the ball into the water. Check: a splash shows, the banner "SPLASH! TRY AGAIN FROM HERE" shows, the ball is back at the place of the last putt, and the stroke count is up by 1 (the putt only).
7f. **Bridge (holes 2 and 4).** Putt the ball over the bridge, 3 times. Check: in 3 of 3 tries there is no splash.
8a. Set Holes to 5 and play 5 holes. Check: the top right shows "HOLE n/5  PAR p" for n = 1 to 5 with the pars 2, 3, 3, 3 and 4.
8b. After each hole, compare the banner and the strokes. Check: 1 stroke: "HOLE IN ONE!". Par minus 1: "BIRDIE!". Par: "PAR!". Par plus 1: "BOGEY". More: "N strokes". The banner matches the table for 5 of 5 holes.
8c. On one hole, putt away from the hole on purpose. Check: after the 6th stroke the banner "Picked up after 6 strokes" shows, and the hole counts 6 for that player.
8d. Look at the card at the end of each hole. Check: the title is "Hole N done!", and the total after hole n is the sum of the strokes of holes 1 to n (5 of 5 holes, count by hand).
8e. Press A on the card. Check: the next hole starts within 2 s.
8f. Count the strokes of one player by hand for a hole. Check: the number in the bar is the same after every putt.
9a. Play the first hole on Easy, then on Medium, then on Hard. Take a photo of the aim at the start of each. Check: Easy has a line that is at least 2 times as long as the line of Medium. Hard has no line, only a small marker on the ground.
9b. After the aim is locked, look at the screen on each difficulty. Check: on Easy the text "SWING FORWARD. A BIGGER SWING GOES FARTHER!" shows. On Medium and Hard it does not show.
9c. Make 5 of the weakest swings that still putt, on Easy and on Medium. Check: the mean distance of the ball on Easy is at least 2 times the mean distance on Medium.
9d. Look at the photos of hole 1 on the 3 difficulties. Check: the walls, the rocks and the cup are in the same places.
10a. Finish a match with 2 phones. Check: the result menu names the player with the fewest strokes as "<NAME> wins!" (or "Tie!" when the strokes are equal), and the list is in the order of the strokes.
10b. Finish a 3 hole match alone. Check: the medal is the one of the rule (gold at 8 strokes or fewer, silver at 11 or fewer, bronze at 14 or fewer, no medal above 14).
10c. Choose Try again. Check: hole 1 starts again, with 0 strokes for every player.
10d. Choose New game, then Back to menu (on the next result menu). Check: New game opens the settings view, and Back to menu opens the Games screen.
11a. Play with 4 phones. Leave the game on one phone during a hole. Check: the plate shows the name of the next player within 3 s, and the name of the leaver is not used again.
11b. Play with 2 phones. Leave the game on one phone. Check: the other player goes on with the turns until the hole is done.
11c. Pause the game from the TV (OK) after the back swing, then choose Resume. Check: a full swing within 10 s after Resume putts the ball. (The pause with the card is checked by A-26-11.)
12a. Let a child of about 5 to 8 years play on Easy, with a grown-up next to them who does not help. Check: in "3, 2, 1" the child points at its own name tag within 10 s.
12b. Same child. Check: the child turns the phone and the aim mark moves to the left side within 30 s after the first plate "<NAME>'S TURN!", with no help.
12c. Same child. Check: the child putts the ball (one stroke counted) within 60 s after the first plate, with no help.
12d. After the match, ask: "Play again?". Check: the child says yes.
13. Play with 4 phones and open the debug overlay. Check: the FPS value is 55 or more for 30 s. (REQ-GM-50)
14a. **Pixel world (REQ-GM-47i to 47n).** From 3 m, a tester points at the ball each time you say "mark" while it rolls on the farthest hole. Check: the finger points at the ball in 5 of 5 tries.
14b. From 3 m, ask a tester to point at the golfer and then at the windmill. Check: both answers are right for every tester.
14c. From 3 m, read aloud the names and strokes in the bar and one banner. Check: no error.

Measurements (write down, no pass or fail): the turn angle that moves the aim mark from the middle to the side end; the delay from the swing to the ball moving; if a normal putt goes too far or too short; any hole that you find too hard or too easy; the time of a 3 hole match. Use them to tune the aim range, the putt speeds and the hole designs.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1a | Photo of the settings view | Not run | | | |
| 1b | Photo of the tile next to a photo of the game | Not run | | | |
| 2a | Photo of the countdown with the name tags | Not run | | | |
| 2b | Photo of the course; note: the five objects, each yes or no | Not run | | | |
| 2c | Photo of the bar and of the top right | Not run | | | |
| 3a | Photo of the TV at the start of a turn | Not run | | | |
| 3b | Photo of the golfer next to the phone color | Not run | | | |
| 3c | Note: stopwatch seconds of the plate | Not run | | | |
| 3d | Photo of both phones | Not run | | | |
| 4a | Video of the turn to both sides | Not run | | | |
| 4b | Video of RECENTER; note: seconds until the mark is straight | Not run | | | |
| 4c | Photo of the gold mark; note: did it move (yes or no) | Not run | | | |
| 4d | Photo of the aim mark at the start of the turn | Not run | | | |
| 5a | Note: distances of the 15 putts | Not run | | | |
| 5b | Video of a putt | Not run | | | |
| 5c | Note: buzzes in 5 putts (yes or no for each) | Not run | | | |
| 5d | Note: strokes counted by the small moves | Not run | | | |
| 5e | Video (240 fps); note: frames and ms for 5 putts | Not run | | | |
| 6a | Note: the names in the order of the 4 turns | Not run | | | |
| 6b | Note: the order of the names; photo of a ball at its next turn | Not run | | | |
| 6c | Note: names on the plates after the hole-in | Not run | | | |
| 7a | Video of a wall bounce and a rock bounce | Not run | | | |
| 7b | Video of a brick wall and the windmill block | Not run | | | |
| 7c | Video of 3 blade contacts | Not run | | | |
| 7d | Video of 30 s of a barrier; note: ball passed (yes or no) | Not run | | | |
| 7e | Video of the splash; note: strokes before and after | Not run | | | |
| 7f | Video of 3 bridge crossings | Not run | | | |
| 8a | Photo of the top right on each hole | Not run | | | |
| 8b | Note: table of hole, strokes, banner | Not run | | | |
| 8c | Photo of the banner "Picked up after 6 strokes" | Not run | | | |
| 8d | Photo of each card; note: the sums | Not run | | | |
| 8e | Note: seconds from A to the next hole | Not run | | | |
| 8f | Note: strokes counted by hand and in the bar | Not run | | | |
| 9a | 3 photos of the aim, one for each difficulty | Not run | | | |
| 9b | 3 photos after the lock, one for each difficulty | Not run | | | |
| 9c | Note: distances of 10 weakest putts | Not run | | | |
| 9d | 3 photos of hole 1 | Not run | | | |
| 10a | Photo of the result menu with 2 phones | Not run | | | |
| 10b | Photo of the result menu with the medal; note: strokes | Not run | | | |
| 10c | Note: hole and strokes after Try again | Not run | | | |
| 10d | Note: the screen after New game and after Back to menu | Not run | | | |
| 11a | Note: seconds until the next name; names after the leave | Not run | | | |
| 11b | Note: turns of the other player | Not run | | | |
| 11c | Note: the putt after Resume (yes or no) | Not run | | | |
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

