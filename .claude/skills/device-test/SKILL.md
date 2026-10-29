---
name: device-test
description: Guide an on-device test run (phone and TV) from docs/MANUAL_TESTS.md and record the results. Use when the user is testing on real hardware, reports a device test result, or asks what to retest.
---

The `qa` agent runs this flow. A note in a result goes to `product-engineer` and `qa` for the requirement change and the issue (CLAUDE.md, Manual tests); a step a machine can check goes to `automation-developer`.

1. Read `docs/MANUAL_TESTS.md`. It holds the tests, a results table for every test, the run log and the Summary. Evidence goes in `docs/evidence/`.
2. Check the setup before the tests: current controller APK installed (`build-deploy`), TV and phone on the same Wi-Fi,
   **Invert tilt axes off**, TV window in front if the TV app runs on a desktop. A desktop TV is not a real TV box. Say so in the notes.
3. Give the user one test at a time with the exact pose or steps from the plan. Poses matter: "right side down" means the phone flat,
   screen up, top pointing away, then the right edge rolled down so the screen faces the user's right.
4. Interpret the numbers with `docs/RISKS.md`. Known facts:
   - Raw accel on Android is inverted by Godot. `sensor_sampler.gd` corrects it, so the overlay should show `Accel ~ 0 0 +9.8` flat.
   - The TV decides a phone is lost after 5 s of silence. A shorter Wi-Fi drop will not pause the game.
   - Latency gaps above 100 ms point to the network (risks B1, B2).
5. Write the user's results into the results table of the test (one row for each step): pass, fail, retest or n/a, plus the measured values, the run ID
   and the link to the evidence. Add a row to the Run log for the session. Update the Summary table and the list in `CLAUDE.md` (Manual tests).
   Keep first-run values when a retest follows. Never mark a step as pass on your own: write only what the user reports, and do not turn a result into a pass without a measurement.
6. Finish with a list of the tests that still need a run, and ask for `adb logcat -s godot` for any failure.
