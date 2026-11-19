# CP/A pour l'Oric sous BASIC — spécification de travail

But : que ce qui est fait sous CP/A serve aussi sur un Oric ordinaire, sans disquette CP/A :
des programmes en langage machine chargés par `CLOAD`, et, au bout du chemin, un jeu écrit en
GRAPHER qui tourne sur n'importe quel Atmos (cassette ou LOCI). Dans l'autre sens, que les
vieux programmes de l'Oric, presque tous conservés en `.TAP`, se reprennent sous CP/A. Quatre
étages : la sortie `.TAP` (faite), GRXASM vers un Oric seul (fait), la lecture des `.TAP`
sous CP/A (décidée), puis une boîte à outils pour le BASIC (plus tard).

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

**Programmes BASIC en texte (fait)** : MKTAP accepte un fichier `.BAS` (programme BASIC écrit
dans EDIT, avec ses numéros de ligne), un seul, sans adresse ; il le code comme la ROM 1.1
quand on tape les lignes et en fait un bloc BASIC (type `$00`) en `$0501`, avec l'octet de plus
du § 1 ; `/R` le lance (`RUN`) à la fin du chargement. Il peut voisiner avec des blocs de
langage machine dans le même `.TAP` (le programme les charge par `CLOAD""`) ; `/R` ne va alors
que sur lui, le chargeur des autres blocs prenant `$0501` aussi. Mode d'emploi :
`docs/manuel.md`, « Un programme BASIC écrit dans EDIT ».

- **Codage** : celui de `TokeniseLine` (`$C5FA`), suivi pas à pas : espaces gardés ; texte
  recopié entre guillemets, après `REM` et dans un `DATA` jusqu'au `:` ; `?` = `PRINT` ;
  chiffres, `:` et `;` recopiés ; ailleurs, le premier mot-clé de la table de la ROM (ordre de
  `$C0EA`, pas celui de bas2tap) qui commence là, même au milieu d'un nom (`SCORE` : `SC OR
  E`), sinon le caractère. Le numéro est lu comme `Txt2Int` (`$CAE2`) : espaces admis entre les
  chiffres, refus dès 6400 avant un chiffre de plus (63999 au plus).
- **Choix** : les minuscules passent en majuscules hors du texte (entre guillemets, après
  `REM`, dans un `DATA`, elles restent) ; une ligne de plus de 78 caractères (l'éditeur de
  l'Oric s'arrête là, `GetLine` `$C592`) est acceptée avec un avertissement ; une ligne codée
  sur plus de 250 octets est refusée (`LIST` parcourt une ligne avec un index d'un octet) ;
  numéros strictement croissants (pas de tri ni de remplacement comme à la saisie) ; lignes
  vides et lignes réduites à un numéro ignorées ; caractères de contrôle retirés (le clavier
  n'en met pas dans une ligne) ; code 128 ou plus hors du texte refusé (la ROM couperait la
  ligne) ; fin du programme en `$97FF` au plus.
- **Cible** : la ROM 1.1 (Atmos). La table de la ROM 1.0 (Oric-1, même adresse) ne diffère
  qu'en deux rangs (`$82`-`$83` : `INVERSE`, `NORMAL` au lieu de `STORE`, `RECALL`) et un
  mot-clé de plus à la fin (`GO`, `$F7`) : un programme sans ces quatre mots, ni `GO` hors de
  `GOTO` et `GOSUB` (un nom comme `GOLD` compris), est codé de même pour un Oric-1
  (comparaison des deux tables ; pas essayé).
- **Essais** : `tools/test_bas.py` fait tourner la ROM elle-même dans le 6502 simulé (sa saisie
  depuis `$C4C1` : `CHRGET`, `Txt2Int`, `TokeniseLine`) et compare son codage à celui de
  `tools/mktap.py`, sur des lignes écrites à la main et 3 000 tirées au hasard, et vérifie que
  la table de `progs/bas_tab.s` est celle de la ROM ; `tools/test_mktap.sh` compare MKTAP.COM
  à `mktap.py`, puis charge un `.BAS` dans Oricutron : programme lancé, octets et début des
  variables identiques à ceux du même programme tapé au clavier.
- Le sens inverse (`.TAP` vers texte) : § 5.

**Lancer un `.TAP`** : `USBMOUNT JEU.TAP /B` (`docs/usb.md` § 1.4) monte la cassette et
redémarre le LOCI en BASIC 1.1, qui la charge tout seul ; le `.TAP` tourne sous la ROM, sans
CP/A. Le firmware du LOCI (`mia_api_boot`, `mia_task`) charge la ROM, y pose ses
modifications pour la cassette et le chargement automatique (`CLOAD""` en `$E738`, appelé
depuis `$ED83` en 1.1), remet la ROM à la place de la RAM overlay et saute par `($FFFC)`.
Le LOCI émulé de Phosphoric ne fait que changer de ROM (`op_mia_boot`) : CP/A reprend la
main, et `CLOAD""` reste à taper ; signalé à son auteur.

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

## 5. Lire un `.TAP` sous CP/A : UNTAP et DIS (décidé, pas encore fait)

La plupart des vieux programmes de l'Oric existent en `.TAP`. Les lancer passe par la ROM
(§ 2, « Lancer un `.TAP` ») ; les **lire** se fait sous CP/A, sans ROM ni LOCI : un programme
BASIC devient un texte qu'on lit et modifie dans EDIT, et que MKTAP recode ; du code machine
devient un source qu'ASM réassemble. Le `.TAP` est d'abord copié sur la disquette (`IMPORT
JEU.TAP`, ou CMDER) : un fichier de CP/A comme un autre. Deux `.COM`, rien dans le système.

### 5.1 UNTAP : les blocs d'un `.TAP`

    UNTAP JEU                 liste les blocs
    UNTAP JEU 2               extrait le bloc 2
    UNTAP JEU *               extrait tous les blocs
    UNTAP JEU 2 /D            extrait le bloc 2 et le désassemble (DIS, par CHAIN)

    A>UNTAP JEU
    1 JEU        BASIC  0501-0A3F  auto
    2 -          code   9800-9F12
    3 ECRAN      code   BB80-BFDF

- **Lecture** (format du § 1) : après au moins un `$16`, un `$24`, l'en-tête de 9 octets, le
  nom jusqu'au `$00`, puis `fin - début + 1` octets. Ce qui n'est pas un bloc entre deux
  blocs est sauté ; la fin du fichier (les `^Z` de remplissage d'un fichier importé, ou
  n'importe quoi après le dernier bloc) aussi. Un bloc coupé par la fin du fichier est
  extrait avec ce qu'il a, et signalé (`bloc 2 incomplet`).
- **Blocs sans nom** : fréquents (`CSAVE""`, et `CLOAD""` charge le bloc suivant quel que
  soit son nom) ; la liste les montre par `-`.
- **Noms des fichiers écrits** : le nom du bloc (16 caractères quelconques), ses lettres et
  chiffres seulement, 8 au plus, en majuscules. Nom vide (bloc sans nom, ou sans lettre ni
  chiffre), ou déjà pris par un bloc précédent du même `.TAP` : le nom du `.TAP` suivi du
  numéro du bloc, le nom raccourci pour tenir en 8 (`JEU2`, `AVENTUR2`, `AVENTU12`). Un
  fichier qui existe déjà est remplacé après la question habituelle (`O` / `N` / `T` pour
  tous).
- **Bloc BASIC** (type `$00`) → `NOM.BAS`, en texte, comme `LIST` l'afficherait : numéro,
  espace, la ligne avec chaque mot-clé écrit en entier (table de `progs/bas_tab.s`, celle de
  MKTAP), lignes terminées par CR LF. Ce qui suit la fin du programme (`$00 $00`) dans le
  bloc, souvent du code machine collé au programme, devient `NOM.BIN`, à son adresse
  (listée).
- **Aller-retour** : `MKTAP JEU2 NOM.BAS` redonne le même bloc, octet par octet, pour tout
  programme que la ROM a pu coder elle-même (tapé au clavier) ; c'est la propriété vérifiée
  par les essais. Exceptions connues, signalées par UNTAP ligne par ligne : caractères de
  contrôle et codes de 128 et plus dans le texte (couleurs glissées dans une chaîne, très
  courant), qu'il faut écrire dans le `.BAS` dans une notation que MKTAP comprenne aussi
  (§ 8).
- **Bloc de code** (type `$80`) → `NOM.BIN` : les octets tels quels ; adresse de début,
  de fin, et démarrage automatique dans la liste. `/D` passe ce fichier à DIS avec son
  adresse et son point d'entrée.
- **Oric-1** : un programme BASIC de la ROM 1.0 n'a que deux codes différents (`$82`, `$83`)
  et un de plus (`GO`, `$F7`) ; `/1` lit le bloc avec la table de la 1.0.

### 5.2 DIS : du code machine vers un source

    DIS NOM.BIN 9800          désassemble, point d'entrée au début
    DIS NOM.BIN 9800 /E 9A10  points d'entrée en plus (8 au plus)
    DIS PROG.COM              un .COM de CP/A (en $0500 par défaut)

DIS écrit `NOM.ASM`, un source qu'**ASM réassemble en un fichier identique** à celui de
départ : c'est sa règle, et ce que les essais vérifient. Il sert aux `.TAP` comme à tout
fichier de code (`.COM` de CP/A, image de la ROM, police).

- **Code ou données** : en partant des points d'entrée (le début, le démarrage automatique,
  ceux de `/E`), DIS suit les sauts, les appels et les deux suites de chaque branchement ;
  ce qu'il atteint est du code, le reste des données, écrites en `.byt` (en `.asc` pour une
  suite d'au moins 4 caractères imprimables). Une instruction coupée par une donnée, un
  code d'opération non documenté : `.byt`. Le reste se corrige à la main dans EDIT (tables
  de sauts, `RTS` utilisé comme saut, code modifié par lui-même), puis se réassemble.
- **Étiquettes** : `Lxxxx` sur chaque cible d'un saut, d'un branchement ou d'une adresse
  absolue qui tombe dans le fichier ; `*=` à l'adresse de chargement. Hors du fichier, les
  adresses connues sont nommées par une table de symboles : celle de la ROM 1.1 (points
  d'entrée, page zéro et page 2 du BASIC, registres du VIA), livrée sur la disquette dans le
  format `.SYM` d'ASM (`ATMOS.SYM`), ce qui la rend utile aussi à DEBUG ; les noms qu'elle
  donne sont déclarés en tête du source (`nom = $xxxx`), pour qu'il s'assemble seul.
- **Taille** : un bit par octet du fichier pour « code » et un pour « étiquette » : 12 Ko
  pour un bloc de 48 Ko ; le source s'écrit au fil de la seconde passe, sans le garder en
  mémoire. Tables d'instructions : `progs/asm_tab.s`, celles d'ASM et de DEBUG.

### 5.3 Vers un `.COM` : au cas par cas

Faire tourner un vieux programme sous CP/A n'est pas un but de UNTAP ni de DIS : il attend la
ROM (cachée par la RAM overlay), utilise la page 2 et la page zéro du BASIC (en partie celles
de CP/A) et se charge rarement en `$0500`. Le source de DIS est le chemin : on y remplace les
appels à la ROM par ceux du BDOS, on change `*=`, on réassemble. Un programme en code pur qui
n'appelle pas la ROM (un jeu qui prend toute la machine) passe presque tel quel ; les autres
demandent ce travail à la main. Une couche qui imiterait la ROM sous CP/A n'est pas prévue.

### 5.4 Essais prévus

- UNTAP dans le 6502 simulé (`tools/run_com.py`), contre un `tools/untap.py` qui fait la même
  chose sur le PC : blocs, noms, cas tordus (synchronisation longue, rebut entre les blocs,
  bloc coupé, `^Z` de fin).
- Aller-retour BASIC : les 3 000 lignes tirées au hasard de `tools/test_bas.py`, codées par la
  ROM, rendues en texte par UNTAP, recodées par MKTAP : mêmes octets ; puis des `.TAP` de
  programmes connus.
- DIS → ASM → mêmes octets, sur tous les `.COM` de CP/A et sur la ROM 1.1 entière.

## 6. Plus tard : boîte à outils pour le BASIC

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

## 7. Écarté

- **GRAPHER traduit en BASIC** : tokeniseur, décimaux du BASIC au lieu des entiers de
  GRAPHER, pas de blocs `IF` ; et la vitesse, raison d'être de GRAPHER traduit, serait perdue.

## 8. Questions ouvertes

- UNTAP (§ 5.1) : notation, dans un `.BAS`, des caractères de contrôle et des codes de 128 et
  plus d'une chaîne ou d'un `REM` (proposé : `{nn}` en hexadécimal, `{{` pour une accolade),
  comprise par MKTAP et `mktap.py`.
- DIS (§ 5.2) : contenu de `ATMOS.SYM` (combien de noms de la ROM : quelques dizaines de
  points d'entrée utiles, ou tous) ; DIS et UNTAP en un seul programme si DIS reste petit.
- Boîte à outils (§ 6) : nom et syntaxe des commandes (`!PASTE ...` ou `!P ...`), un seul
  module ou plusieurs selon la place ; adresse du module (sous `HIMEM`, ou `$9800-$9FFF`
  quand le programme reste en mode texte).
