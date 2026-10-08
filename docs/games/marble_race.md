# Marble Race (`marble_race`)

Type: 3D. Players: 1 to 4. Input: tilt (`PlayerInput.tilt()`), Recenter.
General requirements: `docs/GAME_REQUIREMENTS.md`. Code: `scripts/game/marble_race/`.

## Goal

Each player tilts a phone to roll a marble along a winding track. The first marble over the finish line wins.
Marbles bounce off the walls, the posts and each other.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-62 | Gap | `docs/DEVICE_TEST.md` has a section for this game (Test 9). It is not yet run on a device. |
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
| REQ-MR-10 | The order is: finished marbles by time, then the others by distance along the track. | Done | smoke_tv (standings) |
| REQ-MR-11 | A player who leaves is removed from the race. The race continues with the others. | Done | smoke_tv |
| REQ-MR-12 | A phone that is lost pauses the race while another player is connected (general REQ-GM-30). | Done | smoke_tv (maze, same base class) |
| REQ-MR-13 | The haptic events are: GO (60 ms), a hit at 3 m/s or faster (20 ms, at most every 150 ms), crossing the finish line (120 ms). | Done | Device |

### Tracks

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-20 | A track is a line of points with one half-width. The drivable area is all points within the half-width of the line. | Done | run_tests |
| REQ-MR-21 | The tracks are Classic, Sprint, Zigzag and Gauntlet. Each has a different character (see the table below). | Done | run_tests |
| REQ-MR-22 | Each track starts with a straight of 8 m or more toward the top of the screen. | Done | run_tests |
| REQ-MR-23 | A track does not touch itself. | Done | run_tests |
| REQ-MR-24 | The finish line is 6 m before the end of the track. Posts end 8 m before the end of the track. | Done | run_tests |
| REQ-MR-25 | A new track needs: an id in `MarbleTrack.IDS`, a case in `MarbleTrack.make()`, and a variant in the registry. A test checks all three agree. | Done | run_tests |

| Track | Length | Width | Posts | Winning time (target) |
|-------|--------|-------|-------|-----------------------|
| Classic | about 143 m | 6.8 m | 9 | 20 to 30 s |
| Sprint | about 92 m | 8.0 m | 4 | 12 to 20 s |
| Zigzag | about 190 m | 5.8 m | 0 | 30 to 45 s |
| Gauntlet | about 160 m | 9.2 m | 15 | 25 to 40 s |

The lengths are measured (`MarbleTrack.length`). The winning times are targets, from a top speed of about 9 m/s. They are not measured on a device yet. See "Open questions".

### Menus and flow

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-30 | The Games screen has one "Marble Race" tile. It opens the track list. A track starts the race. Back from the list returns to the grid with the tile in focus. | Done | smoke_tv |
| REQ-MR-31 | The results menu has Restart, Choose track and Back to menu. Choose track opens the track list. The current track is marked. | Done | smoke_tv |
| REQ-MR-32 | The pause menu has Resume, Restart and Back to menu. It has no Choose track. A player can leave a race at any time. | Done | smoke_tv (pause menu) |
| REQ-MR-33 | Restart keeps the track. | Done | smoke_tv |
| REQ-MR-34 | Back in the track list of the results returns to the results. Back in the results leaves the game. | Done | smoke_tv |
| REQ-MR-14 | If all players leave during the race, a menu "No players connected" opens with "Back to menu". | Done | smoke_tv |
| REQ-MR-15 | The Recenter button of the phone zeroes the tilt of that player in the race. | Done | smoke_tv |
| REQ-MR-35 | The name of the track is shown on the screen during the race. | Done | Device |

### Camera and look

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-MR-40 | The camera looks down from above and slightly from behind. It never turns. Up on the screen is toward the start of the track's first straight. | Done | Device |
| REQ-MR-41 | The camera follows the middle of the pack and moves higher when the marbles are far apart (16 m to 48 m). | Done | Device |
| REQ-MR-42 | All marbles stay in view while they are 55 m or less apart along the screen. Beyond that, an arrow in the color of the marble shows at the screen edge, and a number shows how many meters it is behind the leader. | Done | smoke_tv, Device |
| REQ-MR-43 | The track floor, the edge, the posts, the finish line and the marbles have clear and different colors. Marbles use the slot color. The posts use a grey that is not a slot color. | Done | smoke_tv (post color), Device |
| REQ-MR-44 | Visual language (`docs/TV_FLOW.md`, FD-14, REQ-GM-47). The marbles and the posts are outlined spheres and cylinders (inverted-hull mesh, `add_outlined_mesh`). The track floor is purple `#472aa3`, the rim is the dark outline color, the finish line is a checkered band of boxes, the background is teal `#0f6a78`. The shell draws the HUD and the countdown. The tile screenshot shows this look. | Done | Screenshot (`tools/make_tiles.gd`), Device |

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
- Should the results show all finish times, and should the best time of each track be saved?
