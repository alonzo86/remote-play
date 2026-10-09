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
| R2 | | | | | | | |

## Summary

Update this table after every run. *Latest* is the newest result of the whole test (the worst result of its steps).

| Test | Title | Needs | Covers | Latest | Run | Evidence |
|------|-------|-------|--------|--------|-----|----------|
| [1](#test-1) | Start and join | 1 phone, 1 TV | REQ-T1, REQ-FL-5 to 10 | Retest (design change) | R1 | |
| [2](#test-2) | QR scan (plugin, unverified) | 1 phone, 1 TV | RISKS C5 | Pass | R0 | |
| [3](#test-3) | Sensor directions | 1 phone, 1 TV | RISKS A2 | Retest | R0 | |
| [4](#test-4) | Latency and packet rate | 1 to 4 phones, 1 TV, a phone camera (240 fps) | RISKS A1, A3, B1, B2 | Fail | R0 | |
| [6](#test-6) | Tilt maze feel | 1 to 4 phones, 1 TV | REQ-MZ-4, REQ-MZ-6, REQ-MZ-8, REQ-GM-37 | Partial (items 1 to 3 Pass, 4 and 5 not run) | R1 | |
| [7](#test-7) | Disconnect and reconnect | 2 phones, 1 TV | REQ-GM-30, REQ-GM-30a, REQ-FL-25, REQ-MR-14, REQ-MZ-8 | Fail (item 1, fixed, retest) | R1 | |
| [8](#test-8) | TV remote | 1 phone, 1 TV with its remote | REQ-GM-31, REQ-GM-31a, REQ-GM-33, REQ-FL-41, REQ-FL-55 | Fail (items 2 and 3, fixed, retest) | R1 | |
| [8b](#test-8b) | The TV flow and the style | 1 to 2 phones, 1 TV (set to Hebrew for item 7) | REQ-FL-1 to 46, REQ-FL-54, 56, 57, FD-1 to 17 | Fail (items 2 and 7, fixed, retest) | R1 | |
| [9](#test-9) | Marble race (3D) | 2 to 4 phones, 1 TV | REQ-MR-*, REQ-3D-*, REQ-GM-37, REQ-GM-50 | Not run |  | |
| [10](#test-10) | Target Shoot (pointer) | 1 to 4 phones, 1 TV | REQ-TS-*, RISKS A4, REQ-GM-37, REQ-GM-50 | Not run |  | |
| [11](#test-11) | Result menus (REQ-GM-72) | 1 to 4 phones, 1 TV | REQ-GM-34, REQ-GM-40, REQ-GM-41, REQ-GM-72, REQ-GM-73, REQ-MZ-5, REQ-MR-31 | Not run |  | |
| [12](#test-12) | Game tiles and the toy box look (REQ-GM-49) | 1 TV (phones for the game photos) | REQ-GM-49, REQ-FL-20, REQ-FL-40, REQ-GM-41 | Not run |  | |

Test 5 (pointer drift) was removed on 2026-10-07 with the old pointer test. The pointer is checked again in Test 10.

## Test 1

### Start and join

Needs: 1 phone, 1 TV. Covers: REQ-T1, REQ-FL-5 to 10.


**Steps**

1. Start the TV app. Check: the Android splash shows, then the logo screen with an animation (about 2.5 seconds), then the **Connect controllers** screen with a room code and a QR code. If the QR code is empty, the TV has no Wi-Fi address (the screen says so).
2. Start the controller app on one phone. Check: the phone shows a **portrait** screen.
3. Join with the **TV list** (tap the TV). Check: the phone shows "Waiting for the host" with a colored player circle, the TV shows the phone in slot 1 as "Ready!", and the line **Press OK to continue** shows at the bottom (there is no Continue button and no player count). Press OK. Check: the TV shows the Games screen and the phone says "Choose a game on the TV".
4. Tap **Leave**, then tap the TV under **Discovered TVs**. Check: it joins (the button reads "<code> x/y", for example "KQZM 1/4", and it is green; **Refresh** is yellow). Tap **Refresh**. Check: the list shows "Searching..." and the TV is back within 2 seconds.
5. Tap **Leave**, then join with the **TV IP address**. Check: it joins.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the TV (splash, logo, Connect screen) and the phone (portrait) | Not run | | | |
| 2 | Photo of the phone in portrait | Not run | | | |
| 3 | Photo of TV and phone together: slot 1 'Ready!' and the line 'Press OK to continue'; then the Games screen | Retest | R1 | Chat report 2026-10-09 (no file) | R1: the owner found the Continue button redundant (it was the only focus target) and the count of players repeated the slot list. Changed on 2026-10-09 (FD-17, REQ-FL-6, 7): the button and the count are gone, and 'Press OK to continue' shows once a phone has joined. The old check cannot pass any more. Retest the new screen. |
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
4. Optional: put a different QR code in front of the phone (for example a web link). Check: the message "This is not a Remote Play code".

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

Needs: 1 to 4 phones, 1 TV. Covers: REQ-MZ-4, REQ-MZ-6, REQ-MZ-8, REQ-GM-37.


**Steps**

1. Start **Tilt Maze** with 1 phone. Hold the phone level in the countdown.
2. Finish the maze. Write down: does the ball feel too light, too heavy, or good? Is the deadzone good (the ball does not creep when the phone is level)?
3. Tune the constants in `scripts/game/maze/maze_game.gd` (`TILT_ACCEL`, `FRICTION`, `DEADZONE`) if needed.
4. Repeat with 2 to 4 phones. Check *Rx Hz* and *Gap ms* for all players during the race.
5. Tilt the phone, then tap **RECENTER**. Check: the ball stops creeping. Tap **A** and **B**. Check: nothing changes (A and B do not recenter, REQ-MZ-8). At GO the phone recenters by itself.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Note: the phone is level in the countdown | Pass | R1 | Chat report 2026-10-09 (no file) | R1: the owner played the maze and reported 'it works perfectly'. The steps of the countdown were not reported one by one. |
| 2 | Note: ball too light, too heavy or good; deadzone good or not. Short video | Pass | R1 | Chat report 2026-10-09 (no file) | R1: 'i tested the maze game and it works perfectly'. The feel is good on the TV. The number of phones was not written down (step 4 is still open). |
| 3 | If constants changed: the commit or the diff | N/A | R1 | Chat report 2026-10-09 (no file) | R1: no tuning is needed, because the owner reported no problem. The constants are unchanged. |
| 4 | Screenshot of the debug overlay for every player during the race | Not run | | | |
| 5 | Video of the ball: creeping, then RECENTER, then A and B | Not run | | | |

History:

- R1: items 1 to 3 **Pass** (the owner: 'it works perfectly'). Items 4 and 5 are not run: 2 to 4 phones, and RECENTER with A and B.
- R0: **Retest**. First run: drift and inverted controls (caused by 'Invert tilt axes' being on). After the fix the maze looks good on the desk. The feel and the constants were not judged. Item 5 is new (RECENTER, and A and B do nothing).

## Test 7

### Disconnect and reconnect

Needs: 2 phones, 1 TV. Covers: REQ-GM-30, REQ-GM-30a, REQ-FL-25, REQ-MR-14, REQ-MZ-8.


**Steps**

1. With two phones joined, during the maze, switch one phone Wi-Fi off for 15 seconds, then on. Check: within about 5 seconds the TV pauses and shows the card "P2 lost connection" with **Resume without P2** and **End game**, and the phone shows "Reconnecting...". When the phone is back, the card says "P2 reconnected" with **Resume**. The game goes on only when you press **Resume**.
2. Lock the phone screen for 10 seconds, then unlock. Check: the phone reconnects. (Android can stop the app in the background.)
3. Switch the phone Wi-Fi off for 40 seconds. Check: the slot is freed. When the Wi-Fi is back, the phone joins again (maybe in a different slot).
4. Switch one phone Wi-Fi off again and wait for the card. Choose **Resume without P2**. Check: the game continues without that player. Switch the Wi-Fi on. Check: the phone joins again as a new player and waits for the next round.
5. With only one phone joined, switch its Wi-Fi off during the maze. Check: within about 5 seconds the game pauses with the card "P1 lost connection" that has only **End game** (no Resume, because nobody is connected). Switch the Wi-Fi on. Check: the card says "P1 reconnected" and offers **Resume**. Do the same in the marble race and in Target Shoot. Press Back on the card. Check: it asks "End the game?".
6. On the phone pad, tap **Leave** once. Check: it turns red ("Again") for 3 seconds and the phone does not leave. Tap again within 3 seconds: it leaves. Check the pad buttons: A is green and B is red, both sink when pressed.
7. Phone call: with one phone in a game, call that phone from another phone and answer. Check: the game pauses with the card. End the call and go back to the controller app. Check: the phone says "Reconnecting..." and then joins again, the card says "P1 reconnected" with **Resume**, and **Resume** goes on with the game. Try a call that lasts more than 1 minute (the slot is kept 5 minutes while the game is paused). Write down how long the phone needs to reconnect after the call. (REQ-GM-30, 30a)

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Video of TV and phone: the card, 'Reconnecting...', then Resume | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the phone disconnected from the Wi-Fi and showed 'Reconnecting...', but on the TV the game kept going (no pause, no card). The off time was not written down (it must be more than 5 s). Cause (found on 2026-10-09): the TV waited for a close handshake that a phone with no Wi-Fi cannot answer, so it never marked the phone lost. The same failure was seen in R0. Fixed on 2026-10-09 (a silent phone is lost at once, PROTOCOL.md) and the pause changed (REQ-GM-30). A test now reproduces it. Retest. |
| 2 | Note: did the phone reconnect | Not run | | | |
| 3 | Photo of the Connect or Games screen after 40 s and after the join again | Not run | | | |
| 4 | Video: Resume without P2 with a lost phone, and the phone that joins again | Not run | | | |
| 5 | Photo of the card of the only player lost (End game only), and of the card after the return (Resume); in the maze, the race and Target Shoot | Retest | R1 | Chat report 2026-10-09 (no file) | R1: a phone call stopped the game ('as expected') and the TV showed 'No players connected'. After the call there was no way to resume. The owner asked for a message that says which player disconnected, with Resume only when a player is still connected or the disconnected player is back. Changed on 2026-10-09 (REQ-GM-30, 30a): the game waits with a card, there is no Resume while nobody is connected, and Resume shows when the phone is back. The slot is kept 5 minutes while paused. The old check ('No players connected' at once) is gone. Retest. |
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

Needs: 1 to 2 phones, 1 TV (set to Hebrew for item 7). Covers: REQ-FL-1 to 46, REQ-FL-54, REQ-FL-56, 57, FD-1 to 17.


**Steps**

1. Start the TV app from cold. Check: the logo screen goes on by itself after about 2.5 seconds, and OK skips it. Back on the logo screen does not quit.
2. On the Games screen, with one phone joined, check that every tile shows its screenshot, title and player range, and that the text is readable from the sofa (REQ-FL-40).
3. Open the **players badge** (OK). Check: the modal shows the slots, a QR code and the room code. Press **Remove** on a player. Check: the phone says that the host removed it and does not reconnect by itself. Join again with the QR code. Check: the slot fills again.
4. Join a phone while a game runs. Check: the phone says "A round is running", it does not take part, and it joins the next round.
5. Check the motion on the TV box: the logo (with its confetti), the tile growing and shrinking and the screen changes run at 60 frames per second (overlay FPS). Check that the Party Pop colors look right on your TV (not washed out, outlines visible).
6. Phone: check that the fonts and the colors match the TV on the connect, waiting and pad screens.
7. Set the language of the TV to a language that is written from right to left (Hebrew, region Israel) and start the app. Check: every screen is in English and left to right (the QR card on the left, the title on the left, the buttons not mirrored). The phone app does the same with a phone set to Hebrew. (REQ-FL-54)

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Video from cold start: logo, then Connect | Not run | | | |
| 2 | Photo of the Games screen with all tiles | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the screenshots of the games are missing on the Games screen of the Android 10 TV. What the tiles showed instead (dark boxes, colors) was not written down. The same tiles show on a desktop with the OpenGL renderer. The cause is not confirmed. Changed on 2026-10-09 (REQ-FL-56, 57): the image is rounded in the file and not clipped, a placeholder shows when a tile does not load, and a warning goes to the log. Retest. If they are still missing, save `adb logcat -d -s godot` and look for 'Tile image'. |
| 3 | Photos of the Players modal; of the phone after Remove; of the slot after the join again | Not run | | | |
| 4 | Photo of the phone 'A round is running' | Not run | | | |
| 5 | Overlay FPS screenshot during the logo, tile growth and screen changes; photo of the colors | Not run | | | |
| 6 | Photos of the phone connect, waiting and pad screens next to the TV | Not run | | | |
| 7 | Photos of the Connect and Games screens on a TV set to Hebrew; of the phone set to Hebrew | Fail | R1 | Chat report 2026-10-09 (no file) | R1: the TV is set to the IL region and Hebrew. The text was English, but the layout was mirrored (right to left). Fixed on 2026-10-09 (REQ-FL-54): the app sets the locale to English and the layout to left to right. Retest on the TV. The phone was not tried. |

History:

- R1: **Fail** (items 2 and 7). The tile screenshots are missing, and the layout is mirrored on a TV set to Hebrew. Both changed on 2026-10-09 and wait for the retest. The other items are not run.

## Test 9

### Marble race (3D)

Needs: 2 to 4 phones, 1 TV. Covers: REQ-MR-*, REQ-3D-*, REQ-GM-37, REQ-GM-50.

Needs 2 to 4 phones. Requirements: `docs/games/marble_race.md`. Start "Marble Race" and pick a track.


**Steps**

1. Check: the TV shows the track from above, the order list at the top left, and the track name at the bottom right. All text is inside the screen edge and can be read from the sofa. (REQ-MR-9, REQ-MR-35)
2. Check: during "3, 2, 1" the marbles do not move when you tilt. At "GO!" every phone buzzes. (REQ-MR-3)
3. Tilt right: the marble goes right on the screen. Tilt the top of the phone up: the marble goes down on the screen. (REQ-3D-6)
4. Check the feel. Write down if the marble is too slow, too fast, or too nervous. (`ACCEL`, `DAMPING`)
5. Hit a wall, a post and another marble at speed. Check: the phone buzzes, not more than 6 times a second. (REQ-MR-13)
6. Check: the frame rate in the debug overlay is 60 (or close) with 4 phones on Gauntlet. (REQ-GM-50)
7. Let one marble run far ahead on Gauntlet. Check: when the last marble leaves the view, an arrow in its color shows at the screen edge with a distance, and you can read it. (REQ-MR-42)
8. Finish a race on each track. Write down the winning time. Compare with the targets in the table. (REQ-MR-21)
9. At the results: use Choose track, pick another track, and check that the new race has that track. Press Back in the track list: it returns to the results.
10. During a race, open the pause menu. Check: it has no Choose track. (REQ-MR-32)
11. After a change to the shared game code (the countdown clock, the buzz cool-down, the end with no players), run this test again with 2 phones on each track. Check: the countdown, the buzz at GO, the buzz limit (item 5), a player who leaves (the race goes on) and the last player who leaves (the menu "No players connected") all work as before. Tap **RECENTER** during a race: the marble stops drifting.

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
| 9 | Video: Choose track, new track, Back in the list | Not run | | | |
| 10 | Photo of the pause menu | Not run | | | |
| 11 | Video of a full race on one track and notes for every check in the item | Not run | | | |

Winning times (item 8). Compare with the targets in `docs/games/marble_race.md` (REQ-MR-21):

| Track | Winning time (s) | Run | Evidence |
|-------|------------------|-----|----------|
| Classic | | | |
| Sprint | | | |
| Zigzag | | | |
| Gauntlet | | | |

History:

- -: **Not run**. Not run on a device yet. Item 11 is new: run it again after a change of the shared game code (PR 12 changed the countdown, the buzz limit and the end with no players).

## Test 10

### Target Shoot (pointer)

Needs: 1 to 4 phones, 1 TV. Covers: REQ-TS-*, RISKS A4, REQ-GM-37, REQ-GM-50.

Needs 1 to 4 phones. Hold each phone like a remote control, pointing at the TV, from the sofa. This is the first game that uses the
gyroscope pointer, so this test also checks the pointer itself (the old Test 5 for drift was removed).


**Steps**

1. Start **Target Shoot** with 1 phone. Hold the phone toward the TV during "3, 2, 1" and press nothing. Check: a cursor ring in the player color follows the phone, a shot in the countdown does nothing, and at "GO" the cursor is in the middle of the screen. (REQ-TS-1, 2)
2. Move the phone left, right, up and down. Check: the cursor moves the same way on the screen. Write down if the cursor is too fast or too slow for the distance from the sofa, and if you need a big arm movement to reach the corners. (`pointer_range_deg` in `orientation.gd`, REQ-TS-3)
3. Hold the phone still for 40 seconds. Check: the cursor stays where it is. Write down how far it drifted (in cm on the screen). Tap **RECENTER**. Check: the cursor goes to the middle. (RISKS A4, REQ-GM-37)
4. Press **A** on a target. Check: the target goes, the points show, the phone buzzes a little. Press A on empty space. Check: a short buzz, the cursor fades, and A does nothing for about half a second. Press B. Check: nothing happens. (REQ-TS-4 to 6)
5. Check that the three target kinds are easy to tell apart from the sofa: cyan (10), small yellow (25) and the pink square with an X (-15). Check that the cursor and its number are easy to see on the dark board. (REQ-TS-12)
6. Play a full round alone. Write down the score. Check the medal at the end and compare with the tiers [200, 350, 500]: are they too easy or too hard? (REQ-TS-15)
7. Play with 2 to 4 phones. Check: both players see the same targets. Two players shoot the same target: only the first one scores. Check the frame rate in the debug overlay with 4 players (60 expected). (REQ-TS-11, REQ-GM-50)
8. Switch one phone Wi-Fi off during a round. Check: the game pauses and then goes on, and the cursor and score of a phone that left are gone. (REQ-TS-16)

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Video of the countdown and GO: the cursor in the middle | Not run | | | |
| 2 | Note: range too small or too big; video of the cursor in the four directions | Not run | | | |
| 3 | Note: drift in cm after 40 s; video of RECENTER | Not run | | | |
| 4 | Video: hit, miss with the fade and the lock, B does nothing; note the buzzes | Not run | | | |
| 5 | Photo of the three target kinds and the cursor from the sofa | Not run | | | |
| 6 | Photo of the result menu with the medal; the score; note on the tiers | Not run | | | |
| 7 | Photo of two phones' cursors and the same targets; overlay FPS with 4 phones | Not run | | | |
| 8 | Video: Wi-Fi off during a round, then the round goes on | Not run | | | |

Values to write down (items 2, 3 and 6). These decide the first tuning values of the game:

| Value | Result | Run | Notes |
|-------|--------|-----|-------|
| Pointer range: comfortable half range in degrees (now 25, `pointer_range_deg`) | | | |
| Drift after 40 s still (cm on the screen) | | | |
| Score of a full round alone, and the medal (tiers 200, 350, 500) | | | |
| Frame rate with 4 phones (aim 60) | | | |

History:

- -: **Not run**. New. This is the first game with the gyroscope pointer. It also decides: the pointer range, the drift, the medal tiers [200, 350, 500] and the target sizes.

## Test 11

### Result menus (REQ-GM-72)

Needs: 1 to 4 phones, 1 TV. Covers: REQ-GM-34, REQ-GM-40, REQ-GM-41, REQ-GM-72, REQ-GM-73, REQ-MZ-5, REQ-MR-31.

1 to 4 phones. Tests the ranked result menu that both games and Target Shoot use. New. Added with the shared game code (PR 12).

**Steps**

1. Maze with 1 phone: finish the maze. Check: the title says '<name> wins!', the list has one row '1st  <name>  <time> s', and the buttons are **Restart** and **Back to menu**. The text is easy to read from the sofa.
2. Maze with 2 to 4 phones: let one ball reach the exit first. Check: the winner is '1st' with a time, the other balls are listed as 'not finished' (nearest to the exit first), and the list and the buttons stay inside the screen edge (60 px).
3. Marble Race with 4 phones on any track: let all marbles finish. Check: the list shows 4 rows with times, best first, and a title with the winner. The card with the list and the 3 buttons (Restart, Choose track, Back to menu) is inside the screen edge and can be read.
4. Marble Race with 4 phones: let one marble finish and wait about 4 seconds for the end. Check: the marbles that did not finish are listed as 'not finished', the furthest first.
5. Marble Race, at the results: choose **Choose track**, then **Cancel**. Check: the results come back with the same list.
6. Marble Race: when the race is over and the results show, switch off the Wi-Fi of all phones (or leave the game on every phone). Then choose **Choose track** and **Cancel**. Check: the menu says 'No players connected' and has only **Back to menu**. (REQ-MR-14)
7. Target Shoot with 1 phone: play a full round. Check: the title is a medal ('Bronze medal!', 'Silver medal!', 'Gold medal!') or 'No medal this time', and the list has one row with the score. With 2 phones: the title names the winner, or says 'Tie!' for equal scores.

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
3. Check the tiles of **Tilt Maze** and **Marble Race**. They were made before the chip style changed: they may still show 'P1 Phone 1' on the chips. If the tile and the game differ, tell Claude: the tiles are made again with `tools/make_tiles.gd`.
4. Check the tile of **Target Shoot**: it shows the blue board, targets, two cursors with their numbers and the hint. Check that the cursor and the targets can be seen at the small size of the tile.

**Results**

| Item | Evidence to capture | Result | Run | Evidence | Notes |
|------|---------------------|--------|-----|----------|-------|
| 1 | Photo of the Games screen | Not run | | | |
| 2 | Photos: tile next to the game, for each game | Not run | | | |
| 3 | Photos of the old and the new look, and a note | Not run | | | |
| 4 | Photo of the tile and of the running game | Not run | | | |

History:

- -: **Not run**. New.
