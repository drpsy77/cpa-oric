#!/usr/bin/env python3
"""Fabrique un fichier .SPR (sprites ou tuiles de GRAPHER) à partir d'un
dessin en texte, en attendant l'éditeur de sprites.

  mkspr.py SOURCE.txt SORTIE.SPR

Format de la source (docs/grapher.md § 10.1 pour le fichier produit) :

  ; commentaire (ligne ignorée, comme les lignes vides)
  GENRE 0            0 : sprites (dessin et silhouette), 1 : tuiles
  NOM larg haut      un sprite ou une tuile : nom de 4 caractères au plus,
                     1 à 4 colonnes, 1 à 4 lignes de cases ; suivent
                     8 x haut lignes de 6 x larg caractères :
     #  point allumé
     o  point éteint qui cache le décor (sprites : silhouette sans dessin)
     .  transparent (sprites) ; éteint (tuiles)
"""
import sys


def lire(chemin):
    genre = None
    objets = []
    cour = None
    for n, l in enumerate(open(chemin, encoding="utf-8"), 1):
        l = l.rstrip("\n").rstrip()
        if not l or l.startswith(";"):
            continue
        if cour is not None and len(cour["lignes"]) < 8 * cour["h"]:
            if len(l) != 6 * cour["w"] or set(l) - set("#o."):
                sys.exit(f"{chemin}:{n} : ligne de {6 * cour['w']} caractères # o . attendue")
            cour["lignes"].append(l)
            continue
        t = l.split()
        if t[0].upper() == "GENRE":
            genre = int(t[1])
            continue
        if len(t) != 3:
            sys.exit(f"{chemin}:{n} : « NOM larg haut » attendu")
        w, h = int(t[1]), int(t[2])
        if not (1 <= w <= 4 and 1 <= h <= 4) or len(t[0]) > 4:
            sys.exit(f"{chemin}:{n} : nom de 4 caractères, 1 à 4 colonnes et lignes")
        cour = {"nom": t[0], "w": w, "h": h, "lignes": []}
        objets.append(cour)
    if genre not in (0, 1) or not objets or len(objets) > 255:
        sys.exit(f"{chemin} : GENRE 0 ou 1 et 1 à 255 objets attendus")
    if len(cour["lignes"]) < 8 * cour["h"]:
        sys.exit(f"{chemin} : dessin incomplet ({cour['nom']})")
    return genre, objets


def octet(ligne, x, car):
    v = 0
    for i in range(6):
        if ligne[x + i] in car:
            v |= 32 >> i
    return v


def fabriquer(genre, objets):
    out = bytearray(b"SPR\x01" + bytes([len(objets), genre, 0, 0]))
    for o in objets:
        out += bytes([o["w"], o["h"], 0, 0]) + o["nom"].ljust(4).encode("ascii")
        for cy in range(o["h"]):
            for cx in range(o["w"]):
                lignes = o["lignes"][8 * cy:8 * cy + 8]
                out += bytes(octet(l, 6 * cx, "#") for l in lignes)
                if genre == 0:
                    out += bytes(octet(l, 6 * cx, "#o") for l in lignes)
    return bytes(out)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    g, objs = lire(sys.argv[1])
    data = fabriquer(g, objs)
    open(sys.argv[2], "wb").write(data)
    print(f"{sys.argv[2]} : {len(objs)} objet(s), genre {g}, {len(data)} octets")
