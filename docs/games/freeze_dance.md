# Freeze Dance (`freeze_dance`)

Type: 2D. Players: 1 to 4. Input: how much the phone moves (`PlayerInput.gyro` and `PlayerInput.accel`). No buttons.
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
Code: `scripts/game/freeze_dance/` (`dance_rules.gd` the rules, `dance_look.gd` the pictures, `freeze_dance_game.gd` the input, the
round and the drawing). Issue #97. Look approved by the owner on 2026-10-23 (mock v5: a disco floor of dark tiles with white light
tiles, seen from the edge of the stage, simple dancers of one color each, a mirror ball; `/mnt/project-files/freeze-dance/v5-storyboard.png`).

## Goal

The players stand in front of the TV with a phone in the hand. While the music plays everybody wiggles the phone and the dancers on
the TV dance. When the music stops and the floor lights go out, everybody must hold the phone still. A player who holds still gets
10 points; a player who moves sits out one song (about 10 s), keeps the points, and comes back for the next one. 6 songs; the
player with the most points wins. A child of 5 can play it: one hint line, big dancers, and a mistake takes nothing away.

Registry entry: `description` (one line), `how_to` and `tile` (`assets/tiles/freeze_dance.png`, made by `tools/make_tiles.gd`),
see REQ-GM-7. Visual language: shell, player colors, pixel world (REQ-GM-45 to 49). Check the tile next to the Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-35 | Exception | The game shows no timer, so it has no countdown: the first song starts at once after Start (the song of the game is the music of the dance). The clock is the number of songs. |
| REQ-GM-73 | Exception | One player gets no medal and the game has no medal tiers (owner, 2026-10-24, as Whack-a-Mole). With more players each row has the medal of its place (REQ-GM-73a). |
| REQ-GM-98 | Exception | No personal best (no key in `ProfileKeys`, as Whack-a-Mole): a new key changes the profile code format. Decision to confirm. |
| REQ-GM-102 | Note | Not a swing game, but the players wiggle a phone with energy, so the registry flag `swing` is set and the safety card shows. The wording of the TV line says "swing game": to confirm with the owner. |
| REQ-GM-37a | Note | The pad has no buttons (`pad: []`): the phone is only moved. |
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 29). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |
| REQ-GM-80 to 84 | Note | Content: friendly dancers on a disco floor. A move takes no points away (REQ-FD-8), the player who moves sits out for one song only (REQ-GM-83) and watches, and every text is positive. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Songs

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-FD-1 | A round has 6 songs. A song has three parts: the music (`music` seconds), the freeze (`freeze` seconds, REQ-FD-11) and a rest of 2 s with the lights still off. The music of each song lasts a random time between `music_min` and `music_max` (REQ-FD-11), drawn when the round starts from one `RandomNumberGenerator` (a test fixes it with `start_props.seed`; Try again keeps the seed, REQ-GM-32). The game starts at once with the music of the first song. After the rest of the 6th song the result menu opens (REQ-FD-9). | Done | dance_rules, smoke_freeze |
| REQ-FD-2 | The music is the song `freeze_dance` of `Sound`. It stops at once when the freeze starts (the player of the song is paused, not faded) and goes on from the same place when the next song starts. | Done | smoke_freeze, audio |
| REQ-FD-3 | The TV shows the part of the song: during the music the banner `WIGGLE!` (a short word, REQ-GM-84) and the floor lights; at the stop the banner `FREEZE!` and all lights go out (REQ-FD-12). The phones show nothing special: the stop is only on the TV (owner, 2026-10-24). The HUD shows `SONG n OF 6` in the place of the timer (REQ-GM-47o). | Done | smoke_freeze |

Dancing and holding still

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-FD-4 | The motion of a phone is `energy = |gyro| + 0.25 * |shake|` (rad/s and m/s2), smoothed with a time constant of 0.12 s. The shake is the raw acceleration minus its slow part (a low-pass with a time constant of 0.25 s, `DanceRules.Meter`): it needs no estimate of the direction of gravity, so a phone that was turned a moment ago does not read as moving. It does not depend on how the phone is held or where it points, so a loose grip and a phone held at any angle work the same (REQ-GM-24: all players have the same values). | Done | dance_rules |
| REQ-FD-5 | A player has danced in a song when the smoothed energy was at least `WIGGLE_MIN` (2.0) for 1.5 s in total during the music. The dancer on the TV dances (the arms go up and down, the body hops) while the energy of its phone is at least half of `WIGGLE_MIN`, and stands still otherwise, so the player sees the effect of the wiggle. | Done | dance_rules, smoke_freeze |
| REQ-FD-6 | In the freeze the player has `grace` seconds (REQ-FD-11) to stop. After that the player has moved when the smoothed energy is above `still_limit` (REQ-FD-11), at any moment up to the end of the freeze. It counts once per song. A player who sits out (REQ-FD-8) is not checked. | Done | dance_rules, smoke_freeze |
| REQ-FD-7 | A player who holds still through the freeze gets 10 points (`POINTS`), when they danced in that song (REQ-FD-5). A player who held still but did not dance gets nothing for that song, and nothing is taken away. The points come when the freeze ends, with `+10` in the color of the player above the dancer, a buzz of 40 ms on the phone (after the freeze, so the buzz cannot count as a move) and the effect `dance_points` with a pitch for each player. | Done | dance_rules, smoke_freeze |

Moving and sitting out

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-FD-8 | A player who moves in the freeze sits out one song (REQ-GM-83: about 10 s, the points stay, nothing is taken away). The mover leaves the floor at once and sits on the bench at the right bottom of the screen with its name and `BACK IN n` (the seconds until the start of the song where it plays again, rounded up; nothing when that song would be after the 6th). The mover buzzes 80 ms and the effect `dance_out` plays (a soft, funny `boop`, REQ-GM-81). In the next song the player watches; its phone is not checked and cannot score. In the song after that it dances again. When every player is out, the song goes on with an empty floor. | Done | dance_rules, smoke_freeze |
| REQ-FD-9 | The result menu is `open_results()` (REQ-GM-72) with a `Scoreboard` (higher is better): ranking, "X wins!" or "Tie!", Try again, New game, Back to menu. With one player at the start there is no medal (exception to REQ-GM-73); a round that starts with two or more players keeps the medals of the places also when players leave. A player who leaves takes the dancer and the bench plate away, and the round goes on. A lost phone pauses the round (REQ-GM-30). When the last player leaves, the menu "No players connected" opens (REQ-GM-22). The winner buzzes 400 ms. | Done | smoke_freeze |
| REQ-FD-10 | Personal best: no key (exception, see the first section). | Done | smoke_bests |

Difficulty (REQ-GM-91, 96)

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-FD-11 | The settings view has the row Difficulty only (registry `settings: []`), and `difficulty` is a prop of the game (REQ-GM-93). Difficulty changes the music, the freeze and the check, never the points. Easy is playable by a child of about 5 years: it has the shortest freeze, the most time to stop and the loosest check, and Hard has no penalty that Easy does not have (REQ-GM-96). First guesses, to tune on a device (Test 29), in `dance_rules.gd`, `LEVELS`: see the table below. | Done | dance_rules |

Look and feedback

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-FD-12 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n), drawn by `dance_look.gd`, seen from the edge of the stage: a dark hall with a mirror ball, a floor in perspective that runs away from the viewer in 8 rows of 16 columns, a wooden stage lip and two speakers at the bottom. The floor tiles are dark; light tiles are near white. During the music, in steps of 0.5 s, a new random set of tiles is lit all over the floor: a tile is lit with a probability of 35 %, never two tiles that share a side (corners may touch), and there is always at least one lit tile in each quarter of the floor. At the stop and in the rest no tile is lit. The dancers are simple: a head with two dots and a mouth, a cap and a body in the color of the slot, two arms and two legs, a black outline; the dancer is smaller when it stands farther away. Light and color do not hide a dancer: the dark floor and the white tiles both differ from every slot color. No number and no avatar on a dancer (REQ-GM-46); the name is on the chips and on the bench. Key objects are 48 px high or more (a dancer is 160 px or more). | Done | dance_rules (tiles), smoke_freeze, pixel_games, Screenshot |
| REQ-FD-13 | Dancers stand in the places of their slot: from 1 to 4 players, each count has its own places, near ones and far ones, so that nobody hides another (see `dance_look.gd`). A player who leaves does not change the places of the others. | Done | smoke_freeze |
| REQ-FD-14 | Haptics (REQ-GM-43, 49b): a move buzzes 80 ms, a held freeze buzzes 40 ms (REQ-FD-7), the winner 400 ms. No buzz at the stop or during the freeze, so that no phone is moved by its own buzz. Sounds: `freeze_stop` (the stop, a soft "record stop"), `dance_points` (a pitch for each player), `dance_out` and the song `freeze_dance`. All soft and friendly (REQ-GM-81). | Done | smoke_freeze, audio |
| REQ-FD-15 | Children (REQ-GM-80 to 84): friendly dancers, a move takes nothing away and means a short rest, nobody is out for more than one song, the hint is one line (`freeze_dance.hint`, the first 4 s of the first song), the dancers are large, the Easy freeze is 2 s with a long time to stop, and every text is positive. | Device | Review, Device (with a child, Test 29) |
| REQ-FD-16 | The layout comes from `size` (REQ-2D-2). It works at 1280x720 and 1920x1080: the pixel world scales with the screen, the HUD keeps its pixel size. | Done | smoke_freeze |

### Settings and difficulty

First guesses (`dance_rules.gd`, `LEVELS`), tuned on a device (Test 29):

| Difficulty | Music (s) | Freeze (s) | Grace (s) | `still_limit` |
|------------|-----------|-----------|-----------|---------------|
| Easy | 7 to 10 | 2.0 | 0.8 | 1.6 |
| Medium | 5 to 10 | 3.0 | 0.5 | 1.1 |
| Hard | 4 to 8 | 4.0 | 0.4 | 0.8 |

The freeze is longer on Hard because holding still is harder for longer; the music is shorter on Hard so the stop comes sooner.

## Parameters

| Name | First value |
|------|-------------|
| `SONGS`, `POINTS`, `REST` | 6, 10, 2 s |
| `WIGGLE_MIN`, `DANCE_NEED`, `SMOOTH` | 2.0, 1.5 s, 0.12 s |
| `ACCEL_WEIGHT` (the shake in the energy), `GRAVITY_TAU` | 0.25, 0.25 s |
| Light tiles: `LIT_SHARE`, step | 35 %, 0.5 s |
| `HINT_TIME` | 4 s |
| Levels | table above |

## Open questions

- Every threshold (`WIGGLE_MIN`, `still_limit`, the grace) is a first guess. A phone in a loose hand shakes more than one in a tight grip; the device test (Test 29) sets the values, also with a child of 5.
- A phone held in a hand has a tremor: if `still_limit` of Hard is too strict, loosen it.
- The safety card says "swing game" (see REQ-GM-102 above). Does the owner want a text of its own for a wiggle game?
- Personal best: a key per difficulty needs a new profile code format version. The owner decides.
- "Freeze Dance" is the working title; no trademark search has been done.
- The Hebrew texts were written by Claude and need a native reader.
