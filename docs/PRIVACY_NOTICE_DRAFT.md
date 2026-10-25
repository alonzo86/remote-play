# Privacy notice: draft paragraph for the QR scanner (Android)

Draft, not legal advice. Written on 2026-10-13 for checklist item B2 of pull request 33. The full privacy notice and terms (English and Hebrew, drafts) are in `docs/legal/`; this paragraph is the source of their QR scanner part. It must say the same as the About note (`about.app_scans_with_google` in `assets/lang/strings.csv`): if one changes, change the other.

## English

**QR code scanner (Android).** To join a game, the Android phone app can scan a QR code from the TV. The scan uses the Google code scanner, which is part of Google Play services. The camera picture stays on your phone and is not sent to us or to Google. Sababi receives only the text of the code. Google receives technical data about how the scanner works, such as the phone model, the operating system version, the app version and performance information, and uses it to run and improve the scanner. See Google's ML Kit terms: https://developers.google.com/ml-kit/terms.

## Hebrew

Written in `docs/legal/privacy-notice.he.md` (section 4), based on the Hebrew of the About note. The owner reads Hebrew and reviews it.

## Facts behind the paragraph

- Source: <https://developers.google.com/ml-kit/terms> and <https://developers.google.com/ml-kit/android-data-disclosure>, read on 2026-10-13.
- The input (the camera picture) and the result are processed on the phone and are not sent to Google. ML Kit may contact Google servers for fixes, models and hardware information.
- Metrics Google lists: device information (maker, model, OS version, build, ML hardware), app information (package name, version), performance (latency), API settings (image format, resolution), input and output size, feature version, event type, error codes, and per-installation identifiers that are "not intended to uniquely identify a user or physical device". Sent over HTTPS, not given to third parties.
- Not confirmed: whether the code scanner also sends a device identifier (Google does not say if it is a "thin" or a "bundled" feature).
- The terms ask us to tell users that Google processes ML Kit metrics, and make us responsible for our Play Data safety answers. They do not ask for consent.
- Only the Android phone app carries the scanner library. The TV app has its own build project without it (since 2026-10-13). The phone without Google Play services cannot scan and types the room code, so nothing is sent to Google there.
