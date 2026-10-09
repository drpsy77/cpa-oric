# Projet « CP/A disquette » — système évolutif, développement, gestion, communication

À lire avec `docs/architecture.md` (contrat d'interface commun avec la version ROM).

## But

Un système à la CP/M pour Oric Atmos, chargé depuis une disquette (Microdisc, Cumulus, LOCI)
dans les 16 Ko de RAM overlay. Il s'enrichit par des commandes `.COM` sur le disque plutôt que par
du code résident. Usages visés : développer sur l'Oric lui-même, gérer des fichiers et des
données, communiquer (réseau par le LOCI).

## État (version 0.9)

**Système** (`$C000-$F450`, marge 544 octets jusqu'à `$F670`, 667 sans l'option `CPLCMD` ; page `$FF00-$FFB7`, marge 66
octets jusqu'aux vecteurs) :

- console avec pause en fin d'écran, menus déroulants, reprise après plantage (BRK, RESET) ;
- imprimante sur le port Centronics (LIST, BDOS 5), copie de la console par CTRL-P ou par
  l'article Imprimante du menu Systeme ;
- voyants au bout de la barre de menus : `A` / `a` (majuscules / minuscules), `P` (imprimante) ;
- lecture de ligne (BDOS 10, `src/rline.s`) : curseur ← →, insertion, DEL / CTRL-D, CTRL-A / E,
  historique ↑ ↓ (256 octets, garde ses lignes au démarrage à chaud), complétion des noms de
  fichiers par ESC (partie commune, puis liste des noms possibles), et en début de ligne des
  commandes internes et des `.COM` / `.BAT` sans leur type (option `CPLCMD`) ;
- fichiers CP/M 2.2 : séquentiel, accès direct (33-36), attributs R/O et SYS (30) ;
- quatre lecteurs A: à D: (Microdisc, LOCI, Oricutron) : `B:` au prompt, article « Lecteur
  suivant » du menu Systeme, lecteur dans tout nom de fichier, programme cherché sur A: s'il
  n'est pas sur le lecteur courant, lecteur vide ou absent sans blocage ;
- mode SPLIT (240 × 128 + barre + 10 lignes de texte ; bascule en `$BFDF` comme le BASIC, `$A000`
  utilisable), graphisme BDOS 115, images `.IMG` ;
- son BDOS 116 (notes, bruit, enveloppe, durées gérées par l'IRQ, départ simultané des voix,
  mélangeur son et bruit par voix) ;
- HIRES plein écran (240 × 200) laissé aux programmes (`progs/hires.inc`) : le système le
  reconnaît (`$1E` en `$BFDF` hors SPLIT) et n'y dessine rien ; retour au texte assuré par le
  démarrage à chaud ;
- CCP : DIR, DIRS, SAVE, VER, CLS, SPLIT, TEXT, GCLS, GSAVE, GLOAD, PUT (sortie vers un fichier), DO (scripts
  `.BAT` avec `$1`-`$9`, lancés aussi par leur nom, appel de script à script par XDO.COM),
  ECHO, PAUSE.

**Programmes** : HELP (aide par rubriques), SET (attributs), EDIT (éditeur, insertion de fichier,
impression mise en page, réglages par fichier dans EDIT.CFG),
HEX (éditeur hexa par fenêtres, écriture sur place), LOGO (français, tortue, son sur les trois
voix de l'AY avec enveloppe, bruit, mélangeur et départ simultané, clavier
LISCAR / TOUCHE?, valeurs typées, nombres décimaux, mots et listes, fonctions de l'utilisateur
avec RENDS, écran texte, aller-retour avec EDIT par EDITE), ASM
(assembleur 6502, identique à `xa` sur nos sources, écrit `.SYM`), DEBUG (moniteur,
désassembleur symbolique, pas à pas), STAT (taille des fichiers en enregistrements, blocs et
octets ; place libre), MEM (carte mémoire), POKE et GO (écrire et lancer du code), XDO (appel
de script à script), COPY (jokers admis, comme PIP), TYPE, ERA (avec confirmation), REN,
GTEST, HELLO ; GRAPHER (petit langage de dessin, fichiers `.GRX` : variables, expressions, boucles, sous-programmes ; HIRES plein écran ou SPLIT ; les
commandes de dessin du prompt y sont passées) et VOIR (affiche une image `.HIR` ou `.IMG`) ;
EXPORT, IMPORT et USBDIR (échange de fichiers avec
la clé USB du LOCI) ; FORMAT (formatage, un seul lecteur possible, `/Q` rapide) ; DISKCOPY
(copie de disquette, un seul lecteur possible ; `/S` : système seul, comme SYSGEN).
Disquette livrée : commandes et applications protégées (R/O) et visibles, exemples modifiables ;
trois disquettes par usage (LOGO, notes, assembleur), commandes de base cachées (SYS).

**Essayé sur matériel** (Oric Atmos + LOCI) : démarrage, menus, EDIT, PUT, DIR, GTEST, LOGO,
STAT, MEM, POKE, GO et DO ; l'historique des lignes (flèche haut) au prompt de CP/A et dans
LOGO, ← → dans LOGO ; la complétion des noms par ESC ; le mode SPLIT avec la bascule en `$BFDF` ; dans LOGO,
les décimaux et la tortue avec des décimaux (vitesse jugée meilleure que le BASIC). DEBUG
démarre, mais n'a pas encore servi à déboguer pour de vrai. Restent à essayer sur le vrai
Oric : l'impression depuis EDIT (`^P`) et `^L`, ASM (jamais lancé), DEBUG en usage réel (points d'arrêt, pas à pas), HEX en écriture
sur place, le son (dans LOGO : SON, SONF, BRUITV, ENVELOPPE, MELANGE, ENSEMBLE, ATTENDSSON,
JOUE?, et la coupure par ESC), et dans LOGO : LISCAR, TOUCHE?, les mots et les listes, LISLISTE,
les fonctions RACINE, SIN, COS, ARCTAN, LN, EXP, RENDS (FACT, FIBO, profondeur),
ECRANTEXTE et ECRANMIXTE (avec le menu Tortue), le dessin du lot L4 (POINT, TRAIT,
RECTANGLE, PAVE, CERCLE, ETIQUETTE, FIXECOULEUR, ALLUME?), EDITE et le Retour d'EDIT (temps d'écriture
et de lecture de LOGO.$$$, image gardée), `LOGO NOM` ; EXPORT, IMPORT et USBDIR (jamais
lancés sur le vrai LOCI : voir le lot L1 plus bas) ; FORMAT (lot L2 : sur le LOCI et sur un
vrai Microdisc) ; DISKCOPY (lot L3) ; COPY avec jokers et STAT avec attributs (lot LA).

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

- LOGO, lots E et F : `make_fcb` (SAUVE, CHARGE, EDITE, SAUVEIMAGE, CHARGEIMAGE) prend un
  `"NOM` comme avant, ou sinon évalue une expression, qui doit donner un mot non vide (un
  nombre est pris comme mot : `CHARGE 7` cherche `7.LOG`). Un CHARGE imbriqué n'est pas
  permis mais refusé : le permettre demandait de sauver ~300 octets par niveau (FCB, tampon
  d'enregistrement, ligne en cours), et le besoin est couvert par le noyau qui enchaîne les
  chargements. Variable `ldon` (1 pendant un CHARGE, remise à 0 à la fin, au démarrage et par
  toute erreur) ; `ld_check` en tête de SAUVE (donc d'EDITE) et de CHARGE donne
  `Interdit pendant CHARGE :`. SAUVEIMAGE et CHARGEIMAGE restent permis : ils gardent le FCB
  du CHARGE en cours sur la pile du 6502 le temps de l'opération (un fichier d'étape charge
  son image). Coût : LOGO.COM +134 octets (16 967).
- Son, opérations 7 et 8 de la fonction 116 (ajout au contrat accepté par Pierre ; les deux
  versions) : SYNC (0 préparation, 1 départ, 2 abandon), pour la synchronisation des voix que
  le BASIC obtient par PLAY ; MIXER (son et bruit d'une voix, les deux à la fois possibles).
  En préparation, NOTE, NOISE et TONE écrivent période et mélangeur tout de suite, coupent la
  voix (volume 0, durée 0) et retiennent volume et durée (`s_pvol`, `s_pdur`) ; ENV écrit la
  période et retient l'écriture du registre 13, qui relance l'enveloppe. Le départ écrit,
  interruptions masquées, le registre 13 si besoin puis les volumes et les durées des voix
  préparées. Retenir aussi périodes et mélangeur aurait demandé une copie des 14 registres :
  la page 2 n'a que 10 octets libres (`$0246-$024F`, 8 pris : `s_hold`, `s_pvol`, `s_pdur`,
  `s_penv`). Effet : une voix qui jouait encore change de note quelques millisecondes avant
  le départ (elle est coupée dès sa préparation). Le départ ne relance l'enveloppe que si
  ENV a été donné pendant la préparation. Coût : 123 octets résidents (165 pour les ajouts,
  42 regagnés en réécrivant SILENCE, WAIT et le mélangeur de NOTE et NOISE) ; essayé dans
  Oricutron par un programme qui relit les registres de l'AY. Il ne restait que 19 octets dans
  le système : le pilote série (~150 octets) demandera de libérer de la place.
- LOGO, lot B, partie son (décidée avec Pierre) : `SON voix note volume durée`, `SONF`
  (période brute 0-4095), `BRUITV` (bruit sur une voix, période 0-31), `ENVELOPPE forme
  période` (période 0-65535 : un entier au-delà de 32767 arrive en décimal, il est arrondi et
  converti à part), `MELANGE voix son bruit`, `ATTENDSSON voix` (255 : toutes), `JOUE? voix`
  (fonction), `ENSEMBLE [liste]` ; `NOTE` et `BRUIT` supprimés (aucun test ni fichier de la
  disquette ne s'en servait). Toute valeur hors limites est une erreur (`Valeur hors limites :`
  suivi de la commande) plutôt qu'un écrêtage silencieux comme le faisait `NOTE` (durée > 255).
  Les arguments sont gardés sur la pile du 6502 jusqu'à l'appel (une fonction de l'utilisateur
  appelée dans un argument peut elle-même jouer un son et réutiliser `gblk`). `SON` rend la main
  tout de suite : ESC et toute erreur font `SILENCE` (dans `error`), sinon une note sans fin
  continuerait au prompt. `ENSEMBLE` : SYNC 0, puis la liste dans un contexte `FR_ENS` ; SYNC 1
  quand ce contexte est retiré, quelle qu'en soit la raison (fin de la liste, `STOP`, `RENDS` :
  `x_rest` les voit toutes) ; un compteur (`ensd`) fait qu'un ENSEMBLE dans un autre est compris
  dans le premier ; une erreur remet le compteur à 0 et SILENCE abandonne la préparation.
  `JOUE?` et `ATTENDSSON` reposent sur STATUS, qui ne compte que les notes minutées : une note
  sans fin (durée 0) ne « joue » pas pour eux (sinon `ATTENDSSON` ne rendrait jamais la main).
  Système : le démarrage à chaud remet `s_hold` à 0 (3 octets) ; sans cela, un
  programme qui quittait pendant une préparation (`ENSEMBLE [... QUITTE]`) laissait le son
  muet pour tous les programmes suivants. Corrigé au passage : `puts` de LOGO s'arrêtait à 255
  caractères, AIDE était coupée depuis longtemps (au milieu de la ligne `SI`) ; `puts` passe
  maintenant à la page suivante. Coût : LOGO.COM +460 octets (17 427), dont 104 pour les 3
  lignes d'AIDE en plus et 4 pour `puts` ; zone libre réduite d'une page (`procbase` `$5E00`
  -> `$5F00`).
  Essayé dans Oricutron en relisant les registres de l'AY (crochet de test modifié localement
  pour vider les 14 registres en `$0300`) : périodes, volumes, enveloppe 40000, mélangeur,
  ENSEMBLE imbriqué avec STOP, erreurs de plage, ESC pendant ATTENDSSON.
- Lecteurs A: à D: (demandés par Pierre : 4, comme le LOCI, Oricutron et le Microdisc ; menu
  qui passe au lecteur suivant). Pas de changement du contrat : les fonctions 14, 24 et 25 et
  l'entrée SELDSK existaient (A: seul) ; l'octet 0 du FCB suit CP/M (0 = courant, 1 = A:).
  - Pilote (`disk.s`) : lecteur dans les bits 5-6 de `$0314` ; le WD1793 n'a qu'un registre de
    piste, rangé par lecteur (`dsk_trk`) au changement (`md_sel`). Après un changement, un
    déplacement de tête est toujours fait : Oricutron n'a qu'une position de tête pour tous
    ses lecteurs (constaté : sans cela, B: était lu sur la piste où était resté A:) ; sur le vrai
    matériel, c'est une vérification de piste. Un lecteur vide ou absent ne répond jamais
    (Oricutron laisse la lecture en attente, comme le vrai contrôleur) : attente du premier
    octet limitée à ~0,7 s (DRQ guetté par une boucle de 11 cycles : ~18 cycles entre DRQ et la
    lecture, 23 pour l'écriture, sous les 32 µs d'un octet), attentes des déplacements à
    ~3 s, puis Force Interrupt et échec sans nouvel essai. Le lecteur des accès est
    `buf_drv`, celui du secteur en cache : un secteur modifié est toujours réécrit sur son
    lecteur.
  - Système de fichiers (`fs.s`) : `set_fcb`, au début de chaque fonction, choisit le lecteur
    (`drv_select`) ; une carte d'allocation par lecteur (4 x 22 octets en `$FD00`, `alv_index`
    ajoute `alv_off`), faite d'après le répertoire à la première utilisation depuis le dernier
    démarrage à chaud (`log_vec`), sans perdre une recherche 17/18 en cours. Lecteur inconnu ou
    illisible : la fonction rend `$FF`. 18 reprend le lecteur de 17. Variables du disque
    déplacées en `$FD58-$FD7F` (même ordre : PUT sauve toujours deux blocs de 12 octets),
    `dsk_trk` en `$FDA4`. Démarrage à chaud : le lecteur courant est gardé et relu, retour en
    A: s'il ne répond plus. Changer de disquette demande un CTRL-C, comme sous CP/M.
  - CCP : `X:` seul change de lecteur (`X:?` si absent) ; invite `B>` ; un `.COM` sans lecteur
    absent du lecteur courant est cherché sur A: (`open_com`, comme la recherche de CP/M 3) ;
    DO fixe le lecteur de son script à l'ouverture (un `A:` dans un script de B: ne change pas
    sa lecture) ; DIR d'un lecteur illisible ne donne pas de place libre. Complétion par ESC
    sur le lecteur tapé (`B:NO` + ESC). Menu : « Lecteur suivant » tape `X:` (comme les autres
    articles qui tapent une commande ; dans un programme, ce texte arrive au programme).
    Choix : un lecteur absent arrête le cycle du menu (il répond `B:?`, on tape `C:`).
  - Programmes : STAT prend le lecteur de son paramètre (et ne donne pas de place libre pour
    un lecteur illisible) ; EDIT garde le lecteur de « Ouvrir », « Insérer », « Enreg. sous »
    et le transmet à LOGO au Retour ; LOGO accepte `"B:NOM` (SAUVE, CHARGE, EDITE, images) ;
    ASM cherche les `#include` sur le lecteur de la source. COPY marchait déjà.
  - Coût résident mesuré : ~414 octets (pilote et système de fichiers ~260, CCP ~78, complétion
    et menu ~71, corrections après essais ~10), le double de l'estimation (~210). Place
    trouvée par la piste G de la revue (tables `g_ylo` / `g_yhi` calculées par `font_init`
    dans `$B400-$B4FF`, glyphes des codes 0-31 jamais affichés : +231 octets ; l'octet
    `IMG_END` qui y était écrit ne servait plus) et l'écriture inutile de `fs_err`. Marge
    192 octets. LOGO.COM +44 octets (17 471) : zone libre réduite d'une page (`procbase`
    `$6000`). Essayé dans Oricutron avec 1 à 4 disquettes : DIR, TYPE, COPY, SAVE, REN, ERA,
    STAT, programme lancé depuis B: et depuis A: quand on est sur B:, script DO, complétion,
    menu A->B->C->D->A, lecteur vide, LOGO (CHARGE, SAUVE, EDITE et Retour sur B:), ASM et
    EDIT sur B:.
- Fusion de la branche « place résidente » (pistes A à F) avec le lot B (son) : marge 375
  octets (378 - 3 pour la remise à 0 de `s_hold`). La bannière plus courte d'une ligne décale
  la pagination de la console : dans `tools/test_logo.sh`, deux frappes simulées tombaient
  pendant un accès disque et perdaient SHIFT (`"` lu `'`, `:` lu `;`) ; une pause de plus
  avant ces frappes suffit (artefact du crochet de test, qui appuie SHIFT et la touche dans la
  même trame : une frappe humaine n'est pas concernée).
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
  la ligne d'appel est sautée. Toute erreur de XDO arrête le script.
  Limite de fond, constatée par Pierre (`SCRIPT.BAT` qui se rappelle avec `($1+4)`) : les
  scripts n'ont ni calcul, ni variable, ni condition ; `$n` est un remplacement de texte. L'appel
  de script à script sert donc à réutiliser des suites de commandes, pas à programmer : un
  script récursif ne s'arrête que par ESC. Calculer, répéter, décider : LOGO ou un `.COM`.
  Alternative documentée dans le README (idée de Pierre) : le script lance `LOGO NOM`, dont
  `NOM.LOG` définit ses procédures, les appelle et finit par `QUITTE` ; l'image reste intacte
  en SPLIT et le script continue dessus (essayé dans Oricutron : `PELOUSE.BAT` + `HERBE.LOG`).
  Manque : passer des paramètres du script à LOGO (`LOGO NOM` ne prend que le nom). Coût : 49 octets
  résidents, XDO.COM 1 271 octets.

- Revue de place (octobre 2026), avant le pilote série. Mesure par module et par routine
  (fichier `.sym`) : les plus gros postes sont fs.s (1 961 o), bios.s (1 796), gfx.s (1 595),
  menu.s (1 402), ccp_disk.s (1 383), rline.s (1 026), tables.s (920) et la police (768).
  Pistes retenues par Pierre (A à F, sans risque) : la page `$FF00-$FFF9`, déjà chargée avec le
  système et vide, reçoit les tables de l'écran texte et du clavier (`src/tables_ff.s`,
  184 octets ; `gen_tables.py` écrit les deux fichiers, `build.sh` contrôle les deux marges) ;
  bannière sans la ligne TPA/BDOS (elle est dans HELP et MEM), pause « -- Suite (^C stop) -- »,
  message de PUT en anglais court comme les autres messages du CCP ; SAVE lit son nombre par
  `get_byte` (celui des commandes graphiques) et `parse_dec` disparaît ; table des commandes
  internes sans 0 de fin (dernier caractère avec le bit 7) ; routines `def_pos`, `def_chk`,
  `pf_chk` pour la suite cf_def / parse_fcb / check_name répétée dans le CCP ;
  `bios_setdma` et `bios_disk_stub` réservés à la ROM. Gain : 359 octets dans la zone du code,
  66 encore libres dans la page `$FF00`. Pistes gardées en réserve (risque faible à moyen) :
  G, tables g_ylo/g_yhi calculées au démarrage dans `$B400-$B4FF` (police des codes 0-31,
  jamais affichée ; ~230 o ; **faite** avec les lecteurs, +231 o) ; H, masque de point calculé au lieu de g_xbit (~220 o, un peu plus
  lent) ; I, test de RAM réduit à un remplissage, test complet en `.COM` (~105 o) ; J, TYPE, ERA
  et REN en `.COM` (~290 o, transparents pour les scripts). Écartées : commandes graphiques en
  `.COM` (scripts ralentis), compression du clavier ou de la police, complétion ESC.

- Échange avec la clé USB du LOCI (lot L1, octobre 2026) : trois `.COM`, `EXPORT fic [nom]`,
  `IMPORT nom [fic] [/T]` et `USBDIR [chemin]`, rien de résident, et une bibliothèque commune
  `progs/loci_inc.s` (appel de l'API de la MIA, pile d'échange, messages d'erreur, nombres sur
  32 bits). Tailles : EXPORT 1 248 octets, IMPORT 1 661, USBDIR 994 (un bloc de 2 Ko
  chacun ; les tampons sont après la fin du programme, hors du fichier). Choix :
  - Le LOCI est reconnu au code que sa MIA place en `$03B0-$03B7` (CLV, BVC, LDA #, LDX #,
    RTS) avant tout `JSR $03B0` : sans LOCI, ces adresses sont celles du VIA, et l'appel
    planterait. Message `LOCI absent : cle USB inaccessible`.
  - Chemins sans lecteur par défaut : FatFs du LOCI prend alors la première clé montée (son
    lecteur courant), quel que soit son numéro (`1:`, ou `2:` derrière un hub, le LOCI
    numérotant les appareils USB). `0:` (mémoire interne) et les chemins restent possibles.
  - Noms tapés en minuscules gardés pour la clé : la casse d'origine vient de `ORIG_LINE`
    (la ligne tapée), dont `TAIL` donne la longueur des paramètres.
  - ^Z : EXPORT les retire du dernier enregistrement (règle de STAT), IMPORT les ajoute ; un
    binaire fait l'aller-retour à l'identique sauf s'il finit par des `$1A`. Fins de ligne
    gardées à l'EXPORT (CR LF, que le Mac lit) ; à l'IMPORT, l'option `/T` change un LF seul
    en CR LF (sans elle, EDIT accepte déjà le LF seul, mais TYPE afficherait en escalier).
    Pas de détection automatique texte/binaire : une option explicite, comme PIP.
  - Par défaut, IMPORT coupe le nom de la clé à 8 + 3 caractères (plutôt que de refuser) et
    affiche le nom obtenu ; un 2e mot réduit à `B:` garde ce nom sur ce lecteur.
  - Un fichier existant est remplacé des deux côtés, comme COPY. EXPORT refuse un nom en
    `.DSK` (on pourrait écraser l'image de disquette en service, le LOCI ne verrouillant pas
    ses fichiers). Disque plein à l'IMPORT : le fichier commencé est effacé.
  - Transferts par enregistrements de 128 octets (une opération de la MIA chacun) : simple,
    et l'accès à la disquette reste le plus lent. EXPORT lit avec un enregistrement d'avance
    pour reconnaître le dernier.
  - Essais sans le matériel : le correctif d'Oricutron simule la MIA sur un dossier du PC
    (`ORIC_LOCI=dossier`, `machine.c`, opérations de fichiers et de répertoires seulement,
    faites d'un coup). Essayé ainsi : aller-retour à l'identique d'un binaire de 70 001 octets
    et d'un `.COM`, textes avec `/T` (LF seul, et CR LF inchangé), noms longs, sous-dossier,
    `0:`, `B:` seul, erreurs (fichier absent, nom invalide, disque plein, `.DSK`), et
    `LOCI absent` sans la simulation. La simulation suit les sources du firmware
    (loci-firmware, `src/mia/api/std.c` et `dir.c`), pas le vrai LOCI.
- FORMAT.COM (lot L2, octobre 2026) : 1 573 octets, rien de résident ; noms des entrées
  disque du BIOS (`B_SELDSK`... `B_WRITE`) et de la fonction 13 (`F_RESET`) ajoutés à
  `cpa.inc` (ce sont les entrées du contrat, simplement nommées). Choix :
  - Le contrôleur est piloté directement par FORMAT : le BIOS n'a pas d'entrée Write Track,
    et en ajouter une coûterait de la place résidente et toucherait le contrat commun avec
    la ROM. FORMAT tient à jour les variables du pilote (`phy_drv`, `dsk_trk`, signalées
    dans `src/hw.inc`), comme `md_sel`, pour que le BIOS retrouve la bonne piste ensuite.
    Positionnement sans vérification (piste vierge), RESTORE au début.
  - Vérifié avant de coder : le LOCI (loci-firmware, `src/mia/oric/dsk.c`) et Oricutron
    font Write Track. Le LOCI retrouve les données d'un secteur à un écart fixe après son
    en-tête : l'image de piste reprend donc exactement la disposition de `mkdisk.py`
    (60 x `$4E`, puis par secteur 12 x `$00`, `$F5` x 3, `$FE`, C H R N, `$F7`, 22 x `$4E`,
    12 x `$00`, `$F5` x 3, `$FB`, 256 x `$E5`, `$F7`, 38 x `$4E`), soit 6 078 octets,
    complétés à 24 pages ; ensuite `$4E` jusqu'à la fin de la commande (impulsion d'index
    sur un vrai lecteur, 6 400 octets sur le LOCI et Oricutron). Une fin avant les dernières
    données (6 040 octets) est signalée (« Piste ecrite en partie seulement »).
  - Entrelacement 2:1 (1, 10, 2, 11... 9) : sans lui, un vrai Microdisc ne lit qu'un
    secteur par tour (le BDOS traite le secteur pendant que le suivant passe) ; avec, une
    piste se lit en deux tours environ. Sans effet sur le LOCI et Oricutron (la recherche
    d'un secteur n'y dépend pas de la rotation), et `mkdisk.py` reste en ordre 1:1.
  - Relecture de chaque piste aussitôt écrite (17 secteurs, tous à `$E5`, deux essais) :
    c'est la vérification, et sur le LOCI elle remet aussi à neuf le compteur d'attente
    du firmware (`dsk_rw_countdown`, fixé par une lecture mais pas par Write Track) avant la
    piste suivante. Le répertoire est vide de lui-même (secteurs à `$E5`).
  - `/Q` passe par le BIOS (SELDSK, SETSEC, SETDMA, WRITE : leur première vraie
    utilisation) et écrit 16 secteurs de `$E5` (LSN 68 à 83) ; une disquette illisible est
    refusée.
  - Un seul lecteur : `FORMAT A:` vide le tampon du BDOS (fonction 13) avant de demander
    la disquette, puis demande la disquette système avant le démarrage à chaud. ESC entre
    deux pistes interrompt.
  - Essayé dans Oricutron : disquette de données et image vierge (sans aucun secteur)
    formatées, chaque piste contrôlée (ordre des secteurs, CRC, `$E5`), copie et relecture
    de LOGO.COM sur la disquette formatée, `/Q`, refus de `/Q` sur une image vierge, réponse
    N, ESC, lecteur absent (`Lecteur C: absent ou vide`), `FORMAT A:`. Environ une minute
    dans Oricutron pour une disquette complète.
  - Correction (signalée par Pierre, disquette SEDORIC en B:) : « Relecture : erreur
    secteur 01 » sur la face 0 de chaque piste. Oricutron garde en cache la disposition des
    secteurs d'une piste (lue au positionnement ou au changement de face) et ne l'oubliait
    pas après Write Track ; SEDORIC place ses secteurs ailleurs (premier en-tête à l'octet
    108 de la piste, 72 pour CP/A), la relecture visait donc les anciennes positions. Les
    disquettes déjà au format CP/A passaient (mêmes positions). Deux remèdes : FORMAT se
    positionne avec la face 1 choisie (la face 0 est alors relue d'après une piste fraîche,
    y compris avec l'Oricutron de l'OSDK, non corrigé) ; et le correctif d'Oricutron vide ce
    cache à la fin de Write Track (`disk.c`). Essayé : la disquette SEDORIC de Pierre et sa
    copie à moitié formatée, 84 pistes contrôlées.
- DISKCOPY.COM (lot L3, octobre 2026) : 2 216 octets (deux blocs), rien de résident.
  Choix :
  - Les secteurs passent par SELDSK, SETSEC, SETDMA, READ et WRITE du BIOS (leur première
    vraie utilisation : elles marchent), par tranches aussi grandes que la TPA (une page par
    secteur, du haut du programme au haut de la TPA, `$020C` : ~165 secteurs en mode texte,
    moins en SPLIT). SELDSK avant chaque passage d'un lecteur à l'autre ; il ne relit le
    répertoire qu'au premier appel. La source et la destination sont vérifiées lisibles
    avant la confirmation (`Destination illisible : FORMAT ?`).
  - Sans `/T` : LSN 0-67, puis les blocs cités par le répertoire de la source (lu
    directement, 16 secteurs ; blocs 0 et 1 toujours). Le reste de la destination garde son
    ancien contenu, que plus rien ne désigne.
  - `/S` : LSN 0-67, puis les fichiers SYS (extent 0 du répertoire de la source, 48 au plus)
    copiés par le BDOS comme COPY.COM ; sur la destination, attributs levés (fonction 30),
    fichier effacé, recopié, puis attributs de la source posés. Les autres fichiers ne
    bougent pas (les secteurs 0-67 sont hors de la zone des fichiers). Deux lecteurs exigés :
    avec un seul, il faudrait garder les fichiers en mémoire entre deux échanges.
    **Remplacé au lot LA** : `/S` ne copie plus que LSN 0-67 (SYSGEN), y compris avec un
    seul lecteur ; les fichiers se copient par `COPY *.COM B:`.
  - Un seul lecteur (`DISKCOPY A: A:`), fait dès ce lot pour la copie de secteurs : la
    source puis la destination sont demandées à chaque tranche ; le tampon du BDOS est vidé
    (fonction 13) avant le premier échange, et la disquette système est redemandée avant le
    démarrage à chaud.
  - Au passage, bug de SET corrigé : `SET B:NOM RO` changeait les attributs du fichier de
    même nom sur le lecteur courant (le FCB de la fonction 30 avait toujours le lecteur 0) ;
    il prend maintenant le lecteur demandé.
  - Essayé dans Oricutron : copie sur une disquette formatée par FORMAT (secteurs utiles
    identiques, la copie démarre), `/T /V` (1 428 secteurs identiques), `/S /V` (système
    identique, COPY.COM protégé de la destination remplacé, fichiers de données gardés,
    attributs recopiés), `A: A:` (échanges demandés à chaque tranche), destination non
    formatée refusée, `/S` avec un seul lecteur refusé, ESC.
- Attributs « à la CP/M » (lot LA, octobre 2026, option C choisie par Pierre après
  discussion : sur les disquettes CP/M, les commandes étaient visibles ; SYS servait surtout,
  sous CP/M 3, à partager les commandes de la zone utilisateur 0, que CP/A n'a pas ; SYSGEN
  ne copiait que les pistes système, PIP les fichiers). Un attribut, un sens : R/O protège,
  SYS cache de DIR (laissé à l'utilisateur), `DISKCOPY /S` = SYSGEN.
  - Disquette livrée : commandes et applications R/O et visibles, plus README.TXT et
    CPA.INC ; exemples (HELLO, GTEST, leurs `.ASM`, DEMO.LOG, DESSIN.BAT) sans attribut
    (ASM doit pouvoir réécrire HELLO.COM). Attributs posés par `mkdisk.py` (`--ro` / `--rw`
    dans `new`, commande `attr`, `ls` les montre), listes dans `build.sh`.
  - STAT : colonne `At` (`R` protégé, `S` système) et ligne finale `n fichier(s), R : n,
    S : n` (36 colonnes au plus). STAT.COM 916 octets.
  - COPY réécrit, jokers admis comme PIP (1 033 octets, au lieu de 360) : source avec
    jokers ; destination = nom, lecteur seul (mêmes noms), modèle avec `?` (caractère de la
    source), ou absente (lecteur courant, si la source a un lecteur). Noms relevés d'abord
    (premier extent, 128 au plus), puis copiés un à un. Attributs non recopiés (comme PIP).
    Destination protégée : laissée (`fichier protege`, F_DELETE rend `$FE`) ; même fichier :
    refusé ; répertoire plein ou disque plein : arrêt, copie partielle effacée. Le tampon va
    jusqu'au haut de la TPA (`$020C`) : l'ancien COPY écrivait jusqu'à `$B400` même en
    SPLIT, sur l'image. Pas de copie entre disquettes avec un seul lecteur (plus tard).
  - IMPORT sur un fichier protégé : `Fichier protege (SET fic RW)` au lieu de `Repertoire
    plein`.
  - DISKCOPY : la copie des fichiers SYS est retirée (1 658 octets au lieu de 2 216, un
    seul bloc) ; `/S` marche donc aussi avec un seul lecteur.
  - Essayé dans Oricutron : STAT `*.*` (20 protégés), `ERA COPY.COM` refusé, `ERA *.LOG`
    efface DEMO.LOG (non protégé, comme voulu) ; `DISKCOPY A: B: /S` puis `COPY *.COM B:`
    (20 commandes identiques, sans attribut, système identique) ; COPY vers un fichier
    protégé, `*.ASM *.BAK`, nom unique, même fichier, aucun fichier, usage ; IMPORT sur
    README.TXT protégé.
- Piste J (octobre 2026) : TYPE, ERA et REN quittent le CCP pour TYPE.COM (177 octets),
  ERA.COM (674) et REN.COM (499), protégés sur la disquette livrée. Gain résident : 298
  octets (marge 192 -> 490). Leurs messages passent en français (programmes), sauf ce que
  le BDOS affiche. Retirés aussi du CCP : `all_wild`, les messages `ALL (Y/N)?`, `File
  exists` et `File R/O`.
  - TYPE : même conduite (arrêt au ^Z, une touche interrompt, retour à la ligne final si
    besoin). Sans jokers.
  - ERA : relève les fichiers visés (premier extent, 128 noms), les montre 3 par ligne comme
    DIR, compte les protégés (gardés, puisque la fonction 19 les épargne), puis demande
    `Effacer n fichier(s) (O/N) ?` — même pour un seul fichier (Pierre avait effacé un
    fichier par erreur, nom complété par ESC). `/Q` : sans question, pour les scripts (un
    script avec ERA sans `/Q` attend la réponse). L'effacement passe par la fonction 19 avec
    le nom tapé (jokers compris).
  - REN : syntaxe `nouveau=ancien` de CP/M 2.2, espaces admis autour de `=`, lecteur d'un
    seul côté valant pour les deux ; refus si le nouveau nom existe, si l'ancien est protégé
    ou introuvable.
  - Les commandes restent utilisables dans les scripts, par PUT (`PUT OUT.TXT TYPE X`) et
    depuis un autre lecteur (programme cherché sur A:). Le menu Fichiers tape toujours
    `TYPE `, `REN `, `ERA `.
  - Essayé dans Oricutron : TYPE (texte, sans nom, introuvable), ERA (un fichier refusé par
    N, `*.LOG` confirmé, `*.COM` : 2 fichiers proposés et 21 protégés gardés, réponse autre
    que O = abandon, `/Q` dans un script), REN (renommage, nom existant, fichier protégé,
    introuvable, usage), PUT avec TYPE.
- EXPORT avec jokers (octobre 2026) : `EXPORT afn [dossier]` — les noms sont relevés d'abord
  (premier extent, 128 au plus, comme COPY), puis copiés un à un sous leur nom de CP/A
  (`NOM.EXT`, sans les espaces), en minuscules si le modèle tapé en contient (lecteur mis à
  part) : `export *.log` donne `demo.log`. Le 2e mot est alors un dossier (« / » ajouté
  s'il manque ; `1:/ORIC`, `0:` admis), plus un nom. Un `.DSK` est sauté (« Refuse »), une
  erreur de la clé arrête tout, ESC arrête entre deux fichiers ; fin : `n fichier(s)
  exporte(s)`. La copie d'un fichier est devenue la routine `xone`, commune aux deux cas.
  EXPORT.COM 1 741 octets. Essayé dans Oricutron (MIA simulée) : `*.ASM`, `*.log oric`,
  `HELLO.* 1:/Oric/`, aucun fichier, nom seul inchangé ; contenus identiques.

- EDIT, lot L5 (octobre 2026) : raccourci `^L` pour Insérer... (`^K`, proposé dans la
  backlog, n'était pas libre : c'est le code de la flèche haut, `$0B`) et impression : article
  « Imprimer ^P » du menu Fichier et raccourci `^P` (libre dans EDIT : le CTRL-P du système
  n'agit que pendant la lecture d'une ligne). Tout le texte, dans l'ordre, par la fonction 5
  du BDOS ; CR LF à la fin de chaque paragraphe (l'imprimante coupe les lignes longues), et
  à la fin d'un dernier paragraphe sans CR. ESC (`B_CONST` à chaque paragraphe) arrête :
  « Impression interrompue ». Sans imprimante, LIST attend 2 ms par caractère puis continue
  (rien ne bloque, ESC pour abréger). Menu Fichier : 7 articles. EDIT.COM ~110 octets de
  plus. Essayé dans Oricutron : `printer_out.txt` identique au fichier enregistré par EDIT
  (DEMO.LOG, 447 octets), `^L` insère DEMO.LOG, menu affiché.

- LOGO, lot L4 (graphisme, octobre 2026) : `POINT x y`, `TRAIT`, `RECTANGLE`, `PAVE` (deux
  coins opposés), `CERCLE r`, `ETIQUETTE x`, `FIXECOULEUR v` et la fonction `ALLUME? x y`.
  LOGO.COM 18 217 octets (+746) ; zone des procédures : `procbase` `$6000` -> `$6300`
  (768 octets de moins pour l'utilisateur). Choix (« à confirmer » dans la backlog, décidés) :
  - Coordonnées de la tortue (centre 0 0, y vers le haut, décimaux admis), comme `FIXEXY` ;
    la tortue ne bouge pas. Les points passent par `scr_pos` (le calcul de la tortue) ; un
    point est évalué avant le suivant et gardé sur la pile (une fonction peut dessiner).
  - Mode du crayon (trace, `GOMME`, `INVERSE`) respecté, que le crayon soit levé ou non
    (`LC` ne concerne que le trait de la tortue). La tortue est déjà cachée pendant
    l'exécution d'une ligne (`repl`) : rien à faire de plus pour « cacher la tortue ».
  - Découpage : `TRAIT` et `RECTANGLE` (quatre `TRAIT`) passent par `seg`, qui découpe aux
    bords ; `PAVE` met ses coins dans l'ordre et les borne à l'image (rien s'il est dehors) ;
    `CERCLE` (BDOS, centre sur 8 bits) et `ETIQUETTE` ne dessinent rien si la tortue est
    hors de l'image, le BDOS découpant le reste. Rayon 0 à 127 (limite du BDOS), au-delà
    `Valeur hors limites`.
  - `ETIQUETTE` : la valeur écrite comme par `ECRIS` (un nombre passe par `as_text`), 40
    caractères au plus, copiés dans `llbuf` ; colonne = x / 6, haut du texte = y - 7 (le
    texte est posé sur la ligne de la tortue, à sa droite).
  - `FIXECOULEUR v` : attribut (encre 0-7, papier 16-23 ; 8-15 refusés) en colonne 0 des
    lignes 0 à 126 (la 127 porte le retour au texte) ; le BDOS ne trace jamais sur un octet
    d'attribut, la couleur reste.
  - `ALLUME? x y` : 0 hors de l'image.
  - Tous refusent l'écran texte (`need_img`).
  - Essayé dans Oricutron, et nouveau scénario de `tools/test_logo.sh` (`t14.log` : dessin,
    `ALLUME?` sur un point, hors de l'image, sur un trait gommé, dans un pavé ; `CERCLE 200`
    et `FIXECOULEUR 10` refusés ; empreinte de l'image).
  - Constaté au passage : `CHARGE` ne lit pas un fichier aux lignes terminées par LF seul
    (fichier du Mac) : `IMPORT /T` est indispensable pour un `.LOG` (signalé dans le README).

- Complétion des commandes par ESC (octobre 2026, à la demande de Pierre, réversible) : en
  début de ligne du CCP (mot qui commence à la colonne 0 ; pas dans LOGO ni DEBUG, qui
  lisent aussi leurs lignes par la fonction 10), ESC propose les commandes internes (table
  du CCP, `cmd_table`, relue telle quelle) et les fichiers `.COM` / `.BAT` du lecteur
  courant, sans leur type ; les autres fichiers ne sont pas proposés. Le reste de la ligne
  garde la complétion des noms de fichiers. Coût : 123 octets résidents (marge 490 -> 367),
  et `cp_ti`, `cp_first` (`$FDA8-$FDA9`, octets libres après `dsk_trk`). Option d'assemblage `CPLCMD`
  (`#ifdef` dans `src/rline.s`), mise par `build.sh` (`DISK_OPTS`, `-DCPLCMD` par défaut) :
  `DISK_OPTS="" ./build.sh` donne un système sans elle, de même taille qu'avant (seules
  deux cibles de branchement changent), et le commit est à part (`git revert` possible).
  Écarté : chercher aussi sur A: depuis un autre lecteur (plus coûteux, peu utile).
  Essayé dans Oricutron : `FB` -> `FBOX `, `ED` -> `EDIT `, `DES` -> `DESSIN `, `D` et `L`
  (listes), `HEL` (HELLO et HELP), `TYPE REA` -> `TYPE README.TXT ` (inchangé).

## Suite prévue (par priorité)

**Prochains lots, dans l'ordre voulu par Pierre** (une livraison testée et un commit par lot ;
les coûts sont des estimations, et l'expérience montre qu'elles sont souvent dépassées du
simple au double). Principe posé par Pierre : la plupart des possesseurs d'un vrai lecteur
n'en ont qu'un ; les commandes de manipulation de fichiers doivent donc pouvoir être sur
chaque disquette (d'où `DISKCOPY /S`), et une commande disque doit marcher avec un seul
lecteur dès que c'est possible.

| Lot | Contenu | Code | État |
|---|---|---|---|
| L1 | **Échange de fichiers avec la clé USB du LOCI** (voir 6 plus bas) : `EXPORT fic [nom]`, `IMPORT nom [fic] [/T]`, `USBDIR [chemin]` ; en tête, à la demande de Pierre | 1-1,7 Ko par `.COM`, rien de résident | **fait** (essayé dans Oricutron avec la MIA simulée ; reste le vrai LOCI) |
| L2 | **FORMAT.COM** : `FORMAT B:` formate au format CP/A (2 faces, 42 pistes, 17 secteurs de 256 octets) par la commande Write Track du WD1793 (image de piste MFM construite en TPA, ~6 250 octets : marques d'adresse, CRC écrits par le contrôleur, secteurs remplis de `$E5`), puis relit chaque piste (vérification) et écrit un répertoire vide. Confirmation « Tout X: sera efface (O/N) ». Marche avec un seul lecteur : `FORMAT A:` demande d'insérer la disquette à formater, puis de remettre la disquette système (le système reste en RAM ; le démarrage à chaud ne relit que le répertoire). Option `/Q` (formatage rapide) : répertoire vide seulement, pour une disquette déjà formatée (images du LOCI, et si l'émulation du LOCI n'a pas Write Track : à vérifier avant de coder, Oricutron l'a). À décider en codant : entrelacement des secteurs (vitesse sur un vrai Microdisc) | ~1 à 1,5 Ko, rien de résident | **fait** (1 573 octets ; essayé dans Oricutron ; restent le LOCI et un vrai Microdisc) |
| L3 | **DISKCOPY.COM** : `DISKCOPY A: B:` copie une disquette entière par les entrées SELDSK, SETSEC, SETDMA, READ et WRITE du BIOS (leur première vraie utilisation : à éprouver), par tranches de ~170 secteurs (TPA) : amorçage et système (LSN 0-67), répertoire, puis seulement les blocs occupés de la source ; `/T` copie tout, `/V` relit et compare. **`/S`** : rend une disquette démarrable sans toucher à ses fichiers (comme SYSGEN de CP/M) : amorçage et système, plus les fichiers de la source marqués SYS (`SET COPY.COM SYS`...), pour que chaque disquette ait ses commandes. Confirmation, ESC entre deux tranches, démarrage à chaud à la fin. La destination doit être formatée (L2). **À terme** : copie avec un seul lecteur (`DISKCOPY A: A:`, échange des disquettes à chaque tranche, ~9 échanges pour une disquette pleine, moins en ne copiant que les blocs occupés) | ~1 à 1,5 Ko, rien de résident | **fait** (2 216 octets ; un seul lecteur fait aussi, sauf pour `/S` ; restent le LOCI et un vrai Microdisc) |
| LA | **Attributs et copie « à la CP/M »** (décidé avec Pierre, octobre 2026, option C) : (1) la disquette livrée a ses commandes **R/O et visibles** (DIR les montre, comme sur une disquette CP/M) : HELP, SET, STAT, COPY, FORMAT, DISKCOPY, XDO, MEM, POKE, GO, EXPORT, IMPORT, USBDIR, EDIT, HEX, LOGO, ASM, DEBUG, plus README.TXT et CPA.INC ; les exemples (HELLO, GTEST, leurs `.ASM`, DEMO.LOG, DESSIN.BAT) restent sans attribut (ASM doit pouvoir réécrire HELLO.COM) ; attributs posés par `mkdisk.py` (nouvelle option) depuis `build.sh` ; (2) **STAT** : colonne `R` (protégé) / `S` (système, caché de DIR) et résumé en fin de liste ; (3) **COPY avec jokers**, comme PIP : `COPY *.COM B:`, `COPY B:*.LOG` ; (4) **`DISKCOPY /S` réduit à SYSGEN** : amorçage et système (LSN 0-67) seulement, la copie des fichiers SYS disparaît (les fichiers : `COPY *.COM B:`) ; SYS ne veut plus dire que « caché de DIR » ; (5) messages : IMPORT et COPY sur un fichier protégé disent `Fichier protege` (aujourd'hui `Repertoire plein`, `Write error`) | COPY grossit (~0,5 Ko), DISKCOPY maigrit ; rien de résident | **fait** (essayé dans Oricutron ; restent le LOCI et un vrai Microdisc) |
| L4 | **LOGO, lot B, partie graphisme** : POINT, TRAIT, RECTANGLE / PAVE, CERCLE, ETIQUETTE (texte à la position de la tortue), FIXECOULEUR (ATTR), ALLUME? (lire un point) ; coordonnées de la tortue (à confirmer) ; cachent la tortue, refusent l'écran texte | ~400-800 o, pris à la place de l'utilisateur | **fait** (essayé dans Oricutron ; reste le vrai Oric) |
| L5 | **EDIT** : raccourci clavier pour « Insérer » (proposé : `^K`, libre ; à confirmer) et impression du texte (article « Imprimer » du menu Fichier et raccourci, par la fonction 5 du BDOS, CR LF à chaque ligne ; sans imprimante, rien ne bloque) | ~150-300 o dans EDIT.COM | **fait** (raccourci `^L`, pas `^K` qui est la flèche haut ; essayé dans Oricutron) |
| LB | **Disquettes par usage** (décidé avec Pierre, octobre 2026) : `build.sh` fabrique `cpa-logo.dsk` (EDIT, LOGO, DEMO.LOG, DESSIN.BAT), `cpa-notes.dsk` (EDIT) et `cpa-asm.dsk` (EDIT, ASM, DEBUG, HEX, CPA.INC, HELLO et GTEST ; MEM, POKE, GO cachés). Sur chacune, les commandes de base (TYPE, ERA, REN, SET, STAT, COPY, HELP, FORMAT, DISKCOPY, XDO, EXPORT, IMPORT, USBDIR) sont **R/O et SYS** : DIR ne montre que l'outil et le travail. EDIT reste visible partout (« presque » système, mais une commande doit se voir). `mkdisk.py new` reçoit `--sys` / `--dir`. Usage conseillé : disquette d'usage en A:, données en B:. `cpa.dsk` inchangée (tout visible). HELP PROGRAMMES rappelle `DIRS *.COM` | rien dans le système ; HELP.COM +1 ligne | **fait** (essayé dans Oricutron : DIR, DIRS, STAT, ASM HELLO sur `cpa-asm.dsk` ; reste le LOCI) |
| LC | **Paragraphes et limites** (décidé avec Pierre, octobre 2026) : un paragraphe d'EDIT n'a pas de limite, mais ses lecteurs en ont (LOGO 126 par ligne, DO 78, l'imprimante sa largeur) et elles étaient invisibles. (1) **LOGO** : `CHARGE` refusait en silence la fin d'une ligne de plus de 126 caractères ; il s'arrête maintenant sur `Ligne de plus de 126 car. : L n` (n = numéro de ligne, comme `L` dans EDIT). Pas de listes sur plusieurs lignes (choix de Pierre : on concatène avec PH) ; (2) **EDIT** : `C` = position dans le paragraphe (et non plus colonne à l'écran) ; **`EDIT.CFG`** (texte, une règle par ligne : `[d:]afn maxi [MOTS\|CAR] [largeur]`, la première qui correspond s'applique, cherché sur le lecteur du document puis A:, lu à l'ouverture et à « Enreg. sous », réglages intégrés `*.LOG 126` et `*.BAT 78` sans lui) ; au-delà de maxi, `C nnn!` en inverse ; **^N** / Chercher, Trop long : premier caractère en trop du paragraphe trop long suivant ; Statistiques : plus long paragraphe et son numéro ; (3) **impression** coupée entre les mots à largeur-1 (pas de ligne blanche sur une imprimante qui passe d'elle-même à la ligne), mot trop long coupé au caractère. `EDIT.CFG` livré (R/W ; SYS sur les disquettes par usage) | rien dans le système ; EDIT.COM 6 656 -> 8 192 octets (texte : ~32 Ko au lieu de ~34) ; LOGO.COM +~40 o | **fait** (essayé dans Oricutron : `C127!`, ^N, Statistiques, règle par fichier, EDIT.CFG trouvé sur A: pour un document sur B:, impression à 30 et 40 colonnes ; reste le vrai Oric et une vraie imprimante) |
| LD | **HIRES plein écran par une bibliothèque** (décidé avec Pierre, octobre 2026 ; plutôt qu'un mode 3 résident de la fonction 115) : `progs/hires.inc` (`HIRES.INC` sur les disquettes), incluse par un programme : plein écran 240 × 200 et SPLIT avec les mêmes routines (`h_full`, `h_split`, `h_text`, `h_cls`, `h_pen`, `h_plot`, `h_line`, `h_box`, `h_fbox`, `h_circle`, `h_print`, `h_attr`, `h_point`, `h_load`/`h_save` .HIR ou .IMG, `h_key`), tables propres (200 lignes, x / 6, masques, copie de la police : 1,6 Ko après la fin du programme), page zéro `$C0-$C7`, étiquettes internes `hz_`. Règle : le programme prend l'écran et n'écrit pas sur la console avant `h_text`. **Filet résident** (~46 o) : `hires_on` (vmode = 0 et `$1E` en `$BFDF`) ; FUNCT ignoré, voyants non redessinés ; démarrage à chaud et reprise après plantage : retour au texte, police, écran, et historique des lignes vidé (`$BA80-$BB7F` recouvert par l'image) ; `video_text` recopie la police. **VOIR.COM** (`.HIR` plein écran, `.IMG` SPLIT, une touche) ; **`tools/png2hir.py`** (Pillow : mise à l'échelle, trame Floyd-Steinberg ou seuil, `--split`, `--apercu`). Aucun changement du contrat d'interface. La piste H (masque calculé) devient inutile pour ce besoin et reste en réserve | VOIR 1,7 Ko ; résident +46 o | **fait** (Oricutron : VOIR plein écran et SPLIT, FUNCT ignoré, programme qui sort sans `h_text`, flèche haut après le HIRES ; reste le vrai Oric : bascule du circuit vidéo, 3 lignes du bas noires) |
| LE | **GRAPHER.COM, palier 2** (décidé avec Pierre : commandes en anglais, fichiers `.GRX`, nom GRAPHER) : exécute un fichier de commandes graphiques, une par ligne : HIRES, SPLIT, TEXT, GCLS, PEN, PLOT, LINE, BOX, FBOX, CIRCLE, GTEXT, ATTR, GLOAD/GSAVE (.HIR en HIRES, .IMG en SPLIT ; depuis le texte, le type choisit le mode), WAIT, DELAY (1/50 s), ECHO (pas en HIRES), END, `;` ; `$1`-`$9` (casse d'origine, `ORIG_LINE`) ; erreurs `L n COMMANDE : message` ; ESC entre deux lignes (une autre touche est gardée pour WAIT) ; en fin de fichier, HIRES attend une touche, SPLIT reste au-dessus du prompt ; lancé en SPLIT, dessine sur l'image en place. Dessin par `hires.inc`, pas par la fonction 115. **Les commandes PEN, PLOT, LINE, BOX, FBOX, CIRCLE, GTEXT, ATTR, POINT quittent le CCP de la version disque** (la ROM les garde) ; SPLIT, TEXT, GCLS, GSAVE, GLOAD restent. `DESSIN.BAT` devient `DESSIN.GRX` ; `ECRAN.GRX` (plein écran, couleurs par attributs). Paliers 3 (LF) et 4 (LG) faits | GRAPHER 3,4 Ko ; résident −224 o | **fait** (Oricutron : ECRAN, DESSIN avec paramètre, erreurs, ESC, GSAVE puis GLOAD .HIR depuis le texte ; ASM identique à xa pour VOIR et GRAPHER) |
| LF | **GRAPHER, palier 3** (« indispensable », Pierre) : le fichier est chargé en mémoire (jusqu'à `$9F00`) et exécuté avec un pointeur de ligne. Entiers 16 bits signés, variables `A`-`Z`, affectation `V = expr` / `LET` ; expressions à priorités (signe ; `* / %` ; `+ -` ; comparaisons 1/0 ; `& \|`), parenthèses, `RND(n)`, `ABS(n)`, `POINT(x,y)`, `INKEY` ; règle des espaces : un paramètre parmi plusieurs n'a pas d'espace (sauf entre parenthèses), une expression seule en fin de ligne si. Blocs : `REPEAT n`, `FOR V a b [pas]`, `WHILE expr` (fermés par `NEXT`), `IF`/`ELSE`/`ENDIF`, `SUB NOM`/`ENDSUB`/`RETURN` et `CALL NOM` ; pile de contrôle de 16 entrées ; les blocs sautés sont parcourus par classe de commande (table : nom, classe, adresse ; commandes fréquentes en tête, deux fois plus rapide). `PRINT expr`, `GNUM col y n`. Erreurs : `NEXT sans boucle`, `NEXT manquant`, `bloc non ferme`, `SUB introuvable`, `RETURN sans CALL`, `division par zero`, `expression ?`, `valeur hors de 0-255`, `variable ?`, `pas nul`, `trop de blocs imbriques`. Exemples `MOTIFS.GRX`, `ARDOISE.GRX` (télécran avec INKEY). `tools/test_grapher.sh` : non-régression dans le 6502 simulé (`run_com.py` accepte la fonction 115 en mode texte). Vitesse mesurée : ~170 lignes/s pour `PLOT 1+RND(238) 1+RND(198)` + `NEXT` | GRAPHER 3,4 -> 6 Ko ; rien de résident | **fait** (Oricutron : MOTIFS, ARDOISE aux flèches ; test_grapher 15 cas ; ASM identique à xa) |
| LG | **GRAPHER, palier 4 : traduction en assembleur** (Pierre : « oui ») : `GRAPHER NOM /A` écrit `NOM.ASM` (supprimé en cas d'erreur), qu'ASM assemble en `NOM.COM`. Même analyse que l'interpréteur (table des commandes à deux adresses : exécution, traduction ; `binop`, `parse_num`, `parse_id`, `find_fn`, `relop`, `x_open`/`x_close` partagés). Expressions compilées avec un état « constante en attente » : calcul des parties constantes à la traduction (par `binop`), sinon `g_ev`/`g_et` et la pile des valeurs de la bibliothèque. Bibliothèque d'exécution **`progs/grx.inc`** (`GRX.INC`) : opérations, comparaisons, `RND`, `POINT` (garde `h_x1`/`h_y1`, corrigé aussi dans l'interpréteur), `INKEY`, `PRINT`/`GNUM`, textes et noms d'images placés après l'appel (`g_str`), boucles (`g_rept`, `g_forok`, `g_forstep`, 4 octets `Bn` par bloc), ESC à chaque `NEXT`, erreurs d'exécution sans numéro de ligne. Code lisible : ligne source en commentaire, `V_A`-`V_Z`, `L3T`/`L3E`/`L3X`, `P_NOM`. `run_com.py` remplit `ORIG_LINE`. `test_grapher.sh` : chaque test interprété puis traduit, assemblé (xa) et exécuté (`.ref`, `.kref`) | GRAPHER 6 -> 10 Ko ; GRX.INC (source) ; rien de résident | **fait** (Oricutron : ECRAN compilé = interprété (image identique), MOTIFS 8 fois plus rapide, ARDOISE ; chaîne complète sur l'Oric émulé : `GRAPHER MOTIFS /A`, `ASM MOTIFS` (< 1 min), `MOTIFS` ; ASM = xa sur les 5 programmes produits) |

La piste J de la revue de place (TYPE, ERA et REN en `.COM`) est **faite** (octobre 2026,
voir « Choix déjà faits »), avec la confirmation d'ERA. La complétion par ESC des commandes
(premier mot) est faite aussi, dans un commit à part et derrière une option d'assemblage.

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

1. **LOGO : primitives graphiques, chargement par étapes.** Les modules (« bibliothèques
   dynamiques » : noyau, table d'accès, modules `.LGM` relogés comme les PRL de MP/M) sont
   **mis de côté**. Raison : ils ne rendaient que 4 à 6 Ko pris au code de LOGO, alors que ce
   qui grossit dans un grand projet, ce sont les procédures et les textes de l'utilisateur ; et
   pour ceux-là, le chargement par étapes existe déjà sans rien coûter : un fichier `.LOG` peut
   contenir n'importe quelles lignes (CHARGE les exécute), OUBLIE rend la place (les procédures
   suivantes sont recopiées vers le bas), les variables globales restent. En mode interactif,
   l'utilisateur n'a pas besoin de beaucoup de mémoire. Essayé dans Oricutron : un noyau qui
   enchaîne trois salles, chacune dans son fichier (exemple dans le README, « Un grand
   programme par étapes »). L'étude des modules reste dans l'historique git (commit 0702b64).

   | Lot | Contenu | Complexité | État |
   |---|---|---|---|
   | B | primitives du BDOS 115/116 que LOGO n'expose pas, directement dans LOGO.COM (sans modules). Son : SON, SONF, BRUITV, ENVELOPPE, MELANGE, ENSEMBLE, ATTENDSSON, JOUE? (NOTE et BRUIT supprimés), +460 o. Graphisme : POINT, TRAIT, RECTANGLE / PAVE, CERCLE, ETIQUETTE (texte à la position de la tortue), FIXECOULEUR (ATTR), ALLUME? (lire un point) ; coordonnées de la tortue (à confirmer) ; cachent la tortue, refusent l'écran texte. Estimé 350-400 o, pris à la place de l'utilisateur | moyenne | son **fait**, graphisme à faire |
   | E | `CHARGE` accepte un nom calculé (`CHARGE :S`, `CHARGE MOT "S :N`) : plus besoin d'une ligne `SI` par fichier | faible | **fait** |
   | F | `CHARGE` dans un fichier chargé : l'état du premier chargement (FCB, tampon, reprise) était écrasé, la fin du fichier perdue et le programme appelant arrêté sans message ; maintenant refusé par un message | faible | **fait** |
   | D | plus tard, si besoin : procédures converties en jetons à la définition (vitesse, place ; LISTE et EDITE retraduisent) | élevée | piste |

   Écarté pour l'instant : une primitive générique `.SYSTEME n [liste]` (seules les fonctions
   115 et 116 s'y prêtent, les autres demandent des adresses ; risques : quitter LOGO, mode
   d'écran désynchronisé, traces de la tortue). À reconsidérer avec PEEK / POKE, « pour experts ».

2. **Réseau par le LOCI** (matériel décrit dans `docs/loci-modem-wifi.md`, pas encore acheté) :
   - pilote série dans le BIOS, branché sur PUNCH / READER : ACIA 6551 en `$0380` sur le LOCI
     (`$031C` dans Oricutron), adresse dans une variable, ~150 octets (place : zone du code ;
     variables en `$FDA8-$FDAF` et `$FDF8-$FDFF`, libres et remises à zéro au démarrage à
     froid) ;
   - `XFER.COM` : envoi et réception de fichiers en XMODEM (paquets de 128 octets acquittés) ;
   - `tools/xfer_server.py` : serveur XMODEM sur le Mac ;
   - `TERM.COM` : terminal (commandes AT du modem PicoWiFiModemUSB).
3. Petites améliorations notées : `AUTO.BAT` exécuté au démarrage ; commande `NOTE` au prompt
   (son dans les scripts) ou `PLAY.COM` (partition texte) ; ne pas perdre la frappe anticipée
   pendant `NOTE`/`ATTENDS` dans LOGO (EDIT : lot L4). Bibliothèque LOGO `MATH.LOG` de Pierre (PI, PUIS, FACT) :
   hors de la disquette construite pour l'instant.
   Son : la partie son du lot B est faite (volume réglable par `SON`) ; restent la commande
   au prompt ou `PLAY.COM`.
4. Lecteurs : FORMAT, DISKCOPY et COPY avec jokers faits (lots L2, L3, LA) ; reste COPY
   d'une disquette à l'autre avec un seul lecteur (échanges, comme DISKCOPY A: A:).
5. Pistes : base de données simple sur l'accès direct.
6. **Échange de fichiers avec la clé USB du LOCI** (étude, octobre 2026). Le LOCI dérive du
   Picocomputer 6502 (RP6502) : son « MIA » expose à l'Oric l'API du RIA, en `$03A0-$03B9`
   (`loci-rom/src/asminc/loci.inc`) : `MIA_XSTACK` `$03AC` (pile d'échange de 512 octets : on
   y écrit les octets en ordre inverse, on les y relit), `MIA_ERRNO` `$03AD`, `MIA_OP` `$03AF`
   (écrire le numéro lance l'opération), `MIA_SPIN` `$03B0` (JSR : attend la fin),
   `MIA_BUSY` `$03B2`, `MIA_A` `$03B4`, `MIA_X` `$03B6`, `MIA_SREG` `$03B8`. Opérations :
   `$14` open (nom poussé sur la pile, A = drapeaux à la cc65 : 1 lecture, 2 écriture,
   `$10` créer, `$20` tronquer, `$40` ajouter), `$15` close, `$16` read_xstack (256 octets au
   plus), `$18` write_xstack, `$1A` lseek, `$1B` unlink, `$1C` rename, `$80`-`$82`
   opendir / closedir / readdir, `$83` mkdir. Résultat dans A/X (X négatif : erreur, code dans
   `MIA_ERRNO`). Chemins : `1:` est la clé USB (FAT, FatFs ; une 2e clé serait `2:`), `0:` la
   mémoire interne du LOCI (littlefs). Plan : `EXPORT fic [nom]` (fichier CP/A -> `1:/NOM`,
   les `^Z` de fin retirés pour un texte), `IMPORT nom [fic]`, et un `USBDIR` (liste de la clé).
   Tout en `.COM`, rien de résident, marche avec un seul lecteur. **Fait** (lot L1, voir
   « Choix déjà faits »). Reste à vérifier sur le vrai LOCI (Oricutron n'a que notre
   simulation ; l'émulateur Phosphoric dit émuler le LOCI) : la reconnaissance du LOCI
   (signature en `$03B0`) ; écriture sur la clé pendant que `cpa.dsk`, sur la même clé, est
   monté comme lecteur Microdisc ; interruptions de CP/A pendant `MIA_SPIN` ; les drapeaux
   d'ouverture ; le lecteur par défaut (sans `1:`) avec et sans hub ; la vitesse.
   Jokers dans EXPORT : faits (octobre 2026, voir « Choix déjà faits »). Suites possibles : conversion CR LF -> LF à l'EXPORT si le Mac
   la demande, liste des appareils du LOCI (`opendir("")`).

7. **Images : dessin GRAPHER ou copie d'écran ?** (backlog, octobre 2026 ; rien à coder avant
   les essais de Pierre sur le vrai Oric). Pierre compare deux façons de garder un écran : un
   dessin décrit par un `.GRX` (exécuté ou traduit en `.COM`) et une copie d'écran (`.HIR`,
   8 000 octets ; `.IMG`, 5 120). Repères mesurés : un `.COM` traduit pèse au moins 3 114 octets
   (bibliothèques entières : `GRX.INC` 1 620, `HIRES.INC` 1 488), puis quelques dizaines
   d'octets par commande (`LINE` : 26) ; à l'exécution, +1,6 Ko de tables après le programme.
   Pistes notées :
   - **Découper `GRX.INC` et `HIRES.INC` en modules** (noyau, cercle, texte, images, division,
     RND...) et n'écrire que les `#include` utiles : 700 à 900 octets estimés pour `HIRES` +
     `LINE` (estimation à prendre large) ; zones à zéro de `GRX.INC` (~150 octets) après la fin du
     programme ; police copiée seulement si le programme écrit du texte (768 octets de mémoire).
     Pas maintenant (Pierre).
   - **Reprendre le compresseur d'images** fait avec Claude auparavant (à retrouver : il n'est ni
     dans ce dépôt ni dans les conversations consultées) : images `.HIR`/`.IMG` compressées sur
     la disquette, décompressées au chargement (`hires.inc`, VOIR, GRAPHER).

## Contraintes à garder en tête

- 544 octets libres dans la zone du code (667 sans l'option `CPLCMD`) et 66 dans la page `$FF00` : tout ajout résident se
  justifie, le reste va en `.COM` (le pilote série prévu en demande ~150 estimés, donc
  plutôt 300 : les estimations ont été dépassées du simple au double). Réserve : pistes H et
  I de la revue de place (~325 octets) ; J (TYPE, ERA et REN en `.COM`) est faite.
- Les interruptions sont coupées pendant les accès disque (une touche peut être perdue, le
  compteur 50 Hz retarde).
- Ne rien changer au contrat d'interface (`docs/architecture.md`) sans penser à la version ROM.
