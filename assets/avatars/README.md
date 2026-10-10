# Avatars

`avatars.png` is the sheet of the 16 player avatars (FD-22, `docs/PROFILES_PLAN.md` section 7): a 4 x 4 grid of cells of 16 x 16 pixels, 64 x 64 pixels in all, drawn in the palette of the arcade style. The index of an avatar is `row * 4 + column`.

Rules: a later sheet may add avatars, but it never moves or removes one, because an index is saved in the profiles of the players. The image is imported without filter and without mipmaps (`tests/design_tokens.gd` checks this). The code that draws it is `scripts/ui/avatar.gd`.
