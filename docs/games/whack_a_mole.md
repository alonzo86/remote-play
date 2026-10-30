# Whack-a-Mole (`whack_a_mole`)

Type: 2D. Players: 1 to 4. Input: pointer (`PlayerInput.pointer()`), A (bonk), Recenter.
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84). Exceptions are in the first section.
Code: `scripts/game/whack_a_mole/`. Issue #100. Look approved by the owner on 2026-10-23 (mock: a meadow with a fence, 9 holes
in a 3 x 3 grid, friendly brown moles, a golden crown mole as the bonus).

## Goal

Each player points a phone at the TV like a remote control. A ring in the player color follows the phone. Friendly moles pop out
of 9 holes in a meadow. A press on A bonks the mole under the ring: it closes its eyes, smiles, sparkles and goes down. All players
play on the same holes; the first bonk that lands on a mole gets its points. The player with the most points after 60 seconds
wins. A miss costs nothing. The simplest game of the set: a child of 5 can play it.

Registry entry: `description` (one line) and `tile` (`assets/tiles/whack_a_mole.png`, made by `tools/make_tiles.gd`), see REQ-GM-7.
Visual language: shell, player colors, pixel world (REQ-GM-45 to 49). Check the tile next to the Games screen.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-73 | Rule | One player gets no medal (owner, 2026-10-23, issue #66; the general rule since issue #119). The result shows the points. With more players each row has the medal of its place (REQ-GM-73a). |
| REQ-GM-98 | Gap | No personal best (no key in `ProfileKeys`): the game has no best yet. Decided 2026-10-30 by agents under CLAUDE.md (the owner can revert): it gets one, `whack_a_mole|<difficulty>`, the points of the player, higher is better, keys 43 to 45; planned (issue #216), because the points are a personal score that compares between rounds (as Banana Party). |
| REQ-GM-37 | Note | Recenter is on the pad, as in Banana Party: the pointer uses the yaw of the gyroscope, and yaw drifts (RISKS A4). |
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 28). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |
| REQ-GM-80 to 84 | Note | Content: friendly moles, a funny bonk with no hammer and no pain. A miss costs nothing (REQ-WM-5). No player is out of the round. Text is positive. |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Round

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-WM-1 | A round has a countdown of 3 s and then 60 s of play (`RoundClock`). Rings move during the countdown, but a press does nothing. The visible clock shows the seconds left. At 0 the round ends and the result menu opens (REQ-WM-13). | Done | smoke_mole |
| REQ-WM-2 | At GO every phone recenters, so the pose held in the countdown is the center of the screen. The Recenter button works during the round. A and B: only A is used. | Done | smoke_mole |

Aim and bonk

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-WM-3 | The ring of a player is at `pointer()` mapped to the play area with `PointerMap` (`scripts/game/pointer_map.gd`), the same as Banana Party (REQ-SS-3): -1 is the left or top edge, +1 the right or bottom edge. The play area is the screen inside the 60 px margin, under the HUD. The ring stays inside it. | Done | game_rules, smoke_mole |
| REQ-WM-4 | A press on A (an edge: `button_pressed`) bonks at the place of the ring at that moment, at once (no flight). Holding A does not repeat. A press does nothing while the game is paused, in the countdown, or after the round. A player can bonk again after 0.3 s (reload); a press inside the reload time is ignored. Presses are handled in the order they arrived, not in slot order (REQ-GM-24). | Done | smoke_mole |
| REQ-WM-5 | A miss costs nothing: no points are lost, the player does not wait longer, and the ring does not change. A press that hits no mole makes a small poof where it landed. | Done | smoke_mole |

Moles and score

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-WM-6 | The meadow has 9 holes in a 3 x 3 grid (the middles of the columns at 1/6, 3/6 and 5/6 of the play area width, the rows at 0.30, 0.62 and 0.94 of its height, at 1920x1080 reference pixels). A mole comes up from an empty hole: it rises in 0.25 s, stays up for `stay` seconds (REQ-WM-9), and goes down in 0.25 s. A hole has at most one mole. A mole that goes down by itself is not a loss. | Done | game_rules |
| REQ-WM-7 | A bonk hits a mole when the place of the ring is inside the head circle of the mole (radius 100, 84 or 72 px at Easy, Medium or Hard, plus 12 px, see the table below) and the mole is more than half out of its hole (rising, up, or going down). When two moles are hit, the one with the nearer center. A hit mole is taken: its points go to the player, it cannot be hit again, it stays 0.8 s in a short happy animation (REQ-WM-11) and then it is gone. A mole that is hit while it rises or sinks stays where it is and comes fully out in 0.15 s (no jump). The first press in the order of arrival wins a mole; a later press on it is a miss. A score never goes down. | Done | game_rules, smoke_mole |
| REQ-WM-8 | A normal mole is worth 10 points. The golden mole (a crown) is worth 50 and stays up for 70 % of `stay`. The first golden mole comes after 10 s of play, then every 14 to 22 s. | Done | game_rules |
| REQ-WM-9 | A new mole comes every `spawn_every` seconds while fewer than `max_base` + the number of players moles (not counting the golden one), at most 6, are out. The time between two moles also runs while the field is full: a hole that frees is not filled at once, and moles never come in a burst. The first mole comes at once. The moles are the same for all players. Everything comes from one `RandomNumberGenerator`; a test can fix it with `start_props.seed`; without a seed a new round has new moles. Try again keeps the seed that was given (REQ-GM-32). | Done | game_rules |

Look and feedback

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-WM-10 | Visual language (REQ-GM-45 to 49). The world is a pixel world (REQ-GM-47i to 47n), drawn by `mole_look.gd`: a sunny meadow with a blue sky and a sun, a wooden fence, flecks of grass, 9 dark holes with a lip of dirt in front. A mole is a pixel picture with a one-pixel black outline (brown fur, pink nose, two eyes); the golden mole is yellow with a crown. A mole comes out from behind the lip of its hole (the part that is still inside is cut). The ring is a dark 4 px edge and 2 px in the player color, 40 px radius, no badge and no number (REQ-GM-46). Every key object is 48 px high or more at 1920x1080. The title, timer (`Shell.TIMER_X`), leader chip, countdown, hint and menus come from the shell. The hint says "Point at the TV and press A to bonk a mole. Recenter if the ring drifts." | Done | game_rules (visual rules), smoke_mole, Screenshot |
| REQ-WM-11 | A hit mole closes its eyes (`^ ^` smile), sparkles of the player color and white turn around it in 4 steps, and the points show above it ("+10", in the color of the player; "+50" bigger). It does not fall, shake or hurt: it is happy. Nothing in a hit is violent or sad (REQ-GM-81). | Done | smoke_mole, Screenshot |
| REQ-WM-12 | Haptics (REQ-GM-43): a bonk that hits buzzes the player 40 ms, a bonk that misses 15 ms (the gap between two buzzes is 100 ms or more, `Haptics`). GO buzzes every phone 60 ms. The winner buzzes 400 ms at the end. Sounds: `mole_hit`, `mole_points` (a pitch for each player), `mole_miss` and the song `whack_a_mole`. | Device | smoke_mole, Device (feel) |

End and players

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-WM-13 | The result menu is `open_results()` (REQ-GM-72) with a `Scoreboard` (higher is better): ranking, "X wins!" or "Tie!", Try again, New game, Back to menu. With one player there is no medal (REQ-GM-73); a player who stays after the others left has a technical win and the gold medal (owner, 2026-10-29); with more players each row has the medal of its place (REQ-GM-73a). A player who leaves takes the ring and the score out, and the round goes on. A lost phone pauses the round (REQ-GM-30). When the last player leaves, the menu "No players connected" opens (REQ-GM-21, 22). | Done | smoke_mole |
| REQ-WM-14 | Children (REQ-GM-80 to 84): friendly moles, a funny bonk, a miss costs nothing, no player is out of the round, the hint is one line, the moles are large (168 px circle) and slow at Easy, and every text is positive. | Device | Review, Device (with a child, Test 28) |
| REQ-WM-15 | The layout comes from `size` (REQ-2D-2). It works at 1280x720 and 1920x1080: the play area and the sizes of the moles scale with the screen. The ring and the HUD keep their pixel size. | Done | game_rules (scale) |
| REQ-WM-16 | Personal best: no key yet; planned (issue #216): `whack_a_mole|<difficulty>`, higher is better, keys 43 to 45 (see the first section). | Planned (issue #216) | smoke_bests |

### Settings and difficulty

The settings view has the row Difficulty (registry `settings: []`), and `difficulty` is a prop of the game (REQ-GM-90 to 95). Difficulty
changes how long a mole stays and how many come, never the points. First guesses (`mole_field.gd`, `LEVELS`):

| Difficulty | `stay` (s) | `spawn_every` (s) | `max_base` | Hit radius |
|------------|-----------|-------------------|------------|-----------|
| Easy | 2.6 | 1.4 | 2 | 100 px |
| Medium | 1.8 | 1.0 | 2 | 84 px |
| Hard | 1.1 | 0.7 | 3 | 72 px |

## Parameters

Values that change how the game feels. Tune them on a device (Test 28). First values, in `mole_field.gd` and
`whack_a_mole_game.gd`:

| Name | First value |
|------|-------------|
| `RISE_TIME`, `DOWN_TIME`, `HIT_LIFE`, `HIT_RISE` | 0.25 s, 0.25 s, 0.8 s, 0.15 s |
| `POINTS`, `GOLDEN_POINTS`, `GOLDEN_STAY` | 10, 50, 70 % of `stay` |
| `BONUS_FIRST`, `BONUS_MIN`, `BONUS_MAX` | 10 s, 14 s, 22 s |
| `MAX_OUT` | 6 |
| `RELOAD`, `HINT_TIME`, `ROUND_TIME`, `COUNTDOWN` | 0.3 s, 4 s, 60 s, 3 s |
| Levels | table above |

## Sound and haptics (REQ-GM-49a to 49c, REQ-GM-43)

The song `whack_a_mole` plays with the play. The effects `mole_hit`, `mole_points` and `mole_miss` and the haptics (hit 40 ms, miss 15 ms, GO 60 ms, winner 400 ms) are in REQ-WM-12. The pause and result sounds come from the base class.

## Languages and texts (REQ-GM-47o)

The rows are in `assets/lang/strings.csv`: `registry.whack_a_mole`, `registry.desc_whack_a_mole`, `how_to.whack_a_mole` and `whack_a_mole.*`. In Hebrew the HUD is mirrored by the shell; the field is not. The Hebrew was written by Claude and needs a native reader.

## Open questions

- Name: no trademark search was done for "Whack-a-Mole" (a name that others may own). This is not a clearance, and the decision about the name Sababi does not cover it. Check the name before the store release.
- Personal best: decided 2026-10-30, planned (issue #216): keys 43 to 45, a new profile code format version.
- The Hebrew texts were written by Claude and need a native reader.
