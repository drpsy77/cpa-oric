# GRAPHER — référence

GRAPHER exécute un fichier texte `.GRX` (écrit avec EDIT) : une commande par ligne, en anglais.
C'est un langage de bas niveau, proche de l'écran. Il manipule des entiers, des variables
d'une ou deux lettres, des tableaux, l'image HIRES ou SPLIT et l'écran texte. Il sert à fabriquer des
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
| `GRXASM NOM /C [p1 ... p9]`, `GRAPHER NOM /C [...]` | traduit, puis enchaîne `ASM NOM /E` : il ne reste que `NOM.COM` (`NOM.ASM` est effacé si l'assemblage réussit ; une erreur le laisse, pour le lire) |

## 2. Écriture d'un programme

- Une commande par ligne, 126 caractères au plus (`ligne de plus de 126 car.`). Le retrait
  est libre. Le texte s'arrête au premier `^Z`. Une tabulation (TAB, code 9) compte comme
  un espace (l'Oric n'en a pas ; `IMPORT nom /T` les remplace déjà à l'arrivée).
- `;` commence un commentaire, en début ou en fin de ligne.
- `$1` à `$9` sont remplacés par les paramètres de la ligne de commande, avec leur casse
  d'origine (`X = $1`, `GTEXT 2 90 $2`).
- **Règle des espaces** : l'espace sépare les paramètres ; une expression parmi plusieurs
  paramètres ne contient donc pas d'espace, sauf entre parenthèses
  (`LINE X 0 (239 - X) 199`). Une expression seule en fin de ligne (`X = ...`, `IF`,
  `WHILE`) peut en contenir, comme les éléments de `PRINT`.
- **Afficher** : `PRINT e1 e2 ...` écrit à la suite des nombres (calculs), des chaînes
  (`A$`, `M$(l)`) et des textes entre guillemets, sans rien entre eux : `PRINT "V= " V`,
  `PRINT A " " B`. Les éléments se séparent par des espaces ; un calcul s'arrête là où il ne
  peut plus continuer (`PRINT A - B " points"`). Dans la console (`TEXT`, `SPLIT`), `PRINT`
  passe à la ligne à la fin, sauf avec un `;` final (`PRINT "Total : " ;`, puis
  `PRINT T`) ; pour un commentaire après, `;;` (`PRINT X ;; reste sur la ligne`). En LORES,
  il ne passe jamais à la ligne (§ 7) ; en HIRES plein écran, il n'affiche rien. `PRINT`
  seul passe à la ligne. Une chaîne suivie de `=`, `<` ou `>` est une comparaison
  (`PRINT A$ = B$` affiche 1 ou 0). `ECHO texte` écrit le texte de la ligne, puis passe à la
  ligne dans la console ; entre guillemets, le texte seul, espaces compris.

## 3. Nombres, variables, expressions

- Entiers de 16 bits signés (-32768 à 32767) ; variables à 0 au départ.
- Nom d'une variable : une lettre (`A` à `Z`), suivie ou non d'une lettre ou d'un chiffre
  (`PX`, `PY`, `N1`), soit 961 variables. Majuscules et minuscules sont confondues. `IF` est
  réservé. Les noms de deux caractères servent aux variables simples seulement : un tableau
  ou une chaîne garde une lettre (`AX(3)` et `AX$` sont refusés).
- Bonne pratique : des variables nommées pour ce qui est unique (le joueur `PX PY`, le score
  `SC`), un tableau pour ce qui se parcourt en boucle (des monstres `X(3) Y(3)`), et les
  constantes écrites en clair. Dans un programme traduit, une variable simple se lit en
  une instruction ; un élément d'un tableau déclaré en tête du programme, de taille
  constante, se lit presque aussi vite (§ 12).
- Affectation : `V = expr` ou `LET V = expr`.
- Opérateurs, du plus fort au plus faible : `-` (signe) ; `*` `/` `%` (`/` tronque vers 0,
  `%` est le reste) ; `+` `-` ; comparaisons `=` `<>` `<` `<=` `>` `>=` (1 si vrai, 0 sinon) ;
  `&` `|` (et, ou bit à bit).
- Parenthèses : `(X * 2)`.

| Fonction | Valeur |
|---|---|
| `RND(n)` | nombre au hasard de 0 à n-1 (tirages successifs indépendants : pas de bandes ni de motifs quand ils servent de coordonnées) |
| `ABS(n)` | valeur absolue |
| `POINT(x,y)` | 1 si le point de l'image est allumé (HIRES ou SPLIT) |
| `SCRN(col,lig)` | octet d'une case de l'écran texte (LORES) |
| `INKEY` | touche, 0 si aucune ; n'attend pas ; sans délai de répétition (§ 8) |
| `FOUND` | 1 si le dernier `LOAD` ou `BLOAD` a trouvé son fichier, 0 sinon (§ 10) |
| `LEN(A$)` | longueur d'une chaîne (§ 9) |

Une lettre suivie de `(` est un tableau ; les fonctions ont des noms de trois lettres ou plus.

## 4. Contrôle

| Bloc | Effet |
|---|---|
| `REPEAT n` ... `NEXT` | n fois (rien si n ≤ 0) |
| `FOR V a b [pas]` ... `NEXT` | V de a à b, pas de 1 par défaut, négatif pour descendre ; rien si a est déjà au-delà de b ; pas nul : `pas nul` |
| `WHILE expr` ... `NEXT` | tant que l'expression n'est pas nulle (`WHILE 1` : sans fin ; ESC arrête en interprété, § 8) |
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
| `PRINT e1 e2 ...` | écrit au curseur, à la suite, nombres, chaînes et textes entre guillemets (`PRINT "Score : " S`), sans passer à la ligne |
| `SPC n [x]` | écrit n fois l'octet x (32 par défaut) : effacer, remettre l'attribut 16, tracer un trait |
| `TAB n` | avance le curseur de n colonnes sans rien écrire (relatif : `LOCATE` donne la colonne absolue) |
| `PRINTV`, `ECHOV`, `SPCV` | comme `PRINT`, `ECHO` et `SPC`, mais le curseur **descend** : un caractère par ligne, dans la même colonne (une colonne de chiffres, un mot vertical, un mur : `SPCV 20 35`). `ECHOV` seul : ligne 0 de la colonne suivante |

- **Bord droit** : rien ne s'écrit au-delà de la colonne 39. Ce qui dépasse est perdu, sans
  erreur ; le curseur reste au bout jusqu'au prochain `LOCATE` ou `ECHO` seul. Rien ne passe
  sur la ligne suivante, et rien ne fait défiler l'écran. En vertical (`PRINTV`...), rien ne
  s'écrit sous la ligne 27, de la même façon.
- Colonne ou ligne hors de l'écran : `valeur hors limites` ; `n` de `SPC` et `TAB`, `x` et
  `code` : 0-255 (`valeur hors de 0-255`).
- Hors LORES, `LOCATE`, `CHAR`, `SCRN`, `SPC`, `TAB`, `PRINTV`, `ECHOV` et `SPCV` donnent
  `LORES d'abord`. En LORES,
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
  l'historique) : les tuiles le dessinent (`TFONT ... ALT`, § 7.3). Un `INPUT` abîme ses codes 64 à 111 ; à
  la fin d'un programme qui s'en est servi, l'historique des lignes est vidé.

### 7.2 Rectangles : copie, défilement, rotation

Ces commandes travaillent sur l'écran texte (LORES) comme sur l'image (HIRES, SPLIT). En LORES,
une case est un caractère (ou un attribut) ; dans l'image, une case est un octet de 6 points
en largeur (colonnes 0-39) et une ligne de points en hauteur (lignes 0-199, ou 0-127 en
SPLIT). Les octets sont copiés tels quels, attributs compris. Dans la console :
`LORES d'abord`.

| Commande | Effet |
|---|---|
| `PASTE T$(c,l) col lig larg haut` | colle à l'écran, coin haut-gauche en (col, lig), le rectangle de `larg` × `haut` cases du tableau `$` à deux dimensions qui commence à `T$(c,l)` (colonne c, ligne l du tableau) |
| `GRAB T$(c,l) col lig larg haut` | l'inverse : copie le rectangle de l'écran dans le tableau |
| `SCROLH n [c1 l1 c2 l2 [x]]` | fait glisser le rectangle de n cases : n > 0 vers la droite, n < 0 vers la gauche. Les cases libérées reçoivent l'octet x : un espace par défaut en LORES, l'octet vide (64) dans l'image |
| `SCROLV n [c1 l1 c2 l2 [x]]` | la même chose en hauteur : n > 0 vers le bas, n < 0 vers le haut |
| `ROTH n [c1 l1 c2 l2]`, `ROTV n [c1 l1 c2 l2]` | rotation : ce qui sort d'un côté rentre de l'autre (n modulo la taille) |

- Sans rectangle, c'est tout l'écran. Le rectangle se donne par ses coins, comme pour `BOX` :
  colonnes c1 à c2, lignes l1 à l2. Hors de l'écran, ou c2 < c1, ou l2 < l1 : `valeur hors
  limites`. n = 0, ou une rotation d'un tour complet : rien. Un défilement d'au moins la
  taille du rectangle le remplit de x.
- `PASTE` et `GRAB` : le rectangle doit tenir dans l'écran (`valeur hors limites`) et dans le
  tableau (`indice hors limites`) ; `larg` et `haut` valent au moins 1. Il n'y a pas de
  découpage automatique aux bords : le programme borne lui-même sa caméra.
- **Sprites** : on ne fait pas glisser ni ne recouvre un décor sous un sprite affiché. On
  retire les sprites (`SHIDE`), puis `PASTE` ou `SCROL...`, puis on les réaffiche (§ 7.1).
- `CLS` met l'attribut 16 partout : un décor collé par `PASTE` le remplace dans sa zone, et
  les colonnes 0-1 gardent leurs attributs si le rectangle commence à la colonne 2.

**Une carte plus grande que l'écran.** La carte est dans un tableau `$` (un octet par case,
attributs permis) ; après chaque pas, `PASTE` redessine la fenêtre depuis le coin de la caméra.
C'est la méthode normale : la position de la caméra suffit à décrire l'écran (déplacements en
diagonale, sauts, retour au début : la même ligne).

    DIM T$(128,64)
    BLOAD T$ CARTE
    LORES
    ...
    WHILE 1
      K = INKEY
      IF K>7 & K<12
        ...                     ; pas du joueur, CX, CY : coin de la camera, bornes
        PASTE T$(CX,CY) 2 1 38 26
      ENDIF
    NEXT

Le redessin se fait seulement après un pas (§ 8, « Boucle de jeu »). Pour une carte bien
plus grande dans la même mémoire, les tuiles (§ 7.3).

**Défiler puis compléter.** Quand le décor n'est pas entier en mémoire (calculé au fur et à
mesure, tiré au hasard, sans fin), on fait glisser la zone de jeu d'une case et on écrit la
bande qui entre : une ligne par `LOCATE` et `SPC` ou `PRINT A$`, une colonne par `PRINTV A$`
ou `SPCV`, ou un `PASTE` d'une ligne ou d'une colonne. Exemple : `DEFILE.GRX` (§ 14).

### 7.3 Tuiles : une grande carte en peu de mémoire

Une **tuile** est un petit dessin de 1 à 4 colonnes sur 1 à 4 lignes de caractères. La carte
est un tableau `$` à deux dimensions dont chaque octet désigne une tuile : une carte de
64 × 32 tuiles de 2 × 2 (2 Ko) donne un monde de 128 × 64 caractères (8 Ko avec `PASTE`).
`TMAP` en dessine une fenêtre ; la caméra avance d'un caractère, pas d'une tuile.

    DIM T$(64,32) D$(4,5) S$(152)
    BLOAD S$ TUILES.SPR       ; dessins des caracteres (genre 1)
    FOR J 0 3                 ; codes de chaque tuile, ligne par ligne
      D$(J,0) = 34            ; eau
      D$(J,1) = 33            ; herbe
      ...
    NEXT
    TILESET D$ 2 2 "~ #^M"    ; tuiles de 2 x 2 ; caracteres de la carte
    LOAD T$ NIVEAU1           ; la carte, ecrite en clair dans EDIT
    LORES
    TFONT S$ 33 ALT           ; dessins copies dans le jeu secondaire
    ...
    TMAP T$ X-19 Y-13 2 1 38 26
    IF TILE(NX,NY) = 1        ; de l'herbe sous le pas ?

| Élément | Effet |
|---|---|
| `TILESET D$ larg haut [K$]` | déclare les tuiles : chaque ligne de `D$` (tableau `$` à deux dimensions) donne les `larg` × `haut` codes d'une tuile, ligne par ligne (1 à 4 de chaque, 256 tuiles au plus) ; `K$` (texte entre guillemets ou chaîne) liste les octets de la carte dans l'ordre des tuiles : `"~ #^M"` fait de `~` la tuile 0, de l'espace la tuile 1... Sans `K$`, l'octet de la carte est le numéro de la tuile |
| `TMAP T$ X Y col lig larg haut` | dessine à l'écran, coin en (col, lig), la fenêtre de `larg` × `haut` cases de la carte `T$` (tableau `$` à deux dimensions) dont le coin est le caractère (X, Y) du monde ; X et Y peuvent sortir de la carte, même être négatifs |
| `TFONT S$ code [ALT]` | copie dans la police (jeu standard, ou secondaire avec `ALT`) les dessins d'un fichier `.SPR` de genre 1 chargé dans `S$` (§ 10.1) : toutes les cases de toutes ses tuiles, dans l'ordre du fichier, sur des codes consécutifs à partir de `code` (32 à 127 ; `ALT` : 32 à 111) |
| `TILE(X,Y)` | fonction : numéro de la tuile sous le caractère (X, Y) du monde, sur la carte du dernier `TMAP` ; 0 hors de la carte, ou avant tout `TMAP` |

- **La tuile 0 comble tout** : un octet de la carte absent de `K$` (ou, sans `K$`, plus
  grand que le dernier numéro), et tout ce qui est hors de la carte, s'affiche comme la
  tuile 0. C'est pratique pour une carte écrite dans EDIT (`LOAD` met des 0 au bout des
  lignes courtes) et pour une île entourée d'eau : la caméra n'a pas besoin d'être bornée.
  Un octet présent deux fois dans `K$` : le premier l'emporte.
- **Coordonnées** : le caractère (X, Y) du monde est dans la tuile (X / larg, Y / haut).
  Ni `TMAP` ni `TILE` ne font de division : quelques soustractions, une fois par commande.
- **Codes** : les tuiles partagent leurs caractères (l'eau ou un mur : un seul caractère
  répété). `TFONT` ne fait que copier les dessins ; c'est `D$` qui assemble les codes.
  Dans un `.SPR` de genre 1, une « tuile » de 1 × 1 est simplement un caractère : le
  fichier peut ne contenir que des caractères, que `D$` assemble en tuiles plus grandes.
- **Jeu secondaire** : les lignes de la carte commencent par l'attribut 9
  (`CHAR 0 L 9`) ; tout le jeu (codes 32 à 111) est alors aux tuiles, et le texte des
  autres lignes garde le jeu standard. Le jeu secondaire n'a pas de dessins à lui : même
  le vide (l'herbe) doit en recevoir un. Mêmes réserves que pour les sprites (§ 7.1) :
  `INPUT` abîme les codes 64 à 111, et l'historique des lignes est vidé à la fin.
- **Mémoire** : `TILESET` réserve sous les tableaux (larg × haut + 1) × 256 octets (2 × 2 :
  1 280 ; 4 × 4 : 4 352), alignés sur une page, une fois ; un `TILESET` suivant les reprend,
  ou réserve de nouveau s'il lui en faut plus. Il prépare une table par place dans la
  tuile (octet de la carte → code affiché) : environ 50 ms pour des tuiles de 2 × 2.
- **Vitesse** de `TMAP` (fenêtre de 38 × 26, programme traduit ou interprété : c'est la même
  routine) : tuiles de 1 × 1, environ 35 ms ; 2 × 2, 55 ms ; 4 × 4, 43 ms (`PASTE` : 22 ms).
  On ne redessine qu'après un pas (§ 8, « Boucle de jeu »).
- **Sprites** : un sprite passe sur les tuiles comme sur tout décor (§ 7.1) : la tuile
  reste visible autour de sa silhouette. Sur les lignes de la carte en jeu secondaire, son
  tas est déclaré avec `ALT` (`SPOOL T ALT`, `SSHOW ... ALT`), sur des codes que les tuiles
  n'utilisent pas. Comme pour `PASTE` (§ 7.2), retirer les sprites avant `TMAP`, puis les
  réafficher.
- `TMAP` et `TFONT` demandent le LORES (`LORES d'abord`). Erreurs (interprété) :
  `TILESET d'abord` ; `valeur hors limites` (tuile de plus de 4, fenêtre hors de l'écran,
  codes de `TFONT` hors du jeu) ; `indice hors limites` (ligne de `D$` trop courte, `K$`
  plus long que la liste des tuiles, carte à une dimension) ; `fichier .SPR ?` (`TFONT`
  sur un fichier qui n'est pas de genre 1). Traduit : rien n'est vérifié ; `TMAP` sans
  `TILESET` ne fait rien.

Exemple complet : `CARTE.GRX` (§ 14).

## 8. Touches et temps

| Élément | Effet |
|---|---|
| `INKEY` | fonction, comme `KEY$` du BASIC : vide le tampon du clavier et rend la touche tapée depuis le dernier `INKEY`, sinon celle qui est encore enfoncée, sinon 0. Sans délai de répétition : pour les jeux d'action |
| `GET V` | attend une touche et range son code dans V ; suit le délai et la cadence de répétition du clavier (menu Clavier) |
| `WAIT` | attend une touche, sans la garder |
| `DELAY n` | attend n cinquantièmes de seconde, sans regarder le clavier |

Codes des flèches : 8 gauche, 9 droite, 10 bas, 11 haut ; avec SHIFT 240 à 243, avec CTRL
244 à 247 (même ordre). CTRL + lettre : 1 à 26, sauf CTRL-H à CTRL-K : 28 à 31. Une touche tapée pendant
l'exécution est gardée pour `WAIT`, `GET` ou `INKEY`.

**ESC est la touche de l'interpréteur, pas celle du programme.**

- **En interprété**, ESC arrête le programme à tout moment : entre deux lignes, dans une
  boucle, pendant `GET`, `WAIT`, `INPUT` et `ANIM` (message `Interrompu`). Le programme ne
  le voit jamais : c'est la sortie de secours de la mise au point.
- **Dans un programme traduit** (§ 12), ESC n'arrête plus rien : le programme a la main sur
  tout. `INKEY`, `GET` et `WAIT` le rendent comme une autre touche (27), `INPUT` l'ignore,
  `ANIM` s'arrête comme sur une autre touche. Une boucle qui ne prévoit pas de sortie ne
  s'arrête que par le bouton RESET, qui rend le système.
- **La sortie d'un jeu se fait donc par une autre touche**, choisie par le programme (Q dans
  les exemples, `IF K = 81 | K = 113` pour Q majuscule ou minuscule), qui marche de la même
  façon dans les deux modes. Un programme traduit peut aussi donner un rôle à ESC (menu,
  inventaire) avec `IF K = 27`, qui ne sert jamais en interprété.

**Boucle de jeu : ne redessiner que ce qui change.** Avec `INKEY`, la boucle tourne sans
attendre : si elle redessine l'écran à chaque tour (`PASTE`, `CLS`, un score), l'image
scintille, car elle est sans cesse effacée et réécrite pendant que le balayage l'affiche.
`GET` cachait le problème en arrêtant la boucle jusqu'à la touche suivante, mais il subit le
délai et la cadence de répétition du clavier. La bonne forme : lire la touche, et ne
calculer puis redessiner que si elle a changé quelque chose ; le dessin va dans un
sous-programme, appelé une fois avant la boucle.

    CALL DESSIN                 ; premier affichage
    WHILE 1
      K = INKEY
      IF K>7 & K<12             ; une fleche : deplacement, puis dessin
        ...                     ; nouvelle position, verifiee
        CALL DESSIN
      ENDIF
      IF K = 81 | K = 113       ; Q ou q : fin
        END
      ENDIF
    NEXT

Une touche maintenue est rendue à chaque tour par `INKEY` : le déplacement suit la vitesse
de la boucle, bien plus grande dans un programme traduit. Un `DELAY n` après le dessin
règle la vitesse du jeu.

## 9. Tableaux et chaînes

**Noms.** Chaque lettre sert à trois choses indépendantes : `A` (entier), `A(...)` (tableau
d'entiers de 16 bits), `A$` (tableau d'octets 0-255 : chaîne ou grille de caractères).

**DIM.** `DIM S(10) N$(12,10) M$(38,25)`

- Une ou deux dimensions. Deux dimensions s'écrivent dans l'ordre de l'écran de l'Oric
  (`LOCATE col lig`, `SCRN(col,lig)`) : colonnes, puis lignes. `DIM M$(38,25)` donne 25
  lignes de 38 cases, et `M$(X,Y)` est la case de la colonne X dans la ligne Y. En mémoire,
  les lignes se suivent, chacune de ses 38 cases. Un `.GRX` écrit dans l'ordre (ligne,
  colonne) des versions précédentes se convertit sur le PC par `tools/grx_colig.py`. Plusieurs tableaux par ligne. Les tailles sont des expressions, au
  moins 1.
- Indices de 0 à n-1, comme en C : `DIM A(10)` donne `A(0)` à `A(9)`. Éléments à 0.
- Un tableau se déclare une seule fois (`deja dimensionne`) et avant usage (`tableau non
  dimensionne`). Pas de place : `memoire pleine`, dès le `DIM`. La mémoire n'est jamais
  libérée ni agrandie.

**Éléments.**

- `A(i)`, `A(c,l)` : dans un calcul, ou à gauche de `=` (`A(I,J) = A(I,J) + 1`).
- `A(k)` sur un tableau à deux dimensions : l'élément k du tableau mis à plat, ligne après
  ligne (`G(7)` est `G(3,1)` sur `DIM G(4,3)`).
- `A$(i)` (une dimension) et `M$(c,l)` : le code d'une case, en lecture et en écriture
  (`M$(X,Y) = 35`).

**Chaînes.** `A$` (tableau `$` à une dimension) et `M$(l)` (ligne l d'un tableau `$` à deux
dimensions) sont des chaînes. Une chaîne s'arrête au premier 0, ou à la fin de sa capacité si
elle est pleine : `DIM N$(12)` contient 12 caractères au plus. Une chaîne fait au plus 255
caractères ; un tableau `$` plus grand se lit case par case. Un tableau de chaînes est un
tableau `$` à deux dimensions (`N$(12,10)` : 10 noms de 12 caractères au plus).

| Élément | Effet |
|---|---|
| `A$ = "texte"`, `A$ = B$`, `M$(I) = A$` | affectation ; le reste de la capacité est mis à 0 ; trop long : `chaine trop longue` |
| `=` `<>` `<` `<=` `>` `>=` | comparaison de deux chaînes ou d'une chaîne et d'un texte (`IF R$ = "O"`), dans l'ordre des codes (`"AB" < "ABC"`) ; 1 ou 0 |
| `LEN(A$)`, `LEN(M$(I))` | longueur |
| `PRINT A$` | en LORES : au curseur, codes 0-31 écrits tels quels (une ligne de niveau garde ses couleurs). Dans la console : codes 0-31 remplacés par un espace. Avec d'autres éléments : `PRINT "Nom : " A$` (§ 2). `PRINT A$ = B$` affiche la comparaison |
| `INPUT A$`, `INPUT M$(I)` | saisie. En LORES : au curseur (case en vidéo inverse), caractères 32-126, DEL efface, RETURN valide, arrêt à la capacité ou au bord droit. Ailleurs : saisie de ligne de la console, coupée à la capacité |
| `INPUT V` | entier de -32768 à 32767 : chiffres et `-`, 6 caractères au plus ; vide ou hors limites : un son, et on recommence |
| `FILL A v`, `FILL M$ 32` | tout le tableau à v |

- Une chaîne ne se mélange pas aux calculs (`chaine dans un calcul`). Il n'y a ni
  concaténation ni conversion en mémoire ; à l'affichage, `PRINT` met bout à bout textes,
  nombres et chaînes (§ 2).
- `ECHO` n'écrit que le texte du programme (`ECHO A$` écrit « A$ »).
- Un attribut 0 ne peut pas être affiché par `PRINT` (c'est la fin de chaîne) : on l'écrit par
  `CHAR` ou `M$(X,Y) = 0`.
- Pas d'`INPUT` d'un élément : `INPUT V` puis `A(I) = V`.
- En interprété, chaque accès vérifie le tableau et ses indices (`indice hors limites`). Un
  programme traduit ne vérifie rien (§ 12).

## 10. Fichiers : images, animations, données

| Commande | Effet |
|---|---|
| `GLOAD nom` | charge une image : `.HIR` (ou `.HIZ` compressée) en HIRES, `.IMG` en SPLIT ; depuis le mode texte, le type choisit le mode (`.HIR` par défaut) |
| `GSAVE nom` | enregistre l'image au format du mode (`.HIR` ou `.IMG`) |
| `ANIM nom [n]` | joue l'animation `nom.ANI` n fois (0 ou rien : jusqu'à une touche) ; HIRES plein écran seulement (refusé en SPLIT) ; ESC arrête le programme en interprété ; dans un programme traduit, ESC finit l'animation comme une autre touche |
| `SAVE A nom`, `LOAD A nom` | tableau en **texte** (`.TXT` par défaut), modifiable avec EDIT |
| `BSAVE A nom`, `BLOAD A nom` | tableau en **binaire** (`.DAT` par défaut), octets tels quels, modifiable avec HEX ; entiers : octet bas puis octet haut |
| `BSAVE SCREEN nom`, `BLOAD SCREEN nom` | écran texte entier, 1 120 octets (`.SCR` par défaut) ; LORES seulement (`LORES d'abord`) ; le curseur ne bouge pas |
| `FOUND` | fonction : 1 si le dernier `LOAD` ou `BLOAD` a trouvé son fichier, 0 sinon (0 au lancement) |

Le nom s'écrit sans guillemets, avec un lecteur facultatif ; `$1`-`$9` sont permis. Formats
`.HIZ` et `.ANI`, outils de fabrication : README, « HIRES plein écran ».

**Fichiers de données.** `A` est le nom du tableau (`SAVE N$ HOF`, `BLOAD M NIVEAU1`).
`SAVE` et `BSAVE` remplacent un fichier existant sans confirmation, sans risque de le perdre :
ils écrivent `NOM.$$$`, puis effacent l'ancien fichier et renomment (comme EDIT). Il faut donc
la place du nouveau fichier en plus de l'ancien. `disque plein` (ou `code 0-31 : BSAVE` en
cours d'écriture) : l'ancien fichier n'a pas changé, `NOM.$$$` est effacé. `repertoire plein`,
`fichier protege` (R/O) : rien n'est écrit. Un RESET pendant l'écriture laisse l'ancien fichier
ou le nouveau ; au pire le nouveau est complet dans `NOM.$$$` (`REN NOM.EXT=NOM.$$$`).

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
- Ce que contient le fichier selon la commande, et les pièges (CR LF, attributs, largeurs) :
  § 10.2.
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
copiées dans la police par `TFONT`, § 7.3), puis deux octets à 0 (réservés).

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

### 10.2 Du tableau ou de l'écran au fichier : ce qu'on obtient

Un tableau `$` déclaré `DIM T$(c,l)` a `l` lignes (0 à l-1) de `c` octets (colonnes 0 à
c-1) ; les octets sont rangés ligne après ligne. Ce que chaque commande en fait :

| | `SAVE T$ nom` (texte) | `BSAVE T$ nom` (binaire) | `BSAVE SCREEN nom` |
|---|---|---|---|
| Contenu | une ligne de fichier par ligne du tableau : ses octets jusqu'au premier 0, au plus `c` | les `l` × `c` octets, à la suite, sans séparateur | les 28 lignes de 40 cases de l'écran, colonnes 0-1 (attributs) comprises : 1 120 octets |
| Fin de ligne | CR LF, **ajoutés par `SAVE`** | aucune | aucune |
| Octets permis | 32-255 ; un code 1-31 arrête le programme (`code 0-31 : BSAVE`) | tous | tous |
| Fin du fichier | dernier enregistrement complété par `^Z` | complété par des 0 | complété par des 0 |
| Pour | EDIT, `LOAD` | HEX, `BLOAD` | HEX, `BLOAD SCREEN` |

Conséquences pratiques :

- **Ne pas écrire soi-même CR et LF** dans un tableau destiné à `SAVE` : ce sont des codes
  0-31, refusés ; `SAVE` les ajoute à chaque ligne.
- **`BSAVE` n'écrit pas un texte.** Ouvert dans EDIT, un `.DAT` est un seul paragraphe (pas
  de CR LF), terminé par des octets nuls ; si l'on y range soi-même CR et LF, EDIT les
  comprend, mais la fin reste faite de 0 au lieu de `^Z`. EDIT lit CR LF ou un LF seul
  comme une fin de paragraphe, et un CR qui n'est pas suivi de LF comme une fin de plus
  (donc LF puis CR donne une ligne vide entre deux lignes).
- **Les espaces sont écrits, les 0 non** : une ligne s'arrête au premier 0, mais les espaces de
  fin de ligne restent dans le fichier.
- **Largeurs** : l'écran a 40 colonnes, dont les deux premières sont des attributs ; EDIT en
  montre 38. Un tableau de 38 colonnes pris sur les colonnes 2-39 de l'écran donne des lignes
  qui remplissent exactement une ligne d'EDIT. Une ligne plus longue que les colonnes du
  tableau arrête `LOAD` (`ligne trop longue : L n`).
- **Écran du LORES** : après `LORES` ou `CLS`, chaque case contient l'attribut 16 (papier
  noir), pas un espace. `GRAB` d'une zone jamais écrite, puis `SAVE`, donne `code 0-31 :
  BSAVE` : remplir d'abord la zone d'espaces (`SPC`). Les colonnes 0-1 contiennent des
  attributs : commencer le `GRAB` à la colonne 2. Un caractère en vidéo inverse (code + 128)
  passe tel quel.
- **Tableau d'entiers** : `SAVE` écrit les nombres d'une ligne séparés par un espace
  (`DIM N(3,2)` donne deux lignes `0 0 0`) ; `BSAVE` écrit chaque entier sur deux octets, bas
  puis haut (-5 : `FB FF`).
- **Taille sur la disquette** : toujours un multiple de 128 octets (`BSAVE SCREEN` : 1 152).
  `BLOAD` lit seulement la taille du tableau ; le reste est ignoré.

Exemple : l'écran texte en fichier lisible et modifiable dans EDIT, puis relu.

    DIM T$(38,28)
    LORES
    FOR Y 0 27
      LOCATE 2 Y
      SPC 38             ; des espaces, pas l'attribut 16
    NEXT
    ; ... dessin du texte avec LOCATE, ECHO, CHAR ...
    GRAB T$(0,0) 2 0 38 28
    SAVE T$ ECRAN        ; ECRAN.TXT : 28 lignes de 38 caracteres + CR LF
    ; plus tard, ou dans un autre programme :
    LOAD T$ ECRAN
    PASTE T$(0,0) 2 0 38 28

Les couleurs (attributs, codes 0-31) ne passent pas par `SAVE` : pour un écran en couleurs,
`BSAVE SCREEN` (tout l'écran) ou `BSAVE` d'un tableau, retouchés avec HEX.

## 11. Erreurs

Une erreur arrête le programme : retour à la console, puis `L n COMMANDE : message`
(`L 3 LINE : valeur hors de 0-255`). Un programme traduit ne vérifie rien pendant
l'exécution (§ 12) ; il ne lui reste que les erreurs qui ne sont pas des fautes du programme,
sans numéro de ligne : fichiers (`Erreur : disque plein`...), `memoire pleine` à un `DIM`
de taille calculée. ESC ne l'arrête pas (§ 8). Les messages sont en français sur `cpa.dsk`,
en anglais sur `cpa-en.dsk` (ceux de GRXASM et des programmes traduits aussi).

| Sujet | Messages |
|---|---|
| Lecture | `commande inconnue`, `parametres ?`, `ligne de plus de 126 car.`, `expression ?`, `variable ? (A, AB ou A1)` |
| Valeurs | `valeur hors de 0-255`, `valeur hors limites`, `division par zero`, `pas nul` |
| Modes | `HIRES ou SPLIT d'abord`, `LORES d'abord` |
| Blocs | `NEXT sans boucle`, `NEXT manquant`, `bloc non ferme`, `fin de bloc en trop`, `trop de blocs imbriques`, `RETURN sans CALL`, `SUB introuvable` |
| Tableaux | `deja dimensionne`, `tableau non dimensionne`, `indice hors limites`, `memoire pleine`, `chaine trop longue`, `chaine dans un calcul` |
| Sprites | `SPRITES d'abord`, `SPOOL d'abord`, `fichier .SPR ?` (pas un `.SPR` de sprites, ou sprite mal formé), `plus de caracteres pour les sprites` (tas vide) ; `valeur hors limites` : emplacement, rang du sprite, code du tas, sprite hors de l'écran |
| Fichiers | `Fichier introuvable` et `Fichier trop gros` (le `.GRX`), `image introuvable`, `disque plein`, `repertoire plein`, `fichier protege`, `animation introuvable`, `animation trop grande` ; données (§ 10) : `ligne trop longue : L n`, `trop de lignes : L n`, `nombre ? : L n`, `code 0-31 : BSAVE` |

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
  `V_Z` (dans `GRX.INC`) et `V_PX`, `V_N1`... (réservées à la fin de `NOM.ASM`, seulement
  celles que le programme utilise), étiquettes `L3T`, `L3E`, `L3X` pour les blocs, `P_NOM`
  pour les sous-programmes, `B1`, `B2`... pour les boucles `FOR` et `REPEAT`. Pour tenir peu
  de place sur la disquette, une instruction est précédée d'un seul espace ; étiquettes et
  directives (`.byt`, `.word`, `*=`) sont en colonne 1.
- Code produit, en plus des constantes calculées :
  - un opérande de droite simple (un nombre ou une variable, sans rien qui lie plus fort
    après lui : `K = 9`, `X - Y`, `N + 1`) va directement dans `g_et`, sans passer par la
    pile des valeurs ; l'opération est faite à l'envers (`<` devient `>`, `X - 2` devient
    `X + (-2)`, `X - Y` appelle `g_rsub`). `/` et `%` passent toujours par la pile ;
  - `IF` et `WHILE` testent directement le résultat d'une comparaison, d'un `&` ou d'un `|`
    (drapeau Z rendu par `g_cmp`, `g_and`, `g_or`) ;
  - `V = V + 1` et `V = V - 1` (rien d'autre sur la ligne) deviennent `inc` et `dec` ;
  - une constante dont les deux octets sont égaux (`0`, `-1`, `257`) est chargée une fois.
- Les parties constantes des expressions sont calculées pendant la traduction (`120+8` donne
  `128`) ; une constante hors de 0-255 est signalée tout de suite.
- `$1`-`$9` sont remplacés au moment de la traduction.
- **Aucun contrôle à l'exécution.** L'interprété sert à la mise au point ; le programme
  traduit va droit au but, sous la responsabilité du programmeur (comme en C). Si un
  programme traduit se comporte mal, on le relance en interprété pour trouver l'erreur.
  - Vérifié pendant la traduction (avec le numéro de ligne) : la syntaxe et les blocs, une
    constante hors de 0-255 (paramètre ou octet d'un tableau `$`), un pas constant nul, une
    division par une constante nulle, la profondeur des expressions.
  - Plus vérifié du tout : un paramètre calculé hors de 0-255 (seul son octet bas compte),
    une colonne ou une ligne hors de l'écran, une commande du LORES hors du LORES, les
    indices et les tableaux, une chaîne trop longue (coupée à la capacité), une division par
    zéro (le résultat n'a pas de sens), un pas calculé nul (la boucle ne finit pas), ESC (une
    touche comme une autre, § 8).
  - Un paramètre qui est une variable simple se lit en une instruction (`lda V_L`, son
    octet bas).
- Un tableau doit être déclaré par un `DIM` placé plus haut dans le fichier (la traduction
  lit le fichier dans l'ordre).
- **Tableaux à adresse fixe.** Un `DIM` de tailles constantes (`DIM X(8) G$(16,16)`),
  hors de tout bloc (ni `IF`, ni boucle, ni `SUB`), premier `DIM` de ce tableau, est
  réservé au lancement du programme, avant la première ligne : son adresse est connue à
  la traduction (`T_X` pour `X()`, `C_G` pour `G$()`, écrites à la fin de `NOM.ASM`).
  Ses éléments sont alors lus et écrits sans passer par le descripteur :
  - indices constants : une adresse fixe (`S(3)` : `lda T_S+6`) ; `A - S(3)` va
    directement dans l'opérande de droite, comme une variable ;
  - tableau de 256 octets au plus (128 entiers), indices calculés : le décalage est mis
    dans Y (`lda T_X,y`) ; avec deux indices, une table du début de chaque ligne
    (`TR_G`, quelques octets dans le fichier) évite la multiplication. `X(I)` ou
    `G(I,J)` (indices constants ou variables simples) passe aussi directement dans
    l'opérande de droite ;
  - tableau plus grand, indices calculés : par le descripteur.

  Le descripteur est écrit aussi (`LOAD`, `SAVE`, `FILL`, `SPRITES` et les chaînes s'en
  servent). Un `DIM` de taille calculée, ou dans un bloc, reste exécuté à sa place.
  Exemple mesuré : 8 « monstres » déplacés 50 fois (tableaux `X Y D E` de 8 entiers,
  grille `G$(16,16)`) : 3,2 fois moins d'instructions que par les descripteurs, et un
  programme un peu plus petit.
- **Bibliothèques.** GRXASM recopie à la fin de `NOM.ASM` les seules routines dont le
  programme a besoin (celles qu'il appelle, et celles qu'elles appellent), prises dans
  `GRX.INC` et `HIRES.INC` toujours (`HIRES.INC` tient aussi l'écran texte : `h_init`,
  `h_text`, `PRINT`), plus `ARR.INC` si le programme a des tableaux ou des chaînes (un
  `PRINT "..."` suffit), `FIL.INC` s'il
  lit ou écrit des fichiers de données (`SAVE`... `FOUND`), `SPR.INC` s'il a des sprites et
  `ANIM.INC` s'il anime. Ces fichiers sont cherchés sur le lecteur du `.GRX`, puis sur les
  lecteurs déjà lus de A: à D: (la disquette système en A:, le projet en B:) ; sinon :
  `GRX.INC absente (bibliotheque)`. ASM n'a ensuite besoin que de `CPA.INC`, cherché de même.
  Pour CARTE, `NOM.ASM` fait 46 Ko : `/C` ne laisse que `NOM.COM` (8 Ko). Ils sont,
  avec GRXASM, sur la disquette complète, la disquette Assembleur et la disquette
  Animations (pas sur la disquette Logo, qui n'a pas ASM).
- Taille d'un `.COM` traduit : 1,4 Ko pour `ARDOISE`, 1,7 Ko pour `DESSIN`, 2,2 Ko pour
  `MOTIFS`, 4,0 Ko pour `SERPENT`, 6,0 Ko pour `SPRITES` (les contrôles retirés en ont ôté
  4 à 15 %). `NOM.ASM` est plus long (10 Ko pour `DESSIN`, 34 Ko pour
  `SPRITES`) : il faut la place sur la disquette pendant la traduction. ASM met moins d'une
  minute pour `MOTIFS`.

## 13. Mémoire, vitesse, limites

- **Mémoire** (interprété) : GRAPHER.COM (17 756 octets) en `$0500`, puis les tables de
  `hires.inc`, les tampons et les variables. Le texte du `.GRX` vient ensuite et s'arrête au plus tard en
  `$9D60`. Les tableaux sont réservés sous `$9D60`, vers le bas, jusqu'à la fin du texte. Une
  animation ou une image `.HIZ` se charge après le texte, sans jamais recouvrir les tableaux.
  Les descripteurs des tableaux occupent `$9D60-$9EFF`. `SPRITES n` réserve sous les tableaux
  5 octets par emplacement et 192 octets pour les deux tas ; `TILESET`, (larg × haut + 1)
  pages (§ 7.3). La zone libre pour le texte, les tableaux et une animation fait environ
  17 Ko (texte à partir de `$5A05`) : `VAISSEAU.ANI` (12,5 Ko) s'y joue, pas `CUBE.ANI`
  ni `BALLE.ANI` (18 et 21 Ko), qui demandent la traduction.
- **Mémoire** (traduit) : le programme en `$0500`, puis les tables de `hires.inc`. Les
  tableaux sont réservés sous `$9D60` comme en interprété : les tableaux fixes (§ 12) au
  lancement, dans l'ordre des `DIM`, puis les autres à leur `DIM`.
- **Tailles d'un programme traduit** (mesure des onze exemples, `files/*.grx` ; part du
  programme séparée de celle des bibliothèques) :

  | | Par octet de `.GRX` | Par ligne de `.GRX` | CARTE (96 lignes, 2,1 Ko) |
  |---|---:|---:|---:|
  | `NOM.ASM`, programme | 6,4 à 7,0 octets | ~10 lignes, ~140 octets | 14,2 Ko |
  | `NOM.ASM`, bibliothèques | — | — | 32,0 Ko |
  | `NOM.COM`, programme | 1,15 à 1,35 octet | ~25 octets | 2,6 Ko |
  | `NOM.COM`, bibliothèques | — | — | 5,8 Ko |

  Le compilé fait donc à peu près le `.GRX` en clair, plus les routines de bibliothèque
  utilisées : 0,8 Ko (ARDOISE) à 5,8 Ko (CARTE) dans les exemples. Le `.ASM`
  intermédiaire fait environ 6,5 fois le `.GRX`, plus le texte des routines recopiées (5
  à 32 Ko ; les six bibliothèques font 69 Ko sur la disquette, aucun programme ne les
  prend toutes). Un `.GRX` ne dépasse pas ~17 Ko en interprété (texte et tableaux
  ensemble) ni ~21 Ko pour GRXASM (texte de `$48AF` à `$9CE0`). Pire cas pour un `.GRX`
  de 17 Ko : `.ASM` de 145 à 175 Ko et `.COM` d'environ 30 Ko, présents ensemble pendant
  l'assemblage, soit ~200 Ko sur la disquette de projet (336 Ko) ; `/C` n'y laisse ensuite
  que le `.COM`. La limite qui compte est la mémoire : le `.COM` et ses tableaux tiennent
  entre `$0500` et `$9D60` (~38 Ko) ; 30 Ko de code ne laissent que ~8 Ko de tableaux.
- **Vitesse** : 150 à quelques centaines de lignes par seconde en interprété (un ciel de 400
  étoiles, `PLOT 1+RND(238) 1+RND(198)` : 5 s ; traduit : 0,6 s). Un sprite de 1 × 2 cases
  déplacé par `SSHOW` : 2,3 ms dans un programme traduit (environ 1,1 ms par case : retrait
  puis affichage). Une zone de 38 × 26 cases (programme traduit, mesure du 6502 simulé,
  estimée en cycles) : `PASTE` ou `SCROLV`, environ 20 ms (une trame) ; `TMAP`, 35 à 55 ms
  selon la taille des tuiles (§ 7.3) ; `SCROLH`, `ROTH`,
  environ 40 ms (chaque ligne passe par un tampon) ; `ROTV n` : n passes d'une ligne, dans le
  sens le plus court. Dans l'image, compter 8 000 octets pour tout le HIRES : environ 150 ms.
  Sans contrôles à l'exécution (§ 12), une boucle de 1 000 `RND` et `CHAR` va 2,2 fois plus
  vite qu'avec, et 1 064 `LOCATE` et `CHAR` 1,65 fois (6502 simulé, en instructions).
- **Limites** : entiers seulement, variables d'une ou deux lettres (tableaux et chaînes : une
  lettre), deux dimensions au plus, ni
  concaténation ni conversion de chaînes.

## 14. Exemples livrés

| Fichier | Contenu |
|---|---|
| `DESSIN.GRX` | mode SPLIT, avec paramètre |
| `ECRAN.GRX` | écran titre en couleurs par attributs (HIRES) |
| `MOTIFS.GRX` | éventail, cercles, ciel étoilé : boucles, hasard, sous-programme |
| `ARDOISE.GRX` | télécran : les flèches dessinent, ESPACE efface, Q finit (`INKEY`) |
| `FLECHES.GRX` | LORES : un `@` qu'on déplace aux flèches dans un cadre, `SCRN` pour les murs |
| `SERPENT.GRX` | LORES : serpent (corps dans deux tableaux en anneau, `SCRN` pour les collisions) |
| `SCORES.GRX` | meilleurs scores : `INPUT` du nom, tri, titre coloré par un attribut en tête de chaîne ; les cinq meilleurs gardés dans `HOFN.TXT` et `HOFS.TXT` (`LOAD`, `SAVE`, `FOUND`) |
| `SPRITES.GRX` | LORES : un bonhomme mené aux flèches (deux images de marche) et une balle qui rebondit, sur un décor en deux couleurs ; sprites de `HEROS.SPR` |
| `CARTE.GRX` | LORES : une île de 64 × 32 tuiles de 2 × 2 (128 × 64 caractères) tirée au hasard dans `T$` (lacs, arbres, montagnes, murs), écrite en clair (`TILESET` avec `K$`), vue par une fenêtre de 38 × 26 centrée sur le joueur (`TMAP` ; hors de l'île, la tuile 0 : la mer) ; dessins de `TUILES.SPR` dans le jeu secondaire (`TFONT ... ALT`) ; on ne marche que sur l'herbe (`TILE`) ; flèches (`INKEY`, redessin seulement après un pas, sous-programme `CALC`), Q : fin |
| `DEFILE.GRX` | LORES : une route qui défile vers le bas (`SCROLV`, puis la ligne neuve en haut) ; flèches gauche et droite, `INKEY` |
| `ANIMS.GRX` | animations (disquette Animations) |
| `ROTSCROL.GRX` | Démonstration de LOAD, PASTE, SCROLV/H, ROTV/H |
| `JEU.GRX` | FILL, PASTE, ROTV/H local. Remettre les couleurs à leur place |

## 15. Mise en œuvre

| Fichier | Rôle |
|---|---|
| `progs/grapher.s` | interpréteur (`GRAPHER.COM`) ; `/A` : CHAIN vers GRXASM |
| `progs/grxasm.s` | traducteur (`GRXASM.COM`) |
| `progs/grxd_inc.s`, `progs/grxc_inc.s` | communs aux deux : constantes et page zéro ; lecture du `.GRX` et des lignes, paramètres, table des noms de commandes (les fréquentes en tête), analyse des noms, nombres et fonctions, calcul des constantes, sous-programmes, erreurs. Chaque programme a sa table `cadr` d'adresses des commandes, dans l'ordre de la table des noms, et ses propres affectations (`x_asg`, `x_aasg`), `ANIM` (`an_val`, `an_none`), `ndim_s`, `to_text`, `o_drop` et tampons |
| `progs/grx.inc` (`GRX.INC`) | bibliothèque d'exécution des programmes traduits |
| `progs/msg/fr/`, `progs/msg/en/` | messages, mêmes étiquettes dans les deux langues : `grapher.msg`, `grxasm.msg` (et les commentaires du `.ASM` produit), `grxc.msg` (communs), un par bibliothèque (`grx.msg`, `arr.msg`, `fil.msg`, `spr.msg`, `anim.msg`). GRAPHER, GRXASM et VOIR les incluent à part (ASM n'a qu'un niveau d'inclusion) ; dans la bibliothèque, une ligne `;#msg nom.msg` marque leur place, et `tools/strip_inc.py` les y recopie dans la langue de la disquette (`build/src`, `build/src-en`). `g_m_el` : longueur du préfixe d'erreur de `GRX.INC`, que `FIL.INC` saute |
| `progs/arr.inc` (`ARR.INC`) | tableaux et chaînes, commune aux deux (`r_chk` : vérifications en interprété) ; descripteurs en `$9D60` ; rectangles de l'écran (`r_blit`, `r_scrl`, `r_sdef`, `r_rows`) |
| `progs/hires.inc` (`HIRES.INC`) | écran : dessin, LORES (`h_lores`, `h_loc`, `h_chr`...), écriture verticale (`h_lvon`, `h_lvoff`), images ; `h_buf` : 40 octets libres après ses tables (tampon de `r_scrl`) |
| `progs/anim.inc` (`ANIM.INC`) | animations `.ANI` ; l'`ANIM` des programmes traduits (`a_grx`) est dans `GRX.INC`, pour ne rien coûter à l'interpréteur ni à VOIR |
| `progs/spr.inc` (`SPR.INC`) | sprites (`s_res`, `s_pool`, `s_show`, `s_hide`) et tuiles (`t_set`, `t_map`, `t_get`, `t_font` ; `g_tmap` de `GRX.INC` pour le traduit), commune aux deux ; se sert de `arr.inc` (descripteurs, place sous les tableaux) et de `hz_tad` (`hires.inc`) ; demande au programme l'octet `s_hst` |
| `progs/fil.inc` (`FIL.INC`) | fichiers de données (`SAVE`... `FOUND`), commune aux deux ; enregistrements dans `DEF_DMA` ; demande au programme son FCB (`f_fcb`), l'écriture d'un nombre (`f_fmt`, `f_nbuf`) et quatre messages (`f_mlo`, `f_mful`, `f_mro`, `f_mdir`) ; écriture par `NOM.$$$` (`f_wopen`, `f_wclose`, `f_wabort`), type d'origine gardé dans `f_ext` |

Les tampons (noms de fichiers, paramètres, mots...) sont après la fin du programme, mis à 0
au lancement : ils ne sont pas dans le fichier.

**Variables** : `getvar` (une instruction : `FOR`, `GET`, `INPUT`, affectation) et `kw_var`
(dans une expression, après `parse_id`) rendent la première lettre dans `vix` (0-25) et le
second caractère dans `vc` (0 : aucun, 1-26 : lettre, 27-36 : chiffre) ; `IF` est refusé
(`not_if`). L'interpréteur range les 962 variables dans une table `vars` de 1 924 octets
(entre `lbuf` et le texte, mise à 0 au lancement) : `vaddr` calcule
`vars + 2 * (26 * vc + vix)`, sans recherche, donc aussi vite qu'avec une lettre ; une boucle
`FOR` garde l'adresse de sa variable (`cs_v`, `cs_vh`). Le traducteur écrit `V_` puis le nom
(`o_sym`) ; il note les variables de deux caractères rencontrées (`kvu` : 5 octets par
lettre, un bit par second caractère) et les réserve à la fin de `NOM.ASM` (`o_vars`,
`.word 0`). Un bloc de boucle `Bn` a 6 octets : arrivée, pas, puis l'adresse de la variable,
écrite à l'entrée du `FOR` ; `g_forok` et `g_forstep` la lisent là. Les boucles ont leur
propre numéro (`knb`, `k_newloop`, gardé dans `cs_bl`/`cs_bh`), distinct de celui des blocs
(`kn`, étiquettes `L`) : seuls les `FOR` et `REPEAT` ont un `Bn`.

**Expressions traduites** : la gauche d'une opération reste en constante (`vs_f` = 1), passe
par `g_push` (`vs_f` = 0), ou reste dans `g_ev` quand `k_simple` voit, en lisant la suite de
la ligne, que la droite est un nombre ou une variable sans opérateur plus fort derrière
(`vs_f` = 2) : `kdst` envoie alors la variable dans `g_et` (`ld_var`), et `k_apply` (`lreg`)
y met la constante puis choisit l'opération inversée (`cswp` pour les comparaisons, `"r"`
pour `g_rsub`). `kz` vaut 1 juste après un `jsr g_cmp`, `g_and` ou `g_or` ; toute autre
instruction le remet à 0 (`o_tab`) ; `o_skipz` n'écrit alors que `bne *+5` / `jmp`.
`k_incdec` reconnaît `V = V + 1` et `V = V - 1`.

**Bibliothèques recopiées** (GRXASM) : `build.sh` passe les copies allégées de la
disquette (`tools/strip_inc.py`) dans `tools/mark_inc.py`, qui découpe les six
bibliothèques des programmes traduits en routines (d'une étiquette en colonne 0, hors bloc
`.( .)`, à la suivante), les numérote à la suite dans l'ordre de `NOM.ASM` (GRX, ARR, FIL,
SPR, ANIM, HIRES) et écrit des lignes de commentaire : `;@#NNN` (la première routine du
fichier est NNN+1), `;@DDDEEE` devant chaque routine (les routines dont elle a besoin : ce
que nomment ses instructions et ses données, et la suivante si elle ne finit ni par `rts`,
ni par `jmp`, ni par des données ; `;@*` : toujours gardée, `g_init`), `;@+DDD` (suite),
`;@=NNN` (lignes d'une autre routine : une constante qui vaut une étiquette, comme
`a_fail = g_stop`, est un nom de cette routine ; `000` : toujours recopiées). Pendant la
traduction, `oc` relève les noms écrits qui commencent par une minuscule et contiennent `_`
(`kcapt`, liste `kroot`). À la fin, `kl_libs` lit les bibliothèques utiles une première fois
(`kl_run` 0) : une routine dont l'étiquette, ou une constante qui la vaut, est un nom relevé
est gardée (`KMK`, une marque par numéro), et chaque besoin donne une arête (`KEDG`, 4
octets) ; `kl_clos` parcourt les arêtes jusqu'à ce que rien ne change ; la seconde lecture
(`kl_run` 1) recopie les lignes des routines gardées. Ces tables occupent la place du texte
du `.GRX`, qui ne sert plus. `tools/test_inc.sh` vérifie que les copies marquées s'assemblent
comme les originaux et que chaque programme traduit s'assemble (une routine oubliée donne
une étiquette non définie) ; `test_grapher.sh` traduit avec elles.

**Deux dimensions** : le programme écrit (colonne, ligne) ; `ARR.INC` garde en mémoire et dans
le descripteur l'ordre (lignes, colonnes) : `r_dim2` et `r_ea2` (donc `r_get2`) échangent
`r_i` et `r_j` en entrant, et les traducteurs passent les indices dans l'ordre du texte. Seul
GRXASM s'en occupe pour les tableaux fixes : la table des lignes `TR_S` est indexée par le
second indice, et le premier s'y ajoute (`kf_ix`) ; quand les deux sont calculés, la
colonne attend sur la pile du 6502, puis dans `g_et`. `tools/grx_colig.py` passe un `.GRX`
écrit dans l'ancien ordre (ligne, colonne) au nouveau.

**Tableaux fixes** (GRXASM) : `kf_new` décide, au `DIM`, qu'un tableau est fixe et calcule
son adresse comme `r_dim` le fera (`kftop` suit `r_top`, à partir de `$9D60`) ; rien n'est
écrit à la ligne du `DIM`. L'en-tête de `NOM.ASM` appelle `G_INIT` : sans tableau fixe,
`G_INIT = g_init` (écrit après `HIRES.INC`) ; sinon une routine (`kf_init`) qui appelle
`g_init`, corrige `g_sp` (deux `inc` : la pile du lancement), puis fait les `r_dim1` /
`r_dim2` des tableaux fixes du plus haut au plus bas, c'est-à-dire dans l'ordre des `DIM`.
Suivent les tables des lignes utilisées (`TR_G .byt`) et les adresses (`T_G = $9D38`).
Cases `kf_*` : 0-25 entiers, 26-51 tableaux `$` ; un tableau est petit (`kf_sm`) s'il fait
256 octets au plus. Un accès (`kf_get`, `kf_put`) lit ses indices par `kf_ix` : chacun est
calculé (`g_ev`), une variable simple (lue plus tard, sans code ; petit tableau seulement)
ou une constante (`kcl`) ; le résultat est une adresse fixe (`kfm` = 0, `kfo`), un
décalage dans A (1) ou à charger dans Y depuis l'opérande (3, octets), ou le descripteur
(2). La destination `ksym` = 3 écrit `T_S+kfo` puis `,y` (`kyx`), ce qui permet de reprendre
`ld_var` et `o_st16`. Une affectation garde le décalage sur la pile du 6502 (`pha` / `pla`)
seulement si la valeur demande un calcul (`kf_look`) ; un entier reçu d'une variable est
copié directement (`kf_cpv`). `kf_get` garde l'état (`kfst`, `KFN` octets) sur la pile :
un indice peut lire un autre tableau fixe. `ks_arr` étend `k_simple` aux éléments d'indices
constants, ou de variables simples dans un petit tableau d'entiers. Tests : `fix.grx`,
`e_fix.grx`.

**Contrôles** : un programme traduit n'en fait aucun (§ 12). GRXASM écrit `lda g_ev` (ou
`lda V_x` pour une variable seule : `kv_one`) là où il écrivait `jsr g_byte`, appelle
directement `h_loc`, `h_chr`, `h_ltab`, `h_lvon`, `r_scrl`, et n'écrit plus `jsr g_brk` à
chaque `NEXT`. `GRX.INC` n'a plus ni `g_byte`, ni `g_needlo`, ni `g_chk`, ni `g_brk`, ni les
tests de `g_push`, `g_sdiv`, `g_forok`, `g_scrn`. Dans `arr.inc`, `r_chk` (0 en traduit)
commande aussi la plage 0-255 de `r_stb` et `r_fill`, et `r_copy` coupe une chaîne trop
longue au lieu de s'arrêter. `k_apply` refuse une division par une constante nulle ; la
profondeur des expressions est bornée pendant la traduction (`NVS`), comme la pile des
valeurs de `GRX.INC` (24).

**Hasard** : xorshift 32 bits (`x ^= x << 8`, `x ^= x >> 9`, `x ^= x << 23`), de période
2³² − 1. Les décalages ont été choisis parmi ceux qui donnent cette période pour se faire par
octets : recopies d'octets et un seul décalage d'un bit (63 octets, sans boucle). `RND(n)`
fait un pas, puis, pour n < 256, rend (mot haut × n) / 65 536 (multiplication de 8 pas) ;
pour n plus grand, le reste de la division du mot haut (15 bits) par n. Graine : le compteur
50 Hz, complété par `$5A` `$A5` (jamais nulle), puis 4 pas, sans quoi deux lancements à un tic
d'écart commencent par des valeurs voisines. L'interpréteur (`rand`, `f_rnd`) tire la graine
au lancement ; `GRX.INC` (`g_rnd`) au premier `RND`, pour qu'un programme sans `RND`
n'emporte pas le générateur. Un générateur de 16 bits (graine × 5 + 13849, par exemple)
lie chaque tirage au précédent : des coordonnées tirées par paires s'alignent en bandes ;
aucun générateur de 16 bits ne tient en trois dimensions. Tests : `rnd.grx`
(valeurs, bornes), `rnd2.grx` (couples de tirages : 64 cases toutes remplies),
`e_div0.grx`.

**Rectangles** (`arr.inc`) : ils sont dans `ARR.INC` plutôt que dans `HIRES.INC`, que d'autres
programmes incluent (VOIR) sans s'en servir ; un programme traduit qui fait défiler inclut
donc `ARR.INC`, dont GRXASM ne recopie que les routines utiles.

- `rz_ra` : adresse du début d'une ligne à la colonne `h_x1` (LORES : `hz_rows` ; image :
  `h_ylo`, `h_yhi`). `rz_mv` copie `rz_bn` octets de `hp` vers `hq` (`lda (hp),y` /
  `sta (hq),y`, environ 18 cycles par octet) ; `rz_fl` remplit.
- `r_blit` (`PASTE`, `GRAB`) : une ligne de l'écran par ligne du tableau ; la mémoire avance de
  `r_bst` octets (la taille 2 du tableau, lue dans son descripteur), l'écran d'une ligne.
  L'interpréteur vérifie le coin opposé par `r_ea2` avant de copier ; les indices sont gardés
  dans `flim` et `fstep` (temporaires de `FOR`) pendant le calcul des quatre autres
  paramètres. Traduit, les deux indices passent par la pile des valeurs (`g_push`), puis
  `g_paste` ou `g_grab` les reprend.
- `r_scrl` : `|n|` ramené à la taille (modulo pour une rotation). En largeur, chaque ligne
  passe par `h_buf`, puis revient décalée en deux morceaux (le reste, puis les k cases
  libérées : `r_sf`, ou le début du tampon en rotation). En hauteur, des lignes entières sont
  recopiées dans le bon ordre (de bas en haut pour descendre) ; une rotation fait k passes
  d'une ligne, k ramené au plus à la moitié de la hauteur en changeant de sens, la ligne qui
  sort passant par `h_buf`.
- `r_sdef` pose le rectangle de tout l'écran et l'octet par défaut ; les paramètres présents
  le remplacent ensuite (interprété et traduit font de même).
- `PRINTV`, `ECHOV`, `SPCV` : `h_lv` (`h_lvon` / `h_lvoff`) change seulement l'avance du
  curseur dans `h_lput` et le sens de `h_lnl` ; GRXASM entoure la traduction de `PRINT`,
  `ECHO` ou `SPC` de `jsr g_vlon` et `jsr h_lvoff`.
- Tests : `lo_rect.grx` (LORES : rectangles, signes, octet, rotations, écriture verticale,
  `PASTE`, `GRAB`), `rect.grx` (image, par `POINT`), `e_rect*.grx` (erreurs).

Page zéro : `$10-$5C` pour GRAPHER et GRXASM, plus `$5E-$61` (GRAPHER : graine du hasard ; GRXASM : pointeurs), `$10-$2C` pour `GRX.INC`, `$B0-$BF` pour
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

**Tuiles** (`spr.inc`, même page zéro que les sprites) :

- `TILESET` (`t_set`) réserve (larg × haut + 1) pages alignées sous les tableaux (`tz_res`,
  `t_tb`, `t_np` : de nouveau seulement si un `TILESET` en demande plus). Page 0 : octet de
  la carte → numéro de la tuile (0 partout, puis les numéros ; avec `K$`, du dernier
  caractère au premier, pour que le premier l'emporte ; `t_z` : un octet qui donne la
  tuile 0). Page 1 + p, pour chaque place p = ligne × larg + colonne dans la tuile :
  octet de la carte → code affiché, rempli octet par octet (adresse de la ligne de `D$`
  par `rz_mul`, gardée tant que la tuile ne change pas). `TMAP` n'a plus de numéro de
  tuile à chercher : il traduit, comme une carte de 1 × 1.
- `tz_div` : X / larg (1 à 4, signé, arrondi vers le bas) par 16 décalages et
  soustractions, une fois par commande (`tz_cut` : tuile et place pour X et Y).
- `TMAP` (`t_map`) : nombre de colonnes de tuiles touchées (`t_nt`), et les premières et
  dernières dans la carte (`t_jl`, `t_jh`), une fois ; puis par ligne de l'écran, trois
  morceaux : avant la carte, dans la carte, après (hors de la carte : `t_z`). Tuiles
  d'une colonne : `lda (carte),y` / `tax` / `lda table,x` / `sta (écran),y` (environ
  35 cycles par case). Plus larges : les octets des tuiles de la ligne vont dans `h_buf`
  (21 au plus), puis quatre instructions `lda table,x` (une par place, page modifiée à
  chaque ligne) se suivent ; un compteur dit quand passer à la tuile suivante (environ
  55 cycles par case en 2 × 2). La ligne de la carte (`t_mp`) avance d'une ligne de
  tuiles toutes les `haut` lignes ; une ligne hors de la carte n'a que des `t_z`.
- `TILE` (`t_get`) : `tz_cut`, puis l'octet de la carte et la page 0 ; la carte (adresse,
  lignes, colonnes) est celle que le dernier `TMAP` a gardée (`t_ma`, `t_mr`, `t_mc`).
- `TFONT` (`t_font`, `tz_walk`) : un premier passage compte les cases (et vérifie le
  fichier en interprété : `sz_find0`, genre 1, tailles, place dans le tableau), le second
  les copie en `$B400` ou `$B800` + 8 × code. `ALT` met `s_hst` à 1 (historique vidé).
- GRXASM ne recopie que les routines utiles : `tz_in` et `tz_inc` (deux entrées du même
  test) sont écrites pour que `tz_in` puisse venir sans `tz_inc` (pas de `BIT abs` entre
  elles).
- Tests : `lo_tile.grx` (`K$`, caméra à cheval sur les tuiles, hors de la carte, octet
  inconnu, ligne courte, tuiles de 3 × 1 sans `K$`, `TILE`), `lo_tile2.grx` (`TFONT` dans
  les deux jeux, `K$` dans un tableau, tuiles de 1 × 1), `lo_tile3.grx` (sprite sur des
  tuiles, dans les deux jeux : dessins redessinés avec le masque, tuile rendue au
  déplacement), `e_tile*.grx` (erreurs) ;
  `TUIL.SPR` fait par `tools/mkspr.py` (source `tuil_spr.txt`), `TUIL.TXT` et `MAPT.TXT` lus
  par `LOAD`.

Tests : `tools/test_grapher.sh` vérifie le CHAIN de `/A`, puis exécute chaque cas interprété
(GRAPHER) puis traduit (GRXASM), dans le 6502
simulé (`tools/run_com.py`, sans émulateur), et compare au résultat attendu (`.ref`, `.kref`,
saisies dans `NOM.in`). Puis essai Oricutron des exemples.

## 16. Décidé, pas encore fait

- Caractères animés au rythme du 50 Hz (l'eau qui ondule), sans toucher à la carte.
- **Éditeur de caractères et de sprites** : un `.COM` plein écran qui écrit les `.SPR`
  (sprites et tuiles). En attendant, `tools/mkspr.py` fabrique un `.SPR` sur le PC à partir
  d'un dessin en texte (`tools/spr/tuiles.txt`).

## 17. Questions ouvertes

- **Phases d'un jeu** (`RUN NOM [p...]`) : le programme passe la main à un autre `.GRX` ou
  `.COM` traduit en gardant variables, tableaux et écran (LORES, HIRES, sprites). En
  interprété, seul le texte est remplacé (il doit tenir sous les tableaux). En traduit : les
  variables dans une zone fixe commune à tous les `.COM` (rangées comme dans
  l'interpréteur), les tableaux déjà sous `$9D60`, un chargeur recopié en `$9F00` qui lit le
  `.COM` en `$0500` et y saute sans remettre les variables à 0 ; chaque phase garde ses
  bibliothèques. Restent à choisir : le nom (`RUN` ou `CHAIN`) ; comment une phase déclare
  les tableaux qu'elle reçoit (un `DIM` identique accepté sans effacer, ou `COMMON`).

- Si le parcours du fichier par `SSHOW` est trop lent pour les derniers sprites : table des
  positions construite au chargement.
- Plus tard : sprites qui apportent leur couleur (cases « attribut » dans le fichier, posées
  telles quelles, remises au retrait).
