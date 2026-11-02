---
name: sync-docs
description: Find and update every document and test that a change makes wrong, before the pull request is created and again before the issue is closed. Use for any change of behavior, screens, texts, buttons, requirements, protocol, build or tools.
---

A change is not finished while a document or a test still describes the old behavior (CLAUDE.md, "Finishing work without the owner"). Run
this skill after the code works and before `pr-submit`, and run step 2 again before an issue is closed.

## 1. List what the change removed, renamed or replaced

Write the list in your notes: every removed or renamed button, screen, key of `assets/lang/strings.csv`, function, file, constant, setting,
protocol field, tool or build option, and every value that changed (a color token, a size, a version such as the minimum iOS version).

## 2. Search for each item (the whole repository, not only the files you touched)

For each item run `grep -rniE "<old name>|<old text>|<old value>" docs README.md CLAUDE.md .claude assets/lang/strings.csv tests tools scripts ios export_presets.cfg`
(leave out `docs/evidence/` and build output). Search for the English text, the key, the function or file name and the old value. Also search
the words a person would use ("PLAYERS button", "yellow frame", "clipboard"). Open each hit and decide: wrong now, history, or still true.

## 3. Update by change type

| The change touches | Update in the same PR |
|--------------------|-----------------------|
| Behavior or a screen | The requirement (`docs/TV_FLOW.md`, `docs/REQUIREMENTS.md`, `docs/GAME_REQUIREMENTS.md`, `docs/games/<id>.md`); the plan file that describes it (`docs/*_PLAN.md`: mark old text as removed with the date, do not leave it as if current) |
| A text | The `strings.csv` row and its `where`; the requirement that quotes the text; the manual steps that quote it; the PR string list |
| A look (color, size, token) | `docs/ARCADE_STYLE_PLAN.md`, `docs/design-system/`, the requirement (`REQ-FL-38a`, `REQ-FL-41a`), `tests/design_tokens.gd` |
| The protocol | `docs/PROTOCOL.md` and the `change-protocol` skill |
| A build, export, plugin or minimum OS version | `docs/EXPORT.md`, `export_presets.cfg`, `tools/*.sh`, `docs/THIRD_PARTY.md`, the plan file |
| Data the app reads, stores, sends or asks permission for | `docs/legal/privacy-notice.md` and `docs/PRIVACY_NOTICE_DRAFT.md` are owner only: do not edit them; state in the PR what is out of date and label it `needs-owner` |
| A device check | `docs/MANUAL_TESTS.md` (steps with a pass or fail value, the Summary table, "Tests to run, in order"); never mark a step as passed |
| A thing a machine can check | The test, `tests/suites.txt`, `docs/AUTOMATED_TESTS.md` (an `A-<test>-<item>` row; remove the manual step it replaced) |
| A new or removed doc, test suite or module | `README.md`, `docs/AGENTS.md`, `docs/REQ_COVERAGE.md` where they list it |

## 4. Tests

Search `tests/` for the removed names and old values, not only for the suites that fail today: a test that still passes can check the old
behavior (for example a list that no longer matters). Update or delete it, and add a test for the new behavior that fails when it breaks.

## 5. Report

Put a section "Docs and tests aligned" in the PR description: the removed or renamed items, the files you searched, the files you changed,
and the hits you left on purpose (history, owner-only text) with the reason. An owner-only hit gets one PR comment, the label `needs-owner`
and a line in the final message. Do not write "no docs needed" without the searches of step 2.
