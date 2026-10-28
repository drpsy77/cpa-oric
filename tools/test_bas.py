#!/usr/bin/env python3
"""Codage des .BAS par tools/mktap.py contre la ROM BASIC 1.1 elle-même.

La ROM (tools/oricutron/roms/basic11b.rom) tourne dans le 6502 simulé
(py65) : la ligne est mise dans son tampon ($35), puis son propre chemin de
saisie est suivi depuis $C4C1 (CHRGET, Txt2Int pour le numéro,
TokeniseLine $C5FA) jusqu'à l'insertion ($C4D9) ; le numéro ($33-$34) et
la ligne codée ($35...) sont comparés à ceux de mktap.py (code_bas).

  python3 tools/test_bas.py [nombre de lignes au hasard, défaut 3000]

Cas : une liste écrite à la main (mots-clés collés, chaînes, DATA, REM,
« ? », numéros avec espaces), puis des lignes tirées au hasard. Les
minuscules (que la ROM ne reconnaît pas) sont essayées à part : la ligne en
minuscules donne, par mktap.py, le même code que la ROM sur la ligne mise
en majuscules hors des chaînes, des REM et des DATA (écrite à la main).
La table des mots-clés de MKTAP.COM (progs/bas_tab.s) est aussi comparée à
celle de la ROM.
"""
import os
import random
import sys

R = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(R, "pylib"))
sys.path.insert(0, R)
from py65.devices.mpu6502 import MPU        # noqa: E402
import mktap                                 # noqa: E402

ROM = os.path.join(R, "oricutron", "roms", "basic11b.rom")


class Rom:
    def __init__(self):
        rom = open(ROM, "rb").read()
        self.m = MPU()
        self.m.memory[0xC000:0x10000] = list(rom)
        # CHRGET, recopiée en $E2 par la ROM au démarrage
        self.m.memory[0xE2:0xE2 + 17] = list(rom[0xEC9C - 0xC000:0xEC9C - 0xC000 + 17])

    def code(self, ligne):
        """Ligne tapée -> (numéro, octets codés) ou None (pas un numéro
        valide : commande directe, ou erreur de syntaxe)."""
        m = self.m
        for i in range(0x35, 0x35 + 82):
            m.memory[i] = 0
        for i, c in enumerate(ligne):
            m.memory[0x35 + i] = c
        m.memory[0xE9] = 0x34
        m.memory[0xEA] = 0x00
        m.sp = 0xF0
        m.pc = 0xC4C1
        for _ in range(200000):
            if m.pc == 0xC4D9:
                n = m.memory[0x33] | m.memory[0x34] << 8
                out = bytearray()
                i = 0x35
                while m.memory[i]:
                    out.append(m.memory[i])
                    i += 1
                return n, bytes(out)
            # commande directe, ligne vide, numéro trop grand, erreur
            if m.pc in (0xC4CD, 0xC4B7, 0xCACA, 0xC47C):
                return None
            m.step()
        raise RuntimeError("ROM : pas de fin pour %r" % ligne)


def par_mktap(ligne):
    """Même ligne par mktap.py -> (numéro, octets) ; None si refusée."""
    try:
        p = mktap.code_bas(ligne + b"\r\n", "T.BAS")
    except SystemExit:
        return None
    num = p[2] | p[3] << 8
    return num, p[4:p.index(0, 4)]


MAIN = [
    b"10 PRINT \"BONJOUR\"",
    b"20 FORI=1TO10STEP2:NEXTI",
    b"30 IFA>=1THENGOTO10ELSE?TAB(3);SPC(2)",
    b"40 REM PRINT ? \"X:Y",
    b"50 DATA PRINT,\"A:B\",TO:PRINT 1",
    b"60 DATA ? FOR : ?A",
    b"70 SCORE=FORT+TOTO:IFX ORY THENEND",
    b"80 A$=LEFT$(B$,2)+MID$(C$,1,2)+RIGHT$(D$,1)+CHR$(65)",
    b"90 ? \"NON FERME",
    b"1 0 0 PRINT 5",
    b"   110   PRINT",
    b"63999 END",
    b"64000 END",
    b"6400 END",
    b"120 CALL#9000:DOKE#2F5,#9000:!",
    b"130 POKE48000,PEEK(1)AND255:X=DEEK(2)",
    b"140 ON X GOTO 10,20:ON X GOSUB 30",
    b"150 A=1E3*PI/2^3-SQR(4)+-1",
    b"160 GET K$:IF KEY$=\"\" THEN 160",
    b"170 HIRES:CURSET10,10,1:DRAW5,5,1:CIRCLE3,1:TEXT",
    b"180 DEF FN A(X)=X*2:PRINT FN A(3)",
    b"190 PRINT@1,2;\"X\"",
    b"200 REPEAT:X=X+1:UNTIL X>5",
    b"210 RESTORE:READ A:STOP:CONT",
    b"220 PRINT;;;:::",
    b"230 INPUT\"NOM\";N$:LET B=VAL(N$)",
    b"240 DATA",
    b"250 X=ATN(1)+COS(1)+SIN(1)+TAN(1)+LN(2)+EXP(1)+LOG(10)",
    b"260 A=NOT B:C=TRUE:D=FALSE:E=SGN(-1)+INT(1)+ABS(1)+FRE(0)+POS(0)",
    b"270 PAPER0:INK7:LORES0:PLOT1,1,\"A\":WAIT10",
    b"280 PING:SHOOT:ZAP:EXPLODE:SOUND1,2,3:MUSIC1,2,3,4:PLAY1,1,1,1",
    b"290 X=HEX$(255)+STR$(1):Y=LEN(\"A\")+ASC(\"B\")",
    b"300 X=SCRN(1,1)+POINT(1,1):Y=USR(0)&1",
    b"310 GOTO 10 : GOSUB 20 : RETURN : POP : PULL",
    b"320 CLS:LIST:LLIST:LPRINT:CLEAR:NEW",
    b"330 STORE A,\"X\":RECALL A,\"X\":CSAVE\"A\":CLOAD\"A\"",
    b"340 TRON:TROFF:EDIT:AUTO:GRAB:RELEASE:HIMEM#9000",
    b"350 FILL1,1,1:PATTERN1:CHAR65,0,1:CURMOV1,1,1",
    b"360 DIM A(10):A(1)=2:END",
    b"370",
    b"PRINT 1",
    b"",
]

# minuscules : (ligne pour mktap.py, même ligne mise en majuscules hors des
# chaînes, des REM et des DATA, pour la ROM)
MINUS = [
    (b"10 print \"Bonjour\";a$", b"10 PRINT \"Bonjour\";A$"),
    (b"20 rem Un Commentaire", b"20 REM Un Commentaire"),
    (b"30 data abc,\"x\",Def:goto 30", b"30 DATA abc,\"x\",Def:GOTO 30"),
    (b"40 forI=1to3:nexti", b"40 FORI=1TO3:NEXTI"),
    (b"50 Score=Fort+tOtO", b"50 SCORE=FORT+TOTO"),
    (b"60 ? left$(\"aB\",1)", b"60 ? LEFT$(\"aB\",1)"),
]

MORCEAUX = (mktap.MOTS_CLES + list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            + list("0123456789") + [" ", " ", ":", ";", "\"", "?", ",", "(",
                                       ")", "$", "#", "%", ".", "'", "[", "]"]
            + ["DATA", "REM", "\"", ":"])


def hasard(rng):
    t = str(rng.randrange(0, 64010))
    t = rng.choice(["", " ", "  "]) + " ".join(t) if rng.random() < .1 else t
    t += rng.choice(["", " ", "  "])
    while len(t) < rng.randrange(4, 78):
        t += rng.choice(MORCEAUX)
    return t[:78].encode("ascii")


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    rom = Rom()
    ko = 0
    vus = 0
    # table de MKTAP.COM (progs/bas_tab.s) == table de la ROM ($C0EA)
    tab = bytearray()
    for l in open(os.path.join(R, "..", "progs", "bas_tab.s")):
        l = l.split(";")[0].strip()
        if l.startswith(".byt"):
            tab += bytes(int(x.strip().lstrip("$"), 16) for x in l[4:].split(","))
    if bytes(tab) != bytes(rom.m.memory[0xC0EA:0xC0EA + len(tab)]):
        print("progs/bas_tab.s DIFFERENT de la table de la ROM")
        ko += 1

    def compare(ligne, attendu):
        nonlocal ko, vus
        vus += 1
        a = par_mktap(ligne)
        if a != attendu:
            ko += 1
            if ko <= 10:
                print("DIFFERENT : %r\n  ROM    : %r\n  mktap  : %r" % (ligne, attendu, a))

    for ligne in MAIN:
        r = rom.code(ligne)
        if r is not None and r[1] == b"":
            r = None            # numéro seul : la ROM efface la ligne
        compare(ligne, r)
    for minus, maj in MINUS:
        compare(minus, rom.code(maj))
    rng = random.Random(1234)
    for _ in range(n):
        ligne = hasard(rng)
        r = rom.code(ligne)
        if r is not None and r[1] == b"":
            r = None
        compare(ligne, r)
    print("%d lignes, %d differentes" % (vus, ko))
    sys.exit(ko != 0)


if __name__ == "__main__":
    main()
