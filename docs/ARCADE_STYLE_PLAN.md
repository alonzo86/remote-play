# Arcade style and localization plan (FD-18, FD-19)

Status: **phases 1 to 5 built** (phase 1: menus, phone, game shell, manual test 16; phase 2: the pixel view and Sumo Bumpers, manual test 15; phase 3: the 3D pixel view and Marble Race, manual test 9; phase 4: Tilt Maze, Paint Grab and Snowball Splat, manual tests 6, 14 and 10). Phase 5, English and Hebrew with a right to left UI, was built on 2026-10-10 (manual test 17). The style requirements are in
`docs/TV_FLOW.md` (REQ-FL-37 to 46) and `docs/GAME_REQUIREMENTS.md` (REQ-GM-45, 46); REQ-GM-47 and 48 (the game worlds) still
described the toy-like tier 2 rules until phase 2; phases 2 to 4 are built and REQ-GM-47i to 47n are the rules now.
Style: ASD-STE100 Simplified Technical English, like the other requirements files.

## 1. Decision

On 2026-10-10 the owner chose look **A, "8-bit cabinet"** for the TV app, the phone app and the games (FD-18 in
`docs/TV_FLOW.md`). It replaces Party Pop (FD-13). Four other looks were compared and rejected: B Neon CRT (glow and
scanlines are hard to read from a sofa, the same reason as for Arcade Neon in FD-13), C Pixel Pop (too soft), D 16-bit
arcade, and E Atari 2600.

The mockups of all five looks (look A was chosen) were in `docs/design-system/arcade/mockups.html`; the file was removed on
2026-10-16, because the games and the screens look different now. They were a direction, not exact pixels. This file gives the values.

## 2. Target style

These values become the requirements in `docs/TV_FLOW.md` (they replace REQ-FL-37 to 46) in the phase 1 pull request.
Sizes are for 1920x1080.

### 2.1 Palette

A small fixed palette, taken from the NES palette. All text colors have a contrast of 4.5:1 or more on black.

| Token | Color | Use | Contrast on black |
|-------|-------|-----|-------------------|
| `BG` | `#000000` | Every screen background | - |
| `TEXT` | `#fcfcfc` | Text, the outer frame line | 20.5:1 |
| `TEXT_INFO` | `#b0b0b0` | Active info text: help text, "WAIT", empty slots, the player range (issue #221) | 9.7:1 |
| `TEXT_DIM` | `#7c7c7c` | A disabled item only, and the frame of a tile that is not focused (not text) | 5.0:1 |
| `ACCENT` | `#f8b800` | Titles, the room code, the focused item, "PRESS OK" | 11.8:1 |
| `FRAME` | `#0058f8` | The inner frame line (not text) | 3.8:1 |
| `OK` | `#00b800` | "READY", good | 7.9:1 |
| `BAD` | `#f83800` | "LOST", errors, danger | 5.6:1 |
| `DISABLED` | `#7c7c7c` | A disabled item: dim text, no cursor | 5.0:1 |
| `BUTTON_FACE` | `#fcfcfc` (`TEXT`) | The face of every enabled button (issue #173) | - |
| `BUTTON_TEXT` | `#000000` (`BG`) | The text on that face | 20.5:1 on the face |
| `BUTTON_EDGE` | `#a4a4a4` | The lower edge of the round A and B buttons | 2.4:1 on the face |
| `MARK_W` | 12 px | The border of a marked button (focus, chosen, active): twice `LINE`, `ACCENT` | - |

The player colors stay as they are in `Protocol` (`#e63946`, `#2a9d8f`, `#f4a261`, `#457b9d`). They are 4.6:1 or more on
black. They show as a filled square next to the slot number, never as the only cue.

### 2.2 Font

- One font: **Press Start 2P** (SIL OFL, TTF in `assets/fonts/` with its license file). It replaces Lilita One and
  Fredoka. The font is an 8 px grid: sizes are multiples of 8, with antialiasing off and no hinting, so the pixels stay
  sharp.
- Sizes on the TV: body text and hints 32 px, menu items and slots 40 px, titles 64 px, the logo text 96 px, the
  countdown 256 px. The rule "all TV text is 32 px or more" (REQ-FL-40) stays; the smallest size is 32 px.
- All UI text is upper case ("PRESS OK TO CONTINUE", "1P ALON"). Player names show in upper case.
- Hebrew player names use **Sababi Pixel Hebrew** (`assets/fonts/SababiPixelHebrew.ttf`, SIL OFL), a fallback
  font made for this project on the same 8 px grid: 2 px vertical strokes, 1 px horizontal strokes, the cap height of
  Press Start 2P, and final letters (and qof) that go 2 px lower than the other letters. It has the 27 letters, maqaf, geresh and
  gershayim, no niqqud. The TTF file is the source: change it with a font editor (the tool that drew it is not in the repository). The UI text is English or Hebrew (FD-19, REQ-FL-54 was changed by it); this font is the Hebrew fallback and covers names. Other characters (emoji) use the Godot default font.
- The phone uses the same font, at 24 px or more on a phone screen.

### 2.3 Frames and shapes

- No round corners, no hard offset shadows, no outlines around buttons. `RADIUS`, `SHADOW` and `OUTLINE_W` go away.
- A panel (the QR card, the result box, the pause box, a modal) is black with a **double frame**: a 6 px `TEXT` line
  outside, 6 px of black, and a 6 px `FRAME` blue line inside.
- A player slot is a row: the slot color square (24 px), "1P" to "4P", the name, and the state word ("READY" in `OK`,
  "WAIT" in `TEXT_INFO`, "LOST" in `BAD`).
- The players badge shows four small squares (filled in the slot color when joined, dark gray when empty) and "2P".

### 2.4 Menus and focus

- A list of choices (results, pause, quit, settings) is a text menu, not a row of buttons. The focused item is
  `ACCENT` with a "▶" cursor in front of it (drawn as pixels, not a font glyph). Other items are `TEXT` (also the quiet item BACK, since issue #173; only a disabled item is dim). A destructive
  item ("END GAME", "QUIT") is `BAD` when it has focus. A choice never depends on color alone: the cursor shows focus.
- A game tile has a 6 px `TEXT_DIM` frame. The focused tile has a 6 px `ACCENT` frame, a pixel cursor (REQ-FL-41) before its title, and it
  shows no growth (FD-7 was changed by question 1: the description is in a bar under the grid and the tiles keep one size).
- The default focus of a confirmation stays on the safe item (REQ-FL-10, REQ-FL-53).

### 2.5 Phone pad

- Every enabled button, on the phone and on the TV, is white (issue #173, 2026-10-29): the face is `BUTTON_FACE`, the text
  is `BUTTON_TEXT` (black), the edge is white. Pressed is the reverse (black face, white text). A disabled button keeps
  its dim look (a `TEXT_DIM` line on black). A mark (the chosen IN or OUT, the active player) is a `MARK_W`
  `ACCENT` border around the white face, so it is a shape and a color. The focus is a yellow face with black text and the same border. The code is `UiTheme.button_box()` and
  `UiTheme.style_button()`; no screen styles a button by itself (`tests/design_tokens.gd`). A text menu item has no face (it
  is white text with a cursor, section 2.4); a game tile is a picture with a frame, not a button.
- A and B are round white arcade buttons: a 6 px white ring, a `BUTTON_EDGE` lower edge and a white face with a black
  letter (the button looks pressed in when it is down). A and B differ by the letter only (question 6).
- RECENTER and DISCONNECT are white text boxes. DISCONNECT leaves with one tap (REQ-FL-52; it was LEAVE with two taps until 2026-10-11).
- The slot color square and "2P" are at the top. The text under them says what to do ("TILT TO ROLL").

### 2.6 Motion

- "PRESS OK TO CONTINUE" and other prompts blink: 0.55 s on, 0.55 s off, a hard step, not a fade.
- Movement moves in steps of whole pixels of the 8 px grid (a tile grows in 4 steps over about 180 ms, not a smooth
  tween).
- Screen changes are a hard cut or a short wipe of up to 250 ms.
- The logo drops in from the top in steps. The confetti burst becomes square pixel confetti in `ACCENT`, `OK` and
  `FRAME`.
- Motion stops while a game is paused (REQ-FL-43). No shader (REQ-FL-44).

### 2.7 Games (pixel worlds)

- The game world draws at a low resolution and scales up with nearest filtering. The default is **480x270** (one game
  pixel is 4x4 screen pixels at 1080p, 8x8 at 4K). See open question 4.
- The shell (HUD, chips, timer, countdown, pause, results, hints) draws on top at full 1920x1080, with the arcade font.
  It does not go through the low-res view, so text stays readable.
- Tier 2 (REQ-GM-47) is replaced by pixel rules: a 1 game-pixel black outline on key objects, flat colors from a
  limited world palette, no rounding rule (shapes are stepped by the pixel grid), key objects 12 game pixels (48 screen
  pixels) or more, and the 3:1 contrast rule stays. The exact values are set by the trial in phase 2, like the marble
  race trial set the Party Pop values (REQ-FL-47).
- The number on a player ball must stay readable at 480x270. The trial checks it; if it is not readable, the shell
  draws the number at full resolution above the ball.

## 3. Phases

Each phase is one pull request. Each one changes its requirements files in the same commit (REQ-GM-5), comes with its
tests, keeps every module at 80% coverage or more, and adds or changes its manual tests (REQ-GM-62).

### Phase 0: decision and plan (this change)

- FD-18 in `docs/TV_FLOW.md`, this plan.
- Notes in the files that describe Party Pop, so that nobody builds new Party Pop work: `README.md`,
  `docs/REQUIREMENTS.md`, `docs/GAME_REQUIREMENTS.md`, `docs/design-system/README.md`, the `review` and
  `add-minigame` skills and the `design-reviewer` agent.

### Phase 1: arcade UI (TV menus, phone, game shell) - built

Decisions taken while building it: the description of the focused tile is in a bar under the grid and the tiles keep one size (question 1,
default a); the gear is an OPTIONS box (as in the mockup); the in-game title is 32 px (the HUD must fit next to the timer and the chips);
modal titles are 48 px; the slot color squares always get black text (`UiTheme.text_on()`, 4.5:1 or more on all four colors).

The menus and the shell change in the same pull request, so a game never shows an old pause menu next to new menus
(the same rule as REQ-FL-48).

1. Add `PressStart2P-Regular.ttf` and `OFL-PressStart2P.txt` to `assets/fonts/`. Import it and
   `SababiPixelHebrew.ttf` with antialiasing off and no hinting, and set the Hebrew font as the fallback of Press
   Start 2P. Remove Lilita One and Fredoka.
2. `scripts/ui/ui_theme.gd`: the palette of section 2.1, the font of 2.2, the frame style of 2.3. Remove the Party Pop
   colors that have no use. Keep the role names (`BG`, `TEXT`, `ACCENT`, `OK`, `BAD`) so that the games keep working.
3. `scripts/ui/ui_kit.gd`: a double-frame panel, a text menu with the pixel cursor (it replaces the button rows), the
   blinking label.
4. TV screens: `tv_logo.gd`, `tv_connect.gd`, `slot_list.gd`, `tv_games.gd`, `game_tile.gd` (square corners, remove
   `GameTile.rounded()` and REQ-FL-57), `players_badge.gd`, `players_modal.gd`, `tv_modal.gd`, `tv_settings.gd`,
   `tv_game_settings.gd`, `track_picker.gd`, `gear_button.gd`, `confetti.gd`, `choice_row.gd`, `backdrop.gd`.
5. Phone screens: `controller_connect.gd`, `controller_wait.gd`, `controller_pad.gd`.
6. Game shell: `scripts/game/shell.gd`, `minigame.gd`, `minigame_3d.gd` (HUD, chips, timer, countdown, hint, pause and
   result menus).
7. The Android splash color (REQ-FL-51) becomes black. The logo screen draws "SABABI" in the arcade font until
   the logo file exists (FD-15, open question 5). The logo file exists since 2026-10-10 (FD-21 (naming), FD-26).
8. Requirements: replace REQ-FL-37 to 46, 41a, 52, 53, 56, 57 in `docs/TV_FLOW.md`; change REQ-P6 in
   `docs/REQUIREMENTS.md` (the font file); change REQ-GM-45, 46 in `docs/GAME_REQUIREMENTS.md` (chips and balls in the
   new style).
9. Design system: update `tokens.json` from the new `UiTheme`, run `tools/design_tokens_css.py`, and redo the
   component previews and READMEs in `docs/design-system/components/`.
10. Tests: the button contrast test (REQ-FL-53) becomes a menu item contrast test; the theme and shell tests follow
    the new values.
11. Manual test: a new device test for the arcade look (see section 5).

### Phase 2: pixel world trial (Sumo Bumpers) - built

Decisions taken while building it: the view is a `SubViewport` of 480x270 with `size_2d_override` set to the size of the game node, so a game keeps its 1920x1080 drawing code (REQ-GM-47i); the HUD, the slot numbers and "WHEE!" are drawn on the game node at full resolution (the view is behind it, `z_index` -1); the new rules are REQ-GM-47i to 47n and they sit next to the old tier 2 rules until each game is restyled (a game that is not restyled keeps 47a to 47h). The values are first guesses until test 15.

1. A low-res game view in `minigame.gd`: the world draws into a 480x270 `SubViewport` with nearest filtering, and the
   shell draws on top at full resolution.
2. Restyle Sumo Bumpers (2D, simple shapes) with the pixel rules of section 2.7.
3. Set the exact tier 2 values in `docs/GAME_REQUIREMENTS.md` (they replace REQ-GM-47a to 47h and REQ-GM-48) after the
   trial. Make the tile again (`tools/make_tiles.gd`).

### Phase 3: 3D trial (Marble Race) - built

Decisions taken while building it: the 3D view is a `SubViewport` of 480x270 shown by a `TextureRect` with nearest filtering (`minigame_3d.gd`, for every 3D game); the HUD maps world points with `world_to_hud()`; the slot number of a marble is drawn by the HUD (a marble with a radius under 16 px on the HUD has none); the background is the arcade blue `#1b3a8a` and the rim is black. The frame rate gain on a TV box is not measured: Test 9 item 12.

1. The low-res view in `minigame_3d.gd` (a 480x270 `SubViewport` for the camera, no antialiasing).
2. Restyle Marble Race: the outline meshes stay (REQ-GM-47c), the colors move to the world palette. Check that the
   marbles and the slot numbers stay readable, and the frame rate on the TV box (it should go up: fewer pixels).

### Phase 4: the other games - built

Decisions taken while building it: one pull request for each game, stacked. Tilt Maze got walls of 12 px and Hard cells of 76 px (the 4 px grid); Paint Grab tiles are a whole number of world pixels wide, a painted tile has no lighter edge, and its timer box is 240 px; Snowball Splat has pixel snowfall in game time and a poof in 3 hard steps. The star field, the eyes and the centered text are shared `Shell` helpers.

Tilt Maze, Paint Grab, Snowball Splat, one pull request each, with their tile. Their visual requirements change:
REQ-MZ-7, REQ-PG-15, REQ-SS-12, REQ-SB-15, REQ-MR-44.

## 4. Open questions for the owner

Each question has a default. On 2026-10-10 the owner said to keep the defaults; question 2 got a project font.

1. **Long text in a wide font.** Press Start 2P is wide: at 32 px about 11 characters fit in the description panel of a
   tile, and a game description has about 60. Options: (a) the description goes in a bar under the grid, (b) shorter
   descriptions, (c) a narrow second pixel font for long text only. Default: (a).
2. **Names the font cannot show.** Decided 2026-10-10: Hebrew uses the project font Sababi Pixel Hebrew (section
   2.2); emoji and other scripts use the Godot default font.
3. **Arcade flourishes in the mockup**: "CREDIT 02" for the player count, "PLAYER SELECT" and "SELECT GAME" as titles,
   "1P" instead of "P1". Default: use them as in the mockup.
4. **Game resolution.** 480x270 (the default) keeps detail; 320x180 is chunkier and more "real 8-bit", but small
   objects get hard to see.
5. **Logo.** The owner makes the logo (FD-15). It must now read on black, and pixel art fits the style. Default: text
   logo in the arcade font until then. Done on 2026-10-10: a pixel-art logo and splash (FD-21 (naming), FD-26).
6. **Phone A and B colors.** The mockup shows two red arcade buttons. The rule was A green, B red (REQ-FL-52). Decided
   2026-10-29 (issue #173, the owner's wording "all enabled buttons are white"): A and B are white, the letter tells them apart.
7. **Where to choose the language** (section 7.1). Decided 2026-10-10: on the logo screen at the first start only,
   then automatic as now, and a Language row in Settings.

## 5. Manual tests

- New test (phase 1): the arcade look on a real TV and phone. Read every screen from the sofa (about 3 m): 32 px text,
  the blinking prompts, the frames; the pixels are sharp, not blurred (on a 1080p and, if available, a 4K TV); the
  phone screens; 60 fps on the TV box.
- Tests that must run again after phase 1: 1 (Connect screen), 8b (TV flow and style), 11 (result menus), 13 (iPhone
  controller).
- After phases 2 to 4: the game tests of each restyled game (6, 9, 10, 14, 15) and 12 (game tiles).

## 6. Risks

- **Readability.** A wide, all-caps font is slower to read. Keep text short; the device test checks it.
- **Kids 5 to 8.** The look can feel cold. The device tests with a child (tests 10, 14, 15) watch for it.
- **Blur.** Pixel art looks bad when it scales by a non-whole number. The TV is 1920x1080 or 3840x2160, so 4x or 8x;
  the window stretch mode stays `canvas_items` and the game view uses whole-number scaling.
- **Size of phase 1.** It touches almost every UI file. It is one pull request because of the rule against mixed
  looks.

## 7. Localization: English and Hebrew (phase 5)

Decided on 2026-10-10 by the owner: the first localized version has two languages, English and Hebrew. Hebrew needs a
right-to-left (RTL) UI. This replaces REQ-FL-54 ("the UI is always English and always left to right") in the phase 5
pull request (FD-19 in `docs/TV_FLOW.md`). Phase 5 comes after phase 1, because it changes the same screens. It can run
before or between phases 2 to 4.

### 7.1 Where the player chooses the language

Decided on 2026-10-10 (open question 7):
- **First start of the TV app:** the logo screen does not move on by itself. It shows the logo and a language choice
  under it: "ENGLISH" and "עברית", each in its own font. The focus starts on the language of the TV (Hebrew when the
  system language is Hebrew, else English). OK chooses, the app saves it and goes to the Connect screen. This changes
  REQ-FL-2 and REQ-FL-3 for the first start only.
- **Every later start:** the logo screen moves on by itself as now (REQ-FL-2, 2 to 3 seconds).
- **To change it later:** a "LANGUAGE" row on the Settings screen (FD-4) switches between English and Hebrew at once,
  with no restart.
- **The phone:** before it joins, the phone uses the language of the phone (Hebrew when the system language is Hebrew,
  else English). Changed 2026-10-29 (issue #171, REQ-FL-62): it keeps that language after it joins and never follows the
  TV. The phone changes its own language with the language button on its Settings screen (kept after a restart). The TV
  still sends its language, but a phone ignores it.

Why not a choice on every start: the same family uses the same language every time, and a stop on every start adds a
step before every game night.

### 7.2 Strings

- Every UI text goes through Godot translation (`tr()`, a `.csv` translation file in `translations/` with the columns
  `key,en,he,where,notes` (`assets/lang/strings.csv`, FD-24)). Game names, descriptions, hints, result titles and medal names are translated too (the registry
  stores keys, not text).
- A test fails when a key has no English or no Hebrew text, or when code shows a text that is not a key.
- Player names are never translated.
- English stays upper case (section 2.2). Hebrew has no case.

### 7.3 Right to left

- In Hebrew, the root window uses `LAYOUT_DIRECTION_RTL`. Godot containers mirror by themselves: the QR card moves to
  the right of the Connect screen, a slot row reads right to left, the menu cursor "▶" becomes "◀" on the right side of
  the item.
- Code that draws by hand (`shell.gd`, `_draw()` in the screens and games) must mirror its HUD positions: the chips
  start at the right (1P is the rightmost), the title is at the top right, the timer at the top left.
- The game worlds are **not** mirrored: a maze or a track is the same in both languages. Only text and HUD mirror.
- Mixed text (a Hebrew sentence with a Latin name or a number) uses the Godot BiDi text server (TextServerAdvanced).
  The Android and iOS exports must include its ICU data. A test shows a mixed line in the right order.
- The D-pad moves the focus by position on the screen, so Left still moves left on a mirrored screen.

### 7.4 Font

- Hebrew UI text uses Sababi Pixel Hebrew (section 2.2) as the main font, with Press Start 2P as its fallback for
  digits and Latin letters. The Hebrew font then needs the punctuation used in Hebrew text (`,` `.` `!` `?` `:` `-`
  `"` `'`); add them to the font on the same grid.
- Text must fit in both languages: the longest of the two decides the layout.

### 7.5 Phase 5 steps

Built on 2026-10-10 (REQ-FL-54, 60 to 63, REQ-GM-47o, protocol message `lang`). How it differs from this text: the translation
table was a GDScript file (`scripts/core/strings.gd`, the English text was the key) and not a `.csv` file, so that it needed no import
step and no `.translation` file in the build. On 2026-10-11 it became `assets/lang/strings.csv` with real keys (FD-24), which the app reads itself, so there is still no import step; `TranslationServer` still translates labels and buttons by itself. The check that
"a text without a key" fails is a static scan and a screen scan in `tests/smoke_lang.gd`. The project setting
`internationalization/locale/include_text_server_data` is on, so the exports carry the text server data (the ICU data of the
break iterator); the BiDi order itself comes from TextServerAdvanced, and a test checks the order of a mixed line. The device
test 17 checks the Android and iOS builds.

1. FD-19 in `docs/TV_FLOW.md`; replace REQ-FL-54 with the language and RTL requirements of this section; change
   REQ-FL-2, 3 (first start) and REQ-FL-23 (the Settings row).
2. The translation file, `tr()` in every screen, the shell and the games; the key test.
3. The language choice on the logo screen, the Settings row, saved in the user settings.
4. The language message to the phones (`docs/PROTOCOL.md`, with the `change-protocol` skill).
5. RTL: the layout direction, the hand-drawn HUD positions, the menu cursor; the BiDi export data.
6. The Hebrew punctuation in the font. (Built without a change to the font: the Hebrew font is the fallback of Press Start 2P, so
   `,` `.` `!` `?` `:` `-` `"` `'` come from Press Start 2P and no glyph needed to be added. The device test 17 checks that
   they look right next to the Hebrew letters.)
7. Manual test: the TV and two phones in Hebrew (first start, the choice, every screen mirrored and readable, each
   phone in its own language and never the TV's (since 2026-10-29), a change in Settings), and in English. Test 8b item 7 ("a TV set to Hebrew stays English")
   changes: the TV now offers Hebrew.
