#!/bin/sh
# The MAME tests of the Super Memoria commands (image ebasic-sm), with the images they leave checked by smfs.py
# (kresp0/vtech-genio2000 tools/smfs, SMFS=path). Results in tests/smout/<test>/drive.log.
# Copyright (C) 2026 Santiago Crespo
# SPDX-License-Identifier: 0BSD
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"
SMFS=${SMFS:-$HOME/PROYECTOS/genio2000/genio2000-repo/tools/smfs/smfs.py}
O=tests/smout
fail=0
run() {   # test [image]
  CART=ebasic-sm_gl2000_mame_64K.bin SM_INIT=${2:-blank} tests/run_mame.sh "tests/$1.txt" "$O/$1" 120 > /dev/null 2>&1
  r=$(tail -1 "$O/$1/drive.log")
  echo "$1: $r"
  case "$r" in *"fail=0"*) ;; *) fail=1; grep -A5 FAIL "$O/$1/drive.log" | head -30 ;; esac
}
ok() {    # description command...
  d=$1; shift
  if "$@" > /dev/null 2>&1; then echo "  ok: $d"; else echo "  FAILED: $d"; fail=1; fi
}
C="python3 tests/smcheck.py"
export SMFS
$C images $O/img || exit 1
run t20_smfs
T=$O/t20_smfs
for f in formatted saved1 replaced saved2 erased sram_after; do ok "$f.bin valid for smfs.py" python3 "$SMFS" $T/$f.bin; done
ok "FORMAT = smfs.py format" $C format $T/formatted.bin
ok "SAVE \"prog\" = smfs.py put PROG.BAS" $C put $T/formatted.bin $T/saved1.bin PROG.BAS
ok "SAVE \"PROG.BAS\" again = smfs.py put (replaced, old block freed)" $C put $T/saved1.bin $T/replaced.bin PROG.BAS
ok "SAVE \"other\" = smfs.py put OTHER.BAS" $C put $T/replaced.bin $T/saved2.bin OTHER.BAS
ok "*ERA \"other\" = smfs.py rm OTHER.BAS" $C rm $T/saved2.bin $T/erased.bin OTHER.BAS
ok "failed ERASE, LOAD and CHAIN wrote nothing" $C same $T/erased.bin $T/sram_after.bin
I=$HERE/$O/img
run t21_full $I/dirfull.bin
ok "Directory full: nothing written" $C same $I/dirfull.bin $O/t21_full/unchanged.bin
ok "F07.BAS replaced in a full directory = smfs.py put" $C put $I/dirfull.bin $O/t21_full/sram_after.bin F07.BAS
run t22_cartfull $I/full.bin
ok "Cartridge full, then PROG.BAS replaced = smfs.py put" $C put $I/full.bin $O/t22_cartfull/sram_after.bin PROG.BAS
run t23_badcrc $I/badcrc.bin
ok "Bad CRC: nothing written" $C same $I/badcrc.bin $O/t23_badcrc/sram_after.bin
run t24_badindex $I/badindex.bin
ok "Bad index: nothing written by SAVE, ERASE, DIR, LOAD" $C same $I/badindex.bin $O/t24_badindex/unchanged.bin
ok "then FORMAT = smfs.py format" $C format $O/t24_badindex/sram_after.bin
run t25_misc $I/files.bin
ok "*CAT, OSCLI \"ERA NOTES.TXT\" = smfs.py rm" $C rm $I/files.bin $O/t25_misc/erased.bin NOTES.TXT
ok "LONG.BAS (4 blocks) loaded and saved as LONG2.BAS = smfs.py put" $C put $O/t25_misc/erased.bin $O/t25_misc/long2.bin LONG2.BAS
ok "LONG2.BAS has the bytes of LONG.BAS" sh -c "python3 $SMFS $O/t25_misc/long2.bin get LONG.BAS $O/t25_misc/a && python3 $SMFS $O/t25_misc/long2.bin get LONG2.BAS $O/t25_misc/b && cmp $O/t25_misc/a $O/t25_misc/b"
ok "Cannot write, OFF: nothing more written" $C same $O/t25_misc/long2.bin $O/t25_misc/sram_after.bin
run t26_nofmt blank
ok "Not formatted: nothing written" $C same $O/t26_nofmt/sram_before.bin $O/t26_nofmt/sram_after.bin
run t27_broken $I/broken.bin
ok "Bad file: nothing written" $C same $I/broken.bin $O/t27_broken/sram_after.bin
run t28_after blank
run t29_files $I/files.bin
ok "OPENOUT, PRINT#, BPUT#, CLOSE# = smfs.py put DATA.DAT" $C put $I/files.bin $O/t29_files/written.bin DATA.DAT
ok "a 720-byte file written by CLOSE# = smfs.py put BIG.DAT" $C put $O/t29_files/written.bin $O/t29_files/big.bin BIG.DAT
ok "OPENIN of a missing file wrote nothing" $C same $O/t29_files/big.bin $O/t29_files/sram_after.bin
[ $fail = 0 ] && echo "ALL PASS" || echo "SOME FAILED"
exit $fail
