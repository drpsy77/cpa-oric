# EDSPRITE — référence

Éditeur plein écran des fichiers `.SPR` de GRAPHER (format : `grapher.md` § 10.1) : sprites
(genre 0 : dessin et silhouette) et tuiles ou caractères (genre 1 : dessin seul, copiés dans
la police par `TFONT`). Il remplace HEX et `tools/mkspr.py` pour fabriquer ces fichiers sur
l'Oric. Un `.COM` (8 540 octets ; 8 391 en anglais), rien de résident. Sur les disquettes qui
ont GRAPHER : `cpa.dsk`, `cpa-logo.dsk`, `cpa-asm.dsk`, `cpa-anim.dsk` et leurs jumelles
anglaises.

## 1. Appel

    EDSPRITE             nouveau fichier (sans nom : demandé à l'enregistrement)
    EDSPRITE HEROS       ouvre HEROS.SPR (le type est ajouté), ou le crée

Un nouveau fichier a un sprite `SP01` de 2 × 2 caractères (genre 0) ou un caractère `CAR1`
(genre 1). Un fichier qui n'est pas un `.SPR` (signature `SPR`, version 1, genre 0 ou 1,
tailles de 1 à 4, longueur juste) est refusé : `Pas un fichier .SPR`. Lancé en mode SPLIT,
EDSPRITE passe en texte et y revient en sortant, l'image intacte.

## 2. Écran

     0|  Fichier Edit Sprite Dessin Vue     A
     1|     1  :  2  :  3  :  4  : HEROS.SPR
     2|   ....####...:.....:.....:>HER1 2x2 S
     3|   ...######..:.....:.....: HER2 2x2 S
     4|   ...# ## #..:.....:.....: MSTR 2x2 M
     5|  1...######..:.....:.....: BOSS 4x4 S
     6|   ....####...:.....:.....:
     7|   .....##....:.....:.....:
     8|   ..########.:.....:.....:
     9|   _##########+_____+_____+
    10|   .#..####..#:.....:.....:
    11|   .#..####..#:.....:.....:
    12|   ....####...:.....:.....:
    13|  2....#:.#...:.....:.....:
    14|   ...##:.##..:.....:.....:
    15|   ...#.:..#..:.....:.....: 1/4
    16|   ..##.:..##.:.....:.....: sprites
    17|   _____+_____+_____+_____+
    18|   .....:.....:.....:.....: Reel
    19|   .....:.....:.....:.....:
    20|   .....:.....:.....:.....:::::::::
    21|  3.....:.....:.....:.....:::::::::
    22|   .....:.....:.....:.....:::::@@::
    23|   .....:.....:.....:.....:::::@@::
    24|   .....:.....:.....:.....:::::::::
    25|   _____+_____+_____+_____+::::::::
    26|
    27|  x7 y12 car 2,2 plein  crayon      *

- **Grille** (colonnes 3-26, lignes 2-25) : un point du sprite par case de l'écran, 4 × 3
  caractères visibles (24 × 24 points) ; un sprite de 4 caractères de haut défile d'un
  caractère quand le curseur sort de la grille. Colonne 2 : numéro de la ligne de caractères ;
  ligne 1 : numéros des colonnes de caractères. Le curseur clignote.
- **Trois états**, dessinés par des caractères redéfinis : point plein (case entièrement
  allumée, `#` ci-dessus), masque (point éteint qui cache le décor : case vide), transparent
  (case grisée en damier, `.`). Genre 1 : deux états, plein et vide.
- **Limites des caractères** : sur la 6e colonne de points d'un caractère, un trait à droite
  de la case ; sur la 8e ligne, un trait en bas ; au coin, les deux (`:`, `_`, `+` ci-dessus).
  Le trait se superpose à l'état : allumé sur une case vide ou grisée, éteint sur une pleine.
- **Mode `S` ou `M`** (sprite ou masque), propre à chaque sprite, affiché dans la liste ;
  il vaut pour la grille, les codes et « Réel ». `S` : les trois états, les octets du dessin,
  le sprite. `M` : la silhouette ; plein et masque sont pleins tous les deux, le transparent
  reste grisé ; les octets de la silhouette ; la silhouette dans « Réel ». Ce mode sert à
  l'affichage : il n'est pas enregistré.
- **Liste** (ligne 1 : le fichier ; lignes 2-13 : un sprite par ligne, nom, taille, `S` ou
  `M`, défilement au-delà de 12) ; `>` montre le sprite courant. Lignes 15-16 : rang, nombre,
  genre.
- **Réel** (lignes 20-25, colonnes 28-33) : le sprite en taille réelle au milieu d'un décor
  (vide, damier, briques, herbe), avec les vrais caractères redessinés ; il suit chaque point
  posé.
- **Codes** (`^H` ou menu Vue) : à la place de la liste et de « Réel », en face de chaque ligne
  de points de la grille, ses octets en hexadécimal (deux chiffres par caractère de largeur) :
  ceux du dessin en mode `S`, de la silhouette en mode `M`. `^H` de nouveau : la liste.
- **Ligne d'état** (27) : position du curseur (point), caractère, état du point, `crayon`
  s'il est baissé, `*` si le fichier a changé ; les questions et messages s'y affichent aussi.

## 3. Touches

Deux zones : la **saisie** (la grille) et la **sélection** (la liste des sprites). `^I` passe
de l'une à l'autre (ou menu Sprite, Select / Saisie).

| Touche | Saisie | Sélection |
|---|---|---|
| flèches | déplacer le curseur d'un point | ↑ ↓ : sprite précédent / suivant |
| SHIFT + flèches | au bord du caractère, puis caractère suivant | page de 12 |
| CTRL ← / CTRL → | sprite précédent / suivant | sprite précédent / suivant |
| CTRL ↑ / CTRL ↓ | premier / dernier sprite | premier / dernier sprite |
| ESPACE | point plein / transparent | — |
| `M` | masque / transparent (genre 0) | mode masque |
| `S` | — | mode sprite |
| DEL | point transparent (genre 1 : vide) | — |
| `P` | crayon : en se déplaçant, le curseur pose le dernier état choisi ; `P` de nouveau, ou ESC, le lève | — |
| RETURN | — | passer à la saisie |
| `^H` | codes hexadécimaux / liste et « Réel » | idem |
| `^Z` `^X` `^C` `^V` | annuler, couper, copier, coller le caractère sous le curseur | le sprite entier |
| `^N` `^O` `^S` `^Q` | nouveau fichier, ouvrir, enregistrer, quitter | idem |

## 4. Menus (FUNCT)

- **Fichier** : Nouveau `^N` (question : sprites ou tuiles), Ouvrir... `^O`, Enregistrer `^S`,
  Enreg. sous..., Quitter `^Q`. Un fichier modifié demande confirmation avant d'être
  abandonné.
- **Edit** : Annuler `^Z`, Couper `^X`, Copier `^C`, Coller `^V`, Effacer. Dans la sélection,
  ils agissent sur le sprite entier (couper le retire, sauf s'il est le dernier ; coller
  insère la copie après le courant ; effacer le rend tout transparent) ; dans la saisie, sur le
  caractère sous le curseur. Annuler reprend le dessin du sprite d'avant la dernière
  modification (un niveau ; pas les ajouts ni les suppressions de sprites).
- **Sprite** : Nouveau... (taille de 1 à 4 × 1 à 4, tapée `2X2`, puis nom de 1 à 4 lettres ou
  chiffres ; il se place après le courant), Dupliquer (la copie prend le nom avec le dernier
  chiffre augmenté : `HER1` → `HER2`), Supprimer (confirmation), Renommer..., Taille... (le
  dessin garde son coin haut-gauche), Avancer / Reculer d'un rang dans le fichier, Select,
  Saisie.
- **Dessin** : Inverser (plein ↔ masque, le transparent reste ; genre 1 : plein ↔ vide),
  Miroir horizontal, Miroir vertical, Quart de tour (sprite carré en points : 4 × 3 caractères seulement), Décaler d'un
  point dans les 4 sens (ce qui sort rentre de l'autre côté), Silhouette = dessin. Genre 1 :
  Prendre police.. copie le dessin des caractères du jeu standard à partir d'un code (32 à
  127) comme point de départ. Chaque transformation s'annule par `^Z`.
- **Vue** : Codes hexa `^H`, Décor (vide, damier, briques, herbe, à tour de rôle), Animer :
  fait défiler dans « Réel » les sprites de même taille dont le nom commence pareil (sans les
  chiffres de la fin : `HER1`, `HER2`...), un toutes les 12/50 s ; une touche arrête.

## 5. Fichiers et sûreté

- Tout le fichier est en mémoire : environ 34 Ko (29 Ko lancé en mode SPLIT), soit plus de
  120 sprites de 4 × 4 ; 255 sprites au plus. Au-delà : `Memoire pleine`.
- Enregistrement comme EDIT : `NOM.$$$` écrit en entier, puis l'ancien effacé et le nouveau
  renommé. Disque plein, répertoire plein, fichier protégé : message, l'ancien reste intact.
  Le dernier enregistrement est complété par des zéros. Essais : `tools/test_fichiers.py`
  (normal, disque plein, répertoire plein, R/O, enregistrer sous, remplacer, RESET).
- Enreg. sous un fichier qui existe : `Remplacer ce fichier (O/N) ?`.

## 6. Mise en œuvre

- Les 12 caractères de la grille (3 états × sans trait, à droite, en bas, les deux) prennent
  des codes de la police standard qu'aucun texte du programme ni du système n'affiche
  (``@ # [ \ ] _ ` { | } ~`` et DEL) : les menus déroulants s'écrivent dans la police de la ligne, la
  police secondaire n'y est pas possible. L'aperçu prend les codes 64-79 (sprite) et 80
  (décor) du jeu secondaire (attribut 9 en colonne 27, 8 en colonne 34), plus bas que tout
  menu déroulant. Les dessins d'origine des 12 codes sont gardés (pour « Prendre police ») ;
  en sortant, le démarrage à chaud rend la police.
- La grille est redessinée case par case (une lecture du sprite par caractère et par ligne
  de points, puis ses 6 points).

## 7. Plus tard

- Sprites en HIRES plein écran : le format `.SPR` (6 points par octet) convient déjà ; il
  manque l'affichage dans GRAPHER (bibliothèque), pas l'éditeur.
- Caractères animés au 50 Hz (`etat.md` § 2 point 1).
