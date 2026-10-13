#!/bin/sh
# Construit sur le Mac une application Clock Signal à quatre lecteurs pour
# l'Oric (tools/clk-4lecteurs.patch) : le panneau Fichier > Insérer propose
# le lecteur (premier vide, A: à D:), et une disquette glissée sur la fenêtre
# va dans le premier lecteur vide (A: est remplacé si les quatre sont pleins).
# Contient aussi le rétablissement de l'interruption du Microdisc, sans
# lequel la version 50e3b4d ne démarre aucune disquette.
# Il faut Xcode (l'application complète, pas seulement les outils en ligne de
# commande). Tout reste dans tools/clk-mac/ (ignoré par git).
# Usage : ./tools/build_clk_mac.sh
# Résultat : tools/clk-mac/Clock Signal.app (signée pour cet ordinateur).
# Les ROMs sont celles de l'application Clock Signal déjà installée (même
# identifiant) ; sinon elle les demande au premier lancement.
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
