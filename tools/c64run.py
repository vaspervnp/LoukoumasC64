#!/usr/bin/env python3
"""Build a scripted copy of the game, play it in VICE, and read the result.

    tools/c64run.py --route "FIRE@120-122,..." [--room N] [--frames F]
                    [--shot out.png] [--peek name ...] [--poke name=value@frame,...]

The build is src/main.s with -D SCRIPT=1 (input from the route, see
tools/mkscript.py) and -D STARTROOM=N. x64sc runs it in warp under the
remote monitor; when script_frame reaches --frames the machine is stopped
and the named variables are read out of memory through the label file. With
--shot a screenshot is taken at that moment.

This is the C64 side of the CPC's make check: the route is the level design's
test, and the asserts are about score, lives, rooms and stun.
"""

import argparse
import os
import re
import socket
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = 6511
MENU = 91               # script frames before the first frame of play


def labels(path):
    out = {}
    for line in open(path):
        m = re.match(r"^(\w+)\s*=\s*(~?\$[0-9a-fA-F]+|-?\d+)", line)
        if m:
            v = m.group(2)
            if v.startswith("~"):
                out[m.group(1)] = ~int(v[2:], 16)
            else:
                out[m.group(1)] = int(v[1:], 16) if v.startswith("$") else int(v)
    return out


class Monitor:
    def __init__(self, port):
        self.s = None
        for _ in range(100):
            try:
                self.s = socket.create_connection(("127.0.0.1", port))
                break
            except OSError:
                time.sleep(0.1)
        if self.s is None:
            sys.exit("c64run: VICE's monitor never answered")
        self.read(0.5)

    def read(self, quiet=0.2):
        self.s.settimeout(quiet)
        out = b""
        while True:
            try:
                d = self.s.recv(65536)
                if not d:
                    break
                out += d
            except socket.timeout:
                break
        return out.decode("latin-1")

    def cmd(self, c, quiet=0.2):
        self.s.sendall((c + "\n").encode())
        return self.read(quiet)

    def mem(self, addr, n=1):
        txt = self.cmd("m %04x %04x" % (addr, addr + n - 1))
        vals = []
        for m in re.finditer(r">C:([0-9a-f]{4})\s+((?:[0-9a-f]{2}\s+)+)", txt):
            vals += [int(v, 16) for v in m.group(2).split()]
        return vals[:n]


def build(route, room, out, stop, pokes=""):
    script = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "mkscript.py"),
                             route, str(stop), pokes], capture_output=True, text=True,
                            check=True).stdout
    open(os.path.join(ROOT, "src", "script.s"), "w").write(script)
    r = subprocess.run(["64tass", "-C", "-a", "-B", "-Wno-implied-reg", "--no-caret-diag",
                        "-q", "-D", "SCRIPT=1", "-D", "PROFILE=1",
                        "-D", "STARTROOM=%d" % room,
                        "-o", out + ".prg", "-l", out + ".lbl",
                        os.path.join(ROOT, "src", "main.s")], capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stdout + r.stderr)
    return labels(out + ".lbl")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--route", default="")
    ap.add_argument("--play", help="a route in room frames: frame 0 is the first "
                    "frame of play, as tools/c64sim.py counts them")
    ap.add_argument("--room", type=int, default=0)
    ap.add_argument("--frames", type=int, default=400)
    ap.add_argument("--shot")
    ap.add_argument("--peek", nargs="*", default=[])
    ap.add_argument("--poke", default="", help="NAME=VALUE@FRAME,... - script "
                    "frames, or room frames with --play")
    ap.add_argument("--save", nargs="*", default=[],
                    help="FILE:START:END (hex) - raw memory to a file")
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "script"))
    ap.add_argument("--ntsc", action="store_true")
    a = ap.parse_args()

    if a.play is not None:
        # The title takes fire at 60, the chooser at 90, and the room's first
        # read of the controls is the frame after.
        items = ["FIRE@60-62", "FIRE@90-92"]
        for item in a.play.split(","):
            if not item.strip():
                continue
            name, fr = item.strip().split("@")
            lo, hi = (fr.split("-") + [fr])[:2]
            items.append("%s@%d-%d" % (name, int(lo) + MENU, int(hi) + MENU))
        a.route = ",".join(items)
        a.frames += MENU
        a.poke = ",".join("%s@%d" % (p.split("@")[0], int(p.split("@")[1]) + MENU)
                          for p in a.poke.split(",") if p.strip())
    lbl = build(a.route, a.room, a.out, a.frames, a.poke)
    for attempt in range(3):
        result = play(a, lbl)
        if result is not None:
            break
        print("c64run: the program never started; trying again", file=sys.stderr)
    else:
        sys.exit("c64run: VICE never ran the program")
    for k, v in result.items():
        print("%s = %s" % (k, v))


def play(a, lbl):
    """One run in VICE. None if autostart never got the program going."""
    args = ["x64sc", "-default", "-warp", "-sounddev", "dummy",
            "-remotemonitor", "-remotemonitoraddress", "ip4://127.0.0.1:%d" % PORT,
            "-autostartprgmode", "1", "-autostart", a.out + ".prg"]
    if a.ntsc:
        args.insert(2, "-ntsc")     # after -default, or it is undone
    p = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        # Leave autostart alone until it has typed RUN: breaking into the
        # monitor while it is injecting the program can make it give up.
        time.sleep(3.0)
        mon = Monitor(PORT)
        sf = lbl["script_frame"]
        halt = lbl["script_halt"]
        started = False
        reached = False
        deadline = time.time() + 120
        while time.time() < deadline:
            mon.cmd("x")
            time.sleep(0.4)
            mon.s.sendall(b"\n")          # any input breaks into the monitor
            regs = mon.read(0.3)
            m = re.search(r"\(C:\$([0-9a-f]{4})\)", regs)
            if m and int(m.group(1), 16) in (halt, halt + 1, halt + 2):
                reached = True
                break
            lo, hi = mon.mem(sf, 2)
            f = lo | (hi << 8)
            if f == a.frames:
                reached = True
                break
            if f:
                started = True
            elif not started and time.time() > deadline - 110:
                return None             # ten seconds and not one frame read
        if not reached:
            return None                 # it never got there: run it again
        if a.shot:
            # The monitor stops the machine wherever the beam is, and VICE's
            # picture of the line it was drawing is half done. Go on to the
            # bottom border, the frame complete, first.
            out = mon.cmd("break %x if RL >= $10a && RL < $130" % halt, 0.3)
            m = re.search(r"BREAK: (\d+)", out)
            mon.cmd("x", 1.0)
            if m:
                mon.cmd("del %s" % m.group(1), 0.3)
            mon.cmd('screenshot "%s" 2' % os.path.abspath(a.shot), 1.0)
        for item in a.save:
            path, lo, hi = item.split(":")
            mon.cmd('bank cpu', 0.2)
            mon.cmd('bsave "%s" 0 %s %s' % (os.path.abspath(path), lo, hi), 1.0)
        res = {"frame": a.frames}
        for name in a.peek:
            size = 1
            if ":" in name:
                name, size = name.split(":")
                size = int(size)
            res[name] = mon.mem(lbl[name], size)
        mon.s.sendall(b"quit\n")
        time.sleep(0.3)
        return res
    finally:
        p.kill()
        p.wait()


if __name__ == "__main__":
    main()
