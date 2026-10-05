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
        .byt 0
help_ptrs
        .word h_default,h_0,h_1,h_2,h_3,h_4,h_5,h_6,h_7
h_default
        .asc "COMMANDES",13,10
        .asc "---------",13,10
        .asc "HELP [sujet]  | aide (HELP.COM)",13,10
        .asc "VER           | version",13,10
        .asc "CLS           | efface l'ecran",13,10
        .asc "DIR [afn]     | liste des fichiers",13,10
        .asc "DIRS [afn]    | idem, fichiers SYS",13,10
        .asc "              |   compris",13,10
        .asc "TYPE fic      | affiche un texte",13,10
        .asc "ERA afn       | efface des fichiers",13,10
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
        .asc "NOM [param]   | lance NOM.COM",13,10
        .asc "",13,10
        .asc "Autres sujets : HELP suivi de",13,10
        .asc "  TOUCHES PROGRAMMES EDIT HEX",13,10
        .asc "  LOGO ASM DEBUG MEMOIRE",13,10
        .asc "  (4 lettres suffisent)",13,10
        .byt 0
h_0
        .asc "TOUCHES",13,10
        .asc "-------",13,10
        .asc "FUNCT         | menus deroulants",13,10
        .asc "CTRL-T        | majuscules oui/non",13,10
        .asc "<- ->         | deplace dans la ligne",13,10
        .asc "              |   (on tape en",13,10
        .asc "              |   insertion)",13,10
        .asc "haut bas      | lignes deja tapees",13,10
        .asc "              |   (historique)",13,10
        .asc "ESC           | complete un nom de",13,10
        .asc "              |   fichier ; 2 fois :",13,10
        .asc "              |   les noms possibles",13,10
        .asc "DEL ^D        | efface a gauche /",13,10
        .asc "              |   sous",13,10
        .asc "^A ^E         | debut / fin de ligne",13,10
        .asc "CTRL-X        | efface la ligne",13,10
        .asc "CTRL-P        | imprimante oui/non",13,10
        .asc "              |   (tout ce qui",13,10
        .asc "              |   s'affiche)",13,10
        .asc "CTRL-C        | redemarrage a chaud",13,10
        .asc "RESET         | retour au prompt",13,10
        .byt 0
h_1
        .asc "PROGRAMMES",13,10
        .asc "----------",13,10
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
        .asc "COPY src dst  | copie un fichier",13,10
        .asc "STAT [afn]    | taille : enreg.,",13,10
        .asc "              |   blocs de 2 Ko,",13,10
        .asc "              |   octets ; seul :",13,10
        .asc "              |   place libre",13,10
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
        .asc "FUNCT         | menus Fichier (dont",13,10
        .asc "              |   Inserer), Edition,",13,10
        .asc "              |   Chercher, Options",13,10
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
        .asc "NOTE n d      | joue la note n (37 =",13,10
        .asc "              |   do) pendant d/50 s",13,10
        .asc "BRUIT d       | bruit pendant d/50 s",13,10
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
