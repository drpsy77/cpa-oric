# CP/A pour l'Oric sous BASIC — spécification de travail

But : que ce qui est fait sous CP/A serve aussi sur un Oric ordinaire, sans disquette CP/A :
des programmes en langage machine chargés par `CLOAD`, et, au bout du chemin, un jeu écrit en
GRAPHER qui tourne sur n'importe quel Atmos (cassette ou LOCI). Trois étages : la sortie
`.TAP` (faite), GRXASM vers un Oric seul (à faire), puis une boîte à outils pour le BASIC
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
  (chargeur compris, `$0501-$05xx`), une longueur nulle ou plus grande que le fichier.
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

**Décidé, pas encore fait** : **`CASSETTE.COM`** écrit un `.TAP` sur le port cassette (vrai
magnétophone) et lit une cassette vers un fichier `.TAP`, pour l'Oric sans LOCI. Un `.COM`,
rien dans le système de la version disquette ; dans la version ROM, ce sera une fonction du
système (`docs/projet-rom.md`).

## 3. GRXASM pour un Oric seul (décidé, pas encore fait)

`GRXASM JEU /O` traduit un programme GRAPHER en un programme autonome, mis dans `JEU.TAP`
(démarrage automatique), qui prend toute la machine : ni CP/A, ni BASIC pendant le jeu.

- **Même code qu'aujourd'hui** : un programme traduit fait déjà ses dessins lui-même
  (`HIRES.INC`, `ARR.INC`, `SPR.INC`, `ANIM.INC` écrivent en mémoire ; GRXASM n'en recopie que
  les routines utiles). Seul change le socle : `ORIC.INC` au lieu de `CPA.INC` (§ 4).
- **Pas d'appel à la ROM** : les routines du socle sont celles de CP/A, recopiées (le matériel
  est le même : VIA, AY, ULA). La ROM n'offre pas l'état de la matrice du clavier dont les jeux
  ont besoin, ses adresses diffèrent entre 1.0 et 1.1, elle occupe la page zéro de nos
  routines. Sans elle, un seul comportement à essayer, et le `.TAP` vaut aussi pour un Oric-1.
- **Mémoire** : chargé en `$0500` comme un `.COM`, mais le point d'entrée du démarrage
  automatique ne peut pas être en `$0500-$0502` (§ 1) : `$0503` au plus tôt (les trois
  premiers octets du programme ne servent pas, ou le bloc commence en `$0503`). Au départ, le programme prend la page zéro
  et la pile, détourne l'IRQ par `$0244` ; il a `$0500-$B3FF` (environ 44 Ko).
- **Fin** : `END` et le bouton RESET (NMI par `$0247`) redémarrent la ROM (`JMP ($FFFC)`) ;
  pas de retour au BASIC (il faudrait lui rendre page zéro, page 2 et vecteurs).
- **Fichiers** : `LOAD` / `BLOAD` d'un nom constant deviennent des données mises dans le
  `.TAP` au moment de la traduction ; `SAVE` et les noms calculés sont refusés à la traduction.
- **Modes** : LORES et HIRES d'abord ; SPLIT (console sous l'image) refusé à la traduction
  dans une première version, ajouté ensuite.
- Exemples à livrer : `CARTE.GRX`, `SERPENT.GRX`, `DEFILE.GRX` en `.TAP` (et leurs jumeaux
  anglais).

## 4. Le socle `ORIC.INC`

Remplace `CPA.INC` pour `GRXASM /O`. Il fournit ce que les bibliothèques demandent
aujourd'hui au système (relevé dans `GRX.INC`, `HIRES.INC`, `ARR.INC`, `ANIM.INC`) :

| Service de CP/A | Utilisé par | Dans `ORIC.INC` | Taille estimée |
|---|---|---|---:|
| Changement de mode (fonction 115 op 10-11 : texte, SPLIT, police remise) | `h_gfx`, `grx.inc` | `g_mode` et la partie utile de `font_init` | ~300 |
| Compteur 50 Hz `SYS_TICKS`, touche tenue `KB_HELD`, `CONST`, `CONIN` | `grx.inc`, `anim.inc`, `h_key` | interruption du VIA, `kb_scan` et ses tables | ~700 |
| Son (fonction 116) : GRAPHER n'a pas de commande de son ; seul le bip d'un `INPUT` refusé (`rz_bip`) | `arr.inc` | bip par écriture directe dans l'AY | ~40 |
| `PRINT` hors LORES (`CONOUT`), `INPUT` (fonction 10) | `grx.inc`, `arr.inc` | mini-console : caractère, retour, défilement ; saisie simple | ~500 |
| Fichiers (`FIL.INC`, `BLOAD`, `GSAVE` / `GLOAD`) | selon le programme | rien : données dans le `.TAP` | — |

Total ~1,5 à 2 Ko, à prévoir à 2,5 Ko. `ORIC.INC` est marqué `;@` comme les autres
bibliothèques : un jeu sans `INPUT` ni `PRINT` dans la console en embarque moins. Si GRAPHER
reçoit un jour des commandes de son, `snd.s` (~600 octets) rejoindra le socle.

| Bibliothèque | Oric seul |
|---|---|
| `HIRES.INC` | oui, modes par `ORIC.INC` |
| `ARR.INC` | oui, saisie au clavier de `ORIC.INC` |
| `SPR.INC`, `ANIM.INC` | oui |
| `FIL.INC` | données incluses à la traduction |
| `GRX.INC` | oui, sur `ORIC.INC` |

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

- Données de `LOAD` / `BLOAD` dans le `.TAP` : recopiées dans le programme (`.byt` dans le
  `.ASM`, simple mais long à assembler pour une image), ou blocs à part. Blocs à part : le
  code est en `$0500`, là où se charge le chargeur BASIC de MKTAP. À essayer : le dernier
  `CLOAD""` du chargeur charge le code en `$0500` avec la marque de démarrage automatique,
  que la ROM lance tout de suite, avant de relire la ligne écrasée.
- Boîte à outils (§ 5) : nom et syntaxe des commandes (`!PASTE ...` ou `!P ...`), un seul
  module ou plusieurs selon la place ; adresse du module (sous `HIMEM`, ou `$9800-$9FFF`
  quand le programme reste en mode texte).
