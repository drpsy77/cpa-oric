# Points de fonction — CP/A disquette

Mesure de ce qui a été développé : points de fonction IFPUG, points d'algorithmes (ce
qu'IFPUG ne voit pas), lignes de code et de documentation, octets produits, commits,
réutilisation, qualité. Le calcul détaillé est ici ; les totaux et les mesures sont refaits
par `python3 tools/pf_mesure.py --ecrire` (après `./build.sh`), qui vérifie aussi chaque
ligne des tableaux.

Comptage de référence : version 0.9, commit `b86817e` (18 octobre 2026).

## 1. Synthèse

<!-- synthese:debut -->
| Composant | ILF | EIF | EI | EO | EQ | **PF IFPUG** | Algorithmes | **Total** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Système et commandes | 38 | 5 | 171 | 36 | 72 | **322** | 68 | **390** |
| EDIT | 21 | 0 | 36 | 8 | 9 | **74** | 18 | **92** |
| GRAPHER + GRXASM | 28 | 22 | 115 | 25 | 15 | **205** | 46 | **251** |
| LOGO | 28 | 0 | 121 | 12 | 33 | **194** | 44 | **238** |
| CMDER | 14 | 0 | 21 | 13 | 9 | **57** | 22 | **79** |
| HEX | 7 | 0 | 6 | 0 | 6 | **19** | 5 | **24** |
| VOIR | 0 | 10 | 3 | 0 | 6 | **19** | 12 | **31** |
| USB | 14 | 0 | 8 | 0 | 3 | **25** | 5 | **30** |
| ASM | 0 | 5 | 0 | 4 | 0 | **9** | 12 | **21** |
| DEBUG | 21 | 5 | 28 | 9 | 12 | **75** | 13 | **88** |
| *Applications* | *133* | *42* | *338* | *71* | *93* | ***677*** | *177* | ***854*** |
| Exemples | 7 | 10 | 27 | 56 | 6 | **106** | 16 | **122** |
| Outillage PC | 7 | 15 | 25 | 90 | 12 | **149** | 39 | **188** |
| **Total** | **185** | **72** | **561** | **253** | **183** | **1254** | **300** | **1554** |

Points ajustés (indicatif, § 9) : 1 254 × 1,05 ≈ 1 317.

Nombre de fonctions comptées : 26 ILF, 14 EIF, 180 EI, 62 EO, 61 EQ.
<!-- synthese:fin -->

Lecture (comptage de référence) :

- Le système fait un quart des points (322 PF) : le contrat BIOS / BDOS, offert aux
  programmes, compte autant que les commandes du prompt.
- IFPUG voit mal les traducteurs : ASM n'a qu'une sortie (9 PF) pour 2 392 lignes ; ses
  12 points d'algorithmes et ses 266 lignes par PF le montrent. CMDER (105 lignes par PF)
  et HEX (82) sont aussi plus denses que la moyenne.
- 45 lignes d'assembleur par PF en moyenne, loin des quelque 320 des tables de conversion
  usuelles pour l'assembleur : le comptage est fin (chaque fonction du BDOS, chaque primitive
  qui agit compte au moins 3 points). Comparer CP/A à lui-même d'une version à l'autre,
  pas à des moyennes d'industrie.

## 2. Méthode

### 2.1 Points de fonction IFPUG

IFPUG 4.3.1 (ISO/IEC 20926), **points non ajustés**. Une frontière par composant : le
système, chaque application, les exemples (un petit programme chacun), l'outillage PC.

| Type | Faible | Moyenne | Élevée |
|---|---:|---:|---:|
| ILF : groupe de données maintenu par le composant | 7 | 10 | 15 |
| EIF : groupe de données lu, maintenu ailleurs | 5 | 7 | 10 |
| EI : entrée (modifie des données ou l'état) | 3 | 4 | 6 |
| EO : sortie avec calcul ou données dérivées | 4 | 5 | 7 |
| EQ : interrogation (lecture simple) | 3 | 4 | 6 |

Complexité d'après les matrices IFPUG : RET et DET pour les données, FTR (données lues ou
modifiées) et DET (zones échangées) pour les transactions. Les tableaux donnent RET/FTR et
DET ; la colonne Cplx (F, M, É) et les points en découlent (le script le vérifie).

Interprétation pour CP/A :

- **Utilisateurs du système** : la personne au prompt, et les programmes `.COM` qui appellent
  le BDOS et le BIOS. Chaque fonction du contrat d'interface est donc une transaction, sauf
  si elle fait exactement ce que fait déjà une transaction comptée (ligne « — », 0 point :
  `GCLS` du CCP et l'opération 0 de la fonction 115). Une commande qui ajoute un traitement
  à la fonction qu'elle appelle (ERA : liste, confirmation, bilan) compte à part.
- **Données** : un format ou un état que l'utilisateur reconnaît et que le composant tient à
  jour (répertoire CP/M, `.GRX`, `.IMG`, historique des lignes, tortue, points d'arrêt...).
  Les données du code (textes de HELP, tables) ne sont pas des groupes de données. Un
  fichier tenu par un autre composant (un `.BAT` écrit par EDIT, lu par DO) est un EIF.
- **Langages** (LOGO, GRAPHER) : une primitive qui agit sur des données ou sur l'écran est
  une transaction ; les primitives qui ne font que calculer (fonctions numériques, de mots et
  de listes) forment une sortie par famille ; les structures de contrôle (REPETE, SI, FOR,
  IF, SUB...) sont dans la transaction « exécuter ». Leur difficulté est comptée dans les
  algorithmes. Deux primitives au même traitement (AV et RE) font une transaction.
- **Non comptés** : la navigation (flèches, pages, menus déroulants : leurs articles tapent
  des commandes déjà comptées), les messages d'erreur, les réglages techniques (fonction 26,
  `SETTRK`...), PUNCH et READER (réservées au réseau).

### 2.2 Points d'algorithmes

IFPUG mesure ce que l'utilisateur échange avec le logiciel, pas la difficulté du traitement :
un assembleur deux passes ne fait qu'une sortie. Chaque algorithme développé reçoit donc
des points, selon un barème simple (dans l'esprit de SNAP, la méthode de l'IFPUG pour le
non-fonctionnel) :

| Points | Niveau | Exemples |
|---:|---|---|
| 1 | transformation directe, recherche ou contrôle simple, table | substitution de `$1`-`$9`, tri des cinq meilleurs scores |
| 3 | algorithme classique avec cas particuliers ou contraintes du matériel | Bresenham, complétion des noms, LZSS, tri sur plusieurs critères |
| 5 | algorithme lourd, ou plusieurs mécanismes imbriqués | système de fichiers CP/M, décimaux, interpréteur, traducteur, ramasse-miettes |

Un algorithme est compté une fois, dans le composant où il est écrit (une bibliothèque
partagée l'est dans son composant : `hires.inc` dans VOIR, `asm_tab.s` dans ASM,
`loci_inc.s` dans USB).

### 2.3 Mesures complémentaires (§ 7, § 8)

- **Lignes** : code, commentaires (lignes de commentaire seules), vides ; lignes **générées**
  (tables, police, textes de HELP : `Généré` en tête) à part, hors code. Répartition des
  fichiers : `COMPOSANTS` dans `tools/pf_mesure.py` (`archives/`, émulateurs et bancs d'essai
  externes exclus).
- **Octets produits** : `.COM` du composant ; système : code résident, page `$FF00`,
  chargeur d'amorçage et commandes `.COM`. Ratios **code / PF** et **octets / PF**.
- **Documentation** : lignes non vides des documents, réparties par composant ; entrées de
  l'aide de HELP.
- **Réutilisation** : lignes assemblées dans les `.COM` (chaque bibliothèque comptée dans
  chaque programme qui l'inclut) divisées par les lignes écrites.
- **Commits** qui touchent chaque composant ; le rythme se lit dans l'historique (§ 10).
- **Qualité** : défauts connus (`docs/etat.md`), points à vérifier sur le vrai Oric
  (`docs/essais-materiel.md`), défauts pour 100 PF.

### 2.4 Mise à jour

À chaque livraison qui ajoute ou change une fonction :

1. ajouter ou modifier les lignes du composant (identifiant suivant, jamais réutilisé ; une
   fonction retirée est barrée en `—` avec 0 point) ;
2. un nouveau fichier source : sa place dans `COMPOSANTS` (`tools/pf_mesure.py`) ;
3. `./build.sh`, puis `python3 tools/pf_mesure.py --ecrire` (refuse une ligne mal comptée) ;
4. une ligne dans l'historique (§ 10), la qualité (§ 8) si elle a changé.

Identifiants : composant (`SYS`, `EDIT`, `GRA`, `LOGO`, `CMD`, `HEX`, `VOIR`, `USB`, `ASM`,
`DBG`, `EX`, `OUT`), puis `D` (données), `T` (transactions) ou `A` (algorithmes) et un
numéro.

## 3. Système et commandes

BIOS, BDOS, CCP, menus, chargeur d'amorçage, et les commandes `.COM` du système : TYPE, ERA,
REN, SET, STAT, COPY, FORMAT, DISKCOPY, XDO, HELP, MEM, POKE, GO, VSYNC. Version disquette
(dans la ROM, HELP, MEM, POKE, GO et DUMP sont internes au CCP).

**Données**

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| SYS.D01 | Fichiers des lecteurs A: à D: (répertoire, extents, enregistrements, attributs R/O et SYS) | ILF | 3 | 24 | M | 10 |
| SYS.D02 | Réglages de la console et de la session (couleurs, pagination, majuscules, imprimante, vitesse du clavier, lecteur courant, mode d'écran, haut et plafond de la TPA) | ILF | 1 | 12 | F | 7 |
| SYS.D03 | Historique des lignes tapées | ILF | 1 | 2 | F | 7 |
| SYS.D04 | Image du mode SPLIT (en mémoire, fichiers `.IMG`) | ILF | 1 | 3 | F | 7 |
| SYS.D05 | État des voix du son (note, volume, durée, enveloppe, mélangeur) | ILF | 2 | 8 | F | 7 |
| SYS.D06 | Scripts `.BAT` (écrits par EDIT) | EIF | 1 | 3 | F | 5 |

**Commandes (prompt, menus, touches)**

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| SYS.T01 | DIR, DIRS : liste des fichiers (modèle, lecteur, fichiers SYS) | EQ | 1 | 6 | F | 3 |
| SYS.T02 | TYPE : afficher un texte | EQ | 1 | 3 | F | 3 |
| SYS.T03 | ERA : effacer (liste, confirmation, `/Q`, bilan des protégés) | EI | 1 | 5 | F | 3 |
| SYS.T04 | REN : renommer | EI | 1 | 3 | F | 3 |
| SYS.T05 | SET : poser les attributs | EI | 1 | 4 | F | 3 |
| SYS.T06 | SET sans option : afficher les attributs | EQ | 1 | 4 | F | 3 |
| SYS.T07 | STAT : tailles, place libre calculée d'après le répertoire | EO | 1 | 8 | F | 4 |
| SYS.T08 | COPY : copier (jokers, nom par modèle, vers un lecteur) | EI | 1 | 6 | F | 3 |
| SYS.T09 | FORMAT : formater une disquette (`/Q`, un seul lecteur) | EI | 1 | 3 | F | 3 |
| SYS.T10 | DISKCOPY : copier une disquette (`/T`, `/V`, `/S`, un seul lecteur) | EI | 1 | 6 | F | 3 |
| SYS.T11 | SAVE : sauver n pages de la TPA | EI | 1 | 3 | F | 3 |
| SYS.T12 | PUT : copier dans un fichier la sortie d'une commande | EI | 1 | 4 | F | 3 |
| SYS.T13 | DO : exécuter un script (paramètres `$1`-`$9`, ESC) | EI | 2 | 12 | M | 4 |
| SYS.T14 | XDO : appel de script à script | EI | 2 | 12 | M | 4 |
| SYS.T15 | Lancer un programme ou un script par son nom (recherche sur les lecteurs) | EI | 2 | 6 | M | 4 |
| SYS.T16 | Changer de lecteur courant (`B:`, menu Lecteur suivant) | EI | 2 | 3 | F | 3 |
| SYS.T17 | VER : version | EQ | 0 | 1 | F | 3 |
| SYS.T18 | HELP [sujet] : aide par rubriques | EQ | 0 | 2 | F | 3 |
| SYS.T19 | CLS : effacer l'écran | EI | 1 | 1 | F | 3 |
| SYS.T20 | PAPER, INK : couleurs de la console | EI | 1 | 2 | F | 3 |
| SYS.T21 | PAGE ON/OFF : pause en fin d'écran | EI | 1 | 1 | F | 3 |
| SYS.T22 | CTRL-T : majuscules (voyant `A`/`a`) | EI | 1 | 2 | F | 3 |
| SYS.T23 | CTRL-P : copie sur l'imprimante (voyant `P`) | EI | 1 | 2 | F | 3 |
| SYS.T24 | Menu Clavier : vitesse de répétition | EI | 1 | 1 | F | 3 |
| SYS.T25 | ECHO : afficher un texte | EO | 0 | 1 | F | 4 |
| SYS.T26 | PAUSE : attendre une touche | EI | 0 | 2 | F | 3 |
| SYS.T27 | SPLIT, TEXT : mode d'écran | EI | 2 | 2 | F | 3 |
| SYS.T28 | GCLS : effacer l'image | EI | 1 | 1 | F | 3 |
| SYS.T29 | GSAVE : enregistrer l'image | EI | 2 | 2 | F | 3 |
| SYS.T30 | GLOAD : charger une image | EI | 2 | 2 | F | 3 |
| SYS.T31 | MEM : carte de la mémoire selon le mode | EO | 1 | 10 | F | 4 |
| SYS.T32 | POKE : écrire en mémoire | EI | 0 | 3 | F | 3 |
| SYS.T33 | GO : lancer du code | EI | 0 | 2 | F | 3 |
| SYS.T34 | VSYNC : caler le top 50 Hz sur le balayage | EI | 1 | 3 | F | 3 |
| SYS.T35 | Complétion par TAB ou ESC (noms de fichiers, commandes ; deux fois : les noms possibles) | EQ | 1 | 4 | F | 3 |
| SYS.T36 | Démarrage à chaud (CTRL-C, RESET, menu Redémarrer, fonction 0, WBOOT) | EI | 2 | 2 | F | 3 |
| SYS.T37 | Démarrage à froid (BOOT) | EI | 2 | 2 | F | 3 |
| SYS.T38 | Reprise après plantage (BRK) | EI | 2 | 2 | F | 3 |

**Fonctions du BDOS (programmes)**

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| SYS.T40 | 0 réinitialisation (= SYS.T36) | — | — | — | — | 0 |
| SYS.T41 | 1 lecture console avec écho | EQ | 1 | 2 | F | 3 |
| SYS.T42 | 2 écriture console (pagination, imprimante) | EO | 1 | 2 | F | 4 |
| SYS.T43 | 5 imprimante | EO | 0 | 1 | F | 4 |
| SYS.T44 | 6 entrée-sortie directe | EQ | 0 | 2 | F | 3 |
| SYS.T45 | 9 afficher une chaîne | EO | 1 | 2 | F | 4 |
| SYS.T46 | 10 lecture d'une ligne éditable (historique, complétion) | EI | 2 | 4 | F | 3 |
| SYS.T47 | 11 état de la console | EQ | 0 | 1 | F | 3 |
| SYS.T48 | 12 version | EQ | 0 | 1 | F | 3 |
| SYS.T49 | 13 réinitialisation des disques | EI | 1 | 1 | F | 3 |
| SYS.T50 | 14 choisir le lecteur courant | EI | 2 | 2 | F | 3 |
| SYS.T51 | 15 ouvrir un fichier | EQ | 1 | 6 | F | 3 |
| SYS.T52 | 16 fermer un fichier | EI | 1 | 4 | F | 3 |
| SYS.T53 | 17, 18 chercher le premier, le suivant | EQ | 1 | 8 | F | 3 |
| SYS.T54 | 19 effacer | EI | 1 | 3 | F | 3 |
| SYS.T55 | 20 lecture séquentielle | EQ | 1 | 4 | F | 3 |
| SYS.T56 | 21 écriture séquentielle | EI | 1 | 4 | F | 3 |
| SYS.T57 | 22 créer | EI | 1 | 3 | F | 3 |
| SYS.T58 | 23 renommer | EI | 1 | 3 | F | 3 |
| SYS.T59 | 24 lecteurs lus | EQ | 1 | 1 | F | 3 |
| SYS.T60 | 25 lecteur courant | EQ | 1 | 1 | F | 3 |
| SYS.T61 | 26 adresse DMA (réglage des fonctions de fichiers) | — | — | — | — | 0 |
| SYS.T62 | 30 attributs | EI | 1 | 3 | F | 3 |
| SYS.T63 | 33 lecture directe | EQ | 1 | 4 | F | 3 |
| SYS.T64 | 34 écriture directe | EI | 1 | 4 | F | 3 |
| SYS.T65 | 35 taille d'un fichier (calculée) | EO | 1 | 3 | F | 4 |
| SYS.T66 | 36 position directe d'après la séquentielle | EO | 1 | 3 | F | 4 |
| SYS.T67 | 47 CHAIN | EI | 1 | 2 | F | 3 |
| SYS.T68 | 115 op 0 GCLS (= SYS.T28) | — | — | — | — | 0 |
| SYS.T69 | 115 op 1 PEN | EI | 1 | 1 | F | 3 |
| SYS.T70 | 115 op 2 PLOT | EI | 1 | 3 | F | 3 |
| SYS.T71 | 115 op 3 LINE | EI | 1 | 5 | F | 3 |
| SYS.T72 | 115 op 4 BOX | EI | 1 | 5 | F | 3 |
| SYS.T73 | 115 op 5 FBOX | EI | 1 | 5 | F | 3 |
| SYS.T74 | 115 op 6 CIRCLE | EI | 1 | 4 | F | 3 |
| SYS.T75 | 115 op 7 TEXT | EI | 1 | 4 | F | 3 |
| SYS.T76 | 115 op 8 ATTR | EI | 1 | 5 | F | 3 |
| SYS.T77 | 115 op 9 POINT | EQ | 1 | 3 | F | 3 |
| SYS.T78 | 115 op 10 MODE (= SYS.T27) | — | — | — | — | 0 |
| SYS.T79 | 115 op 11 GETMODE | EQ | 1 | 1 | F | 3 |
| SYS.T80 | 115 op 12, 13 GSAVE, GLOAD (= SYS.T29, SYS.T30) | — | — | — | — | 0 |
| SYS.T81 | 116 op 0 SILENCE | EI | 1 | 1 | F | 3 |
| SYS.T82 | 116 op 1 NOTE | EI | 1 | 5 | F | 3 |
| SYS.T83 | 116 op 2 NOISE | EI | 1 | 5 | F | 3 |
| SYS.T84 | 116 op 3 ENV | EI | 1 | 3 | F | 3 |
| SYS.T85 | 116 op 4 WAIT | EQ | 1 | 1 | F | 3 |
| SYS.T86 | 116 op 5 STATUS | EQ | 1 | 1 | F | 3 |
| SYS.T87 | 116 op 6 TONE | EI | 1 | 5 | F | 3 |
| SYS.T88 | 116 op 7 SYNC | EI | 1 | 2 | F | 3 |
| SYS.T89 | 116 op 8 MIXER | EI | 1 | 3 | F | 3 |

**Entrées du BIOS (programmes)**

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| SYS.T90 | CONST (= fonction 11) | — | — | — | — | 0 |
| SYS.T91 | CONIN : touche sans écho, codes étendus | EQ | 1 | 1 | F | 3 |
| SYS.T92 | CONOUT : caractère à l'écran, sans imprimante | EO | 1 | 2 | F | 4 |
| SYS.T93 | LIST (= fonction 5) | — | — | — | — | 0 |
| SYS.T94 | SELDSK : choisir un lecteur, état | EQ | 1 | 2 | F | 3 |
| SYS.T95 | Lire un secteur (HOME, SETTRK, SETSEC, SETDMA, READ) | EQ | 1 | 4 | F | 3 |
| SYS.T96 | Écrire un secteur (WRITE) | EI | 1 | 4 | F | 3 |
| SYS.T97 | BOOT, WBOOT (= SYS.T36, SYS.T37) | — | — | — | — | 0 |
| SYS.T98 | MENUBAR : barre de menus d'un programme (codes `$81`...) | EQ | 0 | 5 | F | 3 |

**Algorithmes**

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| SYS.A01 | Système de fichiers CP/M : blocs de 2 Ko, extents, accès direct, carte d'allocation par lecteur | `fs.s` | 5 |
| SYS.A02 | Pilote WD1793 : piste par lecteur, attentes, lecteurs non montés du LOCI | `disk.s` | 3 |
| SYS.A03 | Clavier sous IRQ : matrice, SHIFT et CTRL, codes étendus, répétition réglable | `bios.s` | 3 |
| SYS.A04 | Console : défilement, pagination, couleurs de tête de ligne, voyants, curseur | `bios.s` | 1 |
| SYS.A05 | Lecture de ligne : édition en insertion, historique, écho imprimante suspendu | `rline.s` | 3 |
| SYS.A06 | Complétion des noms et des commandes (préfixe commun, lecteurs parcourus, liste des possibles) | `rline.s` | 3 |
| SYS.A07 | Recherche des programmes et des scripts sur les lecteurs (lecteurs lus, sans réponse, LOCI) | `ccp_disk.s` | 3 |
| SYS.A08 | Menus déroulants : dessin, sauvegarde et retour de l'écran, articles qui tapent une commande | `menu.s` | 3 |
| SYS.A09 | Segment (Bresenham) dans l'image SPLIT | `gfx.s` | 3 |
| SYS.A10 | Cercle | `gfx.s` | 3 |
| SYS.A11 | Rectangles, texte dans l'image, attributs, test d'un point | `gfx.s` | 1 |
| SYS.A12 | Son AY : notes en périodes, durées sous IRQ, enveloppe, départ simultané | `snd.s` | 3 |
| SYS.A13 | Scripts : lecture ligne à ligne, remplacement de `$1`-`$9` | `script.s` | 1 |
| SYS.A14 | PUT : sortie en tampon, écrite hors affichage, état du système de fichiers sauvé et rendu | `put.s` | 3 |
| SYS.A15 | CHAIN : ligne différée exécutée après le démarrage à chaud | `bdos.s` | 1 |
| SYS.A16 | Reprise après plantage et RESET : vecteurs, écran, police et console remis | `bios.s` | 3 |
| SYS.A17 | Imprimante Centronics : strobe, accusé, VIA partagé avec l'AY | `bios.s` | 1 |
| SYS.A18 | Police et tables de l'écran (lignes de points du SPLIT calculées) | `bios.s` | 1 |
| SYS.A19 | Test de la RAM au démarrage | `bios.s` | 1 |
| SYS.A20 | Chargeur d'amorçage Microdisc | `boot.s` | 3 |
| SYS.A21 | COPY : jokers à la source et à la destination | `copy.s` | 3 |
| SYS.A22 | FORMAT : image de piste du WD1793, entrelacement 2:1, relecture | `format.s` | 3 |
| SYS.A23 | DISKCOPY : tranches, blocs cités par le répertoire, un seul lecteur | `diskcopy.s` | 3 |
| SYS.A24 | XDO : fusion du script appelé et de la fin de l'appelant dans `$$$.BAT` | `xdo.s` | 3 |
| SYS.A25 | HELP : décompression LZSS d'une rubrique | `help.s` | 3 |
| SYS.A26 | STAT : place libre d'après le répertoire | `stat.s` | 1 |
| SYS.A27 | VSYNC : calage du timer de l'IRQ sur le balayage vidéo | `vsync.s` | 3 |
| SYS.A28 | ERA, REN, SET, TYPE, MEM, POKE, GO : contrôles, décodage des paramètres | `progs/` | 1 |

## 4. Applications

### 4.1 EDIT

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| EDIT.D01 | Document texte (paragraphes) | ILF | 1 | 3 | F | 7 |
| EDIT.D02 | `EDIT.CFG` : longueur maxi, coupure, largeur d'impression par modèle de nom | ILF | 1 | 4 | F | 7 |
| EDIT.D03 | Presse-papiers (4 Ko) | ILF | 1 | 1 | F | 7 |
| EDIT.T01 | Nouveau | EI | 1 | 1 | F | 3 |
| EDIT.T02 | Ouvrir (réglages d'`EDIT.CFG`) | EQ | 2 | 3 | F | 3 |
| EDIT.T03 | Insérer un fichier au curseur | EI | 1 | 2 | F | 3 |
| EDIT.T04 | Enregistrer (`NOM.$$$` puis remplacement) | EI | 2 | 2 | F | 3 |
| EDIT.T05 | Enregistrer sous (réglages relus) | EI | 2 | 3 | F | 3 |
| EDIT.T06 | Imprimer, mis en page | EO | 2 | 3 | F | 4 |
| EDIT.T07 | Retour vers LOGO (lancé par `EDITE`) | EI | 1 | 2 | F | 3 |
| EDIT.T08 | Saisir et modifier le texte (insertion ou remplacement, DEL, RETURN) | EI | 1 | 3 | F | 3 |
| EDIT.T09 | Effacer le paragraphe | EI | 1 | 1 | F | 3 |
| EDIT.T10 | Couper le bloc | EI | 2 | 2 | F | 3 |
| EDIT.T11 | Copier le bloc | EI | 2 | 2 | F | 3 |
| EDIT.T12 | Coller | EI | 2 | 1 | F | 3 |
| EDIT.T13 | Chercher, Suivant | EQ | 1 | 2 | F | 3 |
| EDIT.T14 | Remplacer (O/N/T) | EI | 1 | 4 | F | 3 |
| EDIT.T15 | Trop long : paragraphe suivant qui dépasse le maxi | EQ | 2 | 2 | F | 3 |
| EDIT.T16 | Statistiques (caractères, mots, plus long paragraphe) | EO | 1 | 4 | F | 4 |
| EDIT.T17 | Options : coupure aux mots, insertion ou remplacement | EI | 1 | 2 | F | 3 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| EDIT.A01 | Affichage des paragraphes coupés entre les mots ou à 38 caractères, ligne d'état | `edit.s` | 3 |
| EDIT.A02 | Déplacements dans le texte coupé : lignes, pages, mots, à travers les paragraphes | `edit.s` | 3 |
| EDIT.A03 | Tampon de 32 Ko : insertion, effacement, bloc, presse-papiers | `edit.s` | 3 |
| EDIT.A04 | Recherche sans distinction de casse, remplacement interactif | `edit.s` | 1 |
| EDIT.A05 | Impression : coupure à la largeur, mots trop longs | `edit.s` | 3 |
| EDIT.A06 | `EDIT.CFG` : première ligne qui correspond (jokers, lecteur) | `edit.s` | 3 |
| EDIT.A07 | Enregistrement sûr (`NOM.$$$`, remplacement) | `edit.s` | 1 |
| EDIT.A08 | Statistiques | `edit.s` | 1 |

### 4.2 GRAPHER et GRXASM

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| GRA.D01 | Programme `.GRX` (écrit par EDIT) | EIF | 1 | 3 | F | 5 |
| GRA.D02 | Variables et tableaux (962 variables, entiers, octets, chaînes) | ILF | 2 | 6 | F | 7 |
| GRA.D03 | Fichiers de données (`.TXT`, `.DAT`, `.SCR`) | ILF | 3 | 5 | F | 7 |
| GRA.D04 | Dessin (HIRES, SPLIT ; `.HIR`, `.HIZ`, `.IMG`) | ILF | 2 | 3 | F | 7 |
| GRA.D05 | Animations `.ANI` | EIF | 1 | 3 | F | 5 |
| GRA.D06 | Sprites `.SPR` | EIF | 2 | 5 | F | 5 |
| GRA.D07 | Emplacements de sprites et codes réservés | ILF | 2 | 6 | F | 7 |
| GRA.D08 | Bibliothèques des programmes traduits (GRX, ARR, FIL, SPR, ANIM, HIRES) | EIF | 6 | 3 | M | 7 |
| GRA.T01 | Exécuter un `.GRX` (paramètres `$1`-`$9`, boucles, conditions, sous-programmes, ESC) | EI | 2 | 6 | M | 4 |
| GRA.T02 | Affectation `V = expr` | EI | 1 | 2 | F | 3 |
| GRA.T03 | DIM | EI | 1 | 4 | F | 3 |
| GRA.T04 | FILL | EI | 1 | 2 | F | 3 |
| GRA.T05 | INPUT (chaîne ou entier) | EI | 1 | 2 | F | 3 |
| GRA.T06 | PRINT | EO | 1 | 1 | F | 4 |
| GRA.T07 | GNUM : nombre dans l'image | EO | 2 | 3 | F | 4 |
| GRA.T08 | ECHO | EO | 0 | 1 | F | 4 |
| GRA.T09 | Mode d'écran : HIRES, SPLIT, TEXT, LORES | EI | 1 | 1 | F | 3 |
| GRA.T10 | CLS | EI | 0 | 1 | F | 3 |
| GRA.T11 | LOCATE | EI | 0 | 2 | F | 3 |
| GRA.T12 | CHAR | EI | 0 | 3 | F | 3 |
| GRA.T13 | SPC | EI | 0 | 2 | F | 3 |
| GRA.T14 | TAB | EI | 0 | 1 | F | 3 |
| GRA.T15 | Écriture verticale : PRINTV, ECHOV, SPCV | EO | 1 | 2 | F | 4 |
| GRA.T16 | PASTE : tableau vers l'écran | EI | 1 | 7 | F | 3 |
| GRA.T17 | GRAB : écran vers le tableau | EI | 1 | 7 | F | 3 |
| GRA.T18 | Défilement horizontal : SCROLH, ROTH | EI | 0 | 6 | F | 3 |
| GRA.T19 | Défilement vertical : SCROLV, ROTV | EI | 0 | 6 | F | 3 |
| GRA.T20 | GCLS | EI | 1 | 1 | F | 3 |
| GRA.T21 | PEN | EI | 1 | 1 | F | 3 |
| GRA.T22 | PLOT | EI | 1 | 2 | F | 3 |
| GRA.T23 | LINE | EI | 1 | 4 | F | 3 |
| GRA.T24 | BOX | EI | 1 | 4 | F | 3 |
| GRA.T25 | FBOX | EI | 1 | 4 | F | 3 |
| GRA.T26 | CIRCLE | EI | 1 | 3 | F | 3 |
| GRA.T27 | GTEXT | EI | 1 | 3 | F | 3 |
| GRA.T28 | ATTR | EI | 1 | 4 | F | 3 |
| GRA.T29 | POINT(x,y) | EQ | 1 | 2 | F | 3 |
| GRA.T30 | SCRN(col,lig) | EQ | 0 | 2 | F | 3 |
| GRA.T31 | GLOAD | EI | 1 | 1 | F | 3 |
| GRA.T32 | GSAVE | EI | 1 | 1 | F | 3 |
| GRA.T33 | ANIM | EQ | 1 | 2 | F | 3 |
| GRA.T34 | GET, WAIT | EI | 1 | 1 | F | 3 |
| GRA.T35 | INKEY | EQ | 0 | 1 | F | 3 |
| GRA.T36 | SAVE : tableau en texte | EI | 2 | 3 | F | 3 |
| GRA.T37 | LOAD | EI | 2 | 3 | F | 3 |
| GRA.T38 | BSAVE : tableau en binaire | EI | 2 | 3 | F | 3 |
| GRA.T39 | BLOAD | EI | 2 | 3 | F | 3 |
| GRA.T40 | BSAVE SCREEN | EI | 1 | 1 | F | 3 |
| GRA.T41 | BLOAD SCREEN | EI | 1 | 1 | F | 3 |
| GRA.T42 | FOUND | EQ | 1 | 1 | F | 3 |
| GRA.T43 | SPRITES n | EI | 1 | 1 | F | 3 |
| GRA.T44 | SPOOL | EI | 2 | 2 | F | 3 |
| GRA.T45 | SSHOW | EI | 3 | 6 | É | 6 |
| GRA.T46 | SHIDE | EI | 1 | 1 | F | 3 |
| GRA.T47 | Fonctions et opérateurs des expressions (RND, ABS, LEN, comparaisons de chaînes) | EO | 1 | 3 | F | 4 |
| GRA.T48 | GRXASM : traduire `NOM.GRX` en `NOM.ASM` avec les seules routines utiles | EO | 2 | 6 | M | 5 |
| GRA.T49 | `GRAPHER NOM /A` (= GRA.T48) | — | — | — | — | 0 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| GRA.A01 | Interpréteur ligne à ligne : FOR, REPEAT, WHILE, IF/ELSE, SUB, pile de contrôle, erreurs | `grapher.s` | 5 |
| GRA.A02 | Analyse des expressions entières (priorités, fonctions, chaînes) et des noms | `grxc_inc.s` | 3 |
| GRA.A03 | Variables de deux caractères à adresse calculée | `grapher.s` | 1 |
| GRA.A04 | Tableaux et chaînes : descripteurs, contrôles en interprété | `arr.inc` | 3 |
| GRA.A05 | Hasard xorshift 32 bits par octets, RND(n) | `grapher.s`, `grx.inc` | 3 |
| GRA.A06 | Rectangles PASTE, GRAB | `arr.inc` | 3 |
| GRA.A07 | Défilement et rotation (modulo, tampon de ligne) | `arr.inc` | 3 |
| GRA.A08 | Sprites en mode texte : codes réservés, caractères redessinés, fond gardé | `spr.inc` | 5 |
| GRA.A09 | Fichiers de données : texte CR LF, binaire, écran, FOUND | `fil.inc` | 3 |
| GRA.A10 | Écriture verticale | `hires.inc`, `grapher.s` | 1 |
| GRA.A11 | GRXASM : traduction en assembleur, expressions gardées en registres, sauts courts | `grxasm.s` | 5 |
| GRA.A12 | GRXASM : tableaux à adresse fixe (indices constants ou variables, décalages) | `grxasm.s` | 5 |
| GRA.A13 | GRXASM : routines utiles des bibliothèques (graphe des besoins, fermeture) | `grxasm.s` | 5 |
| GRA.A14 | `/A` : passage à GRXASM par CHAIN | `grapher.s` | 1 |

### 4.3 LOGO

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| LOGO.D01 | Procédures (espace de travail, fichiers `.LOG`) | ILF | 1 | 3 | F | 7 |
| LOGO.D02 | Variables globales, mots et listes | ILF | 1 | 3 | F | 7 |
| LOGO.D03 | Tortue (position, cap, crayon, visibilité) | ILF | 1 | 6 | F | 7 |
| LOGO.D04 | Dessin (image SPLIT, fichiers `.IMG`) | ILF | 1 | 2 | F | 7 |
| LOGO.T01 | AV, RE | EI | 2 | 2 | F | 3 |
| LOGO.T02 | DR, GA | EI | 1 | 2 | F | 3 |
| LOGO.T03 | FIXECAP | EI | 1 | 1 | F | 3 |
| LOGO.T04 | FIXEXY | EI | 2 | 2 | F | 3 |
| LOGO.T05 | Crayon : LC, BC, GOMME, INVERSE | EI | 1 | 1 | F | 3 |
| LOGO.T06 | CT, MT | EI | 2 | 1 | F | 3 |
| LOGO.T07 | NETTOIE (VE = NETTOIE et ORIGINE) | EI | 1 | 1 | F | 3 |
| LOGO.T08 | ORIGINE | EI | 2 | 1 | F | 3 |
| LOGO.T09 | XCOR, YCOR, CAP | EQ | 1 | 3 | F | 3 |
| LOGO.T10 | POINT | EI | 2 | 2 | F | 3 |
| LOGO.T11 | TRAIT | EI | 2 | 4 | F | 3 |
| LOGO.T12 | RECTANGLE | EI | 2 | 4 | F | 3 |
| LOGO.T13 | PAVE | EI | 2 | 4 | F | 3 |
| LOGO.T14 | CERCLE | EI | 2 | 1 | F | 3 |
| LOGO.T15 | ETIQUETTE | EI | 2 | 1 | F | 3 |
| LOGO.T16 | FIXECOULEUR | EI | 1 | 1 | F | 3 |
| LOGO.T17 | ALLUME? | EQ | 2 | 3 | F | 3 |
| LOGO.T18 | ECRANTEXTE, ECRANMIXTE | EI | 2 | 1 | F | 3 |
| LOGO.T19 | VIDETEXTE | EI | 0 | 1 | F | 3 |
| LOGO.T20 | ECRIS, TAPE | EO | 1 | 2 | F | 4 |
| LOGO.T21 | FIXECURSEUR | EI | 0 | 2 | F | 3 |
| LOGO.T22 | CURSEUR | EQ | 0 | 2 | F | 3 |
| LOGO.T23 | FIXECARECRAN | EI | 0 | 3 | F | 3 |
| LOGO.T24 | CARECRAN | EQ | 0 | 3 | F | 3 |
| LOGO.T25 | POUR ... FIN : définir une procédure | EI | 1 | 3 | F | 3 |
| LOGO.T26 | Exécuter une ligne ou une procédure (REPETE, SI, EXECUTE, STOP, RENDS, ATTENDS, ESC) | EI | 3 | 6 | É | 6 |
| LOGO.T27 | DONNE | EI | 1 | 2 | F | 3 |
| LOGO.T28 | TITRES | EQ | 1 | 1 | F | 3 |
| LOGO.T29 | LISTE "NOM | EQ | 1 | 2 | F | 3 |
| LOGO.T30 | OUBLIE | EI | 1 | 1 | F | 3 |
| LOGO.T31 | OUBLIETOUT | EI | 1 | 1 | F | 3 |
| LOGO.T32 | SAUVE | EI | 1 | 2 | F | 3 |
| LOGO.T33 | CHARGE (nom calculé, lignes exécutées) | EI | 2 | 2 | F | 3 |
| LOGO.T34 | EDITE et retour d'EDIT (état gardé) | EI | 4 | 3 | M | 4 |
| LOGO.T35 | SAUVEIMAGE | EI | 1 | 1 | F | 3 |
| LOGO.T36 | CHARGEIMAGE | EI | 1 | 1 | F | 3 |
| LOGO.T37 | LISLISTE | EI | 0 | 1 | F | 3 |
| LOGO.T38 | LISMOT | EI | 0 | 1 | F | 3 |
| LOGO.T39 | LISCAR | EI | 0 | 1 | F | 3 |
| LOGO.T40 | TOUCHE? | EQ | 0 | 1 | F | 3 |
| LOGO.T41 | TOUCHE (sans délai de répétition) | EQ | 0 | 1 | F | 3 |
| LOGO.T42 | Fonctions numériques (opérateurs, RACINE, SIN, COS, ARCTAN, LN, EXP, ENT, ARRONDI, ABS, QUOTIENT, RESTE, HASARD) | EO | 1 | 3 | F | 4 |
| LOGO.T43 | Fonctions de mots et listes (PR, DER, SP, SD, ITEM, COMPTE, MOT, PH, LISTE, ASCII, CAR, prédicats) | EO | 1 | 3 | F | 4 |
| LOGO.T44 | SON | EI | 1 | 4 | F | 3 |
| LOGO.T45 | SONF | EI | 1 | 4 | F | 3 |
| LOGO.T46 | BRUITV | EI | 1 | 4 | F | 3 |
| LOGO.T47 | ENVELOPPE | EI | 1 | 2 | F | 3 |
| LOGO.T48 | MELANGE | EI | 1 | 3 | F | 3 |
| LOGO.T49 | ENSEMBLE | EI | 1 | 1 | F | 3 |
| LOGO.T50 | ATTENDSSON | EQ | 1 | 1 | F | 3 |
| LOGO.T51 | JOUE? | EQ | 1 | 1 | F | 3 |
| LOGO.T52 | SILENCE | EI | 1 | 1 | F | 3 |
| LOGO.T53 | AIDE | EQ | 0 | 1 | F | 3 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| LOGO.A01 | Interpréteur : lecture directe du texte, index des primitives par lettre, pile de contextes (120 niveaux) | `logo.s` | 5 |
| LOGO.A02 | Évaluateur d'expressions typées (entier, décimal, texte), pile de valeurs, passage en décimal | `logo.s` | 3 |
| LOGO.A03 | Décimaux de 5 octets : + - * / à 0,5 ulp | `fp_inc.s` | 5 |
| LOGO.A04 | RACINE, EXP, LN, ARCTAN, SIN et COS en degrés | `fp_inc.s` | 5 |
| LOGO.A05 | Décimaux et texte dans les deux sens (9 chiffres, notation E) | `fp_inc.s` | 3 |
| LOGO.A06 | Tas des mots et listes, compactage à la manière du BASIC Microsoft | `ltxt_inc.s` | 5 |
| LOGO.A07 | Mots et listes : normalisation, sous-listes, résultats copiés | `ltxt_inc.s` | 3 |
| LOGO.A08 | RENDS : fonctions de l'utilisateur, pile du 6502 recopiée | `logo.s` | 3 |
| LOGO.A09 | Tortue en virgule fixe 1/256, sinus en table interpolé | `logo.s` | 3 |
| LOGO.A10 | Dessin sans la tortue : découpage aux bords, cercle, rectangle, étiquette | `logo.s` | 3 |
| LOGO.A11 | EDITE : état sauvé dans `LOGO.$$$`, CHAIN aller et retour | `logo.s` | 3 |
| LOGO.A12 | Son : ENSEMBLE (contexte, imbrication), arguments gardés sur la pile | `logo.s` | 1 |
| LOGO.A13 | TOUCHE sans délai de répétition | `logo.s` | 1 |
| LOGO.A14 | HASARD | `logo.s` | 1 |

### 4.4 CMDER

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| CMD.D01 | Fichiers des lecteurs (répertoire, attributs) | ILF | 2 | 10 | F | 7 |
| CMD.D02 | Fichiers et dossiers de la clé USB | ILF | 2 | 5 | F | 7 |
| CMD.T01 | Liste des fichiers (tri, filtre, SYS cachés, deux colonnes) | EQ | 1 | 10 | F | 3 |
| CMD.T02 | Liste de la clé USB (dossiers) | EQ | 1 | 6 | F | 3 |
| CMD.T03 | Absents de l'autre colonne, ou différents | EO | 2 | 6 | M | 5 |
| CMD.T04 | Voir un texte | EQ | 1 | 3 | F | 3 |
| CMD.T05 | Copier (lecteurs, clé, un seul lecteur, place, remplacer) | EI | 2 | 8 | M | 4 |
| CMD.T06 | Copier texte (LF seul en CR LF, TAB) | EI | 2 | 8 | M | 4 |
| CMD.T07 | Déplacer | EI | 2 | 6 | M | 4 |
| CMD.T08 | Renommer | EI | 1 | 3 | F | 3 |
| CMD.T09 | Effacer (confirmation, bilan) | EI | 1 | 3 | F | 3 |
| CMD.T10 | Attributs R et S | EI | 1 | 3 | F | 3 |
| CMD.T11 | Taille exacte (d'un fichier, de tous) | EO | 1 | 4 | F | 4 |
| CMD.T12 | Imprimer la liste | EO | 1 | 6 | F | 4 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| CMD.A01 | Table des fichiers : extents regroupés (enregistrements, blocs) | `cmder.s` | 3 |
| CMD.A02 | Tri sur quatre critères, ordre inverse | `cmder.s` | 3 |
| CMD.A03 | Filtre et marques par modèle | `cmder.s` | 1 |
| CMD.A04 | Comparaison des deux colonnes | `cmder.s` | 3 |
| CMD.A05 | Copie en tranches avec un seul lecteur : FCB repris, empreinte du répertoire contre la mauvaise disquette | `cmder.s` | 5 |
| CMD.A06 | Contrôle de place (blocs requis moins ceux des fichiers remplacés) | `cmder.s` | 3 |
| CMD.A07 | Clé : noms ramenés en 8 + 3, dossiers | `cmder.s` | 1 |
| CMD.A08 | Fins de ligne et tabulations converties | `cmder.s` | 1 |
| CMD.A09 | Deux colonnes : états échangés, seule la colonne active redessinée | `cmder.s` | 1 |
| CMD.A10 | Saisie en ligne propre (texte proposé modifiable) | `cmder.s` | 1 |

### 4.5 HEX

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| HEX.D01 | Fichier édité (octets) | ILF | 1 | 3 | F | 7 |
| HEX.T01 | Ouvrir et afficher (hexa et ASCII, fenêtres de 32 Ko, aller à une adresse) | EQ | 1 | 6 | F | 3 |
| HEX.T02 | Modifier des octets (hexa ou ASCII) | EI | 1 | 3 | F | 3 |
| HEX.T03 | Chercher du texte ou des octets (`#hexa`), suivant | EQ | 1 | 3 | F | 3 |
| HEX.T04 | Enregistrer sur place les enregistrements modifiés | EI | 1 | 2 | F | 3 |
| HEX.T05 | Recharger (= HEX.T01) | — | — | — | — | 0 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| HEX.A01 | Fenêtres de 32 Ko par accès direct, seuls les enregistrements modifiés réécrits | `hex.s` | 3 |
| HEX.A02 | Recherche de texte ou d'une suite d'octets | `hex.s` | 1 |
| HEX.A03 | Saisie par demi-octet, deux zones d'affichage | `hex.s` | 1 |

### 4.6 VOIR

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| VOIR.D01 | Images (`.HIR`, `.HIZ`, `.IMG`) | EIF | 2 | 2 | F | 5 |
| VOIR.D02 | Animations (`.ANI`) | EIF | 1 | 3 | F | 5 |
| VOIR.T01 | Afficher une image | EQ | 1 | 2 | F | 3 |
| VOIR.T02 | Jouer une animation n fois | EQ | 1 | 3 | F | 3 |
| VOIR.T03 | Déplacer la ligne de déchirure (flèches) | EI | 0 | 1 | F | 3 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| VOIR.A01 | Décompression LZSS (`h_unz`) | `hires.inc` | 3 |
| VOIR.A02 | Animation par différences : zones gardées sans copie, distance « négative », cadence au top 50 Hz sans dérive | `anim.inc`, `hires.inc` | 5 |
| VOIR.A03 | HIRES.INC : segment et cercle | `hires.inc` | 3 |
| VOIR.A04 | HIRES.INC : écran texte au programme (LORES), texte, attributs, chargement et sauvegarde | `hires.inc` | 1 |

### 4.7 USB (EXPORT, IMPORT, USBDIR)

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| USB.D01 | Fichiers des lecteurs | ILF | 1 | 5 | F | 7 |
| USB.D02 | Fichiers et dossiers de la clé USB et de la mémoire du LOCI | ILF | 2 | 5 | F | 7 |
| USB.T01 | EXPORT (un fichier ou des jokers, dossier, `^Z` retirés, `.DSK` refusé) | EI | 2 | 6 | M | 4 |
| USB.T02 | IMPORT (nom en 8.3, `/T`, `^Z` ajoutés) | EI | 2 | 6 | M | 4 |
| USB.T03 | USBDIR : liste (tailles, dossiers) | EQ | 1 | 4 | F | 3 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| USB.A01 | API de la MIA du LOCI : détection, opérations, transferts par 128 octets | `loci_inc.s` | 3 |
| USB.A02 | Conversions `^Z` et `/T` | `export.s`, `import.s` | 1 |
| USB.A03 | Noms longs en 8.3 | `import.s` | 1 |

### 4.8 ASM

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| ASM.D01 | Source `.ASM` et inclusions | EIF | 1 | 3 | F | 5 |
| ASM.T01 | Assembler : `NOM.COM`, `NOM.SYM`, liste des erreurs | EO | 1 | 6 | F | 4 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| ASM.A01 | Assembleur 6502 en deux passes : 56 mnémoniques, 12 modes, page zéro automatique, code écrit au fil de la passe 2 | `asm.s`, `asm_tab.s` | 5 |
| ASM.A02 | Évaluateur d'expressions (priorités, `<` `>`, unaires, `*`) | `asm.s` | 3 |
| ASM.A03 | Table des symboles, blocs locaux `.(` `.)` | `asm.s` | 3 |
| ASM.A04 | Directives (`.byt`, `.asc`, `.word`, `.dsb`, second `*=`), inclusion | `asm.s` | 1 |

### 4.9 DEBUG

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| DBG.D01 | Programme chargé (code et données en mémoire) | ILF | 1 | 3 | F | 7 |
| DBG.D02 | Registres du programme | ILF | 1 | 12 | F | 7 |
| DBG.D03 | Points d'arrêt (8) | ILF | 1 | 2 | F | 7 |
| DBG.D04 | Symboles `.SYM` (écrits par ASM) | EIF | 1 | 3 | F | 5 |
| DBG.T01 | Charger le programme, ses symboles et ses paramètres | EI | 3 | 4 | M | 4 |
| DBG.T02 | R : afficher les registres | EQ | 1 | 12 | F | 3 |
| DBG.T03 | R reg=v : modifier un registre ou un indicateur | EI | 1 | 2 | F | 3 |
| DBG.T04 | L : désassembler avec les symboles | EO | 2 | 6 | M | 5 |
| DBG.T05 | D : mémoire en hexa et ASCII | EQ | 1 | 3 | F | 3 |
| DBG.T06 | M : écrire des octets | EI | 1 | 2 | F | 3 |
| DBG.T07 | G : exécuter jusqu'à un point d'arrêt | EI | 3 | 2 | M | 4 |
| DBG.T08 | T : pas à pas, en entrant dans les JSR | EI | 3 | 3 | M | 4 |
| DBG.T09 | P : pas à pas, JSR d'un coup | EI | 3 | 3 | M | 4 |
| DBG.T10 | B adr : poser un point d'arrêt | EI | 1 | 1 | F | 3 |
| DBG.T11 | B : lister les points d'arrêt | EQ | 1 | 1 | F | 3 |
| DBG.T12 | B- : enlever un point ou tous | EI | 1 | 1 | F | 3 |
| DBG.T13 | ? expr : valeur et symbole le plus proche | EO | 1 | 3 | F | 4 |
| DBG.T14 | H : aide | EQ | 0 | 1 | F | 3 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| DBG.A01 | Désassembleur avec les étiquettes du source | `debug.s` | 3 |
| DBG.A02 | Pas à pas par BRK provisoires (deux suites d'un branchement, appels au système d'un coup) | `debug.s` | 5 |
| DBG.A03 | Vecteurs IRQ, NMI, WBOOT détournés, page zéro échangée, pile du programme gardée | `debug.s` | 3 |
| DBG.A04 | Placement en `$8400`, haut de la TPA abaissé | `debug.s` | 1 |
| DBG.A05 | Adresses : hexa, `#décimal`, `nom+n`, symbole le plus proche | `debug.s` | 1 |

## 5. Exemples

Chaque exemple est un petit programme, compté pour ce qu'il fait. ELIZA2 rend le même
service qu'ELIZA, mais c'est un autre programme : compté à part.

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| EX.D01 | Meilleurs scores `HOFN.TXT`, `HOFS.TXT` (SCORES) | ILF | 1 | 2 | F | 7 |
| EX.D02 | Sprites `HEROS.SPR` (SPRITES) | EIF | 2 | 4 | F | 5 |
| EX.D03 | Animations de démonstration (ANIMS, DEMO.BAT) | EIF | 1 | 2 | F | 5 |
| EX.T01 | HELLO : message et paramètres | EO | 0 | 2 | F | 4 |
| EX.T02 | GTEST : démonstration graphique SPLIT | EO | 0 | 1 | F | 4 |
| EX.T03 | DESSIN.GRX : dessin avec un texte en paramètre | EO | 0 | 2 | F | 4 |
| EX.T04 | ECRAN.GRX : écran titre | EO | 0 | 1 | F | 4 |
| EX.T05 | MOTIFS.GRX : éventail, cercles, ciel étoilé | EO | 0 | 1 | F | 4 |
| EX.T06 | ARDOISE.GRX : dessiner aux flèches | EI | 0 | 1 | F | 3 |
| EX.T07 | ARDOISE.GRX : effacer | EI | 0 | 1 | F | 3 |
| EX.T08 | FLECHES.GRX : déplacer le `@` dans un cadre | EI | 0 | 2 | F | 3 |
| EX.T09 | SERPENT.GRX : jeu du serpent, longueur affichée | EI | 0 | 3 | F | 3 |
| EX.T10 | SCORES.GRX : saisir un nom et un score, garder les cinq meilleurs | EI | 1 | 2 | F | 3 |
| EX.T11 | SCORES.GRX : tableau des scores | EQ | 1 | 2 | F | 3 |
| EX.T12 | SPRITES.GRX : bonhomme aux flèches, balle qui rebondit | EI | 1 | 2 | F | 3 |
| EX.T13 | CARTE.GRX : explorer un monde de 128 × 64 cases | EI | 0 | 2 | F | 3 |
| EX.T14 | DEFILE.GRX : conduire sur une route qui défile | EI | 0 | 2 | F | 3 |
| EX.T15 | ANIMS.GRX : jouer les animations | EQ | 1 | 1 | F | 3 |
| EX.T16 | DEMO.LOG : CARRE, POLY | EO | 0 | 2 | F | 4 |
| EX.T17 | DEMO.LOG : ETOILE, FLEUR, SPIRALE | EO | 0 | 2 | F | 4 |
| EX.T18 | DEMO.LOG : ARBRE (récursif) | EO | 0 | 2 | F | 4 |
| EX.T19 | ELIZA.LOG : conversation | EO | 0 | 2 | F | 4 |
| EX.T20 | ELIZA2.LOG : la même, par fonctions récursives | EO | 0 | 2 | F | 4 |
| EX.T21 | FLECHES.LOG : déplacer un `@`, murs lus à l'écran | EI | 0 | 2 | F | 3 |
| EX.T22 | TRACARRE.LOG : courbe de x² | EO | 0 | 5 | F | 4 |
| EX.T23 | TRASINUS.LOG : courbe du sinus | EO | 0 | 5 | F | 4 |
| EX.T24 | TRASINXX.LOG : courbe de x sin x | EO | 0 | 5 | F | 4 |
| EX.T25 | DEMO.BAT : démonstration enchaînée | EO | 1 | 1 | F | 4 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| EX.A01 | CARTE : monde tiré au hasard (arbres, montagnes, lacs), fenêtre qui suit le joueur | `carte.grx` | 3 |
| EX.A02 | SERPENT : corps en anneau dans deux tableaux, collisions | `serpent.grx` | 1 |
| EX.A03 | SCORES : tri, cinq meilleurs gardés | `scores.grx` | 1 |
| EX.A04 | SPRITES : rebond, deux images de marche | `sprites.grx` | 1 |
| EX.A05 | DEFILE : route qui défile | `defile.grx` | 1 |
| EX.A06 | ELIZA : mots-clés, conjugaison, réponses de repli | `eliza.log` | 3 |
| EX.A07 | ELIZA2 : recherches récursives arrêtées dès qu'elles trouvent | `eliza2.log` | 3 |
| EX.A08 | Traceurs : repère, échelle, pas | `tra*.log` | 1 |
| EX.A09 | ARBRE récursif, spirales | `demo.log` | 1 |
| EX.A10 | GTEST, DESSIN, MOTIFS : figures | `gtest.s`, `*.grx` | 1 |

## 6. Outillage PC

Programmes qui tournent sur le Mac ou sous Linux : construction, images, tests.

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| OUT.D01 | Images de disquette `.DSK` (géométrie, répertoire CP/M) | ILF | 2 | 12 | F | 7 |
| OUT.D02 | Sources du projet (`src`, `progs`, `files`) | EIF | 3 | 3 | F | 5 |
| OUT.D03 | Images et animations d'origine (PNG, GIF) | EIF | 1 | 3 | F | 5 |
| OUT.D04 | Scénarios et références des tests | EIF | 2 | 3 | F | 5 |
| OUT.T01 | `build.sh` : ROM et cinq disquettes, contrôles de taille, marges | EO | 3 | 8 | M | 5 |
| OUT.T02 | `mkdisk.py new` : créer une image | EI | 2 | 6 | M | 4 |
| OUT.T03 | `mkdisk.py ls` | EQ | 1 | 5 | F | 3 |
| OUT.T04 | `mkdisk.py get` | EQ | 1 | 2 | F | 3 |
| OUT.T05 | `mkdisk.py put` (CR LF) | EI | 2 | 3 | F | 3 |
| OUT.T06 | `mkdisk.py era` | EI | 1 | 1 | F | 3 |
| OUT.T07 | `mkdisk.py attr` | EI | 1 | 2 | F | 3 |
| OUT.T08 | `gen_tables.py` : tables de l'écran et du clavier | EO | 0 | 2 | F | 4 |
| OUT.T09 | `gen_font.py` : police | EO | 0 | 1 | F | 4 |
| OUT.T10 | `gen_asm_tab.py` : mnémoniques et opcodes | EO | 0 | 2 | F | 4 |
| OUT.T11 | `gen_readme_txt.py` : README.TXT et textes de HELP | EO | 0 | 3 | F | 4 |
| OUT.T12 | `strip_inc.py` : bibliothèques sans commentaires | EO | 1 | 1 | F | 4 |
| OUT.T13 | `mark_inc.py` : bibliothèques marquées par routine | EO | 1 | 3 | F | 4 |
| OUT.T14 | `lzhir.py c` : compresser | EO | 1 | 2 | F | 4 |
| OUT.T15 | `lzhir.py d` : décompresser | EO | 1 | 2 | F | 4 |
| OUT.T16 | `lzhir.py i` : informations | EQ | 1 | 2 | F | 3 |
| OUT.T17 | `png2hir.py` : image HIRES ou SPLIT | EO | 1 | 4 | F | 4 |
| OUT.T18 | `mkanim.py` : animation, bilan, aperçu | EO | 1 | 6 | F | 4 |
| OUT.T19 | `anim_demos.py` : animations de démonstration | EO | 0 | 2 | F | 4 |
| OUT.T20 | `run_com.py` : exécuter un `.COM` dans un 6502 simulé | EO | 2 | 4 | F | 4 |
| OUT.T21 | `run_test.sh` : Oricutron piloté (frappe, vidage mémoire) | EO | 1 | 4 | F | 4 |
| OUT.T22 | `screen.py` : texte de l'écran | EQ | 1 | 1 | F | 3 |
| OUT.T23 | `smoke_test.sh` | EO | 2 | 3 | F | 4 |
| OUT.T24 | `test_asm.sh` | EO | 1 | 3 | F | 4 |
| OUT.T25 | `test_logo.sh` | EO | 2 | 3 | F | 4 |
| OUT.T26 | `test_grapher.sh` | EO | 2 | 3 | F | 4 |
| OUT.T27 | `test_inc.sh` | EO | 2 | 3 | F | 4 |
| OUT.T28 | `test_fp.py` | EO | 0 | 3 | F | 4 |
| OUT.T29 | `test_anim.py` | EO | 1 | 3 | F | 4 |
| OUT.T30 | `setup_linux.sh` | EI | 0 | 2 | F | 3 |
| OUT.T31 | `setup_clk.sh` (deux correctifs de Clock Signal) | EI | 0 | 2 | F | 3 |
| OUT.T32 | `build_xa.sh` | EI | 0 | 1 | F | 3 |
| OUT.T33 | `build_clk_mac.sh` | EI | 0 | 1 | F | 3 |
| OUT.T34 | `pf_mesure.py` : mesures et totaux de ce document | EO | 3 | 10 | M | 5 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| OUT.A01 | Image MFM, entrelacement, répertoire et allocation CP/M, attributs, CR LF | `mkdisk.py` | 3 |
| OUT.A02 | Compression LZSS (format repris d'un ancien compresseur OSDK) | `lzhir.py` | 3 |
| OUT.A03 | Animation : différences entre images, zones gardées, estimation des cycles de décodage | `mkanim.py` | 5 |
| OUT.A04 | Mise à l'échelle, seuil ou tramage, codage HIRES | `png2hir.py` | 3 |
| OUT.A05 | Démonstrations : cube en projection, balle, vaisseau | `anim_demos.py` | 3 |
| OUT.A06 | Découpage des bibliothèques en routines, relevé des besoins | `mark_inc.py` | 3 |
| OUT.A07 | Retrait des commentaires | `strip_inc.py` | 1 |
| OUT.A08 | Aide en colonnes de 37 caractères, rubriques compressées | `gen_readme_txt.py` | 3 |
| OUT.A09 | Tables, police, opcodes | `gen_*.py` | 1 |
| OUT.A10 | 6502 simulé (py65) avec un BDOS minimal et des fichiers | `run_com.py` | 3 |
| OUT.A11 | Oricutron piloté : correctif (frappe simulée, vidage mémoire) | `oricutron-testhook.patch`, `run_test.sh` | 3 |
| OUT.A12 | Clock Signal : correctifs (quatre lecteurs, banc d'essai) | `clk-*.patch` | 3 |
| OUT.A13 | Décimaux comparés au calcul exact, erreur en ulp | `test_fp.py`, `fp_harness.s` | 3 |
| OUT.A14 | Tests par comparaison aux références (LOGO, GRAPHER, ASM, bibliothèques) | `test_*.sh` | 1 |
| OUT.A15 | Comptage des lignes, contrôle des matrices IFPUG | `pf_mesure.py` | 1 |

## 7. Mesures

<!-- mesures:debut -->
| Composant | Fichiers | Code | Commentaires | Vides | Générées | % comment. | Octets produits | Code / PF | Octets / PF |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Système et commandes | 36 | 11 053 | 1 102 | 536 | 830 | 9 % | 36 311 | 34 | 113 |
| EDIT | 2 | 3 313 | 174 | 118 | 5 | 5 % | 8 192 | 45 | 111 |
| GRAPHER + GRXASM | 8 | 11 785 | 833 | 405 | 0 | 7 % | 30 053 | 57 | 147 |
| LOGO | 4 | 8 696 | 553 | 287 | 16 | 6 % | 18 960 | 45 | 98 |
| CMDER | 1 | 5 991 | 294 | 181 | 0 | 5 % | 13 581 | 105 | 238 |
| HEX | 1 | 1 564 | 87 | 59 | 0 | 5 % | 3 840 | 82 | 202 |
| VOIR | 3 | 1 468 | 168 | 64 | 0 | 10 % | 3 353 | 77 | 176 |
| USB | 4 | 1 313 | 135 | 74 | 0 | 9 % | 4 479 | 53 | 179 |
| ASM | 2 | 2 392 | 117 | 76 | 70 | 5 % | 5 949 | 266 | 661 |
| DEBUG | 1 | 2 378 | 121 | 87 | 0 | 5 % | 6 496 | 32 | 87 |
| Exemples | 27 | 888 | 53 | 30 | 0 | 6 % | 244 | 8 | 2 |
| Outillage PC | 147 | 5 780 | 568 | 322 | 0 | 9 % | — | 39 | — |
| **Total** | 236 | 56 621 | 4 205 | 2 239 | 921 | 7 % | 131 458 | 45 | 105 |

Octets du système : code résident 13 875 (`$C000-$F633`), page `$FF00` 232, chargeur d'amorçage 768 ; le reste : les commandes `.COM` du système. Exemples : HELLO et GTEST seulement (les `.GRX` et `.LOG` sont interprétés) ; données binaires des exemples (`.ANI`, `.HIZ`, `.SPR`, `.GIF`) : 71 407 octets.

| Composant | Documentation (lignes) | Aide de HELP (entrées) | Doc / PF | Commits |
|---|---:|---:|---:|---:|
| Système et commandes | 1 155 | 76 | 3,6 | 72 |
| EDIT | 68 | 19 | 0,9 | 7 |
| GRAPHER + GRXASM | 744 | 64 | 3,6 | 26 |
| LOGO | 273 | 63 | 1,4 | 19 |
| CMDER | 169 | 24 | 3,0 | 9 |
| HEX | 34 | 9 | 1,8 | 2 |
| VOIR | 78 | — | 4,1 | 8 |
| USB | 38 | 9 | 1,5 | 5 |
| ASM | 42 | 10 | 4,7 | 3 |
| DEBUG | 40 | 12 | 0,5 | 1 |
| Exemples | 0 | — | 0,0 | 17 |
| Outillage PC | 291 | — | 2,0 | 85 |
| Transverse (projet) | 1 201 | — | — | 24 |
| **Total** | 4 133 | 286 | 3,3 | 131 |

Lignes de documentation : lignes non vides de `docs/*.md` (`manuel.md` réparti par section), `README.md`, `CLAUDE.md` ; aide de HELP : entrées de `tools/gen_readme_txt.py`. Un commit compte pour chaque composant qu'il touche (la colonne ne s'additionne pas).

Historique : 131 commits du 2026-10-04 au 2026-10-18.

Réutilisation : 43 871 lignes de code écrites dans `progs/`, 49 172 lignes assemblées dans les `.COM` (bibliothèques incluses comptées dans chaque programme qui les inclut) : taux 1,12 (sans compter les bibliothèques que GRXASM recopie dans les programmes traduits).
<!-- mesures:fin -->

## 8. Qualité

Défauts connus : `docs/etat.md` § 5 ; points à vérifier : `docs/essais-materiel.md`
(« À vérifier », une puce = un point).

| Composant | Défauts connus | Manques notés | À vérifier sur le matériel |
|---|---:|---:|---:|
| Système et commandes | 0 | 0 | 9 |
| EDIT | 3 | 0 | 1 |
| GRAPHER + GRXASM | 1 | 1 | 16 |
| LOGO | 0 | 0 | 7 |
| CMDER | 0 | 0 | 1 |
| HEX | 0 | 0 | 2 |
| VOIR | 0 | 0 | 1 |
| USB | 0 | 0 | 1 |
| ASM | 0 | 0 | 1 |
| DEBUG | 0 | 0 | 1 |
| Outillage | 0 | 0 | 1 |
| **Total** | **4** | **1** | **41** |

- EDIT : Enregistrer sous depuis un document R/O (tout nom refusé), fichier existant
  remplacé sans question, faux succès sur un fichier R/O.
- GRAPHER : `SAVE`, `BSAVE` effacent l'ancien fichier avant d'écrire (disque plein : contenu
  perdu) ; manque : savoir si un fichier existe sans le charger.

## 9. Facteur d'ajustement (indicatif)

Les 14 caractéristiques générales d'IFPUG (0 à 5), pour l'ensemble :

| Caractéristique | Note | Caractéristique | Note |
|---|---:|---|---:|
| Communication de données (clé USB du LOCI) | 1 | Mise à jour en ligne | 3 |
| Traitement distribué | 0 | Traitements complexes | 4 |
| Performances (6502 à 1 MHz) | 4 | Réutilisation | 3 |
| Configuration contrainte (16 Ko résidents, octets comptés) | 5 | Facilité d'installation | 2 |
| Volume de transactions | 1 | Facilité d'exploitation (reprise, scripts) | 3 |
| Saisie interactive | 5 | Plusieurs sites (disquette, ROM, émulateurs, matériel) | 3 |
| Ergonomie (menus, complétion, historique) | 4 | Facilité de modification | 2 |

Total 40 : facteur 0,65 + 0,01 × 40 = **1,05**.

## 10. Historique des comptages

| Date | Commit | Version | PF IFPUG | Algorithmes | Total | Commits | Ce qui a changé |
|---|---|---|---:|---:|---:|---:|---|
| 2026-10-18 | `b86817e` | 0.9 | 1 254 | 300 | 1 554 | 131 | comptage de référence |
