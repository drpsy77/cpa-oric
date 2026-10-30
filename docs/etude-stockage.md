# Étude : place sur les disquettes et formats de stockage

Spécification de travail, **rien n'est décidé**. Elle rassemble les mesures, les contraintes
et les pistes, pour qu'une conversation suivante les trie avec Pierre. Elle prolonge le
point 9 de `docs/etat.md` (« Orientation LOCI du stockage », décidé : la place doit venir
du lecteur « fichiers USB », pas de disquettes 3 pouces rentabilisées), qu'il faut relire
avec elle.

## Pour reprendre

1. Ne rien coder d'emblée. Rien n'est décidé, pas même le principe d'un nouveau format.
2. D'abord **faire le schéma de ce qui converge et de ce qui diverge** entre les pistes
   ci-dessous (A à E) et le point 9 d'`etat.md` : ce qu'elles partagent (code, format,
   arborescence de distribution), ce qu'elles rendent inutile, ce qui les oppose (public
   visé, contrat, matériel). Le présenter à Pierre, puis seulement proposer un ordre.
3. Les deux vérifications qui changent tout, avant de choisir : le LOCI lit-il une image de
   80 pistes (piste 79, face 2) ? Que permet l'interface fichiers du LOCI (pour le lecteur
   U: du point 9) ?

## Ce qui est (mesuré sur le coffret actuel)

- Géométrie : 2 faces x 42 pistes x 17 secteurs de 256 octets = 357 Ko ; système en LSN
  3-67 (~16 Ko) ; répertoire = blocs 0 et 1 (128 entrées de 32 octets) ; 170 blocs de 2 Ko
  (`hw.inc` : `BLK_SECT`, `NBLK`, `DIR_ENT`), numéros de bloc sur un octet ; 336 Ko pour les
  fichiers ; cartes d'allocation `ALV` en `$FD00` (4 lecteurs x 22 octets). Marge du code
  résident : 588 octets (`etat.md` § 1).
- Coffret par usage (`docs/manuel.md`) : chaque disquette démarre seule et porte ses outils.
  Place libre : Système 86 Ko, Animations 44, Logo 200, Exemples 50, Notes 248, Projet 336.
- Ce que coûte la granularité (place occupée par les fichiers, en Ko) :

| Disquette | Données réelles | Blocs de 2 Ko | 1 Ko | 512 octets | Au secteur (256) |
|---|---|---|---|---|---|
| Système | 210 | 250 | 227 | 218 | 213 |
| Animations | 253 | 292 | 270 | 260 | 255 |
| Logo | 104 | 136 | 115 | 110 | 106 |
| Exemples | 226 | 286 | 252 | 236 | 229 |
| Notes | 68 | 88 | 76 | 72 | 69 |

- Les commandes de base, la clé USB, TERM, XFER, CMDER, HELP, VOIR et EDIT.CFG, recopiés sur
  chaque disquette d'usage : 78 Ko en blocs (59 Ko réels). Dont TYPE, ERA, REN, SET, STAT,
  COPY, XDO, MEM, POKE, GO : ~8 Ko réels, 11 fichiers, ~22 Ko en blocs.
- Conclusion des mesures : le plafond vient d'abord de la géométrie (336 Ko), ensuite des
  doublons, en dernier de la taille des blocs.

## Contraintes matérielles

- Le contrôleur Microdisc (WD1793) ne fait que la double densité (250 kbit/s) : pas de
  1,44 Mo sur un vrai Oric. Une image « haute densité » pour le LOCI serait illisible par un
  vrai Microdisc.
- Lecteur 3″ d'origine du Microdisc (Hitachi HFD305S) : une seule face (on retourne la
  disquette), 40 pistes. Il ne lit pas le format de CP/A, qui change de face dès la piste
  logique 1, système compris (la lecture, `$80`, ne compare pas la face : il lirait la face
  0 à la place de la 1). Lecteur 3,5″ double densité : 80 pistes, lisible par le Microdisc
  (SEDORIC s'en sert). Une disquette de
  80 pistes est illisible par un lecteur 3″.
- LOCI, Cumulus : lisent des images, sans limite mécanique ; nombre de pistes accepté par
  le LOCI **non vérifié** (le firmware n'est plus dans `archives/`). Oricutron et Clock
  Signal : à vérifier aussi.

## Pistes (aucune choisie)

- **A. Format étendu 80 pistes** : 2 x 80 x 17 x 256 = 680 Ko (~660 utiles). Avec 340 blocs
  de 2 Ko, les numéros de bloc ne tiennent plus sur un octet : il faut de toute façon les
  passer sur 16 bits. Proposition associée : blocs de 1 Ko, numéros sur 16 bits, et un
  **descripteur de format** sur chaque disquette (géométrie, taille de bloc, taille du
  répertoire), lu à la première utilisation du lecteur, pour que 42 et 80 pistes et
  l'ancien format cohabitent. Public : LOCI, Cumulus, lecteurs 3,5″.
- **B. Blocs de 1 Ko sur 42 pistes** : 340 blocs, donc numéros sur 16 bits aussi ; gain de
  12 à 34 Ko par disquette. Même cœur que A, sans changer la géométrie.
- **C. Regrouper les petites commandes** en un fichier où le CCP les cherche : ~14 Ko de
  plus par disquette, sans toucher au format (touche le CCP, sa place).
- **D. Lecteur « fichiers USB » (U:)**, point 9 d'`etat.md` : les fichiers du BDOS passent
  par l'interface fichiers du LOCI ; place de la clé, fichiers lisibles sur le Mac. Touche
  le contrat (lecteur sans accès secteur). C'est la direction déjà retenue pour la place.
- **E. Lire les disquettes SEDORIC** (secteurs chaînés, granularité 256 octets) : projet
  d'échange à part, pas une réponse à la place.
- **F. Une version pour le Microdisc** : écartée. Le lecteur 3″ d'origine ne lit pas le
  format (ci-dessus) ; il faudrait une géométrie une face de 40 pistes (170 Ko, ~148 pour les
  fichiers : `NSIDES`, `NCYL` de `hw.inc`, `disk.s`, amorce, FORMAT, DISKCOPY, STAT et CMDER
  recompilés, coffret redécoupé, disquettes illisibles par la version LOCI). Pour le Cumulus,
  un Gotek, un HxC ou un lecteur double face, les disquettes actuelles sans les programmes du
  LOCI (EXPORT, IMPORT, USBDIR, USBMOUNT, USBCD, TERM, XFER : 22 Ko de plus par disquette)
  suffiraient sans doute, mais rien n'y a été essayé. Laissé à qui le demandera (note de
  `README.md`).

## Distribution envisagée (si deux formats existent)

Un dossier de livraison hors de `build/`, symétrique langue x format, les mêmes 6
disquettes dans chacun, noms actuels gardés (pas de collision sur une même clé USB) :

```
disquettes/
  LISEZMOI.TXT   quel dossier choisir
  fr/  en/       80 pistes : LOCI, Cumulus, lecteur 3,5"
  42pistes/fr/  42pistes/en/   42 pistes : format actuel
```

Sans objet tant qu'un seul format existe. À prévoir : liens des README, `.gitignore`, tests,
doc et `CLAUDE.md` qui citent `build/cpa.dsk` ; les liens publiés vers `build/*.dsk`
cesseraient de marcher.

## Freins et coûts relevés

- LOCI 80 pistes non vérifié (essai sur le matériel : une image d'essai et un petit
  programme qui lit la piste 79).
- Contrat : STAT, DIR, CMDER calculent la place en supposant des blocs de 2 Ko ; il faudrait
  une fonction BDOS des paramètres du disque (en fin de table, partagée avec la ROM :
  accord de Pierre avant tout code). D touche aussi le contrat.
- Mémoire : cartes d'allocation de 88 à ~340 octets pour 4 lecteurs en 80 pistes ; leur
  place est à trouver (le code, lui, tient dans la marge).
- Ampleur : `fs.s`, géométrie du BIOS, FORMAT, DISKCOPY, CMDER (copie à un lecteur, place),
  STAT, DIR, `mkdisk.py`, `test_fdc.py`, `test_fichiers.py`, doc ; étapes testées une à une
  (`mkdisk.py` d'abord, comme référence), sinon un défaut du système de fichiers se
  localise mal.
- Travaux en parallèle : la descente de PUT touche `bios.s`, `cpa.s`, `hw.inc`.

## Questions ouvertes

- Faut-il un nouveau format sur disquette, vu le point 9 (U:) ? Pour qui (LOCI, Cumulus,
  lecteur 3,5″) ?
- Si oui : A, B ou les deux ? Anciennes disquettes de 2 Ko lues et écrites, ou seulement
  lues (copie vers le nouveau format) ? Répertoire de 128 ou 256 entrées en 80 pistes ?
- C vaut-il la place qu'il prend dans le CCP ?
- Ordre entre ce sujet, le lecteur U: et la descente de PUT.
