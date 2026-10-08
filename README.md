# CP/A — Control Program for Atmos

Mini système « à la CP/M » pour Oric Atmos. Version 0.9.

Il existe deux variantes construites à partir des mêmes sources :

- **`build/cpa.dsk`**, la version principale. C'est une disquette amorçable pour le contrôleur Microdisc,
  et donc aussi pour le Cumulus et le LOCI. L'EPROM du Microdisc la démarre, puis le système se charge
  dans les 16 Ko de RAM overlay (`$C000-$FFFF`) cachés sous la ROM BASIC. Il n'y a aucune EPROM à graver,
  et l'espace des programmes reste intact.
- **`build/cpa.rom`**, une ROM de 16 Ko qui remplace la ROM BASIC. Elle donne la console et le moniteur,
  sans disque.

## Documentation de travail

- `docs/architecture.md` : couches, contrat d'interface commun aux deux versions, carte mémoire,
  construction et tests, conventions ;
- `docs/projet-disquette.md` : la version disquette (état, choix, suite prévue) ;
- `docs/projet-rom.md` : la version ROM dédiée (but, état, à faire) ;
- `docs/atelier.md` : comment construire et tester comme Claude (Raspberry Pi, Windows) ;
- `docs/loci-modem-wifi.md` : relier un modem WiFi (Pico W) au LOCI.

## Construire

Il faut Python 3 et l'assembleur `xa` de l'OSDK. Le script `tools/build_xa.sh` le télécharge et
le compile dans `tools/xa` (macOS ou Linux, il faut git et un compilateur C++) :

    ./tools/build_xa.sh
    ./build.sh

`build.sh` prend `tools/xa` s'il existe ; sinon il utilise la variable `XA` ou le `xa` du PATH.

Sur Linux (Raspberry Pi compris), `tools/setup_linux.sh` installe en une fois tout l'atelier de
test : xa, py65 et un Oricutron piloté par script. Voir `docs/atelier.md`.

## Lancer dans Oricutron

Version disque : l'EPROM du Microdisc fait appel à la ROM BASIC 1.1, il faut donc garder
`atmosrom = 'roms/basic11b'` et avoir `roms/microdis.rom`.

    oricutron -m atmos -k microdisc -d build/cpa.dsk

Version ROM : copier `build/cpa.rom` dans `roms/`, puis mettre `atmosrom = 'roms/cpa'` dans `oricutron.cfg`.

Sur le matériel, copier `cpa.dsk` sur la clé USB ou la carte SD du LOCI (ou du Cumulus) et
démarrer dessus. CP/A a été essayé sur un vrai Oric Atmos avec un LOCI : démarrage, menus,
EDIT, PUT, DIR, SPLIT, GTEST et LOGO fonctionnent (ASM et DEBUG restent à essayer). Les
couleurs des menus, peu lisibles dans certains émulateurs, sont nettes sur un vrai écran.

**Plusieurs lecteurs.** La version disquette gère quatre lecteurs, `A:` à `D:`, comme le
contrôleur Microdisc, le LOCI et Oricutron (un `-d` par lecteur :
`oricutron -m atmos -k microdisc -d build/cpa.dsk -d donnees.dsk`). Voir « Lecteurs A: à D: ».

La disquette contient `README.TXT`, un aide-mémoire de toutes les commandes et de leurs
paramètres, à lire sur l'Oric avec `TYPE README.TXT` (une page à la fois).

## Commandes du CCP

| Commande | Effet |
|---|---|
| `DIR [afn]` | liste les fichiers (jokers `*` et `?`) et l'espace libre ; les fichiers SYS sont cachés |
| `DIRS [afn]` | comme DIR, fichiers SYS compris |
| `TYPE fichier` | affiche un fichier texte (une touche l'interrompt) — TYPE.COM |
| `ERA afn [/Q]` | efface : montre les fichiers visés et demande `Effacer n fichier(s) (O/N) ?` (les protégés sont gardés) ; `/Q` sans question, pour un script — ERA.COM |
| `REN nouveau=ancien` | renomme — REN.COM |
| `SAVE n fichier` | enregistre n pages de 256 octets à partir de `$0500` |
| `GSAVE fichier`, `GLOAD fichier` | enregistre / charge l'image du mode SPLIT (type `.IMG` par défaut) |
| `PUT fichier commande [paramètres]` | exécute la commande en copiant tout ce qu'elle affiche dans le fichier |
| `DO fichier [p1 ... p9]` | exécute les commandes de `FICHIER.BAT`, une par ligne |
| `ECHO texte`, `PAUSE [texte]` | affiche un texte ; attend une touche (pour les scripts) |
| `PEN`, `PLOT`, `LINE`, `BOX`, `FBOX`, `CIRCLE`, `GTEXT`, `ATTR`, `POINT` | primitives graphiques (voir le mode SPLIT) |
| `NOM [args]` | charge `NOM.COM` en `$0500` et l'exécute ; à défaut, exécute le script `NOM.BAT` (comme `DO NOM [args]`) |
| `VER`, `CLS` | version, effacement de l'écran |
| `B:` (`A:` à `D:`) | change de lecteur courant (version disquette) ; l'invite devient `B>` |

TYPE, ERA et REN sont des programmes (`.COM`, sur la disquette système) et non des commandes
internes : cela libère près de 300 octets dans le système. On les tape de la même façon, y
compris dans les scripts et après PUT ; depuis un autre lecteur, ils sont cherchés sur A:.

Commandes transitoires (fichiers `.COM` sur la disquette) qui complètent le CCP :

| Commande | Effet |
|---|---|
| `HELP [sujet]` | aide en français : commandes internes, puis `HELP EDIT`, `HELP HEX`, `HELP LOGO`, `HELP ASM`, `HELP DEBUG`, `HELP MEM` (carte mémoire), `HELP TOUCHES`, `HELP PROG` |
| `SET afn [RO\|RW\|SYS\|DIR]` | attributs des fichiers (sans option : les affiche) |
| `STAT [d:][afn]` | taille de chaque fichier : enregistrements de 128 octets, blocs de 2 Ko, octets, attributs (`R` protégé, `S` système) ; sans paramètre : place libre sur le disque |
| `MEM` | carte de la mémoire (taille de la TPA selon le mode texte ou SPLIT) |
| `POKE adr bb [bb...]` | écrit des octets en mémoire (hexadécimal, `$` facultatif) |
| `GO adr [paramètres]` | lance le code en `adr` comme un `.COM` (un `RTS` ramène au prompt) |
| `XDO NOM [p1 ... p9]` | appel d'un script par un script ; lancé par le CCP, pas à taper (voir DO) |

Dans la version disquette, `HELP`, `MEM`, `DUMP`, `POKE` et `GO` ne sont plus internes, pour
laisser la place au BDOS : l'aide est dans `HELP.COM` (plus complète), `MEM`, `POKE` et `GO`
sont des `.COM`, et DEBUG fait le travail de `DUMP`. La version ROM, qui n'a pas de disque, les
garde en interne.

**POKE et GO en version disquette.** Comme tout `.COM`, ils sont chargés en `$0500` : chacun
tient en une page (`$0500-$05FF`), donc tout ce qui est à partir de `$0600` est préservé d'un
appel à l'autre. Un petit programme tapé avec plusieurs POKE commence donc en `$0600` :

    A>POKE 0600 A9 41 A2 02 20 03 02 60
    A>GO 0600
    A

Un seul POKE peut aussi écrire en `$0500` (pour un `SAVE` juste après) : il décode d'abord tous
les octets, puis les copie depuis la page zéro (`$D0-$DD`), par-dessus lui-même. Le POKE suivant
écraserait ces octets en se chargeant. `GO adr NOM.EXT` transmet la suite de la ligne au code
lancé : ligne de paramètres en `$0480` et FCB1 rempli avec le premier paramètre (FCB2 vide,
comme sous DEBUG).

**Taille d'un fichier (STAT).** Le répertoire CP/M ne compte que des enregistrements de
128 octets. STAT lit le dernier et retire les `^Z` (`$1A`) qui le complètent, comme le font
EDIT, PUT, LOGO et l'outil PC `mkdisk.py` : la taille en octets est exacte pour ces fichiers. Un
fichier binaire dont les derniers octets valent réellement `$1A` paraît un peu plus court.

    A>STAT *.TXT
    Fichier       Enreg  Blocs Octets At
    README  .TXT     79      5  10054 R
    1 fichier(s), R : 1, S : 0

La colonne `At` donne les attributs : `R` pour un fichier protégé (R/O), `S` pour un fichier
système (caché de DIR). La dernière ligne compte les fichiers, les protégés et les cachés.

## Lecteurs A: à D:

Tout nom de fichier peut commencer par un lecteur : `DIR B:`, `TYPE B:LETTRE.TXT`,
`COPY LETTRE.TXT B:`, `ERA B:*.BAK`, `STAT B:`, `EDIT B:NOTES.TXT`, `ASM B:PROG` (le `.COM`,
le `.SYM` et les `#include` sont sur le lecteur de la source), et dans LOGO `CHARGE "B:JEU`.
Sans lecteur, c'est le lecteur courant, choisi par `B:` au prompt ou par l'article **Lecteur
suivant** du menu Systeme (A, B, C, D, puis A). Un programme tapé sans lecteur
qui n'est pas sur le lecteur courant est cherché sur `A:` : depuis `B>`, `EDIT`, `LOGO` ou
`STAT` se lancent depuis la disquette système.

Chaque lecteur a la même organisation de disquette. Une disquette de données (sans système)
se prépare sur l'Oric avec `FORMAT B:`, ou sur le PC : `python3 tools/mkdisk.py new
donnees.dsk [fichiers...]` ; les pistes du système y restent inutilisées (336 Ko pour les
fichiers). Sur le LOCI, monter l'image sur le lecteur B, C ou D.

**FORMAT.** `FORMAT B:` formate la disquette du lecteur B: au format de CP/A (2 faces,
42 pistes, 17 secteurs de 256 octets) : chaque piste est écrite d'un coup (commande Write
Track du contrôleur), puis relue ; la progression s'affiche (`Piste 12 face 1`), ESC
interrompt entre deux pistes. Une confirmation est demandée (`Tout B: sera efface. Suite
(O/N) ?`). `FORMAT A:` marche avec un seul lecteur : il demande d'insérer la disquette à
formater, puis de remettre la disquette système (le système reste en mémoire). `FORMAT B: /Q`
vide seulement le répertoire d'une disquette déjà formatée : c'est instantané, et cela suffit
pour une image du LOCI ou d'Oricutron. Les secteurs sont entrelacés (1, 10, 2, 11...) pour
qu'un vrai lecteur Microdisc lise une piste en deux tours au lieu de dix-sept ; les images
faites par `mkdisk.py` ne le sont pas, ce qui ne change rien sur le LOCI ni dans Oricutron.

**DISKCOPY.** `DISKCOPY A: B:` copie la disquette de A: sur celle de B: (déjà formatée) :
amorçage et système, répertoire, puis seulement les blocs occupés par des fichiers ; `/T`
copie les 1 428 secteurs, `/V` relit et compare chaque secteur écrit. La copie se fait par
tranches d'environ 165 secteurs (la TPA), avec la progression (`Tranche 2 : ecriture`) ;
ESC arrête entre deux tranches. `DISKCOPY A: A:` marche avec un seul lecteur : la source et
la destination sont demandées tour à tour, une fois par tranche (4 échanges pour la
disquette système, 9 avec `/T`).

`DISKCOPY A: B: /S` rend la disquette de B: démarrable **sans toucher à ses fichiers**, comme
SYSGEN sous CP/M : il ne copie que l'amorçage et le système (secteurs 0 à 67, hors de la zone
des fichiers). Les commandes se copient ensuite avec COPY, comme avec PIP :

    A>DISKCOPY A: B: /S
    A>COPY *.COM B:

`DISKCOPY A: A: /S` marche aussi avec un seul lecteur.

**COPY** copie un ou plusieurs fichiers, jokers admis, comme PIP : `COPY LETTRE.TXT
LETTRE.BAK`, `COPY *.COM B:` (lecteur seul : mêmes noms), `COPY *.TXT *.BAK` (un `?` du
modèle prend le caractère de la source), `COPY B:*.LOG` (sans destination : le lecteur
courant). Chaque fichier copié est nommé, puis le nombre de copies. Les attributs ne sont
pas recopiés (comme PIP) : la copie d'une commande protégée est modifiable. Un fichier de
destination protégé est laissé (`fichier protege`), un fichier sur lui-même refusé (`meme
fichier`) ; les autres fichiers du même nom sont remplacés. ESC arrête entre deux fichiers.
COPY respecte le haut de la TPA (il marche aussi en mode SPLIT). Avec un seul lecteur, copier
d'une disquette à l'autre n'est pas encore possible.

Comme sous CP/M, le répertoire d'un lecteur est lu à sa première utilisation, et relu après
un démarrage à chaud (CTRL-C en début de ligne, ou fin d'un programme) : après avoir changé
de disquette, faire CTRL-C avant d'écrire dessus. Le lecteur courant est gardé au démarrage à
chaud (retour en `A:` s'il ne répond plus). Un lecteur vide ou absent ne bloque pas l'Oric :
après moins d'une seconde, `BDOS: disk I/O error`, et `B:` répond `B:?` sans changer de
lecteur. Un script DO continue de se lire sur sa disquette même s'il change de lecteur.

**Attributs de fichier.** Comme sous CP/M 2.2, deux bits du nom de fichier servent
d'attributs : R/O (lecture seule : le fichier ne peut être ni effacé, ni renommé, ni écrit,
ni remplacé) et SYS (fichier système : `DIR` ne le montre pas, `DIRS` oui ; il reste
utilisable). `SET HELP.COM RO SYS` protège et cache, `SET HELP.COM RW DIR` revient en arrière.
ERA garde les fichiers protégés (et les compte), REN répond `Fichier protege` ; EDIT et HEX
refusent d'enregistrer un fichier protégé, COPY et IMPORT répondent `fichier protege`. Les programmes passent par la fonction 30 du BDOS
(bit 7 de l'octet 9 du FCB = R/O, de l'octet 10 = SYS). `STAT *.*` montre les attributs de
tous les fichiers.

Sur la disquette livrée, les commandes et les applications (COPY, STAT, HELP, EDIT, LOGO,
ASM...), README.TXT et CPA.INC sont **protégées** (R/O) et restent **visibles** dans DIR,
comme sur une disquette CP/M : un `ERA *.*` ou un nom complété par ESC ne peut plus les
effacer. Pour remplacer une commande par une nouvelle version : `SET COPY.COM RW`, puis la
copier. Les exemples (HELLO, GTEST et leurs `.ASM`, DEMO.LOG, DESSIN.BAT) restent
modifiables : `ASM HELLO` réécrit HELLO.COM. Aucun fichier n'est caché (SYS) : l'attribut
reste à la disposition de l'utilisateur.

Touches : CTRL-T bascule les majuscules (voyant `A`, ou `a` pour les minuscules, au bout de
la barre de menus), CTRL-C en début de ligne fait un démarrage à
chaud. Le bouton RESET revient au CCP.

**Édition de la ligne, historique, complétion.** Au prompt `A>` comme dans les programmes qui
lisent une ligne par le BDOS (fonction 10 : LOGO, DEBUG…) :

| Touche | Effet |
|---|---|
| ← / → | déplacer le curseur dans la ligne ; ce qu'on tape s'insère |
| ↑ / ↓ | lignes déjà validées (historique), de la plus récente à la plus ancienne |
| ESC | compléter le nom de fichier qui se termine au curseur ; en début de ligne, la commande |
| DEL / CTRL-D | effacer à gauche / sous le curseur |
| CTRL-A / CTRL-E | début / fin de la ligne |
| CTRL-X | effacer toute la ligne |
| CTRL-P | imprimante : copier tout ce qui s'affiche, oui / non (voyant `P` ; voir plus bas) |

L'historique garde les dernières lignes (256 octets, une vingtaine de commandes courtes) ; il
survit au démarrage à chaud, et une ligne identique à la précédente n'y entre pas deux fois.

La complétion s'inspire du `filec` du C-shell, qui complétait déjà par ESC — touche placée sur
l'Oric à l'endroit de la touche TAB d'un clavier de PC. `TYPE REA` + ESC donne
`TYPE README.TXT ` (avec l'espace, prêt pour la suite). Si plusieurs fichiers conviennent, ESC
ajoute la partie commune (`DIR HELL` → `DIR HELLO.`) ; si rien ne peut être ajouté, ESC
affiche les noms possibles et réécrit la ligne en dessous. Sans majuscules (CTRL-T), le nom
est complété en minuscules. Un mot vide + ESC montre tout le disque.

**Premier mot : les commandes.** En début de ligne, ESC complète une commande : les
commandes internes (`FB` → `FBOX `) et les programmes `.COM` et `.BAT` du lecteur courant,
sans leur type (`ED` → `EDIT `, `DES` → `DESSIN `). `D` + ESC montre `DEBUG DISKCOPY DESSIN
DIR DIRS DO`. Les autres fichiers ne sont pas proposés en début de ligne. Cette complétion
coûte environ 120 octets dans le système ; elle est assemblée avec l'option `CPLCMD`, et
`DISK_OPTS="" ./build.sh` construit un système sans elle (la complétion des noms de fichiers
reste).

**Pause en fin d'écran.** Quand une commande remplit la console (27 lignes en mode texte,
10 en mode SPLIT) sans que l'utilisateur ait touché le clavier, l'affichage s'arrête sur
` -- Suite (^C stop) -- `. Une touche continue, CTRL-C abandonne et revient au
prompt. Cela vaut pour `HELP`, `TYPE`, `DIR`, `DUMP`… et pour les programmes qui affichent par
le BDOS ou le BIOS. Un programme qui ne veut pas de pause met `$02A3` à 0 (variable publique,
remise à 1 au démarrage à froid).

**Rediriger la sortie : PUT.** `PUT LISTE.TXT DIR`, `PUT AIDE.TXT HELP` ou
`PUT RAPPORT.TXT ASM PROG` exécutent la commande (interne ou programme `.COM`) normalement, et
tout ce qu'elle affiche est aussi écrit dans le fichier, au format texte CP/M (`^Z` à la fin).
On peut ensuite le relire avec `TYPE` ou le modifier avec `EDIT`. Pendant un PUT, la pause en fin
d'écran est suspendue. Les lignes de DIR, qui remplissent l'écran, reçoivent leur fin de ligne
dans le fichier.

Comment ça marche : `conout` range aussi chaque caractère dans un tampon de 1 280 octets. Écrire
sur le disque au milieu d'un affichage serait dangereux (l'affichage peut avoir lieu au milieu
d'une fonction du BDOS ou entre « chercher premier » et « chercher suivant »). Les
enregistrements pleins sont donc écrits à l'entrée de l'appel BDOS suivant, en sauvant puis en
rendant l'état du système de fichiers. Le fichier est refermé au retour au prompt (ou au
démarrage à chaud). Un programme qui afficherait beaucoup sans jamais appeler le BDOS ferait
déborder le tampon : la fin serait perdue, et un message le signale.

**Scripts : DO.** `DO NOM [p1 ... p9]` lit `NOM.BAT` et exécute ses lignes une à une, comme si on
les tapait au prompt (chaque ligne est affichée après `A>`). Les lignes vides et celles qui
commencent par `;` sont ignorées. `$1` à `$9` sont remplacés par les paramètres donnés à DO
(`$$` donne `$`). Un script se lance aussi par son nom, comme un programme : `NOM [p1 ... p9]`
exécute `NOM.BAT` s'il n'y a pas de `NOM.COM` (`NOM.BAT` tapé en entier aussi ; un autre type
que COM ou BAT est refusé). Les programmes lancés par le script lisent le clavier normalement,
et un script peut en appeler un autre (par DO ou par son nom) : à la fin du script appelé,
l'appelant reprend à la ligne suivante. C'est `XDO.COM` qui s'en charge, au moment de l'appel
seulement : il écrit `$$$.BAT`, fait du script appelé (avec ses paramètres) suivi de la fin de
l'appelant (avec les siens), puis enchaîne sur `DO $$$` ; on voit passer `A>XDO ...` et
`A>DO $$$`. Le script appelé est relu à chaque appel : rien à recompiler quand on le modifie.
Un script qui n'en appelle pas d'autre ne passe pas par XDO. Il faut une disquette où l'on peut
écrire ; sans `XDO.COM`, la ligne d'appel est sautée (`XDO?`). Un script qui modifie un script
déjà en cours d'exécution (l'appelant) n'est pas sûr. ESC tapé entre deux lignes, ou pendant un `PAUSE`,
arrête le script. `ECHO texte` affiche un texte et `PAUSE [texte]` attend une touche. La pause
en fin d'écran repart à zéro à chaque ligne du script. Exemple sur la disquette : `DESSIN.BAT`.

    ; DESSIN.BAT : demo des commandes graphiques
    SPLIT
    BOX 0 0 239 126
    CIRCLE 60 64 40
    GTEXT 2 114 $1
    ECHO Fini.

    A>DO DESSIN Bonjour

`ECHO`, `GTEXT` et les paramètres de DO gardent les minuscules telles qu'elles sont tapées
(le reste de la ligne de commande passe en majuscules).

**Limites des scripts.** Un script n'est qu'une suite de commandes, comme tapées au clavier :
il n'y a ni calcul, ni variable, ni condition, ni boucle. `$1` à `$9` sont remplacés par le
texte des paramètres, sans rien évaluer : `($1+4)` devient `(10+4)`, que les commandes ne
comprennent pas. Un script qui s'appelle lui-même ne s'arrête jamais de lui-même (il n'y a pas
de condition pour sortir) : seul ESC l'arrête. Exemple qui ne marche pas :

    ; SCRIPT.BAT : trait en $1, puis le suivant 4 points plus loin ?
    LINE $1 100 $1 110
    SCRIPT ($1+4)

La première ligne trace bien le trait en 10, mais la deuxième passe `(10+4)` tel quel. Au
niveau suivant, `LINE (10+4) 100 (10+4) 110` n'est pas compris ; le script se rappelle ensuite
sans fin avec un paramètre de plus en plus long, jusqu'à ESC. Pour calculer, répéter ou décider,
il faut un programme : LOGO (`REPETE`, variables, `SI`) ou un `.COM`.

**L'alternative : confier le calcul à LOGO, depuis le script.** Le script garde ce qu'il fait
bien (enchaîner des commandes et des programmes) et LOGO fait le reste. Deux propriétés le
permettent : `LOGO NOM` charge `NOM.LOG` au démarrage et `CHARGE` exécute les lignes du fichier
qui ne sont pas des procédures, donc un programme peut se lancer seul et finir par `QUITTE` ;
et en sortant de LOGO, l'image reste intacte, en mode SPLIT : le script continue sur le même
dessin, et les commandes graphiques du CCP peuvent le compléter. Exemple :

    ; PELOUSE.BAT
    SPLIT
    CIRCLE 120 30 20
    LOGO HERBE
    GTEXT 2 114 Pelouse finie

    POUR HERBE :N
    REPETE :N [AV 10 RE 10 LC DR 90 AV 4 GA 90 BC]
    FIN
    LC FIXEXY -110 -40 BC
    HERBE 50
    QUITTE

(la seconde partie est `HERBE.LOG`). Le cercle tracé par le CCP, les 50 brins tracés par LOGO
et le texte ajouté ensuite par le script restent ensemble à l'écran. Le script ne peut pas
passer de paramètre à LOGO (`LOGO NOM` ne prend que le nom du fichier) : les valeurs sont dans
`NOM.LOG`, qu'on peut avoir écrit avec EDIT.

## Échange de fichiers avec la clé USB du LOCI

Sur un Oric équipé d'un LOCI, trois commandes copient des fichiers entre CP/A et la clé USB
du LOCI (une clé FAT, celle qui porte souvent `cpa.dsk`), sans passer par le PC ni par
`mkdisk.py` :

| Commande | Effet |
|---|---|
| `EXPORT fic [nom]` | copie le fichier de CP/A `fic` sur la clé, sous le nom `nom` (par défaut, `fic` tel qu'il a été tapé, minuscules gardées, à la racine) |
| `EXPORT afn [dossier]` | avec des jokers (`*.LOG`, `B:*.*`) : chaque fichier sous son nom, en minuscules si le modèle a été tapé en minuscules, à la racine ou dans le dossier donné ; un `.DSK` est sauté, ESC arrête entre deux fichiers |
| `IMPORT nom [fic] [/T]` | copie le fichier `nom` de la clé dans CP/A, sous le nom `fic` (par défaut, le nom de la clé sans son chemin, coupé à 8 + 3 caractères ; `B:` seul : ce nom-là sur le lecteur B:) ; `/T` : texte, un LF seul (fin de ligne du Mac, de Linux) devient CR LF — indispensable pour un `.LOG` écrit sur le Mac, que `CHARGE` de LOGO ne lit qu'en CR LF |
| `USBDIR [chemin]` | liste un dossier de la clé (la racine par défaut) : nom et taille, `<REP>` pour un dossier |

    A>EXPORT LETTRE.TXT
    A>EXPORT B:JEU.LOG 1:/oric/jeu.log
    A>export *.log oric
    A>IMPORT notes.txt /T
    A>IMPORT docs/MATH.LOG B:
    A>USBDIR docs

Les noms de la clé peuvent avoir un chemin. Sans lecteur, c'est la première clé USB vue par
le LOCI : c'est le plus sûr, car avec un hub la clé n'est pas forcément `1:` (le LOCI
numérote les appareils USB). `0:` désigne la mémoire interne du LOCI (`USBDIR 0:`,
`EXPORT X.TXT 0:X.TXT`). Un nom avec des espaces ne passe pas sur la ligne de commande :
le renommer sur le Mac.

- Un fichier du même nom est remplacé, sur la clé comme dans CP/A.
- EXPORT retire les `^Z` (`$1A`) qui complètent le dernier enregistrement (même règle que
  STAT) : un texte arrive à sa vraie taille ; les fins de ligne restent CR LF, que les
  éditeurs du Mac lisent. IMPORT complète le dernier enregistrement par des `^Z`. Un binaire
  fait l'aller-retour à l'identique, sauf s'il se termine réellement par des octets `$1A`.
- EXPORT refuse un nom en `.DSK` : ce pourrait être l'image de disquette en service.
- Si la disquette ou la clé est pleine, le fichier commencé est effacé (IMPORT) ou le message
  le dit (EXPORT).
- USBDIR ne montre ni les fichiers cachés ou système, ni ceux qui commencent par un point
  (les `._NOM` que le Mac laisse sur les clés FAT). ESC ou CTRL-C arrête la liste.
- Sans LOCI (Oricutron, Microdisc, Cumulus) : `LOCI absent : cle USB inaccessible`.
  Les erreurs du LOCI s'affichent avec leur code : `Erreur USB 36 : introuvable`.

Ces commandes passent par l'interface que le LOCI offre au 6502, celle du Picocomputer 6502
(registres en `$03A0-$03BF`, détail dans `progs/loci_inc.s`). Pour les essayer sans le
matériel, l'Oricutron de l'atelier simule cette interface sur un dossier du PC :
`ORIC_LOCI=dossier` (voir « Outils »).

## Démarrage et reprise après plantage

Au démarrage à froid, CP/A teste la RAM des programmes comme le fait la ROM de l'Atmos :
il écrit `$AA` puis `$55` dans chaque octet et vérifie la relecture. Il affiche ensuite
`RAM test OK.` ou l'adresse du premier octet défectueux. Le test dure environ 1,5 s.

Contrairement à la ROM, il laisse la mémoire remplie de `$00`, qui est l'instruction `BRK`.
Un programme qui saute par erreur dans une zone vide est donc intercepté :
`*BRK* at xxxx` s'affiche, puis le système revient au prompt.

Le bouton RESET de l'Atmos, câblé sur une interruption NMI, ramène au prompt en affichant
l'adresse où tournait le programme (`*RESET* at xxxx`). Ça permet de sortir d'une boucle
infinie et de savoir où elle se trouvait. Après BRK ou RESET, l'écran repasse en mode texte,
même si le programme était en haute résolution, et la police est rechargée.

Chaque démarrage à chaud remet aussi en place :
- les vecteurs de la page 2 ;
- le VIA et le timer à 50 Hz ;
- le son, coupé ;
- la police ;
- la barre de menus.

Seules les instructions illégales de type « JAM », qui bloquent le 6502 lui-même, et
l'écrasement du système en RAM (version disque) obligent à redémarrer complètement.

## Mode SPLIT : image et texte

`SPLIT` partage l'écran en deux : une image de 240 × 128 points en haute résolution
en haut, et du texte en dessous (la barre de menus puis 10 lignes de console).
Le prompt, les commandes et les menus continuent de fonctionner sous l'image.
`TEXT` revient au mode texte, et `GCLS` efface l'image.

`GSAVE NOM` enregistre l'image dans `NOM.IMG`, et `GLOAD NOM` la recharge en passant en
mode SPLIT si besoin (la console n'est pas effacée si on y est déjà). Le fichier est la
copie brute de `$A000-$B3FF` : 5 120 octets, attributs de couleur compris. On peut ainsi
préparer des images (avec LOGO, ou un programme de dessin) et les recharger dans un jeu.

Comment ça marche : comme avec le `HIRES` du BASIC, la dernière case de l'écran (`$BFDF`)
contient l'attribut `$1E`, qui fait commencer la trame suivante en haute résolution : tout
l'octet `$A000` est donc visible et utilisable. La première case de la ligne de points 127
(`$B3D8`, seul octet de l'image qui ne sert pas aux points) contient `$1A`, qui fait revenir au
texte à la ligne 128. La dernière ligne de texte ne contient que des attributs (elle reste
vide) : le vrai circuit vidéo change de mode à la ligne de points suivante, et la fin de cette
ligne serait dessinée avec la police du mode HIRES, qui n'existe pas ici. L'image (`$A000-$B3FF`)
s'arrête juste avant la police du mode texte (`$B400`), si bien qu'aucune zone ne se
chevauche. Pendant le mode SPLIT, la TPA s'arrête en `$9FFF` (variable publique `$020C`).

Le HIRES complet (200 lignes) n'est pas géré par le système : les programmes qui en ont
besoin le pilotent entièrement eux-mêmes.

**Primitives graphiques** (fonction 115 du BDOS, A/Y = adresse d'un bloc de 6 octets
`[op, p1..p5]`, comme pour l'extension GSX de CP/M) :

| op | Primitive | Paramètres |
|---|---|---|
| 0 | GCLS | — |
| 1 | PEN | 0 efface, 1 trace, 2 inverse |
| 2 | PLOT | x (0-239), y (0-127) |
| 3 | LINE | x1, y1, x2, y2 |
| 4 / 5 | BOX / FBOX | x1, y1, x2, y2 (rectangle vide / plein) |
| 6 | CIRCLE | x, y, r (r ≤ 127) |
| 7 | TEXT | colonne (0-39), y, adresse de la chaîne |
| 8 | ATTR | colonne, y1, y2, attribut (encre 0-7, papier 16-23) |
| 9 | POINT | x, y → A = 1 si le point est allumé |
| 10 | MODE | 0 texte, 1 SPLIT (image effacée), 2 SPLIT en gardant l'image |
| 11 | GETMODE | → A = 0 texte, 1 SPLIT |
| 12 | GSAVE | adresse du FCB (octet bas, octet haut) : enregistre l'image |
| 13 | GLOAD | adresse du FCB : charge une image et passe en SPLIT |

GSAVE et GLOAD (version disque) prennent le type `.IMG` si le nom n'en a pas, et renvoient
0 si tout va bien, 1 si le fichier est absent, 2 si le disque ou le répertoire est plein,
`$FF` pour GSAVE hors du mode SPLIT. Un programme qui appelle GLOAD depuis le mode texte doit
rester sous `$A000`.

**Au prompt**, chaque primitive a sa commande, avec ses paramètres en décimal (0 à 255) :
`PEN m`, `PLOT x y`, `LINE x1 y1 x2 y2`, `BOX x1 y1 x2 y2`, `FBOX x1 y1 x2 y2`, `CIRCLE x y r`,
`GTEXT col y texte`, `ATTR col y1 y2 v`, `POINT x y` (affiche 0 ou 1). Il faut être en mode
SPLIT (pas de bascule automatique : `Not in SPLIT mode.`) et donner exactement le bon nombre de
paramètres (sinon `Syntax?`). Avec `DO`, on dessine ainsi sans programme, et `GSAVE` garde le
résultat. Le crayon est en mode « trace » au démarrage.

Hors du mode SPLIT, les primitives 0 à 9 renvoient `$FF`. `GTEST.COM` est un exemple
complet : il passe en SPLIT et dessine un cadre, des diagonales, des cercles, des
rectangles et du texte.

## Le son (fonction 116 du BDOS)

Le circuit sonore de l'Oric (AY-3-8912, trois voix et un bruit) est accessible comme le
graphisme : X = 116, A/Y = adresse d'un bloc `[op, p1..p5]`. Les deux versions (disquette et
ROM) l'ont.

| op | Primitive | Paramètres |
|---|---|---|
| 0 | SILENCE | — (coupe les trois voix) |
| 1 | NOTE | voix (0-2), note (1-96 ; 37 = do central, 46 = la 440 Hz ; 0 = silence), volume (0-15, 16 = enveloppe), durée |
| 2 | NOISE | voix, période du bruit (0-31), volume, durée |
| 3 | ENV | forme (0-15), période lo, période hi (enveloppe) |
| 4 | WAIT | voix (255 : toutes) — attend la fin des notes |
| 5 | STATUS | → A : un bit par voix qui joue encore |
| 6 | TONE | voix, période lo, période hi (0-4095), volume, durée |
| 7 | SYNC | mode : 0 préparation, 1 départ, 2 abandon (voir plus bas) |
| 8 | MIXER | voix, son (0/1), bruit (0/1) — les deux à la fois sont possibles |

La durée est en cinquantièmes de seconde (0 : la note tient jusqu'à la suivante). Elle est
décomptée par l'interruption à 50 Hz : le programme continue pendant que la note joue, et
`WAIT` ou `STATUS` servent à se synchroniser. Le clavier passant lui aussi par l'AY, les
écritures dans le circuit sont faites interruptions masquées. Dans LOGO : `SON`, `SONF`,
`BRUITV`, `ENVELOPPE`, `MELANGE`, `ENSEMBLE`, `ATTENDSSON`, `JOUE?` et `SILENCE` (voir
« Le son dans LOGO »).

**Départ simultané (SYNC).** Après `SYNC 0`, NOTE, NOISE et TONE règlent la période et le
mélangeur de la voix tout de suite, mais la coupent et retiennent son volume et sa durée ; ENV
règle la période de l'enveloppe et retient son départ. `SYNC 1` fait alors partir toutes les
voix préparées dans le même instant, interruptions masquées (quelques microsecondes d'écart),
et relance l'enveloppe si elle a été réglée pendant la préparation : les voix commencent
ensemble et, à durée égale, s'arrêtent au même top de 50 Hz. `SYNC 2` abandonne (les voix
préparées restent muettes), SILENCE aussi.

**Mélangeur (MIXER).** NOTE et TONE mettent le son de la voix et coupent son bruit, NOISE
l'inverse. MIXER, donné ensuite, choisit son et bruit librement, y compris les deux à la fois
sur la même voix (bruitages). Le générateur de bruit et l'enveloppe sont uniques dans l'AY :
leur période est commune aux trois voix.

## Menus déroulants

La ligne d'état sert de barre de menus : **Systeme** (Version, Aide, Memoire, Imprimante,
Lecteur suivant, Redemarrer), **Fichiers** (version disque seulement),
**Ecran** (Mode SPLIT, Mode texte, Effacer, Encre, Papier, Majuscules) et **Clavier**. Au bout
de la barre, deux voyants : `A` (majuscules verrouillées) ou `a` (minuscules), puis `P` quand
la copie à l'imprimante est active. Le moteur est réécrit d'après le projet
[Menus](https://github.com/drpsy77/Menus) de Pierre Garnier, dont il reprend l'ergonomie,
les couleurs et le format de table.

- **FUNCT** ouvre la barre, puis **←/→** passent d'un menu à l'autre.
- **↓** ou **ENTER** déroule le menu, **↑/↓** choisissent l'article, et remonter au-dessus du
  premier article referme le menu.
- **ENTER** exécute l'article choisi, **ESC** ou **FUNCT** ferment le menu.

Le menu s'ouvre à chaque lecture du clavier : au prompt `A>`, mais aussi dans un programme
qui lit le clavier par le BIOS ou le BDOS. La zone d'écran qu'il recouvre est sauvegardée
puis restaurée.

Un article déclenche l'une de ces deux actions :
- **taper une commande** à la place de l'utilisateur, par exemple `DIR` suivi d'Entrée, ou
  `TYPE ` laissé à compléter ;
- **appeler une routine**, par exemple pour changer l'encre, le papier, les majuscules ou la
  vitesse de répétition des touches.

Un programme peut installer sa propre barre par `JSR $C02D` avec A/Y = adresse de la barre :

    barre   .byt 2                      ; nombre de menus (8 au plus)
            .word menu1, menu2
    menu1   .byt 2,9                    ; nombre d'articles, largeur du plus long libellé
            .asc "Fichier",0            ; titre
            .asc "Ouvrir...",0          ; libellé
            .byt 1                      ; 1 = taper une chaîne, 2 = appeler une routine
            .word chaine_ou_routine
            .asc "Quitter",0
            .byt 2
            .word quitter

## L'éditeur de texte EDIT

    A>EDIT LETTRE.TXT

C'est un éditeur plein écran : 26 lignes de 38 colonnes, avec une barre de menus et une ligne
d'état (nom du fichier, `*` si le texte est modifié, paragraphe `L`, colonne `C`, `INS`/`RFP`,
`M` si une marque est posée). Par défaut, les lignes sont coupées entre les mots.
Le texte peut atteindre environ 34 Ko.

| Touche | Action |
|---|---|
| Flèches | déplacer le curseur |
| RETURN | nouveau paragraphe |
| DEL / CTRL-D | effacer à gauche / sous le curseur |
| CTRL-Y | effacer le paragraphe |
| CTRL-A / CTRL-E | début / fin de ligne |
| CTRL-R / CTRL-C | page précédente / suivante |
| CTRL-Q / CTRL-Z | début / fin du texte |
| CTRL-O | insertion / remplacement |
| CTRL-F / CTRL-G | chercher / suivant (repart du début si besoin) |
| CTRL-S | enregistrer |
| CTRL-L | insérer un fichier au curseur (Fichier, Insérer...) |
| CTRL-P | imprimer le texte (Fichier, Imprimer) |
| FUNCT | menus |

Menus :
- **Fichier** : Nouveau, Ouvrir..., Insérer..., Enregistrer, Enreg. sous..., Imprimer, Quitter. Le
  système demande confirmation avant de perdre des modifications. Insérer... ajoute le contenu
  d'un autre fichier texte à l'endroit du curseur (le curseur se retrouve après le texte inséré).
  Imprimer envoie tout le texte sur l'imprimante (port Centronics, fonction 5 du BDOS), un
  paragraphe par ligne (CR LF à la fin de chacun) : l'imprimante coupe elle-même les lignes trop
  longues. ESC arrête entre deux paragraphes. Sans imprimante rien ne bloque, mais chaque
  caractère attend 2 ms l'accusé de réception (une vingtaine de secondes pour 10 Ko) : ESC.
  Lancé depuis LOGO par `EDITE`, EDIT montre Retour au lieu de Quitter : il enregistre le texte
  s'il a changé et revient dans LOGO (voir LOGO).
- **Edition** : Marquer, Copier, Couper, Coller, Eff. paragr. Le presse-papiers fait 4 Ko au plus.
  On marque un bout du bloc, on déplace le curseur à l'autre bout, puis on copie ou on coupe.
- **Chercher** : Chercher..., Suivant, Remplacer.... Pour chaque occurrence, on répond
  O (oui), N (non), T (tous) ou Esc. La recherche ignore la différence majuscules/minuscules.
- **Options** : Coupure mots (entre les mots, ou à 38 caractères), Ins/Rempl., Statistiques
  (caractères et mots).

Lancé depuis le mode SPLIT, l'éditeur passe en plein écran texte et garde son texte sous
`$A000` (environ 29 Ko). En sortant, il réaffiche l'image intacte.

Les fichiers sont du texte CP/M : CR LF entre les paragraphes, `^Z` à la fin. Pour ne rien perdre
si le disque est plein, l'enregistrement écrit d'abord `NOM.$$$`, puis remplace l'ancien fichier.

Programmes fournis sur la disquette :
- `HELLO.COM` affiche ses arguments ;
- `COPY.COM src [dst]` copie des fichiers (jokers admis), par gros blocs, à travers le BDOS.
- `EDIT.COM [fichier]`, l'éditeur de texte décrit ci-dessus.
- `GTEST.COM`, le test du mode SPLIT et des primitives graphiques.
- `LOGO.COM`, avec `DEMO.LOG`.
- `HEX.COM fichier`, l'éditeur hexadécimal décrit plus bas.
- `ASM.COM NOM`, l'assembleur 6502, avec les sources d'exemple `HELLO.ASM`, `GTEST.ASM` et
  `CPA.INC`.
- `DEBUG.COM NOM`, le moniteur, désassembleur et pas à pas.
- `STAT.COM`, `MEM.COM`, `POKE.COM`, `GO.COM`, `XDO.COM`, décrits plus haut.
- `EXPORT.COM`, `IMPORT.COM`, `USBDIR.COM` : échange de fichiers avec la clé USB du LOCI.
- `FORMAT.COM X: [/Q]` : formatage d'une disquette (voir « Lecteurs A: à D: »).
- `DISKCOPY.COM src: dst: [/T] [/V] [/S]` : copie d'une disquette, ou de son système.

## LOGO

    A>LOGO

C'est un Logo en français. La tortue dessine dans l'image du mode SPLIT (LOGO y passe tout seul),
et on tape les commandes sous l'image, après le prompt `?`. Les nombres sont des entiers ou des
décimaux (voir plus bas).

| Commande | Effet |
|---|---|
| `AVANCE n` / `AV`, `RECULE n` / `RE` | avancer, reculer |
| `DROITE n` / `DR`, `GAUCHE n` / `GA` | tourner (degrés) |
| `LEVECRAYON` / `LC`, `BAISSECRAYON` / `BC` | lever, baisser le crayon |
| `GOMME`, `INVERSE` | le crayon efface, inverse |
| `CACHETORTUE` / `CT`, `MONTRETORTUE` / `MT` | cacher, montrer la tortue |
| `VIDEECRAN` / `VE`, `NETTOIE`, `ORIGINE` | effacer et revenir au centre, effacer, revenir au centre |
| `FIXECAP n`, `FIXEXY x y` | cap absolu, position absolue (centre = 0 0, y vers le haut) |
| `POINT x y`, `TRAIT x1 y1 x2 y2` | un point, un trait (coordonnées de la tortue) |
| `RECTANGLE x1 y1 x2 y2`, `PAVE x1 y1 x2 y2` | rectangle (deux coins opposés), rectangle plein |
| `CERCLE r` | cercle de rayon r (0 à 127) autour de la tortue |
| `ETIQUETTE x` | écrit x (nombre, mot ou liste, comme `ECRIS`) dans l'image, à droite de la tortue et posé sur sa ligne |
| `FIXECOULEUR v` | couleur de toute l'image : encre 0 à 7 (0 noir, 1 rouge, 2 vert, 3 jaune, 4 bleu, 5 magenta, 6 cyan, 7 blanc) ou papier 16 à 23 |
| `ECRANTEXTE`, `ECRANMIXTE` | passer en écran texte (26 lignes, sans image ni tortue), revenir à l'image et à la tortue |
| `REPETE n [ ... ]` | répéter une liste |
| `SI condition [ ... ] [ ... ]` | condition, avec une liste « sinon » facultative |
| `POUR NOM :A :B` ... `FIN` | définir une procédure (paramètres facultatifs) |
| `STOP` | sortir de la procédure |
| `RENDS x` | sortir de la procédure en rendant x : elle devient une fonction (voir plus bas) |
| `DONNE "X n`, `:X` | variable globale, valeur d'une variable ou d'un paramètre |
| `ECRIS n` / `EC`, `ECRIS "mot`, `ECRIS [texte]` | afficher |
| `ATTENDS n` | attendre n cinquantièmes de seconde |
| `LISLISTE` / `LL` | lit une ligne au clavier et la rend en liste (`DONNE "R LISLISTE`) ; la ligne passe en majuscules |
| `LISMOT` | lit une ligne et la rend en un seul mot (sans les blancs du début et de la fin) |
| `LISCAR` | attend une touche et rend le caractère (`ASCII LISCAR` pour son code) |
| `TOUCHE?` | 1 si une touche a été tapée (on la lit ensuite avec `LISCAR`), 0 sinon ; n'attend pas |
| `ASCII x`, `CAR n` | code du premier caractère ; caractère de code n |
| `SAUVE "NOM`, `CHARGE "NOM` | enregistrer les procédures, charger un fichier (`NOM.LOG` : procédures et autres lignes, exécutées) ; le nom peut être calculé (`CHARGE :F`, `CHARGE MOT "S :N`) et commencer par un lecteur (`CHARGE "B:JEU`) |
| `EDITE "NOM` | modifier les procédures avec EDIT, puis revenir (voir plus bas) |
| `SAUVEIMAGE "NOM`, `CHARGEIMAGE "NOM` | enregistrer, charger le dessin (`NOM.IMG`, sans la tortue) |
| `TITRES`, `LISTE "NOM`, `OUBLIE "NOM`, `OUBLIETOUT` | lister, afficher, supprimer |
| `SON v n vol d`, `SONF`, `BRUITV`, `ENVELOPPE`, `MELANGE`, `ENSEMBLE`, `ATTENDSSON`, `SILENCE` | le son : voir « Le son dans LOGO » plus bas |
| `AIDE`, `QUITTE` / `AUREVOIR` | aide, retour à CP/A (l'image reste) |

**Dessiner sans la tortue.** `POINT`, `TRAIT`, `RECTANGLE`, `PAVE`, `CERCLE` et `ETIQUETTE`
prennent les coordonnées de la tortue (centre 0 0, y vers le haut) mais ne la déplacent pas.
Ils suivent le mode du crayon (`GOMME`, `INVERSE`), même crayon levé, et sont découpés aux
bords de l'image ; `CERCLE` et `ETIQUETTE` ne dessinent rien si la tortue est hors de
l'image. `FIXECOULEUR` pose la couleur en tête de chaque ligne de l'image : ses 6 premiers
points (la colonne 0) deviennent la couleur, que le dessin n'efface pas. `ALLUME? x y` rend 1
si le point est allumé, 0 sinon. Tous refusent l'écran texte (`ECRANTEXTE`).

    VE CERCLE 40 RECTANGLE -40 -40 40 40 TRAIT -40 -40 40 40
    ETIQUETTE [BONJOUR] FIXECOULEUR 3
    SI ALLUME? 0 0 [ECRIS "ALLUME]

Dans les expressions : `+ - * / ( ) = < >`, ainsi que `HASARD n`, `CAP`, `XCOR`, `YCOR`, `ALLUME? x y`,
`LISCAR`, `TOUCHE?`, `JOUE? v`, `RACINE x`, `SIN x`, `COS x`, `ARCTAN x` (angles en degrés, comme la
tortue : `SIN 30` donne 0.5, `ARCTAN 1` donne 45), `LN x`, `EXP x`, `ENT x` (partie entière, vers zéro), `ARRONDI x` (entier le plus proche,
2.5 donne 3), `ABS x`, `QUOTIENT a b` (division entière, vers zéro) et `RESTE a b` (du signe
de `a`). Une touche tapée pendant qu'un programme tourne est gardée pour `LISCAR` (la
dernière seulement) ; elle est oubliée au retour au prompt. ESC interrompt aussi `LISCAR`.

**Le son dans LOGO.** Les trois voix de l'AY (0, 1, 2) jouent pendant que le programme
continue ; chaque durée est en cinquantièmes de seconde (0 à 255 ; 0 : la note tient jusqu'à
la suivante sur la voix, ou jusqu'à `SILENCE`). Une valeur hors limites donne `Valeur hors
limites :` suivi de la commande. ESC et toute erreur coupent le son.

| Primitive | Effet |
|---|---|
| `SON v n vol d` | note n sur la voix v : 1 à 96, 37 = do central, 46 = la 440 Hz (n = 12 × (octave − 1) + demi-ton + 1, do = 0), 0 = silence pendant d ; volume 0 à 15, 16 = la voix suit l'enveloppe |
| `SONF v p vol d` | son de période brute p (0 à 4095) : fréquence = 62 500 / p Hz (p = 142 : la 440 Hz) |
| `BRUITV v p vol d` | bruit sur la voix v, période p (0 à 31 ; le générateur de bruit est commun aux trois voix) |
| `ENVELOPPE f p` | forme f (0 à 15, celles de l'AY : 0 descente, 4 montée, 8 dents de scie, 10 triangle...), période p (0 à 65535, en 256 µs) ; une seule enveloppe pour toutes les voix de volume 16 |
| `MELANGE v s b` | son (s) et bruit (b) de la voix v, 1 = oui, 0 = non, les deux à la fois possibles ; à donner après `SON`, `SONF` ou `BRUITV`, qui le règlent |
| `ENSEMBLE [ ... ]` | les voix réglées dans la liste partent toutes au même instant à la fin de la liste (accord, attaque commune) ; aussi après un `STOP` ou un `RENDS` dans la liste |
| `ATTENDSSON v` | attend la fin de la voix v, ou de toutes avec 255 ; ESC interrompt |
| `JOUE? v` | 1 si la voix v (255 : l'une des trois) joue encore, 0 sinon ; une note sans fin (durée 0) ne compte pas |
| `SILENCE` | coupe les trois voix |

    SON 0 37 12 20 ATTENDSSON 0
    REPETE 2 [SON 0 37 12 20 ATTENDSSON 0 SON 0 41 12 20 ATTENDSSON 0]
    ENVELOPPE 0 2000
    ENSEMBLE [SON 0 37 16 100 SON 1 41 16 100 SON 2 44 16 100]
    BRUITV 0 20 15 50 MELANGE 0 1 1

L'accord de do majeur part d'un coup et s'éteint avec l'enveloppe ; la dernière ligne mêle une
note et du bruit sur la voix 0. `NOTE` et `BRUIT` des versions précédentes n'existent plus :
`NOTE 37 20` s'écrit `SON 0 37 12 20 ATTENDSSON 0`.

**Nombres.** Les nombres décimaux s'écrivent avec un point : `3.14`, `0.5`, `1.5E-7`, `6E23`.
Ils sont « à la Oric » : 5 octets, environ 9 chiffres significatifs, de 1E-38 à 1E38 environ.
Un calcul entre entiers reste entier tant qu'il tient entre -32768 et 32767 ; sinon il passe
en décimal (`32767 + 1` donne 32768, `1000 * 1000` donne 1000000). `/` est une vraie
division : `7 / 2` donne 3.5, `6 / 3` donne 2. `ECRIS` affiche au plus 9 chiffres, sans zéros
inutiles, en notation E au-delà de 999999999 ou en dessous de 0.00001. Les commandes qui
attendent un entier (`REPETE`, `SON`, `ATTENDS`...) arrondissent au plus proche (`REPETE 2.6`
répète 3 fois) ; au-delà de 32767 : `Nombre trop grand`. `SI` est vrai pour tout nombre non
nul.

**Mots et listes.** `"BONJOUR` est un mot (il va jusqu'au prochain blanc ou crochet :
`"-3.5` aussi), `[UN DEUX [TROIS]]` une liste ; les deux se rangent dans des variables
(`DONNE "L [A B C]`) et se passent aux procédures. Fonctions :

| Fonction | Résultat |
|---|---|
| `PREMIER x` / `PR`, `DERNIER x` / `DER` | premier, dernier élément (ou caractère d'un mot) |
| `SAUFPREMIER x` / `SP`, `SAUFDERNIER x` / `SD` | tout sauf le premier, sauf le dernier |
| `ITEM n x`, `COMPTE x` | n-ième élément ; nombre d'éléments (ou de caractères) |
| `MOT a b` | mot fait de a puis b (`MOT "BON "JOUR`) |
| `PHRASE a b` / `PH` | liste des éléments de a puis de b |
| `LISTE a b` | liste de deux éléments (une liste reste une sous-liste) |
| `VIDE? x`, `MOT? x`, `LISTE? x`, `NOMBRE? x`, `MEMBRE? a b` | 1 ou 0 |

`EXECUTE [ECRIS 5 AV 10]` (ou `EXEC`) exécute une liste. Un mot qui a l'écriture d'un nombre
compte comme ce nombre (`"12 + 1` donne 13), et un nombre devient un mot là où il en faut un
(`COMPTE 12345` donne 5). `=` compare aussi les mots et les listes. Dans une expression,
`LISTE` est la fonction ci-dessus ; en début de ligne, `LISTE "NOM` affiche toujours une
procédure. Les mots et listes occupent le haut de la mémoire libre, les procédures le bas ;
quand la place manque, LOGO récupère celle des textes qui ne servent plus.

**Fonctions de l'utilisateur.** Une procédure qui se termine par `RENDS x` s'emploie dans une
expression, comme `RACINE` :

    POUR FACT :N
    SI :N < 2 [RENDS 1]
    RENDS :N * FACT :N - 1
    FIN
    ? ECRIS FACT 10
    3628800

Elle peut rendre un nombre, un mot ou une liste, s'appeler elle-même et servir d'argument à
une autre (`ECRIS SOMME CARRE 3 CARRE 4`). Une fonction qui arrive à `FIN` (ou à `STOP`) sans
`RENDS` donne `Rien n'a ete rendu par NOM` ; une procédure appelée comme une commande ne doit
pas faire `RENDS` (`Que faire de ce que rend NOM`). Les fonctions qui s'appellent elles-mêmes
vont jusqu'à une quarantaine de niveaux (`Trop de niveaux` au-delà) ; les procédures appelées
comme des commandes, elles, peuvent s'appeler beaucoup plus profondément.

**La tortue et les décimaux.** `AV`, `RE`, `DR`, `GA`, `FIXECAP` et `FIXEXY` acceptent des
décimaux : la position et le cap sont gardés au 1/256 près (de pas ou de degré), et le sinus,
lu dans une table au 1/65536, est interpolé entre deux degrés. `REPETE 7 [AV 30 DR 360 / 7]`
se referme, `DR 0.5` tourne d'un demi-degré. `XCOR`, `YCOR` et `CAP` rendent un entier quand
la tortue est sur un point entier, sinon un décimal arrondi à 2 décimales (`FIXECAP 30 AV 100`
donne `86.6` pour `YCOR`). Une position au-delà de -32768..32767 donne `Nombre trop grand`.

**Modifier ses procédures avec EDIT.** `EDITE "NOM` (menu Fichier, « Editer... ») enregistre
toutes les procédures dans `NOM.LOG` et ouvre ce fichier dans EDIT. Le menu Fichier d'EDIT
propose alors Retour : le fichier est enregistré s'il a changé, LOGO revient avec ses
variables, ses mots et listes, la tortue, le dessin et le mode d'écran, et recharge `NOM.LOG`
(les procédures sont celles du fichier). L'état de LOGO passe par le fichier `LOGO.$$$`,
effacé au retour. Un programme en cours s'arrête. On peut aussi lancer `LOGO NOM`, qui charge
`NOM.LOG` dès le démarrage. Le passage d'un programme à l'autre utilise la fonction 47 du
BDOS (voir « Appel du BDOS »).

**Écran texte.** Pour un programme qui n'écrit que du texte (calculs décimaux, mots et
listes), `ECRANTEXTE` (menu Tortue, « Ecran texte ») donne tout l'écran au texte : 26 lignes
au lieu de 10. L'image reste en mémoire : `ECRANMIXTE` la remet, avec la tortue là où elle
était. En écran texte, les commandes qui bougent la tortue ou touchent l'image (`AV`, `RE`,
`DR`, `GA`, `FIXECAP`, `FIXEXY`, `ORIGINE`, `VE`, `NETTOIE`, `SAUVEIMAGE`, `CHARGEIMAGE`)
donnent `Impossible en ecran texte : AV` ; `LC`, `BC`, `GOMME`, `INVERSE`, `CT`, `MT` restent
permises (elles servent au retour), et `XCOR`, `YCOR`, `CAP` répondent toujours. La place
pour les procédures et les textes ne change pas.

`-5` collé derrière un blanc est un nombre négatif (`FIXEXY -50 -30`), alors que `3 - 2` est
une soustraction. ESC interrompt un programme. La barre de menus (Fichier, Tortue, Aide) tape
les commandes à la place de l'utilisateur.

Les procédures sont enregistrées comme du texte (`POUR` ... `FIN`), qu'on peut modifier avec
`EDIT DEMO.LOG`. `CHARGE` exécute aussi les autres lignes du fichier. La disquette contient
`DEMO.LOG`, avec CARRE, POLY, ETOILE, FLEUR, SPIRALE, ARBRE (récursif) et DEMO :

    ? CHARGE "DEMO
    ? DEMO

Le Logo lit directement le texte des procédures. Les listes et les appels passent par une pile
de contextes en mémoire, pas par la pile du 6502. La récursion peut donc aller jusqu'à
120 niveaux, avec 100 paramètres actifs et 32 variables globales.

**Un grand programme par étapes.** Un fichier `.LOG` peut contenir n'importe quelles lignes
de Logo, pas seulement des procédures : `CHARGE` les exécute toutes, comme si on les tapait.
Et `OUBLIE "NOM` rend vraiment la place de la procédure. Un programme trop grand pour la
mémoire (un jeu d'aventure, par exemple) se découpe donc en étapes : un noyau chargé une fois,
puis, à chaque étape, le fichier de cette étape, oublié quand on la quitte. Les variables
globales passent d'une étape à l'autre. Exemple (essayé) : `NOYAU.LOG` contient

    POUR JEU
    DONNE "N 1
    REPETE 3 [ETAPE]
    ECRIS "FIN
    FIN
    POUR ETAPE
    CHARGE MOT "S :N
    SALLE
    OUBLIE "SALLE
    FIN

et `S1.LOG`, `S2.LOG`, `S3.LOG` définissent chacun une procédure `SALLE`, qui fait l'étape et
choisit la suivante (`DONNE "N 2`). On lance `LOGO NOYAU`, puis `JEU`. Le nom donné à
`CHARGE` (comme à `SAUVE`, `SAUVEIMAGE`, `CHARGEIMAGE` et `EDITE`) peut être calculé : `"S1`,
`:F`, `MOT "S :N`... Un fichier d'étape peut charger son image (`CHARGEIMAGE "SALLE1`). Deux
règles :

- Pas de `CHARGE`, de `SAUVE` ni d'`EDITE` pendant un `CHARGE` (dans le fichier chargé, ou
  dans une procédure qu'il appelle) : ils prendraient le fichier en cours de lecture. LOGO
  le refuse (`Interdit pendant CHARGE : CHARGE`) et revient au prompt. C'est le noyau qui
  enchaîne les chargements, une fois chaque fichier fini.
- C'est le noyau, chargé en premier et jamais oublié, qui charge et oublie les étapes. Oublier
  la procédure en cours, ou une procédure chargée avant elle, déplacerait en mémoire le texte
  qui est en train de s'exécuter.

Chaque valeur (variable, paramètre, résultat intermédiaire d'un calcul) est typée : un octet
de type et 5 octets de contenu : un entier, ou un décimal (bibliothèque `progs/fp_inc.s`,
réutilisable par d'autres programmes). Les mots et les listes viendront s'y ranger (voir
`docs/projet-disquette.md`).

## L'éditeur hexadécimal HEX

    A>HEX EDIT.COM

HEX affiche n'importe quel fichier en hexadécimal et en ASCII, 8 octets par ligne
sur 26 lignes, et permet de le modifier :

    0000 D8 A2 73 A9 E3 A0 16 20 ..s....

La ligne d'état donne le nom du fichier (`*` s'il est modifié), la position du curseur
et la taille du fichier (`$0125/$1700`), la valeur de l'octet courant en hexa et en décimal,
et le mode (`HEX`, `ASC`, ou `LECT` pour lecture seule). L'octet courant est en vidéo inverse
dans la zone où l'on tape.

| Touche | Action |
|---|---|
| Flèches | octet précédent / suivant, ligne précédente / suivante |
| RETURN, DEL | début de la ligne suivante, octet précédent |
| CTRL-R / CTRL-C | page précédente / suivante |
| CTRL-Q / CTRL-Z | début / fin du fichier |
| CTRL-A | aller à une adresse (en hexa) |
| CTRL-F / CTRL-G | chercher / suivant |
| CTRL-O | modifier en hexa ou en ASCII |
| CTRL-S | enregistrer |
| ESC | quitter (confirmation si le fichier est modifié) |
| FUNCT | menus Fichier (Enregistrer, Recharger, Quitter), Aller, Mode |

En mode HEX, on tape deux chiffres par octet (le premier remplace le demi-octet fort,
le second le faible, puis le curseur avance). En mode ASCII, chaque caractère tapé remplace
l'octet. La taille du fichier ne change jamais.

La recherche prend du texte (sans distinguer majuscules et minuscules) ou, après `#`, des
octets en hexa : `#20 03 02` ou `#200302`. Elle repart du début si besoin.

HEX lit le fichier en accès direct, par fenêtre de 32 Ko au plus : un fichier qui tient dans la
fenêtre est lu d'un coup, un plus gros est parcouru par morceaux, jusqu'à 64 Ko (au-delà, seul le
début est montré). `^S` réécrit sur place les seuls enregistrements modifiés ; quitter une
fenêtre modifiée pour une autre partie du fichier l'écrit aussi (message « Modifications
ecrites »). Lancé depuis le mode SPLIT, HEX garde l'image et la réaffiche en sortant. Comme sous
CP/M, la taille est un multiple de 128 octets : la fin d'un fichier texte montre donc les `^Z`
(`1A`) de remplissage. Un fichier protégé (R/O) se consulte mais ne s'enregistre pas.

## L'assembleur ASM

    A>EDIT PROG.ASM
    A>ASM PROG
    A>PROG

`ASM NOM` assemble `NOM.ASM` (ou `NOM.ext` si on donne le type) et écrit `NOM.COM`. On peut ainsi
écrire, assembler et lancer un programme sans quitter l'Oric. Exemple sur la disquette :

    A>ASM HELLO
    ASM CP/A 1.0
    Passe 1
    Passe 2
    HELLO.COM $0500-$0557 : 88 octets
    8 symboles (.SYM)

La syntaxe est celle de l'assembleur `xa` de l'OSDK, pour la partie dont les programmes CP/A ont
besoin : les mêmes sources s'assemblent sur l'Oric et sur le PC. Assemblés sur l'Oric, HELLO,
COPY, GTEST, HEX, EDIT, LOGO et ASM lui-même donnent exactement les mêmes octets qu'avec `xa`.

| Élément | Syntaxe |
|---|---|
| Étiquette | en colonne 1, sensible à la casse (`:` facultatif) |
| Constante | `NOM = expression` |
| Adresse | `*= $0500` (c'est aussi la valeur par défaut) |
| Données | `.byt` / `.byte` / `.asc` (nombres et chaînes `"..."`), `.word`, `.dsb n[,valeur]` |
| Blocs | `.(` ... `.)` : les étiquettes définies dedans sont locales au bloc |
| Inclusion | `#include "CPA.INC"` (un niveau) |
| Commentaire | `;` jusqu'à la fin de la ligne |

Expressions : nombres décimaux, `$hexa`, `%binaire`, caractères `"A"` ou `'A'`, `*` (adresse de
l'instruction), symboles, parenthèses, `+ - * / & | ^ << >>`, moins unaire, et `<` / `>` (octet
bas / haut) devant l'expression. Les mnémoniques s'écrivent en majuscules ou en minuscules ;
`ASL`, `LSR`, `ROL`, `ROR` acceptent `A` ou rien. Une adresse connue avant la ligne et inférieure
à 256 donne le mode page zéro.

Comme avec `xa`, un second `*=` ne laisse pas de trou dans le fichier : le code qui suit est mis
à la suite, assemblé pour la nouvelle adresse (DEBUG s'en sert pour se recopier en haut de la
mémoire). En plus de `NOM.COM`, ASM écrit `NOM.SYM`, la liste des symboles pour DEBUG.

Les erreurs sont listées avec le numéro de ligne, le message et le début de la ligne (le nom du
fichier inclus entre crochets s'il y a lieu). La liste fait une pause à chaque écran plein. S'il y
a une erreur, rien n'est écrit. ESC interrompt l'assemblage.

L'assembleur lit le source ligne à ligne sur le disque, en deux passes : la taille du source
n'est limitée que par la disquette. La table des symboles et le code produit se partagent la
mémoire libre (environ 37 Ko en mode texte). Une ligne peut faire environ 1000 caractères.
À titre d'exemple, LOGO (3 500 lignes, 66 Ko de source) s'assemble en un peu plus d'une minute.

## Le débogueur DEBUG

    A>ASM PROG
    A>DEBUG PROG [paramètres]

DEBUG charge `PROG.COM` en `$0500`, là où il tournera, et `PROG.SYM` s'il existe. Les
paramètres qui suivent le nom sont passés au programme. Le débogueur se place lui-même en
`$8400-$9FFF`, les symboles juste en dessous, et il abaisse d'autant le haut de la TPA
(variable `$020C`, plafond `$02A9`) : il reste environ 31 Ko au programme. Les programmes qui
respectent le haut de la TPA (EDIT, HEX, ASM, LOGO) fonctionnent donc sous le débogueur.

    PC=0504 A=00 X=03 Y=00 S=F9
    P=20  N V - B D I Z C
          0 0 1 0 0 0 0 0
    boucle:
    0504 20 0C 05  JSR double

| Commande | Effet |
|---|---|
| `R` | registres, avec le détail du registre d'état bit par bit |
| `R A=41`, `R PC=boucle`, `R S=F0`, `R C=1` | modifie un registre (A X Y P S PC) ou un indicateur (N V D I Z C) |
| `L [adr]` | désassemble 12 instructions, avec les étiquettes du source |
| `D [adr]` | mémoire en hexa et en ASCII |
| `M adr bb bb ...` | écrit des octets |
| `G [adr]` | exécute jusqu'à un point d'arrêt, la fin du programme ou le bouton RESET |
| `T [n]` | pas à pas (n instructions), en entrant dans les `JSR` |
| `P [n]` | pas à pas, chaque `JSR` exécuté d'un coup |
| `B [adr]`, `B- [adr]` | pose ou liste les points d'arrêt (8 au plus), en enlève un ou tous |
| `? expr` | valeur en hexa et en décimal, et le symbole le plus proche |
| `H`, `Q` | aide, retour au système |

Les adresses s'écrivent en hexa (`512`, `$512`), en décimal (`#1298`) ou avec un nom de symbole,
suivis éventuellement de `+` ou `-` : `L boucle+3`. Pour les noms, la casse ne compte pas. Les
symboles globaux passent avant les étiquettes locales des blocs `.( .)`. Le désassemblage
remplace les adresses par les noms (`STX cnt`, `JSR BDOS`, `LDA TAIL+1,Y`) et affiche les
étiquettes sur leur propre ligne. En pas à pas, chaque instruction donne une ligne de registres,
avec les indicateurs en lettres (majuscule = 1) : `A=00 X=03 Y=00 S=F7 nvdiZc`. ESC arrête une
série de pas.

Comment ça marche : le 6502 n'ayant pas de mode pas à pas, DEBUG pose un `BRK` provisoire sur
l'instruction suivante (sur les deux suites d'un branchement), et sur chaque point d'arrêt. Il
détourne les vecteurs en RAM : IRQ (pour reconnaître ses `BRK`), NMI (le bouton RESET arrête le
programme au lieu de redémarrer le système) et WBOOT (la fin du programme). Un `JSR` vers le
système (`JSR BDOS`, BIOS) est toujours exécuté d'un coup. Le débogueur garde la pile du
programme et travaille en dessous. Ses variables de page zéro (`$D0-$DF`) sont échangées avec
celles du programme à chaque arrêt.

## Écrire un programme .COM

Un `.COM` est du code assemblé pour `$0500`. Le CCP le charge à cette adresse et l'appelle par `JSR`. Un programme doit rester sous
le haut de la TPA, donné en `$020C` (`$B400` en mode texte, `$A000` en mode SPLIT).
Le programme rend la main par `RTS` ou `JMP $0200`.

Avant le lancement, le CCP prépare :
- en `$045C`, le FCB 1, rempli avec le 1er argument ;
- en `$046C`, le FCB 2 (16 octets), rempli avec le 2e argument ;
- en `$0480`, la ligne de paramètres : un octet de longueur puis les caractères, terminés par 0 ;
- le DMA, positionné sur `$0480`.

Les programmes ont pour eux la page zéro `$00-$DF`. Voir `progs/hello.s`, `progs/copy.s`
et `progs/edit.s`.

`progs/cpa.inc` rassemble l'interface publique :
- les points d'entrée du BDOS et du BIOS ;
- les numéros de fonctions ;
- les variables du curseur (`$0210-$0214`), qu'un programme plein écran peut piloter ;
- les constantes des menus.

Un programme qui installe sa propre barre de menus peut lui faire « taper » des codes `$81-$FF`.
Ces codes n'arrivent jamais du clavier, et le programme les reçoit par CONIN comme des touches
ordinaires. C'est ce que fait l'éditeur.

## Appel du BDOS

    X = numéro de fonction (registre C de CP/M)
    A/Y = paramètre, octet bas / octet haut (registre DE de CP/M)
    JSR $0203  -> résultat dans A

| N° | Fonction | N° | Fonction |
|---|---|---|---|
| 0 | démarrage à chaud | 15 | ouvrir (A=$FF si absent) |
| 1 | lire un caractère avec écho | 16 | fermer |
| 2 | écrire le caractère A | 17 / 18 | chercher premier / suivant (entrée de 32 octets copiée au DMA) |
| 5 | imprimer le caractère A (Centronics) | | |
| 6 | E/S directe (`$FF` lire, `$FE` état) | 19 | effacer (jokers) |
| 9 | chaîne terminée par `$` | 20 | lecture séquentielle (0 OK, 1 fin) |
| 10 | lire une ligne (format CP/M) | 21 | écriture séquentielle (0 OK, 1 répertoire plein, 2 disque plein) |
| 11 | état console | 22 | créer |
| 12 | version (`$22`) | 23 | renommer (nouveau nom en FCB+16) |
| | | 30 | attributs (bit 7 des octets 9 et 10 du FCB : R/O, SYS) |
| | | 33 / 34 | lecture / écriture directe de l'enregistrement R0-R1 (FCB+33) |
| | | 35 | taille du fichier en enregistrements -> R0-R1 |
| | | 36 | R0-R1 <- position séquentielle courante |
| 13 | réinitialiser les disques | 24 / 25 | lecteurs lus (bit 0 = A:) / lecteur courant (0 = A:) |
| 14 | lecteur courant <- A (0-3 ; `$FF` si absent) | 26 | adresse DMA (enregistrements de 128 octets) |
| | | 47 | CHAIN : A/Y = ligne de commande (0 à la fin) ; ne revient pas |

Le FCB a le format CP/M 2.2 sur 36 octets ; son octet 0 est le lecteur (0 = lecteur courant,
1 = A: ... 4 = D:). Un lecteur absent ou illisible fait échouer la fonction (`$FF`).

**Imprimante.** CP/A imprime sur le port Centronics de l'Oric (entrée LIST du BIOS, fonction
5 du BDOS : A = caractère). CTRL-P, tapé pendant la saisie d'une ligne (au prompt, dans LOGO,
DEBUG...), ou l'article Imprimante du menu Systeme, active ou coupe la copie à l'imprimante
de tout ce qui s'affiche, comme sous CP/M (voyant `P` au bout de la barre) :
CTRL-P puis `TYPE README.TXT` imprime le fichier. Pendant l'édition d'une ligne, seule la
ligne finale est imprimée (pas les retouches). Sans imprimante branchée, rien ne bloque :
l'attente de l'accusé de réception est limitée à 2 ms environ par caractère. Dans Oricutron,
ce qui est imprimé s'ajoute au fichier `printer_out.txt` de son dossier (imprimante activée
par défaut). EDIT, qui dessine son écran directement, n'est pas copié.

**Enchaîner deux programmes.** La fonction 47 (comme celle de CP/M 3) termine le programme
et fait exécuter une ligne par le CCP, comme si on l'avait tapée : elle s'affiche après `A>`
puis s'exécute, avant la ligne suivante d'un script DO en cours. Sous CP/M 3 la ligne est au
DMA ; ici elle est donnée par A/Y (78 caractères au plus). Exemple : LOGO lance
`EDIT NOM.LOG /L`, et EDIT revient par `LOGO NOM.LOG /R`.

**Accès direct.** Les fonctions 33 à 36 lisent et écrivent l'enregistrement de 128 octets dont
le numéro est en R0-R1 (octets 33 et 34 du FCB, R2 à 0), sans tout relire depuis le début.
Comme sous CP/M, la position courante n'avance pas : une lecture séquentielle reprend au même
enregistrement. Retours de la lecture : 0, 1 (enregistrement jamais écrit), 4 (extent
inexistant), 6 (hors limites). L'écriture peut créer un fichier à trous ; elle renvoie 2 si le
disque est plein, 5 si le répertoire est plein, `$FF` si le fichier est en lecture seule. La
fonction 35 donne la taille (nombre d'enregistrements, en tenant compte des trous).

## Table BIOS (adresses fixes)

`$C000` BOOT, `$C003` WBOOT, `$C006` CONST, `$C009` CONIN, `$C00C` CONOUT, `$C00F` LIST,
`$C012` PUNCH, `$C015` READER, `$C018` HOME, `$C01B` SELDSK (A = lecteur 0-3), `$C01E` SETTRK (sans effet),
`$C021` SETSEC (A/Y = n° de secteur logique), `$C024` SETDMA (tampon de 256 octets),
`$C027` READ, `$C02A` WRITE (A=0 OK), `$C02D` MENUBAR (A/Y = barre de menus).

## Carte mémoire (version disque)

| Zone | Usage |
|---|---|
| `$0000-$00DF` | page zéro libre pour les programmes |
| `$00E0-$00FF` | page zéro système |
| `$0200` / `$0203` | `JMP WBOOT` / `JMP BDOS` |
| `$0206` / `$0209` | vecteurs IRQ / NMI en RAM, détournables |
| `$0210-$02FF` | variables du système (console, clavier, menus, test RAM, graphisme, pagination `$02A3`, plafond de la TPA `$02A9`, édition de ligne) |
| `$0400-$04FF` | page de base : tampon de commande, FCB `$045C`/`$046C`, DMA `$0480` |
| `$0500-$B3FF` | TPA (44 800 octets) |
| `$B400-$B4FF` | (glyphes des codes 0-31, jamais affichés) adresses des lignes de points du mode SPLIT, calculées au démarrage |
| `$B500-$B7FF` | jeu de caractères |
| `$B800-$B9FF` | jeu alternatif (inutilisé en mode texte) : sauvegarde de l'écran sous les menus |
| `$BA00-$BA7F` | ligne en cours d'édition (BDOS 10) |
| `$BA80-$BB7F` | historique des lignes |
| `$BB80-$BFDF` | écran texte |
| `$C000-$F4xx` | CP/A (RAM overlay), environ 13,2 Ko |
| `$F670-$F7BF` | ligne de commande d'origine, script DO (FCB, enregistrement, paramètres) |
| `$F7C0-$FCFF` | PUT : sauvegarde d'état et tampon de 1 280 octets |
| `$FD00-$FEFF` | variables du BDOS (dont les cartes d'allocation des 4 lecteurs) et tampon de secteur |
| `$FF00-$FFF9` | CP/A : tables (lignes de l'écran, clavier) ; place pour de petites routines |

Il reste environ 260 octets libres dans la RAM overlay pour de futures fonctions résidentes : 192 entre la fin du code et `$F670`, 66 à la fin de la page `$FF00`.

## Format de la disquette

L'image est au format MFM_DISK : 2 faces × 42 pistes × 17 secteurs de 256 octets, soit 357 Ko.
Les secteurs sont adressés par numéro logique (LSN) : piste logique = LSN / 17, cylindre = piste / 2,
face = piste mod 2.

| LSN | Contenu |
|---|---|
| 0-2 | amorçage Microdisc (faux répertoire Oric DOS, chargeur) |
| 3-66 | système (16 Ko) |
| 68-1427 | 170 blocs de 2 Ko. Les blocs 0 et 1 forment le répertoire : 128 entrées au format CP/M 2.2 (EXM=1) |

Les écritures passent par un tampon en écriture différée. Il faut fermer un fichier (fonction 16)
pour que ses données et son entrée de répertoire soient à jour sur la disquette.

## Outils

`tools/mkdisk.py` crée et manipule les images depuis le PC :

    python3 tools/mkdisk.py ls  build/cpa.dsk
    python3 tools/mkdisk.py put build/cpa.dsk monprog.com
    python3 tools/mkdisk.py get build/cpa.dsk NOTES.TXT notes.txt
    python3 tools/mkdisk.py era build/cpa.dsk NOTES.TXT
    python3 tools/mkdisk.py attr build/cpa.dsk NOTES.TXT RO      # RO RW SYS DIR
    python3 tools/mkdisk.py new donnees.dsk [fichiers...]    # disquette de données (B: à D:)

Autres fichiers dans `tools/` :
- `gen_font.py` : police 6×8 originale ;
- `gen_tables.py` : tables écran et clavier ;
- `run_test.sh` et `screen.py` : tests automatiques dans Oricutron (`DSKB=`... pour monter les
  lecteurs B: à D:) ;
- `test_asm.sh` : non-régression d'ASM (chaque programme assemblé par ASM.COM doit être
  identique à sa version `xa`) ;
- `run_com.py` : exécute un `.COM` dans un 6502 simulé (module Python `py65`), avec un BDOS
  minimal sur un dossier du PC. C'est ce qui sert à comparer ASM avec `xa` :
  `python3 tools/run_com.py DOSSIER ASM.COM LOGO` ;
- `gen_readme_txt.py` : textes d'aide, à partir d'une seule liste : `files/readme.txt` (`README.TXT`
  sur la disquette) et `progs/help_tab.s` (les rubriques de `HELP.COM`), 37 colonnes au plus ;
- `gen_asm_tab.py` : table des mnémoniques et des opcodes de l'assembleur (`progs/asm_tab.s`) ;
- `oricutron-testhook.patch` : frappe simulée et dump mémoire pour ces tests ; avec la
  variable `ORIC_LOCI=dossier`, l'interface du LOCI simulée sur ce dossier, qui tient lieu de
  clé USB (`0:` est son sous-dossier `int`) : EXPORT, IMPORT et USBDIR marchent dans
  l'émulateur (`ORIC_LOCI=/tmp/cle DSK=build/cpa.dsk tools/run_test.sh ...`).

## Limites connues

- Quatre lecteurs (A: à D:), pas de zones utilisateur.
- COPY ne copie pas d'une disquette à l'autre avec un seul lecteur.
- Les interruptions sont coupées pendant un transfert de secteur. Une touche frappée pendant un accès
  disque peut donc être perdue.
- Essayé sur un Oric Atmos avec LOCI ; pas encore sur Cumulus ni sur un vrai Microdisc.
- Les commandes « tapées » par un menu passent par le tampon clavier (15 caractères au plus).

## Licence

CP/A est distribué sous licence MIT (voir `LICENSE`). Les images `build/cpa.dsk` et
`build/cpa.rom` sont fournies prêtes à l'emploi ; `./build.sh` les reconstruit.
