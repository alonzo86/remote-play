# Galaxy Protector (`asteroid_blast`)

Type: 2D. Players: 1 to 4. Input: tilt (`PlayerInput.tilt()`, left and right), Recenter.
General requirements: `docs/GAME_REQUIREMENTS.md`, also the rules for children (REQ-GM-80 to 84).
Code: `scripts/game/asteroid_blast/` (`space_field.gd` the rules, `blast_look.gd` the pictures, `asteroid_blast_game.gd` the screen).

## Goal

Each player tilts a phone to fly a little **spaceship** left and right along the bottom of the screen. The ships shoot by themselves
at the **asteroids** that fall from above. A ship can shoot an asteroid or fly out of its way. From time to time a round **upgrade**
falls too: a **force field** (it takes one hit and goes away) or **one more laser** (up to 4). A ship that is hit without a force field
blows up, and its player is out. The game is a team game: the players fly against the same asteroids. But the player with the most
points wins. The game is endless. It ends when the last ship is gone. The asteroids come in **waves** of 30 s, with 5 s of rest between
two waves, and every wave is harder than the one before.

Registry entry: `description` (one line) and `tile` (`assets/tiles/asteroid_blast.png`, made by `tools/make_tiles.gd`), see REQ-GM-7.
Visual language: shell, player colors, pixel world (REQ-GM-45, 46, 47i to 47n, 48, 49). Check the tile next to the Games screen.

## Gaps

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-62 | Gap | `docs/MANUAL_TESTS.md` has a test for this game (Test 21). It is not yet run on a device. |
| REQ-GM-50, REQ-GM-51, REQ-GM-52 | Device | Frame rate, per-frame allocation and start time are not measured on a TV box. |
| REQ-GM-80 to 84 | Note | REQ-GM-81: the ships shoot toy beams at lifeless gray rocks; no person, animal or creature is hurt, and a ship that is hit bursts into colored pixels. REQ-GM-83: a hit costs no points; a player who is out keeps the points and watches, and the game ends when the last ship is out, so the wait lasts only as long as the others fly (REQ-AB-14). The hint is one line. Texts are positive ("Wave 3 clear!"). |

## Requirements

Status: Done, Open, or Device (needs a real TV and phones). "Check" names the test.

Players and flying

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-AB-1 | 1 to 4 players (registry `min_players` 1, `max_players` 4). The ships start in a row along the bottom, spread evenly, in slot order (REQ-GM-25). The game is endless (REQ-AB-14) and a team game with a winner: the player with the most points wins (REQ-AB-14). | Done | smoke_asteroid |
| REQ-AB-2 | Tilting the phone to the right moves the ship to the right, tilting to the left moves it to the left. The speed follows the tilt smoothly (full tilt: 760 px/s, `SHIP_SMOOTH`), a small tilt (dead zone 0.04) does nothing, and the ship stops at 60 px from both sides. The ships steer during the countdown too, but nothing falls and nobody fires until GO. A ship that is out does not steer. All players have the same values (REQ-GM-24). | Done | game_rules, smoke_asteroid |
| REQ-AB-3 | The RECENTER button recenters (REQ-GM-37). The pose held in the countdown is the center at GO. A and B do nothing. | Device | Device (RECENTER) |
| REQ-AB-4 | A ship fires by itself, every 0.4 s, straight up, from the first moment after GO. There is no button to fire. | Done | game_rules, smoke_asteroid |

Asteroids

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-AB-5 | There are three sizes of asteroids. A beam does 1 damage and is gone. A **small** asteroid (radius 30 px) has 1 life and gives 10 points, a **medium** (48 px) has 2 lives and gives 20 points, a **large** (74 px) has 4 lives and gives 40 points. The smaller an asteroid, the faster it falls (small 1.25, medium 1.0, large 0.75 times the fall speed). The points go to the ship whose beam destroyed it. | Done | game_rules |
| REQ-AB-6 | Asteroids enter at the top, at a random place across the whole width, with a small sideways drift. They turn back at the sides. One that reaches the bottom is gone with no effect. | Done | game_rules |
| REQ-AB-7 | A destroyed **large** asteroid leaves two **medium** pieces, a destroyed **medium** one leaves two **small** pieces, a **small** one leaves nothing. The pieces fly apart sideways. The pieces give their own points. | Done | game_rules |
| REQ-AB-8 | The game is played in **waves**. A wave lasts 30 s. Then there is a rest of 5 s: no asteroid comes (the ones on the screen fall on), the lasers go on firing. Then the next wave starts. Each ship that is still flying at the end of wave n gets 50 x n points. | Done | game_rules |
| REQ-AB-9 | Each wave is harder than the one before: the asteroids fall 10 % faster for each wave, they come more often (the time between two asteroids is 1.5 s divided by 1 + 0.2 x (wave - 1), not shorter than 0.35 s), and large asteroids come more often (the chance of a large one grows from 20 % by 3 % for each wave, up to 45 %; the chance of a small one falls from 40 % to 15 %). With more ships in the sky, more asteroids come (divided by 1 + 0.3 x (ships - 1)), so the game is as hard with 4 players as with 1. | Done | game_rules |

Upgrades, force field and loss

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-AB-10 | A round **upgrade** falls from the top: the first after 10 s of play, then one after 12 to 20 s. Its kind is chosen by chance: a **force field** (blue, a shield) or a **weapon** (orange, an arrow). There are at most 2 on the screen. A ship that touches one takes it and the pickup is gone. An upgrade that nobody takes falls off the bottom. | Done | game_rules |
| REQ-AB-11 | The **weapon** upgrade gives the ship one more laser. A ship has 1 laser at the start and 4 at most. The lasers fire together, side by side (22 px apart, around the middle of the ship). An upgrade that a ship cannot use (4 lasers, or a force field already on) gives 50 points instead. | Done | game_rules |
| REQ-AB-12 | The **force field** upgrade puts a ring around the ship. When an asteroid hits the ship, the ring goes away, the asteroid breaks into dust (no points, no pieces), and the ship flies on, whole. | Done | game_rules |
| REQ-AB-13 | An asteroid that hits a ship without a force field blows up the ship: a burst of colored pixels, a sound and a buzz on that phone. The player is out and keeps the points. The other ships go on. | Done | game_rules, smoke_asteroid |
| REQ-AB-14 | The game is endless: it ends when every ship is gone. The sky goes on for 2 s, then the result menu opens (`open_results()`, REQ-GM-72): the ranking by points, "X wins!" or "Tie!", Try again, New game, Back to menu. One player sees a medal for the points (REQ-GM-73, tiers in REQ-AB-20) and "Reached wave N" as the title. | Done | smoke_asteroid |

Feedback and players

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-AB-15 | Sounds and haptics (the table below): an asteroid breaks, a pickup is taken, a force field takes a hit, a ship is lost, a wave ends or begins. A pickup buzzes the phone (30 ms), a force field hit 80 ms, a lost ship 400 ms, GO 60 ms, the winner 400 ms. | Device | smoke_asteroid (events), Device (the feel) |
| REQ-AB-16 | HUD: the title "Galaxy Protector", the leader chip (`draw_leader_chip()`, REQ-GM-46) with the points of the leader or TIE, and each phone shows its own points and place (REQ-FL-67). The wave ("Wave 3") is in the bar, with a line under it that shows how much of the wave (or of the rest) is left. A banner "Wave 3" shows for 2 s at the start of a wave; in the rest the banners are "Wave 3 clear!" and "Next wave in 4". In the countdown every ship has a name tag (REQ-GM-46a). A ship has no number on it (REQ-GM-46). The hint is one line, "Tilt to steer. Your ship shoots by itself. Grab the upgrades!", shown in the countdown and for 5 s after GO. The layout comes from `size` (REQ-2D-2) and works at 1280x720 and 1920x1080. | Done | smoke_asteroid, game_helpers |
| REQ-AB-17 | Look (REQ-GM-47i to 47n): a pixel night sky of 8 dark bands (`#0a0a1e` to `#1c1244`) with 66 star pixels in three layers that drift down (6, 12, 22 world pixels per second) and a far purple planet with a ring. An asteroid is a gray round rock with a rough edge, light from the top left, and 2 to 4 craters; there are 4 looks of each size, and all have a one-pixel black outline (`#101018`). A ship is 14 x 14 world pixels with a flame: the hull in the player color, a white nose and wing tips, a cyan cockpit. A pickup is a round disc of 15 pixels: blue with a white shield, or orange with a white arrow. A beam is a bar in the player color with a white core. A force field is a light blue ring that blinks. An explosion is a ring of sparks in 4 steps in 0.6 s. All text is 32 px or larger and inside the 60 px margin; the banners sit on a black plate. | Device | game_rules (pictures), Device |
| REQ-AB-18 | Personal best (REQ-GM-98): the key is `asteroid_blast|<difficulty>`, a higher score is better (`best_key()`; keys 37 to 39 of `ProfileKeys`). | Done | smoke_bests, profile_code |
| REQ-AB-19 | A player who leaves takes the ship and the beams out and keeps no points in the ranking (REQ-GM-21). When nobody is left the "No players connected" menu opens (REQ-GM-22). A lost phone pauses the game with the card of REQ-GM-30; nothing runs during the pause (the base class). | Done | smoke_asteroid, smoke_tv (shared base class) |

Settings (REQ-GM-90 to 97)

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-AB-20 | The settings view has the row Difficulty (registry `settings: []`), and `difficulty` is a prop of the game. The speed and the number of asteroids are factors on Medium; the medal tiers (REQ-GM-73) are for one player (bronze, silver, gold). | Done | smoke_asteroid, game_rules |

| Difficulty | Fall speed | Asteroids | Medal tiers (points) |
|------------|------------|-----------|----------------------|
| Easy | x 0.8 | x 0.8 | 800, 2400, 5000 |
| Medium | x 1.0 | x 1.0 | 600, 1800, 4000 |
| Hard | x 1.25 | x 1.3 | 500, 1500, 3200 |

## Parameters

Values that change how the game feels. Tune them on a device (Test 21). First values, all in `space_field.gd`:

| Name | First value |
|------|-------------|
| `SHIP_SPEED`, `SHIP_SMOOTH`, `TILT_DEADZONE` | 760 px/s, 9 1/s, 0.04 |
| `FIRE_EVERY`, `BEAM_SPEED`, `LASER_GAP`, `MAX_LASERS` | 0.4 s, 1100 px/s, 22 px, 4 |
| `WAVE_TIME`, `REST_TIME`, `WAVE_BONUS` | 30 s, 5 s, 50 x wave |
| `BASE_SPEED`, `SPEED_PER_WAVE` | 120 px/s (medium, wave 1), +10 % for each wave |
| `SPAWN_BASE`, `SPAWN_PER_WAVE`, `SPAWN_MIN`, `SPAWN_PER_PLAYER` | 1.5 s, 0.2, 0.35 s, 0.3 |
| `SIZES` | radius 30/48/74 px, life 1/2/4, points 10/20/40 |
| `UPGRADE_FIRST`, `UPGRADE_MIN`, `UPGRADE_MAX`, `UPGRADE_SPEED`, `UPGRADE_SPARE` | 10 s, 12 s, 20 s, 130 px/s, 50 points |
| `END_DELAY`, `BANNER_TIME`, `HINT_TIME` (in `asteroid_blast_game.gd`) | 2 s, 2 s, 5 s |
| Levels | table above |

## Open questions

- Is a ship too slow or too fast at full tilt (760 px/s)? Is one laser every 0.4 s too little at the start?
- How hard is wave 5, and wave 10? Does a player who is out wait too long when the others fly well (REQ-GM-83)?
- Are the upgrades often enough (every 12 to 20 s for all players together)? Should a force field and a weapon be dropped in a fixed order?
- With 4 players the pickups are shared: should a taken pickup respawn for the others?
- The medal tiers are guesses: how many points does a child of 5 to 8 years get in a first game?

## Sound and haptics (REQ-GM-49a to 49c, REQ-GM-43)

The song `asteroid_blast` plays from "GO": a bright, driving march at 140 BPM, A minor. The countdown, pause and result sounds come from the base class.

| ID | Effect | When | Sound | Status |
|----|--------|------|-------|--------|
| REQ-AB-S1 | `blast_boom` | An asteroid is destroyed. | A short pop and a low thud | Device (test 18, 21) |
| REQ-AB-S2 | `blast_pickup` | A ship takes an upgrade (haptic 30 ms). | Rising three-note run | Device (test 18, 21) |
| REQ-AB-S3 | `blast_shield` | A force field takes a hit (haptic 80 ms). | A falling blip with a puff | Device (test 18, 21) |
| REQ-AB-S4 | `blast_lost` | A ship is lost (haptic 400 ms). | A long falling boom, not scary | Device (test 18, 21) |
| REQ-AB-S5 | `blast_wave` | A wave ends, and the next wave starts. | Short rising run | Device (test 18, 21) |

The beams have no sound: with 4 ships firing, a sound for every shot would be noise.

## Languages (REQ-GM-47o)

The texts of this game are English and Hebrew: the title, the description, the hint, the banners ("Wave %d", "Wave %d clear!", "Next wave in %d", "All ships are gone!") and "Reached wave %d" have a Hebrew text in `scripts/core/strings.gd`. The Hebrew text was written by Claude and needs a native reader. In Hebrew the HUD is mirrored by the shell (title, leader chip, the wave text and the line); the game world is not mirrored.
