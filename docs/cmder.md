# CMDER — référence

Gestionnaire de fichiers en plein écran : une ou deux colonnes, disquettes A: à D: et clé USB
du LOCI. Liste triable et filtrable, marquage, Voir, Copier, Déplacer, Renommer, Effacer,
Attributs, tailles exactes ; copie avec un seul lecteur ; sur la clé, Dupliquer et Monter. Un
`.COM` (17 889 octets, 9 blocs), rien de résident. C'est d'abord un outil de liste et de tri ; pour copier une disquette entière,
DISKCOPY est plus rapide.

## 1. Appel

    CMDER                lecteur courant, tous les fichiers, plein écran
    CMDER B:*.COM        lecteur B:, filtre *.COM
    CMDER A: B:          deux colonnes (un modèle par lecteur : CMDER A:*.COM B:)
    CMDER USB:[chemin]   la clé USB du LOCI, dans le répertoire courant de CP/A, ou au
                         chemin donné, relatif à lui (JEUX, .., /JEUX, 2:/JEUX, 0:)
    CMDER A: USB:        deux colonnes, disquette et clé (la colonne USB à gauche ou à droite)
    CMDER USB:JEUX /R    répertoires seuls dans la colonne USB (/R à la fin)

`CMDER A: A:` est refusé (`Deux lecteurs differents`), `CMDER USB: USB:` aussi (`Une seule
colonne USB`). Pour charger un autre lecteur dans une colonne : `^L`, ou quitter et relancer.
ESC quitte : toute opération est faite tout de suite. **En sortant, le dernier répertoire
USB affiché devient le répertoire courant de CP/A** (fichier `0:CPA.CWD`, `docs/usb.md`
§ 2.1), celui d'où partent USBDIR, IMPORT, EXPORT et le prochain `CMDER USB:` : changer de
répertoire sur la clé, c'est entrer dans CMDER, aller où l'on veut et quitter. Le script
`USBCD.BAT` (`USBDIR /C $1`, sur les disquettes) en fait un raccourci : `USBCD` seul ouvre
CMDER sur la clé, répertoires seuls ; ESC une fois arrivé (`USBCD JEUX` change de répertoire
sans ouvrir CMDER). Lancé en mode SPLIT, CMDER repasse en
texte (l'image est perdue).

## 2. Écran

**Plein écran** (une colonne, ou zoom `^Z`) :

```
 0 |Fichier Marque Trier Vue          a  |
 1 |A: *.*     22/40 fic 126K libre      |
 2 |  NOM+     TYP  TAILLE RS   N GENRE  |
 3 |  ANIM     INC   8 832 R    1 Source |
 4 |* ASM      COM   6 144 R    3 Prog   |
   ...
25 |3 marques : 8 064 o                  |
26 |                                     |
27 |FUNCT menus  ESP marque  ESC fin     |
```

- Ligne 0 : barre de menus du système (FUNCT) et voyants. Lignes 1-2 : en-tête. Lignes 3-24 :
  22 fichiers par page (128 entrées au plus). Ligne 25 : fichier sous le curseur
  (`ASM.COM : 48 enr., 3 bloc(s)`) ou total des marques. Ligne 26 : messages et questions.
  Ligne 27 : aide.
- Colonnes : marque `*`, nom, type, taille, `R` (protégé), `S` (système), `N` (rang dans le
  répertoire, l'ordre de DIR), genre (`COM` Prog, `BAT` Script, `GRX` Grapher, `LOG` Logo,
  `ASM`/`INC` Source, `TXT` Texte, `CFG` Config, `HIR`/`IMG`/`HIZ` Image, `ANI` Anim, `SYM`
  Symboles, `$$$` Tempo).
- Tri signalé par `+` (croissant) ou `-` collé au titre de la colonne (`NOM+`, `TAILLE-`).
- En-tête : lecteur, filtre, `22/40` quand un filtre en cache, place libre en Ko.
- Ascenseur en colonne 39 (rail `:`, curseur en vidéo inverse) quand la liste dépasse
  l'écran.
- Couleurs : titres (ligne 2) papier cyan, encre noire ; lignes 25-26 papier bleu, encre
  blanche ; le reste garde les couleurs de l'utilisateur (`PAPER`, `INK`). Constantes au
  début de la source.

**Deux colonnes** : deux colonnes de 18 caractères (marque, nom, type, taille en Ko) ;
la colonne 20 sert d'ascenseur à la colonne de gauche, la 39 à celle de droite. En-tête :
`A:*.*#        112K` (`#` : « Absents de l'autre » actif), en vidéo inverse pour la colonne
active, qui seule montre son curseur. Lignes 25-26 : colonne active. Chaque colonne garde son
lecteur, son filtre, son tri, ses marques, son curseur.

**Colonne USB** : en-tête `USB:JEUX/` (dernier répertoire du chemin seulement, `USB:2:/` à la
racine ; `USB:?` si le LOCI est absent ou la clé illisible, `+` après le nombre de fichiers si
la liste est coupée à 128). `..` et les sous-répertoires (`<REP>`) en tête, quel que soit le
tri. Noms longs coupés avec `~` (12 caractères en deux colonnes, 26 en plein écran).

**Supports** : `..` à la racine d'un support mène à la liste des supports (en-tête
`USB:supports`) : `0:`, la mémoire interne du LOCI, et les clés USB, avec leur fabricant,
leur modèle et leur taille ; `*` marque celui d'où l'on vient, et le curseur s'y place.
RETURN entre à la racine d'un support. Le numéro d'une clé est son adresse USB, qui change
selon la prise (`docs/usb.md` § 2.1) :

```
 1 |USB:supports         3 fic           |
 2 |  NOM+                        TAILLE |
 3 |  0: memoire du LOCI   15 Mo         |
 4 |  2: SanDisk Cruzer  14.9 Go *       |
 5 |  4: Kingston DataTra 7.5 Go         |
```

Dans la liste des supports, rien ne se copie (`Choisir d'abord un support` comme
destination).

## 3. Tailles

Le répertoire CP/M ne compte que des enregistrements de 128 octets : CMDER affiche tout de
suite `enregistrements × 128` (exact pour les binaires). **Tailles exactes** (`^E`) applique
la règle de STAT (les `^Z` du dernier enregistrement retirés) : une lecture par fichier,
quelques secondes sur un vrai Microdisc (ESC l'arrête) ; gardées jusqu'à la relecture. Les
fichiers de plus de 16 Ko (plusieurs entrées) sont regroupés en une ligne. Sur la clé : taille
exacte, et les blocs qu'il occuperait sur une disquette.

## 4. Touches

| Touche | Effet |
|---|---|
| ↑ ↓ | fichier précédent / suivant |
| ← →, SHIFT-↑ SHIFT-↓ | page précédente / suivante |
| `<` `>`, CTRL-↑ CTRL-↓ | premier / dernier fichier |
| A-Z | fichier suivant dont le nom commence par cette lettre |
| ESPACE | marque / ôte la marque, puis descend |
| `+` `-` | marque / ôte selon un motif (RETURN seul = `*.*`) |
| `*` | inverse les marques |
| 1 2 3 4 | tri par ordre disque, nom, type, taille ; la même touche inverse l'ordre |
| `/` | filtre (RETURN seul = sans filtre) |
| RETURN | Voir ; sur `<REP>` : entrer ; sur `..` : remonter |
| DEL | Effacer |
| `^C` | Copier... |
| `^X` | Déplacer... |
| `^N` | Renommer... |
| `^U` | Dupliquer... (clé) |
| `^O` | Monter... (clé) |
| `^A` | Attributs... |
| `?` | Infos (taille exacte, blocs) |
| `^E` | Tailles exactes |
| `^L` | Lecteur... (colonne active) |
| `^R` | Relire le répertoire (après un changement de disquette) |
| `^I` (CTRL-I) | autre colonne |
| `^Z` | zoom : colonne active en plein écran, et retour (`^I` y montre l'autre) |
| `^W` | échange les deux colonnes de place |
| FUNCT | menus |
| ESC, `^Q` | quitter ; dans une question, ESC annule |

Touches communes avec EDIT et HEX (`docs/manuel.md`, « Les mêmes touches partout ») ;
`^M` (RETURN), `^T` et `^P` (système) ne servent pas. `^C` ne quitte pas. **Les opérations portent sur les fichiers marqués, ou sur le fichier sous le
curseur s'il n'y en a pas.** Un modèle sans point vaut pour tous les types (`LO*` = `LO*.*`).
À clé égale, le tri se fait par nom, de A à Z.

## 5. Menus

Les articles tapent des codes (`$81-$9F`) : un article et son raccourci passent par le même
aiguillage ; le raccourci est écrit à droite du libellé.

- **Fichier** : Voir RET, Copier... ^C, Copier texte..., Deplacer... ^X, Renommer... ^N,
  Effacer DEL, Dupliquer... ^U, Monter... ^O, Attributs... ^A, Infos ?, Imprimer liste, Lecteur... ^L, Relire ^R,
  Quitter ^Q (ou ESC).
- **Marque** : Marquer ESP, Marquer... +, Oter... -, Inverser *, Tout, Rien.
- **Trier** : Ordre disque 1, Nom 2, Type 3, Taille 4.
- **Vue** : Filtrer... /, Sans filtre, Repertoires seuls, Cacher SYS (devient Montrer SYS),
  Taille exacte ^E, Absents autre, Zoom ^Z, Echanger ^W, Autre col. ^I.

**Répertoires seuls** (colonne de la clé, bascule ; `Cle USB seulement` ailleurs ; `/R` à
l'appel) : seuls `..` et les `<REP>` restent, pour parcourir l'arborescence sans les fichiers ;
l'en-tête compte les visibles (`3/5 fic`).

## 6. Opérations

Questions et saisies en ligne 26, par une saisie propre à CMDER (texte proposé modifiable,
ESC annule) : la fonction 10 du BDOS ne convient pas (ESC y complète les noms).

- **Voir** : texte en pages de 26 lignes, coupé à 38 colonnes, arrêt au `^Z` ; non
  imprimables en `.` ; une fin de ligne LF seule est comprise. Les couleurs de l'utilisateur
  reviennent pendant l'affichage. Pour le binaire : HEX.
- **Effacer** : `Effacer 3 fichiers (O/N) ?` ; un fichier R/O est sauté ; bilan.
- **Renommer** : un seul fichier ; le nom actuel est proposé ; `Nom deja pris`, `Fichier
  protege`.
- **Attributs** : `R`, `S`, `RS` ou rien, proposé d'après le fichier sous le curseur,
  appliqué à tous les fichiers visés (fonction 30).
- **Copier** : la question propose le lecteur de l'autre colonne (`Copier 3 fichiers vers :
  B:`) ; tout lecteur ou un nom (`B:NOM.EXT`, un seul fichier) est possible. Progression
  `Copie : NOM.EXT (3/12)`. Fichier présent : `Remplacer NOM.EXT (O/N/T) ?` ; R/O à l'arrivée :
  sauté. Les attributs R/O et SYS sont recopiés (contrairement à COPY). Disque plein : le
  fichier commencé est effacé, la copie s'arrête. ESC entre deux fichiers ou deux tranches.
  Un fichier copié perd sa marque : après un arrêt, les marques restantes montrent ce qui
  reste. **Place** : vers une disquette, les blocs nécessaires (moins ceux des fichiers
  remplacés) sont comparés à la place libre : `Libre 14K, requis 18K : O/N ?`.
- **Déplacer** : même lecteur et autre nom = renommer ; autre lecteur = copier puis effacer
  l'original si la copie a réussi ; refusé d'emblée si un original est protégé.
- **Un seul lecteur** (destination = lecteur de la liste) : lecture dans le tampon (jusqu'à
  32 tranches), puis `DESTINATION en A:, une touche`, écriture, `SOURCE en A:, une touche`...
  Une disquette identique à la source demande `Comme la source : continuer (O/N) ?`. À la
  fin, `SOURCE en A:, une touche (ESC : rester)` : ESC garde la destination (pas pour
  Déplacer).
- **Absents de l'autre** (bascule par colonne) : ne montre que les fichiers absents de
  l'autre colonne, ou présents avec une autre taille ou d'autres attributs (sans lire le
  contenu ; avec la clé : nom 8.3 et taille). `Tout` puis `^C` : synchronisation.
- **Imprimer la liste** : colonne active, au format du plein écran, par la fonction 5.
- **Erreurs disque** : `Erreur disque : verifiez la disquette` en ligne 26, sans le message
  du BDOS ; pendant une copie à un seul lecteur, la même disquette est redemandée
  (`Erreur, DESTINATION en A:...`).

Après toute opération : répertoire(s) relu(s), curseur gardé sur le même fichier.

**Clé USB** : une passerelle, le vrai support reste la disquette. Copier dans les deux sens
(comme EXPORT et IMPORT : `^Z` retirés à l'envoi, ajoutés à l'arrivée, noms ramenés en 8 + 3
avec `_` pour un caractère interdit, `.DSK` refusé à l'envoi, fichier de la clé remplacé sans
question). Vers la clé, la réponse `USB:rep` est relative au répertoire de la colonne USB (ou,
sans elle, au répertoire courant de CP/A) ; `USB:` seul : ce répertoire-là. `/T` à la fin de la réponse de Copier (ou `Copier texte...`) change un LF seul en
CR LF et une tabulation (TAB) en un espace. Déplacer d'une disquette vers la clé, pas
l'inverse. Pas d'attributs sur la clé (`Cle USB : pas d'attributs`), pas de copie de
répertoire entier. Sur la clé, des fichiers seulement (`Fichiers seulement` pour un
répertoire) :

- **Renommer** (`^N`) : le nom long actuel est proposé (63 caractères au plus ; la ligne
  défile) ; `Nom deja pris` ; une image montée est refusée (`Image montee en B:`).
- **Effacer** (DEL) : `Effacer 3 fichiers de la cle (O/N) ?` (le nom long pour un seul) ;
  les images montées sont sautées (bilan `2 efface(s), 1 refuse(s)` ; pour une seule :
  `Image montee en B:`) ; les répertoires restent.
- **Dupliquer** (`^U`, clé seulement) : copie dans le même répertoire ; nom proposé d'après
  l'original, modifiable : le nombre à la fin du nom augmenté, sinon `1` ajouté
  (`PROJETS.DSK` → `PROJETS1.DSK`, `JEU2.TAP` → `JEU3.TAP`, `JEU9` → `JEU10`) ;
  `Nom deja pris` ; progression `Copie : 132/525 Ko`, ESC arrête (`Interrompu`). La copie
  s'écrit sous `~CPADUP.TMP`, renommé à la fin ; un arrêt ou une erreur l'efface.
- **Monter** (`^O`, clé seulement) : une image de disquette (`Monter en : B:`, A: refusé)
  ou une cassette (`.TAP`, aussitôt), avec les règles de USBMOUNT (`docs/usb.md` § 1.4) ;
  `Pas une image (.DSK ou .TAP)`, `Image montee en C:` ; message `C: puzzle.dsk`.

**Nom de la disquette** de chaque lecteur, d'après le menu du LOCI (sur un LOCI seulement) :
plein écran, dans l'en-tête (`A: cpa.dsk *.*    22/40 fic 126K libre`), coupé avec `~`
(12 caractères au plus, moins si le filtre et le nombre de fichiers prennent la place) ; en
deux colonnes, à la place du filtre quand il n'y en a pas (`B:projets-2~  112K`, 10
caractères au plus).

## 7. Mise en œuvre

- `progs/cmder.s`, avec `progs/loci_inc.s` (clé USB : API du LOCI, répertoire courant,
  chemins, supports) ; page zéro hors de `$30-$3B` (zone de `loci_inc.s`).
- **Répertoire courant** : `cw_get` (au premier `USB:`) le lit, retrouve une clé renumérotée
  d'après sa description, et rend la base des chemins relatifs (`lpath`) ; `k_quit` l'écrit
  par `cw_put` si une colonne montre la clé (pas la liste des supports), seulement s'il a
  changé. `upath` vide = la liste des supports (`u_sups` : une entrée « répertoire » par
  support, son numéro dans `E_SIZE`, sa ligne de `dv_fmt` en nom long) ; `usup` : le support
  marqué `*`.
- **Répertoires seuls** : bit 1 de `hides` (le bit 0 cache les SYS), par colonne.
- **Opérations sur la clé** : `u_ren`, `u_del`, `k_dup`, `k_mnt` ; montage par
  `progs/lmnt_inc.s` (le même code que USBMOUNT ; ses tampons après `lnames`). Effacer
  traite les fichiers du rang le plus haut au plus bas : un effacement ne change pas le rang
  des suivants (`u_name` relit le répertoire). Saisie longue (`askl`) : 63 caractères, la
  fin seulement si la ligne déborde. En-têtes : `hdnm` lit le nom en XRAM (`haslmn` : LOCI
  et configuration du menu vus au démarrage).
- **Textes** : barre de menus, messages, en-têtes de colonnes, noms des genres et colonne du
  signe de tri (`spos`, `spos2`) dans `progs/msg/fr/cmder.msg` et `progs/msg/en/cmder.msg`
  (`cpa-en.dsk` : `File Mark Sort View`, colonnes `NAME TYP SIZE RS N KIND`, réponses `Y`,
  `N`, `A`). Les lettres des attributs (`R`, `S`), `USB:` et l'option `/T` sont les mêmes
  dans les deux langues.
- **Table des fichiers** : 128 × 24 octets, remplie par les fonctions 17/18 avec des `?`
  partout (toutes les entrées, extents compris, dans l'ordre du répertoire) ; entrées d'un
  même fichier regroupées par le nom (enregistrements = le plus grand `EX × 128 + RC`, blocs
  = somme). Deux colonnes : l'état de la colonne active (page zéro `$25-$2F`, filtre, liste
  visible, table) est à sa place habituelle, celui de l'autre dans une seconde zone de même
  forme ; `pswap` échange les deux. `ent_ptr` et `vis_ptr` lisent une table par pointeur.
  Seule la colonne active est redessinée quand le curseur bouge.
- **Clé** : nom 8 + 3 dans la table, nom long (26 caractères) dans une zone à part ; le nom
  complet est relu sur la clé pour ouvrir le fichier. Copie fichier par fichier. `path_up`
  : `FILES` remonte à `/`, `1:REP` à `1:`, `A/B` à `A` ; `is_root` reconnaît vide, `/`,
  `1:`, `1:/`.
- **Copie** : une seule mécanique, en tranches (lecture de la suite des fichiers dans le
  tampon, le reste de la TPA, puis écriture). Un seul lecteur : fonction 13 avant chaque
  échange ; un fichier commencé est fermé (fonction 16, point d'étape) puis repris avec le
  même FCB. **Empreinte** du répertoire (sommes de contrôle et nombre d'entrées) de chaque
  disquette, refaite après chaque écriture : la mauvaise disquette est refusée.
- **Erreurs** : CMDER pose `IO_QUIET` (`$FDAC`) pendant ses accès ; le BDOS n'affiche rien et
  pose le bit 7 ; CMDER le lit après chaque opération. `IO_QUIET` est remis à 0 avant chaque
  sortie.
- Affichage direct dans `$BB80`, touches par CONIN du BIOS (comme EDIT).
- Mémoire : CMDER.COM, deux tables (2 × 3 Ko), tampon de copie ~25 Ko.

## 8. Plus tard

- Un programme de comparaison de fichiers, à part.
- Ouvrir un fichier dans EDIT ou HEX puis revenir à CMDER (CHAIN et un script, comme
  `EDITE` de LOGO).
