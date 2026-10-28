#!/usr/bin/env python3
"""Outil de disquette CP/A (images MFM_DISK lues par Oricutron, Cumulus, LOCI).

  mkdisk.py new  IMAGE --boot boot.bin --system cpa_sys.bin [--ro|--rw] [--sys|--dir] [fichiers...]
  mkdisk.py ls   IMAGE
  mkdisk.py get  IMAGE NOM.EXT [fichier_local]
  mkdisk.py put  IMAGE fichier_local [NOM.EXT]
  mkdisk.py era  IMAGE NOM.EXT
  mkdisk.py attr IMAGE NOM.EXT RO|RW|SYS|DIR...
  mkdisk.py check  IMAGE         secteurs absents ou à CRC faux, répertoire,
                                 cohérence de chaque fichier (code 1 : défaut)
  mkdisk.py diff   AVANT APRES   fichiers ajoutés, effacés, modifiés
                                 (code 0 : aucune différence)
  mkdisk.py repare IMAGE SORTIE  réécrit une image saine (secteurs relus
                                 même mal synchronisés ; contenu gardé tel
                                 quel, même si son CRC est faux)

« check » sépare les défauts (disquette fausse : secteur illisible, bloc
partagé ou hors de la disquette, entrée d'un fichier manquante ou en double,
entrée incomplète avant la dernière, enregistrements sans bloc, bloc alloué
après la fin) des avertissements (traces d'un travail interrompu, sans
danger : NOM.$$$ resté, fichier vide, bloc libre qui contient des données
— fichier jamais fermé, ou effacé : ERA laisse les données en place —,
secteur illisible dans un bloc libre).

Attributs (comme SET sur l'Oric) : bit 7 de t1 = R/O (protégé), de t2 =
SYS (caché de DIR). Dans « new », --ro protège les fichiers qui suivent,
--rw revient aux fichiers non protégés ; de même --sys cache les fichiers qui
suivent, --dir les laisse visibles. « ls » montre R/O et SYS. Un fichier
de « new » peut s'écrire SOURCE=NOM.EXT : SOURCE copié sous le nom NOM.EXT
(exemples traduits de la disquette anglaise, files/en/noms.txt).

Géométrie : 2 faces x 42 pistes x 17 secteurs de 256 octets.
Secteur logique (LSN) -> piste logique = LSN // 17, cylindre = piste // 2,
face = piste % 2, secteur = LSN % 17 + 1.

Fichiers texte (types TEXTE plus bas : .ASM, .INC, .LOG, .GRX, .TXT, .BAT, .BAS,
.CFG...) : « new » et « put » mettent des fins de ligne CR LF, celles de
CP/M qu'attendent EDIT, TYPE, LOGO et ASM (un fichier venu du Mac, en LF
seul, s'afficherait en escalier). Les CR LF déjà là ne changent pas ; les
autres types (.COM, .HIZ, .ANI...) sont copiés tels quels.
LSN 0-2 : amorçage, 3-66 : système, 68+ : blocs de 2 Ko (bloc 0-1 = répertoire).

Entrelacement : sur chaque piste, les secteurs sont rangés un sur ENTREL
(variable d'environnement CPA_ENTREL pour essayer une autre valeur ; 1 = dans
l'ordre). Un vrai lecteur tourne pendant que le BDOS traite un secteur : dans
l'ordre, le suivant est déjà passé et il faut attendre un tour. La lecture
des images ne dépend pas de l'ordre (secteurs retrouvés par leur en-tête).
Lecture tolérante : un en-tête ou des données précédés de deux $A1 seulement
sont acceptés. Clock Signal, quand il réécrit une piste dans l'image, ne
garde que deux des trois $A1 de chaque synchronisation (le premier devient
des octets sans sens) : Oricutron et le LOCI ne retrouvent plus ces
secteurs, la disquette paraît vide ; « repare » la remet d'aplomb.
"""
import os
import struct
import sys

# types de fichiers texte : fins de ligne CR LF sur la disquette
TEXTE = {"ASM", "INC", "LOG", "GRX", "TXT", "BAT", "CFG", "DOC", "SUB", "PRN", "LST", "BAS"}


def crlf_texte(name, data):
    """LF seul (Mac, Linux) -> CR LF pour un fichier texte ; CR LF gardé."""
    ext = os.path.basename(name).rpartition(".")[2].upper()
    if ext not in TEXTE:
        return data
    return data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")

SPT, NSIDES, NCYL = 17, 2, 42
NSECT = SPT * NSIDES * NCYL
SYS_LSN, DIR_LSN = 3, 68
BLK_SECT = 8
NBLK = (NSECT - DIR_LSN) // BLK_SECT
DIR_ENT = 128
TRACK_LEN = 6400
GAP1, GAP2, GAP3 = 72, 34, 50
ENTREL = int(os.environ.get("CPA_ENTREL", "2"))


def slot_order(k):
    """Numéros de secteur dans l'ordre de passage sous la tête, un sur k
    (k = 2 : 1, 10, 2, 11... 9, comme FORMAT.COM)."""
    order = [0] * SPT
    pos = 0
    for s in range(1, SPT + 1):
        while order[pos]:
            pos = (pos + 1) % SPT
        order[pos] = s
        pos = (pos + k) % SPT
    return order

CRCTAB = []
for i in range(256):
    c = i << 8
    for _ in range(8):
        c = ((c << 1) ^ 0x1021) if c & 0x8000 else (c << 1)
    CRCTAB.append(c & 0xFFFF)


def crc16(data):
    crc = 0xFFFF
    for b in data:
        crc = ((crc << 8) & 0xFFFF) ^ CRCTAB[(crc >> 8) ^ b]
    return crc


def lsn_chs(lsn):
    lt = lsn // SPT
    return lt // 2, lt % 2, lsn % SPT + 1


class Disk:
    def __init__(self, sectors=None):
        self.sec = sectors or [bytes(256)] * NSECT

    # ------------------------------------------------------- image MFM
    @classmethod
    def load(cls, path):
        raw = open(path, "rb").read()
        if raw[:8] != b"MFM_DISK":
            raise SystemExit("%s : pas une image MFM_DISK" % path)
        sides, tracks = struct.unpack("<II", raw[8:16])
        found = {}
        crcbad = set()
        mal_sync = 0
        for side in range(sides):
            for trk in range(tracks):
                base = 256 + (side * tracks + trk) * TRACK_LEN
                t = raw[base:base + TRACK_LEN]
                p = 0
                while True:
                    p = t.find(b"\xa1\xa1\xfe", p)     # (deux $A1 au moins)
                    if p < 0:
                        break
                    if t[p - 1] != 0xA1:
                        mal_sync += 1
                    tr, sd, sc, sz = t[p + 3:p + 7]
                    idf = b"\xa1\xa1\xa1\xfe" + t[p + 3:p + 7]
                    id_ok = crc16(idf) == struct.unpack(">H", t[p + 7:p + 9])[0]
                    d = t.find(b"\xa1\xa1\xfb", p + 9)
                    if d < 0 or d - p > 80 or sz > 3:
                        p += 9
                        continue
                    n = 128 << sz
                    data = t[d + 3:d + 3 + n]
                    d_ok = crc16(b"\xa1\xa1\xa1\xfb" + data) == \
                        struct.unpack(">H", t[d + 3 + n:d + 5 + n].ljust(2, b"\0"))[0]
                    if (tr, sd, sc) not in found or id_ok and d_ok:
                        found[(tr, sd, sc)] = data
                        if id_ok and d_ok:
                            crcbad.discard((tr, sd, sc))
                        else:
                            crcbad.add((tr, sd, sc))
                    p = d + 3 + n
        secs = []
        missing = []
        bad = []
        for lsn in range(NSECT):
            c, s, n = lsn_chs(lsn)
            if (c, s, n) not in found:
                missing.append(lsn)
            elif (c, s, n) in crcbad:
                bad.append(lsn)
            secs.append(found.get((c, s, n), bytes(256)))
        d = cls(secs)
        d.missing, d.crcbad, d.mal_sync = missing, bad, mal_sync
        return d

    def save(self, path):
        out = bytearray(b"MFM_DISK")
        out += struct.pack("<III", NSIDES, NCYL, 1)
        out += bytes(256 - len(out))
        for side in range(NSIDES):
            for cyl in range(NCYL):
                t = bytearray()
                t += b"\x4e" * (GAP1 - 12)
                for s in slot_order(ENTREL):
                    lt = cyl * 2 + side
                    data = self.sec[lt * SPT + s - 1]
                    idf = b"\xa1\xa1\xa1\xfe" + bytes([cyl, side, s, 1])
                    t += b"\x00" * 12 + idf + struct.pack(">H", crc16(idf))
                    t += b"\x4e" * (GAP2 - 12)
                    df = b"\xa1\xa1\xa1\xfb" + data
                    t += b"\x00" * 12 + df + struct.pack(">H", crc16(df))
                    t += b"\x4e" * (GAP3 - 12)
                assert len(t) <= TRACK_LEN
                t += b"\x4e" * (TRACK_LEN - len(t))
                out += t
        open(path, "wb").write(out)

    # ------------------------------------------------- système de fichiers
    def blk_lsn(self, b):
        return DIR_LSN + b * BLK_SECT

    def dir_entries(self):
        ents = []
        for i in range(DIR_ENT):
            s = self.sec[DIR_LSN + i // 8]
            ents.append(bytearray(s[(i % 8) * 32:(i % 8) * 32 + 32]))
        return ents

    def put_entry(self, i, e):
        lsn = DIR_LSN + i // 8
        s = bytearray(self.sec[lsn])
        s[(i % 8) * 32:(i % 8) * 32 + 32] = e
        self.sec[lsn] = bytes(s)

    def format_dir(self):
        for k in range(2 * BLK_SECT):
            self.sec[DIR_LSN + k] = b"\xe5" * 256

    def used_blocks(self):
        used = {0, 1}
        for e in self.dir_entries():
            if e[0] != 0xE5:
                used.update(b for b in e[16:32] if b)
        return used

    @staticmethod
    def name83(name):
        name = os.path.basename(name).upper()
        base, _, ext = name.partition(".")
        return (base[:8].ljust(8) + ext[:3].ljust(3)).encode("ascii")

    def find(self, name83):
        return sorted(((e[12], i, e) for i, e in enumerate(self.dir_entries())
                       if e[0] == 0 and bytes(c & 0x7F for c in e[1:12]) == name83),
                      key=lambda x: x[0])

    def read_file(self, name):
        n = self.name83(name)
        parts = self.find(n)
        if not parts:
            raise SystemExit("fichier introuvable : %s" % name)
        data = bytearray()
        for ex, _, e in parts:              # une entrée = 256 enregistrements
            nrec = (ex & 1) * 128 + e[15]
            base = (ex >> 1) * 256
            for r in range(nrec):
                b = e[16 + r // 16]
                pos = (base + r) * 128
                if len(data) < pos + 128:
                    data += bytes(pos + 128 - len(data))
                if b == 0:                  # trou (fichier écrit en accès direct)
                    continue
                lsn = self.blk_lsn(b) + (r // 2) % 8
                half = r & 1
                data[pos:pos + 128] = self.sec[lsn][half * 128:half * 128 + 128]
        return bytes(data)

    def erase(self, name):
        n = self.name83(name)
        for _, i, e in self.find(n):
            e[0] = 0xE5
            self.put_entry(i, e)

    def write_file(self, name, data):
        data = crlf_texte(name, data)
        self.erase(name)
        n = self.name83(name)
        if len(data) % 128:
            data += b"\x1a" * (128 - len(data) % 128)
        nrec = len(data) // 128
        used = self.used_blocks()
        free = [b for b in range(2, NBLK) if b not in used]
        ents = self.dir_entries()
        free_ent = [i for i, e in enumerate(ents) if e[0] == 0xE5]
        p = 0
        rec = 0
        while True:
            n_here = min(256, nrec - rec)
            if not free_ent:
                raise SystemExit("répertoire plein")
            e = bytearray(32)
            e[1:12] = n
            le_last = 2 * p + (max(n_here, 1) - 1) // 128
            e[12] = le_last
            e[15] = n_here - 128 * (le_last - 2 * p)
            nb = (n_here + 15) // 16
            if nb > len(free):
                raise SystemExit("disque plein")
            for k in range(nb):
                b = free.pop(0)
                e[16 + k] = b
                for s in range(BLK_SECT):
                    r0 = rec + k * 16 + s * 2
                    chunk = data[r0 * 128:(r0 + 2) * 128]
                    self.sec[self.blk_lsn(b) + s] = bytes(chunk.ljust(256, b"\x1a"))
            self.put_entry(free_ent.pop(0), e)
            rec += n_here
            p += 1
            if rec >= nrec:
                break

    def set_attr(self, name, ro=None, sys_=None):
        n = self.name83(name)
        parts = self.find(n)
        if not parts:
            raise SystemExit("fichier introuvable : %s" % name)
        for _, i, e in parts:
            if ro is not None:
                e[9] = (e[9] & 0x7F) | (0x80 if ro else 0)
            if sys_ is not None:
                e[10] = (e[10] & 0x7F) | (0x80 if sys_ else 0)
            self.put_entry(i, e)

    def attrs(self):
        res = {}
        for e in self.dir_entries():
            if e[0] == 0:
                nm = bytes(c & 0x7F for c in e[1:12]).decode("ascii")
                res[nm] = (bool(e[9] & 0x80), bool(e[10] & 0x80))
        return res

    def listing(self):
        files = {}
        for e in self.dir_entries():
            if e[0] == 0:
                nm = bytes(c & 0x7F for c in e[1:12]).decode("ascii")
                files[nm] = files.get(nm, 0) + (e[12] & 1) * 128 + e[15]
        return files


def nom_lisible(nm):
    """'HELLO   COM' -> 'HELLO.COM'"""
    return nm[:8].rstrip() + "." + nm[8:].rstrip()


def bloc_vierge(d, b):
    """Vrai si les 8 secteurs du bloc b ne contiennent qu'un même octet
    (disquette neuve : 0 pour mkdisk, $E5 après FORMAT)."""
    data = b"".join(d.sec[d.blk_lsn(b) + s] for s in range(BLK_SECT))
    return data.count(data[0]) == len(data)


def check(d):
    """Contrôle de l'image chargée : secteurs, entrées du répertoire,
    blocs, puis cohérence de chaque fichier. Défauts (code de retour 1) :
    ce qui rend la disquette fausse ; avertissements (code 0) : ce qui
    reste d'un travail interrompu (NOM.$$$, fichier vide, blocs libres
    qui contiennent des données)."""
    err = 0
    avert = 0
    def zone(lsn):
        if lsn < SYS_LSN:
            return "amorce"
        if lsn < DIR_LSN:
            return "système"
        if lsn < DIR_LSN + 2 * BLK_SECT:
            return "répertoire"
        return "bloc %d" % ((lsn - DIR_LSN) // BLK_SECT)
    if d.mal_sync:
        print("synchronisations à deux $A1 : %d (piste réécrite par Clock Signal ?)" % d.mal_sync)
    occupes = d.used_blocks()
    for lsn, quoi in [(l, "absent") for l in d.missing] + [(l, ": CRC faux") for l in d.crcbad]:
        b = (lsn - DIR_LSN) // BLK_SECT
        if lsn >= DIR_LSN and b not in occupes:
            # bloc libre (écriture coupée par RESET, par exemple) : aucun
            # fichier n'y perd rien, DISKCOPY ne copie que les blocs occupés
            print("avertissement : secteur %d %s (bloc %d, libre)" % (lsn, quoi, b)); avert += 1
        else:
            print("secteur %d %s (%s)" % (lsn, quoi, zone(lsn))); err += 1
    owner = {}
    fichiers = {}                       # (utilisateur, nom) -> entrées
    for i, e in enumerate(d.dir_entries()):
        if e[0] == 0xE5:
            continue
        nom = bytes(c & 0x7F for c in e[1:12]).decode("ascii", "replace")
        if e[0] > 15 or any(c & 0x7F < 32 for c in e[1:12]):
            print("entrée %d invraisemblable (utilisateur %d, %r)" % (i, e[0], nom)); err += 1
            continue
        fichiers.setdefault((e[0], nom), []).append(e)
        for b in e[16:32]:
            if not b:
                continue
            if b < 2 or b >= NBLK:
                print("%s : bloc %d hors de la disquette" % (nom_lisible(nom), b)); err += 1
            elif b in owner and owner[b] != nom:
                print("bloc %d partagé : %s et %s" % (b, nom_lisible(owner[b]),
                                                     nom_lisible(nom))); err += 1
            owner[b] = nom

    # cohérence de chaque fichier (une entrée = extents 2p et 2p+1)
    for (u, nom), ents in sorted(fichiers.items()):
        nl = nom_lisible(nom)
        if u:
            nl += " (utilisateur %d)" % u
        ents.sort(key=lambda e: e[12])
        vues = {}
        for e in ents:
            p = e[12] // 2
            if p in vues:
                print("%s : deux entrées pour les extents %d-%d" % (nl, 2 * p, 2 * p + 1)); err += 1
            vues[p] = e
        dern = max(vues)
        for p in range(dern):
            if p not in vues:
                print("%s : entrée des extents %d-%d manquante (fichier coupé)"
                      % (nl, 2 * p, 2 * p + 1)); err += 1
        for p, e in sorted(vues.items()):
            rc = e[15]
            if rc > 128:
                print("%s : extent %d, RC = %d (128 au plus)" % (nl, e[12], rc)); err += 1
                continue
            if p < dern and (e[12] & 1 == 0 or rc != 128):
                print("%s : entrée %d incomplète (extent %d, RC %d) avant la dernière"
                      % (nl, p, e[12], rc)); err += 1
            nrec = (e[12] & 1) * 128 + rc
            utiles = (nrec + 15) // 16          # blocs de 16 enregistrements
            for k in range(16):
                b = e[16 + k]
                if k < utiles and not b:
                    print("%s : enregistrements %d-%d sans bloc"
                          % (nl, p * 256 + k * 16, min(p * 256 + k * 16 + 15,
                                                       p * 256 + nrec - 1))); err += 1
                elif k >= utiles and b:
                    print("%s : bloc %d alloué après la fin (%d enregistrement(s))"
                          % (nl, b, p * 256 + nrec)); err += 1
        if len({e[9] & 0x80 for e in ents}) > 1:
            print("%s : attribut R/O différent d'une entrée à l'autre" % nl); err += 1
        taille = 256 * dern + (vues[dern][12] & 1) * 128 + vues[dern][15]
        if nom[8:] == "$$$":
            print("avertissement : %s reste (enregistrement interrompu ?), %d octets"
                  % (nl, taille * 128)); avert += 1
        elif taille == 0:
            print("avertissement : %s est vide (0 octet)" % nl); avert += 1

    # blocs libres qui contiennent des données (fichier jamais fermé,
    # ou fichier effacé : ERA laisse les données en place)
    orph = [b for b in range(2, NBLK) if b not in owner and not bloc_vierge(d, b)]
    if orph:
        print("avertissement : %d bloc(s) libre(s) avec des données : %s"
              % (len(orph), " ".join(map(str, orph[:24])) + (" ..." if len(orph) > 24 else "")))
        avert += 1
    print("%d fichier(s), %d bloc(s) occupé(s) ; %s%s" % (
        len(fichiers), len(owner),
        "aucun défaut" if not err else "%d défaut(s)" % err,
        "" if not avert else ", %d avertissement(s)" % avert))
    return 1 if err else 0


def contenus(d):
    """nom -> (octets, R/O, SYS) pour chaque fichier lisible."""
    res = {}
    at = d.attrs()
    for nm in d.listing():
        try:
            data = d.read_file(nom_lisible(nm))
        except SystemExit:
            data = None
        res[nm] = (data,) + at.get(nm, (False, False))
    return res


def diff(a, b):
    """Différences de AVANT (a) à APRES (b). 0 si rien n'a changé."""
    n = 0
    ca, cb = contenus(a), contenus(b)
    def attr(t):
        return ("R/O" if t[1] else "R/W") + " " + ("SYS" if t[2] else "DIR")
    for nm in sorted(set(ca) | set(cb)):
        nl = nom_lisible(nm)
        if nm not in ca:
            print("+ %-12s ajouté   %6d octets %s" % (nl, len(cb[nm][0] or b""), attr(cb[nm]))); n += 1
        elif nm not in cb:
            print("- %-12s effacé   %6d octets" % (nl, len(ca[nm][0] or b""))); n += 1
        else:
            if ca[nm][0] != cb[nm][0]:
                print("~ %-12s modifié  %6d -> %d octets" % (nl, len(ca[nm][0] or b""),
                                                           len(cb[nm][0] or b""))); n += 1
            if ca[nm][1:] != cb[nm][1:]:
                print("~ %-12s attributs %s -> %s" % (nl, attr(ca[nm]), attr(cb[nm]))); n += 1
    if a.sec[:DIR_LSN] != b.sec[:DIR_LSN]:
        k = sum(1 for x, y in zip(a.sec[:DIR_LSN], b.sec[:DIR_LSN]) if x != y)
        print("! amorce ou système : %d secteur(s) modifié(s)" % k); n += 1
    libres = [k for k in range(2, NBLK) if k not in b.used_blocks()
              and any(a.sec[a.blk_lsn(k) + s] != b.sec[b.blk_lsn(k) + s] for s in range(BLK_SECT))]
    if libres:
        print("  (blocs écrits restés libres : %s)" % " ".join(map(str, libres)))
    if not n:
        print("aucune différence de fichiers")
    return 1 if n else 0


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 1
    cmd, img = argv[1], argv[2]
    rest = argv[3:]
    if cmd == "diff":
        if not rest:
            print(__doc__)
            return 1
        return diff(Disk.load(img), Disk.load(rest[0]))
    if cmd == "new":
        boot = sysb = None
        files = []
        ro = sy = False
        i = 0
        while i < len(rest):
            if rest[i] == "--boot":
                boot = open(rest[i + 1], "rb").read(); i += 2
            elif rest[i] == "--system":
                sysb = open(rest[i + 1], "rb").read(); i += 2
            elif rest[i] in ("--ro", "--rw"):
                ro = rest[i] == "--ro"; i += 1
            elif rest[i] in ("--sys", "--dir"):
                sy = rest[i] == "--sys"; i += 1
            else:
                files.append((rest[i], ro, sy)); i += 1
        d = Disk()
        if boot:
            assert len(boot) == 768
            for k in range(3):
                d.sec[k] = boot[k * 256:(k + 1) * 256]
        if sysb:
            assert len(sysb) == 16384
            for k in range(64):
                d.sec[SYS_LSN + k] = sysb[k * 256:(k + 1) * 256]
        d.format_dir()
        for f, f_ro, f_sys in files:
            src, _, nom = f.partition("=")
            nom = nom or src
            d.write_file(nom, open(src, "rb").read())
            if f_ro or f_sys:
                d.set_attr(nom, ro=f_ro, sys_=f_sys)
        d.save(img)
        cmd = "ls"
    d = Disk.load(img)
    if cmd == "ls":
        files = d.listing()
        at = d.attrs()
        for nm, rec in sorted(files.items()):
            ro, sy = at.get(nm, (False, False))
            print("%s.%s %7d octets %s %s" % (nm[:8], nm[8:], rec * 128,
                                              "R/O" if ro else "R/W", "SYS" if sy else "DIR"))
        free = NBLK - len(d.used_blocks())
        print("%d fichier(s), %d Ko libres" % (len(files), free * 2))
    elif cmd == "check":
        return check(d)
    elif cmd == "repare":
        d.save(rest[0])
        print("%s écrite : %d secteur(s) absent(s) (mis à 0), %d à CRC faux (gardés)"
              % (rest[0], len(d.missing), len(d.crcbad)))
    elif cmd == "get":
        data = d.read_file(rest[0])
        out = rest[1] if len(rest) > 1 else rest[0]
        open(out, "wb").write(data)
        print("%s : %d octets" % (out, len(data)))
    elif cmd == "put":
        d.write_file(rest[1] if len(rest) > 1 else rest[0], open(rest[0], "rb").read())
        d.save(img)
    elif cmd == "era":
        d.erase(rest[0])
        d.save(img)
    elif cmd == "attr":
        kw = {}
        for o in rest[1:]:
            o = o.upper()
            if o in ("RO", "RW"):
                kw["ro"] = o == "RO"
            elif o in ("SYS", "DIR"):
                kw["sys_"] = o == "SYS"
            else:
                raise SystemExit("attribut inconnu : %s (RO RW SYS DIR)" % o)
        d.set_attr(rest[0], **kw)
        d.save(img)
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
