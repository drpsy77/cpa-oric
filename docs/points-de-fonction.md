# Points de fonction — CP/A disquette

Mesure de ce qui a été développé : points de fonction IFPUG, points d'algorithmes (ce
qu'IFPUG ne voit pas), lignes de code et de documentation, octets produits, commits,
réutilisation, qualité. Le calcul détaillé est ici ; les totaux et les mesures sont refaits
par `python3 tools/pf_mesure.py --ecrire` (après `./build.sh`), qui vérifie aussi chaque
ligne des tableaux.

Comptage de référence : version 0.9, commit `b86817e` (18 octobre 2026).
Comparaison avec CP/M 2.2 et applications de CP/M qui manquent à CP/A : § 11.

## 1. Synthèse

<!-- synthese:debut -->
| Composant | ILF | EIF | EI | EO | EQ | **PF IFPUG** | Algorithmes | **Total** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Système et commandes | 38 | 5 | 171 | 36 | 72 | **322** | 68 | **390** |
| EDIT | 21 | 0 | 36 | 8 | 9 | **74** | 18 | **92** |
| GRAPHER + GRXASM | 35 | 22 | 125 | 29 | 18 | **229** | 51 | **280** |
| LOGO | 28 | 0 | 121 | 12 | 33 | **194** | 44 | **238** |
| CMDER | 14 | 0 | 21 | 13 | 9 | **57** | 22 | **79** |
| HEX | 7 | 0 | 6 | 0 | 6 | **19** | 5 | **24** |
| VOIR | 0 | 10 | 3 | 0 | 6 | **19** | 12 | **31** |
| USB | 14 | 0 | 8 | 0 | 3 | **25** | 5 | **30** |
| ASM | 0 | 5 | 0 | 4 | 0 | **9** | 12 | **21** |
| DEBUG | 21 | 5 | 28 | 9 | 12 | **75** | 13 | **88** |
| *Applications* | *140* | *42* | *348* | *75* | *96* | ***701*** | *182* | ***883*** |
| Exemples | 7 | 10 | 27 | 56 | 6 | **106** | 16 | **122** |
| Outillage PC | 7 | 15 | 25 | 102 | 18 | **167** | 45 | **212** |
| **Total** | **192** | **72** | **571** | **269** | **192** | **1296** | **311** | **1607** |

Points ajustés (indicatif, § 9) : 1 296 × 1,05 ≈ 1 361.

Nombre de fonctions comptées : 27 ILF, 14 EIF, 183 EI, 66 EO, 64 EQ.
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
| SYS.A16 | Reprise après plantage et RESET : vecteurs, écran, police et console remis ; RESET différé jusqu'à la fin d'un transfert de secteur | `bios.s`, `disk.s` | 3 |
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
| EDIT.D02 | `EDIT.CFG` : longueur maxi, coupure (mots, caractères, ligne), largeur d'impression par modèle de nom | ILF | 1 | 4 | F | 7 |
| EDIT.D03 | Presse-papiers (4 Ko) | ILF | 1 | 1 | F | 7 |
| EDIT.T01 | Nouveau | EI | 1 | 1 | F | 3 |
| EDIT.T02 | Ouvrir (réglages d'`EDIT.CFG` ; fichier trop long : tronqué, pas d'enregistrement sous son nom) | EQ | 2 | 3 | F | 3 |
| EDIT.T03 | Insérer un fichier au curseur | EI | 1 | 2 | F | 3 |
| EDIT.T04 | Enregistrer (`NOM.$$$` puis remplacement) | EI | 2 | 2 | F | 3 |
| EDIT.T05 | Enregistrer sous (réglages relus ; fichier existant : `Remplacer (O/N)`, protégé : refusé) | EI | 2 | 4 | F | 3 |
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
| EDIT.T17 | Options : mode d'affichage (mots, 38 caractères, ligne ; CTRL-W), insertion ou remplacement | EI | 1 | 3 | F | 3 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| EDIT.A01 | Affichage des paragraphes coupés entre les mots ou à 38 caractères, ou en ligne entière avec défilement horizontal, ligne d'état | `edit.s` | 3 |
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
| GRA.D09 | Tuiles : tables par place, carte du dernier TMAP | ILF | 2 | 6 | F | 7 |
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
| GRA.T50 | TILESET | EI | 2 | 4 | F | 3 |
| GRA.T51 | TMAP | EI | 2 | 7 | M | 4 |
| GRA.T52 | TILE(x,y) | EQ | 2 | 3 | F | 3 |
| GRA.T53 | TFONT | EI | 2 | 3 | F | 3 |
| GRA.T54 | `/C` : traduire puis assembler (CHAIN vers `ASM NOM /E`), `NOM.COM` seul | EO | 2 | 3 | F | 4 |

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
| GRA.A09 | Fichiers de données : texte CR LF, binaire, écran, FOUND ; écriture sûre (`NOM.$$$`, remplacement) | `fil.inc` | 3 |
| GRA.A10 | Écriture verticale | `hires.inc`, `grapher.s` | 1 |
| GRA.A11 | GRXASM : traduction en assembleur, expressions gardées en registres, sauts courts | `grxasm.s` | 5 |
| GRA.A12 | GRXASM : tableaux à adresse fixe (indices constants ou variables, décalages) | `grxasm.s` | 5 |
| GRA.A13 | GRXASM : routines utiles des bibliothèques (graphe des besoins, fermeture) | `grxasm.s` | 5 |
| GRA.A14 | `/A`, `/C` : passage à GRXASM, puis à ASM, par CHAIN ; bibliothèques cherchées sur le lecteur du `.GRX`, puis sur les lecteurs lus | `grapher.s`, `grxasm.s` | 1 |
| GRA.A15 | Tuiles : une table par place dans la tuile, carte traduite par morceaux (avant, dans, après la carte), instructions modifiées par ligne, coordonnées sans division | `spr.inc` | 5 |

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
| ASM.T01 | Assembler : `NOM.COM`, `NOM.SYM` (`/S`), liste des erreurs ; `/E` : source effacée après succès | EO | 1 | 7 | F | 4 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| ASM.A01 | Assembleur 6502 en deux passes : 56 mnémoniques, 12 modes, page zéro automatique, code écrit au fil de la passe 2 | `asm.s`, `asm_tab.s` | 5 |
| ASM.A02 | Évaluateur d'expressions (priorités, `<` `>`, unaires, `*`) | `asm.s` | 3 |
| ASM.A03 | Table des symboles, blocs locaux `.(` `.)` | `asm.s` | 3 |
| ASM.A04 | Directives (`.byt`, `.asc`, `.word`, `.dsb`, second `*=`), inclusion (lecteur de la source, puis lecteurs lus) | `asm.s` | 1 |

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
| EX.T13 | CARTE.GRX : explorer une île de 64 × 32 tuiles | EI | 0 | 2 | F | 3 |
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
| EX.A01 | CARTE : île de tuiles tirée au hasard (lacs, arbres, montagnes, murs), fenêtre centrée sur le joueur, déplacement sur l'herbe | `carte.grx` | 3 |
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
| OUT.T01 | `build.sh` : ROM et sept disquettes (dont la disquette de projet vierge et la disquette anglaise), deux langues de messages, contrôles de taille, marges | EO | 3 | 8 | M | 5 |
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
| OUT.T35 | `mkspr.py` : `.SPR` (sprites ou tuiles) d'après un dessin en texte | EO | 1 | 4 | F | 4 |
| OUT.T36 | `mkdisk.py check` : secteurs, répertoire, cohérence des fichiers, défauts et avertissements | EQ | 1 | 6 | F | 3 |
| OUT.T37 | `mkdisk.py repare` : image réécrite saine | EO | 1 | 3 | F | 4 |
| OUT.T38 | `mkdisk.py diff` : fichiers ajoutés, effacés, modifiés | EQ | 1 | 4 | F | 3 |
| OUT.T39 | `test_fichiers.py` : sûreté des enregistrements (EDIT, GRAPHER) | EO | 2 | 4 | F | 4 |

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
| OUT.A16 | Lecture tolérante des images, cohérence des fichiers (extents, blocs), blocs libres écrits, comparaison de deux images | `mkdisk.py` | 3 |
| OUT.A17 | Scénarios d'enregistrement : disquettes remplies, RESET balayé (fenêtre d'écriture, puis trame par trame) | `test_fichiers.py` | 3 |

## 7. Mesures

<!-- mesures:debut -->
| Composant | Fichiers | Code | Commentaires | Vides | Générées | % comment. | Octets produits | Code / PF | Octets / PF |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Système et commandes | 63 | 11 142 | 1 181 | 534 | 865 | 10 % | 36 933 | 35 | 115 |
| EDIT | 4 | 3 648 | 198 | 129 | 5 | 5 % | 8 704 | 49 | 118 |
| GRAPHER + GRXASM | 8 | 12 944 | 933 | 426 | 0 | 7 % | 32 642 | 57 | 143 |
| LOGO | 4 | 8 696 | 553 | 287 | 16 | 6 % | 18 960 | 45 | 98 |
| CMDER | 1 | 5 992 | 294 | 181 | 0 | 5 % | 13 581 | 105 | 238 |
| HEX | 3 | 1 621 | 96 | 63 | 0 | 6 % | 3 840 | 85 | 202 |
| VOIR | 5 | 1 476 | 172 | 64 | 0 | 10 % | 3 353 | 78 | 176 |
| USB | 12 | 1 350 | 153 | 74 | 0 | 10 % | 4 479 | 54 | 179 |
| ASM | 4 | 2 489 | 130 | 78 | 70 | 5 % | 6 130 | 277 | 681 |
| DEBUG | 3 | 2 426 | 129 | 87 | 0 | 5 % | 6 490 | 32 | 87 |
| Exemples | 28 | 892 | 56 | 30 | 0 | 6 % | 244 | 8 | 2 |
| Outillage PC | 160 | 6 576 | 702 | 398 | 0 | 10 % | — | 39 | — |
| **Total** | 295 | 59 252 | 4 597 | 2 351 | 956 | 7 % | 135 356 | 46 | 104 |

Octets du système : code résident 13 922 (`$C000-$F662`), page `$FF00` 240, chargeur d'amorçage 768 ; le reste : les commandes `.COM` du système. Exemples : HELLO et GTEST seulement (les `.GRX` et `.LOG` sont interprétés) ; données binaires des exemples (`.ANI`, `.HIZ`, `.SPR`, `.GIF`) : 71 559 octets.

| Composant | Documentation (lignes) | Aide de HELP (entrées) | Doc / PF | Commits |
|---|---:|---:|---:|---:|
| Système et commandes | 1 218 | 76 | 3,8 | 83 |
| EDIT | 93 | 20 | 1,3 | 12 |
| GRAPHER + GRXASM | 848 | 69 | 3,7 | 32 |
| LOGO | 273 | 63 | 1,4 | 19 |
| CMDER | 169 | 24 | 3,0 | 10 |
| HEX | 34 | 9 | 1,8 | 3 |
| VOIR | 78 | — | 4,1 | 9 |
| USB | 38 | 9 | 1,5 | 6 |
| ASM | 58 | 10 | 6,4 | 5 |
| DEBUG | 40 | 12 | 0,5 | 2 |
| Exemples | 0 | — | 0,0 | 18 |
| Outillage PC | 323 | — | 1,9 | 98 |
| Transverse (projet) | 1 766 | — | — | 41 |
| Traduction anglaise (docs/en) | 2 236 | — | — | 10 |
| **Total** | 7 174 | 292 | 5,5 | 156 |

Lignes de documentation : lignes non vides de `docs/*.md` (`manuel.md` réparti par section), `README.md`, `CLAUDE.md` ; aide de HELP : entrées de `tools/gen_readme_txt.py`. Un commit compte pour chaque composant qu'il touche (la colonne ne s'additionne pas).

Historique : 156 commits du 2026-10-04 au 2026-10-20.

Réutilisation : 44 938 lignes de code écrites dans `progs/`, 50 197 lignes assemblées dans les `.COM` (bibliothèques incluses comptées dans chaque programme qui les inclut) : taux 1,12 (sans compter les bibliothèques que GRXASM recopie dans les programmes traduits).
<!-- mesures:fin -->

## 8. Qualité

Défauts connus : `docs/etat.md` § 5 ; points à vérifier : `docs/essais-materiel.md`
(« À vérifier », une puce = un point).

| Composant | Défauts connus | Manques notés | À vérifier sur le matériel |
|---|---:|---:|---:|
| Système et commandes | 2 | 0 | 11 |
| EDIT | 0 | 0 | 2 |
| GRAPHER + GRXASM | 1 | 1 | 17 |
| LOGO | 1 | 0 | 7 |
| CMDER | 0 | 0 | 1 |
| HEX | 0 | 0 | 2 |
| VOIR | 0 | 0 | 1 |
| USB | 1 | 0 | 1 |
| ASM | 1 | 0 | 1 |
| DEBUG | 0 | 0 | 1 |
| Outillage | 0 | 0 | 1 |
| **Total** | **6** | **1** | **45** |

Effacent l'ancien fichier avant d'écrire (disque plein ou RESET : ancien perdu) :
- Système et commandes : `GSAVE` (BDOS 115 op 12), COPY sur un fichier existant ;
- GRAPHER : `GSAVE` (`h_save`) ; manque : savoir si un fichier existe sans le charger ;
- LOGO : `SAUVE` ; USB : IMPORT sur un fichier existant ; ASM : `.COM`, `.SYM`.

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
| 2026-10-19 | tuiles | 0.9 | 1 278 | 305 | 1 583 | 142 | tuiles de GRAPHER (`TILESET`, `TMAP`, `TILE`, `TFONT`), `mkspr.py`, CARTE en tuiles |
| 2026-10-19 | fichiers sûrs | 0.9 | 1 292 | 311 | 1 603 | 150 | `mkdisk.py check`, `diff`, `repare` ; `test_fichiers.py` ; SAVE/BSAVE par `NOM.$$$` ; EDIT Enregistrer sous ; RESET différé pendant un secteur |
| 2026-10-19 | deux disquettes | 0.9 | 1 296 | 311 | 1 607 | 152 | `cpa-projet.dsk` ; ASM et GRXASM cherchent les `.INC` sur A: à D: ; GRXASM et GRAPHER `/C` ; ASM `/S`, `/E` ; EDIT : texte tronqué jamais enregistré sous son nom |
| 2026-10-19 | anglais (1) | 0.9 | 1 296 | 311 | 1 607 | 155 | messages en deux langues (`progs/msg`), `cpa-en.dsk`, commandes traduites |

## 11. Comparaisons

### 11.1 CP/M 2.2

CP/M 2.2 (Digital Research, 1979-1980), compté avec les mêmes règles (§ 2) d'après ses sources
d'origine et son manuel. Correspondance : le système de CP/M (BDOS, CCP, BIOS type) et ses
utilitaires (STAT, PIP, SUBMIT, XSUB, DUMP, SYSGEN, MOVCPM) en face du système de CP/A et de
ses commandes ; ED en face d'EDIT ; ASM et LOAD en face d'ASM ; DDT en face de DEBUG. CP/M n'a
ni graphisme, ni son, ni langage, ni gestionnaire de fichiers : le reste de CP/A n'a pas
d'équivalent.

<!-- comparaison:debut -->
| Domaine | CP/A PF | CP/A algo. | CP/A total | CP/M 2.2 PF | CP/M algo. | CP/M total | CP/A / CP/M |
|---|---:|---:|---:|---:|---:|---:|---:|
| Système, commandes, utilitaires de fichiers | 322 | 68 | 390 | 261 | 41 | 302 | 1,3 |
| Éditeur (EDIT / ED) | 74 | 18 | 92 | 71 | 9 | 80 | 1,1 |
| Assembleur (ASM / ASM et LOAD) | 9 | 12 | 21 | 13 | 13 | 26 | 0,8 |
| Débogueur (DEBUG / DDT) | 75 | 13 | 88 | 51 | 15 | 66 | 1,3 |
| **Total** | **480** | **111** | **591** | **396** | **78** | **474** | **1,2** |
<!-- comparaison:fin -->

| Domaine | CP/A lignes | CP/M lignes | CP/A octets | CP/M octets |
|---|---:|---:|---:|---:|
| Système et utilitaires | 11 053 (6502) | 5 255 (8080) + 2 134 (PL/M) | 36 311 | 21 706 |
| Éditeur | 3 313 | 1 127 (PL/M) | 8 192 | 6 563 |
| Assembleur | 2 392 | 2 788 (8080) + 255 (PL/M) | 5 949 | 9 921 |
| Débogueur | 2 378 | 2 170 (8080) | 6 496 | 4 864 |

Lignes de code sans commentaires ni lignes vides. CCP et BDOS : version reformatée à une
instruction par ligne (l'original en met plusieurs, séparées par `!`) ; BIOS : le BIOS type
de Digital Research (`CBIOS`, `DEBLOCK`, `DISKDEF`, amorçage), que chaque constructeur
réécrivait. PL/M : langage évolué, une ligne vaut plusieurs instructions. Octets CP/M : CCP
2 Ko, BDOS 3,5 Ko, `.COM` des utilitaires, sans le BIOS (propre à chaque machine) ni MOVCPM
(9,5 Ko, qui contient une image du système).

Lecture :

- Le système de CP/A rend environ 1,2 fois les points de fonction de celui de CP/M (1,3 avec
  les algorithmes) : graphisme et son (fonctions 115, 116), menus, couleurs, complétion,
  historique, scripts imbriqués, formatage et copie de disquettes avec un seul lecteur.
  CP/M a ce que CP/A n'a pas : zones utilisateur, périphériques logiques (IOBYTE,
  `STAT DEV:`), PIP vers les périphériques, XSUB, et six fonctions du BDOS (27, 28, 29, 31,
  37, 40).
- Densité : 34 lignes de 6502 par PF pour le système de CP/A, 28 lignes (8080 et PL/M) pour
  CP/M ; 113 octets par PF contre 83, mais CP/A compte son pilote de disque, que CP/M laisse
  au BIOS de chaque constructeur, et le 6502 n'a que trois registres de 8 bits.
- EDIT est un éditeur plein écran, ED un éditeur ligne à ligne : nombre de fonctions voisin,
  mais l'essentiel d'EDIT est dans l'affichage (algorithmes).
- DDT a ce que DEBUG n'a pas (mini-assembleur, remplir, déplacer, chargement à un décalage) ;
  DEBUG a les symboles et des points d'arrêt permanents.

**CP/M 2.2 : système et utilitaires**

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| CPM.D01 | Fichiers des lecteurs A: à P: (répertoire, extents, attributs, 16 zones utilisateur) | ILF | 3 | 26 | M | 10 |
| CPM.D02 | Réglages de la session (IOBYTE, lecteur courant, zone utilisateur, disques protégés) | ILF | 1 | 6 | F | 7 |
| CPM.D03 | File d'attente `$$$.SUB` (écrite par SUBMIT, lue par le CCP) | ILF | 1 | 2 | F | 7 |
| CPM.D04 | Fichiers `.SUB` (écrits par ED) | EIF | 1 | 3 | F | 5 |
| CPM.D05 | Image du système (pistes système, fichier de MOVCPM) | ILF | 1 | 3 | F | 7 |
| CPM.T01 | DIR | EQ | 1 | 4 | F | 3 |
| CPM.T02 | ERA (`ALL (Y/N)?`) | EI | 1 | 3 | F | 3 |
| CPM.T03 | REN | EI | 1 | 3 | F | 3 |
| CPM.T04 | SAVE | EI | 1 | 3 | F | 3 |
| CPM.T05 | TYPE | EQ | 1 | 2 | F | 3 |
| CPM.T06 | USER n | EI | 1 | 1 | F | 3 |
| CPM.T07 | `d:` : changer de lecteur | EI | 2 | 2 | F | 3 |
| CPM.T08 | Lancer un programme | EI | 2 | 3 | F | 3 |
| CPM.T09 | Exécuter la file `$$$.SUB` | EI | 2 | 3 | F | 3 |
| CPM.T10 | Démarrage à chaud (CTRL-C, fonction 0, WBOOT) | EI | 2 | 2 | F | 3 |
| CPM.T11 | Démarrage à froid (BOOT) | EI | 2 | 2 | F | 3 |
| CPM.T12 | CTRL-P : copie sur l'imprimante | EI | 1 | 1 | F | 3 |
| CPM.T20 | 0 réinitialisation (= CPM.T10) | — | — | — | — | 0 |
| CPM.T21 | 1 lecture console avec écho | EQ | 1 | 2 | F | 3 |
| CPM.T22 | 2 écriture console (tabulations, CTRL-S, CTRL-P) | EO | 1 | 2 | F | 4 |
| CPM.T23 | 3 lecteur auxiliaire | EQ | 1 | 1 | F | 3 |
| CPM.T24 | 4 perforateur | EO | 1 | 1 | F | 4 |
| CPM.T25 | 5 imprimante | EO | 1 | 1 | F | 4 |
| CPM.T26 | 6 entrée-sortie directe | EQ | 0 | 2 | F | 3 |
| CPM.T27 | 7 lire l'IOBYTE | EQ | 1 | 1 | F | 3 |
| CPM.T28 | 8 fixer l'IOBYTE | EI | 1 | 1 | F | 3 |
| CPM.T29 | 9 afficher une chaîne | EO | 1 | 2 | F | 4 |
| CPM.T30 | 10 lecture d'une ligne (CTRL-E, R, U, X, H) | EI | 1 | 4 | F | 3 |
| CPM.T31 | 11 état de la console | EQ | 0 | 1 | F | 3 |
| CPM.T32 | 12 version | EQ | 0 | 1 | F | 3 |
| CPM.T33 | 13 réinitialisation des disques | EI | 1 | 1 | F | 3 |
| CPM.T34 | 14 choisir le lecteur courant | EI | 2 | 2 | F | 3 |
| CPM.T35 | 15 ouvrir | EQ | 1 | 6 | F | 3 |
| CPM.T36 | 16 fermer | EI | 1 | 4 | F | 3 |
| CPM.T37 | 17, 18 chercher le premier, le suivant | EQ | 1 | 8 | F | 3 |
| CPM.T38 | 19 effacer | EI | 1 | 3 | F | 3 |
| CPM.T39 | 20 lecture séquentielle | EQ | 1 | 4 | F | 3 |
| CPM.T40 | 21 écriture séquentielle | EI | 1 | 4 | F | 3 |
| CPM.T41 | 22 créer | EI | 1 | 3 | F | 3 |
| CPM.T42 | 23 renommer | EI | 1 | 3 | F | 3 |
| CPM.T43 | 24 lecteurs lus | EQ | 1 | 1 | F | 3 |
| CPM.T44 | 25 lecteur courant | EQ | 1 | 1 | F | 3 |
| CPM.T45 | 26 adresse DMA (réglage) | — | — | — | — | 0 |
| CPM.T46 | 27 vecteur d'allocation | EQ | 1 | 1 | F | 3 |
| CPM.T47 | 28 protéger un disque | EI | 1 | 1 | F | 3 |
| CPM.T48 | 29 vecteur des disques protégés | EQ | 1 | 1 | F | 3 |
| CPM.T49 | 30 attributs | EI | 1 | 3 | F | 3 |
| CPM.T50 | 31 paramètres du disque | EQ | 1 | 10 | F | 3 |
| CPM.T51 | 32 zone utilisateur (lire, fixer) | EI | 1 | 1 | F | 3 |
| CPM.T52 | 33 lecture directe | EQ | 1 | 4 | F | 3 |
| CPM.T53 | 34 écriture directe | EI | 1 | 4 | F | 3 |
| CPM.T54 | 35 taille d'un fichier | EO | 1 | 3 | F | 4 |
| CPM.T55 | 36 position directe d'après la séquentielle | EO | 1 | 3 | F | 4 |
| CPM.T56 | 37 réinitialiser des lecteurs | EI | 1 | 1 | F | 3 |
| CPM.T57 | 40 écriture directe avec remplissage | EI | 1 | 4 | F | 3 |
| CPM.T60 | CONST (= fonction 11) | — | — | — | — | 0 |
| CPM.T61 | CONIN | EQ | 1 | 1 | F | 3 |
| CPM.T62 | CONOUT | EO | 1 | 1 | F | 4 |
| CPM.T63 | LIST, PUNCH, READER (= fonctions 5, 4, 3) | — | — | — | — | 0 |
| CPM.T64 | SELDSK (rend les tables du disque) | EQ | 1 | 2 | F | 3 |
| CPM.T65 | Lire un secteur | EQ | 1 | 4 | F | 3 |
| CPM.T66 | Écrire un secteur | EI | 1 | 4 | F | 3 |
| CPM.T67 | LISTST : état de l'imprimante | EQ | 0 | 1 | F | 3 |
| CPM.T68 | BOOT, WBOOT, SECTRAN, HOME, SETTRK, SETSEC, SETDMA (comptés ou réglages) | — | — | — | — | 0 |
| CPM.T80 | STAT : place libre | EO | 1 | 4 | F | 4 |
| CPM.T81 | STAT afn : tailles (enregistrements, Ko, extents, attributs) | EO | 1 | 8 | F | 4 |
| CPM.T82 | STAT afn `$R/O` `$R/W` `$SYS` `$DIR` | EI | 1 | 3 | F | 3 |
| CPM.T83 | STAT `d:=R/O` | EI | 1 | 2 | F | 3 |
| CPM.T84 | STAT `DSK:` : paramètres des disques | EQ | 1 | 10 | F | 3 |
| CPM.T85 | STAT `USR:` : zones utilisées | EQ | 1 | 2 | F | 3 |
| CPM.T86 | STAT `DEV:`, `VAL:` : affectations, aide | EQ | 1 | 4 | F | 3 |
| CPM.T87 | STAT `CON:=TTY:`... : affecter un périphérique | EI | 1 | 2 | F | 3 |
| CPM.T88 | PIP : copier (jokers ; options V E O N T U L Z F P Q S G R W D H I) | EI | 2 | 18 | É | 6 |
| CPM.T89 | PIP : concaténer | EI | 2 | 6 | M | 4 |
| CPM.T90 | PIP : périphériques (CON: LST: PUN: RDR: NUL: EOF: PRN:) | EI | 2 | 6 | M | 4 |
| CPM.T91 | SUBMIT : écrire la file `$$$.SUB` (`$1`-`$9`, `^x`) | EI | 2 | 4 | F | 3 |
| CPM.T92 | XSUB : entrée des programmes lue dans la file | EI | 1 | 2 | F | 3 |
| CPM.T93 | DUMP : fichier en hexa | EQ | 1 | 2 | F | 3 |
| CPM.T94 | SYSGEN : copier le système (disque ou fichier) | EI | 1 | 3 | F | 3 |
| CPM.T95 | MOVCPM : système pour une autre taille de mémoire | EO | 1 | 2 | F | 4 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| CPM.A01 | Système de fichiers (allocation par carte de bits, extents, accès direct) | BDOS | 5 |
| CPM.A02 | Changement de disquette reconnu (somme de contrôle du répertoire) | BDOS | 3 |
| CPM.A03 | Console : tabulations, CTRL-S, CTRL-P, édition de ligne | BDOS | 3 |
| CPM.A04 | Erreurs (Bad Sector, Select, R/O), zones utilisateur | BDOS | 1 |
| CPM.A05 | Noms en FCB, jokers, commandes internes | CCP | 1 |
| CPM.A06 | File `$$$.SUB` lue par le dernier enregistrement | CCP | 1 |
| CPM.A07 | Dégroupage des secteurs physiques | `DEBLOCK` | 3 |
| CPM.A08 | Tables des disques produites par macros | `DISKDEF` | 3 |
| CPM.A09 | Chargeur d'amorçage | `BOOT` | 1 |
| CPM.A10 | Place libre, tailles, affectations de l'IOBYTE | STAT | 3 |
| CPM.A11 | Copie avec filtres et options (extraction Q/S, tabulations, numéros, pages, Intel HEX) | PIP | 5 |
| CPM.A12 | Concaténation, périphériques, vérification | PIP | 3 |
| CPM.A13 | Remplacement de `$1`-`$9`, lignes écrites à l'envers | SUBMIT | 1 |
| CPM.A14 | Fonction 10 détournée, résident sous le CCP | XSUB | 3 |
| CPM.A15 | Copie des pistes système | SYSGEN | 1 |
| CPM.A16 | Relogement par carte de bits | MOVCPM | 3 |
| CPM.A17 | Vidage hexa | DUMP | 1 |

**CP/M 2.2 : ED**

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| CPMED.D01 | Fichier édité (tampon, fichier temporaire, `.BAK`) | ILF | 1 | 3 | F | 7 |
| CPMED.D02 | Bloc transféré (X, R) | ILF | 1 | 1 | F | 7 |
| CPMED.D03 | Bibliothèques `.LIB` (R) | EIF | 1 | 2 | F | 5 |
| CPMED.T01 | A : ajouter des lignes au tampon | EI | 2 | 2 | F | 3 |
| CPMED.T02 | W : écrire des lignes | EI | 2 | 2 | F | 3 |
| CPMED.T03 | E : fin (enregistre, `.BAK`) | EI | 1 | 1 | F | 3 |
| CPMED.T04 | H : enregistrer et reprendre | EI | 1 | 1 | F | 3 |
| CPMED.T05 | O : abandonner les modifications | EI | 1 | 1 | F | 3 |
| CPMED.T06 | Q : quitter sans rien changer | EI | 1 | 1 | F | 3 |
| CPMED.T07 | I : insérer | EI | 1 | 2 | F | 3 |
| CPMED.T08 | D, K : effacer des caractères, des lignes | EI | 1 | 2 | F | 3 |
| CPMED.T09 | T, P : afficher des lignes, une page | EQ | 1 | 2 | F | 3 |
| CPMED.T10 | F, N : chercher (N : au-delà du tampon) | EQ | 2 | 2 | F | 3 |
| CPMED.T11 | S : substituer | EI | 1 | 3 | F | 3 |
| CPMED.T12 | J : juxtaposer | EI | 1 | 3 | F | 3 |
| CPMED.T13 | X : transférer vers le bloc | EI | 2 | 2 | F | 3 |
| CPMED.T14 | R : lire une bibliothèque ou le bloc | EI | 3 | 2 | M | 4 |
| CPMED.T15 | M : macro (répéter des commandes) | EI | 1 | 2 | F | 3 |
| CPMED.T16 | U : majuscules oui/non | EI | 0 | 1 | F | 3 |
| CPMED.T17 | V : numéros de ligne oui/non | EI | 0 | 1 | F | 3 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| CPMED.A01 | Tampon de lignes avec va-et-vient sur disque (A, W, fichier temporaire, `.BAK`) | ED | 5 |
| CPMED.A02 | Recherche, substitution, juxtaposition | ED | 1 |
| CPMED.A03 | Macros, bibliothèques, transfert | ED | 3 |

**CP/M 2.2 : ASM et LOAD**

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| CPMASM.D01 | Source `.ASM` | EIF | 1 | 3 | F | 5 |
| CPMASM.T01 | ASM : `.HEX` et `.PRN` (lecteurs choisis) | EO | 1 | 6 | F | 4 |
| CPMASM.T02 | LOAD : `.HEX` en `.COM` | EO | 1 | 3 | F | 4 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| CPMASM.A01 | Assembleur 8080 en deux passes | ASM | 5 |
| CPMASM.A02 | Expressions (opérateurs, priorités) | ASM | 3 |
| CPMASM.A03 | Table des symboles par hachage | ASM | 3 |
| CPMASM.A04 | Sortie Intel HEX et listing | ASM | 1 |
| CPMASM.A05 | Lecture Intel HEX (sommes de contrôle) | LOAD | 1 |

**CP/M 2.2 : DDT**

| Id | Fonction | Type | RET/FTR | DET | Cplx | PF |
|---|---|---|---:|---:|---|---:|
| CPMDDT.D01 | Programme en mémoire | ILF | 1 | 3 | F | 7 |
| CPMDDT.D02 | Registres | ILF | 1 | 12 | F | 7 |
| CPMDDT.T01 | I, R : charger un fichier `.HEX` ou `.COM` (décalage) | EI | 1 | 3 | F | 3 |
| CPMDDT.T02 | D : mémoire | EQ | 1 | 3 | F | 3 |
| CPMDDT.T03 | F : remplir | EI | 1 | 3 | F | 3 |
| CPMDDT.T04 | M : déplacer | EI | 1 | 3 | F | 3 |
| CPMDDT.T05 | S : modifier la mémoire octet par octet | EI | 1 | 2 | F | 3 |
| CPMDDT.T06 | A : assembler une ligne | EI | 1 | 3 | F | 3 |
| CPMDDT.T07 | L : désassembler | EO | 1 | 3 | F | 4 |
| CPMDDT.T08 | G : exécuter (deux points d'arrêt) | EI | 2 | 3 | F | 3 |
| CPMDDT.T09 | T : pas à pas avec trace | EI | 2 | 3 | F | 3 |
| CPMDDT.T10 | U : pas à pas sans trace | EI | 2 | 3 | F | 3 |
| CPMDDT.T11 | X : registres | EQ | 1 | 12 | F | 3 |
| CPMDDT.T12 | X r : modifier un registre | EI | 1 | 2 | F | 3 |

| Id | Algorithme | Où | Points |
|---|---|---|---:|
| CPMDDT.A01 | Désassembleur 8080 | DDT | 3 |
| CPMDDT.A02 | Mini-assembleur | DDT | 3 |
| CPMDDT.A03 | Pas à pas et points d'arrêt par RST 7, trace | DDT | 5 |
| CPMDDT.A04 | Relogement de DDT sous le BDOS | DDT | 3 |
| CPMDDT.A05 | Lecture Intel HEX avec décalage | DDT | 1 |

### 11.2 Applications de CP/M qui manquent à CP/A

Ce qu'on achetait avec CP/M (l'Osborne 1 était livré avec WordStar, SuperCalc, dBASE II,
MBASIC, CBASIC et un programme de communication), et les utilitaires du domaine public
qu'on disait indispensables. Place d'après la règle de `docs/architecture.md` : tout est en
`.COM`.

| Application de CP/M | Rôle | Dans CP/A | Ce qui manque |
|---|---|---|---|
| WordStar, MailMerge, Spellguard | traitement de texte | EDIT (édition, impression mise en page) | mise en forme à l'impression (gras, souligné, en-têtes, numéros de page, justification), publipostage, orthographe |
| SuperCalc, Multiplan | tableur | — | tout ; les décimaux de LOGO (`fp_inc.s`) servent tels quels |
| dBASE II | base de données | fichiers de données de GRAPHER | une base simple sur l'accès direct (déjà notée, `docs/etat.md` § 2.6) |
| MBASIC, CBASIC | BASIC avec décimaux et fichiers | LOGO (décimaux), GRAPHER (fichiers) | pas de BASIC sous CP/A : le pont va dans l'autre sens, vers le BASIC de l'Oric (`docs/oric-basic.md`) |
| Turbo Pascal, BDS C | langage compilé avec éditeur | GRAPHER : interprété pour la mise au point, traduit en assembleur par GRXASM pour la vitesse ; ASM | peu de chose : les phases d'un jeu, les tuiles (`docs/grapher.md` § 16, § 17) |
| MODEM7, Kermit, XMODEM | communication | — | prévu : `XFER.COM`, `TERM.COM` (`docs/etat.md` § 2.4) |
| NSWEEP, SD | gestion des fichiers | CMDER, DIR, STAT | rien |
| UNERA | récupérer un fichier effacé | — | tout (le répertoire garde les entrées effacées, comme CP/M) |
| FINDBAD | repérer les secteurs défectueux | relecture de FORMAT et de DISKCOPY `/V` | verrouiller les blocs défectueux |
| SQ, USQ, LU, NULU, CRUNCH | compression, archives `.LBR` | décompression LZSS (HELP, `.HIZ`) | un compresseur sur l'Oric, un format d'archive |
| MAC, RMAC, LINK-80 | assembleur à macros, éditeur de liens | ASM | macros, assemblage conditionnel, modules |
| Adventure, Zork (Infocom) | jeux d'aventure | — | un interpréteur de jeux (machine Z) ouvrirait tout le catalogue Infocom |
| (CP/M lui-même) | zones utilisateur, IOBYTE, XSUB, PIP vers les périphériques | — | voir § 11.1 |

Le traitement de texte, le tableur et la base de données ne sont pas le but de CP/A : EDIT
reste un éditeur (de programmes, de scripts, de données). Le manque qui compte est du côté
de la création (dessin assisté, éditeur de sprites et de caractères), du développement sur
l'Oric et des échanges avec l'extérieur.
