# Bumper Cars (`bumper_cars`)

Type: 2D. Players: 2 to 4. Input: tilt (`PlayerInput.tilt()`). A and B do nothing.
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
Code: `scripts/game/bumper_cars/`, with the shared helper `scripts/game/tilt_body.gd`. Issue #99. Rules answered by the owner on
2026-10-23 ("as suggested", 2 players at least). Look approved by the owner on 2026-10-24 (mock: the Fun Fair, a steel floor in a
rink with black rubber rails and a red and white tent above, round-cornered cars with a black tyre bumper and a pole spark).

## Goal

Each player tilts a phone to drive a bumper car in a rink, like the ones at a fun fair. Gold stars lie on the floor: drive over a
star to pick it up. The cars bounce off each other and off the rubber rails. When two cars bump hard it is a bonk with a spark and a buzz,
and nobody loses a star (decision of the owner, 2026-10-29: players bump into each other just for fun). Nobody is out and nobody waits (REQ-GM-83). The player with the
most stars after 60 seconds wins. The game needs 2 players or more.

Registry entry: `description` (one line) and `tile` (`assets/tiles/bumper_cars.png`, made by `tools/make_tiles.gd`), see REQ-GM-7.
Visual language: shell, player colors, pixel world (REQ-GM-45 to 49). Check the tile next to the Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-98 | Exception | No personal best (no key in `ProfileKeys`): the result is a place, and a new key changes the profile code format. |
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 32). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |
| REQ-GM-81 to 84 | Note | Content: friendly toy cars, a bump is a funny bonk with a spark, nobody is hurt, nobody is out. Text is positive. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Round

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-BC-1 | A round has a countdown of 3 s and then 60 s of play (`RoundClock`). Cars do not move during the countdown. The visible clock shows the seconds left, in the same place as in the other games (REQ-GM-47o). At 0 the round ends and the result menu opens (REQ-BC-12). | Done | smoke_bumper_cars |
| REQ-BC-2 | At GO every phone recenters, so the pose held in the countdown is the center. The pad has no Recenter box and no A or B (REQ-GM-37, 37a, `pad: []`). | Done | smoke_bumper_cars |
| REQ-BC-3 | The cars start on a circle around the middle of the rink, spread evenly (REQ-GM-25), the first at the top, all at the same distance from the middle. | Done | bumper_rules |

Driving and bumping

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-BC-4 | Tilt moves a car (`TiltBody`: acceleration, dead zone, damping, speed limit). All players have the same values (REQ-GM-24). A car is a disk. The rail of the rink keeps the whole disk inside and gives a soft bounce (the car keeps 0.6 of its speed). | Done | smoke_bumper_cars |
| REQ-BC-5 | Cars bounce off each other (`TiltBody.collide`, restitution 0.9): they never overlap after a tick, and a hit pushes the other car away. | Done | smoke_bumper_cars |
| REQ-BC-6 | A bump is a hit when the speed of the two cars towards each other is at least 250 px/s. A hit buzzes both phones (25 ms, at most every 150 ms for one slot), plays the sound `car_bump`, and shows a spark where the cars met. A slower touch does nothing. | Device | bumper_rules, smoke_bumper_cars, audio_events, Device (the feel) (Test 32 step 12a) |
| REQ-BC-7 | A hit (REQ-BC-6) takes no star from any car and never changes a score (owner, 2026-10-29: it was one star from each car from 2026-10-24; REQ-GM-83). It only bonks: the spark, the buzz and the sound of REQ-BC-6. The same pair of cars cannot hit again for 0.6 s. | Done | bumper_rules, smoke_bumper_cars |
| Removed id | REQ-BC-8 was removed on 2026-10-29 (a hit drops no star, REQ-BC-7; `smoke_bumper_cars` checks it). The id is not used again. | Removed | - |

Stars

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-BC-9 | The floor has `stars` stars (see the table below). Whenever there are fewer, a new star appears every 0.6 s at a random place in the rink that is at least 120 px from every car and from the rail, and blinks for 0.4 s. A round starts with the full number. | Done | bumper_rules, smoke_bumper_cars |
| REQ-BC-10 | A car picks up a star when its middle is closer than 76 px to the star (the car radius and the star radius). The star goes away, the player gets 1 star in the score, the phone buzzes 15 ms, and the sound `car_star` plays. When two cars reach a star in the same tick, the nearer one gets it. A star is worth 1: a score is the number of stars. | Done | bumper_rules, smoke_bumper_cars |

Players, result and phones

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-BC-11 | A player who leaves takes the car out and keeps no stars in the ranking (REQ-GM-21). The stars of a leaving player are gone. When one player is left, the match ends at once with the result menu: a technical win with the gold medal (REQ-GM-73). When nobody is left the "No players connected" menu opens (REQ-GM-22). | Done | smoke_bumper_cars |
| REQ-BC-12 | At the end of the round the result menu is `open_results()` (REQ-GM-72): ranking, "X wins!" or "Tie!", Try again, Settings, Back to menu. The score text is "N stars". The winner gets a buzz of 400 ms. | Done | smoke_bumper_cars |
| REQ-BC-13 | A lost phone pauses the round with the card of REQ-GM-30. Nothing runs during the pause (the clock, the new stars, the cars). | Done | smoke_tv (shared base class) |
| REQ-BC-14 | The leader chip (`draw_leader_chip()`, REQ-GM-46) shows the leader and the stars of the leader, or TIE. Each phone shows its own stars and place (REQ-FL-67). A car has no number on it (REQ-GM-46). | Done | smoke_bumper_cars, hud_layout |
| REQ-BC-15 | Children (REQ-GM-80 to 84): friendly toy cars; a bump is a bonk and a spark; nobody is out and nobody waits (REQ-GM-83); there is a hint line in the first seconds ("Tilt to drive and pick up stars!"; text of the owner, 2026-10-29); all texts are positive. | Done | review, smoke_bumper_cars |

Look

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-BC-16 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n), drawn in `bumper_look.gd` in the 480x270 view: the **Fun Fair**. A dark violet backdrop (`#181028`) under the black bar of the HUD; a red and white striped tent roof with scallops above the rink; the rink is a floor of two greys (`#a6acba`, `#b0b6c4`) in squares of 6 world pixels, a red and a white ring in the middle; the rail is black rubber with white reflectors; the stars are gold (`#ffd640`) 9x8 pixel stars. A car is a 28x20 pixel sprite that faces the way it drives (4 directions, kept when it stops): a black tyre bumper with tread marks and a shine, a glossy body in the slot color with a lighter top and a darker bottom, a white racing stripe, a dark seat and a white steering wheel, two headlights, a chrome nose, and a pole at the back with a blue spark that flickers. The shadow is a dark copy of the car shape, 2 world pixels down and to the right. The outline of a car differs from the floor by 3:1 or more, and every slot color differs from the outline by 3:1 or more (REQ-GM-47m). All text is 32 px or larger (REQ-FL-40, issue #246) and inside the 60 px margin; the title is 32 px on one line, and where the name would touch the timer box, as in Hebrew, on two lines at 32 px (`Shell.title_wrapped()`, one `title` box for the HUD; nothing is cut or made smaller). | Device | review, bumper_rules (colors, car, stars), tiles, smoke_bumper_cars (the view), layout_menus, Device (Test 32 step 12b) |
| REQ-BC-17 | The layout comes from `size` (REQ-2D-2). It works at 1280x720 and 1920x1080: the simulation runs in 1920x1080 units and only the drawing is scaled. | Done | smoke_bumper_cars |

Settings (REQ-GM-90 to 97)

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-BC-20 | The settings view has the row Difficulty (registry `settings: []`), and `difficulty` is a prop of the game. The values are in the table below. Difficulty changes only the rink size and the number of stars on the floor; the speed of the cars and the time are the same. | Done | smoke_bumper_cars, bumper_rules |

| Difficulty | Rink size (share of the largest rink) | Stars on the floor |
|------------|---------------------------------------|--------------------|
| Easy | 100 % | 12 |
| Medium | 90 % | 9 |
| Hard | 80 % | 6 |

The largest rink is 1776 x 784 px. A car has a radius of 48 px.

## Parameters

Values that change how the game feels. Tune them on a device (Test 32). First values:

| Name | File | First value |
|------|------|-------------|
| `ACCEL`, `DAMPING`, `MAX_SPEED`, `DEADZONE` | `tilt_body.gd` | 2200 px/s2, 1.4 1/s, 560 px/s, 0.03 (the same as Paint Grab) |
| `ROUND_TIME`, `COUNTDOWN` | `bumper_cars_game.gd` | 60 s, 3 s |
| `CAR_R`, `PICKUP_R`, `RAIL_BOUNCE` | `bumper_rink.gd` | 48 px, 76 px, 0.6 |
| `HIT_SPEED`, `HIT_GAP` | `bumper_rink.gd` | 250 px/s, 0.6 s |
| `RESTITUTION` | `bumper_rink.gd` | 0.9 |
| `SPAWN_EVERY`, `SPAWN_CLEAR` | `bumper_rink.gd` | 0.6 s, 120 px |
| Levels | `bumper_rink.gd` | table above |

## Open questions

- Is 60 s long enough, and are 9 stars on the floor with 4 cars too few or too many?
- Should a car that has many stars be slower, so that the leader can be caught?

## Sound and haptics (REQ-GM-49a to 49c, REQ-GM-43)

The song `bumper_cars` starts at GO (REQ-GM-35): a bouncy fun-fair march at 126 BPM, C major. The countdown, pause and result sounds come from the base class.

| ID | Effect | When | Sound | Status |
|----|--------|------|-------|--------|
| REQ-BC-S1 | `car_bump` | Two cars hit (REQ-BC-6). | A rubber bonk with a zap | Device (test 18) |
| REQ-BC-S2 | `car_star` | A car picks up a star. | A short rising ding | Device (test 18) |

Haptics on the phone of the player: GO 60 ms; hit 25 ms; star 15 ms; match win 400 ms.

## Languages (REQ-GM-47o)

The texts of this game are English and Hebrew: the title, the description, the how-to text, the hint and the score text have a key and a Hebrew text in `assets/lang/strings.csv`. In Hebrew the HUD is mirrored by the shell (title, leader chip, timer). The game world is not mirrored.
