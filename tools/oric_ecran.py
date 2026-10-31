#!/usr/bin/env python3
"""Écran texte de l'Oric hors de l'Oric : police de CP/A et règles de l'ULA.

Partagé par la console à distance (docs/console-distance.md) : le client
tkinter (tools/remote_tk.py), le faux démon d'essai (tools/faux_demon.py),
et plus tard le démon tools/remote.py (police de la page web).
Python 3, bibliothèque standard seulement.

    python3 tools/oric_ecran.py VIDAGE.mem SORTIE.png [--echelle N]
        dessine l'écran d'un vidage de tools/run_test.sh (comparaison avec
        la capture d'Oricutron)

Une ligne d'écran = 40 octets tels qu'en $BB80 (attributs et bit 7 compris).
Le rendu donne pour chaque ligne 8 rangées de 240 points, chaque point étant
une couleur de l'Oric (0 noir ... 7 blanc).
"""
import os
import re
import struct
import sys
import zlib

COLS, ROWS = 40, 28
LARG, HAUT = COLS * 6, ROWS * 8          # 240 x 224 points
SCREEN = 0xBB80

# Couleurs de l'Oric (bit 0 rouge, bit 1 vert, bit 2 bleu)
RVB = [(0, 0, 0), (255, 0, 0), (0, 255, 0), (255, 255, 0),
       (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)]
HEX = ["#%02x%02x%02x" % c for c in RVB]

DEPOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def charger_police(chemin=None):
    """Police de CP/A lue dans src/font.s (5 octets par caractère, codes 32 à
    127), dépliée comme font_init : 8 rangées de 6 points par caractère
    (bit 5 = point de gauche). Rend une liste de 128 glyphes ; codes 0-31 vides."""
    chemin = chemin or os.path.join(DEPOT, "src", "font.s")
    octets = []
    for ligne in open(chemin, encoding="utf-8"):
        m = re.match(r"\s*\.byt\s+([^;]+)", ligne)
        if m:
            octets += [int(v.strip().lstrip("$"), 16) for v in m.group(1).split(",")]
    if len(octets) != 96 * 5:
        raise ValueError("%s : %d octets au lieu de 480" % (chemin, len(octets)))
    police = [[0] * 8 for _ in range(32)]
    for c in range(96):
        bits = 0
        for o in octets[5 * c:5 * c + 5]:
            bits = (bits << 8) | o
        police.append([((bits >> (35 - 5 * r)) & 0x1F) << 1 for r in range(8)])
    return police


def rendre_ligne(police, octets, num, clign_eteint=False):
    """Les 8 rangées de 240 points d'une ligne d'écran, selon l'ULA (mode texte).

    Chaque ligne repart en encre 7, papier 0, sans attribut. Un octet de code
    0-31 (bit 7 ôté) est un attribut : 0-7 encre, 8-15 jeu de caractères
    (bit 0 double hauteur, bit 1 jeu secondaire, bit 2 clignotement), 16-23
    papier, 24-31 mode vidéo (sans effet ici) ; sa case est dessinée en papier.
    Bit 7 : vidéo inverse (encre et papier complémentés). Le jeu secondaire
    (en $B800, que CP/A n'initialise pas) est dessiné avec la police normale.
    num : numéro de la ligne (sa parité choisit la moitié en double hauteur)."""
    encre, papier, double, clign = 7, 0, False, False
    rangs = [[0] * LARG for _ in range(8)]
    for col in range(COLS):
        b = octets[col]
        c = b & 0x7F
        inv = 7 if b & 0x80 else 0
        if c < 32:
            if c < 8:
                encre = c
            elif c < 16:
                double, clign = bool(c & 1), bool(c & 4)
            elif c < 24:
                papier = c - 16
            fond = papier ^ inv
            for r in range(8):
                rangs[r][col * 6:col * 6 + 6] = [fond] * 6
            continue
        av, fond = encre ^ inv, papier ^ inv
        if clign and clign_eteint:
            av = fond
        g = police[c]
        for r in range(8):
            v = g[((r + 8 * (num & 1)) >> 1)] if double else g[r]
            rang = rangs[r]
            x = col * 6
            for k in range(6):
                rang[x + k] = av if v & (0x20 >> k) else fond
    return rangs


def ligne_a_clignotement(octets):
    """Vrai si un attribut de clignotement est actif sur la ligne."""
    return any(8 <= (b & 0x7F) < 16 and (b & 4) for b in octets)


def ecran_depuis_vidage(mem):
    """État de l'écran d'un vidage de 64 Ko (tools/run_test.sh), sous la forme
    de la trame S du pilote : mode, curseur, 28 lignes ; la case du curseur
    est rétablie si le clignotement l'a inversée (cur_vis), comme le pilote
    le fait."""
    lignes = [bytearray(mem[SCREEN + 40 * n:SCREEN + 40 * n + 40]) for n in range(ROWS)]
    cx, cy, vis, actif = mem[0x210], mem[0x211], mem[0x212], mem[0x213]
    if vis and cy < ROWS and cx < COLS:
        lignes[cy][cx] ^= 0x80
    mode = 1 if mem[0x280] == 1 else 0
    if mode == 0 and 28 <= (lignes[27][39] & 0x7F) < 32:
        mode = 2
    if mem[0x20E] == 1:
        mode |= 0x80
    return {"mode": mode, "curseur": [cx, cy, bool(actif)], "lignes": [bytes(l) for l in lignes]}


def ascii_oric(texte):
    """Texte collé -> codes de touches de l'Oric, comme XFER /T : accents et
    cédille retirés, œ -> oe, æ -> ae, fins de ligne en CR (13), tabulation
    -> 29 (TAB du contrat) ; le reste hors de 32-126 est ignoré."""
    import unicodedata
    texte = texte.replace("\r\n", "\r").replace("\n", "\r")
    for a, b in (("œ", "oe"), ("Œ", "OE"), ("æ", "ae"), ("Æ", "AE"), ("’", "'"),
                 ("«", '"'), ("»", '"'), ("–", "-"), ("—", "-"), ("…", "..."), (" ", " ")):
        texte = texte.replace(a, b)
    codes = bytearray()
    for ch in unicodedata.normalize("NFKD", texte):
        o = ord(ch)
        if 32 <= o < 127 or o == 13:
            codes.append(o)
        elif ch == "\t":
            codes.append(29)
    return bytes(codes)


def png(chemin, rangs, echelle=1):
    """Écrit une image PNG (sans bibliothèque) : rangs = rangées d'indices de couleur."""
    brut = bytearray()
    for rang in rangs:
        ligne = bytearray([0])
        for p in rang:
            ligne += bytes(RVB[p]) * echelle
        brut += bytes(ligne) * echelle
    larg, haut = len(rangs[0]) * echelle, len(rangs) * echelle

    def bloc(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(chemin, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(bloc(b"IHDR", struct.pack(">IIBBBBB", larg, haut, 8, 2, 0, 0, 0)))
        f.write(bloc(b"IDAT", zlib.compress(bytes(brut), 6)))
        f.write(bloc(b"IEND", b""))


def rangs_ecran(police, lignes, curseur=None, clign_eteint=False):
    """Les 224 rangées d'un écran entier ; curseur = (cx, cy) dessiné inversé."""
    rangs = []
    for n, l in enumerate(lignes):
        if curseur and curseur[1] == n and curseur[0] < COLS:
            l = bytearray(l)
            l[curseur[0]] ^= 0x80
        rangs += rendre_ligne(police, l, n, clign_eteint)
    return rangs


def main(args):
    if len(args) < 2:
        print(__doc__.split("\n\n")[1])
        return 1
    echelle = 2
    if "--echelle" in args:
        i = args.index("--echelle")
        echelle = int(args[i + 1])
        del args[i:i + 2]
    e = ecran_depuis_vidage(open(args[0], "rb").read())
    cx, cy, actif = e["curseur"]
    police = charger_police()
    png(args[1], rangs_ecran(police, e["lignes"], (cx, cy) if actif else None), echelle)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
