# Sababi

A couch game for Android TV. A phone is the motion controller (Wii-remote style).
Godot 4.7 and GDScript. One project makes two apps:

- **tv**: runs on Android TV or a streaming box. It shows the game.
- **controller**: runs on up to 4 phones: Android, or an iPhone (unverified, see [docs/EXPORT.md](docs/EXPORT.md)). It sends gyroscope, accelerometer, touch and button data.

The games are minigames that use the phone as a motion controller: a tilt maze, a car race (Road Rally, with three themes and several tracks) a pointer game for the whole family: throw bananas at hungry jungle animals (Banana Party), a tilt game where paint blobs paint a floor with a hidden picture and bonus pots (Paint Grab), and a party game where bumpers push each other off a shrinking platform (Sumo Bumpers, 2 to 4 players), and an endless team shooter where tilted spaceships blast waves of falling asteroids and grab upgrades (Star Shield, 1 to 4 players), and bowling with the phone as the ball: turn it to aim and swing it to throw (Pin Pals, 1 to 4 players), and tennis with the phone as the racket: swing it to hit the ball, alone against a ball machine or in teams (Tennis, 1 to 4 players), and mini golf with the phone as the putter: turn it to aim and swing it to putt on five small courses (Mini Golf, 1 to 4 players), and a team game where tilted dogs herd sheep into a pen before the time is up (Sheep Herding, 1 to 4 players), and a pointer game where friendly moles pop out of nine holes and the players bonk them (Whack-a-Mole, 1 to 4 players), a turn-based team game where all players stack bricks into one tower (Tower Builder, 1 to 4 players), and air hockey with a tilt of the phone (Air Hockey: two players enroll with A, and with one phone the computer player ROBO plays the other seat; `scripts/game/bot.gd` is the base class of bots). New minigames are added through the game registry (see below).

Docs: [requirements](docs/REQUIREMENTS.md) | [game requirements](docs/GAME_REQUIREMENTS.md) (per game: `docs/games/`) | [TV flow](docs/TV_FLOW.md) | [manual tests](docs/MANUAL_TESTS.md) | [protocol](docs/PROTOCOL.md) | [export steps](docs/EXPORT.md) | [risks](docs/RISKS.md) | [games roadmap](docs/GAMES_ROADMAP.md) | [design system](docs/design-system/README.md)

## How it works

```
 Phone (controller)                               TV
 ┌─────────────────────┐                       ┌──────────────────────┐
 │ sensor_sampler 60 Hz│   WebSocket 47801     │ tv_server (4 slots)  │
 │ controller_client   │ ────────────────────> │  -> PlayerInput      │
 │  (reconnect, ping)  │  36-byte sensor pkt   │      -> Orientation  │
 └─────────────────────┘  + JSON control       │ minigames read       │
                                               │ PlayerInput only     │
                                               └──────────────────────┘
```

- TV flow: Android splash, logo screen, **Connect controllers** (QR code, room code, 4 slots, "PRESS OK TO CONTINUE"), **Games** (tiles with a
  screenshot, the players badge, the OPTIONS button; the description of the focused game is in a bar under the grid), then the game. Back goes one step back. Full flow: [docs/TV_FLOW.md](docs/TV_FLOW.md).
  Phones follow the TV: they show "Waiting for the host", "Choose a game on the TV", or the pad.
- The role is chosen by the feature tag `tv` or `controller`. On desktop, use `-- --role=tv` or `-- --role=controller`.
- The TV shows a 4-letter room code and a QR code (`ws://IP:47801/ROOM`). The room code is the address of the TV (its last two numbers, scrambled).
  The phone types the room code (all phones, also an iPhone), or scans the QR code (Android plugin). The TV sends nothing on the network by itself: no beacon, no list of TVs ([protocol](docs/PROTOCOL.md), "Room code").
- The phone sends raw sensor values. The TV does the sensor fusion (`scripts/input/orientation.gd`),
  so one code path is easy to tune.
- A phone that loses the connection (or is silent for 3 seconds) keeps its slot and reconnects with a token: 5 seconds, and
  5 minutes while a game is paused for it. The game pauses with a card ("2P LOST CONNECTION") and goes on only when the TV user
  chooses Resume (or Resume without the lost phone). When no player is left, the game ends with "No players connected".
- Player profiles (FD-22, [docs/PROFILES_PLAN.md](docs/PROFILES_PLAN.md)): a phone keeps up to 8 profiles (name of at most 10 characters, one of 32 pixel avatars) in `user://profiles.cfg`. The TV shows the name and the avatar in place of "Player N" and the slot number. The player is chosen on the Connect screen (a dropdown and a + for a new player) and cannot change while the phone is joined: DISCONNECT first. The avatar shows next to the colour on the chips of the game HUD; the objects in a game have only the colour. A player can be copied to another phone with a QR code or a text (SHARE, SCAN A PLAYER, PASTE A CODE). A profile keeps its best score for each game and difficulty (Banana Party, Paint Grab, the 10 tracks of Road Rally); the phone says NEW BEST! after a round.
- Sound (FD-20, [docs/AUDIO_PLAN.md](docs/AUDIO_PLAN.md)): the TV plays an arcade-style song for the menus and one for each game, and sound
  effects. It is made in code by a small chip synthesizer (`scripts/audio/`), so there is no audio file. The Settings screen has Music, Effects
  and Mute. The phone makes no sound: it vibrates in games, and its Settings screen (a button on the waiting screen) has a Haptics ON/OFF switch.
- The debug overlay (Menu key, F3, or the switch on the Settings screen) shows per player: RTT, sensor age, packet rate,
  longest gap, lost packets, raw gyroscope and accelerometer, tilt and pointer.

## Project structure

```
project.godot            autoloads: Role, Sound, App. Main scene: scenes/boot.tscn (an empty node)
export_presets.cfg       presets "tv" and "controller"
scripts/
  app.gd                 autoload. Owns services, switches screens, settings
  audio/                 synth.gd, songs.gd (songs and effects as data), audio_manager.gd (the Sound autoload)
  core/                  protocol.gd (constants, packet codec), role.gd, qr_encoder.gd, profile.gd, profile_store.gd, profile_keys.gd, profile_code.gd
  net/                   tv_server, controller_client, qr_scanner
  input/                 sensor_sampler (phone), orientation (fusion), player_input (state per slot)
  game/                  minigame.gd (2D base), minigame_3d.gd (3D base), registry.gd (game list), maze/, marble_race/
  ui/                    TV screens (tv_logo, tv_connect, tv_games, tv_settings, players_modal), controller screens
                         (controller_connect, controller_wait, controller_pad), ui_theme, ui_kit, debug_overlay
android/plugin/          QrScannerPlugin.java (Android plugin: Google code scanner)
tests/                   headless tests (see below) and screenshot scripts
tools/                   make_icons.gd, patch_android_manifest.sh
docs/                    requirements, protocol, export, risks
```

All screens are built in code in the 8-bit arcade style (FD-18, docs/TV_FLOW.md, docs/ARCADE_STYLE_PLAN.md): the menus, the phone and the game shell since phase 1; the worlds of Sumo Bumpers (phase 2), Road Rally (phase 3, a flat pixel world since 2026-10-15) and Treasure Maze, Paint Grab and Banana Party (phase 4) and Star Shield (2026-10-16) are pixel worlds (a 480x270 view scaled up, REQ-GM-47i to 47n): all game worlds are pixel worlds now. The UI has two languages, English and Hebrew (right to left), chosen on the first start and in Settings (FD-19): `scripts/core/lang.gd` and `assets/lang/strings.csv` (the key, the English and the Hebrew text of each UI text). Image files: the pixel font and the Hebrew fallback font (`assets/fonts`),
the game tile screenshots (`assets/tiles`, made by `tools/make_tiles.gd`), the logo (`assets/logo`) and the icons.

**Separation rule:** `net/` and `input/` never refer to `game/`.
Games only read `PlayerInput` (`tilt()`, `pointer()`, `is_down()`, `button_pressed`, raw values).

### Add a minigame

0. Write the requirements: copy `docs/games/TEMPLATE.md` to `docs/games/<id>.md`. The general rules are in
   `docs/GAME_REQUIREMENTS.md`.
1. Make a folder under `scripts/game/`.
2. Extend `scripts/game/minigame.gd`. Override `_game_ready()`, `_game_tick(delta)`, `_game_draw()`.
   The base class is the game shell: the player list, the pause when a phone is lost, the D-pad pause menu
   (Resume, Try again, End game), the result menu (`open_menu`), and the Back key. Draw titles, score chips, the
   countdown and hints with `scripts/game/shell.gd`. The base class also ends the game when no player is left (`end_no_players()`) and calls
   `_on_player_left(slot)` when a player leaves. Set `is_over = true` when the game ends. `round_clock.gd` (countdown and playing time) and
   `haptics.gd` (buzz cool-down), `scoreboard.gd` (scores and ranking) and `medals.gd` (solo medals) are small helpers for games; `open_results()` shows the ranking.
3. Add one entry for the game in `scripts/game/registry.gd` (with `doc`, `description` and `tile`; `enroll: true` for a game that enrolls its players itself, REQ-GM-106). The Games screen is built
   from that list. Run `tools/make_tiles.gd` to make the tile screenshot (see the header of that file).

For a 3D game, extend `scripts/game/minigame_3d.gd` instead. Override `_world_ready()` (build the scene under `world`),
`_world_tick(delta)` and optionally `_hud_draw(canvas)`. No game uses it now: Road Rally (`scripts/game/marble_race/`) was a 3D game until 2026-10-15 and is a flat pixel world now.
A key object (player, goal, hazard) gets an outline with `add_outlined_mesh()`.
The 3D world is frozen while the game is paused.

A registry entry may have `props`, set on the game before it starts (and kept for Try again). An entry with a `settings`
list has a settings view (Difficulty and the rows of the list) before the game: the choices become props of the game
(`scripts/game/game_settings.gd`, `scripts/ui/tv_game_settings.gd`). Road Rally has a Theme row (Candy Road, Space Rally, Jungle Run) and a `tracks` row: 10 fixed tracks and a random one,
all made from seeds by `MarbleTrack.generate()` in `scripts/game/marble_race/marble_track.gd`. The pause menu does not change settings.

## Run on a PC

```sh
godot --path . -- --role=tv                       # TV window
godot --path . -- --role=controller --join=127.0.0.1   # phone window. Joins the TV at that address.
```

TV keys: arrows, Enter, Esc (back), F3 (overlay).
The phone window has no sensors. The mouse simulates tilt (position) and yaw (movement).

## Build and export

Short version. Full steps and a problem table: [docs/EXPORT.md](docs/EXPORT.md).

1. Install Godot 4.7 (with export templates), JDK 17 (`brew install openjdk@17`) and the Android SDK. JDK 26 does not work with the Gradle build.
2. Run `tools/setup.sh`. It sets the JDK path in the editor settings, installs the Android build template,
   and patches the manifest (TV banner, hardware flags, QR scanner plugin).
3. Build the APKs: `tools/build.sh apk` (output: `build/sababi-tv.apk`, `build/sababi-controller.apk`).
4. Deploy to a connected device: `tools/deploy.sh controller` or `tools/deploy.sh tv` (builds, installs, launches; `-s <serial>` picks a device).
5. iPhone (controller only, unverified): `IOS_TEAM_ID=<team id> tools/deploy-ios.sh`. Steps: [docs/EXPORT.md](docs/EXPORT.md), section *Controller on an iPhone*.
6. Other commands: `tools/build.sh run-tv`, `run-controller`, `test`.
7. Install (or `tools/build.sh install`): `adb connect <tv-ip>:5555`, then `adb install -r build/sababi-tv.apk`.
   Install the controller APK on the phone.
   A device with an older build (Remote Play, Wobble, or Sababi with the test package names) keeps it, because the package names
   changed (FD-21, FD-26, FD-27): remove it with `adb uninstall com.example.remoteplay.tv`, `adb uninstall com.example.remoteplay.controller`,
   `adb uninstall com.example.wobble.tv`, `adb uninstall com.example.wobble.controller`,
   `adb uninstall com.example.sababi.tv` and `adb uninstall com.example.sababi.controller`.

## Test on a real Android TV or streaming box

1. Enable developer options and ADB debugging on the TV (see [docs/EXPORT.md](docs/EXPORT.md), section 5).
2. Put the TV and the phones on the same Wi-Fi network (5 GHz is best; Ethernet on the TV box is better).
3. Start the TV app. Start the controller app. Scan the QR code on the TV (or tap the TV in the list).
4. Open the debug overlay. Watch RTT, *Age ms*, *Gap ms*, and *Rx Hz*.
   The full test plan with pass criteria is in [docs/MANUAL_TESTS.md](docs/MANUAL_TESTS.md).
5. Run **Treasure Maze** with 1 to 4 phones. If the ball rolls the wrong way, use **Invert tilt axes** on the TV Settings screen
   (the gear on the Games screen).
6. Run **Road Rally** and check the frame rate with 4 phones.

## Controls

| Where | Control | Action |
|-------|---------|--------|
| Phone | RECENTER | Set the neutral pose and zero the yaw |
| Phone | A / B | Buttons. Each game shows only the buttons it uses (the maze and the race show none); only the pointer games (Banana Party and Whack-a-Mole) have the RECENTER button |
| Phone | Scan / Paste TV link | Join by the QR code on the TV (or by the link in the clipboard on a PC) |
| Phone | Disconnect | Leave the TV at once (one tap) and return to the connect screen |
| TV remote | D-pad | Move the focus |
| TV remote | OK | Select. In a game: open the pause menu |
| TV remote | Back | Back one level. Games: Connect screen (players stay). Connect: quit question |
| TV remote | Menu (or F3) | Show or hide the debug overlay |

## Tests

```sh
GODOT=/path/to/godot tests/run_all.sh
```

The suites are listed once, in `tests/suites.txt` (script, role, title). `tests/run_suites.sh` runs them. A new suite is added to that file only.
`tests/run_all.sh` is the quick local run (the suites and the check of `tokens.css`). CI has two jobs for this. `test` runs the suites
on the instrumented copy of the project (`COVERAGE_STEP=run tools/coverage.sh`), so a failure there is a failed test, and it keeps the
coverage hits. `coverage` (after `test`) reads those hits and fails when a module is below 80% (`COVERAGE_STEP=report tools/coverage.sh`).
No test runs twice. `tests/suites.txt` has a tier for each suite: `unit` suites (the logic of one module or one rule) are what the CI runs,
and `scenario` suites (screens, layouts, texts, flows) run locally or on demand (the label `full-tests`, or a manual run); `tests/run_all.sh
unit|scenario|all` runs a tier. The CI reports the coverage and never fails on it: the 80% rule is the local check `tools/coverage.sh` (all
suites). When each CI job runs is in `docs/AUTOMATED_TESTS.md`, section "CI minutes".

- `tests/run_tests.gd`: packet codec, sensor fusion (tilt, yaw, bias, timestamp wrap), maze generator,
  QR encoder, and a network test with a real server and 4 clients (join, full room, wrong room, RTT,
  reconnect to the same slot, leave, phase message).
- `tests/smoke_tv.gd`: starts the whole TV app, runs the flow (logo, Connect, Games, Settings, Players modal, Remove, Back),
  joins 2 simulated phones, and runs the maze (tilt moves the ball, late phone waits, pause on lost phone, pause menu,
  restart) and the race.
- `tests/audio.gd`: the synthesizer, the songs and effects (every effect the code plays exists), the `Sound` manager, the volume rows of the
  Settings screen and the phone Haptics switch.
- `tests/screenshots*.gd`: save screenshots (needs a display, for example `xvfb-run`).

### Coverage

```sh
GODOT=/path/to/godot tools/coverage.sh        # needs python3 and gdtoolkit (pip install "gdtoolkit==4.*")
```

Godot has no coverage switch, so `tools/coverage/instrument.py` makes a copy of the project and puts a hit call before each
statement inside a function in `scripts/` (it uses the parser of gdtoolkit). The suites of `tests/suites.txt` run on the copy. The result is in
`build/coverage/`: `summary.md`, `summary.json` and `lcov.info`.
**The rule: every module (script file) has at least 80% line coverage.** The script fails when one is lower, and the CI job
`coverage` runs the same script, shows the table in the run summary and keeps the files for 14 days. A module that needs extremely hard
work to test today (a real device, an external service) can be set aside in `tools/coverage/exclusions.txt` (`path | reason`).
Tests check behavior. Do not write a test only to cover lines. See `CLAUDE.md`, "Tests and coverage".
What it counts: statements in functions that start on their own line. Class variables and constants are not counted.
Phone-only and Android-only code (`qr_scanner.gd`, `sensor_sampler.gd`) stays low, because only a device can run it.

## Status

- Tested: headless tests above, and a two-process run (TV and phone) on one PC.
  The QR codes decode with an independent decoder (OpenCV).
- **Not tested: real Android TV, real phone sensors, real Wi-Fi.** The iPhone controller was deployed and joins a TV, but its sensor directions are not measured (Manual test 13). The first on-device run must check the
  items marked *unverified* in [docs/RISKS.md](docs/RISKS.md), mainly the sensor signs and the key mapping.
- The QR scanner plugin compiled only against stubs (the real ML Kit and Godot libraries were not reachable
  from the build sandbox). It needs Google Play services on the phone. Test it first: `docs/MANUAL_TESTS.md`, test 2.
