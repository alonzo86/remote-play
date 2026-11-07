# Join approval plan: the host lets each new phone in with the TV remote (FD-30, issue #393)

Status (2026-11-07): **plan, nothing is built.** Written by the role `software-architect` for issue #393. The owner decided on 2026-11-07 (issue #385) that the host approves each new phone with the TV remote, with a TV setting "approve new players" that is ON by default. The behavior rules (what the host and the player see) are REQ-FL-93 to REQ-FL-104 in `docs/TV_FLOW.md`, written by the `product-engineer`; the look is the mock in `docs/design-system/components/JoinApproval/` (the owner approves it). This file says **how**: the join state machine of the TV, the protocol, the phone and TV code, the tests and the phases. Where this plan and REQ-FL-93 to 104 differ, section 12 lists the point; the requirement wins for what the user sees, this plan wins for the wire and the code structure. No code, no string and no legal text is changed by this file.

Style: ASD-STE100 Simplified Technical English, like the other plans. File and line references were checked on 2026-11-07 against `main` (after PR #391 and PR #392).

## 1. Goals and non-goals

Goals:

1. With the setting ON, a phone that joins with a new connection takes no slot and gets no game message until the host presses OK on the TV remote.
2. A phone that comes back with a token that the TV gave it in this session is not asked again (a lost Wi-Fi, a phone call, the app in the background).
3. The approval never shows during a round and never slows a round.
4. One device on the Wi-Fi cannot fill the TV with cards or keep the family out longer than the limits of issue #387 allow.
5. Old and new builds work together without a `VERSION` change: an old phone with a new TV waits and then joins, or gets a clear text; a new phone with an old TV joins at once as today.
6. With the setting OFF the TV behaves exactly as today (FD-28), byte for byte on the wire.

Non-goals:

- No PIN, no password, no encryption. FD-28 stays: the room code is the address, not a secret. The approval stops a stranger who joins; it does not stop a device that reads the traffic (section 9).
- No approval for a profile change, a slot change or a resume. The approval is about the device, once per session.
- No list of waiting phones in the Players modal and no "allow all" action. The queue is small (4) and the card shows one request at a time.
- No memory across a TV restart: the TV forgets every token and every block when the app closes (no new saved data except the setting).
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
- **FD-30.4 "Known token" means a token that this TV gave in this session and did not revoke.** The TV keeps the tokens of the phones it welcomed in `_known_tokens` (memory only, at most 32, the oldest goes first). A `hello` with a known token joins with no card: to its own slot when the slot is still present (today's resume), else to a free slot as a returning player (a late joiner in a round, REQ-FL-25). Revoked: `kick` (REQ-FL-33), a `bye` from the phone (the player left), `_replace_slot` (issue #388). Kept: a lost slot that timed out, "Resume without 2P" (`drop_player`). Reason: the slot grace is 5 s (`SLOT_GRACE_MS`); a phone that is in the background for 10 s in the menu would ask the adult again, which the owner wanted to avoid ("a lost connection does not ask the adult again", issue #385). The token is 128 bits from `Crypto` (issue #388), so it is as safe as the resume of today. **This widens REQ-FL-94** (which says "inside the 5 s of the grace"); the `product-engineer` aligns the text (section 12).
- **FD-30.5 The checks that exist today run before the queue, and run again at the moment of the allow.** Before: room code, replaced token, resume, held profile (`kicked`/`replaced`, REQ-FL-74, issue #388), a full TV (`reject`/`full`). A request that cannot get a slot is never shown. At the allow: the held profile and the free slot are checked again (the room can change in 60 s), and the takeover of a **lost** holder (`_replace_slot`) happens only then, never at the request: a stranger who is not allowed must not free the slot of a lost child.
- **FD-30.6 Allowed is `welcome`. Every end without a slot is `kicked` with a reason: `refused`, `timeout`, `busy`.** `kicked` already means "no slot, forget the token, do not retry", and issue #388 already sends it to a phone that has no slot (`replaced`). An old phone maps any reason except `replaced` to `kicked` and shows "THE HOST REMOVED YOU. SCAN THE CODE TO JOIN AGAIN." in its own language: a clear, true enough text with the right action. A `reject` with a new reason would show the raw code ("Connection refused: timeout") on an old phone.
- **FD-30.7 The TV sends `{"t":"pending"}` when the request is queued and again every 2 s (`Protocol.PENDING_KEEPALIVE_MS`).** An old phone closes a `JOINING` socket after 5 s with no frame (`controller_client.gd:214`); any frame resets that clock, and the old phone ignores the unknown `t`. So the old phone waits as long as the TV wants, with no change to its code. The new phone uses the same frames to see that the TV is alive. 2 s is under half of 5 s, so one late frame on a weak Wi-Fi (gaps of 380 ms were measured, `change-protocol` step 5) does not drop the phone.
- **FD-30.8 Limits.** A request counts toward `MAX_PENDING` (16) and `max_pending_per_ip` (4) of issue #387. On top: at most 4 requests at one time (`MAX_WAITING`, REQ-FL-99; a fifth gets `busy`), at most **1 request for each address**: a new `hello` from an address that has a request **replaces** it (the old socket is closed with no message; the new one keeps the place in the queue, the arrival time and the card time). Reason: a real phone that retries after a Wi-Fi gap leaves a half-open socket that the TV cannot see (an old phone sends nothing while it waits); the replacement lets that phone in, and a rogue device can still hold only one card and cannot make its 60 s or its 180 s longer. A host refusal blocks the address for 60 s (REQ-FL-104, `refuse_block_ms`); a timeout, a cancel and the setting turned OFF do not block.
- **FD-30.9 The card shows only in a menu phase, one at a time, 1 s after the last answer.** The head request is "shown" when `in_menu_phase()` is true and 1 s (`approval_gap_ms`) has passed since the last card closed. Its 60 s (`approval_timeout_ms`) counts from that moment. A request also ends as a timeout 180 s (`approval_total_ms`) after it arrived, shown or not (REQ-FL-96). When the phase goes to a round while a card is shown (no host key can start a round while the card holds the input, but the code must not trust that), the request goes back to "not shown" and gets a new 60 s at the next menu phase; the 180 s still bounds it.
- **FD-30.10 Turning the setting OFF refuses every waiting request (`kicked`/`refused`, no address block); turning it ON changes nothing for the phones in the room.** This follows REQ-FL-102 (D2): nobody gets in without an answer of the host. The OFF refusal does not block, so the phone can join at once with one tap.
- **FD-30.11 `VERSION` stays 5.** Neither side waits for a new message: the phone waits for `welcome` as before, the TV waits for `hello` as before. `pending` is optional for the phone (FD-30.7), `kicked` exists, its new reasons fall back to the known text on an old phone (FD-30.6). By the rule of `docs/PROTOCOL.md` ("Version change") this is compatible. `LANG_REMOVE_AFTER_VERSION` is not touched.
- **FD-30.12 The card lives in a layer that the App owns, above the screens, not inside a screen.** A request can show on any menu screen (Connect, Games, Settings, a game settings view, the Players modal, About) and must survive a screen change. The App keeps one `JoinRequests` node (a `CanvasLayer`) and the Back key goes to it first (section 7).
- **FD-30.13 The phone never sends `hello` again while it waits, and does not retry after the wait ends.** A retry would make a new request at the end of the queue. A lost socket while waiting ends the join with the reason `wait_lost` (REQ-FL-103). CANCEL sends the existing `{"t":"bye"}`.

## 4. The join state machine on the TV

### 4.1 States of a connection

```
TCP accept ──(limits of #387)──> PENDING ──hello──> checks (4.2) ──┬─> SLOT (welcome)                     [approval OFF, known token]
   │                                │                               ├─> closed (reject / kicked / close)   [a check fails]
   └─ refused at once               └─ 5 s no hello: close          └─> WAITING ─┬─ allow: re-check ─┬─> SLOT (welcome)
                                                                                 │                   └─> closed (reject full / kicked replaced)
                                                                                 ├─ BACK: kicked refused (+ block the address 60 s)
                                                                                 ├─ 60 s shown, or 180 s total: kicked timeout
                                                                                 ├─ setting OFF: kicked refused (no block)
                                                                                 ├─ replaced by a newer hello of the same address: close, no message
                                                                                 ├─ phone sends bye, or the socket closes: removed, no message
                                                                                 └─ TV stops: bye
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
    1. The address is blocked (a refusal in the last 60 s): `kicked`/`refused`, no card.
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
| The setting goes OFF | All requests: `kicked`/`refused`, no block (FD-30.10). |
| The TV app stops (`stop()`) | Each waiting phone gets `bye` (the phone shows "THE TV APP CLOSED THE CONNECTION.", today's text for a TV that quits), sockets closed 300 ms later (issue #169). |
| The TV address changes | No change: the sockets stay as the slots do today. |

### 4.5 The TV server API (for the UI and the tests)

- `var approve_new := false`; `func set_approve_new(on: bool)` (OFF refuses the waiting requests, FD-30.10).
- `signal requests_changed()`: a request was added, removed, shown or hidden. The UI reads the state; the signal carries no data, so the UI never keeps its own copy of the queue.
- `func shown_request() -> Dictionary`: empty, or `{id, name, av, slot_hint, ms_left, others}`. `name` is `Profile.clean_name` of the `hello` (empty for a phone with no name; the UI shows `players.default_name` with `slot_hint + 1`, the first free slot now), `av` is `Profile.clean_avatar` when the `pid` is valid, else -1. `others` is the number of other requests.
- `func request_count() -> int`.
- `func allow_request(id: int)`, `func refuse_request(id: int)`: do nothing for an id that is not shown (a key press that comes after a timeout).
- Settable for the tests, like `peer_timeout_ms`: `approval_timeout_ms` (60000), `approval_total_ms` (180000), `approval_gap_ms` (1000), `refuse_block_ms` (60000), `max_waiting_per_ip` (1). Constant: `MAX_WAITING` (4), `MAX_KNOWN_TOKENS` (32). The time comes from `Time.get_ticks_msec()` as in the rest of the server; the tests use short values, as `net_loss` does for the grace.

## 5. Protocol

### 5.1 Messages

| From | Message | Meaning |
|------|---------|---------|
| TV | `{"t":"pending"}` | New. The TV has the `hello` and waits for the host. Sent when the request is queued and again every `PENDING_KEEPALIVE_MS` = 2000 ms until the end of the wait. The phone shows its waiting screen and sends nothing more (except `bye` for CANCEL). It has no field today; a later optional field (for example the place in the queue, or "a round runs", decision D7 of `docs/TV_FLOW.md`) is compatible, because the phone ignores fields that it does not know. Sent only by a TV whose setting is ON. |
| TV | `{"t":"welcome", ...}` | Unchanged. The host allowed the phone (or no approval was needed). |
| TV | `{"t":"kicked","reason":"refused"}` | New reason. The host pressed BACK, or the address is blocked after a refusal (60 s), or the setting was turned OFF while the phone waited. |
| TV | `{"t":"kicked","reason":"timeout"}` | New reason. 60 s with the card shown, or 180 s in total, with no answer. |
| TV | `{"t":"kicked","reason":"busy"}` | New reason. 4 requests already wait. |
| Phone | `{"t":"bye"}` | Unchanged message; new use: CANCEL on the waiting screen withdraws the request. |
| TV | `{"t":"bye"}` | Unchanged message; also sent to a waiting phone when the TV app stops. |

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
- "Limits of the TV": a waiting phone counts toward `MAX_PENDING` and `max_pending_per_ip`; `MAX_WAITING` 4; 1 request for each address; the 60 s block.
- "Slots, loss and reconnect": "A `hello` with an unknown token is a new player" gets "and needs the approval when the setting is ON"; the known tokens.
- "Version change": one sentence that `pending` keeps `VERSION` 5 and why (FD-30.7, FD-30.11).
- The text "the TV asks for nothing else" (section "Room code") gets "except the approval of the host when the setting is ON".
- `tests/protocol_doc.gd` checks the numbers that the document quotes: `PENDING_KEEPALIVE_MS` is in `protocol.gd`; the TV numbers (60 s, 180 s, 4, 1, 60 s block) are quoted with their `TvServer` names, as `MAX_PENDING` is today.

### 5.4 Tests that prove old and new together (phase 1, `tests/join_approval.gd`)

The old phone is a **frozen copy** of `scripts/net/controller_client.gd` as it is on `main` before phase 1, in `tests/fixtures/controller_client_v5.gd` (with a header line: the commit it was taken from, and "delete when `VERSION` goes above 5"). It is a real old peer, not a mock: it has the old `JOINING` timeout and the old `kicked` mapping. It is not a module of `scripts/`, so it is not in the coverage.

1. Old phone, setting ON: after 6 s (more than `HELLO_TIMEOUT_MS`) it is still `JOINING`, and the largest gap between two frames it received is below 2500 ms. Then `allow_request`: it is `CONNECTED` with a slot and a token.
2. Old phone, refused / timeout (short `approval_timeout_ms`) / busy (4 requests already): it is `IDLE`, `rejected` gave `kicked`, its token is empty, and it makes no new connection in the next 3 s (the accept count of its address does not grow).
3. Old phone, setting OFF: `welcome` is the first frame (today).
4. New phone, new TV, setting OFF: the first frame after `hello` is `welcome` and no `pending` is ever sent: this is the wire behavior of a TV of today, so the new phone against an old TV is the path that every current net suite already tests.
5. New phone, setting ON: `WAITING` after `pending`; `CONNECTED` after the allow; `rejected` gives exactly `refused`, `timeout`, `busy`; `wait_lost` when the TV socket goes silent for 5 s; `tv_closed` when the TV stops.
6. `Protocol.VERSION` is 5 and `protocol_doc` passes with `pending` in `MESSAGES` and in `docs/PROTOCOL.md`.
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
- New `scripts/ui/join_card.gd` extends `scripts/ui/tv_modal.gd` (the dim layer, the double frame, the focus held inside, `card_width` 1200, the 60 px safe margin of REQ-FL-81). It builds the content of the mock: title, avatar (the `Avatar` drawing of REQ-FL-70) and name, the time bar and seconds (`ms_left`, redrawn once a second, not each frame), the "+N WAITING" box (`others`), the two key hints. The name label has `auto_translate_mode` disabled (a player name is never a key) and the text direction of the name itself (a Hebrew name in the English UI and the reverse, REQ-FL-69); the card mirrors in Hebrew through the layout direction like every modal.
- It has **no focusable button**: OK and BACK are keys, not menu items (the mock shows key hints). That keeps it out of the D-pad walk.

### 7.2 Keys and focus

- **OK** (`ui_accept`: the DPAD center and Enter of the remote): `join_requests.gd` reads it in `_input`, consumes it (`set_input_as_handled`), and calls `allow_request` when the card has been open for 1 s (REQ-FL-97, D6). The App keeps the layer the **last child** after every `App.go()` (`move_child(layer, -1)`), so its `_input` runs before the `_input` of any screen (Godot calls `_input` from the last child to the first). OK on the card plays `join` (the server signal `player_joined` already plays it, so the card plays nothing more for OK); the App `select` sound is skipped because the event is consumed.
- **BACK**: `App._back()` asks the layer first: `if join_requests.is_open(): join_requests.on_back(); return`. This keeps the 250 ms rule of `_back()` for the double event (key and notification) of one press, so one press refuses one request, never two. The card ignores BACK in its first 1 s too. BACK plays `denied`; `App._menu_sound` skips its `back` sound while the card is open.
- Other keys (arrows, Menu/F3 for the overlay) do nothing on the card: the arrows are held inside by `TvModal`; the overlay key keeps working (it is a debug tool).
- **Focus**: the card suspends the focus of the controls under it (`TvModal._suspend_focus_below`) and gives it back on close. When a screen changes while a card is open (the logo screen goes on to Connect by itself after 2 to 3 s), `App.go()` calls `join_requests.on_screen_changed()`, which suspends the controls of the new screen too, so its `focus_later` cannot take the input from the card. When the card closes the focus goes back to the control that had it (TvModal) or, after a screen change, to the first item of the screen.
- **Over another modal** (the Players modal, the quit dialog of the Connect screen): the card is a second modal on top; it suspends the controls of the first one and gives them back. BACK goes to the card first (above), so it never closes the modal under it.
- **The pause card**: no interplay. A pause is the phase `paused`; the card never shows in a round (FD-30.9), and the pause card of the game never shows in a menu phase.
- **Logo screen at the first start** (language choice, REQ-FL-60): the phase is `connect`, so a card can show over it (only a phone with a saved token of an older session can ask that early). The language choice waits under the card. This is acceptable and needs no special case.

### 7.3 The Settings row (phase 4)

- `App.settings` gets `"approve_players": true` (FD-30.3). `_start_tv()` sets `server.approve_new = bool(settings.approve_players)` before `server.start()`.
- `App.set_approve_players(on)` (like `set_overlay`): `settings.approve_players = on`, `save_settings()`, `server.set_approve_new(on)`.
- `tv_settings.gd`: `_add_row(rows, "settings.approve_players", "approve_players", Callable())`, and the on/off branch calls `App.set_approve_players(on)` for this key (as it does for `overlay`). The position of the row is open between REQ-FL-93 (last, after Language) and the mock (after INVERT AXES); the code is the same either way (section 12).
- The phone does not need the setting and the protocol does not carry it. The TV sends nothing about it.
- A `settings.cfg` without the key loads as `true`; a value of another type loads as `true` (`ConfigIO.fit`).

## 8. The `--join` debug path and the tests that join with no approval

- `--join=127.0.0.1` (a phone on a desktop, `app.gd:352`) is not a bypass: it sends an empty `room`, which only a debug TV accepts (issue #388), and then the approval applies as for any phone. The developer presses Enter on the TV window. No debug flag skips the approval: a bypass in debug builds would hide the bugs of this feature from every desktop run.
- Net suites (`net_*`, `join_flow`, `r4_join_code`, `r4_phone_profiles`, ...) make their own `TvServer`: `approve_new` is false by default (FD-30.3), so they need no change in any phase.
- TV app suites boot the App, which sets `server.approve_new` from `App.settings` from phase 4. Each of them sets `_app.server.approve_new = false` right after the App starts (memory only; nothing is saved, so the settings file of the machine is not touched). The suites known on 2026-11-07 that join a phone through the TV App: `r1_tv_screens`, `tv_flow_reqs`, `r4_tv_profiles`, `screenshots`, `screens_sweep`, `focus_walk`, `auto_r3_tv`, `r4_tv_menus`, `audio`, `smoke_lang`, `design_tokens` (the `automation-developer` checks the full list with a search for `ControllerClient.new` and `connect_to(` in the suites that boot the App). The suites have no shared App boot helper today (`tests/game_helpers.gd` is a suite, not a helper), so the line goes in each suite, or in a new helper if the `automation-developer` prefers one.
- The approval suites set `approve_new = true` (net) or `App.set_approve_players(true)` with the settings file saved and restored as `r1_tv_screens.gd:169-196` does.

## 9. Security

What the approval stops: a device on the same Wi-Fi that builds the room code and joins (issue #385). What it does not stop: a device that reads the traffic. The traffic stays plain WebSocket (FD-28); a device that can read it can copy a token and resume as that player with no card (a known token, FD-30.4). This was true before (resume by token) and needs a capture of the Wi-Fi traffic, not just the room code. `docs/RISKS.md` C6 says it after phase 4.

Flooding and spam, with the limits that apply:

| Attack | Bound |
|--------|-------|
| Many connections that never send `hello` | `MAX_PENDING` 16, 4 for each address, 30 accepts for each address in 10 s (issue #387). Requests count toward 16 and 4. |
| Many `hello` from one device to fill the queue | 1 request for each address (FD-30.8): the device holds one card, and each new `hello` only replaces its own request (same place, same timers; it cannot make its wait longer). |
| The same device asks again and again after a refusal | The address is blocked for 60 s after a refusal by the host: `kicked`/`refused` with no card (REQ-FL-104). |
| A device with many addresses fills the 4 places | A real phone then gets `busy` for at most 180 s; the host refuses each card (each refusal blocks its address). Turning the setting OFF would let the device in; the host can kick it (REQ-FL-33). Accepted: it needs several addresses on the network and is a nuisance, not a data leak. |
| A crafted name or avatar on the card | `Profile.clean_name` (letters, digits, space, 10 characters) and `Profile.clean_avatar`; the label never translates the name (7.1). |
| A waiting socket that sends a flood of frames | At most 8 frames read for each socket in each frame, `MAX_TEXT_BYTES`, `BUFFER_BYTES` and `MAX_QUEUED_PACKETS` as for the slots. |
| A stranger frees the slot of a lost child by sending its `pid` | The lost-holder takeover runs only at the allow (FD-30.5); with the setting ON a stranger is never allowed without the host. |

The `security-reviewer` reviews phases 1 and 4 (network input and a saved setting).

## 10. Docs, strings, legal texts

### 10.1 Documents (each in the PR of its phase, `sync-docs`)

- `docs/PROTOCOL.md`: phase 1 (5.3).
- `docs/TV_FLOW.md`: the statuses of REQ-FL-93 to 104 move from Planned with each phase; FD-30 gets "built"; the align points of section 12 (by the `product-engineer`).
- `docs/REQUIREMENTS.md`: REQ-A4 (join in one step) and the security lines say the approval (phase 4).
- `docs/AUTOMATED_TESTS.md`: the new suites (`join_approval`, `join_approval_tv`) and the A- rows they replace, each phase.
- `docs/MANUAL_TESTS.md`: Manual test 34 exists (Not run). Phase 4: the Summary and "Tests to run, in order" rows; the join steps of the tests that join a phone (tests 1, 7, 8b, 20, 21, per the list of `docs/TV_FLOW.md`) say "press OK on the card" or "turn the setting OFF first". One new step for the old-build pair (5.4 item 7) in test 34.
- `README.md`: how a phone joins and the Settings rows (phase 4).
- `docs/RISKS.md`: C6 "No authentication" becomes "approval by the host, default ON; a device that reads the traffic can still copy a token" (phase 4; the architect writes it).

### 10.2 Privacy notice and store texts (owner only; phase 4 names them and carries `needs-owner`)

- `docs/legal/privacy-notice.md` and `.he.md`, section 3: "There is no PIN or password: anyone on the same network who knows the room code or sees the QR code on the TV can join the game." is no longer true with the default. It must say that, with "approve new players" ON (the default), the adult with the TV remote lets each new phone in, and that with it OFF anyone on the network can join. The sentence on the unencrypted traffic stays true.
- Section 2, the table: the row "Settings" (on the TV) now also holds "approve new players"; the row "Name, avatar and scores ... on the TV, in memory only" now also covers a phone that waits for approval (its name and avatar show on the card, memory only). No new data, nothing saved about a phone.
- `docs/legal/store-listing-draft.md`: no sentence is false today; the owner may add that the host lets each phone in (a feature for parents). Not required.

### 10.3 Strings (keys only; the `product-engineer` writes the texts, the `localization-reviewer` reviews)

The proposed rows are in `docs/TV_FLOW.md` ("Proposed strings"). The keys the code needs:

- TV, phase 3: `approval.title`, `approval.hint_ok`, `approval.hint_back`, `approval.time_left`, `approval.others_waiting` (the mock also has a title "NEW PLAYER" and key boxes "ALLOW" / "REFUSE"; the `product-engineer` and the designer settle the set before phase 3).
- TV, phase 4: `settings.approve_players`.
- Phone, phase 2: `connect.waiting_approval`, `connect.waiting_approval_hint`, `connect.approval_cancel`, `connect.approval_refused`, `connect.approval_timeout`, `connect.approval_busy`, and the text for `wait_lost` (REQ-FL-103 reuses `connect.room_not_found`; see section 12).
- Reused, no change: `common.on`, `common.off`, `players.default_name`, `app.player_already_in_room`, `app.room_full_4_players`, `app.tv_closed_connection`, `app.host_removed_scan_code` (what an old phone shows for `refused`, `timeout` and `busy`).

## 11. Phases (one PR each, stacked: phase n is based on phase n-1)

Every phase is shippable: after phase 1 to 3 a user sees no change, because the approval is off in the App until phase 4.

| Phase | Content | Files | Tests | Manual test |
|-------|---------|-------|-------|-------------|
| 1. TV server, protocol, phone client | FD-30.1 to 30.11, 30.13; sections 4, 5, 6.1. `approve_new` false in the code; the App does not set it. | `scripts/core/protocol.gd` (`MESSAGES.pending`, `PENDING_KEEPALIVE_MS`), `scripts/net/tv_server.gd`, `scripts/net/controller_client.gd`, `docs/PROTOCOL.md`, `tests/join_approval.gd` (new), `tests/fixtures/controller_client_v5.gd` (new, frozen), `tests/suites.txt`, `tests/net_limits.gd` (requests count toward the pending limits), `tests/protocol_doc.gd` (if a number check needs a line), `docs/AUTOMATED_TESTS.md`, `docs/TV_FLOW.md` (statuses) | `join_approval` (all rules of section 4 and the pairs of 5.4), `net_limits`, `net_profiles`, `protocol_doc`, `join_flow`, `net_loss`; the `qa` decides on the whole suite (a change of the net). | none (headless only) |
| 2. Phone UI | Section 6.2. The waiting state of the Connect screen, CANCEL and Back, the texts of the reasons. | `scripts/ui/controller_connect.gd`, `scripts/app.gd` (`_on_client_rejected`), `assets/lang/strings.csv` (phone rows), `tests/r4_join_code.gd` or a new `tests/join_approval_phone.gd` (states and texts with a TvServer with `approve_new = true`), `tests/smoke_lang.gd`, `tests/screenshots_controller.gd` (the waiting screen), `docs/TV_FLOW.md`, `docs/AUTOMATED_TESTS.md` | the touched suites; pixel checks of the phone screen in both languages | test 34 steps for the phone (Not run until phase 4) |
| 3. TV card | Sections 7.1, 7.2. `join_requests.gd` and `join_card.gd`, the App layer, `_back()` routing, `go()` keeps the layer last, sounds. Reached only with `server.approve_new = true` (tests). | `scripts/ui/join_requests.gd` (new), `scripts/ui/join_card.gd` (new), `scripts/app.gd`, `assets/lang/strings.csv` (TV card rows), `tests/join_approval_tv.gd` (new: OK after 1 s allows, OK before 1 s does nothing, BACK refuses one request for one press with the double event, the card over the Players modal and its focus restored, a screen change under the card, no card in a round), `tests/screens_sweep.gd`, `tests/design_tokens.gd` (sizes, margin), `tests/focus_walk.gd`, `tests/suites.txt`, `docs/AUTOMATED_TESTS.md`, `docs/TV_FLOW.md` | the touched suites; pixel check of the card in English and Hebrew | none yet |
| 4. Setting, default ON, docs | Section 7.3, section 8 (TV app suites set the approval off), section 10.1 and 10.2. | `scripts/app.gd` (`approve_players`, `set_approve_players`), `scripts/ui/tv_settings.gd`, `assets/lang/strings.csv` (`settings.approve_players`), the TV app suites of section 8, `tests/smoke_settings.gd` (default ON, saved, a file with no key), `README.md`, `docs/MANUAL_TESTS.md` (Summary, order, join steps), `docs/AUTOMATED_TESTS.md`, `docs/REQUIREMENTS.md`, `docs/TV_FLOW.md`, `docs/RISKS.md` (C6). Owner only, named in the PR with `needs-owner`: `docs/legal/privacy-notice.md`, `.he.md`. | the touched suites and the whole suite (the `qa` decides; many TV suites change) | Manual test 34 (a real remote, 2 phones; one step with an older controller build) |

The PR of phase 4 is merged when its checks pass; the privacy notice is a separate owner PR or comment (CLAUDE.md, "Split work so that the owner's part is small"), not a block of phase 4, unless the owner says that the notice must ship in the same release (a release is not made by the agents).

## 12. Points to align with the requirements and the mock

These are for the `product-engineer` and the `ui-ux-designer`; none of them needs the owner unless they disagree about what the user sees.

1. REQ-FL-94: "known token" is wider (FD-30.4: a token of this session that was not revoked, not only inside the 5 s grace).
2. REQ-FL-99: add "1 request for each address; a new request of the same address replaces the old one" (FD-30.8).
3. REQ-FL-103: a TV that **quits** sends `bye`, so the phone shows today's `app.tv_closed_connection`; only a **lost** link (no frame for 5 s, or a close with no message) is `wait_lost`, for which the requirement chooses `connect.room_not_found`. Both are existing texts.
4. The Settings row: REQ-FL-93 puts it last (after Language), the mock puts it after INVERT AXES. One of them changes before phase 4.
5. The card texts: REQ-FL-97 has "LET %s IN?", "PRESS OK TO LET IN", "PRESS BACK TO REFUSE", "TIME LEFT: %d", "OTHERS WAITING: %d"; the mock has "NEW PLAYER", "+2 WAITING", "ALLOW", "REFUSE" and a time bar. One set before phase 3.
6. REQ-FL-102 (OFF refuses): the plan adds "with no 60 s block" (FD-30.10).

## 13. Risks

| ID | Risk | Effect | What we do |
|----|------|--------|------------|
| JA-R1 | An old phone that loses its Wi-Fi while it waits cannot be seen by the TV (it sends nothing). | A dead request holds a place up to 180 s, or the host allows a dead phone (a wrong slot for about 8 s). | The 60 s and 180 s limits; the replacement by address (FD-30.8); the slot grace frees it. New phones are the same (they send nothing either) but end their side at 5 s. |
| JA-R2 | Two phones behind one address (a travel router, a Wi-Fi extender with NAT) replace each other's request. | Only the newest of the two can ask; the other shows `wait_lost` and must tap JOIN after the first is in. | Rare on a home LAN (each phone has its own address). Recorded in Manual test 34 notes if seen. `max_waiting_per_ip` is a variable, so it can go to 2 without a protocol change. |
| JA-R3 | The card is reached by Back and OK through two paths (key and notification on Android TV). | One press could answer two cards. | Back goes only through `App._back()` (250 ms rule) and the next card waits 1 s, and each card ignores keys for 1 s. `join_approval_tv` sends both events of one press. |
| JA-R4 | A screen sets the focus after the card opened (the logo screen goes to Connect by itself). | The arrows or OK reach the screen under the card. | `App.go()` calls `on_screen_changed()` (7.2); a test changes the screen under an open card. |
| JA-R5 | A phase-2 or phase-3 build saves `approve_players = false`. | The owner's default ON never reaches a TV that ran such a build. | The key enters `App.settings` only in phase 4 (FD-30.3). |
| JA-R6 | A sniffed token resumes a slot with no card. | A device that reads the Wi-Fi can play as another player. | Not in scope (no encryption, FD-28). `docs/RISKS.md` C6 and the privacy notice say that the traffic is not encrypted. |
| JA-R7 | An old phone shows "THE HOST REMOVED YOU" for a timeout or a full queue. | A slightly wrong text on old builds. | Only builds from before phase 2; the right action (scan again) is in the text. |
| JA-R8 | The 1 s key lock feels like a missed press on a slow TV box. | The host presses OK twice. | The second press, after 1 s, allows; it cannot answer a second card, because that card also waits 1 s. Manual test 34 measures it on the real remote. |
| JA-R9 | Low-end TV box load. | None expected: at most 4 more sockets polled, one frame of 15 bytes every 2 s for each, one modal redrawn once a second. | Manual test 34 checks the frame rate in the menu with 4 phones and a card (debug overlay). |

## 14. Owner questions

None blocks phases 1 to 3. For phase 4 and the release:

1. Is a controller build already in the hands of people other than the test devices (a store, a shared APK)? If not, the old-phone behavior of 5.2 matters only for the test phones, and the old-build step of Manual test 34 can be dropped.
2. The privacy notice text of section 10.2 (owner only).
3. The look of the card and of the phone screens (the mock; owner approves).
