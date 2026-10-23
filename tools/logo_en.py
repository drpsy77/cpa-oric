#!/usr/bin/env python3
"""Traduit en anglais les primitives LOGO d'un texte tapé (scénarios de
tools/test_logo.sh, LANGUE=en), d'après le vocabulaire de
tools/gen_logo_voc.py.

  logo_en.py TEXTE      écrit TEXTE traduit sur la sortie

Un mot (lettres, ?) est traduit s'il est une primitive française ; les mots
après " ou : (noms, variables) ne le sont pas. La casse suit l'original
(minuscules si le mot l'était). LISTE devient LIST (les scénarios ne s'en
servent pas comme instruction)."""
import re
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_logo_voc as V

T = {}
for r in V.VOC:
    fr, en = V.noms(r, 0), V.noms(r, 1)
    for k, n in enumerate(fr):
        T.setdefault(n, en[k] if k < len(en) else en[0])
T["LISTE"] = "LIST"
T[V.FIN[0]] = V.FIN[1]


def traduit(s):
    def mot(m):
        avant, w = m.group(1), m.group(2)
        if avant in ('"', ":"):
            return avant + w
        e = T.get(w.upper())
        if e is None:
            return avant + w
        return avant + (e.lower() if w.islower() else e)
    return re.sub(r'(^|[^A-Za-z?"]|"|:)([A-Za-z][A-Za-z?]*)', mot, s)


if __name__ == "__main__":
    sys.stdout.write(traduit(sys.argv[1]))
