#!/bin/sh
# Compile Oricutron pour le web (Emscripten), avec le correctif de CP/A.
#
#   tools/web/build_web.sh SOURCES SORTIE
#
#   SOURCES  sources d'Oricutron, correctif tools/oricutron-testhook.patch appliqué
#   SORTIE   dossier produit : index.html, Oricutron.js, .wasm, .data, cpa.dsk...
#            à servir tel quel (GitHub Pages, ou python3 -m http.server)
# Il faut emcc (Emscripten) dans le PATH.
set -e
WEB=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$WEB/../.." && pwd)
SRC=$(cd "$1" && pwd)
mkdir -p "$2"; OUT=$(cd "$2" && pwd)
T=$(mktemp -d)
# données préchargées : images de l'interface (assets/), configuration (/)
mkdir -p "$T/assets"
cp -R "$SRC/images" "$T/assets/"
rm -f "$T/assets/images/"*.psd
cd "$SRC"
emcc -O2 -std=gnu99 -w \
  -DWWW -DCPA_WWW -DWWW_NO_MONITOR -DWWW_NO_PRAVETZ -DWWW_NO_ORIC1 \
  -D__SPECIFY_SDL_DIR__=1 -DAPP_NAME_FULL='"Oricutron 1.2 (CP/A)"' -DAPP_YEAR='"2015"' \
  -DVERSION_COPYRIGHTS='"Oricutron 1.2.0 2016 Peter Gordon"' \
  -sUSE_SDL=2 \
  6551.c 6551_com.c 6551_loopback.c 6551_modem.c gui.c render_gl.c render_null.c \
  render_sw.c render_sw8.c 6502.c 8912.c avi.c plugins/ch376/ch376.c disk.c \
  disk_pravetz.c font.c joystick.c keyboard.c machine.c main.c monitor.c \
  plugins/ch376/oric_ch376_plugin.c plugins/twilighte_board/oric_twilighte_board_plugin.c \
  snapshot.c system_sdl.c tape.c ula.c via.c filereq_sdl.c msgbox_sdl.c \
  -sASYNCIFY -sINITIAL_MEMORY=64mb -sFETCH -sFORCE_FILESYSTEM=1 -lidbfs.js \
  -sEXPORTED_RUNTIME_METHODS=ccall,FS,IDBFS,addRunDependency,removeRunDependency \
  --preload-file "$T/assets@/assets" --preload-file "$WEB/oricutron.cfg@/oricutron.cfg" \
  --shell-file "$WEB/shell.html" \
  -o "$OUT/index.html"
cp "$REPO/build/cpa.dsk" "$OUT/cpa.dsk"
cp "$WEB/manifest.json" "$WEB/icon.png" "$OUT/"
rm -rf "$T"
ls -l "$OUT"
