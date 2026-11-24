# CP/A pour l'Oric sous BASIC — spécification de travail

But : que ce qui est fait sous CP/A serve aussi sur un Oric ordinaire, sans disquette CP/A :
des programmes en langage machine chargés par `CLOAD`, et, au bout du chemin, un jeu écrit en
GRAPHER qui tourne sur n'importe quel Atmos (cassette ou LOCI). Dans l'autre sens, que les
vieux programmes de l'Oric, presque tous conservés en `.TAP`, se reprennent sous CP/A. Quatre
étages : la sortie `.TAP` (faite), GRXASM vers un Oric seul (fait), la lecture des `.TAP`
sous CP/A (UNTAP et DIS faits), puis une boîte à outils pour le BASIC (plus tard).

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
- Le sens inverse (`.TAP` vers texte) : UNTAP, § 5.1, qui écrit `{hh}` pour un code qu'on ne
  tape pas ; MKTAP décode cette notation après le numéro de la ligne.

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

## 5. Lire un `.TAP` sous CP/A : UNTAP et DIS (faits)

La plupart des vieux programmes de l'Oric existent en `.TAP`. Les lancer passe par la ROM
(§ 2, « Lancer un `.TAP` ») ; les **lire** se fait sous CP/A, sans ROM ni LOCI : un programme
BASIC devient un texte qu'on lit et modifie dans EDIT, et que MKTAP recode ; du code machine
devient un source qu'ASM réassemble. Le `.TAP` est d'abord copié sur la disquette (`IMPORT
JEU.TAP`, ou CMDER) : un fichier de CP/A comme un autre. Deux `.COM`, rien dans le système.

### 5.1 UNTAP : les blocs d'un `.TAP` (fait)

`UNTAP.COM` (`progs/untap.s`) et `tools/untap.py` (sur le PC) donnent le même résultat. Mode
d'emploi : `docs/manuel.md`, « Lire une cassette : UNTAP ».

    UNTAP JEU                 liste les blocs
    UNTAP JEU 2               extrait le bloc 2
    UNTAP JEU *               extrait tous les blocs
    UNTAP JEU 1 /1            programme BASIC de l'Oric-1

    A>UNTAP JEU
      1 JEU              BAS 0501-0A3F /R
      2 -                BIN 9800-9F12
      3 ECRAN            BIN BB80-BFDF

- **Lecture** (format du § 1) : après au moins un `$16`, un `$24`, l'en-tête de 9 octets, le
  nom jusqu'au `$00` (16 caractères gardés), puis `fin - début + 1` octets (aucun si la fin
  est avant le début). Ce qui n'est pas un bloc entre deux blocs est sauté ; la fin du
  fichier (les `^Z` de remplissage, ou n'importe quoi après le dernier bloc) aussi. Un bloc
  coupé par la fin du fichier est extrait avec ce qu'il a, et signalé (`bloc 2 incomplet`).
  255 blocs au plus.
- **Liste** : numéro, nom (`-` : bloc sans nom, fréquent, car `CLOAD""` charge le bloc
  suivant quel que soit son nom ; `?` pour un caractère qui ne s'affiche pas), `BAS` (type
  `$00`) ou `BIN` (tout autre type), début et fin, `/R` (démarrage automatique). 37 colonnes.
- **Noms des fichiers écrits** : les lettres et chiffres du nom du bloc, 8 au plus, en
  majuscules. Nom vide (bloc sans nom, ou sans lettre ni chiffre), ou déjà pris par un bloc
  précédent du même `.TAP` (48 noms retenus) : le nom du `.TAP` suivi du numéro du bloc, le
  nom raccourci pour tenir en 8 (`JEU2`, `AVENTUR2`, `AVENTU12`). Les noms sont calculés pour
  tous les blocs, même quand un seul est extrait : `UNTAP JEU 4` et `UNTAP JEU *` donnent le
  même nom au bloc 4. Un fichier qui existe est remplacé, comme par COPY et MKTAP ; les
  fichiers vont sur le lecteur du `.TAP`.
- **Bloc BASIC** → `NOM.BAS`, en texte, comme `LIST` l'afficherait : numéro, espace, la ligne
  avec chaque mot-clé écrit en entier (table de `progs/bas_tab.s`, celle de MKTAP), CR LF.
  Le découpage suit celui du codage : texte entre guillemets (jusqu'au guillemet suivant ou
  la fin de la ligne), `DATA` jusqu'au `:`, `REM` jusqu'au bout recopiés tels quels ;
  ailleurs, un code de `$80` et plus est un mot-clé. Fin du programme : un lien dont l'octet
  fort est nul (comme `LIST`). Ce qui suit dans le bloc, s'il y a plus d'un octet (le
  programme en a un de plus, § 1), souvent du code collé au programme, devient `NOM.BIN`, à
  son adresse (affichée).
- **Notation** `{hh}` (hexadécimal, en majuscules) pour ce que MKTAP ne relirait pas tel
  quel : codes 0 à 31 et 127 et plus (couleurs glissées dans une chaîne, très courant), un
  espace ou un chiffre en tête du texte (MKTAP les prendrait pour le numéro), un espace en
  fin (un éditeur peut les retirer) ; `{{` pour une accolade. MKTAP et `mktap.py` la
  décodent après le numéro (`{00}` et toute autre accolade restent tels quels), avant la
  limite de 78 caractères (§ 2).
- **Vérification, aller-retour** : chaque ligne rendue en texte est recodée par la routine de
  MKTAP (`progs/bcr_inc.s`, partagée) et comparée à l'originale ; une différence donne
  `ligne N : recodage different` (minuscules hors texte, que MKTAP met en majuscules ;
  ligne fabriquée par un autre outil que la ROM ; code inconnu, `$F7` et plus ; ligne vide,
  que MKTAP ignore ; ligne de plus de 255 caractères en texte). Sans avertissement, pour un
  programme en `$0501` aux numéros croissants (tout ce qu'a écrit `CSAVE`), `MKTAP JEU2
  NOM.BAS` redonne le même programme, octet par octet, liens compris.
- **Bloc de code** → `NOM.BIN` : les octets tels quels ; son adresse est dans la liste et dans
  le message (`ECRAN.BIN BB80-BFDF ecrit`).
- **Oric-1** : `/1` lit les codes `$82` (`INVERSE`), `$83` (`NORMAL`) et `$F7` (`GO`) de la
  ROM 1.0 ; MKTAP codant pour la 1.1, ces lignes sont signalées.
- **Taille** : 3,3 Ko. Lecture et écriture par enregistrements de 128 octets, une ligne à la
  fois : la taille du `.TAP` n'est pas limitée.
- **Essais** : `tools/test_untap.py` (UNTAP.COM dans le 6502 simulé contre `untap.py` : noms
  vides, en double, longs, en minuscules ; synchronisation longue, rebut, bloc coupé, fin
  avant le début ; queue de code, codes inconnus, minuscules, ligne vide, espace en tête,
  ROM 1.0 ; douze blocs ; puis l'aller-retour de programmes tirés au hasard, octets de
  contrôle et de 128 et plus compris, recodés par `mktap.py`) ; `tools/test_mktap.sh`
  compare MKTAP.COM à `mktap.py` sur la notation.

### 5.2 DIS : du code machine vers un source (fait)

`DIS.COM` (`progs/dis.s`, 5 126 octets). Mode d'emploi : `docs/manuel.md`, « Le désassembleur DIS ».

    DIS NOM.BIN 9800          désassemble, point d'entrée au début
    DIS NOM.BIN 9800 /E 9A10  points d'entrée en plus (8 au plus)
    DIS PROG.COM              un .COM de CP/A (en $0500 par défaut)

DIS écrit `NOM.ASM`, un source qu'**ASM réassemble en un fichier identique** à celui de
départ (fin du dernier enregistrement comprise) : c'est sa règle, et ce que les essais
vérifient. Il sert aux `.TAP` comme à tout fichier de code (`.COM` de CP/A, image de la ROM).

- **Code ou données** : en partant des points d'entrée (le début, ceux de `/E`, les vecteurs
  `$FFFA-$FFFF` quand le fichier les contient), DIS suit les instructions, les sauts, les
  appels et les deux suites de chaque branchement ; `JMP (adr)`, `RTS`, `RTI`, `BRK`, un code
  non documenté ou la fin du fichier arrêtent la suite. Ce qu'il atteint est du code, le
  reste des données : `.asc` pour au moins 4 caractères imprimables (sans `"` ; 20 par ligne,
  la suite d'une chaîne pleine reste en `.asc`), `.dsb n,$hh` pour au moins 8 octets égaux,
  `.byt` sinon (6 par ligne). Le démarrage automatique d'un `.TAP` est le début du bloc :
  pas d'option à part.
- **Écrit en `.byt`**, l'instruction en commentaire : une instruction dans laquelle commence
  une autre (code qui se chevauche, `BIT` qui saute un octet) ; une instruction absolue dont
  l'adresse tient sur un octet quand la forme page zéro existe (ASM, comme xa, choisirait la
  page zéro) ; un branchement dont la cible sort de `$0000-$FFFF`. Une instruction coupée par
  la fin du fichier, un code non documenté : données.
- **Étiquettes** `Lxxxx` (en colonne 1, l'instruction en colonne 9) : cibles des sauts, des
  branchements et des adresses absolues qui tombent dans le fichier, points d'entrée de `/E`
  et des vecteurs ; une adresse au milieu
  d'une instruction s'écrit `Lxxxx+1` ou `+2`, l'étiquette sur l'instruction (code modifié par
  lui-même). Jamais d'étiquette pour un opérande page zéro (une étiquette définie plus loin
  ferait choisir la forme absolue). `*=` à l'adresse de chargement.
- **Noms** : une adresse égale à un nom d'`ATMOS.SYM` prend ce nom : comme étiquette quand
  elle tombe dans le fichier (la ROM désassemblée : `StartBASIC cld`, `jsr SetScreen` ; un
  nom de 8 caractères ou plus est suivi d'une seule espace), sinon déclaré en tête du source
  (`PrintChar = $F5C1`), pour qu'il s'assemble seul. Pas de nom pour un opérande page zéro
  qui tombe dans le fichier (chargé en page zéro). `ATMOS.SYM`
  (`tools/atmos_sym.txt`, au format `.SYM` d'ASM par `tools/mksym.py`, 2,6 Ko) : les 16
  registres du VIA et 220 points d'entrée de la ROM 1.1, noms du fichier `basic11b.sym`
  d'Oricutron (doublons retirés). Cherché sur le lecteur du fichier, puis en A: ; absent :
  adresses en hexadécimal (message). Pas lu pour un `.COM` (la ROM y est cachée : `$C006`
  serait `JumpTab` au lieu du BIOS).
- **Mémoire** : trois bits par octet du fichier (début d'instruction ; intérieur d'une
  instruction, qui sert aussi de liste « à suivre » pendant le suivi ; étiquette), soit
  3 Ko pour 8 Ko, 18 Ko pour 48 Ko ; puis un cache d'enregistrements de 128 octets lus par la
  lecture directe (fonction 33), en puissance de 2 (256 au plus) jusqu'au haut de la TPA. Le
  fichier n'a pas à tenir en mémoire (511 enregistrements au plus, sans dépasser `$FFFF`).
  Le source s'écrit au fil de la dernière passe ; il fait environ 6 fois le fichier (EDIT,
  8,7 Ko : 51 Ko ; la ROM, 16 Ko : 117 Ko).
- **Durée** (mesurée dans le 6502 simulé, en instructions) : EDIT 4,9 millions, la ROM
  14,7 millions, soit de l'ordre de 20 s et d'une minute sur l'Oric, écriture du disque en plus
  (à confirmer).
- **Passes** : suivi (balayages de la liste « à suivre » jusqu'à ce qu'elle soit vide),
  chevauchements, étiquettes et noms utilisés, écriture.
- **Tables** : celles d'ASM (`progs/asm_tab.s`) et de DEBUG (`progs/dis_inc.s` : modes,
  longueurs, table code → mnémonique), partagées ; mnémoniques écrits en minuscules.
- **Essais** : `tools/test_dis.py` (DIS.COM dans le 6502 simulé ; le source réassemblé par
  xa, et par ASM.COM pour quelques-uns, redonne le fichier) sur tous les `.COM` de CP/A, la
  ROM 1.1 entière (en `$C000`, vecteurs compris) et des cas fabriqués (absolu sur la page
  zéro, `BIT` qui saute un octet, `Lxxxx+1`, branchement hors du fichier et hors de
  `$0000-$FFFF`, codes non documentés, `/E`, guillemets et `;` dans le texte, fichier en
  `$0000`, instruction coupée par la fin).

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
- DIS → ASM → mêmes octets, sur tous les `.COM` de CP/A et sur la ROM 1.1 entière (fait :
  `tools/test_dis.py`).

### 5.5 Un jeu entier : l'essai de Mr Wimpy

Mr Wimpy (Ocean, 1984 ; `.TAP` de 31 Ko) a servi d'essai de UNTAP et de DIS sur un vrai jeu,
dans le 6502 simulé. Le `.TAP` n'est pas dans le dépôt.

    A>UNTAP WIMPY
      1 WIMPY.1          BAS 0501-054F /R
      2 WIMPY.2          BIN 9FFF-BF67 /R
      3 WIMPY.3          BIN 2DFF-87C3 /R
    A>UNTAP WIMPY *
    A>TYPE WIMPY1.BAS
    ...
    30 POKE #26C,7:HIRES:CLOAD"WIMPY.2":CLOAD"WIMPY.3"
    40 TEXT:CALL#2E00
    A>DIS WIMPY3.BIN 2DFF /E 2E00

- **Manière de faire** : l'adresse du bloc est celle que UNTAP affiche (`2DFF`) ; le point
  d'entrée est celui du `CALL` du chargeur BASIC (`/E 2E00`), qu'on lit dans `WIMPY1.BAS`.
  Les deux sont nécessaires :
  - sans l'adresse, DIS écrit `*= $0500` : les adresses absolues du programme tombent hors
    du fichier et ne reçoivent aucune étiquette ;
  - sans `/E`, tout reste en `.byt` : le bloc commence un octet avant le code, par un `RTS`
    (le démarrage automatique du bloc rend la main au BASIC, qui fait le `CALL`), et DIS,
    parti du début, s'arrête sur ce `RTS`.
- **Résultat** : 2 955 instructions suivies (6,2 Ko de code sur 22 981 octets), 591
  étiquettes, noms du VIA et de la ROM ; `WIMPY3.ASM` fait 154 Ko (6 760 lignes). Réassemblé
  par xa et par ASM.COM (601 symboles, 25,6 millions d'instructions, de l'ordre de deux
  minutes sur l'Oric) : fichier identique.
- **Ce qui manque** :
  - *Tables de sauts.* Le jeu saute par `JMP ($003D)` et `JMP ($378A)` : 4 tables
    d'adresses (`$3687`, `$369F`, `$36B9`, `$4936`) et un vecteur posé par deux `LDA #`
    (`$2FA5`), soit 18 points d'entrée de plus, quand `/E` en prend 8. Avec eux, le code
    atteint 7,1 Ko ; le reste est fait de textes, de tables et de 11,5 Ko de dessins
    (`$5A8C-$87C3`).
  - *Tables écrites en données.* Une table d'adresses sort en `.byt` ou en `.asc` (celle de
    `$4936` : `.byt $07`, `.asc "JSJyI"`). Le source se réassemble à l'identique, mais
    devient faux dès qu'une instruction est insérée avant les routines visées.
  - *Taille.* 154 Ko ne s'ouvrent pas dans EDIT ; les dessins en `.byt` (6 octets par
    ligne) en font la moitié.
  - *Ce qu'aucun désassembleur ne devine* : une adresse chargée en deux moitiés
    (`lda #$A5`, `lda #$2F`) se corrige à la main ; une valeur qui ressemble à une adresse
    du fichier n'en est pas toujours une (`$7D00` est ici une durée du compteur du VIA).
- **Conclusion** : DIS.COM convient à un bloc de quelques Ko (une routine, un chargeur, un
  module), lu dans EDIT. Désassembler un jeu entier sur l'Oric n'est pas réaliste : ce
  travail se fait sur le PC, et le `.TAP` modifié se refait par xa ou par `ASM /T`.
- **Sur le PC** : `tools/dis65.py` (§ 5.6) comble ces manques. Avec les 4 tables et le
  vecteur, qu'il propose lui-même, le code suivi passe de 6,2 à 7,1 Ko (3 402
  instructions) ; le source fait 73 Ko, les dessins 53 Ko dans un fichier à part.

### 5.6 DIS65 : un programme entier, sur le PC (fait)

`tools/dis65.py` désassemble un programme d'après un **fichier de description** qu'on
complète à mesure qu'on comprend le programme ; on relance, le source est refait. Rien ne
se corrige à la main dans le source : une correction est une ligne de la description. Le
source suit les règles de DIS (§ 5.2) et se contrôle de la même façon : réassemblé par xa
(`tools/xa`, ou `$XA`), il redonne le fichier.

    python3 tools/dis65.py wimpy.tap 3 2E00     écrit wimpy3.dis (bloc 3, entrée en 2E00),
                                                puis wimpy3.s
    python3 tools/dis65.py wimpy3.dis           refait wimpy3.s après une retouche
    python3 tools/dis65.py JEU3.BIN 2DFF 2E00   même chose depuis un .BIN d'UNTAP

`-n` : pas de contrôle par xa ; `-q` : pas de liste des candidats. Les fichiers sont écrits
à côté de la description, dont ils prennent le nom.

**La description** : une déclaration par ligne, adresses en hexadécimal, `;` ouvre un
commentaire.

    file  "Mr Wimpy.tap" 3       le bloc 3 d'un .TAP (adresse lue dans le bloc)
    file  WIMPY3.BIN 2DFF 87C3   ou un fichier, son adresse, sa dernière adresse (les ^Z
                                 de fin d'un .BIN d'UNTAP sont ainsi laissés)
    entry 2E00 Start             point d'entrée, avec ou sans nom
    table 3687 4                 4 adresses de routines : .word Lxxxx, routines suivies
    table2 5000 5010 8           octets bas en 5000, hauts en 5010 : .byt <Lxxxx, .byt >Lxxxx
    rtstable 3700 4              adresses diminuées de 1 (saut par RTS) : .word Lxxxx-1
    rtstable2 5000 5010 8
    pointers 36D1 12 Texts       adresses de données : .word Lxxxx, non suivies
    pointers2 3620 361D 3
    data  5A8C-87C3 gfx          données, jamais du code ; nommée : dans wimpy3_gfx.s
    text  5038-5045              texte : .asc
    name  378A GameVec           nom d'une adresse
    lo    2E00 2FA5              l'instruction en 2E00 charge l'octet bas de 2FA5
    hi    2E05 2FA5              celle en 2E05, l'octet haut
    rem   4936 quatre directions commentaire écrit devant cette adresse
    symbols FICHIER | none       noms connus

- **Points d'entrée** : sans limite. Sans aucun `entry`, le début du fichier ; dès qu'il y
  en a un, le début n'en est plus un (un bloc commence souvent par un octet de plus). Les
  vecteurs `$FFFA-$FFFF`, quand le fichier les contient, sont une table.
- **Tables d'adresses** : chaque entrée s'écrit avec l'étiquette de sa cible, qui reste
  juste quand le code bouge. `table` et `rtstable` font de leurs cibles des points
  d'entrée ; `pointers` non. Une entrée hors du fichier s'écrit en hexadécimal (signalée
  pour une table de routines).
- **Adresses chargées en deux moitiés** : `lo` et `hi` donnent `lda #<Game` et
  `lda #>Game` (toute instruction immédiate). Une déclaration qui ne correspond pas à
  l'octet du fichier est refusée avec un message, le source reste identique.
- **Zones** : `data` s'écrit en `.byt` de 16 octets par ligne (`.dsb` pour 8 octets égaux
  ou plus), sans recherche de texte ; avec un nom, dans un fichier à part que le source
  principal inclut (`#include`). `text` s'écrit en `.asc` dès le premier caractère. Le
  code suivi s'arrête devant une zone déclarée (message) : c'est la manière de traiter
  un `JSR` suivi de ses paramètres, la suite se donnant par `entry`. Hors de ces zones,
  les données s'écrivent comme dans DIS (`.byt` de 8 octets, `.asc` de 40 caractères).
- **Noms** : un nom (de `entry`, d'une table, de `text`, de `data`, de `name`) remplace
  `Lxxxx` ; l'adresse est alors rappelée en commentaire, pour retrouver l'endroit dans la
  description. Une adresse hors du fichier nommée par `name` est déclarée en tête
  (`Jump = $3D` : un opérande page zéro garde sa forme courte). `symbols` : fichier au
  format de `tools/atmos_sym.txt`, qui est pris par défaut (ROM 1.1 et VIA ; aucun pour
  un `.COM`).
- **Candidats** : après le source, dis65 propose des lignes à vérifier puis à copier dans
  la description :
  - `lda T,x` / `sta V` / `lda T+1,x` / `sta V+1` : une table de mots, ou deux tables
    d'octets quand les adresses lues ne se suivent pas ; `table` quand `V` sert à sauter
    (`JMP (V)`, opérande d'un `JMP` ou d'un `JSR` modifié, vecteur de la page 2),
    `pointers` sinon. Le nombre d'entrées s'arrête à la première qui ne vise plus le
    fichier, qui est du code, ou qu'une autre instruction lit ;
  - `lda T,x` / `pha` / `lda U,x` / `pha` : `rtstable` ;
  - `lda #` / `sta V` / `lda #` / `sta V+1` dont la valeur tombe dans le fichier :
    `lo`, `hi`, et `entry` quand `V` sert à sauter (jamais vers le VIA : `$7D00` rangé
    dans son compteur est une durée) ;
  - `lda #` / `ldy #` (ou `ldx #`) avant un `JSR` : `lo`, `hi` (pointeur passé à une
    routine).
  Une table déclarée fait suivre du code nouveau, qui peut donner d'autres candidats :
  on relance jusqu'à ce qu'il n'en reste plus d'utile.
- **Autres messages** : les suites arrêtées par un code non documenté (un point d'entrée
  faux, ou des données derrière un `JSR`).
- **Nom du fichier** : `dis65.py`, pas `dis.py`, qui cacherait le module `dis` de Python
  aux autres outils du dossier.
- **Essais** : `tools/test_dis65.py`. Fichiers entiers sans description (les `.COM` de
  CP/A, la ROM 1.1, les cas tordus de `test_dis.py`) : xa redonne le fichier. Un
  programme fabriqué qui réunit les cas ci-dessus : les candidats proposés, copiés dans
  la description, suffisent à ce que le source **décalé d'un octet** (une instruction
  insérée en tête) soit égal à l'original décalé de même, et le source sans description
  ne l'est pas. Tous les mots-clés, un bloc lu dans un `.TAP`, les erreurs de
  description.

**Pas fait** : dessins laissés dans un fichier binaire (ASM n'a pas de directive pour
l'inclure) ; tables dont les entrées ne sont pas des adresses seules (adresse suivie
d'un paramètre).

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

- DIS (§ 5.2) : noms de la page zéro et de la page 2 du BASIC dans `ATMOS.SYM` (il faut une
  source sûre) ; `ATMOS.SYM` lu aussi par DEBUG ; une table `CPA.SYM` (BDOS, page 2 de
  CP/A) pour les `.COM` ; `UNTAP JEU 2 /D`, qui passerait le bloc à DIS (par CHAIN).
- Boîte à outils (§ 6) : nom et syntaxe des commandes (`!PASTE ...` ou `!P ...`), un seul
  module ou plusieurs selon la place ; adresse du module (sous `HIMEM`, ou `$9800-$9FFF`
  quand le programme reste en mode texte).
