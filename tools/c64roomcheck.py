#!/usr/bin/env python3
"""Render every room out of the assembled program, the way the C64 does,
and refuse a room that clashes or cannot be played.

    tools/c64roomcheck.py build/loukoumas.prg build/loukoumas.lbl [--png DIR]
                          [--dump N]

The room tables are read out of the .prg through the label file, so this sees
exactly the bytes the 6502 sees. Each room is then drawn with a copy of
video.s's fill_box and its colour allocator - the same clipping, the same
order of choices - into a bitmap, a screen RAM and a colour RAM, and:

  * a cell where the finished picture is not what was drawn - some pixel
    shows a colour other than the one last painted there, because a slot
    was stolen from under it - is a clash (loukc64.md 5.2), and fails the
    check. A pickup that borrowed a colour is reported with -v, not failed.
  * every sausage and saucer stands on a platform the cat can reach, every
    platform is reachable, the cat starts on one, the way out is reachable
    and no shelf runs into it, walkers walk on something (the CPC's
    roomcheck.py, with the C64's jump)

--png writes each room as a 320 x 200 picture; --dump N writes room N's
bitmap, screen and colour RAM as raw bytes for comparison with a memory dump
taken from VICE (loukc64.md M2: the two renders must agree byte for byte).
"""

import copy
import os
import re
import sys

PEPTO = [
    (0x00, 0x00, 0x00), (0xFF, 0xFF, 0xFF), (0x68, 0x37, 0x2B), (0x70, 0xA4, 0xB2),
    (0x6F, 0x3D, 0x86), (0x58, 0x8D, 0x43), (0x35, 0x28, 0x79), (0xB8, 0xC7, 0x6F),
    (0x6F, 0x4F, 0x25), (0x43, 0x39, 0x00), (0x9A, 0x67, 0x59), (0x44, 0x44, 0x44),
    (0x6C, 0x6C, 0x6C), (0x9A, 0xD2, 0x84), (0x6C, 0x5E, 0xB5), (0x95, 0x95, 0x95),
]

SCREEN_W, SCREEN_H = 160, 200
LMASK = [0xFF, 0x3F, 0x0F, 0x03]
RMASK = [0xC0, 0xF0, 0xFC, 0xFF]
SLOT_PAT = [0x00, 0x55, 0xAA, 0xFF]


def ptab(b):
    bits = 0
    for k in range(4):
        bits |= 1 << ((b >> (2 * k)) & 3)
    return bits


PTAB = [ptab(b) for b in range(256)]


class Prog:
    def __init__(self, prg, lbl):
        data = open(prg, "rb").read()
        self.load = data[0] | (data[1] << 8)
        self.mem = bytearray(0x10000)
        self.mem[self.load:self.load + len(data) - 2] = data[2:]
        self.sym = {}
        for line in open(lbl):
            m = re.match(r"^(\w+)\s*=\s*(~?\$[0-9a-fA-F]+|-?\d+)", line)
            if m:
                v = m.group(2)
                if v.startswith("~"):           # 64tass writes -n as ~(n-1)
                    self.sym[m.group(1)] = ~int(v[2:], 16)
                else:
                    self.sym[m.group(1)] = int(v[1:], 16) if v.startswith("$") else int(v)

    def __getitem__(self, a):
        return self.mem[a]

    def word(self, a):
        return self.mem[a] | (self.mem[a + 1] << 8)

    def c(self, name):
        if name not in self.sym:
            sys.exit("c64roomcheck: %s is not in the label file" % name)
        return self.sym[name]


class Screen:
    """bitmap, screen RAM and colour RAM, and fill_box exactly as video.s."""

    def __init__(self, pen_colour, clip_top):
        self.bmp = bytearray(8000)
        self.scr = bytearray(1000)
        self.col = bytearray(1000)
        self.pen_colour = pen_colour
        self.clip_top = clip_top
        self.clashes = []
        self.soft = False
        self.borrowed = []
        self.bg = 0
        self.who = ""
        self.why = {}
        # What the picture should be, a colour per pixel, as if a cell could
        # hold sixteen: None is the background. soft marks a pickup's pixel.
        self.truth = [[None] * SCREEN_W for _ in range(SCREEN_H)]
        self.soft_px = set()
        self.touched = None     # a set: the cells fill_box paints, when kept

    def fill_box(self, bx, by, bw, bh, pen):
        if bw == 0 or bh == 0 or bx >= SCREEN_W:
            return
        if bx + bw > SCREEN_W:
            bw = SCREEN_W - bx
        if by < self.clip_top:
            cut = self.clip_top - by
            if bh <= cut:
                return
            bh -= cut
            by = self.clip_top
        if by >= SCREEN_H:
            return
        if by + bh > SCREEN_H:
            bh = SCREEN_H - by
        colour = self.pen_colour[pen]
        for y in range(by, by + bh):
            for x in range(bx, bx + bw):
                self.truth[y][x] = None if pen == 0 else colour
                if self.soft:
                    self.soft_px.add((x, y))
                else:
                    self.soft_px.discard((x, y))
        bx1, by1 = bx + bw - 1, by + bh - 1
        cc0, cc1, cr0, cr1 = bx >> 2, bx1 >> 2, by >> 3, by1 >> 3
        for cr in range(cr0, cr1 + 1):
            ly0 = by & 7 if cr == cr0 else 0
            ly1 = by1 & 7 if cr == cr1 else 7
            for cc in range(cc0, cc1 + 1):
                mask = LMASK[bx & 3 if cc == cc0 else 0] & RMASK[bx1 & 3 if cc == cc1 else 3]
                nmask = mask ^ 0xFF
                cell = cr * 40 + cc
                base = cr * 320 + cc * 8
                if self.touched is not None:
                    self.touched.add(cell)
                slot = self.alloc(pen, colour, cell, base, ly0, ly1, nmask)
                pat = SLOT_PAT[slot] & mask
                for ly in range(ly0, ly1 + 1):
                    self.bmp[base + ly] = (self.bmp[base + ly] & nmask) | pat

    def alloc(self, pen, colour, cell, base, ly0, ly1, nmask):
        if pen == 0:
            return 0
        if self.scr[cell] >> 4 == colour:
            return 1
        if self.scr[cell] & 15 == colour:
            return 2
        if self.col[cell] & 15 == colour:
            return 3
        pres = 0
        for y in range(8):
            b = self.bmp[base + y]
            if ly0 <= y <= ly1:
                b &= nmask
            pres |= PTAB[b]
        if not pres & 2:
            self.scr[cell] = (self.scr[cell] & 0x0F) | (colour << 4)
            return 1
        if not pres & 4:
            self.scr[cell] = (self.scr[cell] & 0xF0) | colour
            return 2
        if pres & 8:
            if self.soft:
                cands = [self.bg, self.scr[cell] >> 4, self.scr[cell] & 15,
                         self.col[cell] & 15]
                best = 0
                for k in range(1, 4):
                    if DIST[colour][cands[k]] < DIST[colour][cands[best]]:
                        best = k
                self.borrowed.append(cell)
                return best
            self.clashes.append(cell)
            self.why.setdefault(cell, "%s: colour %d over %d,%d,%d" % (
                self.who, colour, self.scr[cell] >> 4, self.scr[cell] & 15,
                self.col[cell] & 15))
        self.col[cell] = colour
        return 3

    def draw_pic(self, p, addr, x, y):
        w, h = p[addr], p[addr + 1]
        addr += 2
        for row in range(h):
            pens = []
            for i in range(w):
                b = p[addr + (i >> 1)]
                pens.append(b >> 4 if i % 2 == 0 else b & 15)
            run_x, run_pen = 0, 0
            for i in range(w + 1):
                pen = pens[i] if i < w else 0xFF
                if pen != run_pen:
                    if run_pen not in (0, 0xFF):
                        self.fill_box(x + run_x, y, i - run_x, 1, run_pen)
                    run_pen, run_x = pen, i
            addr += w // 2
            y += 1

    def shown(self, x, y, bg):
        cr, cc = y >> 3, x >> 2
        cell = cr * 40 + cc
        pair = (self.bmp[cr * 320 + cc * 8 + (y & 7)] >> (6 - 2 * (x & 3))) & 3
        return [bg, self.scr[cell] >> 4, self.scr[cell] & 15, self.col[cell] & 15][pair]

    def wrong_cells(self, bg):
        """Cells where what is shown is not what was drawn: (hard, soft)."""
        hard, soft = set(), set()
        for y in range(SCREEN_H):
            for x in range(SCREEN_W):
                want = self.truth[y][x]
                want = bg if want is None else want
                if self.shown(x, y, bg) != want:
                    cell = (y >> 3) * 40 + (x >> 2)
                    (soft if (x, y) in self.soft_px else hard).add(cell)
        return hard, soft

    def save(self, cc, cr, nc, nr):
        out = []
        for r in range(cr, cr + nr):
            for c in range(cc, cc + nc):
                cell = r * 40 + c
                out.append((cell, bytes(self.bmp[r * 320 + c * 8:r * 320 + c * 8 + 8]),
                            self.scr[cell], self.col[cell]))
        return out

    def image(self, bg):
        from PIL import Image
        im = Image.new("RGB", (320, 200))
        px = im.load()
        for cr in range(25):
            for cc in range(40):
                cell = cr * 40 + cc
                cols = [bg, self.scr[cell] >> 4, self.scr[cell] & 15, self.col[cell] & 15]
                for ly in range(8):
                    b = self.bmp[cr * 320 + cc * 8 + ly]
                    for k in range(4):
                        c = PEPTO[cols[(b >> (6 - 2 * k)) & 3]]
                        px[cc * 8 + k * 2, cr * 8 + ly] = c
                        px[cc * 8 + k * 2 + 1, cr * 8 + ly] = c
        return im


def read_list(p, addr, size):
    out = []
    while p[addr] != 0xFF:
        out.append(tuple(p[addr + k] for k in range(size)))
        addr += size
    return out


def gap(a0, a1, b0, b1):
    if a1 >= b0 and b1 >= a0:
        return 0
    return b0 - a1 if b0 > a1 else a0 - b1


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    png_dir = None
    dump = None
    if "--png" in sys.argv:
        png_dir = sys.argv[sys.argv.index("--png") + 1]
        args.remove(png_dir)
    if "--dump" in sys.argv:
        dump = int(sys.argv[sys.argv.index("--dump") + 1])
        args.remove(str(dump))
    p = Prog(args[0], args[1])
    c = p.c

    pen_colour = [p[c("pen_colour") + i] for i in range(16)]
    size = c("R_SIZE")
    floor_y, shelf_h, cat_h, cat_w = c("FLOOR_Y"), c("SHELF_H"), c("CAT_H"), c("CAT_W")
    pick_w, pick_h = c("PICK_W"), c("PICK_H")
    rise = c("JUMP_RISE")
    across_up = 33              # the CPC's 20 bytes, at 1.67 px a byte
    across_level = 47           # its 28
    bad = []
    warn = []
    total_clash = 0
    exit_cells_max = 0
    global DIST
    DIST = [[p[c("colour_dist") + a * 16 + b] for b in range(16)] for a in range(16)]

    for i in range(c("ROOM_COUNT")):
        r = c("rooms") + i * size
        g = lambda k: p[r + c(k)]
        w = lambda k: p.word(r + c(k))
        n = i + 1

        def fail(msg):
            bad.append("room %d: %s" % (n, msg))

        s = Screen(pen_colour, c("PLAY_TOP"))

        prop_names = {v: k for k, v in p.sym.items() if k.startswith("PROP_")}
        decal_names = {v: k for k, v in p.sym.items() if k.startswith("DECAL_")}

        def draw_prop(pid, x, y):
            s.who = "%s at %d,%d" % (prop_names.get(pid, pid), x, y)
            for dx, dy, bw, bh, pen in read_list(p, p.word(c("prop_boxes") + 2 * pid), 5):
                if y + dy > 255:
                    continue
                s.fill_box((x + dx) & 0xFF, y + dy, bw, bh, pen)

        props = read_list(p, w("R_PROPS"), 3)
        for pid, x, y in props:
            if pid & 0x80:
                s.who = "%s at %d,%d" % (decal_names.get(pid & 0x7F), x, y)
                s.draw_pic(p, p.word(c("decal_table") + 2 * (pid & 0x7F)), x, y)
            else:
                draw_prop(pid, x, y)
        plats = read_list(p, w("R_PLAT"), 3)
        s.fill_box(0, floor_y + shelf_h, SCREEN_W, SCREEN_H - floor_y - shelf_h, g("R_FLOOR"))
        for x0, x1, y in plats:
            s.who = "shelf %d..%d at %d" % (x0, x1, y)
            s.fill_box(x0, y, x1 - x0 + 1, shelf_h, 2)
        draw_prop(g("R_EXITSHUT"), g("R_EXITPX"), g("R_EXITPY"))

        # The way out, open, painted over the room as it stands before the
        # pickups go down: what room_load keeps a copy of (exit_save) and the
        # fifth sausage puts back. It must not clash either, and its cells
        # must fit EXIT_BUF.
        so = copy.deepcopy(s)
        so.touched = set()
        draw_prop_on = s
        s = so
        draw_prop(g("R_EXITOPEN"), g("R_EXITPX"), g("R_EXITPY"))
        s = draw_prop_on
        if not so.touched:
            fail("the open way out draws nothing")
        else:
            ccs = [cl % 40 for cl in so.touched]
            crs = [cl // 40 for cl in so.touched]
            ncells = (max(ccs) - min(ccs) + 1) * (max(crs) - min(crs) + 1)
            exit_cells_max = max(exit_cells_max, ncells)
            if ncells > c("EXIT_CELLS"):
                fail("the open way out covers %d cells; EXIT_BUF holds %d"
                     % (ncells, c("EXIT_CELLS")))
        open_hard, _ = so.wrong_cells(g("R_LIGHT"))
        if open_hard:
            total_clash += len(open_hard)
            fail("the open way out: %d cells clash: %s" % (len(open_hard), " ".join(
                "%d,%d" % (cl % 40, cl // 40) for cl in sorted(open_hard)[:12])))
        sa = w("R_SAUS")
        picks = [(p[sa + 2 * k], p[sa + 2 * k + 1], "pick_sausage") for k in range(g("R_NSAUS"))]
        if g("R_MILKX") != c("NO_MILK"):
            picks.append((g("R_MILKX"), g("R_MILKY"), "pick_milk"))
        s.soft = True
        s.bg = g("R_LIGHT")
        for x, y, what in picks:
            s.draw_pic(p, c(what), x, y)
        s.soft = False

        hard, soft_cells = s.wrong_cells(g("R_LIGHT"))
        s.clashes = sorted(hard)
        if s.clashes:
            cells = s.clashes
            total_clash += len(cells)
            fail("%d cells clash: %s" % (len(cells), " ".join(
                "%d,%d" % (cl % 40, cl // 40) for cl in cells[:12])
                + (" ..." if len(cells) > 12 else "")))
            if "-v" in sys.argv:
                for cl in cells:
                    bad.append("    cell %d,%d (x %d, y %d): %s" % (
                        cl % 40, cl // 40, cl % 40 * 4, cl // 40 * 8,
                        s.why.get(cl, "?")))
        if soft_cells:
            warn.append("room %d: a pickup borrows a colour in %d cells: %s" % (
                n, len(soft_cells), " ".join("%d,%d" % (cl % 40, cl // 40)
                                            for cl in sorted(soft_cells))))

        if png_dir:
            os.makedirs(png_dir, exist_ok=True)
            im = s.image(g("R_LIGHT"))
            if "--marks" in sys.argv:       # every clash, ringed in red
                px = im.load()
                for cl in set(s.clashes):
                    cr, cc = divmod(cl, 40)
                    for k in range(8):
                        for x, y in ((cc * 8 + k, cr * 8), (cc * 8 + k, cr * 8 + 7),
                                     (cc * 8, cr * 8 + k), (cc * 8 + 7, cr * 8 + k)):
                            px[x, y] = (255, 0, 0)
            im.save(os.path.join(png_dir, "room%02d.png" % n))
        if dump == n:
            open("build/room%02d.bin" % n, "wb").write(bytes(s.bmp) + bytes(s.scr) + bytes(s.col))

        # --- can it be played? -------------------------------------------
        start = None
        for k, (x0, x1, y) in enumerate(plats):
            if y == g("R_STARTY") + cat_h and x0 <= g("R_STARTX") <= x1:
                start = k
        if start is None:
            fail("the cat starts on nothing")
            continue
        seen, edge = {start}, [start]
        while edge:
            k = edge.pop()
            x0, x1, y = plats[k]
            for j, (nx0, nx1, ny) in enumerate(plats):
                if j in seen or y - ny > rise:
                    continue
                if gap(x0, x1, nx0, nx1) > (across_up if y > ny else across_level):
                    continue
                seen.add(j)
                edge.append(j)
        for k, (x0, x1, y) in enumerate(plats):
            if k not in seen:
                fail("platform %d..%d at y=%d cannot be reached" % (x0, x1, y))
        for k, (x, y, what) in enumerate(picks):
            on = [j for j, (x0, x1, py) in enumerate(plats)
                  if py == y + pick_h and x0 <= x and x + pick_w <= x1 + 1]
            if not on:
                fail("%s %d at %d,%d stands on nothing" % (what[5:], k + 1, x, y))
            elif not set(on) & seen:
                fail("%s %d at %d,%d is out of reach" % (what[5:], k + 1, x, y))
        ex, ey, ew, eh = g("R_EXITX"), g("R_EXITY"), g("R_EXITW"), g("R_EXITH")
        if not any(ex + ew > x0 and x1 + 1 > ex and ey + eh > y - cat_h and y > ey
                   for j, (x0, x1, y) in enumerate(plats) if j in seen):
            fail("the way out cannot be reached")
        ea = w("R_ENEM")
        for k in range(g("R_NENEM")):
            t, x, y, dx, x0, x1, base = (p[ea + 7 * k + q] for q in range(7))
            ew_, eh_ = p[c("ek_w") + t - 1], p[c("ek_h") + t - 1]
            if x1 + ew_ > SCREEN_W:
                fail("enemy %d patrols past the right edge" % (k + 1))
            if p[c("ek_behaviour") + t - 1] == c("EB_WALK"):
                if not any(py == y + eh_ and px0 <= x0 and x1 + ew_ <= px1 + 1
                           for px0, px1, py in plats):
                    fail("enemy %d walks on nothing" % (k + 1))

    if "-v" in sys.argv:
        for line in warn:
            print("c64roomcheck: warning: " + line)
    for line in bad:
        print("c64roomcheck: " + line)
    if bad:
        print("c64roomcheck: %d problems, %d clashing cells" % (len(bad), total_clash))
        sys.exit(1)
    print("c64roomcheck: %d rooms, no clash shut or open, every sausage and way out"
          " reachable (%d pickups borrow a colour; -v lists them); the largest open"
          " way out is %d cells" % (c("ROOM_COUNT"), len(warn), exit_cells_max))


LIGHTS = {}

if __name__ == "__main__":
    main()
