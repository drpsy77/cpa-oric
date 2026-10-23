#!/usr/bin/env python3
"""Fichiers d'une disquette anglaise, d'après ceux de la française.

  en_files.py FICHIER...     écrit les arguments de mkdisk.py new (sur une
                             ligne) pour la version anglaise des FICHIERs
                             (--ro, --rw, --sys, --dir passent tels quels)
  en_files.py --verifie      contrôle la table files/en/noms.txt
  en_files.py --jumelles FR.dsk EN.dsk
                             contrôle qu'une disquette anglaise a les fichiers
                             de la française (noms traduits), mêmes attributs

  build/progs/X.COM  -> build/progs-en/X.COM (messages anglais)
  build/src/X.INC    -> build/src-en/X.INC (bibliothèques, messages anglais)
  files/..., build/src/X.ASM (exemples) -> d'après files/en/noms.txt :
                        files/en/<nom anglais en minuscules>=NOM.EXT, ou le
                        fichier français s'il n'y a rien à traduire (images,
                        sprites, animations)
Un exemple absent de la table, ou un texte (.GRX .LOG .BAT .ASM .TXT .CFG)
sans traduction, arrête tout : chaque exemple a sa version anglaise."""
import os
import sys

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
TABLE = os.path.join(RACINE, "files", "en", "noms.txt")
TEXTES = {"GRX", "LOG", "BAT", "ASM", "TXT", "CFG"}


def table():
    t = {}
    for l in open(TABLE, encoding="utf-8"):
        l = l.split("#")[0].split()
        if l:
            fr, en = l
            if fr in t or en.upper() in (e.upper() for e in t.values()):
                sys.exit("noms.txt : %s ou %s en double" % (fr, en))
            t[fr] = en
    return t


def anglais(f, t):
    if f.startswith("--"):                  # --ro, --sys... : tels quels
        return f
    if f.startswith("build/progs/"):
        return "build/progs-en/" + f[len("build/progs/"):]
    if f.startswith("build/src/") and f.endswith(".INC"):
        return "build/src-en/" + f[len("build/src/"):]
    if f not in t:
        sys.exit("en_files : %s n'a pas de nom anglais (files/en/noms.txt)" % f)
    en = t[f]
    tr = "files/en/" + en.lower()
    if os.path.exists(os.path.join(RACINE, tr)):
        return "%s=%s" % (tr, en)
    if en.rpartition(".")[2].upper() in TEXTES:
        sys.exit("en_files : %s (%s) n'est pas traduit dans files/en" % (f, en))
    return "%s=%s" % (f, en)


def verifie(t):
    ok = True
    for fr, en in t.items():
        if fr.startswith("files/") and not os.path.exists(os.path.join(RACINE, fr)):
            print("absent :", fr); ok = False
        if len(en.partition(".")[0]) > 8 or len(en.partition(".")[2]) > 3:
            print("pas en 8.3 :", en); ok = False
        if en.rpartition(".")[2].upper() in TEXTES and \
                not os.path.exists(os.path.join(RACINE, "files/en", en.lower())):
            print("pas traduit :", fr, "->", en); ok = False
    connus = {en.lower() for en in t.values()} | {"noms.txt"}
    for f in os.listdir(os.path.join(RACINE, "files", "en")):
        if f not in connus:
            print("dans files/en mais pas dans la table :", f); ok = False
    print("noms.txt : %d exemples, %s" % (len(t), "correspondance complète" if ok else "A CORRIGER"))
    return ok


def jumelles(fr, en, t):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import mkdisk

    def liste(img):                 # NOM.EXT -> (R/O, SYS)
        return {mkdisk.nom_lisible(n): a for n, a in mkdisk.Disk.load(img).attrs().items()}
    noms = {os.path.basename(f).upper(): e.upper() for f, e in t.items()}
    lf, le = liste(fr), liste(en)
    attendus = {noms.get(n, n): a for n, a in lf.items()}
    ok = True
    for n in sorted(set(attendus) | set(le)):
        if attendus.get(n) != le.get(n):
            print("  %s : %s sur la française, %s sur l'anglaise" % (n, attendus.get(n, "absent"), le.get(n, "absent")))
            ok = False
    print("%s = %s : %d fichiers%s" % (os.path.basename(fr), os.path.basename(en), len(lf), "" if ok else ", A CORRIGER"))
    return ok


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    t = table()
    if sys.argv[1] == "--verifie":
        sys.exit(0 if verifie(t) else 1)
    if sys.argv[1] == "--jumelles":
        sys.exit(0 if jumelles(sys.argv[2], sys.argv[3], t) else 1)
    print(" ".join(anglais(f, t) for f in sys.argv[1:]))
