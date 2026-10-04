# Projet « CP/A disquette » — système évolutif, développement, gestion, communication

À lire avec `docs/architecture.md` (contrat d'interface commun avec la version ROM).

## But

Un système à la CP/M pour Oric Atmos, chargé depuis une disquette (Microdisc, Cumulus, LOCI)
dans les 16 Ko de RAM overlay. Il s'enrichit par des commandes `.COM` sur le disque plutôt que par
du code résident. Usages visés : développer sur l'Oric lui-même, gérer des fichiers et des
données, communiquer (réseau par le LOCI).

## État (version 0.9)

**Système** (`$C000-$F4BF`, marge 433 octets jusqu'à `$F670`) :

- console avec pause en fin d'écran, menus déroulants, reprise après plantage (BRK, RESET) ;
- lecture de ligne (BDOS 10, `src/rline.s`) : curseur ← →, insertion, DEL / CTRL-D, CTRL-A / E,
  historique ↑ ↓ (256 octets, garde ses lignes au démarrage à chaud), complétion des noms de
  fichiers par ESC (partie commune, puis liste des noms possibles) ;
- fichiers CP/M 2.2 : séquentiel, accès direct (33-36), attributs R/O et SYS (30) ;
- mode SPLIT (240 × 128 + barre + 10 lignes de texte ; bascule en `$BFDF` comme le BASIC, `$A000`
  utilisable), graphisme BDOS 115, images `.IMG` ;
- son BDOS 116 (notes, bruit, enveloppe, durées gérées par l'IRQ) ;
- CCP : DIR, DIRS, TYPE, ERA, REN, SAVE, VER, CLS, SPLIT, TEXT, GCLS, PEN, PLOT, LINE, BOX,
  FBOX, CIRCLE, GTEXT, ATTR, POINT, GSAVE, GLOAD, PUT (sortie vers un fichier), DO (scripts
  `.BAT` avec `$1`-`$9`), ECHO, PAUSE.

**Programmes** : HELP (aide par rubriques), SET (attributs), EDIT (éditeur, insertion de fichier),
HEX (éditeur hexa par fenêtres, écriture sur place), LOGO (français, tortue, sons), ASM
(assembleur 6502, identique à `xa` sur nos sources, écrit `.SYM`), DEBUG (moniteur,
désassembleur symbolique, pas à pas), COPY, GTEST, HELLO.

**Essayé sur matériel** (Oric Atmos + LOCI) : démarrage, menus, EDIT, PUT, DIR, SPLIT, GTEST,
LOGO. Restent à essayer sur le vrai Oric : ASM, DEBUG, HEX en écriture sur place, DO, le son,
l'édition de ligne (flèches, historique, complétion par ESC), le mode SPLIT avec la bascule
en `$BFDF` (premier octet `$A000` visible, ligne 27 vide).

## Choix déjà faits (et pourquoi)

- HELP, MEM, DUMP, POKE, GO ne sont plus internes : HELP.COM et DEBUG les remplacent, la place
  libérée sert au BDOS.
- PUT n'écrit jamais sur le disque pendant un affichage : tampon de 1 280 octets vidé à l'entrée
  de l'appel BDOS suivant, état du système de fichiers sauvé puis rendu.
- HEX écrit sur place (accès direct) au lieu de réécrire tout le fichier ; quitter une fenêtre
  modifiée d'un gros fichier l'écrit.
- DEBUG se place en `$8400-$9FFF` et abaisse le haut de la TPA (plafond `$02A9`).
- Édition de ligne dans le BDOS (fonction 10) et non dans le CCP : LOGO et DEBUG en profitent
  aussi, et la ROM l'a (sans la complétion). Coût : 834 octets résidents. La ligne est éditée
  dans `$BA00` (126 caractères au plus) et l'historique est en `$BA80-$BB7F` : fin du jeu de
  caractères alternatif, que les menus n'utilisent qu'au début (98 octets au plus aujourd'hui,
  512 possibles). Un seul historique pour le CCP et les programmes.
- Complétion par ESC (comme le `filec` du C-shell ; ESC est à la place de TAB) : CTRL-I vaut
  `$09`, la flèche droite. Elle lit le répertoire directement (`dir_get`), sans toucher au DMA
  ni au FCB des programmes ; seule une recherche 17/18 en cours chez l'appelant serait perdue.
  Pas de jokers ; les noms sont complétés en minuscules quand les majuscules sont coupées.
- Flèches : gauche `$08` n'efface plus (DEL le fait), bas `$0A` ne valide plus la ligne.
- SPLIT : l'attribut HIRES n'est plus en `$BB80` (il masquait l'octet `$A000` dans Oricutron, et
  toute la ligne de points 0 sur le vrai circuit, qui change de mode à la ligne suivante) mais en
  `$BFDF`, comme le BASIC. Prix : la ligne de texte 27 ne contient que des attributs, la console
  SPLIT passe de 11 à 10 lignes (variable `con_last`). Seul `$B3D8` (retour au texte) reste pris.

## Suite prévue (par priorité)

1. **Réseau par le LOCI** (matériel décrit dans `docs/loci-modem-wifi.md`, pas encore acheté) :
   - pilote série dans le BIOS, branché sur PUNCH / READER : ACIA 6551 en `$0380` sur le LOCI
     (`$031C` dans Oricutron), adresse dans une variable, ~150 octets ;
   - `XFER.COM` : envoi et réception de fichiers en XMODEM (paquets de 128 octets acquittés) ;
   - `tools/xfer_server.py` : serveur XMODEM sur le Mac ;
   - `TERM.COM` : terminal (commandes AT du modem PicoWiFiModemUSB).
2. Petites améliorations notées : `AUTO.BAT` exécuté au démarrage ; commande `NOTE` au prompt
   (son dans les scripts) ou `PLAY.COM` (partition texte) ; ne pas perdre la frappe anticipée
   pendant `NOTE`/`ATTENDS` dans LOGO ; raccourci clavier pour « Insérer » dans EDIT.
3. Pistes : export direct d'un fichier vers la clé USB du LOCI (API MIA en `$03A0`) ; base de
   données simple sur l'accès direct.

## Contraintes à garder en tête

- 433 octets libres dans le système : tout ajout résident se justifie, le reste va en `.COM`
  (le pilote série prévu en demande ~150).
- Les interruptions sont coupées pendant les accès disque (une touche peut être perdue, le
  compteur 50 Hz retarde).
- Ne rien changer au contrat d'interface (`docs/architecture.md`) sans penser à la version ROM.
