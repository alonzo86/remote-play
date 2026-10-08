Remote Play is a couch game for Android TV with phones as motion controllers. The look is **Party Pop**: chunky, saturated and sticker-like. The TV and the phone share it.

## Content fundamentals
- Short, friendly, plain sentences for people on a sofa: "Ready!", "waiting", "Press OK to continue without them", "Choose a game on the TV". No jargon, no emoji, no exclamation marks except "Ready!".
- Titles are Title Case or short caps (REMOTE PLAY, Marble Race). Player names fall back to "Player 1" to "Player 4". Counts read "1 player", "2 players", "1-4 players".
- A failing state always says why in words ("lost", the reason a game cannot start); never color alone.

## Visual foundations
- **Color.** Every screen sits on plain `bg` purple, no dots or bubbles. Info bars use `bg-dark`. Text on purple is `text`, secondary `text-dim`, titles and numbers `accent`. White `card` surfaces carry `card-text`, secondary `card-dim`. The room code is `room` pink. Player colors `player-1`..`player-4` always appear with the slot number.
- **Type.** Titles in Lilita One (`title` 76px, `modal-title` 54px, logo 170px), everything else in Fredoka medium or semibold (`body`, `button`, `label`). Sizes are 1080p TV pixels. On a TV, titles and game names are at least 28px, help text at least 22px; text on purple holds 4.5:1.
- **Shape.** Every card, slot, badge and button has a 6px `outline` border, `radius-lg` (26px) corners, and the hard `shadow-hard` (6px right and down, no blur, never a gradient). Pills and the gear are fully round (`radius-pill`).
- **Buttons.** Default buttons are `button` purple with white text, never white. The one main action is `accent` yellow with `card-text`. Back is the quiet `bg-dark` button with a dimmed outline, set apart from the options. Disabled is flat `disabled`, no shadow.
- **Focus.** Focus and hover are a 10px `accent` outline; a focused tile gets a yellow title. Focus never changes size or moves layout. No focus outline is white. A focused tile bounces once (~150 ms, scale 1.04); a joining slot pops 1.05.
- **Spacing.** Cards pad 14px by 32px, modals 44px; modal body gap `space-22`; keep the TV `safe-area` of 60px.
- **Motion.** Short fades or slides up to 250 ms, a back-ease logo entrance, one confetti burst (`confetti-pink`, `confetti-cyan`, `accent`). No shaders, motion stops while paused.
- **Modals.** A white card over a 72% `outline` dim layer.
- **Games.** Draw worlds with shapes. Backgrounds come from `bg` or the `world-*` set and keep the key objects brightest (3:1 against the ground).

## Iconography
No icon font. Icons are drawn in code from shapes (the gear is eight lines and two circles, the players badge four dots). The app icon is a yellow phone on `brand-dark` (`assets/Icons`). The logo file `assets/logo/logo.png` does not exist yet, so the screen sets REMOTE PLAY in Lilita One with an 18px outline.

## About this folder
A copy of the Remote Play design system, extracted from `scripts/ui/ui_theme.gd`, `scripts/ui/ui_kit.gd` and `docs/TV_FLOW.md` (Party Pop, FD-13). The code stays the source of truth: change `UiTheme` first, then update `tokens.json`. Fonts live in `assets/fonts` and screenshots in `assets/tiles`; the previews in `components/` are static HTML renditions of the Godot widgets (1080p pixels), and `GameTile` reads its screenshots from the published artifact.
