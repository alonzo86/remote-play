# Network protocol, version 3

This document uses ASD-STE100 style. Code: `scripts/core/protocol.gd`.

## Ports

| Port | Type | Use |
|------|------|-----|
| 47800 | UDP | TV sends a beacon. Phones listen. |
| 47801 | TCP | WebSocket server on the TV. Path and query are not used. |

## Discovery beacon (UDP, TV to LAN, 1 per second)

The TV sends the beacon to `255.255.255.255`, to the `/24` subnet broadcast address, and to `127.0.0.1`.

```json
{"t":"beacon","v":3,"room":"KQZM","port":47801,"name":"Living Room TV","players":2,"max":4}
```

The phone uses the sender IP address of the UDP packet as the TV address.
A TV that is silent for 4 seconds is removed from the phone list.

### Probe (finding a TV when the beacon does not arrive)

A router can drop broadcast packets, and a computer can refuse to send them (for example macOS without the Local Network permission
for the app), while a direct connection works (the QR code joins). Then the phone looks for the TV itself (REQ-FL-83): it opens a
WebSocket to port 47801 of every address of its `/24` network (the other 253 addresses of each private IPv4 address of the phone, of the best kind only: `192.168.x.x`, else `10.x.x.x`, else `172.16.x.x` to `172.31.x.x`; a mobile-data address of another kind is not scanned),
32 at a time with a timeout of 1.5 s, and sends `{"t":"hello","v":3,"room":"-"}`. `-` is not in the room alphabet, so the TV answers
`{"t":"reject","reason":"bad_room","room":"KQZM","name":"Living Room TV","players":2,"max":4}` and closes: the phone has the room code,
the name and the player count, and joins nothing. A TV found this way is listed like a beacon TV, and stays in the list for 20 s after
the last answer (a TV with a beacon stays 4 s). The phone scans only when the user taps Refresh (a scan that starts by itself looks like a port scan to some routers, which can then block the phone), and a join stops a scan that runs. A TV of an older build answers `bad_room` without `room`; it is not listed by the scan.

The room code has 4 letters from `ACDEFGHJKLMNPQRTUVWXYZ`. It is not a password: the beacon carries it, so every device on the network sees it.
The join PIN (see "Join PIN" below) is a password of a kind, and the beacon never carries it.
It only tells two TVs apart on one network.

## Join (WebSocket, JSON text frames)

| From | Message | Meaning |
|------|---------|---------|
| Phone | `{"t":"hello","v":3,"room":"KQZM","token":"","pin":"0427","name":"","pid":"","av":-1}` | First message. `room` can be empty (join by IP). `token` is empty for a new player. `pin` is the join PIN of the TV (4 digits). It is needed for a new player and not for a phone that returns with a token the TV knows. `name` can be empty: the TV then shows "Player N". `pid` and `av` are optional: the profile ID (32 lower-case hex characters) and the avatar index (0 to 255) of the profile that plays (FD-22, "Profiles" below). |
| TV | `{"t":"welcome","slot":0,"token":"…","color":"#e63946","phase":"connect","name":"Living Room TV","lang":"en","pid":"","av":-1,"pname":""}` | Accepted. The phone saves `token`. `pid`, `av` and `pname` are the profile that the TV accepted (empty or -1 for a guest). `name` here is the name of the TV; the player name is `pname`, the name that the TV shows (with a number when another player has the same name, for example `Sam 2`). `lang` is the language of the TV, `en` or `he`; the field is optional (a TV of an older build does not send it) and the phone keeps its own language then (REQ-FL-62). |
| TV | `{"t":"reject","reason":"full"}` | `reason`: `full`, `bad_room`, `bad_pin`, `pin_locked`, `version`. `bad_pin`: a new phone sent no PIN or a wrong one. `pin_locked`: too many wrong PINs, try again later. A `bad_room` answer also has `room` (the room code of the TV), `name`, `players` and `max`, the same values as the beacon: see "Probe". The fields are optional; a phone ignores them when they are not there. |

The TV closes a connection that sends no `hello` in 5 seconds.

## Join PIN (FD-25)

The TV makes a PIN of 4 digits when it starts and shows it on the Connect screen and in the Players modal. It is never sent over the network by the TV. The QR code of the TV holds it: `ws://IP:PORT/ROOM?pin=0427`. A phone that scans the code sends the PIN in `hello`; a phone that joins from the list of found TVs asks the player to type it.

- A `hello` that has to take a new slot (no token, or a token that the TV does not know) must carry the PIN of the TV. Without it, or with a wrong one, the TV answers `reject` with `reason` `bad_pin`.
- A `hello` with a token of a player who is in a slot (also a lost one) needs no PIN: that phone joined before.
- The probe (see "Probe") needs no PIN: the TV answers `bad_room` before it checks the PIN, and that answer has no PIN. The probe `hello` carries `"v":3`, like every `hello`.
- A phone on the same device as the TV (the address is the loopback address) needs no PIN. This is for a development run and for the tests. (`TvServer.pin_exempt_loopback`)
- After `PIN_TRIES` (5) wrong PINs the TV refuses every new phone for `PIN_LOCK_MS` (30 s), also one with the right PIN, and answers `reject` with `reason` `pin_locked`. The PIN stays. Guessing 10000 PINs then takes many hours. A device can still lock the join for others by guessing wrong; phones that are in a slot are not affected.
- The traffic is still not encrypted. The PIN keeps a device that only sees the beacon from joining. It does not stop a device that reads the traffic of a phone that joins.
- `VERSION` is 3 since FD-25: a new phone sends `pin`, and a TV of version 2 does not ask for it. An old and a new build see no beacon from each other and reject each other with `version`.

## Messages after the join

| From | Message | Meaning |
|------|---------|---------|
| Phone | `{"t":"ping","id":7,"t0":123456}` | Once each second. `t0` is the phone clock in ms. |
| TV | `{"t":"pong","id":7,"t0":123456,"t1":987654}` | `t1` is the TV clock in ms when the ping arrived. |
| Phone | `{"t":"stat","rtt":14.2,"off":864198.5,"hz":59.8}` | Sent after each pong. `rtt` = RTT in ms. `off` = TV clock minus phone clock. `hz` = sensor packets sent per second. |
| Phone | `{"t":"recenter"}` | Set the neutral pose and zero the yaw. |
| TV | `{"t":"phase","v":"menu"}` | What the TV shows. `v`: `connect` (logo and Connect screens), `menu` (Games, Settings, Players), `playing`, `paused`, `waiting`. `waiting` is sent only to a phone that joined during a round: it takes part in the next round. |
| TV | `{"t":"lang","v":"he"}` | The language of the TV changed (Settings). Every connected phone switches its UI at once (REQ-FL-62). `v`: `en` or `he`. An unknown value is ignored. Optional message: an older phone ignores it, so the protocol `VERSION` stays 2. |
| TV | `{"t":"haptic","ms":40}` | Vibrate the phone. |
| TV | `{"t":"score","rank":2,"of":4,"v":"12"}` | The place of this player in the running game (`rank`, 1 is first; equal scores share a place; 0 while nobody has scored), the number of ranked players (`of`) and the score text (`v`, at most 12 characters, empty when the game has no score yet, for example a race before the finish). Sent once for each change, only while a game runs. The phone shows it in its header (REQ-FL-67) and clears it at any phase other than `playing` and `paused`, and when it joins again. Optional message: an older phone ignores it, so the protocol `VERSION` stays 2. |
| TV | `{"t":"turn","s":1,"who":""}` | Whose turn it is in a game with turns (Pin Pals, REQ-BW-14). `s`: 0 no turn line, 1 the turn of this phone, 2 another player is on turn (`who` is the name of that player, at most 20 characters). `k` is optional: `"golf"` makes the waiting line say that the player is putting (Mini Golf, REQ-MG-12); without it the line says that the player is bowling. Sent once for each change, only while a game runs. The phone shows a line under its score row and clears it at any phase other than `playing` and `paused`, and when it joins again. Optional message: an older phone ignores it, so the protocol `VERSION` stays 3. |
| Phone | `{"t":"profile","pid":"…","name":"Noam","av":7}` | The player changed profile on the phone (FD-22). `{"t":"profile"}` alone is a guest. The TV accepts it only in the phases `connect` and `menu`. Optional message. |
| TV | `{"t":"profile","pid":"…","name":"Noam","av":7}` | The answer to every `profile` message: the values the TV accepted (empty for a guest); `name` is the name that the TV shows. In the phases `playing`, `paused` and `waiting` the TV does not change the profile and answers with the stored one. The phone shows the answer as the truth. |
| TV | `{"t":"result","pid":"…","key":"paint_grab|medium","v":340}` | The result of the round for the profile of this phone (FD-22, REQ-GM-99). `key` is the best key of the game, `v` the score as a whole number (a time in milliseconds). Sent at the end of a round to each finished player with a profile and a score above 0; never to a guest or to a lost phone. The phone ignores it when `pid` is not its profile. Optional message: `VERSION` stays 2. |
| Both | `{"t":"bye"}` | Clean leave. The TV frees the slot at once. |
| TV | `{"t":"kicked"}` | The host removed this player (Players modal). The slot is free at once and the token is no longer valid. The phone forgets the token, goes to its connect screen, and does not reconnect by itself. Any phone can join the slot again by the normal join. |
| TV | `{"t":"kicked","reason":"replaced"}` | The same profile joined from another phone (see "Profiles"). Same effect as `kicked`; the phone shows "THIS PLAYER IS ALREADY IN THE ROOM." (`app.player_already_in_room`) The field `reason` is optional. |

Phone computation:

- `rtt = t3 - t0` (`t3` = phone clock when the pong arrives).
- `off = t1 - (t0 + t3) / 2`.

The TV computes the sensor age: `age = tv_receive_time - (packet_ts + off)`.
The error is about +/- RTT/2. Use the trend, not the single value. The value can be below zero.

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
- **The same `pid` on two phones.** In the phases `connect` and `menu` the newer phone wins, also on a full TV: the TV frees the older slot and sends `kicked` with `reason` `replaced` to that phone. The TV remembers the token of the freed slot for 10 minutes (`REPLACED_TOKEN_MS`) and answers a `hello` with that token with the same `kicked`, so a phone that was offline does not come back and replace the newer one. In the phases `playing`, `paused` and `waiting` no slot is freed: the newer phone joins as a guest and can send `profile` in the next menu.
- A phone that comes back with its token keeps the profile that the TV has for that slot; `pid`, `av` and `name` of that `hello` are ignored outside `connect` and `menu`.

**Copy of a profile.** A profile is copied to another phone with a text that starts with `WP1.`, shown as a QR code or copied to the clipboard. It never goes over the network of the game and the TV never sees it. The format is in `docs/PROFILES_PLAN.md` section 6.1 (`scripts/core/profile_code.gd`). The QR encoder (`scripts/core/qr_encoder.gd`) goes up to version 14, error correction L, 458 bytes.

All these fields and messages are optional: an old TV or an old phone ignores them. (They were added at `VERSION` 2. The join PIN raised it to 3.)

## Slots, loss and reconnect

- The TV has 4 slots. A slot has the state `EMPTY`, `CONNECTED`, or `LOST`.
- When the socket closes or is silent for 5 seconds (planned: 3 seconds, issue #56), the slot becomes `LOST`. A silent phone is lost at once: the TV does not wait for a close handshake that the phone cannot answer (for example when its Wi-Fi is gone). The TV keeps a lost slot for 30 seconds. While the game is paused for it (phase `paused`), the TV keeps it for 5 minutes (`PAUSED_SLOT_GRACE_MS`), so that a phone call does not end the game.
- The game pauses while a participant is `LOST`, and it does not go on by itself (REQ-GM-30). The TV user chooses: "Resume without 2P" (the name of the player, or "2P" for a guest) frees the slot of the lost phone (only while another participant is connected), "Resume" goes on when the phones are back, "End game" leaves. A phone that comes back with its token gets its slot again. When the slot is freed (time over, or "Resume without"), a phone that comes back is a new player and waits for the next round. When no participant is left, the game ends with "No players connected".
- The phone reconnects after 0.5 s, 1 s, 2 s, and then every 2 s. It sends the saved `token`.
  The TV gives the same slot back.
- A `hello` with an unknown token is a new player.
- The phone gives up and shows an error only when the first connection fails 3 times, or when the TV sends `reject`.
- The phone also gives up (and returns to the connect screen) when the user taps "Disconnect".

## Version change

Change `VERSION` in `protocol.gd` when an old peer would misread the packet layout or a message. A new optional field or message does not change it (`lang`, `score`, `turn`, `profile`). The TV rejects other versions.
