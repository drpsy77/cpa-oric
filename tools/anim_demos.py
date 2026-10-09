#!/usr/bin/env python3
"""Fabrique les animations de démonstration de la disquette cpa-anim.dsk.

  anim_demos.py DOSSIER      écrit CUBE.ANI, BALLE.ANI, VAISSEAU.ANI,
                             LOGO.HIZ et vaisseau.gif (la source du 3e)

  CUBE.ANI      cube au trait qui tourne : un quart de tour suffit pour
                boucler (le cube retombe sur lui-même)
  BALLE.ANI     balle qui rebondit devant une image tramée (seule la
                balle change : 25 images/s)
  VAISSEAU.ANI  un GIF animé contrasté (dessiné ici, puis passé par
                mkanim.py comme n'importe quel GIF)
  LOGO.HIZ      image fixe compressée (png2hir.py --hiz)

Les fichiers produits sont gardés dans files/anim/ : la construction de
la disquette (build.sh) n'a pas besoin de Pillow.
"""
import math
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image, ImageDraw
import lzhir
from png2hir import convert_image

W, H = 240, 200


def to_oric(im, seuil=None):
    data, _ = convert_image(im, H, False, seuil)
    return bytes(data)


def cube(n=12):
    """Rotation autour de l'axe vertical, cube penché : 90 degrés = la
    même image, donc n images couvrent un quart de tour et bouclent."""
    pts = [(x, y, z) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    edges = [(a, b) for a in range(8) for b in range(a + 1, 8)
             if sum(pts[a][k] != pts[b][k] for k in range(3)) == 1]
    tilt = math.radians(25)
    frames = []
    for f in range(n):
        im = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(im)
        a = (math.pi / 2) * f / n
        P = []
        for x, y, z in pts:
            x, z = x * math.cos(a) - z * math.sin(a), x * math.sin(a) + z * math.cos(a)
            y, z = y * math.cos(tilt) - z * math.sin(tilt), y * math.sin(tilt) + z * math.cos(tilt)
            s = 150 / (z + 4.2)
            P.append((120 + x * s, 100 + y * s))
        for e in edges:
            d.line([P[e[0]], P[e[1]]], fill=255)
        d.text((88, 186), "CP/A  ANIM", fill=255)
        frames.append(to_oric(im, 128))
    return frames


def fond():
    """Image de fond en niveaux de gris (tramée ensuite)."""
    im = Image.new("L", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            px[x, y] = int(110 + 50 * math.sin(x / 23.0) + 50 * math.cos(y / 17.0 + x / 40.0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 172, W - 1, H - 1], fill=60)          # sol
    d.polygon([(10, 172), (70, 70), (130, 172)], fill=200)  # montagnes
    d.polygon([(100, 172), (170, 50), (235, 172)], fill=150)
    d.ellipse([185, 12, 225, 52], fill=250)                 # soleil
    return im


def balle(n=30):
    """Le fond est tramé une seule fois (sinon le motif bouge partout) ;
    seules les cases touchées par la balle changent d'une image à l'autre."""
    bg = fond()
    base = to_oric(bg)
    out = []
    for f in range(n):
        t = f / n
        x = 30 + 180 * abs((2 * t) % 2 - 1)
        y = 155 - 130 * abs(math.sin(math.pi * 2 * t))
        im = bg.copy()
        d = ImageDraw.Draw(im)
        d.ellipse([x - 15, y - 15, x + 15, y + 15], fill=0)     # ballon :
        d.ellipse([x - 12, y - 12, x + 12, y + 12], fill=255)   # anneau et
        d.ellipse([x - 4, y - 12, x + 4, y + 12], fill=0)       # bande noirs
        d.line([(x - 12, y), (x + 12, y)], fill=0, width=2)
        ball = to_oric(im, 128)
        m = Image.new("1", (W, H), 0)
        ImageDraw.Draw(m).ellipse([x - 15, y - 15, x + 15, y + 15], fill=1)
        mp = m.load()
        b = bytearray(base)
        for row in range(H):
            for c in range(40):
                if any(mp[c * 6 + i, row] for i in range(6)):
                    b[row * 40 + c] = ball[row * 40 + c]
        out.append(bytes(b))
    return out


def vaisseau_gif(path, n=24):
    """GIF original, noir et blanc : un vaisseau traverse les étoiles."""
    random.seed(7)
    stars = [(random.randint(0, 3 * W), random.randint(0, H - 1), random.randint(1, 3)) for _ in range(70)]
    imgs = []
    for f in range(n):
        im = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(im)
        for sx, sy, v in stars:                       # étoiles qui défilent
            x = (sx - f * v * 6) % (3 * W)
            if x < W:
                d.line([(x, sy), (x + v * 2, sy)], fill=255)
        bob = 6 * math.sin(2 * math.pi * f / n)
        cx, cy = 120, 100 + bob
        hull = [(cx - 70, cy + 10), (cx + 60, cy + 10), (cx + 85, cy - 2), (cx + 60, cy - 12),
                (cx - 30, cy - 12), (cx - 55, cy - 30), (cx - 70, cy - 30)]
        d.polygon(hull, fill=255)
        d.polygon([(cx - 20, cy - 12), (cx + 10, cy - 12), (cx - 5, cy - 38), (cx - 25, cy - 38)], fill=255)
        d.rectangle([cx - 15, cy - 34, cx - 8, cy - 26], fill=0)          # hublot
        for k in range(4):
            d.ellipse([cx - 50 + k * 26, cy - 5, cx - 42 + k * 26, cy + 3], fill=0)
        flame = 18 + 10 * ((f % 3) / 2)                                   # réacteur
        d.polygon([(cx - 70, cy - 6), (cx - 70 - flame, cy), (cx - 70, cy + 6)], fill=255)
        imgs.append(im)
    imgs[0].save(path, save_all=True, append_images=imgs[1:], duration=80, loop=0)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    out = argv[1]
    os.makedirs(out, exist_ok=True)
    for name, frames, delay in (("CUBE.ANI", cube(), 5), ("BALLE.ANI", balle(), 2)):
        data, stats = lzhir.make_ani(frames, [delay] * len(frames))
        assert lzhir.play(data) == frames
        open(os.path.join(out, name), "wb").write(data)
        print("== %s" % name)
        lzhir.report(data, stats)
    gif = os.path.join(out, "vaisseau.gif")
    vaisseau_gif(gif)
    print("== VAISSEAU.ANI (depuis vaisseau.gif)")
    subprocess.check_call([sys.executable, os.path.join(HERE, "mkanim.py"),
                           os.path.join(out, "VAISSEAU.ANI"), gif, "--seuil", "128", "--delai", "4"])
    logo = os.path.join(HERE, "..", "cpa-logo-oricutron.png")
    hiz = lzhir.compress(to_oric(Image.open(logo), 128))
    open(os.path.join(out, "LOGO.HIZ"), "wb").write(hiz)
    print("== LOGO.HIZ : %d octets" % len(hiz))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
