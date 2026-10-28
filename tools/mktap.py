#!/usr/bin/env python3
"""Fabrique un fichier .TAP (cassette de l'Oric) : même résultat que MKTAP.COM.

  mktap.py SORTIE.TAP FICHIER ADR[,LONG] [/R] [FICHIER ADR[,LONG] [/R]]...
  mktap.py SORTIE.TAP PROG.BAS [/R] [FICHIER ADR[,LONG] [/R]]...

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

  Un fichier .BAS (programme BASIC en texte, avec ses numéros de ligne,
  un seul) ne prend pas d'adresse : il est codé comme le ferait la ROM 1.1
  (mots-clés en un octet) et chargé en $0501 comme un programme BASIC ;
  /R le lance (RUN) à la fin du chargement. Les minuscules passent en
  majuscules, sauf entre guillemets, après REM et dans un DATA. Codage
  et contrôles : voir code_bas (docs/oric-basic.md § 2).

Contrôles (les mêmes que MKTAP.COM) : 8 blocs au plus, un seul /R, chaque
bloc dans $0500-$BFFF, pas de chevauchement (chargeur BASIC compris),
LONG non nulle et pas plus grande que la taille brute, bloc /R en $0503 au
plus tôt (la ROM met $00 en $0500-$0502 avant de le lancer ; un .BAS
n'est pas concerné), un seul .BAS.

Le fichier écrit a la taille exacte (MKTAP.COM, lui, complète son dernier
enregistrement par des ^Z, que EXPORT retire ; si le dernier octet utile
vaut $1A, MKTAP.COM ajoute d'abord un octet 0)."""
import os
import sys

# mots-clés du BASIC de l'Oric (ROM 1.1, table de la ROM)
T_CLOAD = 0xB6
T_CALL = 0xBF
T_DATA = 0x91
T_REM = 0x9D
T_PRINT = 0xBA

# table des mots-clés de la ROM 1.1 ($C0EA), dans son ordre : le code d'un
# mot-clé est $80 + son rang ; la ROM prend le premier qui convient
MOTS_CLES = (
    "END EDIT STORE RECALL TRON TROFF POP PLOT PULL LORES DOKE REPEAT "
    "UNTIL FOR LLIST LPRINT NEXT DATA INPUT DIM CLS READ LET GOTO RUN IF "
    "RESTORE GOSUB RETURN REM HIMEM GRAB RELEASE TEXT HIRES SHOOT EXPLODE "
    "ZAP PING SOUND MUSIC PLAY CURSET CURMOV DRAW CIRCLE PATTERN FILL CHAR "
    "PAPER INK STOP ON WAIT CLOAD CSAVE DEF POKE PRINT CONT LIST CLEAR GET "
    "CALL ! NEW TAB( TO FN SPC( @ AUTO ELSE THEN NOT STEP + - * / ^ AND OR "
    "> = < SGN INT ABS USR FRE POS HEX$ & SQR RND LN EXP COS SIN TAN ATN "
    "PEEK DEEK LOG LEN STR$ VAL ASC CHR$ PI TRUE FALSE KEY$ SCRN POINT "
    "LEFT$ RIGHT$ MID$").split()
assert len(MOTS_CLES) == 119

LG_EDITEUR = 78         # ligne la plus longue que l'éditeur de l'Oric accepte
LG_SOURCE = 255         # ligne de texte la plus longue (MKTAP.COM : tampon)
LG_CODE = 250           # octets codés d'une ligne au plus (LIST : index Y)

MIN_ADR = 0x0500
MIN_AUTO = 0x0503        # bloc /R : la ROM met $00 en $0500-$0502 avant de le lancer
MAX_ADR = 0xBFFF
MAX_BLOCS = 8
BASIC = 0x0501          # début des programmes BASIC
BASMAX = 0x97FF         # fin d'un programme BASIC au plus (sous HIMEM)


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


def code_ligne(t):
    """Code le texte d'une ligne (après son numéro) comme TokeniseLine de la
    ROM 1.1 ($C5FA), minuscules en plus : espaces gardés ; entre guillemets,
    après REM et dans un DATA (jusqu'au « : »), texte recopié tel quel ;
    « ? » = PRINT ; chiffres, « : » et « ; » recopiés ; ailleurs, le
    premier mot-clé de la table qui commence là (lettres mises en
    majuscules), sinon le caractère, en majuscule. None : caractère de
    code $80 ou plus hors texte (la ROM couperait la ligne)."""
    out = bytearray()
    i = 0
    data = False
    while i < len(t):
        c = t[i]
        if c == 0x22:                       # chaîne : jusqu'au guillemet
            out.append(c)
            i += 1
            while i < len(t):
                out.append(t[i])
                i += 1
                if t[i - 1] == 0x22:
                    break
            continue
        if c == 0x20 or data:
            b = c
            i += 1
        elif c == ord("?"):
            b = T_PRINT
            i += 1
        elif 0x30 <= c <= 0x3B:
            b = c
            i += 1
        else:
            if c >= 0x80:
                return None
            haut = bytes(t[i:i + 7]).upper()
            for n, m in enumerate(MOTS_CLES):
                if haut.startswith(m.encode("ascii")):
                    b = 0x80 + n
                    i += len(m)
                    break
            else:
                b = ord(chr(c).upper())
                i += 1
        out.append(b)
        if b == ord(":"):
            data = False
        elif b == T_DATA:
            data = True
        elif b == T_REM:
            out += t[i:]
            break
    return bytes(out)


def code_bas(data, nom):
    """Programme BASIC en texte -> octets chargés en $0501 (lignes liées,
    fin 0 0, plus un octet : la ROM en fait le début des variables).
    Chaque ligne : numéro (espaces admis, comme à la saisie), puis le texte.
    Lignes vides ignorées, ligne réduite à un numéro aussi ; caractères de
    contrôle retirés (le clavier de l'Oric n'en met pas dans une ligne).
    Erreurs : numéro absent ou plus grand que 63999, numéros pas
    croissants, ligne de texte de plus de 255 caractères ou codée sur plus
    de 250 octets, caractère de code $80 ou plus hors texte. Avertissement :
    ligne de plus de 78 caractères (l'éditeur de l'Oric la refuserait)."""
    fin = data.find(b"\x1a")
    if fin >= 0:
        data = data[:fin]
    prog = bytearray()
    adr = BASIC
    der = -1                # numéro de la ligne précédente
    for brute in data.replace(b"\r\n", b"\n").replace(b"\r", b"\n").split(b"\n"):
        t = bytes(c for c in brute if c >= 0x20)
        if not t.strip(b" "):
            continue
        i = 0
        while i < len(t) and t[i] == 0x20:
            i += 1
        num = 0
        chiffres = 0
        while i < len(t) and (t[i] == 0x20 or 0x30 <= t[i] <= 0x39):
            if t[i] != 0x20:
                if num >= 6400:
                    chiffres = -1
                    break
                num = num * 10 + t[i] - 0x30
                chiffres += 1
            i += 1
        if chiffres <= 0:
            sys.exit("apres %d : numero invalide" % max(der, 0))
        if len(t) > LG_SOURCE:
            sys.exit("ligne %d : trop longue" % num)
        if i == len(t):
            continue                    # numéro seul : rien
        if num <= der:
            sys.exit("ligne %d : hors d'ordre" % num)
        if len(t) > LG_EDITEUR:
            print("ligne %d : plus de 78 caracteres" % num)
        code = code_ligne(t[i:])
        if code is None:
            sys.exit("ligne %d : caractere invalide" % num)
        if len(code) > LG_CODE:
            sys.exit("ligne %d : trop longue" % num)
        adr += 5 + len(code)
        prog += bytes([adr & 255, adr >> 8, num & 255, num >> 8]) + code + b"\0"
        der = num
    if not prog:
        sys.exit("%s : vide" % nom)
    return bytes(prog) + b"\0\0\0"


def est_bas(chemin):
    return os.path.basename(chemin).upper().endswith(".BAS")


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
        if est_bas(f):
            if any(b[4] for b in blocs):
                sys.exit("Un seul .BAS")
            i += 1
            if i < len(args):
                try:
                    hexa(args[i].split(",")[0])
                    sys.exit("Pas d'adresse apres un .BAS")
                except ValueError:
                    pass
            auto = False
            if i < len(args) and args[i].upper() == "/R":
                auto = True
                i += 1
            blocs.append([f, BASIC, None, auto, True])
            continue
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
        blocs.append([f, adr, lg, auto, False])
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
    for f, adr, lg, auto, bas in blocs:
        data = open(f, "rb").read()
        if bas:
            code = code_bas(data, f)
            fin = BASIC + len(code) - 1
            if fin > BASMAX:
                sys.exit("%s : trop long" % f)
            plages.append((nom_bloc(f), BASIC, fin))
            contenus.append(code)
            continue
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
        if auto and adr < MIN_AUTO:
            sys.exit("%s : /R avant 0503" % f)
        plages.append((nom_bloc(f), adr, fin))
        contenus.append(data[:lg])
    auto = [b for b in blocs if b[3]]
    prog = None
    if auto and len(blocs) > 1 and not auto[0][4]:
        if any(b[4] for b in blocs):
            sys.exit("Avec un .BAS, /R sur lui seulement")
        prog = chargeur(auto[0][1], len(blocs))
    # chargeur en dernier, comme MKTAP.COM (même message d'erreur)
    toutes = plages + ([(nom_tap, BASIC, BASIC + len(prog) - 1)] if prog else [])
    for i in range(len(toutes)):
        for j in range(i):
            if toutes[i][1] <= toutes[j][2] and toutes[j][1] <= toutes[i][2]:
                sys.exit("%s : chevauche %s" % (toutes[i][0], toutes[j][0]))
    return prog, plages, contenus


def main():
    if len(sys.argv) < 3:
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
    for (nom, adr, fin), data, b in zip(plages, contenus, blocs):
        lance = prog is None and b[3]       # pas de chargeur : bloc /R
        out += entete(nom, 0x00 if b[4] else 0x80, 0x80 if lance else 0,
                      adr, fin) + data
        print("%-8s %04X-%04X%s%s" % (nom, adr, fin, " BASIC" if b[4] else "",
                                      " /R" if b[3] else ""))
    open(sortie, "wb").write(out)


if __name__ == "__main__":
    main()
