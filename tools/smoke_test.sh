#!/bin/sh
# Vérifie que l'atelier fonctionne de bout en bout : construction, puis
# démarrage de la disquette et de la ROM dans Oricutron, lecture de l'écran.
set -e
NL='
'
cd "$(dirname "$0")/.."
T=$(mktemp -d)
./build.sh
echo "== Disquette : DIR"
# la disquette met environ 6 s à démarrer : frappe à la trame 400
DSK=build/cpa.dsk ORIC_KEYS_AT=400 tools/run_test.sh "DIR$NL" 600 "$T/d"
python3 tools/screen.py "$T/d.mem" > "$T/d.txt"
head -12 "$T/d.txt"
grep -q "HELP" "$T/d.txt" || { echo "ECHEC : DIR"; exit 1; }
echo "== Imprimante : CTRL-P puis ECHO (printer_out.txt d'Oricutron)"
rm -f tools/oricutron/printer_out.txt
DSK=build/cpa.dsk ORIC_KEYS_AT=400 tools/run_test.sh "$(printf '\034pecho imprime\n|\034pecho pas imprime\n|')" 900 "$T/p"
cat tools/oricutron/printer_out.txt
grep -q "IMPRIME" tools/oricutron/printer_out.txt && ! grep -q "PAS" tools/oricutron/printer_out.txt || { echo "ECHEC : imprimante"; exit 1; }
echo "== ROM : VER"
ORIC_ROM=cpa tools/run_test.sh "VER$NL" 300 "$T/r"
python3 tools/screen.py "$T/r.mem" > "$T/r.txt"
head -8 "$T/r.txt"
grep -qi "A>VER" "$T/r.txt" || { echo "ECHEC : ROM"; exit 1; }
rm -rf "$T"
echo "OK : l'atelier fonctionne"
