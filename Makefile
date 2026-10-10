# LoukoumasC64 - build with 64tass, run with VICE.
#
#   make            build/loukoumas.prg and build/loukoumas.d64
#   make run        start it in x64sc
#   make check      the static checks: colour clash and reachability
#   make profile    every room's route played in VICE: out, and no frame missed
#   make modelcheck the checks without VICE: clash, reachability, every route
#                   in the Python model (what CI runs when it has no ROMs)
#   make shots      screenshots of every room into build/shots/
#   make manualshots  the manuals' and the inlay's screen shots, into docs/
#   make covers     the disc inlay, docs/cover-<lang>.png
#   make manuals    the A5 booklets, docs/manual-<lang>.pdf
#   make gen        regenerate the generated sources from the art and text
#
# The generated sources (src/font.s, src/strings.s, src/sprites.s,
# src/spriteblk.s, src/spriteblk2.s, src/art.s, src/title.s, src/music.s) are committed, so a build needs only 64tass.
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

.PHONY: all run rundisk check profile modelcheck shots manualshots covers manuals gen clean

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

profile: $(PRG)
	$(PYTHON) tools/c64profile.py

modelcheck: $(PRG)
	$(PYTHON) tools/c64roomcheck.py $(PRG) $(LBL)
	$(PYTHON) tools/c64profile.py --sim

shots: $(PRG)
	$(PYTHON) tools/c64shots.py

# The screen shots the manuals and the inlay are made of, in both languages:
# scripted runs in VICE (tools/mkshots64.py). Committed, like the inlay and
# the booklets, because they need VICE, Pillow, fpdf2 and the Noto fonts.
SCENES := title difficulty lounge kitchen backyard park rooftops gameover
DOCSHOTS := $(foreach s,$(SCENES),docs/loukoumas-$(s)-en.png docs/loukoumas-$(s)-el.png)
COVER_SCENES := lounge park rooftops gameover

manualshots: $(PRG)
	$(PYTHON) tools/mkshots64.py

covers: docs/cover-en.png docs/cover-el.png

docs/cover-%.png: assets/art/title.jpg $(DOCSHOTS) tools/mkcover64.py
	$(PYTHON) tools/mkcover64.py assets/art/title.jpg $* $@ \
		$(foreach s,$(COVER_SCENES),docs/loukoumas-$(s)-$*.png)

# The front comes out of the same run as the wrap.
docs/cover-%-front.png: docs/cover-%.png
	@:

manuals: docs/manual-en.pdf docs/manual-el.pdf

docs/manual-%.pdf: MANUAL.%.md docs/cover-%-front.png $(DOCSHOTS) tools/mkmanual.py
	$(PYTHON) tools/mkmanual.py $< $@

gen:
	$(PYTHON) tools/mktext64.py
	$(PYTHON) tools/mksprite64.py
	$(PYTHON) tools/mktitle64.py
	$(PYTHON) tools/mkmusic64.py assets/music/title.txt

clean:
	rm -rf build
