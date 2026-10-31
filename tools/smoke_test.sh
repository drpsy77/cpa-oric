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
echo "== Deux disquettes : B:, GRXASM CARTE /C (bibliothèques et CPA.INC sur A:)"
cp build/cpa-projet.dsk "$T/p.dsk"
python3 tools/mkdisk.py put "$T/p.dsk" files/carte.grx CARTE.GRX >/dev/null
python3 tools/mkdisk.py put "$T/p.dsk" files/tuiles.spr TUILES.SPR >/dev/null
ORIC_WARP=1 DSK=build/cpa.dsk DSKB="$T/p.dsk" ORIC_KEYS_AT=400 \
  tools/run_test.sh "B:${NL}GRXASM CARTE /C$NL" 12000 "$T/c"
python3 tools/mkdisk.py ls "$T/c.b.dsk" | head -3
python3 tools/mkdisk.py ls "$T/c.b.dsk" | grep -q "^CARTE   .COM" && \
  ! python3 tools/mkdisk.py ls "$T/c.b.dsk" | grep -q "^CARTE   .ASM" || { echo "ECHEC : GRXASM /C"; exit 1; }
echo "== Deux disquettes anglaises : B:, GRXASM MAP /C (cpa-en.dsk sur A:)"
cp build/cpa-project-en.dsk "$T/pe.dsk"
python3 tools/mkdisk.py put "$T/pe.dsk" files/en/map.grx MAP.GRX >/dev/null
python3 tools/mkdisk.py put "$T/pe.dsk" files/tuiles.spr TILES.SPR >/dev/null
ORIC_WARP=1 DSK=build/cpa-en.dsk DSKB="$T/pe.dsk" ORIC_KEYS_AT=400 \
  tools/run_test.sh "B:${NL}GRXASM MAP /C$NL" 12000 "$T/e"
python3 tools/mkdisk.py ls "$T/e.b.dsk" | head -3
python3 tools/mkdisk.py ls "$T/e.b.dsk" | grep -q "^MAP     .COM" && \
  ! python3 tools/mkdisk.py ls "$T/e.b.dsk" | grep -q "^MAP     .ASM" || { echo "ECHEC : GRXASM /C (anglais)"; exit 1; }
echo "== Fin de disquette : COPY d'un fichier de 640 Ko (blocs 2 à 330) de B: vers C:,"
echo "   après DIR d'une disquette sans étiquette du format en D:"
python3 - "$T" <<'FIN'
import sys
sys.path.insert(0, "tools")
import mkdisk as M
T = sys.argv[1]
d = M.Disk()
d.format_dir()
d.write_file("GROS.BIN", bytes((i * 7 + (i >> 11)) & 0xFF for i in range(320 * 2048)))
d.save(T + "/gros.dsk")
d = M.Disk()
d.format_dir()
d.put_entry(0, b"\xe5" * 32)            # sans étiquette : refusée
d.save(T + "/sans.dsk")
FIN
ORIC_WARP=1 DSK=build/cpa.dsk DSKB="$T/gros.dsk" DSKC=build/cpa-projet.dsk DSKD="$T/sans.dsk" \
  ORIC_KEYS_AT=400 tools/run_test.sh "dir d:${NL}copy b:gros.bin c:$NL" 12000 "$T/g"
python3 tools/screen.py "$T/g.mem" > "$T/g.txt"
sed -n 5,11p "$T/g.txt"
python3 tools/mkdisk.py check "$T/g.c.dsk" | tail -1
python3 tools/mkdisk.py get "$T/gros.dsk" GROS.BIN "$T/g1.bin" >/dev/null
python3 tools/mkdisk.py get "$T/g.c.dsk" GROS.BIN "$T/g2.bin" >/dev/null
cmp -s "$T/g1.bin" "$T/g2.bin" && python3 tools/mkdisk.py check "$T/g.c.dsk" >/dev/null || \
  { echo "ECHEC : fin de disquette"; exit 1; }
grep -q "not a CP/A 80-track disk" "$T/g.txt" || { echo "ECHEC : disquette sans etiquette"; exit 1; }
echo "== ROM : VER"
ORIC_ROM=cpa tools/run_test.sh "VER$NL" 300 "$T/r"
python3 tools/screen.py "$T/r.mem" > "$T/r.txt"
head -8 "$T/r.txt"
grep -qi "A>VER" "$T/r.txt" || { echo "ECHEC : ROM"; exit 1; }
rm -rf "$T"
echo "OK : l'atelier fonctionne"
