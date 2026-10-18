# CP/A pour l'Oric sous BASIC — spécification de travail

But : que ce qui est fait sous CP/A serve aussi sur un Oric Atmos ordinaire, sans disquette
CP/A : des programmes en assembleur chargés par `CLOAD`, des routines rapides appelées depuis
un programme BASIC, et, au bout du chemin, un jeu écrit en GRAPHER qui tourne sur n'importe
quel Atmos (cassette ou LOCI). Quatre niveaux, chacun utile seul ; ils sont décrits dans
l'ordre où il faut les faire.

## 1. Ce qui est établi (Oricutron, ROM BASIC 1.1)

- **Format `.TAP`** (lu par `tape.c` d'Oricutron, essayé) : quelques octets `$16` (3 au moins),
  `$24`, puis l'en-tête : `$00 $00`, type (`$80` code machine, `$00` programme BASIC),
  démarrage automatique (`$00` non ; `$80` ou `$C7` : le code est lancé à la fin du chargement,
  essayé), adresse de **fin incluse** (octet fort, puis faible), adresse de début (fort,
  faible), `$00`, le nom (16 caractères au plus), `$00`, puis les octets. Plusieurs fichiers
  se suivent dans un même `.TAP`.
- **Chargement** : une routine de 11 octets en `$9000`, mise dans un `.TAP`, arrive intacte
  par `CLOAD""` ; `CALL #9000` l'exécute et le BASIC reprend (`Ready`).
- **Commande `!`** : la ROM fait `JMP ($02F5)` (`$CD13`). `DOKE #2F5,#9000` puis `!` lance la
  routine ; elle finit par `RTS` et la suite de la ligne est exécutée (`!:PRINT 12` affiche
  12).
- **Interruption** : le vecteur IRQ de la ROM pointe sur `$0244`, qui contient `JMP $EE22`
  (NMI : `$0247`, `JMP $F8B2`). Un programme peut donc passer avant la ROM et lui rendre la
  main, ou la remplacer tout à fait.
- **Mémoire** : au démarrage, `37631 BYTES FREE` : le programme BASIC occupe `$0501-$97FF`.
  En mode texte, la police est en `$B400` et l'écran en `$BB80`, comme sous CP/A ; `$9800-$B3FF`
  (image HIRES et police du mode HIRES) n'est utilisé qu'en HIRES.
- **Ce qui n'existe plus sous BASIC** : le BDOS (`$0203`), la table BIOS (`$C000`), les menus,
  les fichiers. La ROM de l'Atmos, elle, est là et peut être appelée. La page 2 et une grande
  partie de la page zéro appartiennent au BASIC.

## 2. Niveau 1 : sortie `.TAP` (décidé, pas encore fait)

**`MKTAP.COM`** (sur l'Oric) et **`tools/mktap.py`** (sur le PC, pour `build.sh` et les essais)
font la même chose :

    MKTAP JEU PROG.COM 9000 /R CARTE.DAT 8000 IMAGE.HIR A000

- Écrit `JEU.TAP` : un bloc par fichier, à l'adresse donnée (hexa), nom = nom du fichier sans
  type ; `/R` après un fichier : démarrage automatique de ce bloc (`$80`).
- Un programme est d'abord assemblé à son adresse sous BASIC (`*= $9000`) : ASM le permet
  déjà, le `.COM` n'a pas d'en-tête.
- Pourquoi un programme à part plutôt qu'une option d'ASM : ASM est à moins de 260 octets du
  bloc suivant ; MKTAP sert aussi aux images (`.HIR` en `$A000`), aux cartes, aux polices,
  aux sons, et à plusieurs fichiers dans une seule cassette.
- Transport : `EXPORT JEU.TAP` vers la clé USB du LOCI, cassette montée par le LOCI,
  `CLOAD""`. Dans Oricutron : `-t JEU.TAP` (il tape lui-même `CLOAD""`).
- Taille estimée : moins de 1 Ko. Essais : `tools/run_test.sh` sur la ROM BASIC avec `-t`
  (le crochet de test tape maintenant `!`).
- **`CASSETTE.COM`** : écrit un `.TAP` sur le port cassette (vrai magnétophone) et lit une
  cassette vers un fichier `.TAP`, pour l'Oric sans LOCI. Un `.COM`, rien dans le système de
  la version disquette ; dans la version ROM, ce sera une fonction du système
  (`docs/projet-rom.md`).

## 3. Niveau 2 : boîte à outils pour le BASIC, par `!` (proposé)

Un module en code machine (`OUTILS.TAP`, par exemple) chargé en haut de la mémoire après
`HIMEM`, qui donne au BASIC les opérations rapides de GRAPHER :

    10 HIMEM #8BFF : CLOAD"OUTILS"
    20 !PASTE #4000,128, CX,CY, 2,1, 38,26
    30 !SCROLH -1, 2,1,39,26

- **Commandes candidates** : `PASTE` / `GRAB` (rectangle d'une carte en mémoire vers l'écran,
  et l'inverse : la carte est une zone d'octets chargée par `CLOAD`, avec sa largeur),
  `SCROLH` / `SCROLV` / `ROTH` / `ROTV`, `PRINTV` (texte vertical), `UNZ` (image `.HIZ`
  compressée, 8 000 octets décompressés depuis 2 à 4 Ko), `ANIM` (animation `.ANI`), plus
  tard les sprites en mode texte et les tuiles. Le BASIC a déjà `DRAW`, `CIRCLE`, `FILL` : pas
  de doublon.
- **Paramètres** : `!` suivi d'un mot et d'expressions BASIC séparées par des virgules. Le
  module lit la ligne avec les routines de la ROM (lecture du caractère suivant, évaluation
  d'une expression, conversion en entier) : leurs adresses sont à relever dans la ROM et à
  essayer dans Oricutron, comme pour `$02F5`. Repli sans la ROM : paramètres posés par `DOKE`
  dans un bloc, puis `!` ou `CALL`.
- **Page zéro** : les routines de GRAPHER se servent de `$00-$DF`, que le BASIC occupe. Le
  module sauve les octets de page zéro qu'il utilise en entrant et les rend en sortant (le
  coût, quelques centaines de cycles, est faible devant un `PASTE` plein écran).
- **Source** : les mêmes routines que `ARR.INC`, `SPR.INC`, `HIRES.INC`, `ANIM.INC`, avec un
  socle `ORIC.INC` à la place de `CPA.INC` (§ 5).

## 4. Niveau 3 : GRXASM pour un Oric seul (proposé)

`GRXASM JEU /O` traduirait un programme GRAPHER en un programme autonome dans `JEU.TAP`
(démarrage automatique), qui prend toute la machine : ni CP/A, ni BASIC pendant le jeu.

- Clavier : la lecture de la matrice du BIOS de CP/A (`kb_scan`), recopiée (le matériel est
  le même) ; compteur 50 Hz par l'interruption du VIA, en remplaçant le saut de `$0244`.
- Écran : LORES, HIRES, sprites, rectangles, images et animations : déjà des écritures
  directes en mémoire ; seuls les changements de mode (fonction 115) sont à refaire.
- Son : les routines AY de `src/snd.s`, incluses.
- Fichiers : `LOAD` / `BLOAD` d'un nom constant deviennent des données mises dans le `.TAP` au
  moment de la traduction ; `SAVE` et les noms calculés sont refusés à la traduction.
- Mémoire : `$0500-$B3FF` (environ 44 Ko) et la page zéro presque entière, puisque le BASIC
  ne tourne pas. `END` : retour au BASIC (page zéro et vecteurs rendus) ou redémarrage.
- Exemples à livrer : `CARTE.GRX`, `SERPENT.GRX`, `DEFILE.GRX` en `.TAP`.

## 5. Le socle `ORIC.INC`

Remplace `CPA.INC` pour les niveaux 2 et 3. Il fournit ce que les bibliothèques demandent au
système : passage en HIRES et retour au texte (attribut et police, sans la fonction 115), un
compteur de trames, une lecture du clavier (niveau 3), l'écriture d'un caractère à l'écran, et
rien pour les fichiers. Les bibliothèques reçoivent quelques `#ifdef` (ASM.COM devra les
comprendre, ou bien `tools/strip_inc.py` produira les deux versions).

| Bibliothèque | Sous BASIC (niveau 2) | Oric seul (niveau 3) |
|---|---|---|
| `HIRES.INC` | dessins, `h_unz`, LORES : oui ; modes : par le BASIC (`HIRES`, `TEXT`) | oui, modes par `ORIC.INC` |
| `ARR.INC` | tableaux, chaînes, rectangles : oui ; affichage et saisie : non | oui, saisie au clavier de `ORIC.INC` |
| `SPR.INC` | oui (après `ARR.INC` et `HIRES.INC`) | oui |
| `ANIM.INC` | oui, avec le compteur de `ORIC.INC` | oui |
| `FIL.INC` | non | données incluses à la traduction |
| `GRX.INC` | non | oui, sur `ORIC.INC` |

## 6. Niveau 4 : GRAPHER traduit en BASIC (possible, en dernier)

Un `.GRX` deviendrait un programme BASIC lisible et modifiable, dont les commandes lentes
(rectangles, sprites, images) sont des `!` du niveau 2.

- Correspondances simples : variables (le BASIC de l'Oric distingue aussi deux caractères),
  `FOR`, `REPEAT n` (`FOR`), `WHILE` et les blocs `IF ... ENDIF` (`IF NOT ... GOTO`),
  sous-programmes (`GOSUB`), `LOCATE` / `PRINT` (`PLOT`, `PRINT`), `INKEY` (`KEY$`).
- Le `.TAP` d'un programme BASIC contient les lignes **tokenisées** : la table des mots-clés
  se lit dans la ROM elle-même. Un tokeniseur sur le PC d'abord, puis dans GRXASM.
- Intérêt : montrer aux habitués du BASIC ce que CP/A apporte ; la vitesse reste celle du
  BASIC hors des `!`. Le niveau 3 est plus rapide et plus simple à obtenir.

## 7. Questions ouvertes

- Nom et syntaxe des commandes du niveau 2 (`!PASTE ...` ou `!P ...`, un seul module ou
  plusieurs selon la place).
- Adresse du module sous BASIC (sous `HIMEM`, ou `$9800-$9FFF` quand le programme reste en
  mode texte).
- Ordre de travail après le niveau 1 : le niveau 3 (un jeu GRAPHER sur tout Atmos) ou le
  niveau 2 (des routines rapides pour le BASIC).
