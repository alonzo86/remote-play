# Color-blind audit of the player colors (issue #237)

Date: 2026-10-30. Status: audit and proposal only. **The palette in `scripts/core/protocol.gd` is not changed**: a new palette changes the look of every game and the owner decides first (issue #237, REQ-GM-46).

## 1. Which TV objects carry a cue besides color

REQ-GM-46 (decision of the owner) says that a player object on the TV shows **no number and no avatar**: players are told apart by the slot color, and the names are on the chips. So the table below is a statement of the present rules, not a list of bugs. "Cue" means something besides the color that tells which player an object belongs to.

| Game | Player object on the TV | Same shape for all slots | Cue besides color |
|------|------------------------|--------------------------|-------------------|
| Pin Pals (bowling) | ball (`BowlingLook.draw_ball`) | yes | Turn order: one ball on the lane at a time; the score sheet rows hold the name chip with the avatar |
| Tennis | player with a shirt in the slot color | no: skin and hair change with the slot (`TennisLook.draw_person`, `SKINS[slot]`, `HAIRS[slot+1]`) | Side of the court and the team chip; skin and hair (a weak cue) |
| Mini Golf | golfer with a shirt in the slot color; the ball is white, with no ring, and only the ball on turn is drawn (2026-11-03) | yes | Turn order: one golfer at a time, the shirt tells who plays; the chips of the bar name the players; the score table has a chip with the avatar |
| Air Hockey | mallet (`AirHockeyLook.draw_paddle`) | yes | Position: the seat on the left or on the right, own goal; chips with avatars above the goals |
| Star Shield | ship hull and beam | yes | None |
| Bumper Cars | car (`bumper_cars_game._draw_car`) | yes | None (the spark on the pole takes a slot as a random seed only) |
| Car Race | car (`RaceLook.car_image`) | yes | None |
| Treasure Maze | ball | yes | None |
| Paint Grab | blob, and the tiles it painted | yes | None (the painted tiles are in the same color) |
| Sheep Herding | dog (`SheepLook`, a texture per color) | yes | None; the score is shared by the team, so who is who matters less |
| Snowball Splat | cursor ring | yes | None |
| Sumo Bumpers | penguin (`SumoLook.penguin_image`) | yes | None |
| Whack-a-Mole | cursor ring | yes | None |
| Freeze Dance | dancer (`DanceLook.dancer_image`) | yes | Place: dancers stand in slot order; the bench has chips with the avatar |
| Tower Builder | brick | yes | Turn order: one brick hangs from the crane; the line "turn of NAME" is in the slot color |

Result: 9 of 15 games (Star Shield, Bumper Cars, Car Race, Treasure Maze, Paint Grab, Sheep Herding, Snowball Splat, Sumo Bumpers, Whack-a-Mole) have no cue at all and need the colors to be told apart. The other 6 have a cue of position, turn or place, and only Tennis has a cue on the object itself (skin and hair). A shape or number mark on the object would change REQ-GM-46 ("no number and no avatar on a player object"), so it is not added here: it is a decision for the owner.

## 2. The present palette under a color-blind simulation

Method: Machado et al. (2009) matrices, severity 1.0, applied in linear RGB; distance is CIE76 delta E, the same measure as the tests `auto_paint`, `auto_asteroid` (minimum 25 under normal vision). The script is not in the repository (`mocks/palette/cb.py` of the project files).

| Palette | Normal | Protanopia | Deuteranopia | Tritanopia |
|---------|--------|-----------|--------------|------------|
| Now: e63946 2a9d8f f4a261 457b9d | 35.9 (slots 2, 4) | 24.7 (1, 2) | **20.2 (1, 3)** | **13.1 (2, 4)** |

Findings: red and orange (slots 1 and 3) fall to 20 under deuteranopia, as the issue says; teal and blue (slots 2 and 4) are 36 under normal vision and 13 under tritanopia. Contrast against the black screen (`UiTheme.contrast`): 5.0, 6.3, 10.2, 4.6.

There is no test for this: the rule "25 under simulation" is not a requirement yet, and a test that fails on the present palette must not be committed. When the owner picks a palette, a test with the limit (below) is added in the same change.

## 3. Two proposals (not applied)

Minimum delta E of any two slots, per vision type, and `UiTheme.contrast` against black:

| Palette | Normal | Protan | Deutan | Tritan | Contrast vs black |
|---------|--------|--------|--------|--------|-------------------|
| Now | 35.9 | 24.7 | 20.2 | 13.1 | 5.0, 6.3, 10.2, 4.6 |
| **A**: blue 006aff, amber b28324, magenta d92b82, lime eaff00 | 66.6 | 53.1 | 47.8 | 47.7 | 4.5, 6.2, 4.6, 18.8 |
| **B**: cyan 3dcef2, orange cc7e0a, purple aa3df2, pink f20c68 | 75.7 | 43.8 | 41.2 | 41.3 | 11.3, 6.6, 4.7, 5.0 |

Notes for the owner:
- A follows the idea of the issue (blue, orange, magenta, yellow-green) and has the best worst case (47.7). Slot 1 (006aff) is almost the color of the inner frame line `UiTheme.FRAME` (0058f8), and slot 4 (eaff00) is close to the yellow `UiTheme.ACCENT` (f8b800, delta E 34). Slot 4 is very bright.
- B has the highest distance under normal vision and 41 or more in every simulation. Slot 4 (f20c68) is near the red `UiTheme.BAD` (f83800, delta E 47) and slot 1 is a light cyan.
- Both keep contrast of 4.5 or more against black, delta E 40 or more from an empty tile (`SLOT_EMPTY`), and 28 or more from the accent, OK and BAD colors. Text on a slot color stays in the chip (REQ-GM-46), so white text on the lime or cyan is not needed.
- If chosen, the limit for a test is a minimum delta E of 40 under each of the 3 simulations, and `docs/games/*.md` lines that name colors (for example "teal" or "red") and `docs/design-system/tokens.json` change in the same commit.
- Before and after pixel checks of every game are needed (`tests/pixel_games.gd`).

Mock images (TV black, 4 slots, under the 4 vision types, and an arena): `/mnt/project-files/mocks/palette/slot_colors.png` and `/mnt/project-files/mocks/palette/game_screen.png`.
