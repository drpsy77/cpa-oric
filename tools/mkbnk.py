#!/usr/bin/env python3
"""Banques de la fenêtre : découpe le système assemblé et écrit CPA.BNK.

  python3 tools/mkbnk.py ASSEMBLE.bin SYMBOLES.sym SYSTEME.bin CPA.BNK

ASSEMBLE.bin : sortie de xa pour src/cpa.s (-DDISK) : l'image de 16 Ko
($C000-$FFFF), suivie des banques IMG (src/img.s) et GFX (src/gfx_draw.s),
assemblées pour la fenêtre (*= WIN). Écrit :
  SYSTEME.bin  les 16 Ko, signature posée en bnk_sig ;
  CPA.BNK      enregistrement 0 : signature (2 octets) ; PUT (copie de
               l'image) en 1-5 et IMG en 6-10 : la fenêtre WIN-WIN_END
               (576 octets), bourrée ; GFX en 11-19 : WIN-GFX_END (1 088
               octets), bourrée (bk_first, bk_endh de src/bank.s).
Signature : CRC-16 (CCITT) de l'image (bnk_sig à 0) et des banques IMG et GFX,
jamais 0 : une banque faite pour un autre système est refusée par le
chargeur (src/bank.s). Contrôle : IMG s'arrête avant WIN_END, GFX avant GFX_END (PUT : build.sh).
"""
import sys

BASE = 0xC000
TAILLE = 16384
WIN_PUT, WIN_IMG = 0x01, 0x02


def symboles(chemin):
    s = {}
    for ligne in open(chemin):
        p = ligne.split()
        if len(p) >= 2:
            try:
                s[p[1]] = int(p[0], 16)
            except ValueError:
                pass
    return s


def crc16(data, crc=0xFFFF):
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else crc << 1
            crc &= 0xFFFF
    return crc


def main(argv):
    if len(argv) != 5:
        print(__doc__)
        return 1
    tout = bytearray(open(argv[1], "rb").read())
    sym = symboles(argv[2])
    win, fin, gfin = sym["WIN"], sym["WIN_END"], sym["GFX_END"]
    image = tout[:TAILLE]
    li = sym["img_bank_end"] - win
    lg = sym["gfx_bank_end"] - win
    if sym["img_bank"] != win or sym["gfx_bank"] != win \
            or len(tout) != TAILLE + li + lg:
        raise SystemExit("mkbnk : banques IMG et GFX mal placées après l'image")
    img_seul = bytes(tout[TAILLE:TAILLE + li])
    gfx_seul = bytes(tout[TAILLE + li:])
    taille = fin - win                      # 576 : la fenêtre entière
    if li > taille:
        raise SystemExit("mkbnk : banque IMG trop longue (%d octets, %d au plus)" % (li, taille))
    if lg > gfin - win:
        raise SystemExit("mkbnk : banque GFX trop longue (%d octets, %d au plus)"
                         % (lg, gfin - win))
    put = bytes(image[win - BASE:fin - BASE])   # PUT, PUT_SAVE, bourrage
    img = img_seul + b"\xFF" * (taille - li)
    gfx = gfx_seul + b"\xFF" * (gfin - win - lg)
    sig = sym["bnk_sig"] - BASE
    image[sig:sig + 2] = b"\0\0"
    s = crc16(bytes(image) + img + gfx) or 1
    image[sig:sig + 2] = bytes((s & 0xFF, s >> 8))
    bnk = bytearray(bytes((s & 0xFF, s >> 8)) + bytes(126))
    for premier, nrec, b in ((1, 5, put), (6, 5, img), (11, 9, gfx)):   # bk_first (bank.s)
        assert len(bnk) == premier * 128 and len(b) <= nrec * 128
        bnk += b + bytes(nrec * 128 - len(b))
    open(argv[3], "wb").write(bytes(image))
    open(argv[4], "wb").write(bnk)
    print("CPA.BNK : signature %04X ; PUT %d octets (marge %d), IMG %d (marge %d), "
          "GFX %d (marge %d) ; %d octets"
          % (s, sym["PUT_SAVE"] - win, fin - sym["win_put_end"],
             li, taille - li, lg, gfin - win - lg, len(bnk)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
