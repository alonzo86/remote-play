# Audio plan: arcade music and sound effects (FD-20)

Status: **phase A and the effects of the first five games are built (2026-10-10); Star Shield, the sixth game, has a song and five effects (2026-10-16); manual test 18 is open.** The sections below are the plan; section 11 says what was built and what differs. The owner asked for music on the TV app: an arcade-style, MIDI-like loop, one clip for the menus and one for each game, and sound effects for each game. This file proposes how, lists the effects for each game, and lists the defaults chosen for the open questions. The owner confirms or changes the effect lists (section 4) before phase B.
Style: ASD-STE100 Simplified Technical English, like the other requirements files.

Base: this plan is based on `main`. The arcade style PRs 18 to 24 are still stacked and unmerged, so some names here (the Hebrew texts of FD-19, the pixel worlds) exist only in that stack. When the stack reaches `main`, resolve conflicts in `docs/TV_FLOW.md`, `docs/GAME_REQUIREMENTS.md` and `docs/REQUIREMENTS.md`, and re-check the file names in this plan.

## 1. Decision proposed (FD-20)

The TV plays music and effects. The sound comes **only from the TV app** and depends only on the TV app's own volume settings (section 3.3) and the volume of the TV itself. The phone app makes no sound, so the media volume, mute switch or silent mode of a phone changes nothing. The phone has haptics instead (section 2.3).

The sound is **made in code**, in the same way as the pictures (REQ-P6): a small synthesizer with the four voices of an old arcade chip (two pulse waves, one triangle, one noise), and the songs and effects are data tables in GDScript. No audio file is added to the repository.

| Option | For | Against |
|--------|-----|---------|
| A. Synthesizer in code (proposed) | No license, no file size, fits REQ-P6 ("built in code"), the sound is the 8-bit style by nature, a test can check the samples, a change is a text change in a review | The songs must be written as note tables; a composer's work cannot be dropped in |
| B. Authored files (`.ogg` or `.wav`, or `.mid` with a soundfont) | Any style, a composer can deliver | License checks (CC0 or paid, a credit file as for the fonts), 0.5 to 2 MB for each loop in `.ogg`, a `.mid` needs a soundfont (about 1 to 30 MB) that Godot 4 cannot play without an add-on, a review cannot read the sound |
| C. Hybrid: synthesizer now, files later | A file can replace one clip with no code change (the sound bank loads `res://assets/audio/<id>.ogg` first when it exists) | A little more code for the bank |

Default: **A**, built so that C is possible (section 3.4). Music in "MIDI-like" style is what A makes: the songs are note lists with a tempo, and the synthesizer plays them.

## 2. What the owner hears

### 2.1 Music

The clip ids are the game ids. The games were renamed later: `maze` is Treasure Maze (was Tilt Maze), `marble_race` is Car Race (was Marble Race), `snowball_splat` is Banana Party (was Snowball Splat); the names in this plan are the names of the time it was written.

| Clip | Where | Mood | Length of the loop |
|------|-------|------|--------------------|
| `menu` | Logo (starts at once; if the system blocks audio it starts at the first key), Connect, Games, Settings, a game settings view | Bright, easy, slow to medium (about 112 BPM). Does not tire, because it plays for minutes | 32 bars of 4/4 (about 68 s) |
| `maze` | Tilt Maze | Calm and curious, a little sneaky (about 120 BPM) | 16 bars (32 s) |
| `marble_race` | Marble Race | Fast and driving (about 150 BPM) | 16 bars (25 s) |
| `paint_grab` | Paint Grab | Cheerful and bouncy (about 128 BPM) | 16 bars (30 s) |
| `sumo_bumpers` | Sumo Bumpers | Heavy and comic, a march with a strong beat (about 132 BPM) | 16 bars (29 s) |
| `snowball_splat` | Snowball Splat | Light and playful, bell-like (about 124 BPM) | 16 bars (31 s) |
| `asteroid_blast` | Star Shield | Bright and driving, a march in A minor (about 140 BPM) | 16 bars (27 s) |

Rules:
- Game music of a game with a countdown starts at the end of the countdown ("GO"), not before it. The countdown has its own beeps (section 4.1). Only a game with a visible timer has a countdown (REQ-GM-35); the music of the other games (Star Shield, Sumo Bumpers, Pin Pals, Mini Golf, Tennis with 2 to 4 players) starts with the play.
- Music is quieter than effects (about 6 dB), so a hit is always heard. Every effect is 3 to 9 dB above the music at the default levels (RMS, bus gains applied), and no effect or song clips (peak 1.0 or lower); `tests/audio.gd` asserts this for every effect.
- The pause menu and the "phone lost" card lower the music to 30% (it does not stop, so Resume has no jump). The result menu stops the music and plays a short jingle, then goes quiet; it does not loop under a menu where the players talk.
- The menu music goes on across the menu screens with no restart (the Games screen to the Settings screen and back). It restarts only after a game.
- When the music of a game is finished by the result, the menu music comes back when the player goes back to the menu.
- Nothing is loud at start: music fades in over 0.5 s and out over 0.5 s (a hard step is the style for pictures, not for sound; a hard stop clicks).

### 2.2 Shared effects (all games and menus)

| Id | When | Sound |
|----|------|-------|
| `move` | The menu cursor moves | Very short high blip (30 ms) |
| `select` | OK on an item | Two-note rise (90 ms) |
| `back` | Back | Two-note fall (90 ms) |
| `denied` | OK on a dim item (for example a game that needs 2 players) | Low buzz (120 ms) |
| `join` | A phone joins | Three-note rising run (200 ms) |
| `leave` | A phone leaves or is lost | Three-note falling run (200 ms) |
| `pause` / `resume` | Pause menu opens / closes | A short down step / a short up step |
| `count` | Each second of the 3, 2, 1 countdown (games with a timer only) | A beep (100 ms) |
| `go` | The countdown ends | A higher, longer beep (300 ms) |
| `time_low` | The last 5 s of a timed game, each second | A soft tick |
| `win` | The result menu, with a winner or a medal | A short fanfare (1.5 s). A medal tier changes the length: bronze 1 note run, silver 2, gold 3 |
| `tie` | The result menu, a tie or no medal | A neutral two-note phrase (1 s). Never a sad sound for a loss (REQ-GM-81, children from 5 years) |

### 2.3 Haptics on the phone (new requirement)

Sound is for the TV only, so the phone gives feedback by vibration. The games already have haptics (REQ-GM-43, `Haptics.pulse()`); this plan makes them a rule: **every game gives haptic feedback on the phone of the player for its main scenes, and each game file lists them.** The haptic and the TV effect for one event happen together, so an event is felt on the phone and heard on the TV.

Proposed scenes (the game files get the final list; the current code already has most of them):

| Scene | Haptic | Games |
|-------|--------|-------|
| The countdown ends ("GO") | 60 ms | the games with a countdown: maze, marble race, snowball splat, paint grab, Tennis alone. Not Star Shield, Sumo Bumpers, Pin Pals, Mini Golf, Tennis with 2 to 4 players |
| The player scores or reaches the goal (exit, finish line, a hit on a Puff) | 120 ms, or 40 ms for a small score | maze, marble race, snowball splat |
| The player's own object touches something (wall, bumper, another player) | 15 to 30 ms, with a cool-down | maze, marble race, paint grab, sumo |
| A bump that pushes the player (stronger when harder) | 20 to 80 ms | sumo |
| The player's action fires (a throw, a dash) | 15 to 40 ms | snowball splat, sumo |
| The player's blob paints or loses a tile | 20 ms, with a cool-down | paint grab |
| The player falls off (a funny fall, not a punishment) | 120 ms | sumo |
| A round or the game ends | 400 ms | all |
| The game pauses because a phone was lost, and when it comes back | one pulse on the phones that are still connected | all |

Rules:
- Only the phone of the player that the event is about vibrates, except the start, the end and a pause (all phones).
- A repeated haptic has the 100 ms or longer cool-down of REQ-GM-43, and a game must not buzz all the time (a long tilt in a wall is not a long buzz).
- A haptic never replaces information: a phone without a vibrator, or with vibration off, plays the same game. The TV shows everything that matters.
- Sound and haptic are two separate outputs: the volume levels of the TV app do not turn haptics off.
- **Haptics switch (decided by the owner on 2026-10-10):** the phone app has a HAPTICS ON/OFF switch. It is a framed box (`UiKit.box_button()`) on the phone's wait screen, the screen the player sees between games, so the player can change it before a game starts. Default ON. The choice is saved on the phone (`user://`, with the other phone data) and applies to every TV the phone joins. When it is OFF, the phone ignores the `haptic` messages (`controller_pad.gd` does not call `Input.vibrate_handheld()`); the TV sends them as before, so the protocol does not change (`docs/PROTOCOL.md` stays as it is). The switch has Hebrew text (FD-19) when that is merged. A test checks that OFF stops the vibration call, that ON restores it, and that the choice is saved and loaded. Manual test 18 checks it on a phone, and that a phone with the switch OFF plays the game normally.
- Test: for each game, a smoke test emits each scene and checks that `App.server.haptic()` (or `Haptics.pulse()`) was called for the right slot. A device check (manual test 18, haptic part) feels each scene on a real phone: is it too weak, too strong, or too often?

## 3. How it is built

### 3.1 Files

| File | Job |
|------|-----|
| `scripts/audio/synth.gd` | Pure functions. Renders a list of notes to 16-bit mono `PackedByteArray` samples at 22050 Hz: pulse (duty 12.5%, 25%, 50%), triangle, noise (short and long), a simple volume envelope, a pitch slide. No node, no scene |
| `scripts/audio/songs.gd` | The data: one song for each clip (tempo, loop length, four channels of notes written as short strings), and the effect table (section 4) |
| `scripts/audio/sound_bank.gd` | Renders a song or an effect to an `AudioStreamWAV` once and keeps it (a loop song uses `LOOP_FORWARD`). Looks for `res://assets/audio/<id>.ogg` first (option C) |
| `scripts/audio/audio_manager.gd` | The autoload `Sound` (or a child of `App`): the buses, one music player, a pool of 8 effect players, `Sound.music(id)`, `Sound.sfx(id)`, `Sound.duck(on)`, volume and mute |
| `tools/make_audio_preview.py` or `tools/export_audio.gd` | A developer tool that writes each song and effect to a `.wav` in a scratch folder, so the owner can listen on a computer without the TV. It is not part of the app |

Rendering at 22050 Hz mono keeps memory small: a 68 s loop is 22050 x 2 bytes x 68 = about 3 MB in memory. All 6 songs are about 11 MB. This is acceptable, but a song is rendered on first use (and the previous game song is freed), so only the menu song and one game song are in memory. Rendering a 30 s loop in GDScript takes about 100 to 300 ms on a TV box (an estimate, not measured: **the first test measures it**); the render happens behind the countdown (3 s), not on the frame the game opens. If it is too slow, the songs are rendered at the first start of the app and cached in `user://audio_cache/`, or the sample rate goes down to 16000 Hz (the style allows it).

### 3.2 Playing in Godot

- Two buses are created in code at start: `Music` and `SFX`, both under `Master`. The default bus layout file is not used, so the layout is code and a test can check it.
- `AudioStreamPlayer` nodes (not 2D or 3D players): the audio does not come from a place on the screen.
- The effect pool has 8 players. A new effect takes a free player; if none is free, it takes the oldest one, except that `win`, `go` and `count` are never cut. The same effect id has a minimum gap of 40 ms (so a ball that touches a wall 10 times in a frame is one sound). This is the audio twin of the haptic cool-down (REQ-GM-43).
- Games call `Sound.sfx("sumo_bump")` at the same places they call `Haptics`/`App.server.haptic()`. A game never makes its own players (a new rule, section 5).
- `Minigame` (the base class) starts the game music at "GO" (at once in a game without a countdown), ducks it on pause and on the "phone lost" card, stops it on the result menu, and plays `count`/`go`/`win`/`tie`. A game then needs only its own effects.
- The music does not stop when the game node is freed by "Back to menu": `App.go_menu()` calls `Sound.music("menu")`.
- Android TV: the mix rate of the project is 44100 Hz (Godot default); the 22050 Hz streams are resampled by the engine. Output latency on a TV box can be 100 ms or more and cannot be fixed in the app; effects are short and not timed with the picture to the frame. Manual test 18 checks that it feels fine.
- Focus loss: when the app goes to the background (Home), Godot pauses the audio by itself; no code is needed. Manual test 18 checks that the music does not play on the Android home screen.

### 3.3 Volume (Settings)

- The Settings screen (REQ-FL-23) gets two rows after "Invert tilt axes": **Music** and **Effects** (a value from 0 to 10, changed with Left and Right, like a choice row; default 7 for Music and 8 for Effects). There is no Mute row (dropped by the owner, issue #49): a level of 0 is silent.
- The values are saved in `user://settings.cfg` (`App.settings`: `music_volume`, `sfx_volume`), like `invert_tilt`.
- Changing a value acts at once. When the owner changes **Effects**, one `select` sound plays as the sample; when the owner changes **Music**, the menu music is already playing, so the change is heard at once.
- The volume steps use a curve (`linear_to_db(v / 10.0)` squared), not a straight line, so the steps sound even.
- Hebrew: the three rows have Hebrew text in `assets/lang/strings.csv` (FD-19, FD-24); the test `smoke_lang` fails when one is missing.
- The phone is not touched: no setting, and it plays no sound (the media volume of the phone has no effect).

### 3.4 Replacing a clip with a file later

`SoundBank` looks for `res://assets/audio/<id>.ogg` before it renders. If the owner (or a composer) delivers a file, it is dropped there with its license text file (`assets/audio/LICENSE-<name>.txt`, as the fonts have) and the code does not change. `REQ-P6` already lists the allowed asset kinds, so the decision FD-20 adds "sound files in `assets/audio`" to the list when this happens. Until then no file exists and no license is open.

### 3.5 Licensing and size

- Option A: the songs are written for this project. The owner owns them (the repository license applies). No third-party license. **Do not copy a known melody** (an arcade tune would be a copyright problem even as notes). All songs are original; the plan for each is a mood and a chord pattern, not a tune.
- Repository size: about 25 KB of GDScript for all songs and effects (an estimate). No binary.
- APK size: no change.

## 4. Proposed effects for each game (please confirm or change)

Each row is one effect. "Where" names the event that the game already has (it has a haptic or a state change there). The effects should be easy to hear from the sofa and never scary (REQ-GM-81). Target: **8 to 10 effects for each game, plus the shared ones of section 2.2.**

### 4.1 Tilt Maze (`maze`)

| Id | When | Sound |
|----|------|-------|
| `maze_bump` | A ball touches a wall (same limit as the haptic buzz, REQ-MZ-S1) | A soft "tok" (40 ms, low pulse). Quiet, because it repeats |
| `maze_roll` | *Option*: a ball moves fast | A very quiet rolling noise. **Proposed: not built** (many balls make noise; it hides the music) |
| `maze_exit` | One ball reaches the exit | A bright rising run (350 ms) |
| `maze_exit_other` | The 2nd, 3rd and 4th ball reach the exit | The same run, one note shorter each time |
| `maze_exit_ring` | The exit pulse (0.55 s steps) | *Not built*: too much repeated noise |

### 4.2 Marble Race (`marble_race`)

| Id | When | Sound |
|----|------|-------|
| `marble_wall` | A marble hits a wall faster than the buzz limit | A short clack, higher when faster (2 pitches) |
| `marble_bumper` | A marble hits a bumper | A "boing" (pitch slide up, 120 ms) |
| `marble_marble` | Two marbles touch | A lower clack than the wall |
| `marble_post` | A marble passes a post (difficulty posts) | A ping |
| `marble_finish` | A marble crosses the line | A rising run (400 ms); the first marble also plays `win` at the result |
| `marble_lap` | *Not built*: no laps now | - |
| `marble_roll` | *Option*: a rolling noise that follows the speed of the fastest marble | **Proposed: not built**, as in the maze |

### 4.3 Paint Grab (`paint_grab`)

| Id | When | Sound |
|----|------|-------|
| `paint_tile` | A blob paints an empty tile | A soft "plip" (30 ms). Several in a row: the pitch goes up a little for each tile in a short row (resets after 0.5 s), like a coin run |
| `paint_steal` | A blob takes a tile of another color | A "pop" with a small downward slide (60 ms) |
| `paint_bounce` | Two blobs touch | A rubber "bwop" (80 ms) |
| `paint_edge` | A blob bounces off the edge | A quiet "tok" |
| `paint_lead` | *Option*: the lead changes in the last 10 s | A short alert (2 notes). **Proposed: built**, because it makes the end exciting |

### 4.4 Sumo Bumpers (`sumo_bumpers`)

| Id | When | Sound |
|----|------|-------|
| `sumo_bump` | Two bumpers hit | A "bonk" (noise burst plus low pulse, 80 ms); stronger hits are lower and longer |
| `sumo_dash` | A bumper dashes | A "whoosh" (noise with a rising filter, 150 ms) |
| `sumo_ready` | The dash is ready again | A tiny tick (only for the player, so it is very quiet; **proposed: not built**, 4 players make too many ticks) |
| `sumo_shrink` | The platform shrinks | *Option*: a low rumble that grows as the platform gets small. **Proposed: built as one soft low drone**, volume by the platform size |
| `sumo_fall` | A bumper falls over the edge | A long falling slide with a "wheee" (500 ms, pitch down), funny and not sad (REQ-SB-S3, "WHEE!") |
| `sumo_round_win` | A round ends with a last bumper | A short up-run (400 ms) |
| `sumo_round_start` | A new round starts (the wait after a fall ends) | The `count`/`go` beeps |

### 4.5 Snowball Splat (`snowball_splat`)

| Id | When | Sound |
|----|------|-------|
| `snow_throw` | A press on A throws a snowball | A "fwip" (noise, short, 70 ms) |
| `snow_hit` | A snowball hits a Puff | A soft "splat" (noise plus a pitch drop, 120 ms) followed by a cheerful "boing" |
| `snow_miss` | A snowball misses (the poof) | A very quiet "puff" (60 ms). A miss costs nothing (REQ-GM-81), so no negative sound |
| `snow_puff` | A Puff pops up or flies away | A squeak (pitch slide, 80 ms) |
| `snow_points` | The "+10" appears | A coin-like ping, so the player knows who scored. The pitch depends on the player slot (4 different pitches), so a player knows which sound is theirs |
| `snow_combo` | *Option*: 3 hits in a row | **Proposed: not built**; the rules have no combos |

## 5. Requirements to add (in the same commit as the behavior, REQ-GM-5)

- `docs/TV_FLOW.md`: FD-20, a section "Sound" with REQ-FL-64 to 72 (music for the menu, ducking, the Settings rows, saving, the phone is silent and its media volume has no effect, nothing plays in the background).
- `docs/GAME_REQUIREMENTS.md`: change REQ-GM-43 to the haptic rule of section 2.3 (every game lists its haptic scenes in its game file, and the games without a scene need a gap or exception under REQ-GM-2); and add REQ-GM-49a to 49f: a game uses `Sound` only (no own players); it names its effects in its requirements file; an effect has a minimum gap; no scary or negative sound (a miss, a fall and a loss are funny or neutral); every event that has a haptic should have an effect, unless the game file says why not; the game music starts at "GO".
- `docs/REQUIREMENTS.md` REQ-P6: add "sound that is made in code (`scripts/audio`)" and, when option C is used, "audio files in `assets/audio` with a license file".
- `docs/games/<id>.md` (five files): a new "Haptics" section with the scenes of section 2.3, and a new "Sound" section with the table of section 4 (the final effect list) and the song mood.
- `docs/RISKS.md`: remove "No sound."; add the risks of section 8.
- `docs/PROTOCOL.md`: no change (the phone decides whether to vibrate).
- `docs/TV_FLOW.md` (phone app section): the HAPTICS switch of the wait screen, a new REQ-FL number.
- `README.md`, the `add-minigame` skill and `docs/games/TEMPLATE.md`: a new game lists its music and effects.

## 6. Tests

Headless Godot uses the dummy audio driver: the nodes and buses work, nothing is heard. So the tests check the data and the behavior, not the sound:

| Suite | Checks |
|-------|--------|
| `tests/audio_synth.gd` (new, in `tests/suites.txt`) | The synthesizer: a pulse at 440 Hz has the right period; a rest is silence; the envelope ends at 0 (no click at the end); a loop song has the same length as its bars and tempo; samples are inside the 16-bit range (no clipping); the same notes give the same bytes (deterministic) |
| `tests/audio_songs.gd` (new) | Every registry game has a song and every effect id of its requirements file is in the effect table; no song is empty; every song has the same number of bars on each channel; no effect is longer than 2 s (fanfares) or 0.5 s (the others) |
| `tests/smoke_tv.gd` | The buses `Music` and `SFX` exist; the Settings screen has the Music and Effects rows, they change `App.settings`, and the values are saved and loaded; `Sound.music("menu")` starts a player and a second call with the same id does not restart it; a pause ducks and Resume restores; the result menu stops the music |
| `tests/game_helpers.gd` | The effect pool: a 41st effect in the same 40 ms is dropped; the oldest player is taken when the pool is full; `win` is never cut |
| `tests/smoke_*.gd` (the five games) | Each game plays its effects: the test emits the event (a hit, a fall, a throw) and checks the signal `sfx_played` (a small log kept by the manager for tests, not used by the app) |
| `tests/smoke_lang.gd` | The new Settings rows have Hebrew text |

What a headless test cannot check, and Claude does not claim: whether it sounds good, the loudness balance, the latency, and the pops. These are manual test 18.

Coverage: the new modules are pure data and a thin player manager; the 80% rule applies to each script. `songs.gd` is a table, so it is covered by the checks that read every song. If `audio_manager.gd` is hard to test, only the `AudioStreamPlayer` calls are small; the logic (pool, gap, ducking state) is kept in plain functions that the tests call.

## 7. Phases (one PR for each, stacked, as the owner prefers)

| Phase | Content | PR |
|-------|---------|----|
| A | The phone HAPTICS switch (small, and useful by itself), the synthesizer, the sound bank, `Sound`, the buses, the menu song, the shared effects, the Settings rows (volume, mute), FD-20 and the requirements, the tests, the preview tool, manual test 18 (menu part) | PR 1 |
| B1 | Game music and effects for Sumo Bumpers (it has the most events: use it to tune the pool and the gap) | PR 2 |
| B2 | Marble Race and Tilt Maze | PR 3 |
| B3 | Paint Grab and Snowball Splat | PR 4 |

After phase A the owner can listen to the preview tool's `.wav` files on a computer and say what to change in the songs before the game songs are written.

## 8. Risks

- **Taste.** Chip music is easy to make bad. Mitigation: phase A makes only the menu song, and the owner hears it before the others. The preview tool makes a change fast.
- **The loop is annoying after minutes.** Mitigation: the menu loop is long (68 s), a game loop is 25 to 32 s (a game round is 60 s to a few minutes), and the Music row can go to 0.
- **Render time and memory on a TV box** (section 3.1). Mitigation: rendering behind the countdown; a cache or a lower sample rate if needed.
- **Latency.** A TV box can add 100 ms or more. Effects are not timed to the frame; haptics on the phone come at the same time and are not delayed by the TV.
- **Clicks and pops** from a hard start or end. Mitigation: every note has a short envelope and the player fades in and out.
- **Many effects at once with 4 players.** Mitigation: the pool, the minimum gap, quiet repeated effects, and the "not built" choices in section 4.
- **A child or a sleeping person.** Default volume is not full (7 and 8 of 10), and the first start of the TV app does not play a loud sound.
- **Sound that scares** (REQ-GM-81). Mitigation: section 4 has no negative sound for a miss, a fall or a loss, and the test checks the length of every effect.

## 9. Open questions and the default chosen for each

| # | Question | Default (used until the owner answers) |
|---|----------|----------------------------------------|
| 1 | Synthesizer in code, authored files, or both? | Synthesizer in code, with a way to drop in files later (option C) |
| 2 | Does the phone make sound? | No. Haptics only |
| 3 | Menu music on the logo screen too? | Yes, it starts with the logo (on a TV the app may start with the sound off until the owner presses a key; if the system blocks audio, it starts at the first key) |
| 4 | Music while the game settings view is open? | Yes, the menu song continues |
| 5 | Music on the result menu? | A jingle, then silence |
| 6 | Mute and two volumes in Settings? | Yes: Music, Effects, Mute. Defaults 7, 8, off |
| 7 | One song for each game, or several that change with the difficulty? | One song for each game. The tempo does not change with the difficulty |
| 8 | Does the music speed up in the last 10 s of a timed game? | No (a tempo change in a loop is hard to do without a click). The `time_low` tick is used |
| 9 | The effects of section 4 | As listed. The rows marked "not built" and "option" are not built unless the owner asks |
| 10 | Rolling noise for balls and marbles? | Not built |
| 11 | A different pitch for each player on the "scored" sounds? | Yes, in Snowball Splat and Paint Grab (so a player hears their own), 4 pitches |
| 12 | Song names | Working titles are the clip ids. The owner can name them; no name shows in the app |
| 14 | A haptics ON/OFF switch? | Yes (owner's decision): on the phone wait screen, default ON, saved on the phone |
| 13 | Audio in the screenshots/tile tool and the CI | No sound is needed there; the dummy driver is used |

## 10. What the owner decides next

1. The effect lists of section 4: add, remove, or change any row (especially the "option" rows).
2. The default answers of section 9, if any is wrong.
3. After phase A: listen to the menu song and say what to change (faster, calmer, more bass, other mood).

## 11. What was built (2026-10-10)

Built on `main`, in the Party Pop style of `main` (the arcade style stack is not merged; resolve conflicts later):
- `scripts/audio/synth.gd`, `songs.gd`, `audio_manager.gd` (the autoload `Sound`), the volume rows and Mute on the Settings screen, the phone Settings screen with the Haptics switch, and the requirements REQ-FL-64 to 66, REQ-GM-49a to 49c (this PR). Manual test 18.
- The menu song and one song for each game, the shared effects, and the effects of the five games, played where the games already have a haptic.
- Differences from the plan:
  - The sample rate is **16000 Hz** (not 22050), to make the songs faster on a TV box. A song is made in steps of 3 ms a frame on the main thread (a worker thread crashed the coverage run, which counts lines); on a desktop the menu song is ready after about 1.8 s. A TV box is not measured.
  - The loops are **16 bars** (about 25 to 34 s), including the menu song (the plan said 32 bars).
  - The game song is made behind the countdown and starts when `RoundClock` reports GO (so a pause during the countdown moves it too). A game without a countdown (REQ-GM-35) calls `Sound.music()` in `Minigame._ready()`: the song is made at once and starts when it is ready, with the play.
  - `Sound` emits the signal `sfx_played(id)` that the test uses (no test-only log).
  - Effects that are not built: `maze_exit_other`, `marble_post` and `snow_puff` (no event to hang them on), the Sumo drone and rolling noise. `paint_bounce`, `paint_edge`, `paint_lead`, `time_low` and `denied` are built.
  - The songs, effects and levels are first guesses.
  - `tools/export_audio.gd` writes every song and effect as a `.wav` file, for listening on a computer: `godot --headless --path . --script tools/export_audio.gd -- <folder>`.
