# CP/A — manuel

Mode d'emploi de la version disquette : commandes, programmes, programmation. GRAPHER et LOGO
ont leur propre référence (`docs/grapher.md`, `docs/logo.md`), CMDER aussi (`docs/cmder.md`).
Contrat d'interface (table BIOS, fonctions du BDOS, carte mémoire) : `docs/architecture.md`.
Sur l'Oric, `HELP` donne un résumé de chaque commande.

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
| `SPLIT`, `TEXT`, `GCLS` | mode SPLIT (image et texte), mode texte, effacement de l'image |
| `NOM [args]` | charge `NOM.COM` en `$0500` et l'exécute ; à défaut, exécute le script `NOM.BAT` (comme `DO NOM [args]`) |
| `VER`, `CLS` | version, effacement de l'écran |
| `PAPER n`, `INK n` | couleur du fond, de l'encre (0 noir, 1 rouge, 2 vert, 3 jaune, 4 bleu, 5 magenta, 6 cyan, 7 blanc) de toute la console ; la même couleur pour les deux est permise (texte caché) |
| `PAGE ON`, `PAGE OFF` | pause en fin d'écran, ou non (voir plus bas) |
| `B:` (`A:` à `D:`) | change de lecteur courant (version disquette) ; l'invite devient `B>` |

TYPE, ERA et REN sont des programmes (`.COM`), pour la place résidente. Les commandes de
dessin (`PLOT`, `LINE`, `BOX`, `FBOX`, `CIRCLE`, `GTEXT`, `ATTR`, `PEN`) sont dans
`GRAPHER.COM` (`docs/grapher.md`) ; la version ROM les garde au prompt. Un `.COM` se tape
comme une commande interne, y compris dans les scripts et après PUT ; il est cherché sur les
autres lecteurs s'il n'est pas sur le courant (voir « Lecteurs A: à D: »).

Commandes transitoires (fichiers `.COM` sur la disquette) qui complètent le CCP :

| Commande | Effet |
|---|---|
| `HELP [sujet]` | aide en français : commandes internes, puis `HELP EDIT`, `HELP HEX`, `HELP LOGO`, `HELP ASM`, `HELP DEBUG`, `HELP MEM` (carte mémoire), `HELP TOUCHES`, `HELP PROG`, `HELP CMDER` |
| `CMDER [d:][afn]` | gestionnaire de fichiers plein écran : liste triable et filtrable, marquage, Voir, Copier, Déplacer, Renommer, Effacer, Attributs ; copie avec un seul lecteur (`docs/cmder.md`) |
| `SET afn [RO\|RW\|SYS\|DIR]` | attributs des fichiers (sans option : les affiche) |
| `STAT [d:][afn]` | taille de chaque fichier : enregistrements de 128 octets, blocs de 2 Ko, octets, attributs (`R` protégé, `S` système) ; sans paramètre : place libre sur le disque |
| `MEM` | carte de la mémoire (taille de la TPA selon le mode texte ou SPLIT) |
| `POKE adr bb [bb...]` | écrit des octets en mémoire (hexadécimal, `$` facultatif) |
| `GO adr [paramètres]` | lance le code en `adr` comme un `.COM` (un `RTS` ramène au prompt) |
| `XDO NOM [p1 ... p9]` | appel d'un script par un script ; lancé par le CCP, pas à taper (voir DO) |

Dans la version disquette, `HELP`, `MEM`, `POKE` et `GO` sont des `.COM` et DEBUG remplace
`DUMP`, pour laisser la place au BDOS ; la version ROM, sans disque, les a en interne.

Autres programmes de la disquette :
- `HELLO.COM` affiche ses arguments ;
- `COPY.COM src [dst]` copie des fichiers (jokers admis), par gros blocs, à travers le BDOS.
- `EDIT.COM [fichier]`, l'éditeur de texte (plus bas).
- `GTEST.COM`, le test du mode SPLIT et des primitives graphiques.
- `LOGO.COM`, avec `DEMO.LOG`.
- `HEX.COM fichier`, l'éditeur hexadécimal décrit plus bas.
- `GRAPHER.COM NOM`, le petit langage de dessin des fichiers `.GRX` (exécuté), et
  `GRXASM.COM NOM` (ou `GRAPHER NOM /A`), qui le traduit en assembleur (en recopiant les routines utiles de `GRX.INC`, `HIRES.INC`...), avec ses exemples (`docs/grapher.md` § 14), et
  `VOIR.COM NOM`, qui affiche une image (`docs/grapher.md`, « HIRES plein écran »).
- `ASM.COM NOM`, l'assembleur 6502, avec les sources d'exemple `HELLO.ASM`, `GTEST.ASM`,
  `CPA.INC` et `HIRES.INC`.
- `DEBUG.COM NOM`, le moniteur, désassembleur et pas à pas.
- `STAT.COM`, `MEM.COM`, `POKE.COM`, `GO.COM`, `XDO.COM`, décrits ci-dessus.
- `EXPORT.COM`, `IMPORT.COM`, `USBDIR.COM` : échange de fichiers avec la clé USB du LOCI.
- `FORMAT.COM X: [/Q]` : formatage d'une disquette (voir « Lecteurs A: à D: »).
- `DISKCOPY.COM src: dst: [/T] [/V] [/S]` : copie d'une disquette, ou de son système.

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

**128 fichiers par disquette.** Le répertoire (la table des fichiers, que liste `DIR` ; ce
n'est pas un dossier : CP/A n'en a pas) a 128 entrées, une par fichier quelle que soit sa
taille jusqu'à 32 Ko (au-delà, une entrée de plus par tranche de 32 Ko). Une disquette contient
donc 128 fichiers au plus, même s'il reste de la place : EDIT, HEX, CMDER et GRAPHER répondent
alors `Repertoire plein`, et rien n'est écrit. Effacer des fichiers inutiles (`ERA`) ou passer
sur une autre disquette.

## Lecteurs A: à D:

Tout nom de fichier peut commencer par un lecteur : `DIR B:`, `TYPE B:LETTRE.TXT`,
`COPY LETTRE.TXT B:`, `ERA B:*.BAK`, `STAT B:`, `EDIT B:NOTES.TXT`, `ASM B:PROG` (le `.COM`
et le `.SYM` sur le lecteur de la source ; les `#include` y sont cherchés, puis sur A: à D:),
et dans LOGO `CHARGE "B:JEU`.
Sans lecteur, c'est le lecteur courant, choisi par `B:` au prompt ou par l'article **Lecteur
suivant** du menu Systeme (A, B, C, D, puis A). Un programme (`.COM`) ou un script
(`.BAT`, aussi par `DO`) tapé sans lecteur est cherché sur le lecteur courant, puis sur `A:`,
puis sur ceux des lecteurs `B:`, `C:` et `D:` déjà lus depuis la mise sous tension (`DIR B:`,
`B:`, une copie...) : depuis `B>`, `EDIT`, `LOGO` ou `STAT` se lancent depuis la disquette
système. Avec un vrai Microdisc, un lecteur vide ou absent coûte plusieurs secondes : une
commande inconnue (une faute de frappe) prendrait ~16 s si la recherche essayait les lecteurs
jamais lus ; elle répond donc en ~2 s. Une disquette qu'on vient d'insérer en `B:` se lit
d'abord (`DIR B:`), et ses programmes se trouvent ensuite. Avec le LOCI, qui dit quels
lecteurs ont une image, tous ceux-là sont cherchés, lus ou non. Dans un script, la recherche
commence par le lecteur du script : un script et ses programmes rangés sur une même
disquette se trouvent, quel que soit le lecteur où elle est (ensuite `A:`, puis les autres).
Un lecteur qui ne répond pas est ensuite sauté par cette recherche, jusqu'à ce qu'on le lise
de nouveau (`C:`, `DIR C:`...). Un nom tapé avec son lecteur (`C:PROG`) n'est cherché que là.
Limite : la fin d'un script qui en a appelé un autre est lue depuis `$$$.BAT`, écrit sur le lecteur
courant ; c'est alors ce lecteur qui passe en premier.

Chaque lecteur a la même organisation de disquette. Une disquette de données (sans système)
se prépare sur l'Oric avec `FORMAT B:`, ou sur le PC : `python3 tools/mkdisk.py new
donnees.dsk [fichiers...]` ; les pistes du système y restent inutilisées (336 Ko pour les
fichiers). Sur le LOCI, monter l'image sur le lecteur B, C ou D.

Sur le LOCI, un lecteur sans image est refusé d'emblée (`BDOS: disk I/O error` s'il est tapé,
rien pendant la recherche des programmes) : le contrôleur du LOCI ne termine jamais une
commande envoyée à un tel lecteur, et ne répond plus ensuite jusqu'à son redémarrage. CP/A
lit donc, avant de passer sur un autre lecteur, la liste des lecteurs montés que garde le
menu du LOCI. Une image montée ou éjectée se prend en compte au démarrage suivant depuis le
menu du LOCI.

**FORMAT.** `FORMAT B:` formate la disquette du lecteur B: au format de CP/A (2 faces,
42 pistes, 17 secteurs de 256 octets) : chaque piste est écrite d'un coup (commande Write
Track du contrôleur), puis relue ; la progression s'affiche (`Piste 12 face 1`), ESC
interrompt entre deux pistes. Une confirmation est demandée (`Tout B: sera efface. Suite
(O/N) ?`). `FORMAT A:` marche avec un seul lecteur : il demande d'insérer la disquette à
formater, puis de remettre la disquette système (le système reste en mémoire). `FORMAT B: /Q`
vide seulement le répertoire d'une disquette déjà formatée : c'est instantané, et cela suffit
pour une image du LOCI ou d'Oricutron. Les secteurs sont entrelacés (1, 10, 2, 11...) pour
qu'un vrai lecteur Microdisc lise une piste en deux tours au lieu de dix-sept ; les images
faites par `mkdisk.py` (`build/*.dsk`) le sont de même. Mesuré dans Clock Signal, qui simule
la rotation : copier LOGO.COM prend ~12 s au lieu de ~50 s, et le démarrage ~7 s au lieu
de ~9 s. Cela ne change rien sur le LOCI ni dans Oricutron.

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
COPY respecte le haut de la TPA (il marche aussi en mode SPLIT). Avec un seul lecteur, pour
copier d'une disquette à l'autre : CMDER.

**CMDER** (comme « commander ») montre les fichiers d'une disquette en plein écran et agit
dessus : `CMDER`, `CMDER B:`, `CMDER B:*.COM` (lecteur et filtre). Chaque ligne donne le nom,
le type, la taille en octets, `R` (protégé) et `S` (système), le rang dans le répertoire (`N`,
l'ordre de DIR) et un genre (Prog, Source, Texte, Image...) ; en bas, le fichier sous le
curseur ou le total des fichiers marqués. Flèches haut et bas : fichier ; gauche et droite :
page ; `<` `>` : premier, dernier ; une lettre : fichier suivant qui commence par elle.
`ESPACE` marque, `+` / `-` marquent ou démarquent selon un modèle, `*` inverse ; `1` à `4`
trient par ordre disque, nom, type, taille (la même touche inverse l'ordre) ; `/` filtre
(`B:*.TXT` change aussi de lecteur). Les opérations portent sur les fichiers marqués, ou sur
celui du curseur : RETURN les montre (texte, par pages), `^C` copie, `^X` déplace, `^N`
renomme, DEL efface (après confirmation), `^A` change les attributs, `?` donne la taille
exacte du fichier et `^E` celle de tous (règle de STAT), `^L` change de lecteur, `^R` relit
(disquette changée), ESC ou `^Q` quitte. Les mêmes actions sont dans les menus (FUNCT) Fichier,
Marque, Trier et Vue. Une copie garde les attributs de l'original ; un fichier déjà présent
est remplacé après accord (`O/N/T`, T pour tous), un fichier protégé de la destination est
laissé ; disque plein : la copie commencée est effacée.

Les titres des colonnes et les deux lignes d'état sont en couleur (cyan, bleu) ; la liste
et la ligne d'aide gardent les couleurs choisies par PAPER et INK. En colonne 39, un
ascenseur montre la partie visible de la liste. Une erreur disque s'affiche en ligne 26
(`Erreur disque : verifiez la disquette`) au lieu du message du BDOS au milieu de l'écran.

**Deux colonnes** : `CMDER A: B:` (un filtre par lecteur : `CMDER A:*.COM B:`) montre deux
disquettes côte à côte (nom, type, taille en Ko) ; l'en-tête de la colonne active est en vidéo
inverse. TAB passe à l'autre colonne, `^W` échange leurs places, `^Z` met la colonne active
en plein écran (et revient). Copier propose le lecteur de l'autre colonne (RETURN suffit) et
vérifie d'abord la place (`Libre 14K, requis 18K : O/N ?`). Menu Vue, « Absents autre » : la
colonne ne montre que les fichiers absents de l'autre, ou présents avec une autre taille ou
d'autres attributs (`#` dans l'en-tête) ; avec « Tout » puis `^C`, on recopie ce qui manque.
Menu Fichier, « Imprimer liste » : la liste de la colonne active sur l'imprimante.

**Clé USB du LOCI** : `CMDER USB:` (ou `CMDER USB:/JEUX`, `CMDER A: USB:`) montre le
répertoire courant de la clé (`USB:JEUX/`) : dossiers d'abord (`<REP>`), noms longs (en entier
jusqu'à 26 caractères en plein écran). RETURN entre dans un dossier, ou remonte sur `..` ; sur
un fichier, il le montre. La clé est une passerelle : on y copie (Copier vers `USB:`, ou vers
la colonne de la clé) et on en copie, mais on n'y efface ni ne renomme rien. Depuis la clé, un
nom long est ramené en 8 + 3 (comme IMPORT) ; `/T` à la fin de la réponse (ou menu « Copier
texte... ») change un LF seul en CR LF et une tabulation en un espace. Vers la clé, les `^Z` de fin sont retirés (comme
EXPORT) et un `.DSK` est refusé.

Copier vers le lecteur de la liste sans changer de nom (`A:` quand la liste est celle de A:)
veut dire **un seul lecteur** : CMDER lit autant de fichiers que la mémoire en tient (~33 Ko),
demande `DESTINATION en A:, une touche`, écrit, puis `SOURCE en A:` pour la suite, et ainsi de
suite. Avant d'écrire, il vérifie une empreinte du répertoire de chaque disquette et refuse la
mauvaise (`Non ! DESTINATION en A:...`) ; un gros fichier est fermé avant chaque échange, puis
repris. Une disquette au même répertoire que la source (copie de la source,
ancienne version) est acceptée après `Comme la source : continuer (O/N) ?` ; il faut alors
veiller soi-même à remettre la bonne. À la fin d'une copie, `SOURCE en A: (ESC : rester)` :
ESC laisse la destination dans le lecteur et la liste la montre. ESC à une autre demande
arrête tout. Déplacer avec un seul lecteur efface les originaux
quand la source revient.

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
ASM...), README.TXT, CPA.INC, HIRES.INC, GRX.INC, ANIM.INC, ARR.INC, FIL.INC et SPR.INC sont **protégées** (R/O) et restent **visibles** dans DIR,
comme sur une disquette CP/M : un `ERA *.*` ou un nom complété par ESC ne peut plus les
effacer. Pour remplacer une commande par une nouvelle version : `SET COPY.COM RW`, puis la
copier. Les exemples (HELLO, GTEST et leurs `.ASM`, DEMO.LOG, les `.GRX`, HEROS.SPR, TUILES.SPR) restent
modifiables : `ASM HELLO` réécrit HELLO.COM. Aucun fichier n'est caché (SYS) : l'attribut
reste à la disposition de l'utilisateur.

SYS ne change pas le nom : `HELP.COM` marqué SYS reste `HELP.COM` et se lance toujours
(un fichier renommé `.SYS` ne serait plus une commande : le CCP ne lance que `.COM` et `.BAT`).

**Disquettes par usage.** `build.sh` fabrique aussi quatre disquettes amorçables, plus légères
à l'affichage. Sur chacune, les commandes de base (TYPE, ERA, REN, SET, STAT, COPY, HELP,
FORMAT, DISKCOPY, XDO, EXPORT, IMPORT, USBDIR, VOIR, CMDER) sont protégées et **cachées** (SYS) : `DIR`
ne montre que l'outil de la disquette et les fichiers de travail, `DIRS` montre tout. EDIT
y est partout, protégé et visible.

| Image | Visibles (protégés) | En plus, cachés | Exemples modifiables |
|---|---|---|---|
| `build/cpa-logo.dsk` | EDIT, LOGO, GRAPHER | | DEMO.LOG, ELIZA.LOG, ELIZA2.LOG, TRACARRE.LOG, TRASINUS.LOG, TRASINXX.LOG, DESSIN.GRX, ECRAN.GRX, MOTIFS.GRX, ARDOISE.GRX, FLECHES.GRX, FLECHES.LOG, SERPENT.GRX, SCORES.GRX, SPRITES.GRX, HEROS.SPR, CARTE.GRX, TUILES.SPR, DEFILE.GRX |
| `build/cpa-notes.dsk` | EDIT | | |
| `build/cpa-asm.dsk` | EDIT, ASM, DEBUG, HEX, GRAPHER, GRXASM, CPA.INC, HIRES.INC, GRX.INC, ANIM.INC, ARR.INC, FIL.INC, SPR.INC | MEM, POKE, GO | HELLO, GTEST (`.ASM`, `.COM`) |
| `build/cpa-anim.dsk` | EDIT, VOIR, VSYNC, GRAPHER, GRXASM, ASM | CPA.INC, HIRES.INC, GRX.INC, ANIM.INC, ARR.INC, FIL.INC, SPR.INC | CUBE.ANI, BALLE.ANI, VAISSEAU.ANI, LOGO.HIZ, ANIMS.GRX, DEMO.BAT |

Sur `cpa-anim.dsk`, `DEMO` (le script `DEMO.BAT`) enchaîne l'image compressée, les trois
animations dans VOIR, puis `GRAPHER ANIMS` (une touche entre deux).

**Disquette anglaise.** `build/cpa-en.dsk` a le contenu de `cpa.dsk`, avec les messages
des programmes en anglais (traduction en cours : les commandes, EDIT, HEX, ASM et DEBUG ; la
touche « oui » y est `Y`, et « tous » `A` dans les remplacements d'EDIT) et un `EDIT.CFG`
commenté en anglais.

**Disquette de projet.** `build/cpa-projet.dsk` est une disquette vierge (sans système, 336 Ko
pour les fichiers), à mettre en `B:` et à copier pour chaque projet.

Usage conseillé : la disquette système en `A:` (`cpa.dsk`, ou une disquette d'usage), une
disquette de projet en `B:`, et `B:` comme lecteur courant. Depuis `B>`, `EDIT`, `LOGO`,
`ASM`, `GRAPHER` ou `GRXASM` sont trouvés sur `A:`, ainsi que les bibliothèques (`CPA.INC`,
`HIRES.INC`, `GRX.INC`...) qu'ASM et GRXASM cherchent sur le lecteur du projet puis sur A: à
D: ; tout ce qui est produit (`.ASM`, `.COM`, `.SYM`, fichiers de données) va sur `B:`, et
`DIR` ne montre que le travail en cours. `build/cpa.dsk` reste la disquette complète, tout
visible, et la démonstration ; il y reste environ 78 Ko, peu pour travailler (une traduction
par GRXASM écrit vite plus de 40 Ko).

Touches : CTRL-T bascule les majuscules (voyant `A`, ou `a` pour les minuscules, au bout de
la barre de menus), CTRL-C sur une ligne vide du prompt fait un démarrage à
chaud. Le bouton RESET revient au CCP.

**Les mêmes touches partout.** L'Oric n'a ni TAB, ni Début, ni Fin, ni pages : le système
les remplace par des combinaisons, que EDIT, HEX, CMDER et la ligne de commande
comprennent de la même façon.

| Touche | Effet |
|---|---|
| SHIFT-← / SHIFT-→ | début / fin de la ligne |
| SHIFT-↑ / SHIFT-↓ | page précédente / suivante |
| CTRL-↑ / CTRL-↓ | début / fin du texte (du fichier, de la liste) |
| CTRL-← / CTRL-→ | mot précédent / suivant (EDIT) |
| CTRL-I | TAB : compléter un nom, changer de zone ou de colonne (EDIT : insérer un fichier) |
| CTRL-ESPACE | marquer un bout du bloc (EDIT) ; ESC ôte la marque |
| CTRL-X / CTRL-C / CTRL-V | couper / copier / coller (CMDER : déplacer / copier) |
| CTRL-F / CTRL-G | chercher / suivant |
| CTRL-S / CTRL-Q | enregistrer / quitter |

CTRL-H, CTRL-I, CTRL-J et CTRL-K sont des touches à part, distinctes des flèches. CTRL avec
un chiffre ou un signe ne donne rien.

**Édition de la ligne, historique, complétion.** Au prompt `A>` comme dans les programmes qui
lisent une ligne par le BDOS (fonction 10 : LOGO, DEBUG…) :

| Touche | Effet |
|---|---|
| ← / → | déplacer le curseur dans la ligne ; ce qu'on tape s'insère |
| ↑ / ↓ | lignes déjà validées (historique), de la plus récente à la plus ancienne |
| TAB (CTRL-I) ou ESC | compléter le nom de fichier qui se termine au curseur ; en début de ligne, la commande |
| DEL / CTRL-D | effacer à gauche / sous le curseur |
| SHIFT-← / SHIFT-→, CTRL-A / CTRL-E | début / fin de la ligne |
| CTRL-U | effacer toute la ligne |
| CTRL-C | sur une ligne vide du prompt `A>` : démarrage à chaud (sans effet dans un programme) |
| CTRL-P | imprimante : copier tout ce qui s'affiche, oui / non (voyant `P` ; voir plus bas) |

L'historique garde les dernières lignes (256 octets, une vingtaine de commandes courtes) ; il
survit au démarrage à chaud, et une ligne identique à la précédente n'y entre pas deux fois.

La complétion s'inspire du `filec` du C-shell, qui complétait déjà par ESC — touche placée sur
l'Oric à l'endroit de la touche TAB d'un clavier de PC ; TAB (CTRL-I) fait de même, comme
dans les shells d'aujourd'hui. `TYPE REA` + ESC donne
`TYPE README.TXT ` (avec l'espace, prêt pour la suite). Si plusieurs fichiers conviennent, ESC
ajoute la partie commune (`DIR HELL` → `DIR HELLO.`) ; si rien ne peut être ajouté, ESC
affiche les noms possibles et réécrit la ligne en dessous. Sans majuscules (CTRL-T), le nom
est complété en minuscules. Un mot vide + ESC montre tout le disque.

**Premier mot : les commandes.** En début de ligne, ESC complète une commande : les
commandes internes (`DIRS` après `DIR` + ESC) et les programmes `.COM` et `.BAT`, sans leur
type (`ED` → `EDIT `, `GR` → `GRAPHER `). Les programmes sont cherchés sur les mêmes lecteurs
que quand on lance une commande : le lecteur courant, puis les autres (sans LOCI, ceux déjà
lus depuis la mise en route, par `DIR B:` par exemple) ; un programme présent sur deux
lecteurs n'est proposé qu'une fois. `D` + ESC montre `DEBUG DISKCOPY DIR DIRS DO`. Les autres
fichiers ne sont pas proposés en début de ligne. Cette complétion coûte environ 250 octets
dans le système ; elle est assemblée avec l'option `CPLCMD`, et
`DISK_OPTS="" ./build.sh` construit un système sans elle (la complétion des noms de fichiers
reste).

**Pause en fin d'écran.** Quand une commande remplit la console (27 lignes en mode texte,
10 en mode SPLIT) sans que l'utilisateur ait touché le clavier, l'affichage s'arrête sur
` -- Suite (^C stop) -- `. Une touche continue, CTRL-C abandonne et revient au
prompt. Cela vaut pour `HELP`, `TYPE`, `DIR`, `DUMP`… et pour les programmes qui affichent par
le BDOS ou le BIOS. `PAGE OFF` (ou l'article Pagination du menu Ecran, qui bascule) supprime
la pause, `PAGE ON` la remet ; le réglage reste jusqu'au démarrage à froid. Un programme qui ne
veut pas de pause met `$02A3` à 0 (variable publique, remise à 1 au démarrage à froid).

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
en fin d'écran repart à zéro à chaque ligne du script. Exemple :

    ; IMAGES.BAT : montre deux images, puis dessine
    VOIR TITRE
    VOIR CARTE
    GRAPHER DESSIN $1
    ECHO Fini.

    A>DO IMAGES Bonjour

`ECHO` et les paramètres de DO gardent les minuscules telles qu'elles sont tapées
(le reste de la ligne de commande passe en majuscules).

**Limites des scripts.** Un script n'est qu'une suite de commandes, comme tapées au clavier :
il n'y a ni calcul, ni variable, ni condition, ni boucle. `$1` à `$9` sont remplacés par le
texte des paramètres, sans rien évaluer : `($1+4)` devient `(10+4)`, que les commandes ne
comprennent pas. Un script qui s'appelle lui-même ne s'arrête jamais de lui-même (il n'y a pas
de condition pour sortir) : seul ESC l'arrête. Exemple qui ne marche pas :

    ; SCRIPT.BAT : trait en $1, puis le suivant 4 points plus loin ?
    GRAPHER TRAIT $1
    SCRIPT ($1+4)

(`TRAIT.GRX` contient `SPLIT` puis `LINE $1 100 $1 110`.) La première ligne trace bien le
trait en 10, mais la deuxième passe `(10+4)` tel quel. Au niveau suivant, GRAPHER refuse
`LINE (10+4) 100 (10+4) 110` (`parametres ?`) ; le script se rappelle ensuite sans fin avec un
paramètre de plus en plus long, jusqu'à ESC. Pour calculer, répéter ou décider,
il faut un programme : LOGO (`REPETE`, variables, `SI`) ou un `.COM`.

**L'alternative : confier le calcul à LOGO, depuis le script.** Le script garde ce qu'il fait
bien (enchaîner des commandes et des programmes) et LOGO fait le reste. Deux propriétés le
permettent : `LOGO NOM` charge `NOM.LOG` au démarrage et `CHARGE` exécute les lignes du fichier
qui ne sont pas des procédures, donc un programme peut se lancer seul et finir par `QUITTE` ;
et en sortant de LOGO, l'image reste intacte, en mode SPLIT : le script continue sur le même
dessin, et GRAPHER, lancé en mode SPLIT, dessine par-dessus sans l'effacer. Exemple :

    ; PELOUSE.BAT (CERCLE.GRX : SPLIT puis CIRCLE 120 30 20 ;
    ; MOT.GRX : GTEXT 2 114 $1 $2)
    GRAPHER CERCLE
    LOGO HERBE
    GRAPHER MOT Pelouse finie

    POUR HERBE :N
    REPETE :N [AV 10 RE 10 LC DR 90 AV 4 GA 90 BC]
    FIN
    LC FIXEXY -110 -40 BC
    HERBE 50
    QUITTE

(la seconde partie est `HERBE.LOG`). Le cercle tracé par GRAPHER, les 50 brins tracés par LOGO
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
| `IMPORT nom [fic] [/T]` | copie le fichier `nom` de la clé dans CP/A, sous le nom `fic` (par défaut, le nom de la clé sans son chemin, coupé à 8 + 3 caractères ; `B:` seul : ce nom-là sur le lecteur B:) ; `/T` : texte, un LF seul (fin de ligne du Mac, de Linux) devient CR LF et une tabulation (que l'Oric n'a pas) un espace — indispensable pour un `.LOG` écrit sur le Mac, que `CHARGE` de LOGO ne lit qu'en CR LF |
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
`ORIC_LOCI=dossier` (voir « Outils »), ou la ligne `loci = '~/Oric/loci'` dans `oricutron.cfg`
(le dossier doit exister, avec son sous-dossier `int` pour `0:`).

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

## Menus déroulants

La ligne d'état sert de barre de menus : **Systeme** (Version, Aide, Memoire, Imprimante,
Lecteur suivant, Redemarrer), **Fichiers** (version disque seulement),
**Ecran** (Mode SPLIT, Mode texte, Effacer, Encre, Papier, Majuscules, Pagination) et
**Clavier**. Encre et Papier passent à la couleur suivante (jamais la même pour les deux) ;
dans les scripts, `INK n` et `PAPER n` font de même avec une couleur choisie. Au bout
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

Le HIRES plein écran (240 × 200) n'est pas un mode du système : les programmes le prennent
en main avec la bibliothèque `hires.inc` (voir « HIRES plein écran »), comme `GRAPHER` et `VOIR`.

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

**Sans programme**, on dessine avec `GRAPHER` et un fichier `.GRX` (`docs/grapher.md`), et
`GSAVE` garde le résultat. La version ROM garde au prompt une commande par primitive (`PEN m`,
`PLOT x y`, `LINE x1 y1 x2 y2`, `BOX`, `FBOX`, `CIRCLE x y r`, `GTEXT col y texte`,
`ATTR col y1 y2 v`, `POINT x y`), en mode SPLIT seulement. Le crayon est en mode « trace » au
démarrage.

Hors du mode SPLIT, les primitives 0 à 9 renvoient `$FF`. `GTEST.COM` est un exemple
complet : il passe en SPLIT et dessine un cadre, des diagonales, des cercles, des
rectangles et du texte.

## HIRES plein écran : VOIR, hires.inc, png2hir.py, animations

Le HIRES plein écran (240 × 200 points, `$A000-$BF3F`) recouvre la police (`$B400`) et l'écran
texte (`$BB80`) : le système ne peut plus rien y afficher. Ce n'est donc pas un mode du système
mais une règle : **le programme prend l'écran pour lui**, et rend la main proprement.

- `VOIR NOM` affiche `NOM.HIR` en plein écran, `VOIR NOM.HIZ` la même image compressée, ou
  `VOIR NOM.IMG` une image du mode SPLIT, et revient au texte à la première touche.
- `VOIR NOM.ANI [n]` joue une animation plein écran n fois (0 ou rien : jusqu'à une touche) ;
  `ANIM NOM [n]` fait de même dans GRAPHER (interprété, ou traduit par GRXASM). Voir
  « Animations » plus bas.
- Une image `.HIR` est la copie brute de l'écran : 8 000 octets, le format usuel sur Oric.
  `GSAVE` dans GRAPHER en écrit ; `tools/png2hir.py image.png NOM.HIR` en fabrique une sur le
  Mac à partir d'une image quelconque (mise à l'échelle, noir et blanc tramé ; `--split` pour
  une image `.IMG` de 240 × 128 ; module Pillow), qu'on copie ensuite avec `IMPORT` ou
  `tools/mkdisk.py put`.
- `progs/hires.inc` (`HIRES.INC` sur les disquettes) est la bibliothèque qu'un programme inclut
  (`#include "HIRES.INC"`, avec xa sur le Mac ou ASM sur l'Oric) : `h_full` (plein écran),
  `h_split`, `h_text`, `h_cls`, `h_pen`, `h_plot`, `h_line`, `h_box`, `h_fbox`, `h_circle`,
  `h_print` (texte), `h_attr`, `h_point`, `h_load`, `h_save`, `h_key` ; pour l'écran texte
  (LORES) : `h_lores`, `h_lcls`, `h_loc`, `h_chr`, `h_scrn`, `h_lput`, `h_lstr`, `h_lspc`,
  `h_ltab`, `h_lnl` (curseur d'écriture `h_lx`, `h_ly`). Les paramètres sont dans
  `h_x1`, `h_y1`, `h_x2`, `h_y2`, `h_r` ; elle utilise `$C0-$C7` en page zéro et place ses
  tables (2 Ko) après la fin du programme (`h_free` : première adresse libre). Les mêmes
  routines marchent en SPLIT (128 lignes). Voir `progs/voir.s` pour un exemple court.

Pendant le HIRES plein écran, le programme n'écrit pas sur la console (fonctions 2, 9... du
BDOS) avant `h_text`. Le système, lui, n'y dessine plus rien de lui-même : la touche FUNCT est
ignorée (pas de menus), les voyants ne sont pas redessinés et le curseur est éteint. Il le
reconnaît à l'attribut `$1E` dans la dernière case de l'écran (`$BFDF`) hors du mode SPLIT. Et
si le programme se termine sans `h_text` (CTRL-C, plantage, oubli), le démarrage à chaud remet
le mode texte, la police et un écran propre. L'écran texte au programme (LORES, `h_lores`)
suit la même règle ; le système le reconnaît à la variable publique `SCR_PROG` (`$020E`) à 1,
que `h_lores` pose et que `h_text` et le démarrage à chaud remettent à 0.

### Images compressées et animations

**Compression.** Une image `.HIZ` est compressée en LZSS (le compresseur d'un ancien projet
OSDK de Pierre, gardé dans `archives/lzss-osdk/`) : environ 1,1 à 1,4 Ko pour un dessin au
trait, 4 à 8 Ko pour une image tramée, au lieu de 8 000 octets. `h_load` la reconnaît à son
type, la charge en mémoire libre (`h_zbuf`, après le programme) et la décompresse par
`h_unz`. Fabrication : `tools/png2hir.py image.png NOM.HIZ --hiz` (ou `tools/lzhir.py c
NOM.HIR NOM.HIZ`).

**Animations.** Une animation `.ANI` est une suite d'images où chacune ne décrit que ce qui
change depuis la précédente. Le format du flux reste celui du compresseur d'origine : une
copie de distance 0 recopie l'octet sur lui-même (il est **gardé**), une distance
« négative » prend l'octet plus loin, encore de l'image précédente. `h_unz` traite le saut
sans rien copier, ce qui fait la vitesse. Mesures (6502 simulé, cycle près) : environ
52 cycles par octet littéral, 18 par octet copié, ~105 par zone gardée quelle que soit sa
longueur ; en pratique, **environ 200 octets changés par 1/50 s**.

| Démo (`cpa-anim.dsk`) | Taille | Décodage | Cadence |
|---|---|---|---|
| `CUBE.ANI` : cube au trait, 12 images (un quart de tour boucle) | 18,3 Ko | ~65 000 cycles | 10 images/s |
| `BALLE.ANI` : ballon devant une image tramée, 30 images | 21,2 Ko | ~21 000 cycles | 25 images/s |
| `VAISSEAU.ANI` : GIF animé passé par `mkanim.py`, 24 images | 12,5 Ko | ~21 000 cycles | 12,5 images/s |

- Fabrication sur le Mac : `tools/mkanim.py FILM.ANI anim.gif [--seuil 128] [--delai N]
  [--apercu voir.gif]` (ou une suite de PNG) ; le bilan donne la taille, le décodage estimé
  (à 1 % près) et la cadence obtenue. `--seuil` est conseillé : le tramage change tout l'écran
  d'une image à l'autre, et une vidéo tramée plein écran ne dépasse pas 2 à 3 images/s.
  `--longue` donne un fichier plus petit mais plus lent. Les démos : `tools/anim_demos.py`.
- L'animation entière est chargée en mémoire : ~34 Ko dans VOIR, ~25 Ko dans GRAPHER (après le
  texte du `.GRX`). La 1re image est dessinée sur un écran effacé ; la dernière est suivie
  d'une image de retour vers la 1re, pour boucler sans tout redessiner.
- Cadence : chaque image a son délai (1/50 s) et part au top 50 Hz qui suit ; si le décodage
  déborde, l'image attend le top suivant, sans dérive.
- **Déchirure.** L'Oric n'a qu'un écran : une image se dessine pendant que le faisceau balaie.
  Le timer de l'IRQ du système tourne à 19 968 cycles, une trame vidéo exacte (top à 50,08 Hz),
  et n'est relancé qu'au démarrage à froid : le top tombe toujours à la même ligne du balayage,
  et la ligne de déchirure ne bouge pas. Les **flèches gauche et droite** la déplacent de
  8 lignes ; on la met là où rien ne change. Ce réglage tient jusqu'au prochain démarrage.
- **VSYNC** cale le top sur la fin de l'image, comme le réglage du début d'Oricium (l'Oric n'a
  pas de signal de synchronisation que le programme puisse lire). Un texte caché au milieu de
  l'écran n'est rendu visible que pendant 8 lignes de balayage, à un instant fixe après le
  top ; les flèches décalent le top (gauche / droite : 1 ligne, haut / bas : 8 lignes) jusqu'à
  voir le texte en entier et immobile, RETURN garde le réglage (ESC l'annule). Une image se
  décode alors juste après que le faisceau a quitté l'image, et ne se déchire pas si elle tient
  dans le temps où il revient : environ 7 000 cycles, plus 64 par ligne en descendant (une
  petite figure qui bouge). Les démos changent trop de points par image (10 000 à 75 000
  cycles) : la déchirure y reste, à un endroit fixe. À faire une fois après l'allumage ; à
  essayer sur un vrai Oric.
- Dans un programme : `#include "ANIM.INC"` **avant** `HIRES.INC` (qui reste à la fin), puis
  `a_play` (A/Y = FCB, X = passages ; C=1 si erreur, `a_msg` donne le message). GRXASM
  n'inclut `ANIM.INC` que si le programme se sert d'ANIM.

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
`docs/logo.md`).

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

## L'éditeur de texte EDIT

    A>EDIT LETTRE.TXT

C'est un éditeur plein écran : 26 lignes de 38 colonnes, avec une barre de menus et une ligne
d'état (nom du fichier, `*` si le texte est modifié, paragraphe `L`, position `C` du curseur
dans le paragraphe, `INS`/`RFP`, `M` si une marque est posée). Le texte peut atteindre
32 000 octets (environ 27 Ko lancé depuis le mode SPLIT). Un fichier plus long s'ouvre
**tronqué** (`Fichier tronque : trop gros`) ; il ne peut pas être enregistré sous son nom
(`Texte tronque : Enreg. sous...`), ce qui en perdrait la fin, mais peut l'être sous un autre.
Un long programme en assembleur s'écrit donc en modules de moins de 32 000 octets, réunis
par `#include` (voir ASM) ; TYPE et ASM, eux, lisent un fichier de toute taille.

Trois modes d'affichage (menu Options, ou CTRL-W qui passe au suivant) :

- **Coupure mots** (par défaut) : un paragraphe trop long continue sur les lignes suivantes,
  coupé entre les mots ;
- **Coupure 38 car** : coupé tous les 38 caractères ;
- **Ligne** : un paragraphe par ligne d'écran ; la fenêtre défile en largeur (de 10 en 10
  colonnes) pour suivre le curseur, et toutes les lignes avec elle. La ligne d'état montre
  `<` quand la fenêtre est décalée et `>` quand le paragraphe continue à droite. Au-delà de
  240 caractères, le paragraphe continue sur la ligne suivante. C'est le mode du code (`.ASM`,
  `.GRX`, `.LOG`, `.BAT`) et des cartes de GRAPHER écrites en clair, plus larges que l'écran.

Un paragraphe d'EDIT n'a pas de limite de longueur, mais les programmes qui lisent le fichier
en ont une : LOGO lit 126 caractères par ligne, un script `.BAT` 78. Le fichier **`EDIT.CFG`**
donne, pour chaque fichier, la longueur maxi d'un paragraphe, la coupure à l'écran et la
largeur de l'imprimante :

    ; nom    maxi coupure imprimante
    LETTRE.TXT 0   MOTS  96
    *.LOG    126  LIGNE 80
    *.BAT    78   LIGNE 80
    *.*      0    MOTS  80

La première ligne dont le nom correspond s'applique (jokers `*` et `?`, lecteur facultatif :
`B:*.TXT`) ; on met donc les fichiers particuliers en tête. Coupure : `MOTS`, `CAR` ou `LIGNE`
(le mode de départ ; on en change pendant l'édition) ; seule la première lettre compte, et
`WORDS`, `CHAR`, `LINE` (ceux de l'`EDIT.CFG` de `cpa-en.dsk`) valent aussi. Les colonnes absentes gardent leur
valeur par défaut (sans limite, `MOTS`, 80) ; `;` commence un commentaire. EDIT cherche
`EDIT.CFG` sur le lecteur du document, puis sur `A:`, à chaque ouverture et à chaque
« Enreg. sous... ». Sans `EDIT.CFG`, il garde 126 pour `*.LOG` et 78 pour `*.BAT`. Les
disquettes livrées l'ont, modifiable (`EDIT EDIT.CFG`) ; il est caché (SYS) sur les disquettes
par usage.

Quand le paragraphe du curseur dépasse la longueur maxi, la ligne d'état montre `C 127!` en
vidéo inverse. **CTRL-L** (menu Chercher, Trop long) va au premier caractère en trop du
paragraphe trop long suivant ; les Statistiques donnent la longueur du plus long paragraphe
et son numéro (`max 177 (L4)`).

| Touche | Action |
|---|---|
| Flèches | déplacer le curseur |
| SHIFT-← / SHIFT-→ | début / fin de ligne |
| CTRL-← / CTRL-→ | début du mot (ou du précédent) / du mot suivant ; un mot finit à un espace ou à une fin de paragraphe |
| SHIFT-↑ / SHIFT-↓ | page précédente / suivante |
| CTRL-↑ / CTRL-↓ | début / fin du texte |
| RETURN | nouveau paragraphe |
| DEL / CTRL-D | effacer à gauche / sous le curseur |
| CTRL-ESPACE | marquer un bout du bloc (Edition, Marquer) ; ESC ôte la marque |
| CTRL-X / CTRL-C / CTRL-V | couper / copier le bloc (de la marque au curseur) / coller |
| CTRL-K | effacer le paragraphe |
| CTRL-E | insertion / remplacement |
| CTRL-F / CTRL-G / CTRL-H | chercher / suivant (repart du début si besoin) / remplacer |
| CTRL-O / CTRL-S / CTRL-Q | ouvrir / enregistrer / quitter |
| CTRL-I (TAB) | insérer un fichier au curseur (Fichier, Insérer...) |
| CTRL-P | imprimer le texte (Fichier, Imprimer) |
| CTRL-L | paragraphe trop long suivant (Chercher, Trop long) |
| CTRL-W | mode d'affichage suivant : coupure mots, 38 car, ligne (Options) |
| FUNCT | menus |

Menus :
- **Fichier** : Nouveau, Ouvrir..., Insérer..., Enregistrer, Enreg. sous..., Imprimer, Quitter. Le
  système demande confirmation avant de perdre des modifications. Insérer... ajoute le contenu
  d'un autre fichier texte à l'endroit du curseur (le curseur se retrouve après le texte inséré).
  Imprimer envoie tout le texte sur l'imprimante (port Centronics, fonction 5 du BDOS), mis en
  page : chaque paragraphe est coupé entre les mots en lignes d'au plus la largeur de
  l'imprimante moins un caractère (79 pour 80, réglable dans `EDIT.CFG`), pour qu'une
  imprimante qui passe d'elle-même à la ligne ne fasse pas de ligne blanche ; un mot plus long
  qu'une ligne est coupé. ESC arrête entre deux lignes. Sans imprimante rien ne bloque, mais chaque
  caractère attend 2 ms l'accusé de réception (une vingtaine de secondes pour 10 Ko) : ESC.
  Lancé depuis LOGO par `EDITE`, EDIT montre Retour au lieu de Quitter : il enregistre le texte
  s'il a changé et revient dans LOGO (voir LOGO).
- **Edition** : Marquer, Copier, Couper, Coller, Eff. paragr. Le presse-papiers fait 4 Ko au plus.
  On marque un bout du bloc (CTRL-ESPACE), on déplace le curseur à l'autre bout, puis on copie
  (CTRL-C) ou on coupe (CTRL-X) ; CTRL-V colle au curseur. ESC ôte la marque.
- **Chercher** : Chercher..., Suivant, Remplacer..., Trop long. Pour chaque occurrence, on répond
  O (oui), N (non), T (tous) ou Esc. La recherche ignore la différence majuscules/minuscules.
- **Options** : Coupure mots, Coupure 38car, Ligne (les trois modes d'affichage ; `>` devant
  celui en cours ; le mode de départ vient d'`EDIT.CFG`), Ins/Rempl., Statistiques (caractères,
  mots, plus long paragraphe).

Lancé depuis le mode SPLIT, l'éditeur passe en plein écran texte et garde son texte sous
`$A000` (environ 27 Ko). En sortant, il réaffiche l'image intacte.

Les fichiers sont du texte CP/M : CR LF entre les paragraphes, `^Z` à la fin. Pour ne rien perdre
si le disque est plein, l'enregistrement écrit d'abord `NOM.$$$`, puis remplace l'ancien fichier :
il faut donc la place du nouveau fichier en plus de l'ancien. Disque plein (`Disque plein : non
enregistre`) ou répertoire plein : l'ancien fichier n'a pas changé et `NOM.$$$` est effacé.
Enreg. sous... un fichier qui existe demande `Remplacer NOM.EXT (O/N) ?` ; un fichier protégé
est refusé (`Fichier protege (R/O)`) sans rien écrire. Un document ouvert en lecture seule peut
être enregistré sous un autre nom. Un RESET pendant l'enregistrement laisse l'ancien fichier, ou
le nouveau ; au pire (RESET entre l'effacement de l'ancien et le renommage, une demi-seconde)
le nouveau texte est complet dans `NOM.$$$` : `REN NOM.EXT=NOM.$$$` le remet. Un `NOM.$$$`
resté est effacé par l'enregistrement suivant du même nom.

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
| SHIFT-← / SHIFT-→ | début / fin de la ligne |
| SHIFT-↑ / SHIFT-↓ | page précédente / suivante |
| CTRL-↑ / CTRL-↓ | début / fin du fichier |
| CTRL-L | aller à une adresse (en hexa) |
| CTRL-F / CTRL-G | chercher / suivant |
| TAB (CTRL-I) | modifier en hexa ou en ASCII |
| CTRL-S / CTRL-R | enregistrer / recharger |
| ESC ou CTRL-Q | quitter (confirmation si le fichier est modifié) |
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

`ASM NOM [/S] [/E]` assemble `NOM.ASM` (ou `NOM.ext` si on donne le type) et écrit `NOM.COM`.
On peut ainsi écrire, assembler et lancer un programme sans quitter l'Oric. `/S` écrit aussi
`NOM.SYM`, la liste des symboles pour DEBUG ; `/E` efface la source si l'assemblage a réussi
(c'est ce que fait `GRXASM NOM /C`, dont le `.ASM` n'est qu'un intermédiaire). Exemple sur la
disquette :

    A>ASM HELLO /S
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
| Inclusion | `#include "CPA.INC"` (un niveau), cherché sur le lecteur de la source, puis sur les lecteurs déjà lus de A: à D: |
| Commentaire | `;` jusqu'à la fin de la ligne |

Expressions : nombres décimaux, `$hexa`, `%binaire`, caractères `"A"` ou `'A'`, `*` (adresse de
l'instruction), symboles, parenthèses, `+ - * / & | ^ << >>`, moins unaire, et `<` / `>` (octet
bas / haut) devant l'expression. Les mnémoniques s'écrivent en majuscules ou en minuscules ;
`ASL`, `LSR`, `ROL`, `ROR` acceptent `A` ou rien. Une adresse connue avant la ligne et inférieure
à 256 donne le mode page zéro.

Comme avec `xa`, un second `*=` ne laisse pas de trou dans le fichier : le code qui suit est mis
à la suite, assemblé pour la nouvelle adresse (DEBUG s'en sert pour se recopier en haut de la
mémoire).

**Un programme en plusieurs fichiers.** EDIT ne tient que 32 000 octets : un long programme
se découpe en modules, édités séparément et réunis par le fichier principal.

    ; JEU.ASM
    #include "CPA.INC"
    *= $0500
            jsr init
            ...
    #include "ECRAN.INC"
    #include "NIVEAUX.INC"

Un seul niveau d'inclusion : un module n'en inclut pas d'autre (`Un seul niveau
d'inclusion`). Les étiquettes sont communes à tous les fichiers : préfixer celles de chaque
module (`ec_`, `nv_`...), comme le font les bibliothèques (`h_`, `r_`, `f_`). Les modules se
cherchent comme `CPA.INC` : sur le lecteur de `JEU.ASM`, puis sur A: à D:.

Les erreurs sont listées avec le numéro de ligne, le message et le début de la ligne (le nom du
fichier inclus entre crochets s'il y a lieu). La liste fait une pause à chaque écran plein. S'il y
a une erreur, rien n'est écrit. ESC interrompt l'assemblage.

L'assembleur lit le source ligne à ligne sur le disque, en deux passes : la taille du source
n'est limitée que par la disquette. La seconde passe écrit le code dans `NOM.COM` au fur et à
mesure, par enregistrements de 128 octets : la mémoire libre (environ 37 Ko en mode texte) ne
sert qu'à la table des symboles (environ 10 octets plus la longueur du nom par symbole ; LOGO
en a 1 500). Une ligne peut faire environ 1000 caractères.
À titre d'exemple, LOGO (6 500 lignes, 136 Ko de source, 19 Ko de code) s'assemble en un peu
plus d'une minute et demie (environ 28 millions d'instructions, plus les accès disque).

## Le débogueur DEBUG

    A>ASM PROG
    A>DEBUG PROG [paramètres]

DEBUG charge `PROG.COM` en `$0500`, là où il tournera, et `PROG.SYM` s'il existe (`ASM PROG /S`). Les
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

Les fichiers texte (`.ASM`, `.INC`, `.LOG`, `.GRX`, `.TXT`, `.BAT`, `.CFG`, `.DOC`, `.SUB`,
`.PRN`, `.LST`) sont mis en fins de ligne CR LF, celles de CP/M, par `put` et `new` (donc aussi
par `build.sh`) : un fichier écrit sur le Mac, en LF seul, s'afficherait sinon en escalier
dans EDIT et TYPE. Les autres types sont copiés tels quels.

Images et animations faites sur le PC : `tools/png2hir.py` (PNG ou JPEG -> `.HIR`, `.IMG`
avec `--split`, `.HIZ` avec `--hiz`), `tools/mkanim.py` (GIF -> `.ANI`) ; voir « HIRES plein
écran ». Les autres outils (construction, tests, émulateurs) sont décrits dans
`docs/atelier.md`.

## Mise en œuvre des programmes

Ce qui sert avant de modifier un programme. Le système : `docs/systeme.md`.

- **COPY** (comme PIP) : noms relevés d'abord (premier extent, 128 au plus), puis copiés un à
  un ; tampon jusqu'au haut de la TPA (`$020C`) ; attributs non recopiés ; destination
  protégée laissée (`fichier protege`) ; copie partielle effacée si le disque est plein.
- **ERA** : relève et montre les fichiers visés, compte les protégés (gardés : la fonction 19
  les épargne), demande toujours confirmation (`/Q` pour les scripts).
- **REN** : syntaxe `nouveau=ancien` de CP/M 2.2 ; refus si le nouveau existe, si l'ancien est
  protégé ou introuvable.
- **SET** prend le lecteur du nom (`SET B:NOM RO`).
- **Attributs** : R/O protège, SYS cache de DIR ; c'est tout. Les commandes de la disquette
  livrée sont R/O et visibles ; les exemples sans attribut. Posés par `mkdisk.py` (listes dans
  `build.sh`).
- **FORMAT** pilote le WD1793 lui-même (le BIOS n'a pas d'entrée Write Track ; en ajouter une
  toucherait le contrat) et tient à jour `phy_drv` et `dsk_trk` (`src/hw.inc`). Image de piste
  identique à celle de `mkdisk.py` (le LOCI retrouve les données à un écart fixe de
  l'en-tête), 6 078 octets puis `$4E`. Entrelacement 2:1. Chaque piste est relue aussitôt
  écrite (vérification ; sur le LOCI, elle remet aussi à neuf son compteur d'attente).
  Positionnement avec la face 1 choisie (sinon Oricutron relit la face 0 d'après son ancien
  cache). `/Q` passe par le BIOS. Même test du LOCI que le BIOS (`Lecteur B: absent ou vide`).
- **DISKCOPY** passe par SELDSK, SETSEC, SETDMA, READ, WRITE du BIOS, par tranches aussi
  grandes que la TPA. Sans `/T` : LSN 0-67 puis les blocs cités par le répertoire. `/S` :
  LSN 0-67 seulement (SYSGEN). Un seul lecteur : source et destination demandées à chaque
  tranche, tampon du BDOS vidé avant le premier échange, disquette système redemandée à la fin.
- **EXPORT, IMPORT, USBDIR** (`progs/loci_inc.s`) : le LOCI est reconnu au code que sa MIA
  place en `$03B0-$03B7`, après l'opération 0 (au démarrage d'une disquette, le firmware y
  laisse autre chose) ; sans LOCI, ces adresses sont celles du VIA. Chemins sans lecteur : la
  première clé montée. Casse d'origine prise dans `ORIG_LINE`. `^Z` retirés à l'EXPORT,
  ajoutés à l'IMPORT ; `/T` change LF seul en CR LF et TAB en un espace. Un `.DSK` est refusé à l'EXPORT (on
  écraserait l'image en service). Transferts par enregistrements de 128 octets. API de la MIA
  (`$03A0-$03B9`) : `loci-rom/src/asminc/loci.inc`.
- **EDIT** : 8 192 octets exactement (tout ajout coûte un bloc de 2 Ko ; 842 octets de
  tampons pourraient sortir du fichier). `/L` : l'article Quitter devient Retour (vers LOGO).
- **ASM** écrit le code au fil de la passe 2, par enregistrements (`wput`) : la mémoire ne
  sert qu'aux symboles. Le fichier est effacé s'il y a des erreurs. `tools/test_asm.sh` :
  chaque programme de `progs/` assemblé par ASM.COM doit être identique à xa.
- **HEX** écrit sur place (accès direct) ; quitter une fenêtre modifiée l'écrit.
- **DEBUG** se place en `$8400-$9FFF` et abaisse le haut de la TPA (plafond `$02A9`).
- **POKE, GO** tiennent en `$0500-$05FF` ; POKE décode tout avant d'écrire, depuis la page
  zéro (`$D0-$DD`).
- **STAT** calcule la place libre d'après le répertoire (pas de fonction 27).
- **HELP** et README.TXT sont produits par `tools/gen_readme_txt.py` (textes de HELP
  compressés en LZSS).

## Limites connues

- Quatre lecteurs (A: à D:), pas de zones utilisateur.
- COPY ne copie pas d'une disquette à l'autre avec un seul lecteur : CMDER le fait.
- Les interruptions sont coupées pendant un transfert de secteur : une touche frappée pendant
  un accès disque peut être perdue.
- Les commandes « tapées » par un menu passent par le tampon clavier (15 caractères au plus).
