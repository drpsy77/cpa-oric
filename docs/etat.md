# CP/A disquette — état et suite

Système « à la CP/M » pour Oric Atmos, chargé depuis une disquette (Microdisc, LOCI) dans les
16 Ko de RAM overlay, et enrichi par des programmes `.COM` plutôt que par du code résident.
Usages visés : développer sur l'Oric lui-même, gérer des fichiers et des données, communiquer
(réseau par le LOCI). À lire avec `docs/architecture.md`.

## 1. Ce qui existe (version 0.9)

**Système** : code `$C000-$F633`, **marge 61 octets** jusqu'à `$F670` (184 sans l'option
`CPLCMD`) ; page `$FF00-$FFE7`, marge 18 octets (table des touches de l'édition de ligne). `./build.sh` affiche les deux marges.

- console : pause en fin d'écran, menus déroulants (FUNCT), voyants `A`/`a` et `P`, couleurs
  et pagination (`PAPER`, `INK`, `PAGE`) ;
- clavier : CTRL-H à CTRL-K distincts des flèches (28-31), CTRL-ESPACE (0), SHIFT et CTRL
  avec les flèches (`$F0-$F7`) ; mêmes touches dans EDIT, HEX, CMDER et la ligne de commande
  (`docs/manuel.md`, « Les mêmes touches partout ») ;
- lecture de ligne (BDOS 10) : édition, historique, complétion par TAB ou ESC des noms de fichiers
  et, en début de ligne, des commandes (sur les lecteurs où elles seraient cherchées) ;
- fichiers CP/M 2.2 (séquentiel, accès direct, attributs R/O et SYS), lecteurs A: à D: ;
- programmes et scripts cherchés sur le lecteur du script (ou le courant), puis A: à D: ;
  scripts `.BAT` (DO, `$1`-`$9`, appel de script à script par XDO) ; CHAIN (BDOS 47) ;
- imprimante Centronics (LIST, BDOS 5, CTRL-P) ;
- graphisme SPLIT (BDOS 115), son AY (BDOS 116) ; HIRES plein écran et écran texte (LORES)
  laissés aux programmes, avec retour assuré par le démarrage à chaud ;
- reprise après plantage (BRK, RESET).

Détail du fonctionnement interne : `docs/systeme.md`. Mode d'emploi : `docs/manuel.md`.

**Programmes**

| Programme | Octets | Rôle | Documentation |
|---|---:|---|---|
| HELP | 10 888 | aide par rubriques (textes compressés) | `manuel.md` |
| TYPE, ERA, REN, SET, STAT, COPY | 177 à 1 033 | fichiers | `manuel.md` |
| FORMAT, DISKCOPY | 1 685, 1 658 | disquettes, avec un seul lecteur | `manuel.md` |
| CMDER | 13 581 | gestionnaire de fichiers plein écran, deux colonnes, clé USB | `cmder.md` |
| EXPORT, IMPORT, USBDIR | 1 750, 1 735, 994 | échange avec la clé USB du LOCI | `manuel.md` |
| XDO | 1 351 | appel de script à script | `manuel.md` |
| EDIT | 8 192 | éditeur de texte | `manuel.md` |
| HEX | 3 840 | éditeur hexadécimal | `manuel.md` |
| ASM | 5 949 | assembleur 6502 (identique à xa sur nos sources) | `manuel.md` |
| DEBUG | 6 496 | moniteur, désassembleur, pas à pas | `manuel.md` |
| MEM, POKE, GO | 674, 254, 221 | mémoire | `manuel.md` |
| LOGO | 18 960 | Logo en français : tortue, décimaux, listes, son, écran texte | `logo.md` |
| GRAPHER, GRXASM | 15 555, 14 498 | langage de dessin et de jeux (`.GRX`) : interpréteur, traducteur en assembleur (aucun contrôle à l'exécution, tableaux à adresse fixe, seules routines utiles des bibliothèques) ; fichiers de données, sprites en mode texte (`.SPR`) ; rectangles (copie d'un tableau vers l'écran, défilement, rotation), écriture verticale | `grapher.md` |
| VOIR, VSYNC | 3 353, 744 | images, animations ; calage du top sur le balayage | `manuel.md` |
| HELLO, GTEST | 88, 156 | exemples d'assembleur | — |

Disquettes : `cpa.dsk` (tout), `cpa-logo.dsk`, `cpa-notes.dsk`, `cpa-asm.dsk`,
`cpa-anim.dsk` ; contenu dans `docs/manuel.md`.

**Mesure** : 1 254 points de fonction IFPUG et 300 points d'algorithmes ; détail, lignes,
octets et documentation dans `docs/points-de-fonction.md`.

**Sur le vrai matériel** : ce qui a été vérifié et ce qui reste à vérifier est dans
`docs/essais-materiel.md`, à lire seulement quand on en a besoin.

## 2. Suite prévue (par priorité)

1. **Phases d'un jeu** (`RUN`, à décider : `docs/grapher.md` § 17). Les programmes
   traduits sont maintenant petits (seules routines utiles des bibliothèques : 1,5 à 6,4 Ko
   pour les exemples) et rapides (tableaux à adresse fixe).
2. **Sprites en mode texte** : faits dans GRAPHER (`SPRITES`, `SPOOL`, `SSHOW`, `SHIDE`,
   bibliothèque `SPR.INC` ; `docs/grapher.md` § 7.1, § 10.1). Rectangles faits (`PASTE`,
   `GRAB`, `SCROLH`, `SCROLV`, `ROTH`, `ROTV`, `PRINTV`, `ECHOV`, `SPCV` : § 7.2). Reste :
   les tuiles, `TILESET` et `TMAP`, décidées (`docs/grapher.md` § 16.1), puis leurs dessins
   depuis un `.SPR` et les caractères animés (§ 16.2, § 17), puis l'éditeur de caractères et de sprites (`.COM` plein
   écran) ; LOGO ensuite peut-être.
3. **CP/A pour l'Oric sous BASIC** (`docs/oric-basic.md`) : `MKTAP.COM` et `tools/mktap.py`
   (décidé), puis une boîte à outils appelée par `!` depuis le BASIC, ou GRXASM vers un
   programme autonome (`.TAP`) ; ordre à choisir.
4. **Réseau par le LOCI** (matériel : `docs/loci-modem-wifi.md`, pas encore acheté) : pilote
   série dans le BIOS sur PUNCH / READER (ACIA 6551, `$0380` sur le LOCI, `$031C` dans
   Oricutron ; ~150 octets estimés, donc ~300 à prévoir : il faut d'abord libérer de la place,
   § 3) ; `XFER.COM` (XMODEM) et `tools/xfer_server.py` ; `TERM.COM` (commandes AT).
5. **Défauts constatés** (reproduits dans Oricutron sur `cpa.dsk`)
   - GRAPHER, `SAVE`, `BSAVE`, `BSAVE SCREEN` (`progs/fil.inc`) : l'ancien fichier est effacé
     avant l'écriture ; disque plein en cours d'écriture : ancien contenu perdu, fichier de
     0 octet. À écrire comme EDIT (`NOM.$$$` puis remplacement). Un fichier R/O reste intact
     (le BDOS le protège) mais le message dit à tort `disque plein`.
   - EDIT, Enregistrer sous : depuis un document R/O (README.TXT), tout nom est refusé
     (`Fichier protege (R/O)`, même un nom nouveau) : l'indicateur R/O que l'ouverture met
     dans le FCB (octet 13) reste après `take_name`, qui ne recopie que le nom.
   - EDIT, Enregistrer sous un fichier existant : remplacé sans question (HELLO.ASM sous
     HELLO.COM écrase le programme) ; demander `Remplacer NOM.EXT (O/N) ?`.
   - EDIT, Enregistrer sous un fichier R/O : `Enregistre` affiché, rien n'est remplacé (le
     fichier R/O reste intact) et `NOM.$$$` reste sur la disquette ; le résultat du
     renommage n'est pas regardé.
   - GRAPHER : pas de moyen de savoir si un fichier existe sans le charger (`FOUND` ne vaut
     qu'après `LOAD` ou `BLOAD`) ; une fonction du genre `EXIST("NOM")`, ou une commande qui
     pose `FOUND`, à décider.
6. **Petites améliorations notées**
   - `AUTO.BAT` exécuté au démarrage ;
   - son dans les scripts : commande `NOTE` au prompt ou `PLAY.COM` (partition texte) ;
   - LOGO : ne pas perdre la frappe anticipée pendant `NOTE` / `ATTENDS` ; passer des
     paramètres d'un script à `LOGO NOM` ; tokenisation des procédures (vitesse, place), à
     décider sur mesure ;
   - GRAPHER : exemples de fichiers de données : un
     niveau écrit dans EDIT (`LOAD`), un écran titre (`BLOAD SCREEN`) ;
   - EDIT : un paragraphe sur une seule ligne avec défilement horizontal ; une édition plein
     écran (colonnes 0-1 comprises) pour dessiner un écran texte ;
   - USBDIR : liste des appareils du LOCI (`opendir("")`) ;
   - une base de données simple sur l'accès direct (piste).
7. **Version anglaise** (plus tard, approche à valider) : un build par langue (`LANG=en`),
   messages de chaque programme dans un fichier inclus par langue, aide de HELP en deux
   listes, primitives de LOGO en anglais (FORWARD, TO... END : les `.LOG` dépendent de la
   langue), exemples traduits ; documentation : `README.md` en anglais, documents
   d'utilisation dans `docs/en/` (mêmes noms), documents internes en français seulement.

Écarté : `REDIM` dans GRAPHER (hors de l'esprit du langage : les tailles sont connues à
l'écriture) ; modules chargeables pour LOGO (le chargement par étapes avec `CHARGE` et `OUBLIE`
suffit) ; primitive LOGO générique `.SYSTEME n [liste]` ; conversion CR LF -> LF par EXPORT.

## 3. Réserves de place

**Système** (marge 61 octets ; page `$FF00` : 18 octets) :

| Piste | Gain estimé | Prix |
|---|---:|---|
| H : masque de point calculé au lieu de la table `g_xbit` (240 octets) | ~220 | un peu plus lent en SPLIT |
| Police rangée sur 5 octets par caractère, dépliée par `font_init` | ~250 | le texte de `gfx.s` doit lire la police recopiée |
| I : test de RAM réduit à un remplissage, test complet en `.COM` | ~105 | — |
| Code répété (`g_box`/`g_line`, `go`/`f_delete`, `cmd_put`/`run_transient`) | < 500 | coût des `JSR` |
| Option `CPLCMD` retirée (complétion des commandes) | 123 | perte de la fonction |

Écartés : commandes graphiques du CCP en `.COM` (scripts ralentis), compression du clavier.

**Disquettes** (blocs de 2 Ko : un octet gagné ne rend un bloc qu'en repassant sous un
multiple de 2 048) :

- tampons stockés dans le fichier, à sortir après la fin du programme : DEBUG (122), EDIT
  (842), HEX (432), XDO (512) ;
- GRAPHER (15 555 octets) prend 8 blocs, 829 octets libres dans le dernier (place des
  tuiles) ; piste de place : messages d'erreur par numéro, ~40 octets. GRXASM (14 498) prend
  8 blocs ; GRX.INC (11 816 octets sur la disquette, marques `;@` comprises) prend 6 blocs, 472 octets avant le 7e. HELP (10 888) prend 6 blocs. Les disquettes se
  spécialisent plutôt que de gratter des octets ;
- EDIT fait exactement 8 192 octets : 57 octets de code de plus le feraient passer au bloc
  suivant (tampon de texte aligné sur une page). HEX : 47 octets ; ASM est à moins de 260
  octets du bloc suivant ;
- blocs de 1 Ko (−27 Ko sur `cpa.dsk`) : format du répertoire à changer, anciennes
  disquettes illisibles ; en dernier recours.

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
