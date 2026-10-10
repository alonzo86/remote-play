#!/usr/bin/env python3
"""Build assets/fonts/RemotePlayPixelHebrew.ttf: a Hebrew pixel font that matches Press Start 2P.

Same grid as Press Start 2P: 8x8 pixels per glyph, 125 font units per pixel, 1000 units per em,
monospaced (advance 1000). Letters use rows 0 to 6 (the cap height of Press Start 2P), vertical
strokes are 2 pixels wide and horizontal strokes 1 pixel, and column 7 stays empty as the gap.
The final letters and qof go down to row 8 (below the baseline). The font is a fallback for
player names (docs/ARCADE_STYLE_PLAN.md, open question 2). Needs fontTools:
    python3 tools/make_hebrew_font.py [out.ttf]
"""
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

PX = 125
EM = 1000

# Each glyph: rows from the top (row 0 is the top of a capital, row 7 is just above the baseline
# in Press Start 2P, row 8 is below it). "X" is a pixel. Rows that are missing are empty.
GLYPHS = {
    0x05D0: ["XX...XX", ".XX..XX", "..XX.X.", "..XXX..", ".X.XX..", "XX..XX.", "XX...XX"],  # alef
    0x05D1: ["XXXXX..", "....XX.", "....XX.", "....XX.", "....XX.", "....XX.", "XXXXXXX"],  # bet
    0x05D2: [".XXX...", "...XX..", "...XX..", "...XX..", "..XXX..", ".XX.XX.", "XX..XX."],  # gimel
    0x05D3: ["XXXXXXX", "....XX.", "....XX.", "....XX.", "....XX.", "....XX.", "....XX."],  # dalet
    0x05D4: ["XXXXXXX", ".....XX", ".....XX", "XX...XX", "XX...XX", "XX...XX", "XX...XX"],  # he
    0x05D5: [".XXXX..", "...XX..", "...XX..", "...XX..", "...XX..", "...XX..", "...XX.."],  # vav
    0x05D6: [".XXXXX.", "...XX..", "...XX..", "...XX..", "...XX..", "...XX..", "...XX.."],  # zayin
    0x05D7: ["XXXXXXX", "XX...XX", "XX...XX", "XX...XX", "XX...XX", "XX...XX", "XX...XX"],  # het
    0x05D8: ["XX.XXX.", "XX.X.XX", "XX...XX", "XX...XX", "XX...XX", "XX...XX", ".XXXXX."],  # tet
    0x05D9: [".XXXX..", "...XX..", "...XX.."],                                                # yod
    0x05DA: ["XXXXXX.", ".....XX", ".....XX", ".....XX", ".....XX", ".....XX", ".....XX",
             ".....XX", ".....XX"],                                                           # final kaf
    0x05DB: ["XXXXX..", "....XX.", ".....XX", ".....XX", ".....XX", "....XX.", "XXXXX.."],  # kaf
    0x05DC: ["XX.....", "XX.....", "XXXXXXX", ".....XX", ".....XX", "....XX.", "..XXX.."],  # lamed
    0x05DD: ["XXXXXX.", "XX...XX", "XX...XX", "XX...XX", "XX...XX", "XX...XX", "XXXXXXX"],  # final mem
    0x05DE: ["XX.XXX.", ".XX..XX", "XX...XX", "XX...XX", "XX...XX", "XX...XX", "XX.XXXX"],  # mem
    0x05DF: [".XXXX..", "...XX..", "...XX..", "...XX..", "...XX..", "...XX..", "...XX..",
             "...XX..", "...XX.."],                                                           # final nun
    0x05E0: [".XXX...", "...XX..", "...XX..", "...XX..", "...XX..", "...XX..", ".XXXX.."],  # nun
    0x05E1: ["XXXXXXX", "XX...XX", "XX...XX", "XX...XX", "XX...XX", ".XX.XX.", "..XXX.."],  # samekh
    0x05E2: ["XX...XX", "XX...XX", ".XX..XX", "..XX.XX", "...XXX.", "..XXX..", "XXX...."],  # ayin
    0x05E3: ["XXXXXX.", "X....XX", "XXX..XX", ".....XX", ".....XX", ".....XX", ".....XX",
             ".....XX", ".....XX"],                                                           # final pe
    0x05E4: ["XXXXXX.", "X....XX", "XXX..XX", ".....XX", ".....XX", ".....XX", "XXXXXXX"],  # pe
    0x05E5: ["XX...XX", "XX...XX", ".XX..XX", "..XXXX.", "...XX..", "...XX..", "...XX..",
             "...XX..", "...XX.."],                                                           # final tsadi
    0x05E6: ["XX...XX", "XX...XX", ".XX.XX.", "..XXX..", "...XX..", "....XX.", "XXXXXXX"],  # tsadi
    0x05E7: ["XXXXXXX", ".....XX", "XX...XX", "XX...XX", "XX..XX.", "XX.XX..", "XX.....",
             "XX.....", "XX....."],                                                           # qof
    0x05E8: ["XXXXXX.", ".....XX", ".....XX", ".....XX", ".....XX", ".....XX", ".....XX"],  # resh
    0x05E9: ["XX.X.XX", "XX.X.XX", "XX.X.XX", "XX.X.XX", "XX.X.XX", "XX.X.XX", ".XXXXX."],  # shin
    0x05EA: ["XXXXXXX", ".XX..XX", ".XX..XX", ".XX..XX", ".XX..XX", ".XX..XX", "XXX..XX"],  # tav
    0x05BE: ["", "", "", "XXXXXXX"],                                                          # maqaf
    0x05F3: ["..XX...", "..XX...", ".XX...."],                                                # geresh
    0x05F4: ["XX.XX..", "XX.XX..", "X..X..."],                                                # gershayim
}

NAMES = {cp: "uni%04X" % cp for cp in GLYPHS}


def glyph_from_rows(rows):
    pen = TTGlyphPen(None)
    for r, row in enumerate(rows):
        # Row r covers y from (7 - r) * PX to (8 - r) * PX: row 0 is the top (y 875..1000).
        y0 = (7 - r) * PX
        y1 = y0 + PX
        x = 0
        while x < len(row):
            if row[x] != "X":
                x += 1
                continue
            start = x
            while x < len(row) and row[x] == "X":
                x += 1
            # One rectangle for each run of pixels, clockwise (TrueType outer contour).
            pen.moveTo((start * PX, y0))
            pen.lineTo((start * PX, y1))
            pen.lineTo((x * PX, y1))
            pen.lineTo((x * PX, y0))
            pen.closePath()
    return pen.glyph()


def build(out_path):
    order = [".notdef", "space"] + [NAMES[cp] for cp in sorted(GLYPHS)]
    fb = FontBuilder(EM, isTTF=True)
    fb.setupGlyphOrder(order)
    cmap = {0x20: "space", 0xA0: "space"}
    cmap.update({cp: NAMES[cp] for cp in GLYPHS})
    fb.setupCharacterMap(cmap)
    notdef = glyph_from_rows(["XXXXXXX", "X.....X", "X.....X", "X.....X", "X.....X", "X.....X", "XXXXXXX"])
    glyphs = {".notdef": notdef, "space": TTGlyphPen(None).glyph()}
    glyphs.update({NAMES[cp]: glyph_from_rows(rows) for cp, rows in GLYPHS.items()})
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics({name: (EM, glyphs[name].xMin if hasattr(glyphs[name], "xMin") else 0) for name in order})
    # The same vertical metrics as Press Start 2P, so a line does not jump when a name mixes both fonts.
    fb.setupHorizontalHeader(ascent=1000, descent=0)
    fb.setupOS2(sTypoAscender=1000, sTypoDescender=0, sTypoLineGap=0, usWinAscent=1000, usWinDescent=374,
                fsType=0, achVendID="RMPL", ulUnicodeRange1=1 << 11)
    fb.setupNameTable({
        "familyName": "Remote Play Pixel Hebrew",
        "styleName": "Regular",
        "uniqueFontIdentifier": "RemotePlayPixelHebrew-Regular",
        "fullName": "Remote Play Pixel Hebrew Regular",
        "psName": "RemotePlayPixelHebrew-Regular",
        "version": "Version 1.000",
        "copyright": "Copyright 2026 the Remote Play authors",
        "licenseDescription": "Licensed under the SIL Open Font License, Version 1.1",
    })
    fb.setupPost(isFixedPitch=1)
    fb.save(out_path)


if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else "assets/fonts/RemotePlayPixelHebrew.ttf")
