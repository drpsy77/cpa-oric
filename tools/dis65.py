#!/usr/bin/env python3
"""Désassembleur 6502 sur le PC : un programme entier, décrit dans un fichier.

  dis65.py JEU.dis                       désassemble d'après la description
  dis65.py FICHIER.BIN ADR [ENTREE...]   écrit FICHIER.dis (début de description),
  dis65.py JEU.TAP BLOC [ENTREE...]      puis désassemble
  options : -n  pas de contrôle par xa ; -q  pas de liste des candidats

Écrit JEU.s (et JEU_nom.s pour chaque zone « data » nommée), à côté de la
description : un source que xa réassemble en un fichier identique, ce qui est
contrôlé (tools/xa, ou $XA). La description se complète à mesure qu'on
comprend le programme ; on relance, le source est refait. Une ligne par
déclaration, adresses en hexadécimal, « ; » ouvre un commentaire :

  file  NOM.BIN 2DFF [87C3]    fichier, adresse de chargement [dernière adresse]
  file  "JEU.TAP" 3            ou le bloc 3 d'un .TAP (adresse lue dans le bloc)
  entry 2E00 [Nom]             point d'entrée (sans aucun entry : le début)
  table 3687 4 [Nom]           4 adresses de routines : .word Lxxxx, suivies
  table2 5000 5010 8 [Nom]     octets bas en 5000, hauts en 5010 : .byt <Lxxxx
  rtstable 3700 4 [Nom]        adresses - 1 (saut par RTS) : .word Lxxxx-1
  rtstable2 5000 5010 8 [Nom]
  pointers 4F40 6 [Nom]        adresses de données : .word Lxxxx, non suivies
  pointers2 5020 5030 8 [Nom]
  data  5A8C-87C3 [nom]        données (jamais du code), 16 octets par ligne ;
                               avec un nom : écrites à part, dans JEU_nom.s
  text  4F00-4F3F [Nom]        texte : .asc
  name  378A Nom               nom d'une adresse (étiquette, ou constante en tête)
  lo    2E00 2FA5              l'instruction en 2E00 charge l'octet bas de 2FA5 :
  hi    2E05 2FA5              lda #<L2FA5 ; en 2E05 l'octet haut : lda #>L2FA5
  rem   2FA5 texte             commentaire écrit devant cette adresse
  symbols FICHIER | none       noms connus (défaut : atmos_sym.txt, ROM 1.1 et
                               VIA ; aucun pour un .COM)

Règles du source : celles de DIS.COM (docs/oric-basic.md § 5.2) ; référence : § 5.6.
"""
import os
import re
import shlex
import subprocess
import sys
import tempfile

R = os.path.dirname(os.path.abspath(__file__))

IMP, IMM, ZP, ZPX, ZPY, ABS, ABX, ABY, IND, INX, INY, REL = range(12)
LEN = (1, 2, 2, 2, 2, 3, 3, 3, 3, 2, 2, 2)
OPS = {
    'ADC': {1: 0x69, 2: 0x65, 3: 0x75, 5: 0x6D, 6: 0x7D, 7: 0x79, 9: 0x61, 10: 0x71},
    'AND': {1: 0x29, 2: 0x25, 3: 0x35, 5: 0x2D, 6: 0x3D, 7: 0x39, 9: 0x21, 10: 0x31},
    'ASL': {0: 0x0A, 2: 0x06, 3: 0x16, 5: 0x0E, 6: 0x1E},
    'BCC': {11: 0x90}, 'BCS': {11: 0xB0}, 'BEQ': {11: 0xF0},
    'BIT': {2: 0x24, 5: 0x2C},
    'BMI': {11: 0x30}, 'BNE': {11: 0xD0}, 'BPL': {11: 0x10},
    'BRK': {0: 0x00}, 'BVC': {11: 0x50}, 'BVS': {11: 0x70},
    'CLC': {0: 0x18}, 'CLD': {0: 0xD8}, 'CLI': {0: 0x58}, 'CLV': {0: 0xB8},
    'CMP': {1: 0xC9, 2: 0xC5, 3: 0xD5, 5: 0xCD, 6: 0xDD, 7: 0xD9, 9: 0xC1, 10: 0xD1},
    'CPX': {1: 0xE0, 2: 0xE4, 5: 0xEC}, 'CPY': {1: 0xC0, 2: 0xC4, 5: 0xCC},
    'DEC': {2: 0xC6, 3: 0xD6, 5: 0xCE, 6: 0xDE}, 'DEX': {0: 0xCA}, 'DEY': {0: 0x88},
    'EOR': {1: 0x49, 2: 0x45, 3: 0x55, 5: 0x4D, 6: 0x5D, 7: 0x59, 9: 0x41, 10: 0x51},
    'INC': {2: 0xE6, 3: 0xF6, 5: 0xEE, 6: 0xFE}, 'INX': {0: 0xE8}, 'INY': {0: 0xC8},
    'JMP': {5: 0x4C, 8: 0x6C}, 'JSR': {5: 0x20},
    'LDA': {1: 0xA9, 2: 0xA5, 3: 0xB5, 5: 0xAD, 6: 0xBD, 7: 0xB9, 9: 0xA1, 10: 0xB1},
    'LDX': {1: 0xA2, 2: 0xA6, 4: 0xB6, 5: 0xAE, 7: 0xBE},
    'LDY': {1: 0xA0, 2: 0xA4, 3: 0xB4, 5: 0xAC, 6: 0xBC},
    'LSR': {0: 0x4A, 2: 0x46, 3: 0x56, 5: 0x4E, 6: 0x5E}, 'NOP': {0: 0xEA},
    'ORA': {1: 0x09, 2: 0x05, 3: 0x15, 5: 0x0D, 6: 0x1D, 7: 0x19, 9: 0x01, 10: 0x11},
    'PHA': {0: 0x48}, 'PHP': {0: 0x08}, 'PLA': {0: 0x68}, 'PLP': {0: 0x28},
    'ROL': {0: 0x2A, 2: 0x26, 3: 0x36, 5: 0x2E, 6: 0x3E},
    'ROR': {0: 0x6A, 2: 0x66, 3: 0x76, 5: 0x6E, 6: 0x7E},
    'RTI': {0: 0x40}, 'RTS': {0: 0x60},
    'SBC': {1: 0xE9, 2: 0xE5, 3: 0xF5, 5: 0xED, 6: 0xFD, 7: 0xF9, 9: 0xE1, 10: 0xF1},
    'SEC': {0: 0x38}, 'SED': {0: 0xF8}, 'SEI': {0: 0x78},
    'STA': {2: 0x85, 3: 0x95, 5: 0x8D, 6: 0x9D, 7: 0x99, 9: 0x81, 10: 0x91},
    'STX': {2: 0x86, 4: 0x96, 5: 0x8E}, 'STY': {2: 0x84, 3: 0x94, 5: 0x8C},
    'TAX': {0: 0xAA}, 'TAY': {0: 0xA8}, 'TSX': {0: 0xBA}, 'TXA': {0: 0x8A},
    'TXS': {0: 0x9A}, 'TYA': {0: 0x98},
}
OPC = {c: (m.lower(), mode) for m, d in OPS.items() for mode, c in d.items()}
ZPDE = {ABS: ZP, ABX: ZPX, ABY: ZPY}          # forme page zéro d'un mode absolu
FIN = ("jmp", "rts", "rti", "brk")            # la suite s'arrête après
# vecteurs de la page 2 de l'Oric (l'adresse suit un JMP)
VECT = {0x0245: "IRQ (ROM 1.1)", 0x0248: "NMI (ROM 1.1)", 0x0229: "IRQ (ROM 1.0)",
        0x022C: "NMI (ROM 1.0)", 0x02F5: "commande !", 0x02FC: "fonction &"}
# mot-clé -> (deux tables, suivi comme du code, adresses - 1)
TABLES = {"table": (0, 1, 0), "table2": (1, 1, 0), "rtstable": (0, 1, 1),
          "rtstable2": (1, 1, 1), "pointers": (0, 0, 0), "pointers2": (1, 0, 0)}
NOM = re.compile(r"[A-Za-z_][A-Za-z0-9_]*$")
MODELE = """; %s : description de %s pour tools/dis65.py
; (python3 tools/dis65.py : liste des mots-clés ; adresses en hexadécimal)
;   entry ADR [Nom]            table ADR N [Nom]       table2 BAS HAUT N [Nom]
;   pointers ADR N [Nom]       rtstable ADR N [Nom]    data DEB-FIN [nom]
;   text DEB-FIN [Nom]         name ADR Nom            rem ADR texte
;   lo ADR CIBLE / hi ADR CIBLE (lda #<Lxxxx / lda #>Lxxxx)
%s
"""


class Erreur(Exception):
    pass


def hexa(s):
    try:
        v = int(s.lstrip("$#"), 16)
    except ValueError:
        raise Erreur("adresse en hexadécimal attendue : " + s)
    if not 0 <= v <= 0xFFFF:
        raise Erreur("adresse hors de $0000-$FFFF : " + s)
    return v


def lire_sym(chemin):
    """fichier de noms (format de atmos_sym.txt) -> {adresse: nom}"""
    d = {}
    for l in open(chemin, encoding="utf-8"):
        m = l.split("#")[0].split()
        if len(m) >= 2:
            d.setdefault(int(m[0], 16), m[1])
    return d


class Desc:
    """La description lue."""

    def __init__(self, chemin):
        self.chemin = chemin
        self.dossier = os.path.dirname(os.path.abspath(chemin))
        self.nomdis = os.path.basename(chemin)
        self.mem = None
        self.fichier = None
        self.base = 0
        self.entrees = []           # adresses
        self.tables = []            # (mot-clé, bas, haut ou None, n)
        self.zones = []             # ("data" | "text", début, fin, nom)
        self.noms = {}              # adresse -> nom
        self.rems = {}              # adresse -> [textes]
        self.lohi = {}              # adresse de l'instruction -> ("<" | ">", cible)
        self.sym = None             # None : défaut ; "" : aucun ; sinon chemin
        for no, ligne in enumerate(open(chemin, encoding="utf-8"), 1):
            try:
                self.ligne(ligne.rstrip("\r\n"))
            except Erreur as e:
                raise Erreur("%s ligne %d : %s" % (self.nomdis, no, e))
        if self.mem is None:
            raise Erreur("%s : pas de ligne « file »" % self.nomdis)

    def nommer(self, adr, nom):
        if not NOM.match(nom) or nom.upper() in OPS or nom.upper() in ("A", "X", "Y"):
            raise Erreur("nom refusé : " + nom)
        if self.noms.get(adr, nom) != nom:
            raise Erreur("deux noms pour $%04X : %s, %s" % (adr, self.noms[adr], nom))
        if nom in [n for a, n in self.noms.items() if a != adr]:
            raise Erreur("nom donné deux fois : " + nom)
        self.noms[adr] = nom

    def ligne(self, ligne):
        m = re.match(r"\s*rem\s+(\S+)\s?(.*)$", ligne, re.I)
        if m:
            self.rems.setdefault(hexa(m.group(1)), []).append(m.group(2).rstrip())
            return
        lex = shlex.shlex(ligne, posix=True)
        lex.whitespace_split = True
        lex.commenters = ";"
        try:
            w = list(lex)
        except ValueError as e:
            raise Erreur(str(e))
        if not w:
            return
        cle, p = w[0].lower(), w[1:]

        def arg(n, plus=0):
            if not n <= len(p) <= n + plus:
                raise Erreur("%s : %d paramètre(s) attendu(s)" % (cle, n))

        if cle == "file":
            arg(2, 1)
            self.lire_fichier(p)
        elif cle == "entry":
            arg(1, 1)
            self.entrees.append(hexa(p[0]))
            if len(p) > 1:
                self.nommer(hexa(p[0]), p[1])
        elif cle in TABLES:
            deux = TABLES[cle][0]
            arg(2 + deux, 1)
            bas = hexa(p[0])
            haut = hexa(p[1]) if deux else None
            try:
                n = int(p[1 + deux])
            except ValueError:
                raise Erreur("nombre d'entrées attendu : " + p[1 + deux])
            if n < 1:
                raise Erreur("nombre d'entrées : 1 au moins")
            self.tables.append((cle, bas, haut, n))
            if len(p) > 2 + deux:
                self.nommer(bas, p[2 + deux])
        elif cle in ("data", "text"):
            arg(1, 1)
            ab = p[0].split("-")
            if len(ab) != 2:
                raise Erreur("zone attendue : DEBUT-FIN")
            a, b = hexa(ab[0]), hexa(ab[1])
            if b < a:
                raise Erreur("zone à l'envers : " + p[0])
            nom = p[1] if len(p) > 1 else None
            self.zones.append((cle, a, b, nom))
            if nom:
                self.nommer(a, nom)
        elif cle == "name":
            arg(2)
            self.nommer(hexa(p[0]), p[1])
        elif cle in ("lo", "hi"):
            arg(2)
            self.lohi[hexa(p[0])] = ("<" if cle == "lo" else ">", hexa(p[1]))
        elif cle == "symbols":
            arg(1)
            self.sym = "" if p[0].lower() == "none" else os.path.join(self.dossier, p[0])
        else:
            raise Erreur("mot-clé inconnu : " + w[0])

    def lire_fichier(self, p):
        if self.mem is not None:
            raise Erreur("une seule ligne « file »")
        chemin = os.path.join(self.dossier, p[0])
        if not os.path.exists(chemin):
            raise Erreur("fichier absent : " + chemin)
        data = open(chemin, "rb").read()
        self.fichier = os.path.basename(p[0])
        if p[0].lower().endswith(".tap"):
            sys.path.insert(0, R)
            import untap
            bl = untap.blocs(data)
            if not p[1].isdigit() or not 1 <= int(p[1]) <= len(bl):
                raise Erreur("bloc du .TAP : 1 à %d" % len(bl))
            h, _, corps, coupe, _ = bl[int(p[1]) - 1]
            if not h[2] or coupe:
                raise Erreur("bloc %s : %s" % (p[1], "incomplet" if coupe else "BASIC"))
            self.base, self.mem = h[6] << 8 | h[7], corps
            self.fichier += " bloc " + p[1]
        else:
            self.base, self.mem = hexa(p[1]), data
            if len(p) > 2:
                fin = hexa(p[2])
                if not self.base <= fin < self.base + len(data):
                    raise Erreur("dernière adresse hors du fichier : " + p[2])
                self.mem = data[:fin - self.base + 1]
        if not self.mem or self.base + len(self.mem) > 0x10000:
            raise Erreur("fichier vide ou qui dépasse $FFFF")


class Dis:
    def __init__(self, d):
        self.d = d
        self.mem, self.base = d.mem, d.base
        self.fin = d.base + len(d.mem)          # première adresse après le fichier
        n = len(d.mem)
        self.zone = [None] * n                  # zone déclarée de chaque octet
        self.code = bytearray(n)                # 1 : début d'instruction, 2 : intérieur
        self.owner = list(range(n))             # début de l'élément qui contient l'octet
        self.inst = {}                          # adresse -> (mn, mode, opérande, long., écrit)
        self.avis = []
        self.arrets = []                        # suites arrêtées par un code inconnu
        self.cibles = []                        # adresses à suivre données par les tables
        sym = d.sym
        if sym is None:
            sym = os.path.join(R, "atmos_sym.txt")
            if d.fichier.upper().endswith(".COM") or not os.path.exists(sym):
                sym = ""
        self.sym = lire_sym(sym) if sym else {}
        self.poser_zones()
        self.suivre()
        self.decouper()
        self.etiqueter()

    def inf(self, a):
        return self.base <= a < self.fin

    def mot(self, a):
        o = a - self.base
        return self.mem[o] | self.mem[o + 1] << 8

    # ---- zones déclarées --------------------------------------------------
    def prendre(self, a, z, quoi):
        if not self.inf(a):
            raise Erreur("%s : $%04X hors du fichier" % (quoi, a))
        if self.zone[a - self.base] is not None:
            raise Erreur("%s : $%04X déjà dans une autre zone" % (quoi, a))
        self.zone[a - self.base] = z

    def poser_zones(self):
        d = self.d
        for cle, a, b, nom in d.zones:
            z = (cle, nom if cle == "data" else None)
            for x in range(a, b + 1):
                self.prendre(x, z, "%s %04X-%04X" % (cle, a, b))
        tables = list(d.tables)
        if self.base <= 0xFFFA and self.fin == 0x10000 \
                and not any(self.zone[0xFFFA - self.base:]):
            tables.append(("table", 0xFFFA, None, 3))       # vecteurs du 6502
        for cle, bas, haut, n in tables:
            deux, suivi, moins = TABLES[cle]
            quoi = "%s %04X" % (cle, bas)
            for k in range(n):
                if deux:
                    for x in (bas + k, haut + k):
                        if not self.inf(x):
                            raise Erreur("%s : $%04X hors du fichier" % (quoi, x))
                    v = self.mem[bas + k - self.base] | self.mem[haut + k - self.base] << 8
                    t = (v + moins) & 0xFFFF
                    self.prendre(bas + k, ("lo", t, moins), quoi)
                    self.prendre(haut + k, ("hi", t, moins), quoi)
                else:
                    x = bas + 2 * k
                    if not self.inf(x + 1):
                        raise Erreur("%s : $%04X hors du fichier" % (quoi, x + 1))
                    t = (self.mot(x) + moins) & 0xFFFF
                    self.prendre(x, ("word", t, moins), quoi)
                    self.prendre(x + 1, ("word2",), quoi)
                    self.owner[x + 1 - self.base] = x - self.base
                if suivi:
                    if self.inf(t):
                        self.cibles.append(t)
                    elif not (cle == "table" and bas == 0xFFFA and haut is None):
                        self.avis.append("%s : entrée %d ($%04X) hors du fichier"
                                         % (quoi, k, t))

    # ---- suivi du code ----------------------------------------------------
    def suivre(self):
        d = self.d
        a_suivre = list(d.entrees) if d.entrees else [self.base]
        for a in d.entrees:
            if not self.inf(a):
                raise Erreur("entry %04X : hors du fichier" % a)
        a_suivre += self.cibles
        mem, base = self.mem, self.base
        while a_suivre:
            a = a_suivre.pop()
            while self.inf(a) and not a in self.inst:
                o = a - base
                op = OPC.get(mem[o])
                if op is None:
                    self.arrets.append(a)
                    break
                mn, mode = op
                n = LEN[mode]
                if a + n > self.fin:
                    break
                if any(self.zone[o:o + n]):
                    self.avis.append("le code suivi entre dans une zone déclarée en $%04X" % a)
                    break
                opv = mem[o + 1] if n == 2 else mem[o + 1] | mem[o + 2] << 8 if n == 3 else 0
                self.inst[a] = [mn, mode, opv, n, n]
                if mode == REL:
                    a_suivre.append(a + 2 + (opv - 256 if opv > 127 else opv))
                elif mode == ABS and mn in ("jmp", "jsr"):
                    a_suivre.append(opv)
                if mn in FIN:
                    break
                a += n

    def decouper(self):
        """Une instruction dans laquelle en commence une autre s'arrête là."""
        for a, i in self.inst.items():
            for k in range(1, i[3]):
                if a + k in self.inst:
                    i[4] = k
                    break
            o = a - self.base
            self.code[o] = 1
            for k in range(1, i[4]):
                self.code[o + k] = 2
                self.owner[o + k] = o

    def cible(self, a):
        i = self.inst[a]
        return a + 2 + (i[2] - 256 if i[2] > 127 else i[2])

    def enbyt(self, a):
        """instruction écrite en .byt (xa ne redonnerait pas les mêmes octets)"""
        mn, mode, opv, n, ecrit = self.inst[a]
        return (ecrit < n
                or mode in ZPDE and opv < 0x100 and ZPDE[mode] in OPS[mn.upper()]
                or mode == REL and not 0 <= self.cible(a) <= 0xFFFF)

    def vise(self, a):
        """adresse visée par l'opérande (None : aucune), page zéro ?"""
        mn, mode, opv, n, ecrit = self.inst[a]
        if self.enbyt(a):
            return None, False
        if mode == REL:
            return self.cible(a), False
        if mode in (ABS, ABX, ABY, IND):
            return opv, False
        if mode == IMM:
            return (self.d.lohi[a][1] if a in self.d.lohi else None), False
        if mode == IMP:
            return None, False
        return opv, True

    # ---- étiquettes -------------------------------------------------------
    def debut(self, a):
        return self.base + self.owner[a - self.base]

    def etiqueter(self):
        d = self.d
        for a, (c, t) in list(d.lohi.items()):
            i = self.inst.get(a)
            v = t & 0xFF if c == "<" else t >> 8
            if i is None or i[1] != IMM or self.enbyt(a) or i[2] != v:
                self.avis.append("%s %04X %04X : pas une instruction immédiate de valeur $%02X"
                                 % ("lo" if c == "<" else "hi", a, t, v))
                del d.lohi[a]
        lab = set()
        for a in self.inst:
            t, zp = self.vise(a)
            if t is not None and not zp and self.inf(t):
                lab.add(self.debut(t))
        for z in self.zone:
            if z and z[0] in ("word", "lo", "hi") and self.inf(z[1]):
                lab.add(self.debut(z[1]))
        for a in list(d.entrees) + self.cibles:
            lab.add(self.debut(a))
        self.nom_int = {}                       # noms des adresses du fichier
        for a, nom in self.sym.items():
            if self.inf(a) and self.debut(a) == a:
                self.nom_int[a] = nom
        self.nom_ext = dict(self.sym)           # noms des adresses hors du fichier
        for a, nom in d.noms.items():
            if not self.inf(a):
                self.nom_ext[a] = nom
            elif self.debut(a) != a:
                self.avis.append("name %04X %s : au milieu d'un élément, écrire %s"
                                 % (a, nom, self.ref(a)))
            else:
                self.nom_int[a] = nom
        lab.update(self.nom_int)
        self.lab = lab
        pris = {}
        for a in lab:
            pris.setdefault(self.nomde(a), []).append(a)
        for nom, la in pris.items():
            if len(la) > 1:
                raise Erreur("nom %s : donné à $%04X et à $%04X" % (nom, la[0], la[1]))
        self.rems = {}
        for a, t in d.rems.items():
            if self.inf(a):
                self.rems.setdefault(self.debut(a), []).extend(t)
            else:
                self.avis.append("rem %04X : hors du fichier" % a)
        self.ext_vus = set()

    def nomde(self, a):
        return self.nom_int.get(a) or "L%04X" % a

    def ref(self, a):
        """texte d'une adresse sur 16 bits"""
        if self.inf(a):
            s = self.debut(a)
            return self.nomde(s) if s == a else "%s+%d" % (self.nomde(s), a - s)
        if a in self.nom_ext:
            self.ext_vus.add(a)
            return self.nom_ext[a]
        return "$%04X" % a

    def refzp(self, a):
        if not self.inf(a) and a in self.nom_ext:
            self.ext_vus.add(a)
            return self.nom_ext[a]
        return "$%02X" % a

    # ---- écriture ---------------------------------------------------------
    def operande(self, a, litt=False):
        mn, mode, opv, n, ecrit = self.inst[a]
        if mode == IMP:
            return ""
        if mode == IMM:
            if not litt and a in self.d.lohi:
                c, t = self.d.lohi[a]
                return " #%s%s" % (c, self.ref(t))
            return " #$%02X" % opv
        if mode == REL:
            t = self.cible(a)
            return " " + ("$%04X" % (t & 0xFFFF) if litt else self.ref(t))
        if mode in (ABS, ABX, ABY, IND):
            r = "$%04X" % opv if litt else self.ref(opv)
        else:
            r = "$%02X" % opv if litt else self.refzp(opv)
        return " " + {ZP: "%s", ABS: "%s", ZPX: "%s,x", ABX: "%s,x", ZPY: "%s,y", ABY: "%s,y",
                      IND: "(%s)", INX: "(%s,x)", INY: "(%s),y"}[mode] % r

    def instruction(self, a):
        """-> (texte, commentaire)"""
        i = self.inst[a]
        if self.enbyt(a):
            o = a - self.base
            return (".byt " + ",".join("$%02X" % b for b in self.mem[o:o + i[4]]),
                    i[0] + self.operande(a, True))
        return i[0] + self.operande(a), None

    def donnees(self, a, b, style):
        """octets de a à b (exclu) -> lignes ; style : None, "data" ou "text" """
        m = self.mem[a - self.base:b - self.base]
        out, buf = [], []
        par = 16 if style == "data" else 8

        def vider():
            for k in range(0, len(buf), par):
                out.append(".byt " + ",".join("$%02X" % x for x in buf[k:k + par]))
            del buf[:]

        def imprimable(c):
            return 0x20 <= c < 0x7F and c != 0x22

        i, n = 0, len(m)
        while i < n:
            j = i
            while j < n and m[j] == m[i]:
                j += 1
            if j - i >= 8 and not (style == "text" and imprimable(m[i])):
                vider()
                out.append(".dsb %d,$%02X" % (j - i, m[i]))
                i = j
                continue
            j = i
            if style != "data":
                while j < n and imprimable(m[j]):
                    j += 1
            if j - i >= (1 if style == "text" else 4):
                vider()
                for k in range(i, j, 40):
                    out.append('.asc "%s"' % m[k:min(j, k + 40)].decode("ascii"))
                i = j
                continue
            buf.append(m[i])
            i += 1
        vider()
        return out

    @staticmethod
    def ligne(lab, texte, com=None):
        s = (" " * 8 if not lab else "%-8s" % lab if len(lab) < 8 else lab + " ") + texte
        return "%-32s; %s" % (s, com) if com else s

    def ecrire(self, base_nom):
        """-> [(nom de fichier, lignes)], le principal en premier"""
        corps = []
        fichiers = []
        cur, cur_nom = corps, None
        a = self.base
        while a < self.fin:
            z = self.zone[a - self.base]
            zf = z[1] if z and z[0] == "data" else None
            if zf != cur_nom:
                cur_nom = zf
                if zf:
                    f = "%s_%s.s" % (base_nom, zf.lower())
                    cur = ["; %s : $%04X, inclus par %s.s" % (f, a, base_nom)]
                    fichiers.append((f, cur))
                    corps.append('#include "%s"' % f)
                else:
                    cur = corps
            for t in self.rems.get(a, ()):
                cur.append("; " + t if t else ";")
            lab = self.nomde(a) if a in self.lab else ""
            com = "$%04X" % a if lab and a in self.nom_int else None
            if a in self.inst:
                t, c = self.instruction(a)
                cur.append(self.ligne(lab, t, " : ".join(x for x in (com, c) if x)))
                a += self.inst[a][4]
            elif z and z[0] == "word":
                r = self.ref(z[1]) + ("-1" if z[2] and self.inf(z[1]) else "")
                if not self.inf(z[1]):
                    r = "$%04X" % self.mot(a)
                cur.append(self.ligne(lab, ".word " + r, com))
                a += 2
            elif z and z[0] in ("lo", "hi"):
                r = self.ref(z[1]) + ("-1" if z[2] and self.inf(z[1]) else "")
                c = "<" if z[0] == "lo" else ">"
                if not self.inf(z[1]):
                    r, c = "$%02X" % self.mem[a - self.base], ""
                cur.append(self.ligne(lab, ".byt %s%s" % (c, r), com))
                a += 1
            else:
                b = a + 1
                while b < self.fin and self.zone[b - self.base] is z and b not in self.inst \
                        and b not in self.lab and b not in self.rems:
                    b += 1
                for k, t in enumerate(self.donnees(a, b, z[0] if z else None)):
                    cur.append(self.ligne(lab if k == 0 else "", t, com if k == 0 else None))
                a = b
        d = self.d
        tete = ["; %s.s : %s, $%04X-$%04X" % (base_nom, d.fichier, self.base, self.fin - 1),
                "; écrit par tools/dis65.py d'après %s : c'est elle qu'on complète" % d.nomdis, ""]
        for x in sorted(self.ext_vus):
            n = self.nom_ext[x]
            tete.append("%s= $%0*X" % ("%-8s" % n if len(n) < 8 else n + " ",
                                       2 if x < 0x100 else 4, x))
        if self.ext_vus:
            tete.append("")
        tete += ["        *= $%04X" % self.base, ""]
        return [(base_nom + ".s", tete + corps)] + fichiers

    # ---- tables et pointeurs candidats ------------------------------------
    def candidats(self):
        """-> lignes à proposer pour la description"""
        normales = {a: i for a, i in self.inst.items() if not self.enbyt(a)}
        indirects = {i[2] for i in normales.values() if i[1] == IND}
        vus = {i[2] for i in normales.values() if i[1] in (ABS, ABX, ABY, IND)}

        def libre(x):
            return self.inf(x) and self.zone[x - self.base] is None \
                and not self.code[x - self.base]

        def vers_code(v):
            """l'adresse rangée en v, v+1 sert-elle à sauter ?"""
            if v in indirects:
                return "JMP ($%04X)" % v
            j = normales.get(v - 1)
            if j and j[1] == ABS and j[0] in ("jmp", "jsr"):
                return "%s modifié en $%04X" % (j[0].upper(), v - 1)
            return VECT.get(v)

        def routine(t):
            return self.inf(t) and self.code[t - self.base] != 2 \
                and self.zone[t - self.base] is None

        out = {}
        for a in sorted(normales):
            ch = [a]
            while len(ch) < 4:
                x = ch[-1] + normales[ch[-1]][3]
                if x not in normales:
                    break
                ch.append(x)
            if len(ch) < 3:
                continue
            i = [normales[c] for c in ch]
            # lda #bas : ldy #haut : jsr (convention de la ROM : A, Y)
            if i[0][1] == IMM and i[1][1] == IMM and i[0][0] == "lda" and i[2][0] == "jsr" \
                    and i[1][0] in ("ldy", "ldx") and ch[0] not in self.d.lohi:
                t = i[0][2] | i[1][2] << 8
                if libre(t):
                    out[ch[0]] = ["lo %04X %04X" % (ch[0], t),
                                  "hi %04X %04X      ; A et %s avant JSR $%04X : pointeur ?"
                                  % (ch[1], t, i[1][0][2].upper(), i[2][2])]
            if len(ch) < 4:
                continue
            paire = {"lda": "sta", "ldx": "stx", "ldy": "sty"}
            if not (paire.get(i[0][0]) == i[1][0] and paire.get(i[2][0]) == i[3][0]
                    and i[1][1] in (ZP, ABS) and i[3][1] in (ZP, ABS)
                    and abs(i[1][2] - i[3][2]) == 1):
                if (i[0][0] == i[2][0] == "lda" and i[1][0] == i[3][0] == "pha"
                        and i[0][1] == i[2][1] and i[0][1] in (ABX, ABY)):
                    haut, bas = i[0][2], i[2][2]          # l'octet haut est empilé d'abord
                    self.table_candidate(out, ch[0], bas, haut, "rtstable", vus,
                                         libre, routine, "empilé en $%04X, saut par RTS ?" % ch[0])
                continue
            premier_bas = i[1][2] < i[3][2]
            v = min(i[1][2], i[3][2])
            but = vers_code(v)
            if i[0][1] == IMM and i[2][1] == IMM:
                if ch[0] in self.d.lohi or ch[2] in self.d.lohi:
                    continue
                bas, haut = (0, 2) if premier_bas else (2, 0)
                t = i[bas][2] | i[haut][2] << 8
                if not self.inf(t) or 0x0300 <= v <= 0x030F:    # VIA : une durée
                    continue
                l = []
                if but and routine(t) and t not in self.inst:
                    l.append("entry %04X          ; rangé en $%04X : %s" % (t, v, but))
                elif not but and not libre(t):
                    continue
                l += ["lo %04X %04X" % (ch[bas], t),
                      "hi %04X %04X      ; rangé en $%04X%s"
                      % (ch[haut], t, v, "" if but else " : pointeur ?")]
                out[ch[0]] = l
            elif i[0][0] == i[2][0] == "lda" and i[0][1] == i[2][1] and i[0][1] in (ABX, ABY):
                bas, haut = (i[0][2], i[2][2]) if premier_bas else (i[2][2], i[0][2])
                self.table_candidate(out, ch[0], bas, haut, "table" if but else "pointers",
                                     vus, libre, routine,
                                     "lu en $%04X, rangé en $%04X%s"
                                     % (ch[0], v, " : " + but if but else ""))
        lignes = []
        for a in sorted(out):
            for l in out[a]:
                t, _, c = l.partition(";")
                l = "%-24s; %s" % (t.rstrip(), c.strip()) if c else t.rstrip()
                if l not in lignes:
                    lignes.append(l)
        return lignes

    def table_candidate(self, out, ou, bas, haut, cle, vus, libre, routine, note):
        moins = TABLES[cle][2]
        suivi = TABLES[cle][1]
        deux = haut != bas + 1
        pas = 1 if deux else 2
        limite = abs(haut - bas) if deux else 0x10000
        n = 0
        while n < limite:
            pb, ph = (bas + n, haut + n) if deux else (bas + 2 * n, bas + 2 * n + 1)
            if not (libre(pb) and libre(ph)) or n and (pb in vus or ph in vus):
                break
            t = (self.mem[pb - self.base] | self.mem[ph - self.base] << 8) + moins & 0xFFFF
            if not (routine(t) if suivi else self.inf(t)):
                break
            n += 1
        if not n:
            return
        if deux:
            out[ou] = ["%s2 %04X %04X %d  ; %s" % (cle, bas, haut, n, note)]
        else:
            out[ou] = ["%s %04X %d       ; %s" % (cle, bas, n, note)]


def controle(xa, dossier, source, mem, base):
    """Réassemble par xa et compare -> (bon, message)"""
    with tempfile.TemporaryDirectory() as tmp:
        sortie, err = os.path.join(tmp, "x.bin"), os.path.join(tmp, "x.err")
        p = subprocess.run([xa, "-o", sortie, "-e", err, source], cwd=dossier,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if p.returncode or not os.path.exists(sortie):
            e = open(err, errors="replace").read() if os.path.exists(err) else ""
            return False, "xa : ERREUR\n" + (e or p.stdout.decode("latin-1"))[:600]
        x = open(sortie, "rb").read()
    if x == mem:
        return True, "xa : fichier identique"
    for k, (u, v) in enumerate(zip(x, mem)):
        if u != v:
            return False, "xa : DIFFERENT, premier écart en $%04X (%02X au lieu de %02X)" \
                % (base + k, u, v)
    return False, "xa : DIFFERENT, %d octets au lieu de %d" % (len(x), len(mem))


def trouver_xa():
    for x in (os.environ.get("XA"), os.path.join(R, "xa")):
        if x and os.path.isfile(x):
            return os.path.abspath(x)
    return None


def nouvelle(args):
    """FICHIER ADR|BLOC [ENTREE...] -> chemin de la description écrite"""
    if len(args) < 2:
        raise Erreur("attendu : FICHIER.BIN ADRESSE [ENTREE...] ou JEU.TAP BLOC [ENTREE...]")
    chemin = args[0]
    base = os.path.splitext(os.path.basename(chemin))[0].lower()
    if chemin.lower().endswith(".tap"):
        base = "%s%s" % (re.sub(r"[^a-z0-9]+", "_", base).strip("_")[:16], args[1])
    desc = os.path.join(os.path.dirname(chemin) or ".", base + ".dis")
    if os.path.exists(desc):
        raise Erreur("%s existe déjà : python3 tools/dis65.py %s" % (desc, desc))
    nom = os.path.basename(chemin)
    l = ["file  %s %s" % ('"%s"' % nom if re.search(r"[\s;]", nom) else nom, args[1])]
    l += ["entry %04X" % hexa(e) for e in args[2:]]
    open(desc, "w", encoding="utf-8").write(MODELE % (os.path.basename(desc), nom, "\n".join(l)))
    print("%s écrit" % desc)
    return desc


def main():
    args = sys.argv[1:]
    sans_xa = "-n" in args
    muet = "-q" in args
    args = [a for a in args if a not in ("-n", "-q")]
    if not args:
        sys.exit(__doc__)
    try:
        desc = args[0] if args[0].lower().endswith(".dis") and len(args) == 1 else nouvelle(args)
        d = Desc(desc)
        dis = Dis(d)
        base_nom = os.path.splitext(d.nomdis)[0]
        fichiers = dis.ecrire(base_nom)
    except Erreur as e:
        sys.exit(str(e))
    print("%s $%04X-$%04X : %d octets" % (d.fichier, dis.base, dis.fin - 1, len(dis.mem)))
    print("%d instructions (%d octets de code), %d étiquettes, %d table(s)"
          % (len(dis.inst), sum(1 for c in dis.code if c), len(dis.lab),
             len(d.tables)))
    for nom, lignes in fichiers:
        texte = "\n".join(lignes) + "\n"
        open(os.path.join(d.dossier, nom), "w", encoding="utf-8", newline="\n").write(texte)
        print("%s : %d lignes, %d Ko" % (nom, len(lignes), (len(texte.encode()) + 512) // 1024))
    for a in dis.avis:
        print("attention : " + a)
    if dis.arrets:
        print("suite arrêtée par un code non documenté : "
              + " ".join("$%04X" % a for a in sorted(dis.arrets)[:8])
              + (" ... (%d)" % len(dis.arrets) if len(dis.arrets) > 8 else ""))
    bon = True
    if not sans_xa:
        xa = trouver_xa()
        if xa:
            bon, msg = controle(xa, d.dossier, fichiers[0][0], bytes(dis.mem), dis.base)
            print(msg)
        else:
            print("xa absent (tools/build_xa.sh) : pas de contrôle")
    if not muet:
        c = dis.candidats()
        if c:
            print("candidats (à vérifier, puis à copier dans %s) :" % d.nomdis)
            for l in c:
                print("  " + l)
    sys.exit(0 if bon else 1)


if __name__ == "__main__":
    main()
