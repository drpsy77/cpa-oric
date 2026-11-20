#!/usr/bin/env python3
"""ATMOS.SYM : table des noms de l'Oric Atmos, au format .SYM d'ASM.

  mksym.py [tools/atmos_sym.txt] build/src/ATMOS.SYM

Entrée : une ligne par nom, « adresse-hexa nom » (étiquette) ou
« adresse-hexa nom = » (constante) ; « # » commente. Sortie (format de
`ASM /S`, lu par DEBUG et DIS) : [longueur du nom][valeur lo][valeur hi]
[genre : bit 0 étiquette][nom] ..., longueur nulle à la fin, dernier
enregistrement de 128 octets complété par des zéros.
Refusés : nom en double, valeur en double, nom qu'ASM prendrait pour un
mnémonique, un registre, ou une étiquette de DIS (Lxxxx)."""
import os
import re
import sys

R = os.path.dirname(os.path.abspath(__file__))
MNEMO = set("ADC AND ASL BCC BCS BEQ BIT BMI BNE BPL BRK BVC BVS CLC CLD CLI CLV CMP "
            "CPX CPY DEC DEX DEY EOR INC INX INY JMP JSR LDA LDX LDY LSR NOP ORA PHA "
            "PHP PLA PLP ROL ROR RTI RTS SBC SEC SED SEI STA STX STY TAX TAY TSX TXA "
            "TXS TYA".split())


def lire(chemin):
    noms, vals, out = set(), set(), []
    for k, l in enumerate(open(chemin, encoding="utf-8"), 1):
        l = l.split("#")[0].split()
        if not l:
            continue
        v, n = int(l[0], 16), l[1]
        cst = len(l) > 2 and l[2] == "="
        if (n in noms or v in vals or n.upper() in MNEMO or n.upper() in ("A", "X", "Y")
                or re.fullmatch(r"L[0-9A-F]{4}", n) or not re.fullmatch(r"[A-Za-z_]\w*", n)
                or len(n) > 31 or not 0 <= v <= 0xFFFF):
            sys.exit("%s:%d : nom refusé (%s)" % (chemin, k, n))
        noms.add(n)
        vals.add(v)
        out.append((v, n, cst))
    return out


def main():
    a = sys.argv[1:]
    if len(a) == 1:
        a = [os.path.join(R, "atmos_sym.txt")] + a
    if len(a) != 2:
        sys.exit(__doc__)
    t = bytearray()
    for v, n, cst in lire(a[0]):
        t += bytes([len(n), v & 255, v >> 8, 0 if cst else 1]) + n.encode()
    t.append(0)
    t += bytes(-len(t) % 128)
    open(a[1], "wb").write(t)
    print("%s : %d noms, %d octets" % (a[1], len(lire(a[0])), len(t)))


if __name__ == "__main__":
    main()
