# Device test plan

Purpose: find out if the phone-as-controller feel is good, and check the items that the headless tests cannot check.
This document uses ASD-STE100 style. Time needed: about 45 minutes.

## What you need

- 1 Android TV or streaming box, with the `tv` APK installed.
- 1 to 4 Android phones with the `controller` APK. The phones need Google Play services (for the QR scanner).
- 1 Wi-Fi network for all devices. Best: 5 GHz. Turn off VPN on the phones.
- The build steps are in `docs/EXPORT.md`.

Write the results in the table at the end of this file (or copy it).
Test numbers do not change. Test 5 (pointer drift) was removed with the pointer test.

## Test 1. Start and join

1. Start the TV app. Check: the Android splash shows, then the logo screen with an animation (about 2.5 seconds), then the **Connect controllers** screen with a room code and a QR code. If the QR code is empty, the TV has no Wi-Fi address (the screen says so).
2. Start the controller app on one phone. Check: the phone shows a **portrait** screen.
3. Join with the **TV list** (tap the TV). Check: the phone shows "Waiting for the host" with a colored player circle, the TV shows the phone in slot 1 as "Ready!", and **Continue** is enabled and focused.
   Press OK on **Continue**. Check: the TV shows the Games screen and the phone says "Choose a game on the TV".
4. Tap **Leave**, then tap the TV under **Discovered TVs**. Check: it joins (the button reads "<code> x/y", for example "KQZM 1/4", and it is green; **Refresh** is yellow). Tap **Refresh**. Check: the list shows "Searching..." and the TV is back within 2 seconds.
5. Tap **Leave**, then join with the **TV IP address**. Check: it joins.

## Test 2. QR scan (plugin, unverified)

1. Tap **Leave**. On the connect screen, the button must say **Scan QR code**.
   If it says **Paste TV link**, the plugin is not in the build. Run `tools/patch_android_manifest.sh` and export again.
2. Tap the button and scan the QR code on the TV. Check: the phone joins in less than 5 seconds.
3. Scan again and press Back in the scanner. Check: no error message and the app does not crash.
4. Optional: put a different QR code in front of the phone (for example a web link). Check: the message "This is not a Remote Play code".

## Test 3. Sensor directions (unverified)

Open the debug overlay on the TV (Menu key, or the menu item). Hold the phone in portrait with the screen toward you.

| Action | Expected raw values / result |
|--------|------------------------------|
| Phone flat, screen up, still | `Accel` about `0 0 +9.8` |
| Right side down | `Accel x` negative. In the maze, the ball rolls right |
| Top of phone up | `Accel y` positive. In the maze, the ball rolls toward you (down on the TV) |
| Turn the phone to the left (like turning on a table) | `Gyro z` positive (raw value only. No game uses the yaw now) |

If a direction is wrong, use **Invert tilt axes** on the **Settings** screen of the TV (the gear on the Games screen). Write down which one you needed.

## Test 4. Latency and packet rate

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

## Test 6. Tilt maze feel

1. Start **Tilt Maze** with 1 phone. Hold the phone level in the countdown.
2. Finish the maze. Write down: does the ball feel too light, too heavy, or good? Is the deadzone good (the ball does not creep when the phone is level)?
3. Tune the constants in `scripts/game/maze/maze_game.gd` (`TILT_ACCEL`, `FRICTION`, `DEADZONE`) if needed.
4. Repeat with 2 to 4 phones. Check *Rx Hz* and *Gap ms* for all players during the race.
5. Tilt the phone, then tap **RECENTER**. Check: the ball stops creeping. Tap **A** and **B**. Check: nothing changes (A and B do not recenter, REQ-MZ-8). At GO the phone recenters by itself.

## Test 7. Disconnect and reconnect

1. With two phones joined, during the maze, switch one phone Wi-Fi off for 5 seconds, then on. Check: the TV pauses ("Waiting for P1 to reconnect"), the phone shows "Reconnecting...", and the game continues when the phone is back.
2. Lock the phone screen for 10 seconds, then unlock. Check: the phone reconnects. (Android can stop the app in the background.)
3. Switch the phone Wi-Fi off for 40 seconds. Check: the slot is freed. When the Wi-Fi is back, the phone joins again (maybe in a different slot).
4. Press OK on the TV remote while a phone is lost. Check: the game continues without that player.
5. With only one phone joined, switch its Wi-Fi off during the maze. Check: the game ends at once with "No players connected" (no waiting, no pause message). Do the same in the marble race.
6. On the phone pad, tap **Leave** once. Check: it turns red ("Again") for 3 seconds and the phone does not leave. Tap again within 3 seconds: it leaves. Check the pad buttons: A is green and B is red, both sink when pressed.

## Test 8. TV remote

1. Use only the remote. Check that the D-pad moves the focus on every screen (tiles, badge, gear, buttons) and OK selects. A focused button has a thick black border and lifts (a longer shadow); a focused game tile grows wide and shows its description. Check that the border is visible from the sofa on every button, also on the purple rows. Press and hold OK on a button: it sinks (no shadow). The layout of the buttons does not move.
2. In a game, press OK. Check: the pause menu opens with Resume, Restart, and Back to menu. Choose Back to menu, and also press Back during play. Check: both ask "End the game?" with **Keep playing** (green, in focus) and **End game** (red). The game is paused. Back on the question keeps playing. **End game** goes to the Games screen. After the game is over (result menu), Back leaves at once.
3. Press Back in a game and choose **End game**: back to the Games screen. Press Back on the Games screen: the Connect screen (the players stay). Press Back on the Connect screen: the quit question opens, with **Stay** in focus.
4. Check the Menu key. If the remote has no Menu key, open **Settings** (the gear on the Games screen) and use **Debug overlay**.
5. Check: the app icon and banner show in the Android TV home row (the banner is the TV, the maze and the phone).

## Test 8b. The TV flow and the style

1. Start the TV app from cold. Check: the logo screen goes on by itself after about 2.5 seconds, and OK skips it. Back on the logo screen does not quit.
2. On the Games screen, with one phone joined, check that every tile shows its screenshot, title and player range, and that the text is readable from the sofa (REQ-FL-40).
3. Open the **players badge** (OK). Check: the modal shows the slots, a QR code and the room code. Press **Remove** on a player. Check: the phone says that the host removed it and does not reconnect by itself. Join again with the QR code. Check: the slot fills again.
4. Join a phone while a game runs. Check: the phone says "A round is running", it does not take part, and it joins the next round.
5. Check the motion on the TV box: the logo (with its confetti), the tile growing and shrinking and the screen changes run at 60 frames per second (overlay FPS). Check that the Party Pop colors look right on your TV (not washed out, outlines visible).
6. Phone: check that the fonts and the colors match the TV on the connect, waiting and pad screens.

## Test 9. Marble race (3D)

Needs 2 to 4 phones. Requirements: `docs/games/marble_race.md`. Start "Marble Race" and pick a track.

1. Check: the TV shows the track from above, the order list at the top left, and the track name at the bottom right.
   All text is inside the screen edge and can be read from the sofa. (REQ-MR-9, REQ-MR-35)
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

## Test 10. Target Shoot (pointer)

Needs 1 to 4 phones. Hold each phone like a remote control, pointing at the TV, from the sofa. This is the first game that uses the
gyroscope pointer, so this test also checks the pointer itself (the old Test 5 for drift was removed).

1. Start **Target Shoot** with 1 phone. Hold the phone toward the TV during "3, 2, 1" and press nothing. Check: a cursor ring in the player color follows the phone, a shot in the countdown does nothing, and at "GO" the cursor is in the middle of the screen. (REQ-TS-1, 2)
2. Move the phone left, right, up and down. Check: the cursor moves the same way on the screen. Write down if the cursor is too fast or too slow for the distance from the sofa, and if you need a big arm movement to reach the corners. (`pointer_range_deg` in `orientation.gd`, REQ-TS-3)
3. Hold the phone still for 40 seconds. Check: the cursor stays where it is. Write down how far it drifted (in cm on the screen). Tap **RECENTER**. Check: the cursor goes to the middle. (RISKS A4, REQ-GM-37)
4. Press **A** on a target. Check: the target goes, the points show, the phone buzzes a little. Press A on empty space. Check: a short buzz, the cursor fades, and A does nothing for about half a second. Press B. Check: nothing happens. (REQ-TS-4 to 6)
5. Check that the three target kinds are easy to tell apart from the sofa: cyan (10), small yellow (25) and the pink square with an X (-15). Check that the cursor and its number are easy to see on the dark board. (REQ-TS-12)
6. Play a full round alone. Write down the score. Check the medal at the end and compare with the tiers [200, 350, 500]: are they too easy or too hard? (REQ-TS-15)
7. Play with 2 to 4 phones. Check: both players see the same targets. Two players shoot the same target: only the first one scores. Check the frame rate in the debug overlay with 4 players (60 expected). (REQ-TS-11, REQ-GM-50)
8. Switch one phone Wi-Fi off during a round. Check: the game pauses and then goes on, and the cursor and score of a phone that left are gone. (REQ-TS-16)

## Results

| Test | Result (pass / fail) | Note (optional) |
|------|----------------------|------|
| 1 Join (list, code, IP) | fail | Join by code fails with "Room YCNW not found, is the tv on the same wi-fi?". The list and the IP work. Setup: TV app on a desktop, phone on the same Wi-Fi |
| 2 QR scan | pass | |
| 3 Directions (invert switches needed) | pass | The phone reports every accelerometer axis inverted (flat, screen up: z = -9.83). Fixed in `sensor_sampler.gd` (accelerometer sign flipped on the phone). No invert switch is needed. Checked after the fix: tilt directions in the maze are right. Not re-checked: the gyro rows (turn left, point higher) |
| 4 RTT / Rx Hz / Gap / Lost | fail | RTT above 60 ms, Rx Hz above 55, Gap 150-380 ms, Lost 0. Setup: TV app on a desktop (not a TV box), phone on the same Wi-Fi. Not yet representative of a real TV |
| 4 Total delay (camera) | n/a | didn't test |
| 5 Drift (still, moving) / avg error | n/a | The pointer test was removed (2026-10-07). First run: pass |
| 6 Maze feel / constants changed | retest | First run: drift and inverted controls (caused by Invert tilt axes being on). After the fix, the maze looks good on the desk. Feel and constants not judged yet |
| 7 Reconnect | retest | Wi-Fi off on the phone: the phone shows "Reconnecting...". The game kept running and the TV never showed "Waiting for P1 to reconnect". Wi-Fi on: the phone reconnected and the game resumed. Off time was not measured (the TV pauses only after 5 s of silence) |
| 8 Remote and banner | n/a | didn't test |
| 10 Target Shoot (pointer) | not run | New. Needs the pointer feel (range, drift), the medal tiers and the target sizes |

Send the results (and the `adb logcat -s godot` log for any failure). The next step depends on them:
if the drift, the sensor rate, or the latency spikes are the main problem, see `docs/RISKS.md` (items A1, A3, B1, B2).
