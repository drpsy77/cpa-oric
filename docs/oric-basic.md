# CP/A pour l'Oric sous BASIC — spécification de travail

But : que ce qui est fait sous CP/A serve aussi sur un Oric ordinaire, sans disquette CP/A :
des programmes en langage machine chargés par `CLOAD`, et, au bout du chemin, un jeu écrit en
GRAPHER qui tourne sur n'importe quel Atmos (cassette ou LOCI). Trois étages : la sortie
`.TAP` (faite), GRXASM vers un Oric seul (fait), puis une boîte à outils pour le BASIC
(plus tard).

## 1. Ce qui est établi (Oricutron, ROM BASIC 1.1)

- **Format `.TAP`** (lu par `tape.c` d'Oricutron, essayé) : quelques octets `$16` (3 au moins ;
  MKTAP en met 4, comme `CSAVE`), `$24`, puis l'en-tête : `$00 $00`, type (`$80` code machine,
  `$00` programme BASIC), démarrage automatique (`$00` non ; `$80` ou `$C7` : le code est
  lancé, ou le programme BASIC exécuté, à la fin du chargement), adresse de **fin incluse**
  (octet fort, puis faible), adresse de début (fort, faible), `$00`, le nom (16 caractères au
  plus), `$00`, puis les octets. Plusieurs fichiers se suivent dans un même `.TAP` ; chaque
  `CLOAD""` charge le suivant.
- **Programme BASIC** : chargé en `$0501`, lignes tokenisées (lien vers la ligne suivante,
  numéro, mots-clés en un octet, `$00`), puis `$00 $00`. La ROM prend l'adresse de fin du bloc
  pour le **début des variables** : le bloc a donc un octet de plus que le programme (comme
  avec `CSAVE`) ; sinon le programme se charge et se liste, mais l'entrée d'une nouvelle ligne
  bloque le BASIC (essayé). Mots-clés de la ROM 1.1 (table de la ROM, à partir de `$80`) :
  `CLOAD` = `$B6`, `CALL` = `$BF`, `!` = `$C0`.
- **Chargement** : une routine en `$9000`, mise dans un `.TAP`, arrive intacte par `CLOAD""` ;
  `CALL #9000` l'exécute et le BASIC reprend (`Ready`). Un `CLOAD""` dans un programme BASIC
  charge un bloc de code machine et le programme continue (chargeur de MKTAP, essayé).
- **Démarrage automatique en `$0500`** : la ROM met `$00` en `$0500-$0502` (programme BASIC
  vide) avant de lancer le bloc ; le code y trouve un `BRK`. Sans démarrage automatique, le
  même bloc arrive intact (`CALL#500` ensuite). Essayé avec PUZZLE traduit (`JEU.GRX`).
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
  les fichiers. La ROM de l'Atmos, elle, est là. La page 2 et une grande partie de la page
  zéro appartiennent au BASIC.

## 2. Sortie `.TAP` : MKTAP (fait)

**`MKTAP.COM`** (sur l'Oric) et **`tools/mktap.py`** (sur le PC) font le même fichier :

    MKTAP JEU JEU.COM 8000 /R CARTE.DAT 9800 IMAGE.HIR A000

- Un bloc par fichier (8 au plus), à l'adresse donnée (hexadécimal), nommé d'après le fichier
  sans son type ; `,lg` après l'adresse donne la longueur. Sans elle, la taille du fichier
  moins les `^Z` de remplissage de son dernier enregistrement (règle de STAT et d'EXPORT) ;
  elle peut aller jusqu'à la taille brute, pour des données qui finissent vraiment par `$1A`.
- `/R` après un fichier (une seule fois) : ce bloc est lancé après le chargement. Seul bloc :
  marque de démarrage automatique. Plusieurs blocs : un chargeur BASIC est mis en tête, nommé
  comme le `.TAP`, à démarrage automatique : `10 CLOAD"":...:CLOAD"":CALL#adr` (un `CLOAD""`
  par bloc) ; l'utilisateur ne tape qu'un `CLOAD""`. Sans `/R` : un `CLOAD""` par bloc.
- Refusé avant d'écrire : un bloc hors de `$0500-$BFFF`, deux blocs qui se chevauchent
  (chargeur compris, `$0501-$05xx`), une longueur nulle ou plus grande que le fichier, un
  bloc `/R` qui commence avant `$0503` (§ 1 : la ROM met `$00` en `$0500-$0502`).
- Le `.TAP` écrit par MKTAP.COM a son dernier enregistrement complété par des `^Z`, que
  `EXPORT` retire (un octet 0 est ajouté avant eux si le dernier octet utile vaut `$1A`).
  Transport : `EXPORT JEU.TAP`, cassette montée par le menu du LOCI, `CLOAD""` ; dans
  Oricutron : `-t JEU.TAP`.
- Un programme est d'abord assemblé à son adresse sous BASIC (`*= $8000`) : le `.COM` n'a pas
  d'en-tête. Le code lancé tourne sous la ROM (ni BDOS ni BIOS de CP/A).
- Pourquoi un programme à part plutôt qu'une option d'ASM : ASM est à quelques octets du bloc
  suivant ; MKTAP sert aussi aux images (`.HIR` en `$A000`), aux cartes, aux polices, aux
  écrans texte (`$BB80`), et à plusieurs fichiers dans une seule cassette.
- Mode d'emploi : `docs/manuel.md`, « Publier pour l'Oric sous BASIC ». Essais :
  `tools/test_mktap.sh` (MKTAP.COM contre `mktap.py` dans le 6502 simulé, puis chargement
  sous BASIC 1.1 dans Oricutron : chargeur, code, données, BASIC encore modifiable).

**Décidé, pas encore fait : programmes BASIC en texte.** MKTAP accepte un fichier `.BAS`
(programme BASIC écrit dans EDIT, avec ses numéros de ligne) et le code comme le ferait la ROM
(mots-clés en un octet, sauf entre guillemets, après `REM` et selon la règle de `DATA`) ; le
bloc va en `$0501`, avec l'octet de plus du § 1, et peut voisiner avec des blocs de langage
machine dans le même `.TAP`. Le codage imite celui de la ROM 1.1 (ordre de sa table des
mots-clés), pas celui de bas2tap. Essai : le même programme tapé dans Oricutron sous BASIC,
mémoire comparée octet par octet ; `tools/mktap.py` fait de même sur le PC. Taille estimée :
~2 Ko de plus (table des mots-clés ~500 octets). À décider : les minuscules (la ROM ne
reconnaît les mots-clés qu'en majuscules), les lignes plus longues que l'éditeur de l'Oric
(~78 caractères). Plus tard, le sens inverse (`.TAP` vers texte) pour reprendre de vieux
programmes dans EDIT.

**Décidé, pas encore fait** : **`CASSETTE.COM`** écrit un `.TAP` sur le port cassette (vrai
magnétophone) et lit une cassette vers un fichier `.TAP`, pour l'Oric sans LOCI. Un `.COM`,
rien dans le système de la version disquette ; dans la version ROM, ce sera une fonction du
système (`docs/projet-rom.md`).

## 3. GRXASM pour un Oric seul (fait)

`GRXASM JEU /O` traduit un programme GRAPHER en `JEU.TAP` (démarrage automatique), qui prend
toute la machine : ni CP/A, ni BASIC, ni ROM pendant le jeu. Mode d'emploi :
`docs/grapher.md` § 12.1 ; mise en œuvre : § 15 (« Oric seul »). En bref :

- **Même code** que les programmes traduits pour CP/A, mêmes bibliothèques ; seul le socle
  change : `ORIC.INC` au lieu de `CPA.INC` (§ 4).
- **Une commande** : GRXASM enchaîne `ASM JEU /E /T`. `JEU.ASM` porte l'en-tête du `.TAP` en
  `.byt`, juste avant `$0503` ; `/T` d'ASM nomme seulement le fichier écrit (`JEU.TAP`).
  Pas de `.COM` intermédiaire, qui planterait sous CP/A (il serait chargé en `$0500`).
- **Pas d'appel à la ROM** : les vecteurs IRQ et NMI sont pris là où la ROM les envoie (lus
  en `$FFFE` et `$FFFA` : `$0244` / `$0247` sur l'Atmos, `$0228` / `$022B` sur l'Oric-1) ;
  le même `.TAP` vaut pour les deux machines (Oric-1 : à essayer).
- **Mémoire** : bloc chargé en `$0503` (`$0500-$0502` mis à `$00` par la ROM) ; tableaux sous
  `$9D60`, comme sous CP/A.
- **Fin** : `END` et RESET redémarrent la ROM (`JMP ($FFFC)`) ; une touche d'abord si la
  console a du texte (un message d'erreur reste lisible). Pas de retour au BASIC.
- **Fichiers** : les fichiers lus par `LOAD`, `BLOAD`, `GLOAD` et `ANIM` (noms toujours
  constants en GRAPHER) sont recopiés dans le programme (`.byt`, table `O_FILES`) pendant la
  traduction. Choix : un seul bloc dans le `.TAP`, pas de chargeur BASIC en `$0501` (qui
  chevaucherait le programme), et `BLOAD` garde son sens (relu à volonté). Prix : un
  fichier occupe sa place deux fois, et `NOM.ASM` grossit d'environ 4,4 octets par octet
  de données. `SAVE`, `BSAVE`, `GSAVE` sont refusés à la traduction.
- **Modes** : texte (console), LORES et HIRES. SPLIT est refusé à la traduction.
- **Contrôles des bibliothèques** : les fragments « interprété seulement » d'`ARR.INC`
  (`;[` ... `;]`) sont retirés des copies que GRXASM recopie, pour tous les programmes
  traduits (jusqu'à 4 % plus petits) ; les tailles constantes d'un `DIM` sont vérifiées à
  la traduction (`valeur hors limites`, `memoire pleine`, avec le numéro de ligne) ; un
  `DIM` de taille calculée garde son contrôle `memoire pleine` à l'exécution, affiché par la
  console d'`ORIC.INC`.
- **Exemples** : `CARTE`, `SERPENT`, `DEFILE` et leurs jumeaux anglais (`MAP`, `SNAKE`,
  `ROAD`) dans `build/tap/`, essayés sous BASIC 1.1 dans Oricutron (`tools/test_oric.sh`).

**Décidé, pas encore fait** : le mode SPLIT (console sous l'image, dans `ORIC.INC`) ; le son,
si GRAPHER reçoit des commandes de son (`snd.s`, ~600 octets, rejoindrait le socle :
aujourd'hui un bip seulement).

## 4. Le socle `ORIC.INC`

`progs/oric.inc`, sur les disquettes avec GRXASM (`ORIC.INC`). Il fournit ce que les
bibliothèques demandent au système, sous les noms de `CPA.INC` :

| Service de CP/A | Utilisé par | Dans `ORIC.INC` | Taille |
|---|---|---|---:|
| Prise de la machine, interruption 50 Hz `SYS_TICKS`, fin, RESET | tous | `o_init`, `o_irq`, `o_end`, `o_nmi` | ~250 |
| Touche tenue `KB_HELD`, `CONST`, `CONIN` | `grx.inc`, `anim.inc`, `h_key` | `o_kscan` (`kb_scan` de CP/A sans les menus) et ses tables | ~480 |
| Fonction 2 (console), fonction 115 op 10-11 (mode texte, police remise) | `grx.inc`, `arr.inc`, `hires.inc` | `BDOS`, `o_con`, `o_gfx`, `o_text` | ~350 |
| Fonction 10 (`INPUT` dans la console) | `arr.inc` | `o_rdl` | ~120 |
| Fonctions 15, 20 (fichiers lus) | `fil.inc`, `hires.inc`, `anim.inc` | `o_open`, `o_read`, table `O_FILES` écrite par GRXASM | ~110 |
| Fonction 116 (son) : seul le bip d'un `INPUT` refusé (`rz_bip`) | `arr.inc` | `o_snd` | ~40 |

Mesuré : 1,2 Ko dans `SERPENT` et `DEFILE`, 1,3 Ko dans `CARTE` (fichiers lus). Seules les
routines utiles sont recopiées (`tools/mark_inc.py`, annotations `;>` et `;&`) : un jeu sans
`INPUT` dans la console n'emporte pas `o_rdl`.

## 5. Plus tard : boîte à outils pour le BASIC

À faire après `GRXASM /O`, qui aura déjà le socle `ORIC.INC` et le tri des routines. Un module
en code machine (`OUTILS.TAP`, par exemple), chargé en haut de la mémoire sous `HIMEM`, donne
au BASIC les opérations rapides de GRAPHER par la commande `!` :

    10 HIMEM #8BFF : CLOAD"OUTILS"
    20 !PASTE #4000,128, CX,CY, 2,1, 38,26
    30 !SCROLH -1, 2,1,39,26

- **Commandes candidates** : `PASTE` / `GRAB` (rectangle d'une carte en mémoire vers l'écran,
  et l'inverse : la carte est une zone d'octets chargée par `CLOAD`, avec sa largeur),
  `SCROLH` / `SCROLV` / `ROTH` / `ROTV`, `PRINTV` (texte vertical), `UNZ` (image `.HIZ`),
  `ANIM` (animation `.ANI`), plus tard les sprites en mode texte et les tuiles. Le BASIC a
  déjà `DRAW`, `CIRCLE`, `FILL` : pas de doublon.
- **Paramètres** : `!` suivi d'un mot et d'expressions BASIC séparées par des virgules, lues
  par les routines de la ROM (caractère suivant, évaluation d'une expression, conversion en
  entier) ; leurs adresses sont à relever dans la ROM 1.1 (et 1.0 : elles diffèrent) et à
  essayer dans Oricutron. Repli sans la ROM : paramètres posés par `DOKE` dans un bloc, puis
  `!` ou `CALL`.
- **Page zéro** : partagée avec le BASIC ; le module sauve les octets qu'il utilise en entrant
  et les rend en sortant (quelques centaines de cycles, peu devant un `PASTE` plein écran).
- **Source** : les mêmes routines que `ARR.INC`, `SPR.INC`, `HIRES.INC`, `ANIM.INC`, sur le
  socle `ORIC.INC` dans une variante « sous BASIC » (modes par `HIRES` et `TEXT` du BASIC,
  compteur de trames, pas de clavier ni de fichiers).

## 6. Écarté

- **GRAPHER traduit en BASIC** : tokeniseur, décimaux du BASIC au lieu des entiers de
  GRAPHER, pas de blocs `IF` ; et la vitesse, raison d'être de GRAPHER traduit, serait perdue.

## 7. Questions ouvertes

- Boîte à outils (§ 5) : nom et syntaxe des commandes (`!PASTE ...` ou `!P ...`), un seul
  module ou plusieurs selon la place ; adresse du module (sous `HIMEM`, ou `$9800-$9FFF`
  quand le programme reste en mode texte).
