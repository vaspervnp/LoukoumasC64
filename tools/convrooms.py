#!/usr/bin/env python3
"""Carry the CPC's twenty-nine rooms over to the C64's geometry, once.

    tools/convrooms.py [../LoukoumasCPC]  >  src/rooms.s

This is the first step of loukc64.md section 14: it reads the room tables out
of an assembled CPC build (the same way the CPC's tools/roomcheck.py does, so
it sees exactly the bytes the Z80 sees) and scales every number in them:

    x  CPC bytes (2 px of 192)   ->  C64 multicolour pixels of 160:  x * 5/3
    y  CPC scanlines             ->  C64 lines, anchored on the floor:
          above the floor  181 - (236 - y) * 3/4
          in the floor     181 + (y - 236) * 19/36

Box lists are scaled relative to their own origin, edge by edge, so boxes that
touched on the CPC still touch here. Sausages, saucers, walkers and the cat's
start are re-seated on whatever platform they stood on, with the C64 sprite
heights, so nothing ends up hanging in the air after the rounding.

The output is source, not a build product: once written it is committed and
edited by hand like any other room table. Re-running this throws those edits
away, which is why the Makefile never does.
"""

import os
import re
import sys

CPC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "..", "LoukoumasCPC")

CPC_FLOOR = 236
C64_FLOOR = 181
SHELF_STEP_CPC = 32
SHELF_STEP_C64 = 24

ENEMY_NAMES = ["", "ROBOT", "CANARY", "DOG", "PIGEON", "WASP", "BALL", "PLANE",
               "MOP", "BLOB", "SYRINGE", "BAT", "STRAY"]
FLYERS = {"CANARY", "PIGEON", "WASP", "PLANE", "SYRINGE", "BAT"}

#: The CPC hardware colour a room is lit by -> the C64 colour.
LIGHT = {4: ("LIGHT_INDOOR", 6), 23: ("LIGHT_DAY", 14), 20: ("LIGHT_NIGHT", 0)}


def rnd(v):
    return int(v + 0.5) if v >= 0 else -int(-v + 0.5)


def X(x):
    return rnd(x * 5 / 3)


def Y(y):
    if y <= CPC_FLOOR:
        return C64_FLOOR - rnd((CPC_FLOOR - y) * 3 / 4)
    return C64_FLOOR + rnd((y - CPC_FLOOR) * 19 / 36)


def sym_y(y):
    """A C64 line, spelt as the grid constant it is when it is one."""
    if y == C64_FLOOR:
        return "FLOOR_Y"
    for n in range(1, 6):
        if y == C64_FLOOR - n * SHELF_STEP_C64:
            return "SHELF_%d" % n
    return str(y)


class Build:
    def __init__(self, root):
        b = os.path.join(root, "build")
        self.mem = bytearray(0x10000)
        code = open(os.path.join(b, "loukoumas_en.bin"), "rb").read()
        self.mem[0x4000:0x4000 + len(code)] = code
        self.sym = {}
        for line in open(os.path.join(b, "loukoumas_en.sym")):
            m = re.match(r"^(\S+)\s+#([0-9A-Fa-f]+)\s", line)
            if m:
                self.sym[m.group(1).upper()] = int(m.group(2), 16)
        tables = open(os.path.join(b, "tables.bin"), "rb").read()
        dest = self.c("DATA_ORG")
        self.mem[dest:dest + len(tables)] = tables

    def __getitem__(self, a):
        return self.mem[a]

    def word(self, a):
        return self.mem[a] | (self.mem[a + 1] << 8)

    def c(self, name):
        return self.sym[name.upper()]

    def sbyte(self, a):
        v = self.mem[a]
        return v - 256 if v > 127 else v


def source_comments(src):
    """The CPC's words for its tables: for each label, the ;; block above it
    and the comment on each data line under it, in order."""
    lines = src.split("\n")
    out = {}
    for i, line in enumerate(lines):
        m = re.match(r"^(\w+)\s*$", line)
        if not m:
            continue
        label = m.group(1)
        above = []
        k = i - 1
        while k >= 0 and (re.match(r"^\w+\s+EQU", lines[k]) or not lines[k].strip()):
            k -= 1              # the room's own constants sit between
        while k >= 0 and lines[k].startswith(";;"):
            above.insert(0, lines[k])
            k -= 1
        per_line = []
        k = i + 1
        while k < len(lines) and not re.match(r"^\w", lines[k]):
            t = lines[k].strip()
            if t.lower().startswith("defb"):
                c = t.split(";", 1)[1].strip() if ";" in t else ""
                if "#FF" not in t.upper().split(";")[0]:
                    per_line.append(c)
            k += 1
        out[label] = (above, per_line)
    return out


def com(c):
    return "      ; " + c if c else ""


def read_list(b, addr, size):
    out = []
    while b[addr] != 0xFF:
        out.append(tuple(b[addr + k] for k in range(size)))
        addr += size
    return out


def main():
    b = Build(CPC)
    src = open(os.path.join(CPC, "src", "rooms.asm"), encoding="utf-8").read()

    # Prop ids and the box list each one names, in prop_boxes order.
    prop_ids = {}
    for m in re.finditer(r"^(PROP_\w+)\s+EQU\s+(\d+)", src, re.M):
        prop_ids[int(m.group(2))] = m.group(1)
    block = src[src.index("prop_boxes"):src.index(";; The furniture")]
    box_labels = re.findall(r"box_\w+", block)
    art = open(os.path.join(CPC, "src", "artwork.asm"), encoding="utf-8").read()
    decal_ids = {}
    for m in re.finditer(r"^DECAL_(\w+)\s+EQU\s+(\d+)", art, re.M):
        if m.group(1) != "COUNT":
            decal_ids[int(m.group(2))] = "DECAL_" + m.group(1)

    spr_cpc = {}
    for name in ENEMY_NAMES[1:] + ["SAUSAGE", "MILK", "CAT_STAND"]:
        spr_cpc[name] = (b.c("SPR_%s_W" % name), b.c("SPR_%s_H" % name))

    notes = source_comments(src)
    out = []
    w = out.append
    w(";; " + "=" * 75)
    w(";; rooms.s - the flat, the school and the way home, in C64 geometry.")
    w(";;")
    w(";; First written by tools/convrooms.py from the CPC's tables (x * 5/3,")
    w(";; y * 3/4 about the floor), and edited by hand from there on. Every")
    w(";; number is a multicolour pixel across (0-159) or a raster line down")
    w(";; (0-199, the HUD is 0-15). See config.s for the grid.")
    w(";;")
    w(";; A box is dx, dy, width, height, pen. Pens are the CPC's sixteen, mapped")
    w(";; to C64 colours by pen_colour in video.s; pen 0 is the room's light,")
    w(";; which takes no colour slot in the cell.")
    w(";; " + "=" * 75)
    w("")
    for k in sorted(prop_ids):
        w("%-18s = %d" % (prop_ids[k], k))
    w("")
    w("prop_boxes")
    for i in range(0, len(box_labels), 4):
        w("        .word " + ", ".join(box_labels[i:i + 4]))
    w("")

    base = b.c("PROP_BOXES")
    for i, label in enumerate(box_labels):
        boxes = read_list(b, b.word(base + 2 * i), 5)
        above, per = notes.get(label, ([], []))
        for line in above:
            if not line.startswith(";; ----"):
                w(line)
        w(label)
        for bi, (dx, dy, bw, bh, pen) in enumerate(boxes):
            x0, x1 = X(dx), X(dx + bw)
            y0, y1 = rnd(dy * 3 / 4), rnd((dy + bh) * 3 / 4)
            if x1 == x0:
                x1 = x0 + 1
            if y1 == y0:
                y1 = y0 + 1
            w("        .byte %3d,%4d,%4d,%4d, %2d%s" % (x0, y0, x1 - x0, y1 - y0, pen,
                                                 com(per[bi] if bi < len(per) else "")))
        w("        .byte $ff")
        w("")
    w("")

    size = b.c("R_SIZE")
    rbase = b.c("ROOMS")
    off = {k: b.c(k) for k in ("R_NAME", "R_PLAT", "R_SAUS", "R_NSAUS", "R_ENEM",
                               "R_NENEM", "R_PROPS", "R_EXITPX", "R_EXITPY",
                               "R_EXITX", "R_EXITY", "R_EXITW", "R_EXITH",
                               "R_EXITSHUT", "R_EXITOPEN", "R_STARTX",
                               "R_STARTY", "R_MILKX", "R_MILKY", "R_PAL",
                               "R_FLOOR")}
    records = []
    bodies = []
    for i in range(b.c("ROOM_COUNT")):
        r = rbase + i * size
        g = lambda k: b[r + off[k]]
        n = i + 1
        plats = read_list(b, b.word(r + off["R_PLAT"]), 3)

        def plat_y(cy):
            v = Y(cy)
            k = (v - 5) % 8
            if k == 7:          # one line short of the cell grid: snap to it
                v += 1
            elif k == 1:
                v -= 1
            return v

        cplats = [(X(x0), X(x1 + 1) - 1, plat_y(y)) for x0, x1, y in plats]

        def seat(cx, cy, cw_bytes, ch, what):
            """Find the CPC platform (cx, cy+ch) stands on; return its C64 index."""
            for k, (x0, x1, y) in enumerate(plats):
                if y == cy + ch and x0 <= cx + cw_bytes - 1 and cx <= x1:
                    return k
            sys.exit("room %d: %s at %d,%d stands on nothing" % (n, what, cx, cy))

        body = []
        above, per = notes.get("r%d_plat" % n, ([], []))
        body.extend(above if above else [";; %d" % n])
        body.append("r%d_plat" % n)
        for k, (x0, x1, y) in enumerate(cplats):
            body.append("        .byte %3d, %3d, %-8s%s" % (x0, x1, sym_y(y),
                        com(per[k] if k < len(per) else "")))
        body.append("        .byte $ff")
        body.append("")

        def pickup(cx, cy, kind, w_px, h_sym):
            sw, sh = spr_cpc[kind]
            k = seat(cx, cy, sw, sh, kind.lower())
            x0, x1, y = cplats[k]
            x = X(cx + sw / 2) - w_px // 2
            x = max(x0, min(x, x1 + 1 - w_px))
            return x, "%s-%s" % (sym_y(y), h_sym)

        body.append("r%d_saus" % n)
        sa = b.word(r + off["R_SAUS"])
        per = notes.get("r%d_saus" % n, ([], []))[1]
        for s in range(g("R_NSAUS")):
            x, ys = pickup(b[sa + 2 * s], b[sa + 2 * s + 1], "SAUSAGE", 8, "PICK_H")
            body.append("        .byte %3d, %-14s%s" % (x, ys, com(per[s] if s < len(per) else "")))
        body.append("")

        body.append("r%d_enem" % n)
        body.append("        ;; type, x, y, dx, first x, last x, top of a flyer's arc")
        ea = b.word(r + off["R_ENEM"])
        for e in range(g("R_NENEM")):
            t, ex, ey, edx, ex0, ex1, ebase = (b[ea + 7 * e + k] for k in range(7))
            edx = edx - 256 if edx > 127 else edx
            name = ENEMY_NAMES[t]
            cw, ch = spr_cpc[name]
            x0 = X(ex0)
            x1s = "%d-SPR_%s_W" % (X(ex1 + cw), name)
            if name in FLYERS:
                ys = str(Y(ey))
                base = str(Y(ebase))
                dx = 2 if edx > 0 else -2
            else:
                k = seat(ex0, ey, ex1 - ex0 + cw, ch, name.lower())
                ys = "%s-SPR_%s_H" % (sym_y(cplats[k][2]), name)
                base = "0"
                dx = 1 if edx > 0 else -1
            per = notes.get("r%d_enem" % n, ([], []))[1]
            body.append("        .byte ET_%-7s, %3d, %-18s, %6s, %3d, %-16s, %s%s"
                        % (name, X(ex), ys, "%d&255" % dx if dx < 0 else str(dx), x0, x1s,
                           base, com(per[e] if e < len(per) else "")))
        body.append("")

        body.append("r%d_props" % n)
        per = notes.get("r%d_props" % n, ([], []))[1]
        for k, (pid, px, py) in enumerate(read_list(b, b.word(r + off["R_PROPS"]), 3)):
            if pid & 0x80:
                pname = "DECAL+" + decal_ids[pid & 0x7F]
            else:
                pname = prop_ids[pid]
            body.append("        .byte %-22s, %3d, %3d%s" % (pname, X(px), Y(py),
                        com(per[k] if k < len(per) else "")))
        body.append("        .byte $ff")
        body.append("")
        bodies.append("\n".join(body))

        # The record
        sx, sy = g("R_STARTX"), g("R_STARTY")
        k = seat(sx, sy, spr_cpc["CAT_STAND"][0], spr_cpc["CAT_STAND"][1], "the cat")
        start_y = "%s-CAT_H" % sym_y(cplats[k][2])
        mx, my = g("R_MILKX"), g("R_MILKY")
        if mx == 255:
            milk = "NO_MILK, 0"
        else:
            x, ys = pickup(mx, my, "MILK", 8, "PICK_H")
            milk = "%d, %s" % (x, ys)
        ex, ey, ew, eh = g("R_EXITX"), g("R_EXITY"), g("R_EXITW"), g("R_EXITH")
        rec = []
        rec.append("        ;; --- %d %s" % (n, "-" * 60))
        rec.append("        .byte MSG_ROOM%d" % n)
        rec.append("        .word r%d_plat, r%d_saus" % (n, n))
        rec.append("        .byte %d" % g("R_NSAUS"))
        rec.append("        .word r%d_enem" % n)
        rec.append("        .byte %d" % g("R_NENEM"))
        rec.append("        .word r%d_props" % n)
        rec.append("        .byte %d, %d" % (X(g("R_EXITPX")), Y(g("R_EXITPY"))))
        rec.append("        .byte %d, %d, %d, %d, %s, %s"
                   % (X(ex), Y(ey), X(ex + ew) - X(ex), Y(ey + eh) - Y(ey),
                      prop_ids[g("R_EXITSHUT")], prop_ids[g("R_EXITOPEN")]))
        rec.append("        .byte %d, %s" % (X(sx), start_y))
        rec.append("        .byte %s" % milk)
        rec.append("        .byte %s, %d" % (LIGHT[g("R_PAL")][0], g("R_FLOOR")))
        records.append("\n".join(rec))

    w("rooms")
    w("\n\n".join(records))
    w("rooms_end")
    w("        .cerror rooms_end-rooms != ROOM_COUNT*R_SIZE, \"a room record is the wrong size\"")
    w("")
    w("\n".join(bodies))
    print("\n".join(out))


if __name__ == "__main__":
    main()
