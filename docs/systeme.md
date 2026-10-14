# CP/A — fonctionnement interne du système

Ce qui n'est pas dans le contrat d'interface (`docs/architecture.md`) mais qu'il faut savoir
avant de toucher au BIOS, au BDOS ou au CCP. Variables des pages 2 et 3 :
`docs/memoire-pages-2-3.md`.

## 1. Console et clavier

- **Lecture de ligne dans le BDOS** (fonction 10, `src/rline.s`), pas dans le CCP : LOGO et
  DEBUG en profitent, et la ROM l'a (sans la complétion). La ligne est éditée en `$BA00`
  (126 caractères au plus), l'historique est en `$BA80-$BB7F` (fin du jeu de caractères
  secondaire). Un seul historique pour le CCP et les programmes ; il est gardé au démarrage
  à chaud, sauf après un HIRES plein écran (zone recouverte par l'image).
- Flèches : gauche `$08` n'efface pas (DEL le fait), bas `$0A` ne valide pas la ligne.
  CTRL-I vaut `$09`, la flèche droite : la complétion est donc sur ESC.
- **Complétion par ESC** (comme `filec` du C-shell) : elle lit le répertoire directement
  (`dir_get`), sans toucher au DMA ni au FCB des programmes ; seule une recherche 17/18 en
  cours chez l'appelant serait perdue. Pas de jokers ; noms en minuscules quand les
  majuscules sont coupées. Au premier mot de la ligne du CCP (option `CPLCMD`, commit à part,
  `DISK_OPTS="" ./build.sh` pour s'en passer) : commandes internes, puis `.COM` / `.BAT` sans
  leur type, sur les lecteurs que parcourt la recherche des programmes (§ 3, `drv_ok`), sans
  message d'erreur. Noms déjà vus dans `CP_TAB` (`$B800`, zone de sauvegarde des menus,
  libre pendant ESC ; 39 noms). Pas dans LOGO ni DEBUG.
- **Majuscules** : verrouillage gardé ; le CCP et LOGO passent leurs lignes en majuscules,
  mais les fonctions 1 et 10 rendent ce qui est tapé (comme CP/M).
- **Voyants** (barre de menus) : colonne 37 `A`/`a` (majuscules), colonne 38 `P`
  (imprimante) ; colonnes 35-36 libres (réseau plus tard). `draw_flags`.
- `PAPER`, `INK` (attributs de tête de chaque ligne de la console, `apply_colors`, même
  couleur permise) et `PAGE ON/OFF` (`page_on`) sont des commandes internes, donc aussi
  dans la ROM ; réglages gardés jusqu'au démarrage à froid.

## 2. Écran

- **SPLIT** : l'attribut HIRES est en `$BFDF`, comme le BASIC (en `$BB80`, il masquait la
  ligne de points 0 sur le vrai circuit). La ligne de texte 27 ne contient que des
  attributs : la console SPLIT a 10 lignes (`con_last`). Seul `$B3D8` (retour au texte) est
  pris dans l'image.
- **Écran au programme** (`hires_on`) : HIRES plein écran (`$1E` en `$BFDF` hors SPLIT) ou
  LORES (`SCR_PROG` = 1). FUNCT ne fait rien, CTRL-T et CTRL-P arrivent comme des touches,
  voyants non dessinés, pas de clignotement ni de pause. Le démarrage à chaud remet le texte,
  la police, l'écran et la barre ; `video_text` recopie la police.
- Tables `g_ylo` / `g_yhi` du SPLIT calculées par `font_init` en `$B400-$B4FF` (glyphes des
  codes 0-31, jamais affichés).

## 3. Disques

- **Pilote** (`src/disk.s`) : lecteur dans les bits 5-6 de `$0314`. Le WD1793 n'a qu'un
  registre de piste, rangé par lecteur (`dsk_trk`) au changement (`md_sel`) ; après un
  changement, un déplacement de tête est toujours fait (Oricutron n'a qu'une position de tête
  pour tous ses lecteurs). Le lecteur des accès est `buf_drv`, celui du secteur en cache : un
  secteur modifié est toujours réécrit sur son lecteur.
- **Attentes** : premier octet d'un secteur ~2,9 s au plus (`dsk_to2`) : sur un vrai
  Microdisc, la tête se lève après ~3 s sans commande et le moteur avec elle, et le premier
  octet arrive ~1 s après. L'attente ne coûte rien quand le contrôleur répond. Déplacements :
  ~3 s, puis Force Interrupt et échec sans nouvel essai.
- **LOCI** : aucune commande pour un lecteur que le LOCI n'a pas monté (sa tâche disque se
  bloque jusqu'au redémarrage du LOCI). `loci_abs` le vérifie avant de changer de lecteur et
  au début de `disk_read`, `disk_write`, `disk_home`. Source : la configuration du menu du
  LOCI en XRAM (`"LOCI"` en `$8000`, `mounts` en `$800B`), lue par la fenêtre 1
  (`$03A8-$03AB`). LOCI reconnu à la marque `L` en `$0319`. Signature absente ou octet
  invraisemblable : on laisse passer.
- **Système de fichiers** (`src/fs.s`) : `set_fcb` choisit le lecteur au début de chaque
  fonction (`drv_select`) ; une carte d'allocation par lecteur (4 × 22 octets en `$FD00`),
  faite à la première utilisation depuis le dernier démarrage à chaud (`log_vec`). Lecteur
  inconnu ou illisible : `$FF`. Changer de disquette demande un CTRL-C, comme sous CP/M.
  Démarrage à chaud : lecteur courant gardé et relu, retour en A: s'il ne répond plus.
- **Recherche des programmes et des scripts** (`open_com`) : un `.COM` ou `.BAT` tapé sans
  lecteur (aussi par DO et XDO) est cherché sur le lecteur du script en cours (au prompt : le
  courant), puis A: à D:, sans essayer deux fois le même. Un lecteur sans réponse est noté
  dans `bad_vec` (remis à 0 au démarrage à froid) et sauté ensuite, sauf s'il est le premier
  essayé. Sans LOCI, B:, C:, D: ne sont essayés que s'ils ont été lus depuis le démarrage à
  froid (`seen_vec`) : un lecteur vide coûte plusieurs secondes sur un vrai Microdisc. Les
  lecteurs essayés après le premier ne donnent pas « BDOS: disk I/O error » (`io_quiet`, bit
  7 = erreur survenue ; remis à 0 au démarrage à chaud). Un nom avec lecteur n'est cherché
  que là. Écartés : un `PATH` (variable de plus dans le contrat), un `$D` dans les scripts.
- **Format** : 2 faces, 42 pistes, 17 secteurs de 256 octets, entrelacement 2:1 (1, 10, 2,
  11... 9) pour `mkdisk.py` et FORMAT (sans lui, un vrai Microdisc lit un secteur par tour).
  Blocs de 2 Ko. Système en LSN 0-67.

## 4. CCP et scripts

- **Lancement** : `NOM.COM`, puis `NOM.BAT` (comme `.SUB` de CP/M 3) ; un autre type tapé
  donne `NOM.EXT?`. Un script lancé par son nom passe par DO (`NOM a b` = `DO NOM a b`).
- **DO** fixe le lecteur de son script à l'ouverture. Les `$1`-`$9` sont un remplacement de
  texte : les scripts n'ont ni calcul, ni variable, ni condition (pour cela : LOGO, GRAPHER ou
  un `.COM`).
- **Appel de script à script** (XDO.COM) : DO appelé pendant un script enchaîne (CHAIN) sur
  `XDO NOM paramètres`, qui lit l'état de l'appelant dans les zones de DO (`SCR_ON`,
  `SCR_IDX`, `SCR_FCB`, `SCR_BUF`, `SCR_PAR`, `ORIG_LINE`), lit le script appelé et la fin de
  l'appelant, fait les remplacements, écrit `$$$.BAT` (sur le lecteur courant) et enchaîne sur
  `DO $$$`. Tout est lu avant d'écrire. Limites : disquette protégée en écriture, ligne
  d'appel de 78 caractères, sans XDO.COM la ligne d'appel est sautée.
- **CHAIN** (BDOS 47) : ligne recopiée en `$0400`, `chain_on` (`$0244`) à 1, démarrage à
  chaud ; le CCP l'exécute avant toute ligne d'un script DO.
- **PUT** n'écrit jamais sur le disque pendant un affichage : tampon de 1 280 octets vidé à
  l'entrée de l'appel BDOS suivant, état du système de fichiers sauvé puis rendu.
- TYPE, ERA et REN sont des `.COM` (place résidente) ; le menu Fichiers tape toujours leur
  nom.

## 5. Imprimante et son

- **LIST** : octet sur le port A du VIA (partagé avec l'AY : interruptions coupées le temps
  de l'écrire et du strobe), front descendant de PB4 (au repos à 1 ; `kb_row` préserve les
  bits 3-7 de ORB), accusé CA1 attendu ~2 ms au plus. CTRL-P bascule `lst_echo` pendant la
  lecture d'une ligne ; pendant l'édition, la copie est suspendue (bit 7) et la ligne finale
  est imprimée par RETURN. Oricutron écrit dans `printer_out.txt`.
- **Son, SYNC et MIXER** (opérations 7 et 8) : en préparation, NOTE, NOISE et TONE écrivent
  période et mélangeur tout de suite, coupent la voix et retiennent volume et durée (`s_pvol`,
  `s_pdur`) ; ENV retient l'écriture du registre 13. Le départ écrit, interruptions masquées,
  le registre 13 si besoin puis les volumes et durées. Une voix qui jouait change donc de
  note quelques millisecondes avant le départ. Le démarrage à chaud remet `s_hold` à 0.

## 6. Place

Mesurer par module et par routine avec `build/cpa_sys.sym`. Les plus gros postes : `fs.s`,
`bios.s`, `gfx.s`, `menu.s`, `ccp_disk.s`, `rline.s`, tables, police. La page `$FF00`
(`src/tables_ff.s`, écrite par `tools/gen_tables.py`) reçoit les tables de l'écran texte et du
clavier. Réserves : `docs/etat.md` § 3.
