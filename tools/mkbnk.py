#!/usr/bin/env python3
"""Banques de la fenêtre : découpe le système assemblé et écrit CPA.BNK.

  python3 tools/mkbnk.py ASSEMBLE.bin SYMBOLES.sym SYSTEME.bin CPA.BNK

ASSEMBLE.bin : sortie de xa pour src/cpa.s (-DDISK) : l'image de 16 Ko
($C000-$FFFF), suivie de la banque IMG (src/img.s, assemblée pour la
fenêtre, *= WIN). Écrit :
  SYSTEME.bin  les 16 Ko, signature posée en bnk_sig ;
  CPA.BNK      enregistrement 0 : signature (2 octets) ; la banque de bit b
               de win_id en 5b-4 à 5b : la fenêtre entière (WIN à WIN_END,
               576 octets), bourrée : PUT (copie de l'image), puis IMG.
Signature : CRC-16 (CCITT) de l'image (bnk_sig à 0) et de la banque IMG,
jamais 0 : une banque faite pour un autre système est refusée par le
chargeur (src/bank.s). Contrôle : la banque IMG s'arrête avant WIN_END (PUT : build.sh).
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
    if len(tout) <= TAILLE:
        raise SystemExit("mkbnk : pas de banque IMG après l'image (%d octets)" % len(tout))
    image, img = tout[:TAILLE], bytes(tout[TAILLE:])
    img_seul = img
    win, fin = sym["WIN"], sym["WIN_END"]
    if sym["img_bank"] != win or sym["img_bank_end"] - win != len(img):
        raise SystemExit("mkbnk : banque IMG mal placée")
    taille = fin - win                      # 576 : la fenêtre entière
    if len(img) > taille:
        raise SystemExit("mkbnk : banque IMG trop longue (%d octets, %d au plus)"
                         % (len(img), taille))
    put = bytes(image[win - BASE:fin - BASE])   # PUT, PUT_SAVE, bourrage
    img = img + b"\xFF" * (taille - len(img))
    sig = sym["bnk_sig"] - BASE
    image[sig:sig + 2] = b"\0\0"
    s = crc16(bytes(image) + img) or 1
    image[sig:sig + 2] = bytes((s & 0xFF, s >> 8))
    bnk = bytearray(bytes((s & 0xFF, s >> 8)) + bytes(126))
    for bit, b in ((WIN_PUT, put), (WIN_IMG, img)):     # bit b : 5b-4 à 5b
        assert len(bnk) == (5 * bit - 4) * 128
        bnk += b + bytes(5 * 128 - len(b))
    open(argv[3], "wb").write(bytes(image))
    open(argv[4], "wb").write(bnk)
    print("CPA.BNK : signature %04X ; PUT %d octets (marge %d), IMG %d (marge %d) ; %d octets"
          % (s, sym["PUT_SAVE"] - win, fin - sym["win_put_end"],
             len(img_seul), taille - len(img_seul), len(bnk)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
