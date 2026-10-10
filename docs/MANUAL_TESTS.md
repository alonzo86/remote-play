# Manual tests

The tests that only a person with real devices can do: phones, a TV or a TV box, a remote control, a camera.
This file holds **all** of them: the steps, the result of every step, and the evidence. The headless tests (`tests/`) do not replace them.
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
- Before every run: the current APKs are installed, **Invert tilt axes** is off, and the TV and the phones are on the same Wi-Fi.

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
| [1](#test-1) | Start and join | 1 phone, 1 TV | REQ-T1, REQ-FL-5 to 10 | Retest (design change) | R1 | |
| [2](#test-2) | QR scan (plugin, unverified) | 1 phone, 1 TV | RISKS C5 | Pass | R0 | |
| [3](#test-3) | Sensor directions | 1 phone, 1 TV | RISKS A2 | Retest | R0 | |
| [4](#test-4) | Latency and packet rate | 1 to 4 phones, 1 TV, a phone camera (240 fps) | RISKS A1, A3, B1, B2 | Fail | R0 | |
| [6](#test-6) | Tilt maze feel | 1 to 4 phones, 1 TV | REQ-MZ-4, REQ-MZ-6, REQ-MZ-8, REQ-MZ-9, REQ-GM-37, REQ-GM-90 to 95 | Partial (items 1 to 3 Pass, 4 to 6 not run) | R1 | |
| [7](#test-7) | Disconnect and reconnect | 2 phones, 1 TV | REQ-GM-30, REQ-GM-30a, REQ-FL-25, REQ-MR-14, REQ-MZ-8 | Fail (item 1, fixed, retest) | R1 | |
| [8](#test-8) | TV remote | 1 phone, 1 TV with its remote | REQ-GM-31, REQ-GM-31a, REQ-GM-33, REQ-FL-41, REQ-FL-55 | Fail (items 2 and 3, fixed, retest) | R1 | |
| [8b](#test-8b) | The TV flow and the style | 1 to 2 phones, 1 TV (item 7 moved to Test 17) | REQ-FL-1 to 46, REQ-FL-54, 56, 57, FD-1 to 17 | Fail (items 2 and 7, fixed, retest) | R1 | |
| [9](#test-9) | Marble race (3D) | 2 to 4 phones, 1 TV | REQ-MR-*, REQ-3D-*, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50 | Not run |  | |
| [10](#test-10) | Snowball Splat (pointer) | 1 to 4 phones, 1 TV, a child for item 9 | REQ-SS-*, REQ-GM-80 to 84, RISKS A4, REQ-GM-37, REQ-GM-50 | Fail (first version, redesigned), score chip fixed, retest | R2 | |
| [11](#test-11) | Result menus (REQ-GM-72) | 1 to 4 phones, 1 TV | REQ-GM-34, REQ-GM-40, REQ-GM-41, REQ-GM-72, REQ-GM-73, REQ-MZ-5, REQ-MR-31 | Not run |  | |
| [12](#test-12) | Game tiles and the toy box look (REQ-GM-49) | 1 TV (phones for the game photos) | REQ-GM-49, REQ-FL-20, REQ-FL-40, REQ-GM-41 | Not run |  | |
| [13](#test-13) | Controller on an iPhone | 1 iPhone, 1 Mac with Xcode, 1 TV | `tools/deploy-ios.sh`, RISKS A2 | Not run |  | |
| [14](#test-14) | Paint Grab (tilt) | 1 to 4 phones, 1 TV, a child for item 7 | REQ-PG-*, REQ-GM-80 to 84, 90 to 97, REQ-GM-50 | Not run |  | |
| [15](#test-15) | Sumo Bumpers (tilt and A) | 2 to 4 phones, 1 TV, a child for item 8 | REQ-SB-*, REQ-GM-80 to 84, 90 to 97, REQ-GM-50 | Not run |  | |
| [16](#test-16) | The arcade look (phase 1) | 1 to 4 phones, 1 TV on 1080p (and a 4K TV if you have one), a child for item 8 | REQ-FL-37 to 46, REQ-FL-41a, 52, 53, REQ-GM-45, 46, FD-18 | Not run |  | |
| [17](#test-17) | Hebrew and right to left (phase 5) | 2 phones (one set to Hebrew), 1 TV (once set to Hebrew, once to English) | REQ-FL-54, 60 to 63, REQ-GM-47o, FD-19 | Not run |  | |
| [18](#test-18) | Sound and haptics | 1 to 4 phones, 1 TV | REQ-FL-64 to 66, REQ-GM-49a to 49c, REQ-GM-43 | Not run | | |
| [19](#test-19) | Leader chip, phone score and name tags | 2 to 4 phones (names of 10 letters), 1 TV, a child for item 8 | REQ-FL-67, REQ-GM-46, 46a, FD-21 | Not run | | |
| [20](#test-20) | Player profiles (phases A and B: names, avatars, copy by QR) | 2 to 4 phones, 1 TV, a child for item 7 | REQ-FL-69 to 75, REQ-N8, REQ-C7 to C9, FD-22 | Not run | | |

Test 5 (pointer drift) was removed on 2026-10-07 with the old pointer test. The pointer is checked again in Test 10.

## Test 1

### Start and join

Needs: 1 phone, 1 TV. Covers: REQ-T1, REQ-FL-5 to 10.


**Steps**

1. Start the TV app. Check: the app is named **Wobble TV** in the launcher (uninstall the old Remote Play apps first: the package names changed, FD-21). The Android splash shows the pixel phone mascot on black, then the logo screen with the mascot and the word WOBBLE (sharp pixels, not blurred) and an animation (about 2.5 seconds), then the **Connect controllers** screen with a room code and a QR code. If the QR code is empty, the TV has no Wi-Fi address (the screen says so).
2. Start the controller app on one phone. Check: it is named **Wobble Controller**, and the phone shows a **portrait** screen with the title WOBBLE.
3. Join with the **TV list** (tap the TV). Check: the phone shows "Waiting for the host" with a colored player circle, the TV shows the phone in slot 1 as "READY", and the line **Press OK to continue** shows at the bottom (there is no Continue button and no player count). Press OK. Check: the TV shows the Games screen and the phone says "Choose a game on the TV".
4. Tap **Leave**, then tap the TV under **Discovered TVs**. Check: it joins (the button reads "<code> x/y", for example "KQZM 1/4", and it is green; **Refresh** is yellow). Tap **Refresh**. Check: the list shows "Searching..." and the TV is back within 2 seconds.
5. Tap **Leave**, then join with the **TV IP address**. Check: it joins.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the TV (splash, logo, Connect screen) and the phone (portrait) | Not run | | | |
| 2 | Photo of the phone in portrait | Not run | | | |
| 3 | Photo of TV and phone together: slot 1 'READY' and the line 'PRESS OK TO CONTINUE'; then the Games screen | Retest | R1 | Chat report 2026-10-09 (no file) | R1: the owner found the Continue button redundant (it was the only focus target) and the count of players repeated the slot list. Changed on 2026-10-09 (FD-17, REQ-FL-6, 7): the button and the count are gone, and 'PRESS OK TO CONTINUE' shows once a phone has joined. The old check cannot pass any more. Retest the new screen. |
| 4 | Photo of the phone list with the button '<code> x/y'; note the time Refresh takes | Not run | | | |
| 5 | Phone screenshot after joining by IP | Not run | | | |

History:

- R1: **Retest** (step 3). Design change after the first run on a real Android TV. See the row of step 3.
- R0: **Fail**. Join by room code failed with 'Room YCNW not found, is the tv on the same wi-fi?'. The list and the IP worked. TV app on a desktop, phone on the same Wi-Fi. The plan has no join by room code now, so every step needs a retest.

## Test 2

### QR scan (plugin, unverified)

Needs: 1 phone, 1 TV. Covers: RISKS C5.


**Steps**

1. Tap **Leave**. On the connect screen, the button must say **Scan QR code**. If it says **Paste TV link**, the plugin is not in the build. Run `tools/patch_android_manifest.sh` and export again.
2. Tap the button and scan the QR code on the TV. Check: the phone joins in less than 5 seconds.
3. Scan again and press Back in the scanner. Check: no error message and the app does not crash.
4. Optional: put a different QR code in front of the phone (for example a web link). Check: the message "This is not a Wobble code".

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

Open the debug overlay on the TV (Menu key, or the menu item). Hold the phone in portrait with the screen toward you.

| Action | Expected raw values / result |
|--------|------------------------------|
| Phone flat, screen up, still | `Accel` about `0 0 +9.8` |
| Right side down | `Accel x` negative. In the maze, the ball rolls right |
| Top of phone up | `Accel y` positive. In the maze, the ball rolls toward you (down on the TV) |
| Turn the phone to the left (like turning on a table) | `Gyro z` positive (raw value only. No game uses the yaw now) |

If a direction is wrong, use **Invert tilt axes** on the **Settings** screen of the TV (the gear on the Games screen). Write down which one you needed.


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

Needs: 1 to 4 phones, 1 TV, a phone camera (240 fps). Covers: RISKS A1, A3, B1, B2.

Use the overlay. Keep the phone still for 30 seconds, then move it for 30 seconds.

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

### Tilt maze feel

Needs: 1 to 4 phones, 1 TV. Covers: REQ-MZ-4, REQ-MZ-6, REQ-MZ-7, REQ-MZ-8, REQ-MZ-9, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-90 to 95.


**Steps**

1. Start **Tilt Maze** with 1 phone. Hold the phone level in the countdown.
2. Finish the maze. Write down: does the ball feel too light, too heavy, or good? Is the deadzone good (the ball does not creep when the phone is level)?
3. Tune the constants in `scripts/game/maze/maze_game.gd` (`TILT_ACCEL`, `FRICTION`, `DEADZONE`) if needed.
4. Repeat with 2 to 4 phones. Check *Rx Hz* and *Gap ms* for all players during the race.
5. Tilt the phone, then tap **RECENTER**. Check: the ball stops creeping. Tap **A** and **B**. Check: nothing changes (A and B do not recenter, REQ-MZ-8). At GO the phone recenters by itself.
6. Open the tile of **Tilt Maze**. Check: the settings view opens with Difficulty on Medium, and Back (left) and Start (right) are on one line at the bottom. With the remote, press Left and Right on the Difficulty row (it must stop at Easy and at Hard). Play one round on each of Easy, Medium and Hard. Check: Easy is a small maze, Hard is big and winding, the whole board is on the screen, and the ball does not feel stuck in the narrow corridors of Hard. After the round, the result menu has **Settings**, and it returns to the view with the last choice. In the view, press Back on the remote: it returns to the Games screen (the app does not close). With the only phone connected, switch its Wi-Fi off while the view is open: after about 5 seconds Start is dimmed and a yellow line says "Needs 1 player". Switch Wi-Fi on again: Start works again.
7. **Pixel world (phase 4, REQ-MZ-7).** From the sofa (about 3 m), look at the maze on Medium and Hard. Check: the walls, the balls and the exit are sharp square pixels, the walls are easy to see on the board, the slot numbers on the balls are easy to read, and the white ring of the exit blinks in a hard step. The walls are 12 px now (before: 10 px) and Hard has cells of 76 px (before: 78 px): check that the ball does not feel stuck in the narrow corridors of Hard.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Note: the phone is level in the countdown | Pass | R1 | Chat report 2026-10-09 (no file) | R1: the owner played the maze and reported 'it works perfectly'. The steps of the countdown were not reported one by one. |
| 2 | Note: ball too light, too heavy or good; deadzone good or not. Short video | Pass | R1 | Chat report 2026-10-09 (no file) | R1: 'i tested the maze game and it works perfectly'. The feel is good on the TV. The number of phones was not written down (step 4 is still open). |
| 3 | If constants changed: the commit or the diff | N/A | R1 | Chat report 2026-10-09 (no file) | R1: no tuning is needed, because the owner reported no problem. The constants are unchanged. |
| 4 | Screenshot of the debug overlay for every player during the race | Not run | | | |
| 5 | Video of the ball: creeping, then RECENTER, then A and B | Not run | | | |
| 6 | Photos of the settings view and of the maze on Easy, Medium and Hard; note on the sizes and the corridors | Not run | | | Added 2026-10-09 (REQ-MZ-9). The sizes in `LEVELS` are first guesses. |
| 7 | Photo of the maze from the sofa; note: sharp pixels, readable numbers, the ball in the corridors of Hard | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). |

History:

- 2026-10-10 (not run): item 7 is new: the maze world is a pixel world (phase 4 of the arcade style), walls 12 px, Hard cells 76 px.
- 2026-10-09 (not run): item 6 is new (REQ-MZ-9, REQ-GM-90 to 97): the settings view, the three difficulties, the yellow chosen value, Back and Start on one line, and Start dimmed when no phone fits.
- R1: items 1 to 3 **Pass** (the owner: 'it works perfectly'). Items 4 and 5 are not run: 2 to 4 phones, and RECENTER with A and B.
- R0: **Retest**. First run: drift and inverted controls (caused by 'Invert tilt axes' being on). After the fix the maze looks good on the desk. The feel and the constants were not judged. Item 5 is new (RECENTER, and A and B do nothing).

## Test 7

### Disconnect and reconnect

Needs: 2 phones, 1 TV. Covers: REQ-GM-30, REQ-GM-30a, REQ-FL-25, REQ-MR-14, REQ-MZ-8.


**Steps**

1. With two phones joined, during the maze, switch one phone Wi-Fi off for 15 seconds, then on. Check: within about 5 seconds the TV pauses and shows the card "2P LOST CONNECTION" with **Resume without P2** and **End game**, and the phone shows "Reconnecting...". When the phone is back, the card says "P2 reconnected" with **Resume**. The game goes on only when you press **Resume**.
2. Lock the phone screen for 10 seconds, then unlock. Check: the phone reconnects. (Android can stop the app in the background.)
3. Switch the phone Wi-Fi off for 40 seconds. Check: the slot is freed. When the Wi-Fi is back, the phone joins again (maybe in a different slot).
4. Switch one phone Wi-Fi off again and wait for the card. Choose **Resume without P2** (for a player with a profile the card says its name, test 20 item 6). Check: the game continues without that player. Switch the Wi-Fi on. Check: the phone joins again as a new player and waits for the next round.
5. With only one phone joined, switch its Wi-Fi off during the maze. Check: within about 5 seconds the game pauses with the card "1P LOST CONNECTION" that has only **End game** (no Resume, because nobody is connected). Switch the Wi-Fi on. Check: the card says "P1 reconnected" and offers **Resume**. Do the same in the marble race and in Snowball Splat. Press Back on the card. Check: it asks "End the game?".
6. On the phone pad, tap **Leave** once. Check: it turns red ("AGAIN") for 3 seconds and the phone does not leave. Tap again within 3 seconds: it leaves. Check the pad buttons: A is green and B is red, both sink when pressed.
7. Phone call: with one phone in a game, call that phone from another phone and answer. Check: the game pauses with the card. End the call and go back to the controller app. Check: the phone says "Reconnecting..." and then joins again, the card says "P1 reconnected" with **Resume**, and **Resume** goes on with the game. Try a call that lasts more than 1 minute (the slot is kept 5 minutes while the game is paused). Write down how long the phone needs to reconnect after the call. (REQ-GM-30, 30a)

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Video of TV and phone: the card, 'Reconnecting...', then Resume | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the phone disconnected from the Wi-Fi and showed 'Reconnecting...', but on the TV the game kept going (no pause, no card). The off time was not written down (it must be more than 5 s). Cause (found on 2026-10-09): the TV waited for a close handshake that a phone with no Wi-Fi cannot answer, so it never marked the phone lost. The same failure was seen in R0. Fixed on 2026-10-09 (a silent phone is lost at once, PROTOCOL.md) and the pause changed (REQ-GM-30). A test now reproduces it. Retest. |
| 2 | Note: did the phone reconnect | Not run | | | |
| 3 | Photo of the Connect or Games screen after 40 s and after the join again | Not run | | | |
| 4 | Video: Resume without P2 with a lost phone, and the phone that joins again | Not run | | | |
| 5 | Photo of the card of the only player lost (End game only), and of the card after the return (Resume); in the maze, the race and Snowball Splat | Retest | R1 | Chat report 2026-10-09 (no file) | R1: a phone call stopped the game ('as expected') and the TV showed 'No players connected'. After the call there was no way to resume. The owner asked for a message that says which player disconnected, with Resume only when a player is still connected or the disconnected player is back. Changed on 2026-10-09 (REQ-GM-30, 30a): the game waits with a card, there is no Resume while nobody is connected, and Resume shows when the phone is back. The slot is kept 5 minutes while paused. The old check ('No players connected' at once) is gone. Retest. |
| 6 | Photo of the red Leave button ('Again'), and of the pad buttons | Not run | | | |
| 7 | Video of a phone call: the card, the return, Resume. Note how long the phone needs to reconnect | Not run | | | |

History:

- R1: **Fail** (item 1) and **Retest** (item 5). A phone without Wi-Fi did not pause the game, and a phone call ended it with no way to resume. Both changed on 2026-10-09 and wait for the retest. Items 2, 3, 4 and 6 are not run.
- R0: **Retest**. Wi-Fi off on the phone: the phone shows 'Reconnecting...'. The game kept running and the TV never showed 'Waiting for P1 to reconnect'. Wi-Fi on: the phone reconnected and the game went on. The off time was not measured (the TV pauses only after 5 s of silence). Item 6 (Leave twice, A green and B red) is new.

## Test 8

### TV remote

Needs: 1 phone, 1 TV with its remote. Covers: REQ-GM-31, REQ-GM-31a, REQ-GM-33, REQ-FL-41.


**Steps**

1. Use only the remote. Check that the D-pad moves the focus on every screen (tiles, badge, gear, buttons) and OK selects. A focused button has a thick black border and lifts (a longer shadow); a focused game tile grows wide and shows its description. Check that the border is visible from the sofa on every button, also on the purple rows. Press and hold OK on a button: it sinks (no shadow). The layout of the buttons does not move.
2. In a game, press OK. Check: the pause menu opens with Resume, Restart, and Back to menu. Choose Back to menu, and also press Back during play. Check: both ask "End the game?" with **Keep playing** (green, in focus) and **End game** (red). The game is paused. Back on the question keeps playing. **End game** goes to the Games screen. After the game is over (result menu), Back leaves at once.
3. Press Back in a game and choose **End game**: back to the Games screen. Press Back on the Games screen: the Connect screen (the players stay). Press Back on the Connect screen: the quit question opens, with **Stay** in focus.
4. Check the Menu key. If the remote has no Menu key, open **Settings** (the gear on the Games screen) and use **Debug overlay**.
5. Check: the app icon and banner show in the Android TV home row (the banner is the TV, the maze and the phone).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Video of the remote moving the focus on every screen, with the focus border visible | Not run | | | |
| 2 | Video of the pause menu and the 'End the game?' question | Fail | R1 | Chat report 2026-10-09 (no file) | R1: pressing Back on the remote in the middle of a game quits the app completely. The 'End the game?' question was not seen. Cause: the engine setting `quit_on_go_back` was on, so the engine quit after the app had handled Back. Fixed on 2026-10-09 (REQ-FL-55). Retest. The OK key and the pause menu were not reported. |
| 3 | Video or photos of Back on the Games, Connect screens and the quit question | Fail | R1 | Chat report 2026-10-09 (no file) | R1: Back quits the app on every screen. The owner saw the app go back to the previous view for a moment before it closed. Same cause and fix as item 2. Retest. |
| 4 | Photo of the overlay after the Menu key, or of the Settings switch | Not run | | | |
| 5 | Photo of the TV home row with the icon and banner | Not run | | | |

History:

- R1: **Fail** (items 2 and 3). Back quits the app on every screen. Fixed on 2026-10-09 (REQ-FL-55). Items 1, 4 and 5 are not run.
- Item 2 changed before the first run (the 'End the game?' question).

## Test 8b

### The TV flow and the style

Needs: 1 to 2 phones, 1 TV. Covers: REQ-FL-1 to 46, REQ-FL-56, 57, FD-1 to 17. Item 7 (a TV set to Hebrew) moved to Test 17 on 2026-10-10: FD-19 replaced REQ-FL-54, so the TV now offers Hebrew and no longer stays English.


**Steps**

1. Start the TV app from cold. Check: the logo screen goes on by itself after about 2.5 seconds, and OK skips it. Back on the logo screen does not quit.
2. On the Games screen, with one phone joined, check that every tile shows its screenshot, title and player range, and that the text is readable from the sofa (REQ-FL-40).
3. Open the **players badge** (OK). Check: the modal shows the slots, a QR code and the room code. Press **Remove** on a player. Check: the phone says that the host removed it and does not reconnect by itself. Join again with the QR code. Check: the slot fills again.
4. Join a phone while a game runs. Check: the phone says "A round is running", it does not take part, and it joins the next round.
5. Check the motion on the TV box: the logo (with its confetti), the blinking prompts and the screen changes run at 60 frames per second (overlay FPS). Check that the arcade colors look right on your TV (black is black, yellow and blue are not washed out).
6. Phone: check that the fonts and the colors match the TV on the connect, waiting and pad screens.
7. (Moved to Test 17.) The old step was: set the TV to Hebrew, region Israel, and check that the app stays English and left to right. FD-19 replaced that rule on 2026-10-10: the app now has Hebrew, and the result of R1 (the mirrored English UI) is not a defect any more.

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

History:

- R1: **Fail** (items 2 and 7). The tile screenshots are missing, and the layout is mirrored on a TV set to Hebrew. Both changed on 2026-10-09 and wait for the retest. The other items are not run.

## Test 9

### Marble race (3D)

Needs: 2 to 4 phones, 1 TV. Covers: REQ-MR-*, REQ-3D-*, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Needs 2 to 4 phones. Requirements: `docs/games/marble_race.md`. Start "Marble Race" and pick a track.


**Steps**

1. Check: the TV shows the track from above, the order list at the top left, and the track name at the bottom right. All text is inside the screen edge and can be read from the sofa. (REQ-MR-9, REQ-MR-35)
2. Check: during "3, 2, 1" the marbles do not move when you tilt. At "GO!" every phone buzzes. (REQ-MR-3)
3. Tilt right: the marble goes right on the screen. Tilt the top of the phone up: the marble goes down on the screen. (REQ-3D-6)
4. Check the feel. Write down if the marble is too slow, too fast, or too nervous. (`ACCEL`, `DAMPING`)
5. Hit a wall, a post and another marble at speed. Check: the phone buzzes, not more than 6 times a second. (REQ-MR-13)
6. Check: the frame rate in the debug overlay is 60 (or close) with 4 phones on Hard. (REQ-GM-50)
7. Let one marble run far ahead on a long track (Hard). Check: when the last marble leaves the view, an arrow in its color shows at the screen edge with a distance, and you can read it. (REQ-MR-42)
8. Finish a race on 3 different tracks of the list and on the random track. Write down the winning time of each. (REQ-MR-51)
9. Open the tile of **Marble Race**. Check: the settings view shows Difficulty (Left and Right) and, under it, a carousel of tracks (10 line sketches and a "?", no names), wider than the Difficulty row, with the selected track in the middle. Move the carousel with Left and Right (the track in the middle is the one you get), then Start. Check: the race has the track of the sketch. Play Easy, Medium and Hard on one track. Check: the line is the same and there are few, some and many posts. Choose the "?" tile twice: the tracks are different. Restart: the same track again. (REQ-MR-50 to 54)
10. During a race, open the pause menu. Check: it has Resume, Restart and Back to menu only. (REQ-MR-32)
11. After a change to the shared game code (the countdown clock, the buzz cool-down, the end with no players), run this test again with 2 phones on each track. Check: the countdown, the buzz at GO, the buzz limit (item 5), a player who leaves (the race goes on) and the last player who leaves (the menu "No players connected") all work as before. Tap **RECENTER** during a race: the marble stops drifting.
12. **Pixel world (phase 3, REQ-MR-44, REQ-GM-47i to 47n).** From the sofa (about 3 m), look at the race. Check: the track, the posts and the marbles are made of sharp square pixels (not blurred), each marble has a black outline and its number is easy to read on it, and the posts and marbles are easy to tell apart on the purple track. Fly the camera high (let one marble run far ahead): the small marbles have no number, and you can still follow them by color. Write down the frame rate with 4 phones on Hard (it should be the same or better than before) and the TV (1080p or 4K).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the race screen (order list, track name) | Not run | | | |
| 2 | Video: marbles still in the countdown, GO buzz noted | Not run | | | |
| 3 | Video: tilt right and tilt up | Not run | | | |
| 4 | Note: too slow, too fast or too nervous | Not run | | | |
| 5 | Note: count the buzzes in one second at a wall, a post and a marble | Not run | | | |
| 6 | Overlay screenshot (FPS) with 4 phones on Gauntlet | Not run | | | |
| 7 | Photo of an edge arrow with its distance | Not run | | | |
| 8 | Winning time for each track (fill the table in the test) | Not run | | | |
| 9 | Photo of the settings view; video of choosing a track and of Easy, Medium and Hard; note on the generated tracks (any bad bends or corners where a marble gets stuck) | Not run | | | Changed 2026-10-09: the four hand-made tracks were replaced by generated tracks. |
| 10 | Photo of the pause menu | Not run | | | |
| 11 | Video of a full race on one track and notes for every check in the item | Not run | | | |
| 12 | Photo of the race from the sofa; note: sharp pixels, readable numbers, the frame rate and the TV | Not run | | | |

Winning times (item 8):

| Track | Difficulty | Winning time (s) | Run | Evidence |
|-------|------------|------------------|-----|----------|
| Track | | | | |
| Track | | | | |
| Track | | | | |
| Random track | | | | |

History:

- 2026-10-09 (not run): the four hand-made tracks were replaced by generated tracks, and item 9 is new: the settings view with Difficulty and the track carousel (10 sketches and a '?', the middle one is chosen, yellow border), difficulty by the number of posts (Easy 2, Medium 6, Hard 10 for each 100 m). Look for a bend where a marble gets stuck, and for too many posts on Hard. The results menu has Settings, not Choose track.
- 2026-10-10 (not run): item 12 is new: the 3D world is drawn in a 480x270 pixel view (phase 3 of the arcade style), and the marbles have their slot number on them.
- -: **Not run**. Not run on a device yet. Item 11 is new: run it again after a change of the shared game code (PR 12 changed the countdown, the buzz limit and the end with no players).

## Test 10

### Snowball Splat (pointer)

Needs: 1 to 4 phones, 1 TV, and a child of about 5 to 8 years for item 9. Covers: REQ-SS-*, REQ-GM-47i to 47n, REQ-GM-80 to 84, 90 to 95, RISKS A4, REQ-GM-37, REQ-GM-50.

Hold each phone like a remote control, pointing at the TV, from the sofa. This is the first game that uses the
gyroscope pointer, so this test also checks the pointer itself (the old Test 5 for drift was removed).
The game was "Target Shoot" until 2026-10-09: it was changed after the first try (see History).


**Steps**

1. Start **Snowball Splat** with 1 phone. Hold the phone toward the TV during "3, 2, 1" and press nothing. Check: a cursor ring in the player color follows the phone, a throw in the countdown does nothing, and at "GO" the cursor is in the middle of the screen. (REQ-SS-1, 2)
2. Move the phone left, right, up and down. Check: the cursor moves the same way on the screen. Write down if the cursor is too fast or too slow for the distance from the sofa, and if you need a big arm movement to reach the corners. (`pointer_range_deg` in `orientation.gd`, REQ-SS-3)
3. Hold the phone still for 40 seconds. Check: the cursor stays where it is. Write down how far it drifted (in cm on the screen). Tap **RECENTER**. Check: the cursor goes to the middle. (RISKS A4, REQ-GM-37)
4. Press **A**. Check: a snowball flies to the cursor. When it lands on a Puff, the Puff gets snow on top, closes its eyes happily and floats away, the points show, and the phone buzzes a little. When it lands on empty sky, a white poof shows, nothing is lost, and you can throw again after a moment. Press B. Check: nothing happens. (REQ-SS-4 to 6, 13)
5. Check the Puffs from the sofa. Check: they are big and slow enough to hit with a pointer, they are easy to tell apart (pink, cyan and green Puffs for 10 points, the smaller yellow Little Puff for 25 points), and the cursor and its number are easy to see on the dark sky. Write down if the speed is right for an adult and for a child. (REQ-SS-7, 12)
6. Play a full round of 60 seconds alone. Write down the score. Check the medal at the end and compare with the tiers [150, 300, 450]: are they too easy or too hard? (REQ-SS-16)
7. Play with 2 to 4 phones. Check: all players see the same Puffs. Two players throw at the same Puff: the one who threw first gets it. Check the frame rate in the debug overlay with 4 players (60 expected). (REQ-SS-11, REQ-GM-50)
8. Switch one phone Wi-Fi off during a round. Check: within about 5 seconds the game pauses with the card "2P LOST CONNECTION". The cursor and score of a phone that left are gone. (REQ-GM-30, REQ-SS-16)
9. Let a child of about 5 to 8 years play 2 rounds, with a grown-up next to them. Check: the child understands what to do from the hint and a few seconds of play, hits some Puffs, is not frustrated or scared, and wants to play again. Write down the age and what the child said or did. (REQ-GM-80 to 84, REQ-SS-17)
10. Open the tile of **Snowball Splat**: the settings view opens. Play one round alone on each of Easy, Medium and Hard. Check: Easy has slow Puffs and more of them, Hard has fast Puffs and fewer, Hard is a challenge but not impossible, and the medal title names the difficulty ("Silver medal! (Hard)"). Write down the score of each round to tune the tiers (Easy [170, 340, 510], Medium [150, 300, 450], Hard [120, 240, 360]).
11. **Pixel world (phase 4, REQ-SS-12).** From the sofa (about 3 m), look at the sky. Check: the Puffs, the cursors and the snowballs are sharp square pixels, a Puff is easy to see on the dark board, the number on each cursor badge is easy to read, the points "+10" are easy to read, and the white flakes do not hide the Puffs. Write down if the cursor and the snowball are easy to follow.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Video of the countdown and GO: the cursor in the middle | Not run | | | |
| 2 | Note: range too small or too big; video of the cursor in the four directions | Not run | | | |
| 3 | Note: drift in cm after 40 s; video of RECENTER | Not run | | | |
| 4 | Video: a hit, a miss with the poof, B does nothing; note the buzzes | Not run | | | |
| 5 | Photo of the Puffs and the cursor from the sofa; note on the speed | Not run | | | |
| 6 | Photo of the result menu with the medal; the score; note on the tiers | Retest | R2 | Chat report 2026-10-09 (no file) | R2: while playing, 'when in the game and the score is above 3 digits, the last digit isn't visible'. The name-and-score chip at the top was a fixed 250 px wide and cut the text. Fixed on 2026-10-09 (REQ-GM-46): the chip is as wide as its content, and a long name is not cut (the chip gets wider, or goes to a second row). The rest of the round (feel, medal, tiers) was not reported. Retest, and check scores of 4 and 5 digits and a long phone name. |
| 7 | Photo of two phones' cursors and the same Puffs; overlay FPS with 4 phones | Not run | | | |
| 8 | Video: Wi-Fi off during a round, then the card | Not run | | | |
| 9 | Short video of the child playing (only with the permission of the parent); the age and the words of the child | Not run | | | |
| 10 | Photos of the settings view and of a round on each difficulty; the scores; note on the speed and the number of Puffs | Not run | | | Added 2026-10-09 (REQ-SS-20 to 22). All values are first guesses. |
| 11 | Photo of the sky from the sofa; note: sharp pixels, readable numbers and points | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). |

Values to write down (items 2, 3, 5 and 6). These decide the first tuning values of the game:

| Value | Result | Run | Notes |
|-------|--------|-----|-------|
| Pointer range: comfortable half range in degrees (now 25, `pointer_range_deg`) | | | |
| Drift after 40 s still (cm on the screen) | | | |
| Speed of the Puffs for an adult and for a child (now 100 and 160 px/s) | | | |
| Score of a full round alone, and the medal (tiers 150, 300, 450) | | | |
| Frame rate with 4 phones (aim 60) | | | |

History:

- 2026-10-10 (not run): item 11 is new: the sky is a pixel world (phase 4 of the arcade style).
- 2026-10-09 (not run): item 10 is new: the settings view and Easy, Medium and Hard for Snowball Splat (faster and fewer Puffs as it grows, medal tiers for each level, the title names the difficulty).
- R2: the owner played the new game and reported one problem: the last digit of a score above 3 digits was not visible in the chip at the top. Fixed on 2026-10-09. Nothing else was reported, so the other items stay not run.
- R1: **Fail**, then redesigned. The owner tried the first version ("Target Shoot", small fast targets, a lock after a miss, decoys) and said: "I don't think it's playable in its current definition." They asked for something like Duck Hunt with larger and slowly moving targets, no penalty for a miss, and a game that is also for kids, so not shooting but for example throwing snowballs at a made-up character. Changed on 2026-10-09: the game is now Snowball Splat (REQ-SS-*), and REQ-GM-80 to 84 are new for all games. Which steps failed was not reported. The whole test needs a run with the new game.

## Test 11

### Result menus (REQ-GM-72)

Needs: 1 to 4 phones, 1 TV. Covers: REQ-GM-34, REQ-GM-40, REQ-GM-41, REQ-GM-72, REQ-GM-73, REQ-MZ-5, REQ-MR-31.

1 to 4 phones. Tests the ranked result menu that both games and Snowball Splat use. New. Added with the shared game code (PR 12).

**Steps**

1. Maze with 1 phone: finish the maze. Check: the title says '<name> wins!', the list has one row '1st  <name>  <time> s', and the buttons are **Restart** and **Back to menu**. The text is easy to read from the sofa.
2. Maze with 2 to 4 phones: let one ball reach the exit first. Check: the winner is '1st' with a time, the other balls are listed as 'not finished' (nearest to the exit first), and the list and the buttons stay inside the screen edge (60 px).
3. Marble Race with 4 phones on any track: let all marbles finish. Check: the list shows 4 rows with times, best first, and a title with the winner. The card with the list and the 3 buttons (Restart, Settings, Back to menu) is inside the screen edge and can be read.
4. Marble Race with 4 phones: let one marble finish and wait about 4 seconds for the end. Check: the marbles that did not finish are listed as 'not finished', the furthest first.
5. Marble Race, at the results: choose **Settings**. Check: the settings view opens with the last difficulty and track, and Back returns to the Games screen.
6. Marble Race: when the race is over and the results show, switch off the Wi-Fi of all phones (or leave the game on every phone). Then choose **Settings** and **Back**, then open the results again if they are gone. Check: the menu says 'No players connected' and has only **Back to menu**. (REQ-MR-14)
7. Snowball Splat with 1 phone: play a full round. Check: the title is a medal ('Bronze medal!', 'Silver medal!', 'Gold medal!') or 'No medal this time', and the list has one row with the score. With 2 phones: the title names the winner, or says 'Tie!' for equal scores.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the result menu (1 phone) from the sofa | Not run | | | |
| 2 | Photo of the result menu with 'not finished' rows; check the edge | Not run | | | |
| 3 | Photo of the race results with 4 rows, with the screen edge visible | Not run | | | |
| 4 | Photo of the 'not finished' rows | Not run | | | |
| 5 | Photo or short video of Cancel returning to the results | Not run | | | |
| 6 | Photo of the 'No players connected' menu | Not run | | | |
| 7 | Photos of the medal title and of the winner or Tie title | Not run | | | |

History:

- -: **Not run**. New.

## Test 12

### Game tiles and the toy box look (REQ-GM-49)

Needs: 1 TV (phones for the game photos). Covers: REQ-GM-49, REQ-FL-20, REQ-FL-40, REQ-GM-41.

No phones are needed. Needs the TV and the Games screen. New. This is the visual check that the `review` skill asks for with a screenshot of the game next to the Games screen.

**Steps**

1. Open the Games screen. Check: every game has a tile with its screenshot, title and player range, and the text is easy to read from the sofa.
2. For each game, compare its tile with a photo of the game running. Check: the tile shows the same look (colors, outline, shapes) as the game, and the Games screen and the games look like one toy box.
3. Check the tiles of **Tilt Maze** and **Marble Race**. The Marble Race tile was made again on 2026-10-09: 4 marbles on a bend before a post (Track 1, Hard). The Maze tile was made again too: 4 balls on the way to the exit, the new chip style. If a tile and its game differ, tell Claude: the tiles are made again with `tools/make_tiles.gd`.
4. Check the tile of **Snowball Splat** (made again on 2026-10-09): it shows the night sky, the Puffs, four players with scores, a Puff that was just hit ("+25", snow cap) and a snowball in the air. Check that the cursors, the hit Puff and the snowball can be seen at the small size of the tile.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the Games screen | Not run | | | |
| 2 | Photos: tile next to the game, for each game | Not run | | | |
| 3 | Photos of the old and the new look, and a note | Not run | | | Marble Race and Maze tiles remade 2026-10-09 (4 marbles on a bend with posts; 4 balls on the way to the exit). |
| 4 | Photo of the tile and of the running game | Not run | | | Snowball Splat tile remade 2026-10-09 (4 players, a hit, a snowball in the air). |

History:

- -: **Not run**. New.

## Test 13

### Controller on an iPhone

Needs: 1 iPhone, 1 Mac with Xcode, 1 TV. Covers: `tools/deploy-ios.sh`, RISKS A2. New. Nothing in the iOS path has run yet.

**Steps**

1. Follow `docs/EXPORT.md`, section *Controller on an iPhone*, and run `IOS_TEAM_ID=<team id> tools/deploy-ios.sh`. Check: the export, the build, the install and the launch end without an error, and the app opens on the phone. Write down every error and the fix.
2. Open the connect screen. Check: there is no scan and no paste button, only **Discovered TVs** and **Refresh**. The local network permission is asked once. The list shows the TV (tap it: the phone joins and the TV shows the player), or stays empty (write which, and tell Claude). With the list empty, a second line must say how to allow Local Network (REQ-FL-59). Turn Local Network off for the app in Settings to see it.
3. Tilt the phone flat, left, right, forward, back (like Test 3, items 1 and 4). Check: the overlay Accel and Gyro values have the same directions as on Android. If they are inverted, tell Claude: the Android-only axis fix in `sensor_sampler.gd` needs a platform check.
4. Play Tilt Maze for 2 minutes with the screen on. Check: no disconnect, no screen lock, and the ball follows the tilt.
5. Lock the phone and unlock it. Check: the TV shows the lost-phone card and the game can resume (like Test 7, items 1 and 5).
6. On an iPhone with a Dynamic Island or a notch, open every phone screen (Connect, waiting, Settings, the pad in a game), also turned to the side. Check: nothing is hidden by the island, the notch, the status bar or the home bar: the colored square, the player number, Leave, the texts and the A and B buttons are fully visible (REQ-FL-68). Write down which iPhone it is.

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

1. Open the tile of **Paint Grab**. Check: the settings view has Difficulty on Medium, and Back (left) and Start (right) on one line. Start.
2. Hold the phone level in "3, 2, 1". Check: the blob does not move and nothing is painted. At "GO!" every phone buzzes.
3. Tilt the phone. Check: the blob rolls the same way, slows down by itself, bounces softly at the edge and never leaves the floor. Write down if it is too slow, too fast or too nervous (`ACCEL`, `DAMPING`, `MAX_SPEED` in `scripts/game/tilt_body.gd`).
4. Roll over tiles. Check: each tile takes your color, pops a little, and your tile count on your phone goes up. Roll over a tile of another player: it changes color and your phone buzzes.
5. Play a full round of 60 seconds alone on Easy, Medium and Hard. Write down the percent of the floor you painted and the medal. Check: the title names the difficulty ("Silver medal! (Hard)"), and the tiers [Easy 35, 55, 75; Medium 30, 50, 70; Hard 25, 40, 55] feel right.
6. Play with 2 to 4 phones. Check: the blobs bounce off each other, the leader chip names the leader (or TIE), the winner is named at the end, and equal scores say "Tie!". Leave the game on one phone during a round: its blob goes, its tiles stay, and the round goes on.
7. Let a child of about 5 to 8 years play 2 rounds, with a grown-up next to them. Check: the child understands what to do from the hint line, enjoys it, and is not upset when a tile is painted over.
8. Check the frame rate in the debug overlay with 4 phones on Hard (60 or close). (REQ-GM-50)
9. Tap **RECENTER** with the phone tilted. Check: the blob stops creeping. A and B do nothing. (REQ-PG-14)
10. **Pixel world (phase 4, REQ-PG-15).** From the sofa (about 3 m), look at the floor on Medium and Hard. Check: the tiles are sharp squares with equal gaps (no uneven lines), you can tell the colors apart, the blob and its number are easy to see on a tile of its own color, and a painted tile pops (a hard step). Write down if the pop is easy to see.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the settings view | Not run | | | |
| 2 | Video of the countdown and GO | Not run | | | |
| 3 | Note: too slow, too fast or too nervous; short video | Not run | | | |
| 4 | Video: painting a free tile and taking a tile; the tile count on the phone | Not run | | | |
| 5 | Percent and medal for each difficulty; note on the tiers | Not run | | | |
| 6 | Video or photo of 4 blobs; note on the bounce | Not run | | | |
| 7 | Note: the child, the age, what happened | Not run | | | |
| 8 | Overlay screenshot (FPS) with 4 phones on Hard | Not run | | | |
| 9 | Video: RECENTER, then A and B | Not run | | | |
| 10 | Photo of the floor from the sofa; note: equal gaps, colors, the blob and the pop | Not run | | | Added 2026-10-10 (phase 4 of the arcade style). |

History:

- 2026-10-10 (not run): item 10 is new: the floor is a pixel world (phase 4 of the arcade style).
- -: **Not run**. New.

## Test 15

### Sumo Bumpers (tilt and A)

Needs: 2 to 4 phones, 1 TV, and a child of about 5 to 8 years for item 8. Covers: REQ-SB-*, REQ-GM-80 to 84, REQ-GM-90 to 97, REQ-GM-37, REQ-GM-47i to 47n, REQ-GM-50.

Hold each phone flat like a tray. New game (2026-10-09). The movement (`TiltBody`), the bounce, the dash and the difficulty values are first guesses.

**Steps**

1. With 1 phone, open the tile of **Sumo Bumpers**. Check: the tile is dimmed and says "Needs 2 players". With 2 phones the settings view opens with Difficulty on Medium. Start.
2. Hold the phones level in "3, 2, 1" with the title "Round 1 of 3". Check: the bumpers do not move. At "GO!" every phone buzzes.
3. Tilt the phone. Check: the bumper rolls the same way, slows down by itself, and the platform shrinks all the time (the edge ring gets red). Write down if the bumper is too slow, too fast or too nervous (`tilt_body.gd`).
4. Bump into another bumper. Check: both bounce away and both phones buzz at a fast hit, and nobody is hurt.
5. Press **A** with a tilt. Check: a dash in the tilt direction, a ring around the bumper shows when it is ready again. Write down if the dash is too strong or too weak (`DASH_SPEED`, the dash time).
6. Roll over the edge. Check: the bumper spins, gets small and says "Whee!", the phone buzzes, and the round goes on. When one bumper is left, a banner names the winner of the round and the next round starts after 2.5 s with all bumpers back.
7. Play all 3 rounds with 2, 3 and 4 phones. Check: the points of the leader chip and on each phone, the winner of the match, and "Tie!" for equal points. Write down how long a round is and if the wait after a fall is too long (REQ-SB-9). Play Easy, Medium and Hard.
8. Let a child of about 5 to 8 years play a match, with a grown-up next to them. Check: the child understands what to do from the hint line, laughs at the fall and is not upset.
9. Leave the game on one phone during a round. Check: its bumper goes and the match goes on. With 2 phones, leave on one: the match ends at once.
10. Check the frame rate in the debug overlay with 4 phones on Hard (60 or close). (REQ-GM-50)
11. **Pixel world (phase 2, REQ-GM-47i to 47n).** From the sofa (about 3 m), look at the world. Check: the bumpers, the platform and the stars are made of sharp square pixels (not blurred), every bumper has a black outline, eyes, and its number is easy to read on it, "WHEE!" and the chips are sharp text, and the bumpers are easy to tell apart on the dark platform. Write down if a bumper is too small to follow in a fight, and the TV (1080p or 4K).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the dimmed tile and of the settings view | Not run | | | |
| 2 | Video of the countdown and GO | Not run | | | |
| 3 | Note: too slow, too fast or too nervous; photo of the red ring | Not run | | | |
| 4 | Video of a bump; note on the buzz | Not run | | | |
| 5 | Video of a dash; note on the strength and the ready ring | Not run | | | |
| 6 | Video of a fall and the banner | Not run | | | |
| 7 | Length of a round for each difficulty; note on the wait | Not run | | | |
| 8 | Note: the child, the age, what happened | Not run | | | |
| 9 | Note: what happened on each leave | Not run | | | |
| 10 | Overlay screenshot (FPS) with 4 phones on Hard | Not run | | | |
| 11 | Photo of the screen from the sofa; note: sharp pixels, readable numbers, the TV | Not run | | | |

History:

- -: **Not run**. New. Item 11 was added on 2026-10-10 (phase 2 of the arcade style).

## Test 16

### The arcade look (REQ-FL-37 to 46, FD-18)

Needs: 1 to 4 phones, 1 TV on 1080p (and a 4K TV if you have one), a child of 5 to 8 years for item 8. Covers: REQ-FL-37 to 46, 41a, 52, 53, REQ-GM-45, 46. New, written on 2026-10-10 for phase 1 of `docs/ARCADE_STYLE_PLAN.md`. The games still draw their old worlds (phases 2 to 4): only the menus, the phone and the game shell (HUD, countdown, menus, hints) are new.

**Steps**

1. Sit on the sofa (about 3 m from the TV). Go through the logo, Connect, Games, Settings, a game settings view, the Players modal, the quit question, a pause menu and a result menu. Check: all text is easy to read (the smallest is 32 px), upper case, white, gray or yellow on black. Write down every text that is hard to read.
2. Look at the text and the frames from 1 m. Check: the pixels are sharp, not blurred or smoothed, on 1080p. Do it on a 4K TV too, if you have one.
3. Games screen with 1, 2 and 4 phones. Check: three tiles in a row, the focused tile has a yellow frame and a cursor, the description of the focused game shows in the bar under the grid, "SNOWBALL SPLAT" fits under its tile, and a game that needs more phones shows its reason in yellow.
4. Check the menus: the cursor is in front of the focused item, a destructive item (END GAME, QUIT, REMOVE) is red with the focus, BACK is dim until it has the focus, and OK, Back and the D-pad work as before.
5. Check the motion: PRESS OK TO CONTINUE and PRESS OK TO SKIP blink (about half a second on, half a second off), the logo drops in in steps, the confetti is square, the countdown number shrinks in steps. The overlay FPS stays at 60.
6. Phone: connect, wait and pad screens. Check: the text is readable at arm's length, A (green) and B (red) feel like buttons, RECENTER flashes yellow, LEAVE needs two taps, and the slot color square with the slot number is at the top.
7. Play each game with 4 phones that have long names (12 letters or more). Check: the leader chip (name and score), the timer, the title and the hint do not hide each other or the play area, and the HUD stays on one row. Write down which game has a problem and where. Test 19 covers the leader chip and the phone score in detail. The games are restyled in phases 2 to 4: a problem here is a note for that phase.
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
2. In Hebrew, go through the logo, Connect, Games, Settings, a settings view, the Players modal, the quit question. Check: every screen is mirrored (QR card at the right, slot squares at the right, cursor at the right and pointing left, title at the right), no text is cut, no English word is left (except WOBBLE, WI-FI, OK, the room code and the player names), and the Hebrew letters and the punctuation (`. , ! ? -`) look right next to each other. Write down any text that is cut or any word that looks wrong.
3. In Hebrew, the Left and Right keys of the remote in a choice row (Difficulty): Right goes to the previous value (the arrow at the right), Left to the next. Check that the D-pad moves the focus between rows by position as before.
4. Join 2 phones: one with the system language Hebrew, one English, with player names in Latin letters and in Hebrew letters. Check: before the join the Hebrew phone shows its connect screen in Hebrew and the English phone in English; after the join both show the language of the TV (Hebrew); the player names show as typed (a Latin name in a Hebrew row is in the right place).
5. In Settings, press OK on the Language row. Check: the TV switches to English at once (the layout turns left to right), the phones switch too, and the Settings screen stays open. Switch back to Hebrew. Leave the app and start it again: the language is the one that was last chosen.
6. Start each game in Hebrew with 2 phones. Check: the title is at the top right, the leader chip is at the left, the timer is at the left of the title, the hint and the countdown ("קדימה") are readable, and the world is not mirrored (the maze start is at the top left, the track runs as in English). Open the pause menu and the result menu: the ranking list, the medal text and "תיקו!" read right.
7. Phone in Hebrew, on the pad screen: the words RECENTER, LEAVE and the hint are Hebrew, and A and B are in the same places as in English (the pad is not mirrored).
8. Run the English TV again with the same phones: nothing changed from before (compare with Test 16).

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Video of the first start with the choice and the second start; photo of the choice | Not run | | | |
| 2 | Photos of each TV screen in Hebrew; a list of cut or wrong text | Not run | | | |
| 3 | Video of a choice row with Left and Right | Not run | | | |
| 4 | Photos of both phones before and after the join, and the Connect screen with the names | Not run | | | |
| 5 | Video of the switch in Settings with the TV and a phone in the picture | Not run | | | |
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
2. Move the cursor, press OK and Back on the remote. Check: a soft blip, a rising two-note sound, a falling two-note sound. Join and leave with a phone: a rising and a falling run. Write down if any sound is too loud, too sharp or too often.
3. Open Settings. Check: the rows Music, Effects and Mute. Change Music with Left and Right: the song gets louder and quieter by 10 steps. Change Effects: a sample plays. Mute: everything is silent. Leave the app and start it again: the levels are kept.
4. Change the volume of the TV and of the phone (media volume, silent mode). Check: the TV sound follows the TV only. The phone makes no sound at all and its settings change nothing.
5. Start each game (5 games). Check: the countdown beeps at 2 and 1 and a higher beep at GO, and the game song starts at GO (write down how long after GO). The song of each game has its own mood and loops without a click. Write down which songs you like and which not.
6. In each game, make each event of the *Sound and haptics* table of its game file (`docs/games/<id>.md`). Check: the effect plays and the phone of the player buzzes at the same time. Write down effects that are too loud, too quiet, too often or that do not fit. With 4 players, check that the effects do not turn into noise.
7. Open the pause menu and the "phone lost" card (turn off Wi-Fi on one phone). Check: the music gets quieter and comes back with Resume, with no jump.
8. Finish a game with a winner, with a medal (one player), and with a tie. Check: a short fanfare for a winner or a medal, a neutral phrase for a tie or "Round over", then silence on the result menu. Back to the menu: the menu song comes back.
9. Let a child of about 5 to 8 years play a game with sound. Check: the sounds are friendly and not scary or too loud. Write down what the child says.
10. On a phone, open **Settings** on the waiting screen and set **Haptics** to OFF. Check: the phone does not vibrate in a game, and the game plays the same. Set it to ON: it vibrates once and in games. Close the app and start it again: the choice is kept. Check that the Settings button is not in the way of Leave.
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

Needs: 2 to 4 phones (give two of them names of 10 letters, the most since FD-22), 1 TV on 1080p, a grown-up, and a child of about 5 to 8 years for item 8. Covers: REQ-FL-67, REQ-GM-46, 46a, FD-21, issue #25.

New (2026-10-10). The HUD shows one chip, the leader, and not a chip for each player. Each phone shows its own place and score. The size of the header text on the phone and the place of the name tags are first values. The headless tests check the layout rules, not how it looks from the sofa.

**Steps**

1. Start Snowball Splat with 4 phones (two names of 10 letters, the most a name can have since FD-22). Check from the sofa: the top row has the title, the timer and one chip with the leader's name and score, all on one row; nothing covers the play area; the name and the score are easy to read. Write down if the leader chip is too small or too big.
2. In the same game, before anybody scores: no chip shows and the phones show only `2P` (or the profile name) and 0. Then score with different phones. Check: the chip changes to the new leader at once; when two phones have the same score it says TIE with a gray square and the score; a score of 4 and 5 digits still fits.
3. Look at each phone during the game. Check: the line under the header row (not next to Leave) shows the place (1ST to 4TH) and the score (`2ND  120`), and it changes when the score changes; it is readable at arm's length; with one phone only the score shows (no place). On an iPhone with a Dynamic Island (and on an Android phone with a camera cut-out): the colored square, the player number and Leave are fully visible below the island or the notch, nothing is hidden at the top, at the bottom (the home bar) or at the side when you turn the phone, and A and B are fully on the screen (REQ-FL-68). Open the pause menu: the phone keeps its score. Go back to the menu: the score is gone.
4. Play Paint Grab and Sumo Bumpers with 2 to 4 phones. Check the same as items 1 to 3. In Sumo Bumpers the name tags show again in the countdown of every round.
5. Play Marble Race with 3 or 4 phones. Check: the leader chip names the first marble (with its time after the finish); the phones show their place; a marble that has not finished shows no time. Check that the old list of names at the left is gone.
6. Play Tilt Maze with 2 to 4 phones. Check: there is no chip during play (the maze has no score) and the phones show only `2P`.
7. In every game, look at the countdown. Check: each player's name stands next to its own ball, marble, cursor, bumper or blob, in its color; the names do not cover each other (start the maze and Sumo with 4 phones); every name is complete; the tags are gone at GO. Write down where a tag hides something important.
8. A child of 5 to 8 years plays a game. Check: the child finds its own object by the name in the countdown and reads or understands the number on its phone. Write down what the child says.
9. Set the TV to Hebrew and play one game with 2 phones. Check: the leader chip is at the left margin, the timer is at the left of the title, TIE reads "תיקו", and the phone header is readable.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the TV with 4 long names | Not run | | | |
| 2 | Photo of TIE; photo of a 5-digit score | Not run | | | |
| 3 | Photo of a phone header with place and score | Not run | | | |
| 4 | Note for Paint Grab and Sumo Bumpers | Not run | | | |
| 5 | Photo of the Marble Race HUD | Not run | | | |
| 6 | Note: no chip in the maze | Not run | | | |
| 7 | Photo of the countdown of each game | Not run | | | |
| 8 | Note: the child, the age, what happened | Not run | | | |
| 9 | Photo of the Hebrew HUD and phone | Not run | | | |

History:

- -: **Not run**. New.

## Test 20

### Player profiles (REQ-FL-69 to 75, REQ-N8, REQ-C7 to C9, FD-22)

Needs: 2 to 4 phones (one an iPhone if possible), 1 TV on 1080p, a grown-up, and a child of about 5 to 8 years for item 7. Covers: REQ-FL-69 to 75, REQ-N8, REQ-C7 to C9, FD-22. Items 1 to 8 are phase A (names and avatars), items 12 to 15 are phase B (copy by QR). The items 9 to 11 for the personal bests are added by phase C (`docs/PROFILES_PLAN.md`, section 11.2).

New (2026-10-10). The headless tests check the rules and the drawing. They do not show how an avatar looks from the sofa, or how the profile screens feel to a child.

**Steps**

1. Make a profile on a phone (name, avatar) and join a TV. Check: the TV shows the name and the avatar in the Players list, on the ball or blob in each game, in the countdown tags and in the result list; no "Player N" for that phone.
2. Change the avatar and the name on the phone (in a menu) and look at the TV. Check: the TV shows the new values after the phone answers; the phone shows what the TV accepted.
3. A parent phone with 3 profiles: switch between rounds. Check: the TV shows the new name and avatar; the profile button is gone when a round starts; the list closes if it was open.
4. Two phones with the names `Sam` and `sam`. Check: the TV shows `Sam` and `Sam 2`. A name of 10 letters and a Hebrew name of 10 letters fit on the cards and in the lists.
5. A guest next to profile players. Check: the guest keeps the number and `Player N`.
6. Pause card with profile names (switch the Wi-Fi of a phone off). Check: `MAYA LOST CONNECTION`, `Resume without Maya`, `Maya reconnected`; two names of 10 letters fit; a Hebrew name in the English sentence and an English name in the Hebrew sentence read right.
7. All 16 avatars on the four slot colors and on the smallest ball, from the sofa. A child of 5 to 8 years names five of them and finds its own avatar. Write down which avatars look alike.
8. The same profile on a second phone joins the same TV while the TV is in a menu. Check: the older phone shows `YOUR PLAYER JOINED ANOTHER PHONE.` and goes to the Connect screen. Then repeat during a round: the second phone waits as a guest and nobody is removed.

12. Share a profile to a second phone by QR: on the first phone open the list, tap SHARE on a row; on the second phone tap SCAN A PLAYER. Check: the second phone shows PLAYER ADDED. with the same name and avatar. Time how long the code takes to appear and to scan; try it from 30 cm and from 60 cm, with the screen at full and at low brightness.
13. Share a player that the second phone already has, after a rename on the first phone (the name is newer there): the second phone shows PLAYER UPDATED. and has the newer name and avatar. Then rename on the second phone and scan the old copy again: the newer name stays.
14. An iPhone: COPY CODE on one phone and PASTE A CODE on the iPhone (the iPhone has no scan button). Check the same result as item 12.
15. A broken code (change one letter of a copied code, then paste), a TV link (scan the QR code of the TV on the list), and a player code scanned on the Connect screen: the messages THIS CODE DOES NOT WORK., THIS IS A TV LINK., and the player is added.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the TV with 2 profile players in a game | Not run | | | |
| 2 | Note: the new name and avatar on the TV | Not run | | | |
| 3 | Video of a switch between rounds | Not run | | | |
| 4 | Photo of `Sam` and `Sam 2` | Not run | | | |
| 5 | Photo: a guest next to a profile player | Not run | | | |
| 6 | Photo of the pause card in English and in Hebrew | Not run | | | |
| 7 | Photo of the 16 avatars on the TV; note: the child, the age, what the child said | Not run | | | |
| 8 | Photo of the message on the older phone | Not run | | | |
| 12 | Video: the scan; time to show and to scan; the distances | Not run | | | |
| 13 | Note: the names on both phones | Not run | | | |
| 14 | Note: the iPhone model and what happened | Not run | | | |
| 15 | Photo of each message | Not run | | | |

History:

- -: **Not run**. New.
