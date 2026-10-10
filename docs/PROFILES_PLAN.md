# Player profiles plan: names, avatars, personal bests, QR transfer (FD-22)

Status: **plan. Nothing is built.** The owner asked on 2026-10-10 for players who are recognized in every room, with their own name and avatar, and a best score that stays with them. This file records the decisions, the design, the changes to every document, and the phases. The owner confirms or changes the defaults in section 9 before phase A.
Style: ASD-STE100 Simplified Technical English, like the other requirements files. The requirement IDs in this plan (REQ-FL-73 to 82, REQ-GM-98 to 101, REQ-N8, REQ-C7 to C9) are proposed: they are given in the pull request of each phase.

## 1. Decision proposed (FD-22)

A **profile** lives on the phone. It has a random ID, a name, an avatar and the personal best scores of that player. The phone sends the ID, the name and the avatar when it joins a TV, so every TV and every room knows the player again. The TV stores nothing about profiles.

Decided by the owner on 2026-10-10 (this thread):

1. There is no server and no account (REQ-P5). A login with Google or another service is **not** planned now. It could be added later only as an optional backup of the profiles, and the profile ID stays the identity. Not part of this plan.
2. The phone does everything: a profile is made, changed, chosen and shared on the phone. The TV has no login, no keyboard entry and no profile screen.
3. One phone can hold several profiles (a parent with several children). One phone is one controller, so one profile plays at a time. The phone decides when to switch; the TV does not ask (REQ-FL-76).
4. A player with a profile is called by the profile name everywhere the TV and the phone now say "Player N", "2P" or "P2". A phone without a profile is a guest and keeps the number.
5. The avatar is picked from a sprite sheet of pixel avatars, and can be changed later. On the TV the avatar takes the place of the player number.
6. The best score of the player is kept in the profile on the phone. Every round counts.
7. A profile can be copied to another phone with a QR code, one profile at a time. The code contains the best scores.

What this plan does not do: no profile data on the TV (so no shared leaderboard on a TV), no sync between two phones after a copy, no protection against a changed app (a score on a phone is not proof of anything; this is a family game).

## 2. What the players see

### 2.1 On the phone

| Screen | Content |
|--------|---------|
| Connect screen | A new row at the top shows the active profile (avatar and name, or `GUEST`). A tap opens the profile list. A player who never made a profile sees `MAKE A PLAYER` once, in the same place. Nothing blocks joining. |
| Profile list ("WHO IS PLAYING?") | One row for each profile: the avatar and the name. A tap on a row makes it the active profile. A row `GUEST` plays without a profile. The buttons are `NEW PLAYER`, `SCAN A PLAYER` (see 2.3) and, on each row, `EDIT` and `SHARE`. The list is reached from the Connect screen and from the waiting screen. It cannot be opened while the TV is in the phase `playing`, `paused` or `waiting`. |
| Edit | The name field (1 to 16 letters, the keyboard of the phone), the avatar picker (a 4 x 4 grid, 16 avatars, the picked one has a frame), `SAVE`, `DELETE`. `DELETE` asks `DELETE <name>?` first. The avatar can be changed here at any time. |
| Share | A QR code of the profile, the text of the code with a `COPY CODE` button, and a line that says that everybody who scans it gets the best scores. The QR code goes away after 60 seconds (section 6.3). |
| Waiting screen and pad | The colored square at the top shows the avatar instead of the slot number. The text next to it shows the profile name (a guest sees `2P` as now). |

The texts are English and Hebrew (REQ-FL-54). Hebrew names are allowed (section 3.3).

### 2.2 On the TV

| Place | Today | With a profile |
|-------|-------|----------------|
| Players list (Connect screen, Players modal) | slot color square, `2P`, the name | the square holds the avatar, then the profile name |
| Ball or marble of a player in a game (`Shell.ball()`, REQ-GM-46) | the slot number on the ball | the avatar on the ball |
| Result menu and the ranking (REQ-GM-72) | `1st  Player 2  12` | `1st  Maya  12` |
| Pause card (REQ-GM-30) | `2P LOST CONNECTION`, `Resume without P2`, `P2 reconnected` | `MAYA LOST CONNECTION`, `Resume without Maya`, `Maya reconnected` |
| Name tags in the countdown (REQ-GM-46a) | the name | the name (no change: there is no number there) |
| Leader chip (REQ-GM-46) | the name and the score | no change: there is no number in it |
| Debug overlay | `P2` | no change (it is a developer tool) |

A guest keeps the slot number and the name `Player N`. Two players with the same name on one TV get a number after the second name (`Sam`, `Sam 2`), see section 4.3.

### 2.3 Copy a profile to another phone

1. On the first phone: profile list, `SHARE` on the row. The QR code shows.
2. On the second phone: profile list, `SCAN A PLAYER`. The camera scans the code and the profile is made, with the same ID, name, avatar and best scores.
3. A phone that cannot scan (an iPhone has no scanner plugin yet, RISKS A2) uses `COPY CODE` on the first phone and `PASTE A CODE` on the second one.

The result is a **copy**, not a move. If the second phone already has a profile with the same ID, the two are merged: the name and avatar of the code win, and each best score is the better one of the two (section 5.4). After the copy the two phones do not sync.

## 3. The profile

### 3.1 Fields

| Field | Type | Rule |
|-------|------|------|
| `id` | 16 random bytes, written as 32 hex characters | Made once with `Crypto.generate_random_bytes(16)`. Never changes. It is the identity of the player. |
| `name` | text, 1 to 16 characters | Same limit as the TV uses now (`tv_server.gd`). Trimmed. |
| `avatar` | integer, 0 to 15 | The index in the sprite sheet (section 7). An index the app does not know is shown as the number (a future sheet can add avatars; it never changes or removes one). |
| `bests` | map of best key to integer | Section 5. Empty at the start. |

The phone also saves the ID of the **active** profile, or none for a guest.

### 3.2 Storage

`user://profiles.cfg` on the phone (a `ConfigFile`, like `controller.cfg`), written at once after each change (create, edit, delete, a new best, an import). The limit is **8 profiles** on one phone (`NEW PLAYER` and `SCAN A PLAYER` are dim when the list is full; a scan of a code for an existing ID is still allowed, because it merges). A reinstall or "clear data" deletes the profiles. Only a copy made before can bring them back. The Share screen says this in one line.

### 3.3 Names

The pixel fonts draw only some characters (REQ-FL-39). The name field accepts letters of the Latin and Hebrew ranges the two fonts have, digits and the space. Any other character is dropped as it is typed. A name that is empty after this is not saved.

## 4. Protocol (`docs/PROTOCOL.md`)

The protocol `VERSION` stays 2: every new field and message is optional, and an old TV or an old phone ignores it (the same rule as `lang` and `score`). Use the `change-protocol` skill.

### 4.1 Join

`hello` gets two optional fields:

```json
{"t":"hello","v":2,"room":"KQZM","token":"","name":"Maya","pid":"9f2c...32 hex...","av":3}
```

`pid` is the profile ID, `av` the avatar index. A phone without a profile sends neither, and the TV treats it as a guest (`name` empty or the old value, "Player N"). The TV rejects a `pid` that is not 32 hex characters by ignoring it (guest), not with a `reject`.

### 4.2 Change of profile

```json
{"t":"profile","pid":"…","name":"Noam","av":7}      // or {"t":"profile"} for a guest
```

Phone to TV. The TV accepts it only in the phases `connect` and `menu`, and ignores it in `playing`, `paused` and `waiting` (the phone does not offer the list then, so this is a second guard). The slot, the token and the color do not change. The TV updates the player and redraws the lists. The same checks as in 4.1 apply.

### 4.3 Names on the TV

`PlayerInput` gets `profile_id`, `avatar` and a `display_name`. The TV computes `display_name` from the profile name, and adds ` 2`, ` 3` to a name that is already used by a player of a lower slot. For a guest it is `Player N` as now. Every TV text uses `display_name`. The raw name is kept for the result list of a finished round, so a name does not change in the middle of a screen.

### 4.4 Same profile on two phones

If a `hello` brings a `pid` that is already present in **another** slot, the newer phone wins: the TV frees the older slot as with `kicked` (the older phone forgets its token and goes to its connect screen). The reason is that one profile is one player; the usual case is the owner who moved to a second phone. A phone that reconnects with its token is not affected (the token is checked first, as now).

### 4.5 Round results and personal bests

When a round ends, the TV sends each phone that took part and has a `pid` one message:

```json
{"t":"result","key":"snowball_splat|medium","v":340,"better":"high"}
```

`key` is the best key of the game (section 5.1), `v` the score of that player as a number, `better` is `high` or `low`. The phone updates its profile if `v` is better and answers nothing. A guest phone gets no message. A phone that is lost at the end of the round does not get it, and the score is not saved (the TV does not keep it).

## 5. Personal bests

### 5.1 What a game says

`Minigame` gets one function, `best_key() -> String`. The default is the game ID and the difficulty (REQ-GM-91): `maze|easy`. A game adds a variant when the score depends on it: Marble Race adds the track number (`marble_race|medium|3`). A game with no personal score returns an empty text and no `result` is sent. Sumo Bumpers returns an empty text (its result is a win, not a number). A random track of Marble Race has no key.

| Game | Key | Better |
|------|-----|--------|
| Tilt Maze | `maze|<difficulty>` | lower (time) |
| Marble Race | `marble_race|<difficulty>|<track 1 to 10>` | lower (time) |
| Snowball Splat | `snowball_splat|<difficulty>` | higher |
| Paint Grab | `paint_grab|<difficulty>` | higher (percent of the floor) |
| Sumo Bumpers | none | |

### 5.2 What counts

Every round counts (owner, 2026-10-10), also with 2 to 4 players. `open_results()` is the one place that ends a round with scores (REQ-GM-72), so it sends the messages. Only a player who **finished** with a score gets one ("not finished" and a score of 0 in a higher-is-better game send nothing). The score is the number of the `Scoreboard`, not the text. A restart is a new round. A round that ends with "No players connected" sends nothing.

### 5.3 Stored value

An integer in thousandths (a time of 12.345 s is 12345; a score of 340 is 340000), so the smallest and the largest value use the same code. The phone keeps one integer for each key.

### 5.4 Merge on import

For each key the better value wins (the rule of 5.1). A key that is in one profile only is kept.

### 5.5 What the player sees

The phone shows `NEW BEST!` on the waiting screen after a round that set a new best, with the old best in small text. Nothing changes on the TV: the result menu stays as it is (open question 9.5).

## 6. Sharing by QR code

### 6.1 Code format

The text of the QR code is `WP1.` followed by base64url text (no padding) of this binary data:

| Bytes | Field |
|-------|-------|
| 1 | Format version, 1 |
| 16 | Profile ID |
| 1 | Avatar |
| 1 + n | Name: length n (0 to 32 bytes, UTF-8), then the bytes |
| 1 | Number of bests, k |
| k times | Best key number (1 byte, from the table `ProfileKeys`), then the value as a varint (up to 5 bytes) |
| 2 | Checksum (CRC-16) of all the bytes before it |

`ProfileKeys` is a fixed table in code: the key text and its number, 1 to 39 (3 games with 3 difficulties = 9 keys; Marble Race 3 difficulties x 10 tracks = 30 keys). A number is never reused or changed; a new game adds numbers at the end. A code with a key number the app does not know is read, and that key is skipped. A code with another format version, a wrong checksum or a truncated body is rejected with `THIS CODE DOES NOT WORK`. The prefix `WP1.` tells the scanner that this is not a TV link (`ws://`), so the Connect screen scan and the profile scan give the right message when the wrong code is scanned.

### 6.2 Size and the QR encoder

The largest profile is 52 bytes plus 39 bests of up to 6 bytes plus 2: about 290 bytes, or about 390 characters of text. A normal profile with a few bests is about 80 bytes, 110 characters. `scripts/core/qr_encoder.gd` now stops at version 6 (134 bytes). Phase C extends it to **version 14, error correction L** (458 bytes): more block layouts, the alignment pattern positions and the version information that versions 7 and higher need. The TV link keeps using the small versions. The size of the modules on the phone screen is chosen so that a version 14 code is at least 6 screen pixels per module (the screen is 1080 wide, the code is 73 modules). There is no QR decoder in the repository, so the encoder is checked by (a) structure tests (size, finder and timing patterns, format and version bits, the capacity table) and (b) a one-time check with an outside decoder that is not added to the repository, and (c) manual test 20.

### 6.3 Safety

A profile code gives anybody who scans it the player. This is acceptable because the TV already trusts what the phone says. The Share screen opens only after a tap on `SHARE`, hides the code after 60 seconds, and never shows it on the TV.

### 6.4 Scanning

The phone scanner is the existing Google code scanner plugin (`qr_scanner.gd`); no plugin change. An iPhone has no scanner now (RISKS A2), so the paste code is the way there.

## 7. Avatar sprite sheet

- File: `assets/avatars/avatars.png`, 64 x 64 px, 16 cells of 16 x 16 px in a 4 x 4 grid, transparent background, the colors of the NES palette of `UiTheme` (REQ-FL-37), a 1 px dark outline on each avatar, no antialiasing. The index is row by row from the top left.
- 16 friendly characters that a child of 5 years knows at once and that are different in their shape, not only in their color (animals and a robot, an alien, a ghost, a star). The first version is drawn by Claude with a script that is kept in the project files, as for the logo; the owner changes the list if a picture does not work.
- Rule: the avatar is drawn at a whole-number scale with the nearest filter, in the place of the number, centered in the colored square. It must be readable on all four slot colors and from the sofa. The size on the screen of each place (the ball, the list square, the phone square) is decided when it is built, and the manual test checks it.
- REQ-P6 gets the new allowed file. The file is imported without a filter and without mipmaps, like the logo. A license line in `assets/avatars/README.md` says that the art is made for the project.
- Both apps load the same sheet. The index stays valid for ever (section 3.1).

## 8. Phases

One pull request for each phase, stacked, with the code, the tests, the documents and the manual test in the same pull request (REQ-GM-5, REQ-GM-62). A pull request is made only when the owner asks.

| Phase | Content | Manual test |
|-------|---------|-------------|
| A. Profiles and names | `Profile` and `ProfileStore` (new modules), the avatar sheet and the `Avatar` drawing, the phone screens (list, edit, avatar picker, switch), `hello` and `profile`, the TV `display_name`, avatars instead of numbers, names in the pause card, the result menu and the lists, the duplicate ID rule. Documents of section 10 for these parts. | Test 20 items 1 to 8 |
| B. Personal bests | `ProfileKeys`, `best_key()` in `Minigame` and in four games, the `result` message, the update and merge rules, `NEW BEST!` on the phone. The requirements file of each game. | Test 20 items 9 to 11 |
| C. Share by QR | The QR encoder up to version 14, the code format, `SHARE`, `SCAN A PLAYER`, `COPY CODE`, `PASTE A CODE`, the import and merge. | Test 20 items 12 to 15 |

Phase A is useful alone: it already gives the recognized players with names and avatars. Phase B needs A. Phase C needs A and B, because the code carries the bests.

## 9. Defaults chosen for open questions (the owner confirms)

1. **8 profiles** on one phone, and a `GUEST` row. A limit keeps the list on one screen.
2. A profile ID on two phones at one TV: **the newer phone wins** (section 4.4).
3. The profile list **cannot be opened during a round**; a phone switches between rounds only.
4. A **random track** in Marble Race and a **Sumo Bumpers** round have no personal best.
5. `NEW BEST!` shows on the **phone only**. The TV result menu does not change. (This changes what the TV shows, so the owner decides: for example a `NEW BEST` tag on the row of the result list.)
6. Deleting a profile on the phone does not tell any TV. A profile in a running round is not deletable (the list is closed).
7. The avatar is **not** drawn on the leader chip or on the name tags, because those places have no number now.
8. 16 avatars, 4 x 4.

## 10. Documents that change

The documents are as important as the code (REQ-GM-5). Each item is done in the pull request of its phase, in the same commit as the behavior.

| Document | Change | Phase |
|----------|--------|-------|
| `docs/TV_FLOW.md` | FD-22 in the decisions table. A section "Profiles" with REQ-FL-73 to 82: the phone screens, the list, the edit and delete rules, the guest, the name rules, the avatar in the numbers' place, `display_name`, the duplicate name, the duplicate ID, the switch rule, the share screen. Change REQ-FL-32 and 33 (Players modal shows name and avatar). Two rows of the decision table are both numbered FD-21 (the leader chip and the name Wobble): this plan keeps both as they are and numbers its decision FD-22; the owner decides whether the second FD-21 is renumbered. | A, C |
| `docs/PROTOCOL.md` | `hello` fields `pid`, `av`; the messages `profile` and `result`; the duplicate ID rule in "Slots, loss and reconnect"; the text "Resume without P2" becomes the name rule; the QR payload `WP1.` in a new section; `VERSION` stays 2 and why. | A, B, C |
| `docs/REQUIREMENTS.md` | REQ-P5: say that profiles are on the phone only and that there is no account. REQ-P6: the allowed file `assets/avatars`. REQ-N7 stays. New REQ-N8 (profile fields in `hello`) and REQ-C7 to C9 (profiles on the phone, local storage, switch rule). REQ-T5: the pause card names the players. | A |
| `docs/GAME_REQUIREMENTS.md` | REQ-GM-30 and 30a (names in the pause card), REQ-GM-46 (avatar in the place of the number on a ball), REQ-GM-72 (names in the result list), REQ-GM-73 (medals stay; personal best is separate). New REQ-GM-98 to 101: `best_key()`, what counts, the messages, no best for a game with no key. `scripts/game/medals.gd` comment "Nothing is saved: the player is not identified yet" is corrected. | A, B |
| `docs/games/TEMPLATE.md` and the five game files | The template gets the line "Personal best (REQ-GM-98): key and direction". `maze.md`, `marble_race.md`, `snowball_splat.md`, `paint_grab.md` get a row with the key. `sumo_bumpers.md` gets an exception row. The pause card rows that say `2P` or `P2` are updated. | A, B |
| `docs/MANUAL_TESTS.md` | New test 20 (section 11), the Summary table row, the list of covered requirements. Tests 7 and 19: the pause card and the name tags are re-read with profile names (a note, not a result). | A, B, C |
| `CLAUDE.md` | The table "Tests the user has to run now": a row for test 20. | A |
| `docs/GAMES_ROADMAP.md` | The shared code table gets `Minigame.best_key()` and `Avatar`. | B |
| `.claude/skills/add-minigame/SKILL.md` | A step: decide the best key, or return an empty text and write the exception. | B |
| `.claude/skills/change-protocol/SKILL.md` | Check that its list of messages is still right; add `profile` and `result` if the skill lists the messages. | A |
| `docs/RISKS.md` | New risks: a dense QR code may scan badly (version 14), an avatar may be unclear at the size of the number, a name with a character the font lacks, one profile on two phones, a reinstall deletes the profiles, an iPhone cannot scan. | A, C |
| `docs/EXPORT.md` | One line: `assets/avatars` is in the export of both apps (the presets export all resources; check it in phase A). | A |
| `README.md` | The feature list gets profiles; the docs index gets this file. | A |
| `docs/PROFILES_PLAN.md` (this file) | Status line and a "what was built, what differs" section at the end of each phase, as in `docs/AUDIO_PLAN.md`. | each |
| `scripts/core/strings.gd` | English and Hebrew texts for every new screen and button; `tests/smoke_lang.gd` fails when one is missing. The Hebrew text is written by Claude and checked by a native reader (manual test 17 style). | A, B, C |

## 11. Tests

### 11.1 Automatic

All new suites are added to `tests/suites.txt` only. Every new module needs 80% line coverage (CLAUDE.md). The tests check behavior, not lines.

| Suite | What it checks |
|-------|----------------|
| `tests/profiles.gd` (controller role) | Make, rename, change the avatar, delete; the limit of 8; the name rules (16 characters, Hebrew, characters the font lacks are dropped, empty is refused); write and read back `profiles.cfg`; the active profile and the guest; the random ID is 32 hex characters and two IDs differ. |
| same | Bests: a lower time is better, a higher score is better, a score of 0 and "not finished" are ignored, the integer in thousandths, the merge rule. |
| same | Code: encode and decode of a profile give the same profile; a Hebrew name of 16 letters; 39 bests; a wrong checksum, a truncated code, another version, a wrong prefix are rejected; an unknown key number is skipped; golden test: a fixed profile gives a fixed text (protects `ProfileKeys`). |
| `tests/net_profiles.gd` (controller role, real sockets like `net_loss.gd`) | `hello` with `pid` and `av` fills the player; an old `hello` without them is a guest; a bad `pid` is a guest; `profile` changes name and avatar in `connect` and `menu` and is ignored in `playing`; the duplicate ID rule frees the older slot and a token resume does not; two equal names give `Sam` and `Sam 2`; `result` reaches only a phone with a `pid`. |
| `tests/game_rules.gd` | `open_results()` sends one `result` for each finished player with the key of the game; Sumo and a random track send none. |
| `tests/ui_states.gd` | The profile list, the edit screen (a name is needed to save, `DELETE` asks first, the full list dims `NEW PLAYER`), the Share screen and its 60-second hide, the waiting screen shows the avatar. |
| `tests/smoke_tv.gd`, `smoke_lang.gd` | The pause card, the result list and the players list show the profile name; every new string has Hebrew. |
| QR encoder (in `run_tests.gd`) | Versions 7 to 14: size, finder, timing and alignment patterns, format and version bits, the capacity for each version, a text that is too long returns empty; versions 1 to 6 give the same modules as before. |

`gdlint` is clean and `tools/coverage.sh` reports every module at 80% or more before a pull request (CLAUDE.md). The UI modules are covered by the UI tests above; none is set aside in `tools/coverage/exclusions.txt`.

### 11.2 Manual: test 20 (new, "Not run")

Needs: 2 to 4 phones (one an iPhone if possible), 1 TV, a grown-up and a child of about 5 to 8 years. It covers REQ-FL-73 to 82, REQ-GM-98 to 101, REQ-N8, REQ-C7 to C9, FD-22. Items:

1. Make a profile on a phone: name, avatar; join a TV. Check: the TV shows the name and the avatar in the Players list, on the ball in each game, in the result list; no "Player N".
2. Change the avatar and the name, join again; check the TV.
3. A parent phone with 3 profiles: switch between rounds; check that the TV shows the new name and avatar, and that the list does not open during a round.
4. Two phones with the same name: the TV shows `Sam` and `Sam 2`.
5. A guest next to profile players: the guest keeps the number.
6. Pause card with a profile name (switch Wi-Fi off): the texts with the name; Hebrew name of 16 letters; check that the text fits.
7. All avatars on all four slot colors, from the sofa, and a child names five of them.
8. The same profile on a second phone joins the same TV: the older phone returns to its connect screen.
9. Play each of the four games with a profile; check `NEW BEST!` and that a worse round does not change the best; one round with 2 phones.
10. Close the app and open it: the profiles and bests are still there. Join another TV: the same name and avatar.
11. Sumo Bumpers and a random Marble Race track: no best.
12. Share a profile with 20 bests to a second phone by QR: the same name, avatar and bests; time how long the scan takes; try it from 30 cm and from 60 cm.
13. Import a profile that the second phone already has, with better bests on each side: the better ones stay.
14. An iPhone: `COPY CODE` on one phone and `PASTE A CODE` on the iPhone.
15. A broken code (one letter changed) and a TV link: the right messages.

## 12. Risks

| Risk | Plan |
|------|------|
| A QR code of version 14 is too dense for a phone screen scan | Item 12 measures it. If it fails, phase C limits the bests in the code to the 20 most recent, and says so in the Share screen (the owner decides first), or splits the code. |
| No decoder in the repository to check the new encoder | Structure tests, one outside decoder check by Claude, then the manual test. |
| An avatar is unclear at the size of a ball digit | Item 7. The size of each place is set in phase A and can change. |
| A reinstall deletes the profiles | The Share screen says it. A login backup is a later option (section 1). |
| The pid is a stable identifier sent in clear text on the LAN | It is a random number with no link to a real person. The app has no internet part (REQ-P5). |
