# LoukoumasC64 - build with 64tass, run with VICE.
#
#   make            build/loukoumas.prg and build/loukoumas.d64
#   make run        start it in x64sc
#   make check      the static checks: colour clash and reachability
#   make shots      screenshots of every room into build/shots/
#   make gen        regenerate the generated sources from the art and text
#
# The generated sources (src/font.s, src/strings.s, src/sprites.s,
# src/spriteblk.s, src/art.s, src/title.s, src/music.s) are committed, so a build needs only 64tass.
# src/rooms.s was generated once by tools/convrooms.py and is hand-edited
# source from then on - the Makefile never regenerates it.

TASS    ?= 64tass
X64     ?= x64sc
PYTHON  ?= python3

SRC     := $(wildcard src/*.s)
PRG     := build/loukoumas.prg
D64     := build/loukoumas.d64
LBL     := build/loukoumas.lbl

TASSFLAGS := -C -a -B -Wall -Wno-implied-reg --no-caret-diag

.PHONY: all run rundisk check shots gen clean

all: $(PRG) $(D64)

$(PRG): $(SRC) | build
	$(TASS) $(TASSFLAGS) -o $@ -l $(LBL) -L build/loukoumas.lst src/main.s

# The disc: the loader, the splash and the game packed (tools/mkdisk64.py).
$(D64): $(PRG) src/loader.s src/unpack.s src/fastload.s tools/mkdisk64.py \
		tools/pack64.py tools/d64.py \
		tools/mksplash64.py assets/revive8b.scr
	$(PYTHON) tools/mkdisk64.py $(PRG) $(LBL)

build:
	mkdir -p build

run: $(PRG)
	$(X64) -autostart $(PRG)

rundisk: $(D64)
	$(X64) -autostart $(D64)

check: $(PRG)
	$(PYTHON) tools/c64check.py $(PRG) $(LBL)

shots: $(PRG)
	$(PYTHON) tools/c64shots.py

gen:
	$(PYTHON) tools/mktext64.py
	$(PYTHON) tools/mksprite64.py
	$(PYTHON) tools/mktitle64.py
	$(PYTHON) tools/mkmusic64.py ../LoukoumasCPC/src/loukmus.asm

clean:
	rm -rf build
