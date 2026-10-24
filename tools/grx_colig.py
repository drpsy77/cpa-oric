#!/usr/bin/env python3
"""Passe un programme GRAPHER (.GRX) de l'ancienne notation des tableaux à
deux dimensions, (ligne, colonne) comme en C, à la notation de l'Oric,
(colonne, ligne) : DIM T$(28,38) devient DIM T$(38,28), M$(L,C) devient
M$(C,L), PASTE T$(CY,CX) ... devient PASTE T$(CX,CY) ... Le programme fait
exactement la même chose (même mémoire, mêmes fichiers) : seuls les deux
indices de chaque tableau sont échangés.

  python3 tools/grx_colig.py FICHIER.GRX [...]      réécrit les fichiers
  python3 tools/grx_colig.py --voir FICHIER.GRX     montre sans écrire

Un tableau est une lettre seule (A à Z, éventuellement suivie de $) suivie
d'une parenthèse ; les fonctions (TILE, POINT, SCRN, RND...) ont un nom de
plusieurs lettres et ne sont pas touchées. Les textes entre guillemets et les
commentaires (après ;) ne sont pas changés : les lignes de commentaire qui
semblent citer un tableau à deux indices sont signalées, à revoir à la main.
À ne passer qu'une fois sur un fichier (une seconde fois remet l'ancien
ordre). Sur l'Oric : EXPORT du fichier, conversion sur le PC, IMPORT.
"""
import re
import sys


def ref_end(s, i):
    """s[i] = '(' : indice de la ')' correspondante, et les positions des
    virgules de premier niveau (None si pas de fin)."""
    d = 0
    virg = []
    q = False
    for k in range(i, len(s)):
        c = s[k]
        if q:
            if c == '"':
                q = False
            continue
        if c == '"':
            q = True
        elif c == '(':
            d += 1
        elif c == ')':
            d -= 1
            if d == 0:
                return k, virg
        elif c == ',' and d == 1:
            virg.append(k)
    return None, None


def convertit(code):
    """Partie code d'une ligne (sans commentaire) : indices échangés."""
    out = []
    i = 0
    n = len(code)
    while i < n:
        c = code[i]
        if c == '"':                        # texte : recopié tel quel
            j = code.find('"', i + 1)
            j = n if j < 0 else j + 1
            out.append(code[i:j])
            i = j
            continue
        if c.isalpha() and (i == 0 or not (code[i - 1].isalnum() or code[i - 1] == '_')):
            j = i + 1
            if j < n and code[j] == '$':
                j += 1
            if j < n and code[j] == '(' and (j == i + 1 or code[i + 1] == '$') \
                    and not (i + 1 < n and code[i + 1].isalpha()):
                fin, virg = ref_end(code, j)
                if fin is not None and len(virg) == 1:
                    a = code[j + 1:virg[0]]
                    b = code[virg[0] + 1:fin]
                    a2, b2 = convertit(a), convertit(b)
                    out.append(code[i:j] + "(" + b2.strip() + "," + a2.strip() + ")")
                    i = fin + 1
                    continue
                if fin is not None:
                    out.append(code[i:j] + "(" + convertit(code[j + 1:fin]) + ")")
                    i = fin + 1
                    continue
        out.append(c)
        i += 1
    return "".join(out)


def coupe(ligne):
    """(code, commentaire) : le commentaire commence au premier ; hors texte."""
    q = False
    for k, c in enumerate(ligne):
        if c == '"':
            q = not q
        elif c == ';' and not q:
            return ligne[:k], ligne[k:]
    return ligne, ""


SUSPECT = re.compile(r'(?<![A-Za-z0-9_])[A-Za-z]\$?\([^()]*,[^()]*\)')


def traite(texte, nom, signale):
    lignes = texte.split("\n")
    res = []
    for no, l in enumerate(lignes, 1):
        code, com = coupe(l)
        res.append(convertit(code) + com)
        if com and SUSPECT.search(com):
            signale.append("%s:%d: commentaire à revoir : %s" % (nom, no, com.strip()))
    return "\n".join(res)


def main():
    voir = "--voir" in sys.argv
    fichiers = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not fichiers:
        print(__doc__)
        return 1
    signale = []
    for f in fichiers:
        brut = open(f, "rb").read()
        texte = brut.decode("latin-1")
        neuf = traite(texte, f, signale)
        if neuf != texte:
            if voir:
                for a, b in zip(texte.split("\n"), neuf.split("\n")):
                    if a != b:
                        print("%s\n  - %s\n  + %s" % (f, a.rstrip(), b.rstrip()))
            else:
                open(f, "wb").write(neuf.encode("latin-1"))
                print("converti : %s" % f)
    for s in signale:
        print(s)
    return 0


if __name__ == "__main__":
    sys.exit(main())
