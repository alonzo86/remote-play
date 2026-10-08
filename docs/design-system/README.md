Remote Play is a couch game for Android TV with phones as motion controllers. The look is **Party Pop**: chunky, saturated and sticker-like. The TV and the phone share it.

## Content fundamentals
- Short, friendly, plain sentences for people on a sofa: "Ready!", "waiting", "Press OK to continue without them", "Choose a game on the TV". No jargon, no emoji, no exclamation marks except "Ready!".
- Titles are Title Case or short caps (REMOTE PLAY, Marble Race). Player names fall back to "Player 1" to "Player 4". Counts read "1 player", "2 players", "1-4 players".
- A failing state always says why in words ("Lost", the reason a game cannot start); never color alone.

## Visual foundations
- **Color.** Every screen sits on plain `bg` purple, no dots or bubbles. Dark panels use `bg-dark`. Text on purple is `text`, secondary `text-dim`, titles and numbers `accent`. White `card` surfaces carry `card-text`, secondary `card-dim`. The room code is `room` pink. Player colors `player-1`..`player-4` always appear with the slot number.
- **Type.** Titles in Lilita One (`title` 76px, `modal-title` 54px, logo 170px), everything else in Fredoka medium or semibold (`body`, `button`, `label`). Sizes are 1080p TV pixels. On a TV all text is at least 28px (titles, game names and help text); text on purple holds 4.5:1.
- **Shape.** Every card, slot, badge and button has a 6px `outline` border, `radius-lg` (26px) corners, and the hard `shadow-hard` (6px right and down, no blur, never a gradient). Pills and the gear are fully round (`radius-pill`).
- **Buttons.** Three colors with a hard shadow: yellow `accent` (default), green `ok` (the main action), red `danger` (destroys something, white text, with a ✕). Focus is a 10px black `focus-border` and a lift. Pressed sinks onto the shadow. Back is the quiet `bg-dark` button. Disabled is flat opaque gray, no shadow.
- **Focus.** A focused button has a 10px black `focus-border` and a longer shadow (it lifts). A focused tile grows to the right to show the game description and gets a yellow title, with no border change (a Netflix menu, 180 ms). Focus never moves the layout of buttons. A joining slot pops 1.05.
- **Spacing.** Cards pad 14px by 32px, modals 44px; modal body gap `space-22`; keep the TV `safe-area` of 60px.
- **Motion.** Short fades or slides up to 250 ms, a back-ease logo entrance, one confetti burst (`confetti-pink`, `confetti-cyan`, `accent`). No shaders, motion stops while paused.
- **Modals.** A white card over a 72% `outline` dim layer.
- **Games.** Draw worlds with shapes. Backgrounds come from `bg` or the `world-*` set and keep the key objects brightest (3:1 against the ground).

## Iconography
No icon font. Icons are drawn in code from shapes (the gear is eight lines and two circles, the players badge four dots). The app icon is a yellow phone on `brand-dark` (`assets/Icons`). The logo file `assets/logo/logo.png` does not exist yet, so the screen sets REMOTE PLAY in Lilita One with an 18px outline.

## About this folder
A copy of the Remote Play design system, extracted from `scripts/ui/ui_theme.gd`, `scripts/ui/ui_kit.gd` and `docs/TV_FLOW.md` (Party Pop, FD-13). The code stays the source of truth: change `UiTheme` first, then update `tokens.json`. Fonts live in `assets/fonts` and screenshots in `assets/tiles`; the previews in `components/` are static HTML renditions of the Godot widgets (1080p pixels), and `tokens.css` is generated from `tokens.json`: run `tools/design_tokens_css.py` after you change a token (`--check` fails when it is out of date; `tests/run_all.sh` runs it).
