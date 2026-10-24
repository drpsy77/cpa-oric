# Éditeur de sprites et de caractères — spécification de travail

Programme `.COM` plein écran qui dessine les fichiers `.SPR` de GRAPHER (format :
`grapher.md` § 10.1) : sprites (genre 0 : dessin et silhouette) et tuiles ou caractères
(genre 1 : dessin seul, copiés dans la police par `TFONT`). Il remplace HEX et
`tools/mkspr.py` pour fabriquer ces fichiers sur l'Oric. Nom provisoire : SPRED.

## 1. Fait

Rien n'est codé. Le format `.SPR` existe et sert déjà (`BLOAD`, `SSHOW`, `TFONT`) ; ses
noms de 4 caractères étaient prévus pour l'éditeur.

## 2. Décidé, pas encore fait

### 2.1 Écran

L'écran texte entier (40 × 28, colonnes 0-1 : attributs) :

    ligne 0    Fichier Sprite Dessin Vue                A    barre de menus (FUNCT)
    ligne 1    HEROS.SPR  HER1  2x2  1/4  sprites           fichier, sprite, taille, rang
    ligne 2      0     6     12    18                       règle (colonnes de points)
    ligne 3     0..##...##......:....  |  ::::::::::        grille 24 x 24 points
    ...          ..#####.##....:..... |  ::::@@::::        aperçu en taille réelle,
    ...          ..#o##o###..........  |  ::::@@::::        sur un décor
    ...          ...                   |  ::::::::::
    ...                                |  HER1 2x2         liste des sprites du
    ...                                |  HER2 2x2         fichier (le courant en
    ...                                |  ...              vidéo inverse)
    ligne 26     ...                   |
    ligne 27   x 7 y 12  case 1,1  # crayon       ^S       état

- **Grille** : un point du sprite par case de l'écran. `#` (case pleine) : point allumé ;
  `o` : point éteint qui cache le décor (silhouette seule, yeux, contour noir) ; `.` :
  transparent. 24 × 24 points visibles : un sprite de 4 lignes (32 points de haut) défile
  d'une ligne de caractères quand le curseur sort de la grille. La règle et la ligne d'état
  disent dans quelle case (colonne, ligne) du sprite est le curseur.
- **Aperçu** : le sprite en taille réelle, avec les vrais caractères redessinés (jeu
  secondaire, codes 64 à 79), au milieu d'un décor choisi (menu Vue : vide, damier,
  briques, herbe) ; il suit chaque point posé.
- **Liste** : les sprites du fichier (nom, taille) ; le courant en vidéo inverse.
- Genre 1 (tuiles, caractères) : `o` et les commandes de silhouette n'existent pas ; l'aperçu
  montre le dessin seul.

### 2.2 Touches (mêmes touches que EDIT, HEX et CMDER, `manuel.md`)

| Touche | Effet |
|---|---|
| flèches | déplacer le curseur d'un point |
| SHIFT + flèches | au bord de la case (6 ou 8 points), puis à la case suivante |
| ESPACE | point allumé / transparent |
| `O` | point opaque (éteint, cache le décor) / transparent (genre 0) |
| `P` | crayon : en se déplaçant, le curseur pose le dernier état choisi (`#`, `o` ou `.`) ; `P` de nouveau, ou ESC, le lève |
| CTRL-← / CTRL-→ | sprite précédent / suivant |
| CTRL-↑ / CTRL-↓ | premier / dernier sprite |
| CTRL-X / CTRL-C / CTRL-V | couper / copier / coller un sprite entier (images d'une animation) |
| CTRL-Z | annuler le dernier changement (un niveau) |
| CTRL-S / CTRL-Q | enregistrer / quitter (question si le fichier a changé) |
| FUNCT | menus |

### 2.3 Menus

- **Fichier** : Nouveau (genre : sprites ou tuiles/caractères), Ouvrir..., Enregistrer `^S`,
  Enreg. sous..., Quitter `^Q`.
- **Sprite** : Nouveau (taille 1-4 × 1-4, nom), Dupliquer, Supprimer, Renommer, Taille (le
  dessin garde son coin haut-gauche), Avancer / Reculer dans le fichier, Couper `^X`,
  Copier `^C`, Coller `^V`.
- **Dessin** : Effacer, Inverser, Miroir horizontal, Miroir vertical, Rotation d'un quart de
  tour (sprite carré), Décaler d'un point (4 sens, ce qui sort rentre de l'autre côté),
  Silhouette = dessin, Contour (silhouette = dessin et un point autour : un bord noir qui
  détache le sprite du décor), Annuler `^Z`.
- **Vue** : Décor de l'aperçu, Silhouette seule, Animer (fait défiler dans l'aperçu les
  sprites dont le nom commence pareil, `HER1` `HER2`... ; une touche arrête).
- Genre 1, menu Dessin : « Prendre dans la police » copie le dessin de caractères existants
  (codes 32-127 du jeu standard) comme point de départ, pour retoucher une lettre.

### 2.4 Fichiers et sûreté

- `SPRED NOM` ouvre `NOM.SPR` (le type est ajouté) ou le crée ; sans nom : nouveau fichier.
- Lecture : signature `SPR`, version 1, genre 0 ou 1, tailles 1-4 ; sinon `fichier .SPR ?`.
- Enregistrement comme EDIT : `NOM.$$$` écrit en entier, puis l'ancien effacé et le nouveau
  renommé ; disque plein, répertoire plein, fichier protégé : message, l'ancien reste
  intact. Ajouté à `tools/test_fichiers.py`.
- Mémoire : tout le fichier en mémoire (environ 30 Ko de TPA, soit plus de 100 sprites de
  4 × 4) ; au-delà : `memoire pleine`.
- Messages, menus et décor en deux langues (`progs/msg/fr`, `progs/msg/en`).

### 2.5 Coût et place

- `.COM` estimé entre 7 et 10 Ko (prévu large : CMDER fait 13,5 Ko), 4 à 5 blocs.
- Sur les disquettes qui ont GRAPHER : `cpa.dsk` (62 Ko libres), `cpa-logo.dsk`,
  `cpa-anim.dsk`, `cpa-asm.dsk`, et leurs jumelles anglaises.
- Rien dans le système, rien dans le contrat.

### 2.6 Plus tard

- Sprites en HIRES plein écran : le format `.SPR` (6 points par octet) convient déjà ; il
  manque l'affichage dans GRAPHER (bibliothèque), pas l'éditeur.
- Caractères animés au 50 Hz (`etat.md` § 2 point 1).

## 3. Questions ouvertes

1. Le nom : SPRED, ou un autre ?
2. La grille : un point par case (clair, mais un sprite de 4 lignes défile), ou deux
   points par case en hauteur (tout le sprite visible, curseur moins net) ?
