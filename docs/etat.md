# CP/A disquette — état et suite

Système « à la CP/M » pour Oric Atmos muni d'un LOCI (ou dans un émulateur), chargé depuis
une disquette au format Microdisc dans les 16 Ko de RAM overlay, et enrichi par des
programmes `.COM` plutôt que par du code résident.
Usages visés : développer sur l'Oric lui-même, gérer des fichiers et des données, communiquer
(réseau par le LOCI). À lire avec `docs/architecture.md`.

## 1. Ce qui existe (version 0.9)

**Système** : code résident `$C000-$F3A7` en français (`$F37B` en anglais), **marge 544
octets** (588 en anglais) jusqu'à `$F5C8`, où commencent les cartes d'allocation
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
| HELP | 12 922 | aide par rubriques (textes compressés) | `manuel.md` |
| TYPE, ERA, REN, SET, STAT, COPY | 177 à 1 033 | fichiers | `manuel.md` |
| FORMAT, DISKCOPY | 1 828, 1 694 | disquettes, avec un seul lecteur | `manuel.md` |
| CMDER | 18 025 | gestionnaire de fichiers plein écran, deux colonnes, clé USB (supports, répertoires seuls, renommer, effacer, dupliquer, monter ; nom des disquettes dans les en-têtes) ; fixe le répertoire courant de la clé | `cmder.md` |
| EXPORT, IMPORT, USBDIR | 3 046, 3 381, 2 961 | échange avec la clé USB du LOCI, relatif au répertoire courant de CP/A (`0:CPA.CWD`) ; jokers ; `USBDIR /S` : supports ; `USBCD rep` (`USBDIR /C`) : change de répertoire, `USBCD` seul : CMDER | `manuel.md`, `usb.md` |
| USBMOUNT | 4 032 | monte, montre, éjecte les images de disquette (B: à D:) et la cassette de la clé ; `/B` : démarre le BASIC 1.1 du LOCI sur la cassette | `manuel.md`, `usb.md` |
| MKTAP | 4 079 | fichier `.TAP` pour l'Oric sous BASIC (`CLOAD""`) : un bloc par fichier, démarrage automatique (bloc `/R` en `$0503` au plus tôt) ou chargeur BASIC ; programme BASIC en texte (`.BAS`) codé comme la ROM 1.1 | `manuel.md`, `oric-basic.md` |
| TERM | 2 007 | terminal série (modem WiFi du LOCI, ACIA `$0380` ; Oricutron `$031C`) ; `TERM hote` compose d'abord (fichier `HOSTS`) | `manuel.md` |
| XFER | 3 179 | envoi et réception de fichiers par le modem (XMODEM-CRC), serveur `tools/xfer_server.py` ; `@hote` compose d'abord (fichier `HOSTS`) | `manuel.md` |
| REMOTE | 1 966 | console à distance : appelle le démon du Mac (`HOSTS`, port 2324), active, coupe, état | `manuel.md`, `console-distance.md` |
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
398 Ko libres), `cpa-anim.dsk` (la démonstration, 356 Ko libres), `cpa-logo.dsk` (LOGO seul,
512 Ko libres, pour la plateforme LOGO à venir), `cpa-exemples.dsk` (exemples de GRAPHER et
d'ASM, 362 Ko libres), `cpa-notes.dsk` (écrire, 560 Ko libres) ; `CPA.BNK` (2 560 octets,
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

## 2. Suite prévue (par priorité)

Ordre fixé d'après `docs/vision.md` : créer, développer et compiler, publier, échanger.

**Prochains développements** : la liste fixée par Pierre est faite : `GRXASM NOM /O`
(25/10/2026) ; la clé USB depuis CP/A, niveau 1, en trois lots (27-28/10/2026,
`docs/usb.md`) ; les programmes BASIC en texte (`.BAS`) codés par MKTAP (28/10/2026). Suite
du point 3 ci-dessous : `CASSETTE.COM` (décidé) ; le reste de la liste garde son ordre.
Fait (01/11/2026) : le pilote série du BIOS et la console à distance (point 4), lots 1 à 3
et la page web (lot 4, 02/11/2026) (`docs/console-distance.md`).

**Fait (lot 1, 07/11/2026)** : sprites dans l'image (HIRES, SPLIT) de GRAPHER, `HSHOW k S$ n
col y` et `HHIDE k` (`docs/grapher.md` § 7.1) : `.SPR` de genre 0, décor gardé par emplacement
(128 octets chacun, réservés au premier `HSHOW`), x par octets, y au point près ; traduits
par GRXASM. Essais : `hi_spr.grx`, `e_hspr*.grx` ; dans Oricutron, `DUN.SPR` devant le
château de LOGO. Coût : GRAPHER +414 octets (9 blocs), GRXASM +83 ; les vérifications de
l'interprété sont retirées des copies de `SPR.INC` (`;[ ;]`), qui rapetisse (15 297
octets), comme `GRX.LIB` (32 174). Plus tard : placement au point près (décalages). Corrigé en passant : un programme traduit
qui faisait `GRAB` sans `PASTE` plantait (`g_grab` continue dans `g_paste`, non recopiée :
marque `;>`, de même `h_lvon`).

**Prochaine tâche : vidéo LOGO** (plan approuvé par Pierre) : fabriquée sur le banc
(Phosphoric natif, `--video` AVI avec le son, frappe par `--type-keys`), montage par ffmpeg
(longues frappes accélérées × 3-4, sous-titres courts en français) ; une première version
de 3-4 min soumise à Pierre. Programmes **tapés puis exécutés** (graphisme, interactivité,
variables) :
1. Château (`files/dchateau.log`, de Pierre) : `CRENEAU`, `DRAPEAU`, `TOUR` tapés, `TOUR`
   essayée à deux échelles, puis `CHATEAU`.
2. Le chevalier : sortie de LOGO (l'image reste en SPLIT), `CHEVAL.GRX` tapé dans EDIT,
   lancé : `DUN.SPR` traverse devant les tours (flèches, ou seul).
3. Le même en assembleur : `GRXASM CHEVAL /C`, ASM, `CHEVAL`.
4. Forêt : `ARBRE` (`files/demo.log`) tapé, composition `FORET` (arbres à plusieurs
   échelles et places, `HASARD`, sol, lune par `POLY`), `SAUVEIMAGE "FORET`.
5. Traceur : `CHARGE "TRASINUS`, puis `F` seul retapé (x·sin x) et relancé.
6. `VOIR FORET.IMG` : la forêt revient.
7. Facultatif : `LABYRINT.GRX` de Pierre (sur sa clé LOCI, `files/`) en finale.

**Ensuite** : nouvelle revue complète du projet (demandée par Pierre le 07/11/2026 : sources,
outils, docs, disquettes) et proposition de nettoyage de ce qui est obsolète. Puis :
avec un seul lecteur, demander la disquette système quand `CPA.BNK` de `A:` manque ou n'a pas
la signature du système (brouillon : 67 octets ; changement de disquette du banc à réparer
d'abord).

1. **Atelier créatif**
   - Fait dans GRAPHER : sprites en mode texte (`SPRITES`, `SPOOL`, `SSHOW`, `SHIDE`,
     bibliothèque `SPR.INC` ; `docs/grapher.md` § 7.1, § 10.1), rectangles (`PASTE`, `GRAB`,
     `SCROLH`, `SCROLV`, `ROTH`, `ROTV`, `PRINTV`, `ECHOV`, `SPCV` : § 7.2), tuiles
     (`TILESET`, `TMAP`, `TILE`, `TFONT` : § 7.3). EDSPRITE (24/10/2026) : l'éditeur des
     `.SPR` sur l'Oric (`docs/edsprite.md`) ; `tools/mkspr.py` les fait aussi sur le PC.
   - Reste : les caractères animés au 50 Hz (§ 16) ; un **dessin assisté** (`.COM`, plus
     précis que la tortue de LOGO : points, traits, formes, remplissage, couleurs par
     attributs, vers `.HIR` / `.HIZ`), à spécifier.
2. **GRAPHER, plateforme de développement** : phases d'un jeu (`RUN`, à décider :
   `docs/grapher.md` § 17). Les programmes traduits sont petits (seules routines utiles des
   bibliothèques : 1,5 à 6,4 Ko pour les exemples) et rapides (tableaux à adresse fixe).
   - Gros programme envisagé par Pierre (24/10/2026, rien codé) : un **rogue-like** (sprites,
     niveaux tirés au hasard, une dizaine de monstres, armes, butin). Estimation : 500 à
     550 lignes, 12 à 15 Ko de `.GRX` ; tables des monstres et des objets dans des fichiers
     de données (`LOAD`), ~3 Ko de tableaux. Trop juste en interprété (~17 Ko pour texte et
     tableaux), à l'aise traduit : `.COM` de 20 à 23 Ko, ~15 Ko de tableaux libres,
     `.ASM` de ~130 Ko pendant l'assemblage. Bon cas d'essai pour la limite de 20 Ko et pour
     `RUN` : la génération d'un niveau, programme à part, écrit le niveau dans des fichiers
     de données que le jeu relit.
   - **Son** (décidé par Pierre, rien codé) : GRAPHER n'a aucune commande de son (seul le
     bip d'un `INPUT` refusé, `rz_bip` d'`ARR.INC`). Commandes à spécifier avec Pierre
     avant tout code (notes, bruit, durées, attente, son en cours ; s'inspirer de LOGO sans
     sa lourdeur, § 2 point 6). Interprété et traduit par la fonction 116 du BDOS ; avec
     `GRXASM /O`, `snd.s` (~600 octets) rejoint le socle `ORIC.INC` (`docs/oric-basic.md`
     § 4 ; aujourd'hui un bip seulement). Place : GRAPHER a 663 octets libres dans son
     dernier bloc (§ 3).
   - Fait (04/11/2026) : **bibliothèques précompilées** (`GRX.LIB`, `docs/grapher.md` § 12
     et § 15). `tools/mk_lib.py` (lancé par `build.sh`) assemble les sept bibliothèques des
     programmes traduits, routine par routine, avec leurs relogements ; GRXASM, s'il trouve
     `GRX.LIB`, n'y lit que les besoins et les noms et termine `NOM.ASM` par une ligne
     `#lib "GRX.LIB",...` qu'ASM relie. Même `.COM` / `.TAP`, octet par octet, que par les
     `.INC` (`tools/test_lib.sh` : tous les tests de GRAPHER et les exemples, CP/A et `/O`).
     Mesuré dans le 6502 simulé (instructions) : GRXASM 2 à 5 fois moins (`CARTE` : 2,2
     millions au lieu de 5,9 ; `LO_TILE` : 1,3 au lieu de 4,8), ASM 2 à 2,5 fois moins
     (`CARTE` : 3,7 au lieu de 8,9) ; `NOM.ASM` ne contient plus que le programme.
     `GRX.LIB` fait 32 Ko (les sept `.INC` : 70 Ko) ; les `.INC` restent sur les disquettes
     (choix de Pierre : repli quand `GRX.LIB` manque, et pour l'assembleur écrit à la main).
     Prix : ASM +1,2 Ko (toujours 4 blocs), GRXASM +0,7 Ko (9 blocs au lieu de 8), 36 Ko de
     moins sur chaque disquette qui porte GRXASM. À minuter sur l'Oric (§ essais).
3. **Publier vers l'Oric de base** (`docs/oric-basic.md`) : `MKTAP.COM` et `tools/mktap.py`
   faits (`.TAP` à plusieurs blocs, démarrage automatique, chargeur BASIC tokenisé quand il y
   a plusieurs blocs ; essayés sous BASIC 1.1 dans Oricutron, `tools/test_mktap.sh`).
   - Fait (25/10/2026) : **`GRXASM NOM /O`**, un programme GRAPHER traduit en `.TAP`
     autonome pour un Oric seul (Atmos, Oric-1), sur le socle `ORIC.INC` qui remplace
     `CPA.INC` (routines de CP/A recopiées, aucun appel à la ROM), en une commande (ASM
     `/T`) ; fichiers lus recopiés dans le programme ; `SPLIT` et écritures refusés ; essayé
     sous BASIC 1.1 dans Oricutron (`tools/test_oric.sh`, exemples dans `build/tap/`).
     `docs/grapher.md` § 12.1, `docs/oric-basic.md` § 3 et 4. Avec lui : les vérifications de
     l'interpréteur retirées des copies d'`ARR.INC` (programmes traduits jusqu'à 4 % plus
     petits), les tailles constantes de `DIM` vérifiées à la traduction, MKTAP qui refuse un
     bloc `/R` avant `$0503`. Décidé, pas encore fait : SPLIT dans `ORIC.INC`, le son quand
     GRAPHER en aura.
   - Fait (28/10/2026) : les **`.BAS`** : MKTAP code un programme BASIC écrit dans EDIT
     comme la ROM 1.1 quand on le tape (minuscules mises en majuscules hors du texte, ligne
     de plus de 78 caractères acceptée avec un avertissement), en `$0501`, lancé par `/R` ;
     codage comparé à la ROM elle-même (`tools/test_bas.py`) et au programme tapé dans
     Oricutron (`docs/oric-basic.md` § 2). Plus tard : le sens inverse (`.TAP` vers texte).
   - Suite : `CASSETTE.COM` (décidé).
   - Plus tard : la boîte à outils appelée par `!` depuis le BASIC (`docs/oric-basic.md`
     § 5). Écartée : la traduction de GRAPHER en BASIC (§ 6).
   - **La clé USB et le LOCI depuis CP/A** (CMDER seul écran interactif : répertoire
     courant propre à CP/A, supports, répertoires seuls, renommer, effacer, dupliquer,
     monter ; en ligne : `USBDIR /S`, USBMOUNT pour disquettes et cassette) : spécification,
     maquettes et lots dans `docs/usb.md` (API du LOCI et configuration du menu en XRAM lues
     dans `archives/`, non versionnées). Fait (lot 1, 27/10/2026) : répertoire courant
     propre à CP/A (`0:CPA.CWD`, clé renumérotée retrouvée d'après sa description), chemins
     relatifs, jokers, `USBDIR /S`, supports et répertoires seuls dans CMDER, `USBCD.BAT`.
     Fait (lot 2, 27/10/2026) : USBMOUNT (disquettes B: à D:, cassette, `/B` pour le
     BASIC ; configuration du menu du LOCI tenue à jour ; `lmnt_inc.s`). Fait (lot 3,
     28/10/2026) : CMDER renomme, efface, duplique et monte sur la clé ; noms des disquettes
     dans les en-têtes ; CMDER passe à 9 blocs. Niveau 2 (un répertoire de la clé
     comme lecteur) : après les banques de la fenêtre (§ 3 ; lots 1 et 2 faits).
   - L'équivalent de `CSAVE` est `CASSETTE.COM` (décidé, `docs/oric-basic.md` § 2). Sous
     CP/A, la ROM est remplacée par la RAM overlay : réécrire les routines cassette (timing
     à essayer sur un vrai magnétophone) ou basculer un moment sur la ROM.
4. **Réseau par le LOCI** (matériel : `docs/loci-modem-wifi.md`). La liaison marche dans les
   deux sens : Oric, LOCI (firmware 0.3.98 de diagnostic, `tools/loci-acia-diag/`), Pico W,
   WiFi, `nc` sur le Mac, avec `TERM /E`. `TERM.COM` fait (scrute l'ACIA lui-même, sans le
   BIOS ; CR, LF seul et CR LF reçus vont tous à la ligne). `XFER.COM` fait (30/10/2026) :
   envoi et réception d'un fichier en XMODEM-CRC, serveur `tools/xfer_server.py` (Mac ou
   Pi), réception par `NOM.$$$`, `/T` (fins de ligne, texte du Mac passé en ASCII :
   accents et cédille retirés, `œ` -> `oe`, `æ` -> `ae`) ; essayé dans Oricutron
   (`tools/test_xfer.sh` : 40 Ko, `/T`, refus, ESC, erreurs simulées) et sur le vrai Oric
   (30/10/2026, sauf les accents) ; TERM et XFER sur la bibliothèque `acia_inc.s`. TERM
   affiche par la fonction 2 du BDOS : `PUT NOM TERM` capture une session entière.
   Fait (01/11/2026, lot 1 de la console à distance) : le fichier `HOSTS` (une ligne
   `nom adresse[:port]` par hôte, sur chaque disquette amorçable, caché et modifiable) et
   l'appel du modem par les programmes (`ac_dial` d'`acia_inc.s` : `AT`, sinon `+++` et
   `ATH0`, puis `ATDT-adresse:port`) : `TERM mac`, `XFER R fic @mac` ; essayé dans
   Oricutron (`tools/test_xfer.sh`), à essayer sur le vrai Oric. Mesure sur le vrai Oric
   (01/11/2026) : réception de 7,8 Ko en 5 à 10 s ; envoi en 27 s, par à-coups : le Pico W
   retient l'envoi par moments, et `ac_txw` abandonnait au bout de 0,3 s (octet perdu, bloc
   redemandé) ; il attend maintenant 5 s, à remesurer. Décidé, pas encore fait :
   plusieurs fichiers (jokers). Possible, pas demandé (le débit actuel suffit à Pierre) :
   **XMODEM-1K** (blocs de 1 Ko, en-tête STX, option « K » de la ligne de commande du
   serveur pour rester compatible, CRC par table de 512 octets construite au démarrage ;
   tout dans `XFER.COM` et `xfer_server.py`, rien de résident ; tampon de 1 Ko après la fin
   du programme ; ~8 fois moins d'allers-retours).
   - **Le tampon est hors de l'Oric** : le LOCI ne remplit son tampon de 32 octets que s'il
     a de la place, le Pico W attend que l'USB accepte avant d'écrire et ne rouvre la
     fenêtre TCP que quand son tampon se vide (`docs/loci-modem-wifi.md`, « Contrôle de
     flux »). Un Oric occupé (défilement, disque, interruptions coupées) ne perd rien : ni
     interruption ni tampon circulaire côté Oric. Vaut pour le LOCI seulement ; un vrai 6551
     (Oricutron `$031C`, carte série) perd un octet si on tarde.
   - Décidé par Pierre : **console à distance** (le Mac tape et lit à la place du clavier et
     de l'écran : essais sur le vrai Oric pilotés comme `tools/run_test.sh`, texte collé dans
     EDIT). Elle demande le pilote dans le BIOS : elle doit survivre aux programmes.
   - **Console à distance** (`docs/console-distance.md`, schéma animé
     `docs/console-distance.html`) : fait (lot 3, 01/11/2026). Pilote résident
     (`src/serial.s`, 660 octets avec ses crochets : plus que les 500 prévus ; marge du
     système alors 46 octets), fonction 117 du BDOS, PUNCH / READER définis (ajouts au contrat),
     `REMOTE.COM`, refus de TERM et XFER pendant la console, démon `tools/remote.py` (écho
     rapide, texte collé au rythme du programme, ligne de commande `touches`, `coller`,
     `ecran`, `attendre`), `tools/test_remote.sh` (Oricutron) ; la fenêtre tkinter
     (`tools/remote_tk.py`) marche avec le démon. Fait (lot 4, 02/11/2026) : la page
     web (`tools/remote.html`, servie par le démon sur `GET /` : ordinateur et
     téléphone ; rendu identique à la fenêtre, clavier, bouton RETURN, Coller, RESET),
     essayée avec le faux démon et sur le vrai Oric (démon du Mac). Fait aussi
     (02/11/2026) : la **vitrine** (`tools/vitrine.py`, `docs/console-distance.md`
     § 9.5 : CP/A montré en boucle, scènes au hasard, `MOSAIQUE.GRX` et `HORLOGE.GRX`
     en LORES, pause quand quelqu'un tape) et les **spectateurs** (`--spectateurs` :
     lecture seule pour une passerelle qui publie la page, § 9.6 : Apache sur le VPS de
     Pierre, WireGuard jusqu'à la maison) ; essayés dans Oricutron. Fait (03/11/2026) :
     `tools/passerelle.py` prépare les fichiers de la passerelle (WireGuard des deux
     côtés, clés comprises ; Apache en lecture seule ; services du démon et de la
     vitrine) ; spectateurs comptés (ligne d'état de la page) et plafonnés
     (503 au-delà de 40) ; appel de l'Oric refusé depuis le tunnel. **En service**
     (03/11/2026, installé par Pierre) : `https://cycleamen.fr/cpa/` (VPS de Pierre,
     Apache, `cpa-oric.conf` dans `conf-enabled/`) ; démon et vitrine en services
     systemd sur le **Pi 400** (pas simon : temps de réponse), tunnel `10.77.0.1` ↔
     `10.77.0.2`. Les comptes diffèrent d'une machine à l'autre : `User=` et chemins des
     services à vérifier sur la machine du démon. Un ancien démon resté lancé (simon,
     ou à la main sur le Pi 400) prend l'Oric ou les ports : un seul démon à la fois.
     **Machine appelée** : interchangeable (`docs/console-distance.md` § 1). En service :
     un émulateur sans système sur Raspberry Pi 3B+ (fondé sur Phosphoric, LOCI émulé,
     WiFi du Pi), à la place du vrai Oric, arrêté (régulateur 5 V qui chauffe sans hub
     alimenté, `docs/loci-modem-wifi.md`, « Sans Oric »). Un vrai Oric, un Oric mieux
     équipé ou un Neo6502 peut reprendre sa place sans rien changer côté Pi 400.
     Fait (04/11/2026) : **police transmise** (`$FD 'C' n`, lignes 28-75 du pilote =
     `$B400-$BB7F`, § 4 « Police » de `console-distance.md` ; pilote +65 octets, démon
     `2026-11-04.1`) : sprites, tuiles et EDSPRITE vus par la page et la fenêtre ; essai
     `sprites` de `tools/test_remote.sh`. **Vitrine plus vive** : une scène de spectacle
     (HORLOGE, MOSAIQUE, EDIT, DEBUG, CMDER, EDSPRITE sur `DUN.SPR`), deux commandes,
     et ainsi de suite, moins d'une seconde entre deux ; CMDER efface parfois un des deux
     `.GRX`, retapé ensuite dans EDIT ; française ou anglaise selon le système
     (`MOSAIC.GRX`, `CLOCK.GRX` en anglais).
     **Vitrine commentée** : chaque étape dit ce qui se passe à côté du voyant de la
     page (`POST /commentaire`, démon `2026-11-05.1`, `console-distance.md` § 9.1 et
     9.5) ; essayée avec le faux démon. **Rappel automatique** (`console-distance.md`
     § 4, démon `2026-11-05.2`) : après `REMOTE hote`, 10 s sans rien recevoir (démon
     relancé, liaison ou WiFi tombés), le pilote raccroche et recompose sous l'IRQ, toutes
     les 30 s jusqu'à la réponse ; `REMOTE OFF` l'arrête ; fonction 117 op 4 (ajout au
     contrat). Une touche tapée sur le clavier de l'Oric est signalée au démon (bit 6 de
     la trame `S`), qui refuse aussitôt les touches de la vitrine (409) : elle s'arrête,
     et reprend 30 s après la dernière touche (120 avant). Essayés dans Oricutron
     (`tools/test_remote.sh` : `rappel`, `clavier`, `rappel_off`).
     **Sur le vrai Oric** (01/11/2026) : démon sur simon, un Raspberry Pi Zero autonome
     (`10.0.0.39`, port 2324 pour l'Oric, 8040 en HTTP ; lancé au démarrage, fenêtre
     plein écran) ; Pico en `10.0.0.2` avec le firmware `tools/pico-modem/` (Nagle
     gardé). Claude joint simon par le lien avec le Mac de Pierre : il tape, lit l'écran
     (`/ecran`), le journal (`/journal`) et la version (`/version`) ; vérification du
     pilote chargé : `DEBUG TYPE`, `D DD91`. Mesures : écho 0,25 à 0,33 s ; 22 à 27
     lignes en 1,5 à 1,8 s (~750 octets/s) ; `VER` sur un écran plein 3,1 à 3,6 s.
     Trame `S` lente après une commande (1,1 à 1,5 s, mesuré le 01/11 à 23 h 12) : pas
     reproduite après un redémarrage de l'Oric et un nouvel appel (01/11, 23 h 30 ; 25
     `VER` et 30 touches sans effet) : écho et `S` à 0,2 s de médiane, après une commande
     comme au repos. Le pilote ne fait rien de long après une commande (`VER` : deux
     lignes ; ni disque ni attente dans le CCP et la lecture de ligne). Reste, sans lien
     avec les commandes, environ un échange sur dix retardé de 1 à 2 s : signature d'un
     paquet perdu sur le WiFi et renvoyé par la pile TCP du Pico (lwIP, délai de renvoi
     d'une seconde au moins) ; à regarder seulement si cela gêne (réglage du firmware).
     Plafonds du pilote par IRQ selon le port (02/11/2026, 37 octets résidents) :
     LOCI 16 octets reçus, 64 émis (6551 : 4 et 24, comme avant), réglables par `DEBUG`
     (`docs/console-distance.md` § 4). Avec le firmware du Pico corrigé (il lisait un octet
     de l'USB par tour de boucle : ~650 octets/s au plus vers le WiFi), mesuré sur le vrai
     Oric, démon sur le Mac : écho 0,21 s, 27 lignes en 0,4 s (~3 Ko/s, le plafond de 64
     octets par IRQ ; 1,0 s avec les anciens plafonds), `VER` sur un écran plein 0,8 à
     0,9 s (3,1 à 3,6 s avant). simon (Pi Zero en WiFi, ping 50 ms et pointes à 150 ms)
     donne les à-coups, pas le débit.
     Suite prévue (ordre fixé par Pierre, 02/11/2026) : `tools/essai_oric.py`, essais
     du vrai Oric pilotés par Claude (batterie tirée de `essais-materiel.md`).
     Pour mesurer ou essayer sur le vrai Oric : démon sur le Mac de Pierre
     (`python3 tools/remote.py serve`, `REMOTE MAC` ; `10.0.0.7:8040` sur son réseau, joint
     par le lien avec son Mac) ou sur simon (`10.0.0.39:8040`).
     Avec ce lot, l'appel du modem est plus sûr : CR et réponses en retard jetés avant
     `AT` (le premier `XFER @MAC` répondait `ERROR`), et `xfer_server.py` accepte un
     nouvel appel à tout moment (une connexion morte le bloquait).
   - Aussi : passerelle
   vers Claude sur le Pi 400 (serveur TCP : appel de l'API, accents translittérés, lignes de
   38 colonnes, historique gardé côté Pi).
   - Contre-essai à faire : la 0.3.1 officielle avec le câble de données (`ACIADIAG.TAP`,
     `TERM /D`). Avec un câble sans données, elle lisait `A7 4C D0` en `$0381-$0383` ;
     la même source recompilée (0.3.98) lit `70 02 00`. Résultat à porter dans l'issue 17
     du firmware du LOCI.
5. **Sûreté des fichiers et défauts constatés**
   - **Contrôleur du LOCI qui ne répond plus après un RESET pendant `DISKCOPY A: D:`**
     (D: vide ; `*RESET* at C6C6`, disquettes intactes). Le pilote en fait maintenant une
     erreur disque au lieu d'accès déclarés bons (`docs/systeme.md` § 3). Reste à comprendre
     la cause : `C6C6` n'est pas une adresse de DISKCOPY mais du traitement du RESET lui-même
     (`hires_on` sur `cpa-en.dsk`, `print_hex8` sur `cpa.dsk`), donc une seconde NMI pendant
     le démarrage à chaud (rebond du bouton ?) ; la seconde NMI agit tout de suite, même au
     milieu d'un secteur (`bios.s`, `nmi_handler`). Le firmware du LOCI termine une écriture
     abandonnée au bout d'un délai (`dsk_rw_countdown`, `dsk.c`) : pas de blocage évident de
     ce côté. Non reproductible dans Oricutron, dont le contrôleur du LOCI simulé, une fois
     bloqué, ne lève jamais INTRQ (l'attente du premier octet échouait déjà) ; à voir sur le
     LOCI (`docs/essais-materiel.md`). Si c'est un rebond : ignorer une NMI arrivée peu après
     la précédente.
   - **Firmware du LOCI 0.3.98** (vrai LOCI, 30/10/2026) : sans les décimaux dans `printf`,
     la clé se décrit `1: MSC  GB General  UDisk` ; `dv_next` l'écartait (il attendait un
     chiffre), d'où `USBDIR /S` sans la clé, un répertoire courant sans support (`/files`)
     et `CPA.CWD` qui ne retenait rien. Corrigé (`docs/usb.md` § 2) ; à revérifier sur le
     matériel. `CPA.CWD` n'était de plus jamais créé : sur `0:`, le firmware traduit
     `O_CREAT+O_TRUNC` sans `O_CREAT` (`std.c`) ; contourné dans `usb_open` (créer, puis
     tronquer), reproduit dans Oricutron ; à signaler au firmware du LOCI. Le montage d'une image de `0:` (`USBMOUNT B: 0:CPA-ANIM.DSK`) a figé le
     LOCI (le firmware ne vérifie pas l'ouverture du fichier, `mnt.c`) : refusé par
     USBMOUNT et CMDER (`Pas d'image sur 0:`) ; à signaler au firmware du LOCI. Un
     `USBDIR` a aussi figé l'Oric et le LOCI après un passage par le menu du LOCI, avec un
     répertoire courant sans support : à reproduire maintenant que les chemins ont toujours
     leur support.
   - EDIT et GRAPHER (`SAVE`, `BSAVE`, `BSAVE SCREEN`) passent la batterie
     `tools/test_fichiers.py` (disque plein, répertoire plein, R/O, RESET balayé). Reste
     une fenêtre d'une demi-seconde, entre l'effacement de l'ancien fichier et le
     renommage, où un RESET laisse le nouveau contenu seulement dans `NOM.$$$` (rien n'est
     perdu, `REN` le remet). La fermer : une section protégée contre RESET pendant
     l'effacement et le renommage (variable publique en page 2, ou fonction BDOS de
     remplacement) — touche au contrat, à décider.
   - Écrivent encore en effaçant d'abord l'ancien fichier (disque plein ou RESET : ancien
     perdu), à passer par `NOM.$$$` et à ajouter à la batterie : `h_save` de `hires.inc`
     (image HIRES plein écran ; en SPLIT, GSAVE du système passe déjà par `NOM.$$$`), SAVE
     du CCP, LOGO (`SAUVE`, et `LOGO.$$$`
     de l'état), COPY et IMPORT sur un fichier existant, ASM (`.COM`, `.SYM` : refaits par
     un nouvel assemblage).
   - GSAVE du système rend 3 pour un fichier protégé ; GRAPHER (`h_save`) et LOGO
     (`SAUVEIMAGE`) l'affichent encore comme un disque plein : leur message à corriger.
   - GRAPHER : pas de moyen de savoir si un fichier existe sans le charger (`FOUND` ne vaut
     qu'après `LOAD` ou `BLOAD`) ; une fonction du genre `EXIST("NOM")`, ou une commande qui
     pose `FOUND`, à décider.
   - Notés par Pierre le 22/10/2026 (rien codé) :
     - **`ANIMS.GRX`** : ne passe plus dans GRAPHER (« animation trop grande ») mais passe
       une fois compilé par GRXASM. Pas forcément un défaut : en faire un exemple du manuel
       qui montre les limites du mode interprété et l'intérêt de compiler, avec la place
       disponible en plus après compilation par rapport à la version interprétée (à mesurer).
6. **Petites améliorations notées**
   - **Imprimante dans un fichier** (demandé par Pierre le 24/10/2026, sans imprimante ;
     Oricutron écrit déjà `printer.out`). Décidé : par PUT, plutôt que par un pilote LOCI
     dans le BIOS (API du LOCI résidente) : `PUT /P NOM commande`
     recopie dans le fichier ce qui part à l'imprimante (LIST, BDOS 5, CTRL-P, `^P` d'EDIT)
     au lieu de l'écran ; `EXPORT` le passe sur la clé, puis directement avec le lecteur
     U: (§ 2 point 9 : `PUT /P U:PRINT.TXT ...`). Coût résident : un test dans LIST vers
     `put_char` (~10 octets ; PUT est une banque de la fenêtre, § 3).
   - **DEBUG** (décidé par Pierre le 30/10/2026, à faire avec sa refonte, pas avant) :
     afficher par la fonction 2 du BDOS au lieu de `B_CONOUT` (`putc`), pour que
     `PUT LISTE.TXT DEBUG` garde un long désassemblage sans limite de tampon (puis XFER ou
     EXPORT vers un ordinateur) ; revoir son ergonomie ;
   - son dans les scripts : commande `NOTE` au prompt ou `PLAY.COM` (partition texte) ;
   - **Son de LOGO plus simple** (remarque de Pierre le 24/10/2026) : `SON v n vol d` et
     `ENSEMBLE` sont lourds pour un accord et n'ont pas de raccourci. Piste retenue : une
     surcouche écrite en LOGO (fichier `.LOG` chargé par `CHARGE` : notes par leur nom,
     accord, durées), sans toucher à LOGO.COM, puis seulement les primitives qui
     manqueraient. À écrire avec Pierre (ce qu'il attend d'un accord).
   - LOGO : ne pas perdre la frappe anticipée pendant `NOTE` / `ATTENDS` ; passer des
     paramètres d'un script à `LOGO NOM` ; tokenisation des procédures **en mémoire**
     seulement (au `CHARGE`, détokenisées par `SAUVE`, `LISTE`, `EDITE`), après la
     traduction et sur mesure (vitesse d'ELIZA et des traceurs, place) ; le contenu des
     listes reste du texte (code ou données : décidé à l'exécution) ;
   - GRAPHER : exemples de fichiers de données : un
     niveau écrit dans EDIT (`LOAD`), un écran titre (`BLOAD SCREEN`) ;
   - EDIT : une édition plein écran (colonnes 0-1 comprises) pour dessiner un écran texte ;
   - EDIT, demandé par Pierre le 23/10/2026 (rien codé) : un **sélecteur de fichiers**
     pour Ouvrir... et Insérer... (liste aux flèches, début de nom pour filtrer, RETURN
     choisit, ESC sort ; même esprit que `USBMOUNT`, § 2 point 3). À écrire une fois, en
     bibliothèque (`.inc`) réutilisable par les autres programmes (GRAPHER `LOAD`, CMDER...).
     Et **Insérer une partie d'un fichier** : le fichier choisi s'affiche en lecture seule,
     on s'y déplace et on y cherche (même recherche que dans EDIT), on marque début et fin,
     RETURN insère le bloc au curseur. But : une bibliothèque de bouts de code dans quelques
     gros fichiers, sans les charger en entier ni multiplier les petits fichiers. Lecture du
     fichier par morceaux, sans le copier dans le tampon de texte : bon usage des fichiers à
     accès direct (fonctions 33 à 36, point ci-dessous). Place à mesurer (EDIT : 1 536
     octets libres dans son dernier bloc, § 3).
     Gardé aussi : des **bouts nommés**. Une ligne `;##NOM` (commentaire en ASM et en
     GRAPHER ; distinct du `;@#` de GRXASM) commence un bout, qui va jusqu'au `;##` suivant
     ou la fin du fichier. Articulation proposée : Insérer... -> sélecteur de fichiers ; si
     le fichier a des `;##`, liste de leurs noms (RETURN insère le bout), plus une entrée
     « parcourir » vers la vue en lecture seule (où `;##` sert aussi de saut d'un bout à
     l'autre) ; sans `;##`, directement la vue. Index : construit à l'ouverture, en une
     lecture séquentielle, gardé en mémoire tant qu'EDIT tourne (nom, n° d'enregistrement
     de 128 octets, position 0-127 dans l'enregistrement : ~20 octets par bout) ; insertion
     par lecture directe (fonction 33) à cet enregistrement puis lecture suivie jusqu'au
     bout suivant. Pas de fichier d'index sur disque (rien pour savoir s'il est périmé).
   - un usage des fichiers à accès direct (fonctions 33 à 36) dans les programmes : GRAPHER,
     LOGO ou un `.COM`, à trouver.
7. **Version anglaise** (faite et essayée sur le vrai Oric le 24/10/2026 ; tout nouveau texte affiché ou document d'utilisation se fait dans les deux langues)
   - Décidé : une seule disquette anglaise, `cpa-en.dsk` (le contenu de `cpa.dsk`, programmes
     de `build/progs-en`) ; pas de disquettes par usage en anglais tant que LOGO n'est pas
     traduit. Les mots-clés de GRAPHER restent ceux d'aujourd'hui dans les deux langues :
     seuls les messages se traduisent.
   - Fait : la mécanique (`architecture.md` § 5 : `progs/msg/fr`, `progs/msg/en`, deux
     assemblages par `build.sh`, menus dans les fichiers de messages, `files/en/`) ; les
     commandes TYPE, ERA, REN, SET, STAT, COPY, FORMAT, DISKCOPY, XDO, MEM, POKE, GO, VOIR,
     VSYNC, EXPORT, IMPORT, USBDIR ; EDIT (et son `EDIT.CFG` : `WORDS`, `CHAR`, `LINE`
     acceptés dans les deux langues), HEX, ASM, DEBUG ; CMDER (en-têtes, genres et
     colonne du signe de tri compris : 13 435 octets en anglais, 7 blocs comme en
     français) ; GRAPHER, GRXASM (et les commentaires du `.ASM` produit) et les
     bibliothèques des programmes traduits : `GRX.INC`, `ARR.INC`, `FIL.INC`, `SPR.INC`,
     `ANIM.INC` (VOIR compris) en deux langues, `build/src` et `build/src-en`, messages
     recopiés par `strip_inc.py` (`architecture.md` § 5) ; GRAPHER 17 685 octets en
     anglais, GRXASM 15 132. `tools/test_asm.sh` assemble aussi
     les programmes traduits avec leurs messages anglais ; `LANGUE=en
     tools/test_grapher.sh` compare GRAPHER et GRXASM anglais aux références françaises
     traduites par les fichiers de messages (`tools/msg_fr_en.py`).
   - Fait aussi : **le système** (principe : tout ce qui est produit l'est dans les deux
     langues, `architecture.md` § 5). Barre de menus FUNCT du prompt et messages de la
     console dans `src/msg/fr/sys.msg` et `src/msg/en/sys.msg` ; `build.sh` assemble
     `cpa_sys.bin` et `cpa_sys_en.bin` (marges contrôlées toutes deux). Barre anglaise :
     System, Files, Screen, Keyboard. Les articles montrent leur raccourci (Imprimante
     `^P`, Majuscules `^T`, Redemarrer `^C` ; aucun autre article n'en a). Les menus
     déroulants (système et programmes) prennent leurs encres dans `m_colors` selon le
     papier (`src/menu_col.s`, page `$FF00` : blanc avec magenta et bleu sur papier noir,
     etc. ; tableau dans le source). Coût : 23 octets de code (marge française 37 → 14),
     8 octets dans `$FF00` (18 → 10). La ROM, projet à part, reste en français.
   - Fait aussi : HELP et README.TXT (`tools/gen_readme_txt.py`, une liste par langue,
     mêmes rubriques ; `helptab.msg` dans `progs/msg/fr` et `en`, `files/en/readme.txt`).
     Sujets anglais : KEYS PROGRAMS EDIT HEX LOGO ASM DEBUG MEMORY USB GRAPHER CMDER ; la
     rubrique LOGO donne les primitives anglaises. HELP anglais : 7 blocs comme le
     français.
   - Fait aussi : toutes les disquettes en deux langues (jumelles `-en`, `architecture.md`
     § 5 ; `cpa-project-en.dsk` pour la vierge) et tous les exemples traduits sous des noms
     anglais (`files/en/noms.txt`) : `.GRX`, `.LOG` (ELIZA réécrit pour l'anglais :
     table de reflet, mots-clés, réponses), `DEMO.BAT`,
     `HELLO.ASM`, `GTEST.ASM` (`GTEST.COM` anglais). `ROTSCROL.GRX` et `JEU.GRX`
     (`PUZZLE.GRX`), cités au § 14 de `grapher.md`, sont sur `cpa-exemples.dsk` (et sa
     jumelle).
   - Fait aussi : `docs/en` décrit les disquettes anglaises (écrans, menus, messages de
     `cpa-en.dsk` ; `architecture.md` § 7) ; README.md renvoie à `cpa-en.dsk`.
   - Fait aussi : **LOGO** (`logo.md`). Une seule table de primitives
     (`tools/gen_logo_voc.py`) : chacune a un numéro (le token d'une tokenisation future)
     et ses noms dans les deux langues ; `LOGO.COM` dans la langue de la disquette, comme les
     autres programmes (vocabulaire `logovoc.msg`, messages, menus et AIDE `logo.msg`), donc
     pas de `LOGOFR` / `LOGOEN` et rien à changer au retour d'EDIT. Anglais classique
     (FORWARD FD, TO ... END, MAKE, PRINT PR, REPEAT, IF, OUTPUT OP, BUTFIRST BF...).
     `LOGOTR.COM` traduit un `.LOG` : primitives seulement, en position de code (listes
     d'instructions de `REPETE`, `SI`, `EXECUTE`, `ENSEMBLE`), listes de données recopiées,
     avertissements (liste de données qui commence par une primitive, nom de l'utilisateur
     qui est une primitive d'arrivée) ; aller-retour identique sur les exemples et les
     scénarios de test. Exemples `.LOG` anglais passés aux primitives anglaises par LOGOTR.
     `LANGUE=en tools/test_logo.sh` (références `tools/logo_tests/en`).
   - `smoke_test` : les deux disquettes anglaises ensemble (`GRXASM MAP /C`, `cpa-en.dsk`
     sur A:, `cpa-project-en.dsk` sur B:) ; le reste du smoke test ne dépend pas de la langue.
   - Documentation : faite. `README.md` en anglais (français : `README.fr.md`), documents
     d'utilisation dans `docs/en/` (mêmes noms, `tools/check_en.py`), documents internes en
     français seulement.

8. **Construire CP/A sur l'Oric** (demandé par Pierre le 23/10/2026, rien codé) : une
   disquette de construction pour produire sur l'Oric un système configuré selon les besoins
   (sans menus, sans USB du LOCI...) et l'installer sur B:, et faire les versions ROM.
   - Installer sur B: : existe déjà, `DISKCOPY A: B: /S` (comme SYSGEN) ; il faudra la même
     chose depuis un fichier système produit par ASM.
   - Sources : 198 Ko dans `src/`, 130 Ko sans commentaires ni lignes vides : `build.sh`
     produirait une version sans commentaires pour la disquette de construction (les
     sources de référence restent celles du dépôt). Tient sur une disquette, à mesurer.
   - ASM (syntaxe de xa, octets identiques) : manquent `#ifdef`, `#ifndef`, `#else`,
     `#endif` (les seules directives du système : 64 blocs, imbrication sur 2 niveaux dans
     `ccp.s` et `rline.s` ; pas de `#if` ni de `#define`). Les options (`DISK`, `CPLCMD`...)
     seraient des constantes d'un fichier de configuration inclus en premier (`DISK = 1`),
     sans option nouvelle sur la ligne de commande. Coût estimé : ~150 à 200 octets (mots
     des directives, état de saut avec une petite pile, lignes sautées, deux messages
     d'erreur). L'inclusion sur deux niveaux est évitée sans coût : `#include "sys.msg"`
     passe de `menu.s` à `cpa.s`. ASM (6 130 octets) est à 14 octets d'un bloc : il passe
     de 3 à 4 blocs sur la disquette (2 Ko). Symboles du système : 1 262, ~19 Ko, la
     mémoire libre d'ASM (~37 Ko) suffit. Temps : LOGO (136 Ko de source) s'assemble en
     ~1 min 30 ; le système (130 Ko sans commentaires) devrait être du même ordre, à
     mesurer sur le LOCI.
   - Refaire sur l'Oric les contrôles de `build.sh` (marges, fin du code, page `$FF00`).
   - Options touchant une fonction du BDOS (menus, USB, son...) : le numéro doit rester et
     répondre « absent » avec un code connu, et les programmes savoir s'en passer. Règle à
     écrire dans `architecture.md` (précise le contrat sans le casser) avant de rendre
     quoi que ce soit optionnel.
   - ROM : même assemblage avec l'option ROM (16 Ko), `EXPORT` vers la clé ; vérifier que
     le LOCI démarre sur une ROM lue sur sa clé.
   - Ordre proposé : règle des fonctions optionnelles ; `#ifdef` dans ASM, `sys.msg` inclus
     par `cpa.s` ;
     essai d'assemblage du système par ASM (octets identiques à xa) ; disquette de
     construction ; installation depuis un fichier ; ROM.

9. **Orientation LOCI du stockage**. Décidé par Pierre (23/10/2026), rien codé : CP/A vise
   à moderniser l'environnement, pas à rentabiliser des disquettes 3 pouces devenues rares
   et chères ; le LOCI est simple, répandu et peu cher, et la synchronisation d'un vrai
   Microdisc est délicate. Les fichiers restent du **texte sur disque** (EDIT, TYPE, git, le
   Mac) : pas de tokenisation ni de compactage sur disque (ceux du BASIC et de SEDORIC sont
   de leur époque) ; la place viendra du **lecteur « fichiers USB »** ci-dessous, la
   direction à suivre pour le stockage. Le `.dsk` reste pour démarrer.
   - Fait : **disquettes de 2 faces de 80 pistes** (piste A de `docs/etude-stockage.md`,
     qui garde les mesures et les pistes restantes) : 658 Ko pour les fichiers au lieu de
     336, blocs de 2 Ko numérotés sur 16 bits (comme CP/M 2.2 au-delà de 255 blocs),
     répertoire de 128 entrées dont l'étiquette du format ; anciennes disquettes refusées,
     converties par `tools/mkdisk.py conv`. Essayé dans Oricutron ; à essayer sur le LOCI
     (`docs/essais-materiel.md`).
   - **Lecteur « fichiers USB » (U:)**, plus intéressant : les fonctions fichiers du BDOS
     passent par l'interface fichiers du LOCI (ouvrir, lire, écrire, se positionner,
     fermer ; USBDIR s'en sert déjà pour lister). Gains : taille de la clé, vitesse (pas
     d'émulation de secteurs), fichiers lisibles et modifiables sur le Mac (éditeur, git ;
     plus besoin d'`EXPORT` / `IMPORT`), accès direct presque gratuit (positionnement ;
     utile à la bibliothèque de bouts d'EDIT, § 2 point 6), taille exacte des fichiers.
     Difficultés : noms longs ramenés en 8.3 ; attributs R/O et SYS ; espace libre pour DIR
     et STAT ; les programmes qui lisent des secteurs par le BIOS (DISKCOPY, FORMAT...) ne
     marchent pas sur U:. **Touche le contrat** (un type de lecteur sans accès secteur) :
     à décider avant tout code.
   - **Construction hybride proposée** : A: reste un `.dsk` (démarrage ;
     un utilisateur de Sedoric essaie CP/A sans rien changer), U:
     lecteur de travail pour qui a un LOCI (option de la construction, point 8). À terme,
     une variante « tout LOCI » où A: est un dossier de la clé : plus de code de secteurs
     sauf l'amorçage, système plus petit.
   - Préalable : lire l'interface fichiers du LOCI (`loci-rom`, firmware) : ce qu'elle
     permet, longueur des noms, espace libre, vitesse.
   - Fichier catalogue par répertoire de la clé (question de Pierre) : écarté. Il doublerait
     la vérité du disque et serait périmé dès qu'on modifie les fichiers sur le Mac (le but
     même de U:) ; écritures en plus à chaque modification (fenêtre RESET) ; fichier parasite
     sur la clé. Gain faible : ouvrir un fichier par son nom va droit au LOCI ; seuls DIR,
     les jokers et la complétion parcourent un répertoire, et lire un catalogue passe par la
     même interface qu'un `readdir`. À la place : (1) FAT garde déjà un nom court 8.3 pour
     chaque nom long : si l'interface du LOCI le renvoie, la correspondance des noms est
     faite et stable ; (2) un cache en mémoire du répertoire courant, tenu par CP/A,
     invalidé par ses propres écritures et au démarrage à chaud ; (3) le tri par joker fait
     par le firmware (piste à proposer à sodiumlb). D'abord mesurer la vitesse d'un
     `readdir` sur un répertoire de quelques centaines de fichiers.
   - Piste de Pierre : proposer à l'auteur du LOCI (sodiumlb) une version du firmware qui
     fasse du LOCI une vraie interface de stockage, support alternatif au Microdisc.
     Précédents dans cet esprit : Orix (système de la carte Twilighte, fichiers FAT sur
     clé USB / SD directement) et Erebus (à regarder).

Écarté : une base de données (hors de la vision : `docs/vision.md`) ; `REDIM` dans GRAPHER (hors de l'esprit du langage : les tailles sont connues à
l'écriture) ; modules chargeables pour LOGO (le chargement par étapes avec `CHARGE` et `OUBLIE`
suffit) ; primitive LOGO générique `.SYSTEME n [liste]` ; conversion CR LF -> LF par EXPORT ; un portage pour le Microdisc (son lecteur 3″ d'origine
n'a qu'une face de 40 pistes, les disquettes de CP/A en ont 2 de 80 ; laissé à qui le
demandera : note de `README.md`, piste F de `docs/etude-stockage.md`).

## 3. Réserves de place

**Système** (marge 544 octets ; fenêtre : 2 octets pour PUT, 4 pour IMG, 91 pour GFX ; page
`$FF00` : 10 octets ; variables du BDOS : `$FD57` libre, 1 octet ; rappel automatique de
la console à distance : 339 octets résidents et `$FD27-$FD56`). Fait : les tracés
du SPLIT en banque GFX (959 octets rendus, variante sans toucher aux tables `g_xcol`,
`g_xbit`). Fait : police rangée sur 5
octets par caractère, dépliée par `font_init` (257 octets rendus, `docs/systeme.md` § 2).

| Piste | Gain estimé | Prix |
|---|---:|---|
| H : masque de point sans la table `g_xbit` (240 octets) ; en dernier recours, variante A | A ~185, B ~215 | mesuré (ci-dessous) : A 5 à 8 % plus lent, B 9 à 14 % |
| Code répété (`g_box`/`g_line`, `go`/`f_delete`) | < 400 | coût des `JSR` |
| Autre banque de la fenêtre (une commande ou une fonction rare : 576 octets au plus) | sa taille, moins ~6 par point d'entrée | un accès à `CPA.BNK` au premier usage |

Écartés : commandes graphiques du CCP en `.COM` (scripts ralentis), compression du clavier ;
toucher aux menus ou à la complétion (`CPLCMD`), fonctions phares (`docs/vision.md`).

**Piste H mesurée** (6502 simulé, appels par la fonction 115, images identiques ; temps
actuels à 1 MHz) : A garde `g_xcol` et ajoute une table de 40 multiples de 6 et une de 6
masques ; B calcule 6 × colonne par décalages.

| Charge | Actuel | A | B |
|---|---:|---:|---:|
| 2 000 PLOT | 0,71 s | +4,6 % | +8,8 % |
| 120 LINE | 2,85 s | +6,4 % | +12,3 % |
| 40 CIRCLE | 1,14 s | +7,5 % | +14,4 % |
| 20 BOX | 2,13 s | +6,8 % | +13,1 % |

Les tracés du SPLIT (PLOT, LINE, BOX, CIRCLE, POINT, par `g_addr`) sont un point fort : H
ne se fait qu'en dernier recours, en variante A. Les primitives du système ne servent pas en
HIRES plein écran (tables des lignes en `$B400`, dans l'image HIRES) : `hires.inc` a les
siennes.

**La fenêtre** (`$F7C0-$FCFF`, `docs/systeme.md` § 6). Fait : lot 1, PUT et le code du
démarrage à froid (test de la RAM, `AUTO.BAT`) chargés avec le système (576 octets
résidents rendus) ; lot 2, banque IMG (GSAVE, GLOAD, SAVE) lue dans `CPA.BNK` quand elle
sert, PUT rechargé de `CPA.BNK`, prêt de la fenêtre pendant un PUT, GSAVE par `NOM.$$$` (69
octets rendus : le chargeur, `win_call` et les points d'entrée font ~370 octets, coût fixe ;
chaque banque suivante rend presque toute sa taille). Le pilote série (660 octets, § 2
point 4 : console à distance) a pris la marge ; les menus (fonction phare) restent
résidents. Lot 4 : banque GFX, les tracés du SPLIT (BDOS 115 op 2 à 9, 997 octets) ; elle
déborde sur le tampon de PUT (jusqu'à `$FBFF`), donc pas de tracé pendant un PUT (LOGO sous
PUT ne dessine pas ; GRAPHER dessine par `hires.inc`, pas concerné) ; chargée au premier
tracé, puis de nouveau après GSAVE, GLOAD ou PUT ; `CPA.BNK` passe à 2 blocs (2 560 octets),
2 Ko de moins sur chaque disquette amorçable.

Pas dans la fenêtre : la complétion des commandes (un chargement à chaque ESC) ; MODE,
GETMODE, PEN et GCLS de la fonction 115 (le démarrage à chaud et IMG s'en servent) ; `hw_init` et `font_init`, qui servent aussi au
démarrage à chaud et à `crash_screen` ; `msg_banner` (VER).

Décidé, pas encore fait (lot 3) : options résident / en banque / absent, d'abord par `-D`
dans `build.sh` (puis le fichier de configuration de la construction sur l'Oric, § 2 point
8). Le code du démarrage à froid va toujours dans la fenêtre.

**Disquettes** (blocs de 2 Ko : un octet gagné ne rend un bloc qu'en repassant sous un
multiple de 2 048) :

- tampons stockés dans le fichier, à sortir après la fin du programme : DEBUG (122), EDIT
  (842), HEX (432), XDO (512) ;
- GRAPHER (18 183 octets) prend 9 blocs, 249 octets libres dans le dernier ; piste de
  place : messages d'erreur par numéro, ~40 octets. GRXASM (17 085) prend 9 blocs, 1 347
  octets libres dans le dernier (17 013 en anglais ; le texte d'un `.GRX` à traduire va de
  `$51A4` à `$9CE0`, ~19,2 Ko : 738 octets de moins depuis la lecture de `GRX.LIB`) ; ORIC.INC (9,3 Ko sur la disquette) prend 5 blocs ;
  GRX.INC (12 492 octets sur la disquette, CR LF, marques `;@` et messages compris) prend 7
  blocs, 1 844 octets libres dans le dernier ; GRX.LIB (32 174, 32 115 en anglais) prend
  16 blocs, 594 octets libres dans le dernier. HELP (12 850) prend 7 blocs, 1 486 octets libres dans le dernier (13 029 en anglais, 7
  blocs). CMDER (18 025) prend 9 blocs, 407 octets libres dans le dernier ;
  EXPORT, IMPORT, USBDIR 2 blocs chacun (le code commun de `loci_inc.s` : ~1,7 Ko) ;
  USBMOUNT (4 032) prend 2 blocs, 64 octets libres (87 en anglais) ; MKTAP (4 079)
  aussi, à 17 octets près (57 en anglais). EDSPRITE (8 967) prend
  5 blocs, 1 273 octets libres dans le dernier. Les disquettes se spécialisent plutôt
  que de gratter des octets ;
- EDIT (8 704 octets) prend 5 blocs, 1 536 octets libres dans le dernier (tampon de texte
  aligné sur une page ; en anglais, 243 octets de code avant la page suivante, 71 en
  français). HEX : 47 octets avant le bloc suivant (143 en anglais) ; ASM (7 322) prend 4
  blocs, 870 octets libres dans le dernier (957 en anglais, 7 235) ;
- usage à deux disquettes : sur `cpa.dsk` il reste 360 Ko (360 sur `cpa-en.dsk`) ; le
  travail va de préférence sur une disquette de projet en B: (658 Ko), GRXASM `/C` ne
  laisse que le `.COM`, ASM n'écrit le `.SYM` que sur demande (`/S`) ;
- répertoire : 127 fichiers au plus par disquette (entrée 0 : l'étiquette ; un fichier en
  prend une par tranche de 16 Ko) ; CMDER et la complétion comptent sur 128 entrées au plus ;
- blocs de 1 Ko : écartés (ce ne serait plus le format de CP/M 2.2,
  `docs/etude-stockage.md`).

**Mémoire de GRAPHER interprété** : environ 17 Ko pour le texte, les tableaux et une
animation (`docs/grapher.md` § 13) ; `CUBE.ANI` et `BALLE.ANI` ne se jouent qu'en traduit.
Chaque octet de plus dans GRAPHER.COM en retire un.

## 4. Contraintes à garder en tête

- Tout ajout résident se justifie ; le reste va en `.COM`. Les estimations ont souvent été
  dépassées du simple au double : prévoir large.
- Les interruptions sont coupées pendant les accès disque (une touche peut être perdue, le
  compteur 50 Hz retarde).
- Le contrat d'interface (`docs/architecture.md`) est commun avec la version ROM
  (`docs/projet-rom.md`).
- La plupart des possesseurs d'un vrai lecteur n'en ont qu'un : une commande disque doit
  marcher avec un seul lecteur dès que c'est possible, et les commandes de base doivent
  pouvoir être sur chaque disquette.
