#!/usr/bin/env python3
"""Turn the sprite and decal art into src/sprites.s and src/art.s.

    tools/mksprite64.py

Sources, all drawn in the CPC's sixteen pens so the art is shared:

  assets/sprites.txt        the cat (cut down to 20 lines), the sausage, the
                            robot and the canary, as ASCII
  assets/art/sprite/*.png   the other enemies, and the saucer of milk
  assets/art/decal/*.png    scenery painted into the bitmap

Hardware sprites (loukc64.md 5.1). A multicolour sprite has one colour of its
own and two it shares with every other sprite; here the shared two are black
($D025) and white ($D026), which is what every outline and every eye is.
Anything with a second colour of its own gets a second sprite laid over it -
the overlay - with that colour as its own. A third colour cannot be had, so
it is mapped to the nearest of the four the pair can show, and the tool says
so: that is a drawing to look at, not an error.

Each picture is written as a frame descriptor - body pointer, overlay pointer,
body colour, overlay colour - and the blocks themselves, 64 bytes each. The
first 64 go to SPRITE_MEM, under the I/O (src/spriteblk.s); the rest to
SPRITE_MEM2, the charset slot past the font (src/spriteblk2.s). The pointers
are written as the VIC's own (SPR_PTR0 + n, SPR_PTR2 + n); an overlay with
nothing in it is 0, and is switched off.

An enemy has two pictures, its own and a second from sprites.txt (NAME2),
the same size and in the same two colours, and four descriptors in a row:
right, left, then the second picture right and left. enemy.s adds 8 to show
the second.

Pickups and decals are not sprites: they live in the bitmap. They are written
as rows of pen nibbles, two pixels a byte, left pixel in the high nibble; pen
0 is transparent. video.s draws them through the same colour allocator as the
furniture.
"""

import glob
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES_TXT = os.path.join(ROOT, "assets", "sprites.txt")
ART = os.path.join(ROOT, "assets", "art")

#: CPC pal_play as RGB, to read the PNGs.
CPC_RGB = [
    (0, 0, 128), (255, 128, 128), (255, 255, 0), (255, 255, 255),
    (0, 0, 0), (128, 128, 128), (128, 128, 0), (255, 128, 0),
    (0, 128, 0), (0, 255, 0), (0, 128, 128), (0, 255, 255),
    (128, 0, 0), (255, 0, 0), (128, 0, 128), (255, 255, 128),
]

#: CPC pen -> C64 colour for sprites. The pale yellow of the canary and the
#: mop is yellow here: sprites do not have to share it with the shelves.
SPRITE_COLOUR = [None, 10, 7, 1, 0, 12, 9, 8, 5, 13, 11, 3, 2, 10, 4, 7]

#: The C64's sixteen, "Pepto" PAL, to pick the nearest when a sprite has
#: more colours than it can show.
C64_RGB = [
    (0x00, 0x00, 0x00), (0xFF, 0xFF, 0xFF), (0x68, 0x37, 0x2B), (0x70, 0xA4, 0xB2),
    (0x6F, 0x3D, 0x86), (0x58, 0x8D, 0x43), (0x35, 0x28, 0x79), (0xB8, 0xC7, 0x6F),
    (0x6F, 0x4F, 0x25), (0x43, 0x39, 0x00), (0x9A, 0x67, 0x59), (0x44, 0x44, 0x44),
    (0x6C, 0x6C, 0x6C), (0x9A, 0xD2, 0x84), (0x6C, 0x5E, 0xB5), (0x95, 0x95, 0x95),
]

SHARED_0 = 0        # $D025, bit pair 01: black
SHARED_1 = 1        # $D026, bit pair 11: white

#: Decals drawn for sixteen pens anywhere, recoloured to live in a
#: multicolour cell: three colours in any 4 x 8, and the canopy of a tree
#: wants room for the yellow of a branch to stand on. The CPC's art is
#: shared, so the C64's changes to it are written here, pen for pen.
DECAL_REMAP = {
    "TREETOP": {2: 9, 6: 8},            # no yellow fruit, no olive shade
    "FLOWERS": {15: 2, 1: 13, 8: 9},    # one red, one yellow, one green
    "FLASK": {15: 3, 9: 11},            # white glass, cyan inside
    "PLANT": {12: 7},                   # one colour of pot
    "SWING": {12: 7, 5: 6},             # the seat and its board alike, and
                                        # a wooden frame, like the sandpit's
    "SIGN": {5: 3},                     # a white post: it stands on the floor
    "GLOBE": {5: 3},                    # a white stand: it stands on a desk
    "SLIDE": {5: 3},                    # a white frame: a shelf crosses it
}

#: Drawn facing left, so the mirror is the right-hand one.
FACES_LEFT = {"CANARY", "STRAY"}

#: Enemies, in ET_ order (enemy.s indexes the kinds table by type-1).
ENEMIES = ["ROBOT", "CANARY", "DOG", "PIGEON", "WASP", "BALL", "PLANE", "MOP",
           "BLOB", "SYRINGE", "BAT", "STRAY"]


def read_txt():
    out = {}
    name, rows, tags = None, [], set()
    for lineno, line in enumerate(open(SPRITES_TXT, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if line.startswith(":"):
            if name:
                out[name] = (rows, tags)
            parts = line[1:].split()
            name, rows, tags = parts[0], [], set(parts[1:])
            continue
        if not line.strip() or line.startswith("#"):
            continue
        if name is None:
            sys.exit("%s:%d: art before a name" % (SPRITES_TXT, lineno))
        rows.append([None if c == "." else int(c, 16) for c in line])
    if name:
        out[name] = (rows, tags)
    for n, (rows, _) in out.items():
        if len({len(r) for r in rows}) != 1:
            sys.exit("%s: %s has rows of different lengths" % (SPRITES_TXT, n))
    return out


def read_png(path):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    rows = []
    for y in range(h):
        row = []
        for x in range(w):
            r, g, b, a = im.getpixel((x, y))
            if a < 128:
                row.append(None)
                continue
            if (r, g, b) not in CPC_RGB:
                sys.exit("%s: pixel %d,%d is %02X%02X%02X, not a pen"
                         % (path, x, y, r, g, b))
            row.append(CPC_RGB.index((r, g, b)))
        rows.append(row)
    return rows


def dist(a, b):
    return sum((p - q) ** 2 for p, q in zip(C64_RGB[a], C64_RGB[b]))


def split_colours(name, rows, keep=None):
    """Choose the body colour and the overlay colour; map the rest. keep is a
    (body, overlay) to use instead: an enemy's second frame has its first's."""
    count = {}
    for row in rows:
        for p in row:
            if p is None:
                continue
            c = SPRITE_COLOUR[p]
            if c not in (SHARED_0, SHARED_1):
                count[c] = count.get(c, 0) + 1
    order = sorted(count, key=lambda c: (-count[c], c))
    body = order[0] if order else 7
    over = order[1] if len(order) > 1 else None
    if keep:
        body, over = keep
        order = [body] + ([over] if over is not None else []) + [
            c for c in order if c not in (body, over)]
    if len(order) > 2:
        print("mksprite64: %s has %d colours of its own; %s mapped to the nearest"
              % (name, len(order), ", ".join(str(c) for c in order[2:])),
              file=sys.stderr)
    choices = [body, SHARED_0, SHARED_1] + ([over] if over is not None else [])

    def colour(p):
        c = SPRITE_COLOUR[p]
        if c in choices:
            return c
        return min(choices, key=lambda k: dist(k, c))
    grid = [[None if p is None else colour(p) for p in row] for row in rows]
    return body, over, grid


def sprite_block(grid, want):
    """One 64-byte block. want(c) gives the bit pair for colour c, or None."""
    if len(grid) > 21 or len(grid[0]) > 12:
        sys.exit("sprite larger than 12 x 21")
    data = bytearray(64)
    for y, row in enumerate(grid):
        for x, c in enumerate(row):
            if c is None:
                continue
            pair = want(c)
            if pair is None:
                continue
            byte = y * 3 + x // 4
            data[byte] |= pair << (6 - 2 * (x % 4))
    return bytes(data)


def main():
    txt = read_txt()
    pics = {}           # name -> (rows, tags)
    for name, (rows, tags) in txt.items():
        pics[name] = (rows, tags)
    for path in sorted(glob.glob(os.path.join(ART, "sprite", "*.png"))):
        name = os.path.splitext(os.path.basename(path))[0].upper()
        if name in pics:
            continue            # redrawn for the C64 in sprites.txt
        rows = read_png(path)
        tags = {"pickup"} if name == "MILK" else {"flip"}
        pics[name] = (rows, tags)

    blocks = [bytes(64)]
    frames = []         # (label, body ptr, over ptr, body col, over col, w, h)
    consts = []

    def add_block(data):
        if data == bytes(64):
            return 0
        if data in blocks:
            return blocks.index(data)
        blocks.append(data)
        return len(blocks) - 1

    def add_frame(label, grid, body, over):
        b = add_block(sprite_block(grid, lambda c: {body: 2, SHARED_0: 1,
                                                    SHARED_1: 3}.get(c)))
        o = add_block(sprite_block(grid, lambda c: 2 if c == over and c != body
                                   else None)) if over is not None else 0
        frames.append((label, b, o, body, over if over is not None else 0))

    def pointer(n):
        if n == 0:
            return "0"
        return "SPR_PTR0+%d" % n if n < 64 else "SPR_PTR2+%d" % (n - 64)

    cast = ["CAT_STAND", "CAT_WALK1", "CAT_WALK2", "CAT_ROLL", "CAT_FLAT"]
    for name in cast + ENEMIES:
        rows, tags = pics[name]
        body, over, grid = split_colours(name, rows)
        h, w = len(grid), len(grid[0])
        consts.append(("SPR_%s_W" % name, w))
        consts.append(("SPR_%s_H" % name, h))
        mirror = [list(reversed(r)) for r in grid]
        if name in cast:
            add_frame("frm_" + name.lower(), grid, body, over)
            continue
        right, left = (mirror, grid) if name in FACES_LEFT else (grid, mirror)
        add_frame("frm_" + name.lower(), right, body, over)
        add_frame("frm_" + name.lower() + "_l", left, body, over)
        if name + "2" not in pics:
            sys.exit("mksprite64: %s has no second frame (%s2 in sprites.txt)"
                     % (name, name))
        _, _, grid2 = split_colours(name + "2", pics[name + "2"][0], (body, over))
        if (len(grid2), len(grid2[0])) != (h, w):
            sys.exit("mksprite64: %s2 is not the size of %s" % (name, name))
        mirror2 = [list(reversed(r)) for r in grid2]
        right, left = (mirror2, grid2) if name in FACES_LEFT else (grid2, mirror2)
        add_frame("frm_" + name.lower() + "2", right, body, over)
        add_frame("frm_" + name.lower() + "2_l", left, body, over)

    if len(blocks) > 64 + 24:
        sys.exit("mksprite64: %d sprite blocks; there is room for 64 under the "
                 "I/O and 24 past the font" % len(blocks))

    path = os.path.join(ROOT, "src", "sprites.s")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(";; Generated by tools/mksprite64.py from assets/sprites.txt and\n")
        fh.write(";; assets/art/sprite - do not edit.\n;;\n")
        fh.write(";; A frame is: body pointer, overlay pointer, body colour, overlay\n")
        fh.write(";; colour. Shared colours are black ($D025) and white ($D026).\n\n")
        for k, v in consts:
            fh.write("%-20s = %d\n" % (k, v))
        fh.write("\nSPRITE_BLOCKS        = %d\n" % len(blocks))
        fh.write("FRM_SIZE             = 4\n\n")
        for label, b, o, bc, oc in frames:
            fh.write("%-16s .byte %s, %s, %2d, %2d\n" % (label, pointer(b), pointer(o),
                                                         bc, oc))
    for fname, label, part, first, mem in (
            ("spriteblk.s", "sprite_blocks", blocks[:64], 0, "SPRITE_MEM"),
            ("spriteblk2.s", "sprite_blocks2", blocks[64:], 64, "SPRITE_MEM2")):
        path = os.path.join(ROOT, "src", fname)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(";; Generated by tools/mksprite64.py - do not edit.\n")
            fh.write(";; Sprite blocks %d-, copied to %s at boot.\n" % (first, mem))
            fh.write("%s\n" % label)
            for i, data in enumerate(part):
                fh.write("        ;; %d\n" % (first + i))
                for k in range(0, 64, 16):
                    fh.write("        .byte %s\n" % ",".join("$%02x" % v
                                                             for v in data[k:k + 16]))
            fh.write("%s_end\n" % label)

    # --- Pickups and decals: pen nibbles, into the bitmap ---------------------
    def nibbles(rows):
        w = len(rows[0])
        if w % 2:
            rows = [r + [None] for r in rows]
            w += 1
        out = []
        for r in rows:
            for x in range(0, w, 2):
                a = r[x] or 0
                b = r[x + 1] or 0
                out.append((a << 4) | b)
        return w, out

    path = os.path.join(ROOT, "src", "art.s")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(";; Generated by tools/mksprite64.py - do not edit.\n;;\n")
        fh.write(";; Pictures painted into the bitmap: width in pixels, height in lines,\n")
        fh.write(";; then rows of pen nibbles, two pixels a byte, left in the high\n")
        fh.write(";; nibble. Pen 0 is transparent.\n\n")
        sausage = pics["SAUSAGE"][0]
        milk = pics["MILK"][0]
        for label, rows in (("pick_sausage", sausage), ("pick_milk", milk)):
            w, data = nibbles(rows)
            fh.write("%s\n        .byte %d, %d\n" % (label, w, len(rows)))
            for k in range(0, len(data), w // 2):
                fh.write("        .byte %s\n" % ",".join("$%02x" % v
                                                         for v in data[k:k + w // 2]))
        fh.write("PICK_W = %d\nPICK_H = %d\n\n" % (len(sausage[0]), len(sausage)))
        # How far apart two colours look, for a pickup that has to borrow one
        # already in its cell: colour_dist[a*16+b], 0-255.
        fh.write(";; colour_dist[a*16+b]: how unlike two C64 colours look, 0-255.\n")
        fh.write("colour_dist\n")
        far = max(dist(a, b) for a in range(16) for b in range(16))
        for a in range(16):
            fh.write("        .byte %s\n" % ",".join(
                "%d" % (dist(a, b) * 255 // far) for b in range(16)))
        if len(milk) != len(sausage) or len(milk[0]) != len(sausage[0]):
            sys.exit("mksprite64: the saucer and the sausage must be one size")

        decals = sorted(glob.glob(os.path.join(ART, "decal", "*.png")))
        names = [os.path.splitext(os.path.basename(p))[0].upper() for p in decals]
        for i, n in enumerate(names):
            fh.write("DECAL_%-10s = %d\n" % (n, i))
        fh.write("DECAL_COUNT       = %d\n\ndecal_table\n" % len(names))
        for n in names:
            fh.write("        .word dec_%s\n" % n.lower())
        for path_, n in zip(decals, names):
            rows = read_png(path_)
            remap = DECAL_REMAP.get(n, {})
            rows = [[remap.get(p, p) if p is not None else None for p in r] for r in rows]
            w, data = nibbles(rows)
            fh.write("\ndec_%s\n        .byte %d, %d\n" % (n.lower(), w, len(rows)))
            for k in range(0, len(data), w // 2):
                fh.write("        .byte %s\n" % ",".join("$%02x" % v
                                                         for v in data[k:k + w // 2]))

    print("mksprite64: %d frames in %d blocks, %d decals"
          % (len(frames), len(blocks), len(decals)), file=sys.stderr)


if __name__ == "__main__":
    main()
