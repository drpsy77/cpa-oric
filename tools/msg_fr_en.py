#!/usr/bin/env python3
"""Traduit en anglais une sortie attendue écrite en français, par les
fichiers de messages des programmes (progs/msg/fr, progs/msg/en).

  msg_fr_en.py FICHIER [nom.msg ...]

Chaque chaîne entre guillemets d'une étiquette du fichier français est
associée à la chaîne de même rang de la même étiquette du fichier anglais ;
dans FICHIER, chaque chaîne française (3 caractères au moins, la plus
longue d'abord) est remplacée par sa traduction, et le résultat est écrit
sur la sortie. Sert à comparer la sortie des programmes anglais aux
références françaises (tools/test_grapher.sh, LANGUE=en) sans doubler les
références. Sans nom de fichier .msg : ceux de GRAPHER et de GRXASM."""
import os
import re
import sys

MSG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "progs", "msg")
DEFAUT = ["grxc.msg", "grapher.msg", "grxasm.msg", "grx.msg", "arr.msg",
          "fil.msg", "spr.msg", "anim.msg"]


def chaines(chemin):
    """-> {étiquette: [chaînes entre guillemets, dans l'ordre]}"""
    res = {}
    cour = None
    for l in open(chemin, encoding="utf-8"):
        if l.startswith(";"):
            continue
        m = re.match(r"^([A-Za-z_]\w*)", l)
        if m:
            cour = m.group(1)
            res.setdefault(cour, [])
        if cour is not None:
            code = re.match(r'^((?:[^;"]|"[^"]*")*)', l).group(1)   # sans commentaire
            res[cour] += re.findall(r'"([^"]*)"', code)
    return res


def table(noms):
    t = {}
    for n in noms:
        fr = chaines(os.path.join(MSG, "fr", n))
        en = chaines(os.path.join(MSG, "en", n))
        for e, lf in fr.items():
            le = en.get(e)
            if le is None or len(le) != len(lf):
                sys.exit("msg_fr_en : %s, %s : chaînes différentes" % (n, e))
            for a, b in zip(lf, le):
                if len(a) >= 3 and a != b:
                    if t.get(a, b) != b:
                        sys.exit("msg_fr_en : « %s » a deux traductions" % a)
                    t[a] = b
    return t


def main(fichier, noms):
    t = table(noms or DEFAUT)
    texte = open(fichier, encoding="latin-1").read()
    cles = sorted(t, key=len, reverse=True)
    motif = re.compile("|".join(re.escape(c) for c in cles))
    sys.stdout.write(motif.sub(lambda m: t[m.group(0)], texte))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2:])
