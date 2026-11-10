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
Disquette changée sans démarrage à chaud (après une seconde sans accès
disque) : un fichier créé sur la nouvelle ne doit pas prendre les blocs
d'un fichier qu'elle porte déjà ; un fichier ouvert puis allongé reçoit
une erreur (rien n'est pris), puis l'écriture suivante passe ; sans
changement de disquette, la pause ne gêne rien.
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
        a = c.a
        if fonction == 13:                      # la fonction 13 remet le DMA en $0480
            self.bdos(26, DMA)
        return a

    def fcb(self, nom=b"TEST    DAT"):
        self.mem[FCB:FCB + 36] = [0] + list(nom) + [0] * 24

    def pause(self, trames=100):
        """Le temps passe sans accès disque (compteur 50 Hz)."""
        t = (self.mem[0x21B] | self.mem[0x21C] << 8) + trames
        self.mem[0x21B], self.mem[0x21C] = t & 255, (t >> 8) & 255

    def ecrit(self, nom, n, v, cree=True):
        """Crée (ou ouvre) nom et y écrit n enregistrements de valeur v."""
        self.fcb(nom)
        r = [self.bdos(22 if cree else 15, FCB)]
        for _ in range(n):
            self.mem[DMA:DMA + 128] = [v] * 128
            r.append(self.bdos(21, FCB))
        r.append(self.bdos(16, FCB))
        return r

    def relit(self, nom, n, v):
        """True si nom fait n enregistrements de valeur v."""
        self.fcb(nom)
        if self.bdos(15, FCB):
            return False
        for _ in range(n):
            if self.bdos(20, FCB) or self.mem[DMA:DMA + 128] != [v] * 128:
                return False
        return self.bdos(20, FCB) == 1

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


def essai_change(b):
    """Disquette changée sans démarrage à chaud : liste des défauts."""
    import copy
    m, bad = b.mem, []
    GROS, NEUF = b"GROS    DAT", b"NEUF    DAT"
    m[b.sym["io_quiet"]] = 1                    # erreurs sans message
    vide = copy.deepcopy(b.disque)
    b.bdos(13); b.bdos(26, DMA)
    if any(b.ecrit(GROS, 300, 0x11)):
        bad.append("préparation de la disquette Y")
    pleine = copy.deepcopy(b.disque)            # Y : GROS.DAT, 19 blocs
    # 1. sans changement : une pause ne gêne pas
    b.pause()
    if any(b.ecrit(NEUF, 20, 0x22)) or not b.relit(GROS, 300, 0x11) \
            or not b.relit(NEUF, 20, 0x22):
        bad.append("pause sans changement : écriture refusée ou fichier abîmé")
    # 2. disquette vide lue (carte vide), puis Y remise sans démarrage à chaud
    b.disque = copy.deepcopy(vide)
    b.bdos(13)
    b.fcb(NEUF); b.bdos(15, FCB)                # carte de la vide en mémoire
    b.pause()
    b.disque = copy.deepcopy(pleine)
    if any(b.ecrit(NEUF, 20, 0x22)):
        bad.append("création après le changement : refusée")
    b.bdos(13)
    if not b.relit(GROS, 300, 0x11):
        bad.append("création après le changement : GROS.DAT abîmé")
    if not b.relit(NEUF, 20, 0x22):
        bad.append("création après le changement : NEUF.DAT faux")
    # 3. fichier ouvert sur la nouvelle disquette puis allongé : refus, puis bon
    b.disque = copy.deepcopy(vide)
    b.bdos(13)
    b.ecrit(NEUF, 2, 0x33)
    petite = copy.deepcopy(b.disque)            # Z : NEUF.DAT, 1 bloc
    b.disque = copy.deepcopy(pleine)
    b.bdos(13)
    b.fcb(GROS); b.bdos(15, FCB)                # carte de Y en mémoire
    b.pause()
    b.disque = copy.deepcopy(petite)
    b.disque[b.sym["DIR_LSN"]][64:96] = pleine[b.sym["DIR_LSN"]][32:64]
    b.disque[b.sym["DIR_LSN"]][64 + 12] = 9     # Z porte aussi un autre fichier
    b.fcb(NEUF); b.bdos(15, FCB)
    m[FCB + 32] = 16                            # enregistrement 16 : bloc neuf
    m[DMA:DMA + 128] = [0x44] * 128
    r1 = b.bdos(21, FCB)
    r2 = b.bdos(21, FCB)
    if (r1, r2) != (0xFF, 0):
        bad.append("allongement après le changement : %d puis %d, attendu 255 puis 0" % (r1, r2))
    m[b.sym["io_quiet"]] = 0
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
    bad = essai_change(b)
    print("disquette changée   : %s" % ("OK" if not bad else "ECHEC"))
    for t in bad:
        print("    " + t)
    code |= bool(bad)
    return code


if __name__ == "__main__":
    sys.exit(main())
