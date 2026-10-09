#!/usr/bin/env python3
"""Compression LZSS des images HIRES de CP/A (.HIZ) et des animations (.ANI).

Module utilisé par png2hir.py (--hiz) et mkanim.py ; utilisable seul :

  lzhir.py c IMAGE.HIR IMAGE.HIZ     compresse une image (8 000 ou 5 120 octets)
  lzhir.py d IMAGE.HIZ IMAGE.HIR [--split]   décompresse (contrôle)
  lzhir.py i FILM.ANI                décrit une animation

Format du flux (celui de archives/lzss-osdk, décodé par h_unz de hires.inc) :
groupes de 8 jetons précédés d'un octet de drapeaux lu à partir du bit 0.
Bit à 1 : littéral, 1 octet. Bit à 0 : copie, 3 octets : distance 16 bits
(little-endian) puis longueur 4..255 ; la source est l'adresse en cours moins
la distance, modulo 65 536, recopiée octet par octet. D'où, sans rien changer
au décodeur d'origine :
  - distance > 0 : octets déjà écrits (de l'image en cours) ;
  - distance 0 : l'octet est recopié sur lui-même : il est GARDÉ (saut) ;
  - distance « négative » (65 536 - k) : k octets plus loin, encore de
    l'image précédente.
h_unz traite le saut sans rien copier (c'est ce qui rend les animations
rapides). Pas de marqueur de fin : arrêt après 8 000 octets (5 120 en SPLIT).

Image seule .HIZ : le flux, sans en-tête ; il est autonome (ni saut ni
image précédente), donc lisible par le décodeur d'origine sur n'importe
quel écran.

Animation .ANI : en-tête de 16 octets
  0-3   "ANI", version 1
  4-5   nombre d'images N
  6     drapeaux : bit 0 = image de retour présente (boucle sans h_cls)
  7     0
  8-9   taille des données qui suivent l'en-tête
  10-15 0
puis N images (+ l'image de retour) : délai (1/50 s, 1-255), longueur
(2 octets), flux. La 1re image est codée par rapport à l'écran effacé
(octets $40, h_cls) ; chacune des suivantes par rapport à la précédente ;
l'image de retour ramène de la dernière à la 1re.
"""
import os
import sys

MIN_MATCH = 4
MAX_MATCH = 255
HL = 4              # octets indexés par la table de hachage
CHAIN = 64          # candidats examinés par position
BLANK = 0x40        # octet de points vide (h_cls)
SIZE_FULL = 8000
SIZE_SPLIT = 5120
TOP_FULL = 34 * 1024    # place estimée pour une animation dans VOIR
TOP_GRAPHER = 22 * 1024  # et dans GRAPHER interprété (après son texte)

# coûts du décodeur h_unz (cycles du 6502), mesurés : tools/test_anim.py
# recale ce modèle sur le décodeur exécuté dans py65 (écart < 1 %)
C_LIT = 52      # littéral
C_COPY = 127    # copie : par jeton...
C_BYTE = 18.2   # ...plus par octet copié
C_SKIP = 105    # saut (distance 0), quelle que soit la longueur
C_FLAG = 31     # octet de drapeaux (tous les 8 jetons)
C_CALL = 250    # appel, initialisation et retour
TICK = 20000 - 850  # cycles utiles par 1/50 s (IRQ du système : ~850)


def _tokens_to_bytes(tokens):
    out = bytearray()
    for g in range(0, len(tokens), 8):
        grp = tokens[g:g + 8]
        flag = 0
        pay = bytearray()
        for b, t in enumerate(grp):
            if t[0] == 'L':
                flag |= 1 << b
                pay.append(t[1])
            else:
                d = t[1] & 0xFFFF
                pay += bytes([d & 255, d >> 8, t[2]])
        out.append(flag)
        out += pay
    return bytes(out)


def delta(old, new, coupe=True):
    """Code `new` sachant que `old` est déjà à l'écran. Liste de jetons
    ('L', octet) ou ('C', distance, longueur) ; distance 0 = garder.

    coupe=True : une copie s'arrête là où au moins MIN_MATCH octets
    inchangés reprennent (plus gros, plus rapide à décoder)."""
    n = len(new)
    seul = old is None                  # image autonome : pas d'écran d'avant
    if seul:
        old = bytes(n)
        coupe = False
    assert len(old) == n
    tnew = {}
    told = {}
    if not seul:
        for p in range(n - HL + 1):
            told.setdefault(old[p:p + HL], []).append(p)
    # ks[p] : prochaine position >= p d'où MIN_MATCH octets sont inchangés
    ks = [n] * (n + 1)
    run = 0
    for p in range(n - 1, -1, -1):
        run = run + 1 if old[p] == new[p] and not seul else 0
        ks[p] = p if run >= MIN_MATCH else ks[p + 1]

    def ins(p):
        if p + HL <= n:
            lst = tnew.setdefault(new[p:p + HL], [])
            lst.insert(0, p)
            if len(lst) > CHAIN:
                lst.pop()

    tokens = []
    i = 0
    while i < n:
        mx = min(MAX_MATCH, n - i)
        k = 0
        while not seul and k < mx and old[i + k] == new[i + k]:
            k += 1
        if k >= MIN_MATCH:                      # garder : rien à copier
            tokens.append(('C', 0, k))
            for q in range(i, i + k):
                ins(q)
            i += k
            continue
        if coupe and ks[i] > i:
            mx = min(mx, ks[i] - i)
        best, dist = 0, 0
        key = new[i:i + HL]
        if len(key) == HL:
            for p in tnew.get(key, ()):         # image en cours, en arrière
                L = 0
                while L < mx and new[p + L] == new[i + L]:
                    L += 1
                if L > best:
                    best, dist = L, i - p
            c = 0
            for p in told.get(key, ()):         # image précédente, plus loin
                if p <= i:
                    continue
                c += 1
                if c > CHAIN:
                    break
                L = 0
                lim = min(mx, n - p)
                while L < lim and old[p + L] == new[i + L]:
                    L += 1
                if L > best:
                    best, dist = L, i - p
        if best >= MIN_MATCH:
            tokens.append(('C', dist, best))
            for q in range(i, i + best):
                ins(q)
            i += best
        else:
            tokens.append(('L', new[i]))
            ins(i)
            i += 1
    return tokens


def compress(data):
    """Image seule (.HIZ) : flux autonome (ni saut ni image précédente),
    exactement le format de archives/lzss-osdk : l'écran d'avant n'importe
    pas, et le décodeur d'origine la lit telle quelle."""
    return _tokens_to_bytes(delta(None, data, False))


def encode(old, new, coupe=True):
    return _tokens_to_bytes(delta(old, new, coupe))


def decode(comp, old):
    """Miroir du décodeur 6502 : `old` = écran avant, rend l'écran après et
    la longueur du flux lue."""
    out = bytearray(old)
    n = len(out)
    pos = 0
    d = 0
    while d < n:
        flag = comp[pos]
        pos += 1
        for b in range(8):
            if d >= n:
                break
            if flag >> b & 1:
                out[d] = comp[pos]
                pos += 1
                d += 1
            else:
                dist = comp[pos] | comp[pos + 1] << 8
                ln = comp[pos + 2]
                pos += 3
                s = (d - dist) & 0xFFFF     # distance 0 : l'octet lui-meme
                for k in range(min(ln, n - d)):
                    out[d] = out[s + k]
                    d += 1
    return bytes(out), pos


def cycles(comp, n):
    c = C_CALL
    pos = 0
    d = 0
    while d < n:
        flag = comp[pos]
        pos += 1
        c += C_FLAG
        for b in range(8):
            if d >= n:
                break
            if flag >> b & 1:
                c += C_LIT
                pos += 1
                d += 1
            else:
                dist = comp[pos] | comp[pos + 1] << 8
                ln = min(comp[pos + 2], n - d)
                pos += 3
                if dist == 0:
                    c += C_SKIP
                else:
                    c += C_COPY + C_BYTE * ln
                d += ln
    return int(c)


def make_ani(frames, delays, coupe=True):
    """frames : images de 8 000 octets ; delays : 1/50 s par image.
    -> (octets du fichier .ANI, liste (taille, cycles) par image)."""
    blank = bytes([BLANK]) * SIZE_FULL
    body = bytearray()
    stats = []
    seq = [(blank, frames[0])] + [(frames[i - 1], frames[i]) for i in range(1, len(frames))]
    loop = len(frames) > 1
    if loop:
        seq.append((frames[-1], frames[0]))
    rdel = list(delays) + [delays[0]]
    for i, (old, new) in enumerate(seq):
        comp = encode(old, new, coupe)
        chk, used = decode(comp, old)
        assert chk == new and used == len(comp), "erreur interne du compresseur"
        dl = max(1, min(255, int(rdel[i])))
        body += bytes([dl, len(comp) & 255, len(comp) >> 8]) + comp
        stats.append((len(comp) + 3, cycles(comp, SIZE_FULL)))
    head = bytearray(b'ANI\x01')
    head += bytes([len(frames) & 255, len(frames) >> 8, 1 if loop else 0, 0])
    head += bytes([len(body) & 255, (len(body) >> 8) & 255]) + bytes(6)
    return bytes(head + body), stats


def read_ani(data):
    """-> (liste (délai, flux), image de retour présente)"""
    if data[:4] != b'ANI\x01':
        raise ValueError("pas une animation CP/A (en-tete ANI)")
    n = data[4] | data[5] << 8
    loop = data[6] & 1
    p = 16
    out = []
    for _ in range(n + loop):
        dl = data[p]
        ln = data[p + 1] | data[p + 2] << 8
        out.append((dl, data[p + 3:p + 3 + ln]))
        p += 3 + ln
    return out, bool(loop)


def play(data):
    """Rejoue l'animation en Python -> images (8 000 octets) d'un passage."""
    fr, loop = read_ani(data)
    scr = bytes([BLANK]) * SIZE_FULL
    imgs = []
    for dl, comp in fr[:len(fr) - loop]:
        scr, _ = decode(comp, scr)
        imgs.append(scr)
    if loop:
        back, _ = decode(fr[-1][1], scr)
        assert back == imgs[0], "l'image de retour ne ramene pas a la premiere"
    return imgs


def report(data, stats, out=sys.stdout):
    n = data[4] | data[5] << 8
    sz = [s for s, _ in stats]
    cy = [c for _, c in stats]
    fr, loop = read_ani(data)
    ticks = [-(-c // TICK) for c in cy]
    dels = [d for d, _ in fr]
    # une image dure son délai, ou plus si le décodage déborde
    real = [max(t, d) for t, d in zip(ticks, dels)]
    body = real[1:] if len(real) > 1 else real
    out.write("%d images, %d octets (%.1f Ko) ; image 1 : %d octets\n" % (n, len(data), len(data) / 1024, sz[0]))
    if len(sz) > 1:
        out.write("suivantes : %d octets en moyenne, %d au plus\n" % (sum(sz[1:]) / len(sz[1:]), max(sz[1:])))
        out.write("decodage : %d cycles en moyenne, %d au plus (estimation), soit %d/50 s au plus\n"
                  % (sum(cy[1:]) / len(cy[1:]), max(cy[1:]), max(ticks[1:])))
        out.write("cadence : %.1f images/s demandees, %.1f obtenues (en boucle)\n"
                  % (50 * len(body) / sum(dels[1:] if len(dels) > 1 else dels), 50 * len(body) / sum(body)))
    for lim, nom in ((TOP_FULL, "VOIR"), (TOP_GRAPHER, "GRAPHER")):
        out.write("%s : %s (place estimee %d Ko)\n" % (nom, "tient" if len(data) <= lim else "TROP GRAND", lim // 1024))


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 1
    cmd = argv[1]
    if cmd == 'c' and len(argv) >= 4:
        raw = open(argv[2], 'rb').read()
        if len(raw) not in (SIZE_FULL, SIZE_SPLIT):
            sys.exit("%s : %d octets, une image en fait 8000 ou 5120" % (argv[2], len(raw)))
        comp = compress(raw)
        assert decode(comp, bytes(len(raw)))[0] == raw
        open(argv[3], 'wb').write(comp)
        print("%s : %d octets (au lieu de %d)" % (argv[3], len(comp), len(raw)))
    elif cmd == 'd' and len(argv) >= 4:
        n = SIZE_SPLIT if '--split' in argv else SIZE_FULL
        out, _ = decode(open(argv[2], 'rb').read(), bytes([BLANK]) * n)
        open(argv[3], 'wb').write(out)
        print("%s : %d octets" % (argv[3], len(out)))
    elif cmd == 'i':
        data = open(argv[2], 'rb').read()
        fr, loop = read_ani(data)
        play(data)
        stats = [(len(c) + 3, cycles(c, SIZE_FULL)) for _, c in fr]
        report(data, stats)
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
