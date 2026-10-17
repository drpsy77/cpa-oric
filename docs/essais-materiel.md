# Essais sur le vrai matériel

Pierre essaie sur un Oric Atmos avec un LOCI. Ce document n'est pas à lire à chaque
conversation : seulement pour savoir quoi faire vérifier, ou pour noter un résultat. Une
livraison ajoute ses points à « À vérifier » ; un point vérifié passe dans « Vérifié ».

## À vérifier sur Oric Atmos + LOCI

**Système**

- complétion des commandes par ESC sur tous les lecteurs (programme présent seulement sur
  B:) ;
- recherche des programmes limitée aux lecteurs déjà lus : rien ne doit changer avec le LOCI ;
- image faite par `mkdisk.py` en entrelacement 2:1 : démarrer, faire un COPY ;
- HIRES plein écran : bascule du circuit vidéo, les 3 lignes du bas noires ;
- VSYNC : réglage du top, tenue du réglage après d'autres commandes.

**Programmes**

- EDIT : impression (`^P`) et coupure à la largeur sur une vraie imprimante ; `^L` ;
  `C nnn!`, `^N`, Statistiques ;
- ASM : un assemblage (jamais lancé sur le vrai Oric ; lectures et écritures alternées sur la
  disquette) ;
- DEBUG en usage réel : points d'arrêt, pas à pas ;
- HEX : écriture sur place ;
- disquettes par usage (`cpa-logo`, `cpa-notes`, `cpa-asm`) : DIR, DIRS, STAT, `ASM HELLO`.

**LOGO**

- son : SON, SONF, BRUITV, ENVELOPPE, MELANGE, ENSEMBLE, ATTENDSSON, JOUE?, coupure par ESC ;
- LISCAR, TOUCHE?, mots et listes, LISLISTE ;
- RACINE, SIN, COS, ARCTAN, LN, EXP ; RENDS (FACT, FIBO, profondeur) ;
- ECRANTEXTE et ECRANMIXTE (aussi par le menu Tortue) ;
- EDITE et Retour d'EDIT (temps d'écriture et de lecture de `LOGO.$$$`, image gardée) ;
  `LOGO NOM` ;
- écran texte : `FLECHES.LOG`, couleurs par `FIXECARECRAN 0 l n`.

**GRAPHER, VOIR, animations**

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
  (`GRXASM`, `ASM`) tournent comme en interprété, plus vite ; ESC les arrête par `INKEY` ou
  `GET` ; une boucle qui ne lit pas le clavier (`WHILE 1` ... `NEXT`) ne s'arrête que par le
  bouton RESET, qui rend le système ; `MOTIFS` (ciel étoilé, `RND`) : les étoiles restent bien
  réparties.

## À vérifier ailleurs

- **Vrai Microdisc** : FORMAT, DISKCOPY, attributs et COPY avec jokers ; premier accès après
  une pause de plus de 3 s (TYPE, PUT, FORMAT).
- **Clock Signal** (simule la rotation et le chargement de tête) : premier accès après plus
  de 3 s ; n'y utiliser que A: et des commandes qui existent tant que la version à quatre
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
