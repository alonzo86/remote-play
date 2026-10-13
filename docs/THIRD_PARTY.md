# Third-party libraries and resources

Every library, plugin, font, sound, image or other resource that Wobble ships and that another maker owns is listed here, with its license and what the license asks of us. The rule for adding one is in `CLAUDE.md` ("Third-party libraries and resources"). Checked on 2026-10-13 (draft, not legal advice).

| Component | Version | Used in | Shipped in the app | License | Owner | Notice needed | Status |
|-----------|---------|---------|--------------------|---------|-------|---------------|--------|
| Godot Engine | 4.7 (CI 4.7.2) | TV and phone apps | yes | MIT | Juan Linietsky, Ariel Manzur, Godot Engine contributors | Yes: shown on the About screen (`Engine.get_license_text()`) | Done |
| Libraries bundled in Godot (FreeType, HarfBuzz, ICU data, libpng, zlib, ENet, mbedTLS and others) | as in the engine | TV and phone apps | yes | Mostly MIT, BSD, Apache-2.0, Zlib | Various | Yes: shown on the About screen (`Engine.get_copyright_info()`, `get_license_info()`) | Done |
| AndroidX, Kotlin standard library, kotlinx-coroutines, JetBrains annotations, javax.inject, JSpecify, Firebase components and encoders, Google datatransport (46 libraries, list below) | as in the list below | Android apps (pulled in by the code scanner and the Godot template) | yes | Apache-2.0 | Google, JetBrains and others | Apache-2.0 asks for a copy of the license with the app. None of these libraries has a NOTICE file. Shown on the About screen, page "Android libraries" (`assets/licenses/android-libraries.txt`, packed in every export) | Done |
| Play services base, basement, tasks, and ODML image (4 libraries) | 18.1.0, 18.1.0, 18.0.2, 1.0.0-beta1 | Android apps (pulled in by the code scanner) | yes | Android Software Development Kit License | Google | Google's terms, not a free open-source license. Listed with the URL of the terms on the same About page | Done |
| Google Play services code scanner (ML Kit), `play-services-code-scanner:16.1.0`, with `com.google.mlkit:common:18.9.0`, `vision-common:17.0.0`, `barcode-scanning-common:17.0.0` | 16.1.0 | Android phone, QR scan | the client library yes, the scanner module no (Play services downloads it) | ML Kit Terms of Service (they include the Google APIs Terms of Service) | Google | Tell users that Google gets ML Kit metrics (About note: done; privacy notice and Play Data safety form: open). Details below | Open: privacy notice and Data safety form |
| Press Start 2P font | `assets/fonts/PressStart2P-Regular.ttf` | TV and phone UI | yes | SIL OFL 1.1 | The Press Start 2P Project Authors (cody@zone38.net) | Yes: `assets/fonts/OFL-PressStart2P.txt`, packed in every export, shown on the About screen | Done |
| Wobble Pixel Hebrew font | own work | Hebrew names | yes | SIL OFL 1.1 (own choice) | Alon Yampolski | Yes: `assets/fonts/OFL-WobblePixelHebrew.txt`, packed and shown like the other font | Done |
| gdtoolkit (gdlint) | 4.x | CI | no | MIT | Scony and contributors | No | Done |
| setup-godot GitHub Action | v2 | CI | no | MIT | Chickensoft | No | Done |

Our own work needs no row: the sounds (made in code), the QR encoder, the avatars, icons, tiles, medals and the logo. For the art made with an AI tool (the Gemini mascot, the scripted avatars) see the open questions in the legal drafts of the project.

The longer notes and the questions for a lawyer are in the project files (`legal/`), not in the repository.

## Android libraries (checked 2026-10-13)

The list comes from `./gradlew dependencies --configuration standardReleaseRuntimeClasspath` in `android/build` (Godot 4.7 template, after `tools/patch_android_manifest.sh`). The `releaseRuntimeClasspath` name in the old note does not exist in this template: the configuration has the flavor in its name (`standard`). The licenses come from the POM of each library in the Gradle cache. Libraries inside the Godot engine itself are in the rows above.

- **Apache-2.0 (46):** androidx activity 1.8.1, annotation 1.8.1, annotation-experimental 1.4.0, annotation-jvm 1.8.1, arch.core common and runtime 2.2.0, collection 1.1.0, concurrent-futures 1.1.0, core 1.8.0, core-ktx 1.2.0, core-splashscreen 1.0.1, customview 1.0.0, documentfile 1.1.0, exifinterface 1.0.0, fragment 1.8.6, lifecycle (common, livedata, livedata-core, runtime, viewmodel, viewmodel-savedstate) 2.6.1, loader 1.0.0, profileinstaller 1.3.1, savedstate 1.2.1, startup-runtime 1.1.1, tracing 1.0.0, versionedparcelable 1.1.1, viewpager 1.0.0; datatransport transport-api 2.2.1, transport-backend-cct 2.3.3, transport-runtime 2.2.6; firebase-annotations 16.0.0, firebase-components 16.1.0, firebase-encoders 16.1.0, firebase-encoders-json 17.1.0; javax.inject 1; org.jetbrains annotations 13.0; kotlin-stdlib, kotlin-stdlib-common 2.1.21; kotlin-stdlib-jdk7, jdk8 1.8.0; kotlinx-coroutines (android, core, core-jvm, bom) 1.6.4; org.jspecify 1.0.0.
- **Android Software Development Kit License (4):** play-services-base 18.1.0, play-services-basement 18.1.0, play-services-tasks 18.0.2, com.google.android.odml:image 1.0.0-beta1.
- **ML Kit Terms of Service (4):** play-services-code-scanner 16.1.0, mlkit common 18.9.0, vision-common 17.0.0, barcode-scanning-common 17.0.0.
- **No license in the POM (1):** com.google.guava:listenablefuture 1.0. It is the empty placeholder that Guava publishes (Apache-2.0 in Guava); it holds no code.
- **NOTICE files:** none of the libraries has a `NOTICE` file. The ML Kit and Firebase archives hold a `third_party_licenses.txt` for the Google "open source licenses" screen, which Wobble does not show.
- **About screen:** the page "Android libraries" (in the 3rd Party Libraries list of the Android TV and phone apps) has this list, the names and URLs of Google's two terms, and the Apache-2.0 text. Done on 2026-10-13.

## Google code scanner and ML Kit (read on 2026-10-13)

Sources: <https://developers.google.com/ml-kit/terms> and <https://developers.google.com/ml-kit/android-data-disclosure>.

- **What it means for Wobble:** the camera image and the scanned text stay on the phone (ML Kit does not send input or output to Google). ML Kit may contact Google servers for fixes, new models and hardware information. It sends Google *metrics* about how the API works in the app.
- **Metrics listed by Google:** device information (maker, model, OS version, build, ML hardware); app information (package name, app version); performance (latency); API settings (image format, resolution); input and output size, feature version, event type, error codes. Per-installation identifiers "not intended to uniquely identify a user or physical device". Sent over HTTPS, not given to third parties. Google does not say which kind (thin or bundled) the code scanner is, so we cannot say if a device identifier is also sent.
- **What the terms ask of us:** tell the users of the app that Google processes ML Kit metrics data, as the law requires; answer the Data safety form for ourselves (Google says it is our duty); no reverse engineering of the ML Kit APIs or models. The terms do not ask for consent.
- **About note (done 2026-10-13):** `about.app_scans_with_google` now says that the picture stays on the phone, that Wobble gets only the text, and that Google receives technical data such as the phone model and the app version. The Hebrew was written by Claude and needs a native reader.
- **Play Data safety form (draft for you to check in the Play Console):** the app collects no name, e-mail, location, contacts or photos. The profile (name, avatar, best scores) stays on the phone and is sent to the TV on the local network only. For the ML Kit metrics, the likely answers are: *Device or other IDs* (the per-installation identifier), *App info and performance* (diagnostics, performance), and *App activity* is not collected. Data is collected by Google's library, encrypted in transit, not used for ads. Ask Play Console's data types guide before you submit; this is not legal advice.
- **Privacy notice:** the notice lives in the project files (`legal/`), not in this repository. It needs one paragraph with the same facts as the About note.
- **Phones without Play services:** no scan; the app offers PASTE ROOM LINK instead, so nothing is sent to Google there.
