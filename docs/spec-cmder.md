# CMDER : gestionnaire de fichiers en plein écran — spécification

État : maquette validée par Pierre (12 octobre 2026), **version 1 faite** le même jour
(`progs/cmder.s`, CMDER.COM 7 628 octets, lot LJ) ; écarts de la réalisation au § 11. Nom
choisi par Pierre (écho à GRAPHER). Un `.COM`, **rien de résident**, contrat d'interface inchangé.

## 0. Périmètre

- **Version 1 (ce document)** : une seule disquette, en plein écran : `CMDER [d:][afn]`.
- **Plus tard** (maquettes au § 9, rien de décidé au-delà) : `CMDER A: B:` démarre
  directement en deux colonnes ; `CMDER USB:[chemin]` et `CMDER A: USB:` affichent la clé du
  LOCI (répertoire courant seulement, pas le chemin complet), avec passage en plein écran ;
  « Comparer » vient avec les deux colonnes.
- Principe déjà posé : une commande disque doit marcher **avec un seul lecteur**. La copie
  vers le même lecteur (échange de disquettes) est donc dans la version 1.

## 1. Appel

    CMDER            lecteur courant, tous les fichiers
    CMDER B:         lecteur B:
    CMDER B:*.COM    lecteur B:, filtre *.COM déjà posé

ESC quitte (rien n'est perdu : toute opération est faite tout de suite).

## 2. Écran (plein écran, une disquette)

Ligne 0 : barre de menus du système (`MENUBAR`, FUNCT), voyants à droite comme partout.
Lignes 1-2 : en-tête. Lignes 3-24 : 22 fichiers par page (128 entrées au plus : 6 pages).
Ligne 25 : informations. Ligne 26 : messages et questions. Ligne 27 : aide.
Maquette sur les 37 colonnes utiles (le curseur est une ligne en vidéo inverse, invisible ici) :

```
 0 |Fichier Marque Trier Vue          a  |
 1 |A: *.*              40 fic 126K libre|
 2 |  NOM+     TYP  TAILLE RS   N GENRE  |
 3 |  ANIM     INC   8 832 R    1 Source |
 4 |  ARDOISE  GRX     384      2 Grapher|
 5 |* ASM      COM   6 144 R    3 Prog   |
 6 |* COPY     COM   1 152 R    4 Prog   |
 7 |  CPA      INC   5 120 R    5 Source |
 8 |  DEBUG    COM   6 528 R    6 Prog   |
 9 |  DEMO     LOG     512      7 Logo   |
10 |  DESSIN   GRX     256      8 Grapher|
11 |  DISKCOPY COM   1 664 R    9 Prog   |
12 |  ECRAN    GRX     512     10 Grapher|
13 |  EDIT     CFG     512     11 Config |
14 |  EDIT     COM   8 192 R   12 Prog   |
15 |* ERA      COM     768 RS  13 Prog   |
16 |  EXPORT   COM   1 792 R   14 Prog   |
17 |  FLECHES  GRX     768     15 Grapher|
18 |  FORMAT   COM   1 792 R   16 Prog   |
19 |  GO       COM     256 R   17 Prog   |
20 |  GRAPHER  COM  12 416 R   18 Prog   |
21 |  GRX      INC  20 096 R   19 Source |
22 |  GTEST    ASM   1 664     20 Source |
23 |  GTEST    COM     256     21 Prog   |
24 |  HELLO    ASM     896     22 Source |
25 |3 marques : 8 064 o                  |
26 |                                     |
27 |FUNCT menus  ESP marque  ESC fin     |
```

Colonnes d'une ligne : marque `*`, nom, type, taille en octets, `R` (protégé R/O), `S`
(système, caché de DIR), `N` = rang dans le répertoire (l'« ordre sur le disque », celui de
DIR), genre. Le tri en cours est signalé dans l'en-tête par `+` (croissant) ou `-`
(décroissant) collé au titre de la colonne (`NOM+`, `TAILLE-`...).

- **Ligne 1** : lecteur, filtre, nombre de fichiers (`22/40` quand un filtre en cache),
  place libre (calculée comme STAT, d'après le répertoire).
- **Ligne 25** : sans marque, le fichier sous le curseur (`DEMO.LOG : 4 enr., 1 bloc`, ou
  `DEMO.LOG : 447 o` une fois la taille exacte lue) ; avec des marques, leur nombre et leur
  total.
- **Genre** : déduit du type par une petite table (`COM` Prog, `BAT` Script, `GRX` Grapher,
  `LOG` Logo, `ASM`/`INC` Source, `TXT` Texte, `CFG` Config, `HIR`/`IMG`/`HIZ` Image, `ANI`
  Anim, `SYM` Symboles, `$$$` Tempo, sinon vide). C'est le premier élément à retirer si la
  place manque (~150 octets).

## 3. Tailles

Le répertoire CP/M 2.2 ne donne que des enregistrements de 128 octets. CMDER affiche donc
**tout de suite** `enregistrements × 128` (exact pour les `.COM` et les fichiers binaires), sans
aucune lecture. **Tailles exactes** (`^E`) applique la règle de STAT (les `^Z` du dernier
enregistrement sont retirés) : une lecture de secteur par fichier, rapide sur le LOCI, quelques
secondes sur un vrai Microdisc (ESC l'arrête). Résultat gardé jusqu'à la relecture du
répertoire. Les fichiers de plus de 16 Ko (plusieurs entrées) sont regroupés en une ligne.

## 4. Touches (vue principale)

| Touche | Effet |
|---|---|
| ↑ ↓ | fichier précédent / suivant |
| ← → | page précédente / suivante |
| `<` `>` | premier / dernier fichier |
| A-Z | saut au fichier suivant dont le nom commence par cette lettre |
| ESPACE | marque / ôte la marque, puis descend |
| `+` `-` | marque / ôte selon un motif (jokers ; RETURN seul = `*.*`, donc tout / rien) |
| `*` | inverse les marques |
| 1 2 3 4 | trie par ordre disque, nom, type, taille ; la même touche une 2e fois inverse l'ordre |
| `/` | filtre (motif à jokers ; RETURN seul = sans filtre) |
| RETURN | Voir (texte du fichier) |
| DEL | Effacer |
| `^C` | Copier... |
| `^D` | Déplacer... |
| `^N` | Renommer... |
| `^A` | Attributs... |
| `?` | Infos (taille exacte, blocs, entrées du répertoire) |
| `^E` | Tailles exactes (tous les fichiers) |
| `^L` | Lecteur... (A: à D:) |
| `^R` | Relire le répertoire (après un changement de disquette) |
| FUNCT | menus |
| ESC | quitter (dans une question : annuler) |

Touches évitées : `^H ^I ^J ^K` (ce sont les flèches), `^M` (RETURN), `^T` (majuscules) et `^P`
(copie vers l'imprimante) qui appartiennent au système. `^C` ne quitte pas : dans le système, il
n'agit qu'à la pause de fin d'écran, que CMDER n'utilise pas.

**Les opérations portent sur les fichiers marqués, ou sur le fichier sous le curseur s'il n'y a
aucune marque.**

## 5. Menus

Les articles « tapent » un code (`MA_TYPE`, comme EDIT) : un article et son raccourci passent par
le même aiguillage. Le raccourci est écrit à droite du libellé.

**Fichier** (10 articles, largeur 16)

```
 0 |Fichier Marque Trier Vue          a  |
 1 | Voir         RET iers  126 Ko libres|
 2 | Copier...     ^C ILLE RS   N GENRE  |
 3 | Deplacer...   ^D  832 R    1 Source |
 4 | Renommer...   ^N  384      2 Grapher|
 5 | Effacer      DEL  144 R    3 Prog   |
 6 | Attributs...  ^A  152 R    4 Prog   |
 7 | Infos          ?  120 R    5 Source |
 8 | Lecteur...    ^L  528 R    6 Prog   |
 9 | Relire        ^R  512      7 Logo   |
10 | Quitter      ESC  256      8 Grapher|
```

**Marque** (5 articles)

| Article | Raccourci |
|---|---|
| Marquer / oter | ESP |
| Marquer... (motif) | `+` |
| Oter... (motif) | `-` |
| Inverser | `*` |
| Tout / Rien | `+` RET / `-` RET |

**Trier** (4 articles) : `Ordre disque 1`, `Nom 2`, `Type 3`, `Taille 4`. À type égal, tri
par nom ; à taille égale, par nom.

**Vue** (4 articles) : `Filtrer... /`, `Sans filtre`, `Cacher SYS` (bascule ; par défaut
CMDER montre tout, `S` dans la colonne), `Tailles exactes ^E`.

## 6. Opérations

Questions et saisies en ligne 26, par une saisie propre à CMDER (comme `ask` dans EDIT) : texte
proposé modifiable, ESC annule. La fonction 10 du BDOS ne convient pas ici : ESC y complète
les noms et la liste des noms ferait défiler l'écran.

- **Voir** (RETURN) : texte en pages de 26 lignes, coupé à 38 colonnes, s'arrête au `^Z` ;
  caractères non imprimables en `.` ; ESPACE ou ↓ : page suivante, ESC : retour. Pour le
  binaire : HEX.
- **Effacer** (DEL) : `Effacer 3 fichiers (O/N) ?` ; un fichier R/O est sauté, bilan
  `2 effaces, 1 protege`.
- **Renommer** (`^N`) : un seul fichier (`Un seul fichier a la fois` sinon) ; le nom actuel est
  proposé ; `Nom deja pris`, `Fichier protege`.
- **Attributs** (`^A`) : `Attributs (R, S, RS ou rien) : R_`, proposé d'après le fichier sous
  le curseur, appliqué à tous les fichiers visés (fonction 30).
- **Copier** (`^C`) : `Copier 3 fichiers vers : B:_`
  - `B:` : vers un autre lecteur, mêmes noms ;
  - `NOM.EXT` ou `B:NOM.EXT` : un seul fichier, sous un autre nom ;
  - le lecteur courant (`A:` quand on est sur A:) : **un seul lecteur**, voir plus bas.
  - Fichier déjà présent : `LOGO.COM existe : remplacer (O/N/T) ?` (T = tous) ; ESC arrête.
    Fichier R/O à l'arrivée : sauté, avec le message `Fichier protege`.
  - Les attributs R/O et SYS sont recopiés (la copie ressemble à l'original : utile pour
    préparer une disquette d'usage).
  - Disque plein : le fichier commencé est effacé, la copie s'arrête (règle d'IMPORT).
  - ESC entre deux fichiers et entre deux tranches. Chaque fichier copié perd sa marque : en
    cas d'arrêt, les marques restantes montrent ce qui n'est pas fait.
- **Déplacer** (`^D`) : même lecteur et autre nom = renommer ; autre lecteur = copier puis
  effacer l'original, seulement si la copie a réussi ; original R/O : refusé.
- **Un seul lecteur** : le fichier est lu dans un tampon (le reste de la TPA, ~28 Ko), puis :
  `DESTINATION en A:, une touche`, écriture, `SOURCE en A:, une touche`,
  et ainsi de suite ; un fichier plus grand que le tampon demande plusieurs échanges (il est
  fermé puis repris à son enregistrement suivant). Le BDOS est prévenu à chaque échange
  (fonction 13, comme DISKCOPY). **Protection contre une erreur d'échange** : CMDER note une
  empreinte du répertoire (somme de contrôle des secteurs lus) de chaque disquette ; avant
  d'écrire, il la vérifie et refuse la mauvaise (`Pas la bonne disquette`). À la fin :
  `Remettez la disquette SOURCE`, et la liste est relue.

Après toute opération : répertoire relu, curseur gardé sur le même fichier (ou le suivant).

## 7. Mémoire

| Zone | Taille |
|---|---|
| CMDER.COM en `$0500` | 6 à 9 Ko (§ 8) |
| Table des fichiers : 128 × ~24 octets (nom, attributs, enregistrements, rang, entrées, taille exacte, marque, genre) + ordre d'affichage | ~3,2 Ko |
| Tampon de copie | le reste de la TPA, ~28 Ko en mode texte |
| Système | rien de plus (menus, BDOS : déjà résidents) |

Lecture du répertoire : par les fonctions 17/18 du BDOS avec des `?` (extents compris), sinon
lecture directe des 16 secteurs comme DISKCOPY (à trancher en codant, § 10).

## 8. Coût estimé

Estimations à doubler par prudence (règle du projet) : la colonne « prévoir » est celle qui
compte.

| Partie | Estimation | Prévoir |
|---|---:|---:|
| Démarrage, paramètres, barre de menus (4 menus, 23 articles) | 600 | 900 |
| Lecture du répertoire, regroupement des extents, table | 400 | 700 |
| Tris (4 clés, ordre inverse) et filtre à jokers | 400 | 600 |
| Affichage : en-tête, liste, ligne 25, nombres sur 24 bits, genre | 700 | 1 100 |
| Clavier, curseur, pages, saut par lettre | 250 | 400 |
| Marquage (ESP, `+` `-` `*`, totaux) | 250 | 400 |
| Saisie d'une ligne et question O/N/T | 200 | 300 |
| Effacer, Renommer, Attributs | 450 | 700 |
| Copier, Déplacer (autre lecteur, autre nom) | 700 | 1 100 |
| Copie avec un seul lecteur (échanges, empreinte, reprise) | 500 | 1 000 |
| Voir | 250 | 400 |
| Tailles exactes, Infos | 200 | 300 |
| Messages (~35) | 700 | 900 |
| **Total CMDER.COM** | **~5,9 Ko** | **~8,8 Ko** |

Rien de résident. À côté : une rubrique CMDER dans HELP (~0,6 Ko dans HELP.COM), README.md,
README.TXT. Sur les disquettes : `cpa.dsk` visible ; sur les disquettes d'usage, R/O et SYS
comme les autres commandes de base (~9 Ko, 5 blocs).

## 9. Plus tard : deux colonnes et clé USB (maquettes, rien de décidé)

Deux colonnes de 18 caractères séparées par `|` ; la taille passe en Ko ; `^X` passe d'une
colonne à l'autre (l'Oric n'a pas de TAB : CTRL-I est la flèche droite) ; les flèches gauche et
droite gardent leur sens (pages) ; « Comparer » apparaît (présent d'un seul côté, taille
différente).

```
 0 |Fichier Marque Trier Vue          a  |
 1 |A:*.*  126K libre |B:*.*  280K libre |
 2 | ANIM     INC   9K| DEMO     LOG   1K|
 3 | ARDOISE  GRX   1K|*NOTES    TXT   4K|
 4 |*ASM      COM   6K| LETTRE   TXT   2K|
 5 | COPY     COM   2K| SCORES   DAT   1K|
```

Colonne USB : le répertoire courant seulement (`USB:JEUX/`), `..` et les sous-répertoires en
tête (`<REP>`, RETURN pour y entrer), noms longs coupés avec `~` ; passage en plein écran pour
lire les noms longs. Échanges par la bibliothèque `loci_inc.s` (celle d'IMPORT, EXPORT,
USBDIR), noms ramenés en 8.3 à l'arrivée comme IMPORT.

```
 1 |USB:JEUX/   4 fic |B:*.*  280K libre |
 2 | ..          <REP>| DEMO     LOG   1K|
 3 | DEMOS       <REP>|*NOTES    TXT   4K|
 4 | PONG     TAP  10K| LETTRE   TXT   2K|
 5 | SUPERCO~ DSK 330K| SCORES   DAT   1K|
```

Pour que ce soit simple à ajouter, la version 1 range déjà ce qui dépend de la source
(lire la liste, lire et écrire un fichier, effacer, renommer) derrière quelques routines : une
colonne USB n'aura qu'à fournir les siennes.

## 10. Tranché en codant

- Les fonctions 17/18 avec `?` partout (extent compris) rendent toutes les entrées, dans
  l'ordre du répertoire : la table se remplit par elles, sans lecture directe. Les entrées
  d'un même fichier sont regroupées par le nom ; enregistrements = le plus grand `EX x 128 +
  RC` (comme la fonction 35), blocs = somme des blocs des entrées.
- Reprise d'un fichier après un échange : inutile de le rouvrir. Le FCB de la destination
  est fermé (fonction 16, point d'étape : l'entrée du répertoire reçoit les blocs déjà
  écrits) avant chaque échange, puis on continue d'écrire avec le même FCB ; la carte
  d'allocation refaite par la fonction 13 contient donc ces blocs. Le FCB de la source sert
  tel quel (rien n'est écrit sur la source).
- Affichage direct dans `$BB80` et touches par l'entrée CONIN du BIOS (comme EDIT) : FUNCT
  ouvre la barre de CMDER.

## 11. Réalisation (version 1) : écarts et précisions

- **En-tête** : `A: *.*     22/40 fic 126K libre` (place comptée en Ko, comme STAT).
- **Tri par défaut** : par nom. L'ordre inverse ne vaut que pour la clé principale : à égalité
  (même taille, même type), les noms restent de A à Z.
- **Ligne 25** : `NOM.EXT : 69 enr., 5 bloc(s)` ; `?` (Infos) donne en message la taille
  exacte et les blocs.
- **Menus** : Marque : `Marquer ESP`, `Marquer... +`, `Oter... -`, `Inverser *`, `Tout`,
  `Rien` ; Vue : `Filtrer... /`, `Sans filtre`, `Cacher SYS` (devient `Montrer SYS`),
  `Taille exacte ^E`. Les articles tapent les codes `$81-$98`.
- **Saisies** : texte proposé (`*.*` pour `+` et `-`, le nom actuel pour Renommer, le filtre
  actuel pour `/`) ; un modèle sans point vaut pour tous les types (`LO*` = `LO*.*`).
- **Voir** : 26 lignes par page, `-- ESP : suite, ESC : retour --`, puis `-- Fin du
  fichier : une touche --`.
- **Copie** : progression `Copie : NOM.EXT` ; `Remplacer NOM.EXT (O/N/T) ?` ; bilan
  `3 copie(s), 1 protege(s)` (ou `deplace(s)`) ; un fichier sauté ou non copié garde sa
  marque. Un seul lecteur : `DESTINATION en A:, une touche` (`Non ! ...` si c'est la source
  ou une autre disquette), `Lecture du repertoire...` après chaque touche. ESC à une demande :
  `Interrompu` (`NOM.EXT incomplet` si un gros fichier était commencé). Le tampon (~33 Ko en
  mode texte) reçoit jusqu'à 32 tranches (fichiers ou morceaux) par échange.
- **Déplacer** : refusé d'emblée si un original est protégé (`Original protege (R/O)`).
- **Lancé en mode SPLIT** : CMDER repasse en texte (l'image est perdue) ; ESC rend le prompt
  en texte.
- **Taille** : CMDER.COM 7 628 octets (estimé ~5,9 Ko, prévu ~8,8 Ko), table 3,1 Ko.
- **Essais** (Oricutron, `tools/run_test.sh`) : liste, tris et ordre inverse, filtre (avec
  changement de lecteur), SYS cachés, marquage, Voir, Infos, tailles exactes, menus,
  Renommer, Attributs, Effacer (fichier protégé épargné), Copier et Déplacer vers B: (4
  fichiers, 60 Ko, plus que le tampon : contenus identiques, attributs gardés), remplacement
  O/N/T, destination protégée, disque plein (copie effacée), un seul lecteur avec de vrais
  échanges (`DSKSWAP` et `\x07`, ajoutés à l'Oricutron de test pour cela) : 4 fichiers
  dont un coupé en deux, mauvaise disquette refusée, ESC, Déplacer.
- **Reste à vérifier sur le vrai Oric + LOCI** : rapidité de l'affichage, échanges de
  disquettes par le menu du LOCI (attention : une touche tapée lecteur vide bloque le LOCI,
  comme pour DISKCOPY A: A:), copie vers un second lecteur du LOCI.
