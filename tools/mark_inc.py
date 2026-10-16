#!/usr/bin/env python3
"""Marque les bibliothèques des programmes traduits (copies de la disquette)
pour que GRXASM n'en recopie que les routines utiles.

  mark_inc.py DOSSIER

Lit dans DOSSIER les copies allégées (tools/strip_inc.py) GRX.INC, ARR.INC,
FIL.INC, SPR.INC, ANIM.INC et HIRES.INC, et les réécrit avec des lignes de
commentaire (ASM et xa les ignorent). Les routines sont numérotées de 1 à
$FFF, à la suite d'un fichier à l'autre, dans cet ordre :

  ;@#NNN     première ligne : la première routine du fichier est NNN+1
  ;@DDDEEE   une routine commence (numéro suivant) ; la ligne qui suit porte
             son étiquette ; DDD, EEE... (3 chiffres hexadécimaux) : les
             routines dont elle a besoin. « ;@* » : toujours gardée (g_init)
  ;@+DDD     suite de la liste (ligne trop longue)
  ;@=NNN     les lignes qui suivent appartiennent à la routine NNN (000 :
             toujours recopiées) : constantes

Une routine va d'une étiquette en colonne 0 (hors bloc .( .)) à la suivante ;
elle a besoin de tout ce que ses instructions et ses données nomment, et de la
suivante si elle ne finit ni par rts, ni par jmp, ni par des données (elle
continue dedans). Une constante qui vaut une étiquette appartient à la routine
de cette étiquette (« a_fail = g_stop » : GRXASM la reconnaît comme un nom de
g_stop) ; les autres sont toujours recopiées."""
import os
import re
import sys

ORDRE = ["GRX.INC", "ARR.INC", "FIL.INC", "SPR.INC", "ANIM.INC", "HIRES.INC"]
TOUJOURS = {"g_init"}
MNEM = set("adc and asl bcc bcs beq bit bmi bne bpl brk bvc bvs clc cld cli clv cmp "
           "cpx cpy dec dex dey eor inc inx iny jmp jsr lda ldx ldy lsr nop ora pha "
           "php pla plp rol ror rti rts sbc sec sed sei sta stx sty tax tay tsx txa "
           "txs tya".split())
ID = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
LMAX = 100   # longueur d'une ligne ;@ (ASM lit des lignes plus longues)


def idents(s):
    s = re.sub(r'"[^"]*"|\'[^\']*\'', " ", s)
    return set(ID.findall(s))


def analyse(fichiers):
    """-> lignes par fichier [(texte, nom_de_bloc ou None, equate)], blocs, constantes"""
    blocs = []          # dicts : nom, fichier, refs, fin
    equ = {}            # nom -> identifiants de la valeur
    lignes = {}
    for f, texte in fichiers:
        prof = 0
        cour = None
        res = []
        for l in texte.split("\n"):
            if l.startswith(";@"):
                continue                    # déjà marqué : on refait
            t = l.split()
            proprio = cour
            eq = None
            m = re.match(r"^([A-Za-z_]\w*)\s*=\s*(.*)$", l)
            if m and prof == 0:
                equ[m.group(1)] = idents(m.group(2))
                eq = m.group(1)
                proprio = None
            elif l and l[0] not in " \t.;" and prof == 0:
                m = re.match(r"^([A-Za-z_]\w*)(.*)$", l)
                if m and m.group(1).lower() not in MNEM:
                    cour = {"nom": m.group(1), "fichier": f, "refs": set(), "fin": None}
                    blocs.append(cour)
                    proprio = cour
            if proprio is not None and not l.startswith(";"):
                corps = l
                if l and l[0] not in " \t.":
                    corps = re.sub(r"^[A-Za-z_]\w*", "", l)
                tk = corps.split()
                if tk:
                    op = tk[0].lower()
                    if op in MNEM:
                        proprio["fin"] = op
                        proprio["refs"] |= idents(" ".join(tk[1:]))
                    elif op.startswith(".") and op not in (".(", ".)"):
                        proprio["refs"] |= idents(" ".join(tk[1:]))
                        proprio["fin"] = "data"
                    elif "=" in corps:      # constante locale d'un bloc
                        proprio["refs"] |= idents(corps.split("=", 1)[1])
            res.append((l, proprio, eq))
            if ".(" in t:
                prof += 1
            if ".)" in t:
                prof -= 1
        lignes[f] = res
    return lignes, blocs, equ


def main(dossier):
    fichiers = []
    for f in ORDRE:
        p = os.path.join(dossier, f)
        fichiers.append((f, open(p, encoding="latin-1").read().rstrip("\n")))
    lignes, blocs, equ = analyse(fichiers)
    num = {}
    for i, b in enumerate(blocs):
        b["n"] = i + 1
        if b["nom"] in num:
            sys.exit("mark_inc : étiquette en double : " + b["nom"])
        num[b["nom"]] = b
    if len(blocs) > 0x3FF:   # KMAXR de GRXASM
        sys.exit("mark_inc : trop de routines")

    def resout(nom, vus=None):
        """blocs désignés par un nom (étiquette, ou constante qui en vaut)"""
        if nom in num:
            return [num[nom]]
        if nom in equ:
            vus = vus or set()
            if nom in vus:
                return []
            vus.add(nom)
            r = []
            for i in sorted(equ[nom]):
                r += resout(i, vus)
            return r
        return []

    noms = {b["n"]: [b["nom"]] for b in blocs}
    proprio_eq = {}
    for e in equ:
        r = resout(e)
        if r:
            proprio_eq[e] = r[0]
            noms[r[0]["n"]].append(e)
            r[0]["refs"].add(e)          # (les autres blocs nommés)
    for i, b in enumerate(blocs):
        d = set()
        for r in b["refs"]:
            for x in resout(r):
                if x is not b:
                    d.add(x["n"])
        if b["fin"] not in ("rts", "jmp", "rti", "data") and i + 1 < len(blocs) \
                and blocs[i + 1]["fichier"] == b["fichier"]:
            d.add(blocs[i + 1]["n"])     # continue dans la suivante
        b["deps"] = sorted(d)
    total = 0
    for f, _ in fichiers:
        mes = [b for b in blocs if b["fichier"] == f]
        corps = [";@#%03X" % (mes[0]["n"] - 1)]
        cour = 0
        partis = set()
        for l, proprio, eq in lignes[f]:
            if eq is not None:
                p = proprio_eq[eq]["n"] if eq in proprio_eq else 0
            else:
                p = proprio["n"] if proprio else 0
            if proprio is not None and eq is None and p not in partis:
                partis.add(p)             # première ligne : l'étiquette
                m = ";@" + ("*" if proprio["nom"] in TOUJOURS else "")
                for dd in proprio["deps"]:
                    if len(m) + 3 > LMAX:
                        corps.append(m)
                        m = ";@+"
                    m += "%03X" % dd
                corps.append(m)
                cour = p
            elif p != cour:
                corps.append(";@=%03X" % p)
                cour = p
            corps.append(l)
        data = ("\n".join(corps) + "\n").encode("latin-1")
        open(os.path.join(dossier, f), "wb").write(data)
        total += len(data)
    return len(blocs), total


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    n, t = main(sys.argv[1])
    print("bibliothèques marquées : %d routines, %d octets" % (n, t))
