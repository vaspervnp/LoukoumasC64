#!/usr/bin/env python3
"""Every screen shot the manuals and the inlay use, in both languages.

    tools/mkshots64.py            all of them
    tools/mkshots64.py lounge     just that one, both languages

A shot is a scripted run (tools/c64run.py): which room the game starts in,
the route, the frame to stop on, and any pokes. It is VICE's own screenshot
at that frame, border and all, doubled to 768 x 544 so it is the same size
as the CPC's shots and the manual and cover tools need no telling.

The game starts in English; the Greek shots press L on the title first. The
rooms are shot on hard, the game as designed, along routes the model found
(tools/c64route.py) - every one is a clean run, so the cat in the picture is
where a player who knew the room would be.
"""

import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
BUILD = os.path.join(ROOT, "build")
MENU = 91               # script frames before the first frame of play (c64run.py)

#: The title takes fire at 60 and the chooser at 90 (as in c64run.py --play).
TITLE_FIRE, CHOOSER_FIRE = "FIRE@60-62", "FIRE@90-92"

#: name, room (None: the menus), route in room frames (or script frames for
#: the menus), the frame to stop on, pokes as NAME=VALUE@FRAME.
SHOTS = [
    ("title",      None, "",                                         40, ""),
    ("difficulty", None, "FIRE@40-41",                               60, ""),
    # tools/routes.txt's room 9, which needs a belly-flop on the top shelf.
    ("lounge",        8, "UP@0-0,DOWN@5-7,FIRE@6-7,RIGHT@25-60,LEFT@61-95,"
                         "UP@96-96,RIGHT@120-168,UP@141-141,UP@170-170",  160, ""),
    # The Pitsos is only worth a picture standing open, which is the fifth
    # sausage: the cat is on his way out of the room.
    ("kitchen",       9, "RIGHT@0-23,UP@0-0,LEFT@24-41,UP@30-30,RIGHT@42-89,"
                         "UP@96-96,LEFT@102-119,RIGHT@126-161,UP@126-126", 150, ""),
    ("backyard",     10, "DOWN@0-17,RIGHT@0-23,LEFT@24-53,UP@24-24,UP@54-54,"
                         "RIGHT@60-65,RIGHT@72-83,UP@84-84",           70, ""),
    ("park",         13, "DOWN@0-17,RIGHT@0-17,LEFT@18-41,UP@24-24,RIGHT@48-77,"
                         "UP@54-54",                                   60, ""),
    ("rooftops",     27, "LEFT@0-71,UP@6-6,UP@42-42,RIGHT@72-119,UP@72-72", 84, ""),
    # Out of lives: one poked in, and the robot in the basement takes it.
    ("gameover",      0, "RIGHT@10-200",                              110,
                         "cat_lives=1@5"),
]


def shift(items, by):
    out = []
    for item in items.split(","):
        if not item.strip():
            continue
        name, fr = item.strip().split("@")
        lo, hi = (fr.split("-") + [fr])[:2]
        out.append("%s@%d-%d" % (name, int(lo) + by, int(hi) + by))
    return out


def shoot(name, room, route, frame, pokes):
    for lang in ("en", "el"):
        items = ["LANG@20-21"] if lang == "el" else []
        if room is None:
            items += shift(route, 0)
            stop, poke = frame, pokes
        else:
            items += [TITLE_FIRE, CHOOSER_FIRE] + shift(route, MENU)
            stop = frame + MENU
            poke = ",".join("%s@%d" % (p.split("@")[0], int(p.split("@")[1]) + MENU)
                            for p in pokes.split(",") if p.strip())
        raw = os.path.join(BUILD, "shot.png")
        args = [sys.executable, os.path.join(ROOT, "tools", "c64run.py"),
                "--route", ",".join(items), "--room", str(room or 0),
                "--frames", str(stop), "--shot", raw,
                "--out", os.path.join(BUILD, "shot")]
        if poke:
            args += ["--poke", poke]
        subprocess.run(args, check=True, stdout=subprocess.DEVNULL)
        out = os.path.join(DOCS, "loukoumas-%s-%s.png" % (name, lang))
        im = Image.open(raw).convert("RGB")
        im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(out)
        print("mkshots64: %s" % os.path.relpath(out, ROOT))


def main():
    os.makedirs(DOCS, exist_ok=True)
    wanted = sys.argv[1:]
    for shot in SHOTS:
        if not wanted or shot[0] in wanted:
            shoot(*shot)


if __name__ == "__main__":
    main()
