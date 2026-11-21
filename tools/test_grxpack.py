#!/usr/bin/env python3
"""Non-régression de GRXPACK.COM (compacteur de .GRX), sans émulateur
(6502 simulé de tools/run_com.py). Pour chaque programme de
tools/grapher_tests, chaque exemple livré (files/*.grx, files/en/*.grx) et
ceux de la vitrine :
  1. GRXPACK.COM écrit le même fichier que tools/grxpack.py, octet par octet,
     et annonce les mêmes nombres de lignes et d'octets ;
  2. « GRXPACK NOM /L n » rend la bonne ligne de la source (première, milieu,
     dernière) ;
  3. le programme compact se comporte comme l'original :
     - traduit par GRXASM puis assemblé par xa, il donne le même .COM, octet
       par octet (mêmes messages de traduction, au numéro de ligne près),
       que la source sans ce qui suit le guillemet fermant d'un ECHO (GRXASM
       recopie ce texte dans le .COM, qui ne l'affiche jamais) ;
     - interprété par GRAPHER (tools/grapher_tests seulement), il affiche ce
       qu'attend le fichier .ref, au numéro de ligne près.
Avant eux, « cas » : les règles une à une (lignes et résultat attendu), puis
des fichiers aux limites (fins de ligne CR, LF, mêlées ou absentes, ^Z, octet
0, tabulations, fichier vide, enregistrement plein, ligne de 255 caractères,
ligne trop longue), sans GRAPHER ni GRXASM.
  tools/test_grxpack.py [NOM...]   (défaut : tous ; « cas » : les cas seuls)
  tools/test_grxpack.py --py ...   sans GRXPACK.COM : la référence Python seule
                                   (étapes 3 seulement)
  LANGUE=en tools/test_grxpack.py  programmes et bibliothèques anglais
                                   (build/progs-en, build/src-en), sans la
                                   comparaison aux .ref (messages français)"""
import glob, os, re, shutil, subprocess, sys, tempfile

R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(R, 'tools'))
import grxpack

RUN = os.path.join(R, 'tools', 'run_com.py')
XA = os.environ.get('XA', os.path.join(R, 'tools', 'xa'))
EN = os.environ.get('LANGUE') == 'en'
P = os.path.join(R, 'build', 'progs-en' if EN else 'progs')
S = os.path.join(R, 'build', 'src-en' if EN else 'src')
D = os.path.join(R, 'tools', 'grapher_tests')


# les règles : ligne de la source, ligne compacte (None : elle disparaît)
CAS = [
    (b'', None), (b'   ', None), (b'; c', None), (b'   ; c', None),
    (b'  PLOT  10   20  ; point', b'PLOT 10 20'),
    (b'X = A + B ; somme', b'X=A+B'),
    (b'N1 = N1 + 1', b'N1=N1+1'),
    (b'X = 5 ;', b'X=5'),
    (b'LET X = A + B', b'LET X=A+B'),
    (b'IF A = 1 & B < 2', b'IF A=1&B<2'),
    (b'IF -A', b'IF -A'),
    (b'if  a$ = "oui"', b'if a$= "oui"'),
    (b'WHILE (X < 10)', b'WHILE (X<10)'),
    (b'LINE X 0 (239 - X) 199', b'LINE X 0 (239-X) 199'),
    (b'PLOT X -5', b'PLOT X -5'),
    (b'PLOT ( X ) ( Y )', b'PLOT (X) (Y)'),
    (b'FOR I 0 (N - 1)', b'FOR I 0 (N-1)'),
    (b'DIM A( 10 ) B$(4, 5)', b'DIM A(10) B$(4,5)'),
    (b'SSHOW 1 S$ 2 (X + 1) Y ALT', b'SSHOW 1 S$ 2 (X+1) Y ALT'),
    (b'T$(X + J, Y + I) = 126', b'T$(X+J,Y+I)=126'),
    (b'M$(I + 1) = "a"', b'M$(I+1)= "a"'),
    (b'A$ = "x  y" ; c', b'A$= "x  y"'),
    (b'CALL  DESSIN', b'CALL DESSIN'),
    (b'print  x', b'print x'),
    (b'PRINT', b'PRINT'), (b'PRINT ;', b'PRINT ;'),
    (b'PRINT "V= " V', b'PRINT "V= " V'),
    (b'PRINT A - B " points"', b'PRINT A-B " points"'),
    (b'PRINT A " " B', b'PRINT A " " B'),
    (b'PRINT "Total : " ;', b'PRINT "Total : " ;'),
    (b'PRINT X ;; reste', b'PRINT X ;'),
    (b'PRINT X ;  ', b'PRINT X ;'),
    (b'PRINT X ; commentaire', b'PRINT X'),
    (b'PRINT "a;b" ; c', b'PRINT "a;b"'),
    (b'PRINT LEN( "a b" ) + 1', b'PRINT LEN( "a b" )+1'),
    (b'PRINTV  X + 1 ;', b'PRINTV X+1 ;'),
    (b'ECHO', b'ECHO'), (b'ECHO   ', b'ECHO'),
    (b'ECHO  Il dit "oui" ; non  ', b'ECHO Il dit "oui" ; non  '),
    (b'ECHO "a  b" ; c', b'ECHO "a  b"'),
    (b'ECHO "', b'ECHO "'),
    (b'echov  x ; y', b'echov x ; y'),
    (b'GTEXT  2 90 Score ; 10 ', b'GTEXT 2 90 Score ; 10 '),
    (b'ECHOS  x ; y', b'ECHOS x'),
    (b'ABCDEFGHIJ  1   2', b'ABCDEFGHIJ 1 2'),
    (b'(  1 + 2 )  3', b'(1+2) 3'),
    (b'PLOT 1 2 "a ; b', b'PLOT 1 2 "a ; b'),
    (b'PLOT 1 2 ))  ( 3 )', b'PLOT 1 2 )) (3)'),
]


def run(d, prog, args, env=None):
    e = dict(os.environ)
    e.update(env or {})
    r = subprocess.run([sys.executable, RUN, d, prog] + args, cwd=d, env=e,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    t = r.stdout.decode('latin-1')
    return ''.join(l for l in t.splitlines(True)
                   if not re.match(r'\[[0-9]* instructions\]', l))


def source(f):
    """Comme test_grapher.sh : fins de ligne CR LF."""
    l = open(f, 'rb').read().replace(b'\r', b'').split(b'\n')
    return b'\r\n'.join(l[:-1]) + (b'\r\n' if len(l) > 1 else b'') + (l[-1] + b'\r' if l[-1] else b'')


def sans_reste(data):
    """La source, sans ce qui suit le guillemet fermant d'un ECHO ou d'un
    ECHOV : jamais affiché, mais recopié par GRXASM dans le .COM."""
    r = bytearray()
    change = False
    for t, fin in grxpack.lignes(data):
        s = t.lstrip(b' ')
        j = 0
        while j < len(s) and grxpack.lettre(s[j]):
            j += 1
        if s[:j].upper() in grxpack.TEXTE:
            k = j
            while k < len(s) and s[k] == 32:
                k += 1
            e = s.find(b'"', k + 1) if k < len(s) and s[k] == 34 else -1
            if 0 <= e < len(s) - 1:
                t = t[:len(t) - len(s) + e + 1]
                change = True
        r += t + fin
    return bytes(r) if change else data


def renumerote(t, nums):
    """Numéros de ligne des messages (« L n ») ramenés à ceux de la source."""
    def f(m):
        n = int(m.group(1))
        return 'L %d ' % nums[n - 1] if 1 <= n <= len(nums) else m.group(0)
    return re.sub(r'(?m)^L (\d+) ', f, t)


def pack_com(K, N, data):
    """GRXPACK N ZZPACK dans K -> (fichier écrit ou None, sortie)."""
    for g in glob.glob(K + '/*.GRX') + glob.glob(K + '/*.$$$'):
        os.remove(g)
    open(os.path.join(K, N + '.GRX'), 'wb').write(data)
    out = run(K, 'GRXPACK.COM', [N, 'ZZPACK'])
    try:
        return open(os.path.join(K, 'ZZPACK.GRX'), 'rb').read(), out
    except OSError:
        return None, out


def verifie(got, out, data):
    """Fichier écrit et bilan comparés à la référence -> erreurs."""
    err = []
    ref, nums, lues = grxpack.compacte(data)
    if got is None:
        return ['pas de fichier ecrit : ' + out.strip()]
    z = got.find(b'\x1a')
    if (got if z < 0 else got[:z]) != ref:
        err.append('fichier different de grxpack.py')
    if len(got) % 128 or (z >= 0 and got[z:].strip(b'\x1a')) or len(got) - len(ref) >= 128:
        err.append('fin de fichier (^Z)')
    m = re.findall(r'(\d+) \S+, (\d+) \S+', out)
    want = [(str(lues), str(len(grxpack.texte(data)))), (str(len(nums)), str(len(ref)))]
    if m != want:
        err.append('bilan %s, attendu %s' % (m, want))
    return err


def cas(K, py):
    ko = 0
    for s, want in CAS:
        got = grxpack.ligne(s)
        if got != want:
            ko += 1
            print('DIFFERENT : regle %r : %r, attendu %r' % (s, got, want))
    if py:
        return ko
    l = [s for s, _ in CAS]
    plein = b'ECHO ' + b'x' * 121 + b'\r\n'
    fichiers = [
        ('regles', b''.join(x + b'\r\n' for x in l)),
        ('lf', b''.join(x + b'\n' for x in l)),
        ('cr', b''.join(x + b'\r' for x in l)),
        ('melees', b''.join(x + (b'\r\n', b'\n', b'\r')[i % 3] for i, x in enumerate(l))),
        ('sans fin', b'X = 1\r\nPLOT 1  2'),
        ('^Z', b'X = 1\r\n\x1aPLOT 1 2\r\n'),
        ('octet 0', b'X = 1\r\nPL\x00OT 1 2\r\n'),
        ('tabulations', b'\tX\t=\t1\t; c\r\nECHO a\tb\r\n'),
        ('vide', b''),
        ('commentaires seuls', b'; a\r\n\r\n  ; b\r\n'),
        ('255 caracteres', b'ECHO ' + b'x' * 250 + b'\r\n'),
        ('255 caracteres, parametres', b'PLOT ' + b'1  ' * 83 + b'2\r\n'),
        ('255 caracteres, calcul', b'X = ' + b'( 1 + ' * 41 + b'1 ;;;\r\n'),
        ('255 caracteres, espaces', b' ' * 250 + b'X = 1\r\n' + b' ' * 255 + b'\r\n'),
        ('enregistrement plein', plein),
        ('deux enregistrements pleins', plein * 2),
        ('long', b''.join(x + b'\r\n' for x in l) * 12),
    ]
    for nom, data in fichiers:
        got, out = pack_com(K, 'CAS', data)
        err = verifie(got, out, data)
        if err:
            ko += 1
            print('DIFFERENT : fichier %s : %s' % (nom, ' ; '.join(err)))
    # ligne de plus de 255 caractères : son numéro, rien d'écrit
    got, out = pack_com(K, 'CAS', b'X = 1\r\n; c\r\nECHO ' + b'x' * 251 + b'\r\nY = 2\r\n')
    if got is not None or glob.glob(K + '/ZZPACK.*') or not re.search(r' 3\s*$', out):
        ko += 1
        print('DIFFERENT : ligne trop longue : ' + out.strip())
    for a in ([], ['CAS'], ['CAS', 'CAS'], ['CAS', '/L'], ['CAS', '/L', '0'], ['ABSENT', 'ZZPACK']):
        out = run(K, 'GRXPACK.COM', a)
        if glob.glob(K + '/ZZPACK.*') or re.search(r'\d+ \S+, \d+', out) or not out.strip():
            ko += 1
            print('DIFFERENT : GRXPACK %s : %s' % (' '.join(a), out.strip()))
    print('%s : cas' % ('identique' if not ko else 'DIFFERENT'))
    return ko


def main():
    args = sys.argv[1:]
    py = '--py' in args
    noms = [a for a in args if a != '--py']
    T = tempfile.mkdtemp()
    A, B, K = (os.path.join(T, x) for x in 'abk')
    for d in (A, B):
        os.mkdir(d)
        for f in ('GRAPHER.COM', 'GRXASM.COM'):
            shutil.copy(os.path.join(P, f), d)
        for f in (glob.glob(S + '/*.INC') + glob.glob(D + '/*.TXT') + glob.glob(D + '/*.SPR')
                  + glob.glob(R + '/files/anim/*.ANI') + glob.glob(R + '/files/anim/*.HIZ')):
            shutil.copy(f, d)
        for f in glob.glob(R + '/files/*.spr'):
            shutil.copy(f, os.path.join(d, os.path.basename(f).upper()))
    os.mkdir(K)
    if not py:
        shutil.copy(os.path.join(P, 'GRXPACK.COM'), K)
    # (fichier, GRAPHER ?, GRXASM ?)
    liste = [(f, True, True) for f in sorted(glob.glob(D + '/*.grx'))]
    liste += [(f, False, True) for f in sorted(glob.glob(R + '/files/*.grx') + glob.glob(R + '/files/*.GRX')
                                                + glob.glob(R + '/tools/vitrine/*.grx'))]
    liste += [(f, False, False) for f in sorted(glob.glob(R + '/files/en/*.grx') + glob.glob(R + '/files/en/*.GRX'))]
    ko = 0
    faits = 0
    if not noms or 'cas' in noms:
        ko += cas(K, py)
    for f, interp, trad in liste:
        n = os.path.splitext(os.path.basename(f))[0]
        if noms and n not in noms:
            continue
        faits += 1
        N = n.upper()
        err = []
        data = source(f)
        ref, nums, lues = grxpack.compacte(data)
        open(os.path.join(A, N + '.GRX'), 'wb').write(sans_reste(data))
        if py:
            open(os.path.join(B, N + '.GRX'), 'wb').write(ref)
        else:
            got, out = pack_com(K, N, data)
            err += verifie(got, out, data)
            if got is not None:
                open(os.path.join(B, N + '.GRX'), 'wb').write(got)
                for k in sorted(set([1, (len(nums) + 1) // 2, len(nums)])):
                    if k < 1:
                        continue
                    o = run(K, 'GRXPACK.COM', [N, '/L', str(k)])
                    m = re.search(r'(\d+) \D+ (\d+)', o)
                    t = grxpack.lignes(data)[nums[k - 1] - 1][0].decode('latin-1')
                    if not m or (int(m.group(1)), int(m.group(2))) != (k, nums[k - 1]) \
                            or t.strip() not in o:
                        err.append('/L %d : %s' % (k, o.strip()))
                o = run(K, 'GRXPACK.COM', [N, '/L', str(len(nums) + 1)])
                if re.search(r'\d+ \D+ \d+', o):
                    err.append('/L au-dela de la fin : ' + o.strip())
        if interp and not EN:
            ev = {}
            e = os.path.join(D, n + '.env')
            if os.path.exists(e):
                for w in open(e).read().split():
                    k, _, v = w.partition('=')
                    ev[k] = v
            i = os.path.join(D, n + '.in')
            ev['INPUT'] = open(i).read().rstrip('\n') if os.path.exists(i) else ''
            ev['SCREEN'] = '1' if n.startswith('lo') else ''
            o = renumerote(run(B, 'GRAPHER.COM', [N], ev), nums)
            if o != open(os.path.join(D, n + '.ref'), encoding='latin-1').read():
                err.append('GRAPHER : sortie differente de %s.ref' % n)
                open(os.path.join(T, n + '.out'), 'w', encoding='latin-1').write(o)
        if trad:
            com = []
            msg = []
            for d in (A, B):
                for x in ('.ASM', '.COM'):
                    if os.path.exists(os.path.join(d, N + x)):
                        os.remove(os.path.join(d, N + x))
                msg.append(run(d, 'GRXASM.COM', [N]))
                a = os.path.join(d, N + '.ASM')
                c = None
                if os.path.exists(a):
                    s = os.path.join(d, n + '.s')
                    open(s, 'wb').write(open(a, 'rb').read().replace(b'\x1a', b''))
                    r = subprocess.run([XA, '-o', N + '.COM', n + '.s'], cwd=d,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                    if r.returncode == 0:
                        c = open(os.path.join(d, N + '.COM'), 'rb').read()
                    else:
                        c = b'xa : ' + r.stdout
                com.append(c)
            if renumerote(msg[1], nums) != msg[0]:
                err.append('GRXASM : messages differents')
            if com[0] != com[1]:
                err.append('GRXASM : .COM different')
        if err:
            ko += 1
            print('DIFFERENT : %s : %s' % (n, ' ; '.join(err)))
        else:
            print('identique : %s (%d -> %d octets)' % (n, len(data), len(ref)))
    print('GRXPACK : %d programme(s), %d différence(s)%s' % (faits, ko, '' if not ko else ' (' + T + ')'))
    if not ko:
        shutil.rmtree(T)
    sys.exit(1 if ko else 0)


if __name__ == '__main__':
    main()
