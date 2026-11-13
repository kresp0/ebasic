#!/usr/bin/env python3
# Builds the data of the AYUDA guide (help.s) from help.txt.
#   * Checks that every keyword of the interpreter (MAIN.Z80's tables) has an entry.
#   * Compresses the entry texts with a dictionary of up to 128 pieces (bytes 0x80-0xFF);
#     byte 1 escapes a code page 850 character, 10 is a new line.
#   * Lays every page out exactly as hwrap in help.s does and fails if one does not fit.
# Usage: gen_help.py help.txt MAIN.Z80 out/helpdata.s
# Copyright (C) 2026 Santiago Crespo
# SPDX-License-Identifier: 0BSD
import re
import sys
from collections import Counter

src, main, out = sys.argv[1:4]
LF = 10
MAXLEN = 250		# the page text in BUFFER (256 bytes)
MAXLINES = 20		# LINES in help.s


def cp850(s):
    return s.encode("cp850")


# ---- entries
entries = []
for line in open(src, encoding="utf-8"):
    line = line.rstrip("\n")
    if line.startswith("#"):
        continue
    if line.startswith("@"):
        entries.append({"title": line[1:], "body": [], "ex": ""})
    elif line.startswith("="):
        entries[-1]["ex"] = line[1:]
    elif entries:
        entries[-1]["body"].append(line)
for e in entries:
    paras, cur = [], []
    for l in e["body"]:
        if l.strip():
            cur.append(l.strip())
        elif cur:
            paras.append(" ".join(cur))
            cur = []
    if cur:
        paras.append(" ".join(cur))
    e["text"] = "\n".join(paras)

# ---- keyword coverage
lines = open(main, encoding="latin-1").read().split("\n")
i = next(n for n, l in enumerate(lines) if l.startswith("KEYWDS:"))
kws = []
while not lines[i].startswith("KEYWDL"):
    m = re.search(r"DEFM\s+'([^']*)'", lines[i])
    if m:
        w = m.group(1).strip().rstrip("(")
        if not re.fullmatch(r"[A-Z$]+", w):
            break			# the error words that follow the keywords
        kws.append(w)
    i += 1
i = next(n for n, l in enumerate(lines) if l.startswith("COMNDS:"))
while "DEFM" in lines[i] or "DEFB" in lines[i] or lines[i].startswith("COMNDS"):
    m = re.search(r"DEFM\s+'([^']*)'", lines[i])
    if m:
        kws.append(m.group(1).strip())
    i += 1
need = set(kws) - {"COLOR"}		# COLOR is COLOUR's other spelling (its entry says so)
have = {e["title"] for e in entries}
missing = sorted(need - have)
if missing:
    sys.exit("help.txt has no entry for: " + " ".join(missing))

# ---- activity keys: the keyword each one types, in panel order (column by column, top to bottom,
# without OFF and the empty place above it), as tokens of the interpreter's table
ACTIVITY = ["PRINT", "INPUT", "IF", "THEN", "ELSE", "FOR", "TO", "STEP", "NEXT", "GOTO",
            "REPEAT", "UNTIL", "WHILE", "ENDWHILE", "GOSUB", "DEF", "PROC", "FN", "ENDPROC", "LOCAL",
            "DIM", "GET", "INKEY", "RND", "INT", "CHR$", "LEFT$(", "MID$(", "LEN", "TAB(",
            "CLS", "RUN", "LIST", "MODE", "RETURN", "SOUND", "REM", "END"]
assert len(ACTIVITY) == 38
toks = {"LIST": 0}			# a command, not a token: kwname writes it itself
k0 = next(n for n, l in enumerate(lines) if l.startswith("KEYWDS:"))
k1 = next(n for n, l in enumerate(lines) if l.startswith("KEYWDL"))
for n in range(k0, k1):
    m = re.search(r"DEFM\s+'([^']*)'", lines[n])
    t = re.search(r"DEFB\s+([0-9A-F]+)H", lines[n - 1])
    if m and t:
        toks.setdefault(m.group(1).strip(), int(t.group(1), 16))
acttok = [toks[k] for k in ACTIVITY]

# ---- order: the pages that are not keywords first (as in help.txt), then the keywords by title
head = [e for e in entries if not re.fullmatch(r"[A-Z$\[]+", e["title"])]
rest = sorted((e for e in entries if e not in head), key=lambda e: e["title"])
entries = head + rest
assert len(entries) < 256


# ---- page layout (the same as hwrap)
def page(e):
    p = cp850(e["title"]) + bytes([LF]) + cp850(e["text"])
    if e["ex"]:
        p += bytes([LF]) + b"e.g. " + cp850(e["ex"])
    return p


def wrap(t):
    res, c = [], 0
    while c != len(t):
        start, d, k = c, None, 0
        while True:
            l = c + k
            if l == len(t):
                end, nxt = l, l
                break
            if t[l] == LF:
                end, nxt = l, l + 1
                break
            if t[l] == 0x20:
                d = l
            k += 1
            if k == 20:
                l = c + 20
                if l == len(t):
                    end, nxt = l, l
                elif t[l] == 0x20 or t[l] == LF:
                    end, nxt = l, l + 1
                elif d is None:
                    end, nxt = l, l
                else:
                    end, nxt = d, d + 1
                break
        res.append(t[start:end])
        c = nxt
    return res


for e in entries:
    p = page(e)
    if len(p) > MAXLEN:
        sys.exit("%s: page of %d characters (at most %d)" % (e["title"], len(p), MAXLEN))
    if len(wrap(p)) > MAXLINES:
        sys.exit("%s: %d lines (at most %d)" % (e["title"], len(wrap(p)), MAXLINES))

# ---- dictionary: greedy, by bytes saved
texts = [[cp850(e["text"])] for e in entries] + [[cp850(e["ex"])] for e in entries]	# pieces and int tokens
dic = []
while len(dic) < 128:
    cnt = Counter()
    for t in texts:
        for piece in t:
            if isinstance(piece, bytes):
                for m in re.finditer(rb"[A-Za-z$]+[ :(]?|[ (][A-Za-z]+|[A-Z]+ [0-9]+[:,]", piece):
                    if len(m.group(0)) >= 3:
                        cnt[m.group(0)] += 1
    best, gain = None, 0
    for w, n in cnt.items():
        g = n * (len(w) - 1) - (len(w) + 1)
        if g > gain:
            best, gain = w, g
    if best is None:
        break
    tok = len(dic)
    dic.append(best)
    for t in texts:
        new = []
        for piece in t:
            if isinstance(piece, bytes):
                parts = piece.split(best)
                for j, part in enumerate(parts):
                    if part:
                        new.append(part)
                    if j < len(parts) - 1:
                        new.append(tok)
            else:
                new.append(piece)
        t[:] = new


def encode(t):
    b = bytearray()
    for piece in t:
        if isinstance(piece, int):
            b.append(0x80 + piece)
        else:
            for c in piece:
                b += bytes([1, c]) if c >= 0x80 else bytes([c])
    return bytes(b)


def asm_bytes(b):
    return "\n".join("\t.db\t" + ",".join("0x%02X" % x for x in b[i:i + 16]) for i in range(0, len(b), 16))


codes = [encode(t) for t in texts]
body, exs = codes[:len(entries)], codes[len(entries):]
for name, orig, b in zip([e["title"] for e in entries] * 2,
                         [cp850(e["text"]) for e in entries] + [cp850(e["ex"]) for e in entries], codes):
    assert 0 not in b
    # decoding gives the text back
    dec, j = bytearray(), 0
    while j < len(b):
        if b[j] >= 0x80:
            dec += dic[b[j] - 0x80]
        elif b[j] == 1:
            j += 1
            dec.append(b[j])
        else:
            dec.append(b[j])
        j += 1
    assert bytes(dec) == orig, name

o = ["; Generated by gen_help.py from %s. Do not edit." % src, "\t.area\tP2",
     "HCOUNT::\t.db\t%d" % len(entries), "HKW::\t.db\t%d\t; first keyword entry" % len(head), "HIDX::"]
o += ["\t.dw\the%d" % n for n in range(len(entries))]
o.append("ACTTOK::\t.db\t" + ",".join("0x%02X" % t for t in acttok))
o.append("HDICT::")
for w in dic:
    o.append("\t.db\t%d\n\t.ascii\t\"%s\"" % (len(w), w.decode()))
for n, (e, b) in enumerate(zip(entries, body)):
    o.append("he%d:\t; %s" % (n, e["title"]))
    o.append(asm_bytes(cp850(e["title"]) + b"\0" + b + b"\0" + exs[n] + b"\0"))
open(out, "w").write("\n".join(o) + "\n")
raw = sum(len(cp850(e["text"]) + cp850(e["ex"])) for e in entries)
size = sum(len(b) for b in codes)
print("help: %d entries, %d keywords covered; texts and examples %d -> %d bytes, dictionary %d pieces (%d bytes)" %
      (len(entries), len(need), raw, size, len(dic), sum(len(w) + 1 for w in dic)))
