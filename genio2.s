; genio2.s - page 2 of the VTech Genio 2000 OS layer for R.T. Russell's BBCZ80 interpreter:
; console on the 4x20 LCD, keyboard matrix, line input with recall of program lines.
; Reached through the jump table below and the RAM trampolines of genio1.s.
; Copyright (C) 2026 Santiago Crespo
; SPDX-License-Identifier: 0BSD

	.include "shared.inc"
; Page-1 addresses and call stubs (PBCDL, ESCAPE, AUTONO, PAGE, ...) come from out/p1calls.s

	.area	P2

.macro	SLOT	target, n
	.ifne	.-P2TAB-3*n
	.error	1
	.endif
	jp	target
.endm

P2TAB:	SLOT	p2init, S_INIT
	SLOT	OSRDCH, S_OSRDCH
	SLOT	OSWRCH, S_OSWRCH
	SLOT	OSLINE, S_OSLINE
	SLOT	OSKEY, S_OSKEY
	SLOT	CLRSCN, S_CLRSCN
	SLOT	PUTCSR, S_PUTCSR
	SLOT	GETCSR, S_GETCSR
	SLOT	PROMPT, S_PROMPT
	SLOT	trapkey, S_TRAPKEY
	SLOT	ASSEM, S_ASSEM
	SLOT	h_sound, S_SOUND
	SLOT	h_envel, S_ENVEL
	SLOT	h_wait, S_WAIT
	SLOT	h_mode, S_MODE
	SLOT	h_clg, S_CLG
	SLOT	h_gcol, S_GCOL
	SLOT	h_move, S_MOVE
	SLOT	h_draw, S_DRAW
	SLOT	h_plot, S_PLOT
	SLOT	h_fill, S_FILL
	SLOT	h_line, S_LINE
	SLOT	h_circle, S_CIRCLE
	SLOT	h_ellips, S_ELLIPS
	SLOT	h_rectan, S_RECTAN
	SLOT	h_origin, S_ORIGIN
	SLOT	h_point, S_POINT
	SLOT	h_csron, S_CSRON
	SLOT	h_csroff, S_CSROFF
	SLOT	h_modefn, S_MODEFN
	SLOT	h_widfn, S_WIDFN
	SLOT	h_adval, S_ADVAL
	.ifne	SMFS
	SLOT	fs_save, S_OSSAVE
	SLOT	fs_load, S_OSLOAD
	SLOT	fs_cli, S_OSCLI
	SLOT	fs_open, S_OSOPEN
	SLOT	fs_bget, S_OSBGET
	SLOT	fs_bput, S_OSBPUT
	SLOT	fs_stat, S_OSSTAT
	SLOT	fs_ext, S_GETEXT
	SLOT	fs_ptr, S_GETPTR
	SLOT	fs_putp, S_PUTPTR
	SLOT	fs_shut, S_OSSHUT
	.endif

; Start-up, after page 1 has set up RAM, the LCD and caps lock: CGRAM, LED, screen
p2init:
	.ifne	SMFS
	call	fsinit
	.endif
	call	accents
	call	setled
	jp	CLRSCN

; Glyphs of A I O U with acute accent for CGRAM 0-3 (design 0 of vgldk-genio's cgram_accents.h)
ACCGLY:	.db	0x01,0x02,0x0E,0x11,0x1F,0x11,0x11,0x00
	.db	0x01,0x02,0x0E,0x04,0x04,0x04,0x0E,0x00
	.db	0x01,0x02,0x0E,0x11,0x11,0x11,0x0E,0x00
	.db	0x01,0x02,0x11,0x11,0x11,0x11,0x0E,0x00

; DDRAM set-address command for the three column groups (0-3, 4-11, 12-19) of each row; the cell's
; column is added. Same map as the firmware table B0:07EE, which puts row 1, column 0 at A8.
ROWADR:	.db	0x80,0x84,0x8C, 0xC0,0xC4,0xCC, 0x84,0x8C,0x94, 0xC4,0xCC,0xD4

; Text is code page 850 (the firmware's own internal codes); these are drawn at another LCD code
LCDTAB:	.db	0xA4,0x9B, 0xA5,0x9C, 0xAD,0xA9, 0xA8,0x9F, 0xA7,0x9E	; n~ N~ inverted ! ? ordinal
	.db	0xB5,0, 0xD6,1, 0xE0,2, 0xE9,3, 0			; A I O U acute: CGRAM


;---------------------------------------------------------------- LCD

; ~70 us, more than the 37 us an HD44780 write needs (the busy flag is not read)
lcd_delay:
	push	bc
	ld	b, #32
1$:	djnz	1$
	pop	bc
	ret


; A = DDRAM set-address command of cell E (0-79). Destroys B,H,L,F.
ddaddr:	ld	a, e
	ld	hl, #ROWADR
1$:	cp	#20
	jr	c, 2$
	sub	#20
	inc	hl
	inc	hl
	inc	hl
	jr	1$
2$:	ld	b, a
	cp	#4
	jr	c, 3$
	inc	hl
	cp	#12
	jr	c, 3$
	inc	hl
3$:	add	a, (hl)
	cp	#0xC0
	ret	nz
	ld	a, #0xA8
	ret

; Write character A to cell E (0-79) and to the shadow screen. Destroys A,B,C,H,L,F.
putcell:
	push	de
	ld	d, #0
	ld	hl, #SCR
	add	hl, de
	pop	de
	ld	(hl), a
	ld	hl, #LCDTAB
	call	look
	ld	c, a
	ld	a, (GSHOW)		; the graphics window covers cells 28-31 and 48-51 (the centre)
	or	a
	jr	z, 2$
	ld	a, e
	sub	#28
	cp	#4
	jr	c, 1$
	ld	a, e
	sub	#48
	cp	#4
	jr	nc, 2$
	add	a, #4
1$:	ld	c, a
2$:	call	ddaddr
	ld	b, a
	ld	a, i			; P/V = IFF2
	di
	push	af
	ld	a, b
	out	(0x0A), a
	call	lcd_delay
	ld	a, c
	out	(0x0B), a
	call	lcd_delay
	pop	af
	ret	po
	ei
	ret

; Rewrite the LCD from the shadow screen. Destroys A,B,C,H,L,F.
redraw::
	push	de
	ld	e, #0
1$:	ld	hl, #SCR
	ld	d, #0
	add	hl, de
	ld	a, (hl)
	call	putcell
	inc	e
	ld	a, e
	cp	#80
	jr	c, 1$
	pop	de
	ret

; Load B bytes from HL into CGRAM from character 0. Interrupts stay off: the firmware's interrupt
; routine moves the LCD address to its cursor.
cgload:	ld	a, i
	di
	push	af
	ld	a, #0x40
	out	(0x0A), a
	call	lcd_delay
1$:	ld	a, (hl)
	out	(0x0B), a
	call	lcd_delay
	inc	hl
	djnz	1$
	pop	af
	ret	po
	ei
	ret

; The accented capitals into CGRAM 0-3
accents:
	ld	hl, #ACCGLY
	ld	b, #32
	jr	cgload

;CLRSCN - Clear screen. Destroys A,D,E,H,L,F.
CLRSCN:	push	bc
	ld	hl, #SCR
	ld	b, #80
1$:	ld	(hl), #0x20
	inc	hl
	djnz	1$
	call	redraw
	pop	bc
	xor	a
	ld	(CX), a
	ld	(CY), a
	ret

;PUTCSR - DE = x, HL = y.  GETCSR - returns DE = x, HL = y.
PUTCSR:	ld	a, e
	cp	#20
	jr	c, 1$
	ld	a, #19
1$:	ld	(CX), a
	ld	a, l
	cp	#4
	jr	c, 2$
	ld	a, #3
2$:	ld	(CY), a
	ret

GETCSR:	ld	a, (CX)
	ld	e, a
	ld	a, (CY)
	ld	l, a
	xor	a
	ld	d, a
	ld	h, a
	ret

; E = cell of the cursor (column 20 shows on column 19). Destroys A,F.
curcell:
	ld	a, (CY)
	ld	e, a
	add	a, a
	add	a, a
	add	a, e			; 5*row
	add	a, a
	add	a, a			; 20*row
	ld	e, a
	ld	a, (CX)
	cp	#20
	jr	c, 1$
	dec	a
1$:	add	a, e
	ld	e, a
	ret

; Underline cursor, drawn by the firmware ISR's LCD service (none without the ISR). Destroys A,F.
showcur:
	ld	a, (CX)
	cp	#20
	jr	c, 1$
	dec	a
1$:	ld	(FW_DIRTY+4), a
	ld	a, (CY)
	ld	(FW_DIRTY+5), a
	ld	a, #1
	jr	setcur

hidecur:
	xor	a
setcur:	ld	(FW_DIRTY+7), a
	ret

;OSWRCH - Write character A to the console, or capture it (CAPT). Destroys nothing.
OSWRCH:	push	af
	push	bc
	push	de
	push	hl
	ld	c, a
	ld	a, (CAPT)
	or	a
	jr	nz, capt
	ld	a, c
	cp	#7
	jr	z, 1$
	ld	a, #1			; the output must stay readable before the editor comes back
	ld	(OUTDIRTY), a
1$:	ld	a, c
	call	vdu
	jr	c, wdone
	call	wrch
wdone:	pop	hl
	pop	de
	pop	bc
	pop	af
	ret

capt:	dec	a
	jr	z, capl
	dec	a
	jr	z, cape
	ld	hl, (EDPTR)		; 3: raw, into the line buffer
	ld	(hl), c
	inc	l
	ld	(EDPTR), hl
	jr	wdone

; 2: the message of an error, printing characters only, up to three rows
cape:	ld	a, c
	cp	#0x20
	jr	c, wdone
	ld	a, (ERRLEN)
	cp	#60
	jr	nc, wdone
	ld	e, a
	ld	d, #0
	ld	hl, #ERRBUF
	add	hl, de
	ld	(hl), c
	ld	hl, #ERRLEN
	inc	(hl)
	jr	wdone

; 1: LIST output for the editor: the first NBEFORE lines into the VIEW rows (20 characters each),
; the next one into the line buffer. Leading spaces are dropped.
capl:	ld	a, c
	cp	#CR
	jr	nz, 1$
	ld	hl, #CAPIDX
	inc	(hl)
	xor	a
	ld	(CAPCOL), a
	jr	wdone
1$:	cp	#0x20
	jr	c, wdone
	ld	a, (CAPCOL)
	or	a
	jr	nz, 2$
	ld	a, c
	cp	#0x20
	jr	z, wdone
2$:	ld	a, (NBEFORE)
	ld	b, a
	ld	a, (CAPIDX)
	cp	b
	jr	z, 5$
	jr	nc, 4$
	add	a, #3			; row = 3 - NBEFORE + index
	sub	b
	ld	e, a
	add	a, a
	add	a, a
	add	a, e
	add	a, a
	add	a, a
	ld	e, a
	ld	a, (CAPCOL)
	cp	#20
	jr	nc, 4$
	add	a, e
	ld	e, a
	ld	d, #0
	ld	hl, #VIEW
	add	hl, de
	ld	(hl), c
	jr	4$
5$:	ld	hl, (EDPTR)
	ld	a, l
	cp	#253
	jr	nc, 4$
	ld	(hl), c
	inc	l
	ld	(EDPTR), hl
4$:	ld	hl, #CAPCOL
	ld	a, (hl)
	inc	a
	jr	z, 6$
	ld	(hl), a
6$:	jp	wdone

;PROMPT - prints nothing: it tells OSLINE that this line is for the interpreter's ">" prompt.
PROMPT:	push	af
	ld	a, #1
	ld	(ATPROMPT), a
	pop	af
	ret

wrch:	cp	#0x20
	jr	c, wctrl
	cp	#0x7F
	ret	z
	push	af
	ld	a, (CX)
	cp	#20
	call	nc, newline		; deferred wrap: the line breaks on the next character
	call	curcell
	pop	af
	call	putcell
	ld	hl, #CX
	inc	(hl)
	ret

wctrl:	cp	#CR
	jr	z, wcr
	cp	#LF
	jr	z, wlf
	cp	#8
	jr	z, wbs
	cp	#12
	jp	z, CLRSCN
	cp	#7
	jr	z, beep
	cp	#30
	ret	nz
	ld	de, #0
	ld	h, d
	ld	l, e
	jp	PUTCSR

newline:
	xor	a
	ld	(CX), a
wlf:	ld	a, (CY)
	cp	#3
	jr	z, scroll
	inc	a
	ld	(CY), a
	ret

wcr:	xor	a
	ld	(CX), a
	ret

wbs:	ld	hl, #CX
	ld	a, (hl)
	cp	#20			; past column 19 (deferred wrap): back onto column 19
	jr	nc, 3$
	or	a
	jr	z, 1$
	dec	(hl)
	ret
1$:	ld	a, (CY)
	or	a
	ret	z
	dec	a
	ld	(CY), a
3$:	ld	(hl), #19
	ret

scroll:	ld	hl, #SCR+20
	ld	de, #SCR
	ld	bc, #60
	ldir
	ex	de, hl			; HL = start of the last row
	ld	b, #20
1$:	ld	(hl), #0x20
	inc	hl
	djnz	1$
	jp	redraw

; Square wave on the speaker (port 0x12 bit 3), about 1 kHz for 0.1 s, interrupts off
beep:	ld	a, i
	di
	push	af
	ld	de, #200
1$:	ld	a, (P12)
	xor	#0x08
	ld	(P12), a
	out	(0x12), a
	ld	b, #234
2$:	djnz	2$
	dec	de
	ld	a, d
	or	e
	jr	nz, 1$
	call	setled
	pop	af
	ret	po
	ei
	ret

; Caps-lock LED (port 0x12 bit 5); bit 0 (power off) is never set here
setled:	ld	a, (CAPS)
	rrca
	rrca
	rrca
	and	#0x20
	ld	(P12), a
	out	(0x12), a
	ret


;---------------------------------------------------------------- keyboard

; One keyboard poll with auto-repeat. Returns A = character or 0. Destroys A,B,C,D,E,H,L,F.
kpoll:	call	offpoll
	call	kscan
	ld	hl, #RELCNT		; a release counts after two empty scans (contact bounce)
	ld	a, d
	inc	a
	jr	z, 7$
	ld	(hl), #0
	jr	8$
7$:	inc	(hl)
	ld	a, (hl)
	cp	#2
	ld	a, #0
	ret	c
8$:	ld	hl, #LASTSC
	ld	a, d
	cp	(hl)
	ld	(hl), a
	inc	hl			; REPCNT
	jr	z, 1$
	ld	(hl), #50		; first repeat after ~0.5 s of polls
	jr	2$
1$:	inc	a
	ret	z			; no key
	dec	(hl)
	ld	a, #0
	ret	nz
	ld	(hl), #8
2$:	ld	a, d
	inc	a
	ret	z
	ld	a, d			; activity key: codes 192-213, 240-255 in panel order
	sub	#64
	jr	c, 10$
	cp	#35
	jr	c, 11$
	sub	#2
11$:	cp	#22
	jr	c, 12$
	add	a, #0x1A
12$:	add	a, #0xC0
	ret
10$:	ld	hl, #KTAB
	ld	c, d
	ld	b, #0
	add	hl, bc
	ld	a, (hl)
	or	a
	ret	z
	cp	#1			; caps lock
	jr	nz, 3$
	ld	hl, #CAPS
	xor	(hl)
	ld	(hl), a
	call	setled
	xor	a
	ld	(REPCNT), a		; no repeat for caps lock (next one after 256 polls)
	ret
3$:	ld	c, a
	ld	a, (CAPS)
	xor	e
	and	#1
	ld	d, a			; D = 1 for upper case (SHIFT xor caps lock)
	ld	a, c
	bit	1, e
	jr	z, 4$
	ld	hl, #ACCLO		; ALT+vowel: accented, ALT+digit: the red legend
	dec	d
	jr	nz, 9$
	ld	hl, #ACCUP
9$:	call	look
	ret	c
	ld	hl, #ALTTAB
	jr	look
4$:	sub	#'a
	cp	#26
	ld	a, c
	jr	nc, 5$
	dec	d
	ret	nz
	sub	#0x20
	ret
5$:	dec	d
	jr	nz, 6$
	ld	hl, #CASETAB
	call	look
	ret	c
6$:	bit	0, e
	ret	z
	ld	hl, #SHFTAB
; Pairs (from, to) ending in 0 at HL: A = the pair's "to" and carry if A is found, else A unchanged. Destroys C,H,L,F.
look:	ld	c, a
1$:	ld	a, (hl)
	or	a
	ld	a, c
	ret	z
	cp	(hl)
	inc	hl
	jr	nz, 2$
	ld	a, (hl)
	scf
	ret
2$:	inc	hl
	jr	1$

; Scancode (row*8+col) -> code. 0 = ignored, 1 = caps lock. Matrix as mapped on the unit.
KTAB:	.db	HELP, 1,    '2,   '4,   '6,   '8,   '0,   0	; AYUDA (SHIFT: TAB)
	.db	0x5E, '1,   '3,   '5,   '7,   '9,   8,    0	; PAUSA, BORRAR=BS
	.db	0,    'q,   'e,   't,   'u,   'o,   0x81, LEFT	; u-diaeresis
	.db	0,    'a,   's,   'f,   'h,   'k,   0xA4, RIGHT	; n-tilde
	.db	0,    'z,   'd,   'g,   'j,   'l,   0x3B, CR	; INTRO
	.db	0,    0,    'x,   'v,   'n,   0x2C, 0x27, 0x7F	; JUGADOR DERECHA/DEL
	.db	0,    0x20, 'c,   'b,   'm,   0x2E, 0,    ESC	; RESPUESTA
	.db	0,    0,    'w,   'r,   'y,   'i,   'p,   0

; Pairs (from, to) for SHIFT, upper case, ALT; code page 850
SHFTAB:	.db	'1,0xAD, '2,0xA8, '3,0x23, '4,0x24, '5,0x25, '6,0x2F, '7,0x26, '8,0x2A, '9,0x28, '0,0x29
	.db	0x2C,0x3F, 0x2E,0x21, 0x27,0x22, 0x3B,0x3A, LEFT,0x3C, RIGHT,0x3E, HELP,9, 0
CASETAB:	.db	0xA4,0xA5, 0x81,0x9A, 0
ACCLO:	.db	'a,0xA0, 'e,0x82, 'i,0xA1, 'o,0xA2, 'u,0xA3, 0
ACCUP:	.db	'a,0xB5, 'e,0x90, 'i,0xD6, 'o,0xE0, 'u,0xE9, 0
ALTTAB:	.db	'1,0x5C, '2,0x40, '3,0x2D, '4,0x5F, '5,0x2B, '6,0x5B, '7,0x5D, '8,0x3D, '9,0x7C, '0,0x7E, 0x81,UP, 0x3B,DOWN, LEFT,HOME, RIGHT,END, 0

; ~10 ms between keyboard polls
pause:	push	bc
	ld	bc, #2300
1$:	dec	bc
	ld	a, b
	or	c
	jr	nz, 1$
	pop	bc
	ret


;OSKEY - HL = time limit (cs). Carry set: A = character; carry clear: time-out. Destroys A,H,L,F.
OSKEY:	ld	a, (KEYFLG)
	or	a
	jr	z, 1$
	xor	a
	ld	(KEYFLG), a
	ld	a, (KEYCH)
	scf
	ret
1$:	push	bc
	push	de
	push	hl
	call	showcur
	pop	hl
2$:	push	hl
	call	kpoll
	pop	hl
	or	a
	jr	nz, 3$
	ld	a, h
	or	l
	jr	z, 4$
	call	pause
	dec	hl
	jr	2$
3$:	cp	#ESC
	call	z, escset
	scf
4$:	push	af
	call	hidecur
	pop	af
	pop	de
	pop	bc
	ret

escset:	ld	hl, #FLAGS
	set	7, (hl)
	ret

;OSRDCH - Wait for a character. Destroys A,F.
OSRDCH:	push	hl
1$:	ld	hl, #0xFFFF
	call	OSKEY
	jr	nc, 1$
	pop	hl
	ret

;trapkey - keyboard sample for TRAP: Escape sets the flag, another key is kept for GET/INKEY. Destroys A,H,L,F.
trapkey:
	push	bc
	push	de
	call	kpoll
	or	a
	jr	z, 1$
	cp	#ESC
	jr	nz, 2$
	call	escset
	jr	1$
2$:	ld	(KEYCH), a
	ld	a, #1
	ld	(KEYFLG), a
1$:	pop	de
	pop	bc
	ret

; Abort with Escape (in page 1) if the flag is set
ltrap:	ld	a, (FLAGS)
	or	a
	ret	p
	ld	hl, #FLAGS
	res	7, (hl)
	ld	hl, #ESCAPE
	jp	R_JP1

;---------------------------------------------------------------- line input

;OSLINE - Read a line into the buffer at HL (L=0), terminated by CR. Returns A=0.
; At the ">" prompt this is the screen editor; for INPUT, and in AUTO mode, a plain console line.
OSLINE:	ld	a, (CAPT)
	cp	#2
	call	z, errdone
	ld	a, (ATPROMPT)
	or	a
	jp	z, conline
	xor	a
	ld	(ATPROMPT), a
	ld	de, (AUTONO)
	ld	a, d
	or	e
	jp	nz, conline
	ld	a, (CAPT)
	dec	a
	jr	nz, 1$
	call	capdone			; the listing asked for below has been captured
	jr	edit
1$:	ld	a, (OUTDIRTY)
	or	a
	call	nz, showout
	ld	a, (PENDNAV)
	or	a
	call	nz, navigate
	ld	a, (VIEWOK)
	or	a
	jp	z, mklist

; The editor: rows 0-2 show the program lines before the one in the prompt (row 3).
edit:	call	ghide
	xor	a
	ld	(CURSOFF), a
	ld	hl, #ACCS
	ld	a, (LEN)
	ld	l, a
	ld	(hl), #CR
	call	drawtop
ed_loop:
	call	drawin
	ld	a, (PENDKEY)
	or	a
	jr	z, 1$
	ld	b, a
	xor	a
	ld	(PENDKEY), a
	ld	a, b
	jr	2$
1$:	call	getkey
2$:	cp	#ESC
	jr	nz, 3$
	call	ltrap
	jr	ed_loop
3$:	cp	#CR
	jp	z, ed_enter
	cp	#HELP
	jp	z, ed_help
	cp	#UP
	jp	z, ed_nav
	cp	#DOWN
	jp	z, ed_nav
	cp	#8
	jp	z, ed_bs
	cp	#0x7F
	jp	z, ed_del
	ld	hl, #CUR
	cp	#LEFT
	jp	z, ed_left
	cp	#RIGHT
	jp	z, ed_right
	cp	#HOME
	jp	z, ed_home
	cp	#END
	jp	z, ed_end
	call	actkey
	jr	nc, ed_ins
	call	ACTTOK1
	ld	de, #GTMP
	call	kwname			; the keyword's name, from the interpreter's table
	ld	hl, #GTMP
4$:	ld	a, (hl)
	inc	hl
	push	hl
	push	de
	call	insch
	pop	de
	pop	hl
	ld	a, l
	cp	e
	jr	nz, 4$
	jp	ed_mod
ed_ins:	cp	#0x20
	jp	c, ed_loop
	cp	#LEFT
	jr	c, 2$
	cp	#HELP+1
	jp	c, ed_loop
2$:	call	insch
	jr	ed_mod

; Insert A at the cursor
insch:	ld	c, a
	ld	a, (LEN)
	cp	#253
	ret	nc
	ld	hl, #ACCS
	ld	l, a
	ld	a, (CUR)
	ld	b, a
1$:	ld	a, l
	cp	b
	jr	z, 2$
	dec	l
	ld	a, (hl)
	inc	l
	ld	(hl), a
	dec	l
	jr	1$
2$:	ld	(hl), c
	ld	hl, #LEN
	inc	(hl)
	ld	hl, #CUR
	inc	(hl)
	ret

; Carry and A = 0-37 if A is the code of an activity key
actkey:	cp	#0xF0
	jr	c, 1$
	sub	#0xDA
	scf
	ret
1$:	sub	#0xC0
	cp	#22
	ret	c
	add	a, #0xC0
	or	a
	ret

; A = 0-37: A = the token of that key's keyword
ACTTOK1:
	ld	e, a
	ld	d, #0
	ld	hl, #ACTTOK
	add	hl, de
	ld	a, (hl)
	ret

ed_bs:	ld	a, (CUR)
	or	a
	jp	z, ed_loop
	dec	a
	ld	(CUR), a
	jr	delat
ed_del:	ld	a, (LEN)
	ld	b, a
	ld	a, (CUR)
	cp	b
	jp	z, ed_loop
; Delete the character at A
delat:	ld	hl, #ACCS
	ld	l, a
	ld	a, (LEN)
	ld	b, a
1$:	ld	a, l
	inc	a
	cp	b
	jr	nc, 2$
	inc	l
	ld	a, (hl)
	dec	l
	ld	(hl), a
	inc	l
	jr	1$
2$:	ld	hl, #LEN
	dec	(hl)
ed_mod:	ld	a, #1
	ld	(MODIF), a
	ld	hl, #ACCS
	ld	a, (LEN)
	ld	l, a
	ld	(hl), #CR
	jp	ed_loop

; Cursor movements (HL = CUR); they also hide an error message
ed_left:
	ld	a, (hl)
	or	a
	jr	z, ed_mv
	dec	(hl)
	jr	ed_mv
ed_right:
	ld	a, (LEN)
	cp	(hl)
	jr	z, ed_mv
	inc	(hl)
	jr	ed_mv
ed_home:
	ld	(hl), #0
	jr	ed_mv
ed_end:	ld	a, (LEN)
	ld	(hl), a
ed_mv:	call	noerr
	jp	ed_loop

; ALT+U-diaeresis / ALT+;: to the line above / below. A changed program line is stored first.
ed_nav:	ld	b, a
	call	noerr
	ld	a, (MODIF)
	or	a
	jr	z, 1$
	call	lineno
	jr	nc, 1$
	ld	a, b
	ld	(PENDNAV), a
	ld	(CURLN), de
	ld	(BOUND), de
	jr	ed_ret
1$:	ld	a, b
	call	navigate
	jp	z, ed_loop		; nothing above
	jp	mklist

; INTRO: the line goes to the interpreter. A program line moves up into the view and the prompt
; is left empty; a command gets the whole screen for its output.
ed_enter:
	call	noerr
	call	lineno
	jr	nc, 1$
	ld	hl, #0
	ld	(CURLN), hl
	inc	de
	ld	(BOUND), de
	jr	ed_ret
1$:	ld	a, (LEN)
	or	a
	jr	z, ed_ret0
	ld	hl, (CURLN)
	ld	a, h
	or	l
	jr	z, 2$
	ld	(BOUND), hl
	ld	hl, #0
	ld	(CURLN), hl
2$:	xor	a			; the command line scrolls up, its output follows
	ld	(CX), a
	ld	a, #3
	ld	(CY), a
	call	wlf
	ld	a, (GMODE)		; and the graphics window comes back
	or	a
	call	nz, gshow
ed_ret:	xor	a
	ld	(VIEWOK), a
ed_ret0:
	xor	a
	ld	(LEN), a
	ld	(CUR), a
	ld	(HOFS), a
	ld	(MODIF), a
	ret

; Wait for a key; meanwhile an error message blinks
getkey:	ld	hl, #0xFFFF
	ld	a, (ERRSHOW)
	or	a
	jr	z, 1$
	ld	hl, #25
1$:	call	OSKEY
	ret	c
	ld	hl, #BLINK
	ld	a, (hl)
	xor	#1
	ld	(hl), a
	call	drawtop
	jr	getkey

; Hide the error message
noerr:	ld	a, (ERRSHOW)
	or	a
	ret	z
	xor	a
	ld	(ERRSHOW), a
	jp	drawtop

; Rows 0-2: VIEW, or the error message on the rows it needs while it blinks on
drawtop:
	ld	e, #0
1$:	ld	hl, #VIEW
	ld	d, #0
	add	hl, de
	ld	c, (hl)
	ld	a, (ERRSHOW)
	ld	b, a
	ld	a, (BLINK)
	and	b
	jr	z, 3$
	ld	a, (ERRCELLS)
	ld	b, a
	ld	a, e
	cp	b
	jr	nc, 3$
	ld	c, #0x20
	ld	a, (ERRLEN)
	ld	b, a
	ld	a, e
	cp	b
	jr	nc, 3$
	ld	hl, #ERRBUF
	add	hl, de
	ld	c, (hl)
3$:	ld	a, c
	call	putcell
	inc	e
	ld	a, e
	cp	#60
	jr	c, 1$
	ret

; Row 3: ">" and the part of the line around the cursor; the hardware cursor goes to CUR
drawin:	ld	a, (CUR)
	ld	b, a
	ld	a, (HOFS)
	cp	b
	jr	c, 1$
	jr	z, 1$
	ld	a, b
	jr	2$
1$:	add	a, #18
	cp	b
	jr	nc, 3$
	ld	a, b
	sub	#18
2$:	ld	(HOFS), a
3$:	ld	e, #60
	ld	a, #0x3E
	call	putcell
4$:	inc	e
	ld	a, (HOFS)
	add	a, e
	sub	#61
	ld	b, a
	ld	a, (LEN)
	cp	b
	ld	a, #0x20
	jr	z, 5$
	jr	c, 5$
	ld	hl, #ACCS
	ld	l, b
	ld	a, (hl)
5$:	call	putcell
	ld	a, e
	cp	#79
	jr	c, 4$
	ld	a, (HOFS)
	ld	b, a
	ld	a, (CUR)
	sub	b
	inc	a
	ld	(CX), a
	ld	a, #3
	ld	(CY), a
	ret

; The interpreter printed something: leave it on the screen (with the error, if there was one)
; until a key is pressed. That key is kept as the first one of the editor, unless it is INTRO or Escape.
showout:
	ld	a, (ERRSHOW)
	or	a
	jr	z, 2$
	ld	a, (CX)			; start the message on a line of its own
	or	a
	jr	z, 6$
	ld	a, #CR
	call	wrch
	ld	a, #LF
	call	wrch
6$:	ld	hl, #ERRBUF
	ld	a, (ERRLEN)
	ld	b, a
	inc	b
	jr	3$
1$:	ld	a, (hl)
	push	bc
	push	hl
	call	wrch
	pop	hl
	pop	bc
	inc	hl
3$:	djnz	1$
	ld	a, #CR
	call	wrch
	ld	a, #LF
	call	wrch
2$:	ld	a, #0x3E
	call	wrch
	call	OSRDCH
	cp	#ESC
	jr	nz, 4$
	ld	hl, #FLAGS
	res	7, (hl)
	jr	5$
4$:	cp	#CR
	jr	z, 5$
	ld	(PENDKEY), a
5$:	xor	a
	ld	(OUTDIRTY), a
	ret

; After an untrapped error: show its message, and load the line it happened in
errdone:
	xor	a
	ld	(CAPT), a
	ld	(VIEWOK), a
	ld	(LEN), a
	ld	(CUR), a
	ld	(MODIF), a
	ld	(PENDNAV), a
	inc	a
	ld	(ERRSHOW), a
	ld	(BLINK), a
	ld	a, (ERRLEN)		; cells of the rows the message needs
	ld	b, a
	xor	a
1$:	cp	b
	jr	nc, 2$
	add	a, #20
	jr	1$
2$:	ld	(ERRCELLS), a
	ld	hl, (ERL)
	ld	a, h
	or	l
	ret	z
	ld	(CURLN), hl
	ld	(BOUND), hl
	ret

; The listing has been captured: the view is ready, and the loaded line (if any) is in ACCS
capdone:
	xor	a
	ld	(CAPT), a
	ld	(MODIF), a
	ld	(HOFS), a
	inc	a
	ld	(VIEWOK), a
	ld	a, (LOADTGT)
	or	a
	jr	z, 1$
	ld	a, (EDPTR)
1$:	ld	(LEN), a
	ld	(CUR), a
	ret

; Ask the interpreter for "LIST a,b": up to three lines before BOUND for the view, and the line
; CURLN (if it still exists) for the prompt. The output is captured (CAPT = 1).
mklist:	xor	a
	ld	(LOADTGT), a
	ld	de, (CURLN)
	ld	a, d
	or	e
	jr	z, 2$
	call	firstge
	jr	z, 1$
	or	a
	sbc	hl, de
	jr	nz, 1$
	ld	a, #1
	ld	(LOADTGT), a
	ld	(BOUND), de
	jr	2$
1$:	ld	hl, #0
	ld	(CURLN), hl
2$:	ld	de, (BOUND)
	ld	c, #0
3$:	push	bc
	call	prevln
	pop	bc
	jr	z, 4$
	ld	a, c
	or	a
	jr	nz, 5$
	ld	(LISTB), hl
5$:	ex	de, hl
	inc	c
	ld	a, c
	cp	#3
	jr	c, 3$
4$:	ld	a, c
	ld	(NBEFORE), a
	ld	(LISTA), de
	ld	hl, #VIEW		; blank view
	ld	b, #60
6$:	ld	(hl), #0x20
	inc	hl
	djnz	6$
	ld	a, (LOADTGT)
	or	a
	jr	z, 7$
	ld	hl, (CURLN)
	ld	(LISTB), hl
	jr	8$
7$:	ld	a, c
	or	a
	jr	nz, 8$
	inc	a			; nothing to list
	ld	(VIEWOK), a
	xor	a
	ld	(LEN), a
	ld	(CUR), a
	jp	edit
8$:	ld	hl, #ACCS
	ld	de, #lstxt
	ld	b, #5
9$:	ld	a, (de)
	ld	(hl), a
	inc	de
	inc	l
	djnz	9$
	ld	(EDPTR), hl
	ld	a, #3
	ld	(CAPT), a
	ld	hl, (LISTA)
	call	PBCDL
	ld	a, #0x2C
	call	OSWRCH
	ld	hl, (LISTB)
	call	PBCDL
	ld	hl, (EDPTR)
	ld	(hl), #CR
	ld	l, #0
	ld	(EDPTR), hl
	xor	a
	ld	(CAPIDX), a
	ld	(CAPCOL), a
	inc	a
	ld	(CAPT), a
	xor	a
	ret

lstxt:	.ascii	"LIST "

; A = UP or DOWN: move the edit position to the program line above / below. Returns Z if there
; is no line above (nothing changes); past the last line the prompt is empty, at the end.
navigate:
	ld	b, a
	xor	a
	ld	(PENDNAV), a
	ld	de, (CURLN)
	ld	a, d
	or	e
	jr	nz, 1$
	ld	de, (BOUND)
	ld	a, b
	cp	#UP
	jr	z, 3$
	jr	2$
1$:	ld	a, b
	cp	#UP
	jr	z, 3$
	inc	de
2$:	call	firstge
	jr	nz, 4$
	ld	hl, #0
	ld	(CURLN), hl
	dec	hl
	ld	(BOUND), hl
	jr	5$
3$:	call	prevln
	ret	z
4$:	ld	(CURLN), hl
	ld	(BOUND), hl
5$:	xor	a
	ld	(VIEWOK), a
	ld	(LEN), a
	ld	(CUR), a
	ld	(MODIF), a
	inc	a
	ret

; DE = the number at the start of the line in ACCS, carry set if there is one
lineno:	ld	hl, #ACCS
	ld	de, #0
1$:	ld	a, (hl)
	inc	l
	cp	#0x20
	jr	z, 1$
	sub	#0x30
	cp	#10
	ret	nc
2$:	push	hl
	ld	h, d
	ld	l, e
	add	hl, hl
	add	hl, hl
	add	hl, de
	add	hl, hl
	ld	e, a
	ld	d, #0
	add	hl, de
	ex	de, hl
	pop	hl
	ld	a, (hl)
	inc	l
	sub	#0x30
	cp	#10
	jr	c, 2$
	scf
	ret

; HL = the number of the last program line below DE; Z if there is none. Destroys A,B,C.
prevln:	ld	hl, (PAGE)
	ld	bc, #0xFFFF
1$:	ld	a, (hl)
	or	a
	jr	z, 9$
	push	hl
	call	lnum
	jr	nc, 8$
	ld	b, h
	ld	c, l
	pop	hl
	call	nextln
	jr	1$
8$:	pop	hl
9$:	ld	h, b
	ld	l, c
	ld	a, b
	and	c
	inc	a
	ret

; HL = the number of the first program line at or above DE; Z if there is none. Destroys A,B,C.
firstge:
	ld	hl, (PAGE)
1$:	ld	a, (hl)
	or	a
	ret	z
	push	hl
	call	lnum
	pop	bc
	jr	nc, 2$
	ld	h, b
	ld	l, c
	call	nextln
	jr	1$
2$:	or	#1
	ret

; HL = line: HL = its number, compared with DE (C: below, Z: equal)
lnum:	inc	hl
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	or	a
	sbc	hl, de
	add	hl, de
	ret

; HL = line: HL = the next line
nextln:	ld	a, (hl)
	add	a, l
	ld	l, a
	ret	nc
	inc	h
	ret

; Plain line input at the console (INPUT, AUTO)
conline:
	ld	(hl), #CR
1$:	call	OSRDCH
	cp	#ESC
	jr	nz, 5$
	call	ltrap
	jr	1$
5$:	cp	#CR
	jr	z, 9$
	cp	#8
	jr	z, 6$
	cp	#0x7F
	jr	z, 6$
	cp	#0x20
	jr	c, 1$
	cp	#LEFT			; cursor and activity keys are not part of a line
	jr	c, 7$
	cp	#HELP+1
	jr	c, 1$
	call	actkey
	jr	c, 1$
7$:	ld	b, a
	ld	a, l
	cp	#255
	jr	z, 1$
	ld	(hl), b
	inc	l
	ld	(hl), #CR
	ld	a, b
	call	OSWRCH
	jr	1$
6$:	ld	a, l
	or	a
	jr	z, 1$
	dec	l
	ld	(hl), #CR
	ld	a, #8
	call	OSWRCH
	ld	a, #0x20
	call	OSWRCH
	ld	a, #8
	call	OSWRCH
	jr	1$
9$:	call	OSWRCH
	ld	a, #LF
	call	OSWRCH
	xor	a
	ret
