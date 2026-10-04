#!/bin/sh
# Installe l'atelier de construction et de test de CP/A sur Linux
# (Raspberry Pi OS, Debian, Ubuntu), dans le dépôt lui-même :
#   tools/xa          assembleur xa de l'OSDK
#   tools/pylib/      module Python py65 (6502 simulé, pour run_com.py)
#   tools/oricutron/  Oricutron avec le crochet de test (frappe simulée,
#                     vidage mémoire), sans toucher à un Oricutron existant
# Usage : ./tools/setup_linux.sh [dossier_roms]
#   dossier_roms : dossier roms/ d'un Oricutron existant, où se trouvent
#   basic11b.rom et microdis.rom (elles ne sont pas fournies avec les sources
#   d'Oricutron). Sans argument, le script les cherche dans le dossier personnel.
# Relançable : refait seulement ce qui manque.
set -e
ROMS=""
[ -n "$1" ] && ROMS=$(cd "$1" && pwd)
cd "$(dirname "$0")"
TOOLS=$(pwd)
ORIC_COMMIT=002279fce9fa756d1d63cdc40ae97939eb7de7ed

# 1. paquets du système (demande le mot de passe sudo)
PKGS="git build-essential cmake libsdl2-dev python3 python3-pip xvfb imagemagick"
MISSING=""
for p in $PKGS; do
  dpkg -s "$p" >/dev/null 2>&1 || MISSING="$MISSING $p"
done
if [ -n "$MISSING" ]; then
  echo "== Paquets à installer :$MISSING"
  SUDO=""; [ "$(id -u)" = 0 ] || SUDO=sudo
  $SUDO apt-get update
  $SUDO apt-get install -y $MISSING
fi

# 2. xa
if [ ! -x xa ]; then
  echo "== Compilation de xa"
  ./build_xa.sh
fi

# 3. py65, installé dans tools/pylib (pas dans le Python du système)
if [ ! -d pylib/py65 ]; then
  echo "== Installation de py65 dans tools/pylib"
  python3 -m pip install --quiet --target pylib py65
fi

# 4. Oricutron avec le crochet de test
if [ ! -x oricutron/Oricutron-sdl2 ]; then
  echo "== Compilation d'Oricutron (quelques minutes sur un Raspberry Pi)"
  rm -rf oricutron
  git clone -q https://github.com/pete-gordon/oricutron.git oricutron
  cd oricutron
  git checkout -q $ORIC_COMMIT
  git apply "$TOOLS/oricutron-testhook.patch"
  mkdir -p b && cd b
  cmake -DUSE_SDL2=ON .. >cmake.log
  make -j"$(nproc)" >make.log 2>&1 || { tail -20 make.log; exit 1; }
  cp Oricutron-sdl2 ..
  cd "$TOOLS"
fi

# 5. ROMs de l'Oric (BASIC 1.1 et Microdisc)
R=tools_roms_ok
for r in basic11b.rom microdis.rom; do
  [ -f oricutron/roms/$r ] && continue
  SRC=""
  if [ -n "$ROMS" ] && [ -f "$ROMS/$r" ]; then SRC="$ROMS/$r"
  else SRC=$(find "$HOME" -maxdepth 5 -name $r -not -path "$TOOLS/*" 2>/dev/null | head -1)
  fi
  if [ -n "$SRC" ]; then cp "$SRC" oricutron/roms/ && echo "== $r copiée depuis $SRC"
  else echo "!! $r introuvable : relancer avec le dossier roms d'un Oricutron existant"; R=""
  fi
done
[ -n "$R" ] || exit 1

echo "== Atelier prêt :"
echo "   ./build.sh                 construit build/cpa.rom et build/cpa.dsk"
echo "   tools/smoke_test.sh        vérifie la chaîne complète (construction + émulateur)"
echo "   tools/test_asm.sh          ASM.COM contre xa"
