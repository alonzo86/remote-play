# Arcade style plan (FD-18)

Status: **planned**. Nothing is built yet. The code and the style requirements (`docs/TV_FLOW.md` REQ-FL-37 to 46,
`docs/GAME_REQUIREMENTS.md` REQ-GM-45 to 48) still describe Party Pop (FD-13) until the pull request of each phase
changes them.
Style: ASD-STE100 Simplified Technical English, like the other requirements files.

## 1. Decision

On 2026-10-10 the owner chose look **A, "8-bit cabinet"** for the TV app, the phone app and the games (FD-18 in
`docs/TV_FLOW.md`). It replaces Party Pop (FD-13). Four other looks were compared and rejected: B Neon CRT (glow and
scanlines are hard to read from a sofa, the same reason as for Arcade Neon in FD-13), C Pixel Pop (too soft), D 16-bit
arcade, and E Atari 2600.

The mockups of all five looks are in `docs/design-system/arcade/mockups.html` (open it in a browser). Look A is the
first section, and the "A and C, screen by screen" section shows A on the Games menu, a countdown, the results, the
pause menu and the phone screens. The mockups are a direction, not exact pixels. This file gives the values.

## 2. Target style

These values become the requirements in `docs/TV_FLOW.md` (they replace REQ-FL-37 to 46) in the phase 1 pull request.
Sizes are for 1920x1080.

### 2.1 Palette

A small fixed palette, taken from the NES palette. All text colors have a contrast of 4.5:1 or more on black.

| Token | Color | Use | Contrast on black |
|-------|-------|-----|-------------------|
| `BG` | `#000000` | Every screen background | - |
| `TEXT` | `#fcfcfc` | Text, the outer frame line | 20.5:1 |
| `TEXT_DIM` | `#7c7c7c` | Help text, "WAIT", empty slots, the quiet menu item | 5.0:1 |
| `ACCENT` | `#f8b800` | Titles, the room code, the focused item, "PRESS OK" | 11.8:1 |
| `FRAME` | `#0058f8` | The inner frame line (not text) | 3.8:1 |
| `OK` | `#00b800` | "READY", good | 7.9:1 |
| `BAD` | `#f83800` | "LOST", errors, danger | 5.6:1 |
| `DISABLED` | `#7c7c7c` | A disabled item: dim text, no cursor | 5.0:1 |

The player colors stay as they are in `Protocol` (`#e63946`, `#2a9d8f`, `#f4a261`, `#457b9d`). They are 4.6:1 or more on
black. They show as a filled square next to the slot number, never as the only cue.

### 2.2 Font

- One font: **Press Start 2P** (SIL OFL, TTF in `assets/fonts/` with its license file). It replaces Lilita One and
  Fredoka. The font is an 8 px grid: sizes are multiples of 8, with antialiasing off and no hinting, so the pixels stay
  sharp.
- Sizes on the TV: body text and hints 32 px, menu items and slots 40 px, titles 64 px, the logo text 96 px, the
  countdown 256 px. The rule "all TV text is 28 px or more" (REQ-FL-40) stays; the smallest size is now 32 px.
- All UI text is upper case ("PRESS OK TO CONTINUE", "1P ALON"). Player names show in upper case.
- A character that the font does not have (for example a Hebrew name or an emoji) uses a fallback font. See open
  question 2.
- The phone uses the same font, at 24 px or more on a phone screen.

### 2.3 Frames and shapes

- No round corners, no hard offset shadows, no outlines around buttons. `RADIUS`, `SHADOW` and `OUTLINE_W` go away.
- A panel (the QR card, the result box, the pause box, a modal) is black with a **double frame**: a 6 px `TEXT` line
  outside, 6 px of black, and a 6 px `FRAME` blue line inside.
- A player slot is a row: the slot color square (24 px), "1P" to "4P", the name, and the state word ("READY" in `OK`,
  "WAIT" in `TEXT_DIM`, "LOST" in `BAD`).
- The players badge shows four small squares (filled in the slot color when joined, dark gray when empty) and "2P".

### 2.4 Menus and focus

- A list of choices (results, pause, quit, settings) is a text menu, not a row of buttons. The focused item is
  `ACCENT` with a "▶" cursor in front of it (drawn as pixels, not a font glyph). Other items are `TEXT`. A destructive
  item ("END GAME", "QUIT") is `BAD` when it has focus. A choice never depends on color alone: the cursor shows focus.
- A game tile has a 6 px `TEXT_DIM` frame. The focused tile has a 6 px `ACCENT` frame, a "▶" before its title, and it
  grows to show the description (FD-7 stays).
- The default focus of a confirmation stays on the safe item (REQ-FL-10, REQ-FL-53).

### 2.5 Phone pad

- A and B are round arcade buttons with a 6 px white ring and a darker lower edge (the button looks pressed in when
  it is down). The colors are open question 6.
- RECENTER and LEAVE are framed text boxes. LEAVE still needs two taps (REQ-FL-52).
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

- FD-18 in `docs/TV_FLOW.md`, this plan, the mockups in `docs/design-system/arcade/`.
- Notes in the files that describe Party Pop, so that nobody builds new Party Pop work: `README.md`,
  `docs/REQUIREMENTS.md`, `docs/GAME_REQUIREMENTS.md`, `docs/design-system/README.md`, the `review` and
  `add-minigame` skills and the `design-reviewer` agent.

### Phase 1: arcade UI (TV menus, phone, game shell)

The menus and the shell change in the same pull request, so a game never shows an old pause menu next to new menus
(the same rule as REQ-FL-48).

1. Add `PressStart2P-Regular.ttf` and `OFL-PressStart2P.txt` to `assets/fonts/`. Import it with antialiasing off and
   no hinting. Remove Lilita One and Fredoka.
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
7. The Android splash color (REQ-FL-51) becomes black. The logo screen draws "REMOTE PLAY" in the arcade font until
   the logo file exists (FD-15, open question 5).
8. Requirements: replace REQ-FL-37 to 46, 41a, 52, 53, 56, 57 in `docs/TV_FLOW.md`; change REQ-P6 in
   `docs/REQUIREMENTS.md` (the font file); change REQ-GM-45, 46 in `docs/GAME_REQUIREMENTS.md` (chips and balls in the
   new style).
9. Design system: update `tokens.json` from the new `UiTheme`, run `tools/design_tokens_css.py`, and redo the
   component previews and READMEs in `docs/design-system/components/`.
10. Tests: the button contrast test (REQ-FL-53) becomes a menu item contrast test; the theme and shell tests follow
    the new values.
11. Manual test: a new device test for the arcade look (see section 5).

### Phase 2: pixel world trial (Sumo Bumpers)

1. A low-res game view in `minigame.gd`: the world draws into a 480x270 `SubViewport` with nearest filtering, and the
   shell draws on top at full resolution.
2. Restyle Sumo Bumpers (2D, simple shapes) with the pixel rules of section 2.7.
3. Set the exact tier 2 values in `docs/GAME_REQUIREMENTS.md` (they replace REQ-GM-47a to 47h and REQ-GM-48) after the
   trial. Make the tile again (`tools/make_tiles.gd`).

### Phase 3: 3D trial (Marble Race)

1. The low-res view in `minigame_3d.gd` (a 480x270 `SubViewport` for the camera, no antialiasing).
2. Restyle Marble Race: the outline meshes stay (REQ-GM-47c), the colors move to the world palette. Check that the
   marbles and the slot numbers stay readable, and the frame rate on the TV box (it should go up: fewer pixels).

### Phase 4: the other games

Tilt Maze, Paint Grab, Snowball Splat, one pull request each, with their tile. Their visual requirements change:
REQ-MZ-7, REQ-PG-15, REQ-SS-12, REQ-SB-15, REQ-MR-44.

## 4. Open questions for the owner

Each question has a default. Work on a phase continues with the default until the owner answers.

1. **Long text in a wide font.** Press Start 2P is wide: at 32 px about 11 characters fit in the description panel of a
   tile, and a game description has about 60. Options: (a) the description goes in a bar under the grid, (b) shorter
   descriptions, (c) a narrow second pixel font for long text only. Default: (a).
2. **Names the font cannot show** (Hebrew, emoji). Default: the Godot default font as a fallback for those characters.
3. **Arcade flourishes in the mockup**: "CREDIT 02" for the player count, "PLAYER SELECT" and "SELECT GAME" as titles,
   "1P" instead of "P1". Default: use them as in the mockup.
4. **Game resolution.** 480x270 (the default) keeps detail; 320x180 is chunkier and more "real 8-bit", but small
   objects get hard to see.
5. **Logo.** The owner makes the logo (FD-15). It must now read on black, and pixel art fits the style. Default: text
   logo in the arcade font until then.
6. **Phone A and B colors.** The mockup shows two red arcade buttons. The current rule is A green, B red (REQ-FL-52).
   Default: keep A green and B red.

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
