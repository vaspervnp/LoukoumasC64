#!/usr/bin/env python3
"""The REVIVE8BIT splash, for the loader: build/splash.bin.

    tools/mksplash64.py [--preview]

The CPC shows assets/revive8b.scr - a 16 KB mode 0 screen, with its sixteen
inks in assets/revive8b.txt - while the game loads (its louk.bas). A mode 0
screen is 160 x 200 pixels twice as wide as they are tall, which is exactly a
multicolour bitmap's shape, so the picture comes over pixel for pixel; only
its colours have to fit four to a cell. That is the title's converter
(tools/mktitle64.py), on all 25 cell rows.

The output is the bitmap, the screen RAM and the colour RAM (8000 + 1000 +
1000 bytes) and then the background colour, for the loader to unpack.
"""

import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import mktitle64   # noqa: E402
from mksprite64 import C64_RGB   # noqa: E402

#: CPC hardware colour -> RGB, for the inks the picture names.
HW_RGB = {0x54: (0, 0, 0), 0x40: (128, 128, 128), 0x4B: (255, 255, 255),
          0x4E: (255, 128, 0), 0x43: (255, 255, 128), 0x46: (0, 128, 128),
          0x5C: (128, 0, 0), 0x44: (0, 0, 128), 0x57: (0, 128, 255),
          0x5B: (128, 255, 255), 0x4C: (255, 0, 0), 0x4A: (255, 255, 0),
          0x53: (0, 255, 255), 0x47: (255, 128, 128), 0x5E: (128, 128, 0),
          0x58: (128, 0, 128)}


def inks():
    out = []
    for line in open(os.path.join(ROOT, "assets", "revive8b.txt")):
        f = line.split()
        if len(f) >= 3 and f[0].isdigit() and f[2].startswith("&"):
            out.append(int(f[2][1:], 16))
    return out


def main():
    scr = open(os.path.join(ROOT, "assets", "revive8b.scr"), "rb").read()
    ink = inks()
    img = []
    for y in range(200):
        base = (y % 8) * 2048 + (y // 8) * 80      # the CPC's screen layout
        row = []
        for xb in range(80):
            b = scr[base + xb]
            for bits in ((7, 3, 5, 1), (6, 2, 4, 0)):
                pen = sum(((b >> bit) & 1) << i for i, bit in enumerate(bits))
                rgb = HW_RGB[ink[pen]]
                row.append(min(range(16), key=lambda c: mktitle64.dist(rgb, C64_RGB[c])))
        img.append(row)
    freq = {}
    for row in img:
        for c in row:
            freq[c] = freq.get(c, 0) + 1
    tries = sorted(freq, key=lambda c: -freq[c])[:4]
    bg = min(tries, key=lambda c: mktitle64.cells(img, c, rows=25, first_byte_blank=False)[3])
    bmp, s, col, _ = mktitle64.cells(img, bg, rows=25, first_byte_blank=False)
    open(os.path.join(ROOT, "build", "splash.bin"), "wb").write(bytes(bmp) + bytes(s)
                                                                 + bytes(col) + bytes([bg]))
    if "--preview" in sys.argv:
        mktitle64.ROWS = 25
        mktitle64.show(bmp, s, col, bg, os.path.join(ROOT, "build", "splash.png"))
    print("mksplash64: background %d" % bg, file=sys.stderr)


if __name__ == "__main__":
    main()
