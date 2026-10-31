# Étude : place sur les disquettes et formats de stockage

Spécification de travail. Elle rassemble les mesures, les contraintes et les pistes de la
place sur les disquettes. Elle prolonge le point 9 de `docs/etat.md` (« Orientation LOCI du
stockage » : la cible est l'Oric Atmos muni d'un LOCI ; la place doit venir aussi du lecteur
« fichiers USB », pas de disquettes 3 pouces rentabilisées), qu'il faut relire avec elle.

## Fait : piste A, 2 faces de 80 pistes

Le format des disquettes est celui de la piste A, sans changer la taille des blocs
(`docs/systeme.md` § 3, `docs/architecture.md` § 2 « Disquette ») :

- 2 faces x 80 pistes x 17 secteurs de 256 octets (2 720 secteurs, image MFM_DISK de 1 Mo,
  géométrie 1 comme avant) ; amorçage et système aux mêmes secteurs (LSN 0-66).
- Blocs de 2 Ko gardés, numéros sur 16 bits : c'est le cas de CP/M 2.2 au-delà de 255 blocs
  (EXM = 0 : une entrée = 8 blocs = un extent de 16 Ko). 331 blocs, 658 Ko pour les
  fichiers (336 avant).
- Répertoire gardé à 128 entrées (CMDER, la complétion et les outils comptent sur 128 au
  plus), dont l'entrée 0 pour l'**étiquette du format** (octet 0 = `$20` comme l'étiquette de
  CP/M 3, puis `CPA-2X80-2K`) : le système refuse une disquette sans étiquette (ancien
  format, autre système) au lieu de la lire de travers, puis de l'abîmer.
- Les anciennes disquettes (42 pistes) ne sont ni lues ni écrites par le système : la
  conversion se fait sur le PC (`tools/mkdisk.py conv`), où sont les images du LOCI. Aucun
  code résident pour deux formats.
- Prix : cartes d'allocation de 4 x 42 octets, sorties de `$FD00` (trop petit) et posées
  sous les tampons de DO (`$F5C8`) : la limite du code résident passe de `$F670` à `$F5C8` ;
  le BDOS grandit de 40 octets. Marge du code résident : 380 octets (588 avant).
- Le LOCI lit le nombre de pistes dans l'en-tête de l'image (`loci-firmware`,
  `src/mia/oric/dsk.c` : `dsk_mount_fat`, `dsk_set_active_track`), sans limite propre ;
  Oricutron accepte jusqu'à 128 pistes. Le LOCI n'agrandit pas une image : FORMAT ne fait
  pas 80 pistes d'une image de 42.
- Écarté : les blocs de 1 Ko avec des numéros sur 16 bits (piste B) : une entrée de 8 blocs
  ne couvrirait que 8 Ko, moins qu'un extent ; ce n'est plus le format de CP/M 2.2 (qui
  l'interdit) et tout le système de fichiers serait à revoir pour 12 à 34 Ko par disquette.

## Ce qui était (mesuré sur le coffret de 42 pistes)

- Géométrie : 2 faces x 42 pistes x 17 secteurs de 256 octets = 357 Ko ; système en LSN
  3-67 (~16 Ko) ; répertoire = blocs 0 et 1 (128 entrées de 32 octets) ; 170 blocs de 2 Ko,
  numéros de bloc sur un octet ; 336 Ko pour les fichiers.
- Coffret par usage (`docs/manuel.md`) : chaque disquette démarre seule et porte ses outils.
  Place libre : Système 86 Ko, Animations 44, Logo 200, Exemples 50, Notes 248, Projet 336 ;
  en 80 pistes : 408, 366, 522, 372, 570 et 658 Ko.
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
- Conclusion des mesures : le plafond venait d'abord de la géométrie (336 Ko), ensuite des
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
- LOCI, Cumulus : lisent des images, sans limite mécanique ; le LOCI prend le nombre de
  pistes de l'en-tête de l'image, Oricutron jusqu'à 128 (ci-dessus) ; Clock Signal : non
  vérifié.

## Pistes restantes

- **A. Format étendu 80 pistes** : fait (ci-dessus), sans blocs de 1 Ko ni descripteur de
  plusieurs formats (une étiquette, un seul format).
- **B. Blocs de 1 Ko** : écartée (ci-dessus).
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
  un Gotek, un HxC ou un lecteur 3,5″ double face (80 pistes : la géométrie des disquettes
  de CP/A), les disquettes actuelles sans les programmes du
  LOCI (EXPORT, IMPORT, USBDIR, USBMOUNT, USBCD, TERM, XFER : 22 Ko de plus par disquette)
  suffiraient sans doute, mais rien n'y a été essayé. Laissé à qui le demandera (note de
  `README.md`).

## Distribution envisagée (si deux formats coexistaient)

Un dossier de livraison hors de `build/`, symétrique langue x format, les mêmes 6
disquettes dans chacun, noms actuels gardés (pas de collision sur une même clé USB) :

```
disquettes/
  LISEZMOI.TXT   quel dossier choisir
  fr/  en/       80 pistes : LOCI, Cumulus, lecteur 3,5"
  42pistes/fr/  42pistes/en/   42 pistes : format actuel
```

Sans objet : un seul format existe (80 pistes), les images restent dans `build/`.

## Freins et coûts relevés

- Contrat : STAT, DIR, CMDER, DISKCOPY calculent la place d'après les constantes du format
  (`D_NBLK` de `progs/cpa.inc`) ; une fonction BDOS des paramètres du disque ne servirait
  que si plusieurs formats coexistaient. D touche le contrat (lecteur sans accès secteur).
- Travaux en parallèle : la descente de PUT touche `bios.s`, `cpa.s`, `hw.inc`.

## Questions ouvertes

- C vaut-il la place qu'il prend dans le CCP ?
- Ordre entre le lecteur U: (D) et la descente de PUT.
