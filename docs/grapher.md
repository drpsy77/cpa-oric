# GRAPHER — référence

GRAPHER exécute un fichier texte `.GRX` (écrit avec EDIT) : une commande par ligne, en anglais.
C'est un langage de bas niveau, proche de l'écran. Il manipule des entiers, des variables
d'une lettre, des tableaux, l'image HIRES ou SPLIT et l'écran texte. Il sert à fabriquer des
écrans (titre, décor) et de petits jeux. Le même fichier peut être **interprété**, ou
**traduit** en assembleur par GRXASM puis assemblé en un `.COM` autonome, 5 à 20 fois plus
rapide (§ 12).

Ce document est la seule référence de GRAPHER. Le README n'en donne qu'un aperçu. HELP et
README.TXT (sur la disquette) en donnent un résumé (`tools/gen_readme_txt.py`).

    ; un eventail en plein ecran
    HIRES
    FOR X 0 239 6
      LINE X 0 239-X 199
    NEXT
    WAIT

## 1. Lancer

| Commande | Effet |
|---|---|
| `GRAPHER NOM [p1 ... p9]` | charge `NOM.GRX` (lecteur facultatif) en mémoire et l'exécute ; `p1`-`p9` remplacent `$1`-`$9` |
| `GRXASM NOM [p1 ... p9]` | n'exécute pas : écrit `NOM.ASM`, à assembler par `ASM NOM` (§ 12) |
| `GRAPHER NOM /A [p1 ... p9]` | la même chose : GRAPHER passe la main à GRXASM (`/A` juste après le nom) |

## 2. Écriture d'un programme

- Une commande par ligne, 126 caractères au plus (`ligne de plus de 126 car.`). Le retrait
  est libre. Le texte s'arrête au premier `^Z`.
- `;` commence un commentaire, en début ou en fin de ligne.
- `$1` à `$9` sont remplacés par les paramètres de la ligne de commande, avec leur casse
  d'origine (`X = $1`, `GTEXT 2 90 $2`).
- **Règle des espaces** : l'espace sépare les paramètres ; une expression parmi plusieurs
  paramètres ne contient donc pas d'espace, sauf entre parenthèses
  (`LINE X 0 (239 - X) 199`). Une expression seule en fin de ligne (`X = ...`, `IF`,
  `WHILE`, `PRINT`) peut en contenir.

## 3. Nombres, variables, expressions

- Entiers de 16 bits signés (-32768 à 32767) ; variables `A` à `Z`, à 0 au départ.
- Affectation : `V = expr` ou `LET V = expr`.
- Opérateurs, du plus fort au plus faible : `-` (signe) ; `*` `/` `%` (`/` tronque vers 0,
  `%` est le reste) ; `+` `-` ; comparaisons `=` `<>` `<` `<=` `>` `>=` (1 si vrai, 0 sinon) ;
  `&` `|` (et, ou bit à bit).
- Parenthèses : `(X * 2)`.

| Fonction | Valeur |
|---|---|
| `RND(n)` | nombre au hasard de 0 à n-1 |
| `ABS(n)` | valeur absolue |
| `POINT(x,y)` | 1 si le point de l'image est allumé (HIRES ou SPLIT) |
| `SCRN(col,lig)` | octet d'une case de l'écran texte (LORES) |
| `INKEY` | touche, 0 si aucune ; n'attend pas ; sans délai de répétition (§ 8) |
| `FOUND` | 1 si le dernier `LOAD` ou `BLOAD` a trouvé son fichier, 0 sinon (§ 10) |
| `LEN(A$)` | longueur d'une chaîne (§ 9) |

Une lettre suivie de `(` est un tableau ; les fonctions ont des noms de plusieurs lettres.

## 4. Contrôle

| Bloc | Effet |
|---|---|
| `REPEAT n` ... `NEXT` | n fois (rien si n ≤ 0) |
| `FOR V a b [pas]` ... `NEXT` | V de a à b, pas de 1 par défaut, négatif pour descendre ; rien si a est déjà au-delà de b ; pas nul : `pas nul` |
| `WHILE expr` ... `NEXT` | tant que l'expression n'est pas nulle (`WHILE 1` : sans fin, ESC arrête) |
| `IF expr` ... [`ELSE` ...] `ENDIF` | si l'expression n'est pas nulle |
| `SUB NOM` ... `ENDSUB` | sous-programme, appelé par `CALL NOM` ; `RETURN` en sort avant la fin ; rencontré en chemin, il est sauté (on peut le placer n'importe où) |
| `END` | fin du programme |

Les blocs s'imbriquent sur 16 niveaux (boucles et appels).

## 5. Modes d'écran

| Commande | Effet |
|---|---|
| `HIRES` | HIRES plein écran, 240 × 200 points, image effacée ; pas de console |
| `SPLIT` | 240 × 128 points, console dessous, image effacée |
| `LORES` | l'écran texte entier au programme (§ 7) ; il est effacé (`CLS`) |
| `TEXT` | retour à la console |

- **Fin du programme** (fin du fichier ou `END`) : HIRES et LORES rendent aussitôt la
  console, sans attendre. Pour laisser l'écran affiché, le programme finit par `WAIT` ou
  `GET`. Une image SPLIT reste au-dessus du prompt.
- Lancé en mode SPLIT, GRAPHER dessine sur l'image en place (après un programme LOGO, par
  exemple).
- En HIRES plein écran, `ECHO`, `PRINT` et `CLS` n'affichent rien (pas de console).

## 6. Dessin (HIRES et SPLIT)

| Commande | Effet |
|---|---|
| `GCLS` | efface l'image |
| `PEN m` | crayon : 0 efface, 1 trace, 2 inverse (autre valeur : `parametres ?`) |
| `PLOT x y` | point (x 0-239 ; y 0-199, ou 0-127 en SPLIT) |
| `LINE x1 y1 x2 y2` | ligne |
| `BOX x1 y1 x2 y2`, `FBOX x1 y1 x2 y2` | rectangle, rectangle plein |
| `CIRCLE x y r` | cercle (r ≤ 127) |
| `GTEXT col y texte` | texte dans l'image : case `col` (0-39, 6 points), ligne de points `y` |
| `GNUM col y n` | nombre dans l'image (un score) |
| `ATTR col y1 y2 v` | attribut dans la case `col`, lignes `y1` à `y2` : encre 0-7, papier 16-23 |

Les paramètres du dessin vont de 0 à 255 (`valeur hors de 0-255`). Hors HIRES et SPLIT :
`HIRES ou SPLIT d'abord`. Images et animations : § 10.

## 7. Écran texte (LORES)

`LORES` donne au programme 40 colonnes (0-39) sur 28 lignes (0-27), ligne 0 et colonnes 0-1
comprises. Il n'y a ni console, ni menus, ni curseur de la console : FUNCT et CTRL-T arrivent
au programme comme des touches ordinaires. Le programme pose lui-même les attributs de couleur
où il veut.

| Commande | Effet |
|---|---|
| `CLS` | attribut 16 (papier noir) dans les 1 120 cases ; curseur d'écriture en (0, 0). Hors LORES : efface la console |
| `LOCATE col lig` | place le curseur d'écriture |
| `CHAR col lig code` | écrit l'octet `code` (0-255) dans la case : caractère 32-127, +128 en vidéo inverse, ou attribut (encre 0-7, papier 16-23...) ; le curseur ne bouge pas |
| `SCRN(col,lig)` | fonction : l'octet de la case |
| `ECHO texte` | écrit le texte au curseur, qui avance. Sans guillemets, les espaces du début sont sautés ; entre guillemets, le texte est pris tel quel (`ECHO "  Score : "`) |
| `ECHO` (seul) | colonne 0 de la ligne suivante ; après la ligne 27 : ligne 0 ; rien n'est effacé |
| `PRINT expr`, `PRINT A$` | écrit le nombre ou la chaîne au curseur, sans passer à la ligne |
| `SPC n [x]` | écrit n fois l'octet x (32 par défaut) : effacer, remettre l'attribut 16, tracer un trait |
| `TAB n` | avance le curseur de n colonnes sans rien écrire (relatif : `LOCATE` donne la colonne absolue) |

- **Bord droit** : rien ne s'écrit au-delà de la colonne 39. Ce qui dépasse est perdu, sans
  erreur ; le curseur reste au bout jusqu'au prochain `LOCATE` ou `ECHO` seul. Rien ne passe
  sur la ligne suivante, et rien ne fait défiler l'écran.
- Colonne ou ligne hors de l'écran : `valeur hors limites` ; `n` de `SPC` et `TAB`, `x` et
  `code` : 0-255 (`valeur hors de 0-255`).
- Hors LORES, `LOCATE`, `CHAR`, `SCRN`, `SPC` et `TAB` donnent `LORES d'abord`. En LORES,
  les commandes de dessin donnent `HIRES ou SPLIT d'abord`.
- `HIRES` ou `SPLIT` depuis le LORES : l'écran texte est perdu. `GLOAD` d'une image `.IMG`
  depuis le LORES rend d'abord la console.

### 7.1 Sprites

Un sprite est un petit personnage de 1 à 4 colonnes sur 1 à 4 lignes de cases, dessiné dans
un fichier `.SPR` (format : § 10.1), chargé par `BLOAD` dans un tableau `$`. Il se déplace
de case en case sur le décor de l'écran texte, sans l'abîmer : chaque case qu'il recouvre
reçoit un caractère redessiné, combinaison du décor de la case et du sprite.

    case affichée = (décor AND NOT silhouette) OR dessin

Le décor reste visible autour de la silhouette du sprite, dans ses propres cases. La couleur
est celle de la ligne (attributs) : le sprite prend la couleur des lignes où il passe.

    DIM S$(112) T(16)
    BLOAD S$ HEROS.SPR
    FOR I 0 15
      T(I) = 112+I          ; codes 112-127 réservés aux sprites
    NEXT
    LORES
    ...                     ; le décor
    SPRITES 2
    SPOOL T
    SSHOW 0 S$ 0 X Y        ; le sprite 0 du fichier, emplacement 0

| Commande | Effet |
|---|---|
| `SPRITES n` | réserve n emplacements (0 à n-1, n de 1 à 255), une fois, avant `SPOOL` ; un emplacement est un objet affiché |
| `SPOOL T [ALT]` | le tableau d'entiers T (déclaré, ou lu par `LOAD`) donne les codes que les sprites peuvent prendre : 32 à 127 (`ALT` : jeu secondaire, 32 à 111), 96 au plus, dans n'importe quel ordre ; ils deviennent tous libres. C'est le **tas** du jeu de caractères |
| `SSHOW k S$ n col lig [ALT]` | affiche le sprite n (rang dans le fichier, à partir de 0) du tableau `S$` dans l'emplacement k, coin haut-gauche en (col, lig), avec le tas du jeu indiqué. Sur un emplacement déjà occupé, l'ancien sprite est d'abord retiré : c'est aussi le déplacement et l'image suivante d'une animation |
| `SHIDE k` | retire le sprite de l'emplacement k : le décor revient, les codes sont rendus au tas (rien si l'emplacement est libre) |

`SSHOW` et `SHIDE` demandent le LORES (`LORES d'abord`).

**Règles pour le programmeur** (le programme traduit ne vérifie rien, § 12) :

- Un code du tas n'apparaît jamais dans le décor ; on garde au moins les chiffres, les
  majuscules et l'espace (il reste 59 codes : 33-47, 58-64, 91-127). Un sprite affiché
  occupe un code par case recouverte ; il faut assez de codes pour tous les sprites affichés
  en même temps (`plus de caracteres pour les sprites`).
- **Les attributs sont prioritaires** : une case qui contient un attribut (code 0-31) n'est
  jamais recouverte, le sprite y est invisible. Or `CLS` met l'attribut 16 partout : la zone
  où passent les sprites doit être remplie d'espaces (ou de décor), par exemple
  `SPC 40` sur chaque ligne. Les attributs de couleur se mettent là où les sprites ne passent
  pas (colonnes 0-1, bord de la zone de jeu).
- Le sprite doit tenir dans l'écran (`valeur hors limites`).
- Deux sprites qui se chevauchent partagent le caractère commun (le second se dessine sur le
  premier). Retirer l'un remet le décor sur la partie commune : on réaffiche l'autre. Aucun
  code n'est perdu, quel que soit l'ordre des retraits.
- On ne change pas le décor sous un sprite affiché (le retirer d'abord), ni le tableau du tas
  pendant que des sprites sont affichés. Un nouveau `SPOOL` rend tous les codes du tas
  libres : les sprites encore affichés avec lui sont à réafficher.
- Le tas correspond au jeu de caractères des lignes où passe le sprite (attribut 8 : standard,
  9 : secondaire). Un personnage à cheval sur deux jeux est découpé en deux sprites. Le jeu
  secondaire n'a pas de dessins à lui (le système y range la ligne en cours d'édition et
  l'historique) : il servira avec les tuiles (§ 16). Un `INPUT` abîme ses codes 64 à 111 ; à
  la fin d'un programme qui s'en est servi, l'historique des lignes est vidé.

## 8. Touches et temps

| Élément | Effet |
|---|---|
| `INKEY` | fonction, comme `KEY$` du BASIC : vide le tampon du clavier et rend la touche tapée depuis le dernier `INKEY`, sinon celle qui est encore enfoncée, sinon 0. Sans délai de répétition : pour les jeux d'action |
| `GET V` | attend une touche et range son code dans V ; suit le délai et la cadence de répétition du clavier (menu Clavier) |
| `WAIT` | attend une touche, sans la garder |
| `DELAY n` | attend n cinquantièmes de seconde, sans regarder le clavier |

Codes des flèches : 8 gauche, 9 droite, 10 bas, 11 haut. **ESC** arrête le programme, entre
deux lignes et pendant `GET`, `WAIT` et `INPUT` (message `Interrompu`). Une autre touche tapée
pendant l'exécution est gardée pour `WAIT`, `GET` ou `INKEY`.

## 9. Tableaux et chaînes

**Noms.** Chaque lettre sert à trois choses indépendantes : `A` (entier), `A(...)` (tableau
d'entiers de 16 bits), `A$` (tableau d'octets 0-255 : chaîne ou grille de caractères).

**DIM.** `DIM S(10) N$(10,12) M$(25,38)`

- Une ou deux dimensions. Plusieurs tableaux par ligne. Les tailles sont des expressions, au
  moins 1.
- Indices de 0 à n-1, comme en C : `DIM A(10)` donne `A(0)` à `A(9)`. Éléments à 0.
- Un tableau se déclare une seule fois (`deja dimensionne`) et avant usage (`tableau non
  dimensionne`). Pas de place : `memoire pleine`, dès le `DIM`. La mémoire n'est jamais
  libérée ni agrandie.

**Éléments.**

- `A(i)`, `A(i,j)` : dans un calcul, ou à gauche de `=` (`A(I,J) = A(I,J) + 1`).
- `A(k)` sur un tableau à deux dimensions : l'élément k du tableau mis à plat, ligne après
  ligne, comme en C (`G(7)` est `G(1,3)` sur `DIM G(3,4)`).
- `A$(i)` (une dimension) et `M$(l,c)` : le code d'une case, en lecture et en écriture
  (`M$(L,C) = 35`).

**Chaînes.** `A$` (tableau `$` à une dimension) et `M$(l)` (ligne l d'un tableau `$` à deux
dimensions) sont des chaînes. Une chaîne s'arrête au premier 0, ou à la fin de sa capacité si
elle est pleine : `DIM N$(12)` contient 12 caractères au plus. Une chaîne fait au plus 255
caractères ; un tableau `$` plus grand se lit case par case. Un tableau de chaînes est un
tableau `$` à deux dimensions (`N$(10,12)` : 10 noms).

| Élément | Effet |
|---|---|
| `A$ = "texte"`, `A$ = B$`, `M$(I) = A$` | affectation ; le reste de la capacité est mis à 0 ; trop long : `chaine trop longue` |
| `=` `<>` `<` `<=` `>` `>=` | comparaison de deux chaînes ou d'une chaîne et d'un texte (`IF R$ = "O"`), dans l'ordre des codes (`"AB" < "ABC"`) ; 1 ou 0 |
| `LEN(A$)`, `LEN(M$(I))` | longueur |
| `PRINT A$` | en LORES : au curseur, codes 0-31 écrits tels quels (une ligne de niveau garde ses couleurs). Dans la console : codes 0-31 remplacés par un espace, puis passage à la ligne. `PRINT A$ = B$` affiche la comparaison |
| `INPUT A$`, `INPUT M$(I)` | saisie. En LORES : au curseur (case en vidéo inverse), caractères 32-126, DEL efface, RETURN valide, arrêt à la capacité ou au bord droit. Ailleurs : saisie de ligne de la console, coupée à la capacité |
| `INPUT V` | entier de -32768 à 32767 : chiffres et `-`, 6 caractères au plus ; vide ou hors limites : un son, et on recommence |
| `FILL A v`, `FILL M$ 32` | tout le tableau à v |

- Une chaîne ne se mélange pas aux calculs (`chaine dans un calcul`). Il n'y a ni
  concaténation ni conversion : on enchaîne `ECHO` et `PRINT`.
- `ECHO` n'écrit que le texte du programme (`ECHO A$` écrit « A$ »).
- Un attribut 0 ne peut pas être affiché par `PRINT` (c'est la fin de chaîne) : on l'écrit par
  `CHAR` ou `M$(L,C) = 0`.
- Pas d'`INPUT` d'un élément : `INPUT V` puis `A(I) = V`.
- En interprété, chaque accès vérifie le tableau et ses indices (`indice hors limites`). Un
  programme traduit ne vérifie rien (§ 12).

## 10. Fichiers : images, animations, données

| Commande | Effet |
|---|---|
| `GLOAD nom` | charge une image : `.HIR` (ou `.HIZ` compressée) en HIRES, `.IMG` en SPLIT ; depuis le mode texte, le type choisit le mode (`.HIR` par défaut) |
| `GSAVE nom` | enregistre l'image au format du mode (`.HIR` ou `.IMG`) |
| `ANIM nom [n]` | joue l'animation `nom.ANI` n fois (0 ou rien : jusqu'à une touche) ; HIRES plein écran seulement (refusé en SPLIT) ; ESC arrête le programme |
| `SAVE A nom`, `LOAD A nom` | tableau en **texte** (`.TXT` par défaut), modifiable avec EDIT |
| `BSAVE A nom`, `BLOAD A nom` | tableau en **binaire** (`.DAT` par défaut), octets tels quels, modifiable avec HEX ; entiers : octet bas puis octet haut |
| `BSAVE SCREEN nom`, `BLOAD SCREEN nom` | écran texte entier, 1 120 octets (`.SCR` par défaut) ; LORES seulement (`LORES d'abord`) ; le curseur ne bouge pas |
| `FOUND` | fonction : 1 si le dernier `LOAD` ou `BLOAD` a trouvé son fichier, 0 sinon (0 au lancement) |

Le nom s'écrit sans guillemets, avec un lecteur facultatif ; `$1`-`$9` sont permis. Formats
`.HIZ` et `.ANI`, outils de fabrication : README, « HIRES plein écran ».

**Fichiers de données.** `A` est le nom du tableau (`SAVE N$ HOF`, `BLOAD M NIVEAU1`).
`SAVE` et `BSAVE` écrasent un fichier existant sans confirmation.

- **Fichier absent** au `LOAD` ou au `BLOAD` : pas d'erreur, le tableau (ou l'écran) ne
  change pas, et `FOUND` vaut 0. Les autres erreurs arrêtent le programme.

      LOAD S SCORES
      IF FOUND = 0
        FILL S 0
      ENDIF

- **Texte**, au format de CP/M comme EDIT. `SAVE` termine chaque ligne par CR LF et complète
  le dernier enregistrement par `^Z` ; `LOAD` accepte CR LF, LF ou CR, et s'arrête au
  premier `^Z`.
- Une ligne du fichier correspond toujours à une ligne du tableau (pas de commentaires).
  Tableau `$` : la ligne telle quelle, espaces compris, jusqu'au premier 0. Tableau
  d'entiers : les nombres séparés par des espaces (une tabulation compte comme un espace),
  signe `-` permis. Un tableau à une dimension tient sur une seule ligne (tous ses nombres,
  ou toute sa chaîne).
- `LOAD` met d'abord le tableau à 0 : une ligne plus courte laisse la fin de sa ligne à 0 ;
  des lignes en moins laissent le reste du tableau à 0. Des lignes vides en trop sont
  ignorées.
- Erreurs de `LOAD`, avec la ligne du fichier : `ligne trop longue : L n` (trop de
  caractères ou de nombres), `trop de lignes : L n`, `nombre ? : L n` (pas un entier de
  -32768 à 32767). Ce qui a été lu avant reste dans le tableau.
- `SAVE` d'un tableau `$` qui contient un code 1-31 : `code 0-31 : BSAVE` (ces codes ne se
  tapent pas dans EDIT : les attributs passent par `BSAVE`).
- **Binaire** : les fichiers de CP/M n'ont pas de taille à l'octet près (enregistrements de
  128 octets). `BSAVE` complète le dernier enregistrement par des 0. `BLOAD` met le tableau
  à 0 puis lit sa taille : un fichier plus court laisse la fin à 0, ce qui dépasse est
  ignoré. `BLOAD SCREEN` n'efface pas l'écran avant.
- Rien d'autre ne se sauve (ni les variables `A`-`Z`, ni la police) : un programme qui veut
  garder des variables les range dans un tableau.

### 10.1 Fichiers de sprites (`.SPR`)

Un fichier `.SPR` se charge tel quel dans un tableau `$` assez grand
(`BLOAD S$ HEROS.SPR` : le type est à écrire, `BLOAD` met `.DAT` par défaut). Tout est
aligné sur 8 octets, la largeur d'une ligne de HEX : chaque bloc commence en début de ligne,
chaque case d'un sprite tient sur deux lignes (dessin, silhouette). Les sprites se suivent
sans trou, de tailles différentes ; leur nom aide à les retrouver dans HEX et servira à
l'éditeur.

**En-tête du fichier (8 octets)** : `SPR` (signature), version 1, nombre de sprites (1 à
255), genre (0 : sprites, cases de 16 octets ; 1 : tuiles, cases de 8 octets, dessin seul,
§ 16), puis deux octets à 0 (réservés).

**Chaque sprite** : un en-tête de 8 octets (largeur en colonnes 1-4, hauteur en lignes 1-4,
deux octets à 0 réservés, nom de 4 caractères ASCII complété par des espaces : `HER1`), puis
ses cases, ligne par ligne puis colonne par colonne (2 × 2 : haut-gauche, haut-droite,
bas-gauche, bas-droite), 16 octets chacune : le **dessin** (8 octets, de la ligne du haut à
celle du bas), puis la **silhouette** (8 octets, 1 = le point appartient au personnage).

| Dessin | Silhouette | À l'écran |
|---|---|---|
| 0 | 0 | le décor (transparent) |
| 1 | 0 ou 1 | point allumé |
| 0 | 1 | point éteint : le décor y est caché (yeux, contour noir) |

Chaque octet : 6 points dans les bits 5 à 0 (bit 5 à gauche, comme la police de l'Oric),
bits 7 et 6 à 0. Taille : 8 octets, puis par sprite 8 + 16 × largeur × hauteur (1 × 1 : 24
octets ; 4 × 4 : 264). Une animation est une suite de sprites (`HER1`, `HER2`...) affichés
tour à tour dans le même emplacement.

Exemple : un bonhomme de 1 colonne sur 2 lignes, seul dans son fichier (48 octets, dans HEX) :

    0000  53 50 52 01 01 00 00 00   SPR.....   version 1, 1 sprite, genre 0
    0008  01 02 00 00 48 45 52 4F   ....HERO   1 colonne, 2 lignes, HERO
    0010  1E 12 1E 0C 3F 2D 0C 12   ........   case (0,0) : dessin
    0018  1E 1E 1E 0C 3F 2D 0C 12   ........   case (0,0) : silhouette (yeux opaques)
    0020  12 12 33 00 00 00 00 00   ..3.....   case (0,1) : dessin
    0028  12 12 33 00 00 00 00 00   ..3.....   case (0,1) : silhouette

La silhouette suit la convention « 1 = le personnage » (le contraire du masque d'Oricium,
`tuile AND masque OR sprite`). En attendant l'éditeur de sprites, un `.SPR` se fabrique dans
HEX ou par un petit programme qui remplit un tableau `$` et fait `BSAVE`.

## 11. Erreurs

Une erreur arrête le programme : retour à la console, puis `L n COMMANDE : message`
(`L 3 LINE : valeur hors de 0-255`). Dans un programme traduit, les erreurs d'exécution
s'affichent sans numéro de ligne (`Erreur : division par zero`).

| Sujet | Messages |
|---|---|
| Lecture | `commande inconnue`, `parametres ?`, `ligne de plus de 126 car.`, `expression ?`, `variable ? (A a Z)` |
| Valeurs | `valeur hors de 0-255`, `valeur hors limites`, `division par zero`, `pas nul` |
| Modes | `HIRES ou SPLIT d'abord`, `LORES d'abord` |
| Blocs | `NEXT sans boucle`, `NEXT manquant`, `bloc non ferme`, `fin de bloc en trop`, `trop de blocs imbriques`, `RETURN sans CALL`, `SUB introuvable` |
| Tableaux | `deja dimensionne`, `tableau non dimensionne`, `indice hors limites`, `memoire pleine`, `chaine trop longue`, `chaine dans un calcul` |
| Sprites | `SPRITES d'abord`, `SPOOL d'abord`, `fichier .SPR ?` (pas un `.SPR` de sprites, ou sprite mal formé), `plus de caracteres pour les sprites` (tas vide) ; `valeur hors limites` : emplacement, rang du sprite, code du tas, sprite hors de l'écran |
| Fichiers | `Fichier introuvable` et `Fichier trop gros` (le `.GRX`), `image introuvable`, `disque plein`, `animation introuvable`, `animation trop grande` ; données (§ 10) : `ligne trop longue : L n`, `trop de lignes : L n`, `nombre ? : L n`, `code 0-31 : BSAVE` |

Un `ENDIF` oublié après un `IF` vrai n'est pas signalé : le reste s'exécute normalement.

## 12. Traduction en assembleur (GRXASM)

    A>GRXASM MOTIFS
    MOTIFS.ASM ecrit : ASM MOTIFS
    A>ASM MOTIFS
    A>MOTIFS

- La traduction est faite par `GRXASM.COM`, un programme à part (l'interpréteur n'en garde
  pas le code en mémoire). `GRAPHER NOM /A` le lance par CHAIN : la ligne devient
  `GRXASM NOM /A ...`, 78 caractères au plus (`Ligne trop longue`). GRXASM doit être sur un
  lecteur où les commandes sont cherchées.
- La traduction fait la même analyse que l'interpréteur. Les erreurs de syntaxe et de blocs
  sont signalées avec la ligne, et `NOM.ASM` n'est alors pas écrit.
- Le `.ASM` est lisible : chaque ligne du `.GRX` y figure en commentaire. Variables `V_A` à
  `V_Z`, étiquettes `L3T`, `L3E`, `L3X` pour les blocs, `P_NOM` pour les sous-programmes.
- Les parties constantes des expressions sont calculées pendant la traduction (`120+8` donne
  `128`) ; une constante hors de 0-255 est signalée tout de suite.
- `$1`-`$9` sont remplacés au moment de la traduction.
- Les indices et les tableaux ne sont pas vérifiés, pour aller plus vite : si un programme
  traduit se comporte mal, on le relance en interprété pour trouver l'erreur.
- Un tableau doit être déclaré par un `DIM` placé plus haut dans le fichier (la traduction
  lit le fichier dans l'ordre).
- ASM a besoin, sur le lecteur de la source, de `CPA.INC`, `GRX.INC`, `HIRES.INC`, plus
  `ARR.INC` si le programme a des tableaux, `FIL.INC` s'il lit ou écrit des fichiers de
  données (`SAVE`... `FOUND`), `SPR.INC` s'il a des sprites et `ANIM.INC` s'il anime. Ils sont, avec GRXASM,
  sur la disquette complète, la disquette Assembleur et la disquette Animations (pas sur la
  disquette Logo, qui n'a pas ASM).
- Un `.COM` traduit pèse au moins 3 Ko (bibliothèques), puis quelques dizaines d'octets par
  commande. ASM met moins d'une minute pour `MOTIFS`.

## 13. Mémoire, vitesse, limites

- **Mémoire** (interprété) : GRAPHER.COM (13 940 octets) en `$0500`, puis les tables de
  `hires.inc`, les tampons et les variables. Le texte du `.GRX` vient ensuite et s'arrête au plus tard en
  `$9D60`. Les tableaux sont réservés sous `$9D60`, vers le bas, jusqu'à la fin du texte. Une
  animation ou une image `.HIZ` se charge après le texte, sans jamais recouvrir les tableaux.
  Les descripteurs des tableaux occupent `$9D60-$9EFF`. `SPRITES n` réserve sous les tableaux
  5 octets par emplacement et 192 octets pour les deux tas. La zone libre pour le texte, les
  tableaux et une animation fait environ 22 Ko (texte à partir de `$4454`).
- **Vitesse** : 150 à quelques centaines de lignes par seconde en interprété (un ciel de 400
  étoiles, `PLOT 1+RND(238) 1+RND(198)` : 5 s ; traduit : 0,6 s). Un sprite de 1 × 2 cases
  déplacé par `SSHOW` : 2,3 ms dans un programme traduit (environ 1,1 ms par case : retrait
  puis affichage).
- **Limites** : entiers seulement, variables d'une lettre, deux dimensions au plus, ni
  concaténation ni conversion de chaînes.

## 14. Exemples livrés

| Fichier | Contenu |
|---|---|
| `DESSIN.GRX` | mode SPLIT, avec paramètre |
| `ECRAN.GRX` | écran titre en couleurs par attributs (HIRES) |
| `MOTIFS.GRX` | éventail, cercles, ciel étoilé : boucles, hasard, sous-programme |
| `ARDOISE.GRX` | télécran : les flèches dessinent, ESPACE efface, ESC finit (`INKEY`) |
| `FLECHES.GRX` | LORES : un `@` qu'on déplace aux flèches dans un cadre, `SCRN` pour les murs |
| `SERPENT.GRX` | LORES : serpent (corps dans deux tableaux en anneau, `SCRN` pour les collisions) |
| `SCORES.GRX` | meilleurs scores : `INPUT` du nom, tri, titre coloré par un attribut en tête de chaîne ; les cinq meilleurs gardés dans `HOFN.TXT` et `HOFS.TXT` (`LOAD`, `SAVE`, `FOUND`) |
| `SPRITES.GRX` | LORES : un bonhomme mené aux flèches (deux images de marche) et une balle qui rebondit, sur un décor en deux couleurs ; sprites de `HEROS.SPR` |
| `ANIMS.GRX` | animations (disquette Animations) |

## 15. Mise en œuvre

| Fichier | Rôle |
|---|---|
| `progs/grapher.s` | interpréteur (`GRAPHER.COM`) ; `/A` : CHAIN vers GRXASM |
| `progs/grxasm.s` | traducteur (`GRXASM.COM`) |
| `progs/grxd_inc.s`, `progs/grxc_inc.s` | communs aux deux : constantes et page zéro ; lecture du `.GRX` et des lignes, paramètres, table des noms de commandes (les fréquentes en tête), analyse des noms, nombres et fonctions, calcul des constantes, sous-programmes, erreurs. Chaque programme a sa table `cadr` d'adresses des commandes, dans l'ordre de la table des noms, et ses propres affectations (`x_asg`, `x_aasg`), `ANIM` (`an_val`, `an_none`), `ndim_s`, `to_text`, `o_drop` et tampons |
| `progs/grx.inc` (`GRX.INC`) | bibliothèque d'exécution des programmes traduits |
| `progs/arr.inc` (`ARR.INC`) | tableaux et chaînes, commune aux deux (`r_chk` : vérifications en interprété) ; descripteurs en `$9D60` |
| `progs/hires.inc` (`HIRES.INC`) | écran : dessin, LORES (`h_lores`, `h_loc`, `h_chr`...), images |
| `progs/anim.inc` (`ANIM.INC`) | animations `.ANI` |
| `progs/spr.inc` (`SPR.INC`) | sprites (`s_res`, `s_pool`, `s_show`, `s_hide`), commune aux deux ; se sert de `arr.inc` (descripteurs, place sous les tableaux) et de `hz_tad` (`hires.inc`) ; demande au programme l'octet `s_hst` |
| `progs/fil.inc` (`FIL.INC`) | fichiers de données (`SAVE`... `FOUND`), commune aux deux ; enregistrements dans `DEF_DMA` ; demande au programme son FCB (`f_fcb`), l'écriture d'un nombre (`f_fmt`, `f_nbuf`) et deux messages |

Les tampons (noms de fichiers, paramètres, mots...) sont après la fin du programme, mis à 0
au lancement : ils ne sont pas dans le fichier.

Page zéro : `$10-$58` pour GRAPHER et GRXASM, `$10-$27` pour `GRX.INC`, `$B0-$BF` pour
`spr.inc`, `$C0-$C7` pour `hires.inc`, `$C8-$CF` pour `arr.inc`, `$D0-$DF` pour `fil.inc`.

**Sprites** (`spr.inc`) :

- Un **tas** par jeu de caractères : le tableau du programmeur sert de pile (les `sommet`
  premiers éléments sont les codes libres ; prendre : `sommet - 1` puis lire ; rendre :
  écrire puis `sommet + 1` ; l'ordre des codes change, sans importance), son sommet, sa
  taille (96 au plus), et `SOUS` : 96 octets, pour chaque code de 32 à 127 l'octet du décor
  caché par le caractère qui porte ce code (0 : code libre). Les deux `SOUS` et les
  emplacements sont réservés par `SPRITES`, sous les tableaux.
- Un **emplacement** : 5 octets, tas + 1 (0 : libre), colonne, ligne, largeur, hauteur. Le
  rang du sprite n'est pas gardé : `SHIDE` n'a besoin que du rectangle ; les codes pris se
  lisent à l'écran, ce qu'ils cachent dans `SOUS`.
- `SSHOW` : retire l'ancien sprite de l'emplacement ; parcourt le fichier jusqu'au sprite n
  (taille de chaque sprite dans son en-tête) ; en interprété, vérifie le fichier, l'écran,
  puis compte les codes à prendre avant de rien dessiner (rien n'est posé à moitié) ; pour
  chaque case : attribut → rien ; code déjà pris dans ce tas (`SOUS` non nul) → on dessine
  sur lui ; sinon un code pris au tas, `SOUS` reçoit l'octet du décor. Le caractère est
  dessiné (`(décor AND NOT silhouette) OR dessin`, 8 lignes) avant d'être montré ; le bit 7
  (vidéo inverse) du décor est gardé. Traduit, un tas vide laisse la case sans sprite.
- `SHIDE` : pour chaque case du rectangle, si son code a un `SOUS` non nul : le décor revient,
  `SOUS` à 0, le code retourne au tas.
- **Historique des lignes** : `SPOOL ... ALT` met `s_hst` à 1 ; en rendant la console
  (`to_text` de GRAPHER, `g_totext` de `GRX.INC`), le programme vide alors l'historique
  (`$BA80`), recouvert par les dessins du jeu secondaire. Le système n'y est pour rien (aucun
  octet résident) ; après un plantage ou CTRL-C, l'historique peut garder des lignes sans
  sens, sans autre effet.
- Tests : `lo_spr.grx` (affichage, déplacement, chevauchement, attribut, inverse ; dessins
  vérifiés sur une police factice, `NOM.env`), `lo_spr2.grx` (jeu secondaire, historique
  vidé), `e_spr*.grx` (erreurs).

Tests : `tools/test_grapher.sh` vérifie le CHAIN de `/A`, puis exécute chaque cas interprété
(GRAPHER) puis traduit (GRXASM), dans le 6502
simulé (`tools/run_com.py`, sans émulateur), et compare au résultat attendu (`.ref`, `.kref`,
saisies dans `NOM.in`). Puis essai Oricutron des exemples.

## 16. Décidé, pas encore fait

### 16.1 Plus tard

- **`REDIM`** : redimensionner un tableau en gardant les éléments dont les indices existent
  encore (comme `ReDim Preserve`) ; les tableaux déclarés après sont déplacés. ~0,3 à 0,5 Ko.
- **Éditeur de caractères et de sprites** : un `.COM` plein écran qui écrit les `.SPR`.

## 17. Questions ouvertes

- **Tuiles** (fichier `.SPR` de genre 1) : commandes `TILES T$ ...` (dessins copiés dans la
  police) et `TILE n col lig` (codes posés à l'écran) ; comment le programme choisit les
  codes d'une tuile de plusieurs cases (codes consécutifs, ou liste comme pour les tas). Les
  tuiles donneront aussi ses dessins au jeu secondaire.
- Si le parcours du fichier par `SSHOW` est trop lent pour les derniers sprites : table des
  positions construite au chargement.
- Plus tard : sprites qui apportent leur couleur (cases « attribut » dans le fichier, posées
  telles quelles, remises au retrait).
