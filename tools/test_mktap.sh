#!/bin/sh
# MKTAP.COM contre tools/mktap.py, puis chargement sous BASIC 1.1.
#  1. MKTAP.COM est lancé dans le 6502 simulé (tools/run_com.py) sur
#     plusieurs cas ; le .TAP écrit, sans les ^Z qui complètent son dernier
#     enregistrement (ce que fait EXPORT), doit être celui de mktap.py.
#     Programmes BASIC en texte (.BAS) : mêmes comparaisons, refus des
#     deux côtés pour les .BAS fautifs ; le codage lui-même est comparé à
#     la ROM par tools/test_bas.py.
#  2. Si l'Oricutron de test et la ROM BASIC 1.1 sont là : un .TAP à deux
#     blocs avec /R (chargeur BASIC) est chargé par CLOAD"" ; le code doit
#     avoir écrit « MKTAP OK », les données être en place, et le BASIC
#     chargé rester modifiable (LIST, nouvelle ligne).
#   tools/test_mktap.sh
set -e
cd "$(dirname "$0")/.."
R=$(pwd)
XA=${XA:-tools/xa}
T=$(mktemp -d)
cat > "$T/test.s" <<'E'
        *= $9000
        ldx #0
l       lda msg,x
        beq e
        sta $BB80+40*20+2,x
        inx
        bne l
e       rts
msg     .asc "MKTAP OK",0
E
$XA -o "$T/TEST.COM" "$T/test.s"
(cd progs && ../$XA -I msg/fr -o "$T/MKTAP.COM" mktap.s)
python3 - "$T" <<'E'
import sys
d = sys.argv[1]
open(d + "/DATA.BIN", "wb").write(bytes((i * 7) & 255 for i in range(300)))
open(d + "/ZFIN.BIN", "wb").write(bytes(range(20)) + b"\x1a\x1a\x1a")   # ^Z utiles
open(d + "/GROS.BIN", "wb").write(bytes((i * 13) & 255 for i in range(8000)))
# .BAS : enregistrements de 128 octets complétés par des ^Z, comme EDIT
def bas(nom, texte):
    if len(texte) % 128:
        texte += b"\x1a" * (128 - len(texte) % 128)
    open(d + "/" + nom, "wb").write(texte)
bas("PROG.BAS", b"10 REM essai de MKTAP\r\n"
    b"20 print \"Bonjour\";a$:data abc,\"x:y\",z:goto 20\r\n"
    b"\r\n   30 IFA>1THENPRINTSCORE ELSE?TAB(3)\r\n"
    b"40\r\n1 0 0 for i=1to 9:?i;:next\r\n"
    b"110 REM " + b"X" * 80 + b"\r\n"      # plus de 78 : avertissement
    b"120 a=\x07peek(1)\r\n")               # contrôle retiré
bas("LF.BAS", b"5 CLS\n10 PRINT\"FIN\"")   # LF seuls, sans fin de ligne
# un gros programme (plusieurs pages, liens de toutes sortes)
bas("GROS.BAS", b"".join(b"%d PRINT\"LIGNE %d\";A$(%d):DATA %d,X\r\n"
                         % (i, i, i % 7, i * 3) for i in range(1, 900)))
# programme tapé aussi au clavier dans Oricutron (majuscules : le clavier
# de l'Oric démarre en CAPS)
TAPE = (b"10 REM ESSAI MKTAP\r\n20 A=5:B$=\"OK\":DATA 1,2,X\r\n"
        b"30 FOR I=1 TO 3:PRINT I;:NEXT\r\n"
        b"40 IF A>1 THEN PRINT \"MKTAP BAS \";B$\r\n50 ? TAB(2);\"FIN\"\r\n")
bas("TAPE.BAS", TAPE)
open(d + "/tape.txt", "wb").write(TAPE.replace(b"\r\n", b"\n"))
bas("ADR.BAS", b"10 END\r\n")
bas("SANSNUM.BAS", b"10 END\r\nPRINT\r\n")
bas("GRANDNUM.BAS", b"10 END\r\n64000 END\r\n")
bas("ORDRE.BAS", b"10 END\r\n20 END\r\n15 END\r\n")
bas("LONG.BAS", b"10 REM " + b"A" * 260 + b"\r\n")
bas("LONGCODE.BAS", b"10 " + b"A" * 251 + b"\r\n")
bas("CAR.BAS", b"10 PRINT \xe9\r\n")
bas("VIDE.BAS", b"\r\n   \r\n10\r\n")
bas("ENORME.BAS", b"".join(b"%d REM %s\r\n" % (i, b"B" * 120)
                           for i in range(1, 320)))
E
ok=0; ko=0
# cas : NOM puis arguments ; le .TAP de mktap.py va dans $T/ref
cas() {
  n=$1; shift
  (cd "$T" && python3 "$R/tools/run_com.py" . MKTAP.COM $n "$@" > "$T/$n.out" 2>&1)
  mkdir -p "$T/ref"
  (cd "$T" && python3 "$R/tools/mktap.py" ref/$n.TAP "$@" > /dev/null)
  if python3 - "$T/$n.TAP" "$T/ref/$n.TAP" <<'E'
import sys
a = open(sys.argv[1], "rb").read()
b = open(sys.argv[2], "rb").read()
# MKTAP.COM : multiple de 128, ^Z de remplissage ; un octet 0 avant eux si
# le dernier octet utile vaut $1A
attendu = b + (b"\0" if b.endswith(b"\x1a") else b"")
sys.exit(not (len(a) % 128 == 0 and a.rstrip(b"\x1a") == attendu.rstrip(b"\x1a")
              and a[:len(attendu)] == attendu))
E
  then echo "identique : $n $*"; ok=$((ok+1))
  else echo "DIFFERENT : $n $*"; ko=$((ko+1)); cat "$T/$n.out"
  fi
}
cas T1 TEST.COM 9000 /R
cas T2 TEST.COM 9000 /R DATA.BIN 9100
cas T3 TEST.COM 9000 DATA.BIN 9100,80 ZFIN.BIN 500
cas T4 ZFIN.BIN 600,17
cas T5 GROS.BIN A000 TEST.COM 9000 /R DATA.BIN 600 ZFIN.BIN 8000
cas T6 TEST.COM 1000 /R
cas T7 TEST.COM A00 /R DATA.BIN 9100
cas T8 TEST.COM 503 /R
cas B1 PROG.BAS /R
cas B2 PROG.BAS DATA.BIN 9100 TEST.COM 9000
cas B3 TEST.COM 9000 LF.BAS /R
cas B4 GROS.BAS
if grep -q "ligne 110 : plus de 78 caracteres" "$T/B1.out"; then
  echo "avertissement : ligne de plus de 78 caracteres"; ok=$((ok+1))
else echo "AVERTISSEMENT ABSENT"; cat "$T/B1.out"; ko=$((ko+1))
fi
# erreurs : le .TAP ne doit pas être écrit
erreur() {
  n=$1; shift
  (cd "$T" && python3 "$R/tools/run_com.py" . MKTAP.COM $n "$@" > "$T/$n.out" 2>&1)
  if [ -f "$T/$n.TAP" ]; then echo "ECRIT A TORT : $n $*"; ko=$((ko+1))
  else echo "refuse : $n $* -> $(grep -v instructions "$T/$n.out" | tail -1)"; ok=$((ok+1))
  fi
}
erreur E1 TEST.COM 400
erreur E2 GROS.BIN B000
erreur E3 TEST.COM 9000 DATA.BIN 9010
erreur E4 TEST.COM 500 /R DATA.BIN 9000
erreur E5 TEST.COM 9000,100
erreur E6 ABSENT.COM 9000
erreur E7 TEST.COM 9000 /R DATA.BIN 8000 /R
erreur E8 TEST.COM XYZ
erreur E9 TEST.COM 502 /R
erreur E10 TEST.COM 500 /R
# .BAS fautifs : refusés aussi par mktap.py
erreurb() {
  erreur "$@"
  n=$1; shift
  if (cd "$T" && python3 "$R/tools/mktap.py" ref/$n.TAP "$@" > /dev/null 2>&1); then
    echo "ACCEPTE PAR mktap.py : $n $*"; ko=$((ko+1))
  fi
}
erreurb E11 ADR.BAS 501
erreurb E12 PROG.BAS LF.BAS
erreurb E13 PROG.BAS TEST.COM 9000 /R
erreurb E14 SANSNUM.BAS
erreurb E15 GRANDNUM.BAS
erreurb E16 ORDRE.BAS
erreurb E17 LONG.BAS
erreurb E18 LONGCODE.BAS
erreurb E19 CAR.BAS
erreurb E20 VIDE.BAS
erreurb E21 ENORME.BAS
erreurb E22 PROG.BAS DATA.BIN 500,100

# chargement sous BASIC 1.1 (Oricutron de test)
if [ -x tools/oricutron/Oricutron-sdl2 ] && [ -f tools/oricutron/roms/basic11b.rom ]; then
  python3 -c "import sys; open(sys.argv[2],'wb').write(open(sys.argv[1],'rb').read().rstrip(b'\x1a'))" \
    "$T/T2.TAP" "$T/t2.tap"
  ORIC_KEYS_AT=500 tools/run_test.sh '|20 A=5
|LIST
' 1400 "$T/b" --turbotape on -t "$T/t2.tap" > /dev/null 2>&1 || true
  ecran=$(python3 tools/screen.py "$T/b.mem")
  if echo "$ecran" | grep -q 'MKTAP OK' && echo "$ecran" | grep -q '10 CLOAD"":CLOAD"":CALL#9000' \
     && echo "$ecran" | grep -q ' 20 A=5' \
     && python3 -c "import sys; m=open(sys.argv[1],'rb').read(); d=open(sys.argv[2],'rb').read(); sys.exit(m[0x9100:0x9100+300]!=d)" "$T/b.mem" "$T/DATA.BIN"
  then echo "BASIC 1.1 : chargeur, code et donnees en place"; ok=$((ok+1))
  else echo "BASIC 1.1 : ECHEC"; echo "$ecran"; ko=$((ko+1))
  fi
  # .BAS : le programme chargé (et lancé par /R) doit être, octet pour
  # octet, celui que la ROM fait quand on le tape ; même début des
  # variables ($9C-$9D : la fin du bloc, son octet de plus)
  (cd "$T" && python3 "$R/tools/mktap.py" tape.tap TAPE.BAS /R > /dev/null)
  ORIC_KEYS_AT=400 tools/run_test.sh "$(cat "$T/tape.txt")
" 2600 "$T/k" > /dev/null 2>&1 || true
  ORIC_KEYS_AT=500 tools/run_test.sh '|' 1000 "$T/c" --turbotape on -t "$T/tape.tap" > /dev/null 2>&1 || true
  ecran=$(python3 tools/screen.py "$T/c.mem")
  if echo "$ecran" | grep -q 'MKTAP BAS OK' \
     && python3 - "$T/k.mem" "$T/c.mem" "$T/tape.tap" <<'E'
import sys
k = open(sys.argv[1], "rb").read()
c = open(sys.argv[2], "rb").read()
t = open(sys.argv[3], "rb").read()
fin = t[9] << 8 | t[10]                 # fin du bloc (incluse, en-tête)
n = fin - 0x0501                        # programme sans l'octet de plus
sys.exit(not (n > 0 and k[0x501:0x501 + n] == c[0x501:0x501 + n] == t[-n - 1:-1]
              and k[0x9C:0x9E] == c[0x9C:0x9E] == bytes([fin & 255, fin >> 8])))
E
  then echo "BASIC 1.1 : .BAS charge, lance, identique au programme tape"; ok=$((ok+1))
  else echo "BASIC 1.1 : .BAS ECHEC"; echo "$ecran"; python3 tools/screen.py "$T/k.mem"; ko=$((ko+1))
  fi
else
  echo "(Oricutron de test ou ROM BASIC absente : chargement non essayé)"
fi
rm -rf "$T"
# codage des .BAS contre la ROM elle-même (6502 simulé)
if [ -f tools/oricutron/roms/basic11b.rom ]; then
  if python3 tools/test_bas.py; then ok=$((ok+1)); else ko=$((ko+1)); fi
fi
echo "$ok bons, $ko mauvais"
[ $ko -eq 0 ]
