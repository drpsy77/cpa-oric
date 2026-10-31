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
                                 quel, même si son CRC est faux), au format
                                 de l'image (80 pistes, ou 42 avant conv)
  mkdisk.py conv ANCIENNE NOUVELLE [--boot boot.bin --system cpa_sys.bin]
                                 recopie les fichiers (et leurs attributs)
                                 d'une disquette de l'ancien format (42
                                 pistes) sur une disquette neuve de 80
                                 pistes ; sans --boot ni --system, la
                                 nouvelle n'a pas de système (l'ancien ne
                                 lit pas le nouveau format)

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

Géométrie : 2 faces x 80 pistes x 17 secteurs de 256 octets (2 720
secteurs, 680 Ko). Secteur logique (LSN) -> piste logique = LSN // 17,
cylindre = piste // 2, face = piste % 2, secteur = LSN % 17 + 1.
LSN 0-2 : amorçage, 3-66 : système, 67 : libre, 68-2715 : 331 blocs de 2 Ko
(blocs 0 et 1 : répertoire de 128 entrées ; blocs 2 à 330 : fichiers,
658 Ko) ; LSN 2716-2719 inutilisés.

Répertoire (comme CP/M 2.2 au-delà de 255 blocs) : une entrée de 32
octets = un extent de 128 enregistrements (16 Ko) ; octet 0 utilisateur
($E5 = libre), 1-11 nom, 12 EX (numéro de l'extent), 15 RC
(enregistrements de l'extent), 16-31 huit numéros de blocs sur 16 bits
(poids faible d'abord ; 0 = aucun). L'entrée 0 est l'étiquette du format
(octet 0 = $20, comme l'étiquette de CP/M 3, puis « CPA-2X80-2K ») : le
système refuse une disquette qui ne l'a pas.

Ancien format (42 pistes, 1 428 secteurs, 170 blocs numérotés sur 8 bits,
une entrée = deux extents de 16 blocs) : lu par « conv » et « repare »
seulement (les autres commandes le refusent).

Fichiers texte (types TEXTE plus bas : .ASM, .INC, .LOG, .GRX, .TXT, .BAT, .BAS,
.CFG...) : « new » et « put » mettent des fins de ligne CR LF, celles de
CP/M qu'attendent EDIT, TYPE, LOGO et ASM (un fichier venu du Mac, en LF
seul, s'afficherait en escalier). Les CR LF déjà là ne changent pas ; les
autres types (.COM, .HIZ, .ANI...) sont copiés tels quels.

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

SPT, NSIDES, NCYL = 17, 2, 80
NSECT = SPT * NSIDES * NCYL                 # 2 720
SYS_LSN, DIR_LSN = 3, 68
BLK_SECT = 8
NBLK = (NSECT - DIR_LSN) // BLK_SECT        # 331 (blocs 0-1 : répertoire)
DIR_ENT = 128
EXT_REC = 128                               # enregistrements par entrée
LABEL = b"\x20CPA-2X80-2K" + bytes(20)      # entrée 0 du répertoire
# ancien format (lu par « conv »)
OLD_NCYL = 42
OLD_NSECT = SPT * NSIDES * OLD_NCYL         # 1 428
OLD_NBLK = (OLD_NSECT - DIR_LSN) // BLK_SECT  # 170
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
    """Disquette CP/A en mémoire : self.sec = liste des secteurs logiques.
    old = True : ancien format (42 pistes, blocs sur 8 bits), en lecture
    seule (conversion)."""

    def __init__(self, sectors=None, old=False):
        self.old = old
        self.nsect = OLD_NSECT if old else NSECT
        self.ncyl = OLD_NCYL if old else NCYL
        self.nblk = OLD_NBLK if old else NBLK
        self.sec = sectors or [bytes(256)] * self.nsect

    # ------------------------------------------------------- image MFM
    @classmethod
    def load(cls, path, old_ok=False):
        raw = open(path, "rb").read()
        if raw[:8] != b"MFM_DISK":
            raise SystemExit("%s : pas une image MFM_DISK" % path)
        sides, tracks = struct.unpack("<II", raw[8:16])
        old = tracks == OLD_NCYL
        if old and not old_ok:
            raise SystemExit("%s : ancien format de CP/A (42 pistes) ; "
                             "le convertir : mkdisk.py conv %s NOUVELLE.DSK" % (path, path))
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
        for lsn in range(OLD_NSECT if old else NSECT):
            c, s, n = lsn_chs(lsn)
            if (c, s, n) not in found:
                missing.append(lsn)
            elif (c, s, n) in crcbad:
                bad.append(lsn)
            secs.append(found.get((c, s, n), bytes(256)))
        d = cls(secs, old)
        d.missing, d.crcbad, d.mal_sync = missing, bad, mal_sync
        return d

    def save(self, path):
        """Image MFM_DISK de la géométrie de la disquette (80 pistes, ou 42
        pour une ancienne : « repare » seulement)."""
        out = bytearray(b"MFM_DISK")
        out += struct.pack("<III", NSIDES, self.ncyl, 1)
        out += bytes(256 - len(out))
        for side in range(NSIDES):
            for cyl in range(self.ncyl):
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
        """Répertoire vide : 16 secteurs de $E5, puis l'étiquette du format
        en entrée 0 (comme FORMAT.COM)."""
        for k in range(2 * BLK_SECT):
            self.sec[DIR_LSN + k] = b"\xe5" * 256
        self.put_entry(0, LABEL)

    def has_label(self):
        return bytes(self.dir_entries()[0]) == LABEL

    def blocks(self, e):
        """Numéros de blocs d'une entrée (0 = aucun), dans l'ordre."""
        if self.old:
            return list(e[16:32])
        return [e[16 + 2 * k] | e[17 + 2 * k] << 8 for k in range(8)]

    def ext_span(self, e):
        """(premier enregistrement du fichier couvert par l'entrée, nombre
        d'enregistrements de l'entrée)."""
        if self.old:                        # une entrée = extents 2p et 2p+1
            return (e[12] >> 1) * 256, (e[12] & 1) * 128 + e[15]
        return e[12] * EXT_REC, e[15]

    def used_blocks(self):
        used = {0, 1}
        for e in self.dir_entries():
            if e[0] != 0xE5:
                used.update(b for b in self.blocks(e) if b)
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
        """name : « NOM.EXT », ou les 11 octets du répertoire."""
        n = name if isinstance(name, bytes) else self.name83(name)
        parts = self.find(n)
        if not parts:
            raise SystemExit("fichier introuvable : %s" % name)
        data = bytearray()
        for _, _, e in parts:
            base, nrec = self.ext_span(e)
            blks = self.blocks(e)
            for r in range(nrec):
                b = blks[r // 16]
                pos = (base + r) * 128
                if len(data) < pos + 128:
                    data += bytes(pos + 128 - len(data))
                if b == 0:                  # trou (fichier écrit en accès direct)
                    continue
                lsn = self.blk_lsn(b) + (r // 2) % 8
                half = r & 1
                data[pos:pos + 128] = self.sec[lsn][half * 128:half * 128 + 128]
        return bytes(data)

    def _rw(self):
        if self.old:
            raise SystemExit("ancien format : lecture seule (mkdisk.py conv)")

    def erase(self, name):
        self._rw()
        n = self.name83(name)
        for _, i, e in self.find(n):
            e[0] = 0xE5
            self.put_entry(i, e)

    def write_file(self, name, data):
        """Fichier NOM.EXT (fins de ligne CR LF pour un type texte)."""
        self.write_file_raw(self.name83(name), crlf_texte(name, data))

    def write_file_raw(self, n, data):
        """Fichier de nom n (11 octets, « NOM     EXT »), contenu tel quel."""
        self._rw()
        for _, i, e in self.find(n):
            e[0] = 0xE5
            self.put_entry(i, e)
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
            n_here = min(EXT_REC, nrec - rec)
            if not free_ent:
                raise SystemExit("répertoire plein")
            e = bytearray(32)
            e[1:12] = n
            e[12] = p
            e[15] = n_here
            nb = (n_here + 15) // 16
            if nb > len(free):
                raise SystemExit("disque plein")
            for k in range(nb):
                b = free.pop(0)
                e[16 + 2 * k] = b & 0xFF
                e[17 + 2 * k] = b >> 8
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
        self._rw()
        n = name if isinstance(name, bytes) else self.name83(name)
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
        """nom -> enregistrements (le plus grand EX * 128 + RC, comme la
        fonction 35 du BDOS)."""
        files = {}
        for e in self.dir_entries():
            if e[0] == 0:
                nm = bytes(c & 0x7F for c in e[1:12]).decode("ascii")
                base, nrec = self.ext_span(e)
                files[nm] = max(files.get(nm, 0), base + nrec)
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
    """Contrôle de l'image chargée : étiquette, secteurs, entrées du
    répertoire, blocs, puis cohérence de chaque fichier. Défauts (code de
    retour 1) : ce qui rend la disquette fausse ; avertissements (code 0) :
    ce qui reste d'un travail interrompu (NOM.$$$, fichier vide, blocs
    libres qui contiennent des données)."""
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
    if not d.has_label():
        print("étiquette du format absente (entrée 0 du répertoire) : "
              "le système refusera la disquette"); err += 1
    occupes = d.used_blocks()
    for lsn, quoi in [(l, "absent") for l in d.missing] + [(l, ": CRC faux") for l in d.crcbad]:
        b = (lsn - DIR_LSN) // BLK_SECT
        if lsn >= DIR_LSN + NBLK * BLK_SECT:
            continue                    # fin de la disquette, hors des blocs
        if lsn >= DIR_LSN and b not in occupes:
            # bloc libre (écriture coupée par RESET, par exemple) : aucun
            # fichier n'y perd rien, DISKCOPY ne copie que les blocs occupés
            print("avertissement : secteur %d %s (bloc %d, libre)" % (lsn, quoi, b)); avert += 1
        else:
            print("secteur %d %s (%s)" % (lsn, quoi, zone(lsn))); err += 1
    owner = {}
    fichiers = {}                       # (utilisateur, nom) -> entrées
    for i, e in enumerate(d.dir_entries()):
        if e[0] == 0xE5 or i == 0 and bytes(e) == LABEL:
            continue
        nom = bytes(c & 0x7F for c in e[1:12]).decode("ascii", "replace")
        if e[0] > 15 or any(c & 0x7F < 32 for c in e[1:12]):
            print("entrée %d invraisemblable (utilisateur %d, %r)" % (i, e[0], nom)); err += 1
            continue
        fichiers.setdefault((e[0], nom), []).append(e)
        for b in d.blocks(e):
            if not b:
                continue
            if b < 2 or b >= NBLK:
                print("%s : bloc %d hors de la disquette" % (nom_lisible(nom), b)); err += 1
            elif b in owner and owner[b] != nom:
                print("bloc %d partagé : %s et %s" % (b, nom_lisible(owner[b]),
                                                     nom_lisible(nom))); err += 1
            owner[b] = nom

    # cohérence de chaque fichier (une entrée = un extent de 128
    # enregistrements, huit blocs)
    for (u, nom), ents in sorted(fichiers.items()):
        nl = nom_lisible(nom)
        if u:
            nl += " (utilisateur %d)" % u
        ents.sort(key=lambda e: e[12])
        vues = {}
        for e in ents:
            p = e[12]
            if p in vues:
                print("%s : deux entrées pour l'extent %d" % (nl, p)); err += 1
            vues[p] = e
        dern = max(vues)
        for p in range(dern):
            if p not in vues:
                print("%s : entrée de l'extent %d manquante (fichier coupé)" % (nl, p)); err += 1
        for p, e in sorted(vues.items()):
            rc = e[15]
            if rc > EXT_REC:
                print("%s : extent %d, RC = %d (128 au plus)" % (nl, p, rc)); err += 1
                continue
            if p < dern and rc != EXT_REC:
                print("%s : extent %d incomplet (RC %d) avant le dernier" % (nl, p, rc)); err += 1
            utiles = (rc + 15) // 16            # blocs de 16 enregistrements
            for k, b in enumerate(d.blocks(e)):
                if k < utiles and not b:
                    print("%s : enregistrements %d-%d sans bloc"
                          % (nl, p * EXT_REC + k * 16, min(p * EXT_REC + k * 16 + 15,
                                                          p * EXT_REC + rc - 1))); err += 1
                elif k >= utiles and b:
                    print("%s : bloc %d alloué après la fin (%d enregistrement(s))"
                          % (nl, b, p * EXT_REC + rc)); err += 1
        if len({e[9] & 0x80 for e in ents}) > 1:
            print("%s : attribut R/O différent d'une entrée à l'autre" % nl); err += 1
        taille = EXT_REC * dern + vues[dern][15]
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


def conv(src, rest):
    """Ancienne disquette (42 pistes) -> nouvelle (80 pistes) : fichiers et
    attributs recopiés ; amorçage et système seulement s'ils sont donnés."""
    if not rest:
        print(__doc__)
        return 1
    dst = rest[0]
    boot = sysb = None
    i = 1
    while i < len(rest):
        if rest[i] == "--boot":
            boot = open(rest[i + 1], "rb").read(); i += 2
        elif rest[i] == "--system":
            sysb = open(rest[i + 1], "rb").read(); i += 2
        else:
            print(__doc__)
            return 1
    a = Disk.load(src, old_ok=True)
    if not a.old:
        raise SystemExit("%s : déjà au format de 80 pistes" % src)
    if a.missing or a.crcbad:
        print("avertissement : %d secteur(s) absent(s), %d à CRC faux (mkdisk.py repare)"
              % (len(a.missing), len(a.crcbad)))
    d = Disk()
    if boot:
        assert len(boot) == 768
        for k in range(3):
            d.sec[k] = boot[k * 256:(k + 1) * 256]
    if sysb:
        assert len(sysb) == 16384
        for k in range(64):
            d.sec[SYS_LSN + k] = sysb[k * 256:(k + 1) * 256]
    if not sysb and any(any(s) for s in a.sec[SYS_LSN:SYS_LSN + 64]):
        print("avertissement : système de l'ancienne disquette non recopié "
              "(il ne lit pas le nouveau format) ; --boot et --system pour en mettre un")
    d.format_dir()
    at = a.attrs()
    # les fichiers dans l'ordre du répertoire d'origine
    vus = []
    for e in a.dir_entries():
        if e[0] == 0:
            nm = bytes(c & 0x7F for c in e[1:12]).decode("ascii")
            if nm not in vus:
                vus.append(nm)
    for nm in vus:
        n = nm.encode("ascii")
        # contenu tel quel, à l'enregistrement près (pas de passage en CR LF)
        d.write_file_raw(n, a.read_file(n))
        ro, sy = at.get(nm, (False, False))
        if ro or sy:
            d.set_attr(n, ro=ro, sys_=sy)
    d.save(dst)
    print("%s écrite : %d fichier(s), %d Ko libres" % (dst, len(vus), (NBLK - len(d.used_blocks())) * 2))
    return 0


# arguments après IMAGE : (nombre au moins, forme)
USAGE = {
    "new": (0, "new IMAGE [--boot boot.bin --system cpa_sys.bin] [fichiers...]"),
    "ls": (0, "ls IMAGE"),
    "check": (0, "check IMAGE"),
    "get": (1, "get IMAGE NOM.EXT [fichier_local]"),
    "put": (1, "put IMAGE fichier_local [NOM.EXT]"),
    "era": (1, "era IMAGE NOM.EXT"),
    "attr": (2, "attr IMAGE NOM.EXT RO|RW|SYS|DIR..."),
    "diff": (1, "diff AVANT APRES"),
    "repare": (1, "repare IMAGE SORTIE"),
    "conv": (1, "conv ANCIENNE NOUVELLE [--boot boot.bin --system cpa_sys.bin]"),
}


def main(argv):
    if len(argv) < 2 or argv[1] not in USAGE:
        print(__doc__)
        return 1
    cmd = argv[1]
    if len(argv) < 3 + USAGE[cmd][0]:
        print("usage : mkdisk.py %s" % USAGE[cmd][1])
        return 1
    img = argv[2]
    rest = argv[3:]
    if cmd == "diff":
        return diff(Disk.load(img), Disk.load(rest[0]))
    if cmd == "conv":
        return conv(img, rest)
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
    d = Disk.load(img, old_ok=cmd == "repare")
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
        if os.path.abspath(rest[0]) == os.path.abspath(img):
            raise SystemExit("repare : SORTIE doit être une autre image que %s" % img)
        d.save(rest[0])
        print("%s écrite%s : %d secteur(s) absent(s) (mis à 0), %d à CRC faux (gardés)"
              % (rest[0], " (ancien format, 42 pistes)" if d.old else "",
                 len(d.missing), len(d.crcbad)))
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
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
