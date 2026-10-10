#!/bin/sh
# Non-régression de ASM.COM : chaque programme de progs/ est assemblé par
# ASM.COM (dans un 6502 simulé, tools/run_com.py, module Python py65) et
# comparé octet par octet avec le résultat de xa.
#   XA=chemin/vers/xa tools/test_asm.sh
set -e
cd "$(dirname "$0")/.."
XA=${XA:-tools/xa}
case "$XA" in */*) XA="$(cd "$(dirname "$XA")" && pwd)/$(basename "$XA")";; esac
T=$(mktemp -d)
cp progs/cpa.inc progs/hires.inc progs/anim.inc progs/*_tab.s progs/*_inc.s "$T/"
(cd progs && $XA -o "$T/ASM.COM" asm.s)
ok=0; ko=0
for p in hello copy gtest hex edit logo debug help set poke go mem stat xdo export import usbdir format diskcopy type era ren voir vsync grapher asm; do
  P=$(echo $p | tr a-z A-Z)
  cp progs/$p.s "$T/$P.ASM"
  (cd progs && $XA -o "$T/ref.bin" $p.s)
  (cd "$T" && python3 "$OLDPWD/tools/run_com.py" "$T" ASM.COM $p >/dev/null 2>&1) || true
  n=$(wc -c < "$T/ref.bin")
  if [ -f "$T/$P.COM" ] && cmp -s -n $n "$T/ref.bin" "$T/$P.COM"; then
    echo "identique : $P ($n octets)"; ok=$((ok+1))
  else
    echo "DIFFERENT : $P"; ko=$((ko+1))
  fi
  [ "$P" = ASM ] || rm -f "$T/$P.COM"
done
rm -rf "$T"
echo "$ok identiques, $ko différents"
[ $ko -eq 0 ]
