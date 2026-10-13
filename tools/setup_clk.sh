#!/bin/sh
# Installe le banc d'essai Clock Signal (Linux) dans tools/clk/ :
#   tools/clk/clkheadless   Clock Signal sans écran, piloté par un script
#                           (frappe, mesure du temps émulé, écran texte)
#   tools/clk/roms/Oric/    ROMs attendues par Clock Signal
# Clock Signal simule la rotation du disque et le chargement de la tête du
# Microdisc, ce que ne font ni Oricutron ni le LOCI : c'est lui qui mesure la
# vitesse des accès disque d'un vrai lecteur (entrelacement, attentes).
# Clock Signal est pris au commit 50e3b4d (12 octobre 2026), qui corrige la
# sélection des lecteurs B: à D: du Microdisc (défaut signalé par Pierre,
# corrigé par Thomas Harte, PR #1900). Deux correctifs, dans l'ordre :
#   tools/clk-4lecteurs.patch  quatre lecteurs utilisables (une disquette
#       insérée va dans le premier lecteur vide, ou dans celui demandé), et
#       interruption du Microdisc de nouveau masquée (50e3b4d ne démarre plus
#       aucune disquette Microdisc) ; aussi pour l'application Mac
#       (tools/build_clk_mac.sh) ;
#   tools/clk-banc.patch       le banc (harness/headless.cpp), et la mémoire
#       de l'Oric lisible par lui.
# Usage : ./tools/setup_clk.sh   (après tools/setup_linux.sh, dont il reprend
#         les paquets et les ROMs d'Oricutron)
# Exemple :
#   printf 'waitprompt\nrun 4\ncmd COPY LOGO.COM LOG2.COM\nscreen\n' > /tmp/s.txt
#   cp build/cpa.dsk /tmp/c.dsk
#   tools/clk/clkheadless /tmp/c.dsk tools/clk/roms /tmp/s.txt
#   (« insert /tmp/b.dsk » dans le script met une disquette en B:)
set -e
cd "$(dirname "$0")"
TOOLS=$(pwd)
CLK_COMMIT=50e3b4d9327c211d14eb9dcca5ccc2b8ef5f8786

MISSING=""
for p in cmake zlib1g-dev libgl-dev libsdl2-dev; do
  dpkg -s "$p" >/dev/null 2>&1 || MISSING="$MISSING $p"
done
if [ -n "$MISSING" ]; then
  echo "!! Paquets manquants :$MISSING"
  echo "   sudo apt-get install -y$MISSING"
  exit 1
fi

if [ ! -x clk/clkheadless ]; then
  echo "== Compilation de Clock Signal (long : une vingtaine de minutes sur un Raspberry Pi)"
  rm -rf clk/src
  mkdir -p clk
  git clone -q https://github.com/TomHarte/CLK.git clk/src
  cd clk/src
  git checkout -q $CLK_COMMIT
  git apply "$TOOLS/clk-4lecteurs.patch"
  git apply "$TOOLS/clk-banc.patch"
  mkdir -p b && cd b
  cmake -DCLK_UI=SDL -DCMAKE_BUILD_TYPE=Release .. >cmake.log
  make -j"$(nproc)" clkheadless >make.log 2>&1 || { tail -20 make.log; exit 1; }
  cp clkheadless "$TOOLS/clk/"
  cd "$TOOLS"
fi

# ROMs : celles d'Oricutron, sous les noms de Clock Signal. Sa ROM de
# couleurs n'est pas fournie : un fichier vide de 128 octets suffit au banc,
# qui ne lit que la mémoire (l'image n'est pas affichée).
mkdir -p clk/roms/Oric
for pair in basic11b.rom:basic11.rom microdis.rom:microdisc.rom; do
  src=${pair%%:*}; dst=${pair##*:}
  [ -f clk/roms/Oric/$dst ] && continue
  if [ -f oricutron/roms/$src ]; then cp oricutron/roms/$src clk/roms/Oric/$dst
  else echo "!! oricutron/roms/$src introuvable : lancer d'abord tools/setup_linux.sh"; exit 1
  fi
done
[ -f clk/roms/Oric/colour.rom ] || head -c 128 /dev/zero > clk/roms/Oric/colour.rom

echo "== Banc Clock Signal prêt : tools/clk/clkheadless IMAGE tools/clk/roms SCRIPT"
