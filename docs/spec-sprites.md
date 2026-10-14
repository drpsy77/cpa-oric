# Sprites en mode texte : format des fichiers `.SPR`

Format validé par Pierre le 14 octobre 2026. Rien n'est codé : les commandes de GRAPHER (et
peut-être de LOGO), la bibliothèque d'affichage et l'éditeur de sprites viendront ensuite
(backlog, `docs/projet-disquette.md`).

## 1. Principe

En mode texte, l'Oric n'affiche que des cases de 6 × 8 points ; chaque case contient un code
qui désigne un dessin de 8 octets de la police. Un sprite est un groupe de **caractères
réservés**, de 1 à 4 colonnes sur 1 à 4 lignes, redessinés à chaque déplacement et posés à la
place des tuiles du décor. Chaque ligne d'une case réservée est la combinaison :

    case affichée = (tuile AND NOT silhouette) OR dessin

| Dessin | Silhouette | À l'écran |
|---|---|---|
| 0 | 0 | le décor (transparent) |
| 1 | 0 ou 1 | point allumé |
| 0 | 1 | point éteint : le décor y est caché |

Le personnage se fond ainsi dans la tuile : le décor reste visible autour de sa silhouette,
dans ses propres cases. La silhouette ne compte que pour les points éteints du personnage
(yeux, contour noir). Comme sur l'Oric, la couleur est celle de la ligne (attributs) : le
personnage prend la couleur des lignes où il passe.

## 2. Le fichier

Tout est aligné sur 8 octets, la largeur d'une ligne de HEX : chaque bloc commence en début de
ligne, chaque case d'un sprite tient sur deux lignes (dessin, silhouette). Les sprites se
suivent sans trou (place optimisée) ; leur nom aide à les retrouver dans HEX et servira à
l'éditeur. Type par défaut : `.SPR`.

**En-tête du fichier (8 octets)**

| Octet | Contenu |
|---|---|
| 0-2 | `SPR` (signature) |
| 3 | version : 1 |
| 4 | nombre de sprites (1 à 255) |
| 5-7 | 0 (réservés) |

**Chaque sprite : un en-tête de 8 octets**

| Octet | Contenu |
|---|---|
| 0 | largeur en colonnes : 1 à 4 |
| 1 | hauteur en lignes : 1 à 4 |
| 2-3 | 0 (réservés : plus tard, peut-être un point d'ancrage ou un délai d'animation) |
| 4-7 | nom de 4 caractères ASCII, complété par des espaces (`HERO`, `ENN1`) |

**puis ses cases** (largeur × hauteur), ligne par ligne puis colonne par colonne (2 × 2 :
haut-gauche, haut-droite, bas-gauche, bas-droite), 16 octets chacune :

| Octets | Contenu |
|---|---|
| 0-7 | le **dessin**, de la ligne du haut à celle du bas |
| 8-15 | la **silhouette** (1 = le point appartient au personnage), dans le même ordre |

**Chaque octet** : 6 points dans les bits 5 à 0 (bit 5 = point de gauche, comme la police de
l'Oric) ; bits 7 et 6 à 0. Un sprite rempli de zéros est entièrement transparent.

**Taille** : 8 octets, puis par sprite 8 + 16 × largeur × hauteur (1 × 1 : 24 octets ; 4 × 4 :
264). GRAPHER désignera les sprites par leur rang dans le fichier, à partir de 0 ; une
animation est une suite de sprites (`HER1`, `HER2`...).

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

    0000  53 50 52 01 01 00 00 00   SPR.....   fichier : version 1, 1 sprite
    0008  01 02 00 00 48 45 52 4F   ....HERO   1 colonne, 2 lignes, « HERO »
    0010  1E 12 1E 0C 3F 2D 0C 12   ........   case (0,0) : dessin
    0018  1E 1E 1E 0C 3F 2D 0C 12   ........   case (0,0) : silhouette
    0020  12 12 33 00 00 00 00 00   ..3.....   case (0,1) : dessin
    0028  12 12 33 00 00 00 00 00   ..3.....   case (0,1) : silhouette

## 4. Choix de Pierre

- Silhouette : 1 = le point appartient au personnage (le contraire du masque d'Oricium,
  `tuile AND masque OR sprite` : la routine l'inversera).
- Sprites de tailles différentes à la suite (pas d'emplacements fixes) ; le nom dans le
  fichier, pratique dans HEX et pour l'éditeur à venir.
- Octets 2-3 de chaque sprite à 0 pour l'instant.
- Taille : 1 à 4 colonnes sur 1 à 4 lignes ; tableau stocké en fichier, modifiable avec HEX.

## 5. Encore ouvert (à voir avant tout code)

- Mouvement de case en case, ou au point près (copies décalées, une case de plus en largeur et
  en hauteur).
- Nombre de sprites affichés à la fois, codes des caractères réservés (sur les 96 codes
  32-127), jeu de caractères secondaire ou non.
- Commandes de GRAPHER (chargement du `.SPR`, pose, retrait) et bibliothèque commune
  (interprété et traduit, comme `ARR.INC`).
