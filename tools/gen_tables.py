#!/usr/bin/env python3
"""Génère les tables du système :
  src/tables.s     tables du mode SPLIT (adresses des lignes de points, colonne et
                   masque de chaque x), dans la zone du code ;
  src/tables_ff.s  adresses des lignes de l'écran texte et tables du clavier,
                   placées dans la page $FF00 (voir src/cpa.s).
Usage : gen_tables.py [src/tables.s]  (tables_ff.s est écrit à côté)"""
import sys

SCREEN = 0xBB80

# Matrice clavier Atmos : index = ligne*8 + colonne
# (colonne c sélectionnée en écrivant ~(1<<c) dans le registre 14 de l'AY).
# 0 = pas de caractère (modificateurs, touches absentes).
ESC, DEL, CR = 0x1B, 0x7F, 0x0D
LEFT, RIGHT, DOWN, UP = 0x08, 0x09, 0x0A, 0x0B

NORM = [
    '7', 'n', '5', 'v', 0, '1', 'x', '3',
    'j', 't', 'r', 'f', 0, ESC, 'q', 'd',
    'm', '6', 'b', '4', 0, 'z', '2', 'c',
    'k', '9', ';', '-', 0, 0, '\\', "'",
    ' ', ',', '.', UP, 0, LEFT, DOWN, RIGHT,
    'u', 'i', 'o', 'p', 0, DEL, ']', '[',
    'y', 'h', 'g', 'e', 0, 'a', 's', 'w',
    '8', 'l', '0', '/', 0, CR, 0, '=',
]
SHIFT = [
    '&', 'N', '%', 'V', 0, '!', 'X', '#',
    'J', 'T', 'R', 'F', 0, ESC, 'Q', 'D',
    'M', '^', 'B', '$', 0, 'Z', '@', 'C',
    'K', '(', ':', '_', 0, 0, '|', '"',
    ' ', '<', '>', UP, 0, LEFT, DOWN, RIGHT,
    'U', 'I', 'O', 'P', 0, DEL, '}', '{',
    'Y', 'H', 'G', 'E', 0, 'A', 'S', 'W',
    '*', 'L', ')', '?', 0, CR, 0, '+',
]

def val(x):
    return ord(x) if isinstance(x, str) else x

def table(name, data):
    out = [name]
    for i in range(0, len(data), 8):
        out.append("        .byt " + ",".join("$%02X" % val(v) for v in data[i:i+8]))
    return out

def main(path):
    assert len(NORM) == 64 and len(SHIFT) == 64
    HEAD = ["; Généré par tools/gen_tables.py — ne pas éditer à la main", ""]
    F = list(HEAD)
    F.append("line_lo")
    F.append("        .byt " + ",".join("$%02X" % ((SCREEN + 40*r) & 0xFF) for r in range(28)))
    F.append("line_hi")
    F.append("        .byt " + ",".join("$%02X" % ((SCREEN + 40*r) >> 8) for r in range(28)))
    F.append("")
    F += table("keymap_norm", NORM)
    F += table("keymap_shift", SHIFT)
    L = list(HEAD)
    # mode SPLIT : adresse de chaque ligne de points, colonne et masque de chaque x
    L.append("")
    L.append("g_ylo")
    for r in range(0, 128, 16):
        L.append("        .byt " + ",".join("$%02X" % ((0xA000 + 40*y) & 0xFF) for y in range(r, r+16)))
    L.append("g_yhi")
    for r in range(0, 128, 16):
        L.append("        .byt " + ",".join("$%02X" % ((0xA000 + 40*y) >> 8) for y in range(r, r+16)))
    L.append("g_xcol")
    for r in range(0, 240, 20):
        L.append("        .byt " + ",".join("%d" % (x // 6) for x in range(r, r+20)))
    L.append("g_xbit")
    for r in range(0, 240, 20):
        L.append("        .byt " + ",".join("$%02X" % (0x20 >> (x % 6)) for x in range(r, r+20)))
    open(path, "w").write("\n".join(L) + "\n")
    open(path.replace("tables.s", "tables_ff.s"), "w").write("\n".join(F) + "\n")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "src/tables.s")
