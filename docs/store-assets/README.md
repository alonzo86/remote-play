# Store assets

Images for the store listings. The owner approved the English set on 2026-11-07 (issue #384). The store **texts** are in
`docs/legal/store-listing-draft.md` (owner only); this folder has the images only.

## Google Play (English only for now)

| File | Size | Use |
|------|------|-----|
| `google-play/icon_512.png` | 512x512 | App icon of the listing. It is `assets/icons/icon_1024.png` scaled down by 2 (nearest neighbour, so the pixels stay sharp). Fully opaque, no rounded corners: the store masks it. |
| `google-play/feature_graphic_1024x500.png` | 1024x500 | Feature graphic. Made from the game tiles (`assets/tiles/`), the logo and the Press Start 2P font (see `docs/THIRD_PARTY.md`). |
| `google-play/tv/0_logo.png` .. `9_bowling.png` | 1920x1080 | TV screenshots, in the order of the file names. |
| `google-play/phone/1_choose_game_on_tv.png`, `2_pad_a_b.png` | 1080x1920 | Phone screenshots. |

The TV and phone screenshots are captures of the real apps (headless Godot with a software GL driver), with the player names
"Player 1" and "Player 2" and the room code of a local test. The phone screens show no debug overlay and no RECENTER button.

The home page of the website shows these screenshots at half size (`site/screens/`, see `site/README.md`). Capture a screenshot again: make its copy there again.

## Rules

- No Hebrew set yet. Phone Hebrew texts of two or more lines are drawn too close together (issue #403): fix it, then capture the
  Hebrew set (the same screens).
- A screenshot shows the app as it is. When a screen that is in a screenshot changes (a text, a button, a color), capture it again.
  The game name on a screenshot must be the name of the game in the app (for example "MOLE BONK", not the old "WHACK-A-MOLE").
- No image of another maker may be added without a row in `docs/THIRD_PARTY.md` (CLAUDE.md, "Third-party libraries and resources").
- The privacy notice and the store texts are owner only. The file sizes and the pixel sizes above are the store's rules as
  the project knew them on 2026-11-07; check the store's current rules before the upload (issue #384).
