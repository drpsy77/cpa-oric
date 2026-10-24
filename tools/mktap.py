#!/usr/bin/env python3
"""Fabrique un fichier .TAP (cassette de l'Oric) : même résultat que MKTAP.COM.

  mktap.py SORTIE.TAP FICHIER ADR[,LONG] [/R] [FICHIER ADR[,LONG] [/R]]...

  ADR, LONG : hexadécimal ($ facultatif). Chaque FICHIER devient un bloc
  chargé en ADR (code machine), nommé d'après le fichier sans son type.
  Sans LONG, la longueur est celle du fichier, moins les ^Z ($1A) qui
  complètent son dernier enregistrement de 128 octets (même règle que
  STAT, EXPORT et MKTAP.COM sur l'Oric). LONG peut aller jusqu'à la
  taille brute (enregistrements entiers, complétés par des ^Z comme sur
  la disquette) : données qui finissent vraiment par $1A.
  /R après un fichier : ce bloc est lancé après le chargement.
    - un seul bloc : il porte la marque de démarrage automatique ;
    - plusieurs blocs : un petit programme BASIC est mis en tête (nommé
      comme le .TAP, démarrage automatique) :
        10 CLOAD"":CLOAD"":...:CALL#ADR
      il charge les blocs dans l'ordre puis lance celui marqué /R.
  Sans /R : les blocs se chargent un par un par CLOAD"".

Contrôles (les mêmes que MKTAP.COM) : 8 blocs au plus, un seul /R, chaque
bloc dans $0500-$BFFF, pas de chevauchement (chargeur BASIC compris),
LONG non nulle et pas plus grande que la taille brute.

Le fichier écrit a la taille exacte (MKTAP.COM, lui, complète son dernier
enregistrement par des ^Z, que EXPORT retire ; si le dernier octet utile
vaut $1A, MKTAP.COM ajoute d'abord un octet 0)."""
import os
import sys

# mots-clés du BASIC de l'Oric (ROM 1.1, table de la ROM)
T_CLOAD = 0xB6
T_CALL = 0xBF

MIN_ADR = 0x0500
MAX_ADR = 0xBFFF
MAX_BLOCS = 8
BASIC = 0x0501          # début des programmes BASIC


def entete(nom, typ, auto, debut, fin):
    """Synchro, $24, en-tête de 9 octets, nom terminé par 0."""
    return (bytes([0x16] * 4 + [0x24, 0, 0, typ, auto, fin >> 8, fin & 255,
                                debut >> 8, debut & 255, 0])
            + nom.encode("ascii") + b"\0")


def longueur_cpm(data):
    """Longueur d'un fichier CP/A : enregistrements de 128 octets, ^Z de
    remplissage du dernier retirés."""
    if len(data) % 128:
        data = data + b"\x1a" * (128 - len(data) % 128)
    n = len(data)
    bas = n - 128
    while n > bas and data[n - 1] == 0x1A:
        n -= 1
    return n


def chargeur(adr, nblocs):
    """Programme BASIC : 10 CLOAD"":... :CALL#ADR (tokenisé, en $0501)."""
    ligne = bytes([0x0A, 0x00])
    for i in range(nblocs):
        ligne += bytes([T_CLOAD]) + b'""' + b":"
    ligne += bytes([T_CALL]) + ("#%X" % adr).encode("ascii") + b"\0"
    suivante = BASIC + 2 + len(ligne)
    # fin du programme (0 0), plus un octet : la ROM prend l'adresse de fin
    # du bloc pour le début des variables (comme CSAVE, qui écrit un octet
    # de plus)
    prog = bytes([suivante & 255, suivante >> 8]) + ligne + b"\0\0\0"
    return prog


def nom_bloc(chemin):
    n = os.path.basename(chemin).split(".")[0].upper()
    if ":" in n:
        n = n.split(":")[1]
    return n[:8]


def hexa(t):
    t = t.lstrip("$")
    if not t or len(t) > 4:
        raise ValueError
    return int(t, 16)


def analyse(args):
    blocs = []
    i = 0
    while i < len(args):
        f = args[i]
        if i + 1 >= len(args):
            sys.exit("%s : adresse manquante" % f)
        a = args[i + 1].split(",")
        try:
            adr = hexa(a[0])
            lg = hexa(a[1]) if len(a) > 1 else None
        except (ValueError, IndexError):
            sys.exit("%s : adresse invalide" % f)
        i += 2
        auto = False
        if i < len(args) and args[i].upper() == "/R":
            auto = True
            i += 1
        blocs.append([f, adr, lg, auto])
    return blocs


def fabrique(blocs, nom_tap):
    if not blocs:
        sys.exit("aucun fichier")
    if len(blocs) > MAX_BLOCS:
        sys.exit("trop de fichiers (8 au plus)")
    if sum(b[3] for b in blocs) > 1:
        sys.exit("/R une seule fois")
    plages = []
    contenus = []
    for f, adr, lg, auto in blocs:
        data = open(f, "rb").read()
        n = longueur_cpm(data)
        if n == 0:
            sys.exit("%s : vide" % f)
        brut = (len(data) + 127) // 128 * 128
        data = data + b"\x1a" * (brut - len(data))
        if lg is None:
            lg = n
        if lg > brut:
            sys.exit("%s : plus court que la longueur" % f)
        fin = adr + lg - 1
        if adr < MIN_ADR or fin > MAX_ADR:
            sys.exit("%s : hors de 0500-BFFF" % f)
        plages.append((nom_bloc(f), adr, fin))
        contenus.append(data[:lg])
    auto = [b for b in blocs if b[3]]
    prog = None
    if auto and len(blocs) > 1:
        prog = chargeur(auto[0][1], len(blocs))
    # chargeur en dernier, comme MKTAP.COM (même message d'erreur)
    toutes = plages + ([(nom_tap, BASIC, BASIC + len(prog) - 1)] if prog else [])
    for i in range(len(toutes)):
        for j in range(i):
            if toutes[i][1] <= toutes[j][2] and toutes[j][1] <= toutes[i][2]:
                sys.exit("%s : chevauche %s" % (toutes[i][0], toutes[j][0]))
    return prog, plages, contenus


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    sortie = sys.argv[1]
    blocs = analyse(sys.argv[2:])
    nom_tap = nom_bloc(sortie)
    prog, plages, contenus = fabrique(blocs, nom_tap)
    out = b""
    if prog is not None:
        fin = BASIC + len(prog) - 1
        out += entete(nom_tap, 0x00, 0x80, BASIC, fin) + prog
        print("%-8s %04X-%04X BASIC" % (nom_tap, BASIC, fin))
    seul_auto = prog is None and blocs[0][3]
    for (nom, adr, fin), data, b in zip(plages, contenus, blocs):
        out += entete(nom, 0x80, 0x80 if seul_auto else 0, adr, fin) + data
        print("%-8s %04X-%04X%s" % (nom, adr, fin, " /R" if b[3] else ""))
    open(sortie, "wb").write(out)


if __name__ == "__main__":
    main()
