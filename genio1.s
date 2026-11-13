; genio1.s - page 1 of the VTech Genio 2000 OS layer for the BBC BASIC (Z80) v5 interpreter.
; Linked with the interpreter: cartridge header, start-up, the entry points the interpreter calls
; (most of them are stubs that run the code of page 2), the per-statement Escape test, TIME,
; and the errors, whose inline messages must sit in the page that EXTERR reads.
; Copyright (C) 2026 Santiago Crespo
; SPDX-License-Identifier: 0BSD

	.include "shared.inc"

	.globl	OSINIT, OSRDCH, OSWRCH, OSLINE, OSSAVE, OSLOAD, OSOPEN, OSSHUT
	.globl	OSBGET, OSBPUT, OSSTAT, GETEXT, GETPTR, PUTPTR, PROMPT, RESET
	.globl	LTRAP, OSCLI, TRAP, OSKEY, OSCALL
	.globl	CLRSCN, PUTCSR, GETCSR, PUTIME, GETIME, BYE, ASSEM
	.globl	SOUND, ENVEL, WAIT, MODE, CLG, GCOL, MOVE, DRAW, PLOT, FILL, LINE, CIRCLE, ELLIPS
	.globl	RECTAN, ORIGIN, POINT, CSRON, CSROFF, MODEFN, WIDFN, ADVAL
	.globl	COLOUR, TINT, TINTFN, MOUSE, SYS, PUTIMS, GETIMS, SORRY
	.globl	HIMEM, LOMEM, PBCDL
	.globl	START, ESCAPE, EXTERR, USER, KEYWDS, kwname, kscan, offpoll

	.area	CODE
	.db	0x55, 0xAA, 0x59, 0x45	; autostart signature
	di
	ld	sp, #0xDFF0
	ld	hl, #ramsrc
	ld	de, #RAMCODE
	ld	bc, #ramsrc_end-ramsrc
	ldir
	ld	hl, #XRAM		; the layer's variables
	ld	de, #XRAM+1
	ld	bc, #VARS_END-XRAM-1
	ld	(hl), #0
	ldir
	ld	hl, #lcdini		; HD44780: 8-bit, display on, about 2.5 ms per command
	ld	b, #lcdini_end-lcdini
1$:	ld	a, (hl)
	out	(0x0A), a
	ld	de, #600
2$:	dec	de
	ld	a, d
	or	e
	jr	nz, 2$
	inc	hl
	djnz	1$
	ld	a, #1
	ld	(CAPS), a		; caps lock on: BASIC keywords are upper case
	ld	hl, #0xFFFF		; the editor starts at the end of the (empty) program
	ld	(BOUND), hl
	call	p2init
	ld	hl, (0x0039)		; enable the firmware ISR only if 0038 is JP 0119 and the hook is 0033
	ld	de, #0x0119
	or	a
	sbc	hl, de
	jr	nz, 3$
	ld	hl, (FW_HOOK)
	ld	de, #0x0033
	or	a
	sbc	hl, de
	jr	nz, 3$
	ld	a, #0xFF
	ld	(FW_KEYCODE), a
	ld	a, #0xD0
	ld	(FW_KEYST), a
	ld	hl, #FW_DIRTY
	ld	b, #8
4$:	ld	(hl), #0
	inc	hl
	djnz	4$
	ld	hl, #R_HOOK
	ld	(FW_HOOK), hl
	im	1
	ei
3$:	jp	START			; cold start of the interpreter

lcdini:	.db	0x38, 0x38, 0x38, 0x38, 0x01, 0x02, 0x0C, 0x06
lcdini_end:

; Entry point that runs slot n of the page-2 jump table
.macro	FAR	name, n
name:	push	hl
	ld	hl, #0x8000+3*n
	jp	R_FAR
.endm

	FAR	p2init, S_INIT
	FAR	OSRDCH, S_OSRDCH
	FAR	OSWRCH, S_OSWRCH
	FAR	OSLINE, S_OSLINE
	FAR	OSKEY, S_OSKEY
	FAR	CLRSCN, S_CLRSCN
	FAR	PUTCSR, S_PUTCSR
	FAR	GETCSR, S_GETCSR
	FAR	p2prompt, S_PROMPT
	FAR	trapkey, S_TRAPKEY
; The statements and functions of HOOK.Z80 that this machine can do, and the inline assembler
	FAR	ASSEM, S_ASSEM
	FAR	SOUND, S_SOUND
	FAR	ENVEL, S_ENVEL
	FAR	WAIT, S_WAIT
	FAR	MODE, S_MODE
	FAR	CLG, S_CLG
	FAR	GCOL, S_GCOL
	FAR	MOVE, S_MOVE
	FAR	DRAW, S_DRAW
	FAR	PLOT, S_PLOT
	FAR	FILL, S_FILL
	FAR	LINE, S_LINE
	FAR	CIRCLE, S_CIRCLE
	FAR	ELLIPS, S_ELLIPS
	FAR	RECTAN, S_RECTAN
	FAR	ORIGIN, S_ORIGIN
	FAR	POINT, S_POINT
	FAR	CSRON, S_CSRON
	FAR	CSROFF, S_CSROFF
	FAR	MODEFN, S_MODEFN
	FAR	WIDFN, S_WIDFN
	FAR	ADVAL, S_ADVAL

;TRAP - every 20th call sample the keyboard; then as LTRAP. Destroys A,H,L,F.
;LTRAP - abort with Escape if the flag is set. Destroys A,F.
TRAP:	ld	hl, #TRPCNT
	dec	(hl)
	jr	nz, LTRAP
	ld	(hl), #20
	call	trapkey
LTRAP:	ld	a, (FLAGS)
	or	a
	ret	p
	ld	hl, #FLAGS
	res	7, (hl)
	jp	ESCAPE

;GETIME - DEHL = TIME (cs). PUTIME - set it from DEHL. Destroy A,D,E,H,L,F.
GETIME:	ld	a, i
	di
	ld	hl, (TICKS+2)
	ex	de, hl
	ld	hl, (TICKS)
	ret	po
	ei
	ret

PUTIME:	ld	a, i
	di
	ld	(TICKS), hl
	ex	de, hl
	ld	(TICKS+2), hl
	ld	hl, #0
	ld	(TFRAC), hl
	ret	po
	ei
	ret

; PROMPT - the first time, also print the free memory at the right of the banner's first row.
PROMPT:	push	af
	ld	a, (MEMSHOWN)
	or	a
	jr	nz, 2$
	inc	a
	ld	(MEMSHOWN), a
	ld	hl, (CX)		; CX and CY
	push	hl
	ld	hl, (HIMEM)
	ld	de, (LOMEM)
	or	a
	sbc	hl, de
	ld	de, #16			; columns 16-19: with 8 KiB of RAM it has four digits
	ld	(CX), de		; and row 0
	call	PBCDL
	pop	hl
	ld	(CX), hl
2$:	pop	af
	jp	p2prompt

;OSINIT - DE = HIMEM, HL = PAGE, Z set (no auto-run).
OSINIT:	ld	de, #XRAM
	ld	hl, #USER
	xor	a
	ret

;RESET - called after an untrapped error, just before its message: capture the message for the editor.
RESET:	ld	a, #2
	ld	(CAPT), a
	xor	a
	ld	(ERRLEN), a
	ret
OSSHUT:
OSCALL:	ret

;OSCLI - no star commands exist: an empty command or a comment (*|) is accepted, the rest is an error.
OSCLI:	ld	a, (hl)
	inc	hl
	cp	#0x20
	jr	z, OSCLI
	cp	#0x2A
	jr	z, OSCLI
	cp	#CR
	ret	z
	cp	#0x7C
	ret	z
	ld	a, #254
	call	EXTERR
	.ascii	"Bad command"
	.db	0

;BYE - QUIT: back to the firmware menu (RST 30h)
BYE:	di
	ld	a, #0xC0		; the firmware's "no key" state, as on entry
	ld	(FW_KEYST), a
	jp	0x0030

; What this machine cannot do, as in HOOK.Z80 (a fatal error)
COLOUR:
TINT:
TINTFN:
MOUSE:
SYS:
PUTIMS:
GETIMS:
SORRY:	xor	a
	call	EXTERR
	.ascii	"Sorry"
	.db	0

; No filing system: OPENIN/OPENOUT return 0, CLOSE does nothing, the rest is an error
OSOPEN:	xor	a
	ret

OSSAVE:
OSLOAD:
OSBGET:
OSBPUT:
OSSTAT:
GETEXT:
GETPTR:
PUTPTR:	ld	a, #214
	call	EXTERR
	.ascii	"No filing system"
	.db	0

;---------------------------------------------------------------- keyboard (called by page 2)

; Scan the keyboard (matrix 1, then the activity panel). Returns D = first non-modifier scancode (row*8+col) or FF, E bit 0 = SHIFT, bit 1 = ALT.
; Destroys A,B,C,D,E,H,L,F.
kscan:	ld	bc, #0x0100		; B = column mask, C = column
	ld	de, #0xFF00
1$:	ld	a, b
	out	(0x10), a
	nop
	in	a, (0x10)
	cpl
	ld	l, a
	ld	a, c
	cp	#1
	jr	nz, 2$
	bit	5, l
	res	5, l
	jr	z, 3$
	set	1, e
	jr	3$
2$:	cp	#6
	jr	nz, 3$
	bit	6, l
	res	6, l
	jr	z, 3$
	set	0, e
3$:	ld	a, d
	inc	a
	jr	nz, 5$			; already found one
	ld	a, l
	or	a
	jr	z, 6$
	ld	d, c
4$:	rrca
	jr	c, 5$
	ld	h, a
	ld	a, d
	add	a, #8
	ld	d, a
	ld	a, h
	jr	4$
6$:	in	a, (0x11)		; activity panel: rows 8-12 on port 0x11 (not OFF, column 7 row 9)
	cpl
	and	#0x1F
	ld	h, a
	ld	a, c
	cp	#7
	ld	a, h
	jr	nz, 7$
	and	#0x1C
7$:	or	a
	jr	z, 5$
	ld	h, a
	ld	a, c			; D = 64 + column*5 + row
	add	a, a
	add	a, a
	add	a, c
	add	a, #64
	ld	d, a
8$:	srl	h
	jr	c, 5$
	inc	d
	jr	8$
5$:	sla	b
	inc	c
	bit	3, c
	jr	z, 1$
	xor	a
	out	(0x10), a
	ret

; OFF key: column mask 0x80, port 0x11 bit 1 low (the routine verified on the unit). Z = pressed.
offscan:
	ld	a, #0x80
	out	(0x10), a
	nop
	in	a, (0x11)
	and	#0x02
	push	af
	xor	a
	out	(0x10), a
	pop	af
	ret

; Power off when OFF is pressed (held ~20 ms against bounce); ignored until seen released once.
offpoll:
	call	offscan
	jr	z, 1$
	ld	a, #1
	ld	(OFFARM), a
	ret
1$:	ld	a, (OFFARM)
	or	a
	ret	z
	ld	bc, #0x0380		; 896 x 134 T = 19.6 ms
2$:	call	offscan
	ret	nz
	dec	bc
	ld	a, b
	or	c
	jr	nz, 2$
offnow:	di
	ld	a, #0x01
	out	(0x12), a
3$:	halt				; the firmware's own power-off sequence
	jr	3$

;kwname - copy the name of keyword token A to DE (as LIST shows it), then a space unless it
; ends in "(". DE ends after it. Used by the activity keys of the editor in page 2.
kwname:	ld	hl, #KEYWDS
	ld	c, a
	or	a
	jr	nz, 1$
	ld	hl, #kwlist		; 0: the command LIST
	jr	3$
1$:	ld	a, (hl)			; a token, then its name
	inc	hl
	cp	c
	jr	z, 3$
2$:	ld	a, (hl)
	cp	#0x20
	jr	c, 1$
	cp	#0x80
	jr	nc, 1$
	inc	hl
	jr	2$
3$:	ld	a, (hl)
	cp	#0x20
	jr	c, 4$
	cp	#0x80
	jr	nc, 4$
	ld	(de), a
	inc	hl
	inc	de
	jr	3$
4$:	dec	de
	ld	a, (de)
	inc	de
	cp	#0x28
	ret	z
	ld	a, #0x20
	ld	(de), a
	inc	de
	ret

kwlist:	.ascii	"LIST"
	.db	0

;---------------------------------------------------------------- code copied to RAMCODE
; Page switching must run from RAM: the code of the page being left disappears with the OUT.
ramsrc:
; HL = page-2 address to call, the caller's HL on the stack. All other registers pass both ways.
rfar:	ld	(RAMCODE+rfar_t-ramsrc+1), hl
	pop	hl
	push	af
	ld	a, #PAGE2
	out	(0x03), a
	pop	af
rfar_t:	call	0
	push	af
	ld	a, #PAGE1
	out	(0x03), a
	pop	af
	ret
; The same from page 2 to a page-1 routine.
rcall1:	ld	(RAMCODE+rcall1_t-ramsrc+1), hl
	pop	hl
	push	af
	ld	a, #PAGE1
	out	(0x03), a
	pop	af
rcall1_t:	call	0
	push	af
	ld	a, #PAGE2
	out	(0x03), a
	pop	af
	ret
; From page 2, jump to the page-1 address in HL for good (errors).
rjp1:	ld	a, #PAGE1
	out	(0x03), a
	jp	(hl)
; Interrupt hook, called by the firmware ISR (registers already saved). It lives in RAM because
; either cartridge page may be mapped when the interrupt comes.
hook:	ld	hl, (TFRAC)
	ld	de, #9082		; 65536 * (100 / 46.76 - 2): 2.1386 cs per interrupt
	add	hl, de
	ld	(TFRAC), hl
	ld	hl, (TICKS)
	ld	de, #2
	adc	hl, de
	ld	(TICKS), hl
	ret	nc
	ld	hl, (TICKS+2)
	inc	hl
	ld	(TICKS+2), hl
	ret
ramsrc_end:

R_FAR == RAMCODE+rfar-ramsrc
R_CALL1 == RAMCODE+rcall1-ramsrc
R_JP1 == RAMCODE+rjp1-ramsrc
R_HOOK == RAMCODE+hook-ramsrc

	.ifgt	VARS_END-RAMCODE		; the variables must end before the RAM code
	.error	1
	.endif
	.ifgt	RAMCODE+ramsrc_end-ramsrc-0xDB00	; and the RAM code below the firmware's DB00
	.error	1
	.endif
