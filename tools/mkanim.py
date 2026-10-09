#!/usr/bin/env python3
"""Fabrique une animation plein écran pour CP/A (.ANI) à partir d'un GIF
animé ou d'une suite d'images (PNG, JPEG...).

  mkanim.py FILM.ANI anim.gif [options]
  mkanim.py FILM.ANI image1.png image2.png ... [options]

Options :
  --delai N     durée de chaque image en 1/50 s (défaut : celle du GIF,
                sinon 4, soit 12,5 images/s)
  --pas N       ne garde qu'une image sur N (GIF trop long)
  --max N       N images au plus
  --seuil N     pas de tramage : seuil 0-255 (conseillé pour un dessin ;
                le tramage change tout l'écran d'une image à l'autre)
  --invert      inverse le noir et le blanc
  --cadre       garde toute l'image (bandes noires) au lieu de la recadrer
  --longue      fichier plus petit, décodage plus lent (copies non coupées)
  --apercu F    écrit aussi un GIF de ce que verra l'Oric

Chaque image passe par la conversion de png2hir.py (240 x 200, noir et
blanc), puis est codée par rapport à la précédente (lzhir.py). Le bilan
donne la taille, le temps de décodage estimé et la cadence obtenue sur
l'Oric. Lecture : VOIR FILM.ANI [n], ou ANIM FILM [n] dans GRAPHER.

Il faut le module Pillow : pip3 install pillow
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from PIL import Image, ImageSequence
except ImportError:
    sys.exit("mkanim.py : il faut le module Pillow (pip3 install pillow)")
import lzhir
from png2hir import convert_image, W


def opt(opts, name, default=None, conv=int):
    if name in opts:
        return conv(opts[opts.index(name) + 1])
    return default


def load_frames(files):
    """-> liste (image Pillow, délai en 1/50 s ou None)"""
    out = []
    for f in files:
        im = Image.open(f)
        if getattr(im, "n_frames", 1) > 1:
            for fr in ImageSequence.Iterator(im):
                ms = fr.info.get("duration", 0) or 0
                out.append((fr.convert("RGB"), max(1, round(ms / 20)) if ms else None))
        else:
            out.append((im.convert("RGB"), None))
    return out


def preview(path, frames, delays):
    imgs = []
    for data in frames:
        im = Image.new("1", (W, 200))
        px = im.load()
        for y in range(200):
            for c in range(40):
                b = data[y * 40 + c]
                for i in range(6):
                    px[c * 6 + i, y] = 255 if b & (0x20 >> i) else 0
        imgs.append(im.convert("L").resize((W * 2, 400), Image.NEAREST))
    imgs[0].save(path, save_all=True, append_images=imgs[1:], loop=0,
                 duration=[d * 20 for d in delays])


def main(argv):
    opts = argv[1:]
    valued = ("--delai", "--pas", "--max", "--seuil", "--apercu")
    args = []
    skip = False
    for i, a in enumerate(opts):
        if skip:
            skip = False
            continue
        if a in valued:
            skip = True
        elif not a.startswith("--"):
            args.append(a)
    if len(args) < 2:
        print(__doc__)
        return 1
    out, files = args[0], args[1:]
    src = load_frames(files)
    pas = opt(opts, "--pas", 1)
    src = src[::pas]
    if opt(opts, "--max"):
        src = src[:opt(opts, "--max")]
    fixed = opt(opts, "--delai")
    seuil = opt(opts, "--seuil")
    frames, delays = [], []
    for im, d in src:
        data, _ = convert_image(im, 200, "--invert" in opts, seuil, "--cadre" in opts)
        frames.append(bytes(data))
        delays.append(fixed or (d * pas if d else 4))
    data, stats = lzhir.make_ani(frames, delays, "--longue" not in opts)
    assert lzhir.play(data) == frames
    open(out, "wb").write(data)
    print("%s :" % out)
    lzhir.report(data, stats)
    ap = opt(opts, "--apercu", conv=str)
    if ap:
        preview(ap, frames, [min(255, max(1, d)) for d in delays])
        print("apercu : %s" % ap)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
