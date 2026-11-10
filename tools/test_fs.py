#!/usr/bin/env python3
"""Système de fichiers (src/fs.s) dans un 6502 simulé (py65, tools/pylib),
sans émulateur : fin de fichier et ajout en fin de fichier.

  python3 tools/test_fs.py [cpa_sys.bin cpa_sys.sym]

Le système disque (build/cpa_sys.bin, chargé en $C000) est appelé par
l'entrée du BDOS ; disk_read et disk_write sont remplacés par une
disquette vide en mémoire (étiquette du format, répertoire libre).
Pour un fichier de 100, 128 et 256 enregistrements (128 et 256 : extents
de 16 Ko pleins) : écriture, relecture, fin de fichier rendue deux fois
de suite (fonction 20 : 1), position (36), ajout d'un enregistrement
après la fin (21), fermeture (16), taille (35), relecture de tout.
Défaut gardé : après la fin d'un fichier multiple de 16 Ko, une lecture
rendait de vieilles données et une écriture écrasait l'extent précédent.
Code de retour : 0 si tout est bon.
"""
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, "pylib"))
from py65.devices.mpu6502 import MPU          # noqa: E402

BUILD = os.path.join(os.path.dirname(ICI), "build")
FCB, DMA = 0x2000, 0x3000


class Banc:
    def __init__(self, binaire, sym):
        self.sym = sym
        self.mem = [0] * 65536
        for i, b in enumerate(binaire[:16384]):
            self.mem[0xC000 + i] = b
        d = sym["DIR_LSN"]
        self.disque = {}
        for s in range(16):                     # répertoire : 128 entrées libres
            self.disque[d + s] = [0xE5 if i % 32 == 0 else 0 for i in range(256)]
        self.disque[d][0:12] = [0x20] + list(b"CPA-2X80-2K")
        self.mem[sym["act_drv"]] = 0xFF         # aucun lecteur choisi
        self.cpu = MPU(memory=self.mem)

    def bdos(self, fonction, ay=0):
        m, c, s = self.mem, self.cpu, self.sym
        m[0x1000:0x1003] = [0x20, s["bdos"] & 255, s["bdos"] >> 8]
        c.pc, c.x, c.a, c.y = 0x1000, fonction, ay & 255, ay >> 8
        n = 0
        while c.pc != 0x1003:
            if c.pc in (s["disk_read"], s["disk_write"]):
                lsn = m[s["dsk_lsn"]] | m[s["dsk_lsn"] + 1] << 8
                buf = m[s["dsk_buf"]] | m[s["dsk_buf"] + 1] << 8
                if c.pc == s["disk_read"]:
                    m[buf:buf + 256] = self.disque.get(lsn, [0] * 256)
                else:
                    self.disque[lsn] = m[buf:buf + 256]
                bas = m[0x100 + ((c.sp + 1) & 255)]     # RTS, A = 0 (Z = 1)
                haut = m[0x100 + ((c.sp + 2) & 255)]
                c.sp = (c.sp + 2) & 255
                c.pc = ((haut << 8 | bas) + 1) & 0xFFFF
                c.a = 0
                c.p |= 2
            else:
                c.step()
            n += 1
            if n > 20_000_000:
                raise RuntimeError("le BDOS ne revient pas (fonction %d)" % fonction)
        return c.a

    def fcb(self):
        self.mem[FCB:FCB + 36] = [0] + list(b"TEST    DAT") + [0] * 24

    def r0(self):
        return self.mem[FCB + 33] | self.mem[FCB + 34] << 8


def essai(b, n):
    """Liste des défauts pour un fichier de n enregistrements."""
    m, bad = b.mem, []

    def veut(quoi, vu, attendu):
        if vu != attendu:
            bad.append("%s : %s, attendu %s" % (quoi, vu, attendu))

    b.fcb(); b.bdos(19, FCB)
    b.fcb(); b.bdos(26, DMA)
    veut("création", b.bdos(22, FCB), 0)
    for r in range(n):
        m[DMA:DMA + 128] = [r & 255] * 128
        veut("écriture %d" % r, b.bdos(21, FCB), 0)
    veut("fermeture", b.bdos(16, FCB), 0)
    b.fcb(); veut("ouverture", b.bdos(15, FCB), 0)
    for r in range(n):
        veut("lecture %d" % r, (b.bdos(20, FCB), m[DMA]), (0, r & 255))
    veut("fin de fichier", b.bdos(20, FCB), 1)
    veut("fin de fichier, encore", b.bdos(20, FCB), 1)
    b.bdos(36, FCB); veut("position (36)", b.r0(), n)
    m[DMA:DMA + 128] = [0xAA] * 128
    veut("ajout après la fin", b.bdos(21, FCB), 0)
    veut("fermeture après l'ajout", b.bdos(16, FCB), 0)
    b.fcb(); b.bdos(35, FCB); veut("taille (35)", b.r0(), n + 1)
    b.fcb(); b.bdos(15, FCB)
    for r in range(n):
        veut("relecture %d" % r, (b.bdos(20, FCB), m[DMA]), (0, r & 255))
    veut("enregistrement ajouté", (b.bdos(20, FCB), m[DMA]), (0, 0xAA))
    veut("fin après l'ajout", b.bdos(20, FCB), 1)
    return bad


def main():
    binf = sys.argv[1] if len(sys.argv) > 2 else os.path.join(BUILD, "cpa_sys.bin")
    symf = sys.argv[2] if len(sys.argv) > 2 else os.path.join(BUILD, "cpa_sys.sym")
    sym = {}
    for ligne in open(symf):
        mots = ligne.split()
        if len(mots) >= 2:
            sym[mots[1]] = int(mots[0], 16)
    b = Banc(open(binf, "rb").read(), sym)
    code = 0
    for n in (100, 128, 256):
        bad = essai(b, n)
        print("%3d enregistrements : %s" % (n, "OK" if not bad else "ECHEC"))
        for t in bad[:6]:
            print("    " + t)
        code |= bool(bad)
    return code


if __name__ == "__main__":
    sys.exit(main())
