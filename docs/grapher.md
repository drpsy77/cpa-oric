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

## 10. Images et animations

| Commande | Effet |
|---|---|
| `GLOAD nom` | charge une image : `.HIR` (ou `.HIZ` compressée) en HIRES, `.IMG` en SPLIT ; depuis le mode texte, le type choisit le mode (`.HIR` par défaut) |
| `GSAVE nom` | enregistre l'image au format du mode (`.HIR` ou `.IMG`) |
| `ANIM nom [n]` | joue l'animation `nom.ANI` n fois (0 ou rien : jusqu'à une touche) ; HIRES plein écran seulement (refusé en SPLIT) ; ESC arrête le programme |

Le nom s'écrit sans guillemets, avec un lecteur facultatif ; `$1`-`$9` sont permis. Formats
`.HIZ` et `.ANI`, outils de fabrication : README, « HIRES plein écran ».

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
| Fichiers | `Fichier introuvable` et `Fichier trop gros` (le `.GRX`), `image introuvable`, `disque plein`, `animation introuvable`, `animation trop grande` |

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
  `ARR.INC` si le programme a des tableaux et `ANIM.INC` s'il anime. Ils sont, avec GRXASM,
  sur la disquette complète, la disquette Assembleur et la disquette Animations (pas sur la
  disquette Logo, qui n'a pas ASM).
- Un `.COM` traduit pèse au moins 3 Ko (bibliothèques), puis quelques dizaines d'octets par
  commande. ASM met moins d'une minute pour `MOTIFS`.

## 13. Mémoire, vitesse, limites

- **Mémoire** (interprété) : GRAPHER.COM (11 165 octets) en `$0500`, puis les tables de
  `hires.inc`, les tampons et les variables. Le texte du `.GRX` vient ensuite et s'arrête au plus tard en
  `$9D60`. Les tableaux sont réservés sous `$9D60`, vers le bas, jusqu'à la fin du texte. Une
  animation ou une image `.HIZ` se charge après le texte, sans jamais recouvrir les tableaux.
  Les descripteurs des tableaux occupent `$9D60-$9EFF`. La zone libre pour le texte, les
  tableaux et une animation fait environ 25 Ko (texte à partir de `$397C`).
- **Vitesse** : 150 à quelques centaines de lignes par seconde en interprété (un ciel de 400
  étoiles, `PLOT 1+RND(238) 1+RND(198)` : 5 s ; traduit : 0,6 s).
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
| `SCORES.GRX` | meilleurs scores : `INPUT` du nom, tri, titre coloré par un attribut en tête de chaîne |
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

Les tampons (noms de fichiers, paramètres, mots...) sont après la fin du programme, mis à 0
au lancement : ils ne sont pas dans le fichier.

Page zéro : `$10-$56` pour GRAPHER et GRXASM, `$10-$27` pour `GRX.INC`, `$C0-$C7` pour
`hires.inc`, `$C8-$CF` pour `arr.inc`.

Tests : `tools/test_grapher.sh` vérifie le CHAIN de `/A`, puis exécute chaque cas interprété
(GRAPHER) puis traduit (GRXASM), dans le 6502
simulé (`tools/run_com.py`, sans émulateur), et compare au résultat attendu (`.ref`, `.kref`,
saisies dans `NOM.in`). Puis essai Oricutron des exemples.

## 16. Décidé, pas encore fait

### 16.1 Fichiers de données (prochain lot)

| Commande | Effet |
|---|---|
| `SAVE A nom`, `LOAD A nom` | tableau en **texte** (`.TXT` par défaut), modifiable avec EDIT |
| `BSAVE A nom`, `BLOAD A nom` | tableau en **binaire** (`.DAT` par défaut), octets tels quels, modifiable avec HEX ; entiers : octet bas puis octet haut |
| `BSAVE SCREEN nom`, `BLOAD SCREEN nom` | écran texte entier, 1 120 octets (`.SCR` par défaut) ; LORES seulement (`LORES d'abord`) ; le curseur ne bouge pas |

`A` est le nom du tableau (`SAVE N$ HOF`, `BLOAD M NIVEAU1`). Le nom du fichier s'écrit comme
pour `GLOAD`. `SAVE` et `BSAVE` écrasent un fichier existant sans confirmation.

**Texte**, au format de CP/M comme EDIT :

- `SAVE` termine chaque ligne par CR LF et complète le dernier enregistrement par `^Z`.
  `LOAD` accepte CR LF, LF ou CR, et s'arrête au premier `^Z`.
- Une ligne du fichier correspond à une ligne du tableau, toujours (pas de commentaires).
  Tableau `$` : la ligne telle quelle, espaces compris, jusqu'au premier 0. Tableau `$` à une
  dimension : une seule ligne. Tableau d'entiers : les nombres séparés par des espaces (une
  tabulation compte comme un espace), signe `-` permis. Tableau d'entiers à une dimension :
  tous les nombres sur une seule ligne.
- `SAVE` d'un tableau `$` contenant un code 1-31 : erreur `code 0-31 : BSAVE` (ces codes ne
  se tapent pas dans EDIT ; les attributs passent par `BSAVE`).
- `LOAD` : une ligne plus courte que la ligne du tableau est complétée par des 0 (`$` comme
  entiers). Ligne trop longue ou trop de nombres : `ligne trop longue : L n` (n = ligne du
  fichier). Lignes en trop : erreur ; en moins : le reste du tableau à 0. Nombre invalide ou
  hors de -32768..32767 : erreur. En cas d'erreur, ce qui a été lu reste dans le tableau.

**Binaire** : les fichiers de CP/M n'ont pas de taille à l'octet près (enregistrements de
128 octets). `BLOAD` lit la taille du tableau : un fichier plus court laisse la fin à 0, ce
qui dépasse est ignoré. `BSAVE` complète le dernier enregistrement par des 0.

**Fichier absent** au `LOAD` ou au `BLOAD` : pas d'erreur, le tableau reste tel quel. La
fonction `FOUND` vaut 1 si le dernier `LOAD` ou `BLOAD` a trouvé le fichier, 0 sinon (0 au
lancement) :

    LOAD S SCORES
    IF FOUND = 0
      FILL S 0
    ENDIF

Autres erreurs disque : celles de `GSAVE`, qui arrêtent le programme.

Rien d'autre ne se sauve pour l'instant (ni les variables `A`-`Z`, ni la police) : un
programme qui veut garder des variables les range dans un tableau.

Coût estimé : 1 à 1,5 Ko partagés entre GRAPHER (exécution, environ 12 Ko au total, donc
moins de 1 Ko pris sur la zone libre) et GRXASM (traduction) ; `GRX.INC` +0,5 Ko, inclus seulement par un programme qui s'en sert. Tests :
aller-retour texte et binaire (interprété = traduit), erreurs, fichier absent. Exemples : le
tableau des scores enregistré, un niveau dessiné dans EDIT, un écran titre en binaire.

### 16.2 Plus tard

- **`REDIM`** : redimensionner un tableau en gardant les éléments dont les indices existent
  encore (comme `ReDim Preserve`) ; les tableaux déclarés après sont déplacés. ~0,3 à 0,5 Ko.
- **Sprites en mode texte** : `docs/spec-sprites.md` ; les fichiers `.SPR` se chargent par
  `BLOAD`.

## 17. Questions ouvertes

Aucune.
