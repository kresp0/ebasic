; help.s - page 2: the guide behind the AYUDA key. An index of entries (the editor first, then
; every keyword); INTRO opens one, and on its page INTRO copies the example into the prompt.
; The text comes from help.txt through gen_help.py (out/helpdata.s).
; Copyright (C) 2026 Santiago Crespo
; SPDX-License-Identifier: 0BSD

	.include "shared.inc"

	.area	P2

HLEN = GTMP			; length of the page text in BUFFER
HNL = GTMP+1			; number of lines
HEX = GTMP+2			; offset of the example in the entry (0: none), 2 bytes
HPTR = GTMP+4			; entry of the next index row
LINES = FMASK			; start and end offset of each line (20 lines)

; AYUDA in the editor: the entry of the word at the cursor, or the index
ed_help::
	ld	a, #1
	ld	(CURSOFF), a
	call	hctx
	jr	c, 2$
1$:	call	hindex
	jr	nc, 3$
2$:	ld	(HSEL), a
	call	hpage
	jr	z, 1$
3$:	jp	edit

; The index: A = the chosen entry and carry, or no carry to leave
hindex:	call	hdrawidx
	call	hkey
	ld	hl, #HSEL
	cp	#UP
	jr	nz, 1$
	ld	a, (hl)
	or	a
	jr	z, hindex
	dec	(hl)
	ld	a, (HTOP)
	cp	(hl)
	jr	c, hindex
	jr	z, hindex
	ld	a, (hl)
	ld	(HTOP), a
	jr	hindex
1$:	cp	#DOWN
	jr	nz, 2$
	ld	a, (HCOUNT)
	dec	a
	cp	(hl)
	jr	z, hindex
	inc	(hl)
	ld	a, (HTOP)
	add	a, #3
	cp	(hl)
	jr	nc, hindex
	ld	a, (hl)
	sub	#3
	ld	(HTOP), a
	jr	hindex
2$:	cp	#CR
	jr	nz, 3$
	ld	a, (hl)
	scf
	ret
3$:	cp	#ESC
	jr	z, hquit
	cp	#HELP
	jr	z, hquit
	call	hletter
	jr	hindex

; A letter: select the first keyword from it on (NC if A is not a letter)
hletter:
	and	#0xDF
	cp	#0x41
	ccf
	ret	nc
	cp	#0x5B
	ret	nc
	call	hlfirst
	ld	(HSEL), a
	ld	(HTOP), a
	scf
	ret

; A key for the guide: U-diaeresis, LEFT, ALT+U-diaeresis are up; ";", RIGHT, ALT+; are down
hkey:	call	OSRDCH
	cp	#0x81
	jr	z, 1$
	cp	#0x9A
	jr	z, 1$
	cp	#LEFT
	jr	z, 1$
	cp	#0x3B
	jr	z, 2$
	cp	#RIGHT
	ret	nz
2$:	ld	a, #DOWN
	ret
1$:	ld	a, #UP
	ret

hquit:	ld	hl, #FLAGS		; leave (and forget an Escape)
	res	7, (hl)
	or	a
	ret

; Draw four titles from HTOP, ">" on the selected one
hdrawidx:
	ld	a, (HTOP)
	ld	c, a
	call	hentry
	ld	(HPTR), hl
	ld	e, #0
1$:	ld	a, (HSEL)
	cp	c
	ld	a, #0x20
	jr	nz, 2$
	ld	a, #0x3E
2$:	push	bc
	call	putcell
	pop	bc
	inc	e
	ld	hl, #0			; HL = 0: no title (past the last entry)
	ld	a, (HCOUNT)
	cp	c
	jr	z, 3$
	jr	c, 3$
	push	de
	push	bc
	ld	hl, (HPTR)
	push	hl
	ld	de, #BUFFER
	call	httl
	pop	hl
	call	hskip
	ld	(HPTR), hl
	pop	bc
	pop	de
	ld	hl, #BUFFER
3$:	ld	b, #19
4$:	ld	a, h
	or	l
	jr	z, 5$
	ld	a, (hl)
	inc	hl
	or	a
	jr	nz, 6$
	ld	hl, #0
5$:	ld	a, #0x20
6$:	push	hl
	push	bc
	call	putcell
	pop	bc
	pop	hl
	inc	e
	djnz	4$
	inc	c
	ld	a, e
	cp	#80
	jr	c, 1$
	ret

; HL = entry A. An entry is its title (a keyword's token, or text ending in 0), its text and its example.
hentry:	ld	hl, #he0
	or	a
	ret	z
	ld	b, a
1$:	call	hskip
	djnz	1$
	ret

; HL = the entry after the one at HL
hskip:	ld	a, (hl)
	inc	hl
	cp	#0x80
	call	c, hskz
	call	hskz
hskz:	push	bc
	xor	a
	ld	b, a
	ld	c, a
	cpir
	pop	bc
	ret

; The title of the entry at HL to DE, ending in 0 (DE on it). HL = its text.
httl:	ld	a, (hl)
	inc	hl
	cp	#0x80
	jr	c, 3$
	push	hl
	call	kwname
	pop	hl
1$:	dec	de			; without the space or "(" kwname ends with
	ld	a, (de)
	cp	#0x20
	jr	z, 1$
	cp	#0x28
	jr	z, 1$
	inc	de
	xor	a
2$:	ld	(de), a
	ret
3$:	ld	(de), a
	or	a
	ret	z
	inc	de
	ld	a, (hl)
	inc	hl
	jr	3$

; A = the first keyword entry from letter A on
hlfirst:
	sub	#0x41
	ld	e, a
	ld	d, #0
	ld	hl, #HLETTER
	add	hl, de
	ld	a, (hl)
	ret

; The page of entry HSEL: Z to go back to the index, NZ to leave
hpage:	call	hexpand
	call	hwrap
	xor	a
	ld	(HLINE), a
1$:	call	hdrawpg
	call	hkey
	ld	hl, #HLINE
	cp	#UP
	jr	nz, 2$
	ld	a, (hl)
	or	a
	jr	z, 1$
	dec	(hl)
	jr	1$
2$:	cp	#DOWN
	jr	nz, 3$
	ld	a, (hl)
	add	a, #4
	ld	b, a
	ld	a, (HNL)
	cp	b
	jr	z, 1$
	jr	c, 1$
	inc	(hl)
	jr	1$
3$:	cp	#ESC
	jr	nz, 4$
	ld	hl, #FLAGS
	res	7, (hl)
	xor	a
	ret
4$:	cp	#HELP
	jr	nz, 5$
	or	a			; NZ
	ret
5$:	cp	#CR
	jr	z, 6$
	call	hletter			; a letter: the index, from that letter
	jr	nc, 1$
	xor	a
	ret
6$:	ld	hl, (HEX)		; ENTER: the example into the prompt
	ld	a, h
	or	l
	jr	z, 1$
	ld	de, #ACCS
	call	hdec
	ld	a, e
	ld	(LEN), a
	ld	(CUR), a
	ld	a, #1
	ld	(MODIF), a
	or	a			; NZ
	ret

; BUFFER = title, LF, body, and "LF e.g. example" if there is one
hexpand:
	ld	a, (HSEL)
	call	hentry
	ld	de, #BUFFER
	call	httl
	ld	a, #LF
	ld	(de), a
	inc	e
	call	hdec			; body
	ld	(HEX), hl
	ld	a, (hl)
	or	a
	jr	nz, 3$
	ld	hl, #0			; no example
	ld	(HEX), hl
	jr	4$
3$:	push	hl
	ld	hl, #egtxt
	ld	b, #6
5$:	ld	a, (hl)
	ld	(de), a
	inc	hl
	inc	e
	djnz	5$
	pop	hl
	call	hdec			; example
4$:	ld	a, e
	ld	(HLEN), a
	ret

; Expand the text at HL (ending in 0) to DE: 1 escapes the next byte, a pair code (gen_help.py) gives
; its two symbols. HL ends after the 0.
hdec:	ld	a, (hl)
	inc	hl
	or	a
	ret	z
	dec	a
	jr	nz, 1$
	ld	a, (hl)			; escaped
	inc	hl
	ld	(de), a
	inc	e
	jr	hdec
1$:	inc	a
	call	hput
	jr	hdec

; Symbol A to DE: a character, the title (2), or the two symbols of a pair (0x80-0xFF: pairs 0-127;
; 3-31 but LF: 129-157)
hput:	sub	#0x80
	jr	nc, 1$
	add	a, #0x80
	cp	#0x20
	jr	nc, 3$
	cp	#LF
	jr	z, 3$
	cp	#2
	jr	z, 4$
	add	a, #126
1$:	push	hl
	ld	l, a
	ld	h, #0
	add	hl, hl
	ld	bc, #HDICT
	add	hl, bc
	ld	a, (hl)
	inc	hl
	push	hl
	call	hput
	pop	hl
	ld	a, (hl)
	pop	hl
	jr	hput
3$:	ld	(de), a
	inc	de
	ret
4$:	push	hl			; the title, at the start of BUFFER up to its LF
	ld	hl, #BUFFER
5$:	ld	a, (hl)
	cp	#LF
	jr	z, 6$
	ld	(de), a
	inc	hl
	inc	de
	jr	5$
6$:	pop	hl
	ret

egtxt:	.db	LF
	.ascii	"e.g. "

; Lines of at most 20 characters, broken after a space where possible (gen_help.py does the same)
hwrap:	ld	hl, #LINES
	ld	c, #0			; position
	ld	b, #0			; lines
1$:	ld	a, (HLEN)
	cp	c
	jr	z, 9$
	ld	(hl), c			; start
	inc	hl
	push	hl
	ld	d, #0xFF		; last space seen
	ld	e, #0			; k
2$:	ld	a, c
	add	a, e
	ld	l, a
	ld	a, (HLEN)
	cp	l
	jr	z, 5$			; end of the text: the line ends there
	ld	h, #>BUFFER
	ld	a, (hl)
	cp	#LF
	jr	z, 6$
	cp	#0x20
	jr	nz, 3$
	ld	d, l
3$:	inc	e
	ld	a, e
	cp	#20
	jr	c, 2$
	ld	a, c			; 20 fit: does a space or the end follow?
	add	a, #20
	ld	l, a
	ld	a, (HLEN)
	cp	l
	jr	z, 5$
	ld	a, (hl)
	cp	#0x20
	jr	z, 7$
	cp	#LF
	jr	z, 6$
	ld	a, d			; break at the last space, or hard at 20
	inc	a
	ld	a, l
	jr	z, 5$
	ld	l, d
	jr	7$
5$:	pop	hl			; end = L, next = L
	ld	(hl), a
	ld	c, a
	jr	8$
6$:	ld	a, l			; LF at L: end = L, next = L+1
	pop	hl
	ld	(hl), a
	inc	a
	ld	c, a
	jr	8$
7$:	ld	a, l			; space at L: end = L, next = L+1
	pop	hl
	ld	(hl), a
	inc	a
	ld	c, a
8$:	inc	hl
	inc	b
	jr	1$
9$:	ld	a, b
	ld	(HNL), a
	ret

; Four lines from HLINE
hdrawpg:
	ld	e, #0
	ld	a, (HLINE)
	ld	c, a
1$:	ld	a, (HNL)
	cp	c
	ld	b, #0			; empty row
	jr	z, 2$
	jr	c, 2$
	ld	a, c
	add	a, a
	ld	l, a
	ld	h, #0
	push	de
	ld	de, #LINES
	add	hl, de
	pop	de
	ld	a, (hl)			; start
	inc	hl
	ld	b, (hl)			; end
	ld	l, a
	ld	a, b
	sub	l
	ld	b, a			; length
	ld	h, #>BUFFER
2$:	ld	d, #20
3$:	ld	a, b
	or	a
	ld	a, #0x20
	jr	z, 4$
	ld	a, (hl)
	inc	hl
	dec	b
4$:	push	hl
	push	bc
	call	putcell
	pop	bc
	pop	hl
	inc	e
	dec	d
	jr	nz, 3$
	inc	c
	ld	a, e
	cp	#80
	jr	c, 1$
	ret

; Carry and A = the entry whose title is the keyword at the cursor (letters and $ around CUR)
hctx:	ld	hl, #ACCS
	ld	a, (CUR)
	ld	l, a
1$:	ld	a, l			; back to the start of the word
	or	a
	jr	z, 2$
	dec	l
	ld	a, (hl)
	call	hword
	jr	c, 1$
	inc	l
2$:	ld	a, (hl)
	cp	#0x41			; a keyword starts with a letter
	ccf
	ret	nc
	cp	#0x5B
	ret	nc
	push	hl
	call	hlfirst
	push	af
	call	hentry
	pop	bc			; B = the entry
	ld	(HPTR), hl
	pop	hl
3$:	ld	a, (HCOUNT)
	cp	b
	ret	z			; NC: not found
	push	hl
	push	bc
	ld	hl, (HPTR)
	push	hl
	ld	de, #BUFFER
	call	httl
	pop	hl
	call	hskip
	ld	(HPTR), hl
	pop	bc
	pop	hl
	ld	de, #BUFFER
	ld	a, (de)
	cp	(hl)
	jr	nz, 7$			; past the keywords of this letter
	push	hl
4$:	ld	a, (de)			; title against the word
	or	a
	jr	z, 5$
	cp	(hl)
	jr	nz, 6$
	inc	de
	inc	l
	jr	4$
5$:	ld	a, (hl)			; title ended: so must the word
	call	hword
	jr	c, 6$
	pop	hl
	ld	a, b
	scf
	ret
6$:	pop	hl
	inc	b
	jr	3$
7$:	or	a
	ret

; Carry if A can be part of a keyword (A-Z, $)
hword:	cp	#0x24
	scf
	ret	z
	cp	#0x41
	ccf
	ret	nc
	cp	#0x5B
	ret
