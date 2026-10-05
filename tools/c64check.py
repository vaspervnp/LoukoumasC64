#!/usr/bin/env python3
"""make check: the level design's test, on the C64.

    tools/c64check.py build/loukoumas.prg build/loukoumas.lbl

1. tools/c64roomcheck.py - every room renders without a colour clash, and
   every sausage, saucer and way out can be reached.
2. Room 1 as the C64 draws it, out of VICE's memory, against the Python
   render of the same tables: byte for byte (loukc64.md M2).
3. The scripted playthrough of room 1 (loukc64.md M3-M5), in Python and in
   VICE, which must agree with each other and with the CPC's asserts: the
   belly-flop freezes the robot on the heater, the cat goes through it, all
   five sausages, no life lost, and the way out leads to the next room.

Room 1's geometry is frozen while this route passes, as it is on the CPC.
"""

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import c64roomcheck   # noqa: E402
import c64sim         # noqa: E402

#: Room 1, in room frames (frame 0 is the first frame of play). Onto the
#: rack's lower shelf, across to the crates, up to the rack's upper shelf,
#: back down to the crates and a belly-flop that flattens the robot on the
#: heater; up past it onto the heater, off its end, a second flop for the
#: robot on the floor, the last sausage and out of the door.
ROOM1 = ("UP@0-1,RIGHT@30-55,UP@50-51,LEFT@80-115,UP@80-81,RIGHT@116-160,"
         "UP@161-162,DOWN@170-172,FIRE@171-172,UP@190-191,RIGHT@190-250,"
         "UP@252-253,DOWN@258-260,FIRE@259-260,LEFT@275-320,RIGHT@321-360")


def run(*args):
    r = subprocess.run([sys.executable] + list(args), capture_output=True, text=True,
                       cwd=ROOT)
    return r.returncode, r.stdout + r.stderr


def peeks(out):
    res = {}
    for line in out.splitlines():
        if " = " in line:
            k, v = line.split(" = ", 1)
            res[k.strip()] = eval(v)
    return res


def main():
    prg, lbl = sys.argv[1], sys.argv[2]
    failed = []

    code, out = run("tools/c64roomcheck.py", prg, lbl)
    print(out.strip())
    if code:
        failed.append("roomcheck")

    # --- 2. the render, both ways ----------------------------------------------
    code, out = run("tools/c64roomcheck.py", prg, lbl, "--dump", "1")
    want = open(os.path.join(ROOT, "build", "room01.bin"), "rb").read()
    code, out = run("tools/c64run.py", "--play", "", "--frames", "1", "--save",
                    "build/vice_bmp.bin:e000:ff3f", "build/vice_scr.bin:c400:c7e7",
                    "build/vice_col.bin:d800:dbe7")
    got_bmp = open(os.path.join(ROOT, "build", "vice_bmp.bin"), "rb").read()
    got_scr = open(os.path.join(ROOT, "build", "vice_scr.bin"), "rb").read()
    got_col = bytes(b & 15 for b in open(os.path.join(ROOT, "build", "vice_col.bin"), "rb").read())
    want_bmp, want_scr, want_col = want[:8000], want[8000:9000], want[9000:10000]
    # The HUD's two text rows have ink in colour RAM; the render has none.
    diffs = []
    for name, a, b, skip in (("bitmap", got_bmp, want_bmp, 0),
                             ("screen", got_scr, want_scr, 80),
                             ("colour", got_col, want_col, 80)):
        bad = [i for i in range(skip, len(b)) if a[i] != b[i]]
        if bad:
            diffs.append("%s differs at %d bytes, first at %d" % (name, len(bad), bad[0]))
    if diffs:
        failed.append("render")
        print("render: room 1 in VICE is not the Python render: " + "; ".join(diffs))
    else:
        print("render: room 1 in VICE matches the Python render byte for byte")

    # --- 3. the route ------------------------------------------------------------
    p = c64roomcheck.Prog(prg, lbl)
    g, r = c64sim.run(p, 0, ROOM1)
    sim_ok = (r == "exit" and g.got == 5 and g.lives == g.start_lives
              and any("flop lands at y=123" in e for _, e in g.events))
    print("route (sim): %s, %d/5 sausages, %d lives, out at frame %d"
          % (r, g.got, g.lives, g.frame))
    if not sim_ok:
        failed.append("route (sim)")
    exit_frame = g.frame

    code, out = run("tools/c64run.py", "--play", ROOM1, "--frames", "180",
                    "--peek", "cat_x", "cat_y", "en_stun:3")
    v = peeks(out)
    stunned = v.get("en_stun", [0, 0, 0])[1] > 0
    print("route (VICE) at 180: cat at %s,%s, heater robot stunned: %s"
          % (v.get("cat_x"), v.get("cat_y"), stunned))
    if not stunned or v.get("cat_y") != [123]:
        failed.append("flop")

    code, out = run("tools/c64run.py", "--play", ROOM1, "--frames", str(exit_frame + 5),
                    "--peek", "cur_room", "score:3", "cat_lives", "start_lives")
    v = peeks(out)
    ok = (v.get("cur_room") == [1] and v.get("score") == [0, 5, 0]
          and v.get("cat_lives") == v.get("start_lives"))
    print("route (VICE) at %d: room %s, score %s, lives %s"
          % (exit_frame + 5, v.get("cur_room"), v.get("score"), v.get("cat_lives")))
    if not ok:
        failed.append("route (VICE)")

    if failed:
        sys.exit("c64check: FAILED: " + ", ".join(failed))
    print("c64check: all passed")


if __name__ == "__main__":
    main()
