---
name: run-tests
description: Run the Sababi headless tests and lint. Use after any change to scripts, tests or the Android plugin, or when asked to run tests, lint or check the build.
---

1. Make sure nothing holds the network ports. The tests start a real TV server on TCP 47801.
   ```sh
   lsof -iTCP:47801 -sTCP:LISTEN
   ```
   If a Godot process shows up, it is probably the user's TV app. Ask the user to quit it. Do not kill it.
2. Run the tests: `tools/build.sh test`. It runs `tests/run_all.sh`: all suites of `tests/suites.txt` (unit, network, game rules, TV smoke tests), then the check of `tokens.css`. `tests/run_all.sh unit` runs only the unit tier (what the CI runs), `scenario` the rest.
   Expect `178 checks, 0 failed` and `smoke test done, 0 failed`.
   The count changes when tests are added. A failure at "server listens on 47801" means the port is busy.
3. Run lint: `gdlint scripts tests tools` and `shellcheck tests/*.sh tools/*.sh`.
   Install `gdtoolkit` with `pip install "gdtoolkit==4.*"` if needed. If pip fails on a certificate path, check `pip config list`
   and pass `PIP_CERT=` for that one command. Do not edit the user's pip config.
4. Report the real counts and any failures. Never report a pass for a step that did not run.

5. Run the coverage: `GODOT=<path> tools/coverage.sh` (see the README, section Coverage). It fails when a module is below 80%.
   It is slow (it runs the tests again on an instrumented copy), so run it before a pull request and when tests or scripts changed.
   Report the total and the lowest modules. For a module that is below, write tests that check its behavior (not tests that only run lines).
   Set a module aside in `tools/coverage/exclusions.txt` only when it needs extremely hard work to test, and tell the user why.

Screenshot scripts (`tests/screenshots*.gd`) need a display and are not part of the CI run.
