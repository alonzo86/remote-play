# Sababi website

The pages of https://alonzo86.github.io/remote-play/ (GitHub Pages, deployed from this folder by `.github/workflows/pages.yml`).

| Page | What it is |
|------|------------|
| `index.html`, `he/index.html` | Home (English, Hebrew right to left) with the section "Get the phone app" and the store buttons |
| `get/index.html` | The page that the QR code "GET THE PHONE APP TO PLAY" of the TV opens (`About.APP_URL`). A phone goes straight to its own store when the address is filled in |
| `privacy.html`, `terms.html` (and `he/`) | **Generated** from `docs/legal/privacy-notice*.md` and `terms*.md` by `tools/make_legal_pages.py` (run it after a change of the texts; `tests/legal_pages.gd` fails when a page is out of date). They show the text as it is, so they say "Draft, not published" until the owner removes that line from the Markdown texts. Not published: GitHub Pages is off until the owner turns it on (issue #37) |
| `licenses.html` (and `he/`) | Placeholder ("Coming soon"). The text comes from `docs/THIRD_PARTY.md` when the owner asks for it (issue #37) |
| `lang.js`, `flags/us.svg`, `flags/il.svg` | The language menu of the header (a `<details class="lang">` in every page, English and עברית, each with a flag; owner request of 2026-11-09, issue #37). It works without JavaScript; `lang.js` closes it on a click outside, on Escape and after a choice. The two flags are simple SVG drawings made for this project (no third-party artwork). To add a language: one more `<li>` in the menu of every page and one more flag file; `tests/site_language.gd` checks the 8 pages |
| `stores.js` | The three store addresses (phone app on Google Play and the App Store, TV app on Google Play; the home page has a section for each app). Empty means "Coming soon". Fill them in when the app has its store pages |
| `style.css` | The look, with the colors of the design tokens (`docs/design-system/tokens.css`) |

Rules:
- The address of `get/` is drawn by every installed TV app (`scripts/core/about.gd`, `APP_URL`): never move it. Change where it sends people in `stores.js`.
- The store badges (Google Play, App Store) are trademarked artwork: use only the official files and follow the brand rules of the stores, and add them to `docs/THIRD_PARTY.md` first.
- The privacy notice, the terms and the store texts are owner only (CLAUDE.md). Edit `docs/legal/*.md`, never the generated pages by hand.
- To see it: `cd site && python3 -m http.server 8000`.
