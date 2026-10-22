---
name: change-protocol
description: Change the Sababi network protocol (packets, messages, ports, timeouts). Use when a request touches scripts/core/protocol.gd, the sensor packet, the WebSocket messages or the discovery beacon.
---

The protocol is shared by the TV and the controller, which can be different builds on the same network.

1. Edit `scripts/core/protocol.gd` first. Keep the encoder and the decoder together.
2. Update `docs/PROTOCOL.md` in the same change: the tables, the JSON examples and the byte layout of the sensor packet.
3. Compatibility:
   - Adding an optional JSON field or message is compatible. Old peers ignore it (`lang`, `score`, `profile`, `pid`, `av`). The messages are listed in `docs/PROTOCOL.md`.
   - Changing the binary packet layout, a field meaning, or a required message is not compatible. Bump `VERSION`. `hello` carries `v`, and a mismatched peer is rejected.
   - Keep `SENSOR_PACKET_SIZE` equal to the real size.
4. Update every user: `tv_server.gd`, `controller_client.gd`, `player_input.gd`,
   and the tests in `tests/run_tests.gd` (codec round trip, wrong version, reconnect).
5. Timeouts (`PEER_TIMEOUT_MS`, `SLOT_GRACE_MS`, `HELLO_TIMEOUT_MS`) interact with Wi-Fi gaps. Measured gaps reach 380 ms on
   a desktop TV. Do not set a timeout below about 2 s without a device test.
6. Run `run-tests`. Then test the real pair, TV and phone, because the headless tests use loopback only.
