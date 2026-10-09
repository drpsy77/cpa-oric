#!/usr/bin/env python3
"""Non-régression des images compressées et des animations, sans émulateur.

  python3 tools/test_anim.py          (après ./build.sh)

1. Chaque image de files/anim/*.ANI est décodée par h_unz (hires.inc,
   assemblé dans VOIR.COM) dans le 6502 simulé (py65), et comparée au
   décodeur Python (lzhir.py) : écran et pointeur rendu. Les cycles
   mesurés recalent le modèle de coût de lzhir.py (écart affiché).
2. VOIR NOM.ANI 2 est exécuté en entier (tools/run_com.py) : l'écran final
   doit être la dernière image, et l'écart entre deux images doit être
   leur délai, ou plus seulement si le décodage a débordé.
3. VOIR LOGO.HIZ doit afficher l'image.
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "pylib"))
from py65.devices.mpu6502 import MPU
import lzhir

XA = os.environ.get("XA", os.path.join(HERE, "xa"))
ko = 0


def fail(msg):
    global ko
    ko += 1
    print("ECHEC : " + msg)


def counts(comp, n=8000):
    """jetons du flux : littéraux, copies, octets copiés, sauts, drapeaux"""
    pos = d = 0
    c = [0, 0, 0, 0, 0, 1]
    while d < n:
        f = comp[pos]
        pos += 1
        c[4] += 1
        for b in range(8):
            if d >= n:
                break
            if f >> b & 1:
                c[0] += 1
                pos += 1
                d += 1
            else:
                dist = comp[pos] | comp[pos + 1] << 8
                L = min(comp[pos + 2], n - d)
                pos += 3
                if dist == 0:
                    c[3] += 1
                else:
                    c[1] += 1
                    c[2] += L
                d += L
    return c


def main():
    t = tempfile.mkdtemp()
    subprocess.check_call([XA, "-o", os.path.join(t, "VOIR.COM"), "-l", os.path.join(t, "voir.lab"), "voir.s"],
                          cwd=os.path.join(ROOT, "progs"))
    lab = {}
    for l in open(os.path.join(t, "voir.lab")):
        p = l.split()
        if len(p) == 2:
            lab[p[1]] = int(p[0], 16)
    code = open(os.path.join(t, "VOIR.COM"), "rb").read()
    anims = sorted(f for f in os.listdir(os.path.join(ROOT, "files", "anim")) if f.endswith(".ANI"))

    # 1. h_unz image par image
    rows, meas = [], []
    for a in anims:
        fr, loop = lzhir.read_ani(open(os.path.join(ROOT, "files", "anim", a), "rb").read())
        scr = bytes([lzhir.BLANK]) * 8000
        for i, (dl, comp) in enumerate(fr):
            mem = bytearray(65536)
            mem[0x500:0x500 + len(code)] = code
            mem[0x2000:0x2000 + len(comp)] = comp
            mem[0xA000:0xA000 + 8000] = scr
            mem[lab["h_lines"]] = 200
            mem[0x400:0x403] = bytes([0x20, lab["h_unz"] & 255, lab["h_unz"] >> 8])
            m = MPU(memory=mem)
            m.pc, m.sp, m.a, m.y = 0x400, 0xFD, 0x00, 0x20
            c0 = m.processorCycles
            while m.pc != 0x403:
                m.step()
            want, used = lzhir.decode(comp, scr)
            if bytes(mem[0xA000:0xA000 + 8000]) != want:
                fail("%s image %d : ecran" % (a, i + 1))
            if (m.a | m.y << 8) != 0x2000 + used:
                fail("%s image %d : pointeur rendu" % (a, i + 1))
            if any(mem[0xBF40:0xC000]):
                fail("%s image %d : ecriture apres l'image" % (a, i + 1))
            rows.append(counts(comp))
            meas.append(m.processorCycles - c0)
            scr = want
        print("h_unz : %s, %d images" % (a, len(fr)))
    err = []
    for r, y in zip(rows, meas):
        e = lzhir.C_LIT * r[0] + lzhir.C_COPY * r[1] + lzhir.C_BYTE * r[2] + lzhir.C_SKIP * r[3] \
            + lzhir.C_FLAG * r[4] + lzhir.C_CALL * r[5]
        err.append((e - y) / y)
    print("modele de lzhir.py : ecart moyen %+.1f %%, au plus %+.1f %%"
          % (100 * sum(err) / len(err), 100 * max(err, key=abs)))
    if max(abs(e) for e in err) > 0.03:
        fail("modele de cout a recaler")
    try:
        import numpy as np
        coef = np.linalg.lstsq(np.array(rows, float), np.array(meas, float), rcond=None)[0]
        print("  coefficients mesures : litteral %.1f, copie %.1f + %.1f/octet, saut %.1f, drapeaux %.1f, appel %.1f"
              % tuple(coef))
    except ImportError:
        pass

    # 2. VOIR NOM.ANI 2 en entier
    for f in anims + ["LOGO.HIZ"]:
        src = os.path.join(ROOT, "files", "anim", f)
        open(os.path.join(t, f), "wb").write(open(src, "rb").read())
    env = dict(os.environ, PROF="%04X" % lab["h_unz"], PROF_OUT=os.path.join(t, "prof.txt"),
               DUMP=os.path.join(t, "dump.mem"))
    for a in anims:
        subprocess.run([sys.executable, os.path.join(HERE, "run_com.py"), t, "VOIR.COM", a, "2"],
                       env=env, stdout=subprocess.DEVNULL, check=True)
        data = open(os.path.join(t, a), "rb").read()
        imgs = lzhir.play(data)
        fr, loop = lzhir.read_ani(data)
        mem = open(os.path.join(t, "dump.mem"), "rb").read()
        if mem[0xA000:0xA000 + 8000] != imgs[-1]:
            fail("VOIR %s 2 : l'ecran final n'est pas la derniere image" % a)
        calls = [tuple(map(int, l.split())) for l in open(os.path.join(t, "prof.txt"))]
        n = len(fr) - loop
        order = list(range(n)) + ([n] + list(range(1, n)) if loop else list(range(n)))
        if len(calls) != len(order):
            fail("VOIR %s 2 : %d images jouees au lieu de %d" % (a, len(calls), len(order)))
        bad = 0
        for k in range(1, len(calls)):
            gap = (calls[k][0] - calls[k - 1][0]) / 20000
            delay = fr[order[k - 1]][0]
            late = -(-calls[k - 1][1] // 20000)
            if round(gap) not in (delay, max(delay, late), max(delay, late) + 1) or abs(gap - round(gap)) > 0.05:
                bad += 1
        if bad:
            fail("VOIR %s 2 : %d ecarts entre images hors cadence" % (a, bad))
        print("VOIR %s 2 : %d images, ecran final et cadence %s" % (a, len(calls), "corrects" if not bad else "FAUX"))
    subprocess.run([sys.executable, os.path.join(HERE, "run_com.py"), t, "VOIR.COM", "LOGO.HIZ"],
                   env=dict(os.environ, DUMP=os.path.join(t, "dump.mem")), stdout=subprocess.DEVNULL, check=True)
    mem = open(os.path.join(t, "dump.mem"), "rb").read()
    want = lzhir.decode(open(os.path.join(t, "LOGO.HIZ"), "rb").read(), bytes(8000))[0]
    if mem[0xA000:0xA000 + 8000] != want or mem[0xBFDF] != 0x1E:
        fail("VOIR LOGO.HIZ")
    else:
        print("VOIR LOGO.HIZ : correct")
    print("animations : %d echec(s)" % ko)
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
