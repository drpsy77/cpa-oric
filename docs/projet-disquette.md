# Projet « CP/A disquette » — système évolutif, développement, gestion, communication

À lire avec `docs/architecture.md` (contrat d'interface commun avec la version ROM).

## But

Un système à la CP/M pour Oric Atmos, chargé depuis une disquette (Microdisc, Cumulus, LOCI)
dans les 16 Ko de RAM overlay. Il s'enrichit par des commandes `.COM` sur le disque plutôt que par
du code résident. Usages visés : développer sur l'Oric lui-même, gérer des fichiers et des
données, communiquer (réseau par le LOCI).

## État (version 0.9)

**Système** (`$C000-$F5E2`, marge 142 octets jusqu'à `$F670`) :

- console avec pause en fin d'écran, menus déroulants, reprise après plantage (BRK, RESET) ;
- imprimante sur le port Centronics (LIST, BDOS 5), copie de la console par CTRL-P ou par
  l'article Imprimante du menu Systeme ;
- voyants au bout de la barre de menus : `A` / `a` (majuscules / minuscules), `P` (imprimante) ;
- lecture de ligne (BDOS 10, `src/rline.s`) : curseur ← →, insertion, DEL / CTRL-D, CTRL-A / E,
  historique ↑ ↓ (256 octets, garde ses lignes au démarrage à chaud), complétion des noms de
  fichiers par ESC (partie commune, puis liste des noms possibles) ;
- fichiers CP/M 2.2 : séquentiel, accès direct (33-36), attributs R/O et SYS (30) ;
- mode SPLIT (240 × 128 + barre + 10 lignes de texte ; bascule en `$BFDF` comme le BASIC, `$A000`
  utilisable), graphisme BDOS 115, images `.IMG` ;
- son BDOS 116 (notes, bruit, enveloppe, durées gérées par l'IRQ) ;
- CCP : DIR, DIRS, TYPE, ERA, REN, SAVE, VER, CLS, SPLIT, TEXT, GCLS, PEN, PLOT, LINE, BOX,
  FBOX, CIRCLE, GTEXT, ATTR, POINT, GSAVE, GLOAD, PUT (sortie vers un fichier), DO (scripts
  `.BAT` avec `$1`-`$9`, lancés aussi par leur nom, appel de script à script par XDO.COM),
  ECHO, PAUSE.

**Programmes** : HELP (aide par rubriques), SET (attributs), EDIT (éditeur, insertion de fichier),
HEX (éditeur hexa par fenêtres, écriture sur place), LOGO (français, tortue, sons, clavier
LISCAR / TOUCHE?, valeurs typées, nombres décimaux, mots et listes, fonctions de l'utilisateur
avec RENDS, écran texte, aller-retour avec EDIT par EDITE), ASM
(assembleur 6502, identique à `xa` sur nos sources, écrit `.SYM`), DEBUG (moniteur,
désassembleur symbolique, pas à pas), STAT (taille des fichiers en enregistrements, blocs et
octets ; place libre), MEM (carte mémoire), POKE et GO (écrire et lancer du code), XDO (appel
de script à script), COPY, GTEST, HELLO.

**Essayé sur matériel** (Oric Atmos + LOCI) : démarrage, menus, EDIT, PUT, DIR, GTEST, LOGO,
STAT, MEM, POKE, GO et DO ; l'historique des lignes (flèche haut) au prompt de CP/A et dans
LOGO, ← → dans LOGO ; la complétion des noms par ESC ; le mode SPLIT avec la bascule en `$BFDF` ; dans LOGO,
les décimaux et la tortue avec des décimaux (vitesse jugée meilleure que le BASIC). DEBUG
démarre, mais n'a pas encore servi à déboguer pour de vrai. Restent à essayer sur le vrai
Oric : ASM (jamais lancé), DEBUG en usage réel (points d'arrêt, pas à pas), HEX en écriture
sur place, le son, et dans LOGO : LISCAR, TOUCHE?, les mots et les listes, LISLISTE,
les fonctions RACINE, SIN, COS, ARCTAN, LN, EXP, RENDS (FACT, FIBO, profondeur),
ECRANTEXTE et ECRANMIXTE (avec le menu Tortue), EDITE et le Retour d'EDIT (temps d'écriture
et de lecture de LOGO.$$$, image gardée), `LOGO NOM`.

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
- LOGO, lot 3 : les décimaux sont dans une bibliothèque à part, `progs/fp_inc.s` (format du
  BASIC de l'Oric, routines écrites pour CP/A), testée seule par `tools/test_fp.py` contre un
  calcul exact : + - * / à 0,5 ulp, lecture au demi-bit près pour les nombres courts.
  QUOTIENT est la division entière (vers zéro), RESTE a le signe du dividende ; ENT tronque,
  ARRONDI éloigne 0,5 de zéro. Un résultat décimal reste décimal même s'il tombe juste
  (`0.5 * 4` vaut 2, de type décimal) : l'affichage est le même, et les primitives qui veulent
  un entier arrondissent. En attendant le lot 4, la tortue reçoit elle aussi un entier
  arrondi ; l'arbre de DEMO a ainsi un niveau de plus (10,67 n'est plus tronqué à 10).
- LOGO, lot 4 : la tortue reçoit des décimaux en virgule fixe (1/256) ; le cap a un octet de
  fraction (`headf`). La table de sinus passe de 256 * sin à 65536 * sin (16 bits ; 90° est
  traité à part, sinus = 1 exactement) : sans cela, `FIXECAP 30 AV 100` plaçait YCOR à 86.72
  au lieu de 86.60, ce que les décimaux rendaient visible. Écart mesuré sur 14 caps : 0,006 au
  plus. Conséquence : les dessins changent d'un point par endroits (DEMO, et l'heptagone de
  `360 / 7` se referme). XCOR, YCOR, CAP : entier si la tortue est sur un point entier, sinon
  arrondis à 2 décimales (la précision est de 1/256).
- LOGO, lot 5 : les mots et listes sont des textes dans un tas (`progs/ltxt_inc.s`), qui
  descend de memtop pendant que les procédures montent. Compactage à la manière du BASIC
  Microsoft : le texte encore désigné le plus haut monte contre memtop, et ainsi de suite.
  Deux règles le rendent sûr : un résultat est toujours une copie (jamais un morceau d'un
  autre texte), et seules comptent les variables, les arguments et la pile de valeurs ; une
  primitive qui réserve de la place y empile d'abord ses textes. Une liste est rangée
  normalisée : une espace entre éléments, aucune après `[` ni avant `]`. EXECUTE copie la
  liste dans une pile à part de 512 octets (`xstack`), que le compactage ne touche pas.
  Un mot cité va jusqu'au blanc ou au crochet (`"-3.5`). LISTE est une fonction dans une
  expression et reste la commande d'affichage d'une procédure en début de ligne. Les
  booléens restent 1 et 0 (VRAI et FAUX viendront si on en a besoin).
- LOGO, lot 6 : LISLISTE et LISMOT lisent par la fonction 10 du BDOS (édition, historique)
  dans leur propre tampon (`llbuf`), passent la ligne en majuscules comme au prompt, et
  réutilisent la normalisation des listes. Une touche tapée avant la lecture est oubliée.
  ESC n'interrompt pas pendant la lecture (il complète un nom de fichier, comme au prompt).
  LISCAR rend désormais un caractère : `ASCII LISCAR` donne le code, `CAR n` l'inverse.
- LOGO, lot 7 : les fonctions sont dans `fp_inc.s` (utilisables par d'autres programmes) :
  séries de Taylor à coefficients exacts sur un petit intervalle, évaluées par Horner.
  RACINE par Newton ; EXP par 2^n e^u avec la réduction de Cody et Waite (LN 2 en deux
  parties) ; LN par 2 atanh((m - 1) / (m + 1)) ; SIN et COS en quarts de tour (les angles
  remarquables tombent juste : COS 90 = 0) ; ARCTAN par 1/x et la formule de 30°. Écarts
  mesurés par `tools/test_fp.py` : RACINE 0,5 ulp, EXP 0,9, LN 1,75, ARCTAN 1,5 ; SIN en
  degrés 1,5E-9. En radians (`fp_sin`, `fp_cos`, inutilisés par LOGO), l'erreur croît avec
  l'argument : 1E-8 vers 50 radians. PUISSANCE n'est pas prévue : elle s'écrit en Logo.
- LOGO : DONNE gardait le nom de la variable dans `p3` pendant l'évaluation, que la recherche
  des fonctions (HASARD, CAP...) écrase : `DONNE "X CAP` créait une variable au mauvais nom.
  Le nom est maintenant gardé sur la pile du 6502.

- LOGO, lot 8 : RENDS. Une procédure appelée dans une expression (`primary`) passe par
  `call_func` : contexte `FR_FUNC`, puis une boucle `run` imbriquée. Pour ne pas limiter la
  profondeur à la pile du 6502 (une quinzaine d'octets par niveau), la partie de la pile
  entre `savsp` et le sommet (évaluateur en attente, nom de la commande appelante) est
  recopiée dans une zone à part (`spill`, 640 octets) et la pile repart de `savsp` ;
  `RENDS` dépile les contextes jusqu'au `FR_FUNC` (locales et EXECUTE rendus), recopie la
  pile et revient à l'appelant de `primary` avec la valeur dans vt/val. Une erreur remet
  tout à zéro (`savsp`, `reset_frames`). Les arguments d'un appel sont évalués sur la pile
  de valeurs (racine du compactage) et non plus dans `argv`, supprimé : une fonction appelée
  pendant l'évaluation des arguments d'une autre réutilise hdr, parn, pcount. La pile de
  valeurs passe de 24 à 40 valeurs. Profondeur : une quarantaine de niveaux pour
  `RENDS :N * FACT :N - 1` (pile de valeurs), environ 45 sans opération en attente
  (`spill`) ; les procédures appelées en instruction ne changent pas. Décisions : une
  fonction qui arrive à FIN ou à STOP sans RENDS est une erreur (`Rien n'a ete rendu par`),
  RENDS dans une procédure appelée en instruction aussi (`Que faire de ce que rend`, comme
  UCB Logo), RENDS hors de toute procédure aussi. FIXEXY garde x sur la pile pendant
  l'évaluation de y (une fonction peut déplacer la tortue). Le contexte d'une procédure
  garde l'adresse de son enregistrement (compteur), pour nommer la procédure dans les
  messages. Coût : 424 octets de code, 1 Ko de zones (zone libre en SPLIT : 18,2 Ko
  au lieu de 19,2).

- LOGO, lot 9 : écran texte. ECRANTEXTE passe le système en mode texte (BDOS 115, mode 0)
  après avoir effacé la tortue ; ECRANMIXTE revient en SPLIT sans effacer l'image (mode 2) ;
  les deux réinstallent la barre de menus de LOGO (le changement de mode remet celle du
  système). Une variable `tmode` : `need_img` donne `Impossible en ecran texte :` au début
  de AV, RE, DR, GA, FIXECAP, FIXEXY, ORIGINE, VE, NETTOIE, SAUVEIMAGE, CHARGEIMAGE ;
  `turtle_show` ne dessine pas. LC, BC, GOMME, INVERSE, CT, MT restent permises (elles ne
  dessinent rien et préparent le retour). `memtop` reste à `$A000` : l'image est gardée et
  rien n'est à déplacer au retour ; agrandir la zone de 5 Ko en texte demanderait de
  reloger le tas à chaque ECRANMIXTE (~150 octets, à faire si la place manque un jour).
  Menu Tortue : « Ecran texte », « Ecran mixte ». Coût : 229 octets (zone libre 17,9 Ko :
  le code a franchi une page).

- Enchaînement de programmes : BDOS 47 CHAIN (numéro et rôle de CP/M 3 ; la ligne est donnée
  par A/Y au lieu du DMA). La ligne est recopiée dans `CMDBUF` ($0400, qu'un démarrage à
  chaud ne touche pas), `chain_on` ($0244, page 2, remis à 0 au démarrage à froid) est mis à 1,
  puis démarrage à chaud ; le CCP affiche la ligne après `A>` et l'exécute avant toute ligne
  d'un script DO. Dans le BDOS commun (la ROM l'a aussi, pour ses commandes internes). Coût :
  54 octets résidents (marge 379 octets).
- LOGO, lot 10 : EDITE "NOM fait SAUVE, range l'état dans `LOGO.$$$` puis enchaîne sur
  `EDIT NOM.LOG /L`. État : en-tête (« LGS1 », hp, memtop, mode d'écran), variables globales
  (512 octets), tas des textes (de hp arrondi à 128 jusqu'à memtop), page zéro `$00-$FF`
  (relue en dernier dans lbuf et llbuf, recopiée d'un coup : tant qu'elle n'est pas recopiée,
  les globales et le tas relus ne sont désignés par rien, un fichier incomplet est sans
  danger). Les procédures ne sont pas dans l'état : elles reviennent par CHARGE du fichier
  modifié, préparé par `args` comme une ligne tapée au prompt (`autold`). Le contexte
  d'exécution n'est pas gardé : EDITE arrête un programme en cours, on revient au prompt.
  En écran texte, EDITE repasse en SPLIT avant d'enchaîner : EDIT garde l'image quand il part
  du mode SPLIT (sinon son presse-papiers l'écraserait) ; LOGO remet l'écran texte au retour.
  `LOGO NOM` (sans /R) charge `NOM.LOG` au démarrage. EDIT : avec `/L` dans ses paramètres,
  l'article Quitter devient Retour (le texte du menu est réécrit en mémoire) ; Retour
  enregistre si le texte a changé (en cas d'échec, on reste dans EDIT) et enchaîne sur
  `LOGO NOM.LOG /R`. Coût : LOGO 785 octets (zone libre 17,2 Ko), EDIT 160 octets.

- Imprimante : LIST du BIOS (l'entrée existait, vide ; PUNCH a maintenant sa propre entrée
  vide). Octet sur le port A du VIA, partagé avec l'AY (interruptions coupées le temps de
  l'écrire et de donner le strobe), front descendant de PB4 (désormais au repos à 1 ; kb_row
  préserve les bits 3 à 7 de ORB), attente de l'accusé CA1 limitée à ~2 ms : sans imprimante
  rien ne bloque. BDOS 5 pointe directement sur LIST. CTRL-P dans l'édition de ligne (BDOS 10)
  bascule la copie de la console (`lst_echo`, `$0245`) ; pendant l'édition la copie est
  suspendue (bit 7) et la ligne finale est imprimée par RETURN, pour ne pas imprimer les
  retouches ; un démarrage à chaud lève la suspension. Oricutron écrit l'imprimé dans
  `printer_out.txt` : `tools/smoke_test.sh` le vérifie. Coût : 106 octets résidents.
- Voyants de la barre : le texte `CAPS` (colonnes 35-38), peu parlant et sans place pour
  l'imprimante, est remplacé par deux voyants toujours visibles : colonne 37 `A` (majuscules
  verrouillées) ou `a` (minuscules), colonne 38 `P` quand la copie à l'imprimante (bit 0 de
  `lst_echo`) est active. Les colonnes 35-36 restent libres (voyant réseau plus tard).
  Le verrouillage des majuscules est gardé : le CCP et LOGO passent leurs lignes en
  majuscules, mais les fonctions 1 et 10 du BDOS rendent ce qui est tapé (comme CP/M), et le
  clavier de l'Oric donne des minuscules sans SHIFT (EDIT, sources pour ASM...).
  Un article Imprimante dans le menu Systeme (et non Clavier, réservé au rythme des touches)
  appelle la même routine que CTRL-P, qui ne marche que pendant la lecture d'une ligne.
  `draw_flags` remplace `draw_caps`, appelée par la barre (tous les programmes), CTRL-T,
  CTRL-P et les menus. Coût : 11 octets résidents.

- Lancement d'un programme : le CCP cherche `NOM.COM`, puis `NOM.BAT` (comme `.SUB` dans
  CP/M 3) ; `NOM.COM` et `NOM.BAT` tapés en entier sont acceptés, tout autre type donne
  `NOM.EXT?` comme CP/M 2.2. Avant, un type explicite était chargé tel quel : `DESSIN.BAT` tapé
  au prompt exécutait le texte en `$0500` (BRK en `$203A`, constaté sur le vrai Oric). Un script
  lancé par son nom passe par DO (`cmd_do`, reprise du nom à `ccp_pos`) : `NOM a b` équivaut à
  `DO NOM a b`, y compris par CHAIN. L'existence de `NOM.BAT` est vérifiée avec le FCB du CCP
  avant d'appeler DO, pour qu'une commande inconnue dans un script n'arrête pas ce script.
  Coût : 53 octets résidents.
- Appel de script à script, à la demande (« JIT ») : DO appelé pendant un script (par DO ou par
  le nom) ne remplace plus le script en cours mais enchaîne (CHAIN) sur `XDO NOM paramètres`.
  XDO.COM lit l'état de l'appelant dans les zones de DO (rendues publiques dans `cpa.inc` :
  `SCR_ON`, `SCR_IDX`, `SCR_FCB`, `SCR_BUF`, `SCR_PAR`, `ORIG_LINE`), lit le script appelé et la
  fin de l'appelant en mémoire (TPA), remplace les `$1`-`$9` de chacun par ses propres
  paramètres en doublant les `$` des textes recopiés, écrit `$$$.BAT` et enchaîne sur
  `DO $$$`. Tout est lu avant d'écrire : l'appelant peut être `$$$.BAT` lui-même, et les appels
  s'emboîtent sans limite autre que la TPA (« Scripts trop longs »). Un script sans appel ne
  coûte rien de plus ; le script appelé est relu à chaque appel (pas de recompilation). Écartés :
  empiler les contextes dans le système (~120 octets par niveau), un développement préalable
  de tout script (écriture sur le disque à chaque lancement), un compilateur `.BAT` -> `.COM`
  (un `.COM` lancé par un `.COM` l'écrase en `$0500`, et le résultat serait figé). Limites :
  une disquette protégée en écriture empêche les appels ; la ligne d'appel est tronquée à 78
  caractères (CHAIN) ; modifier l'appelant pendant qu'il tourne n'est pas sûr ; sans XDO.COM,
  la ligne d'appel est sautée. Toute erreur de XDO arrête le script. Coût : 49 octets
  résidents, XDO.COM 1 271 octets.

## Suite prévue (par priorité)

0. **LOGO : nombres décimaux, saisie, mots et listes** (lots 1 à 10 faits, un commit par livraison). Choix :
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
   | 3 | décimaux : 4 opérations, comparaisons, lecture/affichage, conversions, promotion, QUOTIENT, RESTE, ENT, ARRONDI, ABS | élevée | 2,7 Ko | **fait** |
   | 4 | tortue et décimaux (conversions, cap fractionnaire, contrôles de plage) | moyenne | 460 o | **fait** |
   | 5 | mots et listes : tas et compactage, MOT, PHRASE, LISTE, PREMIER, DERNIER, SAUFPREMIER, SAUFDERNIER, ITEM, COMPTE, VIDE?, MOT?, NOMBRE?, LISTE?, MEMBRE?, `=` sur les textes, ECRIS et EXECUTE de listes ; un mot qui a l'air d'un nombre compte comme un nombre | élevée | 2,9 Ko + 0,6 Ko de zones | **fait** |
   | 6 | LISLISTE (et LISMOT) ; LISCAR rend un caractère (ASCII, CAR) | faible | 275 o + 128 o | **fait** |
   | 7 | RACINE, SIN, COS, ARCTAN, LN, EXP (PUISSANCE : écrite en Logo si besoin) | moyenne | 1,4 Ko | **fait** |
   | 8 | RENDS (procédures qui renvoient une valeur ; l'évaluateur est récursif, les procédures non) | élevée | 424 o + 1 Ko de zones | **fait** |
   | 9 | mode texte : ECRANTEXTE / ECRANMIXTE, erreur pour les primitives graphiques, `memtop` reste à `$A000` | faible | 229 o | **fait** |
   | 10 | aller-retour avec EDIT : BDOS 47 « Chain » (comme CP/M 3, ajout au contrat accepté), EDITE dans LOGO (état dans `LOGO.$$$`), article « Retour » dans EDIT | moyenne | 54 o résidents, LOGO 785 o, EDIT 160 o | **fait** |

   Mémoire visée après les lots 1 à 7 : LOGO.COM ~13-14 Ko, zone libre ~21 Ko en SPLIT
   partagée entre procédures et textes. Après le lot 7 : LOGO.COM 15,4 Ko (les lots 5 et 7
   ont coûté le double de l'estimation), zone libre 20 Ko en SPLIT (28 Ko avant le lot 2).
   Après le lot 10 : LOGO.COM 16,8 Ko, zone libre 17,2 Ko (en SPLIT comme en texte).
   Chaque lot passe `tools/test_logo.sh` ; ses références ne changent que là où le lot change
   volontairement un résultat (par exemple `7 / 2` au lot 3).

1. **LOGO en modules** (« bibliothèques dynamiques », idée du dictionnaire de Forth : on ne
   charge que les mots du contexte). Constat : LOGO.COM fait 16,8 Ko et laisse 17,2 Ko à
   l'utilisateur ; tout est chargé, même ce qui ne sert pas. Tout se fait dans LOGO.COM :
   ni le système ni le contrat d'interface ne changent.
   - Noyau : interpréteur, nombres (décimaux compris, ils servent partout), variables,
     procédures, fichiers. Modules sur la disquette (`.LGM`), chargés par `CHARGEMODULE "NOM`,
     rendus par `OUBLIEMODULE` ; chaque module apporte sa table de primitives, consultée
     après celle du noyau.
   - Table d'accès au noyau (sauts vers ~20 routines : évaluer un entier, erreurs, cacher la
     tortue, BDOS...) : les modules ne dépendent pas des adresses internes de LOGO.
   - Relocation à la manière des PRL de MP/M : le module est assemblé à deux adresses, un outil
     Python en tire une carte d'un bit par octet à corriger, le chargeur de LOGO l'applique
     (~60-80 octets). Plusieurs modules peuvent être chargés à la fois.
   - Coût estimé dans le noyau : 250-350 octets. Gain : sortir les fonctions (1,4 Ko), les mots
     et listes (2,9 Ko + 0,6 Ko de zones), EDITE (~0,8 Ko), peut-être le texte de l'aide :
     noyau visé 10-12 Ko, 4 à 6 Ko rendus à l'utilisateur qui n'a pas besoin de tout.
   - Points délicats : la frontière noyau / modules ; un programme sauvé déclare ses modules
     (ligne `CHARGEMODULE` en tête) ; `test_logo.sh` charge les modules.

   | Lot | Contenu | Complexité | État |
   |---|---|---|---|
   | A | mécanisme : table d'accès, chargeur avec relocation, CHARGEMODULE / OUBLIEMODULE, outil Python de fabrication ; validé en sortant les fonctions mathématiques dans un module (tests LOGO identiques) | élevée | à faire |
   | B | module `GRAPHE` : primitives du BDOS 115/116 que LOGO n'expose pas — POINT, TRAIT, RECTANGLE / PAVE, CERCLE, ETIQUETTE (texte à la position de la tortue), FIXECOULEUR (ATTR), ALLUME? (lire un point), SON voix note volume durée, ENVELOPPE ; coordonnées de la tortue (à confirmer) ; cachent la tortue, refusent l'écran texte. Estimé 350-400 o | moyenne | à faire |
   | C | selon le gain mesuré : sortir les listes, EDITE, l'aide | moyenne | à voir |
   | D | plus tard, si besoin : procédures converties en jetons à la définition (vitesse, place ; LISTE et EDITE retraduisent) | élevée | piste |

   Écarté pour l'instant : une primitive générique `.SYSTEME n [liste]` (seules les fonctions
   115 et 116 s'y prêtent, les autres demandent des adresses ; risques : quitter LOGO, mode
   d'écran désynchronisé, traces de la tortue). À reconsidérer avec PEEK / POKE, « pour experts ».

2. **Réseau par le LOCI** (matériel décrit dans `docs/loci-modem-wifi.md`, pas encore acheté) :
   - pilote série dans le BIOS, branché sur PUNCH / READER : ACIA 6551 en `$0380` sur le LOCI
     (`$031C` dans Oricutron), adresse dans une variable, ~150 octets ;
   - `XFER.COM` : envoi et réception de fichiers en XMODEM (paquets de 128 octets acquittés) ;
   - `tools/xfer_server.py` : serveur XMODEM sur le Mac ;
   - `TERM.COM` : terminal (commandes AT du modem PicoWiFiModemUSB).
3. Petites améliorations notées : `AUTO.BAT` exécuté au démarrage ; commande `NOTE` au prompt
   (son dans les scripts) ou `PLAY.COM` (partition texte) ; ne pas perdre la frappe anticipée
   pendant `NOTE`/`ATTENDS` dans LOGO ; raccourci clavier pour « Insérer » dans EDIT.
   Imprimer le texte depuis EDIT. Bibliothèque LOGO `MATH.LOG` de Pierre (PI, PUIS, FACT) :
   hors de la disquette construite pour l'instant.
   Revue complète du son : le volume maximal de l'AY est agressif et rien ne permet de le régler
   (NOTE et BRUIT de LOGO jouent au volume 12) ; `SON` du lot B prendra un volume.
4. Pistes : export direct d'un fichier vers la clé USB du LOCI (API MIA en `$03A0`) ; base de
   données simple sur l'accès direct.

## Contraintes à garder en tête

- 142 octets libres dans le système : tout ajout résident se justifie, le reste va en `.COM`
  (le pilote série prévu en demande ~150).
- Les interruptions sont coupées pendant les accès disque (une touche peut être perdue, le
  compteur 50 Hz retarde).
- Ne rien changer au contrat d'interface (`docs/architecture.md`) sans penser à la version ROM.
