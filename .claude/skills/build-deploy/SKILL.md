---
name: build-deploy
description: Set up the machine, build the Android APKs, and install them on a connected phone or TV. Use for any build, export, install or adb problem.
---

Commands (macOS):
- First time: `tools/setup.sh` (JDK 17 path, Android build template, manifest patch). Safe to repeat.
- Run on the desktop: `tools/build.sh run-tv` and `tools/build.sh run-controller`.
- Build both APKs: `tools/build.sh apk` (output in `build/`).
- Deploy to a device: `tools/deploy.sh controller` or `tools/deploy.sh tv` (add `-s <serial>` when several devices are attached,
  `--no-build` to reuse the APK). For a TV: `adb connect <ip>:5555` first.

Known problems:
- **Gradle fails with a TLS error or a Java error:** the JDK is not 17. JDK 26 does not work. Use `openjdk@17` from Homebrew.
- **`/usr/local/bin/godot` gives "exec format error":** it is a Linux binary. Use `/Applications/Godot.app/Contents/MacOS/Godot` (the scripts do).
- **"Not found: AndroidManifest.xml":** the Godot 4.7 template keeps it in `android/build/src/main/`. `tools/setup.sh` handles that.
- **"Paste TV link" instead of "Scan the QR code":** the plugin is not in the build. Run `tools/setup.sh`, then export again.
- **"No device connected":** check USB debugging and `adb devices`. A new adb daemon may need a moment.
- After changing `android/plugin/` or the manifest patch, run `tools/setup.sh` again before exporting.

For this repo, `gh` must use the GitHub account `alonzo86`. Check `gh auth status` before any `gh` command.
