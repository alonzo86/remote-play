# Privacy notice: draft paragraph for the QR scanner (Android)

`docs/legal/privacy-notice.md` is the notice (the canonical text); this file keeps only the facts behind its section 4. Draft, not legal advice. Written on 2026-10-13 for checklist item B2 of pull request 33. The full privacy notice and terms (English and Hebrew, drafts) are in `docs/legal/`; this paragraph is the source of their QR scanner part. It must say the same as the About note (`about.app_scans_with_google` in `assets/lang/strings.csv`): if one changes, change the other.

## English

**QR code scanner (Android).** To join a game, the Android phone app can scan a QR code from the TV. The scan uses the Google code scanner, which is part of Google Play services. The camera picture stays on your phone and is not sent to us or to Google. Sababi receives only the text of the code. Google receives technical data about how the scanner works and uses it to run and improve the scanner (the notice of 2026-11-09 is this short; the examples are in the facts below). See Google's ML Kit terms: https://developers.google.com/ml-kit/terms.

## Hebrew

Written in `docs/legal/privacy-notice.he.md` (section 4), based on the Hebrew of the About note. The owner reads Hebrew and reviews it.

## Facts behind the paragraph

- Source: <https://developers.google.com/ml-kit/terms> and <https://developers.google.com/ml-kit/android-data-disclosure>, read on 2026-10-13.
- The input (the camera picture) and the result are processed on the phone and are not sent to Google. ML Kit may contact Google servers for fixes, models and hardware information.
- Metrics Google lists: device information (maker, model, OS version, build, ML hardware), app information (package name, version), performance (latency), API settings (image format, resolution), input and output size, feature version, event type, error codes, and per-installation identifiers that are "not intended to uniquely identify a user or physical device". Sent over HTTPS, not given to third parties.
- Not confirmed: whether the code scanner also sends a device identifier (Google does not say if it is a "thin" or a "bundled" feature).
- The terms ask us to tell users that Google processes ML Kit metrics, and make us responsible for our Play Data safety answers. They do not ask for consent.
- Only the Android phone app carries the scanner library. The TV app has its own build project without it (since 2026-10-13). The phone without Google Play services cannot scan and types the room code, so nothing is sent to Google there.

## iPhone and iPad (added 2026-11-01, issue #299)

**Not in the notice now:** on 2026-11-09 the owner removed all iPhone wording from `docs/legal/privacy-notice.md` and its Hebrew twin until the iOS app is published (issue #425 keeps the removed text and adds it back then). The owner accepted this draft on 2026-11-01. Facts behind it:

- The scan uses Apple's VisionKit (`DataScannerViewController`, QR codes only) in our own plugin. It runs on the device. No third-party code and no network call are added.
- The camera picture is shown on the scan screen only. Nothing is saved, sent or kept after the screen closes (REQ-FL-92, Manual test 33 steps 7a and 7b).
- App Store Connect, App Privacy: the answer stays **Data Not Collected**. The picture is processed on the device and never sent off the device (Apple counts data as collected when it is sent off the device and kept; the owner confirms this against Apple's current App Privacy text before the form is filled). The plugin uses no "required reason API", so it adds no entry to the privacy manifest; check with the Xcode privacy report on the first build.
- The camera question is the text of `privacy/camera_usage_description` in the `controller-ios` preset: "Sababi uses the camera only to read the QR code on your TV, to join the game. The picture is not saved or sent." and its Hebrew entry (needs a native reader).
