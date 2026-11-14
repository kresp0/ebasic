#!/usr/bin/env python3
# Builds the data of the AYUDA guide (help.s) from help.txt.
#   * Checks that every keyword of the interpreter (MAIN.Z80's tables) has an entry.
#   * Compresses the entry texts with a dictionary of up to 128 pieces (bytes 0x80-0xFF);
#     byte 1 escapes a code page 850 character, 10 is a new line.
#   * Lays every page out exactly as hwrap in help.s does and fails if one does not fit.
# Usage: gen_help.py help.txt MAIN.Z80 out/helpdata.s [--sm]   (--sm: the guide of the ebasic-sm image)
# Copyright (C) 2026 Santiago Crespo
# SPDX-License-Identifier: 0BSD
import re
import sys
from collections import Counter

src, main, out = sys.argv[1:4]
SM = "--sm" in sys.argv[4:]	# the guide of the ebasic-sm image
LF = 10
MAXLEN = 250		# the page text in BUFFER (256 bytes)
MAXLINES = 20		# LINES in help.s


def cp850(s):
    return s.encode("cp850")


# ---- entries
entries = []
for line in open(src, encoding="utf-8"):
    line = line.rstrip("\n")
    if line.startswith(("?sm ", "?no ")):
        if line.startswith("?sm ") != SM:
            continue
        line = line[4:]
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

# ---- titles: a keyword's title is its token, and the guide gets the name back from kwname (genio1.s),
# which copies the first name the interpreter's table gives that token
table = []
for n in range(k0, k1 + 1):
    m = re.search(r"DEFM\s+'([^']*)'", lines[n])
    t = re.search(r"DEFB\s+([0-9A-F]+)H", lines[n - 1])
    if m and t:
        table.append((int(t.group(1), 16), m.group(1)))


def kwtitle(name):
    return re.sub(r"[ (]+$", "", name)


first = {}
for t, name in table:
    first.setdefault(t, name)
titletok = {}
for t, name in first.items():
    if t >= 0x80:
        titletok.setdefault(kwtitle(name), t)


def title_bytes(e):
    if e["title"] in titletok:
        return bytes([titletok[e["title"]]])
    b = cp850(e["title"])
    assert 0x20 <= b[0] < 0x80 and 0 not in b
    return b + b"\0"


# ---- byte pair encoding of the texts and examples. Code 2 stands for the entry's title (as the page shows
# it, from the start of BUFFER), which most texts and examples repeat. Any other code stands for two symbols,
# each a character or a code: codes 0x80-0xFF are pairs 0-127, and the control codes 3-31 other than LF are
# pairs 129-157. Byte 1 escapes a code page 850 character (0x80-0xFF), which never takes part in a pair.
TITLE = 2
CODES = list(range(0x80, 0x100)) + [c for c in range(3, 32) if c != LF]


def pairidx(c):
    return c - 0x80 if c >= 0x80 else c + 126


seqs = []
for e in entries:
    t = cp850(e["title"])
    for s in (cp850(e["text"]), cp850(e["ex"])):
        parts = s.split(t) if len(t) > 1 else [s]
        q = []
        for i, p in enumerate(parts):
            q += [("esc", c) if c >= 0x80 else c for c in p] + ([TITLE] if i < len(parts) - 1 else [])
        seqs.append(q)
for s in seqs:
    assert not any(isinstance(c, int) and c < 0x20 and c not in (LF, TITLE) for c in s)
pairs = {}
for code in CODES:
    cnt = Counter()
    for s in seqs:
        for a, b in zip(s, s[1:]):
            if isinstance(a, int) and isinstance(b, int):
                cnt[(a, b)] += 1
    if not cnt:
        break
    best, n = cnt.most_common(1)[0]
    if n < 3:			# a pair costs 2 bytes in the dictionary
        break
    pairs[code] = best
    for k, s in enumerate(seqs):
        o, i = [], 0
        while i < len(s):
            if i + 1 < len(s) and (s[i], s[i + 1]) == best:
                o.append(code)
                i += 2
            else:
                o.append(s[i])
                i += 1
        seqs[k] = o


def encode(s):
    b = bytearray()
    for c in s:
        b += bytes([1, c[1]]) if isinstance(c, tuple) else bytes([c])
    return bytes(b)


def expand(c, title):
    if c == TITLE:
        return title
    return expand(pairs[c][0], title) + expand(pairs[c][1], title) if c in pairs else bytes([c])


def decode(b, title):		# as hdec in help.s
    d, j = bytearray(), 0
    while j < len(b):
        if b[j] == 1:
            d.append(b[j + 1])
            j += 1
        else:
            d += expand(b[j], title)
        j += 1
    return bytes(d)


def asm_bytes(b):
    return "\n".join("\t.db\t" + ",".join("0x%02X" % x for x in b[i:i + 16]) for i in range(0, len(b), 16))


codes = [encode(s) for s in seqs]
body, exs = codes[0::2], codes[1::2]
for e, b, x in zip(entries, body, exs):
    assert 0 not in b and 0 not in x
    t = cp850(e["title"])
    assert decode(b, t) == cp850(e["text"]) and decode(x, t) == cp850(e["ex"]), e["title"]

# ---- the first keyword entry from each letter on (what a letter selects in the index)
letters = []
for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
    n = len(head)
    while n < len(entries) - 1 and entries[n]["title"][0] < c:
        n += 1
    letters.append(n)

npairs = max(pairidx(c) for c in pairs) + 1
dic = bytearray(2 * npairs)
for c, (a, b) in pairs.items():
    dic[2 * pairidx(c):2 * pairidx(c) + 2] = bytes([a, b])
o = ["; Generated by gen_help.py from %s. Do not edit." % src, "\t.area\tP2",
     "HCOUNT::\t.db\t%d" % len(entries), "HKW::\t.db\t%d\t; first keyword entry" % len(head),
     "HLETTER::\t.db\t" + ",".join("%d" % n for n in letters),
     "ACTTOK::\t.db\t" + ",".join("0x%02X" % t for t in acttok),
     "HDICT::", asm_bytes(dic), "he0::"]
data = 0
for n, (e, b, x) in enumerate(zip(entries, body, exs)):
    rec = title_bytes(e) + b + b"\0" + x + b"\0"
    o.append("; %s\n%s" % (e["title"], asm_bytes(rec)))
    data += len(rec)
open(out, "w").write("\n".join(o) + "\n")
raw = sum(len(cp850(e["text"]) + cp850(e["ex"])) for e in entries)
print("help: %d entries (%d titles as tokens), %d keywords covered; texts and examples %d -> %d bytes, "
      "%d pairs; %d bytes with the titles and the dictionary" %
      (len(entries), sum(e["title"] in titletok for e in entries), len(need), raw,
       sum(len(b) for b in codes), len(pairs), data + len(dic)))
