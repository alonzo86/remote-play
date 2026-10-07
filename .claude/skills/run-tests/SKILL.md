---
name: run-tests
description: Run the Remote Play headless tests and lint. Use after any change to scripts, tests or the Android plugin, or when asked to run tests, lint or check the build.
---

1. Make sure nothing holds the network ports. The tests start a real TV server on TCP 47801 and UDP 47800.
   ```sh
   lsof -iTCP:47801 -sTCP:LISTEN
   ```
   If a Godot process shows up, it is probably the user's TV app. Ask the user to quit it. Do not kill it.
2. Run the tests: `tools/build.sh test`. It runs `tests/run_all.sh` (unit and network tests, then the TV smoke test).
   Expect `47 checks, 0 failed` and `smoke test done, 0 failed`.
   The count changes when tests are added. A failure at "server listens on 47801" means the port is busy.
3. Run lint: `gdlint scripts tests tools` and `shellcheck tests/run_all.sh tools/*.sh`.
   Install `gdtoolkit` with `pip install "gdtoolkit==4.*"` if needed. If pip fails on a certificate path, check `pip config list`
   and pass `PIP_CERT=` for that one command. Do not edit the user's pip config.
4. Report the real counts and any failures. Never report a pass for a step that did not run.

Screenshot scripts (`tests/screenshots*.gd`) need a display and are not part of the CI run.
