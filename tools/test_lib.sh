#!/bin/sh
# Non-régression de GRX.LIB (bibliothèques précompilées, tools/mk_lib.py) :
# chaque programme de tools/grapher_tests et chaque exemple livré (files/*.grx)
# est traduit par GRXASM deux fois,
# avec et sans /O :
#   - sans GRX.LIB : les routines utiles sont recopiées des .INC marqués,
#     le .ASM est assemblé par xa (référence) ;
#   - avec GRX.LIB : le .ASM se termine par « #lib "GRX.LIB",... », il est
#     assemblé par ASM.COM (6502 simulé, tools/run_com.py), qui relie les
#     routines gardées ;
# le .COM (le .TAP avec /O) doit être le même, octet par octet. Affiche
# aussi les instructions exécutées par GRXASM (sans / avec GRX.LIB) et par ASM.
#   tools/test_lib.sh [NOM...]     (défaut : tous ; ~30 min sur un Mac)
#   LANGUE=en tools/test_lib.sh    (bibliothèques de build/src-en)
set -e
cd "$(dirname "$0")/.."
R=$(pwd)
XA=${XA:-tools/xa}
case "$XA" in */*) XA="$(cd "$(dirname "$XA")" && pwd)/$(basename "$XA")";; esac
if [ "$LANGUE" = en ]; then S=build/src-en; P=build/progs-en; else S=build/src; P=build/progs; fi
T=$(mktemp -d)
mkdir "$T/w"
cp $S/*.INC $S/GRX.LIB $P/GRXASM.COM $P/ASM.COM files/anim/CUBE.ANI \
   tools/grapher_tests/*.TXT tools/grapher_tests/*.SPR "$T/w/"
for f in tools/grapher_tests/*.grx; do
  N=$(basename "$f" .grx | tr a-z A-Z)
  tr -d '\r' < "$f" | sed 's/$/\r/' > "$T/w/$N.GRX"
done
# exemples livrés (files/*.grx : CARTE, SPRITES, JEU...), avec leurs données
mkdir "$T/x"
cp $S/*.INC $S/GRX.LIB $P/GRXASM.COM $P/ASM.COM files/anim/*.ANI files/anim/*.HIZ "$T/x/"
for f in files/*.grx files/*.GRX files/*.spr; do
  N=$(basename "$f" | tr a-z A-Z)
  case "$N" in *.GRX) tr -d '\r' < "$f" | sed 's/$/\r/' > "$T/x/$N";; *) cp "$f" "$T/x/$N";; esac
done
LISTE="$*"
[ -n "$LISTE" ] || LISTE="$(cd "$T/w" && ls *.GRX | sed 's/\.GRX$//') $(cd "$T/x" && ls *.GRX | sed 's/\.GRX$//; s/^/x:/')"
ok=0; ko=0
compte() { grep -o '[0-9]* instructions' "$1" | cut -d' ' -f1; }
for N in $LISTE; do
  W="$T/w"
  case "$N" in x:*) N=${N#x:}; W="$T/x";; esac
  [ -f "$W/$N.GRX" ] || [ "$W" = "$T/x" ] || { [ -f "$T/x/$N.GRX" ] && W="$T/x"; }
  for O in "" /O; do
    D="$T/$N$O"; rm -rf "$D"; mkdir -p "$D/t" "$D/l"
    for d in t l; do
      (cd "$W" && cp $(ls | grep -v -e '\.GRX$' -e '^GRX\.LIB$') "$N.GRX" "$D/$d/")
    done
    cp "$W/GRX.LIB" "$D/l/"
    (cd "$D/t" && python3 "$R/tools/run_com.py" "$D/t" GRXASM.COM $N $O > g.log 2>&1) || true
    (cd "$D/l" && python3 "$R/tools/run_com.py" "$D/l" GRXASM.COM $N $O > g.log 2>&1) || true
    if [ ! -f "$D/t/$N.ASM" ]; then
      if [ -f "$D/l/$N.ASM" ]; then echo "DIFFERENT : $N$O (traduit seulement avec GRX.LIB)"; ko=$((ko+1)); fi
      continue                          # refusé à la traduction, des deux façons
    fi
    tr -d '\032' < "$D/t/$N.ASM" > "$D/t/ref.s"
    if [ -n "$O" ]; then F=$N.TAP; else F=$N.COM; fi
    (cd "$D/l" && python3 "$R/tools/run_com.py" "$D/l" ASM.COM $N ${O:+/T} > a.log 2>&1) || true
    if ! (cd "$D/t" && "$XA" -o ref.bin ref.s > xa.log 2>&1); then
      # refusé à l'assemblage (ANIMS /O : trop gros pour un Oric seul) : ASM aussi
      if [ -f "$D/l/$F" ]; then echo "DIFFERENT : $N$O (refusé par xa seulement)"; ko=$((ko+1))
      else ok=$((ok+1)); echo "identique : $N$O (refusé à l'assemblage, des deux façons)"; fi
      continue
    fi
    if [ -f "$D/l/$F" ] && cmp -s -n $(wc -c < "$D/t/ref.bin") "$D/t/ref.bin" "$D/l/$F"; then
      ok=$((ok+1))
      echo "identique : $N$O (GRXASM $(compte "$D/t/g.log") / $(compte "$D/l/g.log"), ASM $(compte "$D/l/a.log"))"
    else
      echo "DIFFERENT : $N$O"; tail -3 "$D/l/a.log"; ko=$((ko+1))
    fi
  done
done
rm -rf "$T"
echo "$ok identiques, $ko différents"
[ $ko -eq 0 ]
