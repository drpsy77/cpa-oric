#!/bin/sh
# Compile l'assembleur xa de l'OSDK dans tools/xa (macOS ou Linux).
#   ./tools/build_xa.sh      puis      XA=tools/xa ./build.sh
set -e
cd "$(dirname "$0")"
TMP=$(mktemp -d)
git clone -q --depth 1 https://github.com/nekoniaow/OSDK.git "$TMP/osdk"
# common.cpp n'utilise curses que pour getch() : un remplaçant suffit
mkdir -p "$TMP/inc"
printf '#include <stdio.h>\nstatic inline int getch(void){return getchar();}\n' > "$TMP/inc/curses.h"
cd "$TMP/osdk"
c++ -O2 -w -I"$TMP/inc" -Ixa/includes -Icommon/includes xa/sources/*.cpp common/sources/*.cpp -o "$OLDPWD/xa"
rm -rf "$TMP"
echo "OK : tools/xa"
