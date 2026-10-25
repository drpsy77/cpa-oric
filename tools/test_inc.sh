#!/bin/sh
# Non-régression des bibliothèques allégées de la disquette
# (tools/strip_inc.py : CPA.INC, HIRES.INC, GRX.INC, ANIM.INC, ARR.INC, FIL.INC, SPR.INC,
# ORIC.INC sans commentaires, avec leurs messages, puis marques ;@ de tools/mark_inc.py) :
#   1. chaque programme de progs/ donne le même binaire avec la copie
#      allégée qu'avec l'original (xa ; copies sans les messages « ;#msg »,
#      que ces programmes incluent à part) ;
#   2. les programmes traduits par GRXASM NOM (tools/grapher_tests), qui
#      recopient les routines utiles des copies marquées (messages compris,
#      comme sur la disquette), s'assemblent par xa (une routine oubliée :
#      étiquette non définie) ; de même traduits par GRXASM NOM /O (Oric
#      seul : ORIC.INC recopiée, sans CPA.INC), quand la traduction
#      l'accepte ;
#   3. VOIR et un programme traduit, assemblés par ASM.COM (6502 simulé,
#      tools/run_com.py), donnent le même binaire que xa.
#   XA=chemin/vers/xa tools/test_inc.sh
set -e
cd "$(dirname "$0")/.."
XA=${XA:-tools/xa}
case "$XA" in */*) XA="$(cd "$(dirname "$XA")" && pwd)/$(basename "$XA")";; esac
RUN="$(pwd)/tools/run_com.py"
T=$(mktemp -d)
mkdir "$T/o" "$T/s" "$T/m"
# o : originaux ; s : copies allégées sans messages (sous les deux noms, comme
# xa les cherche) ; m : copies de la disquette (messages en français, marques)
for i in cpa hires grx anim arr fil spr oric; do
  I=$(echo $i | tr a-z A-Z)
  cp progs/$i.inc "$T/o/$i.inc"; cp progs/$i.inc "$T/o/$I.INC"
  python3 tools/strip_inc.py progs/$i.inc "$T/s/$i.inc" - > /dev/null
  cp "$T/s/$i.inc" "$T/s/$I.INC"
  python3 tools/strip_inc.py progs/$i.inc "$T/m/$I.INC" > /dev/null
done
python3 tools/mark_inc.py "$T/m" > /dev/null
cp progs/*_tab.s progs/*_inc.s progs/msg/fr/*.msg "$T/o/"; cp progs/*_tab.s progs/*_inc.s progs/msg/fr/*.msg "$T/s/"
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
# 2. programmes traduits par GRXASM (bibliothèques marquées à côté du .GRX)
cp build/progs/GRXASM.COM "$T/"; cp build/progs/ASM.COM "$T/s/"; cp build/progs/ASM.COM "$T/m/"
cp files/anim/CUBE.ANI "$T/"; cp tools/grapher_tests/*.TXT tools/grapher_tests/*.SPR "$T/"
cp "$T/m/"*.INC "$T/"
last=""
for f in tools/grapher_tests/*.grx; do
  N=$(basename "$f" .grx | tr a-z A-Z)
  tr -d '\r' < "$f" | sed 's/$/\r/' > "$T/$N.GRX"
  (cd "$T" && python3 "$RUN" "$T" GRXASM.COM "$N" > /dev/null 2>&1) || true
  [ -f "$T/$N.ASM" ] || continue
  tr -d '\032' < "$T/$N.ASM" > "$T/m/$N.s"
  if (cd "$T/m" && $XA -o $N.bin $N.s > $N.err 2>&1); then ok=$((ok+1))
  else echo "DIFFERENT : $N (GRXASM, xa)"; head -3 "$T/m/$N.err"; ko=$((ko+1)); fi
  last=$N
  # /O : sans CPA.INC (refusé à la traduction : SPLIT, écritures)
  rm -f "$T/$N.ASM"
  (cd "$T" && python3 "$RUN" "$T" GRXASM.COM "$N" /O > /dev/null 2>&1) || true
  [ -f "$T/$N.ASM" ] || continue
  mkdir -p "$T/o2"
  tr -d '\032' < "$T/$N.ASM" > "$T/o2/$N.s"
  if (cd "$T/o2" && $XA -o $N.tap $N.s > $N.err 2>&1); then ok=$((ok+1))
  else echo "DIFFERENT : $N (GRXASM /O, xa)"; head -3 "$T/o2/$N.err"; ko=$((ko+1)); fi
done
# 3. ASM.COM avec les copies allégées : VOIR (s), un programme traduit (m)
asmcom() {   # asmcom DOSSIER nom référence
  N=$(echo $2 | tr a-z A-Z)
  [ -f "$3" ] || return 0
  cp "$1/$2.s" "$1/$N.ASM"
  (cd "$1" && python3 "$RUN" "$1" ASM.COM $2 > /dev/null 2>&1) || true
  if [ -f "$1/$N.COM" ] && cmp -s -n $(wc -c < "$3") "$3" "$1/$N.COM"; then ok=$((ok+1))
  else echo "DIFFERENT : $N (ASM.COM)"; ko=$((ko+1)); fi
}
asmcom "$T/s" voir "$T/o/voir.bin"
[ -n "$last" ] && asmcom "$T/m" $last "$T/m/$last.bin"
rm -rf "$T"
echo "bibliothèques allégées : $ok identiques, $ko différents"
[ $ko -eq 0 ]
