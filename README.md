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

La disquette contient `README.TXT`, un aide-mémoire de toutes les commandes et de leurs
paramètres, à lire sur l'Oric avec `TYPE README.TXT` (une page à la fois).

## Commandes du CCP

| Commande | Effet |
|---|---|
| `DIR [afn]` | liste les fichiers (jokers `*` et `?`) et l'espace libre ; les fichiers SYS sont cachés |
| `DIRS [afn]` | comme DIR, fichiers SYS compris |
| `TYPE fichier` | affiche un fichier texte (une touche l'interrompt) |
| `ERA afn` | efface (demande confirmation pour `*.*`) |
| `REN nouveau=ancien` | renomme |
| `SAVE n fichier` | enregistre n pages de 256 octets à partir de `$0500` |
| `GSAVE fichier`, `GLOAD fichier` | enregistre / charge l'image du mode SPLIT (type `.IMG` par défaut) |
| `PUT fichier commande [paramètres]` | exécute la commande en copiant tout ce qu'elle affiche dans le fichier |
| `DO fichier [p1 ... p9]` | exécute les commandes de `FICHIER.BAT`, une par ligne |
| `ECHO texte`, `PAUSE [texte]` | affiche un texte ; attend une touche (pour les scripts) |
| `PEN`, `PLOT`, `LINE`, `BOX`, `FBOX`, `CIRCLE`, `GTEXT`, `ATTR`, `POINT` | primitives graphiques (voir le mode SPLIT) |
| `NOM [args]` | charge `NOM.COM` en `$0500` et l'exécute |
| `VER`, `CLS` | version, effacement de l'écran |

Commandes transitoires (fichiers `.COM` sur la disquette) qui complètent le CCP :

| Commande | Effet |
|---|---|
| `HELP [sujet]` | aide en français : commandes internes, puis `HELP EDIT`, `HELP HEX`, `HELP LOGO`, `HELP ASM`, `HELP DEBUG`, `HELP MEM` (carte mémoire), `HELP TOUCHES`, `HELP PROG` |
| `SET afn [RO\|RW\|SYS\|DIR]` | attributs des fichiers (sans option : les affiche) |

Dans la version disquette, `HELP`, `MEM`, `DUMP`, `POKE` et `GO` ne sont plus internes : l'aide
est dans `HELP.COM` (plus complète, et sans prendre de place dans le système), et DEBUG fait
le travail du moniteur. La version ROM, qui n'a pas de disque, les garde en interne.

**Attributs de fichier.** Comme sous CP/M 2.2, deux bits du nom de fichier servent
d'attributs : R/O (lecture seule : le fichier ne peut être ni effacé, ni renommé, ni écrit,
ni remplacé) et SYS (fichier système : `DIR` ne le montre pas, `DIRS` oui ; il reste
utilisable). `SET HELP.COM RO SYS` protège et cache, `SET HELP.COM RW DIR` revient en arrière.
ERA et REN répondent `File R/O` ; EDIT et HEX refusent d'enregistrer un fichier protégé.
Les programmes passent par la fonction 30 du BDOS (bit 7 de l'octet 9 du FCB = R/O, de
l'octet 10 = SYS).

Touches : CTRL-T bascule les majuscules, DEL efface, CTRL-X efface la ligne,
CTRL-C en début de ligne fait un démarrage à chaud. Le bouton RESET revient au CCP.

**Pause en fin d'écran.** Quand une commande remplit la console (27 lignes en mode texte,
11 en mode SPLIT) sans que l'utilisateur ait touché le clavier, l'affichage s'arrête sur
` -- Suite : une touche (^C stop) -- `. Une touche continue, CTRL-C abandonne et revient au
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
(`$$` donne `$`). Les programmes lancés par le script lisent le clavier normalement, et un DO
dans un script passe au nouveau script. ESC tapé entre deux lignes, ou pendant un `PAUSE`,
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
en haut, et 12 lignes de texte en dessous (la barre de menus puis 11 lignes de console).
Le prompt, les commandes et les menus continuent de fonctionner sous l'image.
`TEXT` revient au mode texte, et `GCLS` efface l'image.

`GSAVE NOM` enregistre l'image dans `NOM.IMG`, et `GLOAD NOM` la recharge en passant en
mode SPLIT si besoin (la console n'est pas effacée si on y est déjà). Le fichier est la
copie brute de `$A000-$B3FF` : 5 120 octets, attributs de couleur compris. On peut ainsi
préparer des images (avec LOGO, ou un programme de dessin) et les recharger dans un jeu.

Comment ça marche : la trame commence en mode texte. La toute première case lue (`$BB80`)
contient l'attribut `$1E`, qui fait passer en haute résolution. La première case de la ligne
de points 128 (`$B400`) contient `$1A`, qui fait revenir au texte. L'image (`$A000-$B3FF`)
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

La durée est en cinquantièmes de seconde (0 : la note tient jusqu'à la suivante). Elle est
décomptée par l'interruption à 50 Hz : le programme continue pendant que la note joue, et
`WAIT` ou `STATUS` servent à se synchroniser. Le clavier passant lui aussi par l'AY, les
écritures dans le circuit sont faites interruptions masquées. Dans LOGO : `NOTE n d`,
`BRUIT d` et `SILENCE`.

    REPETE 2 [NOTE 37 20 NOTE 41 20 NOTE 44 20 NOTE 49 40]

## Menus déroulants

La ligne d'état sert de barre de menus : **Systeme**, **Fichiers** (version disque seulement),
**Ecran** (Mode SPLIT, Mode texte, Effacer, Encre, Papier, Majuscules) et **Clavier**. Le moteur est réécrit d'après le projet
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
| FUNCT | menus |

Menus :
- **Fichier** : Nouveau, Ouvrir..., Insérer..., Enregistrer, Enreg. sous..., Quitter. Le système
  demande confirmation avant de perdre des modifications. Insérer... ajoute le contenu d'un autre
  fichier texte à l'endroit du curseur (le curseur se retrouve après le texte inséré).
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
- `COPY.COM SOURCE DEST` copie un fichier par gros blocs, à travers le BDOS.
- `EDIT.COM [fichier]`, l'éditeur de texte décrit ci-dessus.
- `GTEST.COM`, le test du mode SPLIT et des primitives graphiques.
- `LOGO.COM`, avec `DEMO.LOG`.
- `HEX.COM fichier`, l'éditeur hexadécimal décrit plus bas.
- `ASM.COM NOM`, l'assembleur 6502, avec les sources d'exemple `HELLO.ASM`, `GTEST.ASM` et
  `CPA.INC`.
- `DEBUG.COM NOM`, le moniteur, désassembleur et pas à pas.

## LOGO

    A>LOGO

C'est un Logo en français. La tortue dessine dans l'image du mode SPLIT (LOGO y passe tout seul),
et on tape les commandes sous l'image, après le prompt `?`. Les nombres sont des entiers.

| Commande | Effet |
|---|---|
| `AVANCE n` / `AV`, `RECULE n` / `RE` | avancer, reculer |
| `DROITE n` / `DR`, `GAUCHE n` / `GA` | tourner (degrés) |
| `LEVECRAYON` / `LC`, `BAISSECRAYON` / `BC` | lever, baisser le crayon |
| `GOMME`, `INVERSE` | le crayon efface, inverse |
| `CACHETORTUE` / `CT`, `MONTRETORTUE` / `MT` | cacher, montrer la tortue |
| `VIDEECRAN` / `VE`, `NETTOIE`, `ORIGINE` | effacer et revenir au centre, effacer, revenir au centre |
| `FIXECAP n`, `FIXEXY x y` | cap absolu, position absolue (centre = 0 0, y vers le haut) |
| `REPETE n [ ... ]` | répéter une liste |
| `SI condition [ ... ] [ ... ]` | condition, avec une liste « sinon » facultative |
| `POUR NOM :A :B` ... `FIN` | définir une procédure (paramètres facultatifs) |
| `STOP` | sortir de la procédure |
| `DONNE "X n`, `:X` | variable globale, valeur d'une variable ou d'un paramètre |
| `ECRIS n` / `EC`, `ECRIS "mot`, `ECRIS [texte]` | afficher |
| `ATTENDS n` | attendre n cinquantièmes de seconde |
| `SAUVE "NOM`, `CHARGE "NOM` | enregistrer, charger les procédures (`NOM.LOG`) |
| `SAUVEIMAGE "NOM`, `CHARGEIMAGE "NOM` | enregistrer, charger le dessin (`NOM.IMG`, sans la tortue) |
| `TITRES`, `LISTE "NOM`, `OUBLIE "NOM`, `OUBLIETOUT` | lister, afficher, supprimer |
| `NOTE n d`, `BRUIT d`, `SILENCE` | joue la note n (1 à 96, 37 = do central, 46 = la 440 Hz, 0 = silence) ou un bruit pendant d cinquantièmes de seconde ; coupe le son |
| `AIDE`, `QUITTE` / `AUREVOIR` | aide, retour à CP/A (l'image reste) |

Dans les expressions : `+ - * / ( ) = < >`, ainsi que `HASARD n`, `CAP`, `XCOR` et `YCOR`.
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
| 6 | E/S directe (`$FF` lire, `$FE` état) | 19 | effacer (jokers) |
| 9 | chaîne terminée par `$` | 20 | lecture séquentielle (0 OK, 1 fin) |
| 10 | lire une ligne (format CP/M) | 21 | écriture séquentielle (0 OK, 1 répertoire plein, 2 disque plein) |
| 11 | état console | 22 | créer |
| 12 | version (`$22`) | 23 | renommer (nouveau nom en FCB+16) |
| | | 30 | attributs (bit 7 des octets 9 et 10 du FCB : R/O, SYS) |
| | | 33 / 34 | lecture / écriture directe de l'enregistrement R0-R1 (FCB+33) |
| | | 35 | taille du fichier en enregistrements -> R0-R1 |
| | | 36 | R0-R1 <- position séquentielle courante |
| 13 | réinitialiser les disques | 24 / 25 | disques connectés / disque courant |
| 14 | choisir le disque (A: seul) | 26 | adresse DMA (enregistrements de 128 octets) |

Le FCB a le format CP/M 2.2 sur 36 octets.

**Accès direct.** Les fonctions 33 à 36 lisent et écrivent l'enregistrement de 128 octets dont
le numéro est en R0-R1 (octets 33 et 34 du FCB, R2 à 0), sans tout relire depuis le début.
Comme sous CP/M, la position courante n'avance pas : une lecture séquentielle reprend au même
enregistrement. Retours de la lecture : 0, 1 (enregistrement jamais écrit), 4 (extent
inexistant), 6 (hors limites). L'écriture peut créer un fichier à trous ; elle renvoie 2 si le
disque est plein, 5 si le répertoire est plein, `$FF` si le fichier est en lecture seule. La
fonction 35 donne la taille (nombre d'enregistrements, en tenant compte des trous).

## Table BIOS (adresses fixes)

`$C000` BOOT, `$C003` WBOOT, `$C006` CONST, `$C009` CONIN, `$C00C` CONOUT, `$C00F` LIST,
`$C012` PUNCH, `$C015` READER, `$C018` HOME, `$C01B` SELDSK, `$C01E` SETTRK (sans effet),
`$C021` SETSEC (A/Y = n° de secteur logique), `$C024` SETDMA (tampon de 256 octets),
`$C027` READ, `$C02A` WRITE (A=0 OK), `$C02D` MENUBAR (A/Y = barre de menus).

## Carte mémoire (version disque)

| Zone | Usage |
|---|---|
| `$0000-$00DF` | page zéro libre pour les programmes |
| `$00E0-$00FF` | page zéro système |
| `$0200` / `$0203` | `JMP WBOOT` / `JMP BDOS` |
| `$0206` / `$0209` | vecteurs IRQ / NMI en RAM, détournables |
| `$0210-$02A9` | variables du système (console, clavier, menus, test RAM, graphisme, pagination `$02A3`, plafond de la TPA `$02A9`) |
| `$0400-$04FF` | page de base : tampon de commande, FCB `$045C`/`$046C`, DMA `$0480` |
| `$0500-$B3FF` | TPA (44 800 octets) |
| `$B400-$B7FF` | jeu de caractères |
| `$B800-$BB7F` | jeu alternatif (inutilisé en mode texte) : sauvegarde de l'écran sous les menus |
| `$BB80-$BFDF` | écran texte |
| `$C000-$F1xx` | CP/A (RAM overlay), environ 12,3 Ko |
| `$F670-$F7BF` | ligne de commande d'origine, script DO (FCB, enregistrement, paramètres) |
| `$F7C0-$FCFF` | PUT : sauvegarde d'état et tampon de 1 280 octets |
| `$FD00-$FEFF` | variables du BDOS et tampon de secteur |

Il reste environ 1,3 Ko libres dans la RAM overlay (entre la fin du code et `$F670`) pour de futures commandes internes.

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

Autres fichiers dans `tools/` :
- `gen_font.py` : police 6×8 originale ;
- `gen_tables.py` : tables écran et clavier ;
- `run_test.sh` et `screen.py` : tests automatiques dans Oricutron ;
- `test_asm.sh` : non-régression d'ASM (chaque programme assemblé par ASM.COM doit être
  identique à sa version `xa`) ;
- `run_com.py` : exécute un `.COM` dans un 6502 simulé (module Python `py65`), avec un BDOS
  minimal sur un dossier du PC. C'est ce qui sert à comparer ASM avec `xa` :
  `python3 tools/run_com.py DOSSIER ASM.COM LOGO` ;
- `gen_readme_txt.py` : textes d'aide, à partir d'une seule liste : `files/readme.txt` (`README.TXT`
  sur la disquette) et `progs/help_tab.s` (les rubriques de `HELP.COM`), 37 colonnes au plus ;
- `gen_asm_tab.py` : table des mnémoniques et des opcodes de l'assembleur (`progs/asm_tab.s`) ;
- `oricutron-testhook.patch` : frappe simulée et dump mémoire pour ces tests.

## Limites connues

- Un seul lecteur (A:), pas de zones utilisateur.
- Les interruptions sont coupées pendant un transfert de secteur. Une touche frappée pendant un accès
  disque peut donc être perdue.
- Essayé sur un Oric Atmos avec LOCI ; pas encore sur Cumulus ni sur un vrai Microdisc.
- Les commandes « tapées » par un menu passent par le tampon clavier (15 caractères au plus).

## Licence

CP/A est distribué sous licence MIT (voir `LICENSE`). Les images `build/cpa.dsk` et
`build/cpa.rom` sont fournies prêtes à l'emploi ; `./build.sh` les reconstruit.
