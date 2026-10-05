#!/usr/bin/env python3
"""The game's logic in Python, step for step, to plan and check routes.

    tools/c64sim.py build/loukoumas.prg build/loukoumas.lbl ROOM "ROUTE"
                    [--trace] [--diff N]

A model of play.s and enemy.s: the cat's 8.8 physics, one-way platforms,
rolling, the belly-flop and its stun, the patrols and the flyers' arcs, the
pickups, damage and the way out. It reads the room out of the assembled
program, so it plays the same tables the 6502 does, and it takes the same
route syntax as tools/mkscript.py - but its frame 0 is the first frame of
play in the room, not power-on (tools/c64run.py adds the menus in front).

It is a planning tool and a second opinion, not the referee: VICE playing
the real program is (tools/c64run.py). When the two disagree, this is wrong.
"""

import re
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from c64roomcheck import Prog, read_list   # noqa: E402

CTL = {"UP": 1, "DOWN": 2, "LEFT": 4, "RIGHT": 8, "FIRE": 16}
ST_GROUND, ST_AIR, ST_FLOP, ST_ROLL = range(4)


def parse_route(route):
    out = []
    for item in route.split(","):
        item = item.strip()
        if not item:
            continue
        name, frames = item.split("@")
        a, b = (frames.split("-") + [frames])[:2]
        bits = 0
        for n in name.split("+"):
            bits |= CTL[n]
        out.append((int(a), int(b), bits))
    return out


def s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v


class Game:
    def __init__(self, p, room, difficulty=2, lives=None):
        self.p = p
        c = p.c
        self.c = c
        diff = c("diff_tab") + difficulty * 5
        (self.walk_period, self.walk_steps, self.fly_period, self.stun_time,
         self.start_lives) = (p[diff + k] for k in range(5))
        self.lives = self.start_lives if lives is None else lives
        self.score = 0
        self.room = room
        self.frame = 0
        self.events = []
        self.load()

    def load(self):
        p, c = self.p, self.c
        r = c("rooms") + self.room * c("R_SIZE")
        g = lambda k: p[r + c(k)]
        self.plats = read_list(p, p.word(r + c("R_PLAT")), 3)
        sa = p.word(r + c("R_SAUS"))
        self.nsaus = g("R_NSAUS")
        self.picks = [[p[sa + 2 * k], p[sa + 2 * k + 1], True] for k in range(self.nsaus)]
        self.milk = None
        if g("R_MILKX") != c("NO_MILK"):
            self.milk = [g("R_MILKX"), g("R_MILKY"), True]
        self.exit = (g("R_EXITX"), g("R_EXITY"), g("R_EXITW"), g("R_EXITH"))
        self.startx, self.starty = g("R_STARTX"), g("R_STARTY")
        self.x, self.xf, self.y, self.yf = self.startx, 0, self.starty, 0
        self.vy = 0
        self.h = c("CAT_H")
        self.state, self.stun, self.anim, self.invul = ST_GROUND, 0, 0, 0
        self.got = 0
        self.done = False
        self.prev = 0
        ea = p.word(r + c("R_ENEM"))
        self.en = []
        for k in range(g("R_NENEM")):
            t, x, y, dx, x0, x1, base = (p[ea + 7 * k + q] for q in range(7))
            self.en.append({"t": t, "x": x, "y": y, "dx": dx if dx < 128 else dx - 256,
                            "x0": x0, "x1": x1, "base": base, "phase": 0, "stun": 0,
                            "tick": 0, "w": p[c("ek_w") + t - 1],
                            "h": p[c("ek_h") + t - 1],
                            "fly": p[c("ek_behaviour") + t - 1] == c("EB_FLY")})
        self.sine = [p[c("sine_tab") + k] for k in range(32)]
        self.frm_h = [p[c("cat_frm_h") + k] for k in range(5)]

    # --- the cat --------------------------------------------------------------
    def set_frame(self, f):
        nh = self.frm_h[f]
        self.y = (self.y + self.h - nh) & 0xFF
        self.h = nh

    def step_h(self, step):
        moved = False
        if self.now & CTL["LEFT"]:
            if self.x or self.xf:
                v = (self.x << 8 | self.xf) - step
                if v < 0:
                    v = 0
                self.x, self.xf = v >> 8, v & 0xFF
                moved = True
        elif self.now & CTL["RIGHT"]:
            lim = self.c("SCREEN_W") - self.c("CAT_W")
            if self.x < lim:
                v = (self.x << 8 | self.xf) + step
                if (v >> 8) >= lim:
                    v = lim << 8
                self.x, self.xf = v >> 8, v & 0xFF
                moved = True
        return moved

    def find_landing(self, ofeet, nfeet):
        best = None
        cw = self.c("CAT_W")
        for x0, x1, top in self.plats:
            if x1 < self.x or self.x + cw - 1 < x0:
                continue
            if top < ofeet or nfeet < top:
                continue
            if best is None or top < best:
                best = top
        return best

    def hits(self, bx, by, bw, bh):
        cw = self.c("CAT_W")
        return (bx + bw - 1 >= self.x and self.x + cw - 1 >= bx
                and by + bh - 1 >= self.y and self.y + self.h - 1 >= by)

    def cat_update(self):
        c = self.c
        if self.stun:
            self.stun -= 1
            return
        if self.state == ST_ROLL:
            self.step_h(c("ROLL_STEP"))
            if not self.now & CTL["DOWN"]:
                self.set_frame(0)
                self.state = ST_GROUND
                return
            if self.find_landing(self.y + self.h, self.y + self.h) is None:
                self.state, self.vy = ST_AIR, 0
            return
        if self.state == ST_GROUND:
            moved = self.step_h(c("WALK_STEP"))
            if self.now & CTL["DOWN"]:
                self.set_frame(3)
                self.state = ST_ROLL
                return
            if self.pressed & (CTL["FIRE"] | CTL["UP"]):
                self.events.append((self.frame, "jump"))
                self.vy = s16(c("JUMP_V"))
                self.state = ST_AIR
                self.set_frame(0)
                return
            if self.find_landing(self.y + self.h, self.y + self.h) is None:
                self.state, self.vy = ST_AIR, 0
                return
            if moved:
                self.anim = (self.anim + 1) & 0xFF
                self.set_frame(2 if self.anim & c("WALK_BIT") else 1)
            else:
                self.anim = 0
                self.set_frame(0)
            return
        # in the air
        self.step_h(c("WALK_STEP"))
        if (self.state != ST_FLOP and self.now & CTL["DOWN"]
                and self.pressed & CTL["FIRE"]):
            self.events.append((self.frame, "flop"))
            self.vy = c("FLOP_V")
            self.state = ST_FLOP
            self.set_frame(4)
        self.vy = s16(self.vy + c("GRAVITY"))
        if self.vy >= 0 and self.vy >= c("MAX_FALL"):
            self.vy = c("MAX_FALL")
        ofeet = self.y + self.h
        v = (self.y << 8 | self.yf) + self.vy
        if v < 0:
            v = c("PLAY_TOP") << 8
            self.vy = 0
        self.y, self.yf = (v >> 8) & 0xFF, v & 0xFF
        if self.y < c("PLAY_TOP"):
            self.y, self.yf, self.vy = c("PLAY_TOP"), 0, 0
        if self.vy < 0:
            return
        top = self.find_landing(ofeet, self.y + self.h)
        if top is None:
            return
        self.y, self.yf, self.vy = top - self.h, 0, 0
        if self.state == ST_FLOP:
            self.stun = c("FLOP_STUN")
            self.state = ST_GROUND
            for e in self.en:
                if abs(self.y - e["y"]) <= c("FLOP_REACH_Y"):
                    e["stun"] = self.stun_time
            self.events.append((self.frame, "flop lands at y=%d" % self.y))
        else:
            self.state = ST_GROUND
            self.set_frame(0)

    # --- the cast -----------------------------------------------------------
    def bounce(self, e):
        e["x"] = (e["x"] + e["dx"]) & 0xFF
        if e["x"] < e["x0"] or e["x"] > e["x1"]:
            e["x"] = e["x0"] if e["dx"] < 0 else e["x1"]
            e["dx"] = -e["dx"]

    def enemies_update(self):
        for e in reversed(self.en):
            if e["stun"]:
                e["stun"] -= 1
                continue
            if e["fly"]:
                e["tick"] += 1
                if e["tick"] < self.fly_period:
                    continue
                e["tick"] = 0
                self.bounce(e)
                e["phase"] = (e["phase"] + 1) & 31
                e["y"] = (e["base"] + self.sine[e["phase"]]) & 0xFF
            else:
                e["phase"] += 1
                if e["phase"] >= self.walk_period:
                    e["phase"] = 0
                if e["phase"] >= self.walk_steps:
                    continue
                self.bounce(e)

    def step(self, ctl):
        c = self.c
        self.now = ctl
        self.pressed = ctl & ~self.prev
        self.prev = ctl
        self.cat_update()
        self.enemies_update()
        pw, ph = c("PICK_W"), c("PICK_H")
        if self.milk and self.milk[2] and self.hits(self.milk[0], self.milk[1], pw, ph):
            self.milk[2] = False
            self.lives = min(self.lives + 1, self.start_lives)
            self.events.append((self.frame, "milk"))
        if not self.done:
            for k, pk in enumerate(self.picks):
                if pk[2] and self.hits(pk[0], pk[1], pw, ph):
                    pk[2] = False
                    self.got += 1
                    self.score += 100
                    self.events.append((self.frame, "sausage %d" % (k + 1)))
            if self.got == self.nsaus:
                self.done = True
                self.events.append((self.frame, "the way out opens"))
        if self.invul:
            self.invul -= 1
        hit = any(not e["stun"] and self.hits(e["x"], e["y"], e["w"], e["h"])
                  for e in self.en)
        if hit and not self.invul:
            self.lives -= 1
            self.events.append((self.frame, "caught - %d lives" % self.lives))
            if self.lives == 0:
                return "over"
            self.set_frame(0)
            self.x, self.y, self.xf, self.yf = self.startx, self.starty, 0, 0
            self.stun, self.state, self.vy = 0, ST_GROUND, 0
            self.invul = c("INVUL_FRAMES")
        if self.done and self.hits(*self.exit):
            self.events.append((self.frame, "through the way out"))
            return "exit"
        return None


def run(p, room, route, frames=3000, trace=False):
    g = Game(p, room)
    steps = parse_route(route)
    for f in range(frames):
        g.frame = f
        ctl = 0
        for a, b, bits in steps:
            if a <= f <= b:
                ctl |= bits
        r = g.step(ctl)
        if trace:
            print("%4d x=%3d y=%3d st=%d vy=%5d  %s" % (
                f, g.x, g.y, g.state, g.vy,
                " ".join("%s%d,%d" % ("*" if e["stun"] else "", e["x"], e["y"])
                         for e in g.en)))
        if r:
            return g, r
    return g, None


def main():
    p = Prog(sys.argv[1], sys.argv[2])
    room = int(sys.argv[3])
    g, r = run(p, room, sys.argv[4], trace="--trace" in sys.argv)
    for f, e in g.events:
        print("%5d  %s" % (f, e))
    print("result: %s, score %d, lives %d, %d/%d sausages, cat at %d,%d"
          % (r, g.score, g.lives, g.got, g.nsaus, g.x, g.y))


if __name__ == "__main__":
    main()
