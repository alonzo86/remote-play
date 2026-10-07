---
name: review
description: Review a change to the Remote Play Godot project against its architecture rules and known pitfalls. Use before a commit or PR, or when asked to review code, a diff or a branch.
---

Review the current diff (`git diff main...HEAD` plus uncommitted changes), or the files or PR the user names.
Report only real problems, most severe first, each with file:line, the failing scenario, and a fix.
Run the `run-tests` skill when the diff touches `scripts/`, `tests/` or the plugin.

## Checklist

**Architecture**
- `scripts/net/` and `scripts/input/` must never refer to `scripts/game/`. Games read `PlayerInput` only.
- A minigame extends `scripts/game/minigame.gd` and uses no networking script.
- Phone-only code (sensors, UI, `controller_*`) must not run on the TV, and the reverse. Role comes from `Role` (feature tag or `--role=`).
- Sensor fusion stays on the TV (`orientation.gd`). The phone sends raw values.

**Protocol and sensors**
- Any change to a packet, message or constant in `scripts/core/protocol.gd` needs a matching update in `docs/PROTOCOL.md`, and a `VERSION` bump if it is incompatible (see `change-protocol`).
- Sensor sign conventions: accel `z = +9.8` flat with the screen up; x right, y toward the top of the phone. Godot on Android reports accel inverted, and `sensor_sampler.gd` flips it. Do not fix signs anywhere else, and keep `invert_tilt` off by default.
- Timestamps are u32 and wrap. Packet sequence is u16 and wraps.

**Networking**
- The TV and the phones can both stall, drop or reconnect at any time. Check timeouts (`PEER_TIMEOUT_MS`, `HELLO_TIMEOUT_MS`, `SLOT_GRACE_MS`), reconnect with the token, and slot reuse.
- No blocking waits on the main thread. Awaits must have a timeout.

**Android**
- Changes to `android/plugin/` need `tools/patch_android_manifest.sh` and a manifest permission when an API needs one.
- `Engine.has_singleton("QrScanner")` is false on desktop. Every plugin call needs a no-plugin fallback.
- The TV preset needs `required="false"` on touchscreen and sensor features.

**Style (matches the code)**
- GDScript with tabs, typed variables where the surrounding code types them, `##` doc comments, short ASD-STE100 style in docs.
- `gdlint scripts tests tools` must pass (`.gdlintrc`). Shell scripts pass `shellcheck`.
- Screens are built in code in the Party Pop style (`docs/TV_FLOW.md`). Image files only where REQ-P6 allows them.
- A new game follows the visual language: shell (REQ-GM-45), player colors (REQ-GM-46), toy-like world (REQ-GM-47), and a tile screenshot that looks like the same toy box as the Games screen (REQ-GM-49).

**Games**
- A game has `docs/games/<id>.md` and a `doc` field in `scripts/game/registry.gd`. A change to game behavior changes that file (REQ-GM-5).
- Check the change against `docs/GAME_REQUIREMENTS.md` (general, plus 2D or 3D) and the game file. Report a broken requirement by its ID.
- Statuses in the game file match the code. A requirement marked Done has a check, or says why it has none.

**Tests and docs**
- Behaviour changes in `scripts/` need a check in `tests/run_tests.gd` or `tests/smoke_tv.gd`.
- User-visible changes update `README.md`, and test results go in `docs/DEVICE_TEST.md`.
