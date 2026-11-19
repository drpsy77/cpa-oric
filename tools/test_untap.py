#!/usr/bin/env python3
"""UNTAP.COM contre tools/untap.py, et aller-retour BASIC par MKTAP.

  python3 tools/test_untap.py [nombre de programmes au hasard, défaut 6]

1. Des .TAP fabriqués ici (noms vides, en double, longs, en minuscules ;
   synchronisation longue, rebut entre les blocs, bloc coupé, fin avant le
   début ; BASIC suivi de code, codes inconnus, minuscules, ligne vide,
   espace en tête, codes de la ROM 1.0 ; douze blocs pour AVENTU12) sont
   lus par UNTAP.COM (build/progs, 6502 simulé par tools/run_com.py) et par
   untap.py : même sortie à l'écran, mêmes fichiers écrits.
2. Aller-retour : des programmes BASIC tirés au hasard (lignes codées
   comme la ROM par mktap.code_ligne, octets de contrôle et de 128 et plus
   glissés dans les chaînes et les REM) sont mis en .TAP, rendus en texte
   par UNTAP.COM, puis recodés par tools/mktap.py : le programme doit
   revenir octet par octet, liens compris, sauf les lignes signalées
   « recodage different » (et seulement celles que mktap.py recode
   autrement).
"""
import os
import random
import shutil
import subprocess
import sys
import tempfile

R = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, R)
import mktap                                 # noqa: E402

COM = os.path.join(R, "..", "build", "progs", "UNTAP.COM")
ko = 0


def bloc(nom, typ, debut, corps, auto=0, sync=4):
    fin = debut + len(corps) - 1
    return (bytes([0x16] * sync + [0x24, 0, 0, typ, auto, fin >> 8, fin & 255,
                                   debut >> 8, debut & 255, 0]) + nom + b"\0" + corps)


def prog(lignes, queue=b"\0"):
    """[(numéro, octets codés)] -> programme en $0501 (liens, 0 0, queue)"""
    out = bytearray()
    adr = 0x0501
    for num, code in lignes:
        adr += 5 + len(code)
        out += bytes([adr & 255, adr >> 8, num & 255, num >> 8]) + code + b"\0"
    return bytes(out) + b"\0\0" + queue


def lance(cmd, cwd):
    p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    lignes = p.stdout.decode("latin-1").replace("\r", "").split("\n")
    return [x for x in lignes if x and not x.startswith("[")]


def fichiers(d, sauf):
    return {f: open(os.path.join(d, f), "rb").read()
            for f in sorted(os.listdir(d)) if f not in sauf}


def compare(nom, tap, args, tmp):
    """UNTAP.COM et untap.py sur le même .TAP -> (sortie, fichiers) de COM"""
    global ko
    a = os.path.join(tmp, "com")
    b = os.path.join(tmp, "py")
    for d in (a, b):
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(d)
        open(os.path.join(d, nom + ".TAP"), "wb").write(tap)
    shutil.copy(COM, os.path.join(a, "UNTAP.COM"))
    sa = lance([sys.executable, os.path.join(R, "run_com.py"), ".", "UNTAP.COM", nom] + args, a)
    sb = lance([sys.executable, os.path.join(R, "untap.py"), nom + ".TAP"] + args, b)
    fa = fichiers(a, ("UNTAP.COM", nom + ".TAP"))
    fb = fichiers(b, (nom + ".TAP",))
    titre = "%s %s" % (nom, " ".join(args))
    if sa != sb or fa != fb:
        ko += 1
        print("DIFFERENT : " + titre)
        if sa != sb:
            print("  UNTAP.COM : %r\n  untap.py  : %r" % (sa, sb))
        for f in sorted(set(fa) | set(fb)):
            if fa.get(f) != fb.get(f):
                print("  fichier %s : %r / %r" % (f, (fa.get(f) or b"")[:80], (fb.get(f) or b"")[:80]))
    else:
        print("identique : %s (%d ligne(s), %d fichier(s))" % (titre, len(sa), len(fa)))
    return sa, fa


def cas_fixes(tmp):
    code = bytes(range(256))
    basic = prog([(10, mktap.code_ligne(b'PRINT "OK"')),
                  (20, mktap.code_ligne(b"GOTO 10"))])
    # noms
    tap = (bloc(b"JEU", 0, 0x0501, basic, auto=0x80)
           + bloc(b"", 0x80, 0x9800, code[:100])
           + bloc(b"***", 0x80, 0xA000, code[:10])
           + bloc(b"JEU", 0x80, 0x9000, code[5:50])
           + bloc(b"jeu 2!", 0x80, 0x9000, code[:3])
           + bloc(b"ABCDEFGHIJKLMNOPQRS", 0x80, 0xBB80, code[:40], auto=0xC7))
    compare("NOMS", tap, [], tmp)
    compare("NOMS", tap, ["*"], tmp)
    compare("NOMS", tap, ["4"], tmp)
    compare("NOMS", tap, ["9"], tmp)
    compare("NOMS", tap, ["0"], tmp)
    compare("NOMS", tap, ["/X"], tmp)
    # douze blocs, nom de .TAP long
    tap = b"".join(bloc(b"", 0x80, 0x9000 + i, code[:i + 1]) for i in range(12))
    compare("AVENTURE", tap, ["*"], tmp)
    # synchronisation longue, rebut, bloc coupé, fin avant le début
    fausse = bytes([0x16, 0x24, 0, 0, 0x80, 0, 0x8F, 0x00, 0x90, 0x00, 0]) + b"F\0"
    tap = (b"\x16\x16\x00rebut\x16\x25" + bloc(b"A", 0x80, 0x9000, code[:20], sync=200)
           + b"rebut\x24\x00" + fausse + bloc(b"G", 0x80, 0x9100, code[:5], sync=1)
           + bloc(b"B", 0x80, 0x9000, code[:60])[:-30])
    compare("REBUT", tap, [], tmp)
    compare("REBUT", tap, ["*"], tmp)
    compare("RIEN", b"pas une cassette" * 20, [], tmp)
    # BASIC : queue de code, codes inconnus, minuscules, ligne vide, espace
    # en tête, ROM 1.0, accolades, contrôles, chaîne non fermée
    lignes = [(1, mktap.code_ligne(b"PRINT 1")),
              (2, b"\xf8\xfa"),
              (3, b"print a"),
              (4, b""),
              (5, b" " + mktap.code_ligne(b"PRINT 2")),
              (6, b"\x82:\x83:\xf7 10"),
              (7, b'\xba"{\x1b\x80\xff} "'),
              (8, b"\x9d \x01\x7f{x}"),
              (9, b"5" + mktap.code_ligne(b"END")),
              (65535, b'\x91 1,"a:b":\xba'),
              (11, b'\xba"pas ferme \x91 :')]
    p = prog(lignes, queue=b"\0" + code[:33])
    tap = bloc(b"PROG", 0, 0x0501, p) + bloc(b"PROG", 0, 0x0501, prog(lignes)[:-9])
    compare("BAS", tap, [], tmp)
    compare("BAS", tap, ["*"], tmp)
    compare("BAS", tap, ["1", "/1"], tmp)


def hasard(rng):
    """ligne codée comme la ROM : morceaux au hasard, puis octets bruts
    glissés dans une chaîne ou un REM"""
    morceaux = (mktap.MOTS_CLES + list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                + list("0123456789") + [" ", ":", ";", "\"", "?", ",", "(", ")",
                                           "$", "#", "%", ".", "{", "DATA", "REM"])
    t = ""
    while len(t) < rng.randrange(1, 70):
        t += rng.choice(morceaux)
    code = mktap.code_ligne(t.encode("ascii"))
    r = rng.random()
    if r < .3:
        brut = bytes(rng.choice([rng.randrange(1, 32), rng.randrange(127, 256),
                                 rng.randrange(32, 127)]) for _ in range(rng.randrange(1, 6)))
        brut = brut.replace(b'"', b"'")
        code = code + (b'\x3a\xba"' + brut + b'"' if r < .2 else b":\x9d" + brut)
    return code[:250]


def aller_retour(rng, tmp, n):
    global ko
    for k in range(n):
        lignes = []
        num = rng.randrange(0, 50)
        for _ in range(rng.randrange(20, 120)):
            lignes.append((num, hasard(rng)))
            num += rng.randrange(1, 300)
            if num > 63999:
                break
        p = prog(lignes)
        nom = "AR%d" % k
        sortie, fich = compare(nom, bloc(nom.encode(), 0, 0x0501, p), ["1"], tmp)
        signalees = {int(x.split()[1]) for x in sortie if "recodage" in x}
        d = os.path.join(tmp, "com")
        q = subprocess.run([sys.executable, os.path.join(R, "mktap.py"), "X.TAP",
                            nom + ".BAS"], cwd=d, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT)
        if q.returncode:
            ko += 1
            print("ALLER-RETOUR %s : mktap.py refuse : %s" % (nom, q.stdout.decode()))
            continue
        x = open(os.path.join(d, "X.TAP"), "rb").read()
        p2 = x[x.index(b"\0", 14) + 1:]       # après le nom
        # lignes recodées, comparées une à une (les liens suivent)
        def decoupe(prg):
            out = {}
            i = 0
            while prg[i + 1]:
                num = prg[i + 2] | prg[i + 3] << 8
                j = prg.index(b"\0", i + 4)
                out[num] = prg[i + 4:j]
                i = j + 1
            return out
        a, b = decoupe(p), decoupe(p2)
        faux = sorted(n for n in a if a[n] != b.get(n) and n not in signalees)
        trop = sorted(n for n in signalees if a[n] == b.get(n) and a[n])
        if faux or trop or (not signalees and p2 != p):
            ko += 1
            print("ALLER-RETOUR %s : differentes non signalees %s, signalees a tort %s"
                  % (nom, faux[:5], trop[:5]))
        else:
            print("aller-retour %s : %d lignes, %d signalee(s)" % (nom, len(a), len(signalees)))


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 6
    if not os.path.exists(COM):
        sys.exit("build/progs/UNTAP.COM absent : ./build.sh d'abord")
    tmp = tempfile.mkdtemp()
    try:
        cas_fixes(tmp)
        aller_retour(random.Random(77), tmp, n)
    finally:
        shutil.rmtree(tmp)
    print("UNTAP : %s" % ("tout est bon" if not ko else "%d DIFFERENCE(S)" % ko))
    sys.exit(1 if ko else 0)


if __name__ == "__main__":
    main()
