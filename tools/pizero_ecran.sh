#!/bin/sh
# Écran de l'Oric sur la console d'un Raspberry Pi Zero : lance le serveur X
# sur le terminal courant (tty1), sans bureau ni gestionnaire de fenêtres, avec
# la fenêtre de la console à distance en plein écran (tools/remote_tk.py).
# F10 dans la fenêtre : on revient à la console texte.
#
#   tools/pizero_ecran.sh [options de remote_tk.py]
#
# Variables :
#   DEMON=http://hote:8040   démon à joindre (défaut http://localhost:8040)
#   FAUX=1                   lance aussi tools/faux_demon.py (mire d'essai) sur
#                            le Pi Zero, en attendant le vrai démon
#   FAUX_ARGS="..."          ses arguments (ex. "--periode 3 a.mem b.mem")
#   OPTIONS="..."            options de remote_tk.py (défaut --sans-boutons)
#
# Lancement automatique au démarrage (console tty1 en connexion automatique,
# raspi-config : System Options > Boot / Auto Login > Console Autologin), à
# la fin de ~/.bash_profile :
#   if [ "$(tty)" = /dev/tty1 ] && [ -z "$DISPLAY" ]; then
#     ~/cpa-oric/tools/pizero_ecran.sh
#   fi
# Paquets (Raspberry Pi OS Lite) :
#   sudo apt install --no-install-recommends xserver-xorg xinit \
#        x11-xserver-utils python3-tk fonts-dejavu-core
# Détail : docs/console-distance.md § 9.4.

HERE=$(cd "$(dirname "$0")" && pwd)

if [ "$1" = "--dans-x" ]; then
  # --- partie lancée par xinit, dans le serveur X ---
  shift
  xset s off s noblank -dpms 2>/dev/null     # pas de mise en veille de l'écran
  FPID=""
  if [ -n "$FAUX" ]; then
    # shellcheck disable=SC2086
    python3 "$HERE/faux_demon.py" $FAUX_ARGS >/tmp/faux_demon.log 2>&1 &
    FPID=$!
    sleep 1
  fi
  # relancée si elle s'arrête sur une erreur ; F10 (code 0) : fin
  while :; do
    # shellcheck disable=SC2086
    python3 "$HERE/remote_tk.py" --plein-ecran --demon "${DEMON:-http://localhost:8040}" \
      ${OPTIONS:---sans-boutons} "$@" && break
    sleep 2
  done
  [ -n "$FPID" ] && kill "$FPID"
  exit 0
fi

# --- lancement du serveur X sur le terminal courant ---
command -v xinit >/dev/null || { echo "xinit manque : voir l'en-tete de $0"; exit 1; }
python3 -c "import tkinter" 2>/dev/null || { echo "python3-tk manque : voir l'en-tete de $0"; exit 1; }
VT=${XDG_VTNR:-$(tty | sed -n 's|^/dev/tty\([0-9]*\)$|\1|p')}
[ -n "$VT" ] || { echo "a lancer depuis une console (tty1), pas par ssh"; exit 1; }
exec xinit "$0" --dans-x "$@" -- :0 "vt$VT" -keeptty -nolisten tcp -nocursor -quiet
