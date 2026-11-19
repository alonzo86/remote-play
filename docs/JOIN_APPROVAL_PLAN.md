# Join approval plan: the host lets each new phone in with the TV remote (FD-30, issue #393)

Status (2026-11-07): **plan; phases 1 to 4 are built (phase 4, 2026-11-07: the Settings row, the default ON, the TV app suites with the approval OFF, the docs); Manual test 34 ran in R9 on 2026-11-17: 22 of 23 steps Pass, item 4c is the headless test A-34-4c; Manual test 34 was set to Pass on 2026-11-19 (owner's instruction) and REQ-FL-93 to 104 are Done; the privacy notice, section 3, was updated on 2026-11-08 with the owner's decision (see section 10.2).** Phase 4 differs from section 8 in one point: the TV app suites do not each carry the line `approve_new = false`; `tests/import_guard.gd` (`ok()`, the first line of every suite) turns the approval OFF in memory in the TV App of the run, and the suites that test the approval turn it ON themselves. Phase 4 also adds `tests/approve_setting.gd`. Phase 1 differs from the text below in three points (the behavior is the contract): (a) the refusal table is its own class `scripts/net/refusal_table.gd` (`RefusalTable`, used by `TvServer`), and `tv_server.gd` carries a `gdlint:ignore` for `max-public-methods` because the approval API is part of the class; (b) the tests of 5.4 6a and 6c give a request the address of a test (`tests/join_approval.gd` sets `host` of the pending entry before the `hello`), because a client that connects to 127.0.0.2 reaches the TV with the source address 127.0.0.1, so no loopback alias is needed and 6c is never skipped; (c) after `_replace_slot` the token is in `_replaced_tokens`, and step 4 of 4.2 runs before the known tokens, so a `hello` with it gets `kicked`/`replaced` (not a card) for 10 minutes, and a card after that (6d is read this way). Written Written by the role `software-architect` for issue #393. The owner decided on 2026-11-07 (issue #385) that the host approves each new phone with the TV remote, with a TV setting "approve new players" that is ON by default. The behavior rules (what the host and the player see) are REQ-FL-93 to REQ-FL-104 in `docs/TV_FLOW.md`, written by the `product-engineer`; the look is the mock in `docs/design-system/components/JoinApproval/` (approved by the owner on 2026-11-07). This file says **how**: the join state machine of the TV, the protocol, the phone and TV code, the tests and the phases. Where this plan and REQ-FL-93 to 104 differed, section 12 lists the point and the final choice of the plan; the requirement wins for what the user sees, this plan wins for the wire and the code structure. No code, no string and no legal text is changed by this file.

Style: ASD-STE100 Simplified Technical English, like the other plans. File and line references were checked on 2026-11-07 against `main` (after PR #391 and PR #392).

## Decided by the owner (2026-11-07)

Every decision of `docs/TV_FLOW.md` (D1 to D12) and the look of the mocks are decided. Nothing in this plan waits for the owner except the privacy notice text (section 10.2) and question 1 of section 14 (it does not block a phase).

1. **D1, the card shows the avatar and the name** (REQ-FL-97, section 7.1). A phone with no name shows "PLAYER N".
2. **D2, the setting OFF refuses the waiting requests** (FD-30.10); the OFF refusal neither counts nor blocks.
3. **D3, a TV that quits sends `bye`; a lost link is `wait_lost`** (section 12, point 3). No new text, no retry.
4. **D4, block after 3 refusals in a row.** A host refusal does not block the address by itself. The address is blocked for 60 s only after 3 **consecutive** refusals by the host from that address. An allow resets the counter to 0. A timeout or a cancel by the phone does not count and does not reset. The TV keeps the counter for each address for the run of the TV app (FD-30.8, section 4.6).
5. **D5, 180 s in total and 60 s for each card**, invisible to the host (FD-30.9).
6. **D6, the 1 s key lock.** OK, the arrows and BACK are ignored for 1 s after a card shows; BACK stays ignored after the 1 s too (D12) (FD-30.15, section 7.2).
7. **D7, the phone shows one waiting text** (FD-30.14). The text is "WAITING FOR THE HOST TO GET YOU IN." / "ממתינים שהמארח יאשר אתכם." (`connect.waiting_approval`). The hint line does not name OK; the proposal is "ASK THE HOST TO ALLOW YOU ON THE TV." (`connect.waiting_approval_hint`, section 10.3).
8. **D8, the Settings row "approve new players" is the first row of the TV Settings screen**, above Debug overlay (FD-30.16, section 7.3). This replaces the first recommendation (last row).
9. **D9, a TV with 4 players refuses before the card** (4.2, step 8).
10. **D10, no countdown on the TV card.** The card shows no time text, no time bar and no seconds left. The internal timeouts (60 s shown, 180 s total) stay, and the host does not see them (FD-30.14).
11. **D11, the wide known-token rule** (FD-30.4). A known token is any token that this TV gave in this run of the TV app and that a kick, a `bye` of the phone or a replacement of the slot (`_replace_slot`) did not revoke; the TV keeps at most 32 (the oldest goes first) and forgets them all when the TV app restarts. A `hello` with a known token joins with no card.
12. **D12, the card buttons and BACK** (FD-30.15, section 7.2). The card has two buttons, ALLOW and REFUSE, and no key hints. The focus starts on ALLOW for every card. LEFT and RIGHT move the focus; OK activates the focused button. **BACK does not refuse: the card ignores BACK.** BACK cannot close the card, and BACK does not reach the screen or the modal under the card. Only a button (after the 1 s lock) or the internal time limit (60 s shown, 180 s total) ends a request.
13. **The setting "approve new players" is ON by default** (FD-30.3).
14. **The look of the mocks is approved** (`docs/design-system/components/JoinApproval/`: the TV card, the Settings screen, the phone waiting, refused, timeout and busy screens).

## 1. Goals and non-goals

Goals:

1. With the setting ON, a phone that joins with a new connection takes no slot and gets no game message until the host activates ALLOW on the TV card with the remote.
2. A phone that comes back with a token that the TV gave it in this session is not asked again (a lost Wi-Fi, a phone call, the app in the background).
3. The approval never shows during a round and never slows a round.
4. One device on the Wi-Fi cannot fill the TV with cards or keep the family out longer than the limits of issue #387 allow.
5. Old and new builds work together without a `VERSION` change: an old phone with a new TV waits and then joins, or gets a clear text; a new phone with an old TV joins at once as today.
6. With the setting OFF the TV behaves exactly as today (FD-28), byte for byte on the wire.

Non-goals:

- No PIN, no password, no encryption. FD-28 stays: the room code is the address, not a secret. The approval stops a stranger who joins; it does not stop a device that reads the traffic (section 9).
- No approval for a profile change, a slot change or a resume. The approval is about the device, once per session.
- No list of waiting phones in the Players modal and no "allow all" action. The queue is small (4) and the card shows one request at a time.
- No memory across a TV restart: the TV forgets every token, every refusal counter and every block when the app closes (no new saved data except the setting).
- No countdown for the host: the TV card shows no remaining time (owner, 2026-11-07).
- No change to the 4 slots, to the pause rules (REQ-GM-30) or to REQ-FL-74 (held profile).

## 2. The state today (facts this plan starts from)

| Place | What it does today |
|-------|--------------------|
| `scripts/net/tv_server.gd:322-333` | Accepts a TCP stream unless `_pending` has 16 entries (`MAX_PENDING`), the address has 4 (`max_pending_per_ip`), or the address opened 30 in 10 s (`max_accepts_per_ip`, `ACCEPT_WINDOW_MS`). Entries are `{ws, since, host}`. |
| `tv_server.gd:374-392` (`_poll_pending`) | The first text frame of a pending socket goes to `_handle_hello`, then the entry is dropped from `_pending` (it joined or it was rejected). No `hello` in 5 s (`Protocol.HELLO_TIMEOUT_MS`) closes it. |
| `tv_server.gd:395-489` (`_handle_hello`) | In order: `t`, `v` (`version`), `room` (`bad_room`; empty only in a debug build), a replaced token (`kicked`/`replaced`), resume by token (a present slot with that token), a `pid` held by a connected phone (`kicked`/`replaced`, issue #388), a lost holder (`_replace_slot`, menu phases), a free slot (`full`), then the slot, the token (`Protocol.make_token`) and `welcome`. |
| `tv_server.gd:42`, `:493-499` | `phase` is `connect`, `menu`, `playing` or `paused`; `in_menu_phase()` is `connect` or `menu` (the Games, Settings, Players and game settings screens), `in_round()` is `playing` or `paused`. The game result menu is still `playing` (`scripts/game/minigame.gd`). |
| `tv_server.gd:301-307` (`kick`) | Sends `kicked`, frees the slot. The token is gone with the slot (REQ-FL-33). |
| `scripts/net/controller_client.gd:196-215` | State `JOINING` after the socket opens: sends `hello`; **closes the socket when no frame came for `HELLO_TIMEOUT_MS` (5 s)**. Any frame (also an unknown `t`) resets `_last_rx_ms`. `_handle` ignores an unknown `t` (the `match` has no default branch). |
| `controller_client.gd:270-274`, `:333-343` | `reject`: IDLE, `rejected(reason)`, no retry. `kicked`: IDLE, forgets the token, saves an empty token, no retry; any reason other than `replaced` becomes `kicked`. |
| `controller_client.gd:361-378` | A socket that closes before any `welcome` is retried up to `give_up_after` (3, or 1 for a typed code), then `unreachable`. |
| `scripts/app.gd:455-464` | Maps a reason to a text; `kicked` is `app.host_removed_scan_code` ("THE HOST REMOVED YOU. SCAN THE CODE TO JOIN AGAIN."); an unknown reason is `connect.refused` with the raw code. |
| `scripts/app.gd:35-42`, `:266-290` | `App.settings` (a Dictionary) is saved to `user://settings.cfg` by `save_settings()`: **every key of the dictionary is written**. `_load_settings` uses `ConfigIO.fit` (wrong type gives the default). |
| `scripts/ui/tv_settings.gd:48-108` | A generic on/off row (`_add_row`): Left OFF, Right ON, `App.settings[key] = on` and `App.save_settings()`; the key `overlay` has its own setter (`App.set_overlay`). |
| `scripts/ui/tv_modal.gd` | A modal: dim layer, double frame, focus held inside, controls under it suspended (`_suspend_focus_below`) and restored on `close()`; Back goes to `on_back()` through the screen. |
| `scripts/app.gd:236-247` (`_back`) | The Back key arrives as a key and as `NOTIFICATION_WM_GO_BACK_REQUEST`; `_back()` drops the second one within 250 ms and calls `on_back()` of the current screen. |
| `scripts/app.gd:341-349` | The phone app starts with the saved host and token (a reconnect), or with `--join=<host>` (an empty `room`, a debug TV only). |
| `docs/PROTOCOL.md`, "Version change" | `VERSION` changes when an old peer misreads a message or when a new message is one that the other side **waits for**. `VERSION` is 5. |
| Tests | Net suites (`net_limits`, `net_profiles`, `join_flow`, `r4_join_code`, ...) make a `TvServer` and call `start({})`. TV app suites (`r1_tv_screens`, `tv_flow_reqs`, `r4_tv_profiles`, `screenshots`, ...) boot the App as a TV and join with `ControllerClient` on 127.0.0.1. |

## 3. Decisions (FD-30.n)

Each decision has its reason. FD-30 is the owner's decision in `docs/TV_FLOW.md`; these are the technical decisions under it.

- **FD-30.1 A waiting phone lives in its own list `_waiting`, not in a slot and not in `_pending`.** A slot would show in the slot list, the badge and `players_in()`, and every game reads the slots; a request must not exist for the games (REQ-FL-94). `_pending` is "no `hello` yet" with a 5 s limit; a request has a `hello` and lives up to 180 s. The two lists share the limits of issue #387 (FD-30.8).
- **FD-30.2 The TV server owns the queue, the timers and the decisions; the UI only shows the head and calls `allow_request(id)` / `refuse_request(id)`.** The rules are then testable headless with no screen, and `scripts/net/` still refers to no UI and no game (it emits signals and exposes data, as it does for slots).
- **FD-30.3 `TvServer.approve_new` is `false` in the code; the App sets it from the setting.** Every test that makes a `TvServer` keeps the one-step join with no change, and the net layer does not read `App.settings`. The App setting `approve_players` is `true` by default (owner) and enters `App.settings` only in phase 4, so that no build ever saves a `false` default to `settings.cfg` (`save_settings()` writes every key; a phase that saved `false` would turn the owner's default OFF on every test TV for good).
- **FD-30.4 "Known token" means a token that this TV gave in this run of the TV app and did not revoke (owner, D11).** The TV keeps the tokens of the phones it welcomed in `_known_tokens` (memory only, at most 32, the oldest goes first). A `hello` with a known token joins with no card: to its own slot when the slot is still present (today's resume), else to a free slot as a returning player (a late joiner in a round, REQ-FL-25). Revoked: `kick` (REQ-FL-33), a `bye` from the phone (the player left), `_replace_slot` (issue #388). Kept: a lost slot that timed out, "Resume without 2P" (`drop_player`). Reason: the slot grace is 5 s (`SLOT_GRACE_MS`); a phone that is in the background for 10 s in the menu would ask the adult again, which the owner wanted to avoid ("a lost connection does not ask the adult again", issue #385). The token is 128 bits from `Crypto` (issue #388), so it is as safe as the resume of today. The `welcome` of a known-token join sends the same token again (the phone keeps it; it stays in `_known_tokens`). **Decided by the owner (D11, 2026-11-07): the wide rule.** The narrow rule (no card only inside the 5 s grace) was considered and not chosen (section 12, point 1).
- **FD-30.5 The checks that exist today run before the queue, and run again at the moment of the allow.** Before: room code, replaced token, resume, held profile (`kicked`/`replaced`, REQ-FL-74, issue #388), a full TV (`reject`/`full`). A request that cannot get a slot is never shown. At the allow: the held profile and the free slot are checked again (the room can change in 60 s), and the takeover of a **lost** holder (`_replace_slot`) happens only then, never at the request: a stranger who is not allowed must not free the slot of a lost child.
- **FD-30.6 Allowed is `welcome`. Every end without a slot is `kicked` with a reason: `refused`, `timeout`, `busy`.** `kicked` already means "no slot, forget the token, do not retry", and issue #388 already sends it to a phone that has no slot (`replaced`). An old phone maps any reason except `replaced` to `kicked` and shows "THE HOST REMOVED YOU. SCAN THE CODE TO JOIN AGAIN." in its own language: a clear, true enough text with the right action. A `reject` with a new reason would show the raw code ("Connection refused: timeout") on an old phone.
- **FD-30.7 The TV sends `{"t":"pending"}` when the request is queued and again every 2 s (`Protocol.PENDING_KEEPALIVE_MS`).** An old phone closes a `JOINING` socket after 5 s with no frame (`controller_client.gd:214`); any frame resets that clock, and the old phone ignores the unknown `t`. So the old phone waits as long as the TV wants, with no change to its code. The new phone uses the same frames to see that the TV is alive. 2 s is under half of 5 s, so one late frame on a weak Wi-Fi (gaps of 380 ms were measured, `change-protocol` step 5) does not drop the phone.
- **FD-30.8 Limits.** A request counts toward `MAX_PENDING` (16) and `max_pending_per_ip` (4) of issue #387. On top: at most 4 requests at one time (`MAX_WAITING`, REQ-FL-99; a fifth gets `busy`), at most **1 request for each address**: a new `hello` from an address that has a request **replaces** it (the old socket is closed with no message; the new one keeps the place in the queue, the arrival time and the card time; **but when the old request was already shown on the card, the new one gets a new id and `shown_ms` goes back to -1: the card shows again after the 1 s gap with the new name and avatar, and a late allow of the old id does nothing**). **Address key (security review of PR #397):** every per-address table (accept window, `_pending_of`, `_waiting_of`, the refusal table) uses `TvServer.address_key`: an IPv4-mapped IPv6 address is its IPv4 address, an IPv6 address is its /64 prefix (the first 4 groups), an IPv4 address and anything else stay as they are, so a device cannot get many keys by changing its IPv6 address. **Accepted limit:** phones behind one address (a NAT, a hotspot, 127.0.0.1 in tests) share one waiting request, the waiting cap and the refusal block. Reason: a real phone that retries after a Wi-Fi gap leaves a half-open socket that the TV cannot see (an old phone sends nothing while it waits); the replacement lets that phone in, and a rogue device can still hold only one card and cannot make its 60 s or its 180 s longer. **Refusal counter (owner, 2026-11-07):** one host refusal does not block. The TV counts the host refusals (REFUSE on the card; BACK does not refuse, D12) for each address; at the 3rd refusal in a row (`refuse_block_after`) the address is blocked for 60 s (REQ-FL-104, `refuse_block_ms`) and its counter goes back to 0, so after the block the address has 3 new chances. An allow of a request from the address sets the counter to 0. A timeout, a cancel by the phone (`bye` or a closed socket), a replacement by a newer `hello` and the setting turned OFF do not count and do not reset. A `hello` that arrives during the block gets `kicked`/`refused` (5.1) and does not count. The table is kept in memory for the run of the TV app and is bounded (section 4.6). Reason: a child who taps JOIN by mistake, or a parent who presses REFUSE by mistake, must not lock a family phone out for 60 s; 3 refusals in a row still stop a device that asks again and again.
- **FD-30.9 The card shows only in a menu phase, one at a time, 1 s after the last answer.** The head request is "shown" when `in_menu_phase()` is true and 1 s (`approval_gap_ms`) has passed since the last card closed. Its 60 s (`approval_timeout_ms`) counts from that moment. A request also ends as a timeout 180 s (`approval_total_ms`) after it arrived, shown or not (REQ-FL-96). When the phase goes to a round while a card is shown (no host key can start a round while the card holds the input, but the code must not trust that), the request goes back to "not shown" and gets a new 60 s at the next menu phase; the 180 s still bounds it.
- **FD-30.10 Turning the setting OFF refuses every waiting request (`kicked`/`refused`); it does not count toward the refusal counter and does not reset it; turning it ON changes nothing for the phones in the room.** This follows REQ-FL-102 (D2): nobody gets in without an answer of the host. The OFF refusal does not block, so the phone can join at once with one tap.
- **FD-30.11 `VERSION` stays 5.** Neither side waits for a new message: the phone waits for `welcome` as before, the TV waits for `hello` as before. `pending` is optional for the phone (FD-30.7), `kicked` exists, its new reasons fall back to the known text on an old phone (FD-30.6). By the rule of `docs/PROTOCOL.md` ("Version change") this is compatible. `LANG_REMOVE_AFTER_VERSION` is not touched.
- **FD-30.12 The card lives in a layer that the App owns, above the screens, not inside a screen.** A request can show on any menu screen (Connect, Games, Settings, a game settings view, the Players modal, About) and must survive a screen change. The App keeps one `JoinRequests` node (a `CanvasLayer`) and the Back key goes to it first (section 7).
- **FD-30.13 The phone never sends `hello` again while it waits, and does not retry after the wait ends.** A retry would make a new request at the end of the queue. A lost socket while waiting ends the join with the reason `wait_lost` (REQ-FL-103). CANCEL sends the existing `{"t":"bye"}`.
- **FD-30.14 No time is shown to the host and no message carries the remaining time (owner, 2026-11-07).** The card has no time text, no time bar and no update each second; `shown_request()` has no `ms_left`. The 60 s and the 180 s are server timers only. `pending` has no field for the time, and the phone shows no time either (REQ-FL-100 has none). Reason: the owner decision; it also removes the only part of the card that redraws while it waits (JA-R9).
- **FD-30.15 The card has two focusable buttons, ALLOW and REFUSE, and handles its own keys (owner, 2026-11-07, D12).** The buttons are `UiKit.item` menu items (`MenuItem`, the pixel cursor in front of the focused one, as in the approved mock and every TV menu), in one `HBoxContainer`, ALLOW first; the layout direction mirrors them in Hebrew (ALLOW at the right). The focus starts on ALLOW for every card. LEFT and RIGHT move the focus, OK activates the focused button. **BACK is ignored by the card, always** (in the first 1 s and after): it does not refuse, it does not close the card, and it does not reach `App._back()`'s screen path, so it never goes back, never quits and never closes a modal under the card (section 7.2, "BACK while a card shows"). A request ends only by ALLOW, REFUSE or the internal time limit (60 s shown, 180 s total). For its first 1 s the card also consumes OK, LEFT, RIGHT, UP and DOWN, so that a press meant for the menu neither answers the card nor moves the focus away from ALLOW, and never reaches the screen under it. The MENU key is not handled by the card: it does what it does today on the screen under the card. Reason: the owner's decision (BACK is not a clear answer for the host; the two buttons are); the buttons reuse the TV menu item (no new widget, the same focus look of REQ-FL-42, the sounds of REQ-FL-65b) and `TvModal` (REQ-FL-34).
- **FD-30.16 The Settings row "approve new players" is the first row (owner, 2026-11-07).** It gets the focus when the Settings screen opens. The order of the rows is code only: `settings.cfg` is read by key, so no saved order changes and no file needs a migration (section 7.3).

## 4. The join state machine on the TV

### 4.1 States of a connection

```
TCP accept ──(limits of #387)──> PENDING ──hello──> checks (4.2) ──┬─> SLOT (welcome)                     [approval OFF, known token]
   │                                │                               ├─> closed (reject / kicked / close)   [a check fails]
   └─ refused at once               └─ 5 s no hello: close          └─> WAITING ─┬─ allow: re-check ─┬─> SLOT (welcome)
                                                                                 │                   └─> closed (reject full / kicked replaced)
                                                                                 │   (allow: refusal counter of the address = 0)
                                                                                 ├─ REFUSE: kicked refused, counter + 1      (at 3: block 60 s, counter = 0)
                                                                                 ├─ 60 s shown, or 180 s total: kicked timeout (counter not changed)
                                                                                 ├─ setting OFF: kicked refused (counter not changed, no block)
                                                                                 ├─ replaced by a newer hello of the same address: close, no message
                                                                                 ├─ phone sends bye, or the socket closes: removed, no message (counter not changed)
                                                                                 └─ TV stops: bye
```

Refusal state of an address (section 4.6), kept for the run of the TV app:

```
COUNT n (0, 1, 2) ──host REFUSE──> COUNT n+1 ──(n+1 = 3)──> BLOCKED 60 s, counter 0 ──60 s passed──> COUNT 0
      │                                                        │
      └─ allow: COUNT 0                                         └─ hello: kicked refused, no card, not counted
      (timeout, cancel, socket closed, replaced, setting OFF: no change)
```

### 4.2 Order of the checks of a `hello` (the new code)

1. `t` is `hello`, else close (today).
2. `v` is `Protocol.VERSION`, else `reject`/`version` (today).
3. `room` is the room code (or empty in a debug build), else `reject`/`bad_room` (today, issue #388).
4. A replaced token inside its 10 min: `kicked`/`replaced` (today).
5. A token of a present slot: **resume, no card** (today).
6. A known token (FD-30.4) whose slot is gone: **join as a returning player, no card** (new; goes to step 8 with `needs_approval = false`).
7. A `pid` held by a connected phone: `kicked`/`replaced`, **before any approval** (issue #388, REQ-FL-74).
8. No free slot: `reject`/`full` (today). No card for a phone that cannot get a slot (REQ-FL-94, D9).
9. `approve_new` is false, or step 6 matched: the slot path of today (`_admit`), including the lost-holder takeover.
10. Else, the approval gate:
    1. The address is blocked (3 host refusals in a row, the last one less than 60 s ago, section 4.6): `kicked`/`refused`, no card, the counter is not changed.
    2. The address has a request: replace it (FD-30.8), send `pending`, stop.
    3. `_waiting.size() >= MAX_WAITING`: `kicked`/`busy`.
    4. Append `{id, ws, host, hello, arrived_ms, shown_ms = -1, last_keepalive_ms}` to `_waiting`, send `pending`, emit `requests_changed`.

`_handle_hello` is split into `_check_hello(ws, msg, now)` (steps 1 to 10) and `_admit(ws, msg, now, known)` (the slot path of today, lines 412 to 489, unchanged in behavior). `allow_request(id)` calls `_admit` with the stored `hello`: `_admit` repeats steps 7 and 8 by itself (it does today), and does the lost-holder takeover. The phase at the allow is always a menu phase, so the profile of the `hello` counts.

### 4.3 Each frame (`_process`)

Order matters, so that a phone that closed its old socket and opened a new one in the same frame is not seen as two requests:

1. `_closing.service`, address check (today).
2. **`_poll_waiting(now)`** (new, before the accept loop): poll each waiting socket; a closed socket or a `bye` removes the request (and closes its card); other frames are read and dropped (at most 8 frames for each socket in each frame, so a flood costs little; `MAX_TEXT_BYTES` and the buffer limits apply as today); send `pending` when 2 s passed; end with `timeout` at 60 s shown or 180 s total; pick the head to show (FD-30.9).
3. Accept loop: the limits use `_pending.size() + _waiting.size()` and `_pending_of(host) + _waiting_of(host)`.
4. `_poll_pending`, slots (today).

### 4.4 Events while a request waits

| Event | Result |
|-------|--------|
| The TV goes to a round (`set_phase("playing"/"paused")`) | The card closes (the request stays, "not shown"). `pending` goes on. No card during the round, countdown or result menu (they are all `playing`/`paused`). |
| The TV goes back to a menu phase | The head is shown 1 s later (or at once when no card closed in the last 1 s) with a new 60 s. |
| The phone sends `bye` (CANCEL) or its socket closes | The request is removed at once; its card closes; the next one shows 1 s later. No message to the phone. |
| The phone loses its Wi-Fi with no close | The TV cannot see it (an old phone sends nothing while it waits). The request ends by the 60 s or the 180 s, or by a newer `hello` of the same address (FD-30.8). An allow of a dead socket gives a slot that is LOST 3 s later (`PEER_TIMEOUT_MS`) and freed 5 s after that: the cost is one wrong slot for 8 s. |
| 4 phones joined while a request waits | At the allow: `reject`/`full` (REQ-FL-95). |
| The holder of the requested profile connected while the request waited | At the allow: `kicked`/`replaced` (REQ-FL-74). |
| The setting goes OFF | All requests: `kicked`/`refused`; the refusal counters do not change, no block (FD-30.10). |
| The host refuses (OK on REFUSE; BACK is ignored, D12) | `kicked`/`refused`; the counter of the address goes up by 1; at 3 the address is blocked for 60 s (4.6). |
| The host allows (OK on ALLOW) and the allow gives a slot (`welcome`) | The counter of the address goes to 0. An allow that ends in `reject`/`full` or `kicked`/`replaced` (the room changed) also sets it to 0: the host said yes to that address. |
| The request ends by `timeout` | The counter does not change. |
| The TV app stops (`stop()`) | Each waiting phone gets `bye` (the phone shows "THE TV APP CLOSED THE CONNECTION.", today's text for a TV that quits), sockets closed 300 ms later (issue #169). |
| The TV address changes | No change: the sockets stay as the slots do today. |

### 4.5 The TV server API (for the UI and the tests)

- `var approve_new := false`; `func set_approve_new(on: bool)` (OFF refuses the waiting requests, FD-30.10).
- `signal requests_changed()`: a request was added, removed, shown or hidden. The UI reads the state; the signal carries no data, so the UI never keeps its own copy of the queue.
- `func shown_request() -> Dictionary`: empty, or `{id, name, av, guest, slot_hint, others}` (no remaining time, FD-30.14). `name` is `Profile.clean_name` of the `hello` (empty for a phone with no name; the UI shows `players.default_name` with `slot_hint + 1`, the first free slot now), `av` is `Profile.clean_avatar` when the `pid` is valid, else -1. `others` is the number of other requests.
- `func request_count() -> int`.
- `func allow_request(id: int)`, `func refuse_request(id: int)`: do nothing for an id that is not shown (a key press that comes after a timeout).
- Settable for the tests, like `peer_timeout_ms`: `approval_timeout_ms` (60000), `approval_total_ms` (180000), `approval_gap_ms` (1000), `refuse_block_ms` (60000), `refuse_block_after` (3), `max_refusal_entries` (64), `max_waiting_per_ip` (1). Constant: `MAX_WAITING` (4), `MAX_KNOWN_TOKENS` (32). The time comes from `Time.get_ticks_msec()` as in the rest of the server; the tests use short values, as `net_loss` does for the grace.

### 4.6 The refusal table (owner decision 1)

- `_refusals: Dictionary`, address (String) to `{count, blocked_until_ms, touched_ms}`. Memory only; it is not cleared by a phase change, a screen change or the setting, only by the end of the TV app.
- Host refusal of a shown card (REFUSE calls `refuse_request`; BACK calls nothing, D12): `count += 1`, `touched_ms = now`. When `count >= refuse_block_after`: `blocked_until_ms = now + refuse_block_ms`, `count = 0`.
- Allow (ALLOW on a shown card): the entry of the address is erased (count 0 and no block is the same as no entry). When the address is blocked at that moment (not possible today: a blocked address has no request; the code does not trust that), the block stays.
- Blocked: `now < blocked_until_ms`. An entry with `count == 0` and an ended block is erased when it is read, so the table holds only addresses that have a live counter or a live block.
- **Bound:** at most `max_refusal_entries` = 64 entries (a home LAN has far fewer devices; each entry is a short string and three integers, a few kB in total). When a new address must be added and the table is full: first erase every entry with an ended block and `count == 0`; if it is still full, erase the entry with the oldest `touched_ms` that is **not** blocked; if every entry is blocked, erase the one whose block ends first. So a device with many addresses can at worst make the TV forget an old counter (the cost: that address gets its 3 chances again), never grow the memory, and it cannot lift a younger block.
- Timeout, cancel (`bye` or a closed socket), replacement by a newer `hello`, setting OFF: no access to the table.

## 5. Protocol

### 5.1 Messages

| From | Message | Meaning |
|------|---------|---------|
| TV | `{"t":"pending"}` | New. The TV has the `hello` and waits for the host. Sent when the request is queued and again every `PENDING_KEEPALIVE_MS` = 2000 ms until the end of the wait. The phone shows its waiting screen and sends nothing more (except `bye` for CANCEL). It has no field, and it carries **no remaining time** (FD-30.14: neither the TV card nor the phone shows a time). A later optional field (for example the place in the queue, or "a round runs", decision D7 of `docs/TV_FLOW.md`) is compatible, because the phone ignores fields that it does not know. Sent only by a TV whose setting is ON. |
| TV | `{"t":"welcome", ...}` | Unchanged. The host allowed the phone (or no approval was needed). |
| TV | `{"t":"kicked","reason":"refused"}` | New reason. The host refused (REFUSE), or the address is blocked (3 host refusals in a row, for 60 s; the `hello` gets this at once, with no card), or the setting was turned OFF while the phone waited. |
| TV | `{"t":"kicked","reason":"timeout"}` | New reason. 60 s with the card shown, or 180 s in total, with no answer. |
| TV | `{"t":"kicked","reason":"busy"}` | New reason. 4 requests already wait. |
| Phone | `{"t":"bye"}` | Unchanged message; new use: CANCEL on the waiting screen withdraws the request. |
| TV | `{"t":"bye"}` | Unchanged message; also sent to a waiting phone when the TV app stops. |

**What a blocked address gets: `kicked`/`refused`, not `busy`, and no new reason.** Reasons: (1) it is true: the host refused this address, and the phone shows `connect.approval_refused`, which tells the player to ask the host; `busy` would tell the player that others wait and invite a retry that is refused again. (2) No new reason means no new text and no new mapping: an old phone (VERSION 5) maps `refused` to `kicked` like every other new reason and shows "THE HOST REMOVED YOU. SCAN THE CODE TO JOIN AGAIN."; a new phone already knows `refused`. (3) It does not tell a rogue device when the block ends. `VERSION` stays 5 (FD-30.11): no message, field or wait is added by the counter; it is TV state only.

After a `kicked` the TV closes the socket 300 ms later (`_discard`, as today). `Protocol.MESSAGES` gets `"pending": "tv"`; `tests/protocol_doc.gd` then checks it against the tables of `docs/PROTOCOL.md` and the literals of the net code.

### 5.2 Old and new together

| Phone | TV | Setting | What happens |
|-------|----|---------|--------------|
| New | New | OFF | As today. The first frame after `hello` is `welcome` (no `pending`). |
| New | New | ON | `pending` (every 2 s), then `welcome` or `kicked` with `refused`, `timeout` or `busy`. The phone shows its waiting screen and then the pad or the text of the reason. |
| Old (VERSION 5, no `pending`) | New | ON | The old phone stays in `JOINING` and shows "CONNECTING..." (it ignores `pending`, but the frames keep its 5 s clock from closing the socket). Allowed: `welcome`, it plays normally. Refused, timeout, busy: it shows "THE HOST REMOVED YOU. SCAN THE CODE TO JOIN AGAIN.", forgets the token and does not retry. If its socket drops while it waits, it retries (today's code, at most 3 tries) and each try is a new request at the end of the queue, or replaces its own request when the address is the same (FD-30.8). |
| Old | New | OFF | As today. |
| New | Old | (none) | The old TV sends `welcome` at once. The new phone never sees `pending` and never enters its waiting state. CANCEL does not exist on that path. |
| Any VERSION other than 5 | any | any | `reject`/`version`, as today. |

**`VERSION` stays 5** (FD-30.11). A future `VERSION` 6 may drop the keepalive need (a v6 phone can wait with no frames) and may then also remove `lang` (`LANG_REMOVE_AFTER_VERSION`); that is not part of this work.

### 5.3 Changes of `docs/PROTOCOL.md` (phase 1, by `sw-developer` with this plan as the source)

- "Join" table: the rows `pending` and the three `kicked` reasons; a paragraph "Approval (FD-30)" with the order of the checks (4.2), the known tokens (FD-30.4), the limits (FD-30.8) and the timers (FD-30.9).
- "Messages after the join": the `bye` row says that a waiting phone may send it (CANCEL) and that a waiting phone gets it when the TV stops; the `kicked` rows say that `refused`, `timeout` and `busy` are sent to a phone that has no slot.
- "Limits of the TV": a waiting phone counts toward `MAX_PENDING` and `max_pending_per_ip`; `MAX_WAITING` 4; 1 request for each address; the 60 s block after 3 host refusals in a row from one address (`refuse_block_after`, `refuse_block_ms`), reset by an allow, not changed by a timeout or a cancel, at most `max_refusal_entries` 64 addresses kept; a blocked `hello` gets `kicked`/`refused`.
- "Slots, loss and reconnect": "A `hello` with an unknown token is a new player" gets "and needs the approval when the setting is ON"; the known tokens.
- "Version change": one sentence that `pending` keeps `VERSION` 5 and why (FD-30.7, FD-30.11).
- The text "the TV asks for nothing else" (section "Room code") gets "except the approval of the host when the setting is ON".
- `tests/protocol_doc.gd` checks the numbers that the document quotes: `PENDING_KEEPALIVE_MS` is in `protocol.gd`; the TV numbers (60 s, 180 s, 4, 1, 3 refusals, 60 s block, 64 entries) are quoted with their `TvServer` names, as `MAX_PENDING` is today.

### 5.4 Tests that prove old and new together (phase 1, `tests/join_approval.gd`)

The old phone is a **frozen copy** of `scripts/net/controller_client.gd` as it is on `main` before phase 1, in `tests/fixtures/controller_client_v5.gd` (with a header line: the commit it was taken from, and "delete when `VERSION` goes above 5"). It is a real old peer, not a mock: it has the old `JOINING` timeout and the old `kicked` mapping. It is not a module of `scripts/`, so it is not in the coverage.

1. Old phone, setting ON: after 6 s (more than `HELLO_TIMEOUT_MS`) it is still `JOINING`, and the largest gap between two frames it received is below 2500 ms. Then `allow_request`: it is `CONNECTED` with a slot and a token.
2. Old phone, refused / timeout (short `approval_timeout_ms`) / busy (4 requests already wait from 4 other test addresses, as in 6c): it is `IDLE`, `rejected` gave `kicked`, its token is empty, and it makes no new connection in the next 3 s (the accept count of its address does not grow).
3. Old phone, setting OFF: `welcome` is the first frame (today).
4. New phone, new TV, setting OFF: the first frame after `hello` is `welcome` and no `pending` is ever sent: this is the wire behavior of a TV of today, so the new phone against an old TV is the path that every current net suite already tests.
5. New phone, setting ON: `WAITING` after `pending`; `CONNECTED` after the allow; `rejected` gives exactly `refused`, `timeout`, `busy`; `wait_lost` when the TV socket goes silent for 5 s; `tv_closed` when the TV stops.
6. `Protocol.VERSION` is 5 and `protocol_doc` passes with `pending` in `MESSAGES` and in `docs/PROTOCOL.md`.
6a. The refusal counter (section 4.6, owner decision 1), with a short `refuse_block_ms`:
    - 1 and 2 refusals from one address: the next `hello` of that address gets `pending` and a card (no block).
    - 3 refusals in a row: the next `hello` gets `kicked`/`refused` with no `pending` and no `requests_changed`; after `refuse_block_ms` the next `hello` gets a card again.
    - 2 refusals, 1 allow, 2 refusals: no block (the allow reset the counter).
    - 2 refusals, then a timeout, a `bye` (CANCEL), a closed socket, a replacement by a newer `hello` and the setting OFF: the count is still 2; the next refusal blocks.
    - A blocked `hello` does not count: after the block ends, the address needs 3 new refusals.
    - Two addresses keep separate counters (2 refusals on each: no block on either).
    - The bound (with a small `max_refusal_entries`, for example 2, and addresses of 127.0.0.x): when the table is full, the address with the oldest counter that is not blocked starts again from 0 (one refusal does not block it), and a blocked address stays blocked. The tests check the behavior through `hello`, not the table.
    - An old phone (the frozen copy) against a blocked address: `IDLE`, `rejected` gave `kicked`, no retry.
6b. No remaining time on the wire (FD-30.14): `pending` has only the field `t`, and `shown_request()` has no time key.
6c. **The `busy` answer (REQ-FL-99, `MAX_WAITING` 4), headless only (A-34-4c).** 4 fake clients, each from a different test address (127.0.0.2 to 127.0.0.5, as the bound test of 6a), each make one request; a fifth client from a sixth address gets `kicked`/`busy` with no `pending` and no `requests_changed`; after one of the 4 requests ends, a new `hello` gets `pending` again. The manual Test 34 does **not** cover `busy`: with one request for each address (FD-30.8) it needs 5 devices, and the test has at most 3 phones. On macOS only 127.0.0.1 is up by default: when the extra loopback addresses are missing, the suite prints that it skips 6c and does not report a pass for it.
6d. **The known-token rule (FD-30.4, D11 decided: wide).** A phone joins, its slot is freed (it is away longer than `PEER_TIMEOUT_MS` + `SLOT_GRACE_MS`, short values in the test), and a `hello` with its token more than 5 s after the last frame gets `welcome` with the same token, with no `pending` and no `requests_changed` (no card), in a menu phase and in a round (a returning player, REQ-FL-25). The same after `drop_player`. The same token after `kick`, after the phone's `bye`, and after `_replace_slot` gets `pending` and a card; after 33 joins the token of the first one gets a card (the oldest is pushed out), the token of the 33rd does not. A new `TvServer` (a TV restart) does not know any token of the old one.
7. A real pair on devices (the `change-protocol` skill, step 6): Manual test 34, plus one step with an older controller build against the new TV (section 11).

## 6. Phone side

### 6.1 `scripts/net/controller_client.gd` (phase 1)

- `enum State` gets `WAITING` **at the end** (after `RECONNECTING`), so the numbers of the other states do not change (many lines in `scripts/` and `tests/` use the states, and a number that moves would break a test that compares numbers).
- `pending` in `JOINING` (or `WAITING`): state `WAITING`, `_last_rx_ms = now`. Nothing is sent.
- In `WAITING`: no ping, no sensor (as in `JOINING`); no frame for `HELLO_TIMEOUT_MS` (5 s): close the socket, state `IDLE`, `rejected("wait_lost")`, **no retry** (FD-30.13).
- `_on_closed()` in `WAITING` (the TV closed the socket with no message): the same as above, no retry.
- `welcome` in `WAITING`: as today (`CONNECTED`).
- `kicked`: the reasons `replaced`, `refused`, `timeout`, `busy` go out as they are; any other reason is `kicked` (today). The token is forgotten and saved empty (today), so a refused phone does not come back by itself at the next start.
- New `func cancel_wait()`: when `WAITING`, send `bye`, close, state `IDLE`, no `rejected` signal (CANCEL shows no message, REQ-FL-100). `leave()` already does this; `cancel_wait()` is `leave()` without the "kicked" side effects and is the call the UI uses.
- Token: while it waits the phone keeps the token it sent (a stale token that the TV did not know); the `welcome` gives the new one. Nothing else changes.

### 6.2 `scripts/ui/controller_connect.gd` and `scripts/app.gd` (phase 2)

- The waiting screen is a **state of the Connect screen**, not a new screen: `App._on_client_state` and `_show_phone_screen` change only for `CONNECTED` and `IDLE`, so a `WAITING` phone stays on the Connect screen with no new routing. In `WAITING` the screen hides the code row, JOIN and SCAN QR CODE, and shows the texts and the CANCEL box button of REQ-FL-100 and the mock (`docs/design-system/components/JoinApproval/`, screen `waiting`). It shows the active profile (slot color and avatar above the button, per the mock) from the client values.
- A join by a typed code: `pending` means that the right address answered, so `_candidates` is cleared at `WAITING` and `wait_lost` never tries the next address.
- CANCEL and the Android Back key (`on_back()` in `WAITING`) call `App.client.cancel_wait()`; the screen goes back to its normal state with no message. The quit dialog shows only outside `WAITING`.
- `App._on_client_rejected`: `refused`, `timeout`, `busy` and `wait_lost` map to their keys (section 10). The status line shows the text in `UiTheme.BAD` (today's path for `last_error`).
- No retry and no auto join: after a refusal or a timeout the phone stays on the Connect screen until the player taps JOIN or scans (REQ-FL-101).
- The app start with a saved token (`app.gd:341`) is unchanged: the token is known when the TV did not restart (no card), else the phone waits for the card like any new phone.

## 7. TV side UI

### 7.1 Where the card lives

- New `scripts/ui/join_requests.gd` (a `CanvasLayer`, layer above the screens and below the debug overlay) made by `App._start_tv()` and kept for the whole run. It connects to `server.requests_changed` and opens or closes one card. It is the only UI code that calls `allow_request` and `refuse_request`.
- New `scripts/ui/join_card.gd` extends `scripts/ui/tv_modal.gd` (the dim layer, the double frame, the focus held inside, `card_width` 1200, the 60 px safe margin of REQ-FL-81). It overrides `_build()` and builds the content of the approved mock: the title (`approval.title`), the avatar (the `Avatar` drawing of REQ-FL-70) and the name, the line `approval.wants`, the "+N WAITING" box (`approval.others_waiting`, only when `others` > 0), and the row of the two buttons. **No key hints and no key names** (owner, 2026-11-07). **No time text, no time bar and no update each second** (owner, FD-30.14): the card changes only on `requests_changed`; the 60 s and 180 s timers run in the server and the host does not see them. The name label has `auto_translate_mode` disabled (a player name is never a key) and the text direction of the name itself (a Hebrew name in the English UI and the reverse, REQ-FL-69); the card mirrors in Hebrew through the layout direction like every modal.
- **The buttons (FD-30.15).** `UiKit.item("approval.allow", _on_allow)` and `UiKit.item("approval.refuse", _on_refuse)`: the `MenuItem` of every TV menu (REQ-FL-41: the text and the pixel cursor in front of the focused item, mirrored in Hebrew; `focus_mode` `FOCUS_ALL`). They are in one `HBoxContainer` (ALLOW first, the gap of the mock, 160 px), centered, so the layout direction puts ALLOW at the left in English and at the right in Hebrew, as the mock does. The text colors follow the approved mock (ALLOW in `UiTheme.OK`, REFUSE in `UiTheme.BAD`, a font color override on each item); the word is the cue, the cursor marks the focus. `join_card.gd` therefore adds its line to `MEANING` of `tests/palette_lint.gd` (`[1, 1]`: OK is the allow action, BAD is the refuse action, REQ-GM-44). The card does not use `entries` of `TvModal` (that is a vertical text menu); it reuses `TvModal` for the frame, the dim layer, `_suspend_focus_below`, `first_focusable()` and `close()`, and `UiKit.focus_later(allow)` for the first focus (the same call as `default_index` of `TvModal._build`). No new widget class.
- `_on_allow()` and `_on_refuse()` check the age of the card (at least 1 s, the D6 lock) again before they act, then call `join_requests.allow(id)` / `refuse(id)`, which call the server. A press that comes before 1 s, or for an id that is no longer shown, does nothing (4.5).

### 7.2 Keys and focus

Who reads which key (owner decisions D6 and D12, FD-30.15). The rule in one sentence (the same as REQ-FL-97): **OK, BACK, LEFT, RIGHT, UP and DOWN are ignored for 1 s after a card shows; after that the card owns the arrows and OK activates the focused button; BACK stays ignored as long as a card shows; the MENU key is not handled by the card and does what it does today on the screen under it.** Godot calls `_input` from the last child to the first and from a child before its parent, then the GUI (the focused button), then `_unhandled_input`. The App keeps the layer the **last child** after every `App.go()` (`move_child(layer, -1)`), so the `_input` of the card runs before the `_input` of the screen, of a modal inside the screen (the Players modal) and of the App itself.

| Key | First 1 s after the card shows | After 1 s |
|-----|-------------------------------|-----------|
| OK (`ui_accept`: DPAD center, Enter) | `join_card._input` consumes it (`set_input_as_handled`): nothing happens, and it never reaches the screen under the card (the Connect and logo screens read OK in `_unhandled_input`, `tv_connect.gd:100`, `tv_logo.gd:100`). | `join_card._input` consumes the press and activates the focused button itself (`_on_allow()` / `_on_refuse()`). **Built so (phase 3, found by the test):** the GUI does not consume the press of OK on a `Button` (it acts when the key is let go), so the press would reach the `_unhandled_input` of the screen under the card (the Connect screen went on to Games). If the focus is not on a card button, the card puts it on ALLOW and consumes the press. |
| BACK (`ui_cancel`, `KEY_BACK`, `NOTIFICATION_WM_GO_BACK_REQUEST`) | Ignored (D12): nothing happens, no sound, the card stays, the focus stays. | Ignored, the same (D12). The card cannot be closed by BACK; only ALLOW, REFUSE or the internal time limit ends the request. How it is ignored: "BACK while a card shows", below. |
| LEFT, RIGHT | Consumed, no move: the focus stays on ALLOW at the moment the card can answer (a press meant for the menu cannot leave REFUSE focused). | `join_card._input` moves the focus itself (`find_valid_focus_neighbor` inside the card, then `grab_focus`) and consumes the event; at the edge it does nothing. Reason: a second `TvModal` under the card (the Players modal) would see a focus outside itself in its own `_input`, find no focusable control (the card suspended them) and consume the arrow, so the GUI move would never happen. The card handles the arrow before it can. The layout direction mirrors the move (RIGHT goes from ALLOW to REFUSE in English, LEFT does in Hebrew). |
| UP, DOWN | Consumed, nothing. | Consumed, nothing (one row of buttons; the card owns the arrows). |
| MENU (`KEY_MENU`), and F3 on a desktop | Not handled by the card: it does what it does today on the screen under the card (`App._input`, `app.gd:120`, shows or hides the debug overlay). | The same. |

**BACK while a card shows (D12).** BACK arrives in three forms, and each must stop at the card layer, so that it never reaches `App._back()`'s call of `_screen.on_back()` (that call goes back a screen, closes a modal such as the Players modal through the screen, or, on a screen with no `on_back`, calls `_quit()`):

1. `ui_cancel` (Escape, and the remote's BACK where it maps to `ui_cancel`) and 2. `KEY_BACK` as an `InputEventKey`: `join_requests._input` (the layer is the last child of the App, so its `_input` runs before `App._input`, before the `_input` of the screen and of any `TvModal` under the card) checks `is_open()` and, when true, calls `get_viewport().set_input_as_handled()` for a pressed `ui_cancel` or a pressed `KEY_BACK` (also echo), and then `App.note_back()`. `App._input` therefore never sees the event: no `_back()` call and no `back` sound from `_menu_sound`. `App.note_back()` is a new two-line public method that sets `_last_back_ms = Time.get_ticks_msec()`; it is needed so that the notification of the same press (it can come up to 250 ms later, `app.gd:236-247`) is dropped by the 250 ms rule even when the card closed between the two events (a REFUSE or a timeout in that moment).
3. `NOTIFICATION_WM_GO_BACK_REQUEST` (Android, `App._notification`): it is not an input event and cannot be consumed. `App._back()` gets one new check **after** the 250 ms check and the stamp of `_last_back_ms`, and **before** the `_screen.on_back()` / `_quit()` branch: `if join_requests != null and join_requests.is_open(): return`. So the notification also does nothing while a card shows, and the stamp drops a later duplicate.

The check uses `is_open()` of the layer (a card is shown), not a phase or a screen. Between two cards (the 1 s gap of FD-30.9), and with no card, BACK does what it does today on every screen: the TV's BACK behavior outside the card is unchanged. `JoinRequests` has no `on_back()` (the earlier draft's `on_back()` that refused is dropped). REQ-FL-34 says "Back closes the modal" for the Players modal; the card is the exception that the owner decided (D12), and `docs/TV_FLOW.md` REQ-FL-34 says so (by the `product-engineer`).

Sounds (REQ-FL-65b): LEFT and RIGHT play `move` when the focus moved (the card plays it, because it consumed the event before `App._menu_sound`). ALLOW plays `join` (the server signal `player_joined` already plays it; the card plays nothing more). REFUSE plays `denied`. BACK plays nothing (it is consumed before `App._menu_sound`, and the notification path has no sound). `App._menu_sound` needs no change: the card consumes OK in `_input`, so the App never sees it and plays no `select` (phase 3). A press in the first 1 s plays nothing.
- **Focus**: the focus starts on ALLOW for every card (`UiKit.focus_later`, D12). The card suspends the focus of the controls under it (`TvModal._suspend_focus_below`) and gives it back on close. When a screen changes while a card is open (the logo screen goes on to Connect when OK is pressed; it did so by itself after 2 to 3 s until 2026-11-10), `App.go()` calls `join_requests.on_screen_changed()`, which suspends the controls of the new screen too, so its `focus_later` cannot take the input from the card. When the card closes the focus goes back to the control that had it (TvModal) or, after a screen change, to the first item of the screen. When a new card follows (the next request, 1 s later), it is a new `JoinCard` and the focus starts on ALLOW again. When only `others` changes, the card updates its "+N WAITING" label in place and keeps the focus where it is.
- **REQ-FL-34 rules kept:** the controls under the dim layer cannot take the focus (`_suspend_focus_below`), the arrows move only inside the card, BACK goes to the card first. The differences from the Players modal (D12): the focus starts on ALLOW (the action of the card), not on Close (the card has no Close), and BACK does not close the card (it is ignored).
- **Over another modal** (the Players modal, the quit dialog of the Connect screen): the card is a second modal on top; it suspends the controls of the first one and gives them back. BACK stops at the card layer (above), so it never closes the modal under it and never quits from the quit dialog. The arrows are handled by the card before the lower modal sees them (table above).
- **The pause card**: no interplay. A pause is the phase `paused`; the card never shows in a round (FD-30.9), and the pause card of the game never shows in a menu phase.
- **Logo screen at the first start** (language choice, REQ-FL-60): the phase is `connect`, so a card can show over it (only a phone with a saved token of an older session can ask that early). The language choice waits under the card. This is acceptable and needs no special case.

### 7.3 The Settings row (phase 4)

- `App.settings` gets `"approve_players": true` (FD-30.3). `_start_tv()` sets `server.approve_new = bool(settings.approve_players)` before `server.start()`.
- `App.set_approve_players(on)` (like `set_overlay`): `settings.approve_players = on`, `save_settings()`, `server.set_approve_new(on)`.
- `tv_settings.gd`: `_add_row(rows, "settings.approve_players", "approve_players", Callable())` is the **first** `_add_row` call, before `settings.debug_overlay` (owner, 2026-11-07, FD-30.16; the approved mock shows it first and focused). The on/off branch calls `App.set_approve_players(on)` for this key (as it does for `overlay`).
- **Focus walk.** `UiKit.focus_later(_rows[0])` stays: the new row gets the focus when Settings opens. Down walks approve, Debug overlay, Invert tilt axes, Music, Effects, Language, About, Back. The rows are 6 in a debug build (they were 5) and 5 in a release build, which has no Debug overlay row (owner, 2026-11-18); 6 rows of 120 px and the gaps still scroll with the focus (REQ-FL-23). Language stays the last row.
- **Saved order.** None: `settings.cfg` is a ConfigFile read by key (`_load_settings`, `ConfigIO.fit`), and the row order lives only in `tv_settings.gd`. No migration.
- **Tests that read the rows by index** (phase 4 changes them; each uses the row by its title key from now on, through one small helper in the suite, so that a later row cannot shift them again):
  - `tests/screens_sweep.gd:280-289`: `rows[0]` is now the approve row. As written, its Right and Left would set `approve_players` and **save it to the settings file of the machine** and the overlay checks would fail. It must take the Debug overlay row.
  - `tests/r4_tv_menus.gd:157`: `_rows[1]` (Invert tilt axes) becomes the third row.
  - `tests/audio.gd:357`, `:668` (`rows.size() == 5`, the message "5 rows (debug, invert, music, effects, language)") become 6 rows with the new name first; `:359`, `:367-388`, `:677-712` (`rows[2]` Music, `rows[3]` Effects, `rows[4]` Language), `:630` (`_rows[1]`) and `:665` (`titles[2]`, `titles[3]`) move by one.
  - `tests/smoke_lang.gd:352-358`: `_rows.size() == 5` and `_rows[4]` (Language) become 6 and the Language row.
  - `tests/focus_walk.gd:293-330`: no change is needed (it uses the last row for Language, `seen.size() >= 4`, and the 120 px check covers the new row); it gets one new check: the first focus of Settings is the approve row.
  - `tests/screenshots.gd:97-99`: the `settings` shot shows the new first row (no reference image; the pixel checks of the phase compare it with the mock in both languages).
- **Default and file:** `tests/config_files.gd` (it tests `App._load_settings`; `tests/smoke_settings.gd` tests the game settings views, not `App.settings`): a file with no `approve_players` key loads `true`, a text or an Array loads `true`, `false` is kept.
- The phone does not need the setting and the protocol does not carry it. The TV sends nothing about it.
- A `settings.cfg` without the key loads as `true`; a value of another type loads as `true` (`ConfigIO.fit`).

## 8. The `--join` debug path and the tests that join with no approval

- `--join=127.0.0.1` (a phone on a desktop, `app.gd:352`) is not a bypass: it sends an empty `room`, which only a debug TV accepts (issue #388), and then the approval applies as for any phone. The developer presses Enter on the TV window (ALLOW has the focus). No debug flag skips the approval: a bypass in debug builds would hide the bugs of this feature from every desktop run.
- Net suites (`net_*`, `join_flow`, `r4_join_code`, `r4_phone_profiles`, ...) make their own `TvServer`: `approve_new` is false by default (FD-30.3), so they need no change in any phase.
- TV app suites boot the App, which sets `server.approve_new` from `App.settings` from phase 4. Each of them sets `_app.server.approve_new = false` right after the App starts (memory only; nothing is saved, so the settings file of the machine is not touched). The suites known on 2026-11-07 that join a phone through the TV App: `r1_tv_screens`, `tv_flow_reqs`, `r4_tv_profiles`, `screenshots`, `screens_sweep`, `focus_walk`, `auto_r3_tv`, `r4_tv_menus`, `audio`, `smoke_lang`, `design_tokens` (the `automation-developer` checks the full list with a search for `ControllerClient.new` and `connect_to(` in the suites that boot the App). The suites have no shared App boot helper today (`tests/game_helpers.gd` is a suite, not a helper), so the line goes in each suite, or in a new helper if the `automation-developer` prefers one.
- The approval suites set `approve_new = true` (net) or `App.set_approve_players(true)` with the settings file saved and restored as `r1_tv_screens.gd:169-196` does.

## 9. Security

What the approval stops: a device on the same Wi-Fi that builds the room code and joins (issue #385). What it does not stop: a device that reads the traffic. The traffic stays plain WebSocket (FD-28); a device that can read it can copy a token and resume as that player with no card (a known token, FD-30.4). This was true before (resume by token) and needs a capture of the Wi-Fi traffic, not just the room code. `docs/RISKS.md` C6 says it after phase 4.

Flooding and spam, with the limits that apply:

| Attack | Bound |
|--------|-------|
| Many connections that never send `hello` | `MAX_PENDING` 16, 4 for each address, 30 accepts for each address in 10 s (issue #387). Requests count toward 16 and 4. |
| Many `hello` from one device to fill the queue | 1 request for each address (FD-30.8): the device holds one card, and each new `hello` only replaces its own request (same place, same timers; it cannot make its wait longer; a shown request is replaced by a new id that shows again after the gap). |
| The same device asks again and again after a refusal | After 3 host refusals in a row the address is blocked for 60 s: `kicked`/`refused` with no card (REQ-FL-104, owner decision 1). So one address costs the host at most 3 refusals each 60 s (plus the 1 s gap between cards). A timeout does not count, so a device that waits for the timeout costs the host nothing but 60 s of one card; the limit of 1 request for each address holds it to one card. |
| Many addresses fill the refusal table | At most `max_refusal_entries` 64 entries; the oldest entry that is not blocked goes first (4.6). Memory is bounded; the worst case is that an old counter is forgotten. |
| A device with many addresses fills the 4 places | A real phone then gets `busy` for at most 180 s; the host refuses each card (3 refusals block an address). Turning the setting OFF would let the device in; the host can kick it (REQ-FL-33). Accepted: it needs several addresses on the network and is a nuisance, not a data leak. |
| A crafted name or avatar on the card | `Profile.clean_name` (letters, digits, space, 10 characters) and `Profile.clean_avatar`; the label never translates the name (7.1). |
| A waiting socket that sends a flood of frames | At most 8 frames read for each socket in each frame, `MAX_TEXT_BYTES`, `BUFFER_BYTES` and `MAX_QUEUED_PACKETS` as for the slots. |
| A stranger frees the slot of a lost child by sending its `pid` | The lost-holder takeover runs only at the allow (FD-30.5); with the setting ON a stranger is never allowed without the host. |

The `security-reviewer` reviews phases 1 and 4 (network input and a saved setting).

## 10. Docs, strings, legal texts

### 10.1 Documents (each in the PR of its phase, `sync-docs`)

The documents and tests that this feature makes wrong when it is built (not in the plan PR; each in the PR of the phase that makes it wrong):

- `docs/TV_FLOW.md` REQ-FL-8 (the 5 s grace is not the only return with no card: a known token also returns with no card, D11), FD-5 (phones join at any time; with the setting ON a new phone waits for the card, and in a round until the next menu phase), REQ-FL-34 (the modal rules: a second modal over the Players modal, the focus on ALLOW, not on Close, and BACK does not close the card, D12): phase 1 (REQ-FL-8), phase 3 (REQ-FL-34), phase 4 (FD-5, when the default is ON).
- `docs/REQUIREMENTS.md` REQ-A4 (join in one step) and the security lines: phase 4.
- **The "Planned (issue #393)" one-line notes** that the `product-engineer` adds now to REQ-FL-8, REQ-A4 and REQ-FL-34: each phase that builds the change replaces its note with the new text and removes the "Planned" mark (REQ-FL-8 in phase 1, REQ-FL-34 in phase 3, REQ-A4 in phase 4). The same for the notes on REQ-FL-23 and REQ-FL-25.
- `tests/config_files.gd`: the planned test of REQ-FL-93 (the default ON, a file with no key, a wrong type, `false` kept; section 7.3): phase 4.
- `docs/PROTOCOL.md`: phase 1 (5.3).
- `docs/MANUAL_TESTS.md` tests 1, 7, 8b, 20 and 21 (their join steps): phase 4 (below).
- `README.md`: phase 4 (below).
- Owner only: the privacy notice and the store texts (10.2): phase 4 names them and carries `needs-owner`.

What each phase changes in each document:

- `docs/PROTOCOL.md`: phase 1 (5.3).
- `docs/TV_FLOW.md`: the statuses of REQ-FL-93 to 104 move from Planned with each phase; FD-30 gets "built"; the align points of section 12 (by the `product-engineer`); REQ-FL-8, FD-5 and REQ-FL-34 as above.
- `docs/REQUIREMENTS.md`: REQ-A4 (join in one step) and the security lines say the approval (phase 4).
- `docs/AUTOMATED_TESTS.md`: the new suites (`join_approval`, `join_approval_tv`) and the A- rows they replace, each phase.
- `docs/MANUAL_TESTS.md`: Manual test 34 exists (Not run). Phase 4: the Summary and "Tests to run, in order" rows; the join steps of the tests that join a phone (tests 1, 7, 8b, 20, 21, per the list of `docs/TV_FLOW.md`) say "press OK on the card (ALLOW has the focus)" or "turn the setting OFF first"; test 34 step 1a checks that the approve row is the first Settings row, has the focus when Settings opens, and is ON on a new settings file. One new step for the old-build pair (5.4 item 7) in test 34.
- `README.md`: how a phone joins and the Settings rows (phase 4).
- `docs/RISKS.md`: C6 "No authentication" becomes "approval by the host, default ON; a device that reads the traffic can still copy a token" (phase 4; the architect writes it).

### 10.2 Privacy notice and store texts (owner only; phase 4 names them and carries `needs-owner`)

- `docs/legal/privacy-notice.md` and `.he.md`, section 3: **done 2026-11-08, applies the owner's decision of 2026-11-08 (issue #385):** the sentence "There is no PIN or password: anyone on the same network ... can join the game" is replaced by a short sentence that the host can approve or refuse every join request (the owner asked for the short version and no mention of a PIN or password). The sentence on the unencrypted traffic stays true. Note: with "approve new players" OFF anyone on the network can still join; the notice no longer says so (the owner's wording).
- Section 2, the table: the row "Settings" (on the TV) held "approve new players" (since the owner's edit of 2026-11-09 it says "your choices in the apps", with no list); the row "Name, avatar and scores ... on the TV, in memory only" now also covers a phone that waits for approval (its name and avatar show on the card, memory only). No new data, nothing saved about a phone.
- `docs/legal/store-listing-draft.md`: no sentence is false today; the owner may add that the host lets each phone in (a feature for parents). Not required.

### 10.3 Strings (keys only; the `product-engineer` writes the texts, the `localization-reviewer` reviews)

The proposed rows are in `docs/TV_FLOW.md` ("Proposed strings"). The keys the code needs:

- TV, phase 3: `approval.title`, `approval.wants`, `approval.allow`, `approval.refuse`, `approval.others_waiting`, `approval.one_waiting`. The keys `approval.hint_ok` and `approval.hint_back` are gone (the card has buttons, no key hints, owner decision 4), and no time key (`approval.time_left` is dropped, owner decision 2). `approval.allow` and `approval.refuse` are the texts of the two buttons.
- TV, phase 4: `settings.approve_players`.
- Phone, phase 2: `connect.waiting_approval` ("WAITING FOR THE HOST TO GET YOU IN." / "ממתינים שהמארח יאשר אתכם.", **approved by the owner** 2026-11-07), `connect.waiting_approval_hint` (**proposal**: "ASK THE HOST TO ALLOW YOU ON THE TV."; the Hebrew of the approved mock is "בקשו מהמארח לאשר אתכם בטלוויזיה."; the `localization-reviewer` reviews both; the old proposal "ASK THE HOST TO PRESS OK ON THE TV." is gone, because the card has no OK hint), `connect.approval_cancel`, `connect.approval_refused`, `connect.approval_timeout`, `connect.approval_busy`, and the text for `wait_lost` (REQ-FL-103 reuses `connect.room_not_found`; see section 12).
- Reused, no change: `common.on`, `common.off`, `players.default_name`, `app.player_already_in_room`, `app.room_full_4_players`, `app.tv_closed_connection`, `app.host_removed_scan_code` (what an old phone shows for `refused`, `timeout` and `busy`).

## 11. Phases (one PR each, stacked: phase n is based on phase n-1)

Every phase is shippable: after phase 1 to 3 a user sees no change, because the approval is off in the App until phase 4.

| Phase | Content | Files | Tests | Manual test |
|-------|---------|-------|-------|-------------|
| 1. TV server, protocol, phone client | FD-30.1 to 30.11, 30.13, 30.14 (no time in `shown_request` or `pending`); sections 4 (with the refusal table of 4.6), 5, 6.1. `approve_new` false in the code; the App does not set it. The wide known-token rule (FD-30.4, D11). The exact list is in section 11.1. | `scripts/core/protocol.gd` (`MESSAGES.pending`, `PENDING_KEEPALIVE_MS`), `scripts/net/tv_server.gd`, `scripts/net/controller_client.gd`, `docs/PROTOCOL.md`, `tests/join_approval.gd` (new), `tests/fixtures/controller_client_v5.gd` (new, frozen), `tests/suites.txt`, `tests/net_limits.gd` (requests count toward the pending limits), `tests/protocol_doc.gd` (if a number check needs a line), `docs/AUTOMATED_TESTS.md`, `docs/TV_FLOW.md` (statuses) | `join_approval` (all rules of section 4, the pairs of 5.4, the refusal counter and its bound of 5.4 item 6a, no time on the wire of 6b, `busy` with 4 fake clients of 6c (A-34-4c), the known-token rule of 6d), `net_limits`, `net_profiles`, `protocol_doc`, `join_flow`, `net_loss`; the `qa` decides on the whole suite (a change of the net). | none (headless only) |
| 2. Phone UI | Section 6.2. The waiting state of the Connect screen, CANCEL and Back, the texts of the reasons. | `scripts/ui/controller_connect.gd`, `scripts/app.gd` (`_on_client_rejected`), `assets/lang/strings.csv` (phone rows), `tests/r4_join_code.gd` or a new `tests/join_approval_phone.gd` (states and texts with a TvServer with `approve_new = true`), `tests/smoke_lang.gd`, `tests/screenshots_controller.gd` (the waiting screen), `docs/TV_FLOW.md`, `docs/AUTOMATED_TESTS.md` | the touched suites; pixel checks of the phone screen in both languages | test 34 steps for the phone (Not run until phase 4) |
| 3. TV card | Sections 7.1, 7.2 (FD-30.15). `join_requests.gd` and `join_card.gd` (a `TvModal` with the two `UiKit.item` buttons ALLOW and REFUSE), the App layer, BACK ignored while a card shows (the layer's `_input` consumes `ui_cancel` and `KEY_BACK` and calls `App.note_back()`; `App._back()` returns while `join_requests.is_open()`, 7.2), `go()` keeps the layer last, `_menu_sound` quiet for OK while the card is open, sounds. Reached only with `server.approve_new = true` (tests). | `scripts/ui/join_requests.gd` (new: the layer, `is_open()`, `allow(id)`, `refuse(id)`, `on_screen_changed()`, the BACK consumer in `_input`), `scripts/ui/join_card.gd` (new), `scripts/app.gd` (`join_requests` member made in `_start_tv()`, `note_back()`, the `is_open()` check in `_back()`, `go()`, `_menu_sound`), `assets/lang/strings.csv` (TV card rows `approval.title`, `approval.wants`, `approval.allow`, `approval.refuse`, `approval.others_waiting`, `approval.one_waiting`), `tests/join_approval_tv.gd` (new), `tests/palette_lint.gd` (the `MEANING` line of `join_card.gd`), `tests/screens_sweep.gd`, `tests/design_tokens.gd` (sizes, margin), `tests/suites.txt`, `docs/AUTOMATED_TESTS.md`, `docs/TV_FLOW.md` | `join_approval_tv`: (a) the focus is on ALLOW when the card shows, and on ALLOW of the next card; (b) RIGHT moves it to REFUSE and LEFT back in English, mirrored in Hebrew; UP and DOWN do nothing; at the edge nothing; `move` plays only for a real move; (c) OK on ALLOW after 1 s allows (`welcome`, `join`, no `select`); OK on REFUSE after 1 s refuses (`kicked`/`refused`, `denied`); (d) OK, BACK, LEFT, RIGHT, UP and DOWN in the first 1 s do nothing: the focus is still on ALLOW at 1 s, no answer, no sound, and the Connect screen under the card does not go on to Games (its `_unhandled_input` never sees the OK); (d2) MENU with a card open (in the first 1 s and after) is not handled by the card: it shows or hides the debug overlay as today, and the card stays open with no answer; (e) **BACK does nothing while a card shows (D12):** at 0.5 s and at 2 s after the card shows, BACK in each form (`ui_cancel`, a `KEY_BACK` key event, `NOTIFICATION_WM_GO_BACK_REQUEST`, and the key plus the notification of one press): the card is still open, the request is still shown (`request_count()` unchanged, no `kicked` at the phone), the focus is on the same button, no sound, the current screen is the same object (no `go()`), `quit_hook` is not called (a test hook that records the call), and the refusal counter of the address is unchanged (3 later REFUSE presses are still needed for the block); on a screen with no `on_back` the App does not quit; (e2) after the card closes (ALLOW), BACK does what it does today on the screen under it (the Games screen goes back to Connect), and the notification of a BACK key consumed less than 250 ms before the close is dropped; (f) the card over the Players modal: LEFT and RIGHT move the focus of the card (the lower modal does not eat them), BACK does nothing and the Players modal stays open under the card, its focus comes back on close; the same over the quit dialog of the Connect screen (BACK does not quit); (g) a screen change under the card; (h) no card in a round; (i) 3 refusals on cards of one address (REFUSE, REFUSE, REFUSE, with BACK presses between them that change nothing) give the block and a fourth `hello` shows no card; (i2) a card with no answer ends by the internal limit (short `approval_timeout_ms`): the card closes, the phone gets `kicked`/`timeout`, and BACK then works on the screen as today; (j) the card shows no time and its text does not change while it waits with no event; (k) the card has no key name and no hint text (no label with OK or BACK). Also `palette_lint`, `screens_sweep`, `design_tokens`; pixel check of the card in English and Hebrew against the approved mock | none yet |
| 4. Setting, default ON, docs | Section 7.3 (FD-30.16), section 8 (TV app suites set the approval off), section 10.1 and 10.2. `TvServer.approve_new` is written only through `set_approve_new` (the App must call the setter, never assign the member). | `scripts/app.gd` (`approve_players`, `set_approve_players`), `scripts/ui/tv_settings.gd` (the row **first**, before Debug overlay), `assets/lang/strings.csv` (`settings.approve_players`), the TV app suites of section 8, the suites that read the Settings rows by index (7.3: `screens_sweep`, `r4_tv_menus`, `audio`, `smoke_lang`, `focus_walk`), `tests/config_files.gd` (default ON, saved, a file with no key, a wrong type), `README.md`, `docs/MANUAL_TESTS.md` (Summary, order, join steps), `docs/AUTOMATED_TESTS.md`, `docs/REQUIREMENTS.md`, `docs/TV_FLOW.md`, `docs/RISKS.md` (C6). Owner only, named in the PR with `needs-owner`: `docs/legal/privacy-notice.md`, `.he.md`. | the touched suites and the whole suite (the `qa` decides; many TV suites change) | Manual test 34 (a real remote, 2 phones; one step with an older controller build) |

### 11.1 Phase 1: what it implements (the start list for `sw-developer`)

Nothing in phase 1 waits for the owner (D11 is decided: the wide rule). No user-visible change: `approve_new` is `false` in the code and nothing in `scripts/app.gd` or `scripts/ui/` sets it. No string row, no `VERSION` change.

**Files.**

| File | Change |
|------|--------|
| `scripts/core/protocol.gd` | `MESSAGES` gets `"pending": "tv"`; new `const PENDING_KEEPALIVE_MS := 2000`. `VERSION` stays 5, `HELLO_TIMEOUT_MS` stays 5000. |
| `scripts/net/tv_server.gd` | The members below; `_handle_hello` split into `_check_hello` and `_admit` (4.2); `_poll_waiting` in `_process` before the accept loop (4.3); the accept limits count `_waiting` (FD-30.8); token revocation in `kick`, the `bye` branch of `_handle_control` and `_replace_slot`; `set_phase` to a round hides the shown card; `stop()` sends `bye` to each waiting phone (`_discard`, 300 ms) and clears `_waiting`, `_known_tokens` and `_refusals`. No reference to `scripts/game/` or `scripts/ui/`. |
| `scripts/net/controller_client.gd` | Section 6.1: `State.WAITING` appended at the end of the enum; `pending` handling; the 5 s silence in `WAITING` gives `rejected("wait_lost")` with no retry; `_on_closed()` in `WAITING` the same; `kicked` passes `refused`, `timeout`, `busy` (and `replaced`) through; new `cancel_wait()`. |
| `docs/PROTOCOL.md` | Section 5.3 (`change-protocol` skill). |
| `tests/join_approval.gd` (new) | Below. |
| `tests/fixtures/controller_client_v5.gd` (new, frozen) | A copy of `scripts/net/controller_client.gd` at the base commit of phase 1, with the header line of 5.4. |
| `tests/suites.txt` | `tests/join_approval.gd|controller|join approval: queue, limits, refusal counter, known tokens, old and new phone (issue #393)|unit` |
| `tests/net_limits.gd` | A waiting request counts toward `MAX_PENDING` and `max_pending_per_ip` (16 and 4); a 17th connection is closed at once with 16 requests and pending sockets together. |
| `tests/protocol_doc.gd` | Only if a number check needs a line (`PENDING_KEEPALIVE_MS`, the `TvServer` names of 5.3). |
| `docs/AUTOMATED_TESTS.md` | The `join_approval` row and the A- rows it covers (A-34-4c). |
| `docs/TV_FLOW.md` | Status notes of REQ-FL-94, 95, 96, 98, 99, 102, 104 (the server part is built; the UI part is still Planned) and the REQ-FL-8 note (10.1); by the `product-engineer` or `sw-developer` with `sync-docs`. |

**New `TvServer` members (public).**

- `signal requests_changed()`.
- `var approve_new := false` (FD-30.3; **false in the code**), `func set_approve_new(on: bool) -> void` (OFF: every waiting phone gets `kicked`/`refused`, the refusal table is not touched, `requests_changed`).
- `var approval_timeout_ms := 60000`, `var approval_total_ms := 180000`, `var approval_gap_ms := 1000`, `var refuse_block_ms := 60000`, `var refuse_block_after := 3`, `var max_refusal_entries := 64`, `var max_waiting_per_ip := 1`.
- `const MAX_WAITING := 4`, `const MAX_KNOWN_TOKENS := 32`.
- `func shown_request() -> Dictionary` (`{id, name, av, guest, slot_hint, others}` or empty; no time key), `func request_count() -> int`, `func allow_request(id: int) -> void`, `func refuse_request(id: int) -> void` (both do nothing for an id that is not shown).

**New `TvServer` members (private).** `_waiting: Array` (entries `{id, ws, host, hello, arrived_ms, shown_ms, last_keepalive_ms}`), `_next_request_id := 1`, `_last_card_end_ms` (for the 1 s gap), `_known_tokens: Array[String]` (oldest first, at most `MAX_KNOWN_TOKENS`), `_refusals: Dictionary` (4.6); `_check_hello(ws, msg, now)`, `_admit(ws, msg, now, known: bool)`, `_poll_waiting(now)`, `_waiting_of(host) -> int`, `_end_request(index, reason)` (sends `kicked` with the reason, or nothing for a cancel or a replacement; closes; emits `requests_changed`), `_remember_token(token)`, `_forget_token(token)`, `_is_blocked(host, now) -> bool`, `_count_refusal(host, now)`, `_clear_refusals(host)`. The names are a proposal; the behavior is the contract.

**Known tokens (D11, FD-30.4).** Every `welcome` (a new join, a resume and a known-token join) adds its token to `_known_tokens` (moved to the end when it is already in; the first one is removed above 32). A `hello` whose token is in `_known_tokens` and has no present slot goes to `_admit` with `known = true` and the same token (no `make_token`): no card, in a menu phase and in a round. `kick`, the phone's `bye` and `_replace_slot` call `_forget_token` before the slot is reset. A slot freed by the grace timeout and `drop_player` keep the token. `_replaced_tokens` (step 4) is checked before the known tokens, as today.

**Messages.** TV to phone: `{"t":"pending"}` (at the queueing and every 2 s, only with `approve_new`), `{"t":"kicked","reason":"refused"|"timeout"|"busy"}` (to a phone with no slot), `{"t":"bye"}` (to a waiting phone at `stop()`). Phone to TV: `{"t":"bye"}` while waiting (`cancel_wait()`). `welcome`, `reject` and `hello` do not change.

**Tests of `tests/join_approval.gd`** (a `TvServer` on its own port with `approve_new = true` and short timers, fake `WebSocketPeer` clients and the real `ControllerClient`):

1. The rules of section 4: the order of the checks of 4.2 (a wrong room, a replaced token, a held `pid`, a full TV each give today's answer and 0 requests); a new phone: 0 slots used, 1 request, `pending`; allow: `welcome`, 1 slot; refuse: `kicked`/`refused`; no card shows in `playing` or `paused`, the head shows 1 s after the phase goes to `menu`, and a card shown when the phase goes to a round goes back to "not shown"; the 60 s shown and the 180 s total give `kicked`/`timeout`; the 1 s gap between two cards; a second `hello` of the same address replaces the request (same place and `arrived_ms`, the old socket closed with no message; the same id while the request was not shown, a new id and a card that shows again after the gap when it was shown); a `bye` and a closed socket remove the request with no message; the setting OFF refuses all with no block; at the allow, a TV that became full gives `reject`/`full` and a holder that came back gives `kicked`/`replaced`; the lost-holder takeover happens only at the allow; `stop()` sends `bye` to a waiting phone; a waiting socket that floods frames is read at most 8 frames for each frame.
2. The pairs of 5.4, items 1 to 6, 6a (the refusal counter and its bound), 6b (no time on the wire), 6c (`busy`, skipped with a printed line when 127.0.0.2 to 127.0.0.6 are missing) and 6d (the wide known-token rule).
3. `approve_new` false (the default of a new `TvServer`): the first frame after `hello` is `welcome`, no `pending`, no `requests_changed` (the wire of today).

Also run `net_limits`, `net_profiles`, `protocol_doc`, `join_flow`, `net_loss`; the `qa` decides on the whole suite (a change of the net). `security-reviewer` reviews the PR (network input).

The PR of phase 4 is merged when its checks pass; the privacy notice is a separate owner PR or comment (CLAUDE.md, "Split work so that the owner's part is small"), not a block of phase 4, unless the owner says that the notice must ship in the same release (a release is not made by the agents).

## 12. Points to align with the requirements and the mock

Final choices of the plan (2026-11-07). The `product-engineer` aligns `docs/TV_FLOW.md` at the same time; where the two texts differ, this list is the plan's answer, and the requirement still wins for what the user sees.

1. **REQ-FL-94, known token (D11): decided by the owner on 2026-11-07, the wide rule** (FD-30.4: any token that this TV gave in this run of the TV app and that a kick, a `bye` or a replacement did not revoke, at most 32 kept, forgotten when the TV app restarts). A phone that is in the background for 10 s, or that drops in a round, comes back with no card and with no wait for the end of the round. The narrow rule (no card only inside the 5 s grace) was considered and not chosen.
2. REQ-FL-99: **1 waiting request for each address**; a new request of the same address replaces the old one (FD-30.8).
3. REQ-FL-103 (D3, approved): a TV that **quits** sends `bye` (the phone shows `app.tv_closed_connection`); only a **lost** link is `wait_lost` (`connect.room_not_found`).
4. The Settings row: **first**, before Debug overlay (owner, 2026-11-07, FD-30.16; it replaces D8). The `product-engineer` aligns REQ-FL-93 ("the last row, after Language", and its planned test `tests/smoke_settings.gd`, which is `tests/config_files.gd` in this plan) and REQ-FL-23 ("one more row after Language"). The approved mock already shows the row first.
5. The card (owner, 2026-11-07, FD-30.15): **two buttons ALLOW and REFUSE, no key hints and no key names; LEFT and RIGHT move the focus; OK activates the focused button; the 1 s lock stays (D6); no time text and no time bar.** **D12, decided by the owner on 2026-11-07:** the focus starts on ALLOW; BACK does **not** refuse: the card ignores BACK, so BACK cannot close the card and only a button or the internal time limit ends a request. The `product-engineer` aligns `docs/TV_FLOW.md` with the key table of 7.2: REQ-FL-97 (OK, LEFT, RIGHT, UP and DOWN are ignored for 1 s after a card shows; BACK is ignored as long as the card shows; the card owns the arrows; the MENU key is not handled by the card), REQ-FL-104 ("REFUSE or BACK" becomes "REFUSE"), REQ-FL-34 (BACK does not close the card) and the FD-30 row ("BACK on the remote also refuses" is no longer true). Keys: section 10.3.
6. REQ-FL-102 and REQ-FL-104: the OFF refusal neither counts nor blocks (FD-30.10); the block comes only after 3 host refusals in a row (owner decision 1).
7. REQ-FL-100 and the "Proposed strings" of `docs/TV_FLOW.md`: `connect.waiting_approval` is the owner's text "WAITING FOR THE HOST TO GET YOU IN." / "ממתינים שהמארח יאשר אתכם." (it replaces "WAITING FOR THE TV TO LET YOU IN."); `connect.waiting_approval_hint` no longer names OK: the proposal "ASK THE HOST TO ALLOW YOU ON THE TV." (Hebrew of the mock "בקשו מהמארח לאשר אתכם בטלוויזיה.") replaces "ASK THE HOST TO PRESS OK ON THE TV." / "בקשו מהמארח ללחוץ OK בטלוויזיה.". The `approval.*` rows of the TV are those of 10.3 (`approval.hint_ok` and `approval.hint_back` stay removed).

## 13. Risks

| ID | Risk | Effect | What we do |
|----|------|--------|------------|
| JA-R1 | An old phone that loses its Wi-Fi while it waits cannot be seen by the TV (it sends nothing). | A dead request holds a place up to 180 s, or the host allows a dead phone (a wrong slot for about 8 s). | The 60 s and 180 s limits; the replacement by address (FD-30.8); the slot grace frees it. New phones are the same (they send nothing either) but end their side at 5 s. |
| JA-R2 | Two phones behind one address (a travel router, a Wi-Fi extender with NAT) replace each other's request. | Only the newest of the two can ask; the other shows `wait_lost` and must tap JOIN after the first is in. | Rare on a home LAN (each phone has its own address). Recorded in Manual test 34 notes if seen. `max_waiting_per_ip` is a variable, so it can go to 2 without a protocol change. |
| JA-R3 | BACK reaches the TV through three paths (`ui_cancel`, `KEY_BACK`, and the notification on Android TV). | A BACK that leaks past the card goes back a screen, closes the Players modal or quits the TV app under an open card. | The layer consumes both key forms in `_input` and stamps `_last_back_ms` (`App.note_back()`); `App._back()` returns while `join_requests.is_open()`; the 250 ms rule drops the notification of a press whose card closed in between (7.2). `join_approval_tv` items (e), (e2) and (f) send each form and the key plus the notification of one press. |
| JA-R14 | BACK is ignored by the card (D12). | A host who does not want to answer cannot close the card with BACK; the card stays over the menu and holds the arrows. | Accepted by the owner. A card with no answer ends by the internal limit (60 s shown, 180 s total, FD-30.9) as a timeout, which neither counts nor blocks. Then the next card (1 s later) or the screen gets the keys again. `join_approval_tv` item (i2). |
| JA-R15 | The BACK change leaks to other screens. | BACK stops working on a TV screen with no card. | The check is only `join_requests.is_open()` (a card is shown); with no card, and in the 1 s gap between cards, `_back()` runs as today. The TV's BACK behavior on every other screen is unchanged; `join_approval_tv` item (e2) and the existing BACK tests (`r1_tv_screens`, `tv_flow_reqs`, `focus_walk`) stay green. |
| JA-R4 | A screen sets the focus after the card opened (the logo screen goes to Connect when OK is pressed; it did so by itself until 2026-11-10). | The arrows or OK reach the screen under the card. | `App.go()` calls `on_screen_changed()` (7.2); a test changes the screen under an open card. |
| JA-R5 | A phase-2 or phase-3 build saves `approve_players = false`. | The owner's default ON never reaches a TV that ran such a build. | The key enters `App.settings` only in phase 4 (FD-30.3). |
| JA-R6 | A sniffed token resumes a slot with no card. | A device that reads the Wi-Fi can play as another player. | Not in scope (no encryption, FD-28). `docs/RISKS.md` C6 and the privacy notice say that the traffic is not encrypted. |
| JA-R7 | An old phone shows "THE HOST REMOVED YOU" for a timeout or a full queue. | A slightly wrong text on old builds. | Only builds from before phase 2; the right action (scan again) is in the text. |
| JA-R8 | The 1 s key lock feels like a missed press on a slow TV box. | The host presses OK twice. | The second press, after 1 s, activates the focused button (ALLOW, because the arrows are also locked for 1 s); it cannot answer a second card, because that card also waits 1 s and starts on ALLOW. Manual test 34 measures it on the real remote. |
| JA-R10 | The card is a second `TvModal` over the Players modal; the lower modal's `_input` sees a focus outside itself and eats the arrows. | LEFT and RIGHT would not move the focus between ALLOW and REFUSE over the Players modal. | The layer is the last child, and the card moves its focus itself in `_input` and consumes the arrow (7.2). `join_approval_tv` item (f). |
| JA-R11 | OK before 1 s, or with a focus outside the card, reaches the `_unhandled_input` of the screen under it (Connect, logo). | The Connect screen goes on to Games, or the logo screen picks a language, under the card. | The card consumes OK in `_input` in its first 1 s and whenever the focus is not on a card button (7.2). `join_approval_tv` item (d). |
| JA-R12 | The approve row is the first Settings row and has the focus when Settings opens (owner, FD-30.16). | One LEFT press right after OK on OPTIONS turns the approval OFF and saves it; with the setting OFF anyone on the Wi-Fi joins. | The row shows OFF in gray at once (REQ-FL-23), and a waiting request is refused, not let in (FD-30.10). The plan adds no confirmation (that would change what the user sees; the owner decided the order). Manual test 34 step 1a checks that the row is first, focused and ON on a new settings file. |
| JA-R13 | Phase 4 shifts the index of every Settings row in the tests. | `screens_sweep` would press Left and Right on the approve row and save it to the settings file of the machine; other suites fail. | Phase 4 changes the suites of 7.3 to find a row by its title key; the `qa` runs the whole suite for phase 4. |
| JA-R9 | Low-end TV box load. | None expected: at most 4 more sockets polled, one frame of 15 bytes every 2 s for each, one modal that redraws only when the queue changes (no countdown, FD-30.14), a refusal table of at most 64 entries. | Manual test 34 checks the frame rate in the menu with 4 phones and a card (debug overlay). |

## 14. Owner questions

Answered on 2026-11-07: the look of the card and of the phone screens (the mocks are approved), D1 to D12 (D11: the wide known-token rule; D12: the focus starts on ALLOW and BACK is ignored by the card), the card buttons (ALLOW and REFUSE, no key hints), the first Settings row and the phone waiting text (see "Decided by the owner (2026-11-07)").

Open (neither blocks a phase):

1. Is a controller build already in the hands of people other than the test devices (a store, a shared APK)? If not, the old-phone behavior of 5.2 matters only for the test phones, and the old-build step of Manual test 34 can be dropped.
2. The privacy notice text of section 10.2 (owner only).
