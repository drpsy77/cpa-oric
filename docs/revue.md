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
- **Disquette changée sans CTRL-C** (`docs/systeme.md` § 3). La carte des blocs libres de
  l'ancienne disquette servait sur la nouvelle : dans Oricutron, `PUT X.TXT DIR` après un
  échange de `cpa.dsk` contre `cpa-exemples.dsk` prenait un bloc d'`ARDOISE.GRX`. Comme
  CP/M : une somme par secteur du répertoire, vérifiée avant de prendre ou de rendre des
  blocs quand une seconde s'est passée sans accès disque ; différente, le lecteur est relu.
  Le format et le contrat ne changent pas. Coût : 331 octets résidents (marge 184), 16
  secteurs relus à la première écriture après une pause.
- **`tools/test_fs.py`** : le système de fichiers dans un 6502 simulé, sans émulateur (fin
  de fichier, ajout après la fin, position, taille ; disquette changée : création,
  allongement, pause sans changement).

## 2. Décidé, pas encore fait

Par ordre. Chaque lot se termine par les tests de `architecture.md` § 4.

### Lot 1 — sûreté des fichiers

- **Accès direct** : la fonction 33 (et la 20 quand elle passe à l'extent suivant) change
  d'extent sans ranger l'actuel ; un bloc alloué juste avant par la fonction 34 ou 21 est
  perdu. Aucun programme ne s'en sert encore ; à corriger avant le sélecteur d'EDIT
  (`etat.md` § 2 point 6). Piste : un bit « FCB modifié » (posé à l'allocation d'un bloc et
  quand RC grandit, effacé par l'ouverture et la fermeture) ; un changement d'extent ne
  ferme que si le bit est posé (une lecture seule n'écrit jamais le répertoire).
- **Écritures qui effacent d'abord l'ancien fichier** (`etat.md` § 2 point 5) : `h_save`,
  SAVE du CCP, LOGO, COPY, IMPORT, ASM, à passer par `NOM.$$$`.
- Chercher dans `progs/` les programmes qui lisent jusqu'à la fin puis écrivent (ajout en
  fin de fichier) : ils étaient exposés au défaut du § 1.

### Lot 2 — version ROM archivée

Décidé : la version ROM n'a plus de sens. Les commandes majeures sont des `.COM` (EDIT,
GRAPHER, LOGO) qui ne tiendraient pas en ROM, et un programme qui tourne sur un Oric seul se
fait par `GRXASM /O` et `.TAP`.

- Retirer des sources le code de la ROM (environ 70 directives `#ifdef DISK`, `#ifndef
  DISK`, `#else` dans dix fichiers de `src/`) ; `-DDISK` disparaît de `build.sh`. Le
  système produit doit rester identique octet par octet.
- Retirer `build/cpa.rom` et ses lignes de `.gitignore`, `build.sh`, `smoke_test.sh`,
  `run_test.sh` (`ORIC_ROM=cpa`).
- Documents : `projet-rom.md` retiré ; `architecture.md` (deux projets, colonne « Version
  ROM », « les deux versions », § 4), `vision.md` (question ouverte fermée), `README`,
  `CLAUDE.md`, en-tête de `src/cpa.s` (page zéro libre `$00-$DF`, fin du code `$F5C8`).
- Le contrat reste ce qu'il est : il n'est plus « partagé avec la ROM », il est ce que les
  programmes `.COM` déjà écrits attendent.

### Lot 3 — documents à jour

- **`etat.md` scindé** : il fait 55 Ko, avec des dates et du récit, contre sa propre règle
  (`architecture.md` § 7). Garder l'état (court), la suite prévue et les réserves de place ;
  le récit des lots faits est dans git et dans les références des programmes.
- **Liste de la 1.0** en tête de la suite prévue, d'après `vision.md` : dessin assisté (à
  spécifier), son de GRAPHER, phases d'un jeu (`RUN`), `CASSETTE.COM`, un jeu complet (le
  rogue-like comme fil conducteur), vérification sur le matériel. Ce qui n'y est pas attend.
- Chiffres périmés de `etat.md`, à reprendre de `build/` : HELP (13 029 en français,
  12 850 en anglais ; le § 3 les inverse), REMOTE (2 127), place libre de GRAPHER (257),
  tailles anglaises du § 2 point 7 (GRAPHER 18 104, GRXASM 17 013, CMDER 17 859 : 9
  blocs), ASM du point 8 (7 322 : déjà 4 blocs), place libre des disquettes (`cpa.dsk`
  358 Ko, anim 318, exemples 324, logo 510, notes 558).
- `docs/en/` contient dix documents : les cinq d'utilisation, suivis par
  `tools/check_en.py`, et cinq internes (architecture, vision, usb, console-distance,
  loci-modem-wifi), annoncés par `README.md` mais pas suivis, alors que `etat.md` § 2
  point 7 dit les documents internes en français seulement. Les ajouter à `check_en.py` et
  corriger `etat.md` ; `README.fr.md` ne cite que les cinq premiers.
- **`essais-materiel.md` trié** : environ 35 rubriques attendent le vrai Oric, arrêté.
  Séparer ce qui exige le matériel (timing du disque et du LOCI, son, couleurs, vidéo par
  ligne) de ce qu'un émulateur couvre.

### Lot 4 — dépôt et intégration continue

- Dépôt : 579 Mo d'objets git non compactés pour 10,6 Mo utiles, un verrou resté
  (`.git/stale-maintenance-lock-claude`), un `REBASE_HEAD` : `git gc` après vérification.
  `build/` garde de vieux fichiers ignorés (patchs, archives, disquettes de 42 pistes).
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

- La marge du système est de 184 octets après le lot de sûreté : quelle piste de place
  ouvrir en premier (`etat.md` § 3 : code répété, autre banque de la fenêtre) ?
