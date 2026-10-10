# Requirements

Project: Wobble. A couch game for Android TV.
A phone is the motion controller (Wii-remote style).

Style: this text uses ASD-STE100 Simplified Technical English.
Each requirement has an ID. Use the ID in code comments and tests.

## 1. Goal

- REQ-G1: The app must give a good phone-as-controller feel: low delay and stable tilt input.
- REQ-G2: The app is a collection of minigames. Each game has its own requirements file in `docs/games/`.

## 2. Platform and tools

- REQ-P1: Use Godot 4.7 (4.x) with GDScript only.
- REQ-P2: Use one project with two export targets: `tv` (Android TV) and `controller` (Android phone).
- REQ-P3: The role is chosen by the feature tag `tv` or `controller`.
- REQ-P4: On desktop, the argument `-- --role=tv` or `-- --role=controller` replaces the feature tag.
- REQ-P5: Do not use servers, accounts, subscriptions, analytics, or paid services. Use the LAN only.
- REQ-P6: Menus and games are built in code from shapes, with the 8-bit arcade style (`docs/TV_FLOW.md`, FD-18). Allowed files: the pixel font Press Start 2P and the Hebrew fallback font Wobble Pixel Hebrew (`assets/fonts`, each with its license file), the game tile screenshots (`assets/tiles`), the logo (`assets/logo`), and the app icons. No other image, sound or model files without a decision in `docs/TV_FLOW.md`.

## 3. Architecture

- REQ-A1: The TV runs a WebSocket server (`TCPServer` + `WebSocketPeer`) on fixed TCP port 47801.
- REQ-A2: The TV sends a UDP broadcast beacon on port 47800 every 1 second.
- REQ-A3: The TV shows a QR code and a 4-letter room code on screen.
- REQ-A4: The phone scans the QR code, or finds the TV with the UDP beacon, or picks the TV from the list of discovered TVs (with a Refresh button). The "Scan QR code" button is white. A TV in the list is a green button that shows only "<room code> x/y" (players joined and maximum); the Refresh button is yellow, not the same color. There is no typed room code or IP: if neither works, there is no TV to connect to.
- REQ-A5: The TV accepts up to 4 phones at the same time.
- REQ-A6: Input handling and networking are in separate scripts from game logic.
- REQ-A7: To add a minigame, a developer adds one folder and extends `minigame.gd`.
- REQ-A8: `net/` and `input/` scripts must not refer to `game/` scripts.
- REQ-A9: Games are listed in `scripts/game/registry.gd`. The Games screen is built from it (title, description, tile, player range). 3D games extend `minigame_3d.gd`.
- REQ-A10: Each game has a requirements file in `docs/games/`. All games also follow `docs/GAME_REQUIREMENTS.md`.

## 4. Protocol

- REQ-N1: The phone sends sensor data at about 60 Hz in a packed binary frame (36 bytes).
- REQ-N2: Each sensor packet has a phone timestamp and a sequence number.
- REQ-N3: Control messages are JSON text frames.
- REQ-N4: The TV and phone measure RTT and clock offset with `ping` / `pong` once each second.
- REQ-N5: A phone that loses its connection keeps its slot for 30 seconds, and for 5 minutes while the game is paused for it.
- REQ-N6: The phone reconnects automatically with a saved token (backoff 0.5 s, 1 s, 2 s, then every 2 s).
- REQ-N7: Full message reference: `docs/PROTOCOL.md`.

## 5. Phone controller

- REQ-C1: Read `Input.get_gyroscope()` and `Input.get_accelerometer()`.
- REQ-C2: Send touch and button events with the sensor packet.
- REQ-C3: Show a big "Recenter" button that resets the yaw (fixes gyro drift).
- REQ-C4: Show connection status and a latency readout.
- REQ-C5: Keep the screen awake.
- REQ-C6: Lock the screen to portrait.

## 6. TV application

- REQ-T1: The games are the tilt maze and the marble race. In the maze each phone tilts a ball through a maze. The first ball to reach the exit wins.
- REQ-T3: All menus, the restart function, and the back function work with the TV remote D-pad.
- REQ-T6: The TV app follows the flow in `docs/TV_FLOW.md`: logo, Connect controllers, Games, and a game. Settings and the Players modal open from the Games screen.
- REQ-T4: A debug overlay shows, for each player: latency, packet rate, sensor age, packet loss, and raw sensor values.
- REQ-T5: The game pauses when a phone disconnects, also when the phone is only silent (no Wi-Fi, a phone call). A card tells which phone, and the player chooses: resume without it (while another phone is connected), resume when it is back, or end the game (REQ-GM-30, 30a). The game never goes on by itself.

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
| D1 | Join by UDP discovery plus room code. The TV shows a QR code that holds `ws://IP:PORT/ROOM`. The phone scans it with a small Android plugin (Google code scanner). On a PC the phone window uses a "Paste TV link" button. |
| D2 | All data goes over WebSocket (TCP) in v1. The overlay shows sensor age so the user can see TCP delay. |
| D3 | The TV does sensor fusion. The phone sends raw values. |
| D4 | Godot 4.7 stable. |
| D5 | Role by feature tag, or by command-line argument on desktop. |

## 10. Known limits

- The code was checked with Godot headless (script parse and protocol tests). It was not tested on a real TV or phone.
- The QR scanner plugin was compiled only against stubs. It needs Google Play services on the phone.
