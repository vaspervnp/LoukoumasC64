#!/usr/bin/env python3
"""build/rooms/roomNN.png at 3x with the cell grid and cell numbers, for
deciding by eye what to do about a clash. A debugging aid."""
import sys
from PIL import Image, ImageDraw
n = int(sys.argv[1])
im = Image.open("build/rooms/room%02d.png" % n).resize((960, 600), Image.NEAREST)
d = ImageDraw.Draw(im)
for cc in range(0, 40):
    d.line([(cc * 24, 0), (cc * 24, 600)], fill=(90, 90, 90))
    if cc % 5 == 0:
        d.text((cc * 24 + 2, 2), str(cc), fill=(255, 255, 0))
for cr in range(0, 25):
    d.line([(0, cr * 24), (960, cr * 24)], fill=(90, 90, 90))
    d.text((2, cr * 24 + 2), str(cr), fill=(255, 255, 0))
im.save("build/rooms/view%02d.png" % n)
