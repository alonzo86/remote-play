# Player profiles plan: names, avatars, QR transfer, personal bests (FD-22)

Status: **plan, reviewed once by an independent critic on 2026-10-10 (section 13). All three phases are built (A: profiles and names, B: copy by QR, C: personal bests).** The owner asked on 2026-10-10 for players who are recognized in every room, with their own name and avatar, and a best score that stays with them. This file records the decisions, the design, the changes to every document, and the phases. The owner confirms or changes the defaults in section 9 before phase A.
Style: ASD-STE100 Simplified Technical English, like the other requirements files. The requirement IDs in this plan (REQ-FL-69 to 78, REQ-GM-98 to 101, REQ-N8, REQ-C7 to C9) are in the requirements files now (all phases are built).

## 1. Decision proposed (FD-22)

A **profile** lives on the phone. It has a random ID, a name, an avatar and the personal best scores of that player. The phone sends the ID, the name and the avatar when it joins a TV, so every TV and every room knows the player again. The TV keeps the profile of a player in memory for the session only, and stores nothing.

Decided by the owner on 2026-10-10 (this thread):

1. There is no server and no account (REQ-P5). A login with Google or another service is **not** planned now. It could be added later only as an optional backup of the profiles, and the profile ID stays the identity. Not part of this plan.
2. The phone does everything: a profile is made, changed, chosen and shared on the phone. The TV has no login, no keyboard entry and no profile screen.
3. One phone can hold several profiles (a parent with several children). One phone is one controller, so one profile plays at a time. The phone decides when to switch; the TV does not ask.
4. A player with a profile is called by the profile name everywhere the TV and the phone now say "Player N", "2P" or "P2". A phone without a profile is a guest and keeps the number.
5. The avatar is picked from a sprite sheet of pixel avatars, and can be changed later. On the TV the avatar takes the place of the player number.
6. The best score of the player is kept in the profile on the phone. Every round counts.
7. A profile can be copied to another phone with a QR code, one profile at a time. The code contains the best scores.
8. Tilt Maze has no personal best.
9. A name has at most **10 characters**, on the phone, on the TV and in a code. A short limit removes most of the problems with long names (cards, chips, tags, codes).
10. A 1-player round and a 4-player round share one best.

What this plan does not do: no profile data on the TV (so no shared leaderboard on a TV), no sync between two phones after a copy, no protection against a changed app (a score on a phone is not proof of anything; this is a family game).

## 2. What the players see

### 2.1 On the phone

| Screen | Content |
|--------|---------|
| Connect screen | A dropdown at the top shows the active profile (avatar and name together, or `GUEST`), with a `+` next to it for a new player (REQ-FL-71, built on 2026-10-11). The dropdown lists the profiles, `GUEST` and `PLAYERS` (the list screen with EDIT, SHARE and the paste and scan of a code). Nothing blocks joining. After the phone has joined a TV the player cannot be changed: the player taps `DISCONNECT` and chooses again. |
| Profile list ("WHO IS PLAYING?") | One row for each profile: the avatar and the name. A tap on a row makes it the active profile. A row `GUEST` plays without a profile. The buttons are `NEW PLAYER`, `SCAN A PLAYER` and `PASTE A CODE` (see 2.3) and, on each row, `EDIT` and `SHARE`. When the list holds 8 profiles, `NEW PLAYER` is dim and a line says `8 PLAYERS IS THE MAXIMUM`. The list is reached from the Connect screen and from the waiting screen, only while the TV is in the phase `connect` or `menu`. When the phase changes to `playing`, `paused` or `waiting`, the phone closes the list, the edit, share and scan screens and hides any QR code. |
| Edit | The name field (1 to 10 letters, the keyboard of the phone), the avatar picker (32 avatars, 6 in a row, the list scrolls by dragging, the picked one has a frame), `SAVE`, `DELETE`. `DELETE` asks `DELETE <name>?` first. The avatar can be changed here at any time. |
| Share | A QR code of the profile, the text of the code with a `COPY CODE` button, and two lines: everybody who scans the code gets this player and the best scores; the two phones do not stay in sync after the copy. The QR code goes away after 60 seconds (section 6.3). |
| Waiting screen and pad | The colored square at the top shows the avatar instead of the slot number. The text next to it shows the profile name. A guest sees the slot number and `2P` as now. While the phone reconnects, the text says `Reconnecting...` as now. |

The texts are English and Hebrew (REQ-FL-54).

### 2.2 On the TV

| Place | Today | With a profile |
|-------|-------|----------------|
| Players list (Connect screen, Players modal), `slot_list.gd` | slot color square, `2P`, the name | the square holds the avatar, then the profile name |
| Ball, marble, blob, bumper or cursor of a player (REQ-GM-46) | the slot number | nothing: since 2026-10-11 an object has neither a number nor an avatar, only the slot color |
| Leader chip (`Shell.chip()`, REQ-GM-46b) | the color square and the name | the color square, the avatar (32 px) and the name (changed on 2026-10-11 to show the avatar, see the end of this file) |
| Result menu and the ranking (REQ-GM-72) | `1st  Player 2  12` | `1st  Maya  12` |
| Pause card (REQ-GM-30), `Minigame._slot_labels()` | `2P LOST CONNECTION`, `Resume without P2`, `P2 reconnected` | `MAYA LOST CONNECTION`, `Resume without Maya`, `Maya reconnected` |
| Leader chip (REQ-GM-46) | the name and the score | no change: there is no number in it |
| Debug overlay | `P2` | no change (it is a developer tool) |

A guest keeps the slot number and the name `Player N`. Names that are the same on one TV get a number (section 4.3). Two names of 10 letters fit in the pause card title on one line.

### 2.3 Copy a profile to another phone

1. On the first phone: profile list, `SHARE` on the row. The QR code shows.
2. On the second phone: profile list, `SCAN A PLAYER`. The camera scans the code and the profile is made, with the same ID, name, avatar and best scores.
3. A phone that cannot scan uses `COPY CODE` on the first phone and `PASTE A CODE` on the second one. An iPhone has no scan button at all today (`controller_connect.gd:24`, RISKS C5), so for an iPhone this is the only way. `COPY CODE` and `PASTE A CODE` are new UI that use the clipboard of the device.

The result is a **copy**, not a move. If the second phone already has a profile with the same ID, the two are merged (section 6.5). After the copy the two phones do not sync.

## 3. The profile

### 3.1 Fields

| Field | Type | Rule |
|-------|------|------|
| `id` | 16 random bytes, written as 32 lower-case hex characters | Made once with `Crypto.generate_random_bytes(16)`. Never changes. It is the identity of the player. |
| `name` | text, 1 to 10 characters | One constant `NAME_MAX` = 10 in `Protocol` is used by the phone field, the TV and the import. The TV now cuts at 16 (`tv_server.gd:209`); it changes to 10, also for an old phone that sends a longer name. Trimmed. |
| `avatar` | integer, 0 to 31 | The index in the sprite sheet (section 7). An index the app does not know shows the slot number (a later sheet can add avatars; it never changes or removes one). |
| `rev` | integer, 0 and up | Counts the edits of name and avatar. Used by the merge (section 6.5). |
| `bests` | map of best key to integer | Section 5. Empty at the start. |

The phone also saves the ID of the **active** profile, or none for a guest. After a delete of the active profile the guest is active.

### 3.2 Storage

`user://profiles.cfg` on the phone (a `ConfigFile`, like `controller.cfg`), written at once after each change (create, edit, delete, a new best, an import). If a write fails, the phone keeps the change in memory and shows `COULD NOT SAVE`. Before a write the old file is copied to `profiles.bak`; a file that cannot be read starts an empty list from the `.bak` if that one is good. The limit is **8 profiles** on one phone. A reinstall or "clear data" deletes the profiles. Only a copy made before can bring them back. The Share screen says this in one line. Leaving a TV (`Leave`) does not change a profile.

### 3.3 Names

The pixel fonts draw only some characters (REQ-FL-39). The name field accepts the characters for which `Font.has_char()` is true in the two fonts, except control characters, direction marks and the nikud signs, and also digits and the space. A test derives the allowed set from the fonts, so a font change cannot make a name unreadable. A character that is not allowed is dropped as it is typed, and a short line under the field says `LETTERS, DIGITS AND SPACE ONLY`. A name that is empty after this is not saved. The TV applies the same whitelist and the 10-character cut to every name it receives (section 4.1).

## 4. Protocol (`docs/PROTOCOL.md`)

The protocol `VERSION` stayed unchanged by the profiles (it was 2 then; it is 5 now, `scripts/core/protocol.gd`): every new field and message is optional, and an old TV or an old phone ignores it (the same rule as `lang` and `score`). The sentence in `PROTOCOL.md` that says `VERSION` changes "when a message changes" is reworded: it changes when an old side would misread a message. The wrong `"v":1` in the example of `hello` is corrected in the same change. Use the `change-protocol` skill.

### 4.1 Join

`hello` gets two optional fields:

```json
{"t":"hello","v":5,"room":"KQZM","token":"","name":"Maya","pid":"9f2c...32 hex...","av":3}
```

`pid` is the profile ID, `av` the avatar index. The TV checks them: `pid` is made lower case and must be 32 hex characters, `av` must be an integer from 0 to 255, and `name` goes through the whitelist and the 10-character cut. A `pid` that fails is ignored and the phone is a guest. **Any `hello` with no valid `pid` is a guest, also when `name` is not empty** (an old phone that sends a name shows that name as now, and has no avatar). A guest has the name `Player N` when the name is empty.

`welcome` gets the optional fields `pid`, `av` and `pname` (`name` in `welcome` is already the name of the TV) with the profile the TV accepted (they are empty for a guest). The phone compares them with its own profile and shows the TV answer as the truth.

### 4.2 Change of profile

```json
{"t":"profile","pid":"…","name":"Noam","av":7}      // or {"t":"profile"} for a guest
```

Phone to TV. The TV accepts it only in the phases `connect` and `menu`, applies the checks of 4.1 and the rule 4.4, and answers every `profile` with `{"t":"profile","pid":"…","name":"…","av":7}` (the accepted values, or empty for a guest). The phone keeps its change as *pending* until this answer comes, and shows the answer. The slot, the token and the color do not change. In the phases `playing`, `paused` and `waiting` the TV ignores `profile` and still answers with the stored profile.

A `hello` that resumes a slot with a token follows the same guard: outside `connect` and `menu` the TV keeps the stored profile of the slot and ignores `pid`, `av` and `name` of that `hello`. The profile changes at the next `profile` message in a menu phase.

### 4.3 Names on the TV

`PlayerInput` gets `profile_id`, `avatar` and a `display_name`. The TV makes `display_name` from the profile name, and adds ` 2`, ` 3` to a name that is already used by a player in a lower slot. The comparison ignores case and spaces at the ends (the screens show upper case), and a guest `Player 2` is part of the comparison. The longest `display_name` is 12 characters (10 and ` 2`); the chips and the tags were made for 16, so they fit; the layout tests use 12. `display_name` is frozen when a round starts and is made again only in the menus, so a name does not change in the middle of a round. Every TV text uses `display_name`. `PlayerInput.reset()` clears the profile fields.

### 4.4 Same profile on two phones

The `pid` check runs before the slot is chosen, so a full TV does not reject the phone that replaces its own profile.

- In the phases `connect` and `menu`, if a `hello` or a `profile` brings a `pid` that is already present in **another** slot, the **newer phone wins**. The TV frees the older slot and tells that phone `{"t":"kicked","reason":"replaced"}`. The phone shows `THIS PLAYER IS ALREADY IN THE ROOM.` (key `app.player_already_in_room`; the plan first had "YOUR PLAYER JOINED ANOTHER PHONE") (the text for plain `kicked` stays `The host removed you...`), forgets its token and does not reconnect by itself. The TV also remembers the token of the freed slot for 10 minutes, and answers a `hello` with that token with the same `kicked`, so a phone that was offline when it was replaced does not come back and replace the newer one.
- In the phases `playing`, `paused` and `waiting` the TV does **not** free a slot because of a `pid`. The newer phone joins as a guest (as every late phone waits for the next round, REQ-FL-25) and its `pid` is ignored; it can send `profile` in the next menu.
- A phone that reconnects with its token is checked first and is not affected (the token path of `tv_server.gd` stays first).

### 4.5 Round results and personal bests

When a round ends, the TV sends each phone that took part and has a `pid` one message:

```json
{"t":"result","pid":"…","key":"snowball_splat|medium","v":340}
```

`key` is the best key of the game (section 5.1), `v` the score of that player as an integer in the units of section 5.3. The direction (higher or lower is better) is a fixed property of the key, kept in `ProfileKeys` on the phone; it is not in the message. A guest phone gets no message. The phone ignores a `result` whose `pid` is not the active profile. A phone that is lost at the end of the round does not get the message, and the score is not saved (the TV does not keep it).

### 4.6 The profile of the active phone changes

If the player deletes the active profile, or an import changes it, while the phone is connected in a menu phase, the phone sends `profile` (guest, or the new values) at once.

## 5. Personal bests

### 5.1 What a game says

`Minigame` gets one function, `best_key() -> String`. The default is the game ID and the difficulty (REQ-GM-91): `snowball_splat|medium`. A game adds a variant when the score depends on it. A game with no personal score returns an empty text and no `result` is sent.

| Game | Key | Better | Why |
|------|-----|--------|-----|
| Tilt Maze | none (owner, item 9.1) | | The maze is random in every round (`maze_game.gd:64`), so a time is mostly the luck of the maze. Only the winner has a time (`maze_game.gd:100`). |
| Marble Race | `marble_race|<difficulty>|<track 1 to 10>` | lower (time) | Only the 10 fixed tracks (`FIXED_SEEDS`, `marble_track.gd:63`). |
| Snowball Splat | `snowball_splat|<difficulty>` | higher | |
| Paint Grab | `paint_grab|<difficulty>` | higher (tiles) | The score of the `Scoreboard` is the number of tiles (`paint_grab_game.gd:139`). |
| Sumo Bumpers | none | | The result is a win, not a number. |

A random track of Marble Race has no key. If the track generator or `FIXED_SEEDS` changes so that a track is not the same track, the change adds **new key numbers** (section 6.1) instead of reusing the old ones.

### 5.2 What counts

Every round counts (owner, 2026-10-10), also with 2 to 4 players; a round with 4 players and a round with 1 player share one key. `open_results()` is the one place that ends a round with scores (REQ-GM-72), so it sends the messages. Only a player who **finished** with a score gets one: a player who is "not finished" (a ball that did not reach the exit or the finish) and a score of 0 in a higher-is-better game send nothing. A restart is a new round. A round that ends with "No players connected" sends nothing.

### 5.3 Stored value

An integer: a time in milliseconds (12.345 s is 12345), a score as it is (340 tiles is 340). The TV converts and sends the integer; the phone keeps one integer for each key.

### 5.4 What the player sees

The phone shows `NEW BEST!` on the waiting screen after a round that set a new best, with the old best in small text. Nothing changes on the TV: the result menu stays as it is (item 9.5).

## 6. Sharing by QR code

### 6.1 Code format

The text of the QR code is `WP1.` followed by base64url text (no padding) of this binary data:

| Bytes | Field |
|-------|-------|
| 1 | Format version: 1, or 2 when a best has a number above 39 |
| 16 | Profile ID |
| 1 | Avatar |
| 1 to 5 | `rev` (varint; the decoder accepts up to 5 bytes) |
| 1 + n | Name: length n (0 to 20 bytes, UTF-8; 10 characters, Hebrew letters take 2 bytes), then the bytes |
| 1 | Number of bests, k (0 to 39 in version 1, 0 to 42 in version 2) |
| k times | Best key number (1 byte, from the table `ProfileKeys`), then the value as a varint (up to 5 bytes) |
| 2 | Checksum (CRC-16) of all the bytes before it |

`ProfileKeys` is a fixed table in code: for each key the key text, its number (1 to 42: Maze none, Snowball Splat 3, Paint Grab 3, Marble Race 3 difficulties x 10 tracks = 30, Star Shield 3 = numbers 37 to 39, Pin Pals 3 = numbers 40 to 42. Pin Pals raised `MAX_KEYS` from 39 to 42 and added a second format version: a code with a best above number 39 is written as `FORMAT_VERSION` 2, any other code stays version 1 (same layout; version 1 allows k up to 39, version 2 up to 42), so an app from before Pin Pals reads every code except one that has a Pin Pals best. The next game with a best adds numbers at the end and decides again whether a version 3 is needed) and its direction. A number is never reused or changed; a new game or a changed track set adds numbers at the end. A code with a key number the app does not know is read, and that key is skipped. The prefix `WP1.` tells the scanner that this is not a TV link (`ws://`); the Connect screen scan routes a `WP1.` code to the import and the profile scan gives `THIS IS A TV LINK` for a TV link.

### 6.2 Size and the QR encoder

The largest profile is 1+16+1+2+21+1+42*6+2 = 295 bytes, or about 375 characters of text with the prefix. A normal profile with a few bests is about 80 bytes, 110 characters. `scripts/core/qr_encoder.gd` now stops at version 6 (134 bytes). Phase B extends it to **version 14, error correction L** (458 bytes). The work is more than a bigger table:

- the character count field of byte mode is 16 bits from version 10 (now 8 bits, `qr_encoder.gd:41`, and the capacity check at `:29` changes with it);
- the table of alignment pattern positions (`_ALIGN`, `:15`) for versions 7 to 14 (version 14 has 6, 26, 46, 66), and the skip of the patterns that touch a finder pattern;
- the block layout for each version (short and long blocks; check that the code at `:131` is right for them);
- the two version information blocks (18 bits each) for version 7 and higher.

The TV link keeps using the small versions. The Share screen draws the code with a white border of 4 modules (the TV `QrView` has 1, `qr_view.gd:29`) and at least 6 screen pixels for a module: a version 14 code is 73 modules, with the border 81, so 486 of 1080 pixels. The code is made **once** when the Share screen opens (eight masks over 73 x 73 modules are too slow for each frame), and the time is measured on a phone in manual test 20. There is no QR decoder in the repository, so the encoder is checked by (a) structure tests (size, finder, timing and alignment patterns, format and version bits, the capacity table, the 16-bit count), (b) a fixed text with the hash of its expected modules in `tests/`, made once with an outside decoder that confirms it reads the text back, so the owner can repeat the check, and (c) manual test 20.

### 6.3 Safety and the input rules

A profile code gives anybody who scans it the player. This is acceptable because the TV already trusts what the phone says. The Share screen opens only after a tap on `SHARE`, hides the code after 60 seconds, and never shows it on the TV.

**Import rules.** The CRC finds typing errors only, so a decoded profile goes through the same rules as a typed one. The name goes through the whitelist and the 10-character cut (the format allows 20 bytes; a longer or unclean name is cut, not refused). The avatar is 0 to 255 and an unknown index shows the number. `k` is at most 42, a key that appears twice is refused, a value of 0 or above 4 000 000 000 is skipped, and the direction comes from `ProfileKeys`, not from the code. A code that breaks the format is refused with `THIS CODE DOES NOT WORK`. Every rule has a test.

### 6.4 Scanning

The phone scanner is the existing Google code scanner plugin (`qr_scanner.gd`); no plugin change. The scanner opens its own screen, so the phone offers `SCAN A PLAYER` only in the phases `connect` and `menu`, and ignores a scan result that comes after a phase change to a game phase. The scan result is routed by prefix (`WP1.` or `ws://`) on both the Connect screen (`controller_connect.gd`, `_on_qr_text`) and the profile list.

### 6.5 Merge on import

If the phone has a profile with the same ID: the profile with the higher `rev` gives the name and the avatar (equal `rev`: the local one stays), and `rev` becomes the higher number. For each best key the better value wins (direction from `ProfileKeys`); a key that is in one profile only is kept. A scan of an old copy therefore never replaces a newer rename. If the ID is new and the phone has 8 profiles, the phone says `8 PLAYERS IS THE MAXIMUM`. If the imported profile is the active one while the phone is connected, section 4.6 applies.

## 7. Avatar sprite sheet

- File: `assets/avatars/avatars.png`, 64 x 128 px, 32 cells of 16 x 16 px in 4 columns and 8 rows (decided by the owner on 2026-10-11: 32 avatars in the same style; the first 16 are unchanged), transparent background, the colors of the NES palette of `UiTheme` (REQ-FL-37), a 1 px dark outline on each avatar, no antialiasing. The index is row by row from the top left.
- 32 friendly characters that a child of 5 years knows at once and that are different in their shape, not only in their color (animals and a robot, an alien, a ghost, a star; 16 to 31: lion, mouse, koala, cow, monkey, tiger, duck, turtle, bat, octopus, bee, dino, unicorn, ladybug, crab, wizard). The first version is drawn by Claude with a script that is kept in the project files, as for the logo; the owner changes the list if a picture does not work.
- Rule: the avatar is drawn at a whole-number scale with the nearest filter, in the place of the number, centered in the colored square. It must be readable on all four slot colors and from the sofa. The pixel-world games draw the ball in the low-resolution layer and the number later on the HUD (`Shell.ball_number()`, `shell.gd:171`), and the 3D marble has its own number (`marble_race.gd:404`). Phase A lists every place and sets the size for each; a 16 x 16 sprite at 2x is 32 px, so the smallest ball radius is checked first.
- REQ-P6 gets the new allowed file. The file is imported without a filter and without mipmaps, like the logo, and `tests/design_tokens.gd` checks the import settings. A license line in `assets/avatars/README.md` says that the art is made for the project.
- Both apps load the same sheet (the export presets export all resources, `export_presets.cfg`). The index stays valid for ever (section 3.1).

## 8. Phases

One pull request for each phase, stacked, with the code, the tests, the documents and the manual test in the same pull request (REQ-GM-5, REQ-GM-62). A pull request is made only when the owner asks.

| Phase | Content | Manual test |
|-------|---------|-------------|
| A. Profiles and names | `Profile` and `ProfileStore` (new modules), the avatar sheet and the `Avatar` drawing, the phone screens (list, edit, avatar picker, switch), `hello`, `welcome` and `profile`, the TV validation and `display_name`, avatars instead of numbers, names in the pause card, the result menu and the lists, the duplicate ID rule, the text edits of section 10. | Test 20 items 1 to 8 |
| B. Share by QR | The QR encoder up to version 14, the code format and the import rules, `SHARE`, `SCAN A PLAYER`, `COPY CODE`, `PASTE A CODE`, the merge. The code has k = 0 bests until phase C. | Test 20 items 12 to 15 |
| C. Personal bests | `ProfileKeys` directions, `best_key()` in `Minigame` and in the games, the `result` message, the update rule, `NEW BEST!` on the phone, the bests in the code. The requirements file of each game. | Test 20 items 9 to 11 |

Phase A is useful alone. Phase B needs A and gives the copy of a profile early (a child's profile can move to a new phone before bests exist). Phase C needs A and B.

## 9. Defaults and decisions

Items 1, 8 and 10 are decided by the owner. The others are defaults that the owner confirms.

1. **Tilt Maze has no personal best** (decided by the owner). The maze is random in every round, and only the winner has a time.
2. **8 profiles** on one phone, and a `GUEST` row.
3. A profile ID on two phones: **the newer phone wins** in a menu, and a phone never replaces another one during a round (section 4.4).
4. The profile list **cannot be opened during a round**; a phone switches between rounds only.
5. `NEW BEST!` shows on the **phone only**. The TV result menu does not change. This changes what the TV shows, so the owner decides: for example a `NEW BEST` tag on the row of the result list.
6. Deleting a profile on the phone that is not the active one tells no TV. Deleting the active one makes the phone a guest on the TV.
7. ~~The avatar is not drawn on the leader chip.~~ Changed on 2026-10-11: the leader chip shows the avatar (REQ-GM-46b, REQ-FL-70); the game objects do not.
8. **Name length.** At most 10 characters (decided by the owner). Two names fit in the pause card title on one line. Hebrew names in an English sentence and the reverse need a text direction check (manual test 20 item 6).
9. A name field **drops** characters the fonts cannot draw, with a hint under the field.
10. Bests of rounds with 1 to 4 players share one key (decided by the owner).
11. **Privacy.** The profile ID is the same on every TV, so a TV can see that it is the same child as at another house, and the ID is in the QR code. The TV holds it in memory only and clears it when the slot is freed; nothing is logged. The name of a child shows on a TV in a friend's house. The owner confirms that this is wanted; a child can always play as `GUEST`.
12. 32 avatars, 4 columns by 8 rows (first 16 were decided at the plan; the owner asked for at least 32 in the same style after the phase A review).

## 10. Documents that change

The documents are as important as the code (REQ-GM-5). Each item is done in the pull request of its phase, in the same commit as the behavior.

| Document | Change | Phase |
|----------|--------|-------|
| `docs/TV_FLOW.md` | FD-22 in the decisions table. A section "Profiles" with REQ-FL-69 to 78: the phone screens, the list, the edit and delete rules, the guest, the name rules, the avatar in the numbers' place, `display_name`, the duplicate name, the duplicate ID, the switch rule, the share screen. Change REQ-FL-32 and 33 (Players modal shows name and avatar). Two rows of the decision table are both numbered FD-21 (the leader chip and the name Sababi): this plan keeps both as they are and numbers its decision FD-22; the owner decides whether the second FD-21 is renumbered. | A, B |
| `docs/PROTOCOL.md` | `hello` and `welcome` fields `pid`, `av`; the messages `profile` and `result`; the `reason` of `kicked`; the duplicate ID rule and the token memory in "Slots, loss and reconnect"; the text "Resume without P2" in that section becomes the name rule; the `WP1.` payload in a new section; `VERSION` stays 2 and why; the wrong `"v":1` and the sentence about `VERSION`. | A, B, C |
| `docs/REQUIREMENTS.md` | REQ-P5: say that profiles are on the phone only and are not an account. REQ-P6: the allowed file `assets/avatars`. New REQ-N8 (profile fields in `hello`) and REQ-C7 to C9 (profiles on the phone, local storage, switch rule). REQ-T5: the pause card names the players. | A |
| `docs/GAME_REQUIREMENTS.md` | REQ-GM-30 and 30a (names in the pause card), REQ-GM-46 (avatar in the place of the number on a ball), REQ-GM-72 (names in the result list), REQ-GM-73 (medals stay; personal best is separate). New REQ-GM-98 to 101: `best_key()`, what counts, the message, no best for a game with no key. The comment in `scripts/game/medals.gd` ("the player is not identified yet") is corrected. | A, C |
| `docs/games/TEMPLATE.md` and the game files that existed then (`marble_race.md` is now the Car Race file; the file names did not change) | The template gets a requirement row "Personal best (REQ-GM-98): key and direction, or the exception" in its table. `marble_race.md`, `snowball_splat.md`, `paint_grab.md` get a row with the key; `maze.md` and `sumo_bumpers.md` get an exception row. The rows that say `2P` or `P2` are updated for profile players. | A, C |
| `docs/MANUAL_TESTS.md` | New test 20 (section 11), the Summary table row, the list of covered requirements. The steps of test 7 (lines about `2P LOST CONNECTION`, `Resume without P2`, `P2 reconnected`) and test 19 (the phone shows `2P`) are edited so they are right for a guest and for a profile player; the old wording stays for a guest. Test 19 uses names of 12 to 16 letters: they become 10 letters. | A, B, C |
| `CLAUDE.md` | The table "Tests the user has to run now": a row for test 20. | A |
| `docs/design-system/` | The profile row, the avatar picker and the Share card in the phone mockups; `tests/screenshots_controller.gd` gets the new screens. | A, B |
| `docs/GAMES_ROADMAP.md` | The shared code table gets `Minigame.best_key()` and `Avatar`. | A, C |
| `.claude/skills/add-minigame/SKILL.md` | A step: decide the best key, or return an empty text and write the exception. | C |
| `.claude/skills/change-protocol/SKILL.md` | Check that its list of messages is still right; add `profile` and `result` if the skill lists the messages. | A |
| `docs/RISKS.md` | New risks: a dense QR code may scan badly (version 14), an avatar may be unclear at the size of the number, a name with a character the font lacks, one profile on two phones, a reinstall deletes the profiles, an iPhone cannot scan (a link to C5). | A, B |
| `docs/EXPORT.md` | One line: `assets/avatars` is in the export of both apps. | A |
| `README.md` | The feature list gets profiles; the docs index gets this file. | A |
| `docs/PROFILES_PLAN.md` (this file) | Status line and a "what was built, what differs" section at the end of each phase, as in `docs/AUDIO_PLAN.md`. | each |
| `assets/lang/strings.csv` | English and Hebrew texts for every new screen, button and message; `tests/smoke_lang.gd` fails when one is missing. The Hebrew text is written by Claude and checked by a native reader (manual test 17 style). | A, B, C |

## 11. Tests

### 11.1 Automatic

All new suites are added to `tests/suites.txt` only, with these lines: `tests/profiles.gd|controller|profiles, codes and bests` and `tests/net_profiles.gd|controller|profiles over the network`. Every new module (`Profile`, `ProfileStore`, `ProfileKeys`, `Avatar`, and the three phone screens: list, edit, share) needs 80% line coverage (CLAUDE.md). The tests check behavior, not lines. No module is put in `tools/coverage/exclusions.txt`.

| Suite | What it checks |
|-------|----------------|
| `tests/profiles.gd` | Make, rename, change the avatar (and `rev` goes up), delete; the limit of 8; the name rules (10 characters, Hebrew, the allowed set derived from `Font.has_char()`, empty is refused); write and read back `profiles.cfg`; a failed write; a corrupt file with and without `.bak`; the active profile and the guest; the random ID is 32 hex characters and two IDs differ. |
| same | Bests: a lower time is better, a higher score is better, a score of 0 and "not finished" are ignored, the merge rule, the direction comes from `ProfileKeys`. |
| same | Code: encode and decode of a profile give the same profile; a Hebrew name of 10 letters; 42 bests; a wrong checksum, a truncated code, another version, a wrong prefix are rejected; an unknown key number is skipped; a duplicate key, a value of 0, a name of 20 bytes and one of 30 bytes, an avatar of 255 and k above 42 follow the import rules; the merge with `rev`; golden test: a fixed profile gives a fixed text (protects `ProfileKeys`). |
| `tests/net_profiles.gd` (real sockets, like `net_loss.gd`) | `hello` with `pid` and `av` fills the player and `welcome` echoes it; an old `hello` without them is a guest; a bad `pid`, an `av` of 300 and a name with a newline are cleaned; `profile` changes name and avatar in `connect` and `menu`, is answered, and is ignored (but answered) in `playing`; a resume `hello` in `playing` does not change the profile; the duplicate ID rule frees the older slot with `kicked/replaced` in a menu, also on a full TV; the old phone with a stale token gets `kicked/replaced` and does not replace the new one; in `playing` the second phone is a guest; a token resume is not affected; `Sam`, `sam` and a guest named `Player 2` get distinct `display_name`; `display_name` does not change during a round; `result` carries the `pid` and reaches only a phone with one. |
| `tests/game_rules.gd` | `open_results()` sends one `result` for each finished player with the key of the game; Maze, Sumo and a random track send none; a player who is "not finished" gets none. |
| `tests/ui_states.gd` | The profile list, the edit screen (a name is needed to save, `DELETE` asks first, the full list dims `NEW PLAYER` and says why), the Share screen and its 60-second hide, the screens close on a phase change, the waiting screen shows the avatar, the guest and the reconnect case. |
| `tests/smoke_tv.gd`, `smoke_lang.gd` | The pause card, the result list and the players list show the profile name (also 12 characters and Hebrew); every new string has Hebrew. |
| QR encoder (in `run_tests.gd`) | Versions 7 to 14: size, finder, timing and alignment patterns, format and version bits, the capacity for each version, the 16-bit count, a text that is too long returns empty; versions 1 to 6 give the same modules as before; the fixed text with the hash of its modules. |
| `tests/design_tokens.gd` | The import settings of the avatar sheet (no filter, no mipmaps). |

`gdlint` is clean and `tools/coverage.sh` reports every module at 80% or more before a pull request (CLAUDE.md).

### 11.2 Manual: test 20 (new, "Not run")

Needs: 2 to 4 phones (one an iPhone if possible), 1 TV, a grown-up and a child of about 5 to 8 years. It covers REQ-FL-69 to 78, REQ-GM-98 to 101, REQ-N8, REQ-C7 to C9, FD-22. Items:

1. Make a profile on a phone: name, avatar; join a TV. Check: the TV shows the name and the avatar in the Players list, on the ball or blob in each game, in the result list; no "Player N".
2. Change the avatar and the name, join again; check the TV.
3. A parent phone with 3 profiles: switch between rounds; check that the TV shows the new name and avatar, that the phone waits for the TV answer, and that the list closes when a round starts.
4. Two phones with the same name (also `Sam` and `sam`): the TV shows `Sam` and `Sam 2`.
5. A guest next to profile players: the guest keeps the number.
6. Pause card with profile names (switch Wi-Fi off): two names of 10 letters, a Hebrew name in an English sentence and an English name in Hebrew; check that the text fits and reads right.
7. All avatars on all four slot colors and on the smallest ball, from the sofa; a child names five of them.
8. The same profile on a second phone joins the same TV in the menu: the older phone shows `THIS PLAYER IS ALREADY IN THE ROOM.` (key `app.player_already_in_room`; the plan first had "YOUR PLAYER JOINED ANOTHER PHONE"). Then repeat during a round: the second phone waits as a guest and nobody is removed.
9. Play Snowball Splat, Paint Grab and Marble Race (a fixed track) with a profile; check `NEW BEST!` and that a worse round does not change the best; one round with 2 phones.
10. Close the app and open it: the profiles and bests are still there. Join another TV: the same name and avatar.
11. Tilt Maze, Sumo Bumpers and a random Marble Race track: no best.
12. Share a profile with 20 bests to a second phone by QR: the same name, avatar and bests; time how long the code takes to appear and to scan; try it from 30 cm and from 60 cm.
13. Import a profile that the second phone already has, with a newer name on one phone and better bests on each side: the newer name and the better bests stay.
14. An iPhone: `COPY CODE` on one phone and `PASTE A CODE` on the iPhone.
15. A broken code (one letter changed), a TV link on the profile scan, and a profile code on the Connect screen: the right messages.

## 12. Risks

| Risk | Plan |
|------|------|
| A QR code of version 14 is too dense for a phone screen scan | Item 12 measures it. If it fails, phase B keeps only the bests that were set most recently (the owner decides first) or splits the code. |
| No decoder in the repository to check the new encoder | Structure tests, a fixed text with a hash, one outside decoder check by Claude, then the manual test. |
| An avatar is unclear at the size of a ball digit | Item 7. The size of each place is set in phase A and can change. |
| A reinstall deletes the profiles | The Share screen says it. A login backup is a later option (section 1). |
| The profile ID is a stable identifier sent in clear text on the LAN | It is a random number with no link to a real person. The TV keeps it in memory only (item 9.11). The app has no internet part (REQ-P5). |
| Two phones with one profile | Section 4.4. |

## 13. Review

On 2026-10-10 an independent reviewer read this plan against the code and the documents. Its report had 25 findings. They are applied here: no personal best for the random maze (9.1), the duplicate ID rule with a token memory and a rule for rounds (4.4), the profile answer and the resume guard (4.2), the validation of `hello` and of imported codes (4.1, 6.3), the `rev` in the merge (6.5), the real cost of the QR encoder (6.2), the wrong references to RISKS and the missing iPhone paste UI (2.3), the keys of Paint Grab and Marble Race (5.1, 5.3), the rules for equal names (4.3), the text edits in manual tests 7 and 19 and the other documents (10, 11), the places of the avatar in the pixel worlds (2.2, 7), and the share phase before the bests phase (8). Open points that need the owner are in section 9.

## 14. Phase A: what was built, what differs

Built on 2026-10-10 on branch `claude/profiles-a-names`.

- New modules: `Profile` (ID, name rules), `ProfileStore` (`user://profiles.cfg`, `.bak`, the limit of 8), `Avatar` and `AvatarView` (the sheet and its drawing), the phone screens `controller_profiles.gd` and `controller_profile_edit.gd`. `Protocol` has `NAME_MAX`, `AVATAR_COUNT` and `REPLACED_TOKEN_MS`.
- The `welcome` field for the player name is `pname`, because `name` in `welcome` is the name of the TV.
- The name whitelist is a fixed set (Latin letters, digits, the space and the Hebrew letters) and a test checks that the pixel fonts have a glyph for every character of it. The plan said the set is derived from `Font.has_char()` at run time; a fixed set is the same for the phone and the TV and does not depend on a font being loaded on the TV.
- `PlayerInput.player_name` stays the display name that every TV text uses (the plan called it `display_name`); `raw_name` is the name that the phone sent.
- Changed on 2026-10-11: the avatar is no longer drawn on the objects of a game (`Shell.mark()` and `Shell.ball_number()` are gone). The leader chip shows it next to the color square (`Shell.chip()`). The result menu rows keep the slot color square.
- Changed on 2026-10-21: the name tags of the countdown (REQ-GM-46a) were removed (decision of the owner, Alon). The avatar and the name show on the leader chip, the pause card and the result menu.
- Not in phase A: `SHARE` and the scan or paste buttons (phase B), the bests (phase C), the design-system mockups and `tests/screenshots_controller.gd` for the new screens (open, see the doubts in the pull request).

Changes after the phase A review (2026-10-11):

- A phone that returns in a round keeps the name the TV showed it (`Sam 2` stays `Sam 2`, also when the first `Sam` left); before, the name was made again.
- `pname` in `welcome` and `name` in the `profile` answer are the name that the TV shows (with the number), so the phone header and the TV agree.
- The phone sends its profile again at the next menu also when only the name or the avatar differs from what the TV has (a number that the TV added to a name does not count).
- A lost connection no longer closes the profile list and the edit screen, so a typed name is not lost.
- `ProfileStore.save()` copies the file to `.bak` only when the file is a good one; `Profile.clean_id` accepts only the characters 0 to 9 and a to f; the TV forgets replaced tokens that are past their time.
- Not changed: review item 4 (a late phone with the same profile removes the player who just played at the next menu) waits for the decision of the owner.
- The sheet has 32 avatars (4 columns by 8 rows, the first 16 unchanged), made with the same script and style. The picker shows 6 in a row and scrolls by dragging; a tap picks only when the finger does not move (`AvatarView.TAP_SLOP`).

## 15. Phase B: what was built, what differs

Built on 2026-10-10 on branch `claude/profiles-b-share`.

- `QrEncoder` goes up to version 14 (L). It was checked with an outside decoder (zxing-cpp): 66 texts of 1 to 458 bytes, every version, all read back. `tests/qr.gd` checks the structure and the hash of a fixed text. The code is drawn by `QrView` with `quiet = 4` and whole-pixel modules.
- `ProfileKeys` (the key table, numbers 1 to 36 and the direction) was moved from phase C to this phase, because the code format needs the numbers. Phase C adds `best_key()`, the `result` message and the update rule. `Profile.bests` already existed in phase A.
- `ProfileCode` (`encode`, `decode`, the CRC-16) and `ProfileStore.import_profile()` (add or merge). `App.import_profile_text()` is the one entry for a scan, a paste and the Connect screen.
- A new player from a code becomes the active one only when the phone had no profile. Otherwise the active profile stays.
- Screens: `controller_profile_share.gd`, SHARE on each row, SCAN A PLAYER (only where the QR plugin exists) and PASTE A CODE on the list.
- The Share screen has no countdown number; it goes back to the list after 60 seconds.
- Not in phase B: the time to make a version 14 code on a phone is not measured (test 20 item 12).

## 16. Phase C: what was built, what differs

Built on 2026-10-10 on branch `claude/profiles-c-bests`.

- `Minigame.best_key()` and `best_value()`. The default key is empty (no best), so Tilt Maze and Sumo Bumpers needed no change; Snowball Splat and Paint Grab give `<game>|<difficulty>`; Marble Race gives the key only for the 10 fixed tracks and saves the time in milliseconds. The plan said the default key is the game and the difficulty; an empty default is safer for a new game (the `add-minigame` skill asks for a decision).
- `open_results()` sends the `result` message (`TvServer.send_result()`). The phone checks the `pid`, and `App` records the best with `ProfileStore.record_best()`.
- The waiting screen shows NEW BEST! and the old best. The old best shows only when there was one. The first score of a key is also a new best.
- `ProfileKeys` was built in phase B.
