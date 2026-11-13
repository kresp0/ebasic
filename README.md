# EBASIC: a BASIC for the VTech Genio 2000

*By Santiago Crespo, 2026. The BASIC interpreter inside it is R.T. Russell's BBC BASIC (Z80).*

EBASIC is a 32 KiB cartridge for the Spanish VTech Genio 2000. It uses two 16 KiB pages at 0x8000 and starts automatically (`55 AA 59 45`). The language is **R.T. Russell's BBC BASIC (Z80) v5 interpreter**; around it, EBASIC adds a layer written for the Genio:

* a **screen editor**: three rows of program above a one-row prompt;
* a **guide** on the HELP key, with a page and an example for every keyword;
* **keyword keys** on the activity panel, which programs can also read;
* **sound**, a **20x16 pixel graphics window**, the **Z80 inline assembler**, and **Spanish text** with accented capitals.

The language is the full v5: integer, 40-bit float, string and byte variables, arrays, multi-line `DEF PROC`/`DEF FN` with `LOCAL` and recursion, `REPEAT`, `WHILE`, `CASE`, `EXIT`, `ON ERROR`, `EVAL`, `TIME`, `GET`/`INKEY`, `TAB(x,y)` and so on. Programs live in RAM; there is no storage.

**About the name.** EBASIC is not an official edition of BBC BASIC. The interpreter's sources say that the name "BBC BASIC" is used with the BBC's permission and does not transfer to derived works, so this cartridge has its own name. The interpreter modules are Russell's, assembled unchanged except for the banner lines. The first screen reads:

```
EBASIC 1.0 by   5501
Santiago Crespo 2026
BASIC by R.T.Russell
>
```

The number at the top right is the memory free for programs and variables (`HIMEM-LOMEM`), worked out at start-up. `REPORT` before any error shows the second and third lines, where the original showed Russell's notice.

**Machines.** Written for the Spanish VTech Genio 2000, and tested in MAME so far. It will most likely also work on its
relatives the Genius 4000, Genius LEADER 4000 Quadro, Genius LEADER 4004 Quadro L and PreComputer
Power Pad, but it has not been tried on them; their keyboards carry other legends, so the key names
used here and some typed characters may differ.

## Keys
The legends on the Genio's keys are in Spanish. This README and the cartridge call the special keys by English names:

| Name used here | Key legend | What it does |
|---|---|---|
| ENTER | INTRO | enters the line |
| ANSWER | RESPUESTA | Escape: stops a program, leaves the guide |
| HELP | AYUDA | opens the guide (SHIFT+HELP is TAB) |
| DELETE | REPETIR / BORRAR | deletes to the left |
| DEL | JUGADOR DERECHA / DEL | deletes to the right |
| LEFT, RIGHT | RETROCESO, AVANCE | move the cursor in the line; with ALT, to the start and the end |
| up, down | ALT+Ü, ALT+; | previous / next program line (in the guide: Ü and ; alone, or LEFT/RIGHT) |
| SHIFT, CAPS, ALT | MAYÚSCULAS, BLOQ. MAYÚSCULAS, ALT | as on the key legends; CAPS is on at start-up, because keywords are upper case |

* **SHIFT** gives `¡ ¿ # $ % / & * ( )` on the digits, `? ! " :` on `, . ' ;`, and `< >` on LEFT/RIGHT.
* **ALT** gives `\ @ - _ + [ ] =` on 1-8, as the red legends show. **ALT+9 = `|`** and **ALT+0 = `~`** are EBASIC's own choice: those keys have no red legend.
* **ALT + vowel** gives an accented vowel. SHIFT xor CAPS chooses upper or lower case, so with CAPS on, ALT+A gives Á and SHIFT+ALT+A gives á.
* **PAUSA** is `^`.
* **OFF** switches the unit off as soon as it is pressed (it must be held about 20 ms, against contact bounce). It is checked whenever the keyboard is read, so a program that never reads the keyboard or checks for Escape cannot be switched off this way.
* **`GET` codes in a program:** LEFT 136, RIGHT 137, down 138, up 139, ALT+LEFT 140, ALT+RIGHT 141, HELP 142, and the activity keys (below).

### Activity keys
Each key of the top panel types a common keyword, as on a Spectrum; OFF and ON are not used. In a running program, `GET`/`INKEY` return the codes below. The order is the panel's, column by column, top to bottom.

| Column | Key legend | Types | `GET` code |
|---|---|---|---|
| 1 | BUSCA LA LETRA | `PRINT` | 192 |
| 1 | RECUERDA LA PALABRA | `INPUT` | 193 |
| 1 | PLURALES | `IF` | 194 |
| 1 | VERBOS | `THEN` | 195 |
| 1 | REVOLTIJO DE LETRAS | `ELSE` | 196 |
| 2 | LA PALABRA MISTERIOSA | `FOR` | 197 |
| 2 | DERIVADOS | `TO` | 198 |
| 2 | SINONIMOS | `STEP` | 199 |
| 2 | ANTONIMOS | `NEXT` | 200 |
| 2 | LA LETRA LOCA | `GOTO` | 201 |
| 3 | LA NUEVA PALABRA | `REPEAT` | 202 |
| 3 | TRUEQUE DE LETRAS | `UNTIL` | 203 |
| 3 | ALFAPUZZLE | `WHILE` | 204 |
| 3 | REVOLTIJO | `ENDWHILE` | 205 |
| 3 | ACERTIJO GRAMATICAL | `GOSUB` | 206 |
| 4 | SUMA | `DEF` | 207 |
| 4 | RESTA | `PROC` | 208 |
| 4 | MULTIPLICACION | `FN` | 209 |
| 4 | DIVISION | `ENDPROC` | 210 |
| 4 | FRACCIONES / DECIMALES | `LOCAL` | 211 |
| 5 | FRACCIONES / PORCENTAJES | `DIM` | 212 |
| 5 | RATIOS | `GET` | 213 |
| 5 | ALGEBRA | `INKEY` | 240 |
| 5 | REPASO A LAS MATEMATICAS | `RND` | 241 |
| 5 | EL SIGNO PERDIDO | `INT` | 242 |
| 6 | CIENCIAS | `CHR$` | 243 |
| 6 | CINE Y TELEVISION | `LEFT$(` | 244 |
| 6 | HISTORIA Y GEOGRAFIA | `MID$(` | 245 |
| 6 | GENERAL | `LEN` | 246 |
| 6 | ¿QUE SOY? | `TAB(` | 247 |
| 7 | EL NUMERO RELAMPAGO | `CLS` | 248 |
| 7 | BASIC | `RUN` | 249 |
| 7 | IMPRIMIR TEXTO | `LIST` | 250 |
| 7 | CALCULADORA | `MODE` | 251 |
| 7 | CARTUCHOS ADICIONALES | `RETURN` | 252 |
| 8 | NIVEL | `SOUND` | 253 |
| 8 | 1 JUGADOR | `REM` | 254 |
| 8 | 2 JUGADORES | `END` | 255 |

## The screen editor
```
20 FOR I=1 TO 10       <- rows 1-3: the program lines before the one in the prompt
30   PRINT I*I            (their first 20 characters)
40 NEXT
>50 PRINT "fin"_       <- row 4: the prompt, the line being edited
```
* **Editing:** type anywhere in the line; DELETE and DEL delete, LEFT/RIGHT move, ALT+LEFT/RIGHT jump to the start / end. A long line scrolls sideways in its row.
* **ENTER:** a program line (it starts with a number) is stored and moves up into the view, and the prompt is left empty. A command runs on the whole screen.
* **Up / down:** bring the program line above / below into the prompt, and the view scrolls with it. A changed line is stored before moving.
* **After a command:** if it printed or drew something, the screen stays until a key is pressed, and that key is the first of the next line (ENTER and ANSWER only dismiss it). If it printed nothing, the editor comes back at once.
* **Errors** show on the top rows (as many as they need, up to three) and blink until the cursor moves or ENTER is pressed. An error in a program line loads that line into the prompt. If the program had printed something, the message first follows that output on the full screen.
* **`INPUT` and `AUTO`** use a plain console line.
* **Line length:** the prompt holds up to 253 characters. A program line whose listing is longer is cut when it is loaded, and stored cut if it is then changed.

## The guide (HELP)
* **Opening it:** HELP opens an index with three pages about EBASIC, then one entry per keyword (all 145 of the interpreter's keywords and commands). With the cursor on a keyword, HELP opens that keyword's page directly.
* **In the index:** Ü and `;` (or LEFT/RIGHT, or ALT+Ü/ALT+;) move. A letter jumps to the first keyword with it. ENTER opens a page.
* **On a page:** the same keys scroll. A letter goes back to the index at that letter, ENTER copies the page's example into the prompt (ready to run or store), and ANSWER returns to the index.
* **The text** is in English, written for this cartridge. It comes from `help.txt` through `gen_help.py`, which:
  * checks that every keyword of the interpreter has an entry;
  * compresses the text with a 128-piece dictionary (11 KB to 7 KB);
  * lays every page out exactly as the cartridge does, and fails if one does not fit.

## Graphics, sound and the other statements
The statements that the CP/M edition answered with `Sorry` (from `HOOK.Z80`) are implemented in the way of Russell's Acorn edition (`ACORN.Z80`): each one is turned into VDU codes, so `VDU 25,...` and the rest work too. The EBASIC versions differ in these points:

* **`MODE 1`** turns on a **20x16 pixel window in the middle of the screen** (columns 9-12, rows 2-3), drawn with all 8 CGRAM characters. The LCD leaves gaps between character cells, so the picture looks like a grid. While the window is shown, accented capitals print wrongly, because their CGRAM glyphs are in use; the editor puts them back. `MODE 0` is text only. Both clear the screen.
* **Coordinates** are pixels, 0-19 by 0-15, with the origin at the bottom left.
* **Drawing statements:** `MOVE`, `DRAW`, `LINE`, `PLOT` (codes: lines, points, triangles 80, boxes 96, flood fill 128/136, circles 144/152, ellipses 192/200), `CIRCLE [FILL]`, `ELLIPSE [FILL]`, `RECTANGLE [FILL]`, `FILL`, `ORIGIN`, `CLG`, `GCOL a,c` (set / OR / AND / EOR / invert, `c+128` for the background), `POINT(x,y)` (1, 0, or -1 outside).
* **How shapes are drawn:** each pixel of the window is tested against the shape (`d² ≤ r² + r` for circles, the same rounding for ellipses). Lines use Bresenham. Differences in shape tests are limited to ±127 pixels.
* **`SOUND c,a,p,d`** plays on the 1-bit speaker:
  * channels 1-3 are tones and channel 0 is noise;
  * `a` from -15 to -1 plays, 0 is a rest, and 1-4 selects an envelope;
  * `p` is the BBC pitch scale (53 = middle C, 4 per semitone), and `d` is in twentieths of a second;
  * **the program waits while the note plays** (the 46.76 Hz interrupt is far too slow to make sound in the background), and ANSWER stops it.
  * The sound comes from a phase accumulator, at 91.9 kHz with interrupts off. `gen_sound.py` emits the 66 T-state sample loop and asserts its count.
* **`ENVELOPE`** keeps the pitch part of envelopes 1-4. The volume part cannot be played on a 1-bit speaker.
* **Other statements and functions:** `WAIT n` pauses n centiseconds. `OFF`/`ON` hide or show the cursor while a program waits for a key (`VDU 23,1,n` too). `ADVAL(-1)` tells whether a key is waiting. `MODE` and `WIDTH` also work as functions.
* **Still `Sorry`:** `COLOUR`, `TINT`, `MOUSE`, `SYS`, `TIME$`.
* **The inline assembler** `[ ... ]` is Russell's `ASMB.Z80`, unchanged, running in page 2.

## How it is built
| Page (port 0x03) | Contents | Free |
|---|---|---|
| 1 (`0x80`) | the interpreter (`MAIN`, `EXEC`, `EVAL`, `MATH`, `DATA`), `genio1.s` (start-up, entry stubs, `TRAP`, `TIME`, errors, keyboard scan, keyword names, trampolines), the sound engine | 11 bytes |
| 2 (`0x83`) | `genio2.s` (LCD, editor), `stmt.s` (statements, VDU, graphics), `help.s` + guide data, `ASMB.Z80`, stubs to page 1 | 17 bytes |

* **Selecting a page:** on the RevD board with a 32 KiB AT28C256, bit 1 of the port 0x03 selector drives A14 (measured on the unit: [HW_RESULTS_20261110.md](https://github.com/kresp0/vtech-genio2000/blob/main/docs/firmware/HW_RESULTS_20261110.md), test 3). MAME uses bit 0, so `0x83` reaches the second half on both.
* **Calls between pages** go through trampolines in RAM. They switch the page, call, and switch back, passing every register and flag through unchanged. The checks at assembly time make sure both pages agree on the slots of the page-2 jump table.
* **Statements** entered from page 1 continue at the interpreter's `XEQ`, and drop the trampoline's return address first.
* **Page-2 code that needs interpreter routines** (`EXPRI`, `COMMA`, ...; the assembler's `VAR`, `STOREN`, ...) calls stubs. `mksyms.py` generates them from the page-1 map.
* **The interrupt hook is in RAM**, because either page may be mapped when the interrupt comes.
* **The converter:** `m80_to_sdas.py` converts Russell's M80 sources to sdas syntax mechanically. `make verify-converter BBCZ80=<clone>` rebuilds his CP/M edition and checks that it is **byte-identical** to the published `BBCBASIC.COM`.
* **Memory:**

| Range | Use |
|---|---|
| `C000-C2FF` | interpreter workspace |
| `C300-D87F` | **PAGE = &C300, HIMEM = &D880**: 5,504 bytes for program, variables and stack |
| `D880-DA4F` | EBASIC's variables (`shared.inc`): shadow screen `D880`, `TIME` `D8D2`, picture `D999`, editor, sound, guide |
| `DA80-DACA` | trampolines and the interrupt hook |
| `DB00-DFFF` | left to the firmware's interrupt routine and the start-up stack |

* **Screen:** an 80-byte shadow screen, written cell by cell with the gl4000 DDRAM map, with about 70 µs per LCD write and no busy-flag read.
* **Text** is code page 850, the firmware's own internal code page. Nine codes are drawn from other glyphs: ñ Ñ ¡ ¿ º from the LCD's own ROM, and Á Í Ó Ú from CGRAM.
* **`TIME`** uses the firmware's 46.76 Hz interrupt as a timer. The layer first checks the vector and the hook, then sets `DB00 = D0` and `DB01 = FF`, the latter because with `DB00 = D0` the firmware powers off when `DB01 = B4`, the value it has at entry on the real unit ([INTERRUPTS.md](https://github.com/kresp0/vtech-genio2000/blob/main/docs/firmware/INTERRUPTS.md)). If the check fails, `TIME` stays at 0.

```bash
make            # ebasic_gl2000_AT28C256_32K.bin for the EEPROM, ebasic_gl2000_mame_64K.bin for MAME's -cart
make verify-converter BBCZ80=/path/to/BBCZ80
```
Needs `sdasz80`, `sdldz80` (SDCC 4.5) and `python3`.

## Status
**Verified in headless MAME** (`tests/`; logs of the final image in `tests/results/`):
* **The language** (`t1`-`t4`): arithmetic, floats, strings, recursion, `PROC` with arrays, errors, Escape, `TAB`, `INKEY`.
  * Speed: `FOR I%=1 TO 1000:NEXT` takes 0.40 s.
  * `TIME` runs 6.9 % fast in MAME, whose interrupt is 50 Hz instead of the 46.76 Hz measured on the unit ([CLOCK_AND_SOUND.md](https://github.com/kresp0/vtech-genio2000/blob/main/docs/hardware/CLOCK_AND_SOUND.md)).
* **Editor** (`t12`): views, insertion, saving on moving, errors on the console and blinking on the top rows, the error line loaded.
* **Guide** (`t16`): index, Ü/; without ALT, a letter jumps (from the index and from a page), keyword at the cursor, example copied and run.
* **Activity keys** (`t17`): PRINT, DIM, DEF, LEFT$( and LIST typed in the editor. `GET` gives 254, 255, 253, 192 for 1 JUGADOR, 2 JUGADORES, NIVEL, BUSCA LA LETRA.
* **Graphics** (`t14`, `t18`): the picture checked pixel by pixel for a circle, a line, a filled box, an ellipse, a flood fill, a triangle, EOR and `VDU 25`; `POINT` gives 1, 1, -1. A snapshot shows the window in the middle of the LCD, and it stays until a key is pressed.
* **Assembler** (`t13`): `LD HL,1234:RET` assembles to `21 D2 04 C9`, and `USR` returns `&4D20000` (HL is the high word of the result); `OPT 3` lists the code.
* **Sound** (`t15`, `ebasic_sound_mame.wav`):
  * middle C 261.0 Hz (261.6 expected), A 439.3 Hz (440), 880 Hz, a rest, noise, an envelope sweep;
  * `d = 10` lasts 0.504 s;
  * `WAIT 50` is 50 cs.
* **`VDU 7`** gives a 985 Hz beep.
* **Accents** (`t9`) and **cursor keys** (`t10`).
* **The LED program** (`t8`) and **OFF** (`t6`, a 50 ms press) work. Port 0x12 only receives `20`, `28`, `00` and, when switching off, `01`.
* **`QUIT`** goes back to the firmware menu.

**Not tested on hardware.** Nothing of EBASIC has run on a real unit. The risks, most serious first:
1. **The second cartridge page (`0x83`):** the selector bit was measured on the RevD board, but no code has ever run from the second half on the unit.
2. **The firmware ISR as a timer:** it relies on firmware internals (`DB00/DB01`, `DCF0-DCF7`, hook `DFF5`), as one combination; `hwtest` measured the parts separately ([HW_RESULTS_20261110.md](https://github.com/kresp0/vtech-genio2000/blob/main/docs/firmware/HW_RESULTS_20261110.md)).
3. **LCD timing:** no busy-flag read, and CGRAM is rewritten with interrupts off (64 bytes, about 4.5 ms).
4. **Reading the activity panel** through port 0x11 in the same scan as the main keys. The firmware does this, but EBASIC's own scan has not run on the unit.
5. **The sound:** loop timing on the real clock; the speaker's own response is not modelled.
6. **The keyboard:** ghosting with several keys held, and the ALT symbols and SHIFT+ALT+vowel, which the firmware's BASIC was never seen producing.
7. **Uninitialised RAM** at power-up, which MAME clears.

No undocumented opcodes are used.

## Licence
* 0BSD (`LICENSE`), Copyright (C) 2026 Santiago Crespo: EBASIC's own files, code and documentation (`genio1.s`, `genio2.s`, `stmt.s`, `help.s`, `help.txt`, `shared.inc`, the generators, the `Makefile`, `tests/`, this README). You may use, copy, modify and distribute them for any purpose, with or without fee, without conditions. Until 2026-11-13 they were released under GPL-3.0-or-later; copies taken then may still be used under those terms.
* zlib licence: `bbcz80/` holds R.T. Russell's BBC BASIC (Z80) sources unchanged (`licence.txt`). The build makes altered versions from them in `out/` (converted to sdas syntax, and `MAIN` with the banner lines changed), and says so in their headers.
