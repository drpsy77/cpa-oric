#!/bin/bash
# Les exemples .GRX traduits (files/en, files/en/noms.txt) doivent avoir le
# même code que les originaux : chaque paire est traduite par GRXASM (6502
# simulé, tools/run_com.py), français avec les bibliothèques de build/src,
# anglais avec celles de build/src-en ; les deux .ASM sont comparés sans les
# commentaires, avec les chaînes vidées et les noms de sous-programmes
# traduits ramenés au français (SUBS). Différences admises : g_m_el (longueur
# du préfixe d'erreur) et celles de ADMIS (texte recentré).
#   tools/test_exemples_en.sh      (après ./build.sh)
set -e
cd "$(dirname "$0")/.."
RUN="$(pwd)/tools/run_com.py"
SUBS="s/FRAME/CADRE/g; s/FOOD/MANGE/g"
ADMIS="PATTERNS:lda #\$1[01]"     # GTEXT 16 96 ETOILES / GTEXT 17 96 STARS
T=$(mktemp -d)
mkdir "$T/fr" "$T/en"
cp build/progs/GRXASM.COM build/src/*.INC "$T/fr/"
cp build/progs-en/GRXASM.COM build/src-en/*.INC "$T/en/"
norm() { tr -d '\032\r' < "$1" | grep -v '^;' | sed -e 's/"[^"]*"/""/g' -e "$SUBS" | grep -v 'g_m_el'; }
ok=0; ko=0
grep -v '^#' files/en/noms.txt | while read fr en; do
  case "$fr" in *.grx|*.GRX) ;; *) continue ;; esac
  N=$(basename "$fr" | sed 's/\.[^.]*$//' | tr a-z A-Z); E=$(echo $en | sed 's/\..*//')
  tr -d '\r' < "$fr" | sed 's/$/\r/' > "$T/fr/$N.GRX"
  tr -d '\r' < "files/en/$(echo $en | tr A-Z a-z)" | sed 's/$/\r/' > "$T/en/$E.GRX"
  (cd "$T/fr" && python3 "$RUN" "$T/fr" GRXASM.COM $N > /dev/null 2>&1) || true
  (cd "$T/en" && python3 "$RUN" "$T/en" GRXASM.COM $E > /dev/null 2>&1) || true
  if [ ! -f "$T/fr/$N.ASM" ] || [ ! -f "$T/en/$E.ASM" ]; then echo "DIFFERENT : $N / $E (GRXASM)"; echo x >> "$T/ko"; continue; fi
  d=$(diff <(norm "$T/fr/$N.ASM") <(norm "$T/en/$E.ASM") | grep '^[<>]' | sed 's/^[<>] *//' | sort -u)
  a=$(echo "$ADMIS" | tr ' ' '\n' | grep "^$E:" | cut -d: -f2-)
  [ -n "$a" ] && d=$(echo "$d" | grep -v -e "$a" || true)
  if [ -z "$d" ]; then echo "identique : $N / $E"; else echo "DIFFERENT : $N / $E"; echo "$d" | head -5; echo x >> "$T/ko"; fi
done
n=$( [ -f "$T/ko" ] && wc -l < "$T/ko" || echo 0)
rm -rf "$T"
echo "exemples traduits : $n différence(s)"
[ "$n" -eq 0 ]
