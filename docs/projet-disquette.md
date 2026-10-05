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
HEX (éditeur hexa par fenêtres, écriture sur place), LOGO (français, tortue, sons, clavier
LISCAR / TOUCHE?, valeurs typées), ASM
(assembleur 6502, identique à `xa` sur nos sources, écrit `.SYM`), DEBUG (moniteur,
désassembleur symbolique, pas à pas), STAT (taille des fichiers en enregistrements, blocs et
octets ; place libre), MEM (carte mémoire), POKE et GO (écrire et lancer du code), COPY, GTEST,
HELLO.

**Essayé sur matériel** (Oric Atmos + LOCI) : démarrage, menus, EDIT, PUT, DIR, SPLIT, GTEST,
LOGO, STAT, MEM, POKE et GO. Restent à essayer sur le vrai Oric : ASM, DEBUG, HEX en écriture
sur place, DO, le son, l'édition de ligne (flèches, historique, complétion par ESC), le mode
SPLIT avec la bascule en `$BFDF` (premier octet `$A000` visible, ligne 27 vide), LISCAR et
TOUCHE? dans LOGO.

## Choix déjà faits (et pourquoi)

- HELP, MEM, DUMP, POKE, GO ne sont plus internes, la place libérée sert au BDOS. HELP.COM
  remplace HELP, DEBUG remplace DUMP. MEM, POKE et GO sont revenus en `.COM` : DEBUG ne
  démarre qu'avec un programme à charger, il ne pouvait pas en tenir lieu.
- POKE.COM et GO.COM tiennent chacun dans `$0500-$05FF` (2 enregistrements) : à partir de
  `$0600`, la mémoire est préservée d'un appel à l'autre. POKE décode tous les octets avant
  d'écrire, puis copie depuis la page zéro (`$D0-$DD`) : un POKE en `$0500` suivi d'un SAVE
  marche. GO passe la suite de la ligne au code lancé (`$0480`, FCB1), comme DEBUG.
- STAT.COM (nom de CP/M) donne la taille en octets en retirant les `^Z` du dernier
  enregistrement : le répertoire CP/M 2.2 n'a pas de compteur d'octets. Exact pour les textes
  et pour les fichiers copiés par `mkdisk.py`. La place libre est calculée d'après les entrées
  du répertoire (le BDOS n'a pas la fonction 27 de CP/M, et on ne l'ajoute pas pour ça).
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
- LOGO, lot 2 : les valeurs intermédiaires de l'évaluateur passent par une pile de valeurs
  (24 valeurs de 6 octets) au lieu de la pile du 6502 ; c'est elle, avec les variables et les
  paramètres, qui servira de racine au compactage du tas. Le tas lui-même attend le lot 5 :
  avant les mots, rien ne l'utiliserait et il ne pourrait pas être essayé.
- LOGO : une touche lue par le test d'ESC pendant l'exécution est gardée (`pkey`) pour LISCAR et
  TOUCHE? au lieu d'être jetée ; on ne garde que la dernière, oubliée au retour au prompt.
- LOGO : DONNE gardait le nom de la variable dans `p3` pendant l'évaluation, que la recherche
  des fonctions (HASARD, CAP...) écrase : `DONNE "X CAP` créait une variable au mauvais nom.
  Le nom est maintenant gardé sur la pile du 6502.

## Suite prévue (par priorité)

0. **LOGO : nombres décimaux, saisie, mots et listes** (en cours, un commit par livraison). Choix :
   - nombres « à la Oric » : flottant de 5 octets (exposant + mantisse de 32 bits, ~9 chiffres) ;
     en interne deux types, entier 16 bits et décimal ; un entier qui déborde devient décimal,
     `/` est une division exacte (QUOTIENT et RESTE pour la division entière) ; point décimal ;
   - la tortue garde ses calculs entiers et sa virgule fixe : un décimal est converti à l'entrée
     des primitives (distances et coordonnées au 1/256, cap fractionnaire avec interpolation du
     sinus, arrondi au plus proche pour REPETE, NOTE, ATTENDS ; erreur hors de portée) ;
   - valeur = 6 octets (type + 5 octets) ; mots et listes = adresse et longueur d'un texte dans
     un tas qui descend du haut de la mémoire, les procédures montant du bas ; compactage du tas
     (racines : variables, paramètres, pile de valeurs) ;
   - une liste est un texte entre crochets ; une sous-liste est un groupe `[...]` (PREMIER le
     rend entier, par comptage des crochets). Listes emboîtables sans cellules ; EXECUTE gratuit.

   | Lot | Contenu | Complexité | Code | État |
   |---|---|---|---|---|
   | 1 | LISCAR, TOUCHE? | faible | ~60 o | **fait** |
   | 2 | valeurs typées (6 octets), pile de valeurs, variables et paramètres typés | élevée | ~300 o (+530 o de variables) | **fait** (le tas passe au lot 5) |
   | 3 | décimaux : 4 opérations, comparaisons, lecture/affichage, conversions, promotion, QUOTIENT, RESTE, ENT, ARRONDI, ABS | élevée | ~2-2,3 Ko | à faire |
   | 4 | tortue et décimaux (conversions, cap fractionnaire, contrôles de plage) | moyenne | ~250 o | à faire |
   | 5 | mots et listes : tas et compactage, MOT, PHRASE, LISTE, PREMIER, DERNIER, SAUFPREMIER, SAUFDERNIER, ITEM, COMPTE, VIDE?, MOT?, NOMBRE?, LISTE?, MEMBRE?, `=` sur les textes, ECRIS et EXECUTE de listes ; un mot qui a l'air d'un nombre compte comme un nombre | élevée | ~1,1-1,4 Ko + tas | à faire |
   | 6 | LISLISTE (et LISMOT) ; LISCAR rendra alors un caractère (code par ASCII) | faible | ~150 o + 128 o | à faire |
   | 7 | RACINE, SIN, COS, ARCTAN ; en option LN, EXP, PUISSANCE (+~500 o) | moyenne | ~700 o | à faire |
   | 8 | option : RENDS (procédures qui renvoient une valeur ; l'évaluateur est récursif, les procédures non) | élevée | ~400-600 o | à décider |

   Mémoire visée après les lots 1 à 7 : LOGO.COM ~13-14 Ko (7,6 Ko aujourd'hui), zone libre
   ~21 Ko en SPLIT partagée entre procédures et textes (27 Ko aujourd'hui, 28 Ko avant le lot 2).
   Chaque lot passe `tools/test_logo.sh` ; ses références ne changent que là où le lot change
   volontairement un résultat (par exemple `7 / 2` au lot 3).

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
