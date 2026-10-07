# Export steps

This document uses ASD-STE100 style. It shows how to make two Android apps from one project:

| Preset | Feature tag | Package ID | Runs on |
|--------|-------------|------------|---------|
| `tv` | `tv` | `com.example.remoteplay.tv` | Android TV or streaming box |
| `controller` | `controller` | `com.example.remoteplay.controller` | Android phone |

You can change the package IDs in `export_presets.cfg` (`package/unique_name`).
The two IDs are different, so you can install both apps on one device.

## 1. Install the tools (one time)

1. Install **Godot 4.7.x** (standard build, not .NET).
2. Install **JDK 17** or newer (the build was checked with JDK 21).
3. Install the **Android SDK**. The easy way is Android Studio. You need these SDK packages:
   platform-tools, build-tools 36.1.0 and platform android-36 (the versions in the 4.7 build template,
   `android/build/config.gradle`). The Gradle build does not need the NDK or CMake.
4. In Godot open **Editor > Editor Settings > Export > Android**.
   Set `Java SDK Path` and `Android SDK Path`.
5. Open **Editor > Manage Export Templates** and install the templates for your Godot version.
6. Make a debug keystore, if you do not have one:
   ```sh
   keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
     -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" \
     -validity 9999 -storetype pkcs12
   ```
   Set the path in **Editor Settings > Export > Android > Debug Keystore**
   (user `androiddebugkey`, password `android`).

## 2. Install the Android build template (one time per clone)

The presets use the Gradle build. The Gradle build is necessary for Android TV,
because Godot adds the `LEANBACK_LAUNCHER` category only with Gradle.

1. Open the project in the Godot editor.
2. Select **Project > Install Android Build Template**.
   On the command line, `godot --headless --install-android-build-template --export-debug "controller" build/remote-play-controller.apk`
   installs the template and exports once. Run the patch script after it, then export again.
3. Close the editor dialog. Then run this command in the project folder:
   ```sh
   tools/patch_android_manifest.sh
   ```
   The script does these things (you can run it again without harm):
   - copies `assets/icons/banner.png` (320 x 180) to `android/build/res/drawable-xhdpi/banner.png`;
   - adds `android:banner="@drawable/banner"` to the `<application>` tag in `android/build/src/main/AndroidManifest.xml`;
   - adds `uses-feature` lines for leanback, touchscreen, gyroscope and accelerometer,
     all with `required="false"`;
   - installs the **QR scanner plugin**: it copies `android/plugin/QrScannerPlugin.java` to
     `android/build/src/main/java/com/example/remoteplay/`, adds the Gradle dependency
     `com.google.android.gms:play-services-code-scanner:16.1.0`, and adds the plugin entry
     (`org.godotengine.plugin.v2.QrScanner`) to the manifest.

The TV launcher shows an app only when the app has a banner and the leanback category.
The category comes from the preset option `package/show_in_android_tv` (set to `true` in the `tv` preset).

### QR scanner plugin

The controller app scans the QR code on the TV screen with the Google code scanner (ML Kit).

- The scanner has its own screen. The app does **not** need the camera permission.
- The phone needs **Google Play services**. A phone without them shows "QR scan failed" and you use the list or the room code.
- The first scan can take a few seconds, because Play services can download the scanner module.
  The manifest entry `com.google.mlkit.vision.DEPENDENCIES = barcode_ui` asks Play services to download it at install time.
- The first build needs internet access for Gradle (to get the dependency from Google Maven).
- GDScript side: `scripts/net/qr_scanner.gd`. Without the plugin (PC, or a build where you skipped the patch script)
  the button on the connect screen is **Paste TV link**. It reads `ws://IP:47801/ROOM` from the clipboard.

## 3. Export

In the editor: **Project > Export**. Select a preset. Select **Export Project**.
Turn on **Export With Debug** for test builds.

On the command line (use the same Godot version):

```sh
mkdir -p build
godot --headless --path . --export-debug "tv"         build/remote-play-tv.apk
godot --headless --path . --export-debug "controller" build/remote-play-controller.apk
```

For a release build, set a release keystore in the preset (`keystore/release*`) and use `--export-release`.

## 4. Check the result

```sh
aapt dump badging build/remote-play-tv.apk | grep -E "banner|package:"
aapt dump xmltree build/remote-play-tv.apk AndroidManifest.xml | grep -E "LEANBACK_LAUNCHER|QrScanner"
```

You must see a `banner` entry, `android.intent.category.LEANBACK_LAUNCHER` and `org.godotengine.plugin.v2.QrScanner`.
(Godot 4.7 puts the launcher categories on an `activity-alias`, so `aapt dump badging` does not show a
`leanback-launchable-activity` line.)
If you do not see them, run `tools/patch_android_manifest.sh` again and export again.

## 5. Install on a real Android TV or streaming box

1. On the TV: **Settings > Device Preferences > About**. Select **Build** 7 times to enable developer options.
2. Go to **Settings > Device Preferences > Developer options**. Turn on **USB debugging** (Fire TV: **ADB debugging**).
   On Android 11 and later, turn on **Wireless debugging** if it is available. Fire TV also has **Apps from Unknown Sources**.
3. Find the IP address of the TV: **Settings > Network**.
4. On your computer (same network):
   ```sh
   adb connect 192.168.1.50:5555
   adb install -r build/remote-play-tv.apk
   ```
   The TV may ask you to allow the computer. Select **Always allow**.
5. Start the app. Use the **Apps** row on the home screen, or run:
   ```sh
   adb shell monkey -p com.example.remoteplay.tv -c android.intent.category.LEANBACK_LAUNCHER 1
   ```
6. Read the log:
   ```sh
   adb logcat -s godot
   ```

For the phone: connect it with USB (or Wireless debugging), then `adb install -r build/remote-play-controller.apk`.
Or copy the APK to the phone and open it (allow installs from this source).

## 6. Run a test session

1. Connect the TV and the phone to the **same Wi-Fi network** (best: 5 GHz).
2. Start the TV app. After the logo it shows the **Connect controllers** screen with the room code and the QR code.
3. Start the controller app. Tap **Scan the QR code on the TV** and scan the code. (Or tap the TV in the list, or type the room code.)
4. On the TV, press **Continue**. Press the Menu key (or open **Settings**, the gear, and switch **Debug overlay** on) to see the latency numbers.
5. Select **Tilt Maze**. Hold the phone flat during the countdown. Tilt to roll the ball.
   If the ball rolls the wrong way, select **Invert tilt axes** on the Settings screen.

## Desktop tests (no Android)

```sh
godot --path . -- --role=tv                          # TV window (1280x720)
godot --path . -- --role=controller --auto-join      # phone window, joins the first TV found
```

Keyboard on the TV window: arrow keys move, Enter selects, Esc goes back, F3 toggles the overlay.
The phone window has no sensors. The mouse position simulates the tilt and the mouse movement simulates the yaw.

## Problems

| Symptom | Likely cause and action |
|---------|-------------------------|
| App is not in the TV home row | Banner or leanback category is missing. Run the patch script, export again, check with `aapt`. |
| "Scan QR" button says **Paste TV link** | The plugin is not in the build. Run the patch script and export again. |
| "QR scan failed" | Google Play services are missing or old, or the scanner module is still downloading. Try again, or use the list or the room code. |
| Phone does not find the TV | Wi-Fi guest network or "AP isolation" blocks broadcast. Type the room code (it needs the beacon) or the TV IP. |
| Phone shows "Cannot reach the TV" | Different subnet, VPN on the phone, or a firewall. Use the TV IP from the TV screen. |
| Tilt direction is wrong | Use the **Invert tilt axes** switch on the TV Settings screen. Report the raw values from the overlay. |
| Phone starts in landscape, then turns | Expected. The app sets portrait at start. See `docs/RISKS.md`. |
