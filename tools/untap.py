#!/usr/bin/env python3
"""Les blocs d'un fichier .TAP : même résultat qu'UNTAP.COM (progs/untap.s).

  untap.py JEU.TAP [n|*] [/1] [--dir DOSSIER]

  sans n : liste les blocs (numéro, nom, BAS ou BIN, adresses, /R) ;
  n : extrait le bloc n ; * : tous. /1 : BASIC de l'Oric-1 (ROM 1.0).
  Les fichiers sont écrits dans DOSSIER (défaut : celui du .TAP), avec
  leur dernier enregistrement de 128 octets complété par des ^Z, comme
  sur la disquette.

Bloc BASIC (type $00) -> NOM.BAS en texte (comme LIST, CR LF), avec la
notation « {hh} » pour ce que MKTAP ne relirait pas tel quel (codes 0-31
et 127 et plus, espace ou chiffre en tête, espace en fin ; « {{ » pour
l'accolade) ; chaque ligne est recodée par mktap.code_ligne et comparée à
l'originale (« ligne N : recodage different »). Ce qui suit la fin du
programme, s'il y a plus d'un octet -> NOM.BIN. Autre type -> NOM.BIN.
Noms : docs/oric-basic.md § 5.1."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mktap                                 # noqa: E402

T_DATA, T_REM = 0x91, 0x9D
ALT10 = {0x82: "INVERSE", 0x83: "NORMAL", 0xF7: "GO"}
MAXN = 48
USAGE = ("UNTAP nom [n|*] [/1] : blocs .TAP\nUNTAP JEU      liste les blocs\n"
         "UNTAP JEU 2    extrait le bloc 2\nUNTAP JEU *    extrait tous les blocs\n"
         "BASIC : NOM.BAS (texte, MKTAP)\ncode : NOM.BIN ; /1 : BASIC Oric-1")


def blocs(data):
    """-> [(entête 9 octets, nom (octets, 16 au plus), contenu, coupé,
    longueur annoncée)]"""
    out = []
    i = 0
    n = len(data)
    while True:
        while i < n and data[i] != 0x16:            # synchronisation
            i += 1
        if i >= n:
            return out
        while i < n and data[i] == 0x16:
            i += 1
        if i >= n:
            return out
        if data[i] != 0x24:
            continue
        i += 1
        if i + 9 > n:
            return out
        h = data[i:i + 9]
        i += 9
        j = data.find(b"\0", i)
        if j < 0:
            return out
        nom = data[i:j][:16]
        i = j + 1
        debut = h[6] << 8 | h[7]
        fin = h[4] << 8 | h[5]
        lg = fin - debut + 1 if fin >= debut else 0
        corps = data[i:i + lg]
        i += lg
        out.append((h, nom, corps, len(corps) < lg, lg))
        if len(out) == 255:
            return out


def nom_fichier(nom, nb, base, deja):
    f = "".join(chr(c).upper() for c in nom if chr(c).isascii() and chr(c).isalnum())[:8]
    if not f or f in deja:
        s = str(nb)
        f = base[:8 - len(s)] + s
    if len(deja) < MAXN:
        deja.append(f)
    return f


def detok(ligne, v10):
    """ligne codée -> (texte en octets, ne_pas_garantir)"""
    out = bytearray()
    nok = False
    q = d = r = False
    for b in ligne:
        if r:
            out.append(b)
            continue
        if q:
            out.append(b)
            if b == 0x22:
                q = False
            continue
        if b == 0x22:
            out.append(b)
            q = True
            continue
        if d or b < 0x80:
            out.append(b)
        elif v10 and b in ALT10:
            out += ALT10[b].encode()
        elif b < 0x80 + len(mktap.MOTS_CLES):
            out += mktap.MOTS_CLES[b - 0x80].encode()
        else:
            out.append(b)
            nok = True
        if b == ord(":"):
            d = False
        elif b == T_DATA:
            d = True
        elif b == T_REM:
            r = True
    if len(out) > 255:
        out = out[:255]
        nok = True
    return bytes(out), nok


def echappe(t):
    out = bytearray()
    for i, c in enumerate(t):
        if c == 0x7B:
            out += b"{{"
        elif (c < 0x20 or c >= 0x7F or (i == 0 and (c == 0x20 or 0x30 <= c <= 0x39))
              or (i == len(t) - 1 and c == 0x20)):
            out += b"{%02X}" % c
        else:
            out.append(c)
    return bytes(out)


def bas(corps, v10, avert):
    """programme BASIC -> (texte .BAS, octets lus avant le reste)"""
    out = bytearray()
    i = 0
    n = len(corps)
    while True:
        if i + 2 > n:
            return bytes(out), None
        if corps[i + 1] == 0:
            return bytes(out), i + 2
        if i + 4 > n:
            return bytes(out), None
        num = corps[i + 2] | corps[i + 3] << 8
        i += 4
        j = corps.find(b"\0", i)
        fin = n if j < 0 else j
        ligne = corps[i:fin]
        i = fin + 1
        nok = len(ligne) > 255
        ligne = ligne[:255]
        t, k = detok(ligne, v10)
        nok = nok or k or not ligne
        if not nok:
            nok = mktap.code_ligne(t) != ligne
        out += b"%d " % num + echappe(t) + b"\r\n"
        if nok:
            avert.append("ligne %d : recodage different" % num)
        if j < 0:
            return bytes(out), None


def disque(data):
    if len(data) % 128:
        data += b"\x1a" * (128 - len(data) % 128)
    return data


def main():
    args = [a for a in sys.argv[1:]]
    dossier = None
    if "--dir" in args:
        k = args.index("--dir")
        dossier = args[k + 1]
        del args[k:k + 2]
    v10 = "/1" in [a.upper() for a in args]
    args = [a for a in args if a.upper() != "/1"]
    if not args:
        sys.exit(__doc__)
    chemin = args[0]
    voulu = args[1] if len(args) > 1 else None
    if voulu not in (None, "*"):
        if not voulu.isdigit():
            sys.exit(USAGE)
        if not 1 <= int(voulu) <= 255:
            sys.exit("Numero de bloc : 1 a 255")
    if dossier is None:
        dossier = os.path.dirname(chemin) or "."
    base = os.path.basename(chemin).split(".")[0].upper()[:8]
    data = disque(open(chemin, "rb").read())     # comme sur la disquette
    bl = blocs(data)
    if not bl:
        sys.exit("Aucun bloc (pas un .TAP ?)")
    deja = []
    trouve = False
    for nb, (h, nom, corps, coupe, lg) in enumerate(bl, 1):
        f = nom_fichier(nom, nb, base, deja)
        debut, fin = h[6] << 8 | h[7], h[4] << 8 | h[5]
        if voulu is None:
            n = "".join(chr(c) if 0x20 <= c < 0x7F else "?" for c in nom) or "-"
            print("%3d %-16s %s %04X-%04X%s" % (nb, n, "BIN" if h[2] else "BAS",
                                               debut, fin, " /R" if h[3] else ""))
        elif voulu == "*" or int(voulu) == nb:
            trouve = True
            if h[2]:
                open(os.path.join(dossier, f + ".BIN"), "wb").write(disque(corps))
                print("%s.BIN %04X-%04X ecrit" % (f, debut, fin))
            else:
                avert = []
                texte, lus = bas(corps, v10, avert)
                open(os.path.join(dossier, f + ".BAS"), "wb").write(disque(texte))
                for a in avert:
                    print(a)
                print("%s.BAS ecrit" % f)
                if lus is not None and lg - lus > 1:
                    open(os.path.join(dossier, f + ".BIN"), "wb").write(disque(corps[lus:]))
                    print("%s.BIN %04X-%04X ecrit" % (f, debut + lus, fin))
        if coupe:
            print("bloc %d incomplet" % nb)
        if voulu not in (None, "*") and int(voulu) == nb:
            break
    if voulu is not None and not trouve:
        sys.exit("Bloc absent")


if __name__ == "__main__":
    main()
