#!/bin/sh
# Non-régression des bibliothèques allégées de la disquette
# (tools/strip_inc.py : CPA.INC, HIRES.INC, GRX.INC, ANIM.INC sans
# commentaires). Le même programme doit donner le même binaire avec la
# copie allégée qu'avec l'original :
#   1. chaque programme de progs/, assemblé par xa ;
#   2. les programmes traduits par GRAPHER NOM /A (tools/grapher_tests),
#      assemblés par xa ;
#   3. VOIR et un programme traduit, assemblés par ASM.COM (6502 simulé,
#      tools/run_com.py) avec les copies allégées, comparés à xa.
#   XA=chemin/vers/xa tools/test_inc.sh
set -e
cd "$(dirname "$0")/.."
XA=${XA:-tools/xa}
case "$XA" in */*) XA="$(cd "$(dirname "$XA")" && pwd)/$(basename "$XA")";; esac
RUN="$(pwd)/tools/run_com.py"
T=$(mktemp -d)
mkdir "$T/o" "$T/s"
# o : originaux ; s : copies allégées (sous les deux noms, comme xa les cherche)
for i in cpa hires grx anim; do
  I=$(echo $i | tr a-z A-Z)
  cp progs/$i.inc "$T/o/$i.inc"; cp progs/$i.inc "$T/o/$I.INC"
  python3 tools/strip_inc.py progs/$i.inc "$T/s/$i.inc" > /dev/null
  cp "$T/s/$i.inc" "$T/s/$I.INC"
done
cp progs/*_tab.s progs/*_inc.s "$T/o/"; cp progs/*_tab.s progs/*_inc.s "$T/s/"
ok=0; ko=0
same() {   # same NOM fichier1 fichier2
  if cmp -s "$2" "$3"; then ok=$((ok+1)); else echo "DIFFERENT : $1"; ko=$((ko+1)); fi
}
# 1. programmes de progs/
for p in $(ls progs/*.s | grep -v -e _tab.s -e _inc.s); do
  n=$(basename $p .s)
  cp $p "$T/o/"; cp $p "$T/s/"
  (cd "$T/o" && $XA -o $n.bin $n.s > /dev/null)
  (cd "$T/s" && $XA -o $n.bin $n.s > /dev/null)
  same "$n (xa)" "$T/o/$n.bin" "$T/s/$n.bin"
done
# 2. programmes traduits par GRAPHER
cp build/progs/GRAPHER.COM "$T/"; cp build/progs/ASM.COM "$T/s/"; cp files/anim/CUBE.ANI "$T/"
last=""
for f in tools/grapher_tests/*.grx; do
  N=$(basename "$f" .grx | tr a-z A-Z)
  tr -d '\r' < "$f" | sed 's/$/\r/' > "$T/$N.GRX"
  (cd "$T" && python3 "$RUN" "$T" GRAPHER.COM "$N" /A > /dev/null 2>&1) || true
  [ -f "$T/$N.ASM" ] || continue
  tr -d '\032' < "$T/$N.ASM" > "$T/o/$N.s"; cp "$T/o/$N.s" "$T/s/$N.s"
  (cd "$T/o" && $XA -o $N.bin $N.s > /dev/null 2>&1) || continue   # erreur voulue du test
  (cd "$T/s" && $XA -o $N.bin $N.s > /dev/null)
  same "$N (GRAPHER /A, xa)" "$T/o/$N.bin" "$T/s/$N.bin"
  last=$N
done
# 3. ASM.COM avec les copies allégées
for n in voir $(echo $last | tr A-Z a-z); do
  N=$(echo $n | tr a-z A-Z)
  [ -f "$T/o/$n.bin" ] || [ -f "$T/o/$N.bin" ] || continue
  ref="$T/o/$n.bin"; [ -f "$ref" ] || ref="$T/o/$N.bin"
  src="$T/s/$n.s"; [ -f "$src" ] || src="$T/s/$N.s"
  cp "$src" "$T/s/$N.ASM"
  (cd "$T/s" && python3 "$RUN" "$T/s" ASM.COM $n > /dev/null 2>&1) || true
  if [ -f "$T/s/$N.COM" ] && cmp -s -n $(wc -c < "$ref") "$ref" "$T/s/$N.COM"; then ok=$((ok+1))
  else echo "DIFFERENT : $N (ASM.COM)"; ko=$((ko+1)); fi
done
rm -rf "$T"
echo "bibliothèques allégées : $ok identiques, $ko différents"
[ $ko -eq 0 ]
