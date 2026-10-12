# Third-party libraries and resources

Every library, plugin, font, sound, image or other resource that Wobble ships and that another maker owns is listed here, with its license and what the license asks of us. The rule for adding one is in `CLAUDE.md` ("Third-party libraries and resources"). Checked on 2026-10-11 (draft, not legal advice).

| Component | Version | Used in | Shipped in the app | License | Owner | Notice needed | Status |
|-----------|---------|---------|--------------------|---------|-------|---------------|--------|
| Godot Engine | 4.7 (CI 4.7.2) | TV and phone apps | yes | MIT | Juan Linietsky, Ariel Manzur, Godot Engine contributors | Yes: shown on the About screen (`Engine.get_license_text()`) | Done |
| Libraries bundled in Godot (FreeType, HarfBuzz, ICU data, libpng, zlib, ENet, mbedTLS and others) | as in the engine | TV and phone apps | yes | Mostly MIT, BSD, Apache-2.0, Zlib | Various | Yes: shown on the About screen (`Engine.get_copyright_info()`, `get_license_info()`) | Done |
| Godot Android Gradle template, AndroidX, Kotlin libraries | not listed yet | Android apps | yes | Mostly Apache-2.0 | Google, JetBrains and others | Yes if a library has a NOTICE file | Open: needs `gradle :app:dependencies --configuration releaseRuntimeClasspath` from a good build |
| Google Play services code scanner (ML Kit), `play-services-code-scanner:16.1.0` | 16.1.0 | Android phone, QR scan | no (Play services downloads it) | Google APIs and ML Kit terms | Google | Note on the About screen; privacy notice; Play Data safety form | Open: terms not read |
| Press Start 2P font | `assets/fonts/PressStart2P-Regular.ttf` | TV and phone UI | yes | SIL OFL 1.1 | The Press Start 2P Project Authors (cody@zone38.net) | Yes: `assets/fonts/OFL-PressStart2P.txt`, packed in every export, shown on the About screen | Done |
| Wobble Pixel Hebrew font | own work | Hebrew names | yes | SIL OFL 1.1 (own choice) | the Wobble authors | Yes: `assets/fonts/OFL-WobblePixelHebrew.txt`, packed and shown like the other font | Decision: keep OFL, name a real holder |
| gdtoolkit (gdlint) | 4.x | CI | no | MIT | Scony and contributors | No | Done |
| setup-godot GitHub Action | v2 | CI | no | MIT | Chickensoft | No | Done |

Our own work needs no row: the sounds (made in code), the QR encoder, the avatars, icons, tiles, medals and the logo. For the art made with an AI tool (the Gemini mascot, the scripted avatars) see the open questions in the legal drafts of the project.

The longer notes and the questions for a lawyer are in the project files (`legal/`), not in the repository.
