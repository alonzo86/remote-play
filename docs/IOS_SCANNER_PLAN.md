# iPhone QR scanner plan (issue #299)

Status: **plan, not built. No code, no preset change and no legal text is changed by this file.** Written on 2026-11-01 by the roles `product-engineer` and `software-architect`. Alon decided in issue #299: "add an iPhone scanner". The owner approves this plan before phase 1 starts.
Style: ASD-STE100 Simplified Technical English, like the other plans. Requirement IDs in this plan are proposed; check the highest free ID in `docs/TV_FLOW.md` when the first phase starts (REQ-FL-87 is the highest on 2026-11-01).

## 1. Why, and the state today

The iPhone controller joins only with the typed room code (REQ-FL-58). The Android phone has a "SCAN QR CODE" button that opens the Google code scanner (issue #36, REQ-FL-83a). Joining by scan is the main way to join (issue #241), so the iPhone player gets the slower way. The iPhone also cannot scan a shared player profile (`profiles.scan_profile`, REQ-FL-76/77): it pastes a code.

Facts that this plan starts from (checked in the repository on 2026-11-01):

| Place | What it says today |
|-------|--------------------|
| `export_presets.cfg:173` (`controller-ios`) | `privacy/camera_usage_description="Sababi scans the QR code on the TV."` The line is already there. `tests/design_tokens.gd:414` checks that the text is not empty. |
| `scripts/ui/controller_connect.gd:25-28` | `shows_scan_button(os_name)` returns false for "iOS". |
| `scripts/net/qr_scanner.gd` | One GDScript entry point. It looks for the engine singleton "QrScanner" (the Android plugin). Signals `scanned(text)` and `failed(reason)`; reason "cancelled" is silent (`_on_qr_failed`, issue #43). `acquire_wifi_locks()` calls `acquireWifiLocks` on the plugin. |
| `scripts/ui/controller_profiles.gd:55` | Shows "SCAN A PROFILE" when `is_available()`. |
| `docs/legal/privacy-notice.md` (and `.he.md`) | Section 4: the scan is Android only. Section 5: iPhone has "local network" only. Section 6: the only third-party component is Google Play services. |
| `docs/EXPORT.md:65, 149` | "The app does not need the camera permission" (Android text); "No QR scan: ... the iPhone joins by the typed room code" (iOS text). |
| `docs/THIRD_PARTY.md` | Rows for the Google code scanner (Android only). Nothing for iOS. |
| `tools/deploy-ios.sh` | Exports the preset `controller-ios` as an Xcode project, patches Info.plist, signs and installs with `xcodebuild`. It knows no plugin. |
| Manual test 13 | The iPhone app has never been run on a device (status: written, never run). |

Consequence: the camera purpose string in the preset is true only after this plan is built. Until then no iOS build goes to a store (nothing is uploaded without the owner's go-ahead, issue #289), so the text does not say something false to a user. Phase 0 (section 6) keeps it that way and makes the documents say the same.

## 2. Requirements (proposed)

All new requirements go in `docs/TV_FLOW.md` (the phone connect screen) and are copied to `docs/REQUIREMENTS.md` where that file lists them. `Status: Device` means: not done until the matching manual test is Pass (CLAUDE.md). REQ-FL-58 is **changed**, not removed.

- REQ-FL-58 (changed): On an iPhone or iPad the Connect screen shows the "SCAN QR CODE" button when the build has the iOS scanner plugin (`QrScanner.is_available()`), like Android. A build without the plugin (a Mac editor, a simulator, a build that skipped the plugin) shows no button and the player types the room code. The decision does not depend on the OS name any more: `shows_scan_button()` is removed and the screen asks `is_available()` only.
- REQ-FL-88: The iOS scan opens a full screen camera view over the app with a live picture, a short help line (`connect.scan_hint`) and a CANCEL button (`connect.scan_cancel`) at least 96 px high at the bottom. The view is portrait only, like the app. The camera is not on before the view opens and is off when the view closes (the scan, CANCEL, the app goes to the background, a phone call). Status: Device (Manual test 33).
- REQ-FL-89: A good scan closes the view at once and returns the text of the first QR code seen. Only QR codes are read (no other bar code type). The result goes to the same handlers as on Android: a TV link joins (`Protocol.parse_pair_url`), a player code opens the profile import, another text shows `connect.not_sababi_code`. The phone buzzes once with the normal haptics when the code is read (iOS only, if haptics are on). Status: Device.
- REQ-FL-90: CANCEL, a swipe down on the view and the app going to the background close the view and report `failed("cancelled")`. The Connect screen then shows no message and stays as it was, with the typed room code field still usable. This matches the Android scanner, where Back is a cancel (issue #43). Status: Device.
- REQ-FL-91: The first scan asks iOS for the camera permission. When the player taps "Don't Allow" (or the camera is off in Settings, or a school profile blocks it), the scan reports `failed("camera_denied")` and the Connect screen shows `connect.camera_denied` (it says how to turn the camera on, and that the room code works). The player can still join with the typed room code. A phone with no camera reports `failed("no_camera")` and shows `connect.no_camera`. No other reason shows the raw word to a child: every reason from the plugin maps to a key (the Android path keeps its text `connect.qr_failed`). Status: Device.
- REQ-FL-92: The picture of the camera is not saved, not sent and not kept after the view closes. The plugin reads the text of the code in memory only. The iPhone app asks for the camera permission and for nothing else new (no photo library, no microphone). Status: Device (the privacy notice depends on it; Manual test 33 step 6).
- REQ-FL-83 (changed, one phrase): "the scan button (only when the build has the scanner ...)" stays true; the sentence about iOS in REQ-FL-58 is the only iOS change.
- REQ-FL-76 / REQ-FL-77: no text change. "Where the phone has a scanner" now also covers the iPhone, and the paste button stays as the second way.
- REQ-P6 / REQ-P5: the plugin is our own code (no third-party resource), so REQ-P6 (allowed files) lists the folder `ios/plugin/` as source only. If the owner chooses a third-party plugin (section 4, option B), REQ-P6 gets the line that CLAUDE.md asks for.

How this matches the Android scanner:

| Behavior | Android (Google code scanner) | iPhone (this plan) |
|----------|-------------------------------|--------------------|
| Button, size, place | REQ-FL-83a | same button, same code (no OS check) |
| Result | text of the code | text of the code |
| Cancel | Back key: reason "cancelled", silent | CANCEL, swipe down, background: reason "cancelled", silent |
| Failure | `connect.qr_failed` with the reason | `connect.qr_failed` for an unknown error; own texts for denied and no camera |
| Room code typed | stays | stays |
| Permission | none (own screen of Play services) | camera permission, asked once by iOS |
| Needs a service | Google Play services | none (Apple's system framework) |
| Data to a third party | technical data to Google | none |

## 3. Technical approach

### 3.1 Choice: a small own iOS plugin on Apple AVFoundation

Godot 4.7 has no QR scanner in the engine. A Godot iOS plugin is a native static library (an xcframework) with a `.gdip` file; an Objective-C++ class registers itself as an engine singleton and emits signals. This is the same shape as the Android plugin `QrScanner` (`android/plugin/QrScannerPlugin.java`), so `scripts/net/qr_scanner.gd` stays the single entry point: it already asks `Engine.has_singleton("QrScanner")`. The name "QrScanner" and the two signals are the same on both platforms.

Why own code:
- AVFoundation (`AVCaptureSession` + `AVCaptureMetadataOutput` with `AVMetadataObjectTypeQRCode`) is part of iOS. It reads QR codes on the device, with no model download and no network. It is not a "library that another maker owns" in the sense of CLAUDE.md: a system framework of the operating system needs no row in `docs/THIRD_PARTY.md`, no license file and no About notice. The plugin is about 250 lines.
- No data goes to a third party, so Data Not Collected in App Privacy stays true and the privacy notice needs no new third party.
- No new risk for the license review.

### 3.2 GDScript API (single entry point)

`scripts/net/qr_scanner.gd` keeps its public API: `is_available()`, `scan()`, signals `scanned(text)` and `failed(reason)`, `acquire_wifi_locks()`. Changes are small and are made in phase 2:

```gdscript
func scan() -> void:
	...
	if OS.get_name() == "iOS":
		# The native view cannot call Lang, so the texts are passed in, in the language of the app.
		_plugin.call("scan", Lang.t("connect.scan_hint"), Lang.t("connect.scan_cancel"))
	else:
		_plugin.call("scan")

func acquire_wifi_locks() -> void:
	# The iOS plugin has no Wi-Fi locks: call only when the plugin has the method.
	if _plugin != null and _plugin.has_method("acquireWifiLocks"):
		_plugin.call("acquireWifiLocks")
```

The second change matters: `scripts/app.gd:333` calls `acquire_wifi_locks()` on every start. Without the `has_method` check the iOS plugin would receive a call it does not have. The strings are passed from GDScript so `assets/lang/strings.csv` stays the only place of user texts (REQ-FL-63); the native code has no text of its own. The reasons that the plugin sends are a fixed list: `cancelled`, `camera_denied`, `no_camera`, `error`. `controller_connect.gd::_on_qr_failed` maps `camera_denied` and `no_camera` to their keys; the rest keeps `connect.qr_failed`.

Native side (`ios/plugin/qr_scanner/`, new folder, source only):
- `qr_scanner.h/.mm`: class `QrScanner : Object` (the Godot `Object`), methods `scan(String hint, String cancel)`, signals `scanned(String)` and `failed(String)`. Registered in `plugin_init()` with `Engine::get_singleton()->add_singleton(...)` as the Godot iOS plugin guide describes.
- `QrScanViewController` (UIKit): full screen, `AVCaptureVideoPreviewLayer`, a `UIButton` for CANCEL, the hint label. Presented over the Godot root view controller. `AVCaptureMetadataOutput` delegate returns the first QR string, stops the session and dismisses the view. Permission: `AVCaptureDevice requestAccessForMediaType:` before the session starts; denied or restricted gives `camera_denied`; no capture device gives `no_camera`.
- Portrait only (`supportedInterfaceOrientations`), RTL-safe layout (CANCEL is centered, the hint is centered, so Hebrew needs no mirror).
- `QrScanner.gdip`: name, the xcframework (debug and release), `linker_flags` for the frameworks `AVFoundation` and `UIKit`, and `[plist]` with `NSCameraUsageDescription`.

### 3.3 Build and pack with the export

- The Godot iOS plugin build needs the Godot engine headers of the same version as the export templates (4.7.2). `tools/build_ios_plugin.sh` (new, macOS only, like `tools/deploy-ios.sh`) fetches/uses a Godot source checkout at the tag of the templates, builds the headers once (`scons platform=ios target=template_debug` partial build as the plugin guide says), then runs `xcodebuild` for `ios/plugin/qr_scanner` for device and simulator slices and `xcodebuild -create-xcframework`. The output goes to `ios/plugins/qr_scanner/` (`.gdip` and the two xcframeworks).
- The binaries (the xcframeworks) are **not committed** (`.gitignore`), like `android/build`. The script is run by `tools/deploy-ios.sh` when the folder is missing (step before the export), and it is one more line in `tools/setup.sh` on a Mac. CI (CircleCI on Linux) cannot build it; CI checks only the GDScript, the docs and the preset text (section 3.5).
- Export: the Godot iOS exporter lists the plugins found in `res://ios/plugins/` as checkboxes in the preset (`plugins/QrScanner=true`). Phase 3 sets that one option in the `controller-ios` preset and nothing else. The `export_filter` and `exclude_filter` of the preset already skip `tests/*`, `tools/*`; `ios/plugin/*` (the source) is added to `exclude_filter` so the source is not packed in the pck. `tests/design_tokens.gd` is extended: the preset has the plugin option, the camera text is not empty, the TV and the Android presets have no iOS plugin.
- `tools/deploy-ios.sh` needs only the build step and a check that the plugin folder exists. The Info.plist patch for the orientation stays.
- The camera purpose string: stays in `privacy/camera_usage_description` in the preset (Godot writes `NSCameraUsageDescription` from it). The `.gdip` `[plist]` must not set it again (two sources of one text). Draft text in section 5.3.
- The TV app is Android only, so it gets nothing from this work.

### 3.4 Alternatives

| Option | What it is | Verdict |
|--------|-----------|---------|
| A. Own plugin on AVFoundation (this plan) | About 250 lines of Objective-C++, built on a Mac | **Recommended.** No license, no third party, no data to anyone. Cost: a Mac build step and Godot headers. |
| B. A community Godot iOS plugin for QR or camera | Ready code, usually MIT. Not checked: none was verified in this plan | Allowed only after `license-reviewer`: CLAUDE.md asks for a row in `docs/THIRD_PARTY.md`, the license file `assets/licenses/LICENSE-<name>.txt` packed in the `controller-ios` `include_filter` (`tests/design_tokens.gd`), an About page if the license asks for a notice (`scripts/core/about.gd` + strings rows), a line in REQ-P6 and the privacy notice if it collects data. Risk: the plugin may be for an older Godot, may not be kept up to date, may bring a camera view we cannot restyle or localize. |
| C. Google ML Kit Barcode Scanning for iOS (CocoaPods) | The iOS twin of the Android scanner | Not recommended. It sends technical data to Google like the Android one (privacy notice and App Privacy would change: "Diagnostics"), brings a Pod and an Apple privacy manifest to maintain, and Godot's Xcode project does not use CocoaPods. |
| D. Apple VisionKit `DataScannerViewController` | System scanner with its own UI, iOS 16 and later | Possible later. The preset has `min_ios_version="15.0"` (a first guess, issue #289). It needs iOS 16 and a phone with the A12 chip, and its UI cannot show our Hebrew/English texts. If the owner sets the minimum to iOS 16 it can replace the view in 3.2; the GDScript API and the signals do not change. |
| E. Scan with the Godot camera feed (`CameraServer`) and decode in GDScript | No native code | Not recommended. A QR decoder in GDScript is a new library to write or copy (license), it is slow on a phone, and the camera feed in Godot on iOS has been unreliable. |
| F. Do not add a scanner; remove the camera string | The other answer to issue #299 | Not chosen: Alon decided to add it. It stays as the fallback when phase 4 fails on a device (section 7). |

## 4. Phases (one pull request each)

0. **Align the documents and the test (no code, no new feature).** PR by `product-engineer`/`sw-developer`. Adds requirements REQ-FL-88 to 92 and the change of REQ-FL-58 with status `Planned (issue #299)`; adds Manual test 33 to `docs/MANUAL_TESTS.md` with every result "Not run" and the line in the open-tests table of CLAUDE.md (a change of CLAUDE.md: owner approves). Does **not** change the privacy notice, the store texts or the preset (owner only; drafts are in section 5). It can be merged before the plugin because the Hebrew and English notices are changed in phase 3, in the same PR that ships the scanner in a build (REQ-GM-5).
1. **Native plugin source and build script.** `ios/plugin/qr_scanner/`, `tools/build_ios_plugin.sh`, `.gitignore`, a section in `docs/EXPORT.md`. No change of the preset. Check: it compiles on a Mac with Xcode (the author cannot run it on Linux; so the PR says "not built" until a Mac run; Claude does not mark it as built). Review: `code-reviewer` reads the Objective-C++ for the life cycle (session stops, delegate clears, no retain cycle).
2. **GDScript side and tests.** `qr_scanner.gd` (iOS call with the two texts, `has_method` guard), `controller_connect.gd` (remove `shows_scan_button`, map `camera_denied`/`no_camera`), new strings (section 5.6). Tests that run headless with a fake plugin object (a script with the same signals and methods, registered with `Engine.register_singleton`): `scan()` on "iOS" passes the two texts; `cancelled` shows no message; `camera_denied` shows `connect.camera_denied`; the Connect screen has the scan button when a plugin is there, also with `os_name = "iOS"`, and has none without it; the test of `A-13-2` ("no scan button on iPhone") is changed to say "no scan button on an iPhone without the plugin". `acquire_wifi_locks()` does not fail with a plugin without the method.
3. **Export and legal (owner approves).** Preset option `plugins/QrScanner=true`, `exclude_filter` for the source, `tests/design_tokens.gd`, `tools/deploy-ios.sh` build step, and the text changes of section 5 (privacy notice English and Hebrew, `docs/EXPORT.md`, `docs/PRIVACY_NOTICE_DRAFT.md`, `docs/legal/store-listing-draft.md` if it lists permissions, About page if the owner wants it). CLAUDE.md: a change of the privacy notice or of a store text is **not** merged by an agent. The PR is left for the owner with a comment.
4. **Device test and status.** The owner runs Manual test 33 on an iPhone (needs the Mac and Xcode; test 13 steps 1a to 2d first). Claude writes the results the owner reports, never marks a step as passed (CLAUDE.md), then changes the requirement status. If a step fails, a GitHub issue is opened (CLAUDE.md, "Manual tests").

Phases 0 and 2 can go in parallel. Phase 3 needs 1 and 2.

## 5. Legal and store texts (DRAFTS, NOT APPLIED)

Privacy and store texts are owner-only. Everything in this section is a proposal for Alon to accept, change or reject. Hebrew was written by Claude and needs a native reader (one `localization` issue comment).

### 5.1 `docs/legal/privacy-notice.md`, section 4 (new bullet before "Share a profile")

> - **QR code scan (iPhone and iPad).** To scan the QR code of the TV or of a shared profile, the Controller uses the camera of your iPhone. iOS asks for your permission the first time. The camera picture is shown on the scan screen only while it is open. It stays on your phone: Sababi does not save it and does not send it to us or to anyone else. Sababi receives only the text of the code. If you tap Don't Allow, you can type the room code instead, and you can turn the camera on later in Settings > Sababi.

The Android bullet stays as it is. The heading "4. Camera, clipboard and sharing a profile" stays.

### 5.2 `docs/legal/privacy-notice.md`, sections 5 and 6

Section 5, last sentence now: "iPhone: local network (to connect to the TV on your network)." Proposed:

> iPhone: local network (to connect to the TV on your network) and camera (only to scan a QR code; you can say no and type the room code instead).

Section 6, now: "The only third-party component that touches your data on the device is Google Play services (the QR scanner, Android only)." Proposed (add one sentence):

> The only third-party component that touches your data on the device is Google Play services (the QR scanner, Android only). The QR scanner on the iPhone is part of iOS (Apple's camera framework): it adds no third-party component.

Section 3 and the data table (section 2) do not change: the app still sends nothing outside the local network. The summary line "we do not receive personal data" stays true (the picture is never sent).

### 5.3 Camera purpose string (`privacy/camera_usage_description` in `export_presets.cfg`, owner only)

Now: `Sababi scans the QR code on the TV.` Proposed (Apple wants the reason and what is done with the picture; one sentence a parent can read):

> Sababi uses the camera only to read the QR code on your TV, to join the game. The picture is not saved or sent.

The text is English only: the Godot iOS preset has no localized option (same limit as the Local Network text, `docs/EXPORT.md`). A Hebrew `InfoPlist.strings` is out of scope here. The check in `tests/design_tokens.gd` (not empty) stays; if the owner agrees it can also check that the word "QR" is in the text.

### 5.4 App Privacy answers (App Store Connect, owner fills the form)

Answer stays **Data Not Collected**. Reason to write in the form notes: the camera picture is processed on the device and is never sent off the device or kept (Apple's definition of "collect" is data sent off the device in a way that lets us or a partner keep it for longer than needed to serve the request in real time). No third-party SDK with data collection is added (the iOS plugin is own code on a system framework). The privacy manifest (`PrivacyInfo.xcprivacy`): the plugin uses no "required reason API" (no UserDefaults, no file time stamps, no disk space, no system boot time), so the plugin adds no entry; the manifest of the engine (from the Godot export) stays as it is. Check at phase 3 with `xcodebuild`'s privacy report that no new entry appears.

### 5.5 `docs/EXPORT.md` (line 65 and the iOS section)

The text on line 65 is in the section "QR scanner plugin" and speaks about Android. It is true for Android, so the sentence is only moved under a heading "Android":

> **Android.** The scanner has its own screen. The app does **not** need the camera permission. ...

New text for the iOS section (line 149 now says "No QR scan: ... the iPhone joins by the typed room code (REQ-FL-58)"). Proposed replacement:

> - QR scan: the iPhone app has its own scanner plugin (`ios/plugin/qr_scanner`, built by `tools/build_ios_plugin.sh`, issue #299). It needs the **camera permission**: iOS asks the first time the player taps SCAN QR CODE. If the player taps Don't Allow, the scan shows a message and the player types the room code, or switches the camera on in Settings > Sababi. The text of the question is in the preset (`privacy/camera_usage_description`), English only. Without the plugin folder the build has no scan button.

And line 192 (release checklist, item 3) gets: "the App Store privacy answers (Data Not Collected; the iPhone scanner uses the camera on the device only), the age rating, the Local Network text and the camera text".

### 5.6 About page and `docs/THIRD_PARTY.md`

- `docs/THIRD_PARTY.md`: **no new row** with option A (an Apple system framework and our own code). With option B or C a row is required (section 3.4). A short line is added under the table: "The iPhone QR scanner is own code on Apple's AVFoundation (a system framework of iOS); it ships no third-party code."
- About screen: no license notice is needed with option A. The Android page "QR scanner" (`about.qr_scanner`, `about.app_scans_with_google`) is shown only on Android (`scanner_note`). Decision for Alon (question 3): add a similar page on iPhone that says what the privacy notice says, or not. If yes, proposed rows (not added now):

| Key | English | Hebrew | where |
|-----|---------|--------|-------|
| `about.app_scans_with_apple` | The app scans the QR code with the camera of your iPhone. The picture stays on your phone and is not saved. Sababi gets only the text. | האפליקציה סורקת את קוד ה־QR באמצעות המצלמה של האייפון. התמונה נשארת בטלפון ולא נשמרת. SABABI מקבל רק את הטקסט. | About screen, iPhone: text of the QR scanner page |

and `scanner_note` becomes true for iOS in `controller_connect.gd:44` (`about.qr_scanner` is reused as the page title).

### 5.7 Strings for the app (`assets/lang/strings.csv`, added in phase 2, listed here for `localization-reviewer`)

No existing row changes. Four new rows (key, English, Hebrew, where):

| Key | English | Hebrew | where |
|-----|---------|--------|-------|
| `connect.scan_hint` | POINT THE CAMERA AT THE QR CODE ON THE TV | כוונו את המצלמה אל קוד ה־QR שבטלוויזיה | Phone (iPhone), scan view: help line over the camera picture |
| `connect.scan_cancel` | CANCEL | ביטול | Phone (iPhone), scan view: button that closes the camera |
| `connect.camera_denied` | THE CAMERA IS OFF FOR SABABI. TURN IT ON IN SETTINGS, OR TYPE THE ROOM CODE. | המצלמה כבויה עבור SABABI. הפעילו אותה בהגדרות, או הקלידו את קוד החדר. | Phone, Connect screen: message after the player said no to the camera |
| `connect.no_camera` | THIS PHONE HAS NO CAMERA. TYPE THE ROOM CODE. | אין מצלמה בטלפון הזה. הקלידו את קוד החדר. | Phone, Connect screen: message when the scan cannot start |

No existing row has the text CANCEL, so none is reused. Hebrew keeps SABABI and QR in Latin letters, as the rules say. These rows are shown on the iPhone only; the key for the Android failure text, `connect.qr_failed`, does not change.

## 6. Manual test 33 (new; steps for `docs/MANUAL_TESTS.md`, all "Not run")

Needs: 1 iPhone, 1 Mac with Xcode, 1 TV with the Sababi TV app, a second phone for a profile code. Run test 13 steps 1a to 2d first. Every step has one pass or fail criterion. Claude cannot run them.

1a. Run `IOS_TEAM_ID=<id> tools/deploy-ios.sh`. Check: the plugin builds, the app installs and starts (exit code 0).
2a. Open the Connect screen. Check: the SCAN QR CODE button is the first control under the status line and is at least 200 px high (REQ-FL-58, 83a).
3a. Tap SCAN QR CODE for the first time. Check: iOS shows the camera question once, with the text of section 5.3 (REQ-FL-91).
3b. Tap Allow. Check: the camera view opens within 2 seconds, in portrait, with the hint line and the CANCEL button (REQ-FL-88).
4a. Point the phone at the QR code on the TV from 30 cm to 1 m (note the distance range that reads). Check: the view closes and the phone is on the waiting screen within 3 seconds of the code being in the picture. (REQ-FL-89) Note: the time in seconds, 5 tries.
4b. Scan a QR code of a shared player profile (a second phone, Share). Check: the player list opens with the note that the player was added. (REQ-FL-89)
4c. Scan a QR code of a web page. Check: the Connect screen shows "THIS IS NOT A SABABI CODE." and the camera is closed. (REQ-FL-89)
5a. Open the scan view and tap CANCEL. Check: the view closes, the Connect screen shows no message, and the typed room code still joins. (REQ-FL-90)
5b. Open the scan view and swipe down. Check: same result as 5a. (REQ-FL-90)
5c. Open the scan view, press the home button and return. Check: the camera view is closed, no message; the green camera dot in the status bar is off. (REQ-FL-88, 90)
6a. Settings > Sababi > Camera off. Tap SCAN QR CODE. Check: no camera view, the Connect screen shows the exact text of `connect.camera_denied`, and typing the room code joins. (REQ-FL-91)
6b. Switch the camera on again. Check: the scan works without a restart. (REQ-FL-91)
7a. After a scan (and after CANCEL) check the Photos app and Files. Check: no new picture or file of Sababi (REQ-FL-92). Note: Settings > Privacy > Camera lists Sababi, and Settings > Privacy has no new entry (microphone, photos) for Sababi.
8a. Set the phone to Hebrew in the app. Check: the hint line and CANCEL show the Hebrew text and read right to left, inside the screen edge. Note: a Hebrew reader confirms the words (the manual test step for Claude-written Hebrew).
9a. In the dark room with only the TV on. Check: the code reads in 5 seconds (note: yes/no, the phone model).
9b. Hold a child of 5 to 8 years in front of the TV with the phone. Check: the child scans without help in 30 seconds.

The matching row `| 33 | ... |` goes in the "Tests the user has to run now" table of CLAUDE.md in phase 0. Nothing in this test can be done headless (a real camera): the GDScript side is covered by the headless tests of phase 2.

## 7. Risks

| # | Risk | Effect | Answer |
|---|------|--------|--------|
| R1 | The plugin cannot be built or run on the machines Claude uses (no Xcode, no iPhone) | Code is written blind; compile errors and crashes show only on the owner's Mac | Phase 1 PR says "not built". The code is small. Manual test 33 and test 13 are Device tests, never marked Pass by Claude. The owner (or a Mac session) runs phase 1 first with a "hello" call before the rest is merged. |
| R2 | Godot 4.7 iOS plugin API differs from the one this plan knows (header names, `add_singleton`, signal emit from the main thread) | Plugin does not load | Phase 1 starts by building the plugin guide's sample against the 4.7.2 headers; the result is written in the PR. If the API is not workable the fallback is option D (VisionKit through the same API) or F. |
| R3 | The whole iOS app has never run on a device (test 13 never run) | A scanner bug cannot be told from a join bug | Test 13 steps 1a to 2d must pass first (test 33 says so). |
| R4 | Godot's render loop and a native view controller on top: the Godot view pauses or the sensors stop while the view is up | Phone loses the TV link while scanning | The scan is short, the link is a WebSocket with the normal timeouts; test step 4a checks the join. If the link drops, the plugin closes the view on `applicationWillResignActive`. |
| R5 | The privacy notice says "not sent" and a later change breaks that | Wrong legal text | REQ-FL-92 is a requirement with a test step; a change of the plugin goes through `code-reviewer` and the owner (privacy notice). |
| R6 | Camera question text is English only | A Hebrew child gets an English question | Same known limit as the Local Network text. Out of scope; listed in the open `localization` issue. |
| R7 | App Store review asks why the camera is used | Delay | The text (5.3) says it, the scan is user started, and the notice explains it. |
| R8 | iPad and simulator have no usable camera | Button shown, scan fails | `no_camera` message (REQ-FL-91). The simulator build has no plugin slice for the camera, so the button is hidden there only if the simulator slice is not built; decision in phase 1. |
| R9 | The Mac build step makes `tools/deploy-ios.sh` slower and needs Godot sources | Friction for the owner | The plugin is built once and cached in `ios/plugins/`; the script rebuilds only when the source is newer. |

## 8. Decisions for Alon

1. **Approve option A** (own plugin on Apple AVFoundation, no third party). Or choose B (a community plugin: then name it, and `license-reviewer` checks the license), C (Google ML Kit, with data to Google) or D (VisionKit, minimum iOS 16).
2. **Minimum iOS version**: keep 15.0 (AVFoundation works on it) or raise it to 16 (needed only for option D). Issue #289 holds the open iOS store decisions.
3. **About page on iPhone** for the scanner (section 5.6): add or not. It is not required by any license with option A.
4. **Privacy notice, camera text and the App Privacy answer**: accept, change or reject the drafts in sections 5.1 to 5.5 (owner only). The Hebrew drafts need a native reader.
5. **Camera text only in English** (Godot limit) or add a Hebrew `InfoPlist.strings` by hand in the Xcode project later.
6. **The plugin binaries are built on the Mac and not committed** (section 3.3). Or commit the built xcframeworks (bigger repository, no Mac build step for others, and a binary in the repository that CI cannot rebuild).
7. **Phase 0 timing**: add the Planned requirements and Manual test 33 now (with the CLAUDE.md table row, which is a change of a CLAUDE.md rule file: owner approves), or wait until phase 1 starts.
8. **A haptic buzz on a good scan** (REQ-FL-89) is a small extra that the issue did not ask for: keep or remove.
