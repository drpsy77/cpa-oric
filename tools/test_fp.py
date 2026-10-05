#!/usr/bin/env python3
"""Teste progs/fp_inc.s (décimaux « à la Oric », 5 octets) dans un 6502
simulé (py65), contre un calcul exact en fractions.

  python3 tools/test_fp.py [nombre de tirages par opération, 2000 par défaut]

Tolérance : 1 unité du dernier bit (ulp, 2^-32 relatif) pour + - * /, la
lecture et les conversions ; l'affichage doit redonner la valeur à 9
chiffres significatifs près (dernier chiffre à 1 près)."""
import os, sys, random, re, subprocess, tempfile
from fractions import Fraction as F
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'pylib'))
from py65.devices.mpu6502 import MPU

N = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
random.seed(1)

# --- assemblage du banc d'essai -------------------------------------------
xa = os.environ.get('XA') or (os.path.join(HERE, 'xa') if os.path.exists(os.path.join(HERE, 'xa')) else 'xa')
binf = tempfile.mktemp()
r = subprocess.run([xa, '-o', binf, 'fp_harness.s'], cwd=HERE, capture_output=True, text=True)
if r.returncode:
    print(r.stdout, r.stderr); sys.exit(1)
code = open(binf, 'rb').read(); os.remove(binf)
mpu = MPU()
mem = mpu.memory
for i, b in enumerate(code):
    mem[0x1000 + i] = b
ADD, SUB, MUL, DIV, CMP, ITOF, TOINT, TRUNC, RND, PARSE, PRINT, SQRT, EXP, LN, SIN, COS, ATN, SIND, COSD, ATND = range(0x1000, 0x103C, 3)

def call(addr):
    mem[0x0200:0x0203] = [0x20, addr & 255, addr >> 8]
    mem[0x0203] = 0
    mem[0x02FE] = 0
    mem[0x02FF] = 0
    mpu.sp = 0xFF
    mpu.pc = 0x0200
    n = 0
    while mpu.pc != 0x0203:
        mpu.step(); n += 1
        if n > 2_000_000:
            raise RuntimeError('boucle sans fin')
    return n

# --- format ----------------------------------------------------------------
def decode(b):
    e, m0, m1, m2, m3 = b
    if e == 0:
        return F(0)
    m = ((m0 | 0x80) << 24) | (m1 << 16) | (m2 << 8) | m3
    v = F(m, 1 << 32) * F(2) ** (e - 128)
    return -v if m0 & 0x80 else v

def encode(x):
    """Plus proche nombre représentable (None si trop grand)."""
    x = F(x)
    if x == 0:
        return [0, 0, 0, 0, 0]
    s = 1 if x < 0 else 0
    x = abs(x)
    e = 0
    while x >= 1: x /= 2; e += 1
    while x < F(1, 2): x *= 2; e -= 1
    m = round(x * (1 << 32))
    if m == 1 << 32:
        m >>= 1; e += 1
    e += 128
    if e > 255: return None
    if e < 1: return [0, 0, 0, 0, 0]
    return [e, ((m >> 24) & 0x7F) | (s << 7), (m >> 16) & 255, (m >> 8) & 255, m & 255]

def ulp(x):
    """Taille d'une unité du dernier bit pour la grandeur de x."""
    x = abs(F(x))
    if x == 0: return F(0)
    e = 0
    while x >= 1: x /= 2; e += 1
    while x < F(1, 2): x *= 2; e -= 1
    return F(2) ** (e - 32)

def rnd_num(lo=96, hi=160):
    e = random.randint(lo, hi)
    return [e, random.randint(0, 255), random.randint(0, 255), random.randint(0, 255), random.randint(0, 255)]

fails = 0
def bad(msg):
    global fails
    fails += 1
    if fails <= 15: print('  ECHEC', msg)

def setnum(addr, b):
    mem[addr:addr + 5] = b

# --- opérations ------------------------------------------------------------
ops = [('+', ADD, lambda a, b: a + b), ('-', SUB, lambda a, b: a - b),
       ('*', MUL, lambda a, b: a * b), ('/', DIV, lambda a, b: a / b)]
worst = {}
for name, addr, f in ops:
    w = 0
    for i in range(N):
        if name in '*/':
            a, b = rnd_num(1, 255), rnd_num(1, 255)
        elif i % 10 == 0:            # nombres voisins : annulation
            a = rnd_num(); b = list(a); b[4] ^= random.randint(1, 255); b[1] ^= 0x80 if random.random() < .5 else 0
        else:
            a, b = rnd_num(), rnd_num()
        if i % 50 == 0: b = [0, 0, 0, 0, 0]
        setnum(0x280, a); setnum(0x288, b)
        call(addr)
        x, y = decode(a), decode(b)
        if name == '/' and y == 0:
            if mem[0x2FE] != 2: bad('%s : division par zéro non signalée' % name)
            continue
        exact = f(x, y)
        ref = encode(exact)
        if ref is None or (abs(exact) >= F(2) ** 126 and mem[0x2FE] == 1):
            if mem[0x2FE] != 1: bad('%s %s %s : dépassement non signalé' % (x, name, y))
            continue
        if mem[0x2FE]:
            bad('%s %s %s : erreur %d inattendue' % (float(x), name, float(y), mem[0x2FE])); continue
        got = decode(mem[0x290:0x295])
        if abs(exact) < F(2) ** -126:
            continue                 # sous-dépassement : zéro admis
        err = abs(got - exact) / ulp(exact) if exact else abs(got)
        w = max(w, err)
        if err > 1:
            bad('%s %s %s = %s, obtenu %s (%.2f ulp)' % (float(x), name, float(y), float(exact), float(got), err))
    worst[name] = w
print('opérations : erreur maximale en ulp', {k: round(float(v), 3) for k, v in worst.items()})

# --- comparaison -----------------------------------------------------------
for i in range(N):
    a = rnd_num(120, 136); b = list(a) if i % 3 == 0 else rnd_num(120, 136)
    if i % 7 == 0: b[1] ^= 0x80
    if i % 11 == 0: a = [0, 0, 0, 0, 0]
    setnum(0x280, a); setnum(0x288, b); call(CMP)
    x, y = decode(a), decode(b)
    exp = 0 if x == y else (1 if x > y else 0xFF)
    if mem[0x290] != exp: bad('cmp %s %s : %d au lieu de %d' % (x, y, mem[0x290], exp))
print('comparaison : vérifiée')

# --- entiers ---------------------------------------------------------------
for v in list(range(-40, 41)) + [32767, -32768, 255, 256, -256, 1000, -1000] + random.sample(range(-32768, 32768), N):
    mem[0x298] = v & 255; mem[0x299] = (v >> 8) & 255; call(ITOF)
    if decode(mem[0x290:0x295]) != v: bad('itof %d -> %s' % (v, decode(mem[0x290:0x295])))
def half_away(x):
    n = int(abs(x) + F(1, 2))
    return -n if x < 0 else n
for i in range(N):
    x = F(random.randint(-3300000, 3300000), random.choice([1, 2, 4, 10, 100, 7]))
    if i % 20 == 0: x = F(random.choice([32767, -32768, 32768, -32769, 32767.5, -32768.5, 0.5, -0.5, 1.5, -2.5]))
    b = encode(x); setnum(0x280, b); call(TOINT)
    xv = decode(b); r = half_away(xv)
    ok = -32768 <= r <= 32767
    got = mem[0x290] | mem[0x291] << 8
    if got >= 32768: got -= 65536
    if ok and (mem[0x292] or got != r): bad('toint %s -> %d (C=%d), attendu %d' % (float(xv), got, mem[0x292], r))
    if not ok and not mem[0x292]: bad('toint %s : dépassement non signalé' % float(xv))
    setnum(0x280, b); call(TRUNC)
    t = int(xv)
    if decode(mem[0x290:0x295]) != t: bad('trunc %s -> %s' % (float(xv), float(decode(mem[0x290:0x295]))))
    setnum(0x280, b); call(RND)
    if decode(mem[0x290:0x295]) != r: bad('rnd %s -> %s' % (float(xv), float(decode(mem[0x290:0x295]))))
print('conversions entières, partie entière, arrondi : vérifiés')

# --- lecture ---------------------------------------------------------------
def parse(txt):
    t = txt.encode() + b' '
    mem[0x400:0x400 + len(t)] = t
    call(PARSE)
    return mem[0x295], decode(mem[0x290:0x295]), mem[0x2FE]
cases = ['0', '1', '7', '10', '0.5', '3.14159', '32768', '100000', '0.1', '0.001', '123456789',
         '1234567891234', '1E5', '2.5E-3', '1E+2', '6.02E23', '1.6E-19', '00012.50', '1E', '3.5E-',
         '999999999', '0.000000123', '4294967295']
for i in range(N // 4):
    ip = str(random.randint(0, 10 ** random.randint(0, 12)))
    fp = str(random.randint(0, 10 ** random.randint(0, 6)))
    s = ip + ('.' + fp if random.random() < .7 else '')
    if random.random() < .3: s += 'E' + str(random.randint(-30, 30))
    cases.append(s)
w = wr = 0
for s in cases:
    n, got, err = parse(s)
    m = re.match(r'\d+(\.\d*)?(E[+-]?\d+)?', s)
    txt = m.group(0)
    exact = F(txt)
    if encode(exact) is None:
        if err != 1: bad('lecture %r : dépassement non signalé' % s)
        continue
    if err: bad('lecture %r : erreur %d' % (s, err)); continue
    if n != len(txt): bad('lecture %r : %d caractères lus au lieu de %d' % (s, n, len(txt)))
    if exact == 0:
        if got != 0: bad('lecture %r -> %s' % (s, float(got)))
        continue
    if abs(exact) < F(2) ** -126: continue
    sig = len(re.sub(r'E.*', '', txt).replace('.', '').strip('0'))
    e = abs(got - exact) / ulp(exact)
    rel = abs(got - exact) / abs(exact)
    mant = txt.split('E')[0]
    shift = (int(txt.split('E')[1]) if 'E' in txt else 0) - (len(mant.split('.')[1]) if '.' in mant else 0)
    if sig <= 9 and abs(shift) <= 9:     # une seule multiplication ou division
        w = max(w, e)
        if e > 1: bad('lecture %r -> %s (%.2f ulp)' % (s, float(got), e))
    else:
        wr = max(wr, rel)
        if rel > F(5, 10 ** 9): bad('lecture %r -> %s (écart relatif %.2e)' % (s, float(got), float(rel)))
print('lecture : %d nombres ; courts : %.3f ulp au plus, longs : écart relatif %.1e au plus'
      % (len(cases), w, float(wr)))

# --- affichage -------------------------------------------------------------
def show(b):
    setnum(0x280, b); call(PRINT)
    return bytes(mem[0x300:0x300 + mem[0x2FF]]).decode()
fixed = {0: '0', 1: '1', -1: '-1', 0.5: '0.5', 100: '100', 3.5: '3.5', 32768: '32768', -0.25: '-0.25',
         1e9: '1E9', 123456789: '123456789', 0.00001: '0.00001', 1e-6: '1E-6', 1e20: '1E20',
         1.5e-7: '1.5E-7', 40000: '40000', 1000000: '1000000', F(1, 3): '0.333333333',
         F(2, 3): '0.666666667', 18.5: '18.5', -16384: '-16384', 1e38: '1E38'}
for v, txt in fixed.items():
    got = show(encode(F(v)))
    if got != txt: bad('affichage de %s : %r au lieu de %r' % (v, got, txt))
pat = re.compile(r'^-?(\d+(\.\d+)?|0\.0*\d+|\d(\.\d+)?E-?\d+)$')
limites = []                         # 10^k et ses deux voisins représentables
for k in range(-38, 39):
    b = encode(F(10) ** k)
    if b is None or b[0] < 2: continue
    m = (b[1] & 0x7F) << 24 | b[2] << 16 | b[3] << 8 | b[4]
    for d in (-1, 0, 1):
        mm = m + d
        if 0 <= mm < 1 << 31:
            limites.append([b[0], mm >> 24, (mm >> 16) & 255, (mm >> 8) & 255, mm & 255])
for i in range(N + len(limites)):
    b = rnd_num(1, 255)
    if i % 3 == 0: b = encode(F(random.randint(-10 ** 9, 10 ** 9), 10 ** random.randint(0, 9)))
    if i >= N: b = limites[i - N]
    x = decode(b)
    txt = show(b)
    if not pat.match(txt): bad('affichage mal formé %r' % txt); continue
    if txt.endswith('0') and '.' in txt and 'E' not in txt: bad('zéro final %r' % txt)
    got = F(txt)
    if x == 0:
        if got != 0: bad('affichage de 0 : %r' % txt)
        continue
    digits = len(re.sub(r'E.*', '', txt).replace('-', '').replace('.', '').lstrip('0'))
    if digits > 9: bad('plus de 9 chiffres : %r' % txt)
    if abs(got - x) / abs(x) > F(1, 10 ** 8) * F(6, 10):    # 9 chiffres, dernier à 1 près
        bad('affichage de %r : %r' % (float(x), txt))
print('affichage : vérifié (%d nombres, dont %d autour des puissances de 10)' % (N + len(fixed) + len(limites), len(limites)))

# --- fonctions --------------------------------------------------------------
import math
def fun(addr, x):
    b = encode(F(x)); setnum(0x280, b); call(addr)
    return decode(b), decode(mem[0x290:0x295]), mem[0x2FE]
def rel_ulp(got, ref):
    return float(abs(F(got) - F(ref)) / ulp(F(ref))) if ref else float(abs(got))
fz = {}
def check(name, addr, f, xs, tol, absolute=False, grow=0):
    w = 0
    for x in xs:
        xv, got, err = fun(addr, x)
        if err: bad('%s(%r) : erreur %d' % (name, float(xv), err)); continue
        ref = f(float(xv))
        e = (abs(float(got) - ref) * 2 ** 32) if absolute else rel_ulp(got, ref)
        lim = tol + grow * abs(float(xv))   # radians et degrés : l'erreur de la
        w = max(w, e)                        # réduction croît avec l'argument
        if e > lim: bad('%s(%r) = %r, attendu %r (%.2f)' % (name, float(xv), float(got), ref, e))
    fz[name] = round(w, 2)
R = random.random
M = N // 2
check('RACINE', SQRT, math.sqrt, [R() * 10 ** random.randint(-30, 30) for i in range(M)] + [1, 2, 4, 9, 100, 0.25], 1.01)
check('EXP', EXP, math.exp, [(R() - .5) * 170 for i in range(M)] + [0, 1, -1, 0.5, 10], 3)
check('LN', LN, math.log, [R() * 10 ** random.randint(-30, 30) for i in range(M)] + [1, 2, 10, 0.5, math.e], 3)
check('SIN', SIN, math.sin, [(R() - .5) * 100 for i in range(M)] + [0, 1, -1, 3], 2, True, 1.5)
check('COS', COS, math.cos, [(R() - .5) * 100 for i in range(M)] + [0, 1, -1, 3], 2, True, 1.5)
check('ARCTAN', ATN, math.atan, [(R() - .5) * 10 ** random.randint(-3, 5) for i in range(M)] + [0, 1, -1, 0.2679, 1e10], 3)
check('SIN degres', SIND, lambda d: math.sin(math.radians(d)), [(R() - .5) * 1000 for i in range(M)], 2, True, 1 / 45)
check('ARCTAN degres', ATND, lambda x: math.degrees(math.atan(x)), [(R() - .5) * 100 for i in range(M)], 4)
print('fonctions : écart maximal (ulp ; SIN, COS : en 2^-32 absolu)', fz)
for name, addr, x, want in [('SIN', SIND, 30, F(1, 2)), ('SIN', SIND, 90, 1), ('SIN', SIND, 180, 0), ('COS', COSD, 90, 0),
                            ('COS', COSD, 0, 1), ('SIN', SIND, -90, -1), ('COS', COSD, 360, 1), ('ARCTAN', ATND, 1, 45)]:
    xv, got, err = fun(addr, x)
    if abs(got - want) > F(1, 10 ** 9) * max(1, abs(F(want))): bad('%s %s degrés = %r au lieu de %s' % (name, x, float(got), want))
for name, addr, x in [('RACINE', SQRT, -1), ('LN', LN, 0), ('LN', LN, -2)]:
    if fun(addr, x)[2] != 3: bad('%s(%s) : calcul impossible non signalé' % (name, x))
if fun(EXP, 100)[2] != 1: bad('EXP 100 : dépassement non signalé')
if fun(EXP, -100)[1] != 0: bad('EXP -100 : devrait donner 0')
print('valeurs remarquables et erreurs : vérifiées')

print('ECHECS : %d' % fails if fails else 'fp_inc.s : tout est conforme')
sys.exit(1 if fails else 0)
