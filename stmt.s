; stmt.s - page 2: the statements and functions of HOOK.Z80 that the Genio can do, the VDU
; codes they use, and the 20x16 graphics window drawn with the 8 CGRAM characters.
; Statements are entered from page 1 through R_FAR and continue at the interpreter's XEQ;
; arguments are read with the interpreter's own routines (stubs in p1calls.s), as ACORN.Z80 does.
; Copyright (C) 2026 Santiago Crespo
; SPDX-License-Identifier: 0BSD

	.include "shared.inc"

	.area	P2

TBY = 0x0F			; tokens
TTO = 0xB8
TFILL = 0x03

; GTMP fields
PLK = GTMP			; PLOT code being drawn
OPACT = GTMP+1			; action and colour of the pixels being drawn
OPCOL = GTMP+2
GOUT = GTMP+3			; shape: 1 = outline only
GFN = GTMP+4			; shape: inside test
SX = GTMP+6			; scan position
SY = GTMP+8
LX = GTMP+10			; line: current point; shapes: centre
LY = GTMP+12
DX = GTMP+14			; line: |dx|, -|dy|; circle: r^2; ellipse: a^2, b^2
DY = GTMP+16
SXS = GTMP+18			; line: steps
SYS = GTMP+19
ERR = GTMP+20			; line: error; ellipse: a^2*b^2 (4 bytes)

;---------------------------------------------------------------- statement endings

; Continue with the next statement. The trampoline's return address is dropped: statements
; are entered by a jump and never return.
xeqgo::	pop	hl
	ld	hl, #XEQ
	jp	R_JP1

; The fatal error "Sorry" of page 1
sorry:	ld	hl, #SORRY
	jp	R_JP1

; Functions return an integer: low word in HL', high word in HL, C = 0 (as ACORN.Z80 does)
retu8:	ld	h, #0
retint:	ld	a, h
	add	a, a
	sbc	a, a
exxret:	exx
	ld	h, a
	ld	l, a
	xor	a
	ld	c, a
	ret

cexpri:	call	COMMA
	jp	EXPRI

; Read ",expr" twice: DE = first, HL = second
cexpr2:	call	cexpri
	exx
	push	hl
	call	cexpri
	exx
	pop	de
	ret

;---------------------------------------------------------------- statements

;MODE n
h_mode::
	call	EXPRI
	exx
	ld	a, l
	call	mode
	jp	xeqgo

;CLG
h_clg::	call	clg
	jp	xeqgo

;GCOL [a,]c
h_gcol::
	call	EXPRI
	exx
	ld	e, #0
	ld	a, (iy)
	cp	#0x2C
	jr	nz, 1$
	push	hl
	call	cexpri
	exx
	pop	de
1$:	ld	a, e
	ld	c, l
	call	gcol
	jp	xeqgo

;ORIGIN x,y
h_origin::
	call	EXPRI
	exx
	push	hl
	call	cexpri
	exx
	pop	de
	ld	(ORGX), de
	ld	(ORGY), hl
	jp	xeqgo

;MOVE [BY] x,y   DRAW [BY] x,y   FILL [BY] x,y   PLOT [BY] [k,]x,y
h_move::
	ld	c, #4
	jr	plot1
h_draw::
	ld	c, #5
	jr	plot1
h_fill::
	ld	c, #133
	jr	plot1
h_plot::
	ld	c, #69
	cp	#TBY
	jr	z, plot1
	call	EXPRI
	exx
	push	hl
	call	cexpri
	exx
	ld	a, (iy)
	cp	#0x2C
	jr	z, plot3
	pop	de			; PLOT x,y
	ld	c, #69
	jr	plot4
plot3:	pop	bc			; PLOT k,x,y: C = k
	push	bc
	push	hl
	call	cexpri
	exx
	pop	de
	pop	bc
	jr	plot4
plot1:	cp	#TBY
	jr	nz, plot2
	inc	iy
	res	2, c			; BY: relative
plot2:	push	bc
	call	EXPRI
	exx
	push	hl
	call	cexpri
	exx
	pop	de
	pop	bc
plot4:	call	plot
	jp	xeqgo

;LINE x1,y1,x2,y2
h_line::
	call	EXPRI
	exx
	push	hl
	call	cexpri
	exx
	pop	de
	ld	c, #4
	call	plot
	call	cexpr2
	ld	c, #5
	jr	plot4

;CIRCLE [FILL] x,y,r
h_circle::
	ld	c, #145
	call	fillopt
	push	bc
	call	EXPRI
	exx
	push	hl
	call	cexpri
	exx
	pop	de
	ld	c, #4
	call	plot
	call	cexpri
	exx
	ex	de, hl
	ld	hl, #0
	pop	bc
	jr	plot4

;ELLIPSE [FILL] x,y,a,b
h_ellips::
	ld	c, #193
	call	fillopt
	push	bc
	call	EXPRI
	exx
	push	hl
	call	cexpri
	exx
	pop	de
	ld	c, #4
	call	plot
	call	cexpr2			; DE = a, HL = b
	push	hl
	push	de
	ld	hl, #0
	ld	c, #0			; relative move by (a,0)
	call	plot
	pop	de
	ld	hl, #0
	or	a
	sbc	hl, de
	ex	de, hl			; DE = -a
	pop	hl			; HL = b
	pop	bc
	jr	plot4

;RECTANGLE [FILL] x,y,w[,h]   (... TO is not available)
h_rectan::
	ld	c, #1
	call	fillopt
	push	bc
	call	EXPRI
	exx
	push	hl
	call	cexpri
	exx
	pop	de
	ld	c, #4
	call	plot
	call	cexpri			; w
	exx
	push	hl
	ld	a, (iy)
	cp	#0x2C
	jr	nz, 1$
	call	cexpri			; h
	exx
1$:	pop	de			; DE = w, HL = h (= w if not given)
	ld	a, (iy)
	cp	#TTO
	jp	z, sorry
	pop	bc
	bit	3, c			; FILL: one relative rectangle fill
	jr	z, 2$
	ld	c, #97
	jp	plot4
2$:	push	hl			; outline: four relative lines
	push	de
	ld	hl, #0
	ld	c, #1
	call	plot			; (w,0)
	pop	de
	pop	hl
	push	hl
	push	de
	ld	de, #0
	ld	c, #1
	call	plot			; (0,h)
	pop	de
	ld	hl, #0
	or	a
	sbc	hl, de
	ex	de, hl
	ld	hl, #0
	ld	c, #1
	call	plot			; (-w,0)
	pop	de
	ld	hl, #0
	or	a
	sbc	hl, de
	ld	de, #0
	ld	c, #1
	jp	plot4			; (0,-h)

; "FILL" after CIRCLE/ELLIPSE/RECTANGLE: C + 8 (outline -> filled). A = next character.
fillopt:
	cp	#TFILL
	ret	nz
	inc	iy
	ld	a, c
	add	a, #8
	ld	c, a
	ret

;WAIT [n] - wait n centiseconds (Escape stops it)
h_wait::
	call	TERMQ
	ld	hl, #0
	jr	z, 1$
	call	EXPRI
	exx
1$:	ld	a, h
	or	l
	jr	z, 3$
	bit	7, h
	jr	nz, 3$
2$:	push	hl
	call	pause
	call	trapkey
	pop	hl
	ld	a, (FLAGS)
	or	a
	jp	m, ltrap
	dec	hl
	ld	a, h
	or	l
	jr	nz, 2$
3$:	jp	xeqgo

;OFF / ON - hide / show the cursor while a program waits for a key
h_csroff::
	ld	a, #1
	ld	(CURSOFF), a
	jp	xeqgo
h_csron::
	xor	a
	ld	(CURSOFF), a
	jp	xeqgo

;SOUND c,a,p,d
h_sound::
	call	EXPRI
	exx
	ld	a, l
	ld	(SND), a		; channel
	call	cexpri
	exx
	ld	(SND+1), hl		; amplitude / envelope
	call	cexpri
	exx
	ld	a, l
	ld	(SND+3), a		; pitch
	call	cexpri
	exx
	ld	(SND+4), hl		; duration (twentieths)
	call	sound
	ld	a, (FLAGS)
	or	a
	jp	m, ltrap
	jp	xeqgo

;ENVELOPE n,t,pi1,pi2,pi3,pn1,pn2,pn3,aa,ad,as,ar,ala,ald - the pitch part of envelopes 1-4
h_envel::
	call	EXPRI
	exx
	ld	a, l
	dec	a
	cp	#4
	ld	hl, #0			; envelopes 5-16: read and forget
	jr	nc, 1$
	ld	l, a
	add	a, a
	add	a, a
	add	a, a
	sub	l			; 7 * (n-1)
	ld	l, a
	ld	de, #ENVS
	add	hl, de
1$:	ld	b, #13
2$:	push	bc
	push	hl
	call	cexpri
	exx
	ld	a, l
	pop	hl
	pop	bc
	push	af
	ld	a, b
	cp	#7			; the first 7 of the 13 are kept
	jr	c, 3$
	ld	a, h
	or	l
	jr	z, 3$
	pop	af
	ld	(hl), a
	inc	hl
	jr	4$
3$:	pop	af
4$:	djnz	2$
	jp	xeqgo

;---------------------------------------------------------------- functions

;POINT(x,y): 1 if the pixel is set, 0 if not, -1 outside the window
h_point::
	call	EXPRI
	exx
	push	hl
	call	cexpri
	exx
	pop	de
	call	BRAKET
	call	devxy
	call	gpix
	ld	l, #0xFF
	jr	nc, 1$
	and	(hl)
	ld	l, #0
	jr	z, 1$
	inc	l
1$:	ld	a, l
	ld	h, #0
	inc	a
	jr	nz, 2$
	dec	h
2$:	jp	retint

;MODE (function) - 0 or 1
h_modefn::
	ld	a, (GMODE)
	ld	l, a
	jp	retu8

;WIDTH (function)
h_widfn::
	ld	a, (WIDTH)
	ld	l, a
	jp	retu8

;ADVAL(n): -1 = keys waiting, -5 to -8 = free places in a sound queue (always 15), else 0
h_adval::
	call	ITEMI
	exx
	ld	a, h
	inc	a
	ld	hl, #0
	jp	nz, retu8
	ld	a, l
	cp	#0xFF
	jr	nz, 1$
	ld	a, (KEYFLG)
	ld	l, a
	jp	retu8
1$:	add	a, #8			; -8..-5 -> 0..3
	cp	#4
	jp	nc, retu8
	ld	l, #15
	jp	retu8

;---------------------------------------------------------------- VDU

; Parameter bytes taken by each VDU code 0-31
vducnt:	.db	0,1,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,1,2,5,0,0,1,9, 8,5,0,0,4,4,0,2

; Called by OSWRCH with the character in A. Carry set if it was taken here (a VDU code or one of
; its parameters), carry clear for the console. Destroys B,C,D,E,H,L.
vdu::	ld	c, a
	ld	a, (VDUN)
	or	a
	jr	z, 3$
	dec	a
	ld	(VDUN), a
	ld	hl, #VDUI
	ld	e, (hl)
	inc	(hl)
	ld	d, #0
	ld	hl, #VDUP
	add	hl, de
	ld	(hl), c
	or	a
	scf
	ret	nz
	ld	a, (VDUC)
	call	vdurun
	scf
	ret
3$:	ld	a, c
	cp	#32
	ret	nc
	ld	e, a
	ld	d, #0
	ld	hl, #vducnt
	add	hl, de
	ld	a, (hl)
	or	a
	jr	z, 4$
	ld	(VDUN), a
	ld	a, c
	ld	(VDUC), a
	xor	a
	ld	(VDUI), a
	scf
	ret
4$:	ld	a, c
	cp	#16
	jr	nz, 5$
	call	clg
	scf
	ret
5$:	or	a
	ld	a, c
	ret

; Run VDU code A with its parameters in VDUP
vdurun:	ld	hl, #VDUP
	cp	#18
	jr	nz, 1$
	ld	a, (hl)			; GCOL a,c
	inc	hl
	ld	c, (hl)
	jp	gcol
1$:	cp	#22
	jr	nz, 2$
	ld	a, (hl)			; MODE n
	jp	mode
2$:	cp	#25
	jr	nz, 3$
	ld	c, (hl)			; PLOT k,x;y;
	ld	de, (VDUP+1)
	ld	hl, (VDUP+3)
	jp	plot
3$:	cp	#29
	jr	nz, 4$
	ld	hl, (VDUP)		; ORIGIN x;y;
	ld	(ORGX), hl
	ld	hl, (VDUP+2)
	ld	(ORGY), hl
	ret
4$:	cp	#31
	jr	nz, 5$
	ld	e, (hl)			; TAB(x,y)
	ld	d, #0
	inc	hl
	ld	l, (hl)
	ld	h, d
	jp	PUTCSR
5$:	cp	#23
	ret	nz
	ld	a, (hl)			; VDU 23,1,n: cursor off (0) / on (1)
	dec	a
	ret	nz
	inc	hl
	ld	a, (hl)
	or	a
	ld	a, #0
	jr	nz, 6$
	inc	a
6$:	ld	(CURSOFF), a
	ret

;---------------------------------------------------------------- graphics state

; MODE A: 0 = text only, anything else = text and the graphics window. Both clear the screen
; and reset the graphics colours, the origin and the cursor.
mode::	or	a
	jr	z, 1$
	ld	a, #1
1$:	ld	(GMODE), a
	call	CLRSCN
	ld	hl, #GACT		; GCOL 0,1 and 0,0; origin and points 0
	ld	b, #ORGY+2-GACT+12
2$:	ld	(hl), #0
	inc	hl
	djnz	2$
	ld	a, #1
	ld	(GFG), a
	xor	a
	ld	(CURSOFF), a
	ld	(VDUN), a
	call	clg
	ld	a, (GMODE)
	or	a
	jp	nz, gshow
	jp	ghide

; GCOL A,C: colour C (0 or 1 in two colours) with action A; C >= 128 sets the background
gcol:	bit	7, c
	jr	nz, 1$
	ld	(GACT), a
	ld	a, c
	and	#1
	ld	(GFG), a
	ret
1$:	ld	(GBGACT), a
	ld	a, c
	and	#1
	ld	(GBG), a
	ret

; CLG: the window in the background colour
clg::	ld	a, (GBG)
	neg				; 0 or FF
	ld	hl, #GBUF
	ld	b, #64
1$:	ld	(hl), a
	inc	hl
	djnz	1$
	jp	gupd

; Show the window: CGRAM 0-7 get the picture, and the 8 cells in the middle of the screen show it
gshow::	ld	a, #1
	ld	(GSHOW), a
	call	gupd
	jr	gcells

; Hide it: CGRAM 0-3 get the accented capitals back, and the 8 cells their text
ghide::	ld	a, (GSHOW)
	or	a
	ret	z
	xor	a
	ld	(GSHOW), a
	call	accents
gcells:	ld	e, #28
1$:	ld	hl, #SCR
	ld	d, #0
	add	hl, de
	ld	a, (hl)
	call	putcell
	inc	e
	ld	a, e
	cp	#32
	jr	nz, 2$
	ld	e, #48
2$:	cp	#52
	jr	nz, 1$
	ret

; Copy the picture to CGRAM, if it is on the screen. Interrupts stay off for the 64 bytes: the
; firmware's interrupt routine moves the LCD address to its cursor.
gupd:	ld	a, (GSHOW)
	or	a
	ret	z
	ld	(OUTDIRTY), a		; a picture is output: it stays until a key
	ld	hl, #GBUF
	ld	b, #64
	jp	cgload

;---------------------------------------------------------------- PLOT

; Device coordinates of user point DE,HL (ORIGIN added)
devxy:	push	hl
	ld	hl, (ORGX)
	add	hl, de
	ex	de, hl
	ld	hl, (ORGY)
	pop	bc
	add	hl, bc
	ret

; PLOT C,DE,HL (BBCZ80's PLOT codes: bits 0-1 colour, bit 2 absolute, bits 3-7 the shape)
plot::	ld	a, c
	ld	(PLK), a
	bit	2, c
	jr	z, 1$
	call	devxy
	jr	2$
1$:	push	hl			; relative to the last point
	ld	hl, (PTS)
	add	hl, de
	ex	de, hl
	ld	hl, (PTS+2)
	pop	bc
	add	hl, bc
2$:	push	hl			; the last three points: newest first
	push	de
	ld	hl, #PTS+7
	ld	de, #PTS+11
	ld	bc, #8
	lddr
	pop	de
	pop	hl
	ld	(PTS), de
	ld	(PTS+2), hl
	ld	a, (PLK)
	and	#3
	ret	z			; a move
	ld	hl, #GACT
	dec	a
	jr	z, 3$
	ld	hl, #GBGACT
	dec	a
	jr	nz, 3$
	ld	a, #4			; 2: invert
	ld	(OPACT), a
	jr	4$
3$:	ld	a, (hl)
	ld	(OPACT), a
	inc	hl
	ld	a, (hl)
	ld	(OPCOL), a
4$:	ld	a, (PLK)
	and	#0xF8
	cp	#64
	jp	c, pline
	jr	z, ppoint
	ld	hl, #in_tri
	cp	#80
	jr	z, pfill
	ld	hl, #in_rect
	cp	#96
	jr	z, pfill
	cp	#128
	jp	z, flood
	cp	#136
	jp	z, flood
	cp	#144
	jr	z, pcirc
	cp	#152
	jr	z, pcirc
	cp	#192
	jr	z, pell
	cp	#200
	jr	z, pell
	ret

ppoint:	ld	de, (PTS)
	ld	hl, (PTS+2)
	call	setpix
	jp	gupd

pfill:	xor	a
	jp	pscan

pcirc:	ld	hl, (PTS+4)		; centre = previous point, r^2 = distance^2 to the new one
	ld	(LX), hl
	ld	hl, (PTS+6)
	ld	(LY), hl
	ld	de, (PTS)
	ld	hl, (PTS+2)
	call	cdist
	push	hl			; r^2 + r: no lone pixels on the axes
	call	isqrt
	pop	hl
	ld	e, a
	ld	d, #0
	add	hl, de
	ld	(DX), hl
	ld	hl, #in_circ
	jr	pshape

pell:	ld	hl, (PTS+8)		; centre = two points back, a from the previous, b from the new
	ld	(LX), hl
	ld	hl, (PTS+10)
	ld	(LY), hl
	ld	hl, (PTS+4)
	ld	de, (LX)
	call	sdiff
	push	af
	call	sq8
	ld	(DX), hl		; a^2
	ld	hl, (PTS+2)
	ld	de, (LY)
	call	sdiff
	push	af
	call	sq8
	ld	(DY), hl		; b^2
	ld	de, (DX)
	call	umul16
	ld	(ERR), hl		; a^2*b^2 ...
	ld	(ERR+2), de
	pop	af			; ... + max(a,b)*min(a,b)^2: no lone pixels on the axes
	call	abs8
	ld	c, a
	pop	af
	call	abs8
	cp	c
	jr	nc, 1$
	ld	b, c
	ld	c, a
	ld	a, b
1$:	push	af
	ld	a, c
	ld	e, c
	call	mul8
	pop	af
	ld	e, a
	ld	d, #0
	call	umul16
	ld	bc, (ERR)
	add	hl, bc
	ld	(ERR), hl
	ld	hl, (ERR+2)
	adc	hl, de
	ld	(ERR+2), hl
	ld	hl, #in_ell

pshape:	ld	a, (PLK)		; bit 3 clear: outline
	cpl
	rrca
	rrca
	rrca
	and	#1
pscan:	ld	(GOUT), a
	ld	(GFN), hl
	call	scan
	jp	gupd

; Line from the previous point to the new one (Bresenham)
pline:	ld	hl, (PTS+4)
	ld	(LX), hl
	ld	hl, (PTS+6)
	ld	(LY), hl
	ld	hl, (PTS)		; dx = |x1-x0|, step
	ld	de, (LX)
	ld	a, #1
	call	absd
	ld	(DX), hl
	ld	(SXS), a
	ld	hl, (PTS+2)		; dy = -|y1-y0|, step
	ld	de, (LY)
	ld	a, #1
	call	absd
	ld	(SYS), a
	ex	de, hl
	ld	hl, #0
	or	a
	sbc	hl, de
	ld	(DY), hl
	ld	de, (DX)
	add	hl, de
	ld	(ERR), hl
1$:	ld	de, (LX)
	ld	hl, (LY)
	call	setpix
	ld	hl, (LX)
	ld	de, (PTS)
	or	a
	sbc	hl, de
	jr	nz, 2$
	ld	hl, (LY)
	ld	de, (PTS+2)
	sbc	hl, de
	jp	z, gupd
2$:	ld	hl, (ERR)
	add	hl, hl			; e2
	push	hl
	ld	de, (DY)
	or	a
	sbc	hl, de
	jp	m, 3$			; e2 < dy
	ld	hl, (ERR)
	add	hl, de
	ld	(ERR), hl
	ld	hl, (LX)
	ld	a, (SXS)
	call	addstep
	ld	(LX), hl
3$:	pop	hl
	ld	de, (DX)
	or	a
	sbc	hl, de
	jr	z, 4$
	jp	p, 1$			; e2 > dx
4$:	ld	hl, (ERR)
	add	hl, de
	ld	(ERR), hl
	ld	hl, (LY)
	ld	a, (SYS)
	call	addstep
	ld	(LY), hl
	jr	1$

; HL += A (1 or -1)
addstep:
	inc	a
	jr	z, 1$
	inc	hl
	ret
1$:	dec	hl
	ret

; HL = |HL-DE|; A = 1 if HL >= DE else -1
absd:	or	a
	sbc	hl, de
	ret	p
	ex	de, hl
	ld	hl, #0
	or	a
	sbc	hl, de
	ld	a, #0xFF
	ret

;---------------------------------------------------------------- shapes

; For each pixel of the window, plot it if GFN says it is inside (GOUT = 1: only if a 4-neighbour is not)
scan:	ld	hl, #0
	ld	(SY), hl
1$:	ld	hl, #0
	ld	(SX), hl
2$:	ld	de, (SX)
	ld	hl, (SY)
	call	inside
	jr	nc, 3$
	ld	a, (GOUT)
	or	a
	jr	z, 4$
	ld	de, (SX)
	dec	de
	ld	hl, (SY)
	call	inside
	jr	nc, 4$
	ld	de, (SX)
	inc	de
	ld	hl, (SY)
	call	inside
	jr	nc, 4$
	ld	de, (SX)
	ld	hl, (SY)
	dec	hl
	call	inside
	jr	nc, 4$
	ld	de, (SX)
	ld	hl, (SY)
	inc	hl
	call	inside
	jr	c, 3$
4$:	ld	de, (SX)
	ld	hl, (SY)
	call	setpix
3$:	ld	hl, #SX
	inc	(hl)
	ld	a, (hl)
	cp	#20
	jr	c, 2$
	ld	hl, #SY
	inc	(hl)
	ld	a, (hl)
	cp	#16
	jr	c, 1$
	ret

inside:	push	hl
	ld	hl, (GFN)
	ex	(sp), hl
	ret

; DE,HL inside the rectangle of the last two points (carry)
in_rect:
	push	hl
	ld	hl, (PTS)
	ld	bc, (PTS+4)
	call	between
	pop	de
	ret	nc
	ld	hl, (PTS+2)
	ld	bc, (PTS+6)
between:			; carry if DE is between HL and BC (signed, inclusive)
	push	hl
	or	a
	sbc	hl, bc
	pop	hl
	jp	m, 1$
	push	hl			; HL >= BC: swap
	ld	h, b
	ld	l, c
	pop	bc
1$:	ex	de, hl			; HL = value, DE = low, BC = high
	push	hl
	or	a
	sbc	hl, de
	pop	hl
	jp	m, 2$
	ld	d, b
	ld	e, c
	ex	de, hl
	or	a
	sbc	hl, de
	jp	m, 2$
	scf
	ret
2$:	or	a
	ret

; DE,HL inside the circle (LX,LY) with r^2 = DX
in_circ:
	call	cdist
	ex	de, hl
	ld	hl, (DX)
	or	a
	sbc	hl, de			; carry if r^2 < d^2
	ccf
	ret

; HL = d^2 from (LX,LY) to DE,HL (each difference limited to +-127)
cdist:	push	de
	ld	de, (LY)
	call	sdiff
	call	sq8
	ex	(sp), hl
	ld	de, (LX)
	call	sdiff
	call	sq8
	pop	de
	add	hl, de
	ret

; DE,HL inside the ellipse centred at (LX,LY): dx^2*b^2 + dy^2*a^2 <= a^2*b^2 (32 bits)
in_ell:	push	de
	ld	de, (LY)
	call	sdiff
	call	sq8
	ld	de, (DX)		; dy^2 * a^2
	call	umul16
	pop	bc			; BC = x
	push	de
	push	hl
	ld	h, b
	ld	l, c
	ld	de, (LX)
	call	sdiff
	call	sq8
	ld	de, (DY)		; dx^2 * b^2
	call	umul16
	pop	bc
	add	hl, bc
	ex	de, hl			; DE = low word of the sum
	pop	bc
	adc	hl, bc			; HL = high word
	jr	c, 2$
	ld	bc, (ERR+2)
	push	hl
	or	a
	sbc	hl, bc
	pop	hl
	jr	c, 1$
	jr	nz, 2$
	ex	de, hl
	ld	bc, (ERR)
	or	a
	sbc	hl, bc
	jr	z, 1$
	ret				; carry if below
1$:	scf
	ret
2$:	or	a
	ret

; DE,HL inside the triangle of the last three points: the three edge functions do not have
; both signs
in_tri:	ld	(LX), de
	ld	(LY), hl
	ld	c, #0
	ld	hl, #PTS
	ld	de, #PTS+4
	call	edgef
	ld	hl, #PTS+4
	ld	de, #PTS+8
	call	edgef
	ld	hl, #PTS+8
	ld	de, #PTS
	call	edgef
	ld	a, c
	cp	#3
	ret

; Sign of the edge function (HL = point a, DE = point b, at (LX,LY)) into C: bit 0 positive, bit 1 negative
edgef:	push	bc
	push	de			; a -> DX,DY  b -> ERR,ERR+2
	ld	de, #DX
	ld	bc, #4
	ldir
	pop	hl
	ld	de, #ERR
	ld	bc, #4
	ldir
	ld	hl, (ERR)		; (xb-xa)*(py-ya)
	ld	de, (DX)
	call	sdiff
	push	af
	ld	hl, (LY)
	ld	de, (DY)
	call	sdiff
	pop	bc
	call	smul8
	push	hl
	ld	hl, (ERR+2)		; (yb-ya)*(px-xa)
	ld	de, (DY)
	call	sdiff
	push	af
	ld	hl, (LX)
	ld	de, (DX)
	call	sdiff
	pop	bc
	call	smul8
	ex	de, hl
	pop	hl
	or	a
	sbc	hl, de
	pop	bc
	ld	a, h
	or	l
	ret	z
	bit	7, h
	jr	z, 1$
	set	1, c
	ret
1$:	set	0, c
	ret

;---------------------------------------------------------------- arithmetic

abs8:	bit	7, a
	ret	z
	neg
	ret

; A = integer square root of HL (HL < 32768): how many odd numbers can be taken away
isqrt:	ld	de, #1
	xor	a
1$:	sbc	hl, de
	ret	c
	inc	a
	inc	de
	inc	de
	jr	1$

; A = HL-DE limited to -127..127
sdiff:	or	a
	sbc	hl, de
	ld	a, h
	or	a
	jr	nz, 1$
	ld	a, l
	cp	#128
	ret	c
	ld	a, #127
	ret
1$:	bit	7, h
	ld	a, #127
	ret	z
	ld	a, h
	inc	a
	jr	nz, 2$
	ld	a, l
	cp	#129
	ret	nc
2$:	ld	a, #0x81
	ret

; HL = A*A (A signed)
sq8:	call	abs8
	ld	e, a
; HL = A*E (unsigned). Destroys A,B,D.
mul8:	ld	d, #0
	ld	hl, #0
	ld	b, #8
1$:	add	hl, hl
	rlca
	jr	nc, 2$
	add	hl, de
2$:	djnz	1$
	ret

; HL = A*B (signed bytes)
smul8:	ld	c, a
	xor	b
	push	af
	ld	a, c
	bit	7, a
	jr	z, 1$
	neg
1$:	ld	e, a
	ld	a, b
	bit	7, a
	jr	z, 2$
	neg
2$:	call	mul8
	pop	af
	ret	p
	ex	de, hl
	ld	hl, #0
	or	a
	sbc	hl, de
	ret

; DEHL = HL*DE (unsigned). Destroys A,B,C.
umul16:	ld	b, h
	ld	c, l
	ld	hl, #0
	ld	a, #16
1$:	add	hl, hl
	rl	e
	rl	d
	jr	nc, 2$
	add	hl, bc
	jr	nc, 2$
	inc	de
2$:	dec	a
	jr	nz, 1$
	ret

;---------------------------------------------------------------- pixels

; Device pixel DE,HL: carry and HL = byte of GBUF, A = bit, if it is in the window (0-19, 0-15)
gpix::	ld	a, d
	or	a
	ret	nz
	ld	a, e
	cp	#20
	ret	nc
	ld	a, h
	or	a
	ret	nz
	ld	a, l
	cp	#16
	ret	nc
	ld	a, #15			; row from the top
	sub	l
	ld	l, a
	ld	a, e			; character column, bit
	ld	b, #0
1$:	cp	#5
	jr	c, 2$
	sub	#5
	inc	b
	jr	1$
2$:	ld	c, #0x10
	or	a
	jr	z, 4$
3$:	srl	c
	dec	a
	jr	nz, 3$
4$:	ld	a, l			; byte = column*8 + row + 24 * (row >= 8)
	cp	#8
	jr	c, 5$
	add	a, #24
5$:	ld	e, a
	ld	a, b
	add	a, a
	add	a, a
	add	a, a
	add	a, e
	ld	e, a
	ld	d, #0
	ld	hl, #GBUF
	add	hl, de
	ld	a, c
	scf
	ret

; Plot device pixel DE,HL with OPACT/OPCOL
setpix:	call	gpix
	ret	nc
	ld	b, a
	ld	c, (hl)
	ld	a, (OPCOL)
	or	a
	ld	a, (OPACT)
	jr	z, 2$
	cp	#2			; colour 1: and = unchanged, eor/invert = flip, set/or = set
	ret	z
	cp	#3
	jr	nc, 4$
	ld	a, c
	or	b
	ld	(hl), a
	ret
2$:	or	a			; colour 0: set/and = clear, invert = flip, or/eor = unchanged
	jr	z, 3$
	cp	#2
	jr	z, 3$
	cp	#4
	ret	nz
4$:	ld	a, c
	xor	b
	ld	(hl), a
	ret
3$:	ld	a, b
	cpl
	and	c
	ld	(hl), a
	ret

;---------------------------------------------------------------- flood fill

; Fill the area of background-coloured pixels around the new point (PLOT 128-135, FILL)
flood:	ld	de, (PTS)
	ld	hl, (PTS+2)
	call	gpix
	jp	nc, gupd
	call	isbg
	jp	nz, gupd
	ld	hl, #FMASK
	ld	b, #40
1$:	ld	(hl), #0
	inc	hl
	djnz	1$
	ld	de, (PTS)
	ld	hl, (PTS+2)
	call	mptr
	or	(hl)
	ld	(hl), a
2$:	xor	a			; grow the area until nothing changes
	ld	(GOUT), a
	ld	hl, #0
	ld	(SY), hl
3$:	ld	hl, #0
	ld	(SX), hl
4$:	ld	de, (SX)
	ld	hl, (SY)
	call	mptr
	and	(hl)
	jr	nz, 5$
	ld	de, (SX)
	ld	hl, (SY)
	call	gpix
	call	isbg
	jr	nz, 5$
	ld	de, (SX)
	dec	de
	ld	hl, (SY)
	call	mtest
	jr	nz, 6$
	ld	de, (SX)
	inc	de
	ld	hl, (SY)
	call	mtest
	jr	nz, 6$
	ld	de, (SX)
	ld	hl, (SY)
	dec	hl
	call	mtest
	jr	nz, 6$
	ld	de, (SX)
	ld	hl, (SY)
	inc	hl
	call	mtest
	jr	z, 5$
6$:	ld	de, (SX)
	ld	hl, (SY)
	call	mptr
	or	(hl)
	ld	(hl), a
	ld	a, #1
	ld	(GOUT), a
5$:	ld	hl, #SX
	inc	(hl)
	ld	a, (hl)
	cp	#20
	jr	c, 4$
	ld	hl, #SY
	inc	(hl)
	ld	a, (hl)
	cp	#16
	jr	c, 3$
	ld	a, (GOUT)
	or	a
	jp	nz, 2$
	ld	hl, #in_mask		; plot the area
	xor	a
	jp	pscan

in_mask:
	call	mtest
	ret	z
	scf
	ret

; Z if the pixel at HL (bit A) has the background colour
isbg:	and	(hl)
	jr	z, 1$
	ld	a, #1
1$:	ld	b, a
	ld	a, (GBG)
	xor	b
	ret

; NZ if pixel DE,HL is in the window and marked in FMASK
mtest:	call	mptr
	jr	nc, 1$
	and	(hl)
	ret
1$:	xor	a
	ret

; Pixel DE,HL: carry and HL = byte of FMASK, A = bit, if it is in the window
mptr:	ld	a, d
	or	a
	ret	nz
	ld	a, e
	cp	#20
	ret	nc
	ld	a, h
	or	a
	ret	nz
	ld	a, l
	cp	#16
	ret	nc
	add	hl, hl			; y*20 + x
	add	hl, hl
	ld	b, h
	ld	c, l
	add	hl, hl
	add	hl, hl
	add	hl, bc
	add	hl, de
	ld	a, l
	and	#7
	ld	b, a
	srl	h
	rr	l
	srl	h
	rr	l
	srl	h
	rr	l
	ld	de, #FMASK
	add	hl, de
	ld	a, #1
	inc	b
	jr	2$
1$:	rlca
2$:	djnz	1$
	scf
	ret
