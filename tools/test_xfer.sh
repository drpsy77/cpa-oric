#!/bin/sh
# XFER.COM et tools/xfer_server.py, de bout en bout dans Oricutron : le
# modem d'Oricutron (serial = 'modem', ACIA en $031C) se connecte en TCP
# au serveur lancé ici ; TERM compose le numéro, puis XFER transfère.
#   - E puis R d'un texte de cpa.dsk : identique dans les deux sens (^Z de
#     fin retirés sur le serveur) ;
#   - fichier de 40 Ko (plus de 255 blocs : numéros qui reviennent à 0)
#     vers B:, et retour : identique ;
#   - /T : LF, tabulation, accents (UTF-8) du serveur -> CR LF, espace,
#     ASCII sur l'Oric (Ç -> C, œ -> oe, « -> "), et retour en LF ;
#   - refus : fichier absent du serveur, fichier absent de CP/A, jokers,
#     fichier protégé (R/O) gardé tel quel ;
#   - ESC pendant une réception : annulé, ni NOM ni NOM.$$$ sur le disque ;
#   - erreurs simulées par le serveur (--fautes) à chaque transfert : bloc
#     abîmé (NAK, renvoyé), bloc répété (ignoré), bloc refusé, acquit perdu
#     (l'Oric renvoie le bloc au bout de 10 s).
#   tools/test_xfer.sh
set -e
cd "$(dirname "$0")/.."
R=$(pwd)
T=$(mktemp -d)
PORT=${PORT:-2399}
mkdir "$T/srv"
python3 - "$T/srv" <<'E'
import sys, random
d = sys.argv[1]
random.seed(7)
open(d + "/gros.bin", "wb").write(bytes(random.randrange(256) for _ in range(40000)))
open(d + "/mac.txt", "wb").write("ligne 1\n\tÇa : cœur, Lætitia, « élève »\nfin\n".encode())
E
python3 tools/xfer_server.py --port $PORT --dir "$T/srv" --once --fautes > "$T/srv.log" 2>&1 &
SRV=$!
sleep 1
K="term\n|atdt127.0.0.1:$PORT\n||\034q|"
K="${K}xfer e readme.txt\n||||||"
K="${K}xfer r copie.txt readme.txt\n||||||"
K="${K}xfer r b:gros.bin\n||||||||||||||||||||||||||||||||||||||||||||||||||"
K="${K}xfer e b:gros.bin retour.bin\n||||||||||||||||||||||||||||||||||||||||||||||||||"
K="${K}xfer r mac.txt /t\n|||"
K="${K}xfer e mac.txt mac2.txt /t\n|||"
K="${K}xfer r rien.txt\n||"
K="${K}xfer e rien.txt\n|"
K="${K}xfer e *.txt\n|"
K="${K}xfer r readme.txt\n||||"
K="${K}xfer r b:stop.bin gros.bin\n||\033||||"
K="${K}dir b:\n|"
KEYS=$(printf "$K")
DSK=build/cpa.dsk DSKB=build/cpa-projet.dsk ORIC_KEYS_AT=400 ORIC_WARP=1 \
  ORIC_CFG="serial = 'modem'" tools/run_test.sh "$KEYS" 60000 "$T/o" >/dev/null 2>&1 || true
kill $SRV 2>/dev/null || true
python3 tools/screen.py "$T/o.mem" > "$T/screen.txt" 2>/dev/null || true
rc=0
python3 - "$T" "$R" <<'E' || rc=1
import sys, subprocess
T, R = sys.argv[1], sys.argv[2]
def get(dsk, name):
    out = T + "/got"
    r = subprocess.run(["python3", R + "/tools/mkdisk.py", "get", dsk, name, out],
                       capture_output=True)
    return open(out, "rb").read() if r.returncode == 0 else None
def rd(f):
    try:
        return open(f, "rb").read()
    except OSError:
        return None
def strip(b):
    return b.rstrip(b"\x1a")
srv = T + "/srv/"
screen = open(T + "/screen.txt").read()
ko = 0
def check(ok, what):
    global ko
    print(("ok    : " if ok else "ECHEC : ") + what)
    ko += 0 if ok else 1
readme = get(R + "/build/cpa.dsk", "README.TXT")
check(rd(srv + "readme.txt") == strip(readme), "E : texte identique sur le serveur")
check(get(T + "/o.dsk", "COPIE.TXT") == readme, "R : texte identique sur l'Oric")
gros = rd(srv + "gros.bin")
g = get(T + "/o.b.dsk", "GROS.BIN")
check(g is not None and strip(g) == gros and len(g) % 128 == 0, "R : 40 Ko vers B:, identique")
check(rd(srv + "retour.bin") == gros, "E : 40 Ko depuis B:, identique")
check(get(T + "/o.dsk", "MAC.TXT") is not None and
      strip(get(T + "/o.dsk", "MAC.TXT")) == b'ligne 1\r\n Ca : coeur, Laetitia, " eleve "\r\nfin\r\n', "R /T : CR LF, espace, accents")
check(rd(srv + "mac2.txt") == b'ligne 1\n Ca : coeur, Laetitia, " eleve "\nfin\n', "E /T : LF")
check("Serveur : fichier absent" in screen, "R : absent du serveur")
check("Fichier absent" in screen, "E : absent de CP/A")
check("pas de jokers" in screen, "jokers refuses")
check("protege" in screen and get(T + "/o.dsk", "README.TXT") == readme, "R/O garde")
check("Annule (ESC)" in screen and get(T + "/o.b.dsk", "STOP.BIN") is None
      and get(T + "/o.b.dsk", "STOP.$$$") is None, "ESC : rien d'ecrit")
log = open(T + "/srv.log").read()
for f in ("bloc 3 abime", "bloc 4 repete", "bloc 2 refuse", "acquit du bloc 5 perdu"):
    check("faute : " + f in log, "erreur simulee : " + f)
if ko:
    print(screen)
    print(open(T + "/srv.log").read())
sys.exit(1 if ko else 0)
E
[ $rc = 0 ] && rm -rf "$T" || echo "garde : $T"
exit $rc
