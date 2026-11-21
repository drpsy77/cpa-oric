#!/usr/bin/env python3
"""Compacte un programme de GRAPHER (.GRX) : le jumeau de GRXPACK.COM
(progs/grxpack.s), auquel tools/test_grxpack.py le compare octet par octet.
  grxpack.py SOURCE.GRX DEST.GRX     écrit le programme compact
  grxpack.py SOURCE.GRX -l N         ligne de la source qui a donné la ligne N
                                     du programme compact

Ce qui est retiré, et rien d'autre (docs/grapher.md § 13.1) :
  - les commentaires, les lignes vides ou faites d'un commentaire, le retrait ;
  - les espaces de fin de ligne, et ceux qui en suivent un autre ;
  - dans un calcul où GRAPHER les ignore (toute la ligne pour une
    affectation, LET, IF, WHILE, PRINT et PRINTV ; ailleurs entre
    parenthèses), les espaces qui touchent un opérateur, une parenthèse du
    côté intérieur ou une virgule, sauf contre un guillemet.
Ce qui est gardé tel quel : le texte entre guillemets, celui d'ECHO, ECHOV
et GTEXT (un « ; » y est du texte), le « ; » final de PRINT, la casse, les
fins de ligne (CR, LF ou CR LF, comme dans la source). Une tabulation
devient un espace, comme au chargement par GRAPHER ; le texte s'arrête au
premier ^Z (ou au premier octet 0)."""
import sys

OPS = b'+-*/%=<>&|'
AVANT = OPS + b'(,'      # un espace après l'un d'eux est inutile
APRES = OPS + b'),'      # un espace avant l'un d'eux est inutile
TEXTE = (b'ECHO', b'ECHOV')
BRUT = (b'GTEXT',)
PRINT = (b'PRINT', b'PRINTV')
CALCUL = (b'IF', b'WHILE', b'LET')


def lettre(c):
    return 65 <= c <= 90 or 97 <= c <= 122


def ligne(s):
    """Ligne compacte (sans fin de ligne), ou None si elle disparaît."""
    n = len(s)
    i = 0
    while i < n and s[i] == 32:
        i += 1
    if i == n or s[i] == 59:
        return None
    j = i
    while j < n and lettre(s[j]):
        j += 1
    mot = s[i:j]
    cle = mot.upper()
    out = bytearray(mot)
    i = j
    if cle in TEXTE or cle in BRUT:
        k = i
        while k < n and s[k] == 32:
            k += 1
        if k == n:
            return bytes(out)
        if k > i:
            out.append(32)
        if cle in TEXTE and s[k] == 34:      # entre guillemets : la suite est ignorée
            e = s.find(b'"', k + 1)
            out += s[k:] if e < 0 else s[k:e + 1]
        else:
            out += s[k:]
        return bytes(out)
    imprime = cle in PRINT
    force = imprime or cle in CALCUL         # un espace gardé après le mot
    calcul = force or 1 <= len(mot) <= 2     # une ou deux lettres : affectation
    niveau = 0
    guil = False
    premier = True
    while i < n:
        c = s[i]
        if guil:
            out.append(c)
            i += 1
            if c == 34:
                guil = False
            continue
        if c == 59:
            if imprime:                      # « ; » final : pas de passage à la ligne
                k = i + 1
                while k < n and s[k] == 32:
                    k += 1
                if k == n or s[k] == 59:
                    out.append(59)
                    return bytes(out)
            break
        if c == 32:
            while i < n and s[i] == 32:
                i += 1
            if i == n:
                break
            c2 = s[i]
            p = out[-1] if out else 0
            garde = True
            if (calcul or niveau) and not (force and premier):
                if p in AVANT and c2 != 34:
                    garde = False
                elif c2 in APRES and p != 34:
                    garde = False
            if garde:
                out.append(32)
            premier = False
            continue
        premier = False
        if c == 34:
            guil = True
        elif c == 40:
            niveau += 1
        elif c == 41 and niveau:
            niveau -= 1
        out.append(c)
        i += 1
    if not guil:
        while out and out[-1] == 32:
            out.pop()
    return bytes(out)


def texte(data):
    """Le texte s'arrête au premier ^Z (ou au premier octet 0)."""
    for i, c in enumerate(data):
        if c in (0, 26):
            return data[:i]
    return data


def lignes(data):
    """Lignes de la source : (texte sans fin de ligne, fin de ligne)."""
    data = texte(data).replace(b'\t', b' ')
    r = []
    i = 0
    n = len(data)
    while i < n:
        j = i
        while j < n and data[j] not in (13, 10):
            j += 1
        k = j
        if k < n and data[k] == 13:
            k += 1
        if k < n and data[k] == 10:
            k += 1
        r.append((data[i:j], data[j:k]))
        i = k
    return r


def compacte(data):
    """-> (texte compact, numéros des lignes de la source gardées, lignes lues)."""
    out = bytearray()
    nums = []
    src = lignes(data)
    for num, (t, fin) in enumerate(src, 1):
        c = ligne(t)
        if c is not None:
            out += c + fin
            nums.append(num)
    return bytes(out), nums, len(src)


def main():
    if len(sys.argv) not in (3, 4) or (len(sys.argv) == 4) != (sys.argv[2] == '-l'):
        sys.exit(__doc__)
    data = open(sys.argv[1], 'rb').read()
    out, nums, lues = compacte(data)
    if sys.argv[2] == '-l':
        n = int(sys.argv[3])
        if not 1 <= n <= len(nums):
            sys.exit("pas de ligne %d" % n)
        t = lignes(data)[nums[n - 1] - 1][0]
        print("Ligne %d : ligne %d de la source" % (n, nums[n - 1]))
        print(t.decode('latin-1'))
        return
    open(sys.argv[2], 'wb').write(out)
    print("Lu    : %d lignes, %d octets" % (lues, len(texte(data))))
    print("Ecrit : %d lignes, %d octets" % (len(nums), len(out)))


if __name__ == '__main__':
    main()
