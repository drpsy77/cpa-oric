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

## 9. Plus tard : deux colonnes et clé USB (premières maquettes ; décisions au § 12)

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

(Prévu à l'origine : que la version 1 range ce qui dépend de la source derrière quelques
routines. Ce n'est pas fait : la v1 appelle le BDOS directement ; voir § 12.4.)

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

## 12. Lot 2 (spécification, octobre 2026 ; rien de codé)

Décidé avec Pierre après les essais de la v1 sur le vrai Oric + LOCI (« l'affichage est très
rapide » ; copie de CMDER sur une ancienne version réussie avec une disquette bien
différente). Trois parties, chacune livrée, essayée et commitée à part : **2a**
améliorations, **2b** deux colonnes, **2c** clé USB.

### 12.1 Partie 2a : améliorations de la v1

1. **Disquette identique à la source** (un seul lecteur). L'empreinte ne voit que le
   répertoire : deux disquettes aux mêmes fichiers (mêmes tailles, mêmes blocs) se
   confondent. Au lieu de refuser, CMDER demande `Identique a la source : continuer (O/N) ?`
   (O : c'est bien la destination ; N : nouvelle demande de la destination). Le numéro de
   disquette écrit par FORMAT (option B) est écarté pour l'instant.
2. **Erreurs disque sans message du BDOS** : pendant ses accès, CMDER pose `IO_QUIET`
   (`$FDAC`, `cpa.inc`) ; le BDOS n'écrit plus `BDOS: disk I/O error` à la position du curseur
   de la console (au milieu de l'écran, constaté par Pierre). CMDER affiche en ligne 26
   `Erreur disque : verifiez la disquette` et, pendant une copie à un seul lecteur, redemande
   la même disquette ; ailleurs, l'opération s'arrête sur ce message. `IO_QUIET` est remis à
   0 avant chaque sortie (ESC, et avant tout retour au prompt).
3. **Fin d'une copie à un seul lecteur** : `SOURCE en A:, une touche (ESC : rester)`. ESC
   garde la destination dans le lecteur et la liste la montre (un échange de moins). Pour
   Déplacer, la source reste exigée (les originaux y sont effacés). Le tampon n'est pas
   agrandi (Pierre : en usage réel, il exploite les 4 lecteurs).
4. **Couleurs** (attributs en colonnes 0 et 1) : titres des colonnes (ligne 2) papier cyan,
   encre noire ; lignes d'état 25 et 26 papier bleu, encre blanche (comme EDIT) ; la ligne
   d'aide 27 et la liste gardent les couleurs de l'utilisateur (PAPER / INK restent valables
   dans toutes les applications). Si l'utilisateur a choisi les mêmes couleurs, tant pis
   (Pierre). Voir remet les couleurs de l'utilisateur sur ses lignes pendant l'affichage du
   texte, puis repose celles de CMDER. Couleurs en constantes au début de la source.
5. **Ascenseur en colonne 39** (lignes 3 à 24) : rail `:` et curseur en vidéo inverse, de
   hauteur `22 x 22 / nvis` (1 au moins) et placé à `top x 22 / nvis` ; rien quand tout tient
   dans l'écran (22 fichiers au plus).

Coût prévu (doublé par prudence) : ~100 + 80 + 80 + 100 + 150 = **~510 octets**.

**Fait (2a)** : CMDER.COM 7 628 -> 8 197 octets (+569). Écarts : message
`Comme la source : continuer (O/N) ?` (37 colonnes) ; préfixe `Erreur, ` (au lieu de
`Non ! `) quand la disquette demandée est illisible. **Le BDOS change de 5 octets** (marge
du système 222 -> 215) : avec `IO_QUIET` non nul, une erreur disque n'affiche rien mais pose
le bit 7 de `IO_QUIET` ; CMDER le lit après chaque opération, chaque lecture de la copie et
chaque échange (`Erreur disque : verifiez la disquette`). Sans ce bit, une erreur de lecture
pendant une copie passait pour une fin de fichier (copie tronquée sans message) : elle arrête
maintenant la copie (avec deux lecteurs, la copie commencée est effacée). Une disquette
acceptée comme « identique à la source » ne peut plus être distinguée de la source aux
échanges suivants : c'est à l'utilisateur de mettre la bonne. Essayé dans Oricutron :
couleurs et ascenseur (capture), lecteur B: illisible (secteur du répertoire abîmé : message
en ligne 26, plus de `BDOS: disk I/O error`), destination illisible pendant un échange
(`Erreur, DESTINATION en A:...`), disquette identique (O, puis remplacement), ESC à la fin
(la liste montre la destination).

### 12.2 Partie 2b : deux colonnes

**Appel** : `CMDER A: B:` démarre en deux colonnes (un modèle par lecteur :
`CMDER A:*.COM B:`, lus par FCB1 et FCB2). Pas d'article pour charger un autre lecteur dans
une colonne : on quitte et on relance (historique des lignes, Pierre). `^L` (Lecteur...)
change le lecteur de la colonne active. Pas de notion de source et de cible : les
opérations partent de la colonne active.

**Écran** (38 colonnes 2 à 39 ; `#` = curseur de l'ascenseur, en vidéo inverse) :

```
 0 |Fichier Marque Trier Vue           a  |
 1 |A:*.*  118K libre |B:*.*  280K libre  |
 2 | NOM+     TYP   Ko| NOM+     TYP   Ko |
 3 | ANIM     INC   9K# DEMO     LOG   1K |
 4 | ARDOISE  GRX   1K#*NOTES    TXT   4K |
 5 |*ASM      COM   6K# LETTRE   TXT   2K |
 6 | CMDER    COM   8K: SCORES   DAT   1K |
 7 | COPY     COM   2K:                   |
   ...
25 |ASM.COM : 48 enr., 3 bloc(s)          |
26 |                                      |
27 |FUNCT menus  ESP marque  ESC fin      |
```

- Colonne de 18 caractères : marque, nom, type, taille en Ko. La séparation (colonne 20)
  sert d'ascenseur à la colonne de gauche ; la colonne 39, à celle de droite.
- Colonne active : son en-tête (ligne 1) en vidéo inverse, et elle seule montre son curseur.
  Lignes 25 et 26 : fichier ou marques de la colonne active.
- Chaque colonne garde son lecteur, son filtre, son tri, ses marques, son curseur.

**Touches nouvelles** (toutes les autres comme en v1, pour la colonne active) :

| Touche | Effet |
|---|---|
| `^X` | passe à l'autre colonne (l'Oric n'a pas de TAB : CTRL-I est la flèche droite) |
| `^Z` | zoom : la colonne active en plein écran (affichage de la v1), et retour |
| `^W` | échange les deux colonnes de place |

En zoom, `^X` montre l'autre colonne en plein écran. Les flèches gauche et droite restent
les pages. Menu Vue : `Deux colonnes / Plein ecran ^Z`, `Echanger ^W`, `Autre colonne ^X`,
`Absents de l'autre`. Menu Fichier : `Imprimer la liste`.

**Copier / Déplacer** : la question propose le lecteur de l'autre colonne (`Copier 3
fichiers vers : B:`, RETURN suffit) ; tout autre lecteur ou nom reste possible. Après
l'opération, les deux colonnes sont relues.

**Comparer** deux fichiers : **reporté** (Pierre : un programme de comparaison dédié).

**Absents de l'autre** (menu Vue, bascule par colonne) : la colonne ne montre que les
fichiers dont le nom n'existe pas dans l'autre colonne, **ou** qui existent sous le même nom
avec une autre taille (enregistrements) ou d'autres attributs (R, S) ; la comparaison se fait
sur les tables, sans lecture du contenu. Avec `Tout` puis `^C`, on recopie ce qui manque ou
diffère : une synchronisation sans code de plus. L'en-tête le signale (`A:*.*` suivi de `#`).

**Place avant une copie** : vers une disquette, CMDER compte les blocs de 2 Ko nécessaires
(par fichier, enregistrements arrondis au bloc), retire ceux des fichiers du même nom qui
seront remplacés, et compare à la place libre de la destination. Si elle manque :
`Place : 26K libres, 31K a copier (O/N)` (O : essayer quand même). Pas de vérification avec
un seul lecteur (la destination n'est pas encore lue) ni vers la clé USB.

**Imprimer la liste** (menu Fichier) : en-tête et lignes de la colonne active, au format du
plein écran, sur l'imprimante (fonction 5, CR LF) ; sans imprimante, rien ne bloque.

**Mémoire** : deux tables (2 x 3 Ko) ; tampon de copie ~30 Ko au lieu de ~33. L'état d'une
colonne (lecteur, filtre, tri, compteurs, curseur, table) tient dans un bloc ; changer de
colonne échange les blocs.

`CMDER A: A:` (le même lecteur deux fois) est refusé : `Deux lecteurs differents` ; la copie
à un seul lecteur reste celle du plein écran.

Coût prévu (doublé) : affichage en deux colonnes et deux ascenseurs ~700 ; état par
colonne, `^X ^Z ^W` ~400 ; destination proposée et relecture des deux colonnes ~150 ;
Absents de l'autre ~300 ; place avant copie ~200 ; impression ~200 ; menus et messages
~300. **~2,3 Ko**.

**Fait (2b)** : CMDER.COM 8 197 -> 9 818 octets (+1 621). Réalisation : l'état de la colonne
active (octets `$25-$2F` de la page zéro, filtre, liste visible, table) est à sa place
habituelle ; celui de l'autre colonne dans une seconde zone de même forme (`pswap` échange
les deux : `^X`, et les relectures de l'autre colonne). L'autre colonne n'est redessinée
qu'après `^X ^W ^Z`, Voir et les relectures : déplacer le curseur ne redessine que la colonne
active (affichage aussi rapide qu'en v1). `ent_ptr` et `vis_ptr` lisent la table par un
pointeur, pour dessiner l'autre colonne et pour Absents de l'autre. En-tête d'une colonne :
`A:*.*#        112K` (`#` : absents de l'autre seulement ; la colonne active en vidéo
inverse) ; titres `NOM+  TYP  Ko` (`+NOM` pour l'ordre du disque). Après une copie, les deux
colonnes sont relues. Place avant copie : `Libre 14K, requis 18K : O/N ?`. Essayé dans
Oricutron : affichage et ascenseurs, `^X`, `^W`, `^Z`, Voir puis retour, Absents de l'autre
(nom, taille, attributs), copie avec le lecteur de l'autre colonne proposé, place
insuffisante, `A: A:` et `^L` vers le lecteur de l'autre colonne refusés, impression
(`printer_out.txt`), copie à un seul lecteur inchangée.

### 12.3 Partie 2c : clé USB du LOCI

**Appel** : `CMDER USB:[chemin]` (plein écran) ou `CMDER A: USB:[chemin]` (deux colonnes ;
la colonne USB peut être à gauche ou à droite). `USB:` est lu par CMDER dans la ligne de
commande (le CCP ne le comprend pas comme un lecteur). Sans chemin : la racine de la
première clé (comme USBDIR). LOCI absent : `LOCI absent : cle USB inaccessible`, colonne
vide.

**Affichage** : l'en-tête montre le répertoire courant seulement (`USB:JEUX/`), pas le
chemin complet. En tête de liste `..` (sauf à la racine) et les sous-répertoires (`<REP>`),
puis les fichiers. Noms longs : coupés avec `~` en deux colonnes (12 caractères), en entier
jusqu'à 26 caractères en plein écran (`^Z`), plus la taille. RETURN sur `<REP>` y entre,
sur `..` remonte ; RETURN sur un fichier : Voir.

**Opérations** : la clé est une **passerelle** (Pierre) : le vrai support reste la
disquette. Copier dans les deux sens (logique d'EXPORT et d'IMPORT : `^Z` retirés à l'envoi,
ajoutés à l'arrivée ; noms coupés à 8 + 3 à l'arrivée sur disquette ; `.DSK` refusé à
l'envoi). Déplacer d'une disquette vers la clé (l'original sur disquette est effacé) ; pas
de Déplacer depuis la clé. **Rien n'est effacé ni renommé sur la clé** (Effacer, Renommer,
Attributs refusés dans une colonne USB : `Cle USB : lecture et copie seulement`). Pas de
copie de répertoire entier. Voir sur la clé. Tri par nom, type, taille et ordre de la clé ;
filtre et marquage comme ailleurs. Bibliothèque commune : `progs/loci_inc.s`.

**Textes** (de la clé vers une disquette) : comme `IMPORT /T`, l'option `/T` à la fin de la
réponse de Copier change un LF seul en CR LF (`Copier 2 fichiers vers : A: /T`) ; sans elle,
copie binaire. Le menu Fichier a aussi `Copier texte...`, qui pose la même question avec
` /T` déjà écrit.

Coût prévu (doublé) : liste et navigation ~900 ; noms longs, plein écran ~300 ; copies
dans les deux sens et `/T` ~900 ; Voir ~150 ; messages ~300 ; plus `loci_inc.s` (~700 déjà
écrits). **~3,3 Ko**.

**Fait (2c)** : CMDER.COM 9 818 -> 13 463 octets (+3 645, dont ~720 pour `loci_inc.s`, incluse
telle quelle : la page zéro de CMDER a été déplacée hors de `$30-$3B`). Réalisation :
- une seule colonne USB à la fois (`CMDER USB: USB:` refusé : `Une seule colonne USB`) ;
  `CMDER USB:`, `CMDER USB:/JEUX`, `CMDER A: USB:` ou `CMDER USB: A:` ; le chemin est lu dans
  la ligne d'origine (`get_args`) ;
- table : nom ramené en 8 + 3 (comme IMPORT, un caractère interdit devient `_`), taille
  exacte, enregistrements et blocs qu'il occuperait sur une disquette ; nom long (26
  caractères affichés, `~` au-delà) dans une zone à part ; le nom complet est relu sur la clé
  quand il faut ouvrir le fichier. Répertoires d'abord, quel que soit le tri ;
- en-tête `USB:JEUX/` (`USB:?` : LOCI absent ou clé illisible, avec le message
  `LOCI absent : cle USB inaccessible`) ; `+` après le nombre de fichiers si la liste est
  coupée à 128 ;
- copie fichier par fichier (pas de grand tampon) : depuis la clé, `^Z` ajoutés, `/T`
  (`Copier texte...` le propose) ; vers la clé, `^Z` de fin retirés, fichier remplacé sans
  question (comme EXPORT), `.DSK` refusé (`refuse(s)`) ; place vérifiée vers la disquette ;
- Absents de l'autre entre la clé et une disquette : nom 8 + 3 et taille, sans les attributs ;
  les répertoires restent montrés ;
- Voir : une fin de ligne LF seule est comprise (fichiers du Mac, de Linux) ;
- Effacer, Renommer, Attributs et Déplacer depuis la clé : `Cle USB : lecture et copie
  seulement`.
Essayé dans Oricutron avec la clé simulée (`ORIC_LOCI`) : liste, répertoires (entrer,
remonter), nom long, fichier caché et `._` absents, Voir (LF seul), copie vers B: avec `/T`
(CR LF et `^Z` vérifiés), copie d'un fichier de 70 000 octets (contenu identique), copie et
Déplacer vers la clé (EDIT.COM identique), Absents de l'autre, refus dans la colonne de la
clé, LOCI absent. Reste le vrai LOCI. CMDER.COM finirait vers **14 Ko**, toujours sans rien de résident (tampon ~25 Ko).

### 12.4 Remarques

- **Ordre de livraison** : 2a, puis 2b, puis 2c. 2b et 2c demandent d'abord de ranger ce
  qui dépend de la source (liste, lecture, écriture, effacement, renommage) derrière des
  routines par colonne : la v1 appelle le BDOS directement. Ce rangement fait partie de 2b.
- **Idées en plus** (à accepter ou non, chacune ~100-200 octets) :
  - retenues par Pierre : place avant une copie, impression de la liste (§ 12.2) ;
  - plus tard : ouvrir un fichier dans EDIT ou HEX puis revenir à CMDER (enchaînement par
    CHAIN et un script, comme `EDITE` de LOGO) ; programme de comparaison dédié.
- **Firmware du LOCI** : sans objet (ni effacement ni renommage sur la clé).
- **Grand répertoire de clé** : plus de 128 entrées : CMDER montre les 128 premières et le
  signale (`liste coupee`).

### 12.5 Réponses de Pierre (12 octobre 2026)

1. Touches `^X` autre colonne, `^Z` zoom, `^W` échanger : oui (`=` comparer : sans objet).
2. `CMDER A: A:` : refusé.
3. Absents de l'autre : nom absent, ou même nom avec une taille ou des attributs différents.
   (À sa réponse 8, Pierre écarte « différent » comme trop compliqué : compris comme la
   comparaison du contenu ; la taille et les attributs, déjà dans les tables, sont gardés.)
4. Comparer : reporté, un programme dédié.
5. Textes de la clé : option `/T` dans la réponse de Copier, et article `Copier texte...` ;
   revue des fonctions et des menus par Pierre après l'implémentation.
6. Pas de copie de répertoire entier (IMPORT * n'existe pas non plus).
7. Pas d'effacement (ni de renommage) sur la clé : c'est une passerelle.
8. Place avant une copie : oui. Imprimer la liste : oui.

### 12.6 Après l'essai du lot 2 sur le vrai Oric (Pierre)

Couleurs et deux colonnes validées (la barre de menus en vidéo inverse coupe le menu
déroulant sur la ligne des titres colorés : accepté). Ajouté : la progression d'une copie
de plusieurs fichiers donne le rang, `Copie : NOM.EXT (3/12)` (disquettes, un seul lecteur,
clé USB). Constat de Pierre : copier beaucoup de fichiers vers une disquette vierge reste plus
lent que DISKCOPY (chaque fichier coûte recherche, effacement, création, fermeture et
attributs) ; CMDER est d'abord un outil de liste et de tri, tous les indicateurs en vue.

