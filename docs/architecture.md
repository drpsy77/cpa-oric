# CP/A — architecture commune et contrat d'interface

Ce document est la référence partagée par les deux projets issus de CP/A :

- **la version disquette** (`build/cpa.dsk`) : système évolutif, mémoire étendue par le disque,
  orienté développement, gestion et communication — voir `docs/etat.md` ;
- **la version ROM** (`build/cpa.rom`) : ROM dédiée à l'exécution autonome d'un programme
  (cassette, cartouche) — voir `docs/projet-rom.md`.

Les deux sont construites à partir des **mêmes sources** (`src/`), la version disquette avec
`-DDISK`. Ce qui est décrit ici ne doit pas changer sans accord entre les deux projets.

## 1. Les couches

| Couche | Rôle | Où | Profil |
|---|---|---|---|
| BIOS | matériel : clavier, écran, console, IRQ 50 Hz, reprise après plantage, disque | `src/bios.s`, `src/disk.s` | commun (disque : `-DDISK`) |
| BDOS | services numérotés comme CP/M 2.2 (`JSR $0203`, X = fonction) | `src/bdos.s`, `src/fs.s`, `src/gfx.s`, `src/snd.s` | commun ; fichiers : disque seulement |
| CCP | prompt `A>` et commandes internes (la ligne est lue par `src/rline.s`, BDOS 10) | `src/ccp.s`, `src/ccp_gfx.s`, `src/ccp_disk.s`, `src/put.s`, `src/script.s` | commun ; DIR/PUT/DO… : disque (TYPE, ERA, REN : `.COM` ; commandes de dessin : GRAPHER.COM, ROM seulement au prompt) |
| Menus | barre de menus déroulants (FUNCT) | `src/menu.s` | commun |
| Programmes | fichiers `.COM` chargés en `$0500` (un nom sans `.COM` se rabat sur le script `.BAT`) | `progs/*.s` | disque (la ROM pourra en intégrer un) |

**Règle de placement** (pour toute nouvelle fonction) :

1. Ce qui touche au matériel ou doit tourner sous interruption → **BIOS**.
2. Un service que plusieurs programmes utiliseront (graphisme, son, fichiers) → **BDOS**, avec un
   numéro de fonction et un bloc de paramètres `[op, p1..p5]` comme les fonctions 115 et 116.
3. Une commande instantanée ou utile dans les scripts → **CCP** (commande interne), seulement si
   la place le permet.
4. Tout le reste → **programme `.COM`** (version disquette) : il ne coûte rien tant qu'on ne le
   lance pas.

## 2. Contrat d'interface (identique dans les deux versions)

### Table BIOS (`$C000`, 3 octets par entrée)

`$C000` BOOT, `$C003` WBOOT, `$C006` CONST, `$C009` CONIN, `$C00C` CONOUT, `$C00F` LIST,
`$C012` PUNCH, `$C015` READER, `$C018` HOME, `$C01B` SELDSK, `$C01E` SETTRK, `$C021` SETSEC,
`$C024` SETDMA, `$C027` READ, `$C02A` WRITE, `$C02D` MENUBAR. Version disquette : SELDSK
prend A = lecteur (0-3) et rend A = 0, ou `$FF` si le lecteur est absent ou illisible ; READ et
WRITE agissent sur ce lecteur.

Les entrées existantes ne bougent jamais ; une nouvelle entrée s'ajoute à la fin (`$C030`…).
LIST imprime A sur le port Centronics (port A du VIA, strobe PB4, accusé CA1 attendu 2 ms au
plus ; Oricutron écrit dans `printer_out.txt`). PUNCH et READER sont réservées au port série
(réseau, version disquette).

### Codes du clavier (CONIN, fonctions 1, 6, 10)

ASCII ; DEL `$7F` ; flèches `$08` gauche, `$09` droite, `$0A` bas, `$0B` haut ; avec SHIFT
`$F0-$F3`, avec CTRL `$F4-$F7` (même ordre). CTRL + lettre : 1-26, sauf CTRL-H à CTRL-K :
28-31 (TAB = CTRL-I = 29) ; CTRL-ESPACE et CTRL-@ : 0 ; CTRL-[ : 27 ; CTRL avec une autre
touche : rien. FUNCT : menus (codes `$81` et suivants choisis par le programme).

### Vecteurs et page 2

| Adresse | Contenu |
|---|---|
| `$0200` / `$0203` | `JMP WBOOT` / `JMP BDOS` |
| `$0206` / `$0209` | `JMP` IRQ / NMI, détournables (DEBUG s'en sert) |
| `$020C` | haut de la TPA (mot) : `$B400` en texte, `$A000` en SPLIT, moins si un plafond est posé |
| `$020E` | `SCR_PROG` : 1 = un programme a l'écran texte entier (LORES) ; la console est muette (ni menus, ni voyants, FUNCT et CTRL-T sans effet) ; remis à 0 au démarrage à chaud |
| `$0210-$0214` | console : curseur X, Y, visible, actif, clignotement |
| `$021B` | compteur 50 Hz (mot) |
| `$02A3` | 1 = pause en fin d'écran |
| `$02A9` | plafond de la TPA (page ; 0 = aucun), remis à 0 au démarrage à chaud |
| `$0244` | 1 = une ligne laissée par CHAIN attend dans `$0400` (interne au système) |
| `$0245` | imprimante : bit 0 = CTRL-P actif, bit 7 = suspendu pendant l'édition d'une ligne (interne) |

Les autres variables de la page 2 sont internes (liste complète, page 3 comprise : `docs/memoire-pages-2-3.md`). La partie
publique est dans `progs/cpa.inc`, que tout programme inclut.

### Fonctions du BDOS

| N° | Fonction | Versions |
|---|---|---|
| 0-12 | console et système, comme CP/M 2.2 (la 5 imprime sur le port Centronics) ; la 10 édite la ligne (flèches, insertion, historique ; complétion des noms de fichiers par TAB ou ESC en version disquette ; CTRL-C n'y fait un démarrage à chaud que sur une ligne vide du prompt du CCP), 126 caractères au plus | les deux |
| 13-25, 30, 33-36 | fichiers (CP/M 2.2, accès direct, attributs) ; lecteurs A: à D: (octet 0 du FCB : 0 = courant, 1 = A:... ; 14 choisit le lecteur courant, 24 rend les lecteurs lus, 25 le lecteur courant) | disque ; la ROM renvoie `$FF` (0 pour 24 et 25) |
| 26 | adresse DMA | les deux |
| 47 | CHAIN (comme CP/M 3) : A/Y = ligne de commande terminée par 0 (78 caractères au plus), exécutée par le CCP après un démarrage à chaud ; ne revient pas | les deux |
| 115 | graphisme du mode SPLIT : bloc `[op, p1..p5]`, op 0-13 | les deux (12-13 GSAVE/GLOAD : disque) |
| 116 | son AY-3-8912 : bloc `[op, p1..p5]`, op 0-8 (7 SYNC : départ simultané des voix, 8 MIXER : son et bruit d'une voix) | les deux |

Numéros libres pour l'avenir : 37-46, 48-114 et 117 et suivants. Une fonction ajoutée existe dans les
deux versions, quitte à renvoyer `$FF` là où elle n'a pas de sens.

### Programmes `.COM`

- Chargés et lancés en `$0500` par `JSR` ; retour par `RTS` ou `JMP $0200`.
- Page de base en `$0400` : FCB1 `$045C`, FCB2 `$046C`, paramètres et DMA `$0480`.
- Page zéro libre : `$0000-$00DF` (`$E0-$FF` au système ; DEBUG échange `$D0-$DF`).
- Un programme respecte le haut de la TPA (`$020C`) au lieu d'une adresse fixe.

## 3. Carte mémoire

| Zone | Version disquette | Version ROM |
|---|---|---|
| `$0000-$04FF` | page zéro, pile, page 2 (système), page de base | idem |
| `$0500-$B3FF` | TPA (programmes) ; `$A000-$B3FF` = image en SPLIT ; en HIRES plein écran (programme avec `progs/hires.inc`), image `$A000-$BF3F` qui recouvre aussi la police, les zones de `$B800-$BB7F` et l'écran texte | idem |
| `$B400-$BFDF` | `$B400-$B4FF` : adresses des lignes de points du mode SPLIT (`g_ylo`, `g_yhi`), calculées par `font_init` à la place des glyphes des codes 0-31 (des attributs, jamais affichés) ; police, police secondaire (`$B800-$B9FF` : sauvegarde des menus, et noms déjà vus pendant une complétion par ESC ; `$BA00-$BA7F` : ligne en cours d'édition ; `$BA80-$BB7F` : historique des lignes), écran texte | idem |
| `$C000-$FFFF` | RAM overlay chargée depuis la disquette : code jusqu'à `$F670` au plus (fin réelle : `rom_end`, affichée par `./build.sh`), puis tampons (ligne de commande `$F670`, DO `$F6C0`, PUT `$F7C0-$FCFF`), variables du BDOS `$FD00` (cartes d'allocation des 4 lecteurs `$FD00-$FD57`, puis variables ; libres : `$FDF8-$FDFF`), tampon de secteur `$FE00`, page `$FF00-$FFF9` chargée avec le système (tables `src/tables_ff.s`, `rl_keys.s`, `menu_col.s` jusqu'à `$FFEF`, puis libre ; elle ne reçoit que des données ou des routines autonomes, car elle n'est pas contiguë au code), vecteurs `$FFFA` | ROM : code jusqu'à `$E3D4` environ, tables en `$FF00` (comme la disquette), reste libre |

## 4. Construire et tester

Détail complet (outils, scénarios, installation sur Raspberry Pi) : `docs/atelier.md`.

    ./tools/setup_linux.sh [roms]    # une fois, sur Linux : xa, py65, Oricutron de test
    ./build.sh                       # build/cpa.rom, build/cpa.dsk (+ contrôles de taille)
    tools/smoke_test.sh              # construction + démarrage disquette et ROM dans l'émulateur
    tools/test_asm.sh                # ASM.COM doit redonner les octets de xa
    tools/test_logo.sh               # LOGO.COM : scénarios comparés aux références
    tools/test_grapher.sh            # GRAPHER.COM, GRXASM.COM : calculs, boucles, erreurs (sans émulateur)
    LANGUE=en tools/test_grapher.sh  # les mêmes en anglais, contre les références traduites
    tools/test_inc.sh                # bibliothèques allégées de la disquette == originaux
    python3 tools/test_fp.py         # décimaux (progs/fp_inc.s) contre un calcul exact
    python3 tools/test_anim.py       # images .HIZ et animations .ANI (h_unz, VOIR)
    python3 tools/pf_mesure.py --ecrire   # mesures et totaux de docs/points-de-fonction.md
    python3 tools/test_fichiers.py   # EDIT, GRAPHER : disque plein, R/O, RESET pendant l'écriture

- `build.sh` refuse un système disque qui dépasse `$F670`, une page `$FF00` qui atteint les
  vecteurs (`$FFFA`) et une ROM qui ne fait pas 16 Ko ; il affiche les deux marges.
- Tests dans Oricutron : `tools/run_test.sh` (frappe simulée et vidage mémoire, avec le patch
  `tools/oricutron-testhook.patch` ; `DSK=` pour la disquette, `ORIC_ROM=cpa` pour la ROM) et
  `tools/screen.py` (texte de l'écran).
- `tools/run_com.py` exécute un `.COM` dans un 6502 simulé avec un BDOS minimal (sans écran).
- Matériel : essayé sur Oric Atmos + LOCI (version disquette). Les couleurs des menus sont
  meilleures sur un vrai écran que dans certains émulateurs.

**Quels tests pour quel changement** (proportionnés au risque ; `test_logo.sh` dure ~25 min) :

| Changement | Tests |
|---|---|
| Toujours | `./build.sh` (taille, marge) et `tools/test_asm.sh` |
| Système (BIOS, BDOS, CCP, menus) | en plus : essai Oricutron ciblé sur ce qui change, `tools/smoke_test.sh` |
| LOGO.COM, `fp_inc.s`, `ltxt_inc.s`, ou les fonctions BDOS 10, 47, 115, 116 | en plus : `tools/test_logo.sh` |
| `fp_inc.s` | en plus : `python3 tools/test_fp.py` |
| GRAPHER.COM, GRXASM.COM (`grx*_inc.s`, `arr.inc`, `fil.inc`, `spr.inc`), `hires.inc` | en plus : `tools/test_grapher.sh` (et `LANGUE=en` si un message change), `tools/test_inc.sh`, essai Oricutron des exemples `.GRX` (dessin) |
| EDIT (enregistrement), `fil.inc`, `src/fs.s`, `src/disk.s` | en plus : `python3 tools/test_fichiers.py` (~10 min ; `--vite` pour un balayage plus lâche) |
| VOIR.COM, `hires.inc` (`h_unz`), `anim.inc`, `lzhir.py` | en plus : `python3 tools/test_anim.py` (images et animations dans le 6502 simulé) |
| Avant un commit de version, ou sur demande | tout |

## 5. Conventions

- Fichiers `progs/*_tab.s` (tables) et `progs/*_inc.s` (bibliothèques) : inclus par un
  programme, jamais assemblés seuls. `progs/hires.inc` est une bibliothèque livrée sur les
  disquettes (`HIRES.INC`, nom 8.3 pour ASM) ; ses étiquettes internes commencent par `hz_`
  pour ne gêner aucun programme. `progs/grx.inc` (`GRX.INC`) est la bibliothèque d'exécution
  des programmes traduits par `GRXASM NOM` (ou `GRAPHER NOM /A`). `progs/arr.inc` (`ARR.INC`,
  tableaux), `progs/fil.inc` (`FIL.INC`, fichiers de données) et `progs/spr.inc` (`SPR.INC`,
  sprites en mode texte) servent à l'interpréteur et aux programmes traduits. `progs/anim.inc` (`ANIM.INC`) joue les
  animations `.ANI` ; il s'inclut avant `HIRES.INC`, qui reste à la fin du programme (ses
  tables suivent `h_end`), et utilise aussi les étiquettes internes `hz_`.
- Écran au programme. HIRES plein écran : une convention, pas une fonction du contrat. Un programme qui met `$1E`
  en `$BFDF` hors du mode SPLIT a l'écran pour lui ; le système le reconnaît (`hires_on`) et
  n'y dessine rien (FUNCT ignoré, voyants, curseur éteint par le programme) ; le démarrage à
  chaud remet le texte, la police et un historique vide.
  Écran texte (LORES, `h_lores` de `hires.inc`) : `SCR_PROG` (`$020E`) à 1, mêmes effets
  (FUNCT et CTRL-T arrivent au programme comme des touches) ; `h_text` et le démarrage à chaud
  rendent la console.
- Assembleur : syntaxe `xa` de l'OSDK. Les programmes de `progs/` restent dans le sous-ensemble
  compris par ASM.COM (pas de `&étiquette`, pas de `#define`) : `tools/test_asm.sh` le vérifie.
  Le système (`src/`) peut utiliser tout `xa`.
- Pièges de `xa` : une étiquette locale de bloc `.( .)` ne peut pas porter le nom d'une
  étiquette globale déjà définie ; pas d'étiquette nommée comme une instruction ; branchements
  limités à ±127 octets (passer par un `JMP`).
- Textes à l'écran : ASCII sans accents, 37 colonnes au plus pour une ligne complète (la 38e
  provoque un retour à la ligne automatique en plus). Messages du CCP en anglais court ; menus,
  aide et programmes en français sur `cpa.dsk`, en anglais sur `cpa-en.dsk` (ci-dessous).
- Commentaires et documentation en français.
- **Deux langues** : tout ce qui est produit pour la version disquette, système compris, existe
  en français et en anglais (`cpa.dsk`, `cpa-en.dsk`). Système : barre de menus et messages
  de la console dans `src/msg/fr/sys.msg` ou `src/msg/en/sys.msg` (mêmes étiquettes),
  `build.sh` assemble `cpa_sys.bin` et `cpa_sys_en.bin` et contrôle la marge des deux (la
  française, plus longue, est la contrainte) ; les messages courts du CCP sont en anglais
  dans les deux. La version ROM, projet à part, reste en français pour l'instant.
- Messages des programmes en deux langues : chaque programme traduit inclut ses messages
  (`#include "nom.msg"`, nom de 8 caractères au plus pour ASM), pris dans `progs/msg/fr/`
  ou `progs/msg/en/` (mêmes étiquettes ; la touche « oui » est la constante `K_YES`, `O` ou
  `Y`). `build.sh` assemble deux fois : `build/progs` (français, `-I msg/fr`) et
  `build/progs-en` (`-I msg/en -I msg/fr` : un programme pas encore traduit garde ses
  messages français), puis `cpa-en.dsk`. ASM n'ayant qu'un niveau d'inclusion, une
  bibliothèque ne contient pas de `#include` : le programme inclut les messages de
  `loci_inc.s` (`loci.msg`) juste avant elle. Les menus d'un programme (FUNCT) sont dans
  son fichier de messages, largeur comprise ; les autres touches de réponse ont aussi leur
  constante (`K_ALL`, « tous » : `T` ou `A`). Les fichiers livrés qui ont une version
  anglaise sont dans `files/en/` (même nom : `EDIT.CFG`, `README.TXT`, exemples `.GRX`), mis
  sur `cpa-en.dsk` à la place de ceux de `files/` (`en_liste` de `build.sh`). Un exemple
  traduit garde le code de l'original : seuls les commentaires et les textes affichés
  changent (même colonne à l'écran) ; un changement de l'un est reporté dans l'autre.
- Aide : `tools/gen_readme_txt.py` produit à la fois README.TXT (notation et renvoi à HELP :
  `files/readme.txt`, `files/en/readme.txt`) et les textes de HELP.COM (`helptab.msg` dans
  `progs/msg/fr` et `progs/msg/en`, compressés en LZSS, décodés par `help.s`), à partir d'une
  liste par langue (mêmes rubriques, même nombre de lignes : vérifié).
- Bibliothèques sur la disquette (CPA.INC, HIRES.INC, GRX.INC, ANIM.INC, ARR.INC, FIL.INC, SPR.INC) : copies sans
  commentaires faites par `tools/strip_inc.py` ; la documentation reste dans `progs/*.inc`.
  Leurs messages sont dans `progs/msg/fr` et `progs/msg/en` (`arr.msg`...) : dans la
  bibliothèque, une ligne `;#msg nom.msg` marque leur place, `strip_inc.py` les y recopie
  dans la langue de la disquette (`build/src`, `build/src-en` pour `cpa-en.dsk`), et un
  programme de `progs/` qui inclut la bibliothèque inclut aussi ses messages, juste après.
  Les six bibliothèques des programmes traduits (GRX, ARR, FIL, SPR, ANIM, HIRES) sont en
  plus marquées par `tools/mark_inc.py` (lignes de commentaire `;@`) : GRXASM n'en recopie
  que les routines utiles (`docs/grapher.md` § 12, § 15).
- Git : un commit par livraison, message en français, testé avant. Le dépôt est publié sur
  GitHub (https://github.com/drpsy77/cpa-oric).

## 6. Organisation du dépôt

| Dossier | Contenu |
|---|---|
| `src/` | système (BIOS, BDOS, CCP, menus, graphisme, son, disque) |
| `boot/` | chargeur d'amorçage Microdisc |
| `progs/` | programmes `.COM` et `cpa.inc` |
| `files/` | fichiers copiés tels quels sur la disquette (README.TXT, DEMO.LOG, DESSIN.BAT) |
| `tools/` | outils PC : images disque, tables, tests |
| `docs/` | documentation (index dans `README.md`) |
| `build/` | résultats ; seuls `cpa.dsk` et `cpa.rom` sont versionnés |

## 7. Documentation

Une seule source par sujet, au présent : un document décrit ce qui **est** (ou ce qui est
décidé), sans récit, sans dates de discussion, sans « Pierre a dit ». L'histoire est dans git.

| Sujet | Où |
|---|---|
| but, public, principes, ce que CP/A n'est pas | `docs/vision.md` (critère pour ordonner la suite) |
| contrat, conventions, construction | ce document |
| état, suite prévue, réserves de place | `docs/etat.md` (court : relu à chaque conversation) |
| fonctionnement interne du système | `docs/systeme.md` |
| mode d'emploi d'un programme | `docs/manuel.md`, ou sa référence (`logo.md`, `grapher.md`, `cmder.md`) |
| choix de mise en œuvre d'un programme | section « Mise en œuvre » de sa référence |
| essais sur le vrai matériel | `docs/essais-materiel.md` (lu seulement au besoin) |
| aide sur l'Oric | `tools/gen_readme_txt.py` (HELP.COM, README.TXT) |
| mesure (points de fonction, lignes, octets) | `docs/points-de-fonction.md` |

- Une spécification de travail suit le même plan : ce qui est fait, « Décidé, pas encore
  fait », « Questions ouvertes ». Une question disparaît dès qu'elle a sa réponse : la
  réponse est intégrée au texte. Une fois le travail livré, la spécification devient (ou
  rejoint) la référence du programme.
- À chaque livraison : la référence du programme, `docs/etat.md` (tailles, marge, suite),
  `docs/essais-materiel.md` (« À vérifier ») et, si une fonction change,
  `docs/points-de-fonction.md` (§ 2.4) sont mis à jour ; rien n'est raconté.
- `README.md` (anglais) et `README.fr.md` (français) vont ensemble : un changement de l'un
  est reporté dans l'autre. De même pour les documents d'utilisation (`manuel.md`, `logo.md`,
  `grapher.md`, `cmder.md`) et leur traduction dans `docs/en/` : `python3 tools/check_en.py`
  signale une traduction en retard (titres, tableaux, exemples).

