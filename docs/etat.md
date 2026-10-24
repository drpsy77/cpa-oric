# CP/A disquette — état et suite

Système « à la CP/M » pour Oric Atmos, chargé depuis une disquette (Microdisc, LOCI) dans les
16 Ko de RAM overlay, et enrichi par des programmes `.COM` plutôt que par du code résident.
Usages visés : développer sur l'Oric lui-même, gérer des fichiers et des données, communiquer
(réseau par le LOCI). À lire avec `docs/architecture.md`.

## 1. Ce qui existe (version 0.9)

**Système** : code `$C000-$F664` en français (`$F638` en anglais), **marge 12 octets**
jusqu'à `$F670` (135 sans l'option `CPLCMD`) ; page `$FF00-$FFEF`, marge 10 octets (table
des touches de l'édition de ligne, encres des menus). `./build.sh` affiche les deux marges.

- console : pause en fin d'écran, menus déroulants (FUNCT), voyants `A`/`a` et `P`, couleurs
  et pagination (`PAPER`, `INK`, `PAGE`) ;
- clavier : CTRL-H à CTRL-K distincts des flèches (28-31), CTRL-ESPACE (0), SHIFT et CTRL
  avec les flèches (`$F0-$F7`) ; mêmes touches dans EDIT, HEX, CMDER et la ligne de commande
  (`docs/manuel.md`, « Les mêmes touches partout ») ;
- lecture de ligne (BDOS 10) : édition, historique, complétion par TAB ou ESC des noms de fichiers
  et, en début de ligne, des commandes (sur les lecteurs où elles seraient cherchées) ;
- fichiers CP/M 2.2 (séquentiel, accès direct, attributs R/O et SYS), lecteurs A: à D: ;
- programmes et scripts cherchés sur le lecteur du script (ou le courant), puis A: à D: ;
  scripts `.BAT` (DO, `$1`-`$9`, appel de script à script par XDO) ; CHAIN (BDOS 47) ;
- imprimante Centronics (LIST, BDOS 5, CTRL-P) ;
- graphisme SPLIT (BDOS 115), son AY (BDOS 116) ; HIRES plein écran et écran texte (LORES)
  laissés aux programmes, avec retour assuré par le démarrage à chaud ;
- reprise après plantage (BRK, RESET) ; un RESET pendant le transfert d'un secteur attend la
  fin du secteur (un secteur coupé, du répertoire par exemple, serait illisible) ; un
  contrôleur de disquettes qui ne répond plus donne `BDOS: disk I/O error`, jamais un accès
  déclaré bon (`tools/test_fdc.py`).

Détail du fonctionnement interne : `docs/systeme.md`. Mode d'emploi : `docs/manuel.md`.

**Programmes**

| Programme | Octets | Rôle | Documentation |
|---|---:|---|---|
| HELP | 11 577 | aide par rubriques (textes compressés) | `manuel.md` |
| TYPE, ERA, REN, SET, STAT, COPY | 177 à 1 033 | fichiers | `manuel.md` |
| FORMAT, DISKCOPY | 1 685, 1 658 | disquettes, avec un seul lecteur | `manuel.md` |
| CMDER | 13 581 | gestionnaire de fichiers plein écran, deux colonnes, clé USB | `cmder.md` |
| EXPORT, IMPORT, USBDIR | 1 750, 1 735, 994 | échange avec la clé USB du LOCI | `manuel.md` |
| TERM | 700 | terminal série (modem WiFi du LOCI, ACIA `$0380` ; Oricutron `$031C`) | `manuel.md` |
| XDO | 1 351 | appel de script à script | `manuel.md` |
| EDIT | 8 704 | éditeur de texte (coupure aux mots, à 38 caractères, ou ligne entière qui défile en largeur) | `manuel.md` |
| HEX | 3 840 | éditeur hexadécimal | `manuel.md` |
| ASM | 6 130 | assembleur 6502 (identique à xa sur nos sources) ; `/S` : symboles, `/E` : source effacée ; `#include` cherchés sur A: à D: | `manuel.md` |
| DEBUG | 6 490 | moniteur, désassembleur, pas à pas | `manuel.md` |
| MEM, POKE, GO | 674, 254, 221 | mémoire | `manuel.md` |
| LOGO | 18 963 | Logo (français, ou anglais sur les disquettes anglaises : 18 758) : tortue, décimaux, listes, son, écran texte | `logo.md` |
| LOGOTR | 4 402 | traduit les primitives d'un `.LOG` d'une langue à l'autre | `logo.md` |
| GRAPHER, GRXASM | 17 654, 15 004 | langage de dessin et de jeux (`.GRX`) : interpréteur, traducteur en assembleur (`/C` : jusqu'au `.COM` ; aucun contrôle à l'exécution, tableaux à adresse fixe, seules routines utiles des bibliothèques) ; fichiers de données, sprites en mode texte (`.SPR`) ; rectangles (copie d'un tableau vers l'écran, défilement, rotation), écriture verticale ; cartes de tuiles (`TILESET`, `TMAP`, `TILE`, dessins par `TFONT`) | `grapher.md` |
| VOIR, VSYNC | 3 353, 744 | images, animations ; calage du top sur le balayage | `manuel.md` |
| HELLO, GTEST | 88, 156 | exemples d'assembleur | — |

Disquettes : `cpa.dsk` (tout, et la démonstration), `cpa-logo.dsk`, `cpa-notes.dsk`,
`cpa-asm.dsk`, `cpa-anim.dsk`, et `cpa-projet.dsk` (vierge, sans système : le travail en B:,
la disquette système en A:) ; chacune a sa jumelle anglaise (`cpa-en.dsk`, `cpa-logo-en.dsk`...
`cpa-project-en.dsk`) ; contenu dans `docs/manuel.md`.

**Mesure** : 1 307 points de fonction IFPUG et 312 points d'algorithmes ; détail, lignes,
octets et documentation dans `docs/points-de-fonction.md`.

**Sur le vrai matériel** : versions anglaise et française essayées en entier sur Oric
Atmos + LOCI (ASM compris, deux lecteurs, clé USB débranchée à chaud), sans un plantage ni
un redémarrage ; la stabilité est un argument du README. Les deux défauts trouvés dans les
cas limites (RESET pendant DISKCOPY : accès déclarés bons sans réponse du contrôleur ; EDIT
qui ne rouvrait pas un texte de plus de ~31 Ko qu'il venait d'écrire) sont corrigés, à
revérifier. Ce qui reste à vérifier est dans `docs/essais-materiel.md`, à lire seulement
quand on en a besoin.

## 2. Suite prévue (par priorité)

Ordre fixé d'après `docs/vision.md` : créer, développer et compiler, publier, échanger.

1. **Atelier créatif**
   - Fait dans GRAPHER : sprites en mode texte (`SPRITES`, `SPOOL`, `SSHOW`, `SHIDE`,
     bibliothèque `SPR.INC` ; `docs/grapher.md` § 7.1, § 10.1), rectangles (`PASTE`, `GRAB`,
     `SCROLH`, `SCROLV`, `ROTH`, `ROTV`, `PRINTV`, `ECHOV`, `SPCV` : § 7.2), tuiles
     (`TILESET`, `TMAP`, `TILE`, `TFONT` : § 7.3 ; `tools/mkspr.py` fait les `.SPR` sur le
     PC en attendant l'éditeur).
   - Reste : les caractères animés au 50 Hz (§ 16) ; l'éditeur de caractères et de sprites
     (`.COM` plein écran) ; un **dessin assisté** (`.COM`, plus
     précis que la tortue de LOGO : points, traits, formes, remplissage, couleurs par
     attributs, vers `.HIR` / `.HIZ`), à spécifier.
2. **GRAPHER, plateforme de développement** : phases d'un jeu (`RUN`, à décider :
   `docs/grapher.md` § 17). Les programmes traduits sont petits (seules routines utiles des
   bibliothèques : 1,5 à 6,4 Ko pour les exemples) et rapides (tableaux à adresse fixe).
   - Gros programme envisagé par Pierre (24/10/2026, rien codé) : un **rogue-like** (sprites,
     niveaux tirés au hasard, une dizaine de monstres, armes, butin). Estimation : 500 à
     550 lignes, 12 à 15 Ko de `.GRX` ; tables des monstres et des objets dans des fichiers
     de données (`LOAD`), ~3 Ko de tableaux. Trop juste en interprété (~17 Ko pour texte et
     tableaux), à l'aise traduit : `.COM` de 20 à 23 Ko, ~15 Ko de tableaux libres,
     `.ASM` de ~130 Ko pendant l'assemblage. Bon cas d'essai pour la limite de 20 Ko et pour
     `RUN` : la génération d'un niveau, programme à part, écrit le niveau dans des fichiers
     de données que le jeu relit.
3. **Publier vers l'Oric de base** (`docs/oric-basic.md`) : `MKTAP.COM`, `tools/mktap.py` et
   `CASSETTE.COM` (décidés), puis une boîte à outils appelée par `!` depuis le BASIC, ou
   GRXASM vers un programme autonome (`.TAP`) ; ordre à choisir.
   - Demandé par Pierre le 23/10/2026 (rien codé ; ergonomie du menu LOCI jugée peu pratique) :
     - **`USBMOUNT`** (nom choisi) : une seule commande pour monter un fichier de la clé du
       LOCI depuis CP/A, sans repasser par son menu ; le type du fichier dit quoi faire.
       - `USBMOUNT B: JEU.DSK` : monte un `.dsk` en B:, C: ou D: (relire le répertoire comme
         après un changement de disquette). **A: interdit** (décidé par Pierre) : les `.COM`
         et le fichier de banques du système y sont lus. Une disquette Sedoric seulement
         pour booter dessus.
       - `USBMOUNT JEU.TAP` : monte le `.TAP` dans le lecteur cassette du LOCI ; avec `/B`
         (option à confirmer), rend la main à la ROM BASIC et lance le chargement (on quitte
         CP/A). Ferme la boucle développer, publier, essayer.
       - Ne remplace pas le menu du LOCI au premier démarrage.
       - Complétion des noms de la clé USB (demandée) : la complétion du prompt (BDOS 10,
         `rline.s`) ne lit que les disquettes CP/A ; l'étendre à la clé coûterait de la place
         résidente et l'API du LOCI dans le système. Décidé : c'est `USBMOUNT` qui la fait.
         Sans nom, ou avec un début de nom (`USBMOUNT JE`), il montre la liste des `.DSK` /
         `.TAP` de la clé qui conviennent (navigable aux flèches, RETURN monte, ESC sort) ;
         un seul possible : monté directement. Noms longs de la clé : coupés à 37 colonnes.
     - Préalable : vérifier dans les sources du LOCI (firmware et ROM du menu) que
       le montage `.TAP` / `.dsk` est appelable depuis un programme 6502 (USBDIR utilise déjà
       l'API du LOCI). Des `.COM`, rien dans le contrat.
     - L'équivalent de `CSAVE` est `CASSETTE.COM` (déjà décidé, `docs/oric-basic.md` § 2).
       Sous CP/A, la ROM est remplacée par la RAM overlay : réécrire les routines cassette
       (timing à essayer sur un vrai magnétophone) ou basculer un moment sur la ROM.
     - Ordre proposé : `USBMOUNT` sur `.TAP` avec boot, puis sur `.dsk` en B:, puis
       `CASSETTE.COM`.
4. **Réseau par le LOCI** (matériel : `docs/loci-modem-wifi.md` ; Pico W préparé, firmware
   recompilé, liaison Mac vérifiée ; **le Pico W ne marche pas encore avec le LOCI** : en
   attente d'un firmware du LOCI qui le prenne en charge, TERM reste à essayer) : `TERM.COM` fait (scrute l'ACIA lui-même, sans le
   BIOS). Reste : pilote série dans le BIOS sur PUNCH / READER (ACIA 6551, `$0380` sur le
   LOCI, `$031C` dans Oricutron ; ~150 octets estimés, donc ~300 à prévoir : il faut d'abord
   libérer de la place, § 3) ; `XFER.COM` (XMODEM) et `tools/xfer_server.py`.
5. **Sûreté des fichiers et défauts constatés**
   - **Contrôleur du LOCI qui ne répond plus après un RESET pendant `DISKCOPY A: D:`**
     (D: vide ; `*RESET* at C6C6`, disquettes intactes). Le pilote en fait maintenant une
     erreur disque au lieu d'accès déclarés bons (`docs/systeme.md` § 3). Reste à comprendre
     la cause : `C6C6` n'est pas une adresse de DISKCOPY mais du traitement du RESET lui-même
     (`hires_on` sur `cpa-en.dsk`, `print_hex8` sur `cpa.dsk`), donc une seconde NMI pendant
     le démarrage à chaud (rebond du bouton ?) ; la seconde NMI agit tout de suite, même au
     milieu d'un secteur (`bios.s`, `nmi_handler`). Le firmware du LOCI termine une écriture
     abandonnée au bout d'un délai (`dsk_rw_countdown`, `dsk.c`) : pas de blocage évident de
     ce côté. Non reproductible dans Oricutron, dont le contrôleur du LOCI simulé, une fois
     bloqué, ne lève jamais INTRQ (l'attente du premier octet échouait déjà) ; à voir sur le
     LOCI (`docs/essais-materiel.md`). Si c'est un rebond : ignorer une NMI arrivée peu après
     la précédente.
   - EDIT et GRAPHER (`SAVE`, `BSAVE`, `BSAVE SCREEN`) passent la batterie
     `tools/test_fichiers.py` (disque plein, répertoire plein, R/O, RESET balayé). Reste
     une fenêtre d'une demi-seconde, entre l'effacement de l'ancien fichier et le
     renommage, où un RESET laisse le nouveau contenu seulement dans `NOM.$$$` (rien n'est
     perdu, `REN` le remet). La fermer : une section protégée contre RESET pendant
     l'effacement et le renommage (variable publique en page 2, ou fonction BDOS de
     remplacement) — touche au contrat, à décider.
   - Écrivent encore en effaçant d'abord l'ancien fichier (disque plein ou RESET : ancien
     perdu), à passer par `NOM.$$$` et à ajouter à la batterie : `GSAVE` (BDOS 115 op 12,
     `img_save` de `src/gfx.s`, et `h_save` de `hires.inc`), LOGO (`SAUVE`, et `LOGO.$$$`
     de l'état), COPY et IMPORT sur un fichier existant, ASM (`.COM`, `.SYM` : refaits par
     un nouvel assemblage).
   - GRAPHER : pas de moyen de savoir si un fichier existe sans le charger (`FOUND` ne vaut
     qu'après `LOAD` ou `BLOAD`) ; une fonction du genre `EXIST("NOM")`, ou une commande qui
     pose `FOUND`, à décider.
   - Notés par Pierre le 22/10/2026 (à corriger, rien codé) :
     - **HIRES** : au passage en HIRES, les 3 lignes de texte du bas affichent ce qu'il y a
       en mémoire à leur adresse (caractères curieux) ; les effacer au passage.
     - **TAB -> `^I`** : « TAB » n'est pas naturel ; écrire `^I` dans les menus et les
       messages, en particulier CMDER (« Autre col. TAB ») et HEX (« Hex/ASCII TAB »), en
       français et en anglais. Attention : dans EDIT, `^I` veut dire insérer.
     - **Tableaux de GRAPHER en notation Oric** : abandonner l'ordre du C (Lig, Col), qui
       déroute alors que toutes les commandes et fonctions de l'Oric sont en (Col, Lig).
       `T$(Col, Lig)` = Lig chaînes de longueur maximale Col ; en mémoire, toujours Lig zones
       consécutives de Col caractères.
       Touche GRAPHER, GRXASM, `arr.inc`, exemples, références de test et `docs/grapher.md`.
     - **`ANIMS.GRX`** : ne passe plus dans GRAPHER (« animation trop grande ») mais passe
       une fois compilé par GRXASM. Pas forcément un défaut : en faire un exemple du manuel
       qui montre les limites du mode interprété et l'intérêt de compiler, avec la place
       disponible en plus après compilation par rapport à la version interprétée (à mesurer).
   - **Erreur d'un programme traduit après HIRES** (constaté dans Oricutron, en français
     comme en anglais, rien codé) : `HIRES` puis `GLOAD` d'une image absente ;
     l'interprété affiche `L 2 GLOAD : image introuvable`, le traduit
     (`GRXASM E2 /C`, `E2`) rend un prompt sur un écran vide : le message
     `Erreur : image introuvable` est effacé au retour (démarrage à chaud après HIRES ?).
6. **Petites améliorations notées**
   - **REN dans l'ordre de COPY** (demandé par Pierre le 24/10/2026, rien codé) :
     `REN ancien nouveau`, comme `COPY source destination`, moins déroutant que l'ordre de
     CP/M. Les deux syntaxes acceptées : avec un `=`, c'est l'ordre de CP/M
     (`REN nouveau=ancien`), sans `=`, celui de COPY. Toujours refusé si le nouveau nom
     existe (`Le nouveau nom existe deja`) ou si le fichier est protégé. Touche `ren.s`,
     `ren.msg` (usage dans les deux langues), le manuel, HELP et README.TXT, et la ligne
     `REN NOM.EXT=NOM.$$$` des documents (les deux formes y restent justes).
   - **Imprimante dans un fichier** (demandé par Pierre le 24/10/2026, sans imprimante ;
     Oricutron écrit déjà `printer.out`). Décidé : par PUT, plutôt que par un pilote LOCI
     dans le BIOS (marge de 12 octets, API du LOCI résidente) : `PUT /P NOM commande`
     recopie dans le fichier ce qui part à l'imprimante (LIST, BDOS 5, CTRL-P, `^P` d'EDIT)
     au lieu de l'écran ; `EXPORT` le passe sur la clé, puis directement avec le lecteur
     U: (§ 2 point 9 : `PUT /P U:PRINT.TXT ...`). Coût résident : un test dans LIST vers
     `put_char` (~10 octets), à faire avec la descente de PUT en banque (§ 3).
   - `AUTO.BAT` exécuté au démarrage ;
   - son dans les scripts : commande `NOTE` au prompt ou `PLAY.COM` (partition texte) ;
   - **Son de LOGO plus simple** (remarque de Pierre le 24/10/2026) : `SON v n vol d` et
     `ENSEMBLE` sont lourds pour un accord et n'ont pas de raccourci. Piste retenue : une
     surcouche écrite en LOGO (fichier `.LOG` chargé par `CHARGE` : notes par leur nom,
     accord, durées), sans toucher à LOGO.COM, puis seulement les primitives qui
     manqueraient. À écrire avec Pierre (ce qu'il attend d'un accord).
   - **TERM et la touche RETURN** (constaté par Pierre) : RETURN ne passe pas à la ligne.
     TERM envoie CR seul (ce qu'attend le modem) et affiche ce qui revient tel quel ; un CR
     sans LF (écho local `/E`, serveur qui ne renvoie que CR) ramène au début de la même
     ligne. Décidé : à l'affichage, CR donne CR LF, et un LF qui suit aussitôt est sauté (pas
     de ligne vide avec les serveurs qui envoient CR LF) ; option `/L` pour envoyer CR LF
     (serveurs comme `nc`). Essai sur le LOCI quand le Pico y marchera.
   - LOGO : ne pas perdre la frappe anticipée pendant `NOTE` / `ATTENDS` ; passer des
     paramètres d'un script à `LOGO NOM` ; tokenisation des procédures **en mémoire**
     seulement (au `CHARGE`, détokenisées par `SAUVE`, `LISTE`, `EDITE`), après la
     traduction et sur mesure (vitesse d'ELIZA et des traceurs, place) ; le contenu des
     listes reste du texte (code ou données : décidé à l'exécution) ;
   - GRAPHER : exemples de fichiers de données : un
     niveau écrit dans EDIT (`LOAD`), un écran titre (`BLOAD SCREEN`) ;
   - EDIT : une édition plein écran (colonnes 0-1 comprises) pour dessiner un écran texte ;
   - EDIT, demandé par Pierre le 23/10/2026 (rien codé) : un **sélecteur de fichiers**
     pour Ouvrir... et Insérer... (liste aux flèches, début de nom pour filtrer, RETURN
     choisit, ESC sort ; même esprit que `USBMOUNT`, § 2 point 3). À écrire une fois, en
     bibliothèque (`.inc`) réutilisable par les autres programmes (GRAPHER `LOAD`, CMDER...).
     Et **Insérer une partie d'un fichier** : le fichier choisi s'affiche en lecture seule,
     on s'y déplace et on y cherche (même recherche que dans EDIT), on marque début et fin,
     RETURN insère le bloc au curseur. But : une bibliothèque de bouts de code dans quelques
     gros fichiers, sans les charger en entier ni multiplier les petits fichiers. Lecture du
     fichier par morceaux, sans le copier dans le tampon de texte : bon usage des fichiers à
     accès direct (fonctions 33 à 36, point ci-dessous). Place à mesurer (EDIT : 1 536
     octets libres dans son dernier bloc, § 3).
     Gardé aussi : des **bouts nommés**. Une ligne `;##NOM` (commentaire en ASM et en
     GRAPHER ; distinct du `;@#` de GRXASM) commence un bout, qui va jusqu'au `;##` suivant
     ou la fin du fichier. Articulation proposée : Insérer... -> sélecteur de fichiers ; si
     le fichier a des `;##`, liste de leurs noms (RETURN insère le bout), plus une entrée
     « parcourir » vers la vue en lecture seule (où `;##` sert aussi de saut d'un bout à
     l'autre) ; sans `;##`, directement la vue. Index : construit à l'ouverture, en une
     lecture séquentielle, gardé en mémoire tant qu'EDIT tourne (nom, n° d'enregistrement
     de 128 octets, position 0-127 dans l'enregistrement : ~20 octets par bout) ; insertion
     par lecture directe (fonction 33) à cet enregistrement puis lecture suivie jusqu'au
     bout suivant. Pas de fichier d'index sur disque (rien pour savoir s'il est périmé).
   - USBDIR : liste des appareils du LOCI (`opendir("")`) ;
   - un usage des fichiers à accès direct (fonctions 33 à 36) dans les programmes : GRAPHER,
     LOGO ou un `.COM`, à trouver.
7. **Version anglaise** (faite et essayée sur le vrai Oric le 24/10/2026 ; tout nouveau texte affiché ou document d'utilisation se fait dans les deux langues)
   - Décidé : une seule disquette anglaise, `cpa-en.dsk` (le contenu de `cpa.dsk`, programmes
     de `build/progs-en`) ; pas de disquettes par usage en anglais tant que LOGO n'est pas
     traduit. Les mots-clés de GRAPHER restent ceux d'aujourd'hui dans les deux langues :
     seuls les messages se traduisent.
   - Fait : la mécanique (`architecture.md` § 5 : `progs/msg/fr`, `progs/msg/en`, deux
     assemblages par `build.sh`, menus dans les fichiers de messages, `files/en/`) ; les
     commandes TYPE, ERA, REN, SET, STAT, COPY, FORMAT, DISKCOPY, XDO, MEM, POKE, GO, VOIR,
     VSYNC, EXPORT, IMPORT, USBDIR ; EDIT (et son `EDIT.CFG` : `WORDS`, `CHAR`, `LINE`
     acceptés dans les deux langues), HEX, ASM, DEBUG ; CMDER (en-têtes, genres et
     colonne du signe de tri compris : 13 435 octets en anglais, 7 blocs comme en
     français) ; GRAPHER, GRXASM (et les commentaires du `.ASM` produit) et les
     bibliothèques des programmes traduits : `GRX.INC`, `ARR.INC`, `FIL.INC`, `SPR.INC`,
     `ANIM.INC` (VOIR compris) en deux langues, `build/src` et `build/src-en`, messages
     recopiés par `strip_inc.py` (`architecture.md` § 5) ; GRAPHER 17 583 octets en
     anglais, GRXASM 14 961. `tools/test_asm.sh` assemble aussi
     les programmes traduits avec leurs messages anglais ; `LANGUE=en
     tools/test_grapher.sh` compare GRAPHER et GRXASM anglais aux références françaises
     traduites par les fichiers de messages (`tools/msg_fr_en.py`).
   - Fait aussi : **le système** (principe : tout ce qui est produit l'est dans les deux
     langues, `architecture.md` § 5). Barre de menus FUNCT du prompt et messages de la
     console dans `src/msg/fr/sys.msg` et `src/msg/en/sys.msg` ; `build.sh` assemble
     `cpa_sys.bin` et `cpa_sys_en.bin` (marges contrôlées toutes deux). Barre anglaise :
     System, Files, Screen, Keyboard. Les articles montrent leur raccourci (Imprimante
     `^P`, Majuscules `^T`, Redemarrer `^C` ; aucun autre article n'en a). Les menus
     déroulants (système et programmes) prennent leurs encres dans `m_colors` selon le
     papier (`src/menu_col.s`, page `$FF00` : blanc avec magenta et bleu sur papier noir,
     etc. ; tableau dans le source). Coût : 23 octets de code (marge française 37 → 14),
     8 octets dans `$FF00` (18 → 10). La ROM, projet à part, reste en français.
   - Fait aussi : HELP et README.TXT (`tools/gen_readme_txt.py`, une liste par langue,
     mêmes rubriques ; `helptab.msg` dans `progs/msg/fr` et `en`, `files/en/readme.txt`).
     Sujets anglais : KEYS PROGRAMS EDIT HEX LOGO ASM DEBUG MEMORY USB GRAPHER CMDER ; la
     rubrique LOGO donne les primitives anglaises. HELP anglais : 6 blocs comme le
     français.
   - Fait aussi : toutes les disquettes en deux langues (jumelles `-en`, `architecture.md`
     § 5 ; `cpa-project-en.dsk` pour la vierge) et tous les exemples traduits sous des noms
     anglais (`files/en/noms.txt`) : `.GRX`, `.LOG` (ELIZA réécrit pour l'anglais :
     table de reflet, mots-clés, réponses), `DEMO.BAT`,
     `HELLO.ASM`, `GTEST.ASM` (`GTEST.COM` anglais). `ROTSCROL.GRX` et `JEU.GRX`
     (`PUZZLE.GRX`), cités au § 14 de `grapher.md`, sont maintenant sur `cpa.dsk` et
     `cpa-logo.dsk` (et leurs jumelles).
   - Fait aussi : `docs/en` décrit les disquettes anglaises (écrans, menus, messages de
     `cpa-en.dsk` ; `architecture.md` § 7) ; README.md renvoie à `cpa-en.dsk`.
   - Fait aussi : **LOGO** (`logo.md`). Une seule table de primitives
     (`tools/gen_logo_voc.py`) : chacune a un numéro (le token d'une tokenisation future)
     et ses noms dans les deux langues ; `LOGO.COM` dans la langue de la disquette, comme les
     autres programmes (vocabulaire `logovoc.msg`, messages, menus et AIDE `logo.msg`), donc
     pas de `LOGOFR` / `LOGOEN` et rien à changer au retour d'EDIT. Anglais classique
     (FORWARD FD, TO ... END, MAKE, PRINT PR, REPEAT, IF, OUTPUT OP, BUTFIRST BF...).
     `LOGOTR.COM` traduit un `.LOG` : primitives seulement, en position de code (listes
     d'instructions de `REPETE`, `SI`, `EXECUTE`, `ENSEMBLE`), listes de données recopiées,
     avertissements (liste de données qui commence par une primitive, nom de l'utilisateur
     qui est une primitive d'arrivée) ; aller-retour identique sur les exemples et les
     scénarios de test. Exemples `.LOG` anglais passés aux primitives anglaises par LOGOTR.
     `LANGUE=en tools/test_logo.sh` (références `tools/logo_tests/en`).
   - `smoke_test` : les deux disquettes anglaises ensemble (`GRXASM MAP /C`, `cpa-en.dsk`
     sur A:, `cpa-project-en.dsk` sur B:) ; le reste du smoke test ne dépend pas de la langue.
   - Documentation : faite. `README.md` en anglais (français : `README.fr.md`), documents
     d'utilisation dans `docs/en/` (mêmes noms, `tools/check_en.py`), documents internes en
     français seulement.

8. **Construire CP/A sur l'Oric** (demandé par Pierre le 23/10/2026, rien codé) : une
   disquette de construction pour produire sur l'Oric un système configuré selon les besoins
   (sans menus, sans USB du LOCI...) et l'installer sur B:, et faire les versions ROM.
   - Installer sur B: : existe déjà, `DISKCOPY A: B: /S` (comme SYSGEN) ; il faudra la même
     chose depuis un fichier système produit par ASM.
   - Sources : 198 Ko dans `src/`, 130 Ko sans commentaires ni lignes vides : `build.sh`
     produirait une version sans commentaires pour la disquette de construction (les
     sources de référence restent celles du dépôt). Tient sur une disquette, à mesurer.
   - ASM (syntaxe de xa, octets identiques) : manquent `#ifdef`, `#ifndef`, `#else`,
     `#endif` (les seules directives du système : 64 blocs, imbrication sur 2 niveaux dans
     `ccp.s` et `rline.s` ; pas de `#if` ni de `#define`). Les options (`DISK`, `CPLCMD`...)
     seraient des constantes d'un fichier de configuration inclus en premier (`DISK = 1`),
     sans option nouvelle sur la ligne de commande. Coût estimé : ~150 à 200 octets (mots
     des directives, état de saut avec une petite pile, lignes sautées, deux messages
     d'erreur). L'inclusion sur deux niveaux est évitée sans coût : `#include "sys.msg"`
     passe de `menu.s` à `cpa.s`. ASM (6 130 octets) est à 14 octets d'un bloc : il passe
     de 3 à 4 blocs sur la disquette (2 Ko). Symboles du système : 1 262, ~19 Ko, la
     mémoire libre d'ASM (~37 Ko) suffit. Temps : LOGO (136 Ko de source) s'assemble en
     ~1 min 30 ; le système (130 Ko sans commentaires) devrait être du même ordre, à
     mesurer sur un vrai Microdisc.
   - Refaire sur l'Oric les contrôles de `build.sh` (marges, fin du code, page `$FF00`).
   - Options touchant une fonction du BDOS (menus, USB, son...) : le numéro doit rester et
     répondre « absent » avec un code connu, et les programmes savoir s'en passer. Règle à
     écrire dans `architecture.md` (précise le contrat sans le casser) avant de rendre
     quoi que ce soit optionnel.
   - ROM : même assemblage avec l'option ROM (16 Ko), `EXPORT` vers la clé ; vérifier que
     le LOCI démarre sur une ROM lue sur sa clé.
   - Ordre proposé : règle des fonctions optionnelles ; `#ifdef` dans ASM, `sys.msg` inclus
     par `cpa.s` ;
     essai d'assemblage du système par ASM (octets identiques à xa) ; disquette de
     construction ; installation depuis un fichier ; ROM.

9. **Orientation LOCI du stockage**. Décidé par Pierre (23/10/2026), rien codé : CP/A vise
   à moderniser l'environnement, pas à rentabiliser des disquettes 3 pouces devenues rares
   et chères ; le LOCI est simple, répandu et peu cher, et la synchronisation d'un vrai
   Microdisc est délicate. Les fichiers restent du **texte sur disque** (EDIT, TYPE, git, le
   Mac) : pas de tokenisation ni de compactage sur disque (ceux du BASIC et de SEDORIC sont
   de leur époque) ; la place viendra du **lecteur « fichiers USB »** ci-dessous, la
   direction à suivre pour le stockage. Le `.dsk` reste pour démarrer et pour les vrais
   Microdisc et Cumulus.
   - **`.dsk` de 1 Mo** : possible mais cher. Cartes d'allocation actuelles : 22 octets par
     lecteur (`$FD00-$FD57`), ~176 blocs de 2 Ko, ~350 Ko. 1 Mo = 512 blocs : cartes de 64
     octets par lecteur (~170 octets résidents de plus) et numéros de bloc sur 2 octets
     dans le répertoire (comme CP/M 2.2 au-delà de 255 blocs) : nouveau format, anciennes
     disquettes illisibles. Et le LOCI doit accepter la géométrie (2 faces x 128 pistes ?)
     : à vérifier dans son firmware.
   - **Lecteur « fichiers USB » (U:)**, plus intéressant : les fonctions fichiers du BDOS
     passent par l'interface fichiers du LOCI (ouvrir, lire, écrire, se positionner,
     fermer ; USBDIR s'en sert déjà pour lister). Gains : taille de la clé, vitesse (pas
     d'émulation de secteurs), fichiers lisibles et modifiables sur le Mac (éditeur, git ;
     plus besoin d'`EXPORT` / `IMPORT`), accès direct presque gratuit (positionnement ;
     utile à la bibliothèque de bouts d'EDIT, § 2 point 6), taille exacte des fichiers.
     Difficultés : noms longs ramenés en 8.3 ; attributs R/O et SYS ; espace libre pour DIR
     et STAT ; les programmes qui lisent des secteurs par le BIOS (DISKCOPY, FORMAT...) ne
     marchent pas sur U:. **Touche le contrat** (un type de lecteur sans accès secteur) :
     à décider avant tout code.
   - **Construction hybride proposée** : A: reste un `.dsk` (démarrage ; compatible vrai
     Microdisc et Cumulus ; un utilisateur de Sedoric essaie CP/A sans rien changer), U:
     lecteur de travail pour qui a un LOCI (option de la construction, point 8). À terme,
     une variante « tout LOCI » où A: est un dossier de la clé : plus de code de secteurs
     sauf l'amorçage, système plus petit.
   - Préalable : lire l'interface fichiers du LOCI (`loci-rom`, firmware) : ce qu'elle
     permet, longueur des noms, espace libre, vitesse.
   - Fichier catalogue par répertoire de la clé (question de Pierre) : écarté. Il doublerait
     la vérité du disque et serait périmé dès qu'on modifie les fichiers sur le Mac (le but
     même de U:) ; écritures en plus à chaque modification (fenêtre RESET) ; fichier parasite
     sur la clé. Gain faible : ouvrir un fichier par son nom va droit au LOCI ; seuls DIR,
     les jokers et la complétion parcourent un répertoire, et lire un catalogue passe par la
     même interface qu'un `readdir`. À la place : (1) FAT garde déjà un nom court 8.3 pour
     chaque nom long : si l'interface du LOCI le renvoie, la correspondance des noms est
     faite et stable ; (2) un cache en mémoire du répertoire courant, tenu par CP/A,
     invalidé par ses propres écritures et au démarrage à chaud ; (3) le tri par joker fait
     par le firmware (piste à proposer à sodiumlb). D'abord mesurer la vitesse d'un
     `readdir` sur un répertoire de quelques centaines de fichiers.
   - Piste de Pierre : proposer à l'auteur du LOCI (sodiumlb) une version du firmware qui
     fasse du LOCI une vraie interface de stockage, support alternatif au Microdisc.
     Précédents dans cet esprit : Orix (système de la carte Twilighte, fichiers FAT sur
     clé USB / SD directement) et Erebus (à regarder).

Écarté : une base de données (hors de la vision : `docs/vision.md`) ; `REDIM` dans GRAPHER (hors de l'esprit du langage : les tailles sont connues à
l'écriture) ; modules chargeables pour LOGO (le chargement par étapes avec `CHARGE` et `OUBLIE`
suffit) ; primitive LOGO générique `.SYSTEME n [liste]` ; conversion CR LF -> LF par EXPORT.

## 3. Réserves de place

**Système** (marge 12 octets ; page `$FF00` : 10 octets) :

| Piste | Gain estimé | Prix |
|---|---:|---|
| H : masque de point calculé au lieu de la table `g_xbit` (240 octets) | ~220 | un peu plus lent en SPLIT |
| Police rangée sur 5 octets par caractère, dépliée par `font_init` | ~250 | le texte de `gfx.s` doit lire la police recopiée |
| I : test de RAM réduit à un remplissage, test complet en `.COM` | ~105 | — |
| Code répété (`g_box`/`g_line`, `go`/`f_delete`, `cmd_put`/`run_transient`) | < 500 | coût des `JSR` |
| Option `CPLCMD` retirée (complétion des commandes) | 123 | perte de la fonction |

Écartés : commandes graphiques du CCP en `.COM` (scripts ralentis), compression du clavier.

**Décidé par Pierre le 23/10/2026 (rien codé) : PUT descend en banque**, avant de toucher
aux menus (fonction phare, gardés résidents). PUT sert très peu ; le pilote série (~300
octets, § 2 point 4) est plus utile.
- Le tampon de PUT (`$F7C0-$FCFF`, 1 280 octets) devient une **fenêtre partagée**. Le code
  de PUT (`src/put.s`, 525 octets de `put_char` à `cmd_do`) va dans un fichier de banques
  sur A: (type SYS, chargé par les routines de fichiers résidentes) ; seuls restent les
  crochets du BIOS, du BDOS et du CCP (`put_on`, `put_end`, `put_flush`...) et un chargeur
  de banque. PUT chargé : son code et un tampon plus petit (~750 octets) dans la fenêtre.
  Variables de PUT en page 2 : internes (`$02AA-$02AE`), pas de contrat touché.
- Dans la même fenêtre, des fonctions rares qui ne servent jamais pendant un PUT :
  - le **code du démarrage à froid** (`ram_test`, `ram_report`, et ce qui ne sert qu'à la
    mise en route dans `hw_init` / `font_init`, à vérifier) : chargé avec le système dans
    la fenêtre, exécuté une fois, puis écrasé ; ni banque ni accès disque ; ~200 à 300
    octets ;
  - **pas** la complétion des commandes : sur un vrai Microdisc, un chargement de banque
    à chaque ESC ajouterait du retard à une complétion déjà lente. Elle reste résidente.
  - **GSAVE / GLOAD** (BDOS 115 op 12 et 13, `g_gsave` à `img_load`, et les commandes du
    CCP `cmd_gsave`, `cmd_gload`, `img_msg` : ~300 octets) et **`SAVE n fichier`**
    (`cmd_save`, ~130 octets) : rares, et déjà des accès disque (5 Ko pour une image), le
    chargement de la banque se voit peu. Bonus : GSAVE doit de toute façon passer par
    `NOM.$$$` (§ 2 point 5), écrit dans la banque sans coût résident.
  - **Prêt de la fenêtre pendant un PUT** : GLOAD / GSAVE sont appelés par GRAPHER, LOGO
    et les programmes traduits, donc possibles sous `PUT`. À l'entrée de tout appel BDOS,
    PUT a déjà vidé son tampon (`put_flush`) ; le code de PUT ne garde pas d'état hors de la page 2 (à vérifier : `pc_st` est modifié par le code, mais recalculé à chaque caractère).
    Donc : copie de la console suspendue (`put_on` à 0), banque IMG chargée, opération,
    banque PUT rechargée, `put_on` rendu. Coût : une relecture de ~525 octets, rare.
- **Pas les fonctions graphiques** (BDOS 115, `gfx.s`) : ~1,7 Ko, plus que la fenêtre ;
  appelées sans cesse par GRAPHER, LOGO et les programmes traduits (`GRX.INC`,
  `HIRES.INC`) ; et un PUT d'un programme qui dessine (`PUT LOG.TXT GRAPHER DEMO`, en
  SPLIT ou en HIRES) aurait besoin des deux à la fois dans la fenêtre. Aujourd'hui ce cas
  marche (texte copié, dessin à l'écran, tampon de PUT dans l'overlay hors de l'image) ;
  il doit continuer de marcher.
- Gain résident estimé : ~525 (PUT) + ~250 (démarrage) + ~430 (GSAVE, GLOAD, SAVE), moins
  le chargeur et le prêt (~120) : ~1,1 Ko ; le pilote série (~300) y tient avec de la marge.
- **Les banques sont une option, pas du dur** (pour la construction sur l'Oric, § 2 point
  8) : chaque module qui peut descendre (PUT, IMG = GSAVE / GLOAD / SAVE) a une option à
  trois valeurs dans le fichier de configuration : résident, en banque, absent. Résident :
  assemblé avec le reste, appels directs (le relais devient un simple `JSR`) ; en banque :
  assemblé dans le fichier de banques, appelé par le relais ; absent : le numéro répond
  « absent ». Chargeur et prêt de fenêtre assemblés seulement si au moins un module est en
  banque. Le code du démarrage à froid va toujours dans la zone du tampon de PUT (gain sans
  banque). Le contrôle de la fin du code (`rom_end`) dit à l'assemblage s'il faut en
  descendre un. La ROM n'a que résident ou absent.
- À vérifier : que le chargeur du système remplit bien `$F7C0-$FCFF` depuis la disquette ;
  la vitesse de chargement de la banque de PUT sur un vrai Microdisc et sur le LOCI.

**Disquettes** (blocs de 2 Ko : un octet gagné ne rend un bloc qu'en repassant sous un
multiple de 2 048) :

- tampons stockés dans le fichier, à sortir après la fin du programme : DEBUG (122), EDIT
  (842), HEX (432), XDO (512) ;
- GRAPHER (17 654 octets) prend 9 blocs, 778 octets libres dans le dernier ; piste de
  place : messages d'erreur par numéro, ~40 octets. GRXASM (15 004) prend 8 blocs ;
  GRX.INC (11 073 octets sur la disquette, marques `;@` et messages compris) prend 6
  blocs, 1 215 octets avant le 7e. HELP (11 577) prend 6 blocs. Les disquettes se spécialisent plutôt
  que de gratter des octets ;
- EDIT (8 704 octets) prend 5 blocs, 1 536 octets libres dans le dernier (tampon de texte
  aligné sur une page ; en anglais, 243 octets de code avant la page suivante, 71 en
  français). HEX : 47 octets avant le bloc suivant (143 en anglais) ; ASM (6 130) est à 14
  octets du bloc suivant, 91 en anglais (6 053) : un message français de plus doit être
  compensé ;
- usage à deux disquettes : sur `cpa.dsk` il reste ~70 Ko, peu pour travailler (CARTE :
  `CARTE.ASM` 46 Ko) ; le travail va sur une disquette de projet en B:, GRXASM `/C` ne
  laisse que le `.COM`, ASM n'écrit le `.SYM` que sur demande (`/S`) ;
- blocs de 1 Ko (−27 Ko sur `cpa.dsk`) : format du répertoire à changer, anciennes
  disquettes illisibles ; en dernier recours.

**Mémoire de GRAPHER interprété** : environ 17 Ko pour le texte, les tableaux et une
animation (`docs/grapher.md` § 13) ; `CUBE.ANI` et `BALLE.ANI` ne se jouent qu'en traduit.
Chaque octet de plus dans GRAPHER.COM en retire un.

## 4. Contraintes à garder en tête

- Tout ajout résident se justifie ; le reste va en `.COM`. Les estimations ont souvent été
  dépassées du simple au double : prévoir large.
- Les interruptions sont coupées pendant les accès disque (une touche peut être perdue, le
  compteur 50 Hz retarde).
- Le contrat d'interface (`docs/architecture.md`) est commun avec la version ROM
  (`docs/projet-rom.md`).
- La plupart des possesseurs d'un vrai lecteur n'en ont qu'un : une commande disque doit
  marcher avec un seul lecteur dès que c'est possible, et les commandes de base doivent
  pouvoir être sur chaque disquette.
