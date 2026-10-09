#!/bin/sh
# Construit CP/A :
#   build/cpa.rom      ROM de 16 Ko (sans disque)
#   build/cpa_sys.bin  système disque, chargé en RAM overlay $C000-$FFFF
#   build/boot.bin     secteurs d'amorçage Microdisc (3 x 256 octets)
#   build/progs/*.COM  programmes d'exemple
#   build/cpa.dsk      disquette amorçable (MFM_DISK, 2 faces, 42 pistes, 17 secteurs)
#   build/cpa-logo.dsk, cpa-notes.dsk, cpa-asm.dsk, cpa-anim.dsk  disquettes par usage
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

# Options du système disque. CPLCMD : ESC complète aussi le premier mot
# par les commandes internes et les .COM / .BAT (~120 octets résidents) ;
# DISK_OPTS="" ./build.sh pour s'en passer.
DISK_OPTS=${DISK_OPTS--DCPLCMD}
cd src
$XA -o ../build/cpa.rom -l ../build/cpa.sym -e ../build/cpa.err cpa.s
$XA -DDISK $DISK_OPTS -o ../build/cpa_sys.bin -l ../build/cpa_sys.sym -e ../build/cpa_sys.err cpa.s
cd ..
for f in build/cpa.rom build/cpa_sys.bin; do
  SIZE=$(wc -c < $f)
  if [ "$SIZE" -ne 16384 ]; then echo "Taille inattendue pour $f : $SIZE"; exit 1; fi
done
# le code du système disque doit s'arrêter avant ses zones de travail ($F670 : DO et PUT, puis $FD00)
END=$(grep -E " rom_end$" build/cpa_sys.sym | cut -d' ' -f1)
python3 -c "import sys; e=int('$END',16); print('Fin du code disque : %04X (marge %d octets)' % (e, 0xF670-e)); sys.exit(e>0xF670)"
# la page $FF00 doit s'arrêter avant les vecteurs du 6502 ($FFFA)
FFEND=$(grep -E " ff_end$" build/cpa_sys.sym | cut -d' ' -f1)
python3 -c "import sys; e=int('$FFEND',16); print('Page FF00 : fin %04X (marge %d octets)' % (e, 0xFFFA-e)); sys.exit(e>0xFFFA)"

cd boot
$XA -o ../build/boot.bin -e ../build/boot.err boot.s
cd ..
[ "$(wc -c < build/boot.bin)" -eq 768 ] || { echo "boot.bin doit faire 768 octets"; exit 1; }

for p in $(ls progs/*.s | grep -v -e _tab.s -e _inc.s); do
  n=$(basename "$p" .s | tr a-z A-Z)
  (cd progs && $XA -o ../build/progs/$n.COM -e ../build/progs/$n.err $(basename "$p"))
done

# sources d'exemple pour ASM.COM
mkdir -p build/src
cp progs/hello.s build/src/HELLO.ASM
cp progs/gtest.s build/src/GTEST.ASM
cp progs/cpa.inc build/src/CPA.INC
cp progs/hires.inc build/src/HIRES.INC
cp progs/grx.inc build/src/GRX.INC
cp progs/anim.inc build/src/ANIM.INC

# commandes, applications et documentation protégées (R/O, visibles dans
# DIR comme sur une disquette CP/M) ; exemples modifiables (ASM HELLO doit
# pouvoir réécrire HELLO.COM, LOGO réécrire DEMO.LOG)
EXEMPLES="build/progs/HELLO.COM build/progs/GTEST.COM build/src/HELLO.ASM build/src/GTEST.ASM files/demo.log files/dessin.grx files/ecran.grx files/motifs.grx files/ardoise.grx files/edit.cfg"
PROTEGES=""
for f in build/progs/*.COM build/src/CPA.INC build/src/HIRES.INC build/src/GRX.INC build/src/ANIM.INC files/readme.txt; do
  case " $EXEMPLES " in *" $f "*) ;; *) PROTEGES="$PROTEGES $f" ;; esac
done
python3 tools/mkdisk.py new build/cpa.dsk --boot build/boot.bin --system build/cpa_sys.bin \
  --ro $PROTEGES --rw $EXEMPLES

# Disquettes par usage. Sur chacune : les commandes de base protégées et
# cachées de DIR (SYS), EDIT.CFG modifiable et caché, EDIT et l'outil de la
# disquette protégés et visibles, les exemples modifiables.
P=build/progs
BASE="$P/TYPE.COM $P/ERA.COM $P/REN.COM $P/SET.COM $P/STAT.COM $P/COPY.COM $P/HELP.COM
  $P/FORMAT.COM $P/DISKCOPY.COM $P/XDO.COM $P/EXPORT.COM $P/IMPORT.COM $P/USBDIR.COM
  $P/VOIR.COM"
theme() {   # theme IMAGE "visibles" "système en plus" "exemples"
  echo "== $1"
  python3 tools/mkdisk.py new "$1" --boot build/boot.bin --system build/cpa_sys.bin \
    --ro --sys $BASE $3 --rw files/edit.cfg --ro --dir $P/EDIT.COM $2 --rw $4 | tail -1
}
theme build/cpa-logo.dsk "$P/LOGO.COM $P/GRAPHER.COM" "" "files/demo.log files/dessin.grx files/ecran.grx files/motifs.grx files/ardoise.grx"
theme build/cpa-notes.dsk "" "" ""
theme build/cpa-asm.dsk "$P/ASM.COM $P/DEBUG.COM $P/HEX.COM $P/GRAPHER.COM build/src/CPA.INC build/src/HIRES.INC build/src/GRX.INC build/src/ANIM.INC" \
  "$P/MEM.COM $P/POKE.COM $P/GO.COM" \
  "$P/HELLO.COM $P/GTEST.COM build/src/HELLO.ASM build/src/GTEST.ASM"
# Animations : VOIR visible (il sort des commandes de base), GRAPHER et
# ASM avec les bibliothèques (GRAPHER ANIMS /A) ; animations fabriquées
# par tools/anim_demos.py et gardées dans files/anim/ (pas de Pillow ici)
BASE_SANS_VOIR=$(echo $BASE | sed "s|$P/VOIR.COM||")
BASE_TOUT=$BASE
BASE=$BASE_SANS_VOIR
theme build/cpa-anim.dsk "$P/VOIR.COM $P/GRAPHER.COM $P/ASM.COM" \
  "build/src/CPA.INC build/src/HIRES.INC build/src/GRX.INC build/src/ANIM.INC" \
  "files/anim/CUBE.ANI files/anim/BALLE.ANI files/anim/VAISSEAU.ANI files/anim/LOGO.HIZ files/anims.grx files/demo.bat"
BASE=$BASE_TOUT
echo "OK : build/cpa.rom, build/cpa.dsk, build/cpa-{logo,notes,asm,anim}.dsk"
