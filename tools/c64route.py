#!/usr/bin/env python3
"""Find a route through a room with the Python model of the game.

    tools/c64route.py build/loukoumas.prg build/loukoumas.lbl ROOM [--all]

A beam search over short bursts of input - stand, walk, jump, jump across,
belly-flop, roll - six frames each, scored by sausages eaten and distance to
the next one, and thrown away the moment a life is lost. It answers the
question loukc64.md 13 asks of the new geometry: can every room still be
finished, on hard, without losing a life? And it writes the route in the
syntax tools/c64sim.py, tools/c64run.py and tools/mkscript.py take, so the
answer can be played in VICE.

--all runs every room and prints one line each.
"""

import copy
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import c64roomcheck   # noqa: E402
import c64sim         # noqa: E402

U, D, L, R, F = 1, 2, 4, 8, 16
STEP = 6
#: name, the controls for each of the six frames
MACROS = [
    ("wait", [0] * STEP),
    ("left", [L] * STEP),
    ("right", [R] * STEP),
    ("jump", [U] + [0] * (STEP - 1)),
    ("jumpl", [U | L] + [L] * (STEP - 1)),
    ("jumpr", [U | R] + [R] * (STEP - 1)),
    ("flop", [D | F] + [D] * (STEP - 1)),
    ("rolll", [D | L] * STEP),
    ("rollr", [D | R] * STEP),
]
NAMES = {U: "UP", D: "DOWN", L: "LEFT", R: "RIGHT", F: "FIRE"}


def target(g):
    """Where the cat should be going: the nearest sausage, then the door."""
    best = None
    for x, y, alive in g.picks:
        if alive:
            d = abs(x - g.x) + 3 * abs(y - (g.y + g.h - 5))
            best = d if best is None else min(best, d)
    if best is None:
        ex, ey, ew, eh = g.exit
        best = abs(ex + ew // 2 - g.x - 6) + 3 * abs(ey + eh - g.y - g.h)
    return best


def score(g):
    return g.got * 10000 - target(g) - g.frame // 4


def key(g):
    return (g.x, g.xf >> 6, g.y, g.state, g.vy, g.stun,
            tuple(a for _, _, a in g.picks),
            tuple(e["stun"] > 0 for e in g.en))


def search(p, room, beam=300, limit=3000):
    start = c64sim.Game(p, room)
    start.prev = 0
    frontier = [(start, [])]
    for _ in range(limit // STEP):
        nxt = {}
        for g, moves in frontier:
            for name, ctls in MACROS:
                h = copy.deepcopy(g)
                h.events = []
                result = None
                for c in ctls:
                    result = h.step(c)
                    h.frame += 1
                    if result or h.lives < h.start_lives:
                        break
                if h.lives < h.start_lives:
                    continue
                m = moves + [ctls]
                if result == "exit":
                    return m, h
                k = key(h)
                if k not in nxt or score(h) > score(nxt[k][0]):
                    nxt[k] = (h, m)
        frontier = sorted(nxt.values(), key=lambda t: -score(t[0]))[:beam]
        if not frontier:
            return None, None
    return None, frontier[0][0] if frontier else None


def as_route(moves):
    """Frame-by-frame controls -> the route syntax: runs of each bit."""
    frames = [c for m in moves for c in m]
    out = []
    for bit, name in NAMES.items():
        f = 0
        while f < len(frames):
            if frames[f] & bit:
                g = f
                while g + 1 < len(frames) and frames[g + 1] & bit:
                    g += 1
                out.append((f, "%s@%d-%d" % (name, f, g)))
                f = g + 1
            else:
                f += 1
    return ",".join(r for _, r in sorted(out))


def main():
    p = c64roomcheck.Prog(sys.argv[1], sys.argv[2])
    rooms = range(p.c("ROOM_COUNT")) if "--all" in sys.argv else [int(sys.argv[3])]
    bad = 0
    for room in rooms:
        moves, g = search(p, room)
        if moves is None:
            bad += 1
            print("room %2d: no route found (best: %d/%d sausages)"
                  % (room + 1, g.got if g else 0, g.nsaus if g else 0))
            continue
        route = as_route(moves)
        # Play it again from the top, the way the other tools will.
        g2, r = c64sim.run(p, room, route)
        ok = r == "exit" and g2.lives == g2.start_lives
        print("room %2d: %s in %d frames%s" % (room + 1, "out" if ok else "REPLAY FAILED",
                                               len(moves) * STEP,
                                               "" if "--all" in sys.argv else "\n" + route))
        if not ok:
            bad += 1
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
