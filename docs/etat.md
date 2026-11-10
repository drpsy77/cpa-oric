# CP/A disquette — état

Système « à la CP/M » pour Oric Atmos muni d'un LOCI (ou dans un émulateur), chargé depuis
une disquette au format Microdisc dans les 16 Ko de RAM overlay, et enrichi par des
programmes `.COM` plutôt que par du code résident.
Usages visés : développer sur l'Oric lui-même, gérer des fichiers et des données, communiquer
(réseau par le LOCI). À lire avec `docs/architecture.md`. La suite prévue est dans `docs/suite.md`, les réserves
de place dans `docs/place.md` : à lire quand la demande les concerne.

## 1. Ce qui existe (version 0.9)

**Système** : code résident `$C000-$F3C4` en français (`$F398` en anglais), **marge 515
octets** (559 en anglais) jusqu'à `$F5C8`, où commencent les cartes d'allocation
des 4 lecteurs (168 octets, puis les tampons de DO en `$F670`) ; fenêtre `$F7C0-$FCFF`, une
banque à la fois, lue dans `CPA.BNK` quand elle sert : PUT (marge 2 octets) ou IMG (GSAVE,
GLOAD, SAVE ; marge 4) avant le tampon de PUT de 768 octets, ou GFX (les tracés du SPLIT,
997 octets jusqu'à `$FBFF`, marge 91 : pas de tracé pendant un PUT) ; code du démarrage à
froid dans le tampon, marge 565 (`docs/systeme.md` § 6) ; page `$FF00-$FFEF`, marge 10 octets (table des touches de
l'édition de ligne, encres des menus). `./build.sh` affiche les marges.

- console : pause en fin d'écran, menus déroulants (FUNCT), voyants `A`/`a`, `P` et `R`/`r`,
  couleurs et pagination (`PAPER`, `INK`, `PAGE`) ;
- port série et console à distance (`src/serial.s`, option `SERIE`) : service sous l'IRQ
  de 50 Hz, le Mac tape et lit l'écran par le modem du LOCI (`REMOTE`, démon
  `tools/remote.py`), caractères redéfinis compris (police du mode texte : sprites,
  tuiles, EDSPRITE) ; rappel automatique si le démon se tait 10 s (relancé, liaison
  tombée) ; touche tapée sur l'Oric signalée au démon (la vitrine s'arrête) ; PUNCH,
  READER, fonction 117 (`docs/console-distance.md`) ;
- clavier : CTRL-H à CTRL-K distincts des flèches (28-31), CTRL-ESPACE (0), SHIFT et CTRL
  avec les flèches (`$F0-$F7`) ; mêmes touches dans EDIT, HEX, CMDER et la ligne de commande
  (`docs/manuel.md`, « Les mêmes touches partout ») ;
- lecture de ligne (BDOS 10) : édition, historique, complétion par TAB ou ESC des noms de fichiers
  et, en début de ligne, des commandes (sur les lecteurs où elles seraient cherchées) ;
- fichiers CP/M 2.2 (séquentiel, accès direct, attributs R/O et SYS), lecteurs A: à D: ;
  changer de disquette demande un CTRL-C ; option de construction `CHGDSK`, absente par
  défaut (331 octets résidents) : disquette changée reconnue avant toute écriture qui prend
  ou rend des blocs (sommes du répertoire, `docs/systeme.md` § 3) ;
  disquettes de 2 faces de 80 pistes (images de 1 Mo, 658 Ko pour les fichiers, numéros de
  bloc sur 16 bits, étiquette du format en entrée 0 ; `docs/systeme.md` § 3) ; celles de 42
  pistes sont refusées (`BDOS: not a CP/A 80-track disk`) et se convertissent sur le PC
  (`tools/mkdisk.py conv`) ;
- programmes et scripts cherchés sur le lecteur du script (ou le courant), puis A: à D: ;
  scripts `.BAT` (DO, `$1`-`$9`, appel de script à script par XDO, `AUTO.BAT` au démarrage
  à froid) ; CHAIN (BDOS 47) ; PUT (sortie d'une commande dans un fichier) ;
- imprimante Centronics (LIST, BDOS 5, CTRL-P) ;
- graphisme SPLIT (BDOS 115 ; GSAVE par `NOM.$$$`), son AY (BDOS 116) ; HIRES plein écran et écran texte (LORES)
  laissés aux programmes, avec retour assuré par le démarrage à chaud ;
- reprise après plantage (BRK, RESET) ; un RESET pendant le transfert d'un secteur attend la
  fin du secteur (un secteur coupé, du répertoire par exemple, serait illisible) ; un
  contrôleur de disquettes qui ne répond plus donne `BDOS: disk I/O error`, jamais un accès
  déclaré bon (`tools/test_fdc.py`).

Détail du fonctionnement interne : `docs/systeme.md`. Mode d'emploi : `docs/manuel.md`.

**Programmes**

| Programme | Octets | Rôle | Documentation |
|---|---:|---|---|
| HELP | 13 029 | aide par rubriques (textes compressés) | `manuel.md` |
| TYPE, ERA, REN, SET, STAT, COPY | 177 à 1 033 | fichiers | `manuel.md` |
| FORMAT, DISKCOPY | 1 828, 1 694 | disquettes, avec un seul lecteur | `manuel.md` |
| CMDER | 18 025 | gestionnaire de fichiers plein écran, deux colonnes, clé USB (supports, répertoires seuls, renommer, effacer, dupliquer, monter ; nom des disquettes dans les en-têtes) ; fixe le répertoire courant de la clé | `cmder.md` |
| EXPORT, IMPORT, USBDIR | 3 046, 3 381, 2 961 | échange avec la clé USB du LOCI, relatif au répertoire courant de CP/A (`0:CPA.CWD`) ; jokers ; `USBDIR /S` : supports ; `USBCD rep` (`USBDIR /C`) : change de répertoire, `USBCD` seul : CMDER | `manuel.md`, `usb.md` |
| USBMOUNT | 4 032 | monte, montre, éjecte les images de disquette (B: à D:) et la cassette de la clé ; `/B` : démarre le BASIC 1.1 du LOCI sur la cassette | `manuel.md`, `usb.md` |
| MKTAP | 4 079 | fichier `.TAP` pour l'Oric sous BASIC (`CLOAD""`) : un bloc par fichier, démarrage automatique (bloc `/R` en `$0503` au plus tôt) ou chargeur BASIC ; programme BASIC en texte (`.BAS`) codé comme la ROM 1.1 | `manuel.md`, `oric-basic.md` |
| TERM | 2 007 | terminal série (modem WiFi du LOCI, ACIA `$0380` ; Oricutron `$031C`) ; `TERM hote` compose d'abord (fichier `HOSTS`) | `manuel.md` |
| XFER | 3 179 | envoi et réception de fichiers par le modem (XMODEM-CRC), serveur `tools/xfer_server.py` ; `@hote` compose d'abord (fichier `HOSTS`) | `manuel.md` |
| REMOTE | 2 127 | console à distance : appelle le démon du Mac (`HOSTS`, port 2324), active, coupe, état | `manuel.md`, `console-distance.md` |
| XDO | 1 351 | appel de script à script | `manuel.md` |
| EDIT | 8 704 | éditeur de texte (coupure aux mots, à 38 caractères, ou ligne entière qui défile en largeur) | `manuel.md` |
| HEX | 3 840 | éditeur hexadécimal | `manuel.md` |
| EDSPRITE | 8 967 | éditeur plein écran des sprites et caractères `.SPR` de GRAPHER (grille à trois états, liste, aperçu réel, codes hexa, transformations, animation) | `edsprite.md` |
| ASM | 7 322 | assembleur 6502 (identique à xa sur nos sources) ; `/S` : symboles, `/E` : source effacée, `/T` : fichier écrit nommé `NOM.TAP` ; `#include` cherchés sur A: à D: ; `#lib` : routines de `GRX.LIB` reliées | `manuel.md` |
| DEBUG | 6 490 | moniteur, désassembleur, pas à pas | `manuel.md` |
| MEM, POKE, GO | 674, 254, 221 | mémoire | `manuel.md` |
| LOGO | 19 108 | Logo (français, ou anglais sur les disquettes anglaises : 18 899) : tortue, décimaux, listes, son, écran texte | `logo.md` |
| LOGOTR | 4 429 | traduit les primitives d'un `.LOG` d'une langue à l'autre | `logo.md` |
| GRAPHER, GRXASM | 18 175, 17 085 | langage de dessin et de jeux (`.GRX`) : interpréteur, traducteur en assembleur (`/C` : jusqu'au `.COM` ; `/O` : `.TAP` pour un Oric seul, sans CP/A ni BASIC, sur le socle `ORIC.INC` ; aucun contrôle à l'exécution, tableaux à adresse fixe, seules routines utiles des bibliothèques, prises précompilées dans `GRX.LIB` quand elle est là) ; fichiers de données, sprites (`.SPR`) en mode texte et dans l'image ; rectangles (copie d'un tableau vers l'écran, défilement, rotation), écriture verticale ; cartes de tuiles (`TILESET`, `TMAP`, `TILE`, dessins par `TFONT`) ; tableaux à deux dimensions en (colonne, ligne), comme l'écran ; `PRINT` à plusieurs éléments | `grapher.md` |
| VOIR, VSYNC | 3 353, 744 | images, animations ; calage du top sur le balayage | `manuel.md` |
| HELLO, GTEST | 88, 156 | exemples d'assembleur | — |

Disquettes, une par usage, chacune amorçable et munie de ses outils (un seul lecteur
suffit) : `cpa.dsk` (système : tous les programmes sauf LOGO, toute l'aide, aucun exemple ;
358 Ko libres), `cpa-anim.dsk` (la démonstration, 318 Ko libres), `cpa-logo.dsk` (LOGO seul,
510 Ko libres, pour la plateforme LOGO à venir), `cpa-exemples.dsk` (exemples de GRAPHER et
d'ASM, 324 Ko libres), `cpa-notes.dsk` (écrire, 558 Ko libres) ; `CPA.BNK` (2 560 octets,
caché) sur chacune, et `cpa-projet.dsk` (vierge,
sans système : le travail en B:, 658 Ko) ; chacune a sa jumelle anglaise (`cpa-en.dsk`,
`cpa-examples-en.dsk`... `cpa-project-en.dsk`) ; contenu dans `docs/manuel.md`.

**Mesure** : 1 569 points de fonction IFPUG et 360 points d'algorithmes ; détail, lignes,
octets et documentation dans `docs/points-de-fonction.md`.

**Sur le vrai matériel** : versions anglaise et française essayées en entier sur Oric
Atmos + LOCI (ASM compris, deux lecteurs, clé USB débranchée à chaud), sans un plantage ni
un redémarrage ; la stabilité est un argument du README. Les deux défauts trouvés dans les
cas limites (RESET pendant DISKCOPY : accès déclarés bons sans réponse du contrôleur ; EDIT
qui ne rouvrait pas un texte de plus de ~31 Ko qu'il venait d'écrire) sont corrigés, à
revérifier. Ce qui reste à vérifier est dans `docs/essais-materiel.md`, à lire seulement
quand on en a besoin.

## 2. Vers la version 1.0

D'après `docs/vision.md`. Ce qui n'est pas dans cette liste attend (`docs/suite.md`).

| Objectif de la 1.0 | État |
|---|---|
| Atelier créatif : sprites et caractères | fait (EDSPRITE, `SPR.INC`) |
| Atelier créatif : tuiles | fait (`TILESET`, `TMAP`, `TILE`, `TFONT`) |
| Atelier créatif : dessin assisté | à spécifier |
| GRAPHER plateforme : phases d'un jeu (`RUN`) | à décider |
| GRAPHER plateforme : son | à spécifier |
| GRAPHER plateforme : un jeu complet fait sur l'Oric (le rogue-like) | à écrire |
| Pont vers l'Oric de base : `.TAP` autonome | fait (`MKTAP`, `GRXASM /O`) |
| Pont vers l'Oric de base : `CASSETTE.COM` | décidé, pas fait |
| Extérieur : terminal et transfert par le modem du LOCI | fait (TERM, XFER) |
| Vérifiée sur le vrai matériel | en attente (`docs/essais-materiel.md`) |

Revue du projet et lots en cours : `docs/revue.md`.

## 3. Contraintes à garder en tête

- Tout ajout résident se justifie ; le reste va en `.COM`. Les estimations ont souvent été
  dépassées du simple au double : prévoir large.
- Les interruptions sont coupées pendant les accès disque (une touche peut être perdue, le
  compteur 50 Hz retarde).
- Le contrat d'interface (`docs/architecture.md`) est commun avec la version ROM
  (`docs/projet-rom.md`).
- La plupart des possesseurs d'un vrai lecteur n'en ont qu'un : une commande disque doit
  marcher avec un seul lecteur dès que c'est possible, et les commandes de base doivent
  pouvoir être sur chaque disquette.
