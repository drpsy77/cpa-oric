#!/usr/bin/env python3
"""Bibliothèque de la souris du LOCI (progs/mou_inc.s) dans un 6502 simulé
(py65, tools/pylib), sans émulateur.

  python3 tools/test_mou.py

La bibliothèque est assemblée par xa avec une table de sauts en $0500 ;
le LOCI est simulé : registres de la MIA ($03A4-$03AF), code d'attente
en $03B0, XREG, fenêtre 0 de la XRAM, fichiers de 0: (open, read, write,
close). Essais :
- sans LOCI : mo_init refuse, mo_poll rend 0 ;
- départ : rapport tenu en $FF00, réglage 2 sans 0:CPA.MOU ;
- 3 000 mouvements tirés au hasard pour chaque sensibilité (0 à 7) et des
  bornes variées, comparés à un calcul en Python (différence signée,
  restes gardés, bornes), passage de 255 à 0 compris ;
- boutons (enfoncés, relâchés, tenus au départ), molette, mo_sync ;
- mo_save puis mo_init relit le réglage ; réglage hors limites refusé ;
- mo_end : plus de rapport ($FFFF) ; la fenêtre 1 n'est jamais touchée.
Code de retour : 0 si tout est bon.
"""
import os
import random
import subprocess
import sys
import tempfile

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(ICI)
sys.path.insert(0, os.path.join(ICI, "pylib"))
from py65.devices.mpu6502 import MPU          # noqa: E402
from py65.memory import ObservableMemory      # noqa: E402

ROUTINES = ("mo_init", "mo_poll", "mo_sync", "mo_save", "mo_end", "mo_setn")


def assembler():
    xa = os.environ.get("XA") or os.path.join(ICI, "xa")
    if not os.path.exists(xa):
        xa = "xa"
    d = tempfile.mkdtemp()
    src = os.path.join(d, "w.s")
    with open(src, "w") as f:
        f.write("* = $0500\n")
        for r in ROUTINES:
            f.write(" jmp %s\n" % r)
        f.write('#include "mou_inc.s"\n')
    binf, lab = os.path.join(d, "w.bin"), os.path.join(d, "w.lab")
    subprocess.run([xa, "-I", os.path.join(RACINE, "progs"), "-o", binf,
                    "-l", lab, src], check=True)
    sym = {}
    for ligne in open(lab):
        a, nom = ligne.split()[:2]
        sym[nom] = int(a, 16)
    return open(binf, "rb").read(), sym


class Loci:
    """MIA du LOCI : pile d'échange, opérations, fenêtres de la XRAM."""

    def __init__(self, mem, present=True):
        self.mem = mem
        self.xram = [0] * 65536
        self.entree, self.sortie = [], []
        self.param = 0
        self.code = [0xB8, 0x50, 0xFE, 0xA9, 0, 0xA2, 0, 0x60]
        self.addr0, self.step0 = 0, 1
        self.mou = 0xFFFF
        self.fichiers = {}
        self.ouverts = {}
        self.fen1 = False                       # fenêtre 1 touchée
        self.present = present
        mem.subscribe_to_read(range(0x300, 0x400), self.lire)
        mem.subscribe_to_write(range(0x300, 0x400), self.ecrire)

    def lire(self, a):
        if not self.present:
            return 0x4C if a == 0x319 else 0xFF
        if a == 0x319:
            return ord("L")
        if a == 0x3A4:
            v = self.xram[self.addr0]
            self.addr0 = (self.addr0 + self.step0) & 0xFFFF
            return v
        if a in (0x3A8, 0x3A9, 0x3AA, 0x3AB):
            self.fen1 = True
        if a == 0x3AC:
            return self.sortie.pop(0) if self.sortie else 0
        if 0x3B0 <= a < 0x3B8:
            return self.code[a - 0x3B0]
        return 0

    def ecrire(self, a, v):
        if not self.present:
            return
        if a == 0x3A5:
            self.step0 = v - 256 if v > 127 else v
        elif a == 0x3A6:
            self.addr0 = (self.addr0 & 0xFF00) | v
        elif a == 0x3A7:
            self.addr0 = (self.addr0 & 0xFF) | v << 8
        elif a in (0x3A8, 0x3A9, 0x3AA, 0x3AB):
            self.fen1 = True
        elif a == 0x3AC:
            self.entree.append(v)
        elif a == 0x3B4:
            self.param = v
        elif a == 0x3AF:
            self.operation(v)

    def rendre(self, r):
        r &= 0xFFFF
        self.code = [0xB8, 0x50, 0x00, 0xA9, r & 255, 0xA2, r >> 8, 0x60]

    def operation(self, op):
        e, self.entree = self.entree, []
        if op == 0:
            self.sortie = []
            self.rendre(0)
        elif op == 0x01:                        # XREG
            if len(e) != 5 or e[0] != 0:
                return self.rendre(-1)
            if e[1] == 0 and e[2] == 1:
                self.mou = e[3] << 8 | e[4]
            self.rendre(0)
        elif op == 0x14:                        # open
            nom = bytes(reversed(e)).decode()
            if nom not in self.fichiers:
                if not self.param & 0x10:
                    return self.rendre(-1)
                self.fichiers[nom] = []
            fd = 3 + len(self.ouverts)
            self.ouverts[fd] = [nom, 0]
            self.rendre(fd)
        elif op == 0x15:                        # close
            self.rendre(0 if self.ouverts.pop(self.param, None) else -1)
        elif op == 0x16:                        # read_xstack
            nom, pos = self.ouverts[self.param]
            n = e[0] << 8 | e[1]
            d = self.fichiers[nom][pos:pos + n]
            self.ouverts[self.param][1] += len(d)
            self.sortie = list(d)
            self.rendre(len(d))
        elif op == 0x18:                        # write_xstack
            nom, pos = self.ouverts[self.param]
            d = list(reversed(e))
            f = self.fichiers[nom]
            f[pos:pos + len(d)] = d
            self.ouverts[self.param][1] += len(d)
            self.rendre(len(d))
        else:
            self.rendre(-1)

    # La souris : comme loci_mou_report ; avant XREG, ce qu'il y a en
    # $FF00 (le rapport n'y est écrit qu'au mouvement suivant)
    def souris(self, boutons, dx=0, dy=0, molette=0):
        m = 0xFF00 if self.mou == 0xFFFF else self.mou
        x = self.xram
        x[m] = boutons
        x[m + 1] = (x[m + 1] + dx) & 255
        x[m + 2] = (x[m + 2] + dy) & 255
        x[m + 3] = (x[m + 3] + molette) & 255


class Banc:
    def __init__(self, binaire, sym, present=True):
        self.sym = sym
        self.mem = ObservableMemory()
        for i, b in enumerate(binaire):
            self.mem[0x500 + i] = b
        self.loci = Loci(self.mem, present)
        self.cpu = MPU(memory=self.mem)

    def appel(self, nom):
        n = ROUTINES.index(nom)
        m, c = self.mem, self.cpu
        m[0x1000:0x1003] = [0x20, 0x00 + 3 * n, 0x05]
        c.pc = 0x1000
        k = 0
        while c.pc != 0x1003:
            c.step()
            k += 1
            if k > 100_000:
                raise RuntimeError("%s ne revient pas" % nom)
        return c.a, c.p & 1

    def __getitem__(self, nom):
        return self.mem[self.sym[nom]]

    def __setitem__(self, nom, v):
        self.mem[self.sym[nom]] = v


def signe(v):
    return v - 256 if v > 127 else v


def main():
    binaire, sym = assembler()
    print("mou_inc.s : %d octets" % (len(binaire) - 3 * len(ROUTINES)))
    echecs = []

    def verifie(cond, msg):
        if not cond:
            echecs.append(msg)
            print("ECHEC", msg)

    # Sans LOCI
    b = Banc(binaire, sym, present=False)
    a, c = b.appel("mo_init")
    verifie(c == 1 and b["mo_on"] == 0, "sans LOCI : mo_init doit refuser")
    a, c = b.appel("mo_poll")
    verifie(a == 0, "sans LOCI : mo_poll doit rendre 0")

    # Départ, puis mouvements au hasard
    hasard = random.Random(1)
    for n in range(8):
        b = Banc(binaire, sym)
        L = b.loci
        L.souris(0, hasard.randrange(256), hasard.randrange(256), hasard.randrange(256))
        b["mo_unit"] = max(0, n - 2)
        a, c = b.appel("mo_init")
        verifie(c == 0 and b["mo_on"] == 1, "n=%d : mo_init doit accepter" % n)
        verifie(L.mou == 0xFF00, "rapport en $FF00 (%04X)" % L.mou)
        verifie(b["mo_reg"] == 2, "réglage par défaut 2")
        b["mo_n"] = n
        xmax, ymax = hasard.choice([(239, 199), (39, 27), (255, 255), (0, 5)])
        b["mo_xmax"], b["mo_ymax"] = xmax, ymax
        x = hasard.randrange(xmax + 1)
        y = hasard.randrange(ymax + 1)
        b["mo_x"], b["mo_y"] = x, y
        rx = ry = 0
        bt = 0
        for i in range(3000):
            dx = hasard.randint(-127, 127) if hasard.random() < .5 else hasard.randint(-3, 3)
            dy = hasard.randint(-127, 127) if hasard.random() < .5 else hasard.randint(-3, 3)
            dw = hasard.randint(-5, 5) if hasard.random() < .2 else 0
            nb = hasard.randrange(8) if hasard.random() < .1 else bt
            L.souris(nb, dx, dy, dw)
            a, c = b.appel("mo_poll")
            chg = 0
            for d, r, p, mx, k in ((dx, rx, x, xmax, 0), (dy, ry, y, ymax, 1)):
                s = d + r
                r = s & ((1 << n) - 1)
                q = s >> n
                np_ = min(max(p + q, 0), mx)
                if np_ != p:
                    chg |= 1
                if k == 0:
                    rx, x = r, np_
                else:
                    ry, y = r, np_
            if dw:
                chg |= 4
            if nb != bt:
                chg |= 2
            bp, br = nb & ~bt & 7, bt & ~nb & 7
            bt = nb
            obtenu = (b["mo_x"], b["mo_y"], signe(b["mo_w"]), b["mo_b"],
                      b["mo_bp"], b["mo_br"], a)
            attendu = (x, y, dw, bt, bp, br, chg)
            if obtenu != attendu:
                verifie(False, "n=%d, essai %d : %s au lieu de %s" % (n, i, obtenu, attendu))
                break
        verifie(not L.fen1, "n=%d : la fenêtre 1 a été touchée" % n)

    # Bouton tenu au départ, mo_sync
    b = Banc(binaire, sym)
    L = b.loci
    L.souris(1, 10, 20, 30)
    b.appel("mo_init")
    L.souris(1, 50, 0, 0)
    a, c = b.appel("mo_poll")
    verifie(b["mo_bp"] == 0 and b["mo_b"] == 1, "bouton tenu au départ : pas un clic")
    L.souris(3, 100, 100, 3)
    b.appel("mo_sync")
    x0, y0 = b["mo_x"], b["mo_y"]
    a, c = b.appel("mo_poll")
    verifie(a == 0 and (b["mo_x"], b["mo_y"]) == (x0, y0) and b["mo_bp"] == 0,
            "mo_sync : le mouvement d'avant doit être oublié (A=%d)" % a)

    # Réglage gardé dans 0:CPA.MOU
    b["mo_reg"] = 3
    a, c = b.appel("mo_save")
    verifie(c == 0 and L.fichiers.get("0:CPA.MOU") == [3], "mo_save : %s" % L.fichiers)
    b["mo_reg"] = 0
    b["mo_unit"] = 2
    b.appel("mo_init")
    verifie(b["mo_reg"] == 3 and b["mo_n"] == 5, "réglage relu : %d, n=%d" % (b["mo_reg"], b["mo_n"]))
    b["mo_unit"] = 6
    b.appel("mo_setn")
    verifie(b["mo_n"] == 7, "mo_n borné à 7")
    L.fichiers["0:CPA.MOU"] = [9]
    b.appel("mo_init")
    verifie(b["mo_reg"] == 2, "réglage hors limites : défaut")
    verifie(not L.ouverts, "fichiers restés ouverts : %s" % L.ouverts)

    # Fin
    b.appel("mo_end")
    verifie(L.mou == 0xFFFF and b["mo_on"] == 0, "mo_end : rapport arrêté")
    a, c = b.appel("mo_poll")
    verifie(a == 0, "après mo_end : mo_poll rend 0")
    a, c = b.appel("mo_save")
    verifie(c == 1, "après mo_end : mo_save refuse")

    print("OK" if not echecs else "%d echec(s)" % len(echecs))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
