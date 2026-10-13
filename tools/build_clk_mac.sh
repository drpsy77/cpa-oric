#!/bin/sh
# Construit sur le Mac une application Clock Signal à quatre lecteurs pour
# l'Oric (tools/clk-4lecteurs.patch) : le panneau Fichier > Insérer propose
# le lecteur (premier vide, A: à D:), et une disquette glissée sur la fenêtre
# va dans le premier lecteur vide (A: est remplacé si les quatre sont pleins).
# Le panneau Insérer s'ouvre dans le dossier de la disquette de démarrage.
# Contient aussi le rétablissement de l'interruption du Microdisc, sans
# lequel la version 50e3b4d ne démarre aucune disquette.
# Il faut Xcode (l'application complète, pas seulement les outils en ligne de
# commande). Tout reste dans tools/clk-mac/ (ignoré par git).
# Résultat : tools/clk-mac/Clock Signal.app (signée pour cet ordinateur).
# ROMs de l'Oric (basic11.rom, microdisc.rom ; colour.rom facultative) : rangées dans
# l'application construite. Le script les cherche, dans l'ordre, dans le
# dossier donné en argument, dans l'application Clock Signal installée
# (/Applications), dans les dossiers de ROMs de Clock Signal (Bibliothèque),
# puis dans les ROMs d'Oricutron de l'atelier (basic11b.rom, microdis.rom).
# Usage : ./tools/build_clk_mac.sh [dossier_roms]
set -e
cd "$(dirname "$0")"
TOOLS=$(pwd)
CLK_COMMIT=50e3b4d9327c211d14eb9dcca5ccc2b8ef5f8786

command -v xcodebuild >/dev/null || { echo "!! xcodebuild introuvable : installer Xcode"; exit 1; }
mkdir -p clk-mac
if [ ! -d clk-mac/src/.git ]; then
  echo "== Téléchargement de Clock Signal"
  git clone -q https://github.com/TomHarte/CLK.git clk-mac/src
fi
cd clk-mac/src
git fetch -q origin
git checkout -q -f $CLK_COMMIT
git clean -qfd
git apply "$TOOLS/clk-4lecteurs.patch"

# ROMs rangées dans l'application (dossier ROMImages/Oric des sources)
DEST=ROMImages/Oric
CANDS="${1:-}
/Applications/Clock Signal.app/Contents/Resources/ROMImages/Oric
$HOME/Library/Containers/TH.Clock-Signal/Data/Library/Application Support/ROMImages/Oric
$HOME/Library/Application Support/ROMImages/Oric
$TOOLS/oricutron/roms"
for pair in basic11.rom:basic11b.rom microdisc.rom:microdis.rom colour.rom:colour.rom; do
  want=${pair%%:*}; alt=${pair##*:}
  found=""
  echo "$CANDS" | while IFS= read -r d; do
    [ -n "$d" ] || continue
    for n in "$want" "$alt"; do
      if [ -f "$d/$n" ]; then echo "$d/$n"; exit 0; fi
    done
  done > /tmp/clk_rom_$$ || true
  found=$(head -1 /tmp/clk_rom_$$); rm -f /tmp/clk_rom_$$
  if [ -n "$found" ]; then
    cp "$found" "$DEST/$want"; echo "== $want <- $found"
  elif [ "$want" = colour.rom ]; then
    echo "== colour.rom absente : facultative (Clock Signal calcule alors les couleurs lui-même)"
  else
    echo "!! $want introuvable : l'application le demandera (glisser le fichier"
    echo "   dans sa fenêtre des ROMs manquantes), ou relancer avec le dossier qui le contient"
  fi
done
cd OSBindings/Mac
echo "== Compilation (quelques minutes ; journal : tools/clk-mac/build.log)"
xcodebuild -quiet -scheme "Clock Signal" -configuration Release \
  -derivedDataPath "$TOOLS/clk-mac/dd" CODE_SIGN_IDENTITY=- \
  > "$TOOLS/clk-mac/build.log" 2>&1 || { tail -30 "$TOOLS/clk-mac/build.log"; exit 1; }
APP=$(find "$TOOLS/clk-mac/dd" -name "Clock Signal.app" -type d | head -1)
[ -n "$APP" ] || { echo "!! application introuvable après la compilation"; exit 1; }
rm -rf "$TOOLS/clk-mac/Clock Signal.app"
cp -R "$APP" "$TOOLS/clk-mac/"
echo "== Prêt : open \"$TOOLS/clk-mac/Clock Signal.app\""
