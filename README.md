# Remote Play

A prototype of a couch game for Android TV. A phone is the motion controller (Wii-remote style).
Godot 4.7 and GDScript. One project makes two apps:

- **tv**: runs on Android TV or a streaming box. It shows the game.
- **controller**: runs on up to 4 Android phones. It sends gyroscope, accelerometer, touch and button data.

The goal is to judge the *feel* of a phone as a motion controller. The game content is small on purpose:
a tilt maze and a pointer test.

Docs: [requirements](docs/REQUIREMENTS.md) | [device test plan](docs/DEVICE_TEST.md) | [protocol](docs/PROTOCOL.md) | [export steps](docs/EXPORT.md) | [risks](docs/RISKS.md)

## How it works

```
 Phone (controller)                               TV
 ┌─────────────────────┐   UDP 47800 beacon    ┌──────────────────────┐
 │ sensor_sampler 60 Hz│ <──────────────────── │ tv_discovery         │
 │ controller_client   │   WebSocket 47801     │ tv_server (4 slots)  │
 │  (reconnect, ping)  │ ────────────────────> │  -> PlayerInput      │
 └─────────────────────┘  36-byte sensor pkt   │      -> Orientation  │
                          + JSON control       │ minigames read       │
                                               │ PlayerInput only     │
                                               └──────────────────────┘
```

- The role is chosen by the feature tag `tv` or `controller`. On desktop, use `-- --role=tv` or `-- --role=controller`.
- The TV shows a 4-letter room code and a QR code (`ws://IP:47801/ROOM`).
  The phone scans the QR code (Android plugin), or finds the TV by the UDP beacon, or the user types the room code or the TV IP.
- The phone sends raw sensor values. The TV does the sensor fusion (`scripts/input/orientation.gd`),
  so one code path is easy to tune.
- A phone that loses the connection keeps its slot for 30 seconds and reconnects with a token.
  The game pauses while a player is lost.
- The debug overlay (Menu key, F3, or the menu item) shows per player: RTT, sensor age, packet rate,
  longest gap, lost packets, raw gyroscope and accelerometer, tilt and pointer.

## Project structure

```
project.godot            autoloads: Role, App. Main scene: scenes/boot.tscn (an empty node)
export_presets.cfg       presets "tv" and "controller"
scripts/
  app.gd                 autoload. Owns services, switches screens, settings
  core/                  protocol.gd (constants, packet codec), role.gd, qr_encoder.gd
  net/                   tv_server, tv_discovery, controller_client, controller_discovery, qr_scanner
  input/                 sensor_sampler (phone), orientation (fusion), player_input (state per slot)
  game/                  minigame.gd (base class), maze/, pointer_test/
  ui/                    tv_menu, debug_overlay, controller_connect, controller_pad, ui_theme
android/plugin/          QrScannerPlugin.java (Android plugin: Google code scanner)
tests/                   headless tests (see below) and screenshot scripts
tools/                   make_icons.gd, patch_android_manifest.sh
docs/                    requirements, protocol, export, risks
```

All screens are built in code from flat shapes. There are no external assets.

**Separation rule:** `net/` and `input/` never refer to `game/`.
Games only read `PlayerInput` (`tilt()`, `pointer()`, `is_down()`, `button_pressed`, raw values).

### Add a minigame

1. Make a folder under `scripts/game/`.
2. Extend `scripts/game/minigame.gd`. Override `_game_ready()`, `_game_tick(delta)`, `_game_draw()`.
   The base class gives you the player list, the pause when a phone is lost, the D-pad pause menu
   (Resume, Restart, Back to menu), and the Back key.
3. Add one button for the game in `scripts/ui/tv_menu.gd`.

## Run on a PC

```sh
godot --path . -- --role=tv                       # TV window
godot --path . -- --role=controller --auto-join   # phone window. Joins the first TV found.
```

TV keys: arrows, Enter, Esc (back), F3 (overlay).
The phone window has no sensors. The mouse simulates tilt (position) and yaw (movement).

## Build and export

Short version. Full steps and a problem table: [docs/EXPORT.md](docs/EXPORT.md).

1. Install Godot 4.7 (with export templates), JDK 17 (`brew install openjdk@17`) and the Android SDK. JDK 26 does not work with the Gradle build.
2. Run `tools/setup.sh`. It sets the JDK path in the editor settings, installs the Android build template,
   and patches the manifest (TV banner, hardware flags, QR scanner plugin).
3. Build the APKs: `tools/build.sh apk` (output: `build/remote-play-tv.apk`, `build/remote-play-controller.apk`).
4. Deploy to a connected device: `tools/deploy.sh controller` or `tools/deploy.sh tv` (builds, installs, launches; `-s <serial>` picks a device).
5. Other commands: `tools/build.sh run-tv`, `run-controller`, `test`.
6. Install (or `tools/build.sh install`): `adb connect <tv-ip>:5555`, then `adb install -r build/remote-play-tv.apk`.
   Install the controller APK on the phone.

## Test on a real Android TV or streaming box

1. Enable developer options and ADB debugging on the TV (see [docs/EXPORT.md](docs/EXPORT.md), section 5).
2. Put the TV and the phones on the same Wi-Fi network (5 GHz is best; Ethernet on the TV box is better).
3. Start the TV app. Start the controller app. Scan the QR code on the TV (or tap the TV in the list).
4. Open the debug overlay. Watch RTT, *Age ms*, *Gap ms*, and *Rx Hz*.
   The full test plan with pass criteria is in [docs/DEVICE_TEST.md](docs/DEVICE_TEST.md).
5. Run **Pointer Test**: tap RECENTER while you point at the TV. Check drift, range and direction.
   If a direction is wrong, use the invert switches in the TV menu.
6. Run **Tilt Maze** with 1 to 4 phones.

## Controls

| Where | Control | Action |
|-------|---------|--------|
| Phone | RECENTER | Set the neutral pose and zero the yaw |
| Phone | A / B | Buttons. In the maze, A recenters. In the pointer test, A = shoot, B = recenter |
| Phone | Scan / Paste TV link | Join by the QR code on the TV (or by the link in the clipboard on a PC) |
| Phone | Leave | Leave the TV and return to the connect screen |
| TV remote | D-pad | Move the focus |
| TV remote | OK | Select. In a game: open the pause menu |
| TV remote | Back | Back one level. On the main menu: quit |
| TV remote | Menu (or F3) | Show or hide the debug overlay |

## Tests

```sh
GODOT=/path/to/godot tests/run_all.sh
```

- `tests/run_tests.gd`: packet codec, sensor fusion (tilt, yaw, bias, timestamp wrap), maze generator,
  QR encoder, and a network test with a real server and 4 clients (join, full room, wrong room, RTT,
  reconnect to the same slot, leave, phase message).
- `tests/smoke_tv.gd`: starts the whole TV app, joins 2 simulated phones, runs the menu, the maze
  (tilt moves the ball, pause on lost phone, pause menu, restart) and the pointer test.
- `tests/screenshots*.gd`: save screenshots (needs a display, for example `xvfb-run`).

## Status

- Tested: headless tests above, and a two-process run (TV and phone) on one PC with real UDP discovery.
  The QR codes decode with an independent decoder (OpenCV).
- **Not tested: real Android TV, real phone sensors, real Wi-Fi.** The first on-device run must check the
  items marked *unverified* in [docs/RISKS.md](docs/RISKS.md), mainly the sensor signs and the key mapping.
- The QR scanner plugin compiled only against stubs (the real ML Kit and Godot libraries were not reachable
  from the build sandbox). It needs Google Play services on the phone. Test it first: `docs/DEVICE_TEST.md`, test 2.
