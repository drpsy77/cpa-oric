#!/usr/bin/env python3
"""Pilote disque (src/disk.s) face à un contrôleur qui ne répond plus, dans
un 6502 simulé (py65, tools/pylib), sans émulateur.

  python3 tools/test_fdc.py [cpa_sys.bin cpa_sys.sym]

Le système disque (build/cpa_sys.bin, chargé en $C000) appelle disk_read
et disk_write sur un WD1793 simulé dans l'état vu sur le LOCI après un
RESET pendant DISKCOPY : toujours occupé (bit 0 de l'état), sans erreur
dans l'état, sans DRQ. Deux variantes : INTRQ levée (la commande paraît
finie : on arrive à la fin du transfert, où l'attente du contrôleur
dépasse son délai) et INTRQ jamais levée (attente du premier octet
dépassée). Attendu dans les quatre cas : A = 1 (échec), jamais un accès
déclaré bon avec un tampon qui n'a pas été lu ou un secteur pas écrit.
Chaque cas fait attendre ~7 s d'Oric (délais du pilote), ~3 s ici.
Code de retour : 0 si tout est bon.
"""
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, "pylib"))
from py65.devices.mpu6502 import MPU          # noqa: E402
from py65.memory import ObservableMemory      # noqa: E402

BUILD = os.path.join(os.path.dirname(ICI), "build")


def essai(binaire, sym, routine, intrq):
    mem = ObservableMemory()
    for i, b in enumerate(binaire):
        mem[0xC000 + i] = b
    # $0310 état : occupé ; $0311 piste 0 ; $0314 bit 7 = /INTRQ ;
    # $0318 bit 7 = /DRQ ; $0319 : pas de LOCI (pas de liste des lecteurs)
    io = {0x310: 0x01, 0x311: 0x00, 0x314: 0x7F if intrq else 0xFF,
          0x318: 0xFF, 0x319: 0x00}
    mem.subscribe_to_read(range(0x300, 0x400), lambda a: io.get(a, 0xFF))
    mem.subscribe_to_write(range(0x300, 0x400), lambda a, v: None)
    for n, v in (("dsk_lsn", 0), ("dsk_lsn+1", 0), ("dsk_buf", 0x00),
                 ("dsk_buf+1", 0x20), ("buf_drv", 0), ("phy_drv", 0)):
        nom, plus = (n[:-2], 1) if n.endswith("+1") else (n, 0)
        mem[sym[nom] + plus] = v
    for i, b in enumerate([0x20, sym[routine] & 0xFF, sym[routine] >> 8]):
        mem[0x1000 + i] = b                     # JSR routine, puis $1003
    cpu = MPU(memory=mem)
    cpu.pc = 0x1000
    n = 0
    while cpu.pc != 0x1003:
        cpu.step()
        n += 1
        if n > 60_000_000:
            return None, cpu.processorCycles
    return cpu.a, cpu.processorCycles


def main():
    binf = sys.argv[1] if len(sys.argv) > 2 else os.path.join(BUILD, "cpa_sys.bin")
    symf = sys.argv[2] if len(sys.argv) > 2 else os.path.join(BUILD, "cpa_sys.sym")
    binaire = open(binf, "rb").read()
    sym = {}
    for ligne in open(symf):
        a, nom = ligne.split()[:2]
        sym[nom] = int(a, 16)
    echecs = 0
    for routine in ("disk_read", "disk_write"):
        for intrq in (True, False):
            a, cycles = essai(binaire, sym, routine, intrq)
            ok = a == 1
            echecs += not ok
            print("%-5s %s, INTRQ %s : %s (%.1f s d'Oric)" % (
                "OK" if ok else "ECHEC", routine, "levee" if intrq else "jamais levee",
                "pas de retour" if a is None else "A=%d" % a, cycles / 1e6))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
