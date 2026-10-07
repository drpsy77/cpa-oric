# CP/A — architecture commune et contrat d'interface

Ce document est la référence partagée par les deux projets issus de CP/A :

- **la version disquette** (`build/cpa.dsk`) : système évolutif, mémoire étendue par le disque,
  orienté développement, gestion et communication — voir `docs/projet-disquette.md` ;
- **la version ROM** (`build/cpa.rom`) : ROM dédiée à l'exécution autonome d'un programme
  (cassette, cartouche) — voir `docs/projet-rom.md`.

Les deux sont construites à partir des **mêmes sources** (`src/`), la version disquette avec
`-DDISK`. Ce qui est décrit ici ne doit pas changer sans accord entre les deux projets.

## 1. Les couches

| Couche | Rôle | Où | Profil |
|---|---|---|---|
| BIOS | matériel : clavier, écran, console, IRQ 50 Hz, reprise après plantage, disque | `src/bios.s`, `src/disk.s` | commun (disque : `-DDISK`) |
| BDOS | services numérotés comme CP/M 2.2 (`JSR $0203`, X = fonction) | `src/bdos.s`, `src/fs.s`, `src/gfx.s`, `src/snd.s` | commun ; fichiers : disque seulement |
| CCP | prompt `A>` et commandes internes (la ligne est lue par `src/rline.s`, BDOS 10) | `src/ccp.s`, `src/ccp_gfx.s`, `src/ccp_disk.s`, `src/put.s`, `src/script.s` | commun ; DIR/TYPE/PUT/DO… : disque |
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
`$C024` SETDMA, `$C027` READ, `$C02A` WRITE, `$C02D` MENUBAR.

Les entrées existantes ne bougent jamais ; une nouvelle entrée s'ajoute à la fin (`$C030`…).
LIST imprime A sur le port Centronics (port A du VIA, strobe PB4, accusé CA1 attendu 2 ms au
plus ; Oricutron écrit dans `printer_out.txt`). PUNCH et READER sont réservées au port série
(réseau, version disquette).

### Vecteurs et page 2

| Adresse | Contenu |
|---|---|
| `$0200` / `$0203` | `JMP WBOOT` / `JMP BDOS` |
| `$0206` / `$0209` | `JMP` IRQ / NMI, détournables (DEBUG s'en sert) |
| `$020C` | haut de la TPA (mot) : `$B400` en texte, `$A000` en SPLIT, moins si un plafond est posé |
| `$0210-$0214` | console : curseur X, Y, visible, actif, clignotement |
| `$021B` | compteur 50 Hz (mot) |
| `$02A3` | 1 = pause en fin d'écran |
| `$02A9` | plafond de la TPA (page ; 0 = aucun), remis à 0 au démarrage à chaud |
| `$0244` | 1 = une ligne laissée par CHAIN attend dans `$0400` (interne au système) |
| `$0245` | imprimante : bit 0 = CTRL-P actif, bit 7 = suspendu pendant l'édition d'une ligne (interne) |

Les autres variables de la page 2 sont internes (liste complète : `src/hw.inc`). La partie
publique est dans `progs/cpa.inc`, que tout programme inclut.

### Fonctions du BDOS

| N° | Fonction | Versions |
|---|---|---|
| 0-12 | console et système, comme CP/M 2.2 (la 5 imprime sur le port Centronics) ; la 10 édite la ligne (flèches, insertion, historique ; complétion des noms de fichiers par ESC en version disquette), 126 caractères au plus | les deux |
| 13-25, 30, 33-36 | fichiers (CP/M 2.2, accès direct, attributs) | disque ; la ROM renvoie `$FF` |
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
| `$0500-$B3FF` | TPA (programmes) ; `$A000-$B3FF` = image en SPLIT | idem |
| `$B400-$BFDF` | police, police secondaire (`$B800-$B9FF` : sauvegarde des menus ; `$BA00-$BA7F` : ligne en cours d'édition ; `$BA80-$BB7F` : historique des lignes), écran texte | idem |
| `$C000-$FFFF` | RAM overlay chargée depuis la disquette : code jusqu'à `$F670` (fin réelle `$F65D`), puis tampons (ligne de commande `$F670`, DO `$F6C0`, PUT `$F7C0-$FCFF`), variables du BDOS `$FD00`, tampon de secteur `$FE00`, page `$FF00-$FFF9` apparemment libre (aucune référence dans les sources), vecteurs `$FFFA` | ROM : code jusqu'à `$E3A0` environ, reste libre |

## 4. Construire et tester

Détail complet (outils, scénarios, installation sur Raspberry Pi) : `docs/atelier.md`.

    ./tools/setup_linux.sh [roms]    # une fois, sur Linux : xa, py65, Oricutron de test
    ./build.sh                       # build/cpa.rom, build/cpa.dsk (+ contrôles de taille)
    tools/smoke_test.sh              # construction + démarrage disquette et ROM dans l'émulateur
    tools/test_asm.sh                # ASM.COM doit redonner les octets de xa
    tools/test_logo.sh               # LOGO.COM : scénarios comparés aux références
    python3 tools/test_fp.py         # décimaux (progs/fp_inc.s) contre un calcul exact

- `build.sh` refuse un système disque qui dépasse `$F670` et une ROM qui ne fait pas 16 Ko.
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
| Avant un commit de version, ou sur demande | tout |

## 5. Conventions

- Fichiers `progs/*_tab.s` (tables) et `progs/*_inc.s` (bibliothèques) : inclus par un
  programme, jamais assemblés seuls.
- Assembleur : syntaxe `xa` de l'OSDK. Les programmes de `progs/` restent dans le sous-ensemble
  compris par ASM.COM (pas de `&étiquette`, pas de `#define`) : `tools/test_asm.sh` le vérifie.
  Le système (`src/`) peut utiliser tout `xa`.
- Pièges de `xa` : une étiquette locale de bloc `.( .)` ne peut pas porter le nom d'une
  étiquette globale déjà définie ; pas d'étiquette nommée comme une instruction ; branchements
  limités à ±127 octets (passer par un `JMP`).
- Textes à l'écran : ASCII sans accents, 37 colonnes au plus pour une ligne complète (la 38e
  provoque un retour à la ligne automatique en plus). Messages du CCP en anglais court, aide et
  programmes en français.
- Commentaires et documentation en français.
- Aide : `tools/gen_readme_txt.py` produit à la fois `files/readme.txt` (README.TXT) et
  `progs/help_tab.s` (HELP.COM) à partir d'une seule liste.
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
| `docs/` | ce document, les deux projets, notes matérielles (modem WiFi du LOCI) |
| `build/` | résultats ; seuls `cpa.dsk` et `cpa.rom` sont versionnés |
