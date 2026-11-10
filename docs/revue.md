# CP/A disquette — revue du projet

Revue des sources, des outils, des documents et des disquettes : ce qui a été constaté, ce
qui est corrigé, ce qui est décidé et reste à faire. À lire avec `docs/etat.md` ; une ligne
disparaît d'ici quand elle est faite et portée dans le document qui la concerne.

Étendue : `architecture.md`, `etat.md`, `vision.md`, `src/fs.s` et `src/bdos.s` lus en
entier, `src/bios.s` et `src/cpa.s` en partie, documents comparés aux fichiers de `build/`.
Pas encore relus : les sources des programmes (`progs/`, ~60 000 lignes), les outils
(`tools/`), les manuels.

## 1. Fait

- **Lecture après la fin d'un fichier multiple de 16 Ko** (`src/fs.s`, fonction 20). La fin
  était rendue une fois, mais le FCB restait sur l'extent suivant, qui n'existe pas, avec
  les blocs de l'ancien : une deuxième lecture rendait de vieilles données, une écriture
  écrasait le début de l'extent précédent et la fermeture échouait. Le FCB reste maintenant
  à la fin du dernier extent : la fin est rendue à chaque lecture, une écriture ajoute un
  extent. La fonction 36 rend aussi la bonne position à la fin d'un extent plein (elle se
  trompait d'un enregistrement). Coût : 21 octets résidents.
- **Disquette changée sans CTRL-C** : option de construction `CHGDSK`, absente par défaut
  (`docs/systeme.md` § 3 ; sur un petit ordinateur, c'est à l'utilisateur de savoir ce
  qu'il fait : CTRL-C après un changement de disquette). Sans elle, la carte des blocs libres de
  l'ancienne disquette servait sur la nouvelle : dans Oricutron, `PUT X.TXT DIR` après un
  échange de `cpa.dsk` contre `cpa-exemples.dsk` prenait un bloc d'`ARDOISE.GRX`. Comme
  CP/M : une somme par secteur du répertoire, vérifiée avant de prendre ou de rendre des
  blocs quand une seconde s'est passée sans accès disque ; différente, le lecteur est relu.
  Le format et le contrat ne changent pas. Coût de l'option : 331 octets résidents (marge
  184 au lieu de 515), 37 ms à chaque lecture d'un lecteur, 16 secteurs relus à la première
  écriture après une pause.
- **`etat.md` scindé** : `etat.md` (10 Ko : état, liste de la version 1.0, contraintes),
  `suite.md` (suite prévue), `place.md` (réserves de place) ; chiffres de l'état et de la
  place repris de `build/`.
- **Version ROM abandonnée** : code retiré de `src/` (67 blocs `#ifdef DISK`, `#ifndef
  DISK`), `-DDISK` retiré de `build.sh`, `build/cpa.rom` et `docs/projet-rom.md` retirés ;
  les douze disquettes sont identiques octet par octet. `architecture.md`, `vision.md`,
  `README`, `CLAUDE.md`, `etat.md` mis à jour.
- **`tools/test_fs.py`** : le système de fichiers dans un 6502 simulé, sans émulateur (fin
  de fichier, ajout après la fin, position, taille ; disquette changée : création,
  allongement, pause sans changement).

## 2. Décidé, pas encore fait

Par ordre. Chaque lot se termine par les tests de `architecture.md` § 4. Tout ajout
résident est annoncé à Pierre (octets, temps) avant d'être codé.

### Lot 1 — sûreté des fichiers

- **Accès direct** : la fonction 33 (et la 20 quand elle passe à l'extent suivant) change
  d'extent sans ranger l'actuel ; un bloc neuf alloué juste avant par la fonction 34 ou 21
  est perdu. Aucun programme n'y est exposé : HEX écrit sur place (blocs existants, taille
  inchangée), CMDER, MKTAP et STAT ne font que lire, GRAPHER et LOGO n'ont pas d'accès
  direct. À corriger le jour où un programme allonge un fichier en accès direct, pas
  avant (environ 40 octets résidents). Piste : un bit « FCB modifié » (posé à l'allocation
  d'un bloc et quand RC grandit, effacé par l'ouverture et la fermeture) ; un changement
  d'extent ne ferme que si le bit est posé.
- **Écriture par `NOM.$$$`** : réservée à ce qui ne se refait pas. Elle demande la place du
  nouveau fichier en plus de l'ancien ; elle se justifie pour EDIT (et EDSPRITE, les
  tableaux de GRAPHER : faits), où un incident perd un travail. Pas ailleurs : ce que
  GRAPHER produit se rejoue (un langage de dessin et de jeux, pas un logiciel qui crée des
  données de l'utilisateur) ; COPY et IMPORT gardent leur source ; ASM a la sienne ; PUT
  part d'un fichier vide par définition. Une demande nouvelle se décide avec la vue
  d'ensemble.
- **LOGO, sauvegarde du travail** (à étudier, options à présenter avant tout code) : un
  fichier `.LOG` peut contenir des commandes directes ; l'édition depuis LOGO ne reprend
  que les procédures (`POUR`) et réécrit le fichier d'origine, qui perd ses commandes
  directes. Chercher une solution plus large pour garder le travail fait sous LOGO.
- **`SAVE n fichier` du CCP** (à réécrire, à spécifier) : elle enregistre toujours à partir
  de `$0500` (le `SAVE` de CP/M : faire un `.COM` de la mémoire), ce qui ne sert pas à
  l'utilisateur ; aucun script ni outil du dépôt ne s'en sert. Elle est dans la banque IMG
  de la fenêtre, pas dans le code résident.
- Ajout en fin de fichier : aucun programme ne le fait (tous ceux qui écrivent par la
  fonction 21 créent leur fichier par la 22 ; PUT crée le sien) ; le défaut du § 1 ne
  pouvait donc toucher qu'un programme écrit par l'utilisateur.

### Lot 3 — documents à jour

- Mentions de la version ROM encore à retirer : `architecture.md` (cellules des tableaux
  du § 1 et du § 2 : « ROM seulement », « en version disquette »), `docs/en/architecture.md`, `manuel.md` et
  `docs/en/manuel.md`, `atelier.md`, `grapher.md` (fr, en), `memoire-pages-2-3.md`,
  `points-de-fonction.md`, `suite.md` (point 8), `systeme.md`, `oric-basic.md`.
- `docs/suite.md` (40 Ko, issu de la scission d'`etat.md`) garde des dates et le récit des
  lots faits, contre `architecture.md` § 7 : à réduire point par point, en vérifiant que
  chaque « Fait » est décrit dans la référence du programme avant de le retirer.
- Chiffres périmés de `docs/suite.md` : tailles anglaises du point 7 (GRAPHER 18 104,
  GRXASM 17 013, CMDER 17 859 : 9 blocs), ASM du point 8 (7 322 : déjà 4 blocs).
- `docs/en/` contient dix documents : les cinq d'utilisation, suivis par
  `tools/check_en.py`, et cinq internes (architecture, vision, usb, console-distance,
  loci-modem-wifi), annoncés par `README.md` mais pas suivis, alors que `suite.md`
  point 7 dit les documents internes en français seulement. Les ajouter à `check_en.py` et
  corriger `suite.md` ; `README.fr.md` ne cite que les cinq premiers.
- **`essais-materiel.md` trié** : environ 35 rubriques attendent le vrai Oric, arrêté.
  Séparer ce qui exige le matériel (timing du disque et du LOCI, son, couleurs, vidéo par
  ligne) de ce qu'un émulateur couvre.

### Lot 4 — dépôt et intégration continue

- Dépôt : `git gc` fait (un seul paquet, `git fsck` sans défaut). L'historique pèse
  385 Mo : douze images de 1 Mo sont versionnées et changent à presque chaque commit
  (environ 280 commits). Question ouverte (§ 3). `build/` garde de vieux fichiers ignorés
  (patchs, archives, disquettes de 42 pistes), et `.git` un verrou resté
  (`stale-maintenance-lock-claude`) et un `REBASE_HEAD`.
- GitHub : les deux tâches ne construisent qu'Oricutron. En ajouter une qui lance
  `./build.sh` et les tests sans émulateur (`test_asm.sh`, `test_grapher.sh`, `test_fp.py`,
  `test_fs.py`, `test_fdc.py`, `test_bas.py`) à chaque envoi.

### Lot 5 — optimisations

- **Aiguillage du BDOS** : un appel standard (chaque caractère affiché) passe quatre
  comparaisons (115, 116, 117, 47) avant sa table ; tester d'abord `BDOS_NFUNC` gagne une
  dizaine de cycles par appel, sans octet de plus.
- **ERA, REN, attributs** : le secteur du répertoire est réécrit à chaque entrée ; une
  écriture différée par secteur divise les accès (jusqu'à 8 entrées par secteur). À peser
  avec la fenêtre de RESET.
- Routines répétées dans les `.COM` (`puts` défini 17 fois) : à mesurer ; gain utile
  seulement s'il fait passer un programme sous un bloc de 2 Ko.

## 3. Questions ouvertes

- Images `build/*.dsk` dans git : les garder versionnées (prêtes à l'emploi pour qui clone,
  mais ~12 Mo de plus par livraison), ou les publier comme fichiers d'une version GitHub
  (« release ») et ne plus les versionner ?
