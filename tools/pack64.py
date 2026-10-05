#!/usr/bin/env python3
"""A small LZ packer, and its format, for src/unpack.s.

    tools/pack64.py IN OUT [--skip N]

exomizer is what loukc64.md 10 names, and it is not installed here; this is
the plain thing instead - about a fifth worse than exomizer on this game, in
exchange for a decruncher of eighty-odd bytes that anyone can read. --skip N
drops N bytes from the front of IN (2 for a .prg's load address).

The stream is a run of tokens, each starting with one byte t:

    t = 0           the end
    t = 1..127      t literal bytes follow
    t = 128..191    a match of (t & 63) + 2 bytes, 2..65; one byte follows,
                    the distance back - 1 (1..256 bytes back)
    t = 192..255    a match of (t & 63) + 3 bytes, 3..66; two bytes follow,
                    the distance back - 1, low byte first (1..65536 back)

A match copies forward from the output itself, one byte at a time, so a
distance shorter than the length repeats a pattern - a run of one byte is a
literal and a match at distance 1.

The parse is optimal for this format: cheapest cost to the end from every
position, worked out backwards over the matches a hash chain finds.
"""

import sys

MAX_CHAIN = 96


def candidates(data):
    """For each position, (length, distance) pairs worth considering."""
    n = len(data)
    heads = {}
    prev = [-1] * n
    out = [[] for _ in range(n)]
    for i in range(n - 1):
        key = data[i:i + 2]
        j = heads.get(key, -1)
        prev[i] = j
        heads[key] = i
        found = []
        best = 1
        steps = 0
        while j >= 0 and steps < MAX_CHAIN and i - j <= 65536:
            k = 0
            lim = min(66, n - i)
            while k < lim and data[j + k] == data[i + k]:
                k += 1
            if k > best:
                best = k
                found.append((k, i - j))
            steps += 1
            j = prev[j]
        out[i] = found
    return out


def pack(data):
    n = len(data)
    cand = candidates(data)
    INF = 1 << 60
    cost = [INF] * (n + 1)
    choice = [None] * (n + 1)
    cost[n] = 1                     # the end token
    for i in range(n - 1, -1, -1):
        # Literals: a run of 1..127 starting here.
        best, pick = INF, None
        for run in range(1, min(127, n - i) + 1):
            c = 1 + run + cost[i + run]
            if c < best:
                best, pick = c, ("lit", run)
            if run > 16 and c > best + 32:
                break
        for length, dist in cand[i]:
            for ln in range(2, length + 1):
                if dist <= 256 and ln <= 65:
                    c = 2 + cost[i + ln]
                elif ln >= 3 and ln <= 66:
                    c = 3 + cost[i + ln]
                else:
                    continue
                if c < best:
                    best, pick = c, ("match", ln, dist)
        cost[i], choice[i] = best, pick
    out = bytearray()
    i = 0
    while i < n:
        ch = choice[i]
        if ch[0] == "lit":
            out.append(ch[1])
            out += data[i:i + ch[1]]
            i += ch[1]
        else:
            _, ln, dist = ch
            if dist <= 256 and ln <= 65:
                out.append(128 | (ln - 2))
                out.append(dist - 1)
            else:
                out.append(192 | (ln - 3))
                out.append((dist - 1) & 255)
                out.append((dist - 1) >> 8)
            i += ln
    out.append(0)
    return bytes(out)


def lowest_start(stream, load):
    """The lowest address the stream may start at, unpacking to `load`, so
    the output never overwrites a byte of stream not yet read: after every
    token, what has been written must end at or before the next byte to be
    read."""
    worst = -1 << 30
    out = 0
    i = 0
    while True:
        t = stream[i]
        i += 1
        if t == 0:
            return worst
        if t < 128:
            # literal byte j is read at i+j and written at out+j: the write may
            # land on byte i+j itself, which has been read; not past it
            out += t
            i += t
        else:
            i += 1 if t < 192 else 2
            out += (t & 63) + (2 if t < 192 else 3)
        worst = max(worst, load + out - i)


def unpack(stream):
    out = bytearray()
    i = 0
    while True:
        t = stream[i]
        i += 1
        if t == 0:
            return bytes(out)
        if t < 128:
            out += stream[i:i + t]
            i += t
            continue
        if t < 192:
            ln, dist = (t & 63) + 2, stream[i] + 1
            i += 1
        else:
            ln, dist = (t & 63) + 3, (stream[i] | stream[i + 1] << 8) + 1
            i += 2
        for _ in range(ln):
            out.append(out[-dist])


def main():
    src = open(sys.argv[1], "rb").read()
    skip = int(sys.argv[sys.argv.index("--skip") + 1]) if "--skip" in sys.argv else 0
    data = src[skip:]
    packed = pack(data)
    if unpack(packed) != data:
        sys.exit("pack64: the stream does not unpack to the input")
    open(sys.argv[2], "wb").write(packed)
    print("pack64: %d -> %d bytes (%d%%)" % (len(data), len(packed),
                                           100 * len(packed) // len(data)), file=sys.stderr)


if __name__ == "__main__":
    main()
