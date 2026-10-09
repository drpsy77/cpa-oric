#!/bin/sh
# Non-régression de GRAPHER.COM sans émulateur : chaque fichier de
# tools/grapher_tests/*.grx est exécuté dans le 6502 simulé de
# tools/run_com.py (mode texte : PRINT et messages d'erreur seulement),
# et la sortie est comparée au fichier .ref.
#   tools/test_grapher.sh          compare aux références
#   REF=1 tools/test_grapher.sh    réécrit les références (après vérification !)
set -e
cd "$(dirname "$0")/.."
D=tools/grapher_tests
T=$(mktemp -d)
cp build/progs/GRAPHER.COM "$T/"
ko=0
for f in $D/*.grx; do
  n=$(basename "$f" .grx)
  N=$(echo "$n" | tr a-z A-Z)
  tr -d '\r' < "$f" | sed 's/$/\r/' > "$T/$N.GRX"
  (cd "$T" && python3 "$OLDPWD/tools/run_com.py" "$T" GRAPHER.COM "$N" 2>&1) \
    | grep -v '^\[[0-9]* instructions\]' > "$T/$n.out"
  if [ -n "$REF" ]; then cp "$T/$n.out" "$D/$n.ref"; echo "référence écrite : $n"
  elif diff "$D/$n.ref" "$T/$n.out" > "$T/$n.diff"; then echo "identique : $n"
  else echo "DIFFERENT : $n"; cat "$T/$n.diff"; ko=$((ko+1)); fi
done
rm -rf "$T"
echo "GRAPHER : $ko différence(s)"
[ $ko -eq 0 ]
