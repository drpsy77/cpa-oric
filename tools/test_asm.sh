#!/bin/sh
# Non-régression de ASM.COM : chaque programme de progs/ est assemblé par
# ASM.COM (dans un 6502 simulé, tools/run_com.py, module Python py65) et
# comparé octet par octet avec le résultat de xa. Les programmes traduits
# (progs/msg/en) le sont une seconde fois avec leurs messages anglais.
#   XA=chemin/vers/xa tools/test_asm.sh
set -e
cd "$(dirname "$0")/.."
XA=${XA:-tools/xa}
case "$XA" in */*) XA="$(cd "$(dirname "$XA")" && pwd)/$(basename "$XA")";; esac
T=$(mktemp -d)
cp progs/cpa.inc progs/hires.inc progs/anim.inc progs/arr.inc progs/fil.inc progs/spr.inc progs/*_tab.s progs/*_inc.s progs/msg/fr/*.msg "$T/"
(cd progs && $XA -I msg/fr -o "$T/ASM.COM" asm.s)
ok=0; ko=0
# essai L p : assemble p par ASM.COM (messages déjà copiés dans $T) et par
# xa (-I msg/L -I msg/fr), puis compare
essai() {
  P=$(echo $2 | tr a-z A-Z)
  cp progs/$2.s "$T/$P.ASM"
  (cd progs && $XA -I msg/$1 -I msg/fr -o "$T/ref.bin" $2.s)
  (cd "$T" && python3 "$OLDPWD/tools/run_com.py" "$T" ASM.COM $2 >/dev/null 2>&1) || true
  n=$(wc -c < "$T/ref.bin")
  if [ -f "$T/$P.COM" ] && cmp -s -n $n "$T/ref.bin" "$T/$P.COM"; then
    echo "identique : $P ($1, $n octets)"; ok=$((ok+1))
  else
    echo "DIFFERENT : $P ($1)"; ko=$((ko+1))
  fi
  [ "$P" = ASM ] || rm -f "$T/$P.COM"
}
for p in hello copy gtest hex edit logo logotr debug help set poke go mem stat xdo export import usbdir usbmount format diskcopy type era ren voir vsync grapher grxasm cmder asm term xfer edsprite mktap; do
  essai fr $p
done
# en anglais : les programmes qui ont des messages dans progs/msg/en (et
# ceux qui incluent loci.msg) ; ASM.COM reste celui de la passe française
cp progs/msg/en/*.msg "$T/"
for p in $(ls progs/msg/en | sed 's/\.msg$//'); do
  [ -f progs/$p.s ] && essai en $p
done
# exemples traduits de la disquette anglaise (files/en/*.asm)
for n in hello gtest; do
  P=$(echo $n | tr a-z A-Z)
  cp files/en/$n.asm "$T/$P.ASM"
  $XA -I progs -o "$T/ref.bin" files/en/$n.asm
  (cd "$T" && python3 "$OLDPWD/tools/run_com.py" "$T" ASM.COM $n >/dev/null 2>&1) || true
  m=$(wc -c < "$T/ref.bin")
  if [ -f "$T/$P.COM" ] && cmp -s -n $m "$T/ref.bin" "$T/$P.COM"; then
    echo "identique : $P (files/en, $m octets)"; ok=$((ok+1))
  else
    echo "DIFFERENT : $P (files/en)"; ko=$((ko+1))
  fi
  rm -f "$T/$P.COM"
done
rm -rf "$T"
echo "$ok identiques, $ko différents"
[ $ko -eq 0 ]
