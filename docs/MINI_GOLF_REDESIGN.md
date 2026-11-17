# Mini Golf redesign: analysis and proposal

Status: option A approved by the owner on 2026-11-03 and built (`golf_look.gd`, REQ-MG-2, 16, 18, 19 in `docs/games/mini_golf.md`; the new look is checked by `golf_view` and `smoke_golf_phones`; Manual test 26 steps 14d and 14e, the TV with 4 phones, were removed on 2026-11-17, issue #457). The owner decisions: option A; only the ball on turn is drawn, white, with no ring and no flashing border (the owner first chose the balls of all players in rings, then changed it on the same day); a small golfer stays by the ball on turn; the scenery stays as a smaller border; the tile and test 26 change. Holes 4 and 5 were not shortened or bent: from above they fit one screen as they are. The text below is the analysis that led to the decision (the old look is described in the present tense). Evidence: screenshots made with a throwaway script (1920x1080, 4 players, hard-set ball positions on holes 1 to 5; not committed).

## 1. Problems found

| # | What I saw | Where |
|---|------------|-------|
| P1 | The camera is fixed behind the tee and never moves. Far from the tee the course shrinks to a thin band: the whole of z 3 to 6 m is only 16 of 270 picture pixels (about 65 px of 1080). Hole 2 and 4 lakes, bridge, windmill, cup and flag are all squeezed into that band. | `golf_look.gd:17,75-76` (`HY=88`, `py(z)=HY+100/z`) |
| P2 | The ball has a floor of 6 picture pixels (48 px). Near the tee it is correct. At the cup the ball is wider than the bridge, wider than the cup and as big as the golfer. It hides the cup and the flag. | `golf_look.gd:24,86-87` |
| P3 | The golfer is drawn at the ball with a floor of 42% of the near size. At the cup the golfer is bigger than the windmill and the flag and stands on them (hole 2, near cup: golfer, ball and windmill are one blob). | `golf_look.gd:25`, `mini_golf_game.gd:361-363` |
| P4 | Hole 3 (turn to the right): the second arm of the L and the cup (x = 2.4 m) are a flat sliver about 45 px high at the right edge, with a barrier, a rock, ball and golfer on top of each other. The target is hard to see and aiming at it is a guess. | `golf_holes.gd:26-29`, screenshot `h3_near_cup` |
| P5 | The ground is a baked 480x270 texture per hole, not drawn from the course data. The things on it (rocks, boxes, ball) are drawn live with the formula of P1. Two scales are glued together; they drift when the course is wide (holes 2, 4 and 5 are 2.4 to 3.6 m wide and run out of the bottom edge of the view). | `golf_look.gd:93-104,360-361` |
| P6 | Only the player on turn is drawn (REQ-MG-2). The balls of the others cannot be seen, so the "race" cannot be seen. | `mini_golf_game.gd:361`, `docs/games/mini_golf.md` REQ-MG-2 |
| P7 | The bottom chip bar sits on the fairway and the brown frame (bar and course overlap at the near edge). The banner plate sits over the horizon, on top of the cup area, where the player has to look. | `mini_golf_game.gd:380-396,446` |
| P8 | The guide for aiming (the dotted line) is 3.0 / 1.2 / 0 m long, but beyond z 3 m a meter is about 10 px, so the line is a dot. | `mini_golf_game.gd:35-37`, `golf_look.gd:481-491` |

"Things get messy as the player makes progress" is P1 to P4: every putt moves the ball further from the camera, where the same perspective formula shrinks the course while the floors on ball, golfer and marks (P2, P3, P8) keep their size. The proportions change with every stroke.

## 2. Root causes

1. One fixed camera and a steep perspective (`100/z`), made for a short first view, used for holes up to 6 m long and 3.6 m wide.
2. Size floors (ball 48 px, golfer 42%, aim marks 8 to 16 px) fix the readability near the tee and break the scale far away. Floors and perspective disagree.
3. The picture is a hand-painted texture, so scale cannot change without repainting 5 textures.
4. The view is built around one golfer; there is no place for the others.
5. The HUD is laid over the course instead of next to it.

## 3. Options

### A. Top-down course that always fits (recommended)
The camera looks straight down (or almost). Each hole is scaled once so the whole course fits the area between the HUD bands. The ball, the cup and the obstacles have one constant scale for the whole hole. All balls of all players are drawn (own color ring). The golfer is a small figure next to the ball or a big marker.
- Player sees: the whole hole at once, a ball that does not change size, who is ahead. The 8-bit look, colors, sounds, flag, windmill, lake art can be reused; the "behind the golfer" view is lost.
- Stays: rules, sim (`golf_sim.gd`, `golf_rules.gd`), hole data (`golf_holes.gd`), phone controls and detector, strings, settings, results.
- Cost: medium. The draw code (`golf_look.gd`) and the 5 ground images are redone; the sim and the rules are not touched. Aim line becomes a true length.
- Risks: the "from behind" mock was approved in design threads ("the look can be revisited later", doc header); the 8-bit scenery needs a new layout; the aim direction (phone left/right) must map to a top-down angle, and the Hebrew view must stay unmirrored (REQ-MG, languages section); pixel tests and the tile change.

### B. Follow camera with a constant ball size
Keep the view from behind. The camera moves with the ball (it centres on the ball and on the cup), with a constant scale for ball and golfer and a limited tilt. The scenery scrolls.
- Player sees: the current look, but the ball and the golfer stay the same size and the cup comes closer. The cup is not always on screen at the start of a long hole.
- Stays: the look, golfer animation, the mock.
- Cost: large. The ground cannot be a baked texture any more (P5): it must be drawn from the fairway rectangles; the scenery must be a scrolling layer; the golfer art may need a second size. A turn of the L (hole 3) needs a camera that turns.
- Risks: nausea and "lost" feeling for a 5-year-old when the camera moves; the camera move at each turn start costs time; large test change; all players' balls cannot be shown at once.

### C. Keep the view, fix the numbers
Lower the perspective strength (for example `100/z` to `40/z`), raise the horizon, shrink the floors on the ball and the golfer, move the bar and banner. Draw the ground from the course data.
- Player sees: the same game with less shrinking and a less huge ball. The far end is still small.
- Cost: small to medium (look only). Risks: it moves, but does not remove, P1, P3, P4; the next hole design (longer or wider) breaks it again; the 48 px ball rule (REQ-GM-47e, 47m, issue #64) limits how small the ball may be, so the course would have to be shorter or the view wider.

### Turn-based or all at once
Turn-based is kept in all options: it is the rule of the game, a child understands it, and a swing is a real arm movement that two players cannot do at once. In Option A the others' balls are shown but still play one at a time. All-at-once (shared screen, no turns) is not recommended: it needs another phone input rule and another kid rule (REQ-GM-80 to 84) review.

### Phone controls
Not part of the problem in the owner's note. Keep the aim (turn the phone) and the swing. Open item: issue #209 (swing detector, needs a device test) is separate from this redesign. A top-down view makes aim easier to read (a true arrow), so Option A may help the phone side without changing it.

## 4. Recommendation

Option A. It removes the cause (one perspective, many floors) instead of tuning it, makes later holes as readable as the first, shows all players, and keeps the sim, rules, controls and data. Option C can be done first as a quick patch if the owner wants an early improvement, but it is thrown away by A.

## 5. Questions for the owner (what the user sees is the owner's decision)

1. Is it acceptable to drop the view "from behind the golfer" for a top-down view (the look was never approved as final)? Or must the golfer-from-behind look stay (then Option B or C)?
2. In Option A, show the balls of all players at once, or only the one on turn (REQ-MG-2 says only the one on turn)?
3. Should the golfer stay (a small figure by the ball, animated swing) or be replaced by an arrow and a club mark?
4. Keep 5 holes of this size and the par 2 to 4, or may the holes be redrawn to fit one screen (the long ones, 4 and 5, are shortened or bent)?
5. Keep the scenery (hot air balloon, clubhouse, trees) as a border around the course, or remove it for a plain course?
6. May the tile (`assets/tiles/mini_golf.png`) and the manual test 26 steps change with the new look?

## 6. Phased plan (after the answers)

1. `product-engineer` and `ui-ux-designer`: requirements change (REQ-MG-3, 4, 16, 2 if needed) marked Planned, with an issue, and a mock of holes 1, 3 and 5 in the new view for approval. No code before the look is approved.
2. `sw-developer`: a new `golf_look` draw (scale from the course bounds, constant ball, all balls, HUD bands outside the course), sim untouched; one commit that also updates `docs/games/mini_golf.md`.
3. `automation-developer`: pixel and layout tests (ball size constant across a hole, course inside the safe area, HUD not over the course), the smoke and `r4_golf` tests adjusted.
4. `qa`: manual test 26 steps for the new view; owner checks on a TV (Device).
5. `ui-ux-designer`: new tile; `sync-docs`, then PR with the strings list (the hints may change).
