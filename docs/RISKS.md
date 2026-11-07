# Open risks and mitigations

This document uses ASD-STE100 style. The code passed headless tests only (`tests/run_all.sh`).
Nobody has tested it on a real TV or phone yet. Items marked **(unverified)** need a check on a device.

## A. Motion quality

| # | Risk | Effect | Mitigation |
|---|------|--------|------------|
| A1 | **Gyro yaw drift.** Integration of the gyroscope gives a yaw that moves slowly. | The cursor leaves the target after some seconds. | Done: the yaw is frozen while the phone is still; the gyro bias is learned while still; the Recenter button. Next: use `Input.get_magnetometer()` as a slow yaw reference (it fails near metal and speakers), or add a plugin that reads the Android rotation-vector sensor. |
| A2 | **Axis and sign conventions (unverified).** Godot may flip the sign of the accelerometer or gyroscope on Android. | Tilt or yaw is inverted. | Done: the Settings switch *Invert tilt axes*, and raw values in the overlay. After you know the real signs, set the defaults in `app.gd` (`settings`). |
| A3 | **Sensor rate (unverified).** Android can give gyroscope data at less than 60 Hz. Godot reads the latest value. | Repeated samples; steps in the cursor. | Compare *Rx Hz* with the number of changing values in the overlay. If the sensor rate is low, a plugin can request a faster rate (needs `HIGH_SAMPLING_RATE_SENSORS` above 200 Hz). |
| A4 | **Phone held in other poses.** The yaw rate is projected on gravity. | Pointing straight up or down is unstable. | Acceptable for a TV pointer. Games should keep the phone near horizontal or vertical. |
| A5 | **Maze physics values are guesses.** `TILT_ACCEL`, friction and limits are in `maze_game.gd`. | The ball feels too light or too heavy. | Change the constants while you play. This is the main tuning step of the "feel" test. |

## B. Latency and network

| # | Risk | Effect | Mitigation |
|---|------|--------|------------|
| B1 | **TCP head-of-line blocking.** One lost packet delays all packets behind it. | Latency spikes (*Gap ms* and *Age ms* in the overlay). | Measure first. If gaps over 50 ms are common, add a UDP sensor channel (same packet layout, with the token in a header). Packets that arrive late are dropped, not queued. |
| B2 | **Wi-Fi power saving** on the phone or the TV. | Bursts of 100 ms or more. | Use 5 GHz. Disable battery saver on the phone. A low-latency Wi-Fi lock (`WIFI_MODE_FULL_LOW_LATENCY`) needs a small Android plugin. |
| B3 | **TV box on Wi-Fi.** Many boxes have weak antennas. | High jitter for all players. | Use an Ethernet cable on the TV box. Keep the router in the same room. |
| B4 | **Clock offset error.** Sensor age has an error of +/- RTT/2. It can be negative. | Misleading absolute value. | Use the trend. For a true end-to-end figure, record a screen with a high-speed camera. The RTT is exact. |
| B5 | **More players, more load.** 4 phones x 60 packets/s x 36 bytes is small (about 10 kB/s). | None expected. | Check *Rx Hz* of all slots when 4 phones play. |
| B6 | **Input to photon delay is more than the network.** TV display lag (game mode off) can add 50 ms or more. | The game feels late even with a good network. | Turn on the game mode of the TV. |

## C. Discovery and connection

| # | Risk | Effect | Mitigation |
|---|------|--------|------------|
| C1 | **The room code does not reach the TV** (guest Wi-Fi with AP isolation, a VPN on the phone, mobile data only, TV and phone on networks that do not share the first two numbers of the address). | The typed code shows "CAN'T FIND THIS ROOM". | Done (issue #52, FD-28): the status line says to scan the QR code, which holds the full address. The TV sends no broadcast, so a blocked broadcast does not matter. |
| C2 | **Multicast lock (not needed).** | - | Removed with the beacon (issue #52): the permission `CHANGE_WIFI_MULTICAST_STATE` and the `MulticastLock` are gone. |
| C3 | **Wrong IP on the TV.** Devices with Ethernet and Wi-Fi have two addresses. The code prefers 192.168.x.x, then 10.x, then 172.16-31.x. | The QR code or the URL shows the wrong address. | Add a menu item to choose the interface. The room code is the code of that address, so a wrong address gives a code that does not work; the phone says that the room is not found. |
| C4 | **The first two numbers.** A typed room code holds only the last two numbers of the TV address. | Wrong on a network where the phone and the TV differ in the first two numbers (rare). | The QR code holds the full address. |
| C5 | **QR scanner plugin is unverified.** It is a small Java plugin (`android/plugin/QrScannerPlugin.java`) for the Google code scanner. It was first compiled only against stubs; Test 2 steps 3a and 3b passed on a phone in R5. It needs Google Play services. | Scan fails or the app does not build. | Check on a phone (`docs/MANUAL_TESTS.md`, test 2). Fallbacks: the list, the room code, the TV IP. Use ZXing (`zxing-android-embedded`) if the phone has no Play services. |
| C6 | **No password; the host approves new phones.** The room code or the QR code gets a phone only as far as the card on the TV: with the setting "approve new players" ON (the default, REQ-FL-93, issue #393) the adult with the remote lets each new phone in; with it OFF any device on the LAN can join (the join PIN was removed in issue #52). The traffic is plain WebSocket (FD-28): a device that reads it can copy a token and resume as that player with no card (FD-30.4; it needs a capture of the Wi-Fi traffic, not just the room code). | A neighbour on shared Wi-Fi can build the room code and ask; the host sees the request and can refuse. With the setting OFF the neighbour joins. One Left press on the first Settings row turns the approval OFF (JA-R12). | Approval ON by default; the host refuses with REFUSE; 3 refusals block the address for 60 s (REQ-FL-104). Acceptable for a home LAN. The privacy notice must say it (owner text, `needs-owner`, issue #393). |
| C7 | **The phone app goes to the background.** Android stops the sensors and the app. | The slot becomes `LOST`; the game pauses with a card and waits for the TV user (REQ-GM-30). | Done: the reconnect with token. The slot grace is 5 s (`Protocol.SLOT_GRACE_MS`) and 5 min while the game is paused (`Protocol.PAUSED_SLOT_GRACE_MS`), so a phone call does not end the game. |

## D. Android and TV platform

| # | Risk | Effect | Mitigation |
|---|------|--------|------------|
| D1 | **Portrait lock is set at run time (unverified).** The Godot manifest value comes from the project setting (landscape). The phone app calls `screen_set_orientation`. | A short landscape flash at start. | Edit `android:screenOrientation` in `android/build/src/main/AndroidManifest.xml` for a phone-only build. |
| D2 | **Remote key mapping (unverified).** The OK button must map to `ui_accept`, the Back button to `KEY_BACK`. The Menu key does not exist on all remotes. | Cannot toggle the overlay or go back. | The overlay switch is also a menu item. Back also works through `NOTIFICATION_WM_GO_BACK_REQUEST`. |
| D3 | **32-bit TV boxes.** Many boxes run a 32-bit system. | `arm64` APK does not install. | The `tv` preset builds `armeabi-v7a` and `arm64-v8a`. |
| D4 | **Gradle build is required for Android TV.** | The export needs JDK, SDK and the template. | See `docs/EXPORT.md`. |
| D5 | **Overscan and TV safe area.** | Text near the edge can be cut. | The layout keeps 60 px margins. Check on your TV. |
| D6 | **Android TV has no touchscreen and sometimes no sensors.** | None for the TV app. | The manifest sets `required="false"` for these features. |

## E. Known limits

- Profiles (FD-22): a reinstall or "clear data" deletes the profiles of a phone (a copy by QR, phase B, is the only backup). A name can use only letters of the two alphabets, digits and the space, because the pixel fonts have no other glyph. An avatar may be hard to tell apart at the size of the small ball (a 16 px picture at a whole-number scale; a player object shows no number and no avatar, REQ-GM-46). The same profile on two phones: a connected holder keeps the profile and a newer phone that joins with it is sent away with a message and takes no slot; a lost holder is replaced (REQ-FL-74). A profile code is a QR code of up to version 14 (73 modules): it may scan badly from far away or on a dim screen (test 20 items 12 and 14); an iPhone cannot scan, so it pastes the text. A personal best is a number on a phone: anybody can change it with an edited app, and it is not proof of anything (this is a family game). If a track or a game changes so that a saved score means something else, a new key number is added (never a changed one). A profile code gives the player to anybody who scans it, and the code goes away after 60 seconds. The QR encoder has no decoder in the repository: it was checked once with an outside decoder (zxing-cpp, 66 texts of all versions) and a fixed text with the hash of its modules is in `tests/qr.gd`. The Hebrew texts of the profile screens are written by Claude and need a native reader (test 20 and test 17).

- Balls do not collide with each other.
- The maze size follows the Difficulty (REQ-MZ-9), and there is no level progress.
- Sound (FD-20): made in code, so no license and no file. Open risks: the taste of the songs, the render time of a song on a TV box (it is made in steps of 3 ms a frame; the first test measures it), the latency of the TV box, and many effects at once with 4 players. Manual test 18.
