# CP/A disquette — réserves de place

Marges du système et des disquettes, pistes pour gagner de la place. À lire avec
`docs/etat.md` ; `./build.sh` affiche les marges.

**Système** (marge 463 octets ; fenêtre : 2 octets pour PUT, 4 pour IMG, 91 pour GFX ; page
`$FF00` : 10 octets ; variables du BDOS : aucune libre en `$FD13-$FD57` ; rappel automatique de
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
chaque banque suivante rend presque toute sa taille). Le pilote série (660 octets, `docs/suite.md`
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
dans `build.sh` (puis le fichier de configuration de la construction sur l'Oric, `docs/suite.md` point
8). Le code du démarrage à froid va toujours dans la fenêtre.

**Disquettes** (blocs de 2 Ko : un octet gagné ne rend un bloc qu'en repassant sous un
multiple de 2 048) :

- tampons stockés dans le fichier, à sortir après la fin du programme : DEBUG (122), EDIT
  (842), HEX (432), XDO (512) ;
- GRAPHER (18 175 octets) prend 9 blocs, 257 octets libres dans le dernier ; piste de
  place : messages d'erreur par numéro, ~40 octets. GRXASM (17 085) prend 9 blocs, 1 347
  octets libres dans le dernier (17 013 en anglais ; le texte d'un `.GRX` à traduire va de
  `$51A4` à `$9CE0`, ~19,2 Ko : 738 octets de moins depuis la lecture de `GRX.LIB`) ; ORIC.INC (9,3 Ko sur la disquette) prend 5 blocs ;
  GRX.INC (12 492 octets sur la disquette, CR LF, marques `;@` et messages compris) prend 7
  blocs, 1 844 octets libres dans le dernier ; GRX.LIB (32 174, 32 115 en anglais) prend
  16 blocs, 594 octets libres dans le dernier. HELP (13 029) prend 7 blocs, 1 307 octets libres dans le dernier (12 850 en anglais, 7
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
- usage à deux disquettes : sur `cpa.dsk` il reste 358 Ko (358 sur `cpa-en.dsk`) ; le
  travail va de préférence sur une disquette de projet en B: (658 Ko), GRXASM `/C` ne
  laisse que le `.COM`, ASM n'écrit le `.SYM` que sur demande (`/S`) ;
- répertoire : 127 fichiers au plus par disquette (entrée 0 : l'étiquette ; un fichier en
  prend une par tranche de 16 Ko) ; CMDER et la complétion comptent sur 128 entrées au plus ;
- blocs de 1 Ko : écartés (ce ne serait plus le format de CP/M 2.2,
  `docs/etude-stockage.md`).

**Mémoire de GRAPHER interprété** : environ 17 Ko pour le texte, les tableaux et une
animation (`docs/grapher.md` § 13) ; `CUBE.ANI` et `BALLE.ANI` ne se jouent qu'en traduit.
Chaque octet de plus dans GRAPHER.COM en retire un.

