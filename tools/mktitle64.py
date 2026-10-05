#!/usr/bin/env python3
"""Turn the title painting into a multicolour bitmap: src/title.s.

    tools/mktitle64.py [--preview]

The source is the CPC's title painting, assets/art/title.jpg: the cat caught
at the open Pitsos with a sausage, at a quarter past three in the morning.
loukc64.md 5.7 says an automatic conversion comes out blurred and clashing;
this one is built for the cell, not against it:

  * The painting is cropped (a little wall off the top, most of the floor off
    the bottom) and scaled to 160 x 168 - cell rows 0-20 - so a multicolour
    pixel is twice as wide as a line, as the monitor shows it.
  * Every pixel goes to its nearest C64 colour first; then each 4 x 8 cell
    keeps the three colours, besides the background, that cost the least
    over the pixels in it, and every pixel takes the nearest of those four.
    The background - the one colour every cell shares - is whichever makes
    the whole picture cheapest.
  * The name and the subtitle are put in before the cells are chosen, as
    pixels that must come out exactly, so the lettering is never the colour
    that loses. They are in the game's font, as on the CPC, and differ by
    language - so cell rows 0-4 are written twice, once per language, and
    rows 5-20 once.

Row 21 is left empty: the footer's text split is written on its last line,
which must be blank in both modes (CLAUDE.md 3), and so must the first byte
of the bitmap, which text mode reads there for a few cycles.

--preview writes build/title-<lang>.png at 2:1, which is how to judge it.
"""

import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import mktext64   # noqa: E402
from mksprite64 import C64_RGB   # noqa: E402

SRC = os.path.join(ROOT, "assets", "art", "title.jpg")
OUT = os.path.join(ROOT, "src", "title.s")

W, ROWS = 160, 21
H = ROWS * 8
BAND = 5                        # cell rows that carry the lettering
CROP_TOP, CROP_BOTTOM = 40, 80  # source rows dropped: wall above, floor below

NAME_Y, NAME_SX, NAME_SY = 3, 2, 3
SUB_Y = 29
YELLOW, BLACK, CORAL = 7, 0, 10

LANGS = ["en", "el"]            # the order of LANG_EN, LANG_EL


def dist(a, b):
    # Weighted RGB: the eye is kinder to blue than to green. Plain RGB and a
    # luma-weighted distance were tried too; this kept the wall's tiles and
    # the window's skyline, which the others flattened.
    return 2 * (a[0] - b[0]) ** 2 + 4 * (a[1] - b[1]) ** 2 + 3 * (a[2] - b[2]) ** 2


D = [[dist(C64_RGB[a], C64_RGB[b]) for b in range(16)] for a in range(16)]


def painting():
    src = Image.open(SRC).convert("RGB")
    w, h = src.size
    src = src.crop((0, CROP_TOP, w, h - CROP_BOTTOM))
    small = src.resize((W, H), Image.LANCZOS)
    px = small.load()
    return [[min(range(16), key=lambda c: dist(px[x, y], C64_RGB[c]))
             for x in range(W)] for y in range(H)]


def letters(lang):
    """The lettering as {(x, y): colour}: name with its shadow, subtitle."""
    glyphs = mktext64.read_font()
    index = {(" " if n == "SPACE" else n): i for i, (n, _) in enumerate(glyphs)}
    text = mktext64.read_strings(os.path.join(ROOT, "text", "loukoumas.%s.txt" % lang))
    out = {}

    def draw(msg, y, sx, sy, colour, dx=0, dy=0):
        codes = [index[mktext64.fold(ch)] for ch in text[msg]]
        x0 = (W - len(codes) * 6 * sx) // 2
        for i, code in enumerate(codes):
            rows = glyphs[code][1]
            for gy in range(7):
                for gx in range(5):
                    if rows[gy] & (0x40 >> gx):
                        for yy in range(sy):
                            for xx in range(sx):
                                out[(x0 + (i * 6 + gx) * sx + xx + dx,
                                     y + gy * sy + yy + dy)] = colour

    draw("TITLE1", NAME_Y, NAME_SX, NAME_SY, BLACK, 1, 2)     # the shadow
    draw("TITLE1", NAME_Y, NAME_SX, NAME_SY, YELLOW)
    sub = {}
    saved, out = out, sub
    draw("TITLE2", SUB_Y, 1, 1, CORAL)
    out = saved
    for (x, y) in sub:          # a black rim round the subtitle, so it reads
        for dx in (-1, 0, 1):   # over the tiles of the wall
            for dy in (-1, 0, 1):
                if (x + dx, y + dy) not in sub:
                    out[(x + dx, y + dy)] = BLACK
    out.update(sub)
    return out


def cells(img, bg, locked=None):
    """Choose each cell's three colours; return the bitmap, screen and colour
    RAM, and the total error."""
    locked = locked or {}
    bmp, scr, col = bytearray(ROWS * 320), bytearray(ROWS * 40), bytearray(ROWS * 40)
    cost = 0
    for cr in range(ROWS):
        for cc in range(40):
            count = {}
            must = set()
            for y in range(cr * 8, cr * 8 + 8):
                for x in range(cc * 4, cc * 4 + 4):
                    c = locked.get((x, y), img[y][x])
                    count[c] = count.get(c, 0) + 1
                    if (x, y) in locked and locked[(x, y)] != bg:
                        must.add(locked[(x, y)])
            if len(must) > 3:
                sys.exit("mktitle64: cell %d,%d needs %d colours for the lettering"
                         % (cc, cr, len(must)))
            others = [c for c in count if c != bg and c not in must]
            best, best_cost = None, None
            need = 3 - len(must)

            def combos(pool, k):
                if k == 0 or not pool:
                    yield []
                    return
                for i, c in enumerate(pool):
                    for rest in combos(pool[i + 1:], k - 1):
                        yield [c] + rest
            for extra in combos(others, min(need, len(others))):
                pal = sorted(must) + extra
                e = sum(n * min(D[c][p] for p in pal + [bg]) for c, n in count.items())
                if best_cost is None or e < best_cost:
                    best, best_cost = pal, e
            cost += best_cost
            pal = best + [None] * (3 - len(best))
            choices = [(0, bg)] + [(k + 1, p) for k, p in enumerate(pal) if p is not None]
            for y in range(8):
                byte = 0
                for k in range(4):
                    x, yy = cc * 4 + k, cr * 8 + y
                    c = locked.get((x, yy), img[yy][x])
                    slot = min(choices, key=lambda t: D[c][t[1]])[0]
                    byte |= slot << (6 - 2 * k)
                bmp[cr * 320 + cc * 8 + y] = byte
            scr[cr * 40 + cc] = ((pal[0] or 0) << 4) | (pal[1] or 0)
            col[cr * 40 + cc] = pal[2] or 0
    bmp[7] = 0                  # the byte text mode reads on the split line
    return bmp, scr, col, cost


def show(bmp, scr, col, bg, path):
    im = Image.new("RGB", (320, ROWS * 8))
    p = im.load()
    for cr in range(ROWS):
        for cc in range(40):
            cols = [bg, scr[cr * 40 + cc] >> 4, scr[cr * 40 + cc] & 15, col[cr * 40 + cc]]
            for y in range(8):
                b = bmp[cr * 320 + cc * 8 + y]
                for k in range(4):
                    c = C64_RGB[cols[(b >> (6 - 2 * k)) & 3]]
                    p[cc * 8 + 2 * k, cr * 8 + y] = c
                    p[cc * 8 + 2 * k + 1, cr * 8 + y] = c
    im.resize((640, ROWS * 16), Image.NEAREST).save(path)


def data(name, b):
    out = ["%s" % name]
    for i in range(0, len(b), 32):
        out.append("        .byte " + ",".join("$%02x" % v for v in b[i:i + 32]))
    return "\n".join(out)


def main():
    img = painting()
    freq = {}
    for row in img:
        for c in row:
            freq[c] = freq.get(c, 0) + 1
    tries = sorted(freq, key=lambda c: -freq[c])[:5]
    bg = min(tries, key=lambda c: cells(img, c)[3])

    bands = {}
    for lang in LANGS:
        bmp, scr, col, _ = cells(img, bg, letters(lang))
        bands[lang] = (bmp, scr, col)
        if "--preview" in sys.argv:
            show(bmp, scr, col, bg, os.path.join(ROOT, "build", "title-%s.png" % lang))
    bmp, scr, col = bands["en"]
    for lang in LANGS[1:]:      # below the band, the languages are one picture
        assert bands[lang][0][BAND * 320:] == bmp[BAND * 320:]

    with open(OUT, "w") as fh:
        fh.write(";; Generated by tools/mktitle64.py from assets/art/title.jpg - do not edit.\n")
        fh.write(";; Cell rows 0-%d of the bitmap; rows 0-%d once per language, with the\n"
                 ";; lettering in them, rows %d-%d once. See the tool for how.\n\n"
                 % (ROWS - 1, BAND - 1, BAND, ROWS - 1))
        fh.write("TITLE_BG    = %d\nTITLE_ROWS  = %d\nTITLE_BAND  = %d\n\n" % (bg, ROWS, BAND))
        fh.write(data("title_bmp", bmp[BAND * 320:]) + "\n")
        fh.write(data("title_scr", scr[BAND * 40:]) + "\n")
        fh.write(data("title_col", col[BAND * 40:]) + "\n\n")
        for lang in LANGS:
            b, s, c = bands[lang]
            fh.write(data("title_band_bmp_%s" % lang, b[:BAND * 320]) + "\n")
            fh.write(data("title_band_scr_%s" % lang, s[:BAND * 40]) + "\n")
            fh.write(data("title_band_col_%s" % lang, c[:BAND * 40]) + "\n\n")
        fh.write("title_band_lo .byte %s\n" % ", ".join("<title_band_bmp_%s" % l for l in LANGS))
        fh.write("title_band_hi .byte %s\n" % ", ".join(">title_band_bmp_%s" % l for l in LANGS))
    print("mktitle64: background %d, %d bytes" % (bg, (ROWS - BAND) * 400 + BAND * 400 * 2),
          file=sys.stderr)


if __name__ == "__main__":
    main()
