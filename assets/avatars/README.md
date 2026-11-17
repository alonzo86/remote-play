# Avatars

`avatars.png` is the sheet of the 32 player avatars (FD-22, `docs/PROFILES_PLAN.md` section 7): 4 columns and 8 rows of cells of 16 x 16 pixels, 64 x 128 pixels in all, drawn in the palette of the arcade style. The index of an avatar is `row * 4 + column`.

`guest.png` is the picture of a guest (a phone with no profile): 16 x 16 pixels, a grey silhouette with a question mark (owner, 2026-11-11). It is not one of the 32, so a player cannot choose it and the sheet does not have it; `Protocol.GUEST_AVATAR` is its index in the code and it is never sent. It is written by `tools/make_guest_avatar.gd` (the picture is in that file) and imported with the same settings as the sheet.

Rules: a later sheet may add avatars, but it never moves or removes one, because an index is saved in the profiles of the players. The image is imported without filter and without mipmaps (`tests/design_tokens.gd` checks this). The code that draws it is `scripts/ui/avatar.gd`.
