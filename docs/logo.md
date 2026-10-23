# LOGO — référence

A>LOGO

Sur les disquettes françaises, ce Logo parle français (`AVANCE`, `POUR ... FIN`) ; sur les
disquettes anglaises, anglais (`FORWARD`, `TO ... END`, `docs/en/logo.md`) ; `LOGOTR` traduit
un fichier `.LOG` de l'une à l'autre (voir « Traduire un programme »). La tortue dessine dans l'image du mode SPLIT (LOGO y passe tout seul),
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
| `VIDETEXTE` / `VT` | effacer la console (lignes 1-27 en écran texte, sous la barre en écran mixte), curseur en haut à gauche |
| `TAPE x` | comme `ECRIS`, sans passer à la ligne (jeux : un score à sa place) |
| `FIXECURSEUR c l` | placer le curseur de la console (pour `TAPE`, `ECRIS`) : colonne 0-39, ligne 0-27 de l'écran entier (voir « Jeux en écran texte ») |
| `FIXECARECRAN c l n` | écrire le code n (0-255) dans une case, sans bouger le curseur : caractère, attribut de couleur (0-7 encre, 16-23 papier), +128 pour la vidéo inverse |
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
| `TOUCHE` | la touche, sans attendre et sans délai de répétition (jeux d'action, comme `KEY$` en BASIC) : celle tapée depuis le dernier `TOUCHE`, sinon celle qui est encore enfoncée, sinon le mot vide |
| `CURSEUR`, `CARECRAN c l` | position du curseur `[colonne ligne]` ; code de la case (0-255) |
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
`LISCAR`, `TOUCHE?`, `TOUCHE`, `CURSEUR`, `CARECRAN c l`, `JOUE? v`, `RACINE x`, `SIN x`, `COS x`, `ARCTAN x` (angles en degrés, comme la
tortue : `SIN 30` donne 0.5, `ARCTAN 1` donne 45), `LN x`, `EXP x`, `ENT x` (partie entière, vers zéro), `ARRONDI x` (entier le plus proche,
2.5 donne 3), `ABS x`, `QUOTIENT a b` (division entière, vers zéro) et `RESTE a b` (du signe
de `a`). Une touche tapée pendant qu'un programme tourne est gardée pour `LISCAR` (la
dernière seulement) ; elle est oubliée au retour au prompt. ESC et CTRL-C interrompent aussi `LISCAR` (`LISCAR` ne les rend donc jamais).

**Jeux en écran texte.** `FIXECURSEUR`, `CURSEUR`, `CARECRAN` et `FIXECARECRAN` prennent les
coordonnées de l'écran entier, comme le LORES de GRAPHER : colonnes 0 à 39 (0 et 1 portent
les attributs de la ligne : `FIXECARECRAN 0 5 20` met la ligne 5 sur fond bleu), lignes 0
à 27 en écran texte (la ligne 0 est la barre du système, redessinée quand on ouvre un menu),
16 à 26 en écran mixte (au-dessus, l'image ; la ligne 27 porte les attributs du mode). LOGO
garde sa console : `TAPE` et `ECRIS` écrivent au curseur, passent à la ligne au bout de la
ligne et font défiler la console après la ligne 27 ; pour la dernière case de l'écran,
`FIXECARECRAN`. `TOUCHE` lit le clavier sans attendre et sans le délai de répétition :
une flèche tenue fait avancer à chaque appel dès l'appui, et plus rien dès qu'on la lâche
(`LISCAR` et `TOUCHE?` suivent, eux, la répétition du clavier). Les flèches rendent
`CAR 8` (gauche), `CAR 9` (droite), `CAR 10` (bas), `CAR 11` (haut) ; avec SHIFT, `CAR 240`
à `CAR 243`, avec CTRL `CAR 244` à `CAR 247` (même ordre). Exemple sur
`cpa-logo.dsk` : `LOGO FLECHES.LOG` (un `@` qu'on déplace dans un cadre, les murs lus par
`CARECRAN`).

    DONNE "K TOUCHE
    SI VIDE? :K [STOP]
    SI :K = CAR 9 [DONNE "X :X + 1]
    SI (CARECRAN :X :Y) = 32 [FIXECARECRAN :X :Y 64]

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
BDOS (voir « Appel du BDOS » (`docs/manuel.md`)).

**Écran texte.** Pour un programme qui n'écrit que du texte (calculs décimaux, mots et
listes), `ECRANTEXTE` (menu Tortue, « Ecran texte ») donne tout l'écran au texte : 26 lignes
au lieu de 10. L'image reste en mémoire : `ECRANMIXTE` la remet, avec la tortue là où elle
était. En écran texte, les commandes qui bougent la tortue ou touchent l'image (`AV`, `RE`,
`DR`, `GA`, `FIXECAP`, `FIXEXY`, `ORIGINE`, `VE`, `NETTOIE`, `SAUVEIMAGE`, `CHARGEIMAGE`)
donnent `Impossible en ecran texte : AV` ; `LC`, `BC`, `GOMME`, `INVERSE`, `CT`, `MT` restent
permises (elles servent au retour), et `XCOR`, `YCOR`, `CAP` répondent toujours. La place
pour les procédures et les textes ne change pas.

`-5` collé derrière un blanc est un nombre négatif (`FIXEXY -50 -30`), alors que `3 - 2` est
une soustraction. ESC ou CTRL-C interrompt un programme (on reste dans LOGO, procédures et
variables gardées) ; au prompt `?`, CTRL-C ne fait rien. La barre de menus (Fichier, Tortue, Aide) tape
les commandes à la place de l'utilisateur.

Les procédures sont enregistrées comme du texte (`POUR` ... `FIN`), qu'on peut modifier avec
`EDIT DEMO.LOG`. `CHARGE` exécute aussi les autres lignes du fichier. Une ligne de fichier a
126 caractères au plus, comme au clavier : au-delà, `CHARGE` s'arrête sur
`Ligne de plus de 126 car. : L 12` (le numéro est celui de la ligne d'état d'EDIT, qui signale
ces lignes : voir `EDIT.CFG`) ; une longue liste se construit en plusieurs lignes (`DONNE "L
PH :L [...]`). La disquette contient
`DEMO.LOG`, avec CARRE, POLY, ETOILE, FLEUR, SPIRALE, ARBRE (récursif) et DEMO :

    ? CHARGE "DEMO
    ? DEMO

La disquette LOGO (`cpa-logo.dsk`) ajoute des exemples de Pierre, qui se lancent d'eux-mêmes
par `LOGO NOM` : `ELIZA` (le « docteur », conversation en français ; `AUREVOIR` pour
sortir), et trois traceurs de courbes dans un repère : `TRACARRE` (x²), `TRASINUS`
(sinus), `TRASINXX` (x sin x). `ELIZA2` donne les mêmes réponses, mais ses recherches sont
des fonctions récursives (`RENDS`) qui s'arrêtent dès qu'elles trouvent, et un mot absent de
la table est écarté d'un seul `MEMBRE?` au lieu d'une boucle de 80 tours qui recopie la
table : une réponse prend 1 à 2 s au lieu de 15 à 30. Comparer les deux est une bonne leçon
de Logo sur l'Oric : un `REPETE` qui continue après avoir trouvé, et `SP` sur une longue
liste (une copie à chaque pas), coûtent cher.

Le Logo lit directement le texte des procédures ; les noms des primitives sont retrouvés par
un index par première lettre, construit au démarrage. Les listes et les appels passent par une pile
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
réutilisable par d'autres programmes). Les mots et les listes sont des textes rangés dans un tas (voir « Mise en
œuvre »).

## Traduire un programme (LOGOTR)

    A>LOGOTR JEU           JEU.LOG en français, l'original gardé en JEU.BAK
    A>LOGOTR JEU GAME /EN  JEU.LOG en anglais, dans GAME.LOG

`LOGOTR NOM [DEST] [/EN|/FR]` traduit les primitives de `NOM.LOG` : vers l'anglais avec `/EN`
(par défaut sur les disquettes anglaises), vers le français avec `/FR` (par défaut sur les
françaises). Sans `DEST`, le fichier est remplacé et l'original gardé en `NOM.BAK` ; la
traduction est d'abord écrite dans `NOM.$$$` : rien n'est perdu si le disque est plein. Il
donne le nombre de mots traduits et les avertissements, avec leur numéro de ligne.

Seules les primitives sont traduites : les noms de l'utilisateur (procédures, variables, mots
entre guillemets) restent tels quels, comme tout ce qui est une donnée. En Logo, le code et les
données se ressemblent (`[AV 10]` peut être exécuté ou affiché) : LOGOTR traduit les listes
qui sont des listes d'instructions de `REPETE`, `SI`, `EXECUTE` et `ENSEMBLE`, et recopie les
autres telles quelles. Deux avertissements :

- `liste de donnees ? AV` : une liste de données qui commence par un nom de primitive ; elle
  est peut-être exécutée plus tard (`DONNE "L [AV 10]` puis `EXECUTE :L`) : à vérifier, et à
  traduire à la main s'il le faut. Une phrase affichée par le programme peut aussi le
  provoquer (`ECRIS [POUR SORTIR...]`) : rien à faire.
- `nom de primitive : STEP` : un nom de l'utilisateur qui est une primitive dans la langue
  d'arrivée ; renommer la procédure, sinon LOGO la prendrait pour la primitive.

Sans avertissement : un mot entre guillemets dont le programme fait du code (`EXEC LISTE
"ECRIS 9`) reste tel quel ; à traduire à la main.

Une abréviation devient l'abréviation de l'autre langue quand elle existe (`AV` / `FD`), sinon
le nom long (`EXEC` donne `RUN`, qui revient en `EXECUTE`). `LISTE` est en français à la fois
une instruction (montrer une procédure) et une fonction (faire une liste) : elle devient
`PRINTOUT` en début d'instruction devant un mot entre guillemets, `LIST` sinon. Traduits
aller et retour, les exemples et les scénarios de test reviennent à l'identique (à ces
abréviations près).

## Mise en œuvre

Source : `progs/logo.s`, avec `progs/fp_inc.s` (décimaux et fonctions) et
`progs/ltxt_inc.s` (mots et listes). Tests : `tools/test_logo.sh` (scénarios
`tools/logo_tests/*.log` comparés aux `.ref`, ~20 min ; `LANGUE=en` : LOGO anglais, scénarios
traduits par LOGOTR, références dans `tools/logo_tests/en`) et `python3 tools/test_fp.py`.

**Vocabulaire.** `tools/gen_logo_voc.py` tient la seule table des primitives : chacune a un
numéro (son rang : le token d'une future tokenisation en mémoire), sa routine et ses noms en
français et en anglais (le nom long d'abord, puis les abréviations). Il écrit les tables
`prims` et `funcs` de chaque langue (`progs/msg/fr/logovoc.msg`, `progs/msg/en/logovoc.msg`),
les mots `POUR` / `FIN`, les commandes tapées par les menus et la table numérotée de LOGOTR
(`progs/lgtr_tab.s`). Les messages, les menus et le texte d'`AIDE` sont dans `logo.msg`.
`FIN` a trois lettres dans les deux langues (`END`) : une procédure rangée finit par ce mot
(`w_fin`).

**Valeurs.** 6 octets : un type (entier 16 bits, décimal, texte) et 5 octets. Les décimaux
sont au format du BASIC de l'Oric (exposant et mantisse de 32 bits, ~9 chiffres), routines
écrites pour CP/A. Un entier qui déborde devient décimal ; un résultat décimal reste décimal
même s'il tombe juste (`0.5 * 4`) ; les primitives qui veulent un entier arrondissent.
`QUOTIENT` tronque vers zéro, `RESTE` a le signe du dividende. Précision mesurée : + - * / à
0,5 ulp ; RACINE 0,5 ulp, EXP 0,9, LN 1,75, ARCTAN 1,5 ; SIN en degrés 1,5E-9 (angles
remarquables exacts : `COS 90` = 0). `PUISSANCE` n'existe pas : elle s'écrit en Logo.

**Pile de valeurs.** Les valeurs intermédiaires de l'évaluateur passent par une pile de 40
valeurs, pas par la pile du 6502. Avec les variables et les arguments, c'est la racine du
compactage du tas.

**Mots et listes.** Ce sont des textes dans un tas qui descend de `memtop` pendant que les
procédures montent. Compactage à la manière du BASIC Microsoft. Deux règles le rendent sûr :
un résultat est toujours une copie (jamais un morceau d'un autre texte), et seules comptent
les variables, les arguments et la pile de valeurs ; une primitive qui réserve de la place y
empile d'abord ses textes. Une liste est rangée normalisée (une espace entre éléments, aucune
après `[` ni avant `]`) ; une sous-liste est un groupe `[...]`. EXECUTE copie la liste dans
une pile à part de 512 octets (`xstack`), que le compactage ne touche pas.

**Tortue.** Virgule fixe au 1/256 ; le cap a un octet de fraction (`headf`). Table de sinus
en 65536 × sin (90° traité à part). XCOR, YCOR, CAP : entier si la tortue est sur un point
entier, sinon arrondis à 2 décimales. `ECRANTEXTE` garde `memtop` à `$A000` : l'image est
gardée et rien n'est à déplacer au retour.

**RENDS.** Une procédure appelée dans une expression passe par `call_func` (contexte
`FR_FUNC`, boucle `run` imbriquée). Pour ne pas limiter la profondeur à la pile du 6502, la
partie de la pile entre `savsp` et le sommet est recopiée dans `spill` (640 octets). Une
fonction qui finit sans RENDS, ou RENDS dans une procédure appelée en instruction, est une
erreur. Profondeur : une quarantaine de niveaux.

**EDITE.** SAUVE, puis l'état dans `LOGO.$$$` (en-tête « LGS1 », variables globales, tas,
page zéro relue en dernier), puis CHAIN sur `EDIT NOM.LOG /L`. Le Retour d'EDIT enchaîne sur
`LOGO NOM.LOG /R`, qui recharge l'état et le fichier. Les procédures ne sont pas dans l'état ;
le contexte d'exécution n'est pas gardé.

**CHARGE.** Accepte un nom calculé ; un CHARGE dans un fichier chargé est refusé (`ldon`,
`Interdit pendant CHARGE :`). Un grand programme se charge par étapes (`CHARGE`, `OUBLIE`) :
c'est pourquoi les modules chargeables ont été écartés.

**Recherche des primitives.** Les tables `prims` et `funcs` sont rangées par première
lettre ; `ix_build` en tire au démarrage un index (`pix`, 2 × 26 adresses) : une primitive
ajoutée va dans le groupe de sa lettre. L'index est construit en RAM plutôt qu'écrit en
étiquettes, parce que 40 étiquettes de plus faisaient déborder la table des symboles d'ASM
sur `LOGO.ASM`.

**Son.** Les arguments sont gardés sur la pile du 6502 jusqu'à l'appel du BDOS (une fonction
appelée dans un argument peut elle-même jouer un son). ESC et toute erreur font `SILENCE`.
`ENSEMBLE` : SYNC 0, la liste dans un contexte `FR_ENS`, SYNC 1 quand ce contexte est retiré
(fin, `STOP`, `RENDS`) ; un ENSEMBLE dans un autre est compris dans le premier (`ensd`).
`JOUE?` et `ATTENDSSON` ne voient que les notes minutées.

**Écran texte.** `FIXECURSEUR` écrit `CON_CURX`/`CON_CURY` (le curseur affiché est d'abord
retiré, interruptions masquées). En écran mixte, seules les lignes 16-26 sont permises.
`TOUCHE` fait comme `INKEY` de GRAPHER (tampon vidé, touche neuve, sinon `KB_HELD`).

