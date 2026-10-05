#!/usr/bin/env python3
"""Write a .d64 - a 35-track 1541 disc - with files laid out as we choose.

c1541 writes every file with the DOS's interleave of 10: each next sector
ten on round the track, which is right for the KERNAL's own load. The fast
loader (src/fastload.s) takes about 45 ms to send a sector, and the DOS
needs more lead than ten sectors leave it after that, so it waits a whole
turn for every other one. Here each file has its own interleave.

    d64 = D64("loukoumas", "26")
    d64.add("loukoumas", data, interleave=10)
    open(path, "wb").write(d64.image())

Files are PRGs; `data` includes the two bytes of load address. They go on
tracks 17, 16, ... 1 and then 19, 20, ... 35, as the DOS fills a disc: the
first file nearest the directory, so the head has least to travel.
"""

SECTORS = [0] + [21] * 17 + [19] * 7 + [18] * 6 + [17] * 5   # by track, 1-35
DIR_TRACK = 18


def offset(track, sector):
    return (sum(SECTORS[1:track]) + sector) * 256


def petscii(name):
    """Lower-case ASCII to PETSCII as 64tass -a and c1541 write it: upper case."""
    return bytes(ord(c.upper()) if c.isalpha() else ord(c) for c in name)


class D64:
    def __init__(self, name, ident):
        self.name, self.ident = name, ident
        self.used = {t: set() for t in range(1, 36)}
        self.used[DIR_TRACK] |= {0}
        self.data = bytearray(sum(SECTORS) * 256)
        self.files = []
        self.order = list(range(17, 0, -1)) + list(range(19, 36))

    def add(self, name, data, interleave=10):
        chunks = [data[i:i + 254] for i in range(0, len(data), 254)] or [b""]
        sectors = []
        tracks = iter(self.order)
        track = next(tracks)
        sector = 0
        for _ in chunks:
            while len(self.used[track]) == SECTORS[track]:
                track = next(tracks)
                sector %= SECTORS[track]
            n = SECTORS[track]
            while sector in self.used[track]:
                sector = (sector + 1) % n
            self.used[track].add(sector)
            sectors.append((track, sector))
            sector = (sector + interleave) % n
        for k, (chunk, (t, s)) in enumerate(zip(chunks, sectors)):
            block = bytearray(256)
            if k + 1 < len(sectors):
                block[0], block[1] = sectors[k + 1]
            else:
                block[0], block[1] = 0, len(chunk) + 1
            block[2:2 + len(chunk)] = chunk
            o = offset(t, s)
            self.data[o:o + 256] = block
        self.files.append((name, sectors[0], len(sectors)))
        return sectors

    def image(self):
        if len(self.files) > 8:
            raise ValueError("d64: one directory sector holds eight files")
        self.used[DIR_TRACK].add(1)
        d = bytearray(256)
        d[0], d[1] = 0, 0xFF
        for i, (name, (t, s), blocks) in enumerate(self.files):
            e = i * 32
            d[e + 2] = 0x82                         # PRG, closed
            d[e + 3], d[e + 4] = t, s
            d[e + 5:e + 21] = petscii(name).ljust(16, b"\xa0")
            d[e + 30], d[e + 31] = blocks & 255, blocks >> 8
        o = offset(DIR_TRACK, 1)
        self.data[o:o + 256] = d

        bam = bytearray(256)
        bam[0], bam[1], bam[2] = DIR_TRACK, 1, 0x41
        for t in range(1, 36):
            free = [s for s in range(SECTORS[t]) if s not in self.used[t]]
            bits = sum(1 << s for s in free)
            bam[4 * t:4 * t + 4] = bytes([len(free), bits & 255, (bits >> 8) & 255, bits >> 16])
        bam[0x90:0xA0] = petscii(self.name).ljust(16, b"\xa0")
        bam[0xA0:0xA2] = b"\xa0\xa0"
        bam[0xA2:0xA4] = petscii(self.ident)[:2]
        bam[0xA4] = 0xA0
        bam[0xA5:0xA7] = b"2A"
        bam[0xA7:0xAB] = b"\xa0" * 4
        o = offset(DIR_TRACK, 0)
        self.data[o:o + 256] = bam
        return bytes(self.data)
