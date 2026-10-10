# Network protocol, version 2

This document uses ASD-STE100 style. Code: `scripts/core/protocol.gd`.

## Ports

| Port | Type | Use |
|------|------|-----|
| 47800 | UDP | TV sends a beacon. Phones listen. |
| 47801 | TCP | WebSocket server on the TV. Path and query are not used. |

## Discovery beacon (UDP, TV to LAN, 1 per second)

The TV sends the beacon to `255.255.255.255`, to the `/24` subnet broadcast address, and to `127.0.0.1`.

```json
{"t":"beacon","v":2,"room":"KQZM","port":47801,"name":"Living Room TV","players":2,"max":4}
```

The phone uses the sender IP address of the UDP packet as the TV address.
A TV that is silent for 4 seconds is removed from the phone list.

The room code has 4 letters from `ACDEFGHJKLMNPQRTUVWXYZ`. It is not a password.
It only tells two TVs apart on one network.

## Join (WebSocket, JSON text frames)

| From | Message | Meaning |
|------|---------|---------|
| Phone | `{"t":"hello","v":2,"room":"KQZM","token":"","name":"","pid":"","av":-1}` | First message. `room` can be empty (join by IP). `token` is empty for a new player. `name` can be empty: the TV then shows "Player N". `pid` and `av` are optional: the profile ID (32 lower-case hex characters) and the avatar index (0 to 255) of the profile that plays (FD-22, "Profiles" below). |
| TV | `{"t":"welcome","slot":0,"token":"…","color":"#e63946","phase":"connect","name":"Living Room TV","lang":"en","pid":"","av":-1,"pname":""}` | Accepted. The phone saves `token`. `pid`, `av` and `pname` are the profile that the TV accepted (empty or -1 for a guest). `name` here is the name of the TV; the player name is `pname`. `lang` is the language of the TV, `en` or `he`; the field is optional (a TV of an older build does not send it) and the phone keeps its own language then (REQ-FL-62). |
| TV | `{"t":"reject","reason":"full"}` | `reason`: `full`, `bad_room`, `version`. |

The TV closes a connection that sends no `hello` in 5 seconds.

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
| Phone | `{"t":"profile","pid":"…","name":"Noam","av":7}` | The player changed profile on the phone (FD-22). `{"t":"profile"}` alone is a guest. The TV accepts it only in the phases `connect` and `menu`. Optional message. |
| TV | `{"t":"profile","pid":"…","name":"Noam","av":7}` | The answer to every `profile` message: the values the TV accepted (empty for a guest). In the phases `playing`, `paused` and `waiting` the TV does not change the profile and answers with the stored one. The phone shows the answer as the truth. |
| Both | `{"t":"bye"}` | Clean leave. The TV frees the slot at once. |
| TV | `{"t":"kicked"}` | The host removed this player (Players modal). The slot is free at once and the token is no longer valid. The phone forgets the token, goes to its connect screen, and does not reconnect by itself. Any phone can join the slot again by the normal join. |
| TV | `{"t":"kicked","reason":"replaced"}` | The same profile joined from another phone (see "Profiles"). Same effect as `kicked`; the phone shows "Your player joined another phone." The field `reason` is optional. |

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
| 34 | u8 | Touch x, 0 to 255 over the screen width |
| 35 | u8 | Touch y, 0 to 255 over the screen height |

The phone frame: x = right, y = top of the phone, z = out of the screen.

## Profiles (FD-22)

A profile lives on the phone (`docs/PROFILES_PLAN.md`). The TV keeps it in memory for the session only.

- `pid` is 32 hex characters; the TV makes it lower case. `av` is an integer from 0 to 255; the phone sends 0 to 15 (the sheet has 16 avatars) and the TV shows the slot number for an index it does not know. `name` has at most `NAME_MAX` = 10 characters. The TV keeps only letters of the Latin and Hebrew alphabets, digits and the space (the pixel fonts have no other glyph), and cuts the result at 10.
- A `hello` with no valid `pid` is a guest, also when `name` is not empty (an old phone that sends only a name shows that name and has no avatar). A guest with no name is "Player N".
- The TV makes the shown names different: a name that another player in a lower slot already has (the comparison ignores case and the spaces at the ends) gets " 2", " 3". The names are made again only outside a round, so a name does not change in the middle of a game.
- **The same `pid` on two phones.** In the phases `connect` and `menu` the newer phone wins, also on a full TV: the TV frees the older slot and sends `kicked` with `reason` `replaced` to that phone. The TV remembers the token of the freed slot for 10 minutes (`REPLACED_TOKEN_MS`) and answers a `hello` with that token with the same `kicked`, so a phone that was offline does not come back and replace the newer one. In the phases `playing`, `paused` and `waiting` no slot is freed: the newer phone joins as a guest and can send `profile` in the next menu.
- A phone that comes back with its token keeps the profile that the TV has for that slot; `pid`, `av` and `name` of that `hello` are ignored outside `connect` and `menu`.

All these fields and messages are optional, so `VERSION` stays 2: an old TV or an old phone ignores them.

## Slots, loss and reconnect

- The TV has 4 slots. A slot has the state `EMPTY`, `CONNECTED`, or `LOST`.
- When the socket closes or is silent for 5 seconds, the slot becomes `LOST`. A silent phone is lost at once: the TV does not wait for a close handshake that the phone cannot answer (for example when its Wi-Fi is gone). The TV keeps a lost slot for 30 seconds. While the game is paused for it (phase `paused`), the TV keeps it for 5 minutes (`PAUSED_SLOT_GRACE_MS`), so that a phone call does not end the game.
- The game pauses while a participant is `LOST`, and it does not go on by itself (REQ-GM-30). The TV user chooses: "Resume without P2" (the name of the player, or "P2" for a guest) frees the slot of the lost phone (only while another participant is connected), "Resume" goes on when the phones are back, "End game" leaves. A phone that comes back with its token gets its slot again. When the slot is freed (time over, or "Resume without"), a phone that comes back is a new player and waits for the next round. When no participant is left, the game ends with "No players connected".
- The phone reconnects after 0.5 s, 1 s, 2 s, and then every 2 s. It sends the saved `token`.
  The TV gives the same slot back.
- A `hello` with an unknown token is a new player.
- The phone gives up and shows an error only when the first connection fails 3 times, or when the TV sends `reject`.
- The phone also gives up (and returns to the connect screen) when the user taps "Leave".

## Version change

Change `VERSION` in `protocol.gd` when an old peer would misread the packet layout or a message. A new optional field or message does not change it (`lang`, `score`, `profile`). The TV rejects other versions.
