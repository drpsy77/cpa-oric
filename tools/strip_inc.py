#!/usr/bin/env python3
"""Copie allégée d'une bibliothèque .inc pour la disquette.

  strip_inc.py SOURCE DESTINATION

Retire les commentaires et les lignes vides, réduit chaque suite
d'espaces ou de TAB à un seul espace (hors chaînes et caractères entre
guillemets ou apostrophes) ; une instruction garde un espace devant elle,
une étiquette reste en colonne 0. ASM.COM et xa assemblent la copie comme
l'original (vérifié par tools/test_inc.sh). La documentation reste dans
les sources du dépôt (progs/*.inc) : la copie commence par une ligne qui
le dit. Fin de ligne : LF, comme les sources."""
import os
import sys


def strip_line(line):
    out = []
    quote = None
    space = False
    for i, c in enumerate(line):
        if quote:
            out.append(c)
            if c == quote:
                quote = None
            continue
        if c == ";":
            break
        if c in " \t":
            space = True
            continue
        if space:
            out.append(" ")
            space = False
        if c in "\"'":
            quote = c
        out.append(c)
    return "".join(out).rstrip()


def main(src, dst):
    lines = open(src, encoding="latin-1").read().splitlines()
    name = os.path.basename(dst).upper()
    res = ["; %s : version allegee, documentation dans les sources de CP/A" % name]
    for l in lines:
        s = strip_line(l)
        if s:
            res.append(s)
    data = ("\n".join(res) + "\n").encode("latin-1")
    open(dst, "wb").write(data)
    return len(data)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    n = main(sys.argv[1], sys.argv[2])
    print("%s : %d -> %d octets" % (os.path.basename(sys.argv[2]), os.path.getsize(sys.argv[1]), n))
