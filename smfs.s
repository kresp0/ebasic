; smfs.s - SAVE, LOAD, DIR, FORMAT and ERASE on the Super Memoria RAM cartridge, in SMFS (docs/SMFS.md of
; kresp0/vtech-genio2000). fs.s copies it to RAM that EBASIC does not use while one of these commands runs
; (SMA to SME in shared.inc) and calls SMENTRY with interrupts off. It runs while the EBASIC cartridge
; is out of the slot, so it has its own LCD, keyboard and OFF code, and it returns only once EBASIC is back.
; fs.s computes the CRC of a program's bytes itself, with crcup.
; Copyright (C) 2026 Santiago Crespo
; SPDX-License-Identifier: 0BSD

	.module	smfs
	.include "shared.inc"

HDR = 0x8000			; all the metadata is in page 80: header, CRC at 800C, block table, directory
MCRC = 0x800C
TAB = 0x8080
DIR = 0x8100
NENT = 32
ESIZE = 32
NBLK = 128
FIRSTB = 5			; blocks 0-4 hold the metadata

K_INTRO = 0x10			; getkey: bits of column 7 (port 0x10 rows 4 and 6, port 0x11 row 9)
K_ANS = 0x40
K_OFF = 0x02

; Variables, in the graphics scratch (GTMP and FMASK, 64 bytes)
edsum = GTMP			; sum of EBASIC's pages 80 and 83
oldent = GTMP+4
src = GTMP+6
left = GTMP+8
mode = GTMP+10			; walk: 0 read, 1 compare, 2 write
oldfirst = GTMP+11
offcnt = GTMP+12		; OFF: scans held, and 1 once seen released
offarm = GTMP+13
tsum = GTMP+14			; cartis: the first reading
blink = GTMP+16			; wait5: the caps LED blinks while this code runs
nbuf = GTMP+18			; 5 digits
lbuf = GTMP+23			; a row of text
	.ifgt	lbuf+21-FMASK-40
	.error	1
	.endif

	.area	SMC (ABS)
	.org	SMC
SMENTRY::
	ld	a, #R_ESC
	ld	(P_RES), a
	ld	hl, #t_back		; (an empty row: the result of cancelling)
	ld	(P_MSG), hl
	xor	a
	ld	(offarm), a
	ld	a, #0x0C		; LCD cursor off
	call	lcd_cmd
	call	sums
	ld	(edsum), hl
	ld	hl, #t_ins		; the swap
	call	show4
1$:	call	getkey
	cp	#K_ANS
	jr	z, 2$
	cp	#K_INTRO
	jr	nz, 1$
	call	cartis			; on only with another cartridge that reads the same twice
	dec	a
	jr	nz, 1$
	ld	a, (P_OP)
	cp	#OP_FORMAT
	jp	z, op_format
	call	fscheck
	jr	z, 3$
	ld	hl, #m_nofmt
	dec	a
	jp	z, err
	ld	hl, #m_meta
	jp	err
3$:	ld	a, (P_OP)
	cp	#OP_SAVE
	jr	z, op_save
	cp	#OP_DIR
	jp	z, op_dir
	call	findname		; LOAD and ERASE
	ld	hl, #m_notf
	jp	nz, err
	cp	#OP_LOAD
	jp	z, op_load
	ld	a, 16(ix)		; ERASE
	call	freechain
	call	clrent
	call	metaput
	ld	hl, #m_done
	jp	ok
2$:	call	cartis			; RESPUESTA: back only if EBASIC is in
	or	a
	jp	z, retn
	jp	back

; A file of the same name keeps its blocks until the new copy is in place: they do not count as free
op_save:
	call	findname
	ld	a, 16(ix)
	jr	z, 1$
	call	freeent
	ld	hl, #m_dirf
	jp	nz, err
	ld	a, #0xFF
1$:	ld	(oldent), ix
	ld	(oldfirst), a
	ld	hl, (P_LEN)		; blocks: (length + 255) / 256, at least 1
	ld	de, #255
	add	hl, de
	ld	a, h
	or	a
	jr	nz, 2$
	inc	a
2$:	ld	b, a
	call	countfree
	cp	b
	ld	hl, #m_full
	jp	c, err
	call	link
	ld	c, #2			; the data
	call	walk
	ld	de, (oldent)		; the entry: from here on the new copy is the file
	ld	hl, #P_NAME
	ld	bc, #ESIZE
	ldir
	ld	a, (oldfirst)
	call	freechain
	call	metaput
	ld	c, #1			; read it back
	call	walk
	ld	hl, #m_verify
	jp	nz, err
	ld	hl, #m_done
	jp	ok

atend:	push	ix
	pop	hl
	ld	a, h
	cp	#>(DIR+NENT*ESIZE)
	ret


;---------------------------------------------------------------- the SMFS routines
lcd_cmd:
	out	(0x0A), a
	jr	lcd_wait
lcd_dat:
	out	(0x0B), a
lcd_wait:
	push	bc
	ld	b, #40
1$:	djnz	1$
	pop	bc
	ret

	.area	SMA (ABS)
	.org	SMCODE

pg80:	ld	a, #0x80
	jr	pgset
pg81:	ld	a, #0x81
pgset:	out	(0x03), a
	ret

; DE = CRC-16/CCITT updated with A
crcup::	push	bc
	xor	d
	ld	d, a
	ld	b, #8
1$:	sla	e
	rl	d
	jr	nc, 2$
	ld	a, d
	xor	#0x10
	ld	d, a
	ld	a, e
	xor	#0x21
	ld	e, a
2$:	djnz	1$
	pop	bc
	ret

; DE = CRC of the block table and the directory
metacrc:
	call	pg80
	ld	hl, #TAB
	ld	de, #0xFFFF
1$:	ld	a, (hl)
	call	crcup
	inc	hl
	ld	a, h
	cp	#0x85
	jr	nz, 1$
	ret

metaput:
	call	metacrc
	ld	(MCRC), de
	ret

; Z: SMFS with good metadata. NZ: A = 1 not SMFS, 2 metadata CRC wrong
fscheck:
	call	pg80
	ld	hl, #magic
	ld	de, #HDR
	ld	b, #8
1$:	ld	a, (de)
	cp	(hl)
	ld	a, #1
	ret	nz
	inc	hl
	inc	de
	djnz	1$
	call	metacrc
	ld	hl, (MCRC)
	or	a
	sbc	hl, de
	ld	a, #2
	ret

; IX = the entry named P_NAME, Z if there is one (P_NAME is never empty: free entries never match).
; A = P_OP.
findname:
	ld	ix, #DIR
	ld	b, #NENT
1$:	push	ix
	pop	hl
	ld	de, #P_NAME
	ld	c, #16
2$:	ld	a, (de)
	cp	(hl)
	jr	nz, 3$
	inc	hl
	inc	de
	dec	c
	jr	nz, 2$
3$:	ld	a, (P_OP)
	ret	z
	ld	de, #ESIZE
	add	ix, de
	djnz	1$
	ret

; IX = the first free entry, Z if there is one
freeent:
	ld	ix, #DIR
	ld	de, #ESIZE
	ld	b, #NENT
1$:	ld	a, 0(ix)
	or	a
	ret	z
	add	ix, de
	djnz	1$
	ret

; The entry at IX to zero
clrent:	push	ix
	pop	hl
	ld	b, #ESIZE
1$:	ld	(hl), #0
	inc	hl
	djnz	1$
	ret

; Chains the B lowest free blocks in the table (there are enough): P_FIRST and the links, FF on the last
link:	ld	de, #P_FIRST
	ld	hl, #TAB+FIRSTB
1$:	ld	a, (hl)
	or	a
	jr	nz, 2$
	ld	a, l
	sub	#<TAB
	ld	(de), a
	ld	e, l
	ld	d, h
	dec	b
	jr	z, 3$
2$:	inc	l
	jr	1$
3$:	ld	a, #0xFF
	ld	(de), a
	ret

; Frees the chain from block A (FF: none)
freechain:
	ld	h, #>TAB
1$:	cp	#FIRSTB
	ret	c
	cp	#NBLK
	ret	nc
	add	a, #<TAB
	ld	l, a
	ld	a, (hl)
	ld	(hl), #0
	jr	1$

magic:	.db	0x55, 0xAA, 0xEE, 0x53, 0x4D, 0x46, 0x53, 0x01	; 55 AA EE "SMFS" version 1
; Results, in LCD codes; an error's number comes before it (fs.s reports it with EXTERR)
m_done:	.asciz	"Done."
	.db	200
m_nofmt: .asciz	"Not formatted"
	.db	201
m_meta:	.asciz	"Bad index"
	.db	202
m_nowr:	.asciz	"Cannot write"
	.db	214
m_notf:	.asciz	"File not found"
	.db	179
m_dirf:	.asciz	"Directory full"
	.db	198
m_full:	.asciz	"Cartridge full"
	.db	203
m_verify: .asciz "Verify failed"
	.db	205
m_big:	.asciz	"Too big"
	.db	206
m_bad:	.asciz	"Bad file"
	.db	207
m_crc::	.asciz	"Bad CRC"
poweroff:				; the power-off sequence verified on the unit
	di
	ld	a, #0x01
	out	(0x12), a
1$:	halt
	jr	1$

; About 5 ms. Every 64 calls the caps LED changes, so that a blinking LED shows this code is running.
wait5:	push	bc
	ld	bc, #1180
1$:	dec	bc
	ld	a, b
	or	c
	jr	nz, 1$
	pop	bc
	ld	a, (blink)
	inc	a
	ld	(blink), a
	and	#0x3F
	ret	nz
	ld	a, (blink)
	and	#0x40
	rra				; bit 5 of port 0x12: the LED (bit 0, power off, stays 0)
	out	(0x12), a
	ret

t_free:	.asciz	" bytes free"
; An empty SMFS; NZ if the cartridge does not keep what is written
format:	call	pg80
	ld	hl, #HDR
1$:	ld	(hl), #0
	ld	a, (hl)
	or	a
	ret	nz
	inc	hl
	ld	a, h
	cp	#0x85
	jr	nz, 1$
	ld	hl, #magic
	ld	de, #HDR
	ld	bc, #8
	ldir
	ld	hl, #TAB
	ld	b, #FIRSTB
2$:	ld	(hl), #0xFE
	inc	hl
	djnz	2$
	call	metaput
	jp	fscheck			; and read it back

; P_LEN bytes at P_BUF along the chain from P_FIRST: C = 0 read into RAM, 1 compared, 2 written (the last
; block padded with zeros). NZ: a block outside 5-127, or a difference.
walk:	ld	a, c
	ld	(mode), a
	ld	hl, (P_BUF)
	ld	(src), hl
	ld	hl, (P_LEN)
	ld	(left), hl
	ld	a, (P_FIRST)
1$:	ld	hl, (left)
	ld	b, a
	ld	a, h
	or	l
	jr	z, 9$
	ld	a, b
	cp	#FIRSTB
	jr	c, 8$
	cp	#NBLK
	jr	nc, 8$
	push	af
	ld	l, #0			; blocks 00-3F at 8000 + n * 256 in page 80, 40-7F the same in page 81
	cp	#0x40
	jr	nc, 2$
	add	a, #0x80
	ld	h, a
	call	pg80
	jr	3$
2$:	add	a, #0x40
	ld	h, a
	call	pg81
3$:	ld	bc, (left)		; this block's bytes: BC = min(left, 256)
	ld	a, b
	or	a
	jr	z, 4$
	ld	bc, #256
4$:	push	hl
	ld	hl, (left)
	sbc	hl, bc			; (carry is clear)
	ld	(left), hl
	pop	hl
	ld	de, (src)
	ld	a, (mode)
	dec	a
	jr	z, 6$
	jp	p, 5$
	ldir				; read
	jr	7$
5$:	ex	de, hl			; write, then zeros to the end of the block
	ldir
	ex	de, hl
51$:	ld	a, l
	or	a
	jr	z, 7$
	ld	(hl), b
	inc	l
	jr	51$
6$:	ld	a, (de)			; compare
	cpi
	jr	nz, 71$
	inc	de
	jp	pe, 6$
7$:	ld	(src), de
	call	pg80
	pop	af
	add	a, #<TAB
	ld	l, a
	ld	h, #>TAB
	ld	a, (hl)
	jr	1$
71$:	pop	af
8$:	call	pg80
	or	#1
	ret
9$:	call	pg80
	xor	a
	ret

;---------------------------------------------------------------- DIR: four files a screen; INTRO: the next four

op_dir:	ld	ix, #DIR-ESIZE
	call	skip
1$:	ld	d, #0
2$:	push	de
	ld	hl, #lbuf
	ld	b, #20
3$:	ld	(hl), #0x20
	inc	hl
	djnz	3$
	ld	(hl), b
	call	atend
	jr	z, 5$
	push	ix			; the name, and the length at the end of the row
	pop	hl
	ld	de, #lbuf
	ld	b, #16
4$:	ld	a, (hl)
	or	a
	jr	z, 41$
	ld	(de), a
	inc	hl
	inc	de
	djnz	4$
41$:	ld	l, 18(ix)
	ld	h, 19(ix)
	ld	de, #lbuf+15
	call	number
	call	skip
5$:	pop	de
	ld	hl, #lbuf
	call	show
	inc	d
	bit	2, d
	jr	z, 2$
	call	getkey
	cp	#K_ANS
	jr	z, 6$
	call	atend
	jr	nz, 1$
6$:	call	countfree		; the result: the free bytes
	ld	h, a
	ld	l, #0
	ld	de, #lbuf
	call	number
	ld	hl, #t_free
	ld	bc, #12
	ldir
	ld	hl, #lbuf
	jp	ok

; HL in decimal into the five cells from DE, without leading zeros (their cells keep what they had)
number:	push	de
	ld	de, #nbuf
	ld	bc, #-10000
	call	1$
	ld	bc, #-1000
	call	1$
	ld	bc, #-100
	call	1$
	ld	c, #-10
	call	1$
	ld	c, b
	call	1$
	pop	de
	ld	hl, #nbuf
	ld	b, #4
2$:	ld	a, (hl)
	cp	#0x30
	jr	nz, 3$
	inc	hl
	inc	de
	djnz	2$
3$:	inc	b
	ld	c, b
	ld	b, #0
	ldir
	ret
1$:	ld	a, #0x2F
4$:	inc	a
	add	hl, bc
	jr	c, 4$
	sbc	hl, bc
	ld	(de), a
	inc	de
	ret

;---------------------------------------------------------------- the end: the result, and EBASIC back

err:	ld	a, #R_ERR
	.db	0xFE			; (cp #n: skips the xor)
ok:	xor	a
fin:	ld	(P_RES), a
	ld	(P_MSG), hl
back:	ld	hl, (P_MSG)		; row 0 the result, then the request
	ld	d, #0
	call	show
	ld	hl, #t_back
	inc	d
	call	showfrom
	call	getkey
	cp	#K_INTRO
	jr	nz, back
	call	cartis
	or	a
	jr	nz, back
retn:	ld	a, (P12)		; EBASIC's LED again
	out	(0x12), a
	ld	a, #PAGE2
	out	(0x03), a
	ret

;---------------------------------------------------------------- LCD, keyboard, OFF

; Four strings from HL on rows 0-3 (showfrom: from row D to 3)
show4:	ld	d, #0
showfrom:
	call	show
	inc	hl
	inc	d
	bit	2, d
	jr	z, showfrom
	ret

; Row D = the string at HL, padded with spaces; HL ends on its 0. A row is three runs of DDRAM.
show:	push	de
	ld	a, d
	add	a, a
	add	a, d
	ld	e, a
	ld	d, #0
	push	hl
	ld	hl, #rowadr
	add	hl, de
	ex	de, hl
	pop	hl
	ld	c, #4
	call	1$
	ld	c, #8
	call	1$
	call	1$
	pop	de
	ret
1$:	ld	a, (de)
	inc	de
	call	lcd_cmd
	ld	b, c
2$:	ld	a, (hl)
	inc	hl
	or	a
	jr	nz, 3$
	dec	hl
	ld	a, #0x20
3$:	call	lcd_dat
	djnz	2$
	ret

; Set-DDRAM commands for the three runs of each row (columns 0, 4 and 12; the gl4000 map)
rowadr:	.db	0x80,0x88,0x98, 0xC0,0xC8,0xD8, 0x84,0x90,0xA0, 0xC4,0xD0,0xE0

; A = the keys down in column 7 (INTRO, RESPUESTA, OFF bits), 0 if none
kbscan:	ld	a, #0x80
	out	(0x10), a
	ld	b, #4
1$:	djnz	1$
	in	a, (0x10)
	cpl
	and	#K_INTRO|K_ANS
	ld	c, a
	in	a, (0x11)
	cpl
	and	#K_OFF
	or	c
	ld	c, a
	xor	a
	out	(0x10), a
	ld	a, c
	ret

; A = the next key: all keys up, then the same in two scans 5 ms apart
getkey:	call	kscan
	or	a
	jr	nz, getkey
1$:	call	kscan
	or	a
	jr	z, 1$
	ld	d, a
	call	kscan
	cp	d
	jr	nz, 1$
	ret

; About 5 ms, then a scan. OFF reads as no key; held for about 1.2 s, once it has been seen released,
; it switches the unit off (as supermem-test: a contact that bounces while cartridges are swapped
; must not do it).
kscan:	call	wait5
	call	kbscan
	push	hl
	ld	hl, #offcnt
	bit	1, a
	jr	z, 3$
	inc	hl
	ld	a, (hl)
	dec	hl
	or	a
	jr	z, 2$
	inc	(hl)
	ld	a, (hl)
	cp	#220
	jp	nc, poweroff
2$:	xor	a
	pop	hl
	ret
3$:	ld	(hl), #0
	inc	hl
	ld	(hl), #1
	pop	hl
	ret
t_ins:	.asciz	"Swap EBASIC for the"
	.asciz	"SUPER MEMORIA: INTRO"
	.asciz	"RESPUESTA: cancel"
	.db	0
t_back:	.db	0
	.asciz	"Put EBASIC back in:"
	.asciz	"INTRO"

	.area	SMD (ABS)
	.org	SMD
op_format:
	call	format
	ld	hl, #m_nowr
	jp	nz, err
	ld	hl, #m_done
	jp	ok

op_load:
	push	ix			; the entry to P_NAME...: first block, length, CRC
	pop	hl
	ld	de, #P_NAME
	ld	bc, #ESIZE
	ldir
	ld	hl, (P_LEN)
	ld	de, (P_CAP)
	scf
	sbc	hl, de
	ld	hl, #m_big
	jp	nc, err
	ld	c, #0
	call	walk
	ld	hl, #m_done
	jp	z, ok
	ld	a, #R_BROKEN
	ld	hl, #m_bad
	jp	fin

; HL = 16-bit sum of pages 83 and 80; page 80 selected after (as while the cartridges are swapped)
sums:	ld	hl, #0
	ld	a, #PAGE2
	call	pgsum
	ld	a, #0x80
; HL + the bytes of page A
pgsum:	call	pgset
	ld	de, #0x8000
1$:	ld	a, (de)
	add	a, l
	ld	l, a
	jr	nc, 2$
	inc	h
2$:	inc	de
	bit	6, d
	jr	z, 1$
	ret

; A = the number of free blocks
countfree:
	ld	hl, #TAB+FIRSTB
	ld	c, #0
1$:	ld	a, (hl)
	or	a
	jr	nz, 2$
	inc	c
2$:	inc	l
	jr	nz, 1$
	ld	a, c
	ret

; IX = the next used entry; Z: none (IX at the end)
skip:	ld	de, #ESIZE
1$:	add	ix, de
	call	atend
	ret	z
	ld	a, 0(ix)
	or	a
	jr	z, 1$
	ret

	.area	SME (ABS)
	.org	SME
; What is in the slot, from the sum of pages 80 and 83 read twice 0.3 s apart: A = 0 EBASIC, 1 another
; cartridge, 2 the readings differ (a cartridge going in or out)
cartis:	call	sums
	ld	(tsum), hl
	ld	b, #60
1$:	call	wait5
	djnz	1$
	call	sums
	ld	de, (tsum)
	or	a
	sbc	hl, de
	ld	a, #2
	ret	nz
	ld	hl, (edsum)
	sbc	hl, de
	ld	a, #0
	ret	z
	inc	a
	ret
