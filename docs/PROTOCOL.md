# Network protocol, version 5

This document uses ASD-STE100 style. Code: `scripts/core/protocol.gd`.

## Ports

| Port | Type | Use |
|------|------|-----|
| 47801 | TCP | WebSocket server on the TV. Path and query are not used. |

The TV sends nothing on the network by itself. A phone finds the TV in one of two ways: the player types the room code that the TV shows, or the phone scans the QR code of the TV (`ws://IP:47801/ROOM`). There is no list of TVs and no search.

## Room code

The room code is the address of the TV in 4 letters (FD-28). It holds the last two numbers of the IPv4 address of the TV (for `192.168.1.23`: `1` and `23`), which are 16 bits: `v = third * 256 + fourth`.

- **Scramble.** Before the letters are made, the 16 bits go through a fixed one-to-one step, so that the codes on one network do not all look alike: `n = (v * 40503) mod 65536`. The phone undoes it with `v = (n * 30599) mod 65536` (`40503 * 30599` is 1 modulo 65536).
- **Letters.** `n` is written as 4 digits of base 22 with the alphabet `ACDEFGHJKLMNPQRTUVWXYZ`, first digit first. The alphabet has no digit and leaves out B, I, O and S, which look like 8, 1, 0 and 5 (a child reads the code from the TV and types it, issue #241); `tests/room_code.gd` checks it. A change of the alphabet changes every room code, so it needs a new `VERSION` (the `change-protocol` skill); the 22 letters are kept in this order. `192.168.1.23` gives `DREJ`. The first letter uses only the first 7 letters of the alphabet, because `n` is below 65536.
- **Reading.** The phone removes spaces and changes to upper case. A text with another length, a letter that is not in the alphabet, or a value above 65535 is not a room code: the phone shows the error at once and sends nothing.
- **Address.** The phone takes the first two numbers from its own Wi-Fi address (the private IPv4 addresses of the best kind, see `Protocol.private_ipv4s`) and the last two from the code, and connects to port 47801. With several addresses it tries each one, one after the other, with one try and a timeout of 2 s for each (`ControllerClient.connect_to(..., quick)`). If none answers, the phone says that the room is not found and suggests the QR code. A network where the TV and the phone do not share the first two numbers needs the QR code.
- **TV.** The TV uses its LAN address (`Protocol.local_ipv4`: `192.168.x.x`, else `10.x.x.x`, else `172.16.x.x` to `172.31.x.x`), reads it again each second, and shows a new code when it changes. A TV with no address has no code and no QR code.
- **Check.** The TV answers `bad_room` to a `hello` whose `room` is not its own code, so a typed code that reaches another device with the right port, or another TV, does no harm. A `room` that is empty is accepted only by a debug build of the TV (`OS.is_debug_build()`; a run on a desktop: `--join=127.0.0.1`); a release build answers `bad_room` (issue #388).

The room code is not a password: it is the address. Any device on the network can build it, and the TV asks for nothing else (there is no join PIN since FD-28). The traffic is not encrypted.

## Join (WebSocket, JSON text frames)

| From | Message | Meaning |
|------|---------|---------|
| Phone | `{"t":"hello","v":5,"room":"DREJ","token":"","name":"","pid":"","av":-1}` | First message. `room` can be empty only in a development run (a debug build of the TV accepts it, a release build answers `bad_room`). `token` is empty for a new player. `name` can be empty: the TV then shows "Player N". `pid` and `av` are optional: the profile ID (32 lower-case hex characters) and the avatar index (0 to 255) of the profile that plays (FD-22, "Profiles" below). |
| TV | `{"t":"welcome","slot":0,"token":"…","color":"#3dcef2","phase":"connect","name":"Living Room TV","lang":"en","pid":"","av":-1,"pname":""}` | Accepted. Optional `rc`: `false` when the running game has no Recenter box on the pad (REQ-GM-37; absent means true). Optional `ab`: the buttons of the running game, as in `phase` (REQ-GM-37a; absent means `"ab"`). The phone saves `token`. `pid`, `av` and `pname` are the profile that the TV accepted (empty or -1 for a guest). `name` here is the name of the TV; the player name is `pname`, the name that the TV shows (with a number when another player has the same name, for example `Sam 2`). `lang` is the language of the TV, `en` or `he`; the field is optional (a TV of an older build does not send it) and the phone keeps its own language then (REQ-FL-62). |
| TV | `{"t":"reject","reason":"full"}` | `reason`: `full`, `bad_room`, `version`. |

The TV closes a connection that sends no `hello` in 5 seconds.

## Messages after the join

| From | Message | Meaning |
|------|---------|---------|
| Phone | `{"t":"ping","id":7,"t0":123456}` | Once each second. `t0` is the phone clock in ms. |
| TV | `{"t":"pong","id":7,"t0":123456,"t1":987654}` | `t1` is the TV clock in ms when the ping arrived. |
| Phone | `{"t":"stat","rtt":14.2,"off":864198.5,"hz":59.8}` | Sent after each pong. `rtt` = RTT in ms. `off` = TV clock minus phone clock. `hz` = sensor packets sent per second. |
| Phone | `{"t":"recenter"}` | Set the neutral pose and zero the yaw. The pose in the hand is neutral (no snap to flat, REQ-GM-37b). |
| TV | `{"t":"phase","v":"menu"}` | What the TV shows. `v`: `connect` (logo and Connect screens), `menu` (Games, Settings, Players), `playing`, `paused`, `waiting`. `waiting` is sent only to a phone that joined during a round: it takes part in the next round. Optional `rc`: `false` while the running game has no Recenter box on the pad (REQ-GM-37, issue #55); absent means true. Optional `ab`: the buttons that the running game uses, `"a"`, `"b"`, `"ab"` or `""` (REQ-GM-37a, issue #80); absent means `"ab"`. An older phone ignores both and shows all controls, so the protocol `VERSION` does not change. |
| TV | `{"t":"lang","v":"he"}` | The language of the TV changed (Settings). **Not used by the phone since 2026-10-29 (issue #171, REQ-FL-62):** a phone has its own language and ignores this message and `welcome.lang`. The TV still sends both, unchanged, so the wire format and the protocol `VERSION` do not change (an older phone build that still reads them follows the TV language). `v`: `en` or `he`. Remove them in the next incompatible version. |
| TV | `{"t":"haptic","ms":40}` | Vibrate the phone. |
| TV | `{"t":"score","rank":2,"of":4,"v":"12"}` | The place of this player in the running game (`rank`, 1 is first; equal scores share a place; 0 while nobody has scored), the number of ranked players (`of`) and the score text (`v`, at most 12 characters, empty when the game has no score yet, for example a race before the finish). Sent once for each change, only while a game runs. The phone shows it in its header (REQ-FL-67) and clears it at any phase other than `playing` and `paused`, and when it joins again. Optional message: an older phone ignores it, so the protocol `VERSION` stays 2. |
| TV | `{"t":"turn","s":1,"who":""}` | Whose turn it is in a game with turns (Pin Pals, REQ-BW-14). `s`: 0 no turn line, 1 the turn of this phone, 2 another player is on turn (`who` is the name of that player, at most 20 characters). `k` is optional: `"golf"` makes the waiting line say that the player is putting (Mini Golf, REQ-MG-12); without it the line says that the player is bowling. Sent once for each change, only while a game runs. The phone shows a line under its score row and clears it at any phase other than `playing` and `paused`, and when it joins again. Optional message: an older phone ignores it, so the protocol `VERSION` stays 3. |
| TV | `{"t":"setup","swing":true,"pick":true,"in":true}` | The settings view of a game is open on the TV (issues #79 and #76). `swing`: the game is a swing game (Pin Pals, Tennis, Mini Golf): the phone shows the safety card "hold on tight" until the player taps OK, every time the view opens (a phone that tapped for this view answers at once when the TV syncs the view again; REQ-GM-102, issue #148). `pick`: two or more phones are connected: the phone shows the question "play this game?" with IN and OUT (REQ-GM-104). `in`: the choice of this phone as the TV has it. Sent to every connected phone when the view opens and again when a phone joins or leaves, a choice changes or the swing flag changes, so a phone that joins or returns gets it too. Any `phase` message closes it (the phone forgets the setup). |
| Phone | `{"t":"play","v":false}` | The player chose OUT (`false`) or IN (`true`) for the game of the settings view (issue #76, REQ-GM-104). Ignored when no settings view is open. Every phone may go OUT; the next `setup` message carries the choice. A phone that is OUT does not play the next round (it gets the phase `waiting`). |
| Phone | `{"t":"swing_ok"}` | The player tapped OK on the safety card (or had tapped it for this view before the TV synced the view again). The Start button of the TV settings view of a swing game works when every connected phone has sent it. Ignored when no swing setup is open. |
| Phone | `{"t":"profile","pid":"…","name":"Noam","av":7}` | The player changed profile on the phone (FD-22). `{"t":"profile"}` alone is a guest. The TV accepts it only in the phases `connect` and `menu`. Optional message. |
| TV | `{"t":"profile","pid":"…","name":"Noam","av":7}` | The answer to every `profile` message: the values the TV accepted (empty for a guest); `name` is the name that the TV shows. In the phases `playing`, `paused` and `waiting` the TV does not change the profile and answers with the stored one. The phone shows the answer as the truth. |
| TV | `{"t":"result","pid":"…","key":"paint_grab|medium","v":340}` | The result of the round for the profile of this phone (FD-22, REQ-GM-99). `key` is the best key of the game, `v` the score as a whole number (a time in milliseconds). Sent at the end of a round to each finished player with a profile and a score above 0; never to a guest or to a lost phone. The phone ignores it when `pid` is not its profile. Optional message: `VERSION` stays 2. |
| Both | `{"t":"bye"}` | Clean leave. The TV frees the slot at once. When the TV app closes, it sends `bye` to every phone and closes the sockets 300 ms later (a close right after `bye` can drop it, issue #169); the phone goes to idle and says the TV closed. A TV that is killed sends nothing: the phone sees no frame for `PEER_TIMEOUT_MS` (3 s) and goes to reconnecting. |
| TV | `{"t":"kicked"}` | The host removed this player (Players modal). The slot is free at once and the token is no longer valid. The phone forgets the token, goes to its connect screen, and does not reconnect by itself. Any phone can join the slot again by the normal join. |
| TV | `{"t":"kicked","reason":"replaced"}` | The same profile joined from another phone while its holder was lost (see "Profiles"). Same effect as `kicked`; the phone shows "THIS PLAYER IS ALREADY IN THE ROOM." (`app.player_already_in_room`) The field `reason` is optional. |

Phone computation:

- `rtt = t3 - t0` (`t3` = phone clock when the pong arrives).
- `off = t1 - (t0 + t3) / 2`.

The TV computes the sensor age: `age = tv_receive_time - (packet_ts + off)`.
The error is about +/- RTT/2. Use the trend, not the single value. The value can be below zero.

## Fields of the wrong type

A JSON frame can hold any value in any field (REQ-N10). The TV and the phone read a field only with `Protocol.num` (a finite number), `Protocol.whole` (an integer), `Protocol.text` and `Protocol.flag` (a boolean). A value of another type gives the default of that field, so a `stat` with `"rtt": {}` is taken as `rtt = -1`, a `ping` echoes `id` and `t0` as numbers (0 when they are not), and a `hello` with `"v": [5]` has the wrong version. This is not a change of the protocol: the `VERSION` stays.

## Sensor packet (WebSocket binary frame, phone to TV, about 60 per second)

Little-endian. Size: 36 bytes.

| Offset | Type | Field |
|--------|------|-------|
| 0 | u8 | Type. `1` = sensor |
| 1 | u8 | Flags. Bit 0 = a finger touches the screen |
| 2 | u16 | Sequence number. It wraps. The TV counts gaps as lost packets |
| 4 | u32 | Phone clock in ms (`Time.get_ticks_msec()`) |
| 8 | f32 x3 | Gyroscope x, y, z in rad/s (`Input.get_gyroscope()`) |
| 20 | f32 x3 | Accelerometer x, y, z in m/s2 (`Input.get_accelerometer()`) |
| 32 | u8 | Button bits. Bit 0 = A, bit 1 = B |
| 33 | u8 | Reserved. Send 0 |
| 34 | u8 | Touch x, 0 to 255 over the screen width. While it is the turn of the phone in Pin Pals (`turn` with `s` 1 and no `k`), the phone sends the place on its aim strip instead, 0 (left end) to 255 (right end), and only for the finger on the strip |
| 35 | u8 | Touch y, 0 to 255 over the screen height |

The phone frame: x = right, y = top of the phone, z = out of the screen.

## Profiles (FD-22)

A profile lives on the phone (`docs/PROFILES_PLAN.md`). The TV keeps it in memory for the session only.

- `pid` is 32 hex characters; the TV makes it lower case. `av` is an integer from 0 to 255; the phone sends 0 to 31 (the sheet has 32 avatars) and the TV shows the slot number for an index it does not know. `name` has at most `NAME_MAX` = 10 characters. The TV keeps only letters of the Latin and Hebrew alphabets, digits and the space (the pixel fonts have no other glyph), and cuts the result at 10.
- A `hello` with no valid `pid` is a guest, also when `name` is not empty (an old phone that sends only a name shows that name and has no avatar). A guest with no name is "Player N".
- The TV makes the shown names different: a name that another player in a lower slot already has (the comparison ignores case and the spaces at the ends) gets " 2", " 3". The names are made again only outside a round, so a name does not change in the middle of a game.
- **The same `pid` on two phones (issue #388, owner decision of 2026-11-07).** In the phases `connect` and `menu`, when a `hello` or a `profile` brings a `pid` that another slot holds, and the phone of that slot is connected, the connected phone keeps the profile and the newer phone is a guest (the TV ignores its `pid`, `av` and `name`; the `welcome` or `profile` answer says `pid` is empty, as in a round). When the holder is lost (state LOST, slot kept in grace) the newer phone wins, also on a full TV: the TV frees the older slot and sends `kicked` with `reason` `replaced` to that phone if it is still connected. The TV remembers the token of the freed slot for 10 minutes (`REPLACED_TOKEN_MS`) and answers a `hello` with that token with the same `kicked`, so a phone that was offline does not come back and replace the newer one. In the phases `playing`, `paused` and `waiting` no slot is freed: the newer phone joins as a guest and can send `profile` in the next menu. No message changes, so `VERSION` stays 5.
- A phone that comes back with its token keeps the profile that the TV has for that slot; `pid`, `av` and `name` of that `hello` are ignored outside `connect` and `menu`.

**Copy of a profile.** A profile is copied to another phone with a text that starts with `WP1.`, shown as a QR code or copied to the clipboard (COPY CODE). The phone only reads a code by a scan (IMPORT); there is no paste (removed on 2026-11-02). It never goes over the network of the game and the TV never sees it. The format is in `docs/PROFILES_PLAN.md` section 6.1 (`scripts/core/profile_code.gd`). The QR encoder (`scripts/core/qr_encoder.gd`) goes up to version 14, error correction L, 458 bytes.

All these fields and messages are optional: an old TV or an old phone ignores them. (They were added at `VERSION` 2. `VERSION` 3 added the join PIN, 4 removed it with the beacon and 5 added the safety card of the swing games (`setup` and `swing_ok`, because a TV of version 5 waits for the answer of every phone and an older phone would never give it): a build of another version is rejected with `version`.)

## Slots, loss and reconnect

- The TV has 4 slots. A slot has the state `EMPTY`, `CONNECTED`, or `LOST`.
- When the socket closes or is silent for 3 seconds (`PEER_TIMEOUT_MS`, issue #56), the slot becomes `LOST`. A silent phone is lost at once: the TV does not wait for a close handshake that the phone cannot answer (for example when its Wi-Fi is gone). The TV keeps a lost slot for 5 seconds (`SLOT_GRACE_MS`, issue #44), then frees it. While the game is paused for it (phase `paused`), the TV keeps it for 5 minutes (`PAUSED_SLOT_GRACE_MS`), so that a phone call does not end the game.
- The game pauses while a participant is `LOST`, and it does not go on by itself (REQ-GM-30). The TV user chooses: "Resume without 2P" (the name of the player, or "2P" for a guest) frees the slot of the lost phone (only while another participant is connected), "Resume" goes on when the phones are back, "End game" leaves. A phone that comes back with its token gets its slot again. When the slot is freed (time over, or "Resume without"), a phone that comes back is a new player and waits for the next round. When no participant is left, the game ends with "No players connected".
- The phone reconnects after 0.5 s, 1 s, 2 s, and then every 2 s. It sends the saved `token`.
  The TV gives the same slot back.
- A `hello` with an unknown token is a new player.
- **Limits of the TV (issue #387, issue #388).** The token is 32 hex characters from `Crypto.generate_random_bytes(16)`. The TV keeps at most 16 connections that have not sent `hello` (`TvServer.MAX_PENDING`; more are closed at once), at most 4 of them from one address (`max_pending_per_ip`, so one device cannot keep the phones of the family out), and accepts at most 30 connections from one address in 10 s (`max_accepts_per_ip`). A socket buffers at most 32768 bytes (`BUFFER_BYTES`) and 1024 frames (about 15 s of sensor packets); a text frame above 4096 bytes (`MAX_TEXT_BYTES`) is dropped without parsing. A sensor packet with a NaN or INF float, or a gyro or accel value above 1000 (`SENSOR_MAX_ABS`, far above what a phone measures), is dropped (`Protocol.decode_sensor`). None of this changes a message, so `VERSION` stays 5.
- **The `pid` is not a secret (issue #388).** Profile sharing hands the `pid` to other phones on purpose, so a second phone can know it. The TV protects the profile of a connected phone: a newer phone with the same `pid` becomes a guest (above, REQ-FL-74). A holder that is lost can still be replaced, because that is how a family moves a profile to a new phone. Binding the `pid` to the token is not done. The effect is limited to the menu phases, and the host can remove any player.
- The phone gives up and shows an error only when the first connection fails 3 times, or when the TV sends `reject`.
- The phone also gives up (and returns to the connect screen) when the user taps "Disconnect".

## Version change

Change `VERSION` in `protocol.gd` when an old peer would misread the packet layout or a message, or when the new message is one that the other side **waits for**. A new optional field or message that nobody waits for does not change it (`lang`, `score`, `turn`, `profile`). A new message that one side waits for is incompatible, because an old peer never sends it: `setup` and `swing_ok` raised `VERSION` to 5 for that reason (a TV of version 5 waits for the answer of every phone). The TV rejects other versions.

`lang` and `welcome.lang` are still sent but the phone ignores them (issue #171). Remove both at the next `VERSION` bump (`LANG_REMOVE_AFTER_VERSION` in `protocol.gd`; `tests/protocol_doc.gd` fails if the bump is made and `lang` is still there).

**What keeps this document true.** `Protocol.MESSAGES` lists every message and its sender. `tests/protocol_doc.gd` checks that the messages of the tables above, the `"t"` values written in `scripts/net/tv_server.gd` and `scripts/net/controller_client.gd`, and `Protocol.MESSAGES` are the same set with the same senders, and that the version, the port, the size of the sensor packet, the time-outs, the number of slots and `NAME_MAX` quoted in this document are the values in `protocol.gd`.
