#!/usr/bin/env python3
# Two Intel HEX files (page 1 and page 2, both linked at 0x8000) -> 32 KiB cartridge image for an AT28C256:
# page 1 in the first 16 KiB (port 0x03 = 0x80), page 2 in the second (0x83: bit 1 drives A14 on the RevD
# board). With a fourth argument, also a 64 KiB copy for MAME, which maps selector 0x8n to offset n*16 KiB
# without mirroring: repeating the image puts page 2 at 0x83 too, as on a board where A15 is not connected.
# Fails if any byte lies outside the cartridge window.
# Copyright (C) 2026 Santiago Crespo
# SPDX-License-Identifier: 0BSD
import sys


def page(ihx):
    img, top = bytearray(b"\xff" * 0x4000), 0x8000
    for line in open(ihx):
        n, addr, typ = int(line[1:3], 16), int(line[3:7], 16), int(line[7:9], 16)
        if typ != 0:
            continue
        if addr < 0x8000 or addr + n > 0xC000:
            sys.exit("%s: data outside the cartridge window at 0x%04X" % (ihx, addr))
        img[addr - 0x8000:addr - 0x8000 + n] = bytes.fromhex(line[9:9 + 2 * n])
        top = max(top, addr + n)
    return img, top - 0x8000


p1, u1 = page(sys.argv[1])
p2, u2 = page(sys.argv[2])
assert p1[:4] == b"\x55\xaa\x59\x45", "missing autostart signature"
open(sys.argv[3], "wb").write(p1 + p2)
if len(sys.argv) > 4:
    open(sys.argv[4], "wb").write((p1 + p2) * 2)
print("page 1: %d of 16384 bytes used, %d free" % (u1, 16384 - u1))
print("page 2: %d of 16384 bytes used, %d free" % (u2, 16384 - u2))
