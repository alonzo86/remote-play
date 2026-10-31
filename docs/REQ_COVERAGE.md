# Requirement ids that no test named (issue #306)

The issue counted 126 ids (36 in `GAME_REQUIREMENTS.md`, 28 in `TV_FLOW.md`) that appear in no test, manual step or
`AUTOMATED_TESTS.md` row. There was no tool for it, so `tests/req_ids.gd` is the tool now: it reads the ids of the requirements
files and the files that name them, and fails for an id that is not named and not in `tests/req_untested.txt`. Alon chose
"the agent sorts them" (2026-10-31). The count with the same rule as the issue (full text `REQ-XX-n` only) is 122 ids
(`REQ-XX-1` of the template is a placeholder and is not counted).

Buckets:

- **a (done)**: a test names the id now. Either a new check was written (the second column says where) or the existing check of
  that suite checks the behavior and now names the id. A short list after an id (`REQ-PG-5, 6 and 21`) counts for each id of the
  list; a range (`to`) and a wildcard (`REQ-MG-*`) count for none.
- **todo**: a headless test can check it; it is not written yet. The reason says how. None is left: the tests were written in the pull requests #347, #349 and the one after it.
- **review**: a rule of work or of taste that a reviewer judges; no machine can.
- **device**: only a device or a person can check it. None of the 122 is in this bucket: the 63 rows with the status `Device` all
  have manual steps since the pull requests #320 and #324.
- **obsolete**: removed, superseded or no longer true. **These are for Alon to decide**; no requirement was deleted or reworded.

Counts: a 98, todo 0, review 11, obsolete 13, device 0 (total 122).

Ids that need a decision of Alon (obsolete):

- Removed rows with a test that proves the removal: REQ-BC-8, REQ-TN-21. Keep as history or delete the rows.
- Finished plans written as requirements: REQ-FL-47, REQ-FL-48, REQ-FL-49.
- 3D and superseded pixel rules: REQ-GM-47 (umbrella), REQ-GM-47c, REQ-GM-47f, REQ-GM-47g, REQ-GM-47h.
- A rule that the games do not follow and a count cannot settle: REQ-GM-47k (at most 8 colors in a world palette; the games use 11 to 72 color literals).
- Rules that say something false today: REQ-GM-60 (tests are in `smoke_<game>.gd`, not in `smoke_tv.gd`) and REQ-GM-61 (the logic tests
  are in the `*_rules.gd` suites, not in `run_tests.gd`). They need a new wording.

| ID | Bucket | How it is named, or why it is not |
|----|--------|-----------------------------------|
| REQ-2D-1 | a (done) | req_registry (new check) |
| REQ-2D-2 | a (done) | small_screen (new suite: every game at 1280x720; three games are listed as fixed layouts, issue #348) |
| REQ-2D-3 | review | draw calls instead of one node for each moving object: the code-reviewer reads it (frame_cost.gd shows the cost only) |
| REQ-2D-4 | review | a convention for units (pixels at 1920x1080, tilt as sin of the angle): the reviewer reads it |
| REQ-AH-1 | a (done) | named in the existing check of smoke_air_hockey.gd |
| REQ-AH-2 | a (done) | req_registry (new check) |
| REQ-AH-3 | a (done) | named in the existing check of smoke_air_hockey.gd |
| REQ-AH-11 | a (done) | named in the existing check of smoke_air_hockey.gd |
| REQ-AH-15 | a (done) | smoke_air_hockey (check made stricter: purple, no avatar) |
| REQ-AH-22 | a (done) | smoke_bests (new check) |
| REQ-BC-2 | a (done) | req_registry (new check) |
| REQ-BC-8 | obsolete | the row says Removed on 2026-10-29 (a hit drops no star, REQ-BC-7): smoke_bumper_cars checks that a hit takes no star |
| REQ-BC-13 | a (done) | smoke_bumper_cars (new check: a lost phone pauses, 10 s later cars, clock and stars have not moved) |
| REQ-BC-14 | a (done) | named in the existing check of smoke_bumper_cars.gd |
| REQ-BC-15 | review | friendly toys, a hint line, positive texts: the localization-reviewer and the code-reviewer judge it |
| REQ-BW-8 | a (done) | swing_replay.gd (the overlay line has every field of the last swing, one line for each player) |
| REQ-BW-18 | a (done) | named in the existing check of smoke_bowling.gd |
| REQ-BW-20 | a (done) | named in the existing check of smoke_bowling.gd |
| REQ-BW-21 | a (done) | named and made exact in r4_bowling.gd (the plate is there at 1.4 s and gone at 1.6 s) |
| REQ-BW-22 | a (done) | named in the existing check of swing_setup.gd |
| REQ-FL-17 | a (done) | named in the existing check of smoke_settings.gd (Back to the tile of the game) |
| REQ-FL-18 | a (done) | named in the existing check of smoke_tv.gd |
| REQ-FL-21 | a (done) | req_registry (new check) |
| REQ-FL-22 | a (done) | req_registry (new check) |
| REQ-FL-26 | a (done) | named in the existing check of smoke_tv.gd |
| REQ-FL-27 | a (done) | tv_flow_reqs (new check) |
| REQ-FL-29 | a (done) | tv_flow_reqs (new check), protocol_doc.gd (the phase values in the document) |
| REQ-FL-30 | a (done) | named in the existing checks of design_tokens.gd; a check of the start screen was added |
| REQ-FL-31 | review | no internet service for play and the Connect help text: judged by the reviewer with REQ-P5 (the help text is a string row) |
| REQ-FL-32 | a (done) | tv_flow_reqs (new check) |
| REQ-FL-34 | a (done) | tv_flow_reqs (new check) |
| REQ-FL-35 | a (done) | named in the existing check of join_flow.gd (a removed phone gets the message and leaves) |
| REQ-FL-41a | a (done) | named by a step of docs/MANUAL_TESTS.md |
| REQ-FL-45 | a (done) | design_tokens.gd (new check: confetti and backdrop in code), ui_states_a.gd |
| REQ-FL-46 | a (done) | named in the existing check of ui_states_a.gd |
| REQ-FL-47 | obsolete | the plan for the next pull request that restyled the marble race; it is done (tier 2 and the arcade style replaced it) |
| REQ-FL-48 | obsolete | the game shell is built in the same pull request as the menus: history of a finished pull request |
| REQ-FL-49 | obsolete | the other games get the shell in the same pull request: history of a finished pull request |
| REQ-FL-53 | a (done) | named in the existing check of docs/MANUAL_TESTS.md, ui_states.gd |
| REQ-FL-61 | a (done) | named in the existing checks of smoke_lang.gd, focus_walk.gd |
| REQ-FL-65b | a (done) | named in the existing checks of audio.gd, audio_phones.gd |
| REQ-FL-65c | a (done) | named in the existing check of audio.gd, audio_controller.gd |
| REQ-FL-70 | a (done) | named in the existing checks of tv_profiles.gd, smoke_settings.gd (unknown index), r4_tv_profiles.gd; design_tokens.gd (new check: no avatar on a game object) |
| REQ-FL-74 | a (done) | named in the existing check of r4_phone_profiles.gd |
| REQ-FL-77 | a (done) | named in the existing check of ui_share.gd |
| REQ-FL-78 | a (done) | named in the existing check of profile_code.gd |
| REQ-FL-79 | a (done) | named in the existing check of r4_bests.gd |
| REQ-FL-83a | a (done) | named by a step of docs/MANUAL_TESTS.md |
| REQ-GM-1 | a (done) | req_registry (new check) |
| REQ-GM-2 | review | the gaps and exceptions of a game file are read by the product-engineer and the code-reviewer |
| REQ-GM-3 | a (done) | req_registry (new check) |
| REQ-GM-4 | a (done) | named in the existing check of docs/AUTOMATED_TESTS.md |
| REQ-GM-5 | review | a behavior change must change the requirements file in the same commit: the code-reviewer checks every pull request |
| REQ-GM-7a | review | the starting point for a new requirements file is a rule of work for the add-minigame skill |
| REQ-GM-10 | a (done) | req_registry (new check) |
| REQ-GM-11 | a (done) | req_registry (new check) |
| REQ-GM-23 | a (done) | frame_cost.gd (every player of every game has its slot color), palette_lint.gd (no own color near a slot color) |
| REQ-GM-25 | review | a fair start state for every player is a rule of the design of each game; the reviewer checks it per game |
| REQ-GM-36 | a (done) | frame_cost.gd (the menu during play of every game has Resume and End game only) |
| REQ-GM-42 | review | which files a game may use depends on docs/TV_FLOW.md (FD-9, FD-13) and docs/THIRD_PARTY.md: the license-reviewer judges it |
| REQ-GM-44 | a (done) | palette_lint.gd (new check: every use of OK and BAD is on a list with its meaning) |
| REQ-GM-47 | obsolete | the tier 2 rule of toy-like worlds; its parts 47a to 47h are superseded by REQ-GM-47j to 47n (the pixel worlds) |
| REQ-GM-47c | obsolete | outline width in 3D: no game is drawn in 3D since minigame_3d.gd was removed (issue #300) |
| REQ-GM-47f | obsolete | the text says it is superseded by REQ-GM-47l and REQ-FL-38 (no round corners in the arcade style) |
| REQ-GM-47g | obsolete | the text says it is superseded by REQ-GM-47l (no registered game is drawn in 3D) |
| REQ-GM-47h | obsolete | materials and light in 3D: no game is drawn in 3D |
| REQ-GM-47j | a (done) | pixel_games.gd (render lane: the outline of Shell.pixel_ball is one world pixel); the outline of other objects is a look item of the game tests |
| REQ-GM-47k | obsolete | the limit of 8 colors is not what the games do: the games have 11 to 72 different color literals each (only bowling.md and tennis.md list extra colors); the colors on screen can be counted in the render lane, but the limit per game is for the owner to decide |
| REQ-GM-47l | a (done) | pixel_world_lint (new suite: the world draw of every game snaps) |
| REQ-GM-47n | a (done) | pixel_world_lint (new suite: no text in the world draw of any game) |
| REQ-GM-49b | a (done) | audio.gd (limits and lengths of every effect), audio_events.gd (a buzz comes with a sound effect) |
| REQ-GM-49c | a (done) | named in the existing check of audio.gd, audio_controller.gd |
| REQ-GM-49d | a (done) | named in the existing check of game_names_hebrew.gd |
| REQ-GM-51 | a (done) | frame_cost.gd (480 ticks add no nodes in any game) |
| REQ-GM-52 | a (done) | frame_cost.gd (every game builds its scene in 2 s or less) |
| REQ-GM-60 | obsolete | says each game has a check in tests/smoke_tv.gd; in fact each game has its own smoke_<game>.gd suite: reword the rule |
| REQ-GM-61 | obsolete | says pure logic has unit tests in tests/run_tests.gd; in fact they are in the *_rules.gd suites: reword the rule |
| REQ-GM-62 | a (done) | req_registry (new check) |
| REQ-GM-63 | a (done) | named in the existing check of tools/coverage.sh |
| REQ-GM-71 | a (done) | named in the existing check of game_helpers.gd |
| REQ-GM-81 | review | friendly content (no violence, nothing alive shot) is a judgment of the reviewer on pictures and sounds |
| REQ-GM-84 | review | kind words in titles and messages is a judgment of the localization-reviewer (strings.csv has no list of banned words) |
| REQ-GM-95 | a (done) | named in the existing check of smoke_air_hockey.gd |
| REQ-GM-100 | a (done) | named in the existing check of ui_share.gd |
| REQ-GM-101 | a (done) | named in the existing check of profile_code.gd |
| REQ-MG-15 | a (done) | smoke_bests (new check) |
| REQ-MG-17 | a (done) | named in the existing check of swing_setup.gd |
| REQ-MR-1 | a (done) | req_registry (new check) |
| REQ-MR-2 | a (done) | smoke_race (new check: no dead zone, speed grows with the tilt, damping, no speed limit) |
| REQ-MR-3 | a (done) | named in the existing checks of smoke_race.gd, device_mocks.gd, hud_layout.gd |
| REQ-MR-5 | a (done) | smoke_race (new check: a car past the edge is put back and bounces with a part of its speed) |
| REQ-MR-10 | a (done) | smoke_race (new check) |
| REQ-MR-11 | a (done) | smoke_race (new check) |
| REQ-MR-20 | a (done) | game_rules (new check) |
| REQ-MR-21 | a (done) | game_rules (new check) |
| REQ-MR-24 | a (done) | named in the existing check of game_rules.gd |
| REQ-MR-25 | a (done) | req_registry (new check) |
| REQ-MR-30 | a (done) | smoke_race (one tile; Difficulty, Theme, track list, Back and Start) |
| REQ-MR-32 | a (done) | named in the existing checks of smoke_tv.gd |
| REQ-MR-33 | a (done) | named in the existing check of smoke_race.gd |
| REQ-MR-47 | a (done) | named in the existing check of game_rules.gd |
| REQ-MR-55 | a (done) | smoke_tv.gd (the results menu of the race: Try again, Settings, Back to menu) |
| REQ-MZ-10 | a (done) | named in the existing check of hud_layout.gd |
| REQ-MZ-11 | a (done) | named in the existing check of smoke_bests.gd |
| REQ-PG-6 | a (done) | named in the existing check of smoke_paint.gd |
| REQ-PG-30 | a (done) | named in the existing check of game_rules.gd |
| REQ-SB-4 | a (done) | named in the existing check of auto_sumo.gd, smoke_sumo.gd |
| REQ-SB-5 | a (done) | named in the existing check of smoke_sumo.gd |
| REQ-SB-21 | a (done) | named in the existing check of smoke_bests.gd |
| REQ-SH-6 | a (done) | named in the existing check of smoke_sheep.gd |
| REQ-SS-21 | a (done) | named in the existing check of smoke_banana.gd, smoke_tv.gd |
| REQ-SS-23 | a (done) | named in the existing check of game_rules.gd |
| REQ-SS-24 | a (done) | named in the existing check of smoke_bests.gd |
| REQ-TB-1 | a (done) | req_registry (new check) |
| REQ-TB-2 | a (done) | named in the existing check of smoke_tower.gd |
| REQ-TB-14 | a (done) | named in the existing check of smoke_tower.gd |
| REQ-TB-17 | a (done) | req_registry (new check) |
| REQ-TB-20 | a (done) | audio.gd (new check: the song is in D major at 116 bpm, the five tower effects) |
| REQ-TN-14 | a (done) | named in the existing check of tennis_rules.gd |
| REQ-TN-19 | a (done) | named in the existing check of tennis_rules.gd |
| REQ-TN-21 | obsolete | the row says Removed on 2026-10-18 (the aim line on the TV is not built) |
| REQ-TN-22 | a (done) | named in the existing check of swing_setup.gd |
