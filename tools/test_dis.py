#!/usr/bin/env python3
"""DIS.COM : le source écrit se réassemble en un fichier identique.

  python3 tools/test_dis.py [NOM.COM ...]     (défaut : tous)

DIS.COM (build/progs) tourne dans le 6502 simulé (tools/run_com.py) ;
le source NOM.ASM est réassemblé par xa et comparé au fichier de départ
complété par des ^Z (comme sur la disquette) ; quelques-uns le sont aussi
par ASM.COM. Fichiers :
1. les .COM de CP/A (build/progs) ;
2. la ROM 1.1 (tools/oricutron/roms/basic11b.rom, en $C000 ; vecteurs
   en $FFFA), si elle est là ;
3. des cas fabriqués : absolu sur la page zéro, code qui se chevauche
   (BIT qui saute un octet), code modifié par lui-même (Lxxxx+1),
   branchement hors du fichier, codes non documentés, /E, guillemets et
   points-virgules dans les chaînes, suites d'octets égaux, noms
   d'ATMOS.SYM (déclarés en tête).
"""
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ProcessPoolExecutor

R = os.path.dirname(os.path.abspath(__file__))
B = os.path.join(R, "..", "build", "progs")
XA = os.path.join(R, "xa")
ROM = os.path.join(R, "oricutron", "roms", "basic11b.rom")


def disque(d):
    return d + b"\x1a" * (-len(d) % 128)


def dis(job):
    """DIS sur data (fichier nom) -> source ; xa (et ASM.COM) -> comparaison.
    job = (ATMOS.SYM, nom, data, args, asm, attendus) ; -> (écarts, lignes)"""
    sym, nom, data, args, asm, attendus = job
    tmp = tempfile.mkdtemp()
    try:
        shutil.copy(sym, tmp)
        return essai(tmp, nom, data, args, asm, attendus)
    finally:
        shutil.rmtree(tmp)


def essai(tmp, nom, data, args, asm, attendus):
    out = []
    ko = 0
    for f in ("DIS.COM", "ASM.COM"):
        shutil.copy(os.path.join(B, f), tmp)
    open(os.path.join(tmp, nom), "wb").write(data)
    p = subprocess.run([sys.executable, os.path.join(R, "run_com.py"), tmp, "DIS.COM", nom]
                       + list(args), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    sortie = p.stdout.decode("latin-1")
    base = nom.split(".")[0]
    src = os.path.join(tmp, base + ".ASM")
    if not os.path.exists(src):
        return 1, ["DIS ECHOUE : %s %s\n%s" % (nom, " ".join(args), sortie)]
    texte = open(src, "rb").read()
    ref = disque(data)
    q = subprocess.run([XA, "-o", os.path.join(tmp, "x.bin"), "-e", os.path.join(tmp, "x.err"),
                        src], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    x = open(os.path.join(tmp, "x.bin"), "rb").read() if q.returncode == 0 else b""
    bon = disque(x) == ref
    msg = "%s %s : %d octets, %d lignes" % (nom, " ".join(args), len(data), texte.count(b"\n"))
    if asm:
        # ASM.COM écrit BASE.COM : le fichier lu est renommé avant
        os.replace(os.path.join(tmp, nom), os.path.join(tmp, "ORIG.BIN"))
        subprocess.run([sys.executable, os.path.join(R, "run_com.py"), tmp, "ASM.COM", base],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        c = os.path.join(tmp, base + ".COM")
        y = open(c, "rb").read() if os.path.exists(c) else b""
        bon_asm = y[:len(ref)] == ref and not any(y[len(ref):])
        msg += ", ASM.COM %s" % ("identique" if bon_asm else "DIFFERENT")
        bon = bon and bon_asm
    if bon:
        out.append("identique : " + msg)
    else:
        ko += 1
        out.append("DIFFERENT : " + msg)
        if x:
            for i, (u, v) in enumerate(zip(disque(x), ref)):
                if u != v:
                    out.append("  premier écart en +%04X : %02X au lieu de %02X" % (i, u, v))
                    break
            else:
                out.append("  longueurs : %d / %d" % (len(disque(x)), len(ref)))
        else:
            out.append("  xa : " + open(os.path.join(tmp, "x.err")).read()[:300])
    for a in attendus:
        if a not in texte:
            ko += 1
            out.append("ABSENT du source : %s" % a.decode())
    return ko, out


def fabriques():
    """cas tordus, octet par octet ($9800) -> travaux"""
    c = bytes([0xAD, 0x12, 0x00,            # 9800 lda $0012 absolu -> .byt
               0xBD, 0x80, 0x00,            # 9803 lda $0080,x absolu -> .byt
               0xB9, 0x80, 0x00,            # 9806 lda $0080,y (pas de zp,y)
               0x20, 0x50, 0x00,            # 9809 jsr $0050
               0xA9, 0x01,                  # 980C lda #1
               0x2C, 0xA9, 0x02,            # 980E bit $02A9, sauté en 980F
               0xF0, 0xFC,                  # 9811 beq $980F (lda #2)
               0x8D, 0x1B, 0x98,            # 9813 sta L981A+1
               0x20, 0xC1, 0xF5,            # 9816 jsr PrintChar
               0xEA,                        # 9819 nop
               0xA9, 0x00,                  # 981A lda #0
               0x8D, 0x00, 0x03,            # 981C sta VIA_ORB
               0x90, 0x80,                  # 981F bcc $97A1 (hors du fichier)
               0x20, 0x81, 0xF5,            # 9821 jsr $F581 (sans nom)
               0x6C, 0x40, 0x98,            # 9824 jmp (L9840)
               0x60,                        # 9827 rts (non suivi)
               0x02, 0x03])                 # 9828 codes non documentés
    c += b'Il a dit "oui"; ok \0'          # 982A
    c += bytes([0xFF] * 30)                 # 983E (L9840 au milieu)
    c += bytes([0xEA, 0xEA, 0x60])          # 985C : /E
    c += bytes(range(0x20, 0x90))           # 985F
    jobs = [("CAS.BIN", c, ["9800"], True, ())]
    jobs.append(("CAS.BIN", c, ["9800", "/E", "985C", "1234"], False, (b"PrintChar = $F5C1", b"VIA_ORB = $0300", b".byt $AD,$12,$00",
                    b".byt $BD,$80,$00", b"lda $0080,y", b"jsr $0050", b"L981A+1",
                    b"jsr PrintChar", b"sta VIA_ORB", b"bcc $97A1", b"jsr $F581",
                    b"jmp (L9840)", b".byt $2C", b"L985C   nop", b"L980F   lda #$02", b'"Il a dit "',
                    b"L9840   .dsb 28,$FF")))
    # branchement qui sort de $0000-$FFFF, vecteurs en $FFFA
    fin = bytes([0xEA] * 120 + [0xD0, 0x10, 0x80, 0xFF, 0x90, 0xFF, 0xA0, 0xFF])
    jobs.append(("FIN.BIN", fin, ["FF80"], False, ()))
    # instruction coupée par la fin du fichier
    jobs.append(("COUPE.BIN", bytes([0xEA] * 127 + [0x20]), ["1000"], False, ()))
    # chargé en $0000 : pas d'étiquette en page zéro
    jobs.append(("ZP.BIN", bytes([0xA5, 0x10, 0xAD, 0x05, 0x00, 0x4C, 0x00, 0x00])
                 + bytes(range(120)), ["0"], False, (b".byt $AD,$05,$00", b"jmp L0000")))
    return jobs


def main():
    if not os.path.exists(os.path.join(B, "DIS.COM")):
        sys.exit("build/progs/DIS.COM absent : ./build.sh d'abord")
    tmp = tempfile.mkdtemp()
    sym = os.path.join(tmp, "ATMOS.SYM")
    try:
        subprocess.run([sys.executable, os.path.join(R, "mksym.py"), sym],
                       stdout=subprocess.PIPE, check=True)
        noms = sys.argv[1:]
        jobs = []
        if not noms:
            jobs = fabriques()
            if os.path.exists(ROM):
                jobs.append(("BASIC11.ROM", open(ROM, "rb").read(), ["C000"], False,
                             (b"\r\nStartBASIC cld", b"\r\nReset   ldx #$FF", b"jsr SetScreen",
                              b"sta VIA_DDRA")))
            noms = sorted(f for f in os.listdir(B) if f.endswith(".COM"))
        for n in noms:
            jobs.append((n, open(os.path.join(B, n), "rb").read(), [],
                         n in ("HELLO.COM", "SET.COM"), ()))
        ko = 0
        with ProcessPoolExecutor(os.cpu_count()) as ex:
            for k, out in ex.map(dis, [(sym,) + tuple(j) for j in jobs]):
                ko += k
                for l in out:
                    print(l, flush=True)
    finally:
        shutil.rmtree(tmp)
    print("DIS : %s" % ("tout est bon" if not ko else "%d DIFFERENCE(S)" % ko))
    sys.exit(1 if ko else 0)


if __name__ == "__main__":
    main()
