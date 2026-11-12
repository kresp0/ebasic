; shared.inc - constants shared by both cartridge pages: RAM layout, page selectors, jump-table slots.
; Copyright (C) 2026 Santiago Crespo
; SPDX-License-Identifier: GPL-3.0-or-later

CR = 13
LF = 10
ESC = 27
LEFT = 136			; Acorn cursor-key codes
RIGHT = 137
DOWN = 138
UP = 139
HOME = 140			; ALT+RETROCESO / ALT+AVANCE
END = 141
HELP = 142			; AYUDA (SHIFT+AYUDA is TAB)

PAGE1 = 0x80			; port 0x03: first 16 KiB of the cartridge (interpreter)
PAGE2 = 0x83			; second 16 KiB: bit 1 selects it on the RevD board, bit 0 in MAME

; Firmware RAM used only to run its interrupt routine as a timer (bank 0, both known ROMs)
FW_KEYST = 0xDB00		; D0 = "key pending": the ISR then skips its keyboard scan and idle power-off
FW_KEYCODE = 0xDB01		; must not be B4 (OFF) while FW_KEYST = D0
FW_DIRTY = 0xDCF0		; 4 row-dirty flags, then cursor col, row, style, enable
FW_HOOK = 0xDFF5

; RAM of the Genio layer, just above HIMEM
XRAM = 0xD880
SCR = XRAM			; 80-byte shadow screen
CX = SCR+80
CY = CX+1
TICKS = CY+1			; TIME, 4 bytes
TFRAC = TICKS+4
CAPS = TFRAC+2
P12 = CAPS+1			; last value written to port 0x12
RELCNT = P12+1
LASTSC = RELCNT+1
REPCNT = LASTSC+1
OFFARM = REPCNT+1
FLAGS = OFFARM+1		; bit 7 = Escape pending
TRPCNT = FLAGS+1
KEYCH = TRPCNT+1		; key read by TRAP while a program runs
KEYFLG = KEYCH+1
CAPT = KEYFLG+1			; OSWRCH capture: 0 off, 1 listing for the editor, 2 error message, 3 raw into the buffer
EDPTR = CAPT+1
; screen editor
ATPROMPT = EDPTR+2		; PROMPT was called: the next OSLINE is the editor
OUTDIRTY = ATPROMPT+1		; the interpreter printed something since the editor was last shown
VIEWOK = OUTDIRTY+1		; VIEW and the loaded line are up to date
BOUND = VIEWOK+1		; the view shows the program lines below this number
CURLN = BOUND+2			; program line loaded in the prompt (0: none)
PENDNAV = CURLN+2		; UP/DOWN to apply once a changed line has been stored
PENDKEY = PENDNAV+1		; key that ended the reading of the output
MODIF = PENDKEY+1
CUR = MODIF+1			; cursor and length of the line in ACCS
LEN = CUR+1
HOFS = LEN+1			; first character shown in the prompt row
ERRSHOW = HOFS+1
BLINK = ERRSHOW+1
ERRLEN = BLINK+1
ERRCELLS = ERRLEN+1
CAPIDX = ERRCELLS+1		; listing capture: line index, column, lines before the loaded one
CAPCOL = CAPIDX+1
NBEFORE = CAPCOL+1
LOADTGT = NBEFORE+1
LISTA = LOADTGT+1
LISTB = LISTA+2
ERRBUF = LISTB+2		; up to three rows of error message
VIEW = ERRBUF+60		; the three program rows above the prompt
; VDU, graphics, sound
CURSOFF = VIEW+60		; OFF: no cursor while a program waits for a key
VDUN = CURSOFF+1		; parameter bytes still to come for VDUC
VDUC = VDUN+1
VDUI = VDUC+1
VDUP = VDUI+1			; parameters (up to 9)
GMODE = VDUP+9			; MODE: 0 text, 1 with the 20x16 graphics window
GSHOW = GMODE+1			; the window is on the screen (CGRAM holds the picture)
GACT = GSHOW+1			; GCOL action (0 set, 1 or, 2 and, 3 eor, 4 invert) and colour
GFG = GACT+1
GBGACT = GFG+1			; same for the background colour (GCOL a,128+c)
GBG = GBGACT+1
ORGX = GBG+1			; ORIGIN
ORGY = ORGX+2
PTS = ORGY+2			; the last three points, x and y (16 bits), newest first
GBUF = PTS+12			; the picture: 8 CGRAM characters of 8 rows
GTMP = GBUF+64			; scratch for the drawing routines (24 bytes)
FMASK = GTMP+24			; flood fill: one bit per pixel of the window
ENVS = FMASK+40			; ENVELOPE 1-4: T, PI1-3, PN1-3 (7 bytes each)
SND = ENVS+28			; sound: parameters and state (24 bytes)
HSEL = SND+24			; help: selected entry, first entry shown, scroll of the page
HTOP = HSEL+1
HLINE = HTOP+1
MEMSHOWN = HLINE+1		; the free memory has been shown on the first screen
VARS_END = MEMSHOWN+1
RAMCODE = XRAM+0x200		; page-switching trampolines and the ISR hook, copied from page 1

; Page-2 jump table at 0x8000: slot n is at 0x8000+3*n
S_INIT = 0
S_OSRDCH = 1
S_OSWRCH = 2
S_OSLINE = 3
S_OSKEY = 4
S_CLRSCN = 5
S_PUTCSR = 6
S_GETCSR = 7
S_PROMPT = 8
S_TRAPKEY = 9
S_ASSEM = 10
S_SOUND = 11
S_ENVEL = 12
S_WAIT = 13
S_MODE = 14
S_CLG = 15
S_GCOL = 16
S_MOVE = 17
S_DRAW = 18
S_PLOT = 19
S_FILL = 20
S_LINE = 21
S_CIRCLE = 22
S_ELLIPS = 23
S_RECTAN = 24
S_ORIGIN = 25
S_POINT = 26
S_CSRON = 27
S_CSROFF = 28
S_MODEFN = 29
S_WIDFN = 30
S_ADVAL = 31
