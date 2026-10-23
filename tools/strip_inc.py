#!/usr/bin/env python3
"""Copie allégée d'une bibliothèque .inc pour la disquette.

  strip_inc.py SOURCE DESTINATION [DOSSIER_MSG | -]

Retire les commentaires et les lignes vides, réduit chaque suite
d'espaces ou de TAB à un seul espace (hors chaînes et caractères entre
guillemets ou apostrophes) ; une instruction garde un espace devant elle,
une étiquette reste en colonne 0. ASM.COM et xa assemblent la copie comme
l'original (vérifié par tools/test_inc.sh). La documentation reste dans
les sources du dépôt (progs/*.inc) : la copie commence par une ligne qui
le dit. Fin de ligne : LF, comme les sources.

Une ligne « ;#msg NOM.msg » de la bibliothèque est remplacée par la copie
allégée de DOSSIER_MSG/NOM.msg (par défaut msg/fr à côté de SOURCE ;
msg/en pour la disquette anglaise) : la copie de la disquette porte ses
messages, que les programmes de progs/ incluent à part (ASM n'a qu'un
niveau d'inclusion). « - » : marques retirées sans les messages."""
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


def main(src, dst, msgdir=None):
    if msgdir is None:
        msgdir = os.path.join(os.path.dirname(src) or ".", "msg", "fr")
    lines = open(src, encoding="latin-1").read().splitlines()
    name = os.path.basename(dst).upper()
    res = ["; %s : version allegee, documentation dans les sources de CP/A" % name]
    for l in lines:
        if l.startswith(";#msg "):
            if msgdir != "-":
                m = os.path.join(msgdir, l.split()[1])
                for ml in open(m, encoding="latin-1").read().splitlines():
                    s = strip_line(ml)
                    if s:
                        res.append(s)
            continue
        s = strip_line(l)
        if s:
            res.append(s)
    data = ("\n".join(res) + "\n").encode("latin-1")
    open(dst, "wb").write(data)
    return len(data)


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    n = main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) == 4 else None)
    print("%s : %d -> %d octets" % (os.path.basename(sys.argv[2]), os.path.getsize(sys.argv[1]), n))
