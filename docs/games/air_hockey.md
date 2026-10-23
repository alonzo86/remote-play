# Air Hockey (`air_hockey`)

Type: 2D. Players: 1 to 4 phones connected, 2 seats. Input: tilt (`PlayerInput.tilt()`), A (enroll).
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84), the rules for bots (REQ-GM-105)
and for enrolling (REQ-GM-106). Exceptions are in the first section.
Code: `scripts/game/air_hockey/` (`air_hockey_game.gd`, the rules and the physics in `air_hockey_sim.gd`, the pictures in
`air_hockey_look.gd`, the bot in `hockey_bot.gd` on the base class `scripts/game/bot.gd`), with the shared body `scripts/game/tilt_body.gd`.
Issues: #101 (the game), #102 (bots). Mock: `/mnt/project-files/screens/air-hockey/v5-1-play-vs-bot.png` (approved 2026-10-23).

## Goal

Two players face each other across an air hockey table. Each tilts a phone to slide a round mallet in its own half and hits a black
puck at the other goal. The first to the number of goals of the setting (3 to 10, 5 at the start) wins. With one phone the other
seat is **ROBO**, a computer player (the first bot of the app, REQ-GM-105). The players enroll in the game at every start by pressing A.

Registry entry: `description` (one line) and `tile` (`assets/tiles/air_hockey.png`, made by `tools/make_tiles.gd --only=air_hockey`),
see REQ-GM-7. Visual language: shell, player colors, pixel world (REQ-GM-45, 46, 47i to 47n, 48, 49). Check the tile next to the
Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-73 | Exception | A match against ROBO has no medal tiers and no medal (decision of the owner, 2026-10-23). A match of two phones gives the medal of the place (gold, silver). |
| REQ-GM-98 | Exception | No personal best (`best_key()` is empty): the score is the goals of a match against one opponent, so it says little about the player. Decision to confirm. |
| REQ-GM-35 | Exception | The game shows no timer, so it has no countdown. The match starts when the second phone has enrolled (or at once with one phone), and the puck waits 1 s for the serve. |
| REQ-GM-104 | Exception | There is no IN and OUT choice: the game enrolls its players itself (REQ-GM-106, registry `enroll`). |
| REQ-GM-30 | Exception | The card of a lost phone never offers "Resume without ..." once the match runs: the match cannot go on without a player (REQ-AH-19). |
| REQ-GM-47d, 47e, 47m | Exception | Decision of the owner, 2026-10-23: the table is white with black rails (as a real table), and the puck is black. The mallets keep the slot colors with a black outline, and the puck and the table differ by more than 3:1 in luminance. |
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 27). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |
| REQ-GM-80 to 84 | Note | Content: friendly toy mallets and a puck, nothing is hurt. A goal takes nothing away from anybody (REQ-AH-9), nobody is out, the Easy bot is beatable by a child of 5 (REQ-AH-17), the hint is one line, and every text is positive (ROBO "wins" the same way a player does). |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Match and players

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-AH-1 | A match has two seats: seat 0 on the left, seat 1 on the right. The first seat to reach the goals of the setting (REQ-AH-18) wins. There is no timer and no draw during play. | Done | smoke_air_hockey |
| REQ-AH-2 | The game starts with 1 to 4 phones connected (registry `min_players` 1, `max_players` 4). Two phones play; the other phones watch (their pad says "waiting", REQ-GM-106). | Done | smoke_air_hockey |
| REQ-AH-3 | Enrollment (REQ-GM-106): at every start of a match (also Try again and New game) a screen says "PRESS A TO PLAY!" and every connected phone may press A. The first phone that presses stands on the left, the second on the right, and the match starts at once. A phone that is already enrolled does nothing when it presses A again. With one phone connected it is enrolled at once and the match starts against ROBO. With two or more phones connected and one enrolled, the screen also says "OR PRESS OK TO PLAY AGAINST ROBO", and OK on the TV remote starts the match against ROBO. OK with nobody enrolled does nothing. Back leaves at once (nothing is in progress). Nobody can join after the match started. | Done | smoke_air_hockey |
| REQ-AH-4 | Tilt moves the mallet of the seat (`TiltBody`: acceleration 5200 px/s2, damping 5 /s, speed limit 1100 px/s). Tilt to the right slides to the right and tilt forward slides up, for both seats (nobody is mirrored; the left player defends the left goal). Both seats have the same values (REQ-GM-24). The pose held at the start of the match is the center. B does nothing. | Done | air_hockey_rules, smoke_air_hockey |
| REQ-AH-5 | A mallet stays in its own half of the table (it stops at the middle line) and inside the rails. | Done | air_hockey_rules |

Puck, rails and goals

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-AH-6 | The puck is a disk. A mallet that overlaps it pushes it away along the line between them: the speed of the mallet is added (a mallet that moves fast hits hard), and the puck leaves at 420 px/s at least, so it never sticks to a mallet. The puck never speeds up beyond 1800 px/s. A long frame is split in steps of 1/120 s at most, so the puck cannot go through a mallet. | Done | air_hockey_rules |
| REQ-AH-7 | The puck slows down by itself (damping 0.35 /s: about a third in 1 s) and bounces off the rails keeping 92 % of the speed. | Done | air_hockey_rules |
| REQ-AH-8 | Each short side has a goal opening 280 px high in the middle. A puck whose whole disk is over the goal line inside the opening is a goal for the other seat. A puck beside the opening bounces off the rail. | Done | air_hockey_rules |
| REQ-AH-9 | After a goal the scorer gets 1 goal, the phone of the scorer buzzes (120 ms), a banner "GOAL FOR <NAME>!" shows for 2 s with the puck still, and then the mallets go back to their start places and the puck waits 1 s on the side of the seat that conceded (the puck is served to the one who was scored on). Nothing is taken away from anybody. | Done | smoke_air_hockey, air_hockey_rules |
| REQ-AH-10 | The match ends when a seat reaches the goals of the setting. Two phones: `open_results()` ranks both (REQ-GM-72): "<NAME> wins!", "1st NAME 5 goals", "2nd NAME 3 goals", with the medals of the places (REQ-GM-73). Against ROBO: the same menu with both rows (ROBO has the color of its seat and no avatar), no medal (exception above), "<NAME> wins!" or "ROBO wins!", the win sound when the phone won and the neutral sound when ROBO won. The winner phone buzzes 400 ms. The buttons are Try again, New game and Back to menu. Score text: "N goals" ("1 goal"). | Done | smoke_air_hockey |
| REQ-AH-11 | The leader chip (REQ-GM-46) and the place and score on each phone (REQ-FL-67) work with two phones. Against ROBO the phone gets no place (a place of one player would say nothing), and the two chips under the table show the score. | Done | smoke_air_hockey |
| REQ-AH-12 | A hit that sends the puck away faster than 450 px/s buzzes the phone of the mallet (25 ms, at most every 150 ms) and plays `hockey_hit`. A rail hit above 450 px/s plays `hockey_wall`. A goal plays `hockey_goal`. Enrolling buzzes the phone (40 ms) and plays `join`. The song `air_hockey` plays from the start of the play (no countdown). | Done | smoke_air_hockey, audio |

ROBO (REQ-GM-105)

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-AH-13 | ROBO is added automatically, and only, when one phone plays (one phone connected, or the TV remote started the match with one enrolled phone). It takes the right seat. It is never added when two phones play. There is no setting to turn it on or off. | Done | smoke_air_hockey |
| REQ-AH-14 | ROBO is a body like a phone player: it gives a tilt (`PlayerInput.tilt()` is what a phone gives), and its mallet moves with the same `TiltBody` and the same table rules (REQ-GM-24). It sees the puck `reaction` seconds late and cannot tilt farther than `max_tilt`. | Done | air_hockey_rules |
| REQ-AH-15 | ROBO has the name "ROBO" (`air_hockey.bot_name`) and its own color, purple `#a678e6`, which no phone slot has. Its chip under the table has no avatar. It has no personal best and no medal. | Done | smoke_air_hockey |
| REQ-AH-16 | The brain defends: it waits in front of its goal and moves to where the puck will cross its line (a line that bounces off a rail is folded). A slow puck on its half is attacked: it goes behind the puck, seen from the other goal, and then through it, aiming at the other goal with an error of `aim_error` px. A puck that stays slow on its half for `idle` seconds is always attacked (nobody else can reach it). A new puck on its half is attacked with the probability `attack`. | Done | air_hockey_rules |
| REQ-AH-17 | Difficulty (REQ-GM-91) changes only the skill of ROBO (REQ-GM-96): see the table in Parameters. Easy is beatable by a child of about 5 years: a player that only chases the puck with a soft tilt scores at least 3 times as many goals as ROBO on Easy (headless proxy, 4 matches of 3 minutes), and Hard beats that player clearly. The mallet of the player is the same on every level. | Done | air_hockey_rules (the proxy), Device (a child, Test 27) |

Settings, leaving and look

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-AH-18 | The settings view has Difficulty and **Goals to win** (3 to 10, 5 at the start; props `difficulty` and `goals`; the row stops at 3 and at 10). The line under the name is `how_to.air_hockey`. There is no IN and OUT (REQ-GM-106). | Done | smoke_air_hockey |
| REQ-AH-19 | A lost phone pauses the match (REQ-GM-30): nothing runs. The card has End game, and Resume only when every player is connected again; it never offers "Resume without ...". A player that left for good (its slot was freed, REQ-GM-30a) ends the match: the result menu names the player that stays as the winner, with no medal. Against ROBO, when the only phone leaves, "No players connected" opens (REQ-GM-22). Before the match starts, a leave only changes who can enroll; with one phone left it is enrolled at once. | Done | smoke_air_hockey |
| REQ-AH-20 | Look (mock v5): a white table with rounded corners and black rails with silver corner caps on the blue of the arcade set (`#1b3a8a`); a red dashed middle line, a blue center circle with a red dot, blue lines at the thirds, blue goal creases, red face-off circles and dots; the goal openings are gaps in the rails. A mallet has a black outline, a base in the slot color with a darker lower edge, a groove, a knob with a shine and a soft shadow; the puck is black with a bevel, a darker top and a shine. All of it is drawn in the 480x270 pixel view (REQ-GM-47i). | Done | smoke_air_hockey (the view), Device (the look, Test 27) |
| REQ-AH-21 | HUD: the title (REQ-GM-45), "FIRST TO N" in the place of the timer (REQ-GM-47o), one chip under each goal with the color square, the name (the avatar when the player has one) and the goals, the leader chip with two phones, the goal banner (72 px) in the middle, and one hint line "TILT TO SLIDE YOUR MALLET AND HIT THE PUCK!" for 6 s at the start. The table is not mirrored in Hebrew (the world is not mirrored, REQ-GM-47o); the HUD text is. All text is 32 px or larger and inside the 60 px margin. | Done | smoke_air_hockey, hud_layout |
| REQ-AH-22 | Personal best (REQ-GM-98): none (`best_key()` is empty), see the exception above. | Done | smoke_bests |

## Parameters

Values that change how the game feels. All are first guesses; tune them on a device (Test 27).

| Value | Where | First value |
|-------|-------|-------------|
| Table, goal opening, puck and mallet radius | `air_hockey_sim.gd` `RINK`, `GOAL_H`, `PUCK_R`, `PADDLE_R` | 1680x728 px, 280, 34, 60 |
| Mallet: acceleration, damping, speed limit | `PADDLE_ACCEL`, `PADDLE_DAMPING`, `PADDLE_MAX` | 5200 px/s2, 5 /s, 1100 px/s |
| Puck: damping, top speed, rail keep, hit keep, least hit speed | `PUCK_DAMPING`, `PUCK_MAX`, `WALL_KEEP`, `HIT_KEEP`, `MIN_HIT` | 0.35 /s, 1800 px/s, 0.92, 0.9, 420 px/s |
| Serve wait, goal banner | `SERVE_WAIT`, `GOAL_BANNER` | 1.0 s, 2.0 s |
| Hit buzz speed and length | `HIT_BUZZ_SPEED`, `_on_hit()` | 450 px/s, 25 ms |

What Easy, Medium and Hard mean (`hockey_bot.gd` `LEVELS`; only ROBO changes, REQ-GM-91, 96):

| Level | Reaction (s) | Max tilt | Aim error (px) | Defend error (px) | Attacks a new puck | Slow puck speed (px/s) | Idle before it attacks (s) |
|-------|--------------|----------|----------------|-------------------|--------------------|------------------------|----------------------------|
| Easy | 0.5 | 0.35 | 250 | 260 | 30 % | 260 | 2.0 |
| Medium | 0.3 | 0.5 | 200 | 110 | 50 % | 520 | 1.2 |
| Hard | 0.07 | 1.0 | 60 | 25 | 95 % | 900 | 0.5 |

In the headless proxy (a player that only chases the puck, 4 matches of 3 minutes) the player scored 54, 3 and 2 goals and ROBO 1, 4 and 26
goals on Easy, Medium and Hard.

## Open questions

- The tuning values above, from Test 27. In particular: is the Easy ROBO too passive (it scored 1 goal in 12 minutes against the proxy) and is the Medium ROBO right for a grown-up?
- The decisions the owner gave in short form on 2026-10-23: "every match start, 2 players need to enroll" is built as REQ-AH-3 (the first two phones that press A; with one phone, or OK on the remote with one enrolled, ROBO plays). A player that leaves for good ends the match (REQ-AH-19). Confirm both.
- No personal best (exception above).
- The chips show the name and the number of goals on one line ("MAYA 2"), not the two lines of the mock ("MAYA" and "GOALS 2").
- Hebrew texts (12 new rows) are written by Claude: a native reader checks them, in particular the name "רובו" and "שער של %s!".
