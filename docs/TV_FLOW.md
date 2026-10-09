# TV app flow

Status: **built** (the redesign pull request). Chosen visual style: Party Pop (FD-13). This file holds the decisions (FD-n)
and the requirements (REQ-FL-n) of the TV app flow. Open items: the logo image (the owner makes it, FD-15) and the Android
splash image, until then the app icon is used (REQ-FL-51).
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
| FD-4 | Settings (debug overlay, invert tilt) are on a separate Settings screen. A gear icon on the Games screen opens it. Quit is not on the Games grid. | 2026-10-07 |
| FD-5 | Phones can join and leave at any time, also after the Connect screen. Games check the player count. | 2026-10-07 |
| FD-6 | Back goes one step back. Games -> Connect (the players stay) -> quit confirmation. The Back key skips the logo screen. | 2026-10-07 |
| FD-7 | Games grid: 16:9 tiles (420 px wide), rows of 3, D-pad focus. The focused tile grows to the right and shows the description of the game (a Netflix menu); the tiles after it move aside. The title and the player range are under every tile. The grid scrolls down when there are more games. There is no info bar. (Changed 2026-10-08: tiles used to keep their size and a fixed info bar showed the description.) | 2026-10-07 |
| FD-8 | The phone app shows the TV phase (waiting for the host, choose a game, game pad). Its connect screen stays as it is. | 2026-10-07 |
| FD-10 | Only players in the same room and on the same Wi-Fi or LAN network as the TV can play. There is no online play and no relay server. | 2026-10-07 |
| FD-11 | The Connect screen does not show the WebSocket address. (The Continue button of this decision was removed, see FD-17.) | 2026-10-07 |
| FD-12 | The Games screen shows a players badge with the number of players, not the room code. OK on the badge opens a modal to manage the players (see the requirements). | 2026-10-07 |
| FD-9 | Art is no longer limited to flat shapes (changes REQ-P6): the logo and the tile screenshots are image files. Menus and games stay in code. | 2026-10-07 |
| FD-13 | Visual style: **Party Pop**. Chunky, saturated, sticker-like. Thick dark outlines, hard offset shadows, rounded shapes, bright player color tokens. The TV and the phone use the same style. Rejected: Arcade Neon (heavy glow, hard to read from a sofa) and Sticker Book (needs paper image assets). | 2026-10-07 |
| FD-14 | Games share a visual language, not one look. Tier 1 (required): the game shell (pause menu, countdown, results, HUD), fonts, player colors. Tier 2 (required, trial rules): a toy-like world (rounded shapes, flat saturated colors, dark outline on key objects). Tier 3 (free): setting, background, camera, lighting mood. The exact tier 2 values are in `docs/GAME_REQUIREMENTS.md` (REQ-GM-47a to 47h). A trial on the marble race checks them. | 2026-10-07 |
| FD-15 | The owner makes the logo image. The developer sets the exact tier 2 values. | 2026-10-07 |
| FD-16 | The pointer test and the 3D demo were only for the first test of the prototype. They are removed: code, requirements files, tiles and tests. The marble race is the example of a 3D game. The pointer input of the phone (`PlayerInput.pointer()`, the yaw fusion) stays as an input for a later game, but it has no Settings switch now. | 2026-10-07 |
| FD-17 | The Connect screen has no Continue button and no player count. A line "Press OK to continue" shows when at least one phone has joined, and OK opens the Games screen. (Found in the first run on an Android TV: the button was the only focus target, so it was redundant, and the count repeated the slot list.) | 2026-10-09 |

## 3. Requirements

### Splash and logo screen
- REQ-FL-50: Logo file: `assets/logo/logo.png`, PNG with a transparent background, 1600x600 px, the logo centered with at least 80 px of empty space on every side. It must read well on the purple background `#3d1a9e` (FD-13). The logo screen shows it at about 60% of the screen width. If the file is missing, the screen draws the text "REMOTE PLAY" with the title font.
- REQ-FL-51: The Android splash (REQ-FL-1) uses the purple `#3d1a9e` as the background color. It uses the app icon, or a square version of the logo (`assets/logo/splash.png`, 432x432 px, transparent) when the owner provides one.
- REQ-FL-1: The app sets the Android splash (background color and icon) in the project settings.
- REQ-FL-2: After the OS splash, the TV shows a logo screen with an animation. It lasts 2 to 3 seconds.
- REQ-FL-3: OK, or a tap on a touch screen, skips the logo screen. Back does not show it (FD-6).
- REQ-FL-4: The logo screen starts the network services (server and beacon) while it shows, so the Connect screen is ready at once.

### Connect screen
- REQ-FL-5: The screen has two columns of equal height. Left: a card with the QR code and the 4-letter room code below it. Right: the title, one line of help text, and 4 player slots with color and state (free, joined, lost). The screen does not show the WebSocket address (FD-11).
- REQ-FL-6: The screen has no button and no player count (FD-17). A line at the bottom, centered, inside the safe area (60 px margins, RISKS D5), says "Press OK to continue" (yellow, 48 px) as soon as at least one phone has joined. Before that the line is empty, except when the TV has no network address: then it says so in `UiTheme.BAD_TEXT`. The slot list shows who has joined.
- REQ-FL-7: OK opens the Games screen when at least one phone has joined. OK does nothing before that, and nothing while the quit question is open (REQ-FL-10).
- REQ-FL-8: A phone that joins or leaves updates the slots at once. A joined phone shows its name or slot color. The state of a slot is a chip (a pill with a dark outline and dark text): green "Ready!", red "Lost". An empty slot shows "waiting" in plain muted text.
- REQ-FL-9: A phone that is already joined stays joined when the host goes Back from the Games screen to this screen.
- REQ-FL-10: Back on this screen opens a quit confirmation (Quit, Stay). The default focus is "Stay".

### Games screen
- REQ-FL-11: The screen shows one tile for each game in `registry.gd`. A tile has a 16:9 screenshot and the game title (FD-7).
- REQ-FL-12: The tiles are in rows of 3. The content is a column of 1720 px (`tv_games.gd` `CONTENT_W`), centered on any screen width. A tile is 420 px wide (the 16:9 screenshot is 420x236 px). The focused tile is 780 px wide: the screenshot and a panel with the description (`GameTile.wide_width()`), so 2 normal tiles and 1 wide tile fit in a row. It grows in 180 ms and the tiles after it move to the right. The D-pad moves the focus in all 4 directions. The grid scrolls to keep the focused tile in view.
- REQ-FL-13: Every tile has the same layout: the screenshot, the title, and the player range (for example "1-4 players") under it. The focused tile has no yellow outline (the same dark outline as the others). It is wide and its title is yellow: the description of the game is in the panel on the right of the screenshot. A tile that does not accept the players shows the reason in yellow under its title (REQ-FL-14).
- REQ-FL-14: A game that does not accept the current player count has a dimmed tile and a reason ("Needs 2 players"). OK on it does nothing except show the reason (uses `Registry.accepts()`).
- REQ-FL-15: A players badge in the top right shows the number of joined players (for example "2 players"). It does not show the room code (FD-12). The badge is a focus target. OK on it opens the Players modal (REQ-FL-32).
- REQ-FL-16: A gear icon next to the badge is the last focus target. OK on it opens the Settings screen (FD-4).
- REQ-FL-17: A game with a settings view (REQ-GM-90) opens it after OK on the tile: a centered view with Difficulty, Start and Back at the bottom. Back returns to the grid with the same tile in focus. Every game has this view (the marble race adds its track list). Back returns to the grid with the same tile in focus.
- REQ-FL-18: Back on this screen goes to the Connect screen (FD-6).
- REQ-FL-19: The registry entry of a game has a `description` and a `tile` field (path of the screenshot). Both are required for a new game.

### Players modal
- REQ-FL-32: The modal shows the 4 slots with color and state, a QR code with the room code for new phones, and a Close button. It opens on the Games screen (FD-12).
- REQ-FL-33: Each joined or lost slot has a "Remove" action. It is a quiet button (white, dark red text) so that it does not out-shout Close. Remove disconnects the phone and frees the slot. The removed phone returns to its connect screen and its token is no longer valid. The slot stays free until a phone actively connects to it: the removed player or another player, by QR code, room code, TV list or TV IP. The removed phone must not reconnect by itself.
- REQ-FL-34: The modal updates live when a phone joins or leaves. The focus starts on Close. Back closes the modal.
- REQ-FL-35: Remove needs a new message to the phone. Change `docs/PROTOCOL.md` in the same commit (use the `change-protocol` skill).
- REQ-FL-36: The player count on the badge and the tile dimming (REQ-FL-14) update when the modal changes the players.

### Visual style (Party Pop, FD-13)
- REQ-FL-37: All screens use one palette, kept in `UiTheme` (`scripts/ui/ui_theme.gd`): background purple `#3d1a9e` (darker `#2c1180` for dark panels), card white `#ffffff`, text on card `#24104f`, outline and shadow `#1a0b45`, accent yellow `#ffd23f`, button colors yellow (`ACCENT`), green (`OK` `#57cc99`) and red (`DANGER` `#b3122f`), purple row button `#7152e8` (`UiTheme.BUTTON`), focus border black (`FOCUS_BORDER`), disabled gray `#c4c0cf` with edge `#7d7890` and text `#4d4863`, state chips (`CHIP_OK`, `CHIP_BAD` and their dark texts), muted text `#463678` (`CARD_MUTED`), error text on purple `#ff8296` (`BAD_TEXT`), room code pink `#ff3d8b`, confetti pink `#ff5ea8`, cyan `#3ddcff` and yellow. The player colors stay as they are in `Protocol`.
- REQ-FL-38: Cards, slots, badges and buttons have a thick dark outline (6 px at 1080p, `UiTheme.OUTLINE_W`) and a hard shadow offset down and right, with no blur. Corners are rounded. Pills and the gear are fully round.
- REQ-FL-39: Titles use the display font Lilita One. Other text uses Fredoka (medium and semibold). Both fonts are free (SIL OFL) TTF files in `assets/fonts/`, with their license files. The default Godot font is the fallback.
- REQ-FL-40: Text on the TV is at least 28 px high at 1080p for titles and game names, and at least 28 px for every other text, also help text (read from a sofa; the design review found 22 px too small). Text that is part of a picture (the logo file) and the numbers on a ball are not counted. Text on the purple background has a contrast ratio of at least 4.5:1. Text on a white card is dark (`UiTheme.CARD_TEXT`), also for the chips in the games. Text on an empty slot ("waiting") and the OFF state use `UiTheme.CARD_MUTED`, which has a contrast of 4.5:1 or more on the dimmed card.
- REQ-FL-41: The focused button has a thick black border (`UiTheme.FOCUS_BORDER`, 10 px) and lifts: its shadow gets longer (`UiTheme.button_style`). Its fill, its size and the layout stay the same. A focused tile is the exception: it grows (REQ-FL-12) and has a yellow title, with no border change. A quiet Back button turns light when focused, so that the black border shows. The text of a focused button is dark (white on red).
- REQ-FL-41a: Buttons have three colors, all with a hard shadow: yellow (`ACCENT`, the default), green (`OK`, `PrimaryButton`, the main action of a screen) and red (`DANGER`, `DangerButton`, white text). Text on yellow and green is dark (`CARD_TEXT`). Purple rows (settings rows, the players badge, the gear) use `RowButton`. One white button (`LightButton`, dark text) is for the action that must stand out among colored buttons: "Scan QR code" on the phone connect screen (not shown on an iPhone or iPad, REQ-FL-58). A pressed button sinks: the shadow goes and the box moves onto it. A disabled button is flat and gray (`UiTheme.DISABLED`), opaque, never see-through, and its text has a contrast of 4.5:1 or more. A click or a tap leaves no focus on the button (the D-pad does focus). "Back" on a choice screen is a quiet dark button (`SecondaryButton`), apart from the options. Buttons are only as wide as their text needs. Screen margins are as small as the 60 px safe area allows. A color never carries the meaning alone: the label says it.
- REQ-FL-53: A destructive button (`DangerButton`) is dark red `#b3122f` with white text (6.9:1) and a "✕" before the label. It is used in confirmations only (Quit) and beside Remove. The default focus of a confirmation is the safe, main button (Stay, green). Focus follows REQ-FL-41. The text on every button state has a contrast of 4.5:1 or more (a test checks it).
- REQ-FL-42: Motion: a focused tile grows to the right in about 180 ms and the description fades in; it shrinks again when the focus leaves. A button sinks when it is pressed. A slot pops in with a small overshoot when a phone joins (no confetti; coin sound optional). The logo still ends with one confetti burst. Screen changes use a short slide or fade (up to 250 ms).
- REQ-FL-43: Motion stops while a game is paused or a phone is lost, and no motion blocks input.
- REQ-FL-44: The style uses only styled boxes, tweens, particles and fonts. It uses no shader. It must run at 60 fps on the weakest supported TV box (check in `docs/MANUAL_TESTS.md`).
- REQ-FL-45: The background is plain purple, with no dots or bubbles. The confetti of the logo is drawn in code. It is not an image file.
- REQ-FL-46: The phone app uses the same palette, fonts and card style (REQ-FL-28).
- REQ-FL-52: Phone buttons follow REQ-FL-41a and REQ-FL-53. On the pad, A is green and B is red (RECENTER is yellow, Leave is yellow). A pressed button sinks. The player color is only in the badge (the number dot) at the top, never a button fill. A number or letter on a color uses `UiTheme.text_on()` (white or dark, whichever has more contrast: dark on orange and teal, white on red and blue). Scan on the connect screen is white (`LightButton`); the discovered TVs below it are green and Refresh is yellow. Leave needs two taps: the first tap turns it red ("Tap again to leave") for 3 s. Error and offline text on the purple background uses `UiTheme.BAD_TEXT` (4.5:1 or more), not `BAD`.
- REQ-FL-54: The UI is always English and always left to right, whatever the language or the region of the device (a TV set to Hebrew must not mirror the screens). Until translations are added, `App` sets the locale "en" and the layout direction of the root window to left to right at start, on the TV and on the phone. The project setting `internationalization/rendering/root_node_layout_direction` is left to right too.
- REQ-FL-55: The Back key of the remote and of the phone goes back one step in the app and never quits the app by itself. The project setting `application/config/quit_on_go_back` is false. The app quits only through the quit question of the Connect screen (REQ-FL-10).
- REQ-FL-56: A tile whose image is missing or cannot be loaded shows a rounded placeholder (a color from the id) and writes a warning to the log (`adb logcat -s godot`). It never shows an empty box without a reason.
- REQ-FL-57: The corners of the screenshot of a tile are rounded in the image itself (`GameTile.rounded()`, radius 20 px on the screen), once when the tile is made. The tile does not use `clip_children`. (Found in the first run on an Android 10 TV: the screenshots did not show. The cause is not confirmed: this change removes the clipping and adds the warning of REQ-FL-56. See Test 8b item 2 in `docs/MANUAL_TESTS.md`.)
- REQ-FL-58: On an iPhone or iPad (`OS.get_name() == "iOS"`) the phone connect screen has no "Scan QR code" and no "Paste TV link" button: it shows only the list of discovered TVs and Refresh (there is no scanner plugin on iOS). Android and desktop (also a Mac) keep the button. (Device: Manual test 13.)
- REQ-FL-59: On an iPhone or iPad, when the list of discovered TVs is empty and the screen is not searching, a second line under "No TVs found" says: "No TV? In Settings, allow Local Network for this app, and use the same Wi-Fi as the TV." (iOS asks for the Local Network permission once; without it the beacon is not received.) Other platforms show only "No TVs found". (Device: Manual test 13.)

### Game shell and trial (FD-14)
- REQ-FL-47: The next pull request restyles the marble race as a trial of the tier 2 rules (REQ-GM-47). The result is judged with a screenshot of the game next to the Games screen (REQ-GM-49). The trial checks the tier 2 values (REQ-GM-47a to 47h) and they are corrected in `docs/GAME_REQUIREMENTS.md` if they are wrong. If the trial shows that games need more freedom, the rules are made looser before any other game is changed.
- REQ-FL-48: The game shell (REQ-GM-45) is built in the same pull request as the menus. A game must not show an old style pause menu, countdown or result screen next to the new menus.
- REQ-FL-49: The other games get the shell in the same pull request. Their tier 2 restyle follows in a later pull request. (Done for the maze. The pointer test and the 3D demo were removed, see FD-16.)

### Tile screenshots
- REQ-FL-20: A tool script makes the screenshot of each game and saves it as `assets/tiles/<id>.png`, 640x360 pixels.
- REQ-FL-21: The `add-minigame` skill and `docs/games/TEMPLATE.md` include the step to make the screenshot.
- REQ-FL-22: A test fails when a registry game has no tile file or no description.

### Settings screen
- REQ-FL-23: The screen has the debug overlay switch and the invert tilt switch. The invert switch is saved. The debug overlay is never saved: it always starts off. A switch is a pill with a knob: green with "ON" and the knob on the right, grey with "OFF" and the knob on the left.
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
- `docs/GAME_REQUIREMENTS.md`: the menu rules for the title, the description and the tile. REQ-GM-42 is changed and REQ-GM-45 to 49 (visual language, FD-14) are added.
- `docs/MANUAL_TESTS.md`: new tests for the flow (splash, connect, late join, Back).
- `README.md`: project structure (`assets/fonts`, `assets/tiles`) and controls.
- `scripts/ui/ui_theme.gd`: new palette, outline and shadow helpers (the current colors are replaced).
- `scripts/ui/tv_menu.gd` is split into the logo, connect, games and settings screens.

## 5. Open questions

- The tier 2 values are a first version. The marble race trial can change them (FD-14, REQ-FL-47).
- Logo image: the owner makes it (FD-15). Until the file exists, the logo screen draws the text "REMOTE PLAY" in code.
- The screenshot size (640x360) and the tile count per row may change after a check on a real TV.
