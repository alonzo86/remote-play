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
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 29). It is not yet run on a device. |
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
| REQ-SH-2 | The dogs start at the left edge of the field, spread over its height (1 dog in the middle, 2 dogs at 30% and 70%, and so on), all at the same distance from the pen. The sheep start as a flock in the left middle of the field, apart from each other and from every blocker (REQ-SH-4). | Done | sheep_rules, smoke_sheep |
| REQ-SH-3 | The field, the pen, the barn and the things around (REQ-SH-16) come from the seed (`start_props.seed`; Restart keeps it), so a test can fix them. | Done | sheep_rules, smoke_sheep |
| REQ-SH-5 | The round ends when every sheep is in the pen, or when the time is up. When every sheep is in, the dogs and the sheep go on for 1.6 s with confetti over the pen, every phone buzzes 400 ms, and then the result opens (a win for the team: the sound `win`). When the time is up the result opens at once. | Done | smoke_sheep, sheep_rules |
| REQ-SH-6 | The result menu is `open_results()` (REQ-GM-72): the list of the players with "N / M sheep", Try again, New game, Back to menu. With 2 to 4 players the title is "All sheep are safe!" or "N of M sheep are safe!" and every row has the gold medal (the score is shared, so all players tie for 1st, REQ-GM-73a); with one player the title is the difficulty and the row has no medal (REQ-SH-18). | Done | smoke_sheep |

Sheep

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SH-4 | A sheep (a circle of 28 px radius, 72 x 56 px on the screen) walks through nothing: not through a blocker (the pond, a rock, a tree, a hay stack or bales), the barn and the silo, the fence of the pen or the edge of the field. It slides along them and keeps a little of its speed. A dog is blocked the same way, so a dog cannot park inside a tree or the pond. Bushes and flowers are only drawn. | Done | sheep_rules, auto_sheep |
| REQ-SH-7 | A free sheep keeps away from a dog that is closer than the flee radius (REQ-SH-17): it accelerates away from every dog in range, the harder the closer the dog is, up to the run speed of the difficulty. Several dogs add up. A sheep that is cornered at the edge slides along it. Dogs do not touch or push a sheep. | Done | sheep_rules, auto_sheep |
| REQ-SH-8 | A sheep that no dog is near grazes: it walks slowly (at most 45 px/s) for a moment in a random direction, then stands, and chooses again. It is pulled weakly (40 px/s2) toward the middle of the free sheep that are closer than 340 px, so the flock stays together. Two sheep do not overlap. | Done | sheep_rules |
| REQ-SH-9 | Children (REQ-GM-80 to 84): the dogs and the sheep are friendly made-up creatures, nothing is hurt or caught, a scared sheep only runs, no player is out and no player waits, the hint is one line, the dogs are slower than the blob of Paint Grab and the speed is the same for all players, and all texts are positive. A player who leaves takes the dog out, and the round goes on with the others (REQ-GM-21); when nobody is left the "No players connected" menu opens (REQ-GM-22). | Done | smoke_sheep |
| REQ-SH-10 | A sheep whose middle goes through the gate into the pen is in the pen for good (the fence is yellow for 0.5 s, a star pops over it, it hops once). It no longer runs from dogs; it grazes inside the pen, slowly, and cannot leave. The pen holds all the sheep of Hard (14). The number of sheep in the pen is the score of every player (REQ-SH-5). | Done | sheep_rules, smoke_sheep |
| REQ-SH-11 | Dogs (`TiltBody`): tilt gives the acceleration, with a dead zone, damping, a speed limit of 440 px/s and a soft bounce at the edge (the values of Paint Grab, REQ-PG-7, with the lower speed limit). All players have the same values (REQ-GM-24). Dogs bounce off each other softly, with one sound for one touch. | Device | sheep_rules, smoke_sheep, Device (feel) |

Players and feedback

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SH-12 | Sounds and haptics (REQ-GM-43, 49a to 49c): GO buzzes every phone (60 ms). When a sheep walks into the pen, the dog that last scared it (the nearest dog when it was last scared) buzzes 40 ms (at most every 150 ms for one slot, `Haptics`). The end with all sheep in buzzes every phone 400 ms. The effects are in the table *Sound and haptics*. | Device | smoke_sheep, audio_events, Device (the buzz) |
| REQ-SH-13 | The team chip (REQ-GM-46, in place of the leader chip) shows "N / M" and is updated at every change. Each phone shows the same "N / M" and no place (REQ-FL-67). | Done | smoke_sheep, hud_layout |
| REQ-SH-14 | A lost phone pauses the round with the card of REQ-GM-30. The clock does not run during the pause. The pad has no RECENTER box and no A or B (REQ-GM-37, 37a): the pose held in the countdown is the center. | Device | smoke_tv (shared base class), Device (the pad) |

Look

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SH-15 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n), drawn in the 480x270 view: a black screen, the grass `#2f8f3a` with a one-pixel black line and darker tufts, a path of sand dots to the gate, the pen (sand, a brown fence, yellow gate posts), flat colors, a one-pixel black outline on every thing. A dog is 20 x 14 world pixels (80 x 56 px): the body is the color of the player (no number and no avatar on it, REQ-GM-46), with a cream muzzle, belly and paws, a dark ear, a white collar, a pink tongue and a tail. It looks the way it moves (left or right). A sheep is 18 x 14 world pixels (72 x 56 px): white wool, a dark face and legs. A calm sheep has a heart or a sleepy "z" over it; a running sheep has three speed dashes behind it. All text is 32 px or larger and inside the 60 px margin. | Device | review, smoke_sheep, Device |
| REQ-SH-16 | Around the field (REQ-GM-47): the barn with a gambrel roof, a hayloft window, double doors with white crosses, a stone base, a weather vane and a silo (above the pen), a pond, 7 round trees, 4 pines, 3 hay stacks, 2 piles of bales, 3 rocks, 6 bushes and 28 flowers. They are scattered over the whole field, also in the middle, and the places that must stay open are kept free of blockers: the start strip of the dogs (280 px), the start of the sheep, the way from the flock to the gate (300 px wide) and the pen. A thing that finds no room is left out. Things are drawn in order from the back to the front, and the dogs and the sheep are drawn over them so that no sheep is hidden behind a crown. | Done | sheep_rules, smoke_sheep |
| REQ-SH-19 | The layout comes from `size` (REQ-2D-2): the world is simulated and drawn in design units (1920x1080) and scaled to `size`; the field is the screen inside the 60 px margin and under the HUD. It works at 1280x720 and 1920x1080. | Done | smoke_sheep |

Settings (REQ-GM-90 to 97)

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-SH-17 | The settings view has the row Difficulty (registry `settings: []`), and `difficulty` is a prop of the game. The values are in the table below. The number of dogs does not change them: the field is the same with 1 or 4 dogs. | Done | smoke_sheep, sheep_rules |
| REQ-SH-18 | One player: the result shows the number of sheep in the pen at the end and no medal (REQ-GM-73, issue #119); the title of the result is the difficulty. | Done | smoke_sheep, sheep_rules |
| REQ-SH-20 | Personal best (REQ-GM-98): exception, no key (`best_key()` is empty). The result is shared by the team, so it does not belong to the profile of one player. | Done | smoke_bests |

| Difficulty | Sheep | Flee radius | Run speed | Gate | Time |
|------------|-------|-------------|-----------|------|------|
| Easy | 8 | 220 px | 230 px/s | 220 px | 90 s |
| Medium | 11 | 260 px | 270 px/s | 180 px | 75 s |
| Hard | 14 | 300 px | 320 px/s | 150 px | 60 s |

A dog is faster than the fastest sheep for most of a run (440 px/s against 320 px/s), but a sheep that is scared from the front runs
away from the pen, so the dogs have to come from the right side.

## Parameters

Values that change how the game feels. Tune them on a device (Test 29). First values:

| Name | File | First value |
|------|------|-------------|
| `COUNTDOWN`, the time of a round | `sheep_herding_game.gd` | 3 s; 90, 75 and 60 s (table above) |
| `DOG_R`, `DOG_SPEED`, `ACCEL`, `DAMPING`, `DEADZONE`, `BOUNCE` | `sheep_herding_game.gd` / `tilt_body.gd` | 30 px, 440 px/s, 2200 px/s2 for tilt 1.0, 1.4 1/s, 0.03, 0.35 |
| `RADIUS`, `FLEE_ACCEL`, `DAMPING`, `GRAZE_SPEED`, `COHESION_R`, `COHESION_ACCEL`, `SCARED_TIME`, `SCARED_AT` | `sheep_flock.gd` | 28 px, 2600 px/s2, 2.5 1/s, 45 px/s, 340 px, 40 px/s2, 0.7 s, 0.25 |
| The levels | `sheep_herding_game.gd` | table above |
| The pen, the gate, the barn | `sheep_herding_game.gd` | pen 320 x 360 px at the right, a gate of 150 to 220 px |
| The things around the field | `sheep_scenery.gd` | counts in REQ-SH-16 |
| `END_DELAY`, `GLOW_TIME`, `BAA_GAP` | `sheep_herding_game.gd` | 1.6 s, 0.5 s, 0.6 s |

## Open questions

- Is the time right (90, 75 and 60 s)? Can one child of 5 herd 8 sheep alone on Easy?
- Do the sheep run too far or too fast? Do they get stuck in the corners or behind a tree?
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
