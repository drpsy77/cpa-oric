# GRAPHER : écran texte (LORES), tableaux et chaînes — spécification

État : **palier A fait** (12 octobre 2026 ; A1 : oui, plus d'attente imposée en fin de
programme HIRES non plus) ; paliers B et C à relire. Écarts à la réalisation : un `TAB`
négatif donne `valeur hors de 0-255` (comme tout paramètre d'octet) ; `INPUT V` viendra avec
`INPUT A$` au palier B ; CTRL-P n'agit que dans la saisie d'une ligne de la console, qu'un
programme en LORES n'utilise pas.
Décisions déjà prises : `docs/projet-disquette.md`, « Jeux en écran texte : GRAPHER et LOGO ».
Ce document ne concerne que GRAPHER ; les ajouts à LOGO (FIXECURSEUR, CURSEUR, VIDETEXTE,
CARECRAN) et sa tokenisation feront l'objet de lots séparés.

## 0. Principes

- GRAPHER reste un langage de bas niveau, proche de l'écran : on écrit des cases, on lit des
  cases, on gère soi-même la mise en page. Pas de console en LORES, comme en HIRES.
- **Les `.GRX` existants ne changent pas.** Les nouvelles règles d'affichage ne valent qu'en
  LORES ; en mode console (texte) et en SPLIT, ECHO et PRINT restent ce qu'ils sont.
- **Mémoire fixée une fois pour toutes** : `DIM` réserve, rien ne se libère ni ne s'agrandit ;
  le manque de place se voit au `DIM`, jamais en plein jeu ; chaque accès à un tableau
  vérifie ses indices. Pas de ramasse-miettes, pas de fragmentation.
- **Interprété = traduit** (`/A`) : tout ce qui suit existe dans les deux, avec les mêmes
  erreurs (sans numéro de ligne dans un programme traduit, comme aujourd'hui).
- Trois paliers, chacun livré, testé et commité à part : **A** (LORES et affichage),
  **B** (DIM, tableaux, chaînes, INPUT), **C** (fichiers).

## 1. Palier A : l'écran texte LORES

### 1.1 Entrer et sortir

| Commande | Effet |
|---|---|
| `LORES` | le programme prend l'écran texte entier : 40 colonnes (0-39) × 28 lignes (0-27), ligne 0 et colonnes 0-1 comprises. L'écran est effacé (voir `CLS`), le curseur de la console est éteint, la barre de menus disparaît, les touches de la console sont sans effet (1.3). Curseur d'écriture en colonne 0, ligne 0. |
| `TEXT` | retour à la console (comme aujourd'hui) : écran rempli d'espaces (32), couleurs de PAPER et INK en colonnes 0-1, barre de menus, curseur. |
| `CLS` | en LORES : remplit les 1 120 cases, colonnes 0 à 39, de l'attribut 16 (papier noir ; l'Oric en BASIC met 16 partout sauf 8 en colonne 0, Pierre préfère 16 partout) ; curseur en colonne 0, ligne 0. Hors LORES : efface la console (comme la commande CLS du CCP). |

- `HIRES` et `SPLIT` depuis LORES : comme depuis le texte (l'écran texte est perdu).
- Les commandes de dessin (`PLOT`, `LINE`... `GTEXT`, `GNUM`, `ATTR`) restent réservées à
  HIRES et SPLIT : en LORES, l'erreur actuelle (`HIRES ou SPLIT d'abord`).
- **Fin du programme en LORES** (fin du fichier ou `END`) : retour immédiat à la console,
  **sans attente imposée par GRAPHER** (Pierre : attendre est le rôle d'une instruction du
  programme, `WAIT` ou `GET`). Pour HIRES, voir la question A1. **ESC** entre deux lignes
  arrête, comme aujourd'hui. **Erreur** : retour à la console, puis le message habituel
  `L n COMMANDE : message`.
- Touches :

  | Élément | Effet |
  |---|---|
  | `INKEY` | fonction : code de la touche, 0 si aucune ; n'attend pas ; sans délai de répétition (octobre 2026) : touche tapée depuis le dernier `INKEY` (tampon vidé), sinon celle qui est encore enfoncée (`KB_HELD`, `$0217`, lu à 50 Hz par l'IRQ) |
  | `GET V` | **nouveau** : attend une touche et range son code dans la variable V |
  | `WAIT` | attend une touche, sans la garder (inchangé) : `GET` sans variable |
  | `DELAY n` | attend n cinquantièmes de seconde, sans regarder le clavier (inchangé) : cadence d'une animation ou d'un jeu |

  ESC arrête le programme, y compris pendant `GET` et `WAIT` (comme aujourd'hui pour WAIT).
  La répétition des touches est celle du menu Clavier.

### 1.2 Écrire et lire des cases

| Commande / fonction | Effet |
|---|---|
| `LOCATE col lig` | place le curseur d'écriture (col 0-39, lig 0-27, sinon `valeur hors limites`). |
| `CHAR col lig code` | écrit l'octet `code` (0-255) dans la case : un caractère (32-127), un attribut (0-31 : encre 0-7, papier 16-23, et les autres attributs de l'Oric), ou un caractère en vidéo inverse (+128). Le curseur ne bouge pas. |
| `SCRN(col,lig)` | fonction : l'octet de la case (0-255). |
| `ECHO texte` | écrit le texte au curseur, qui avance sur la ligne. Sans guillemets : comme aujourd'hui (espaces du début sautés). Entre guillemets : `ECHO "  Score : "` écrit exactement ce qui est entre les guillemets, espaces compris. `$1`-`$9` sont remplacés dans les deux cas. |
| `ECHO` (seul) | passe à la ligne suivante, en colonne 0 ; après la ligne 27 : ligne 0. Rien n'est effacé. Pour commencer plus loin : `TAB 2`. |
| `PRINT expr` | écrit le nombre au curseur (sans passage à la ligne), qui avance. |
| `SPC n [x]` | écrit n fois l'octet x au curseur (x : 0-255, 32 = espace par défaut), le curseur avance : des espaces, l'attribut 16 de LORES, un trait de `-`... (Pierre a écrit `SPC(N,X)` ; en GRAPHER, les paramètres d'une commande sont séparés par des espaces, les parenthèses étant pour les fonctions.) |
| `TAB n` | avance le curseur de n colonnes **sans rien écrire** (n ≥ 0, sinon `valeur hors limites` : pas de TAB négatif ; relatif : en BASIC de l'Oric, `TAB(n)` va à la colonne n ; ici, `LOCATE` donne la colonne absolue). |

**Règle du bord droit** (ECHO, PRINT, SPC, TAB) : on n'écrit jamais au-delà de la colonne 39.
Ce qui dépasse est perdu, sans erreur ; le curseur reste « au bout » (colonne 40) et tout ce
qui suit sur cette ligne est ignoré jusqu'au prochain `LOCATE` ou `ECHO` seul. Rien ne passe
sur la ligne suivante (dont les colonnes 0-1 portent les attributs), rien ne fait défiler.

Hors LORES, `LOCATE`, `CHAR`, `SCRN`, `SPC` et `TAB` donnent l'erreur `LORES d'abord`.

### 1.3 Ce qu'il faut au système (ajout au contrat : accordé par Pierre)

En HIRES, le système sait qu'un programme a l'écran (`hires_on`, octet `$1E` en `$BFDF`) :
FUNCT est ignoré, les voyants de la barre (`A`/`a` par CTRL-T, `P` par CTRL-P) ne sont pas
redessinés, et le démarrage à chaud remet la console. En LORES, aucune case de l'écran ne
peut servir de marque (le programme les utilise toutes). Proposition :

- une **variable publique de la page 2**, `SCR_PROG` (une des adresses libres de
  `docs/memoire-pages-2-3.md`, par exemple `$020E`, à côté du haut de la TPA), mise à 1 par
  un programme qui prend l'écran texte ; `hires_on` devient « écran au programme » (HIRES
  ou `SCR_PROG`) ; le démarrage à chaud la remet à 0 et réaffiche la console (effacement,
  attributs, barre). Pierre : toutes les interactions de la console sont alors
  désactivées. Concrètement : FUNCT ne fait rien (pas de menus) ; CTRL-T et CTRL-P n'agissent
  plus et ne dessinent plus de voyant (sans cela, CTRL-T écrirait `A` en ligne 0, colonne
  37 d'un jeu) : leur code arrive au programme comme une touche ordinaire ; pas de
  clignotement du curseur ni de pause en fin d'écran (le programme n'écrit pas sur la
  console). Reste RESET (bouton) : retour au prompt, console remise.
- C'est un **ajout au contrat** (une variable publique de plus, dans `progs/cpa.inc` et
  `docs/architecture.md`), donc aussi dans la version ROM ; rien ne change pour l'existant.
- Coût estimé : 20 octets résidents (prévoir 40), sur 287 libres.

### 1.4 Bibliothèque

Les routines LORES (prendre l'écran, effacer, case, curseur d'écriture, texte et nombre bornés
à la ligne) vont dans `hires.inc`, la bibliothèque d'écran, pour servir aussi aux programmes
écrits en assembleur et aux programmes traduits (`/A`).

## 2. Palier B : DIM, tableaux et chaînes

**Fait** (14 octobre 2026), avec les réponses de Pierre plus bas (§ 5) ; écarts et choix de la
réalisation :

- Routines communes à l'interpréteur et aux programmes traduits dans **`progs/arr.inc`**
  (`ARR.INC`, incluse par un `.ASM` traduit seulement s'il a des tableaux ou des chaînes) ;
  `r_chk` : vérifications en interprété seulement. Descripteurs (8 octets par tableau) en
  `$9D60-$9EFF` ; le texte du `.GRX` s'arrête donc à `$9D60` (416 octets de moins).
- Une chaîne fait **255 caractères au plus** (un tableau `$` plus grand se lit case par case).
- `PRINT A$` n'affiche la chaîne que si elle va jusqu'au bout de la ligne ; `PRINT A$ = B$`
  affiche la comparaison.
- À la traduction, un tableau doit être déclaré par un `DIM` placé **plus haut** dans le
  fichier (la traduction lit le fichier dans l'ordre et doit savoir si `M$(I)` est une ligne
  ou une case).
- `INPUT` d'un élément (`INPUT A(I)`) : non ; `INPUT V` puis `A(I) = V`.

### 2.1 Les noms

| Nom | Sorte | Élément |
|---|---|---|
| `A` à `Z` | entier (comme aujourd'hui) | 16 bits signé |
| `A(i)`, `A(i,j)` | tableau d'entiers, 1 ou 2 dimensions | 16 bits signé |
| `A$(i)`, `A$(i,j)` | tableau d'octets, 1 ou 2 dimensions : chaîne ou grille de caractères | 0-255 |

Chaque lettre sert aux trois sortes indépendamment (`A`, `A(...)` et `A$` sont trois choses
différentes), comme en BASIC. Une lettre suivie de `(` est un tableau ; les fonctions ont des
noms de plusieurs lettres (`RND`, `ABS`, `POINT`, `SCRN`, `LEN`).

### 2.2 DIM

    DIM S(10) N$(10,12) M$(25,38)

- Une ligne `DIM` peut déclarer plusieurs tableaux, séparés par des espaces (règle habituelle
  des paramètres). Les tailles sont des expressions, au moins 1.
- **Indices à partir de 0, comme en C** : `DIM A(10)` donne `A(0)` à `A(9)`.
- Chaque tableau se déclare **une seule fois** (`deja dimensionne` sinon) et avant usage
  (`tableau non dimensionne`). Les éléments valent 0 au départ.
- Taille : entiers 2 octets par élément, `$` 1 octet. Pas d'autre limite que la place :
  `memoire pleine` dès le `DIM` s'il n'y en a pas assez.
- Place : les tableaux sont rangés du haut de la zone libre (`$9F00`) vers le bas ; la zone
  libre est ce que laissent le texte du `.GRX` et une animation chargée (aujourd'hui environ
  26 Ko moins la taille du fichier). Dans un programme traduit, même zone, réservée au
  lancement (le `.COM` ne grossit pas).
- Chaque accès vérifie ses indices : `indice hors limites` (indice négatif compris).

### 2.3 Éléments

- `A(I)`, `A(I,J)` : partout où une expression est permise, et à gauche de `=`
  (`A(I,J) = expr`).
- `A$(I)` (tableau à une dimension) et `M$(I,J)` : le code d'une case (0-255), en lecture et
  en écriture (`M$(L,C) = 35` ; hors de 0-255 : `valeur hors de 0-255`).

### 2.4 Chaînes

Une chaîne est le contenu d'un tableau `$` :

- `A$` (sans indice, tableau à une dimension) : toute la chaîne ;
- `M$(I)` (un seul indice, tableau à deux dimensions) : la ligne I, comme une chaîne. Un
  tableau de chaînes est donc un tableau `$` à deux dimensions (`N$(10,12)` : 10 noms).

**Longueur** : la chaîne s'arrête au premier octet 0, ou à la fin de sa capacité si elle est
pleine (pas d'octet perdu pour le 0 final : `DIM N$(12)` contient 12 caractères au plus). Une
grille de niveau `M$(25,38)` peut donc avoir ses 38 cases pleines, et `M$(L)` reste une chaîne.

Ce qu'on peut faire d'une chaîne (et rien d'autre : ni concaténation, ni conversion) :

| Élément | Effet |
|---|---|
| `A$ = "texte"`, `A$ = B$`, `M$(I) = "texte"`, `M$(I) = A$` | affectation ; le reste de la capacité est mis à 0. Plus long que la capacité : `chaine trop longue` (le programme s'arrête). |
| `A$ = B$`, `A$ <> B$`, `A$ < B$`, `<=`, `>`, `>=` | comparaison (1 ou 0), dans `IF`, `WHILE` et les affectations ; ordre des codes (`"ABC" < "ABD"`, `"AB" < "ABC"`). Une chaîne ne se mélange pas aux calculs : `chaine dans un calcul`. |
| `LEN(A$)`, `LEN(M$(I))` | longueur (nombre). |
| `PRINT A$`, `PRINT M$(I)` | affichage : en LORES au curseur (règle du bord droit), ailleurs dans la console avec passage à la ligne. |
| `INPUT A$`, `INPUT M$(I)` | saisie (voir 2.5). |

ECHO reste réservé aux textes écrits dans le programme et à `$1`-`$9` (`ECHO A$` écrit
« A$ »). GTEXT aussi (texte dans l'image) ; un `GPRINT col y A$` pour l'image pourra venir
plus tard si un jeu HIRES en a besoin.

### 2.5 INPUT

- **En LORES** : saisie au curseur d'écriture, curseur visible pendant la saisie ;
  caractères 32-126, DEL efface à gauche, RETURN valide ; s'arrête seule à la capacité de la
  chaîne ou au bord droit (on ne peut plus taper, sans erreur) ; ESC arrête le programme
  (comme partout). Après RETURN, le curseur reste après le texte saisi.
- **Hors LORES** : la saisie de ligne de la console (BDOS 10), coupée à la capacité.
- **`INPUT V`** (accordé par Pierre) : même saisie, chiffres et signe `-` seulement, au plus
  6 caractères ; RETURN valide un entier de -32768 à 32767 ; vide ou hors limites : la
  saisie est refusée (son bref, on recommence), pas d'erreur qui arrête le programme.

## 3. Palier C : fichiers

| Commande | Effet |
|---|---|
| `SAVE A nom`, `LOAD A nom` | texte (type `.TXT` par défaut) : tableau `$` = une ligne du fichier par ligne du tableau (une seule ligne pour un tableau à une dimension), jusqu'au premier 0 ; tableau d'entiers = les nombres, une ligne du fichier par ligne du tableau, séparés par des espaces. Modifiable avec EDIT. |
| `BSAVE A nom`, `BLOAD A nom` | binaire (type `.DAT` par défaut) : les octets du tableau tels quels, ligne après ligne (entiers : octet bas puis octet haut). Les codes 0-31 (attributs) passent ; modifiable avec HEX. |
| `BSAVE SCREEN nom`, `BLOAD SCREEN nom` | en LORES : l'écran texte entier, 1 120 octets (type `.SCR` par défaut) ; un écran titre dessiné une fois, rechargé d'un coup. |

Le nom s'écrit comme pour GLOAD et GSAVE (sans guillemets, lecteur facultatif, `$1`-`$9` permis) ; `A` est le nom du tableau (`SAVE N$ HOF`, `BLOAD M NIVEAU1`).

- **LOAD texte** : une ligne trop longue pour sa ligne de tableau est une erreur
  (`ligne trop longue : L n`, n = ligne du fichier, comme dans LOGO) ; une ligne plus courte
  est complétée par des 0 ; des lignes en trop : erreur ; en moins : le reste du tableau
  à 0. Un nombre invalide ou hors de -32768..32767 : erreur.
- **BLOAD** : les fichiers CP/M n'ont pas de taille à l'octet près (enregistrements de 128
  octets) : on lit la taille du tableau ; un fichier plus court laisse la fin à 0 ; ce qui
  dépasse est ignoré. **BSAVE** complète le dernier enregistrement par des 0.
- Erreurs disque : celles de GSAVE/GLOAD (`fichier introuvable`, disque plein...).

## 4. Coût, tests

Estimations (doublées par prudence, vu les écarts passés) :

| Palier | GRAPHER (interprété + traduction) | Bibliothèques | Système |
|---|---|---|---|
| A | +1 à 1,5 Ko | hires.inc +0,3 à 0,5 Ko | 20-40 octets (`SCR_PROG`) |
| B | +2 à 3 Ko | GRX.INC +1 à 2 Ko | rien |
| C | +0,8 à 1,5 Ko | GRX.INC +0,5 Ko | rien |

GRAPHER passerait de 11,4 Ko à 15-17 Ko ; la zone libre (texte du `.GRX`, animation,
tableaux) baisserait d'autant (environ 26 Ko aujourd'hui).

Tests, à chaque palier : `tools/test_grapher.sh` (chaque cas interprété puis traduit, résultat
comparé), essais dans Oricutron (écrans, touches), et un exemple livré sur la disquette :
palier A, un écran qui bouge un personnage aux flèches ; palier B, un serpent (`DIM` pour le
corps, `SCRN` pour les collisions) et un tableau des meilleurs scores avec INPUT du nom ;
palier C, le même tableau enregistré, un niveau dessiné dans EDIT, un écran titre en binaire.

## 5. Questions

Réponses de Pierre (12 octobre 2026) : **Q1** colonne 0 (les attributs se posent partout
dans un jeu ; pour se décaler, `TAB`) ; **Q2** oui, toutes les interactions de la console
désactivées ; **Q3** oui, `INPUT V` pour un entier de 16 bits (voir 2.5) ; **Q4** oui.

- **A1. Fin d'un programme HIRES.** Aujourd'hui, GRAPHER attend une touche à la fin d'un
  programme HIRES. Faut-il, comme en LORES, ne plus attendre (cohérent : l'attente devient
  toujours un `WAIT` ou un `GET` écrit dans le programme) ? Il faudrait alors ajouter `WAIT`
  à la fin des exemples livrés qui en dépendent (`ECRAN.GRX`, `MOTIFS.GRX`, `ANIMS.GRX`...),
  et les programmes de Pierre écrits avant changeraient de comportement. Je penche pour
  oui, pour n'avoir qu'une règle.

### Questions du palier B : réponses de Pierre (14 octobre 2026)

- **B1. Pas de vérification des indices dans le code traduit (`/A`).** Pierre : « si le
  programme fait n'importe quoi en assemblé, on revient en interprété, qui est alors un mode
  de débogage ». L'interprété vérifie tout ; le traduit va au plus vite.
- **Lecture à un seul indice d'un tableau à deux dimensions** : permise, comme en C (« le
  développeur sait ce qu'il fait ; pour la vitesse, ça peut être utile ») : `A(K)` sur
  `DIM A(3,5)` est l'élément K du tableau mis à plat, ligne après ligne (`A(K)` = `A(K/5,K%5)`).
  En interprété, K est vérifié contre la taille totale. (Pour un tableau `$` à deux
  dimensions, `M$(I)` reste la ligne I comme chaîne, § 2.4.) GRAPHER vérifie ; LOGO, lui, est
  le langage de la pédagogie et des contrôles.
- **B2.** 2 dimensions au plus.
- **B3.** `PRINT` d'une chaîne : en LORES, les codes 0-31 sont écrits tels quels (couleurs
  d'une ligne de niveau) ; dans la console, remplacés par un espace. Le premier 0 reste la fin
  de la chaîne : un attribut 0 ne peut donc pas figurer dans une chaîne affichée par `PRINT`
  (il s'écrit par `CHAR` ou `M$(L,C) = 0`).
- **B4.** `FILL A v` : tout le tableau à v (`FILL M$ 32`).
- **B5.** Valeur de départ : 0, la fin de chaîne (chaîne vide), comme les entiers.
- **B6.** Comparaison avec un texte écrit : oui (`IF R$ = "O"`, `<>`, `<`...).
- **B7.** Exemples : un serpent et un tableau des meilleurs scores.
- **B8.** Palier B seul d'abord, C ensuite.
- **DIM** : taille nulle ou négative refusée. **Redimensionner sans perdre les données**
  (`REDIM`, comme `ReDim Preserve`) : possible (tableaux contigus, ceux d'après déplacés,
  0,3 à 0,5 Ko), **plus tard** (backlog).
- **ANIM** : vérifie toujours la place libre (texte, animation, tableaux), interprété et
  traduit.
