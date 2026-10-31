#!/bin/sh
# Construit CP/A :
#   (build/cpa.rom, la ROM de 16 Ko, n'est plus construite : CLAUDE.md)
#   build/cpa_sys.bin  système disque, chargé en RAM overlay $C000-$FFFF
#   build/boot.bin     secteurs d'amorçage Microdisc (3 x 256 octets)
#   build/progs/*.COM  programmes d'exemple
#   build/cpa.dsk      disquette système amorçable (MFM_DISK, 2 faces, 80 pistes,
#                      17 secteurs) : tous les programmes sauf LOGO, aucun exemple
#   build/cpa-anim.dsk, cpa-logo.dsk, cpa-exemples.dsk, cpa-notes.dsk  par usage
#   build/cpa-projet.dsk  disquette vierge pour les projets (lecteur B:)
#   build/cpa-en.dsk, cpa-{anim,logo,examples,notes,project}-en.dsk
#                      les mêmes en anglais (messages, exemples traduits)
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
python3 tools/gen_logo_voc.py > /dev/null   # vocabulaire de LOGO (fr, en) et table de LOGOTR

# Options du système disque. CPLCMD : ESC complète aussi le premier mot
# par les commandes internes et les .COM / .BAT (~120 octets résidents) ;
# DISK_OPTS="" ./build.sh pour s'en passer.
DISK_OPTS=${DISK_OPTS--DCPLCMD}
# Système : textes (barre de menus, messages de la console) pris dans
# src/msg/fr ou src/msg/en ; disque en deux langues (cpa_sys.bin,
# cpa_sys_en.bin pour cpa-en.dsk) ; la ROM, projet à part, en français.
cd src
# ROM : plus construite ni étudiée (CLAUDE.md) ; build/cpa.rom reste la dernière faite
# $XA -I msg/fr -o ../build/cpa.rom -l ../build/cpa.sym -e ../build/cpa.err cpa.s
$XA -I msg/fr -DDISK $DISK_OPTS -o ../build/cpa_sys_all.bin -l ../build/cpa_sys.sym -e ../build/cpa_sys.err cpa.s
$XA -I msg/en -DDISK $DISK_OPTS -o ../build/cpa_sys_all_en.bin -l ../build/cpa_sys_en.sym -e ../build/cpa_sys_en.err cpa.s
cd ..
# banques de la fenêtre (src/bank.s) : l'image de 16 Ko est suivie de la
# banque IMG ; tools/mkbnk.py les sépare, pose la signature dans le système
# et écrit CPA.BNK (PUT et IMG), un par langue
mkdir -p build/progs-en
python3 tools/mkbnk.py build/cpa_sys_all.bin build/cpa_sys.sym build/cpa_sys.bin build/progs/CPA.BNK
python3 tools/mkbnk.py build/cpa_sys_all_en.bin build/cpa_sys_en.sym build/cpa_sys_en.bin build/progs-en/CPA.BNK > /dev/null
for f in build/cpa_sys.bin build/cpa_sys_en.bin; do
  SIZE=$(wc -c < $f)
  if [ "$SIZE" -ne 16384 ]; then echo "Taille inattendue pour $f : $SIZE"; exit 1; fi
done
for L in "" _en; do
  # le code du système disque doit s'arrêter avant ses zones de travail
  # (SYS_END : cartes d'allocation, puis DO et PUT en $F670, $FD00...)
  END=$(grep -E " rom_end$" build/cpa_sys$L.sym | cut -d' ' -f1)
  SEND=$(grep -E " SYS_END$" build/cpa_sys$L.sym | cut -d' ' -f1)
  python3 -c "import sys; e=int('$END',16); f=int('$SEND',16); print('Fin du code disque$L : %04X (marge %d octets avant %04X)' % (e, f-e, f)); sys.exit(e>f)"
  # fenêtre (src/win.s) : le code de PUT avant son tampon ($FA00), le code du
  # démarrage à froid (dans le tampon) avant les variables ($FD00)
  WEND=$(grep -E " win_put_end$" build/cpa_sys$L.sym | cut -d' ' -f1)
  CEND=$(grep -E " cold_end$" build/cpa_sys$L.sym | cut -d' ' -f1)
  python3 -c "import sys; w=int('$WEND',16); c=int('$CEND',16); print('Fenetre$L : PUT fin %04X (marge %d), demarrage fin %04X (marge %d)' % (w, 0xFA00-w, c, 0xFD00-c)); sys.exit(w>0xFA00 or c>0xFD00)"
  # la page $FF00 doit s'arrêter avant les vecteurs du 6502 ($FFFA)
  FFEND=$(grep -E " ff_end$" build/cpa_sys$L.sym | cut -d' ' -f1)
  python3 -c "import sys; e=int('$FFEND',16); print('Page FF00$L : fin %04X (marge %d octets)' % (e, 0xFFFA-e)); sys.exit(e>0xFFFA)"
done

cd boot
$XA -o ../build/boot.bin -e ../build/boot.err boot.s
cd ..
[ "$(wc -c < build/boot.bin)" -eq 768 ] || { echo "boot.bin doit faire 768 octets"; exit 1; }

# programmes : messages en français (progs/msg/fr) dans build/progs ; en
# anglais dans build/progs-en (progs/msg/en, sinon le français : programmes
# pas encore traduits)
mkdir -p build/progs-en
for p in $(ls progs/*.s | grep -v -e _tab.s -e _inc.s); do
  n=$(basename "$p" .s | tr a-z A-Z)
  (cd progs && $XA -I msg/fr -o ../build/progs/$n.COM -e ../build/progs/$n.err $(basename "$p"))
  (cd progs && $XA -I msg/en -I msg/fr -o ../build/progs-en/$n.COM -e ../build/progs-en/$n.err $(basename "$p"))
done

# sources d'exemple pour ASM.COM ; leur version anglaise (files/en/hello.asm,
# gtest.asm : commentaires et message traduits) donne les .COM de
# build/progs-en ; HELLO, au message déjà anglais, doit rester identique
mkdir -p build/src
cp progs/hello.s build/src/HELLO.ASM
cp progs/gtest.s build/src/GTEST.ASM
for n in hello gtest; do
  N=$(echo $n | tr a-z A-Z)
  $XA -I progs -o build/progs-en/$N.COM -e build/progs-en/$N.err files/en/$n.asm
done
cmp -s build/progs/HELLO.COM build/progs-en/HELLO.COM || { echo "files/en/hello.asm ne donne pas HELLO.COM"; exit 1; }
# bibliothèques : copies sans commentaires (2 à 4 fois plus petites ; la
# documentation reste dans progs/*.inc ; tools/test_inc.sh vérifie qu'elles
# s'assemblent comme les originaux)
# Les messages des bibliothèques (« ;#msg » : progs/msg/fr, en) y sont
# recopiés : build/src pour les disquettes françaises, build/src-en pour
# cpa-en.dsk.
mkdir -p build/src-en
for i in cpa hires grx anim arr fil spr oric; do
  I=$(echo $i | tr a-z A-Z)
  python3 tools/strip_inc.py progs/$i.inc build/src/$I.INC > /dev/null
  python3 tools/strip_inc.py progs/$i.inc build/src-en/$I.INC progs/msg/en > /dev/null
done
# marques ;@ des routines : GRXASM n'en recopie que les utiles (tools/mark_inc.py)
python3 tools/mark_inc.py build/src
python3 tools/mark_inc.py build/src-en > /dev/null

# Chaque disquette existe en français et en anglais : « disque IMAGE IMAGE_EN
# arguments de mkdisk » fait les deux. L'anglaise a le système, les programmes
# et les bibliothèques aux messages anglais (build/progs-en, build/src-en) et
# les exemples traduits, sous leurs noms anglais (files/en/noms.txt, appliqué
# par tools/en_files.py, qui refuse un exemple sans traduction).
python3 tools/en_files.py --verifie > /dev/null || { python3 tools/en_files.py --verifie; exit 1; }
disque() {   # disque IMAGE IMAGE_EN [--ro|--rw|--sys|--dir|fichiers]...
  fr=$1; en=$2; shift 2
  echo "== $fr, $en"
  python3 tools/mkdisk.py new "$fr" --boot build/boot.bin --system build/cpa_sys.bin "$@" | tail -1
  python3 tools/mkdisk.py new "$en" --boot build/boot.bin --system build/cpa_sys_en.bin \
    $(python3 tools/en_files.py "$@") | tail -1
  python3 tools/en_files.py --jumelles "$fr" "$en" | grep -v '^cpa' || true
  python3 tools/en_files.py --jumelles "$fr" "$en" > /dev/null || exit 1
}

P=build/progs
INCS="build/src/CPA.INC build/src/HIRES.INC build/src/GRX.INC build/src/ANIM.INC build/src/ARR.INC build/src/FIL.INC build/src/SPR.INC build/src/ORIC.INC"
GRX_EX="files/dessin.grx files/ecran.grx files/motifs.grx files/ardoise.grx files/fleches.grx
  files/serpent.grx files/scores.grx files/sprites.grx files/heros.spr files/carte.grx
  files/tuiles.spr files/defile.grx files/rotscrol.grx files/JEU.GRX"
ASM_EX="$P/HELLO.COM $P/GTEST.COM build/src/HELLO.ASM build/src/GTEST.ASM"

# Disquette système (cpa.dsk) : tous les programmes, sauf LOGO (il a sa
# disquette) et les exemples (disquette Exemples) ; HELP garde toutes ses
# rubriques. Tout est protégé (R/O). Cachés (SYS, montrés par DIRS) : les
# commandes de base, MEM/POKE/GO, les bibliothèques, EDIT.CFG (modifiable) ;
# DIR montre les applications, et un nouveau programme y apparaît de lui-même.
SYS_CACHES="$P/CPA.BNK $P/TYPE.COM $P/ERA.COM $P/REN.COM $P/SET.COM $P/STAT.COM $P/COPY.COM
  $P/FORMAT.COM $P/DISKCOPY.COM $P/XDO.COM $P/MEM.COM $P/POKE.COM $P/GO.COM files/usbcd.bat"
SYS_AILLEURS="$P/LOGO.COM $P/LOGOTR.COM $P/HELLO.COM $P/GTEST.COM"
SYS_VISIBLES=""
for f in $P/*.COM files/readme.txt; do
  case " $(echo $SYS_CACHES $SYS_AILLEURS) " in *" $f "*) ;; *) SYS_VISIBLES="$SYS_VISIBLES $f" ;; esac
done
disque build/cpa.dsk build/cpa-en.dsk --ro --sys $SYS_CACHES $INCS --rw files/edit.cfg \
  --ro --dir $SYS_VISIBLES

# Disquettes par usage : chacune démarre seule et porte ses outils. Les
# commandes de base, la clé USB, TERM et XFER y sont protégées et cachées
# (SYS), EDIT.CFG modifiable et caché, EDIT et l'outil de la disquette
# protégés et visibles, les exemples modifiables (ASM HELLO réécrit
# HELLO.COM, LOGO réécrit DEMO.LOG).
BASE="$P/CPA.BNK $P/TYPE.COM $P/ERA.COM $P/REN.COM $P/SET.COM $P/STAT.COM $P/COPY.COM $P/HELP.COM
  $P/FORMAT.COM $P/DISKCOPY.COM $P/XDO.COM $P/EXPORT.COM $P/IMPORT.COM $P/USBDIR.COM $P/USBMOUNT.COM
  $P/TERM.COM $P/XFER.COM $P/CMDER.COM files/usbcd.bat"
theme() {   # theme NOM NOM_EN "visibles" "cachés en plus" "exemples"
  disque build/cpa-$1.dsk build/cpa-$2-en.dsk --ro --sys $BASE $4 --rw files/edit.cfg \
    --ro --dir $P/EDIT.COM $3 --rw $5
}
# Animations : VOIR et VSYNC visibles, GRAPHER, GRXASM, ASM et les
# bibliothèques cachés (GRXASM ANIMS refait le programme) ; animations
# fabriquées par tools/anim_demos.py et gardées dans files/anim/ (pas de
# Pillow ici) ; DEMO enchaîne tout
theme anim anim "$P/VOIR.COM $P/VSYNC.COM" \
  "$P/GRAPHER.COM $P/GRXASM.COM $P/ASM.COM $P/EDSPRITE.COM $P/MKTAP.COM $INCS" \
  "files/anim/CUBE.ANI files/anim/BALLE.ANI files/anim/VAISSEAU.ANI files/anim/LOGO.HIZ files/anims.grx files/demo.bat"
# Logo : la plateforme LOGO seule
theme logo logo "$P/LOGO.COM $P/LOGOTR.COM" "$P/VOIR.COM" \
  "files/demo.log files/eliza.log files/eliza2.log files/tracarre.log files/trasinus.log files/trasinxx.log files/fleches.log"
# Exemples : ceux de GRAPHER et d'ASM, visibles ; leurs outils cachés
theme exemples examples "" \
  "$P/VOIR.COM $P/GRAPHER.COM $P/GRXASM.COM $P/EDSPRITE.COM $P/MKTAP.COM $P/ASM.COM $P/DEBUG.COM $P/HEX.COM $P/MEM.COM $P/POKE.COM $P/GO.COM $INCS" \
  "$GRX_EX $ASM_EX"
# Notes : écrire du texte (et l'envoyer)
theme notes notes "" "$P/VOIR.COM" ""
# disquette de projet, vierge : sans système (amorce et pistes du système
# vides), tout le reste pour les fichiers ; en B: à côté de cpa.dsk (même
# contenu sous son nom anglais)
echo "== build/cpa-projet.dsk, build/cpa-project-en.dsk"
python3 tools/mkdisk.py new build/cpa-projet.dsk | tail -1
cp build/cpa-projet.dsk build/cpa-project-en.dsk
echo "OK : build/cpa.dsk, cpa-{anim,logo,exemples,notes,projet}.dsk ;"
echo "     build/cpa-en.dsk, cpa-{anim,logo,examples,notes,project}-en.dsk"
