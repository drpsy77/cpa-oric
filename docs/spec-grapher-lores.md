# GRAPHER : écran texte (LORES), tableaux et chaînes — spécification

État : **proposition à relire par Pierre** (octobre 2026). Rien n'est codé.
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
| `LORES` | le programme prend l'écran texte entier : 40 colonnes (0-39) × 28 lignes (0-27), ligne 0 et colonnes 0-1 comprises. L'écran est effacé (voir `CLS`), le curseur de la console est éteint, la barre de menus disparaît, FUNCT est ignoré. Curseur d'écriture en colonne 2, ligne 0 (voir question Q1). |
| `TEXT` | retour à la console (comme aujourd'hui) : écran effacé, couleurs de PAPER et INK, barre de menus, curseur. |
| `CLS` | en LORES : efface l'écran (espaces), remet en colonnes 0 et 1 de chaque ligne le papier et l'encre courants de la console (PAPER, INK), curseur en colonne 2, ligne 0. Hors LORES : efface la console (comme la commande CLS du CCP). |

- `HIRES` et `SPLIT` depuis LORES : comme depuis le texte (l'écran texte est perdu).
- Les commandes de dessin (`PLOT`, `LINE`... `GTEXT`, `GNUM`, `ATTR`) restent réservées à
  HIRES et SPLIT : en LORES, l'erreur actuelle (`HIRES ou SPLIT d'abord`).
- **Fin du programme en LORES** (fin du fichier ou `END`) : comme en HIRES, l'écran reste
  affiché jusqu'à une touche, puis retour à la console. **ESC** entre deux lignes arrête,
  comme aujourd'hui. **Erreur** : retour à la console, puis le message habituel
  `L n COMMANDE : message`.
- `WAIT`, `DELAY`, `INKEY` inchangés (INKEY lit sans attendre, la répétition des touches
  est celle du menu Clavier).

### 1.2 Écrire et lire des cases

| Commande / fonction | Effet |
|---|---|
| `LOCATE col lig` | place le curseur d'écriture (col 0-39, lig 0-27, sinon `valeur hors limites`). |
| `CHAR col lig code` | écrit l'octet `code` (0-255) dans la case : un caractère (32-127), un attribut (0-31 : encre 0-7, papier 16-23, et les autres attributs de l'Oric), ou un caractère en vidéo inverse (+128). Le curseur ne bouge pas. |
| `SCRN(col,lig)` | fonction : l'octet de la case (0-255). |
| `ECHO texte` | écrit le texte au curseur, qui avance sur la ligne. Sans guillemets : comme aujourd'hui (espaces du début sautés). Entre guillemets : `ECHO "  Score : "` écrit exactement ce qui est entre les guillemets, espaces compris. `$1`-`$9` sont remplacés dans les deux cas. |
| `ECHO` (seul) | passe à la ligne suivante, en colonne 0 (voir Q1) ; après la ligne 27 : ligne 0. Rien n'est effacé. |
| `PRINT expr` | écrit le nombre au curseur (sans passage à la ligne), qui avance. |
| `SPC n` | écrit n espaces au curseur (efface), le curseur avance. |
| `TAB n` | avance le curseur de n colonnes **sans rien écrire** (relatif : en BASIC de l'Oric, `TAB(n)` va à la colonne n ; ici, `LOCATE` donne la colonne absolue). |

**Règle du bord droit** (ECHO, PRINT, SPC, TAB) : on n'écrit jamais au-delà de la colonne 39.
Ce qui dépasse est perdu, sans erreur ; le curseur reste « au bout » (colonne 40) et tout ce
qui suit sur cette ligne est ignoré jusqu'au prochain `LOCATE` ou `ECHO` seul. Rien ne passe
sur la ligne suivante (dont les colonnes 0-1 portent les attributs), rien ne fait défiler.

Hors LORES, `LOCATE`, `CHAR`, `SCRN`, `SPC` et `TAB` donnent l'erreur `LORES d'abord`.

### 1.3 Ce qu'il faut au système (touche au contrat : accord demandé)

En HIRES, le système sait qu'un programme a l'écran (`hires_on`, octet `$1E` en `$BFDF`) :
FUNCT est ignoré, les voyants de la barre (`A`/`a` par CTRL-T, `P` par CTRL-P) ne sont pas
redessinés, et le démarrage à chaud remet la console. En LORES, aucune case de l'écran ne
peut servir de marque (le programme les utilise toutes). Proposition :

- une **variable publique de la page 2**, `SCR_PROG` (adresse libre à choisir), mise à 1 par
  un programme qui prend l'écran texte ; `hires_on` devient « écran au programme » (HIRES
  ou `SCR_PROG`) ; le démarrage à chaud la remet à 0 et réaffiche la console (effacement,
  attributs, barre). Sans cela, CTRL-T écrirait `A` en ligne 0, colonne 37 d'un jeu.
- C'est un **ajout au contrat** (une variable publique de plus, dans `progs/cpa.inc` et
  `docs/architecture.md`), donc aussi dans la version ROM ; rien ne change pour l'existant.
- Coût estimé : 20 octets résidents (prévoir 40), sur 287 libres.

### 1.4 Bibliothèque

Les routines LORES (prendre l'écran, effacer, case, curseur d'écriture, texte et nombre bornés
à la ligne) vont dans `hires.inc`, la bibliothèque d'écran, pour servir aussi aux programmes
écrits en assembleur et aux programmes traduits (`/A`).

## 2. Palier B : DIM, tableaux et chaînes

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
- Question Q3 : faut-il aussi `INPUT V` pour un nombre ?

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

- **Q1. Colonnes 0 et 1.** `LORES` et `CLS` y mettent les couleurs de PAPER et INK, et le
  curseur part en colonne 2 : un texte écrit sans LOCATE a les couleurs de la console. Mais
  un `ECHO` seul ramène en colonne 0 (comme tu l'as demandé) : le texte suivant écrase alors
  les deux attributs de la ligne (la ligne repasse en noir et blanc, défaut de l'Oric).
  Propositions : (a) `ECHO` seul ramène en colonne 2, la colonne 0 restant accessible par
  LOCATE et CHAR ; ou (b) colonne 0, et LORES efface sans attributs (tout en espaces, noir et
  blanc, couleurs posées par le programme avec CHAR). Je penche pour (a).
- **Q2. `SCR_PROG`** : d'accord pour cet ajout au contrat (variable publique de la page 2) ?
- **Q3. `INPUT V`** (nombre) : utile ou non ?
- **Q4. Types par défaut** des fichiers : `.TXT` (texte), `.DAT` (binaire), `.SCR` (écran) ?
