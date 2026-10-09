#!/usr/bin/env python3
"""Convertit une image (PNG, JPEG...) en image haute résolution d'Oric.

  png2hir.py image.png SORTIE.HIR [options]     plein écran 240 x 200
  png2hir.py image.png SORTIE.IMG --split       mode SPLIT 240 x 128 (GLOAD)

Options :
  --invert      inverse le noir et le blanc
  --seuil N     pas de tramage : seuil 0-255 (sinon Floyd-Steinberg)
  --cadre       garde toute l'image (bandes noires) au lieu de la recadrer
  --apercu F    écrit aussi l'aperçu de ce que verra l'Oric (PNG)

L'image est mise à l'échelle et recadrée au centre, passée en niveaux de
gris puis en noir et blanc (encre blanche sur papier noir, les couleurs
du début de chaque ligne de points). Un octet de l'Oric porte 6 points
(bit 5 = point de gauche) et son bit 6 est mis : aucun octet n'est un
attribut. Le fichier est brut : 8 000 octets (.HIR, VOIR et GRAPHER) ou
5 120 octets (.IMG, comme GSAVE). On le copie sur la disquette avec
IMPORT (clé du LOCI) ou tools/mkdisk.py put.

Il faut le module Pillow : pip3 install pillow
"""
import sys

try:
    from PIL import Image, ImageOps
except ImportError:
    sys.exit("png2hir.py : il faut le module Pillow (pip3 install pillow)")

W = 240


def convert(src, lines, invert=False, seuil=None, cadre=False):
    im = Image.open(src).convert("L")
    if cadre:
        im = ImageOps.pad(im, (W, lines), color=0)
    else:
        im = ImageOps.fit(im, (W, lines))
    if invert:
        im = ImageOps.invert(im)
    if seuil is None:
        bw = im.convert("1")                     # tramage Floyd-Steinberg
    else:
        bw = im.point(lambda v: 255 if v >= seuil else 0).convert("1", dither=Image.Dither.NONE)
    px = bw.load()
    out = bytearray()
    for y in range(lines):
        for c in range(W // 6):
            b = 0x40
            for i in range(6):
                if px[c * 6 + i, y]:
                    b |= 0x20 >> i
            out.append(b)
    return out, bw


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    opts = argv[1:]
    if len(args) < 2:
        print(__doc__)
        return 1
    split = "--split" in opts
    seuil = None
    if "--seuil" in opts:
        seuil = int(opts[opts.index("--seuil") + 1])
        args = [a for a in args if a != str(seuil)]
    apercu = None
    if "--apercu" in opts:
        apercu = opts[opts.index("--apercu") + 1]
        args = [a for a in args if a != apercu]
    lines = 128 if split else 200
    data, bw = convert(args[0], lines, "--invert" in opts, seuil, "--cadre" in opts)
    if split:
        # GSAVE garde $A000-$B3FF : la 1re case de la ligne 127 porte le
        # retour au texte ($1A), remis par GLOAD de toute façon
        data[127 * 40] = 0x1A
    open(args[1], "wb").write(bytes(data))
    if apercu:
        bw.convert("RGB").resize((W * 2, lines * 2), Image.NEAREST).save(apercu)
    print("%s : %d octets (%s)" % (args[1], len(data), "SPLIT 240 x 128" if split else "plein écran 240 x 200"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
