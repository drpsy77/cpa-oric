#!/bin/sh
# MKTAP.COM contre tools/mktap.py, puis chargement sous BASIC 1.1.
#  1. MKTAP.COM est lancé dans le 6502 simulé (tools/run_com.py) sur
#     plusieurs cas ; le .TAP écrit, sans les ^Z qui complètent son dernier
#     enregistrement (ce que fait EXPORT), doit être celui de mktap.py.
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
# erreurs : le .TAP ne doit pas être écrit
erreur() {
  n=$1; shift
  (cd "$T" && python3 "$R/tools/run_com.py" . MKTAP.COM $n "$@" > "$T/$n.out" 2>&1)
  if [ -f "$T/$n.TAP" ]; then echo "ECRIT A TORT : $n $*"; ko=$((ko+1))
  else echo "refuse : $n $* -> $(head -1 "$T/$n.out")"; ok=$((ok+1))
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
else
  echo "(Oricutron de test ou ROM BASIC absente : chargement non essayé)"
fi
rm -rf "$T"
echo "$ok bons, $ko mauvais"
[ $ko -eq 0 ]
