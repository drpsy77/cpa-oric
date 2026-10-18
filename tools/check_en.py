#!/usr/bin/env python3
"""Vérifie que les documents traduits (docs/en/) suivent les originaux (docs/) :
mêmes titres de section (nombre et niveau), même nombre de lignes de tableau
et de blocs de code (lignes en retrait de 4 espaces après une ligne vide). Une traduction en retard est signalée (code 1).

  python3 tools/check_en.py
"""
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = ["manuel.md", "logo.md", "grapher.md", "cmder.md"]


def forme(p):
    titres, tables, code = [], 0, 0
    bloc = False
    avant = ""
    for l in open(p, encoding="utf-8"):
        vide, avant = not avant.strip(), l
        if l.startswith("```"):
            bloc = not bloc
            continue
        if bloc:
            continue
        m = re.match(r"^(#+) ", l)
        if m:
            titres.append(len(m.group(1)))
        elif l.startswith("|"):
            tables += 1
        elif l.startswith("    ") and l.strip() and vide:
            code += 1
    return titres, tables, code


def main():
    ok = True
    for n in DOCS:
        fr = os.path.join(RACINE, "docs", n)
        en = os.path.join(RACINE, "docs", "en", n)
        if not os.path.exists(en):
            print("%s : pas de traduction" % n)
            ok = False
            continue
        a, b = forme(fr), forme(en)
        diffs = []
        if a[0] != b[0]:
            diffs.append("titres %d / %d" % (len(a[0]), len(b[0])))
        if a[1] != b[1]:
            diffs.append("lignes de tableau %d / %d" % (a[1], b[1]))
        if a[2] != b[2]:
            diffs.append("blocs de code %d / %d" % (a[2], b[2]))
        print("%s : %s" % (n, ", ".join(diffs) if diffs else "OK"))
        ok = ok and not diffs
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
