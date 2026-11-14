# CP/A disquette — suite prévue (par priorité)

Ce qui est décidé, envisagé ou écarté, par points numérotés. Ce qui est fait n'est pas
ici : l'état est dans `docs/etat.md` (avec la liste de la version 1.0), le mode d'emploi et
la mise en œuvre dans la référence de chaque programme, les réserves de place dans
`docs/place.md`.

Ordre fixé d'après `docs/vision.md` : créer, développer et compiler, publier, échanger.

**En cours** : les lots de la revue du projet (`docs/revue.md` : sûreté des fichiers,
documents, dépôt, optimisations).

**Tâche suivante : vidéo LOGO**, fabriquée sur le banc (Phosphoric natif, `--video` AVI
avec le son, frappe par `--type-keys`), montée par ffmpeg (longues frappes accélérées
× 3-4, sous-titres courts en français) ; une première version de 3-4 min. Programmes
**tapés puis exécutés** (graphisme, interactivité, variables) :
1. Château (`files/dchateau.log`) : `CRENEAU`, `DRAPEAU`, `TOUR` tapés, `TOUR` essayée à
   deux échelles, puis `CHATEAU`.
2. Le chevalier : sortie de LOGO (l'image reste en SPLIT), `CHEVAL.GRX` tapé dans EDIT,
   lancé : `DUN.SPR` traverse devant les tours (flèches, ou seul).
3. Le même en assembleur : `GRXASM CHEVAL /C`, ASM, `CHEVAL`.
4. Forêt : `ARBRE` (`files/demo.log`) tapé, composition `FORET` (arbres à plusieurs
   échelles et places, `HASARD`, sol, lune par `POLY`), `SAUVEIMAGE "FORET`.
5. Traceur : `CHARGE "TRASINUS`, puis `F` seul retapé (x·sin x) et relancé.
6. `VOIR FORET.IMG` : la forêt revient.
7. Facultatif : `LABYRINT.GRX` (`files/`) en finale.

**Puis** : avec un seul lecteur, demander la disquette système quand `CPA.BNK` de `A:`
manque ou n'a pas la signature du système (brouillon : 67 octets ; changement de disquette
du banc à réparer d'abord).

1. **Atelier créatif** (sprites, rectangles, tuiles et EDSPRITE : `docs/grapher.md` § 7,
   `docs/edsprite.md`)
   - Sprites dans l'image (`HSHOW`, `HHIDE`) : placement au point près en x (décalages).
   - Caractères animés au 50 Hz (`docs/grapher.md` § 16).
   - Un **dessin assisté** (`.COM`, plus précis que la tortue de LOGO : points, traits,
     formes, remplissage, couleurs par attributs, vers `.HIR` / `.HIZ`), à spécifier. Le
     remplissage existe déjà (`progs/pnt_inc.s` : `PAINT` de GRAPHER, `REMPLIS` de LOGO,
     `h_paint` de `HIRES.INC`).
2. **GRAPHER, plateforme de développement** (bibliothèques précompilées `GRX.LIB` :
   `docs/grapher.md` § 12 et § 15)
   - Phases d'un jeu (`RUN`), à décider : `docs/grapher.md` § 17.
   - Gros programme envisagé : un **rogue-like** (sprites, niveaux tirés au hasard, une
     dizaine de monstres, armes, butin). Estimation : 500 à 550 lignes, 12 à 15 Ko de
     `.GRX` ; tables des monstres et des objets dans des fichiers de données (`LOAD`),
     ~3 Ko de tableaux. Trop juste en interprété (~17 Ko pour texte et tableaux), à l'aise
     traduit : `.COM` de 20 à 23 Ko, ~15 Ko de tableaux libres, `.ASM` de ~130 Ko pendant
     l'assemblage. Bon cas d'essai pour la limite de 20 Ko et pour `RUN` : la génération
     d'un niveau, programme à part, écrit le niveau dans des fichiers de données que le
     jeu relit.
   - **Son** (décidé, rien codé) : GRAPHER n'a aucune commande de son (seul le bip d'un
     `INPUT` refusé, `rz_bip` d'`ARR.INC`). Commandes à spécifier avant tout code (notes,
     bruit, durées, attente, son en cours ; s'inspirer de LOGO sans sa lourdeur, point 6).
     Interprété et traduit par la fonction 116 du BDOS ; avec `GRXASM /O`, `snd.s`
     (~600 octets) rejoint le socle `ORIC.INC` (`docs/oric-basic.md` § 4 ; aujourd'hui un
     bip seulement). Place : `docs/place.md`.
   - Savoir si un fichier existe sans le charger (`FOUND` ne vaut qu'après `LOAD` ou
     `BLOAD`) : une fonction du genre `EXIST("NOM")`, ou une commande qui pose `FOUND`, à
     décider.
   - `ANIMS.GRX` ne passe plus dans GRAPHER (« animation trop grande ») mais passe une fois
     traduit par GRXASM : en faire un exemple du manuel qui montre les limites du mode
     interprété et l'intérêt de traduire, avec la place gagnée (à mesurer).
   - Exemples de fichiers de données : un niveau écrit dans EDIT (`LOAD`), un écran titre
     (`BLOAD SCREEN`).
3. **Publier vers l'Oric de base** (`MKTAP`, `GRXASM /O`, `.BAS` : `docs/oric-basic.md`)
   - `CASSETTE.COM` (décidé, `docs/oric-basic.md` § 2), l'équivalent de `CSAVE`. Sous
     CP/A, la ROM de l'Oric est remplacée par la RAM overlay : réécrire les routines
     cassette (timing à essayer sur un vrai magnétophone) ou basculer un moment sur la ROM.
   - Décidé, pas encore fait : SPLIT dans `ORIC.INC`, le son quand GRAPHER en aura.
   - Plus tard : un `.TAP` de BASIC rendu en texte (l'inverse de MKTAP) ; la boîte à
     outils appelée par `!` depuis le BASIC (`docs/oric-basic.md` § 5). Écartée : la
     traduction de GRAPHER en BASIC (§ 6).
   - **La clé USB et le LOCI depuis CP/A** (niveau 1 : `docs/usb.md`). Niveau 2, un
     répertoire de la clé comme lecteur : point 9.
4. **Réseau par le LOCI** (TERM, XFER, `HOSTS` : `docs/manuel.md` ; matériel :
   `docs/loci-modem-wifi.md` ; console à distance, vitrine, passerelle :
   `docs/console-distance.md`)
   - XFER : plusieurs fichiers (jokers), décidé. Possible, pas demandé (le débit actuel
     suffit) : **XMODEM-1K** (blocs de 1 Ko, en-tête STX, option « K » de la ligne de
     commande du serveur pour rester compatible, CRC par table de 512 octets construite au
     démarrage ; tout dans `XFER.COM` et `xfer_server.py`, rien de résident ; tampon de
     1 Ko après la fin du programme ; ~8 fois moins d'allers-retours).
   - `tools/essai_oric.py` : essais du vrai Oric pilotés par la console à distance
     (batterie tirée de `docs/essais-materiel.md`).
   - Environ un échange sur dix est retardé de 1 à 2 s sur le WiFi : signature d'un paquet
     perdu et renvoyé par la pile TCP du Pico (lwIP, délai de renvoi d'une seconde au
     moins) ; à regarder seulement si cela gêne (réglage du firmware du Pico).
   - Passerelle vers Claude sur le Pi 400 (serveur TCP : appel de l'API, accents
     translittérés, lignes de 38 colonnes, historique gardé côté Pi) : envisagée.
   - Contre-essai à faire : le firmware 0.3.1 officiel du LOCI avec le câble de données
     (`ACIADIAG.TAP`, `TERM /D`) ; résultat à porter dans l'issue 17 du firmware
     (`docs/loci-modem-wifi.md`).
5. **Sûreté des fichiers et défauts constatés** (lot 1 de `docs/revue.md`)
   - **Contrôleur du LOCI qui ne répond plus après un RESET pendant `DISKCOPY A: D:`**
     (D: vide ; `*RESET* at C6C6`, disquettes intactes). Le pilote en fait une erreur
     disque (`docs/systeme.md` § 3). Reste à comprendre la cause : `C6C6` n'est pas une
     adresse de DISKCOPY mais du traitement du RESET lui-même, donc une seconde NMI pendant
     le démarrage à chaud (rebond du bouton ?) ; la seconde NMI agit tout de suite, même au
     milieu d'un secteur (`bios.s`, `nmi_handler`). Le firmware du LOCI termine une
     écriture abandonnée au bout d'un délai (`dsk_rw_countdown`, `dsk.c`) : pas de blocage
     évident de ce côté. Non reproductible dans Oricutron ; à voir sur le LOCI
     (`docs/essais-materiel.md`). Si c'est un rebond : ignorer une NMI arrivée peu après la
     précédente.
   - **Firmware du LOCI**, à signaler à son auteur (`docs/usb.md` § 2 pour les
     contournements) : sur `0:`, `O_CREAT+O_TRUNC` est traduit sans `O_CREAT` (`std.c`) ;
     le montage d'une image de `0:` fige le LOCI (ouverture du fichier non vérifiée,
     `mnt.c`). Un `USBDIR` a aussi figé l'Oric et le LOCI après un passage par le menu du
     LOCI, avec un répertoire courant sans support : à reproduire maintenant que les
     chemins ont toujours leur support.
   - Écriture par `NOM.$$$` (EDIT, EDSPRITE, tableaux de GRAPHER) : reste une fenêtre d'une
     demi-seconde, entre l'effacement de l'ancien fichier et le renommage, où un RESET
     laisse le nouveau contenu seulement dans `NOM.$$$` (rien n'est perdu, `REN` le
     remet). La fermer : une section protégée contre RESET pendant l'effacement et le
     renommage (variable publique en page 2, ou fonction BDOS de remplacement) — touche au
     contrat, à décider.
   - GSAVE du système rend 3 pour un fichier protégé ; GRAPHER (`h_save`) et LOGO
     (`SAUVEIMAGE`) l'affichent encore comme un disque plein : leur message à corriger.
6. **Petites améliorations notées**
   - **Imprimante dans un fichier** (décidé) : `PUT /P NOM commande` recopie dans le
     fichier ce qui part à l'imprimante (LIST, BDOS 5, CTRL-P, `^P` d'EDIT) au lieu de
     l'écran ; `EXPORT` le passe sur la clé, puis directement avec le lecteur U: (point 9 :
     `PUT /P U:PRINT.TXT ...`). Par PUT plutôt que par un pilote LOCI dans le BIOS (API du
     LOCI résidente). Coût résident : un test dans LIST vers `put_char` (~10 octets ; PUT
     est une banque de la fenêtre, `docs/place.md`).
   - **DEBUG** (décidé, à faire avec sa refonte, pas avant) : afficher par la fonction 2
     du BDOS au lieu de `B_CONOUT` (`putc`), pour que `PUT LISTE.TXT DEBUG` garde un long
     désassemblage sans limite de tampon (puis XFER ou EXPORT vers un ordinateur) ; revoir
     son ergonomie.
   - Son dans les scripts : commande `NOTE` au prompt ou `PLAY.COM` (partition texte).
   - **Son de LOGO plus simple** : `SON v n vol d` et `ENSEMBLE` sont lourds pour un accord
     et n'ont pas de raccourci. Piste retenue : une surcouche écrite en LOGO (fichier
     `.LOG` chargé par `CHARGE` : notes par leur nom, accord, durées), sans toucher à
     LOGO.COM, puis seulement les primitives qui manqueraient. À écrire après avoir fixé ce
     qu'on attend d'un accord.
   - LOGO : ne pas perdre la frappe anticipée pendant `NOTE` / `ATTENDS` ; passer des
     paramètres d'un script à `LOGO NOM` ; tokenisation des procédures **en mémoire**
     seulement (au `CHARGE`, détokenisées par `SAUVE`, `LISTE` ; numéros de
     `tools/gen_logo_voc.py`), sur mesure (vitesse d'ELIZA et des traceurs, place) ; le
     contenu des listes reste du texte (code ou données : décidé à l'exécution).
   - LOGO : **lecture et écriture de fichiers texte** (`OUVRE`, `LISFICHIER` ligne par ligne,
     `ECRISFICHIER`, `FERME` : ~600-800 octets, un FCB et un tampon de plus) pour des données
     trop grandes pour les 32 globales (carte, dictionnaire, journal d'un jeu). Attend un
     programme qui en ait besoin : `SAUVEDONNEES` + `CHARGE` couvrent la sauvegarde de
     partie et les scores (`docs/logo.md`).
   - EDIT : une édition plein écran (colonnes 0-1 comprises) pour dessiner un écran texte.
   - EDIT : un **sélecteur de fichiers** pour Ouvrir... et Insérer... (liste aux flèches,
     début de nom pour filtrer, RETURN choisit, ESC sort ; même esprit que `USBMOUNT`). À
     écrire une fois, en bibliothèque (`.inc`) réutilisable par les autres programmes
     (GRAPHER `LOAD`, CMDER...).
     Et **Insérer une partie d'un fichier** : le fichier choisi s'affiche en lecture seule,
     on s'y déplace et on y cherche (même recherche que dans EDIT), on marque début et fin,
     RETURN insère le bloc au curseur. But : une bibliothèque de bouts de code dans quelques
     gros fichiers, sans les charger en entier ni multiplier les petits fichiers. Lecture du
     fichier par morceaux, sans le copier dans le tampon de texte : bon usage des fichiers à
     accès direct (fonctions 33 à 36). Place à mesurer (`docs/place.md`).
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
   - Fichiers à accès direct (fonctions 33 à 36) : un usage dans GRAPHER ou LOGO
     (enregistrement n d'un fichier de données) reste à trouver. Limite à lever avant :
     `docs/revue.md` § 2.
7. **Version anglaise** : faite (`docs/architecture.md` § 5 et § 7, `docs/logo.md` pour
   LOGO et LOGOTR). Règles gardées : tout nouveau texte affiché ou document d'utilisation
   se fait dans les deux langues ; les mots-clés de GRAPHER sont les mêmes dans les deux
   langues, seuls les messages se traduisent ; les documents de `docs/en/` sont suivis par
   `tools/check_en.py`.

8. **Construire CP/A sur l'Oric** (rien codé) : une disquette de construction pour
   produire sur l'Oric un système configuré selon les besoins (sans menus, sans USB du
   LOCI...) et l'installer sur B:.
   - Installer sur B: : existe déjà, `DISKCOPY A: B: /S` (comme SYSGEN) ; il faudra la même
     chose depuis un fichier système produit par ASM.
   - Sources : `build.sh` produirait une version de `src/` sans commentaires ni lignes
     vides pour la disquette de construction (les sources de référence restent celles du
     dépôt). Tient sur une disquette, à mesurer.
   - ASM (syntaxe de xa, octets identiques) : manquent `#ifdef`, `#ifndef`, `#else`,
     `#endif` (les seules directives du système, imbriquées sur 2 niveaux au plus ; pas de
     `#if` ni de `#define`). Les options (`CPLCMD`, `SERIE`, `CHGDSK`...) seraient des
     constantes d'un fichier de configuration inclus en premier, sans option nouvelle sur
     la ligne de commande. Coût estimé : ~150 à 200 octets (mots des directives, état de
     saut avec une petite pile, lignes sautées, deux messages d'erreur), prévoir large :
     place dans `docs/place.md`. L'inclusion sur deux niveaux est évitée sans coût :
     `#include "sys.msg"` passe de `menu.s` à `cpa.s`. Symboles du système et temps
     d'assemblage (LOGO, 136 Ko de source : ~1 min 30) : à mesurer sur le LOCI.
   - Refaire sur l'Oric les contrôles de `build.sh` (marges, fin du code, page `$FF00`).
   - Options touchant une fonction du BDOS (menus, USB, son...) : le numéro reste et répond
     `$FF` quand l'option est absente (`docs/architecture.md` § 2) ; les programmes doivent
     savoir s'en passer, à vérifier avant de rendre quoi que ce soit optionnel.
   - Ordre proposé : `#ifdef` dans ASM, `sys.msg` inclus par `cpa.s` ; essai d'assemblage
     du système par ASM (octets identiques à xa) ; disquette de construction ; installation
     depuis un fichier.

9. **Orientation LOCI du stockage** (décidé, rien codé) : CP/A vise à moderniser
   l'environnement, pas à rentabiliser des disquettes 3 pouces devenues rares et chères ;
   le LOCI est simple, répandu et peu cher, et la synchronisation d'un vrai Microdisc est
   délicate. Les fichiers restent du **texte sur disque** (EDIT, TYPE, git, le Mac) : pas
   de tokenisation ni de compactage sur disque (ceux du BASIC et de SEDORIC sont de leur
   époque) ; la place viendra du **lecteur « fichiers USB »** ci-dessous, la direction à
   suivre pour le stockage. Le `.dsk` reste pour démarrer (disquettes de 2 faces de 80
   pistes : `docs/systeme.md` § 3 ; mesures et pistes restantes : `docs/etude-stockage.md`).
   - **Lecteur « fichiers USB » (U:)**, plus intéressant : les fonctions fichiers du BDOS
     passent par l'interface fichiers du LOCI (ouvrir, lire, écrire, se positionner,
     fermer ; USBDIR s'en sert déjà pour lister). Gains : taille de la clé, vitesse (pas
     d'émulation de secteurs), fichiers lisibles et modifiables sur le Mac (éditeur, git ;
     plus besoin d'`EXPORT` / `IMPORT`), accès direct presque gratuit (positionnement ;
     utile à la bibliothèque de bouts d'EDIT, point 6), taille exacte des fichiers.
     Difficultés : noms longs ramenés en 8.3 ; attributs R/O et SYS ; espace libre pour DIR
     et STAT ; les programmes qui lisent des secteurs par le BIOS (DISKCOPY, FORMAT...) ne
     marchent pas sur U:. **Touche le contrat** (un type de lecteur sans accès secteur) :
     à décider avant tout code.
   - **Construction hybride proposée** : A: reste un `.dsk` (démarrage ;
     un utilisateur de Sedoric essaie CP/A sans rien changer), U:
     lecteur de travail pour qui a un LOCI (option de la construction, point 8). À terme,
     une variante « tout LOCI » où A: est un dossier de la clé : plus de code de secteurs
     sauf l'amorçage, système plus petit.
   - Préalable : lire l'interface fichiers du LOCI (`loci-rom`, firmware) : ce qu'elle
     permet, longueur des noms, espace libre, vitesse.
   - Fichier catalogue par répertoire de la clé : écarté. Il doublerait
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
   - Piste : proposer à l'auteur du LOCI (sodiumlb) une version du firmware qui
     fasse du LOCI une vraie interface de stockage, support alternatif au Microdisc.
     Précédents dans cet esprit : Orix (système de la carte Twilighte, fichiers FAT sur
     clé USB / SD directement) et Erebus (à regarder).

Écarté : une base de données (hors de la vision : `docs/vision.md`) ; `REDIM` dans GRAPHER (hors de l'esprit du langage : les tailles sont connues à
l'écriture) ; modules chargeables pour LOGO (le chargement par étapes avec `CHARGE` et `OUBLIE`
suffit) ; primitive LOGO générique `.SYSTEME n [liste]` ; conversion CR LF -> LF par EXPORT ; un portage pour le Microdisc (son lecteur 3″ d'origine
n'a qu'une face de 40 pistes, les disquettes de CP/A en ont 2 de 80 ; laissé à qui le
demandera : note de `README.md`, piste F de `docs/etude-stockage.md`).

