; fs.s - page 2: LOAD, SAVE and CHAIN on the Super Memoria (OSLOAD, OSSAVE), the star commands *DIR, *ERA
; and *FORMAT (OSCLI), and one data file at a time (OSOPEN, OSBGET, ...), kept whole in RAM at FBUF: OPENIN
; reads it with one swap of cartridges and CLOSE# writes it with another. The work with the cartridge is done
; by smfs.s, copied to RAM by fscopy; FBUF is where part of it runs, so it is copied only with no file open.
; Copyright (C) 2026 Santiago Crespo
; SPDX-License-Identifier: 0BSD

	.include "shared.inc"

	.area	P2

;OSSAVE - save the program: HL = its name (ending in CR), DE = its start, BC = its length
fs_save::
	push	bc
	push	de
	xor	a
	call	fsname
	pop	hl
	pop	bc
	ld	(P_BUF), hl
	ld	(P_LEN), bc
	call	crcbuf
	ld	(P_CRC), de
	ld	a, #OP_SAVE
	jp	fsrun

;OSLOAD - load a program: HL = its name, DE = where, BC = the room. Carry: loaded.
fs_load::
	push	bc
	push	de
	xor	a
	call	fsname
	pop	hl
	pop	bc
	ld	(P_BUF), hl
	ld	(P_CAP), bc
	ld	a, #OP_LOAD
	call	fsrun
	or	a
	jr	nz, 1$
	call	crcbuf
	ld	hl, (P_CRC)
	or	a
	sbc	hl, de
	scf
	ret	z
	call	clean			; a wrong CRC: the program stays as read
	ld	hl, #m_crc
	jp	fserror
1$:	ld	hl, (PAGE)		; a broken chain: part of it was overwritten, so no program
	ld	(hl), #0
	call	clean
	ld	hl, (P_MSG)
	jp	fserror

; As the interpreter's CLEAN: the end mark after the program, and no variables
clean:	call	GETTOP
	dec	hl
	ld	(hl), #0xFF
	dec	hl
	ld	(hl), #0xFF
	jp	CLEAR

; DE = CRC of the P_LEN bytes at P_BUF
crcbuf:	ld	hl, (P_BUF)
	ld	bc, (P_LEN)
	ld	de, #0xFFFF
1$:	ld	a, b
	or	c
	ret	z
	ld	a, (hl)
	call	crcup
	inc	hl
	dec	bc
	jr	1$

;OSCLI - the star commands *DIR (*CAT, *.), *ERA name (*DELETE name) and *FORMAT, in upper or lower case.
; HL = the command.
fs_cli::
1$:	ld	a, (hl)
	cp	#0x20
	jr	z, 2$
	cp	#0x2A
	jr	nz, 3$
2$:	inc	hl
	jr	1$
3$:	cp	#CR
	ret	z
	cp	#0x7C			; *| is a comment
	ret	z
	ld	de, #clitab
4$:	push	hl
5$:	ld	a, (de)
	inc	de
	cp	#0x20
	jr	c, 7$			; the word matched: A = its operation
	ld	c, a
	ld	a, (hl)
	inc	hl
	cp	#0x61
	jr	c, 51$
	sub	#0x20
51$:	cp	c
	jr	z, 5$
6$:	ld	a, (de)			; not this word
	inc	de
	cp	#0x20
	jr	nc, 6$
	pop	hl
	ld	a, (de)
	or	a
	jr	nz, 4$
8$:	ld	hl, #badcmd
	jp	R_JP1
7$:	pop	bc
	ld	c, a
	ld	a, (hl)			; a letter may not follow
	and	#0xDF
	sub	#0x41
	cp	#26
	jr	c, 8$
	ld	a, c
	cp	#OP_ERASE
	push	af
	call	z, fsname		; (A is not 0: .BAS)
	pop	af
	call	nz, fsprep
fsrun:	ld	(P_OP), a
	ld	a, i
	push	af
	di
	call	SMENTRY
	pop	af
	jp	po, 1$
	ei
1$:	call	redraw			; the screen as it was
	xor	a
	ld	(VIEWOK), a
	ld	a, (P_RES)
	cp	#R_ESC
	jr	z, fsesc
	cp	#R_ERR
	ret	nz
	ld	hl, (P_MSG)
; Error HL: its text (in RAM, so that page 1 can report it), its number in the byte before
fserror:
	dec	hl
	ld	a, (hl)
	inc	hl
	ld	(FSERR), a
	push	hl
	ld	hl, #fserr
	jp	R_JP1
fsesc:	ld	hl, #ESCAPE
	jp	R_JP1

clitab:	.ascii	"DIR"
	.db	OP_DIR
	.ascii	"CAT"
	.db	OP_DIR
	.ascii	"."
	.db	OP_DIR
	.ascii	"ERA"
	.db	OP_ERASE
	.ascii	"DELETE"
	.db	OP_ERASE
	.ascii	"FORMAT"
	.db	OP_FORMAT, 0

; The name at HL into P_NAME, zero-padded, as an SMFS entry with nothing else: spaces and a quote around
; it dropped, in upper case, ".BAS" (A = 0, for OP_ERASE too) or ".DAT" (A = 1) added if it has no extension.
; Then the SMFS code to RAM. "Bad name" if it is empty, too long, or has a character other than
; A-Z 0-9 space . - _
fsname:	ld	(FEXT), a
	ld	a, (FCH)		; with a file open, P_NAME is its name
	or	a
	jp	nz, fsopen
	push	hl
	ld	hl, #P_NAME
	ld	b, #32
1$:	ld	(hl), #0
	inc	hl
	djnz	1$
	pop	hl
2$:	ld	a, (hl)
	inc	hl
	cp	#0x20
	jr	z, 2$
	cp	#0x22
	jr	z, 3$
	dec	hl
3$:	ld	de, #P_NAME
	ld	bc, #17*256		; B: room for 16; C: the dots seen
4$:	ld	a, (hl)
	inc	hl
	cp	#CR
	jr	z, 7$
	cp	#0x22
	jr	z, 7$
	cp	#0x61
	jr	c, 5$
	cp	#0x7B
	jr	nc, 5$
	sub	#0x20
5$:	cp	#0x2E
	jr	nz, 51$
	inc	c
	jr	6$
51$:	cp	#0x20
	jr	z, 6$
	cp	#0x2D
	jr	z, 6$
	cp	#0x5F
	jr	z, 6$
	cp	#0x30
	jr	c, 9$
	cp	#0x3A
	jr	c, 6$
	cp	#0x41
	jr	c, 9$
	cp	#0x5B
	jr	nc, 9$
6$:	ld	(de), a
	inc	de
	djnz	4$
	jr	9$
7$:	ld	a, b			; trailing spaces
	cp	#17
	jr	z, 9$			; empty
	dec	de
	ld	a, (de)
	cp	#0x20
	jr	nz, 71$
	xor	a
	ld	(de), a
	inc	b
	jr	7$
71$:	inc	de
	ld	a, c
	or	a
	jr	nz, fsprep
	ld	a, b			; no extension: ".BAS" or ".DAT", if it fits
	cp	#5
	jr	c, 9$
	ld	hl, #dotbas
	ld	a, (FEXT)
	dec	a
	jr	nz, 8$
	ld	hl, #dotdat
8$:	ld	bc, #4
	ldir
	jr	fsprep
9$:	ld	hl, #badname
	jp	R_JP1

; The SMFS code to RAM, if no file is open (it would overwrite the file's buffer). Keeps A.
fsprep:	ld	hl, #FCH
	inc	(hl)
	dec	(hl)
	jp	z, fscopy
fsopen:	ld	hl, #openerr
	jp	R_JP1

dotbas:	.ascii	".BAS"
dotdat:	.ascii	".DAT"

;---------------------------------------------------------------- the data file, channel 1

;OSOPEN - A = FF OPENOUT, 0 OPENIN, 1 OPENUP; HL = the name. A = the channel (1).
fs_open::
	inc	a
	push	af
	ld	a, #1
	call	fsname			; (it ends with fscopy's LDIR: BC = 0 for gap)
	pop	af
	or	a
	ld	h, a			; (HL = 0: OPENOUT's length)
	ld	l, a
	jr	nz, 1$
	ld	a, #2
	jr	2$
1$:	push	af			; OPENIN, OPENUP: the whole file into the gap below the stack, then FBUF
	call	gap
	ld	(P_CAP), hl
	ld	a, #OP_LOAD
	call	fsrun
	or	a
	ld	hl, (P_MSG)
	jp	nz, fserror
	call	crcbuf
	ld	hl, (P_CRC)
	or	a
	sbc	hl, de
	ld	hl, #m_crc
	jp	nz, fserror
	ld	hl, (P_BUF)
	ld	de, #FBUF
	ld	bc, (P_LEN)
	call	copy
	ld	hl, (P_LEN)
	pop	af
2$:	ld	(FLEN), hl
	ld	(FCH), a		; 1 read, 2 written at CLOSE
	ld	hl, #0
	ld	(FPTR), hl
	ld	a, #1
	ret

; HL = the room at P_BUF = FREE, below the stack (at most FMAX); "No room" if HL < BC
gap:	ld	hl, (FREE)
	ld	(P_BUF), hl
	ex	de, hl
	ld	hl, #-256
	add	hl, sp
	or	a
	sbc	hl, de
	jr	c, 2$
	push	hl
	ld	de, #FMAX
	sbc	hl, de
	pop	hl
	jr	c, 1$
	ex	de, hl
1$:	push	hl
	or	a
	sbc	hl, bc
	pop	hl
	ret	nc
2$:	xor	a
	jp	ERROR

; BC bytes from HL to DE
copy:	ld	a, b
	or	c
	ret	z
	ldir
	ret

;OSSHUT - close channel E (0: all). A file written goes to the Super Memoria now.
fs_shut::
	ld	a, e
	cp	#2
	ret	nc
	ld	a, (FCH)
	or	a
	ret	z
	cp	#2
	ld	a, #0
	ld	(FCH), a		; closed from here, whatever happens
	ret	nz			; read: nothing to do
	ld	hl, #P_NAME+16		; the name is still in P_NAME; the rest of the entry to zero
	ld	b, #16
1$:	ld	(hl), a
	inc	hl
	djnz	1$
	ld	bc, (FLEN)
	call	gap
	ld	(P_LEN), bc
	ld	hl, #FBUF
	ld	de, (P_BUF)
	call	copy
	call	fscopy
	call	crcbuf
	ld	(P_CRC), de
	ld	a, #OP_SAVE
	jp	fsrun

; HL = FBUF + FPTR, for channel E; "Channel" if it is not the open file's
fschan:	ld	a, (FCH)
	or	a
	jr	z, 1$
	ld	a, e
	dec	a
	jr	nz, 1$
	ld	hl, (FPTR)
	ret
1$:	ld	hl, #chanerr
	jp	R_JP1

;OSBGET - A = the next byte of channel E. "Eof" past the end.
fs_bget::
	push	hl
	push	de
	call	fschan
	ld	de, (FLEN)
	or	a
	sbc	hl, de
	add	hl, de
	jr	nc, 1$
	call	ptrinc
	ld	a, (hl)
	pop	de
	pop	hl
	ret
1$:	ld	hl, #E_EOF
	jp	fserror

; HL = FBUF + FPTR, then FPTR + 1. Destroys D,E.
ptrinc:	inc	hl
	ld	(FPTR), hl
	dec	hl
	ld	de, #FBUF
	add	hl, de
	ret

;OSBPUT - byte A to channel E (opened by OPENOUT or OPENUP). "File full" past FMAX bytes.
fs_bput::
	push	hl
	push	de
	push	af
	call	fschan
	ld	a, (FCH)
	cp	#2
	jr	nz, 3$
	ld	de, #FMAX
	or	a
	sbc	hl, de
	add	hl, de
	jr	nc, 1$
	call	ptrinc
	pop	af
	ld	(hl), a
	ld	hl, (FPTR)
	ld	de, (FLEN)
	or	a
	sbc	hl, de
	add	hl, de
	jr	c, 2$
	ld	(FLEN), hl
2$:	pop	de
	pop	hl
	ret
1$:	ld	hl, #E_FULL
	jp	fserror
3$:	ld	hl, #chanerr
	jp	R_JP1

;OSSTAT - Z if channel E is at its end
fs_stat::
	push	hl
	push	de
	call	fschan
	ld	de, (FLEN)
	or	a
	sbc	hl, de
	sbc	a, a			; 0 at the end
	pop	de
	pop	hl
	or	a
	ret

;GETEXT, GETPTR - DEHL = the length, the pointer of channel E
fs_ext::
	call	fschan
	ld	hl, (FLEN)
	jr	fsde0
fs_ptr::
	call	fschan
fsde0:	ld	de, #0
	ret

;PUTPTR - the pointer of channel A to HL (at most FMAX)
fs_putp::
	ld	e, a
	push	hl
	call	fschan
	pop	hl
	ld	de, #FMAX
	or	a
	sbc	hl, de
	add	hl, de
	jr	c, 1$
	ex	de, hl
1$:	ld	(FPTR), hl
	ret

; The texts of these errors go to RAM at start-up (p2init), for page 1 to report them
fsinit::
	ld	hl, #fstxt
	ld	de, #FSTXT
	ld	bc, #fstxt_end-fstxt
	ldir
	ret
fstxt:	.db	223
	.asciz	"Eof"
	.db	198
	.asciz	"File full"
fstxt_end:
E_EOF = FSTXT+1
E_FULL = E_EOF+4+1
	.ifgt	FSTXT+fstxt_end-fstxt-0xDB00
	.error	1
	.endif
