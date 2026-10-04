#!/bin/sh
# Construit CP/A :
#   build/cpa.rom      ROM de 16 Ko (sans disque)
#   build/cpa_sys.bin  système disque, chargé en RAM overlay $C000-$FFFF
#   build/boot.bin     secteurs d'amorçage Microdisc (3 x 256 octets)
#   build/progs/*.COM  programmes d'exemple
#   build/cpa.dsk      disquette amorçable (MFM_DISK, 2 faces, 42 pistes, 17 secteurs)
set -e
cd "$(dirname "$0")"
# assembleur : $XA, sinon tools/xa s'il existe, sinon xa dans le PATH
if [ -z "$XA" ]; then
  if [ -x tools/xa ]; then XA=tools/xa; else XA=xa; fi
fi
case "$XA" in
  */*) XA="$(cd "$(dirname "$XA")" && pwd)/$(basename "$XA")" ;;
esac
mkdir -p build/progs
python3 tools/gen_font.py src/font.s
python3 tools/gen_tables.py src/tables.s

cd src
$XA -o ../build/cpa.rom -l ../build/cpa.sym -e ../build/cpa.err cpa.s
$XA -DDISK -o ../build/cpa_sys.bin -l ../build/cpa_sys.sym -e ../build/cpa_sys.err cpa.s
cd ..
for f in build/cpa.rom build/cpa_sys.bin; do
  SIZE=$(wc -c < $f)
  if [ "$SIZE" -ne 16384 ]; then echo "Taille inattendue pour $f : $SIZE"; exit 1; fi
done
# le code du système disque doit s'arrêter avant ses zones de travail ($F670 : DO et PUT, puis $FD00)
END=$(grep -E " rom_end$" build/cpa_sys.sym | cut -d' ' -f1)
python3 -c "import sys; e=int('$END',16); print('Fin du code disque : %04X (marge %d octets)' % (e, 0xF670-e)); sys.exit(e>0xF670)"

cd boot
$XA -o ../build/boot.bin -e ../build/boot.err boot.s
cd ..
[ "$(wc -c < build/boot.bin)" -eq 768 ] || { echo "boot.bin doit faire 768 octets"; exit 1; }

for p in $(ls progs/*.s | grep -v _tab.s); do
  n=$(basename "$p" .s | tr a-z A-Z)
  (cd progs && $XA -o ../build/progs/$n.COM -e ../build/progs/$n.err $(basename "$p"))
done

# sources d'exemple pour ASM.COM
mkdir -p build/src
cp progs/hello.s build/src/HELLO.ASM
cp progs/gtest.s build/src/GTEST.ASM
cp progs/cpa.inc build/src/CPA.INC

python3 tools/mkdisk.py new build/cpa.dsk --boot build/boot.bin --system build/cpa_sys.bin \
  build/progs/*.COM build/src/* files/*
echo "OK : build/cpa.rom, build/cpa.dsk"
