Sababi is a couch game for Android TV with phones as motion controllers. The look is the **8-bit cabinet** (FD-18): a black screen, one blocky pixel font, a small fixed palette, square double frames, text menus with a pixel cursor and blinking prompts. The TV and the phone share it. The mockups that the owner chose from were removed on 2026-10-16 (the games look different now); the plan is in `docs/ARCADE_STYLE_PLAN.md`. The menus, the phone and the game shell use it since phase 1; the game worlds follow in phases 2 to 4.

## Content fundamentals
- Short, plain sentences for people on a sofa, all in upper case: "PRESS OK TO CONTINUE", "RESUME WITHOUT 2P", "CHOOSE A GAME ON THE TV". No jargon, no emoji. Counts read "1 PLAYER", "1-4 PLAYERS"; the slots are "1P" to "4P" and the Connect screen shows "CREDIT 02" for the phones that have joined.
- A failing state always says why in words ("LOST", the reason a game cannot start); never color alone.

## Visual foundations
- **Color.** Every screen sits on plain `bg` black. Text is `text`, secondary `text-dim`, titles, the room code and the focused item `accent`. `frame` blue is a line, never text. `ok` is READY and the A button, `bad` is LOST, errors and the B button. Player colors `player-1`..`player-4` are a square next to the slot number. Every text color holds 4.5:1 on black.
- **Type.** One font, Press Start 2P, with Sababi Pixel Hebrew as the fallback for Hebrew names. Sizes are multiples of 8 on the 1080p TV: body and hints 32px, menu items and slots 40px, modal titles 48px, titles 64px, logo text 96px, countdown 256px. Text smoothing and hinting are off, so the pixels stay sharp.
- **Shape.** Square corners, no shadow, no outline around buttons. A panel has a double frame (6px `text`, 6px black, 6px `frame`). A box has one 6px line.
- **Menus and focus.** A list of choices is a text menu. The focused item is `accent` with a cursor drawn as pixels in front of it; a destructive item is `bad` with the focus. A focused tile has an `accent` frame and a cursor before its title; its description is in a bar under the grid.
- **Spacing.** Frames pad 24px or more; keep the TV `safe-area` of 60px.
- **Motion.** Hard steps, no fades: prompts blink (0.55s on, 0.55s off), the logo drops in in steps, the confetti is square, the countdown settles in 4 steps. Motion stops while paused. No shaders.
- **Games.** The shell (HUD, chips, timer, countdown, hints, menus) follows this style now. A pixel world is drawn in a 480x270 view that is scaled up with nearest filtering (one world pixel is 4x4 screen pixels), with a one-pixel black outline on key objects, and the HUD and the slot numbers at full resolution on top (REQ-GM-47i to 47n). All game worlds are pixel worlds (Sumo Bumpers, Road Rally, Treasure Maze, Paint Grab, Banana Party, Galaxy Protector). The toy-like tier 2 rules (REQ-GM-47a to 47h) stay in `docs/GAME_REQUIREMENTS.md` only as the rules of 3D meshes (47c, 47g, 47h) and for history.

## Iconography
No icon font. Everything is drawn in code from rectangles and the pixel font (the cursor is four columns of pixels, the players badge four squares). The mascot is a yellow pixel face with sunglasses. The app icon is the mascot on black (`assets/icons`). The logo file `assets/logo/logo.png` has the mascot and the word SABABI; the screen sets SABABI in the pixel font when the file is missing.

## About this folder
A copy of the Sababi design system, extracted from `scripts/ui/ui_theme.gd`, `scripts/ui/ui_kit.gd` and `docs/TV_FLOW.md` (FD-18). The code stays the source of truth: change `UiTheme` first, then update `tokens.json`. Fonts live in `assets/fonts` and screenshots in `assets/tiles`; the previews in `components/` are static HTML renditions of the Godot widgets (1080p pixels), and `tokens.css` is generated from `tokens.json`: run `tools/design_tokens_css.py` after you change a token (`--check` fails when it is out of date; `tests/run_all.sh` runs it).
