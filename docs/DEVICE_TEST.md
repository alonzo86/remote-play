# Device test plan

Purpose: find out if the phone-as-controller feel is good, and check the items that the headless tests cannot check.
This document uses ASD-STE100 style. Time needed: about 45 minutes.

## What you need

- 1 Android TV or streaming box, with the `tv` APK installed.
- 1 to 4 Android phones with the `controller` APK. The phones need Google Play services (for the QR scanner).
- 1 Wi-Fi network for all devices. Best: 5 GHz. Turn off VPN on the phones.
- The build steps are in `docs/EXPORT.md`.

Write the results in the table at the end of this file (or copy it).

## Test 1. Start and join

1. Start the TV app. Check: the menu shows a room code, a QR code, and a URL with an IP address (not `?`).
2. Start the controller app on one phone. Check: the phone shows a **portrait** screen.
3. Join with the **TV list** (tap the TV). Check: the phone shows "Connected - Player 1" and the TV shows the phone in slot 1.
4. Tap **Leave**, then join with the **room code**. Check: it joins.
5. Tap **Leave**, then join with the **TV IP address**. Check: it joins.

## Test 2. QR scan (plugin, unverified)

1. Tap **Leave**. On the connect screen, the button must say **Scan the QR code on the TV**.
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
| Turn the phone to the left (like turning on a table) | `Gyro z` positive. In **Pointer Test**, the cursor goes left |
| Point the top of the phone higher | The cursor goes up |

If a direction is wrong, use **Invert tilt axes** or **Invert pointer yaw** in the TV menu. Write down which one you needed.
If the **vertical** pointer direction is wrong but tilt is right, report it (it needs a code change).

## Test 4. Latency and packet rate

Use the overlay. Keep the phone still for 30 seconds, then move it for 30 seconds.

| Value | Good | Acceptable | Problem |
|-------|------|------------|---------|
| RTT ms | below 20 | below 40 | above 60 |
| Rx Hz | 58 to 60 | 50 to 58 | below 50 |
| Gap ms (longest gap in 1 s) | below 40 | below 80 | above 100 |
| Lost | 0 | 0 | any (gaps in the sequence number) |

Also do this: record the TV and the phone with a phone camera in slow motion (240 fps) and count the frames
between a quick phone movement and the cursor movement. This shows the whole delay, including the TV display.
A total below 100 ms feels good. Above 150 ms feels slow.

## Test 5. Pointer drift

1. Open **Pointer Test**. Point at the TV and tap **RECENTER**.
2. Put the phone on a table and leave it for 60 seconds. Write down the yaw value (shown at the bottom, in degrees). Expected: below 1 degree. (The yaw is frozen while the phone is still.)
3. Hold the phone and wave it around for 60 seconds, then point at the center ring again. Write down the offset of the cursor from the center.
   Good: below 5 degrees (about 1/5 of the ring distance). If the offset is larger, tap RECENTER and check how often you must do it.
4. Aim at each ring and press **A**. Write down the *avg error* after 9 hits.

## Test 6. Tilt maze feel

1. Start **Tilt Maze** with 1 phone. Hold the phone level in the countdown.
2. Finish the maze. Write down: does the ball feel too light, too heavy, or good? Is the deadzone good (the ball does not creep when the phone is level)?
3. Tune the constants in `scripts/game/maze/maze_game.gd` (`TILT_ACCEL`, `FRICTION`, `DEADZONE`) if needed.
4. Repeat with 2 to 4 phones. Check *Rx Hz* and *Gap ms* for all players during the race.

## Test 7. Disconnect and reconnect

1. During the maze, switch the phone Wi-Fi off for 5 seconds, then on. Check: the TV pauses ("Waiting for P1 to reconnect"), the phone shows "Reconnecting...", and the game continues when the phone is back.
2. Lock the phone screen for 10 seconds, then unlock. Check: the phone reconnects. (Android can stop the app in the background.)
3. Switch the phone Wi-Fi off for 40 seconds. Check: the slot is freed. When the Wi-Fi is back, the phone joins again (maybe in a different slot).
4. Press OK on the TV remote while a phone is lost. Check: the game continues without that player.

## Test 8. TV remote

1. Use only the remote. Check that the D-pad moves the focus in the menu and OK selects.
2. In a game, press OK. Check: the pause menu opens with Resume, Restart, and Back to menu.
3. Press Back in a game: back to the menu. Press Back in the menu: the app quits.
4. Check the Menu key. If the remote has no Menu key, use the menu item **Debug overlay**.
5. Check: the app icon and banner show in the Android TV home row (the banner is the TV, the maze and the phone).

## Results

| Test | Result (pass / fail / note) |
|------|-----------------------------|
| 1 Join (list, code, IP) | |
| 2 QR scan | |
| 3 Directions (invert switches needed) | |
| 4 RTT / Rx Hz / Gap / Lost | |
| 4 Total delay (camera) | |
| 5 Drift (still, moving) / avg error | |
| 6 Maze feel / constants changed | |
| 7 Reconnect | |
| 8 Remote and banner | |

Send the results (and the `adb logcat -s godot` log for any failure). The next step depends on them:
if the drift, the sensor rate, or the latency spikes are the main problem, see `docs/RISKS.md` (items A1, A3, B1, B2).
