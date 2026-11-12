# EBASIC, BBC BASIC (Z80) v5 for the VTech Genio 2000. Usage: make   (needs sdasz80, sdldz80, python3)
# The interpreter is R.T. Russell's BBCZ80 (zlib licence, bbcz80/), converted mechanically to sdas syntax.
# Page 1 (interpreter + genio1.s) is linked first; page 2 (genio2.s) then takes the page-1 addresses it needs.
# Copyright (C) 2026 Santiago Crespo
# SPDX-License-Identifier: GPL-3.0-or-later
NAME = ebasic_gl2000
MODS = MAIN EXEC EVAL MATH DATA
RELS1 = out/genio1.rel $(MODS:%=out/%.rel) out/sound.rel
P2SRC = genio2.s stmt.s help.s
RELS2 = $(P2SRC:%.s=out/%.rel) out/helpdata.rel out/ASMB.rel out/p1calls.rel
# Page-1 addresses page 2 uses (RAM variables, jump targets) and page-1 routines it calls through a stub
P1ADDR = ESCAPE XEQ SORRY AUTONO PAGE ERL ACCS BUFFER LISTON COUNT OC PC WIDTH R_CALL1 R_JP1 R_HOOK
P1CALL = sound kwname kscan offpoll PBCDL EXPRI EXPRS ITEMI COMMA BRAKET NXT TERMQ STOREN VAR ZERO TABIT OUT CRLF ERROR

all: $(NAME)_AT28C256_32K.bin

# The one change to the interpreter: its banner names this cartridge, its author and Russell's BASIC
out/MAIN.s: bbcz80/MAIN.Z80 m80_to_sdas.py Makefile
	@mkdir -p out
	sed -e "s/^VERMSG:\tDEFM\t'BBC BASIC (Z80) Version 5.00  '/VERMSG:\tDEFM\t'EBASIC 1.0 by'/" \
	    -e "s/^NOTICE:\tDEFM\t'(C) Copyright R.T.Russell 2025'/NOTICE:\tDEFM\t'Santiago Crespo 2026'\n\tDEFB\tCR\n\tDEFB\tLF\n\tDEFM\t'BASIC by R.T.Russell'/" $< > out/MAIN.Z80
	grep -q "^VERMSG:.*'EBASIC 1.0 by'" out/MAIN.Z80
	grep -q "'BASIC by R.T.Russell'" out/MAIN.Z80
	python3 m80_to_sdas.py out/MAIN.Z80 $@ CODE

out/%.s: bbcz80/%.Z80 m80_to_sdas.py
	@mkdir -p out
	python3 m80_to_sdas.py $< $@ $(if $(filter DATA,$*),RAM,$(if $(filter ASMB,$*),P2,CODE))

out/%.rel: out/%.s
	sdasz80 -l -o $@ $<

out/genio1.rel: genio1.s shared.inc
	@mkdir -p out
	sdasz80 -l -o $@ $<

out/page1.ihx: $(RELS1)
	sdldz80 -n -m -i $@ -b CODE=0x8000 -b RAM=0xC000 $(RELS1)
	@if grep -q "Undefined Global" out/page1.map; then echo "undefined globals"; exit 1; fi

out/p1calls.s: out/page1.ihx mksyms.py
	python3 mksyms.py out/page1.map $@ --addr $(P1ADDR) --call $(P1CALL)

out/helpdata.s: help.txt gen_help.py bbcz80/MAIN.Z80
	python3 gen_help.py help.txt bbcz80/MAIN.Z80 $@

out/sound.s: gen_sound.py
	python3 gen_sound.py $@ CODE

# page-2 modules: undefined symbols are global (-g), resolved by the page-2 link
out/genio2.rel out/stmt.rel out/help.rel: out/%.rel: %.s shared.inc
	sdasz80 -a -g -l -o $@ $<

out/sound.rel: out/sound.s shared.inc
	sdasz80 -l -o $@ $<

out/helpdata.rel out/p1calls.rel: out/%.rel: out/%.s
	sdasz80 -a -g -l -o $@ $<

out/page2.ihx: $(RELS2)
	sdldz80 -n -m -i $@ -b P2=0x8000 $(RELS2)
	@if grep -q "Undefined Global" out/page2.map; then grep "Undefined Global" out/page2.map; exit 1; fi

$(NAME)_AT28C256_32K.bin: out/page1.ihx out/page2.ihx mkcart.py
	python3 mkcart.py out/page1.ihx out/page2.ihx $@ $(NAME)_mame_64K.bin

clean:
	rm -rf out $(NAME)_AT28C256_32K.bin $(NAME)_mame_64K.bin
.PHONY: all clean
.SECONDARY:

# Converter check: rebuild upstream's CP/M edition with sdas and compare it with bin/cpm/BBCBASIC.COM.
# Usage: make verify-converter BBCZ80=/path/to/BBCZ80 (a clone of https://github.com/rtrussell/BBCZ80)
verify-converter:
	@test -n "$(BBCZ80)" || (echo "set BBCZ80=/path/to/BBCZ80"; exit 1)
	@mkdir -p out/cpm
	python3 m80_to_sdas.py $(BBCZ80)/src/DIST.Z80 out/cpm/DIST.s "DIST (ABS)"
	for m in MAIN EXEC EVAL ASMB MATH HOOK CMOS DATA; do \
	  python3 m80_to_sdas.py $(BBCZ80)/src/$$m.Z80 out/cpm/$$m.s $$( [ $$m = DATA ] && echo RAM || echo CODE ) || exit 1; done
	for m in DIST MAIN EXEC EVAL ASMB MATH HOOK CMOS DATA; do sdasz80 -o out/cpm/$$m.rel out/cpm/$$m.s || exit 1; done
	sdldz80 -n -i out/cpm/cpm.ihx -b CODE=0x200 -b RAM=0x4B00 $(foreach m,DIST MAIN EXEC EVAL ASMB MATH HOOK CMOS DATA,out/cpm/$(m).rel)
	python3 -c "import sys; d=bytearray(0x10000); \
	[d.__setitem__(slice(int(l[3:7],16),int(l[3:7],16)+int(l[1:3],16)),bytes.fromhex(l[9:9+2*int(l[1:3],16)])) for l in open('out/cpm/cpm.ihx') if l[7:9]=='00']; \
	r=open('$(BBCZ80)/bin/cpm/BBCBASIC.COM','rb').read(); \
	sys.exit('DIFFERENT') if bytes(d[0x100:0x100+len(r)])!=r else print('converter OK: identical to BBCBASIC.COM (%d bytes)'%len(r))"
.PHONY: verify-converter
