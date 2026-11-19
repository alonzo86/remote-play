# Export steps

This document uses ASD-STE100 style. It shows how to make two Android apps from one project:

| Preset | Feature tag | Package ID | Runs on |
|--------|-------------|------------|---------|
| `tv` | `tv` | `io.github.alonzo86.sababi.tv` | Android TV or streaming box |
| `controller` | `controller` | `io.github.alonzo86.sababi.controller` | Android phone |

You can change the package IDs in `export_presets.cfg` (`package/unique_name`).
The two IDs are different, so you can install both apps on one device.

## 1. Install the tools (one time)

1. Install **Godot 4.7.x** (standard build, not .NET).
2. Install **JDK 17** or newer (the build was checked with JDK 21).
3. Install the **Android SDK**. The easy way is Android Studio. You need these SDK packages:
   platform-tools, build-tools 36.1.0 and platform android-36 (the versions in the 4.7 build template,
   `android/build/config.gradle`). The Gradle build does not need the NDK or CMake. (CI has no APK job: the job
   `build-android` was removed on 2026-10-31, issue #286, because it exported nothing. The manifest patch is tested by
   `tests/ci_scripts.sh`. When an APK job is added, use these versions.)
   **Android levels (issue #389).** All four presets set `gradle_build/min_sdk="24"` (Android 7.0) and
   `gradle_build/target_sdk="36"` (Android 16). These are the defaults of the 4.7.2 template
   (`android/build/config.gradle`: `minSdk 24`, `targetSdk 36`, `compileSdk 36`), written into the presets so a template
   update cannot change them silently. Read from the template source, and confirmed in a dry run of 2026-11-07 (debug APKs and
   release AABs built in a cloud container with a throwaway keystore; `aapt2 dump badging` of both APKs and `aapt2 dump
   xmltree` of the manifests of both AABs: min 24, target 36, compile 36). **Owner decision, 2026-11-08 (issue #389):** keep
   target 36; the owner checked that 36 meets Google Play's current target-API rule (the rule changes: read it again before
   each upload on the Play Console help page). Check the built file with
   `aapt dump badging build/sababi-tv.apk | grep -E "sdkVersion|targetSdkVersion"` (expect 24 and 36). Whether API 24 covers
   the oldest Android TV box the owner wants to support is the owner's decision (min 24 stays). The Android 13 monochrome launcher icon
   (`adaptive_monochrome`) is not set: **owner decision, 2026-11-08: skip it.**
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
2. Select **Project > Install Android Build Template**. It makes `android/build`, the project of the `controller` preset. The `tv` preset uses its own project, `android-tv/build` (`gradle_build/gradle_build_directory="android-tv"`), so that the TV app has no Google code scanner and no ML Kit. `tools/setup.sh` installs both. By hand: copy `android/build` to `android-tv/build`, add `android-tv/.build_version` with the same version, and run the patch script in step 3.
   On the command line, `godot --headless --install-android-build-template --export-debug "controller" build/sababi-controller.apk`
   installs the template and exports once. Run the patch script after it, then export again.
The avatar sheet `assets/avatars/avatars.png` (FD-22) is an image resource, so it is in the export of both apps with the other `assets/` files; no export filter change is needed.
3. Close the editor dialog. Then run this command in the project folder:
   ```sh
   tools/patch_android_manifest.sh
   ```
   The script patches both projects (`tools/patch_android_manifest.sh controller` or `tv` for one). It does these things (you can run it again without harm):
   - copies `assets/icons/banner.png` (320 x 180, the logo; `tools/make_icons.gd` makes it and the icons from `assets/logo`) to `android/build/res/drawable-xhdpi/banner.png`;
   - adds `android:banner="@drawable/banner"` to the `<application>` tag in `android/build/src/main/AndroidManifest.xml`;
   - adds `uses-feature` lines for leanback, touchscreen, gyroscope and accelerometer, all with `required="false"` except
     **leanback in the TV app, which is `required="true"`** (owner, 2026-11-18: "Sababi: TV Games" is installed only on a TV, so
     Google Play does not offer it to phones and tablets; the phone app has no such limit; an older manifest is changed on the next run);
   - in `android/build` only (the controller): installs the **QR scanner plugin**: it copies `android/plugin/QrScannerPlugin.java` to
     `android/build/src/main/java/io/github/alonzo86/sababi/`, adds the Gradle dependency
     `com.google.android.gms:play-services-code-scanner:16.1.0`, and adds the plugin entry
     (`org.godotengine.plugin.v2.QrScanner`) to the manifest.

The TV launcher shows an app only when the app has a banner and the leanback category.
The category comes from the preset option `package/show_in_android_tv` (set to `true` in the `tv` preset).

### QR scanner plugin

The controller app scans the QR code on the TV screen. Android uses the Google code scanner (ML Kit); the iPhone uses its own plugin (section *Controller on an iPhone*).

**Android.**

- The scanner has its own screen. The app does **not** need the camera permission.
- The phone needs **Google Play services**. A phone without them shows "QR scan failed" and you type the room code.
- The first scan can take a few seconds, because Play services can download the scanner module.
  The manifest entry `com.google.mlkit.vision.DEPENDENCIES = barcode_ui` asks Play services to download it at install time.
- The first build needs internet access for Gradle (to get the dependency from Google Maven).
- GDScript side: `scripts/net/qr_scanner.gd`. Without the plugin (PC, or a build where you skipped the patch script)
  the connect screen has no scan button: the player types the room code (issue #115).

## 3. Export

In the editor: **Project > Export**. Select a preset. Select **Export Project**.
Turn on **Export With Debug** for test builds.

On the command line (use the same Godot version):

```sh
mkdir -p build
godot --headless --path . --export-debug "tv"         build/sababi-tv.apk
godot --headless --path . --export-debug "controller" build/sababi-controller.apk
```

For a release build for the stores, see "Release to the stores" below (the presets build APKs for testing only).

## 4. Check the result

```sh
aapt dump badging build/sababi-tv.apk | grep -E "banner|package:"
aapt dump xmltree build/sababi-tv.apk AndroidManifest.xml | grep -E "LEANBACK_LAUNCHER|QrScanner"
aapt dump xmltree build/sababi-controller.apk AndroidManifest.xml | grep -E "QrScanner"
aapt dump xmltree build/sababi-tv.apk AndroidManifest.xml | grep -A2 "android.software.leanback"
aapt dump xmltree build/sababi-controller.apk AndroidManifest.xml | grep -A2 "android.software.leanback"
```

The TV apk must show a `banner` entry and `android.intent.category.LEANBACK_LAUNCHER`, and **no** `QrScanner` (the TV app has no scanner). The controller apk must show `org.godotengine.plugin.v2.QrScanner`. The `android.software.leanback` line must show `required` true in the TV apk and false in the controller apk (the TV app is installed only on a TV, owner, 2026-11-18). A bundle (`.aab`) is checked the same way with `aapt2 dump xmltree --file AndroidManifest.xml`.
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
   adb install -r build/sababi-tv.apk
   ```
   The TV may ask you to allow the computer. Select **Always allow**.
5. Start the app. Use the **Apps** row on the home screen, or run:
   ```sh
   adb shell monkey -p io.github.alonzo86.sababi.tv -c android.intent.category.LEANBACK_LAUNCHER 1
   ```
6. Read the log:
   ```sh
   adb logcat -s godot
   ```

For the phone: connect it with USB (or Wireless debugging), then `adb install -r build/sababi-controller.apk`.
Or copy the APK to the phone and open it (allow installs from this source).

## 6. Run a test session

1. Connect the TV and the phone to the **same Wi-Fi network** (best: 5 GHz).
2. Start the TV app. After the logo it shows the Connect screen with the room code and the QR code.
3. Start the controller app. Tap **SCAN QR CODE** and scan the code. (Or type the room code of the TV in the field and tap **JOIN**.) With the setting **APPROVE NEW PLAYERS** ON (the default) the TV shows a card: press OK on ALLOW with the remote to let the phone in.
4. On the TV, press OK on the Connect screen ("PRESS OK TO CONTINUE"). Press the Menu key (or open **Settings**, the OPTIONS button, and switch **Debug overlay** on) to see the latency numbers. This works in a debug build only (`tools/build.sh apk`, the editor, a desktop run): a release build (`tools/build.sh aab`) has no overlay, no Menu or F3 key for it and no Settings row (owner, 2026-11-18).
5. Select **Treasure Maze**. Hold the phone flat during the countdown. Tilt to roll the ball.
   If the ball rolls the wrong way, select **INVERT AXES** on the Settings screen.

## Controller on an iPhone (unverified)

Only the controller runs on iOS. The TV app stays on Android TV. Status: written, never run (needs Manual test 13).

1. Install Xcode, open it once, then run `sudo xcode-select -s /Applications/Xcode.app`.
2. Sign in with your Apple ID under Xcode > Settings > Accounts. Find the 10-character **Team ID** in Xcode, Signing & Capabilities. It is not the e-mail address.
3. Install the Godot 4.7.2 export templates (Editor > Manage Export Templates). They include iOS.
4. Connect the iPhone by cable. Unlock it, tap Trust, and turn on Developer Mode (Settings > Privacy & Security).
5. Run `IOS_TEAM_ID=<team id> tools/deploy-ios.sh`. It exports the preset `controller-ios`, builds with `xcodebuild`, installs and launches the app.
   The app is named "Sababi: Remote" on the home screen, as on Android (FD-27): the script sets it with `INFOPLIST_KEY_CFBundleDisplayName`, because Godot writes the project name. An App Store build needs the same setting.
   The script first runs `tools/build_ios_plugin.sh` (the QR scanner plugin, rebuilt only when its source is newer) and stops if `ios/plugins/` is missing. After the export it checks that Godot wrote a Hebrew `InfoPlist.strings` with the camera text (`privacy/camera_usage_description_localized`); if it did not, it stops. In that case add `he.lproj/InfoPlist.strings` with `"NSCameraUsageDescription" = "<the Hebrew text of the preset>";` to the Xcode project by hand (the fallback decided by the owner on 2026-11-01).
   `--no-build` reuses the last build. `-d <id>` picks a phone. `IOS_BUNDLE_ID=` changes the bundle ID when a free account says it is taken.
6. On a free account, trust the developer on the phone (Settings > General > VPN & Device Management). The app stops working after 7 days: deploy again.

### The iPhone QR scanner plugin (issue #299)

Source: `ios/plugin/qr_scanner/` (Objective-C++ plus one Swift file on Apple VisionKit, our own code; no third-party code; VisionKit's scanner has no Objective-C interface, so the scan view is Swift: `tools/build_ios_plugin.sh` compiles it with `swiftc` and the `.gdip` adds the Swift library path). Build: `tools/build_ios_plugin.sh` on a Mac. It clones the Godot source at the tag of the export templates (`GODOT_TAG`, default `4.7.2-stable`, or use `GODOT_SRC`), lets scons write the engine headers once, compiles a device slice and a simulator slice, and writes `ios/plugins/qr_scanner.xcframework` and `ios/plugins/QrScanner.gdip`. These two are **not committed** (`.gitignore`); the script rebuilds only when the source is newer (`--force` rebuilds). The plugin registers the singleton `QrScanner` with `scan(hint, cancel)` and the signals `scanned(text)` and `failed(reason)` (reasons: `cancelled`, `camera_denied`, `no_camera`, `error`), as `scripts/net/qr_scanner.gd` expects. The camera text is not in the `.gdip`: it comes from the preset.

**Status: written on Linux without Xcode and without an iPhone. It was never built and never run.** The first Mac run may find compile errors or an engine API that differs from 4.7.2 (risk R2 of `docs/IOS_SCANNER_PLAN.md`). Manual test 33 step 1a is the first check; nothing is marked as built before it.

Differences from Android:

- QR scan: the iPhone app has its own scanner plugin (`ios/plugin/qr_scanner`, built by `tools/build_ios_plugin.sh`, issue #299; REQ-FL-58, 88 to 92). It needs the **camera permission**: iOS asks the first time the player taps SCAN QR CODE. If the player taps Don't Allow, the scan shows a message and the player types the room code, or switches the camera on in Settings > Sababi. The text of the question is in the preset (`privacy/camera_usage_description`, English, and `privacy/camera_usage_description_localized`, Hebrew; the Hebrew text needs a native reader). Without the plugin folder the build has no scan button. **Status: the plugin source and the build script are written on Linux and were never built or run (no Xcode, no iPhone); Manual test 33 is the check.** The plugin binaries are built on the Mac and are not committed (`.gitignore`). The minimum iOS version is 16 (decision of the owner, 2026-11-02; it was 15). Phones older than the A12 chip (iPhone 8 and X) have no scan button and type the room code.
- iOS asks for the Local Network permission the first time the phone looks for the TV (the text is in the `export_presets.cfg` of the controller: "Sababi uses the room code to find your TV on your Wi-Fi and connect to it." The phone builds the TV address from the room code and tries the addresses of the Wi-Fi network). The text is in English only: the Godot iOS preset has no localized option for this key, and a Hebrew `InfoPlist.strings` would have to be added to the Xcode project by hand (not done). If the player taps Don't Allow, the iPhone cannot join: Settings > Sababi > Local Network switches it on.
- The sensor axis fix in `scripts/input/sensor_sampler.gd` was measured on Android only. Check the directions again (Manual test 13, step 4b: the ball rolls to the lowered side).

## Release to the stores (not done yet; nothing here is built or uploaded without the owner's go-ahead)

State of the presets: `tv` and `controller` export an **APK** for testing (`gradle_build/export_format=0`, `build/*.apk`). Google Play needs an **Android App Bundle** for a new app, so there are two more presets, `tv-release` and `controller-release` (`export_format=1`, `build/sababi-tv.aab` and `build/sababi-controller.aab`, `package/signed=true`, not runnable). They are copies of their APK twins (same package, name, version, icons, architectures, include and exclude filters, Gradle directory; `tests/design_tokens.gd` checks it) and have **no keystore, user or password** in the file. The owner's store decisions (the upload keystore, Play App Signing, the iOS Team ID, bundle id and minimum iOS version) are open in issue #289; no real release bundle is built or uploaded without the owner's go-ahead (a dry run with a throwaway keystore outside the repository, as below, is allowed and uploads nothing).

Build the bundles (only on the owner's go-ahead, with the three variables of "Keys" set; the script stops when one is missing):

```sh
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/sababi-upload.keystore \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=sababi-upload \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=... \
tools/build.sh aab        # exports tv-release and controller-release with --export-release
```

Run `tools/patch_android_manifest.sh` first, as for the APKs (section 3). Dry run of 2026-11-07 (issue #289, a throwaway upload keystore outside the repository, nothing uploaded): `tools/build.sh apk` took
2 min 19 s (it also filled the Gradle cache) and `tools/build.sh aab` 55 s; both release bundles pass `jarsigner -verify` and
`bundletool validate`; sizes: TV bundle 54.3 MB, controller bundle 30.2 MB (the base limit is 200 MB); the manifests have the
permissions of section 5 of the privacy notice and nothing more (TV: internet, network state, wifi state, wake lock; controller: the
same and vibrate); the TV app has the banner and `LEANBACK_LAUNCHER` and no scanner, the controller app has the scanner plugin and
ML Kit; ABIs: arm64-v8a for both, armeabi-v7a for the TV; the arm64 libraries have a 16 KB LOAD alignment (0x4000), the armeabi-v7a
libraries 0x1000 (Google's 16 KB rule is for 64-bit libraries, not verified here). Still not done: the real upload keystore, Play
App Signing, the version name (`tools/set_version.sh 1.0.0`) and a run on a real device.

### The version (one place for each app)

The version is written in five presets of `export_presets.cfg`: the TV app has `tv` and `tv-release` (4 lines), the controller app has `controller`, `controller-release` and `controller-ios` (6 lines). The two apps are two Google Play listings, so each can have its own name and code (owner, 2026-11-19). Do not edit the lines by hand:

```sh
tools/set_version.sh 1.0.0 2              # both apps: name x.y.z and one whole number, written to all ten lines
tools/set_version.sh 1.0.1 3 tv           # only the TV app (4 lines)
tools/set_version.sh 1.1.0 5 controller   # only the controller app (6 lines, the iOS build number too)
tools/set_version.sh --check              # exits 1 when the presets of ONE app differ; tests/ci_scripts.sh runs it in the lint job
```

- The **code** (Android `version/code`, iOS build number) must be higher than the one of the last upload. Google Play rejects a repeated or lower code, and App Store Connect rejects a repeated build number for a version. The TV and the controller are two listings, and Google Play counts the code of each app on its own (owner, 2026-11-19): the code of an app only goes up (+1 for each upload of that app, also for a rejected build that reached the store). Raise only the app that you upload again (`tools/set_version.sh <name> <code> tv` or `controller`); the other app keeps its number.
- The **name** is what people see. Raise it for a change that people notice.
- The protocol `VERSION` (`scripts/core/protocol.gd`, `docs/PROTOCOL.md`) is a separate number. It changes only when the wire format changes (the `change-protocol` skill) and has no link to the app version. A TV and a phone of different app versions work together as long as the protocol version is the same.

### Keys (never commit them, never paste them in an issue)

- The **upload keystore** (Android) is made once by the owner (`keytool -genkeypair -v -keystore sababi-upload.keystore -alias sababi-upload -keyalg RSA -keysize 2048 -validity 10000`) and lives outside the repository (a password manager or an encrypted backup, with its two passwords). `.gitignore` now ignores `*.keystore`, `*.jks` and `*.p12`; `export_credentials.cfg` was already ignored. Losing the upload key is recoverable only through Google's key reset, so keep two backups.
- Use **Play App Signing** (the Play Console default for a new app): Google keeps the key that signs the apps for people, and you sign the bundle with the upload key only.
- The presets (also the two release presets, whose `keystore/release*` keys stay empty) have `package/signed=true` and no keystore path on purpose: Godot reads the release keystore from the editor settings or from the environment of the export (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`). On a fresh machine set them first, or the release export fails (it must not fall back to the debug key for a store build).
- iOS: signing uses the Apple account of the owner in Xcode. `application/app_store_team_id="0000000000"` in the preset is a placeholder that Godot needs; the real Team ID comes from `IOS_TEAM_ID` (`tools/deploy-ios.sh`) or from the Xcode project. `application/min_ios_version="16.0"` is the decision of the owner (2026-11-02), needed by the iPhone scanner.

### Checklist for a store release (owner decides each step)

1. The owner agrees to the release and to its version name.
2. `tools/set_version.sh <name> <code> [tv|controller]` (no app: both), then `tools/set_version.sh --check`.
3. The privacy notice and the store forms are final (issues #36 and #37; the privacy policy URL of the forms is `https://alonzo86.github.io/remote-play/privacy.html`, live since 2026-11-18: the repository is public and Pages is on): the Play **Data safety** form (the controller uses the Google code scanner, the TV does not, see `tools/patch_android_manifest.sh`), the App Store privacy answers (Data Not Collected; the iPhone scanner uses the camera on the device only), the age rating (owner decision of 2026-11-08, issue #383: Google Play target audience **6-8, 9-12, 13-15, 16-17 and 18 and over** since 2026-11-12, so the Families policy applies and the whole app is made compliant; Apple age rating **9+**, not the Kids category), the Local Network text and the camera text.
4. The suites of the change and the manual tests with status `Device` that the release needs are Pass in `docs/MANUAL_TESTS.md`.
4b. The privacy notice is inside the apps: every preset has `docs/legal/privacy-notice.md` and `privacy-notice.he.md` in `include_filter`, and excludes the other folders of `docs/` by name in `exclude_filter` (not `docs/*`, which would drop the notice too; `design_tokens` fails when a new folder of `docs/` is not excluded). The website folder `site/*` is excluded too: no script loads it (issue #496; `design_tokens` checks it in every preset). A change of the notice needs a new build of the apps; the website changes at once.
5. Android: export the bundles with `tools/build.sh aab`, check them like in section 4 (the TV has no `QrScanner`, the controller has it) and upload both to the internal testing track first.
6. iOS: export the Xcode project (`controller-ios`), open it in Xcode, set the team, Product > Archive, Distribute App > App Store Connect, then test in TestFlight. (Not verified: no Mac with Xcode was used for this.)
7. Only after the owner says so: promote to production and push the tag `v<name>`. No agent pushes a tag or publishes a store build on its own.

## Desktop tests (no Android)

```sh
godot --path . -- --role=tv                          # TV window (1280x720)
godot --path . -- --role=controller --join=127.0.0.1  # phone window, joins the TV at that address (the TV must be a debug build: it accepts a join with no room code only then; press Enter on the TV window to ALLOW the phone, or turn APPROVE NEW PLAYERS off in Settings)
```

Keyboard on the TV window: arrow keys move, Enter selects, Esc goes back, F3 toggles the overlay (a desktop run from the editor or a debug build only).
The phone window has no sensors. The mouse position simulates the tilt and the mouse movement simulates the yaw.

## Problems

| Symptom | Likely cause and action |
|---------|-------------------------|
| App is not in the TV home row | Banner or leanback category is missing. Run the patch script, export again, check with `aapt`. |
| No "Scan QR code" button on Android | The plugin is not in the build. Run the patch script and export again. |
| "QR scan failed" | Google Play services are missing or old, or the scanner module is still downloading. Try again, or type the room code. |
| Phone says "CAN'T FIND THIS ROOM" | The phone and the TV do not share the first two numbers of their addresses (guest Wi-Fi, a second network, a VPN on the phone, mobile data only), or the code is wrong. Scan the QR code on the TV: it holds the full address. |
| Phone shows "Cannot reach the TV" | Different subnet, VPN on the phone, or a firewall. Use the TV IP from the TV screen. |
| Tilt direction is wrong | Use the **INVERT AXES** row on the TV Settings screen. Report the raw values from the overlay. |
| Phone starts in landscape, then turns | Expected. The app sets portrait at start. See `docs/RISKS.md`. |
