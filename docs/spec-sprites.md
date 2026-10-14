# Sprites en mode texte — spécification

Rien n'est codé. Décidés : le format des fichiers `.SPR` (§ 1-4) et l'affichage (§ 5-7).
Reste à préciser : les tuiles (§ 8). Viendront ensuite les commandes de GRAPHER (et peut-être
de LOGO), une bibliothèque d'affichage (`SPR.INC`, commune à l'interpréteur et aux programmes
traduits) et un éditeur de sprites (`.COM` plein écran).

## 1. Principe

En mode texte, l'Oric n'affiche que des cases de 6 × 8 points ; chaque case contient un code
qui désigne un dessin de 8 octets de la police. Un sprite est un groupe de caractères, de 1 à
4 colonnes sur 1 à 4 lignes, redessinés à chaque affichage et posés à la place des codes du
décor. Chaque ligne d'une case recouverte est la combinaison :

    case affichée = (décor AND NOT silhouette) OR dessin

| Dessin | Silhouette | À l'écran |
|---|---|---|
| 0 | 0 | le décor (transparent) |
| 1 | 0 ou 1 | point allumé |
| 0 | 1 | point éteint : le décor y est caché |

Le personnage se fond ainsi dans le décor : celui-ci reste visible autour de sa silhouette,
dans ses propres cases. La silhouette ne compte que pour les points éteints du personnage
(yeux, contour noir). Comme sur l'Oric, la couleur est celle de la ligne (attributs) : le
personnage prend la couleur des lignes où il passe.

## 2. Le fichier

Tout est aligné sur 8 octets, la largeur d'une ligne de HEX : chaque bloc commence en début de
ligne, chaque case d'un sprite tient sur deux lignes (dessin, silhouette). Les sprites se
suivent sans trou ; leur nom aide à les retrouver dans HEX et servira à l'éditeur. Type par
défaut : `.SPR`.

**En-tête du fichier (8 octets)**

| Octet | Contenu |
|---|---|
| 0-2 | `SPR` (signature) |
| 3 | version : 1 |
| 4 | nombre de sprites (1 à 255) |
| 5 | genre : 0 = sprites (cases de 16 octets : dessin, silhouette) ; 1 = tuiles (cases de 8 octets : dessin seul) |
| 6-7 | 0 (réservés) |

**Chaque sprite : un en-tête de 8 octets**

| Octet | Contenu |
|---|---|
| 0 | largeur en colonnes : 1 à 4 |
| 1 | hauteur en lignes : 1 à 4 |
| 2-3 | 0 (réservés : plus tard, peut-être un point d'ancrage ou un délai d'animation) |
| 4-7 | nom de 4 caractères ASCII, complété par des espaces (`HERO`, `ENN1`) |

**puis ses cases** (largeur × hauteur), ligne par ligne puis colonne par colonne (2 × 2 :
haut-gauche, haut-droite, bas-gauche, bas-droite), 16 octets chacune (8 pour une tuile) :

| Octets | Contenu |
|---|---|
| 0-7 | le **dessin**, de la ligne du haut à celle du bas |
| 8-15 | la **silhouette** (1 = le point appartient au personnage), dans le même ordre ; absente pour une tuile |

**Chaque octet** : 6 points dans les bits 5 à 0 (bit 5 = point de gauche, comme la police de
l'Oric) ; bits 7 et 6 à 0. Un sprite rempli de zéros est entièrement transparent.

**Taille** : 8 octets, puis par sprite 8 + 16 × largeur × hauteur (1 × 1 : 24 octets ; 4 × 4 :
264) ; pour une tuile, 8 + 8 × largeur × hauteur. GRAPHER désigne les sprites par leur rang
dans le fichier, à partir de 0 ; une animation est une suite de sprites (`HER1`, `HER2`...).

## 3. Exemple : un bonhomme de 1 colonne sur 2 lignes

    case (0,0)       dessin   silhouette
      ligne 0  .XXXX.   1E       1E
      ligne 1  .X..X.   12       1E     <- yeux : points éteints opaques
      ligne 2  .XXXX.   1E       1E
      ligne 3  ..XX..   0C       0C
      ligne 4  XXXXXX   3F       3F
      ligne 5  X.XX.X   2D       2D
      ligne 6  ..XX..   0C       0C
      ligne 7  .X..X.   12       12
    case (0,1)
      ligne 0  .X..X.   12       12
      ligne 1  .X..X.   12       12
      ligne 2  XX..XX   33       33
      lignes 3-7        00       00     <- bas de la case : le décor reste visible

`HERO.SPR` (48 octets) dans HEX :

    0000  53 50 52 01 01 00 00 00   SPR.....   fichier : version 1, 1 sprite, genre 0
    0008  01 02 00 00 48 45 52 4F   ....HERO   1 colonne, 2 lignes, « HERO »
    0010  1E 12 1E 0C 3F 2D 0C 12   ........   case (0,0) : dessin
    0018  1E 1E 1E 0C 3F 2D 0C 12   ........   case (0,0) : silhouette
    0020  12 12 33 00 00 00 00 00   ..3.....   case (0,1) : dessin
    0028  12 12 33 00 00 00 00 00   ..3.....   case (0,1) : silhouette

## 4. Choix du format

- Silhouette : 1 = le point appartient au personnage (le contraire du masque d'Oricium,
  `tuile AND masque OR sprite` : la routine l'inverse).
- Sprites de tailles différentes à la suite (pas d'emplacements fixes) ; le nom dans le
  fichier, pratique dans HEX et pour l'éditeur.
- Chargement par `BLOAD` dans un tableau `$` (`docs/grapher.md` § 10).

## 5. Affichage : principes

- **Mouvement de case en case** (pas au point près).
- **Tailles libres** de 1 × 1 à 4 × 4, mélangées ; aucun genre de jeu supposé.
- **Rien n'est réservé pour rien** (comme les sprites HIRES du jeu EDGE) : un sprite affiché
  occupe exactement un caractère redéfini par case couverte, pris à l'affichage et rendu au
  retrait ; les dessins restent dans le tableau chargé du fichier et ne coûtent aucun
  caractère.
- **Le programmeur est responsable** (comme en C) : il répartit les codes entre lettres,
  tuiles et sprites, choisit le jeu de caractères de chaque partie de l'écran et le tas qui
  va avec. Le code traduit (`/A`) ne vérifie rien ; l'interprété vérifie ce qui est indiqué
  au § 7.
- **Préserver au minimum les chiffres, les lettres majuscules et l'espace** : il reste 59
  codes redéfinissables dans le jeu standard (33-47, 58-64, 91-127), pris où l'on veut.
- **Jeu de caractères secondaire** (`$B800`) : seuls les codes 32 à 111 existent (112 à 127
  tomberaient sur l'écran, en `$BB80`). `INPUT` passe par la fonction 10 du BDOS, qui range
  la ligne éditée en `$BA00` (codes 64 à 79) et l'historique en `$BA80-$BB7F` (codes 80 à
  111) : un `INPUT` abîme ces caractères.
- **Attributs prioritaires** : une case du décor qui contient un attribut (code inférieur à
  32) n'est jamais recouverte ; le sprite y est invisible. Remplacer un attribut changerait
  la couleur de toute la fin de la ligne. Le programmeur qui veut des personnages entiers met
  ses attributs là où ils ne passent pas (colonnes 0-1, bord de la zone de jeu).

## 6. Données

**Le tableau de sprites** `S$`, chargé tel quel par `BLOAD` (§ 2).

**Deux tas au plus**, un par jeu de caractères : la liste des codes que la bibliothèque a le
droit de redessiner. Le programmeur la donne dans un tableau d'entiers (déclaré, ou chargé
par `LOAD`), les codes dans n'importe quel ordre. La bibliothèque garde pour chaque tas :

| Donnée | Taille | Rôle |
|---|---|---|
| tableau des codes | celui du programmeur | une **pile** : les `sommet` premiers éléments sont les codes libres. Prendre : `sommet - 1`, lire ; rendre : écrire, `sommet + 1`. L'ordre des codes change, sans importance |
| sommet | 1 octet | nombre de codes libres ; au départ, la taille du tableau |
| base | 2 octets | `$B400` (standard) ou `$B800` (secondaire) |
| `SOUS` | 96 octets | pour chaque code de 32 à 127 : l'octet du décor caché par le caractère qui porte ce code ; 0 = code libre |

Le programmeur ne modifie pas le tableau d'un tas pendant que des sprites sont affichés.
**Aucun code d'un tas ne doit apparaître dans le décor.**

**Les emplacements** : un emplacement = un objet affiché, 5 octets (numéro du sprite,
colonne, ligne, tas, actif). La taille se lit dans l'en-tête du sprite ; les codes pris se
lisent à l'écran ; ce qu'ils cachent est dans `SOUS`. Le nombre d'emplacements est fixé par
le programme.

## 7. Commandes et algorithmes

| Commande | Effet |
|---|---|
| `SPRITES n` | réserve n emplacements (0 à n-1), comme un `DIM` |
| `SPOOL T [ALT]` | le tableau d'entiers T devient le tas du jeu standard (ou secondaire) ; tous ses codes sont libres |
| `SSHOW k S$ n col lig [ALT]` | affiche le sprite n de `S$` dans l'emplacement k, avec le tas du jeu indiqué ; sur un emplacement déjà actif, retire d'abord l'ancien : c'est aussi le déplacement et l'image suivante d'une animation |
| `SHIDE k` | retire le sprite de l'emplacement k : décor remis, codes rendus |

**`SSHOW k S$ n col lig [ALT]`**

    1. Si l'emplacement k est actif : SHIDE k.
    2. Trouver le sprite n : p <- début de S$ + 8 ; n fois p <- p + 8 + 16 × L × H ;
       L, H <- S$[p], S$[p+1] ; cases <- p + 8.
    3. Pour chaque case (i, j), c = i × L + j :
         E <- $BB80 + 40 × (lig + i) + (col + j)
         V <- mémoire[E] ; inv <- V AND 128 ; v <- V AND 127
         si v < 32 : case suivante (attribut, § 5)
         si SOUS[v] <> 0 : (un sprite de ce tas est déjà là : on dessine sur lui)
             r <- v
         sinon :
             si sommet = 0 : retirer ce qui vient d'être posé, erreur
             r <- code pris dans le tas ; SOUS[r] <- V
         tuile <- base + 8 × v ; cible <- base + 8 × r
         pour y de 0 à 7 :
           mémoire[cible + y] <- (mémoire[tuile + y] AND NOT silhouette[c, y])
                                 OR dessin[c, y]
         mémoire[E] <- r OR inv       (dessiné avant d'être montré)
    4. Emplacement k <- n, col, lig, tas, actif.

**`SHIDE k`**

    pour chaque case du rectangle (col, lig, L, H) de l'emplacement :
      r <- mémoire[E] AND 127
      si SOUS[r] <> 0 : mémoire[E] <- SOUS[r] ; SOUS[r] <- 0 ; rendre r au tas
    actif <- 0

**Règles pour le programmeur**

- Deux sprites qui se chevauchent partagent le caractère commun (le second se dessine sur le
  premier). Retirer l'un remet le décor sur la partie commune : réafficher l'autre. Aucun
  code n'est perdu, quel que soit l'ordre des retraits.
- Ne pas changer le décor sous un sprite affiché : le retirer d'abord.
- Le tas doit correspondre au jeu de caractères des lignes où passe le sprite. Un personnage
  à cheval sur deux jeux est découpé en deux sprites.

**Erreurs** (interprété seulement) : `plus de caracteres pour les sprites` (tas vide) ;
emplacement hors de 0 à n-1, sprite absent du fichier, sprite qui dépasse l'écran, tas non
déclaré, fichier qui n'est pas un `.SPR` de genre 0 : `valeur hors limites` ou un message
court à choisir.

**Coût estimé** : ~400 cycles par case affichée, ~50 par case retirée ; un 2 × 2 déplacé :
~2 ms, prévoir 4 ms. Mémoire : 5 octets par emplacement, ~100 octets par tas (plus le
tableau du programmeur). Bibliothèque : prévoir 2 à 3 Ko. GRAPHER passe à 7 blocs sur la
disquette.

**Système** : un programme qui redessine le jeu secondaire abîme l'historique des lignes
(`$BA80-$BB7F`) ; le retour au système le vide dans ce cas (quelques octets).

## 8. Questions ouvertes

- **Tuiles** (fichier de genre 1) : commandes `TILES T$ ...` (dessins copiés dans la police)
  et `TILE n col lig` (codes posés à l'écran) ; comment le programme choisit les codes d'une
  tuile de plusieurs cases (codes consécutifs, ou liste comme pour les tas).
- Si le parcours du fichier (étape 2) est trop lent pour les derniers sprites : table des
  positions construite au chargement.
- Plus tard : sprites qui apportent leur couleur (cases « attribut » dans le fichier, posées
  telles quelles, remises au retrait).
