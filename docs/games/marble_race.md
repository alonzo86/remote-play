# Marble Race (`marble_race`)

Type: 3D. Players: 1 to 4. Input: tilt (`PlayerInput.tilt()`), Recenter.
General requirements: `docs/GAME_REQUIREMENTS.md`. Code: `scripts/game/marble_race/`.

## Goal

Each player tilts a phone to roll a marble along a winding track. The first marble over the finish line wins.
Marbles bounce off the walls, the posts and each other.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a section for this game (Test 9). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

### Play

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-1 | 1 to 4 players. Each phone controls one marble. One player is a time trial. | Done | smoke_tv |
| REQ-MR-2 | Tilt gives acceleration. The marble keeps its speed and slows by damping. There is no dead zone and no speed limit. | Done | smoke_tv (tilt moves marble) |
| REQ-MR-3 | A countdown of 3 s holds all marbles still. At "GO!" every phone buzzes. | Done | smoke_tv (grid wait) |
| REQ-MR-4 | All marbles start on one line across the track, with the same distance to the finish. They do not touch. | Done | smoke_tv |
| REQ-MR-5 | The marble stays on the track. At the edge it bounces back and loses part of its speed. | Done | run_tests (track maths) |
| REQ-MR-6 | Posts are fixed. A marble bounces off them with little loss of speed. Each post leaves a gap of one marble or more on one side. | Done | run_tests (gap check) |
| REQ-MR-7 | Marbles bounce off each other. A marble that finished does not collide with the others. | Done | Device |
| REQ-MR-8 | The first marble that crosses the finish line wins. The other players have 4 s to finish. The race ends when all have finished or after 4 s. | Done | smoke_tv |
| REQ-MR-9 | While the race runs, the screen shows the order (1st to 4th) and the race time. A finished player shows the finish time. | Done | Device (readability) |
| REQ-MR-10 | The order is: finished marbles by time, then the others by distance along the track. The leader chip (REQ-GM-46) shows the first marble (with its time once it has finished), or TIE. Each phone shows its own place and, after the finish, its time (REQ-FL-67). In the countdown each marble has a name tag (REQ-GM-46a). | Done | smoke_tv (standings), game_helpers (leader, tags) |
| REQ-MR-11 | A player who leaves is removed from the race. The race continues with the others. | Done | smoke_tv |
| REQ-MR-12 | A phone that is lost pauses the race while another player is connected (general REQ-GM-30). | Done | smoke_tv (maze, same base class) |
| REQ-MR-13 | The haptic events are: GO (60 ms), a hit at 3 m/s or faster (20 ms, at most every 150 ms), crossing the finish line (120 ms). | Done | Device |

### Tracks

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-20 | A track is a line of points with one half-width. The drivable area is all points within the half-width of the line. | Done | run_tests |
| REQ-MR-21 | The tracks are made from a seed (REQ-MR-51). The four hand-made tracks (Classic, Sprint, Zigzag, Gauntlet) were removed on 2026-10-09. | Done | run_tests |
| REQ-MR-22 | Each track starts with a straight of 8 m or more toward the top of the screen. | Done | run_tests |
| REQ-MR-23 | A track does not touch itself. | Done | run_tests |
| REQ-MR-24 | The finish line is 6 m before the end of the track. Posts end 8 m before the end of the track. | Done | run_tests |
| REQ-MR-25 | The track list in the registry has one value for each fixed seed in `MarbleTrack.FIXED_SEEDS` and the random track. A test checks that they agree. | Done | run_tests |

A generated track is 100 to 165 m long and 5.9 to 9.2 m wide (REQ-MR-52). The winning time depends on the track and is not measured on a device yet. See "Open questions".

### Settings and generated tracks (built 2026-10-09)

REQ-GM-90 to 96 apply. The settings view of the race has the Difficulty row and, under it, the track list. The tracks are made on the fly from a seed, so the four hand-made tracks (REQ-MR-21, 30) go away when this is built.

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-50 | Difficulty is the number of posts on the track: Easy 2, Medium 6, Hard 10 posts for each 100 m of track (Classic today has about 6). The track, the marbles and the physics are the same at every difficulty. Posts keep REQ-MR-6 (a gap of one marble or more on one side) and REQ-MR-24 (they end 8 m before the end). | Done | run_tests |
| REQ-MR-51 | A track is made from a seed (`MarbleTrack.generate(seed)`). The same seed gives the same track. Every generated track meets REQ-MR-20 to 24: a straight start of 8 m or more toward the top of the screen, no touching itself, the finish line 6 m before the end. A test makes many seeds and checks these rules for all of them. | Done | run_tests |
| REQ-MR-52 | A generated track is 90 to 170 m long and 5.8 to 9.2 m wide (in practice 100 to 165 m and 5.9 to 9.2 m). Its turns are smooth: no turn is sharper than the half-width allows, so a marble never gets stuck in a corner. | Done | run_tests |
| REQ-MR-53 | The settings view shows the tracks under the Difficulty row as a carousel (`scripts/ui/track_picker.gd`): the tracks in one line, the track in the middle is the selected one. It is bigger and has a yellow border (REQ-GM-97) and, when the carousel has the focus, the black focus frame; the tracks at the sides get smaller and fainter, and the line slides (0.16 s) when it moves. A dot for each track is under the line, and the dot of the selected one is bigger. A track has no name. Tracks 1 to 10 are line sketches of the middle line of a track made from one of 10 fixed seeds (`MarbleTrack.FIXED_SEEDS`). The 11th is the random track: a question mark. The race uses a new random seed that is not one of the 10 fixed ones. With the focus on the carousel, Left and Right on the remote move the line by one track (it stops at the ends, REQ-GM-92); no OK is needed. Up goes to Difficulty, Down to Start. Track 1 is in the middle when the view opens the first time; later the last choice is in the middle (REQ-GM-94). | Done | smoke_settings |
| REQ-MR-54 | The track list is the only place where the track is chosen. The seed of the chosen track is part of `start_props`, so Restart (REQ-MR-33) plays the same track. The track name is shown during the race (REQ-MR-35). | Done | smoke_tv |
| REQ-MR-55 | The results menu has "Settings" (REQ-GM-95) in place of "Choose track". | Done | smoke_tv |
| REQ-MR-56 | Personal best (REQ-GM-98): the key is `marble_race|<difficulty>|<track 1 to 10>`, the value is the finish time in milliseconds, lower is better. A random track has no key and no best. | Done | smoke_bests |

### Menus and flow

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-30 | The Games screen has one "Marble Race" tile. It opens the settings view (REQ-GM-90): Difficulty, the track list, Start and Back. Back returns to the grid with the tile in focus. | Done | smoke_settings |
| REQ-MR-31 | The results menu (`open_results()`, REQ-GM-72) names the winner and lists all marbles: the finish times first, then the marbles that did not finish (by distance). It has Restart, Settings and Back to menu. Settings opens the settings view with the last choices. | Done | smoke_tv |
| REQ-MR-32 | The pause menu has Resume, Restart and Back to menu. A player can leave a race at any time. | Done | smoke_tv (pause menu) |
| REQ-MR-33 | Restart keeps the track. | Done | smoke_tv |
| REQ-MR-34 | Back in the results leaves the game. | Done | smoke_tv |
| REQ-MR-14 | If all players leave during the race (their slots are freed: the hold of a paused game is over, REQ-GM-30a), a menu "No players connected" opens with "Back to menu". A lost phone first pauses the race with the card of REQ-GM-30. It is also what opens when the results are asked for after all players left. | Done | smoke_tv |
| REQ-MR-15 | The Recenter button of the phone zeroes the tilt of that player in the race. | Done | smoke_tv |
| REQ-MR-35 | The name of the track is shown on the screen during the race. | Done | Device |

### Camera and look

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-40 | The camera looks down from above and slightly from behind. It never turns. Up on the screen is toward the start of the track's first straight. | Done | Device |
| REQ-MR-41 | The camera follows the middle of the pack and moves higher when the marbles are far apart (9 m to 48 m). | Done | Device |
| REQ-MR-42 | All marbles stay in view while they are 55 m or less apart along the screen. Beyond that, an arrow in the color of the marble shows at the screen edge, and a number (32 px) shows how many meters it is behind the leader. | Done | smoke_tv, Device |
| REQ-MR-43 | The track floor, the edge, the posts, the finish line and the marbles have clear and different colors. Marbles use the slot color. The posts use cyan `#3ddcff`, which is not a slot color. The HUD shows "Finish in N m" for the leader. | Done | smoke_tv (post color), Device |
| REQ-MR-44 | Visual language (`docs/TV_FLOW.md`, FD-18, REQ-GM-47c, 47i to 47n). The world is a pixel world: the camera renders into a 480x270 view with no antialiasing, scaled up with nearest filtering. The marbles and the posts are outlined spheres and cylinders (inverted-hull mesh, `add_outlined_mesh`). The track floor is purple `#472aa3`, the rim is the black outline color (`UiTheme.OUTLINE`), the finish line is a checkered band of white and black boxes, the background is blue `#1b3a8a` (the arcade set). The world palette is these colors, the cyan posts and the slot colors. The shell draws the HUD and the countdown at full resolution. Each marble has its slot number on it, drawn by the HUD at the projected position of the marble (`Shell.ball_number()`, REQ-GM-47n) when its radius on the HUD is 16 px or more (`NUMBER_MIN_R`); a marble that is smaller (the camera is high) has no number, and its color and the edge arrow tell it. The tile screenshot shows this look. | Done | smoke_tv (the view, the HUD position, the size of the marble), Screenshot (`tools/make_tiles.gd`), Device |

## Parameters

In `scripts/game/marble_race/marble_race.gd` unless it says otherwise. Tune them on a device.

| Name | Value | Effect |
|------|-------|--------|
| `ACCEL` | 36 m/s² at tilt 1.0 | A tilt of 15 degrees gives about 9 m/s². |
| `DAMPING` | 1.0 /s | With 15 degrees, top speed is about 9 m/s. |
| `WALL_BOUNCE`, `BUMPER_BOUNCE`, `MARBLE_BOUNCE` | 0.45, 0.9, 0.85 | How lively the hits are. |
| `COUNTDOWN`, `END_DELAY` | 3 s, 4 s | Grid wait, and time for the others after the winner. |
| Track half-widths | `marble_track.gd` | Narrow tracks are harder. |

## Open questions

- Is a dead zone (like the maze, 0.03) or a speed limit needed? Test on a device.
- Are the target winning times right? Measure them in Test 9 and update the table.
- Is the edge arrow (REQ-MR-42) clear enough on a TV? Other options: a smaller marble view, or pull the last marble forward.
- Should the best time of each track be saved? (The results show all finish times. Saving waits until players are identified.)

## Sound and haptics (REQ-GM-49a to 49c, REQ-GM-43)

The song `marble_race` plays from "GO": Fast and driving, 150 BPM, E minor. The countdown, pause and result sounds come from the base class.

| ID | Effect | When | Sound | Status |
|----|--------|------|-------|--------|
| REQ-MR-S1 | `marble_wall`, `marble_wall_hard` | A marble hits a wall; the hard one above twice the buzz speed. | Clack, higher when harder | Device (test 18) |
| REQ-MR-S2 | `marble_bumper` | A marble hits a post. | Boing (pitch slide up) | Device (test 18) |
| REQ-MR-S3 | `marble_marble` | Two marbles touch. | Lower clack | Device (test 18) |
| REQ-MR-S4 | `marble_finish` | A marble crosses the line (haptic 120 ms). | Rising run | Device (test 18) |

Haptics on the phone of the player: Countdown end: 60 ms; Wall, post or marble hit above the buzz speed: 20 ms with a gap; Finish: 120 ms. A post is a bumper: it plays `marble_bumper`.

## Languages (REQ-GM-47o)

The texts of this game are English and Hebrew: the title, the description, the hint and the result texts have a key and a Hebrew text in `assets/lang/strings.csv`. In Hebrew the HUD is mirrored by the shell (title, leader chip, timer); the finish text, the timer and the track name use `Shell.mx()`. The game world is not mirrored.
