#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
compress_hires.py
==================

Compresseur / decompresseur pour l'ecran HIRES de l'Oric Atmos
($A000, 200 lignes x 40 octets = 8000 octets), au format LZSS "maison"
decode par decode_screen_hires.s (6502 / ca65).

FORMAT DU FLUX COMPRESSE (doit rester en phase avec le .s !)
--------------------------------------------------------------
Suite de groupes de 8 "jetons", chacun precede d'un octet de FLAGS
(1 bit par jeton, bit 0 = 1er jeton du groupe) :

    bit = 1  ->  jeton LITTERAL : 1 octet brut suit
    bit = 0  ->  jeton COPIE    : 3 octets suivent :
                     distance_lo, distance_hi (16 bits, little-endian,
                     1 = octet precedent), longueur (1 octet, 4..255)

Pas de marqueur de fin : la taille de sortie (8000 octets pour un
ecran HIRES complet) est connue a l'avance des deux cotes.

Usage
-----
    # Compresser un dump memoire (ex: capture de $A000-$BF3F) :
    python3 compress_hires.py compress ecran.bin ecran.lz

    # Le fichier d'entree peut etre un dump plus large (ex: dump complet
    # de la RAM) : on extrait alors la sous-region avec --offset/--size :
    python3 compress_hires.py compress dump_64k.bin ecran.lz --offset 0xA000 --size 8000

    # Decompresser pour verification (sans l'Oric) :
    python3 compress_hires.py decompress ecran.lz ecran_decode.bin --size 8000
"""

import argparse
import sys


# ----------------------------------------------------------------------------
# Parametres du format / du moteur de recherche de motifs
# ----------------------------------------------------------------------------
MIN_MATCH = 4          # en dessous, un jeton COPIE (3 octets) coute plus
                        # cher que des jetons LITTERAL : pas rentable
MAX_MATCH = 255         # longueur codee sur 1 octet brut
HASH_LEN = 4            # nombre d'octets utilises pour indexer les motifs
MAX_CHAIN = 64          # profondeur de recherche max par empreinte (vitesse)


# ----------------------------------------------------------------------------
# Compression
# ----------------------------------------------------------------------------
def _find_best_match(data, i, n, table):
    """Cherche la plus longue correspondance deja vue pour data[i:], en
    limitant la recherche a MAX_CHAIN candidats (vitesse). Retourne
    (longueur, distance) ou (0, 0) si rien d'exploitable."""
    if i + HASH_LEN > n:
        return 0, 0

    key = data[i:i + HASH_LEN]
    candidates = table.get(key)
    if not candidates:
        return 0, 0

    max_len_possible = min(MAX_MATCH, n - i)
    best_len = 0
    best_pos = 0
    checked = 0

    for p in candidates:
        if checked >= MAX_CHAIN:
            break
        checked += 1

        length = 0
        while length < max_len_possible and data[p + length] == data[i + length]:
            length += 1

        if length > best_len:
            best_len = length
            best_pos = p
            if length >= max_len_possible:
                break

    return best_len, (i - best_pos if best_len else 0)


def _insert_hash(data, pos, n, table):
    if pos + HASH_LEN > n:
        return
    key = data[pos:pos + HASH_LEN]
    lst = table.get(key)
    if lst is None:
        table[key] = [pos]
    else:
        lst.insert(0, pos)
        if len(lst) > MAX_CHAIN:
            lst.pop()


def compress(data: bytes) -> bytes:
    """Compresse `data` (les octets bruts de l'ecran HIRES, dans l'ordre)
    au format LZSS decrit en tete de fichier."""
    n = len(data)
    table = {}
    tokens = []  # ('L', byte) ou ('C', distance, length)

    i = 0
    while i < n:
        best_len, best_dist = _find_best_match(data, i, n, table)

        if best_len >= MIN_MATCH:
            tokens.append(('C', best_dist, best_len))
            end = i + best_len
            while i < end:
                _insert_hash(data, i, n, table)
                i += 1
        else:
            tokens.append(('L', data[i]))
            _insert_hash(data, i, n, table)
            i += 1

    out = bytearray()
    ntok = len(tokens)
    idx = 0
    while idx < ntok:
        group = tokens[idx:idx + 8]
        flag = 0
        payload = bytearray()
        for bitpos, tok in enumerate(group):
            if tok[0] == 'L':
                flag |= (1 << bitpos)
                payload.append(tok[1])
            else:
                _, dist, length = tok
                assert 1 <= dist <= 0xFFFF
                assert MIN_MATCH <= length <= MAX_MATCH
                payload.append(dist & 0xFF)
                payload.append((dist >> 8) & 0xFF)
                payload.append(length)
        out.append(flag)
        out.extend(payload)
        idx += 8

    return bytes(out)


# ----------------------------------------------------------------------------
# Decompression (miroir exact du decodeur 6502, pour verification /
# inspection depuis un PC, sans Oric)
# ----------------------------------------------------------------------------
def decompress(comp: bytes, out_size: int) -> bytes:
    out = bytearray()
    pos = 0
    n = len(comp)

    while len(out) < out_size:
        if pos >= n:
            raise ValueError(
                f"flux compresse trop court (arrete a {len(out)}/{out_size} octets)"
            )
        flag = comp[pos]
        pos += 1

        for bit in range(8):
            if len(out) >= out_size:
                break
            if (flag >> bit) & 1:
                # jeton LITTERAL
                if pos >= n:
                    raise ValueError("flux compresse tronque (litteral manquant)")
                out.append(comp[pos])
                pos += 1
            else:
                # jeton COPIE
                if pos + 3 > n:
                    raise ValueError("flux compresse tronque (jeton copie incomplet)")
                dist = comp[pos] | (comp[pos + 1] << 8)
                length = comp[pos + 2]
                pos += 3
                start = len(out) - dist
                if start < 0:
                    raise ValueError("distance de copie invalide (avant le debut de l'ecran)")
                for k in range(length):
                    if len(out) >= out_size:
                        break
                    out.append(out[start + k])

    return bytes(out)


# ----------------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------------
def _auto_int(text: str) -> int:
    """Permet de passer --offset/--size en decimal ou en hexa (0xA000)."""
    return int(text, 0)


def cmd_compress(args):
    with open(args.input, "rb") as f:
        raw = f.read()

    end = args.offset + args.size
    if end > len(raw):
        sys.exit(
            f"Erreur : le fichier d'entree ne fait que {len(raw)} octets, "
            f"impossible d'extraire {args.size} octets a partir de {args.offset}."
        )

    region = raw[args.offset:end]
    comp = compress(region)

    with open(args.output, "wb") as f:
        f.write(comp)

    ratio = len(comp) / len(region) if region else 0.0
    print(f"Entree  : {args.input} (region : offset={args.offset:#06x}, taille={len(region)} octets)")
    print(f"Sortie  : {args.output} ({len(comp)} octets)")
    print(f"Ratio   : {ratio:.3f}  (gain {100 * (1 - ratio):.1f} %)")

    if args.verify:
        check = decompress(comp, len(region))
        if check == region:
            print("Verification : OK (round-trip identique a l'original)")
        else:
            sys.exit("Verification : ECHEC -- le round-trip ne correspond pas a l'original !")


def cmd_decompress(args):
    with open(args.input, "rb") as f:
        comp = f.read()

    out = decompress(comp, args.size)

    with open(args.output, "wb") as f:
        f.write(out)

    print(f"Entree  : {args.input} ({len(comp)} octets compresses)")
    print(f"Sortie  : {args.output} ({len(out)} octets decompresses)")


def main():
    parser = argparse.ArgumentParser(
        description="Compresseur/decompresseur LZSS pour ecran HIRES Oric Atmos "
                     "(compatible avec decode_screen_hires.s)."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_c = sub.add_parser("compress", help="Compresse un dump d'ecran HIRES")
    p_c.add_argument("input", help="Fichier d'entree (dump memoire brut)")
    p_c.add_argument("output", help="Fichier de sortie (flux compresse)")
    p_c.add_argument("--offset", type=_auto_int, default=0,
                      help="Decalage dans le fichier d'entree (defaut : 0). "
                           "Ex: 0xA000 si le fichier est un dump complet de la RAM.")
    p_c.add_argument("--size", type=_auto_int, default=8000,
                      help="Taille de la region a compresser (defaut : 8000, "
                           "un ecran HIRES complet).")
    p_c.add_argument("--no-verify", dest="verify", action="store_false",
                      help="Ne pas relancer une decompression de controle apres coup.")
    p_c.set_defaults(func=cmd_compress)

    p_d = sub.add_parser("decompress", help="Decompresse un flux (pour verification/inspection)")
    p_d.add_argument("input", help="Fichier d'entree (flux compresse)")
    p_d.add_argument("output", help="Fichier de sortie (octets bruts decompresses)")
    p_d.add_argument("--size", type=_auto_int, default=8000,
                      help="Taille attendue en sortie (defaut : 8000).")
    p_d.set_defaults(func=cmd_decompress)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
