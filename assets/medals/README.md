# Medals

`medals.png` is the medal sheet: three medals of 16 x 16 px in one row, from the left gold, silver and bronze (the order of
`Medal.TIERS` in `scripts/ui/medal.gd`), on a transparent background. The result menu draws the medal next to the name of a player
(1st gold, 2nd silver, 3rd bronze, REQ-GM-73), at a whole-number scale with the nearest filter, like an avatar.

The sheet is made by `tools/make_medals.gd`; a hand-made sheet with the same layout can replace it (keep 48 x 16 px).
