; Généré par tools/gen_readme_txt.py — ne pas éditer à la main
help_keys
        .asc "TOUC",0
        .asc "PROG",0
        .asc "EDIT",0
        .asc "HEX",0
        .asc "LOGO",0
        .asc "ASM",0
        .asc "DEBU",0
        .asc "MEMO",0
        .asc "USB",0
        .byt 0
help_ptrs
        .word h_default,h_0,h_1,h_2,h_3,h_4,h_5,h_6,h_7,h_8
h_default
        .asc "COMMANDES",13,10
        .asc "---------",13,10
        .asc "HELP [sujet]  | aide (HELP.COM)",13,10
        .asc "VER           | version",13,10
        .asc "CLS           | efface l'ecran",13,10
        .asc "B:            | lecteur courant (A: a",13,10
        .asc "              |   D:) ; aussi menu",13,10
        .asc "              |   Systeme, Lecteur",13,10
        .asc "              |   suivant ; un .COM",13,10
        .asc "              |   absent est cherche",13,10
        .asc "              |   sur A:",13,10
        .asc "DIR [afn]     | liste des fichiers",13,10
        .asc "DIRS [afn]    | idem, fichiers SYS",13,10
        .asc "              |   compris",13,10
        .asc "TYPE fic      | affiche un texte",13,10
        .asc "ERA afn [/Q]  | efface, apres",13,10
        .asc "              |   confirmation (/Q :",13,10
        .asc "              |   sans question)",13,10
        .asc "REN nouv=anc  | renomme",13,10
        .asc "SAVE n fic    | sauve n pages de 0500",13,10
        .asc "PUT fic cmd [param]",13,10
        .asc "              | lance cmd, copie sa",13,10
        .asc "              |   sortie dans fic",13,10
        .asc "DO fic [p1..p9]",13,10
        .asc "              | lance FIC.BAT ($1..$9",13,10
        .asc "              |   = parametres, ESC",13,10
        .asc "              |   arrete)",13,10
        .asc "ECHO texte    | affiche le texte",13,10
        .asc "PAUSE [texte] | attend une touche",13,10
        .asc "SPLIT         | image + 10 lignes",13,10
        .asc "TEXT          | texte seul",13,10
        .asc "GCLS          | efface l'image",13,10
        .asc "PEN m         | 0 efface 1 trace 2",13,10
        .asc "              |   inv.",13,10
        .asc "PLOT x y      | point (x 0-239, y",13,10
        .asc "              |   0-127)",13,10
        .asc "LINE x1 y1 x2 y2",13,10
        .asc "              | ligne",13,10
        .asc "BOX x1 y1 x2 y2",13,10
        .asc "              | rectangle",13,10
        .asc "FBOX x1 y1 x2 y2",13,10
        .asc "              | rectangle plein",13,10
        .asc "CIRCLE x y r  | cercle",13,10
        .asc "GTEXT col y texte",13,10
        .asc "              | texte dans l'image",13,10
        .asc "              |   (col 0-39)",13,10
        .asc "ATTR col y1 y2 v",13,10
        .asc "              | attribut : encre 0-7,",13,10
        .asc "              |   papier 16-23",13,10
        .asc "POINT x y     | affiche 1 si allume",13,10
        .asc "GSAVE fic     | sauve l'image (.IMG)",13,10
        .asc "GLOAD fic     | charge l'image",13,10
        .asc "NOM [param]   | lance NOM.COM, sinon",13,10
        .asc "              |   NOM.BAT",13,10
        .asc "",13,10
        .asc "Autres sujets : HELP suivi de",13,10
        .asc "  TOUCHES PROGRAMMES EDIT HEX",13,10
        .asc "  LOGO ASM DEBUG MEMOIRE USB",13,10
        .asc "  (4 lettres suffisent)",13,10
        .byt 0
h_0
        .asc "TOUCHES",13,10
        .asc "-------",13,10
        .asc "FUNCT         | menus deroulants",13,10
        .asc "CTRL-T        | majuscules oui/non",13,10
        .asc "              |   (voyant A ou a au",13,10
        .asc "              |   bout de la barre)",13,10
        .asc "<- ->         | deplace dans la ligne",13,10
        .asc "              |   (on tape en",13,10
        .asc "              |   insertion)",13,10
        .asc "haut bas      | lignes deja tapees",13,10
        .asc "              |   (historique)",13,10
        .asc "ESC           | complete un nom de",13,10
        .asc "              |   fichier (en debut",13,10
        .asc "              |   de ligne : une",13,10
        .asc "              |   commande) ; 2 fois",13,10
        .asc "              |   : les noms",13,10
        .asc "              |   possibles",13,10
        .asc "DEL ^D        | efface a gauche /",13,10
        .asc "              |   sous",13,10
        .asc "^A ^E         | debut / fin de ligne",13,10
        .asc "CTRL-X        | efface la ligne",13,10
        .asc "CTRL-P        | imprimante oui/non",13,10
        .asc "              |   (tout ce qui",13,10
        .asc "              |   s'affiche ; voyant",13,10
        .asc "              |   P ; aussi menu",13,10
        .asc "              |   Systeme)",13,10
        .asc "CTRL-C        | redemarrage a chaud",13,10
        .asc "RESET         | retour au prompt",13,10
        .byt 0
h_1
        .asc "PROGRAMMES",13,10
        .asc "----------",13,10
        .asc "DIRS *.COM    | tous, caches (SYS)",13,10
        .asc "              |   compris",13,10
        .asc "EDIT [fic]    | editeur de texte",13,10
        .asc "HEX fic       | editeur hexadecimal",13,10
        .asc "SET afn [opt] | attributs : RO RW SYS",13,10
        .asc "              |   DIR (sans opt : les",13,10
        .asc "              |   affiche)",13,10
        .asc "LOGO [fic]    | Logo et sa tortue",13,10
        .asc "              |   (charge fic.LOG)",13,10
        .asc "ASM nom       | NOM.ASM -> NOM.COM et",13,10
        .asc "              |   NOM.SYM",13,10
        .asc "DEBUG nom [param]",13,10
        .asc "              | debogueur",13,10
        .asc "COPY src [dst]",13,10
        .asc "              | copie, jokers admis :",13,10
        .asc "              |   COPY *.COM B:, COPY",13,10
        .asc "              |   *.TXT *.BAK, COPY",13,10
        .asc "              |   B:*.LOG",13,10
        .asc "FORMAT X: [/Q]",13,10
        .asc "              | formate X: (A: : un",13,10
        .asc "              |   seul lecteur) ; /Q",13,10
        .asc "              |   : vide le",13,10
        .asc "              |   repertoire",13,10
        .asc "DISKCOPY s: d: [opt]",13,10
        .asc "              | copie la disquette s:",13,10
        .asc "              |   sur d: (A: A: : un",13,10
        .asc "              |   seul lecteur) ; /T",13,10
        .asc "              |   tout, /V relecture,",13,10
        .asc "              |   /S systeme",13,10
        .asc "              |   seulement (SYSGEN)",13,10
        .asc "STAT [d:][afn]",13,10
        .asc "              | taille : enreg.,",13,10
        .asc "              |   blocs de 2 Ko,",13,10
        .asc "              |   octets ; At : R",13,10
        .asc "              |   protege, S systeme",13,10
        .asc "              |   ; seul : place",13,10
        .asc "              |   libre",13,10
        .asc "XDO nom [param]",13,10
        .asc "              | script appele par un",13,10
        .asc "              |   script (lance par",13,10
        .asc "              |   le CCP)",13,10
        .asc "EXPORT fic [nom]",13,10
        .asc "              | copie sur la cle USB",13,10
        .asc "              |   du LOCI (HELP USB)",13,10
        .asc "IMPORT nom [fic]",13,10
        .asc "              | copie depuis la cle",13,10
        .asc "              |   USB du LOCI",13,10
        .asc "USBDIR [chemin]",13,10
        .asc "              | fichiers de la cle",13,10
        .asc "              |   USB du LOCI",13,10
        .asc "MEM           | carte de la memoire",13,10
        .asc "POKE adr bb.. | ecrit en memoire",13,10
        .asc "              |   (code a lancer :",13,10
        .asc "              |   0600 et +)",13,10
        .asc "GO adr [param]",13,10
        .asc "              | lance le code (RTS =",13,10
        .asc "              |   retour)",13,10
        .asc "GTEST         | demo graphique",13,10
        .asc "HELLO [param] | exemple de .COM",13,10
        .byt 0
h_2
        .asc "EDIT",13,10
        .asc "----",13,10
        .asc "fleches       | deplacement",13,10
        .asc "^A ^E         | debut / fin de ligne",13,10
        .asc "^R ^C         | page prec. / suiv.",13,10
        .asc "^Q ^Z         | debut / fin du texte",13,10
        .asc "DEL ^D        | efface avant / sous",13,10
        .asc "^Y            | efface le paragraphe",13,10
        .asc "^O            | insere / remplace",13,10
        .asc "^F ^G         | cherche / suivant",13,10
        .asc "^S            | enregistre",13,10
        .asc "^L            | insere un fichier au",13,10
        .asc "              |   curseur",13,10
        .asc "^P            | imprime le texte, mis",13,10
        .asc "              |   en page (ESC",13,10
        .asc "              |   arrete)",13,10
        .asc "^N            | paragraphe trop long",13,10
        .asc "              |   suivant",13,10
        .asc "C 127!        | (ligne d'etat)",13,10
        .asc "              |   position dans le",13,10
        .asc "              |   paragraphe ; ! :",13,10
        .asc "              |   plus long que le",13,10
        .asc "              |   maxi",13,10
        .asc "EDIT.CFG      | par fichier : nom",13,10
        .asc "              |   maxi [MOTS|CAR]",13,10
        .asc "              |   [largeur impr.],",13,10
        .asc "              |   ex. *.LOG 126 CAR",13,10
        .asc "              |   80",13,10
        .asc "FUNCT         | menus Fichier (dont",13,10
        .asc "              |   Inserer, Imprimer),",13,10
        .asc "              |   Edition, Chercher,",13,10
        .asc "              |   Options",13,10
        .asc "Retour        | (lance par EDITE de",13,10
        .asc "              |   LOGO) enregistre et",13,10
        .asc "              |   revient",13,10
        .byt 0
h_3
        .asc "HEX",13,10
        .asc "---",13,10
        .asc "fleches RET   | deplacement",13,10
        .asc "^R ^C         | page prec. / suiv.",13,10
        .asc "^Q ^Z         | debut / fin",13,10
        .asc "^A            | aller a l'adresse",13,10
        .asc "^F ^G         | cherche texte ou",13,10
        .asc "              |   #hexa / suivant",13,10
        .asc "^O            | mode HEX / ASCII",13,10
        .asc "^S            | enregistre",13,10
        .asc "ESC           | quitte",13,10
        .byt 0
h_4
        .asc "LOGO",13,10
        .asc "----",13,10
        .asc "AV n  RE n    | avance / recule (n",13,10
        .asc "              |   decimal admis)",13,10
        .asc "DR n  GA n    | droite / gauche",13,10
        .asc "              |   (degres, 0.5 admis)",13,10
        .asc "LC  BC        | leve / baisse stylo",13,10
        .asc "CT  MT        | cache / montre",13,10
        .asc "VE  ORIGINE   | vide ecran / centre",13,10
        .asc "POINT x y     | un point (coordonnees",13,10
        .asc "              |   de la tortue, qui",13,10
        .asc "              |   ne bouge pas)",13,10
        .asc "TRAIT x y x y | un trait ; RECTANGLE,",13,10
        .asc "              |   PAVE (plein) :",13,10
        .asc "              |   coins opposes",13,10
        .asc "CERCLE r      | autour de la tortue",13,10
        .asc "              |   (r 0-127)",13,10
        .asc "ETIQUETTE x   | ecrit x dans l'image",13,10
        .asc "              |   a la tortue",13,10
        .asc "FIXECOULEUR v | encre 0-7 ou papier",13,10
        .asc "              |   16-23 de l'image",13,10
        .asc "ALLUME? x y   | 1 si le point est",13,10
        .asc "              |   allume",13,10
        .asc "ECRANTEXTE    | tout en texte",13,10
        .asc "ECRANMIXTE    | retour a l'image",13,10
        .asc "REPETE n [..] | repete la liste",13,10
        .asc "SI c [..] [..]",13,10
        .asc "              | condition",13,10
        .asc "POUR NOM :A ... FIN",13,10
        .asc "              | definit une procedure",13,10
        .asc "RENDS x       | la procedure rend x",13,10
        .asc "EC x          | ecrit",13,10
        .asc "SAUVE ",34,"N      | procedures -> N.LOG",13,10
        .asc "CHARGE ",34,"N     | charge N.LOG",13,10
        .asc "EDITE ",34,"N      | N.LOG dans EDIT, puis",13,10
        .asc "              |   Retour",13,10
        .asc "SAUVEIMAGE ",34,"N | dessin -> N.IMG",13,10
        .asc "CHARGEIMAGE ",34,"N",13,10
        .asc "              | charge N.IMG",13,10
        .asc "3.14  2E-7    | decimaux (9 chiffres)",13,10
        .asc "              |   ; 7 / 2 = 3.5",13,10
        .asc "ENT x  ARRONDI x",13,10
        .asc "              | partie entiere /",13,10
        .asc "              |   entier proche",13,10
        .asc "RACINE x      | racine carree",13,10
        .asc "SIN COS ARCTAN",13,10
        .asc "              | en degres (SIN 30 =",13,10
        .asc "              |   0.5)",13,10
        .asc "LN x  EXP x   | logarithme /",13,10
        .asc "              |   exponentielle",13,10
        .asc "ABS x         | valeur absolue",13,10
        .asc "QUOTIENT a b  | division entiere ;",13,10
        .asc "              |   RESTE a b : reste",13,10
        .asc 34,"MOT  [A B]   | mot, liste (DONNE ",34,"L",13,10
        .asc "              |   [A B])",13,10
        .asc "PR SP x       | premier / sauf le",13,10
        .asc "              |   premier",13,10
        .asc "DER SD x      | dernier / sauf le",13,10
        .asc "              |   dernier",13,10
        .asc "ITEM n x      | n-ieme element",13,10
        .asc "COMPTE x      | nombre d'elements",13,10
        .asc "MOT a b       | colle deux mots",13,10
        .asc "PH a b  LISTE a b",13,10
        .asc "              | phrase / liste de",13,10
        .asc "              |   deux",13,10
        .asc "VIDE? MOT? LISTE?",13,10
        .asc "              | 1 ou 0 ; aussi",13,10
        .asc "              |   NOMBRE? MEMBRE? a b",13,10
        .asc "EXEC [..]     | execute une liste",13,10
        .asc "LISLISTE      | lit une ligne ->",13,10
        .asc "              |   liste (LL)",13,10
        .asc "LISMOT        | lit une ligne -> mot",13,10
        .asc "LISCAR        | attend une touche ->",13,10
        .asc "              |   caractere",13,10
        .asc "ASCII x  CAR n",13,10
        .asc "              | code d'un caractere /",13,10
        .asc "              |   caractere",13,10
        .asc "TOUCHE?       | 1 si une touche",13,10
        .asc "              |   attend, 0 sinon",13,10
        .asc "SON v n vol d | note n (37 = do, 0 =",13,10
        .asc "              |   rien) sur la voix v",13,10
        .asc "              |   (0-2), volume 0-15",13,10
        .asc "              |   (16 = enveloppe),",13,10
        .asc "              |   d/50 s (0 : sans",13,10
        .asc "              |   fin)",13,10
        .asc "SONF v p vol d",13,10
        .asc "              | son de periode p",13,10
        .asc "              |   (0-4095)",13,10
        .asc "BRUITV v p vol d",13,10
        .asc "              | bruit de periode p",13,10
        .asc "              |   (0-31)",13,10
        .asc "ENVELOPPE f p | forme 0-15, periode",13,10
        .asc "              |   0-65535",13,10
        .asc "MELANGE v s b | son et bruit de la",13,10
        .asc "              |   voix (1 / 0)",13,10
        .asc "ENSEMBLE [..] | les voix de la liste",13,10
        .asc "              |   partent ensemble",13,10
        .asc "ATTENDSSON v  | attend la fin (255 :",13,10
        .asc "              |   toutes)",13,10
        .asc "JOUE? v       | 1 si la voix joue",13,10
        .asc "              |   encore",13,10
        .asc "SILENCE       | coupe le son",13,10
        .asc "AIDE          | liste complete",13,10
        .asc "QUITTE        | retour a CP/A",13,10
        .byt 0
h_5
        .asc "ASM : SYNTAXE",13,10
        .asc "-------------",13,10
        .asc "etiq          | en colonne 1",13,10
        .asc "NOM = expr    | constante",13,10
        .asc "*= adr        | adresse (0500)",13,10
        .asc ".byt .asc     | octets, ",34,"chaines",34,13,10
        .asc ".word         | mots 16 bits",13,10
        .asc ".dsb n[,v]    | n octets",13,10
        .asc ".(  .)        | bloc, etiquettes",13,10
        .asc "              |   locales",13,10
        .asc "#include ",34,"f",34,"  | inclusion",13,10
        .asc "$ % ",34,"c",34," *     | hexa, binaire, car.,",13,10
        .asc "              |   ici",13,10
        .asc "< >           | octet bas / haut",13,10
        .byt 0
h_6
        .asc "DEBUG",13,10
        .asc "-----",13,10
        .asc "R [reg=v]     | registres (A X Y S PC",13,10
        .asc "              |   P, N V D I Z C)",13,10
        .asc "L [adr]       | desassemble",13,10
        .asc "D [adr]       | memoire",13,10
        .asc "M adr bb..    | modifie la memoire",13,10
        .asc "G [adr]       | execute",13,10
        .asc "T [n]         | pas a pas",13,10
        .asc "P [n]         | pas a pas, JSR d'un",13,10
        .asc "              |   coup",13,10
        .asc "B [adr]       | pose / liste les",13,10
        .asc "              |   points d'arret",13,10
        .asc "B- [adr]      | enleve (tous)",13,10
        .asc "? expr        | valeur et symbole",13,10
        .asc "H  Q          | aide / quitte",13,10
        .asc "adr           | hexa, #decimal, nom+n",13,10
        .byt 0
h_7
        .asc "MEMOIRE",13,10
        .asc "-------",13,10
        .asc "0000-00DF     | page zero libre",13,10
        .asc "0200 / 0203   | WBOOT / BDOS",13,10
        .asc "020C          | haut de la TPA (mot)",13,10
        .asc "0400-04FF     | page de base, DMA",13,10
        .asc "              |   0480",13,10
        .asc "0500-B3FF     | programmes (TPA)",13,10
        .asc "A000-B3FF     | image en mode SPLIT",13,10
        .asc "              |   (TPA jusqu'a 9FFF)",13,10
        .asc "B400-BB7F     | jeux de caracteres",13,10
        .asc "BB80-BFDF     | ecran texte",13,10
        .asc "C000-FFFF     | CP/A (RAM overlay)",13,10
        .asc "DEBUG         | se place en 8400-9FFF",13,10
        .asc "MEM           | cette carte, selon le",13,10
        .asc "              |   mode",13,10
        .byt 0
h_8
        .asc "USB : CLE DU LOCI",13,10
        .asc "-----------------",13,10
        .asc "EXPORT fic [nom]",13,10
        .asc "              | fic -> cle (nom : par",13,10
        .asc "              |   defaut fic,",13,10
        .asc "              |   minuscules gardees)",13,10
        .asc "EXPORT afn [dos]",13,10
        .asc "              | jokers : chaque",13,10
        .asc "              |   fichier sous son",13,10
        .asc "              |   nom, dans le",13,10
        .asc "              |   dossier dos",13,10
        .asc "IMPORT nom [fic]",13,10
        .asc "              | cle -> fic (par",13,10
        .asc "              |   defaut : nom coupe",13,10
        .asc "              |   a 8.3 ; B: seul :",13,10
        .asc "              |   sur B:)",13,10
        .asc "/T            | (IMPORT) texte : LF",13,10
        .asc "              |   seul -> CR LF",13,10
        .asc "USBDIR [chemin]",13,10
        .asc "              | liste (taille, <REP>",13,10
        .asc "              |   : dossier)",13,10
        .asc "1:/DOCS/X.TXT | chemin sur la cle ;",13,10
        .asc "              |   sans 1: : la",13,10
        .asc "              |   premiere cle",13,10
        .asc "0:X.TXT       | memoire interne du",13,10
        .asc "              |   LOCI",13,10
        .asc "^Z            | retires a l'EXPORT,",13,10
        .asc "              |   ajoutes a l'IMPORT",13,10
        .asc "X.DSK         | EXPORT refuse (image",13,10
        .asc "              |   disque)",13,10
        .byt 0
