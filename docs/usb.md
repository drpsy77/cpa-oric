# La clé USB et le LOCI depuis CP/A — spécification

Le but : ne plus repasser par le menu du LOCI (ni par son gestionnaire de fichiers) pour
travailler. Depuis CP/A, on parcourt tous les supports du LOCI, on monte une disquette ou une
cassette, on duplique et on renomme une image ou un fichier, on retrouve ce qui est monté.

Deux niveaux :

- **Niveau 1** (ce document) : les fichiers de la clé restent hors du monde de l'Oric. On les
  liste, on les copie dans les deux sens, on les monte, on les duplique, on les renomme ; on
  ne les ouvre pas directement dans EDIT. Des `.COM` seulement : rien de résident, contrat
  d'interface intact.
- **Niveau 2** (plus tard, § 6) : un répertoire de la clé monté comme un lecteur, dont les
  fichiers se comportent comme ceux d'une disquette.

## 1. Fait

- EXPORT, IMPORT, USBDIR (`docs/manuel.md`) et la colonne USB de CMDER (`docs/cmder.md`) :
  copie dans les deux sens, liste d'un répertoire, `0:` (mémoire interne du LOCI) accepté.
  Sans numéro de support, un nom désigne la première clé, à sa racine.
- La clé est une passerelle : lecture et copie ; ni effacement, ni renommage, ni montage.
- `progs/loci_inc.s` : appel de l'API du LOCI (ouvrir, lire, écrire, fermer, lister).
- Oricutron de test (`ORIC_LOCI`, `docs/atelier.md`) : un dossier du PC tient lieu de clé,
  son sous-dossier `int` de `0:` ; la configuration du menu en XRAM est imitée (`"LOCI"`,
  `mounts`).

## 2. Décidé, pas encore fait

### 2.1 Supports et chemins

- **Supports** : `0:` (mémoire interne, 15 Mo) et `n:`, un par appareil de stockage USB. Le
  numéro est l'adresse USB de l'appareil : il change selon la prise, le hub, les autres
  appareils (clavier, Pico W). Aucune commande ne suppose `1:`.
- **Le LOCI ne donne pas le nom de volume des clés.** Une clé est reconnue à sa
  **description** : taille, fabricant et modèle (`14.9 GB SanDisk Cruzer`).
- **Répertoire courant de CP/A**, propre à CP/A (indépendant de celui du menu du LOCI) et
  gardé après un redémarrage : fichier `0:CPA.CWD` (le chemin, puis la description du
  support), lu par chaque commande USB, écrit par USBCD (et par CMDER en sortant, § 4).
  Jamais écrit : la racine de la première clé, comme aujourd'hui.
- **Support renuméroté** : si le support noté n'a plus la même description (ou n'existe
  plus), la commande cherche celui qui l'a et corrige le numéro (`Cle trouvee en 4:`) ;
  sinon `Cle absente : SanDisk Cruzer`, et le répertoire courant revient à la racine de la
  première clé.
- **Chemins** dans toutes les commandes USB (USBCD, USBDIR, IMPORT, EXPORT, USBMOUNT,
  CMDER) :

| Écrit | Désigne |
|---|---|
| `nom`, `rep/nom` | relatif au répertoire courant |
| `/rep/nom` | depuis la racine du support courant |
| `2:/rep/nom`, `0:nom` | sur ce support |
| `..` | le répertoire parent |

  Pour qui n'a jamais fait de `USBCD`, rien ne change (répertoire courant = racine de la
  première clé). Chemin complet de 127 caractères au plus (`Chemin trop long`). Noms longs :
  affichés coupés (`~`), relus en entier sur la clé pour l'ouverture (comme CMDER).

### 2.2 USBCD : changer de répertoire

    USBCD rep/sous-rep     direct ; aussi .., /, 2:, 0:
    USBCD                  liste à parcourir
    USBCD JE               liste des répertoires qui commencent par JE ; un seul : direct

En direct, le nouveau répertoire s'affiche :

    A>USBCD JEUX/ORIC
    2:/JEUX/ORIC
    A>USBCD ..
    2:/JEUX
    A>USBCD 0:
    0:

**Liste** (plein écran, comme CMDER ; retour au prompt sur un écran effacé) :

```
 0 |                                   a|
 1 |USB 2:/JEUX                          |
 2 |14.9 GB SanDisk Cruzer               |
 3 |  ..                                 |
 4 |> ORIC                         <REP> |
 5 |  ARCADE                       <REP> |
 6 |  PUZZLE-ET-REFLEXION~         <REP> |
   ...
25 |3 repertoires                        |
26 |                                     |
27 |RET entrer ESC choisir ^C annuler    |
```

- Répertoires seulement, triés par nom ; `..` en tête (sauf au-dessus des supports).
  Flèches, pages (← →), première lettre comme dans CMDER.
- RETURN sur un répertoire : y entrer ; sur `..` : remonter. ESC : le répertoire affiché
  devient le répertoire courant ; `^C` : rien ne change.
- **Au-dessus des racines**, `..` à la racine d'un support : la liste des supports, celui en
  cours marqué `*` :

```
 1 |USB : supports                       |
 3 |> 0: memoire du LOCI          15 Mo  |
 4 |  2: SanDisk Cruzer         14.9 Go *|
 5 |  4: Kingston DT             7.5 Go  |
```

- Messages : `Introuvable : ARCAD`, `Pas un repertoire`, `LOCI absent : cle USB
  inaccessible` (celui d'aujourd'hui), `Erreur USB n : ...` (idem).

### 2.3 Catalogue des supports : USBDIR /S

    A>USBDIR /S
    0: memoire du LOCI          15 Mo
    2: SanDisk Cruzer         14.9 Go *
    4: Kingston DT             7.5 Go

Seuls les supports de stockage (pas le clavier, ni la Pico W). `*` : le support du
répertoire courant. **USBDIR** sans paramètre liste le répertoire courant, dont il écrit
d'abord le chemin (`2:/JEUX/ORIC`).

### 2.4 USBMOUNT : disquettes

    USBMOUNT               ce qui est monté
    USBMOUNT B:            chemin complet de l'image de B:
    USBMOUNT B: JEU.DSK    monte JEU.DSK en B: (C:, D:)
    USBMOUNT B: JE         liste des .DSK qui commencent par JE ; un seul : direct
    USBMOUNT B: *          liste de tous les .DSK du répertoire courant
    USBMOUNT B: /E         éjecte

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
  disquette (`Pas une image de disquette` : signature `MFM_DISK` vérifiée).
- Après un montage ou une éjection : écritures en attente faites, disques réinitialisés
  (fonction 13 du BDOS), comme après un changement de disquette et un CTRL-C.
- La liste : même écran que USBCD, avec les répertoires et les `.DSK` ; RETURN sur un
  `.DSK` le monte, sur un répertoire y entre (sans changer le répertoire courant).

### 2.5 USBMOUNT : cassette

    USBMOUNT JEU.TAP       monte la cassette (K7:)
    USBMOUNT JEU.TAP /B    puis quitte CP/A pour le BASIC 1.1 et charge la cassette
    USBMOUNT K7: /E        éjecte la cassette

    A>USBMOUNT JEUCOUL.TAP /B
    K7: jeucoul.tap
    Quitter CP/A pour le BASIC (O/N) ?

- `/B` : démarrage du LOCI en BASIC 1.1, cassette en service, chargement automatique
  (`CLOAD""` sans rien taper). Les disquettes restent montées pour un retour à CP/A par le
  menu du LOCI.
- Ferme la boucle : `GRXASM JEU /O`, puis `USBMOUNT JEU.TAP /B` (le `.TAP` est sur A: à D:
  ou sur la clé ; sur une disquette, USBMOUNT ne peut pas le monter : il faut d'abord
  l'exporter, `Exporter d'abord : EXPORT JEU.TAP`).

### 2.6 CMDER

- La colonne USB s'ouvre dans le répertoire courant (`CMDER USB:`) ; en sortant, le dernier
  répertoire affiché devient le répertoire courant.
- `..` à la racine d'un support : la liste des supports (comme USBCD).
- **Renommer** (`^N`) sur la clé : un fichier ; refusé pour une image montée (`Image montee
  en B:`).
- **Dupliquer** (nouvel article du menu Fichier) : copie dans le même répertoire de la clé,
  nom proposé d'après l'original (dernier chiffre augmenté, sinon `1` ajouté :
  `PROJETS.DSK` → `PROJETS1.DSK`, `JEU2.TAP` → `JEU3.TAP`) ; progression `Copie : 132/525
  Ko`, ESC arrête. La copie s'écrit sous un nom provisoire, renommé à la fin ; un arrêt
  efface ce provisoire (seul effacement sur la clé).
- **Monter** (nouvel article) sur un `.DSK` (`Monter en : B:`) ou un `.TAP` (cassette) :
  comme USBMOUNT.
- **Nom de la disquette** de chaque lecteur : plein écran, dans l'en-tête (`A: cpa.dsk
  *.*  22/40 fic 126K libre`, nom coupé à 12) ; en deux colonnes, à la place du filtre
  quand il n'y en a pas (`B:projets~   112K`).
- Copier et Déplacer vers la clé, Voir, `?` : comme aujourd'hui. Effacer reste refusé sur la
  clé.

### 2.7 Mise en œuvre

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
  répertoire courant est celui de CP/A, § 2.1).
- `opendir` d'un chemin vide liste les appareils : `0: Internal storage [15MB]`, puis
  `n: MSC 14.9 GB` + fabricant (8) + modèle (16) + révision pour un stockage ; les autres
  appareils (clavier, Pico W) ont d'autres textes et sont sautés.
- `readdir` rend le nom court FAT au-delà de la longueur maximale d'un nom.
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
- Code commun dans `loci_inc.s` (chemins, `0:CPA.CWD`, supports, XRAM) et une liste à
  parcourir commune à USBCD, USBMOUNT (et le code de CMDER) ; tous les messages en
  37 colonnes, sans accents.
- Oricutron de test : `mount` change la disquette insérée (lecteurs B: à D:) et la
  configuration en XRAM ; plusieurs clés (sous-dossiers du dossier `ORIC_LOCI`, numéros
  choisis par le test, descriptions inventées) ; `boot` ne s'imite pas (essai sur le vrai
  Oric).

## 3. Lots

| Lot | Contenu | Essais | Place (estimée large) |
|---|---|---|---|
| 1 | **Répertoire courant et supports** : chemins (§ 2.1), `0:CPA.CWD`, support renuméroté ; USBCD ; `USBDIR /S` ; USBDIR, IMPORT, EXPORT relatifs au répertoire courant | Oricutron : deux clés, renumérotation, `0:` ; matériel : clé et Pico W changées de prise | USBCD 2 à 2,5 Ko ; EXPORT, IMPORT, USBDIR : +0,5 à 1 Ko chacun (un bloc de plus chacun, probable) |
| 2 | **USBMOUNT, disquettes** : ce qui est monté, `USBMOUNT B:`, montage, éjection, liste, refus (A:, déjà montée, pas une image) | Oricutron : montage, écriture puis relecture sur l'image montée ; matériel : menu du LOCI ouvert ensuite, mêmes noms | 2 à 3 Ko |
| 3 | **USBMOUNT, cassette** : montage, éjection, `/B` | matériel surtout (`boot`) : `GRXASM JEU /O`, `EXPORT`, `USBMOUNT JEU.TAP /B` | +0,5 Ko |
| 4 | **CMDER** : répertoire courant partagé, supports, Renommer, Dupliquer, Monter, noms des disquettes | Oricutron, puis matériel | +1,5 à 2,5 Ko (un ou deux blocs) |

Chaque lot se livre seul (règles de livraison habituelles) et sert dès sa sortie. Le lot 1
est le socle des autres.

## 4. Questions ouvertes

- **Effacer sur la clé**, au niveau 1 (aujourd'hui refusé partout, sauf le provisoire de
  Dupliquer) : le permettre, dans CMDER seulement, avec confirmation ?
- **`/B`** : demander confirmation (maquette ci-dessus) ou partir tout de suite (la commande
  dit déjà ce qu'elle va faire) ?
- **CMDER** : en sortant, le répertoire USB affiché devient-il le répertoire courant
  (proposé) ?
- **Dupliquer** : raccourci (`^D` s'il est libre partout) et règle du nom proposé.

## 5. Ce que ce niveau ne fait pas

- Ouvrir directement un fichier de la clé dans EDIT, GRAPHER... : il faut l'importer
  (niveau 2).
- La complétion des noms de la clé par ESC au prompt : elle est résidente et ne lit que les
  disquettes ; la lui ajouter demanderait l'API du LOCI dans le système (12 octets de
  marge). Les listes de USBCD et USBMOUNT en tiennent lieu.
- Copier un répertoire entier, créer un répertoire (`$83` existe : plus tard si besoin).

## 6. Plus tard : niveau 2

Un répertoire de la clé monté comme lecteur B:, C: ou D: (à la place d'une image) : ses
fichiers en 8 + 3 se comportent comme ceux d'une disquette (EDIT, GRAPHER, COPY, DIR...).
Un pilote dans le BDOS envoie toutes les fonctions de fichiers de ce lecteur vers l'API du
LOCI ; ni attributs, ni table d'allocation (place libre fictive ; FORMAT, DISKCOPY et les
accès directs aux secteurs refusés). Place résidente estimée 1,5 à 2 Ko, quand le système a
12 octets de marge : après la descente de PUT en banque (`docs/etat.md` § 3), ou le pilote
lui-même en banque. L'effacement y est nécessaire (EDIT enregistre par `NOM.$$$`,
effacement, renommage). Touche le système, pas les numéros du BDOS ; profiterait aussi à la
version ROM.
