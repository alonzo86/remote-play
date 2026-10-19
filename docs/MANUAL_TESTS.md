# Manual tests

The tests that only a person with real devices can do: phones, a TV or a TV box, a remote control, a camera.
This file holds **all** of them: the steps, the result of every step, and the evidence. The headless tests (`tests/`, listed in `docs/AUTOMATED_TESTS.md`) do not replace them; a step that a headless test covers fully was moved there.
Style: ASD-STE100 Simplified Technical English. It replaces `docs/MANUAL_TESTS.md` (that file now points here). Test numbers do not change.

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

Needs: 1 phone, 1 TV. Covers: REQ-A3, REQ-A4, REQ-FL-5 to 10, REQ-FL-80, 83, 84.


**Steps**

1. Start the TV app. Check: the app is named **Sababi: TV Games** in the launcher (uninstall the old apps first: the package names changed, FD-26 and FD-27; the list is in `README.md`). The Android splash shows the pixel mascot (a yellow face with sunglasses) on black. At the very first start the logo screen waits for the language choice: choose ENGLISH with OK (Test 17 checks the language). From the second start the logo screen shows the mascot and the word SABABI (sharp pixels, not blurred) with an animation for about 2.5 seconds, then the **PLAYERS** screen with a QR code, the room code, the join PIN and 4 slots. If the QR code is empty, the TV has no Wi-Fi address (the screen says so).
2. Start the controller app on one phone. Check: it is named **Sababi: Remote**, and the phone shows a **portrait** screen with the title SABABI.
3. Tap the TV in the list **ROOMS FOUND**. Check: the phone shows the PIN pad ("TYPE THE PIN THAT IS SHOWN ON THE TV"). Type the 4 digits of the PIN. Check: the phone shows "WAITING FOR THE HOST" with a colored square with the number 1, the TV shows the phone in slot 1 as "READY", and the line **Press OK to continue** shows at the bottom (there is no Continue button and no player count). Press OK. Check: the TV shows the Games screen and the phone says "Choose a game on the TV".
4. Tap **Disconnect** (top right), then look at **ROOMS FOUND**. Check: the TV shows as a white button "<code> x/y", for example "KQZM 0/4" (a room with no player). Tap it and type the PIN. Check: it joins. Tap **Disconnect** and then **Refresh** (white). Check: the list shows "Searching..." and the TV is back within 2 seconds. New (REQ-FL-83): with the TV app on a Mac, where the list stays empty, tap Refresh and check that the TV shows up in the list within about 15 seconds (the scan; it never starts by itself). If the Mac asks for the Local Network permission, answer with the app that runs the TV; the scan works without it.
5. (Removed. There is no join by IP address, REQ-A4. The join by QR code is Test 2, the PIN rules are Test 21.)
6. New (REQ-FL-80). Tap **Disconnect**. Close the controller app and start it again. Check: the Android splash (the mascot on black) is already in portrait (the phone does not turn), and it is the only splash: the Connect screen follows at once, with no logo screen. "ROOMS FOUND" and **Refresh** are white. Then join, close the app without **Disconnect** and start it again. Check: the phone joins the same TV again by itself (REQ-N6).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the TV (splash, logo, Connect screen) and the phone (portrait) | Not run | | | |
| 2 | Photo of the phone in portrait | Not run | | | |
| 3 | Photo of TV and phone together: slot 1 'READY' and the line 'PRESS OK TO CONTINUE'; then the Games screen | Retest | R1 | Chat report 2026-10-09 (no file) | R1: the owner found the Continue button redundant (it was the only focus target) and the count of players repeated the slot list. Changed on 2026-10-09 (FD-17, REQ-FL-6, 7): the button and the count are gone, and 'PRESS OK TO CONTINUE' shows once a phone has joined. The old check cannot pass any more. Retest the new screen. |
| 4 | Photo of the phone list with the button '<code> x/y'; note the time Refresh takes | Not run | | | |
| 5 | (Removed with the join by IP address) | Not run | | | |
| 6 | Video of the app start in portrait: splash, then the Connect screen | Not run | | | |

History:

- R1: **Retest** (step 3). Design change after the first run on a real Android TV. See the row of step 3.
- R0: **Fail**. Join by room code failed with 'Room YCNW not found, is the tv on the same wi-fi?'. The list and the IP worked. TV app on a desktop, phone on the same Wi-Fi. The plan has no join by room code now, so every step needs a retest.

## Test 2

### QR scan (plugin, unverified)

Needs: 1 phone, 1 TV. Covers: RISKS C5.


**Steps**

1. Tap **Disconnect**. On the connect screen, the button must say **Scan QR code**. If it says **Paste room link**, the plugin is not in the build. Run `tools/patch_android_manifest.sh controller` and export the controller again.
2. Tap the button and scan the QR code on the TV. Check: the phone joins in less than 5 seconds and the PIN pad does not open (the QR code holds the PIN).
3. Scan again and press Back in the scanner. Check: no error message and the app does not crash.
4. Optional: put a different QR code in front of the phone (for example a web link). Check: the message "This is not a Sababi code".

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Phone screenshot of the connect screen: the button text | Not run | | | |
| 2 | Screen recording of the scan, with the seconds to join | Not run | | | |
| 3 | Note: no error, no crash. `adb logcat -s godot` if it crashes | Not run | | | |
| 4 | Phone screenshot of the message | Not run | | | |

History:

- R0: **Pass**.

## Test 3

### Sensor directions

Needs: 1 phone, 1 TV. Covers: RISKS A2.

Open the debug overlay on the TV (Menu key or F3, or OPTIONS, SETTINGS, DEBUG OVERLAY). Hold the phone in portrait with the screen toward you.

| Action | Expected raw values / result |
|--------|------------------------------|
| Phone flat, screen up, still | `Accel` about `0 0 +9.8` |
| Right side down | `Accel x` negative. In the maze, the ball rolls right |
| Top of phone up | `Accel y` positive. In the maze, the ball rolls toward you (down on the TV) |
| Turn the phone to the left (like turning on a table) | `Gyro z` positive (raw value only. No game uses the yaw now) |

If a direction is wrong, use the **Invert axes** row on the **Settings** screen of the TV (the OPTIONS button on the Games screen). Write down which one you needed.


**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Overlay screenshot: Accel about 0 0 +9.8 (flat, still) | Retest | R0 | | Before the fix the phone reported z = -9.83. The fix is in `sensor_sampler.gd`. The value after the fix was not written down. |
| 2 | Overlay screenshot: Accel x negative; video of the ball rolling right | Pass | R0 | | R0: after the fix the tilt directions in the maze are right. |
| 3 | Overlay screenshot: Accel y positive; video of the ball rolling toward you | Pass | R0 | | R0: after the fix the tilt directions in the maze are right. |
| 4 | Overlay screenshot: Gyro z positive when you turn the phone to the left | Retest | R0 | | R0: the gyro rows were not checked again after the fix. |

History:

- R0: **Pass**. The phone reported every accelerometer axis inverted (flat, screen up: z = -9.83). Fixed in `sensor_sampler.gd`. No invert switch is needed. After the fix: the tilt directions in the maze are right. The gyro rows were not checked again, so Test 3 needs a retest of items 1 and 4.

## Test 4

### Latency and packet rate

Needs: 1 to 4 phones, 1 TV, a phone camera (240 fps). Covers: RISKS A3, B1, B2, B3, B5, B6.

Open the overlay (Menu key or F3). Write down if the TV is on Ethernet or Wi-Fi, and if the game mode of the TV is on or off. Keep the phone still for 30 seconds, then move it for 30 seconds. Then play a Treasure Maze round with 4 phones and read Rx Hz and Gap ms of all four rows.

| Value | Good | Acceptable | Problem |
|-------|------|------------|---------|
| RTT ms | below 20 | below 40 | above 60 |
| Rx Hz | 58 to 60 | 50 to 58 | below 50 |
| Gap ms (longest gap in 1 s) | below 40 | below 80 | above 100 |
| Lost | 0 | 0 | any (gaps in the sequence number) |

Also do this: record the TV and the phone with a phone camera in slow motion (240 fps) and count the frames
between a quick phone movement and the ball movement in the maze. This shows the whole delay, including the TV display.
A total below 100 ms feels good. Above 150 ms feels slow.


**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| RTT ms (good below 20, acceptable below 40, problem above 60) | Overlay screenshot at 30 s still and 30 s moving | Fail | R0 | | R0: above 60 ms (exact value not written down). TV app on a desktop, not a TV box. |
| Rx Hz (good 58 to 60, acceptable 50 to 58, problem below 50) | Same screenshots | Retest | R0 | | R0: 'above 55' (exact value not written down). Desktop TV. |
| Gap ms (longest gap in 1 s; good below 40, acceptable below 80, problem above 100) | Same screenshots | Fail | R0 | | R0: 150 to 380 ms. Desktop TV. |
| Lost (good 0) | Same screenshots | Pass | R0 | | R0: 0. |
| Total delay with a camera (below 100 ms good, above 150 ms slow) | Slow motion video (240 fps) with the frame count | Not run |  | | Not tested in R0. |

History:

- R0: **Fail**. RTT above 60 ms, Rx Hz above 55, Gap 150 to 380 ms, Lost 0. TV app on a desktop (not a TV box), phone on the same Wi-Fi: not yet representative of a real TV. The total delay (camera) was not tested.

## Test 6

### Treasure Maze feel

Needs: 1 to 4 phones, 1 TV. Covers: REQ-MZ-4, REQ-MZ-6, REQ-MZ-7, REQ-MZ-8, REQ-MZ-9, REQ-MZ-12, REQ-MZ-13, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-90 to 95.


**Steps**

1. Start **Treasure Maze** with 1 phone. Hold the phone level in the countdown.
2. Finish the maze. Write down: does the ball feel too light, too heavy, or good? Is the deadzone good (the ball does not creep when the phone is level)?
3. Tune the constants in `scripts/game/maze/maze_game.gd` (`TILT_ACCEL`, `FRICTION`, `DEADZONE`) if needed.
4. Repeat with 2 to 4 phones. Check *Rx Hz* and *Gap ms* for all players during the race.
5. Tilt the phone, then tap **RECENTER**. Check: the ball stops creeping. Tap **A** and **B**. Check: nothing changes (A and B do not recenter, REQ-MZ-8). At GO the phone recenters by itself.
6. Open the tile of **Treasure Maze**. Check: the settings view opens with Difficulty on Medium, and Back (left) and Start (right) are on one line at the bottom. With the remote, press Left and Right on the Difficulty row (it must stop at Easy and at Hard). Play one round on each of Easy, Medium and Hard. Check: Easy is a small maze, Hard is big and winding, the whole board is on the screen, and the ball does not feel stuck in the narrow corridors of Hard. After the round, the result menu has **New game**, and it returns to the view with the last choice. In the view, the Theme row shows GARDEN first; Right shows CASTLE, then ICE (it stops at the ends). In the view, press Back on the remote: it returns to the Games screen (the app does not close). With the only phone connected, switch its Wi-Fi off while the view is open: after about 5 seconds Start is dimmed and a yellow line says "NO PLAYERS CONNECTED". Switch Wi-Fi on again: Start works again.
7. **Pixel world (phase 4, REQ-MZ-7).** From the sofa (about 3 m), look at the maze on Medium and Hard. Check: the walls, the balls and the chest are sharp square pixels, the stone walls are easy to see on the checkered floor, the balls with their eyes are easy to tell apart by color, the torch flames and the sparkle of the chest change in a hard step, and the title does not touch the timer. **Looks of 2026-10-15 (Treasure Maze, REQ-MZ-7, REQ-MZ-12):** in the settings view (the Theme row starts on Garden), pick Garden, Castle and Ice in turn and play a round of each: the Theme row works with the remote, the balls and the chest look the same in all three, the player colors are easy to tell apart on the green lawn, and the hedges, stone and ice walls are easy to see. Each theme has two small pictures on each side of the maze (Garden: tree, rose bush; Castle: torch, shield; Ice: penguin, iceberg): from the sofa, can you tell what they are, and are they big enough? When a ball reaches the chest, the lid opens and the gold shows. A child of 5 to 8 years: is the chest easy to find as the goal? The title and its Hebrew text (מבוך האוצר) need the owner's check. **Thick walls (2026-10-15):** the walls are 28 px now (before: 12 px) and the ball is 36 px (before: 48 px). Easy is 13 x 6, Medium 16 x 8 and Hard 18 x 9 cells (before: 11 x 6, 17 x 9 and 21 x 11). The maze fills the screen (a margin of at least 60 px at the left, right and bottom). The balls have a white ring and the garden lawn is bright: check that the red and teal balls are easy to see on it. Check: the hedges, stone and ice are thick and easy to see, the ball does not feel stuck in the corridors of Hard (68 px wide), and the ball is not too small from the sofa.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Note: the phone is level in the countdown | Pass | R1 | Chat report 2026-10-09 (no file) | R1: the owner played the maze and reported 'it works perfectly'. The steps of the countdown were not reported one by one. |
| 2 | Note: ball too light, too heavy or good; deadzone good or not. Short video | Pass | R1 | Chat report 2026-10-09 (no file) | R1: 'i tested the maze game and it works perfectly'. The feel is good on the TV. The number of phones was not written down (step 4 is still open). |
| 3 | If constants changed: the commit or the diff | N/A | R1 | Chat report 2026-10-09 (no file) | R1: no tuning is needed, because the owner reported no problem. The constants are unchanged. |
| 4 | Screenshot of the debug overlay for every player during the race | Not run | | | |
| 5 | Video of the ball: creeping, then RECENTER, then A and B | Not run | | | |
| 6 | Photos of the settings view and of the maze on Easy, Medium and Hard; note on the sizes and the corridors | Not run | | | Added 2026-10-09 (REQ-MZ-9). The sizes in `LEVELS` are first guesses. |
| 7 | Photo of the maze from the sofa; note: sharp pixels, walls easy to see, the ball in the corridors of Hard | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-15 (Treasure Maze). |

History:

- 2026-10-10 (not run): item 7 is new: the maze world is a pixel world (phase 4 of the arcade style), walls 12 px, Hard cells 76 px.
- 2026-10-09 (not run): item 6 is new (REQ-MZ-9, REQ-GM-90 to 97): the settings view, the three difficulties, the yellow chosen value, Back and Start on one line, and Start dimmed when no phone fits.
- R1: items 1 to 3 **Pass** (the owner: 'it works perfectly'). Items 4 and 5 are not run: 2 to 4 phones, and RECENTER with A and B.
- R0: **Retest**. First run: drift and inverted controls (caused by 'Invert axes' being on). After the fix the maze looks good on the desk. The feel and the constants were not judged. Item 5 is new (RECENTER, and A and B do nothing).

## Test 7

### Disconnect and reconnect

Needs: 2 phones, 1 TV. Covers: REQ-GM-30, REQ-GM-30a, REQ-T5, REQ-N5, REQ-N6, REQ-FL-25, REQ-FL-52, REQ-MR-14, REQ-MZ-8.


**Steps**

1. With two phones joined, during the maze, switch one phone Wi-Fi off for 15 seconds, then on. Check: within about 5 seconds the TV pauses and shows the card "2P LOST CONNECTION" with **Resume without 2P** and **End game**, and the phone shows "Reconnecting...". When the phone is back, the card says "2P reconnected" with **Resume**. The game goes on only when you press **Resume**.
2. Lock the phone screen for 10 seconds, then unlock. Check: the phone reconnects. (Android can stop the app in the background.)
3. On the Games screen (not in a game), switch the phone Wi-Fi off for 45 seconds. Check: the slot is freed (the TV shows it empty). When the Wi-Fi is back, the phone shows the PIN pad (the TV does not know it any more). Type the PIN: the phone joins again (maybe in a different slot).
4. Switch one phone Wi-Fi off again and wait for the card. Choose **Resume without 2P** (for a player with a profile the card says its name, test 20 item 6). Check: the game continues without that player. Switch the Wi-Fi on. Check: the phone shows the PIN pad; after the PIN it joins again as a new player and shows "YOU JOIN NEXT ROUND.".
5. With only one phone joined, switch its Wi-Fi off during the maze. Check: within about 5 seconds the game pauses with the card "1P LOST CONNECTION" that has only **End game** (no Resume, because nobody is connected). Switch the Wi-Fi on. Check: the card says "1P reconnected" and offers **Resume**. Do the same in Road Rally and in Banana Party. Press Back on the card. Check: it asks "End the game?".
6. On the phone pad, tap **Disconnect** once. Check: the phone leaves the TV at once (no second tap). The word fits the box. Check the pad buttons: A is green and B is red, both sink when pressed.
7. Phone call: with one phone in a game, call that phone from another phone and answer. Check: the game pauses with the card. End the call and go back to the controller app. Check: the phone says "Reconnecting..." and then joins again, the card says "1P reconnected" with **Resume**, and **Resume** goes on with the game. Try a call that lasts more than 1 minute (the slot is kept 5 minutes while the game is paused). Write down how long the phone needs to reconnect after the call. (REQ-GM-30, 30a)

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Video of TV and phone: the card, 'Reconnecting...', then Resume | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the phone disconnected from the Wi-Fi and showed 'Reconnecting...', but on the TV the game kept going (no pause, no card). The off time was not written down (it must be more than 5 s). Cause (found on 2026-10-09): the TV waited for a close handshake that a phone with no Wi-Fi cannot answer, so it never marked the phone lost. The same failure was seen in R0. Fixed on 2026-10-09 (a silent phone is lost at once, PROTOCOL.md) and the pause changed (REQ-GM-30). A test now reproduces it. Retest. |
| 2 | Note: did the phone reconnect | Not run | | | |
| 3 | Photo of the Connect or Games screen after 40 s and after the join again | Not run | | | |
| 4 | Video: Resume without P2 with a lost phone, and the phone that joins again | Not run | | | |
| 5 | Photo of the card of the only player lost (End game only), and of the card after the return (Resume); in the maze, the race and Banana Party | Retest | R1 | Chat report 2026-10-09 (no file) | R1: a phone call stopped the game ('as expected') and the TV showed 'No players connected'. After the call there was no way to resume. The owner asked for a message that says which player disconnected, with Resume only when a player is still connected or the disconnected player is back. Changed on 2026-10-09 (REQ-GM-30, 30a): the game waits with a card, there is no Resume while nobody is connected, and Resume shows when the phone is back. The slot is kept 5 minutes while paused. The old check ('No players connected' at once) is gone. Retest. |
| 6 | Photo of the Disconnect button on the pad (and on the waiting screen, at the top right), and of the pad buttons | Not run | | | |
| 7 | Video of a phone call: the card, the return, Resume. Note how long the phone needs to reconnect | Not run | | | |

History:

- R1: **Fail** (item 1) and **Retest** (item 5). A phone without Wi-Fi did not pause the game, and a phone call ended it with no way to resume. Both changed on 2026-10-09 and wait for the retest. Items 2, 3, 4 and 6 are not run.
- R0: **Retest**. Wi-Fi off on the phone: the phone shows 'Reconnecting...'. The game kept running and the TV never showed 'Waiting for P1 to reconnect'. Wi-Fi on: the phone reconnected and the game went on. The off time was not measured (the TV pauses only after 5 s of silence). Item 6 (Leave twice, A green and B red) is new.

## Test 8

### TV remote

Needs: 1 phone, 1 TV with its remote. Covers: REQ-GM-31, REQ-GM-31a, REQ-GM-33, REQ-FL-41, REQ-FL-55.


**Steps**

1. Use only the remote. Check that the D-pad moves the focus on every screen (tiles, players badge, OPTIONS, menu items) and OK selects. A focused menu item is yellow with a pixel cursor in front of it (red for END GAME, QUIT and REMOVE). A focused game tile has a yellow frame, and the description of the game shows in the bar under the grid (REQ-FL-12, 13, 41). Check that the focus is easy to see from the sofa on every item, also in Settings.
2. In a game, press OK. Check: the pause menu opens with Resume, Try again, and Back to menu. Choose Back to menu, and also press Back during play. Check: both ask "End the game?" with **Resume play** (in focus, yellow) and **End game** (red when it has the focus). The game is paused. Back on the question keeps playing. **End game** goes to the Games screen. After the game is over (result menu), Back leaves at once.
3. Press Back in a game and choose **End game**: back to the Games screen. Press Back on the Games screen: the Connect screen (the players stay). Press Back on the Connect screen: the quit question opens, with **Stay** in focus.
4. Check the Menu key. If the remote has no Menu key, open **Settings** (the OPTIONS button on the Games screen) and use **Debug overlay**.
5. Check: the app icon and banner show in the Android TV home row, with the name Sababi: TV Games (the icon is the Sababi mascot on black, the banner is the mascot and the word SABABI).
6. On the phone, press the Android Back key on the waiting screen (joined, the TV on the Games screen) and in the middle of a game (the pad screen). Check: both open the question "QUIT SABABI?" with **Stay** in focus, and the app does not close by itself. Back again chooses Stay. During a game, the pad does not react to touches while the question shows. **Quit** closes the app (REQ-FL-55).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Video of the remote moving the focus on every screen, with the focus border visible | Not run | | | |
| 2 | Video of the pause menu and the 'End the game?' question | Fail | R1 | Chat report 2026-10-09 (no file) | R1: pressing Back on the remote in the middle of a game quits the app completely. The 'End the game?' question was not seen. Cause: the engine setting `quit_on_go_back` was on, so the engine quit after the app had handled Back. Fixed on 2026-10-09 (REQ-FL-55). Retest. The OK key and the pause menu were not reported. |
| 3 | Video or photos of Back on the Games, Connect screens and the quit question | Fail | R1 | Chat report 2026-10-09 (no file) | R1: Back quits the app on every screen. The owner saw the app go back to the previous view for a moment before it closed. Same cause and fix as item 2. Retest. |
| 4 | Photo of the overlay after the Menu key, or of the Settings switch | Not run | | | |
| 5 | Photo of the TV home row with the icon and banner | Not run | | | |
| 6 | Video of Back on the phone waiting screen and pad screen | Not run | | | The question and its answers are tested without a phone (`ui_states`); only the real Back key is open. |

History:

- R1: **Fail** (items 2 and 3). Back quits the app on every screen. Fixed on 2026-10-09 (REQ-FL-55). Items 1, 4 and 5 are not run.
- Item 2 changed before the first run (the 'End the game?' question).

## Test 8b

### The TV flow and the style

Needs: 1 to 2 phones, 1 TV. Covers: REQ-FL-1 to 46, REQ-FL-56, 57, REQ-FL-81, FD-1 to 17, FD-23. Item 7 (a TV set to Hebrew) moved to Test 17 on 2026-10-10: FD-19 replaced REQ-FL-54, so the TV now offers Hebrew and no longer stays English.


**Steps**

1. Start the TV app from cold (not the first start: at the first start the logo waits for the language choice). Check: the logo screen goes on by itself after about 2.5 seconds, and OK skips it. Back on the logo screen does not quit.
2. On the Games screen, with one phone joined, check that every tile shows its screenshot, title and player range, and that the text is readable from the sofa (REQ-FL-40).
3. Open the **players badge** (OK). Check: the modal shows the slots, a QR code, the room code and the PIN. Press **Remove** on a player. Check: the phone says that the host removed it and does not reconnect by itself. Join again with the QR code. Check: the slot fills again.
4. Join a phone while a game runs. Check: the phone (it needs the PIN from the list, or it scans the QR code) says "A ROUND IS IN PROGRESS" and "YOU JOIN NEXT ROUND.", it does not take part, and it joins the next round.
5. Check the motion on the TV box: the logo (with its confetti), the blinking prompts and the screen changes run at 60 frames per second (overlay FPS). Check that the arcade colors look right on your TV (black is black, yellow and blue are not washed out).
6. Phone: check that the fonts and the colors match the TV on the connect, waiting and pad screens.
7. (Moved to Test 17.) The old step was: set the TV to Hebrew, region Israel, and check that the app stays English and left to right. FD-19 replaced that rule on 2026-10-10: the app now has Hebrew, and the result of R1 (the mirrored English UI) is not a defect any more.
8. New. On the Games screen with the remote: from a tile press Up, then Left or Right, and reach **OPTIONS** (write down the keys you needed; if it is not reachable, say where the focus goes). Open the players badge and press all four arrow keys. Check: the focus stays on the buttons of the modal and never moves to a game tile under it. In Hebrew, check that the yellow cursor of the focused tile does not touch its title.
9. New (REQ-FL-81). Check the title of three cards in English and in Hebrew: "NO PLAYERS CONNECTED" (in a game with one phone, tap **Disconnect** on the phone and wait until the slot is freed), "PAUSED" (OK in a game) and "END THE GAME?" (Back in a game). Check: the title is white, the items below are yellow only with the focus, and the Hebrew title is on one line.
10. New (2026-10-11). Settings: press Down through all rows with the remote. Check: the focused row is always in view and Back stays visible at the bottom. Games screen: only the focused tile has its title moved in (the cursor does not touch the text, also in Hebrew). A game in Hebrew with a leader: the timer box and the leader chip are at opposite sides and do not overlap (Road Rally too). The result menu: the time says ש׳ in Hebrew, each row has the avatar next to the colour, and the buttons are TRY AGAIN, NEW GAME and BACK TO MENU. On the phone, the avatar is beside the colour square on the waiting screen and on the pad. The result menu shows a medal next to the name of each player: 1st gold, 2nd silver, 3rd bronze (a tie has the same medal), none after the 3rd; a solo round shows the medal of the score next to the name, and the difficulty as the title. Games screen: scroll down to the second row of games, move up to the first row and on to the players badge, then to OPTIONS: it must always be reachable (also in Hebrew).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Video from cold start: logo, then Connect | Not run | | | |
| 2 | Photo of the Games screen with all tiles | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the screenshots of the games are missing on the Games screen of the Android 10 TV. What the tiles showed instead (dark boxes, colors) was not written down. The same tiles show on a desktop with the OpenGL renderer. The cause is not confirmed. Changed on 2026-10-09 (REQ-FL-56, 57): the image is rounded in the file and not clipped, a placeholder shows when a tile does not load, and a warning goes to the log. Retest. If they are still missing, save `adb logcat -d -s godot` and look for 'Tile image'. |
| 3 | Photos of the Players modal; of the phone after Remove; of the slot after the join again | Not run | | | |
| 4 | Photo of the phone 'A round is running' | Not run | | | |
| 5 | Overlay FPS screenshot during the logo, tile growth and screen changes; photo of the colors | Not run | | | |
| 6 | Photos of the phone connect, waiting and pad screens next to the TV | Not run | | | |
| 7 | (Moved to Test 17.) Photos of the Connect and Games screens on a TV set to Hebrew; of the phone set to Hebrew | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the TV is set to the IL region and Hebrew. The text was English, but the layout was mirrored (right to left). Fixed on 2026-10-09 (REQ-FL-54): the app sets the locale to English and the layout to left to right. Retest on the TV. The phone was not tried. |
| 8 | Video of the arrow keys to OPTIONS and in the Players modal; photo of a focused tile in Hebrew | Not run | | | |
| 9 | Photos of the messages in English and Hebrew | Not run | | | |
| 10 | Photos of Settings scrolled, a focused tile in Hebrew, the HUD of Road Rally in Hebrew, the result menu, the phone header | Not run | | | |

History:

- R1: **Fail** (items 2 and 7). The tile screenshots are missing, and the layout is mirrored on a TV set to Hebrew. Both changed on 2026-10-09 and wait for the retest. The other items are not run.

## Test 9

### Road Rally (car race before 2026-10-15)

Needs: 1 to 4 phones (2 to 4 for items 5, 7 and 11), 1 TV. Covers: REQ-MR-*, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Needs 1 to 4 phones (one phone is a time trial). Requirements: `docs/games/marble_race.md`. Start "Road Rally" and pick a track.


**Steps**

1. Check: the TV shows the track from above, a black bar at the top with the title, the timer, "Finish in N m" and the leader chip (the first car, or TIE), and the track name at the bottom right. All text is inside the screen edge and can be read from the sofa. (REQ-MR-9, REQ-MR-10, REQ-MR-35, REQ-MR-40). The top shows only the leader, not the order of all cars; the places 1st to 4th show in the result menu (item 9 of Test 11, A-11-3).
2. Check: during "3, 2, 1" the cars do not move when you tilt. At "GO!" every phone buzzes. (REQ-MR-3)
3. Tilt right: the car goes right on the screen. Tilt the top of the phone up: the car goes down on the screen. (REQ-MR-40, REQ-3D-6)
4. Check the feel. Write down if the car is too slow, too fast, or too nervous. (`ACCEL`, `DAMPING`)
5. Hit a wall, an obstacle and another car at speed. Check: the phone buzzes, with at least 150 ms between two buzzes (about 6 a second at most). (REQ-MR-13)
6. Check: the frame rate in the debug overlay is 60 (or close) with 4 phones on Hard. (REQ-GM-50)
7. Let one car run far ahead on a long track (Hard). Check: when the last car leaves the view, an arrow in its color shows at the screen edge with a distance, and you can read it. (REQ-MR-42)
8. Finish a race on 3 different tracks of the list and on the random track. Write down the winning time of each. (REQ-MR-51)
9. Open the tile of **Road Rally**. Check: the settings view shows Difficulty (Left and Right), the Theme row and, under them, a carousel of tracks (10 line sketches and a "?", no names), wider than the Difficulty row, with the selected track in the middle (Track 1 the first time). Move the carousel with Left and Right (the track in the middle is the one you get), then Start. Check: the race has the track of the sketch. Play Easy, Medium and Hard on one track. Check: the line is the same and there are few, some and many obstacles. Choose the "?" tile twice: the tracks are different. Try again: the same track again. After the race the result menu has Try again, New game and Back to menu. (REQ-MR-50 to 54)
11. After a change to the shared game code (the countdown clock, the buzz cool-down, the end with no players), run this test again with 2 phones on each track. Check: the countdown, the buzz at GO, the buzz limit (item 5), a player who leaves (the race goes on) and the last player who leaves (the menu "No players connected") all work as before. Tap **RECENTER** during a race: the car stops drifting. With 1 phone, start a race: it is a time trial. Finish it: the result menu shows the time and a medal row.
12. **Pixel world (REQ-MR-44, REQ-GM-47i to 47n).** From the sofa (about 3 m), look at the race in each theme. Check: the road, the walls, the obstacles and the cars are made of sharp square pixels (not blurred), each car has a black outline and is easy to tell from the road and from the obstacles, and the finish line is a clear black and white band. Let one car run far ahead: the small car stays readable and the edge arrow (item 7) shows. Check the frame rate and that the race starts at once (the road picture is made in the first frame).
13. **Themes (REQ-MR-45, 46, 47, 48).** In the settings view the row **Theme** shows Candy Road, Space Rally and Jungle Run. Play one race in each theme. Check: the ground, the road, the walls and the three obstacles match the theme (candy: lollipops, gumdrops, cupcakes; space: asteroids, satellites, craters; jungle: logs, boulders, tiki masks); the obstacles are the same on Try again; the cars look the same in every theme and turn to face the way they move; the walls stand out from the ground in all three; the scenery beside the road matches the theme (REQ-MR-57: candy lollipops, canes, ice creams, donuts, cookies; space rockets, planets, UFOs, stars; jungle palms, bushes, flowers, mushrooms) and does not hide the road or the cars. Press Try again and Settings: the theme you chose is still chosen. Switch the TV to Hebrew: the title and the theme names are readable (a Hebrew reader checks the wording). Check with a child of 5 to 8 years: is a car easy to follow and are the obstacles easy to see?

Item 10 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-9-10). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the race screen (top bar with the leader chip, track name) | Not run | | | |
| 2 | Video: cars still in the countdown, GO buzz noted | Not run | | | |
| 3 | Video: tilt right and tilt up | Not run | | | |
| 4 | Note: too slow, too fast or too nervous | Not run | | | |
| 5 | Note: count the buzzes in one second at a wall, an obstacle and a car | Not run | | | |
| 6 | Overlay screenshot (FPS) with 4 phones on a Hard track | Not run | | | |
| 7 | Photo of an edge arrow with its distance | Not run | | | |
| 8 | Winning time for each track (fill the table in the test) | Not run | | | |
| 9 | Photo of the settings view; video of choosing a track and of Easy, Medium and Hard; note on the generated tracks (any bad bends or corners where a car gets stuck) | Not run | | | Changed 2026-10-09: the four hand-made tracks were replaced by generated tracks. |
| 11 | Video of a full race on one track and notes for every check in the item | Not run | | | |
| 12 | Photo of the race from the sofa in each theme; note: sharp pixels, the outline of the cars, the frame rate and the TV | Not run | | | |
| 13 | Photo of each theme; the settings view with the Theme row; note on the Hebrew texts and on the child | Not run | | | Added 2026-10-15: the race became Road Rally (flat pixel world, 3 themes). |

Winning times (item 8):

| Track | Difficulty | Winning time (s) | Run | Evidence |
|-------|------------|------------------|-----|----------|
| Track | | | | |
| Track | | | | |
| Track | | | | |
| Random track | | | | |

History:

- 2026-10-09 (not run): the four hand-made tracks were replaced by generated tracks, and item 9 is new: the settings view with Difficulty and the track carousel (10 sketches and a '?', the middle one is chosen, yellow border), difficulty by the number of obstacles (Easy 2, Medium 6, Hard 10 for each 100 m). Look for a bend where a car gets stuck, and for too many obstacles on Hard. The results menu has Settings, not Choose track.
- 2026-10-10 (not run): item 12 is new: the 3D world is drawn in a 480x270 pixel view (phase 3 of the arcade style), and the cars have their slot number on them.
- -: **Not run**. Not run on a device yet. Item 11 is new: run it again after a change of the shared game code (PR 12 changed the countdown, the buzz limit and the end with no players).

## Test 10

### Banana Party (pointer)

Needs: 1 to 4 phones, 1 TV, and a child of about 5 to 8 years for item 9. Covers: REQ-SS-*, REQ-GM-47i to 47n, REQ-GM-80 to 84, 90 to 95, RISKS A4, REQ-GM-37, REQ-GM-50.

Hold each phone like a remote control, pointing at the TV, from the sofa. This is the first game that uses the
gyroscope pointer, so this test also checks the pointer itself (the old Test 5 for drift was removed).
The game was "Target Shoot" until 2026-10-09: it was changed after the first try (see History).


**Steps**

1. Start **Banana Party** with 1 phone. Hold the phone toward the TV during "3, 2, 1" and press nothing. Check: a cursor ring in the player color follows the phone, a throw in the countdown does nothing, and at "GO" the cursor is in the middle of the screen. (REQ-SS-1, 2)
2. Move the phone left, right, up and down. Check: the cursor moves the same way on the screen. Write down if the cursor is too fast or too slow for the distance from the sofa, and if you need a big arm movement to reach the corners. (`pointer_range_deg` in `orientation.gd`, REQ-SS-3)
3. Hold the phone still for 40 seconds. Check: the cursor stays where it is. Write down how far it drifted (in cm on the screen). Tap **RECENTER**. Check: the cursor goes to the middle. (RISKS A4, REQ-GM-37)
4. Press **A**. Check: a banana flies to the cursor. When it lands on an animal, the animal jumps, closes its eyes happily, shows its own cheer (gorilla shakes, sloth wiggles, lemur turns, elephant sprays water, orangutan has hearts, monkey has sparkles), the points show, and the phone buzzes a little. When it lands on empty ground, a poof shows, nothing is lost, and you can throw again after a moment. Press B. Check: nothing happens. (REQ-SS-4 to 6, 13)
5. Check the animals from the sofa. Check: they are big and slow enough to hit with a pointer, they are easy to tell apart (the smaller monkeys and lemurs for 25 points, the bigger orangutans, sloths, gorillas and elephants for 10), and the cursor ring is easy to see on the green ground. Check the golden monkey king (100 points, fast, comes every 14 to 22 s): is it fun and hittable? New 2026-10-16. Write down if the speed is right for an adult and for a child. (REQ-SS-7, 12)
6. Play a full round of 60 seconds alone. Write down the score. Check the medal at the end and compare with the tiers [150, 300, 450]: are they too easy or too hard? (REQ-SS-16)
7. Play with 2 to 4 phones. Check: all players see the same animals. Two players throw at the same animal: the one who threw first gets it. Check the frame rate in the debug overlay with 4 players (60 expected). (REQ-SS-11, REQ-GM-50)
8. Switch one phone Wi-Fi off during a round. Check: within about 5 seconds the game pauses with the card "2P LOST CONNECTION". The cursor and score of a phone that left are gone. (REQ-GM-30, REQ-SS-16)
9. Let a child of about 5 to 8 years play 2 rounds, with a grown-up next to them. Check: the child understands what to do from the hint and a few seconds of play, hits some animals, is not frustrated or scared, and wants to play again. Write down the age and what the child said or did. (REQ-GM-80 to 84, REQ-SS-17)
10. Open the tile of **Banana Party**: the settings view opens. Play one round alone on each of Easy, Medium and Hard. Check: Easy has slow animals and more of them, Hard has fast animals and fewer, Hard is a challenge but not impossible, and the result title is the difficulty ("HARD") with the medal picture next to your name; a round with no medal says "NO MEDAL THIS TIME (HARD)". Write down the score of each round to tune the tiers (Easy [170, 340, 510], Medium [150, 300, 450], Hard [120, 240, 360]).
11. **Jungle look (2026-10-16, REQ-SS-12).** From the sofa (about 3 m), look at the jungle. Check: the animals, the bananas and the cursor rings are sharp pixels, each animal can be named (monkey, lemur, orangutan, sloth, gorilla, elephant), the player colors of the rings are easy to tell apart on the green ground, the points "+10" are easy to read, and the leaves and vines do not hide the animals. Does the walk (a bob, no legs) look alive enough? Check the bushes (REQ-SS-26): an animal that walks behind a bush is covered and a banana at it does nothing; Easy has 3 bushes, Medium 5, Hard 8; are they too many or too few? Write down if the cursor and the banana are easy to follow. An animal is hidden, and cannot be hit, while its middle is behind a bush: write down if a child finds it unfair that a visible part of an animal cannot be hit.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Video of the countdown and GO: the cursor in the middle | Not run | | | |
| 2 | Note: range too small or too big; video of the cursor in the four directions | Not run | | | |
| 3 | Note: drift in cm after 40 s; video of RECENTER | Not run | | | |
| 4 | Video: a hit, a miss with the poof, B does nothing; note the buzzes | Not run | | | |
| 5 | Photo of the animals and the cursor from the sofa; note on the speed | Not run | | | |
| 6 | Photo of the result menu with the medal; the score; note on the tiers | Retest | R2 | Chat report 2026-10-09 (no file) | R2: while playing, 'when in the game and the score is above 3 digits, the last digit isn't visible'. The name-and-score chip at the top was a fixed 250 px wide and cut the text. Fixed on 2026-10-09 (REQ-GM-46): the chip is as wide as its content, and a long name is not cut (the chip gets wider, or goes to a second row). The rest of the round (feel, medal, tiers) was not reported. Retest, and check scores of 4 and 5 digits and a long phone name. |
| 7 | Photo of two phones' cursors and the same animals; overlay FPS with 4 phones | Not run | | | |
| 8 | Video: Wi-Fi off during a round, then the card | Not run | | | |
| 9 | Short video of the child playing (only with the permission of the parent); the age and the words of the child | Not run | | | |
| 10 | Photos of the settings view and of a round on each difficulty; the scores; note on the speed and the number of animals | Not run | | | Added 2026-10-09 (REQ-SS-20 to 22). All values are first guesses. |
| 11 | Photo of the jungle from the sofa; note: sharp pixels, readable points and "+10", the bushes | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-16 (jungle, REQ-SS-12). |

Values to write down (items 2, 3, 5 and 6). These decide the first tuning values of the game:

| Value | Result | Run | Notes |
|-------|--------|-----|-------|
| Pointer range: comfortable half range in degrees (now 25, `pointer_range_deg`) | | | |
| Drift after 40 s still (cm on the screen) | | | |
| Speed of the animals for an adult and for a child (now 80, 90 and 160 px/s) | | | |
| Score of a full round alone, and the medal (tiers 150, 300, 450) | | | |
| Frame rate with 4 phones (aim 60) | | | |

History:

- 2026-10-10 (not run): item 11 is new: the sky is a pixel world (phase 4 of the arcade style).
- 2026-10-16 (not run): Snowball Splat became **Banana Party** (first Banana Splat; "קרב" means fight in Hebrew, so the owner chose Party): bushes that hide animals (REQ-SS-26, 3, 5 or 8 by difficulty), a jungle at sunset, six animals that eat bananas in three depth lanes, a hit animation for each, plain ring pointers and the golden monkey king (100 points). Items 4, 5 and 11 changed (REQ-SS-7 to 13, 25). All values are first guesses.
- 2026-10-09 (not run): item 10 is new: the settings view and Easy, Medium and Hard for Snowball Splat (faster and fewer Puffs as it grows, medal tiers for each level, the title names the difficulty).
- R2: the owner played the new game and reported one problem: the last digit of a score above 3 digits was not visible in the chip at the top. Fixed on 2026-10-09. Nothing else was reported, so the other items stay not run.
- R1: **Fail**, then redesigned. The owner tried the first version ("Target Shoot", small fast targets, a lock after a miss, decoys) and said: "I don't think it's playable in its current definition." They asked for something like Duck Hunt with larger and slowly moving targets, no penalty for a miss, and a game that is also for kids, so not shooting but for example throwing snowballs at a made-up character. Changed on 2026-10-09: the game is now Snowball Splat (REQ-SS-*), and REQ-GM-80 to 84 are new for all games. Which steps failed was not reported. The whole test needs a run with the new game.

## Test 11

### Result menus (REQ-GM-72)

Needs: 1 to 4 phones, 1 TV. Covers: REQ-GM-34, REQ-GM-40, REQ-GM-41, REQ-GM-72, REQ-GM-73, REQ-MZ-5, REQ-MR-31.

1 to 4 phones. Tests the ranked result menu (REQ-GM-72) that every game with scores uses. Here: the maze and the race. New. Added with the shared game code (PR 12).

**Steps**

1. Maze with 1 phone: finish the maze. Check: the result menu is easy to read from the sofa, and the medal picture and the avatar next to the name are easy to see. (The rows, the title and the buttons are checked by `docs/AUTOMATED_TESTS.md`, A-11-1.)
2. Maze with 2 to 4 phones: let one ball reach the exit first. Check: the list and the buttons are inside the screen edge of your TV (look at the photo) and easy to read. (The rows and the 60 px edge are checked by A-11-2.)
3. Road Rally with 4 phones on any track: let all cars finish. Check: the card with the list and the 3 buttons (Try again, New game, Back to menu) is inside the screen edge of your TV and can be read from the sofa; the medals of 1st, 2nd and 3rd place (gold, silver, bronze) can be told apart. (The rows, the order and the 60 px edge are checked by A-11-3.)

Items 4, 5, 6, 7 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-11-4 to A-11-7). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the result menu (1 phone) from the sofa | Not run | | | |
| 2 | Photo of the result menu with 'not finished' rows; check the edge | Not run | | | |
| 3 | Photo of the race results with 4 rows, with the screen edge visible | Not run | | | |

History:

- -: **Not run**. New.

## Test 12

### Game tiles and the toy box look (REQ-GM-49)

Needs: 1 TV (phones for the game photos). Covers: REQ-GM-49, REQ-FL-20, REQ-FL-40, REQ-GM-41.

Phones are needed only for the photos of the running games. Needs the TV and the Games screen. New. This is the visual check that the `review` skill asks for with a screenshot of the game next to the Games screen.

**Steps**

1. Open the Games screen. Check: the 9 games are in 3 rows of 3; with the remote you reach the last row (the grid scrolls); every tile has its screenshot, title and player range; the description of the focused game shows in the bar under the grid; and the text is easy to read from the sofa.
2. For each game, compare its tile with a photo of the game running. Check: the tile shows the same look (colors, outline, shapes) as the game, and the Games screen and the games look like one toy box.
3. Check the tiles of **Treasure Maze** and **Road Rally**. Both were made again on 2026-10-09: 4 cars on a bend before a post (Track 1, Hard), and 4 balls on the way to the exit in the pixel Garden look. If a tile and its game differ, tell Claude: the tiles are made again with `tools/make_tiles.gd`.
4. Check the tile of **Banana Party** (made again on 2026-10-16): it shows the jungle, the animals, four players with scores, an animal that was just hit ("+10") and a banana in the air. Check that the cursors, the hit animal and the banana can be seen at the small size of the tile.
5. Check the tile of **Paint Grab** (made again on 2026-10-16): the floor with the hidden picture and the bonus pots, and four blobs. Check that the blobs and a pot can be seen at the small size of the tile.
6. Check the tile of **Sumo Bumpers**: the island and the penguins. Check that the penguins and the edge of the island can be seen at the small size of the tile.
7. Check the tile of **Galaxy Protector** (new on 2026-10-16): the night sky, the ships, the asteroids and a beam. Check that the ships and the asteroids of three sizes can be seen at the small size of the tile.
8. Check the tile of **Pin Pals** (new on 2026-10-16): the lane, the pins and the ball about to hit them. Check that the pins and the ball can be seen at the small size of the tile.
9. Check the tile of **Tennis** (new on 2026-10-17): the court with a serve just hit and the ball high over the near half. Check that the players and the ball can be seen at the small size of the tile.
10. Check the tile of **Mini Golf** (new on 2026-10-17): a hole with the windmill and the lake, and a ball on its way. Check that the ball, the hole and the windmill can be seen at the small size of the tile.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the Games screen | Not run | | | |
| 2 | Photos: tile next to the game, for each game | Not run | | | |
| 3 | Photos of the old and the new look, and a note | Not run | | | Road Rally and Maze tiles remade 2026-10-09 (4 cars on a bend with posts; 4 balls on the way to the exit). |
| 4 | Photo of the tile and of the running game | Not run | | | Banana Party tile remade 2026-10-16 (a jungle, 4 players, a hit, a banana in the air). |
| 5 | Photo of the tile and of the running game | Not run | | | Paint Grab tile remade 2026-10-16. |
| 6 | Photo of the tile and of the running game | Not run | | | Sumo Bumpers tile. |
| 7 | Photo of the tile and of the running game | Not run | | | Galaxy Protector tile, new 2026-10-16. |
| 8 | Photo of the Pin Pals tile next to a photo of the game | Not run | | | |
| 9 | Photo of the Tennis tile next to a photo of the game | Not run | | | |
| 10 | Photo of the Mini Golf tile next to a photo of the game | Not run | | | |

History:

- -: **Not run**. New.

## Test 13

### Controller on an iPhone

Needs: 1 iPhone, 1 Mac with Xcode, 1 TV. Covers: `tools/deploy-ios.sh`, RISKS A2, REQ-FL-58, 59, 68, 83, 84. New. Nothing in the iOS path has run yet.

**Steps**

1. Follow `docs/EXPORT.md`, section *Controller on an iPhone*, and run `IOS_TEAM_ID=<team id> tools/deploy-ios.sh`. Check: the export, the build, the install and the launch end without an error, and the app opens on the phone in portrait, with the name Sababi: Remote on the home screen. Write down every error and the fix.
2. Open the connect screen. Check: there is no scan and no paste button, only **ROOMS FOUND** and **Refresh** (and the ABOUT button at the top). The local network permission is asked once. The list shows the TV (tap it, type the PIN from the TV: the phone joins and the TV shows the player), or stays empty (write which, and tell Claude). With the list empty, tap **Refresh** and write down if the scan finds the TV within about 15 seconds (REQ-FL-83). The hint line must say how to allow Local Network (REQ-FL-59). Turn Local Network off for the app in Settings to see it.
3. Tilt the phone flat, left, right, forward, back (like Test 3, items 1 and 4). Check: the overlay Accel and Gyro values have the same directions as on Android. If they are inverted, tell Claude: remove "iOS" from `ACCEL_INVERTED_ON` in `scripts/input/sensor_sampler.gd` (flat, screen up must give Accel z about +9.8).
4. Play Treasure Maze for 2 minutes with the screen on. Check: no disconnect, no screen lock, and the ball follows the tilt.
5. Lock the phone and unlock it. Check: the TV shows the lost-phone card and the game can resume (like Test 7, items 1 and 5). The phone returns with its token and the PIN pad does not open; after a lock of more than 30 seconds outside a game it does (like Test 7, item 3).
6. On an iPhone with a Dynamic Island or a notch, open every phone screen (Connect with the player dropdown, the PIN pad, About, the player list, the player edit screen with the keyboard open, waiting, Settings, the pad in a game), also turned to the side. Check: nothing is hidden by the island, the notch, the status bar or the home bar: the colored square, the player number, DISCONNECT, the texts and the A and B buttons are fully visible (REQ-FL-68). Write down which iPhone it is.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Terminal log of the deploy, photo of the app | Not run | | | |
| 2 | Photo of the TV with the player joined | Not run | | | |
| 3 | Photo of the overlay values for each tilt | Not run | | | |
| 4 | Short video | Not run | | | |
| 5 | Photo of the TV card | Not run | | | |
| 6 | Photo of the pad and the waiting screen under the island, upright and turned | Not run | | | |

History:

- -: **Not run**. New.

## Test 14

### Paint Grab (tilt)

Needs: 1 to 4 phones, 1 TV, and a child of about 5 to 8 years for item 7. Covers: REQ-PG-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Hold each phone flat like a tray. New game (2026-10-09). The blob feel (`TiltBody`: acceleration, damping, speed limit, bounce) and the
difficulty values are first guesses.

**Steps**

3. Tilt the phone. Check: the blob rolls the same way, slows down by itself, bounces softly at the edge and never leaves the floor. Write down if it is too slow, too fast or too nervous (`accel`, `damping`, `max_speed` in `scripts/game/tilt_body.gd`).
4. Roll over tiles. Check: each tile takes your color, pops a little, and your tile count on your phone goes up. Roll over a tile of another player: it changes color and your phone buzzes.
5. Play a full round of 60 seconds alone on Easy, Medium and Hard. Write down the percent of the floor you painted and the medal. Check: the floor is 12 x 7 tiles on Easy, 16 x 9 on Medium and 20 x 11 on Hard, and the blob is slower on Easy and faster on Hard. The title is the difficulty (for example "HARD") and the medal picture is next to your name; with no medal the title is "NO MEDAL THIS TIME (HARD)". The tiers [Easy 35, 55, 75; Medium 30, 50, 70; Hard 25, 40, 55] feel right.
6. Play with 2 to 4 phones. Check: the blobs bounce off each other, the leader chip names the leader (or TIE), the winner is named at the end, and equal scores say "Tie!". Leave the game on one phone during a round: its blob goes, its tiles stay, and the round goes on.
7. Let a child of about 5 to 8 years play 2 rounds, with a grown-up next to them. Check: the child understands what to do from the hint line, enjoys it, and is not upset when a tile is painted over.
8. Check the frame rate in the debug overlay with 4 phones on Hard (60 or close). (REQ-GM-50)
10. **Pixel world (phase 4, REQ-PG-15).** From the sofa (about 3 m), look at the floor on Easy, Medium and Hard. Check: the tiles are sharp squares with equal gaps (no uneven lines), you can tell the colors apart, the blob and its number are easy to see on a tile of its own color, and a painted tile pops (a hard step). Write down if the pop is easy to see.
11. **Pictures and pots (2026-10-16, REQ-PG-22, 23).** Play 5 rounds in a row. Check: each round has a different faint picture under the empty floor, you can see what it is (an invader, a heart, a ghost, a balloon, an apple ...) before the floor fills, and in the end the painted tiles still show it. Write down which pictures you could not recognize and if any came twice in a row. Then check the pots: a gold pot (3 x 3 patch) or a rainbow roller (the whole row) lands first after 8 s of play and then every 9 to 15 s, a frame shows the tiles it will paint, the first blob on it paints the patch and the phone buzzes, and a pot that nobody takes blinks in its last 2 s and goes away after 9 s. Write down if the pots are too rare or too strong, if a child understands them without a hint, and any picture that scares the child.

Items 1, 2, 9 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-14-1, A-14-2, A-14-9). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 3 | Note: too slow, too fast or too nervous; short video | Not run | | | |
| 4 | Video: painting a free tile and taking a tile; the tile count on the phone | Not run | | | |
| 5 | Percent and medal for each difficulty; note on the tiers | Not run | | | |
| 6 | Video or photo of 4 blobs; note on the bounce | Not run | | | |
| 7 | Note: the child, the age, what happened | Not run | | | |
| 8 | Overlay screenshot (FPS) with 4 phones on Hard | Not run | | | |
| 11 | Photos of 3 rounds with the picture visible and after the pots; list of pictures that were not recognized; note on the pots | Not run | | | Added 2026-10-16 (REQ-PG-22, 23). The shapes, the colors and the pot values are first guesses. |
| 10 | Photo of the floor from the sofa; note: equal gaps, colors, the blob and the pop | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). Look changed on 2026-10-15 (Treasure Maze). |

History:

- 2026-10-16 (not run): item 11 is new: a hidden picture under the floor (30 shapes, a new one each round) and bonus pots (gold 3 x 3, rainbow roller), REQ-PG-22 and 23.
- 2026-10-10 (not run): item 10 is new: the floor is a pixel world (phase 4 of the arcade style).
- -: **Not run**. New.

## Test 15

### Sumo Bumpers (tilt and A)

Needs: 2 to 4 phones, 1 TV, and a child of about 5 to 8 years for item 8. Covers: REQ-SB-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Hold each phone flat like a tray. New game (2026-10-09). The movement (`TiltBody`), the bounce, the dash and the difficulty values are first guesses.

**Steps**

1. With 1 phone, open the tile of **Sumo Bumpers**. Check: the tile is dimmed and says "Needs 2 players". With 2 phones the settings view opens with Difficulty on Medium. Start.
3. Tilt the phone. Check: the bumper rolls the same way, slows down by itself, and the platform shrinks all the time (the edge ring gets red). Write down if the bumper is too slow, too fast or too nervous (`accel`, `damping`, `max_speed` in `scripts/game/tilt_body.gd`).
4. Bump into another bumper. Check: both bounce away and both phones buzz at a fast hit, and nobody is hurt.
5. Press **A** with a tilt. Check: a dash in the tilt direction, a ring around the bumper shows when it is ready again. Write down if the dash is too strong or too weak (`DASH_SPEED`, the dash time).
6. Roll over the edge. Check: the bumper spins, gets small and says "Whee!", the phone buzzes, and the round goes on. When one bumper is left, a banner names the winner of the round (a draw says "ROUND DRAW!") and the next round starts after 2.5 s with all bumpers back.
7. Play all 3 rounds with 2, 3 and 4 phones. Check: the points of the leader chip and on each phone, the winner of the match, and "Tie!" for equal points. Write down how long a round is and if the wait after a fall is too long (REQ-SB-9). Check that the platform shrinks in 30, 24 and 18 s (Easy, Medium, Hard), that after the first fall it shrinks twice as fast (a fallen bumper waits at most 15, 12 and 9 s), and that the title says Round 1, 2 and 3 and the bar says Round x of 3. Play Easy, Medium and Hard.
8. Let a child of about 5 to 8 years play a match, with a grown-up next to them. Check: the child understands what to do from the hint line, laughs at the fall and is not upset.
10. Check the frame rate in the debug overlay with 4 phones on Hard (60 or close). (REQ-GM-50)
11. **Pixel world and Sky Island (REQ-GM-47i to 47n, REQ-SB-15).** From the sofa (about 3 m), look at the world. Check: the sky, the clouds, the island and the penguins are made of sharp square pixels (not blurred), every penguin has a black outline and is easy to tell from the others by its body color on the green, the island edge turns red as it shrinks, the cliff and the clouds look right, "WHEE!", the round banner and the countdown are easy to read on the sky, and the chips are sharp text. Write down if a penguin is too small to follow in a fight, and the TV (1080p or 4K).

Items 2, 9 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-15-2, A-15-9). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the dimmed tile and of the settings view | Not run | | | |
| 3 | Note: too slow, too fast or too nervous; photo of the red ring | Not run | | | |
| 4 | Video of a bump; note on the buzz | Not run | | | |
| 5 | Video of a dash; note on the strength and the ready ring | Not run | | | |
| 6 | Video of a fall and the banner | Not run | | | |
| 7 | Length of a round for each difficulty; note on the wait | Not run | | | |
| 8 | Note: the child, the age, what happened | Not run | | | |
| 10 | Overlay screenshot (FPS) with 4 phones on Hard | Not run | | | |
| 11 | Photo of the screen from the sofa; note: sharp pixels, readable numbers, the TV | Not run | | | |

History:

- -: **Not run**. New. Item 11 was added on 2026-10-10 (phase 2 of the arcade style) and changed on 2026-10-15 for the Sky Island and the penguins.

## Test 16

### The arcade look (REQ-FL-37 to 46, FD-18)

Needs: 1 to 4 phones, 1 TV on 1080p (and a 4K TV if you have one), a child of 5 to 8 years for item 8. Covers: REQ-FL-37 to 46, 41a, 52, 53, REQ-GM-45, 46. New, written on 2026-10-10 for phase 1 of `docs/ARCADE_STYLE_PLAN.md`. The games are in the pixel style too (phases 2 to 4 are built); this test looks at the menus, the phone and the game shell (HUD, countdown, menus, hints).

**Steps**

1. Sit on the sofa (about 3 m from the TV). Go through the logo, Connect, Games, Settings, About, a game settings view, the Players modal, the quit question, a pause menu and a result menu. Check: all text is easy to read (the smallest is 32 px), upper case, white, gray or yellow on black. Write down every text that is hard to read.
2. Look at the text and the frames from 1 m. Check: the pixels are sharp, not blurred or smoothed, on 1080p. Do it on a 4K TV too, if you have one.
3. Games screen with 1, 2 and 4 phones. Check: three tiles in a row, the focused tile has a yellow frame and a cursor, the description of the focused game shows in the bar under the grid, "GALAXY PROTECTOR" (the longest title) fits under its tile with the cursor, the grid of 9 tiles (3 rows) scrolls so that the focused tile is in view, and a game that needs more phones shows its reason in yellow.
4. Check the menus: the cursor is in front of the focused item, a destructive item (END GAME, QUIT, REMOVE) is red with the focus, BACK is dim until it has the focus, and OK, Back and the D-pad work as before.
5. Check the motion: PRESS OK TO CONTINUE and PRESS OK TO SKIP blink (about half a second on, half a second off), the logo drops in in steps, the confetti is square, the countdown number shrinks in steps. The overlay FPS stays at 60.
6. Phone: connect, wait and pad screens. Check: the text is readable at arm's length, A (green) and B (red) feel like buttons, RECENTER flashes yellow, DISCONNECT is at the top right and needs one tap, and the slot color square with the slot number is at the top.
7. Play every game of the Games screen with 4 phones that have names of 10 letters (the most a name can have; give two phones the same name to get 12 characters). Check: the leader chip (name and score), the timer, the title and the hint do not hide each other or the play area, and the HUD stays on one row. Write down which game has a problem and where. Test 19 covers the leader chip and the phone score in detail.
8. A child of 5 to 8 years joins and plays one game. Check: the child finds the focus (the cursor), reads or understands "PRESS OK", and does not say it looks scary or boring. Write down what the child says.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photos of each TV screen | Not run | | | |
| 2 | Close photo of a title and a menu on 1080p (and 4K) | Not run | | | |
| 3 | Photo of the Games screen with 1 and 4 phones | Not run | | | |
| 4 | Photos of a menu with the cursor, a red item, a dim BACK | Not run | | | |
| 5 | Video of the logo, a blinking prompt and a countdown; overlay FPS | Not run | | | |
| 6 | Photos of the phone screens | Not run | | | |
| 7 | Photos of the HUD of each game with 4 long names | Not run | | | |
| 8 | Notes: what the child said | Not run | | | |

History:

- -: **Not run**. New.

## Test 17

### Hebrew and right to left (REQ-FL-54, 60 to 63, REQ-GM-47o, FD-19)

Needs: 2 phones (one with the system language Hebrew, one English), 1 TV (run it with the TV set to Hebrew, region Israel, and again set to English), a person who reads Hebrew. Covers: REQ-FL-54, 60 to 63, REQ-GM-47o. New, written on 2026-10-10 for phase 5 of `docs/ARCADE_STYLE_PLAN.md`. The headless test `tests/smoke_lang.gd` checks the table, the layout positions and the protocol; it cannot check how the text looks on a TV.

**Steps**

1. Delete the app data of the TV app (or install fresh) and start it with the TV set to Hebrew. Check: the logo screen waits and shows "ENGLISH" and "עברית" side by side, the focus is on "עברית", and nothing moves on by itself. Press OK. Check: the app is in Hebrew and opens the Connect screen. Close the app and start it again: the logo goes on by itself (no choice) and the language is still Hebrew. Do it again with the TV set to English: the focus starts on "ENGLISH".
2. In Hebrew, go through the logo, Connect, Games, Settings, About, a settings view, the Players modal, the quit question, the Connect screen with the PIN. Check: every screen is mirrored (QR card at the right, slot squares at the right, cursor at the right and pointing left, title at the right), no text is cut, no English word is left (except SABABI, WI-FI, QR, OK, PIN, the room code and the player names), and the Hebrew letters and the punctuation (`. , ! ? -`) look right next to each other. Write down any text that is cut or any word that looks wrong.
3. In Hebrew, the Left and Right keys of the remote in a choice row (Difficulty): Right goes to the previous value (the arrow at the right), Left to the next. Check that the D-pad moves the focus between rows by position as before.
4. Join 2 phones: one with the system language Hebrew, one English, with a profile with a Latin name on one and a profile with a Hebrew name on the other (Test 20). Check: before the join the Hebrew phone shows its connect screen in Hebrew and the English phone in English; after the join both show the language of the TV (Hebrew); the player names show as typed (a Latin name in a Hebrew row is in the right place).
6. Start every game in Hebrew with 2 phones. Check: the title is at the top right, the leader chip is at the left (Pin Pals has no leader chip), the timer is at the left of the title, the hint and the countdown ("קדימה") are readable, and the world is not mirrored (the maze start is at the top left, the track runs as in English). Open the pause menu and the result menu: the ranking list, the medal text and "תיקו!" read right.
7. Phone in Hebrew, on the pad screen: the words RECENTER, DISCONNECT and the hint are Hebrew, and A and B are in the same places as in English (the pad is not mirrored).
8. Run the English TV again with the same phones: nothing changed from before (compare with Test 16).

Item 5 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-17-5). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Video of the first start with the choice and the second start; photo of the choice | Not run | | | |
| 2 | Photos of each TV screen in Hebrew; a list of cut or wrong text | Not run | | | |
| 3 | Video of a choice row with Left and Right | Not run | | | |
| 4 | Photos of both phones before and after the join, and the Connect screen with the names | Not run | | | |
| 6 | Photos of the HUD of each game in Hebrew; the result menu | Not run | | | |
| 7 | Photo of the Hebrew phone pad | Not run | | | |
| 8 | Photos of the English TV | Not run | | | |

History:

- -: **Not run**. New.

## Test 18

### Sound and haptics

Needs: 1 to 4 phones, 1 TV, a grown-up, and a child of about 5 to 8 years for item 9. Covers: REQ-FL-64 to 66, REQ-GM-49a to 49c, REQ-GM-43.

New (2026-10-10). The songs, the effects and the levels are first guesses (`scripts/audio/songs.gd`). The headless tests check the data, not how it sounds. Write down what you hear.

**Steps**

1. Start the TV app. Check: the menu song starts by itself on the logo screen (a short wait is fine), without a click or a pop, and goes on across the Connect, Games and Settings screens without a restart.
2. Move the cursor, press OK and Back on the remote. Check: a soft blip, a rising two-note sound, a falling two-note sound. Join and leave with a phone: a rising and a falling run. Press OK on a dimmed tile (Sumo Bumpers with 1 phone): a low short sound. Write down if any sound is too loud, too sharp or too often.
3. Open Settings. Check: the rows Music, Effects and Mute. Change Music with Left and Right: the song gets louder and quieter by 10 steps. Change Effects: a sample plays. Mute: everything is silent. Leave the app and start it again: the levels are kept.
4. Change the volume of the TV and of the phone (media volume, silent mode). Check: the TV sound follows the TV only. The phone makes no sound at all and its settings change nothing.
5. Start each game (all 9 games of the Games screen). Check: the countdown beeps at 2 and 1 and a higher beep at GO, and the game song starts at GO (write down how long after GO). The song of each game has its own mood and loops without a click. Write down which songs you like and which not. In a timed game, listen for a soft tick in each of the last 5 seconds.
6. In each game, make each event of the *Sound and haptics* table of its game file (`docs/games/<id>.md`). Check: the effect plays and the phone of the player buzzes at the same time. Write down effects that are too loud, too quiet, too often or that do not fit. With 4 players, check that the effects do not turn into noise.
7. Open the pause menu and the "phone lost" card (turn off Wi-Fi on one phone). Check: the music gets quieter and comes back with Resume, with no jump.
8. Finish a game with a winner, with a medal (one player), with no medal (one player), and with a tie. Check: a short fanfare for a winner or a medal, a neutral phrase for a tie, "Round over" or a solo round with no medal, then silence on the result menu. Back to the menu: the menu song comes back.
9. Let a child of about 5 to 8 years play a game with sound. Check: the sounds are friendly and not scary or too loud. Write down what the child says.
10. On a phone, open **Settings** on the waiting screen and set **Haptics** to OFF. Check: the phone does not vibrate in a game, and the game plays the same. Set it to ON: it vibrates once and in games. Close the app and start it again: the choice is kept. Check that the Settings button is not in the way of DISCONNECT.
11. Measure the delay between a picture event and its sound on the TV box (a camera at 60 fps or more): write down the value. Write down if the first song is late after the app starts (the song is made in small steps over some frames).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Note: when the song starts; clicks or pops | Not run | | | |
| 2 | Note on each menu sound | Not run | | | |
| 3 | Photo of the Settings rows; note on the levels | Not run | | | |
| 4 | Note: the phone is silent | Not run | | | |
| 5 | Note for each game: the song, how long after GO it starts | Not run | | | |
| 6 | Note for each effect | Not run | | | |
| 7 | Note: the music level in the pause menu | Not run | | | |
| 8 | Note on the result sounds | Not run | | | |
| 9 | Note: the child, the age, what happened | Not run | | | |
| 10 | Video or note: the phone with Haptics ON and OFF | Not run | | | |
| 11 | Value of the delay; note on the first song | Not run | | | |

History:

- -: **Not run**. New.

## Test 19

### Leader chip, phone score and name tags (REQ-FL-67, REQ-GM-46, 46a, FD-21)

Needs: 2 to 4 phones (give two of them names of 10 letters, the most since FD-22), 1 TV on 1080p, a grown-up, and a child of about 5 to 8 years for item 8. Covers: REQ-FL-67, REQ-FL-68, REQ-GM-46, 46a, FD-21, issue #25.

New (2026-10-10). The HUD shows one chip, the leader, and not a chip for each player. Each phone shows its own place and score. The size of the header text on the phone and the place of the name tags are first values. The headless tests check the layout rules, not how it looks from the sofa.

**Steps**

1. Start Banana Party with 4 phones (two names of 10 letters, the most a name can have since FD-22). Check from the sofa: the top row has the title, the timer and one chip with the leader's name and score, all on one row; nothing covers the play area; the name and the score are easy to read. Write down if the leader chip is too small or too big.
2. In the same game, before anybody scores: no chip shows and the phones show only `2P` (or the profile name) and 0. Then score with different phones. Check: the chip changes to the new leader at once; when two phones have the same score it says TIE with a gray square and the score; a score of 4 and 5 digits still fits.
3. Look at each phone during the game. Check: the line under the header row (not next to Disconnect) shows the place (1ST to 4TH) and the score (`2ND  120`), and it changes when the score changes; it is readable at arm's length; with one phone only the score shows (no place). On an iPhone with a Dynamic Island (and on an Android phone with a camera cut-out): the colored square, the player number and DISCONNECT are fully visible below the island or the notch, nothing is hidden at the top, at the bottom (the home bar) or at the side when you turn the phone, and A and B are fully on the screen (REQ-FL-68). Open the pause menu: the phone keeps its score. Go back to the menu: the score is gone.
4. Play Paint Grab and Sumo Bumpers with 2 to 4 phones. Check the same as items 1 to 3. Do it also with Galaxy Protector (4 ships) and Tennis. In Sumo Bumpers the name tags show again in the countdown of every round.
5. Play Road Rally with 3 or 4 phones. Check: the leader chip names the first car (with its time after the finish); the phones show their place; a car that has not finished shows no time. Check that the old list of names at the left is gone.
6. Play Treasure Maze with 2 to 4 phones. Check: there is no chip during play (the maze has no score) and the phones show only `2P`.
7. In every game, look at the countdown. Check: each player's name stands next to its own ball, car, cursor, bumper, blob, ship or character, in its color; the names do not cover each other (start the maze and Sumo with 4 phones); every name is complete; the tags are gone at GO. Write down where a tag hides something important.
8. A child of 5 to 8 years plays a game. Check: the child finds its own object by the name in the countdown and reads or understands the number on its phone. Write down what the child says.
9. Set the TV to Hebrew and play one game with 2 phones. Check: the leader chip is at the left margin, the timer is at the left of the title, TIE reads "תיקו", and the phone header is readable.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the TV with 4 long names | Not run | | | |
| 2 | Photo of TIE; photo of a 5-digit score | Not run | | | |
| 3 | Photo of a phone header with place and score | Not run | | | |
| 4 | Note for Paint Grab and Sumo Bumpers | Not run | | | |
| 5 | Photo of the Road Rally HUD | Not run | | | |
| 6 | Note: no chip in the maze | Not run | | | |
| 7 | Photo of the countdown of each game | Not run | | | |
| 8 | Note: the child, the age, what happened | Not run | | | |
| 9 | Photo of the Hebrew HUD and phone | Not run | | | |

History:

- -: **Not run**. New.

## Test 20

### Player profiles (REQ-FL-69 to 75, REQ-N8, REQ-C7 to C9, FD-22)

Needs: 2 to 4 phones (one an iPhone if possible), 1 TV on 1080p, a grown-up, and a child of about 5 to 8 years for item 7. Covers: REQ-FL-69 to 79, REQ-GM-98 to 101, REQ-N8, REQ-C7 to C11, FD-22. Items 1 to 8 are phase A (names and avatars), items 9 to 11 are phase C (personal bests), items 12 to 15 are phase B (copy by QR), items 16 and 17 are the Connect screen and the HUD changes of 2026-10-11 (`docs/PROFILES_PLAN.md`, section 11.2).

New (2026-10-10). The headless tests check the rules and the drawing. They do not show how an avatar looks from the sofa, or how the profile screens feel to a child.

**Steps**

1. Make a profile on a phone (name, avatar) and join a TV. Check: the TV shows the name and the avatar in the Players list, in the countdown tags, on the leader chip and in the result list; no "Player N" for that phone. The ball or blob in a game has only its color (REQ-FL-70).
2. Change the avatar and the name with the pencil button on the Connect screen, then join. Check: the TV shows the new values after the phone answers; the phone shows what the TV accepted.
3. A parent phone with 3 profiles: after a round tap DISCONNECT, pick another profile on the Connect screen and join again. Check: the TV shows the new name and avatar. Check that there is no way to change the player while joined (REQ-FL-71).
4. Two phones with the names `Sam` and `sam`. Check: the TV shows `Sam` and `Sam 2`. A name of 10 letters and a Hebrew name of 10 letters fit on the cards and in the lists.
6. Pause card with profile names (switch the Wi-Fi of a phone off). Check: `MAYA LOST CONNECTION`, `Resume without Maya`, `Maya reconnected`; two names of 10 letters fit; a Hebrew name in the English sentence and an English name in the Hebrew sentence read right.
7. All 32 avatars on the four slot colors, at the smallest size they have (the HUD chip and the result row), from the sofa. A child of 5 to 8 years names five of them and finds its own avatar. Write down which avatars look alike.
8. The same profile on a second phone joins the same TV while the TV is in a menu. Check: the older phone shows `THIS PLAYER IS ALREADY IN THE ROOM.` and goes to the Connect screen. Then repeat during a round: the second phone waits as a guest and nobody is removed.

9. Play Banana Party, Paint Grab, Galaxy Protector, Pin Pals (Rails Off; with Rails On there is no NEW BEST) and Road Rally (a fixed track) with a profile on 2 phones. Check: the phone of a player who scores says NEW BEST! on the waiting screen when the round is over; a worse round does not change the best; the second round shows "BEFORE: x" with the old score (a race time in seconds); the phone of a guest shows nothing.
10. Close the app and open it again, then join another TV. Check: the profile and the bests are still there (play the same game and see that "BEFORE" is the old score).
12. Share a profile to a second phone by QR: on the first phone open the list, tap SHARE on a row (give the profile some personal bests first); on the second phone tap SCAN A PROFILE. Check: the second phone shows PLAYER ADDED. with the same name and avatar and the same personal bests. Time how long the code takes to appear and to scan; try it from 30 cm and from 60 cm, with the screen at full and at low brightness.
13. Share a player that the second phone already has, after a rename on the first phone (the name is newer there): the second phone shows PLAYER UPDATED. and has the newer name and avatar. Then rename on the second phone and scan the old copy again: the newer name stays. If each phone has a better best for one game, both phones keep the better value after the scan.
14. An iPhone: COPY CODE on one phone and PASTE A CODE on the iPhone (the iPhone has no scan button). Check the same result as item 12.
15. A broken code (change one letter of a copied code, then paste), a TV link (scan the QR code of the TV on the list), and a player code scanned on the Connect screen: the messages THIS CODE DOES NOT WORK., THIS IS A ROOM LINK., and the player is added.
16. New (REQ-FL-71, 72). On the Connect screen: the dropdown shows the avatar and the name together; open it, pick another player, pick GUEST; tap **+** and make a player (the keyboard must stay open when you tap the name field); the avatars are one line that scrolls by dragging and by the arrows, and the picked one is in view; **Back** from the new player goes to the Connect screen, not to the list; **PLAYERS** in the dropdown opens the list. In Hebrew the arrows still point the right way. After typing, tap outside the field: the keyboard closes. At the first and the last avatar the arrow of that side is dim and does nothing. Tap the pencil button next to the dropdown: change the name and the avatar, Save: both show on the TV after the phone joins; Back from the pencil screen goes to the Connect screen.
17. New (REQ-FL-71, REQ-GM-46b, 70). Join a TV: the waiting screen has only DISCONNECT (top right), the text, SETTINGS and ABOUT, no PLAYER button; to change the player, tap DISCONNECT and choose on the Connect screen. On the TV, in every game, the leader chip and the name tags in the countdown show the color square, then the avatar, then the name, also in Hebrew (left to right inside the chip). No ball, marble, blob, bumper or cursor in any game shows a number or an avatar: only its color (a child of 5 to 8 years still finds their own object, with the name tags in the countdown).

Items 5, 11 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-20-5 and A-20-11). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the TV with 2 profile players in a game | Not run | | | |
| 2 | Note: the new name and avatar on the TV | Not run | | | |
| 3 | Video of a switch between rounds | Not run | | | |
| 4 | Photo of `Sam` and `Sam 2` | Not run | | | |
| 6 | Photo of the pause card in English and in Hebrew | Not run | | | |
| 7 | Photo of the 32 avatars on the TV; note: the child, the age, what the child said | Not run | | | |
| 8 | Photo of the message on the older phone | Not run | | | |
| 9 | Photo of NEW BEST! and BEFORE on a phone | Not run | | | |
| 10 | Note: the bests after a restart of the app | Not run | | | |
| 12 | Video: the scan; time to show and to scan; the distances | Not run | | | |
| 13 | Note: the names on both phones | Not run | | | |
| 14 | Note: the iPhone model and what happened | Not run | | | |
| 15 | Photo of each message | Not run | | | |
| 16 | Video of the dropdown, the +, the avatar line and Back | Not run | | | |
| 17 | Photos of the waiting screen, the leader chip and the name tags (English and Hebrew), the cars | Not run | | | |

History:

- -: **Not run**. New.

## Test 21

### Join PIN and About screens (REQ-FL-84, 85, REQ-N9, FD-25)

Needs: 2 phones (an Android phone and, if possible, an iPhone), 1 TV on 1080p, a grown-up. Covers: REQ-FL-84, REQ-FL-85, REQ-N9, FD-25.

New (2026-10-11). The headless tests check the rules and the pages. They do not show how the PIN pad feels, how the About text reads from the sofa, or how long the Godot pages take to open on a TV box.

**Steps**

1. Open the Sababi: TV Games app. Check: the Connect screen shows the room code and, under it, a PIN of 4 digits, readable from the sofa.
2. Scan the QR code of the TV with an Android phone. Check: the phone joins at once and shows no PIN pad.
3. On a second phone, leave and tap the TV in the list of found TVs. Check: the PIN pad opens; type a wrong PIN: the phone says WRONG PIN. CHECK THE PIN THAT IS SHOWN ON THE TV.; tap the TV again and type the right PIN: the phone joins. Time how long this takes a grown-up. Check that Back closes the pad.
4. Type 5 wrong PINs in a row on the second phone. Check: the sixth try, also with the right PIN, says TOO MANY WRONG PINS. WAIT 30 SECONDS BEFORE RETRYING.; after 30 seconds the right PIN joins. The PIN on the TV does not change. The first phone stays in its slot.
5. Close the phone app and open it again while the TV stays on. Check: the phone comes back to its slot without a PIN. Then restart the TV app and open the phone app: the PIN pad opens by itself (no error text).
6. An iPhone: join from the list with the PIN (the iPhone has no scan button). Check: the pad is easy to use with one hand.
7. Open the Players modal on the TV (from the Games screen). Check: it shows the room code and the PIN; a late phone joins with them.
8. On the TV: Settings, About. Check: the list opens; open "Godot Engine", then "3rd Party Libraries" and one library (for example FreeType) and one with two licenses. Check: every row shows the name and the license type, a long name wraps and is not cut, the text is readable from the sofa, Up and Down of the remote scroll it, Back goes up one step and at the end to Settings. Write down how long the "3rd Party Libraries" list takes to open on the TV box.
9. On a phone: About on the waiting screen (the button after Settings), and About in the top corner of the Connect screen (right in English, left in Hebrew). Check: the pages scroll by touch; on Android the list has the page "QR scanner" (it tells that Google receives technical data) and, in 3rd Party Libraries (also on the Android TV), the page "Android libraries" with the Apache 2.0 text; check that it opens and scrolls to the end in a reasonable time. Check that the Connect screen still fits with the new button. Check: the pencil button next to the player is easy to tell as Edit.
10. Set the TV to Hebrew. Check: the About list and the pages "Sababi" read right (a Hebrew reader checks the wording); the license pages stay in English; the PIN pad and the PIN line read right to left where they should.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the Connect screen with the PIN | Not run | | | |
| 2 | Note: joined at once | Not run | | | |
| 3 | Photo of the PIN pad; note: the time | Not run | | | |
| 4 | Note: the PIN before and after | Not run | | | |
| 5 | Note: the phone came back without a PIN | Not run | | | |
| 6 | Note: the iPhone model | Not run | | | |
| 7 | Photo of the Players modal | Not run | | | |
| 8 | Photo of the About list and a page; note: the time to open the 3rd Party Libraries list and a library page | Not run | | | |
| 9 | Photo of the phone About list and the Connect screen | Not run | | | |
| 10 | Photo of the Hebrew About screen; note from the Hebrew reader | Not run | | | |

History:

- -: **Not run**. New.


## Test 22

### Galaxy Protector (tilt, waves, upgrades)

Needs: 1 to 4 phones, 1 TV, and a child of about 5 to 8 years for item 9. Covers: REQ-AB-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Hold each phone upright or flat as you do for the other tilt games. New game (2026-10-16). Every number (ship speed, the rate of fire, the asteroid speeds, the waves, the upgrade times, the medal tiers) is a first guess.

**Steps**

1. Open the tile of **Galaxy Protector** with 1 phone. Check: the settings view opens with Difficulty on Medium. Start. Check the tile against the game.
2. Hold the phone steady in "3, 2, 1". Check: you can already move the ship, nothing falls and nothing fires, the name tags are over the ships, the hint line is readable, and at "GO!" the phone buzzes.
3. Tilt left and right. Check: the ship moves the same way, smoothly, and stops at the sides. Write down if it is too slow, too fast or too nervous (`SHIP_SPEED`, `SHIP_SMOOTH`). Press **RECENTER** and check that the ship stays still while the phone is held at the new rest pose.
4. Look at the shooting. Check: the ship fires by itself, the beams are easy to see in the color of the ship, the three sizes of asteroids are easy to tell apart, a large one needs 4 hits and breaks into two medium ones, a medium one into two small ones. Write down if the rate of fire feels too slow.
5. Wait for an upgrade. Check: it comes after about 10 s, it is easy to tell the shield (blue) from the weapon (orange), a shield makes a ring around the ship, a weapon adds a beam (up to 4). Take a weapon upgrade when the ship has 4 lasers, and a force field upgrade when the ship has a ring already: check that each gives 50 points and no change to the ship. Write down if upgrades come too often or too rarely.
6. Let an asteroid hit the ship with the ring. Check: the ring goes away, the asteroid is gone, the ship flies on, the phone buzzes. Let one hit the ship without a ring. Check: the ship blows up, the phone buzzes, and the other ships go on.
7. Play waves 1 to 6. Check: a wave is 30 s, then there is a rest of 5 s with "Wave N clear!" and "Next wave in N", the bar line shows the time left, each wave is harder (faster, more asteroids, more large ones) and the bonus points come at the end of a wave. Write down from which wave it is too hard for you, and if the first waves are too slow (Easy, Medium and Hard).
8. Play with 2, 3 and 4 phones. Check: the leader chip and every phone show the points and the place, the player with most points wins, and "Tie!" for equal points. When one player is out, the others go on and the banner "ALL SHIPS ARE GONE!" shows when the last ship is lost, and the game ends 2 s after that. With one player check the medal and "Reached wave N". Write down if it is too hard or too easy with 4 players, and how long a player waits after being out.
9. Let a child of about 5 to 8 years play, with a grown-up next to them. Check: the child understands what to do from the hint line, is not upset when the ship blows up, and wants to play again.
10. Leave the game on one phone during a wave. Check: its ship goes and the game goes on. With 1 phone left, leave: the "No players connected" menu opens.
11. Check the frame rate in the debug overlay with 4 phones on Hard in wave 8 or later (60 or close). (REQ-GM-50)
12. **Pixel world (REQ-GM-47i to 47n, REQ-AB-17).** From the sofa (about 3 m), look at the world. Check: the stars, the planet, the asteroids, the ships, the beams, the pickups and the explosions are made of sharp square pixels, the ships are easy to tell apart by color, a ship is not too small to follow, the banners are easy to read, and the music and the effects are fine (Test 18).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the settings view and of the tile | Not run | | | |
| 2 | Video of the countdown and GO | Not run | | | |
| 3 | Note: too slow, too fast or too nervous | Not run | | | |
| 4 | Video of the shooting; note on the rate of fire | Not run | | | |
| 5 | Video of an upgrade; note on how often they come | Not run | | | |
| 6 | Video of a hit with and without a ring; note on the buzz | Not run | | | |
| 7 | Note: the wave from which it is too hard, for each difficulty | Not run | | | |
| 8 | Photo of the result menu; note on 1, 2, 3 and 4 players | Not run | | | |
| 9 | Note: the child, the age, what happened | Not run | | | |
| 10 | Note: what happened on each leave | Not run | | | |
| 11 | Overlay screenshot (FPS) with 4 phones on Hard | Not run | | | |
| 12 | Photo of the screen from the sofa; note: sharp pixels, readable banners, the TV | Not run | | | |

History:

- -: **Not run**. New (2026-10-16).

## Test 23

### Pin Pals (bowling: aim with a turn, swing to throw)

Needs: 1 to 4 phones, 1 TV, and a child of about 5 to 8 years for item 11. Covers: REQ-BW-*, REQ-GM-80 to 84, REQ-GM-90 to 98, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-16). It was only tested with made-up sensor values. Every number (the swing thresholds 4, 8 and 30 m/s2, the aim ranges, the ball speeds, the lane, the pins, the medal tiers) is a first guess. Hold the phone in one hand like a ball, arm down at the side.

**Steps**

1. Open the tile of **Pin Pals** with 1 phone. Check: the settings view has Difficulty (Medium) and Rails (Off). Start. Check the tile against the game.
2. In "3, 2, 1" check the name tag, the hall (the lane, the 3 dimmer lanes on each side, the disco wall) and the score sheet at the bottom. Check that there is no leader chip. At the start of the turn the aim is in the middle of the lane, wherever the phone points.
3. **Aim.** Turn the phone left and right without a swing. Check: the aim mark follows, in the right direction, smoothly and without drift. Write down if the turn range is too small or too large for each difficulty (Easy 18, Medium 14, Hard 11 degrees) and if "turn" or "tilt" feels better for bowling.
4. **Swing.** Swing back, then forward. Check: the first back swing locks the aim (the mark stops), the ball goes at the end of the forward swing, the phone buzzes, and a hard swing gives a faster ball than a soft one. Try different grips (screen up, screen to the side) and the other hand. Write down every swing that did not throw, or threw when you did not mean to (first guesses: `BACK_ACCEL` 4, `FWD_ACCEL` 8, `FWD_FULL` 30 m/s2).
5. A very soft swing. Check: nothing is thrown, the hint "Swing a bit more!" shows, and you can try again with no time limit.
6. Play a whole game (10 frames) with 1 phone. Check: the rules are the standard ones (strike, spare, the 10th frame with 3 balls), the score sheet agrees with what you count, and the banners (Strike, Spare, Nice roll, Nice try, Oops) match what happened. Check the medal tiers on each difficulty.
7. **Rails** On. Check: a ball that is far to the side stays on the lane, there is no gutter ball, and the result menu has no personal best.
8. Play with 2, 3 and 4 phones. Check: the turns go frame by frame, a phone that is not on turn cannot throw, the name of the player on turn is on the plate, the score and place show on each phone, the winner and "Tie!" are right, and the wait for the other players is not too long (about 30 s with 4 players).
9. Look at the phones. Check: the phone on turn shows "YOUR TURN" and buzzes, the others show the name of the player on turn, and the line goes away in the result menu. (REQ-BW-14)
10. Leave the game on the phone that is on turn. Check: the game goes on with the next player. With 1 phone left, leave: the "No players connected" menu opens. (The pause of a lost phone is checked by A-23-10. Check on a real phone only that the swing starts again after the pause, REQ-BW-20.)
11. Let a child of about 5 to 8 years play on Easy with Rails, with a grown-up next to them. Check: the child understands the hint line, can throw, is not upset by a gutter ball or few pins, and wants to play again.
12. Check the frame rate in the debug overlay with 4 phones (60 or close). (REQ-GM-50)
13. **Pixel world (REQ-GM-47i to 47n).** From the sofa (about 3 m) check: the pins are easy to tell apart from the lane, the ball is easy to follow to the pins, the score sheet and the banners are easy to read, the disco wall is not too bright or too busy, and the music and the effects are fine (Test 18).

Item 14 moved to the automated tests (`docs/AUTOMATED_TESTS.md`, A-23-14). The numbers of the other items do not change.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the settings view and of the tile | Not run | | | |
| 2 | Photo of the countdown screen | Not run | | | |
| 3 | Note: aim range and direction, turn or tilt | Not run | | | |
| 4 | Video of swings; note on every missed or accidental throw, and the grips tried | Not run | | | |
| 5 | Note: what happened with a soft swing | Not run | | | |
| 6 | Photo of the score sheet after the game; note on the rules and the medal tiers | Not run | | | |
| 7 | Video of a ball with rails | Not run | | | |
| 8 | Photo of the result menu; note on 2, 3 and 4 phones and the wait | Not run | | | |
| 9 | Photo of the phones on turn and waiting | Not run | | | |
| 10 | Note: what happened on each leave | Not run | | | |
| 11 | Note: the child, the age, what happened | Not run | | | |
| 12 | Overlay screenshot (FPS) with 4 phones | Not run | | | |
| 13 | Photo of the screen from the sofa; note | Not run | | | |

History:

- -: **Not run**. New (2026-10-16).

## Test 24

### Swing detector for Tennis (debug overlay)

Needs: 1 to 2 phones, 1 TV with its remote. Covers: REQ-TN-5 to 9 (`docs/games/tennis.md`), REQ-T4. New (2026-10-17). Tennis was built after this test (Test 25). This test checks only the
swing detector (`scripts/input/swing_detector.gd`) as Tennis uses it (`PlayerInput`) with the line that the debug overlay shows for each player. A swing is a swing back and then a swing
forward, or a sharp push in any direction with no back swing. The thresholds (`BACK_ACCEL` 4, `FWD_ACCEL` 8, `FWD_FULL` 30 m/s2, all times 0.75 for Tennis; the back swing waits 3 s; a sharp push of 20 m/s2 times 0.75 for 0.03 s; the lock after a swing is 0.6 s) are first guesses, and you tune them from this test.

**Steps**

1. Join with 1 phone. Open the debug overlay (Menu key or F3, or Settings, Debug overlay). Check: under the table there is a line "P1 swing: none yet".
2. Hold the phone in your hand like a racket handle, still. Check: no swing appears. Walk around the room with the phone in your hand. Check: no swing appears.
3. Make a forehand: swing back, then forward, about as hard as a tennis stroke. Do 10 strokes. Check: the line shows `swing N` with a power and lights up for 1.5 s. Write down how many of 10 were found. Also try a sharp push of the phone with no back swing: it counts as a swing.
4. Make a soft, a medium and a hard stroke. Check: the power grows from soft to hard. Write down the powers. A very soft move must not be a swing.
5. Make a **serve**: toss, swing the phone back (up) and then forward from top to bottom. Check: the line says `DOWN`. Do 10 serves and write down how many say `DOWN`. Then a forehand from left to right. Check: it does not say `DOWN`.
6. Swing back and forward, then at once back again. Check: one swing is found, a stroke 0.4 s later is not found (the lock is 0.6 s), and a stroke 1 s later is found.
7. Shake the phone a little, or tap the table with it. Check: no swing is found.
8. Look at "hit N ms ago" in the swing line. Write down the values and the "Age ms" of the table (the delay of the phone, Test 4).
9. Repeat items 3 and 5 with 2 phones at the same time. Check: each phone has its own line and the swings do not mix.
10. (iPhone, if you have one) Repeat items 3 and 5. Check: the same results. Write down if `DOWN` is wrong on the iPhone (the sign of the accelerometer, Test 13 item 3).
11. Press RECENTER while you point at the TV. Swing a forehand to the right, to the left and straight at the TV, 10 times each. Check: the `side` value of the swing line is positive, negative and near 0. A nearly vertical swing gives a side near 0. Write down the values (REQ-TN-7).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the overlay | Not run | | | |
| 2 | Note: any swing found by walking | Not run | | | |
| 3 | Note: strokes found of 10, the power | Not run | | | |
| 4 | Note: the power of a soft, medium and hard stroke | Not run | | | |
| 5 | Note: serves with `DOWN` of 10; the other direction | Not run | | | |
| 6 | Note: one swing or two; the stroke after 0.5 s | Not run | | | |
| 7 | Note: any swing found by a shake or a tap | Not run | | | |
| 8 | Note: the values in ms, the Age ms | Not run | | | |
| 9 | Photo of the overlay with 2 phones | Not run | | | |
| 10 | Note: the iPhone result | Not run | | | |
| 11 | Note: the side values for a swing to the left, to the right and straight | Not run | | | |

History:

- -: **Not run**. New (2026-10-17).

## Test 25

### Tennis (swing, toss, serve, rally, scoring)

Needs: 1 to 4 phones, 1 TV, and a child of about 5 to 8 years for item 12. Covers: REQ-TN-* (`docs/games/tennis.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-17). It was only tested with made-up sensor values. Every number (the swing thresholds of Test 24, the hit window of 0.55 s, the green half width of 0.30, 0.21 and 0.15 s, the ball speeds, the medal tiers) is a first guess. Do Test 24 first: Tennis uses the same swing detector. Hold the phone like a racket handle, with the screen toward you. The direction of the swing sends the ball: swing toward the right of the TV and the ball goes right, toward the left and it goes left (changed 2026-10-18: the tilt did not work). The first run (2026-10-18) found swings that were not detected and shots that mostly went left for a right-handed player: check both again (items 3, 4 and 6).

**Steps**

1. Open the tile of **Tennis** with 2 phones. Check: the settings view has Difficulty (Medium) and Scoring (Real). Start. Check the tile against the game.
2. In "3, 2, 1" check the name tags above the characters, the court (the real lines, the net, the umpire chair, the ball kid at the left net post, the stands, the blank ad boards) and that there is no leader chip.
3. **Serve.** Check: the hint "PRESS A TO TOSS. SWING DOWN TO SERVE! SWING TO A SIDE TO AIM." shows, A of the server tosses the ball, a swing from top to bottom at the top of the toss serves, and the phone buzzes. Try a swing too early, too late and from left to right. Check: a swing that is not a serve does nothing, and when the ball falls the server tosses again.
4. **Return.** Check: the ball glows when it is your turn, the ring on the court shows the place of the hit (yellow, green in the green part), the character runs by itself, and a swing near the ring returns the ball. A swing when the ball is not near does not touch the ball, but the character still swings its racket. A gentle back swing then a sharp push hits, and a slow wide swing also hits. Write down the real delay between the swing and the hit.
5. **Timing.** Swing in the green part, too early and too late. Check: green gives a fast shot with "GREAT!", too early and too late give a slow high lob that stays in play. Write down if the green part is too short or too long for each difficulty.
6. **Power and aim.** Swing soft and hard, and swing to the left and to the right of the TV, also straight at the TV and nearly straight up. Check: a hard swing is faster and longer, a soft swing is short, a swing to the right sends the ball to the right and a swing to the left sends it to the left (the far team is mirrored: its own right), a straight swing goes to the middle, and a strong swing may go out on Medium and Hard but not on Easy. The hint line says to swing to a side to aim, and a player can tell how to aim from the hint line alone. Write down any swing that went to the wrong side.
6b. **Far out and far behind (REQ-TN-4).** Aim wide and long with a hard swing so the other player has to run to the side line and behind the baseline (also with 4 phones). Check: the character stays fully on the screen (not cut at the side or the bottom) and the swing still counts. Write down any ball or character that still leaves the picture.
7. **Real scoring.** Play a whole match with 2 phones. Check: 0, 15, 30, 40, deuce and advantage, the first to 3 games wins, the server changes after every game, the banners (point, game, fault, out, net) match what happened, and the result menu names the winner. Write down how long the match took.
8. **Quick scoring.** Set Scoring to Quick and play. Check: the first to 5 points wins, the server changes every 2 points.
9. Play with 3 phones (2 against 1 on the regular court, the single player changes after every game) and with 4 phones (2 against 2, the pairs take turns). Check: the court size is the same, the names and colors on the scoreboard are right, and each phone shows its own place.
10. Play with 1 phone (the pink ball machine). Check: the machine sends a ball, the rally and the best rally count, the 90 s timer runs, and the result menu shows a medal (Easy 4, 8, 14, Medium 5, 10, 20, Hard 6, 14, 28 hits in a row).
11. Leave on one phone during a match (4 phones, then 2 phones). Check: with 4 phones the match goes on with 3 players; with 2 phones the other player wins at once. (The pause with the card and the ignored swing after it are checked by A-25-11.)
12. Let a child of about 5 to 8 years play on Easy with a grown-up next to them. Check: the child understands the hint line, can serve and return, is not upset by a missed ball, and wants to play again.
13. Check the frame rate in the debug overlay with 4 phones (60 or close). (REQ-GM-50)
14. **Pixel world (REQ-GM-47i to 47n).** From the sofa (about 3 m) check: the ball and its shadow are easy to follow, the far characters can be told apart, the scoreboard and banners are easy to read, and the stands are not too busy.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the settings view and of the tile | Not run | | | |
| 2 | Photo of the countdown screen | Not run | | | |
| 3 | Video of a toss and a serve; note on swings that did nothing | Not run | | | |
| 4 | Note: the delay swing to hit in ms | Not run | | | |
| 5 | Video of a green, an early and a late swing; note on the green part | Not run | | | |
| 6 | Video of soft, hard, left and right shots; note on the swing side | Not run | | | |
| 6b | Video of a player who runs far out and far behind the baseline | Not run | | | |
| 7 | Photo of the result menu; note: the time of the match | Not run | | | |
| 8 | Note: Quick scoring | Not run | | | |
| 9 | Photo of the scoreboard with 3 and 4 phones | Not run | | | |
| 10 | Photo of the solo screen and the medal; note on the tiers | Not run | | | |
| 11 | Note: what happened on each leave and on the lock | Not run | | | |
| 12 | Note: the child, the age, what happened | Not run | | | |
| 13 | Overlay screenshot (FPS) with 4 phones | Not run | | | |
| 14 | Photo of the screen from the sofa; note | Not run | | | |

History:

- -: **Not run**. New (2026-10-17).

## Test 26

### Mini Golf (aim, putt power, turns, 5 holes)

Needs: 1 to 4 phones, 1 TV, and a child of about 5 to 8 years for item 12. Covers: REQ-MG-* (`docs/games/mini_golf.md`), REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n.

New game (2026-10-17). It was only tested with made-up sensor values. Every number (the swing thresholds of Test 24, the putt speeds, the friction of the grass, the 5 course designs, the aim line lengths, the medal tiers) is a first guess. Do Test 24 first: Mini Golf uses the same swing detector. Hold the phone like a putter, with the screen toward you: turn it left and right to aim, swing it back and then forward to putt.

**Steps**

1. Open the tile of **Mini Golf** with 2 phones. Check: the settings view has Difficulty (Medium) and Holes (3 HOLES). Start. Check the tile against the game.
2. In "3, 2, 1" check the name tags, the course (lawn, fence, clubhouse, bushes, the walls of the hole), the bar with all players at the bottom and the hole line (HOLE 1/3 PAR 2) at the top right.
3. **Turn.** Check: only the golfer of the player on turn and a white ball are on the course, the shirt has the color of the player (cap, trousers and shoes white), "<NAME>'S TURN!" shows for about 1.5 s, the other phone shows "<NAME> IS PUTTING" and the phone on turn shows YOUR TURN.
4. **Aim.** Turn the phone left and right. Check: the aim mark follows the direction smoothly and not too fast or slow, RECENTER sets straight ahead, and the direction locks when you swing back (the mark turns gold). Write down if the turn range feels right.
5. **Power.** Putt with a soft, a medium and a hard swing. Check: the ball goes short, medium and far, the golfer swings through at the hit, the phone buzzes, and a small movement is not a putt. Write down the delay between the swing and the ball moving, and if a normal putt goes too far or too short.
6. **Turn order.** With 2 and 4 phones check: each player putts once, in slot order, and the balls stay where they stopped. A player who is in the hole is skipped.
7. **Obstacles.** On all 5 holes check: walls bounce the ball, the brick walls (holes 1, 2, 3 and 5), the windmill block (holes 2 and 5) and the rocks (all holes) bounce it, the turning blades (holes 2, 4 and 5) push it, the sliding barriers (holes 3 and 5) can be timed and never block the whole course, and the lake (holes 2 and 4) gives a splash unless the ball crosses the bridge and sends the ball back to the last spot (no extra stroke is counted besides the putt). Write down any hole that is too hard or too easy.
8. **Holes and words.** Play 5 holes (set Holes to 5). Check: BIRDIE, PAR, BOGEY, HOLE IN ONE and "Picked up after 6 strokes" show at the right strokes, the card at the end of each hole has the strokes of the hole and the total, A skips it, and the bar counts the strokes.
9. **Difficulty.** Play a hole on Easy, Medium and Hard. Check: Easy has a long aim line and the hint about the swing and a weak swing still moves the ball far, Medium a short line, Hard only the marker. The courses are the same.
10. **Result.** Finish a match with 2 phones, then alone. Check: the result menu has the winner (or TIE) and, alone, a medal (gold at par or better, silver at most 1 over par per hole, bronze at most 2 over). Try again, New game and Back to menu work. Write down how long a 3 hole match took.
11. Leave on one phone during a hole (4 phones, then 2 phones). Check: the turn goes on to the next player. (The pause with the card is checked by A-26-11. Check on a real phone only that a swing under way starts again after the pause.)
12. Let a child of about 5 to 8 years play on Easy with a grown-up next to them. Check: the child understands the hint line, can aim and putt, is not upset by water or by a long hole, and wants to play again.
13. Check the frame rate in the debug overlay with 4 phones (60 or close). (REQ-GM-50)
14. **Pixel world (REQ-GM-47i to 47n).** From the sofa (about 3 m) check: the ball is easy to follow also far away, the golfer and the windmill are easy to tell apart, the bar and the banners are easy to read.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the settings view and of the tile | Not run | | | |
| 2 | Photo of the countdown screen | Not run | | | |
| 3 | Photo of a turn on the TV and on both phones | Not run | | | |
| 4 | Note: the turn range of the aim, RECENTER | Not run | | | |
| 5 | Video of soft, medium and hard putts; note: the delay in ms | Not run | | | |
| 6 | Note: the order with 2 and 4 phones | Not run | | | |
| 7 | Video of the windmill, a brick wall, a turning blade, a rock, a sliding barrier, the lake and the bridge; note on the holes | Not run | | | |
| 8 | Photo of the card of a hole and of each banner | Not run | | | |
| 9 | Photo of the aim on each difficulty | Not run | | | |
| 10 | Photo of the result menu and the medal; note: the time of a match | Not run | | | |
| 11 | Note: what happened on each leave and on the lock | Not run | | | |
| 12 | Note: the child, the age, what happened | Not run | | | |
| 13 | Overlay screenshot (FPS) with 4 phones | Not run | | | |
| 14 | Photo of the screen from the sofa; note | Not run | | | |

History:

- -: **Not run**. New (2026-10-17).
