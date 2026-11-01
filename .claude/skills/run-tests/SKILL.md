---
name: run-tests
description: Run the Sababi headless tests and lint. Use before a pull request (the touched suites) or when asked to run tests, lint or check the build. The whole suite only when the user asks or the QA engineer decides.
---

`automation-developer` and `sw-developer` use this skill; `code-reviewer` runs only the suites the diff touches.

1. Make sure nothing holds the network ports. The tests start a real TV server on TCP 47801.
   ```sh
   lsof -iTCP:47801 -sTCP:LISTEN
   ```
   If a Godot process shows up, it is probably the user's TV app. Ask the user to quit it. Do not kill it.
2. Choose the scope. The default is 2a. Use 2b only when the user asks or when the QA engineer (`.claude/agents/qa.md`) decides that the change needs the whole suite (CLAUDE.md, "Tests and coverage").
   2a. The touched suites: first `godot --headless --path . --import` (once on a fresh checkout or after assets changed; without it fonts and sprite sheets do not load and a suite fails with the message "assets not imported", issue #291). Then `tests/run_one.sh tests/<x>.gd` (it imports when `.godot/imported` is missing and fails on a SCRIPT ERROR line) or `godot --headless --path . --script tests/<x>.gd` for each suite of `tests/suites.txt` that covers the changed module or rule. Say which suites you ran.
   2b. The whole suite: `tools/build.sh test`. It runs `tests/run_all.sh`: all suites of `tests/suites.txt` (unit, network, game rules, TV smoke tests), then the check of `tokens.css`. `tests/run_all.sh unit` runs only the unit tier (what the CI runs), `scenario` the rest.
   Expect `0 failed` and `smoke test done, 0 failed`.
   The count changes when tests are added. A failure at "server listens on 47801" means the port is busy.
3. Run lint: `gdlint scripts tests tools` and `shellcheck tests/*.sh tools/*.sh`.
   Install `gdtoolkit` with `pip install "gdtoolkit==4.*"` if needed. If pip fails on a certificate path, check `pip config list`
   and pass `PIP_CERT=` for that one command. Do not edit the user's pip config.
4. For a change or a bug fix, the touched suites include the tests that `qa` and `automation-developer` wrote or updated for it (CLAUDE.md, "Tests and coverage"). Report the real counts and any failures. Never report a pass for a step that did not run.

5. Run the coverage only when the user explicitly tells you to: `GODOT=<path> tools/coverage.sh` (see the README, section Coverage). It fails when a module is below 80%.
   It is slow (about 20 minutes: it runs the tests again on an instrumented copy), so never start it on your own.
   Report the total and the lowest modules. For a module that is below, write tests that check its behavior (not tests that only run lines).
   Set a module aside in `tools/coverage/exclusions.txt` only when it needs extremely hard work to test, and tell the user why.

Screenshot scripts (`tests/screenshots*.gd`) need a display and are not part of the CI run.
