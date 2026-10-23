# Essais sur le vrai matériel

Pierre essaie sur un Oric Atmos avec un LOCI. Ce document n'est pas à lire à chaque
conversation : seulement pour savoir quoi faire vérifier, ou pour noter un résultat. Une
livraison ajoute ses points à « À vérifier » ; un point vérifié passe dans « Vérifié ».

## À vérifier sur Oric Atmos + LOCI

**Système**

- clavier : CTRL avec une lettre (CTRL-I, H, J, K différents des flèches), CTRL-ESPACE et
  CTRL-@ (code 0), SHIFT et CTRL avec les quatre flèches (`GET K` puis `PRINT K` dans un
  `.GRX` : CTRL-I 29, CTRL-ESPACE 0, SHIFT-← 240, CTRL-↓ 246) ; CTRL avec un chiffre : rien ;
  frappe rapide avec SHIFT ou CTRL tenue (pas de touche perdue ni doublée) ;
- prompt : TAB complète comme ESC, SHIFT-←/→, CTRL-U ; CTRL-C sur ligne vide redémarre au
  prompt, mais pas dans LOGO ;
- complétion des commandes par ESC sur tous les lecteurs (programme présent seulement sur
  B:) ;
- recherche des programmes limitée aux lecteurs déjà lus : rien ne doit changer avec le LOCI ;
- image faite par `mkdisk.py` en entrelacement 2:1 : démarrer, faire un COPY ;
- HIRES plein écran : bascule du circuit vidéo, les 3 lignes du bas noires ;
- VSYNC : réglage du top, tenue du réglage après d'autres commandes.
- **RESET pendant un enregistrement** (sur une **copie** de disquette, jamais sur
  l'original) : `EDIT` d'un texte de quelques Ko, une modification, CTRL-S puis RESET aussitôt,
  une dizaine de fois en variant l'instant (pendant que le voyant du lecteur est allumé) ;
  de même `GRAPHER` avec un `SAVE` d'un gros tableau. Chaque fois : `DIR` doit marcher (pas
  de `BDOS: disk I/O error` : un secteur du répertoire coupé au milieu ; le RESET doit
  maintenant attendre la fin du secteur), le fichier doit être l'ancien ou le nouveau, entier
  (`TYPE`), ou le nouveau dans `NOM.$$$` ; `ERA *.$$$` ensuite. Rapporter la disquette sur le
  PC : `python3 tools/mkdisk.py check` sans défaut ;
- RESET hors des accès disque : toujours immédiat (`*RESET* at ...`), comme avant.
- **`cpa-en.dsk`** : démarrer, puis TYPE, ERA (réponse `Y`), COPY, STAT, FORMAT B: (`Y`),
  DISKCOPY, XDO, MEM, VOIR, VSYNC, EXPORT, IMPORT, USBDIR avec le LOCI : messages en
  anglais, 37 colonnes au plus, rien de coupé ;
- **`cpa-en.dsk`, EDIT, HEX, ASM, DEBUG** : dans EDIT, ouvrir les quatre menus (File, Edit,
  Search, Options : cadres entiers, rien sous les voyants), CTRL-H avec réponse `A` (tous),
  Quitter un texte modifié avec `Y` ; `EDIT X.LOG` : Options montre `>` devant Line
  (`EDIT.CFG` anglais, mot `LINE`) ; sur `cpa.dsk`, `EDIT.CFG` français inchangé (MOTS,
  LIGNE). HEX : menus File, Go to, Mode. `ASM HELLO /S`, puis un source fautif : messages
  d'erreur anglais. `DEBUG HELLO`, `H` : l'aide tient en 37 colonnes ; en français aussi
  (lignes « Indic. » et « Programme termine » raccourcies) ;
- **`cpa-en.dsk`, CMDER** : `CMDER` : barre File, Mark, Sort, View (quatre menus entiers),
  colonnes `NAME TYP SIZE RS N KIND`, genres anglais (Text, Temp, Disk) ; touches 1 à 4 :
  signe `+` collé au bon titre ; Vue, Hide SYS devient Show SYS ; DEL sur un fichier :
  `Erase NOM.EXT (Y/N) ?` ; copie vers B: avec `A` (all) si les fichiers existent ;
  `CMDER A: B:` (en-têtes `NAME TYP KB`) ; `CMDER USB:` et `CMDER A: USB:` avec le LOCI
  (`<DIR>`, tri par taille : `+SIZE`) ; sur `cpa.dsk`, `CMDER USB:` puis `4` : `+TAILLE`
  (le signe écrasait le T) ;
- **`cpa-en.dsk`, GRAPHER et GRXASM** : `GRAPHER` seul (usage `GRAPHER NAME...`),
  `GRAPHER ZZ` (`File not found`), un `.GRX` qui fait `LINE` sans `HIRES`
  (`L n LINE : HIRES or SPLIT first`), ESC pendant `WAIT` (`Interrupted`) ;
  `GRXASM DESSIN` (`DESSIN.ASM written: ASM DESSIN`), `TYPE DESSIN.ASM` : en-tête en
  anglais ; `ASM DESSIN` puis `DESSIN` : dessin comme sur `cpa.dsk` ; `VOIR` sur un
  fichier `.ANI` qui n'en est pas un : `not an animation`. Sur `cpa.dsk` : les mêmes,
  messages français inchangés ;
- **`cpa-en.dsk`, HELP et README.TXT** : `TYPE README.TXT` (QUICK REFERENCE) ; `HELP` seul,
  puis `HELP KEYS`, `HELP PROG`, `HELP MEMO`, `HELP GRAP` (rubrique longue : pause en fin
  d'écran), `HELP XYZ` (`Unknown topic.` puis l'aide par défaut) ; 37 colonnes au plus,
  rien de coupé. Sur `cpa.dsk`, `HELP TOUC` inchangé ;
- **Disquettes anglaises** (`cpa-en.dsk`, `cpa-logo-en.dsk`, `cpa-asm-en.dsk`,
  `cpa-anim-en.dsk`, `cpa-notes-en.dsk`) : chacune démarre, `DIR` / `DIRS` montrent les noms
  anglais. Exemples : `GRAPHER ARROWS` (`Arrows, Q: quit      Steps:`), `GRAPHER SCORES`
  (HIGH SCORES en jaune, `Your name:`), `GRAPHER SNAKE` (`Length:`, puis `LOST!`), `GRAPHER
  ROAD` (`Lost! Score:`), `GRAPHER MAP` (TILES.SPR), `GRAPHER SPRITES` (HERO.SPR), `GRAPHER
  PATTERNS` (STARS centré), `GRAPHER PUZZLE`, `GRAPHER ROTSCROL` ; `LOGO DEMO` puis `DEMO`,
  `LOGO ELIZA2` (une petite conversation en anglais, `GOODBYE`), `LOGO PLOTSQR`, `LOGO
  ARROWS` ; sur `cpa-anim-en.dsk`, `DEMO` (BALL.ANI, SHIP.ANI, puis `GRAPHER ANIMS`) ; sur
  `cpa-asm-en.dsk`, `ASM GTEST` puis `GTEST` (`Picture drawn.`). Sur `cpa.dsk` : `GRAPHER
  ROTSCROL` et `GRAPHER JEU`, nouveaux sur la disquette ;
- **LOGO en anglais** (`cpa-logo-en.dsk`) : `LOGO` (barre File, Turtle, Help ; `HELP`),
  `REPEAT 4 [FD 40 RT 90]`, `TO SQ :S` ... `END`, `PO "SQ` (finit par `END`), une erreur
  (`I don't know how to ...`), `LOGO DEMO` puis `DEMO`, `LOGO ELIZA2` (conversation,
  `GOODBYE`), `LOGO ARROWS`, `EDIT "TEST` puis Back (retour dans LOGO). `LOGOTR` : sur
  `cpa-logo.dsk`, `LOGOTR DEMO TEST /EN` puis `TYPE TEST.LOG` ; sur `cpa-logo-en.dsk`,
  `LOGOTR DEMO FR /FR` puis `TYPE FR.LOG` ; `LOGOTR DEMO` (vers l'anglais, sur place) :
  `DEMO.BAK` gardé ; un fichier protégé (`File protected`, texte dans `DEMO.$$$`). Sur `cpa-logo.dsk`, LOGO français inchangé,
  `LOGO DEMO` (le `CHARGE "DEMO` tapé au démarrage, réécrit) ;
- **barre de menus du système** : sur `cpa.dsk` puis `cpa-en.dsk` (System, Files, Screen,
  Keyboard), ouvrir chaque menu : raccourcis `^P`, `^T`, `^C` alignés à droite, cadres
  entiers ; Ecran / Screen plus large (13 / 12). **Couleurs sur le vrai écran** : pour chaque
  papier (`PAPER 0` à `PAPER 7`, avec `INK` contrasté), ouvrir Systeme et descendre d'un
  article : fond, encre des articles et de la sélection comme le tableau de
  `src/menu_col.s` (papier noir : menu blanc, articles magenta, sélection bleue) ; même
  chose dans un menu d'EDIT. Sur `cpa-en.dsk` : `-- More (^C stop) --` en fin d'écran
  (`HELP EDIT`), `PAUSE` (`Press a key to go on...`), ESC pendant un script
  (`Script stopped.`) ;
- **deux disquettes** (`cpa.dsk` en A:, `cpa-projet.dsk` en B:, avec CARTE.GRX et
  TUILES.SPR copiés dessus) : `B:`, puis `GRXASM CARTE /C` ; il ne reste sur B: que
  CARTE.COM, qui se lance (`CARTE`) ; les bibliothèques et CPA.INC ont été lues sur A:.
  Puis `GRXASM CARTE` et `ASM CARTE /S` : CARTE.ASM, CARTE.COM, CARTE.SYM sur B: ;
  `GRAPHER CARTE /C` donne la même chose. Avec un seul lecteur (disquette système puis de
  projet dans le même lecteur), on ne peut pas : les bibliothèques doivent être sur la
  disquette du projet ;
- EDIT d'un fichier de plus de 32 000 octets (CARTE.ASM) : `Fichier tronque : trop gros`,
  CTRL-S refusé (`Texte tronque : Enreg. sous...`), Enreg. sous un autre nom accepté ;

**Programmes**

- EDIT : Enreg. sous... un fichier existant (`Remplacer NOM.EXT (O/N) ?`, N puis O), sous un
  fichier R/O (`Fichier protege (R/O)`, aucun `NOM.$$$` ne reste), depuis README.TXT (R/O)
  sous un nouveau nom ; disque plein (copie de disquette remplie) : `Disque plein : non
  enregistre`, l'ancien fichier intact ;
- GRAPHER : `SAVE`, `BSAVE` d'un fichier R/O (`fichier protege`), disque plein (`disque
  plein`, ancien intact, pas de `NOM.$$$`) ;
- EDIT : impression (`^P`) et coupure à la largeur sur une vraie imprimante ; `^I` (insérer
  un fichier) ; `C nnn!`, `^L` (trop long), Statistiques ; nouvelles touches : CTRL-ESPACE,
  CTRL-X/C/V, ESC (marque ôtée : `M` disparaît de la ligne d'état), CTRL-K, CTRL-H, CTRL-O,
  CTRL-Q, SHIFT et CTRL avec les flèches (CTRL-←/→ : de mot en mot, à travers les fins de
  paragraphe) ; libellés des menus (largeur) ;
- HEX et CMDER : SHIFT et CTRL avec les flèches, TAB (mode HEX/ASCII ; autre colonne),
  `^L` et `^R` dans HEX, `^X` (déplacer) et `^Q` dans CMDER ;
- LOGO : CTRL-C interrompt une boucle (`REPETE 30000 [DR 1]`) comme ESC ;
- ASM : un assemblage (jamais lancé sur le vrai Oric ; lectures et écritures alternées sur la
  disquette) ;
- DEBUG en usage réel : points d'arrêt, pas à pas ;
- HEX : écriture sur place ;
- disquettes par usage (`cpa-logo`, `cpa-notes`, `cpa-asm`) : DIR, DIRS, STAT, `ASM HELLO`.
- tabulations : un `.GRX` écrit sur le Mac avec des tabulations (retrait et séparateurs),
  passé par `IMPORT nom /T` puis par CMDER (`Copier texte...`, ou `/T` à la fin de la
  réponse) : plus aucune tabulation sur la disquette (EDIT, HEX), fins de ligne CR LF ;
  `GRAPHER NOM` le lance sans erreur ; le même fichier importé sans `/T` (tabulations
  gardées) tourne aussi dans GRAPHER et dans un programme traduit par `GRXASM`.
- TERM (Pico W en modem USB, firmware sans le redémarrage à 1200 bauds :
  `docs/loci-modem-wifi.md`) : première ligne `modem du LOCI (ACIA 0380)` ; pas de
  `Pas de modem (DSR)` avec le Pico branché, le message sans lui ; `AT` -> `OK`, `ATI`,
  DEL efface (le modem renvoie BS espace BS) ; `ATDT-IP:2323` vers `nc -l 2323` sur le Mac,
  caractères dans les deux sens (`TERM /E` pour voir ce qu'on tape) ; `+++` puis `ATH` ;
  une longue réception (`cat` d'un gros texte dans `nc`) : rien de perdu ni de doublé pendant
  le défilement de l'écran ; FUNCT pendant une réception : la suite arrive à la sortie du
  menu ; CTRL-Q, puis `TERM` à nouveau : la connexion est toujours là. Que le VIA ne voie pas
  les écritures en `$0380-$0383` (le clavier et le son marchent toujours après TERM).
  `TERM /D` : après le réglage, commande `0B` et contrôle `1E` relus (sinon les écritures
  n'arrivent pas au LOCI, cf. ticket 17 de loci-firmware) ; bit 6 de l'état à 0 avec le Pico.
  Après une mise hors tension de l'Oric et du LOCI (état neuf) : `TERM /D` relit-il `70 02 00`
  au premier affichage ? `TERM /B /E` puis `ATDT-IP:2323` vers `nc -l 2323` : le texte tapé
  arrive-t-il sur le Mac (écritures bonnes, lectures fausses) ?

**LOGO**

- son : SON, SONF, BRUITV, ENVELOPPE, MELANGE, ENSEMBLE, ATTENDSSON, JOUE?, coupure par ESC ;
- LISCAR, TOUCHE?, mots et listes, LISLISTE ;
- RACINE, SIN, COS, ARCTAN, LN, EXP ; RENDS (FACT, FIBO, profondeur) ;
- ECRANTEXTE et ECRANMIXTE (aussi par le menu Tortue) ;
- EDITE et Retour d'EDIT (temps d'écriture et de lecture de `LOGO.$$$`, image gardée) ;
  `LOGO NOM` ;
- écran texte : `FLECHES.LOG`, couleurs par `FIXECARECRAN 0 l n`.

**EDIT**

- modes d'affichage : CTRL-W passe de « Coupure entre les mots » à « Coupure a 38
  caracteres » puis « Ligne entiere (defilement) » (message sur la ligne d'état) ; menu
  Options : `>` devant le mode en cours, les trois articles y mènent directement ; un
  `.ASM` ou un `.GRX` s'ouvre en mode ligne (`EDIT.CFG` livré) ; en mode ligne, sur un
  paragraphe de plus de 38 caractères, SHIFT-→ décale la fenêtre (toutes les lignes avec
  elle, `<` et `>` sur la ligne d'état), la frappe au bout de la ligne la fait suivre de 10
  en 10 colonnes, SHIFT-← la ramène à gauche ; vitesse du redessin à droite d'une longue
  ligne (frappe continue) ;
- SHIFT-→ puis ↓ ou ↑ (tous les modes) : le curseur reste en bout de ligne sur une ligne
  plus courte, à la même colonne sur une plus longue (avant : il revenait au début) ;

**GRAPHER, VOIR, animations**

- tuiles : `CARTE.GRX` en interprété (`GRAPHER CARTE`), puis traduit (`GRXASM CARTE`,
  `ASM CARTE`, `CARTE`) : dessins de l'eau, de l'herbe, des murs, des arbres, des montagnes
  et du joueur nets (jeu secondaire, attribut 9 en colonne 0) ; redessin d'une fenêtre à
  chaque pas (environ 55 ms : déchirure visible ?) ; au bord de l'île, la mer continue
  au-delà de la carte ; on ne traverse ni eau, ni arbre, ni mur, ni montagne ; Q, puis
  `DIR` et une ligne rappelée par ↑ : police et console normales (historique vidé) ;
- sprite sur des tuiles : le test `lo_tile3.grx` (`tools/grapher_tests`, avec `TUIL.SPR`
  et `HERO.SPR`) copié sur une disquette et lancé : le bonhomme laisse voir le cadre et
  les traits des tuiles autour de lui, yeux noirs, sur les lignes du jeu secondaire comme
  sur celles du jeu standard ;
- hasard (xorshift 32 bits) : `CARTE.GRX` (arbres, montagnes, lacs répartis sur toute la
  carte, sans bandes, en interprété puis traduit par `GRXASM CARTE` et `ASM CARTE`) ; deux
  lancements de suite donnent deux mondes différents ; `MOTIFS.GRX` (ciel étoilé) ;
- `CARTE.GRX` par `INKEY` : pas de scintillement à l'arrêt, une flèche maintenue fait avancer
  sans délai de répétition (vitesse en interprété, puis traduit), le joueur bute sur les
  obstacles sans redessin, Q (majuscule ou minuscule) arrête ;
- ESC : en interprété, il arrête `CARTE`, `SERPENT`, `ARDOISE` à tout moment ; traduits
  (`GRXASM`, `ASM`), ces jeux continuent sur ESC et s'arrêtent par Q ; `ANIMS` traduit :
  ESC finit l'animation sans arrêter le programme ;
- `FLECHES.GRX` (couleurs, flèches, `INKEY` sans délai), `ARDOISE.GRX` (dessin continu tant
  qu'on tient la flèche) ;
- en LORES : FUNCT et CTRL-T sans effet ; retour à la console par ESC, fin normale et RESET ;
- `MOTIFS.GRX` et `ECRAN.GRX` attendent une touche avant de finir ;
- `SERPENT.GRX`, `SCORES.GRX` (saisie au curseur) ; un programme traduit avec tableaux (ASM sur
  la disquette Assembleur) ;
- animations : déchirure, flèches gauche / droite, débit ;
- GRAPHER séparé de GRXASM : `GRAPHER MOTIFS /A` (passage par CHAIN, `GRXASM motifs /a`
  affiché), puis `ASM MOTIFS` et `MOTIFS` ; `GRXASM MOTIFS` directement ; un `.GRX`
  interprété de chaque sorte (HIRES, SPLIT `DESSIN`, LORES, tableaux) ; sur la disquette
  Logo, `GRAPHER X /A` doit dire que GRXASM est introuvable.
- fichiers de données : `SCORES.GRX` deux fois (le 2e lancement retrouve les scores ;
  `TYPE HOFN.TXT`, `EDIT HOFS.TXT`) ; `HOFS.TXT` modifié dans EDIT puis relu ; temps
  d'écriture d'un gros tableau ; disque plein ; traduit (`GRXASM SCORES`, `ASM SCORES`).
- sprites : `SPRITES.GRX` (bonhomme aux flèches, balle) : netteté des dessins sur le décor,
  couleur prise de la ligne, scintillement au déplacement, vitesse ; ESC puis `DIR` (police
  et console rendues) ; traduit (`GRXASM SPRITES`, `ASM SPRITES` : durée de l'assemblage,
  puis `SPRITES`).
- variables de deux caractères (`PX`, `N1`) : un jeu en LORES qui s'en sert, interprété puis
  traduit (`GRXASM`, `ASM`) ; les boucles `FOR` d'un programme traduit déjà connu
  (`MOTIFS`, `SERPENT`) tournent comme avant (blocs `Bn` de 6 octets) ; un gros `.GRX` près
  de la limite (environ 20 Ko au lieu de 22) : `Fichier trop gros` au bon moment.
- GRXASM optimisé : un jeu traduit (`MONSTRE2`, `SERPENT`, `SPRITES`) tourne comme en
  interprété ; `ASM` lit le nouveau `.ASM` (un espace devant les instructions, directives en
  colonne 1) et met moins de temps qu'avant.
- tableaux à adresse fixe : `MONSTRES` (ou `SERPENT`, `SPRITES`, `SCORES`) traduit de nouveau
  (`GRXASM`, `ASM`) tourne comme en interprété, et nettement plus vite ; `ASM` accepte la fin
  du `.ASM` (`G_INIT`, `TR_x .byt`, `T_x = $9Dxx`) ; `SCORES` traduit retrouve ses scores
  (`LOAD`, `SAVE` sur des tableaux fixes) ; un tableau trop grand pour la mémoire donne
  `memoire pleine` dès le lancement.
- bibliothèques recopiées par GRXASM : `GRXASM SPRITES` puis `ASM SPRITES` (durée de chacun,
  place sur la disquette pendant la traduction : `SPRITES.ASM` fait 34 Ko) ; `SPRITES`,
  `SERPENT`, `SCORES`, `MOTIFS` traduits tournent comme en interprété ; `GRXASM` sur un
  lecteur sans `GRX.INC` dit `GRX.INC absente (bibliotheque)` et n'écrit pas de `.ASM`.
- rectangles : `CARTE.GRX` (la fenêtre suit le joueur aux flèches, `PASTE` : temps de
  construction du monde en interprété, scintillement ou déchirure du redessin), `DEFILE.GRX`
  (route qui défile, `SCROLV` : régularité, vitesse en interprété puis traduit par
  `GRXASM DEFILE` et `ASM DEFILE`) ; `ROTH` et `ROTV` sur une bande de décor ; `PRINTV`,
  `ECHOV`, `SPCV` (colonnes de texte, murs) ; dans l'image, `SCROLV` en HIRES plein écran
  (durée, environ 150 ms) et en SPLIT (la console sous l'image reste intacte).
- traduit sans contrôles : `SERPENT`, `SPRITES`, `DEFILE`, `CARTE` traduits de nouveau
  (`GRXASM`, `ASM`) tournent comme en interprété, plus vite ; Q les arrête ; une boucle qui ne lit pas le clavier (`WHILE 1` ... `NEXT`) ne s'arrête que par le
  bouton RESET, qui rend le système ; `MOTIFS` (ciel étoilé, `RND`) : les étoiles restent bien
  réparties.

## À vérifier ailleurs

- **Vrai Microdisc** : FORMAT, DISKCOPY, attributs et COPY avec jokers ; premier accès après
  une pause de plus de 3 s (TYPE, PUT, FORMAT).
- **Clock Signal** (simule la rotation et le chargement de tête) : premier accès après plus
  de 3 s. Ses images ne sont pas fiables après écriture : en réécrivant une piste dans le
  fichier, il ne garde que deux des trois `$A1` de chaque synchronisation (Oricutron et le
  LOCI n'y trouvent plus rien) et peut fausser le CRC d'un secteur (« disk I/O error » à la
  relecture) ; `mkdisk.py check` le montre, `mkdisk.py repare` remet l'image d'aplomb. Son
  Write Track ne marche pas sur un 1793 : FORMAT y reste bloqué sur la piste 0 ; n'y utiliser que A: et des commandes qui existent tant que la version à quatre
  lecteurs n'est pas construite.

## Vérifié

Sur Oric Atmos + LOCI, version disquette :

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

Pour la version ROM : voir `docs/projet-rom.md`.
