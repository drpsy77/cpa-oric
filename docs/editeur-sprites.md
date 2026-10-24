# Éditeur de sprites et de caractères — spécification de travail

Programme `.COM` plein écran qui dessine les fichiers `.SPR` de GRAPHER (format :
`grapher.md` § 10.1) : sprites (genre 0 : dessin et silhouette) et tuiles ou caractères
(genre 1 : dessin seul, copiés dans la police par `TFONT`). Il remplace HEX et
`tools/mkspr.py` pour fabriquer ces fichiers sur l'Oric. Nom : EDSPRITE.

## 1. Fait

Rien n'est codé. Le format `.SPR` existe et sert déjà (`BLOAD`, `SSHOW`, `TFONT`) ; ses
noms de 4 caractères étaient prévus pour l'éditeur.

## 2. Décidé, pas encore fait

### 2.1 Écran

L'écran texte entier, 40 colonnes (0-1 : papier et encre de l'utilisateur, invisibles
ici), dans la police standard sauf l'aperçu :

     0|  Fichier Edit Sprite Dessin Vue     A
     1|     1  |  2  |  3  |  4  | Codes
     2|   ....####...:.....:.....: 0F3F2D3F
     3|   ...######..:.....:.....: 0F0C3F3F
     4|   ...# ## #..:.....:.....: 0F3F3F3F
     5|  1...######..:.....:.....: 0F0C3F3F
     6|   ....####...:.....:.....:
     7|   .....##....:.....:.....: HEROS.SPR
     8|   ..########.:.....:.....: HER1 2x2 S
     9|   _##########+_____+_____+ HER2 2x2 S
    10|   .#..####..#:.....:.....: MSTR 2x2 M
    11|   .#..####..#:.....:.....: BOSS 4x4 S
    12|   ....####...:.....:.....:
    13|  2....#:.#...:.....:.....:
    14|   ...##:.##..:.....:.....:
    15|   ...#.:..#..:.....:.....:
    16|   ..##.:..##.:.....:.....:
    17|   _____+_____+_____+_____+
    18|   .....:.....:.....:.....:
    19|   .....:.....:.....:.....: Reel
    20|   .....:.....:.....:.....: ::::::
    21|  3.....:.....:.....:.....: ::::::
    22|   .....:.....:.....:.....: ::@@::
    23|   .....:.....:.....:.....: ::@@::
    24|   .....:.....:.....:.....: ::::::
    25|   _____+_____+_____+_____+ ::::::
    26|  x 7 y 12  case 1,1  # crayon   ^S
    27|

- **Grille** (colonnes 3-26, lignes 2-25) : un point du sprite par case de l'écran, 4 × 3
  caractères visibles (24 × 24 points) ; un sprite de 4 lignes défile d'une ligne de
  caractères quand le curseur sort de la grille. Colonne 2 : numéro de la ligne de
  caractères (au milieu de ses 8 lignes de points) ; ligne 1 : numéros des colonnes.
- **Trois états**, dessinés par des caractères redéfinis : point plein (toute la case
  allumée, `#` ci-dessus), masque (point éteint qui cache le décor : case vide, ` `),
  transparent (case grisée, en damier : `.`).
- **Mode `S` ou `M`** (sprite ou masque), propre à chaque sprite, affiché dans la liste ;
  il vaut pour la grille, « Codes » et « Réel ». `S` : les trois états comme ci-dessus,
  « Codes » montre les octets du dessin, « Réel » le sprite. `M` : la silhouette ; les
  points pleins et les points de masque sont pleins tous les deux, le transparent reste
  grisé ; « Codes » montre les octets de la silhouette, « Réel » la silhouette.
- **Limites des caractères** : sur la 6e colonne de points de chaque caractère, un trait
  vertical à droite de la case ; sur la 8e ligne, un trait en bas ; au coin, les deux
  (`:`, `_`, `+` ci-dessus pour le transparent). Le trait se superpose à l'état : allumé
  sur une case vide ou grisée, éteint sur une case pleine. D'où 12 caractères : 3 états ×
  (sans trait, à droite, en bas, les deux).
- **Codes** (lignes 2-5) : les octets du dessin (`S`) ou de la silhouette (`M`), deux
  chiffres hexadécimaux par octet ; lesquels : § 3.
- **Liste** (ligne 7 : le fichier ; puis un sprite par ligne : nom, taille, `S` ou `M`) ;
  le sprite courant en vidéo inverse.
- **Réel** (lignes 20-25, colonnes 28-33) : le sprite en taille réelle, au milieu d'un
  décor (menu Vue : vide, damier, briques, herbe), avec les vrais caractères redessinés ;
  il suit chaque point posé.
- **Ligne d'état** (26) : position du curseur, case, état et crayon, `^S` si le fichier a
  changé ; les questions et messages s'y affichent aussi.
- Genre 1 (tuiles, caractères) : deux états seulement (plein, vide) ; « Réel » montre le
  dessin seul.
- Mise en œuvre : les 12 caractères de la grille prennent des codes de la police standard
  qu'aucun texte du programme ni du système n'affiche (ponctuation peu utilisée : `@ # [ \
  ] _ ` { | } ~` et DEL) ; l'aperçu prend les codes 64-79 du jeu secondaire (attribut 9 en
  colonne 27, 8 en colonne 34), plus bas que tout menu déroulant, qui s'écrit dans la police
  de la ligne. Le démarrage à chaud rend la police.

### 2.2 Zones et touches (mêmes touches que EDIT, HEX et CMDER, `manuel.md`)

Deux zones : la **saisie** (la grille) et la **sélection** (la liste des sprites) ;
CTRL-I passe de l'une à l'autre (ou menu Sprite, Select / Saisie).

| Touche | Saisie | Sélection |
|---|---|---|
| flèches | déplacer le curseur d'un point | ↑ ↓ : sprite précédent / suivant |
| SHIFT + flèches | au bord du caractère, puis au caractère suivant | page |
| CTRL-↑ / CTRL-↓ | premier / dernier sprite | premier / dernier sprite |
| ESPACE | point plein / transparent | — |
| `M` | masque / transparent (genre 0) | `S` / `M` : mode sprite ou masque du sprite choisi |
| `P` | crayon : en se déplaçant, le curseur pose le dernier état choisi ; `P` de nouveau, ou ESC, le lève | — |
| RETURN | — | passer à la saisie du sprite choisi |

### 2.3 Menus

- **Fichier** : Nouveau `^N` (genre : sprites ou tuiles/caractères), Ouvrir... `^O`,
  Enregistrer `^S`, Enreg. sous..., Quitter `^Q`.
- **Edit** : Annuler `^Z`, Couper `^X`, Copier `^C`, Coller `^V`, Effacer. Dans la
  sélection, ils agissent sur le sprite entier (images d'une animation) ; dans la saisie,
  sur le caractère sous le curseur.
- **Sprite** : Nouveau (taille 1-4 × 1-4, nom), Dupliquer, Supprimer, Renommer, Taille (le
  dessin garde son coin haut-gauche), Avancer / Reculer dans le fichier, Select, Saisie.
- **Dessin** : Inverser, Miroir horizontal, Miroir vertical, Rotation d'un quart de tour
  (sprite carré), Décaler d'un point (4 sens, ce qui sort rentre de l'autre côté),
  Silhouette = dessin. Genre 1 : « Prendre dans la police » copie le dessin de
  caractères existants (codes 32-127 du jeu standard) comme point de départ.
- **Vue** : Décor de l'aperçu, Animer (fait défiler dans « Réel » les sprites dont le nom
  commence pareil, `HER1` `HER2`... ; une touche arrête).

### 2.4 Fichiers et sûreté

- `EDSPRITE NOM` ouvre `NOM.SPR` (le type est ajouté) ou le crée ; sans nom : nouveau fichier.
- Lecture : signature `SPR`, version 1, genre 0 ou 1, tailles 1-4 ; sinon `fichier .SPR ?`.
- Enregistrement comme EDIT : `NOM.$$$` écrit en entier, puis l'ancien effacé et le nouveau
  renommé ; disque plein, répertoire plein, fichier protégé : message, l'ancien reste
  intact. Ajouté à `tools/test_fichiers.py`.
- Mémoire : tout le fichier en mémoire (environ 30 Ko de TPA, soit plus de 100 sprites de
  4 × 4) ; au-delà : `memoire pleine`.
- Messages, menus et décor en deux langues (`progs/msg/fr`, `progs/msg/en`).

### 2.5 Coût et place

- `.COM` estimé entre 8 et 11 Ko (prévu large : CMDER fait 13,5 Ko), 4 à 6 blocs.
- Sur les disquettes qui ont GRAPHER : `cpa.dsk` (62 Ko libres), `cpa-logo.dsk`,
  `cpa-anim.dsk`, `cpa-asm.dsk`, et leurs jumelles anglaises.
- Rien dans le système, rien dans le contrat.

### 2.6 Plus tard

- Sprites en HIRES plein écran : le format `.SPR` (6 points par octet) convient déjà ; il
  manque l'affichage dans GRAPHER (bibliothèque), pas l'éditeur.
- Caractères animés au 50 Hz (`etat.md` § 2 point 1).

## 3. Questions ouvertes

1. « Codes » : 4 lignes de 8 chiffres, soit 16 octets, alors qu'un sprite de 4 × 4 en a
   128 (dessin ou silhouette). Lesquels montrer : les 4 lignes de points à partir de celle
   du curseur (4 octets par ligne, la largeur d'un sprite de 4 caractères), ou un octet par
   ligne de la grille, aligné sur elle (la zone serait alors haute de 24 lignes) ?
