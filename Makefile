# LoukoumasC64 - build with 64tass, run with VICE.
#
#   make            build/loukoumas.prg and build/loukoumas.d64
#   make run        start it in x64sc
#   make check      the static checks: colour clash and reachability
#   make shots      screenshots of every room into build/shots/
#   make gen        regenerate the generated sources from the art and text
#
# The generated sources (src/font.s, src/strings.s, src/sprites.s,
# src/spriteblk.s, src/art.s) are committed, so a build needs only 64tass.
# src/rooms.s was generated once by tools/convrooms.py and is hand-edited
# source from then on - the Makefile never regenerates it.

TASS    ?= 64tass
X64     ?= x64sc
C1541   ?= c1541
PYTHON  ?= python3

SRC     := $(wildcard src/*.s)
PRG     := build/loukoumas.prg
D64     := build/loukoumas.d64
LBL     := build/loukoumas.lbl

TASSFLAGS := -C -a -B -Wall -Wno-implied-reg --no-caret-diag

.PHONY: all run check shots gen clean

all: $(PRG) $(D64)

$(PRG): $(SRC) | build
	$(TASS) $(TASSFLAGS) -o $@ -l $(LBL) -L build/loukoumas.lst src/main.s

$(D64): $(PRG)
	$(C1541) -format "loukoumas,26" d64 $@ -write $(PRG) loukoumas >/dev/null

build:
	mkdir -p build

run: $(PRG)
	$(X64) -autostart $(PRG)

check: $(PRG)
	$(PYTHON) tools/c64check.py $(PRG) $(LBL)

shots: $(PRG)
	$(PYTHON) tools/c64shots.py

gen:
	$(PYTHON) tools/mktext64.py
	$(PYTHON) tools/mksprite64.py

clean:
	rm -rf build
