#!/bin/sh
# Lance Oricutron sans écran, tape des touches, vide la mémoire à une trame
# donnée, puis s'arrête.
#
#   tools/run_test.sh TOUCHES TRAME SORTIE [options oricutron...]
#
#   TOUCHES  texte tapé à partir de la trame ORIC_KEYS_AT (défaut 100) ;
#            codes spéciaux (écrire la chaîne avec $'...' en bash) :
#            \n Entrée  ~ DEL  | pause 3 s  \x1b ESC  \x01-\x04 flèches G D H B
#            \x05 FUNCT  \x1c préfixe CTRL (\x1cC = ^C)  \x06 bouton RESET (NMI)
#   TRAME    trame (1/50 s) du vidage mémoire ; l'émulateur s'arrête juste après
#   SORTIE   préfixe des résultats : SORTIE.mem (64 Ko, $0300-$03FF à zéro),
#            SORTIE.png (capture), SORTIE.log
#
# Variables :
#   DSK=fichier.dsk   démarre sur cette disquette (copiée : l'original ne change pas)
#   ORIC_ROM=cpa      démarre sur build/cpa.rom au lieu de la ROM BASIC 1.1
#   SHOW=1            montre la fenêtre (sinon écran virtuel Xvfb)
#   ORICUTRON=dossier Oricutron avec le crochet de test (défaut tools/oricutron)
#
# Exemples :
#   DSK=build/cpa.dsk tools/run_test.sh $'DIR\n' 600 /tmp/t && python3 tools/screen.py /tmp/t.mem
#   ORIC_ROM=cpa tools/run_test.sh $'VER\n' 300 /tmp/r
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
ORIC=${ORICUTRON:-$HERE/tools/oricutron}
KEYS="$1"; AT="$2"; OUT="$3"; shift 3
case "$OUT" in /*) ;; *) OUT="$(pwd)/$OUT" ;; esac
rm -f "$OUT.mem" "$OUT.png"

ROM=${ORIC_ROM:-basic11b}
[ "$ROM" = cpa ] && cp "$HERE/build/cpa.rom" "$ORIC/roms/cpa.rom"
if [ -n "$DSK" ]; then
  cp "$DSK" "$OUT.dsk"
  set -- -k microdisc -d "$OUT.dsk" "$@"
fi

cd "$ORIC"
printf "machine = atmos\natmosrom = 'roms/%s'\nrendermode = soft\ndiskautosave = yes\n" "$ROM" > oricutron.cfg

XPID=""
if [ -z "$SHOW" ]; then
  # écran virtuel : un numéro libre entre :90 et :99
  for n in 90 91 92 93 94 95 96 97 98 99; do
    [ -e /tmp/.X$n-lock ] || { D=:$n; break; }
  done
  Xvfb $D -screen 0 800x600x24 >/dev/null 2>&1 &
  XPID=$!
  sleep 0.5
  export DISPLAY=$D
fi

SDL_AUDIODRIVER=dummy ORIC_KEYS="$KEYS" ORIC_KEYS_AT=${ORIC_KEYS_AT:-100} \
  ORIC_DUMP_AT="$AT" ORIC_DUMP="$OUT.mem" \
  ./Oricutron-sdl2 -m atmos -w "$@" > "$OUT.log" 2>&1 &
PID=$!
i=0
while [ ! -f "$OUT.mem" ] && [ $i -lt 900 ]; do
  kill -0 $PID 2>/dev/null || break   # émulateur arrêté (ROM absente...)
  sleep 0.1; i=$((i+1))
done
sleep 0.3
command -v import >/dev/null && timeout 10 import -window root "$OUT.png" 2>/dev/null || true
kill -9 $PID 2>/dev/null || true
[ -n "$XPID" ] && kill $XPID 2>/dev/null || true
[ -f "$OUT.mem" ] || { echo "Pas de vidage mémoire (voir $OUT.log)"; exit 1; }
