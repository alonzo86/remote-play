---
name: review
description: Review a change to the Sababi Godot project (a diff, a branch or a GitHub pull request) against its architecture rules and known pitfalls, and write a structured report. Use before a commit or PR, after a PR is created, or when asked to review code.
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
- Screens are built in code in the 8-bit arcade style (`docs/TV_FLOW.md`, REQ-FL-37 to 46). Image files only where REQ-P6 allows them.
- The style is 8-bit arcade (FD-18, `docs/ARCADE_STYLE_PLAN.md`); phases 1 to 4 are built (menus, phone, shell, and the pixel worlds of all six games). A game that draws a pixel world follows REQ-GM-47i to 47n. A change that adds rounded or shadowed widgets, other fonts or art outside the plan is a finding. A change that implements a phase of the plan follows section 2 of the plan.
- A new game is also for children (REQ-GM-80 to 84): friendly made-up characters, no violence against anything alive, no blood and no scary things (toy beams at lifeless things are fine), no point penalty for a mistake and a short wait for a player who is out (or a team game that ends when the last player is out), one hint line, large and slow at the start, positive texts. Report a broken rule by its ID.
- A new game follows the visual language: shell (REQ-GM-45), player colors (REQ-GM-46), toy-like world (REQ-GM-47), and a tile screenshot that looks like the same toy box as the Games screen (REQ-GM-49).

**Games**
- A game has `docs/games/<id>.md` and a `doc` field in `scripts/game/registry.gd`. A change to game behavior changes that file (REQ-GM-5).
- Check the change against `docs/GAME_REQUIREMENTS.md` (general, plus 2D or 3D) and the game file. Report a broken requirement by its ID.
- Statuses in the game file match the code. A requirement marked Done has a check, or says why it has none.

**Strings**
- A new or changed row of `assets/lang/strings.csv` is listed in the pull request description (key, old and new text, English and Hebrew) and
  waits for the user's review (CLAUDE.md). Report a change of strings that is not listed. Every row has a `where`; a changed use changes it.
- The code has keys, never English text (REQ-FL-63).

**Tests and docs**
- Behaviour changes in `scripts/` need a check in `tests/run_tests.gd` or `tests/smoke_tv.gd`.
- Every module has 80% line coverage (`tools/coverage.sh`, run only when the user asked for it: do not report a missing coverage run as a finding), or is set aside with a reason in `tools/coverage/exclusions.txt`.
  Read the new tests: each must assert a behavior and fail when it breaks. Report a test that only runs lines, and a set-aside module
  that could be tested without extreme work.
- User-visible changes update `README.md`, and test results go in `docs/MANUAL_TESTS.md`.

## Report

Use these sections. Do not fill a section for the sake of it: write "No critical issues found", "No other potential improvements found" or
"No tests to improve found". Comment only on changed code. Keep style nits to a minimum.

1. **Summary**: the goal of the change (from the PR title and body, or the commits), the main strengths, the key findings.
2. **Good practices observed** (🟢): what the change does well.
3. **Issues and improvements**, with a count for each group. Each issue has a title, `file:line`, a description (the failing scenario), and a short fix.
   - 🔴 **Critical issues**: wrong behavior or a crash, a security problem, a performance problem (leak, endless loop), or a broken requirement ID.
   - 🟡 **Other potential improvements**: type safety, edge cases, maintainability. These can wait.
4. **Tests**: are the new or changed tests enough to catch a break of the change? Flag an untested critical edge case or important function.
   Skip trivial code (a getter). Say for each finding whether to improve the tests and how.

Focus on: errors and exceptions, type safety, new and changed tests, edge cases, code quality.

## Reviewing a pull request

When the target is a PR (a number or a URL):
- `gh auth status` first: use `alonzo86` for this repo, never another account.
- Get the title, body, author, state, labels and the stats: `gh pr view <n> --json title,body,author,state,labels,additions,deletions,changedFiles,commits`.
- Get the diff: `gh pr diff <n>`. Save it in the scratchpad. If a saved diff of this PR is less than an hour old, reuse it. Otherwise fetch it again.
  Read it in chunks when it is large.
- Review against the goals of the PR, then write the report.

### Posting

Post without asking the user first (decision of the owner, 2026-10-29). Use temp files for the comment bodies (`gh pr comment <n> --body-file`) and delete them after.
Every comment starts with "🤖 AI Code Review", so it is clear that an AI wrote it, and ends with the Claude Code footer.

- **After the PR is created by `pr-submit`** (CLAUDE.md): post **one** comment with the Summary, Good practices, every issue in full, and Tests.
  With no findings, post a short comment that says so and lists what you checked.
- **When the user asks for a review of a PR**: post it in parts.
  1. Summary, Good practices, and for Issues and improvements only the counts.
  2. One comment for each issue, titled `🔴 🤖 AI Code Review - Issue #N` (critical) or `🟡 🤖 AI Code Review - Issue #N` (other).
     Quote the body (`>`) with the file, the code, the issue and the fix. After the quote add a line `**Developer answer:**` for the author to reply.
  3. The Tests comment.

Do not fix your own findings and do not merge. The owner of the PR (`sw-developer`) addresses every finding with a fix or a justification and posts a summary comment; you review again after that comment and decide if each fix and justification holds. When you agree the PR can be merged, except a PR that adds or changes strings: it waits for the user. After 2 cycles of disagreement `sw-developer` states the disagreement in a comment and the PR is left for the user; you do not merge (CLAUDE.md, "Pull requests"). Tell the user what you found.
