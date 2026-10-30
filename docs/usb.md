# La clé USB et le LOCI depuis CP/A

Le but : ne plus repasser par le menu du LOCI (ni par son gestionnaire de fichiers) pour
travailler. Depuis CP/A, on parcourt tous les supports du LOCI, on monte une disquette ou une
cassette, on duplique, renomme ou efface une image ou un fichier, on retrouve ce qui est
monté.

Deux niveaux :

- **Niveau 1** (ce document) : les fichiers de la clé restent hors du monde de l'Oric. On les
  liste, on les copie dans les deux sens, on les monte, on les duplique, on les renomme, on
  les efface ; on ne les ouvre pas directement dans EDIT. Des `.COM` seulement : rien de
  résident, contrat d'interface intact.
- **Niveau 2** (plus tard, § 5) : un répertoire de la clé monté comme un lecteur, dont les
  fichiers se comportent comme ceux d'une disquette.

**Une seule manière de faire chaque chose.** CMDER est le seul écran interactif : on y
parcourt les supports et les répertoires, on y choisit, on y agit. Les commandes en ligne
(USBDIR, IMPORT, EXPORT, USBMOUNT) font une action directe, pour le prompt et les scripts,
sans liste à parcourir : un nom ambigu n'ouvre pas de choix, il est refusé avec la liste des
candidats. Le code commun (chemins, répertoire courant, supports, configuration du LOCI) est
écrit une fois, dans `progs/loci_inc.s`.

## 1. Fait

- EXPORT, IMPORT, USBDIR (`docs/manuel.md`) et la colonne USB de CMDER (`docs/cmder.md`) :
  copie dans les deux sens, liste d'un répertoire, `0:` (mémoire interne du LOCI).
- La clé est une passerelle : copie dans les deux sens, montage (USBMOUNT, CMDER) ;
  renommer, effacer, dupliquer dans CMDER seulement.
- `progs/loci_inc.s` : appel de l'API du LOCI (ouvrir, lire, écrire, fermer, lister),
  répertoire courant, chemins, supports ; `progs/ljok_inc.s` : jokers.
- Oricutron de test (`ORIC_LOCI`, `docs/atelier.md`) : un dossier du PC tient lieu de clé,
  son sous-dossier `int` de `0:`, ses sous-dossiers `usb1` à `usb8` de plusieurs clés
  (description dans `usbN.txt`, autres appareils dans `autres.txt`), liste des appareils ;
  la configuration du menu en XRAM est imitée (`"LOCI"`, `mounts`).

**Lot 1 : répertoire courant et supports.**

### 1.1 Supports et chemins

- **Supports** : `0:` (mémoire interne, 15 Mo) et `n:`, un par appareil de stockage USB. Le
  numéro est l'adresse USB de l'appareil : il change selon la prise, le hub, les autres
  appareils (clavier, Pico W). Aucune commande ne suppose `1:`.
- **Le LOCI ne donne pas le nom de volume des clés.** Une clé est reconnue à sa
  **description** : taille, fabricant et modèle (`14.9 GB SanDisk Cruzer`).
- **Répertoire courant de CP/A**, propre à CP/A (indépendant de celui du menu du LOCI) et
  gardé après un redémarrage : fichier `0:CPA.CWD` (le chemin, puis la description du
  support), lu par chaque commande USB, écrit par CMDER en sortant (§ 1.3), seulement s'il
  change. Jamais écrit : la racine de la première clé.
- **Support renuméroté** : si le support noté n'a plus la même description (ou n'existe
  plus), la commande cherche celui qui l'a et corrige le numéro (`Cle trouvee en 4:`) ;
  sinon `Cle absente : SanDisk Cruzer`, et la commande part de la racine de la première clé ;
  le fichier n'est pas réécrit (le répertoire noté revient avec la clé ; le message se
  répète à chaque commande jusque-là).
- **Chemins** dans toutes les commandes USB (USBDIR, IMPORT, EXPORT, USBMOUNT, CMDER) :

| Écrit | Désigne |
|---|---|
| `nom`, `rep/nom` | relatif au répertoire courant |
| `/rep/nom` | depuis la racine du support courant |
| `2:/rep/nom`, `0:nom` | sur ce support |
| `..` | le répertoire parent |

  Pour qui n'a jamais changé de répertoire, rien ne change (répertoire courant = racine de
  la première clé). `..` est résolu par CP/A (le menu du LOCI a son propre répertoire courant
  dans FatFs, dont CP/A ne dépend pas : tout chemin envoyé au LOCI est complet, `2:/...`).
  Chemin complet de 127 caractères au plus (`Chemin trop long`). Noms longs : affichés coupés
  (`~`), relus en entier sur la clé pour l'ouverture (comme CMDER).
- **Jokers** (`*`, `?`, casse ignorée ; `.*` final accepte aussi un nom sans point) dans le
  dernier élément d'un nom de la clé : `USBDIR *.DSK` filtre la liste ; IMPORT et USBMOUNT,
  qui attendent un seul fichier, prennent le seul qui répond, sinon les écrit (un par
  ligne, 8 au plus, puis `...`) et s'arrête : `Plusieurs fichiers : preciser` ; aucun :
  `Introuvable : JE*`.

### 1.2 Commandes en ligne

**USBDIR** :

    USBDIR [chemin]        liste un répertoire (sans chemin : le répertoire courant),
                           puis son chemin complet et le nombre d'éléments
                           (2:/JEUX/ORIC : 12 element(s) ; nombre à la ligne
                           si le chemin dépasse 20 caractères)
    USBDIR /S              catalogue des supports
    USBDIR /C [chemin]     le répertoire devient le répertoire courant, écrit en
                           retour ; sans chemin : CMDER USB: /R (par CHAIN) ;
                           c'est le script USBCD.BAT

    A>USBDIR /S
    0: memoire du LOCI          15 Mo
    2: SanDisk Cruzer Blade   14.9 Go *
    4: Kingston DataTraveler   7.5 Go

  Seuls les supports de stockage (pas le clavier, ni la Pico W) ; `*` : le support du
  répertoire courant.

**IMPORT, EXPORT** : les noms de la clé sont relatifs au répertoire courant ; IMPORT accepte
les jokers (un seul fichier). Fabricant et modèle viennent du texte du LOCI (`2: MSC 14.9 GB
SanDisk  Cruzer Blade    rev 1.00`), espaces réduits ; taille `GB` écrite `Go` en français.

### 1.3 CMDER

- **Répertoire courant** : la colonne USB s'ouvre dans le répertoire courant (`CMDER USB:`,
  ou `CMDER USB:rep` pour partir d'ailleurs) ; en sortant, le dernier répertoire USB affiché
  devient le répertoire courant. Changer de répertoire, c'est entrer dans CMDER, aller où
  l'on veut, quitter ; ou, en ligne, `USBCD rep` (§ 1.2, `USBDIR /C`).
- **Supports** : `..` à la racine d'un support montre la liste des supports (en-tête
  `USB:supports`), celui d'où l'on vient marqué `*`, le curseur dessus ; RETURN sur un
  support entre à sa racine ; rien ne s'y copie (`Choisir d'abord un support`) :

```
 1 |USB:supports         3 fic           |
 2 |  NOM+                        TAILLE |
 3 |  0: memoire du LOCI   15 Mo         |
 4 |  2: SanDisk Cruzer  14.9 Go *       |
 5 |  4: Kingston DataTra 7.5 Go         |
```

- **Répertoires seuls** : un filtre de plus (menu Vue, `Repertoires seuls`, par colonne ;
  `Cle USB seulement` sur une disquette ; option `/R` à l'appel) ne montre que `..` et les
  `<REP>` ; avec `CMDER USB:JEUX /R`, on parcourt l'arborescence sans les fichiers. Le
  script `USBCD.BAT` (une ligne, `USBDIR /C $1`, § 1.2) : `USBCD JEUX` change de
  répertoire sans écran et écrit le nouveau ; `USBCD` seul ouvre `CMDER USB: /R` (ESC : le
  répertoire affiché devient le répertoire courant). `USBCD.BAT` est sur toutes les
  disquettes, protégé (caché sur les disquettes par usage, comme les commandes de base).
- **Copier vers la clé** : `USB:rep` est relatif au répertoire de la colonne USB (sans elle,
  au répertoire courant de CP/A) ; `USB:` seul : ce répertoire-là.

**Lot 2 : USBMOUNT.**

### 1.4 USBMOUNT

    USBMOUNT               ce qui est monté
    USBMOUNT B:            chemin complet de l'image de B:
    USBMOUNT B: JEU.DSK    monte JEU.DSK en B: (C:, D:) ; JE*.DSK s'il n'y en a qu'un
    USBMOUNT B: /E         éjecte
    USBMOUNT JEU.TAP       monte la cassette (K7:)
    USBMOUNT JEU.TAP /B    puis quitte CP/A pour le BASIC 1.1 et charge la cassette
    USBMOUNT K7: /E        éjecte la cassette

    A>USBMOUNT
    A: cpa.dsk
    B: projets.dsk
    C: -
    D: jeux-fr.dsk
    K7: jeucoul.tap
    A>USBMOUNT B: PUZZLE.DSK
    B: puzzle.dsk

- Noms lus dans la configuration du menu du LOCI (32 caractères au plus) : ce que montre
  CP/A et ce que montre le menu sont toujours les mêmes, quel que soit celui qui a monté.
- **A: interdit** : `A: interdit (disquette systeme)`. Les `.COM` et le fichier de banques
  du système y sont lus.
- Refusés : une image déjà montée dans un autre lecteur (`Deja montee en C:` : deux
  écritures sur le même fichier l'abîmeraient) ; un fichier qui n'est pas une image de
  disquette (`Pas une disquette` : signature `MFM_DISK` vérifiée) ; un `.TAP`
  d'une disquette CP/A (`Exporter d'abord : EXPORT JEU.TAP`) ; une image de la mémoire
  interne (`Pas d'image sur 0:` : le firmware ne vérifie pas l'ouverture d'un fichier de
  `0:` avant de le lire ; un montage de `0:CPA-ANIM.DSK` a figé le LOCI, `mt_mount` de
  `lmnt_inc.s`, CMDER compris).
- Une cassette doit commencer par l'octet de synchronisation `$16` (`Pas une cassette
  (.TAP)`) ; un nom en `.DSK` sans lecteur : `Lecteur ? USBMOUNT B: nom.DSK`.
- Après un montage ou une éjection de disquette : écritures en attente faites, disques
  réinitialisés (fonction 13 du BDOS), comme après un changement de disquette et un CTRL-C.
  Pendant le changement, A: est le lecteur en service : un lecteur sans image ne reçoit
  jamais de commande (le contrôleur du LOCI se bloquerait). Le lecteur courant éjecté laisse
  la place à A:.
- Le nom gardé par le menu est celui de la clé (casse comprise), retrouvé dans le
  répertoire ; `USBMOUNT B:` écrit le répertoire de l'image (getcwd) suivi de ce nom.
- `/B` part tout de suite (pas de question) : démarrage du LOCI en BASIC 1.1, cassette en
  service, chargement automatique (`CLOAD""` sans rien taper). La configuration du menu est
  écrite d'abord comme il l'écrirait (FDC hors service, cassette, BASIC 1.1, chargement
  automatique ; le mode bit à bit gardé), puis l'opération `$A0` avec les drapeaux `$96`
  (`$9E` en mode bit à bit), interruptions du VIA coupées comme le fait le menu. Les
  disquettes restent montées pour un retour à CP/A par le menu du LOCI (FDC remis en
  service). Si le LOCI refuse : `Erreur USB n`, et l'on reste dans CP/A. Ferme la boucle : `GRXASM JEU /O`,
  `EXPORT JEU.TAP`, `USBMOUNT JEU.TAP /B`.

**Lot 3 : opérations de CMDER sur la clé.**

### 1.5 CMDER, opérations sur la clé

Renommer, Effacer (images montées sautées), Dupliquer (`^U`, nom provisoire `~CPADUP.TMP`
renommé à la fin), Monter (`^O`, le code de USBMOUNT : `lmnt_inc.s`), nom de la disquette de
chaque lecteur dans les en-têtes : détail dans `docs/cmder.md` (§ 6, « Clé USB »). Des
fichiers seulement (`Fichiers seulement`) ; les noms longs se saisissent en entier (63
caractères, la ligne défile).

## 2. Mise en œuvre

**API du LOCI** (firmware, `src/mia/main.c` pour la liste, `api/mnt.c`, `api/dir.c`,
`usb/msc.c`), en plus de ce que `loci_inc.s` appelle déjà :

| Opération | Effet |
|---|---|
| `$90` mount | A = lecteur (0-3), 4 cassette, 5 ROM ; chemin sur la pile d'échange ; FAT ou `0:` |
| `$91` umount | A = lecteur |
| `$88` getcwd | A = lecteur : le **répertoire** de l'image montée (jusqu'au dernier `/`), pas son nom |
| `$1A` lseek, `$1B` unlink, `$1C` rename, `$83` mkdir | comme en C |
| `$92`-`$94` | cassette : position, en-tête suivant |
| `$A0` boot | drapeaux : `$01` disquette, `$02` cassette, `$04` BASIC 1.1, `$10` chargement automatique, `$40` reprise, `$80` rapide |

- Pas de copie (dupliquer passe par l'Oric, par paquets de 512 octets) ; pas de chdir (le
  répertoire courant est celui de CP/A, § 1.1).
- `opendir` d'un chemin vide liste les appareils : `0: Internal storage [15MB]`, puis
  `n: MSC 14.9 GB` + fabricant (8) + modèle (16) + révision pour un stockage ; les autres
  appareils (clavier, Pico W) ont d'autres textes et sont sautés. Un firmware compilé
  sans les décimaux dans `printf` (la 0.3.98 de `tools/loci-acia-diag/`) écrit
  `n: MSC  GB General  UDisk` : `dv_next` retient tout texte qui commence par `MSC `, sauf
  `MSC mounted, inquiring` (clé pas encore prête) ; la taille affichée se réduit alors à
  l'unité.
- `readdir` rend le nom court FAT au-delà de la longueur maximale d'un nom.
- `open` sur `0:` (littlefs, `api/std.c`) : `O_TRUNC`, `O_APPEND` ou `O_EXCL` y remplacent
  `O_CREAT` au lieu de s'y ajouter ; `O_CREAT+O_TRUNC` ne crée donc pas un fichier absent
  (erreur 130, `LFS_ERR_NOENT`). `usb_open` ouvre d'abord avec `O_CREAT` seul, referme,
  puis rouvre avec `O_TRUNC`. L'Oricutron des tests reproduit ce comportement.
- **Configuration du menu du LOCI en XRAM** (`loci-rom`, `src/persist.h`, `persist.c`),
  lue et écrite par la fenêtre 1 (`$03A8-$03AB`) :

| XRAM | Contenu |
|---|---|
| `$8000` | `"LOCI"` |
| `$8004-$800A` | `fdc_on`, `tap_on`, `bit_on`, `mou_on`, `b11_on`, `ser_on`, `ald_on` |
| `$800B` | `mounts` : bits 0-3 lecteurs, 4 cassette, 5 ROM (lu par `loci_abs`, `src/disk.s`) |
| `$800C` | `tui_pos` |
| `$800D` | `path` : répertoire du menu (`1:/jeux`), 256 octets |
| `$810D` + 35 × n | `drv_names[n]` : nom seul de l'image (32 caractères au plus, vide si rien), n = 0-3 lecteurs, 4 cassette, 5 ROM |

- **Un montage par l'API n'écrit rien en XRAM** : c'est le menu qui tient `mounts` et
  `drv_names`. USBMOUNT et CMDER les écrivent comme lui ; sans le bit de `mounts`, CP/A
  refuserait le lecteur (`loci_abs`). Le répertoire de l'image se lit par `$88`.
- Code commun, par fichiers (ASM n'a pas d'assemblage conditionnel) : `loci_inc.s` (API,
  répertoire courant `cw_get` / `cw_write`, chemins `lpath`, supports `dv_open`,
  `dv_next`, `dv_parse`, `dv_fmt` : tous les programmes USB, ~1,7 Ko), `lcwp_inc.s`
  (`cw_put`, changer de répertoire : USBDIR, CMDER), `ljok_inc.s` (jokers
  `wmatch`, `lp_find`, `lp_findx` : USBDIR, IMPORT, USBMOUNT ; ~0,4 Ko), `lmnt_inc.s`
  (montage `mt_mount`, `mt_eject`, configuration du menu en XRAM, `mt_where`, `mt_head`,
  `mt_pre` / `mt_post` autour du BDOS : USBMOUNT, et CMDER au lot 3 ; ~0,8 Ko ; ses tampons
  sont placés par le programme après `loci_inc.s`). Messages en 37 colonnes, sans accents
  (`loci.msg`, `usbmount.msg`).
- Oricutron de test : `rename` ; `mount` change la disquette insérée (lecteurs 0 à 3 : l'image de la
  clé, réécrite à l'éjection si elle a changé), `umount`, `getcwd`, XRAM `$8000-$81FF`
  inscriptible (au départ : la configuration d'un menu qui aurait monté les disquettes
  insérées) ; `boot` ne démarre rien, il écrit ses drapeaux dans `boot.txt` et répond par une
  erreur (le démarrage s'essaie sur le vrai Oric).

## 3. Lots

| Lot | Contenu | Essais | Place (estimée large) |
|---|---|---|---|
| 1 | **Fait.** Répertoire courant et supports (§ 1) | Oricutron : deux clés, renumérotation, clé absente, `0:` ; matériel : `docs/essais-materiel.md` | CMDER +1 773 octets (8 blocs) ; USBDIR 2 810, IMPORT 3 443, EXPORT 3 055 (un bloc de plus chacun) |
| 2 | **Fait.** USBMOUNT (§ 1.4) | Oricutron : montage, écriture puis relecture sur l'image montée, éjection du lecteur courant, refus, cassette, drapeaux de `/B` ; matériel : `docs/essais-materiel.md` | USBMOUNT 4 086 octets (2 blocs) ; HELP passe à 7 blocs |
| 3 | **Fait.** CMDER, opérations sur la clé (§ 1.5) | Oricutron : renommer, effacer (image montée sautée), dupliquer (ESC compris), monter, en-têtes ; matériel : `docs/essais-materiel.md` | CMDER +2 535 octets (9 blocs) |

Les trois lots sont faits ; CMDER fait 17 889 octets (9 blocs, 543 octets libres).

## 4. Ce que ce niveau ne fait pas

- Ouvrir directement un fichier de la clé dans EDIT, GRAPHER... : il faut l'importer
  (niveau 2).
- La complétion des noms de la clé par ESC au prompt : elle est résidente et ne lit que les
  disquettes ; la lui ajouter demanderait l'API du LOCI dans le système (12 octets de
  marge). On choisit dans CMDER.
- Copier, effacer ou créer un répertoire entier (`$83` existe : plus tard si besoin).

## 5. Plus tard : niveau 2

Un répertoire de la clé monté comme lecteur B:, C: ou D: (à la place d'une image) : ses
fichiers en 8 + 3 se comportent comme ceux d'une disquette (EDIT, GRAPHER, COPY, DIR...).
Un pilote dans le BDOS envoie toutes les fonctions de fichiers de ce lecteur vers l'API du
LOCI ; ni attributs, ni table d'allocation (place libre fictive ; FORMAT, DISKCOPY et les
accès directs aux secteurs refusés). Place résidente estimée 1,5 à 2 Ko, quand le système a
12 octets de marge : après la descente de PUT en banque (`docs/etat.md` § 3), ou le pilote
lui-même en banque. L'effacement y sert (EDIT enregistre par `NOM.$$$`, effacement,
renommage). Touche le système, pas les numéros du BDOS ; profiterait aussi à la version
ROM.
