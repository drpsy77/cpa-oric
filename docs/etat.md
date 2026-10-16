# CP/A disquette — état et suite

Système « à la CP/M » pour Oric Atmos, chargé depuis une disquette (Microdisc, LOCI) dans les
16 Ko de RAM overlay, et enrichi par des programmes `.COM` plutôt que par du code résident.
Usages visés : développer sur l'Oric lui-même, gérer des fichiers et des données, communiquer
(réseau par le LOCI). À lire avec `docs/architecture.md`.

## 1. Ce qui existe (version 0.9)

**Système** : code `$C000-$F623`, **marge 77 octets** jusqu'à `$F670` (200 sans l'option
`CPLCMD`) ; page `$FF00-$FFB7`, marge 66 octets. `./build.sh` affiche les deux marges.

- console : pause en fin d'écran, menus déroulants (FUNCT), voyants `A`/`a` et `P`, couleurs
  et pagination (`PAPER`, `INK`, `PAGE`) ;
- lecture de ligne (BDOS 10) : édition, historique, complétion par ESC des noms de fichiers
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
| HELP | 10 047 | aide par rubriques (textes compressés) | `manuel.md` |
| TYPE, ERA, REN, SET, STAT, COPY | 177 à 1 033 | fichiers | `manuel.md` |
| FORMAT, DISKCOPY | 1 685, 1 658 | disquettes, avec un seul lecteur | `manuel.md` |
| CMDER | 13 552 | gestionnaire de fichiers plein écran, deux colonnes, clé USB | `cmder.md` |
| EXPORT, IMPORT, USBDIR | 1 750, 1 706, 994 | échange avec la clé USB du LOCI | `manuel.md` |
| XDO | 1 351 | appel de script à script | `manuel.md` |
| EDIT | 8 192 | éditeur de texte | `manuel.md` |
| HEX | 3 840 | éditeur hexadécimal | `manuel.md` |
| ASM | 5 949 | assembleur 6502 (identique à xa sur nos sources) | `manuel.md` |
| DEBUG | 6 496 | moniteur, désassembleur, pas à pas | `manuel.md` |
| MEM, POKE, GO | 674, 254, 221 | mémoire | `manuel.md` |
| LOGO | 18 950 | Logo en français : tortue, décimaux, listes, son, écran texte | `logo.md` |
| GRAPHER, GRXASM | 14 213, 13 981 | langage de dessin et de jeux (`.GRX`) : interpréteur, traducteur en assembleur (tableaux à adresse fixe, seules routines utiles des bibliothèques) ; fichiers de données, sprites en mode texte (`.SPR`) | `grapher.md` |
| VOIR, VSYNC | 3 418, 744 | images, animations ; calage du top sur le balayage | `manuel.md` |
| HELLO, GTEST | 88, 156 | exemples d'assembleur | — |

Disquettes : `cpa.dsk` (tout), `cpa-logo.dsk`, `cpa-notes.dsk`, `cpa-asm.dsk`,
`cpa-anim.dsk` ; contenu dans `docs/manuel.md`.

**Sur le vrai matériel** : ce qui a été vérifié et ce qui reste à vérifier est dans
`docs/essais-materiel.md`, à lire seulement quand on en a besoin.

## 2. Suite prévue (par priorité)

1. **Phases d'un jeu** (`RUN`, à décider : `docs/grapher.md` § 17). Les programmes
   traduits sont maintenant petits (seules routines utiles des bibliothèques : 1,5 à 6,4 Ko
   pour les exemples) et rapides (tableaux à adresse fixe).
2. **Sprites en mode texte** : faits dans GRAPHER (`SPRITES`, `SPOOL`, `SSHOW`, `SHIDE`,
   bibliothèque `SPR.INC` ; `docs/grapher.md` § 7.1, § 10.1). Reste : les tuiles, à préciser
   (`docs/grapher.md` § 17), puis l'éditeur de caractères et de sprites (`.COM` plein
   écran) ; LOGO ensuite peut-être.
3. **Réseau par le LOCI** (matériel : `docs/loci-modem-wifi.md`, pas encore acheté) : pilote
   série dans le BIOS sur PUNCH / READER (ACIA 6551, `$0380` sur le LOCI, `$031C` dans
   Oricutron ; ~150 octets estimés, donc ~300 à prévoir : il faut d'abord libérer de la place,
   § 3) ; `XFER.COM` (XMODEM) et `tools/xfer_server.py` ; `TERM.COM` (commandes AT).
4. **Petites améliorations notées**
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

Écarté : `REDIM` dans GRAPHER (hors de l'esprit du langage : les tailles sont connues à
l'écriture) ; modules chargeables pour LOGO (le chargement par étapes avec `CHARGE` et `OUBLIE`
suffit) ; primitive LOGO générique `.SYSTEME n [liste]` ; conversion CR LF -> LF par EXPORT.

## 3. Réserves de place

**Système** (marge 77 octets) :

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
- GRAPHER (14 213 octets) prend 7 blocs, 123 octets libres dans le dernier (les tuiles
  demanderont un 8e bloc, ou la place des pistes qui suivent) ; pistes de place : messages d'erreur par numéro, ~40 octets ; ANIM
  partagé avec `a_grx` de `anim.inc`, ~40 ; code de `anim.inc` propre aux programmes
  traduits, `a_grx`, 106 octets inutiles à l'interpréteur. GRXASM (13 981) prend 7 blocs,
  355 octets libres dans le dernier ; GRX.INC (10 887, marques `;@` comprises) prend 6 blocs,
  647 octets de trop pour 5 ;
- EDIT fait exactement 8 192 octets : le moindre ajout coûte un bloc. ASM et HEX sont à moins
  de 260 octets du bloc suivant ;
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
