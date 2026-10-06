# Open risks and mitigations

This document uses ASD-STE100 style. The code passed headless tests only (`tests/run_all.sh`).
Nobody has tested it on a real TV or phone yet. Items marked **(unverified)** need a check on a device.

## A. Motion quality

| # | Risk | Effect | Mitigation |
|---|------|--------|------------|
| A1 | **Gyro yaw drift.** Integration of the gyroscope gives a yaw that moves slowly. | The cursor leaves the target after some seconds. | Done: the yaw is frozen while the phone is still; the gyro bias is learned while still; the Recenter button. Next: use `Input.get_magnetometer()` as a slow yaw reference (it fails near metal and speakers), or add a plugin that reads the Android rotation-vector sensor. |
| A2 | **Axis and sign conventions (unverified).** Godot may flip the sign of the accelerometer or gyroscope on Android. | Tilt or yaw is inverted. | Done: menu switches *Invert tilt axes* and *Invert pointer yaw*, and raw values in the overlay. After you know the real signs, set the defaults in `app.gd` (`settings`). |
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
| C1 | **UDP broadcast is blocked** (guest Wi-Fi, AP isolation, some mesh systems, VPN). | The phone does not find the TV. | Done: typing the TV IP works without the beacon. The TV screen shows `ws://IP:47801/ROOM`. |
| C2 | **No multicast lock (unverified).** Some phones drop broadcast packets in power saving. | Discovery is slow or fails. | Add `CHANGE_WIFI_MULTICAST_STATE` and a plugin that holds a `MulticastLock`. |
| C3 | **Wrong IP on the TV.** Devices with Ethernet and Wi-Fi have two addresses. The code prefers 192.168.x.x, then 10.x, then 172.16-31.x. | The QR code or the URL shows the wrong address. | Add a menu item to choose the interface. The beacon uses the real sender address, so the list on the phone is still right. |
| C4 | **The /24 assumption.** The subnet broadcast uses `x.y.z.255`. | Wrong on /16 networks. | `255.255.255.255` is also sent. |
| C5 | **The QR code cannot be scanned inside the app.** Godot has no QR reader. | The user cannot scan. | The phone camera app can read the QR code, but it cannot open the controller app. Use the list or the room code. A GDScript QR decoder on camera frames is possible but large. |
| C6 | **No authentication.** Any device on the LAN can join with the room code. | A neighbour on shared Wi-Fi can join. | Acceptable for a prototype. Add a PIN in `hello` if needed. |
| C7 | **The phone app goes to the background.** Android stops the sensors and the app. | The slot becomes `LOST`; the game pauses. | Done: the reconnect with token. The 30 s slot grace is in `Protocol.SLOT_GRACE_MS`. |

## D. Android and TV platform

| # | Risk | Effect | Mitigation |
|---|------|--------|------------|
| D1 | **Portrait lock is set at run time (unverified).** The Godot manifest value comes from the project setting (landscape). The phone app calls `screen_set_orientation`. | A short landscape flash at start. | Edit `android:screenOrientation` in `android/build/AndroidManifest.xml` for a phone-only build. |
| D2 | **Remote key mapping (unverified).** The OK button must map to `ui_accept`, the Back button to `KEY_BACK`. The Menu key does not exist on all remotes. | Cannot toggle the overlay or go back. | The overlay switch is also a menu item. Back also works through `NOTIFICATION_WM_GO_BACK_REQUEST`. |
| D3 | **32-bit TV boxes.** Many boxes run a 32-bit system. | `arm64` APK does not install. | The `tv` preset builds `armeabi-v7a` and `arm64-v8a`. |
| D4 | **Gradle build is required for Android TV.** | The export needs JDK, SDK and the template. | See `docs/EXPORT.md`. |
| D5 | **Overscan and TV safe area.** | Text near the edge can be cut. | The layout keeps 60 px margins. Check on your TV. |
| D6 | **Android TV has no touchscreen and sometimes no sensors.** | None for the TV app. | The manifest sets `required="false"` for these features. |

## E. Prototype limits

- Balls do not collide with each other.
- Only one maze size and no level progress.
- The pointer test measures only a simple hit error. It does not log to a file.
- No sound.
