#!/bin/sh
# Non-régression de LOGO.COM dans Oricutron (tools/run_test.sh).
#
# Les scénarios sont des fichiers .LOG (tools/logo_tests/*.log) copiés sur
# une disquette de test et lancés par CHARGE ; la sortie de LOGO est
# recueillie par PUT dans OUT.TXT, puis comparée aux fichiers .ref. Pour les
# dessins, on compare l'empreinte MD5 de l'image ($A000-$B3FF).
#
#   tools/test_logo.sh          compare aux références
#   REF=1 tools/test_logo.sh    réécrit les références (après vérification !)
#
# Remarques : après une dizaine de lignes, la console SPLIT attend une
# touche (pagination) : les scénarios tapent un espace avant chaque
# commande. Une touche tapée pendant un accès disque peut se perdre : les
# pauses (|, 3 s) laissent le temps aux chargements.
set -e
cd "$(dirname "$0")/.."
D=tools/logo_tests
T=$(mktemp -d)
cp build/cpa.dsk "$T/test.dsk"
for f in $D/*.log; do
  n=$(basename "$f" .log | tr a-z A-Z)
  python3 tools/mkdisk.py put "$T/test.dsk" "$f" "$n.LOG" >/dev/null
done
ko=0

# run NOM TOUCHES TRAMES : lance, garde OUT.TXT dans $T/NOM.out et la mémoire
run() {
  DSK="$T/test.dsk" ORIC_KEYS_AT=400 tools/run_test.sh "$2" "$3" "$T/$1" >/dev/null
  python3 tools/mkdisk.py get "$T/$1.dsk" OUT.TXT "$T/$1.raw" >/dev/null 2>&1 || : > "$T/$1.raw"
  tr -d '\r\032' < "$T/$1.raw" > "$T/$1.out"
}
# check NOM : compare la sortie texte à $D/NOM.ref
check() {
  if [ -n "$REF" ]; then cp "$T/$1.out" "$D/$1.ref"; echo "référence écrite : $1"
  elif diff "$D/$1.ref" "$T/$1.out" >"$T/$1.diff"; then echo "identique : $1"
  else echo "DIFFERENT : $1"; cat "$T/$1.diff"; ko=$((ko+1)); fi
}
# image NOM : empreinte de l'image du mode SPLIT
image() {
  python3 -c "import hashlib,sys; print(sys.argv[2], hashlib.md5(open(sys.argv[1],'rb').read()[0xA000:0xB400]).hexdigest())" "$T/$1.mem" "$1" >> "$T/images"
}

echo "== calculs, variables, procédures"
run calculs 'PUT OUT.TXT LOGO
|| charge "t1
|||||||| quitte
' 3000
check calculs

echo "== messages d'erreur"
run erreurs 'PUT OUT.TXT LOGO
|| charge "e1
| charge "e2
| charge "e3
| charge "e4
| charge "e5
| charge "e6
| charge "e7
||| charge "e8
| quitte
' 3400
check erreurs

echo "== messages d'erreur des nombres"
run erreurs2 'PUT OUT.TXT LOGO
|| charge "e9
| charge "e10
| charge "e11
| charge "e12
| charge "e13
| charge "e14
| quitte
' 2600
check erreurs2

echo "== nombres décimaux"
run decimaux 'PUT OUT.TXT LOGO
|| charge "t5
|||||||| quitte
' 3000
check decimaux

echo "== tortue et décimaux : cap fractionnaire, distances, précision"
run tortue_dec 'PUT OUT.TXT LOGO
|| charge "t6
|||||||||| charge "t7
|||||| quitte
' 4400
check tortue_dec

echo "== mots et listes"
run mots 'PUT OUT.TXT LOGO
|| charge "t8
|||||||||| quitte
' 3400
check mots

echo "== mots et listes : compactage du tas (environ 2 min)"
run endurance 'PUT OUT.TXT LOGO
|| charge "t9
||||||||||||||||||||||||||||||| quitte
' 6000
check endurance

echo "== messages d'erreur des mots et listes"
run erreurs3 'PUT OUT.TXT LOGO
|| charge "e15
| charge "e16
|| charge "e17
| charge "e18
| quitte
' 2400
check erreurs3

echo "== fonctions : RACINE, SIN, COS, ARCTAN, LN, EXP"
run maths 'PUT OUT.TXT LOGO
|| charge "t11
|||||||| charge "e19
|| charge "e20
|| charge "e21
| quitte
' 4200
check maths

echo "== fonctions de l'utilisateur : RENDS (environ 3 min)"
run rends 'PUT OUT.TXT LOGO
|| charge "t12
|||||||||||||||||||||||||||||||||||||||||| charge "e22
| charge "e23
| charge "e24
| charge "e25
| charge "e26
| quitte
' 9000
check rends

echo "== écran texte : ECRANTEXTE, ECRANMIXTE"
run ecran 'PUT OUT.TXT LOGO
|| charge "t13
||| charge "e27
| charge "e28
| ecranmixte
| ecris 1
| quitte
' 2600
check ecran

echo "== aller-retour avec EDIT : EDITE, Retour (environ 3 min)"
# PUT ne survit pas au passage par EDIT : on compare le texte de l'écran.
# Dans EDIT : une procédure tapée en tête, puis Fichier > Retour.
K=$(printf 'LOGO\n||pour carre\nrepete 4 [av 30 dr 90]\nfin\n|donne "l [a b c]\n|carre dr 45\n|ecrantexte\n|edite "essai\n||||||pour neuf\recris 99\rfin\r||\005||\004|\004|\004|\004|\004|\004||\r|||||||||||||| ecris :l\n| neuf\n| ecris cap\n| av 10\n|')
run edite "$K" 7900
python3 tools/screen.py "$T/edite.mem" | sed -n '2,13p' > "$T/edite.out"
check edite
run logonom 'LOGO demo
|||||| titres
' 1500
python3 tools/screen.py "$T/logonom.mem" | sed -n '18,25p' > "$T/logonom.out"
check logonom

echo "== lecture au clavier : LISLISTE, LISMOT, ASCII, CAR"
run lecture 'PUT OUT.TXT LOGO
|| charge "t10
|||bonjour  le [petit   monde]
||   deux mots  
||21 3
||a||z||
|| quitte
' 4600
check lecture

echo "== clavier : LISCAR, TOUCHE?, DONNE"
run clavier 'PUT OUT.TXT LOGO
|| charge "t3
||a||z||5|| charge "t4
|||q|| quitte
' 3200
check clavier

echo "== tortue"
run tortue 'PUT OUT.TXT LOGO
|| charge "demo
|| charge "t2
|||||||||| quitte
' 3600
check tortue
: > "$T/images"
run demo 'LOGO
|| charge "demo
|||| demo
' 4000
image demo
run dessin 'LOGO
|| charge "demo
|||| charge "t2
' 3600
image dessin
# l'image est la même après un passage par l'écran texte
run carre 'LOGO
|| repete 4 [av 40 dr 90]
' 1200
run carre_t 'LOGO
|| charge "t13
' 1500
image carre
image carre_t
if [ "$(sed -n 's/^carre //p' "$T/images")" != "$(sed -n 's/^carre_t //p' "$T/images")" ]
then echo "DIFFERENT : image changée par l'écran texte"; ko=$((ko+1))
else echo "identiques : image avant et après l'écran texte"; fi
grep -v '^carre' "$T/images" > "$T/images2"
if [ -n "$REF" ]; then cp "$T/images2" "$D/images.ref"; echo "référence écrite : images"
elif diff "$D/images.ref" "$T/images2"; then echo "identiques : images (DEMO, T2)"
else echo "DIFFERENT : images"; ko=$((ko+1)); fi

rm -rf "$T"
[ $ko -eq 0 ] && echo "LOGO : aucune différence" || echo "LOGO : $ko différence(s)"
[ $ko -eq 0 ]
