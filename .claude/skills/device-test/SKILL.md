---
name: device-test
description: Guide an on-device test run (phone and TV) from docs/DEVICE_TEST.md and record the results. Use when the user is testing on real hardware, reports a device test result, or asks what to retest.
---

1. Read `docs/DEVICE_TEST.md`. It holds the tests and the results table.
2. Check the setup before the tests: current controller APK installed (`build-deploy`), TV and phone on the same Wi-Fi,
   **Invert tilt axes off**, TV window in front if the TV app runs on a desktop. A desktop TV is not a real TV box. Say so in the notes.
3. Give the user one test at a time with the exact pose or steps from the plan. Poses matter: "right side down" means the phone flat,
   screen up, top pointing away, then the right edge rolled down so the screen faces the user's right.
4. Interpret the numbers with `docs/RISKS.md`. Known facts:
   - Raw accel on Android is inverted by Godot. `sensor_sampler.gd` corrects it, so the overlay should show `Accel ~ 0 0 +9.8` flat.
   - The TV decides a phone is lost after 5 s of silence. A shorter Wi-Fi drop will not pause the game.
   - A pointer test hit counts only within 90 px of the ring. Recenter first.
   - Latency gaps above 100 ms point to the network (risks B1, B2).
5. Write the user's results into the table: pass, fail, retest or n/a, plus the measured values and the setup. Keep first-run values
   when a retest follows. Do not turn a result into a pass without a measurement.
6. Finish with a list of the tests that still need a run, and ask for `adb logcat -s godot` for any failure.
