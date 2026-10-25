#!/bin/sh
# GRXASM NOM /O (programme GRAPHER pour un Oric seul) et ASM /T :
#   1. traduction dans le 6502 simulé (tools/run_com.py) : refus de ce qu'un
#      Oric seul n'a pas (SPLIT, écritures, image .IMG), fichier absent
#      signalé ;
#   2. ASM.COM NOM /E /T (6502 simulé) écrit le .TAP de xa et efface NOM.ASM ;
#   3. sous BASIC 1.1 dans Oricutron, CLOAD"" (démarrage automatique) :
#      tools/oric_tests/o_cons.grx (console, saisies, fichiers recopiés,
#      FOUND, LORES, HIRES et .HIZ, police remise au retour du texte ; à la
#      fin, une touche, puis la ROM redémarre) ; les exemples CARTE, SERPENT,
#      DEFILE et leurs jumeaux anglais MAP, SNAKE, ROAD, dont les .TAP sont
#      écrits dans build/tap/ (prêts pour un Oric : EXPORT, clé du LOCI).
#   tools/test_oric.sh
set -e
cd "$(dirname "$0")/.."
R=$(pwd)
XA=${XA:-tools/xa}
case "$XA" in */*) XA="$(cd "$(dirname "$XA")" && pwd)/$(basename "$XA")";; esac
RUN="$R/tools/run_com.py"
T=$(mktemp -d)
ok=0; ko=0
bon() { echo "bon : $1"; ok=$((ok+1)); }
mal() { echo "MAUVAIS : $1"; ko=$((ko+1)); }

# prepare L : $T/L avec GRXASM, ASM et les bibliothèques de la langue L
prepare() {
  P=build/progs; S=build/src
  [ "$1" = en ] && { P=build/progs-en; S=build/src-en; }
  mkdir -p "$T/$1"
  cp $P/GRXASM.COM $P/ASM.COM $S/*.INC "$T/$1/"
}
# grx L NOM SOURCE : GRXASM NOM /O dans $T/L (messages dans NOM.out)
grx() {
  tr -d '\r' < "$3" | sed 's/$/\r/' > "$T/$1/$2.GRX"
  rm -f "$T/$1/$2.ASM"
  (cd "$T/$1" && python3 "$RUN" . GRXASM.COM $2 /O 2>&1 < /dev/null) | grep -v '^\[' > "$T/$1/$2.out" || true
}
prepare fr
prepare en

# 1. refus et fichier absent
i=0
for c in "SPLIT" "SAVE A X" "BSAVE A X" "BSAVE SCREEN X" "GSAVE X" "GLOAD X.IMG"; do
  i=$((i+1))
  printf 'DIM A(2)\n%s\n' "$c" > "$T/r.grx"
  grx fr R$i "$T/r.grx"
  w=$(echo "$c" | cut -d' ' -f1)
  if [ ! -f "$T/fr/R$i.ASM" ] && grep -q "^L 2 $w : pas avec /O" "$T/fr/R$i.out"; then
    bon "refus de $c"
  else mal "refus de $c"; cat "$T/fr/R$i.out"; fi
done
printf 'DIM A(2)\nLOAD A ABSENT\n' > "$T/r.grx"
grx fr ABS "$T/r.grx"
if [ -f "$T/fr/ABS.ASM" ] && grep -q "^ABSENT.TXT absent : pas inclus" "$T/fr/ABS.out"; then
  bon "fichier absent signale"
else mal "fichier absent"; cat "$T/fr/ABS.out"; fi

# programme trop gros pour l'Oric (fichiers recopiés : 40 Ko) : l'en-tête
# du .TAP ne s'assemble pas (O_PLACE > 255)
python3 -c "
import sys
for n in ('G1.DAT', 'G2.DAT'):
    open(sys.argv[1] + '/' + n, 'wb').write(bytes(range(256)) * 80)
" "$T/fr"
printf 'DIM A$(200)\nBLOAD A$ G1\nBLOAD A$ G2\n' > "$T/r.grx"
grx fr GROS "$T/r.grx"
tr -d '\032' < "$T/fr/GROS.ASM" > "$T/fr/gros.s"
if (cd "$T/fr" && $XA -o gros.ref gros.s > gros.err 2>&1); then mal "trop gros : assemble quand meme"
elif grep -q "O_PLACE" "$T/fr/gros.s" && grep -q "$(grep -n 'O_PLACE,' "$T/fr/gros.s" | cut -d: -f1)" "$T/fr/gros.err"; then
  bon "trop gros : l'en-tete (O_PLACE) ne s'assemble pas"
else mal "trop gros"; cat "$T/fr/gros.err"; fi

# 2. ASM.COM /T contre xa (o_cons, dans les deux langues)
for L in fr en; do
  cp tools/oric_tests/*.TXT tools/oric_tests/*.DAT files/anim/LOGO.HIZ "$T/$L/"
  grx $L O_CONS tools/oric_tests/o_cons.grx
  tr -d '\032' < "$T/$L/O_CONS.ASM" > "$T/$L/o_cons.s"
  (cd "$T/$L" && $XA -o o_cons.ref o_cons.s)   # (pas .TAP : ASM l'effacerait)
  (cd "$T/$L" && python3 "$RUN" . ASM.COM O_CONS /E /T > asm.out 2>&1) || true
  if [ -f "$T/$L/O_CONS.TAP" ] && [ ! -f "$T/$L/O_CONS.ASM" ] && python3 - "$T/$L/o_cons.ref" "$T/$L/O_CONS.TAP" <<'E'
import sys
a = open(sys.argv[1], "rb").read()
b = open(sys.argv[2], "rb").read()
# ASM complète le dernier enregistrement par des 0
sys.exit(not (b[:len(a)] == a and len(b) % 128 == 0 and not b[len(a):].strip(b"\0")))
E
  then bon "ASM /T ($L) : le .TAP de xa, NOM.ASM efface"
  else mal "ASM /T ($L)"; cat "$T/$L/asm.out"; fi
done

# 3. sous BASIC 1.1 (Oricutron de test)
if [ ! -x tools/oricutron/Oricutron-sdl2 ] || [ ! -f tools/oricutron/roms/basic11b.rom ]; then
  echo "(Oricutron de test ou ROM BASIC absente : chargement non essayé)"
else
  # ecran FICHIER.mem : texte de l'écran
  ecran() { python3 tools/screen.py "$1" 2>/dev/null | head -28; }
  # o_cons : saisies, puis tout ce qui s'affiche avant le LORES
  ORIC_KEYS_AT=420 tools/run_test.sh "$(printf 'Oric\nx\n-12')" 800 "$T/c1" --turbotape on \
    -t "$T/fr/O_CONS.TAP" > /dev/null 2>&1 || true
  e=$(ecran "$T/c1.mem")
  manque=""
  for l in "Oric seul" "deux 4" "11 22 33" "PREMIERE/SECONDE" "FOUND 0" "BINAIRE 1" "nom : oRIC" "-12"; do
    echo "$e" | grep -qF "|..$l" || manque="$manque [$l]"
  done
  if [ -z "$manque" ]; then bon "o_cons : console, saisies, fichiers recopies, FOUND"
  else mal "o_cons :$manque"; echo "$e"; fi
  # o_cons jusqu'à la fin : « fin », police intacte après le HIRES, une
  # touche attendue ; puis la touche : la ROM redémarre (« | » : pause, et
  # pour que $(...) garde le dernier RETURN)
  ORIC_KEYS_AT=420 tools/run_test.sh "$(printf 'Oric\nx\n-123\n|')" 1000 "$T/c2" --turbotape on \
    -t "$T/fr/O_CONS.TAP" > /dev/null 2>&1 || true
  ORIC_KEYS_AT=420 tools/run_test.sh "$(printf 'Oric\nx\n-123\n|||| ')" 1300 "$T/c3" --turbotape on \
    -t "$T/fr/O_CONS.TAP" > /dev/null 2>&1 || true
  if ecran "$T/c2.mem" | grep -q '^ 1|..fin ' && python3 - "$T/c1.mem" "$T/c2.mem" <<'E'
import sys
a = open(sys.argv[1], "rb").read()
b = open(sys.argv[2], "rb").read()
sys.exit(not (a[0xB500:0xB800] == b[0xB500:0xB800] and b[0xBFDF] == 0x1A))
E
  then bon "o_cons : retour au texte (police remise), fin qui attend une touche"
  else mal "o_cons : fin"; ecran "$T/c2.mem"; fi
  if ecran "$T/c3.mem" | grep -q 'ORIC EXTENDED BASIC'; then bon "o_cons : la ROM redemarre"
  else mal "o_cons : pas de redemarrage"; ecran "$T/c3.mem"; fi

  # exemples : L NOM source fichiers trame touches texte_attendu
  mkdir -p build/tap
  cp files/tuiles.spr "$T/fr/TUILES.SPR"; cp files/tuiles.spr "$T/en/TILES.SPR"
  while read -r L N SRC F K ATT; do
    grx $L $N $SRC
    n=$(echo $N | tr A-Z a-z)
    tr -d '\032' < "$T/$L/$N.ASM" > "$T/$L/$n.s"
    (cd "$T/$L" && $XA -o $N.TAP $n.s)
    cp "$T/$L/$N.TAP" build/tap/
    [ "$K" = - ] && K=""
    ORIC_KEYS_AT=700 tools/run_test.sh "$(printf "$K")" $F "$T/$n" --turbotape on \
      -t "$T/$L/$N.TAP" < /dev/null > /dev/null 2>&1 || true
    att=$(echo "$ATT" | tr _ ' ')
    if ecran "$T/$n.mem" | grep -qF "$att"; then
      bon "$N.TAP ($(wc -c < "$T/$L/$N.TAP") octets) : $att"
    else mal "$N.TAP : $att"; ecran "$T/$n.mem"; fi
  done <<'E'
fr CARTE files/carte.grx 900 \002\002\002\004\004 X_70__Y_36
en MAP files/en/map.grx 900 \002\002\002\004\004 X_70__Y_36
fr SERPENT files/serpent.grx 500 - PERDU_!
en SNAKE files/en/snake.grx 500 - LOST!
fr DEFILE files/defile.grx 360 - Perdu_!_Score_:
en ROAD files/en/road.grx 360 - Lost!_Score:
E
fi
rm -rf "$T"
echo "Oric seul (/O) : $ok bons, $ko mauvais"
[ $ko -eq 0 ]
