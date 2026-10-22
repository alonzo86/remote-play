# Road Rally (`marble_race`)

Type: 2D, a pixel world seen from above. Players: 1 to 4. Input: tilt (`PlayerInput.tilt()`).
General requirements: `docs/GAME_REQUIREMENTS.md`. Code: `scripts/game/marble_race/`.

## Goal

Each player tilts a phone to slide a car along a winding road. The first car over the finish line wins.
Cars bounce off the walls, the obstacles and each other. The game was a 3D marble race until 2026-10-15. The rules, the physics and the tracks are the same: only the look and the name changed. The player picks one of three themes in the settings view: Candy Road, Space Rally or Jungle Run.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a section for this game (Test 9). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. The picture of the board takes about 20 ms to make on a desktop (10 fixed tracks, Hard); it is not measured on a TV box. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

### Play

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-1 | 1 to 4 players. Each phone controls one car. One player is a time trial. | Done | smoke_tv |
| REQ-MR-2 | Tilt gives acceleration. The car keeps its speed and slows by damping (it slides like the marble did; it turns to face the way it moves, REQ-MR-48). There is no dead zone and no speed limit. | Done | smoke_tv (tilt moves car) |
| REQ-MR-3 | A countdown of 3 s holds all cars still. At "GO" (the countdown word of this game only, `marble_race.go`; the other games go from 1 to the play) every phone buzzes. | Done | smoke_tv (grid wait) |
| REQ-MR-4 | All cars start on one line across the track, with the same distance to the finish. They do not touch. | Done | smoke_tv |
| REQ-MR-5 | The car stays on the track. At the edge it bounces back and loses part of its speed. | Done | run_tests (track maths) |
| REQ-MR-6 | Obstacles are fixed. A car bounces off them with little loss of speed. Each obstacle leaves a gap of one car or more on one side. | Done | run_tests (gap check) |
| REQ-MR-7 | Cars bounce off each other. A car that finished does not collide with the others. | Device | Device |
| REQ-MR-8 | The first car that crosses the finish line wins. The other players have 4 s to finish. The race ends when all have finished or after 4 s. | Done | smoke_tv |
| REQ-MR-9 | While the race runs, the badge at the top shows only the leader (the leader chip, REQ-MR-10) and the race time, not the whole order. The result menu lists every car with its place, 1st to 4th (a finished car with its time, the others as not finished, REQ-FL-65). | Device | smoke_tv (rows and places), layout_menus; Device (readability) |
| REQ-MR-10 | The order is: finished cars by time, then the others by distance along the track. The leader chip (REQ-GM-46) shows the first car (with its time once it has finished), or TIE. Each phone shows its own place and, after the finish, its time (REQ-FL-67). | Done | smoke_tv (standings), game_helpers (leader) |
| REQ-MR-11 | A player who leaves is removed from the race. The race continues with the others. | Done | smoke_tv |
| REQ-MR-12 | A phone that is lost pauses the race while another player is connected (general REQ-GM-30). | Done | smoke_tv (the race hold with one phone; the maze for two phones) |
| REQ-MR-13 | The haptic events are: GO (60 ms), a hit at 3 m/s or faster (20 ms, at most every 150 ms), crossing the finish line (120 ms). | Device | Device |

### Tracks

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-20 | A track is a line of points with one half-width. The drivable area is all points within the half-width of the line. | Done | run_tests |
| REQ-MR-21 | The tracks are made from a seed (REQ-MR-51). The four hand-made tracks (Classic, Sprint, Zigzag, Gauntlet) were removed on 2026-10-09. | Done | run_tests |
| REQ-MR-22 | Each track starts with a straight of 8 m or more toward the top of the screen. | Done | run_tests |
| REQ-MR-23 | A track does not touch itself. | Done | run_tests |
| REQ-MR-24 | The finish line is 6 m before the end of the track. Obstacles end 8 m before the end of the track. | Done | run_tests |
| REQ-MR-25 | The track list in the registry has one value for each fixed seed in `MarbleTrack.FIXED_SEEDS` and the random track. A test checks that they agree. | Done | run_tests |

A generated track is 100 to 165 m long and 5.9 to 9.2 m wide (REQ-MR-52). The winning time depends on the track and is not measured on a device yet. See "Open questions".

### Settings and generated tracks (built 2026-10-09)

REQ-GM-90 to 96 apply. The settings view of the race has the Difficulty row, the Theme row (REQ-MR-45) and, under them, the track list. The tracks are made on the fly from a seed, so the four hand-made tracks (REQ-MR-21, 30) go away when this is built.

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-50 | Difficulty is the number of obstacles on the track: Easy 2, Medium 6, Hard 10 obstacles for each 100 m of track (Classic today has about 6). The track, the cars and the physics are the same at every difficulty. Obstacles keep REQ-MR-6 (a gap of one car or more on one side) and REQ-MR-24 (they end 8 m before the end). | Done | run_tests |
| REQ-MR-51 | A track is made from a seed (`MarbleTrack.generate(seed)`). The same seed gives the same track. Every generated track meets REQ-MR-20 to 24: a straight start of 8 m or more toward the top of the screen, no touching itself, the finish line 6 m before the end. A test makes many seeds and checks these rules for all of them. | Done | run_tests |
| REQ-MR-52 | A generated track is 90 to 170 m long and 5.8 to 9.2 m wide (in practice 100 to 165 m and 5.9 to 9.2 m). Its turns are smooth: no turn is sharper than the half-width allows, so a car never gets stuck in a corner. | Done | run_tests |
| REQ-MR-53 | The settings view shows the tracks under the Difficulty and Theme rows as a carousel (`scripts/ui/track_picker.gd`): the tracks in one line, the track in the middle is the selected one. It is bigger and has a yellow border (REQ-GM-97) and, when the carousel has the focus, the black focus frame; the tracks at the sides get smaller and fainter, and the line slides (0.16 s) when it moves. A dot for each track is under the line, and the dot of the selected one is bigger. A track has no name. Tracks 1 to 10 are line sketches of the middle line of a track made from one of 10 fixed seeds (`MarbleTrack.FIXED_SEEDS`). The 11th is the random track: a question mark. The race uses a new random seed that is not one of the 10 fixed ones. With the focus on the carousel, Left and Right on the remote move the line by one track (it stops at the ends, REQ-GM-92); no OK is needed. Up goes to Difficulty, Down to Start. Track 1 is in the middle when the view opens the first time; later the last choice is in the middle (REQ-GM-94). | Done | smoke_settings |
| REQ-MR-54 | The track list is the only place where the track is chosen. The seed of the chosen track is part of `start_props`, so Try again (REQ-MR-33) plays the same track. The track name is shown during the race (REQ-MR-35). | Done | smoke_tv |
| REQ-MR-55 | The results menu has "Settings" (REQ-GM-95) in place of "Choose track". | Done | smoke_tv |
| REQ-MR-56 | Personal best (REQ-GM-98): the key is `marble_race|<difficulty>|<track 1 to 10>`, the value is the finish time in milliseconds, lower is better. A random track has no key and no best. | Done | smoke_bests |
| REQ-MR-57 | Each theme has scenery beside the road, made of pixel pictures with an outline: candy has big lollipops, candy canes, ice creams, donuts, cookies and wrapped sweets; space has rockets, ringed planets, UFOs, planets and stars; jungle has palm trees, bushes, hibiscus flowers, mushrooms and ferns. The pieces are placed from the track seed (the same track and theme always give the same scenery), on both sides, clear of the wall and of each other, and drawn under the obstacles and the cars. The scenery has no physics. | Done | game_rules (race look), Screenshot |

### Menus and flow

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-30 | The Games screen has one "Road Rally" tile. It opens the settings view (REQ-GM-90): Difficulty, Theme, the track list, Start and Back. Back returns to the grid with the tile in focus. | Done | smoke_settings |
| REQ-MR-31 | The results menu (`open_results()`, REQ-GM-72) names the winner and lists all cars: the finish times first, then the cars that did not finish (by distance). It has Try again, New game and Back to menu. Settings opens the settings view with the last choices. | Done | smoke_tv |
| REQ-MR-32 | The pause menu has Resume, Try again and End game (it leaves at once, REQ-GM-31). A player can leave a race at any time. | Done | smoke_tv (pause menu) |
| REQ-MR-33 | Try again keeps the track. | Done | smoke_tv |
| REQ-MR-34 | Back in the results leaves the game. | Done | smoke_tv |
| REQ-MR-14 | If all players leave during the race (their slots are freed: the hold of a paused game is over, REQ-GM-30a), a menu "No players connected" opens with "Back to menu". A lost phone first pauses the race with the card of REQ-GM-30. It is also what opens when the results are asked for after all players left. | Done | smoke_tv |
| REQ-MR-15 | The pad has no Recenter box in Road Rally (REQ-GM-37, issue #55); the pose held in the countdown is the center. | Done | smoke_tv |
| REQ-MR-35 | The name of the track is shown on the screen during the race. | Device | Device |

### View and look

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-40 | The view is flat, from above, and never turns. Up on the screen is toward the start of the track's first straight. A black bar at the top (112 px) holds the title, the timer, "Finish in N m" and the leader chip (REQ-GM-46). The timer box is at the place of every game (REQ-GM-47o): left edge at x 520 in English, right edge at x 1400 in Hebrew. | Device | Device |
| REQ-MR-41 | The camera has one zoom: 1 m is 32 screen units (8 world pixels). It follows the middle of the pack, a little below the middle of the free space, so that more road shows ahead (up) than behind. It sits on the world pixel grid, so the picture does not shimmer. When the pack is too spread out for the screen, the leader stays in view and the others get an arrow (REQ-MR-42). | Device | smoke_tv (the cars at the start), Device |
| REQ-MR-42 | A car that is out of view gets an arrow in its color at the screen edge (inside the 60 px margin and under the bar), and a text (32 px, for example "12 m behind") shows how many meters it is behind the leader. | Device | smoke_tv, Device |
| REQ-MR-43 | A car has a black outline (`#101018`) and its slot color. The outline of a car and the outline of an obstacle each differ from both tones of the road by 3:1 or more, in every theme (REQ-GM-47m: the dark outline is the edge of the key object, like the white ring of the maze balls). The HUD shows "Finish in N m" for the leader. | Device | game_rules (race look), smoke_tv, Device |
| REQ-MR-44 | Visual language (`docs/TV_FLOW.md`, FD-18, REQ-GM-47i to 47n). The world is a flat pixel world: `_pixel_world()` is true and the world is drawn into the 480x270 view. The ground is a chess board (a tile of 120x120 world pixels that repeats), the road, its two walls (7 world pixels thick, REQ-GM-47l) and the finish line are one picture of the whole track (`RaceLook.render()`), made once at the first frame by filling rows of pattern tiles (no pixel is tested one by one), and the game draws the window of the camera each frame. The finish line is two rows of black and white cells of 4 world pixels. The shell draws the HUD and the countdown at full resolution (a car has no number and no avatar: its color and the edge arrow tell the players apart, REQ-GM-46). The tile screenshot shows this look (Candy Road). Not a 3D game any more: `minigame_3d.gd` has no game left. | Device | game_rules (race look), smoke_tv, Screenshot (`tools/make_tiles.gd`), Device |
| REQ-MR-45 | Theme. The settings view has a row "Theme" with Candy Road, Space Rally and Jungle Run (values `candy`, `space`, `jungle`; the prop `race_theme`; default `candy`). The choice is kept for the next race (REQ-GM-94) and for Try again. An unknown value gives the default. The cars, the HUD and the physics are the same in every theme. | Done | run_tests, smoke_settings, smoke_tv |
| REQ-MR-46 | The theme gives the ground, the road, the walls and the three obstacles. Candy Road: pink chess ground with sprinkles, a cream road with pink dashes, candy cane walls, lollipops, gumdrops and cupcakes. Space Rally: a starry sky, a metal road of panels, glowing cyan walls, asteroids, satellites and craters. Jungle Run: dark green ground with grass, a dirt road with specks, leafy hedges, logs, boulders and tiki masks. An obstacle is 12 world pixels high or more (REQ-GM-47m), 1.8 m wide like the collision circle (`BUMPER_R`), and has a dark outline of its theme. The obstacles follow the track in turn, from a number made from the seed of the track, so a track has the same obstacles every time. | Device | game_rules (race look), smoke_tv, smoke_settings, Device |
| REQ-MR-47 | A wall stands out from the ground of its theme: the wall color or its outline differ from the ground by 3:1 or more. | Done | game_rules (race look) |
| REQ-MR-48 | A car is a picture of 11x16 world pixels (44x64 screen units) that points up, with the player color on the body (with a light and a shade), a white stripe, a windscreen, a rear window, headlights, tail lights and tires. It faces the way it moves, in steps of 15 degrees, and keeps its direction when it moves slower than 0.8 m/s. The physics circle is 0.6 m (`R`), a little narrower than the picture of the car, which has tires at its sides. | Done | smoke_tv, game_rules (race look) |
| REQ-MR-49 | The road and the walls are colored in the frame of the road, `u` along it and `v` across it (`RaceLook.pattern()`), so that a pattern turns with the road and is not cut in the same direction on the screen at every angle. The pattern goes on along the road across the pieces of the track. | Done | game_rules (race look), Screenshot |

## Parameters

In `scripts/game/marble_race/marble_race.gd` unless it says otherwise. Tune them on a device.

| Name | Value | Effect |
|------|-------|--------|
| `ACCEL` | 36 m/s² at tilt 1.0 | A tilt of 15 degrees gives about 9 m/s². |
| `DAMPING` | 1.0 /s | With 15 degrees, top speed is about 9 m/s. |
| `WALL_BOUNCE`, `BUMPER_BOUNCE`, `CAR_BOUNCE` | 0.45, 0.9, 0.85 | How lively the hits are. |
| `COUNTDOWN`, `END_DELAY` | 3 s, 4 s | Grid wait, and time for the others after the winner. |
| Track half-widths | `marble_track.gd` | Narrow tracks are harder. |

## Open questions

- Is a dead zone (like the maze, 0.03) or a speed limit needed? Test on a device.
- Are the target winning times right? Measure them in Test 9 and update the table.
- Is the edge arrow (REQ-MR-42) clear enough on a TV? Other options: a smaller car view, or pull the last car forward.
- Are the cars (64 px high) and the obstacles (about 52 px) big enough from the sofa? They are first guesses.
- The Hebrew title "ראלי כבישים" and the three theme names in Hebrew are first guesses (`assets/lang/strings.csv`): a Hebrew reader must check them.
- Should the best time of each track be saved? (The results show all finish times. Saving waits until players are identified.)

## Sound and haptics (REQ-GM-49a to 49c, REQ-GM-43)

The song `marble_race` plays from "GO": Fast and driving, 150 BPM, E minor. The countdown, pause and result sounds come from the base class.

| ID | Effect | When | Sound | Status |
|----|--------|------|-------|--------|
| REQ-MR-S1 | `marble_wall`, `marble_wall_hard` | A car hits a wall; the hard one above twice the buzz speed. | Clack, higher when harder | Device (test 18) |
| REQ-MR-S2 | `marble_bumper` | A car hits an obstacle. | Boing (pitch slide up) | Device (test 18) |
| REQ-MR-S3 | `marble_marble` | Two cars touch. | Lower clack | Device (test 18) |
| REQ-MR-S4 | `marble_finish` | A car crosses the line (haptic 120 ms). | Rising run | Device (test 18) |

Haptics on the phone of the player: Countdown end: 60 ms; Wall, obstacle or car hit above the buzz speed: 20 ms with a gap; Finish: 120 ms. An obstacle is a bumper: it plays `marble_bumper`.

## Languages (REQ-GM-47o)

The texts of this game are English and Hebrew: the title, the description, the hint and the result texts have a key and a Hebrew text in `assets/lang/strings.csv`. In Hebrew the HUD is mirrored by the shell (title, leader chip, timer); the finish text, the timer and the track name use `Shell.mx()`. The game world is not mirrored.
