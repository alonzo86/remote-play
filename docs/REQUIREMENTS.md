# Requirements

Project: Sababi. A couch game for Android TV.
A phone is the motion controller (Wii-remote style).

Style: this text uses ASD-STE100 Simplified Technical English.
Each requirement has an ID. Use the ID in code comments and tests.

## 1. Goal

- REQ-G1: The app must give a good phone-as-controller feel: low delay and stable tilt input.
- REQ-G2: The app is a collection of minigames. Each game has its own requirements file in `docs/games/`.

## 2. Platform and tools

- REQ-P1: Use Godot 4.7 (4.x) with GDScript only.
- REQ-P2: Use one project with two export targets: `tv` (Android TV), `controller` (Android phone) and `controller-ios` (iPhone).
- REQ-P3: The role is chosen by the feature tag `tv` or `controller`.
- REQ-P4: On desktop, the argument `-- --role=tv` or `-- --role=controller` replaces the feature tag.
- REQ-P5: Do not use servers, accounts, subscriptions, analytics, or paid services. Use the LAN only. A player profile (FD-22) is a file on the phone; it is not an account and nothing leaves the LAN.
- REQ-P6: Menus and games are built in code from shapes, with the 8-bit arcade style (`docs/TV_FLOW.md`, FD-18). Allowed files: the pixel font Press Start 2P and the Hebrew fallback font Sababi Pixel Hebrew (`assets/fonts`, each with its license file), the game tile screenshots (`assets/tiles`), the medal pictures (`assets/medals`), the player avatar sheet (`assets/avatars`), the licence text of the Android libraries (`assets/licenses`), the logo (`assets/logo`), and the app icons. No other image, sound or model files without a decision in `docs/TV_FLOW.md`.

## 3. Architecture

- REQ-A1: The TV runs a WebSocket server (`TCPServer` + `WebSocketPeer`) on fixed TCP port 47801.
- REQ-A2: **Removed (issue #52, FD-28).** The TV sends nothing on the network by itself: no UDP beacon, no port 47800.
- REQ-A3: The TV shows a QR code and a 4-letter room code on screen. The room code is the code of the LAN address of the TV (REQ-FL-84).
- REQ-A4: The phone joins in one of two ways: it scans the QR code (Android; a phone with no scanner, and an iPhone, has no scan button and no paste button), or the player types the room code of the TV in a field (all phones, also an iPhone; REQ-FL-83). There is no list of discovered rooms, no Refresh button and no search of the network.
- REQ-A5: The TV accepts up to 4 phones at the same time.
- REQ-A6: Input handling and networking are in separate scripts from game logic.
- REQ-A7: To add a minigame, a developer adds one folder and extends `minigame.gd`.
- REQ-A8: `net/` and `input/` scripts must not refer to `game/` scripts.
- REQ-A9: Games are listed in `scripts/game/registry.gd`. The Games screen is built from it (title, description, tile, player range). All games are 2D and extend `minigame.gd`. There is no 3D base class (removed 2026-10-31, issue #300, decision of the owner).
- REQ-A10: Each game has a requirements file in `docs/games/`. All games also follow `docs/GAME_REQUIREMENTS.md`.

## 4. Protocol

- REQ-N1: The phone sends sensor data at about 60 Hz in a packed binary frame (36 bytes).
- REQ-N2: Each sensor packet has a phone timestamp and a sequence number.
- REQ-N3: Control messages are JSON text frames.
- REQ-N4: The TV and phone measure RTT and clock offset with `ping` / `pong` once each second.
- REQ-N5: A phone that loses its connection keeps its slot for 5 seconds (30 before issue #44), and for 5 minutes while the game is paused for it.
- REQ-N6: The phone reconnects automatically with a saved token (backoff 0.5 s, 1 s, 2 s, then every 2 s).
- REQ-N7: Full message reference: `docs/PROTOCOL.md`.
- REQ-N8: `hello` and `welcome` carry an optional profile (`pid`, `av`, and the name); a `profile` message changes it in a menu. The TV checks every field. The new fields are optional, so adding them did not change the protocol `VERSION` (FD-22); the current `VERSION` is in `scripts/core/protocol.gd` (5) and the rules are in `docs/PROTOCOL.md`.
- REQ-N9: **Removed (issue #52, FD-28).** There is no join PIN (`hello.pin`, `bad_pin` and `pin_locked` are gone). The protocol `VERSION` became 4 with it (now 5, `scripts/core/protocol.gd`). See `docs/PROTOCOL.md`, "Room code".
- REQ-N10: Any device on the Wi-Fi can send a frame to the TV port, and the TV and a phone can be different builds. A handler reads the fields of a JSON frame only with `Protocol.num`, `whole`, `text` and `flag`, which give the default for a value of another type (an Array, an object, a number for a text). A frame with a field of the wrong type never raises a script error and never changes the state of a player (issue #308; `tests/net_malformed.gd`).

## 5. Phone controller

- REQ-C1: Read `Input.get_gyroscope()` and `Input.get_accelerometer()`.
- REQ-C2: Send touch and button events with the sensor packet.
- REQ-C3: Show a big "Recenter" button that resets the yaw (fixes gyro drift).
- REQ-C4: Show connection status and a latency readout.
- REQ-C5: Keep the screen awake.
- REQ-C6: Lock the screen to portrait.
- REQ-C7: The phone keeps up to 8 player profiles (ID, name, avatar) in a file and sends the active one to the TV (FD-22, REQ-FL-69 to 75).
- REQ-C8: A profile is saved at once after each change, with a backup copy of the file.
- REQ-C9: The player of a phone is chosen on the Connect screen before the phone joins, and cannot be changed while the phone is joined (the player taps DISCONNECT and chooses again, REQ-FL-71), so a profile never changes during a round.
- REQ-C10: A profile can be copied to another phone with a QR code or a text (`WP1.`); the copy has no server (FD-22, REQ-FL-76 to 78).
- REQ-C11: The phone keeps the personal best of each profile for each game setting and saves it at once (FD-22, REQ-GM-98 to 101).
- REQ-C12: The settings file (`user://settings.cfg`) and the last-TV file (`user://controller.cfg`) are checked when they are read and when they are written (issue #309, `scripts/core/config_io.gd`). A write that fails is put in the log as a warning and the values stay in memory. A value of the wrong type in a file (a damaged or hand-edited file) is not used: the default stays (for `language` it is the first-start choice, REQ-FL-60). A volume is cut to 0 to 10, a language is `en`, `he` or empty, and the saved port is 1 to 65535, else 47801. Test: `tests/config_files.gd`.

## 6. TV application

- REQ-T1: The games are the fifteen games of the registry (`scripts/game/registry.gd`): Treasure Maze, Car Race, Paint Grab, Sumo Bumpers, Banana Party, Star Shield, Pin Pals, Tennis, Mini Golf, Sheep Herding, Whack-a-Mole, Tower Builder, Freeze Dance, Air Hockey and Bumper Cars. Each has its requirements in `docs/games/<id>.md`. In the maze each phone tilts a ball through a maze. The first ball to reach the exit wins.
- REQ-T3: All menus, the restart function, and the back function work with the TV remote D-pad.
- REQ-T4: A debug overlay shows, for each player: latency, packet rate, sensor age, packet loss, and raw sensor values, and the last swing (power, direction, age of the hit) that the swing detector found (`scripts/input/swing_detector.gd`).
- REQ-T5: The game pauses when a phone disconnects, also when the phone is only silent (no Wi-Fi, a phone call). A card tells which player (by the profile name, or "2P" for a guest), and the player chooses: resume without it (while another phone is connected), resume when it is back, or end the game (REQ-GM-30, 30a). The game never goes on by itself.
- REQ-T6: The TV app follows the flow in `docs/TV_FLOW.md`: logo, Connect controllers, Games, and a game. Settings and the Players modal open from the Games screen.

## 7. Android export

- REQ-E1: The TV app has the `LEANBACK_LAUNCHER` category and a banner icon.
- REQ-E2: The TV and phone apps use different package IDs so both can be installed on one device.
- REQ-E3: Document all export steps in `docs/EXPORT.md` and `README.md`.
- REQ-E4: Document how to test on a real Android TV or streaming box.

## 8. Deliverables

1. Project structure and `README.md` with build and export steps.
2. The debug overlay (REQ-T4).
3. A list of open risks and mitigations: `docs/RISKS.md`.

## 9. Decisions (approved by the user)

| ID | Decision |
|----|----------|
| D1 | Join by the room code or the QR code (FD-28; it was UDP discovery plus room code). The TV shows a QR code that holds `ws://IP:PORT/ROOM` and the room code, which is its address in 4 letters. The phone scans the QR code with a small Android plugin (Google code scanner) or types the code. A phone without the plugin (also a PC) has no scan button: it types the code, or uses `--join=127.0.0.1`. |
| D2 | All data goes over WebSocket (TCP) in v1. The overlay shows sensor age so the user can see TCP delay. |
| D3 | The TV does sensor fusion. The phone sends raw values. |
| D4 | Godot 4.7 stable. |
| D5 | Role by feature tag, or by command-line argument on desktop. |

## 10. Known limits

- The code was checked with Godot headless (script parse and protocol tests). It was not tested on a real TV or phone.
- The QR scanner plugin was compiled only against stubs. It needs Google Play services on the phone.
