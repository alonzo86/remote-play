# Sheep Herding (`sheep_herding`)

Type: 2D. Players: 1 to 4. Input: tilt (`PlayerInput.tilt()`).
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
Code: `scripts/game/sheep_herding/` and the shared helper `scripts/game/tilt_body.gd`. Plan: issue #98, `docs/GAMES_ROADMAP.md`.
Mock: `/mnt/project-files/sheep-herding/` (approved by the owner on 2026-10-23).

## Goal

A team game. Each player tilts a phone to run a friendly **sheepdog** (a made-up dog in the color of the player) over a green
field with a pond, trees, hay stacks and a barn. The sheep keep away from a dog that comes close. Together the dogs herd the sheep
into the pen through its gate. The round ends when every sheep is in the pen or when the time is up. The score is the number of
sheep in the pen, and it belongs to the whole team (nobody beats another player). With one player the number of sheep is
shown as a score, with no medal; with 2 to 4 players every player has the gold medal (a shared score is a tie for 1st). A sheep in the pen stays there, nobody is out and nobody waits.

Registry entry: `description` (one line), `how_to` and `tile` (`assets/tiles/sheep_herding.png`, made by `tools/make_tiles.gd`), see
REQ-GM-7 and REQ-GM-103. Visual language: shell, player colors, toy-like world (REQ-GM-45 to 49).

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 29). It was run on a device (run R11; the Results table of the test has the steps). |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |
| REQ-GM-46 | Exception | The leader chip is the team chip: it shows the number of sheep in the pen out of all sheep (REQ-SH-13), in gray, because there is no leader. The phones show the same number and no place. |
| REQ-GM-72, 73 | Note | The score is shared, so every row of the result list shows the same number and the same place (1st), and with 2 to 4 players every row has the gold medal (REQ-GM-73a, REQ-SH-6). |
| REQ-GM-98 | Exception | No personal best (REQ-SH-20): the score belongs to the team, not to one profile. |
| REQ-GM-80 to 84 | Note | Content: friendly dogs and sheep, nobody is hurt, a scared sheep runs away and shows a few speed dashes, a calm sheep shows a heart or a sleepy "z". A sheep in the pen hops and a star pops. Nobody is out (REQ-SH-9). Text is positive. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Round

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SH-1 | A round has a countdown of 3 s and then the playing time of the difficulty (REQ-SH-17), `RoundClock`. The dogs cannot move during the countdown (REQ-GM-35). The clock is visible (`Shell.timer`). | Done | smoke_sheep |
| REQ-SH-2 | The dogs start at the left edge of the field, spread over its height (1 dog in the middle, 2 dogs at 30% and 70%, and so on). The pen is in the bottom right corner (REQ-SH-23), so the dogs are not at the same distance from the gate: the score is shared by the team, so no player has an advantage (REQ-GM-25 does not apply). The sheep start as a flock in the left middle of the field, apart from each other and from every scenery thing (REQ-SH-16). | Done | sheep_rules, smoke_sheep |
| REQ-SH-3 | The field, the pen, the barn and the things around (REQ-SH-16) come from the seed (`start_props.seed`; Restart keeps it), so a test can fix them. | Done | sheep_rules, smoke_sheep |
| REQ-SH-5 | The round ends when every sheep is in the pen, or when the time is up. When every sheep is in, the dogs and the sheep go on for 1.6 s with confetti over the pen, every phone buzzes 400 ms, and then the result opens (a win for the team: the sound `win`). When the time is up the result opens at once. | Done | smoke_sheep, sheep_rules |
| REQ-SH-6 | The result menu is `open_results()` (REQ-GM-72): the list of the players with "N / M sheep", Try again, New game, Back to menu. With 2 to 4 players the title is "All sheep are safe!" or "N of M sheep are safe!" and every row has the gold medal (the score is shared, so all players tie for 1st, REQ-GM-73a); with one player the title is the difficulty and the row has no medal (REQ-SH-18). | Done | smoke_sheep |

Sheep

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SH-4 | A sheep (a circle of 28 px radius, 72 x 56 px on the screen) walks through the barn and the silo, the fence of the pen and the edge of the grass (REQ-SH-22): it slides along them and keeps a little of its speed. A dog is blocked the same way. The pond, the rocks, the trees, the pines, the hay stacks, the bales, the bushes and the flowers are only scenery (decoration): they never block a dog or a sheep and never change how it moves (owner request of 2026-11-17, issue #469). The sheep and the dogs still start clear of them (REQ-SH-2, REQ-SH-16). | Done | sheep_rules, smoke_sheep |
| REQ-SH-7 | A free sheep keeps away from a dog that is closer than the flee radius (REQ-SH-17): it accelerates away from every dog in range, the harder the closer the dog is, up to the run speed of the difficulty. Several dogs add up. A sheep that is cornered at the edge slides along it. Dogs do not touch or push a sheep. A scared sheep is also helped toward the gate by the difficulty (REQ-SH-21). | Done | sheep_rules, smoke_sheep |
| REQ-SH-8 | A sheep that no dog is near grazes: it walks slowly (at most 45 px/s) for a moment in a random direction, then stands, and chooses again. It is pulled weakly (40 px/s2) toward the middle of the free sheep that are closer than 340 px, so the flock stays together. Two sheep do not overlap. | Done | sheep_rules |
| REQ-SH-9 | Children (REQ-GM-80 to 84): the dogs and the sheep are friendly made-up creatures, nothing is hurt or caught, a scared sheep only runs, no player is out and no player waits, the hint is one line, the dogs are slower than the blob of Paint Grab and the speed is the same for all players, and all texts are positive. A player who leaves takes the dog out, and the round goes on with the others (REQ-GM-21); when nobody is left the "No players connected" menu opens (REQ-GM-22). | Done | smoke_sheep |
| REQ-SH-10 | A sheep whose middle goes through the gate into the pen is in the pen for good (the fence is yellow for 0.5 s, a star pops over it, it hops once). It no longer runs from dogs; it grazes inside the pen, slowly, and cannot leave. The pen holds all the sheep of Hard (14). The number of sheep in the pen is the score of every player (REQ-SH-5). | Done | sheep_rules, smoke_sheep |
| REQ-SH-11 | Dogs (`TiltBody`): tilt gives the acceleration, with a dead zone, damping, a speed limit of 440 px/s and a soft bounce at the edge (the values of Paint Grab, REQ-PG-7, with the lower speed limit). All players have the same values (REQ-GM-24). Dogs bounce off each other softly, with one sound for one touch. | Done | sheep_rules, smoke_sheep, Device (feel) (Test 29 steps 10a to 10c) |

Players and feedback

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SH-12 | Sounds and haptics (REQ-GM-43, 49a to 49c): GO buzzes every phone (60 ms). When a sheep walks into the pen, the dog that last scared it (the nearest dog when it was last scared) buzzes 40 ms (at most every 150 ms for one slot, `Haptics`). The end with all sheep in buzzes every phone 400 ms. The effects are in the table *Sound and haptics*. | Done | smoke_sheep, audio_events, Device (the buzz) (Test 29 steps 10d, 10e) |
| REQ-SH-13 | The team chip (REQ-GM-46, in place of the leader chip) shows "N / M" and is updated at every change. Each phone shows the same "N / M" and no place (REQ-FL-67). In Hebrew it reads "N / M" too, N at the left, on the chip, on the phone and in the result row (REQ-FL-54a, issue #480). | Done | smoke_sheep, hud_layout, ratio_order |
| REQ-SH-14 | A lost phone pauses the round with the card of REQ-GM-30. The clock does not run during the pause. The pad has no RECENTER box and no A or B (REQ-GM-37, 37a): the pose held in the countdown is the center. | Done | smoke_tv (shared base class), Device (the pad) (Test 29 steps 10f, 10g) |

Look

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SH-15 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n), drawn in the 480x270 view: a black screen, the grass `#2f8f3a` with a one-pixel black line and darker tufts, a path of sand dots to the gate, the pen (sand, a brown fence, yellow gate posts), flat colors, a one-pixel black outline on every thing. A dog is 20 x 14 world pixels (80 x 56 px): the body is the color of the player (no number and no avatar on it, REQ-GM-46), with a cream muzzle, belly and paws, a dark ear, a white collar, a pink tongue and a tail. It looks the way it moves (left or right). A sheep is 18 x 14 world pixels (72 x 56 px): white wool, a dark face and legs. A calm sheep has a heart or a sleepy "z" over it (52 px up); a running sheep has three speed dashes behind it (46 to 78 px behind). The whole picture of a heart or a "z" and every dash is inside the grass, at any window size, also when the sheep is at an edge or in a corner: no part of it is on the black margin, on the HUD bar or past the grass edge (owner decision of 2026-11-18, option (a), issue #485). At an edge the heart or the "z" is moved down or sideways so that the whole picture is on the grass (at the top edge it is drawn on the back of the sheep). The three dashes are drawn only when all three, at their places behind the sheep (46, 62 and 78 px), are whole inside the grass and none is on the body of the sheep (the 28 px circle of its body); when one is not, none of the three is drawn (owner decision of 2026-11-18: hide them at an edge; they are never moved or squeezed). In the middle of the field the look does not change. All text is 32 px or larger and inside the 60 px margin. | Device | review, sheep_edges, smoke_sheep, Device (Test 29 steps 10h and 11e) |
| REQ-SH-16 | Around the field (REQ-GM-47i to 47n): the barn with a gambrel roof, a hayloft window, double doors with white crosses, a stone base, a weather vane and a silo (at the left end of the pen, on its top), a pond, 7 round trees, 4 pines, 3 hay stacks, 2 piles of bales, 3 rocks, 6 bushes and 28 flowers. They are scattered over the whole field, also in the middle. The whole picture of every thing (the pond ellipse of 240 x 128 px with its black line, the crown of a tree, a pine, a hay stack, a pile of bales, a rock, a bush, a flower) is inside the grass, at least 8 px from its edge, at any window size: no part of it is on the black margin, on the HUD bar or past the grass edge, and none is drawn over the pen or the barn (owner retest of 2026-11-18, issue #479). The place of a thing is tested by its whole picture, not by its foot. The places that must stay open are kept free of things (a dog or a sheep never starts on one, though nothing blocks them, REQ-SH-4): the start strip of the dogs (280 px), the start of the sheep, the way from the flock to the gate (300 px wide) and the pen. A thing that finds no room is left out. Things are drawn in order from the back to the front, and the dogs and the sheep are drawn over them so that no sheep is hidden behind a crown. | Done | sheep_rules, smoke_sheep |
| REQ-SH-19 | The layout comes from `size` (REQ-2D-2): the world is simulated and drawn in design units (1920x1080) and scaled to `size`; the field is the screen inside the 60 px margin and under the HUD. It works at 1280x720 and 1920x1080. | Done | smoke_sheep |

Settings (REQ-GM-90 to 97)

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SH-17 | The settings view has the row Difficulty (registry `settings: []`), and `difficulty` is a prop of the game. The values are in the table below. The number of dogs does not change them: the field is the same with 1 or 4 dogs. | Done | smoke_sheep, sheep_rules |
| REQ-SH-18 | One player: the result shows the number of sheep in the pen at the end and no medal (REQ-GM-73, issue #119); the title of the result is the difficulty. | Done | smoke_sheep, sheep_rules |
| REQ-SH-21 | Help toward the gate (issue #469). While a dog scares a sheep, a part of its flee force turns toward the middle of the gate. The part is the `assist` of the difficulty: Easy 0.8, Medium 0.45, Hard 0 (no help). The help is added to the push away from the dog and scaled the same way (the closer the dog, the more). It never points toward a dog: the part of the way to the gate that points at the dog is dropped, so a dog in front makes the sheep slide to the side. A sheep that no dog scares gets no help, and a sheep in the pen is not helped. All players have the same help (REQ-GM-24). | Done | sheep_rules |
| REQ-SH-22 | Nothing leaves the grass (owner request of 2026-11-17). Every dog and every sheep stays on the grass, the whole picture of it (a dog 80 x 56 px, a sheep 72 x 56 px), never on the black margin around the field, at every tick and in every code path that moves it: the tilt, the bounce at the edge, the flee and the help toward the gate, the push between two sheep, the bounce between two dogs, and the walls of the pen and the barn. The middle of a dog stays at least 40 px from the left and right edge and 30 px from the top and bottom edge; the middle of a sheep at least 36 px from the left and right edge and 28 px from the top and bottom. A dog or a sheep is never inside a wall more than 1 px (a bounce between two dogs at a wall or an edge does not push one into it), and when the nearest way out of a wall would leave the grass, the nearest way that stays on the grass is taken. Sheep in the pen stay inside it (REQ-SH-24). The barn is a wall with its whole picture (REQ-SH-24). The picture is drawn on the place of the simulation, also when it looks left: a picture that is turned around fills the same box as one that is not (issue #478: a sheep or a dog that looked left was drawn one picture width, 72 or 80 px, too far right, over the barn or off the grass). The heart, the "z" and the speed dashes of a sheep are inside the grass too (REQ-SH-15, issue #485). | Done | sheep_edges, sheep_rules, smoke_sheep |
| REQ-SH-23 | The pen is in a corner and no sheep can get stuck (owner request of 2026-11-17). The pen is 292 x 360 px in the bottom right corner of the grass, flush with the right and the bottom edge, with the gate in the middle of its left side (so the gate faces the open field, away from the HUD and from the black margin). The barn stands on the top of the pen, flush with the right edge, and its silo is at the left end of the pen: the barn, the silo and the pen are one block with no ledge and no gap. The collision of the barn is its whole picture (REQ-SH-24). Rule that no sheep gets stuck, measured: (a) no gap between two things (a piece of the fence, the barn, the silo, an edge of the grass) is wider than 0.5 px and narrower than a sheep (56 px) unless a third thing closes it; (b) the places where the middle of a sheep can stand are one region that is reached from the gate (no closed pocket); (c) in a simulation of 300 rounds with random dogs, with dogs that hug every edge and every corner, with a dog that pushes one sheep along every edge, fence and wall from 8 sides, and with 24 flocks that a herding dog drives toward the gate and then leaves, no sheep is ever in a wall (more than 1 px) or off the grass, and at the end every sheep is in the pen or free in the open (not in a wall). Rule (a) is a proxy for a place where a sheep can wedge, it does not prove that a sheep got stuck; the check of the owner's problem (a sheep held at a wall) is the manual step 11b of Test 29. The old layout (the pen 52 px from the right edge, the barn 32 px above it) FAILS rule (a) with 9 gaps and fails REQ-SH-22 in 298 of 300 rounds; the simulation did not find a sheep stuck in a wall on the old layout. The alcove between the top of the barn wall, the silo and the edge that this requirement left open is closed by REQ-SH-24 (issue #476: sheep and a dog stood on the roof and went on to the black margin). | Done | sheep_edges, smoke_sheep |
| REQ-SH-24 | The barn blocks, and the pen holds its sheep (owner request of 2026-11-18, issue #476). (a) The collision of the barn is its whole picture: the roof, from the tip of the weather vane (14 world pixels above the walls) to the foot of the walls, the walls, and the silo with its cap, as two boxes: the barn box (3 world pixels left of the walls to the right edge of the roof, from the vane to the stone base) and the silo box (the silo and its cap down to the foot of the walls). No sheep and no dog is on the roof, beside the vane or on the silo, from any side; the barn picture and the collision have no part where the picture is open, and the box of the barn is flush with the right edge of the grass, so nothing reaches the black margin there. (b) A sheep that is in the pen stays in the pen: at every tick its middle is kept inside the pen box (the inside of the fence, less the radius of the sheep), also when a free sheep at the gate pushes it, when it bounces at a wall and when it walks. It never leaves through the gate, a dog cannot send it out (a dog never pushes a sheep anyway, REQ-SH-7), and it stays counted. (c) A sheep is in the pen, and counted, when its middle is inside the pen box (the same box as in (b), so a sheep that has just walked in does not jump); it is counted once: the event "penned" is one for each sheep and the score is the number of sheep in the pen (REQ-SH-6, REQ-SH-13), which never goes down in a round. The gate, the scoring and the end of the round are as before. The old code failed both rules in a simulation: 310 places where a sheep could stand on the picture of the barn, a dog put on the barn, and a penned sheep that was outside the pen box. | Done | sheep_edges, sheep_rules, smoke_sheep |
| REQ-SH-20 | Personal best (REQ-GM-98): exception, no key (`best_key()` is empty). The result is shared by the team, so it does not belong to the profile of one player. | Done | smoke_bests |

| Difficulty | Sheep | Flee radius | Run speed | Gate | Time | Help toward the gate |
|------------|-------|-------------|-----------|------|------|----------------------|
| Easy | 8 | 220 px | 230 px/s | 220 px | 90 s | 0.8 |
| Medium | 11 | 260 px | 270 px/s | 180 px | 75 s | 0.45 |
| Hard | 14 | 300 px | 320 px/s | 150 px | 60 s | 0 |

A dog is faster than the fastest sheep for most of a run (440 px/s against 320 px/s), but a sheep that is scared from the front runs
away from the pen, so the dogs have to come from the right side. On Easy and Medium the help (REQ-SH-21) bends the run of a scared sheep toward the gate, so a dog that comes from the side still sends the sheep roughly the right way.

## Parameters

Values that change how the game feels. Tune them on a device (Test 29). First values:

| Name | File | First value |
|------|------|-------------|
| `COUNTDOWN`, the time of a round | `sheep_herding_game.gd` | 3 s; 90, 75 and 60 s (table above) |
| `DOG_R`, `DOG_SPEED`, `ACCEL`, `DAMPING`, `DEADZONE`, `BOUNCE` | `sheep_herding_game.gd` / `tilt_body.gd` | 30 px, 440 px/s, 2200 px/s2 for tilt 1.0, 1.4 1/s, 0.03, 0.35 |
| `RADIUS`, `FLEE_ACCEL`, `DAMPING`, `GRAZE_SPEED`, `COHESION_R`, `COHESION_ACCEL`, `SCARED_TIME`, `SCARED_AT` | `sheep_flock.gd` | 28 px, 2600 px/s2, 2.5 1/s, 45 px/s, 340 px, 40 px/s2, 0.7 s, 0.25 |
| The levels, `assist` | `sheep_herding_game.gd`, `sheep_flock.gd` | table above (assist 0.8, 0.45, 0) |
| The pen, the gate, the barn | `sheep_herding_game.gd` (`layout()`, `PEN_SIZE`) | pen 292 x 360 px in the bottom right corner, a gate of 150 to 220 px in the middle of its left side, the barn on the pen (REQ-SH-23, REQ-SH-24) |
| The things around the field | `sheep_scenery.gd` | counts in REQ-SH-16 |
| `END_DELAY`, `GLOW_TIME`, `BAA_GAP` | `sheep_herding_game.gd` | 1.6 s, 0.5 s, 0.6 s |

## Open questions

- Is the time right (90, 75 and 60 s)? Can one child of 5 herd 8 sheep alone on Easy?
- Do the sheep run too far or too fast? (The pen is in a corner, a sheep cannot wedge, nothing is on the barn and a penned sheep stays in, REQ-SH-23, REQ-SH-24; Test 29 steps 11a to 11c check it with the phones.)
- Is the help right: strong enough on Easy that a child herds without planning, and still a game on Medium? (Test 29)
- Is the gate easy to find from the sofa, and is 150 px on Hard too narrow?
- Should a sheep that is out of the pen after the round go on grazing (it does) or should the result show the sheep that were left out?
- No trademark search was done for the name (classes 9 and 41). "Sheep Herding" is plain words.

## Sound and haptics (REQ-GM-49a to 49c, REQ-GM-43)

The song `sheep_herding` plays from "GO": calm and bouncy, 100 BPM, C major. The countdown, pause and result sounds come from the base class.

| ID | Effect | When | Sound | Status |
|----|--------|------|-------|--------|
| REQ-SH-S1 | `sheep_baa` | A free sheep gets scared (at most one every 0.6 s). | Two soft falling beeps | Device (test 18) |
| REQ-SH-S2 | `sheep_pen` | A sheep walks into the pen (haptic 40 ms on the dog that scared it last, REQ-SH-12); also at the confetti. | Three rising notes | Device (test 18) |
| REQ-SH-S3 | `sheep_bump` | Two dogs touch (one sound for one touch). | Soft low blip | Device (test 18) |

Haptics on the phone of the player: Countdown end: 60 ms; a sheep walks into the pen: 40 ms with a gap, on one dog; every sheep in: 400 ms on every phone.

## Languages (REQ-GM-47o)

The texts of this game are English and Hebrew: the title, the description, the how-to line, the hint and the result texts have a key
and a Hebrew text in `assets/lang/strings.csv`. In Hebrew the HUD is mirrored by the shell (title, team chip, timer). The game world is not mirrored.
The Hebrew texts were written by Claude and need a reader whose language is Hebrew.
