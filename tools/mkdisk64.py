#!/usr/bin/env python3
"""Build the disc: build/loukoumas.d64 with the loader and the packed game.

    tools/mkdisk64.py build/loukoumas.prg build/loukoumas.lbl

  LOUKOUMAS   the loader (src/loader.s), with the fast loader (src/fastload.s)
              in it: it loads the other two. LOAD"*",8 and RUN.
  SPLASH      the REVIVE8BIT splash, packed, loading at SPLASH_LZ_AT.
  LOUKC64     the game, packed by tools/pack64.py, with a load address that
              puts its last byte at $BFFF. The game unpacks to $0801 and up,
              and its end overlaps the stream's start: that is safe as long
              as no output byte lands on a byte of stream still to be read,
              which pack64.lowest_start works out token by token and this
              checks.

The disc is written by tools/d64.py rather than c1541, so the two files the
fast loader reads can have an interleave that suits it.
"""

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import pack64   # noqa: E402
from d64 import D64   # noqa: E402

# The fast loader's files: every next sector twelve on round the track. It
# sends a sector in about 45 ms, and the DOS wants its read job well before
# the sector comes round: at 11 it just catches each one in VICE, 2 ms later
# it misses them by a turn; at 12 it has about 8 ms in hand, for a drive that
# turns a little fast. (10, the DOS's own, misses every other sector.)
FAST_INTERLEAVE = 12
TOP = 0xC000                    # the loader's last part starts here
SPLASH_LZ_AT = 0x1000           # above the loader, below where the splash unpacks
SPLASH_TMP = 0x9000


def label(lbl, name):
    for line in open(lbl):
        m = re.match(r"^%s\s*=\s*\$([0-9a-fA-F]+)" % name, line)
        if m:
            return int(m.group(1), 16)
    sys.exit("mkdisk64: %s not in %s" % (name, lbl))


def main():
    prg, lbl = sys.argv[1], sys.argv[2]
    b = os.path.join(ROOT, "build")
    raw = open(prg, "rb").read()
    load = raw[0] | raw[1] << 8
    game = raw[2:]
    packed = pack64.pack(game)
    assert pack64.unpack(packed) == game
    at = TOP - len(packed)
    end = load + len(game)
    lowest = pack64.lowest_start(packed, load)
    if at < lowest:
        sys.exit("mkdisk64: the packed game (%d bytes) would start at $%04X; unpacking "
                 "to $%04X it must start at $%04X or above" % (len(packed), at, load, lowest))
    open(os.path.join(b, "loukc64.prg"), "wb").write(bytes([at & 255, at >> 8]) + packed)

    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "mksplash64.py")], check=True)
    splash = open(os.path.join(b, "splash.bin"), "rb").read()
    splash_lz = pack64.pack(splash)
    if SPLASH_LZ_AT + len(splash_lz) > SPLASH_TMP:
        sys.exit("mkdisk64: the packed splash runs into where it unpacks")
    open(os.path.join(b, "splash.prg"), "wb").write(
        bytes([SPLASH_LZ_AT & 255, SPLASH_LZ_AT >> 8]) + splash_lz)

    subprocess.run(["64tass", "-C", "-a", "-B", "-q", "-Wno-implied-reg", "--no-caret-diag",
                    "-D", "GAME_START=%d" % label(lbl, "start"),
                    "-D", "GAME_LZ_AT=%d" % at,
                    "-D", "SPLASH_LZ_AT=%d" % SPLASH_LZ_AT,
                    "-o", os.path.join(b, "loader.prg"),
                    os.path.join(ROOT, "src", "loader.s")], check=True)
    disc = D64("loukoumas", "26")
    disc.add("loukoumas", open(os.path.join(b, "loader.prg"), "rb").read())
    disc.add("splash", open(os.path.join(b, "splash.prg"), "rb").read(), FAST_INTERLEAVE)
    disc.add("loukc64", open(os.path.join(b, "loukc64.prg"), "rb").read(), FAST_INTERLEAVE)
    open(os.path.join(b, "loukoumas.d64"), "wb").write(disc.image())
    lsize = os.path.getsize(os.path.join(b, "loader.prg"))
    print("mkdisk64: game %d -> %d bytes at $%04X-$BFFF (overlaps the unpacked game "
          "by %d, %d to spare), splash %d bytes, loader %d bytes"
          % (len(game), len(packed), at, max(0, end - at), at - lowest, len(splash_lz), lsize), file=sys.stderr)


if __name__ == "__main__":
    main()
