# Essais sur le vrai matériel

Pierre essaie sur un Oric Atmos avec un LOCI. Ce document n'est pas à lire à chaque
conversation : seulement pour savoir quoi faire vérifier, ou pour noter un résultat. Une
livraison ajoute ses points à « À vérifier » ; un point vérifié passe dans « Vérifié ».

## À vérifier sur Oric Atmos + LOCI

Ce qui reste demande une mise en place exprès ou vise un cas limite que l'usage courant ne
rencontre pas.

**Disquettes de 80 pistes** (2 faces, images de 1 Mo ; `docs/systeme.md` § 3) :

- démarrage sur `cpa.dsk` et sur chaque disquette du coffret : le LOCI monte-t-il une image
  de 80 pistes, et le système se charge-t-il comme avant ? `DIR` : `408K free` sur `cpa.dsk` ;
- fin de la disquette : copier sur `cpa-projet.dsk` en B: un fichier de plus de 600 Ko (fait
  sur le PC : `mkdisk.py put`, ou par `COPY` de B: vers C:), puis `STAT B:*.*` (blocs,
  octets), relire le fichier (`COPY` vers C:, `mkdisk.py get` et comparer sur le Mac) : les
  pistes 42 à 79 et les blocs au-delà de 255 se lisent et s'écrivent ;
- ancienne disquette (42 pistes, une copie !) en B: : `B:` et `DIR B:` donnent `BDOS: not a
  CP/A 80-track disk`, sans rien écrire ; `CMDER B:` : `lecteur absent ou illisible` ;
- `FORMAT B:` sur une copie de `cpa-projet.dsk` : 80 pistes, `Formatage termine`, `DIR B:`
  vide avec `658K free` ; `FORMAT B: /Q` de même ;
- `FORMAT B:` sur une image de 42 pistes (copie d'une disquette SEDORIC) : arrêt à la piste
  42 avec `Image de 42 pistes ? Il en faut 80` (le LOCI n'agrandit pas l'image) ; rien
  d'autre n'est touché ;
- `DISKCOPY A: B:` et `DISKCOPY A: B: /T /V` vers une disquette formatée ; `DISKCOPY A: A:`
  avec un seul lecteur (7 échanges, 17 avec `/T`) ;
- CMDER à deux colonnes : place libre des en-têtes, `?` (blocs d'un gros fichier), copie qui
  ne tient pas (`Libre ...K, requis ...K`) ;
- vitesse : un accès vers la fin de la disquette (pistes 70-79) n'est pas plus lent qu'au
  début de façon visible.

**Coffret de disquettes** (une par usage ; `docs/manuel.md`, disquettes par usage ; chaque
disquette démarre seule, avec un seul lecteur) :

- `cpa.dsk` : `DIR` montre les applications et README.TXT, sans exemple ni LOGO ; `DIRS`
  montre aussi les commandes de base et les `.INC` ; `HELP LOGO` répond quand même ;
- `cpa-anim.dsk` : `DEMO` enchaîne l'image, les trois animations et `GRAPHER ANIMS` ;
- `cpa-logo.dsk` : `DIR` ne montre que LOGO, LOGOTR, EDIT et les `.LOG` ; `LOGO DEMO`, puis
  `DEMO` ;
- `cpa-exemples.dsk` seule : `GRAPHER CARTE`, puis `GRXASM SERPENT`, `ASM SERPENT`,
  `SERPENT` (la place suffit-elle ?) ; `ASM HELLO`, `HELLO` ;
- `cpa-notes.dsk` : écrire un texte dans EDIT, puis `EXPORT` vers la clé et `XFER` (cachés,
  présents) ;
- deux lecteurs : `cpa.dsk` en A:, `cpa-projet.dsk` en B:, `B:`, `GRAPHER` et `ASM` trouvés
  sur A: ;
- les mêmes sur les jumelles anglaises (`cpa-examples-en.dsk`...).

**Fenêtre : PUT et démarrage à froid** (`docs/systeme.md` § 6 ; sur une **copie** de
`cpa.dsk`, puis de `cpa-en.dsk`) :

- mise sous tension : `RAM test OK.` comme avant, durée du démarrage inchangée ;
- `AUTO.BAT` sur A: (fait dans EDIT), par exemple `USBMOUNT B: PROJET.DSK` puis `B:` : au
  démarrage, `A>AUTO`, le montage, puis `B>` ; `DIR B:` lit bien l'image montée ;
- le même, ESC tapé pendant le démarrage : `Script arrete.` ; bouton RESET ensuite : AUTO.BAT
  ne repart pas ; `GO C000` : démarrage sans test de RAM ni AUTO.BAT, puis `PUT L.TXT DIR`
  marche ;
- `PUT L.TXT DIR`, `PUT H.TXT HELP`, puis `TYPE` ; `PUT S.TXT TERM` avec le modem, quelques
  écrans (`ATI`, une page d'un serveur), CTRL-Q : `S.TXT` a toute la session ;
- disque presque plein (une copie remplie par `COPY`), `PUT T.TXT TYPE GRX.INC` : `Disk full`
  à la fin, `T.TXT` garde ce qui tenait.

**Police rangée sur 5 octets** (dépliée au démarrage ; identique octet par octet dans
Oricutron) : au démarrage, puis après un bouton RESET et après `GRAPHER` d'un `.GRX` en
HIRES plein écran (retour au texte) : texte de l'écran et des menus comme avant ; `SPLIT`,
`GTEXT 2 10 Bonjour` dans l'image.

**Fenêtre, lot 2 : banques de CPA.BNK** (`docs/systeme.md` § 6 ; sur une **copie** de
`cpa.dsk`, puis de `cpa-en.dsk`) :

- `SPLIT`, `GSAVE T` : dire combien de temps prend le premier (lecture de `CPA.BNK` sur le
  LOCI) et le suivant ; `TEXT`, `GLOAD T` : l'image revient ; `SAVE 4 S.BIN`, `DIR` ;
- puis `PUT L.TXT DIR` : PUT relu de `CPA.BNK` (un instant), `TYPE L.TXT` ;
- sous PUT, un programme qui fait GSAVE : `PUT L.TXT GRAPHER` d'un `.GRX` avec `SPLIT`, un
  `PRINT`, `GSAVE`, un `PRINT` : `L.TXT` a les deux textes, l'image est écrite ;
- `GSAVE T` deux fois de suite (remplacement), sur un `T.IMG` protégé (`SET T.IMG RO` :
  `File R/O`, l'ancienne image reste), et sur une disquette presque pleine (`Disk full`,
  l'ancienne reste) ;
- disquette sans `CPA.BNK` (`SET CPA.BNK RW`, `ERA CPA.BNK` sur la copie) : `GSAVE T` répond
  `CPA.BNK?`, `PUT L.TXT DIR` marche encore ;
- RESET pendant le premier `GSAVE` (pendant la lecture de `CPA.BNK`) : retour au prompt, puis
  `GSAVE T` et `PUT L.TXT DIR` marchent.

**Après la correction du pilote** (un contrôleur qui ne répond plus donne une erreur disque,
plus un accès déclaré bon : `docs/systeme.md` § 3), en français et en anglais, sur une
**copie** de disquette :

- RESET pendant `DISKCOPY A: D:` (D: une disquette vierge), plusieurs fois : noter l'adresse
  de `*RESET* at`, puis `DIR`, `DIR D:` : on doit voir `BDOS: disk I/O error` (au bout de
  ~6 s par accès) au lieu de `No file`. Dire ensuite si `DIR` sur A: remarche (au besoin
  après CTRL-C) ou seulement après le redémarrage du LOCI, et si le voyant du LOCI reste
  allumé. Un seul appui bref, puis un appui long : la différence dit si le bouton rebondit
  (cause supposée : une seconde NMI pendant le démarrage à chaud, `docs/etat.md` § 2
  point 5) ;
- RESET pendant un enregistrement : `EDIT` d'un texte de quelques Ko, une modification,
  CTRL-S puis RESET aussitôt, une dizaine de fois en variant l'instant ; de même `GRAPHER`
  avec un `SAVE` d'un gros tableau. Chaque fois : `DIR` marche, le fichier est l'ancien ou le
  nouveau, entier (`TYPE`), ou le nouveau dans `NOM.$$$` ; `ERA *.$$$` ensuite. Rapporter la
  disquette sur le PC : `python3 tools/mkdisk.py check` sans défaut.

**Après la correction d'EDIT** (le fichier est converti en le lisant : une fin de ligne
compte un octet en mémoire, deux sur le disque) : le même `ESSAI.INC` (CPA.INC et ARR.INC
insérés, enregistré à 32 761 octets) se rouvre sans `Fichier tronque`, en entier (fin du
texte à sa place) ; un fichier encore plus gros donne toujours le message ; un texte court
s'ouvre comme avant (sur `cpa.dsk` et `cpa-en.dsk`).

**Clé USB, lot 1 : répertoire courant et supports** (`docs/usb.md` § 1 ; sur `cpa.dsk`,
puis quelques commandes sur `cpa-en.dsk`) :

- `USBDIR /S` : `0: memoire du LOCI`, puis chaque clé avec son fabricant, son modèle et sa
  taille (comparer avec le menu du LOCI) ; ni le clavier ni la Pico W dans la liste ;
- `CMDER USB:` : `..` à la racine de la clé mène à `USB:supports`, curseur sur la clé ;
  entrer dans `0:` puis dans la clé, descendre dans un répertoire, ESC ; `USBDIR` écrit ce
  chemin et liste ce répertoire ; `EXPORT`, `IMPORT` d'un nom sans chemin y vont ;
- éteindre et rallumer l'Oric : `USBDIR` repart du même répertoire ; le menu du LOCI garde
  le sien (CP/A ne l'a pas changé) ;
- clé changée de prise (ou un hub, la Pico W branchée avant) pour que son numéro change :
  `USBDIR` dit `Cle trouvee en n:` une fois, puis plus rien ; clé retirée : `Cle absente :
  ...`, liste de la racine de l'autre clé (ou une erreur s'il n'y en a pas) ; clé remise :
  retour au répertoire noté ;
- chemins : `USBDIR ..`, `USBDIR /`, `USBDIR 2:/JEUX` (le numéro de sa clé), `USBDIR 0:`,
  `USBDIR *.DSK` ; `IMPORT DOCS/LET*.TXT /T` (un seul fichier), `IMPORT *.TXT` (plusieurs :
  la liste, `Plusieurs fichiers : preciser`) ;
- `USBCD JEUX` : CMDER dans `JEUX`, répertoires seuls (`3/12 fic`), ESC ; menu Vue,
  `Repertoires seuls` sur une colonne de disquette : `Cle USB seulement` ;
- CMDER deux colonnes `CMDER A: USB:` : `^C` vers `USB:DOCS` (relatif au répertoire de la
  colonne USB) ;
- durée : chaque commande USB lit `0:CPA.CWD` et la liste des appareils ; dire si cela se
  sent avant la liste de `USBDIR`.

**USBCD et USBDIR** (`docs/usb.md` § 1.2 ; sur `cpa.dsk`, puis `cpa-en.dsk`) :

- `USBCD files` : écrit `2:/FILES` (le numéro de la clé), sans ouvrir CMDER ; `USBDIR` :
  le contenu, puis `2:/FILES : n element(s)` ; éteindre et rallumer : `USBDIR` repart de
  `FILES` ;
- `USBCD ..`, `USBCD /`, `USBCD 0:` ; refus : `USBCD nexiste` et `USBCD fichier.txt`
  (`Erreur USB 37 : introuvable` dans Oricutron : noter le code du vrai LOCI) ;
- `USBCD` seul : CMDER sur la clé, répertoires seuls ; descendre, ESC : `USBDIR` liste ce
  répertoire ;
- avec le firmware 0.3.98 (clé décrite `MSC  GB`, sans taille) : `USBDIR /S` montre la clé
  (`1: General UDisk  Go *`), `USBCD files` écrit `1:/FILES` (avec le numéro) ;
- `0:CPA.CWD` absent au départ : `USBCD files` le crée (`USBDIR 0:` le montre), `USBDIR`
  liste `FILES` ; `USBCD ..` le réécrit ; `EXPORT README.TXT 0:NEW.TXT` (fichier absent de
  `0:`) : copié ; de même une copie vers `0:` dans CMDER ;
- `USBMOUNT B: 0:CPA-ANIM.DSK` : `Pas d'image sur 0:`, rien ne se fige ; de même `^O` dans
  CMDER sur une image de `0:` ;
- passer par le menu du LOCI (parcourir la clé), revenir à CP/A, `USBDIR` : pas de gel
  (constaté une fois avant la correction, avec un répertoire courant sans support) ;
- un chemin de plus de 20 caractères : le nombre d'éléments passe à la ligne.

**Clé USB, lot 2 : USBMOUNT** (`docs/usb.md` § 1.4 ; sur `cpa.dsk`, puis quelques
commandes sur `cpa-en.dsk`) :

- `USBMOUNT` : les mêmes noms que le menu du LOCI (A: à D:, K7:) ; `USBMOUNT B:` : le
  chemin complet de l'image ;
- `USBMOUNT C: un.dsk` (une image de travail, copie d'abord) : `DIR C:`, `COPY` d'un fichier
  dessus, `USBMOUNT C: /E`, puis `USBMOUNT C: un.dsk` : le fichier est là ; ouvrir ensuite
  le menu du LOCI : C: montre l'image (et rien après l'éjection), puis retour à CP/A ;
- monter une image dans le lecteur courant (`C:`, puis `USBMOUNT C: autre.dsk`), puis
  l'éjecter : pas de blocage du LOCI, le prompt revient en `A>` ;
- refus : `USBMOUNT A: x.dsk`, la même image dans deux lecteurs, un `.TXT` comme disquette,
  un `.TAP` resté sur la disquette (`Exporter d'abord`) ;
- **`/B`** : `GRXASM JEU /O`, `EXPORT JEU.TAP`, `USBMOUNT JEU.TAP /B` : l'Oric doit
  redémarrer en BASIC 1.1 et charger la cassette tout seul ; dire si rien ne se passe, si
  le BASIC démarre sans charger, ou si `Erreur USB` s'affiche (code). Puis le retour à CP/A
  par le menu du LOCI (FDC à remettre en service) : les disquettes sont toujours montées.

**Clé USB, lot 3 : CMDER sur la clé** (`docs/cmder.md` § 6 ; sur des **copies** d'images) :

- `^U` sur une image de quelques centaines de Ko : nom proposé (`PROJETS1.DSK`), progression
  `Copie : n/525 Ko`, durée à noter ; puis ESC au milieu d'une autre copie : `Interrompu`, et
  pas de `~CPADUP.TMP` resté sur la clé (le vérifier aussi sur le Mac) ;
- `^N` d'un fichier de la clé, avec un nom long (plus de 20 caractères : la ligne défile) ;
  `^N` et DEL sur une image montée : `Image montee en B:` ;
- DEL de plusieurs fichiers marqués (`Effacer 3 fichiers de la cle (O/N) ?`) : bilan, et
  les fichiers ont bien disparu sur le Mac ;
- `^O` sur un `.DSK` (`Monter en : C:`), puis sur un `.TAP` : le menu du LOCI montre les
  mêmes images ;
- en-têtes : `CMDER`, `CMDER A: B:` : nom de chaque image (coupé avec `~` s'il est long) ;
  sur un Oric sans LOCI (s'il y en a un sous la main) : en-têtes comme avant.

**Lot de petites corrections** (rapide, sur `cpa.dsk` puis `cpa-en.dsk`) :

- HIRES plein écran (`GRAPHER ECRAN`, `VOIR` d'une image, après un `DIR` qui a rempli
  l'écran) : les 3 lignes du bas restent noires, sans caractères ;
- un `.GRX` avec `HIRES` puis `GLOAD ABSENT`, traduit (`GRXASM E2 /C`, puis `E2`) :
  `Erreur : image introuvable` reste affiché au-dessus du prompt ;
- `REN A.TXT B.TXT` (ordre de COPY) et `REN A.TXT=B.TXT` (ordre de CP/M) ; `REN` seul
  montre les deux formes ;
- menus : CMDER, Vue, « Autre col. ^I » ; HEX, Mode, « Hex/ASCII ^I » ; `HELP TOUCHES`.

**Tableaux de GRAPHER en (colonne, ligne)** (`DIM T$(c,l)`, `T$(x,y)`, `PASTE T$(x,y)`) :
interprété puis traduit (`GRXASM NOM /C`), sur `cpa-exemples.dsk` et `cpa-examples-en.dsk` : `CARTE` (lacs plus
larges que hauts, chaînes de montagnes horizontales, joueur au centre), `ROTSCROL`,
`SCORES` (noms et scores relus), `JEU` (les pièces de 5 × 3 cases). Un `.GRX` à soi
qui a des tableaux à deux dimensions est à passer par `tools/grx_colig.py` (EXPORT, puis
sur le Mac, puis IMPORT).

**`PRINT` à plusieurs éléments** (interprété puis traduit, console et LORES) :
`PRINT "V= " V`, `PRINT A$ " / " V+1`, `PRINT "Total : " ;` puis `PRINT T` sur la même
ligne, `PRINT X ;; commentaire`, `PRINT A$ = B$` (1 ou 0) ; `ECHO "  texte  "` dans la
console : sans les guillemets, espaces gardés.

**EDSPRITE, deuxième version** (curseur, grisé, aide, Détourer, tuiles), sur `cpa-exemples.dsk` :

- le curseur clignote toujours, même après une longue séance, un nouveau sprite, une
  relance (le défaut venait de l'horloge passée `$8000`, ~11 minutes après le démarrage) ;
- le transparent plus sombre (un point sur quatre) : le curseur se voit dessus, la grille et
  le damier de « Reel » restent lisibles ;
- la ligne d'aide (ligne 26) change avec la zone ;
- Dessin, Detourer sur un héros : un contour de masque, coins compris ; `^Z` l'annule ;
- `EDSPRITE TUILES`, ARBR ou MUR : « Reel » rempli par le motif de la tuile ;
- l'historique des lignes (flèche haut) est intact après EDSPRITE.

**Cas limites de GRAPHER** (pas d'urgence) : `SAVE`, `BSAVE` d'un fichier R/O (`fichier
protege`), disque plein (ancien intact, pas de `NOM.$$$`) ; un `.GRX` d'environ 20 Ko
(attend un gros programme) : `Fichier trop gros` au bon moment ; un tableau trop grand dans
un programme traduit : `memoire pleine` dès le lancement ; `GRXASM` sur un lecteur sans
`GRX.INC` : `GRX.INC absente (bibliotheque)`, pas de `.ASM` ; sur la disquette Logo,
`GRAPHER X /A` : GRXASM introuvable.

**Outils**

- DEBUG, `T` dans une routine du programme : HELLO n'appelle que le BDOS, et un `JSR` vers
  le système est toujours exécuté d'un coup, même par `T` (voulu). Essai : `GRXASM SERPENT`,
  `ASM SERPENT /S`, `DEBUG SERPENT`, puis `T` sur un `JSR` vers une routine de bibliothèque
  (`JSR g_xxx`) : on doit y entrer ; `P` au même endroit l'exécute d'un coup.

**En attente**

- TERM : la liaison avec `nc` sur le Mac marche dans les deux sens (LOCI 0.3.98) ; reste le
  contre-essai avec la 0.3.1 officielle (`docs/loci-modem-wifi.md`, « Firmware du LOCI ») ;
- TERM, fins de ligne, avec `nc -l 2323` sur le Mac et `TERM /E /L` : les lignes tapées
  sur le Mac (LF seul) doivent revenir en colonne 2 sur l'Oric ; celles tapées sur l'Oric
  doivent passer à la ligne dans `nc` ; essayé dans Oricutron (boucle : CR, LF seul, CR LF) ;
- TERM, réception sans perte (`docs/loci-modem-wifi.md`, « Contrôle de flux ») : sur le
  Mac, `nc -l 2323 < un_long_texte.txt` (quelques Ko, lignes courtes), puis `TERM /E /L` et
  `ATDT-IP_DU_MAC:2323` : le texte doit arriver entier, alors que l'écran défile ;
- imprimante : pas d'imprimante ; à essayer par `PUT /P` quand il existera
  (`docs/etat.md` § 2 point 6).

**XFER, texte avec accents** (`/T`, conversion faite par `tools/xfer_server.py`) : un texte
du Mac avec `é è à ç œ æ « » —` reçu par `XFER R NOTE.TXT /T` : dans EDIT, `e e a c oe ae
" " -`, sans caractère parasite.

**MKTAP** (essayé seulement dans Oricutron, ROM BASIC 1.1) :

- Sur `cpa-exemples.dsk` : `ASM HELLO` n'est pas fait pour le BASIC (il appelle le BDOS) ; écrire
  un petit `TAPTEST.ASM` (`*= $9000`, quelques `STA $BB80+...` pour afficher un texte, puis
  `RTS`), `ASM TAPTEST`, puis `MKTAP TAPTEST TAPTEST.COM 9000 /R` et `EXPORT TAPTEST.TAP`.
  Redémarrer l'Oric en BASIC, monter `taptest.tap` comme cassette dans le menu du LOCI,
  `CLOAD""` : le texte doit s'afficher tout seul, puis `Ready`.
- Chargeur BASIC : `MKTAP TAP2 TAPTEST.COM 9000 /R TAPTEST.ASM 8000` (deux blocs), même
  chemin, un seul `CLOAD""` : les deux blocs se chargent, le texte s'affiche ; puis `LIST`
  montre `10 CLOAD"":CLOAD"":CALL#9000`, et une ligne tapée (`20 A=1`) s'ajoute normalement.
- **Programme BASIC écrit dans EDIT** (`.BAS`) : dans EDIT, `ESSAI.BAS` avec quelques lignes
  en minuscules (`10 cls`, `20 for i=1 to 5:print "Ligne";i:next`, `30 data abc,Def`,
  `40 read a$,b$:print a$;b$`, `50 rem Fin`), puis `MKTAP ESSAI ESSAI.BAS /R`, `EXPORT
  ESSAI.TAP`, BASIC, cassette montée par le menu du LOCI, `CLOAD""` : le programme démarre
  tout seul ; `abcDef` s'affiche tel quel ; `LIST` montre les mots-clés en majuscules,
  `"Ligne"`, `abc,Def` et le `REM` restés tels quels ; une ligne tapée (`60 PRINT "OK"`)
  s'ajoute, `RUN` marche. Sans `/R` : `CLOAD""` charge sans lancer. Une ligne de plus de 78
  caractères : MKTAP l'annonce, le `.TAP` marche quand même.
- Si quelqu'un a un **Oric-1** (ROM 1.0) : le même `.TAP` (format et mots-clés supposés
  identiques, jamais vérifié ; un `.BAS` sans `STORE`, `RECALL`, `INVERSE`, `NORMAL`, ni `GO`
  hors de `GOTO` et `GOSUB` : mêmes codes dans les deux ROM, `docs/oric-basic.md` § 2).

**GRXASM `/O`** (programme GRAPHER pour un Oric seul ; la chaîne entière vérifiée avec un jeu,
ci-dessous « Vérifié » ; le reste essayé seulement dans Oricutron, ROM BASIC 1.1) :

- Les `.TAP` tout faits de `build/tap/` (copiés sur la clé depuis le Mac) : monter
  `serpent.tap` comme cassette dans le menu du LOCI, `CLOAD""` : le jeu démarre tout seul ;
  les flèches mènent le serpent (répétition quand on garde la touche), Q finit, et l'Oric
  redémarre en BASIC (`ORIC EXTENDED BASIC`, `37631 BYTES FREE`). De même `carte.tap`
  (tuiles dessinées dans le jeu secondaire : arbres, eau, montagnes ; X et Y changent aux
  flèches) et `defile.tap` (la route défile ; perdu : `Perdu ! Score`, une touche, puis le
  redémarrage). Le bouton RESET en plein jeu doit aussi redémarrer l'Oric proprement.
- Les durées sur l'Oric, au chronomètre : `GRXASM NOM /O`, d'abord la traduction (jusqu'à
  `NOM.ASM ecrit`), puis l'assemblage ; pour `SERPENT`, et pour `CARTE` (avec `TUILES.SPR`,
  recopié dans le `.TAP`). Dans le 6502 simulé, pour `SERPENT` : 12,9 s de calcul et 968
  enregistrements lus ou écrits pour la traduction, 17,9 s et 519 pour l'assemblage.
- Les autres réglages du LOCI que AUTO pour la cassette (seul AUTO essayé).
- Une saisie dans la console : un `.GRX` de trois lignes (`INPUT N$`, `INPUT V`,
  `PRINT N$ " " V`), traduit avec `/O` : le curseur (case inversée) suit la frappe, DEL
  efface, un nombre refusé (`x`) donne un bip court ; à la fin, la ligne affichée reste
  jusqu'à une touche, puis le redémarrage.
- Sur `cpa-en.dsk` : `GRXASM B:SNAKE /O` (messages anglais, `MAP.TAP` et `ROAD.TAP` de
  `build/tap/` aussi).
- Si quelqu'un a un **Oric-1** : `serpent.tap` doit marcher aussi (vecteurs pris en `$0228`
  et `$022B`, d'après la ROM 1.0, jamais essayé).

## À vérifier ailleurs

- **Clock Signal** (simule la rotation et le chargement de tête) : premier accès après plus
  de 3 s. Ses images ne sont pas fiables après écriture : en réécrivant une piste dans le
  fichier, il ne garde que deux des trois `$A1` de chaque synchronisation (Oricutron et le
  LOCI n'y trouvent plus rien) et peut fausser le CRC d'un secteur (« disk I/O error » à la
  relecture) ; `mkdisk.py check` le montre, `mkdisk.py repare` remet l'image d'aplomb. Son
  Write Track ne marche pas sur un 1793 : FORMAT y reste bloqué sur la piste 0 ; n'y utiliser que A: et des commandes qui existent tant que la version à quatre
  lecteurs n'est pas construite.

## Vérifié

Sur Oric Atmos + LOCI, version disquette :

- XFER (30 octobre 2026, avec `tools/xfer_server.py` sur le Mac) : envoi et réception d'un
  texte (identiques), d'un gros `.COM` vers B: (il se lance), `/T` (fins de ligne,
  tabulations), ESC pendant une réception (rien d'écrit, ancien fichier intact), XFER sans
  liaison (`Pas de reponse du serveur`), plusieurs XFER de suite sans repasser par TERM ;
- démarrage, menus, EDIT, PUT, DIR, GTEST, LOGO, STAT, MEM, POKE, GO, DO ;
- historique des lignes (flèche haut) au prompt et dans LOGO, ← → dans LOGO ; complétion des
  noms par ESC ;
- mode SPLIT avec la bascule en `$BFDF` ;
- LOGO : décimaux, tortue avec des décimaux (plus rapide que le BASIC), dessin (POINT, TRAIT,
  RECTANGLE, PAVE, CERCLE, ETIQUETTE, FIXECOULEUR, ALLUME? : un traceur de fonctions) ;
- DEBUG démarre ;
- EXPORT, IMPORT, USBDIR, aussi depuis CMDER (13 octobre 2026) ;
- FORMAT, DISKCOPY, attributs et COPY avec jokers sur le LOCI (13 octobre 2026) ;
- CMDER, version 1 et lot 2, deux colonnes comprises (13 octobre 2026) ;
- lecteur sans image sur le LOCI : plus de « BDOS: disk I/O error » ;
- `PAPER`, `INK`, `PAGE`, article Pagination.

Version anglaise (`cpa-en.dsk` et ses jumelles), 24 octobre 2026 : des séances entières sans
plantage ni redémarrage.

- toutes les commandes et tous les programmes de `cpa-en.dsk` (TYPE à USBDIR, EDIT, HEX, ASM,
  DEBUG, CMDER, GRAPHER, GRXASM, VOIR, HELP, README.TXT, LOGO) : messages anglais, 37
  colonnes ; tous les menus (barre du système, EDIT, HEX, CMDER, LOGO) ;
- les exemples des disquettes anglaises : jeux et dessins `.GRX` en interprété et traduits
  (tuiles, sprites, rectangles, fichiers de données), animations (`DEMO` de
  `cpa-anim-en.dsk`), exemples LOGO ;
- **ASM en vrai** : sources de LOGOTR (`.s` renommés `.asm`) importées de la clé par CMDER,
  `#include` manquants cherchés dans EDIT, `ASM` de LOGOTR jusqu'au `.COM` (lectures et
  écritures alternées sur la disquette) ;
- un score ajouté à `PUZZLE.GRX` (`JEU.GRX` en français) dans EDIT, sur l'Oric ;
- **clé USB débranchée à chaud** : `DIR` donne une erreur BDOS, sans plantage ; clé remise
  (avec une nouvelle version du `.dsk`), `DIR` montre les fichiers de la nouvelle version ;
- HIRES plein écran : bascule du circuit vidéo ; les 3 lignes du bas montraient ce qu'il y a
  en mémoire (corrigé : une boucle de `h_bottom` s'arrêtait au premier octet, à revérifier
  ci-dessus).

Cas limites et disquette française, 24 octobre 2026 :

- EDIT : Enreg. sous un fichier existant, sous un fichier R/O, disque plein ; au-delà de
  32 000 octets, `Fichier tronque : trop gros` à l'ouverture, mais un texte enregistré à
  32 761 octets ne se rouvrait pas (corrigé, à revérifier ci-dessus) ; tous les cas de
  défilement (modes coupure et ligne) ;
- LOGOTR sur un fichier protégé : texte dans `NOM.$$$`, original intact ;
- deux lecteurs : GRXASM vers un autre lecteur, complétion par ESC d'un programme présent
  seulement sur B: ;
- clavier : SHIFT et CTRL avec les flèches et les lettres, CTRL-I, frappe rapide (boucle
  `GET K` / `PRINT K` dans un `.GRX`) ; CTRL-C au prompt : ligne vide -> démarrage à chaud
  (nouvelle ligne), ligne commencée -> rien, comme prévu ;
- couleurs des menus sur les huit papiers : nettes sur le vrai écran ; VSYNC marche (sans
  animation assez rapide pour voir la différence) ;
- DEBUG : pas à pas, désassemblage, points d'arrêt ;
- disquette française : tous les menus, `EDIT.CFG`, `CMDER USB:` puis `4` (`+TAILLE`),
  `HELP TOUC`, `LOGO DEMO`, `GRAPHER JEU` (score) ;
- **RESET pendant `DISKCOPY A: D:`** : `*RESET* at C6C6`, puis `No file` partout jusqu'au
  redémarrage, disquettes intactes (pilote corrigé, à revérifier ci-dessus).
- DEBUG : `G` après un arrêt sur un point d'arrêt ; `H` en français et en anglais selon la
  disquette ; `T` sur `JSR BDOS` l'exécute d'un coup, comme prévu ;
- HEX : écriture d'octets ; EDIT : CTRL-W (trois modes), d'usage courant ;
- GRAPHER traduit, boucle sans lecture du clavier : arrêtée par RESET, système rendu ;
- LOGO : son (essayé plus tôt ; maniement jugé lourd, `docs/etat.md` § 2 point 6) ;
- TERM : RETURN ne passait pas à la ligne (corrigé, en attente du Pico ci-dessus).

GRXASM `/O`, 25 octobre 2026 : un jeu de puzzle (`JEUCOUL.TAP`) écrit dans EDIT sur l'Oric,
mis au point en interprété (`GRAPHER`), puis `GRXASM NOM /O` : traduction, `ASM /E /T`
enchaîné, `.TAP` écrit sans blocage ; `EXPORT` vers la clé ; `CLOAD""` sur l'Atmos depuis le
LOCI en mode cassette (réglage AUTO), sans disquette : le jeu démarre seul ; à la fin, l'Oric
redémarre comme à la mise sous tension (voulu). Le `.TAP` d'ASM `/T`, complété par des 0, se
charge sans souci. Traduction jugée assez longue (non minutée), assemblage plus rapide.

EDSPRITE, première version, 24 octobre 2026 (`cpa.dsk`) : grille lisible (grisé jugé trop
clair pour le curseur : assombri), tous les menus sans traces, héros modifié vu dans
`GRAPHER SPRITES`, police normale en sortant. Défaut trouvé : le curseur ne clignotait plus
(corrigé ci-dessus). RESET pendant `^S` pas essayé (peu utile sous CP/A ; essayé dans
Oricutron par `tools/test_fichiers.py`).

Pour la version ROM : voir `docs/projet-rom.md`.
