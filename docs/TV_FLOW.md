# TV app flow

Status: **agreed, not built yet.** This file holds the decisions (FD-n) and the requirements (REQ-FL-n)
for the redesign of the TV app. The code change comes in the next pull request.
Style: ASD-STE100 Simplified Technical English, like the other requirements files.

## 1. Flow

```
OS splash ──> Logo screen ──> Connect controllers ──> Games ──> (Variant step) ──> Game
 (Android)     (in game)        QR, code, 4 slots      tiles      for example        │
                                      ▲                   │       marble tracks      │
                                      └──── Back ─────────┘◄──── Back / Menu ────────┘
                                      │
                                   Back: quit confirm
Settings: a gear icon on the Games screen opens the Settings screen. The players badge opens the Players modal.
```

## 2. Decisions

| ID | Decision | Date |
|----|----------|------|
| FD-1 | Splash: the Android OS splash first (static, set in project settings), then an animated logo screen of the game for about 2 to 3 seconds. OK skips it. | 2026-10-07 |
| FD-2 | The Connect screen ends when the host presses OK on the TV remote and at least 1 phone is joined. No "Ready" message from the phones. | 2026-10-07 |
| FD-3 | Game tiles use a screenshot of each game. The screenshots are PNG files in the repository, made by a script. A tile without a file shows a colored placeholder. | 2026-10-07 |
| FD-4 | Settings (debug overlay, invert tilt, invert yaw) are on a separate Settings screen. A gear icon on the Games screen opens it. Quit is not on the Games grid. | 2026-10-07 |
| FD-5 | Phones can join and leave at any time, also after the Connect screen. Games check the player count. | 2026-10-07 |
| FD-6 | Back goes one step back. Games -> Connect (the players stay) -> quit confirmation. The Back key skips the logo screen. | 2026-10-07 |
| FD-7 | Games grid: 16:9 tiles, 3 per row, D-pad focus shown by an outline (tiles do not change size). The title and the player range are under every tile. The description of the focused game is in a fixed info bar under the grid. The grid scrolls down when there are more games. | 2026-10-07 |
| FD-8 | The phone app shows the TV phase (waiting for the host, choose a game, game pad). Its connect screen stays as it is. | 2026-10-07 |
| FD-10 | Only players in the same room and on the same Wi-Fi or LAN network as the TV can play. There is no online play and no relay server. | 2026-10-07 |
| FD-11 | The Connect screen does not show the WebSocket address. The Continue button is in a footer bar, aligned to the right edge of the content. | 2026-10-07 |
| FD-12 | The Games screen shows a players badge with the number of players, not the room code. OK on the badge opens a modal to manage the players (see the requirements). | 2026-10-07 |
| FD-9 | Art is no longer limited to flat shapes (changes REQ-P6): the logo and the tile screenshots are image files. Menus and games stay in code. | 2026-10-07 |

## 3. Requirements

### Splash and logo screen
- REQ-FL-1: The app sets the Android splash (background color and icon) in the project settings.
- REQ-FL-2: After the OS splash, the TV shows a logo screen with an animation. It lasts 2 to 3 seconds.
- REQ-FL-3: OK, or a tap on a touch screen, skips the logo screen. Back does not show it (FD-6).
- REQ-FL-4: The logo screen starts the network services (server and beacon) while it shows, so the Connect screen is ready at once.

### Connect screen
- REQ-FL-5: The screen has two columns of equal height. Left: a card with the QR code and the 4-letter room code below it. Right: the title, one line of help text, and 4 player slots with color and state (free, joined, lost). The screen does not show the WebSocket address (FD-11).
- REQ-FL-6: A footer bar at the bottom shows a "Continue" button at the right edge of the content area, inside the safe area (60 px margins, RISKS D5). The button is disabled while no phone has joined, and the footer shows why on its left side.
- REQ-FL-7: The focus starts on "Continue". OK on "Continue" opens the Games screen.
- REQ-FL-8: A phone that joins or leaves updates the slots at once. A joined phone shows its name or slot color.
- REQ-FL-9: A phone that is already joined stays joined when the host goes Back from the Games screen to this screen.
- REQ-FL-10: Back on this screen opens a quit confirmation (Quit, Stay). The default focus is "Stay".

### Games screen
- REQ-FL-11: The screen shows one tile for each game in `registry.gd`. A tile has a 16:9 screenshot and the game title (FD-7).
- REQ-FL-12: The grid has 3 tiles in a row. The D-pad moves the focus in all 4 directions. The grid scrolls to keep the focused tile in view.
- REQ-FL-13: Every tile has the same layout: the screenshot, the title, and the player range (for example "1-4 players") under it. The focused tile has an outline. The one-line description of the focused game is in an info bar under the grid, aligned to the left edge of the grid.
- REQ-FL-14: A game that does not accept the current player count has a dimmed tile and a reason ("Needs 2 players"). OK on it does nothing except show the reason (uses `Registry.accepts()`).
- REQ-FL-15: A players badge in the top right shows the number of joined players (for example "2 players"). It does not show the room code (FD-12). The badge is a focus target. OK on it opens the Players modal (REQ-FL-32).
- REQ-FL-16: A gear icon next to the badge is the last focus target. OK on it opens the Settings screen (FD-4).
- REQ-FL-17: A game with variants asks for the variant after OK on the tile (for example the marble race track). Back returns to the grid with the same tile in focus.
- REQ-FL-18: Back on this screen goes to the Connect screen (FD-6).
- REQ-FL-19: The registry entry of a game has a `description` and a `tile` field (path of the screenshot). Both are required for a new game.

### Players modal
- REQ-FL-32: The modal shows the 4 slots with color and state, a QR code with the room code for new phones, and a Close button. It opens on the Games screen (FD-12).
- REQ-FL-33: Each joined or lost slot has a "Remove" action. Remove disconnects the phone and frees the slot. The removed phone returns to its connect screen and its token is no longer valid. The slot stays free until a phone actively connects to it: the removed player or another player, by QR code, room code, TV list or TV IP. The removed phone must not reconnect by itself.
- REQ-FL-34: The modal updates live when a phone joins or leaves. The focus starts on Close. Back closes the modal.
- REQ-FL-35: Remove needs a new message to the phone. Change `docs/PROTOCOL.md` in the same commit (use the `change-protocol` skill).
- REQ-FL-36: The player count on the badge and the tile dimming (REQ-FL-14) update when the modal changes the players.

### Tile screenshots
- REQ-FL-20: A tool script makes the screenshot of each game and saves it as `assets/tiles/<id>.png`, 640x360 pixels.
- REQ-FL-21: The `add-minigame` skill and `docs/games/TEMPLATE.md` include the step to make the screenshot.
- REQ-FL-22: A test fails when a registry game has no tile file or no description.

### Settings screen
- REQ-FL-23: The screen has the debug overlay switch, the invert tilt switch, and the invert yaw switch. The values are saved (REQ already in `app.gd`).
- REQ-FL-24: Back returns to the Games screen with the gear in focus.

### Network scope
- REQ-FL-31: Only phones on the same local network as the TV can join (FD-10). The app uses no internet service for play (REQ-P5). The Connect screen help text tells the players to be in the same room and on the same Wi-Fi.

### Players that join and leave
- REQ-FL-25: A phone can join on any screen of the TV, also during a game. A new phone waits for the next round (it gets the slot but does not take part).
- REQ-FL-26: A phone that leaves or is lost during a game uses the existing pause and reconnect rules (REQ-T5, REQ-N5).
- REQ-FL-27: When the player count changes on the Games screen, the tiles update at once (REQ-FL-14).

### Phone app
- REQ-FL-28: The phone shows the TV phase after it has joined: "Waiting for the host" (logo and Connect screen), "Choose a game on the TV" (Games and Settings screens), and the game pad (playing and paused).
- REQ-FL-29: The TV sends the phase with the existing `phase` message. A new value is needed for the Connect and Games screens. Change `docs/PROTOCOL.md` in the same commit (use the `change-protocol` skill).

### Android export
- REQ-FL-30: The TV app still starts in the same way on a TV (`LEANBACK_LAUNCHER`, banner). The main scene becomes the logo screen.

## 4. Changes to other files in the next pull request

- `docs/REQUIREMENTS.md`: change REQ-P6 (FD-9), REQ-A9 and REQ-T3 to point to this file. Replace "main menu" with the new screens.
- `docs/GAME_REQUIREMENTS.md`: the menu rules for the title, the description and the tile.
- `docs/DEVICE_TEST.md`: new tests for the flow (splash, connect, late join, Back).
- `README.md`: project structure and controls.
- `scripts/ui/tv_menu.gd` is split into the logo, connect, games and settings screens.

## 5. Open questions

- Logo and splash art: who makes the logo image? Until it exists, the logo screen draws the text "REMOTE PLAY" in code.
- The screenshot size (640x360) and the tile count per row may change after a check on a real TV.
