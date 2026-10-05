#!/usr/bin/env python3
"""Build the disc: build/loukoumas.d64 with the loader and the packed game.

    tools/mkdisk64.py build/loukoumas.prg build/loukoumas.lbl

  LOUKOUMAS   the loader (src/loader.s): the REVIVE8BIT splash, packed, and
              the code that shows it and loads the game. LOAD"*",8 and RUN.
  LOUKC64     the game, packed by tools/pack64.py, with a load address that
              puts its last byte at $BFFF. The game unpacks to $0801 and up,
              and its end overlaps the stream's start: that is safe as long
              as no output byte lands on a byte of stream still to be read,
              which pack64.lowest_start works out token by token and this
              checks.
"""

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import pack64   # noqa: E402

TOP = 0xC000                    # the loader's working part starts here


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
    open(os.path.join(b, "splash.lz"), "wb").write(pack64.pack(splash))

    subprocess.run(["64tass", "-C", "-a", "-B", "-q", "-Wno-implied-reg", "--no-caret-diag",
                    "-D", "GAME_START=%d" % label(lbl, "start"),
                    "-D", "GAME_LZ_AT=%d" % at,
                    "-o", os.path.join(b, "loader.prg"),
                    os.path.join(ROOT, "src", "loader.s")], check=True)
    d64 = os.path.join(b, "loukoumas.d64")
    subprocess.run(["c1541", "-format", "loukoumas,26", "d64", d64,
                    "-write", os.path.join(b, "loader.prg"), "loukoumas",
                    "-write", os.path.join(b, "loukc64.prg"), "loukc64"],
                   check=True, stdout=subprocess.DEVNULL)
    lsize = os.path.getsize(os.path.join(b, "loader.prg"))
    print("mkdisk64: game %d -> %d bytes at $%04X-$BFFF (overlaps the unpacked game "
          "by %d, %d to spare), loader %d bytes"
          % (len(game), len(packed), at, max(0, end - at), at - lowest, lsize), file=sys.stderr)


if __name__ == "__main__":
    main()
