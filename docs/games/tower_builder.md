# Tower Builder (`tower_builder`)

Type: 2D. Players: 1 to 4. Input: A (drop the brick).
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
Code: `scripts/game/tower_builder/` (`tower_builder_game.gd`, the rules of the tower in `tower_stack.gd`, the pictures in `tower_look.gd`).
Issue: #96 (it was called Wobbly Tower; the owner chose the name Tower Builder on 2026-10-23). Mock: `/mnt/project-files/screens/wobbly-tower/v2-1.png` (the look was approved on 2026-10-23).

## Goal

All players build one tall tower together, one brick at a time, in turns (decision of the owner, 2026-10-23). A brick swings on a
crane over the tower, and the player whose turn it is presses A to drop it. A brick that lands and stays is a point for its player.
A brick that lands too far out can make the top of the tower topple: it wobbles, the bricks fall off with a giggle, and the game goes
on with the lower tower. Nobody loses a point for a fall. 12 bricks are dropped in all, shared by the players in turns. Alone, a
player gets a medal for the number of bricks that stayed.

Registry entry: `description` (one line) and `tile` (`assets/tiles/tower_builder.png`, made by `tools/make_tiles.gd --only=tower_builder`),
see REQ-GM-7. Visual language: shell, player colors, pixel world (REQ-GM-45, 46, 47i to 47n, 48, 49). Check the tile next to the
Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-35 | Exception | The game has no round clock, so it has no 3 s countdown: the first turn starts at once after Start. The turn time of the difficulty (REQ-TB-11) is shown in the timer box, in the place of the timer of the other games, but it limits one drop and is not a game clock. Decision to confirm. |
| REQ-GM-83 | Note | The game is turn-based, so a player waits for the other players. Decision of the owner, 2026-10-24: the limit is about 20 s per turn, not for all the turns of the others together. One turn takes at most the turn time plus about 2 s for the fall and the pause (12 s on Easy, 7 s on Medium, 5 s on Hard), so every turn is under 20 s. The waiting players watch the tower, nobody is out, and nothing is taken away. |
| REQ-GM-98 | Exception | No personal best (`best_key()` is empty): the tower is a team result, and a player's bricks depend on the others. Decision to confirm. |
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 28). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |
| REQ-GM-80 to 84 | Note | Content: soft colored bricks and a friendly crane. A fall is funny ("CRASH! GIGGLE!", REQ-TB-9), it takes no point away from anybody (REQ-TB-14), nobody is out, a child gets 10 s a turn on Easy (REQ-TB-11), the hint is one line, and every text is positive. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Game and turns

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TB-1 | All players build one shared tower on one base (decision of the owner, 2026-10-23). The game works with 1 to 4 phones (registry `min_players` 1, `max_players` 4) and has no teams and no opponent. | Done | smoke_tower |
| REQ-TB-2 | Play starts at once after Start, with no countdown (REQ-GM-35 exception). The song starts with the play. The pose of the phone is centered at the start of each turn (REQ-GM-37). | Done | smoke_tower |
| REQ-TB-3 | 12 bricks are dropped in all (`TOTAL_BRICKS`): a brick that misses counts, a brick that topples counts. After the 12th brick has landed and the banner is over, the result menu opens (REQ-GM-72). 12 divides by 1, 2, 3 and 4, so every player has the same number of turns. | Done | smoke_tower |
| REQ-TB-4 | The players take turns in slot order, one brick each. The turn passes to the next player after the brick has landed and the pause of the result is over (0.6 s after a brick that stayed, 1.0 s after a miss, 1.8 s after a topple). | Done | smoke_tower |
| REQ-TB-5 | In its turn a brick swings on a crane over the tower, a smooth swing of 380 px to each side of the middle of the tower, one full swing in 2.4 s (`Stack.swing_x`). A press on A of the phone of the turn lets the brick fall (the speed is 1400 px/s). A of any other phone does nothing, and B does nothing. A brick has a width from 170 to 250 px in steps of 10 px (REQ-TB-10) and is 48 px high. | Done | tower_rules, smoke_tower |

The tower

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TB-6 | A brick lands on the top brick (or on the base) when the two overlap by 24 px or more (`MIN_OVERLAP`). When they overlap by less, the brick misses: it falls beside the tower, lies on the grass, the tower does not change, and a banner says "WHOOPS! IT MISSED!". A miss takes nothing away (REQ-GM-83). | Done | tower_rules, smoke_tower |
| REQ-TB-7 | The rule of the tower is the same for every brick and every player (REQ-GM-24) and has no random number: a joint holds when the middle of the weight of all bricks above it (the widths count as weights) is over the brick below it, or over the base for the first brick. At the lowest joint that does not hold, all the bricks above it fall. So a brick that falls can knock off other bricks, also the ones of earlier turns (decision of the owner, 2026-10-23: simple, but one brick can knock off others). | Done | tower_rules |
| REQ-TB-8 | A joint holds a little beyond the edge of the brick below: the middle of the weight may be 8 px outside it (`SLACK`), so that a drop that is almost right stays. The number is a first guess. | Device | tower_rules (the number), Device (the feel) |
| REQ-TB-9 | A topple (REQ-TB-7): the tower wobbles for 0.7 s (the higher a brick, the more it leans, in steps of the world pixel), the banner "CRASH! GIGGLE!" shows, and then the bricks above the weak joint, the new brick included, slide off the base to the side that each one leans to and lie on the grass (at most 24 lie there). All phones buzz. The bricks that are left stay. The player whose brick toppled gets no point for it, and nobody loses a point that was already given (REQ-GM-83). The game goes on with the lower tower, no restart. | Done | tower_rules, smoke_tower |
| REQ-TB-10 | The widths of the bricks come from a seeded random generator (`seed_value` in the tests, a random seed in play), so that a test plays the same bricks every time. | Done | tower_rules |

Time, players and points

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TB-11 | Difficulty (REQ-GM-91) is the time a player has for a drop (decision of the owner, 2026-10-23): Easy 10 s, Medium 5 s, Hard 3 s. The swing and the bricks are the same on all three. The time left shows in the timer box (REQ-GM-47o, in the place of the timer of the other games). When the time is over, the brick drops by itself where it hangs. The game has no other setting. | Done | tower_rules, smoke_tower |
| REQ-TB-12 | A player who leaves is taken out of the turns and off the board (REQ-GM-21). When it was the turn of that player, the next player gets a new brick and the full turn time at once; a leaver whose brick is falling does not make the next player lose a turn. When nobody is left the "No players connected" menu opens (REQ-GM-22). A lost phone pauses the game with the card of REQ-GM-30; the time of the turn and the swing stop (REQ-GM-30). | Done | smoke_tower, smoke_tv (shared base class) |
| REQ-TB-13 | Haptics (REQ-GM-43): the phone whose turn starts buzzes 100 ms; a drop 30 ms; a brick that stays 60 ms; a miss 40 ms; a topple 80 ms on every phone (at most one buzz every 150 ms for a phone). A buzz never carries information alone. | Device | Device (the buzzes) |
| REQ-TB-14 | A brick that lands and stays gives its player 1 point, and the point is never taken away (REQ-GM-83, REQ-GM-70): the points are the bricks that stayed at the moment they landed. The leader chip shows the leader and the points, or TIE (REQ-GM-46). Each phone shows its place and its points (REQ-FL-67). The chip row under the tower has one chip for each player with the points; the chip of the player of the turn has a white frame. | Done | smoke_tower |
| REQ-TB-15 | The result menu is `open_results()` with the points (REQ-GM-72): the title names the winner or says "Tie!", the rows have the medal of the place (REQ-GM-73a), and the score text is "N BRICKS" ("1 BRICK"). One player gets the medal of the points: bronze 6, silver 9, gold 11 (`MEDAL_TIERS`, the same at all three difficulties; REQ-GM-73, REQ-GM-95). The numbers are a first guess. | Done | smoke_tower, tower_rules |
| REQ-TB-16 | Children (REQ-GM-80 to 84): see the first section. Easy gives a child 10 s for one drop and the swing is slow (one swing in 2.4 s). | Device | Device (Test 28 items 9a to 9d) |
| REQ-TB-17 | The pad of the phone shows the button A alone (registry `pad: ["a"]`, REQ-GM-37a). | Done | run_tests |

Look and sound

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-TB-18 | Look (REQ-GM-47i to 47n, REQ-GM-48, mock of 2026-10-23): a sunny valley drawn in the pixel view: a banded sky from blue to cream, a sun, drifting clouds, snowy mountains, green hills, trees, striped grass with flowers; a wooden base; a crane with a rope; soft bricks in the slot colors with a light top, a dark bottom and a black outline (48 px high); a height ruler at the right with a tick for each of the 12 levels, filled up to the height of the tower. There is no number and no avatar on a brick (REQ-GM-46). The black background colors of the shell are used only for the HUD bar. | Done | tiles (the tile), Device (Test 28 item 11) |
| REQ-TB-19 | HUD: the title "TOWER BUILDER" at the top left; the turn time in the timer box; the plate "<NAME>'S TURN" in the color of the player and the plate "BRICK n OF 12" at the left of the tower; the leader chip; one chip for each player at the bottom, in one row inside the 60 px margin, or in two rows of two when four long names do not fit in one row; one banner in the middle (the miss and the topple); the hint "WAIT FOR YOUR TURN. PRESS A TO DROP THE BRICK!" at the start (6 s). All text is 32 px or more (REQ-GM-41) and mirrors in Hebrew (REQ-GM-47o); the world is not mirrored. | Done | hud_layout, smoke_tower (the chips) |
| REQ-TB-20 | Sound (REQ-GM-49a): the song `tower_builder` (D major, 116 bpm, light drums) and the effects `tower_drop`, `tower_land`, `tower_miss`, `tower_wobble` and `tower_crash`. | Done | audio |
| REQ-TB-21 | Personal best (REQ-GM-98): no key (exception, see the first section). | Done | smoke_bests |

## Parameters

Values that change how the game feels. Tune them on a device (Test 28). All are first guesses.

| Value | File | First value |
|-------|------|-------------|
| Bricks in a game | `tower_stack.gd` `TOTAL_BRICKS` | 12 |
| Turn time Easy, Medium, Hard | `tower_stack.gd` `TURN_TIMES` | 10, 5, 3 s |
| Swing: reach and time of one swing | `tower_stack.gd` `SWING_AMP`, `SWING_PERIOD` | 380 px, 2.4 s |
| Brick: height, widths | `tower_stack.gd` `BRICK_H`, `WIDTH_*` | 48 px, 170 to 250 px |
| Overlap to land, slack of a joint | `tower_stack.gd` `MIN_OVERLAP`, `SLACK` | 24 px, 8 px |
| Medal tiers (solo) | `tower_stack.gd` `MEDAL_TIERS` | 6, 9, 11 |
| Fall speed, wobble time, pauses | `tower_builder_game.gd` | 1400 px/s, 0.7 s, 0.6 / 1.0 / 1.8 s |

## Open questions

For the owner (the answers of 2026-10-23 are used for all the rest):

1. The end of the game: the owner did not say when it ends, so it ends after 12 bricks (REQ-TB-3). Is that the number you want?
2. Points: a brick that stays is a point for its player, and a topple takes nothing (REQ-TB-14). The tower height is not a score. Do you want the final height of the tower on the result menu too?
3. REQ-GM-35 (no countdown) is a decision to confirm.
4. Medal tiers 6, 9 and 11 of 12 for one player are guesses.
5. No trademark search has been done for "Tower Builder".
6. The id was changed from `wobbly_tower` (roadmap) to `tower_builder` with the name.
