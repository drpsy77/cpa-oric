# CP/A disquette — état et suite

Système « à la CP/M » pour Oric Atmos, chargé depuis une disquette (Microdisc, LOCI) dans les
16 Ko de RAM overlay, et enrichi par des programmes `.COM` plutôt que par du code résident.
Usages visés : développer sur l'Oric lui-même, gérer des fichiers et des données, communiquer
(réseau par le LOCI). À lire avec `docs/architecture.md`.

## 1. Ce qui existe (version 0.9)

**Système** : code résident `$C000-$F424` en français (`$F3F8` en anglais), **marge 588
octets** jusqu'à `$F670` (711 sans l'option `CPLCMD`) ; fenêtre `$F7C0-$FCFF` (PUT, marge 2
octets avant son tampon de 768 ; code du démarrage à froid dans le tampon, marge 565 ;
`docs/systeme.md` § 6) ; page `$FF00-$FFEF`, marge 10 octets (table des touches de l'édition
de ligne, encres des menus). `./build.sh` affiche les marges.

- console : pause en fin d'écran, menus déroulants (FUNCT), voyants `A`/`a` et `P`, couleurs
  et pagination (`PAPER`, `INK`, `PAGE`) ;
- clavier : CTRL-H à CTRL-K distincts des flèches (28-31), CTRL-ESPACE (0), SHIFT et CTRL
  avec les flèches (`$F0-$F7`) ; mêmes touches dans EDIT, HEX, CMDER et la ligne de commande
  (`docs/manuel.md`, « Les mêmes touches partout ») ;
- lecture de ligne (BDOS 10) : édition, historique, complétion par TAB ou ESC des noms de fichiers
  et, en début de ligne, des commandes (sur les lecteurs où elles seraient cherchées) ;
- fichiers CP/M 2.2 (séquentiel, accès direct, attributs R/O et SYS), lecteurs A: à D: ;
- programmes et scripts cherchés sur le lecteur du script (ou le courant), puis A: à D: ;
  scripts `.BAT` (DO, `$1`-`$9`, appel de script à script par XDO, `AUTO.BAT` au démarrage
  à froid) ; CHAIN (BDOS 47) ; PUT (sortie d'une commande dans un fichier) ;
- imprimante Centronics (LIST, BDOS 5, CTRL-P) ;
- graphisme SPLIT (BDOS 115), son AY (BDOS 116) ; HIRES plein écran et écran texte (LORES)
  laissés aux programmes, avec retour assuré par le démarrage à chaud ;
- reprise après plantage (BRK, RESET) ; un RESET pendant le transfert d'un secteur attend la
  fin du secteur (un secteur coupé, du répertoire par exemple, serait illisible) ; un
  contrôleur de disquettes qui ne répond plus donne `BDOS: disk I/O error`, jamais un accès
  déclaré bon (`tools/test_fdc.py`).

Détail du fonctionnement interne : `docs/systeme.md`. Mode d'emploi : `docs/manuel.md`.

**Programmes**

| Programme | Octets | Rôle | Documentation |
|---|---:|---|---|
| HELP | 12 580 | aide par rubriques (textes compressés) | `manuel.md` |
| TYPE, ERA, REN, SET, STAT, COPY | 177 à 1 033 | fichiers | `manuel.md` |
| FORMAT, DISKCOPY | 1 685, 1 658 | disquettes, avec un seul lecteur | `manuel.md` |
| CMDER | 17 961 | gestionnaire de fichiers plein écran, deux colonnes, clé USB (supports, répertoires seuls, renommer, effacer, dupliquer, monter ; nom des disquettes dans les en-têtes) ; fixe le répertoire courant de la clé | `cmder.md` |
| EXPORT, IMPORT, USBDIR | 3 046, 3 381, 2 961 | échange avec la clé USB du LOCI, relatif au répertoire courant de CP/A (`0:CPA.CWD`) ; jokers ; `USBDIR /S` : supports ; `USBCD rep` (`USBDIR /C`) : change de répertoire, `USBCD` seul : CMDER | `manuel.md`, `usb.md` |
| USBMOUNT | 4 032 | monte, montre, éjecte les images de disquette (B: à D:) et la cassette de la clé ; `/B` : démarre le BASIC 1.1 du LOCI sur la cassette | `manuel.md`, `usb.md` |
| MKTAP | 4 079 | fichier `.TAP` pour l'Oric sous BASIC (`CLOAD""`) : un bloc par fichier, démarrage automatique (bloc `/R` en `$0503` au plus tôt) ou chargeur BASIC ; programme BASIC en texte (`.BAS`) codé comme la ROM 1.1 | `manuel.md`, `oric-basic.md` |
| TERM | 852 | terminal série (modem WiFi du LOCI, ACIA `$0380` ; Oricutron `$031C`) | `manuel.md` |
| XFER | 2 037 | envoi et réception de fichiers par le modem (XMODEM-CRC), serveur `tools/xfer_server.py` | `manuel.md` |
| XDO | 1 351 | appel de script à script | `manuel.md` |
| EDIT | 8 704 | éditeur de texte (coupure aux mots, à 38 caractères, ou ligne entière qui défile en largeur) | `manuel.md` |
| HEX | 3 840 | éditeur hexadécimal | `manuel.md` |
| EDSPRITE | 8 967 | éditeur plein écran des sprites et caractères `.SPR` de GRAPHER (grille à trois états, liste, aperçu réel, codes hexa, transformations, animation) | `edsprite.md` |
| ASM | 6 140 | assembleur 6502 (identique à xa sur nos sources) ; `/S` : symboles, `/E` : source effacée, `/T` : fichier écrit nommé `NOM.TAP` ; `#include` cherchés sur A: à D: | `manuel.md` |
| DEBUG | 6 490 | moniteur, désassembleur, pas à pas | `manuel.md` |
| MEM, POKE, GO | 674, 254, 221 | mémoire | `manuel.md` |
| LOGO | 18 963 | Logo (français, ou anglais sur les disquettes anglaises : 18 758) : tortue, décimaux, listes, son, écran texte | `logo.md` |
| LOGOTR | 4 402 | traduit les primitives d'un `.LOG` d'une langue à l'autre | `logo.md` |
| GRAPHER, GRXASM | 17 769, 16 264 | langage de dessin et de jeux (`.GRX`) : interpréteur, traducteur en assembleur (`/C` : jusqu'au `.COM` ; `/O` : `.TAP` pour un Oric seul, sans CP/A ni BASIC, sur le socle `ORIC.INC` ; aucun contrôle à l'exécution, tableaux à adresse fixe, seules routines utiles des bibliothèques) ; fichiers de données, sprites en mode texte (`.SPR`) ; rectangles (copie d'un tableau vers l'écran, défilement, rotation), écriture verticale ; cartes de tuiles (`TILESET`, `TMAP`, `TILE`, dessins par `TFONT`) ; tableaux à deux dimensions en (colonne, ligne), comme l'écran ; `PRINT` à plusieurs éléments | `grapher.md` |
| VOIR, VSYNC | 3 353, 744 | images, animations ; calage du top sur le balayage | `manuel.md` |
| HELLO, GTEST | 88, 156 | exemples d'assembleur | — |

Disquettes, une par usage, chacune amorçable et munie de ses outils (un seul lecteur
suffit) : `cpa.dsk` (système : tous les programmes sauf LOGO, toute l'aide, aucun exemple ;
86 Ko libres), `cpa-anim.dsk` (la démonstration, 44 Ko libres), `cpa-logo.dsk` (LOGO seul,
200 Ko libres, pour la plateforme LOGO à venir), `cpa-exemples.dsk` (exemples de GRAPHER et
d'ASM, 50 Ko libres), `cpa-notes.dsk` (écrire, 248 Ko libres), et `cpa-projet.dsk` (vierge,
sans système : le travail en B:) ; chacune a sa jumelle anglaise (`cpa-en.dsk`,
`cpa-examples-en.dsk`... `cpa-project-en.dsk`) ; contenu dans `docs/manuel.md`.

**Mesure** : 1 480 points de fonction IFPUG et 347 points d'algorithmes ; détail, lignes,
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
   - **Bibliothèques compilées** (idée de Pierre, 25/10/2026 ; backlog, pas prioritaire :
     sur le LOCI, la traduction est longue mais ne gêne pas). Mesure dans le 6502 simulé,
     `GRXASM SERPENT /O` : 12,9 s de calcul, 729 enregistrements lus (716 pour les quatre
     bibliothèques, lues deux fois en entier : relevé des dépendances, puis recopie) et 239
     écrits ; `ASM` : 17,9 s, 478 lus (le `.ASM` deux fois), 41 écrits. Le `.ASM` fait
     30 Ko, dont 21 Ko de texte recopié des bibliothèques pour 3,6 Ko de code. Piste : les
     bibliothèques compilées par `build.sh` (xa, sur le PC) avec, pour chaque routine, ses
     dépendances et ses adresses à reloger (cible = routine + décalage ; octet haut seul :
     garder l'octet bas pour la retenue ; symboles du programme : `O_FILES`, `h_end`,
     `s_hst`...) ; GRXASM ne lit qu'un index et n'écrit que le code du programme ; ASM
     ajoute les routines relogées à la même place qu'aujourd'hui, donc un `.COM` / `.TAP`
     identique à l'octet près (les tests actuels restent l'oracle ; un relogeur Python pour
     xa). Gains estimés : ~4 fois moins d'enregistrements, ~3 fois moins de calcul, ~50 Ko
     de moins sur chaque disquette qui porte GRXASM ; aussi pour l'assembleur écrit à la
     main. Prix : outil de construction, ASM d'un ou deux blocs de plus, `.ASM` qui ne
     contient plus les bibliothèques. Première étape possible : l'index des dépendances
     seul (plus de première lecture). À minuter d'abord sur l'Oric (traduction, puis
     assemblage) : le partage entre calcul et accès au LOCI n'est pas connu.
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
     comme lecteur) : après la descente de PUT en banque (§ 3).
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
   Décidé, pas encore fait : plusieurs fichiers (jokers), appel du serveur par XFER
   lui-même (sans passer par TERM).
   Proposé, avec l'appel du serveur par XFER : un fichier texte `HOSTS` (`nom hôte:port`,
   une ligne par hôte), lu par TERM et XFER (code dans `acia_inc.s`, ~200 octets, rien de
   résident) ; un nom absent part au modem, qui résout par le DNS (pas les `.local`).
   - **Le tampon est hors de l'Oric** : le LOCI ne remplit son tampon de 32 octets que s'il
     a de la place, le Pico W attend que l'USB accepte avant d'écrire et ne rouvre la
     fenêtre TCP que quand son tampon se vide (`docs/loci-modem-wifi.md`, « Contrôle de
     flux »). Un Oric occupé (défilement, disque, interruptions coupées) ne perd rien : ni
     interruption ni tampon circulaire côté Oric. Vaut pour le LOCI seulement ; un vrai 6551
     (Oricutron `$031C`, carte série) perd un octet si on tarde.
   - Décidé par Pierre : **console à distance** (le Mac tape et lit à la place du clavier et
     de l'écran : essais sur le vrai Oric pilotés comme `tools/run_test.sh`, texte collé dans
     EDIT). Elle demande le pilote dans le BIOS, pas un `.COM` : elle doit survivre aux
     programmes.
   - Ordre : (1) descente de PUT, lot 1 fait (§ 3 : ~580 octets résidents rendus) ;
     (2) pilote série du BIOS, par
     scrutation, reprenant le code d'`acia_inc.s` : PUNCH / READER (BDOS 3
     et 4), état de la réception, console redirigée (CONST, CONIN, CONOUT ; commande et
     forme à spécifier) ; ~150 octets estimés, ~300 à prévoir.
   - Contraintes du pilote : écritures dans l'ACIA par `STA` absolu seulement (une écriture
     indexée lit d'abord le registre et consomme un octet reçu) : l'adresse `$0380` /
     `$031C` choisie au démarrage se pose dans le code (RAM overlay) ; la ROM devra fixer
     `$0380` ou copier ces quelques instructions en RAM.
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
     perdu), à passer par `NOM.$$$` et à ajouter à la batterie : `GSAVE` (BDOS 115 op 12,
     `img_save` de `src/gfx.s`, et `h_save` de `hires.inc`), LOGO (`SAUVE`, et `LOGO.$$$`
     de l'état), COPY et IMPORT sur un fichier existant, ASM (`.COM`, `.SYM` : refaits par
     un nouvel assemblage).
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
     `put_char` (~10 octets), à faire avec la descente de PUT en banque (§ 3).
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
     mesurer sur un vrai Microdisc.
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
   direction à suivre pour le stockage. Le `.dsk` reste pour démarrer et pour les vrais
   Microdisc et Cumulus.
   - **`.dsk` de 1 Mo** : possible mais cher. Cartes d'allocation actuelles : 22 octets par
     lecteur (`$FD00-$FD57`), ~176 blocs de 2 Ko, ~350 Ko. 1 Mo = 512 blocs : cartes de 64
     octets par lecteur (~170 octets résidents de plus) et numéros de bloc sur 2 octets
     dans le répertoire (comme CP/M 2.2 au-delà de 255 blocs) : nouveau format, anciennes
     disquettes illisibles. Et le LOCI doit accepter la géométrie (2 faces x 128 pistes ?)
     : à vérifier dans son firmware.
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
   - **Construction hybride proposée** : A: reste un `.dsk` (démarrage ; compatible vrai
     Microdisc et Cumulus ; un utilisateur de Sedoric essaie CP/A sans rien changer), U:
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
suffit) ; primitive LOGO générique `.SYSTEME n [liste]` ; conversion CR LF -> LF par EXPORT.

## 3. Réserves de place

**Système** (marge 588 octets ; fenêtre : 2 octets pour PUT ; page `$FF00` : 10 octets) :

| Piste | Gain estimé | Prix |
|---|---:|---|
| H : masque de point calculé au lieu de la table `g_xbit` (240 octets) | ~220 | un peu plus lent en SPLIT |
| Police rangée sur 5 octets par caractère, dépliée par `font_init` | ~250 | le texte de `gfx.s` doit lire la police recopiée |
| Code répété (`g_box`/`g_line`, `go`/`f_delete`) | < 400 | coût des `JSR` |
| Option `CPLCMD` retirée (complétion des commandes) | 123 | perte de la fonction |

Écartés : commandes graphiques du CCP en `.COM` (scripts ralentis), compression du clavier.

**La fenêtre** (`$F7C0-$FCFF`, `docs/systeme.md` § 6). Fait (lot 1) : PUT et le code du
démarrage à froid (test de la RAM, `AUTO.BAT`) y sont chargés avec le système ; 576 octets
résidents rendus. La place sert d'abord au pilote série (~300 octets, § 2 point 4 : console
à distance) ; les menus (fonction phare) restent résidents.

Décidé, pas encore fait :

- **IMG** (lot 2) : GSAVE et GLOAD (BDOS 115 op 12 et 13, `g_gsave` à `g_mode`, 241 octets ;
  `cmd_gsave`, `cmd_gload`, `img_msg`, `img_name`, 64) et `SAVE n fichier` (`cmd_save`, 132) :
  437 octets. Chargée depuis le fichier de banques quand elle sert, elle reste dans la
  fenêtre (les GLOAD suivants ne relisent rien) ; le PUT suivant relit PUT (`win_id` :
  nouveau bit, `cmd_put` refuse déjà une fenêtre sans PUT).
- **Prêt pendant un PUT** (lot 2) : le fichier de banques est ouvert d'abord (absent :
  opération refusée, PUT intact), copie suspendue (`put_on` à 0), IMG lu sur le code de PUT
  sans toucher au tampon (son reste, moins de 128 octets, est en tête), opération, PUT relu,
  copie rendue. À l'entrée du BDOS, `put_flush` a déjà écrit le tampon. Le chargeur prend
  son FCB dans `PUT_SAVE` (`$F9C3`, après le code de PUT : IMG doit s'arrêter avant) ;
  `put_end` regarde aussi `put_lost` (disque plein) : le prêt ne doit pas laisser l'un sans
  l'autre. Un RESET pendant le prêt perd la copie en cours (le fichier n'a que ce qui était
  écrit).
- **Pas dans la fenêtre** : la complétion des commandes (un chargement à chaque ESC
  ralentirait le vrai Microdisc) ; les fonctions graphiques (BDOS 115 sauf 12-13, ~1,7 Ko,
  appelées sans cesse ; `PUT LOG.TXT GRAPHER DEMO` doit continuer de marcher) ; `hw_init` et
  `font_init`, qui servent aussi au démarrage à chaud et à `crash_screen` ; `msg_banner`
  (VER).
- **Fichier de banques** (lot 2) : `CPA.BNK` (SYS, R/O), sur toutes les disquettes système,
  français et anglais ; signature calculée par `build.sh`, comparée à celle du système : une
  banque d'une autre version est refusée avec un message. Cherché comme les programmes
  (lecteur courant, puis A: à D:). Pas de place dans les pistes système (LSN 3-66 pris, 67
  seul libre).
- **Ce qui recule** (lot 2) : sans `CPA.BNK` en ligne, GSAVE, GLOAD et SAVE sont refusés (PUT
  marche tant qu'IMG n'a pas pris sa place) ; sous PUT, chaque GSAVE ou GLOAD relit ~1 Ko de
  banques.
- **Lots** suivants :
  2. fichier de banques, chargeur, IMG en banque, prêt de la fenêtre ; GSAVE par `NOM.$$$`
     (§ 2 point 5) et dans `tools/test_fichiers.py`. Gain ~437, moins le chargeur (~120).
  3. options résident / en banque / absent, d'abord par `-D` dans `build.sh` (puis le
     fichier de configuration de la construction sur l'Oric, § 2 point 8) ; la ROM n'a que
     résident ou absent. Le code du démarrage à froid va toujours dans la fenêtre.
- **À vérifier sur le matériel** (lot 2) : vitesse de chargement d'une banque sur un vrai
  Microdisc et sur le LOCI.

**Disquettes** (blocs de 2 Ko : un octet gagné ne rend un bloc qu'en repassant sous un
multiple de 2 048) :

- tampons stockés dans le fichier, à sortir après la fin du programme : DEBUG (122), EDIT
  (842), HEX (432), XDO (512) ;
- GRAPHER (17 769 octets) prend 9 blocs, 663 octets libres dans le dernier ; piste de
  place : messages d'erreur par numéro, ~40 octets. GRXASM (16 264) prend 8 blocs, 120
  octets libres dans le dernier (le texte d'un `.GRX` à traduire va de `$4E6F` à `$9CE0`,
  ~20 Ko) ; ORIC.INC (9,3 Ko sur la disquette) prend 5 blocs ;
  GRX.INC (12 492 octets sur la disquette, CR LF, marques `;@` et messages compris) prend 7
  blocs, 1 844 octets libres dans le dernier. HELP (12 580) prend 7 blocs, 1 756 octets libres dans le dernier (12 417 en anglais, 7
  blocs). CMDER (17 961) prend 9 blocs, 471 octets libres dans le dernier ;
  EXPORT, IMPORT, USBDIR 2 blocs chacun (le code commun de `loci_inc.s` : ~1,7 Ko) ;
  USBMOUNT (4 032) prend 2 blocs, 64 octets libres (87 en anglais) ; MKTAP (4 079)
  aussi, à 17 octets près (57 en anglais). EDSPRITE (8 967) prend
  5 blocs, 1 273 octets libres dans le dernier. Les disquettes se spécialisent plutôt
  que de gratter des octets ;
- EDIT (8 704 octets) prend 5 blocs, 1 536 octets libres dans le dernier (tampon de texte
  aligné sur une page ; en anglais, 243 octets de code avant la page suivante, 71 en
  français). HEX : 47 octets avant le bloc suivant (143 en anglais) ; ASM (6 140) est à 4
  octets du bloc suivant, 80 en anglais (6 064) : un message français de plus doit être
  compensé ;
- usage à deux disquettes : sur `cpa.dsk` il reste 86 Ko (86 sur `cpa-en.dsk`), peu pour travailler (CARTE :
  `CARTE.ASM` 46 Ko) ; le travail va sur une disquette de projet en B:, GRXASM `/C` ne
  laisse que le `.COM`, ASM n'écrit le `.SYM` que sur demande (`/S`) ;
- blocs de 1 Ko (−27 Ko sur `cpa.dsk`) : format du répertoire à changer, anciennes
  disquettes illisibles ; en dernier recours.

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
