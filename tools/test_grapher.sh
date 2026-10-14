#!/bin/sh
# Non-régression de GRAPHER.COM sans émulateur : chaque fichier de
# tools/grapher_tests/*.grx est exécuté dans le 6502 simulé de
# tools/run_com.py (mode texte : PRINT et messages d'erreur seulement ;
# pour les fichiers lo*.grx, l'écran texte du LORES en plus),
# et la sortie est comparée au fichier .ref ; puis il est traduit
# (GRXASM NOM ; GRAPHER NOM /A passe la main à GRXASM par CHAIN,
# vérifié une fois au début), assemblé avec xa (CPA.INC, GRX.INC, HIRES.INC,
# ANIM.INC ; CUBE.ANI pour ANIM) et
# exécuté : messages de la traduction et sortie comparés au fichier .kref.
#   tools/test_grapher.sh          compare aux références
#   REF=1 tools/test_grapher.sh    réécrit les références (après vérification !)
set -e
cd "$(dirname "$0")/.."
D=tools/grapher_tests
XA=${XA:-tools/xa}
case "$XA" in */*) XA="$(cd "$(dirname "$XA")" && pwd)/$(basename "$XA")";; esac
RUN="$(pwd)/tools/run_com.py"
T=$(mktemp -d)
cp build/progs/GRAPHER.COM build/progs/GRXASM.COM "$T/"
cp progs/cpa.inc "$T/CPA.INC"; cp progs/grx.inc "$T/GRX.INC"; cp progs/hires.inc "$T/HIRES.INC"
cp progs/anim.inc "$T/ANIM.INC"; cp progs/arr.inc "$T/ARR.INC"; cp files/anim/CUBE.ANI "$T/"
ko=0
check() {   # check NOM EXT : compare $T/NOM.out à $D/NOM.EXT
  if [ -n "$REF" ]; then cp "$T/$1.out" "$D/$1.$2"; echo "référence écrite : $1.$2"
  elif diff "$D/$1.$2" "$T/$1.out" > "$T/$1.diff"; then echo "identique : $1.$2"
  else echo "DIFFERENT : $1.$2"; cat "$T/$1.diff"; ko=$((ko+1)); fi
}
# GRAPHER NOM /A : CHAIN vers GRXASM avec le reste de la ligne
c=$(cd "$T" && python3 "$RUN" "$T" GRAPHER.COM CALC /A 12 Ab 2>&1 | grep '^\[CHAIN')
if [ "$c" = "[CHAIN GRXASM CALC /A 12 Ab]" ]; then echo "identique : CHAIN"
else echo "DIFFERENT : CHAIN ($c)"; ko=$((ko+1)); fi
for f in $D/*.grx; do
  n=$(basename "$f" .grx)
  N=$(echo "$n" | tr a-z A-Z)
  S=""; case "$n" in lo*) S=1;; esac   # LORES : l'écran texte à la fin
  IN=""; [ -f "$D/$n.in" ] && IN=$(cat "$D/$n.in")   # saisies (INPUT), séparées par |
  tr -d '\r' < "$f" | sed 's/$/\r/' > "$T/$N.GRX"
  (cd "$T" && INPUT="$IN" SCREEN=$S python3 "$RUN" "$T" GRAPHER.COM "$N" 2>&1) \
    | grep -v '^\[[0-9]* instructions\]' > "$T/$n.out" || true
  check "$n" ref
  rm -f "$T/$N.ASM" "$T/$N.COM"
  (cd "$T" && python3 "$RUN" "$T" GRXASM.COM "$N" 2>&1) \
    | grep -v '^\[[0-9]* instructions\]' > "$T/$n.out" || true
  if [ -f "$T/$N.ASM" ]; then
    tr -d '\032' < "$T/$N.ASM" > "$T/$n.s"
    (cd "$T" && "$XA" -o "$N.COM" "$n.s" > "$n.xa" 2>&1) || { echo "xa : $n"; cat "$T/$n.xa"; ko=$((ko+1)); }
    (cd "$T" && INPUT="$IN" SCREEN=$S python3 "$RUN" "$T" "$N.COM" 2>&1) \
      | grep -v '^\[[0-9]* instructions\]' >> "$T/$n.out" || true
  fi
  check "$n" kref
done
rm -rf "$T"
echo "GRAPHER : $ko différence(s)"
[ $ko -eq 0 ]
