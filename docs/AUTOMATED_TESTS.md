# Automated tests

The tests that run by themselves, with no person and no device. `docs/MANUAL_TESTS.md` holds the rest: what needs a phone, a TV, a
remote, a camera, or a person who looks and judges. When a manual step is covered here, it is removed from there (the numbers of the
other steps do not change) and it gets an ID `A-<test>-<item>` in the table below.

## Run them on the Mac

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tests/run_all.sh        # all suites, stops at the first failure
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/coverage.sh       # same suites with the 80% line coverage check (CI)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/smoke_settings.gd -- --role=tv   # one suite (the role is in suites.txt)
```

The suites are listed in `tests/suites.txt` (`script|role|title`). A new suite is added there only. Each suite prints `ok` or `FAIL`
for every check and ends with `N checks, M failed` (the TV smoke test ends with `smoke test done, M failed`). The whole run takes a few
minutes and opens no window (`--headless`). Screenshots for a look at the screens need a display and are not part of the run:
`godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --role=tv`.

## What replaced a manual step

| ID | Replaces | The checks that do it (suite: check) |
|----|----------|---------------------------------------|
| A-11-1 | Test 11 item 1, rows, title, buttons | `smoke_tv`: "the result menu has Restart, Settings and Back to menu", "each row has a square in the slot color of its player, best first", the `WINS!` title; `layout_menus`: maze results fit. The reading from the sofa stays in item 1 |
| A-11-2 | Test 11 item 2, winner, 'not finished', 60 px edge | `smoke_tv`: maze rows `1ST ... S` and `2ND ... NOT FINISHED`; `layout_menus`: with 4 long names (English and Hebrew) every text and button of the result menu is inside the 60 px edge, no text is below 28 px, buttons do not overlap. The check fails when the edge is made smaller |
| A-11-3 | Test 11 item 3, race results with 4 rows | `smoke_tv`: race rows and buttons; `layout_menus`: race results and the pause menu fit in English and Hebrew |
| A-11-4 | Test 11 item 4, 'not finished', furthest first | `smoke_tv`: "a car that did not finish is listed as not finished, after the finishers" |
| A-11-5 | Test 11 item 5, New game opens the settings with the last choice, Back returns | `smoke_settings`: "the view opens with the last choice (REQ-GM-94)", "Back returns to the Games screen"; `smoke_tv`: "restart keeps the chosen track", "the race results offer Settings" |
| A-11-6 | Test 11 item 6, 'No players connected' with only Back to menu | `smoke_tv`: "results with nobody left say 'No players connected' and only offer Back to menu", "race: when the phone does not come back, 'No players connected' opens (REQ-MR-14)" |
| A-11-7 | Test 11 item 7, medal title, winner, Tie | `smoke_tv`: "equal scores give the title Tie!", "one player and tiers: the row has the silver medal", "a solo player who did not finish gets no medal"; `results_medals` (all medal and tie rules); `game_helpers`: the text of a medal |
| A-17-5 | Test 17 item 5, the Language row switches at once and is kept | `smoke_lang`: "the row switches back to English", "the Settings screen is in Hebrew at once", the phones are told (`heard == ["en", "he", "en"]`), the language is saved in the settings file and the choice is not asked again, the layout turns (QR card left or right of the slots) |
| A-20-5 | Test 20 item 5, a guest keeps the number and `Player N` | `smoke_tv`: "FD-22: card names" (guest `2P`, profile name `Maya`), "a phone without a name is Player N"; `net_profiles` |
| A-20-11 | Test 20 item 11, no NEW BEST in the maze, Sumo and a random race track | `smoke_bests`: "Treasure Maze and Sumo Bumpers have no personal best", "a random track has no key (REQ-MR-56)", "a guest gets nothing" |

## Everything else that is automated (and stays in `tests/`)

These suites guard the rules and the screens. They do not remove a manual step, because the step also asks for a look, a feeling or
a real device, but they make a regression show in CI before a person sees it.

| Suite | What it checks |
|-------|----------------|
| `run_tests` | protocol, server, slots, the controller client, remove and kick, sensors, tilt and recenter |
| `net_loss` | a silent phone: when it is lost, when its slot is freed (grace times, paused game) |
| `net_pin` | the join PIN rules, 5 wrong PINs and the 30 s lock, the PIN pad, the About pages |
| `net_profiles`, `profiles`, `profile_code`, `ui_share`, `smoke_bests` | profiles: names, `Sam` and `sam`, bests, copy codes, share, NEW BEST |
| `smoke_tv`, `games_focus`, `smoke_settings`, `ui_states`, `results_medals`, `layout_menus` | TV flow, Back and the quit question, the Players modal, arrow keys, settings views, medals, result and pause menus |
| `smoke_lang` | the strings table, Hebrew, right to left, the language choice |
| `audio` | the synth, songs, effects, volume, the Haptics switch and its saving |
| `game_helpers`, `game_rules`, `*_rules`, `smoke_*` | the rules of every game, the leader chip and name tag sizes, medal tiers, the tilt body, the swing detector |
| `design_tokens` | sizes, colors, license files packed in the export presets |

## What stays manual, and why

| Kind of step | Tests | Why a machine cannot do it |
|--------------|-------|-----------------------------|
| Real Wi-Fi off, screen lock, a phone call, a returning app | 1, 7, 8b.4, 13.5 | The phone and Android decide what happens. The timing rules are tested in `net_loss` and `smoke_tv`, but not what the phone really does |
| The Android Back key, the remote, the Menu key, the launcher icon | 8, 8b.1 | R1 failed on a real TV because of an engine setting. It needs the real key events |
| Camera, QR, iPhone | 2, 13, 20.12 to 20.15, 21.2, 21.6 | Real camera, plugin and iOS |
| Real sensor axes and drift, swing thresholds with a real arm, latency, packet rate, frame rate on a TV box | 3, 4, 6, 9 to 15, 22 to 26, 24 | Needs the phone sensors and the TV box. The code is tested with made-up values |
| Feel (too light, too fast, too nervous), difficulty, a child of 5 to 8 years | most game tests | A person judges it |
| Look from the sofa, sharp pixels, readable text, Hebrew wording, sound, the animal and tile pictures | 12, 16, 17, 18, 19 and the "pixel world" items | A person looks and listens. The sizes and the 60 px edge are tested where they can be (`layout_menus`, `game_helpers`, `smoke_tv`) |

## Findings of the cleanup

- `tests/golf_rules.gd` stopped at hole 1 with a script error (`h.bumpers` does not exist on every hole), so the checks of holes 2 to 5
  never ran, and the suite still said "0 failed". It reads the optional lists with `get()` now.
- With the checks running: on Mini Golf hole 5 the sliding barrier passes 0.25 m from the cup (the other things keep 0.3 m, REQ-MG-12).
  The test checks that the barrier never covers the tee or the cup, and leaves the 0.3 m margin to a decision of the owner. Nothing in the game was changed.
