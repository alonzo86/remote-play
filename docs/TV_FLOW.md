# TV app flow

Status: **built**. Visual style: the 8-bit arcade style (FD-18), built in phase 1 of `docs/ARCADE_STYLE_PLAN.md` for the menus, the phone and the game shell. The game worlds still use the toy-like tier 2 rules (REQ-GM-47) until phases 2 to 4. This file holds the decisions (FD-n)
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
Settings: an OPTIONS button on the Games screen opens the Settings screen. The players badge opens the Players modal.
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
| FD-13 | Visual style: **Party Pop**. Chunky, saturated, sticker-like. Thick dark outlines, hard offset shadows, rounded shapes, bright player color tokens. The TV and the phone use the same style. Rejected: Arcade Neon (heavy glow, hard to read from a sofa) and Sticker Book (needs paper image assets). **Replaced by FD-18 on 2026-10-10**; the code moved to the arcade style in phase 1. | 2026-10-07 |
| FD-14 | Games share a visual language, not one look. Tier 1 (required): the game shell (pause menu, countdown, results, HUD), fonts, player colors. Tier 2 (required, trial rules): a toy-like world (rounded shapes, flat saturated colors, dark outline on key objects). Tier 3 (free): setting, background, camera, lighting mood. The exact tier 2 values are in `docs/GAME_REQUIREMENTS.md` (REQ-GM-47a to 47h). A trial on the marble race checks them. | 2026-10-07 |
| FD-15 | The owner makes the logo image. The developer sets the exact tier 2 values. | 2026-10-07 |
| FD-16 | The pointer test and the 3D demo were only for the first test of the prototype. They are removed: code, requirements files, tiles and tests. The marble race is the example of a 3D game. The pointer input of the phone (`PlayerInput.pointer()`, the yaw fusion) stays as an input for a later game, but it has no Settings switch now. | 2026-10-07 |
| FD-17 | The Connect screen has no Continue button and no player count. A line "Press OK to continue" shows when at least one phone has joined, and OK opens the Games screen. (Found in the first run on an Android TV: the button was the only focus target, so it was redundant, and the count repeated the slot list.) | 2026-10-09 |
| FD-18 | Visual style: **8-bit arcade** (look A, "8-bit cabinet"). It replaces Party Pop (FD-13) on the TV, the phone and in the games. Black background, one pixel font (Press Start 2P, with the project font Remote Play Pixel Hebrew as the fallback for Hebrew names), a small NES-like palette, square panels with a double frame (white and blue), text menus with a "▶" cursor, blinking prompts. The game worlds draw at a low resolution and scale up with sharp pixels; the shell (HUD, menus) stays at full resolution. Rejected: Neon CRT (hard to read, as in FD-13), Pixel Pop (too soft), 16-bit arcade, Atari 2600. The owner chose it from the mockups in `docs/design-system/arcade/mockups.html`. The values, the phases and the open questions are in `docs/ARCADE_STYLE_PLAN.md`. Status: phase 1 built (menus, phone, game shell); the game worlds follow in phases 2 to 4. | 2026-10-10 |
| FD-19 | Languages: English and Hebrew in the first localized version. Hebrew uses a right-to-left UI (the game worlds are not mirrored). The player chooses the language on the logo screen at the first start (later in Settings); the phones follow the TV. It replaces REQ-FL-54 when it is built. Details: `docs/ARCADE_STYLE_PLAN.md` section 7 (phase 5). Status: built on 2026-10-10 (REQ-FL-54, 60 to 63); device test 17 is open. | 2026-10-10 |

## 3. Requirements

### Splash and logo screen
- REQ-FL-50: Logo file: `assets/logo/logo.png`, PNG with a transparent background, 1600x600 px, the logo centered with at least 80 px of empty space on every side. It must read well on the black background (FD-18); pixel art fits the style. The logo screen shows it at about 60% of the screen width. If the file is missing, the screen draws the text "REMOTE PLAY" in the arcade font (96 px, yellow) with the line "PHONE MOTION CONTROLLER GAMES" under it.
- REQ-FL-51: The Android splash (REQ-FL-1) uses black `#000000` as the background color (`boot_splash/bg_color`). It uses the app icon, or a square version of the logo (`assets/logo/splash.png`, 432x432 px, transparent) when the owner provides one.
- REQ-FL-1: The app sets the Android splash (background color and icon) in the project settings.
- REQ-FL-2: After the OS splash, the TV shows a logo screen with an animation. It lasts 2 to 3 seconds. At the first start it waits for the language choice instead (REQ-FL-60).
- REQ-FL-3: OK, or a tap on a touch screen, skips the logo screen. Back does not show it (FD-6). At the first start OK chooses the focused language and Back chooses it too (REQ-FL-60); a tap outside the two items does nothing.
- REQ-FL-4: The logo screen starts the network services (server and beacon) while it shows, so the Connect screen is ready at once.

### Connect screen
- REQ-FL-5: The screen has two columns of equal height. Left: the QR code on a white square in a double frame (REQ-FL-38), with the words "ROOM CODE" and the 4-letter room code below it. Right: the title "PLAYER SELECT" with "CREDIT 02" (the number of joined phones, two digits) at its right end, one line of help text, and 4 player slots (REQ-FL-8). The screen does not show the WebSocket address (FD-11).
- REQ-FL-6: The screen has no button (FD-17). A line at the bottom, centered, inside the safe area (60 px margins, RISKS D5), says "PRESS OK TO CONTINUE" (yellow, 40 px, blinking, REQ-FL-42) as soon as at least one phone has joined. Before that the line is empty, except when the TV has no network address: then it says so in `UiTheme.BAD`, without blinking. The slot list shows who has joined.
- REQ-FL-7: OK opens the Games screen when at least one phone has joined. OK does nothing before that, and nothing while the quit question is open (REQ-FL-10).
- REQ-FL-8: A phone that joins or leaves updates the slots at once. A slot is a row (no box): a square (24 px) in the slot color, "1P" to "4P", the player name in upper case, and the state word at the right: "READY" in `OK`, "LOST" in `BAD`, "WAIT" in `TEXT_DIM`. An empty slot shows a dark gray square (`SLOT_EMPTY`) and no name. The state is always a word.
- REQ-FL-9: A phone that is already joined stays joined when the host goes Back from the Games screen to this screen.
- REQ-FL-10: Back on this screen opens a quit confirmation (Quit, Stay). The default focus is "Stay".

### Games screen
- REQ-FL-11: The screen shows one tile for each game in `registry.gd`. A tile has a 16:9 screenshot and the game title (FD-7).
- REQ-FL-12: The tiles are in rows of 3. The content is a column of 1720 px (`tv_games.gd` `CONTENT_W`), centered on any screen width. A tile is 480 px wide (the 16:9 screenshot is 480x270 px) and keeps this size, focused or not (FD-18, question 1 of the plan: the description is in a bar under the grid, REQ-FL-13). The D-pad moves the focus in all 4 directions. The grid scrolls to keep the focused tile in view.
- REQ-FL-13: Every tile has the same layout: the screenshot in a 6 px frame, the title (32 px) and the player range (for example "1-4 PLAYERS") under it. The frame is `TEXT_DIM`. The focused tile has an `ACCENT` frame, an `ACCENT` title and a cursor (REQ-FL-41) before the title. The description of the focused game shows in a framed bar of 3 lines under the grid (3 lines, so the bar keeps its height). A tile that does not accept the players shows the reason in yellow under its title (REQ-FL-14).
- REQ-FL-14: A game that does not accept the current player count has a dimmed tile and a reason ("Needs 2 players"). OK on it does nothing except show the reason (uses `Registry.accepts()`).
- REQ-FL-15: A players badge in the top right shows four squares (in the slot colors, dark gray when empty) and the number of joined players (for example "2P"), in a frame. It does not show the room code (FD-12). The badge is a focus target. OK on it opens the Players modal (REQ-FL-32).
- REQ-FL-16: An OPTIONS button (a frame with text) next to the badge is the last focus target. OK on it opens the Settings screen (FD-4). The screen title is "SELECT GAME".
- REQ-FL-17: A game with a settings view (REQ-GM-90) opens it after OK on the tile: a centered view with Difficulty, Start and Back at the bottom. Back returns to the grid with the same tile in focus. Every game has this view (the marble race adds its track list). Back returns to the grid with the same tile in focus.
- REQ-FL-18: Back on this screen goes to the Connect screen (FD-6).
- REQ-FL-19: The registry entry of a game has a `description` and a `tile` field (path of the screenshot). Both are required for a new game.

### Players modal
- REQ-FL-32: The modal shows the 4 slots with color and state, a QR code with the room code for new phones, and a Close button. It opens on the Games screen (FD-12).
- REQ-FL-33: Each joined or lost slot has a "REMOVE" item (red with the focus). Remove disconnects the phone and frees the slot. The removed phone returns to its connect screen and its token is no longer valid. The slot stays free until a phone actively connects to it: the removed player or another player, by QR code, room code, TV list or TV IP. The removed phone must not reconnect by itself.
- REQ-FL-34: The modal updates live when a phone joins or leaves. The focus starts on Close. Back closes the modal.
- REQ-FL-35: Remove needs a new message to the phone. Change `docs/PROTOCOL.md` in the same commit (use the `change-protocol` skill).
- REQ-FL-36: The player count on the badge and the tile dimming (REQ-FL-14) update when the modal changes the players.

### Visual style (8-bit arcade, FD-18)

These requirements replaced the Party Pop ones (FD-13) in phase 1 of `docs/ARCADE_STYLE_PLAN.md`, which has the reasons and the mockups. Sizes are for 1920x1080.

- REQ-FL-37: All screens use one palette, kept in `UiTheme` (`scripts/ui/ui_theme.gd`): `BG` black `#000000`, `TEXT` `#fcfcfc`, `TEXT_DIM` `#7c7c7c`, `ACCENT` yellow `#f8b800`, `FRAME` blue `#0058f8` (a line, never text), `OK` green `#00b800`, `BAD` red `#f83800`, `DISABLED` (= `TEXT_DIM`), `SLOT_EMPTY` `#3c3c3c`, and the confetti colors `ACCENT`, `OK` and `FRAME`. Every text color has a contrast of 4.5:1 or more on black (a test checks it). The player colors stay as they are in `Protocol`: a square next to the slot number, never the only cue. A few old names (`OUTLINE`, `CARD`, `CARD_TEXT`, `BG_DARK`, ...) point to these colors, for the games until their restyle.
- REQ-FL-38: There are no round corners, no shadows and no outlines around buttons. A panel (the QR card, a modal, a menu card) is black with a double frame: a 6 px `TEXT` line outside, 6 px of black, and a 6 px `FRAME` line inside (`UiTheme.frame()`, drawn by `arcade_frame.gd`). A box (a tile, the badge, OPTIONS, a phone button) has one 6 px line (`UiTheme.line_box()`): `TEXT_DIM`, and `ACCENT` with the focus.
- REQ-FL-39: One font: Press Start 2P (SIL OFL), a TTF file in `assets/fonts/` with its license file. The project font Remote Play Pixel Hebrew is its fallback, for Hebrew player names. Both fonts are imported with antialiasing off, no hinting and no subpixel positioning (a test checks the import files), and every text size is a multiple of 8, so the pixels stay sharp. All UI text is upper case, also player names; the code does it where it sets a text (`to_upper()`).
- REQ-FL-40: Text on the TV is at least 32 px high at 1080p, also help text (read from a sofa). Sizes: body text, hints and tile titles 32 px, menu items and slots 40 px, modal titles 48 px, titles 64 px, the logo text 96 px, the countdown 256 px. Text that is part of a picture (the logo file) and the numbers on a ball are not counted. The text of a game HUD (title, chips, timer) is 32 px. Phone text is 24 px or more on the phone screen (the phone viewport is about 1080 px wide: 32 px or more). Text has a contrast of 4.5:1 or more on black.
- REQ-FL-41: A list of choices (results, pause, quit, settings, Players modal) is a text menu (`UiKit.menu()`, `menu_item.gd`), not a row of buttons. The focused item is `ACCENT` with a cursor in front of it, drawn as pixels (`UiTheme.draw_cursor()`: 4 columns of 7, 5, 3 and 1 pixels), not as a font glyph. Other items are `TEXT`. A destructive item (`DangerButton`: END GAME, QUIT, REMOVE) is `BAD` when it has the focus. A quiet item (`QuietButton`: BACK) is `TEXT_DIM` until it has the focus. A disabled item is `DISABLED` and gets no cursor. Focus never depends on color alone: the cursor shows it. A click or a tap leaves no focus on the item (the D-pad does focus). The default focus of a confirmation is the safe item (STAY).
- REQ-FL-41a: Settings rows (`choice_row.gd`, the Settings screen) are menu items too: the name at the left, the value at the right (`ACCENT` for the chosen value in the game settings view, REQ-GM-97). On the phone there is no cursor, so a button is a framed text box (`UiKit.box_button()`): a 6 px `TEXT` line, `ACCENT` with the keyboard focus, filled when pressed.
- REQ-FL-53: A destructive item (`DangerButton`) is `TEXT` and turns `BAD` with the focus (5.6:1 on black); it has no "✕". It is used in confirmations only (QUIT, END GAME) and for REMOVE. The default focus of a confirmation is the safe, main item. The text of every state of every menu item has a contrast of 4.5:1 or more on black (a test checks it).
- REQ-FL-42: Motion moves in hard steps, not smooth tweens. A prompt (PRESS OK TO CONTINUE, PRESS OK TO SKIP) blinks: 0.55 s on, 0.55 s off (`UiTheme.blink_on()`). The logo drops in from the top in steps of 16 px over about 0.5 s and ends with one burst of square pixel confetti (`ACCENT`, `OK`, `FRAME`). The countdown number settles in 4 steps of font size (352, 320, 288, 256 px). Screen changes are a hard cut. Menus and modals appear at once.
- REQ-FL-43: Motion stops while a game is paused or a phone is lost, and no motion blocks input.
- REQ-FL-44: The style uses only styled boxes, tweens, particles and fonts. It uses no shader. It must run at 60 fps on the weakest supported TV box (check in `docs/MANUAL_TESTS.md`).
- REQ-FL-45: The background is plain black, with no pattern. The confetti of the logo is drawn in code. It is not an image file.
- REQ-FL-46: The phone app uses the same palette, font and frames (REQ-FL-28).
- REQ-FL-52: Phone buttons follow REQ-FL-41a. On the pad, A and B are round arcade buttons: a 6 px `TEXT` ring, a darker lower edge, and a face that sits lower while the button is down. A is green (`OK`) and B is red (`BAD`) (question 6 of the plan). RECENTER is a yellow framed box (it fills with yellow for a moment when tapped) and LEAVE is a `TEXT` framed box. The player color is only the square at the top with the slot number, never a button fill. A number or letter on a color uses `UiTheme.text_on()` (black on every player color). Leave needs two taps: the first tap turns it red ("TAP AGAIN TO LEAVE" on the wait screen, "AGAIN" on the pad) for 3 s. Error and offline text uses `UiTheme.BAD`.
- REQ-FL-54: The app has two languages, English and Hebrew (FD-19). Hebrew is written right to left: with Hebrew, the root window uses the right to left layout direction (`Lang.set_language()`), so the screens mirror: the QR card is at the right of the Connect screen, a slot row reads right to left (the square at the right), a menu item has its cursor at the right (a pixel cursor that points left), the Back and Start items of a settings view swap sides, and the arrows of a choice row swap (Right goes to the previous value). The game worlds are **not** mirrored (REQ-GM-47o), and the touch pad of the phone keeps its layout. Without a saved choice the language is the language of the device (Hebrew, or the old code `iw`, gives Hebrew; every other language gives English). The language and the layout never depend on the region of the device (the finding of run R1: a TV set to Hebrew and region IL mirrored an English UI).
- REQ-FL-55: The Back key of the remote and of the phone goes back one step in the app and never quits the app by itself. The project setting `application/config/quit_on_go_back` is false. The app quits only through the quit question of the Connect screen (REQ-FL-10).
- REQ-FL-56: A tile whose image is missing or cannot be loaded shows a placeholder (a color from the id) and writes a warning to the log (`adb logcat -s godot`). It never shows an empty box without a reason.
- REQ-FL-57: The screenshot of a tile has square corners and is drawn with nearest filtering. (Found in the first run on an Android 10 TV: the screenshots did not show. The cause is not confirmed: the warning of REQ-FL-56 shows it. See Test 8b item 2 in `docs/MANUAL_TESTS.md`.)
- REQ-FL-58: On an iPhone or iPad (`OS.get_name() == "iOS"`) the phone connect screen has no "Scan QR code" and no "Paste TV link" button: it shows only the list of discovered TVs and Refresh (there is no scanner plugin on iOS). Android and desktop (also a Mac) keep the button. (Device: Manual test 13.)
- REQ-FL-59: On an iPhone or iPad, when the list of discovered TVs is empty and the screen is not searching, a second line under "No TVs found" says: "No TV? In Settings, allow Local Network for this app, and use the same Wi-Fi as the TV." (iOS asks for the Local Network permission once; without it the beacon is not received.) Other platforms show only "No TVs found". (Device: Manual test 13.)
- REQ-FL-60: The first start of the TV app (no saved language, `App.needs_language_choice()`): the logo screen does not go on by itself. Under the logo it shows two items, "ENGLISH" and "עברית", each written in its own language and in the same size, English at the left in both layouts. The focus starts on the language of the device. OK on an item chooses it: the app saves it (`user://settings.cfg`, key `language`), switches the UI at once and goes to the Connect screen. Back chooses the language that has the focus. The line under the items says "PRESS OK TO CHOOSE". Every later start has no choice: the logo goes on by itself (REQ-FL-2, 3).
- REQ-FL-61: The Settings screen has a Language row (after "Invert tilt axes"): its right end shows the name of the current language ("ENGLISH" or "עברית", yellow, in its own language). OK switches to the other language at once (no restart): all text and the layout direction change, the choice is saved, and the phones follow (REQ-FL-62).
- REQ-FL-62: A phone shows the language of the TV after it has joined. The TV sends it in `welcome` (`lang`) and, when it changes, in the message `lang` (`docs/PROTOCOL.md`). Before it joins, and after it leaves, the phone uses the language of the phone (REQ-FL-54). The phone does not save the language of the TV. A TV of an older build sends none: the phone keeps its own language.
- REQ-FL-63: Every text of the UI goes through the translation (`Lang`, `scripts/core/strings.gd`): the English text in upper case (or the format string) is the key. Labels and buttons translate by themselves; text that code draws (`Shell`) or builds from a name or a number goes through `Lang.t()` and `Lang.f()`. A player name is never translated. A text without a Hebrew entry shows in English, so the screen still works. `tests/smoke_lang.gd` fails when a literal text of the code, a game title or description, a setting name or value, or a medal text has no Hebrew entry, and when a TV screen shows an English word in Hebrew (a name, the room code and the brand names REMOTE PLAY, WI-FI, QR, OK are the exceptions). The text must fit in both languages: the longer one decides the layout (checked on a device, Test 17).

### Game shell and trial (FD-14)
- REQ-FL-47: The next pull request restyles the marble race as a trial of the tier 2 rules (REQ-GM-47). The result is judged with a screenshot of the game next to the Games screen (REQ-GM-49). The trial checks the tier 2 values (REQ-GM-47a to 47h) and they are corrected in `docs/GAME_REQUIREMENTS.md` if they are wrong. If the trial shows that games need more freedom, the rules are made looser before any other game is changed.
- REQ-FL-48: The game shell (REQ-GM-45) is built in the same pull request as the menus. A game must not show an old style pause menu, countdown or result screen next to the new menus.
- REQ-FL-49: The other games get the shell in the same pull request. Their tier 2 restyle follows in a later pull request. (Done for the maze. The pointer test and the 3D demo were removed, see FD-16.)

### Tile screenshots
- REQ-FL-20: A tool script makes the screenshot of each game and saves it as `assets/tiles/<id>.png`, 640x360 pixels.
- REQ-FL-21: The `add-minigame` skill and `docs/games/TEMPLATE.md` include the step to make the screenshot.
- REQ-FL-22: A test fails when a registry game has no tile file or no description.

### Settings screen
- REQ-FL-23: The screen has the debug overlay switch and the invert tilt switch. The invert switch is saved. The debug overlay is never saved: it always starts off. A switch is a menu item with the word "ON" (green) or "OFF" (gray) at its right end. The screen has a third row, Language (REQ-FL-61).
- REQ-FL-24: Back returns to the Games screen with the OPTIONS button in focus.

### Network scope
- REQ-FL-31: Only phones on the same local network as the TV can join (FD-10). The app uses no internet service for play (REQ-P5). The Connect screen help text tells the players to be in the same room and on the same Wi-Fi.

### Players that join and leave
- REQ-FL-25: A phone can join on any screen of the TV, also during a game. A new phone waits for the next round (it gets the slot but does not take part).
- REQ-FL-26: A phone that leaves or is lost during a game uses the existing pause and reconnect rules (REQ-T5, REQ-N5).
- REQ-FL-27: When the player count changes on the Games screen, the tiles update at once (REQ-FL-14).

### Phone app
- REQ-FL-28: The phone shows the TV phase after it has joined: "WAITING FOR THE HOST" (logo and Connect screen), "CHOOSE A GAME ON THE TV" (Games and Settings screens), and the game pad (playing and paused). The wait screen shows the slot color square with the slot number and "1P" to "4P".
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

- The open questions of the arcade style (FD-18) are in `docs/ARCADE_STYLE_PLAN.md` section 4.

- The tier 2 values are a first version. The marble race trial can change them (FD-14, REQ-FL-47).
- Logo image: the owner makes it (FD-15). Until the file exists, the logo screen draws the text "REMOTE PLAY" in code.
- The screenshot size (640x360) and the tile count per row may change after a check on a real TV.
