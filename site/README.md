# Sababi website

The pages of https://alonzo86.github.io/remote-play/ (GitHub Pages, deployed from this folder by `.github/workflows/pages.yml`).

| Page | What it is |
|------|------------|
| `index.html`, `he/index.html` | Home (English, Hebrew right to left) with the section "Get the phone app" and the store buttons |
| `get/index.html` | The page that the QR code "GET THE PHONE APP TO PLAY" of the TV opens (`About.APP_URL`). A phone goes straight to its own store when the address is filled in |
| `privacy.html`, `terms.html`, `licenses.html` (and `he/`) | Placeholders ("Coming soon"). The final texts come from `docs/legal` when the owner approves them (issue #37) |
| `stores.js` | The two store addresses. Empty means "Coming soon". Fill them in when the app has its store pages |
| `style.css` | The look, with the colors of the design tokens (`docs/design-system/tokens.css`) |

Rules:
- The address of `get/` is drawn by every installed TV app (`scripts/core/about.gd`, `APP_URL`): never move it. Change where it sends people in `stores.js`.
- The store badges (Google Play, App Store) are trademarked artwork: use only the official files and follow the brand rules of the stores, and add them to `docs/THIRD_PARTY.md` first.
- The privacy notice, the terms and the store texts are owner only (CLAUDE.md).
- To see it: `cd site && python3 -m http.server 8000`.
