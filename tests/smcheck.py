#!/usr/bin/env python3
# Checks of Super Memoria images left by the MAME tests, with tools/smfs/smfs.py of kresp0/vtech-genio2000:
#   smcheck.py put BEFORE AFTER NAME   AFTER = BEFORE with NAME written by smfs.py (the data taken from AFTER)
#   smcheck.py rm BEFORE AFTER NAME    AFTER = BEFORE with NAME erased by smfs.py
#   smcheck.py format AFTER            AFTER's metadata = an empty SMFS made by smfs.py
#   smcheck.py same A B                A = B
#   smcheck.py images DIR              the test images in DIR (see mkimages below)
# env SMFS = path of smfs.py. Byte-identical results mean EBASIC writes exactly what the format says.
# Copyright (C) 2026 Santiago Crespo
# SPDX-License-Identifier: 0BSD
import os
import sys

sys.path.insert(0, os.path.dirname(os.environ["SMFS"]))
import smfs

op, args = sys.argv[1], sys.argv[2:]
rd = lambda p: open(p, "rb").read()
if op in ("put", "rm"):
    before, after, name = smfs.SMFS(rd(args[0])), rd(args[1]), args[2]
    if op == "put":
        data, ok = smfs.SMFS(after).read(smfs.SMFS(after).find(name))
        assert ok, "CRC"
        before.put(name, data)
    else:
        before.rm(name)
    sys.exit(0 if bytes(before.m) == after else "%s %s: images differ" % (op, name))
if op == "format":
    fs = smfs.SMFS(bytes(0x8000))
    fs.format()
    sys.exit(0 if rd(args[0])[:0x500] == bytes(fs.m[:0x500]) else "not an empty SMFS")
if op == "same":
    sys.exit(0 if rd(args[0]) == rd(args[1]) else "images differ")
if op == "images":
    d = args[0]
    os.makedirs(d, exist_ok=True)
    line = lambda n, body: bytes([len(body) + 4, n & 0xFF, n >> 8]) + body + b"\r"
    prog = line(10, b'\xf1 "hi"') + b"\0\xff\xff"                  # 10 PRINT "hi"
    long = line(5, b'\xf1 "long"') + b"".join(line(10 * i, b"\xf4" + bytes([0x41 + i]) * 200) for i in range(1, 5))
    long += line(60, b'\xf1 "end"') + b"\0\xff\xff"               # 5 PRINT "long", 4 REMs of 200, 60 PRINT "end"
    fs = smfs.SMFS(bytes(0x8000))
    fs.format()
    fs.put("PROG.BAS", prog)
    fs.put("NOTES.TXT", b"un texto\nde dos lineas")
    fs.put("BIG.BAS", bytes(6000))
    fs.put("LONG.BAS", long)
    open(d + "/files.bin", "wb").write(fs.m)
    bad = bytearray(fs.m)
    bad[fs.m[fs.find("PROG.BAS") + 16] * 256 + 3] ^= 0x01      # PRINT -> PLOT: the CRC is wrong
    open(d + "/badcrc.bin", "wb").write(bad)
    bad = bytearray(fs.m)
    bad[smfs.TAB + 0x70] = 0x33                                # a table byte: the metadata CRC is wrong
    open(d + "/badindex.bin", "wb").write(bad)
    br = smfs.SMFS(bytes(fs.m))
    br.put("MID.BAS", bytes(600))
    e = br.find("MID.BAS")
    br.m[smfs.TAB + br.m[e + 16]] = 3                          # MID.BAS's chain goes to a metadata block
    br.store_meta()
    open(d + "/broken.bin", "wb").write(br.m)
    full = smfs.SMFS(bytes(0x8000))
    full.format()
    for i in range(32):
        full.put("F%02d.BAS" % i, prog)
    open(d + "/dirfull.bin", "wb").write(full.m)
    big = smfs.SMFS(bytes(0x8000))
    big.format()
    big.put("PROG.BAS", prog)
    big.put("HUGE.TXT", bytes(121 * 256))                     # 1 block left
    open(d + "/full.bin", "wb").write(big.m)
    sys.exit(0)
sys.exit("usage")
