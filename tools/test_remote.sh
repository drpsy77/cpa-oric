#!/bin/sh
# Console à distance de bout en bout dans Oricutron : pilote série du BIOS
# (src/serial.s), REMOTE.COM, démon tools/remote.py. Le modem d'Oricutron
# (serial = 'modem', ACIA en $031C) appelle le démon lancé ici (REMOTE
# ORIC, pris dans un fichier HOSTS mis sur la disquette) ; le test tape par
# le démon (interface HTTP du § 9.1), puis compare l'écran tenu par le
# démon au vidage mémoire de la fin de l'essai (même lecture que
# tools/screen.py, case du curseur rétablie).
#   - DIR, puis un menu FUNCT ouvert ;
#   - EDIT : un texte de 2 Ko collé (/coller), enregistré (^S), quitté
#     (^Q), puis relu par TYPE ; le fichier de la disquette est le texte ;
#   - CMDER plein écran ;
#   - GRAPHER en SPLIT (seules les lignes de texte, 16 à 27, comptent) ;
#   - GRAPHER en LORES avec deux sprites (caractères redéfinis) : la police
#     tenue par le démon est celle du vidage ($B400-$BB7F, caractères
#     32-127 et 32-111 du jeu secondaire), sprites compris ;
#   - $FD "B" (démarrage à chaud) depuis CMDER : la console reste active
#     (voyant R), DIR tapé ensuite par le démon ;
#   - démon tué au milieu d'une réponse : l'Oric continue (DIR tapé sur son
#     clavier), puis REMOTE rappelle un nouveau démon ;
#   - TERM et XFER refusent de partir pendant la console ; REMOTE OFF.
# En temps réel (pas d'ORIC_WARP) : ~6 min.
#   tools/test_remote.sh [scenario...]
set -e
cd "$(dirname "$0")/.."
R=$(pwd)
T=$(mktemp -d)
PORT=${PORT:-2398}
HTTP=${HTTP:-8098}
cp build/cpa.dsk "$T/a.dsk"
printf 'oric 127.0.0.1:%s\n' $PORT > "$T/hosts"
printf 'SPLIT\nCIRCLE 120 64 40\nLINE 0 0 239 127\n' > "$T/rond.grx"
python3 tools/mkdisk.py era "$T/a.dsk" HOSTS > /dev/null
python3 tools/mkdisk.py put "$T/a.dsk" "$T/hosts" HOSTS > /dev/null
python3 tools/mkdisk.py put "$T/a.dsk" "$T/rond.grx" ROND.GRX > /dev/null
cat > "$T/sprfix.grx" <<'G'
DIM S$(112) T(16)
BLOAD S$ HEROS.SPR
FOR I 0 15
  T(I) = 112+I
NEXT
LORES
FOR L 1 27
  CHAR 0 L 2+(L%2)
  LOCATE 2 L
  ECHO ":. . . . :. . . . :. . . . :"
NEXT
SPRITES 2
SPOOL T
SSHOW 0 S$ 0 10 12
SSHOW 1 S$ 2 20 5
WHILE 1
  K = INKEY
  IF K > 0
    END
  ENDIF
NEXT
G
python3 tools/mkdisk.py put "$T/a.dsk" "$T/sprfix.grx" SPRFIX.GRX > /dev/null
python3 tools/mkdisk.py put "$T/a.dsk" files/heros.spr HEROS.SPR > /dev/null
rc=0
python3 - "$T" "$R" "$PORT" "$HTTP" "$@" <<'E' || rc=1
import json, os, subprocess, sys, time, urllib.request
T, R, PORT, HTTP = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
choix = sys.argv[5:]
sys.path.insert(0, R + "/tools")
import oric_ecran as oe
URL = "http://localhost:%d" % HTTP
ko = 0

def check(ok, what):
    global ko
    print(("ok    : " if ok else "ECHEC : ") + what, flush=True)
    ko += 0 if ok else 1
    return ok

def demon():
    log = open(T + "/demon.log", "a")
    p = subprocess.Popen(["python3", R + "/tools/remote.py", "serve", "--port", PORT,
                          "--http", str(HTTP)], stdout=log, stderr=log)
    for _ in range(50):
        try:
            etat()
            return p
        except OSError:
            time.sleep(0.1)
    return p

def http(chemin, corps=None):
    req = urllib.request.Request(URL + chemin, data=corps,
                                 method="POST" if corps is not None else "GET")
    with urllib.request.urlopen(req, timeout=10) as r:
        return r.read()

def etat():
    return json.loads(http("/ecran?depuis=0"))

def texte(e=None):
    e = e or etat()
    return "\n".join("".join(chr(c & 0x7F) if 32 <= (c & 0x7F) < 127 else "."
                             for c in bytes.fromhex(e["lignes"][str(n)])) for n in range(28))

def touches(s):
    http("/touches", bytes(s, "latin-1") if isinstance(s, str) else bytes(s))

def attendre(cible, delai=30):
    fin = time.time() + delai
    while time.time() < fin:
        try:
            e = etat()
            if (cible(e) if callable(cible) else cible in texte(e)):
                return True
        except OSError:
            pass
        time.sleep(0.2)
    return False

def actif(delai=40):
    return attendre(lambda e: e["liaison"] == "active", delai)

def essai(nom, cles, trames, etapes, split=False, disque=None, comparer=True, police=False):
    """Lance Oricutron (frappe locale cles), joue etapes() par le démon, puis
    compare l'écran du démon au vidage de la trame trames."""
    if choix and nom not in choix:
        return
    print("== " + nom, flush=True)
    d = demon()
    env = dict(os.environ, DSK=disque or T + "/a.dsk", ORIC_KEYS_AT="400",
               ORIC_CFG="serial = 'modem'")
    env.pop("ORIC_WARP", None)
    o = subprocess.Popen(["sh", R + "/tools/run_test.sh", cles, str(trames), T + "/" + nom],
                         env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    t0 = time.time()
    try:
        d = etapes(d) or d
    except Exception as ex:          # l'essai continue : la comparaison dira
        check(False, "%s : etapes (%r)" % (nom, ex))
    o.wait()
    print("   (%d s)" % (time.time() - t0), flush=True)
    mem = open(T + "/" + nom + ".mem", "rb").read()
    v = oe.ecran_depuis_vidage(mem)
    e = etat()
    if not comparer:
        d.terminate()
        d.wait()
        return mem, e
    lignes = range(16, 28) if split else range(28)
    diff = [n for n in lignes if bytes.fromhex(e["lignes"][str(n)]) != v["lignes"][n]]
    ok = check(not diff, "%s : ecran du demon == vidage%s" % (nom, " (lignes 16-27)" if split else ""))
    ok &= check(e["curseur"][:2] == v["curseur"][:2] and (e["mode"] & 0x7F) == (v["mode"] & 0x7F),
                "%s : curseur %s et mode %d (vidage %s, %d)" % (nom, e["curseur"][:2], e["mode"],
                                                              v["curseur"][:2], v["mode"]))
    if police:                       # caractères 32-127, et 32-111 du secondaire
        utiles = [k for k in range(48) if 6 <= k <= 25 or k >= 32]
        manque = [k for k in utiles if str(k) not in e.get("police", {})]
        diff = [k for k in utiles if str(k) in e.get("police", {}) and
                bytes.fromhex(e["police"][str(k)]) != mem[0xB400 + 40 * k:0xB428 + 40 * k]]
        ok &= check(not manque and not diff, "%s : police du demon == vidage (manque %s, diff %s)"
                    % (nom, manque, diff))
        cpa = oe.charger_police()
        redef = [c for c in range(112, 128) if list(mem[0xB400 + 8 * c:0xB408 + 8 * c]) != cpa[c]]
        ok &= check(len(redef) >= 2, "%s : caracteres des sprites redefinis (%d)" % (nom, len(redef)))
    if not ok:
        print(texte(e))
        os.system("python3 %s/tools/screen.py %s/%s.mem" % (R, T, nom))
    d.terminate()
    d.wait()
    return mem, e

N = "\r"
CLES = "remote oric\n"

# 1. DIR, puis le menu Systeme (FUNCT) ouvert
def e1(d):
    actif()
    touches("dir" + N)
    check(attendre("K free"), "dir : affiche par le demon")
    touches([0x80])
    time.sleep(1)
    touches([9])            # menu suivant (Fichiers)
    time.sleep(2)
r = essai("dir_menu", CLES, 1700, e1)
if r:
    check(r[0][0xBB80 + 36] == ord("R"), "voyant R")

# 2. EDIT : 2 Ko colles, enregistres, relus par TYPE
lignes = ["%02d Le renard brun saute, oui." % i for i in range(70)]
txt = "\n".join(lignes) + "\n"
def e2(d):
    actif()
    touches("edit essai.txt" + N)
    time.sleep(4)
    t = time.time()
    http("/coller", txt.encode())
    check(attendre(lignes[-1][:20], 120), "edit : texte colle visible (%d s)" % (time.time() - t))
    time.sleep(1)
    touches([19])           # ^S
    time.sleep(4)
    touches([17])           # ^Q
    check(attendre("A>", 20), "edit : retour au prompt")
    touches("type essai.txt" + N)
    fin = time.time() + 90             # pages : une espace à chaque pause
    while time.time() < fin and lignes[-1] not in texte():
        if "Suite" in texte():
            touches(" ")
        time.sleep(1)
    check(lignes[-1] in texte(), "type : derniere ligne")
    time.sleep(2)
r = essai("edit", CLES, 4500, e2)
if r:
    out = T + "/essai.txt"
    subprocess.run(["python3", R + "/tools/mkdisk.py", "get", T + "/edit.dsk", "ESSAI.TXT", out],
                   capture_output=True)
    lu = open(out, "rb").read().rstrip(b"\x1a") if os.path.exists(out) else b""
    check(lu.replace(b"\r\n", b"\n") == txt.encode(), "edit : fichier == texte colle (%d octets)" % len(lu))

# 3. CMDER
def e3(d):
    actif()
    touches("cmder" + N)
    time.sleep(8)
essai("cmder", CLES, 1700, e3)

# 4. GRAPHER en SPLIT, puis DIR dans les lignes de texte
def e4(d):
    actif()
    touches("grapher rond" + N)
    check(attendre(lambda e: e["mode"] & 0x7F == 1, 30), "split : mode 1 vu par le demon")
    time.sleep(3)
    touches("dir" + N)
    check(attendre("ROND", 20), "split : dir")
    time.sleep(2)
essai("split", CLES, 1900, e4, split=True)

# 4b. GRAPHER en LORES, deux sprites : caracteres redefinis transmis
def e4b(d):
    actif()
    check(attendre(lambda e: len(e.get("police", {})) == 48, 30), "sprites : police lue au debut")
    touches("grapher sprfix" + N)
    check(attendre(lambda e: e["mode"] & 0x80 and ":. . ." in texte(e), 40), "sprites : decor")
    time.sleep(8)
essai("sprites", CLES, 2600, e4b, police=True)

# 5. $FD "B" pendant CMDER : demarrage a chaud, console toujours active
def e5(d):
    actif()
    touches("cmder" + N)
    time.sleep(8)
    http("/reset", b"")
    check(attendre(lambda e: "A>" in texte(e) and "CMDER" not in texte(e).split("\n")[0], 20),
          "reset : prompt")
    time.sleep(2)
    touches("ver" + N)
    check(attendre("CP/A 0.9", 20), "reset : console active ensuite (VER)")
    time.sleep(2)
r = essai("reset", CLES, 2100, e5)
if r:
    check(r[0][0xBB80 + 36] == ord("R"), "reset : voyant R")

# 6. demon tue au milieu d'une reponse ; DIR tape sur l'Oric ; nouvel appel
def e6(d):
    actif()
    touches("help" + N)
    time.sleep(0.6)
    d.kill()
    d.wait()
    time.sleep(2)
    d = demon()
    check(attendre(lambda e: e["liaison"] == "active", 60), "tue : nouvel appel accepte")
    check(attendre("K free", 20), "tue : DIR tape sur l'Oric vu")
    time.sleep(3)
    return d
essai("tue", CLES + "|" * 6 + "dir\n|remote oric\n", 2800, e6)

# 8. rappel : démon tué puis relancé ; l'Oric rappelle seul (10 s de silence)
def e8(d):
    actif()
    touches("dir" + N)
    attendre("K free", 20)
    d.kill()
    d.wait()
    time.sleep(3)
    d = demon()
    t = time.time()
    check(attendre(lambda e: e["liaison"] == "active", 60),
          "rappel : l'Oric rappelle seul (%d s)" % (time.time() - t))
    time.sleep(2)
    touches("ver" + N)
    check(attendre("CP/A 0.9", 20), "rappel : console reprise (VER)")
    time.sleep(3)
    return d
r = essai("rappel", CLES, 3000, e8)
if r:
    check(r[0][0xBB80 + 36] == ord("R"), "rappel : voyant R")

# 9. touche tapée sur le clavier de l'Oric : vue par le démon (humain), qui
#    refuse alors les touches de la vitrine (409)
def e9(d):
    actif()
    check(attendre(lambda e: e.get("humain") is not None and e["humain"] < 3, 40),
          "clavier : touche de l'Oric vue par le demon")
    req = urllib.request.Request(URL + "/touches", data=b"x", method="POST",
                                 headers={"X-Vitrine": "30"})
    try:
        urllib.request.urlopen(req, timeout=10)
        code = 204
    except urllib.error.HTTPError as err:
        code = err.code
    check(code == 409, "clavier : touche de la vitrine refusee (%d)" % code)
    time.sleep(3)
essai("clavier", CLES + "|" * 5 + "ver\n", 1700, e9)

# 10. REMOTE OFF tapé sur l'Oric pendant un rappel (démon tué, rappel parti
#     10 s plus tard, REMOTE OFF vers 46 s) : il s'arrête
def e10(d):
    actif()
    d.kill()
    d.wait()
    time.sleep(55)
    d = demon()                      # l'Oric ne doit plus appeler
    time.sleep(15)
    check(etat()["liaison"] == "attente", "rappel_off : plus d'appel apres REMOTE OFF")
    return d
r = essai("rappel_off", CLES + "|" * 12 + "remote off\n", 4100, e10, comparer=False)
if r:
    t = subprocess.run(["python3", R + "/tools/screen.py", T + "/rappel_off.mem"],
                       capture_output=True, text=True).stdout
    check("Console a distance coupee" in t and r[0][0xBB80 + 36] == ord(" "),
          "rappel_off : console coupee, voyant eteint")

# 7. refus de TERM et XFER pendant la console ; REMOTE ; REMOTE OFF
def e7(d):
    actif()
    touches("term" + N)
    check(attendre("REMOTE OFF", 10), "TERM refuse")
    touches("xfer r a.txt" + N)
    time.sleep(3)
    touches("remote" + N)
    check(attendre("Port : Oricutron", 10), "REMOTE : etat")
    time.sleep(2)
    touches("remote off" + N)
    time.sleep(8)
r = essai("off", CLES, 1900, e7, comparer=False)
if r:
    t = subprocess.run(["python3", R + "/tools/screen.py", T + "/off.mem"],
                       capture_output=True, text=True).stdout
    check(t.count("Console a distance : REMOTE OFF") == 2, "TERM et XFER refuses")
    check("Console a distance coupee" in t and r[0][0xBB80 + 36] == ord(" "), "REMOTE OFF")

sys.exit(1 if ko else 0)
E
[ $rc = 0 ] && rm -rf "$T" || echo "garde : $T"
exit $rc
