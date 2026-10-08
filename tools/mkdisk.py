#!/usr/bin/env python3
"""Outil de disquette CP/A (images MFM_DISK lues par Oricutron, Cumulus, LOCI).

  mkdisk.py new  IMAGE --boot boot.bin --system cpa_sys.bin [--ro|--rw] [--sys|--dir] [fichiers...]
  mkdisk.py ls   IMAGE
  mkdisk.py get  IMAGE NOM.EXT [fichier_local]
  mkdisk.py put  IMAGE fichier_local [NOM.EXT]
  mkdisk.py era  IMAGE NOM.EXT
  mkdisk.py attr IMAGE NOM.EXT RO|RW|SYS|DIR...

Attributs (comme SET sur l'Oric) : bit 7 de t1 = R/O (protégé), de t2 =
SYS (caché de DIR). Dans « new », --ro protège les fichiers qui suivent,
--rw revient aux fichiers non protégés ; de même --sys cache les fichiers qui
suivent, --dir les laisse visibles. « ls » montre R/O et SYS.

Géométrie : 2 faces x 42 pistes x 17 secteurs de 256 octets.
Secteur logique (LSN) -> piste logique = LSN // 17, cylindre = piste // 2,
face = piste % 2, secteur = LSN % 17 + 1.
LSN 0-2 : amorçage, 3-66 : système, 68+ : blocs de 2 Ko (bloc 0-1 = répertoire).
"""
import os
import struct
import sys

SPT, NSIDES, NCYL = 17, 2, 42
NSECT = SPT * NSIDES * NCYL
SYS_LSN, DIR_LSN = 3, 68
BLK_SECT = 8
NBLK = (NSECT - DIR_LSN) // BLK_SECT
DIR_ENT = 128
TRACK_LEN = 6400
GAP1, GAP2, GAP3 = 72, 34, 50

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
        for side in range(sides):
            for trk in range(tracks):
                base = 256 + (side * tracks + trk) * TRACK_LEN
                t = raw[base:base + TRACK_LEN]
                p = 0
                while True:
                    p = t.find(b"\xa1\xa1\xa1\xfe", p)
                    if p < 0:
                        break
                    tr, sd, sc, sz = t[p + 4:p + 8]
                    d = t.find(b"\xa1\xa1\xa1\xfb", p + 10)
                    if d < 0:
                        break
                    found[(tr, sd, sc)] = t[d + 4:d + 4 + (128 << sz)]
                    p = d + 4 + (128 << sz)
        secs = []
        for lsn in range(NSECT):
            c, s, n = lsn_chs(lsn)
            secs.append(found.get((c, s, n), bytes(256)))
        return cls(secs)

    def save(self, path):
        out = bytearray(b"MFM_DISK")
        out += struct.pack("<III", NSIDES, NCYL, 1)
        out += bytes(256 - len(out))
        for side in range(NSIDES):
            for cyl in range(NCYL):
                t = bytearray()
                t += b"\x4e" * (GAP1 - 12)
                for s in range(1, SPT + 1):
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


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 1
    cmd, img = argv[1], argv[2]
    rest = argv[3:]
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
            d.write_file(f, open(f, "rb").read())
            if f_ro or f_sys:
                d.set_attr(f, ro=f_ro, sys_=f_sys)
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
