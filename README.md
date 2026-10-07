# Remote Play

A couch game for Android TV. A phone is the motion controller (Wii-remote style).
Godot 4.7 and GDScript. One project makes two apps:

- **tv**: runs on Android TV or a streaming box. It shows the game.
- **controller**: runs on up to 4 Android phones. It sends gyroscope, accelerometer, touch and button data.

The games are minigames that use the phone as a motion controller: a tilt maze, a pointer test,
a 3D demo and a 3D marble race (with several tracks). New minigames are added through the game registry (see below).

Docs: [requirements](docs/REQUIREMENTS.md) | [game requirements](docs/GAME_REQUIREMENTS.md) (per game: `docs/games/`) | [TV flow](docs/TV_FLOW.md) | [device test plan](docs/DEVICE_TEST.md) | [protocol](docs/PROTOCOL.md) | [export steps](docs/EXPORT.md) | [risks](docs/RISKS.md)

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

- TV flow: Android splash, logo screen, **Connect controllers** (QR code, room code, 4 slots, Continue), **Games** (tiles with a
  screenshot, the players badge, the Settings gear), then the game. Back goes one step back. Full flow: [docs/TV_FLOW.md](docs/TV_FLOW.md).
  Phones follow the TV: they show "Waiting for the host", "Choose a game on the TV", or the pad.
- The role is chosen by the feature tag `tv` or `controller`. On desktop, use `-- --role=tv` or `-- --role=controller`.
- The TV shows a 4-letter room code and a QR code (`ws://IP:47801/ROOM`).
  The phone scans the QR code (Android plugin), or finds the TV by the UDP beacon, or the user types the room code or the TV IP.
- The phone sends raw sensor values. The TV does the sensor fusion (`scripts/input/orientation.gd`),
  so one code path is easy to tune.
- A phone that loses the connection keeps its slot for 30 seconds and reconnects with a token.
  The game pauses while a player is lost.
- The debug overlay (Menu key, F3, or the switch on the Settings screen) shows per player: RTT, sensor age, packet rate,
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
  game/                  minigame.gd (2D base), minigame_3d.gd (3D base), registry.gd (game list), maze/, pointer_test/, demo3d/, marble_race/
  ui/                    TV screens (tv_logo, tv_connect, tv_games, tv_settings, players_modal), controller screens
                         (controller_connect, controller_wait, controller_pad), ui_theme, ui_kit, debug_overlay
android/plugin/          QrScannerPlugin.java (Android plugin: Google code scanner)
tests/                   headless tests (see below) and screenshot scripts
tools/                   make_icons.gd, patch_android_manifest.sh
docs/                    requirements, protocol, export, risks
```

All screens are built in code in the Party Pop style (docs/TV_FLOW.md). Image files: the two fonts (`assets/fonts`),
the game tile screenshots (`assets/tiles`, made by `tools/make_tiles.gd`), the logo (`assets/logo`) and the icons.

**Separation rule:** `net/` and `input/` never refer to `game/`.
Games only read `PlayerInput` (`tilt()`, `pointer()`, `is_down()`, `button_pressed`, raw values).

### Add a minigame

0. Write the requirements: copy `docs/games/TEMPLATE.md` to `docs/games/<id>.md`. The general rules are in
   `docs/GAME_REQUIREMENTS.md`.
1. Make a folder under `scripts/game/`.
2. Extend `scripts/game/minigame.gd`. Override `_game_ready()`, `_game_tick(delta)`, `_game_draw()`.
   The base class is the game shell: the player list, the pause when a phone is lost, the D-pad pause menu
   (Resume, Restart, Back to menu), the result menu (`open_menu`), and the Back key. Draw titles, score chips, the
   countdown and hints with `scripts/game/shell.gd`.
3. Add one entry for the game in `scripts/game/registry.gd` (with `doc`, `description` and `tile`). The Games screen is built
   from that list. Run `tools/make_tiles.gd` to make the tile screenshot (see the header of that file).

For a 3D game, extend `scripts/game/minigame_3d.gd` instead. Override `_world_ready()` (build the scene under `world`),
`_world_tick(delta)` and optionally `_hud_draw(canvas)`. `scripts/game/demo3d/` is a small template.
The 3D world is frozen while the game is paused.

A registry entry may have `props`, set on the game before it starts (and kept for Restart). An entry with `variants`
(a list of title and props) makes the menu ask which variant to start first. The marble race uses this to pick a track
(`track_id`). The track can also be changed from its results menu, but not from the pause menu. Tracks are in `scripts/game/marble_race/marble_track.gd`:
add an id to `IDS`, a case in `make()`, and one registry entry.

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
   If a direction is wrong, use the invert switches on the TV Settings screen (the gear on the Games screen).
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
| TV remote | Back | Back one level. Games: Connect screen (players stay). Connect: quit question |
| TV remote | Menu (or F3) | Show or hide the debug overlay |

## Tests

```sh
GODOT=/path/to/godot tests/run_all.sh
```

- `tests/run_tests.gd`: packet codec, sensor fusion (tilt, yaw, bias, timestamp wrap), maze generator,
  QR encoder, and a network test with a real server and 4 clients (join, full room, wrong room, RTT,
  reconnect to the same slot, leave, phase message).
- `tests/smoke_tv.gd`: starts the whole TV app, runs the flow (logo, Connect, Games, Settings, Players modal, Remove, Back),
  joins 2 simulated phones, and runs the maze (tilt moves the ball, late phone waits, pause on lost phone, pause menu,
  restart), the pointer test, the 3D demo and the marble race.
- `tests/screenshots*.gd`: save screenshots (needs a display, for example `xvfb-run`).

## Status

- Tested: headless tests above, and a two-process run (TV and phone) on one PC with real UDP discovery.
  The QR codes decode with an independent decoder (OpenCV).
- **Not tested: real Android TV, real phone sensors, real Wi-Fi.** The first on-device run must check the
  items marked *unverified* in [docs/RISKS.md](docs/RISKS.md), mainly the sensor signs and the key mapping.
- The QR scanner plugin compiled only against stubs (the real ML Kit and Godot libraries were not reachable
  from the build sandbox). It needs Google Play services on the phone. Test it first: `docs/DEVICE_TEST.md`, test 2.
