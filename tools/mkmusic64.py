#!/usr/bin/env python3
"""Compile the title music, assets/music/title.txt, into src/music.s.

    tools/mkmusic64.py [assets/music/title.txt]

The song is written for the SID, not converted: three voices (the title has
the chip to itself - the effects only play in the game), each a stream of
notes for the player in src/sound.s (music_play). The text format is at the
top of the song file. An instrument's keys:

  wave=pulse|tri|saw|noise   the waveform
  ad=XX sr=XX                attack/decay and sustain/release, in hex
  pw=XXXX sweep=N            pulse width ($000-$FFF), and how much it moves
                             each tick, turning at $200 and $E00
  gate=N                     ticks the gate is held - short and staccato; 0
                             (the default) holds it to one tick before the
                             next note, so every note starts a new attack
  vib=D,S,P                  vibrato: after D ticks the pitch moves S a
                             tick, P ticks one way then P the other
  arp=NAME                   a chord: the note steps through the arp's
                             semitones, one a tick
  drop=N                     added to the frequency every tick: a bonk, a
                             snare's snap

The streams, a byte code per voice:

  $00, ticks              rest
  $01-$60, ticks          note (C0 + n - 1), held so many ticks
  $80 + i                 instrument i from here on
  $C0, note, ticks, dlo, dhi   glide from note, the frequency moving by the
                          signed 16-bit d each tick
  $FF                     the end: back to the voice's loop point
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets", "music", "title.txt")
OUT = os.path.join(ROOT, "src", "music.s")

PAL_CLOCK = 985248
NAMES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7,
         "G#": 8, "A": 9, "A#": 10, "B": 11}
WAVES = {"tri": 0x10, "saw": 0x20, "pulse": 0x40, "noise": 0x80}
BAR = 8


def freq(n):
    """SID frequency of note n, C0 = 0; A4 (57) is 440 Hz."""
    hz = 440.0 * 2 ** ((n - 57) / 12)
    return min(0xFFFF, round(hz * 16777216 / PAL_CLOCK))


def note(tok, where):
    m = re.fullmatch(r"([A-G]#?)(\d)", tok)
    if not m:
        sys.exit("mkmusic64: %s: %r is not a note" % (where, tok))
    return int(m.group(2)) * 12 + NAMES[m.group(1)]


def s16(v):
    return v & 0xFFFF


def main():
    speed, insts, arps, voices = 5, [], {}, {}
    cur = None
    for lineno, raw in enumerate(open(SRC, encoding="utf-8"), 1):
        line = re.sub(r"(^|\s)#.*", "", raw).strip()     # F#5 is a note
        where = "%s:%d" % (os.path.basename(SRC), lineno)
        if not line:
            continue
        words = line.split()
        if words[0] == "speed":
            speed = int(words[1])
        elif words[0] == "inst":
            d = {"name": words[1], "wave": "pulse", "ad": "00", "sr": "F0",
                 "pw": "0800", "sweep": "0", "gate": "0", "vib": "0,0,0",
                 "arp": None, "drop": "0"}
            for kv in words[2:]:
                k, v = kv.split("=")
                if k not in d:
                    sys.exit("mkmusic64: %s: no instrument key %r" % (where, k))
                d[k] = v
            insts.append(d)
        elif words[0] == "arp":
            arps[words[1]] = [int(w) for w in words[2:]]
        elif words[0] == "voice":
            cur = int(words[1])
            voices[cur] = []
        elif cur is not None:
            voices[cur].extend((w, where) for w in words)
        else:
            sys.exit("mkmusic64: %s: notes before a voice" % where)
    if sorted(voices) != [1, 2, 3]:
        sys.exit("mkmusic64: wants voices 1, 2 and 3")
    iname = {d["name"]: i for i, d in enumerate(insts)}
    arpnames = sorted(arps)

    streams, loops, lengths = [], [], []
    for v in (1, 2, 3):
        out, rows, bar_rows, loop, inst = [], 0, 0, None, None
        for tok, where in voices[v]:
            if tok == "|":
                if bar_rows != BAR:
                    sys.exit("mkmusic64: %s: voice %d has a bar of %d rows"
                             % (where, v, bar_rows))
                bar_rows = 0
                continue
            if tok == "%loop":
                loop = (len(out), rows)
                continue
            if tok.startswith("@"):
                if tok[1:] not in iname:
                    sys.exit("mkmusic64: %s: no instrument %s" % (where, tok))
                inst = iname[tok[1:]]
                out.append(0x80 + inst)
                continue
            what, _, length = tok.partition(":")
            if not length:
                sys.exit("mkmusic64: %s: %r has no length" % (where, tok))
            n_rows = int(length)
            ticks = n_rows * speed
            if ticks > 255:
                sys.exit("mkmusic64: %s: %r is too long" % (where, tok))
            rows += n_rows
            bar_rows += n_rows
            if what == "r":
                out += [0x00, ticks]
            elif ">" in what:
                a, b = (note(t, where) for t in what.split(">"))
                delta = round((freq(b) - freq(a)) / ticks)
                out += [0xC0, a + 1, ticks, s16(delta) & 255, s16(delta) >> 8]
            else:
                if inst is None:
                    sys.exit("mkmusic64: %s: a note before any instrument" % where)
                out += [note(what, where) + 1, ticks]
        if bar_rows:
            sys.exit("mkmusic64: voice %d ends part way through a bar" % v)
        if loop is None:
            sys.exit("mkmusic64: voice %d has no %%loop" % v)
        out.append(0xFF)
        streams.append(out)
        loops.append(loop)
        lengths.append(rows)
    if len(set(lengths)) != 1 or len({r for _, r in loops}) != 1:
        sys.exit("mkmusic64: the voices are %s rows long, looping at %s"
                 % (lengths, [r for _, r in loops]))

    def hexbytes(b):
        return ", ".join("$%02x" % x for x in b)

    with open(OUT, "w") as fh:
        fh.write(";; Generated by tools/mkmusic64.py from assets/music/title.txt - do not edit.\n")
        fh.write(";; %d rows of %d ticks: %.1f seconds round.\n\n"
                 % (lengths[0], speed, lengths[0] * speed / 50.0))
        fh.write("MUSIC_INSTS = %d\n\n" % len(insts))
        fh.write(";; SID frequencies, PAL, C0 to B7.\n")
        fh.write("music_freq_lo .byte %s\n" % ", ".join("<%d" % freq(n) for n in range(96)))
        fh.write("music_freq_hi .byte %s\n\n" % ", ".join(">%d" % freq(n) for n in range(96)))
        fh.write(";; The instruments: %s.\n" % ", ".join(d["name"] for d in insts))

        def col(label, vals):
            fh.write("%-14s .byte %s\n" % (label, ", ".join(vals)))
        col("in_wave", ["$%02x" % WAVES[d["wave"]] for d in insts])
        col("in_ad", ["$%s" % d["ad"] for d in insts])
        col("in_sr", ["$%s" % d["sr"] for d in insts])
        col("in_pw_lo", ["$%02x" % (int(d["pw"], 16) & 255) for d in insts])
        col("in_pw_hi", ["$%02x" % (int(d["pw"], 16) >> 8) for d in insts])
        col("in_sweep", ["%d" % (int(d["sweep"]) & 255) for d in insts])
        col("in_gate", ["%d" % int(d["gate"]) for d in insts])
        vib = [[int(x) for x in d["vib"].split(",")] for d in insts]
        col("in_vdelay", ["%d" % v[0] for v in vib])
        col("in_vstep", ["%d" % v[1] for v in vib])
        col("in_vspeed", ["%d" % v[2] for v in vib])
        offs, pos = {}, 0
        for a in arpnames:
            offs[a] = pos
            pos += len(arps[a]) + 1
        col("in_arp", ["%d" % (offs[d["arp"]] + 1 if d["arp"] else 0) for d in insts])
        col("in_drop_lo", ["$%02x" % (s16(int(d["drop"])) & 255) for d in insts])
        col("in_drop_hi", ["$%02x" % (s16(int(d["drop"])) >> 8) for d in insts])
        fh.write("\n;; The chords: semitones, $ff goes round. in_arp is 1 + the offset.\n")
        fh.write("music_arps\n")
        for a in arpnames:
            fh.write("        .byte %s, $ff   ; %s\n" % (", ".join("%d" % o for o in arps[a]), a))
        for v, out in enumerate(streams, 1):
            fh.write("\nmusic_v%d\n" % v)
            for k in range(0, len(out), 16):
                fh.write("        .byte %s\n" % hexbytes(out[k:k + 16]))
        fh.write("\nmusic_lo      .byte <music_v1, <music_v2, <music_v3\n")
        fh.write("music_hi      .byte >music_v1, >music_v2, >music_v3\n")
        fh.write("music_loop_lo .byte %s\n" % ", ".join(
            "<(music_v%d+%d)" % (v, loops[v - 1][0]) for v in (1, 2, 3)))
        fh.write("music_loop_hi .byte %s\n" % ", ".join(
            ">(music_v%d+%d)" % (v, loops[v - 1][0]) for v in (1, 2, 3)))
    print("mkmusic64: %d instruments, %d rows (%.1f s), %d bytes of notes"
          % (len(insts), lengths[0], lengths[0] * speed / 50.0,
             sum(len(s) for s in streams)), file=sys.stderr)


if __name__ == "__main__":
    main()
