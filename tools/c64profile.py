#!/usr/bin/env python3
"""make profile: every room played in VICE, and no frame overrun (loukc64.md M9).

    tools/c64profile.py [--sim] [ROOM ...]

Each route in tools/routes.txt - a clean run on hard - is played by
tools/c64run.py in a PROFILE build, and stopped on the frame after the one
the model (tools/c64sim.py) says the cat goes out on: a route goes on
pressing past the door, and in the next room that walks into things. A room passes if the cat got out (cur_room moved on, or WELL DONE
after the last), lost no life on the way, and the game loop never missed a
frame (prof_over, counted in play_loop). The worst step's logic time in
raster lines (prof_max, of 312) and the room's drawing time in frames
(prof_load) are printed for each.

This is the C64 half of what tools/c64route.py found in the model: there
every room can be finished, here the real program finishes it, in time.

--sim plays the same routes in the Python model (tools/c64sim.py) instead:
a second or two for all 29, no VICE - what CI runs when it has no ROMs.
"""

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOMS = 29
START_LIVES = 3         # hard


def routes():
    out = {}
    for line in open(os.path.join(ROOT, "tools", "routes.txt")):
        m = re.match(r"room (\d+): (.*)", line)
        if m:
            out[int(m.group(1))] = m.group(2).strip()
    return out


def model():
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import c64roomcheck
    import c64sim
    p = c64roomcheck.Prog(os.path.join(ROOT, "build", "loukoumas.prg"),
                          os.path.join(ROOT, "build", "loukoumas.lbl"))
    return p, c64sim


def play(n, route, out_frame):
    frames = out_frame + 1          # c64run halts before that frame's step
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "c64run.py"),
                        "--room", str(n - 1), "--play", route, "--frames", str(frames),
                        "--peek", "cur_room", "cat_lives", "game_over", "prof_max:2",
                        "prof_over", "prof_over_room", "prof_load",
                        "--out", os.path.join(ROOT, "build", "profile")],
                       capture_output=True, text=True, cwd=ROOT)
    if r.returncode:
        return None, r.stdout + r.stderr
    res = {}
    for line in r.stdout.splitlines():
        if " = " in line:
            k, v = line.split(" = ", 1)
            res[k.strip()] = eval(v)
    return res, ""


def simulate(table, wanted):
    p, c64sim = model()
    failed = [n for n in range(1, ROOMS + 1) if n not in table]
    for n in wanted:
        g, r = c64sim.run(p, n - 1, table[n])
        if r != "exit" or g.lives != g.start_lives:
            print("room %2d: FAILED in the model: %s, %d lives" % (n, r, g.lives))
            failed.append(n)
    if failed:
        print("c64profile: FAILED in rooms %s" % failed)
        sys.exit(1)
    print("c64profile: %d rooms played out in the model, no life lost" % len(wanted))


def main():
    table = routes()
    sim = "--sim" in sys.argv
    wanted = [int(a) for a in sys.argv[1:] if a != "--sim"] or sorted(table)
    if sim:
        return simulate(table, wanted)
    missing = [n for n in range(1, ROOMS + 1) if n not in table]
    failed = []
    worst = (0, 0)
    p, c64sim = model()
    for n in wanted:
        g, r = c64sim.run(p, n - 1, table[n])
        if r != "exit":
            print("room %2d: the model does not get out (%s)" % (n, r))
            failed.append(n)
            continue
        res, err = play(n, table[n], g.frame)
        if res is None:
            print("room %2d: c64run failed\n%s" % (n, err))
            failed.append(n)
            continue
        lines = res["prof_max"][0] | res["prof_max"][1] << 8
        out = res["cur_room"][0] == n or (n == ROOMS and res["game_over"][0])
        why = []
        if not out:
            why.append("did not get out (room %d)" % (res["cur_room"][0] + 1))
        if res["cat_lives"][0] != START_LIVES:
            why.append("lost a life")
        if res["prof_over"][0]:
            why.append("%d frames missed" % res["prof_over"][0])
        worst = max(worst, (lines, n))
        print("room %2d: worst step %3d lines, slowest room draw %d frames%s"
              % (n, lines, res["prof_load"][0], "  FAILED: " + ", ".join(why) if why else ""))
        if why:
            failed.append(n)
    if missing:
        print("c64profile: no route for rooms %s" % missing)
    if failed or missing:
        print("c64profile: FAILED in rooms %s" % failed)
        sys.exit(1)
    print("c64profile: %d rooms played out in VICE, no frame missed; the worst step "
          "is %d of 312 lines (room %d)" % (len(wanted), worst[0], worst[1]))


if __name__ == "__main__":
    main()
