# CP/A disquette — revue du projet

Revue des sources, des outils, des documents et des disquettes : ce qui a été constaté, ce
qui est corrigé, ce qui est décidé et reste à faire. À lire avec `docs/etat.md` ; une ligne
disparaît d'ici quand elle est faite et portée dans le document qui la concerne.

Étendue : `architecture.md`, `etat.md`, `vision.md`, `src/fs.s` et `src/bdos.s` lus en
entier, `src/bios.s` et `src/cpa.s` en partie, documents comparés aux fichiers de `build/`.
Pas encore relus : les sources des programmes (`progs/`, ~60 000 lignes), les outils
(`tools/`) ; les manuels ne l'ont été que pour la version ROM.

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
- **Documents à jour** : dernières mentions de la version ROM retirées (manuels, atelier,
  `memoire-pages-2-3.md`, `docs/en/architecture.md` aligné sur le français...) ;
  `docs/suite.md` réduit à ce qui reste à faire (18 Ko au lieu de 40 : ni dates ni récit,
  ce qui est fait est dans les références) ; les dix documents de `docs/en/` suivis par
  `tools/check_en.py` ; `docs/essais-materiel.md` trié en deux parties (A : ce qui exige
  le matériel, seule à compter pour la version 1.0 ; B : même logique que dans
  l'émulateur).
- **Intégration continue** (`docs/atelier.md` § 4) : à chaque envoi, GitHub construit CP/A,
  vérifie que les images du dépôt sont celles que donnent les sources, et lance les tests
  sans émulateur (34 min) ; les traductions sont vérifiées à chaque envoi de documents.
- **Disquettes hors du dépôt** : les `.dsk` sont retirés de tout l'historique (3,5 Mo au
  lieu de 385 ; avec eux `cpa.rom` et une application Clock Signal envoyée par erreur) et
  ne sont plus versionnés ; leurs sommes le sont (`build/disquettes.md5`). Les disquettes
  sont publiées par une version GitHub à l'envoi d'une étiquette (`docs/atelier.md` § 4).
  L'historique d'avant est gardé dans `archives/cpa-oric-avant-reecriture.bundle` (non
  versionné).
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

### Lot 4 — dépôt et intégration continue

- `build/` garde de vieux fichiers ignorés (patchs, archives, disquettes de 42 pistes).

### Lot 5 — optimisations

- **Aiguillage du BDOS** : un appel standard (chaque caractère affiché) passe quatre
  comparaisons (115, 116, 117, 47) avant sa table ; tester d'abord `BDOS_NFUNC` gagne une
  dizaine de cycles par appel, sans octet de plus.
- **ERA, REN, attributs** : le secteur du répertoire est réécrit à chaque entrée ; une
  écriture différée par secteur divise les accès (jusqu'à 8 entrées par secteur). À peser
  avec la fenêtre de RESET.
- `src/hw.inc` garde des noms de la version ROM qui ne servent plus (`dump_addr`, `cg_blk`,
  `cg_n`, `cg_i` : 10 octets de page 2 libres) : à retirer avec `memoire-pages-2-3.md`.
- Routines répétées dans les `.COM` (`puts` défini 17 fois) : à mesurer ; gain utile
  seulement s'il fait passer un programme sous un bloc de 2 Ko.

## 3. Questions ouvertes

Aucune.
