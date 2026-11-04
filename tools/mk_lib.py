#!/usr/bin/env python3
"""Précompile les bibliothèques des programmes traduits en GRX.LIB.

  mk_lib.py DOSSIER            écrit DOSSIER/GRX.LIB
  mk_lib.py DOSSIER --verifie  compare en plus le lien complet à xa

DOSSIER contient les copies marquées de la disquette (tools/strip_inc.py
puis tools/mark_inc.py) : GRX.INC, ARR.INC, FIL.INC, SPR.INC, ANIM.INC,
ORIC.INC, HIRES.INC, et CPA.INC. Les sept bibliothèques sont assemblées
comme GRXASM les recopie (même ordre, mêmes routines, mêmes lignes) par un
assembleur du sous-ensemble xa d'ASM.COM, qui garde pour chaque octet
l'expression d'où il vient : un octet qui dépend d'une étiquette devient un
relogement. GRXASM y lit les besoins des routines ; ASM (directive #lib)
définit les symboles des routines gardées et recopie leurs octets relogés.
Le .COM obtenu est le même, octet par octet, qu'avec les .INC
(tools/test_lib.sh).

Les lignes sont groupées en fragments : lignes consécutives d'une même
routine (numéro des marques ;@, 0 : toujours recopiées) d'une même
bibliothèque. Un fragment est gardé si sa routine l'est (0 : si sa
bibliothèque est lue). Les constantes de CPA.INC sont recopiées comme des
nombres, sauf celles qu'ORIC.INC (GRXASM /O) définit autrement (BDOS : une
étiquette) : celles-là sont cherchées par leur nom au moment du lien.

Format (petit-boutiste) :
  "GL", version (1), longueur (2) du répertoire qui suit (ASM le saute)
  répertoire, pour GRXASM : nombre de bibliothèques (1, 7) ; pour chacune,
    numéro de la routine qui précède sa première (2) et nombre de routines
    (2) ; puis par routine, dans l'ordre : drapeau (1 : toujours gardée),
    nombre de besoins (1), besoins (2 chacun)
  nombre de fragments (2) ; par fragment : bibliothèque (1), routine (2),
    taille (2)
  nombre de noms externes (1) ; chacun terminé par 0
  nombre de symboles (2) ; par symbole : nom terminé par 0, drapeaux (1 :
    bit 0 étiquette, sinon nombre ; bit 1 nom cherché par GRXASM (étiquette
    d'une routine, ou constante qui la vaut) ; bits 4-6 bibliothèque),
    routine (2), valeur ou décalage (2), puis fragment (2) si étiquette
    code des fragments, à la suite : octet c ; c < $80 : c octets
      recopiés tels quels (c = 0 : fin du fragment) ; sinon relogement :
      bits 0-1 : 0 mot, 1 octet bas, 2 octet haut, 3 branchement relatif ;
      bit 2 : cible externe (1 octet : numéro du nom), sinon fragment (2) ;
      bit 3 : décalage (2) qui suit, sinon 0.
"""
import os
import re
import subprocess
import sys
import tempfile

ORDRE = ["GRX.INC", "ARR.INC", "FIL.INC", "SPR.INC", "ANIM.INC", "ORIC.INC", "HIRES.INC"]
I_ORIC = ORDRE.index("ORIC.INC")
VERSION = 1

def table_opcodes():
    """mnémonique -> {mode: opcode}, lu dans progs/asm_tab.s (celle d'ASM)"""
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "progs", "asm_tab.s")
    t = open(p, encoding="utf-8").read()
    noms = "".join(re.findall(r'\.asc "([A-Z]+)"', t.split("mn_ops")[0]))
    lignes = re.findall(r"\.byt ((?:\$[0-9A-F]{2},?){12})", t.split("mn_ops")[1])
    r = {}
    for i in range(len(noms) // 3):
        v = [int(x[1:], 16) for x in lignes[i].split(",")]
        r[noms[3 * i:3 * i + 3]] = {m: o for m, o in enumerate(v) if o != 0xFF}
    return r


OPS = table_opcodes()

IMP, IMM, ZP, ZPX, ZPY, ABS, ABX, ABY, IND, INX, INY, REL = range(12)


class Err(Exception):
    pass


# --- valeurs : constante + termes relogeables {clé: coefficient} ---------
class Lin:
    __slots__ = ("c", "t")

    def __init__(self, c=0, t=None):
        self.c = c
        self.t = {k: v for k, v in (t or {}).items() if v}

    def const(self):
        return not self.t

    def __add__(self, o):
        t = dict(self.t)
        for k, v in o.t.items():
            t[k] = t.get(k, 0) + v
        return Lin(self.c + o.c, t)

    def neg(self):
        return Lin(-self.c, {k: -v for k, v in self.t.items()})

    def __sub__(self, o):
        return self + o.neg()

    def single(self):
        """(clé, décalage) d'une valeur relogeable simple"""
        if len(self.t) != 1:
            return None
        (k, v), = self.t.items()
        return (k, self.c) if v == 1 else None


def lin_op(op, a, b):
    if op == "+":
        return a + b
    if op == "-":
        return a - b
    if not (a.const() and b.const()):
        raise Err("operation '%s' sur une adresse relogeable" % op)
    x, y = a.c, b.c
    r = {"*": lambda: x * y, "/": lambda: x // y if y else 0,
         "&": lambda: x & y, "|": lambda: x | y, "^": lambda: x ^ y,
         "<<": lambda: x << y, ">>": lambda: x >> y}[op]()
    return Lin(r & 0xFFFF)


PREC = {"|": 0, "^": 1, "&": 2, "<<": 3, ">>": 3, "+": 4, "-": 4, "*": 5, "/": 5}


class Expr:
    """analyse une expression de la syntaxe d'ASM ; look(nom) -> (Lin, connu)"""

    def __init__(self, s, look, pc):
        self.s, self.i, self.look, self.pc = s, 0, look, pc
        self.known = True

    def sp(self):
        while self.i < len(self.s) and self.s[self.i] in " \t":
            self.i += 1

    def peek(self):
        self.sp()
        return self.s[self.i] if self.i < len(self.s) else ""

    def top(self):
        """-> (Lin, mode) ; mode '' , '<' ou '>'"""
        c = self.peek()
        if c in "<>":
            self.i += 1
            return self.level(0), c
        return self.level(0), ""

    def getop(self):
        self.sp()
        for o in ("<<", ">>", "+", "-", "*", "/", "&", "|", "^"):
            if self.s.startswith(o, self.i):
                return o
        return None

    def level(self, n):
        if n == 6:
            return self.unary()
        v = self.level(n + 1)
        while True:
            o = self.getop()
            if o is None or PREC[o] != n:
                return v
            self.i += len(o)
            w = self.level(n + 1)
            v = lin_op(o, v, w)

    def unary(self):
        c = self.peek()
        if c == "-":
            self.i += 1
            return self.unary().neg()
        return self.primary()

    def primary(self):
        c = self.peek()
        s = self.s
        if c == "(":
            self.i += 1
            v = self.level(0)
            if self.peek() != ")":
                raise Err("parenthese")
            self.i += 1
            return v
        if c == "$":
            m = re.match(r"\$([0-9A-Fa-f]+)", s[self.i:])
            self.i += m.end()
            return Lin(int(m.group(1), 16))
        if c == "%":
            m = re.match(r"%([01]+)", s[self.i:])
            self.i += m.end()
            return Lin(int(m.group(1), 2))
        if c.isdigit():
            m = re.match(r"[0-9]+", s[self.i:])
            self.i += m.end()
            return Lin(int(m.group(0)))
        if c in "'\"":
            v = ord(s[self.i + 1])
            self.i += 2
            if self.i < len(s) and s[self.i] == c:
                self.i += 1
            return Lin(v)
        if c == "*":
            self.i += 1
            return self.pc
        m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", s[self.i:])
        if not m:
            raise Err("expression : " + s)
        self.i += m.end()
        v, k = self.look(m.group(0))
        if not k:
            self.known = False
        return v


def eval_expr(s, look, pc):
    e = Expr(s, look, pc)
    v, m = e.top()
    if e.peek() not in ("", ")") and not s[e.i:].lstrip().startswith(","):
        pass
    return v, m, e.known, e.i


# --- découpage des lignes --------------------------------------------------
def code_part(l):
    """la ligne sans son commentaire (hors chaînes)"""
    q = None
    for i, c in enumerate(l):
        if q:
            if c == q:
                q = None
        elif c in "\"'":
            # 'c' ou "c" : un caractère ; une chaîne "..." peut être longue
            q = c
        elif c == ";":
            return l[:i].rstrip()
    return l.rstrip()


def split_items(s):
    """éléments d'une directive, séparés par des virgules hors chaînes"""
    r, q, cur = [], None, ""
    for c in s:
        if q:
            cur += c
            if c == q:
                q = None
        elif c in "\"'":
            q = c
            cur += c
        elif c == ",":
            r.append(cur.strip())
            cur = ""
        else:
            cur += c
    if cur.strip():
        r.append(cur.strip())
    return r


def lire_marques(dossier, fichiers):
    """lignes des bibliothèques comme GRXASM les voit :
    [(bibliothèque, routine, ligne)], routines {n: dict}"""
    lignes, rout = [], {}
    for si, f in enumerate(fichiers):
        cnt = cur = 0
        kname = False
        for l in open(os.path.join(dossier, f), encoding="latin-1").read().split("\n"):
            l = l.rstrip("\r")
            if l.startswith(";@"):
                c = l[2:3]
                if c == "#":
                    cnt = int(l[3:6], 16)
                    continue
                if c == "=":
                    cur = int(l[3:6], 16)
                    continue
                if c == "+":
                    deps = l[3:]
                else:
                    cnt += 1
                    cur = cnt
                    kname = True
                    r = rout.setdefault(cur, {"n": cur, "noms": [], "deps": []})
                    r["sec"], r["toujours"] = si, c == "*"
                    deps = l[3:] if c == "*" else l[2:]
                for i in range(0, len(deps) - 2, 3):
                    rout[cur]["deps"].append(int(deps[i:i + 3], 16))
                continue
            if cur and (kname or re.match(r"^[A-Za-z_]\w*\s*=", l)):
                m = re.match(r"^[A-Za-z0-9_]+", l)
                nm = m.group(0) if m else ""
                if kname or nm:
                    r = rout.setdefault(cur, {"n": cur, "noms": [], "deps": []})
                    if nm and nm not in r["noms"]:
                        r["noms"].append(nm)
            kname = False
            if not l.strip():
                continue
            lignes.append((si, cur, l))
    return lignes, rout


def lire_cpa(dossier):
    sy = {}
    for l in open(os.path.join(dossier, "CPA.INC"), encoding="latin-1"):
        l = code_part(l.rstrip("\r\n"))
        m = re.match(r"^([A-Za-z_]\w*)\s*=\s*(.+)$", l)
        if m:
            v, _, _, _ = eval_expr(m.group(2), lambda n: (Lin(sy[n]), True), Lin(0))
            sy[m.group(1)] = v.c & 0xFFFF
    return sy


# --- l'assembleur ------------------------------------------------------------
class Asm:
    def __init__(self, lignes, contexte, externes):
        self.lignes = lignes            # [(sec, routine, texte)]
        self.ctx = contexte             # nom -> nombre (CPA.INC), connus d'avance
        self.ext = externes             # noms cherchés au moment du lien
        self.sym = {}                   # (bloc, nom) -> [Lin|None, ligne de définition]
        self.parent = {0: None}
        self.frags = []                 # dicts : sec, rout, taille, items
        self.inconnus = set()           # noms définis par le programme (O_FILES)

    # recherche d'un nom depuis le bloc b ; passe 1 : seulement défini avant
    def find(self, b, nom, p1, li):
        while b is not None:
            s = self.sym.get((b, nom))
            if s is not None and (not p1 or s[1] < li):
                return s
            b = self.parent[b]
        return None

    def look_fn(self, b, p1, li):
        def look(nom):
            if nom in self.ext:
                s = self.find(b, nom, p1, li)
                if nom in self.ctx:
                    return Lin(0, {("x", nom): 1}), True
                if s is None:
                    return Lin(0, {("x", nom): 1}), False
                return Lin(0, {("x", nom): 1}), s[0] is not None
            s = self.find(b, nom, p1, li)
            if s is None or s[0] is None:
                if nom in self.ctx:
                    return Lin(self.ctx[nom]), True
                if p1:
                    return Lin(0x1234), False
                self.inconnus.add(nom)          # défini par le programme
                return Lin(0, {("x", nom): 1}), True
            return s[0], True
        return look

    def run(self):
        # passe 1 : tailles, symboles ; mode page zéro décidé ici
        self.mode = {}
        self.consts = []                # (clé, expression, bloc, ligne)
        blocs = [0]
        nb = 0
        cle = None
        for li, (sec, rout, l) in enumerate(self.lignes):
            if (sec, rout) != cle:
                self.frags.append({"sec": sec, "rout": rout, "taille": 0, "items": []})
                cle = (sec, rout)
            fr = len(self.frags) - 1
            f = self.frags[fr]
            here = Lin(f["taille"], {("f", fr): 1})
            b = blocs[-1]
            c = code_part(l)
            if not c:
                continue
            m = re.match(r"^([A-Za-z_]\w*)\s*=\s*(.+)$", c)
            if m:
                v, md, known, _ = eval_expr(m.group(2), self.look_fn(b, True, li), here)
                if md:
                    raise Err("constante < > : " + c)
                self.sym[(b, m.group(1))] = [v if known else None, li]
                self.consts.append(((b, m.group(1)), m.group(2), b, li, here))
                self.lineinfo(li, None)
                continue
            if c[0] not in " \t.":
                m = re.match(r"^([A-Za-z_]\w*):?(?:\s+(.*))?$", c)
                if not m:
                    raise Err("ligne : " + c)
                m = (m.group(1), m.group(2) or "")
                nom, c = m
                if (b, nom) in self.sym:
                    raise Err("double : " + nom)
                self.sym[(b, nom)] = [here, li]
            c = c.strip()
            if not c:
                continue
            if c == ".(":
                nb += 1
                self.parent[nb] = b
                blocs.append(nb)
                continue
            if c == ".)":
                blocs.pop()
                continue
            f["taille"] += self.size(c, b, li, here)
        # constantes qui dépendaient de noms définis plus loin
        for _ in range(4):
            for k, ex, b, li, here in self.consts:
                v, _, _, _ = eval_expr(ex, self.look_fn(b, False, li), here)
                self.sym[k][0] = v
        # passe 2 : octets
        blocs = [0]
        nb = 0
        cle = None
        fr = -1
        pos = 0
        for li, (sec, rout, l) in enumerate(self.lignes):
            if (sec, rout) != cle:
                fr += 1
                pos = 0
                cle = (sec, rout)
            f = self.frags[fr]
            b = blocs[-1]
            c = code_part(l)
            if not c or re.match(r"^([A-Za-z_]\w*)\s*=", c):
                continue
            if c[0] not in " \t.":
                c = re.match(r"^[A-Za-z_]\w*:?(?:\s+(.*))?$", c).group(1) or ""
            c = c.strip()
            if not c:
                continue
            if c == ".(":
                nb += 1
                blocs.append(nb)
                continue
            if c == ".)":
                blocs.pop()
                continue
            here = Lin(pos, {("f", fr): 1})
            it = self.gen(c, b, li, here)
            pos += sum(2 if x[0] == "w" else 1 for x in it)
            f["items"] += it
        for f in self.frags:
            n = sum(2 if x[0] == "w" else 1 for x in f["items"])
            assert n == f["taille"], (f, n)
        return self

    def lineinfo(self, li, m):
        self.mode[li] = m

    def operand(self, s):
        """-> (mode syntaxique, expression)"""
        s = s.strip()
        if not s:
            return IMP, None
        if s[0] == "#":
            return IMM, s[1:]
        m = re.match(r"^\((.*),\s*[xX]\s*\)$", s)
        if m:
            return INX, m.group(1)
        m = re.match(r"^\((.*)\)\s*,\s*[yY]$", s)
        if m:
            return INY, m.group(1)
        if s[0] == "(" and s.endswith(")") and self.balanced(s[1:-1]):
            return IND, s[1:-1]
        m = re.match(r"^(.*),\s*([xXyY])$", s)
        if m:
            return (ABX if m.group(2) in "xX" else ABY), m.group(1)
        return ABS, s

    @staticmethod
    def balanced(s):
        d = 0
        for c in s:
            d += c == "("
            d -= c == ")"
            if d < 0:
                return False
        return d == 0

    def size(self, c, b, li, here):
        t = c.split(None, 1)
        op = t[0]
        arg = t[1] if len(t) > 1 else ""
        if op.startswith("."):
            d = op.lower()
            if d in (".byt", ".byte", ".asc"):
                n = 0
                for x in split_items(arg):
                    if x[0] == '"' and x.endswith('"') and len(x) != 3:
                        n += len(x) - 2
                    else:
                        n += 1
                return n
            if d == ".word":
                return 2 * len(split_items(arg))
            if d == ".dsb":
                x = split_items(arg)
                v, _, k, _ = eval_expr(x[0], self.look_fn(b, True, li), here)
                if not (k and v.const()):
                    raise Err(".dsb inconnu")
                return v.c
            raise Err("directive : " + c)
        mn = op.upper()
        if mn not in OPS:
            raise Err("mnemonique : " + c)
        tab = OPS[mn]
        sm, ex = self.operand(arg)
        if sm == IMP:
            md = IMP
        elif sm == IMM:
            md = IMM
        elif sm in (IND, INX, INY):
            md = sm
        else:
            if REL in tab:
                self.mode[li] = REL
                return 2
            v, md_, known, _ = eval_expr(ex, self.look_fn(b, True, li), here)
            z = {ABS: ZP, ABX: ZPX, ABY: ZPY}[sm]
            if z in tab and ((known and v.const() and 0 <= v.c < 256) or sm not in tab):
                md = z
            else:
                md = sm
        if md not in tab:
            raise Err("mode : " + c)
        self.mode[li] = md
        return {IMP: 1, IMM: 2, ZP: 2, ZPX: 2, ZPY: 2, INX: 2, INY: 2, REL: 2}.get(md, 3)

    def byte_item(self, v, md, quoi):
        """un octet : nombre, ou relogement (octet bas, haut)"""
        if v.const():
            x = v.c
            if md == ">":
                x = (x >> 8) & 0xFF
            elif md == "<":
                x &= 0xFF
            else:
                if not -128 <= x <= 255:
                    raise Err("octet hors limites : " + quoi)
                x &= 0xFF
            return ("b", x)
        if v.single() is None:
            raise Err("valeur relogeable composee : " + quoi)
        if md == "":
            raise Err("adresse dans un octet : " + quoi)
        return ("l" if md == "<" else "h", v)

    def gen(self, c, b, li, here):
        look = self.look_fn(b, False, li)
        t = c.split(None, 1)
        op = t[0]
        arg = t[1] if len(t) > 1 else ""
        if op.startswith("."):
            d = op.lower()
            out = []
            if d in (".byt", ".byte", ".asc"):
                for x in split_items(arg):
                    if x[0] == '"' and x.endswith('"') and len(x) != 3:
                        out += [("b", ord(ch)) for ch in x[1:-1]]
                    else:
                        v, md, _, _ = eval_expr(x, look, here)
                        out.append(self.byte_item(v, md, c))
                return out
            if d == ".word":
                for x in split_items(arg):
                    v, md, _, _ = eval_expr(x, look, here)
                    if md:
                        raise Err(".word < > : " + c)
                    out.append(("w", v) if not v.const() else ("w", Lin(v.c & 0xFFFF)))
                return out
            if d == ".dsb":
                x = split_items(arg)
                n = eval_expr(x[0], look, here)[0].c
                f = eval_expr(x[1], look, here)[0].c & 0xFF if len(x) > 1 else 0
                return [("b", f)] * n
        mn = op.upper()
        tab = OPS[mn]
        md = self.mode[li]
        sm, ex = self.operand(arg)
        out = [("b", tab[md])]
        if md == IMP:
            return out
        v, vm, _, _ = eval_expr(ex, look, here)
        if md == REL:
            if v.const():
                raise Err("branchement vers un nombre : " + c)
            d = v - (here + Lin(2))
            if d.const():
                if not -128 <= d.c <= 127:
                    raise Err("branchement trop loin : " + c)
                return out + [("b", d.c & 0xFF)]
            return out + [("r", v)]
        if md == IMM:
            return out + [self.byte_item(v, vm or "", c) if vm or not v.const()
                          else self.byte_item(v, "", c)]
        if vm:
            raise Err("< > hors de # : " + c)
        if md in (ZP, ZPX, ZPY, INX, INY):
            if not v.const() or not 0 <= v.c < 256:
                raise Err("page zero : " + c)
            return out + [("b", v.c)]
        if v.const():
            return out + [("w", Lin(v.c & 0xFFFF))]
        return out + [("w", v)]


# --- lien (contrôle) et écriture du fichier ---------------------------------
def adresses(frags, garde, base):
    adr, pc = {}, base
    for i, f in enumerate(frags):
        if garde(f):
            adr[i] = pc
            pc += f["taille"]
    return adr, pc


def valeur(v, adr, ext):
    x = v.c
    for (k, n), co in v.t.items():
        if k == "f":
            if n not in adr:
                raise Err("fragment non garde")
            x += co * adr[n]
        else:
            x += co * ext[n]
    return x & 0xFFFF


def lien(frags, garde, base, ext):
    adr, _ = adresses(frags, garde, base)
    out = bytearray()
    for i, f in enumerate(frags):
        if i not in adr:
            continue
        for it in f["items"]:
            k = it[0]
            if k == "b":
                out.append(it[1])
            elif k == "w":
                x = valeur(it[1], adr, ext)
                out += bytes([x & 0xFF, x >> 8])
            elif k == "l":
                out.append(valeur(it[1], adr, ext) & 0xFF)
            elif k == "h":
                out.append(valeur(it[1], adr, ext) >> 8)
            elif k == "r":
                d = valeur(it[1], adr, ext) - (base + len(out) + 1)
                d = (d + 0x8000) % 0x10000 - 0x8000
                if not -128 <= d <= 127:
                    raise Err("branchement trop loin")
                out.append(d & 0xFF)
    return bytes(out)


def ecrit(chemin, frags, sym, rout, nsec, sec_first):
    w2 = lambda x: bytes([x & 0xFF, (x >> 8) & 0xFF])  # noqa: E731
    o = bytearray([nsec])
    for si in range(nsec):
        mes = sorted(n for n in rout if rout[n]["sec"] == si)
        assert mes == list(range(sec_first[si] + 1, sec_first[si] + 1 + len(mes)))
        o += w2(sec_first[si]) + w2(len(mes))
    for n in sorted(rout):                  # besoins
        r = rout[n]
        assert len(r["deps"]) < 256
        o += bytes([1 if r["toujours"] else 0, len(r["deps"]), ])
        for x in r["deps"]:
            o += w2(x)
    o = bytearray(b"GL") + bytes([VERSION]) + w2(len(o)) + o
    ext = sorted({k[1] for f in frags for it in f["items"] if it[0] != "b"
                  for k in it[1].t if k[0] == "x"})
    assert len(ext) < 256
    o += w2(len(frags))
    for f in frags:
        o += bytes([f["sec"]]) + w2(f["rout"]) + w2(f["taille"])
    o.append(len(ext))
    for n in ext:
        o += n.encode("latin-1") + b"\0"
    o += w2(len(sym))
    for nom, (sec, rt, v) in sym:
        fl = sec << 4
        if rt and nom in rout[rt]["noms"]:
            fl |= 2                         # nom cherché par GRXASM
        if not v.const():
            fl |= 1
        o += nom.encode("latin-1") + b"\0" + bytes([fl]) + w2(rt)
        if v.const():
            o += w2(v.c)
        else:
            (k, n), off = v.single()
            o += w2(off) + w2(n)
    for f in frags:
        lit = bytearray()

        def flush():
            while lit:
                o.append(min(len(lit), 127))
                o.extend(lit[:127])
                del lit[:127]
        for it in f["items"]:
            if it[0] == "b":
                lit.append(it[1])
                continue
            if it[0] == "w":
                x = it[1]
                if x.const():
                    lit += bytes([x.c & 0xFF, (x.c >> 8) & 0xFF])
                    continue
            flush()
            ty = {"w": 0, "l": 1, "h": 2, "r": 3}[it[0]]
            (k, n), off = it[1].single()
            c = 0x80 | ty
            if k == "x":
                c |= 4
            if off & 0xFFFF:
                c |= 8
            o.append(c)
            o += bytes([ext.index(n)]) if k == "x" else w2(n)
            if off & 0xFFFF:
                o += w2(off & 0xFFFF)
        flush()
        o.append(0)
    open(chemin, "wb").write(o)
    return len(o)


def lit_lib(chemin, masque, bits, ext_val):
    """décode GRX.LIB comme ASM : (symboles {nom: valeur}, octets) pour le
    lien des routines choisies (masque : bibliothèques lues ; bits : routines)
    à partir de base ; ext_val(nom) : valeur d'un nom externe"""
    d = open(chemin, "rb").read()
    p = [0]

    def b1():
        p[0] += 1
        return d[p[0] - 1]

    def b2():
        return b1() | b1() << 8

    def nom():
        i = d.index(b"\0", p[0])
        s = d[p[0]:i].decode("latin-1")
        p[0] = i + 1
        return s
    assert d[:3] == b"GL" + bytes([VERSION])
    p[0] = 3
    fin = b2() + 5
    nsec = b1()
    nr = 0
    for _ in range(nsec):
        b2()
        nr += b2()
    for _ in range(nr):
        b1()
        k = b1()
        p[0] += 2 * k
    assert p[0] == fin
    garde = lambda sec, r: masque >> sec & 1 and (r == 0 or bits[r])  # noqa: E731
    return d, p, b1, b2, nom, garde


def lien_lib(chemin, masque, bits, base, ext_val):
    d, p, b1, b2, nom, garde = lit_lib(chemin, masque, bits, ext_val)
    nf = b2()
    fr = [(b1(), b2(), b2()) for _ in range(nf)]
    adr, pc = {}, base
    for i, (sec, r, t) in enumerate(fr):
        if garde(sec, r):
            adr[i] = pc
            pc += t
    ne = b1()
    ext = [nom() for _ in range(ne)]
    sy = {}
    for _ in range(b2()):
        n = nom()
        fl, r, v = b1(), b2(), b2()
        if fl & 1:
            f = b2()
        if garde(fl >> 4 & 7, r):
            sy[n] = (adr[f] + v) & 0xFFFF if fl & 1 else v
    ev = [None] * ne
    out = bytearray()
    for i, (sec, r, t) in enumerate(fr):
        k = i in adr
        while True:
            c = b1()
            if c == 0:
                break
            if c < 0x80:
                if k:
                    out += d[p[0]:p[0] + c]
                p[0] += c
                continue
            if c & 4:
                j = b1()
                if k and ev[j] is None:
                    ev[j] = sy[ext[j]] if ext[j] in sy else ext_val(ext[j])
                x = ev[j] if k else 0
            else:
                f = b2()
                x = adr.get(f, 0)
            if c & 8:
                x += b2()
            if not k:
                continue
            x &= 0xFFFF
            ty = c & 3
            if ty == 0:
                out += bytes([x & 0xFF, x >> 8])
            elif ty == 1:
                out.append(x & 0xFF)
            elif ty == 2:
                out.append(x >> 8)
            else:
                dd = (x - (base + len(out) + 1) + 0x8000) % 0x10000 - 0x8000
                assert -128 <= dd <= 127
                out.append(dd & 0xFF)
    assert len(out) == pc - base
    return sy, bytes(out)


def assemble(dossier):
    tous, rout = lire_marques(dossier, ORDRE)
    cpa = lire_cpa(dossier)
    # variante /O : ORIC.INC à la place de CPA.INC
    ao = Asm(tous, {}, set()).run()
    gsym = {n: s[0] for (b, n), s in ao.sym.items() if b == 0}
    duals = {n for n in cpa if n in gsym and (not gsym[n].const() or gsym[n].c != cpa[n])}
    ao = Asm(tous, {}, duals).run()
    # variante CP/A : sans ORIC.INC, CPA.INC connue d'avance
    lc = [x for x in tous if x[0] != I_ORIC]
    ac = Asm(lc, cpa, duals).run()
    # même code hors d'ORIC.INC (sinon une seule bibliothèque ne suffit pas)
    fo = [f for f in ao.frags if f["sec"] != I_ORIC]
    if len(fo) != len(ac.frags):
        raise Err("fragments differents entre CP/A et /O")
    io = [i for i, f in enumerate(ao.frags) if f["sec"] != I_ORIC]
    remap = dict(enumerate(io))                  # fragment de ac -> de ao

    def rm(v):
        return Lin(v.c, {(("f", remap[k[1]]) if k[0] == "f" else k): c for k, c in v.t.items()})
    for i, (a, b) in enumerate(zip(fo, ac.frags)):
        ib = [(it[0], rm(it[1]) if it[0] != "b" else it[1]) for it in b["items"]]
        sa = [(it[0], it[1] if it[0] == "b" else (it[1].c, tuple(sorted(it[1].t.items()))))
              for it in a["items"]]
        sb = [(it[0], it[1] if it[0] == "b" else (it[1].c, tuple(sorted(it[1].t.items()))))
              for it in ib]
        if sa != sb:
            raise Err("code different entre CP/A et /O (routine %d)" % a["rout"])
    # symboles globaux, dans l'ordre du texte ; propriétaire : routine de la ligne
    sym = []
    for (b, n), (v, li) in sorted(ao.sym.items(), key=lambda x: x[1][1]):
        if b != 0 or n in duals and tous[li][0] != I_ORIC:
            continue
        if not v.const() and v.single() is None:
            raise Err("symbole compose : " + n)
        if not v.const() and v.single()[0][0] == "x":
            raise Err("symbole externe : " + n)
        sym.append((n, (tous[li][0], tous[li][1], v)))
    secf = {}
    for si in range(len(ORDRE)):
        mes = [n for n in rout if rout[n]["sec"] == si]
        secf[si] = min(mes) - 1
    return ao, ac, sym, rout, secf, cpa, duals


def verifie(dossier, ao, ac, cpa, duals, xa, chemin, nr):
    """lien complet (toutes les routines) == xa, pour CP/A et pour /O"""
    tous, _ = lire_marques(dossier, ORDRE)
    with tempfile.TemporaryDirectory() as t:
        for oric in (False, True):
            src = ([] if oric else ['#include "CPA.INC"']) + ["*= $0503"]
            prog = sorted(ao.inconnus | ac.inconnus)
            src += ["%s .byt 0" % n for n in prog]
            src += [l for s, r, l in tous if oric or s != I_ORIC]
            open(os.path.join(t, "CPA.INC"), "wb").write(
                open(os.path.join(dossier, "CPA.INC"), "rb").read())
            open(os.path.join(t, "t.s"), "w", encoding="latin-1").write("\n".join(src) + "\n")
            r = subprocess.run([xa, "-o", "t.bin", "t.s"], cwd=t, capture_output=True, text=True)
            if r.returncode:
                raise Err("xa : " + (r.stdout + r.stderr)[:300])
            ref = open(os.path.join(t, "t.bin"), "rb").read()
            a = ao if oric else ac
            ext = {}
            if oric:
                adr, _ = adresses(a.frags, lambda f: True, 0x0503 + len(prog))
                for n in duals:
                    ext[n] = valeur(a.sym[(0, n)][0], adr, {})
            else:
                ext = {n: cpa[n] for n in duals}
            for i, n in enumerate(prog):
                ext[n] = 0x0503 + i
            mine = bytes(len(prog)) + lien(a.frags, lambda f: True, 0x0503 + len(prog), ext)
            masque = 0x7F if oric else 0x7F & ~(1 << I_ORIC)
            _, lb = lien_lib(chemin, masque, [1] * (nr + 1), 0x0503 + len(prog),
                             lambda n: ext[n])
            if bytes(len(prog)) + lb != ref:
                raise Err("GRX.LIB lu different de xa (%s)" % ("/O" if oric else "CP/A"))
            if mine != ref:
                i = next((i for i in range(min(len(mine), len(ref))) if mine[i] != ref[i]),
                         min(len(mine), len(ref)))
                raise Err("different de xa (%s) a $%04X (%d/%d octets)"
                          % ("/O" if oric else "CP/A", 0x0503 + i, len(mine), len(ref)))
    return True


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    d = sys.argv[1]
    try:
        ao, ac, sym, rout, secf, cpa, duals = assemble(d)
        chemin = os.path.join(d, "GRX.LIB")
        n = ecrit(chemin, ao.frags, sym, rout, len(ORDRE), secf)
        if "--verifie" in sys.argv:
            xa = os.environ.get("XA") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "xa")
            verifie(d, ao, ac, cpa, duals, xa, chemin, max(rout))
    except Err as e:
        sys.exit("mk_lib : %s" % e)
    print("GRX.LIB : %d octets, %d routines, %d fragments, %d symboles, externes : %s"
          % (n, len(rout), len(ao.frags), len(sym),
             " ".join(sorted(duals | ao.inconnus | ac.inconnus))))


if __name__ == "__main__":
    main()
